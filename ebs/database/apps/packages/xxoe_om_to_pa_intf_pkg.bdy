CREATE OR REPLACE PACKAGE BODY xxoe_om_to_pa_intf_pkg AS

-- ---------------------------------------------------------------------------------------------
-- Name: XXCN_OM_TO_PA_INTF_PKG    
-- Created By: MMAZANET
-- Revision:   1.0
-- --------------------------------------------------------------------------------------------
-- Purpose: This package is used for interfaced material transactions tied to order lines to 
--          pa_transaction_interface_all as well as marking the transactions as they are processed
--          on attribute15 of mtl_material_transactions.
-- ----------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  09/11/2014  MMAZANET    Initial Creation for CHG0032538.
-- ---------------------------------------------------------------------------------------------

g_program      VARCHAR2(30) := 'XXOE_OM_TO_PA_PKG.';
g_trx_source   pa_transaction_interface_all.transaction_source%TYPE  := 'XXPA_OM_TO_PA_INTERFACE';                                                                    
g_log          VARCHAR2(10) := fnd_profile.value('AFLOG_ENABLED');

-- Type used for reporting output to concurrent program
TYPE g_report_type IS RECORD(
  order_number            NUMBER,                  
  line_number             NUMBER,
  transaction_id          NUMBER,
  project_number          VARCHAR2(100),
  task_number             VARCHAR2(100)
);

-- CURSOR to get lines eligible for processing to pa expenditures table
CURSOR c_trx_lines(
  p_org_id       NUMBER,       
  p_order_number NUMBER,
  p_min_trx_date VARCHAR2
)
IS
  SELECT
    ooh.order_number                 order_number,       
    ool.line_number                  line_number,
    ooh.attribute11                  project_id,
    ppa.segment1                     project_number,
    mmt.transaction_quantity         transaction_quantity,
    mmt.transaction_id               transaction_id,
    mmt.transaction_date             transaction_date,
    mta.reference_account            code_combination_id,
    mmt.organization_id              transaction_org_id,
    haou.name                        transaction_org_name,
    mmt.attribute15                  processed_flag,
    SUM(NVL(xdl.unrounded_accounted_dr,0))                       
                                      transaction_amount
   FROM
   -- get order info
     oe_order_headers_all             ooh,          
     oe_order_lines_all               ool,
     pa_projects_all                  ppa,
     oe_transaction_types_tl          ottt_line,
     fnd_lookup_values                flv_om_line,  -- only certain line types come over
   -- get mtl trx info
     mtl_material_transactions        mmt,
   -- get org name
     hr_all_organization_units        haou,
   -- get mtl trx COGS account
     mtl_transaction_accounts         mta,
     xla_distribution_links           xdl,  
     xla_ae_lines                     xal,
     xla_ae_headers                   xah, 
     org_organization_definitions     ood,
     gl_ledgers                       gll   
   -- get order info
   WHERE ooh.header_id                    = ool.header_id
   AND   ooh.org_id                       = p_org_id
   AND   ooh.attribute11                  = TO_CHAR(ppa.project_id)
   AND   ool.line_type_id                 = ottt_line.transaction_type_id
   AND   ottt_line.language               = userenv('LANG')
   AND   ottt_line.name                   = flv_om_line.meaning
   AND   flv_om_line.lookup_type          = 'XXPA_OM_TO_PA_LINE_TYPES'
   AND   flv_om_line.language             = userenv('LANG')
   -- get mtl trx info
   AND   ool.line_id                      = mmt.trx_source_line_id
   -- get org info
   AND   mmt.organization_id              = haou.organization_id
   -- get mtl trx COGS account
   AND   mmt.transaction_id               = mta.transaction_id              
   AND   mmt.organization_id              = mta.organization_id 
   AND   mta.inv_sub_ledger_id            = xdl.source_distribution_id_num_1   
   AND   xdl.source_distribution_type     = 'MTL_TRANSACTION_ACCOUNTS'     
   AND   xdl.ae_header_id                 = xal.ae_header_id
   AND   xdl.ae_line_num                  = xal.ae_line_num     
   AND   xdl.application_id               = xal.application_id 
   AND   xal.ae_header_id                 = xah.ae_header_id     
   AND   xal.application_id               = xah.application_id
   AND   xah.event_type_code              = 'COGS_RECOGNITION'    
   AND   mmt.organization_id              = ood.organization_id
   AND   ood.set_of_books_id              = gll.ledger_id
   AND   gll.ledger_id                    = xal.ledger_id
   AND   xah.gl_transfer_status_code      = 'Y'
   AND   xah.application_id               = 707     
   AND   xal.application_id               = 707  
   AND   xal.accounting_class_code        = 'COST_OF_GOODS_SOLD' 
   AND   ooh.order_number                 = NVL(p_order_number,ooh.order_number)
   -- This is to assist with performance if program starts to slow down.
   AND   mmt.transaction_date             >= NVL(fnd_date.canonical_to_date(p_min_trx_date),'01-JAN-1900')
   -- Everything before this date has been interfaced manually already
   AND   mmt.transaction_date             >= '01-APR-2015'
   -- Check that record has not yet been processed
   AND NVL(mmt.attribute15,'X')           NOT IN ('P','I')
   GROUP BY 
     ooh.order_number,   
     ool.line_number,
     ooh.attribute11,
     ppa.segment1,                       
     mmt.transaction_quantity,   
     mmt.transaction_id,   
     mmt.transaction_date,   
     mta.reference_account,   
     mmt.organization_id,
     haou.name,
     mmt.attribute15;

