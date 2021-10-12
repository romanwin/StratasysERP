CREATE OR REPLACE TRIGGER xxcs_insert_desc_tas_trg
   ---------------------------------------------------------------------------
   -- $Header: xxcs_insert_desc_tas_trg 120.0 2009/08/31  $
   ---------------------------------------------------------------------------
   -- Trigger: xxcs_insert_desc_tas_trg
   -- Created: Maoz
   -- Author  : 02/06/2009
   --------------------------------------------------------------------------
   -- Perpose: update task description
   --------------------------------------------------------------------------
   -- Version  Date      Performer       Comments
   ----------  --------  --------------  -------------------------------------
   --     1.0  31/08/09                  Initial Build
   ---------------------------------------------------------------------------
  BEFORE INSERT ON jtf_tasks_tl
  FOR EACH ROW

DECLARE
   v_prof      VARCHAR2(10);
   v_task_desc VARCHAR2(500);
   v_error     VARCHAR(4000);
BEGIN

   SELECT 'S/N: ' || cii.serial_number || '; Item: ' || msi.description ||
          '; Problem: ' || flv.meaning all_desc
     INTO v_task_desc
     FROM cs_incidents_all_b cia,
          mtl_system_items_b msi,
          fnd_lookup_values  flv,
          csi_item_instances cii,
          jtf_tasks_b        jtb
    WHERE flv.lookup_code = cia.problem_code AND
          cia.inventory_item_id = msi.inventory_item_id(+) AND
          cii.instance_id(+) = cia.customer_product_id AND
          cia.incident_id = jtb.source_object_id AND
          msi.organization_id(+) =
          xxinv_utils_pkg.get_master_organization_id AND
          flv.lookup_type = 'REQUEST_PROBLEM_CODE' AND
          jtb.task_id = :NEW.task_id AND
          flv.LANGUAGE = :NEW.LANGUAGE;

   :NEW.description := v_task_desc;

EXCEPTION
   WHEN OTHERS THEN
      NULL;
END xxcs_insert_desc_tas_trg;
/

