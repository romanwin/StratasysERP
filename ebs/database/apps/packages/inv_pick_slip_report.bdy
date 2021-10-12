CREATE OR REPLACE PACKAGE BODY inv_pick_slip_report AS
  /* $Header: http://sv-glo-tools01p.stratasys.dmn/svn/ERP/ebs/database/apps/packages/inv_pick_slip_report.bdy 2340 2015-07-28 05:57:22Z michal.tzvik $ */
--------------------------------------------------------------------
--  name:              INV_PICK_SLIP_REPORT
--  create by:         XXX
--  Revision:          1.0
--  creation date:     XX/XXX/XXXX
--------------------------------------------------------------------
--  purpose :          Oracle Hook package that we can change the code here.                
--------------------------------------------------------------------
--  ver  date          name              desc
--  1.0  XX/XXX/XXXX   XXX               initial build
--  1.1  2014-06-24    Gary.Altman       Change function print_pick_slip to run XXWIPTOPKL report
--                                       XX: Job Move Order Pick Slip        (CHG0031940)
--  1.2  28/09/2014    Dalit A. Raviv    add set print option before call to 
--                                       XX: Job Move Order Pick Slip report (CHG0033284)
--------------------------------------------------------------------

  g_pkg_name CONSTANT VARCHAR2(30) := 'INV_PICK_SLIP_REPORT';
  
  --------------------------------------------------------------------
  --  name:              mydebug
  --  create by:         XXX
  --  Revision:          1.0
  --  creation date:     XX/XXX/XXXX
  --------------------------------------------------------------------
  --  purpose :          Oracle Hook package that we can change the code here.                
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  XX/XXX/XXXX   XXX               initial build
  --------------------------------------------------------------------
  PROCEDURE mydebug(p_message VARCHAR2, p_api_name VARCHAR2) IS
  BEGIN
    inv_log_util.trace(p_message, g_pkg_name || '.' || p_api_name, 9);
  END;

  --------------------------------------------------------------------
  --  name:              chk_wms_install
  --  create by:         XXX
  --  Revision:          1.0
  --  creation date:     XX/XXX/XXXX
  --------------------------------------------------------------------
  --  purpose :          Oracle Hook package that we can change the code here.                
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  XX/XXX/XXXX   XXX               initial build
  --------------------------------------------------------------------
  FUNCTION chk_wms_install(p_organization_id IN NUMBER) RETURN VARCHAR2 IS
    l_msg_count         NUMBER;
    l_msg_data          VARCHAR2(2000);
    l_api_name CONSTANT VARCHAR(30)    := 'CHK_WMS_INSTALL';
    l_return_status     VARCHAR2(1);
  BEGIN
    IF wms_install.check_install(x_return_status   => l_return_status, 
                                 x_msg_count       => l_msg_count, 
                                 x_msg_data        => l_msg_data,
                                 p_organization_id => p_organization_id) THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      IF (fnd_msg_pub.check_msg_level(fnd_msg_pub.g_msg_lvl_unexp_error)) THEN
        fnd_msg_pub.add_exc_msg(g_pkg_name, l_api_name);
      END IF;

      RETURN 'FALSE';
  END chk_wms_install;

  --------------------------------------------------------------------
  --  name:              chk_wms_install
  --  create by:         XXX
  --  Revision:          1.0
  --  creation date:     XX/XXX/XXXX
  --------------------------------------------------------------------
  --  purpose :          Oracle Hook package that we can change the code here.                
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  XX/XXX/XXXX   XXX               initial build
  --------------------------------------------------------------------
  PROCEDURE run_detail_engine(x_return_status           OUT NOCOPY    VARCHAR2,
                              p_org_id                                NUMBER,
                              p_move_order_type                       NUMBER,
                              p_move_order_from                       VARCHAR2,
                              p_move_order_to                         VARCHAR2,
                              p_source_subinv                         VARCHAR2,
                              p_source_locator_id                     NUMBER,
                              p_dest_subinv                           VARCHAR2,
                              p_dest_locator_id                       NUMBER,
                              p_sales_order_from                      VARCHAR2,
                              p_sales_order_to                        VARCHAR2,
                              p_freight_code                          VARCHAR2,
                              p_customer_id                           NUMBER,
                              p_requested_by                          NUMBER,
                              p_date_reqd_from                        DATE,
                              p_date_reqd_to                          DATE,
                              p_plan_tasks                            BOOLEAN,
                              p_pick_slip_group_rule_id               NUMBER,
                              p_request_id                            NUMBER
                             ) IS
  
  --------------------------------------------------------------------
  --  name:              run_detail_engine
  --  create by:         XXX
  --  Revision:          1.0
  --  creation date:     XX/XXX/XXXX
  --------------------------------------------------------------------
  --  purpose :          Oracle Hook package that we can change the code here. 
  --                     This procedure will be called from Move Order Pick Slip Report. 
  --                     Change History               
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  22-Nov-2004   Nalin Kumar       Modified the Procedure and added parameter 
  --                                       p_request_id to fix Bug# 4003379.
  --------------------------------------------------------------------
  
  /***************************************************************************
    Reason why the p_request_id parameter has been introduced into this procedure:
      Assume that
       o CURSOR c_move_order_lines has 97 records
       o 'INV: Pick Slip Batch Size' profile value is set to 10
    - Basically to eliminate already processed records from getting selected again and again into
      c_move_order_lines CURSOR the request_id has be introduced in this procedure.
    - Once the number of records processed becomes equal to the value specified in 'INV: Pick Slip Batch Size'
      profile (10) then a COMMIT is issued and the c_move_order_lines is CLOSED and OPENED once again
      (to eliminate the 'ORA-01002: fetch out of sequence' Error). When the c_move_order_lines CURSOR
      is OPENED for the second time then the CURSOR MAY fetch the already processed records. But the
      idea is to process only unprocessed records and after CLOSING the CURSOR there was no pointer to
      find out that which all records have been already processed. So to identify the processed records
      we are updating the request_id column in mtl_txn_request_lines along with quantity_detailed. And
      the same (request_id) column is now being used to identify unprocessed records.
  *****************************************************************************/
    l_api_name               VARCHAR2(30);
    l_msg_data               VARCHAR2(2000);
    l_msg_count              NUMBER;
    l_max_batch              NUMBER;
    l_batch_size             NUMBER;
    l_num_of_rows            NUMBER         := 0;
    l_detailed_qty           NUMBER         := 0;
    l_secondary_detailed_qty NUMBER         := NULL; -- INVCONV
    l_revision               VARCHAR2(3)  := NULL;
    l_from_loc_id            NUMBER         := 0;
    l_to_loc_id              NUMBER         := 0;
    -- Increased lot size to 80 Char - Mercy Thomas - B4625329
    l_lot_number             VARCHAR2(80);
    l_expiration_date        DATE;
    l_transaction_temp_id    NUMBER;
    l_txn_header_id          NUMBER;
    l_serial_flag            VARCHAR2(1);

    l_pick_slip_no           NUMBER;
    l_prev_header_id         NUMBER         := 0;
    l_req_msg                VARCHAR2(30)   := NULL;
    l_tracking_quantity_ind  VARCHAR2(30)   := NULL;

    CURSOR c_move_order_lines (l_header_id NUMBER, l_move_order_type NUMBER,
                               l_profile_value NUMBER /* Added to fix Bug# 4003379 */) IS
      SELECT l_header_id header_id,
             l_move_order_type move_order_type,
             mtrl.line_id,
             mtrl.inventory_item_id,
             mtrl.to_account_id,
             mtrl.project_id,
             mtrl.task_id,
             mtrl.quantity_detailed
        FROM mtl_txn_request_lines mtrl
       WHERE mtrl.line_status IN (3, 7)
         AND mtrl.organization_id = p_org_id
         AND mtrl.header_id =  l_header_id
         AND mtrl.quantity > NVL(mtrl.quantity_detailed, 0)
         AND (p_requested_by IS NULL OR mtrl.created_by = p_requested_by)
         AND (p_source_subinv IS NULL OR mtrl.from_subinventory_code = p_source_subinv)
         AND (p_source_locator_id IS NULL OR mtrl.from_locator_id = p_source_locator_id)
         AND (p_dest_subinv IS NULL OR mtrl.to_subinventory_code = p_dest_subinv)
         AND (p_dest_locator_id IS NULL OR mtrl.to_locator_id = p_dest_locator_id)
         AND (p_date_reqd_from IS NULL OR mtrl.date_required >= p_date_reqd_from) /* Added to fix Bug# 4078103 */
         --bug 6850379
         AND (p_date_reqd_to IS NULL OR (mtrl.date_required <= trunc(p_date_reqd_to+1)-0.00001))    /* Added to fix Bug# 4078103 */
         --bug 6850379
         AND ((p_sales_order_from IS NULL AND p_sales_order_to IS NULL AND p_customer_id IS NULL AND p_freight_code IS NULL)
               OR EXISTS (SELECT 1
                            FROM wsh_delivery_details wdd
                           WHERE wdd.organization_id = p_org_id
                             AND wdd.move_order_line_id = mtrl.line_id
                             AND (p_sales_order_from IS NULL OR wdd.source_header_number >= p_sales_order_from)
                             AND (p_sales_order_to IS NULL OR wdd.source_header_number <= p_sales_order_to)
                             AND (p_customer_id IS NULL OR wdd.customer_id = p_customer_id)
                             AND (p_freight_code IS NULL OR wdd.ship_method_code = p_freight_code))
              )
         AND NVL(mtrl.request_id, 0) < p_request_id
             /* Added to fix Bug# 4003379; If the record does not have any request_id or
                it is less than current request_id that means- that record has not been
                processed by this request so select that record for processing. */
         AND rownum < l_profile_value +1
             /* Added to fix Bug# 4003379; ROWNUM is introduced to fetch and lock only
                that many records which has to be processed in a single go based on the
                value of the 'INV: Pick Slip Batch Size' profile. */
       FOR UPDATE OF mtrl.quantity_detailed NOWAIT; -- Added 3772012

    CURSOR c_move_order_header IS
      SELECT mtrh.header_id,
             mtrh.move_order_type
        FROM mtl_txn_request_headers mtrh
       WHERE mtrh.organization_id = p_org_id
         AND (p_move_order_from IS NULL OR mtrh.request_number >= p_move_order_from)
         AND (p_move_order_to IS NULL OR mtrh.request_number <= p_move_order_to)
         AND (    (p_move_order_type = 99 AND mtrh.move_order_type IN (1,2,3,5))
               OR (p_move_order_type = 1  AND mtrh.move_order_type = 3)
               OR (p_move_order_type = 2  AND mtrh.move_order_type = 5)
	       OR (p_move_order_type = 3  AND mtrh.move_order_type = 5) --Bug #4700988 MFG Pick
               OR (p_move_order_type = 4  AND mtrh.move_order_type IN (1,2))
             );

    CURSOR c_mmtt(p_mo_line_id NUMBER) IS
      SELECT transaction_temp_id,
             subinventory_code,
             locator_id,
             transfer_subinventory,
             transfer_to_location,
             revision
        FROM mtl_material_transactions_temp
       WHERE move_order_line_id = p_mo_line_id
         AND pick_slip_number IS NULL;

    l_debug NUMBER;
    record_locked EXCEPTION; -- bug 3772012
    PRAGMA EXCEPTION_INIT(record_locked, -54); -- bug 3772012
    v_mo_line_rec c_move_order_lines%ROWTYPE;
  BEGIN
    /* Initializing the default values */
    l_api_name := 'RUN_DETAIL_ENGINE';
    l_serial_flag := 'F';
    l_debug := NVL(fnd_profile.VALUE('INV_DEBUG_TRACE'), 0);

    IF l_debug = 1 THEN
      mydebug('Running Detail Engine with Parameters...', l_api_name);
      mydebug('  Organization ID     = ' || p_org_id, l_api_name);
      mydebug('  Move Order Type     = ' || p_move_order_type, l_api_name);
      mydebug('  Move Order From     = ' || p_move_order_from, l_api_name);
      mydebug('  Move Order To       = ' || p_move_order_to, l_api_name);
      mydebug('  Source Subinventory = ' || p_source_subinv, l_api_name);
      mydebug('  Source Locator      = ' || p_source_locator_id, l_api_name);
      mydebug('  Dest Subinventory   = ' || p_dest_subinv, l_api_name);
      mydebug('  Dest Locator        = ' || p_dest_locator_id, l_api_name);
      mydebug('  Sales Order From    = ' || p_sales_order_from, l_api_name);
      mydebug('  Sales Order To      = ' || p_sales_order_to, l_api_name);
      mydebug('  Freight Code        = ' || p_freight_code, l_api_name);
      mydebug('  Customer ID         = ' || p_customer_id, l_api_name);
      mydebug('  Requested By        = ' || p_requested_by, l_api_name);
      mydebug('  Date Required From  = ' || p_date_reqd_from, l_api_name);
      mydebug('  Date Required To    = ' || p_date_reqd_to, l_api_name);
      mydebug('  PickSlip Group Rule = ' || p_pick_slip_group_rule_id, l_api_name);
      mydebug('  Request ID          = ' || p_request_id, l_api_name);
    END IF;

    l_max_batch   := TO_NUMBER(fnd_profile.VALUE('INV_PICK_SLIP_BATCH_SIZE'));

    IF (l_debug = 1) THEN
      mydebug('Maximum Batch Size = ' || l_max_batch, l_api_name);
    END IF;

    IF l_max_batch IS NULL OR l_max_batch <= 0 THEN
      l_max_batch  := 20;

      IF (l_debug = 1) THEN
        mydebug('Using Default Batch Size 20', l_api_name);
      END IF;
    END IF;

    l_batch_size  := 0;

    --device integration starts
    IF (inv_install.adv_inv_installed(p_org_id) = TRUE) THEN --for WMS org
       IF wms_device_integration_pvt.wms_call_device_request IS NULL THEN

    IF (l_debug = 1) THEN
       mydebug('Setting global variable for device integration call', l_api_name);
    END IF;
    wms_device_integration_pvt.is_device_set_up(p_org_id,wms_device_integration_pvt.WMS_BE_MO_TASK_ALLOC,x_return_status);
       END IF;
    END IF;
    --device integration end

    FOR v_mo_header_rec IN c_move_order_header LOOP  -- Added 3772012
    BEGIN
     /*    FOR v_mo_line_rec IN c_move_order_lines(v_mo_header_rec.header_id, v_mo_header_rec.move_order_type) LOOP */
     --Start of new code to fix Bug# 4003379
     OPEN c_move_order_lines(v_mo_header_rec.header_id,
                             v_mo_header_rec.move_order_type,
                             l_max_batch); /* Changed from FOR loop Bug# 4003379 */
       LOOP
         FETCH c_move_order_lines INTO v_mo_line_rec;
         IF c_move_order_lines%NOTFOUND THEN
           CLOSE c_move_order_lines;
           COMMIT;
           l_batch_size := 0;
           EXIT;
         END IF;
     --END of new code added to fix Bug# 4003379
         l_batch_size       := l_batch_size + 1;
         IF v_mo_line_rec.header_id <> l_prev_header_id THEN
           l_prev_header_id := v_mo_line_rec.header_id;
           IF p_pick_slip_group_rule_id IS NOT NULL AND v_mo_line_rec.move_order_type IN (1,2) THEN
             IF l_debug = 1 THEN
               mydebug('New Header ID... So updating Pick Slip Grouping Rule', l_api_name);
             END IF;
             UPDATE mtl_txn_request_headers
             SET grouping_rule_id = p_pick_slip_group_rule_id
             WHERE header_id = v_mo_line_rec.header_id;
           END IF;
         END IF;

         SELECT decode(serial_number_control_code, 1, 'F', 'T'), tracking_quantity_ind
          INTO l_serial_flag, l_tracking_quantity_ind -- Bug 8985168
         FROM mtl_system_items
         WHERE inventory_item_id = v_mo_line_rec.inventory_item_id
         AND organization_id = p_org_id;

         SELECT mtl_material_transactions_s.NEXTVAL INTO l_txn_header_id FROM DUAL;

         inv_replenish_detail_pub.line_details_pub(
             x_return_status              => x_return_status,
             x_msg_count                  => l_msg_count,
             x_msg_data                   => l_msg_data,
             x_number_of_rows             => l_num_of_rows,
             x_detailed_qty               => l_detailed_qty,
             x_detailed_qty2              => l_secondary_detailed_qty, --INVCONV
             x_revision                   => l_revision,
             x_locator_id                 => l_from_loc_id,
             x_transfer_to_location       => l_to_loc_id,
             x_lot_number                 => l_lot_number,
             x_expiration_date            => l_expiration_date,
             x_transaction_temp_id        => l_transaction_temp_id,
             p_line_id                    => v_mo_line_rec.line_id,
             p_transaction_header_id      => l_txn_header_id,
             p_transaction_mode           => NULL,
             p_move_order_type            => v_mo_line_rec.move_order_type,
             p_serial_flag                => l_serial_flag,
             p_plan_tasks                 => p_plan_tasks,
             p_auto_pick_confirm          => FALSE
           );


         --
         -- Bug 8985168
         -- Handling the situation where the primary detailed quantity has become 0.
         IF l_debug = 1 THEN
           mydebug('l_tracking_quantity_ind     : ' || l_tracking_quantity_ind,l_api_name);
           mydebug('(1)l_detailed_qty           : ' || l_detailed_qty, l_api_name);
           mydebug('(1)l_secondary_detailed_qty : ' || l_secondary_detailed_qty, l_api_name);
         END IF;
         IF (l_tracking_quantity_ind = 'PS') THEN
            IF (l_detailed_qty = 0) THEN
               l_secondary_detailed_qty := 0;
            END IF;
            -- here theoretically we an raise an error if primary is NON zero while secondary is NULL or 0.
            -- but we will not raise this error at this time!
         ELSE
            l_secondary_detailed_qty := NULL;
         END IF;

         IF l_debug = 1 THEN
           mydebug('(2)l_detailed_qty           : ' || l_detailed_qty, l_api_name);
           mydebug('(2)l_secondary_detailed_qty : ' || l_secondary_detailed_qty, l_api_name);
         END IF;
         -- End Bug 8985168

         --Bug #4155230
         UPDATE mtl_txn_request_lines
         SET quantity_detailed = (NVL(quantity_delivered, 0) + l_detailed_qty),
             --secondary_quantity_detailed = decode(l_secondary_detailed_qty, 0, NULL, l_secondary_detailed_qty), --INVCONV
             secondary_quantity_detailed = NVL(secondary_quantity_delivered,0) + l_secondary_detailed_qty, -- Bug 8985168
             request_id = p_request_id /* Added the updation of request_id to fix Bug# 4003379 */
         WHERE line_id = v_mo_line_rec.line_id
         AND organization_id = p_org_id;

         IF l_debug = 1 THEN
           mydebug('Allocated MO Line = ' || v_mo_line_rec.line_id || ' : Qty Detailed = ' || l_detailed_qty, l_api_name);
         END IF;

         IF p_pick_slip_group_rule_id IS NOT NULL AND v_mo_line_rec.move_order_type IN (1,2) THEN
           -- Looping for each allocation of the MO Line for which Pick Slip Number is not stamped.
           FOR v_mmtt IN c_mmtt(v_mo_line_rec.line_id) LOOP
             inv_pr_pick_slip_number.get_pick_slip_number(
               x_api_status                 => x_return_status,
               x_error_message              => l_msg_data,
               x_pick_slip_number           => l_pick_slip_no,
               p_pick_grouping_rule_id      => p_pick_slip_group_rule_id,
               p_org_id                     => p_org_id,
               p_inventory_item_id          => v_mo_line_rec.inventory_item_id,
               p_revision                   => v_mmtt.revision,
               p_lot_number                 => NULL,
               p_src_subinventory           => v_mmtt.subinventory_code,
               p_src_locator_id             => v_mmtt.locator_id,
               p_supply_subinventory        => v_mmtt.transfer_subinventory,
               p_supply_locator_id          => v_mmtt.transfer_to_location,
               p_project_id                 => v_mo_line_rec.project_id,
               p_task_id                    => v_mo_line_rec.task_id,
               p_wip_entity_id              => NULL,
               p_rep_schedule_id            => NULL,
               p_operation_seq_num          => NULL,
               p_dept_id                    => NULL,
               p_push_or_pull               => NULL
             );

             UPDATE mtl_material_transactions_temp
             SET    pick_slip_number = l_pick_slip_no
             WHERE  transaction_temp_id = v_mmtt.transaction_temp_id;
           END LOOP;
         END IF;

      /*Bug#5140639. Commented the updation of 'distribution_account_id' in MMTT as
         it is already done in 'INV_Replenish_Detail_PUB.Line_Details_PUB' */

	    /* IF v_mo_line_rec.to_account_id IS NOT NULL THEN
           UPDATE mtl_material_transactions_temp
           SET distribution_account_id = v_mo_line_rec.to_account_id
           WHERE move_order_line_id = v_mo_line_rec.line_id;
         END IF;*/

         IF l_batch_size >= l_max_batch THEN
           IF (l_debug = 1) THEN
             mydebug('Current Batch Completed... Committing.',l_api_name);
           END IF;
           IF c_move_order_lines%ISOPEN THEN  --Added to fix Bug# 4003379
             CLOSE c_move_order_lines;
           END IF;
           COMMIT;
           OPEN c_move_order_lines(v_mo_header_rec.header_id,
                                   v_mo_header_rec.move_order_type,
                                   l_max_batch); --Changed from FOR loop bug 4003379

           l_batch_size  := 0;
         END IF;
       END LOOP;
     EXCEPTION -- Added 3772012
       WHEN record_locked THEN
         fnd_message.set_name('INV', 'INV_MO_LOCKED_SO');
         IF (l_debug = 1 ) THEN
           inv_log_util.TRACE('Lines for header '||v_mo_header_rec.header_id||' are locked', 'INV_UTILITIES', 9);
         END IF;
         fnd_msg_pub.ADD;
       END;
    END LOOP;

    IF (l_debug = 1) THEN
      inv_log_util.TRACE('calling Device Integration',l_api_name);
    END IF;
    -- Call Device Integration API to send the details of this
    -- PickRelease Wave for Move Order Allocation to devices, if it is a WMS organization.
    -- Note: We don't check for the return condition of this API as
    -- we let the Move Order Allocation  process succeed
    -- irrespective of DeviceIntegration succeed or fail.
    IF (wms_install.check_install(
      x_return_status   => x_return_status,
      x_msg_count       => l_msg_count,
      x_msg_data        => l_msg_data,
      p_organization_id => p_org_id
      ) = TRUE  ) THEN
       wms_device_integration_pvt.device_request(
         p_bus_event      => WMS_DEVICE_INTEGRATION_PVT.WMS_BE_MO_TASK_ALLOC,
         p_call_ctx       => WMS_Device_integration_pvt.DEV_REQ_AUTO,
         p_task_trx_id    => NULL,
         x_request_msg    => l_req_msg,
         x_return_status  => x_return_status,
         x_msg_count      => l_msg_count,
         x_msg_data       => l_msg_data);

       IF (l_debug = 1) THEN
         inv_log_util.TRACE('Device_API: returned status:'||x_return_status, l_api_name);
       END IF;
    END IF;

    IF c_move_order_lines%ISOPEN THEN  --Added to fix Bug# 4003379
      CLOSE c_move_order_lines;
    END IF;

    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      x_return_status := fnd_api.g_ret_sts_unexp_error;
      IF c_move_order_lines%ISOPEN THEN  --Added to fix Bug# 4003379
        CLOSE c_move_order_lines;
      END IF;
  END run_detail_engine;

  --------------------------------------------------------------------
  --  name:              print_pick_slip
  --  create by:         XXX
  --  Revision:          1.0
  --  creation date:     XX/XXX/XXXX
  --------------------------------------------------------------------
  --  purpose :          Oracle Hook package that we can change the code here.                
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  XX/XXX/XXXX   XXX               initial build
  --  1.1  2014-06-24    Gary.Altman       Change function to run XXWIPTOPKL report
  --                                       XX: Job Move Order Pick Slip        (CHG0031940)
  --  1.2  28/09/2014    Dalit A. Raviv    add set print option before call to 
  --                                       XX: Job Move Order Pick Slip report (CHG0033284)
  --------------------------------------------------------------------
  FUNCTION print_pick_slip( p_organization_id         VARCHAR2,
                            p_move_order_from         VARCHAR2,
                            p_move_order_to           VARCHAR2,
                            p_pick_slip_number_from   VARCHAR2,
                            p_pick_slip_number_to     VARCHAR2,
                            p_source_subinv           VARCHAR2,
                            p_source_locator          VARCHAR2,
                            p_dest_subinv             VARCHAR2,
                            p_dest_locator            VARCHAR2,
                            p_requested_by            VARCHAR2,
                            p_date_reqd_from          VARCHAR2,
                            p_date_reqd_to            VARCHAR2,
                            p_print_option            VARCHAR2,
                            p_print_mo_type           VARCHAR2,
                            p_sales_order_from        VARCHAR2,
                            p_sales_order_to          VARCHAR2,
                            p_ship_method_code        VARCHAR2,
                            p_customer_id             VARCHAR2,
                            p_auto_allocate           VARCHAR2,
                            p_plan_tasks              VARCHAR2,
                            p_pick_slip_group_rule_id VARCHAR2 ) RETURN NUMBER IS
    l_msg_data     varchar2(1000);
    l_msg_count    number;
    l_api_name     varchar2(30);
    l_debug        number;
    l_request_id   number;
    ------ Gary
    l_add_layout   boolean;
    ------ Dalit
    l_print_option boolean;
    l_printer_name varchar2(150);
    l_conc_prog_id number;
  BEGIN
    /* Initializing the default values */
    l_api_name := 'PRINT_PICK_SLIP';
    l_debug := NVL(fnd_profile.VALUE('INV_DEBUG_TRACE'), 0);
    
    

    -- Gary 18-JUN-2014  CHG0031940 
    l_add_layout := fnd_request.add_layout(template_appl_name => 'XXOBJT',--'INV',
                                           template_code      => 'XXWIPTOPKL',--'INVTOPKL_XML',
                                           template_language  => 'en',
                                           template_territory => 'US',
                                           output_format      => 'PDF'
                                           );
    
    if not l_add_layout then
      l_debug := 1 ;
      l_api_name := l_api_name ||': '||' Can not add layout for XXWIPTOPKL';
    end if;
    -- end CHG0031940

    -- CHG0033284 Dalit A. Raviv 28/09/2014
    -- Get program id (program id can be different between environments on dev stage)
    begin
      select v.concurrent_program_id --, user_concurrent_program_name, v.concurrent_program_name
      into   l_conc_prog_id
      from   fnd_concurrent_programs_vl v
      where  v.concurrent_program_name  = 'XXWIPTOPKL';--'XX: Job Move Order Pick Slip'
    exception
      when others then
        l_conc_prog_id := null;
        l_printer_name := null;
    end; 
    -- get printer name from set up - by organization
    -- the document set is set at "Implemetation" -> Order entry -> Shipping -> setup -> Documents -> Choose Printers
    -- Print the report only if the program for the organization is set here and it is default printer or is enable Y 
    if l_conc_prog_id is not null then
      begin
        select wrp.printer_name
        into   l_printer_name
        from   wsh_report_printers       wrp
        where  wrp.level_value_id        = p_organization_id 
        and    wrp.concurrent_program_id = l_conc_prog_id   
        and    wrp.enabled_flag          = 'Y'
        and    wrp.default_printer_flag  = 'Y'
        and    wrp.level_type_id         = 10008;
      exception
        when others then
          l_printer_name := null;
      end;
    end if;
    -- Only if found printer then set print option to print 1 copy  
    if l_printer_name is not null then
      l_print_option := fnd_request.set_print_options(printer     => l_printer_name,
                                                      copies      => 1,
                                                      save_output => TRUE);
      if not l_print_option then
        l_debug := 1;
        l_api_name := l_api_name ||': '||' Can not set print option, for printer: '||l_printer_name;
      end if;
    end if;
    l_request_id  := fnd_request.submit_request(
                       application => 'XXOBJT',    -- 'INV'          -- Gary 18-JUN-2014  CHG0031940
                       program     => 'XXWIPTOPKL',-- 'INVTOPKL_XML' -- Gary 18-JUN-2014  CHG0031940
                       description => NULL,
                       start_time  => NULL,
                       sub_request => FALSE,
                       argument1   => p_organization_id,
                       argument2   => p_move_order_from,
                       argument3   => p_move_order_to,
                       argument4   => p_pick_slip_number_from,
                       argument5   => p_pick_slip_number_to,
                       argument6   => p_source_subinv,
                       argument7   => p_source_locator,
                       argument8   => p_dest_subinv,
                       argument9   => p_dest_locator,
                       argument10  => p_requested_by,
                       argument11  => p_date_reqd_from,
                       argument12  => p_date_reqd_to,
                       argument13  => p_print_option,
                       argument14  => p_print_mo_type,
                       argument15  => p_sales_order_from,
                       argument16  => p_sales_order_to,
                       argument17  => p_ship_method_code,
                       argument18  => p_customer_id,
                       argument19  => p_auto_allocate,
                       argument20  => p_plan_tasks,
                       argument21  => p_pick_slip_group_rule_id );

    IF l_debug = 1 THEN
      mydebug('Request ID = ' || l_request_id, l_api_name);
    END IF;

    IF l_request_id = 0 THEN
       fnd_msg_pub.count_and_get(p_encoded=>fnd_api.g_false,p_data=>l_msg_data, p_count=>l_msg_count);
       IF l_debug = 1 THEN
         mydebug('Unable to submit the MO Pick Slip Request - ' || l_msg_data, l_api_name);
       END IF;
    END IF;

    RETURN l_request_id;
  END print_pick_slip;

END inv_pick_slip_report;
/