-- ---------------------------------------------------------------------------------------------
-- Name: XXOE_OM_TO_PA_INTF_PKG
-- Created By: MMAZANET
-- Revision:   1.0
-- --------------------------------------------------------------------------------------------
-- Purpose: This package is used for interfaced material transactions tied to order lines to 
--          pa_transaction_interface_all as well as marking the transactions as they are processed
--          on attribute15 of mtl_material_transactions.
-- ----------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  09/12/2014  MMAZANET    Initial Creation for CHG0032538.
-- ---------------------------------------------------------------------------------------------

-- --------------------------------------------------------------------------------------------
-- Purpose: Write to request log if 'FND: Debug Log Enabled' is set to Yes
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  10/22/2014  MMAZANET    Initial Creation for CHG0032538.
-- ---------------------------------------------------------------------------------------------
  PROCEDURE dbg(p_msg  VARCHAR2)
  IS 
  BEGIN
    IF g_log = 'Y' THEN
       fnd_file.put_line(fnd_file.log,p_msg); 
    END IF;
  END dbg; 

-- ---------------------------------------------------------------------------------------------
-- Purpose: Write report header
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  09/24/2014  MMAZANET    Initial Creation for CHG0032538.
-- ---------------------------------------------------------------------------------------------
  PROCEDURE write_report_header
  IS
  BEGIN

    -- Write report header
    fnd_file.put_line(fnd_file.output,' ');
    fnd_file.put_line(fnd_file.output,'Order Number  Line Number  Transaction ID  Project Number  Task Number  Message');
    fnd_file.put_line(fnd_file.output,'------------  -----------  --------------  --------------  -----------  '||RPAD('-',50,'-'));

  END write_report_header;

-- ---------------------------------------------------------------------------------------------
-- Purpose: Write report details
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  09/24/2014  MMAZANET    Initial Creation for CHG0032538.
-- ---------------------------------------------------------------------------------------------
  PROCEDURE write_report_row(
    p_report_type  g_report_type,
    p_msg          VARCHAR2,
    p_display      VARCHAR2 DEFAULT'Y'
  )
  IS 
  BEGIN
    IF p_display = 'Y' THEN
      fnd_file.put_line(fnd_file.output,LPAD(NVL(TO_CHAR(p_report_type.order_number),'-'),12,' ')||'  '
                                        ||LPAD(NVL(TO_CHAR(p_report_type.line_number),'-'),11,' ')||'  '
                                        ||LPAD(NVL(TO_CHAR(p_report_type.transaction_id),'-'),14,' ')||'  '
                                        ||LPAD(NVL(p_report_type.project_number,'-'),14,' ')||'  '
                                        ||LPAD(NVL(p_report_type.task_number,'-'),11,' ')||'  '
                                        ||p_msg);
    END IF;
  END write_report_row;

