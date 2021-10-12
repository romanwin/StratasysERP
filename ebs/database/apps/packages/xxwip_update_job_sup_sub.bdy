CREATE OR REPLACE PACKAGE BODY xxwip_update_job_sup_sub IS

  --------------------------------------------------------------------
  --  name:            XXWIP_UPDATE_JOB_SUP_SUB
  --  create by:       ARIK LALO
  --  Revision:        1.0
  --  creation date:   14/04/2004
  --------------------------------------------------------------------
  --  purpose :
  --
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  14/04/2004  ARIK LALO       initial build
  --  1.1  23.6.11     YUVAL TAL       ADD wip_update2
  --  1.2  18.08.2013  Vitaly          CR 870 std cost - change hard-coded organization
  --  1.3  28.05.2014  Gary Altman     CHG0032162 - add procedure to cancel ato jobs
  --  1.4  04/11/2014  Dalit A. Raviv  CHG0033022 - Update Supply Information in WIP Material Requirements
  --                                   add procedure wip_change_supply_info
  --  1.5  15/12/2014  Dalit A. Raviv  CHG0034089 procedure wip_change_supply_info
  --  1.6  21/05/2015  Michal Tzvik    CHG0034294 – Restrict issue QTY: update PROCEDURE wip_change_supply_info
  --------------------------------------------------------------------

  c_success CONSTANT VARCHAR2(1) := '0';
  c_warning CONSTANT VARCHAR2(1) := '1';
  c_error   CONSTANT VARCHAR2(1) := '2';

  --------------------------------------------------------------------
  --  name:            wip_update2
  --  create by:       XXX
  --  Revision:        1.0
  --  creation date:   14/04/XXXX
  --------------------------------------------------------------------
  --  purpose :
  --
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  14/04/XXXX  XXX             initial build
  --------------------------------------------------------------------
  PROCEDURE wip_update2(errbuf            OUT VARCHAR2,
                        retcode           OUT VARCHAR2,
                        p_organization_id IN NUMBER,
                        p_item_id         NUMBER,
                        p_job_number      VARCHAR2) IS
  
    CURSOR c IS
      SELECT DISTINCT e.rowid                     row_id,
                      w.wip_entity_name           job_name,
                      e.inventory_item_id,
                      e.organization_id           organization_id,
                      msi.segment1,
                      e.supply_subinventory       material_requirment_sub,
                      msi.wip_supply_subinventory master_item_sub,
                      r.subinventory_name         kanban_sub,
                      rr.inventory_location_id    material_requirment_locator_id,
                      rr.concatenated_segments    material_requirment_locator,
                      rr2.concatenated_segments   master_item_locator,
                      mil.inventory_location_id   kanban_locator_id,
                      mil.concatenated_segments   kanban_locator
      FROM   wip_requirement_operations e,
             wip_entities               w,
             mtl_system_items_b         msi,
             wip_discrete_jobs          wip,
             mtl_item_locations_kfv     rr,
             mtl_item_locations_kfv     rr2,
             mtl_kanban_cards_v         r,
             mtl_item_locations_kfv     mil
      WHERE  w.wip_entity_id = e.wip_entity_id
      AND    e.inventory_item_id = msi.inventory_item_id
      AND    e.organization_id = msi.organization_id
      AND    e.wip_supply_type NOT IN (4, 5, 6)
      AND    e.wip_entity_id = wip.wip_entity_id
      AND    wip.status_type NOT IN (4, 12, 7)
      AND    wip.organization_id = 735 --IPK
      AND    e.supply_subinventory IS NOT NULL
      AND    e.supply_locator_id != msi.wip_supply_locator_id
      AND    rr.inventory_location_id = e.supply_locator_id
      AND    msi.wip_supply_locator_id = rr2.inventory_location_id
      AND    msi.organization_id = rr.organization_id
      AND    rr2.organization_id = e.organization_id
      AND    mil.inventory_location_id = r.locator_id
      AND    mil.organization_id = r.organization_id
      AND    r.card_status_name != 'Canceled'
      AND    r.source_organization_id = 735 --IPK
      AND    r.inventory_item_id = msi.inventory_item_id
      AND    r.organization_id = msi.organization_id
      AND    e.inventory_item_id = nvl(p_item_id, e.inventory_item_id)
      AND    e.organization_id = nvl(p_organization_id, e.organization_id)
      AND    w.wip_entity_name = nvl(p_job_number, w.wip_entity_name)
      AND    e.quantity_issued = 0;
    l_inx NUMBER := 0;
  BEGIN
    errbuf := NULL;
    FOR i IN c LOOP
    
      IF i.kanban_sub = i.material_requirment_sub AND
         i.material_requirment_locator_id != i.kanban_locator_id THEN
      
        l_inx := l_inx + 1;
        UPDATE wip_requirement_operations wro
        SET    wro.supply_locator_id = i.kanban_locator_id,
               wro.last_update_date  = SYSDATE,
               wro.last_updated_by   = fnd_global.user_id,
               wro.last_update_login = fnd_global.login_id
        WHERE  wro.rowid = i.row_id;
      
        COMMIT;
      END IF;
    
    END LOOP;
    retcode := 0;
    retcode := 'Updated rows :' || l_inx;
  END;

  --------------------------------------------------------------------
  --  name:            wip_update
  --  create by:       XXX
  --  Revision:        1.0
  --  creation date:   14/04/XXXX
  --------------------------------------------------------------------
  --  purpose :
  --
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  14/04/XXXX  XXX             initial build
  --------------------------------------------------------------------
  PROCEDURE wip_update(errbuf            OUT VARCHAR2,
                       retcode           OUT VARCHAR2,
                       p_job_number      IN NUMBER,
                       p_organization_id IN NUMBER) IS
  
    v_wip_entity_id         wip_entities.wip_entity_id%TYPE;
    v_wip_supply_subinv     wip_discrete_jobs.attribute1%TYPE;
    v_wip_def_supply_subinv wip_parameters.default_pull_supply_subinv%TYPE;
    v_error                 VARCHAR2(400);
  
  BEGIN
  
    BEGIN
      SELECT wp.default_pull_supply_subinv
      INTO   v_wip_def_supply_subinv
      FROM   wip_parameters wp
      WHERE  wp.organization_id = p_organization_id;
    EXCEPTION
      WHEN no_data_found THEN
        v_wip_def_supply_subinv := NULL;
      WHEN OTHERS THEN
        v_error := substr(SQLERRM, 1, 80);
        errbuf  := 'Oracle Inserting Error: ' || v_error;
        retcode := '2';
    END;
  
    BEGIN
      SELECT wip_entity_id
      INTO   v_wip_entity_id
      FROM   wip_entities we
      WHERE  we.wip_entity_name = to_char(p_job_number)
      AND    we.organization_id = p_organization_id;
    EXCEPTION
      WHEN no_data_found THEN
        v_wip_entity_id := NULL;
      WHEN OTHERS THEN
        v_error := substr(SQLERRM, 1, 80);
        errbuf  := 'Oracle Inserting Error: ' || v_error;
        retcode := '2';
    END;
  
    BEGIN
      SELECT attribute1
      INTO   v_wip_supply_subinv
      FROM   wip_discrete_jobs wdj,
             wip_entities      we
      WHERE  we.wip_entity_id = wdj.wip_entity_id
      AND    we.organization_id = wdj.organization_id
      AND    we.organization_id = wdj.organization_id
      AND    we.wip_entity_name = to_char(p_job_number);
    EXCEPTION
      WHEN no_data_found THEN
        v_wip_supply_subinv := v_wip_def_supply_subinv;
      WHEN OTHERS THEN
        v_error := substr(SQLERRM, 1, 80);
        errbuf  := 'Oracle Inserting Error: ' || v_error;
        retcode := '2';
    END;
  
    BEGIN
      UPDATE wip_requirement_operations wro
      SET    wro.supply_subinventory = v_wip_supply_subinv
      WHERE  wro.organization_id = p_organization_id
      AND    wro.wip_entity_id = v_wip_entity_id
      AND    wro.wip_supply_type NOT IN ('4', '5', '6');
    EXCEPTION
      WHEN OTHERS THEN
        v_error := substr(SQLERRM, 1, 80);
        errbuf  := 'Oracle Inserting Error: ' || v_error;
        retcode := '2';
    END;
  
  END wip_update;

  --------------------------------------------------------------------
  --  name:            eneter_job_details
  --  create by:       XXX
  --  Revision:        1.0
  --  creation date:   14/04/XXXX
  --------------------------------------------------------------------
  --  purpose :        Enter job details to interface table
  --
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  14/04/XXXX  XXX             initial build
  --------------------------------------------------------------------
  PROCEDURE eneter_job_details(p_wip_entity_name IN VARCHAR2,
                               p_organization_id NUMBER,
                               p_group_id        NUMBER) IS
  
  BEGIN
    INSERT INTO wip_job_schedule_interface
      (load_type,
       process_phase,
       process_status,
       group_id,
       organization_id,
       job_name,
       status_type,
       creation_date,
       created_by,
       last_update_date,
       last_updated_by)
    VALUES
      (3, -- load type update
       2, --PROCESS_PHASE validation
       1, --PROCESS_STATUS pending
       p_group_id,
       p_organization_id,
       p_wip_entity_name,
       7, -- status type cancel
       SYSDATE,
       fnd_global.user_id,
       SYSDATE,
       fnd_global.user_id);
  
    COMMIT;
  
  END eneter_job_details;

  --------------------------------------------------------------------
  --  name:            submit_request
  --  create by:       XXX
  --  Revision:        1.0
  --  creation date:   14/04/XXXX
  --------------------------------------------------------------------
  --  purpose :        Run Open Interface "WIP Mass Load"
  --
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  14/04/XXXX  XXX             initial build
  --------------------------------------------------------------------
  FUNCTION submit_request(p_conc     VARCHAR2,
                          p_app      VARCHAR2,
                          p_group_id NUMBER) RETURN VARCHAR2 IS
    l_request_id         NUMBER;
    l_phase              VARCHAR2(100);
    l_phase_code         VARCHAR2(100);
    l_status             VARCHAR2(100);
    l_status_code        VARCHAR2(100);
    l_completion_message VARCHAR2(2000);
    l_res                BOOLEAN;
  
  BEGIN
    l_request_id := fnd_request.submit_request(application => p_app, program => p_conc, argument1 => p_group_id, argument2 => 0, argument3 => 'No');
  
    IF l_request_id <> 0 THEN
      COMMIT;
      l_res := fnd_concurrent.wait_for_request(request_id => l_request_id, INTERVAL => 1, phase => l_phase, status => l_status, dev_phase => l_phase_code, dev_status => l_status_code, message => l_completion_message);
    ELSE
      RETURN 'Error';
    END IF;
  
    RETURN l_status;
  END submit_request;

  --------------------------------------------------------------------
  --  name:            check_errors
  --  create by:       XXX
  --  Revision:        1.0
  --  creation date:   14/04/XXXX
  --------------------------------------------------------------------
  --  purpose :        Check rows in interface table for group_id
  --
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  14/04/XXXX  XXX             initial build
  --------------------------------------------------------------------
  FUNCTION check_errors(p_group_id NUMBER) RETURN VARCHAR2 IS
  
    CURSOR c_errors IS
      SELECT wjb.job_name
      FROM   wip_job_schedule_interface wjb
      WHERE  wjb.group_id = p_group_id;
  
    l_errors VARCHAR2(100);
  
  BEGIN
  
    l_errors := 'No';
  
    FOR l_err IN c_errors LOOP
      l_errors := 'Yes';
      fnd_file.put_line(fnd_file.log, 'WIP Mass Load Failed for Job:  ' ||
                         l_err.job_name || ' - Group Id: ' ||
                         p_group_id);
    END LOOP;
  
    RETURN l_errors;
  END check_errors;

  --------------------------------------------------------------------
  --  name:            cancel_ato_job
  --  create by:       XXX
  --  Revision:        1.0
  --  creation date:   14/04/XXXX
  --------------------------------------------------------------------
  --  purpose :        Run API to cancel ATO jobs are not connected to SO
  --
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  14/04/XXXX  XXX             initial build
  --------------------------------------------------------------------
  PROCEDURE cancel_ato_job(errbuf  OUT VARCHAR2,
                           retcode OUT VARCHAR2) IS
  
    CURSOR c_jobs IS
      SELECT wdj.wip_entity_id,
             we.wip_entity_name,
             wdj.organization_id
      FROM   wip_discrete_jobs  wdj,
             wip_reservations_v wrv,
             wip_entities       we
      WHERE  wdj.class_code = 'ATO'
      AND    wdj.wip_entity_id = wrv.wip_entity_id(+)
      AND    wrv.reservation_id IS NULL
      AND    wdj.status_type IN (1, 3, 6) -- Unreleasd , Released, On Hold
      AND    wdj.wip_entity_id = we.wip_entity_id
      AND    wdj.source_code = 'WICDOL';
  
    l_group_id NUMBER;
    --l_request_id           NUMBER;
    --l_phase                VARCHAR2(100);
    --l_phase_code           VARCHAR2(100);
    l_status VARCHAR2(100);
    --l_status_code          VARCHAR2(100);
    --l_completion_message   VARCHAR2(2000);
    --l_res                  BOOLEAN;
    l_errors VARCHAR2(100);
  
  BEGIN
  
    retcode := c_success;
  
    SELECT wip_job_schedule_interface_s.nextval
    INTO   l_group_id
    FROM   dual;
  
    FOR l_jobs IN c_jobs LOOP
    
      eneter_job_details(l_jobs.wip_entity_name, l_jobs.organization_id, l_group_id);
    END LOOP;
  
    l_status := submit_request('WICMLP', 'WIP', l_group_id);
  
    IF l_status = 'Error' THEN
      fnd_file.put_line(fnd_file.log, 'WIP Mass Load Completed With Error.');
      retcode := c_error;
      RETURN;
    END IF;
  
    IF l_status = 'Warning' THEN
      fnd_file.put_line(fnd_file.log, 'WIP Mass Load Completed With Warning.');
      retcode := c_warning;
    ELSE
      l_errors := check_errors(l_group_id);
      IF l_errors = 'No' THEN
        fnd_file.put_line(fnd_file.log, 'WIP Mass Load Completed Successfully.');
      ELSE
        fnd_file.put_line(fnd_file.log, 'WIP Mass Load Completed With Warning.');
        retcode := c_warning;
      END IF;
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      retcode := c_error;
      errbuf  := SQLERRM;
  END cancel_ato_job;

  --------------------------------------------------------------------
  --  name:            CHG0033022 - Update Supply Information in WIP Material Requirements
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   04/11/2014
  --------------------------------------------------------------------
  --  purpose :        Update wip_supply_type, supply_subinventory, and supply_locator_id
  --                   at wip_requirement_operations tbl by:
  --                   take values from BOM if all 3 fields are null take from organization item.
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  04/11/2014  Dalit A. Raviv  initial build
  --  1.1  15/12/2014  Dalit A. Raviv  CHG0034089 - update conditions changed
  --  1.2  21/05/2015  Michal Tzvik    CHG0034294 – Restrict issue QTY
  --------------------------------------------------------------------
  PROCEDURE wip_change_supply_info(errbuf              OUT VARCHAR2,
                                   retcode             OUT VARCHAR2,
                                   p_organization_id   IN NUMBER,
                                   p_inventory_item_id IN NUMBER) IS
  
    CURSOR c_pop IS
    -- Find all Jobs and Material Requirements according to parameters.
      SELECT wro.wip_entity_id       wip_entity_id,
             we.wip_entity_name      job,
             msib1.inventory_item_id assembly_item_id,
             msib1.segment1          assembly,
             msib.inventory_item_id  component_item_id,
             msib.segment1           component,
             wro.wip_supply_type     job_supply_type,
             wro.supply_subinventory supply_subinventory,
             wro.supply_locator_id   supply_locator_id,
             wro.organization_id     organization_id,
             wro.operation_seq_num   operation_seq_num
      FROM   mtl_system_items_b         msib,
             mtl_system_items_b         msib1,
             wip_requirement_operations wro,
             wip_entities               we,
             wip_discrete_jobs          wdj
      WHERE  wro.organization_id = msib.organization_id
      AND    wro.inventory_item_id = msib.inventory_item_id
      AND    wdj.organization_id = msib1.organization_id
      AND    wdj.primary_item_id = msib1.inventory_item_id
      AND    wdj.wip_entity_id = wro.wip_entity_id
      AND    wro.wip_entity_id = we.wip_entity_id
      AND    wro.organization_id = we.organization_id
      AND    wdj.status_type IN (1, 3) -- job released/unreleased
      AND    msib.organization_id = p_organization_id --735
      AND    msib.inventory_item_id = p_inventory_item_id
      --and    we.wip_entity_name         = '441990'
      ;
    -- because the job contain all items from the BOM tree (pantoms too)
    -- we need to use this table. there is a program that run each day and do BOM explode to all
    -- assembly items.
    CURSOR c_bom_info(p_component_item_id IN NUMBER,
                      p_assembly_item_id  IN NUMBER) IS -- need to change the select
      SELECT xbeh.wip_supply_type,
             xbeh.supply_subinventory,
             xbeh.supply_locator_id
      FROM   xxinv_bom_explode_history xbeh
      WHERE  top_assembly_item_id = p_assembly_item_id -- 1120976
      AND    organization_id = p_organization_id
      AND    comp_item_id = p_component_item_id -- 14094
      AND    (xbeh.wip_supply_type IS NOT NULL AND
            xbeh.supply_subinventory IS NOT NULL AND
            xbeh.supply_locator_id IS NOT NULL);
  
    CURSOR c_item_info IS
    -- WIP Supply Information in Organization item
      SELECT msib.segment1 item,
             msib.wip_supply_type,
             msib.wip_supply_subinventory,
             msib.wip_supply_locator_id
      FROM   mtl_system_items_b msib
      WHERE  msib.organization_id = p_organization_id -- 735
      AND    msib.inventory_item_id = p_inventory_item_id;
    --and    msib.segment1              = 'ASY-01034' -- <parameter>
  
    l_supply_subinventory wip_requirement_operations.supply_subinventory%TYPE;
    l_supply_locator_id   wip_requirement_operations.supply_locator_id%TYPE;
    l_wip_supply_type     wip_requirement_operations.wip_supply_type%TYPE;
  
  BEGIN
    errbuf  := NULL;
    retcode := 0;
    FOR pop_r IN c_pop LOOP
      fnd_file.put_line(fnd_file.log, '--- Ass: ' || pop_r.assembly ||
                         ' Comp: ' || pop_r.component ||
                         ' ---');
      l_supply_subinventory := NULL;
      l_supply_locator_id   := NULL;
      l_wip_supply_type     := NULL;
      -- 1) Get BOM information
      FOR bom_info_r IN c_bom_info(pop_r.component_item_id, pop_r.assembly_item_id) LOOP
        l_supply_subinventory := bom_info_r.supply_subinventory;
        l_supply_locator_id   := bom_info_r.supply_locator_id;
        l_wip_supply_type     := bom_info_r.wip_supply_type;
      END LOOP;
    
      FOR item_info_r IN c_item_info LOOP
        IF l_supply_subinventory IS NULL THEN
          l_supply_subinventory := item_info_r.wip_supply_subinventory;
        END IF;
        IF l_supply_locator_id IS NULL THEN
          l_supply_locator_id := item_info_r.wip_supply_locator_id;
        END IF;
        IF l_wip_supply_type IS NULL THEN
          l_wip_supply_type := item_info_r.wip_supply_type;
        END IF;
      END LOOP;
    
      -- 3) if all 3 fileds are null write message to log
      IF l_supply_subinventory IS NULL AND l_supply_locator_id IS NULL AND
         l_wip_supply_type IS NULL THEN
        fnd_message.set_name('XXOBJT', 'XXWIP_CNG_SUPPLY_INFO_NULLS'); -- All supply fields are null
        fnd_file.put_line(fnd_file.log, fnd_message.get);
        --dbms_output.put_line(fnd_message.get);
      ELSE
        IF l_wip_supply_type IN (2, 3) AND l_supply_subinventory IS NULL THEN
          fnd_message.set_name('XXOBJT', 'XXWIP_CNG_SUPPLY_INFO_TYPES'); -- Subinventory have null value for supply type either Assembly Pull(2) or Operation Pull(3) - &STYPE
          fnd_message.set_token('STYPE', l_wip_supply_type);
          fnd_file.put_line(fnd_file.log, fnd_message.get);
          --dbms_output.put_line(fnd_message.get);
        ELSE
          BEGIN
            UPDATE wip_requirement_operations wro
            SET    wro.supply_locator_id   = l_supply_locator_id,
                   wro.supply_subinventory = l_supply_subinventory,
                   wro.wip_supply_type     = l_wip_supply_type,
                   wro.last_update_date    = SYSDATE,
                   wro.last_updated_by     = fnd_global.user_id,
                   wro.last_update_login   = fnd_global.login_id
            WHERE  wro.wip_entity_id = pop_r.wip_entity_id
                  -- 1.1 15/12/2014 Dalit A. Raviv CHG0034089 
            AND    wro.inventory_item_id = pop_r.component_item_id
            AND    wro.organization_id = pop_r.organization_id
            AND    wro.operation_seq_num = pop_r.operation_seq_num
            AND    wro.wip_supply_type <> 6
            AND    nvl(wro.required_quantity, 0) -
                   nvl(wro.quantity_issued, 0) > 0
                  -- 1.2 21/05/2015 Michal Tzvik CHG0034294
            AND    nvl(wro.quantity_issued, 0) = 0;
          
            COMMIT;
          EXCEPTION
            WHEN OTHERS THEN
              fnd_file.put_line(fnd_file.log, 'E Update - Supply type: ' ||
                                 l_wip_supply_type ||
                                 ', Supply Subinv: ' ||
                                 l_supply_subinventory ||
                                 ', Supply Locator id: ' ||
                                 l_supply_locator_id || ' - ' ||
                                 substr(SQLERRM, 1, 240));
              /*dbms_output.put_line('E Update - Supply type: '||l_wip_supply_type||
              ', Supply Subinv: '||l_supply_subinventory||', Supply Locator id: '||l_supply_locator_id||
              ' - '||substr(sqlerrm,1,240)); */
          END;
          fnd_file.put_line(fnd_file.log, 'S Update - Job ' || pop_r.job ||
                             ' Supply type: ' ||
                             l_wip_supply_type ||
                             ', Supply Subinv: ' ||
                             l_supply_subinventory ||
                             ', Supply Locator id: ' ||
                             l_supply_locator_id);
          /*dbms_output.put_line('S Update - Supply type: '||l_wip_supply_type||
          ', Supply Subinv: '||l_supply_subinventory||', Supply Locator id: '||l_supply_locator_id);*/
        END IF; -- wp supply type
      END IF; -- all fields are null
    END LOOP; -- pop_r
  END wip_change_supply_info;

END xxwip_update_job_sup_sub;
/
