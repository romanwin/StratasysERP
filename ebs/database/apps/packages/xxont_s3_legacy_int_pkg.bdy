CREATE OR REPLACE PACKAGE BODY xxont_s3_legacy_int_pkg IS
  g_user_id        NUMBER := apps.fnd_global.user_id;
  g_application_id NUMBER := apps.fnd_global.resp_appl_id;
  g_resp_id        NUMBER := apps.fnd_global.resp_id;

  ----------------------------------------------------------------------------
  --  name:            xxont_legacy_s3_int_pkg
  --  create by:       TCS
  --  $Revision:       1.0
  --  creation date:   22/08/2016
  ----------------------------------------------------------------------------
  --  purpose :        Package containing procedure to pull all the ASN/Drop Ship information
  --                   from Legacy and loading those information to S3 environment
  ----------------------------------------------------------------------------
  --  ver  date        name                         desc
  --  1.0  17/08/2016  TCS                    Initial build
  --  1.1  02/12/2016  Rohit                  Defect-635 -- Actual shipment date added
  --                                          Defect-699 --Code modified to include Subinventory code & locator for Drop Shipments
  --  1.2  07/12/2016  Rohit                  Defect-635 -- ship_to_org_code is fetched from db_link 
  --  1.3  13/12/2016  Rohit                  Defect-699
  --                                          1. line_location_id added to fetch unique records.
  --                                          2. Cursor added to fetch the error messages.
  --                                          3. Transit time to be considered in Drop Shipment case as well  
  --                                          4. Serial Number Validation added for Issued out of stores                    
  ----------------------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:               pull_asn
  --  create by:          TCS
  --  $Revision:          1.0
  --  creation date:      22/08/2016
  --- Description:        This procedure will collect the ASN data from  Legacy environment
  --                      and will create those ASN/Drop Ship data into S3 environment through
  --                      Receiving Open Interface
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   22/08/2016    TCS       initial build
  --  1.1   02/12/2016    Rohit     Defect-635 -- Actual shipment date added
  --                                Defect-699 --Code modified to include Subinventory code & locator for Drop Shipments
  --  1.2   07/12/2016    Rohit     Defect-635 -- ship_to_org_code is fetched from db_link
  --  1.3   13/12/2016    Rohit     Defect-699
  --                                1. line_location_id added to fetch unique records.
  --                                2. Cursor added to fetch the error messages.
  --                                3. Transit time to be considered in Drop Shipment case as well
  --                                4. Serial Number Validation added for Issued out of stores
  --------------------------------------------------------------------
  PROCEDURE pull_asn(p_errbuf  OUT VARCHAR2,
                     p_retcode OUT NUMBER)
  
   IS
    l_po_header_id           NUMBER;
    l_vendor_id              NUMBER;
    l_segment1               VARCHAR2(100);
    l_org_id                 NUMBER;
    l_inv_item_id            NUMBER;
    l_intransit_time         NUMBER;
    l_processing_status_code VARCHAR2(100);
    l_error_message          po_interface_errors.error_message%TYPE;
    ship_to_org_code         VARCHAR2(100);
    x_lot_status             VARCHAR2(10);
    l_item                   VARCHAR2(100);
  
    -- Defect-699 --Code modified to include Subinventory code & locator for Drop Shipments
    l_subinventory_code VARCHAR2(100);
    l_locator_id        NUMBER;
    -- Defect-699 --Code modified to include Subinventory code & locator for Drop Shipments
  
    l_serial_count NUMBER;
  
    TYPE grp_id_rec IS RECORD(
      grp_id   NUMBER,
      event_id NUMBER);
  
    TYPE grp_id_tbl IS TABLE OF grp_id_rec INDEX BY BINARY_INTEGER;
    l_grp_id_tbl grp_id_tbl;
  
    TYPE ont_asn_val_tbl IS TABLE OF apps.xxom_asn_s3_int_v@source_s3%ROWTYPE INDEX BY BINARY_INTEGER;
    l_ont_asn_val_tbl          ont_asn_val_tbl;
    x_request_status           VARCHAR2(100);
    l_count_serial             NUMBER;
    l_lot_count                NUMBER;
    l_shipment_num_exist_count NUMBER;
  
    CURSOR c_po_line(p_po_header_id NUMBER, p_release_num NUMBER, p_item_id NUMBER, p_line_location_id NUMBER --,p_shipment_num number
    ) IS
      SELECT pl.item_id,
             pl.po_line_id,
             pl.line_num,
             pll.quantity,
             pl.unit_meas_lookup_code,
             mp.organization_code,
             pll.line_location_id,
             pll.closed_code,
             pll.quantity_received,
             pll.cancel_flag,
             pll.shipment_num,
             pra.po_release_id,
             pra.release_num,
             pll.drop_ship_flag,
             pda.destination_type_code,
             pda.deliver_to_person_id,
             pda.deliver_to_location_id,
             pda.destination_subinventory,
             pda.destination_organization_id,
             pll.ship_to_organization_id
      FROM   po_lines_all          pl,
             po_line_locations_all pll,
             po_releases_all       pra,
             po_distributions_all  pda,
             mtl_parameters        mp
      WHERE  pl.po_header_id = p_po_header_id
      AND    pl.po_line_id = pll.po_line_id
      AND    pra.po_header_id = pl.po_header_id
      AND    pll.po_release_id = pra.po_release_id
      AND    pll.line_location_id = pda.line_location_id
      AND    pra.release_num = p_release_num
      AND    pll.ship_to_organization_id = mp.organization_id
      AND    pl.item_id = p_item_id
      AND    pll.line_location_id = p_line_location_id; --Defect-699 - line_location_id added to fetch unique records
    --and pll.shipment_num=p_shipment_num
  
    --Defect-699 --Cursor added to fetch the error messages
    CURSOR c_po_err(p_group_id NUMBER) IS
      SELECT pie.error_message
      FROM   rcv_headers_interface rhi,
             po_interface_errors   pie
      WHERE  rhi.processing_status_code = 'ERROR'
      AND    rhi.header_interface_id = pie.interface_header_id
      AND    rhi.group_id = pie.batch_id
      AND    rhi.group_id = p_group_id;
    --Defect-699 --Cursor added to fetch the error messages
  
  BEGIN
    fnd_global.apps_initialize(user_id => g_user_id, resp_id => g_resp_id, resp_appl_id => g_application_id);
    BEGIN
      SELECT * BULK COLLECT
      INTO   l_ont_asn_val_tbl
      FROM   apps.xxom_asn_s3_int_v@source_s3
      WHERE  1 = 1
      ORDER  BY last_update_date ASC;
    EXCEPTION
      WHEN no_data_found THEN
        fnd_file.put_line(fnd_file.log, 'Error in Bulk Collect.No data found.' ||
                           SQLERRM);
      WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log, 'Error in Bulk Collect.When Others.' ||
                           SQLERRM);
    END;
  
    FOR i IN 1 .. l_ont_asn_val_tbl.COUNT LOOP
      BEGIN
        l_intransit_time := 0;
        BEGIN
          SELECT pha.po_header_id,
                 pha.vendor_id,
                 pha.segment1,
                 pha.org_id
          INTO   l_po_header_id,
                 l_vendor_id,
                 l_segment1,
                 l_org_id
          FROM   po_headers_all pha --,
          WHERE  1 = 1
          AND    pha.segment1 = l_ont_asn_val_tbl(i).po_number;
        EXCEPTION
          WHEN OTHERS THEN
            fnd_file.put_line(fnd_file.log, 'Fatal Error.' || SQLERRM);
            p_retcode := 2;
        END;
        -----Inserting records in rcv_headers_interface
        SELECT COUNT(1)
        INTO   l_shipment_num_exist_count
        FROM   rcv_headers_interface
        WHERE  shipment_num =
               to_char(l_ont_asn_val_tbl(i).delivery_id) || '-INTERIM'
        AND    processing_status_code = 'PENDING';
      
        IF l_shipment_num_exist_count = 0 THEN
        
          l_intransit_time := 0;
          BEGIN
            BEGIN
              SELECT DISTINCT segment1
              INTO   l_item
              FROM   apps.mtl_system_items_b@source_s3
              WHERE  inventory_item_id = l_ont_asn_val_tbl(i).item_id;
            
              SELECT DISTINCT inventory_item_id
              INTO   l_inv_item_id
              FROM   mtl_system_items_b
              WHERE  segment1 = l_item;
            
            EXCEPTION
              WHEN OTHERS THEN
                l_item        := NULL;
                l_inv_item_id := NULL;
            END;
          
            --Defect-635 -- ship_to_org_code is fetched from db_link  
            /*SELECT mp.organization_code
            INTO   ship_to_org_code
            FROM   po_lines_all          pl,
                   po_line_locations_all pll,
                   po_releases_all       pra,
                   po_distributions_all  pda,
                   mtl_parameters        mp
            WHERE  pl.po_header_id = l_po_header_id
            AND    pl.po_line_id = pll.po_line_id
            AND    pra.po_header_id = pl.po_header_id
            AND    pll.po_release_id = pra.po_release_id
            AND    pll.line_location_id = pda.line_location_id
            AND    pra.release_num = l_ont_asn_val_tbl(i)
            .release_num
            AND    pll.ship_to_organization_id = mp.organization_id
            AND    pl.item_id = l_inv_item_id;*/
          
            IF l_ont_asn_val_tbl(i).ship_method_code IS NOT NULL THEN
              BEGIN
                SELECT intransit_time
                INTO   l_intransit_time
                FROM   apps.msc_interorg_ship_methods@source_s3 mism,
                       apps.msc_trading_partners@source_s3      mtp
                WHERE  mism.last_update_date =
                       (SELECT MAX(mism.last_update_date)
                        FROM   apps.msc_interorg_ship_methods@source_s3 mism,
                               apps.msc_trading_partners@source_s3      mtp
                        WHERE  mism.from_organization_id =
                               l_ont_asn_val_tbl(i)
                        .organization
                        AND    mism.to_organization_id = mtp.sr_tp_id
                        AND    mtp.organization_code LIKE
                              --'%' || ship_to_org_code
                               '%' || l_ont_asn_val_tbl(i)
                        .ship_to_org_code --Defect-635 -- ship_to_org_code is fetched from db_link
                        AND    ship_method = l_ont_asn_val_tbl(i)
                        .ship_method_code)
                AND    mism.from_organization_id = l_ont_asn_val_tbl(i)
                .organization
                AND    mism.to_organization_id = mtp.sr_tp_id
                      --AND    mtp.organization_code LIKE '%' || ship_to_org_code
                AND    mtp.organization_code LIKE
                       '%' || l_ont_asn_val_tbl(i)
                .ship_to_org_code --Defect-635 -- ship_to_org_code is fetched from db_link
                AND    ship_method = l_ont_asn_val_tbl(i)
                .ship_method_code;
              
              EXCEPTION
                WHEN OTHERS THEN
                  l_intransit_time := 0;
              END;
            END IF;
            IF l_ont_asn_val_tbl(i).ship_method_code IS NULL THEN
              BEGIN
                SELECT intransit_time
                INTO   l_intransit_time
                FROM   apps.msc_interorg_ship_methods@source_s3 mism,
                       apps.msc_trading_partners@source_s3      mtp
                WHERE  mism.last_update_date =
                       (SELECT MAX(mism.last_update_date)
                        FROM   apps.msc_interorg_ship_methods@source_s3 mism,
                               apps.msc_trading_partners@source_s3      mtp
                        WHERE  mism.from_organization_id =
                               l_ont_asn_val_tbl(i)
                        .organization
                        AND    mism.to_organization_id = mtp.sr_tp_id
                        AND    mtp.organization_code LIKE
                              --'%' || ship_to_org_code
                               '%' || l_ont_asn_val_tbl(i)
                        .ship_to_org_code --Defect-635 -- ship_to_org_code is fetched from db_link
                        AND    default_flag = 1)
                AND    mism.from_organization_id = l_ont_asn_val_tbl(i)
                .organization
                AND    mism.to_organization_id = mtp.sr_tp_id
                      --AND    mtp.organization_code LIKE '%' || ship_to_org_code
                AND    mtp.organization_code LIKE
                       '%' || l_ont_asn_val_tbl(i)
                .ship_to_org_code --Defect-635 -- ship_to_org_code is fetched from db_link
                AND    default_flag = 1;
              EXCEPTION
                WHEN OTHERS THEN
                  l_intransit_time := 0;
              END;
            END IF;
          
          EXCEPTION
            WHEN OTHERS THEN
              l_intransit_time := 0;
          END;
        
          INSERT INTO rcv_headers_interface
            (header_interface_id,
             group_id,
             processing_status_code,
             receipt_source_code,
             transaction_type,
             last_update_date,
             last_updated_by,
             last_update_login,
             vendor_id,
             expected_receipt_date,
             validation_flag,
             shipment_num,
             asn_type,
             shipped_date,
             packing_slip)
            SELECT rcv_headers_interface_s.NEXTVAL,
                   rcv_interface_groups_s.NEXTVAL,
                   'PENDING',
                   'VENDOR',
                   'NEW',
                   SYSDATE,
                   fnd_profile.VALUE('USER_ID'),
                   fnd_global.login_id,
                   l_vendor_id,
                   --trunc(l_ont_asn_val_tbl(i).ultimate_dropoff_date) + --Defect-635 -- Commented for Actual shipment date
                   --decode(nvl(l_ont_asn_val_tbl(i).drop_ship_flag, 'N'), 'N', l_intransit_time, 0), --Defect-699 --Transit time to be considered in Drop Shipment case as well
                   (trunc(l_ont_asn_val_tbl(i).actual_shipment_date) + --Defect-635 -- Actual shipment date added
                   l_intransit_time), --Defect-699 --Transit time to be considered in Drop Shipment case as well
                   'Y',
                   decode(nvl(l_ont_asn_val_tbl(i).drop_ship_flag, 'N'), 'N', to_char(l_ont_asn_val_tbl(i)
                                   .delivery_id) ||
                           '-INTERIM', 'Y', ''),
                   decode(nvl(l_ont_asn_val_tbl(i).drop_ship_flag, 'N'), 'N', 'ASN', 'Y', ''),
                   trunc(SYSDATE),
                   to_char(l_ont_asn_val_tbl(i).delivery_id)
            FROM   dual;
          l_grp_id_tbl(i).grp_id := rcv_interface_groups_s.CURRVAL;
          l_grp_id_tbl(i).event_id := l_ont_asn_val_tbl(i).event_id;
        END IF;
        ---------------------------------------------------------------------------------
        BEGIN
          SELECT DISTINCT segment1
          INTO   l_item
          FROM   apps.mtl_system_items_b@source_s3
          WHERE  inventory_item_id = l_ont_asn_val_tbl(i).item_id;
        
          SELECT DISTINCT inventory_item_id
          INTO   l_inv_item_id
          FROM   mtl_system_items_b
          WHERE  segment1 = l_item;
        
        EXCEPTION
          WHEN OTHERS THEN
            l_item        := NULL;
            l_inv_item_id := NULL;
        END;
      
        FOR cursor1 IN c_po_line(l_po_header_id, l_ont_asn_val_tbl(i)
                                 .release_num, l_inv_item_id, l_ont_asn_val_tbl(i)
                                 .po_line_location_id) LOOP
        
          IF nvl(l_ont_asn_val_tbl(i).drop_ship_flag, 'N') = 'N' THEN
            BEGIN
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
                 po_header_id,
                 po_line_id,
                 item_id,
                 quantity,
                 unit_of_measure,
                 po_line_location_id,
                 auto_transact_code,
                 receipt_source_code,
                 to_organization_code,
                 source_document_code,
                 header_interface_id,
                 validation_flag,
                 po_release_id,
                 release_num,
                 destination_type_code,
                 deliver_to_person_id,
                 deliver_to_location_id,
                 subinventory)
                SELECT rcv_transactions_interface_s.NEXTVAL,
                       rcv_interface_groups_s.CURRVAL,
                       SYSDATE,
                       fnd_profile.VALUE('USER_ID'),
                       SYSDATE,
                       fnd_profile.VALUE('USER_ID'),
                       fnd_global.login_id,
                       decode(nvl(l_ont_asn_val_tbl(i).drop_ship_flag, 'N'), 'N', 'SHIP', 'Y', 'RECEIVE'),
                       SYSDATE,
                       'PENDING',
                       'BATCH',
                       'PENDING',
                       l_po_header_id,
                       cursor1.po_line_id,
                       cursor1.item_id,
                       l_ont_asn_val_tbl(i) .shipped_quantity,
                       cursor1.unit_meas_lookup_code,
                       cursor1.line_location_id,
                       decode(nvl(l_ont_asn_val_tbl(i).drop_ship_flag, 'N'), 'N', 'SHIP', 'Y', 'DELIVER'),
                       'VENDOR',
                       cursor1.organization_code,
                       'PO',
                       rcv_headers_interface_s.CURRVAL,
                       'Y',
                       cursor1.po_release_id,
                       cursor1.release_num,
                       cursor1.destination_type_code,
                       cursor1.deliver_to_person_id,
                       cursor1.deliver_to_location_id,
                       cursor1.destination_subinventory
                FROM   dual;
            EXCEPTION
              WHEN OTHERS THEN
                fnd_file.put_line(fnd_file.log, 'Error in Insertion in rcv_transactions_interface Table....' ||
                                   SQLERRM);
            END;
          END IF;
          -------------------------------------
          IF nvl(l_ont_asn_val_tbl(i).drop_ship_flag, 'N') = 'Y' THEN
            SELECT COUNT(1)
            INTO   l_count_serial
            FROM   apps.wsh_serial_numbers@source_s3
            WHERE  delivery_detail_id = l_ont_asn_val_tbl(i)
            .delivery_detail_id;
          
            -- Defect-699 --Code modified to include Subinventory code & locator for Drop Shipments     
            BEGIN
            
              SELECT substr(flv.meaning, (instr(flv.meaning, '/', 1, 1) + 1), (instr(flv.meaning, '/', 1, 2) - 1) -
                             (instr(flv.meaning, '/', 1, 1))) subinventory,
                     --substr(flv.meaning, (instr(flv.meaning, '/', 1, 2) + 1), (length(flv.meaning) -
                     --(instr(flv.meaning, '/', 1, 2)))) locator,
                     mil.inventory_location_id locator_id
              INTO   l_subinventory_code,
                     l_locator_id
              FROM   fnd_lookup_values  flv,
                     mtl_item_locations mil,
                     mtl_parameters     mp
              WHERE  flv.lookup_type = 'XX_S3_INTERIM_RCV_SUBINV_LOC'
              AND    flv.LANGUAGE = 'US'
              AND    flv.enabled_flag = 'Y'
              AND    flv.lookup_code = cursor1.organization_code
              AND    mp.organization_code = flv.lookup_code
              AND    mp.organization_id = mil.organization_id
              AND    mil.segment1 || '.' || mil.segment2 || '.' ||
                     mil.segment3 || '.' || mil.segment4 =
                     substr(flv.meaning, (instr(flv.meaning, '/', 1, 2) + 1), (length(flv.meaning) -
                              (instr(flv.meaning, '/', 1, 2))));
            
            EXCEPTION
              WHEN OTHERS THEN
                l_subinventory_code := NULL;
                l_locator_id        := NULL;
              
            END;
            -- Defect-699 --Code modified to include Subinventory code & locator for Drop Shipments
          
            IF l_count_serial = 0 THEN
              BEGIN
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
                   po_header_id,
                   po_line_id,
                   item_id,
                   quantity,
                   unit_of_measure,
                   po_line_location_id,
                   auto_transact_code,
                   receipt_source_code,
                   to_organization_code,
                   source_document_code,
                   header_interface_id,
                   validation_flag,
                   po_release_id,
                   release_num,
                   destination_type_code,
                   deliver_to_person_id,
                   deliver_to_location_id,
                   subinventory,
                   locator_id) -- Defect-699 --Code modified to include Subinventory code & locator for Drop Shipments
                  SELECT rcv_transactions_interface_s.NEXTVAL,
                         rcv_interface_groups_s.CURRVAL,
                         SYSDATE,
                         fnd_profile.VALUE('USER_ID'),
                         SYSDATE,
                         fnd_profile.VALUE('USER_ID'),
                         fnd_global.login_id,
                         decode(nvl(l_ont_asn_val_tbl(i).drop_ship_flag, 'N'), 'N', 'SHIP', 'Y', 'RECEIVE'),
                         SYSDATE,
                         'PENDING',
                         'BATCH',
                         'PENDING',
                         l_po_header_id,
                         cursor1.po_line_id,
                         cursor1.item_id,
                         l_ont_asn_val_tbl(i) .shipped_quantity,
                         cursor1.unit_meas_lookup_code,
                         cursor1.line_location_id,
                         decode(nvl(l_ont_asn_val_tbl(i).drop_ship_flag, 'N'), 'N', 'SHIP', 'Y', 'DELIVER'),
                         'VENDOR',
                         cursor1.organization_code,
                         'PO',
                         rcv_headers_interface_s.CURRVAL,
                         'Y',
                         cursor1.po_release_id,
                         cursor1.release_num,
                         cursor1.destination_type_code,
                         cursor1.deliver_to_person_id,
                         cursor1.deliver_to_location_id,
                         -- Defect-699 --Code modified to include Subinventory code & locator for Drop Shipments
                         --cursor1.destination_subinventory 
                         l_subinventory_code,
                         l_locator_id
                  -- Defect-699 --Code modified to include Subinventory code & locator for Drop Shipments
                  FROM   dual;
              EXCEPTION
                WHEN OTHERS THEN
                  fnd_file.put_line(fnd_file.log, 'Error in Insertion in rcv_transactions_interface Table....' ||
                                     SQLERRM);
              END;
            END IF;
            IF l_count_serial = 0 AND l_ont_asn_val_tbl(i)
            .lot_number IS NOT NULL THEN
              SELECT organization_id
              INTO   l_org_id
              FROM   mtl_parameters
              WHERE  organization_code = cursor1.organization_code;
            
              SELECT COUNT(1)
              INTO   l_lot_count
              FROM   mtl_lot_numbers
              WHERE  inventory_item_id = cursor1.item_id
              AND    organization_id = l_org_id
              AND    lot_number = l_ont_asn_val_tbl(i)
              .lot_number
              AND    nvl(expiration_date, trunc(SYSDATE)) >= trunc(SYSDATE);
              IF l_lot_count = 0 THEN
                xxont_s3_legacy_roi_api_pkg.create_lot(l_org_id, cursor1.item_id, l_ont_asn_val_tbl(i)
                                                       .lot_number, x_lot_status);
              END IF;
              IF x_lot_status = 'S' OR l_lot_count > 0 THEN
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
                   product_transaction_id)
                  (SELECT mtl_material_transactions_s.NEXTVAL,
                          SYSDATE,
                          fnd_profile.VALUE('USER_ID'),
                          SYSDATE,
                          fnd_profile.VALUE('USER_ID'),
                          fnd_global.login_id,
                          l_ont_asn_val_tbl(i) .lot_number,
                          cursor1.quantity,
                          cursor1.quantity,
                          NULL, --serial_transaction_temp_id
                          'RCV',
                          rcv_transactions_interface_s.CURRVAL
                   FROM   dual);
              END IF;
            END IF;
          
            IF l_count_serial > 0 THEN
              FOR k IN (SELECT fm_serial_number
                        FROM   apps.wsh_serial_numbers@source_s3
                        WHERE  delivery_detail_id = l_ont_asn_val_tbl(i)
                        .delivery_detail_id) LOOP
                --Defect-699 --Serial Number validation added        
                BEGIN
                  SELECT COUNT(*)
                  INTO   l_serial_count
                  FROM   mtl_serial_numbers msn,
                         mfg_lookups        mfg,
                         mtl_parameters     mp
                  WHERE  msn.current_status = mfg.lookup_code
                  AND    mfg.lookup_type = 'SERIAL_NUM_STATUS'
                  AND    mfg.enabled_flag = 'Y'
                  AND    mfg.meaning <> 'Issued out of stores'
                  AND    mp.organization_id = msn.current_organization_id
                  AND    mp.organization_code = cursor1.organization_code
                  AND    msn.serial_number = k.fm_serial_number;
                EXCEPTION
                  WHEN OTHERS THEN
                    l_serial_count := 1;
                END;
              
                IF l_serial_count > 0 THEN
                
                  l_error_message := k.fm_serial_number ||
                                     ' is not in Issued out of stores Status.';
                  xxssys_event_pkg_s3.update_error(l_grp_id_tbl(i)
                                                   .event_id, l_error_message);
                
                END IF;
                --Defect-699 --Serial Number validation added              
                IF l_serial_count = 0 THEN
                
                  BEGIN
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
                       po_header_id,
                       po_line_id,
                       item_id,
                       quantity,
                       unit_of_measure,
                       po_line_location_id,
                       auto_transact_code,
                       receipt_source_code,
                       to_organization_code,
                       source_document_code,
                       header_interface_id,
                       validation_flag,
                       po_release_id,
                       release_num,
                       destination_type_code,
                       deliver_to_person_id,
                       deliver_to_location_id,
                       subinventory,
                       locator_id) -- Defect-699 --Code modified to include Subinventory code & locator for Drop Shipments
                      SELECT rcv_transactions_interface_s.NEXTVAL,
                             rcv_interface_groups_s.CURRVAL,
                             SYSDATE,
                             fnd_profile.VALUE('USER_ID'),
                             SYSDATE,
                             fnd_profile.VALUE('USER_ID'),
                             fnd_global.login_id,
                             decode(nvl(l_ont_asn_val_tbl(i).drop_ship_flag, 'N'), 'N', 'SHIP', 'Y', 'RECEIVE'),
                             SYSDATE,
                             'PENDING',
                             'BATCH',
                             'PENDING',
                             l_po_header_id,
                             cursor1.po_line_id,
                             cursor1.item_id,
                             l_ont_asn_val_tbl(i) .shipped_quantity / l_count_serial,
                             cursor1.unit_meas_lookup_code,
                             cursor1.line_location_id,
                             decode(nvl(l_ont_asn_val_tbl(i).drop_ship_flag, 'N'), 'N', 'SHIP', 'Y', 'DELIVER'),
                             'VENDOR',
                             cursor1.organization_code,
                             'PO',
                             rcv_headers_interface_s.CURRVAL,
                             'Y',
                             cursor1.po_release_id,
                             cursor1.release_num,
                             cursor1.destination_type_code,
                             cursor1.deliver_to_person_id,
                             cursor1.deliver_to_location_id,
                             -- Defect-699 --Code modified to include Subinventory code & locator for Drop Shipments
                             --cursor1.destination_subinventory 
                             l_subinventory_code,
                             l_locator_id
                      -- Defect-699 --Code modified to include Subinventory code & locator for Drop Shipments
                      FROM   dual;
                  EXCEPTION
                    WHEN OTHERS THEN
                      fnd_file.put_line(fnd_file.log, 'Error in Insertion in rcv_transactions_interface Table....' ||
                                         SQLERRM);
                  END;
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
                     product_transaction_id)
                  VALUES
                    (mtl_material_transactions_s.NEXTVAL,
                     SYSDATE,
                     fnd_profile.VALUE('USER_ID'),
                     SYSDATE,
                     fnd_profile.VALUE('USER_ID'),
                     fnd_global.login_id,
                     k.fm_serial_number,
                     k.fm_serial_number,
                     'RCV',
                     rcv_transactions_interface_s.CURRVAL);
                END IF;
              END LOOP;
            END IF;
          END IF;
        END LOOP;
        COMMIT;
      EXCEPTION
        WHEN OTHERS THEN
          fnd_file.put_line(fnd_file.log, 'Unexpected error 1....' ||
                             SQLERRM);
      END;
    END LOOP;
    COMMIT;
  
    IF l_grp_id_tbl.COUNT > 0 THEN
      FOR i IN l_grp_id_tbl.FIRST .. l_grp_id_tbl.LAST LOOP
        fnd_file.put_line(fnd_file.log, 'Group ID=' || l_grp_id_tbl(i)
                          .grp_id);
        xxont_s3_legacy_roi_api_pkg.call_receivingtransaction(l_grp_id_tbl(i)
                                                              .grp_id, x_request_status);
        BEGIN
          SELECT rhi.processing_status_code
          INTO   l_processing_status_code
          FROM   rcv_headers_interface rhi
          WHERE  rhi.group_id = l_grp_id_tbl(i).grp_id;
        EXCEPTION
          WHEN OTHERS THEN
            l_processing_status_code := '';
        END;
        IF l_processing_status_code = 'SUCCESS' THEN
          xxssys_event_pkg_s3.update_success(l_grp_id_tbl(i).event_id);
        END IF;
        IF l_processing_status_code = 'ERROR' THEN
          BEGIN
            l_error_message := '';
            /*SELECT pie.error_message
            INTO   l_error_message
            FROM   rcv_headers_interface rhi,
                   po_interface_errors   pie
            WHERE  rhi.processing_status_code = 'ERROR'
            AND    rhi.header_interface_id = pie.interface_header_id
            AND    rhi.group_id = pie.batch_id
            AND    rhi.group_id = l_grp_id_tbl(i).grp_id;*/
          
            --Defect-699 --Cursor added to fetch the error messages
            FOR cursor2 IN c_po_err(l_grp_id_tbl(i).grp_id) LOOP
            
              l_error_message := l_error_message || cursor2.error_message;
            
            END LOOP;
            --Defect-699 --Cursor added to fetch the error messages 
          
            xxssys_event_pkg_s3.update_error(l_grp_id_tbl(i).event_id, l_error_message);
          EXCEPTION
            WHEN OTHERS THEN
              l_error_message := '';
              fnd_file.put_line(fnd_file.log, 'Error while selecting error message from po_interface_errors table' ||
                                 SQLERRM);
          END;
        END IF;
      
      END LOOP;
    END IF;
    IF l_grp_id_tbl.COUNT = 0 THEN
      fnd_file.put_line(fnd_file.log, 'There is no record to process....');
    END IF;
  
    /*FOR i IN 1 .. l_ont_asn_val_tbl.COUNT LOOP
      SELECT COUNT(1)
        INTO l_count
        FROM rcv_shipment_headers
       WHERE packing_slip = to_char(l_ont_asn_val_tbl(i).delivery_id);
      IF l_count >= 1 THEN
        xxssys_event_pkg_s3.update_success(l_ont_asn_val_tbl(i).event_id);
      ELSIF l_count = 0 THEN
      
        xxssys_event_pkg_s3.update_error(l_ont_asn_val_tbl(i).event_id,
                                         '');
      END IF;
    END LOOP;*/
  EXCEPTION
    WHEN OTHERS THEN
      p_retcode := 1;
      fnd_file.put_line(fnd_file.log, 'Unexpected error 2....' || SQLERRM);
  END pull_asn;

END xxont_s3_legacy_int_pkg;
/