-- ---------------------------------------------------------------------------------------------
-- Purpose: This updates mtl_material_transactions attribute15 to indicate transaction status of
--          being interfaced through to pa_expenditure_items_all.  Statuses are as follows
--             
--             I = Interface  :  Record is in pa_transaction_interface_all but has not yet made it
--                               pa_expenditure_items_all
--             E = Error      :  Record is in error 
--             C = Complete   :  Record is interfaced all the way to pa_expenditure_items_all
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  09/24/2014  MMAZANET    Initial Creation for CHG0032538.
-- ---------------------------------------------------------------------------------------------
  PROCEDURE update_mtl_trx_intf_flag(     
    p_transaction_id  IN    NUMBER,
    p_updt_status     IN    VARCHAR,
    x_return_status   OUT   VARCHAR2,
    x_return_msg      OUT   VARCHAR2
  )
  IS
    CURSOR c_mmt
    IS
       SELECT  attribute15
       FROM mtl_material_transactions
       WHERE transaction_id = p_transaction_id
       FOR UPDATE OF attribute15 NOWAIT;
  
    e_lock   EXCEPTION;
    PRAGMA EXCEPTION_INIT (e_lock, -54);          
  BEGIN
    dbg('Begin '||g_program||'UPDATE_MTL_TRX_INTF_FLAG');
    
    FOR rec IN c_mmt LOOP
      UPDATE mtl_material_transactions
      SET attribute15 = p_updt_status
      WHERE CURRENT OF c_mmt;
    END LOOP;
    
    x_return_status := 'S';
  EXCEPTION
    WHEN e_lock THEN
      x_return_msg      := 'Error: Record locked';
      x_return_status   := 'E';
    WHEN OTHERS THEN
      x_return_msg      := 'Unexpected Error in update_mtl_trx_intf_flag '||DBMS_UTILITY.FORMAT_ERROR_STACK;
      x_return_status   := 'E';
  END update_mtl_trx_intf_flag;

