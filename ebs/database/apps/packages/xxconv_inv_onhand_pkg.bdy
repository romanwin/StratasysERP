CREATE OR REPLACE PACKAGE BODY xxconv_inv_onhand_pkg IS
  ---------------------------------------------------------------------------
  -- $Header: xxconv_inv_onhand_pkg   $
  ---------------------------------------------------------------------------
  -- Package: xxconv_inv_onhand_pkg
  -- Created:
  -- Author:
  --------------------------------------------------------------------------
  -- Purpose: Transfer Qty On Hand from old to new Organizations
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  7.7.13    Vitaly      initial build
  ------------------------------------------------------------------

  -----------------------------------------------------------------------------
  PROCEDURE message(p_message VARCHAR2) IS
  
  BEGIN
    ---dbms_output.put_line(p_message);
    fnd_file.put_line(fnd_file.log, '========= ' || p_message);
  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END message;

  --------------------------------------------------------------------
  -- transfer_oh_qty
  -- CR 815 - Transfer Qty On Hand from old to new Organizations
  -------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -----------------------------
  --     1.0  7.7.13    Vitaly      initial build 
  -------------------------------------------------------------------- 
  PROCEDURE transfer_oh_qty(errbuf                 OUT VARCHAR2,
                            retcode                OUT VARCHAR2,
                            p_from_organization_id IN NUMBER,
                            p_to_organization_id   IN NUMBER) IS
  
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
             --MTL_MATERIAL_TRANSACTIONS_S.NEXTVAL transaction_interface_id,
             (SELECT ml.inventory_location_id
                FROM mtl_item_locations_kfv ml
               WHERE ml.concatenated_segments = t.locator
                 AND ml.organization_id = p_to_organization_id ---parameter
              ) to_locator_id
        FROM mtl_onhand_serial_v t, mtl_secondary_inventories mss
       WHERE t.organization_id = p_from_organization_id ---parameter
         AND mss.organization_id = t.organization_id
            ---AND nvl(mss.attribute8, 'N') = 'N' --closed by Noam Segal 12/09/2013
         AND nvl(mss.attribute9, 'N') = 'N' ---Noam Segal 12/09/2013
         AND mss.secondary_inventory_name = t.subinventory_code
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
             --MTL_MATERIAL_TRANSACTIONS_S.NEXTVAL transaction_interface_id,
             (SELECT ml.inventory_location_id
                FROM mtl_item_locations_kfv ml
               WHERE ml.concatenated_segments = v.concatenated_segments
                 AND ml.organization_id = p_to_organization_id ---parameter
              ) to_locator_id
        FROM mtl_onhand_lot_v          t,
             mtl_item_locations_kfv    v,
             mtl_secondary_inventories mss
       WHERE t.organization_id = p_from_organization_id ---parameter
         AND v.organization_id(+) = t.organization_id
         AND v.inventory_location_id(+) = t.locator_id
         AND mss.organization_id = t.organization_id
            ---AND nvl(mss.attribute8, 'N') = 'N' --closed by Noam Segal 12/09/2013
         AND nvl(mss.attribute9, 'N') = 'N' ---Noam Segal 12/09/2013
         AND mss.secondary_inventory_name = t.subinventory_code
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
             --MTL_MATERIAL_TRANSACTIONS_S.NEXTVAL transaction_interface_id,
             (SELECT ml.inventory_location_id
                FROM mtl_item_locations_kfv ml
               WHERE ml.concatenated_segments = v.concatenated_segments
                 AND ml.organization_id = p_to_organization_id ---parameter
              ) to_locator_id
        FROM mtl_onhand_quantities_detail moq,
             mtl_item_locations_kfv       v,
             mtl_secondary_inventories    mss
       WHERE NOT EXISTS
       (SELECT *
                FROM mtl_onhand_serial_v w
               WHERE w.inventory_item_id = moq.inventory_item_id
                 AND w.organization_id = moq.organization_id)
         AND moq.lot_number IS NULL
         AND moq.organization_id = p_from_organization_id ---parameter
         AND v.organization_id(+) = moq.organization_id
         AND v.inventory_location_id(+) = moq.locator_id
         AND mss.organization_id = moq.organization_id
            ---AND nvl(mss.attribute8, 'N') = 'N' --closed by Noam Segal 12/09/2013
         AND nvl(mss.attribute9, 'N') = 'N' ---Noam Segal 12/09/2013
         AND mss.secondary_inventory_name = moq.subinventory_code;
  
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
    v_organization  NUMBER;
  
    -- WHO columns
    l_user_id        NUMBER := fnd_global.user_id;
    l_resp_id        NUMBER := fnd_global.resp_id;
    l_application_id NUMBER := fnd_global.resp_appl_id;
    ---user and responsibility for Apps Initialize-------
    l_user_name VARCHAR2(30) := 'CONVERSION';
    l_resp_name VARCHAR2(50) := 'Implementation Manufacturing, OBJET';
  
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
  
    ---*****parameters******
    message('Parameter p_from_organization_id=' || p_from_organization_id);
    message('Parameter p_to_organization_id=' || p_to_organization_id);
    ----*******************
  
    IF p_from_organization_id IS NULL THEN
      ---Error----
      v_error_message := 'Missing parameter p_from_organization_id';
      RAISE stop_processing;
    END IF;
    IF p_to_organization_id IS NULL THEN
      ---Error----
      v_error_message := 'Missing parameter p_to_organization_id';
      RAISE stop_processing;
    END IF;
    IF p_from_organization_id = p_to_organization_id THEN
      ---Error----
      v_error_message := 'Parameter p_to_organization_id cannot be equel to p_from_organization_id=' ||
                         p_from_organization_id;
      RAISE stop_processing;
    END IF;
  
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
            l_application_id || '================');
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
    /* --moved to the end of process
    BEGIN
      SELECT organization_id
        INTO v_organization
        FROM mtl_parameters mp
       WHERE mp.organization_code = 'WPI';
      IF p_from_organization_id = v_organization THEN
        transfer_oh_qty_tpl(p_from_organization_id);
      END IF;
    END;*/
  
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
         p_to_organization_id, --- TRANSFER_ORGANIZATION,
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
    --------
  
    BEGIN
      SELECT organization_id
        INTO v_organization
        FROM mtl_parameters mp
       WHERE mp.organization_code = 'WPI';
      IF p_from_organization_id = v_organization THEN
        transfer_oh_qty_tpl(p_from_organization_id);
      END IF;
    END;
    --------
  
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

  ----------------------------------------------------------------------------------------
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
  
    v_request_id NUMBER;
    v_bool       BOOLEAN;
    v_step       VARCHAR2(100);
    stop_processing EXCEPTION;
    v_error_message VARCHAR2(5000);
  
    -- WHO columns
    l_user_id        NUMBER := fnd_global.user_id;
    l_resp_id        NUMBER := fnd_global.resp_id;
    l_application_id NUMBER := fnd_global.resp_appl_id;
    ---user and responsibility for Apps Initialize-------
    l_user_name VARCHAR2(30) := 'CONVERSION';
    l_resp_name VARCHAR2(50) := 'Implementation Manufacturing, OBJET';
  
    ---count num of inserted records----
    v_inserted_records_counter     NUMBER := 0;
    v_inserted_lot_records_counter NUMBER := 0;
    v_inserted_ser_records_counter NUMBER := 0;
    ---- out variables for fnd_concurrent.wait_for_request-----
    x_phase       VARCHAR2(100);
    x_status      VARCHAR2(100);
    x_dev_phase   VARCHAR2(100);
    x_dev_status  VARCHAR2(100);
    x_return_bool BOOLEAN;
    x_message     VARCHAR2(100);
  
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
    /*IF p_to_organization_id IS NULL THEN
      ---Error----
      v_error_message := 'Missing parameter p_to_organization_id';
      RAISE stop_processing;
    END IF;*/
    /*IF p_from_organization_id = p_to_organization_id THEN
      ---Error----
      v_error_message := 'Parameter p_to_organization_id cannot be equel to p_from_organization_id=' ||
                         p_from_organization_id;
      RAISE stop_processing;
    END IF;*/
  
    /*v_step := 'Step 10';
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
            */
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
  
    /*---=============== Submit 'Process transaction interface' concurrent program =====================
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
    END IF; */
  
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
  END transfer_oh_qty_tpl;
  ----------------------------------------------------------------------------------------- 
END xxconv_inv_onhand_pkg;
/
