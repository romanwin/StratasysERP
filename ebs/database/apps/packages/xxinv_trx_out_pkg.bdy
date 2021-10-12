CREATE OR REPLACE PACKAGE BODY xxinv_trx_out_pkg IS

  ---------------------------------------------------------------------------
  -- $Header: xxinv_trx_out_pkg   $
  ---------------------------------------------------------------------------
  -- Package: xxinv_trx_out_pkg
  -- Created:
  -- Author:  yuval tal
  ------------------------------------------------------------------
  -- Purpose: CUST-751 - CR1043 - Generate Outgoing  files
  ------------------------------------------------------------------
  -- Ver  Date         Performer       Comments
  ------  ---------    ------------    ----------------------------
  -- 1.0  24.9.2013    yuval tal       initial build
  -- 1.1  16.3.2014    yuval tal       CHG0031433 modify populate_ship_file : add column cust_po_number , contact_person
  -- 1.2  22.7.2014    noam yanai      CHG00323515: Interfaces with Expeditors
  --                                               Add procedures:
  --                                               - populate_wip_file: create and send WIP file (picking tasks)
  --                                               Modify Procedures:
  --                                               - populate_rcv_file: support resend of lines of orders that were recently received. add source code to table
  --                                               - populate_ship_file: add source code to table
  -- 1.3  12.11.2014   noam yanai      CHG0033810   modify  populate_rcv_file: in INTERNAL shipments, when to_subinventory is null bring default subinventory
  --                                               from profile XXINV_TPL_DEFAULT_RCV_SUBINVENTORY
  -- 1.4  23.11.2014   noam.yanai      CHG0033946  - add hasp number to the cursor both in populate_ship_file and populate_wip_file
  --                                               - add contact_phone_number to the cursor in populate_ship file
  --                                               - add filter in RCV out to exclude Move Order where source and destination subs are in TPL
  --                                               - in RCV out exclude doc_type 'MO' from logic of re-send (never re-send 'MO' type)
  --                                               - add in rcv out file, for doc_type='INTERNAL' also intransit inter-organization transfers
  --                                               - added procedure Split_serial_in_rcv_file. Split RMA and PO lines for serial items so that
  --                                                 each serial will have one line with quantity 1
  --                                               - added procedure "Resend_File" that allows to resend XML file for lines in that were already sent.
  -- 1.5  22.01.2015   noam yanai      CHG0034232  add PTO item and PTO description columns in main cursor
  --                                               add PTO item and PTO description in the insert into xxinv_trx_ship_out
  -- 1.6  22-Oct-2015  Dalit A. RAviv  INC0049392  populate_ship_file correct main cursor
  -- 1.6  19-Aug-2015  DAlit A. RAviv  CHG0036206  TPL Interface Expected PO rcv modifications
  --                                               Modify populate_rcv_file
  -- 1.7 07.06.17       yuval tal      INC0094855 - Multiple records created when the Generate RCV file program is run
  --                                   modify populate_rcv_file
  --                                   modify  split_serial_in_rcv_file - avoid splition record already split
  -- 1.8  04/09/17     yuval tal       CHG0041451 modify populate_rcv_fileCorrect UOM code for populate RCV table
  -- 1.9  11.10.17    piyali bhowmick  CHG0041294-TPL Interface FC - Remove Pick Allocations
  --                                              Add procedures :
  --                                              - populate_ship_file_allocate : move the content of populate_ship_file to populate_ship_file_allocate
  --                                                add Move order no and move order line no in main cursor
  --                                                add Move order no and move order line no in the insert into xxinv_trx_ship_out
  --                                                add Ship set number in the main cursor and in the insert into xxinv_trx_ship_out
  --                                              - populate_ship_file_no_allocate : Changing the cursor logic (c_ship)
  --                                                and  change  in CHK UNIQUE logic ¿ new logic is  based on Delivery Detail ID ,MO line ID
  --                                               add Ship set number in the main cursor and in the insert into xxinv_trx_ship_out
  --                                              Modify procedures :
  --                                              - populate_ship_file :check the profile  value for XXINV: TPL Allocations = Y then  use procedure
  --                                                populate_ship_file_allocate else use  populate_ship_file_no_allocate
  --
  -- 2.0  25-04-2018  Roman.W.          CHG0042777 - XXINV_TRX_OUT_PKG package needs modification for Missing RMA sheet issue
  --                                    Added logic to function "generate_rma_report" which allows sending a report not only by delivery but also from order level.
  -- 2.1  07.11.18    Bellona(TCS)      CHG0043872 - Add End User PO Field to TPL Interface and Reports
  -- 2.2  28.11.18    Bellona(TCS)      CHG0043872(CTASK0039460) - Adding space at HEAD_SHIPPING_INSTRUCTIONS by BA request
  -- 2.3  13.5.20     yuval tal         INC0191108 - modify populate_wip_file
  -- 2.4  26.7.20     yuval tal         INC0200056 - modify is_record_exists_in_out,populate_wip_file - performance improvment
  -- 2.5  02/02/2021  Roman W.          CHG0049272 - TPL - Receiving Inspection interface
  -- 2.6  19/05/2021  Roman W.          INC0232164 - Performance/Index issue
  --                                         fixed in procedure IS_RECORD_EXISTS_IN_OUT                                         
  ----------------------------------------------------------------------------------------------------------------------------------------

  procedure message(p_msg in varchar2) is
    l_msg varchar(32676);
  
  begin
  
    l_msg := to_char(sysdate, 'DD/MM/YYYY HH24:MI:SS  ') || p_msg;
  
    if fnd_global.CONC_REQUEST_ID > 0 then
      fnd_file.put_line(fnd_file.LOG, l_msg);
    else
      dbms_output.put_line(l_msg);
    end if;
  
  end message;

  -----------------------------------------------------------------
  -- is_record_exists_in_out
  ----------------------------------------------------------------
  -- Purpose: check record exists in table xxinv_trx_rcv_out
  -----------------------------------------------------------------
  -- Ver   Date        Performer       Comments
  -------  ----------  --------------  ---------------------------
  -- 1.0   24.9.13     yuval tal       initial build
  -- 1.1   26.7.20     yuval tal       INC0200056 -   performence issue
  --                                      create index xxobjt.XXINV_TRX_RCV_OUT_N3 on   xxobjt.XXINV_TRX_RCV_OUT
  --                                      (nvl(shipment_line_id, 0) || '|' || nvl(lot_number, '.') || '|' ||
  --                                      nvl(serial_number, '.') || '|' || nvl(order_line_id, 0) || '|' ||
  --                                      nvl(po_line_location_id, 0));
  -- 1.2   02/02/2021  Roman W.        CHG0049272 TPL - Receiving Inspection interface
  -- 1.3   19/03/2021  Roman W.        INC0232164 - Performance issue
  -----------------------------------------------------------------
  FUNCTION is_record_exists_in_out(p_doc_type            VARCHAR2,
                                   p_shipment_line_id    NUMBER,
                                   p_lot_number          VARCHAR2,
                                   p_serial_number       VARCHAR2,
                                   p_order_line_id       NUMBER,
                                   p_po_line_location_id NUMBER,
                                   p_transaction_id      NUMBER)
    RETURN VARCHAR2 IS
  
    CURSOR c_find(c_shipment_line_id    NUMBER,
                  c_lot_number          VARCHAR2,
                  c_serial_number       VARCHAR2,
                  c_order_line_id       NUMBER,
                  c_po_line_location_id NUMBER,
                  c_transaction_id      NUMBER) IS
      SELECT 'Y'
        FROM xxinv_trx_rcv_out t
       WHERE doc_type = p_doc_type
            /*
            AND nvl(t.shipment_line_id, 0) || '|' || nvl(t.lot_number, '.') || '|' ||
                nvl(t.serial_number, '.') || '|' || nvl(t.order_line_id, 0) || '|' ||
                nvl(t.po_line_location_id, 0) || '|' ||
                nvl(t.transaction_id, 0) =
                nvl(p_shipment_line_id, 0) || '|' || nvl(p_lot_number, '.') || '|' ||
                nvl(p_serial_number, '.') || '|' || nvl(p_order_line_id, 0) || '|' ||
                nvl(p_po_line_location_id, 0) || '|' ||
                nvl(p_transaction_id, 0);
            */
         AND T.SHIPMENT_LINE_ID || '|' || T.LOT_NUMBER || '|' ||
             T.SERIAL_NUMBER || '|' || T.ORDER_LINE_ID || '|' ||
             T.PO_LINE_LOCATION_ID || '|' || T.TRANSACTION_ID =
             c_shipment_line_id || '|' || c_lot_number || '|' ||
             c_serial_number || '|' || c_order_line_id || '|' ||
             c_po_line_location_id || '|' || c_transaction_id;
  
    l_tmp VARCHAR2(1);
  BEGIN
  
    OPEN c_find(p_shipment_line_id,
                p_lot_number,
                p_serial_number,
                p_order_line_id,
                p_po_line_location_id,
                p_transaction_id);
  
    FETCH c_find
      INTO l_tmp;
    CLOSE c_find;
  
    RETURN nvl(l_tmp, 'N');
  
  END;

  -----------------------------------------------------------------
  -- insert_xxinv_trx_resend_orders
  ----------------------------------------------------------------
  -- Purpose: check record exists in table xxinv_tpl_resend_rcv_file
  -----------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------------------
  --     1.0  5.11.14   yuval tal         initial build
  -----------------------------------------------------------------
  PROCEDURE insert_xxinv_trx_resend_orders(p_rec xxinv_trx_resend_orders%ROWTYPE) IS
  BEGIN
    IF p_rec.doc_type IN ('PO', 'INTERNAL', 'OE') THEN
      INSERT INTO xxinv_trx_resend_orders
        (source_code,
         doc_type,
         header_id,
         line_id,
         serial,
         lot,
         po_line_location_id,
         creation_date)
      VALUES
        (p_rec.source_code,
         p_rec.doc_type,
         p_rec.header_id,
         p_rec.line_id,
         p_rec.serial,
         p_rec.lot,
         p_rec.po_line_location_id,
         SYSDATE);
    END IF;
  
  END;

  -----------------------------------------------------------------
  -- is_record_exists_in_resend
  ----------------------------------------------------------------
  -- Purpose: check record exists in table xxinv_tpl_resend_rcv_file
  -----------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------------------
  --     1.0  5.11.14   yuval tal         initial build
  -----------------------------------------------------------------
  FUNCTION is_record_exists_in_resend(p_doc_type            VARCHAR2,
                                      p_shipment_line_id    NUMBER,
                                      p_order_line_id       NUMBER,
                                      p_serial              VARCHAR2,
                                      p_lot                 VARCHAR2,
                                      p_po_line_location_id NUMBER)
  
   RETURN VARCHAR2 IS
  
    CURSOR c_find IS
      SELECT 'Y'
        FROM xxinv_trx_resend_orders xtro
       WHERE doc_type = p_doc_type
         AND line_id = decode(doc_type,
                              'INTERNAL',
                              p_shipment_line_id,
                              p_order_line_id)
         AND nvl(xtro.serial, '-1') = nvl(p_serial, '-1')
         AND nvl(xtro.lot, '-1') = nvl(p_lot, '-1')
         AND nvl(xtro.po_line_location_id, -1) =
             nvl(p_po_line_location_id, -1);
    l_tmp VARCHAR2(1);
  BEGIN
  
    OPEN c_find;
    FETCH c_find
      INTO l_tmp;
    CLOSE c_find;
  
    RETURN nvl(l_tmp, 'N');
  
  END;

  -----------------------------------------------------------------
  -- GET_FROM_MAIL
  ----------------------------------------------------------------
  -- Purpose: GET_FROM_MAIL
  -----------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------------------
  --     1.0  5.11.14   yuval tal         initial build
  -----------------------------------------------------------------
  FUNCTION get_from_mail_address RETURN VARCHAR2 IS
  
    l_env VARCHAR2(50);
  
  BEGIN
  
    SELECT sys_context('userenv', 'instance_name') INTO l_env FROM dual;
  
    RETURN lower('ora' || l_env || '@stratasys.com');
  
  END get_from_mail_address;

  -----------------------------------------------------------------
  -- is_subinventory_tpl
  ----------------------------------------------------------------
  -- Purpose: check if subinventory mark as tpl (attribute4='Y')
  -----------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------------------
  --     1.0  24.9.13   yuval tal         initial build
  -----------------------------------------------------------------
  FUNCTION is_subinventory_tpl(p_organization_id NUMBER,
                               p_subinventory    VARCHAR2) RETURN NUMBER IS
  
    l_flag NUMBER;
  
  BEGIN
  
    SELECT 1
      INTO l_flag
      FROM mtl_secondary_inventories t
     WHERE t.attribute4 = 'Y'
       AND t.organization_id = p_organization_id
       AND t.secondary_inventory_name = p_subinventory;
  
    RETURN l_flag;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 0;
    
  END is_subinventory_tpl;

  -----------------------------------------------------------------
  -- populate_rcv_file
  -- /mnt/oracle/inv/tpl/fc/outgoing
  -- XXINVRCVTRX / XX INV TPL Generate receiving file
  -- RCV_TRX_INSPECT_IL
  ----------------------------------------------------------------
  -- Purpose: populate interface table xxinv_trx_rcv_out
  --
  --          call ml file generation procedure
  -----------------------------------------------------------------
  -- Ver  Date        Performer       Comments
  ------  --------    --------------  ---------------------------
  -- 1.0  24.9.2013   yuval tal       initial build
  -- 1.2  22.7.2014   noam yanai      CHG0032515 support resend of lines of orders that were recently received + add source code
  -- 1.3  27.10.2014  noam yanai                 added functionality that prevents resending interface if the processing of the
  --                                             incoming receiving was not completed. Added flag if the interfaces are still pending
  --                                             in the cursor and then set resend only if not pending. Also added a delete flag in table
  --                                             xxinv_trx_rcv_in_ord_headers and allow delete only after the resend.
  --                                             Also added resending file for doc_type = INTERNAL
  -- 1.4  11.11.2014  noam yanai      CHG0033810 in INTERNAL shipments, when to_subinventory is null bring default subinventory
  --                                             from profile XXINV_TPL_DEFAULT_RCV_SUBINVENTORY
  -- 1.5  27.11.2014  noam yanai      CHG0033946 (1) include in cursor type 'MO' only move orders where source subinventory is outside the TPL
  --                                             (2) when checking if need to re-send order balance - skip type 'MO'
  --                                             (3) add for doc_type='INTERNAL' also interansit inter-organization transfers
  --                                             (4) call new procedure Split_serial_in_rcv_file after insert to xxinv_trx_rcv_out
  -- 1.6  19/08/2015  DAlit A. RAviv  CHG0036206 - TPL Interface Expected PO rcv modifications
  --                                              Modify populate_rcv_file
  -- 1.7 07.06.17       yuval tal      INC0094855 - Multiple records created when the Generate RCV file program is run
  --                                   1.add split_from_line_id field to table xxinv_trx_rcv_out
  --                                        update field when insert new  line
  --                                     2.Avoid update quantity  when record is split from ?? (cursor c_poll_split)
  --                                     AND    xtro.split_from_line_id IS NULL;
  --                                     3.  I also added new status ?SPLIT? which mean that this record was split into X records
  -- 1.8 04/09/17     yuval tal        CHG0041451 modify populate_rcv_fileCorrect UOM code for populate RCV table
  -- 1.9 11/03/2021   Roman W.         CHG0049555
  -- 2.0 02/02/2021   Roman W.         CHG0049272 - TPL - Receiving Inspection interface
  -- 2.1 10/03/2021                            bug fix in cursor
  -- 2.2 15/03/2021                            bug fix in cursor . ADDED : and rt.po_line_location_id=rer.po_line_location_id
  -----------------------------------------------------------------
  PROCEDURE populate_rcv_file(errbuf          OUT VARCHAR2,
                              retcode         OUT VARCHAR2,
                              p_file_code     IN VARCHAR2,
                              p_days_back     IN NUMBER,
                              p_tpl_user_name IN VARCHAR2,
                              p_directory     IN VARCHAR2,
                              p_inspect_flag  IN VARCHAR2) IS
  
    l_errbuf        VARCHAR2(500);
    l_retcode       NUMBER;
    l_file_id       NUMBER;
    l_batch_id      NUMBER;
    l_flag          NUMBER := 0;
    l_creation_date DATE;
    l_directory     VARCHAR2(400);
    --
    l_err_code        NUMBER;
    l_err_message     VARCHAR2(2000);
    l_user_id         NUMBER;
    l_resp_id         NUMBER;
    l_resp_appl_id    NUMBER;
    l_organization_id NUMBER;
    --
    stop_process EXCEPTION;
    l_xxinv_trx_resend_orders_rec xxinv_trx_resend_orders%ROWTYPE;
  
    -- insert into xxinv_trx_rcv_out
    CURSOR c_rcv(c_inspect_flag VARCHAR2) IS
      SELECT *
        FROM ( ----------------------------------------------------
              --                 INSPECT
              ----------------------------------------------------
              SELECT 'INSPECT' doc_type,
                      NULL customer_name,
                      pv.vendor_name supplier_name,
                      NULL shipment_header_id,
                      NULL shipment_number,
                      
                      NULL shipment_line_id,
                      NULL shipment_line_number,
                      rer.po_header_id order_header_id,
                      to_number(rer.po_number) order_number,
                      rer.po_release_id po_release_id,
                      rer.po_release_number po_release_number,
                      rer.po_line_id order_line_id,
                      to_number(rer.po_line_number) order_line_number,
                      rer.po_line_location_id po_line_location_id,
                      NULL service_request_reference,
                      nvl(pll.promised_date, rer.need_by_date) expected_receipt_date,
                      NULL from_organization_id,
                      rer.item_id item_id,
                      msi.segment1 item_code,
                      rer.vendor_item_number supplier_item_code,
                      -- rer.ordered_qty qty_ordered, -- Rem By Roman W. 23/02/2021 CHG0049272
                      --rsup.Quantity qty_ordered,
                      rt.Quantity qty_ordered,
                      (SELECT muom.uom_code
                         FROM mtl_units_of_measure_vl muom
                        WHERE muom.unit_of_measure = pl.unit_meas_lookup_code) qty_uom_code, -- CHG0041451
                      NULL lot_number,
                      NULL lot_expiration_date,
                      NULL lot_status,
                      NULL serial_number,
                      NULL revision,
                      fnd_profile.VALUE('XXINV_TPL_DEFAULT_RCV_SUBINVENTORY') subinventory,
                      (SELECT MAX(l.inventory_location_id)
                         FROM mtl_item_locations_dfv d, mtl_item_locations l
                        WHERE d.row_id = l.rowid
                          AND l.organization_id = msi.organization_id
                          AND l.subinventory_code = pd.destination_subinventory
                          AND d.default_tpl_locator = 'Y') locator_id,
                      NULL from_subinventory,
                      NULL from_locator_id,
                      pll.note_to_receiver note_to_receiver,
                      pl.creation_date,
                      pll.last_update_date,
                      ---------------------------------------------------------------------------
                      (case rer.routing_id
                        when 2 then
                         'RECEIVING'
                        else
                         'INVENTORY'
                      end) destination_type_code, -- CHG0049272
                      --NULL              destination_type_code, -- CHG0049272
                      rt.transaction_id -- CHG0049272  -- EXTERNAL_KEY
                FROM rcv_enter_receipts_po_v rer,
                      rcv_supply              rsup,
                      rcv_shipment_lines      rsl,
                      rcv_shipment_headers    rsh,
                      rcv_transactions        rt,
                      rcv_routing_headers     rrh,
                      mtl_system_items_b      msi,
                      po_headers_all          ph,
                      mtl_parameters          mp,
                      po_lines_all            pl,
                      po_line_locations_all   pll,
                      po_vendors              pv,
                      po_distributions_all    pd
               WHERE 1 = 1
                 AND 'Y' = c_inspect_flag
                 AND 'Y' = fnd_profile.VALUE('XXINV_TPL_INSPECTION')
                 AND rsup.to_organization_id =
                     fnd_profile.VALUE('XXINV_TPL_ORGANIZATION_ID')
                 and rer.item_id = msi.inventory_item_id
                 and rer.to_organization_id = msi.organization_id
                 and pv.vendor_id(+) = rer.vendor_id
                 and pd.line_location_id = rer.po_line_location_id
                 and rsup.shipment_line_id = rsl.shipment_line_id
                 AND rsl.shipment_header_id = rsh.shipment_header_id
                 AND rsup.rcv_transaction_id = rt.transaction_Id
                 AND rrh.routing_header_id = rt.routing_header_id
                 AND rsup.item_id = msi.inventory_item_id
                 AND rsup.to_organization_id = msi.organization_id
                 AND rsup.po_header_id = ph.po_header_id
                 AND rsup.po_line_id = pl.po_line_id
                 AND rsup.po_line_location_id = pll.line_location_id
                 AND mp.organization_id = rsup.to_organization_id
                 AND rsup.po_header_id = rer.po_header_id -- 10/03/2021
                 AND rt.po_line_location_id = rer.po_line_location_id -- 15/03/2021
                 AND ((rrh.routing_header_id = 2 and
                     rt.inspection_status_code not in
                     ('REJECTED', 'ACCEPTED', 'NOT INSPECTED')) OR
                     (rrh.routing_header_id = 1) OR
                     (rrh.routing_header_id = 3))
                 AND not exists
               (select 'X'
                        from xxinv_trx_rcv_out xtro
                       where xtro.transaction_id = rt.transaction_id)
              -----------------------------------------------------
              --                     END INSPECT
              -----------------------------------------------------
              UNION ALL
              -----------------------------------------------------
              --                     INTERNAL
              -----------------------------------------------------
              SELECT 'INTERNAL' doc_type,
                      null customer_name,
                      null supplier_name,
                      rsh.shipment_header_id shipment_header_id,
                      rsh.shipment_num shipment_number,
                      rsl.shipment_line_id shipment_line_id,
                      rsl.line_num shipment_line_number,
                      ph.po_header_id order_header_id,
                      to_number(ph.segment1) order_number,
                      to_number(NULL) po_release_id,
                      to_number(NULL) po_release_number,
                      pl.po_line_id order_line_id,
                      to_number(pl.line_num) order_line_number,
                      null po_line_location_id,
                      null service_request_reference,
                      CASE
                        WHEN org.operating_unit = 81 THEN
                         trunc(rsh.expected_receipt_date + 21)
                        WHEN org.operating_unit = 96 THEN
                         trunc(rsh.expected_receipt_date + 2)
                        ELSE
                         rsh.expected_receipt_date
                      END expected_receipt_date,
                      rsl.from_organization_id from_organization_id,
                      rsl.item_id item_id,
                      msi.segment1 item_code,
                      NULL supplier_item_code,
                      rer.ordered_qty qty_ordered,
                      msi.primary_uom_code qty_uom_code,
                      NULL lot_number,
                      NULL lot_expiration_date,
                      NULL lot_status,
                      NULL serial_number,
                      NULL revision,
                      NULL subinventory,
                      NULL locator_id,
                      NULL from_subinventory,
                      NULL from_locator_id,
                      pll.note_to_receiver note_to_receiver,
                      pl.creation_date creation_date,
                      pl.last_update_date last_update_date, -- CHG0032515
                      NULL destination_type_code, -- CHG0049272
                      NULL transaction_id -- CHG0049272
                FROM rcv_supply                   rsup,
                      rcv_shipment_lines           rsl,
                      rcv_shipment_headers         rsh,
                      rcv_transactions             rt,
                      rcv_routing_headers          rrh,
                      mtl_system_items_b           msi,
                      po_headers_all               ph,
                      mtl_parameters               mp,
                      po_lines_all                 pl,
                      po_line_locations_all        pll,
                      org_organization_definitions org,
                      rcv_enter_receipts_po_v      rer
               WHERE 1 = 1
                 AND 'N' = c_inspect_flag
                 AND rsup.shipment_line_id = rsl.shipment_line_id
                 AND rsl.shipment_header_id = rsh.shipment_header_id
                 AND rsup.rcv_transaction_id = rt.transaction_Id
                 AND rrh.routing_header_id = rt.routing_header_id
                 AND rsup.item_id = msi.inventory_item_id
                 AND rsup.to_organization_id = msi.organization_id
                 AND rsup.po_header_id = ph.po_header_id
                 AND rsup.po_line_id = pl.po_line_id
                 AND rsup.po_line_location_id = pll.line_location_id
                 AND rsup.to_organization_id = 735 --fnd_profile.VALUE('XXINV_TPL_ORGANIZATION_ID') --(736 ITA)
                 AND mp.organization_id = rsup.to_organization_id
                    ------------------------------------------------
                 AND org.ORGANIZATION_ID(+) = rsl.from_organization_id
                 AND rer.to_organization_id = msi.organization_id
                 AND rer.item_id = msi.inventory_item_id
                    ------------------------------------------------
                 AND ((rrh.routing_header_id = 2 and
                     rt.inspection_status_code not in
                     ('REJECTED', 'ACCEPTED', 'NOT INSPECTED')) OR
                     (rrh.routing_header_id = 1) OR
                     (rrh.routing_header_id = 3))
                 AND 'Y' = fnd_profile.value('XXINV_TPL_INSPECTION')
              -----------------------------------------------------
              --                    END INTERNAL
              -----------------------------------------------------
              UNION ALL
              SELECT 'INTERNAL' doc_type,
                      NULL customer_name,
                      org.organization_name supplier_name,
                      shh.shipment_header_id shipment_header_id,
                      shh.shipment_num shipment_number,
                      shl.shipment_line_id shipment_line_id,
                      shl.line_num shipment_line_number,
                      rha.requisition_header_id order_header_id,
                      to_number(rha.segment1) order_number,
                      -- CHG0036206 19/08/2015 DAlit A. Raviv
                      to_number(NULL) po_release_id,
                      to_number(NULL) po_release_number,
                      -- end CHG0036206
                      shl.requisition_line_id order_line_id,
                      to_number(rla.line_num) order_line_number,
                      NULL po_line_location_id,
                      NULL service_request_reference,
                      CASE
                        WHEN org.operating_unit = 81 THEN
                         trunc(shh.expected_receipt_date + 21)
                        WHEN org.operating_unit = 96 THEN
                         trunc(shh.expected_receipt_date + 2)
                        ELSE
                         shh.expected_receipt_date
                      END expected_receipt_date,
                      shl.from_organization_id from_organization_id,
                      shl.item_id item_id,
                      sib.segment1 item_code,
                      NULL supplier_item_code,
                      --decode(msn.inventory_item_id, NULL, shl.quantity_shipped - nvl(shl.quantity_received, 0), 1) qty_ordered,-- Noam Yanai Feb-2014
                      -- CHG0036206  28/10/2015 Dalit &Dovik
                      CASE
                        WHEN msn.inventory_item_id IS NOT NULL THEN
                         1
                        WHEN tln.inventory_item_id IS NOT NULL THEN
                         abs(tln.transaction_quantity) -
                         nvl((SELECT SUM(tln1.transaction_quantity)
                               FROM mtl_transaction_lot_numbers tln1,
                                    mtl_material_transactions   mmt1
                              WHERE tln1.inventory_item_id =
                                    tln.inventory_item_id
                                AND tln1.organization_id =
                                    shl.to_organization_id
                                AND tln1.lot_number = tln.lot_number
                                AND mmt1.transfer_transaction_id =
                                    mmt.transaction_id
                                AND mmt1.organization_id =
                                    shl.to_organization_id
                                AND tln1.transaction_id = mmt1.transaction_id),
                             0)
                        ELSE
                         shl.quantity_shipped - nvl(shl.quantity_received, 0)
                      END qty_ordered,
                      -- CHG0036206  28/10/2015 Dalit &Dovik
                      sib.primary_uom_code qty_uom_code,
                      tln.lot_number lot_number,
                      mln.expiration_date lot_expiration_date,
                      mms.status_code lot_status,
                      msn.serial_number serial_number,
                      mmt.revision revision,
                      nvl(shl.to_subinventory,
                          fnd_profile.value('XXINV_TPL_DEFAULT_RCV_SUBINVENTORY')) subinventory, -- CHG0033810
                      (SELECT MAX(l.inventory_location_id)
                         FROM mtl_item_locations_dfv d, mtl_item_locations l
                        WHERE d.row_id = l.rowid
                          AND l.organization_id = sib.organization_id
                          AND l.subinventory_code =
                              nvl(shl.to_subinventory, -- CHG0033810
                                  fnd_profile.value('XXINV_TPL_DEFAULT_RCV_SUBINVENTORY'))
                          AND d.default_tpl_locator = 'Y') locator_id,
                      NULL from_subinventory,
                      NULL from_locator_id,
                      NULL note_to_receiver,
                      shl.creation_date,
                      shl.last_update_date, -- CHG0032515
                      null destination_type_code, -- CHG0049272
                      null transaction_id -- CHG0049272
                FROM rcv_shipment_lines           shl,
                      rcv_shipment_headers         shh,
                      mtl_system_items_b           sib,
                      mtl_material_transactions    mmt,
                      mtl_transaction_lot_numbers  tln,
                      mtl_lot_numbers              mln,
                      mtl_material_statuses        mms,
                      mtl_serial_numbers           msn,
                      org_organization_definitions org,
                      po_requisition_headers_all   rha,
                      po_requisition_lines_all     rla
               WHERE 1 = 1
                 AND 'N' = c_inspect_flag
                 AND shl.to_organization_id = l_organization_id -- Hard coded -> need to improve
                 AND shh.shipment_header_id = shl.shipment_header_id
                 AND shl.shipment_line_status_code IN
                     ('PARTIALLY RECEIVED', 'EXPECTED')
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
                 AND org.organization_id(+) = shl.from_organization_id
                 AND rla.requisition_line_id(+) = shl.requisition_line_id -- CHG0033946 include inter-organization transfer
                 AND rha.requisition_header_id(+) = rla.requisition_header_id -- CHG0033946 include inter-organization transfer
                 AND shh.shipment_num IS NOT NULL
                    --AND  shl.requisition_line_id IS NOT NULL   CHG0033946 include inter-organization transfer
                    -- CHG0033810 when to_subinventory is null it is OK
                 AND decode(shl.to_subinventory,
                            NULL,
                            1,
                            is_subinventory_tpl(shl.to_organization_id,
                                                shl.to_subinventory)) = 1
              --  AND shl.to_subinventory IN ('8200', '8201') -->  fix this
              UNION ALL
              -----------------------------------------------------
              --                     PO
              -----------------------------------------------------
              SELECT 'PO' doc_type,
                      NULL customer_name,
                      pv.vendor_name supplier_name,
                      NULL shipment_header_id,
                      NULL shipment_number,
                      NULL shipment_line_id,
                      NULL shipment_line_number,
                      rer.po_header_id order_header_id,
                      to_number(rer.po_number) order_number,
                      -- CHG0036206 19/08/2015 DAlit A. Raviv
                      rer.po_release_id     po_release_id,
                      rer.po_release_number po_release_number,
                      -- end CHG0036206
                      rer.po_line_id order_line_id,
                      to_number(rer.po_line_number) order_line_number,
                      rer.po_line_location_id po_line_location_id,
                      NULL service_request_reference,
                      -- CHG0036206 19/08/2015 DAlit A. Raviv
                      nvl(pll.promised_date, rer.need_by_date) expected_receipt_date,
                      -- end CHG0036206
                      NULL                   from_organization_id,
                      rer.item_id            item_id,
                      sib.segment1           item_code,
                      rer.vendor_item_number supplier_item_code,
                      rer.ordered_qty        qty_ordered,
                      --  sib.primary_uom_code qty_uom_code, -- CHG0041451
                      (SELECT muom.uom_code
                         FROM mtl_units_of_measure_vl muom
                        WHERE muom.unit_of_measure = pla.unit_meas_lookup_code) qty_uom_code, -- CHG0041451
                      
                      NULL lot_number,
                      NULL lot_expiration_date,
                      NULL lot_status,
                      NULL serial_number,
                      NULL revision,
                      pd.destination_subinventory subinventory, --> Noam Yanai 08/12/13
                      (SELECT MAX(l.inventory_location_id)
                         FROM mtl_item_locations_dfv d, mtl_item_locations l
                        WHERE d.row_id = l.rowid
                          AND l.organization_id = sib.organization_id
                          AND l.subinventory_code = pd.destination_subinventory --> Noam Yanai 08/09/14 because rer.destination_subinventory is null
                          AND d.default_tpl_locator = 'Y') locator_id,
                      NULL from_subinventory,
                      NULL from_locator_id,
                      pll.note_to_receiver note_to_receiver,
                      pla.creation_date,
                      --pla.last_update_date        -- CHG0032515
                      pll.last_update_date, -- CHG0036206 Dalit A. Raviv 19/08/2015 change pla to pll
                      (case rer.routing_id
                        when 2 then
                         'RECEIVING'
                        else
                         'INVENTORY'
                      end) destination_type_code, -- CHG0049272
                      null transaction_id -- CHG0049272
                FROM rcv_enter_receipts_po_v rer,
                      mtl_system_items_b      sib,
                      po_lines_all            pla,
                      po_line_locations_all   pll,
                      po_vendors              pv,
                      po_distributions_all    pd --  Noam Yanai 08/12/13
               WHERE 1 = 1
                 AND 'N' = c_inspect_flag
                 AND rer.to_organization_id = l_organization_id --Hard coded -> need to improve
                 AND sib.inventory_item_id = rer.item_id
                 AND sib.organization_id = rer.to_organization_id
                 AND pv.vendor_id(+) = rer.vendor_id
                 AND pla.po_line_id = rer.po_line_id
                    --     CHG0036206 Dalit A. Raviv 19/08/2015 change pla to pll
                    -- AND nvl(pll.closed_code, 'OPEN') = 'OPEN' -- Rem By Roman CHG0049555 : Receiving file chnage
                 AND nvl(pll.closed_code, 'OPEN') in
                     ('OPEN', 'CLOSED FOR INVOICE') -- Add By Roman CHG0049555 : Receiving file chnage
                 AND pll.line_location_id = rer.po_line_location_id
                 AND pd.line_location_id = rer.po_line_location_id -- Noam Yanai 08/12/13
                 AND pll.quantity_received < rer.ordered_qty
              -----------------------------------------------------
              --                     END PO
              -----------------------------------------------------
              UNION ALL
              -----------------------------------------------------
              --                     OE
              -----------------------------------------------------
              SELECT 'OE' doc_type,
                      hp.party_name customer_name,
                      NULL supplier_name,
                      NULL shipment_header_id,
                      NULL shipment_number,
                      NULL shipment_line_id,
                      NULL shipment_line_number,
                      rer.oe_order_header_id order_header_id,
                      to_number(rer.oe_order_num) sales_order_number,
                      -- CHG0036206 19/08/2015 DAlit A. Raviv
                      to_number(NULL) po_release_id,
                      to_number(NULL) po_release_number,
                      -- end CHG0036206
                      rer.oe_order_line_id order_line_id,
                      to_number(rer.oe_order_line_num) order_line_number,
                      NULL po_line_location_id,
                      oha.orig_sys_document_ref service_request_reference,
                      rer.need_by_date expected_receipt_date,
                      NULL from_organization_id,
                      rer.item_id item_id,
                      sib.segment1 item_code,
                      NULL supplier_item_code,
                      rer.ordered_qty qty_ordered,
                      sib.primary_uom_code qty_uom_code,
                      NULL lot_number,
                      NULL lot_expiration_date,
                      NULL lot_status,
                      NULL serial_number,
                      NULL revision,
                      ola.subinventory subinventory,
                      (SELECT MAX(l.inventory_location_id)
                         FROM mtl_item_locations_dfv d, mtl_item_locations l
                        WHERE d.row_id = l.rowid
                          AND l.organization_id = sib.organization_id
                          AND l.subinventory_code = ola.subinventory
                          AND d.default_tpl_locator = 'Y') locator_id,
                      NULL subinventory,
                      NULL from_locator_id,
                      NULL note_to_receiver,
                      ola.creation_date,
                      ola.last_update_date,
                      null destination_type_code, -- CHG0049272
                      null transaction_id -- CHG0049272
                FROM rcv_enter_receipts_rma_v rer,
                      mtl_system_items_b       sib,
                      oe_order_headers_all     oha,
                      oe_order_lines_all       ola,
                      hz_cust_accounts         hca,
                      hz_parties               hp
               WHERE 1 = 1
                 AND 'N' = c_inspect_flag
                 AND rer.to_organization_id = l_organization_id
                 AND sib.inventory_item_id = rer.item_id
                 AND sib.organization_id = rer.to_organization_id
                 AND hca.cust_account_id = rer.customer_id
                 AND hp.party_id = hca.party_id
                 AND oha.header_id = rer.oe_order_header_id
                 AND ola.line_id = rer.oe_order_line_id
                 AND rer.oe_order_line_id IS NOT NULL
                 AND (rer.destination_subinventory IS NULL OR
                     is_subinventory_tpl(rer.to_organization_id,
                                          rer.destination_subinventory) = 1)
              -----------------------------------------------------
              --                     END OE
              -----------------------------------------------------
              UNION ALL
              -----------------------------------------------------
              --                     END MO
              -----------------------------------------------------
              SELECT 'MO' doc_type,
                      NULL customer_name,
                      NULL supplier_name,
                      NULL shipment_header_id,
                      NULL shipment_number,
                      NULL shipment_line_id,
                      NULL shipment_line_number,
                      trh.header_id order_header_id,
                      to_number(trh.request_number) order_number,
                      -- CHG0036206 19/08/2015 DAlit A. Raviv
                      to_number(NULL) po_release_id,
                      to_number(NULL) po_release_number,
                      -- end CHG0036206
                      trl.line_id order_line_id,
                      to_number(trl.line_number) order_line_number,
                      NULL po_line_location_id,
                      nvl(trh.description, trh.request_number) service_request_reference, -- CHG0032515
                      trunc(trl.creation_date + 7) expected_receipt_date, -- to allow receiving by MO number there is no SR
                      trh.organization_id from_organization_id,
                      trl.inventory_item_id item_id,
                      sib.segment1 item_code,
                      NULL supplier_item_code,
                      trl.quantity qty_ordered,
                      sib.primary_uom_code qty_uom_code,
                      trl.lot_number lot_number,
                      mln.expiration_date lot_expiration_date,
                      mms.status_code lot_status,
                      trl.serial_number_start serial_number,
                      trl.revision revision,
                      trl.to_subinventory_code subinventory,
                      (SELECT MAX(l.inventory_location_id)
                         FROM mtl_item_locations_dfv d, mtl_item_locations l
                        WHERE d.row_id = l.rowid
                          AND l.organization_id = sib.organization_id
                          AND l.subinventory_code = trl.to_subinventory_code
                          AND d.default_tpl_locator = 'Y') locator_id,
                      trl.from_subinventory_code from_subinventory,
                      trl.from_locator_id from_locator_id,
                      NULL note_to_receiver,
                      trl.creation_date,
                      trl.last_update_date,
                      null destination_type_code, -- CHG0049272
                      null transaction_id -- CHG0049272
                FROM mtl_txn_request_headers trh,
                      mtl_txn_request_lines   trl,
                      mtl_system_items_b      sib,
                      mtl_lot_numbers         mln,
                      mtl_material_statuses   mms
               WHERE 1 = 1
                 AND 'N' = c_inspect_flag
                 AND trh.organization_id = l_organization_id
                 AND trh.header_id = trl.header_id
                 AND sib.inventory_item_id = trl.inventory_item_id
                 AND sib.organization_id = trh.organization_id
                 AND trh.move_order_type = 1
                 AND trl.line_status = 3 -- Approved
                 AND mln.organization_id(+) = trl.organization_id
                 AND mln.inventory_item_id(+) = trl.inventory_item_id
                 AND mln.lot_number(+) = trl.lot_number
                 AND mms.status_id(+) = mln.status_id
                 AND is_subinventory_tpl(trh.organization_id,
                                         trl.to_subinventory_code) = 1
                 AND xxinv_trx_out_pkg.is_subinventory_tpl(trh.organization_id,
                                                           trl.from_subinventory_code) = 0 -- CHG0033946 include MO only when souce sub is out of TPL
                 AND trl.quantity <=
                     nvl((SELECT SUM(decode(sn.serial_number,
                                           NULL,
                                           oqd.transaction_quantity,
                                           1))
                           FROM mtl_onhand_quantities_detail oqd,
                                mtl_serial_numbers           sn
                          WHERE oqd.organization_id = trl.organization_id
                            AND oqd.inventory_item_id = trl.inventory_item_id
                            AND oqd.subinventory_code =
                                trl.from_subinventory_code
                            AND decode(trl.from_locator_id,
                                       NULL,
                                       1,
                                       nvl(trl.from_locator_id, 1)) =
                                nvl(trl.from_locator_id, 1)
                            AND nvl(oqd.revision, '1') =
                                nvl(trl.revision, nvl(oqd.revision, '1'))
                            AND nvl(oqd.lot_number, '1') =
                                nvl(trl.lot_number, nvl(oqd.lot_number, '1'))
                            AND nvl(sn.inventory_item_id(+),
                                    oqd.inventory_item_id) =
                                oqd.inventory_item_id
                            AND nvl(sn.current_organization_id(+),
                                    oqd.organization_id) =
                                oqd.organization_id
                            AND nvl(sn.current_subinventory_code(+),
                                    oqd.subinventory_code) =
                                oqd.subinventory_code
                            AND nvl(sn.current_locator_id(+),
                                    nvl(oqd.locator_id, 1)) =
                                nvl(oqd.locator_id, 1)
                            AND nvl(sn.lot_number(+),
                                    nvl(oqd.lot_number, '1')) =
                                nvl(oqd.lot_number, '1')
                            AND nvl(sn.serial_number(+),
                                    nvl(trl.serial_number_start, '1')) =
                                nvl(trl.serial_number_start, '1')),
                         0)) x
       WHERE x.last_update_date > SYSDATE - p_days_back;
    --  AND    doc_type = 'INTERNAL';
    --  AND x.order_header_id IN (675693, 677044, 670318, 669032, 760250);
  
    -- CHG0036206 Dalit A. Raviv 19/08/2015
    -- Currently the interface supports only one/multiple shipments per order line, but not split of shipments.
    -- In order to support split of shipments, need to add another Cursor.
    -- The new Cursor will look at each shipment line in xxinv_trx_rcv_out table, if it match the order
    -- quantity with the quantity in table PO_LINE_LOCATIONS_ALL. In case there is a difference in the quantity,
    -- update the quantity and status in xxinv_trx_rcv_out accordingly.
    CURSOR c_poll_split(c_inspect_flag VARCHAR2) IS
      SELECT xtro.po_line_location_id,
             pll.quantity new_qty,
             xtro.qty_ordered,
             xtro.order_line_id,
             nvl(pll.promised_date, pll.need_by_date) new_expected_date
        FROM xxinv_trx_rcv_out xtro, po_line_locations_all pll
       WHERE xtro.po_line_location_id = pll.line_location_id
         AND xtro.organization_id = l_organization_id
         AND ((xtro.qty_ordered <> pll.quantity) OR
             (nvl(pll.promised_date, pll.need_by_date) <>
             xtro.expected_receipt_date))
         AND xtro.split_from_line_id IS NULL
            --         AND xtro.doc_type != 'INSPECT'
         AND 'N' = c_inspect_flag; -- INC0094855
  
    l_updated_count              NUMBER;
    l_is_record_exists_in_out    VARCHAR2(30);
    l_xxinv_tpl_resend_rcv_file  VARCHAR2(30);
    l_is_rcv_trx_processed       VARCHAR2(30);
    l_is_record_exists_in_resend VARCHAR2(30);
    l_line_id                    NUMBER; -- CHG0049272
    l_error_code                 VARCHAR2(10); -- CHG0049272
    l_error_desc                 VARCHAR2(500); -- CHG0049272
    l_xxinv_trx_rcv_loads_in     xxinv_trx_out_pkg.xxinv_trx_rcv_loads_in_tab;
  BEGIN
  
    retcode         := '0';
    errbuf          := 'Success';
    l_creation_date := SYSDATE;
    l_batch_id      := fnd_global.conc_request_id;
    message('xxinv_trx_out_pkg.populate_rcv_file(');
    message('                    p_file_code     : ' || p_file_code);
    message('                    p_days_back     : ' || p_days_back);
    message('                    p_tpl_user_name : ' || p_tpl_user_name);
    message('                    p_directory     : ' || p_directory);
    message('                    p_inspect_flag  : ' || p_inspect_flag);
    message('                    );');
  
    -- get user details --
    xxinv_trx_in_pkg.get_user_details(p_user_name       => p_tpl_user_name,
                                      p_user_id         => l_user_id,
                                      p_resp_id         => l_resp_id,
                                      p_resp_appl_id    => l_resp_appl_id,
                                      p_organization_id => l_organization_id,
                                      p_err_code        => l_err_code,
                                      p_err_message     => l_err_message);
  
    IF l_err_code = 1 THEN
      RAISE stop_process;
    END IF;
  
    -- err retry --
    UPDATE xxinv_trx_rcv_out t
       SET t.status_code      = 'NEW',
           t.batch_id         = l_batch_id,
           error_message      = NULL,
           t.last_update_date = SYSDATE,
           t.last_updated_by  = fnd_global.user_id
     WHERE t.status_code = 'ERROR'
       AND t.organization_id = l_organization_id;
  
    l_updated_count := SQL%rowcount;
  
    message('1) SQL%rowcount = ' || l_updated_count);
  
    IF SQL%FOUND THEN
      l_flag := 1;
    END IF;
  
    COMMIT;
  
    -- initialize --
    fnd_global.apps_initialize(l_user_id, l_resp_id, l_resp_appl_id);
    --
    l_directory := nvl(p_directory,
                       fnd_profile.value('XXINV_TPL_TRX_OUT_DIRECTORY'));
    IF xxobjt_general_utils_pkg.am_i_in_production = 'N' THEN
      l_directory := REPLACE(l_directory, 'PROD', 'DEV');
    END IF;
    --
  
    FOR i IN c_rcv(p_inspect_flag) LOOP
      l_is_record_exists_in_out := is_record_exists_in_out(i.doc_type,
                                                           i.shipment_line_id,
                                                           i.lot_number,
                                                           i.serial_number,
                                                           i.order_line_id,
                                                           i.po_line_location_id,
                                                           i.transaction_id);
    
      -- new logic
      IF l_is_record_exists_in_out = 'Y' THEN
        message('is_record_exists_in_out= Y order_line_id=' ||
                i.order_line_id);
      
        l_xxinv_tpl_resend_rcv_file := fnd_profile.value('XXINV_TPL_RESEND_RCV_FILE');
        message('XXINV_TPL_RESEND_RCV_FILE=' ||
                l_xxinv_tpl_resend_rcv_file);
        -- check resend mode
        IF l_xxinv_tpl_resend_rcv_file = 'Y' AND i.doc_type != 'MO' THEN
          -- CHG0033946 noam yanai NOV-14
        
          -- Not Exists in XXINV_TRX_RESEND_ORDERS
          -- And Not in process
          l_is_rcv_trx_processed := is_rcv_trx_processed(p_tpl_user_name,
                                                         i.doc_type,
                                                         i.order_header_id,
                                                         i.shipment_header_id);
        
          l_is_record_exists_in_resend := is_record_exists_in_resend(i.doc_type,
                                                                     i.shipment_line_id,
                                                                     i.order_line_id,
                                                                     i.serial_number,
                                                                     i.lot_number,
                                                                     i.po_line_location_id);
        
          IF l_is_rcv_trx_processed = 'Y' AND
             l_is_record_exists_in_resend = 'N' THEN
          
            message('is_rcv_trx_processed= Y is_record_exists_in_resend=N ' ||
                    i.order_line_id);
          
            -- Insert XXINV_TRX_RESEND_ORDERS
          
            l_xxinv_trx_resend_orders_rec             := NULL;
            l_xxinv_trx_resend_orders_rec.source_code := p_tpl_user_name;
            l_xxinv_trx_resend_orders_rec.doc_type    := i.doc_type;
            l_xxinv_trx_resend_orders_rec.header_id   := CASE i.doc_type
                                                           WHEN 'INTERNAL' THEN
                                                            i.shipment_header_id
                                                           ELSE
                                                            i.order_header_id
                                                         END;
          
            l_xxinv_trx_resend_orders_rec.line_id := CASE i.doc_type
                                                       WHEN 'INTERNAL' THEN
                                                        i.shipment_line_id
                                                       ELSE
                                                        i.order_line_id
                                                     END;
          
            l_xxinv_trx_resend_orders_rec.serial              := i.serial_number;
            l_xxinv_trx_resend_orders_rec.lot                 := i.lot_number;
            l_xxinv_trx_resend_orders_rec.po_line_location_id := i.po_line_location_id;
          
            insert_xxinv_trx_resend_orders(l_xxinv_trx_resend_orders_rec);
          
            -- Insert  xxinv_trx_rcv_out
            l_flag    := 1;
            l_line_id := xxinv_transaction_seq.nextval;
          
            INSERT INTO xxinv_trx_rcv_out
              (line_id,
               organization_id,
               interface_target,
               batch_id,
               status_code,
               creation_date,
               last_update_date,
               created_by,
               last_update_login,
               last_updated_by,
               file_id,
               doc_type,
               customer_name,
               supplier_name,
               shipment_header_id,
               shipment_number,
               shipment_line_id,
               shipment_line_number,
               order_header_id,
               order_number,
               order_line_id,
               order_line_number,
               po_line_location_id,
               service_request_reference,
               expected_receipt_date,
               from_organization_id,
               item_id,
               item_code,
               supplier_item_code,
               qty_ordered,
               qty_uom_code,
               lot_number,
               lot_expiration_date,
               lot_status,
               serial_number,
               revision,
               subinventory,
               locator_id,
               from_subinventory,
               from_locator_id,
               note_to_receiver,
               source_code, -- CHG0032515
               po_release_id, -- CHG0036206 Dalit A. Raviv 19/08/2015
               po_release_number,
               destination_type_code, -- CHG0049272
               transaction_id -- CHG0049272
               ) -- CHG0036206 Dalit A. Raviv 19/08/2015
            VALUES
              (l_line_id, --xxinv_transaction_seq.nextval, --> LINE_ID
               l_organization_id, --> ORGANIZATION_ID
               p_tpl_user_name, --> INTERFACE_TARGET -- 'SH'
               l_batch_id, --> BATCH_ID
               'NEW', --> STATUS_CODE
               l_creation_date, --> CREATION_DATE
               NULL, --> LAST_UPDATE_DATE
               fnd_global.user_id, --> CREATED_BY
               fnd_global.login_id, --> LAST_UPDATE_LOGIN
               fnd_global.user_id, --> LAST_UPDATED_BY
               1, --> FILE_ID
               i.doc_type, --> DOC_TYPE
               i.customer_name, --> CUSTOMER_NAME
               i.supplier_name, --> SUPPLIER_NAME
               i.shipment_header_id, --> SHIPMENT_HEADER_ID
               i.shipment_number, --> SHIPMENT_NUMBER
               i.shipment_line_id, --> SHIPMENT_LINE_ID
               i.shipment_line_number, --> SHIPMENT_LINE_NUMBER
               i.order_header_id, --> ORDER_HEADER_ID
               i.order_number, --> ORDER_NUMBER
               i.order_line_id, --> ORDER_LINE_ID
               i.order_line_number, --> ORDER_LINE_NUMBER
               i.po_line_location_id, --> PO_LINE_LOCATION_ID
               i.service_request_reference, --> SERVICE_REQUEST_REFERENCE
               i.expected_receipt_date, --> EXPECTED_RECEIPT_DATE
               i.from_organization_id, --> FROM_ORGANIZATION_ID
               i.item_id, --> ITEM_ID
               i.item_code, --> ITEM_CODE
               i.supplier_item_code, --> SUPPLIER_ITEM_CODE
               i.qty_ordered, --> QTY_ORDERED
               i.qty_uom_code, --> QTY_UOM_CODE
               i.lot_number, --> LOT_NUMBER
               i.lot_expiration_date, --> LOT_EXPIRATION_DATE
               i.lot_status, --> LOT_STATUS
               i.serial_number, --> SERIAL_NUMBER
               i.revision, --> REVISION
               i.subinventory, --> SUBINVENTORY
               i.locator_id, --> LOCATOR_ID
               i.from_subinventory, --> FROM_SUBINVENTORY
               i.from_locator_id, --> FROM_LOCATOR_ID
               i.note_to_receiver, --> NOTE_TO_RECEIVER
               p_tpl_user_name, --> SOURCE_CODE       -- CHG0032515
               i.po_release_id, --> PO_RELEASE_ID     -- CHG0036206
               i.po_release_number, --> PO_RELEASE_NUMBER -- CHG0036206
               i.destination_type_code, -- CHG0049272
               i.transaction_id -- CHG0049272
               );
          
            get_loads(p_po_line_location_id    => i.po_line_location_id,
                      p_doc_type               => i.doc_type,
                      p_qty                    => i.qty_ordered,
                      p_xxinv_trx_rcv_loads_in => l_xxinv_trx_rcv_loads_in,
                      p_error_code             => l_error_code,
                      p_error_desc             => l_error_desc);
          
            if '0' != l_error_code then
              null; ---???????????????????????
            end if;
          
            for i in 1 .. l_xxinv_trx_rcv_loads_in.count loop
              insert into xxinv_trx_rcv_loads_out
                (load_line_id,
                 parent_line_id,
                 po_line_location_id,
                 load_id,
                 load_qty,
                 doc_type)
              values
                (l_xxinv_trx_rcv_loads_in(i).load_line_id,
                 l_line_id,
                 l_xxinv_trx_rcv_loads_in(i).po_line_location_id,
                 l_xxinv_trx_rcv_loads_in(i).load_id,
                 l_xxinv_trx_rcv_loads_in(i).load_qty,
                 l_xxinv_trx_rcv_loads_in(i).doc_type);
            
            end loop;
          
          END IF; -- record not in incoming process
        END IF; -- profile resend
      ELSE
        -- record NOT EXISTS IN OUT TABLE
        -- insert xxinv_trx_rcv_out
        l_flag    := 1;
        l_line_id := xxinv_transaction_seq.nextval;
        INSERT INTO xxinv_trx_rcv_out
          (line_id,
           organization_id,
           interface_target,
           batch_id,
           status_code,
           creation_date,
           last_update_date,
           created_by,
           last_update_login,
           last_updated_by,
           file_id,
           doc_type,
           customer_name,
           supplier_name,
           shipment_header_id,
           shipment_number,
           shipment_line_id,
           shipment_line_number,
           order_header_id,
           order_number,
           order_line_id,
           order_line_number,
           po_line_location_id,
           service_request_reference,
           expected_receipt_date,
           from_organization_id,
           item_id,
           item_code,
           supplier_item_code,
           qty_ordered,
           qty_uom_code,
           lot_number,
           lot_expiration_date,
           lot_status,
           serial_number,
           revision,
           subinventory,
           locator_id,
           from_subinventory,
           from_locator_id,
           note_to_receiver,
           source_code, -- CHG0032515
           po_release_id, -- CHG0036206 Dalit A. Raviv 19/08/2015
           po_release_number,
           DESTINATION_TYPE_CODE, -- CHG0049272
           TRANSACTION_ID -- CHG0049272
           ) -- CHG0036206 Dalit A. Raviv 19/08/2015
        VALUES
          (xxinv_transaction_seq.nextval, --> LINE_ID
           l_organization_id, --> ORGANIZATION_ID
           p_tpl_user_name, --> INTERFACE_TARGET -- 'SH'
           l_batch_id, --> BATCH_ID
           'NEW', --> STATUS_CODE
           l_creation_date, --> CREATION_DATE
           NULL, --> LAST_UPDATE_DATE
           fnd_global.user_id, --> CREATED_BY
           fnd_global.login_id, --> LAST_UPDATE_LOGIN
           fnd_global.user_id, --> LAST_UPDATED_BY
           1, --> FILE_ID
           i.doc_type, --> DOC_TYPE
           i.customer_name, --> CUSTOMER_NAME
           i.supplier_name, --> SUPPLIER_NAME
           i.shipment_header_id, --> SHIPMENT_HEADER_ID
           i.shipment_number, --> SHIPMENT_NUMBER
           i.shipment_line_id, --> SHIPMENT_LINE_ID
           i.shipment_line_number, --> SHIPMENT_LINE_NUMBER
           i.order_header_id, --> ORDER_HEADER_ID
           i.order_number, --> ORDER_NUMBER
           i.order_line_id, --> ORDER_LINE_ID
           i.order_line_number, --> ORDER_LINE_NUMBER
           i.po_line_location_id, --> PO_LINE_LOCATION_ID
           i.service_request_reference, --> SERVICE_REQUEST_REFERENCE
           i.expected_receipt_date, --> EXPECTED_RECEIPT_DATE
           i.from_organization_id, --> FROM_ORGANIZATION_ID
           i.item_id, --> ITEM_ID
           i.item_code, --> ITEM_CODE
           i.supplier_item_code, --> SUPPLIER_ITEM_CODE
           i.qty_ordered, --> QTY_ORDERED
           i.qty_uom_code, --> QTY_UOM_CODE
           i.lot_number, --> LOT_NUMBER
           i.lot_expiration_date, --> LOT_EXPIRATION_DATE
           i.lot_status, --> LOT_STATUS
           i.serial_number, --> SERIAL_NUMBER
           i.revision, --> REVISION
           i.subinventory, --> SUBINVENTORY
           i.locator_id, --> LOCATOR_ID
           i.from_subinventory, --> FROM_SUBINVENTORY
           i.from_locator_id, --> FROM_LOCATOR_ID
           i.note_to_receiver, --> NOTE_TO_RECEIVER
           p_tpl_user_name, --> SOURCE_CODE       -- CHG0032515
           i.po_release_id, --> PO_RELEASE_ID     -- CHG0036206
           i.po_release_number, --> PO_RELEASE_NUMBER -- CHG0036206
           i.destination_type_code, -- CHG0049272
           i.transaction_id -- CHG0049272
           );
      
        -- Added by Roman W. CHG0049272
        get_loads(p_po_line_location_id    => i.po_line_location_id,
                  p_doc_type               => i.doc_type,
                  p_qty                    => i.qty_ordered,
                  p_xxinv_trx_rcv_loads_in => l_xxinv_trx_rcv_loads_in,
                  p_error_code             => l_error_code,
                  p_error_desc             => l_error_desc);
      
        if '0' != l_error_code then
          null; ---???????????????????????
          errbuf  := 2;
          retcode := l_error_desc;
          continue;
        end if;
      
        for i in 1 .. l_xxinv_trx_rcv_loads_in.count loop
          insert into xxinv_trx_rcv_loads_out
            (load_line_id,
             parent_line_id,
             po_line_location_id,
             load_id,
             load_qty,
             doc_type)
          values
            (l_xxinv_trx_rcv_loads_in     (i).load_line_id,
             xxinv_transaction_seq.currval,
             l_xxinv_trx_rcv_loads_in     (i).po_line_location_id,
             l_xxinv_trx_rcv_loads_in     (i).load_id,
             l_xxinv_trx_rcv_loads_in     (i).load_qty,
             l_xxinv_trx_rcv_loads_in     (i).doc_type);
        
        end loop;
        -- End Added by Roman W. CHG0049272
      
        -- check resend mode
        IF fnd_profile.value('XXINV_TPL_RESEND_RCV_FILE') = 'Y' THEN
          l_xxinv_trx_resend_orders_rec                     := NULL;
          l_xxinv_trx_resend_orders_rec.source_code         := p_tpl_user_name;
          l_xxinv_trx_resend_orders_rec.doc_type            := i.doc_type;
          l_xxinv_trx_resend_orders_rec.header_id           := CASE
                                                                i.doc_type
                                                                 WHEN
                                                                  'INTERNAL' THEN
                                                                  i.shipment_header_id
                                                                 ELSE
                                                                  i.order_header_id
                                                               END;
          l_xxinv_trx_resend_orders_rec.line_id             := CASE
                                                                i.doc_type
                                                                 WHEN
                                                                  'INTERNAL' THEN
                                                                  i.shipment_line_id
                                                                 ELSE
                                                                  i.order_line_id
                                                               END;
          l_xxinv_trx_resend_orders_rec.serial              := i.serial_number;
          l_xxinv_trx_resend_orders_rec.lot                 := i.lot_number;
          l_xxinv_trx_resend_orders_rec.po_line_location_id := i.po_line_location_id;
        
          insert_xxinv_trx_resend_orders(l_xxinv_trx_resend_orders_rec);
        END IF;
        --
      END IF;
    END LOOP;
  
    COMMIT;
    -------------------------------------
    -- CHG0036206 Dalit A. Raviv 19/08/2015 c_poll_split
  
    FOR r_poll_split IN c_poll_split(p_inspect_flag) LOOP
      BEGIN
      
        UPDATE xxinv_trx_rcv_out xtro
           SET xtro.status_code           = 'NEW',
               xtro.qty_ordered           = r_poll_split.new_qty,
               xtro.expected_receipt_date = r_poll_split.new_expected_date,
               xtro.batch_id              = l_batch_id,
               xtro.last_update_date      = SYSDATE
         WHERE xtro.po_line_location_id = r_poll_split.po_line_location_id
           AND xtro.order_line_id = r_poll_split.order_line_id;
      
        IF SQL%FOUND THEN
          l_flag := 1;
        END IF; --INC0094855
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
    END LOOP;
    COMMIT;
    -------------------------------------
  
    -- Create xml file for batch id
    IF l_flag = 1 THEN
      -- Whole IF section noam yanai DEC-2104 CHG0033946  - split RMA and PO lines to have one line per serial
      IF fnd_profile.value('XXINV_TPL_RCV_OUT_SPLIT_SERIAL') = 'Y' THEN
        split_serial_in_rcv_file(errbuf        => errbuf,
                                 retcode       => retcode,
                                 p_source_code => p_tpl_user_name,
                                 p_batch_id    => l_batch_id);
      END IF;
    
      message('Start Create xml file....');
      xxobjt_xml_gen_pkg.create_xml_file(errbuf      => l_errbuf,
                                         retcode     => l_retcode,
                                         p_file_id   => l_file_id,
                                         p_file_code => p_file_code,
                                         p_directory => l_directory,
                                         p_param1    => l_batch_id);
      --
      message('l_retcode  = ' || l_retcode);
      message('l_file_id  = ' || l_file_id);
      message('l_batch_id = ' || l_batch_id);
    
      IF l_retcode = 0 THEN
        -- update file_id
        UPDATE xxinv_trx_rcv_out t
           SET t.file_id = l_file_id, t.status_code = 'FILE'
         WHERE t.batch_id = l_batch_id
           AND status_code = 'NEW'; -- INC0094855 (ignore SPLIT status)
      
        COMMIT;
      
        errbuf := 'File id= ' || l_file_id || ' created successfully';
        -- update status
      ELSE
      
        UPDATE xxinv_trx_rcv_out t
           SET t.file_id       = NULL,
               t.status_code   = 'ERROR',
               t.error_message = l_errbuf
         WHERE t.batch_id = l_batch_id;
      
        COMMIT;
        retcode := 2;
        errbuf  := 'File creation failed see, file log : file_id=' ||
                   l_file_id || ' ' || l_errbuf;
        message(errbuf);
      END IF;
    ELSE
      retcode := 1;
      errbuf  := 'No Records found for file';
      message(errbuf);
    END IF; -- l_flag = 1
  
  EXCEPTION
    WHEN OTHERS THEN
      retcode := '2';
      errbuf  := SQLERRM || ' ' || l_err_message;
  END populate_rcv_file;

  -----------------------------------------------------------------
  -- populate_ship_file
  ----------------------------------------------------------------
  -- Purpose: populate interface table
  -----------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------------------
  --     1.0  24.9.13   yuval tal         initial build
  --     1.1  16.3.14   yuval tal         CHG0031433 add column cust_po_number , contact_person
  --     1.2  22.7.14   noam yanai        CHG0032515 add source code
  --     1.3  23.11.14  noam yanai        CHG0033946 add hasp number to the cursor
  --     1.4  22.01.15  noam yanai        CHG0034232 add PTO item and PTO description columns in main cursor
  --                                                 add PTO item and PTO description in the insert into xxinv_trx_ship_out

  --     1.5  11.10.17  piyali bhowmick   CHG0041294 - move the content of populate_ship_file to
  --                                      populate_ship_file_allocate and check the profile
  --                                      value for XXINV: TPL Allocations = Y then  use procedure
  --                                      populate_ship_file_allocate else use  populate_ship_file_no_allocate

  -----------------------------------------------------------------
  PROCEDURE populate_ship_file(errbuf      OUT VARCHAR2,
                               retcode     OUT VARCHAR2,
                               p_file_code IN VARCHAR2,
                               p_user_name IN VARCHAR2,
                               p_directory IN VARCHAR2) IS
  
    l_errbuf  VARCHAR2(500);
    l_retcode NUMBER;
    --  l_file_id       NUMBER;
    --  l_flag          NUMBER := 0;
    --  l_creation_date DATE := SYSDATE;
    l_batch_id NUMBER;
    --
    l_err_code        NUMBER;
    l_err_message     VARCHAR2(2000);
    l_user_id         NUMBER;
    l_resp_id         NUMBER;
    l_resp_appl_id    NUMBER;
    l_organization_id NUMBER;
    --
    l_tmp NUMBER;
    --  l_directory VARCHAR2(400);
    stop_process EXCEPTION;
    /*  l_service_request_number VARCHAR2(64); -- Added by Noam Yanai AUG-2014  CHG0032497- SFDC project
       l_machine_serial_number  VARCHAR2(50); -- Added by Noam Yanai AUG-2014  CHG0032497- SFDC project
       l_field_service_engineer VARCHAR2(500); -- Added by Noam Yanai AUG-2014  CHG0032497- SFDC project
       l_service_application    VARCHAR2(50); -- Added by Noam Yanai AUG-2014  CHG0032497- SFDC project
    
    */
  
  BEGIN
  
    retcode    := 0;
    l_batch_id := fnd_global.conc_request_id;
  
    -- get user details
    xxinv_trx_in_pkg.get_user_details(p_user_name       => p_user_name,
                                      p_user_id         => l_user_id,
                                      p_resp_id         => l_resp_id,
                                      p_resp_appl_id    => l_resp_appl_id,
                                      p_organization_id => l_organization_id,
                                      p_err_code        => l_err_code,
                                      p_err_message     => l_err_message);
  
    IF l_err_code = 1 THEN
      RAISE stop_process;
    END IF;
  
    -------  apps initialize ---------
  
    fnd_global.apps_initialize(l_user_id, l_resp_id, l_resp_appl_id);
  
    /*  l_directory := nvl(p_directory,
             fnd_profile.value('XXINV_TPL_TRX_OUT_DIRECTORY'));
    
    IF xxobjt_general_utils_pkg.am_i_in_production = 'N' THEN
    
      l_directory := REPLACE(l_directory, 'PROD', 'DEV');
    END IF;
    
    message('Output Directory=' || l_directory);
    
    l_service_application := fnd_profile.value_specific('XXINV_TPL_SERVICE_APPLICATION',
                l_user_id); -- Noam Yanai AUG-2014  CHG0032497- SFDC project
    
    
    */
  
    ----------
  
    IF fnd_profile.value('XXINV_TPL_ALLOCATIONS') = 'Y' -- Added by Piyali Bhowmick on 11-10-2017 for CHG0041294
     THEN
      populate_ship_file_allocate(errbuf,
                                  retcode,
                                  p_file_code,
                                  p_user_name,
                                  p_directory,
                                  l_batch_id);
    ELSE
      populate_ship_file_no_allocate(errbuf,
                                     retcode,
                                     p_file_code,
                                     p_user_name,
                                     p_directory,
                                     l_batch_id);
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      retcode := '2';
      errbuf  := SQLERRM || l_err_message;
    
  END populate_ship_file;
  -----------------------------------------------------------------
  -- populate_ship_file_allocate
  ----------------------------------------------------------------
  -- Purpose: populate interface table
  -----------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------------------
  --    1.0  11.10.17  piyali bhowmick  initial build
  --                                     CHG0041294-TPL Interface FC - Remove Pick Allocations
  --    1.1  11.10.17  piyali bhowmick  CHG0041294 add Move order no and move order line no in main cursor
  --                                                add Move order no and move order line no in the insert into xxinv_trx_ship_out
  --    1.2  25.10.17  piyali bhowmick  CHG0041294 - add Ship set number in the main cursor and in the insert into xxinv_trx_ship_out
  --    1.3  07.11.18  Bellona(TCS)     CHG0043872 - Add End User PO Field to TPL Interface and Reports
  -----------------------------------------------------------------
  PROCEDURE populate_ship_file_allocate(errbuf      OUT VARCHAR2,
                                        retcode     OUT VARCHAR2,
                                        p_file_code IN VARCHAR2,
                                        p_user_name IN VARCHAR2,
                                        p_directory IN VARCHAR2,
                                        p_batch_id  IN NUMBER) IS
  
    l_errbuf        VARCHAR2(500);
    l_retcode       NUMBER;
    l_file_id       NUMBER;
    l_flag          NUMBER := 0;
    l_creation_date DATE := SYSDATE;
    l_batch_id      NUMBER;
    --
    l_err_code        NUMBER;
    l_err_message     VARCHAR2(2000);
    l_user_id         NUMBER;
    l_resp_id         NUMBER;
    l_resp_appl_id    NUMBER;
    l_organization_id NUMBER;
    --
    l_tmp       NUMBER;
    l_directory VARCHAR2(400);
    stop_process EXCEPTION;
    l_service_request_number VARCHAR2(64); -- Added by Noam Yanai AUG-2014  CHG0032497- SFDC project
    l_machine_serial_number  VARCHAR2(50); -- Added by Noam Yanai AUG-2014  CHG0032497- SFDC project
    l_field_service_engineer VARCHAR2(500); -- Added by Noam Yanai AUG-2014  CHG0032497- SFDC project
    l_service_application    VARCHAR2(50); -- Added by Noam Yanai AUG-2014  CHG0032497- SFDC project
  
    CURSOR c_ship IS
      SELECT wda.delivery_id,
             wdd.delivery_detail_id,
             oha.order_number,
             trh.request_number move_order_no, -- Added by Piyali Bhowmick SEP -2017 CHG0041294-TPL Interface FC - Remove Pick Allocations
             trl.line_number move_order_line_no, -- Added by Piyali Bhowmick SEP -2017 CHG0041294-TPL Interface FC - Remove Pick Allocations
             os.set_name ship_set_number, -- Added by Piyali Bhowmick SEP -2017 CHG0041294-TPL Interface FC - Remove Pick Allocations
             wdd.source_header_id order_header_id,
             ola.line_number order_line_number,
             wdd.source_line_id order_line_id,
             trunc(wnd.initial_pickup_date) ship_date,
             oha.sold_to_org_id customer_id,
             ola.ship_to_org_id,
             hp.party_name customer_name,
             loc.address1,
             loc.address2,
             loc.address3,
             loc.city,
             --             loc.county,
             nvl(loc.state, loc.county) county, -- Added by Noam Yanai Feb-2014
             loc.province,
             cntry.territory_code country_code,
             cntry.territory_short_name country_name,
             loc.postal_code,
             csm.carrier_id,
             nvl(wnd.ship_method_code, wdd.ship_method_code) shipping_method_code, -- changed by Noam Yanai OCT-2014
             car.carrier_name,
             wnd.mode_of_transport,
             frtrm.freight_terms,
             ttt.name order_type,
             decode(oha.order_type_id,
                     1120,
                     'Please print Service Label for Each Item. ',
                     '') || -- Added by Noam Yanai Feb-2014
             -- (CHG0043872 start)appending End customer PO to Header Shipping instructions
              decode(oha.attribute14,
                     NULL,
                     oha.shipping_instructions,
                     oha.shipping_instructions || ' End Customer PO: ' ||
                     oha.attribute14)
             -- (CHG0043872 end)appending End customer PO to Header Shipping instructions
              head_shipping_instructions,
             oha.packing_instructions head_packing_instructions,
             ola.shipping_instructions line_shipping_instructions,
             ola.packing_instructions line_packing_instructions,
             wnd.additional_shipment_info cust_carrier_number,
             trl.header_id move_order_header_id,
             wdd.move_order_line_id,
             mtt.transaction_temp_id, --> Beware : this might not be a unique identifier !!
             wdd.inventory_item_id,
             sib.segment1 item_code,
             tlt.lot_number,
             CASE
               WHEN nvl(snt.fm_serial_number, 'x') =
                    nvl(snt.to_serial_number, 'x') THEN
                snt.to_serial_number
               ELSE
                snt.fm_serial_number || ' - ' || snt.to_serial_number
             END serial_number,
             mtt.revision,
             wdd.requested_quantity_uom uom_code,
             decode(snt.fm_serial_number,
                    NULL,
                    -- nvl(tlt.transaction_quantity, wdd.requested_quantity),
                    coalesce(tlt.transaction_quantity,
                             mtt.transaction_quantity,
                             wdd.requested_quantity),
                    1) quantity,
             mtt.subinventory_code subinventory,
             mtt.locator_id locator_id,
             wdd.source_line_id, -- Added by Noam Yanai AUG-2014  CHG0032497- SFDC project
             ohd.sf_case_number service_request_number, -- Added by Noam Yanai AUG-2014  CHG0032497- SFDC project
             ohd.printer_sn machine_serial_number, -- Added by Noam Yanai AUG-2014  CHG0032497- SFDC project
             oha.cust_po_number field_service_engineer, -- Added by Noam Yanai AUG-2014  CHG0032497- SFDC project
             oha.cust_po_number cust_po_number, -- Added by Noam Yanai  MAR-2014
             cntct.contact_name contact_person, -- Added by Noam Yanai  MAR-2014
             nvl((SELECT 'Y'
                   FROM oe_order_headers_all         oha,
                        oe_transaction_types_all     tt,
                        oe_transaction_types_all_dfv dfv
                  WHERE oha.header_id = wdd.source_header_id
                    AND tt.transaction_type_id = oha.order_type_id
                    AND dfv.row_id = tt.rowid
                    AND nvl(dfv.rma_sheet_included, 'N') = 'Y'
                    AND EXISTS
                  (SELECT 1
                           FROM oe_order_lines_all       ola,
                                oe_transaction_types_all tta
                          WHERE ola.header_id = oha.header_id
                            AND tta.transaction_type_id = ola.line_type_id
                            AND tta.order_category_code = 'RETURN')),
                 'N') print_rma,
             CASE
               WHEN ttt.name LIKE 'Service Internal Order%' THEN
                'Y'
               WHEN ttt.name LIKE 'General Service%' THEN -- Noam Yanai AUG-2014 CHG0032515
                'Y'
               ELSE
                'N'
             END print_cs_labels,
             decode(fnd_profile.value_specific('XXINV_TPL_EUROPE',
                                               l_user_id), -- Noam Yanai AUG-2014 CHG0032515
                    'Y', ---- when TPL is in EUROPE then print commercial invoice when ship to is to a country out of the European Union
                    nvl((SELECT 'N'
                          FROM fnd_lookup_values lv
                         WHERE lv.lookup_type = 'XX_EU_COUNTRIES'
                           AND lv.view_application_id = 3
                           AND lv.lookup_code = cntry.territory_code -- INC0049392 TPL Country (hp.country) Dalit A. Raviv 22-Oct-2015
                           AND lv.security_group_id = 0
                           AND lv.language = 'US'
                           AND nvl(lv.end_date_active, SYSDATE + 1) >
                               SYSDATE),
                        'Y'),
                    CASE ---- when TPL is not in EUROPE then print commercial invoice when ship to is another country
                      WHEN fnd_profile.value_specific('XXINV_TPL_COUNTRY',
                                                      l_user_id) =
                           nvl(cntry.territory_code,
                               fnd_profile.value_specific('XXINV_TPL_COUNTRY',
                                                          l_user_id)) THEN
                       'N'
                      ELSE
                       'Y'
                    END) print_performa_invoice,
             xxinv_unified_platform_utl_pkg.get_hasp_sn(snt.fm_serial_number) hasp_number, -- noam yanai NOV-2014 CHG0033946
             cntct.contact_phone contact_phone_number, -- noam yanai DEC-2014 CHG0033946
             pto.item_code pto_item_code, -- CHG0034232 Noam Yanai FEB-15
             pto.item_desc pto_item_desc --- CHG0034232 Noam Yanai FEB-15
        FROM wsh_delivery_assignments wda,
             wsh_new_deliveries wnd,
             wsh_delivery_details wdd,
             mtl_system_items_b sib,
             mtl_material_transactions_temp mtt,
             mtl_transaction_lots_temp tlt,
             mtl_serial_numbers_temp snt,
             oe_order_headers_all oha,
             oe_order_lines_all ola,
             oe_order_headers_all_dfv ohd, -- Noam Yanai AUG-2014  CHG0032497- SFDC project
             oe_transaction_types_tl ttt,
             hz_cust_accounts hca,
             hz_cust_site_uses_all csu,
             hz_cust_acct_sites_all cas,
             hz_party_sites hps,
             hz_locations loc,
             hz_parties hp,
             wsh_carrier_ship_methods csm,
             wsh_carriers_v car,
             fnd_territories_tl cntry,
             oe_frght_terms_active_v frtrm,
             mtl_txn_request_lines trl,
             mtl_txn_request_headers trh, --Piyali Bhowmick SEP-2017  CHG0041294-TPL Interface FC - Remove Pick Allocations
             oe_sets os, --Piyali Bhowmick SEP-2017  CHG0041294-TPL Interface FC - Remove Pick Allocations
             xxoe_contacts_v cntct, -- Noam Yanai  MAR-2014
             (SELECT l.line_id,
                     b.segment1    item_code,
                     b.description item_desc
                FROM oe_order_lines_all l, mtl_system_items_b b
               WHERE b.organization_id = 91
                 AND b.inventory_item_id = l.inventory_item_id) pto --- CHG0034232 Noam Yanai FEB-15
       WHERE wnd.organization_id = l_organization_id
         AND wda.delivery_id = wnd.delivery_id
         AND wdd.delivery_detail_id = wda.delivery_detail_id
         AND wdd.released_status = 'S'
         AND sib.inventory_item_id = wdd.inventory_item_id
         AND sib.organization_id = wdd.organization_id
         AND mtt.move_order_line_id = wdd.move_order_line_id
         AND tlt.transaction_temp_id(+) = mtt.transaction_temp_id
         AND snt.transaction_temp_id(+) = mtt.transaction_temp_id
         AND oha.header_id = wdd.source_header_id
         AND ohd.row_id = oha.rowid -- Noam Yanai AUG-2014  CHG0032497- SFDC project
         AND ola.line_id = wdd.source_line_id
         AND ttt.transaction_type_id = oha.order_type_id
         AND ttt.language = 'US'
         AND hca.cust_account_id = cas.cust_account_id -- Noam MAY-2014: ship_to customer instead of bill_to (oha.sold_to_org_id)
         AND hp.party_id = hca.party_id
         AND csm.ship_method_code(+) = wnd.ship_method_code --,wdd.ship_method_code)
         AND csm.organization_id(+) = wnd.organization_id
         AND car.carrier_id(+) = csm.carrier_id
         AND csu.site_use_id(+) = ola.ship_to_org_id -- oha.ship_to_org_id Changed by Noam OCT-2014
         AND cas.cust_acct_site_id(+) = csu.cust_acct_site_id
         AND hps.party_site_id(+) = cas.party_site_id
         AND loc.location_id(+) = hps.location_id
         AND cntry.territory_code(+) = loc.country
         AND cntry.language = 'US'
         AND frtrm.freight_terms_code(+) = wnd.freight_terms_code
         AND trl.line_id = wdd.move_order_line_id
         AND cntct.contact_id(+) = oha.ship_to_contact_id -- Noam Yanai  MAR-2014
         AND pto.line_id(+) = wdd.top_model_line_id --- CHG0034232 Noam Yanai FEB-15
         AND trh.header_id = trl.header_id -- Piyali Bhowmick SEP -2017 CHG0041294-TPL Interface FC - Remove Pick Allocations
         AND ola.ship_set_id = os.set_id(+); -- Piyali Bhowmick SEP -2017 CHG0041294-TPL Interface FC - Remove Pick Allocations
  
  BEGIN
  
    retcode := 0;
    --  l_batch_id := fnd_global.conc_request_id;
    l_batch_id := p_batch_id; --CHG0041294
  
    -- get user details
    xxinv_trx_in_pkg.get_user_details(p_user_name       => p_user_name,
                                      p_user_id         => l_user_id,
                                      p_resp_id         => l_resp_id,
                                      p_resp_appl_id    => l_resp_appl_id,
                                      p_organization_id => l_organization_id,
                                      p_err_code        => l_err_code,
                                      p_err_message     => l_err_message);
  
    IF l_err_code = 1 THEN
      RAISE stop_process;
    END IF;
  
    -- err retry ----
  
    UPDATE xxinv_trx_ship_out t
       SET t.status_code      = 'NEW',
           error_message      = NULL,
           t.last_update_date = SYSDATE,
           t.batch_id         = l_batch_id,
           t.last_updated_by  = fnd_global.user_id
     WHERE t.status_code = 'ERROR'
       AND t.organization_id = l_organization_id;
  
    IF SQL%FOUND THEN
      l_flag := 1;
    END IF;
  
    COMMIT;
    ------- initialize ---------
    -- The init  is  commented as it is already used before in procedure "populate_ship_file"
    -- for CHG0041294-TPL Interface by Piyali Bhowmick on 11-10-2017
  
    --  fnd_global.apps_initialize(l_user_id, l_resp_id, l_resp_appl_id);
  
    l_directory := nvl(p_directory,
                       fnd_profile.value('XXINV_TPL_TRX_OUT_DIRECTORY'));
  
    IF xxobjt_general_utils_pkg.am_i_in_production = 'N' THEN
    
      l_directory := REPLACE(l_directory, 'PROD', 'DEV');
    END IF;
  
    message('Output Directory=' || l_directory);
  
    l_service_application := fnd_profile.value_specific('XXINV_TPL_SERVICE_APPLICATION',
                                                        l_user_id); -- Noam Yanai AUG-2014  CHG0032497- SFDC project
  
    ----------
    FOR i IN c_ship LOOP
      --TRANSACTION_TEMP_ID, LOT_NUMBER, SERIAL_NUMBER
      BEGIN
      
        CASE l_service_application -- Noam Yanai AUG-2014  CHG0032497- SFDC project
          WHEN 'SFDC' THEN
            l_service_request_number := i.service_request_number;
            l_machine_serial_number  := i.machine_serial_number;
            l_field_service_engineer := i.field_service_engineer;
          WHEN 'ORACLE' THEN
            get_service_parameters(errbuf                   => errbuf,
                                   retcode                  => retcode,
                                   p_service_request_number => l_service_request_number,
                                   p_machine_serial_number  => l_machine_serial_number,
                                   p_field_service_engineer => l_field_service_engineer,
                                   p_source_line_id         => i.source_line_id);
          ELSE
            l_service_request_number := i.service_request_number;
            l_machine_serial_number  := i.machine_serial_number;
            l_field_service_engineer := i.field_service_engineer;
        END CASE;
        l_tmp := 0;
        SELECT 1
          INTO l_tmp
          FROM xxinv_trx_ship_out
         WHERE transaction_temp_id = i.transaction_temp_id
           AND nvl(lot_number, '.') = nvl(i.lot_number, '.')
           AND nvl(serial_number, '.') = nvl(i.serial_number, '.');
        -- CHK UNIQUE
      
        -- dbms_output.put_line('FOUND');
      EXCEPTION
        WHEN no_data_found THEN
          --  dbms_output.put_line('NOT FOUND');
          BEGIN
          
            INSERT INTO xxinv_trx_ship_out
              (line_id,
               organization_id,
               interface_target,
               batch_id,
               status_code,
               creation_date,
               last_update_date,
               created_by,
               last_update_login,
               last_updated_by,
               file_id,
               delivery_id,
               delivery_detail_id,
               order_number,
               order_header_id,
               order_line_number,
               order_line_id,
               ship_date,
               customer_name,
               address1,
               address2,
               address3,
               city,
               county,
               province,
               country_code,
               country_name,
               postal_code,
               carrier_name,
               mode_of_transport,
               freight_terms,
               order_type,
               head_shipping_instructions,
               head_packing_instructions,
               line_shipping_instructions,
               line_packing_instructions,
               move_order_header_id,
               move_order_line_id,
               transaction_temp_id,
               inventory_item_id,
               item_code,
               lot_number,
               serial_number,
               revision,
               quantity,
               subinventory,
               locator_id,
               print_rma,
               print_cs_labels,
               print_performa_invoice,
               service_request_number,
               machine_serial_number,
               shipping_method_code,
               customer_id,
               uom_code,
               rma_status,
               cust_carrier_number,
               field_service_engineer,
               cust_po_number,
               contact_person,
               source_code,
               carrier_id,
               ship_to_org_id,
               hasp_number, -- added by noam yanai NOV-2014 CHG0033946
               contact_phone_number, -- added by noam yanai DEC-2014 CHG0033946
               pto_item_code, --- CHG0034232 added by Noam Yanai FEB-15
               pto_item_desc, --- CHG0034232 added by Noam Yanai FEB-15
               move_order_no, -- Added by Piyali Bhowmick on  SEP -2017 for CHG0041294
               move_order_line_no, -- Added by Piyali Bhowmick on  SEP -2017 for CHG0041294
               ship_set_number -- Added by Piyali Bhowmick on  SEP -2017 for CHG0041294
               )
            VALUES
              (xxinv_transaction_seq.nextval, ---> LINE_ID
               l_organization_id, ---> ORGANIZATION_ID
               p_user_name, -- 'SH' ---> INTERFACE_TARGET
               l_batch_id, ---> BATCH_ID
               'NEW', ---> STATUS_CODE
               l_creation_date, ---> CREATION_DATE
               NULL, ---> LAST_UPDATE_DATE
               fnd_global.user_id, ---> CREATED_BY
               fnd_global.login_id, ---> LAST_UPDATE_LOGIN
               fnd_global.user_id, ---> LAST_UPDATED_BY
               NULL, ---> FILE_ID
               i.delivery_id, ---> DELIVERY_ID              ,
               i.delivery_detail_id, ---> DELIVERY_DETAIL_ID              ,
               i.order_number, ---> ORDER_NUMBER              ,
               i.order_header_id, ---> ORDER_HEADER_ID              ,
               i.order_line_number, ---> ORDER_LINE_NUMBER              ,
               i.order_line_id, ---> ORDER_LINE_ID              ,
               i.ship_date, ---> SHIP_DATE              ,
               i.customer_name, ---> CUSTOMER_NAME              ,
               i.address1, ---> ADDRESS1              ,
               i.address2, ---> ADDRESS2              ,
               i.address3, ---> ADDRESS3              ,
               i.city, ---> CITY              ,
               i.county, ---> COUNTY              ,
               i.province, ---> PROVINCE              ,
               i.country_code, ---> COUNTRY_CODE              ,
               i.country_name, ---> COUNTRY_NAME              ,
               i.postal_code, ---> POSTAL_CODE              ,
               i.carrier_name, ---> CARRIER_NAME              ,
               i.mode_of_transport, ---> MODE_OF_TRANSPORT              ,
               i.freight_terms, ---> FREIGHT_TERMS              ,
               i.order_type, ---> ORDER_TYPE              ,
               i.head_shipping_instructions, ---> HEAD_SHIPPING_INSTRUCTIONS              ,
               i.head_packing_instructions, ---> HEAD_PACKING_INSTRUCTIONS             ,
               i.line_shipping_instructions, ---> LINE_SHIPPING_INSTRUCTIONS              ,
               i.line_packing_instructions, ---> LINE_PACKING_INSTRUCTIONS              ,
               i.move_order_header_id, ---> MOVE_ORDER_HEADER_ID              ,
               i.move_order_line_id, ---> MOVE_ORDER_LINE_ID              ,
               i.transaction_temp_id, ---> TRANSACTION_TEMP_ID              ,
               i.inventory_item_id, ---> INVENTORY_ITEM_ID              ,
               i.item_code, ---> ITEM_CODE              ,
               i.lot_number, ---> LOT_NUMBER              ,
               i.serial_number, ---> SERIAL_NUMBER              ,
               i.revision, ---> REVISION              ,
               i.quantity, ---> QUANTITY              ,
               i.subinventory, ---> SUBINVENTORY              ,
               i.locator_id, ---> LOCATOR_ID              ,
               i.print_rma, ---> PRINT_RMA              ,
               i.print_cs_labels, ---> PRINT_CS_LABELS              ,
               i.print_performa_invoice, ---> PRINT_PERFORMA_INVOICE              ,
               l_service_request_number, ---> SERVICE_REQUEST_NUMBER     -- Changed by Noam Yanai AUG-2014  CHG0032497- SFDC project
               l_machine_serial_number, ---> MACHINE_SERIAL_NUMBER       -- Changed by Noam Yanai AUG-2014  CHG0032497- SFDC project
               i.shipping_method_code, ---> SHIPPING_METHOD_CODE              ,
               i.customer_id, ---> CUSTOMER_ID              ,
               i.uom_code, ---> UOM_CODE              ,
               'N', ---> RMA_STATUS              ,
               i.cust_carrier_number, ---> CUST_CARRIER_NUMBER              ,
               l_field_service_engineer, -- Changed by Noam Yanai AUG-2014  CHG0032497- SFDC project              ,
               i.cust_po_number, -- Added by Noam Yanai  MAR-2014              ,
               i.contact_person,
               p_user_name, --->   SOURCE_CODE                      ------ CHG0032515: Changed by noam yanai JUN-2014
               i.carrier_id,
               i.ship_to_org_id,
               i.hasp_number, -- added by noam yanai NOV-2014 CHG0033946
               i.contact_phone_number, -- added by noam yanai DEC-2014 CHG0033946
               i.pto_item_code, --- CHG0034232 added by Noam Yanai FEB-15
               i.pto_item_desc, --- CHG0034232 added by Noam Yanai FEB-15
               i.move_order_no, ---> MOVE_ORDER_NO          --Added by Piyali Bhowmick on  SEP -2017 for CHG0041294
               i.move_order_line_no, --->MOVE_ORDER_LINE_NO --Added by Piyali Bhowmick on  SEP -2017 for CHG0041294
               i.ship_set_number --> SHIP_SET_NUMBER      -- Added by Piyali Bhowmick on  SEP -2017 for CHG0041294
               );
          
            l_flag := 1;
          
            /*EXCEPTION
            WHEN dup_val_on_index THEN
              NULL;*/
          
          END;
      END;
    END LOOP;
  
    COMMIT;
  
    IF l_flag >= 1 THEN
    
      message('Start Create xml file....');
    
      xxobjt_xml_gen_pkg.create_xml_file(errbuf      => l_errbuf,
                                         retcode     => l_retcode,
                                         p_file_id   => l_file_id,
                                         p_file_code => p_file_code,
                                         p_directory => l_directory,
                                         p_param1    => l_batch_id);
      --
      message('l_retcode=' || l_retcode);
    
      IF l_retcode = 0 THEN
        -- update file_id
        UPDATE xxinv_trx_ship_out t
           SET t.file_id = l_file_id, t.status_code = 'FILE'
         WHERE t.batch_id = l_batch_id;
      
        COMMIT;
        errbuf := 'File id= ' || l_file_id || ' created successfully';
        --
        -- update status
      ELSE
      
        UPDATE xxinv_trx_ship_out t
           SET t.file_id     = NULL,
               t.status_code = 'ERROR',
               error_message = l_errbuf
         WHERE t.batch_id = l_batch_id;
      
        COMMIT;
        retcode := 2;
        errbuf  := 'File creation failed see, file log : file_id=' ||
                   l_file_id || ' ' || l_errbuf;
        message(errbuf);
      
      END IF;
    
    ELSE
    
      --retcode := 1;
      errbuf := 'No Records found';
      message(errbuf);
    
    END IF;
    --   generate_rma_report
    generate_rma_report(errbuf            => l_errbuf,
                        retcode           => l_retcode,
                        p_prefix_name     => 'RMA',
                        p_organization_id => l_organization_id,
                        p_line_id         => NULL);
  
  EXCEPTION
    WHEN OTHERS THEN
      retcode := '2';
      errbuf  := SQLERRM || l_err_message;
    
  END populate_ship_file_allocate;
  -----------------------------------------------------------------
  -- populate_ship_file_no_allocate
  ----------------------------------------------------------------
  -- Purpose: populate interface table
  -----------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------------------
  --  1.0     11.10.17  piyali bhowmick  initial build
  --                                     CHG0041294-TPL Interface FC - Remove Pick Allocations

  --   1.1    11.10.17  piyali bhowmick  CHG0041294 - change in query of the Cursor logic (c_ship)
  --                                                    and  also of the CHK UNIQUE logic which is now based on Delivery Detail ID and MO line ID
  --   1.2    25.10.17  piyali bhowmick  CHG0041294 - add Ship set number in the main cursor and in the insert into xxinv_trx_ship_out
  --   1.3    07.11.18  Bellona(TCS)     CHG0043872 - Add End User PO Field to TPL Interface and Reports
  -----------------------------------------------------------------
  PROCEDURE populate_ship_file_no_allocate(errbuf      OUT VARCHAR2,
                                           retcode     OUT VARCHAR2,
                                           p_file_code IN VARCHAR2,
                                           p_user_name IN VARCHAR2,
                                           p_directory IN VARCHAR2,
                                           p_batch_id  IN NUMBER) IS
  
    l_errbuf        VARCHAR2(500);
    l_retcode       NUMBER;
    l_file_id       NUMBER;
    l_flag          NUMBER := 0;
    l_creation_date DATE := SYSDATE;
    l_batch_id      NUMBER;
    --
    l_err_code        NUMBER;
    l_err_message     VARCHAR2(2000);
    l_user_id         NUMBER;
    l_resp_id         NUMBER;
    l_resp_appl_id    NUMBER;
    l_organization_id NUMBER;
    --
    l_tmp       NUMBER;
    l_directory VARCHAR2(400);
    stop_process EXCEPTION;
    l_service_request_number VARCHAR2(64); -- Added by Noam Yanai AUG-2014  CHG0032497- SFDC project
    l_machine_serial_number  VARCHAR2(50); -- Added by Noam Yanai AUG-2014  CHG0032497- SFDC project
    l_field_service_engineer VARCHAR2(500); -- Added by Noam Yanai AUG-2014  CHG0032497- SFDC project
    l_service_application    VARCHAR2(50); -- Added by Noam Yanai AUG-2014  CHG0032497- SFDC project
  
    CURSOR c_ship IS -- Added by Piyali Bhowmick on 11.10.17 for  CHG0041294-TPL Interface FC
      SELECT wda.delivery_id,
             wdd.delivery_detail_id,
             oha.order_number,
             trh.request_number     move_order_no, -- Added by Piyali Bhowmick SEP -2017 CHG0041294-TPL Interface FC - Remove Pick Allocations
             trl.line_number        move_order_line_no, -- Added by Piyali Bhowmick SEP -2017 CHG0041294-TPL Interface FC - Remove Pick Allocations
             os.set_name            ship_set_number, -- Added by Piyali Bhowmick SEP -2017 CHG0041294-TPL Interface FC - Remove Pick Allocations
             wdd.source_header_id   order_header_id,
             ola.line_number        order_line_number,
             wdd.source_line_id     order_line_id,
             --trunc(wnd.initial_pickup_date) ship_date, -- Dovik Delete
             trunc(wdd.date_scheduled) ship_date, -- Dovik New
             oha.sold_to_org_id customer_id,
             ola.ship_to_org_id,
             hp.party_name customer_name,
             loc.address1,
             loc.address2,
             loc.address3,
             loc.city,
             --             loc.county,
             nvl(loc.state, loc.county) county, -- Added by Noam Yanai Feb-2014
             loc.province,
             cntry.territory_code country_code,
             cntry.territory_short_name country_name,
             loc.postal_code,
             csm.carrier_id,
             --nvl(wnd.ship_method_code, wdd.ship_method_code) shipping_method_code, -- changed by Noam Yanai OCT-2014 Dovik Delete
             wdd.ship_method_code shipping_method_code, --Dovik New
             car.carrier_name,
             --wnd.mode_of_transport, Dovik Delete
             wdd.mode_of_transport, --Dovik New
             frtrm.freight_terms,
             ttt.name order_type,
             decode(oha.order_type_id,
                     1120,
                     'Please print Service Label for Each Item. ',
                     '') || -- Added by Noam Yanai Feb-2014
             -- (CHG0043872 start)appending End customer PO to Header Shipping instructions
              decode(oha.attribute14,
                     NULL,
                     oha.shipping_instructions,
                     oha.shipping_instructions || ' End Customer PO: ' ||
                     oha.attribute14)
             -- (CHG0043872 end)appending End customer PO to Header Shipping instructions
              head_shipping_instructions,
             oha.packing_instructions head_packing_instructions,
             ola.shipping_instructions line_shipping_instructions,
             ola.packing_instructions line_packing_instructions,
             '' /*wnd.additional_shipment_info*/ cust_carrier_number, --Dovik Update
             trl.header_id move_order_header_id,
             wdd.move_order_line_id,
             mtt.transaction_temp_id, --> Beware : this might not be a unique identifier !!
             wdd.inventory_item_id,
             sib.segment1 item_code,
             tlt.lot_number,
             CASE
               WHEN nvl(snt.fm_serial_number, 'x') =
                    nvl(snt.to_serial_number, 'x') THEN
                snt.to_serial_number
               ELSE
                snt.fm_serial_number || ' - ' || snt.to_serial_number
             END serial_number,
             mtt.revision,
             wdd.requested_quantity_uom uom_code,
             decode(snt.fm_serial_number,
                    NULL,
                    -- nvl(tlt.transaction_quantity, wdd.requested_quantity),
                    coalesce(tlt.transaction_quantity,
                             mtt.transaction_quantity,
                             wdd.requested_quantity),
                    1) quantity,
             -- mtt.subinventory_code subinventory, --dovik delete
             trl.from_subinventory_code subinventory, --dovik new
             --mtt.locator_id locator_id, --dovik delete
             trl.from_locator_id locator_id, --dovik new
             wdd.source_line_id, -- Added by Noam Yanai AUG-2014  CHG0032497- SFDC project
             ohd.sf_case_number service_request_number, -- Added by Noam Yanai AUG-2014  CHG0032497- SFDC project
             ohd.printer_sn machine_serial_number, -- Added by Noam Yanai AUG-2014  CHG0032497- SFDC project
             oha.cust_po_number field_service_engineer, -- Added by Noam Yanai AUG-2014  CHG0032497- SFDC project
             oha.cust_po_number cust_po_number, -- Added by Noam Yanai  MAR-2014
             cntct.contact_name contact_person, -- Added by Noam Yanai  MAR-2014
             nvl((SELECT 'Y'
                   FROM oe_order_headers_all         oha,
                        oe_transaction_types_all     tt,
                        oe_transaction_types_all_dfv dfv
                  WHERE oha.header_id = wdd.source_header_id
                    AND tt.transaction_type_id = oha.order_type_id
                    AND dfv.row_id = tt.rowid
                    AND nvl(dfv.rma_sheet_included, 'N') = 'Y'
                    AND EXISTS
                  (SELECT 1
                           FROM oe_order_lines_all       ola,
                                oe_transaction_types_all tta
                          WHERE ola.header_id = oha.header_id
                            AND tta.transaction_type_id = ola.line_type_id
                            AND tta.order_category_code = 'RETURN')),
                 'N') print_rma,
             CASE
               WHEN ttt.name LIKE 'Service Internal Order%' THEN
                'Y'
               WHEN ttt.name LIKE 'General Service%' THEN -- Noam Yanai AUG-2014 CHG0032515
                'Y'
               ELSE
                'N'
             END print_cs_labels,
             decode(fnd_profile.value_specific('XXINV_TPL_EUROPE',
                                               l_user_id), -- Noam Yanai AUG-2014 CHG0032515
                    'Y', ---- when TPL is in EUROPE then print commercial invoice when ship to is to a country out of the European Union
                    nvl((SELECT 'N'
                          FROM fnd_lookup_values lv
                         WHERE lv.lookup_type = 'XX_EU_COUNTRIES'
                           AND lv.view_application_id = 3
                           AND lv.lookup_code = cntry.territory_code -- INC0049392 TPL Country (hp.country) Dalit A. Raviv 22-Oct-2015
                           AND lv.security_group_id = 0
                           AND lv.language = 'US'
                           AND nvl(lv.end_date_active, SYSDATE + 1) >
                               SYSDATE),
                        'Y'),
                    CASE ---- when TPL is not in EUROPE then print commercial invoice when ship to is another country
                      WHEN fnd_profile.value_specific('XXINV_TPL_COUNTRY',
                                                      l_user_id) =
                           nvl(cntry.territory_code,
                               fnd_profile.value_specific('XXINV_TPL_COUNTRY',
                                                          l_user_id)) THEN
                       'N'
                      ELSE
                       'Y'
                    END) print_performa_invoice,
             xxinv_unified_platform_utl_pkg.get_hasp_sn(snt.fm_serial_number) hasp_number, -- noam yanai NOV-2014 CHG0033946
             cntct.contact_phone contact_phone_number, -- noam yanai DEC-2014 CHG0033946
             pto.item_code pto_item_code, -- CHG0034232 Noam Yanai FEB-15
             pto.item_desc pto_item_desc --- CHG0034232 Noam Yanai FEB-15
        FROM wsh_delivery_assignments wda,
             --wsh_new_deliveries wnd, --Dovik Delete
             wsh_delivery_details wdd,
             mtl_system_items_b sib,
             mtl_material_transactions_temp mtt,
             mtl_transaction_lots_temp tlt,
             mtl_serial_numbers_temp snt,
             oe_order_headers_all oha,
             oe_order_lines_all ola,
             oe_order_headers_all_dfv ohd, -- Noam Yanai AUG-2014  CHG0032497- SFDC project
             oe_transaction_types_tl ttt,
             hz_cust_accounts hca,
             hz_cust_site_uses_all csu,
             hz_cust_acct_sites_all cas,
             hz_party_sites hps,
             hz_locations loc,
             hz_parties hp,
             wsh_carrier_ship_methods csm,
             wsh_carriers_v car,
             fnd_territories_tl cntry,
             oe_frght_terms_active_v frtrm,
             mtl_txn_request_headers trh, --Piyali Bhowmick SEP-2017  CHG0041294-TPL Interface FC - Remove Pick Allocations
             mtl_txn_request_lines trl,
             oe_sets os, --Piyali Bhowmick SEP-2017  CHG0041294-TPL Interface FC - Remove Pick Allocations
             xxoe_contacts_v cntct, -- Noam Yanai  MAR-2014
             (SELECT l.line_id,
                     b.segment1    item_code,
                     b.description item_desc
                FROM oe_order_lines_all l, mtl_system_items_b b
               WHERE b.organization_id = 91
                 AND b.inventory_item_id = l.inventory_item_id) pto --- CHG0034232 Noam Yanai FEB-15
      --WHERE  wnd.organization_id = l_organization_id --Dovik Delete
       WHERE wdd.organization_id = l_organization_id -- Dovik New
            --AND    wda.delivery_id = wnd.delivery_id --Dovik Delete
         AND wdd.delivery_detail_id(+) = wda.delivery_detail_id --Dovik Update
         AND wdd.released_status = 'S'
         AND sib.inventory_item_id = wdd.inventory_item_id
         AND sib.organization_id = wdd.organization_id
         AND mtt.move_order_line_id(+) = wdd.move_order_line_id --Dovik Update
         AND tlt.transaction_temp_id(+) = mtt.transaction_temp_id
         AND snt.transaction_temp_id(+) = mtt.transaction_temp_id
         AND oha.header_id = wdd.source_header_id
         AND ohd.row_id = oha.rowid -- Noam Yanai AUG-2014  CHG0032497- SFDC project
         AND ola.line_id = wdd.source_line_id
         AND ttt.transaction_type_id = oha.order_type_id
         AND ttt.language = 'US'
         AND hca.cust_account_id = cas.cust_account_id -- Noam MAY-2014: ship_to customer instead of bill_to (oha.sold_to_org_id)
         AND hp.party_id = hca.party_id
         AND csm.ship_method_code(+) = wdd.ship_method_code --,wdd.ship_method_code) --Dovik Update
         AND csm.organization_id(+) = wdd.organization_id --Dovik Update
         AND car.carrier_id(+) = csm.carrier_id
         AND csu.site_use_id(+) = ola.ship_to_org_id -- oha.ship_to_org_id Changed by Noam OCT-2014
         AND cas.cust_acct_site_id(+) = csu.cust_acct_site_id
         AND hps.party_site_id(+) = cas.party_site_id
         AND loc.location_id(+) = hps.location_id
         AND cntry.territory_code(+) = loc.country
         AND cntry.language = 'US'
         AND frtrm.freight_terms_code(+) = wdd.freight_terms_code --Dovik Update
         AND trl.line_id = wdd.move_order_line_id
         AND cntct.contact_id(+) = oha.ship_to_contact_id -- Noam Yanai  MAR-2014
         AND wda.delivery_id IS NULL --Dovik New
         AND pto.line_id(+) = wdd.top_model_line_id --- CHG0034232 Noam Yanai FEB-15
         AND trh.header_id = trl.header_id -- Piyali Bhowmick SEP -2017 CHG0041294-TPL Interface FC - Remove Pick Allocations
         AND ola.ship_set_id = os.set_id(+); -- Piyali Bhowmick SEP -2017 CHG0041294-TPL Interface FC - Remove Pick Allocations
  
  BEGIN
  
    retcode := 0;
    --  l_batch_id := fnd_global.conc_request_id;
    l_batch_id := p_batch_id; --CHG0041294
  
    -- get user details
    xxinv_trx_in_pkg.get_user_details(p_user_name       => p_user_name,
                                      p_user_id         => l_user_id,
                                      p_resp_id         => l_resp_id,
                                      p_resp_appl_id    => l_resp_appl_id,
                                      p_organization_id => l_organization_id,
                                      p_err_code        => l_err_code,
                                      p_err_message     => l_err_message);
  
    IF l_err_code = 1 THEN
      RAISE stop_process;
    END IF;
  
    -- err retry ----
  
    UPDATE xxinv_trx_ship_out t
       SET t.status_code      = 'NEW',
           error_message      = NULL,
           t.last_update_date = SYSDATE,
           t.batch_id         = l_batch_id,
           t.last_updated_by  = fnd_global.user_id
     WHERE t.status_code = 'ERROR'
       AND t.organization_id = l_organization_id;
  
    IF SQL%FOUND THEN
      l_flag := 1;
    END IF;
  
    COMMIT;
    ------- initialize ---------
    -- The  init is  commented as it is already used before in procedure "populate_ship_file"
    -- for CHG0041294-TPL Interface by Piyali Bhowmick on 11-10-2017
  
    --fnd_global.apps_initialize(l_user_id, l_resp_id, l_resp_appl_id);
  
    l_directory := nvl(p_directory,
                       fnd_profile.value('XXINV_TPL_TRX_OUT_DIRECTORY'));
  
    IF xxobjt_general_utils_pkg.am_i_in_production = 'N' THEN
    
      l_directory := REPLACE(l_directory, 'PROD', 'DEV');
    END IF;
  
    message('Output Directory=' || l_directory);
  
    l_service_application := fnd_profile.value_specific('XXINV_TPL_SERVICE_APPLICATION',
                                                        l_user_id); -- Noam Yanai AUG-2014  CHG0032497- SFDC project*/
  
    ----------
  
    FOR i IN c_ship LOOP
      --TRANSACTION_TEMP_ID, LOT_NUMBER, SERIAL_NUMBER
      BEGIN
      
        CASE l_service_application -- Noam Yanai AUG-2014  CHG0032497- SFDC project
          WHEN 'SFDC' THEN
            l_service_request_number := i.service_request_number;
            l_machine_serial_number  := i.machine_serial_number;
            l_field_service_engineer := i.field_service_engineer;
          WHEN 'ORACLE' THEN
            get_service_parameters(errbuf                   => errbuf,
                                   retcode                  => retcode,
                                   p_service_request_number => l_service_request_number,
                                   p_machine_serial_number  => l_machine_serial_number,
                                   p_field_service_engineer => l_field_service_engineer,
                                   p_source_line_id         => i.source_line_id);
          ELSE
            l_service_request_number := i.service_request_number;
            l_machine_serial_number  := i.machine_serial_number;
            l_field_service_engineer := i.field_service_engineer;
        END CASE;
        l_tmp := 0;
        SELECT 1
          INTO l_tmp
          FROM xxinv_trx_ship_out
         WHERE delivery_detail_id = i.delivery_detail_id --  CHG0041294
           AND move_order_line_id = i.move_order_line_id -- Added by Piyali Bhowmick on 11.10.17 for  CHG0041294-TPL Interface FC
           AND rownum = 1; --CHG0041294
      
        -- CHK UNIQUE
      
        -- dbms_output.put_line('FOUND');
      EXCEPTION
        WHEN no_data_found THEN
          --  dbms_output.put_line('NOT FOUND');
          BEGIN
          
            IF (nvl(l_tmp, 0) = 0) THEN
              --CHG0041294
              INSERT INTO xxinv_trx_ship_out
                (line_id,
                 organization_id,
                 interface_target,
                 batch_id,
                 status_code,
                 creation_date,
                 last_update_date,
                 created_by,
                 last_update_login,
                 last_updated_by,
                 file_id,
                 delivery_id,
                 delivery_detail_id,
                 order_number,
                 order_header_id,
                 order_line_number,
                 order_line_id,
                 ship_date,
                 customer_name,
                 address1,
                 address2,
                 address3,
                 city,
                 county,
                 province,
                 country_code,
                 country_name,
                 postal_code,
                 carrier_name,
                 mode_of_transport,
                 freight_terms,
                 order_type,
                 head_shipping_instructions,
                 head_packing_instructions,
                 line_shipping_instructions,
                 line_packing_instructions,
                 move_order_header_id,
                 move_order_line_id,
                 transaction_temp_id,
                 inventory_item_id,
                 item_code,
                 lot_number,
                 serial_number,
                 revision,
                 quantity,
                 subinventory,
                 locator_id,
                 print_rma,
                 print_cs_labels,
                 print_performa_invoice,
                 service_request_number,
                 machine_serial_number,
                 shipping_method_code,
                 customer_id,
                 uom_code,
                 rma_status,
                 cust_carrier_number,
                 field_service_engineer,
                 cust_po_number,
                 contact_person,
                 source_code,
                 carrier_id,
                 ship_to_org_id,
                 hasp_number, -- added by noam yanai NOV-2014 CHG0033946
                 contact_phone_number, -- added by noam yanai DEC-2014 CHG0033946
                 pto_item_code, --- CHG0034232 added by Noam Yanai FEB-15
                 pto_item_desc, --- CHG0034232 added by Noam Yanai FEB-15
                 move_order_no, -- Added by Piyali Bhowmick on  SEP -2017 for CHG0041294
                 move_order_line_no, -- Added by Piyali Bhowmick on  SEP -2017 for CHG0041294
                 ship_set_number -- Added by Piyali Bhowmick on  SEP -2017 for CHG0041294
                 )
              
              VALUES
                (xxinv_transaction_seq.nextval, ---> LINE_ID
                 l_organization_id, ---> ORGANIZATION_ID
                 p_user_name, -- 'SH' ---> INTERFACE_TARGET
                 l_batch_id, ---> BATCH_ID
                 'NEW', ---> STATUS_CODE
                 l_creation_date, ---> CREATION_DATE
                 NULL, ---> LAST_UPDATE_DATE
                 fnd_global.user_id, ---> CREATED_BY
                 fnd_global.login_id, ---> LAST_UPDATE_LOGIN
                 fnd_global.user_id, ---> LAST_UPDATED_BY
                 NULL, ---> FILE_ID
                 i.delivery_id, ---> DELIVERY_ID              ,
                 i.delivery_detail_id, ---> DELIVERY_DETAIL_ID              ,
                 i.order_number, ---> ORDER_NUMBER              ,
                 i.order_header_id, ---> ORDER_HEADER_ID              ,
                 i.order_line_number, ---> ORDER_LINE_NUMBER              ,
                 i.order_line_id, ---> ORDER_LINE_ID              ,
                 i.ship_date, ---> SHIP_DATE              ,
                 i.customer_name, ---> CUSTOMER_NAME              ,
                 i.address1, ---> ADDRESS1              ,
                 i.address2, ---> ADDRESS2              ,
                 i.address3, ---> ADDRESS3              ,
                 i.city, ---> CITY              ,
                 i.county, ---> COUNTY              ,
                 i.province, ---> PROVINCE              ,
                 i.country_code, ---> COUNTRY_CODE              ,
                 i.country_name, ---> COUNTRY_NAME              ,
                 i.postal_code, ---> POSTAL_CODE              ,
                 i.carrier_name, ---> CARRIER_NAME              ,
                 i.mode_of_transport, ---> MODE_OF_TRANSPORT              ,
                 i.freight_terms, ---> FREIGHT_TERMS              ,
                 i.order_type, ---> ORDER_TYPE              ,
                 i.head_shipping_instructions, ---> HEAD_SHIPPING_INSTRUCTIONS              ,
                 i.head_packing_instructions, ---> HEAD_PACKING_INSTRUCTIONS             ,
                 i.line_shipping_instructions, ---> LINE_SHIPPING_INSTRUCTIONS              ,
                 i.line_packing_instructions, ---> LINE_PACKING_INSTRUCTIONS              ,
                 i.move_order_header_id, ---> MOVE_ORDER_HEADER_ID              ,
                 i.move_order_line_id, ---> MOVE_ORDER_LINE_ID              ,
                 i.transaction_temp_id, ---> TRANSACTION_TEMP_ID              ,
                 i.inventory_item_id, ---> INVENTORY_ITEM_ID              ,
                 i.item_code, ---> ITEM_CODE              ,
                 i.lot_number, ---> LOT_NUMBER              ,
                 i.serial_number, ---> SERIAL_NUMBER              ,
                 i.revision, ---> REVISION              ,
                 i.quantity, ---> QUANTITY              ,
                 i.subinventory, ---> SUBINVENTORY              ,
                 i.locator_id, ---> LOCATOR_ID              ,
                 i.print_rma, ---> PRINT_RMA              ,
                 i.print_cs_labels, ---> PRINT_CS_LABELS              ,
                 i.print_performa_invoice, ---> PRINT_PERFORMA_INVOICE              ,
                 l_service_request_number, ---> SERVICE_REQUEST_NUMBER     -- Changed by Noam Yanai AUG-2014  CHG0032497- SFDC project
                 l_machine_serial_number, ---> MACHINE_SERIAL_NUMBER       -- Changed by Noam Yanai AUG-2014  CHG0032497- SFDC project
                 i.shipping_method_code, ---> SHIPPING_METHOD_CODE              ,
                 i.customer_id, ---> CUSTOMER_ID              ,
                 i.uom_code, ---> UOM_CODE              ,
                 'N', ---> RMA_STATUS              ,
                 i.cust_carrier_number, ---> CUST_CARRIER_NUMBER              ,
                 l_field_service_engineer, -- Changed by Noam Yanai AUG-2014  CHG0032497- SFDC project              ,
                 i.cust_po_number, -- Added by Noam Yanai  MAR-2014              ,
                 i.contact_person,
                 p_user_name, --->   SOURCE_CODE                      ------ CHG0032515: Changed by noam yanai JUN-2014
                 i.carrier_id,
                 i.ship_to_org_id,
                 i.hasp_number, -- added by noam yanai NOV-2014 CHG0033946
                 i.contact_phone_number, -- added by noam yanai DEC-2014 CHG0033946
                 i.pto_item_code, --- CHG0034232 added by Noam Yanai FEB-15
                 i.pto_item_desc, --- CHG0034232 added by Noam Yanai FEB-15
                 i.move_order_no, ---> MOVE_ORDER_NO          --Added by Piyali Bhowmick on  SEP -2017 for CHG0041294
                 i.move_order_line_no, --->MOVE_ORDER_LINE_NO --Added by Piyali Bhowmick on  SEP -2017 for CHG0041294
                 i.ship_set_number --> SHIP_SET_NUMBER      -- Added by Piyali Bhowmick on  SEP -2017 for CHG0041294
                 );
            
              l_flag := 1; --CHG0041294
            
            END IF; -- Added by Piyali Bhowmick on  SEP -2017 for CHG004129
          
          END;
      END;
    END LOOP;
  
    COMMIT;
  
    IF l_flag >= 1 THEN
    
      message('Start Create xml file....');
    
      xxobjt_xml_gen_pkg.create_xml_file(errbuf      => l_errbuf,
                                         retcode     => l_retcode,
                                         p_file_id   => l_file_id,
                                         p_file_code => p_file_code,
                                         p_directory => l_directory,
                                         p_param1    => l_batch_id);
      --
      message('l_retcode=' || l_retcode);
    
      IF l_retcode = 0 THEN
        -- update file_id
        UPDATE xxinv_trx_ship_out t
           SET t.file_id = l_file_id, t.status_code = 'FILE'
         WHERE t.batch_id = l_batch_id;
      
        COMMIT;
        errbuf := 'File id= ' || l_file_id || ' created successfully';
        --
        -- update status
      ELSE
      
        UPDATE xxinv_trx_ship_out t
           SET t.file_id     = NULL,
               t.status_code = 'ERROR',
               error_message = l_errbuf
         WHERE t.batch_id = l_batch_id;
      
        COMMIT;
        retcode := 2;
        errbuf  := 'File creation failed see, file log : file_id=' ||
                   l_file_id || ' ' || l_errbuf;
        message(errbuf);
      
      END IF;
    
    ELSE
    
      --retcode := 1;
      errbuf := 'No Records found';
      message(errbuf);
    
    END IF;
    --   generate_rma_report
    generate_rma_report(errbuf            => l_errbuf,
                        retcode           => l_retcode,
                        p_prefix_name     => 'RMA',
                        p_organization_id => l_organization_id,
                        p_line_id         => NULL);
  
  EXCEPTION
    WHEN OTHERS THEN
      retcode := '2';
      errbuf  := SQLERRM || l_err_message;
    
  END populate_ship_file_no_allocate;

  -----------------------------------------------------------------
  -- populate_wip_file
  ----------------------------------------------------------------
  -- Purpose: populate interface table
  -----------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------------------
  --     1.0  22.7.14   noam yanai      initial build CHG0032515
  --     1.1  23.11.14  noam.yanai      CHG0033946 add hasp number to the cursor
  --     1.2  13.5.20   yuval tal       INC0191108 - modify cursor c_wip replace source name logic
  --     1.3  26.7.20   yuval tal       INC0200056 - modify populate_wip_file - performance improvment

  -----------------------------------------------------------------
  PROCEDURE populate_wip_file(errbuf      OUT VARCHAR2,
                              retcode     OUT VARCHAR2,
                              p_file_code IN VARCHAR2,
                              p_user_name IN VARCHAR2,
                              p_directory IN VARCHAR2) IS
  
    l_errbuf        VARCHAR2(500);
    l_retcode       NUMBER;
    l_file_id       NUMBER;
    l_flag          NUMBER := 0;
    l_creation_date DATE := SYSDATE;
    l_batch_id      NUMBER;
    --
    l_err_code        NUMBER;
    l_err_message     VARCHAR2(2000);
    l_user_id         NUMBER;
    l_resp_id         NUMBER;
    l_resp_appl_id    NUMBER;
    l_organization_id NUMBER;
    --
    l_tmp       NUMBER;
    l_directory VARCHAR2(400);
    stop_process EXCEPTION;
  
    l_master_org_id NUMBER; --INC0200056
  
    CURSOR c_wip(c_master_org_id NUMBER) IS
      SELECT mtt.organization_id organization_id,
             /*  (SELECT MAX(f.user_name)
              FROM fnd_user f
             WHERE fnd_profile.value_specific('XXINV_TPL_ORGANIZATION_ID',
                                              f.user_id) =
                   mtt.organization_id) source_code,*/ -- INC0191108
             p_user_name              source_code, -- INC0191108
             trh.header_id            move_order_header_id,
             trh.move_order_type      move_order_type,
             trl.line_id              move_order_line_id,
             mtt.transaction_temp_id  transaction_temp_id,
             mtt.inventory_item_id    component_item_id,
             cmp.segment1             component_item_code,
             mtt.revision             component_revision,
             snt.fm_serial_number     component_serial_number,
             tlt.lot_number           component_lot_number,
             mtt.transaction_quantity component_qnty,
             mtt.transaction_uom      component_uom_code,
             wdj.primary_item_id      assembly_item_id,
             asm.segment1             assembly_item_code,
             asm.description          assembly_item_description, -- added 09/09/14
             wdj.bom_revision         assembly_revision,
             asm_ser.fm_serial_number assembly_serail_number,
             
             xxinv_unified_platform_utl_pkg.get_hasp_sn(asm_ser.fm_serial_number) assembly_hasp_number, -- added by noam yanai NOV-2014 CHG0033946
             
             wdj.lot_number assembly_lot_number,
             wdj.start_quantity assembly_qnty,
             asm.primary_uom_code assembly_uom_code,
             wdj.wip_entity_id job_id,
             wdj.wip_entity_name job_number,
             wrv.segment1 sales_order_number,
             ola.line_number sales_order_line_number,
             trunc(ola.schedule_ship_date) schedule_ship_date,
             mtt.subinventory_code component_from_subinventory,
             mtt.locator_id component_from_locator_id,
             wdj.completion_subinventory completion_to_subinventory,
             wdj.completion_locator_id completion_to_locator_id
        FROM mtl_system_items_b cmp,
             mtl_system_items_b asm,
             mtl_material_transactions_temp mtt,
             mtl_transaction_lots_temp tlt,
             mtl_serial_numbers_temp snt,
             mtl_txn_request_lines trl,
             mtl_txn_request_headers trh,
             wip_discrete_jobs_v wdj,
             org_organization_definitions org,
             wip_reservations_v wrv,
             oe_order_lines_all ola,
             (SELECT wdj.wip_entity_id,
                     MAX(snt.fm_serial_number) fm_serial_number
                FROM mtl_item_categories_v          miv,
                     wip_discrete_jobs_v            wdj,
                     mtl_txn_request_lines          trl,
                     mtl_material_transactions_temp mtt,
                     mtl_serial_numbers_temp        snt
               WHERE trl.txn_source_id = wdj.wip_entity_id
                 AND miv.inventory_item_id = trl.inventory_item_id
                 AND miv.category_set_name = 'Activity Analysis'
                 AND miv.segment1 = 'General'
                 AND miv.organization_id = c_master_org_id
                 AND mtt.move_order_line_id = trl.line_id
                 AND snt.transaction_temp_id = mtt.transaction_temp_id
               GROUP BY wdj.wip_entity_id) asm_ser
      
       WHERE 1 = 1
            --   AND wdj.wip_entity_id = 4739240
         AND mtt.organization_id = l_organization_id --INC0200056
         AND trl.transaction_type_id = 35
         AND cmp.inventory_item_id = mtt.inventory_item_id
         AND cmp.organization_id = mtt.organization_id
         AND org.organization_id = mtt.organization_id
         AND mtt.move_order_line_id = trl.line_id
         AND tlt.transaction_temp_id(+) = mtt.transaction_temp_id
         AND snt.transaction_temp_id(+) = mtt.transaction_temp_id
         AND wdj.wip_entity_id = trl.txn_source_id
         AND asm.organization_id = wdj.organization_id
         AND asm.inventory_item_id = wdj.primary_item_id
         AND trh.header_id = trl.header_id
         AND wrv.wip_entity_id = wdj.wip_entity_id
         AND ola.line_id(+) = wrv.demand_source_line_id
         AND asm_ser.wip_entity_id(+) = wdj.wip_entity_id;
    -- AND    hsp_ser.assembly_serial_number(+) = asm_ser.fm_serial_number; -- added by noam yanai NOV-2014 CHG0033946
  
  BEGIN
    l_master_org_id := xxinv_utils_pkg.get_master_organization_id; --INC0200056
  
    retcode    := 0;
    l_batch_id := fnd_global.conc_request_id;
  
    -- get user details
    xxinv_trx_in_pkg.get_user_details(p_user_name       => p_user_name,
                                      p_user_id         => l_user_id,
                                      p_resp_id         => l_resp_id,
                                      p_resp_appl_id    => l_resp_appl_id,
                                      p_organization_id => l_organization_id,
                                      p_err_code        => l_err_code,
                                      p_err_message     => l_err_message);
  
    IF l_err_code = 1 THEN
      RAISE stop_process;
    END IF;
  
    -- err retry
  
    UPDATE xxinv_trx_wip_out t
       SET t.status_code      = 'NEW',
           error_message      = NULL,
           t.last_update_date = SYSDATE,
           t.batch_id         = l_batch_id,
           t.last_updated_by  = fnd_global.user_id
     WHERE t.status_code = 'ERROR'
       AND t.organization_id = l_organization_id;
  
    IF SQL%FOUND THEN
      l_flag := 1;
    END IF;
  
    COMMIT;
  
    ------- initialize ---------
    fnd_global.apps_initialize(l_user_id, l_resp_id, l_resp_appl_id);
    IF p_directory IS NULL THEN
      l_directory := nvl(p_directory,
                         fnd_profile.value('XXINV_TPL_TRX_OUT_DIRECTORY'));
    
    ELSE
      l_directory := p_directory;
    END IF;
    IF xxobjt_general_utils_pkg.am_i_in_production = 'N' THEN
    
      l_directory := REPLACE(l_directory, 'PROD', 'DEV');
    END IF;
  
    message('Output Directory=' || l_directory);
    ----------
    FOR i IN c_wip(l_master_org_id) LOOP
      --TRANSACTION_TEMP_ID, LOT_NUMBER, SERIAL_NUMBER
      BEGIN
        SELECT 1
          INTO l_tmp
          FROM xxinv_trx_wip_out
         WHERE transaction_temp_id = i.transaction_temp_id
           AND nvl(component_lot_number, '.') =
               nvl(i.component_lot_number, '.')
           AND nvl(component_serial_number, '.') =
               nvl(i.component_serial_number, '.');
        -- CHK UNIQUE
      
        -- dbms_output.put_line('FOUND');
      EXCEPTION
        WHEN no_data_found THEN
          --  dbms_output.put_line('NOT FOUND');
          BEGIN
          
            INSERT INTO xxinv_trx_wip_out
              (line_id,
               organization_id,
               interface_target,
               batch_id,
               status_code,
               error_message,
               creation_date,
               last_update_date,
               created_by,
               last_update_login,
               last_updated_by,
               file_id,
               source_code,
               job_id,
               job_number,
               sales_order_number,
               sales_order_line_number,
               schedule_ship_date,
               assembly_item_id,
               assembly_item_code,
               assembly_item_description,
               assembly_revision,
               assembly_serial_number,
               assembly_hasp_number, -- added by noam yanai NOV-2014 CHG0033946
               assembly_lot_number,
               assembly_qnty,
               assembly_uom_code,
               completion_to_subinventory,
               completion_to_locator_id,
               move_order_header_id,
               move_order_type,
               move_order_line_id,
               transaction_temp_id,
               component_item_id,
               component_item_code,
               component_revision,
               component_serial_number,
               component_lot_number,
               component_qnty,
               component_uom_code,
               component_from_subinventory,
               component_from_locator_id,
               orig_serial_number,
               orig_lot_number)
            VALUES
              (xxinv_transaction_seq.nextval, ---> LINE_ID
               l_organization_id, ---> ORGANIZATION_ID
               p_user_name, -- 'SH' ---> INTERFACE_TARGET
               l_batch_id, ---> BATCH_ID
               'NEW', ---> STATUS_CODE
               NULL, ---> ERROR_MESSAGE
               l_creation_date, ---> CREATION_DATE
               NULL, ---> LAST_UPDATE_DATE
               fnd_global.user_id, ---> CREATED_BY
               fnd_global.login_id, ---> LAST_UPDATE_LOGIN
               fnd_global.user_id, ---> LAST_UPDATED_BY
               NULL, ---> FILE_ID
               p_user_name, ---> SOURCE_CODE
               i.job_id, ---> JOB_ID
               i.job_number, ---> JOB_NUMBER
               i.sales_order_number, ---> SALES_ORDER_NUMBER
               i.sales_order_line_number, ---> SALES_ORDER_LINE_NUMBER
               i.schedule_ship_date, ---> SCHEDULE_SHIP_DATE
               i.assembly_item_id, ---> ASSEMBLY_ITEM_ID
               i.assembly_item_code, ---> ASSEMBLY_ITEM_CODE
               i.assembly_item_description, ---> ASSEMBLY_ITEM_DESCRIPTION
               i.assembly_revision, ---> ASSEMBLY_REVISION
               i.assembly_serail_number, ---> ASSEMBLY_SERAIL_NUMBER
               i.assembly_hasp_number, ---> ASSEMBLY_HASP_NUMBER    -- added by noam yanai NOV-2014 CHG0033946
               i.assembly_lot_number, ---> ASSEMBLY_LOT_NUMBER
               i.assembly_qnty, ---> ASSEMBLY_QNTY
               i.assembly_uom_code, ---> ASSEMBLY_UOM_CODE
               i.completion_to_subinventory, ---> COMPLETION_TO_SUBINVENTORY
               i.completion_to_locator_id, ---> COMPLETION_TO_LOCATOR_ID
               i.move_order_header_id, ---> MOVE_ORDER_HEADER_ID
               i.move_order_type, ---> MOVE_ORDER_TYPE
               i.move_order_line_id, ---> MOVE_ORDER_LINE_ID
               i.transaction_temp_id, ---> TRANSACTION_TEMP_ID
               i.component_item_id, ---> COMPONENT_ITEM_ID
               i.component_item_code, ---> COMPONENT_ITEM_CODE
               i.component_revision, ---> COMPONENT_REVISION ,
               i.component_serial_number, ---> COMPONENT_SERIAL_NUMBER
               i.component_lot_number, ---> COMPONENT_LOT_NUMBER
               i.component_qnty, ---> COMPONENT_QNTY
               i.component_uom_code, ---> COMPONENT_UOM_CODE ,
               i.component_from_subinventory, ---> COMPONENT_FROM_SUBINVENTORY
               i.component_from_locator_id, ---> COMPONENT_FROM_LOCATOR_ID
               NULL, ---> ORIG_SERIAL_NUMBER
               NULL); --->ORIG_LOT_NUMBER
          
            l_flag := 1;
          
          EXCEPTION
            WHEN dup_val_on_index THEN
              NULL;
            
          END;
      END;
    END LOOP;
  
    COMMIT;
  
    IF l_flag >= 1 THEN
    
      message('Start Create xml file....');
    
      xxobjt_xml_gen_pkg.create_xml_file(errbuf      => l_errbuf,
                                         retcode     => l_retcode,
                                         p_file_id   => l_file_id,
                                         p_file_code => p_file_code,
                                         p_directory => l_directory,
                                         p_param1    => l_batch_id);
      --
      message('l_retcode=' || l_retcode);
    
      IF l_retcode = 0 THEN
        -- update file_id
        UPDATE xxinv_trx_wip_out t
           SET t.file_id = l_file_id, t.status_code = 'FILE'
         WHERE t.batch_id = l_batch_id;
      
        COMMIT;
        errbuf := 'File id= ' || l_file_id || ' created successfully';
        --
        -- update status
      ELSE
      
        UPDATE xxinv_trx_wip_out t
           SET t.file_id     = NULL,
               t.status_code = 'ERROR',
               error_message = l_errbuf
         WHERE t.batch_id = l_batch_id;
      
        COMMIT;
        retcode := 2;
        errbuf  := 'File creation failed see, file log : file_id=' ||
                   l_file_id || ' ' || l_errbuf;
        message(errbuf);
      
      END IF;
    
    ELSE
    
      --retcode := 1;
      errbuf := 'No Records found';
      message(errbuf);
    
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      retcode := '2';
      errbuf  := SQLERRM || l_err_message;
    
  END populate_wip_file;

  -----------------------------------------------------------------
  -- generate_rma_report
  ----------------------------------------------------------------
  -- Purpose: CUST-751 - CR1043
  --          generate rma reports
  --          For PRINT_RMA=?Y?  submit report ?XX: SSYS RMA Report?
  --          mail report to fnd_profile.value('XXINV_TPL_REPORT_MAIL') fnd_profile.value('XXINV_TPL_REPORT_CC_MAIL')
  -- subject mail  p_prefix_name || '_' ||i.delivery_id ||'.pdf'
  --------------------------------------------------------------------------------------------------------------------------------
  -- Version  Date        Performer       Comments
  ----------  ----------  --------------  ----------------------------------------------------------------------------------------
  --     1.0  24.9.13     yuval tal         initial build
  --     2.0  25-04-2018  Roman.W.          CHG0042777 - XXINV_TRX_OUT_PKG package needs modification for Missing RMA sheet issue
  --                                        Added logic which allows sending a report not only by delivery but also from order level.
  --------------------------------------------------------------------------------------------------------------------------------
  PROCEDURE generate_rma_report(errbuf            OUT VARCHAR2,
                                retcode           OUT VARCHAR2,
                                p_prefix_name     VARCHAR2,
                                p_organization_id NUMBER,
                                p_line_id         NUMBER) IS
    ------------------------------------
    --       Local Definitions
    ------------------------------------
    CURSOR c_rma IS
      SELECT xxhr_util_pkg.get_person_email(xxhr_util_pkg.get_user_person_id(oh.created_by)) creator_mail,
             t.order_header_id,
             t.line_id,
             t.delivery_id,
             t.order_number,
             t.rma_err_message
        FROM xxinv_trx_ship_out t, oe_order_headers_all oh
       WHERE t.order_header_id = oh.header_id
         AND ((t.print_rma = 'Y' AND t.rma_status IN ('E', 'N') AND
             t.organization_id = p_organization_id) OR
             (t.print_rma = 'Y' AND t.line_id = p_line_id));
  
    l_result     BOOLEAN;
    l_request_id NUMBER;
    l_count      NUMBER := 0;
  
    ---- out variables for fnd_concurrent.wait_for_request-----
    x_phase       VARCHAR2(100);
    x_status      VARCHAR2(100);
    x_dev_phase   VARCHAR2(100);
    x_dev_status  VARCHAR2(100);
    x_return_bool BOOLEAN;
    x_message     VARCHAR2(100);
    --
    l_from_mail VARCHAR2(50);
    ------------------------------------
    --       Code Section
    ------------------------------------
  BEGIN
  
    l_from_mail := get_from_mail_address;
    retcode     := 0;
  
    FOR i IN c_rma LOOP
      -- chec doc already printed
      UPDATE xxinv_trx_ship_out t
         SET t.rma_status      = 'S',
             t.rma_err_message = 'Report aleady sent in previous line'
       WHERE t.line_id = i.line_id
         AND EXISTS (SELECT 1
                FROM xxinv_trx_ship_out o
               WHERE o.delivery_id = t.delivery_id
                 AND o.order_header_id = t.order_header_id -- added by R.W 25-04-2018 CHG0042777
                 AND o.print_rma = 'Y'
                 AND o.rma_status = 'S');
    
      IF SQL%ROWCOUNT > 0 THEN
        COMMIT;
        CONTINUE;
      END IF;
    
      l_count := l_count + 1;
      message('Submit ram report for  : delivery_id=' || i.delivery_id || ' ' ||
              'order_number=' || i.order_number);
    
      -- set mail distribution
    
      --
      --  select xxhr_util_pkg.get_person_email(get xxhr_util_pkg.get_user_person_id)
    
      l_result := fnd_request.add_delivery_option(TYPE         => 'E', -- this one to speciy the delivery option as Email
                                                  p_argument1  => p_prefix_name || '_' ||
                                                                  i.delivery_id, -- subject for the mail
                                                  p_argument2  => l_from_mail, -- from address
                                                  p_argument3  => fnd_profile.value('XXINV_TPL_RMA_REPORT_MAIL') || CASE
                                                                    WHEN i.creator_mail IS NOT NULL THEN
                                                                     ', ' || i.creator_mail
                                                                    ELSE
                                                                     NULL
                                                                  END, -- to address
                                                  p_argument4  => fnd_profile.value('XXINV_TPL_RMA_CC_REPORT_MAIL'), -- cc address to be specified here.
                                                  nls_language => '');
    
      --Create a Layout when running from the Tools Option
      l_result := fnd_request.add_layout(template_appl_name => 'XXOBJT',
                                         template_code      => 'XXOM_SSYS_RMA',
                                         template_language  => 'en',
                                         template_territory => 'IL',
                                         output_format      => 'PDF');
    
      l_result := fnd_request.set_print_options(printer     => NULL,
                                                copies      => 0,
                                                save_output => TRUE);
    
      l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                                 program     => 'XXOM_SSYS_RMA',
                                                 argument1   => i.delivery_id,
                                                 argument2   => i.order_number);
    
      COMMIT;
    
      IF l_request_id > 0 THEN
      
        --wait for program
        x_return_bool := fnd_concurrent.wait_for_request(l_request_id,
                                                         5,
                                                         1200,
                                                         x_phase,
                                                         x_status,
                                                         x_dev_phase,
                                                         x_dev_status,
                                                         x_message);
      
        IF upper(x_dev_phase) = 'COMPLETE' AND
           upper(x_dev_status) IN ('ERROR', 'WARNING') THEN
        
          i.rma_err_message := 'Concurrent ''XX: SSYS RMA Report'' completed in ' ||
                               upper(x_dev_status);
          message(i.rma_err_message);
        
          UPDATE xxinv_trx_ship_out t
             SET t.rma_request_id   = l_request_id,
                 t.rma_status       = 'E',
                 t.rma_err_message  = i.rma_err_message,
                 t.last_update_date = SYSDATE,
                 t.last_updated_by  = fnd_global.user_id
           WHERE t.line_id = i.line_id;
        
          retcode := '1';
          CONTINUE;
        
        ELSIF upper(x_dev_phase) = 'COMPLETE' AND
              upper(x_dev_status) = 'NORMAL' THEN
          -- report generated
          message('File created');
        
          UPDATE xxinv_trx_ship_out t
             SET t.rma_request_id   = l_request_id,
                 t.rma_status       = 'S',
                 t.error_message    = NULL,
                 t.last_update_date = SYSDATE,
                 t.last_updated_by  = fnd_global.user_id
           WHERE t.line_id = i.line_id;
        
          COMMIT;
        
        ELSE
          -- error
          i.rma_err_message := 'Concurrent ''XX: SSYS RMA Report'' failed ';
          retcode           := '1';
          message(i.rma_err_message);
          -- report generated
          UPDATE xxinv_trx_ship_out t
             SET t.rma_request_id   = l_request_id,
                 t.rma_status       = 'E',
                 t.rma_err_message  = i.rma_err_message,
                 t.last_update_date = SYSDATE,
                 t.last_updated_by  = fnd_global.user_id
           WHERE t.line_id = i.line_id;
        
          COMMIT;
          CONTINUE;
        END IF;
      
      ELSE
        -- submit program failed
        message('failed TO submit XX: SSYS RMA Report ' ||
                fnd_message.get());
      
        UPDATE xxinv_trx_ship_out t
           SET t.rma_request_id   = l_request_id,
               t.rma_status       = 'E',
               t.rma_err_message  = 'failed TO submit XX: SSYS RMA Report ' ||
                                    fnd_message.get(),
               t.last_update_date = SYSDATE,
               t.last_updated_by  = fnd_global.user_id
         WHERE t.line_id = i.line_id;
      
        COMMIT;
        retcode := '1';
      END IF;
    
      COMMIT;
      message('=========');
    END LOOP;
    message(l_count || ' records found');
  
  EXCEPTION
    WHEN OTHERS THEN
    
      retcode := '2';
      errbuf  := SQLERRM;
    
  END generate_rma_report;

  -----------------------------------------------------------------
  -- get_service_parameters
  ----------------------------------------------------------------
  -- Purpose: CHG0032515 (Expeditors interfaces) and CHG0032497 (SFDC project)
  --          returns the service request number, machine serial number and engineer
  --          When this data comes from Oracle service modules
  -----------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------------------
  --     1.0  24.8.14   noam yanai      initial build
  -----------------------------------------------------------------
  PROCEDURE get_service_parameters(errbuf                   OUT VARCHAR2,
                                   retcode                  OUT VARCHAR2,
                                   p_service_request_number OUT VARCHAR2,
                                   p_machine_serial_number  OUT VARCHAR2,
                                   p_field_service_engineer OUT VARCHAR2,
                                   p_source_line_id         IN NUMBER) IS
  
    l_service_request_number VARCHAR2(64);
    l_machine_serial_number  VARCHAR2(50);
    l_field_service_engineer VARCHAR2(500);
  
  BEGIN
  
    SELECT ciab.incident_number, ccp.current_serial_number, rs.source_name
      INTO l_service_request_number,
           l_machine_serial_number,
           l_field_service_engineer
      FROM cs_incidents_all_b        ciab,
           cs_customer_products_all  ccp,
           csp_req_line_details_v    crldv,
           csp_requirement_headers_v crhv,
           jtf_rs_resource_extns     rs
     WHERE crldv.source_id(+) = p_source_line_id
       AND crhv.requirement_header_id(+) = crldv.requirement_header_id
       AND ciab.incident_id(+) = crhv.incident_id
       AND ccp.customer_product_id(+) = ciab.customer_product_id
       AND rs.resource_id(+) = crhv.resource_id
       AND rownum = 1;
  
    p_service_request_number := l_service_request_number;
    p_machine_serial_number  := l_machine_serial_number;
    p_field_service_engineer := l_field_service_engineer;
  
    retcode := '0';
    errbuf  := '';
  
  EXCEPTION
  
    WHEN no_data_found THEN
      retcode                  := '1';
      errbuf                   := 'No service data found for wdd.source_line_id: ' ||
                                  p_source_line_id;
      p_service_request_number := NULL;
      p_machine_serial_number  := NULL;
      p_field_service_engineer := NULL;
    
    WHEN OTHERS THEN
      retcode                  := '2';
      errbuf                   := SQLERRM;
      p_service_request_number := NULL;
      p_machine_serial_number  := NULL;
      p_field_service_engineer := NULL;
    
  END get_service_parameters;

  -----------------------------------------------------------------
  -- is_rcv_trx_processed
  ----------------------------------------------------------------
  -- Purpose: CHG0032515 (Expeditors interfaces)
  --          check whether transaction  processed (status  S success  or C closed )
  --
  -----------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------------------
  --     1.0  24.8.14   noam yanai      initial build
  -----------------------------------------------------------------
  FUNCTION is_rcv_trx_processed(p_source_code        VARCHAR2,
                                p_doc_type           VARCHAR,
                                p_order_header_id    NUMBER,
                                p_shipment_header_id NUMBER) RETURN VARCHAR2 IS
  
    l_is_rcv_trx_processed VARCHAR2(1);
  BEGIN
  
    IF p_doc_type = 'MO' THEN
      RETURN 'Y';
    ELSIF p_doc_type = 'INTERNAL' THEN
      SELECT 'N'
        INTO l_is_rcv_trx_processed
        FROM xxinv_trx_rcv_in ri
       WHERE ri.source_code = p_source_code
         AND ri.doc_type = p_doc_type
         AND ri.shipment_header_id = p_shipment_header_id
         AND ri.status NOT IN ('S', 'C')
         AND rownum = 1;
    ELSE
    
      SELECT 'N'
        INTO l_is_rcv_trx_processed
        FROM xxinv_trx_rcv_in ri
       WHERE ri.source_code = p_source_code
         AND ri.doc_type = p_doc_type
         AND ri.order_header_id = p_order_header_id
         AND ri.status NOT IN ('S', 'C')
         AND rownum = 1;
    
    END IF;
  
    RETURN nvl(l_is_rcv_trx_processed, 'Y');
  
  EXCEPTION
    WHEN no_data_found THEN
      RETURN 'Y';
  END;

  -----------------------------------------------------------------
  -- Split_serial_in_rcv_file
  ----------------------------------------------------------------
  -- Purpose: CHG0033946 (Expeditors interfaces)
  --          When RMA or PO is entered for serialized item, split the rcv_out into one line per serial
  --          This is per expeditor's request as their system does not support receipt of many serials to one line.
  --          For example, if RMA is for quantity 3 than insert 3 lines with quantity 1 and delete original line.
  -----------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------------------
  --     1.0  18.12.14   noam yanai      initial build
  --     1.1  07/06/17  yuval tal        INC0094855 avoid splition record already split
  --                                     update record status which was split to SPLIT
  -----------------------------------------------------------------
  PROCEDURE split_serial_in_rcv_file(errbuf        OUT VARCHAR2,
                                     retcode       OUT VARCHAR2,
                                     p_source_code IN VARCHAR2,
                                     p_batch_id    IN NUMBER) IS
  
    CURSOR c_rcv_out IS
      SELECT ro.*
        FROM xxinv_trx_rcv_out ro, mtl_system_items_b sib
       WHERE ro.status_code = 'NEW'
         AND ro.doc_type IN ('OE', 'PO')
         AND ro.batch_id = p_batch_id
         AND ro.source_code = p_source_code
         AND ro.qty_ordered > 1
         AND sib.organization_id = ro.organization_id
         AND sib.inventory_item_id = ro.item_id
         AND sib.serial_number_control_code > 1
         AND status_code != 'SPLIT'; -- INC0094855
  
  BEGIN
  
    errbuf  := '0';
    retcode := '';
    message('split_serial_in_rcv_file');
    FOR i IN c_rcv_out LOOP
      BEGIN
        SAVEPOINT insert_fail;
      
        message('split line_id' || i.line_id || ' order_number=' ||
                i.order_number);
      
        FOR j IN 1 .. i.qty_ordered LOOP
        
          INSERT INTO xxinv_trx_rcv_out
            (line_id,
             organization_id,
             interface_target,
             batch_id,
             status_code,
             creation_date,
             last_update_date,
             created_by,
             last_update_login,
             last_updated_by,
             file_id,
             doc_type,
             customer_name,
             supplier_name,
             shipment_header_id,
             shipment_number,
             shipment_line_id,
             shipment_line_number,
             order_header_id,
             order_number,
             order_line_id,
             order_line_number,
             po_line_location_id,
             service_request_reference,
             expected_receipt_date,
             from_organization_id,
             item_id,
             item_code,
             supplier_item_code,
             qty_ordered,
             qty_uom_code,
             lot_number,
             lot_expiration_date,
             lot_status,
             serial_number,
             revision,
             subinventory,
             locator_id,
             from_subinventory,
             from_locator_id,
             note_to_receiver,
             source_code,
             split_from_line_id -- INC0094855
             )
          VALUES
            (xxinv_transaction_seq.nextval, ---> LINE_ID
             i.organization_id, ---> ORGANIZATION_ID
             i.source_code, -- 'SH' ---> INTERFACE_TARGET
             i.batch_id, ---> BATCH_ID
             i.status_code, ---> STATUS_CODE
             i.creation_date, ---> CREATION_DATE
             i.creation_date, ---> LAST_UPDATE_DATE
             i.created_by, ---> CREATED_BY
             i.last_update_login, ---> LAST_UPDATE_LOGIN
             i.last_updated_by, ---> LAST_UPDATED_BY
             i.file_id, ---> FILE_ID
             i.doc_type, ---> DOC_TYPE
             i.customer_name, ---> CUSTOMER_NAME
             i.supplier_name, ---> SUPPLIER_NAME
             i.shipment_header_id, ---> SHIPMENT_HEADER_ID
             i.shipment_number, ---> SHIPMENT_NUMBER
             i.shipment_line_id, ---> SHIPMENT_LINE_ID
             i.shipment_line_number, ---> SHIPMENT_LINE_NUMBER
             i.order_header_id, ---> ORDER_HEADER_ID
             i.order_number, ---> ORDER_NUMBER
             i.order_line_id, ---> ORDER_LINE_ID
             i.order_line_number, ---> ORDER_LINE_NUMBER
             i.po_line_location_id, ---> PO_LINE_LOCATION_ID
             i.service_request_reference, ---> SERVICE_REQUEST_REFERENCE
             i.expected_receipt_date, ---> EXPECTED_RECEIPT_DATE
             i.from_organization_id, ---> FROM_ORGANIZATION_ID
             i.item_id, ---> ITEM_ID
             i.item_code, ---> ITEM_CODE
             i.supplier_item_code, ---> SUPPLIER_ITEM_CODE
             1, ---> QTY_ORDERED
             i.qty_uom_code, ---> QTY_UOM_CODE
             i.lot_number, ---> LOT_NUMBER
             i.lot_expiration_date, ---> LOT_EXPIRATION_DATE
             i.lot_status, ---> LOT_STATUS
             i.serial_number, ---> SERIAL_NUMBER
             i.revision, ---> REVISION
             i.subinventory, ---> SUBINVENTORY
             i.locator_id, ---> LOCATOR_ID
             i.from_subinventory, ---> FROM_SUBINVENTORY
             i.from_locator_id, ---> FROM_LOCATOR_ID
             i.note_to_receiver, ---> NOTE_TO_RECEIVER
             i.source_code, --->  SOURCE_CODE
             i.line_id); --INC0094855  split_from_line_id
        END LOOP;
      
        /* DELETE FROM xxinv_trx_rcv_out ro
        WHERE  ro.line_id = i.line_id;INC0094855
        */
        UPDATE xxinv_trx_rcv_out ro
           SET status_code = 'SPLIT'
         WHERE ro.line_id = i.line_id; --INC0094855
      
      EXCEPTION
        WHEN OTHERS THEN
          retcode := '1';
          errbuf  := errbuf || ' - ' || SQLERRM;
          ROLLBACK TO insert_fail;
      END;
    
    END LOOP;
  
    COMMIT;
  
  END split_serial_in_rcv_file;

  -----------------------------------------------------------------
  -- Resend_file
  ----------------------------------------------------------------
  -- Purpose: CHG0033946 (Expeditors interfaces)
  --          Allows to resend XML file for lines in that were already sent.
  --          Changes the status of lines in rcv_out/ship_out/wip_out table
  --          from 'FILE' to ERROR' ensuring that next time the relevant
  --          concurrent run is will create an XML file for them (all the
  --          populte_xxx_file procedures resend ERROR lines)
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------------------
  --     1.0  30.12.14   noam yanai      initial build
  -----------------------------------------------------------------
  PROCEDURE resend_file(errbuf    OUT VARCHAR2,
                        retcode   OUT VARCHAR2,
                        p_type    IN VARCHAR2,
                        p_file_id IN NUMBER,
                        p_line_id IN NUMBER) IS
  
    l_no_of_lines NUMBER;
    l_line_txt    VARCHAR2(100);
  
  BEGIN
  
    retcode       := '0';
    errbuf        := '';
    l_no_of_lines := 0;
  
    IF p_file_id IS NULL THEN
      retcode := '1';
      errbuf  := 'No File id provided. File id is required. ';
    ELSE
    
      CASE nvl(p_type, 'NONE')
        WHEN 'RCV' THEN
          BEGIN
            UPDATE xxinv_trx_rcv_out xtro
               SET xtro.last_update_date = SYSDATE,
                   xtro.last_updated_by  = fnd_global.user_id,
                   xtro.status_code      = 'ERROR',
                   xtro.error_message    = 'Status changed to ERROR by Function : xxinv_trx_out_pkg.resend_file'
             WHERE xtro.file_id = p_file_id
               AND xtro.line_id = nvl(p_line_id, xtro.line_id)
               AND xtro.status_code = 'FILE';
          
            l_no_of_lines := SQL%ROWCOUNT;
          EXCEPTION
            WHEN OTHERS THEN
              retcode := '1';
              errbuf  := 'Update file status failed: ' || SQLERRM;
          END;
        WHEN 'SHIP' THEN
          BEGIN
            UPDATE xxinv_trx_ship_out xtso
               SET xtso.last_update_date = SYSDATE,
                   xtso.last_updated_by  = fnd_global.user_id,
                   xtso.status_code      = 'ERROR',
                   xtso.error_message    = 'Status changed to ERROR by Function : xxinv_trx_out_pkg.resend_file'
             WHERE xtso.file_id = p_file_id
               AND xtso.line_id = nvl(p_line_id, xtso.line_id)
               AND xtso.status_code = 'FILE';
          
            l_no_of_lines := SQL%ROWCOUNT;
          
          EXCEPTION
            WHEN OTHERS THEN
              retcode := '1';
              errbuf  := 'Update file status failed: ' || SQLERRM;
          END;
        WHEN 'WIP' THEN
          BEGIN
            UPDATE xxinv_trx_wip_out xtwo
               SET xtwo.last_update_date = SYSDATE,
                   xtwo.last_updated_by  = fnd_global.user_id,
                   xtwo.status_code      = 'ERROR',
                   xtwo.error_message    = 'Status changed to ERROR by Function : xxinv_trx_out_pkg.resend_file'
             WHERE xtwo.file_id = p_file_id
               AND xtwo.line_id = nvl(p_line_id, xtwo.line_id)
               AND xtwo.status_code = 'FILE';
          
            l_no_of_lines := SQL%ROWCOUNT;
          EXCEPTION
            WHEN OTHERS THEN
              retcode := '1';
              errbuf  := 'Update file status failed: ' || SQLERRM;
          END;
        WHEN 'NONE' THEN
          retcode := '1';
          errbuf  := 'No file type provided. Should be RCV or SHIP or WIP';
          RETURN;
        ELSE
          retcode := '1';
          errbuf  := 'Wrong file type provided: ' || p_type ||
                     '. Should be RCV or SHIP or WIP';
          RETURN;
      END CASE;
      COMMIT;
      IF nvl(l_no_of_lines, 0) = 0 THEN
      
        IF p_line_id IS NULL THEN
          l_line_txt := 'All';
        ELSE
          l_line_txt := to_char(p_line_id);
        END IF;
      
        retcode := '1';
        errbuf  := 'No ' || p_type || ' lines were updated for file_id: ' ||
                   p_file_id || ', line_id :' || l_line_txt;
      ELSE
        IF p_line_id IS NULL THEN
          l_line_txt := ' lines were updated.';
        ELSE
          l_line_txt := ' line was updated.';
        END IF;
      
        retcode := '0';
        errbuf  := 'Update succeeded. ' || l_no_of_lines || ' ' || p_type ||
                   l_line_txt;
      END IF;
    
    END IF; -- if file_id = NULL
  EXCEPTION
    WHEN OTHERS THEN
      retcode := '1';
      errbuf  := 'Fatal Error :  ' || SQLERRM;
  END;

  --------------------------------------------------------------------
  -- Ver    When         Who        Descr
  -- -----  -----------  ---------  ----------------------------------
  -- 1.0    17/02/2021   Roman W.   CHG0049272
  --------------------------------------------------------------------
  procedure get_loads(p_po_line_location_id    IN NUMBER,
                      p_doc_type               IN VARCHAR2,
                      p_qty                    IN NUMBER,
                      p_xxinv_trx_rcv_loads_in OUT xxinv_trx_rcv_loads_in_tab,
                      p_error_code             OUT VARCHAR2,
                      p_error_desc             OUT VARCHAR2) is
  
    cursor c_cur(c_po_line_location_id NUMBER) is
      select xtrli.load_line_id,
             xtrli.po_line_location_id,
             xtrli.doc_type,
             xtrli.load_id,
             xtrli.load_qty
        from xxinv_trx_rcv_loads_in xtrli
       where xtrli.po_line_location_id = c_po_line_location_id
         and not exists
       (select 'X'
                from xxinv_trx_rcv_loads_out xtrlo
               where xtrlo.load_line_id = xtrli.load_line_id)
       order by xtrli.load_qty desc;
  
    type l_loads_set_type is table of c_cur%ROWTYPE;
    l_loads_set   l_loads_set_type;
    l_loads_set2  l_loads_set_type;
    l_row_counter NUMBER;
    l_total_qty   NUMBER := 0;
    ind_i         number := 0;
    ind_j         number := 0;
  begin
    p_error_code             := '0';
    p_error_desc             := null;
    p_xxinv_trx_rcv_loads_in := xxinv_trx_rcv_loads_in_tab();
  
    if 'INSPECT' = p_doc_type then
      select xtrli.load_line_id,
             xtrli.po_line_location_id,
             xtrli.doc_type,
             xtrli.load_id,
             xtrli.load_qty
        BULK COLLECT
        INTO l_loads_set
        from xxinv_trx_rcv_loads_in xtrli
       where xtrli.po_line_location_id = p_po_line_location_id
         and not exists
       (select 'X'
                from xxinv_trx_rcv_loads_out xtrlo
               where xtrlo.load_line_id = xtrli.load_line_id)
       order by xtrli.load_qty desc;
    
      if l_loads_set.last > 0 then
        l_row_counter := l_loads_set.last;
        for i in 1 .. l_row_counter loop
          for j in i .. l_row_counter loop
            if l_total_qty + l_loads_set(j).load_qty = p_qty then
              p_xxinv_trx_rcv_loads_in.EXTEND();
              p_xxinv_trx_rcv_loads_in(p_xxinv_trx_rcv_loads_in.count).po_line_location_id := l_loads_set(j)
                                                                                              .po_line_location_id;
              p_xxinv_trx_rcv_loads_in(p_xxinv_trx_rcv_loads_in.count).load_line_id := l_loads_set(j)
                                                                                       .load_line_id;
              p_xxinv_trx_rcv_loads_in(p_xxinv_trx_rcv_loads_in.count).po_line_location_id := l_loads_set(j)
                                                                                              .po_line_location_id;
              p_xxinv_trx_rcv_loads_in(p_xxinv_trx_rcv_loads_in.count).doc_type := l_loads_set(j)
                                                                                   .doc_type;
              p_xxinv_trx_rcv_loads_in(p_xxinv_trx_rcv_loads_in.count).load_id := l_loads_set(j)
                                                                                  .load_id;
              p_xxinv_trx_rcv_loads_in(p_xxinv_trx_rcv_loads_in.count).load_qty := l_loads_set(j)
                                                                                   .load_qty;
              return;
            elsif l_total_qty + l_loads_set(j).load_qty > p_qty then
              continue;
            elsif l_total_qty + l_loads_set(j).load_qty < p_qty then
              p_xxinv_trx_rcv_loads_in.EXTEND();
              p_xxinv_trx_rcv_loads_in(p_xxinv_trx_rcv_loads_in.count).po_line_location_id := l_loads_set(j)
                                                                                              .po_line_location_id;
              p_xxinv_trx_rcv_loads_in(p_xxinv_trx_rcv_loads_in.count).load_line_id := l_loads_set(j)
                                                                                       .load_line_id;
              p_xxinv_trx_rcv_loads_in(p_xxinv_trx_rcv_loads_in.count).po_line_location_id := l_loads_set(j)
                                                                                              .po_line_location_id;
              p_xxinv_trx_rcv_loads_in(p_xxinv_trx_rcv_loads_in.count).doc_type := l_loads_set(j)
                                                                                   .doc_type;
              p_xxinv_trx_rcv_loads_in(p_xxinv_trx_rcv_loads_in.count).load_id := l_loads_set(j)
                                                                                  .load_id;
              p_xxinv_trx_rcv_loads_in(p_xxinv_trx_rcv_loads_in.count).load_qty := l_loads_set(j)
                                                                                   .load_qty;
              l_total_qty := l_total_qty + l_loads_set(j).load_qty;
            end if;
          end loop;
        end loop;
        p_error_code := '2';
        p_error_desc := 'ERROR Not found apropriate loads quantity';
      
      end if;
    end if;
  end get_loads;
END xxinv_trx_out_pkg;
/