-- ---------------------------------------------------------------------------------------------
-- Purpose: This determines what stage the record is at being interfaced to pa_expenditure_items_all
--          and calls update_mtl_trx_intf_flag to indicate if the record is in error, interfaced
--          to pa_transaction_interface_all, or if it has made it to pa_expenditure_items_all. 
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  09/24/2014  MMAZANET    Initial Creation for CHG0032538.
-- ---------------------------------------------------------------------------------------------
  PROCEDURE process_mtl_trx(
    p_org_id             IN    NUMBER,                       
    p_order_number       IN    NUMBER,
    p_min_trx_date       IN    VARCHAR2 DEFAULT NULL,
    p_report_detail      IN    VARCHAR2 DEFAULT 'N',
    x_return_status      OUT   VARCHAR2,
    x_return_msg         OUT   VARCHAR2
  )
  IS
    l_intf_to_pa_flag             VARCHAR2(1) := 'N';
    l_intf_pa_flag                VARCHAR2(1) := 'N';
    l_error_flag                  VARCHAR2(1) := 'N';
    
    l_records_updated NUMBER      := 0;
    l_records_errored NUMBER      := 0;
    l_records_no_data NUMBER      := 0;
    
    l_report_type     g_report_type;
  BEGIN
    dbg('Begin '||g_program||'PROCESS_MTL_TRX');

    fnd_file.put_line(fnd_file.output,RPAD('*',122,'*'));
    fnd_file.put_line(fnd_file.output,'Updating MTL_MATERIAL_TRANSACTIONS');
    fnd_file.put_line(fnd_file.output,RPAD('*',122,'*'));
    fnd_file.put_line(fnd_file.output,' ');
    write_report_header;

    -- Check for transactions that have been interfaced to pa_expenditure_items_all but 
    -- have not yet been flagged.
    FOR rec IN  c_trx_lines(
                  p_org_id
               ,  p_order_number
               ,  p_min_trx_date) LOOP
      l_report_type.transaction_id  := rec.transaction_id;
      
      -- check if transaction has made it to pa_expenditure_items_all
      BEGIN   
        SELECT 'Y' 
        INTO l_intf_to_pa_flag
        FROM pa_expenditure_items_all
        WHERE transaction_source         = g_trx_source
        AND   orig_transaction_reference = rec.transaction_id;
      EXCEPTION 
        -- More than one row may exist for transaction_id
        WHEN TOO_MANY_ROWS THEN
          l_intf_to_pa_flag := 'Y';
        WHEN OTHERS THEN
          l_intf_to_pa_flag := 'N';
          dbg('Exception while searching pa_expenditure_items_all ' ||DBMS_UTILITY.FORMAT_ERROR_STACK);
      END;

      -- check if transaction is in interface table
      IF l_intf_to_pa_flag = 'N' THEN
        BEGIN
          SELECT 'Y' 
          INTO l_intf_pa_flag
          FROM pa_transaction_interface_all
          WHERE transaction_source         = g_trx_source
          AND   orig_transaction_reference = rec.transaction_id; 
        EXCEPTION 
          -- More than one row may exist for transaction_id
          WHEN TOO_MANY_ROWS THEN
            l_intf_pa_flag := 'Y';
          WHEN OTHERS THEN
            l_intf_pa_flag := 'N';   
            dbg('Exception while searching pa_transaction_interface_all ' ||DBMS_UTILITY.FORMAT_ERROR_STACK);
        END;
      END IF;
      
      dbg('l_intf_to_pa_flag: '||l_intf_to_pa_flag);
      dbg('l_intf_pa_flag: '||l_intf_pa_flag);
      dbg('rec.processed_flag: '||rec.processed_flag);
      
      -- If transaction has interfaced to pa_expenditure_items_all, then mark the record as processed on mtl_material_transactions
      IF l_intf_to_pa_flag = 'Y' THEN
        update_mtl_trx_intf_flag(
          p_transaction_id  => rec.transaction_id,
          p_updt_status     => 'P',
          x_return_status   => x_return_status,
          x_return_msg      => x_return_msg
        );
        
        IF x_return_status <> 'S' THEN
          l_records_errored := l_records_errored + 1; 
          l_error_flag      := 'Y';
          write_report_row(l_report_type,x_return_msg);
        ELSE
          l_records_updated := l_records_updated + 1;
          
          write_report_row(       
            l_report_type,
            'SUCCESS',
            p_report_detail);              
        END IF;            
      END IF;  

      -- Check for condition where record is interfaced (I) in mtl_material_transactions, but can not be located
      -- in interface table.  This could happen if the record has been purged from interface table before processed
      -- by PRC program.
      IF l_intf_pa_flag = 'N' 
        AND rec.processed_flag = 'I'
        AND l_intf_to_pa_flag <> 'Y'
      THEN
        update_mtl_trx_intf_flag(                     
          p_transaction_id  => rec.transaction_id,
          p_updt_status     => 'E',
          x_return_status   => x_return_status,
          x_return_msg      => x_return_msg
        );
        
        IF x_return_status <> 'S' THEN
          l_error_flag      := 'Y';
          write_report_row(l_report_type,x_return_msg);            
        ELSE
          -- Technically this is an error, but l_error_flag is not set to Y because the record will get reprocessed when
          -- ins_pa_transaction_intf runs.
          write_report_row(l_report_type,'Error: Interface Record Could not be located.  Program will re-process on next run.');      
        END IF;
        
        l_records_errored := l_records_errored + 1;
      END IF;

    END LOOP;

    fnd_file.put_line(fnd_file.output,' ');
    fnd_file.put_line(fnd_file.output,'Record Totals');
    fnd_file.put_line(fnd_file.output,RPAD('*',75,'*'));
    fnd_file.put_line(fnd_file.output,'Total Updated Records             :'||l_records_updated);
    fnd_file.put_line(fnd_file.output,'Total Error Records               :'||l_records_errored);

    IF l_error_flag = 'Y' THEN
      x_return_status := 'E'; 
    ELSE
      x_return_status := 'S';
    END IF;     
   
  EXCEPTION
    WHEN OTHERS THEN
      x_return_msg      := 'Unexpected Error in process_mtl_trx '||DBMS_UTILITY.FORMAT_ERROR_STACK;
      x_return_status   := 'E';
  END process_mtl_trx;

