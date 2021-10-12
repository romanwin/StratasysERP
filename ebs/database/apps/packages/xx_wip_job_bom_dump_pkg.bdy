CREATE OR REPLACE PACKAGE BODY apps.xx_wip_job_bom_dump_pkg AS

  /**************************************************************************************************
     Procedure Name: f_get_on_hand_qty
     Parameters    : 1. Inventory Item ID
                     2. Inventory Organization ID
  
     Description   : This function gets the Onhand quantity for a give item.
  
    MODIFICATION HISTORY
    --------------------
    DATE        NAME         DESCRIPTION
    ----------  -----------  --------------------------------------------------------------
    17-SEP-2013 RDAS         Initial Version.
  ***************************************************************************************************/
  FUNCTION f_get_on_hand_qty(p_inventory_item_id IN NUMBER,
                             p_organization_id   IN NUMBER) RETURN NUMBER IS
  
    ln_onhand_qty NUMBER;
  BEGIN
  
    BEGIN
    
      SELECT SUM(transaction_quantity)
        INTO ln_onhand_qty
        FROM mtl_onhand_quantities
       WHERE inventory_item_id = p_inventory_item_id
         AND organization_id = p_organization_id;
    
    EXCEPTION
      WHEN OTHERS THEN
        ln_onhand_qty := NULL;
      
    END;
  
    RETURN ln_onhand_qty;
  
  END f_get_on_hand_qty;

  /**************************************************************************************************
     Procedure Name: f_get_on_hand_qty
     Parameters    : First two parameters are Standard Concurrent program parameters.
                     1. Inventory Organization ID
                     2. This parameter was put in to be able to defragment the
                        table if the program runs slow becuase of the fragmented
                        table. In the concurrent program setup it has been defaulted
                        to 'No'.
  
     Description   : This procedure extracts the Job BOM's for all the Jobs meeting
                     the conditions in the query.
  
    MODIFICATION HISTORY
    --------------------
    DATE        NAME         DESCRIPTION
    ----------  -----------  --------------------------------------------------------------
    17-SEP-2013 RDAS         Initial Version.
  ***************************************************************************************************/
  PROCEDURE p_extract_job_boms(errbuf         OUT VARCHAR2,
                               retcode        OUT NUMBER,
                               p_mfg_org_id   IN NUMBER,
                               p_defrag_table IN VARCHAR2 DEFAULT 'N') AS
  BEGIN
  
    fnd_file.put_line(fnd_file.log,
                      'MFG_ORGANIZATION_ID: ' || p_mfg_org_id);
    EXECUTE IMMEDIATE 'TRUNCATE  TABLE XXOBJT.XX_WIP_STRAT_JOB_COMPONENTS';
  
    MERGE INTO xxobjt.xx_wip_strat_job_components comp
    USING (SELECT job.wip_entity_id,
                  job.wip_entity_name,
                  itm.segment1 item_number,
                  itm.description item_description,
                  job.job_type_meaning job_type,
                  job.status_type_disp status,
                  job.start_quantity job_qty,
                  job.scheduled_start_date start_date,
                  job.scheduled_completion_date end_date,
                  job.date_released released_date,
                  job.bom_revision,
                  job.routing_revision,
                  job.completion_subinventory completion_subinv,
                  loc.concatenated_segments completion_locator,
                  wo.concatenated_segments component_item,
                  wo.item_description component_item_desc,
                  wo.operation_seq_num op_sequence,
                  wo.department_code,
                  wo.item_primary_uom_code uom,
                  wo.basis_type_meaning basis_type,
                  wo.quantity_per_assembly qty_per_assembly,
                  wo.required_quantity qty_per_job,
                  wo.wip_supply_meaning supply_type,
                  wo.supply_subinventory,
                  sloc.concatenated_segments supply_locator,
                  f_get_on_hand_qty(wo.inventory_item_id, wo.organization_id) qty_onhand,
                  wo.quantity_issued qty_issued,
                  wo.quantity_open qty_open,
                  wo.comments component_comment
             FROM wip_discrete_jobs_v          job,
                  mtl_system_items_b           itm,
                  wip_requirement_operations_v wo,
                  mtl_item_locations_kfv       loc,
                  mtl_item_locations_kfv       sloc
            WHERE job.organization_id = p_mfg_org_id
              AND job.wip_entity_id = wo.wip_entity_id
              AND job.primary_item_id = itm.inventory_item_id
              AND job.organization_id = itm.organization_id
              AND job.organization_id = wo.organization_id
              AND wo.wip_supply_type <> 6
              AND job.completion_locator_id = loc.inventory_location_id(+)
              AND wo.supply_locator_id = sloc.inventory_location_id(+)
              AND job.status_type_disp IN ('Unreleased', 'Released')
              AND job.job_type_meaning = 'Standard') jbom
    ON (comp.wip_entity_id = jbom.wip_entity_id)
    WHEN NOT MATCHED THEN
      INSERT
        (comp.wip_entity_id,
         comp.wip_entity_name,
         comp.item_number,
         comp.item_description,
         comp.job_type,
         comp.status,
         comp.job_qty,
         comp.start_date,
         comp.end_date,
         comp.released_date,
         comp.bom_revision,
         comp.routing_revision,
         comp.completion_subinv,
         comp.completion_locator,
         comp.component_item,
         comp.component_item_desc,
         comp.op_sequence,
         comp.department_code,
         comp.uom,
         comp.basis_type,
         comp.qty_per_assembly,
         comp.qty_per_job,
         comp.supply_type,
         comp.supply_subinventory,
         comp.supply_locator,
         comp.qty_onhand,
         comp.qty_issued,
         comp.qty_open,
         comp.component_comment,
         comp.created_by,
         comp.creation_date)
      VALUES
        (jbom.wip_entity_id,
         jbom.wip_entity_name,
         jbom.item_number,
         jbom.item_description,
         jbom.job_type,
         jbom.status,
         jbom.job_qty,
         jbom.start_date,
         jbom.end_date,
         jbom.released_date,
         jbom.bom_revision,
         jbom.routing_revision,
         jbom.completion_subinv,
         jbom.completion_locator,
         jbom.component_item,
         jbom.component_item_desc,
         jbom.op_sequence,
         jbom.department_code,
         jbom.uom,
         jbom.basis_type,
         jbom.qty_per_assembly,
         jbom.qty_per_job,
         jbom.supply_type,
         jbom.supply_subinventory,
         jbom.supply_locator,
         jbom.qty_onhand,
         jbom.qty_issued,
         jbom.qty_open,
         jbom.component_comment,
         fnd_global.user_id,
         SYSDATE)
    WHEN MATCHED THEN
      UPDATE
         SET comp.wip_entity_name     = jbom.wip_entity_name,
             comp.item_number         = jbom.item_number,
             comp.item_description    = jbom.item_description,
             comp.job_type            = jbom.job_type,
             comp.status              = jbom.status,
             comp.job_qty             = jbom.job_qty,
             comp.start_date          = jbom.start_date,
             comp.end_date            = jbom.end_date,
             comp.released_date       = jbom.released_date,
             comp.bom_revision        = jbom.bom_revision,
             comp.routing_revision    = jbom.routing_revision,
             comp.completion_subinv   = jbom.completion_subinv,
             comp.completion_locator  = jbom.completion_locator,
             comp.component_item      = jbom.component_item,
             comp.component_item_desc = jbom.component_item_desc,
             comp.op_sequence         = jbom.op_sequence,
             comp.department_code     = jbom.department_code,
             comp.uom                 = jbom.uom,
             comp.basis_type          = jbom.basis_type,
             comp.qty_per_assembly    = jbom.qty_per_assembly,
             comp.qty_per_job         = jbom.qty_per_job,
             comp.supply_type         = jbom.supply_type,
             comp.supply_subinventory = jbom.supply_subinventory,
             comp.supply_locator      = jbom.supply_locator,
             comp.qty_onhand          = jbom.qty_onhand,
             comp.qty_issued          = jbom.qty_issued,
             comp.qty_open            = jbom.qty_open,
             comp.component_comment   = jbom.component_comment DELETE
       WHERE comp.creation_date <= add_months(SYSDATE, -6);
  
    -- Defragging the table
    IF p_defrag_table = 'Y' THEN
      EXECUTE IMMEDIATE 'CREATE TABLE jbom_temp as select * from XXOBJT.XX_WIP_STRAT_JOB_COMPONENTS';
      EXECUTE IMMEDIATE 'TRUNCATE  TABLE XXOBJT.XX_WIP_STRAT_JOB_COMPONENTS';
      EXECUTE IMMEDIATE 'INSERT INTO XXOBJT.XX_WIP_STRAT_JOB_COMPONENTS select * from jbom_temp';
      EXECUTE IMMEDIATE 'DROP TABLE jbom_temp';
    
    END IF;
  
  END p_extract_job_boms;

END xx_wip_job_bom_dump_pkg;
/
