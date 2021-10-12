CREATE OR REPLACE PACKAGE BODY "XXINV_TRX_IN_PKG" IS
  ---------------------------------------------------------------------------
  -- $Header: XXINV_TRX_IN_PKG   $
  ---------------------------------------------------------------------------
  -- Package: XXINV_TRX_IN_PKG
  -- Created:
  -- Author:  Vitaly
  ---------------------------------------------------------------------------
  -- Purpose: CUST-751 - Process Incoming transactions (CR1044)
  ---------------------------------------------------------------------------
  -- Ver   Date       Performer        Comments
  -- ---   ----       --------         --------------------------------------
  -- 1.0   24.9.13     yuval tal        initial build
  -- 1.1   27.3.14     yuval tal        CHG0031650 :
  --                                    Add  clean_rcv_interface
  --                                    Modify: handle_rcv_rma_trx, handle_rcv_po_trx, handle_rcv_internal_trx
  -- 1.2   2.7.14      noam yanai       CHG0032573 : Fix Bug in Simon Hegele interface that ship lines are sent twice to the TPL
  --                                    modify proc : handle_rcv_mo_trx,handle_pick_trx
  -- 1.3   22.7.14     noam yanai       CHG0032515: Interfaces with Expeditors
  --                                    Add procedures:
  --                                    - is_job_components_picked: checks if all components of a job were picked and issued
  --                                    - is_full_qty_issued: checks if picking task for wip was fully picked
  --                                    - update_assembly_serial: updates the assembly serial to match the machine component that was actually picked
  --                                    - handle_wip_issue_trx: processes the new lines in xxinv_trx_wip_in lines and does the components pick/issue transactions
  --                                    - handle_wip_completion_trx: is called by handle_wip_issue_trx when all components were issued.
  --                                    populates the xxinv_trx_material_in table so that the material transactions concurrent will do the transaction.
  --                                    Modify Procedures:
  --                                    - handle_internal_material_trx: add support for transaction type 44 (wip completion)
  --                                    - handle_rcv_po_trx : insert order headers received into table xxinv_trx_rcv_in_ord_headers to allow orders be sent again
  --                                    - handle_rcv_rma_trx : insert order headers received into table xxinv_trx_rcv_in_ord_headers to allow orders be sent again
  --                                    - handle_rcv_mo_trx : insert order headers received into table xxinv_trx_rcv_in_ord_headers to allow orders be sent again
  -- 1.4   23/11/14    noam yanai       CHG0033946 - in check_rma_serial_valid add filter to the cursor to comply with ATO project
  --                                              - add support for inter-organization transfers in handle_rcv_internal - calculate src_doc_code and rcpt_src_code according to internal type (Inter-org/IR)
  --                                              - change query in function is_job_components_picked to consider only supply type 1 (push)
  --                                              - add procedure get_wip_completion_sub_loc that returns the subinvetory and locator where the wip completion has to happen
  --                                              - in handle_internal_material_trx - don't include in cursor account alias receipt for serials that also have account alias issue (receipt fails if processed first)
  -- 1.5   11/05/2015  Dalit A. Raviv   CHG0034230 procedure  print_commercial_invoice
  --                                    All the versions had unified into one: The XX SSUS: Commercial Invoice PDF Output
  -- 1.6   28/04/2015  yuval tal        CHG0033375 - update_rcv_status modify remove locator_id - required check
  -- 1.7   10/Sep/2015 Dalit A. RAviv   CHG0035915 - Packing interface to support delivery packing
  --                                    add proc/func - print_log, print_out, get_lpn_id, create_lpn, pack_lpn_and_delivery
  --                                                   split_delivery_line, get_lpn_delivery_detail, update_lpn_dff_info,
  --                                                   is_delivery_packed, update_delivery_dff, get_db_qty
  --                                      add logic for TPL that use LPN at pack - proc - handle_pach_trx
  -- 1.8  29.11.15   yuval tal           CHG0037096 - handle_wip_completion_trx,move_stock :  and item id to mtl_lot_number table join
  -- 1.9 3.7.16      yuval tal           INC0067224 - modify handle_pack_trx, Interface bug. The line in the delivery wasn't split to lpns lines
  -- 2.0  8-Sep-2016 Samir Todankar      INC0074535 - Oracle fail to process the transaction from 2200 (stock) to 2201 (scrap)
  --                                      handle_internal_material_trx - Procedure Modified
  --                                      Organization_id added as a condition in the mtl_serial_numbers Table Select Statement
  --  2.1 28.05.17    Yuval tal          CHG0040863 - modify HANDLE_SHIP_CONFIRM_TRX  : TPL Interface- Add freight cost API on Ship Confirm
  --  2.2 27.07.17    Yuval tal          CHG0041184  - modify handle_ship_confirm_trx
  --  2.3 1.8.17      yuval tal          INC0098783 - modify is delivery_packed
  --  2.4 3.8.17      yuval tal          INC0099029 - modify handle_pack / get_db_qty TPL Interface - Upper Serial Numbers/Lot  on Pack In Message
  --  2.5 14.9.17     yuval tal          CHG0041519 - modify handle_pack/ handle_shipconfirm
  --  2.6 25/10/2017  Diptasurjya/Dovik  INC0105240 - Add released_status = 'Y' check in get_db_qty procedure to consider staged delivery lines only
  --  2.7 10/24/2017  Diptasurjya        CHG0040327 - Make changes to avoid too many rows error when delivery detail has been split due to
  --                                     different revision / locator
  --  2.8 26.10.17      piyali bhowmick     CHG0041294 - modify handle_ship_confirm_trx ,handle_pack_trx,handle_pick_trx
  --                                     add proc /func - is_delivery_exists,create_delivery,assign_delivery_detail,get_delivery_id
  --  2.9 01.12.2017    Bellona Banerjee    CHG0041294 - modify handle_pick_trx to create reservation and allocation
  --                                     add proc create_allocation to create allocation for items.
  --  3.0 27-02-2018    Roman.W/Dovik      CHG0042242 : assighn and un-assighn intangible item
  --                                           added procedur : 1)set_item_ship_set_to_null
  --                                                            2)combine_delivery_by_ship_set
  --                                                            3)combine_delivery_by_order
  --                                                            4)ship_confirm_delivery_check
  --                                           to procedure added profile "XX_APPEND_INTANGIBLE_DELIVERIES" condition if "Y" then
  --                                           called procedure "ship_confirm_delivery_check"
  --
  --  3.1 29.03.18      bellona banerjee    CHG0042358  - Modification related to Packing List Report based on TPL user profile
  --  3.2 24.04.18      Bellona Banerjee    CHG0042788 - Modify handle_pick_trx for fetching correct line_id for split lines
  --  3.3 29-03-2018    Roman W.            l_err_message   VARCHAR2(3000) -> VARCHAR2(4000)
  --                                     l_msg_details   VARCHAR2(3000) -> VARCHAR2(4000)
  --                                     l_msg_summary   VARCHAR2(3000) -> VARCHAR2(4000)
  --  3.4 28-05-2018    Roman W             CHG0042242 : assighn and un-assighn intangible item
  --                                                       Added procedure : update_log_status
  --                                                                         insert_to_log
  --  3.5  11/06/2018   Roman W.            CHG0043197 : TPL Interface ship confirm -  eliminate ship confirm errors
  --                                                    1) check status of delivery before reissign.
  --  3.6  15/06/18     Bellona(TCS)         CHG0042444 - Pass new parameter(quantity) to get_db_qty procedure
  --                                     and make changes to avoid too many rows error when delivery detail has been split.
  --  3.7  17/07/18     Bellona(TCS)         CHG0043509 - XX INV TPL Interface Pick transaction - Delivery Detail ID Mandatory
  --                                               Added missing exception handling section wrt delivery_id fetch.
  --  3.8  24/07/18     Bellona(TCS)         INC0126962 : TPL Pick - Status changed to Success, while nothing processed
  --                                     Adding log message to capture error checkpoints.
  --  3.9  09/11/2018   Roman W.          CHG0044170 - TPL Interfaces- LPN implementation in APJ
  --  4.0  13/11/2018   Roman W.          CHG0044170 - TPL Interfaces- LPN implementation in APJ
  --                                       to xxinv_trx_pack_in added fields
  --                                              commercial_status     VARCHAR2(1)
  --                                              commercial_request_id NUMBER,
  --                                              commercial_message    VARCHAR2(500),
  --                                              packlist_status       VARCHAR2(1),
  --                                              packlist_request_id   NUMBER,
  --                                              packlist_message      VARCHAR2(500)
  --  4.1  13/11/2018   Roman W.          CHG0044170 - TPL Interfaces- LPN implementation in APJ
  --                                           in pack update table by delivery_id
  --  4.2  19/04/19     Sowjanya K.          CHG0045366 - Restricting the validation of RMA serial numbers (IB tracible)  only for a specific
  --                       list of items like machines/WJ
  --  4.3  05/09/19     Bellona(TCS)        CHG0046435 - TPL Handle Pack - COC document by Email
  --  4.4  27/10/19     YUVAL TAL           INC0172947 - modify handle_pack_trx - logic of commercial request_id  update
  --  4.5  23/10/19     Diptasurjya         CHG0046025 - Handle doc email sending
  --  4.6  18/11/19     Bellona.B           CHG0046731 - validate whether PO line is cancelled or not.
  --  4.7  31/12/19     Bellona(TCS)        CHG0046955 - TPL Interfaces - validation on Pick IN messages
  --  5.0  09/02/2021   Roman W.            CHG0049272 - TPL Add Inspection to PO receiving
  --                                                            procedure handle_rcv_po_trx
  --  5.1  6.7.21       yuval tal           INC0236079 - modify handle_pick_trx add catch exception in loop
  -------------------------------------------------------------------------------------------------------------------------------------------

  stop_process EXCEPTION;

  g_sleep_mod_sec NUMBER := 30;
  g_sleep_mod     NUMBER := 500;
  g_sleep         NUMBER;
  c_source_code_oe CONSTANT VARCHAR2(10) := 'OE';

  c_inspect CONSTANT VARCHAR2(120) := 'INSPECT'; -- CHG0049272
  --g_init          VARCHAR2(10) := NULL;

  ---> Igorr  - Start 15/10/2013
  CURSOR c_rcv_header(c_doc_type    VARCHAR2,
	          c_source_code VARCHAR2) IS
    SELECT DISTINCT t.order_header_id,
	        t.order_number, -- noam yanai JUL-2014 CHG0032515
	        t.shipment_number,
	        substr(t.packing_slip, 1, 25) packing_slip,
	        t.shipment_header_id,
	        t.destination_type_code -- Added By Roman W. 09/02/2021 CHG0049272
    FROM   xxinv_trx_rcv_in t
    WHERE  t.doc_type = c_doc_type
    AND    t.status = 'N'
    AND    t.source_code = c_source_code;

  CURSOR c_rcv_lines(c_doc_type           VARCHAR2,
	         c_source_code        VARCHAR2,
	         c_order_header_id    NUMBER,
	         c_shipment_header_id NUMBER) IS
    SELECT xtri.rowid                    row_id,
           xtri.trx_id,
           xtri.interface_transaction_id,
           xtri.header_interface_id,
           xtri.shipment_number,
           xtri.item_code,
           xtri.item_id,
           xtri.lot_number,
           xtri.subinventory,
           xtri.locator_id,
           xtri.lot_expiration_date,
           xtri.shipment_header_id,
           xtri.shipment_line_id,
           xtri.qty_received,
           xtri.from_serial_number,
           xtri.packing_slip,
           xtri.qty_uom_code,
           xtri.po_line_location_id,
           xtri.to_serial_number,
           xtri.order_line_id,
           xtri.order_header_id,
           xtro.lot_number               out_lot,
           xtro.serial_number            out_serial -- noam yanai AUG-2014 CHG0032515
    FROM   xxinv_trx_rcv_in  xtri,
           xxinv_trx_rcv_out xtro
    WHERE  xtri.doc_type = c_doc_type
    AND    xtri.status = 'N'
    AND    xtri.source_code = c_source_code
    AND    nvl(xtri.order_header_id, -1) = nvl(c_order_header_id, -1)
    AND    nvl(xtri.shipment_header_id, -1) = nvl(c_shipment_header_id, -1)
    AND    nvl(xtri.order_header_id, 0) + nvl(xtri.shipment_header_id, 0) > 0
    AND    xtro.line_id = xtri.line_id; -- noam yanai AUG-2014 CHG0032515
  ---> Igorr  - End   15/10/2013

  CURSOR c_rcv_trx_interface(c_doc_type    VARCHAR2,
		     c_source_code VARCHAR2,
		     c_group_id    NUMBER) IS
    SELECT xtri.rowid row_id,
           xtri.source_code,
           xtri.interface_transaction_id,
           xtri.trx_id,
           xtri.header_interface_id,
           xtri.shipment_line_id,
           xtri.shipment_number,
           rti.processing_status_code,
           transaction_status_code
    FROM   xxinv_trx_rcv_in           xtri,
           rcv_transactions_interface rti
    WHERE  xtri.doc_type = c_doc_type
    AND    xtri.status = 'I'
    AND    xtri.source_code = c_source_code
    AND    xtri.interface_group_id =
           nvl(c_group_id, xtri.interface_group_id) -- CHG0031650 support null
    AND    rti.interface_transaction_id(+) = xtri.interface_transaction_id;

  ----------------------------------------------------------------------------
  --   did not process this line yet
  --
  --
  --
  ----------------------------------------------------------------
  PROCEDURE message(p_message VARCHAR2) IS
  
  BEGIN
    dbms_output.put_line(p_message);
    fnd_file.put_line(fnd_file.log, '==== ' || p_message);
  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END message;

  -----------------------------------------------------------------
  -- print_coc_document
  ----------------------------------------------------------------
  -- Purpose: print_coc_document submits program XX: Materials COC
  -- called from procedure handle_pick_trx and handle_pack_trx
  -----------------------------------------------------------------
  -- Ver   Date       Performer        Comments
  -- ----  --------   --------------   ---------------------------
  -- 1.0   05.09.19   Bellona(TCS)        CHG0046435 - For the manufacturing readiness project- phase II
  --                                      , we need to issue to APJ the COC document by
  --                                       Email (HK,CN,KR) and to add it to JP PL set.
  -----------------------------------------------------------------
  PROCEDURE print_coc_document(p_err_message  OUT VARCHAR2,
		       p_err_code     OUT VARCHAR2,
		       p_request_id   OUT NUMBER,
		       p_user_name    VARCHAR2,
		       p_delivery_id  NUMBER,
		       p_calling_proc VARCHAR2) IS
  
    -- out variables for fnd_concurrent.wait_for_request --
    x_phase       VARCHAR2(100);
    x_status      VARCHAR2(100);
    x_dev_phase   VARCHAR2(100);
    x_dev_status  VARCHAR2(100);
    x_return_bool BOOLEAN;
    x_message     VARCHAR2(100);
    --
    l_result BOOLEAN;
    l_to     VARCHAR2(240);
    --
    l_err_code        NUMBER;
    l_err_message     VARCHAR2(500);
    l_user_id         NUMBER;
    l_resp_id         NUMBER;
    l_resp_appl_id    NUMBER;
    l_organization_id NUMBER;
    l_delivery_name   wsh_new_deliveries.name%TYPE;
    --
    end_program_exception EXCEPTION;
    l_from_mail     VARCHAR2(50);
    l_creatort_mail VARCHAR2(500);
    /* CURSOR c_trx IS
    SELECT get_order_creator_mail(delivery_id) creator_mail,
           delivery_id
    FROM   (SELECT DISTINCT t.delivery_id
            FROM   xxinv_trx_pick_in t
            WHERE  t.delivery_id = p_delivery_id
            AND    nvl(t.coc_status, '-1') != 'S');*/
  
    CURSOR c_del_name IS
      SELECT NAME
      FROM   wsh_new_deliveries
      WHERE  delivery_id = p_delivery_id;
  
  BEGIN
    message('print_coc_document p_delivery_id=' || p_delivery_id);
    l_from_mail := xxinv_trx_out_pkg.get_from_mail_address;
    --------------------------
    -- check XX: Materials COC
    ---------------------------
    p_err_code := 0;
  
    -- check report already submitted CHG0046435
  
    IF is_report_submitted(p_calling_proc => p_calling_proc, -- PACK/PICK
		   p_report_type  => 'COC',
		   p_delivery_id  => p_delivery_id) = 'Y' THEN
      RETURN;
    END IF;
  
    l_creatort_mail := get_order_creator_mail(p_delivery_id);
  
    get_user_details(p_user_name       => p_user_name,
	         p_user_id         => l_user_id,
	         p_resp_id         => l_resp_id,
	         p_resp_appl_id    => l_resp_appl_id,
	         p_organization_id => l_organization_id,
	         p_err_code        => l_err_code,
	         p_err_message     => l_err_message);
  
    IF l_err_code = 1 THEN
    
      RAISE stop_process;
    END IF;
  
    OPEN c_del_name;
    FETCH c_del_name
      INTO l_delivery_name;
    CLOSE c_del_name;
  
    -- initialize --
  
    fnd_global.apps_initialize(l_user_id, l_resp_id, l_resp_appl_id);
  
    -- FOR i IN c_trx LOOP
    l_to := fnd_profile.value('XXINV_TPL_COC_REPORT_MAIL') ||
	CASE l_creatort_mail
	  WHEN NULL THEN
	   NULL
	  ELSE
	   ', ' || l_creatort_mail
	END; -- to address
  
    dbms_output.put_line('l_to=' || l_to);
    -- submit request
    l_result := fnd_request.add_delivery_option(TYPE         => 'E', -- this one to speciy the delivery option as Email
				p_argument1  => 'COC_' ||
					    p_delivery_id, -- subject for the mail
				p_argument2  => l_from_mail, -- l_from_mail, -- from address
				p_argument3  => l_to, -- to address
				p_argument4  => '', --fnd_profile.value('XXINV_TPL_CI_REPORT_CC_MAIL'), -- cc address to be specified here.
				nls_language => ''); -- language option);
    IF l_result THEN
      dbms_output.put_line('delivery ok');
    ELSE
      p_err_code    := 1;
      p_err_message := 'Unable to add_delivery_option';
      RAISE end_program_exception;
    END IF;
    -- 05/09/2019
    -- Adding layout of program XX: Materials COC
    l_result := fnd_request.add_layout(template_appl_name => 'XXOBJT',
			   template_code      => 'XXINV_MATCERCON', --'XX: Materials COC',
			   template_language  => 'en',
			   template_territory => 'US', --'IL',
			   output_format      => 'PDF');
  
    l_result := fnd_request.set_print_options(printer     => NULL,
			          copies      => 0,
			          save_output => TRUE);
  
    -- Submitting program XX: Materials COC
    p_request_id := fnd_request.submit_request(application => 'XXOBJT',
			           program     => 'XXINV_MATCERCON',
			           argument1   => l_organization_id, --Warehouse
			           argument2   => nvl(l_delivery_name,
					      to_char(p_delivery_id)), -- Delivery Name
			           argument3   => NULL);
  
    COMMIT;
  
    IF p_request_id > 0 THEN
      --wait for program
      x_return_bool := fnd_concurrent.wait_for_request(p_request_id,
				       5, --- interval 10  seconds
				       1200, ---- max wait
				       x_phase,
				       x_status,
				       x_dev_phase,
				       x_dev_status,
				       x_message);
    
      IF upper(x_dev_phase) = 'COMPLETE' AND
         upper(x_dev_status) IN ('ERROR', 'WARNING') THEN
        p_err_message := 'Concurrent ''XX: Materials COC'' completed in ' ||
		 upper(x_dev_status);
        message(p_err_message);
        p_err_code := '1';
      
      ELSIF upper(x_dev_phase) = 'COMPLETE' AND
	upper(x_dev_status) = 'NORMAL' THEN
        -- report generated
        p_err_message := 'Request_id=' || p_request_id ||
		 ' Report sent to ' || l_to || ' ' ||
		 fnd_profile.value('XXINV_TPL_REPORT_CC_MAIL_LIST');
        message(p_err_message);
      ELSE
        -- error
        p_err_message := 'Concurrent XX: Materials COC failed ';
        p_err_code    := '1';
        message(p_err_message);
      
      END IF;
    ELSE
      -- submit program failed
      p_err_message := 'failed TO submit Concurrent XX: Materials COC ' ||
	           fnd_message.get();
      message(p_err_message);
      p_err_code := '1';
    END IF;
    -- END LOOP;
    --
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code    := 1;
      p_err_message := SQLERRM;
    
  END print_coc_document;

  ----------------------------------------------------------------
  -- check_rma_serial_valid
  ----------------------------------------------------------------
  -- Purpose: check serial is valid : serial received exist at customer installbase
  --   condition copied from form personalization
  -----------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------------------
  --     1.0  07/11/13  yuval tal          initial build
  --     1.1  27/10/14  noam yanai         CHG0032515. added new cursor that incorporates changes due to the SFDC project.
  --                                                   The new cursor is used for org that use SFDC according to profile
  --     1.2  23/11/14  noam yanai         CHG0033946. Add filter to the cursor to comply with ATO project
  --     1.3  19/04/19  Sowjanya K.        CHG0045366 - Restricting the validation of RMA serial numbers (IB tracible)  only for a specific
  --                       list of items like machines/WJ
  -----------------------------------------------------------------
  PROCEDURE check_rma_serial_valid(errbuf        OUT VARCHAR2,
		           retcode       OUT VARCHAR2,
		           p_source_code VARCHAR2) IS
  
    CURSOR c_lines IS
      SELECT xtri.trx_id,
	 xtri.from_serial_number,
	 xtri.to_serial_number,
	 xtri.order_line_id,
	 xtri.item_id
      FROM   xxinv_trx_rcv_in xtri
      WHERE  xtri.doc_type = 'OE'
      AND    xtri.status = 'N'
      AND    xtri.from_serial_number IS NOT NULL
      AND    xtri.source_code = p_source_code;
  
    CURSOR c_valid(c_fm_serial_number VARCHAR2,
	       c_to_serial_number VARCHAR2,
	       c_oe_order_line_id NUMBER,
	       c_item_id          NUMBER) IS(
      SELECT 1
      FROM   dual
      WHERE  (SELECT nvl(MAX(1), 0)
	  FROM   oe_order_headers_all ooh,
	         oe_order_lines_all   ool
	  WHERE  ool.header_id = ooh.header_id
	  AND    ool.line_id = c_oe_order_line_id
	  AND    ooh.order_type_id IN
	         (1025, 1026, 1083, 1089, 1114, 1120, 1153, 1159, 1041)) = 0
      AND    c_oe_order_line_id IS NOT NULL
      AND    c_item_id NOT IN (14277, 14783)
      AND    (SELECT nvl(MAX(1), 0)
	  FROM   mtl_system_items_b msi
	  WHERE  msi.serial_number_control_code = 5
	  AND    msi.replenish_to_order_flag = 'N' -- CHG0033946
	  AND    msi.organization_id = 91
	  AND    c_item_id = msi.inventory_item_id) = 0
      AND    (SELECT nvl(MAX(1), 0)
	  FROM   oe_order_lines_all ool,
	         csi_item_instances cii,
	         hz_cust_accounts   hca,
	         hz_parties         hp
	  WHERE  hca.cust_account_id = ool.sold_to_org_id
	  AND    hca.party_id = hp.party_id
	  AND    (cii.owner_party_id = hp.party_id OR
	        (SELECT attribute2
	           FROM   csi_systems_v csv
	           WHERE  csv.system_id = cii.system_id) =
	        hp.party_id)
	  AND    cii.serial_number BETWEEN c_fm_serial_number AND
	         c_to_serial_number
	  AND    ool.line_id = c_oe_order_line_id) = 0
      AND    (SELECT nvl(MAX(1), 0)
	  FROM   oe_order_lines_all     ool,
	         csi_item_instances     cii,
	         hz_cust_accounts       hca,
	         hz_cust_site_uses_all  hcsua,
	         hz_cust_acct_sites_all hcasa,
	         hz_parties             hp
	  WHERE  hcsua.site_use_id = ool.ship_to_org_id
	  AND    hcsua.cust_acct_site_id = hcasa.cust_acct_site_id
	  AND    hcasa.cust_account_id = hca.cust_account_id
	  AND    hca.party_id = hp.party_id
	  AND    (cii.owner_party_id = hp.party_id OR
	        (SELECT attribute2
	           FROM   csi_systems_v csv
	           WHERE  csv.system_id = cii.system_id) =
	        hp.party_id)
	  AND    cii.serial_number BETWEEN c_fm_serial_number AND
	         c_to_serial_number
	  AND    ool.line_id = c_oe_order_line_id) = 0
	-- CHG0045366 - adding condition for restricting the validation of RMA serial numbers
      AND    (SELECT 1
	  FROM   xxcs_items_printers_v pr
	  WHERE  pr.inventory_item_id = c_item_id) = 1);
  
    CURSOR c_valid_sfdc(c_fm_serial_number VARCHAR2, -- Noam Yanai OCT-2014
		c_to_serial_number VARCHAR2,
		c_oe_order_line_id NUMBER,
		c_item_id          NUMBER) IS(
      SELECT 1
      FROM   dual
      WHERE  (SELECT nvl(MAX(1), 0)
	  FROM   oe_order_headers_all ooh,
	         oe_order_lines_all   ool
	  WHERE  ool.header_id = ooh.header_id
	  AND    ool.line_id = c_oe_order_line_id
	  AND    ooh.order_type_id IN
	         (1025, 1026, 1083, 1089, 1114, 1120, 1153, 1159, 1041)) = 0
      AND    c_oe_order_line_id IS NOT NULL
      AND    c_item_id NOT IN (14277, 14783)
      AND    (SELECT nvl(MAX(1), 0)
	  FROM   mtl_system_items_b msi
	  WHERE  msi.serial_number_control_code = 5
	  AND    msi.replenish_to_order_flag = 'N' -- CHG0033946
	  AND    msi.organization_id = 91
	  AND    c_item_id = msi.inventory_item_id) = 0
      AND    (SELECT nvl(MAX(1), 0)
	  FROM   oe_order_lines_all      ool,
	         xxsf_csi_item_instances cii,
	         hz_cust_accounts        hca,
	         hz_parties              hp
	  WHERE  hca.cust_account_id = ool.sold_to_org_id
	  AND    hca.party_id = hp.party_id
	  AND    (cii.owner_party_id = hp.party_id OR (SELECT hca_end_customer.party_id
				           FROM   hz_cust_accounts hca_end_customer
				           WHERE  cii.account_end_customer_id =
					      hca_end_customer.cust_account_id) =
	        hp.party_id)
	  AND    cii.serial_number BETWEEN c_fm_serial_number AND
	         c_to_serial_number
	  AND    ool.line_id = c_oe_order_line_id) = 0
      AND    (SELECT nvl(MAX(1), 0)
	  FROM   oe_order_lines_all      ool,
	         xxsf_csi_item_instances cii,
	         hz_cust_accounts        hca,
	         hz_cust_site_uses_all   hcsua,
	         hz_cust_acct_sites_all  hcasa,
	         hz_parties              hp
	  WHERE  hcsua.site_use_id = ool.ship_to_org_id
	  AND    hcsua.cust_acct_site_id = hcasa.cust_acct_site_id
	  AND    hcasa.cust_account_id = hca.cust_account_id
	  AND    hca.party_id = hp.party_id
	  AND    (cii.owner_party_id = hp.party_id OR (SELECT hca_end_customer.party_id
				           FROM   hz_cust_accounts hca_end_customer
				           WHERE  cii.account_end_customer_id =
					      hca_end_customer.cust_account_id) =
	        hp.party_id)
	  AND    cii.serial_number BETWEEN c_fm_serial_number AND
	         c_to_serial_number
	  AND    ool.line_id = c_oe_order_line_id) = 0
	-- CHG0045366 - adding condition for restricting the validation of RMA serial numbers
      AND    (SELECT 1
	  FROM   xxcs_items_printers_v pr
	  WHERE  pr.inventory_item_id = c_item_id) = 1);
  
    l_err_code        NUMBER;
    l_err_message     VARCHAR2(500);
    l_user_id         NUMBER;
    l_resp_id         NUMBER;
    l_resp_appl_id    NUMBER;
    l_organization_id NUMBER;
    l_service_app     VARCHAR2(100);
  
  BEGIN
    retcode := 0;
    get_user_details(p_user_name       => p_source_code,
	         p_user_id         => l_user_id,
	         p_resp_id         => l_resp_id,
	         p_resp_appl_id    => l_resp_appl_id,
	         p_organization_id => l_organization_id,
	         p_err_code        => l_err_code,
	         p_err_message     => l_err_message);
  
    ------- initialize ---------
    fnd_global.apps_initialize(l_user_id, l_resp_id, l_resp_appl_id);
  
    message('ORG_ID=' || fnd_global.org_id);
  
    mo_global.set_policy_context('S', fnd_global.org_id);
    inv_globals.set_org_id(fnd_global.org_id);
    mo_global.init('INV');
    -----------------------------
  
    l_service_app := fnd_profile.value('XXINV_TPL_SERVICE_APPLICATION'); -- Noam Yanai OCT-2014
  
    FOR i IN c_lines
    LOOP
    
      IF l_service_app = 'ORACLE' THEN
        -- Use the existing cursor
        FOR j IN c_valid(i.from_serial_number,
		 i.to_serial_number,
		 i.order_line_id,
		 i.item_id)
        LOOP
          xxinv_trx_in_pkg.update_rcv_status(errbuf        => errbuf,
			         retcode       => retcode,
			         p_source_code => p_source_code,
			         p_status      => 'E',
			         p_err_message => 'Serial number does not exists at customer site ,please pick valid serial.',
			         p_doc_type    => 'OE',
			         p_trx_id      => i.trx_id);
        
        END LOOP;
      ELSE
        -- Use the new cursor
        FOR j IN c_valid_sfdc(i.from_serial_number,
		      i.to_serial_number,
		      i.order_line_id,
		      i.item_id)
        LOOP
          xxinv_trx_in_pkg.update_rcv_status(errbuf        => errbuf,
			         retcode       => retcode,
			         p_source_code => p_source_code,
			         p_status      => 'E',
			         p_err_message => 'Serial number does not exists at customer site ,please pick valid serial.',
			         p_doc_type    => 'OE',
			         p_trx_id      => i.trx_id);
        
        END LOOP;
      END IF;
    END LOOP;
    COMMIT;
  END check_rma_serial_valid;

  -----------------------------------------------------------------
  -- get_shipment_alert_body
  ----------------------------------------------------------------
  -- Purpose: used to generate mail body of last receive checking failure
  --          when tpl  report in rcv internal peocess
  ----------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------------------
  --     1.0  24.9.13   yuval tal       initial build
  -----------------------------------------------------------------
  FUNCTION get_shipment_alert_body(p_shipment_header_id NUMBER)
    RETURN VARCHAR2 IS
  
    l_body VARCHAR2(32000);
    l_more VARCHAR2(1) := 'N';
  
    CURSOR c_ship IS
      SELECT h.shipment_num         shipment_number,
	 l.line_num             shipment_line_number,
	 msib.inventory_item_id,
	 msib.segment1          item_code,
	 l.quantity_shipped,
	 l.quantity_received,
	 h.shipment_header_id,
	 l.shipment_line_id
      FROM   mtl_system_items_b   msib,
	 rcv_shipment_headers h,
	 rcv_shipment_lines   l
      WHERE  msib.organization_id = 91
      AND    msib.inventory_item_id = l.item_id
      AND    h.shipment_header_id = l.shipment_header_id
      AND    l.shipment_line_status_code IN
	 ('PARTIALLY RECEIVED', 'EXPECTED')
	-- AND h.shipment_num = '632239'
      AND    h.shipment_header_id = p_shipment_header_id
      ORDER  BY 2;
  
    CURSOR c_ship_lines(c_shipment_header_id VARCHAR2,
		c_shipment_line_id   NUMBER) IS
      SELECT o.item_id,
	 o.lot_number,
	 o.serial_number,
	 SUM(o.qty_ordered) qty
      FROM   xxinv_trx_rcv_out o
      WHERE  o.doc_type = 'INTERNAL'
      AND    o.shipment_header_id = c_shipment_header_id
      AND    o.shipment_line_id = c_shipment_line_id
      GROUP  BY o.item_id,
	    o.lot_number,
	    o.serial_number
      MINUS
      SELECT i.item_id,
	 i.lot_number,
	 i.from_serial_number,
	 SUM(i.qty_received) qty
      FROM   xxinv_trx_rcv_in i
      WHERE  i.doc_type = 'INTERNAL'
      AND    i.shipment_header_id = c_shipment_header_id
      AND    i.shipment_line_id = c_shipment_line_id
      GROUP  BY i.item_id,
	    i.lot_number,
	    i.from_serial_number;
  BEGIN
    l_body := xxobjt_wf_mail_support.get_header_html('INTERNAL');
    l_body := l_body || ('The following Items were not received:');
    l_body := l_body || ('<table border=1>');
    l_body := l_body ||
	  ('<tr><th>Item Code</th><th>Quantity Shipped</th><th>Quantity Rceived</th><th>Lot Number</th><th>Serial number</th></tr>');
    FOR i IN c_ship
    LOOP
      FOR j IN c_ship_lines(i.shipment_header_id, i.shipment_line_id)
      LOOP
        l_body := l_body || '<tr><td>' || i.item_code || '</td><td>' ||
	      i.quantity_shipped || '</td><td>' || i.quantity_received ||
	      '</td><td>' || nvl(j.lot_number, chr(38) || 'nbsp') ||
	      '</td><td>' || nvl(j.serial_number, chr(38) || 'nbsp') ||
	      '</td></tr>';
      
        IF length(l_body) > 31000 THEN
          l_more := 'Y';
          EXIT;
        END IF;
      END LOOP;
    
      IF l_more = 'Y' THEN
        EXIT;
      END IF;
    END LOOP;
  
    l_body := l_body || '</table>';
  
    IF l_more = 'Y' THEN
      l_body := l_body || '
      Not all records were printed ...';
    END IF;
  
    l_body := l_body || xxobjt_wf_mail_support.get_footer_html;
  
    RETURN l_body;
  EXCEPTION
    WHEN OTHERS THEN
      l_body := 'Error generating alert body , see xxinv_trx_in_pkg.get_shipment_alert_body <br> for p_shipment_header_id= ' ||
	    p_shipment_header_id;
      RETURN l_body;
  END get_shipment_alert_body;

  -----------------------------------------------------------------
  -- get_user_id
  ----------------------------------------------------------------
  -- Purpose: get_user_details
  -----------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------------------
  --     1.0  24.9.13   yuval tal         initial build
  -----------------------------------------------------------------
  PROCEDURE get_user_details(p_user_name       VARCHAR2,
		     p_user_id         OUT NUMBER,
		     p_resp_id         OUT NUMBER,
		     p_resp_appl_id    OUT NUMBER,
		     p_organization_id OUT NUMBER,
		     p_err_code        OUT NUMBER,
		     p_err_message     OUT VARCHAR2) IS
  
  BEGIN
    p_err_code := 0;
    BEGIN
      SELECT user_id
      INTO   p_user_id
      FROM   fnd_user
      WHERE  user_name = p_user_name; -- 'TPL.DE';
    
    EXCEPTION
      WHEN OTHERS THEN
        p_err_code    := 1;
        p_err_message := 'User id not found';
        RETURN;
      
    END;
    -- get resp id
    p_resp_id := fnd_profile.value_specific(NAME    => 'XXINV_TPL_RESPONSIBILITY_ID',
			        user_id => p_user_id);
  
    -- get resp appl id
    BEGIN
    
      SELECT application_id
      INTO   p_resp_appl_id
      FROM   fnd_responsibility_vl t
      WHERE  t.responsibility_id = p_resp_id;
    
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;
    -- get  organization_id
    p_organization_id := fnd_profile.value_specific(NAME    => 'XXINV_TPL_ORGANIZATION_ID',
				    user_id => p_user_id);
  
    -- check id's exists
    IF p_resp_id IS NULL OR p_organization_id IS NULL THEN
    
      p_err_message := 'Missing values in profiles XXINV_TPL_RESPONSIBILITY_ID or XXINV_TPL_ORGANIZATION_ID';
      p_err_code    := 1;
    
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code    := 1;
      p_err_message := SQLERRM;
  END get_user_details;

  --------------------------------------------------------------------
  --  name:             print_log
  --  create by:        Dalit A. RAviv
  --  Revision:         1.0
  --  creation date:    10/Sep/2015
  --------------------------------------------------------------------
  --  purpose :         CHG0035915 - Print message to log
  --------------------------------------------------------------------
  --  ver  date         name            desc
  --  1.0  10/Sep/2015  Dalit A. RAviv  initial build
  --------------------------------------------------------------------
  PROCEDURE print_log(p_print_msg VARCHAR2) IS
  BEGIN
    IF fnd_global.conc_request_id = -1 THEN
      dbms_output.put_line(p_print_msg);
    ELSE
      fnd_file.put_line(fnd_file.log, p_print_msg);
    END IF;
  END print_log;

  --------------------------------------------------------------------
  --  name:             print_out
  --  create by:        Dalit A. RAviv
  --  Revision:         1.0
  --  creation date:    10/Sep/2015
  --------------------------------------------------------------------
  --  purpose :         CHG0035915 - Print message to output
  --------------------------------------------------------------------
  --  ver  date         name            desc
  --  1.0  10/Sep/2015  Dalit A. RAviv  initial build
  --------------------------------------------------------------------
  PROCEDURE print_out(p_print_msg VARCHAR2) IS
  BEGIN
    IF fnd_global.conc_request_id = -1 THEN
      dbms_output.put_line(p_print_msg);
    ELSE
      fnd_file.put_line(fnd_file.output, p_print_msg);
    END IF;
  END print_out;

  --------------------------------------------------------------------
  --  name:            get_lpn_id
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   10/Sep/2015 13:32:01
  --------------------------------------------------------------------
  --  purpose :        CHG0035915
  --                   get LPN id by LPN name and organization
  --                   Note - Same LPN name can be use in differernt organizations.
  --  In:              p_lpn_number
  --                   p_organization_id
  --  Return:          Lpn_id
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10/Sep/2015 Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_lpn_id(p_lpn_number      IN VARCHAR2,
	          p_organization_id IN NUMBER) RETURN NUMBER IS
  
    l_lpn_id NUMBER;
  BEGIN
    SELECT t.lpn_id
    INTO   l_lpn_id
    FROM   wms_license_plate_numbers t
    WHERE  t.license_plate_number = p_lpn_number
    AND    t.organization_id = p_organization_id;
  
    RETURN l_lpn_id;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_lpn_id;

  --------------------------------------------------------------------
  --  name:            create_lpn
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   10/Sep/2015
  --------------------------------------------------------------------
  --  purpose :        CHG0035915
  --                   create new LPN in oracle
  --                   p_container_item_id  := 10005;               -- item id of the container item defined 'LPN-00001'
  --                   p_container_name     := 'LPN_Dalit20150910'; -- name of the new LPN to be created
  --                   p_organization_id    := 736;                 -- orgnization id to which the container is associated (ITA)
  --                   p_quantity           := 1;                   -- denotes the number of LPN to be created.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10/Sep/2015 Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE create_lpn(errbuf              OUT VARCHAR2,
	           retcode             OUT VARCHAR2,
	           p_container_item_id IN NUMBER,
	           p_container_name    IN VARCHAR2,
	           p_organization_id   IN NUMBER,
	           p_quantity          IN NUMBER) IS
  
    -- Parameters for WSH_CONTAINER_PUB.create_containers
    l_container_item_name VARCHAR2(2000);
    l_container_item_seg  fnd_flex_ext.segmentarray;
    l_organization_code   VARCHAR2(2000);
    l_name_prefix         VARCHAR2(2000);
    l_name_suffix         VARCHAR2(2000);
    l_base_number         NUMBER;
    l_num_digits          NUMBER;
    x_container_ids       wsh_util_core.id_tab_type;
    --out parameters
    x_return_status VARCHAR2(10);
    x_msg_count     NUMBER;
    x_msg_data      VARCHAR2(2000);
    x_msg_details   VARCHAR2(3000);
    x_msg_summary   VARCHAR2(3000);
    --Handle exceptions
    fail_api EXCEPTION;
  
  BEGIN
    errbuf  := NULL;
    retcode := 0;
    -- Initialize return status
    x_return_status := wsh_util_core.g_ret_sts_success;
  
    /* for debug
    IF (fnd_global.conc_request_id = -1) AND (g_init IS NULL) THEN
      -- Call this procedure to initialize applications parameters.
      fnd_global.apps_initialize(user_id => 2470, resp_id => 50623, resp_appl_id => 660);
    END IF;*/
  
    -- Call to WSH_CONTAINER_PUB.CREATE_CONTAINERS
    wsh_container_pub.create_containers(p_api_version         => 1.0,
			    p_init_msg_list       => apps.fnd_api.g_true,
			    p_commit              => fnd_api.g_false,
			    x_return_status       => x_return_status,
			    x_msg_count           => x_msg_count,
			    x_msg_data            => x_msg_data,
			    p_container_item_id   => p_container_item_id, -- inventory item id of the container LPN-00001 = 10005
			    p_container_item_name => l_container_item_name,
			    p_container_item_seg  => l_container_item_seg,
			    p_organization_id     => p_organization_id, -- orgnization id to which the container is associated
			    p_organization_code   => l_organization_code,
			    p_name_prefix         => l_name_prefix,
			    p_name_suffix         => l_name_suffix,
			    p_base_number         => l_base_number,
			    p_num_digits          => l_num_digits,
			    p_quantity            => p_quantity, -- the number of LPN to be created.
			    p_container_name      => p_container_name, -- name of the new LPN to be created
			    x_container_ids       => x_container_ids);
  
    IF (x_return_status <> wsh_util_core.g_ret_sts_success) THEN
      RAISE fail_api;
    ELSE
      COMMIT;
    END IF;
  EXCEPTION
    WHEN fail_api THEN
      wsh_util_core.get_messages('Y',
		         x_msg_summary,
		         x_msg_details,
		         x_msg_count);
      IF x_msg_count > 1 THEN
        x_msg_data := x_msg_summary || x_msg_details;
      ELSE
        x_msg_data := x_msg_summary;
      END IF;
      print_log('Create_lpn: ' || x_msg_data);
      errbuf  := 'Err - create_lpn - ' || x_msg_data;
      retcode := 1;
      ROLLBACK;
    WHEN OTHERS THEN
      errbuf  := 'GEN Err - create_lpn ' || substr(SQLERRM, 1, 240);
      retcode := 1;
  END create_lpn;

  --------------------------------------------------------------------
  --  name:            pack_lpn_and_delivery
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   10/Sep/2015
  --------------------------------------------------------------------
  --  purpose :        CHG0035915
  --                   Pack DD into LPN
  --                   p_container_name   := 'LPN_Dalit20150910'; -- Container_name
  --                   p_action_code      := 'PACK';              -- Container action code (PACK)
  --                   p_detail_tab(1)    := 19037931;            -- Delivery detail to be packed
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10/Sep/2015 Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE pack_lpn_and_delivery(errbuf            OUT VARCHAR2,
		          retcode           OUT VARCHAR2,
		          p_container_name  IN VARCHAR2,
		          p_action_code     IN VARCHAR2,
		          p_delivery_detail IN NUMBER) IS
  
    l_detail_tab       wsh_util_core.id_tab_type;
    l_cont_instance_id NUMBER;
    l_container_flag   VARCHAR2(2000);
    l_delivery_flag    VARCHAR2(2000);
    l_delivery_id      NUMBER;
    l_delivery_name    VARCHAR2(2000);
    -- out parameters
    x_return_status VARCHAR2(10);
    x_msg_count     NUMBER;
    x_msg_data      VARCHAR2(2000);
    x_msg_details   VARCHAR2(3000);
    x_msg_summary   VARCHAR2(3000);
  
    -- Handle exceptions
    fail_api EXCEPTION;
  BEGIN
  
    errbuf  := NULL;
    retcode := 0;
    -- Initialize return status
    x_return_status := wsh_util_core.g_ret_sts_success;
  
    /* for debug
    IF (fnd_global.conc_request_id = -1) AND (g_init IS NULL) THEN
      -- Call this procedure to initialize applications parameters.
      fnd_global.apps_initialize(user_id      => 2470,
                                 resp_id      => 50623,
                                 resp_appl_id => 660);
    END IF;*/
  
    l_detail_tab(1) := p_delivery_detail; -- 19037931 Delivery detail to be packed
  
    wsh_container_pub.container_actions(p_api_version      => 1.0,
			    p_init_msg_list    => apps.fnd_api.g_true,
			    p_commit           => fnd_api.g_false,
			    x_return_status    => x_return_status, -- o
			    x_msg_count        => x_msg_count, -- o
			    x_msg_data         => x_msg_data, -- o
			    p_detail_tab       => l_detail_tab, -- Delivery detail to be packed
			    p_container_name   => p_container_name, -- Container_name
			    p_cont_instance_id => l_cont_instance_id,
			    p_container_flag   => l_container_flag,
			    p_delivery_flag    => l_delivery_flag,
			    p_delivery_id      => l_delivery_id,
			    p_delivery_name    => l_delivery_name,
			    p_action_code      => p_action_code -- Container action code (PACK)
			    );
    IF (x_return_status <> wsh_util_core.g_ret_sts_success) THEN
      RAISE fail_api;
    ELSE
      --print_log('The container '||p_container_name||' is successfully packed with delivery details '||p_delivery_detail);
      COMMIT;
    END IF;
  EXCEPTION
    WHEN fail_api THEN
      wsh_util_core.get_messages('Y',
		         x_msg_summary,
		         x_msg_details,
		         x_msg_count);
      IF x_msg_count > 1 THEN
        x_msg_data := x_msg_summary || x_msg_details;
      ELSE
        x_msg_data := x_msg_summary;
      END IF;
      print_log('Pack_lpn_and_delivery: ' || x_msg_data);
      errbuf  := 'Err - pack_lpn_and_delivery - ' || x_msg_data;
      retcode := 1;
      ROLLBACK;
    WHEN OTHERS THEN
      errbuf  := 'GEN Err - pack_lpn_and_delivery ' ||
	     substr(SQLERRM, 1, 240);
      retcode := 1;
  END pack_lpn_and_delivery;

  --------------------------------------------------------------------
  --  name:            Split_delivery_line
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   10/Sep/2015
  --------------------------------------------------------------------
  --  purpose :        CHG0035915
  --                   get delivery_detail_id and qty to split from DD
  --                   return the new DD
  --                   p_from_detail_id
  --                   p_split_quantity (the qty to be split out of the total qty)
  --  Return           p_new_detail_id
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10/Sep/2015 Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE split_delivery_line(errbuf           OUT VARCHAR2,
		        retcode          OUT VARCHAR2,
		        p_from_detail_id IN NUMBER,
		        p_split_quantity IN NUMBER,
		        p_new_detail_id  OUT NUMBER) IS
  
    l_new_detail_id   NUMBER := NULL;
    l_split_quantity  NUMBER := p_split_quantity;
    l_split_quantity2 NUMBER := NULL;
    -- out parameters
    x_return_status VARCHAR2(10);
    x_msg_count     NUMBER;
    x_msg_data      VARCHAR2(2000);
    x_msg_details   VARCHAR2(3000);
    x_msg_summary   VARCHAR2(3000);
    -- Handle exceptions
    fail_api EXCEPTION;
  BEGIN
    errbuf  := NULL;
    retcode := 0;
    -- Initialize return status
    x_return_status := wsh_util_core.g_ret_sts_success;
  
    /* for debug
    IF (fnd_global.conc_request_id = -1) AND (g_init IS NULL) THEN
      -- Call this procedure to initialize applications parameters.
      fnd_global.apps_initialize(user_id      => 2470,
                                 resp_id      => 50623,
                                 resp_appl_id => 660);
    END IF;*/
  
    wsh_delivery_details_pub.split_line( -- Standard parameters
			    p_api_version      => '1.0', -- i n
			    p_init_msg_list    => apps.fnd_api.g_true, -- i v
			    p_commit           => fnd_api.g_false, -- i v
			    p_validation_level => fnd_api.g_valid_level_full, -- i n
			    x_return_status    => x_return_status, -- o v
			    x_msg_count        => x_msg_count, -- o n
			    x_msg_data         => x_msg_data, -- o v
			    -- program specific parameters
			    p_from_detail_id  => p_from_detail_id, -- i n
			    x_new_detail_id   => l_new_detail_id, -- o n
			    x_split_quantity  => l_split_quantity, -- i/o n
			    x_split_quantity2 => l_split_quantity2 -- i/o n
			    );
  
    IF (x_return_status <> wsh_util_core.g_ret_sts_success) THEN
      RAISE fail_api;
    ELSE
      print_log('Line had Successfully splited. New detail_id - ' ||
	    l_new_detail_id || ' Splited from detail_id - ' ||
	    p_from_detail_id);
      p_new_detail_id := l_new_detail_id;
      COMMIT;
    END IF;
  EXCEPTION
    WHEN fail_api THEN
      wsh_util_core.get_messages('Y',
		         x_msg_summary,
		         x_msg_details,
		         x_msg_count);
      IF x_msg_count > 1 THEN
        x_msg_data := x_msg_summary || x_msg_details;
      ELSE
        x_msg_data := x_msg_summary;
      END IF;
      print_log('Split_delivery_line: ' || x_msg_data);
      p_new_detail_id := NULL;
      errbuf          := 'Err - Split_delivery_line ' || x_msg_data;
      retcode         := 1;
      ROLLBACK;
    WHEN OTHERS THEN
      errbuf  := 'GEN Err - split_delivery_line ' ||
	     substr(SQLERRM, 1, 240);
      retcode := 1;
  END split_delivery_line;

  --------------------------------------------------------------------
  --  name:            get_lpn_delivery_detail
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   29/Sep/2015
  --------------------------------------------------------------------
  --  purpose :        CHG0035915
  --                   Get lpn_id return the DD it conect with
  --  Get:             p_lpn_id
  --  Return:          p_delivery_detail_id of the LPN
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  29/Sep/2015 Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_lpn_delivery_detail(p_lpn_id IN NUMBER) RETURN NUMBER IS
  
    l_delivery_detail_id NUMBER := NULL;
  
  BEGIN
    SELECT wdd.delivery_detail_id
    INTO   l_delivery_detail_id
    FROM   wsh_delivery_details wdd
    WHERE  wdd.lpn_id = p_lpn_id;
  
    RETURN l_delivery_detail_id;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_lpn_delivery_detail;

  --------------------------------------------------------------------
  --  name:            update_lpn_dd_details
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   06/Oct/2015
  --------------------------------------------------------------------
  --  purpose :        CHG0035915
  --                   update LPN delivery detail record with the DFF Attributes info
  --                   and the gross_weight, net_weight
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/Oct/2015 Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE update_lpn_dd_info(errbuf                   OUT VARCHAR2,
		       retcode                  OUT VARCHAR2,
		       p_lpn_delivery_detail_id IN NUMBER,
		       p_gross_weight           IN NUMBER,
		       p_att2_lpn_lenght        IN VARCHAR2,
		       p_att3_lpn_width         IN VARCHAR2,
		       p_att4_lpn_height        IN VARCHAR2,
		       p_att5_lpn_uom           IN VARCHAR2) IS
  
    --l_changed_attributes wsh_delivery_details_pub.changedattributerectype;
    l_changed_attributes wsh_delivery_details_pub.changedattributetabtype;
  
    --out parameters
    x_return_status VARCHAR2(10);
    x_msg_count     NUMBER;
    x_msg_data      VARCHAR2(2000);
    x_msg_details   VARCHAR2(3000);
    x_msg_summary   VARCHAR2(3000);
    apierror EXCEPTION;
  BEGIN
  
    errbuf  := NULL;
    retcode := 0;
    -- Initialize return status
    x_return_status := wsh_util_core.g_ret_sts_success;
  
    l_changed_attributes(1).gross_weight := p_gross_weight; -- n
    l_changed_attributes(1).net_weight := p_gross_weight; -- n
    l_changed_attributes(1).delivery_detail_id := p_lpn_delivery_detail_id; -- 19069640; 19068647; -- n
    l_changed_attributes(1).attribute_category := 'Y'; -- v
    l_changed_attributes(1).attribute2 := p_att2_lpn_lenght; -- v
    l_changed_attributes(1).attribute3 := p_att3_lpn_width; -- v
    l_changed_attributes(1).attribute4 := p_att4_lpn_height; -- v
    l_changed_attributes(1).attribute5 := p_att5_lpn_uom; -- v CM
  
    /*wsh_container_pub.update_container(p_api_version   => 1.0,
    p_init_msg_list => fnd_api.g_true,
    p_commit        => fnd_api.g_false,
    --p_validation_level => ,
    x_return_status => x_return_status,
    x_msg_count     => x_msg_count,
    x_msg_data      => x_msg_data,
    p_container_rec => l_changed_attributes);*/
  
    wsh_delivery_details_pub.update_shipping_attributes(p_api_version_number => 1.0,
				        p_init_msg_list      => fnd_api.g_true,
				        p_commit             => fnd_api.g_false,
				        x_return_status      => x_return_status,
				        x_msg_count          => x_msg_count,
				        x_msg_data           => x_msg_data,
				        p_changed_attributes => l_changed_attributes,
				        p_source_code        => 'WSH');
  
    IF (x_return_status <> wsh_util_core.g_ret_sts_success) THEN
      RAISE apierror;
    ELSE
      --print_log('update_lpn_dd_info - update Container additional info with success');
      /*update wsh_delivery_details wdd
      set    wdd.attribute_category = 'Y'
      where  wdd.delivery_detail_id = p_lpn_delivery_detail_id;
      */
      COMMIT;
    END IF;
  EXCEPTION
    WHEN apierror THEN
      wsh_util_core.get_messages('Y',
		         x_msg_summary,
		         x_msg_details,
		         x_msg_count);
      IF x_msg_count > 1 THEN
        x_msg_data := x_msg_summary || x_msg_details;
      ELSE
        x_msg_data := x_msg_summary;
      END IF;
      print_log('Update_lpn_dd_info: ' || x_msg_data);
      errbuf  := 'E Update_lpn_dd_info: ' || x_msg_data;
      retcode := 1;
      ROLLBACK;
    
    WHEN OTHERS THEN
      errbuf  := 'GEN Err - update_lpn_dd_info ' || substr(SQLERRM, 1, 240);
      retcode := 1;
      print_log('update_lpn_dd_info - GEN Err: ' ||
	    substr(SQLERRM, 1, 240));
  END update_lpn_dd_info;

  --------------------------------------------------------------------
  --  name:            is_delivery_packed
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   07/Oct/2015
  --------------------------------------------------------------------
  --  purpose :        CHG0035915
  --                   check if all delivery detail records that belong to
  --                   specific delivery are packed.
  --                   update delivery record with the DFF Attributes info
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  07/Oct/2015 Dalit A. Raviv    initial build
  --  1.1  31.07.17    Yuval Tal         INC0098783 add  stock_enabled_flag
  --------------------------------------------------------------------
  FUNCTION is_delivery_packed(p_delivery_id IN NUMBER) RETURN VARCHAR2 IS
    l_count NUMBER := 0;
  
  BEGIN
  
    SELECT COUNT(1)
    INTO   l_count
    FROM   wsh_dlvy_deliverables_v wddv,
           mtl_system_items_b      mtl
    WHERE  wddv.delivery_id = p_delivery_id -- 2132330
    AND    wddv.parent_container_instance_id IS NULL
    AND    wddv.container_flag = 'N'
    AND    wddv.source_code = 'OE'
    AND    mtl.stock_enabled_flag = 'Y' -- INC0098783
    AND    mtl.organization_id = wddv.organization_id --INC0098783
    AND    mtl.inventory_item_id = wddv.inventory_item_id; -- INC0098783
  
    IF l_count = 0 THEN
      RETURN 'Y';
    ELSE
      RETURN 'N';
    END IF;
  END is_delivery_packed;

  --------------------------------------------------------------------
  --  name:            update_delivery_dff
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   07/Oct/2015
  --------------------------------------------------------------------
  --  purpose :        CHG0035915
  --                   update delivery record with the DFF Attributes info
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  07/Oct/2015 Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE update_delivery_dff(errbuf        OUT VARCHAR2,
		        retcode       OUT VARCHAR2,
		        p_delivery_id IN NUMBER,
		        p_pack        IN VARCHAR2,
		        p_pack_date   IN DATE) IS
  
    x_delivery_info  apps.wsh_deliveries_pub.delivery_pub_rec_type;
    x_return_status  VARCHAR2(5);
    x_msg_count      NUMBER;
    x_msg_data       VARCHAR2(2000);
    lo_delivery_name wsh_new_deliveries.name%TYPE;
    --l_delivery_name      wsh_new_deliveries.name%type;
    l_delivery_id wsh_new_deliveries.delivery_id%TYPE;
    x_msg_details VARCHAR2(3000);
    x_msg_summary VARCHAR2(3000);
    my_exe EXCEPTION;
  
  BEGIN
    errbuf  := NULL;
    retcode := 0;
    /* for debug
    FND_GLOBAL.APPS_INITIALIZE(user_id => 2470, resp_id => 50623, resp_appl_id => 660);
    mo_global.set_policy_context('S', 736);
    mo_global.init('ONT');
    */
  
    x_delivery_info.attribute3       := p_pack; -- Y/N LOOKUP_TYPE = 'YES_NO'
    x_delivery_info.attribute4       := fnd_date.date_to_canonical(p_pack_date);
    x_delivery_info.delivery_id      := p_delivery_id;
    x_delivery_info.last_update_date := SYSDATE;
    x_delivery_info.last_updated_by  := fnd_global.user_id;
    wsh_deliveries_pub.create_update_delivery(p_api_version_number => 1.0, -- i n
			          p_init_msg_list      => fnd_api.g_true, -- i v
			          x_return_status      => x_return_status, -- o v
			          x_msg_count          => x_msg_count, -- o n
			          x_msg_data           => x_msg_data, -- o v
			          p_action_code        => 'UPDATE', -- o v
			          p_delivery_info      => x_delivery_info, -- i/o Delivery_Pub_Rec_Type,
			          x_delivery_id        => l_delivery_id, -- o n
			          x_name               => lo_delivery_name); -- o v
  
    IF (x_return_status <> wsh_util_core.g_ret_sts_success) THEN
      print_log('Failed to update delivery DFF feilds ' || p_delivery_id);
      RAISE my_exe;
      --else
      --print_log('Delivery has successfully update DFF feilds'||p_delivery_id);
    END IF;
  
    COMMIT;
  
  EXCEPTION
    WHEN my_exe THEN
      print_log('Error Details If Any ' || p_delivery_id);
      wsh_util_core.get_messages('Y',
		         x_msg_summary,
		         x_msg_details,
		         x_msg_count);
    
      IF x_msg_count > 1 THEN
        x_msg_data := x_msg_summary || ' ' || x_msg_details;
      ELSE
        x_msg_data := x_msg_summary || ' ' || x_msg_details;
      END IF;
      print_log('update_delivery_dff: ' || x_msg_data);
      errbuf  := 'update_delivery_dff: ' || x_msg_data;
      retcode := 1;
      ROLLBACK;
    WHEN OTHERS THEN
      print_log('GEN ERR update_delivery_dff - ' ||
	    substr(SQLERRM, 1, 240));
      errbuf  := 'GEN ERR update_delivery_dff - ' ||
	     substr(SQLERRM, 1, 240);
      retcode := 1;
  END update_delivery_dff;

  --------------------------------------------------------------------
  --  name:            get_db_qty
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   07/Oct/2015
  --------------------------------------------------------------------
  --  purpose :        CHG0035915
  --                   find all records that recursive connect to the DD_id
  --                   the TPL sent, that are not packed yet, and match to item, organization, and serial/lot
  --                   return the qty and DD_id of the recursive line.
  --                   It is very important to return the correct DD_id, because this DD_id will use for the pack with LPN
  --                   (it can be a DD_id of a direct splited line, or DD_id of a splited line from a splited line)
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  07/Oct/2015 Dalit A. Raviv    initial build
  --  1.1  3.8.17      yuval tal        INC0099029 - Upper Serial Numbers/Lot
  --  1.2  25/10/2017  Diptasurjya/Dovik INC0105240 - Added released_status='Y' to consider staged lines only
  --  1.3  10/24/2017  Diptasurjya       CHG0040327 - Make changes to avoid too many rows
  --                                     error when delivery detail has been split due to
  --                                     different revision / locator
  --  1.4  15.06.18    Bellona(TCS)     CHG0042444 - Pass new parameter(quantity) to get_db_qty procedure
  --                                     and make changes to avoid too many rows error when delivery detail has been split.
  --------------------------------------------------------------------
  PROCEDURE get_db_qty(errbuf               OUT VARCHAR2,
	           retcode              OUT VARCHAR2,
	           p_delivery_detail_id IN NUMBER,
	           p_inventory_item_id  IN NUMBER,
	           p_lot_number         IN VARCHAR2,
	           p_serial_number      IN VARCHAR2,
	           p_packed_quantity    IN NUMBER, -- CHG0042444
	           p_organization_id    IN NUMBER,
	           --p_trx_line_id        IN NUMBER,  -- CHG0040327
	           --p_dd_id   OUT NUMBER,                -- CHG0042444
	           --p_req_qty OUT NUMBER                -- CHG0042444
	           p_del_tab OUT ddtabtyp -- CHG0042444
	           ) IS
  
    --l_revision  varchar2(3);      -- CHG0040327
    --l_subinventory varchar2(10);  -- CHG0040327
    --l_locator_id number;          -- CHG0040327
  
    --l_req_qty NUMBER;
    --l_dd_id   NUMBER;
    tot_qty NUMBER := 0; --CHG0042444
    l_match VARCHAR2(10) := 'N'; --CHG0042444
  
  BEGIN
    errbuf  := NULL;
    retcode := 0;
    dd_tab.delete;
    IF p_serial_number IS NOT NULL THEN
      WITH dd_qty AS
       (SELECT dd_all.delivery_detail_id,
	   dd_all.requested_quantity,
	   dd_all.inventory_item_id,
	   dd_all.organization_id,
	   dd_all.transaction_temp_id,
	   nvl(dd_all.serial_number, t.fm_serial_number) serial_number
        FROM   (SELECT wdd.delivery_detail_id,
	           wdd.requested_quantity,
	           wdd.inventory_item_id,
	           wdd.organization_id,
	           wdd.transaction_temp_id,
	           wdd.serial_number
	    FROM   wsh_delivery_details     wdd,
	           wsh_delivery_assignments wda
	    WHERE  wda.delivery_detail_id = wdd.delivery_detail_id
	    AND    wda.parent_delivery_detail_id(+) IS NULL
	    AND    wdd.released_status = 'Y' -- INC0105240
	    AND    wdd.inventory_item_id = p_inventory_item_id
	    AND    wdd.organization_id = p_organization_id
	    START  WITH wdd.delivery_detail_id = p_delivery_detail_id
	    CONNECT BY PRIOR wdd.delivery_detail_id =
		    wdd.split_from_delivery_detail_id) dd_all,
	   mtl_serial_numbers_temp t
        WHERE  dd_all.transaction_temp_id = t.transaction_temp_id(+)
        AND    upper(nvl(dd_all.serial_number, t.fm_serial_number)) =
	   upper(p_serial_number)) --INC0099029
      SELECT requested_quantity,
	 delivery_detail_id
      BULK   COLLECT
      INTO   dd_tab --l_req_qty, l_dd_id    --CHG0042444
      FROM   dd_qty;ELSE
      -- ELSIF p_lot_number is not null then   -- CHG0040327 - Change ELSE  to ELSIF to check for lot number not null only
      WITH dd_qty AS
       (SELECT dd_all.delivery_detail_id,
	   dd_all.requested_quantity,
	   dd_all.inventory_item_id,
	   dd_all.organization_id,
	   dd_all.lot_number
        FROM   (SELECT wdd.delivery_detail_id,
	           wdd.requested_quantity,
	           wdd.inventory_item_id,
	           wdd.organization_id,
	           wdd.lot_number
	    FROM   wsh_delivery_details     wdd,
	           wsh_delivery_assignments wda
	    WHERE  wda.delivery_detail_id =
	           wdd.delivery_detail_id
	    AND    wda.parent_delivery_detail_id(+) IS NULL
	    AND    wdd.released_status = 'Y' -- INC0105240
	    AND    wdd.inventory_item_id =
	           p_inventory_item_id
	    AND    wdd.organization_id =
	           p_organization_id
	    START  WITH wdd.delivery_detail_id =
		    p_delivery_detail_id
	    CONNECT BY PRIOR
		    wdd.delivery_detail_id =
		    wdd.split_from_delivery_detail_id) dd_all
        WHERE  (upper(dd_all.lot_number) =
	   upper(p_lot_number) OR p_lot_number IS NULL)) --INC0099029
      SELECT requested_quantity,
	 delivery_detail_id
      BULK   COLLECT
      INTO   dd_tab --l_req_qty, l_dd_id    --CHG0042444
      FROM   dd_qty;
    /*   -- CHG0040327 - Dipta new add portion
      ELSE
        select xsho.revision,
               xsho.subinventory,
               xsho.locator_id
          into l_revision,
               l_subinventory,
               l_locator_id
          from xxinv_trx_ship_out xsho
         where xsho.line_id = p_trx_line_id;
      
        WITH dd_qty AS
         (SELECT dd_all.delivery_detail_id,
                 dd_all.requested_quantity,
                 dd_all.inventory_item_id,
                 dd_all.organization_id,
                 dd_all.revision,
                 dd_all.subinventory,
                 dd_all.locator_id
          FROM   (SELECT wdd.delivery_detail_id,
                         wdd.requested_quantity,
                         wdd.inventory_item_id,
                         wdd.organization_id,
                         nvl(mmt.revision,wdd.revision) revision,
                         nvl(mmt.subinventory_code,wdd.subinventory) subinventory,
                         nvl(mmt.locator_id,wdd.locator_id) locator_id
                  FROM   wsh_delivery_details     wdd,
                         mtl_material_transactions mmt
                  WHERE  mmt.transaction_id (+) = wdd.transaction_id
                  AND    wdd.inventory_item_id = p_inventory_item_id
                  AND    wdd.organization_id = p_organization_id
                  START  WITH wdd.delivery_detail_id = p_delivery_detail_id
                  CONNECT BY PRIOR wdd.delivery_detail_id = wdd.split_from_delivery_detail_id) dd_all
          WHERE  nvl(upper(dd_all.revision),'-9999') = nvl(l_revision,'-9999')
            AND  nvl(upper(dd_all.subinventory),'-9999') = nvl(l_subinventory,'-9999')
            AND  nvl(upper(dd_all.locator_id),-9999) = nvl(l_locator_id,-9999))
        SELECT requested_quantity,
                 delivery_detail_id
        INTO   l_req_qty,
                 l_dd_id
        FROM   dd_qty;
      -- CHG0040327 - Dipta end new addition
        */
    END IF;
  
    --CHG0042444 change started
    -- Searching for a line in db having qty equal to packed qty.
    FOR i IN 1 .. dd_tab.count
    LOOP
      IF dd_tab(i).req_qty = p_packed_quantity AND l_match = 'N' THEN
        --l_req_qty:= dd_tab(i).req_qty;
        --l_dd_id :=  dd_tab(i).dd_id;
        p_del_tab(1) := dd_tab(i);
        l_match := 'Y';
      END IF;
      -- Sum of qty of all the lines in DB relevant to the TPL line
      tot_qty := tot_qty + dd_tab(i).req_qty;
    
    END LOOP;
  
    IF dd_tab.count < 1 THEN
      -- Can not get DB qty, no data found for item and lot/serial
      fnd_message.set_name('XXOBJT', 'XXINV_PACK_TRX_QTY_NDF');
      errbuf := fnd_message.get;
      retcode := 1;
      p_del_tab(1).dd_id := NULL;
      p_del_tab(1).req_qty := 0;
    ELSIF dd_tab.count > 1 AND l_match = 'N' THEN
      -- checking whether packed qty is equal to summation of all DB lines relevant to TPL line.
      -- if equal, the delivery detail ids are passed as parameter to main procedure for packing each DB line.
      IF tot_qty = p_packed_quantity THEN
        FOR i IN 1 .. dd_tab.count
        LOOP
          p_del_tab(i) := dd_tab(i);
        END LOOP;
      ELSE
        -- There is more then one record that retrived for the same item and lot/serial
        fnd_message.set_name('XXOBJT', 'XXINV_PACK_TRX_QTY_TMR');
        errbuf := fnd_message.get;
        retcode := 1;
        p_del_tab(1).dd_id := NULL;
        p_del_tab(1).req_qty := 0;
      END IF;
    ELSIF dd_tab.count = 1 THEN
      p_del_tab(1) := dd_tab(1);
    END IF;
    --CHG0042444 change ended
  
    --p_dd_id   := l_dd_id;
    --p_req_qty := l_req_qty;
  EXCEPTION
    WHEN no_data_found THEN
      -- Can not get DB qty, no data found for item and lot/serial
      fnd_message.set_name('XXOBJT', 'XXINV_PACK_TRX_QTY_NDF');
      errbuf := fnd_message.get;
      retcode := 1;
      p_del_tab(1).dd_id := NULL;
      p_del_tab(1).req_qty := 0;
    WHEN too_many_rows THEN
      -- There is more then one record that retrived for the same item and lot/serial
      fnd_message.set_name('XXOBJT', 'XXINV_PACK_TRX_QTY_TMR');
      errbuf := fnd_message.get;
      retcode := 1;
      p_del_tab(1).dd_id := NULL;
      p_del_tab(1).req_qty := 0;
    WHEN OTHERS THEN
      errbuf := 'Gen Err - get_db_qty - ' || substr(SQLERRM, 1, 240);
      retcode := 1;
      p_del_tab(1).dd_id := NULL;
      p_del_tab(1).req_qty := 0;
  END get_db_qty;

  -----------------------------------------------------------------
  -- handle_rcv_trx
  ----------------------------------------------------------------
  -- Purpose: handle rcv trx
  -- handle PO MO OE INTERNAL receiving  transactions
  -----------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------------------
  --     1.0  24.9.13   yuval tal         initial build
  -----------------------------------------------------------------
  PROCEDURE main_rcv_trx(errbuf      OUT VARCHAR2,
		 retcode     OUT VARCHAR2,
		 p_user_name VARCHAR2) IS
  
    l_err_code       VARCHAR2(50);
    l_err_message    VARCHAR2(500);
    l_common_retcode VARCHAR2(50) := '0';
    l_common_exc EXCEPTION;
  
  BEGIN
    retcode := '0';
  
    /****************************************************
      Start Process for Internal, PO, RMA, MO types
    ****************************************************/
    xxinv_trx_in_pkg.handle_rcv_internal_trx(errbuf      => l_err_message,
			         retcode     => l_err_code,
			         p_user_name => p_user_name);
  
    l_common_retcode := greatest(l_common_retcode, l_err_code);
  
    -- Added By Roman W. 10/03/2021 CHG0049272
    xxinv_trx_in_pkg.handle_rcv_inspect_trx(errbuf      => l_err_message,
			        retcode     => l_err_code,
			        p_user_name => p_user_name);
  
    l_common_retcode := greatest(l_common_retcode, l_err_code);
  
    xxinv_trx_in_pkg.handle_rcv_po_trx(errbuf      => l_err_message,
			   retcode     => l_err_code,
			   p_user_name => p_user_name);
  
    l_common_retcode := greatest(l_common_retcode, l_err_code);
  
    xxinv_trx_in_pkg.handle_rcv_rma_trx(errbuf      => l_err_message,
			    retcode     => l_err_code,
			    p_user_name => p_user_name);
  
    l_common_retcode := greatest(l_common_retcode, l_err_code);
  
    xxinv_trx_in_pkg.handle_rcv_mo_trx(errbuf      => l_err_message,
			   retcode     => l_err_code,
			   p_user_name => p_user_name);
  
    l_common_retcode := greatest(l_common_retcode, l_err_code);
  
    IF nvl(l_common_retcode, '0') != '0' THEN
      retcode := '2';
      errbuf  := SQLERRM;
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      retcode := '2';
      errbuf  := SQLERRM;
  END main_rcv_trx;

  -----------------------------------------------------------------
  -- handle_rcv_trx
  ----------------------------------------------------------------
  -- Purpose: handle rcv trx
  -- handle  INTERNAL receiving  transactions
  -----------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------------------
  --     1.0  24.9.13   yuval tal         initial build
  --     1.1  29.10.13  IgorR
  --     1.1  27.3.14   yuval tal       CHG0031650 : remove call to RVCTP
  --     2.0  06/08/14  noam yanai      CHG0032515 : handle problems with letter case in lot and serial
  --     2.1  27/10/14  noam yanai                   add resend file functionality
  --     2.2  27/11/14  noam yanai      CHG0033946 : add inter-organization transfers
  --                                                 calculate src_doc_code and rcpt_src_code according to internal type (Inter-org/IR)
  -----------------------------------------------------------------
  PROCEDURE handle_rcv_internal_trx(errbuf      OUT VARCHAR2,
			retcode     OUT VARCHAR2,
			p_user_name VARCHAR2) IS
  
    l_err_code        NUMBER;
    l_err_message     VARCHAR2(500);
    l_user_id         NUMBER;
    l_resp_id         NUMBER;
    l_resp_appl_id    NUMBER;
    l_organization_id NUMBER;
    l_org_id          NUMBER;
  
    l_interface_transaction_id NUMBER;
    l_header_interface_id      NUMBER;
    l_group_id                 NUMBER;
    l_lot                      VARCHAR2(80); -- noam yanai AUG-2014 CHG0032515
    l_serial                   VARCHAR2(30); -- noam yanai AUG-2014 CHG0032515
    l_source_doc_code          VARCHAR2(20); -- noam yanai NOV-2014 CHG0033946
    l_receipt_source_code      VARCHAR2(20); -- noam yanai NOV-2014 CHG0033946
  
  BEGIN
  
    l_org_id := fnd_global.org_id;
  
    -- check required
    validate_rcv_data(errbuf, retcode, 'INTERNAL', p_user_name);
    --
    -- get user details
    get_user_details(p_user_name       => p_user_name,
	         p_user_id         => l_user_id,
	         p_resp_id         => l_resp_id,
	         p_resp_appl_id    => l_resp_appl_id,
	         p_organization_id => l_organization_id,
	         p_err_code        => l_err_code,
	         p_err_message     => l_err_message);
  
    IF l_err_code = 1 THEN
      RAISE stop_process;
    END IF;
    ------- initialize ---------
    fnd_global.apps_initialize(l_user_id, l_resp_id, l_resp_appl_id);
  
    message('org_id=' || fnd_global.org_id);
    l_org_id := fnd_global.org_id;
    mo_global.set_policy_context('S', l_org_id);
    inv_globals.set_org_id(l_org_id);
    mo_global.init('INV');
  
    --- internal ---------------
    SELECT rcv_interface_groups_s.nextval
    INTO   l_group_id
    FROM   dual;
  
    SELECT 10 + round(COUNT(*) / g_sleep_mod) * g_sleep_mod_sec
    INTO   g_sleep
    FROM   xxinv_trx_rcv_in t
    WHERE  t.doc_type = 'INTERNAL'
    AND    t.status = 'N'
    AND    t.source_code = p_user_name;
  
    FOR k IN c_rcv_header('INTERNAL', p_user_name)
    LOOP
      BEGIN
        SAVEPOINT header_sp;
      
        IF k.order_header_id IS NULL THEN
          -- inter organization transfer (K2)
          l_source_doc_code     := 'INVENTORY';
          l_receipt_source_code := 'INVENTORY';
        ELSE
          -- internal shipment
          l_source_doc_code     := 'REQ';
          l_receipt_source_code := 'INTERNAL ORDER';
        END IF;
      
        BEGIN
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
	(l_org_id, --> ORG_ID
	 rcv_headers_interface_s.nextval, --> HEADER_INTERFACE_ID
	 l_group_id, --> GROUP_ID
	 'PENDING', --> PROCESSING_STATUS_CODE
	 l_receipt_source_code, --> RECEIPT_SOURCE_CODE  CHG0033946 noam yanai NOV-14  include inter-organization transfer
	 'NEW', --> TRANSACTION_TYPE
	 SYSDATE, --> LAST_UPDATE_DATE
	 0, --> LAST_UPDATED_BY
	 0, --> LAST_UPDATE_LOGIN
	 SYSDATE, --> CREATION_DATE
	 0, --> CREATED_BY
	 k.shipment_number, --> SHIPMENT_NUM
	 l_organization_id, --> SHIP_TO_ORGANIZATION_ID
	 fnd_global.employee_id, --> EMPLOYEE_ID
	 'Y', --> VALIDATION_FLAG
	 NULL, --> TRANSACTION_DATE
	 NULL --> PACKING_SLIP
	 )
          RETURNING group_id, header_interface_id INTO l_group_id, l_header_interface_id;
        END;
      
        FOR i IN c_rcv_lines('INTERNAL',
		     p_user_name,
		     k.order_header_id,
		     k.shipment_header_id)
        LOOP
        
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
	 locator_id,
	 shipment_num,
	 shipped_date,
	 header_interface_id,
	 validation_flag,
	 org_id)
          VALUES
	(rcv_transactions_interface_s.nextval, -- INTERFACE_TRANSACTION_ID
	 l_group_id, -- GROUP_ID
	 SYSDATE, -- LAST_UPDATE_DATE
	 l_user_id, -- LAST_UPDATED_BY
	 SYSDATE, -- CREATION_DATE
	 l_user_id, -- CREATED_BY
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
	 l_receipt_source_code, -- RECEIPT_SOURCE_CODE CHG0033946 noam yanai NOV-14  include inter-organization transfer
	 l_organization_id, -- TO_ORGANIZATION_ID
	 l_source_doc_code, -- SOURCE_DOCUMENT_CODE CHG0033946 noam yanai NOV-14  include inter-organization transfer
	 NULL, -- REQUISITION_LINE_ID
	 NULL, -- REQ_DISTRIBUTION_ID
	 'INVENTORY', -- DESTINATION_TYPE_CODE
	 NULL, -- DELIVER_TO_PERSON_ID
	 NULL, -- LOCATION_ID
	 NULL, -- DELIVER_TO_LOCATION_ID
	 i.subinventory, -- SUBINVENTORY
	 i.locator_id, -- LOCATOR_ID
	 i.shipment_number, -- SHIPMENT_NUM
	 NULL, -- SHIPPED_DATE
	 rcv_headers_interface_s.currval, -- HEADER_INTERFACE_ID
	 'Y', -- VALIDATION_FLAG
	 l_org_id)
          RETURNING interface_transaction_id INTO l_interface_transaction_id;
        
          ---  insert serial /lot -------------
          -- if lot control
          IF i.lot_number IS NOT NULL THEN
	IF is_lot_serial_the_same(i.out_lot, i.lot_number) = 'Y' THEN
	  -- added by noam yanai AUG-2014 CHG0032515
	  l_lot := i.out_lot;
	ELSE
	  l_lot := i.lot_number;
	END IF;
          
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
	  (mtl_material_transactions_s.nextval, --TRANSACTION_INTERFACE_ID
	   SYSDATE, --LAST_UPDATE_DATE
	   l_user_id, --LAST_UPDATED_BY
	   SYSDATE, --CREATION_DATE
	   l_user_id, --CREATED_BY
	   fnd_global.login_id, --LAST_UPDATE_LOGIN
	   l_lot, --LOT_NUMBER                                              -- added by noam yanai AUG-2014 CHG0032515
	   i.qty_received, --TRANSACTION_QUANTITY
	   i.qty_received, --PRIMARY_QUANTITY
	   NULL, --  mtl_material_transactions_s.nextval, --SERIAL_TRANSACTION_TEMP_ID
	   'RCV', --PRODUCT_CODE
	   rcv_transactions_interface_s.currval, --PRODUCT_TRANSACTION_ID
	   i.item_id);
          END IF;
        
          --  if serial control
          IF i.from_serial_number IS NOT NULL THEN
	IF is_lot_serial_the_same(i.out_serial, i.from_serial_number) = 'Y' THEN
	  -- added by noam yanai AUG-2014 CHG0032515
	  l_serial := i.out_serial;
	ELSE
	  l_serial := i.from_serial_number;
	END IF;
          
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
	  (mtl_material_transactions_s.nextval, --TRANSACTION_INTERFACE_ID
	   SYSDATE, --LAST_UPDATE_DATE
	   l_user_id, --LAST_UPDATED_BY
	   SYSDATE, --CREATION_DATE
	   l_user_id, --CREATED_BY
	   fnd_global.login_id, --LAST_UPDATE_LOGIN
	   l_serial, --FM_SERIAL_NUMBER                                  -- added by noam yanai AUG-2014 CHG0032515
	   l_serial, --TO_SERIAL_NUMBER                                  -- added by noam yanai AUG-2014 CHG0032515
	   'RCV', --PRODUCT_CODE
	   rcv_transactions_interface_s.currval, --PRODUCT_TRANSACTION_ID,
	   i.item_id);
          END IF;
        
          ------------- update interface id's
          UPDATE xxinv_trx_rcv_in
          SET    status                   = 'I',
	     interface_transaction_id = l_interface_transaction_id,
	     header_interface_id      = l_header_interface_id,
	     interface_group_id       = l_group_id
          WHERE  trx_id = i.trx_id;
        
          --  delele from temporary table in case of profile XXINV_TPL_RESEND_RCV_FILE ='Y'
          delete_xxinv_trx_resend_orders(errbuf      => errbuf,
			     retcode     => retcode,
			     p_doc_type  => 'INTERNAL',
			     p_header_id => i.shipment_header_id);
          --------------------------------------
        END LOOP; -- lines
      
      EXCEPTION
        WHEN OTHERS THEN
          ROLLBACK TO header_sp;
          l_err_message := substr(SQLERRM, 1, 255);
        
          UPDATE xxinv_trx_rcv_in t
          SET    status        = 'E',
	     t.err_message = l_err_message
          WHERE  t.doc_type = 'INTERNAL'
          AND    t.status = 'N'
          AND    t.source_code = p_user_name
          AND    t.order_header_id = k.order_header_id
          AND    nvl(t.shipment_header_id, -1) =
	     nvl(k.shipment_header_id, -1);
        
      END;
      COMMIT;
    END LOOP; -- packing slip-- header
  
    -- check errors
  
    FOR j IN c_rcv_trx_interface('INTERNAL', p_user_name, NULL)
    LOOP
      IF c_rcv_trx_interface%ROWCOUNT = 1 THEN
        dbms_lock.sleep(g_sleep);
      END IF;
      BEGIN
      
        SELECT nvl(error_message, 'XX Unknown error')
        INTO   l_err_message
        FROM   (SELECT REPLACE(listagg(error_message, ' | ') within
		       GROUP(ORDER BY interface_line_id),
		       'Txn Success.') error_message
	    FROM   po_interface_errors t
	    WHERE  t.interface_line_id = j.interface_transaction_id
	    AND    NOT EXISTS
	     (SELECT 1
		FROM   rcv_transactions rt
		WHERE  rt.interface_transaction_id =
		       j.interface_transaction_id))
        WHERE  (error_message IS NOT NULL OR
	   nvl(j.processing_status_code, 'SUCCEEDED') = 'ERROR');
      
        xxinv_trx_in_pkg.update_rcv_status(errbuf        => errbuf,
			       retcode       => retcode,
			       p_source_code => p_user_name,
			       p_status      => 'E',
			       p_err_message => l_err_message,
			       p_trx_id      => j.trx_id,
			       p_doc_type    => 'INTERNAL');
      
        message(j.interface_transaction_id ||
	    ' interface_transaction_id status=E');
      
      EXCEPTION
        WHEN no_data_found THEN
        
          IF nvl(j.processing_status_code, 'SUCCEEDED') NOT IN
	 ('PENDING', 'ERROR') THEN
	xxinv_trx_in_pkg.update_rcv_status(errbuf        => errbuf,
			           retcode       => retcode,
			           p_source_code => p_user_name,
			           p_status      => 'S',
			           p_err_message => '',
			           p_trx_id      => j.trx_id,
			           p_doc_type    => 'INTERNAL');
          
	message(j.interface_transaction_id ||
	        ' interface_transaction_id status=S');
          END IF;
      END;
    END LOOP;
  
    COMMIT;
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

  -----------------------------------------------------------------
  -- handle_pick_trx
  -----------------------------------------------------------------
  -- Purpose: handle pick trx
  -------------------------------------------------------------------------------------------------------------------------------------------------------------
  -- Version  Date      Performer           Comments
  ----------  ----------  ---------------   -------------------------------------------------------------------------------------------------------------------
  --     1.0  24.9.13     yuval tal         initial build
  --     1.1  2.7.14      noam yanai        CHG0032573 : update xxinv_trx_ship_out with new lot / serial and save original in new fields orig_lot/org_serial
  --                                                   to prevent re-insert of task (will fail unique check)
  --     2.0  06/08/14    noam yanai        CHG0032515 : handle problem with letter case of lot and serial
  --     2.1  27/10/14    noam yanai                     added sending of packing list when finished picking (according to profile)
  --     2.2  26/10/17    Piyali Bhowmick   CHG0041294 : Delivery need to be created and
  --                                                   delivery detail need to be assign to delivery name   in case no allocation mode
  --                                                   all intangible item   if found is  assign to  delivery details
  --     2.3  01.12.17    Bellona Banerjee  CHG0041294 : modify handle_pick_trx to create reservation, allocation, picking and backorder rest of  associated
  --                                                   order lines. Add proc create_allocation to create allocation for items.
  --     2.4  17.07.18    Bellona(TCS)      CHG0043509 : XX INV TPL Interface Pick transaction - Delivery Detail ID Mandatory
  --                                            Added missing exception handling section wrt delivery_id fetch.
  --     2.5  24.07.18    Bellona(TCS)      INC0126962 : TPL Pick - Status changed to Success, while nothing processed
  --                                                   Adding log message to capture error checkpoints.
  --     2.6  09/11/2018  Roman W.          CHG0044170 - TPL Interfaces- LPN implementation in APJ
  --     2.7  05.09.19    Bellona(TCS)      CHG0046435 - TPL Handle Pack - COC document by Email
  --     2.8  31.12.19    Bellona(TCS)      CHG0046955 - TPL Interfaces - validation on Pick IN messages
  --     2.9   6.7.21     yuval tal         INC0236079 - add exception in  validation loop
  --------------------------------------------------------------------------------------------------------------------------------------------------------------
  PROCEDURE handle_pick_trx(errbuf      OUT VARCHAR2,
		    retcode     OUT VARCHAR2,
		    p_user_name VARCHAR2) IS
  
    CURSOR c_trx IS
      SELECT t.*,
	 o.print_performa_invoice,
	 o.subinventory           out_subinventory,
	 o.locator_id             out_locator_id,
	 o.lot_number             out_lot, -- noam yanai AUG-2014 CHG0032515
	 o.serial_number          out_serial, -- noam yanai AUG-2014 CHG0032515
	 o.revision               out_revision, -- noam yanai AUG-2014 CHG0032515
	 o.transaction_temp_id    out_temp_id -- noam yanai AUG-2014 CHG0032515
      FROM   xxinv_trx_pick_in  t,
	 xxinv_trx_ship_out o
      WHERE  t.source_code = p_user_name -- 'TPL'
      AND    t.status = 'N'
      AND    o.line_id = t.line_id
      ORDER  BY t.trx_id;
  
    --V2.3 CHG0041294 - Cursor for pick transactions process
    CURSOR c_pick_batch IS
      SELECT t.*,
	 o.print_performa_invoice,
	 o.subinventory           out_subinventory,
	 o.locator_id             out_locator_id,
	 o.lot_number             out_lot, -- noam yanai AUG-2014 CHG0032515
	 o.serial_number          out_serial, -- noam yanai AUG-2014 CHG0032515
	 o.revision               out_revision, -- noam yanai AUG-2014 CHG0032515
	 o.transaction_temp_id    out_temp_id -- noam yanai AUG-2014 CHG0032515
      FROM   xxinv_trx_pick_in  t,
	 xxinv_trx_ship_out o
      WHERE  t.source_code = p_user_name -- 'TPL'
      AND    t.status IN ('N', 'R')
      AND    o.line_id = t.line_id
      ORDER  BY trx_id;
  
    --V2.3 CHG0041294 - Cursor for move order lines relating pick transactions process
    CURSOR c_mo_details(c_move_order_header_id NUMBER) IS
      SELECT mtrh.header_id,
	 mtrh.request_number,
	 mtrh.move_order_type,
	 mtrh.organization_id
      FROM   mtl_txn_request_headers mtrh
      WHERE  mtrh.header_id = c_move_order_header_id;
  
    --V2.3 CHG0041294 - Cursor for fetching lines to be reserved for line ids having
    --multi-lines
    CURSOR c_reserve_batch(p_line_id NUMBER) IS
      SELECT t.*,
	 o.print_performa_invoice,
	 o.subinventory           out_subinventory,
	 o.locator_id             out_locator_id,
	 o.lot_number             out_lot, -- noam yanai AUG-2014 CHG0032515
	 o.serial_number          out_serial, -- noam yanai AUG-2014 CHG0032515
	 o.revision               out_revision, -- noam yanai AUG-2014 CHG0032515
	 o.transaction_temp_id    out_temp_id -- noam yanai AUG-2014 CHG0032515*/
      FROM   xxinv_trx_pick_in  t,
	 xxinv_trx_ship_out o
      WHERE  t.source_code = p_user_name -- 'TPL.ITA'
      AND    t.status = 'N'
      AND    t.line_id = p_line_id -- i.line_id
      AND    o.line_id = t.line_id
      ORDER  BY t.trx_id,
	    t.line_id;
  
    --V2.3 CHG0041294 - fetching order_source_id passed to Reservation API
    CURSOR c_get_ord_source(c_order_num NUMBER) IS
      SELECT order_source_id
      FROM   oe_order_headers_all o
      WHERE  o.order_number = c_order_num; --XXINV_TRX_PICK_IN.ORDER_NUMBER
  
    --V2.3 CHG0041294 - fetching sales_order_id passed to Reservation API
    CURSOR c_sal_ord_id(p_order_number NUMBER) IS
      SELECT m.sales_order_id
      FROM   apps.mtl_sales_orders_kfv m
      WHERE  m.segment1 = p_order_number; --XXINV_TRX_PICK_IN.ORDER_NUMBER;
  
    --V2.3 CHG0041294 - fetching revision for serial control item passed to
    --Reservation API
    CURSOR c_revision(p_serial_num  VARCHAR2,
	          p_inv_item_id NUMBER) IS
      SELECT msn.revision
      FROM   mtl_serial_numbers msn
      WHERE  msn.serial_number = p_serial_num --XXINV_TRX_PICK_IN.SERIAL_NUMBER
      AND    msn.inventory_item_id = p_inv_item_id; --XXINV_TRX_PICK_IN.INVENTORY_ITEM_ID;
  
    --V2.3 CHG0041294 - fetching line_id passed to Reservation API as demand_source_line_id
    /*CURSOR c_demand_source_line_id(p_order_number NUMBER, p_order_line_num NUMBER)    IS
    SELECT l.line_id
      FROM oe_order_headers_all h, oe_order_lines_all l
     WHERE h.header_id=l.header_id
       AND h.order_number= p_order_number--XXINV_TRX_PICK_IN.ORDER_NUMBER
       AND l.line_number= p_order_line_num--XXINV_TRX_PICK_IN.ORDER_LINE_NUMBER
       and l.flow_status_code <> 'CLOSED'; -- for order lines having split lines
    */
    CURSOR c_demand_source_line_id(p_line_id NUMBER) IS
      SELECT o.order_line_id
      FROM   xxinv_trx_pick_in  t,
	 xxinv_trx_ship_out o
      WHERE  1 = 1
      AND    o.line_id = t.line_id
      AND    t.line_id = p_line_id; --1919952
  
    --V2.3 CHG0041294 - fetching revision for non-lot, non-serial control item passed to
    --Reservation API
    CURSOR c_revsn(p_item_id     NUMBER,
	       p_org_id      NUMBER,
	       p_subinv_code VARCHAR2,
	       p_loc_id      NUMBER) IS
      SELECT t.revision
      FROM   mtl_onhand_quantities t
      WHERE  t.organization_id = p_org_id
      AND    t.inventory_item_id = p_item_id
      AND    t.subinventory_code = p_subinv_code
      AND    t.locator_id = p_loc_id
      GROUP  BY t.inventory_item_id,
	    t.organization_id,
	    t.subinventory_code,
	    t.locator_id,
	    t.revision;
  
    --V2.3 CHG0041294 - fetching lines to be backordered related to pick_in form records
    CURSOR c_source_lines(p_trx_id NUMBER) IS
      SELECT t.*,
	 o.print_performa_invoice,
	 o.subinventory           out_subinventory,
	 o.locator_id             out_locator_id,
	 o.lot_number             out_lot, -- noam yanai AUG-2014 CHG0032515
	 o.serial_number          out_serial, -- noam yanai AUG-2014 CHG0032515
	 o.revision               out_revision, -- noam yanai AUG-2014 CHG0032515
	 o.transaction_temp_id    out_temp_id -- noam yanai AUG-2014 CHG0032515
      FROM   xxinv_trx_pick_in  t,
	 xxinv_trx_ship_out o
      WHERE  t.source_code = p_user_name -- 'TPL'
      AND    o.line_id = t.line_id
      AND    trx_id > (p_trx_id - 1);
  
    --V2.3 CHG0041294 - fetching lines to be backordered post - reservation, allocation
    --and picking process
    CURSOR c_backorder_lines(p_move_order_no NUMBER,
		     p_order_number  NUMBER) IS
      SELECT mtrh.header_id,
	 mtrh.request_number,
	 mtrh.move_order_type,
	 mtrh.organization_id,
	 mtrl.line_id,
	 mtrl.line_number,
	 mtrl.inventory_item_id,
	 mtrl.lot_number,
	 mtrl.quantity,
	 revision,
	 mtrl.from_locator_id,
	 (SELECT DISTINCT operating_unit
	  FROM   org_organization_definitions
	  WHERE  organization_id = mtrh.organization_id) org_id
      FROM   mtl_txn_request_headers mtrh,
	 mtl_txn_request_lines   mtrl
      WHERE  mtrh.header_id = mtrl.header_id
      AND    mtrh.request_number = to_char(p_move_order_no)
      AND    mtrl.txn_source_id IN
	 (SELECT sales_order_id
	   FROM   apps.mtl_sales_orders_kfv m
	   WHERE  m.segment1 = to_char(p_order_number))
      AND    mtrl.line_status IN
	 (SELECT lookup_code
	   FROM   fnd_lookup_values
	   WHERE  lookup_type = 'MTL_TXN_REQUEST_STATUS'
	   AND    LANGUAGE = 'US'
	   AND    meaning IN ('Approved', 'Pre Approved'));
  
    --V2.3 CHG0041294 - fetching extra move order lines created by Oracle System
    --after Allocation
    CURSOR c_extra_molines(p_move_order_line_id NUMBER,
		   p_line_id            NUMBER) IS
      SELECT transaction_temp_id,
	 move_order_line_id,
	 reservation_id,
	 transaction_quantity,
	 primary_quantity --,a.*
      FROM   mtl_material_transactions_temp a
      WHERE  1 = 1
      AND    move_order_line_id = p_move_order_line_id --75769167--p_move_order_line_id
      AND    reservation_id NOT IN
	 (SELECT nvl(commercial_request_id, 0)
	   FROM   xxinv_trx_pick_in t
	   WHERE  line_id = p_line_id);
  
    l_api_version                  NUMBER := 1.0;
    x_return_status                VARCHAR2(2);
    x_msg_count                    NUMBER := 0;
    x_msg_data                     VARCHAR2(500);
    l_transaction_mode             NUMBER := 1;
    l_trolin_tbl                   inv_move_order_pub.trolin_tbl_type;
    l_mold_tbl                     inv_mo_line_detail_util.g_mmtt_tbl_type;
    x_mmtt_tbl                     inv_mo_line_detail_util.g_mmtt_tbl_type;
    x_trolin_tbl                   inv_move_order_pub.trolin_tbl_type;
    l_transaction_date             DATE := SYSDATE;
    l_mo_details                   c_mo_details%ROWTYPE;
    l_err_code                     NUMBER;
    l_err_message                  VARCHAR2(1000);
    l_user_id                      NUMBER;
    l_resp_id                      NUMBER;
    l_resp_appl_id                 NUMBER;
    l_organization_id              NUMBER;
    l_commercial_request_id        NUMBER;
    l_is_all_delivery_lines_staged VARCHAR2(1) := 'N';
    l_revision                     mtl_item_revisions_b.revision%TYPE;
  
    l_is_serial_controlled VARCHAR2(1) := 'N'; -- Noam Yanai
    l_is_lot_controlled    VARCHAR2(1) := 'N'; -- By Noam Yanai
    l_miss_filed_name      VARCHAR2(100);
    --
    l_my_exception EXCEPTION;
    l_sqlerrm          VARCHAR2(300);
    l_mo_line_status   NUMBER; -- Noam Yanai
    l_current_delivery NUMBER; -- Noam Yanai
    l_lot              VARCHAR2(80); -- noam yanai AUG-2014 CHG0032515
    l_serial           VARCHAR2(30); -- noam yanai AUG-2014 CHG0032515
    l_pl_request_id    NUMBER;
    l_del_flag         NUMBER := 0; --CHG0041294
    l_delivery_id      NUMBER; --CHG0041294
    l_out_delivery_id  NUMBER; --CHG0041294
    l_retcode          VARCHAR2(10); --CHG0041294
    l_errbuf           VARCHAR2(500); --CHG0041294
    ti                 NUMBER := 0; --CHG0041294
    flag               NUMBER := 0; --CHG0041294
    l_flow_status_code VARCHAR2(30); --CHG0041294;
    l_header_id        NUMBER; --CHG0041294;
    /*Variables related to reservation creation*/ --CHG0041294
    l_rsv_rec              inv_reservation_global.mtl_reservation_rec_type;
    l_serial_number        inv_reservation_global.serial_number_tbl_type;
    v_serial_number        inv_reservation_global.serial_number_tbl_type;
    l_return_status        VARCHAR2(50);
    l_msg_count            NUMBER;
    l_msg_data             VARCHAR2(250);
    v_quantity_reserved    NUMBER;
    v_reservation_id       NUMBER;
    l_message              VARCHAR2(255);
    l_avlbl_to_reserve_qty NUMBER;
    l_flag                 NUMBER;
    tot_picked_qty         NUMBER;
    l_cnt                  NUMBER;
  
    l_ord_source_id         NUMBER;
    l_rev                   mtl_serial_numbers.revision%TYPE;
    l_sal_ord_id            apps.mtl_sales_orders_kfv.sales_order_id%TYPE;
    l_demand_source_line_id apps.oe_order_lines_all.line_id%TYPE;
    l_delivery_date         mtl_reservations_all_v.requirement_date%TYPE;
    l_coc_request_id        NUMBER; --CHG0046435
  BEGIN
  
    -- get user details
    get_user_details(p_user_name       => p_user_name,
	         p_user_id         => l_user_id,
	         p_resp_id         => l_resp_id,
	         p_resp_appl_id    => l_resp_appl_id,
	         p_organization_id => l_organization_id,
	         p_err_code        => l_err_code,
	         p_err_message     => l_err_message);
  
    IF l_err_code = 1 THEN
      RAISE stop_process;
    END IF;
    ------- initialize ---------
    fnd_global.apps_initialize(l_user_id, l_resp_id, l_resp_appl_id);
    message('ORG_ID=' || fnd_global.org_id);
  
    mo_global.set_policy_context('S', fnd_global.org_id);
    inv_globals.set_org_id(fnd_global.org_id);
    mo_global.init('INV');
    -------------------------------
    -- check required fields ---
  
    FOR u IN c_trx
    
    LOOP
      BEGIN
        -- yuval ???
        l_miss_filed_name := NULL;
        CASE
          WHEN u.move_order_line_id IS NULL THEN
          
	l_miss_filed_name := 'move_order_line_id';
	/*  WHEN u.delivery_id IS NULL THEN
            l_miss_filed_name := 'delivery_id';*/
          WHEN u.delivery_id IS NULL AND
	   fnd_profile.value('XXINV_TPL_ALLOCATIONS') = 'Y' THEN
	--CHG0041294
	l_miss_filed_name := 'delivery_id';
          WHEN u.delivery_name IS NULL AND
	   fnd_profile.value('XXINV_TPL_ALLOCATIONS') = 'N' THEN
	-- CHG0041294
	l_miss_filed_name := 'delivery_name ';
          WHEN u.item_code IS NULL THEN
	l_miss_filed_name := 'item_code';
          WHEN u.inventory_item_id IS NULL THEN
	l_miss_filed_name := 'inventory_item_id';
          WHEN u.subinventory IS NULL THEN
	l_miss_filed_name := 'subinventory';
          WHEN u.locator_id IS NULL THEN
	l_miss_filed_name := 'locator_id';
          WHEN u.line_id IS NULL THEN
	l_miss_filed_name := 'line_id';
          WHEN u.picked_quantity IS NULL THEN
	l_miss_filed_name := 'picked_quantity';
          WHEN u.transaction_temp_id IS NULL AND
	   fnd_profile.value('XXINV_TPL_ALLOCATIONS') = 'Y' THEN
	-- CHG0041294
	l_miss_filed_name := 'transaction_temp_id';
          WHEN u.move_order_header_id IS NULL THEN
	l_miss_filed_name := 'move_order_header_id';
          ELSE
	NULL;
        END CASE;
      
        IF l_miss_filed_name IS NOT NULL THEN
        
          l_err_message := REPLACE('field ~FILED is Required',
		           '~FILED',
		           l_miss_filed_name);
          UPDATE xxinv_trx_pick_in t
          SET    t.err_message      = l_err_message,
	     t.status           = 'E',
	     t.last_update_date = SYSDATE,
	     t.last_updated_by  = l_user_id
          WHERE  t.trx_id = u.trx_id;
          COMMIT;
          message('ERROR_LOG_PRINT_1 for trx_id:' || u.trx_id ||
	      ' ,err_msg- ' || l_err_message); --INC0126962
        END IF;
      
        -- check pick from the correct subinventory
      
        IF u.subinventory != u.out_subinventory OR
           (nvl(u.locator_id, -1) != nvl(u.out_locator_id, -1) AND
           fnd_profile.value('XXINV_TPL_ALLOCATIONS') = 'Y') THEN
          --CHG0041294
          UPDATE xxinv_trx_pick_in t
          SET    t.err_message      = 'Pick from wrong subinventory/locator , expected subinventory=' ||
			  u.out_subinventory || ' locator_id=' ||
			  u.out_locator_id,
	     t.status           = 'E',
	     t.last_update_date = SYSDATE,
	     t.last_updated_by  = l_user_id
          WHERE  t.trx_id = u.trx_id;
          COMMIT;
          message('ERROR_LOG_PRINT_2 for trx_id:' || u.trx_id ||
	      ' ,err_msg-' ||
	      'Pick from wrong subinventory/locator , expected subinventory=' ||
	      u.out_subinventory || ' locator_id=' || u.out_locator_id ||
	      l_err_message); --INC0126962
        END IF;
      
        ------------------------------------------------------------------------------------------
        --  Additional validations added by Noam Yanai Mar-2014
      
        BEGIN
          SELECT wda.delivery_id
          INTO   l_current_delivery
          FROM   wsh_delivery_assignments wda
          WHERE  wda.delivery_detail_id = u.delivery_detail_id;
        EXCEPTION
          -- Added as part of CHG0043509 - XX INV TPL Interface Pick transaction - Delivery Detail ID Mandatory
          WHEN OTHERS THEN
	UPDATE xxinv_trx_pick_in t
	SET    t.err_message      = 'Unable to fetch Delivery_detail_id',
	       t.status           = 'E',
	       t.last_update_date = SYSDATE,
	       t.last_updated_by  = l_user_id
	WHERE  t.trx_id = u.trx_id;
	COMMIT;
        END;
      
        IF u.delivery_id != l_current_delivery THEN
        
          UPDATE xxinv_trx_pick_in t
          SET    t.err_message      = 'Delivery was changed !!  Expected delivery ' ||
			  u.delivery_id ||
			  '  but current delivery is ' ||
			  l_current_delivery,
	     t.status           = 'E',
	     t.last_update_date = SYSDATE,
	     t.last_updated_by  = l_user_id
          WHERE  t.trx_id = u.trx_id;
          COMMIT;
          message('ERROR_LOG_PRINT_3 for trx_id:' || u.trx_id ||
	      ' ,err_msg-' ||
	      'Delivery was changed !!  Expected delivery ' ||
	      u.delivery_id || '  but current delivery is ' ||
	      l_current_delivery || l_err_message); --INC0126962
        END IF;
        message('u.move_order_line_id: ' || u.move_order_line_id);
      
        -- yuval ???
        BEGIN
          SELECT trl.line_status
          INTO   l_mo_line_status
          FROM   mtl_txn_request_lines trl
          WHERE  trl.line_id = u.move_order_line_id;
        
        EXCEPTION
          WHEN OTHERS THEN
          
	UPDATE xxinv_trx_pick_in t
	SET    t.err_message      = 'Unable to fetch mtl_txn_request_lines.line_status for move_order_line_id=' ||
			    u.move_order_line_id,
	       t.status           = 'E',
	       t.last_update_date = SYSDATE,
	       t.last_updated_by  = l_user_id
	WHERE  t.trx_id = u.trx_id;
	COMMIT;
          
        END;
        ------------------------------------------------------------------------------------------
        -- yuval
      EXCEPTION
        WHEN OTHERS THEN
          l_sqlerrm := substr(SQLERRM, 1, 255);
          UPDATE xxinv_trx_pick_in t
          SET    t.err_message      = l_sqlerrm,
	     t.status           = 'E',
	     t.last_update_date = SYSDATE,
	     t.last_updated_by  = l_user_id
          WHERE  t.trx_id = u.trx_id;
          l_sqlerrm := NULL;
          COMMIT;
      END;
    
    END LOOP;
  
    /****************************************************
            Update TEMP tables by sended data
    ****************************************************/
    IF fnd_profile.value('XXINV_TPL_ALLOCATIONS') = 'Y' THEN
      --CHG0041294
      FOR u IN c_trx
      LOOP
        BEGIN
        
          -----
          SELECT decode(nvl(sib.lot_control_code, 1), 2, 'Y', 'N'), -- Added By Noam Yanai
	     decode(nvl(sib.serial_number_control_code, 1), 1, 'N', 'Y')
          INTO   l_is_lot_controlled,
	     l_is_serial_controlled
          FROM   mtl_system_items_b sib
          WHERE  sib.organization_id = l_organization_id
          AND    sib.inventory_item_id = u.inventory_item_id;
        
          l_revision := NULL; -- Added By Noam Yanai
          -------------------------------------------------------------------------- from here added by noam yanai AUG-2014 CHG0032515
        
          IF u.serial_number IS NOT NULL THEN
	IF is_lot_serial_the_same(u.out_serial, u.serial_number) = 'Y' THEN
	  -- added by noam yanai AUG-2014 CHG0032515
	  l_serial := u.out_serial;
	ELSE
	  SELECT nvl(MAX(sn.serial_number), u.serial_number)
	  INTO   l_serial
	  FROM   mtl_serial_numbers sn
	  WHERE  sn.inventory_item_id = u.inventory_item_id
	  AND    upper(sn.serial_number) = upper(u.serial_number);
	END IF;
          END IF;
        
          IF u.lot_number IS NOT NULL THEN
	IF is_lot_serial_the_same(u.out_lot, u.lot_number) = 'Y' THEN
	
	  -- added by noam yanai AUG-2014 CHG0032515
	  l_lot := u.out_lot;
	ELSE
	  SELECT nvl(MAX(ln.lot_number), u.lot_number)
	  INTO   l_lot
	  FROM   mtl_lot_numbers ln
	  WHERE  ln.organization_id = l_organization_id
	  AND    ln.inventory_item_id = u.inventory_item_id
	  AND    upper(ln.lot_number) = upper(u.lot_number);
	END IF;
          END IF;
          -------------------- to here added by noam yanai AUG-2014 CHG0032515
        
          IF is_revision_control(p_item_code       => u.item_code,
		         p_organization_id => l_organization_id) = 'Y' THEN
          
	-- l_revision :=
	get_revision(p_item_code       => u.item_code,
		 p_mode            => 1,
		 p_organization_id => l_organization_id,
		 p_revision        => l_revision,
		 p_err_message     => l_err_message,
		 p_subinv          => u.subinventory,
		 p_locator_id      => u.locator_id,
		 p_serial          => l_serial, -- changed by noam yanai AUG-2014 CHG0032515
		 p_lot_number      => l_lot); -- changed by noam yanai AUG-2014 CHG0032515
          
          END IF;
        
          IF l_is_lot_controlled = 'Y' AND l_is_serial_controlled = 'N' THEN
	-- Added By Noam Yanai
	BEGIN
	  -- CHECK LOT EXISTS (u.lot_number  is  null)
	  -- Item Lot Control , but lot number is missing
	  IF u.lot_number IS NULL THEN
	    l_err_message := 'Item is Lot Control , but lot number is missing';
	    RAISE l_my_exception;
	  END IF;
	
	  IF u.out_lot != l_lot THEN
	  
	    IF nvl(u.out_revision, '-77') = nvl(l_revision, '-77') THEN
	      -- update mtl_transaction_lots_temp in case of lot change
	      UPDATE mtl_transaction_lots_temp t
	      SET    t.lot_number       = l_lot,
		 t.origination_type = 3, -- Added By Noam Yanai
		 t.last_update_date = SYSDATE,
		 t.last_updated_by  = l_user_id
	      WHERE  t.rowid =
		 (SELECT lt.rowid
		  FROM   mtl_material_transactions_temp tt,
		         mtl_transaction_lots_temp      lt
		  WHERE  lt.transaction_temp_id =
		         tt.transaction_temp_id
		  AND    lt.lot_number = nvl(u.out_lot, '-77')
		  AND    lt.transaction_quantity = u.picked_quantity
		  AND    tt.transaction_temp_id = u.out_temp_id
		  AND    nvl(u.out_lot, '-77') != l_lot -- lot change
		  AND    rownum < 2);
	    
	      COMMIT;
	    
	      ------------------------------------- Added by Noam Yanai as part of bug fix CHG0032573
	      ------------------------------------- update ship_out so system will not send another task
	      UPDATE xxinv_trx_ship_out o
	      SET    o.lot_number      = l_lot,
		 o.orig_lot_number = u.out_lot
	      WHERE  o.line_id = u.line_id;
	    
	      COMMIT;
	      -------------------------------------
	      message('Lot: ' || u.out_lot || ' was replaced to lot: ' ||
		  l_lot || ' for item: ' || u.item_code || '.');
	      UPDATE xxinv_trx_pick_in t
	      SET    t.err_message      = 'Lot: ' || u.out_lot ||
			          ' was replaced to lot: ' ||
			          l_lot || '.',
		 t.last_update_date = SYSDATE,
		 t.last_updated_by  = l_user_id
	      WHERE  t.trx_id = u.trx_id;
	      COMMIT;
	    
	    ELSE
	      UPDATE xxinv_trx_pick_in t
	      SET    t.err_message      = 'Lot Change Failed ! Revision of new lot (' ||
			          l_lot ||
			          ') is different from revision of lot (' ||
			          u.out_lot || ') in the task.',
		 t.status           = 'E',
		 t.last_update_date = SYSDATE,
		 t.last_updated_by  = l_user_id
	      WHERE  t.move_order_line_id = u.move_order_line_id;
	    
	      COMMIT;
	      message('ERROR_LOG_PRINT_4 for trx_id:' || u.trx_id ||
		  ' ,err_msg-' ||
		  'Lot Change Failed ! Revision of new lot (' ||
		  l_lot || ') is different from revision of lot (' ||
		  u.out_lot || ') in the task.' || l_err_message); --INC0126962
	    END IF; --(nvl(u.out_revision, '-77') = nvl(l_revision, '-77'))
	  END IF; --(u.out_lot = l_lot)
	
	EXCEPTION
	  WHEN l_my_exception THEN
	  
	    UPDATE xxinv_trx_pick_in t
	    SET    t.err_message      = l_err_message,
	           t.status           = 'E',
	           t.last_update_date = SYSDATE,
	           t.last_updated_by  = l_user_id
	    WHERE  t.trx_id = u.trx_id;
	    COMMIT;
	    message('ERROR_LOG_PRINT_5 :' || 'Err msg: ' ||
		l_err_message || 'sqlerrm- ' || SQLERRM); --INC0126962
	  WHEN OTHERS THEN
	    --NULL;    --INC0126962
	    message('ERROR_LOG_PRINT_6 :' || 'Err msg: ' ||
		l_err_message || 'sqlerrm- ' || SQLERRM); --INC0126962
	END;
          
          ELSIF l_is_serial_controlled = 'Y' THEN
	BEGIN
	  -- check serial exists
	  -- id u.serial_number is null then
	  -- Item is serial control , but serial number is missing
	
	  IF u.serial_number IS NULL THEN
	    l_err_message := 'Item is serial control , but serial number is missing';
	    RAISE l_my_exception;
	  END IF;
	
	  IF u.out_serial != l_serial THEN
	  
	    IF nvl(u.out_revision, '-77') = nvl(l_revision, '-77') THEN
	    
	      UPDATE mtl_serial_numbers_temp st
	      SET    st.last_update_date = SYSDATE,
		 st.last_updated_by  = l_user_id,
		 st.fm_serial_number = l_serial,
		 st.to_serial_number = l_serial,
		 st.group_header_id = -- Added By Noam Yanai
		 (SELECT mtt.transaction_header_id
		  FROM   mtl_material_transactions_temp mtt
		  WHERE  mtt.transaction_temp_id =
		         u.transaction_temp_id)
	      WHERE  st.rowid =
		 (SELECT snt.rowid
		  FROM   mtl_serial_numbers_temp snt
		  WHERE  snt.transaction_temp_id = u.out_temp_id
		  AND    snt.fm_serial_number = u.out_serial);
	    
	      ------------------------------------- Added by Noam Yanai as part of bug fix CHG0032573
	      ------------------------------------- update ship_out so system will not send another task
	      COMMIT;
	    
	      UPDATE xxinv_trx_ship_out o
	      SET    o.serial_number      = l_serial,
		 o.orig_serial_number = u.out_serial
	      WHERE  o.line_id = u.line_id;
	    
	      ------------------------------------- This whole section was Added By Noam Yanai
	      COMMIT;
	    
	      -- update mtl_serial_numbers serial reservation
	      -- new serial ==> reserve
	      UPDATE mtl_serial_numbers msn
	      SET    msn.lot_line_mark_id = u.transaction_temp_id,
		 msn.line_mark_id     = u.transaction_temp_id,
		 msn.group_mark_id    = u.transaction_temp_id,
		 msn.last_update_date = SYSDATE,
		 msn.last_updated_by  = l_user_id
	      WHERE  msn.inventory_item_id = u.inventory_item_id
	      AND    msn.serial_number = l_serial;
	    
	      COMMIT;
	      -- original serial ==> unreserve
	      UPDATE mtl_serial_numbers msn
	      SET    msn.lot_line_mark_id = NULL,
		 msn.line_mark_id     = NULL,
		 msn.group_mark_id    = NULL,
		 msn.last_update_date = SYSDATE,
		 msn.last_updated_by  = l_user_id
	      WHERE  msn.inventory_item_id = u.inventory_item_id
	      AND    msn.serial_number = u.out_serial; -- Added by Noam Yanai as part of bug fix CHG0032573 changed  AUG-2014 CHG0032515
	    
	      ------------------------------------------------------  Until here Added By Noam Yanai
	      COMMIT;
	    
	      message('Serial: ' || u.out_serial ||
		  ' was replaced to serial: ' || l_serial ||
		  ' for item: ' || u.item_code || '.');
	      UPDATE xxinv_trx_pick_in t
	      SET    t.err_message = 'Serial: ' || u.out_serial ||
			     ' was replaced to serial: ' ||
			     l_serial || '.'
	      WHERE  t.trx_id = u.trx_id;
	      COMMIT;
	    
	    ELSE
	      UPDATE xxinv_trx_pick_in t
	      SET    t.err_message = 'Serial Change Failed ! Revision of new serial (' ||
			     l_serial ||
			     ') is different from revision of serial (' ||
			     u.out_serial ||
			     ') OR new serial and old serial are not in the same location',
		 t.status      = 'E'
	      WHERE  t.move_order_line_id = u.move_order_line_id;
	    
	      COMMIT;
	      message('ERROR_LOG_PRINT_7 :' ||
		  'Serial Change Failed ! Revision of new serial (' ||
		  l_serial ||
		  ') is different from revision of serial (' ||
		  u.out_serial ||
		  ') OR new serial and old serial are not in the same location' ||
		  'Err msg: ' || l_err_message || 'sqlerrm- ' ||
		  SQLERRM); --INC0126962
	    END IF;
	  END IF;
	EXCEPTION
	  WHEN l_my_exception THEN
	  
	    UPDATE xxinv_trx_pick_in t
	    SET    t.err_message = l_err_message,
	           t.status      = 'E'
	    WHERE  t.trx_id = u.trx_id;
	    COMMIT;
	    message('ERROR_LOG_PRINT_8 :' || 'Err msg: ' ||
		l_err_message || 'sqlerrm- ' || SQLERRM); --INC0126962
	  WHEN OTHERS THEN
	    --NULL;    --INC0126962
	    message('ERROR_LOG_PRINT_9 :' || 'Err msg: ' ||
		l_err_message || 'sqlerrm- ' || SQLERRM); --INC0126962
	END;
          END IF;
        EXCEPTION
          WHEN OTHERS THEN
	l_sqlerrm := substr(SQLERRM, 1, 255);
	UPDATE xxinv_trx_pick_in t
	SET    t.err_message      = l_err_message || ' ' || l_sqlerrm,
	       t.status           = 'E',
	       t.last_update_date = SYSDATE,
	       t.last_updated_by  = l_user_id
	WHERE  t.trx_id = u.trx_id;
	message('ERROR_LOG_PRINT_10 :' || 'Err msg: ' || l_err_message ||
	        'sqlerrm- ' || SQLERRM); --INC0126962
	COMMIT;
        END;
      END LOOP;
    END IF;
  
    -----------------------------------------
    --- NO Allocation special process activity
    --  in case of no allocation we will need to do the folowing
    --  1. Create Reservation-
    --     For multiple lines having same line ids, do reservation one by
    --     one for all the line ids before proceeding to allocation process
    --  2. Allocate-
    --     For multiple lines having same line ids, do allocation at one go
    --     for the whole batch.
    --  3. create delivery  : update delivery id
    --  4. assign delivery detail  to delivery
    -------------------------------------------
  
    IF fnd_profile.value('XXINV_TPL_ALLOCATIONS') = 'N' THEN
      --CHG0041294
      FOR i IN c_trx
      LOOP
        BEGIN
          l_err_message := NULL;
          message('working on ------>i.trx_id=' || i.trx_id);
          message('Creating Reservation Start');
          -------------------------------------
          /*Create reservation*/ -- CHG0041294
          -------------------------------------
        
          --searching, if multiple lines are present for same line_id
          SELECT COUNT(1),
	     SUM(picked_quantity)
          INTO   l_cnt,
	     tot_picked_qty
          FROM   xxinv_trx_pick_in t
          WHERE  t.source_code = p_user_name -- 'TPL'
          AND    t.status = 'N'
          AND    t.line_id = i.line_id;
        
          message('l_cnt :' || l_cnt);
          message('tot_picked_qty :' || tot_picked_qty);
        
          /* CHG0041294 - For single line_id lines */
          IF l_cnt = 1 THEN
          
	/*fetching order source id*/ -- CHG0041294
	OPEN c_get_ord_source(i.order_number);
	FETCH c_get_ord_source
	  INTO l_ord_source_id;
	CLOSE c_get_ord_source;
          
	message('order source id:' || l_ord_source_id);
          
	IF l_ord_source_id = 10 THEN
	  l_ord_source_id := 8;
	ELSE
	  l_ord_source_id := 2;
	END IF;
	message('Final order source id:' || l_ord_source_id);
          
	OPEN c_sal_ord_id(i.order_number);
	FETCH c_sal_ord_id
	  INTO l_sal_ord_id;
	CLOSE c_sal_ord_id;
	message('l_sal_ord_id:' || l_sal_ord_id);
          
	OPEN c_demand_source_line_id(i.line_id);
	FETCH c_demand_source_line_id
	  INTO l_demand_source_line_id;
	CLOSE c_demand_source_line_id;
          
	/*Fetching correct line_id for split lines*/ -- CHG0042788
	BEGIN
	  SELECT flow_status_code,
	         header_id
	  INTO   l_flow_status_code,
	         l_header_id
	  FROM   oe_order_lines_all
	  WHERE  line_id = l_demand_source_line_id;
	
	  IF l_flow_status_code = 'CLOSED' THEN
	    SELECT MIN(line_id)
	    INTO   l_demand_source_line_id
	    FROM   oe_order_lines_all
	    WHERE  split_from_line_id = l_demand_source_line_id
	    AND    header_id = l_header_id;
	  END IF;
	EXCEPTION
	  WHEN OTHERS THEN
	    l_err_message := 'Error in fetching demand_source_line_id for split lines, passed as paramter, to Reservation API';
	    RAISE l_my_exception;
	END;
	message('l_demand_source_line_id:' || l_demand_source_line_id);
          
	l_rsv_rec := NULL;
	l_serial_number.delete;
	/*Setting paramters*/ --CHG0041294
	l_rsv_rec.requirement_date             := SYSDATE;
	l_rsv_rec.organization_id              := l_organization_id; -- SOURCE_CODE
	l_rsv_rec.inventory_item_id            := i.inventory_item_id; --XXINV_TRX_PICK_IN.INVENTORY_ITEM_ID
	l_rsv_rec.demand_source_type_id        := l_ord_source_id; -- Case (select order_source_id from oe_order_headers_all o where o.order_number=XXINV_TRX_PICK_IN.ORDER_NUMBER)=10, put 8 , Else 2.
	l_rsv_rec.demand_source_header_id      := l_sal_ord_id; --17694909;--select m.sales_order_id from apps.MTL_SALES_ORDERS_KFV m where m.segment1 = XXINV_TRX_PICK_IN.ORDER_NUMBER
	l_rsv_rec.demand_source_line_id        := l_demand_source_line_id; --select l.line_id from oe_order_headers_all h, oe_order_lines_all l where h.header_id=l.header_id and h.order_number= XXINV_TRX_PICK_IN.ORDER_NUMBER and l.line_number= XXINV_TRX_PICK_IN.ORDER_LINE_NUMBER
	l_rsv_rec.reservation_quantity         := i.picked_quantity; --XXINV_TRX_PICK_IN.PICKED_QUANTITY
	l_rsv_rec.primary_reservation_quantity := i.picked_quantity; --XXINV_TRX_PICK_IN.PICKED_QUANTITY
	l_rsv_rec.supply_source_type_id        := 13; --Hard Coded
          
	l_rsv_rec.subinventory_code := i.subinventory; --'1032'; --XXINV_TRX_PICK_IN.SUBINVENTORY
          
	l_rsv_rec.locator_id := i.locator_id; --82334; --XXINV_TRX_PICK_IN.LOCATOR_ID
	/*Populating attributes for serial control items*/
	IF i.serial_number IS NOT NULL THEN
	  OPEN c_revision(i.serial_number, i.inventory_item_id);
	  FETCH c_revision
	    INTO l_rev;
	  CLOSE c_revision;
	  message('l_rev:' || l_rev);
	
	  l_rsv_rec.revision := l_rev; -- 'E2'; --select msn.revision from mtl_serial_numbers msn where msn.serial_number=XXINV_TRX_PICK_IN.SERIAL_NUMBER and msn.inventory_item_id=XXINV_TRX_PICK_IN.INVENTORY_ITEM_ID
	  l_serial_number(1).inventory_item_id := i.inventory_item_id; --14277; --XXINV_TRX_PICK_IN.INVENTORY_ITEM_ID.  -- Only if XXINV_TRX_PICK_IN.SERIAL_NUMBER is not null
	  l_serial_number(1).serial_number := i.serial_number; --'W1730962'; --XXINV_TRX_PICK_IN.SERIAL_NUMBER
	  message('For serial control item l_rsv_rec.revision :' ||
	          l_rsv_rec.revision); -- 'E2'; --select msn.revision from mtl_serial_numbers msn where msn.serial_number=XXINV_TRX_PICK_IN.SERIAL_NUMBER and msn.inventory_item_id=XXINV_TRX_PICK_IN.INVENTORY_ITEM_ID
	END IF;
          
	IF i.lot_number IS NOT NULL THEN
	  message('l_rsv_rec.lot_number :' || l_rsv_rec.lot_number);
	  l_rsv_rec.lot_number := i.lot_number; --'1225'; --XXINV_TRX_PICK_IN.LOT_NUMBER
	  message('For lot control item l_rsv_rec.revision :' ||
	          l_rsv_rec.revision); -- 'E2'; --select msn.revision from mtl_serial_numbers msn where msn.serial_number=XXINV_TRX_PICK_IN.SERIAL_NUMBER and msn.inventory_item_id=XXINV_TRX_PICK_IN.INVENTORY_ITEM_ID
	END IF;
          
	/* R12 Enhanced reservations code changes */
	l_rsv_rec.crossdock_flag    := '';
	l_rsv_rec.detailed_quantity := 0;
          
	IF (i.serial_number IS NULL) AND (i.lot_number IS NULL) THEN
	  l_avlbl_to_reserve_qty := 0;
	  l_flag                 := 0;
	  FOR j IN c_revsn(i.inventory_item_id,
		       l_organization_id,
		       i.subinventory,
		       i.locator_id)
	  LOOP
	    IF l_flag = 0 THEN
	      SELECT l_avlbl_to_reserve_qty +
		 xxinv_utils_pkg.get_avail_to_reserve(i.inventory_item_id,
					  l_organization_id,
					  i.subinventory,
					  i.locator_id,
					  NULL,
					  j.revision)
	      INTO   l_avlbl_to_reserve_qty
	      FROM   dual;
	    END IF;
	  
	    IF l_avlbl_to_reserve_qty >= i.picked_quantity THEN
	      l_rsv_rec.revision := j.revision;
	      l_flag             := 1;
	    END IF;
	  
	  END LOOP;
	  IF l_avlbl_to_reserve_qty < i.picked_quantity THEN
	    message('Not enough quantity available to be reserved.');
	    message('Available_to_reserve_qty: ' ||
		l_avlbl_to_reserve_qty);
	    message('Qty to be reserved: ' || i.picked_quantity);
	    message('Hence reserving available quantity');
	  
	    l_rsv_rec.reservation_quantity         := l_avlbl_to_reserve_qty;
	    l_rsv_rec.primary_reservation_quantity := l_avlbl_to_reserve_qty;
	  END IF;
	  message('For non_serial or non lot control l_rsv_rec.revision :' ||
	          l_rsv_rec.revision);
	END IF;
          
	message('l_rsv_rec.organization_id :' ||
	        l_rsv_rec.organization_id); -- SOURCE_CODE
	message('l_rsv_rec.inventory_item_id :' ||
	        l_rsv_rec.inventory_item_id); --XXINV_TRX_PICK_IN.INVENTORY_ITEM_ID
	message('l_rsv_rec.demand_source_type_id:' ||
	        l_rsv_rec.demand_source_type_id); -- Case (select order_source_id from oe_order_headers_all o where o.order_number=XXINV_TRX_PICK_IN.ORDER_NUMBER)=10, put 8 , Else 2.
	message('l_rsv_rec.demand_source_header_id:' ||
	        l_rsv_rec.demand_source_header_id); --17694909;--select m.sales_order_id from apps.MTL_SALES_ORDERS_KFV m where m.segment1 = XXINV_TRX_PICK_IN.ORDER_NUMBER
	message('l_rsv_rec.demand_source_line_id :' ||
	        l_rsv_rec.demand_source_line_id); --XXINV_TRX_PICK_IN.LINE_ID
	message('l_rsv_rec.reservation_quantity :' ||
	        l_rsv_rec.reservation_quantity); --XXINV_TRX_PICK_IN.PICKED_QUANTITY
	message('l_rsv_rec.primary_reservation_quantity :' ||
	        l_rsv_rec.primary_reservation_quantity);
	message('l_rsv_rec.subinventory_code :' ||
	        l_rsv_rec.subinventory_code); --'1032'; --XXINV_TRX_PICK_IN.SUBINVENTORY
	message('l_rsv_rec.locator_id :' || l_rsv_rec.locator_id);
	IF i.serial_number IS NOT NULL THEN
	  message('l_serial_number(1).inventory_item_id :' || l_serial_number(1)
	          .inventory_item_id); --14277; --XXINV_TRX_PICK_IN.INVENTORY_ITEM_ID.  -- Only if XXINV_TRX_PICK_IN.SERIAL_NUMBER is not null
	  message('l_serial_number(1).serial_number     :' || l_serial_number(1)
	          .serial_number);
	END IF;
          
	message('Creating Reservation');
	/*Calling API to Create Reservation*/
	inv_reservation_pub.create_reservation(p_api_version_number       => 1.0,
				   p_init_msg_lst             => fnd_api.g_true,
				   x_return_status            => l_return_status,
				   x_msg_count                => l_msg_count,
				   x_msg_data                 => l_msg_data,
				   p_rsv_rec                  => l_rsv_rec,
				   p_serial_number            => l_serial_number,
				   x_serial_number            => v_serial_number,
				   p_partial_reservation_flag => fnd_api.g_false,
				   p_force_reservation_flag   => fnd_api.g_false,
				   p_validation_flag          => fnd_api.g_true,
				   p_over_reservation_flag    => 0,
				   x_quantity_reserved        => v_quantity_reserved,
				   x_reservation_id           => v_reservation_id,
				   p_partial_rsv_exists       => FALSE);
          
	message('x_quantity_reserved ' || v_quantity_reserved);
	message('x_return_status ' || l_return_status);
	message('x_reservation_id ' || v_reservation_id);
          
	message('------>' || fnd_message.get);
	IF l_return_status <> 'S' THEN
	  message('l_return_status: ' || l_return_status ||
	          ' l_msg_count :' || l_msg_count || ' l_msg_data: ' ||
	          fnd_message.get);
	
	  FOR j IN 1 .. l_msg_count
	  LOOP
	    l_message := fnd_msg_pub.get(j, 'F');
	    message(substr(l_message, 1, 255));
	  END LOOP;
	  --COMMIT;
	
	  l_err_message := l_message || ' ' || fnd_message.get;
	  RAISE l_my_exception;
	ELSE
	  UPDATE xxinv_trx_pick_in t
	  SET    t.commercial_request_id = v_reservation_id,
	         
	         --t.err_message      = Reservation done, --CHG0041294
	         t.last_update_date = SYSDATE,
	         t.last_updated_by  = fnd_global.user_id
	  WHERE  t.trx_id = i.trx_id;
	
	  COMMIT;
	END IF;
          
	-------------------------------------------
	/*Create Allocation */ -- CHG0041294
	-- create_allocation procedure will
	-- internally call API to create allocations
	-------------------------------------------
	message('Calling create allocation');
	create_allocation(i.move_order_no,
		      i.move_order_line_no,
		      i.move_order_line_id,
		      i.picked_quantity,
		      v_reservation_id,
		      l_organization_id,
		      l_errbuf,
		      l_retcode);
          
	IF l_retcode != 0 THEN
	  l_err_message := l_errbuf;
	  RAISE l_my_exception;
	END IF;
          
	/* CHG0041294 - For line ids having multi-lines */
          ELSIF (l_cnt > 1) THEN
          
	-- Final total picked_quantity for the multiple lines of same line_id
	v_reservation_id := 0;
	-- do batch reservation for multiple lines having same line_id
	message('In batch reservation loop for multiple lines having line_id:' ||
	        i.line_id);
	FOR k IN c_reserve_batch(i.line_id)
	LOOP
	  l_delivery_date := NULL;
	  /*fetching order source id*/ -- CHG0041294
	  OPEN c_get_ord_source(k.order_number);
	  FETCH c_get_ord_source
	    INTO l_ord_source_id;
	  CLOSE c_get_ord_source;
	
	  message('order source id:' || l_ord_source_id);
	
	  IF l_ord_source_id = 10 THEN
	    l_ord_source_id := 8;
	  ELSE
	    l_ord_source_id := 2;
	  END IF;
	  message('Final order source id:' || l_ord_source_id);
	
	  OPEN c_sal_ord_id(k.order_number);
	  FETCH c_sal_ord_id
	    INTO l_sal_ord_id;
	  CLOSE c_sal_ord_id;
	  message('l_sal_ord_id:' || l_sal_ord_id);
	
	  OPEN c_demand_source_line_id(i.line_id);
	  FETCH c_demand_source_line_id
	    INTO l_demand_source_line_id;
	  CLOSE c_demand_source_line_id;
	
	  /*Fetching correct line_id for split lines*/ -- CHG0042788
	  BEGIN
	    SELECT flow_status_code,
	           header_id
	    INTO   l_flow_status_code,
	           l_header_id
	    FROM   oe_order_lines_all
	    WHERE  line_id = l_demand_source_line_id;
	  
	    IF l_flow_status_code = 'CLOSED' THEN
	      SELECT MIN(line_id)
	      INTO   l_demand_source_line_id
	      FROM   oe_order_lines_all
	      WHERE  split_from_line_id = l_demand_source_line_id
	      AND    header_id = l_header_id;
	    END IF;
	  EXCEPTION
	    WHEN OTHERS THEN
	      l_err_message := 'Error in fetching demand_source_line_id for split lines, passed as paramter, to Reservation API';
	      RAISE l_my_exception;
	    
	  END;
	  message('l_demand_source_line_id:' ||
	          l_demand_source_line_id);
	
	  l_rsv_rec := NULL;
	  l_serial_number.delete;
	  /*Setting paramters*/ --CHG0041294
	  l_rsv_rec.requirement_date             := SYSDATE;
	  l_rsv_rec.organization_id              := l_organization_id; -- SOURCE_CODE
	  l_rsv_rec.inventory_item_id            := k.inventory_item_id; --XXINV_TRX_PICK_IN.INVENTORY_ITEM_ID
	  l_rsv_rec.demand_source_type_id        := l_ord_source_id; -- Case (select order_source_id from oe_order_headers_all o where o.order_number=XXINV_TRX_PICK_IN.ORDER_NUMBER)=10, put 8 , Else 2.
	  l_rsv_rec.demand_source_header_id      := l_sal_ord_id; --17694909;--select m.sales_order_id from apps.MTL_SALES_ORDERS_KFV m where m.segment1 = XXINV_TRX_PICK_IN.ORDER_NUMBER
	  l_rsv_rec.demand_source_line_id        := l_demand_source_line_id; --select l.line_id from oe_order_headers_all h, oe_order_lines_all l where h.header_id=l.header_id and h.order_number= XXINV_TRX_PICK_IN.ORDER_NUMBER and l.line_number= XXINV_TRX_PICK_IN.ORDER_LINE_NUMBER
	  l_rsv_rec.reservation_quantity         := k.picked_quantity; --XXINV_TRX_PICK_IN.PICKED_QUANTITY
	  l_rsv_rec.primary_reservation_quantity := k.picked_quantity; --XXINV_TRX_PICK_IN.PICKED_QUANTITY
	  l_rsv_rec.supply_source_type_id        := 13; --Hard Coded
	  l_rsv_rec.subinventory_code            := k.subinventory; --'1032'; --XXINV_TRX_PICK_IN.SUBINVENTORY
	  l_rsv_rec.locator_id                   := k.locator_id; --82334; --XXINV_TRX_PICK_IN.LOCATOR_ID
	  /*Populating attributes for serial control items*/
	  IF k.serial_number IS NOT NULL THEN
	    message('************A serial control item**************');
	    OPEN c_revision(k.serial_number, k.inventory_item_id);
	    FETCH c_revision
	      INTO l_rev;
	    CLOSE c_revision;
	    message('l_rev:' || l_rev);
	    l_rsv_rec.revision := l_rev; -- 'E2'; --select msn.revision from mtl_serial_numbers msn where msn.serial_number=XXINV_TRX_PICK_IN.SERIAL_NUMBER and msn.inventory_item_id=XXINV_TRX_PICK_IN.INVENTORY_ITEM_ID
	    message('For serial control l_rsv_rec.revision :' ||
		l_rsv_rec.revision);
	    l_serial_number(1).inventory_item_id := k.inventory_item_id; --14277; --XXINV_TRX_PICK_IN.INVENTORY_ITEM_ID.  -- Only if XXINV_TRX_PICK_IN.SERIAL_NUMBER is not null
	    l_serial_number(1).serial_number := k.serial_number; --'W1730962'; --XXINV_TRX_PICK_IN.SERIAL_NUMBER
	    BEGIN
	      SELECT mrav.requirement_date + (1 / 1440 * 2)
	      INTO   l_delivery_date
	      FROM   mtl_reservations_all_v mrav
	      WHERE  mrav.reservation_id = v_reservation_id;
	    
	      l_rsv_rec.requirement_date := l_delivery_date; -- passing need-by-date for serial item
	    EXCEPTION
	      WHEN no_data_found THEN
	        message('This is the first record in multiple lines batch having line id ' ||
		    i.line_id);
	      WHEN OTHERS THEN
	        message('Error in fetching need-by-date of previous line reservation');
	    END;
	  END IF;
	
	  IF k.lot_number IS NOT NULL THEN
	    message('************A lot control item**************');
	    l_rsv_rec.lot_number := k.lot_number; --'1225'; --XXINV_TRX_PICK_IN.LOT_NUMBER
	    message('l_rsv_rec.lot_number :' || l_rsv_rec.lot_number);
	    message('For lot control l_rsv_rec.revision :' ||
		l_rsv_rec.revision);
	  END IF;
	  /* R12 Enhanced reservations code changes */
	  l_rsv_rec.crossdock_flag    := '';
	  l_rsv_rec.detailed_quantity := 0;
	
	  IF (k.serial_number IS NULL) AND (k.lot_number IS NULL) THEN
	    message('************A non-serial, non-lot control item**************');
	    l_avlbl_to_reserve_qty := 0;
	    l_flag                 := 0;
	    FOR jr IN c_revsn(k.inventory_item_id,
		          l_organization_id,
		          k.subinventory,
		          k.locator_id)
	    LOOP
	      IF l_flag = 0 THEN
	        SELECT l_avlbl_to_reserve_qty +
		   xxinv_utils_pkg.get_avail_to_reserve(k.inventory_item_id,
					    l_organization_id,
					    k.subinventory,
					    k.locator_id,
					    NULL,
					    jr.revision)
	        INTO   l_avlbl_to_reserve_qty
	        FROM   dual;
	      END IF;
	    
	      IF l_avlbl_to_reserve_qty >= k.picked_quantity THEN
	        l_rsv_rec.revision := jr.revision;
	        l_flag             := 1;
	      END IF;
	    
	    END LOOP;
	    IF l_avlbl_to_reserve_qty < k.picked_quantity THEN
	      message('Not enough quantity available to be reserved.');
	      message('Available_to_reserve_qty: ' ||
		  l_avlbl_to_reserve_qty);
	      message('Qty to be reserved: ' || k.picked_quantity);
	      message('Hence reserving available quantity');
	    
	      l_rsv_rec.reservation_quantity         := l_avlbl_to_reserve_qty;
	      l_rsv_rec.primary_reservation_quantity := l_avlbl_to_reserve_qty;
	    END IF;
	    message('For non_serial or non lot control l_rsv_rec.revision :' ||
		l_rsv_rec.revision);
	  END IF;
	
	  message('l_rsv_rec.organization_id :' ||
	          l_rsv_rec.organization_id); -- SOURCE_CODE
	  message('l_rsv_rec.inventory_item_id :' ||
	          l_rsv_rec.inventory_item_id); --XXINV_TRX_PICK_IN.INVENTORY_ITEM_ID
	  message('l_rsv_rec.demand_source_type_id:' ||
	          l_rsv_rec.demand_source_type_id); -- Case (select order_source_id from oe_order_headers_all o where o.order_number=XXINV_TRX_PICK_IN.ORDER_NUMBER)=10, put 8 , Else 2.
	  message('l_rsv_rec.demand_source_header_id:' ||
	          l_rsv_rec.demand_source_header_id); --17694909;--select m.sales_order_id from apps.MTL_SALES_ORDERS_KFV m where m.segment1 = XXINV_TRX_PICK_IN.ORDER_NUMBER
	  message('l_rsv_rec.demand_source_line_id :' ||
	          l_rsv_rec.demand_source_line_id); --XXINV_TRX_PICK_IN.LINE_ID
	  message('l_rsv_rec.reservation_quantity :' ||
	          l_rsv_rec.reservation_quantity); --XXINV_TRX_PICK_IN.PICKED_QUANTITY
	  message('l_rsv_rec.primary_reservation_quantity :' ||
	          l_rsv_rec.primary_reservation_quantity);
	  message('l_rsv_rec.subinventory_code :' ||
	          l_rsv_rec.subinventory_code); --'1032'; --XXINV_TRX_PICK_IN.SUBINVENTORY
	  message('l_rsv_rec.locator_id :' || l_rsv_rec.locator_id);
	  IF k.serial_number IS NOT NULL THEN
	    message('l_serial_number(1).inventory_item_id :' || l_serial_number(1)
		.inventory_item_id); --14277; --XXINV_TRX_PICK_IN.INVENTORY_ITEM_ID.  -- Only if XXINV_TRX_PICK_IN.SERIAL_NUMBER is not null
	    message('l_serial_number(1).serial_number     :' || l_serial_number(1)
		.serial_number);
	  END IF;
	  message('l_rsv_rec.requirement_date:' ||
	          l_rsv_rec.requirement_date);
	
	  message('Creating Reservation');
	  /*Calling API to Create Reservation*/
	  inv_reservation_pub.create_reservation(p_api_version_number       => 1.0,
				     p_init_msg_lst             => fnd_api.g_true,
				     x_return_status            => l_return_status,
				     x_msg_count                => l_msg_count,
				     x_msg_data                 => l_msg_data,
				     p_rsv_rec                  => l_rsv_rec,
				     p_serial_number            => l_serial_number,
				     x_serial_number            => v_serial_number,
				     p_partial_reservation_flag => fnd_api.g_false,
				     p_force_reservation_flag   => fnd_api.g_false,
				     p_validation_flag          => fnd_api.g_true,
				     p_over_reservation_flag    => 0,
				     x_quantity_reserved        => v_quantity_reserved,
				     x_reservation_id           => v_reservation_id,
				     p_partial_rsv_exists       => FALSE);
	
	  message('x_quantity_reserved ' || v_quantity_reserved);
	  message('x_return_status ' || l_return_status);
	  message('x_reservation_id ' || v_reservation_id);
	
	  message('------>' || fnd_message.get);
	  IF l_return_status <> 'S' THEN
	    message('l_return_status: ' || l_return_status ||
		' l_msg_count :' || l_msg_count || ' l_msg_data: ' ||
		fnd_message.get);
	  
	    FOR j IN 1 .. l_msg_count
	    LOOP
	      l_message := fnd_msg_pub.get(j, 'F');
	      message(substr(l_message, 1, 255));
	    END LOOP;
	    --COMMIT;
	  
	    l_err_message := l_message || ' ' || fnd_message.get;
	    RAISE l_my_exception;
	  ELSE
	    UPDATE xxinv_trx_pick_in t
	    SET    t.status              = 'R',
	           commercial_request_id = v_reservation_id,
	           --t.err_message      = Reservation done, --CHG0041294
	           t.last_update_date = SYSDATE,
	           t.last_updated_by  = fnd_global.user_id
	    WHERE  t.trx_id = k.trx_id;
	  
	    COMMIT;
	  END IF;
	
	END LOOP;
          
	-------------------------------------------
	/*Create Allocation */ -- CHG0041294
	-- create_allocation procedure will
	-- internally call API to create allocations
	-------------------------------------------
	message('Calling create allocation');
	create_allocation(i.move_order_no,
		      i.move_order_line_no,
		      i.move_order_line_id,
		      tot_picked_qty,
		      v_reservation_id,
		      l_organization_id,
		      l_errbuf,
		      l_retcode);
          
	IF l_retcode != 0 THEN
	  l_err_message := l_errbuf;
	  RAISE l_my_exception;
	END IF;
          
          ELSE
	message('Reservation and allocation already done for this order line having line_id: ' ||
	        i.line_id);
          
          END IF; -- End of <IF l_cnt = 1>
        
          FOR m IN c_extra_molines(i.move_order_line_id, i.line_id)
          LOOP
	-- Delete Allocation for extra lines of the Move Order
	inv_replenish_detail_pub.delete_details(p_transaction_temp_id  => m.transaction_temp_id --transaction_temp_id
				   ,
				    p_move_order_line_id   => m.move_order_line_id --move_order_line_id
				   ,
				    p_reservation_id       => m.reservation_id,
				    p_transaction_quantity => m.transaction_quantity,
				    p_primary_trx_qty      => m.primary_quantity,
				    x_return_status        => x_return_status,
				    x_msg_count            => x_msg_count,
				    x_msg_data             => x_msg_data);
          
	message('return status for extra Allocation delete API:' ||
	        x_return_status);
	message(x_msg_data);
	message(x_msg_count);
	message(fnd_message.get);
	IF (x_return_status <> fnd_api.g_ret_sts_success) THEN
	  message('Extra line deletion succesful');
	ELSE
	  message('Extra line deleted having TRANSACTION_TEMP_ID' ||
	          m.transaction_temp_id);
	END IF;
          END LOOP;
        
          /*Create Delivery */
          l_delivery_id := NULL;
        
          -- check delivery exists (by name )
          l_delivery_id := get_delivery_id(i.delivery_name);
        
          -- if delivery doesnt exists then
          IF l_delivery_id IS NULL THEN
          
	create_delivery(i.delivery_name,
		    i.delivery_detail_id,
		    l_out_delivery_id,
		    l_errbuf,
		    l_retcode);
	message('ERROR_LOG_PRINT - Calling create_delivery for no del_id having delivery_name: ' ||
	        i.delivery_name || '.In case of error- ' || SQLERRM); --INC0126962
	IF l_retcode = 0 THEN
	
	  UPDATE xxinv_trx_pick_in t
	  SET    t.delivery_id      = l_out_delivery_id,
	         t.err_message      = NULL, --CHG0041294
	         t.last_update_date = SYSDATE,
	         t.last_updated_by  = fnd_global.user_id
	  WHERE  t.trx_id = i.trx_id;
	  COMMIT;
	  message('ERROR_LOG_PRINT - updation of new del_id: ' ||
	          l_out_delivery_id); --INC0126962
	ELSE
	  l_err_message := l_errbuf;
	  -- CHG0046955 start
	  -- Updating error message in staging table when delivery number creation fails..
	  UPDATE xxinv_trx_pick_in t
	  SET    t.status           = 'E',
	         t.err_message      = 'Delivery id is not created successfully',
	         t.last_update_date = SYSDATE,
	         t.last_updated_by  = fnd_global.user_id
	  WHERE  t.trx_id = i.trx_id;
	  COMMIT;
	  message('ERROR_LOG_PRINT - error in calling create_delivery. ' ||
	          'Err msg: ' || l_err_message);
	  -- CHG0046955 end
	  RAISE l_my_exception;
	END IF;
          
          ELSE
	/* updating delivery_id in table for existing delivery name */
	UPDATE xxinv_trx_pick_in t
	SET    t.delivery_id      = l_delivery_id,
	       t.err_message      = NULL, --CHG0041294
	       t.last_update_date = SYSDATE,
	       t.last_updated_by  = fnd_global.user_id
	WHERE  t.trx_id = i.trx_id;
	COMMIT;
	message('ERROR_LOG_PRINT - updated delivery_id in table for existing delivery name.'); --INC0126962
          END IF;
        
          -- CHG0041294 - check delivery assignment exists
          BEGIN
	SELECT 1
	INTO   l_del_flag
	FROM   wsh_delivery_assignments wda
	WHERE  wda.delivery_detail_id = i.delivery_detail_id --19889322 -pick_in
	AND    wda.delivery_id = nvl(l_delivery_id, l_out_delivery_id); --6566604 pick_in
          EXCEPTION
	WHEN OTHERS THEN
	  l_del_flag := 0;
          END;
        
          IF l_del_flag < 1 THEN
	-- CHG0041294 - add delivery detail to exist delivery
	-- CHG0041294 - Assign  delivery_detail_id to delivery_name
          
	assign_delivery_detail(p_delivery_name      => i.delivery_name,
		           p_delivery_detail_id => i.delivery_detail_id,
		           p_delivery_id        => nvl(l_delivery_id,
					   l_out_delivery_id),
		           p_errbuf             => l_errbuf,
		           p_retcode            => l_retcode);
          
	IF l_retcode != 0 THEN
	  l_err_message := l_errbuf;
	  RAISE l_my_exception;
	
	END IF;
          
          ELSE
	message('Delivery line is already assigned to delivery');
          END IF;
        
          /*
          find all intangible item for header_id  which not assign to any delivery
          all intangible item  found assign to  delivery
          
          system will have to assign also intangible items from the same order,
          which were not included in the pick message,
          but still not assigned to any other delivery.
          */
          --CHG0041294
        
          DECLARE
          
	CURSOR c_intangible IS
	
	  SELECT w.inventory_item_id,
	         w.source_name,
	         w.delivery_id,
	         w.source_header_id,
	         w.source_header_number,
	         w.organization_id,
	         w.ship_from_location_id,
	         w.ship_to_location_id,
	         w.ship_method_code,
	         w.freight_terms_code,
	         w.intmed_ship_to_location_id,
	         w. delivery_detail_id
	  FROM   wsh_deliverables_v w,
	         mtl_system_items_b mtl
	  WHERE  source_header_number = i.
	   order_number
	  AND    nvl(mtl.stock_enabled_flag, 'Y') = 'N'
	  AND    mtl.organization_id = l_organization_id
	  AND    mtl.inventory_item_id = w.inventory_item_id
	  AND    source_name = 'Order Management'
	  AND    w.delivery_id IS NULL;
          
          BEGIN
	FOR intangible IN c_intangible
	LOOP
	
	  assign_delivery_detail(p_delivery_name      => i.delivery_name,
			 p_delivery_detail_id => intangible.delivery_detail_id,
			 p_delivery_id        => nvl(l_delivery_id,
					     l_out_delivery_id),
			 p_errbuf             => l_errbuf,
			 p_retcode            => l_retcode);
	
	  -- handle failure
	  IF l_retcode != 0 THEN
	    l_err_message := l_errbuf;
	    RAISE l_my_exception;
	  
	  END IF;
	
	END LOOP;
          EXCEPTION
	WHEN l_my_exception THEN
	  ROLLBACK;
	  -- update status
	  UPDATE xxinv_trx_pick_in t
	  SET    t.err_message = 'intangible process assignment failure ' ||
			 l_err_message,
	         t.status      = 'E'
	  WHERE  t.trx_id = i.trx_id;
	  COMMIT;
	  message('ERROR_LOG_PRINT_11 :' ||
	          'intangible process assignment failure ' ||
	          'Err msg: ' || l_err_message || 'sqlerrm- ' ||
	          SQLERRM); --INC0126962
          END;
        
          ---- end of intangible process
        EXCEPTION
          WHEN l_my_exception THEN
          
	UPDATE xxinv_trx_pick_in t
	SET    t.err_message      = l_err_message,
	       t.status           = 'E',
	       t.last_update_date = SYSDATE,
	       t.last_updated_by  = l_user_id
	WHERE  t.trx_id = i.trx_id;
          
	message('------>i.trx_id=' || i.trx_id);
	COMMIT;
	message('ERROR_LOG_PRINT_12 :' || 'Err msg: ' || l_err_message ||
	        'sqlerrm- ' || SQLERRM); --INC0126962
          WHEN OTHERS THEN
	l_sqlerrm := substr(SQLERRM, 1, 255);
	UPDATE xxinv_trx_pick_in t
	SET    t.err_message      = l_err_message || l_sqlerrm,
	       t.status           = 'E',
	       t.last_update_date = SYSDATE,
	       t.last_updated_by  = l_user_id
	WHERE  t.trx_id = i.trx_id;
	COMMIT;
	message('ERROR_LOG_PRINT_13 :' || 'Err msg: ' || l_err_message ||
	        'sqlerrm- ' || SQLERRM); --INC0126962
        END;
      END LOOP;
    
      ----------------------------
    
    END IF;
  
    --***********************Start Picking Process*********************
    FOR i IN c_pick_batch
    LOOP
      BEGIN
        FOR j IN c_mo_details(i.move_order_header_id)
        LOOP
          l_mo_details := j;
          message('move_order_type=' || l_mo_details.move_order_type);
        END LOOP;
      
        IF flag = 0 THEN
          ti   := i.trx_id; -- CHG0041294 - Capturing first transaction id for picking process
          flag := 1;
        END IF;
        l_trolin_tbl(1).line_id := i.move_order_line_id;
        message('=======================================================');
        message('Calling INV_Pick_Wave_Pick_Confirm_PUB.Pick_Confirm API');
        message('move_order_line_id=' || i.move_order_line_id);
      
        inv_pick_wave_pick_confirm_pub.pick_confirm(p_api_version_number => l_api_version,
				    p_init_msg_list      => fnd_api.g_true,
				    p_commit             => fnd_api.g_false,
				    x_return_status      => x_return_status,
				    x_msg_count          => x_msg_count,
				    x_msg_data           => x_msg_data,
				    p_move_order_type    => l_mo_details.move_order_type, --i.move_order_type, ??????
				    p_transaction_mode   => l_transaction_mode,
				    p_trolin_tbl         => l_trolin_tbl,
				    p_mold_tbl           => l_mold_tbl,
				    x_mmtt_tbl           => x_mmtt_tbl,
				    x_trolin_tbl         => x_trolin_tbl,
				    p_transaction_date   => l_transaction_date);
      
        message('=======================================================');
        message('x_return_status=' || x_return_status);
        message(fnd_message.get);
        IF (x_return_status <> fnd_api.g_ret_sts_success
           -- Added By Roman W. 2019-08-13 - INC0165587
           AND x_msg_data IS NOT NULL) THEN
          ROLLBACK;
        
          UPDATE xxinv_trx_pick_in t
          SET    t.err_message      = x_msg_data,
	     t.status           = 'E',
	     t.last_update_date = SYSDATE,
	     t.last_updated_by  = fnd_global.user_id
          WHERE  t.trx_id = i.trx_id;
        
          COMMIT;
          message('ERROR_LOG_PRINT_14 :' || 'Err msg: ' || x_msg_data ||
	      'sqlerrm- ' || SQLERRM || ',err_msg-' || l_err_message); --INC0126962
          message(x_msg_data);
        ELSE
          UPDATE xxinv_trx_pick_in t
          SET    t.status           = 'S',
	     t.err_message      = NULL, --CHG0041294
	     t.last_update_date = SYSDATE,
	     t.last_updated_by  = fnd_global.user_id
          WHERE  t.trx_id = i.trx_id;
          COMMIT;
        
          -- from here added and changed by noam yanai OCT-2014
          -----------------------------------------------------------
          --   commericial invoice and packing list submiting process
          -----------------------------------------------------------
        
          --l_is_all_delivery_lines_staged := 'N';
          l_is_all_delivery_lines_staged := is_all_delivery_lines_staged(p_delivery_id => i.delivery_id);
          --------------------------------------------------
          --                 CHG0044170
          --------------------------------------------------
          IF l_is_all_delivery_lines_staged = 'Y' THEN
	IF nvl(i.print_performa_invoice, 'N') = 'Y' THEN
	  IF 'PICK' = fnd_profile.value('XXINV_TPL_CI_TRIGGER') THEN
	    -- CHG0044170
	    print_commercial_invoice(l_err_message, -- out
			     l_err_code, -- out
			     l_commercial_request_id, -- out
			     p_user_name,
			     i.delivery_id,
			     'PICK'); -- CHG0046435
	  
	    UPDATE xxinv_trx_pick_in t
	    SET    t.commercial_status     = decode(l_err_code,
				        0,
				        'S',
				        'E'),
	           t.commercial_request_id = nvl(l_commercial_request_id,
				     commercial_request_id),
	           t.commercial_message    = substr(l_err_message,
				        1,
				        500)
	    WHERE  t.delivery_id = i.delivery_id;
	  
	    COMMIT;
	  END IF; -- CHG0044170
	END IF;
          
	-- send packing list if needed (added by Noam Yanai OCT-2014)
	IF fnd_profile.value('XXINV_TPL_PACKING_LIST_REPORT_MAIL') IS NOT NULL AND
	   (fnd_profile.value('XXINV_TPL_SEND_PACKING_LIST') = 'Y' OR
	    (fnd_profile.value('XXINV_TPL_SEND_PACKING_LIST') = 'P' AND
	     is_pto_included(i.delivery_id) = 'Y')) THEN
	
	  IF 'PICK' = fnd_profile.value('XXINV_TPL_PACK_LIST_TRIGGER') THEN
	    -- CHG0044170
	    print_packing_list(l_err_message, -- out
		           l_err_code, -- out
		           l_pl_request_id, -- out
		           p_user_name,
		           i.delivery_id,
		           'PICK'); --CHG0046435
	  
	    UPDATE xxinv_trx_pick_in t
	    SET    t.packlist_status     = decode(l_err_code,
				      0,
				      'S',
				      'E'),
	           t.packlist_request_id = nvl(l_pl_request_id,
				   packlist_request_id),
	           t.packlist_message    = nvl(substr(l_err_message,
				          1,
				          500),
				   t.packlist_message)
	    WHERE  t.delivery_id = i.delivery_id;
	  END IF; -- CHG0044170
	END IF;
          
	-- send COC Materials document(CHG0046435)
	IF fnd_profile.value('XXINV_TPL_COC_REPORT_MAIL') IS NOT NULL AND
	   (fnd_profile.value('XXINV_TPL_SEND_COC') = 'Y') THEN
	
	  IF 'PICK' = fnd_profile.value('XXINV_TPL_COC_TRIGGER') THEN
	    -- CHG0046435
	    print_coc_document(l_err_message, -- out
		           l_err_code, -- out
		           l_coc_request_id, -- out
		           p_user_name,
		           i.delivery_id,
		           'PICK');
	  
	    UPDATE xxinv_trx_pick_in t
	    SET    t.coc_status     = decode(l_err_code, 0, 'S', 'E'),
	           t.coc_request_id = nvl(l_coc_request_id,
			          coc_request_id),
	           t.coc_message    = nvl(substr(l_err_message, 1, 500),
			          t.coc_message)
	    WHERE  t.delivery_id = i.delivery_id;
	  END IF; -- CHG0046435
	END IF;
          END IF; -- IF l_is_all_delivery_lines_staged = 'Y' THEN...
          ------------------------------------------------
          --                 CHG0044170
          ------------------------------------------------
        END IF; --IF (x_return_status <> fnd_api.g_ret_sts_success) THEN....
        message('=======================================================');
      
      EXCEPTION
        WHEN OTHERS THEN
          l_sqlerrm := substr(SQLERRM, 1, 255);
          UPDATE xxinv_trx_pick_in t
          SET    t.err_message      = l_err_message || ' ' || l_sqlerrm,
	     t.status           = 'E',
	     t.last_update_date = SYSDATE,
	     t.last_updated_by  = l_user_id
          WHERE  t.trx_id = i.trx_id;
          message('ERROR_LOG_PRINT_15 :' || 'Err msg: ' || l_err_message ||
	      'sqlerrm- ' || l_sqlerrm); --INC0126962
      END;
    END LOOP;
  
    message('ti: ' || ti); --CHG0041294 - Printing first transaction id for picking process
  
    --CHG0041294 - Passing first transaction id from picking process
    --             to backorder respective order lines.
    IF nvl(fnd_profile.value('XXINV_TPL_ALLOCATIONS'), 'Y') = 'N' THEN
      FOR i IN c_source_lines(ti)
      LOOP
        FOR j IN c_backorder_lines(i.move_order_no, i.order_number)
        LOOP
          message('Calling Backorder API');
          --Calling API to Backorder extra move order lines
          inv_mo_backorder_pvt.backorder(p_line_id       => j.line_id,
			     x_return_status => x_return_status,
			     x_msg_count     => l_msg_count,
			     x_msg_data      => l_msg_data);
        
          message('=======================================================');
          message('x_return_status=' || x_return_status);
          message(fnd_message.get);
          IF (x_return_status <> fnd_api.g_ret_sts_success) THEN
	ROLLBACK;
	message('Error while Calling Backorder API for line id: ' ||
	        j.line_id);
	message(x_msg_data);
          ELSE
	message('Backorder API successful for move_order_line_id: ' ||
	        i.move_order_line_id);
          
          END IF;
        END LOOP;
      END LOOP;
    END IF;
  
  EXCEPTION
  
    WHEN stop_process THEN
      retcode := '2';
      errbuf  := l_err_message;
      message('Error:' || errbuf);
    WHEN OTHERS THEN
      retcode := '2';
      errbuf  := SQLERRM;
      message('Exception Occured :');
      message(SQLCODE || ': ' || SQLERRM);
    
  END handle_pick_trx;
  --------------------------------------------------------------------
  --  name:          is_delivery_exists
  --  create by:       Piyali Bhowmick
  --  Revision:        1.0
  --  creation date:   26/10/2017 14:45:36
  --------------------------------------------------------------------
  --  purpose :  To check if delivery name exist
  --------------------------------------------------------------------
  --  ver         date         name              desc
  --   1.0    26.10.2017    Piyali Bhowmick      CHG0041294-TPL Interface FC - Remove Pick Allocations
  -------------------------------------------------------------------------------------------
  FUNCTION is_delivery_exists(p_delivery_name VARCHAR2) RETURN VARCHAR2 IS
    l_valid VARCHAR2(1) := 'N';
  
  BEGIN
  
    SELECT 'Y'
    INTO   l_valid
    FROM   wsh_new_deliveries t
    WHERE  t.name = p_delivery_name;
    -- AND    t.organization_id = p_organization_id ;
  
    RETURN l_valid;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'N';
    
  END is_delivery_exists;

  --------------------------------------------------------------------
  --  name:            create_allocation
  --  create by:       Bellona Banerjee
  --  Revision:        1.0
  --  creation date:   28/11/2017 12:45:36
  --------------------------------------------------------------------
  --  purpose :  To create allocation from inv_replenish_detail_pub.line_details_pub
  --
  --------------------------------------------------------------------
  --   ver        date         name               desc
  --   1.0    28.11.2017    Bellona Banerjee      CHG0041294-TPL Interface FC - Remove Pick Allocations
  -------------------------------------------------------------------------------------------
  PROCEDURE create_allocation(p_move_order_no      IN NUMBER,
		      p_move_order_line_no IN NUMBER,
		      p_move_order_line_id IN NUMBER,
		      p_picked_quantity    IN NUMBER,
		      p_reservation_id     IN NUMBER,
		      p_organization_id    IN NUMBER,
		      p_errbuf             OUT VARCHAR2,
		      p_retcode            OUT VARCHAR2) IS
  
    l_api_version          NUMBER := 1.0;
    l_init_msg_list        VARCHAR2(2) := fnd_api.g_true;
    l_return_values        VARCHAR2(2) := fnd_api.g_false;
    l_commit               VARCHAR2(2) := fnd_api.g_false;
    x_return_status        VARCHAR2(2);
    x_msg_count            NUMBER := 0;
    x_msg_data             VARCHAR2(255);
    l_user_id              NUMBER;
    l_resp_id              NUMBER;
    l_appl_id              NUMBER;
    l_row_cnt              NUMBER := 1;
    l_trohdr_rec           inv_move_order_pub.trohdr_rec_type;
    l_trohdr_val_rec       inv_move_order_pub.trohdr_val_rec_type;
    x_trohdr_rec           inv_move_order_pub.trohdr_rec_type;
    x_trohdr_val_rec       inv_move_order_pub.trohdr_val_rec_type;
    l_validation_flag      VARCHAR2(2) := inv_move_order_pub.g_validation_yes;
    l_trolin_tbl           inv_move_order_pub.trolin_tbl_type;
    l_trolin_val_tbl       inv_move_order_pub.trolin_val_tbl_type;
    x_trolin_tbl           inv_move_order_pub.trolin_tbl_type;
    x_trolin_val_tbl       inv_move_order_pub.trolin_val_tbl_type;
    x_number_of_rows       NUMBER;
    x_transfer_to_location NUMBER;
    x_expiration_date      DATE;
    x_transaction_temp_id  NUMBER;
    l_picked_quantity      NUMBER;
  
    --Handle exceptions
    fail_api EXCEPTION;
  
    CURSOR c_mo_details IS
      SELECT mtrh.header_id,
	 mtrh.request_number,
	 mtrh.move_order_type,
	 mtrh.organization_id,
	 mtrl.line_id,
	 mtrl.line_number,
	 mtrl.inventory_item_id,
	 mtrl.lot_number,
	 mtrl.quantity,
	 revision,
	 mtrl.from_locator_id,
	 (SELECT DISTINCT operating_unit
	  FROM   org_organization_definitions
	  WHERE  organization_id = mtrh.organization_id) org_id
      FROM   mtl_txn_request_headers mtrh,
	 mtl_txn_request_lines   mtrl
      WHERE  mtrh.header_id = mtrl.header_id
      AND    mtrh.request_number = p_move_order_no --'37196944'  --XXINV_TRX_PICK_IN.MOVE_ORDER_NO
      AND    mtrl.line_number = p_move_order_line_no --XXINV_TRX_PICK_IN.MOVE_ORDER_LINE_NO
      AND    mtrh.organization_id = p_organization_id --736 -- Profile option name XXINV_TPL_ORGANIZATION_ID
      ;
  
  BEGIN
  
    FOR i IN c_mo_details
    LOOP
    
      l_picked_quantity := p_picked_quantity;
    
      SELECT COUNT(*)
      INTO   x_number_of_rows
      FROM   mtl_txn_request_lines
      WHERE  header_id = i.header_id;
    
      message('==========================================================');
      message('In Parameters for Allocation API');
      message('l_qty_to_be_allocated: ' || l_picked_quantity);
      message('i.revision: ' || i.revision);
      message('i.from_locator_id: ' || i.from_locator_id);
      message('i.lot_number: ' || i.lot_number);
      message('i.move_order_type: ' || i.move_order_type);
      message('==========================================================');
      message('Calling INV_REPLENISH_DETAIL_PUB to Allocate MO');
      ----------------------------------------
      -- Allocate each line of the Move Order
      ----------------------------------------
      inv_replenish_detail_pub.line_details_pub(p_line_id               => i.line_id,
				x_number_of_rows        => x_number_of_rows,
				x_detailed_qty          => l_picked_quantity, --i.quantity,
				x_return_status         => x_return_status,
				x_msg_count             => x_msg_count,
				x_msg_data              => x_msg_data,
				x_revision              => i.revision,
				x_locator_id            => i.from_locator_id,
				x_transfer_to_location  => x_transfer_to_location,
				x_lot_number            => i.lot_number,
				x_expiration_date       => x_expiration_date,
				x_transaction_temp_id   => x_transaction_temp_id,
				p_transaction_header_id => NULL,
				p_transaction_mode      => NULL,
				p_move_order_type       => i.move_order_type,
				p_serial_flag           => fnd_api.g_false,
				p_plan_tasks            => FALSE,
				p_auto_pick_confirm     => FALSE,
				p_commit                => FALSE);
    
      message('return status for Allocation API:' || x_return_status);
      message(x_msg_data);
      message(x_msg_count);
      message(fnd_message.get);
      IF (x_return_status <> fnd_api.g_ret_sts_success) THEN
        RAISE fail_api;
      ELSE
        message('Trx temp ID: ' || x_transaction_temp_id);
        message('Allocation successful');
      END IF;
      message('==========================================================');
    END LOOP;
    COMMIT;
  EXCEPTION
    WHEN fail_api THEN
      message(x_msg_data);
      p_errbuf  := x_msg_data;
      p_retcode := '2';
    WHEN OTHERS THEN
      message('Exception Occured :');
      message('SQLCODE :' || SQLERRM);
      message('=======================================================');
  END create_allocation;

  --------------------------------------------------------------------
  --  name:            create_delivery
  --  create by:       Piyali Bhowmick
  --  Revision:        1.0
  --  creation date:   26/10/2017 12:45:36
  --------------------------------------------------------------------
  --  purpose :  To create delivery_name from WSH_DELIVERIES_PUB.create_update_delivery
  --
  --------------------------------------------------------------------
  --   ver        date         name               desc
  --   1.0    26.10.2017    Piyali Bhowmick      CHG0041294-TPL Interface FC - Remove Pick Allocations
  -------------------------------------------------------------------------------------------

  PROCEDURE create_delivery(p_delivery_name      IN VARCHAR2,
		    p_delivery_detail_id IN NUMBER,
		    p_out_delivery_id    OUT NUMBER,
		    p_errbuf             OUT VARCHAR2,
		    p_retcode            OUT VARCHAR2) IS
  
    l_init_msg_list VARCHAR2(30);
    l_action_code   VARCHAR2(15);
    delivery_info   wsh_deliveries_pub.delivery_pub_rec_type;
    l_return_status VARCHAR2(10);
    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(2000);
    l_msg_details   VARCHAR2(3000);
    l_msg_summary   VARCHAR2(3000);
    fail_api EXCEPTION;
    l_delivery_name              VARCHAR2(100);
    l_organization_id            NUMBER;
    l_pickup_location_id         NUMBER;
    l_dropoff_location_id        NUMBER;
    l_ship_method                VARCHAR2(30);
    l_freight_terms_code         VARCHAR2(30);
    l_intmed_ship_to_location_id NUMBER;
  
  BEGIN
    p_errbuf  := NULL;
    p_retcode := 0;
    -- Initialize return status
  
    l_return_status := wsh_util_core.g_ret_sts_success;
  
    -- Create a new delivery for the following
  
    SELECT w.organization_id,
           w.ship_from_location_id,
           w.ship_to_location_id,
           w.ship_method_code,
           w.freight_terms_code, -- pass freight_terms
           w.intmed_ship_to_location_id
    INTO   l_organization_id,
           l_pickup_location_id,
           l_dropoff_location_id,
           l_ship_method,
           l_freight_terms_code, -- pass freight_terms
           l_intmed_ship_to_location_id
    FROM   wsh_deliverables_v w
    WHERE  w.delivery_detail_id = p_delivery_detail_id;
  
    delivery_info.name                         := p_delivery_name; -- Pass delivery name
    delivery_info.organization_id              := l_organization_id; -- Pass Organization ID
    delivery_info.initial_pickup_location_id   := l_pickup_location_id; -- Pass the Pick up location ID
    delivery_info.ultimate_dropoff_location_id := l_dropoff_location_id; -- pass the Drop off location ID
    delivery_info.ship_method_code             := l_ship_method; -- pass Ship Method
    delivery_info.freight_terms_code           := l_freight_terms_code; -- pass freight_terms
    delivery_info.intmed_ship_to_location_id   := l_intmed_ship_to_location_id; -- pass intmed_ship_to_id
    l_action_code                              := 'CREATE'; -- Action Code
  
    -- Call to WSH_DELIVERIES_PUB.create_update_delivery
    wsh_deliveries_pub.create_update_delivery(p_api_version_number => 1.0,
			          p_init_msg_list      => l_init_msg_list,
			          x_return_status      => l_return_status,
			          x_msg_count          => l_msg_count,
			          x_msg_data           => l_msg_data,
			          p_action_code        => l_action_code,
			          p_delivery_info      => delivery_info,
			          p_delivery_name      => p_delivery_name,
			          x_delivery_id        => p_out_delivery_id,
			          x_name               => l_delivery_name);
  
    -- If the return status is not success(S) then raise exception
  
    IF (l_return_status <> wsh_util_core.g_ret_sts_success) THEN
      RAISE fail_api;
    ELSE
      dbms_output.put_line('New Delivery ID  : ' || p_out_delivery_id);
      dbms_output.put_line('New Delivery Name: ' || p_delivery_name);
      message('New Delivery ID  : ' || p_out_delivery_id);
      message('New Delivery Name: ' || p_delivery_name);
    END IF;
  
  EXCEPTION
    WHEN fail_api THEN
      wsh_util_core.get_messages('Y',
		         l_msg_summary,
		         l_msg_details,
		         l_msg_count);
      IF l_msg_count > 1 THEN
        l_msg_data := l_msg_summary || l_msg_details;
        p_errbuf   := l_msg_data;
        p_retcode  := '2';
        --  dbms_output.put_line('Message Data : ' || x_msg_data);
      ELSE
        l_msg_data := l_msg_summary;
        p_errbuf   := 'create_delivery : Unable to create delivery ' ||
	          l_msg_data;
        p_retcode  := '2';
        --  dbms_output.put_line('Message Data : ' || x_msg_data);
      END IF;
    
    WHEN no_data_found THEN
      p_retcode := '2';
      p_errbuf  := 'create_delivery Unable to create delivery: No info found for p_delivery_detail_id in wsh_deliverables_v';
    WHEN OTHERS THEN
      p_retcode := '2';
      p_errbuf  := 'create_delivery Unable to create delivery:' ||
	       substr(SQLERRM, 1, 200);
    
  END create_delivery;
  --------------------------------------------------------------------
  --  name:            assign_delivery_detail
  --  create by:       Piyali Bhowmick
  --  Revision:        1.0
  --  creation date:   16/10/2017 12:45:36
  --------------------------------------------------------------------
  --  purpose :  To assign  delivery_detail_id to delivery_name
  --
  --------------------------------------------------------------------
  --  ver        date            name            desc
  --   1.0    26.10.2017    Piyali Bhowmick      CHG0041294-TPL Interface FC - Remove Pick Allocations
  -------------------------------------------------------------------------------------------

  PROCEDURE assign_delivery_detail(p_delivery_name      IN VARCHAR2,
		           p_delivery_detail_id IN NUMBER,
		           p_delivery_id        IN NUMBER,
		           p_errbuf             OUT VARCHAR2,
		           p_retcode            OUT VARCHAR2) IS
  
    --l_commit        VARCHAR2(30);
    l_tabofdeldet   wsh_delivery_details_pub.id_tab_type;
    l_action        VARCHAR2(30);
    l_return_status VARCHAR2(10);
    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(2000);
    l_msg_details   VARCHAR2(3000);
    l_msg_summary   VARCHAR2(3000);
    fail_api EXCEPTION;
  BEGIN
    -- Initialize return status
  
    l_return_status := wsh_util_core.g_ret_sts_success;
  
    p_errbuf  := NULL;
    p_retcode := 0;
    -- Values for WSH_DELIVERY_DETAILS_PUB.Detail_to_Delivery
  
    l_tabofdeldet(1) := p_delivery_detail_id;
    l_action := 'ASSIGN';
  
    -- Call to WSH_DELIVERY_DETAILS_PUB.Detail_to_Delivery.
  
    wsh_delivery_details_pub.detail_to_delivery(p_api_version   => 1.0,
				p_init_msg_list => fnd_api.g_true,
				p_commit        => fnd_api.g_true,
				x_return_status => l_return_status,
				x_msg_count     => l_msg_count,
				x_msg_data      => l_msg_data,
				p_tabofdeldets  => l_tabofdeldet,
				p_action        => l_action,
				p_delivery_id   => p_delivery_id,
				p_delivery_name => p_delivery_name);
  
    IF (l_return_status <> wsh_util_core.g_ret_sts_success) THEN
      RAISE fail_api;
    ELSE
      NULL;
      dbms_output.put_line('Detail ' || l_tabofdeldet(1) ||
		   ' assignment to the delivery ' ||
		   p_delivery_name || ' is successful');
    END IF;
  EXCEPTION
    WHEN fail_api THEN
      wsh_util_core.get_messages('Y',
		         l_msg_summary,
		         l_msg_details,
		         l_msg_count);
      IF l_msg_count > 1 THEN
        l_msg_data := l_msg_summary || l_msg_details;
        p_errbuf   := l_msg_data;
        p_retcode  := '2';
        dbms_output.put_line('assign_delivery_detail: Fail to Assign delivery- ' ||
		     l_msg_data);
      ELSE
        l_msg_data := l_msg_summary;
        p_errbuf   := l_msg_data;
        p_retcode  := '2';
        dbms_output.put_line('assign_delivery_detail:Fail to Assign delivery- ' ||
		     l_msg_data);
      END IF;
    
    WHEN OTHERS THEN
      p_errbuf  := 'assign_delivery_detail:Fail to Assign delivery -' ||
	       substr(SQLERRM, 1, 200);
      p_retcode := '2';
    
  END assign_delivery_detail;

  --------------------------------------------------------------------
  --  name:             handle_pack_trx
  --  create by:        yuval tal
  --  Revision:         1.0
  --  creation date:    24.9.2013
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date         name            desc
  --  1.0  24.9.2013    yuval tal       initial build
  --  1.1  27.10.2013   IgorR
  --  1.2  01-OCT-2015  Dalit A. Raviv  CHG0035915 - Packing interface to support delivery packing
  --  1.3  3.7.16      yuval tal        INC0067224 - modify handle_pack_trx, Interface bug. The line in the delivery wasn't split to lpns lines
  --  1.4  3.8.17      yuval tal        INC0099029 - Upper Serial Numbers/Lot  in validations
  --  1.5 14.9.17      yuval tal        CHG0041519 - in case submitted from concurrent set,
  --                                                 pick only records whch enter before set started else pick all
  --                                                 ignore if profile XXINV_TPL_SEQUENTIAL_PROCESS  = N
  --  1.6  10/24/2017   Diptasurjya     CHG0040327 - Pass new parameter to get_db_qty procedure call
  --  1.7  26.10.17  piyali bhowmick     CHG0041294 - Add profile condition 'XXINV_TPL_ALLOCATIONS'='N' in Check Required Field
  --                                                 update delivery id in case of no allocation mode
  --  1.8  15.06.18    Bellona(TCS)     CHG0042444 - Pass new parameter(quantity) to get_db_qty procedure
  --                                     and make changes to avoid too many rows error when delivery detail has been split.
  --
  --  1.9  09/11/2018   Roman W.        CHG0044170 - TPL Interfaces- LPN implementation in APJ
  --  2.0  13/11/2018   Roman W.        CHG0044170 - TPL Interfaces- LPN implementation in APJ
  --                                       to xxinv_trx_pack_in added fields
  --                                              commercial_status     VARCHAR2(1)
  --                                              commercial_request_id NUMBER,
  --                                              commercial_message    VARCHAR2(500),
  --                                              packlist_status       VARCHAR2(1),
  --                                              packlist_request_id   NUMBER,
  --                                              packlist_message      VARCHAR2(500)
  --  2.1  13/11/2018   Roman W.        CHG0044170 - TPL Interfaces- LPN implementation in APJ
  --  2.2  05/09/2019   Bellona(TCS)    CHG0046435 - TPL Handle Pack - COC document by Email
  --  2.3  27.10.19     yuval tal       INC0172947 - wrong condition in where  set t.delivery_id=?
  --------------------------------------------------------------------
  PROCEDURE handle_pack_trx(errbuf      OUT VARCHAR2,
		    retcode     OUT VARCHAR2,
		    p_user_name VARCHAR2) IS
  
    CURSOR c_trx(p_batch_id IN NUMBER) IS
      SELECT t.*
      FROM   xxinv_trx_pack_in t
      WHERE  t.source_code = p_user_name
      AND    t.status = 'N'
      AND    t.batch_id = p_batch_id;
  
    CURSOR c_trx_p IS
      SELECT t.*
      FROM   xxinv_trx_pack_in t
      WHERE  t.source_code = p_user_name
      AND    t.status = 'P';
  
    CURSOR c_delivery_trx_p(p_batch_id IN NUMBER) IS
      SELECT DISTINCT t.delivery_id,
	          t.pack_date
      FROM   xxinv_trx_pack_in t
      WHERE  t.source_code = p_user_name
      AND    t.batch_id = p_batch_id;
  
    -- Dalit A. Raviv 27-Oct-2015 add handle for split with Serials
    CURSOR c_delivery_trx_split(p_batch_id IN NUMBER) IS
      SELECT t.delivery_id,
	 delivery_detail_id,
	 serial_number,
	 inventory_item_id,
	 trx_id,
	 batch_id
      FROM   xxinv_trx_pack_in t
      WHERE  t.serial_number IS NOT NULL
      AND    t.source_code = p_user_name
      AND    t.batch_id = p_batch_id;
  
    CURSOR c_dd_trx_split(p_delivery_detail_id IN NUMBER) IS
      SELECT wdd.requested_quantity,
	 wdd.delivery_detail_id
      FROM   wsh_delivery_details wdd
      WHERE  wdd.delivery_detail_id = p_delivery_detail_id
      AND    wdd.requested_quantity > 1
      UNION
      SELECT wdd.requested_quantity,
	 wdd.delivery_detail_id
      FROM   wsh_delivery_details wdd
      WHERE  wdd.split_from_delivery_detail_id = p_delivery_detail_id
      AND    wdd.requested_quantity > 1;
    -- 27-Oct-2015
  
    l_valid           VARCHAR2(1) := 'N';
    l_organization_id NUMBER;
    l_user_id         NUMBER;
    l_count           NUMBER;
    l_stage_qty       NUMBER := 0;
    l_deliv_qty       NUMBER := 0;
    l_miss_filed_name VARCHAR2(500);
    l_err_message     VARCHAR2(500);
  
    l_resp_id      NUMBER;
    l_resp_appl_id NUMBER;
    l_err_code     NUMBER;
    -- 1.2 01-OCT-2015 Dalit A. Raviv CHG0035915
    l_errbuf             VARCHAR2(2500);
    l_retcode            VARCHAR2(100);
    l_lpn_id             NUMBER := NULL;
    l_req_qty            NUMBER := NULL;
    l_split              VARCHAR2(10);
    l_new_detail_id      NUMBER;
    l_new_lpn            VARCHAR2(10) := 'N';
    l_lpn_dd_id          NUMBER;
    l_lpn_item_id        NUMBER;
    l_packing            VARCHAR2(10);
    l_weight_uom         VARCHAR2(10);
    l_all_pack           VARCHAR2(10);
    l_batch_id           NUMBER;
    l_delivery_detail_id NUMBER;
    stop_process EXCEPTION;
    my_exc       EXCEPTION;
    my_split_exc EXCEPTION;
    --
    l_set_start_date  DATE; --CHG0041519
    l_conc_request_id NUMBER := fnd_global.conc_request_id;
    l_delivery_id     NUMBER; -- CHG0041294
  
    l_dd_tab_rec ddtabtyp; -- CHG0042444
  
    l_is_all_delivery_lines_staged VARCHAR2(1) := 'N'; -- CHG0044170
    l_print_performa_invoice       VARCHAR2(1); -- CHG0044170
    l_commercial_request_id        NUMBER; -- CHG0044170
    l_pl_request_id                NUMBER; -- CHG0044170
    l_is_delivery_packed           VARCHAR2(30); -- CHG0044170
    l_coc_request_id               NUMBER; --CHG0046435
  BEGIN
  
    -- CHG0035915 - Packing interface to support delivery packing
    -- get user details
    get_user_details(p_user_name       => p_user_name,
	         p_user_id         => l_user_id,
	         p_resp_id         => l_resp_id,
	         p_resp_appl_id    => l_resp_appl_id,
	         p_organization_id => l_organization_id,
	         p_err_code        => l_err_code,
	         p_err_message     => l_err_message);
  
    IF l_err_code = 1 THEN
      RAISE stop_process;
    ELSE
      fnd_global.apps_initialize(l_user_id, l_resp_id, l_resp_appl_id);
      --message('ORG_ID = ' || fnd_global.org_id);
    END IF;
  
    --CHG0041519  get set starting date
  
    message('Get concuurent set starting date');
    BEGIN
      IF nvl(fnd_profile.value('XXINV_TPL_SEQUENTIAL_PROCESS'), 'Y') = 'Y' THEN
        SELECT actual_start_date
        INTO   l_set_start_date
        FROM   (SELECT request_id,
	           LEVEL,
	           parent_request_id,
	           t.actual_start_date
	    FROM   fnd_conc_req_summary_v t
	    WHERE  LEVEL = 3
	    START  WITH request_id = l_conc_request_id
	    CONNECT BY PRIOR t.parent_request_id = request_id)
        WHERE  --parent_request_id = -1
         request_id != l_conc_request_id;
      
        message('Found concuurent set starting date=' ||
	    to_char(l_set_start_date, 'ddmmyy hh24miss'));
      
      ELSE
        l_set_start_date := SYSDATE + 1;
        message('XXINV_TPL_SEQUENTIAL_PROCESS=N -> ignore sequence of pick pack ship confirm ');
      
      END IF;
    
    EXCEPTION
    
      WHEN no_data_found THEN
        l_set_start_date := SYSDATE + 1;
        message('Concuurent set starting date not found=' ||
	    to_char(l_set_start_date, 'ddmmyy hh24miss'));
      
    END;
  
    message('Starting date=' ||
	to_char(l_set_start_date, 'ddmmyy hh24miss'));
  
    -- end CHG0041519
  
    /*SELECT user_id
    INTO   l_user_id
    FROM   fnd_user
    WHERE  user_name = p_user_name; -- 'TPL.DE';
    
    l_organization_id := fnd_profile.value_specific(NAME => 'XXINV_TPL_ORGANIZATION_ID',
                                                    user_id => l_user_id);*/
  
    -- i mark all record with batch id it will help me later in the pack prog
    -- to identify all records per delivery from this batch, for the delivery update
    SELECT xxinv_trx_in_batch_s.nextval
    INTO   l_batch_id
    FROM   dual;
  
    UPDATE xxinv_trx_pack_in t
    SET    t.batch_id         = l_batch_id,
           t.last_update_date = SYSDATE,
           t.last_updated_by  = l_user_id
    WHERE  t.source_code = p_user_name
    AND    t.status = 'N'
    AND    t.creation_date < l_set_start_date; -- restrict lines CHG0041519
  
    COMMIT;
    -- end CHG0035915
  
    -- check required
    FOR u IN c_trx(l_batch_id)
    LOOP
    
      l_miss_filed_name := NULL;
      CASE
      /* WHEN u.delivery_id IS NULL THEN
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          l_miss_filed_name := 'delivery_id';*/ -- CHG0041294
        WHEN u.delivery_id IS NULL AND
	 fnd_profile.value('XXINV_TPL_ALLOCATIONS') = 'Y' THEN
          --CHG0041294
          l_miss_filed_name := 'delivery_id';
        WHEN u.delivery_name IS NULL AND
	 fnd_profile.value('XXINV_TPL_ALLOCATIONS') = 'N' THEN
          -- CHG0041294
          l_miss_filed_name := 'delivery_name ';
        WHEN u.order_header_id IS NULL THEN
          l_miss_filed_name := 'order_header_id';
        WHEN u.order_number IS NULL THEN
          l_miss_filed_name := 'order_number';
        WHEN u.order_line_id IS NULL THEN
          l_miss_filed_name := 'order_line_id';
        WHEN u.inventory_item_id IS NULL THEN
          l_miss_filed_name := 'inventory_item_id';
        WHEN u.packed_quantity IS NULL THEN
          l_miss_filed_name := 'packed_quantity';
        WHEN u.item_code IS NULL THEN
          l_miss_filed_name := 'item_code';
        ELSE
          NULL;
      END CASE;
    
      IF l_miss_filed_name IS NOT NULL THEN
        l_err_message := REPLACE('field ~FILED is Required',
		         '~FILED',
		         l_miss_filed_name);
        UPDATE xxinv_trx_pack_in t
        SET    t.err_message      = l_err_message,
	   t.status           = 'E',
	   t.last_update_date = SYSDATE,
	   t.last_updated_by  = l_user_id
        WHERE  t.trx_id = u.trx_id;
        COMMIT;
      END IF;
    END LOOP; -- check required
  
    ------------- Validations -------------
  
    -- update delivery id for non allocation  -  CHG0041294
    IF fnd_profile.value('XXINV_TPL_ALLOCATIONS') = 'N' THEN
    
      FOR a IN c_trx(l_batch_id)
      LOOP
        l_delivery_id := get_delivery_id(a.delivery_name);
      
        UPDATE xxinv_trx_pack_in t
        SET    t.delivery_id      = l_delivery_id,
	   t.err_message      = decode(l_delivery_id,
			       NULL,
			       'Unable to find delivery_id'),
	   t.status           = decode(l_delivery_id,
			       NULL,
			       'E',
			       t.status),
	   t.last_update_date = SYSDATE,
	   t.last_updated_by  = l_user_id
        WHERE  t.trx_id = a.trx_id;
      
        COMMIT;
      
      END LOOP;
    
    END IF;
  
    --- end  CHG0041294
    -- QUANTITY ? check that the total quantity for the item+lot+serial
    --            does not exceed the total quantity in the delivery.
    FOR a IN c_trx(l_batch_id)
    LOOP
      --l_valid     := 'N';
      l_count     := 0;
      l_stage_qty := 0;
      l_deliv_qty := 0;
      BEGIN
        -- Delivery --
        SELECT 'Y'
        INTO   l_valid
        FROM   wsh_new_deliveries t
        WHERE  t.delivery_id = a.delivery_id
        AND    t.organization_id = l_organization_id
        AND    t.status_code = 'OP';
      
      EXCEPTION
        WHEN OTHERS THEN
          --l_valid := 'N';
          UPDATE xxinv_trx_pack_in t
          SET    t.status           = 'E',
	     t.err_message      = 'Delivery ID: ' ||
			  to_char(a.delivery_id) ||
			  '/Delivery name : ' || --CHG0041294
			  to_char(a.delivery_name) ||
			  ' not exist or closed.',
	     t.last_update_date = SYSDATE,
	     t.last_updated_by  = l_user_id
          WHERE  t.trx_id = a.trx_id;
          COMMIT;
        
          retcode := '1';
          errbuf  := 'Delivery ID: ' || to_char(a.delivery_id) ||
	         ' not exist or closed.';
          CONTINUE;
      END;
    
      -- Header --
      --IF l_valid = 'Y' THEN
      SELECT COUNT(d.source_header_id)
      INTO   l_count
      FROM   wsh_delivery_details d
      WHERE  d.source_header_id = a.order_header_id
      AND    d.organization_id = l_organization_id;
    
      IF l_count = 0 THEN
        --l_valid := 'N';
        UPDATE xxinv_trx_pack_in t
        SET    t.status           = 'E',
	   t.err_message      = 'Header ID: ' ||
			to_char(a.order_header_id) ||
			' not linked to delivery.',
	   t.last_update_date = SYSDATE,
	   t.last_updated_by  = l_user_id
        WHERE  t.trx_id = a.trx_id;
        COMMIT;
      
        retcode := '1';
        errbuf  := 'Header ID: ' || to_char(a.order_header_id) ||
	       ' not linked to delivery.';
        CONTINUE;
      END IF; -- l_count
      --END IF; -- l_valid
    
      -- Line to Header --
      --IF l_valid = 'Y' THEN
      SELECT COUNT(1)
      INTO   l_count
      FROM   oe_order_lines_all d
      WHERE  d.header_id = a.order_header_id
      AND    d.line_id = a.order_line_id;
    
      IF l_count = 0 THEN
        --l_valid := 'N';
        UPDATE xxinv_trx_pack_in t
        SET    t.status           = 'E',
	   t.err_message      = 'Line ID: ' || to_char(a.order_line_id) ||
			' not linked to SO: ' || a.order_number || '.',
	   t.last_update_date = SYSDATE,
	   t.last_updated_by  = l_user_id
        WHERE  t.trx_id = a.trx_id;
        COMMIT;
      
        retcode := '1';
        errbuf  := 'Line ID: ' || to_char(a.order_line_id) ||
	       ' not linked to SO: ' || a.order_number || '.';
        CONTINUE;
      END IF; -- l_count
      --END IF; -- l_valid
    
      -- Line to Delivery --
      --IF l_valid = 'Y' THEN
      SELECT COUNT(1)
      INTO   l_count
      FROM   wsh_delivery_details d
      WHERE  d.source_header_id = a.order_header_id
      AND    d.source_line_id = a.order_line_id
      AND    d.organization_id = l_organization_id;
    
      IF l_count = 0 THEN
        --l_valid := 'N';
        UPDATE xxinv_trx_pack_in t
        SET    t.status           = 'E',
	   t.err_message      = 'Line ID: ' || to_char(a.order_line_id) ||
			' not linked to delivery.',
	   t.last_update_date = SYSDATE,
	   t.last_updated_by  = l_user_id
        WHERE  t.trx_id = a.trx_id;
        COMMIT;
      
        retcode := '1';
        errbuf  := 'Line ID: ' || to_char(a.order_line_id) ||
	       ' not linked to delivery.';
        CONTINUE;
      END IF; -- l_count
      --END IF; -- l_valid
    
      -- Item to Delivery --
      --IF l_valid = 'Y' THEN
      SELECT COUNT(d.source_header_id)
      INTO   l_count
      FROM   wsh_delivery_details d
      WHERE  d.source_header_id = a.order_header_id
      AND    d.source_line_id = a.order_line_id
      AND    d.inventory_item_id = a.inventory_item_id
      AND    d.organization_id = l_organization_id;
    
      IF l_count = 0 THEN
        --l_valid := 'N';
        UPDATE xxinv_trx_pack_in t
        SET    t.status           = 'E',
	   t.err_message      = 'Item ID: ' || a.item_code ||
			' not linked to delivery.',
	   t.last_update_date = SYSDATE,
	   t.last_updated_by  = l_user_id
        WHERE  t.trx_id = a.trx_id;
        COMMIT;
      
        retcode := '1';
        errbuf  := 'Item ID: ' || a.item_code || ' not linked to delivery.';
        CONTINUE;
      END IF; -- l_count
      --END IF; -- l_valid
    
      -- LOT Check --
      --IF l_valid = 'Y' THEN
      SELECT COUNT(t.inventory_item_id)
      INTO   l_count
      FROM   mtl_system_items_b t
      WHERE  t.inventory_item_id = a.inventory_item_id
      AND    t.organization_id = l_organization_id
      AND    nvl(t.lot_control_code, 1) = 2; ---> Lot Controlled
    
      IF l_count = 0 THEN
        IF a.lot_number IS NOT NULL THEN
          --l_valid := 'N';
          UPDATE xxinv_trx_pack_in t
          SET    t.status           = 'E',
	     t.err_message      = 'Lot: ' || a.lot_number ||
			  ' sent for item: ' || a.item_code ||
			  ' that not lot controlled.',
	     t.last_update_date = SYSDATE,
	     t.last_updated_by  = l_user_id
          WHERE  t.trx_id = a.trx_id;
          COMMIT;
        
          retcode := '1';
          errbuf  := 'Lot: ' || a.lot_number || ' sent for item: ' ||
	         a.item_code || ' that not lot controlled.';
          CONTINUE;
        END IF; -- a.lot_number
      ELSE
        ---> Lot Controlled
        IF a.lot_number IS NOT NULL THEN
          SELECT COUNT(d.source_header_id)
          INTO   l_count
          FROM   wsh_delivery_details d
          WHERE  d.source_header_id = a.order_header_id
          AND    d.source_line_id = a.order_line_id
          AND    d.inventory_item_id = a.inventory_item_id
          AND    upper(d.lot_number) = upper(a.lot_number) --INC0099029
          AND    d.organization_id = l_organization_id;
        
          IF l_count = 0 THEN
	--l_valid := 'N';
	UPDATE xxinv_trx_pack_in t
	SET    t.status           = 'E',
	       t.err_message      = 'Lot: ' || a.lot_number ||
			    ' sent for item: ' || a.item_code ||
			    ' but not exist in delivery.',
	       t.last_update_date = SYSDATE,
	       t.last_updated_by  = l_user_id
	WHERE  t.trx_id = a.trx_id;
	COMMIT;
          
	retcode := '1';
	errbuf  := 'Lot: ' || a.lot_number || ' sent for item: ' ||
	           a.item_code || ' but not exist in delivery.';
	CONTINUE;
          END IF;
        ELSE
          --l_valid := 'N';
          UPDATE xxinv_trx_pack_in t
          SET    t.status           = 'E',
	     t.err_message      = '"Lot Number" cannot be NULL for item with LOT control.',
	     t.last_update_date = SYSDATE,
	     t.last_updated_by  = l_user_id
          WHERE  t.trx_id = a.trx_id;
          COMMIT;
        
          retcode := '1';
          errbuf  := '"Lot Number" cannot be NULL for item with LOT control.';
          CONTINUE;
        END IF; -- a.lot_number
      END IF; --l_count
      --END IF; -- l_valid
    
      -- SERIAL Check --
      --IF l_valid = 'Y' THEN
      SELECT COUNT(t.inventory_item_id)
      INTO   l_count
      FROM   mtl_system_items_b t
      WHERE  t.inventory_item_id = a.inventory_item_id
      AND    t.organization_id = l_organization_id
      AND    nvl(t.serial_number_control_code, 1) = 1; ---> Not Serial Controlled
    
      IF l_count = 0 THEN
        ---> SERIAL Controlled
        IF a.serial_number IS NOT NULL THEN
          SELECT COUNT(d.source_header_id)
          INTO   l_count
          FROM   wsh_delivery_details d
          WHERE  d.source_header_id = a.order_header_id
	    --  AND    d.source_line_id = a.order_line_id    --  INC0067224
          AND    d.source_line_id IN --  INC0067224
	     (SELECT a.order_line_id
	       FROM   dual
	       UNION ALL
	       SELECT line_id
	       FROM   oe_order_lines_all l
	       WHERE  l.split_from_line_id = a.order_line_id) -- end    --  INC0067224
	    
          AND    d.inventory_item_id = a.inventory_item_id
          AND    d.organization_id = l_organization_id
          AND    nvl(upper(d.serial_number), --Added Noam Y.
	         (SELECT upper(sn.serial_number) --INC0099029
	          FROM   mtl_material_transactions mt,
		     mtl_serial_numbers        sn
	          WHERE  mt.move_order_line_id = d.move_order_line_id
	          AND    sn.last_transaction_id = mt.transaction_id
	          AND    upper(sn.serial_number) =
		     upper(a.serial_number) --INC0099029
	          AND    rownum = 1)) = upper(a.serial_number);
        
          IF l_count = 0 THEN
	--l_valid := 'N';
	UPDATE xxinv_trx_pack_in t
	SET    t.status           = 'E',
	       t.err_message      = 'SERIAL: ' || a.serial_number ||
			    ' sent for item: ' || a.item_code ||
			    ' but not exist in delivery.',
	       t.last_update_date = SYSDATE,
	       t.last_updated_by  = l_user_id
	WHERE  t.trx_id = a.trx_id;
	COMMIT;
          
	retcode := '1';
	errbuf  := 'SERIAL: ' || a.serial_number || ' sent for item: ' ||
	           a.item_code || ' but not exist in delivery.';
	CONTINUE;
          END IF; -- l_count
        ELSE
          --l_valid := 'N';
          UPDATE xxinv_trx_pack_in t
          SET    t.status           = 'E',
	     t.err_message      = '"Serial Number" cannot be NULL for item with SERIAL control.',
	     t.last_update_date = SYSDATE,
	     t.last_updated_by  = l_user_id
          WHERE  t.trx_id = a.trx_id;
          COMMIT;
        
          retcode := '1';
          errbuf  := '"Serial Number" cannot be NULL for item with SERIAL control.';
          CONTINUE;
        END IF; -- a.serial_number
      ELSE
        ---> No Serial Control
        IF a.serial_number IS NOT NULL THEN
          --l_valid := 'N';
          UPDATE xxinv_trx_pack_in t
          SET    t.status           = 'E',
	     t.err_message      = 'Serial: ' || a.serial_number ||
			  ' sent for item: ' || a.item_code ||
			  ' that not serial controlled.',
	     t.last_update_date = SYSDATE,
	     t.last_updated_by  = l_user_id
          WHERE  t.trx_id = a.trx_id;
          COMMIT;
        
          retcode := '1';
          errbuf  := 'Serial: ' || a.serial_number || ' sent for item: ' ||
	         a.item_code || ' that not serial controlled.';
          CONTINUE;
        END IF; -- a.serial_number
      END IF; -- l_count
      --END IF; -- l_valid
    
      -- Quantity --
      -- CHG0035915 01-Oct-2015 Dalit A. Raviv add condition
      -- this code need to support all interfaces sources.
      -- TPL FC will use PACK with split ability of DD if the qty is not the same
      IF /*l_valid = 'Y' AND*/
       nvl(fnd_profile.value('XXINV_TPL_DELIVERY_PACKING'), 'N') = 'N' THEN
        SELECT SUM(t.packed_quantity)
        INTO   l_stage_qty
        FROM   xxinv_trx_pack_in t
        WHERE  t.status != 'E'
        AND    t.inventory_item_id = a.inventory_item_id
        AND    t.delivery_id = a.delivery_id
        AND    t.batch_id = l_batch_id; --CHG0041519
      
        SELECT SUM(t.requested_quantity)
        INTO   l_deliv_qty
        FROM   wsh_delivery_details     t,
	   wsh_delivery_assignments m,
	   wsh_new_deliveries       w
        WHERE  t.inventory_item_id = a.inventory_item_id
        AND    t.delivery_detail_id = m.delivery_detail_id
        AND    w.delivery_id = m.delivery_id
        AND    w.delivery_id = a.delivery_id;
      
        IF nvl(l_stage_qty, 0) > nvl(l_deliv_qty, 0) THEN
          --l_valid := 'N';
          UPDATE xxinv_trx_pack_in t
          SET    t.status           = 'E',
	     t.err_message      = 'Quantity of item: ' || a.item_code ||
			  ' exceed quantity in delivery line.',
	     t.last_update_date = SYSDATE,
	     t.last_updated_by  = l_user_id
          WHERE  t.trx_id = a.trx_id;
          COMMIT;
        
          retcode := '1';
          errbuf  := 'Quantity of item: ' || a.item_code ||
	         ' exceed quantity in delivery.';
          CONTINUE;
        END IF; -- compare qty
      END IF; -- l_valid
    
      ------------- After Validations -------------
      -- CHG0035915 01-Oct-2015 Dalit A. Raviv add condition
      -- If record passed validation, change the record status.
      -- if FC tpl user (need to actual pack the delivery)
      -- change the record into P status in order to continue the process
      --IF l_valid = 'Y' THEN
      l_packing := nvl(fnd_profile.value('XXINV_TPL_DELIVERY_PACKING'), 'N');
      UPDATE xxinv_trx_pack_in t
      SET    t.status = CASE
		  WHEN l_packing = 'N' THEN
		   'S'
		  ELSE
		   'P'
		END,
	 t.err_message      = '',
	 t.last_update_date = SYSDATE,
	 t.last_updated_by  = l_user_id
      WHERE  t.trx_id = a.trx_id;
      COMMIT;
    
      retcode := '0';
      errbuf  := '';
      --END IF; -- l_valid
    END LOOP; -- validation
  
    -- CHG0035915
    -- 1) check LPN exists at oracle if N create new one
    -- 2) Check if the Qty received is the same as in the qty at Delivery detail record in db
    --    if not need to split the line
    -- 3) Handle Split Line
    -- 4) Handle Pack
    -- 5) Handle Update DD LPN dff fields
    --    Handle Update DD LPN weight_uom and gross_weight details
    -- 6) Handle Update delivery DFF attribute4,5
  
    ------------- TPL Pack initialize -------------
    IF l_packing = 'Y' THEN
      mo_global.set_policy_context('S', fnd_global.org_id);
      inv_globals.set_org_id(fnd_global.org_id);
      mo_global.init('INV');
    
      -- Dalit A. Raviv 27-Oct-2015 CHG0035915 -> CTASK0026368
      -- Handle Serial Split before start to pack
      FOR r_delivery_trx_split IN c_delivery_trx_split(l_batch_id)
      LOOP
        FOR r_dd_trx_split IN c_dd_trx_split(r_delivery_trx_split.delivery_detail_id)
        LOOP
          FOR i IN 1 .. (r_dd_trx_split.requested_quantity - 1)
          LOOP
	BEGIN
	  -- Split Line
	  l_errbuf        := NULL;
	  l_retcode       := 0;
	  l_new_detail_id := NULL;
	  split_delivery_line(errbuf           => l_errbuf, -- o v
		          retcode          => l_retcode, -- o v
		          p_from_detail_id => r_dd_trx_split.delivery_detail_id,
		          p_split_quantity => 1, -- i n
		          p_new_detail_id  => l_new_detail_id); -- o n
	  IF l_retcode <> 0 THEN
	    errbuf := l_errbuf;
	    RAISE my_split_exc;
	  END IF;
	EXCEPTION
	  WHEN my_split_exc THEN
	    UPDATE xxinv_trx_pack_in t
	    SET    t.status           = 'E',
	           t.err_message      = 'E - Serial Split Line - ' ||
			        l_errbuf,
	           t.last_update_date = SYSDATE,
	           t.last_updated_by  = l_user_id
	    WHERE  t.trx_id = r_delivery_trx_split.trx_id;
	    COMMIT;
	  
	    retcode := '2';
	END;
          END LOOP;
        END LOOP;
      END LOOP;
      -- CHG0035915 -> CTASK0026368
    
      FOR r_trx_p IN c_trx_p
      LOOP
        l_new_detail_id := NULL;
        l_lpn_id        := NULL;
        l_new_lpn       := 'N';
        l_req_qty       := NULL;
        l_split         := 'N';
        BEGIN
          -- 1) check LPN exists at oracle if N create new one
          l_lpn_id := get_lpn_id(p_lpn_number      => r_trx_p.lpn, -- i v
		         p_organization_id => l_organization_id); -- i n
        
          IF l_lpn_id IS NULL THEN
	-- Handle create new LPN
	l_new_lpn     := 'Y';
	l_errbuf      := NULL;
	l_retcode     := 0;
	l_lpn_item_id := fnd_profile.value('XXINV_TPL_LPN_ITEM'); -- 10005
	create_lpn(errbuf              => l_errbuf,
	           retcode             => l_retcode,
	           p_container_item_id => l_lpn_item_id,
	           p_container_name    => r_trx_p.lpn,
	           p_organization_id   => l_organization_id,
	           p_quantity          => 1);
	IF retcode <> 0 THEN
	  errbuf := l_errbuf;
	  RAISE my_exc;
	ELSE
	  -- After create the lpn i need the lpn_id for later update
	  l_lpn_id := get_lpn_id(p_lpn_number      => r_trx_p.lpn, -- i v
			 p_organization_id => l_organization_id); -- i n
	END IF;
          ELSE
	l_new_lpn := 'N';
          END IF;
        
          -- 2) Check Qty received
          --    if equal to the qty at Delivery detail in DB - Pack
          --    if lower split the delivery line
          --    if Bigger - update record with E
          /*SELECT SUM(wdd.requested_quantity)
          INTO   l_req_qty
          FROM   wsh_delivery_details wdd
          WHERE  wdd.delivery_detail_id = r_trx_p.delivery_detail_id
          AND    wdd.inventory_item_id = r_trx_p.inventory_item_id;*/
          l_errbuf  := NULL;
          l_retcode := 0;
          get_db_qty(errbuf               => l_errbuf, -- o v
	         retcode              => l_retcode, -- o v
	         p_delivery_detail_id => r_trx_p.delivery_detail_id, -- i n
	         p_inventory_item_id  => r_trx_p.inventory_item_id, -- i n
	         p_lot_number         => r_trx_p.lot_number, -- i v
	         p_serial_number      => r_trx_p.serial_number, -- i v
	         p_packed_quantity    => r_trx_p.packed_quantity, -- i n    --CHG0042444
	         p_organization_id    => l_organization_id, -- i n
	         -- p_trx_line_id        => r_trx_p.line_id, -- i n     -- CHG0040327 - Pass Trx Line ID to identify record from XXINV_TRX_SHIP_OUT
	         --p_dd_id   => l_delivery_detail_id, -- o n
	         --p_req_qty => l_req_qty); -- o n
	         p_del_tab => l_dd_tab_rec); -- o n    -- CHG0042444
          IF l_retcode <> 0 THEN
	errbuf := l_errbuf;
	RAISE my_exc;
          ELSE
	IF l_dd_tab_rec.count = 1 THEN
	  IF nvl(l_dd_tab_rec(1).req_qty, 0) >
	     nvl(r_trx_p.packed_quantity, 0) THEN
	    l_split := 'Y';
	  ELSIF nvl(l_dd_tab_rec(1).req_qty, 0) <
	        nvl(r_trx_p.packed_quantity, 0) THEN
	    -- Quantity of item: &ITEM_CODE exceed quantity in delivery detail.
	    fnd_message.set_name('XXOBJT', 'XXINV_PACK_TRX_QTY');
	    fnd_message.set_token('ITEM_CODE', r_trx_p.item_code);
	    l_errbuf := fnd_message.get;
	    errbuf   := l_errbuf;
	    RAISE my_exc;
	  END IF;
	END IF; --<IF l_dd_tab_rec.COUNT =1 THEN >
          END IF;
          -- 3) Handle Split Line
          IF l_split = 'Y' THEN
	--l_split := 'Y';
	l_errbuf  := NULL;
	l_retcode := 0;
	split_delivery_line(errbuf           => l_errbuf, -- o v
		        retcode          => l_retcode, -- o v
		        p_from_detail_id => l_dd_tab_rec(1).dd_id, -- i n r_trx_p.delivery_detail_id
		        p_split_quantity => r_trx_p.packed_quantity, -- i n
		        p_new_detail_id  => l_new_detail_id); -- o n
	IF l_retcode <> 0 THEN
	  errbuf := l_errbuf;
	  RAISE my_exc;
	END IF;
          END IF;
        
          -- 4) Handle Pack
          IF l_split = 'Y' THEN
	l_errbuf  := NULL;
	l_retcode := 0;
	-- PAck the new DD that created by the split
	pack_lpn_and_delivery(errbuf            => l_errbuf, -- o v
		          retcode           => l_retcode, -- o v
		          p_container_name  => r_trx_p.lpn, -- i v
		          p_action_code     => 'PACK', -- i v
		          p_delivery_detail => l_new_detail_id); -- i n
          
	IF l_retcode <> 0 THEN
	  errbuf := l_errbuf;
	  RAISE my_exc;
	END IF;
          ELSE
	l_errbuf  := NULL;
	l_retcode := 0;
	-- Pack the DD that came from TPL
	FOR i IN 1 .. l_dd_tab_rec.count
	LOOP
	  pack_lpn_and_delivery(errbuf            => l_errbuf, -- o v
			retcode           => l_retcode, -- o v
			p_container_name  => r_trx_p.lpn, -- i v
			p_action_code     => 'PACK', -- i v
			p_delivery_detail => l_dd_tab_rec(i)
				         .dd_id); -- i n r_trx_p.delivery_detail_id
	
	  IF l_retcode <> 0 THEN
	    errbuf := l_errbuf;
	    RAISE my_exc;
	  END IF;
	END LOOP;
          END IF;
          -- 5) Handle Update LPN dff fields
          --    add validation if the weight uom at DB = to the one TPL send.
          --    if not raise error.
          l_lpn_dd_id  := get_lpn_delivery_detail(l_lpn_id);
          l_weight_uom := xxinv_utils_pkg.get_weight_uom_code(l_lpn_item_id,
					  l_organization_id);
          IF l_weight_uom <> r_trx_p.lpn_weight_uom THEN
	-- DB weight_uom not equal to the value TPL sent
	fnd_message.set_name('XXOBJT', 'XXINV_PACK_TRX_WEIGHT_UOM');
	l_errbuf := fnd_message.get;
	RAISE my_exc;
          ELSE
	l_errbuf  := NULL;
	l_retcode := 0;
	update_lpn_dd_info(errbuf                   => l_errbuf, -- o v
		       retcode                  => l_retcode, -- o v
		       p_lpn_delivery_detail_id => l_lpn_dd_id, -- i n
		       p_gross_weight           => r_trx_p.lpn_weight, -- i n
		       p_att2_lpn_lenght        => r_trx_p.lpn_length, -- i v
		       p_att3_lpn_width         => r_trx_p.lpn_width, -- i v
		       p_att4_lpn_height        => r_trx_p.lpn_height, -- i v
		       p_att5_lpn_uom           => r_trx_p.lpn_dimension_uom); -- i v
	IF l_retcode <> 0 THEN
	  errbuf := l_errbuf;
	  RAISE my_exc;
	ELSE
	  UPDATE xxinv_trx_pack_in t
	  SET    t.status           = 'S',
	         t.err_message      = NULL,
	         t.last_update_date = SYSDATE,
	         t.last_updated_by  = l_user_id
	  WHERE  t.source_code = p_user_name
	  AND    t.trx_id = r_trx_p.trx_id;
	  COMMIT;
	END IF;
          END IF;
          ---
          ---
          ----------------- Start CHG0044170 -------------------
          l_delivery_id := r_trx_p.delivery_id;
        
          BEGIN
	SELECT o.print_performa_invoice
	INTO   l_print_performa_invoice
	FROM   xxinv_trx_ship_out o
	WHERE  o.line_id = r_trx_p.line_id;
          EXCEPTION
	WHEN OTHERS THEN
	  l_print_performa_invoice := 'N';
          END;
        
          l_is_all_delivery_lines_staged := is_all_delivery_lines_staged(p_delivery_id => l_delivery_id);
          l_is_delivery_packed           := is_delivery_packed(l_delivery_id);
          --------------------------------------------------
          --                 CHG0044170
          --------------------------------------------------
          IF l_is_all_delivery_lines_staged = 'Y' THEN
	IF nvl(l_print_performa_invoice, 'N') = 'Y' THEN
	  IF 'PACK' = fnd_profile.value('XXINV_TPL_CI_TRIGGER') AND
	     'Y' = l_is_delivery_packed THEN
	    -- CHG0044170
	    print_commercial_invoice(l_err_message, -- out
			     l_err_code, -- out
			     l_commercial_request_id, -- out
			     p_user_name,
			     l_delivery_id,
			     'PACK'); --CHG0046435 add PACK
	  
	    UPDATE xxinv_trx_pack_in t
	    SET    t.commercial_status     = decode(l_err_code,
				        0,
				        'S',
				        'E'),
	           t.commercial_request_id = nvl(l_commercial_request_id,
				     commercial_request_id),
	           t.commercial_message    = nvl(substr(l_err_message,
					1,
					500),
				     t.commercial_message)
	    WHERE  t.delivery_id = l_delivery_id; -- INC0172947
	  
	    COMMIT;
	  END IF; -- CHG0044170
	END IF;
          
	-- send packing list if needed (added by Noam Yanai OCT-2014)
	IF fnd_profile.value('XXINV_TPL_PACKING_LIST_REPORT_MAIL') IS NOT NULL AND
	   (fnd_profile.value('XXINV_TPL_SEND_PACKING_LIST') = 'Y' OR
	    (fnd_profile.value('XXINV_TPL_SEND_PACKING_LIST') = 'P' AND
	     is_pto_included(l_delivery_id) = 'Y')) THEN
	
	  IF 'PACK' = fnd_profile.value('XXINV_TPL_PACK_LIST_TRIGGER') AND
	     'Y' = l_is_delivery_packed THEN
	    -- CHG0044170
	    print_packing_list(l_err_message, -- out
		           l_err_code, -- out
		           l_pl_request_id, -- out
		           p_user_name,
		           l_delivery_id,
		           'PACK'); --CHG0046435
	  
	    UPDATE xxinv_trx_pack_in t
	    SET    t.packlist_status     = decode(l_err_code,
				      0,
				      'S',
				      'E'),
	           t.packlist_request_id = nvl(l_pl_request_id,
				   packlist_request_id),
	           t.packlist_message    = nvl(substr(l_err_message,
				          1,
				          500),
				   t.packlist_message)
	    WHERE  t.delivery_id = l_delivery_id; -- INC0172947
	  
	  END IF; -- CHG0044170
	END IF;
          
	-- send COC Materials document(CHG0046435)
	IF fnd_profile.value('XXINV_TPL_COC_REPORT_MAIL') IS NOT NULL AND
	   (fnd_profile.value('XXINV_TPL_SEND_COC') = 'Y') THEN
	
	  IF 'PACK' = fnd_profile.value('XXINV_TPL_COC_TRIGGER') THEN
	    -- CHG0046435
	    print_coc_document(l_err_message, -- out
		           l_err_code, -- out
		           l_coc_request_id, -- out
		           p_user_name,
		           l_delivery_id,
		           'PACK');
	  
	    UPDATE xxinv_trx_pack_in t
	    SET    t.coc_status     = decode(l_err_code, 0, 'S', 'E'),
	           t.coc_request_id = nvl(l_coc_request_id,
			          coc_request_id),
	           t.coc_message    = nvl(substr(l_err_message, 1, 500),
			          t.coc_message)
	    WHERE  t.delivery_id = l_delivery_id;
	  END IF; -- CHG0046435
	END IF;
          END IF; -- IF l_is_all_delivery_lines_staged = 'Y' THEN...
        
          ----------------- End CHG0044170 ---------------------
        EXCEPTION
          WHEN my_exc THEN
	UPDATE xxinv_trx_pack_in t
	SET    t.status           = 'E',
	       t.err_message      = l_errbuf,
	       t.last_update_date = SYSDATE,
	       t.last_updated_by  = l_user_id
	WHERE  t.trx_id = r_trx_p.trx_id;
	COMMIT;
          
          --retcode := '2';
        END;
      END LOOP;
    
      -- 6) Handle Update delivery DFF attribute4,5
      FOR r_delivery_trx_p IN c_delivery_trx_p(l_batch_id)
      LOOP
        BEGIN
          l_all_pack := is_delivery_packed(r_delivery_trx_p.delivery_id); -- i n
          IF l_all_pack = 'Y' THEN
	l_errbuf  := NULL;
	l_retcode := 0;
	update_delivery_dff(errbuf        => l_errbuf, -- o v
		        retcode       => l_retcode, -- o v
		        p_delivery_id => r_delivery_trx_p.delivery_id, -- i n
		        p_pack        => 'Y', -- i v
		        p_pack_date   => r_delivery_trx_p.pack_date); -- i d
	IF l_retcode <> 0 THEN
	  errbuf := l_errbuf;
	  RAISE my_exc;
	ELSE
	  errbuf  := NULL;
	  retcode := 0;
	END IF;
          END IF;
        EXCEPTION
          WHEN my_exc THEN
	UPDATE xxinv_trx_pack_in t
	SET    t.status           = 'E',
	       t.err_message      = substr(l_errbuf, 1, 2000),
	       t.last_update_date = SYSDATE,
	       t.last_updated_by  = l_user_id
	WHERE  t.source_code = p_user_name
	AND    t.delivery_id = r_delivery_trx_p.delivery_id;
	COMMIT;
          
	retcode := '2';
        END;
      END LOOP;
    END IF;
  EXCEPTION
    -- CHG0035915 01-Oct-2015 Dalit A. Raviv
    WHEN stop_process THEN
      retcode := '2';
      errbuf  := l_err_message;
      message('Error:' || errbuf);
      -- end
    WHEN OTHERS THEN
      ROLLBACK;
      retcode := '2';
      errbuf  := SQLERRM;
    
  END handle_pack_trx;
  --------------------------------------------------------------------
  --  name:          get_delivery_id
  --  create by:       Piyali Bhowmick
  --  Revision:        1.0
  --  creation date:   17/10/2017 14:45:36
  --------------------------------------------------------------------
  --  purpose :  To get delivery id from  wsh_new_deliveries table
  --------------------------------------------------------------------
  --  ver         date         name              desc
  --   1.0    26.10.2017    Piyali Bhowmick      CHG0041294-TPL Interface FC - Remove Pick Allocations
  -------------------------------------------------------------------------------------------
  FUNCTION get_delivery_id(p_delivery_name VARCHAR2) RETURN NUMBER IS
    l_delivery_id NUMBER;
  
  BEGIN
  
    SELECT t.delivery_id
    INTO   l_delivery_id
    FROM   wsh_new_deliveries t
    WHERE  t.name = p_delivery_name;
  
    RETURN l_delivery_id;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
    
  END get_delivery_id;

  -----------------------------------------------------------------
  -- handle_material_trx
  ----------------------------------------------------------------
  -- Purpose: handle material trx
  --- xxinv_trx_material_in
  -- status E error
  --        I moved to Interface
  --        N new records to process
  -- transaction_type_id
  --2   = subinventory Transfer
  --31 = Account Alias Issue
  --41 = Account Alias Receipt

  -- mtl_transactions_interface sample /meaning
  -----------------------------------------------
  --source_code -- e.g. 'Wip Completion' 'ORDER ENTRY'
  --source_line_id -- the line_id of the transacting data entity, i.e. sales order line id if source code = 'ORDER ENTRY'
  --source_header_id -- sales order id if source_code = 'ORDER ENTRY', wip entity id if 'Wip Completion' etc.
  --process_flag -- 1- ready for processing, 2 = not ready, 3 = transaction failed , 7 (succeeded) , 3 (error)
  --transaction_mode -- 2 = concurrent processing mode, 3 = background processing mode
  --lock_flag -- 1 = locked, 2 = not locked, null = not locked
  --organization_id -- organization where the stock is to be transacted to (receipt-type txn) or from (issue type txn or transfer)
  --subinventory_code -- subinventory where the stock is be transacted to (receipt-type txn) or from (issue type txn or transfer)
  --transaction_source_type_id -- key to MTL_TXN_SOURCE_TYPES similar to source code in that source will be the transacting entity - Wip Job, Sales Order etc.
  --transaction_type_id -- key to MTL_TRANSACTION_TYPES = the specific type of transaction e.g. sales order issue, WIP Assy Completion etc.
  --transaction_action_id -- more granular classification of the transaction type - check out the lookup 'MTL_TRANSACTION_ACTION' for a list of possible values
  --transfer_subinventory -- only populated if your transaction is a movement from one location to another, e.g. subinv transfer, inter-org transfer, pick confirm
  --transfer_organization -- only populated if your transaction is a movement from one location to another, e.g. subinv transfer, inter-org transfer, pick confirm
  -----------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------------------
  --     1.0  24.9.13   yuval tal         initial build
  --     2.0  22.7.14   noam yanai        CHG0032515: support transaction id 44 (wip completion)
  --                                                  handle letter case problem for lot ans serial
  --     2.1  31.12.14  noam yanai        CHG0033946: Don't include in cursor account alias receipt (41) for serials that also
  --                                                  have account alias issue (31) (receipt fails if processed before issue)
  --     2.2  8-Sep-16  Samir Todankar    INC0074535 : Oracle fail to process the transaction from 2200 (stock) to 2201 (scrap)
  --                                      Organization_Id Condition applied on the mtl_serial_numbers Select Condition
  -----------------------------------------------------------------
  PROCEDURE handle_internal_material_trx(errbuf      OUT VARCHAR2,
			     retcode     OUT VARCHAR2,
			     p_user_name VARCHAR2) IS
  
    CURSOR c_trx IS
      SELECT xtmi.*
      FROM   xxinv_trx_material_in xtmi
      WHERE  xtmi.source_code = p_user_name
      AND    xtmi.status = 'N'
      AND    NOT EXISTS -- CHG0033946 added by noam yanai DEC-2014. Don't include account alias receipt for serials that also
       (SELECT 1 --                                          have account alias issue (receipt fails if processed first)
	  FROM   xxinv_trx_material_in xtmi1
	  WHERE  xtmi.source_code = xtmi1.source_code
	  AND    xtmi1.status = 'N'
	  AND    xtmi1.transaction_type_id = 31 -- account alias issue
	  AND    xtmi.transaction_type_id = 41 -- account alias receipt
	  AND    xtmi1.inventory_item_id = xtmi.inventory_item_id
	  AND    nvl(xtmi1.from_serial_number, '1') =
	         nvl(xtmi.from_serial_number, '2'));
  
    CURSOR c_trx_interface_check IS
      SELECT t.*
      FROM   xxinv_trx_material_in t
      WHERE  t.status = 'I'
      AND    t.source_code = p_user_name;
  
    l_transaction_interface_id NUMBER;
    l_err_code                 NUMBER;
    l_err_message              VARCHAR2(500);
    l_user_id                  NUMBER;
    l_resp_id                  NUMBER;
    l_resp_appl_id             NUMBER;
    l_organization_id          NUMBER;
    next_record_exception EXCEPTION;
    l_error_explanation VARCHAR2(240);
    l_error_code        VARCHAR2(240);
    ---- out variables for fnd_concurrent.wait_for_request-----
    x_phase           VARCHAR2(100);
    x_status          VARCHAR2(100);
    x_dev_phase       VARCHAR2(100);
    x_dev_status      VARCHAR2(100);
    l_bool            BOOLEAN;
    l_request_id      NUMBER;
    x_message         VARCHAR2(500);
    l_check_asset     NUMBER;
    l_revision        mtl_item_revisions_b.revision%TYPE;
    l_miss_filed_name VARCHAR2(500);
    l_lot             VARCHAR2(80); -- Added by noam yanai AUG-14 CHG0032515
    l_serial          VARCHAR2(30); -- Added by noam yanai AUG-14 CHG0032515
  
  BEGIN
    retcode := 0;
  
    -- get user details
    get_user_details(p_user_name       => p_user_name,
	         p_user_id         => l_user_id,
	         p_resp_id         => l_resp_id,
	         p_resp_appl_id    => l_resp_appl_id,
	         p_organization_id => l_organization_id,
	         p_err_code        => l_err_code,
	         p_err_message     => l_err_message);
  
    IF l_err_code = 1 THEN
    
      RAISE stop_process;
    END IF;
    ---
  
    FOR u IN c_trx
    LOOP
      l_miss_filed_name := NULL;
      CASE
        WHEN u.transaction_type_id IS NULL THEN
          l_miss_filed_name := 'transaction_type_id';
        WHEN u.subinventory_code IS NULL THEN
          l_miss_filed_name := 'subinventory_code';
        WHEN u.transfer_subinventory IS NULL AND u.transaction_type_id = 2 THEN
          l_miss_filed_name := 'transfer_subinventory';
        WHEN u.locator_id IS NULL THEN
          l_miss_filed_name := 'locator_id';
        WHEN u.transfer_locator_id IS NULL AND u.transaction_type_id = 2 THEN
          l_miss_filed_name := 'transfer_locator_id';
        WHEN u.inventory_item_id IS NULL THEN
          l_miss_filed_name := 'inventory_item_id';
          /* WHEN u.reason_id IS NULL THEN
            l_miss_filed_name := 'reason_id';
          WHEN u.lot_expiration_date IS NULL THEN
            l_miss_filed_name := 'lot_expiration_date';*/
        WHEN u.transaction_quantity IS NULL THEN
          l_miss_filed_name := 'transaction_quantity';
        WHEN u.transaction_source_id IS NULL AND u.transaction_type_id != 2 THEN
          l_miss_filed_name := 'transaction_source_id';
        ELSE
          NULL;
      END CASE;
    
      BEGIN
        SELECT 'lot_expiration_date'
        INTO   l_miss_filed_name
        FROM   dual
        WHERE  u.lot_expiration_date IS NULL
        AND    EXISTS
         (SELECT 1
	    FROM   mtl_system_items_b sib
	    WHERE  sib.organization_id = l_organization_id
	    AND    sib.inventory_item_id = u.inventory_item_id
	    AND    sib.lot_control_code = 2)
        AND    NOT EXISTS
         (SELECT 1
	    FROM   mtl_lot_numbers lot
	    WHERE  lot.organization_id = l_organization_id
	    AND    lot.inventory_item_id = u.inventory_item_id
	    AND    upper(lot.lot_number) =
	           upper(nvl(u.lot_number, '-77'))); --INC0099029
      
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
    
      IF l_miss_filed_name IS NOT NULL THEN
        l_err_message := REPLACE('field ~FILED is Required',
		         '~FILED',
		         l_miss_filed_name);
        UPDATE xxinv_trx_material_in t
        SET    t.err_message      = l_err_message,
	   t.status           = 'E',
	   t.last_update_date = SYSDATE,
	   t.last_updated_by  = l_user_id
        WHERE  t.trx_id = u.trx_id;
        COMMIT;
      
      END IF;
    
    END LOOP;
  
    ------- initialize ---------
    fnd_global.apps_initialize(l_user_id, l_resp_id, l_resp_appl_id);
  
    message('ORG_ID=' || fnd_global.org_id);
  
    mo_global.set_policy_context('S', fnd_global.org_id); --
    mo_global.init('INV');
    -------------------------------
  
    SELECT 10 + round(COUNT(*) / g_sleep_mod) * g_sleep_mod_sec
    INTO   g_sleep
    FROM   xxinv_trx_material_in t
    WHERE  t.status = 'N';
  
    FOR i IN c_trx
    LOOP
      BEGIN
        l_revision    := NULL;
        l_err_message := NULL;
        -- validation checks
        IF i.transaction_type_id NOT IN (2, 31, 41, 44) THEN
          ------ CHG0032515: Changed by noam yanaiJUN-2014
          l_err_message := 'Data error : transaction_type_id =' ||
		   i.transaction_type_id ||
		   'expected (2,31,41, 44 ) ';
          RAISE next_record_exception;
        END IF;
      
        SELECT COUNT(DISTINCT t.asset_inventory)
        INTO   l_check_asset
        FROM   mtl_secondary_inventories t
        WHERE  t.secondary_inventory_name IN
	   (i.subinventory_code, i.transfer_subinventory)
        AND    t.organization_id = l_organization_id;
      
        IF l_check_asset > 1 THEN
        
          l_err_message := 'Subinventories ' || i.subinventory_code ||
		   ' and ' || i.transfer_subinventory ||
		   ' have different ASSET type.';
          RAISE next_record_exception;
        
        END IF;
        --
        -------------------------------------------------------------------------- from here added by noam yanai AUG-2014 CHG0032515
      
        IF i.from_serial_number IS NOT NULL THEN
          SELECT nvl(MAX(sn.serial_number), i.from_serial_number)
          INTO   l_serial
          FROM   mtl_serial_numbers sn
          WHERE  sn.inventory_item_id = i.inventory_item_id
          AND    upper(sn.serial_number) = upper(i.from_serial_number)
          AND    sn.current_organization_id = l_organization_id; -- INC0074535 Added on 8 Sep 2016
        END IF;
      
        IF i.lot_number IS NOT NULL THEN
          SELECT nvl(MAX(ln.lot_number), i.lot_number)
          INTO   l_lot
          FROM   mtl_lot_numbers ln
          WHERE  ln.organization_id = l_organization_id
          AND    ln.inventory_item_id = i.inventory_item_id
          AND    upper(ln.lot_number) = upper(i.lot_number); --INC0099029
        END IF;
        -------------------------------------------------------------------------- to here added by noam yanai AUG-2014 CHG0032515
      
        IF is_revision_control(p_item_code       => i.item_code,
		       p_organization_id => l_organization_id) = 'Y' THEN
        
          l_revision := NULL;
        
          IF i.transaction_type_id IN (2, 31) THEN
	--2   = subinventory Transfer
	--31  = Account Alias Issue
	get_revision(p_item_code       => i.item_code,
		 p_mode            => 1,
		 p_organization_id => l_organization_id,
		 p_revision        => l_revision,
		 p_err_message     => l_err_message,
		 p_subinv          => i.subinventory_code,
		 p_locator_id      => i.locator_id,
		 p_serial          => l_serial,
		 p_lot_number      => l_lot);
          
          ELSE
	-- 41 = Account Alias Receipr
	-- 44 = WIP Completion
	get_revision(p_item_code       => i.item_code,
		 p_mode            => 2,
		 p_organization_id => l_organization_id,
		 p_subinv          => i.subinventory_code,
		 p_revision        => l_revision,
		 p_err_message     => l_err_message,
		 p_locator_id      => i.locator_id,
		 p_serial          => l_serial,
		 p_lot_number      => l_lot);
          
          END IF;
          --
          IF l_err_message IS NOT NULL THEN
	RAISE next_record_exception;
          END IF;
          --
        END IF;
      
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
           organization_id,
           subinventory_code,
           locator_id,
           transaction_type_id,
           transaction_action_id,
           transaction_source_id,
           transaction_source_type_id,
           transaction_quantity,
           transaction_uom,
           transaction_date,
           transfer_organization,
           transfer_subinventory,
           transfer_locator,
           transaction_mode,
           revision,
           transaction_reference,
           reason_id,
           final_completion_flag) ------ CHG0032515: Changed by noam yanaiJUN-2014
        VALUES
          (mtl_material_transactions_s.nextval, ---transaction_interface_id
           SYSDATE, --- CREATION_DATE,
           fnd_global.user_id, --- CREATED_BY,
           SYSDATE, --- LAST_UPDATE_DATE,
           fnd_global.user_id, --- LAST_UPDATE_BY,
           i.source_code, --- SOURCE_CODE
           1, --- SOURCE_LINE_ID,
           1, --- SOURCE_HEADER_ID
           1, --- PROCESS_FLAG, 1-ready 7-succeeded 3 error
           i.inventory_item_id, --- INVENTORY_ITEM_ID,
           l_organization_id, --- ORGANIZATION_ID, -----------------------????????????????????
           i.subinventory_code, --- SUBINVENTORY_CODE,
           i.locator_id, ---locator_id
           i.transaction_type_id, --3, --- TRANSACTION_TYPE_ID,
           3, --- TRANSACTION_ACTION_ID, -- 3 Direct organization transfer
           i.transaction_source_id,
           13, -- 13  Inventory---TRANSACTION_SOURCE_TYPE_ID  --------------????????????
           decode(i.transaction_type_id,
	      41,
	      i.transaction_quantity,
	      -i.transaction_quantity), --- TRANSACTION_QUANTITY, 41 = Account Alias Receipt
           i.transaction_uom, --- TRANSACTION_UOM,
           SYSDATE, --- TRANSACTION_DATE,
           l_organization_id, --- TRANSFER_ORGANIZATION, ----------------------------????????????????????
           i.transfer_subinventory, --- TRANSFER_SUBINVENTORY,
           i.transfer_locator_id, --- transfer_locator,
           3, --3, --- TRANSACTION_MODE, NULL or 1 Online Processing - 2 Concurrent Processing 3 Background Processing
           l_revision, --- REVISION,
           i.transaction_reference, --- TRANSACTION_REFERENCE
           i.reason_id, --- REASON_ID
           decode(i.transaction_type_id, 44, 'Y')) ------ CHG0032515: Changed by noam yanaiJUN-2014
        RETURNING transaction_interface_id INTO l_transaction_interface_id;
      
        IF i.from_serial_number IS NOT NULL THEN
          -- insert serial
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
	(l_transaction_interface_id,
	 SYSDATE, -- last_update_date,
	 fnd_global.user_id, --last_updated_by,
	 fnd_global.user_id, --created_by,
	 SYSDATE,
	 l_serial,
	 l_serial,
	 i.inventory_item_id);
        
          COMMIT;
        END IF;
      
        -- insert lot
      
        IF i.lot_number IS NOT NULL THEN
          INSERT INTO mtl_transaction_lots_interface
	(transaction_interface_id,
	 last_update_date,
	 last_updated_by,
	 lot_number,
	 transaction_quantity,
	 creation_date,
	 created_by,
	 parent_item_id,
	 lot_expiration_date)
          VALUES
	(l_transaction_interface_id,
	 SYSDATE, -- last_update_date,
	 fnd_global.user_id,
	 l_lot,
	 i.transaction_quantity,
	 SYSDATE,
	 fnd_global.user_id, --created_by,
	 i.inventory_item_id,
	 i.lot_expiration_date);
        
        END IF;
      
        -- update transaction_interface_id
      
        UPDATE xxinv_trx_material_in t
        SET    t.status                   = 'I',
	   t.transaction_interface_id = l_transaction_interface_id,
	   t.last_update_date         = SYSDATE,
	   t.last_updated_by          = fnd_global.user_id,
	   t.last_update_login        = fnd_global.login_id
        WHERE  t.trx_id = i.trx_id;
        --
      
        COMMIT;
      
      EXCEPTION
      
        WHEN next_record_exception THEN
          errbuf  := l_err_message;
          retcode := '1';
          UPDATE xxinv_trx_material_in t
          SET    t.transaction_interface_id = NULL,
	     t.status                   = 'E',
	     t.err_message              = substr(l_err_message, 1, 250),
	     t.last_update_date         = SYSDATE,
	     t.last_updated_by          = fnd_global.user_id,
	     t.last_update_login        = fnd_global.login_id
          WHERE  t.trx_id = i.trx_id;
        
        WHEN OTHERS THEN
          errbuf  := l_err_message || '' || SQLERRM;
          retcode := '2';
          UPDATE xxinv_trx_material_in t
          SET    t.transaction_interface_id = NULL,
	     t.status                   = 'E',
	     t.err_message              = substr(errbuf, 1, 250),
	     t.last_update_date         = SYSDATE,
	     t.last_updated_by          = fnd_global.user_id,
	     t.last_update_login        = fnd_global.login_id
          WHERE  t.trx_id = i.trx_id;
          message('Error insert to interface table ...inventory_item_id=' ||
	      i.inventory_item_id || 'qauntity =' ||
	      i.transaction_quantity || ' Serial=' || l_serial ||
	      ' Lot=' || l_lot);
          message(substr(errbuf, 1, 250));
          message('----------------------------');
        
      END;
    
      COMMIT;
    
    END LOOP;
  
    l_request_id := fnd_request.submit_request(application => 'INV',
			           program     => 'INCTCM');
    COMMIT;
  
    -- v_step := 'Step 210';
    IF l_request_id > 0 THEN
      message('Concurrent ''Process transaction interface'' was submitted successfully (request_id=' ||
	  l_request_id || ')');
      ---------
    
      l_bool := fnd_concurrent.wait_for_request(l_request_id,
				10, --- interval 5  seconds
				600, ---- max wait 120 seconds
				x_phase,
				x_status,
				x_dev_phase,
				x_dev_status,
				x_message);
    
      IF upper(x_dev_phase) = 'COMPLETE' AND
         upper(x_dev_status) IN ('ERROR', 'WARNING') THEN
        message('The ''Process transaction interface'' concurrent program completed in ' ||
	    upper(x_dev_status) || '. See log for request_id=' ||
	    l_request_id);
      
      ELSIF upper(x_dev_phase) = 'COMPLETE' AND
	upper(x_dev_status) = 'NORMAL' THEN
        message('The ''Process transaction interface'' program SUCCESSFULLY COMPLETED for request_id=' ||
	    l_request_id);
      
      ELSE
        message('The ''Process transaction interface'' request failed review log for Oracle request_id=' ||
	    l_request_id);
        retcode := '2';
      END IF;
    ELSE
    
      errbuf := 'Concurrent ''Process transaction interface'' submitting PROBLEM';
      message(errbuf);
      retcode := '2';
    END IF;
  
    -- check status of trx records moved to interface table
  
    FOR j IN c_trx_interface_check
    LOOP
      IF c_trx_interface_check%ROWCOUNT = 1 THEN
        message('Waiting ...' || nvl(g_sleep, 0) || ' Sec');
        dbms_lock.sleep(nvl(g_sleep, 0));
      END IF;
    
      BEGIN
        SELECT t.error_explanation,
	   t.error_code
        INTO   l_error_explanation,
	   l_error_code
        FROM   mtl_transactions_interface t
        WHERE  t.transaction_interface_id = j.transaction_interface_id;
      
        IF l_error_explanation IS NOT NULL THEN
        
          UPDATE xxinv_trx_material_in t
          SET    t.status            = 'E',
	     t.err_message       = l_error_explanation,
	     t.last_update_date  = SYSDATE,
	     t.last_updated_by   = fnd_global.user_id,
	     t.last_update_login = fnd_global.login_id
          WHERE  t.trx_id = j.trx_id;
        
          message('Transaction interface id ' ||
	      j.transaction_interface_id || '  Failed :' ||
	      l_error_explanation);
        END IF;
      
      EXCEPTION
        WHEN no_data_found THEN
        
          UPDATE xxinv_trx_material_in t
          SET    t.status            = 'S',
	     t.err_message       = NULL,
	     t.last_update_date  = SYSDATE,
	     t.last_updated_by   = fnd_global.user_id,
	     t.last_update_login = fnd_global.login_id
          WHERE  t.trx_id = j.trx_id;
          message('Transaction interface id ' ||
	      j.transaction_interface_id || '  succeeded');
      END;
    END LOOP;
    COMMIT;
    ------------------------
  EXCEPTION
  
    WHEN OTHERS THEN
    
      retcode := '2';
      errbuf  := SQLERRM;
    
  END handle_internal_material_trx;

  -----------------------------------------------------------------
  -- handle_ship_confirm_trx
  ----------------------------------------------------------------
  -- Purpose: handle_ship_confirm_trx
  -----------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------------------
  --     1.0  24.9.13   yuval tal         initial build
  --     1.1  30.10.13  IgorR
  --  1.2     28.05.17  Yuval tal         CHG0040863 - modify HANDLE_SHIP_CONFIRM_TRX  :
  --                                     TPL Interface- Add freight cost API on Ship Confirm
  --                                     in case UNIT_AMOUNT is not null
  --                                     Insert data into  WSH_FREIGHT_COSTS_PUB.Create_Update_Freight_Costs API
  --                                     if  freight_cost_type_id is null use Profile: XXINV_TPL_DEFAULT_FREIGHT_COST_TYPE_ID
  --  1.3      27.7.17    yuval tal      CHG0041184
  --                                      1. update DELIVERY.Attribute13  with unit amount
  --                                      2. Validate that Tracking Number is not missing (according to profile XXINV_TPL_IS_TRACKING_REQUIRED)
  --  1.4      14.9.17   yuval tal        CHG0041519    - in case submitted from set pick only records whch enter before set started else pick all
  --                                      ignore sequence if profile  IF profile XXINV_TPL_SEQUENTIAL_PROCESS'='N'
  --  1.5      26.10.17  piyali bhowmick  CHG0041294
  --                                       1.Add profile condition 'XXINV_TPL_ALLOCATIONS'='N' in Check Required Field
  --                                       Ship confirm by delivery_name (if delivery_name  is null raise exception ) else ship confirm by delivery_id
  --                                       2.Add profile condition 'XXINV_TPL_ALLOCATIONS'='Y' in check fully picked or closed
  --                                         change all the l_delivery_name with i.delivery_name
  --                                       3.Update delivery id in case of no allocation mode
  --
  --  2.0      15-04-2018 Roman.W         CHG0042242 - Eliminate Ship Confirm errors due to Intangible Items
  --                                      Added logic for combining deliveries with intangble items only to
  --                                      delivery with inventory items, and disconect HAZARD-RESTRICTED items from ship set
  --
  --  1.6      29.03.18  bellona banerjee  CHG0042358  - Packing List Report based on TPL user profile
  --  1.7      29-03-2018 Roman.W.        l_err_message   VARCHAR2(3000) -> VARCHAR2(4000)
  --                                      l_msg_details   VARCHAR2(3000) -> VARCHAR2(4000)
  --                                      l_msg_summary   VARCHAR2(3000) -> VARCHAR2(4000)
  -----------------------------------------------------------------
  PROCEDURE handle_ship_confirm_trx(errbuf      OUT VARCHAR2,
			retcode     OUT VARCHAR2,
			p_user_name VARCHAR2) IS
  
    l_err_code        NUMBER;
    l_err_message     VARCHAR2(4000); -- rem by R.W. 29-04-2018 l_err_message     VARCHAR2(3000);
    l_user_id         NUMBER;
    l_resp_id         NUMBER;
    l_resp_appl_id    NUMBER;
    l_organization_id NUMBER;
    --
  
    --Parameters for WSH_DELIVERIES_PUB.Delivery_Action.
    l_action_code             VARCHAR2(15);
    l_delivery_id             NUMBER;
    l_delivery_name           VARCHAR2(30);
    l_asg_trip_id             NUMBER;
    l_asg_trip_name           VARCHAR2(30);
    l_asg_pickup_stop_id      NUMBER;
    l_asg_pickup_loc_id       NUMBER;
    l_asg_pickup_loc_code     VARCHAR2(30);
    l_asg_pickup_arr_date     DATE;
    l_asg_pickup_dep_date     DATE;
    l_asg_dropoff_stop_id     NUMBER;
    l_asg_dropoff_loc_id      NUMBER;
    l_asg_dropoff_loc_code    VARCHAR2(30);
    l_asg_dropoff_arr_date    DATE;
    l_asg_dropoff_dep_date    DATE;
    l_sc_action_flag          VARCHAR2(10);
    l_sc_close_trip_flag      VARCHAR2(10);
    l_sc_create_bol_flag      VARCHAR2(10);
    l_sc_stage_del_flag       VARCHAR2(10);
    l_sc_trip_ship_method     VARCHAR2(30);
    l_sc_actual_dep_date      VARCHAR2(30);
    l_sc_report_set_id        NUMBER; --:= 1050; --CHG0042358
    l_sc_report_set_name      VARCHAR2(60);
    l_wv_override_flag        VARCHAR2(10);
    l_sc_defer_interface_flag VARCHAR2(1);
    l_packing_completion_flag VARCHAR2(1);
    x_trip_id                 VARCHAR2(30);
    x_trip_name               VARCHAR2(30);
  
    --out parameters
    x_return_status VARCHAR2(10);
    x_msg_count     NUMBER;
    x_msg_data      VARCHAR2(2000);
    x_msg_details   VARCHAR2(3000);
    x_msg_summary   VARCHAR2(3000);
  
    -- Handle exceptions
    l_api_errorexception     EXCEPTION;
    l_freight_cost_exception EXCEPTION;
    l_delivery_check_message VARCHAR2(500);
    l_miss_filed_name        VARCHAR2(500);
    -- records to handle
    CURSOR c_trx(c_start_date DATE) IS
      SELECT *
      FROM   xxinv_trx_ship_confirm_in t
      WHERE  t.status = 'N'
      AND    t.source_code = p_user_name
      AND    creation_date < c_start_date;
  
    -- Out Parameters
    l_return_status VARCHAR2(10);
    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(2000);
    l_msg_details   VARCHAR2(4000); -- rem by R.W. 29-04-2018     l_msg_details   VARCHAR2(3000);
    l_msg_summary   VARCHAR2(4000); -- rem by R.W. 29-04-2018     l_msg_summary   VARCHAR2(3000);
  
    -- Handle exceptions
    l_api_exception EXCEPTION;
    l_my_exception  EXCEPTION;
  
    --
    l_set_start_date  DATE; --CHG0041519
    l_conc_request_id NUMBER := fnd_global.conc_request_id; --CHG0041519
  
    l_error_code NUMBER; -- CHG0042242
    l_error_desc VARCHAR2(2000); -- CHG0042242
    exc_intangible_deliveries EXCEPTION; -- CHG0042242
  BEGIN
    errbuf  := NULL;
    retcode := 0;
  
    print_log('Get concuurent set starting date');
  
    -- get user details
    get_user_details(p_user_name       => p_user_name,
	         p_user_id         => l_user_id,
	         p_resp_id         => l_resp_id,
	         p_resp_appl_id    => l_resp_appl_id,
	         p_organization_id => l_organization_id,
	         p_err_code        => l_err_code,
	         p_err_message     => l_err_message);
  
    IF l_err_code = 1 THEN
      RAISE stop_process;
    END IF;
    ------- initialize ---------
    fnd_global.apps_initialize(l_user_id, l_resp_id, l_resp_appl_id);
    mo_global.set_policy_context('S', fnd_global.org_id);
    inv_globals.set_org_id(fnd_global.org_id);
    mo_global.init('INV');
    --
  
    --CHG0041519  get set starting date
    BEGIN
      IF nvl(fnd_profile.value('XXINV_TPL_SEQUENTIAL_PROCESS'), 'Y') = 'Y' THEN
        SELECT actual_start_date
        INTO   l_set_start_date
        FROM   (SELECT request_id,
	           LEVEL,
	           parent_request_id,
	           t.actual_start_date
	    FROM   fnd_conc_req_summary_v t
	    WHERE  LEVEL = 3
	    START  WITH request_id = l_conc_request_id
	    CONNECT BY PRIOR t.parent_request_id = request_id)
        WHERE  -- parent_request_id = -1
         request_id != l_conc_request_id;
      
        message('Found concuurent set starting date=' ||
	    to_char(l_set_start_date, 'ddmmyyyy hh24miss'));
      ELSE
      
        l_set_start_date := SYSDATE + 1;
      
        message('XXINV_TPL_SEQUENTIAL_PROCESS=N -> ignore sequence of pick pack ship confirm ');
      
      END IF;
    
    EXCEPTION
    
      WHEN no_data_found THEN
        l_set_start_date := SYSDATE + 1;
        message('Concuurent set starting date not found=' ||
	    to_char(l_set_start_date, 'ddmmyyyy hh24miss'));
      
    END;
  
    message('l_set_start_date=' ||
	to_char(l_set_start_date, 'ddmmyyyy hh24miss'));
    -- end CHG0041519
  
    ---
    SELECT decode(MOD(COUNT(*), g_sleep_mod),
	      0,
	      1,
	      MOD(COUNT(*), g_sleep_mod)) * g_sleep_mod_sec
    INTO   g_sleep
    FROM   xxinv_trx_ship_confirm_in t
    WHERE  t.status = 'N'
    AND    t.source_code = p_user_name;
  
    FOR i IN c_trx(l_set_start_date)
    LOOP
      l_err_message := NULL;
    
      BEGIN
        -- check required fields ---
        l_miss_filed_name := NULL;
        /* CASE
          WHEN i.delivery_id IS NULL THEN
            l_miss_filed_name := 'delivery_id';
          ELSE
            NULL;
        END CASE;*/
        CASE
          WHEN i.delivery_id IS NULL AND
	   fnd_profile.value('XXINV_TPL_ALLOCATIONS') = 'Y' THEN
	l_miss_filed_name := 'delivery_id';
          WHEN i.delivery_name IS NULL AND
	   fnd_profile.value('XXINV_TPL_ALLOCATIONS') = 'N' THEN
	l_miss_filed_name := 'delivery_name';
          ELSE
	NULL;
        END CASE; -- Added by Piyali Bhowmick on 11.10.17 for CHG0041294-TPL Interface FC
      
        IF l_miss_filed_name IS NOT NULL THEN
          l_err_message := REPLACE('field ~FILED is Required',
		           '~FILED',
		           l_miss_filed_name);
          RAISE l_my_exception;
        END IF;
      
        -- CHG0041184
        -- check tracking number is required
      
        IF nvl(fnd_profile.value('XXINV_TPL_IS_TRACKING_REQUIRED'), 'N') = 'Y' AND
           i.tracking_number IS NULL THEN
          l_err_message := 'Tracking Number is missing.';
          RAISE l_my_exception;
        
        END IF;
        --- update delivery id in case of no allocation  for  CHG0041294
        --  delivery was created in pick phase
      
        IF fnd_profile.value('XXINV_TPL_ALLOCATIONS') = 'N' THEN
        
          -- FOR a IN c_trx(l_set_start_date) LOOP
          l_delivery_id := get_delivery_id(i.delivery_name);
        
          UPDATE xxinv_trx_ship_confirm_in t
          SET    t.delivery_id      = l_delivery_id,
	     t.err_message      = decode(l_delivery_id,
			         NULL,
			         'Unable to find delivery_id'),
	     t.status           = decode(l_delivery_id,
			         NULL,
			         'E',
			         t.status),
	     t.last_update_date = SYSDATE,
	     t.last_updated_by  = l_user_id
          WHERE  t.trx_id = i.trx_id;
        
          COMMIT;
          -- END LOOP;
        
        END IF;
        -- end delivery_id update
      
        -- check  packing complete
        IF nvl(fnd_profile.value('XXINV_TPL_DELIVERY_PACKING'), 'N') = 'Y' THEN
          BEGIN
	SELECT 'Y'
	INTO   l_packing_completion_flag
	FROM   wsh_new_deliveries wnd
	WHERE  wnd.delivery_id = nvl(i.delivery_id, l_delivery_id)
	AND    nvl(wnd.attribute3, 'N') = 'Y';
          EXCEPTION
	WHEN no_data_found THEN
	  -- packing not complate
	  l_err_message := 'Packing was not completed.';
	  RAISE l_my_exception;
	
          END;
        END IF;
        -- end CHG0041184
      
        ---
        -- check fully picked or closed
        l_delivery_check_message := is_delivery_picked(i.delivery_id);
        IF l_delivery_check_message IS NULL THEN
          --  IF xxinv_trx_in_pkg.is_delivery_picked(i.delivery_id) = 'Y' THEN
        
          /*SELECT t.name
          INTO   l_delivery_name
          FROM   wsh_new_deliveries t
          WHERE  t.delivery_id = i.delivery_id;*/
        
          IF fnd_profile.value('XXINV_TPL_ALLOCATIONS') = 'Y' THEN
	SELECT t.name
	INTO   i.delivery_name
	FROM   wsh_new_deliveries t
	WHERE  t.delivery_id = i.delivery_id;
          END IF; -- Added by Piyali Bhowmick on 11.10.17 for CHG0041294-TPL Interface FC
        
          -------------------------------------------------------------------------------
          -- Title : CHG0042242 - Eliminate Ship Confirm errors due to Intangible Items
          -- Descr : 1) Execute below logic ip profile "XX_APPEND_INTANGIBLE_DELIVERIES"
          --            value equal "Y"
          --         2) Disconect delivery from ship set with HAZARD-RESTRICTED items
          --         3) Combine Delivery with intagble item only to delivery with
          --            inventory items
          -------------------------------------------------------------------------------
          IF 'Y' =
	 nvl(fnd_profile.value('XX_APPEND_INTANGIBLE_DELIVERIES'), 'N') THEN
	ship_confirm_delivery_check(p_delivery_id => i.delivery_id,
			    p_error_code  => l_error_code,
			    p_error_desc  => l_error_desc);
	IF 0 != l_error_code THEN
	  RAISE exc_intangible_deliveries;
	END IF;
          END IF;
          ----
          -- WSH_DELIVERIES_PUB.CREATE_UPDATE_DELIVERY
          --
          -- Update WAYBILL field (TRACKING_NUMBER)
          -- Update unit _amount (freight cost) CHG0041184
          DECLARE
	-- Sepcific Parameters for WSH_DELIVERIES_PUB.CREATE_UPDATE_DELIVERY
	l_delivery_info_rec wsh_deliveries_pub.delivery_pub_rec_type;
          
          BEGIN
          
	IF i.unit_amount IS NOT NULL OR i.tracking_number IS NOT NULL THEN
	
	  l_return_status := wsh_util_core.g_ret_sts_success;
	
	  l_delivery_info_rec.organization_id := l_organization_id;
	  l_delivery_info_rec.delivery_id     := i.delivery_id;
	  l_delivery_info_rec.name            := i.delivery_name; -- Changed from l_delivery_name to i.delivery_name  by Piyali Bhowmick on 11.10.17 for CHG0041294-TPL Interface FC
	
	  IF i.tracking_number IS NOT NULL THEN
	    SELECT substr(i.tracking_number,
		      1,
		      decode(instr(i.tracking_number, '|', 1),
			 0,
			 length(i.tracking_number),
			 instr(i.tracking_number, '|', 1) - 1))
	    INTO   l_delivery_info_rec.waybill
	    FROM   dual;
	    l_delivery_info_rec.attribute1 := substr(i.tracking_number, 1, 140) || CASE
				    WHEN length(i.tracking_number) > 140 THEN
				     '..(more)'
				  END;
	  
	  END IF;
	  -- CHG0041184
	  IF i.unit_amount IS NOT NULL THEN
	    l_delivery_info_rec.attribute13 := i.unit_amount; -- CHG0041184
	  END IF;
	
	  l_action_code := 'UPDATE';
	
	  -- Call to WSH_DELIVERIES_PUB.create_update_delivery
	  wsh_deliveries_pub.create_update_delivery(p_api_version_number => 1.0,
				        p_init_msg_list      => fnd_api.g_true,
				        x_return_status      => l_return_status,
				        x_msg_count          => l_msg_count,
				        x_msg_data           => l_msg_data,
				        p_action_code        => l_action_code,
				        p_delivery_info      => l_delivery_info_rec,
				        p_delivery_name      => i.delivery_name, -- Changed from l_delivery_name to i.delivery_name  by Piyali Bhowmick on 11.10.17 for CHG0041294-TPL Interface FC l_delivery_name,
				        x_delivery_id        => l_delivery_id,
				        x_name               => l_delivery_name);
	
	  -- If the return status is not success(S) then raise exception
	  IF (l_return_status <> wsh_util_core.g_ret_sts_success) THEN
	  
	    wsh_util_core.get_messages('Y',
			       l_msg_summary,
			       l_msg_details,
			       l_msg_count);
	    IF l_msg_count > 1 THEN
	    
	      l_err_message := substr('Unable to update delivery [unit_amount (freight cost)/tracking_number]' ||
			      chr(10) || l_msg_summary ||
			      l_msg_details,
			      1,
			      500);
	    
	    ELSE
	    
	      l_err_message := substr('Unable to update delivery [unit_amount (freight cost)/tracking_number]' ||
			      chr(10) || l_msg_summary,
			      1,
			      500);
	    
	    END IF;
	  
	    RAISE l_api_exception;
	  
	  END IF;
	END IF;
          
          END;
        
          ------------------------------------------------------------------
          -- CHG0040863 - TPL Interface- Add freight cost API on Ship Confirm
          ------------------------------------------------------------------------
          DECLARE
          
	--Standard Parameters.
	p_api_version_number NUMBER;
	init_msg_list        VARCHAR2(30);
	x_msg_details        VARCHAR2(4000); -- Rem by R.W. 29-04-2018 x_msg_details        VARCHAR2(3000)
	x_msg_summary        VARCHAR2(4000); -- Rem by R.W. 29-04-2018 x_msg_summary        VARCHAR2(3000);
	p_validation_level   NUMBER;
          
	action_code       VARCHAR2(15);
	pub_freight_costs wsh_freight_costs_pub.pubfreightcostrectype;
	freight_cost_id   NUMBER;
          
	x_return_status VARCHAR2(30);
	x_msg_count     NUMBER;
	x_msg_data      VARCHAR2(4000); -- Rem by R.W. 29-04-2018 x_msg_data      VARCHAR2(2000);
          BEGIN
	IF i.unit_amount IS NOT NULL THEN
	
	  -- check XXINV_TPL_DEFAULT_FREIGHT_COST_TYPE_ID
	  IF i.freight_cost_type_id IS NULL AND
	     fnd_profile.value('XXINV_TPL_DEFAULT_FREIGHT_COST_TYPE_ID') IS NULL THEN
	    l_err_message := 'Missing freight_cost_type_id or no value in profile XXINV_TPL_DEFAULT_FREIGHT_COST_TYPE_ID';
	    RAISE l_freight_cost_exception;
	  ELSE
	  
	    -- call  freight cost API
	  
	    /* Initialize return status*/
	    x_return_status := wsh_util_core.g_ret_sts_success;
	  
	    pub_freight_costs.freight_cost_type_id := nvl(i.freight_cost_type_id,
					  fnd_profile.value('XXINV_TPL_DEFAULT_FREIGHT_COST_TYPE_ID'));
	    pub_freight_costs.unit_amount          := i.unit_amount;
	    pub_freight_costs.currency_code        := i.currency_code;
	  
	    -- pub_freight_costs.delivery_detail_id := 1;
	    -- get delevery detail id
	    BEGIN
	      SELECT delivery_detail_id
	      INTO   pub_freight_costs.delivery_detail_id
	      FROM   (SELECT *
		  FROM   wsh_delivery_assignments t
		  WHERE  t.delivery_id = i.delivery_id
		  ORDER  BY 1)
	      WHERE  rownum = 1;
	    
	    EXCEPTION
	      WHEN no_data_found THEN
	        l_err_message := substr('No detail_delivery_id  found for delivery_id',
			        1,
			        2000);
	        RAISE l_freight_cost_exception;
	    END;
	    --Call to WSH_FREIGHT_COSTS_PUB.Create_Update_Freight_Costs.
	  
	    wsh_freight_costs_pub.create_update_freight_costs(p_api_version_number => 1.0,
					      p_init_msg_list      => init_msg_list,
					      p_commit             => NULL,
					      x_return_status      => x_return_status,
					      x_msg_count          => x_msg_count,
					      x_msg_data           => x_msg_data,
					      p_pub_freight_costs  => pub_freight_costs,
					      p_action_code        => 'CREATE',
					      x_freight_cost_id    => freight_cost_id);
	  
	    IF (x_return_status <> wsh_util_core.g_ret_sts_success) THEN
	    
	      wsh_util_core.get_messages('Y',
			         x_msg_summary,
			         x_msg_details,
			         x_msg_count);
	      IF x_msg_count > 1 THEN
	        x_msg_data := substr(x_msg_summary || x_msg_details,
			     1,
			     4000);
	      ELSE
	        x_msg_data := substr(x_msg_summary, 1, 4000);
	      END IF;
	    
	      l_err_message := x_msg_data;
	      RAISE l_freight_cost_exception;
	    END IF; -- freight created
	  END IF; -- profile not missing
	END IF; -- i.unit_amount IS NOT NUL
          EXCEPTION
          
	WHEN OTHERS THEN
	  l_err_message := substr(l_err_message || ' ' || SQLERRM,
			  1,
			  2000);
	  RAISE l_freight_cost_exception;
	
          END;
        
          -- End  CHG0040863
        
          -- Values for Ship Confirming the delivery
        
          l_action_code        := 'CONFIRM'; -- The action code for ship confirm
          l_delivery_id        := i.delivery_id;
          l_sc_action_flag     := 'S';
          l_sc_close_trip_flag := 'Y'; -- Close the trip after ship confirm
          -- l_sc_trip_ship_method     := '000001_DHL_L_COURIER'; -- The ship method code (only if you want to update this...)
          l_sc_defer_interface_flag := 'N';
        
          --CHG0042358 Deriving report_set_id based on TPL user profile
          l_sc_report_set_id := nvl(fnd_profile.value_specific(NAME    => 'XXINV_TPL_PACK_LIST_REPORT_SET_ID',
					   user_id => l_user_id),
			1050);
        
          -- Call to WSH_DELIVERIES_PUB.Delivery_Action.
          wsh_deliveries_pub.delivery_action(p_api_version_number      => 1.0,
			         p_init_msg_list           => fnd_api.g_true,
			         x_return_status           => x_return_status,
			         x_msg_count               => x_msg_count,
			         x_msg_data                => x_msg_data,
			         p_action_code             => l_action_code,
			         p_delivery_id             => l_delivery_id,
			         p_delivery_name           => i.delivery_name, -- Changed from l_delivery_name to i.delivery_name  by Piyali Bhowmick on 11.10.17 for CHG0041294-TPL Interface FC
			         p_asg_trip_id             => l_asg_trip_id,
			         p_asg_trip_name           => l_asg_trip_name,
			         p_asg_pickup_stop_id      => l_asg_pickup_stop_id,
			         p_asg_pickup_loc_id       => l_asg_pickup_loc_id,
			         p_asg_pickup_loc_code     => l_asg_pickup_loc_code,
			         p_asg_pickup_arr_date     => l_asg_pickup_arr_date,
			         p_asg_pickup_dep_date     => l_asg_pickup_dep_date,
			         p_asg_dropoff_stop_id     => l_asg_dropoff_stop_id,
			         p_asg_dropoff_loc_id      => l_asg_dropoff_loc_id,
			         p_asg_dropoff_loc_code    => l_asg_dropoff_loc_code,
			         p_asg_dropoff_arr_date    => l_asg_dropoff_arr_date,
			         p_asg_dropoff_dep_date    => l_asg_dropoff_dep_date,
			         p_sc_action_flag          => l_sc_action_flag,
			         p_sc_close_trip_flag      => l_sc_close_trip_flag,
			         p_sc_create_bol_flag      => l_sc_create_bol_flag,
			         p_sc_stage_del_flag       => l_sc_stage_del_flag,
			         p_sc_trip_ship_method     => l_sc_trip_ship_method,
			         p_sc_actual_dep_date      => l_sc_actual_dep_date,
			         p_sc_report_set_id        => l_sc_report_set_id,
			         p_sc_report_set_name      => l_sc_report_set_name,
			         p_wv_override_flag        => l_wv_override_flag,
			         p_sc_defer_interface_flag => l_sc_defer_interface_flag,
			         x_trip_id                 => x_trip_id,
			         x_trip_name               => x_trip_name);
        
          IF (x_return_status <> wsh_util_core.g_ret_sts_success) THEN
          
	RAISE l_api_errorexception;
          
          ELSE
          
	message('The confirm action on the delivery ' || l_delivery_id ||
	        ' is successful');
	UPDATE xxinv_trx_ship_confirm_in t
	SET    t.err_message = NULL,
	       t.status      = 'S'
	WHERE  t.trx_id = i.trx_id;
	COMMIT;
          
          END IF;
        
        ELSE
        
          UPDATE xxinv_trx_ship_confirm_in t
          -- Rem by R.W. 29-04-2018 SET    t.err_message = l_delivery_check_message, --'Delivery not Fully Picked.',
          SET    t.err_message = substr(l_delivery_check_message, 1, 2000), --'Delivery not Fully Picked.',
	     t.status      = 'E'
          WHERE  t.trx_id = i.trx_id;
          COMMIT;
        
        END IF;
      EXCEPTION
        WHEN l_freight_cost_exception THEN
          ROLLBACK;
          UPDATE xxinv_trx_ship_confirm_in t
          SET    t.err_message = substr('Unable to update freight cost ' ||
			    l_err_message,
			    1,
			    2000),
	     t.status      = 'E'
          WHERE  t.trx_id = i.trx_id;
          COMMIT;
        
        WHEN l_api_errorexception THEN
        
          retcode := 1;
          wsh_util_core.get_messages('Y',
			 x_msg_summary,
			 x_msg_details,
			 x_msg_count);
          IF x_msg_count > 1 THEN
	x_msg_data := substr(x_msg_summary || x_msg_details, 1, 2000);
	dbms_output.put_line('Message Data : ' || x_msg_data);
          ELSE
	x_msg_data := substr(x_msg_summary, 1, 2000);
	dbms_output.put_line('Message Data : ' || x_msg_data);
          END IF;
        
          ROLLBACK;
          UPDATE xxinv_trx_ship_confirm_in t
          -- rem by R.W. 29-04-2018 SET    t.err_message = l_err_message || ' ' || x_msg_data,
          SET    t.err_message = substr(l_err_message || ' ' || x_msg_data,
			    1,
			    2000),
	     t.status      = 'E'
          WHERE  t.trx_id = i.trx_id;
        
          COMMIT;
        
        WHEN l_api_exception THEN
        
          retcode := 1;
          wsh_util_core.get_messages('Y',
			 l_msg_summary,
			 l_msg_details,
			 l_msg_count);
          IF l_msg_count > 1 THEN
	l_msg_data := substr(l_msg_summary || l_msg_details, 1, 2000);
	dbms_output.put_line('Message Data : ' || l_msg_data);
          ELSE
	x_msg_data := substr(l_msg_summary, 1, 4000);
	dbms_output.put_line('Message Data : ' || l_msg_data);
          END IF;
        
          ROLLBACK;
          UPDATE xxinv_trx_ship_confirm_in t
          SET    t.err_message = substr(l_err_message || ' ' || l_msg_data,
			    1,
			    2000),
	     t.status      = 'E'
          WHERE  t.trx_id = i.trx_id;
        
          COMMIT;
        
        -- CHG0042242
        WHEN exc_intangible_deliveries THEN
          retcode := 1;
          errbuf  := errbuf || chr(10) || l_error_desc;
        
          UPDATE xxinv_trx_ship_confirm_in t
          SET    t.err_message = substr('Error:' || l_error_desc, 1, 2000),
	     t.status      = 'E'
          WHERE  t.trx_id = i.trx_id;
        
        WHEN OTHERS THEN
        
          message('Unexpected Error: ' || SQLERRM);
          ROLLBACK;
          retcode := 1;
          errbuf  := l_err_message || ' ' || SQLERRM;
        
          UPDATE xxinv_trx_ship_confirm_in t
          SET    t.err_message = substr('Error:' || errbuf, 1, 2000),
	     t.status      = 'E'
          WHERE  t.trx_id = i.trx_id;
        
          COMMIT;
        
      END;
    END LOOP;
    ---
    COMMIT;
  EXCEPTION
    WHEN stop_process THEN
      retcode := '2';
      errbuf  := l_err_message;
      message('Error: ' || errbuf);
    WHEN OTHERS THEN
      retcode := '2';
      errbuf  := SQLERRM;
      message('Exception Occured :');
      message(SQLCODE || ': ' || SQLERRM);
    
  END handle_ship_confirm_trx;
  ------------------------------------------------------------------------------------------
  -- Conc : XXINV_TPL_RCV_INSPECT_TRANSACT / XX INV TPL Interface Rcv Inspect transaction
  ------------------------------------------------------------------------------------------
  -- Ver   Date        Performer    Comments
  -------  --------    -----------  --------------------------------------------------------
  -- 2.0   09/02/2021  Roman W.     CHG0049272 - TPL Add Inspection to PO receiving
  -- 2.1   21/02/2021  Roman W.     CHG0049272 - bug fix
  -- 2.2   07/04/2021  Roman W.     CHG0049272 - bug fix
  ------------------------------------------------------------------------------------------
  PROCEDURE handle_rcv_inspect_trx(errbuf      OUT VARCHAR2,
		           retcode     OUT VARCHAR2,
		           p_user_name VARCHAR2) IS
  
    l_err_code                 NUMBER;
    l_err_message              VARCHAR2(500);
    l_user_id                  NUMBER;
    l_resp_id                  NUMBER;
    l_resp_appl_id             NUMBER;
    l_organization_id          NUMBER;
    l_org_id                   NUMBER;
    l_interface_transaction_id NUMBER;
    l_header_interface_id      NUMBER;
    l_group_id                 NUMBER;
    ---- out variables for fnd_concurrent.wait_for_request-----
    l_vendor_id              ap_suppliers.vendor_id%TYPE;
    l_vendor_num             ap_suppliers.segment1%TYPE;
    l_vendor_name            ap_suppliers.vendor_name%TYPE;
    l_subinv_code            mtl_qoh_loc_all_v.subinventory_code%TYPE;
    l_revision               mtl_item_revisions_b.revision%TYPE;
    l_processing_status_code VARCHAR2(50);
  
    l_subinventory          rcv_transactions_interface.subinventory%TYPE; -- Added By Roman W. 09/02/2021 CHG0049272
    l_locator_id            rcv_transactions_interface.locator_id%TYPE; -- Added By Roman W. 09/02/2021 CHG0049272
    l_auto_transact_code    rcv_transactions_interface.auto_transact_code%TYPE; -- Added By Roman W. 09/02/2021 CHG0049272
    l_parent_transaction_id NUMBER; -- Added By Roman W. 15/02/2021 CHG0049272
    c_parent_transaction    SYS_REFCURSOR;
    c_sql                   NUMBER;
    c_cnt                   NUMBER;
  BEGIN
  
    -- get user details
    get_user_details(p_user_name       => p_user_name,
	         p_user_id         => l_user_id,
	         p_resp_id         => l_resp_id,
	         p_resp_appl_id    => l_resp_appl_id,
	         p_organization_id => l_organization_id,
	         p_err_code        => l_err_code,
	         p_err_message     => l_err_message);
  
    IF l_err_code = 1 THEN
    
      RAISE stop_process;
    END IF;
    -- check required
    validate_rcv_data(errbuf,
	          retcode,
	          c_inspect,
	          p_user_name,
	          l_organization_id);
    --
  
    ------- initialize ---------
    fnd_global.apps_initialize(l_user_id, l_resp_id, l_resp_appl_id);
  
    message('org_id=' || fnd_global.org_id);
    l_org_id := fnd_global.org_id;
    mo_global.set_policy_context('S', l_org_id);
    inv_globals.set_org_id(l_org_id);
    mo_global.init('INV');
  
    --- PO ---------------
    SELECT rcv_interface_groups_s.nextval
    INTO   l_group_id
    FROM   dual;
    message('Group_id=' || l_group_id);
  
    SELECT 10 + round(COUNT(*) / g_sleep_mod) * g_sleep_mod_sec
    INTO   g_sleep
    FROM   xxinv_trx_rcv_in t
    WHERE  t.doc_type = c_inspect
    AND    t.status = 'N'
    AND    t.source_code = p_user_name;
  
    FOR k IN c_rcv_header(c_inspect -- 'INSPECT'
		 ,
		  p_user_name)
    LOOP
    
      BEGIN
        SAVEPOINT header_sp;
      
        BEGIN
          SELECT DISTINCT t.vendor_name,
		  t.vendor_id,
		  t.segment1
          INTO   l_vendor_name,
	     l_vendor_id,
	     l_vendor_num
          FROM   ap_suppliers   t,
	     po_headers_all p
          WHERE  t.vendor_id = p.vendor_id
          AND    p.po_header_id = k.order_header_id;
        
        EXCEPTION
          WHEN OTHERS THEN
	message('Invalid Vendor');
	l_err_message := 'Invalid Vendor';
          
	xxinv_trx_in_pkg.update_rcv_status(errbuf        => errbuf,
			           retcode       => retcode,
			           p_source_code => p_user_name,
			           p_status      => 'E',
			           p_err_message => l_err_message,
			           p_group_id    => l_group_id,
			           p_doc_type    => c_inspect);
          
	errbuf  := 'Invalid Vendor';
	retcode := '2';
	CONTINUE;
          
        END;
      
        FOR i IN c_rcv_lines(c_inspect,
		     p_user_name,
		     k.order_header_id,
		     k.shipment_header_id)
        LOOP
        
          l_revision    := NULL;
          l_err_message := NULL;
        
          /****************************************************
            VALIDATIONS
          ****************************************************/
          IF i.subinventory IS NULL THEN
          
	BEGIN
	
	  SELECT DISTINCT t.subinventory_code
	  INTO   l_subinv_code
	  FROM   mtl_qoh_loc_all_v t
	  WHERE  t.locator_id = i.locator_id;
	
	EXCEPTION
	  WHEN OTHERS THEN
	    message('Invalid Subinventory/Locator');
	    l_err_message := 'Invalid Subinventory/Locator';
	  
	    xxinv_trx_in_pkg.update_rcv_status(errbuf        => errbuf,
				   retcode       => retcode,
				   p_source_code => p_user_name,
				   p_status      => 'E',
				   p_err_message => l_err_message,
				   p_group_id    => l_group_id,
				   p_trx_id      => i.trx_id,
				   p_doc_type    => c_inspect);
	  
	    errbuf  := 'Invalid Subinventory/Locator';
	    retcode := '2';
	    CONTINUE;
	END;
          
          ELSE
	l_subinv_code := i.subinventory;
          END IF;
        
          BEGIN
	l_revision := NULL;
	IF is_revision_control(p_item_code       => i.item_code,
		           p_organization_id => l_organization_id) = 'Y' THEN
	
	  --   l_revision :=
	  get_revision(p_item_code       => i.item_code,
		   p_mode            => 2,
		   p_organization_id => l_organization_id,
		   p_revision        => l_revision,
		   p_err_message     => l_err_message,
		   p_subinv          => i.subinventory,
		   p_locator_id      => i.locator_id,
		   p_serial          => i.from_serial_number,
		   p_lot_number      => i.lot_number);
	
	END IF;
          
          EXCEPTION
	WHEN OTHERS THEN
	  message('Invalid Item ID: ' || i.item_id);
	  l_err_message := 'Invalid Item ID: ' || i.item_id;
	
	  xxinv_trx_in_pkg.update_rcv_status(errbuf        => errbuf,
				 retcode       => retcode,
				 p_source_code => p_user_name,
				 p_status      => 'E',
				 p_err_message => l_err_message,
				 p_group_id    => l_group_id,
				 p_trx_id      => i.trx_id,
				 p_doc_type    => c_inspect);
	
	  errbuf  := 'Invalid Item ID: ' || i.item_id;
	  retcode := '2';
	  CONTINUE;
          END;
        
          get_parent_transaction_id(p_subinventory      => i.subinventory,
			p_inventory_item_id => i.item_id,
			p_organization_id   => fnd_profile.value('XXINV_TPL_ORGANIZATION_ID'),
			p_line_location_id  => i.po_line_location_id,
			p_quantity          => i.qty_received,
			p_transaction_cur   => c_parent_transaction,
			p_error_code        => l_err_code,
			p_error_desc        => l_err_message);
        
          IF 0 != l_err_code THEN
	errbuf  := l_err_message;
	retcode := '2';
	RETURN;
          END IF;
        
          ----------------------------------------
          --       TRANSACTION_ID LOOP
          ----------------------------------------
          /*
          c_cnt := 0;
          if c_parent_transaction is not null then
            begin
              c_sql := DBMS_SQL.to_cursor_number(c_parent_transaction);
              c_cnt := DBMS_SQL.fetch_rows(c_sql);
            exception
              when others then
                c_cnt := 0;
            end;
          end if;
          */
        
          IF c_parent_transaction IS NOT NULL THEN
	LOOP
	  FETCH c_parent_transaction
	    INTO l_parent_transaction_id;
	  EXIT WHEN c_parent_transaction%NOTFOUND;
	
	  INSERT INTO rcv_transactions_interface
	    (interface_transaction_id,
	     parent_transaction_id,
	     group_id,
	     destination_type_code,
	     transaction_type,
	     transaction_date,
	     processing_status_code,
	     processing_mode_code,
	     transaction_status_code,
	     quantity,
	     uom_code,
	     auto_transact_code,
	     receipt_source_code,
	     source_document_code,
	     po_header_id,
	     po_line_id,
	     po_line_location_id,
	     validation_flag,
	     to_organization_id,
	     item_id,
	     subinventory,
	     locator_id,
	     shipment_header_id,
	     shipment_line_id,
	     org_id,
	     last_update_date,
	     last_updated_by,
	     creation_date,
	     created_by,
	     last_update_login)
	  VALUES
	    (rcv_transactions_interface_s.nextval -- interface_transaction_id,
	    ,
	     l_parent_transaction_id -- parent_transaction_id,
	    ,
	     l_group_id -- group_id,
	    ,
	     'INVENTORY' -- destination_type_code ,
	    ,
	     'DELIVER' -- transaction_type ,
	    ,
	     SYSDATE -- transaction_date ,
	    ,
	     'PENDING' -- processing_status_code ,
	    ,
	     'BATCH' -- processing_mode_code ,
	    ,
	     'PENDING' -- transaction_status_code ,
	    ,
	     i.qty_received -- quantity ,
	    ,
	     i.qty_uom_code -- unit_of_measure ,
	    ,
	     'DELIVER' -- auto_transact_code ,
	    ,
	     'VENDOR' -- receipt_source_code ,
	    ,
	     'PO' -- source_document_code ,
	    ,
	     i.order_header_id -- po_header_id ,
	    ,
	     i.order_line_id -- po_line_id ,
	    ,
	     i.po_line_location_id -- po_line_location_id ,
	    ,
	     'Y' -- validation_flag ,
	    ,
	     l_organization_id -- to_organization_code ,
	    ,
	     i.item_id -- item_num ,
	    ,
	     i.subinventory -- subinventory ,
	    ,
	     i.locator_id -- locator_id ,
	    ,
	     i.shipment_header_id -- shipment_header_id ,
	    ,
	     i.shipment_line_id -- shipment_line_id ,
	    ,
	     l_org_id -- org_id
	    ,
	     SYSDATE -- LAST_UPDATE_DATE
	    ,
	     l_user_id -- LAST_UPDATED_BY
	    ,
	     SYSDATE -- CREATION_DATE
	    ,
	     l_user_id -- CREATED_BY
	    ,
	     NULL -- LAST_UPDATE_LOGIN
	     )
	  RETURNING interface_transaction_id INTO l_interface_transaction_id;
	
	  ---  insert serial /lot -------------
	  -- if lot control
	  -- IF i.lot_number IS NOT NULL THEN  Rem By Roman W. 09/02/2021 CHG0049272
	  IF i.lot_number IS NOT NULL AND
	     'RECEIVING' != k.destination_type_code -- CHG0049272
	   THEN
	  
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
	       parent_item_id,
	       lot_expiration_date)
	    VALUES
	      (mtl_material_transactions_s.nextval, --TRANSACTION_INTERFACE_ID
	       SYSDATE, --LAST_UPDATE_DATE
	       l_user_id, --LAST_UPDATED_BY
	       SYSDATE, --CREATION_DATE
	       l_user_id, --CREATED_BY
	       fnd_global.login_id, --LAST_UPDATE_LOGIN
	       i.lot_number, --LOT_NUMBER
	       i.qty_received, --TRANSACTION_QUANTITY
	       i.qty_received, --PRIMARY_QUANTITY
	       NULL, --  mtl_material_transactions_s.nextval, --SERIAL_TRANSACTION_TEMP_ID
	       'RCV', --PRODUCT_CODE
	       rcv_transactions_interface_s.currval, --PRODUCT_TRANSACTION_ID
	       i.item_id,
	       i.lot_expiration_date);
	  
	  END IF;
	  --  if serial control
	  -- IF i.from_serial_number IS NOT NULL THEN  Rem By Roman W. 09/02/2021 CHG0049272
	  IF i.from_serial_number IS NOT NULL AND
	     'RECEIVING' != k.destination_type_code -- CHG0049272
	   THEN
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
	      (mtl_material_transactions_s.nextval, --TRANSACTION_INTERFACE_ID
	       SYSDATE, --LAST_UPDATE_DATE
	       l_user_id, --LAST_UPDATED_BY
	       SYSDATE, --CREATION_DATE
	       l_user_id, --CREATED_BY
	       fnd_global.login_id, --LAST_UPDATE_LOGIN
	       i.from_serial_number, --FM_SERIAL_NUMBER
	       i.to_serial_number, --TO_SERIAL_NUMBER
	       'RCV', --PRODUCT_CODE
	       rcv_transactions_interface_s.currval, --PRODUCT_TRANSACTION_ID,
	       i.item_id);
	  END IF;
	
	  ------------- update interface id's
	  UPDATE xxinv_trx_rcv_in
	  SET    status                   = 'I',
	         interface_transaction_id = l_interface_transaction_id,
	         header_interface_id      = l_header_interface_id,
	         interface_group_id       = l_group_id
	  WHERE  trx_id = i.trx_id;
	
	  -- delete from temp table to allowed resend in future
	  delete_xxinv_trx_resend_orders(errbuf      => errbuf,
			         retcode     => retcode,
			         p_doc_type  => c_inspect,
			         p_header_id => i.order_header_id);
	END LOOP;
          ELSE
	UPDATE xxinv_trx_rcv_in t
	SET    status        = 'E',
	       t.err_message = 'There is no available transaction matched'
	WHERE  t.doc_type = c_inspect
	AND    t.status = 'N'
	AND    t.source_code = p_user_name
	AND    t.order_header_id = k.order_header_id
	AND    nvl(t.order_number, -1) = nvl(k.order_number, -1)
	AND    nvl(t.shipment_number, -1) = nvl(k.shipment_number, -1)
	AND    nvl(t.shipment_header_id, -1) =
	       nvl(k.shipment_header_id, -1)
	AND    nvl(t.destination_type_code, -1) =
	       nvl(k.destination_type_code, -1);
          
          END IF;
        END LOOP;
      
      EXCEPTION
        WHEN OTHERS THEN
          ROLLBACK TO header_sp;
          l_err_message := substr(SQLERRM, 1, 255);
        
          UPDATE xxinv_trx_rcv_in t
          SET    status        = 'E',
	     t.err_message = l_err_message
          WHERE  t.doc_type = c_inspect
          AND    t.status = 'N'
          AND    t.source_code = p_user_name
          AND    t.order_header_id = k.order_header_id
          AND    nvl(t.shipment_header_id, -1) =
	     nvl(k.shipment_header_id, -1);
        
      END;
      COMMIT;
    END LOOP; -- packing slip--
  
    ------------ check errors --------
    --    message('Checking Errors');
  
    FOR j IN c_rcv_trx_interface(c_inspect, p_user_name, NULL)
    LOOP
      IF c_rcv_trx_interface%ROWCOUNT = 1 THEN
        dbms_lock.sleep(g_sleep);
      END IF;
    
      BEGIN
      
        SELECT nvl(error_message, 'XX Unknown error')
        INTO   l_err_message
        FROM   (SELECT REPLACE(listagg(error_message, ' | ') within
		       GROUP(ORDER BY interface_line_id),
		       'Txn Success.') error_message
	    
	    FROM   po_interface_errors t
	    WHERE  t.interface_line_id = j.interface_transaction_id
	          
	    AND    NOT EXISTS
	     (SELECT 1
		FROM   rcv_transactions rt
		WHERE  rt.interface_transaction_id =
		       j.interface_transaction_id))
        
        WHERE  (error_message IS NOT NULL OR
	   nvl(j.processing_status_code, 'SUCCEEDED') = 'ERROR');
        /*
          END IF;
        */
      
        xxinv_trx_in_pkg.update_rcv_status(errbuf        => errbuf,
			       retcode       => retcode,
			       p_source_code => p_user_name,
			       p_status      => 'E',
			       p_err_message => l_err_message,
			       p_trx_id      => j.trx_id,
			       p_doc_type    => c_inspect);
      
        message(j.interface_transaction_id ||
	    ' interface_transaction_id status=E');
      
      EXCEPTION
        WHEN no_data_found THEN
          /*          UPDATE xxinv_trx_rcv_in t
            SET status = 'S'
          WHERE trx_id = j.trx_id;*/
          IF nvl(j.processing_status_code, 'SUCCEEDED') NOT IN
	 ('PENDING', 'ERROR') THEN
          
	xxinv_trx_in_pkg.update_rcv_status(errbuf        => errbuf,
			           retcode       => retcode,
			           p_source_code => p_user_name,
			           p_status      => 'S',
			           p_err_message => '',
			           p_trx_id      => j.trx_id,
			           p_doc_type    => c_inspect);
          
          END IF;
          message(j.interface_transaction_id ||
	      ' interface_transaction_id status=S');
      END;
    END LOOP;
    COMMIT;
    ------------------------------------
  EXCEPTION
    WHEN stop_process THEN
    
      ROLLBACK;
      retcode := '2';
      errbuf  := l_err_message;
      fnd_file.put_line(fnd_file.log,
		'Stop Exception in HANDLE_RCV_INSPECT_TRX process');
    
    WHEN OTHERS THEN
    
      ROLLBACK;
      retcode := '2';
      errbuf  := SQLERRM;
      fnd_file.put_line(fnd_file.log,
		'Error in HANDLE_RCV_INSPECT_TRX process');
    
  END handle_rcv_inspect_trx;

  -----------------------------------------------------------------
  -- handle_rcv_po_trx
  ----------------------------------------------------------------
  -- Purpose: handle rcv po trx
  -- handle  PO receiving  transactions
  -----------------------------------------------------------------
  -- Ver   Date        Performer    Comments
  -------  --------    -----------  ---------------------------------
  -- 1.0   15.10.13    IgorR        initial build
  -- 1.1   27.3.14     yuval tal    CHG0031650 : remove call to RVCTP
  -- 2.0   09/02/2021  Roman W.     CHG0049272 - TPL Add Inspection to PO receiving
  -- 2.1   10/03/2021  Roman W.     CHG0049272 - TPL Add Inspection to PO receiving
  --                                      remarked subinventory validation section
  -----------------------------------------------------------------
  PROCEDURE handle_rcv_po_trx(errbuf      OUT VARCHAR2,
		      retcode     OUT VARCHAR2,
		      p_user_name VARCHAR2) IS
  
    l_err_code                 NUMBER;
    l_err_message              VARCHAR2(500);
    l_user_id                  NUMBER;
    l_resp_id                  NUMBER;
    l_resp_appl_id             NUMBER;
    l_organization_id          NUMBER;
    l_org_id                   NUMBER;
    l_interface_transaction_id NUMBER;
    l_header_interface_id      NUMBER;
    l_group_id                 NUMBER;
    ---- out variables for fnd_concurrent.wait_for_request-----
    -- x_phase       VARCHAR2(100);
    --  x_status      VARCHAR2(100);
    --  x_dev_phase   VARCHAR2(100);
    --  x_dev_status  VARCHAR2(100);
    -- l_bool        BOOLEAN;
    --  l_request_id  NUMBER;
    --x_message     VARCHAR2(500);
    l_vendor_id              ap_suppliers.vendor_id%TYPE;
    l_vendor_num             ap_suppliers.segment1%TYPE;
    l_vendor_name            ap_suppliers.vendor_name%TYPE;
    l_subinv_code            mtl_qoh_loc_all_v.subinventory_code%TYPE;
    l_revision               mtl_item_revisions_b.revision%TYPE;
    l_processing_status_code VARCHAR2(50);
  
    l_subinventory       rcv_transactions_interface.subinventory%TYPE; -- Added By Roman W. 09/02/2021 CHG0049272
    l_locator_id         rcv_transactions_interface.locator_id%TYPE; -- Added By Roman W. 09/02/2021 CHG0049272
    l_auto_transact_code rcv_transactions_interface.auto_transact_code%TYPE; -- Added By Roman W. 09/02/2021 CHG0049272
  BEGIN
  
    -- get user details
    get_user_details(p_user_name       => p_user_name,
	         p_user_id         => l_user_id,
	         p_resp_id         => l_resp_id,
	         p_resp_appl_id    => l_resp_appl_id,
	         p_organization_id => l_organization_id,
	         p_err_code        => l_err_code,
	         p_err_message     => l_err_message);
  
    IF l_err_code = 1 THEN
    
      RAISE stop_process;
    END IF;
    -- check required
    validate_rcv_data(errbuf,
	          retcode,
	          'PO',
	          p_user_name,
	          l_organization_id);
    --
  
    ------- initialize ---------
    fnd_global.apps_initialize(l_user_id, l_resp_id, l_resp_appl_id);
  
    message('org_id=' || fnd_global.org_id);
    l_org_id := fnd_global.org_id;
    mo_global.set_policy_context('S', l_org_id);
    inv_globals.set_org_id(l_org_id);
    mo_global.init('INV');
  
    --- PO ---------------
    SELECT rcv_interface_groups_s.nextval
    INTO   l_group_id
    FROM   dual;
    message('Group_id=' || l_group_id);
  
    SELECT 10 + round(COUNT(*) / g_sleep_mod) * g_sleep_mod_sec
    INTO   g_sleep
    FROM   xxinv_trx_rcv_in t
    WHERE  t.doc_type = 'PO'
    AND    t.status = 'N'
    AND    t.source_code = p_user_name;
  
    FOR k IN c_rcv_header('PO', p_user_name)
    LOOP
    
      BEGIN
        SAVEPOINT header_sp;
      
        BEGIN
          SELECT DISTINCT t.vendor_name,
		  t.vendor_id,
		  t.segment1
          INTO   l_vendor_name,
	     l_vendor_id,
	     l_vendor_num
          FROM   ap_suppliers   t,
	     po_headers_all p
          WHERE  t.vendor_id = p.vendor_id
          AND    p.po_header_id = k.order_header_id;
        
        EXCEPTION
          WHEN OTHERS THEN
	message('Invalid Vendor');
	l_err_message := 'Invalid Vendor';
          
	xxinv_trx_in_pkg.update_rcv_status(errbuf        => errbuf,
			           retcode       => retcode,
			           p_source_code => p_user_name,
			           p_status      => 'E',
			           p_err_message => l_err_message,
			           p_group_id    => l_group_id,
			           p_doc_type    => 'PO');
          
	errbuf  := 'Invalid Vendor';
	retcode := '2';
	CONTINUE;
          
        END;
      
        BEGIN
          INSERT INTO rcv_headers_interface
	(org_id,
	 header_interface_id,
	 group_id,
	 processing_status_code,
	 receipt_source_code,
	 transaction_type,
	 auto_transact_code,
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
	 packing_slip,
	 vendor_id,
	 vendor_num,
	 vendor_name)
          VALUES
	(l_org_id, ---> ORG_ID
	 rcv_headers_interface_s.nextval, ---> HEADER_INTERFACE_ID
	 l_group_id, ---> GROUP_ID
	 'PENDING', ---> PROCESSING_STATUS_CODE
	 'VENDOR', ---> RECEIPT_SOURCE_CODE
	 'NEW', ---> TRANSACTION_TYPE
	 'DELIVER', ---> AUTO_TRANSACT_CODE
	 SYSDATE, ---> LAST_UPDATE_DATE
	 0, ---> LAST_UPDATE_BY
	 0, ---> LAST_UPDATE_LOGIN
	 SYSDATE, ---> CREATION_DATE
	 0, ---> CREATED_BY
	 k.shipment_number, ---> SHIPMENT_NUM
	 l_organization_id, ---> SHIP_TO_ORGANIZATION_ID
	 fnd_global.employee_id, ---> EMPLOYEE_ID
	 'Y', ---> VALIDATION_FLAG
	 SYSDATE, ---> TRANSACTION_DATE
	 k.packing_slip, ---> PACKING_SLIP
	 l_vendor_id, ---> VENDOR_ID
	 l_vendor_num, ---> VENDOR_NUM
	 l_vendor_name ---> VENDOR_NAME
	 )
          RETURNING group_id, header_interface_id INTO l_group_id, l_header_interface_id;
        END;
      
        FOR i IN c_rcv_lines('PO',
		     p_user_name,
		     k.order_header_id,
		     k.shipment_header_id)
        LOOP
        
          l_revision    := NULL;
          l_err_message := NULL;
        
          /****************************************************
            VALIDATIONS
          ****************************************************/
          IF i.subinventory IS NULL THEN
	NULL;
	/* Rem By Roman W. 10/03/2021 CHG0049272
            BEGIN
            
              SELECT DISTINCT t.subinventory_code
                INTO l_subinv_code
                FROM mtl_qoh_loc_all_v t
               WHERE t.locator_id = i.locator_id;
            
            EXCEPTION
              WHEN OTHERS THEN
                message('Invalid Subinventory/Locator');
                l_err_message := 'Invalid Subinventory/Locator';
            
                xxinv_trx_in_pkg.update_rcv_status(errbuf        => errbuf,
                                                   retcode       => retcode,
                                                   p_source_code => p_user_name,
                                                   p_status      => 'E',
                                                   p_err_message => l_err_message,
                                                   p_group_id    => l_group_id,
                                                   p_trx_id      => i.trx_id,
                                                   p_doc_type    => 'PO');
            
                errbuf  := 'Invalid Subinventory/Locator';
                retcode := '2';
                CONTINUE;
            END;
            */
          
          ELSE
	l_subinv_code := i.subinventory;
          END IF;
        
          BEGIN
	l_revision := NULL;
	IF is_revision_control(p_item_code       => i.item_code,
		           p_organization_id => l_organization_id) = 'Y' THEN
	
	  --   l_revision :=
	  get_revision(p_item_code       => i.item_code,
		   p_mode            => 2,
		   p_organization_id => l_organization_id,
		   p_revision        => l_revision,
		   p_err_message     => l_err_message,
		   p_subinv          => i.subinventory,
		   p_locator_id      => i.locator_id,
		   p_serial          => i.from_serial_number,
		   p_lot_number      => i.lot_number);
	
	END IF;
          
          EXCEPTION
	WHEN OTHERS THEN
	  message('Invalid Item ID: ' || i.item_id);
	  l_err_message := 'Invalid Item ID: ' || i.item_id;
	
	  xxinv_trx_in_pkg.update_rcv_status(errbuf        => errbuf,
				 retcode       => retcode,
				 p_source_code => p_user_name,
				 p_status      => 'E',
				 p_err_message => l_err_message,
				 p_group_id    => l_group_id,
				 p_trx_id      => i.trx_id,
				 p_doc_type    => 'PO');
	
	  errbuf  := 'Invalid Item ID: ' || i.item_id;
	  retcode := '2';
	  CONTINUE;
          END;
        
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
	 locator_id,
	 shipment_num,
	 expected_receipt_date,
	 shipped_date,
	 header_interface_id,
	 validation_flag,
	 org_id,
	 po_line_location_id,
	 packing_slip,
	 item_revision)
          VALUES
	(rcv_transactions_interface_s.nextval, ---> INTERFACE_TRANSACTION_ID
	 l_group_id, ---> GROUP_ID
	 SYSDATE, ---> LAST_UPDATE_DATE
	 l_user_id, ---> LAST_UPDATED_BY
	 SYSDATE, ---> CREATION_DATE
	 l_user_id, ---> CREATED_BY
	 l_user_id, ---> LAST_UPDATE_LOGIN
	 'RECEIVE', ---> TRANSACTION_TYPE
	 SYSDATE, ---> TRANSACTION_DATE
	 'PENDING', ---> PROCESSING_STATUS_CODE
	 'BATCH', ---> PROCESSING_MODE_CODE
	 'PENDING', ---> TRANSACTION_STATUS_CODE
	 i.qty_received, ---> QUANTITY
	 i.qty_uom_code, ---> UOM_CODE
	 'RCV', ---> INTERFACE_SOURCE_CODE
	 i.item_id, ---> ITEM_ID
	 l_user_id, ---> EMPLOYEE_ID
	 decode(k.destination_type_code,
	        'RECEIVING',
	        'RECEIVE',
	        'INVENTORY',
	        'DELIVER',
	        'DELIVER'), ---> AUTO_TRANSACT_CODE    -- CHG0049272
	 i.shipment_header_id, ---> SHIPMENT_HEADER_ID
	 i.shipment_line_id, ---> SHIPMENT_LINE_ID
	 NULL, ---> SHIP_TO_LOCATION_ID
	 'VENDOR', ---> RECEIPT_SOURCE_CODE
	 l_organization_id, ---> TO_ORGANIZATION_ID
	 'PO', ---> SOURCE_DOCUMENT_CODE
	 NULL, ---> REQUISITION_LINE_ID
	 NULL, ---> REQ_DISTRIBUTION_ID
	 'INVENTORY', ---> DESTINATION_TYPE_CODE
	 NULL, ---> DELIVER_TO_PERSON_ID
	 NULL, ---> LOCATION_ID
	 NULL, ---> DELIVER_TO_LOCATION_ID
	 decode(k.destination_type_code,
	        'RECEIVING',
	        NULL,
	        'INVENTORY',
	        l_subinv_code,
	        l_subinv_code), ---> SUBINVENTORY        -- CHG0049272
	 decode(k.destination_type_code,
	        'RECEIVING',
	        NULL,
	        'INVENTORY',
	        i.locator_id,
	        i.locator_id), ---> LOCATOR_ID          -- CHG0049272
	 i.shipment_number, ---> SHIPMENT_NUM
	 SYSDATE + 5, ---> EXPECTED_RECEIPT_DATE
	 SYSDATE, --NULL                                   ---> SHIPPED_DATE
	 rcv_headers_interface_s.currval, ---> HEADER_INTERFACE_ID
	 'Y', ---> VALIDATION_FLAG
	 l_org_id, ---> ORG_ID
	 i.po_line_location_id, ---> PO_LINE_LOCATION_ID
	 i.packing_slip, ---> PACKING_SLIP
	 l_revision ---> ITEM_REVISION
	 )
          RETURNING interface_transaction_id INTO l_interface_transaction_id;
          ---  insert serial /lot -------------
          -- if lot control
          -- IF i.lot_number IS NOT NULL THEN  Rem By Roman W. 09/02/2021 CHG0049272
          IF i.lot_number IS NOT NULL AND
	 'RECEIVING' != k.destination_type_code -- CHG0049272
           THEN
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
	   parent_item_id,
	   lot_expiration_date)
	VALUES
	  (mtl_material_transactions_s.nextval, --TRANSACTION_INTERFACE_ID
	   SYSDATE, --LAST_UPDATE_DATE
	   l_user_id, --LAST_UPDATED_BY
	   SYSDATE, --CREATION_DATE
	   l_user_id, --CREATED_BY
	   fnd_global.login_id, --LAST_UPDATE_LOGIN
	   i.lot_number, --LOT_NUMBER
	   i.qty_received, --TRANSACTION_QUANTITY
	   i.qty_received, --PRIMARY_QUANTITY
	   NULL, --  mtl_material_transactions_s.nextval, --SERIAL_TRANSACTION_TEMP_ID
	   'RCV', --PRODUCT_CODE
	   rcv_transactions_interface_s.currval, --PRODUCT_TRANSACTION_ID
	   i.item_id,
	   i.lot_expiration_date);
          
          END IF;
          --  if serial control
          -- IF i.from_serial_number IS NOT NULL THEN  Rem By Roman W. 09/02/2021 CHG0049272
          IF i.from_serial_number IS NOT NULL AND
	 'RECEIVING' != k.destination_type_code -- CHG0049272
           THEN
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
	  (mtl_material_transactions_s.nextval, --TRANSACTION_INTERFACE_ID
	   SYSDATE, --LAST_UPDATE_DATE
	   l_user_id, --LAST_UPDATED_BY
	   SYSDATE, --CREATION_DATE
	   l_user_id, --CREATED_BY
	   fnd_global.login_id, --LAST_UPDATE_LOGIN
	   i.from_serial_number, --FM_SERIAL_NUMBER
	   i.to_serial_number, --TO_SERIAL_NUMBER
	   'RCV', --PRODUCT_CODE
	   rcv_transactions_interface_s.currval, --PRODUCT_TRANSACTION_ID,
	   i.item_id);
          END IF;
        
          ------------- update interface id's
          UPDATE xxinv_trx_rcv_in
          SET    status                   = 'I',
	     interface_transaction_id = l_interface_transaction_id,
	     header_interface_id      = l_header_interface_id,
	     interface_group_id       = l_group_id
          WHERE  trx_id = i.trx_id;
        
          -- delete from temp table to allowed resend in future
          delete_xxinv_trx_resend_orders(errbuf      => errbuf,
			     retcode     => retcode,
			     p_doc_type  => 'PO',
			     p_header_id => i.order_header_id);
          --------------------------------------
        
        END LOOP;
      
      EXCEPTION
        WHEN OTHERS THEN
          ROLLBACK TO header_sp;
          l_err_message := substr(SQLERRM, 1, 255);
        
          UPDATE xxinv_trx_rcv_in t
          SET    status        = 'E',
	     t.err_message = l_err_message
          WHERE  t.doc_type = 'PO'
          AND    t.status = 'N'
          AND    t.source_code = p_user_name
          AND    t.order_header_id = k.order_header_id
          AND    nvl(t.shipment_header_id, -1) =
	     nvl(k.shipment_header_id, -1);
        
      END;
      COMMIT;
    END LOOP; -- packing slip--
  
    ------------ check errors --------
    --    message('Checking Errors');
  
    FOR j IN c_rcv_trx_interface('PO', p_user_name, NULL)
    LOOP
      IF c_rcv_trx_interface%ROWCOUNT = 1 THEN
        dbms_lock.sleep(g_sleep);
      END IF;
    
      BEGIN
      
        SELECT processing_status_code
        INTO   l_processing_status_code
        FROM   rcv_headers_interface t
        WHERE  t.header_interface_id = j.header_interface_id;
      
        IF l_processing_status_code = 'PENDING' THEN
          CONTINUE;
        ELSE
        
          SELECT nvl(error_message, 'XX Unknown error')
          INTO   l_err_message
          FROM   (SELECT REPLACE(listagg(error_message, ' | ') within
		         GROUP(ORDER BY interface_line_id),
		         'Txn Success.') error_message
	      
	      FROM   po_interface_errors t
	      WHERE  t.interface_line_id = j.interface_transaction_id
		
	      AND    NOT EXISTS
	       (SELECT 1
		  FROM   rcv_transactions rt
		  WHERE  rt.interface_transaction_id =
		         j.interface_transaction_id))
          
          WHERE  (error_message IS NOT NULL OR
	     nvl(j.processing_status_code, 'SUCCEEDED') = 'ERROR');
        
        END IF;
      
        xxinv_trx_in_pkg.update_rcv_status(errbuf        => errbuf,
			       retcode       => retcode,
			       p_source_code => p_user_name,
			       p_status      => 'E',
			       p_err_message => l_err_message,
			       p_trx_id      => j.trx_id,
			       p_doc_type    => 'PO');
      
        message(j.interface_transaction_id ||
	    ' interface_transaction_id status=E');
      
      EXCEPTION
        WHEN no_data_found THEN
          /*          UPDATE xxinv_trx_rcv_in t
            SET status = 'S'
          WHERE trx_id = j.trx_id;*/
          IF nvl(j.processing_status_code, 'SUCCEEDED') NOT IN
	 ('PENDING', 'ERROR') THEN
          
	xxinv_trx_in_pkg.update_rcv_status(errbuf        => errbuf,
			           retcode       => retcode,
			           p_source_code => p_user_name,
			           p_status      => 'S',
			           p_err_message => '',
			           p_trx_id      => j.trx_id,
			           p_doc_type    => 'PO');
          
          END IF;
          message(j.interface_transaction_id ||
	      ' interface_transaction_id status=S');
      END;
    END LOOP;
    COMMIT;
    ------------------------------------
  EXCEPTION
    WHEN stop_process THEN
    
      ROLLBACK;
      retcode := '2';
      errbuf  := l_err_message;
      fnd_file.put_line(fnd_file.log,
		'Stop Exception in HANDLE_RCV_PO_TRX process');
    
    WHEN OTHERS THEN
    
      ROLLBACK;
      retcode := '2';
      errbuf  := SQLERRM;
      fnd_file.put_line(fnd_file.log, 'Error in HANDLE_RCV_PO_TRX process');
    
  END handle_rcv_po_trx;

  -----------------------------------------------------------------
  -- handle_rcv_rma_trx
  ----------------------------------------------------------------
  -- Purpose: handle rcv rma trx
  -- handle  RMA receiving  transactions
  -----------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------------------
  --     1.0  21.10.13  IgorR           initial build
  --     1.1  27.3.14   yuval tal       CHG0031650 : remove call to RVCTP
  -----------------------------------------------------------------
  PROCEDURE handle_rcv_rma_trx(errbuf      OUT VARCHAR2,
		       retcode     OUT VARCHAR2,
		       p_user_name VARCHAR2) IS
  
    l_err_code        NUMBER;
    l_err_message     VARCHAR2(500);
    l_user_id         NUMBER;
    l_resp_id         NUMBER;
    l_resp_appl_id    NUMBER;
    l_organization_id NUMBER;
    l_org_id          NUMBER;
  
    l_interface_transaction_id NUMBER;
    l_header_interface_id      NUMBER;
    l_group_id                 NUMBER;
    ---- out variables for fnd_concurrent.wait_for_request-----
    -- x_phase                   VARCHAR2(100);
    -- x_status                  VARCHAR2(100);
    --  x_dev_phase               VARCHAR2(100);
    --  x_dev_status              VARCHAR2(100);
    -- l_bool       BOOLEAN;
    -- l_request_id NUMBER;
    -- x_message                 VARCHAR2(500);
    l_subinv_code             VARCHAR2(30);
    l_customer_id             hz_cust_accounts.cust_account_id%TYPE;
    l_customer_party_name     hz_parties.party_name%TYPE;
    l_customer_account_number hz_cust_accounts.account_number%TYPE;
  
    l_revision               mtl_item_revisions_b.revision%TYPE;
    l_processing_status_code VARCHAR2(50);
  
  BEGIN
  
    --
    -- get user details
    get_user_details(p_user_name       => p_user_name,
	         p_user_id         => l_user_id,
	         p_resp_id         => l_resp_id,
	         p_resp_appl_id    => l_resp_appl_id,
	         p_organization_id => l_organization_id,
	         p_err_code        => l_err_code,
	         p_err_message     => l_err_message);
  
    IF l_err_code = 1 THEN
    
      RAISE stop_process;
    END IF;
  
    -- check required
    validate_rcv_data(errbuf,
	          retcode,
	          'OE',
	          p_user_name,
	          l_organization_id);
    -- check serial valid
    check_rma_serial_valid(errbuf, retcode, p_user_name);
    ------- initialize ---------
    fnd_global.apps_initialize(l_user_id, l_resp_id, l_resp_appl_id);
  
    message('org_id=' || fnd_global.org_id);
    l_org_id := fnd_global.org_id;
    mo_global.set_policy_context('S', l_org_id);
    inv_globals.set_org_id(l_org_id);
    mo_global.init('INV');
  
    --- RMA ---------------
    SELECT rcv_interface_groups_s.nextval
    INTO   l_group_id
    FROM   dual;
  
    SELECT 10 + round(COUNT(*) / g_sleep_mod) * g_sleep_mod_sec
    INTO   g_sleep
    FROM   xxinv_trx_rcv_in t
    WHERE  t.doc_type = 'OE'
    AND    t.status = 'N'
    AND    t.source_code = p_user_name;
  
    FOR k IN c_rcv_header('OE', p_user_name)
    LOOP
      BEGIN
        SAVEPOINT header_sp;
        BEGIN
          SELECT t.cust_account_id customer_id,
	     p.party_name      customer_party_name,
	     t.account_number  customer_account_number
          INTO   l_customer_id,
	     l_customer_party_name,
	     l_customer_account_number
          FROM   hz_cust_accounts     t,
	     hz_parties           p,
	     oe_order_headers_all o
          WHERE  o.header_id = k.order_header_id
          AND    p.party_id = t.party_id
          AND    t.cust_account_id = o.sold_to_org_id;
        
        EXCEPTION
          WHEN OTHERS THEN
	message('Invalid Customer');
	RAISE stop_process;
        END;
      
        BEGIN
          INSERT INTO rcv_headers_interface
	(org_id,
	 header_interface_id,
	 group_id,
	 processing_status_code,
	 receipt_source_code,
	 transaction_type,
	 auto_transact_code,
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
	 packing_slip,
	 customer_id,
	 customer_party_name,
	 customer_account_number,
	 expected_receipt_date)
          VALUES
	(l_org_id ---> ORG_ID
	,
	 rcv_headers_interface_s.nextval ---> HEADER_INTERFACE_ID
	,
	 l_group_id ---> GROUP_ID
	,
	 'PENDING' ---> PROCESSING_STATUS_CODE
	,
	 'CUSTOMER' ---> RECEIPT_SOURCE_CODE
	,
	 'NEW' ---> TRANSACTION_TYPE
	,
	 'DELIVER' ---> AUTO_TRANSACT_CODE
	,
	 SYSDATE ---> LAST_UPDATE_DATE
	,
	 0 ---> LAST_UPDATE_BY
	,
	 0 ---> LAST_UPDATE_LOGIN
	,
	 SYSDATE ---> CREATION_DATE
	,
	 0 ---> CREATED_BY
	,
	 k.shipment_number ---> SHIPMENT_NUM
	,
	 l_organization_id ---> SHIP_TO_ORGANIZATION_ID
	,
	 fnd_global.employee_id ---> EMPLOYEE_ID
	,
	 'Y' ---> VALIDATION_FLAG
	,
	 SYSDATE ---> TRANSACTION_DATE
	,
	 k.packing_slip ---> PACKING_SLIP
	,
	 l_customer_id ---> CUSTOMER_ID
	,
	 l_customer_party_name ---> CUSTOMER_PARTY_NAME
	,
	 NULL --l_customer_account_number ---> CUSTOMER_ACCOUNT_NUMBER
	,
	 SYSDATE ---> EXPECTED_RECEIPT_DATE
	 )
          RETURNING group_id, header_interface_id INTO l_group_id, l_header_interface_id;
        
        END;
      
        FOR i IN c_rcv_lines('OE',
		     p_user_name,
		     k.order_header_id,
		     k.shipment_header_id)
        LOOP
        
          l_revision    := NULL;
          l_err_message := NULL;
        
          /****************************************************
            VALIDATIONS
          ****************************************************/
          IF i.subinventory IS NULL THEN
          
	BEGIN
	
	  SELECT DISTINCT t.subinventory_code
	  INTO   l_subinv_code
	  FROM   mtl_qoh_loc_all_v t
	  WHERE  t.locator_id = i.locator_id;
	
	EXCEPTION
	  WHEN OTHERS THEN
	    message('Invalid Subinventory/Locator');
	    l_err_message := 'Invalid Subinventory/Locator';
	  
	    xxinv_trx_in_pkg.update_rcv_status(errbuf        => errbuf,
				   retcode       => retcode,
				   p_source_code => p_user_name,
				   p_status      => 'E',
				   p_err_message => l_err_message,
				   p_group_id    => l_group_id,
				   p_trx_id      => i.trx_id,
				   p_doc_type    => 'OE');
	  
	    errbuf  := 'Invalid Subinventory/Locator';
	    retcode := '2';
	    CONTINUE;
	END;
          
          ELSE
	l_subinv_code := i.subinventory;
          END IF;
        
          BEGIN
	l_revision := NULL;
	IF is_revision_control(p_item_code       => i.item_code,
		           p_organization_id => l_organization_id) = 'Y' THEN
	
	  --   l_revision :=
	  get_revision(p_item_code       => i.item_code,
		   p_mode            => 2,
		   p_organization_id => l_organization_id,
		   p_subinv          => i.subinventory,
		   p_revision        => l_revision,
		   p_err_message     => l_err_message,
		   p_locator_id      => i.locator_id,
		   p_serial          => i.from_serial_number,
		   p_lot_number      => i.lot_number);
	
	END IF;
          
          EXCEPTION
	WHEN OTHERS THEN
	  message('Invalid Item ID: ' || i.item_id);
	  l_err_message := 'Invalid Item ID: ' || i.item_id;
	
	  xxinv_trx_in_pkg.update_rcv_status(errbuf        => errbuf,
				 retcode       => retcode,
				 p_source_code => p_user_name,
				 p_status      => 'E',
				 p_err_message => l_err_message,
				 p_group_id    => l_group_id,
				 p_trx_id      => i.trx_id,
				 p_doc_type    => 'OE');
	  errbuf  := 'Invalid Item ID: ' || i.item_id;
	  retcode := '2';
	  CONTINUE;
          END;
          /****************************************************/
        
          INSERT INTO rcv_transactions_interface
	(interface_transaction_id,
	 group_id,
	 header_interface_id,
	 last_update_date,
	 last_updated_by,
	 creation_date,
	 created_by,
	 transaction_type,
	 transaction_date,
	 processing_status_code,
	 processing_mode_code,
	 transaction_status_code,
	 quantity,
	 interface_source_code,
	 item_id,
	 uom_code,
	 employee_id,
	 auto_transact_code,
	 primary_quantity,
	 receipt_source_code,
	 to_organization_id,
	 source_document_code,
	 destination_type_code,
	 deliver_to_location_id,
	 subinventory,
	 locator_id,
	 expected_receipt_date,
	 oe_order_header_id,
	 oe_order_line_id,
	 customer_id,
	 customer_site_id,
	 validation_flag,
	 packing_slip,
	 item_revision)
          VALUES
	(rcv_transactions_interface_s.nextval ---> INTERFACE_TRANSACTION_ID
	,
	 l_group_id ---> GROUP_ID
	,
	 rcv_headers_interface_s.currval ---> HEADER_INTERFACE_ID
	,
	 SYSDATE ---> LAST_UPDATE_DATE
	,
	 l_user_id ---> LAST_UPDATED_BY
	,
	 SYSDATE ---> CREATION_DATE
	,
	 l_user_id ---> CREATED_BY
	,
	 'RECEIVE' ---> TRANSACTION_TYPE
	,
	 SYSDATE ---> TRANSACTION_DATE
	,
	 'PENDING' ---> PROCESSING_STATUS_CODE
	,
	 'BATCH' ---> PROCESSING_MODE_CODE
	,
	 'PENDING' ---> TRANSACTION_STATUS_CODE
	,
	 i.qty_received ---> QUANTITY
	,
	 'RCV' ---> INTERFACE_SOURCE_CODE
	,
	 i.item_id ---> ITEM_ID
	,
	 i.qty_uom_code ---> UOM_CODE
	,
	 l_user_id ---> EMPLOYEE_ID
	,
	 'DELIVER' ---> AUTO_TRANSACT_CODE
	,
	 1 ---> PRIMARY_QUANTITY
	,
	 'CUSTOMER' ---> RECEIPT_SOURCE_CODE
	,
	 l_organization_id ---> TO_ORGANIZATION_ID
	,
	 'RMA' ---> SOURCE_DOCUMENT_CODE
	,
	 'INVENTORY' ---> DESTINATION_TYPE_CODE
	,
	 NULL ---> DELIVER_TO_LOCATION_ID
	,
	 i.subinventory ---> SUBINVENTORY
	,
	 i.locator_id,
	 SYSDATE ---> EXPECTED_RECEIPT_DATE
	,
	 i.order_header_id ---> OE_ORDER_HEADER_ID
	,
	 i.order_line_id ---> OE_ORDER_LINE_ID
	,
	 l_customer_id ---> CUSTOMER_ID
	,
	 NULL ---> CUSTOMER_SITE_ID
	,
	 'Y' ---> VALIDATION_FLAG
	,
	 i.packing_slip ---> PACKING_SLIP
	,
	 l_revision ---> ITEM_REVISION
	 )
          RETURNING interface_transaction_id INTO l_interface_transaction_id;
        
          message('rcv_transactions_interface interface_transaction_id=' ||
	      l_interface_transaction_id);
        
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
	   parent_item_id,
	   lot_expiration_date)
	VALUES
	  (mtl_material_transactions_s.nextval, --TRANSACTION_INTERFACE_ID
	   SYSDATE, --LAST_UPDATE_DATE
	   l_user_id, --LAST_UPDATED_BY
	   SYSDATE, --CREATION_DATE
	   l_user_id, --CREATED_BY
	   fnd_global.login_id, --LAST_UPDATE_LOGIN
	   i.lot_number, --LOT_NUMBER
	   i.qty_received, --TRANSACTION_QUANTITY
	   i.qty_received, --PRIMARY_QUANTITY
	   NULL, --  mtl_material_transactions_s.nextval, --SERIAL_TRANSACTION_TEMP_ID
	   'RCV', --PRODUCT_CODE
	   rcv_transactions_interface_s.currval, --PRODUCT_TRANSACTION_ID
	   i.item_id,
	   i.lot_expiration_date);
          
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
	  (mtl_material_transactions_s.nextval, --TRANSACTION_INTERFACE_ID
	   SYSDATE, --LAST_UPDATE_DATE
	   l_user_id, --LAST_UPDATED_BY
	   SYSDATE, --CREATION_DATE
	   l_user_id, --CREATED_BY
	   fnd_global.login_id, --LAST_UPDATE_LOGIN
	   i.from_serial_number, --FM_SERIAL_NUMBER
	   i.to_serial_number, --TO_SERIAL_NUMBER
	   'RCV', --PRODUCT_CODE
	   rcv_transactions_interface_s.currval, --PRODUCT_TRANSACTION_ID,
	   i.item_id);
          END IF;
        
          ------------- update interface id's
          UPDATE xxinv_trx_rcv_in
          SET    status                   = 'I',
	     interface_transaction_id = l_interface_transaction_id,
	     header_interface_id      = l_header_interface_id,
	     interface_group_id       = l_group_id
          WHERE  trx_id = i.trx_id;
        
          -- delete from temp table to allowed resend in future
          delete_xxinv_trx_resend_orders(errbuf      => errbuf,
			     retcode     => retcode,
			     p_doc_type  => 'OE',
			     p_header_id => i.order_header_id);
        
        --------------------------------------
        
        END LOOP;
      
      EXCEPTION
        WHEN OTHERS THEN
          ROLLBACK TO header_sp;
          l_err_message := substr(SQLERRM, 1, 255);
        
          UPDATE xxinv_trx_rcv_in t
          SET    status        = 'E',
	     t.err_message = l_err_message
          WHERE  t.doc_type = 'OE'
          AND    t.status = 'N'
          AND    t.source_code = p_user_name
          AND    t.order_header_id = k.order_header_id
          AND    nvl(t.shipment_header_id, -1) =
	     nvl(k.shipment_header_id, -1);
        
      END;
      COMMIT;
    END LOOP; -- packing slip--
  
    -- check errors
    FOR j IN c_rcv_trx_interface('OE', p_user_name, NULL)
    LOOP
      IF c_rcv_trx_interface%ROWCOUNT = 1 THEN
        dbms_lock.sleep(g_sleep);
      END IF;
    
      BEGIN
      
        SELECT processing_status_code
        INTO   l_processing_status_code
        FROM   rcv_headers_interface t
        WHERE  t.header_interface_id = j.header_interface_id;
      
        IF l_processing_status_code = 'PENDING' THEN
          CONTINUE;
        ELSE
        
          SELECT nvl(error_message, 'XX Unknown error')
          INTO   l_err_message
          FROM   (SELECT REPLACE(listagg(error_message, ' | ') within
		         GROUP(ORDER BY interface_line_id),
		         'Txn Success.') error_message
	      
	      FROM   po_interface_errors t
	      WHERE  t.interface_line_id = j.interface_transaction_id
		
	      AND    NOT EXISTS
	       (SELECT 1
		  FROM   rcv_transactions rt
		  WHERE  rt.interface_transaction_id =
		         j.interface_transaction_id))
          
          WHERE  (error_message IS NOT NULL OR
	     nvl(j.processing_status_code, 'SUCCEEDED') = 'ERROR');
        
        END IF;
      
        xxinv_trx_in_pkg.update_rcv_status(errbuf        => errbuf,
			       retcode       => retcode,
			       p_source_code => p_user_name,
			       p_status      => 'E',
			       p_err_message => l_err_message,
			       p_trx_id      => j.trx_id,
			       p_doc_type    => 'OE');
      
        message(j.interface_transaction_id ||
	    ' interface_transaction_id status=E');
      
      EXCEPTION
        WHEN no_data_found THEN
        
          IF nvl(j.processing_status_code, 'SUCCEEDED') NOT IN
	 ('PENDING', 'ERROR') THEN
          
	xxinv_trx_in_pkg.update_rcv_status(errbuf        => errbuf,
			           retcode       => retcode,
			           p_source_code => p_user_name,
			           p_status      => 'S',
			           p_err_message => '',
			           p_trx_id      => j.trx_id,
			           p_doc_type    => 'OE');
          
	message(j.interface_transaction_id ||
	        ' interface_transaction_id status=S');
          END IF;
      END;
    END LOOP;
    COMMIT;
    ------------------------------------
  EXCEPTION
    WHEN stop_process THEN
    
      ROLLBACK;
      retcode := '2';
      errbuf  := l_err_message;
      message(l_err_message);
      fnd_file.put_line(fnd_file.log,
		'Stop Exception in HANDLE_RCV_RMA_TRX process');
    
    WHEN OTHERS THEN
    
      ROLLBACK;
      retcode := '2';
      errbuf  := SQLERRM;
      message('Error in HANDLE_RCV_RMA_TRX process: ' ||
	  substr(SQLERRM, 1, 200));
      fnd_file.put_line(fnd_file.log,
		'Error in HANDLE_RCV_RMA_TRX process');
    
  END handle_rcv_rma_trx;

  -----------------------------------------------------------------
  -- handle_rcv_mo_trx
  ----------------------------------------------------------------
  -- Purpose: handle rcv mo trx
  -- handle  MO receiving  transactions
  -----------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------------------
  --     1.0  23.10.13  IgorR           initial build
  --     1.1  2.7.14    noam yanai      CHG0032573 :Prevent move from Asset to non asset and vice versa
  --     2.0  05/08/14  noam yanay      CHG0032515 : handle problems with letter case in lot and serial
  -----------------------------------------------------------------
  PROCEDURE handle_rcv_mo_trx(errbuf      OUT VARCHAR2,
		      retcode     OUT VARCHAR2,
		      p_user_name VARCHAR2) IS
  
    CURSOR c_trx IS
      SELECT xtri.*,
	 xtro.from_subinventory out_from_sub,
	 xtro.from_locator_id   out_from_loc
      FROM   xxinv_trx_rcv_in  xtri,
	 xxinv_trx_rcv_out xtro
      WHERE  xtri.source_code = p_user_name
      AND    xtri.line_id = xtro.line_id(+)
      AND    xtri.doc_type = 'MO'
      AND    xtri.status = 'N';
  
    CURSOR c_trx_check IS
      SELECT xtri.rowid row_id,
	 xtri.*
      FROM   xxinv_trx_rcv_in xtri
      WHERE  xtri.source_code = p_user_name
      AND    xtri.doc_type = 'MO'
      AND    xtri.status = 'I';
  
    l_transaction_interface_id NUMBER;
    --
    l_err_code        NUMBER;
    l_err_message     VARCHAR2(2000);
    l_err_msg         VARCHAR2(32000);
    l_user_id         NUMBER;
    l_resp_id         NUMBER;
    l_resp_appl_id    NUMBER;
    l_organization_id NUMBER;
    next_record_exception EXCEPTION;
  
    ---- out variables for fnd_concurrent.wait_for_request-----
    x_phase      VARCHAR2(100);
    x_status     VARCHAR2(100);
    x_dev_phase  VARCHAR2(100);
    x_dev_status VARCHAR2(100);
    l_bool       BOOLEAN;
    l_request_id NUMBER;
    x_message    VARCHAR2(500);
  
    l_reason_id NUMBER;
    l_group_id  NUMBER;
  
    l_return_status VARCHAR2(100);
    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(2000);
    l_msg_index     NUMBER;
    l_check_asset   NUMBER;
  
    l_revision mtl_item_revisions_b.revision%TYPE;
    l_lot      VARCHAR2(80); -- added by noam yanai AUG-2014 CHG0032515
    l_serial   VARCHAR2(30); -- added by noam yanai AUG-2014 CHG0032515
  
  BEGIN
    retcode := 0;
    -- check required
    validate_rcv_data(errbuf, retcode, 'MO', p_user_name);
    --
    -- get user details
    get_user_details(p_user_name       => p_user_name,
	         p_user_id         => l_user_id,
	         p_resp_id         => l_resp_id,
	         p_resp_appl_id    => l_resp_appl_id,
	         p_organization_id => l_organization_id,
	         p_err_code        => l_err_code,
	         p_err_message     => l_err_message);
  
    IF l_err_code = 1 THEN
    
      RAISE stop_process;
    END IF;
    ------- initialize ---------
    fnd_global.apps_initialize(l_user_id, l_resp_id, l_resp_appl_id);
  
    message('ORG_ID=' || fnd_global.org_id);
  
    mo_global.set_policy_context('S', fnd_global.org_id); --
    mo_global.init('INV');
    -------------------------------
  
    -- Update revision
    UPDATE xxinv_trx_rcv_in xtri
    SET    xtri.revision =
           (SELECT MAX(q.revision)
	FROM   inv.mtl_onhand_quantities_detail q
	WHERE  q.organization_id = l_organization_id
	AND    q.subinventory_code = xtri.from_subinventory
	AND    xtri.item_id = q.inventory_item_id)
    WHERE  xtri.doc_type = 'MO'
    AND    xtri.status = 'N';
  
    COMMIT;
    -- get reason id
  
    SELECT rcv_interface_groups_s.nextval
    INTO   l_group_id
    FROM   dual;
    SELECT t.reason_id
    INTO   l_reason_id
    FROM   mtl_transaction_reasons t
    WHERE  t.reason_name = 'Return from SR -TPL interface';
  
    -- Get records to process
  
    SELECT 10 + round(COUNT(*) / g_sleep_mod) * g_sleep_mod_sec
    INTO   g_sleep
    FROM   xxinv_trx_rcv_in t
    WHERE  t.doc_type = 'MO'
    AND    t.status = 'N'
    AND    t.source_code = p_user_name;
  
    FOR i IN c_trx
    LOOP
      l_revision    := NULL;
      l_err_message := NULL;
    
      BEGIN
        SAVEPOINT header_sp;
        l_revision := NULL;
        ------------------------------------- Added by Noam Yanai as part of bug fix CHG0032573
        ------------------------------------- Prevent move from Asset to non asset and vice versa
        SELECT COUNT(DISTINCT t.asset_inventory)
        INTO   l_check_asset
        FROM   mtl_secondary_inventories t
        WHERE  t.secondary_inventory_name IN
	   (i.subinventory, i.from_subinventory)
        AND    t.organization_id = l_organization_id;
      
        IF l_check_asset > 1 THEN
        
          l_err_message := 'Subinventories ' || i.subinventory || ' and ' ||
		   i.from_subinventory ||
		   ' have different ASSET type.';
        
          xxinv_trx_in_pkg.update_rcv_status(errbuf        => errbuf,
			         retcode       => retcode,
			         p_source_code => p_user_name,
			         p_status      => 'E',
			         p_err_message => l_err_message,
			         p_trx_id      => i.trx_id,
			         p_doc_type    => 'MO');
        
        ELSE
          -------------------------------------------------------------------------- from here added by noam yanai AUG-2014 CHG0032515
          BEGIN
	IF i.lot_number IS NOT NULL THEN
	  SELECT ln.lot_number
	  INTO   l_lot
	  FROM   mtl_lot_numbers ln
	  WHERE  ln.organization_id = l_organization_id
	  AND    ln.inventory_item_id = i.item_id
	  AND    ln.lot_number = i.lot_number;
	END IF;
          
          EXCEPTION
	WHEN no_data_found THEN
	  SELECT nvl(MAX(ln.lot_number), i.lot_number)
	  INTO   l_lot
	  FROM   mtl_lot_numbers ln
	  WHERE  ln.organization_id = l_organization_id
	  AND    ln.inventory_item_id = i.item_id
	  AND    upper(ln.lot_number) = upper(i.lot_number);
          END;
        
          BEGIN
	IF i.from_serial_number IS NOT NULL THEN
	  SELECT sn.serial_number
	  INTO   l_serial
	  FROM   mtl_serial_numbers sn
	  WHERE  sn.inventory_item_id = i.item_id
	  AND    sn.serial_number = i.from_serial_number;
	END IF;
          
          EXCEPTION
	WHEN no_data_found THEN
	  SELECT nvl(MAX(sn.serial_number), i.from_serial_number)
	  INTO   l_serial
	  FROM   mtl_serial_numbers sn
	  WHERE  sn.inventory_item_id = i.item_id
	  AND    upper(sn.serial_number) = upper(i.from_serial_number);
          END;
          -------------------------------------------------------------------------- until here added by noam yanai AUG-2014 CHG0032515
        
          IF is_revision_control(p_item_code       => i.item_code,
		         p_organization_id => l_organization_id) = 'Y' THEN
          
	--  l_revision :=
	get_revision(p_item_code       => i.item_code,
		 p_mode            => 1,
		 p_organization_id => l_organization_id,
		 p_revision        => l_revision,
		 p_err_message     => l_err_message,
		 p_subinv          => i.out_from_sub,
		 p_locator_id      => i.out_from_loc,
		 p_serial          => l_serial,
		 p_lot_number      => l_lot);
          
          END IF;
        
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
	 organization_id,
	 subinventory_code,
	 locator_id,
	 transaction_type_id,
	 transaction_action_id,
	 transaction_source_id,
	 transaction_source_type_id,
	 transaction_quantity,
	 transaction_uom,
	 transaction_date,
	 transfer_organization,
	 transfer_subinventory,
	 transfer_locator,
	 transaction_mode,
	 revision,
	 transaction_reference,
	 reason_id)
          VALUES
	(mtl_material_transactions_s.nextval, --- TRANSACTION_INTERFACE_ID
	 SYSDATE, --- CREATION_DATE
	 fnd_global.user_id, --- CREATED_BY
	 SYSDATE, --- LAST_UPDATE_DATE
	 fnd_global.user_id, --- LAST_UPDATE_BY
	 p_user_name || '_MO', --- SOURCE_CODE
	 1, --- SOURCE_LINE_ID
	 1, --- SOURCE_HEADER_ID
	 1, --- PROCESS_FLAG; 1-ready 7-succeeded 3 error
	 i.item_id, --- INVENTORY_ITEM_ID
	 l_organization_id, --- ORGANIZATION_ID
	 nvl(i.from_subinventory, i.out_from_sub), --- SUBINVENTORY_CODE
	 nvl(i.from_locator_id, i.out_from_loc), --- LOCATOR_ID
	 2, --- TRANSACTION_TYPE_ID; 2 - Subinventory Transfer
	 3, --- TRANSACTION_ACTION_ID; 3 - Direct organization transfer
	 NULL, --- TRANSACTION_SOURCE_ID
	 13, --- TRANSACTION_SOURCE_TYPE_ID
	 i.qty_received, --- TRANSACTION_QUANTITY; 41 - Account Alias Receipt
	 i.qty_uom_code, --- TRANSACTION_UOM
	 SYSDATE, --- TRANSACTION_DATE
	 l_organization_id, --- TRANSFER_ORGANIZATION
	 i.subinventory, --- TRANSFER_SUBINVENTORY
	 i.locator_id, --- TRANSFER_LOCATOR
	 3, --- TRANSACTION_MODE; "NULL or 1" - Online Processing, "2" - Concurrent Processing, "3" - Background Processing
	 l_revision, --- REVISION
	 'MOH: ' || to_char(i.order_number) || ' MOL: ' ||
	 to_char(i.order_line_number) || ' SR: ' ||
	 (SELECT x.service_request_reference
	  FROM   xxinv_trx_rcv_out x
	  WHERE  x.order_header_id = i.order_header_id
	  AND    x.order_line_id = i.order_line_id
	  AND    x.doc_type = 'MO'), --- TRANSACTION_REFERENCE
	 l_reason_id --- REASON_ID
	 )
          RETURNING transaction_interface_id INTO l_transaction_interface_id;
        
          IF i.to_serial_number IS NOT NULL THEN
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
	  (l_transaction_interface_id,
	   SYSDATE, -- last_update_date,
	   fnd_global.user_id, --last_updated_by,
	   fnd_global.user_id, --created_by,
	   SYSDATE,
	   l_serial, -- added by noam yanai AUG-2014 CHG0032515
	   l_serial, -- added by noam yanai AUG-2014 CHG0032515
	   i.item_id);
          
          END IF;
        
          -- insert lot
        
          IF i.lot_number IS NOT NULL THEN
	INSERT INTO mtl_transaction_lots_interface
	  (transaction_interface_id,
	   last_update_date,
	   last_updated_by,
	   lot_number,
	   transaction_quantity,
	   creation_date,
	   created_by,
	   parent_item_id,
	   lot_expiration_date)
	VALUES
	  (l_transaction_interface_id,
	   SYSDATE, -- last_update_date,
	   fnd_global.user_id,
	   l_lot, -- added by noam yanai AUG-2014 CHG0032515
	   i.qty_received,
	   SYSDATE,
	   fnd_global.user_id, --created_by,
	   i.item_id,
	   i.lot_expiration_date);
          
          END IF;
        
          ------------- update interface id's
          UPDATE xxinv_trx_rcv_in xtri
          SET    xtri.status                   = 'I',
	     xtri.interface_transaction_id = l_transaction_interface_id,
	     xtri.interface_group_id       = l_group_id
          WHERE  xtri.trx_id = i.trx_id;
        
          --------------------------------------
        END IF; -- l_check_asset > 1
      
      EXCEPTION
        WHEN OTHERS THEN
          ROLLBACK TO header_sp;
          xxinv_trx_in_pkg.update_rcv_status(errbuf        => errbuf,
			         retcode       => retcode,
			         p_source_code => p_user_name,
			         p_status      => 'E',
			         p_err_message => SQLERRM,
			         p_trx_id      => i.trx_id,
			         p_doc_type    => 'MO');
        
      END;
    
      COMMIT;
    END LOOP;
  
    l_request_id := fnd_request.submit_request(application => 'INV',
			           program     => 'INCTCM');
    COMMIT;
  
    IF l_request_id > 0 THEN
      message('Concurrent ''Process transaction interface'' was submitted successfully (request_id=' ||
	  l_request_id || ')');
    
      l_bool := fnd_concurrent.wait_for_request(l_request_id,
				10, --- interval 5  seconds
				600, ---- max wait 120 seconds
				x_phase,
				x_status,
				x_dev_phase,
				x_dev_status,
				x_message);
    
      IF upper(x_dev_phase) = 'COMPLETE' AND
         upper(x_dev_status) IN ('ERROR', 'WARNING') THEN
      
        UPDATE mtl_transactions_interface mti
        SET    mti.process_flag = 3
        WHERE  mti.transaction_interface_id IN
	   (SELECT xtri.interface_transaction_id
	    FROM   xxinv_trx_rcv_in xtri
	    WHERE  xtri.source_code = p_user_name
	    AND    xtri.doc_type = 'MO'
	    AND    xtri.interface_group_id = l_group_id);
        COMMIT;
      
        errbuf := 'The ''Process transaction interface'' concurrent program completed in in status' ||
	      upper(x_dev_status) || '. See log for request_id=' ||
	      l_request_id;
      
        message('errbuf');
      
        xxinv_trx_in_pkg.update_rcv_status(errbuf        => errbuf,
			       retcode       => retcode,
			       p_source_code => p_user_name,
			       p_status      => 'E',
			       p_err_message => errbuf,
			       p_group_id    => l_group_id,
			       p_doc_type    => 'MO');
        retcode := '2';
        COMMIT;
        RETURN;
      
      ELSIF upper(x_dev_phase) = 'COMPLETE' AND
	upper(x_dev_status) = 'NORMAL' THEN
        message('The ''Process transaction interface'' program SUCCESSFULLY COMPLETED for request_id=' ||
	    l_request_id);
      
      ELSE
      
        UPDATE mtl_transactions_interface t
        SET    t.process_flag = 3
        WHERE  t.transaction_interface_id IN
	   (SELECT p.interface_transaction_id
	    FROM   xxinv_trx_rcv_in p
	    WHERE  p.source_code = p_user_name
	    AND    p.doc_type = 'MO'
	    AND    p.interface_group_id = l_group_id);
        COMMIT;
      
        errbuf := 'The ''Process transaction interface'' request failed review log for Oracle request_id=' ||
	      l_request_id;
      
        message(errbuf);
      
        xxinv_trx_in_pkg.update_rcv_status(errbuf        => errbuf,
			       retcode       => retcode,
			       p_source_code => p_user_name,
			       p_status      => 'E',
			       p_err_message => errbuf,
			       p_group_id    => l_group_id,
			       p_doc_type    => 'MO');
        COMMIT;
        retcode := '2';
        RETURN;
      END IF;
    ELSE
      xxinv_trx_in_pkg.update_rcv_status(errbuf        => errbuf,
			     retcode       => retcode,
			     p_source_code => p_user_name,
			     p_status      => 'E',
			     p_err_message => l_err_message,
			     p_group_id    => l_group_id,
			     p_doc_type    => 'MO');
    
      UPDATE mtl_transactions_interface mti
      SET    mti.process_flag = 3
      WHERE  mti.transaction_interface_id IN
	 (SELECT xtri.interface_transaction_id
	  FROM   xxinv_trx_rcv_in xtri
	  WHERE  xtri.source_code = p_user_name
	  AND    xtri.doc_type = 'MO'
	  AND    xtri.interface_group_id = l_group_id);
      COMMIT;
    
      errbuf := 'Concurrent ''Process transaction interface'' submitting PROBLEM';
      message(errbuf);
      retcode := '2';
      RETURN;
    
    END IF;
  
    ------------ check errors --------
  
    FOR j IN c_trx_check
    LOOP
      IF c_trx_check%ROWCOUNT = 1 THEN
        dbms_lock.sleep(g_sleep);
      END IF;
      BEGIN
      
        SELECT t.error_explanation
        INTO   l_err_message
        FROM   mtl_transactions_interface t
        WHERE  t.transaction_interface_id = j.interface_transaction_id;
      
        xxinv_trx_in_pkg.update_rcv_status(errbuf        => errbuf,
			       retcode       => retcode,
			       p_source_code => p_user_name,
			       p_status      => 'E',
			       p_err_message => l_err_message,
			       p_trx_id      => j.trx_id,
			       p_doc_type    => 'MO');
      
        message('interface_transaction_id= ' || j.interface_transaction_id || ' ' ||
	    l_err_message);
      
      EXCEPTION
        WHEN no_data_found THEN
        
          /****************************************************
              Close Move Order Line (Back Order) - Start
          /****************************************************/
        
          message('Calling INV_MO_BACKORDER_PVT to Backorder MO');
          message('===============================');
        
          inv_mo_backorder_pvt.backorder(p_line_id       => j.order_line_id,
			     x_return_status => l_return_status,
			     x_msg_count     => l_msg_count,
			     x_msg_data      => l_msg_data);
        
          message('Return Status is : ' || l_return_status);
        
          -- Check Return Status
          IF l_return_status = fnd_api.g_ret_sts_success THEN
          
	message('Successfully BackOrdered the Move Order Line');
	COMMIT;
          
	xxinv_trx_in_pkg.update_rcv_status(errbuf        => errbuf,
			           retcode       => retcode,
			           p_source_code => p_user_name,
			           p_status      => 'S',
			           p_err_message => '',
			           p_trx_id      => j.trx_id,
			           p_doc_type    => 'MO');
          
	message(j.interface_transaction_id ||
	        ' interface_transaction_id status=S');
          
          ELSE
          
	message('Could not able to Back Order Line Due to Following Reasons');
	ROLLBACK;
          
	FOR j IN 1 .. l_msg_count
	LOOP
	
	  fnd_msg_pub.get(p_msg_index     => j,
		      p_encoded       => fnd_api.g_false,
		      p_data          => l_msg_data,
		      p_msg_index_out => l_msg_index);
	
	  message('Error Message is : ' || l_msg_data);
	  IF l_err_msg IS NULL THEN
	    l_err_msg := l_err_msg || l_msg_data;
	  ELSE
	    l_err_msg := l_err_msg || '; ' || l_msg_data;
	  END IF;
	
	END LOOP;
          
	l_err_message := substr(l_err_msg, 1, 2000);
          
	xxinv_trx_in_pkg.update_rcv_status(errbuf        => errbuf,
			           retcode       => retcode,
			           p_source_code => p_user_name,
			           p_status      => 'E',
			           p_err_message => l_err_message,
			           p_trx_id      => j.trx_id,
			           p_doc_type    => 'MO');
          
          END IF;
        
        /****************************************************
             Close Move Order Line (Back Order) - End
        /****************************************************/
      
      END;
    
    END LOOP;
  
    COMMIT;
  
  EXCEPTION
  
    WHEN stop_process THEN
    
      ROLLBACK;
      retcode := '2';
      errbuf  := l_err_message;
      fnd_file.put_line(fnd_file.log,
		'Stop Exception in HANDLE_RCV_MO_TRX process');
    
    WHEN OTHERS THEN
    
      ROLLBACK;
      retcode := '2';
      errbuf  := SQLERRM;
      fnd_file.put_line(fnd_file.log, 'Error in HANDLE_RCV_MO_TRX process');
    
  END handle_rcv_mo_trx;

  -----------------------------------------------------------------
  -- update_rcv_status
  ----------------------------------------------------------------
  -- Purpose: Update Status in XXOBJT.XXINV_TRX_RCV_IN table
  -----------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------------------
  --     1.0  23.10.13  IgorR           initial build
  -----------------------------------------------------------------
  PROCEDURE update_rcv_status(errbuf        OUT VARCHAR2,
		      retcode       OUT VARCHAR2,
		      p_source_code VARCHAR2,
		      p_status      VARCHAR2,
		      p_err_message VARCHAR2,
		      p_trx_id      NUMBER DEFAULT NULL,
		      p_doc_type    VARCHAR2 DEFAULT NULL,
		      p_group_id    NUMBER DEFAULT NULL) IS
  
  BEGIN
    retcode := 0;
    UPDATE xxinv_trx_rcv_in t
    SET    t.status             = p_status,
           t.err_message        = p_err_message,
           t.program_request_id = fnd_global.conc_request_id,
           t.last_update_date   = SYSDATE,
           t.last_updated_by    = fnd_global.user_id,
           t.last_update_login  = fnd_global.login_id
    WHERE  t.source_code = p_source_code
    AND    t.trx_id = nvl(p_trx_id, t.trx_id)
    AND    t.doc_type = nvl(p_doc_type, t.doc_type)
    AND    nvl(t.interface_group_id, -1) =
           nvl(p_group_id, nvl(t.interface_group_id, -1));
  
    COMMIT;
  
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      retcode := '2';
      errbuf  := 'Error in UPDATE_STATUS: ' || substr(SQLERRM, 1, 200);
    
  END update_rcv_status;

  -----------------------------------------------------------------
  -- print_commercial_invoice
  ----------------------------------------------------------------
  -- Purpose: print_commercial_invoice if al deliveries with released_status NOT IN ('S', 'Y');
  -- called from procedure handle_pick_trx
  -----------------------------------------------------------------
  -- Ver   Date       Performer        Comments
  -- ----  --------   --------------   ---------------------------
  -- 1.0   21.10.13   yuval tal        initial build
  -- 1.1   11/05/2015 Dalit A. Raviv   CHG0034230 All the versions had unified into one:
  --                                   The XX SSUS: Commercial Invoice PDF Output
  -- 1.2  2.10.19    YUVAL TAL         CHG0046435 - ADD parameter p_calling_proc
  -- 1.3  23-OCT-19   Diptasurjya      CHG0046025 - handle order creator mail change for ecommerce orders
  -----------------------------------------------------------------
  PROCEDURE print_commercial_invoice(p_err_message  OUT VARCHAR2,
			 p_err_code     OUT VARCHAR2,
			 p_request_id   OUT NUMBER,
			 p_user_name    VARCHAR2,
			 p_delivery_id  NUMBER,
			 p_calling_proc VARCHAR2) IS
  
    -- out variables for fnd_concurrent.wait_for_request --
    x_phase       VARCHAR2(100);
    x_status      VARCHAR2(100);
    x_dev_phase   VARCHAR2(100);
    x_dev_status  VARCHAR2(100);
    x_return_bool BOOLEAN;
    x_message     VARCHAR2(100);
    --
    l_result BOOLEAN;
    l_to     VARCHAR2(240);
    --
    l_err_code        NUMBER;
    l_err_message     VARCHAR2(500);
    l_user_id         NUMBER;
    l_resp_id         NUMBER;
    l_resp_appl_id    NUMBER;
    l_organization_id NUMBER;
  
    --
    end_program_exception EXCEPTION;
    l_from_mail    VARCHAR2(50);
    l_creator_mail VARCHAR2(500);
    /*CURSOR c_trx IS
    SELECT get_order_creator_mail(delivery_id) creator_mail,
           delivery_id
    FROM   (SELECT DISTINCT t.delivery_id
            FROM   xxinv_trx_pick_in t
            WHERE  t.delivery_id = p_delivery_id
            AND    nvl(t.commercial_status, '-1') != 'S');*/
  
  BEGIN
  
    --------------------------
    -- check commercial report
    ---------------------------
    p_err_code := 0;
  
    IF is_report_submitted(p_calling_proc => p_calling_proc, -- PACK/PICK
		   p_report_type  => 'CI',
		   p_delivery_id  => p_delivery_id) = 'Y' THEN
      RETURN;
    END IF;
    l_creator_mail := get_order_creator_mail(p_delivery_id, 'CI'); -- CHG0046025  add new parameter for doc type
    l_from_mail    := xxinv_trx_out_pkg.get_from_mail_address;
  
    get_user_details(p_user_name       => p_user_name,
	         p_user_id         => l_user_id,
	         p_resp_id         => l_resp_id,
	         p_resp_appl_id    => l_resp_appl_id,
	         p_organization_id => l_organization_id,
	         p_err_code        => l_err_code,
	         p_err_message     => l_err_message);
  
    IF l_err_code = 1 THEN
    
      RAISE stop_process;
    END IF;
    -- initialize --
  
    fnd_global.apps_initialize(l_user_id, l_resp_id, l_resp_appl_id);
  
    --FOR i IN c_trx LOOP
    l_to := fnd_profile.value('XXINV_TPL_CI_REPORT_MAIL') ||
	CASE l_creator_mail
	  WHEN NULL THEN
	   NULL
	  ELSE
	   ', ' || l_creator_mail
	END; -- to address
  
    dbms_output.put_line('l_to=' || l_to);
    -- submit request
    l_result := fnd_request.add_delivery_option(TYPE         => 'E', -- this one to speciy the delivery option as Email
				p_argument1  => 'CI_' ||
					    p_delivery_id, -- subject for the mail
				p_argument2  => l_from_mail, -- l_from_mail, -- from address
				p_argument3  => l_to, -- to address
				p_argument4  => fnd_profile.value('XXINV_TPL_CI_REPORT_CC_MAIL'), -- cc address to be specified here.
				nls_language => ''); -- language option);
    IF l_result THEN
      dbms_output.put_line('delivery ok');
    ELSE
      p_err_code    := 1;
      p_err_message := 'Unable to add_delivery_option';
      RAISE end_program_exception;
    END IF;
    -- 11/05/2015 Dalit A. Raviv CHG0034230
    -- All the versions had unified into one: The XX SSUS: Commercial Invoice PDF Output
    l_result := fnd_request.add_layout(template_appl_name => 'XXOBJT',
			   template_code      => 'XXSSUS_WSHRDINV', --'XXWSH_WSH_Commercial_invoice',
			   template_language  => 'en',
			   template_territory => 'US', --'IL',
			   output_format      => 'PDF');
  
    l_result := fnd_request.set_print_options(printer     => NULL,
			          copies      => 0,
			          save_output => TRUE);
    dbms_output.put_line('delivery_id=' || p_delivery_id);
  
    p_request_id := fnd_request.submit_request(application => 'XXOBJT',
			           program     => 'XXSSUS_WSHRDINV', --'XXWSHRDINV',
			           argument1   => NULL,
			           argument2   => NULL,
			           argument3   => NULL,
			           argument4   => NULL,
			           argument5   => l_organization_id,
			           argument6   => p_delivery_id,
			           argument7   => 'D',
			           argument8   => 'MSTK',
			           argument9   => NULL,
			           argument10  => 'N',
			           argument11  => 'YES',
			           argument12  => 'YES',
			           argument13  => 'N',
			           argument14  => 'N',
			           argument15  => NULL);
  
    COMMIT;
  
    IF p_request_id > 0 THEN
      --wait for program
      x_return_bool := fnd_concurrent.wait_for_request(p_request_id,
				       5, --- interval 10  seconds
				       1200, ---- max wait
				       x_phase,
				       x_status,
				       x_dev_phase,
				       x_dev_status,
				       x_message);
    
      IF upper(x_dev_phase) = 'COMPLETE' AND
         upper(x_dev_status) IN ('ERROR', 'WARNING') THEN
        p_err_message := 'Concurrent ''XX SSUS: Commercial Invoice PDF Output'' completed in ' ||
		 upper(x_dev_status);
        message(p_err_message);
        p_err_code := '1';
      
      ELSIF upper(x_dev_phase) = 'COMPLETE' AND
	upper(x_dev_status) = 'NORMAL' THEN
        -- report generated
        p_err_message := 'Report sent to ' || l_to || ' ' ||
		 fnd_profile.value('XXINV_TPL_REPORT_CC_MAIL_LIST');
        message(p_err_message);
      ELSE
        -- error
        p_err_message := 'Concurrent XX SSUS: Commercial Invoice PDF Output failed ';
        p_err_code    := '1';
        message(p_err_message);
      
      END IF;
    ELSE
      -- submit program failed
      p_err_message := 'failed TO submit Concurrent XX SSUS: Commercial Invoice PDF Output ' ||
	           fnd_message.get();
      message(p_err_message);
      p_err_code := '1';
    END IF;
    -- END LOOP;
    --
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code    := 1;
      p_err_message := SQLERRM;
    
  END print_commercial_invoice;

  --------------------------------------------------------------------------------------------------
  -- print_print_packing_list
  --------------------------------------------------------------------------------------------------
  -- Purpose: print_commercial_invoice if al deliveries with released_status NOT IN ('S', 'Y');
  -- called from procedure handle_pick_trx
  --------------------------------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------------------
  -- 1.0  26.10.14   Noam Yanai      initial build  (CHG0032515 - interfaces to Expeditors)
  -- 1.1  2.10.19    YUVAL TAL         CHG0046435 - ADD parameter p_calling_proc
  --------------------------------------------------------------------------------------------------
  PROCEDURE print_packing_list(p_err_message  OUT VARCHAR2,
		       p_err_code     OUT VARCHAR2,
		       p_request_id   OUT NUMBER,
		       p_user_name    VARCHAR2,
		       p_delivery_id  NUMBER,
		       p_calling_proc VARCHAR2) IS
  
    ---- out variables for fnd_concurrent.wait_for_request-----
    x_phase       VARCHAR2(100);
    x_status      VARCHAR2(100);
    x_dev_phase   VARCHAR2(100);
    x_dev_status  VARCHAR2(100);
    x_return_bool BOOLEAN;
    x_message     VARCHAR2(100);
    --
    l_result BOOLEAN;
    l_to     VARCHAR2(240);
    --
    l_err_code        NUMBER;
    l_err_message     VARCHAR2(500);
    l_user_id         NUMBER;
    l_resp_id         NUMBER;
    l_resp_appl_id    NUMBER;
    l_organization_id NUMBER;
    l_from_mail       VARCHAR2(50);
    l_delivery_name   wsh_new_deliveries.name%TYPE;
    l_creator_mail    VARCHAR2(500);
    --
    end_program_exception EXCEPTION;
  
    /* CURSOR c_trx IS
    SELECT get_order_creator_mail(delivery_id) creator_mail,
           delivery_id
    FROM   (SELECT DISTINCT t.delivery_id
            FROM   xxinv_trx_pick_in t
            WHERE  t.delivery_id = p_delivery_id
            AND    nvl(t.packlist_status, '-1') != 'S');*/
  
    CURSOR c_del_name IS
      SELECT NAME
      FROM   wsh_new_deliveries
      WHERE  delivery_id = p_delivery_id;
  
  BEGIN
    message('print_packing_list p_delivery_id=' || p_delivery_id);
  
    --------------------------
    -- check commercial report
    ---------------------------
    p_err_code := 0;
  
    -- check report already submitted CHG0046435
  
    IF is_report_submitted(p_calling_proc => p_calling_proc, -- PACK/PICK
		   p_report_type  => 'PL',
		   p_delivery_id  => p_delivery_id) = 'Y' THEN
      RETURN;
    END IF;
    l_from_mail    := xxinv_trx_out_pkg.get_from_mail_address;
    l_creator_mail := get_order_creator_mail(p_delivery_id);
  
    get_user_details(p_user_name       => p_user_name,
	         p_user_id         => l_user_id,
	         p_resp_id         => l_resp_id,
	         p_resp_appl_id    => l_resp_appl_id,
	         p_organization_id => l_organization_id,
	         p_err_code        => l_err_code,
	         p_err_message     => l_err_message);
  
    IF l_err_code = 1 THEN
    
      RAISE stop_process;
    END IF;
  
    OPEN c_del_name;
    FETCH c_del_name
      INTO l_delivery_name;
    CLOSE c_del_name;
    ------- initialize ---------
  
    fnd_global.apps_initialize(l_user_id, l_resp_id, l_resp_appl_id);
  
    --  FOR i IN c_trx LOOP
    l_to := l_creator_mail || ', ' ||
	fnd_profile.value('XXINV_TPL_PACKING_LIST_REPORT_MAIL') ||
	CASE l_creator_mail
	  WHEN NULL THEN
	   NULL
	  ELSE
	   ', ' || l_creator_mail
	END; -- to address
  
    -- l_to := 'yuval.tal@stratasys.com, sys@expeditors.com'; --'yuval.tal@stratasys.com, dror.panhi@stratasys.com';
    dbms_output.put_line('l_to=' || l_to);
    -- submit request
    l_result := fnd_request.add_delivery_option(TYPE        => 'E', -- this one to speciy the delivery option as Email
				p_argument1 => 'PL_' ||
					   p_delivery_id, -- subject for the mail
				p_argument2 => l_from_mail, -- l_from_mail, -- from address
				p_argument3 => l_to, -- to address
				--      p_argument4 => fnd_profile.value('XXINV_TPL_CI_REPORT_CC_MAIL'), -- cc address to be specified here.
				nls_language => ''); -- language option);
    IF l_result THEN
    
      dbms_output.put_line('delivery ok');
    ELSE
      p_err_code    := 1;
      p_err_message := 'Unable to add_delivery_option';
      RAISE end_program_exception;
    END IF;
  
    l_result := fnd_request.add_layout(template_appl_name => 'XXOBJT',
			   template_code      => 'XXWSHRDPAKSM',
			   template_language  => 'en',
			   template_territory => 'IL',
			   output_format      => 'PDF');
  
    l_result := fnd_request.set_print_options(printer     => NULL,
			          copies      => 0,
			          save_output => TRUE);
  
    p_request_id := fnd_request.submit_request(application => 'XXOBJT',
			           program     => 'XXWSHRDPAKSM',
			           argument1   => l_organization_id, -- Warehouse
			           argument2   => nvl(l_delivery_name,
					      to_char(p_delivery_id)), -- Delivery Name
			           argument3   => 'N', -- Print Customer Item ('No')
			           argument4   => 'D', -- Item Display Option ('Description')
			           argument5   => 'DRAFT', -- Print Mode ('Draft')
			           argument6   => 'INV', -- Sort Option ('Inventory Item Number')
			           argument7   => NULL, -- Delivery Date (Low)
			           argument8   => NULL, -- Delivery Date (High)
			           argument9   => NULL, -- Freight Carrier
			           argument10  => fnd_profile.value('REPORT_QUANTITY_PRECISION'), -- Quantity Precision
			           argument11  => 'Y', -- Display Unshipped Items ('Yes')
			           argument12  => '1' -- Send Mail ('Yes')
			           );
  
    -- message(p_request_id);
  
    COMMIT;
  
    IF p_request_id > 0 THEN
      --wait for program
      x_return_bool := fnd_concurrent.wait_for_request(p_request_id,
				       5, --- interval 10  seconds
				       1200, ---- max wait
				       x_phase,
				       x_status,
				       x_dev_phase,
				       x_dev_status,
				       x_message);
    
      IF upper(x_dev_phase) = 'COMPLETE' AND
         upper(x_dev_status) IN ('ERROR', 'WARNING') THEN
        p_err_message := 'Concurrent ''XX: Packing List Report PDF Output via Mail'' completed in ' ||
		 upper(x_dev_status);
      
        message(p_err_message);
        p_err_code := '1';
        --  CONTINUE;
      
      ELSIF upper(x_dev_phase) = 'COMPLETE' AND
	upper(x_dev_status) = 'NORMAL' THEN
        -- report generated
        p_err_message := 'Request_id=' || p_request_id ||
		 ' Report sent to ' || l_to; --|| ' ' ||
        --fnd_profile.value('XXINV_TPL_REPORT_CC_MAIL_LIST');
        message(p_err_message);
      
      ELSE
        -- error
        p_err_message := 'XX: Packing List Report PDF Output via Mail failed ';
        p_err_code    := '1';
        message(p_err_message);
      
        -- CONTINUE;
      END IF;
    ELSE
      -- submit program failed
      p_err_message := 'failed TO submit Concurrent XX: Packing List Report PDF Output via Mail ' ||
	           fnd_message.get();
      message(p_err_message);
      p_err_code := '1';
    END IF;
  
    -- END LOOP;
    --
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code    := 1;
      p_err_message := SQLERRM;
    
  END print_packing_list;

  -----------------------------------------------------------------
  -- is_fully_received
  ----------------------------------------------------------------
  -- Purpose: Check if specific Delivery fully received.
  -----------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------------------
  --     1.0  30.10.13  IgorR           initial build
  -----------------------------------------------------------------
  FUNCTION is_fully_received(p_shipment_header_id NUMBER) RETURN VARCHAR2 IS
  
    l_if_last VARCHAR2(1) := 'N';
  
  BEGIN
  
    SELECT decode(COUNT(DISTINCT t.shipment_line_status_code), 0, 'Y', 'N') check_last
    INTO   l_if_last
    FROM   rcv_shipment_lines t
    WHERE  t.shipment_header_id = p_shipment_header_id
    AND    t.shipment_line_status_code != 'FULLY RECEIVED';
  
    RETURN l_if_last;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'N';
    
  END is_fully_received;

  -----------------------------------------------------------------
  -- is_delivery_picked
  ----------------------------------------------------------------
  -- Purpose: Check if specific Delivery fully picked.
  -----------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------------------
  --     1.0  30.10.13  IgorR           initial build
  -----------------------------------------------------------------
  FUNCTION is_delivery_picked(p_delivery_id NUMBER) RETURN VARCHAR2 IS
  
    l_fully_picked VARCHAR2(100) := NULL;
  
  BEGIN
    BEGIN
      SELECT 'Delivery ' || p_delivery_id || ' is closed (shipped).'
      INTO   l_fully_picked
      FROM   wsh_new_deliveries wnd
      WHERE  wnd.delivery_id = p_delivery_id
      AND    wnd.status_code = 'CL';
    
      IF l_fully_picked IS NOT NULL THEN
        RETURN l_fully_picked;
      END IF;
    EXCEPTION
    
      WHEN OTHERS THEN
        NULL;
    END;
  
    SELECT 'Delivery not Fully Picked.'
    INTO   l_fully_picked
    FROM   wsh_new_deliveries wnd
    WHERE  wnd.delivery_id = p_delivery_id
    AND    EXISTS
     (SELECT 1
	FROM   wsh_delivery_assignments wda,
	       wsh_delivery_details     wdd
	WHERE  wda.delivery_id = wnd.delivery_id
	AND    wdd.delivery_detail_id = wda.delivery_detail_id
	AND    wdd.released_status IN ('B', 'R', 'S')); -- B=backorder, R=ready to release, S=released
  
    RETURN l_fully_picked;
  
  EXCEPTION
    WHEN OTHERS THEN
    
      RETURN NULL;
    
  END is_delivery_picked;

  -----------------------------------------------------------------
  -- get_packing_slip_info
  ----------------------------------------------------------------
  -- Purpose: get_packing_slip_info rcv trx
  -- handle check if receipt exists
  -----------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------------------
  --     1.0  24.9.13   yuval tal         initial build
  -----------------------------------------------------------------
  PROCEDURE get_packing_slip_info(p_packing_slip       IN VARCHAR2,
		          l_organization_id    NUMBER,
		          l_receipt_num        OUT VARCHAR2,
		          l_shipment_header_id OUT NUMBER) IS
  
  BEGIN
  
    SELECT t.receipt_num,
           t.shipment_header_id
    INTO   l_receipt_num,
           l_shipment_header_id
    FROM   rcv_shipment_headers t
    WHERE  t.packing_slip = p_packing_slip
    AND    t.ship_to_org_id = l_organization_id;
  
  EXCEPTION
    WHEN OTHERS THEN
      l_receipt_num        := NULL;
      l_shipment_header_id := NULL;
    
  END get_packing_slip_info;

  -----------------------------------------------------------------
  -- is_pto_included
  ----------------------------------------------------------------
  -- Purpose: check if PTO item exists in delivery
  --
  -- Y - exists
  -- N - not exists
  -----------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------------------
  --     1.0  05/11/13  yuval tal       CHG003200515 - initial build
  -----------------------------------------------------------------

  FUNCTION is_pto_included(p_delivery_id NUMBER) RETURN VARCHAR2 IS
    l_tmp VARCHAR2(1);
  BEGIN
  
    SELECT 1
    INTO   l_tmp
    FROM   wsh.wsh_new_deliveries       wd,
           wsh.wsh_delivery_assignments wda,
           wsh.wsh_delivery_details     wdd,
           ont.oe_order_lines_all       oola
    WHERE  wd.delivery_id = wda.delivery_id
    AND    wda.delivery_detail_id = wdd.delivery_detail_id
    AND    nvl(wdd.container_flag, 'N') = 'N'
    AND    wdd.source_line_id = oola.line_id
    AND    oola.line_id = oola.top_model_line_id
    AND    wd.delivery_id = p_delivery_id
    AND    rownum = 1;
  
    RETURN 'Y';
  EXCEPTION
    WHEN no_data_found THEN
      RETURN 'N';
    
  END;

  -----------------------------------------------------------------
  -- IS_FULL_QTY_PICKED
  ----------------------------------------------------------------
  -- Purpose: Return 'Y' if the full qty picked by MOVE_ORDER_LINE_ID
  -- for given  move order line id , compare quantity (according to line id ) in OUT table with quantity in IN table
  -- if there is one mismatch return 'N'
  -----------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------------------
  --     1.0  05/11/13  yuval tal       initial build
  -----------------------------------------------------------------
  FUNCTION is_full_qty_picked(p_move_order_line_id NUMBER) RETURN VARCHAR2 IS
  
    -- check
    CURSOR c_out IS
      SELECT nvl(MIN(o.quantity), -1) out_qty,
	 nvl(SUM(t.picked_quantity), -2) picked_quantity
      FROM   xxinv_trx_ship_out o,
	 xxinv_trx_pick_in  t
      WHERE  o.move_order_line_id = p_move_order_line_id
      AND    o.line_id = t.line_id
      AND    t.status IN ('N', 'S')
      GROUP  BY o.line_id;
  
  BEGIN
  
    FOR i IN c_out
    LOOP
      IF c_out%NOTFOUND THEN
        RETURN 'N';
      END IF;
      IF i.out_qty != i.picked_quantity THEN
        IF i.out_qty > i.picked_quantity THEN
          -- Added by Noam Yanai Feb-2014
          RETURN 'N';
        ELSE
          RETURN 'X';
        END IF;
      END IF;
    END LOOP;
  
    RETURN 'Y';
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'N';
    
  END is_full_qty_picked;

  -----------------------------------------------------------------
  -- is_all_delivery_lines_staged
  ----------------------------------------------------------------
  -- Purpose: Return 'Y' if need to print Commercial Invoice by DELIVERY
  -----------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------------------
  --     1.0  05/11/13  IgorR           initial build
  -----------------------------------------------------------------
  FUNCTION is_all_delivery_lines_staged(p_delivery_id NUMBER) RETURN VARCHAR2 IS
  
    l_return VARCHAR2(1) := 'N';
  
  BEGIN
  
    SELECT decode(COUNT(DISTINCT wdd.released_status),
	      1,
	      decode(MAX(wdd.released_status), 'Y', 'Y', 'N'),
	      'N') print_com_invoice
    INTO   l_return
    FROM   wsh_delivery_assignments wda,
           wsh_delivery_details     wdd
    WHERE  wda.delivery_id = p_delivery_id
    AND    wdd.delivery_detail_id = wda.delivery_detail_id
    AND    wdd.source_code = 'OE'; -- Noam Yanai JUL-2014
  
    RETURN l_return;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'N';
    
  END is_all_delivery_lines_staged;

  -----------------------------------------------------------------
  -- GET_REVISION
  ----------------------------------------------------------------
  -- Purpose: Return Revision by Item Code and Mode
  -- 1 - Lowest in Stock, 2 - Highest in System
  -----------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------------------
  --     1.0  07/11/13  IgorR           initial build
  -----------------------------------------------------------------
  PROCEDURE get_revision(p_item_code       VARCHAR2,
		 p_mode            NUMBER, ---> 1 - Lowest in Stock, 2 - Highest in System
		 p_organization_id NUMBER,
		 p_revision        OUT VARCHAR2,
		 p_err_message     OUT VARCHAR2,
		 p_subinv          VARCHAR2 DEFAULT NULL,
		 p_locator_id      NUMBER DEFAULT NULL,
		 p_serial          VARCHAR2 DEFAULT NULL,
		 p_lot_number      VARCHAR2 DEFAULT NULL) IS
    -- RETURN VARCHAR2 IS
  
    l_revision mtl_item_revisions_b.revision%TYPE;
  
  BEGIN
  
    IF p_mode = 1 THEN
    
      IF p_serial IS NULL THEN
        ---> Mode = 1 (Lowest in Stock), Not Serial
        SELECT MIN(o.revision)
        INTO   l_revision
        FROM   mtl_onhand_quantities_detail o,
	   mtl_system_items_b           i
        WHERE  o.organization_id = i.organization_id
        AND    o.inventory_item_id = i.inventory_item_id
        AND    o.subinventory_code = p_subinv
        AND    nvl(o.locator_id, -77) =
	   nvl(p_locator_id, nvl(o.locator_id, -77))
        AND    i.organization_id = p_organization_id
        AND    i.segment1 = p_item_code
        AND    nvl(o.lot_number, '-77') =
	   nvl(p_lot_number, nvl(o.lot_number, '-77'));
      
      ELSE
      
        ---> Mode = 1 (Lowest in Stock), Serial
        SELECT MIN(o.revision)
        INTO   l_revision
        FROM   mtl_onhand_serial_v o,
	   mtl_system_items_b  i
        WHERE  o.organization_id = i.organization_id
        AND    o.inventory_item_id = i.inventory_item_id
        AND    o.subinventory_code = p_subinv
        AND    nvl(o.locator_id, -77) =
	   nvl(p_locator_id, nvl(o.locator_id, -77))
        AND    i.organization_id = p_organization_id
        AND    i.segment1 = p_item_code
        AND    nvl(o.serial_number, '-77') =
	   nvl(p_serial, nvl(o.serial_number, '-77'));
      
      END IF;
    
    ELSIF p_mode = 2 THEN
    
      ---> Mode = 2  Highest in System
      SELECT decode((SELECT MAX(s.revision)
	        FROM   mtl_serial_numbers s
	        WHERE  s.inventory_item_id = i.inventory_item_id
	        AND    s.serial_number = nvl(p_serial, s.serial_number)),
	        NULL,
	        (SELECT MAX(r.revision)
	         FROM   mtl_item_revisions_b r
	         WHERE  r.inventory_item_id = i.inventory_item_id
	         AND    r.organization_id = p_organization_id
		   /* (SELECT MAX(p.master_organization_id)
                           FROM mtl_parameters p)*/
	         AND    trunc(r.effectivity_date) <= trunc(SYSDATE)),
	        (SELECT MAX(s.revision)
	         FROM   mtl_serial_numbers s
	         WHERE  s.inventory_item_id = i.inventory_item_id
	         AND    s.serial_number = nvl(p_serial, s.serial_number))) revision
      INTO   l_revision
      FROM   mtl_system_items_b i
      WHERE  i.organization_id = p_organization_id
      AND    i.segment1 = p_item_code;
    
    ELSE
      l_revision := '';
    END IF;
  
    -- RETURN l_revision;
    p_revision := l_revision;
    IF l_revision IS NULL THEN
      p_err_message := 'Serial/Lot Item Not Exists in Stock';
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      p_err_message := SQLERRM; --  RETURN '';
  
  END get_revision;

  -----------------------------------------------------------------
  -- is_revision_control
  ----------------------------------------------------------------
  -- Purpose: Return 'Y' for REVISION Control Items
  -----------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------------------
  --     1.0  07/11/13  IgorR           initial build
  -----------------------------------------------------------------
  FUNCTION is_revision_control(p_item_code       VARCHAR2,
		       p_organization_id NUMBER) RETURN VARCHAR2 IS
  
    l_return VARCHAR2(1) := 'N';
  
  BEGIN
  
    SELECT 'Y'
    INTO   l_return
    FROM   mtl_system_items_b t
    WHERE  t.segment1 = p_item_code
    AND    t.organization_id = p_organization_id
    AND    t.revision_qty_control_code = 2;
  
    RETURN l_return;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'N';
    
  END is_revision_control;

  ----------------------------------------------------------------
  -- validate_rcv_data
  ----------------------------------------------------------------
  -- Purpose: when missing values in requirde fields
  --          update  status to E in table xxinv_trx_rcv_in  records
  -----------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------------------
  --     1.0  07/11/13  yuval tal          initial build
  --     1.1  28/04/2015 yuval tal        CHG0033375 -   remove locator_id - required check
  --     1.2  18/11/2019 Bellona.B        CHG0046731 - validate whether PO line is cancelled or not.
  -----------------------------------------------------------------

  PROCEDURE validate_rcv_data(errbuf            OUT VARCHAR2,
		      retcode           OUT VARCHAR2,
		      p_doc_type        VARCHAR2,
		      p_source_code     VARCHAR2,
		      p_organization_id NUMBER DEFAULT NULL) IS
  
    l_miss_filed_name VARCHAR2(150);
    l_err_message     VARCHAR2(500);
    l_expiration_date DATE;
    CURSOR c_lines IS
      SELECT t.*
      FROM   xxinv_trx_rcv_in t
      WHERE  t.doc_type = p_doc_type
      AND    t.status = 'N'
      AND    t.source_code = p_source_code;
  
    l_cancel_flag VARCHAR2(1); --CHG0046731
  BEGIN
    retcode := 0;
    FOR i IN c_lines
    LOOP
      l_miss_filed_name := NULL;
      CASE p_doc_type
      ----------------------------------------------
      -- Added By Roman W. CHG0049272 14/02/2021
      ----------------------------------------------
        WHEN c_inspect THEN
        
          CASE
	WHEN i.lot_number IS NOT NULL AND i.lot_expiration_date IS NULL THEN
	  BEGIN
	    SELECT t.expiration_date
	    INTO   l_expiration_date
	    FROM   mtl_lot_numbers t
	    WHERE  t.organization_id = p_organization_id
	    AND    t.inventory_item_id = i.item_id
	    AND    t.lot_number = i.lot_number;
	  EXCEPTION
	    WHEN no_data_found THEN
	      l_miss_filed_name := 'lot_expiration_date';
	  END;
	
	WHEN i.order_header_id IS NULL THEN
	  l_miss_filed_name := 'order_header_id';
	WHEN i.packing_slip IS NULL THEN
	  l_miss_filed_name := 'packing_slip';
	WHEN i.subinventory IS NULL THEN
	  l_miss_filed_name := 'subinventory';
	WHEN i.qty_uom_code IS NULL THEN
	  l_miss_filed_name := 'qty_uom_code';
	WHEN i.item_id IS NULL THEN
	  l_miss_filed_name := 'item_id';
	WHEN i.po_line_location_id IS NULL THEN
	  l_miss_filed_name := 'po_line_location_id ';
	WHEN i.line_id IS NULL THEN
	  l_miss_filed_name := 'line_id';
	
	WHEN i.po_line_location_id IS NOT NULL THEN
	  BEGIN
	    SELECT plla.cancel_flag
	    INTO   l_cancel_flag
	    FROM   po_line_locations_all plla
	    WHERE  plla.line_location_id = i.po_line_location_id
	    AND    plla.ship_to_organization_id = p_organization_id;
	  EXCEPTION
	    WHEN no_data_found THEN
	      l_cancel_flag := 'N';
	  END;
	
	  IF l_cancel_flag = 'Y' THEN
	    xxinv_trx_in_pkg.update_rcv_status(errbuf        => errbuf,
				   retcode       => retcode,
				   p_source_code => p_source_code,
				   p_status      => 'E',
				   p_err_message => 'Receiving cannot be performed for cancelled line',
				   p_doc_type    => p_doc_type,
				   p_trx_id      => i.trx_id);
	  END IF;
	  --<<END IF l_cancel_flag = 'Y'>>
          --CHG0046731 end
	ELSE
	  NULL;
          END CASE;
          ------------------------------------------------
      -- End Added By Roman W. CHG0049272 14/02/2021
      ------------------------------------------------
        WHEN 'PO' THEN
          NULL;
          -- Rem By Roman W. 09/03/2021 CHG0049272
          -- check required fields ---
          CASE
	WHEN i.lot_number IS NOT NULL AND i.lot_expiration_date IS NULL THEN
	  BEGIN
	    SELECT t.expiration_date
	    INTO   l_expiration_date
	    FROM   mtl_lot_numbers t
	    WHERE  t.organization_id = p_organization_id
	    AND    t.inventory_item_id = i.item_id
	    AND    t.lot_number = i.lot_number;
	  EXCEPTION
	    WHEN no_data_found THEN
	      l_miss_filed_name := 'lot_expiration_date';
	  END;
	
	WHEN i.order_header_id IS NULL THEN
	  l_miss_filed_name := 'order_header_id';
	WHEN i.packing_slip IS NULL THEN
	  l_miss_filed_name := 'packing_slip';
	  --WHEN i.subinventory IS NULL THEN  l_miss_filed_name := 'subinventory'; -- Rem By Roman W. 09/03/2021 CHG0049272
          --WHEN i.locator_id IS NULL THEN  -- CHG0033375
          --  l_miss_filed_name := 'locator_id';
	WHEN i.qty_uom_code IS NULL THEN
	  l_miss_filed_name := 'qty_uom_code';
	WHEN i.item_id IS NULL THEN
	  l_miss_filed_name := 'item_id';
	  -- WHEN i.shipment_header_id IS NULL THEN
          --    l_miss_filed_name := 'shipment_header_id';
          --  WHEN i.shipment_line_id IS NULL THEN
          --    l_miss_filed_name := 'shipment_line_id ';
	WHEN i.po_line_location_id IS NULL THEN
	  l_miss_filed_name := 'po_line_location_id ';
	WHEN i.line_id IS NULL THEN
	  l_miss_filed_name := 'line_id';
	
          --CHG0046731 start
	WHEN i.po_line_location_id IS NOT NULL THEN
	  BEGIN
	    SELECT plla.cancel_flag
	    INTO   l_cancel_flag
	    FROM   po_line_locations_all plla
	    WHERE  plla.line_location_id = i.po_line_location_id
	    AND    plla.ship_to_organization_id = p_organization_id;
	  EXCEPTION
	    WHEN no_data_found THEN
	      l_cancel_flag := 'N';
	  END;
	
	  IF l_cancel_flag = 'Y' THEN
	    xxinv_trx_in_pkg.update_rcv_status(errbuf        => errbuf,
				   retcode       => retcode,
				   p_source_code => p_source_code,
				   p_status      => 'E',
				   p_err_message => 'Receiving cannot be performed for cancelled line',
				   p_doc_type    => p_doc_type,
				   p_trx_id      => i.trx_id);
	  END IF;
	  --<<END IF l_cancel_flag = 'Y'>>
          --CHG0046731 end
	ELSE
	  NULL;
          END CASE;
          --
        WHEN 'OE' THEN
        
          -- check required fields ---
        
          CASE
	WHEN i.lot_number IS NOT NULL AND i.lot_expiration_date IS NULL THEN
	  BEGIN
	    SELECT t.expiration_date
	    INTO   l_expiration_date
	    FROM   mtl_lot_numbers t
	    WHERE  t.organization_id = p_organization_id
	    AND    t.inventory_item_id = i.item_id
	    AND    t.lot_number = i.lot_number;
	  EXCEPTION
	    WHEN no_data_found THEN
	      l_miss_filed_name := 'lot_expiration_date';
	  END;
	WHEN i.order_header_id IS NULL THEN
	  l_miss_filed_name := 'order_header_id';
	WHEN i.order_line_id IS NULL THEN
	  l_miss_filed_name := 'order_line_id';
	WHEN i.packing_slip IS NULL THEN
	  l_miss_filed_name := 'packing_slip';
	WHEN i.subinventory IS NULL THEN
	  l_miss_filed_name := 'subinventory';
	  --WHEN i.locator_id IS NULL THEN
          --  l_miss_filed_name := 'locator_id'; -- CHG0033375
	WHEN i.qty_uom_code IS NULL THEN
	  l_miss_filed_name := 'qty_uom_code';
	WHEN i.qty_received IS NULL THEN
	  l_miss_filed_name := 'qty_received';
	WHEN i.item_id IS NULL THEN
	  l_miss_filed_name := 'item_id';
	WHEN i.line_id IS NULL THEN
	  l_miss_filed_name := 'line_id';
	ELSE
	  NULL;
          END CASE;
          --
        WHEN 'MO' THEN
        
          -- check required fields ---
        
          CASE
	WHEN i.order_header_id IS NULL THEN
	  l_miss_filed_name := 'order_header_id';
	WHEN i.order_line_id IS NULL THEN
	  l_miss_filed_name := 'order_line_id';
	  --  WHEN i.from_subinventory IS NULL THEN
          --   l_miss_filed_name := 'from_subinventory';
	WHEN i.order_number IS NULL THEN
	  l_miss_filed_name := 'order_number';
	  --WHEN i.locator_id IS NULL THEN
          --  l_miss_filed_name := 'locator_id'; -- CHG0033375
	WHEN i.order_line_number IS NULL THEN
	  l_miss_filed_name := 'order_line_number';
	WHEN i.item_id IS NULL THEN
	  l_miss_filed_name := 'item_id';
	WHEN i.line_id IS NULL THEN
	  l_miss_filed_name := 'line_id';
	WHEN i.qty_uom_code IS NULL THEN
	  l_miss_filed_name := 'qty_uom_code';
	WHEN i.qty_received IS NULL THEN
	  l_miss_filed_name := 'qty_received';
	ELSE
	  NULL;
          END CASE;
        
        WHEN 'INTERNAL' THEN
        
          -- check required fields ---
        
          CASE
	WHEN i.shipment_number IS NULL THEN
	  l_miss_filed_name := 'shipment_number';
	WHEN i.subinventory IS NULL THEN
	  l_miss_filed_name := 'subinventory';
	  -- WHEN i.order_line_id IS NULL THEN    CHG0033946 added by noam yanai NOV-14  include inter-organization transfer
          --   l_miss_filed_name := 'order_line_id';
	WHEN i.shipment_header_id IS NULL THEN
	  l_miss_filed_name := 'shipment_header_id';
	  --   WHEN i.order_number IS NULL THEN   CHG0033946 added by noam yanai NOV-14  include inter-organization transfer
          --    l_miss_filed_name := 'order_number';
          --WHEN i.locator_id IS NULL THEN
          --  l_miss_filed_name := 'locator_id'; -- CHG0033375
	WHEN i.shipment_line_id IS NULL THEN
	  l_miss_filed_name := 'shipment_line_id';
	WHEN i.item_id IS NULL THEN
	  l_miss_filed_name := 'item_id';
	WHEN i.line_id IS NULL THEN
	  l_miss_filed_name := 'line_id';
	WHEN i.qty_uom_code IS NULL THEN
	  l_miss_filed_name := 'qty_uom_code';
	WHEN i.qty_received IS NULL THEN
	  l_miss_filed_name := 'qty_received';
	ELSE
	  NULL;
          END CASE;
          --
      
        ELSE
          NULL;
      END CASE;
      -- check error
      IF l_miss_filed_name IS NOT NULL THEN
        l_err_message := REPLACE('field ~FILED is Required',
		         '~FILED',
		         l_miss_filed_name);
        -- update all header lines to E
        xxinv_trx_in_pkg.update_rcv_status(errbuf        => errbuf,
			       retcode       => retcode,
			       p_source_code => p_source_code,
			       p_status      => 'E',
			       p_err_message => l_err_message,
			       p_doc_type    => p_doc_type,
			       p_trx_id      => i.trx_id);
      
      END IF;
    
    END LOOP;
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      retcode := 1;
      errbuf  := SQLERRM;
  END;

  -------------------------------------------------
  -- check_env_string
  -------------------------------------------------
  -- Purpose: check ws SHGW env field
  -- return 1 - fail
  --        0 - success (match)
  -----------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------------------
  --     1.0  07/11/13  yuval tal          initial build
  -----------------------------------------------------------------
  FUNCTION check_env_string(p_env VARCHAR2) RETURN NUMBER IS
    l_env         VARCHAR2(50);
    l_env_profile VARCHAR2(50);
  
  BEGIN
  
    l_env := xxagile_util_pkg.get_bpel_domain;
  
    CASE
      WHEN l_env = 'production' THEN
        l_env_profile := fnd_profile.value('XXINV_TPL_ENV_STRING_PROD');
      
      WHEN l_env = 'default' THEN
        l_env_profile := fnd_profile.value('XXINV_TPL_ENV_STRING_TEST');
      ELSE
        l_env_profile := fnd_profile.value('XXINV_TPL_ENV_STRING_TEST');
      
    END CASE;
  
    IF l_env_profile = p_env THEN
      RETURN 0;
    ELSE
      RETURN 1;
    END IF;
  
    RETURN 1;
  
  END;

  -------------------------------------------------
  -- get_order_creator_mail
  -------------------------------------------------
  -- Purpose: get order creator mail for delivery (use for commercial mail sending)
  -- return : email
  -----------------------------------------------------------------
  -- Version  Date        Performer       Comments
  ----------  --------    --------------  ---------------------------
  --     1.0  07/11/13    yuval tal       initial build - ignore order created by scheduler user user_id=1111
  --     1.1  08/23/2019  Diptasurjya     CHG0046025 - add parameter for doc type
  -----------------------------------------------------------------

  FUNCTION get_order_creator_mail(p_delivery_id NUMBER,
		          p_doc_type    VARCHAR2 DEFAULT NULL)
    RETURN VARCHAR2 IS
    -- CHG0046025 added new parameter
    -- CHG0046025 comment cursor
    /*CURSOR c IS
       SELECT decode(sh.created_by,
           1111,
           NULL,
           xxhr_util_pkg.get_person_email(xxhr_util_pkg.get_user_person_id(sh.created_by)))
       --das.delivery_detail_id, sh.created_by, sh.order_number so
    
       FROM   ont.oe_order_headers_all     sh,
    wsh.wsh_new_deliveries       del,
    wsh.wsh_delivery_assignments das,
    wsh.wsh_delivery_details     dln
    
       WHERE  dln.source_header_id = sh.header_id
       AND    das.delivery_detail_id = dln.delivery_detail_id
       AND    del.organization_id = dln.organization_id
       AND    das.delivery_id = del.delivery_id
       AND    das.delivery_id = p_delivery_id;*/
    l_mail VARCHAR2(500); -- CHG0046025 change size to 500
  BEGIN
    -- CHG0046025 start email derivation for creator
    SELECT listagg(aa.emails, ',') within GROUP(ORDER BY aa.emails)
    INTO   l_mail
    FROM   (SELECT DISTINCT decode(sh.created_by,
		           1111,
		           NULL,
		           nvl(xxhr_util_pkg.get_person_email(xxhr_util_pkg.get_user_person_id(sh.created_by)),
			   decode(nvl(p_doc_type, 'X'),
			          'CI',
			          (SELECT ffv.attribute8
			           FROM   fnd_flex_value_sets ffvs,
				      fnd_flex_values     ffv
			           WHERE  ffvs.flex_value_set_id =
				      ffv.flex_value_set_id
			           AND    ffvs.flex_value_set_name =
				      'XXOM_SF2OA_Order_Types_Mapping'
			           AND    ffv.attribute8 IS NOT NULL
			           AND    ffv.attribute3 =
				      to_char(sh.order_type_id)),
			          NULL))) emails
	FROM   ont.oe_order_headers_all     sh,
	       wsh.wsh_new_deliveries       del,
	       wsh.wsh_delivery_assignments das,
	       wsh.wsh_delivery_details     dln
	WHERE  dln.source_header_id = sh.header_id
	AND    das.delivery_detail_id = dln.delivery_detail_id
	AND    del.organization_id = dln.organization_id
	AND    das.delivery_id = del.delivery_id
	AND    das.delivery_id = p_delivery_id) aa;
    -- CHG0046025 commented below
    /*OPEN c;
    FETCH c
      INTO l_mail;
    CLOSE c;*/
  
    RETURN TRIM(TRIM(both ',' FROM l_mail)); -- CHG0046025 trim , and space from both ends
  END;

  --------------------------------------------------------------------
  --  customization code:
  --  name:               get_user_id
  --  create by:          yuval tal
  --  $Revision:          1.0
  --  creation date:      25.2.14
  --  Purpose :  get user id for user name
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   25.2.14    yuval tal       initial build
  -----------------------------------------------------------------------

  FUNCTION get_user_id(p_user_name VARCHAR2) RETURN NUMBER IS
    l_tmp NUMBER;
  BEGIN
    SELECT user_id
    INTO   l_tmp
    FROM   fnd_user
    WHERE  user_name = p_user_name;
    RETURN l_tmp;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
    
  END;

  -----------------------------------------------------------------
  -- clean_rcv_interface
  ----------------------------------------------------------------
  -- Purpose: called from form XX TPL Error handling/XXTPLERR
  --          after resubmit error transactions
  --          clean error transaction records
  --
  -----------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------------------
  --     1.1  27.3.14   yuval tal       CHG0031650 : initial
  -----------------------------------------------------------------

  PROCEDURE clean_rcv_interface(p_err_msg  OUT VARCHAR2,
		        p_err_code OUT NUMBER,
		        p_trx_id   NUMBER) IS
    CURSOR c IS
      SELECT *
      FROM   xxinv_trx_rcv_in t
      WHERE  t.trx_id = p_trx_id;
  
  BEGIN
    p_err_code := 0;
  
    FOR i IN c
    LOOP
      IF i.doc_type IN ('PO', 'OE', 'INTERNAL') THEN
        IF i.header_interface_id IS NOT NULL THEN
        
          DELETE FROM rcv_headers_interface rhi
          WHERE  rhi.header_interface_id = i.header_interface_id;
        
          DELETE FROM rcv_transactions_interface rti
          WHERE  rti.header_interface_id = i.header_interface_id;
        
          DELETE FROM po_interface_errors pie
          WHERE  pie.interface_header_id = i.header_interface_id;
        
          DELETE FROM mtl_transaction_lots_interface t
          WHERE  t.product_transaction_id = i.header_interface_id;
        
          DELETE FROM mtl_serial_numbers_interface t
          WHERE  t.product_transaction_id = i.header_interface_id;
        
          -- COMMIT;
        
        END IF;
      END IF;
    
    END LOOP;
  
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := 2;
      p_err_msg  := substr(SQLERRM, 1, 255);
  END;

  -----------------------------------------------------------------
  -- is_lot_serial_the_same
  ----------------------------------------------------------------
  -- Purpose: Check if lot/serial sent by TPL is same as requested
  --          in rcv/ship out file regadless of letter case
  -----------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------------------
  --     1.0  06.08.14  Noam Yanai       initial build CHG0032515
  -----------------------------------------------------------------
  FUNCTION is_lot_serial_the_same(p_out_lot_serial VARCHAR2,
		          p_in_lot_serial  VARCHAR2) RETURN VARCHAR2 IS
  
  BEGIN
    IF upper(p_out_lot_serial) = upper(p_in_lot_serial) THEN
      RETURN 'Y';
    ELSE
      RETURN 'N';
    END IF;
  
  END is_lot_serial_the_same;

  -----------------------------------------------------------------
  -- delete_xxinv_trx_resend_orders
  ----------------------------------------------------------------
  -- Purpose: delete from temp table  xxinv_trx_resend_orders
  -- where we keep order till rcv in case of workinf in mode of re sending rcv info
  -----------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------------------
  --     1.0  22.07.14  Noam Yanai       initial build CHG0032515
  -----------------------------------------------------------------
  PROCEDURE delete_xxinv_trx_resend_orders(errbuf      OUT VARCHAR2,
			       retcode     OUT VARCHAR2,
			       p_doc_type  IN VARCHAR2,
			       p_header_id IN NUMBER) IS
  
  BEGIN
  
    IF fnd_profile.value_specific('XXINV_TPL_RESEND_RCV_FILE') = 'Y' THEN
    
      DELETE FROM xxinv_trx_resend_orders xtro
      WHERE  xtro.header_id = p_header_id
      AND    xtro.doc_type = p_doc_type;
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      retcode := '2';
      errbuf  := SQLERRM;
    
  END;
  -----------------------------------------------------------------
  -- is_job_components_picked
  ----------------------------------------------------------------
  -- Purpose: Check if specific job components are fully picked.
  -----------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------------------
  --     1.0  22.07.14  Noam Yanai       initial build CHG0032515
  -----------------------------------------------------------------
  FUNCTION is_job_components_picked(p_organization_id NUMBER,
			p_job_id          NUMBER) RETURN VARCHAR2 IS
  
    l_open_qty NUMBER;
  
  BEGIN
    BEGIN
    
      SELECT SUM(nvl(wro.quantity_open, 0))
      INTO   l_open_qty
      FROM   wip_requirement_operations_v wro,
	 mtl_system_items_b           sib
      WHERE  wro.organization_id = p_organization_id
      AND    wro.wip_entity_id = p_job_id
      AND    wro.wip_supply_type = 1 -- CHG0033946 changed by noam yanai DEC-2014.Consider only supply type=1 (push)
      AND    sib.organization_id = wro.organization_id
      AND    sib.inventory_item_id = wro.inventory_item_id
      AND    nvl(sib.inventory_item_flag, 'N') = 'Y'
      AND    nvl(sib.stock_enabled_flag, 'N') = 'Y';
    
      IF l_open_qty > 0 THEN
        RETURN 'N';
      ELSE
        RETURN 'Y';
      END IF;
    
    EXCEPTION
    
      WHEN OTHERS THEN
        RETURN 'N';
    END;
  
  END is_job_components_picked;

  -----------------------------------------------------------------
  -- IS_FULL_QTY_ISSUED
  ----------------------------------------------------------------
  -- Purpose: Return 'Y' if the full qty picked by MOVE_ORDER_LINE_ID
  -- for given  move order line id , compare quantity (according to line id ) in OUT table with quantity in IN table
  -- if there is one mismatch return 'N'
  -----------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------------------
  --     1.0  22/7/14   noam yanai      initial build CHG0032515
  -----------------------------------------------------------------
  FUNCTION is_full_qty_issued(p_move_order_line_id NUMBER) RETURN VARCHAR2 IS
  
    -- check
    CURSOR c_out IS
      SELECT nvl(MIN(o.component_qnty), -1) out_qty,
	 nvl(SUM(t.component_qnty), -2) picked_quantity
      FROM   xxinv_trx_wip_out o,
	 xxinv_trx_wip_in  t
      WHERE  o.move_order_line_id = p_move_order_line_id
      AND    o.line_id = t.line_id
      AND    t.status IN ('N', 'S')
      GROUP  BY o.line_id;
  
  BEGIN
  
    FOR i IN c_out
    LOOP
      IF c_out%NOTFOUND THEN
        RETURN 'N';
      END IF;
      IF i.out_qty != i.picked_quantity THEN
        IF i.out_qty > i.picked_quantity THEN
          -- Added by Noam Yanai Feb-2014
          RETURN 'N';
        ELSE
          RETURN 'X';
        END IF;
      END IF;
    END LOOP;
  
    RETURN 'Y';
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'N';
    
  END is_full_qty_issued;

  -----------------------------------------------------------------
  -- update_assembly_serial
  ----------------------------------------------------------------
  -- Purpose: update completion serial in case different than issued serial
  -----------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------------------
  --     1.0  22.7.14   Noam Yanai      initial build CHG0032515
  -----------------------------------------------------------------

  PROCEDURE update_assembly_serial(p_job_id NUMBER) IS
  
    l_picked_serial VARCHAR2(30);
    l_item_id       NUMBER;
    l_serial        VARCHAR2(30);
  
  BEGIN
  
    SELECT twi.component_serial_number,
           twi.component_item_id
    INTO   l_picked_serial,
           l_item_id
    FROM   mtl_item_categories_v miv,
           xxinv_trx_wip_in      twi
    WHERE  twi.job_id = p_job_id
    AND    miv.inventory_item_id = twi.component_item_id
    AND    miv.category_set_name(+) = 'Activity Analysis' -- Assuming only the machie component has value in this category
    AND    miv.segment1(+) = 'General'
    AND    miv.organization_id(+) = 91
    AND    twi.status = 'S'
    AND    rownum < 2;
  
    SELECT sn.serial_number
    INTO   l_serial
    FROM   mtl_serial_numbers sn
    WHERE  sn.inventory_item_id = l_item_id
    AND    upper(sn.serial_number) = upper(l_picked_serial);
  
    UPDATE xxinv_trx_wip_in wi
    SET    wi.assembly_serial_number = l_serial
    WHERE  wi.job_id = p_job_id;
  
    COMMIT;
  
  EXCEPTION
    WHEN OTHERS THEN
      NULL;
    
  END update_assembly_serial;

  -----------------------------------------------------------------
  -- handle_wip_issue_trx
  ----------------------------------------------------------------
  -- Purpose: handle wip issue trx
  -----------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------------------
  --     1.0  22.7.14   Noam Yanai      initial build CHG0032515
  -----------------------------------------------------------------
  PROCEDURE handle_wip_issue_trx(errbuf      OUT VARCHAR2,
		         retcode     OUT VARCHAR2,
		         p_user_name VARCHAR2) IS
  
    CURSOR c_trx_pick IS
      SELECT DISTINCT t.move_order_line_id,
	          t.job_number,
	          t.component_item_code item_code
      FROM   xxinv_trx_wip_in t
      WHERE  t.source_code = p_user_name -- 'TPL'
      AND    t.status = 'N';
  
    CURSOR c_trx IS
      SELECT t.*,
	 o.organization_id,
	 o.component_from_subinventory out_subinventory,
	 o.component_from_locator_id   out_locator_id,
	 o.component_serial_number     out_serial, -- added by noam yanai AUG-2014 CHG0032515
	 o.component_lot_number        out_lot, -- added by noam yanai AUG-2014 CHG0032515
	 o.component_revision          out_revision, -- added by noam yanai AUG-2014 CHG0032515
	 o.transaction_temp_id         out_temp_id -- added by noam yanai AUG-2014 CHG0032515
      FROM   xxinv_trx_wip_in  t,
	 xxinv_trx_wip_out o
      WHERE  t.source_code = p_user_name -- 'TPL'
      AND    t.status = 'N'
      AND    o.line_id = t.line_id;
  
    CURSOR c_mo_details(c_move_order_header_id NUMBER) IS
      SELECT mtrh.header_id,
	 mtrh.request_number,
	 mtrh.move_order_type,
	 mtrh.organization_id
      FROM   mtl_txn_request_headers mtrh
      WHERE  mtrh.header_id = c_move_order_header_id;
  
    l_api_version      NUMBER := 1.0;
    x_return_status    VARCHAR2(2);
    x_msg_count        NUMBER := 0;
    x_msg_data         VARCHAR2(500);
    l_transaction_mode NUMBER := 1;
    l_trolin_tbl       inv_move_order_pub.trolin_tbl_type;
    l_mold_tbl         inv_mo_line_detail_util.g_mmtt_tbl_type;
    x_mmtt_tbl         inv_mo_line_detail_util.g_mmtt_tbl_type;
    x_trolin_tbl       inv_move_order_pub.trolin_tbl_type;
    l_transaction_date DATE := SYSDATE;
    l_mo_details       c_mo_details%ROWTYPE;
    l_err_code         NUMBER;
    l_err_message      VARCHAR2(500);
    l_user_id          NUMBER;
    l_resp_id          NUMBER;
    l_resp_appl_id     NUMBER;
    l_organization_id  NUMBER;
    l_is_full_qty      VARCHAR2(1) := 'N';
  
    l_revision             mtl_item_revisions_b.revision%TYPE;
    l_is_serial_controlled VARCHAR2(1) := 'N'; -- Added By Noam Yanai
    l_is_lot_controlled    VARCHAR2(1) := 'N'; -- Added By Noam Yanai
    l_miss_filed_name      VARCHAR2(100);
    --
    l_my_exception EXCEPTION;
    l_sqlerrm                      VARCHAR2(300);
    l_mo_line_status               NUMBER; -- Added By Noam Yanai
    is_job_components_fully_picked VARCHAR2(1);
    l_lot                          VARCHAR2(80); -- added by noam yanai AUG-2014 CHG0032515
    l_serial                       VARCHAR2(30); -- added by noam yanai AUG-2014 CHG0032515
  
  BEGIN
  
    -- get user details
    get_user_details(p_user_name       => p_user_name,
	         p_user_id         => l_user_id,
	         p_resp_id         => l_resp_id,
	         p_resp_appl_id    => l_resp_appl_id,
	         p_organization_id => l_organization_id,
	         p_err_code        => l_err_code,
	         p_err_message     => l_err_message);
  
    IF l_err_code = 1 THEN
      RAISE stop_process;
    END IF;
  
    -- check required fields ---
  
    FOR u IN c_trx
    LOOP
      l_miss_filed_name := NULL;
      CASE
        WHEN u.move_order_line_id IS NULL THEN
          l_miss_filed_name := 'move_order_line_id';
        WHEN u.job_id IS NULL THEN
          l_miss_filed_name := 'job_id';
        WHEN u.component_item_code IS NULL THEN
          l_miss_filed_name := 'item_code';
        WHEN u.component_item_id IS NULL THEN
          l_miss_filed_name := 'component_item_id';
        WHEN u.component_from_subinventory IS NULL THEN
          l_miss_filed_name := 'subinventory';
        WHEN u.component_from_locator_id IS NULL THEN
          l_miss_filed_name := 'locator_id';
        WHEN u.line_id IS NULL THEN
          l_miss_filed_name := 'line_id';
        WHEN u.component_qnty IS NULL THEN
          l_miss_filed_name := 'picked_quantity';
        WHEN u.transaction_temp_id IS NULL THEN
          l_miss_filed_name := 'transaction_temp_id';
        WHEN u.move_order_header_id IS NULL THEN
          l_miss_filed_name := 'move_order_header_id';
        ELSE
          NULL;
      END CASE;
    
      IF l_miss_filed_name IS NOT NULL THEN
        l_err_message := REPLACE('field ~FILED is Required',
		         '~FILED',
		         l_miss_filed_name);
        UPDATE xxinv_trx_wip_in t
        SET    t.err_message      = l_err_message,
	   t.status           = 'E',
	   t.last_update_date = SYSDATE,
	   t.last_updated_by  = l_user_id
        WHERE  t.trx_id = u.trx_id;
        COMMIT;
      
      END IF;
    
      -- check pick from the correct subinventory
    
      IF u.component_from_subinventory != u.out_subinventory OR
         nvl(u.component_from_locator_id, -1) != nvl(u.out_locator_id, -1) THEN
        UPDATE xxinv_trx_wip_in t
        SET    t.err_message      = 'Pick from wrong subinventory/locator , expected subinventory=' ||
			u.out_subinventory || ' locator_id=' ||
			u.out_locator_id,
	   t.status           = 'E',
	   t.last_update_date = SYSDATE,
	   t.last_updated_by  = l_user_id
        WHERE  t.trx_id = u.trx_id;
        COMMIT;
      END IF;
    
      ------------------------------------------------------------------------------------------
      --  Additional validations added by Noam Yanai Mar-2014
    
      SELECT trl.line_status
      INTO   l_mo_line_status
      FROM   mtl_txn_request_lines trl
      WHERE  trl.line_id = u.move_order_line_id;
    
      IF nvl(l_mo_line_status, -1) NOT IN (3, 7) THEN
        -- Approved / Pre-approved
        UPDATE xxinv_trx_wip_in t
        SET    t.err_message      = 'Move Order Line id ' ||
			u.move_order_line_id ||
			' is closed or cancelled.',
	   t.status           = 'E',
	   t.last_update_date = SYSDATE,
	   t.last_updated_by  = l_user_id
        WHERE  t.trx_id = u.trx_id;
        COMMIT;
      END IF;
      ------------------------------------------------------------------------------------------
    
    END LOOP;
  
    ------- initialize ---------
    fnd_global.apps_initialize(l_user_id, l_resp_id, l_resp_appl_id);
  
    message('ORG_ID=' || fnd_global.org_id);
  
    mo_global.set_policy_context('S', fnd_global.org_id);
    inv_globals.set_org_id(fnd_global.org_id);
    mo_global.init('INV');
    -------------------------------
  
    FOR a IN c_trx_pick
    LOOP
    
      l_is_full_qty := is_full_qty_issued(p_move_order_line_id => a.move_order_line_id);
    
      IF l_is_full_qty = 'N' THEN
        -- Not Fully Picked
      
        UPDATE xxinv_trx_wip_in t
        SET    t.err_message      = 'Job: ' || a.job_number || ' item ' ||
			a.item_code ||
			' was not fully picked for MOVE_ORDER_LINE_ID: ' ||
			a.move_order_line_id,
	   t.status           = 'E', --<<< change this !!  leave the status as 'N' >>>
	   t.last_update_date = SYSDATE,
	   t.last_updated_by  = l_user_id
        WHERE  t.move_order_line_id = a.move_order_line_id
        AND    t.status = 'N';
      
        COMMIT;
        message('Job: ' || a.job_number || ' item ' || a.item_code ||
	    ' was not fully picked for MOVE_ORDER_LINE_ID: ' ||
	    a.move_order_line_id);
      
      ELSIF l_is_full_qty = 'X' THEN
        -- Over Picked Added by Noam Yanai Feb-2014
      
        UPDATE xxinv_trx_wip_in t
        SET    t.err_message      = 'Job: ' || a.job_number || ' item ' ||
			a.item_code ||
			' was OVER picked for MOVE_ORDER_LINE_ID: ' ||
			a.move_order_line_id,
	   t.status           = 'E',
	   t.last_update_date = SYSDATE,
	   t.last_updated_by  = l_user_id
        WHERE  t.move_order_line_id = a.move_order_line_id
        AND    t.status = 'N';
      
        COMMIT;
        message('Job: ' || a.job_number || ' item ' || a.item_code ||
	    ' was OVER picked for MOVE_ORDER_LINE_ID: ' ||
	    a.move_order_line_id);
      
      ELSE
      
        UPDATE xxinv_trx_wip_in t
        SET    t.err_message      = NULL,
	   t.last_update_date = SYSDATE,
	   t.last_updated_by  = l_user_id
        WHERE  t.move_order_line_id = a.move_order_line_id
        AND    t.err_message IS NOT NULL
        AND    t.status = 'N';
      
        COMMIT;
      
      END IF;
    
    END LOOP;
  
    /****************************************************
            Update TEMP tables by sended data
    ****************************************************/
    FOR u IN c_trx
    LOOP
      BEGIN
      
        -----
        SELECT decode(nvl(sib.lot_control_code, 1), 2, 'Y', 'N') -- Added By Noam Yanai
	  ,
	   decode(nvl(sib.serial_number_control_code, 1), 1, 'N', 'Y')
        INTO   l_is_lot_controlled,
	   l_is_serial_controlled
        FROM   mtl_system_items_b sib
        WHERE  sib.organization_id = l_organization_id
        AND    sib.inventory_item_id = u.component_item_id;
      
        l_revision := NULL; -- Added By Noam Yanai
      
        -------------------------------------------------------------------------- from here added by noam yanai AUG-2014 CHG0032515
      
        IF u.component_serial_number IS NOT NULL THEN
          IF is_lot_serial_the_same(u.out_serial, u.component_serial_number) = 'Y' THEN
	-- added by noam yanai AUG-2014 CHG0032515
	l_serial := u.out_serial;
          ELSE
	SELECT nvl(MAX(sn.serial_number), u.component_serial_number)
	INTO   l_serial
	FROM   mtl_serial_numbers sn
	WHERE  sn.inventory_item_id = u.component_item_id
	AND    upper(sn.serial_number) =
	       upper(u.component_serial_number);
          END IF;
        END IF;
      
        IF u.component_lot_number IS NOT NULL THEN
          IF is_lot_serial_the_same(u.out_lot, u.component_lot_number) = 'Y' THEN
	-- added by noam yanai AUG-2014 CHG0032515
	l_lot := u.out_lot;
          ELSE
	SELECT nvl(MAX(ln.lot_number), u.component_lot_number)
	INTO   l_lot
	FROM   mtl_lot_numbers ln
	WHERE  ln.organization_id = l_organization_id
	AND    ln.inventory_item_id = u.component_item_id
	AND    upper(ln.lot_number) = upper(u.component_lot_number);
          END IF;
        END IF;
        -------------------------------------------------------------------------- to here added by noam yanai AUG-2014 CHG0032515
      
        IF is_revision_control(p_item_code       => u.component_item_code,
		       p_organization_id => l_organization_id) = 'Y' THEN
        
          -- l_revision :=
          get_revision(p_item_code       => u.component_item_code,
	           p_mode            => 1,
	           p_organization_id => l_organization_id,
	           p_revision        => l_revision,
	           p_err_message     => l_err_message,
	           p_subinv          => u.component_from_subinventory,
	           p_locator_id      => u.component_from_locator_id,
	           p_serial          => l_serial, -- changed by noam yanai AUG-2014 CHG0032515
	           p_lot_number      => l_lot); -- changed by noam yanai AUG-2014 CHG0032515
        
        END IF;
      
        IF l_is_lot_controlled = 'Y' AND l_is_serial_controlled = 'N' THEN
          -- Added By Noam Yanai
        
          BEGIN
          
	-- CHECK LOT EXISTS (u.lot_number  is  null)
	-- Item Lot Control , but lot number is missing
	IF u.component_lot_number IS NULL THEN
	  l_err_message := 'Item is Lot Control , but lot number is missing';
	  RAISE l_my_exception;
	END IF;
          
	/*            SELECT o.component_lot_number, o.component_revision
             INTO l_old_lot, l_old_revision
             FROM xxinv_trx_wip_out o
            WHERE o.line_id = u.line_id
              AND nvl(o.component_lot_number, '-77') != u.component_lot_number;*/
          
	IF u.out_lot != l_lot THEN
	
	  IF nvl(u.out_revision, '-77') = nvl(l_revision, '-77') THEN
	  
	    UPDATE mtl_transaction_lots_temp t
	    SET    t.lot_number       = l_lot,
	           t.origination_type = 3, -- Added By Noam Yanai = Receiving
	           t.last_update_date = SYSDATE,
	           t.last_updated_by  = l_user_id
	    WHERE  t.rowid =
	           (SELECT lt.rowid
		FROM   mtl_material_transactions_temp tt,
		       mtl_transaction_lots_temp      lt
		WHERE  lt.transaction_temp_id =
		       tt.transaction_temp_id
		AND    lt.lot_number = nvl(u.out_lot, '-77')
		AND    lt.transaction_quantity = u.component_qnty
		AND    tt.transaction_temp_id = u.out_temp_id
		AND    nvl(u.out_lot, '-77') != l_lot -- lot change
		AND    rownum < 2);
	    COMMIT;
	  
	    ------------------------------------- update wip_out so system will not send another task
	    UPDATE xxinv_trx_wip_out o
	    SET    o.component_lot_number = l_lot,
	           o.orig_lot_number      = u.out_lot
	    WHERE  o.line_id = u.line_id;
	  
	    COMMIT;
	  
	    UPDATE xxinv_trx_wip_out o
	    SET    o.assembly_lot_number = l_lot
	    WHERE  o.assembly_lot_number = u.out_lot;
	  
	    COMMIT;
	  
	    message('Lot: ' || u.out_lot || ' was replaced to lot: ' ||
		l_lot || ' for item: ' || u.component_item_code || '.');
	  
	    UPDATE xxinv_trx_wip_in t
	    SET    t.err_message      = 'Lot: ' || u.out_lot ||
			        ' was replaced to lot: ' ||
			        l_lot || '.',
	           t.last_update_date = SYSDATE,
	           t.last_updated_by  = l_user_id
	    WHERE  t.trx_id = u.trx_id;
	    COMMIT;
	  
	  ELSE
	  
	    UPDATE xxinv_trx_wip_in t
	    SET    t.err_message      = 'Lot Change Failed ! Revision of new lot (' ||
			        l_lot ||
			        ') is different from revision of lot (' ||
			        u.out_lot || ') in the task.',
	           t.status           = 'E',
	           t.last_update_date = SYSDATE,
	           t.last_updated_by  = l_user_id
	    WHERE  t.move_order_line_id = u.move_order_line_id;
	  
	    COMMIT;
	  
	  END IF;
	END IF; --(u.out_lot = l_lot)
          
          EXCEPTION
	WHEN l_my_exception THEN
	
	  UPDATE xxinv_trx_wip_in t
	  SET    t.err_message      = l_err_message,
	         t.status           = 'E',
	         t.last_update_date = SYSDATE,
	         t.last_updated_by  = l_user_id
	  WHERE  t.trx_id = u.trx_id;
	  COMMIT;
	
	WHEN OTHERS THEN
	  NULL;
          END;
        
        ELSIF l_is_serial_controlled = 'Y' THEN
        
          BEGIN
          
	-- check serial exists
	-- id u.serial_number is null then
	-- Item is serial control , but serial number is missing
          
	IF u.component_serial_number IS NULL THEN
	  l_err_message := 'Item is serial control , but serial number is missing';
	  RAISE l_my_exception;
	END IF;
	/*
            SELECT o.component_serial_number, o.component_revision
              INTO l_old_serial, l_old_revision
              FROM xxinv_trx_wip_out o
             WHERE o.line_id = u.line_id
               AND o.component_serial_number != u.component_serial_number;*/
	IF nvl(u.out_serial, '-77') != nvl(l_serial, '-77') THEN
	  IF nvl(u.out_revision, '-77') = nvl(l_revision, '-77') THEN
	  
	    UPDATE mtl_serial_numbers_temp st
	    SET    st.last_update_date = SYSDATE,
	           st.last_updated_by  = l_user_id,
	           st.fm_serial_number = l_serial,
	           st.to_serial_number = l_serial,
	           st.group_header_id = -- Added By Noam Yanai
	           (SELECT mtt.transaction_header_id
		FROM   mtl_material_transactions_temp mtt
		WHERE  mtt.transaction_temp_id =
		       u.transaction_temp_id)
	    WHERE  st.rowid =
	           (SELECT snt.rowid
		FROM   mtl_serial_numbers_temp snt
		WHERE  snt.transaction_temp_id = u.out_temp_id
		AND    snt.fm_serial_number = u.out_serial);
	  
	    ------------------------------------- update wip_out so system will not send another task
	    COMMIT;
	  
	    UPDATE xxinv_trx_wip_out o
	    SET    o.component_serial_number = l_serial,
	           o.orig_serial_number      = u.out_serial
	    WHERE  o.line_id = u.line_id;
	  
	    UPDATE xxinv_trx_wip_out o
	    SET    o.assembly_serial_number = l_serial
	    WHERE  o.assembly_serial_number = u.out_serial;
	  
	    ------------------------------------- This whole section was Added By Noam Yanai
	    COMMIT;
	  
	    -- update mtl_serial_numbers serial reservation
	    -- new serial ==> reserve
	    UPDATE mtl_serial_numbers msn
	    SET    msn.lot_line_mark_id = u.transaction_temp_id,
	           msn.line_mark_id     = u.transaction_temp_id,
	           msn.group_mark_id    = u.transaction_temp_id,
	           msn.last_update_date = SYSDATE,
	           msn.last_updated_by  = l_user_id
	    WHERE  msn.inventory_item_id = u.component_item_id
	    AND    msn.serial_number = l_serial;
	  
	    COMMIT;
	    -- original serial ==> unreserve
	    UPDATE mtl_serial_numbers msn
	    SET    msn.lot_line_mark_id = NULL,
	           msn.line_mark_id     = NULL,
	           msn.group_mark_id    = NULL,
	           msn.last_update_date = SYSDATE,
	           msn.last_updated_by  = l_user_id
	    WHERE  msn.inventory_item_id = u.component_item_id
	    AND    msn.serial_number = u.out_serial;
	    ------------------------------------------------------  Until here Added By Noam Yanai
	  
	    COMMIT;
	  
	    message('Serial: ' || u.out_serial ||
		' was replaced to serial: ' ||
		u.component_serial_number || ' for item: ' ||
		l_serial || '.');
	    UPDATE xxinv_trx_wip_in t
	    SET    t.err_message = 'Serial: ' || u.out_serial ||
			   ' was replaced to serial: ' ||
			   l_serial || '.'
	    WHERE  t.trx_id = u.trx_id;
	    COMMIT;
	  
	  ELSE
	  
	    UPDATE xxinv_trx_wip_in t
	    SET    t.err_message = 'Serial Change Failed ! Revision of new serial (' ||
			   l_serial ||
			   ') is different from revision of serial (' ||
			   u.out_serial || ') in the task.',
	           t.status      = 'E'
	    WHERE  t.move_order_line_id = u.move_order_line_id;
	  
	    COMMIT;
	  
	  END IF;
	END IF; --u.out_serial != l_serial
          EXCEPTION
	WHEN l_my_exception THEN
	
	  UPDATE xxinv_trx_wip_in t
	  SET    t.err_message = l_err_message,
	         t.status      = 'E'
	  WHERE  t.trx_id = u.trx_id;
	  COMMIT;
	
	WHEN OTHERS THEN
	  NULL;
          END;
        
        END IF;
      
      EXCEPTION
      
        WHEN OTHERS THEN
          l_sqlerrm := substr(SQLERRM, 1, 255);
          UPDATE xxinv_trx_wip_in t
          SET    t.err_message      = l_err_message || ' ' || l_sqlerrm,
	     t.status           = 'E',
	     t.last_update_date = SYSDATE,
	     t.last_updated_by  = l_user_id
          WHERE  t.trx_id = u.trx_id;
        
          COMMIT;
        
      END;
    END LOOP;
  
    FOR i IN c_trx
    LOOP
      BEGIN
      
        FOR j IN c_mo_details(i.move_order_header_id)
        LOOP
          l_mo_details := j;
          message('move_order_type=' || l_mo_details.move_order_type);
        END LOOP;
      
        l_trolin_tbl(1).line_id := i.move_order_line_id;
        message('=======================================================');
        message('Calling INV_Pick_Wave_Pick_Confirm_PUB.Pick_Confirm API');
        message('move_order_line_id=' || i.move_order_line_id);
        --------------  WIP component Issue
        inv_pick_wave_pick_confirm_pub.pick_confirm(p_api_version_number => l_api_version,
				    p_init_msg_list      => fnd_api.g_true,
				    p_commit             => fnd_api.g_false,
				    x_return_status      => x_return_status,
				    x_msg_count          => x_msg_count,
				    x_msg_data           => x_msg_data,
				    p_move_order_type    => l_mo_details.move_order_type, --i.move_order_type, ??????
				    p_transaction_mode   => l_transaction_mode,
				    p_trolin_tbl         => l_trolin_tbl,
				    p_mold_tbl           => l_mold_tbl,
				    x_mmtt_tbl           => x_mmtt_tbl,
				    x_trolin_tbl         => x_trolin_tbl,
				    p_transaction_date   => l_transaction_date);
      
        message('=======================================================');
        message('x_return_status=' || x_return_status);
      
        IF (x_return_status <> fnd_api.g_ret_sts_success) THEN
          ROLLBACK;
        
          UPDATE xxinv_trx_wip_in t
          SET    t.err_message      = x_msg_data,
	     t.status           = 'E',
	     t.last_update_date = SYSDATE,
	     t.last_updated_by  = fnd_global.user_id
          WHERE  t.trx_id = i.trx_id;
        
          COMMIT;
          message(x_msg_data);
        ELSE
          UPDATE xxinv_trx_wip_in t
          SET    t.status           = 'S',
	     t.last_update_date = SYSDATE,
	     t.last_updated_by  = fnd_global.user_id
          WHERE  t.trx_id = i.trx_id;
          COMMIT;
        
        END IF;
      
        --   Check if this pick was the last pick for the job. If it was insert lines to material_in for wip completion transaction
        is_job_components_fully_picked := is_job_components_picked(i.organization_id,
					       i.job_id);
      
        IF is_job_components_fully_picked = 'Y' THEN
        
          update_assembly_serial(i.job_id); -- Need to update wip_in table of assembly serial in case a different component serial was picked
        
          handle_wip_completion_trx(errbuf, retcode, p_user_name, i.job_id);
        
          IF nvl(retcode, 0) < 0 THEN
	UPDATE xxinv_trx_wip_in t
	SET    t.err_message      = 'Pick Succeeded !! Failed to insert WIP completion for job ' ||
			    i.job_number || '. Error message: ' ||
			    errbuf,
	       t.status           = 'E',
	       t.last_update_date = SYSDATE,
	       t.last_updated_by  = l_user_id
	WHERE  t.trx_id = i.trx_id;
          END IF;
        
        END IF;
      
        message('=======================================================');
      
      EXCEPTION
        WHEN OTHERS THEN
          l_sqlerrm := substr(SQLERRM, 1, 255);
          UPDATE xxinv_trx_wip_in t
          SET    t.err_message      = l_err_message || ' ' || l_sqlerrm,
	     t.status           = 'E',
	     t.last_update_date = SYSDATE,
	     t.last_updated_by  = l_user_id
          WHERE  t.trx_id = i.trx_id;
      END;
    
    END LOOP;
  EXCEPTION
  
    WHEN stop_process THEN
      retcode := '2';
      errbuf  := l_err_message;
      message('Error:' || errbuf);
    WHEN OTHERS THEN
      retcode := '2';
      errbuf  := SQLERRM;
      message('Exception Occured :');
      message(SQLCODE || ': ' || SQLERRM);
    
  END handle_wip_issue_trx;

  -----------------------------------------------------------------
  -- handle_wip_completion_trx
  ----------------------------------------------------------------
  -- Purpose: handle wip completion trx
  -----------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------------------
  --     1.0  22.7.14   Noam Yanai      initial build CHG0032515
  --     1.1  9.12.14   Noam Yanai      CHG0033946 - find completion subinventory and locator when it is missing
  --     1.2  29.11.15   yuval tal      CHG0037096 -  and item id to mtl_lot_number table join
  -----------------------------------------------------------------
  PROCEDURE handle_wip_completion_trx(errbuf      OUT VARCHAR2,
			  retcode     OUT VARCHAR2,
			  p_user_name IN VARCHAR2,
			  p_job_id    IN NUMBER) IS
  
    CURSOR c_trx_complete IS
      SELECT xxinv_trx_in_s.nextval trx_id,
	 source_code source_code,
	 'WIP' source_reference_code,
	 1 bpel_id,
	 NULL program_request_id,
	 NULL transaction_interface_id,
	 SYSDATE creation_date,
	 SYSDATE last_update_date,
	 fnd_global.user_id created_by,
	 fnd_global.login_id last_update_login,
	 fnd_global.user_id last_updated_by,
	 'N' status,
	 NULL err_message,
	 wi.assembly_item_id inventory_item_id,
	 wi.assembly_item_code item_code,
	 44 transaction_type_id,
	 wi.job_id transaction_source_id,
	 wi.assembly_revision revision,
	 wi.completion_to_subinventory subinventory_code,
	 wi.completion_to_locator_id locator_id,
	 (-1) * wi.assembly_qnty transaction_quantity,
	 wi.assembly_uom_code transaction_uom,
	 SYSDATE transaction_date,
	 'Job: ' || wi.job_number || ' , Sales Order: ' ||
	 wi.sales_order_number transaction_reference,
	 NULL reason_id,
	 NULL transfer_subinventory,
	 NULL transfer_locator_id,
	 wi.assembly_serial_number from_serial_number,
	 wi.assembly_serial_number to_serial_number,
	 wi.assembly_lot_number lot_number,
	 decode(wi.assembly_lot_number,
	        NULL,
	        NULL,
	        nvl((SELECT MAX(l.expiration_date)
		FROM   mtl_lot_numbers l
		WHERE  l.lot_number = wi.assembly_lot_number
		AND    l.inventory_item_id = wi.assembly_item_id), --CHG0037096),
		SYSDATE + 30)) lot_expiration_date,
	 NULL resolution_remark,
	 NULL closed_by,
	 wi.job_number
      FROM   xxinv_trx_wip_in wi
      WHERE  wi.job_id = p_job_id
      AND    wi.source_code = p_user_name
      AND    rownum < 2;
  
    l_comp_sub VARCHAR2(10); -- added by noam yanai DEC-14 CHG0033946
    l_comp_loc NUMBER; -- added by noam yanai DEC-14 CHG0033946
  
  BEGIN
  
    errbuf  := NULL;
    retcode := 0;
  
    FOR i IN c_trx_complete
    LOOP
      BEGIN
        -- if TPL doesn't send completion sub/locator find and use sub/locator of unified platform
        get_wip_completion_sub_loc(errbuf,
		           retcode,
		           l_comp_sub,
		           l_comp_loc,
		           i.transaction_source_id);
      
        INSERT INTO xxinv_trx_material_in
          (trx_id,
           source_code,
           source_reference_code,
           bpel_id,
           program_request_id,
           transaction_interface_id,
           creation_date,
           last_update_date,
           created_by,
           last_update_login,
           last_updated_by,
           status,
           err_message,
           inventory_item_id,
           item_code,
           transaction_type_id,
           transaction_source_id,
           revision,
           subinventory_code,
           locator_id,
           transaction_quantity,
           transaction_uom,
           transaction_date,
           transaction_reference,
           reason_id,
           transfer_subinventory,
           transfer_locator_id,
           from_serial_number,
           to_serial_number,
           lot_number,
           lot_expiration_date,
           resolution_remark,
           closed_by)
        VALUES
          (i.trx_id,
           i.source_code,
           i.source_reference_code,
           i.bpel_id,
           i.program_request_id,
           NULL,
           i.creation_date,
           i.last_update_date,
           i.created_by,
           i.last_update_login,
           i.last_updated_by,
           'N',
           NULL,
           i.inventory_item_id,
           i.item_code,
           i.transaction_type_id,
           i.transaction_source_id,
           i.revision,
           nvl(i.subinventory_code, l_comp_sub), -- added by noam yanai DEC-14 CHG0033946
           nvl(i.locator_id, l_comp_loc), -- added by noam yanai DEC-14 CHG0033946
           i.transaction_quantity,
           i.transaction_uom,
           i.transaction_date,
           i.transaction_reference,
           i.reason_id,
           i.transfer_subinventory,
           i.transfer_locator_id,
           i.from_serial_number,
           i.to_serial_number,
           i.lot_number,
           i.lot_expiration_date,
           i.resolution_remark,
           i.closed_by);
      
      EXCEPTION
      
        WHEN OTHERS THEN
          errbuf  := errbuf || '-' || SQLERRM;
          retcode := '2';
          ROLLBACK;
          RETURN;
      END;
    
      COMMIT;
    
    END LOOP;
  
  END handle_wip_completion_trx;

  ----------------------------------------------------------------------------------
  --   get_wip_completion_sub_loc
  ----------------------------------------------------------------------------------
  -- Purpose: find subinventory and locator_id in which the wip completion has to be done.
  --          The subinventory and locator are according to the subinventory and locator
  --          From which the machine component was issued (assuming the machine does not move)
  ----------------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  --------------------------------------------
  --     1.0  09.12.14   Noam Yanai      initial build CHG0033946
  ----------------------------------------------------------------------------------
  PROCEDURE get_wip_completion_sub_loc(errbuf     OUT VARCHAR2,
			   retcode    OUT VARCHAR2,
			   p_comp_sub OUT VARCHAR2,
			   p_comp_loc OUT VARCHAR2,
			   p_job_id   IN NUMBER) IS
  BEGIN
  
    SELECT wi.component_from_subinventory,
           wi.component_from_locator_id
    INTO   p_comp_sub,
           p_comp_loc
    FROM   mtl_item_categories_v miv,
           xxinv_trx_wip_in      wi
    WHERE  miv.inventory_item_id = wi.component_item_id
    AND    miv.category_set_name = 'Activity Analysis'
    AND    miv.segment1 = 'General'
    AND    miv.organization_id = 91
    AND    wi.job_id = p_job_id
    AND    rownum = 1;
  
    errbuf  := '';
    retcode := '0';
  
  EXCEPTION
    WHEN OTHERS THEN
      p_comp_sub := NULL;
      p_comp_loc := NULL;
      errbuf     := 'Error - No Component in the job is a machine (Job_id = ' ||
	        p_job_id || ').';
      retcode    := '2';
    
  END get_wip_completion_sub_loc;
  ----------------------------------------------------------------------------------
  --   Move_stock
  ----------------------------------------------------------------------------------
  -- Purpose: move all stock in a given sub/locator to a given sub/locator
  --          used at go live to move all stock of subinventory to the TPL locator
  --          called from program : XX INV Tpl Mass subtrasnsfer/XXINVTPLMASSMOVE
  ----------------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  --------------------------------------------
  --     1.0  15.09.14   Noam Yanai      initial build CHG0032515
  --     1.1  29.11.2015 yuval tal      CHG0037096 add and item id to mtl_lot_number table join
  ----------------------------------------------------------------------------------

  PROCEDURE move_stock(errbuf      OUT VARCHAR2,
	           retcode     OUT VARCHAR2,
	           p_user_name IN VARCHAR2,
	           p_from_sub  IN VARCHAR2,
	           p_from_loc  IN NUMBER,
	           p_to_sub    IN VARCHAR2,
	           p_to_loc    IN NUMBER) IS
  
    CURSOR c_trx_complete(c_organization_id NUMBER) IS
      SELECT xxinv_trx_in_s.nextval trx_id,
	 x.*
      FROM   (SELECT p_user_name source_code,
	         'stock transfer' source_reference_code,
	         1 bpel_id,
	         NULL program_request_id,
	         NULL transaction_interface_id,
	         SYSDATE creation_date,
	         SYSDATE last_update_date,
	         fnd_global.user_id created_by,
	         fnd_global.login_id last_update_login,
	         fnd_global.user_id last_updated_by,
	         'N' status,
	         NULL err_message,
	         q.inventory_item_id inventory_item_id,
	         b.segment1 item_code,
	         2 transaction_type_id,
	         NULL transaction_source_id,
	         q.revision revision,
	         q.subinventory_code subinventory_code,
	         q.locator_id locator_id,
	         q.transaction_quantity transaction_quantity,
	         q.transaction_uom_code transaction_uom,
	         SYSDATE transaction_date,
	         NULL transaction_reference,
	         NULL reason_id,
	         p_to_sub transfer_subinventory,
	         p_to_loc transfer_locator_id,
	         NULL from_serial_number,
	         NULL to_serial_number,
	         q.lot_number lot_number,
	         decode(q.lot_number,
		    NULL,
		    NULL,
		    nvl((SELECT MAX(l.expiration_date)
		        FROM   mtl_lot_numbers l
		        WHERE  l.lot_number = q.lot_number
		        AND    l.inventory_item_id =
			   q.inventory_item_id), --CHG0037096),
		        SYSDATE + 30)) lot_expiration_date,
	         NULL resolution_remark,
	         NULL closed_by
	  FROM   mtl_onhand_quantities_detail q,
	         mtl_system_items_b           b
	  WHERE  q.organization_id = c_organization_id
	  AND    q.subinventory_code = p_from_sub
	  AND    nvl(q.locator_id, 1) =
	         nvl(p_from_loc, nvl(q.locator_id, 1))
	  AND    nvl(q.locator_id, -1) <>
	         nvl(p_to_loc, nvl(q.locator_id, -2))
	  AND    b.organization_id = q.organization_id
	  AND    b.inventory_item_id = q.inventory_item_id
	  AND    b.serial_number_control_code = 1
	  UNION ALL
	  SELECT p_user_name source_code,
	         'stock transfer' source_reference_code,
	         1 bpel_id,
	         NULL program_request_id,
	         NULL transaction_interface_id,
	         SYSDATE creation_date,
	         SYSDATE last_update_date,
	         fnd_global.user_id created_by,
	         fnd_global.login_id last_update_login,
	         fnd_global.user_id last_updated_by,
	         'N' status,
	         NULL err_message,
	         qs.inventory_item_id inventory_item_id,
	         b.segment1 item_code,
	         2 transaction_type_id,
	         NULL transaction_source_id,
	         qs.revision revision,
	         qs.subinventory_code subinventory_code,
	         qs.locator_id locator_id,
	         1 transaction_quantity,
	         'EA' transaction_uom,
	         SYSDATE transaction_date,
	         NULL transaction_reference,
	         NULL reason_id,
	         p_to_sub transfer_subinventory,
	         p_to_loc transfer_locator_id,
	         qs.serial_number from_serial_number,
	         qs.serial_number to_serial_number,
	         qs.lot_number lot_number,
	         decode(qs.lot_number,
		    NULL,
		    NULL,
		    nvl((SELECT MAX(l.expiration_date)
		        FROM   mtl_lot_numbers l
		        WHERE  l.lot_number = qs.lot_number
		        AND    l.inventory_item_id =
			   b.inventory_item_id), --CHG0037096),
		        SYSDATE + 30)) lot_expiration_date,
	         NULL resolution_remark,
	         NULL closed_by
	  FROM   mtl_onhand_serial_v qs,
	         mtl_system_items_b  b
	  WHERE  qs.organization_id = c_organization_id
	  AND    qs.subinventory_code = p_from_sub
	  AND    nvl(qs.locator_id, 1) =
	         nvl(p_from_loc, nvl(qs.locator_id, 1))
	  AND    nvl(qs.locator_id, -1) <>
	         nvl(p_to_loc, nvl(qs.locator_id, -2))
	  AND    b.organization_id = qs.organization_id
	  AND    b.inventory_item_id = qs.inventory_item_id
	  AND    b.serial_number_control_code <> 1
	  AND    EXISTS
	   (SELECT 1
	          FROM   mtl_onhand_quantities_detail qd
	          WHERE  qd.organization_id = qs.organization_id
	          AND    qd.subinventory_code = qs.subinventory_code
	          AND    nvl(qd.locator_id, 1) = nvl(qs.locator_id, 1)
	          AND    qd.inventory_item_id = qs.inventory_item_id)) x;
  
    l_user_id         NUMBER;
    l_organization_id NUMBER;
    l_count           NUMBER := 0;
  BEGIN
  
    BEGIN
      SELECT user_id
      INTO   l_user_id
      FROM   fnd_user
      WHERE  user_name = p_user_name;
    
    EXCEPTION
      WHEN OTHERS THEN
        retcode := '2';
        errbuf  := 'User id not found';
        message(errbuf);
        RETURN;
      
    END;
  
    l_organization_id := fnd_profile.value_specific(NAME    => 'XXINV_TPL_ORGANIZATION_ID',
				    user_id => l_user_id);
  
    IF l_organization_id IS NULL THEN
      retcode := '1';
      errbuf  := 'Organization id is null for profile XXINV_TPL_ORGANIZATION_ID at user level';
      message(errbuf);
      RETURN;
    
    END IF;
  
    errbuf  := NULL;
    retcode := 0;
  
    FOR i IN c_trx_complete(l_organization_id)
    LOOP
      l_count := l_count + 1;
      INSERT INTO xxinv_trx_material_in
        (trx_id,
         source_code,
         source_reference_code,
         bpel_id,
         program_request_id,
         transaction_interface_id,
         creation_date,
         last_update_date,
         created_by,
         last_update_login,
         last_updated_by,
         status,
         err_message,
         inventory_item_id,
         item_code,
         transaction_type_id,
         transaction_source_id,
         revision,
         subinventory_code,
         locator_id,
         transaction_quantity,
         transaction_uom,
         transaction_date,
         transaction_reference,
         reason_id,
         transfer_subinventory,
         transfer_locator_id,
         from_serial_number,
         to_serial_number,
         lot_number,
         lot_expiration_date,
         resolution_remark,
         closed_by)
      VALUES
        (i.trx_id,
         i.source_code,
         i.source_reference_code,
         i.bpel_id,
         i.program_request_id,
         NULL,
         i.creation_date,
         i.last_update_date,
         i.created_by,
         i.last_update_login,
         i.last_updated_by,
         'N',
         NULL,
         i.inventory_item_id,
         i.item_code,
         i.transaction_type_id,
         i.transaction_source_id,
         i.revision,
         i.subinventory_code,
         i.locator_id,
         i.transaction_quantity,
         i.transaction_uom,
         i.transaction_date,
         i.transaction_reference,
         i.reason_id,
         i.transfer_subinventory,
         i.transfer_locator_id,
         i.from_serial_number,
         i.to_serial_number,
         i.lot_number,
         i.lot_expiration_date,
         i.resolution_remark,
         i.closed_by);
    
    END LOOP;
    COMMIT;
  
    message('Number of records inserted to xxinv_trx_material_in ' ||
	l_count);
  EXCEPTION
  
    WHEN OTHERS THEN
      errbuf  := SQLERRM;
      retcode := 2;
      ROLLBACK;
    
      message('process failed ');
      message(substr(SQLERRM, 1, 250));
  END move_stock;
  ----------------------------------------------------------------------------------------------------------------------------
  ----------------------------------------------------------------------------------------------------------------------------
  ----------------------------------------------------------------------------------------------------------------------------

  -------------------------------------------------------------------------------------
  -- Ver When        Who        Description
  -- --- ----------  ---------  -------------------------------------------------------
  -- 3.5 11-06-2018  Roman W.   CHG0043197 : TPL Interface ship confirm -  eliminate ship confirm errors
  --                                             1) check status of delivery before reissign.
  -------------------------------------------------------------------------------------
  FUNCTION is_valid_delivery(p_delivery_id NUMBER) RETURN VARCHAR2 IS
    ------------------------------
    --     Local Definition
    ------------------------------
    l_ret_value VARCHAR2(300);
    ------------------------------
    --     Code Section
    ------------------------------
  BEGIN
  
    SELECT decode(COUNT(*), 0, 'N', 'Y')
    INTO   l_ret_value
    FROM   wsh_delivery_details_oe_v wddov
    WHERE  wddov.delivery_id = p_delivery_id
    AND    wddov.released_status = 'Y';
  
    RETURN l_ret_value;
  
  END is_valid_delivery;
  -------------------------------------------------------------------------------------
  -- Ver When        Who        Description
  -- --- ----------  ---------  -------------------------------------------------------
  -- 2.7 01-02-2018  R.W.       INC0123315
  -------------------------------------------------------------------------------------
  PROCEDURE assign_delivery_detail_list(p_source_delivery_id     IN NUMBER,
			    p_source_organization_id IN NUMBER,
			    p_destinate_delivery_id  IN NUMBER,
			    p_commit                 IN VARCHAR2 DEFAULT fnd_api.g_true,
			    p_error_code             OUT NUMBER,
			    p_error_desc             OUT VARCHAR2) IS
  
    ------------------------------------
    --     Cursor Definition
    ------------------------------------
    CURSOR delivery_detail_cur(c_delivery_id     NUMBER,
		       c_organization_id NUMBER) IS
      SELECT wddov.delivery_name,
	 wddov.delivery_detail_id
      FROM   wsh_delivery_details_oe_v wddov
      WHERE  wddov.delivery_id = c_delivery_id
      AND    wddov.source_code = c_source_code_oe
      AND    wddov.organization_id = c_organization_id;
  
    ------------------------------------
    --      Local Definitions
    ------------------------------------
    l_msg_count                    NUMBER;
    l_msg_data                     VARCHAR2(2000);
    l_count                        NUMBER;
    l_api_version                  NUMBER;
    l_init_msg_list                VARCHAR2(200);
    l_validation_level             NUMBER;
    l_return_status                VARCHAR2(200);
    l_tabofdeldets                 apps.wsh_delivery_details_pub.id_tab_type;
    l_destinate_delivery_name      VARCHAR2(200);
    l_source_delivery_name         VARCHAR2(200);
    l_index                        NUMBER := 1;
    l_xxinv_trx_delivery_audit_tbl xxinv_trx_delivery_audit_tbl%ROWTYPE;
    ------------------------------------
    --       Code Section
    ------------------------------------
  BEGIN
    p_error_code := 0;
    p_error_desc := NULL;
  
    -- Calculate Delivery Name --
  
    l_api_version      := 1.0;
    l_init_msg_list    := fnd_api.g_true;
    l_validation_level := fnd_api.g_valid_level_full;
  
    /*
    --- Calculate destinate_name --
    select sub.delivery_name
      into l_destinate_delivery_name
      from (select wddov.delivery_name
    
              from wsh_delivery_details_oe_v wddov
             where wddov.delivery_id = p_destinate_delivery_id
               and wddov.source_code = C_SOURCE_CODE_OE
             group by wddov.delivery_name) sub
     where ROWNUM = 1;
    
    select sub2.delivery_name
      into l_source_delivery_name
      from (select wddov.delivery_name
              from wsh_delivery_details_oe_v wddov
             where wddov.delivery_id = p_source_delivery_id
               and wddov.source_code = C_SOURCE_CODE_OE
             group by wddov.delivery_name) sub2
     where ROWNUM = 1;
     */
    -- added by Roman W. INC0123315 --
    --- Calculate destinate_name --
    SELECT wndv.name
    INTO   l_destinate_delivery_name
    FROM   wsh_new_deliveries_v wndv
    WHERE  wndv.delivery_id = p_destinate_delivery_id;
  
    --- Calculation source name ---
    SELECT wndv.name
    INTO   l_source_delivery_name
    FROM   wsh_new_deliveries_v wndv
    WHERE  wndv.delivery_id = p_source_delivery_id;
  
    FOR delivery_detail_ind IN delivery_detail_cur(p_source_delivery_id,
				   p_source_organization_id)
    LOOP
      l_tabofdeldets(l_index) := delivery_detail_ind.delivery_detail_id;
      l_index := l_index + 1;
    
      SELECT wdv.delivery_id,
	 (SELECT wddov.delivery_name
	  FROM   wsh_delivery_details_oe_v wddov
	  WHERE  wddov.delivery_id = wdv.delivery_id
	  GROUP  BY wddov.delivery_name) from_delivery_name,
	 wdv.ship_set_id,
	 p_destinate_delivery_id,
	 (SELECT wddov.delivery_name
	  FROM   wsh_delivery_details_oe_v wddov
	  WHERE  wddov.delivery_id = p_destinate_delivery_id
	  GROUP  BY wddov.delivery_name) to_delivery_name,
	 wdv.ship_set_id,
	 wdv.source_header_id,
	 wdv.source_line_id,
	 wdv.org_id,
	 wdv.inventory_item_id,
	 'NEW'
      INTO   l_xxinv_trx_delivery_audit_tbl.from_delivery_id,
	 l_xxinv_trx_delivery_audit_tbl.from_delivery_name,
	 l_xxinv_trx_delivery_audit_tbl.from_ship_set_id,
	 l_xxinv_trx_delivery_audit_tbl.to_delivery_id,
	 l_xxinv_trx_delivery_audit_tbl.to_delivery_name,
	 l_xxinv_trx_delivery_audit_tbl.to_ship_set_id,
	 l_xxinv_trx_delivery_audit_tbl.header_id,
	 l_xxinv_trx_delivery_audit_tbl.line_id,
	 l_xxinv_trx_delivery_audit_tbl.org_id,
	 l_xxinv_trx_delivery_audit_tbl.item_id,
	 l_xxinv_trx_delivery_audit_tbl.status
      FROM   wsh_deliverables_v wdv
      WHERE  wdv.delivery_detail_id =
	 delivery_detail_ind.delivery_detail_id;
    
      insert_to_log(p_log_dta    => l_xxinv_trx_delivery_audit_tbl,
	        p_error_code => p_error_code,
	        p_error_desc => p_error_desc);
    
    END LOOP;
    --======================================================================================================
    --                                         UNASSIGN                                                   --
    --======================================================================================================
    wsh_delivery_details_pub.detail_to_delivery(p_api_version      => l_api_version,
				p_init_msg_list    => l_init_msg_list,
				p_commit           => p_commit,
				p_validation_level => l_validation_level,
				x_return_status    => l_return_status,
				x_msg_count        => l_msg_count,
				x_msg_data         => l_msg_data,
				p_tabofdeldets     => l_tabofdeldets,
				p_action           => 'UNASSIGN',
				p_delivery_id      => p_source_delivery_id,
				p_delivery_name    => l_source_delivery_name);
  
    IF l_return_status = 'S' THEN
      dbms_output.put_line('Assigned Sucessfully ');
    
    ELSE
      dbms_output.put_line('Message count ' || l_msg_count);
      IF l_msg_count = 1 THEN
        dbms_output.put_line('l_msg_data ' || l_msg_data);
      ELSIF l_msg_count > 1 THEN
        LOOP
          l_count    := l_count + 1;
          l_msg_data := fnd_msg_pub.get(fnd_msg_pub.g_next, fnd_api.g_false);
          IF l_msg_data IS NULL THEN
	EXIT;
          END IF;
          dbms_output.put_line('Message' || l_count || '---' || l_msg_data);
        END LOOP;
      END IF;
    
      p_error_code := -1;
      p_error_desc := 'WORNING : xxinv_trx_in_pkg.assign_delivery_detail_list(' ||
	          p_source_delivery_id || ' , ' ||
	          p_source_organization_id || ' , ' ||
	          p_destinate_delivery_id ||
	          ' ) - please check log file!!!';
    END IF;
    --======================================================================================================
    --                                           ASSIGN                                                   --
    --======================================================================================================
    wsh_delivery_details_pub.detail_to_delivery(p_api_version      => l_api_version,
				p_init_msg_list    => l_init_msg_list,
				p_commit           => p_commit,
				p_validation_level => l_validation_level,
				x_return_status    => l_return_status,
				x_msg_count        => l_msg_count,
				x_msg_data         => l_msg_data,
				p_tabofdeldets     => l_tabofdeldets,
				p_action           => 'ASSIGN',
				p_delivery_id      => p_destinate_delivery_id,
				p_delivery_name    => l_destinate_delivery_name);
  
    IF l_return_status = 'S' THEN
    
      dbms_output.put_line('Assigned Sucessfully ');
    
      update_log_status(p_status     => c_success,
		p_error_code => p_error_code,
		p_error_desc => p_error_desc);
    ELSE
    
      update_log_status(p_status     => c_error,
		p_error_code => p_error_code,
		p_error_desc => p_error_desc);
    
      dbms_output.put_line('Message count ' || l_msg_count);
      IF l_msg_count = 1 THEN
        dbms_output.put_line('l_msg_data ' || l_msg_data);
      ELSIF l_msg_count > 1 THEN
        LOOP
          l_count    := l_count + 1;
          l_msg_data := fnd_msg_pub.get(fnd_msg_pub.g_next, fnd_api.g_false);
          IF l_msg_data IS NULL THEN
	EXIT;
          END IF;
          dbms_output.put_line('Message' || l_count || '---' || l_msg_data);
        END LOOP;
      END IF;
      p_error_code := -1;
      p_error_desc := 'WORNING : xxinv_trx_in_pkg.assign_delivery_detail_list(' ||
	          p_source_delivery_id || ' , ' ||
	          p_source_organization_id || ' , ' ||
	          p_destinate_delivery_id ||
	          ' ) - please check log file!!!';
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      p_error_code := -1;
      p_error_desc := 'WORNING : xxinv_trx_in_pkg.assign_delivery_detail_list(' ||
	          p_source_delivery_id || ',' ||
	          p_source_organization_id || ',' ||
	          p_destinate_delivery_id || ') - ' || SQLERRM;
    
  END assign_delivery_detail_list;
  ----------------------------------------- 1 ----------------------------------------------------------------------
  -- Ver    When        Who      Description
  -- -----  ----------  -------  -----------------------------------------------------------------------------------
  -- 1.0    18-03-2018  Roman.W
  -- 1.1    27-05-2018  Roman W. CHG0042242 (CTASK0036696) - Eliminate Ship Confirm errors due to Intangible Items
  -- 3.5    13-06-2018  Roman W  CHG0043197
  ------------------------------------------------------------------------------------------------------------------
  PROCEDURE set_item_ship_set_to_null(p_ship_set_id IN NUMBER,
			  p_error_code  OUT NUMBER,
			  p_error_desc  OUT VARCHAR2) IS
  
    ----------------------------------
    --     Cursor Definition
    ----------------------------------
    CURSOR item_cur(c_ship_set_id NUMBER) IS
    -- Hazard-restricted items list related to Ship Set --
      SELECT wdv.inventory_item_id item_id,
	 wdv.source_header_id  header_id,
	 wdv.source_line_id    line_id,
	 oola.org_id           org_id
      FROM   wsh_deliverables_v wdv,
	 oe_order_lines_all oola
      WHERE  wdv.ship_set_id = c_ship_set_id
      AND    oola.line_id = wdv.source_line_id
      AND    oola.header_id = wdv.source_header_id
      AND    wdv.source_code = c_source_code_oe
      AND    'Y' =
	 xxinv_utils_pkg.is_item_hazard_restricted(p_inventory_item_id => wdv.inventory_item_id)
      AND    'Y' = is_valid_delivery(wdv.delivery_id)
      UNION ALL
      SELECT wdv.inventory_item_id item_id,
	 wdv.source_header_id  header_id,
	 wdv.source_line_id    line_id,
	 oola.org_id           org_id
      FROM   wsh_deliverables_v wdv,
	 oe_order_lines_all oola
      WHERE  wdv.ship_set_id = c_ship_set_id
      AND    oola.line_id = wdv.source_line_id
      AND    oola.header_id = wdv.source_header_id
      AND    wdv.source_code = c_source_code_oe
      AND    'Y' = is_valid_delivery(wdv.delivery_id)
      AND    'Y' =
	 xxinv_utils_pkg.is_intangible_items(p_inventory_item_id => wdv.inventory_item_id)
	-- to delivery related only intangible item --
      AND    0 =
	 (SELECT COUNT(*)
	   FROM   wsh_deliverables_v wdv_sub
	   WHERE  wdv_sub.ship_set_id = wdv.ship_set_id
	   AND    wdv_sub.delivery_id = wdv.delivery_id
	   AND    wdv_sub.inventory_item_id != wdv.inventory_item_id
	   AND    wdv_sub.source_code = c_source_code_oe
	   AND    'Y' = is_valid_delivery(wdv_sub.delivery_id)
	   AND    'N' =
	          xxinv_utils_pkg.is_intangible_items(p_inventory_item_id => wdv_sub.inventory_item_id))
	-- no multiply delivery related to ship set --
      AND    0 =
	 (SELECT COUNT(*)
	   FROM   wsh_deliverables_v wdv_sub
	   WHERE  wdv_sub.ship_set_id = wdv.ship_set_id
	   AND    wdv_sub.source_code = c_source_code_oe
	   AND    wdv_sub.delivery_id != wdv.delivery_id
	   AND    'Y' = is_valid_delivery(wdv_sub.delivery_id)
	   AND    'N' =
	          xxinv_utils_pkg.is_intangible_items(p_inventory_item_id => wdv_sub.inventory_item_id));
  
    ----------------------------------
    --     Local Definition
    ----------------------------------
    l_return_status VARCHAR2(2000);
    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(2000);
    -- in variables --
  
    l_line_tbl           oe_order_pub.line_tbl_type;
    l_action_request_tbl oe_order_pub.request_tbl_type;
    --  out variables --
  
    l_header_rec_out             oe_order_pub.header_rec_type;
    l_header_val_rec_out         oe_order_pub.header_val_rec_type;
    l_header_adj_tbl_out         oe_order_pub.header_adj_tbl_type;
    l_header_adj_val_tbl_out     oe_order_pub.header_adj_val_tbl_type;
    l_header_price_att_tbl_out   oe_order_pub.header_price_att_tbl_type;
    l_header_adj_att_tbl_out     oe_order_pub.header_adj_att_tbl_type;
    l_header_adj_assoc_tbl_out   oe_order_pub.header_adj_assoc_tbl_type;
    l_header_scredit_tbl_out     oe_order_pub.header_scredit_tbl_type;
    l_header_scredit_val_tbl_out oe_order_pub.header_scredit_val_tbl_type;
    l_line_tbl_out               oe_order_pub.line_tbl_type;
    l_line_val_tbl_out           oe_order_pub.line_val_tbl_type;
    l_line_adj_tbl_out           oe_order_pub.line_adj_tbl_type;
    l_line_adj_val_tbl_out       oe_order_pub.line_adj_val_tbl_type;
    l_line_price_att_tbl_out     oe_order_pub.line_price_att_tbl_type;
    l_line_adj_att_tbl_out       oe_order_pub.line_adj_att_tbl_type;
    l_line_adj_assoc_tbl_out     oe_order_pub.line_adj_assoc_tbl_type;
    l_line_scredit_tbl_out       oe_order_pub.line_scredit_tbl_type;
    l_line_scredit_val_tbl_out   oe_order_pub.line_scredit_val_tbl_type;
    l_lot_serial_tbl_out         oe_order_pub.lot_serial_tbl_type;
    l_lot_serial_val_tbl_out     oe_order_pub.lot_serial_val_tbl_type;
    l_action_request_tbl_out     oe_order_pub.request_tbl_type;
  
    l_ship_set_id               NUMBER;
    l_is_item_hazard_restricted VARCHAR2(10);
  
    l_xxinv_trx_delivery_audit_tbl xxinv_trx_delivery_audit_tbl%ROWTYPE; -- CHG0042242(v1.1)
    ----------------------------------
    --      Code definition
    ----------------------------------
  BEGIN
    p_error_code := 0;
    p_error_desc := NULL;
  
    FOR item_ind IN item_cur(p_ship_set_id)
    LOOP
    
      -- Line --
      l_line_tbl(1) := oe_order_pub.g_miss_line_rec;
      l_line_tbl_out(1) := oe_order_pub.g_miss_line_rec;
      l_line_tbl(1).header_id := item_ind.header_id;
      l_line_tbl(1).line_id := item_ind.line_id;
      l_line_tbl(1).org_id := item_ind.org_id;
      l_line_tbl(1).ship_set_id := NULL;
      l_line_tbl(1).operation := oe_globals.g_opr_update;
      l_line_tbl(1).change_reason := 'Not provided';
    
      oe_msg_pub.delete_msg;
    
      --   v_action_request_tbl (1) := oe_order_pub.g_miss_request_rec;
    
      oe_order_pub.process_order( -- in variables
		         p_api_version_number => 1.0,
		         p_line_tbl           => l_line_tbl,
		         p_action_request_tbl => l_action_request_tbl,
		         p_org_id             => item_ind.org_id,
		         -- out variables
		         x_header_rec             => l_header_rec_out,
		         x_header_val_rec         => l_header_val_rec_out,
		         x_header_adj_tbl         => l_header_adj_tbl_out,
		         x_header_adj_val_tbl     => l_header_adj_val_tbl_out,
		         x_header_price_att_tbl   => l_header_price_att_tbl_out,
		         x_header_adj_att_tbl     => l_header_adj_att_tbl_out,
		         x_header_adj_assoc_tbl   => l_header_adj_assoc_tbl_out,
		         x_header_scredit_tbl     => l_header_scredit_tbl_out,
		         x_header_scredit_val_tbl => l_header_scredit_val_tbl_out,
		         x_line_tbl               => l_line_tbl_out,
		         x_line_val_tbl           => l_line_val_tbl_out,
		         x_line_adj_tbl           => l_line_adj_tbl_out,
		         x_line_adj_val_tbl       => l_line_adj_val_tbl_out,
		         x_line_price_att_tbl     => l_line_price_att_tbl_out,
		         x_line_adj_att_tbl       => l_line_adj_att_tbl_out,
		         x_line_adj_assoc_tbl     => l_line_adj_assoc_tbl_out,
		         x_line_scredit_tbl       => l_line_scredit_tbl_out,
		         x_line_scredit_val_tbl   => l_line_scredit_val_tbl_out,
		         x_lot_serial_tbl         => l_lot_serial_tbl_out,
		         x_lot_serial_val_tbl     => l_lot_serial_val_tbl_out,
		         x_action_request_tbl     => l_action_request_tbl_out,
		         x_return_status          => l_return_status,
		         x_msg_count              => l_msg_count,
		         x_msg_data               => l_msg_data);
    
      IF l_return_status = fnd_api.g_ret_sts_success THEN
      
        -- CTASK0036696(v1.1)
        l_xxinv_trx_delivery_audit_tbl.tpl_user         := fnd_global.user_name;
        l_xxinv_trx_delivery_audit_tbl.header_id        := item_ind.header_id;
        l_xxinv_trx_delivery_audit_tbl.line_id          := item_ind.line_id;
        l_xxinv_trx_delivery_audit_tbl.org_id           := item_ind.org_id;
        l_xxinv_trx_delivery_audit_tbl.item_id          := item_ind.item_id;
        l_xxinv_trx_delivery_audit_tbl.from_ship_set_id := p_ship_set_id;
        l_xxinv_trx_delivery_audit_tbl.to_ship_set_id   := NULL;
        l_xxinv_trx_delivery_audit_tbl.comments         := 'Ship Set to NULL for HAZARD Item (xxinv_trx_in_pkg.set_item_ship_set_to_null)';
        l_xxinv_trx_delivery_audit_tbl.status           := c_success;
      
        insert_to_log(p_log_dta    => l_xxinv_trx_delivery_audit_tbl,
	          p_error_code => p_error_code,
	          p_error_desc => p_error_desc);
      
        COMMIT;
      
        dbms_output.put_line('Order Header Updation Success : ' ||
		     l_header_rec_out.header_id);
        fnd_file.put_line(fnd_file.log,
		  'Order Header Updation Success : ' ||
		  l_header_rec_out.header_id);
      
        IF 0 != p_error_code THEN
          RETURN;
        END IF;
      ELSE
      
        dbms_output.put_line('Order Header Updation failed:' || l_msg_data);
        ROLLBACK;
      
        FOR i IN 1 .. l_msg_count
        LOOP
        
          l_msg_data := oe_msg_pub.get(p_msg_index => i, p_encoded => 'F');
          dbms_output.put_line(i || ') ' || l_msg_data);
          fnd_file.put_line(fnd_file.log, i || ') ' || l_msg_data);
        
        END LOOP;
      END IF;
    END LOOP;
  
  EXCEPTION
    WHEN OTHERS THEN
      p_error_code := -1;
      p_error_desc := 'EXCEPTION_OTHERS : xxinv_trx_in_pkg.set_item_ship_set_null()' ||
	          SQLERRM;
  END set_item_ship_set_to_null;
  ---------------------------------------------------------------------------------------------------
  -- Ver   When        Who       Description
  -- ----  ----------  --------  --------------------------------------------------------------------
  -- 1.0   20-03-2018  Roman.W   CHG0042242 - Eliminate Ship Confirm errors due to Intangible Items
  -- 1.1   27-05-2018  Roman W   CHG0042242 - Added calling to log writing
  -- 3.5   13-06-2018  Roman W   CHG0043197
  ---------------------------------------------------------------------------------------------------
  PROCEDURE combine_delivery_by_ship_set(p_delivery_id IN NUMBER,
			     p_ship_set_id IN NUMBER,
			     p_error_code  OUT NUMBER,
			     p_error_desc  OUT VARCHAR2) IS
    ------------------------------------
    --    Cursor Definition
    ------------------------------------
    CURSOR intangible_items_cur(c_ship_set_id NUMBER,
		        c_delivery_id NUMBER) IS
      SELECT wdv.delivery_id,
	 wdv.organization_id
      FROM   wsh_deliverables_v wdv
      WHERE  wdv.ship_set_id = c_ship_set_id
      AND    wdv.delivery_id != c_delivery_id
      AND    wdv.source_code = c_source_code_oe
      AND    'Y' = is_valid_delivery(wdv.delivery_id)
      AND    'Y' =
	 xxinv_utils_pkg.is_intangible_items(p_inventory_item_id => wdv.inventory_item_id)
      AND    0 =
	 (SELECT COUNT(*)
	   FROM   wsh_deliverables_v wdv_sub
	   WHERE  wdv_sub.ship_set_id = c_ship_set_id
	   AND    wdv_sub.delivery_id = wdv.delivery_id
	   AND    wdv_sub.source_code = c_source_code_oe
	   AND    'N' =
	          xxinv_utils_pkg.is_intangible_items(p_inventory_item_id => wdv.inventory_item_id))
      GROUP  BY wdv.delivery_id,
	    wdv.organization_id;
  
    ------------------------------------
    --     Local Definitions
    ------------------------------------
    l_inventory_item_flag   VARCHAR2(300);
    l_source_delivery_id    NUMBER;
    l_destinate_delivery_id NUMBER;
    no_delivery_combine_to EXCEPTION;
  
    l_xxinv_trx_delivery_audit_tbl xxinv_trx_delivery_audit_tbl%ROWTYPE; -- CHG0042242(v1.1)
    ------------------------------------
    --       Code Section
    ------------------------------------
  BEGIN
    p_error_code := 0;
    p_error_desc := NULL;
  
    -- is to source delivery related inventory ,no hazard and no restricted item --
    SELECT decode(COUNT(*), 0, 'N', 'Y')
    INTO   l_inventory_item_flag
    FROM   wsh_deliverables_v wdv
    WHERE  wdv.delivery_id = p_delivery_id
    AND    wdv.ship_set_id = p_ship_set_id
    AND    wdv.source_code = c_source_code_oe
    AND    'Y' = is_valid_delivery(wdv.delivery_id)
    AND    'N' =
           xxinv_utils_pkg.is_item_hazard_restricted(p_inventory_item_id => wdv.inventory_item_id)
    AND    'N' =
           xxinv_utils_pkg.is_intangible_items(p_inventory_item_id => wdv.inventory_item_id);
  
    IF 'N' = l_inventory_item_flag THEN
    
      SELECT decode(COUNT(*), 0, 'N', 'Y')
      INTO   l_inventory_item_flag
      FROM   wsh_deliverables_v wdv
      WHERE  wdv.ship_set_id = p_ship_set_id
      AND    wdv.source_code = c_source_code_oe
      AND    'Y' = is_valid_delivery(wdv.delivery_id)
      AND    'N' =
	 xxinv_utils_pkg.is_item_hazard_restricted(p_inventory_item_id => wdv.inventory_item_id)
      AND    'N' =
	 xxinv_utils_pkg.is_intangible_items(p_inventory_item_id => wdv.inventory_item_id)
      AND    wdv.delivery_id != p_delivery_id;
    
      IF 'Y' = l_inventory_item_flag THEN
        SELECT wdv.delivery_id
        INTO   l_destinate_delivery_id
        FROM   wsh_deliverables_v wdv
        WHERE  wdv.ship_set_id = p_ship_set_id
        AND    wdv.source_code = c_source_code_oe
        AND    'Y' = is_valid_delivery(p_delivery_id => wdv.delivery_id)
        AND    'N' =
	   xxinv_utils_pkg.is_item_hazard_restricted(p_inventory_item_id => wdv.inventory_item_id)
        AND    'N' =
	   xxinv_utils_pkg.is_intangible_items(p_inventory_item_id => wdv.inventory_item_id)
        AND    wdv.delivery_id != p_delivery_id
        AND    rownum = 1;
      ELSE
        RAISE no_delivery_combine_to;
      END IF;
    
    ELSE
      l_destinate_delivery_id := p_delivery_id;
    END IF;
  
    FOR intangible_items_ind IN intangible_items_cur(p_ship_set_id,
				     l_destinate_delivery_id)
    LOOP
    
      assign_delivery_detail_list(p_source_delivery_id     => intangible_items_ind.delivery_id,
		          p_source_organization_id => intangible_items_ind.organization_id,
		          p_destinate_delivery_id  => l_destinate_delivery_id,
		          p_commit                 => fnd_api.g_true,
		          p_error_code             => p_error_code,
		          p_error_desc             => p_error_desc);
    
      IF 0 != p_error_code THEN
        RETURN;
      END IF;
    
    END LOOP;
  
  EXCEPTION
    WHEN no_delivery_combine_to THEN
      p_error_code := -1;
      p_error_desc := 'WORNING_NO_DELIVERY_COMBINE_TO : xxinv_trx_in_pkg.combine_delivery_by_ship_set(' ||
	          p_delivery_id || ',' || p_ship_set_id || ',' ||
	          ') - no delivery to combine to';
    WHEN OTHERS THEN
      p_error_code := -1;
      p_error_desc := 'EXCEPTION_OTHERS xxinv_trx_in_pkg.combine_delivery_by_ship_set(' ||
	          p_delivery_id || ',' || p_ship_set_id || ') - ' ||
	          SQLERRM;
    
  END combine_delivery_by_ship_set;
  ---------------------------------------------------------------------------------------------------
  -- Ver      When        Who         Description
  -- -------  ----------  ----------  -----------------------------------------------------------------
  -- 1.0      06-06-2018  Roman W     CHG0042242 - Eliminate Ship Confirm errors due to Intangible Items
  --                                      procedure calculate distination delivery_id
  -- 3.5      13-06-2018  Roman W     CHG0043197
  ---------------------------------------------------------------------------------------------------
  PROCEDURE get_destination_delivery_id(p_header_id               IN NUMBER,
			    p_source_delivery_id      IN NUMBER,
			    p_source_organization_id  IN NUMBER,
			    p_destination_delivery_id OUT NUMBER,
			    p_error_code              OUT NUMBER,
			    p_error_desc              OUT VARCHAR2) IS
  
    ----------------------------------
    --      Local Definition
    ----------------------------------
    no_delivery_combine_to EXCEPTION;
    ----------------------------------
    --       Code Section
    ----------------------------------
  BEGIN
    p_error_code := 0;
    p_error_desc := NULL;
  
    SELECT wdv_temp.delivery_id
    INTO   p_destination_delivery_id
    FROM   (SELECT wdv.delivery_id
	FROM   wsh_deliverables_v wdv
	WHERE  wdv.source_header_id = p_header_id
	AND    wdv.delivery_id != p_source_delivery_id
	AND    wdv.organization_id = p_source_organization_id
	AND    wdv.source_code = c_source_code_oe
	AND    'Y' = is_valid_delivery(p_delivery_id => wdv.delivery_id)
	AND    'N' =
	       xxinv_utils_pkg.is_intangible_items(p_inventory_item_id => wdv.inventory_item_id)
	GROUP  BY wdv.delivery_id) wdv_temp
    WHERE  rownum = 1;
  
  EXCEPTION
    WHEN no_data_found THEN
      p_destination_delivery_id := NULL;
      p_error_code              := -1;
      p_error_desc              := 'EXCEPTION_NO_DELIVERY_COMBINE_TO xxinv_trx_in_pkg.get_destination_delivery_id(' ||
		           p_source_delivery_id || ',' ||
		           p_source_organization_id || ')';
    
    WHEN OTHERS THEN
      p_destination_delivery_id := NULL;
      p_error_code              := -1;
      p_error_desc              := 'EXCEPTION_OTHERS xxinv_trx_in_pkg.get_destination_delivery_id(' ||
		           p_source_delivery_id || ',' ||
		           p_source_organization_id || ') - ' ||
		           SQLERRM;
    
  END get_destination_delivery_id;

  ---------------------------------------------------------------------------------------------------
  -- Ver   When        Who       Description
  -- ----  ----------  --------  --------------------------------------------------------------------
  -- 1.0   20-03-2018  Roman W.  CHG0042242 - Eliminate Ship Confirm errors due to Intangible Items
  -- 3.5   13-06-2018  Roman W.  CHG0043197
  ---------------------------------------------------------------------------------------------------
  PROCEDURE combine_delivery_by_order(p_delivery_id IN NUMBER,
			  p_header_id   IN NUMBER,
			  p_error_code  OUT NUMBER,
			  p_error_desc  OUT VARCHAR2) IS
    ------------------------------------
    --    Cursor Definition
    ------------------------------------
    CURSOR intangible_items_cur(c_header_id   NUMBER,
		        c_delivery_id NUMBER) IS
      SELECT wdv.delivery_id,
	 wdv.organization_id
      FROM   wsh_deliverables_v wdv
      WHERE  wdv.source_header_id = c_header_id
	--         and wdv.delivery_id != c_delivery_id
      AND    wdv.source_code = c_source_code_oe
      AND    'Y' = is_valid_delivery(wdv.delivery_id)
	-- delivery with intangble item only --
      AND    'Y' =
	 xxinv_utils_pkg.is_intangible_items(p_inventory_item_id => wdv.inventory_item_id)
	-- delivery without inventory items --
      AND    0 =
	 (SELECT COUNT(*)
	   FROM   wsh_deliverables_v wdv_sub
	   WHERE  wdv_sub.ship_set_id = c_header_id
	   AND    wdv_sub.organization_id = wdv.organization_id
	   AND    wdv_sub.source_code = c_source_code_oe
	   AND    wdv_sub.delivery_id = wdv.delivery_id
	   AND    'Y' = is_valid_delivery(wdv_sub.delivery_id)
	   AND    'N' =
	          xxinv_utils_pkg.is_intangible_items(p_inventory_item_id => wdv.inventory_item_id))
      GROUP  BY wdv.delivery_id,
	    wdv.organization_id;
  
    ------------------------------------
    --     Local Definitions
    ------------------------------------
    l_inventory_item_flag   VARCHAR2(300);
    l_source_delivery_id    NUMBER;
    l_destinate_delivery_id NUMBER;
    no_delivery_combine_to EXCEPTION;
    ------------------------------------
    --       Code Section
    ------------------------------------
  BEGIN
    p_error_code := 0;
    p_error_desc := NULL;
  
    FOR intangible_items_ind IN intangible_items_cur(p_header_id,
				     l_destinate_delivery_id)
    LOOP
    
      get_destination_delivery_id(p_header_id,
		          intangible_items_ind.delivery_id,
		          intangible_items_ind.organization_id,
		          l_destinate_delivery_id,
		          p_error_code,
		          p_error_desc);
      IF 0 != p_error_code THEN
        RETURN;
      END IF;
      assign_delivery_detail_list(p_source_delivery_id     => intangible_items_ind.delivery_id,
		          p_source_organization_id => intangible_items_ind.organization_id,
		          p_destinate_delivery_id  => l_destinate_delivery_id,
		          p_commit                 => fnd_api.g_true,
		          p_error_code             => p_error_code,
		          p_error_desc             => p_error_desc);
    
      IF 0 != p_error_code THEN
        RETURN;
      END IF;
    
    END LOOP;
  
  EXCEPTION
    WHEN no_delivery_combine_to THEN
      p_error_code := -1;
      p_error_desc := 'WORNING_NO_DELIVERY_COMBINE_TO : xxinv_trx_in_pkg.combine_delivery_by_order(' ||
	          p_delivery_id || ',' || p_header_id || ',' ||
	          ') - no delivery to combine to';
    WHEN OTHERS THEN
      p_error_code := -1;
      p_error_desc := 'EXCEPTION_OTHERS xxinv_trx_in_pkg.combine_delivery_by_ship_set(' ||
	          p_delivery_id || ',' || p_header_id || ') - ' ||
	          SQLERRM;
    
  END combine_delivery_by_order;

  ---------------------------------------------------------------------------------------------------
  -- Ver   When        Who       Description
  -- ----  ----------  --------  --------------------------------------------------------------------
  -- 1.0   20-03-2018  Roman.W   CHG0042242 - Eliminate Ship Confirm errors due to Intangible Items
  -- 3.5   11-06-2018  Roman W.  CHG0043197 : TPL Interface ship confirm -  eliminate ship confirm errors
  --                                                    1) check status of delivery before reissign.
  ---------------------------------------------------------------------------------------------------
  PROCEDURE ship_confirm_delivery_check(p_delivery_id IN NUMBER,
			    p_error_code  OUT NUMBER,
			    p_error_desc  OUT VARCHAR2) IS
    -------------------------------
    --    Cursor Definition
    -------------------------------
    CURSOR ship_set_by_delivery_cur(c_delivery_id NUMBER) IS
      SELECT wdv.ship_set_id,
	 wdv.organization_id
      FROM   wsh_deliverables_v wdv
      WHERE  wdv.delivery_id = p_delivery_id
      AND    wdv.source_code = c_source_code_oe
      AND    wdv.ship_set_id IS NOT NULL
      AND    'Y' = is_valid_delivery(wdv.delivery_id) -- CHG0043197
      GROUP  BY wdv.ship_set_id,
	    wdv.organization_id;
    ------ orders by delivery -----
    CURSOR order_by_delivery_cur(c_delivery_id NUMBER) IS
      SELECT wdv_order.source_header_id,
	 wdv_order.organization_id
      FROM   wsh_deliverables_v wdv_order
      WHERE  wdv_order.delivery_id = p_delivery_id
      AND    wdv_order.source_code = c_source_code_oe
      AND    wdv_order.ship_set_id IS NULL
      AND    'Y' = is_valid_delivery(wdv_order.delivery_id) -- CHG0043197
      GROUP  BY wdv_order.source_header_id,
	    wdv_order.organization_id;
  
    -------------------------------
    --     Local Definitions
    -------------------------------
    l_ship_set_count       NUMBER;
    l_delivery_count       NUMBER;
    l_empty_ship_set_count NUMBER;
  
    l_multiple_delivery_flag VARCHAR2(10);
    l_restricted_item_flag   VARCHAR2(10);
    l_intangible_items_flag  VARCHAR2(10);
    l_combine_inv_items_flag VARCHAR2(10);
    l_inventar_item_flag     VARCHAR2(10);
    l_count                  NUMBER;
  
    exc_error_code EXCEPTION;
    -------------------------------
    --     Code Section
    -------------------------------
  BEGIN
    --    p_error_code := -1;
    --    p_error_desc := 'EXCEPTION TEST';
    --    return;
  
    p_error_code := 0;
    p_error_desc := NULL;
    ----------------------------------------
    --  Ship Sets related to delivery loop
    ----------------------------------------
    FOR ship_set_by_delivery_ind IN ship_set_by_delivery_cur(p_delivery_id)
    LOOP
      -- is to ship set related multiple delivery --
      SELECT decode(COUNT(*), 0, 'N', 'Y')
      INTO   l_multiple_delivery_flag
      FROM   (SELECT wdv.delivery_id
	  FROM   wsh_deliverables_v wdv
	  WHERE  wdv.ship_set_id = ship_set_by_delivery_ind.ship_set_id
	  AND    wdv.delivery_id != p_delivery_id
	  AND    wdv.source_code = c_source_code_oe
	  AND    wdv.organization_id =
	         ship_set_by_delivery_ind.organization_id
	  AND    'Y' = is_valid_delivery(wdv.delivery_id) -- CHG0043197
	  GROUP  BY wdv.delivery_id);
    
      -- is to ship set related restricted items --
      SELECT decode(COUNT(*), 0, 'N', 'Y')
      INTO   l_restricted_item_flag
      FROM   wsh_deliverables_v wdv
      WHERE  wdv.ship_set_id = ship_set_by_delivery_ind.ship_set_id
      AND    wdv.source_code = c_source_code_oe
      AND    'Y' = is_valid_delivery(wdv.delivery_id) -- CHG0043197
      AND    'Y' =
	 xxinv_utils_pkg.is_item_hazard_restricted(p_inventory_item_id => wdv.inventory_item_id)
      AND    0 < (SELECT COUNT(*)
	      FROM   wsh_deliverables_v wdv_sub
	      WHERE  wdv_sub.delivery_id != wdv.delivery_id
	      AND    wdv_sub.source_code = c_source_code_oe
	      AND    wdv_sub.ship_set_id = wdv.ship_set_id
	      AND    'Y' = is_valid_delivery(wdv_sub.delivery_id) -- CHG0043197
	      AND    'N' =
		 xxinv_utils_pkg.is_intangible_items(p_inventory_item_id => wdv_sub.inventory_item_id)
	      AND    'N' =
		 xxinv_utils_pkg.is_item_hazard_restricted(p_inventory_item_id => wdv_sub.inventory_item_id)
	      
	      );
    
      -- is to ship set related Intangible Items -
      SELECT decode(COUNT(*), 0, 'N', 'Y')
      INTO   l_intangible_items_flag
      FROM   wsh_deliverables_v wdv
      WHERE  wdv.ship_set_id = ship_set_by_delivery_ind.ship_set_id
      AND    wdv.source_code = c_source_code_oe
      AND    'Y' = is_valid_delivery(wdv.delivery_id) --CHG0043197
      AND    'Y' =
	 xxinv_utils_pkg.is_intangible_items(p_inventory_item_id => wdv.inventory_item_id)
      AND    0 = (SELECT COUNT(*)
	      FROM   wsh_deliverables_v wdv_sub
	      WHERE  wdv_sub.ship_set_id = wdv.ship_set_id
	      AND    wdv_sub.source_code = c_source_code_oe
	      AND    wdv_sub.delivery_id = wdv.delivery_id
	      AND    'Y' = is_valid_delivery(wdv_sub.delivery_id) -- CHG0043197
	      AND    'N' =
		 xxinv_utils_pkg.is_intangible_items(p_inventory_item_id => wdv_sub.inventory_item_id)
	      --and 'N' = xxinv_utils_pkg.is_item_hazard_restricted(p_inventory_item_id => wdv_sub.inventory_item_id)
	      );
    
      -------------------------------------------------------------------
      --  1) Disconect hazard restricted items from ship set
      --  2) Disconet delivery with only intangible item from ship set
      -------------------------------------------------------------------
      IF ('Y' = l_restricted_item_flag AND 'Y' = l_multiple_delivery_flag) OR
         ('Y' = l_intangible_items_flag AND 'N' = l_multiple_delivery_flag) THEN
      
        set_item_ship_set_to_null(p_ship_set_id => ship_set_by_delivery_ind.ship_set_id,
		          p_error_code  => p_error_code,
		          p_error_desc  => p_error_desc);
      
        IF 0 != p_error_code THEN
          RAISE exc_error_code;
        END IF;
      END IF;
      ------------------------------------------------------------------
      --    Combine delivery with only intangible item to delivery with
      --    inventory non hazard items
      ------------------------------------------------------------------
      IF 'Y' = l_intangible_items_flag AND 'Y' = l_multiple_delivery_flag THEN
        combine_delivery_by_ship_set(p_delivery_id => p_delivery_id,
			 p_ship_set_id => ship_set_by_delivery_ind.ship_set_id,
			 p_error_code  => p_error_code,
			 p_error_desc  => p_error_desc);
      
        IF 0 != p_error_code THEN
          RAISE exc_error_code;
        END IF;
      
      END IF;
    
    END LOOP;
  
    --------------------------------------------------------------
    --
    --------------------------------------------------------------
    FOR order_by_delivery_ind IN order_by_delivery_cur(p_delivery_id)
    LOOP
      --  multiply delivery flag --
      SELECT decode(COUNT(*), 0, 'N', 'Y')
      INTO   l_multiple_delivery_flag
      FROM   (SELECT wdv.delivery_id
	  FROM   wsh_deliverables_v wdv
	  WHERE  wdv.source_header_id =
	         order_by_delivery_ind.source_header_id
	  AND    wdv.delivery_id != p_delivery_id
	  AND    wdv.source_code = c_source_code_oe
	  AND    wdv.organization_id =
	         order_by_delivery_ind.organization_id
	  GROUP  BY wdv.delivery_id);
    
      --  delivery with only Intangible item flag related to order --
      SELECT decode(COUNT(*), 0, 'N', 'Y')
      INTO   l_intangible_items_flag
      FROM   wsh_deliverables_v wdv
      WHERE  wdv.source_header_id = order_by_delivery_ind.source_header_id
      AND    wdv.organization_id = order_by_delivery_ind.organization_id
      AND    wdv.source_code = c_source_code_oe
      AND    'Y' = is_valid_delivery(wdv.delivery_id)
      AND    'Y' =
	 xxinv_utils_pkg.is_intangible_items(p_inventory_item_id => wdv.inventory_item_id)
      AND    0 =
	 (SELECT COUNT(*)
	   FROM   wsh_deliverables_v wdv_sub
	   WHERE  wdv_sub.source_header_id =
	          order_by_delivery_ind.source_header_id
	   AND    wdv_sub.delivery_id = wdv.delivery_id
	   AND    wdv_sub.organization_id = wdv.organization_id
	   AND    wdv_sub.source_code = c_source_code_oe
	   AND    'Y' = is_valid_delivery(wdv_sub.delivery_id)
	   AND    'N' =
	          xxinv_utils_pkg.is_intangible_items(wdv_sub.inventory_item_id));
      --================
      --================
      --  delivery with inventar item flag  --
      SELECT decode(COUNT(*), 0, 'N', 'Y')
      INTO   l_inventar_item_flag
      FROM   (SELECT wdv.delivery_id
	  FROM   wsh_deliverables_v wdv
	  WHERE  wdv.source_header_id =
	         order_by_delivery_ind.source_header_id
	  AND    wdv.organization_id =
	         order_by_delivery_ind.organization_id
	  AND    wdv.source_code = c_source_code_oe
	  AND    'Y' = is_valid_delivery(wdv.delivery_id)
	  AND    'N' =
	         xxinv_utils_pkg.is_intangible_items(p_inventory_item_id => wdv.inventory_item_id)
	  GROUP  BY wdv.delivery_id);
    
      IF 'Y' = l_intangible_items_flag AND 'Y' = l_multiple_delivery_flag AND
         'Y' = l_inventar_item_flag THEN
        combine_delivery_by_order(p_delivery_id => p_delivery_id,
		          p_header_id   => order_by_delivery_ind.source_header_id,
		          p_error_code  => p_error_code,
		          p_error_desc  => p_error_desc);
      
        IF 0 != p_error_code THEN
          RAISE exc_error_code;
        END IF;
      
      END IF;
    
    END LOOP;
  EXCEPTION
    WHEN exc_error_code THEN
      NULL;
  END ship_confirm_delivery_check;
  -----------------------------------------------------------------------------------
  -- Ver      When        Who           Description
  -- -------  ----------  ------------  ----------------------------------------------
  -- 1.0      27-05-2018  Roman W.      CHG0042242 - Eliminate Ship Confirm errors due
  --                                          to Intangible Items
  ------------------------------------------------------------------------------------
  PROCEDURE update_log_status(p_status     IN VARCHAR2,
		      p_error_code OUT NUMBER,
		      p_error_desc OUT VARCHAR2) IS
    -----------------------------
    --    Code Section
    -----------------------------
  BEGIN
    p_error_code := 0;
    p_error_desc := NULL;
  
    UPDATE xxinv_trx_delivery_audit_tbl xtdat
    SET    xtdat.status = p_status
    WHERE  xtdat.conc_request_id = fnd_global.conc_request_id
    AND    xtdat.status = c_new;
  
  EXCEPTION
    WHEN OTHERS THEN
      p_error_code := -1;
      p_error_desc := 'EXCEPTION_OTHERS : xxinv_trx_in_pkg.update_log_status() - ' ||
	          SQLERRM;
  END update_log_status;

  -----------------------------------------------------------------------------------
  -- Ver      When        Who           Description
  -- -------  ----------  ------------  ----------------------------------------------
  -- 1.0      27-05-2018  Roman W.      CHG0042242 - Eliminate Ship Confirm errors due
  --                                          to Intangible Items
  ------------------------------------------------------------------------------------
  PROCEDURE insert_to_log(p_log_dta    IN xxinv_trx_delivery_audit_tbl%ROWTYPE,
		  p_error_code OUT NUMBER,
		  p_error_desc OUT VARCHAR2) IS
    ---------------------------------
    --      Local Definition
    ---------------------------------
    ---------------------------------
    --      Code Section
    ---------------------------------
  BEGIN
    p_error_code := 0;
    p_error_desc := NULL;
  
    INSERT INTO xxinv_trx_delivery_audit_tbl
      (audit_id,
       tpl_user,
       header_id,
       line_id,
       org_id,
       item_id,
       delivery_detail_id,
       from_delivery_id,
       from_delivery_name,
       to_delivery_id,
       to_delivery_name,
       from_ship_set_id,
       to_ship_set_id,
       comments,
       conc_request_id,
       conc_program_id,
       status,
       last_update_date,
       last_updated_by,
       last_update_login,
       creation_date,
       created_by)
    VALUES
      (xxinv_trx_delivery_audit_seq.nextval, -- audit_id
       p_log_dta.tpl_user, -- tpl_user
       p_log_dta.header_id, -- header_id
       p_log_dta.line_id, -- line_id
       p_log_dta.org_id, -- org_id
       p_log_dta.item_id, -- item_id
       p_log_dta.delivery_detail_id, -- delivery_detail_id
       p_log_dta.from_delivery_id, -- from_delivery_id
       p_log_dta.from_delivery_name, -- from_delivery_name
       p_log_dta.to_delivery_id, -- to_delivery_id
       p_log_dta.to_delivery_name, -- to_delivery_name
       p_log_dta.from_ship_set_id, -- from_ship_set_id
       p_log_dta.to_ship_set_id, -- to_ship_set_id
       p_log_dta.comments, -- comments
       fnd_global.conc_request_id, -- conc_request_id
       fnd_global.conc_program_id, -- conc_program_id
       p_log_dta.status, -- status
       -- Who columns --
       SYSDATE,
       fnd_global.user_id,
       fnd_global.login_id,
       SYSDATE,
       fnd_global.user_id);
  
    COMMIT;
  
  EXCEPTION
    WHEN OTHERS THEN
      p_error_code := -1;
      p_error_desc := 'EXCEPTION_OTHERS xxinv_trx_in_pkg.insert_to_log() - ' ||
	          SQLERRM;
  END insert_to_log;

  -------------------------------------------------------
  -- is_report_submitted
  -------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------------------
  --   1.0    2.10.19   yuval tal       p_calling_proc 'PICK' / 'PACK'
  --                                    p_report_type CI commercial inv /PL packing list / COC coc report

  -----------------------------------------------------------------
  FUNCTION is_report_submitted(p_calling_proc VARCHAR2,
		       p_report_type  VARCHAR2,
		       p_delivery_id  NUMBER) RETURN VARCHAR2 IS
  
    l_status VARCHAR2(1);
  BEGIN
  
    IF p_calling_proc = 'PICK' THEN
      SELECT 'Y'
      INTO   l_status
      FROM   xxinv_trx_pick_in t
      WHERE  delivery_id = p_delivery_id
      AND    decode(p_report_type,
	        'COC',
	        t.coc_status,
	        'PL',
	        t.packlist_status,
	        'CI',
	        t.commercial_status,
	        '-1') = 'S'
      AND    rownum = 1;
    
    ELSIF p_calling_proc = 'PACK' THEN
      SELECT 'Y'
      INTO   l_status
      FROM   xxinv_trx_pack_in t
      WHERE  delivery_id = p_delivery_id
      AND    nvl(decode(p_report_type,
		'COC',
		t.coc_status,
		'PL',
		t.packlist_status,
		'CI',
		t.commercial_status,
		'-1'),
	     'N') = 'S'
      AND    rownum = 1;
    ELSE
      RETURN NULL;
    
    END IF;
  
    RETURN l_status;
  
  EXCEPTION
    WHEN no_data_found THEN
      RETURN 'N';
    
  END;

  -------------------------------------------------------------------
  -- Ver   When         Who           Descr
  -- ----  -----------  ------------  ----------------------------
  -- 1.0   15/02/2021   Roman W.      CHG0049272 - TPL
  -------------------------------------------------------------------
  PROCEDURE get_parent_transaction_id(p_subinventory      IN VARCHAR2,
			  p_inventory_item_id IN NUMBER,
			  p_organization_id   IN NUMBER DEFAULT fnd_profile.value('XXINV_TPL_ORGANIZATION_ID'),
			  p_line_location_id  IN NUMBER,
			  p_quantity          IN NUMBER,
			  p_transaction_cur   OUT SYS_REFCURSOR,
			  p_error_code        OUT VARCHAR2,
			  p_error_desc        OUT VARCHAR2) IS
  
    --    c_transaction_cur SYS_REFCURSOR;
    l_quantity_sum NUMBER;
    l_row_count    NUMBER;
  BEGIN
  
    p_error_code      := 0;
    p_error_desc      := NULL;
    p_transaction_cur := NULL;
    print_out('-------- get_parent_transaction_id (' || p_subinventory || ',' ||
	  p_inventory_item_id || ',' || p_organization_id || ',' ||
	  p_line_location_id || ',' || p_quantity || ')');
  
    l_row_count := 0;
    IF p_subinventory =
       fnd_profile.value('XXINV_TPL_DEFAULT_MRB_SUBINVENTORY') THEN
    
      SELECT COUNT(*)
      INTO   l_row_count
      FROM   rcv_supply            rsup,
	 rcv_shipment_lines    rsl,
	 rcv_shipment_headers  rsh,
	 rcv_transactions      rt,
	 rcv_routing_headers   rrh,
	 mtl_system_items_b    msib,
	 po_headers_all        ph,
	 mtl_parameters        mp,
	 po_lines_all          pl,
	 po_line_locations_all pll
      WHERE  rsup.shipment_line_id = rsl.shipment_line_id
      AND    rsl.shipment_header_id = rsh.shipment_header_id
      AND    rsup.rcv_transaction_id = rt.transaction_id
      AND    rrh.routing_header_id = rt.routing_header_id
      AND    rsup.item_id = msib.inventory_item_id
      AND    rsup.to_organization_id = msib.organization_id
      AND    rsup.po_header_id = ph.po_header_id
      AND    rsup.po_line_id = pl.po_line_id
      AND    rsup.po_line_location_id = pll.line_location_id
      AND    mp.organization_id = rsup.to_organization_id
      AND    rt.inspection_status_code = 'REJECTED'
      AND    (rrh.routing_header_id = 2 OR rrh.routing_header_id = 1 OR
	rrh.routing_header_id = 3)
      AND    msib.inventory_item_id = p_inventory_item_id
      AND    rsup.to_organization_id = p_organization_id
      AND    rsup.po_line_location_id = p_line_location_id;
    
      IF 0 < l_row_count THEN
        OPEN p_transaction_cur FOR
          SELECT rt.transaction_id
          FROM   rcv_supply            rsup,
	     rcv_shipment_lines    rsl,
	     rcv_shipment_headers  rsh,
	     rcv_transactions      rt,
	     rcv_routing_headers   rrh,
	     mtl_system_items_b    msib,
	     po_headers_all        ph,
	     mtl_parameters        mp,
	     po_lines_all          pl,
	     po_line_locations_all pll
          WHERE  rsup.shipment_line_id = rsl.shipment_line_id
          AND    rsl.shipment_header_id = rsh.shipment_header_id
          AND    rsup.rcv_transaction_id = rt.transaction_id
          AND    rrh.routing_header_id = rt.routing_header_id
          AND    rsup.item_id = msib.inventory_item_id
          AND    rsup.to_organization_id = msib.organization_id
          AND    rsup.po_header_id = ph.po_header_id
          AND    rsup.po_line_id = pl.po_line_id
          AND    rsup.po_line_location_id = pll.line_location_id
          AND    mp.organization_id = rsup.to_organization_id
          AND    rt.inspection_status_code = 'REJECTED'
          AND    (rrh.routing_header_id = 2 OR rrh.routing_header_id = 1 OR
	    rrh.routing_header_id = 3)
          AND    msib.inventory_item_id = p_inventory_item_id
          AND    rsup.to_organization_id = p_organization_id
          AND    rsup.po_line_location_id = p_line_location_id;
      END IF;
    
    ELSE
    
      SELECT COUNT(*)
      INTO   l_row_count
      FROM   rcv_supply            rsup,
	 rcv_shipment_lines    rsl,
	 rcv_shipment_headers  rsh,
	 rcv_transactions      rt,
	 rcv_routing_headers   rrh,
	 mtl_system_items_b    msib,
	 po_headers_all        ph,
	 mtl_parameters        mp,
	 po_lines_all          pl,
	 po_line_locations_all pll
      WHERE  rsup.shipment_line_id = rsl.shipment_line_id
      AND    rsl.shipment_header_id = rsh.shipment_header_id
      AND    rsup.rcv_transaction_id = rt.transaction_id
      AND    rrh.routing_header_id = rt.routing_header_id
      AND    rsup.item_id = msib.inventory_item_id
      AND    rsup.to_organization_id = msib.organization_id
      AND    rsup.po_header_id = ph.po_header_id
      AND    rsup.po_line_id = pl.po_line_id
      AND    rsup.po_line_location_id = pll.line_location_id
      AND    mp.organization_id = rsup.to_organization_id
      AND    rt.inspection_status_code != 'REJECTED'
      AND    (rrh.routing_header_id = 2 OR rrh.routing_header_id = 1 OR
	rrh.routing_header_id = 3)
      AND    msib.inventory_item_id = p_inventory_item_id
      AND    rsup.to_organization_id = p_organization_id
      AND    rsup.po_line_location_id = p_line_location_id;
    
      IF 0 < l_row_count THEN
      
        OPEN p_transaction_cur FOR
          SELECT rt.transaction_id
          FROM   rcv_supply            rsup,
	     rcv_shipment_lines    rsl,
	     rcv_shipment_headers  rsh,
	     rcv_transactions      rt,
	     rcv_routing_headers   rrh,
	     mtl_system_items_b    msib,
	     po_headers_all        ph,
	     mtl_parameters        mp,
	     po_lines_all          pl,
	     po_line_locations_all pll
          WHERE  rsup.shipment_line_id = rsl.shipment_line_id
          AND    rsl.shipment_header_id = rsh.shipment_header_id
          AND    rsup.rcv_transaction_id = rt.transaction_id
          AND    rrh.routing_header_id = rt.routing_header_id
          AND    rsup.item_id = msib.inventory_item_id
          AND    rsup.to_organization_id = msib.organization_id
          AND    rsup.po_header_id = ph.po_header_id
          AND    rsup.po_line_id = pl.po_line_id
          AND    rsup.po_line_location_id = pll.line_location_id
          AND    mp.organization_id = rsup.to_organization_id
          AND    rt.inspection_status_code != 'REJECTED'
          AND    (rrh.routing_header_id = 2 OR rrh.routing_header_id = 1 OR
	    rrh.routing_header_id = 3)
          AND    msib.inventory_item_id = p_inventory_item_id
          AND    rsup.to_organization_id = p_organization_id
          AND    rsup.po_line_location_id = p_line_location_id;
      END IF;
    
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      p_error_code := 2;
      p_error_desc := 'EXCEPTION_OTHERS xxinv_trx_in_pkg.get_parent_transaction_id(' ||
	          p_subinventory || ',' || p_inventory_item_id || ',' ||
	          p_organization_id || ',' || p_line_location_id || ',' ||
	          p_quantity || ') - ' || SQLERRM;
  END get_parent_transaction_id;
  ----------------------------------------------------------------------------------------
  -- Ver    When        Who          Descr
  -- -----  ----------  -----------  ---------------------------------------------------
  -- 1.0    18/03/2021  Roman W.     CHG0049272 - TPL - Receiving Inspection interface
  ----------------------------------------------------------------------------------------
  PROCEDURE insert_rcv_loads(p_trx_id              IN NUMBER,
		     p_po_line_location_id IN NUMBER,
		     p_doc_type            IN VARCHAR2,
		     p_parent_line_id      IN NUMBER,
		     p_loads_xml           IN VARCHAR2,
		     p_error_code          OUT VARCHAR2,
		     p_error_desc          OUT VARCHAR2) IS
    -------------------------
    --   Local Definition
    -------------------------
    CURSOR loads_cur(c_xml VARCHAR2) IS
      SELECT load_id,
	 load_qty
      FROM   xmltable('Loads/LoadsRow' passing xmltype(c_xml) columns
	          load_id VARCHAR2(120) path 'LOAD_ID',
	          load_qty VARCHAR2(120) path 'LOAD_QTY');
    l_xmltype xmltype;
    -------------------------
    --   Code Section
    -------------------------
  BEGIN
  
    p_error_code := '0';
    p_error_desc := NULL;
  
    message(p_trx_id);
    message(p_po_line_location_id);
    message(p_doc_type);
    message(p_parent_line_id);
    message(p_loads_xml);
  
    l_xmltype := xmltype.createxml(p_loads_xml);
  
    FOR loads_ind IN loads_cur(p_loads_xml)
    LOOP
      message('load_id = ' || loads_ind.load_id || ',' || 'load_qty = ' ||
	  loads_ind.load_qty);
      INSERT INTO xxinv_trx_rcv_loads_in
        (parent_trx_id,
         parent_line_id,
         po_line_location_id,
         doc_type,
         load_id,
         load_qty)
      VALUES
        (p_trx_id,
         p_parent_line_id,
         p_po_line_location_id,
         p_doc_type,
         loads_ind.load_id,
         loads_ind.load_qty);
    END LOOP;
  
  EXCEPTION
    WHEN OTHERS THEN
      p_error_code := '2';
      p_error_desc := 'EXCEPTION_OTHERS xxinv_trx_in_pkg.insert_rcv_loads(' ||
	          p_trx_id || ') - ' || SQLERRM;
      message(p_error_desc);
  END insert_rcv_loads;

END xxinv_trx_in_pkg;
/
