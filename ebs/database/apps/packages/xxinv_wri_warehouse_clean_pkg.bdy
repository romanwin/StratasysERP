CREATE OR REPLACE PACKAGE BODY xxinv_wri_warehouse_clean_pkg IS

  -----------------------------------------------------------------------
  --  customization code: CUST331 - WRI Warehouse clean up
  --  name:               XXINV_WRI_WAREHOUSE_CLEAN_PKG
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0 $
  --  creation date:      13/06/2010 1:44:58 PM
  --  Purpose :           Package that handle - wri warehouse clean up
  --                      
  -----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   13/06/2010    Dalit A. Raviv  initial build
  --  1.1   18.08.2013    Vitaly          CR 870 std cost - change hard-coded organization (734 /*IRK*/ ---92 /*WRI*/)
  ----------------------------------------------------------------------- 
  -- population to clean
  CURSOR get_pop_c IS
    SELECT moqd.organization_id organization_id,
           moqd.inventory_item_id inventory_item_id,
           msi.segment1 item,
           moqd.revision revision,
           SUM(moqd.primary_transaction_quantity) total_qoh,
           moqd.subinventory_code subinventory_code,
           moqd.locator_id locator_id,
           moqd.lot_number lot_number,
           msi.description item_description,
           mln.expiration_date lot_expiration_date,
           msi.primary_uom_code primary_uom_code,
           msi.lot_control_code lot_control_code
      FROM mtl_onhand_quantities_detail moqd,
           mtl_system_items_b           msi,
           mtl_lot_numbers              mln
     WHERE moqd.inventory_item_id = msi.inventory_item_id
       AND moqd.lot_number = mln.lot_number(+)
       AND moqd.inventory_item_id = mln.inventory_item_id(+)
       AND moqd.organization_id = msi.organization_id
       AND moqd.organization_id = mln.organization_id(+)
       AND moqd.subinventory_code = '9000' -- MUST be hard code to prevent clean of other subinv
       AND moqd.organization_id = 734 /*IRK*/ ---92 /*WRI*/ -- MUST be hrad code to prevent clean of other organization
    --and    msi.inventory_item_id                    = 15892 -- for debug
    --and    rownum < 20                                      -- for debug
     GROUP BY moqd.organization_id,
              moqd.inventory_item_id,
              msi.segment1,
              moqd.revision,
              moqd.subinventory_code,
              moqd.locator_id,
              moqd.lot_number,
              msi.description,
              mln.expiration_date,
              msi.primary_uom_code,
              msi.lot_control_code;
  -- rec to insert to backup tbl
  TYPE g_backup_rec IS RECORD(
    organization_id     NUMBER,
    inventory_item_id   NUMBER,
    item                VARCHAR2(50),
    revision            VARCHAR2(3),
    total_qoh           NUMBER,
    subinventory_code   VARCHAR2(10),
    locator_id          NUMBER,
    lot_number          VARCHAR2(80),
    item_description    VARCHAR2(240),
    lot_expiration_date DATE,
    primary_uom_code    VARCHAR2(3),
    lot_control_code    NUMBER);

  g_user_id NUMBER := fnd_profile.value('USER_ID');

  -----------------------------------------------------------------------
  --  customization code: CUST331 - WRI Warehouse clean up
  --  name:               del_backup_tbl
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0 $
  --  creation date:      14/06/2010
  --  Purpose :           Procedure that handle - clean of back up table
  --                      we decided that we will keep data for 1 month.                    
  -----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   14/06/2010    Dalit A. Raviv  initial build
  ----------------------------------------------------------------------- 
  PROCEDURE del_backup_tbl(p_error_code OUT NUMBER,
                           p_error_desc OUT VARCHAR2) IS
  
  BEGIN
    DELETE FROM xxinv_wri_warehouse_cln_backup xb
     WHERE xb.creation_date < SYSDATE - 30;
  
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      p_error_code := 1;
      p_error_desc := 'Failed to delete XXINV_WRI_WAREHOUSE_CLN_BACKUP tbl ' ||
                      substr(SQLERRM, 1, 200);
  END del_backup_tbl;

  -----------------------------------------------------------------------
  --  customization code: CUST331 - WRI Warehouse clean up
  --  name:               ins_backup_tbl
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0 $
  --  creation date:      14/06/2010
  --  Purpose :           Procedure that handle - the backup of the data
  --                      we are going to clean                   
  -----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   14/06/2010    Dalit A. Raviv  initial build
  ----------------------------------------------------------------------- 
  PROCEDURE ins_backup_tbl(p_backup_rec IN g_backup_rec,
                           p_error_code OUT NUMBER,
                           p_error_desc OUT VARCHAR2) IS
    l_entity NUMBER := NULL;
  BEGIN
    -- like a batch id
    l_entity := to_char(SYSDATE, 'YYYY') || to_char(SYSDATE, 'MM') ||
                to_char(SYSDATE, 'DD');
  
    INSERT INTO xxinv_wri_warehouse_cln_backup
      (entity_id,
       organization_id,
       inventory_item_id,
       segment1,
       revision,
       primary_transaction_quantity,
       subinventory_code,
       locator_id,
       lot_number,
       item_description,
       lot_expiration_date,
       primary_uom_code,
       lot_control_code,
       last_update_date,
       last_updated_by,
       last_update_login,
       creation_date,
       created_by)
    VALUES
      (l_entity,
       p_backup_rec.organization_id,
       p_backup_rec.inventory_item_id,
       p_backup_rec.item,
       p_backup_rec.revision,
       p_backup_rec.total_qoh,
       p_backup_rec.subinventory_code,
       p_backup_rec.locator_id,
       p_backup_rec.lot_number,
       p_backup_rec.item_description,
       p_backup_rec.lot_expiration_date,
       p_backup_rec.primary_uom_code,
       p_backup_rec.lot_control_code,
       SYSDATE,
       g_user_id,
       -1,
       SYSDATE,
       g_user_id);
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      p_error_code := 1;
      p_error_desc := 'Failed - insert row to XXINV_WRI_WAREHOUSE_CLN_BACKUP tbl ' ||
                      substr(SQLERRM, 1, 200);
  END;

  -----------------------------------------------------------------------
  --  customization code: CUST331 - WRI Warehouse clean up
  --  name:               WRI_warehouse_clean_up
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0 $
  --  creation date:      13/06/2010
  --  Purpose :           Procedure that handle - wri warehouse clean up
  --                      
  -----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   13/06/2010    Dalit A. Raviv  initial build
  ----------------------------------------------------------------------- 
  PROCEDURE wri_warehouse_clean_up(errbuf  OUT VARCHAR2,
                                   retcode OUT VARCHAR2) IS
  
    /*cursor get_pop_c is
      select moqd.organization_id                     organization_id,
             moqd.inventory_item_id                   inventory_item_id,
             msi.segment1                             item,
             moqd.revision                            revision,
             sum(moqd.primary_transaction_quantity)   total_qoh,
             moqd.subinventory_code                   subinventory_code,
             moqd.locator_id                          locator_id,
             moqd.lot_number                          lot_number,
             msi.description                          item_description,
             mln.expiration_date                      lot_expiration_date,
             msi.primary_uom_code                     primary_uom_code,
             msi.lot_control_code                     lot_control_code
      from   mtl_onhand_quantities_detail             moqd,
             mtl_system_items_b                       msi,
             mtl_lot_numbers                          mln
      where  moqd.inventory_item_id                   = msi.inventory_item_id
      and    moqd.lot_number                          = mln.lot_number(+)
      and    moqd.inventory_item_id                   = mln.inventory_item_id(+)
      and    moqd.organization_id                     = msi.organization_id
      and    moqd.organization_id                     = mln.organization_id(+)
      and    moqd.subinventory_code                   = '9000'-- MUST be hard code to prevent clean of other subinv
      and    moqd.organization_id                     = 734 ---IRK ---92--WRI    -- MUST be hrad code to prevent clean of other organization
      --and    msi.inventory_item_id                    = 15892 -- for debug
      --and    rownum < 20                                      -- for debug
      group by  moqd.organization_id,
                moqd.inventory_item_id,
                msi.segment1,
                moqd.revision,
                moqd.subinventory_code,
                moqd.locator_id,
                moqd.lot_number,
                msi.description,
                mln.expiration_date,
                msi.primary_uom_code,
                msi.lot_control_code; 
    */
    -- 'Account alias receipt' / 'Account alias issue'
    l_trx_type_id        NUMBER;
    l_trx_action_id      NUMBER;
    l_trx_source_type_id NUMBER;
    l_trx_type_name      VARCHAR2(80);
    l_source_name        VARCHAR2(80);
    --  
    l_stage             VARCHAR2(80);
    l_source_id         NUMBER;
    l_interfaced_txn_id NUMBER;
    --l_user_id              number      := fnd_profile.value('USER_ID');  
    l_flag       VARCHAR2(1) := 'Y';
    l_total_qoh  NUMBER;
    l_error_code NUMBER := 0;
    l_erorr_desc VARCHAR2(1000) := NULL;
    l_backup_rec g_backup_rec;
    user_exception EXCEPTION;
  BEGIN
    ------ 
    -- Handle clean of backup tbl - hold only rows from the last month
    l_stage := 'Delete xxinv_wri_warehouse_cln_backup';
    dbms_output.put_line(l_stage);
    ------  
    del_backup_tbl(l_error_code, l_erorr_desc);
    IF l_error_code > 0 THEN
      dbms_output.put_line('delete xxinv_wri_warehouse_cln_backup - ' ||
                           l_erorr_desc);
      dbms_output.put_line('----------------------------------------------------------------------');
      fnd_file.put_line(fnd_file.log,
                        'delete xxinv_wri_warehouse_cln_backup - ' ||
                        l_erorr_desc);
      fnd_file.put_line(fnd_file.log,
                        '----------------------------------------------------------------------');
    END IF;
  
    ------
    -- Handle backup of all rows the program will clean from warehouse
    -- if failed to backup rows - program will not continue to the "cleaning"
    l_stage := 'Insert backup rows to xxinv_wri_warehouse_cln_backup tbl';
    dbms_output.put_line(l_stage);
    ------ 
    l_error_code := 0;
    l_erorr_desc := NULL;
    FOR get_pop_r IN get_pop_c LOOP
      l_backup_rec := get_pop_r;
      ins_backup_tbl(l_backup_rec, l_error_code, l_erorr_desc);
      IF l_error_code > 0 THEN
        dbms_output.put_line('insert xxinv_wri_warehouse_cln_backup - ' ||
                             l_erorr_desc);
        dbms_output.put_line('----------------------------------------------------------------------');
        fnd_file.put_line(fnd_file.log,
                          'insert xxinv_wri_warehouse_cln_backup - ' ||
                          l_erorr_desc);
        fnd_file.put_line(fnd_file.log,
                          '----------------------------------------------------------------------');
      
        errbuf  := 'User exception ';
        retcode := 2;
        RAISE user_exception;
      END IF;
    END LOOP;
  
    -------------
    --  START  --
    -------------
    ------
    l_stage := 'Source';
    dbms_output.put_line(l_stage);
    ------   
    SELECT mgd.disposition_id
      INTO l_source_id
      FROM mtl_generic_dispositions mgd
     WHERE mgd.organization_id = 734 /*IRK*/ ---92 /*WRI*/
       AND upper(mgd.segment1) = upper('9000 CLEANING');
  
    FOR get_pop_r IN get_pop_c LOOP
      -- Get trx datails
      l_trx_type_id        := NULL;
      l_trx_type_name      := NULL;
      l_trx_action_id      := NULL;
      l_trx_source_type_id := NULL;
      l_source_name        := NULL;
      l_flag               := 'Y';
      IF get_pop_r.total_qoh < 0 THEN
        -- 'Account alias receipt'
        ------
        l_stage := 'Account alias receipt';
        dbms_output.put_line(l_stage);
        ------
        -- Get Transaction Source Code
        SELECT mtt.transaction_type_id,
               mtt.transaction_type_name,
               mtt.transaction_action_id,
               mtt.transaction_source_type_id,
               mtst.transaction_source_type_name
          INTO l_trx_type_id,
               l_trx_type_name,
               l_trx_action_id,
               l_trx_source_type_id,
               l_source_name
          FROM mtl_transaction_types mtt, mtl_txn_source_types mtst
         WHERE mtt.transaction_source_type_id =
               mtst.transaction_source_type_id
           AND mtt.transaction_type_name = 'Account alias receipt';
      
      ELSIF get_pop_r.total_qoh > 0 THEN
        -- 'Account alias issue'
        ------
        l_stage := 'Account alias issue';
        dbms_output.put_line(l_stage);
        ------
        -- Get Transaction Source Code
        SELECT mtt.transaction_type_id,
               mtt.transaction_type_name,
               mtt.transaction_action_id,
               mtt.transaction_source_type_id,
               mtst.transaction_source_type_name
          INTO l_trx_type_id,
               l_trx_type_name,
               l_trx_action_id,
               l_trx_source_type_id,
               l_source_name
          FROM mtl_transaction_types mtt, mtl_txn_source_types mtst
         WHERE mtt.transaction_source_type_id =
               mtst.transaction_source_type_id
           AND mtt.transaction_type_name = 'Account alias issue';
      
      END IF;
      l_total_qoh := get_pop_r.total_qoh * -1;
      ------
      l_stage := 'INSERT mtl_transactions_interface';
      dbms_output.put_line(l_stage);
      ------
      BEGIN
        SELECT inv.mtl_material_transactions_s.nextval
          INTO l_interfaced_txn_id
          FROM dual;
      
        INSERT INTO mtl_transactions_interface
          (inventory_item_id, -- get_pop_r.inventory_item_id               
           transaction_interface_id, -- l_interfaced_txn_id
           source_code, -- l_source_name
           transaction_type_id, -- l_trx_type_id              31
           transaction_action_id, -- l_trx_action_id            1
           transaction_source_type_id, -- l_trx_source_type_id       6
           transaction_source_id, -- l_source_id                342
           transaction_uom, -- get_pop_r.primary_uom_code
           transaction_quantity, -- get_pop_r.total_qoh
           primary_quantity, -- get_pop_r.total_qoh
           transaction_date, -- sysdate
           transaction_reference, -- 9000
           organization_id, -- get_pop_r.organization_id
           revision, -- get_pop_r.revision
           reason_id, -- null
           source_header_id, -- ????????
           flow_schedule, -- Y
           process_flag, -- 1
           transaction_mode, -- 3
           creation_date, -- sysdate
           created_by, -- l_user_id
           last_update_date, -- sysdate
           last_updated_by, -- l_user_id
           last_update_login, -- -1
           subinventory_code, -- '9000'
           scheduled_flag, -- 2
           substitution_item_id, -- 0
           substitution_type_id, -- 0
           locator_id, -- get_pop_r.locator_id
           source_line_id) -- l_interfaced_txn_id
        VALUES
          (get_pop_r.inventory_item_id, -- inventory_item_id
           l_interfaced_txn_id, -- transaction_interface_id            
           l_source_name, -- source_code
           l_trx_type_id, -- transaction_type_id             31 (issue) / 41 (receipt)
           l_trx_action_id, -- transaction_action_id           1  (issue) / 27 (receipt)
           l_trx_source_type_id, -- transaction_source_type_id      6
           l_source_id, -- transaction_source_id           342
           get_pop_r.primary_uom_code, -- transaction_uom 
           l_total_qoh /*get_pop_r.total_qoh*/, -- transaction_quantity
           l_total_qoh /*get_pop_r.total_qoh*/, -- primary_quantity
           SYSDATE, -- transaction_date
           '9000', -- transaction_reference
           get_pop_r.organization_id, -- organization_id
           get_pop_r.revision, -- revision
           NULL, -- reason_id
           l_interfaced_txn_id, -- source_header_id
           'Y', -- flow_schedule
           '1', -- process_flag
           '3', -- transaction_mode
           SYSDATE, -- creation_date
           g_user_id, -- created_by
           SYSDATE, -- last_update_date
           g_user_id, -- last_updated_by
           -1, -- last_update_login
           '9000', -- subinventory_code
           '2', -- scheduled_flag
           '0', -- substitution_item_id
           '0', -- substitution_type_id
           get_pop_r.locator_id, -- locator_id
           l_interfaced_txn_id); -- source_line_id
      
        dbms_output.put_line('Insert mtl_transactions_interface - Item - ' ||
                             get_pop_r.item || ' Qty - ' ||
                             get_pop_r.total_qoh);
        dbms_output.put_line('Source name - ' || l_source_name ||
                             ' Trx type id - ' || l_trx_type_id ||
                             ' Trx action id - ' || l_trx_action_id);
        dbms_output.put_line('----------------------------------------------------------------------');
        fnd_file.put_line(fnd_file.log,
                          'Insert mtl_transactions_interface - Item - ' ||
                          get_pop_r.item || ' Qty - ' ||
                          get_pop_r.total_qoh);
        fnd_file.put_line(fnd_file.log,
                          'Source name - ' || l_source_name ||
                          ' Trx type id - ' || l_trx_type_id ||
                          ' Trx action id - ' || l_trx_action_id);
        fnd_file.put_line(fnd_file.log,
                          '----------------------------------------------------------------------');
      EXCEPTION
        WHEN OTHERS THEN
          l_flag := 'N';
          dbms_output.put_line('ERR GEN - Insert mtl_transactions_interface - Item - ' ||
                               get_pop_r.item);
          dbms_output.put_line('Source name - ' || l_source_name ||
                               ' Trx type id - ' || l_trx_type_id ||
                               ' Trx action id - ' || l_trx_action_id);
          dbms_output.put_line(substr(SQLERRM, 1, 200));
          dbms_output.put_line('----------------------------------------------------------------------');
          fnd_file.put_line(fnd_file.log,
                            'ERR GEN - Insert mtl_transactions_interface - Item - ' ||
                            get_pop_r.item);
          fnd_file.put_line(fnd_file.log,
                            'Source name - ' || l_source_name ||
                            ' Trx type id - ' || l_trx_type_id ||
                            ' Trx action id - ' || l_trx_action_id);
          fnd_file.put_line(fnd_file.log, substr(SQLERRM, 1, 200));
          fnd_file.put_line(fnd_file.log,
                            '----------------------------------------------------------------------');
      END;
      ------
      l_stage := 'INSERT INTO mtl_transaction_lots_interface';
      dbms_output.put_line(l_stage);
      ------
      BEGIN
        IF get_pop_r.lot_number IS NOT NULL AND
           get_pop_r.lot_control_code IS NOT NULL AND l_flag = 'Y' THEN
          INSERT INTO mtl_transaction_lots_interface
            (transaction_interface_id, -- l_interfaced_txn_id
             source_code, -- l_source_name
             source_line_id, -- NULL
             last_update_date, -- sysdate
             last_updated_by, -- l_user_id
             creation_date, -- sysdate
             created_by, -- l_user_id
             last_update_login, -- -1
             lot_number, -- get_pop_r.lot_number
             lot_expiration_date, -- get_pop_r.lot_expiration_date
             transaction_quantity, -- get_pop_r.total_qoh
             primary_quantity, -- get_pop_r.total_qoh
             process_flag) -- 1
          VALUES
            (l_interfaced_txn_id, -- transaction_interface_id
             l_source_name, -- source_code
             NULL, -- source_line_id
             SYSDATE, -- last_update_date
             g_user_id, -- last_updated_by
             SYSDATE, -- creation_date
             g_user_id, -- created_by
             -1, -- last_update_login
             get_pop_r.lot_number, -- lot_number
             get_pop_r.lot_expiration_date, -- lot_expiration_date
             l_total_qoh /*get_pop_r.total_qoh*/, -- transaction_quantity
             l_total_qoh /*get_pop_r.total_qoh*/, -- primary_quantity
             1); -- process_flag
        
        END IF;
        dbms_output.put_line('Insert mtl_transaction_lots_interface - Item - ' ||
                             get_pop_r.item);
        dbms_output.put_line('Qty - ' || get_pop_r.total_qoh || 'Lot - ' ||
                             get_pop_r.lot_number);
        dbms_output.put_line('----------------------------------------------------------------------');
        fnd_file.put_line(fnd_file.log,
                          'Insert mtl_transaction_lots_interface - Item - ' ||
                          get_pop_r.item);
        fnd_file.put_line(fnd_file.log,
                          'Qty - ' || get_pop_r.total_qoh || 'Lot - ' ||
                          get_pop_r.lot_number);
        fnd_file.put_line(fnd_file.log,
                          '----------------------------------------------------------------------');
      EXCEPTION
        WHEN OTHERS THEN
          l_flag := 'N';
          dbms_output.put_line('ERR GEN - Insert mtl_transaction_lots_interface - Item - ' ||
                               get_pop_r.item);
          dbms_output.put_line('Source name - ' || l_source_name ||
                               ' Trx type id - ' || l_trx_type_id ||
                               ' Trx action id - ' || l_trx_action_id);
          dbms_output.put_line('Qty - ' || get_pop_r.total_qoh || 'Lot - ' ||
                               get_pop_r.lot_number);
          dbms_output.put_line(substr(SQLERRM, 1, 200));
          dbms_output.put_line('----------------------------------------------------------------------');
          fnd_file.put_line(fnd_file.log,
                            'ERR GEN - Insert mtl_transaction_lots_interface - Item - ' ||
                            get_pop_r.item);
          fnd_file.put_line(fnd_file.log,
                            'Source name - ' || l_source_name ||
                            ' Trx type id - ' || l_trx_type_id ||
                            ' Trx action id - ' || l_trx_action_id);
          fnd_file.put_line(fnd_file.log, substr(SQLERRM, 1, 200));
          fnd_file.put_line(fnd_file.log,
                            '----------------------------------------------------------------------');
      END;
      IF l_flag = 'N' THEN
        ROLLBACK;
      ELSE
        COMMIT;
      END IF;
    END LOOP;
  
  EXCEPTION
    WHEN user_exception THEN
      NULL;
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log, 'ERR GEN ');
      fnd_file.put_line(fnd_file.log, substr(SQLERRM, 1, 240));
      errbuf  := 'General exception - ' || substr(SQLERRM, 1, 200);
      retcode := 2;
  END wri_warehouse_clean_up;

END xxinv_wri_warehouse_clean_pkg;
/
