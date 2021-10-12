CREATE OR REPLACE PACKAGE BODY xxconv_inv_trx_pkg IS
  ---------------------------------------------------------------------------
  -- $Header: xxconv_inv_trx_pkg   $
  ---------------------------------------------------------------------------
  -- Package: xxconv_inv_trx_pkg
  -- Created:
  -- Author:
  --------------------------------------------------------------------------
  -- Purpose: CR1178 - Receive and  re-ship intransit shipment at cutover
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  7.7.13    Vitaly      initial build
  ------------------------------------------------------------------

  -----------------------------------------------------------------------------
  stop_process EXCEPTION;

  PROCEDURE message(p_message VARCHAR2) IS
  
  BEGIN
    dbms_output.put_line(p_message);
    fnd_file.put_line(fnd_file.log, '========= ' || p_message);
  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END message;

  --------------------------------------------------------------------
  -- transfer_oh_qty
  -- CR1178 - Receive and  re-ship intransit shipment at cutover.
  -------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -----------------------------
  --     1.0  8.12.13    Vitaly         initial build 
  -------------------------------------------------------------------- 
  PROCEDURE transfer_oh_qty(errbuf               OUT VARCHAR2,
                            retcode              OUT VARCHAR2,
                            p_shipment_header_id NUMBER) IS
  
    CURSOR c_get_trans_interface_data IS
      SELECT t.shipment_number,
             t.shipment_line_id,
             decode(t.lot_number, NULL, 'OBJ_CST_SERIAL', 'OBJ_CST_LOT') source_code,
             t.item_id,
             t.item_code,
             t.lot_number,
             t.from_serial_number,
             t.to_serial_number,
             NULL expiration_date,
             t.qty_received,
             t.qty_uom_code,
             t.subinventory,
             t.revision,
             NULL locator_id,
             t.organization_id ship_from_organization_id,
             mp.organization_code ship_from_organization_code,
             CASE ----'WPI' --> 'IPK'=735 ,'ITA'=736
               WHEN mp.organization_code = 'WPI' AND
                    nvl(msi.attribute9, 'N') = 'Y' THEN
                736 ---'ITA'
               WHEN mp.organization_code = 'WPI' AND
                    nvl(msi.attribute9, 'N') = 'N' THEN
                735 ---'IPK'
               ELSE
                to_number(orgmap.new_organization_id)
             END ship_to_organization_id,
             CASE ----'WPI' --> 'IPK'=735 ,'ITA'=736
               WHEN mp.organization_code = 'WPI' AND
                    nvl(msi.attribute9, 'N') = 'Y' THEN
                'ITA' ---736
               WHEN mp.organization_code = 'WPI' AND
                    nvl(msi.attribute9, 'N') = 'N' THEN
                'IPK' ---735
               ELSE
                orgmap.new_organization_code
             END ship_to_organization_code
        FROM xxinv_cost_org_map_v      orgmap,
             mtl_parameters            mp,
             xxconv_inv_trx            t,
             mtl_secondary_inventories msi
       WHERE t.shipment_header_id = p_shipment_header_id ---parameter
         AND t.status = 'S'
         AND t.organization_id = msi.organization_id
         AND t.subinventory = msi.secondary_inventory_name
         AND orgmap.organization_id != orgmap.new_organization_id
         AND orgmap.organization_id = t.organization_id
         AND t.organization_id = mp.organization_id
       ORDER BY t.shipment_line_id;
  
    CURSOR c_get_trans_lot_ser_interf_d IS
      SELECT mti.transaction_interface_id,
             mti.last_update_date,
             mti.last_updated_by,
             mti.created_by,
             mti.creation_date,
             attribute1                   fm_serial,
             attribute1                   to_serial,
             mti.transaction_quantity,
             mti.attribute2               expiration_date,
             source_code,
             mti.inventory_item_id
        FROM mtl_transactions_interface mti
       WHERE mti.transaction_interface_id IS NOT NULL
         AND ((source_code = 'OBJ_CST_SERIAL' AND NOT EXISTS
              (SELECT 1
                  FROM mtl_serial_numbers_interface ser
                 WHERE mti.transaction_interface_id =
                       ser.transaction_interface_id)) OR
             (source_code = 'OBJ_CST_LOT' AND NOT EXISTS
              (SELECT 1
                  FROM mtl_transaction_lots_interface ser
                 WHERE mti.transaction_interface_id =
                       ser.transaction_interface_id)));
  
    v_request_id NUMBER;
    v_bool       BOOLEAN;
    v_step       VARCHAR2(100);
    stop_processing EXCEPTION;
    v_error_message VARCHAR2(5000);
    ---v_organization  NUMBER;
  
    -- WHO columns
    ---l_user_id        NUMBER := fnd_global.user_id;
    ---l_resp_id        NUMBER := fnd_global.resp_id;
    ---l_application_id NUMBER := fnd_global.resp_appl_id;
    ---user and responsibility for Apps Initialize-------
    ---l_user_name VARCHAR2(30) := 'CONVERSION';
    ---l_resp_name VARCHAR2(50) := 'Implementation Manufacturing, OBJET';
  
    ---count num of inserted records----
    v_inserted_records_counter     NUMBER := 0;
    v_inserted_lot_records_counter NUMBER := 0;
    v_inserted_ser_records_counter NUMBER := 0;
    ---- out variables for fnd_concurrent.wait_for_request-----
    x_phase      VARCHAR2(100);
    x_status     VARCHAR2(100);
    x_dev_phase  VARCHAR2(100);
    x_dev_status VARCHAR2(100);
    -- x_return_bool BOOLEAN;
    x_message VARCHAR2(100);
  
  BEGIN
  
    v_step  := 'Step 0';
    retcode := '0';
    errbuf  := 'Success';
  
    /*  
    v_step := 'Step 10';
    IF l_resp_id = -1 THEN
      -- Get the user_id----
      BEGIN
        SELECT user_id
          INTO l_user_id
          FROM fnd_user
         WHERE user_name = l_user_name;
      EXCEPTION
        WHEN no_data_found THEN
          v_error_message := 'Invalid User ''' || l_user_name || '''';
          RAISE stop_processing;
      END;
      ----------------------    
      v_step := 'Step 20';
      -- Get the application_id and responsibility_id    
      BEGIN
        SELECT application_id, responsibility_id
          INTO l_application_id, l_resp_id
          FROM fnd_responsibility_vl
         WHERE responsibility_name = l_resp_name;
      EXCEPTION
        WHEN no_data_found THEN
          v_error_message := 'Invalid Responsibility ''' || l_resp_name || '''';
          RAISE stop_processing;
      END;
    END IF;
    v_step := 'Step 30';
    -- intiialize applications information
    fnd_global.apps_initialize(l_user_id, l_resp_id, l_application_id);
    message('APPS_INITIALIZE executed (l_user_id=' || l_user_id ||
            ', l_resp_id=' || l_resp_id || ', l_application_id=' ||
            l_application_id || '================');*/
    -------fnd_global.apps_initialize(11976, 50623, 660);
  
    /*---Change Organization (to p_from_organization_id)-----
    v_step := 'Step 40';
    v_bool := fnd_profile.save(x_name       => 'MFG_ORGANIZATION_ID',
                               x_value      => p_from_organization_id, ---parameter
                               x_level_name => 'SITE');
    COMMIT;
    message('Change Organization====set profile MFG_ORGANIZATION_ID=' ||
            p_from_organization_id ||
            '====(equel to p_from_organization_id)============');*/
  
    v_step := 'Step 50';
    FOR trans_interface_rec IN c_get_trans_interface_data LOOP
    
      INSERT INTO mtl_transactions_interface
        (transaction_interface_id,
         creation_date,
         created_by,
         last_update_date,
         last_updated_by,
         source_code,
         source_line_id,
         source_header_id,
         process_flag,
         inventory_item_id,
         attribute1, ---SERIAL NUMBER
         attribute2, ---expiration_date
         organization_id,
         subinventory_code,
         locator_id,
         transaction_type_id,
         transaction_action_id,
         transaction_source_type_id,
         transaction_quantity,
         transaction_uom,
         transaction_date,
         transfer_organization,
         transfer_subinventory,
         transfer_locator,
         transaction_mode,
         revision)
      
      VALUES
        (mtl_material_transactions_s.nextval, ---transaction_interface_id
         SYSDATE, --- CREATION_DATE,
         fnd_global.user_id, --- CREATED_BY,
         SYSDATE, --- LAST_UPDATE_DATE, 
         fnd_global.user_id, --- LAST_UPDATE_BY,
         trans_interface_rec.source_code, --- SOURCE_CODE
         1, --- SOURCE_LINE_ID,
         1, --- SOURCE_HEADER_ID
         1, --- PROCESS_FLAG,
         trans_interface_rec.item_id, --- INVENTORY_ITEM_ID,
         trans_interface_rec.from_serial_number, --ATTRIBUTE1
         trans_interface_rec.expiration_date, --ATTRIBUTE2
         trans_interface_rec.ship_from_organization_id, --- ORGANIZATION_ID,
         trans_interface_rec.subinventory, --- SUBINVENTORY_CODE,
         trans_interface_rec.locator_id, ---locator_id
         3, -------3=Direct Org Transfer   --- TRANSACTION_TYPE_ID, --- ASK NOAM
         3, --- TRANSACTION_ACTION_ID
         13, ---TRANSACTION_SOURCE_TYPE_ID
         trans_interface_rec.qty_received, --- TRANSACTION_QUANTITY,
         trans_interface_rec.qty_uom_code, --- TRANSACTION_UOM,
         SYSDATE, --- TRANSACTION_DATE,
         trans_interface_rec.ship_to_organization_id, --- TRANSFER_ORGANIZATION,
         trans_interface_rec.subinventory, --- TRANSFER_SUBINVENTORY,
         trans_interface_rec.locator_id, ----to_locator_id, --- transfer_locator,
         3, --- TRANSACTION_MODE,
         trans_interface_rec.revision --- REVISION,
         --- SHIPMENT_NUMBER
         );
      v_inserted_records_counter := v_inserted_records_counter + 1;
    
    /*select  v.Shipment_Num,R.MMT_TRANSACTION_ID  , R.*
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            from rcv_shipment_headers v,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 rcv_shipment_lines R
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            where v.receipt_source_code='INVENTORY'
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            AND   R.SHIPMENT_HEADER_ID=V.SHIPMENT_HEADER_ID*/
    
    END LOOP;
    COMMIT;
    message(v_inserted_records_counter ||
            ' records were inserted into MTL_TRANSACTIONS_INTERFACE============');
  
    v_step := 'Step 60';
    FOR trans_lot_serial_interf_rec IN c_get_trans_lot_ser_interf_d LOOP
      v_step := 'Step 70';
      IF trans_lot_serial_interf_rec.source_code = 'OBJ_CST_SERIAL' THEN
        INSERT INTO mtl_serial_numbers_interface
          (transaction_interface_id,
           last_update_date,
           last_updated_by,
           created_by,
           creation_date,
           fm_serial_number,
           to_serial_number,
           parent_item_id)
        VALUES
          (trans_lot_serial_interf_rec.transaction_interface_id,
           trans_lot_serial_interf_rec.last_update_date,
           trans_lot_serial_interf_rec.last_updated_by,
           trans_lot_serial_interf_rec.created_by,
           trans_lot_serial_interf_rec.creation_date,
           trans_lot_serial_interf_rec.fm_serial,
           trans_lot_serial_interf_rec.to_serial,
           trans_lot_serial_interf_rec.inventory_item_id);
        v_inserted_ser_records_counter := v_inserted_ser_records_counter + 1;
      END IF;
      COMMIT;
      v_step := 'Step 80';
      IF trans_lot_serial_interf_rec.source_code = 'OBJ_CST_LOT' THEN
        INSERT INTO mtl_transaction_lots_interface
          (transaction_interface_id,
           lot_number,
           transaction_quantity,
           last_update_date,
           last_updated_by,
           creation_date,
           created_by,
           parent_item_id,
           lot_expiration_date)
        VALUES
          (trans_lot_serial_interf_rec.transaction_interface_id,
           trans_lot_serial_interf_rec.fm_serial,
           trans_lot_serial_interf_rec.transaction_quantity,
           trans_lot_serial_interf_rec.last_update_date,
           trans_lot_serial_interf_rec.last_updated_by,
           trans_lot_serial_interf_rec.creation_date,
           trans_lot_serial_interf_rec.created_by,
           trans_lot_serial_interf_rec.inventory_item_id,
           trans_lot_serial_interf_rec.expiration_date);
        v_inserted_lot_records_counter := v_inserted_lot_records_counter + 1;
      END IF;
      COMMIT;
    END LOOP;
    COMMIT;
    message(v_inserted_ser_records_counter ||
            ' records were inserted into MTL_SERIAL_NUMBERS_INTERFACE==============');
    message(v_inserted_lot_records_counter ||
            ' records were inserted into MTL_TRANSACTION_LOTS_INTERFACE============');
    --------
    /*--------------
    BEGIN
      SELECT organization_id
        INTO v_organization
        FROM mtl_parameters mp
       WHERE mp.organization_code = 'WPI';
      IF p_from_organization_id = v_organization THEN
        transfer_oh_qty_tpl(p_from_organization_id);
      END IF;
    END;
    --------*/
  
    ---=============== Submit 'Process transaction interface' concurrent program =====================
    v_step       := 'Step 200';
    v_request_id := fnd_request.submit_request(application => 'INV',
                                               program     => 'INCTCM');
    COMMIT;
  
    v_step := 'Step 210';
    IF v_request_id > 0 THEN
      message('Concurrent ''Process transaction interface'' was submitted successfully (request_id=' ||
              v_request_id || ')');
      ---------
      v_step := 'Step 220';
      --  LOOP
      v_bool := fnd_concurrent.wait_for_request(v_request_id,
                                                5, --- interval 5  seconds
                                                600, ---- max wait 120 seconds
                                                x_phase,
                                                x_status,
                                                x_dev_phase,
                                                x_dev_status,
                                                x_message);
      --EXIT WHEN x_return_bool AND upper(x_dev_phase) = 'COMPLETE';
    
      --   END LOOP;
    
      IF upper(x_dev_phase) = 'COMPLETE' AND
         upper(x_dev_status) IN ('ERROR', 'WARNING') THEN
        message('The ''Process transaction interface'' concurrent program completed in ' ||
                upper(x_dev_status) || '. See log for request_id=' ||
                v_request_id);
      
      ELSIF upper(x_dev_phase) = 'COMPLETE' AND
            upper(x_dev_status) = 'NORMAL' THEN
        message('The ''Process transaction interface'' program SUCCESSFULLY COMPLETED for request_id=' ||
                v_request_id || '====================');
      
      ELSE
        message('The ''Process transaction interface'' request failed review log for Oracle request_id=' ||
                v_request_id);
        retcode := '1';
      END IF;
    ELSE
      message('Concurrent ''Process transaction interface'' submitting PROBLEM');
      errbuf  := 'Concurrent ''Process transaction interface'' submitting PROBLEM';
      retcode := '2';
    END IF;
  
    ---=============== Submit 'Manager: Lot Move Transactions' concurrent program =====================
    v_step       := 'Step 300';
    v_request_id := fnd_request.submit_request(application => 'WSM',
                                               program     => 'WSCMTM');
    COMMIT;
  
    v_step := 'Step 310';
    IF v_request_id > 0 THEN
      message('Concurrent ''Manager: Lot Move Transactions'' was submitted successfully (request_id=' ||
              v_request_id || ')');
      ---------
      v_step := 'Step 320';
      -- LOOP
      v_bool := fnd_concurrent.wait_for_request(v_request_id,
                                                5, --- interval 5  seconds
                                                600, ---- max wait 120 seconds
                                                x_phase,
                                                x_status,
                                                x_dev_phase,
                                                x_dev_status,
                                                x_message);
      -- EXIT WHEN x_return_bool AND upper(x_dev_phase) = 'COMPLETE';
    
      -- END LOOP;
    
      IF upper(x_dev_phase) = 'COMPLETE' AND
         upper(x_dev_status) IN ('ERROR', 'WARNING') THEN
        message('The ''Manager: Lot Move Transactions'' concurrent program completed in ' ||
                upper(x_dev_status) || '. See log for request_id=' ||
                v_request_id);
      
      ELSIF upper(x_dev_phase) = 'COMPLETE' AND
            upper(x_dev_status) = 'NORMAL' THEN
        message('The ''Manager: Lot Move Transactions'' program SUCCESSFULLY COMPLETED for request_id=' ||
                v_request_id || '====================');
      
      ELSE
        message('The ''Manager: Lot Move Transactions'' request failed review log for Oracle request_id=' ||
                v_request_id);
        retcode := '1';
      END IF;
    ELSE
      message('Concurrent ''Manager: Lot Move Transactions'' submitting PROBLEM');
      errbuf  := 'Concurrent ''Manager: Lot Move Transactions'' submitting PROBLEM';
      retcode := '2';
    END IF;
  
    v_step := 'Step 400';
    message('RESULTS =========================================================');
    message('Concurrent program was completed successfully ===================');
    message('=================================================================');
  
  EXCEPTION
    WHEN stop_processing THEN
      v_error_message := 'ERROR in xxconv_inv_onhand_pkg.transfer_oh_qty: ' ||
                         v_error_message;
      message(v_error_message);
      retcode := '2';
      errbuf  := v_error_message;
    WHEN OTHERS THEN
      v_error_message := substr('Unexpected ERROR in xxconv_inv_onhand_pkg.transfer_oh_qty (' ||
                                v_step || ') ' || SQLERRM,
                                1,
                                200);
      message(v_error_message);
      retcode := '2';
      errbuf  := v_error_message;
  END transfer_oh_qty;
  /*--------------------------------------------------------------------
  -- transfer_oh_qty_tpl
  -- CR1178 - Receive and  re-ship intransit shipment at cutover.
  -------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -----------------------------
  --     1.0  8.12.13    Vitaly         initial build 
  --------------------------------------------------------------------
  PROCEDURE transfer_oh_qty_tpl(p_from_organization_id IN NUMBER) IS
  
    CURSOR c_get_trans_interface_data IS
      SELECT 'OBJ_CST_SERIAL' AS TYPE,
             t.on_hand available_qty,
             t.uom transaction_uom_code,
             t.inventory_item_id,
             t.subinventory_code,
             t.revision,
             t.locator_id,
             t.serial_number,
             NULL expiration_date,
             mp.organization_id p_to_organization_id,
             --MTL_MATERIAL_TRANSACTIONS_S.NEXTVAL transaction_interface_id,
             (SELECT ml.inventory_location_id
                FROM mtl_item_locations_kfv ml
               WHERE ml.concatenated_segments = t.locator
                 AND ml.organization_id = mp.organization_id ---parameter
              ) to_locator_id
        FROM mtl_onhand_serial_v       t,
             mtl_secondary_inventories mss,
             mtl_parameters            mp
       WHERE t.organization_id = p_from_organization_id ---parameter
         AND mss.organization_id = t.organization_id
            ---AND nvl(mss.attribute8, 'N') = 'N' --closed by Noam Segal 12/09/2013
         AND mss.attribute9 = 'Y' ---Noam Segal 12/09/2013
         AND mss.secondary_inventory_name = t.subinventory_code
         AND mp.organization_code = 'ITA'
      UNION ALL
      SELECT 'OBJ_CST_LOT' AS TYPE,
             (t.total_qoh) available_qty, --1
             t.primary_uom_code transaction_uom_code,
             t.inventory_item_id,
             t.subinventory_code,
             t.revision,
             t.locator_id,
             t.lot,
             t.expiration_date,
             mp.organization_id,
             --MTL_MATERIAL_TRANSACTIONS_S.NEXTVAL transaction_interface_id,
             (SELECT ml.inventory_location_id
                FROM mtl_item_locations_kfv ml
               WHERE ml.concatenated_segments = v.concatenated_segments
                 AND ml.organization_id = mp.organization_id ---parameter
              ) to_locator_id
        FROM mtl_onhand_lot_v          t,
             mtl_item_locations_kfv    v,
             mtl_secondary_inventories mss,
             mtl_parameters            mp
       WHERE t.organization_id = p_from_organization_id ---parameter
         AND v.organization_id = t.organization_id
         AND v.inventory_location_id = t.locator_id
         AND mss.organization_id = t.organization_id
            ---AND nvl(mss.attribute8, 'N') = 'N' --closed by Noam Segal 12/09/2013
         AND mss.attribute9 = 'Y' ---Noam Segal 12/09/2013
         AND mss.secondary_inventory_name = t.subinventory_code
         AND mp.organization_code = 'ITA'
      UNION ALL
      SELECT 'OBJ_CST' AS TYPE,
             moq.transaction_quantity,
             moq.transaction_uom_code,
             moq.inventory_item_id,
             moq.subinventory_code,
             moq.revision,
             moq.locator_id,
             NULL,
             NULL,
             mp.organization_id,
             --MTL_MATERIAL_TRANSACTIONS_S.NEXTVAL transaction_interface_id,
             (SELECT ml.inventory_location_id
                FROM mtl_item_locations_kfv ml
               WHERE ml.concatenated_segments = v.concatenated_segments
                 AND ml.organization_id = mp.organization_id ---parameter
              ) to_locator_id
        FROM mtl_onhand_quantities_detail moq,
             mtl_item_locations_kfv       v,
             mtl_secondary_inventories    mss,
             mtl_parameters               mp
      
       WHERE NOT EXISTS
       (SELECT *
                FROM mtl_onhand_serial_v w
               WHERE w.inventory_item_id = moq.inventory_item_id
                 AND w.organization_id = moq.organization_id)
         AND moq.lot_number IS NULL
         AND moq.organization_id = p_from_organization_id ---parameter
         AND v.organization_id = moq.organization_id
         AND v.inventory_location_id = moq.locator_id
         AND mss.organization_id = moq.organization_id
            ---AND nvl(mss.attribute8, 'N') = 'N' --closed by Noam Segal 12/09/2013
         AND mss.attribute9 = 'Y' ---Noam Segal 12/09/2013
         AND mss.secondary_inventory_name = moq.subinventory_code
         AND mp.organization_code = 'ITA';
  
    CURSOR c_get_trans_lot_ser_interf_d IS
      SELECT mti.transaction_interface_id,
             mti.last_update_date,
             mti.last_updated_by,
             mti.created_by,
             mti.creation_date,
             mti.attribute1               fm_serial,
             mti.attribute1               to_serial,
             mti.transaction_quantity,
             mti.attribute2               expiration_date,
             source_code,
             mti.inventory_item_id
        FROM mtl_transactions_interface mti, mtl_parameters mpp
       WHERE mti.transaction_interface_id IS NOT NULL
         AND mti.transfer_organization = mpp.organization_id
         AND mpp.organization_code = 'ITA'
         AND ((source_code = 'OBJ_CST_SERIAL' AND NOT EXISTS
              (SELECT 1
                  FROM mtl_serial_numbers_interface ser
                 WHERE mti.transaction_interface_id =
                       ser.transaction_interface_id)) OR
             (source_code = 'OBJ_CST_LOT' AND NOT EXISTS
              (SELECT 1
                  FROM mtl_transaction_lots_interface ser
                 WHERE mti.transaction_interface_id =
                       ser.transaction_interface_id)));
  
    ---v_request_id NUMBER;
    ---v_bool       BOOLEAN;
    v_step VARCHAR2(100);
    stop_processing EXCEPTION;
    v_error_message VARCHAR2(5000);
  
    -- WHO columns
    ---l_user_id        NUMBER := fnd_global.user_id;
    ---l_resp_id        NUMBER := fnd_global.resp_id;
    ---l_application_id NUMBER := fnd_global.resp_appl_id;
    ---user and responsibility for Apps Initialize-------
    ---l_user_name VARCHAR2(30) := 'CONVERSION';
    ---l_resp_name VARCHAR2(50) := 'Implementation Manufacturing, OBJET';
  
    ---count num of inserted records----
    v_inserted_records_counter     NUMBER := 0;
    v_inserted_lot_records_counter NUMBER := 0;
    v_inserted_ser_records_counter NUMBER := 0;
    ---- out variables for fnd_concurrent.wait_for_request-----
    ---x_phase       VARCHAR2(100);
    ---x_status      VARCHAR2(100);
    ---x_dev_phase   VARCHAR2(100);
    ---x_dev_status  VARCHAR2(100);
    ---x_return_bool BOOLEAN;
    ---x_message     VARCHAR2(100);
  
  BEGIN
  
    v_step := 'Step 0';
    --retcode := '0';
    --errbuf  := 'Success';
    message('TRANSFER_OH_QTY_TPL was started =========================');
    ---*****parameters******
    message('Parameter p_from_organization_id=' || p_from_organization_id);
    --message('Parameter p_to_organization_id=' || p_to_organization_id);
    ----*******************
  
    IF p_from_organization_id IS NULL THEN
      ---Error----
      v_error_message := 'Missing parameter p_from_organization_id';
      RAISE stop_processing;
    END IF;
    \*IF p_to_organization_id IS NULL THEN
      ---Error----
      v_error_message := 'Missing parameter p_to_organization_id';
      RAISE stop_processing;
    END IF;*\
    \*IF p_from_organization_id = p_to_organization_id THEN
      ---Error----
      v_error_message := 'Parameter p_to_organization_id cannot be equel to p_from_organization_id=' ||
                         p_from_organization_id;
      RAISE stop_processing;
    END IF;*\
  
    \*v_step := 'Step 10';
    IF l_resp_id = -1 THEN
      -- Get the user_id----
      BEGIN
        SELECT user_id
          INTO l_user_id
          FROM fnd_user
         WHERE user_name = l_user_name;
      EXCEPTION
        WHEN no_data_found THEN
          v_error_message := 'Invalid User ''' || l_user_name || '''';
          RAISE stop_processing;
      END;
      ----------------------    
      v_step := 'Step 20';
      -- Get the application_id and responsibility_id    
      BEGIN
        SELECT application_id, responsibility_id
          INTO l_application_id, l_resp_id
          FROM fnd_responsibility_vl
         WHERE responsibility_name = l_resp_name;
      EXCEPTION
        WHEN no_data_found THEN
          v_error_message := 'Invalid Responsibility ''' || l_resp_name || '''';
          RAISE stop_processing;
      END;
    END IF;
    v_step := 'Step 30';
    -- intiialize applications information
    fnd_global.apps_initialize(l_user_id, l_resp_id, l_application_id);
    message('APPS_INITIALIZE executed (l_user_id=' || l_user_id ||
            ', l_resp_id=' || l_resp_id || ', l_application_id=' ||
            l_application_id || '================');
            *\
    -------fnd_global.apps_initialize(11976, 50623, 660);
  
    \*---Change Organization (to p_from_organization_id)-----
    v_step := 'Step 40';
    v_bool := fnd_profile.save(x_name       => 'MFG_ORGANIZATION_ID',
                               x_value      => p_from_organization_id, ---parameter
                               x_level_name => 'SITE');
    COMMIT;
    message('Change Organization====set profile MFG_ORGANIZATION_ID=' ||
            p_from_organization_id ||
            '====(equel to p_from_organization_id)============');*\
  
    v_step := 'Step 50';
    FOR trans_interface_rec IN c_get_trans_interface_data LOOP
    
      INSERT INTO mtl_transactions_interface
        (transaction_interface_id,
         creation_date,
         created_by,
         last_update_date,
         last_updated_by,
         source_code,
         source_line_id,
         source_header_id,
         process_flag,
         inventory_item_id,
         attribute1, ---SERIAL NUMBER
         attribute2, ---expiration_date
         organization_id,
         subinventory_code,
         locator_id,
         transaction_type_id,
         transaction_action_id,
         transaction_source_type_id,
         transaction_quantity,
         transaction_uom,
         transaction_date,
         transfer_organization,
         transfer_subinventory,
         transfer_locator,
         transaction_mode,
         revision)
      
      VALUES
        (mtl_material_transactions_s.nextval, ---transaction_interface_id
         SYSDATE, --- CREATION_DATE,
         fnd_global.user_id, --- CREATED_BY,
         SYSDATE, --- LAST_UPDATE_DATE, 
         fnd_global.user_id, --- LAST_UPDATE_BY,
         trans_interface_rec.type, --- SOURCE_CODE
         1, --- SOURCE_LINE_ID,
         1, --- SOURCE_HEADER_ID
         1, --- PROCESS_FLAG,
         trans_interface_rec.inventory_item_id, --- INVENTORY_ITEM_ID,
         trans_interface_rec.serial_number, --ATTRIBUTE1
         trans_interface_rec.expiration_date, --ATTRIBUTE2
         p_from_organization_id, --- ORGANIZATION_ID,
         trans_interface_rec.subinventory_code, --- SUBINVENTORY_CODE,
         trans_interface_rec.locator_id, ---locator_id
         3, --- TRANSACTION_TYPE_ID,
         3, --- TRANSACTION_ACTION_ID
         13, ---TRANSACTION_SOURCE_TYPE_ID
         trans_interface_rec.available_qty, --- TRANSACTION_QUANTITY,
         trans_interface_rec.transaction_uom_code, --- TRANSACTION_UOM,
         SYSDATE, --- TRANSACTION_DATE,
         trans_interface_rec.p_to_organization_id, --- TRANSFER_ORGANIZATION,
         trans_interface_rec.subinventory_code, --- TRANSFER_SUBINVENTORY,
         trans_interface_rec.to_locator_id, --- transfer_locator,
         3, --- TRANSACTION_MODE,
         trans_interface_rec.revision --- REVISION,
         --- SHIPMENT_NUMBER
         );
      v_inserted_records_counter := v_inserted_records_counter + 1;
    END LOOP;
    COMMIT;
    message(v_inserted_records_counter ||
            ' records were inserted into MTL_TRANSACTIONS_INTERFACE============');
  
    v_step := 'Step 60';
    FOR trans_lot_serial_interf_rec IN c_get_trans_lot_ser_interf_d LOOP
      v_step := 'Step 70';
      IF trans_lot_serial_interf_rec.source_code = 'OBJ_CST_SERIAL' THEN
        INSERT INTO mtl_serial_numbers_interface
          (transaction_interface_id,
           last_update_date,
           last_updated_by,
           created_by,
           creation_date,
           fm_serial_number,
           to_serial_number,
           parent_item_id)
        VALUES
          (trans_lot_serial_interf_rec.transaction_interface_id,
           trans_lot_serial_interf_rec.last_update_date,
           trans_lot_serial_interf_rec.last_updated_by,
           trans_lot_serial_interf_rec.created_by,
           trans_lot_serial_interf_rec.creation_date,
           trans_lot_serial_interf_rec.fm_serial,
           trans_lot_serial_interf_rec.to_serial,
           trans_lot_serial_interf_rec.inventory_item_id);
        v_inserted_ser_records_counter := v_inserted_ser_records_counter + 1;
      END IF;
      COMMIT;
      v_step := 'Step 80';
      IF trans_lot_serial_interf_rec.source_code = 'OBJ_CST_LOT' THEN
        INSERT INTO mtl_transaction_lots_interface
          (transaction_interface_id,
           lot_number,
           transaction_quantity,
           last_update_date,
           last_updated_by,
           creation_date,
           created_by,
           parent_item_id,
           lot_expiration_date)
        VALUES
          (trans_lot_serial_interf_rec.transaction_interface_id,
           trans_lot_serial_interf_rec.fm_serial,
           trans_lot_serial_interf_rec.transaction_quantity,
           trans_lot_serial_interf_rec.last_update_date,
           trans_lot_serial_interf_rec.last_updated_by,
           trans_lot_serial_interf_rec.creation_date,
           trans_lot_serial_interf_rec.created_by,
           trans_lot_serial_interf_rec.inventory_item_id,
           trans_lot_serial_interf_rec.expiration_date);
        v_inserted_lot_records_counter := v_inserted_lot_records_counter + 1;
      END IF;
      COMMIT;
    END LOOP;
    COMMIT;
    message(v_inserted_ser_records_counter ||
            ' records were inserted into MTL_SERIAL_NUMBERS_INTERFACE==============');
    message(v_inserted_lot_records_counter ||
            ' records were inserted into MTL_TRANSACTION_LOTS_INTERFACE============');
  
    \*---=============== Submit 'Process transaction interface' concurrent program =====================
    v_step       := 'Step 200';
    v_request_id := fnd_request.submit_request(application => 'INV',
                                               program     => 'INCTCM');
    COMMIT;
    
    v_step := 'Step 210';
    IF v_request_id > 0 THEN
      message('Concurrent ''Process transaction interface'' was submitted successfully (request_id=' ||
              v_request_id || ')');
      ---------
      v_step := 'Step 220';
      LOOP
        v_bool := fnd_concurrent.wait_for_request(v_request_id,
                                                  5, --- interval 5  seconds
                                                  120, ---- max wait 120 seconds
                                                  x_phase,
                                                  x_status,
                                                  x_dev_phase,
                                                  x_dev_status,
                                                  x_message);
        EXIT WHEN x_return_bool AND upper(x_dev_phase) = 'COMPLETE';
      
      END LOOP;
    
      IF upper(x_dev_phase) = 'COMPLETE' AND
         upper(x_dev_status) IN ('ERROR', 'WARNING') THEN
        message('The ''Process transaction interface'' concurrent program completed in ' ||
                upper(x_dev_status) || '. See log for request_id=' ||
                v_request_id);
      
      ELSIF upper(x_dev_phase) = 'COMPLETE' AND
            upper(x_dev_status) = 'NORMAL' THEN
        message('The ''Process transaction interface'' program SUCCESSFULLY COMPLETED for request_id=' ||
                v_request_id || '====================');
      
      ELSE
        message('The ''Process transaction interface'' request failed review log for Oracle request_id=' ||
                v_request_id);
        --retcode := '1';
      END IF;
    ELSE
      message('Concurrent ''Process transaction interface'' submitting PROBLEM');
      --errbuf  := 'Concurrent ''Process transaction interface'' submitting PROBLEM';
      --retcode := '2';
    END IF;
    
    ---=============== Submit 'Manager: Lot Move Transactions' concurrent program =====================
    v_step       := 'Step 300';
    v_request_id := fnd_request.submit_request(application => 'WSM',
                                               program     => 'WSCMTM');
    COMMIT;
    
    v_step := 'Step 310';
    IF v_request_id > 0 THEN
      message('Concurrent ''Manager: Lot Move Transactions'' was submitted successfully (request_id=' ||
              v_request_id || ')');
      ---------
      v_step := 'Step 320';
      LOOP
        v_bool := fnd_concurrent.wait_for_request(v_request_id,
                                                  5, --- interval 5  seconds
                                                  120, ---- max wait 120 seconds
                                                  x_phase,
                                                  x_status,
                                                  x_dev_phase,
                                                  x_dev_status,
                                                  x_message);
        EXIT WHEN x_return_bool AND upper(x_dev_phase) = 'COMPLETE';
      
      END LOOP;
    
      IF upper(x_dev_phase) = 'COMPLETE' AND
         upper(x_dev_status) IN ('ERROR', 'WARNING') THEN
        message('The ''Manager: Lot Move Transactions'' concurrent program completed in ' ||
                upper(x_dev_status) || '. See log for request_id=' ||
                v_request_id);
      
      ELSIF upper(x_dev_phase) = 'COMPLETE' AND
            upper(x_dev_status) = 'NORMAL' THEN
        message('The ''Manager: Lot Move Transactions'' program SUCCESSFULLY COMPLETED for request_id=' ||
                v_request_id || '====================');
      
      ELSE
        message('The ''Manager: Lot Move Transactions'' request failed review log for Oracle request_id=' ||
                v_request_id);
        --retcode := '1';
      END IF;
    ELSE
      message('Concurrent ''Manager: Lot Move Transactions'' submitting PROBLEM');
      --errbuf  := 'Concurrent ''Manager: Lot Move Transactions'' submitting PROBLEM';
      --retcode := '2';
    END IF; *\
  
    v_step := 'Step 400';
    -----message('RESULTS =========================================================');
    ----message('Concurrent program was completed successfully ===================');
    message('TRANSFER_OH_QTY_TPL was completed ==================');
    ----message('=================================================================');
  
  EXCEPTION
    WHEN stop_processing THEN
      v_error_message := 'ERROR in xxconv_inv_onhand_pkg.transfer_oh_qty: ' ||
                         v_error_message;
      message(v_error_message);
      --retcode := '2';
    --errbuf  := v_error_message;
    WHEN OTHERS THEN
      v_error_message := substr('Unexpected ERROR in xxconv_inv_onhand_pkg.transfer_oh_qty (' ||
                                v_step || ') ' || SQLERRM,
                                1,
                                200);
      message(v_error_message);
      --retcode := '2';
    --errbuf  := v_error_message;
  END transfer_oh_qty_tpl;*/
  --------------------------------------------------------------------
  -- handle_new_intransit_shipment
  -- CR1178 - Receive and  re-ship intransit shipment at cutover.
  -------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -----------------------------
  --     1.0  8.12.13    Vitaly         initial build 
  --------------------------------------------------------------------
  PROCEDURE handle_new_intransit_shipment(errbuf               OUT VARCHAR2,
                                          retcode              OUT VARCHAR2,
                                          p_shipment_header_id NUMBER,
                                          p_request_id         NUMBER) IS
  
    CURSOR c_get_intransit_shipment_data IS
      SELECT CASE
               WHEN t.lot_number IS NULL AND t.from_serial_number IS NULL THEN
                'XXX'
               WHEN t.lot_number IS NOT NULL THEN
                'OBJ_CST_LOT'
               ELSE
                'OBJ_CST_SERIAL'
             END source_code,
             t.rowid row_id,
             t.shipment_number,
             t.shipment_number || 'X' new_shipment_number,
             t.shipment_line_id,
             t.shipment_line_number,
             t.item_id,
             t.item_code,
             t.revision,
             t.lot_number,
             t.lot_expiration_date,
             t.from_serial_number,
             t.to_serial_number,
             t.qty_received * -1 qty,
             t.qty_uom_code uom_code,
             t.subinventory,
             t.subinventory_for_receipt,
             t.expected_receipt_date,
             ----t.locator_id ship_from_locator_id,
             t.organization_id ship_from_organization_id,
             mp.organization_code ship_from_organization_code,
             CASE ----'WPI' --> 'IPK'=735 ,'ITA'=736
               WHEN mp.organization_code = 'WPI' AND
                    nvl(msi.attribute9, 'N') = 'Y' THEN
                736 ---'ITA'
               WHEN mp.organization_code = 'WPI' AND
                    nvl(msi.attribute9, 'N') = 'N' THEN
                735 ---'IPK'
               ELSE
                to_number(orgmap.new_organization_id)
             END ship_to_organization_id,
             CASE ----'WPI' --> 'IPK'=735 ,'ITA'=736
               WHEN mp.organization_code = 'WPI' AND
                    nvl(msi.attribute9, 'N') = 'Y' THEN
                'ITA' ---736
               WHEN mp.organization_code = 'WPI' AND
                    nvl(msi.attribute9, 'N') = 'N' THEN
                'IPK' ---735
               ELSE
                orgmap.new_organization_code
             END ship_to_organization_code
        FROM xxinv_cost_org_map_v      orgmap,
             mtl_parameters            mp,
             xxconv_inv_trx            t,
             mtl_secondary_inventories msi
       WHERE t.shipment_header_id = p_shipment_header_id ---parameter
         AND t.request_id = p_request_id ---parameter
         AND t.status = 'S'
         AND t.organization_id = msi.organization_id(+)
         AND nvl(t.subinventory, 'XXXYYYZZZ') =
             msi.secondary_inventory_name(+)
         AND orgmap.organization_id != orgmap.new_organization_id
         AND orgmap.organization_id = t.organization_id
         AND t.organization_id = mp.organization_id
       ORDER BY t.shipment_line_number;
  
    l_inserted_mtl_trans_int      NUMBER := 0;
    l_inserted_mtl_trans_lots_int NUMBER := 0;
    l_inserted_mtl_serial_num_int NUMBER := 0;
    l_error_message               VARCHAR2(3000);
    l_lot_serial_str              VARCHAR2(3000);
  
  BEGIN
    errbuf  := 'Success';
    retcode := '0';
  
    /*fnd_global.apps_initialize(1171, 50623, 660); ---CONVERSION-----Implementation Manufacturing, OBJET
    mo_global.set_policy_context('S', 161 \*p_org_id*\);
    inv_globals.set_org_id(161 \*p_org_id*\);
    mo_global.init('INV');*/
  
    FOR intransit_shipment_rec IN c_get_intransit_shipment_data LOOP
      l_lot_serial_str := NULL;
      INSERT INTO mtl_transactions_interface
        (transaction_interface_id,
         expected_arrival_date,
         creation_date,
         created_by,
         last_update_date,
         last_updated_by,
         source_code,
         source_line_id,
         source_header_id,
         process_flag,
         inventory_item_id,
         revision,
         attribute1, ---SERIAL NUMBER / LOT NUMBER
         attribute2, ---expiration_date
         organization_id,
         subinventory_code,
         ---locator_id,
         ---------------------------------------------------------------
         transfer_subinventory, --transfer_subinventory
         ---transfer_locator, --transfer_locator
         transfer_organization, --transfer_organization
         shipment_number, --shipment_number
         ----------------------------------------------------------------
         transaction_type_id,
         transaction_action_id,
         transaction_source_type_id,
         transaction_quantity,
         transaction_uom,
         transaction_date,
         transaction_reference,
         transaction_mode)
      VALUES
        (mtl_material_transactions_s.nextval, ---transaction_interface_id
         intransit_shipment_rec.expected_receipt_date, ---expected_arrival_date
         SYSDATE, --- CREATION_DATE,
         fnd_global.user_id, --- CREATED_BY,
         SYSDATE, --- LAST_UPDATE_DATE, 
         fnd_global.user_id, --- LAST_UPDATE_BY,
         intransit_shipment_rec.source_code, --- SOURCE_CODE
         1, --- SOURCE_LINE_ID,
         1, --- SOURCE_HEADER_ID
         1, --- PROCESS_FLAG, ---1=pending
         intransit_shipment_rec.item_id, --- INVENTORY_ITEM_ID,
         intransit_shipment_rec.revision,
         nvl(intransit_shipment_rec.from_serial_number,
             intransit_shipment_rec.lot_number), --ATTRIBUTE1  (SERIAL NUM / LOT NUM)
         intransit_shipment_rec.lot_expiration_date, --ATTRIBUTE2
         intransit_shipment_rec.ship_from_organization_id, --- ORGANIZATION_ID,
         intransit_shipment_rec.subinventory_for_receipt, --- SUBINVENTORY_CODE,
         ---intransit_shipment_rec.ship_from_locator_id, ---locator_id
         intransit_shipment_rec.subinventory, --transfer_subinventory
         ---intransit_shipment_rec.ship_to_locator_id, --transfer_locator
         intransit_shipment_rec.ship_to_organization_id, --transfer_organization
         intransit_shipment_rec.new_shipment_number, --shipment_number
         21, --- TRANSACTION_TYPE_ID, ------21= Intransit Shipment
         21, --- TRANSACTION_ACTION_ID
         13, ---TRANSACTION_SOURCE_TYPE_ID
         intransit_shipment_rec.qty, --- TRANSACTION_QUANTITY,
         intransit_shipment_rec.uom_code, --- TRANSACTION_UOM,
         SYSDATE, --- TRANSACTION_DATE,
         'Original shipment_line_id=' ||
         intransit_shipment_rec.shipment_line_id, ----transaction_reference,
         3 --- TRANSACTION_MODE,
         );
      l_inserted_mtl_trans_int := l_inserted_mtl_trans_int + 1;
    
      IF intransit_shipment_rec.source_code = 'OBJ_CST_LOT' THEN
        --------------
        INSERT INTO mtl_transaction_lots_interface
          (transaction_interface_id,
           lot_number,
           transaction_quantity,
           last_update_date,
           last_updated_by,
           creation_date,
           created_by,
           parent_item_id,
           lot_expiration_date)
        VALUES
          (mtl_material_transactions_s.currval, ---transaction_interface_id
           intransit_shipment_rec.lot_number, ---lot_number
           intransit_shipment_rec.qty, ---transaction_quantity
           SYSDATE, ---last_update_date,
           fnd_global.user_id, --- last_updated_by,
           SYSDATE, ---creation_date,
           fnd_global.user_id, --- created_by,
           intransit_shipment_rec.item_id, ---parent_item_id
           intransit_shipment_rec.lot_expiration_date); ---lot_expiration_date
      
        l_inserted_mtl_trans_lots_int := l_inserted_mtl_trans_lots_int + 1;
        l_lot_serial_str              := ' lot=' ||
                                         intransit_shipment_rec.lot_number ||
                                         ', qty=' ||
                                         intransit_shipment_rec.qty;
        ---------------  
      ELSIF intransit_shipment_rec.source_code = 'OBJ_CST_SERIAL' THEN
        --------------
        INSERT INTO mtl_serial_numbers_interface
          (transaction_interface_id,
           fm_serial_number,
           to_serial_number,
           last_update_date,
           last_updated_by,
           creation_date,
           created_by,
           parent_item_id)
        VALUES
          (mtl_material_transactions_s.currval, ---transaction_interface_id
           intransit_shipment_rec.from_serial_number, ---fm_serial_number
           intransit_shipment_rec.from_serial_number, ---to_serial_number
           SYSDATE, ---last_update_date,
           fnd_global.user_id, --- last_updated_by,
           SYSDATE, ---creation_date,
           fnd_global.user_id, --- created_by,
           intransit_shipment_rec.item_id); ---parent_item_id
      
        l_inserted_mtl_serial_num_int := l_inserted_mtl_serial_num_int + 1;
        l_lot_serial_str              := ' serial=' ||
                                         intransit_shipment_rec.from_serial_number;
        ---------------          
      END IF; ---if intransit_shipment_rec.source_code='OBJ_CST_LOT' THEN
      IF l_lot_serial_str IS NULL THEN
        l_lot_serial_str := ' qty=' || intransit_shipment_rec.qty;
      END IF;
    
      UPDATE xxconv_inv_trx t
         SET t.intrans_ship_intrface_trans_id = mtl_material_transactions_s.currval,
             t.new_ship_organization_id       = intransit_shipment_rec.ship_to_organization_id
       WHERE t.rowid = intransit_shipment_rec.row_id;
      ------------------------------------
    /*message('NEW Intransit Shipment----from ' ||intransit_shipment_rec.ship_from_organization_code || ' (' ||intransit_shipment_rec.item_code || '----' || l_lot_serial_str);*/
    END LOOP;
    COMMIT; --- COMMIT --- COMMIT --- COMMIT --- COMMIT --- COMMIT --- 
  
    IF l_inserted_mtl_trans_int = 0 THEN
      l_error_message := 'ERROR: NO RECORDS INSERTED INTO MTL_TRANSACTIONS_INTERFACE';
      retcode         := '2';
      errbuf          := l_error_message;
    ELSE
      NULL;
      /*message(l_inserted_mtl_trans_int ||
      ' records inserted into table MTL_TRANSACTIONS_INTERFACE');*/
    END IF;
    IF l_inserted_mtl_trans_lots_int > 0 THEN
      NULL;
      /*message(l_inserted_mtl_trans_lots_int ||
      ' records inserted into table MTL_TRANSACTION_LOTS_INTERFACE');*/
    END IF;
    IF l_inserted_mtl_serial_num_int > 0 THEN
      NULL;
      /*message(l_inserted_mtl_serial_num_int ||
      ' records inserted into table MTL_SERIAL_NUMBERS_INTERFACE');*/
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      retcode := '2';
      errbuf  := SQLERRM;
      fnd_file.put_line(fnd_file.log,
                        'Error in HANDLE_NEW_INTRANSIT_SHIPMENT: ' ||
                        SQLERRM);
    
  END handle_new_intransit_shipment;
  --------------------------------------------------------------------
  -- validate_existing_quantities
  -- CR1178 - Receive and  re-ship intransit shipment at cutover.
  -------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -----------------------------
  --     1.0  8.12.13    Vitaly         initial build 
  --------------------------------------------------------------------
  PROCEDURE validate_existing_quantities(errbuf               OUT VARCHAR2,
                                         retcode              OUT VARCHAR2,
                                         p_shipment_header_id NUMBER,
                                         p_request_id         IN NUMBER) IS
    CURSOR c_get_qty_should_be_received IS
      SELECT t.item_id,
             t.item_code,
             t.lot_number,
             t.from_serial_number,
             t.to_serial_number,
             t.organization_id,
             mp.organization_code,
             t.subinventory_for_receipt,
             SUM(t.qty_received) sum_qty
        FROM mtl_parameters mp, xxconv_inv_trx t
       WHERE t.shipment_header_id = p_shipment_header_id ---parameter
         AND t.request_id = p_request_id ---parameter
         AND t.status = 'S'
         AND t.organization_id = mp.organization_id
       GROUP BY t.item_id,
                t.item_code,
                t.lot_number,
                t.from_serial_number,
                t.to_serial_number,
                t.organization_id,
                mp.organization_code,
                t.subinventory_for_receipt;
  
    l_onhand_qty    NUMBER;
    l_error_message VARCHAR2(1000);
  
  BEGIN
    retcode := '0';
    errbuf  := 'Success';
  
    FOR det_rec IN c_get_qty_should_be_received LOOP
      IF det_rec.lot_number IS NOT NULL THEN
        --------- LOT -----------------------
        BEGIN
          SELECT SUM(t.total_qoh)
            INTO l_onhand_qty
            FROM mtl_onhand_lot_v          t,
                 mtl_item_locations_kfv    v,
                 mtl_secondary_inventories mss
           WHERE t.organization_id = det_rec.organization_id ----
             AND v.organization_id(+) = t.organization_id
             AND v.inventory_location_id(+) = t.locator_id
             AND mss.organization_id = t.organization_id
             AND nvl(mss.attribute9, 'N') = 'N'
             AND mss.secondary_inventory_name = t.subinventory_code
             AND t.lot = det_rec.lot_number -------
             AND t.inventory_item_id = det_rec.item_id ------
             AND t.subinventory_code = det_rec.subinventory_for_receipt; -------
        EXCEPTION
          WHEN no_data_found THEN
            l_onhand_qty := 0;
        END;
        ------
        IF det_rec.sum_qty > nvl(l_onhand_qty, 0) THEN
          l_error_message := 'Existing Qty Validation ERROR: Item_id=' ||
                             det_rec.item_id || ', Item_code=' ||
                             det_rec.item_code || ', lot=' ||
                             det_rec.lot_number ||
                             ' NOT FOUND in organization_id=' ||
                             det_rec.organization_id || ' (' ||
                             det_rec.organization_code || '), subinv=' ||
                             det_rec.subinventory_for_receipt ||
                             ', sum_qty should be received=' ||
                             det_rec.sum_qty || ', onhand_qty=' ||
                             l_onhand_qty;
          message(l_error_message);
          UPDATE xxconv_inv_trx a ---- all lines for this shipping_number are invalid
             SET a.status = 'E', a.err_message = l_error_message
           WHERE a.shipment_header_id = p_shipment_header_id ---parameter  
             AND a.status = 'S';
          COMMIT;
          RAISE stop_process;
        ELSE
          NULL;
          /*message('Existing Qty Validation SUCCESS: Item_id=' ||
          det_rec.item_id || ', Item_code=' || det_rec.item_code ||
          ', lot=' || det_rec.lot_number ||
          ' was FOUND in organization_id=' ||
          det_rec.organization_id || ' (' ||
          det_rec.organization_code || '), subinv=' ||
          det_rec.subinventory_for_receipt ||
          ', sum_qty should be received=' || det_rec.sum_qty ||
          ', onhand_qty=' || l_onhand_qty);*/
        END IF;
      
      ELSIF det_rec.from_serial_number IS NOT NULL THEN
        ------ SERIAL ----------------------------------
        BEGIN
          SELECT SUM(t.on_hand)
            INTO l_onhand_qty
            FROM mtl_onhand_serial_v t, mtl_secondary_inventories mss
           WHERE t.organization_id = det_rec.organization_id ------
             AND mss.organization_id = t.organization_id
             AND mss.secondary_inventory_name = t.subinventory_code
             AND nvl(mss.attribute9, 'N') = 'N'
             AND t.inventory_item_id = det_rec.item_id -----
             AND t.serial_number = det_rec.from_serial_number -------
             AND t.subinventory_code = det_rec.subinventory_for_receipt; -------
          /*message('Existing Qty Validation SUCCESS: Item_id=' ||
          det_rec.item_id || ', Item_code=' || det_rec.item_code ||
          ', serial_num=' || det_rec.from_serial_number ||
          ' was FOUND in organization_id=' ||
          det_rec.organization_id || ' (' ||
          det_rec.organization_code || '), subinv=' ||
          det_rec.subinventory_for_receipt);*/
        EXCEPTION
          WHEN no_data_found THEN
          
            l_error_message := 'Existing Qty Validation ERROR: Item_id=' ||
                               det_rec.item_id || ', Item_code=' ||
                               det_rec.item_code || ', serial_num=' ||
                               det_rec.from_serial_number ||
                               ' NOT FOUND in organization_id=' ||
                               det_rec.organization_id || ' (' ||
                               det_rec.organization_code || '), subinv=' ||
                               det_rec.subinventory_for_receipt;
            message(l_error_message);
            UPDATE xxconv_inv_trx a ---- all lines for this shipping_number are invalid
               SET a.status = 'E', a.err_message = l_error_message
             WHERE a.shipment_header_id = p_shipment_header_id ---parameter  
               AND a.status = 'S';
            COMMIT;
            RAISE stop_process;
        END;
        ------
      ELSE
        -----NO LOT and NO SERIAL----          
        BEGIN
          SELECT SUM(moq.transaction_quantity)
            INTO l_onhand_qty
            FROM mtl_onhand_quantities_detail moq,
                 mtl_item_locations_kfv       v,
                 mtl_secondary_inventories    mss,
                 mtl_system_items_b           msi,
                 mtl_parameters               mp
           WHERE msi.organization_id = moq.organization_id
             AND msi.inventory_item_id = moq.inventory_item_id
             AND NOT EXISTS
           (SELECT *
                    FROM mtl_onhand_serial_v w
                   WHERE w.inventory_item_id = moq.inventory_item_id
                     AND w.organization_id = moq.organization_id)
             AND moq.lot_number IS NULL
             AND moq.organization_id = det_rec.organization_id ----- 
             AND moq.inventory_item_id = det_rec.item_id -------
             AND v.organization_id(+) = moq.organization_id
             AND v.inventory_location_id(+) = moq.locator_id
             AND mss.organization_id = moq.organization_id
             AND mp.organization_id = moq.organization_id
             AND mss.secondary_inventory_name = moq.subinventory_code
             AND moq.subinventory_code = det_rec.subinventory_for_receipt; -------
        
        EXCEPTION
          WHEN no_data_found THEN
            l_onhand_qty := 0;
        END;
        ------
        IF det_rec.sum_qty > nvl(l_onhand_qty, 0) THEN
          l_error_message := 'Existing Qty Validation ERROR: Item_id=' ||
                             det_rec.item_id || ', Item_code=' ||
                             det_rec.item_code ||
                             ' NOT FOUND in organization_id=' ||
                             det_rec.organization_id || ' (' ||
                             det_rec.organization_code || '), subinv=' ||
                             det_rec.subinventory_for_receipt ||
                             ', sum_qty should be received=' ||
                             det_rec.sum_qty || ', onhand_qty=' ||
                             l_onhand_qty;
          message(l_error_message);
          UPDATE xxconv_inv_trx a ---- all lines for this shipping_number are invalid
             SET a.status = 'E', a.err_message = l_error_message
           WHERE a.shipment_header_id = p_shipment_header_id ---parameter  
             AND a.status = 'S';
          COMMIT;
          RAISE stop_process;
        ELSE
          NULL;
          /*message('Existing Qty Validation SUCCESS: Item_id=' ||
          det_rec.item_id || ', Item_code=' || det_rec.item_code ||
          ' was FOUND in organization_id=' ||
          det_rec.organization_id || ' (' ||
          det_rec.organization_code || '), subinv=' ||
          det_rec.subinventory_for_receipt ||
          ', sum_qty should be received=' || det_rec.sum_qty ||
          ', onhand_qty=' || l_onhand_qty);*/
        END IF;
        ------       
      END IF;
    END LOOP;
  
  EXCEPTION
    WHEN stop_process THEN
      retcode := '2';
      errbuf  := l_error_message;
    WHEN OTHERS THEN
      retcode := '2';
      errbuf  := 'Error in VALIDATE_EXISTING_QUANTITIES: ' ||
                 substr(SQLERRM, 1, 200);
    
  END validate_existing_quantities;
  --------------------------------------------------------------------
  -- handle_rcv_internal_trx
  -- CR1178 - Receive and  re-ship intransit shipment at cutover.
  -------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -----------------------------
  --     1.0  8.12.13    Vitaly         initial build 
  --------------------------------------------------------------------
  PROCEDURE handle_rcv_internal_trx(errbuf               OUT VARCHAR2,
                                    retcode              OUT VARCHAR2,
                                    p_shipment_header_id NUMBER,
                                    p_request_id         NUMBER) IS
  
    --l_err_code           NUMBER;
    l_err_message VARCHAR2(500);
    --l_user_id            NUMBER;
    --l_resp_id            NUMBER;
    --l_resp_appl_id       NUMBER;
    l_to_organization_id NUMBER;
    l_to_location_id     NUMBER;
    l_org_id             NUMBER;
  
    l_interface_transaction_id NUMBER;
    l_header_interface_id      NUMBER;
    l_group_id                 NUMBER;
  
    l_lot_serial_str               VARCHAR2(3000);
    l_lines_inserted_into_interfce NUMBER := 0;
  
    ---- out variables for fnd_concurrent.wait_for_request-----
    x_phase         VARCHAR2(100);
    x_status        VARCHAR2(100);
    x_dev_phase     VARCHAR2(100);
    x_dev_status    VARCHAR2(100);
    l_bool          BOOLEAN;
    l_request_id    NUMBER;
    x_message       VARCHAR2(500);
    g_sleep_mod_sec NUMBER := 30;
    g_sleep_mod     NUMBER := 500;
    g_sleep         NUMBER;
  
    CURSOR c_rcv_header IS
      SELECT DISTINCT t.order_header_id,
                      t.shipment_number,
                      t.from_organization_id
        FROM xxconv_inv_trx t
       WHERE t.status = 'N'
         AND t.request_id = p_request_id ---parameter
         AND t.shipment_header_id = p_shipment_header_id; ---parameter
  
    CURSOR c_rcv_lines(p_order_header_id NUMBER) IS
      SELECT t.rowid row_id, t.*
        FROM xxconv_inv_trx t
       WHERE t.status = 'N'
         AND t.request_id = p_request_id ---parameter
         AND t.shipment_header_id = p_shipment_header_id ---parameter
         AND t.order_header_id = p_order_header_id --cursor parameter
       ORDER BY t.shipment_line_number;
  
    CURSOR c_rcv_trx_interface(p_group_id NUMBER) IS
      SELECT t.rowid row_id, t.*
        FROM xxconv_inv_trx t
       WHERE t.status = 'I'
         AND t.request_id = p_request_id ---parameter
         AND t.interface_group_id = p_group_id ---cursor parameter
         AND t.shipment_header_id = p_shipment_header_id ---parameter
       ORDER BY t.shipment_line_number;
  
  BEGIN
    errbuf  := 'Success';
    retcode := '0';
  
    l_org_id := fnd_global.org_id;
  
    SELECT rcv_interface_groups_s.nextval INTO l_group_id FROM dual;
  
    SELECT 10 + round(COUNT(*) / g_sleep_mod) * g_sleep_mod_sec
      INTO g_sleep
      FROM xxconv_inv_trx t
     WHERE t.status = 'N'
       AND t.request_id = p_request_id; ---parameter
  
    FOR k IN c_rcv_header LOOP
      --------------- RECEIVING HEADER LOOP-------------------
      BEGIN
        SELECT org_tab.to_organization_id,
               decode(org_tab.to_organization_id,
                      461,
                      313944, --  HK    ATH - AP Temp 
                      121,
                      314011, --  HK    ASH - Temp Location 
                      181,
                      314012, --  CN    CSS - Temp Location 
                      101,
                      314013, --  DE    ESB - Temp Location 
                      102,
                      314014, --  DE    ETF - Temp Location 
                      661,
                      314015, --  DE    ERB - Temp Location 
                      684,
                      314016, --  JP    JST - Temp Location 
                      685,
                      314017, --  JP    JTT - Temp Location 
                      93,
                      314018, --  IL    ISK - Temp Location 
                      92,
                      314021, --  IL    IRK - Temp Location 
                      90,
                      314057, --  IL    IPK Temp Location 
                      -777) location_id
          INTO l_to_organization_id, l_to_location_id
          FROM (SELECT MAX(a.organization_id) to_organization_id
                  FROM xxconv_inv_trx a
                 WHERE a.order_header_id = k.order_header_id) org_tab;
      
        INSERT INTO rcv_headers_interface
          (org_id,
           header_interface_id,
           group_id,
           processing_status_code,
           receipt_source_code,
           transaction_type,
           last_update_date,
           last_updated_by,
           last_update_login,
           creation_date,
           created_by,
           shipment_num,
           ship_to_organization_id,
           employee_id,
           validation_flag,
           transaction_date,
           packing_slip)
        VALUES
          (l_org_id ---> ORG_ID
          ,
           rcv_headers_interface_s.nextval ---> HEADER_INTERFACE_ID
          ,
           l_group_id ---> GROUP_ID
          ,
           'PENDING' ---> PROCESSING_STATUS_CODE
          ,
           'INTERNAL ORDER' ---> RECEIPT_SOURCE_CODE
          ,
           'NEW' ---> TRANSACTION_TYPE
          ,
           SYSDATE ---> LAST_UPDATE_DATE
          ,
           fnd_global.user_id ---> LAST_UPDATED_BY
          ,
           0 ---> LAST_UPDATE_LOGIN
          ,
           SYSDATE ---> CREATION_DATE
          ,
           fnd_global.user_id ---> CREATED_BY
          ,
           k.shipment_number ---> SHIPMENT_NUM
          ,
           l_to_organization_id ---> SHIP_TO_ORGANIZATION_ID
          ,
           fnd_global.employee_id ---> EMPLOYEE_ID
          ,
           'Y' ---> VALIDATION_FLAG
          ,
           NULL ---> TRANSACTION_DATE
          ,
           NULL ---> PACKING_SLIP
           )
        RETURNING group_id, header_interface_id INTO l_group_id, l_header_interface_id;
      END;
    
      FOR i IN c_rcv_lines(k.order_header_id) LOOP
        --------------- RECEIVING LINES LOOP-------------------------
        l_lot_serial_str               := NULL;
        l_lines_inserted_into_interfce := l_lines_inserted_into_interfce + 1;
        INSERT INTO rcv_transactions_interface
          (interface_transaction_id,
           group_id,
           last_update_date,
           last_updated_by,
           creation_date,
           created_by,
           last_update_login,
           transaction_type,
           transaction_date,
           processing_status_code,
           processing_mode_code,
           transaction_status_code,
           quantity,
           uom_code,
           interface_source_code,
           item_id,
           employee_id,
           auto_transact_code,
           shipment_header_id,
           shipment_line_id,
           ship_to_location_id,
           receipt_source_code,
           to_organization_id,
           source_document_code,
           requisition_line_id,
           req_distribution_id,
           destination_type_code,
           deliver_to_person_id,
           location_id,
           deliver_to_location_id,
           subinventory,
           ----locator_id, ---no locators in our subinv for receipt
           shipment_num,
           shipped_date,
           header_interface_id,
           validation_flag,
           org_id)
        VALUES
          (rcv_transactions_interface_s.nextval, -- INTERFACE_TRANSACTION_ID
           l_group_id, -- GROUP_ID
           SYSDATE, -- LAST_UPDATE_DATE
           fnd_global.user_id, -- LAST_UPDATED_BY
           SYSDATE, -- CREATION_DATE
           fnd_global.user_id, -- CREATED_BY  
           NULL, -- LAST_UPDATE_LOGIN
           'RECEIVE', -- TRANSACTION_TYPE
           SYSDATE, -- TRANSACTION_DATE
           'PENDING', -- PROCESSING_STATUS_CODE
           'BATCH', -- PROCESSING_MODE_CODE
           'PENDING', -- TRANSACTION_STATUS_CODE
           i.qty_received, -- QUANTITY
           i.qty_uom_code, -- UNIT_OF_MEASURE
           'RCV', -- INTERFACE_SOURCE_CODE
           i.item_id, -- ITEM_ID
           NULL, -- EMPLOYEE_ID
           'DELIVER', -- AUTO_TRANSACT_CODE
           i.shipment_header_id, -- SHIPMENT_HEADER_ID
           i.shipment_line_id, -- SHIPMENT_LINE_ID
           NULL, -- SHIP_TO_LOCATION_ID
           'INTERNAL ORDER', -- RECEIPT_SOURCE_CODE
           l_to_organization_id, -- TO_ORGANIZATION_ID
           'REQ', -- SOURCE_DOCUMENT_CODE
           NULL, -- REQUISITION_LINE_ID
           NULL, -- REQ_DISTRIBUTION_ID
           'INVENTORY', -- DESTINATION_TYPE_CODE
           NULL, -- DELIVER_TO_PERSON_ID
           l_to_location_id, --- LOCATION_ID
           l_to_location_id, --- DELIVER_TO_LOCATION_ID
           i.subinventory_for_receipt, -- SUBINVENTORY
           ---i.locator_id, -- LOCATOR_ID
           i.shipment_number, -- SHIPMENT_NUM
           NULL, -- SHIPPED_DATE
           rcv_headers_interface_s.currval, -- HEADER_INTERFACE_ID
           'Y', -- VALIDATION_FLAG
           l_org_id)
        RETURNING interface_transaction_id INTO l_interface_transaction_id;
      
        ---  insert serial /lot -------------
        -- if lot control
        IF i.lot_number IS NOT NULL THEN
          INSERT INTO mtl_transaction_lots_interface
            (transaction_interface_id,
             last_update_date,
             last_updated_by,
             creation_date,
             created_by,
             last_update_login,
             lot_number,
             transaction_quantity,
             primary_quantity,
             serial_transaction_temp_id,
             product_code,
             product_transaction_id,
             parent_item_id)
          VALUES
            (l_interface_transaction_id, --mtl_material_transactions_s.currval, --TRANSACTION_INTERFACE_ID
             SYSDATE, --LAST_UPDATE_DATE
             fnd_global.user_id, --LAST_UPDATED_BY
             SYSDATE, --CREATION_DATE
             fnd_global.user_id, --CREATED_BY
             fnd_global.login_id, --LAST_UPDATE_LOGIN
             i.lot_number, --LOT_NUMBER
             i.qty_received, --TRANSACTION_QUANTITY
             i.qty_received, --PRIMARY_QUANTITY
             NULL, --  mtl_material_transactions_s.nextval, --SERIAL_TRANSACTION_TEMP_ID
             'RCV', --PRODUCT_CODE
             rcv_transactions_interface_s.currval, --PRODUCT_TRANSACTION_ID
             i.item_id);
        
          l_lot_serial_str := ' lot=' || i.lot_number || ', qty=' ||
                              i.qty_received;
        END IF;
      
        --  if serial control
        IF i.from_serial_number IS NOT NULL THEN
          INSERT INTO mtl_serial_numbers_interface
            (transaction_interface_id,
             last_update_date,
             last_updated_by,
             creation_date,
             created_by,
             last_update_login,
             fm_serial_number,
             to_serial_number,
             product_code,
             product_transaction_id,
             parent_item_id)
          VALUES
            (l_interface_transaction_id, --mtl_material_transactions_s.currval, --TRANSACTION_INTERFACE_ID
             SYSDATE, --LAST_UPDATE_DATE
             fnd_global.user_id, --LAST_UPDATED_BY
             SYSDATE, --CREATION_DATE
             fnd_global.user_id, --CREATED_BY
             fnd_global.login_id, --LAST_UPDATE_LOGIN
             i.from_serial_number, --FM_SERIAL_NUMBER
             i.to_serial_number, --TO_SERIAL_NUMBER
             'RCV', --PRODUCT_CODE
             rcv_transactions_interface_s.currval, --PRODUCT_TRANSACTION_ID,
             i.item_id);
          l_lot_serial_str := ' serial=' || i.from_serial_number;
        END IF;
      
        ------------- update interface id's
        UPDATE xxconv_inv_trx
           SET status                   = 'I', ---Interfaced
               interface_transaction_id = l_interface_transaction_id,
               header_interface_id      = l_header_interface_id,
               interface_group_id       = l_group_id
         WHERE trx_id = i.trx_id;
        COMMIT;
        --------------------------------------
        IF l_lot_serial_str IS NULL THEN
          ---NO LOT, NO SERIAL ITEM-----
          l_lot_serial_str := ', qty=' || i.qty_received;
        END IF;
        /*message('Receiving ''OLD'' Shipment Line ' ||
        i.shipment_line_number || ' (id=' || i.shipment_line_id ||
        ') ***** item=' || i.item_code || ', ' || l_lot_serial_str);*/
      --------------- the end of RECEIVING LINES LOOP-------------------
      END LOOP;
      --------------- the end of RECEIVING HEADER LOOP-------------------
    END LOOP; -- packing slip--
  
    /*message(l_lines_inserted_into_interfce ||
    ' records inserted into Open Interface tables for ''Receiving Transaction Processor''');*/
    IF l_lines_inserted_into_interfce = 0 THEN
      errbuf  := 'ERROR: NO RECORDS INSERTED into Open Interface tables for ''Receiving Transaction Processor''';
      retcode := '2';
      RETURN;
    END IF;
  
    -- run Receiving Transaction Processor  
    l_request_id := fnd_request.submit_request(application => 'PO',
                                               program     => 'RVCTP',
                                               argument1   => 'BATCH',
                                               argument2   => l_group_id,
                                               argument3   => l_org_id);
    COMMIT;
  
    -- v_step := 'Step 210';
    IF l_request_id > 0 THEN
      ---message('Concurrent ''Receiving Transaction Processor'' was submitted successfully for request_id=' ||
      ---        l_request_id);
      ---------
    
      l_bool := fnd_concurrent.wait_for_request(l_request_id,
                                                10, --- interval 10  seconds
                                                600, ---- max wait 600 seconds
                                                x_phase,
                                                x_status,
                                                x_dev_phase,
                                                x_dev_status,
                                                x_message);
    
      IF upper(x_dev_phase) = 'COMPLETE' AND
         upper(x_dev_status) IN ('ERROR', 'WARNING') THEN
        l_err_message := 'The ''Receiving Transaction Processor'' concurrent program completed in ' ||
                         upper(x_dev_status) || '. See log for request_id=' ||
                         l_request_id;
        update_rcv_status(errbuf               => errbuf,
                          retcode              => retcode,
                          p_status             => 'E',
                          p_err_message        => l_err_message,
                          p_shipment_header_id => p_shipment_header_id);
      
        UPDATE rcv_headers_interface t
           SET t.processing_status_code = 'ERROR'
         WHERE t.group_id = l_group_id;
        COMMIT;
        errbuf  := l_err_message;
        retcode := '2';
        RETURN;
      
      ELSIF upper(x_dev_phase) = 'COMPLETE' AND
            upper(x_dev_status) = 'NORMAL' THEN
        ---message('The ''Receiving Transaction Processor'' program SUCCESSFULLY COMPLETED for request_id=' ||
        ---        l_request_id);
        NULL;
      ELSE
        l_err_message := 'The ''Receiving Transaction Processor'' request failed review log for Oracle request_id=' ||
                         l_request_id;
        update_rcv_status(errbuf               => errbuf,
                          retcode              => retcode,
                          p_status             => 'E',
                          p_err_message        => l_err_message,
                          p_shipment_header_id => p_shipment_header_id);
      
        UPDATE rcv_headers_interface t
           SET t.processing_status_code = 'ERROR'
         WHERE t.group_id = l_group_id;
        COMMIT;
      
        errbuf  := l_err_message;
        retcode := '2';
        RETURN;
      END IF;
    ELSE
      l_err_message := 'Concurrent ''Process transaction interface'' submitting PROBLEM';
      update_rcv_status(errbuf               => errbuf,
                        retcode              => retcode,
                        p_status             => 'E',
                        p_err_message        => l_err_message,
                        p_shipment_header_id => p_shipment_header_id);
    
      UPDATE rcv_headers_interface t
         SET t.processing_status_code = 'ERROR'
       WHERE t.group_id = l_group_id;
      COMMIT;
    
      errbuf  := l_err_message;
      retcode := '2';
      RETURN;
    
    END IF;
  
    dbms_lock.sleep(g_sleep);
  
    ---============================================================================
    ---============ Check RECEIVING OPEN INTERFACE errors =========================
    ---============================================================================
    ----message('++++++++++BEFORE Check RECEIVING OPEN INTERFACE errors-----batch_id=' ||
    ---        p_batch_id || ', group_id=' || l_group_id ||
    ---        ', shipment_header_id=' || p_shipment_header_id ||
    ---        ' +++++++++++++++++++++++++++++');
    FOR j IN c_rcv_trx_interface(l_group_id) LOOP
      BEGIN
        SELECT 'Receiving Open Interface ERROR: ' || t.error_message
          INTO l_err_message
          FROM po.po_interface_errors t
         WHERE t.interface_header_id = j.header_interface_id
              ----AND t.interface_transaction_id = j.interface_transaction_id
           AND t.interface_line_id = j.interface_transaction_id
           AND rownum = 1;
        ---message('++++++++++++++++++++++++++++++++++ STATUS=' || j.status ||
        ----        '+++++++++++++++++++++++++++++');
        update_rcv_status(errbuf               => errbuf,
                          retcode              => retcode,
                          p_status             => 'E',
                          p_err_message        => l_err_message,
                          p_shipment_header_id => p_shipment_header_id
                          ----p_trx_id             => j.trx_id
                          );
      
        RAISE stop_process;
      EXCEPTION
        WHEN no_data_found THEN
          /*message('RECEIVING SUCCESS for "OLD" shipment_header_id=' ||
          p_shipment_header_id || ', "OLD" shipment_line_id=' ||
          j.shipment_line_id);*/
          update_rcv_status(errbuf               => errbuf,
                            retcode              => retcode,
                            p_status             => 'S',
                            p_err_message        => '',
                            p_shipment_header_id => p_shipment_header_id,
                            p_trx_id             => j.trx_id);
        
      END;
    END LOOP;
  
    ---============================================================================
    ---============ Check FULLY RECEIVED  =========================================
    ---============================================================================
    validate_existing_quantities(errbuf               => l_err_message,
                                 retcode              => retcode,
                                 p_shipment_header_id => p_shipment_header_id,
                                 p_request_id         => p_request_id);
    IF retcode <> '0' THEN
      RAISE stop_process;
    ELSE
      -----message('VALIDATION Existing Qty (after receiving) SUCCESS');
      NULL;
    END IF;
  
    ------------------------------------
  EXCEPTION
    WHEN stop_process THEN
      retcode := '2';
      errbuf  := l_err_message;
    
    WHEN OTHERS THEN
    
      ROLLBACK;
      retcode := '2';
      errbuf  := SQLERRM;
      fnd_file.put_line(fnd_file.log,
                        'Error in HANDLE_RCV_INTERNAL_TRX process');
    
  END handle_rcv_internal_trx;
  --------------------------------------------------------------------
  -- update_rcv_status
  -- CR1178 - Receive and  re-ship intransit shipment at cutover.
  -------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -----------------------------
  --     1.0  8.12.13    Vitaly         initial build 
  --------------------------------------------------------------------
  PROCEDURE update_rcv_status(errbuf               OUT VARCHAR2,
                              retcode              OUT VARCHAR2,
                              p_status             VARCHAR2,
                              p_err_message        VARCHAR2,
                              p_shipment_header_id NUMBER,
                              p_trx_id             NUMBER DEFAULT NULL) IS
  
  BEGIN
    retcode := 0;
    UPDATE xxconv_inv_trx t
       SET t.status            = p_status,
           t.err_message       = p_err_message,
           t.last_update_date  = SYSDATE,
           t.last_updated_by   = fnd_global.user_id,
           t.last_update_login = fnd_global.login_id
     WHERE t.shipment_header_id = p_shipment_header_id ---parameter
       AND t.trx_id = nvl(p_trx_id, t.trx_id); ---parameter
  
    COMMIT;
  
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      retcode := '2';
      errbuf  := 'Error in UPDATE_STATUS: ' || substr(SQLERRM, 1, 200);
    
  END update_rcv_status;
  --------------------------------------------------------------------
  -- populate_rcv_file
  -- CR1178 - Receive and  re-ship intransit shipment at cutover.
  -------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -----------------------------
  --     1.0  8.12.13    Vitaly         initial build 
  --------------------------------------------------------------------
  PROCEDURE populate_rcv_file(errbuf            OUT VARCHAR2,
                              retcode           OUT VARCHAR2,
                              p_org_id          IN NUMBER,
                              p_shipment_number IN VARCHAR2,
                              p_request_id      IN NUMBER) IS
  
    l_err_message VARCHAR2(2000);
    stop_process     EXCEPTION;
    l_done_exception EXCEPTION;
    --
    l_num_of_inserted_records NUMBER := 0;
    CURSOR c_rcv IS
      SELECT org.operating_unit org_id,
             ou.name operating_unit,
             NULL customer_name,
             org.organization_name supplier_name,
             shh.shipment_header_id shipment_header_id,
             shh.shipment_num shipment_number,
             shl.shipment_line_id shipment_line_id,
             shl.line_num shipment_line_number,
             rha.requisition_header_id order_header_id,
             to_number(rha.segment1) order_number,
             shl.requisition_line_id order_line_id,
             to_number(rla.line_num) order_line_number,
             NULL po_line_location_id,
             NULL service_request_reference,
             shh.expected_receipt_date expected_receipt_date,
             shl.from_organization_id from_organization_id,
             shl.to_organization_id to_organization_id,
             shl.item_id item_id,
             sib.segment1 item_code,
             NULL supplier_item_code,
             decode(msn.inventory_item_id, NULL, shl.quantity_shipped, 1) qty_ordered,
             sib.primary_uom_code qty_uom_code,
             tln.lot_number lot_number,
             mln.expiration_date lot_expiration_date,
             mms.status_code lot_status,
             msn.serial_number serial_number,
             mmt.revision revision,
             shl.to_subinventory subinventory, --from original Intransit Shipment--Will be in use in New Intransit Shipment
             subinv_for_receipt.secondary_inventory_name subinventory_for_receipt --for receiving only (no locators in these subinv)
        FROM rcv_shipment_lines shl,
             rcv_shipment_headers shh,
             mtl_system_items_b sib,
             mtl_material_transactions mmt,
             mtl_transaction_lot_numbers tln,
             mtl_lot_numbers mln,
             mtl_material_statuses mms,
             mtl_serial_numbers msn,
             org_organization_definitions org,
             hr_operating_units ou,
             po_requisition_headers_all rha,
             po_requisition_lines_all rla,
             (SELECT s.organization_id, s.secondary_inventory_name ---for receiving only (no locators in these subinv)
                FROM mtl_secondary_inventories s, fnd_lookup_values_vl v
               WHERE s.asset_inventory = 1
                 AND s.quantity_tracked = 1 --no locators
                 AND s.locator_type = 1
                 AND s.disable_date IS NULL
                 AND s.secondary_inventory_name NOT LIKE 'S%'
                 AND v.lookup_type = 'XXCST_INV_ORG_REPLACE'
                 AND v.lookup_code = to_char(s.organization_id)
                 AND s.secondary_inventory_name =
                     decode(s.organization_id,
                            90,
                            '9002',
                            92,
                            '9000',
                            93,
                            'INTRAN-SUB', ----'PSS IL-NEW'
                            101,
                            '8001',
                            102,
                            'MAIN',
                            121,
                            '2500',
                            181,
                            '6204',
                            461,
                            'PSS HK-NEW',
                            684,
                            'Makuhari',
                            685,
                            'RTS',
                            s.secondary_inventory_name)) subinv_for_receipt
       WHERE shh.shipment_header_id = shl.shipment_header_id
         AND shl.shipment_line_status_code IN
             ('PARTIALLY RECEIVED', 'EXPECTED')
         AND shl.destination_type_code = 'INVENTORY'
         AND sib.inventory_item_id = shl.item_id
         AND sib.organization_id = shl.to_organization_id
         AND mmt.transaction_id(+) = shl.mmt_transaction_id
         AND tln.transaction_id(+) = mmt.transaction_id
         AND mln.organization_id(+) = tln.organization_id
         AND mln.inventory_item_id(+) = tln.inventory_item_id
         AND mln.lot_number(+) = tln.lot_number
         AND mms.status_id(+) = mln.status_id
         AND msn.inventory_item_id(+) = mmt.inventory_item_id
         AND msn.last_transaction_id(+) = mmt.transaction_id
         AND org.organization_id(+) = shl.to_organization_id
         AND org.operating_unit != 89
         AND org.operating_unit = ou.organization_id
         AND shl.from_organization_id <> 95
         AND org.operating_unit = p_org_id ----parameter
         AND rla.requisition_line_id = shl.requisition_line_id
         AND rha.requisition_header_id = rla.requisition_header_id
         AND shh.shipment_num IS NOT NULL
         AND shl.requisition_line_id IS NOT NULL
         AND shl.to_organization_id = subinv_for_receipt.organization_id(+)
         AND shh.shipment_num = nvl(p_shipment_number, shh.shipment_num) --- parameter
         AND shh.shipment_header_id NOT IN
             (SELECT l.shipment_header_id
                FROM rcv_shipment_headers         h,
                     rcv_shipment_lines           l,
                     po_requisition_lines_all     rl,
                     po_requisition_headers_all   rh,
                     oe_order_headers_all         oh,
                     oe_transaction_types_tl      tt,
                     org_organization_definitions ofr,
                     org_organization_definitions oto
               WHERE l.shipment_header_id = h.shipment_header_id
                 AND l.shipment_line_status_code <> 'FULLY RECEIVED'
                 AND l.source_document_code = 'REQ'
                 AND rl.requisition_line_id = l.requisition_line_id
                 AND rh.requisition_header_id = rl.requisition_header_id
                 AND oh.orig_sys_document_ref = rh.segment1
                 AND tt.transaction_type_id = oh.order_type_id
                 AND tt.language = 'US'
                 AND tt.name LIKE 'Service Internal%'
                 AND ofr.organization_id = l.from_organization_id
                 AND oto.organization_id = l.to_organization_id
                 AND ofr.operating_unit <> oto.operating_unit);
  
  BEGIN
  
    retcode := '0';
    errbuf  := 'Success';
  
    DELETE FROM xxconv_inv_trx a WHERE a.request_id = p_request_id; ---parameter
  
    ---------------------------
    l_num_of_inserted_records := 0;
    FOR i IN c_rcv LOOP
      BEGIN
        --------
        INSERT INTO xxconv_inv_trx
          (request_id,
           trx_id,
           org_id,
           operating_unit,
           ---source_code,
           ---source_reference_code,
           creation_date,
           last_update_date,
           created_by,
           last_update_login,
           last_updated_by,
           status,
           ---doc_type,
           ---customer_name,
           supplier_name,
           shipment_header_id,
           shipment_number,
           shipment_line_id,
           shipment_line_number,
           order_header_id,
           order_number,
           order_line_id,
           order_line_number,
           ---po_line_location_id,
           ---service_request_reference,
           expected_receipt_date,
           item_id,
           item_code,
           ----supplier_item_code,
           qty_received,
           qty_uom_code,
           lot_number,
           lot_expiration_date,
           from_serial_number,
           to_serial_number,
           revision,
           organization_id,
           subinventory,
           subinventory_for_receipt,
           ---locator_id,
           from_organization_id
           ---from_subinventory
           ---from_locator_id
           )
        VALUES
          (p_request_id, ----fnd_global.conc_request_id,
           xxconv_inv_trx_id_seq.nextval,
           i.org_id,
           i.operating_unit,
           ---NULL, ---source_code,
           ---NULL, ---source_reference_code,
           SYSDATE, ---creation_date
           SYSDATE, ---last_update_date,
           fnd_global.user_id, ---created_by,
           fnd_global.login_id, ---last_update_login,
           fnd_global.user_id, ---last_updated_by,
           'N', ----status,
           ---NULL, ---doc_type,
           ---i.customer_name,
           i.supplier_name,
           i.shipment_header_id,
           i.shipment_number,
           i.shipment_line_id,
           i.shipment_line_number,
           i.order_header_id,
           i.order_number,
           i.order_line_id,
           i.order_line_number,
           ---i.po_line_location_id,
           ---i.service_request_reference,
           i.expected_receipt_date,
           i.item_id,
           i.item_code,
           ---i.supplier_item_code,
           i.qty_ordered, ----qty_received,
           i.qty_uom_code, ---qty_uom_code
           i.lot_number,
           i.lot_expiration_date,
           i.serial_number,
           i.serial_number,
           i.revision,
           i.to_organization_id,
           i.subinventory,
           i.subinventory_for_receipt,
           ---i.locator_id,
           i.from_organization_id
           ---i.from_subinventory
           ---i.from_locator_id
           );
        ---------------------
        l_num_of_inserted_records := l_num_of_inserted_records + 1;
      EXCEPTION
        WHEN dup_val_on_index THEN
          NULL;
      END;
    
    END LOOP;
  
    COMMIT;
    /*message(l_num_of_inserted_records ||
    ' records inserted into XXCONV_INV_TRX =====================');*/
    IF l_num_of_inserted_records = 0 THEN
      retcode := '2';
      errbuf  := 'NO RECORDS INSERTED into XXCONV_INV_TRX';
      RETURN;
    END IF;
  
  EXCEPTION
    /*WHEN l_done_exception THEN
    ROLLBACK;
    dbms_output.put_line('Raised');*/
  
    WHEN OTHERS THEN
      retcode := '2';
      errbuf  := SQLERRM || ' ' || l_err_message;
  END populate_rcv_file;
  --------------------------------------------------------------------
  -- main
  -- CR1178 - Receive and  re-ship intransit shipment at cutover.
  -------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -----------------------------
  --     1.0  8.12.13    Vitaly         initial build 
  --------------------------------------------------------------------
  PROCEDURE main(errbuf            OUT VARCHAR2,
                 retcode           OUT VARCHAR2,
                 p_org_id          IN NUMBER,
                 p_shipment_number IN VARCHAR2) IS
  
    CURSOR get_shipment_headers(p_request_id NUMBER) IS
      SELECT my_tab.shipment_header_id, my_tab.shipment_number
        FROM (SELECT DISTINCT t.shipment_header_id, t.shipment_number
                FROM xxconv_inv_trx t
               WHERE t.status = 'N'
                 AND t.request_id = p_request_id --cursor parameter
                 AND t.shipment_number =
                     nvl(p_shipment_number, t.shipment_number) ---parameter
              ) my_tab
      ----WHERE rownum <= 3
       ORDER BY my_tab.shipment_number;
  
    x_erbuf   VARCHAR(1000);
    x_retcode VARCHAR2(1000);
    ----x_interfacer_group_id NUMBER;
    v_error_message   VARCHAR2(1000);
    l_success_counter NUMBER := 0;
    l_error_counter   NUMBER := 0;
    stop_process_this_shipping_num EXCEPTION;
    l_request_id NUMBER := fnd_global.conc_request_id;
    ----l_batch_id NUMBER := xxconv_inv_trx_seq.nextval;
  BEGIN
    errbuf  := 'Success';
    retcode := '0';
  
    IF p_org_id IS NULL THEN
      v_error_message := 'ERROR: Missing parameter p_org_id';
      RAISE stop_process;
    ELSIF p_shipment_number IS NOT NULL THEN
      message('=========== REQUEST_ID=' || l_request_id ||
              ' ======== P_ORG_ID=' || p_org_id ||
              ' ======== P_SHIPMENT_NUMBER=' || p_shipment_number ||
              ' ============');
    ELSE
      message('=========== REQUEST_ID=' || l_request_id ||
              ' ======== P_ORG_ID=' || p_org_id || ' ============');
    END IF;
  
    fnd_global.apps_initialize(1171, 50623, 660); ---CONVERSION-----Implementation Manufacturing, OBJET
    ----fnd_global.apps_initialize(11371, 50623, 660); -- Noam.Yanai---Implementation Manufacturing, OBJET
    ----fnd_global.apps_initialize(10070, 50600, 201); -- STEPHANIE.PRIMUS---PUR Buyer, OBJET DE ------Purchasing
  
    mo_global.set_policy_context('S', p_org_id);
    inv_globals.set_org_id(p_org_id);
    mo_global.init('INV');
    ----------------------------------------------
    ---Populate our XX table----------------------
    ----------------------------------------------
    populate_rcv_file(x_erbuf,
                      x_retcode,
                      p_org_id,
                      p_shipment_number,
                      l_request_id);
    IF x_retcode = '0' THEN
      ---message('POPULATE_RCV_FILE was completed successfully');
      NULL;
    ELSE
      v_error_message := 'POPULATE_RCV_FILE was completed with ERROR: ' ||
                         x_erbuf;
      RAISE stop_process;
    END IF;
  
    FOR shipment_rec IN get_shipment_headers(l_request_id) LOOP
      --------
      BEGIN
        ----------------------------------------------------------------------------------------------
        -------------------------- PART 1 ------------------------------------------------------------
        ----Receiving in "OLD" organization and Validate On-Hand quantities in "OLD" organization-----
        ----------------------------------------------------------------------------------------------
        handle_rcv_internal_trx(x_erbuf,
                                x_retcode,
                                shipment_rec.shipment_header_id,
                                l_request_id);
        IF x_retcode = '0' THEN
          ----message('HANDLE_RCV_INTERNAL_TRX (RECEIVING + Validate On-Hand quantities inside) was COMPLETED SUCCESSFULLY');
          NULL;
        ELSE
          ----message('HANDLE_RCV_INTERNAL_TRX ERROR: ' || x_erbuf);
          RAISE stop_process_this_shipping_num; --- stop process this shipment                
        END IF;
        ----------------------------------------------------------------------------------------------
        -------------------------- PART 2 ------------------------------------------------------------
        ----Create Intransit Shippment from "OLD" to "NEW" inventory organization---------------------
        ----------------------------------------------------------------------------------------------
        handle_new_intransit_shipment(x_erbuf,
                                      x_retcode,
                                      shipment_rec.shipment_header_id,
                                      l_request_id);
        IF x_retcode = '0' THEN
          NULL;
          ----message('HANDLE_NEW_INTRANSIT_SHIPMENT (insert into Open Interface tables only...) was COMPLETED SUCCESSFULLY');
        ELSE
          ----message('HANDLE_NEW_INTRANSIT_SHIPMENT ERROR: ' || x_erbuf);
          RAISE stop_process_this_shipping_num; --- stop process this shipment                
        END IF;
        message('Shipment#=' || shipment_rec.shipment_number || ' ok');
        l_success_counter := l_success_counter + 1;
      EXCEPTION
        WHEN stop_process_this_shipping_num THEN
          l_error_counter := l_error_counter + 1;
          message('Shipment#=' || shipment_rec.shipment_number || ' ERROR');
      END;
      --------
    END LOOP;
    message('======= THIS PROGRAM IS COMPLETED ============================');
    message('======= ' || l_success_counter ||
            ' shipments were processed SUCCESSFULLY');
    message('======= ' || l_error_counter ||
            ' shipments processing ERRORS');
    message('==============================================================');
    --- manager "Process transaction interface" should be schedulled----- see mtl open interface errors -------
  EXCEPTION
    WHEN stop_process THEN
      message(v_error_message);
      errbuf  := v_error_message;
      retcode := '2';
  END main;

END xxconv_inv_trx_pkg;
/