-- ---------------------------------------------------------------------------------------------
-- Purpose: This will gather transactions based on OM information that have not yet been 
--          interfaced to pa_expenditure_items_all.
-- ---------------------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  09/24/2014  MMAZANET    Initial Creation for CHG0032538.
-- ---------------------------------------------------------------------------------------------
  PROCEDURE ins_pa_transaction_intf(            
    x_errbuff               OUT   VARCHAR2,
    x_retcode               OUT   NUMBER,
    p_org_id                IN    NUMBER,
    p_order_number          IN    NUMBER,
    p_task_number           IN    VARCHAR2,
    p_expenditure_type      IN    VARCHAR2,                                   
    p_min_trx_date          IN    VARCHAR2,
    p_update_mat_trx        IN    VARCHAR2,
    p_update_mat_trx_only   IN    VARCHAR2,
    p_report_detail         IN    VARCHAR2
  )
  IS
       
    l_batch_name               pa_transaction_interface_all.batch_name%TYPE                   := 'OM_'||TO_CHAR(SYSDATE,'YYYYMMDDHH24MISS');
    l_expenditure_ending_date  pa_transaction_interface_all.expenditure_ending_date%TYPE;
    l_raw_cost                 pa_transaction_interface_all.raw_cost%TYPE                     := 1;
    l_transaction_status_code  pa_transaction_interface_all.transaction_status_code%TYPE      := 'P';
    l_attribute_category       pa_transaction_interface_all.attribute_category%TYPE           := 'PJ'; 
    l_system_linkage           pa_transaction_interface_all.system_linkage%TYPE               := 'PJ'; 
    --l_txn_interface_id         pa_transaction_interface_all.txn_interface_id%TYPE;
    l_created_by               pa_transaction_interface_all.created_by%TYPE                   := TO_NUMBER(fnd_profile.value('USER_ID'));  
    
    l_return_status            VARCHAR2(1) := 'S';
    l_return_msg               VARCHAR2(500);
    
    l_records_loaded           NUMBER := 0;
    l_records_errored          NUMBER := 0;

    l_report_type              g_report_type;
    
    e_error                    EXCEPTION;
  BEGIN
    dbg('Begin '||g_program||'INS_PA_TRANSACTION_INTF');      
    
    dbg('Min Trx date         : '||p_min_trx_date);
    dbg('p_task_number        : '||p_task_number);
    dbg('p_expenditure_type   : '||p_expenditure_type);
    dbg('p_update_mat_trx     : '||p_update_mat_trx);
    dbg('p_update_mat_trx_only: '||p_update_mat_trx_only);
    
    
    IF p_update_mat_trx = 'Y' OR p_update_mat_trx_only = 'Y' THEN 
      process_mtl_trx(                            
        p_org_id          => p_org_id,
        p_order_number    => p_order_number,
        p_min_trx_date    => p_min_trx_date,
        p_report_detail   => p_report_detail,
        x_return_status   => l_return_status,
        x_return_msg      => l_return_msg);  
    END IF;
    
    IF l_return_status = 'E' OR p_update_mat_trx_only = 'Y' THEN
       RAISE e_error;
    END IF;
    
    l_expenditure_ending_date := NEXT_DAY(SYSDATE,'SUN');
    
    fnd_file.put_line(fnd_file.output,' ');
    fnd_file.put_line(fnd_file.output,RPAD('*',122,'*'));
    fnd_file.put_line(fnd_file.output,'INSERTING INTO INTERFACE TABLE FOR BATCH NAME: '||l_batch_name);
    fnd_file.put_line(fnd_file.output,RPAD('*',122,'*'));
    
    IF p_report_detail = 'Y' THEN
      fnd_file.put_line(fnd_file.output,' ');
      fnd_file.put_line(fnd_file.output,'Program Constants');
      fnd_file.put_line(fnd_file.output,RPAD('*',75,'*'));
      fnd_file.put_line(fnd_file.output,'Transaction Source          : '||g_trx_source);
      fnd_file.put_line(fnd_file.output,'Batch Name                  : '||l_batch_name);
      fnd_file.put_line(fnd_file.output,'Expenditure Ending Date     : '||l_expenditure_ending_date);
      fnd_file.put_line(fnd_file.output,'Transaction Status Code     : '||l_transaction_status_code);
      fnd_file.put_line(fnd_file.output,'Attribute Category          : '||l_attribute_category);
    END IF;
    
    fnd_file.put_line(fnd_file.output,' ');
    write_report_header;
    
    FOR rec IN  c_trx_lines(
                  p_org_id,
                  p_order_number,
                  p_min_trx_date) 
    LOOP
      BEGIN
        dbg('*** Begin processing for transaction_id '||rec.transaction_id||' ***');

        IF rec.processed_flag = 'I' THEN
           l_return_msg := 'Record has already been interfaced.';
           RAISE e_error;
        END IF;

        l_report_type.order_number             := rec.order_number;
        l_report_type.line_number              := rec.line_number;
        l_report_type.transaction_id           := rec.transaction_id;
        l_report_type.project_number           := rec.project_number;
        --l_report_type.task_number              := rec.task_number;
        
        dbg('transaction_date      : '||rec.transaction_date);
        dbg('transaction_quantity  : '||rec.transaction_quantity);
        dbg('transaction_org_id    : '||rec.transaction_org_id);

        IF rec.project_number IS NULL THEN
          l_return_msg := 'Error: No project number could be located on order '||rec.order_number||' line number '||rec.line_number;
          RAISE e_error;
        END IF;
        
        /*
        IF rec.task_number IS NULL THEN
          l_return_msg := 'Error: No task number could be located on order '||rec.order_number||' line number '||rec.line_number;
          RAISE e_error;
        END IF;            
        */

        -- Validations will take place when rows are inserted into this table, or when the PRC program
        -- that pulls from this table is run, so validation is not necessary pre-insert into the table below.
        INSERT INTO pa_transaction_interface_all(     
          transaction_source,
          batch_name,
          expenditure_ending_date,
          expenditure_item_date,
          project_number,
          task_number,
          expenditure_type,
          quantity,
          denom_raw_cost,
          transaction_status_code,
          orig_transaction_reference,
          attribute_category,
          attribute9,
          org_id,
          system_linkage,
          created_by,
          creation_date,
          organization_name
        )
        VALUES(
          g_trx_source,
          l_batch_name,
          l_expenditure_ending_date,
          rec.transaction_date,
          rec.project_number,
          p_task_number,
          p_expenditure_type,
          rec.transaction_amount,
          rec.transaction_amount,
          l_transaction_status_code,
          rec.transaction_id,
          l_attribute_category,
          rec.code_combination_id,
          p_org_id,
          l_system_linkage,
          l_created_by,
          SYSDATE,
          rec.transaction_org_name
        );
        
        write_report_row(
          l_report_type,
          'Record Successfully loaded',
          p_report_detail);
        
        update_mtl_trx_intf_flag(                   
          p_transaction_id  => rec.transaction_id,          
          p_updt_status     => 'I',
          x_return_status   => l_return_status,
          x_return_msg      => l_return_msg
        );
        
        IF l_return_status <> 'S' THEN
          RAISE e_error;
        END IF;
        
        l_records_loaded  := l_records_loaded + 1;
        
        -- Explicit commit necessary to commit successful records.  In the event of an error, a ROLLBACK will occur
        -- for that paticular record.
        COMMIT;
      EXCEPTION
        WHEN e_error THEN
          l_records_errored := l_records_errored + 1;
          write_report_row(l_report_type,l_return_msg);
          ROLLBACK;
        WHEN OTHERS THEN
          l_records_errored := l_records_errored + 1;
          write_report_row(l_report_type,'Unexpected Error Occurred '||DBMS_UTILITY.FORMAT_ERROR_STACK);
          ROLLBACK;
      END;         
      dbg('*** End processing for transaction_id '||rec.transaction_id||' ***');
    END LOOP;
    
    fnd_file.put_line(fnd_file.output,' ');
    fnd_file.put_line(fnd_file.output,'Record Totals');
    fnd_file.put_line(fnd_file.output,RPAD('*',75,'*'));
    fnd_file.put_line(fnd_file.output,'Total Success Records :'||l_records_loaded);
    fnd_file.put_line(fnd_file.output,'Total Error Records   :'||l_records_errored);
    
    IF l_records_errored > 0 THEN
      x_retcode := 1;  
    END IF;
  EXCEPTION
    WHEN e_error THEN
      IF l_return_status = 'S' AND p_update_mat_trx_only = 'Y' THEN
        -- Not an error condition.  Simply skipping bulk of processing if 
        -- p_update_mat_trx_only = 'Y'
        NULL;
      ELSE 
        fnd_file.put_line(fnd_file.output,l_return_msg);
        x_retcode := 2; 
      END IF;
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.output,'Unexpected Error Occurred '||DBMS_UTILITY.FORMAT_ERROR_STACK);
      x_retcode := 2; 
  END ins_pa_transaction_intf;

  
END xxoe_om_to_pa_intf_pkg;
/

SHOW ERRORS