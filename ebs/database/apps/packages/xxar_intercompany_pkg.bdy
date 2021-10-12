CREATE OR REPLACE PACKAGE BODY xxar_intercompany_pkg AS

-- ---------------------------------------------------------------------------------------------
-- Name: xxar_intercompany_pkg    
-- Created By: MMAZANET
-- Revision:   1.0
-- --------------------------------------------------------------------------------------------
-- Purpose: This code is used to allow INTERCOMPANY orders to invoice as the shipments are 
--          received.  This is accomplished manipulating the orders in the ra_interface_lines
--          table.  See details in the process_intercompany_invoices.
-- ----------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  01/23/2015  MMAZANET    Initial Creation for CHG0033379.
-- ---------------------------------------------------------------------------------------------

  g_log               VARCHAR2(1)   := fnd_profile.value('AFLOG_ENABLED');
  g_log_module        VARCHAR2(100) := fnd_profile.value('AFLOG_MODULE');
  g_request_id        NUMBER        := fnd_profile.value('CONC_REQUEST_ID');
  g_user_id           NUMBER        := fnd_profile.value('USER_ID');
  g_log_program_unit  VARCHAR2(100);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Write to request log if 'FND: Debug Log Enabled' is set to Yes
  -- ----------------------------------------------------------------------------------------------
  -- Ver  Date        Name        Description
  -- 1.0  01/23/2015  MMAZANET    Initial Creation for CHG0033379.
  -- ---------------------------------------------------------------------------------------------
  PROCEDURE write_log(p_msg  VARCHAR2)
  IS
  BEGIN
    IF g_log = 'Y' AND 'xxra.invoice_intf.xxra_intercompany_pkg.'||g_log_program_unit LIKE LOWER(g_log_module) THEN
      fnd_file.put_line(fnd_file.log,p_msg);
    END IF;
  END write_log;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This function is checking to see wether the receiving transaction has already been
  --          applied against an order for invoicing.  The receiving transaction could have already
  --          been invoiced (checking ra_customer_trx_lines_all for this scenario) or could be 
  --          awaiting invoicing (checking ra_interface_lines_all for this scenario).  If already
  --          received, return 'Y' else return 'N'.
  -- ----------------------------------------------------------------------------------------------
  -- Ver  Date        Name        Description
  -- 1.0  01/23/2015  MMAZANET    Initial Creation for CHG0033379.
  -- ---------------------------------------------------------------------------------------------  
  FUNCTION has_receipt_been_invoiced(
    p_receiving_trx_id        NUMBER,
    p_order_line_id           NUMBER
  )
  RETURN VARCHAR2
  IS l_dummy VARCHAR2(1);
  BEGIN
    -- Check existing invoiced lines for receiving trx id
    SELECT 'Y' 
    INTO l_dummy 
    FROM ra_customer_trx_lines_all
    WHERE interface_line_context        = 'INTERCOMPANY'
    AND   interface_line_attribute6     = TO_CHAR(p_order_line_id)
    AND   interface_line_attribute11    = TO_CHAR(p_receiving_trx_id);
    
    RETURN 'Y'; 
  EXCEPTION
    WHEN OTHERS THEN
      BEGIN
        -- Check existing interface lines for receiving trx id.  This could happen in the 
        -- event of an error when Autoinvoice Import runs.
        SELECT 'Y' 
        INTO l_dummy 
        FROM ra_interface_lines_all
        WHERE interface_line_context        = 'INTERCOMPANY'
        AND   interface_line_attribute6     = TO_CHAR(p_order_line_id)
        AND   interface_line_attribute11    = TO_CHAR(p_receiving_trx_id);  
        
        RETURN 'Y';
      EXCEPTION
        WHEN OTHERS THEN
          RETURN 'N';
      END;
  END has_receipt_been_invoiced;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Write to request log if 'FND: Debug Log Enabled' is set to Yes
  -- ----------------------------------------------------------------------------------------------
  -- Ver  Date        Name        Description
  -- 1.0  01/23/2015  MMAZANET    Initial Creation for CHG0033379.
  -- ---------------------------------------------------------------------------------------------
  PROCEDURE write_output(
    p_order_number                IN VARCHAR2,
    p_line_number                 IN VARCHAR2,
    p_req_number                  IN VARCHAR2,
    p_req_line_number             IN NUMBER,
    p_receiving_transaction_id    IN NUMBER,
    p_from_org                    IN VARCHAR2,
    p_to_org                      IN VARCHAR2,
    p_quantity                    IN NUMBER,
    p_quantity_received           IN NUMBER,
    p_msg                         IN VARCHAR2
  )
  IS
  BEGIN    
    fnd_file.put_line(fnd_file.output,RPAD(p_order_number,17,' ')||'  '
                    ||RPAD(p_line_number,11,' ')||'  '
                    ||RPAD(TO_CHAR(p_req_number),11,' ')||'  '
                    ||RPAD(TO_CHAR(p_req_line_number),8,' ')||'  '
                    ||RPAD(NVL(TO_CHAR(p_receiving_transaction_id),'-'),24,' ')||'  '
                    ||RPAD(TO_CHAR(p_quantity),8,' ')||'  '
                    ||RPAD(NVL(TO_CHAR(p_quantity_received),'-'),8,' ')||'  '
                    ||RPAD(TO_CHAR(p_from_org),8,' ')||'  '
                    ||RPAD(TO_CHAR(p_to_org),8,' ')||'  '
                    ||p_msg
    );
  EXCEPTION
    WHEN OTHERS THEN 
      fnd_file.put_line(fnd_file.output,'Unexepected Error occurred in write_output: '||DBMS_UTILITY.FORMAT_ERROR_STACK);
  END write_output;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Copies ra_interface_lines_all line using rowid as copy from source.  New line may 
  --          have different values for request_id, interface_status, interface_line_attribute11, 
  --          quantity, and amount.
  -- ----------------------------------------------------------------------------------------------
  -- Ver  Date        Name        Description
  -- 1.0  01/23/2015  MMAZANET    Initial Creation for CHG0033379.
  -- ---------------------------------------------------------------------------------------------
  PROCEDURE copy_interface_line(
    p_rowid                       IN ROWID,
    p_interface_line_attribute11  IN VARCHAR2,
    p_quantity                    IN NUMBER,
    p_amount                      IN NUMBER,
    p_invoice_eligible_flag       IN VARCHAR2,
    x_return_status               OUT VARCHAR2,
    x_return_message              OUT VARCHAR2
  )
  IS
    l_ra_interface_lines_all_rec  ra_interface_lines_all%ROWTYPE;
    l_request_id                  NUMBER;
    l_interface_status            VARCHAR2(1);      
  BEGIN
    write_log('BEGIN COPY_INTERFACE_LINE');
    write_log('p_rowid: '||p_rowid);
    write_log('p_interface_line_attribute11: '||p_interface_line_attribute11);
    write_log('p_quantity: '||p_quantity);
    write_log('p_amount: '||p_amount);
    write_log('p_invoice_eligible_flag: '||p_invoice_eligible_flag); 
    
    IF p_invoice_eligible_flag = 'Y' THEN
    -- Allows lines to be invoiced
      l_request_id       := TO_NUMBER(NULL);
      l_interface_status := NULL;
    ELSE
    -- Prevents lines from being invoiced
      l_request_id       := -9;
      l_interface_status := 'P';            
    END IF;      
    
    -- Copy current line
    SELECT *
    INTO l_ra_interface_lines_all_rec
    FROM ra_interface_lines_all
    WHERE rowid = p_rowid;
    
    l_ra_interface_lines_all_rec.interface_line_attribute11 := p_interface_line_attribute11;
    l_ra_interface_lines_all_rec.quantity                   := NVL(p_quantity,l_ra_interface_lines_all_rec.quantity);
    l_ra_interface_lines_all_rec.amount                     := NVL(p_amount,l_ra_interface_lines_all_rec.amount);
    l_ra_interface_lines_all_rec.request_id                 := l_request_id;
    l_ra_interface_lines_all_rec.interface_status           := l_interface_status;
    l_ra_interface_lines_all_rec.creation_date              := SYSDATE;
    l_ra_interface_lines_all_rec.created_by                 := g_user_id;
    l_ra_interface_lines_all_rec.last_update_date           := SYSDATE;
    l_ra_interface_lines_all_rec.last_updated_by            := g_user_id;
  
    -- Insert copied line
    INSERT INTO ra_interface_lines_all 
    VALUES l_ra_interface_lines_all_rec;
  
    x_return_status := 'S';
    write_log('BEGIN COPY_INTERFACE_LINE');
  EXCEPTION
    WHEN OTHERS THEN 
      x_return_status   := 'E';
      x_return_message  := 'Unexpected Error in COPY_INTERFACE_LINE: '||DBMS_UTILITY.FORMAT_ERROR_STACK;
  END copy_interface_line;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Procedure used to update ra_interface_lines_all.
  -- ----------------------------------------------------------------------------------------------
  -- Ver  Date        Name        Description
  -- 1.0  01/23/2015  MMAZANET    Initial Creation for CHG0033379.
  -- ---------------------------------------------------------------------------------------------
  PROCEDURE update_interface_line(
    p_rowid                       IN ROWID,
    p_interface_line_attribute11  IN VARCHAR2,
    p_order_number                IN VARCHAR2,
    p_quantity                    IN NUMBER,
    p_amount                      IN NUMBER,
    p_invoice_eligible_flag       IN VARCHAR2,
    x_return_status               OUT VARCHAR2,
    x_return_message              OUT VARCHAR2
  )
  IS
    CURSOR c_update
    IS
      SELECT 
        quantity,
        interface_line_attribute11
      FROM ra_interface_lines_all
      WHERE rowid                     = NVL(p_rowid,rowid)
      AND   interface_line_attribute1 = NVL(p_order_number,interface_line_attribute1)
      AND   interface_line_context    = 'INTERCOMPANY'
      FOR UPDATE OF
        quantity,
        interface_line_attribute11 NOWAIT;
      
    l_ra_interface_lines_all_rec  ra_interface_lines_all%ROWTYPE;
    l_request_id                  NUMBER;
    l_interface_status            VARCHAR2(1);
    
    e_lock                        EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_lock,-54);
    
  BEGIN
    write_log('BEGIN UPDATE_INTERFACE_LINE');
    write_log('p_rowid: '||p_rowid);
    write_log('p_interface_line_attribute11: '||p_interface_line_attribute11);
    write_log('p_quantity: '||p_quantity);
    write_log('p_amount: '||p_amount);
    write_log('p_invoice_eligible_flag: '||p_invoice_eligible_flag); 
    
    IF p_invoice_eligible_flag = 'Y' THEN
    -- Allows lines to be invoiced  
      l_request_id       := TO_NUMBER(NULL);
      l_interface_status := NULL;
    ELSE
    -- Prevents lines from being invoiced
      l_request_id       := -9;
      l_interface_status := 'P';            
    END IF;

    -- There is special handling for when p_invoice_eligible_flag = 'P'.  When this is set, we simply want
    -- to cycle through and set interface_line_attribute11 = '-9' if it is currently NULL.  This may or may 
    -- not get overwritten later in the program.
    FOR rec IN c_update LOOP
      UPDATE ra_interface_lines_all
      SET 
        -- If P, this is for pre-processing, and this value should be set to -9, IF it is currently NULL
        interface_line_attribute11  = DECODE(p_invoice_eligible_flag
                                      , 'P', NVL(interface_line_attribute11, p_interface_line_attribute11)
                                      , p_interface_line_attribute11),
        quantity                    = NVL(p_quantity,quantity),
        amount                      = NVL(p_amount,amount),
        -- If P, this is for pre-processing and these values shouldn't be touched, so
        -- they are simply set to their DB values.
        request_id                  = DECODE(p_invoice_eligible_flag
                                      , 'P', request_id
                                      , l_request_id),
        interface_status            = DECODE(p_invoice_eligible_flag
                                      , 'P',  interface_status
                                      , l_interface_status),  
        last_update_date            = SYSDATE,
        last_updated_by             = g_user_id
      WHERE CURRENT OF c_update;
    END LOOP; 
  
    x_return_status := 'S';
    write_log('END UPDATE_INTERFACE_LINE');
  EXCEPTION
    WHEN e_lock THEN
      x_return_status   := 'E';
      x_return_message  := 'Error: Row locked';       
    WHEN OTHERS THEN 
      x_return_status   := 'E';
      x_return_message  := 'Unexpected Error in UPDATE_INTERFACE_LINE: '||DBMS_UTILITY.FORMAT_ERROR_STACK;        
  END update_interface_line;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Check that order line has not been yet completely invoiced.  If it has and 
  --          we have an interface line for it in ra_interface_lines_all, we have a problem and 
  --          an error should be raised.
  -- ----------------------------------------------------------------------------------------------
  -- Ver  Date        Name        Description
  -- 1.0  01/23/2015  MMAZANET    Initial Creation for CHG0033379.
  -- ---------------------------------------------------------------------------------------------
  FUNCTION is_order_completely_invoiced(
    p_order_line_id     NUMBER,
    p_org_id            NUMBER,
    p_pending_qty       NUMBER
  )
  RETURN BOOLEAN
  IS
    l_invoiced_qty          NUMBER := 0;
    l_pending_invoice_qty   NUMBER := 0;
    l_og_quantity           NUMBER := 0;
  BEGIN
    write_log('IS_ORDER_COMPLETELY_INVOICED');
    write_log('p_order_line_id: '||p_order_line_id);
    write_log('p_org_id: '||p_org_id);
 
    -- Get pending invoice quantity
    SELECT NVL(SUM(quantity),0)
    INTO l_pending_invoice_qty
    FROM ra_interface_lines_all
    WHERE interface_line_context      = 'INTERCOMPANY'
    AND   org_id                      = p_org_id
    AND   interface_line_attribute6   = TO_CHAR(p_order_line_id)
    AND   NVL(interface_line_attribute11,'X')
                                      -- These are audit lines 
                                      NOT IN ('MASTER','COMPLETE');

    write_log('l_pending_invoice_qty: '||l_pending_invoice_qty); 
    
    -- Get total amount invoiced for order line
    SELECT NVL(SUM(quantity_invoiced),0)
    INTO l_invoiced_qty 
    FROM ra_customer_trx_lines_all
    WHERE interface_line_context    = 'INTERCOMPANY'
    AND   org_id                    = p_org_id
    AND   interface_line_attribute6 = TO_CHAR(p_order_line_id);
    
    write_log('l_invoiced_qty: '||l_invoiced_qty); 
    
    -- Get total order line quantity to be invoiced 
    SELECT NVL(ordered_quantity,0)
    INTO l_og_quantity
    FROM oe_order_lines_all
    WHERE line_id = p_order_line_id;  
  
    write_log('l_og_quantity: '||l_og_quantity);   
  
    -- Take pending + invoiced quantity and check if that value is greater
    -- than the quantity which should be invoiced for the order line.
    -- If the order is completely invoiced return TRUE.  This will trigger an
    -- error in calling program because order has already been invoiced.
    IF (l_invoiced_qty + l_pending_invoice_qty) > l_og_quantity THEN
      RETURN TRUE;
    ELSE
      RETURN FALSE;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN   
      RETURN FALSE;
  END is_order_completely_invoiced;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: In certain cases we may have two receiving lines for the same ra_interface_line in the 
  --          same Autoinvoice run.  When the first line comes through, it creates a 'PENDING' line
  --          which has the remaining quantity to be received and invoiced.  When the second line
  --          comes through, it needs to look for this PENDING row because the handling is slightly
  --          different for this scenario.  See the call to this procedure in process_intercompany_invoices
  --          for further explanation.
  -- ----------------------------------------------------------------------------------------------
  -- Ver  Date        Name        Description
  -- 1.0  01/23/2015  MMAZANET    Initial Creation for CHG0033379.
  -- ---------------------------------------------------------------------------------------------
  PROCEDURE check_for_pending(
    p_material_transaction_id   IN VARCHAR2,
    p_order_line_id             IN VARCHAR2,
    x_pending_exists_flag       OUT VARCHAR2,
    x_quantity                  OUT NUMBER,
    x_rowid                     OUT ROWID,
    x_return_status             OUT VARCHAR2,
    x_return_message            OUT VARCHAR2
  )
  IS
  BEGIN
    write_log('BEGIN CHECK_FOR_PENDING');
    
    SELECT 
      rowid,
      NVL(quantity,0)
    INTO 
      x_rowid,
      x_quantity
    FROM ra_interface_lines_all
    WHERE interface_line_context      = 'INTERCOMPANY'
    AND   interface_line_attribute6   = p_order_line_id
    AND   interface_line_attribute7   = p_material_transaction_id
    AND   interface_line_attribute11  = 'PENDING';
    
    x_pending_exists_flag   := 'Y';
    x_return_status         := 'S';
    write_log('END CHECK_FOR_PENDING');
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      write_log('No pending rows found');
      x_pending_exists_flag   := 'N';
      x_return_status         := 'S';     
    WHEN OTHERS THEN 
      x_pending_exists_flag   := 'N';
      x_return_status         := 'E';
      x_return_message        := 'Unexpected Error in UPDATE_INTERFACE_LINE: '||DBMS_UTILITY.FORMAT_ERROR_STACK;   
  END check_for_pending;

  -- ---------------------------------------------------------------------------------------------------------
  -- Purpose: Main procedure for processing Intercompany invoices.  This is called from the xxar_autoinvoice_pkg.
  --          Currently, Users manually wait for complete receipt of intercompany invoices before running the 
  --          Autoinvoice program for Intercompany.  However, now they would like to invoice upon receiving 
  --          the order or part of the order.  For example, if I ordered a quantity of 10 but only received
  --          a quantity of 2 today, I would want to invoice those 2 and the other 8 would still be available
  --          for invoicing.  
  --
  --          There are three scenarios that can arise based on what the users want to accomplish above.  It's 
  --          important to note that lines are at the mtl_material_transaction level in ra_interface_lines_all.
  --          The line may need to be split to accommodate the functionality above.  Here are examples of the
  --          various scenarios along with the action that scenario will follow
  --
  --          Scenario              Action
  --          --------------------  --------------------------------------------------------------------------
  --          Full order is received and nothing prior was invoiced
  --          Ordered 1 Received 1  interface_line_attribute11 is updated with rcv_transactions transaction_id
  --          Invoiced 0            and will be allowed through for invoicing
  --
  --          Order is partially received and nothing prior was invoiced
  --          Ordered 3 Received 1  Original ra_interface_line has 'MASTER' populated on interface_line_attribute11.
  --          Invoiced 0            This line will never be invoiced and is used for auditing.  Two new lines 
  --                                are created based on the master line.  One has a quantity of 1 and has 
  --                                interface_line_attribute11 populated with rcv_transactions transaction_id. 
  --                                This line will be invoiced since it has been received.  The other line will 
  --                                have the remaining quantity of 2 and will have interface_line_attribute11 
  --                                populated with PENDING.  This line will wait until more is received.
  --
  --          Order has been completely invoiced and we receive a line for interface
  --          Ordered 3 Received 1  If the order has already been completely invoiced and we receive a line for
  --          Invoiced 3            invoicing, this will result in the program throwing an error.
  -- 
  -- Note:    This procedure is transactional and will COMMIT upon successful processing of an ra_interface_line 
  --          row.  If any part of the row errors, the transaction will be rolled back.
  --
  -- Parameters : p_order_numbers_tbl
  --                This is populated in xxar_autoinvoice_pkg with order numbers eligible for invoicing based
  --                on program parameters
  --              p_show_success_flag
  --                This will show error records as well as success records in the output if set to 'Y'
  --
  -- Change History
  -- ---------------------------------------------------------------------------------------------------------
  -- 23-JAN-2015  mmazanet    Initial creation for CHG0033379.
  -- ---------------------------------------------------------------------------------------------------------
  PROCEDURE process_intercompany_invoices(
    p_order_numbers_tbl     IN  xxoe_order_numbers_type,
    p_organization_id       IN  NUMBER,
    p_show_success_flag     IN  VARCHAR2,
    x_return_message        OUT VARCHAR2,
    x_return_status         OUT VARCHAR2
  )
  IS
    CURSOR c_get_intercompany(p_order_number IN NUMBER)
    IS
    SELECT
      row_id,
      order_number,
      order_line_number,
      order_line_id,        
      material_transaction_id,
      master_rec_status,
      org_id,
      from_org,
      to_org,
      requisition_number,
      requisition_line,      
      quantity,
      unit_selling_price,
      amount,
      DECODE(received_invoiced_flag
      , 'Y', NULL
      , received_transaction_id)                received_transaction_id,
      DECODE(received_invoiced_flag
      , 'Y', NULL
      , received_quantity)                      received_quantity
    FROM
    (
      SELECT 
        rila.rowid                              row_id,
        rila.interface_line_attribute1          order_number,
        rila.interface_line_attribute2          order_line_number,
        TO_NUMBER(rila.interface_line_attribute6)          
                                                order_line_id,
        TO_NUMBER( rila.interface_line_attribute7)          
                                                material_transaction_id,
        rila.interface_line_attribute11         master_rec_status,
        rila.org_id                             org_id,
        ood_from.organization_name              from_org,
        ood_to.organization_name                to_org,
        rqha.segment1                           requisition_number,
        rqla.line_num                           requisition_line,      
        rila.quantity                           quantity,
        rila.unit_selling_price                 unit_selling_price,
        rila.amount                             amount,
        rct.transaction_id                      received_transaction_id, -- will be stored in interface_attribute11
        rct.quantity                            received_quantity,
        -- Checks if the receiving transaction has already been applied against a line
        -- that has already been invoiced or is awaiting invoice
        xxar_intercompany_pkg.has_receipt_been_invoiced(rct.transaction_id,ol.line_id)
                                                received_invoiced_flag        
      FROM 
        ra_interface_lines_all                  rila,
        oe_order_lines_all                      ol,
        oe_transaction_types_all                ott,
        oe_order_headers_all                    oh,
        po_requisition_lines_all                rqla,
        po_requisition_headers_all              rqha,
        po_req_distributions_all                rqda,      
        rcv_shipment_lines                      rsl,
        rcv_shipment_headers                    rsh,
        mtl_material_transactions               mmt,
        rcv_transactions                        rct,
        mtl_system_items_b                      msib,
        org_organization_definitions            ood_from,
        org_organization_definitions            ood_to,
        fnd_lookup_values                       flv,
        fnd_lookup_values                       flv_org,
        hz_cust_accounts_all                    hca      
      -- Join to intercompany order headers
      WHERE rila.interface_line_context               = 'INTERCOMPANY'
      AND   rila.interface_line_attribute6            = TO_CHAR(ol.line_id)  
      AND   ol.header_id                              = oh.header_id 
      AND   ol.line_type_id                           = ott.transaction_type_id
      -- Returns, Credits, Trade Ins will not wait for receiving transactions
      AND   ott.order_category_code                   <> 'RETURN'
      AND   ol.source_document_type_id                = 10
      -- Join to PO info    
      AND   ol.source_document_line_id                = rqla.requisition_line_id (+)
      AND   rqla.requisition_header_id                = rqha.requisition_header_id (+)    
      AND   rqda.distribution_id                      = rsl.req_distribution_id                    
      AND   rqla.requisition_line_id                  = rsl.requisition_line_id
      AND   rsl.item_id                               = msib.inventory_item_id
      AND   rsl.from_organization_id                  = msib.organization_id 
      AND   rsl.from_organization_id                  = ood_from.organization_id
      AND   rsl.to_organization_id                    = ood_to.organization_id
      AND   rsl.shipment_header_id                    = rsh.shipment_header_id
      AND   rsl.shipment_line_id                      = rct.shipment_line_id (+)                   
      AND   'RECEIVE'                                 = rct.transaction_type (+)   
      -- Join to material transactions
      AND   rsl.mmt_transaction_id                    = mmt.transaction_id                
      AND   ol.line_id                                = mmt.trx_source_line_id
      AND   TO_NUMBER(rila.interface_line_attribute7) = mmt.transaction_id
      -- Restricts customers this should fire for
      AND   flv.lookup_type                           = 'XXAR_INTERCOMPANY_CUST_LIST'
      AND   flv.lookup_code                           = hca.account_number
      AND   flv.language                              = 'US'
      AND   flv.enabled_flag                          = 'Y'
      AND   hca.cust_account_id                       = oh.sold_to_org_id   
      -- Restricts orgs this should fire for
      AND   flv_org.lookup_type                       = 'XXAR_INTERCOMPANY_ORG_LIST'
      AND   flv_org.lookup_code                       = rila.org_id
      AND   flv_org.language                          = 'US'
      AND   flv_org.enabled_flag                      = 'Y'    
      -- Apply parameters
      AND   rila.org_id                               = p_organization_id
      AND   interface_line_attribute1                 = TO_CHAR(p_order_number)
      -- Only look at pending or null records.  If this is populated with 'MASTER' it's an
      -- audit record and should not be processed.  'PENDING', '-9', or NULL are all eligible
      -- for processing.
      AND   NVL(interface_line_attribute11,'X')       IN ('PENDING','X','-9')                   -- indicates this is the master record
    )
    -- If this flag is 'Y' the received_transaction_id has already been used on an 
    -- invoice on interface line, and we don't want to use it here.
    WHERE received_invoiced_flag    = 'N'    
    ORDER BY 
      order_number,
      order_line_number;

    l_ra_interface_lines_rec        ra_interface_lines_all%ROWTYPE;

    l_error_count                   NUMBER := 0;
    l_success_count                 NUMBER := 0;
    l_remaining_quantity            NUMBER := 0;
    l_remaining_amount              NUMBER := 0;
    l_invoice_amount                NUMBER := 0;
    l_pending_quantity              NUMBER := 0;
    l_pending_rowid                 ROWID;
    l_pending_exists_flag           VARCHAR2(1) := 'Y';
    l_create_invoice_line_flag      VARCHAR2(1) := 'N';
    l_rowid                         ROWID;
    l_quantity                      NUMBER := 0;
    
    l_message                       VARCHAR2(1000);
    l_return_status                 VARCHAR2(1);
    l_create_master_flag            VARCHAR2(1);
    
    e_error                         EXCEPTION;
  BEGIN
    write_log('********** BEGIN PROCESS_INTERCOMPANY_INVOICES **********');
    
    -- Create output report header
    fnd_file.put_line(fnd_file.output,' ');
    fnd_file.put_line(fnd_file.output,'**** PROCECESSING INTERCOMPANY ORDERS ****');
    fnd_file.put_line(fnd_file.output,'                                Requisition  Req Line  Receiving Transaction ID            Quantity');
    fnd_file.put_line(fnd_file.output,'Order Number       Line Number  Number       Number    (rcv_transactions)        Quantity  Received  From Org  To Org    Message');
    fnd_file.put_line(fnd_file.output,'-----------------  -----------  -----------  --------  ------------------------  --------  --------  --------  --------  -------  '||RPAD('-',100,'-'));

    FOR i IN 1.. p_order_numbers_tbl.COUNT LOOP
      BEGIN
        write_log('** Begin LOOP for order '||TO_CHAR(p_order_numbers_tbl(i)));  

        -- Pre-processing used to initially set interface_line_attribute11 to -9.  This flexfield needs 
        -- to contain a value for INTERCOMPANY transactions.  If it has an associated received_transaction_id from the 
        -- c_get_intercompany CURSOR, interface_line_attribute11 will be written over with received_transaction_id. 
        update_interface_line(
          p_rowid                       => NULL,
          p_interface_line_attribute11  => '-9',
          p_order_number                => p_order_numbers_tbl(i),
          p_quantity                    => NULL,
          p_amount                      => NULL,
          p_invoice_eligible_flag       => 'P',
          x_return_status               => l_return_status,
          x_return_message              => l_message
        );

        IF l_return_status <> 'S' THEN 
          RAISE e_error;
        END IF;

        -- ********************************************************************************
        -- Processing of Intercompany invoices which need to wait for receipt begins here
        -- ********************************************************************************
        FOR rec IN c_get_intercompany(p_order_numbers_tbl(i))
        LOOP
          l_create_invoice_line_flag := 'N';
          write_log('** Begin Inner LOOP for order '||TO_CHAR(p_order_numbers_tbl(i)));
          write_log('order_line_number        : '||rec.order_line_number);
          write_log('interface_line_attribute6: '||rec.order_line_id);
          write_log('interface_line_attribute7: '||rec.material_transaction_id);

          BEGIN
            -- check for receipt of all lines... if all lines already received, we have a problem
            -- as the order line has already been invoiced.
            IF  is_order_completely_invoiced(
                  p_order_line_id   => rec.order_line_id,
                  p_org_id          => rec.org_id,
                  p_pending_qty     => rec.quantity)
            THEN
              l_message := 'Error: Order has already been completely invoiced';
              RAISE e_error;  
            END IF;

            -- This indicates that the row should not be invoiced because it has not
            -- yet been received, which is why p_invoice_eligible_flag = 'N'
            IF NVL(rec.received_transaction_id,'-9') = '-9' THEN
                update_interface_line(
                  p_rowid                       => rec.row_id,
                  p_interface_line_attribute11  => NULL,
                  p_order_number                => NULL,
                  p_quantity                    => TO_NUMBER(NULL),
                  p_amount                      => TO_NUMBER(NULL),
                  p_invoice_eligible_flag       => 'N',
                  x_return_status               => l_return_status,
                  x_return_message              => l_message
                );

                IF l_return_status <> 'S' THEN 
                  RAISE e_error;
                END IF;            
            END IF;

            -- Checks for a 'PENDING' ra_interface_line, which would only exist if created in the same Autoinvoice run
            -- for the same material_transaction_id.  This would be the case if we had two receiving transaction_ids
            -- for the same material_transaction_id in the same Autoinvoice run.
            check_for_pending(
              p_material_transaction_id   => rec.material_transaction_id,
              p_order_line_id             => rec.order_line_id,
              x_pending_exists_flag       => l_pending_exists_flag,
              x_quantity                  => l_pending_quantity,
              x_rowid                     => l_pending_rowid,
              x_return_status             => l_return_status,
              x_return_message            => l_message
            );

            IF l_return_status <> 'S' THEN 
              RAISE e_error;
            END IF;             

            write_log('l_pending_exists_flag: '||l_pending_exists_flag);
            
            -- If a pending row exists, we need to transact against the 'PENDING' row rather than the
            -- 'rec' row from the CURSOR.  
            IF l_pending_exists_flag = 'Y' THEN 
              l_rowid               := l_pending_rowid;
              l_quantity            := l_pending_quantity;
              -- Subtract the received quantity from the 'PENDING' row, as this quantity will
              -- be used to create a new 'PENDING' row to wait for additional receiving, if 
              -- l_remaining_quantity <> 0.
              l_remaining_quantity  := l_pending_quantity - rec.received_quantity;
              l_remaining_amount    := l_remaining_quantity * rec.unit_selling_price;                
            ELSE
              -- Amounts for PENDING line which is waiting for receipt of the rest of the shipment
              l_rowid               := rec.row_id;
              l_quantity            := rec.quantity;
              l_remaining_quantity  := rec.quantity - rec.received_quantity;
              l_remaining_amount    := l_remaining_quantity * rec.unit_selling_price;
            END IF;

            -- Amount for line to be invoiced
            l_invoice_amount      := rec.received_quantity * rec.unit_selling_price;

            write_log('l_row_id:            '||l_rowid);
            write_log('l_quantity:          '||l_quantity);
            write_log('l_remaining_quantity:'||l_remaining_quantity);
            write_log('l_remaining_amount:  '||l_remaining_amount);
            write_log('l_invoice_amount:    '||l_invoice_amount);

            -- if received = quantity then line should be interfaced
            IF l_quantity = rec.received_quantity THEN
                update_interface_line(
                  p_rowid                       => l_rowid,
                  p_interface_line_attribute11  => TO_CHAR(rec.received_transaction_id),
                  p_order_number                => NULL,
                  p_quantity                    => TO_NUMBER(NULL),
                  p_amount                      => TO_NUMBER(NULL),
                  p_invoice_eligible_flag       => 'Y',
                  x_return_status               => l_return_status,
                  x_return_message              => l_message
                );

                IF l_return_status <> 'S' THEN 
                  RAISE e_error;
                END IF;
            END IF;

            -- if received < quantity on ra_interface_line, this is a partial receipt.  This results in
            -- the following scenarios...
            IF l_quantity > rec.received_quantity THEN
              -- 1) If the current row from the cursor is 'PENDING' or a 'PENDING' record exists for this
              --    row, the following will happen...
              --    a) If l_remaining_quantity <> 0 then we need to do the following...
              --      i)  The current row will be updated to have interface_attribute11='PENDING' and will 
              --          have the quantity updated to the remaining quantity on it.  This row will wait for more
              --          to be received.
              --      ii) The current row will be copied to a new row which will have a receiving transaction_id
              --          populated in interface_attribute11 and the quantity set to the amount received.  This 
              --          row WILL get invoiced.
              --    b) If l_remaining_quantity = 0 then we need to do the following...
              --      i)  The current row will be updated to have the receiving transaction_id populated in 
              --          interface_attribute11 and the quantity set to the amount received.  No 'PENDING' row
              --          needs to be created because the order line is now completely received.  This row WILL 
              --          get invoiced.       
              -- See ELSE for contiuation of IF statement explanation...  
              IF rec.master_rec_status = 'PENDING' OR l_pending_exists_flag = 'Y' THEN
                IF l_remaining_quantity <> 0 THEN 
                  -- If pending line already exists FROM PREVIOUS INVOICE RUN, update the quantity on it
                  update_interface_line(
                    p_rowid                       => l_rowid,
                    p_interface_line_attribute11  => 'PENDING',
                    p_order_number                => NULL,
                    p_quantity                    => l_remaining_quantity,
                    p_amount                      => l_remaining_amount,
                    p_invoice_eligible_flag       => 'N',
                    x_return_status               => l_return_status,
                    x_return_message              => l_message
                  );
                  
                  l_create_invoice_line_flag  := 'Y';
                ELSE
                  update_interface_line(
                    p_rowid                       => l_rowid,
                    p_interface_line_attribute11  => TO_CHAR(rec.received_transaction_id),
                    p_order_number                => NULL,
                    p_quantity                    => TO_NUMBER(NULL),
                    p_amount                      => TO_NUMBER(NULL),
                    p_invoice_eligible_flag       => 'Y',
                    x_return_status               => l_return_status,
                    x_return_message              => l_message
                  );
                  
                  l_create_invoice_line_flag  := 'N';
                END IF; -- l_remaining_quantity <> 0
                
                IF l_return_status <> 'S' THEN 
                  RAISE e_error;
                END IF;
                
              -- 2) If the current row from the cursor is NOT 'PENDING' or a 'PENDING' record does not exist for 
              --    this row, the following will happen...
              --    a)  The current row will be updated to have interface_attribute11='MASTER'.  This row is used
              --        for audit purposes when we need to split rows because of multiple receipts.  This row will
              --        never be invoiced.
              --    b)  The current row will be copied to a new row and will have interface_attribute11='PENDING' and will 
              --        have the quantity updated to the remaining quantity to be received.  This row will wait for more
              --        to be received before invoicing.
              --    c)  The current row will be copied to a new row which will have a receiving transaction_id
              --        populated in interface_attribute11 and the quantity set to the amount received.  This 
              --        row WILL get invoiced.             
              ELSE
                -- If pending line does not exist, tag the current line as the MASTER
                -- and create a pending line with the l_remaining_quantity

                  -- Set current row to 'MASTER' for audit purposes
                  update_interface_line(
                    p_rowid                       => l_rowid,
                    p_interface_line_attribute11  => 'MASTER',
                    p_order_number                => NULL,
                    p_quantity                    => TO_NUMBER(NULL),
                    p_amount                      => TO_NUMBER(NULL),
                    p_invoice_eligible_flag       => 'N',
                    x_return_status               => l_return_status,
                    x_return_message              => l_message
                  );

                  IF l_return_status <> 'S' THEN 
                    RAISE e_error;
                  END IF;

                  -- Creating 'PENDING' row for remaining quantity to be received
                  copy_interface_line(
                    p_rowid                       => l_rowid,                                        
                    p_interface_line_attribute11  => 'PENDING',                                              
                    -- Set to the remainder to be received                                                   
                    p_quantity                    => l_remaining_quantity,                                   
                    p_amount                      => l_remaining_amount,                                     
                    p_invoice_eligible_flag       => 'N',                                                    
                    x_return_status               => l_return_status,                                        
                    x_return_message              => l_message
                  );         

                  IF l_return_status <> 'S' THEN 
                    RAISE e_error;
                  END IF;
                  
                  l_create_invoice_line_flag  := 'Y';
              END IF; -- END IF rec.master_rec_status = 'PENDING' OR l_pending_exists_flag = 'Y'

              write_log('l_create_invoice_line_flag: '||l_create_invoice_line_flag);
              
              IF l_create_invoice_line_flag = 'Y' THEN
                -- Create line with received_quantity for invoicing
                copy_interface_line(
                  p_rowid                       => l_rowid,
                  p_interface_line_attribute11  => TO_CHAR(rec.received_transaction_id),
                  p_quantity                    => rec.received_quantity,
                  p_amount                      => l_invoice_amount,
                  p_invoice_eligible_flag       => 'Y',
                  x_return_status               => l_return_status,
                  x_return_message              => l_message
                );         

                IF l_return_status <> 'S' THEN 
                  RAISE e_error;
                END IF;
              END IF;
            END IF; --END l_quantity > rec.received_quantity

            IF rec.received_quantity > rec.quantity THEN 
              l_message := 'Error: Received quantity is greater than quantity available to invoice.';
              RAISE e_error;
            END IF;
          EXCEPTION
            WHEN e_error THEN
              -- error reporting
              l_return_status := 'E';
              ROLLBACK;
            WHEN OTHERS THEN 
              l_return_status := 'E';
              l_message  := 'Unexpected Error in PROCESS_INTERCOMPANY_INVOICES: '||DBMS_UTILITY.FORMAT_ERROR_STACK;
          END;

          IF l_return_status = 'E' THEN
            write_log('Error has occurred');
            l_error_count := l_error_count + 1;

            write_output(
              p_order_number                => rec.order_number,
              p_line_number                 => rec.order_line_number,
              p_req_number                  => rec.requisition_number,
              p_req_line_number             => rec.requisition_line,
              p_receiving_transaction_id    => rec.received_transaction_id,
              p_from_org                    => rec.from_org,
              p_to_org                      => rec.to_org,
              p_quantity                    => rec.quantity,
              p_quantity_received           => rec.received_quantity,
              p_msg                         => l_message
            );
            
            ROLLBACK;
          ELSE 
            write_log('Success!');
            l_success_count := l_success_count + 1;

            write_output(
              p_order_number                => rec.order_number,
              p_line_number                 => rec.order_line_number,
              p_req_number                  => rec.requisition_number,
              p_req_line_number             => rec.requisition_line,
              p_receiving_transaction_id    => rec.received_transaction_id,
              p_from_org                    => rec.from_org,
              p_to_org                      => rec.to_org,
              p_quantity                    => rec.quantity,
              p_quantity_received           => rec.received_quantity,
              p_msg                         => l_message
            );
            COMMIT;
          END IF;
        END LOOP; -- End c_get_intercompany LOOP
      EXCEPTION
        WHEN e_error THEN
          -- error reporting
          l_return_status := 'E';
        WHEN OTHERS THEN 
          l_return_status := 'E';
          l_message  := 'Unexpected Error in outer LOOP of PROCESS_INTERCOMPANY_INVOICES: '||DBMS_UTILITY.FORMAT_ERROR_STACK;       
      END;
      
      IF l_return_status = 'E' THEN
        write_log('Error has occurred');
        l_error_count := l_error_count + 1;

        write_output(
          p_order_number                => TO_CHAR(p_order_numbers_tbl(i)),
          p_line_number                 => NULL,
          p_req_number                  => NULL,
          p_req_line_number             => NULL,
          p_receiving_transaction_id    => TO_NUMBER(NULL),
          p_from_org                    => NULL,
          p_to_org                      => NULL,
          p_quantity                    => TO_NUMBER(NULL),
          p_quantity_received           => TO_NUMBER(NULL),
          p_msg                         => l_message
        );
        
        ROLLBACK;
      END IF;
    END LOOP; -- END p_order_numbers_tbl.COUNT LOOP
    
    fnd_file.put_line(fnd_file.output,' ');
    fnd_file.put_line(fnd_file.output,'Intercompany Totals');
    fnd_file.put_line(fnd_file.output,'********************');
    fnd_file.put_line(fnd_file.output,'Success Records: '||l_success_count);
    fnd_file.put_line(fnd_file.output,'Error Records  : '||l_error_count);
    fnd_file.put_line(fnd_file.output,' ');
  
    IF l_error_count > 0 THEN
      x_return_status := 'E';
    ELSE 
      x_return_status := 'S';
    END IF;
  
    write_log('END PROCESS_INTERCOMPANY_INVOICES');
  EXCEPTION
    WHEN OTHERS THEN
      x_return_status   := 'E';
      x_return_message  := 'Unexpected Error in PROCESS_INTERCOMPANY_INVOICES: '||DBMS_UTILITY.FORMAT_ERROR_STACK;
      fnd_file.put_line(fnd_file.output,x_return_message);      
  END process_intercompany_invoices;
  
END xxar_intercompany_pkg;
/

SHOW ERRORS
