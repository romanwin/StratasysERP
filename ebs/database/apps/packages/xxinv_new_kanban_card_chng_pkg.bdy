CREATE OR REPLACE PACKAGE BODY xxinv_new_kanban_card_chng_pkg IS

  -----------------------------------------------------------------------
  --  name:               XXINV_NEW_KANBAN_CARD_CHNG_PKG
  --  create by:          Michal Tzvik 
  --  Revision:           1.0
  --  creation date:      06-OCT-2014
  --  Purpose :           
  -----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   06/10/2014    Michal Tzvik    CHG0032848: initial build
  -----------------------------------------------------------------------  

  --------------------------------------------------------------------
  --  customization code: log_message
  --  name:               
  --  create by:          Michal Tzvik 
  --  Revision:           1.0
  --  creation date:      02/11/2014  
  --  Purpose :           Print messages to log file or dbms_output
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   02/11/2014    Michal Tzvik    CHG0032848: initial build 
  -----------------------------------------------------------------------
  PROCEDURE log_message(p_msg VARCHAR2) IS
  BEGIN
    IF fnd_global.conc_request_id = '-1' THEN
      dbms_output.put_line(p_msg);
    ELSE
      fnd_file.put_line(fnd_file.log, p_msg);
    END IF;
  END log_message;
  --------------------------------------------------------------------
  --  customization code: update_kanban_card_status
  --  name:               
  --  create by:          Michal Tzvik 
  --  Revision:           1.0
  --  creation date:      06/10/2014  
  --  Purpose :           update kanban card status
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   06/10/2014    Michal Tzvik    CHG0032848: initial build 
  -----------------------------------------------------------------------
  PROCEDURE update_kanban_card_status(p_card_status    IN NUMBER,
                                      p_kanban_card_id IN NUMBER)
  
   IS
    l_kanban_card_rec inv_kanban_pvt.kanban_card_rec_type;
  
  BEGIN
  
    l_kanban_card_rec := inv_kanbancard_pkg.query_row(p_kanban_card_id);
    inv_kanbancard_pkg.update_card_status(p_kanban_card_rec => l_kanban_card_rec, p_card_status => p_card_status);
  
  END update_kanban_card_status;

  --------------------------------------------------------------------
  --  customization code: main
  --  name:               
  --  create by:          Michal Tzvik 
  --  Revision:           1.0
  --  creation date:      06/10/2014  
  --  Purpose :           update kanban card status. Called by concurrent program
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   06/10/2014    Michal Tzvik    CHG0032848: initial build 
  -----------------------------------------------------------------------
  PROCEDURE main(errbuf               OUT VARCHAR2,
                 retcode              OUT NUMBER,
                 p_mfg_org_id         IN NUMBER,
                 p_subinventory       IN VARCHAR2,
                 p_inventory_item_id  IN NUMBER,
                 p_current_status     IN VARCHAR2,
                 p_change_to_status   IN VARCHAR2,
                 p_delete_kanban_card IN VARCHAR2) AS
    delete_error EXCEPTION;
    x_return_status VARCHAR2(1);
  
    CURSOR c_kanban IS
      SELECT kc.kanban_card_number,
             kc.kanban_card_id,
             kc.organization_id,
             kps.inventory_item_id,
             itm.segment1 item_number,
             kps.subinventory_name,
             kps.locator_id,
             kps.minimum_order_quantity
      FROM   mtl_kanban_cards          kc,
             mtl_kanban_pull_sequences kps,
             mtl_system_items_b        itm
      WHERE  kc.organization_id = p_mfg_org_id
      AND    kc.supply_status NOT IN (5, 6, 7) -- Not 'In process', 'In Transit' or 'Exception'
      AND    kc.pull_sequence_id = kps.pull_sequence_id
      AND    kps.inventory_item_id = itm.inventory_item_id
      AND    itm.organization_id = p_mfg_org_id
      AND    kc.subinventory_name = p_subinventory
      AND    kc.inventory_item_id =
             nvl(p_inventory_item_id, kc.inventory_item_id)
      AND    kc.card_status = p_current_status;
  
  BEGIN
    errbuf  := 'Normal completion';
    retcode := 0;
  
    log_message('=======================================');
    log_message('Parameters:');
    log_message('-----------');
    log_message('p_mfg_org_id:         ' || p_mfg_org_id);
    log_message('p_subinventory:       ' || p_subinventory);
    log_message('p_inventory_item_id:  ' || p_inventory_item_id);
    log_message('p_current_status:     ' || p_current_status);
    log_message('p_change_to_status:   ' || p_change_to_status);
    log_message('p_delete_kanban_card: ' || p_delete_kanban_card);
    log_message('=======================================');
    log_message(' ');
    log_message(' ');
  
    IF p_current_status = p_change_to_status THEN
      log_message('Parameter ''Current Status'' is equal to parameter ''Change To Status''. Exit program. ');
      RETURN;
    END IF;
  
    IF p_delete_kanban_card = 'NO' THEN
    
      FOR r_kanban IN c_kanban LOOP
        BEGIN
          SAVEPOINT update_status;
          log_message('Update kanban number ' ||
                      r_kanban.kanban_card_number || '...');
          update_kanban_card_status(p_card_status => p_change_to_status, p_kanban_card_id => r_kanban.kanban_card_id);
        
        EXCEPTION
          WHEN OTHERS THEN
            log_message('Failed to update card status of kanban number ' ||
                        r_kanban.kanban_card_number || ': ' || SQLERRM);
            errbuf  := 'Failed to update card status. See details bellow.';
            retcode := 1;
            ROLLBACK TO update_status;
        END;
      END LOOP;
    
    ELSE
      -- p_delete_kanban_card = 'Y'
    
      IF p_change_to_status != 3 THEN
        -- Avoid deleting Card when status is not Cancelled (3)
        log_message('Card can be deleted only on status Cancelled.');
        errbuf  := 'Failed to delete kanban card. See details bellow.';
        retcode := 1;
        RETURN;
      END IF;
    
      FOR r_kanban IN c_kanban LOOP
        BEGIN
          SAVEPOINT cancel_card;
          log_message('Delete kanban number ' ||
                      r_kanban.kanban_card_number || '...');
          update_kanban_card_status(p_card_status => inv_kanban_pvt.g_card_status_cancel, p_kanban_card_id => r_kanban.kanban_card_id);
        
          inv_kanbancard_pkg.delete_row(x_return_status => x_return_status, p_kanban_card_id => r_kanban.kanban_card_id);
        
          IF x_return_status != 'S' THEN
            RAISE delete_error;
          END IF;
        EXCEPTION
          WHEN OTHERS THEN
            log_message('Failed to delete kanban number ' ||
                        r_kanban.kanban_card_number || ': ' || SQLERRM);
            errbuf  := 'Failed to delete kanban card. See details bellow.';
            retcode := 1;
            ROLLBACK TO cancel_card;
        END;
      END LOOP;
    
    END IF;
  
    COMMIT;
  
  END main;

END xxinv_new_kanban_card_chng_pkg;
/
