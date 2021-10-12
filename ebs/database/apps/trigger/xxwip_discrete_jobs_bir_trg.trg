CREATE OR REPLACE TRIGGER xxwip_discrete_jobs_bir_trg
 ---------------------------------------------------------------------------

  --  customization code: 
  --  name:               xxwip_discrete_jobs_bir_trg
  --  create by:          
  --  $Revision:          
  --  creation date: 
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.x   31.8.14        Ginat B        CHG0032991 Set up new OSP process for Kits manufacturing

    BEFORE INSERT OR UPDATE OF status_type ON WIP_DISCRETE_JOBS
  FOR EACH ROW
  
 
when (NEW.status_type IN (1, 3) AND NEW.schedule_group_id IS NULL)
DECLARE
  l_schedule_group_id NUMBER;
  -- l_op_assembly_id    NUMBER;

BEGIN
  -- --Ginat b.
  -- IF :new.job_type = 1 THEN 
  --   l_op_assembly_id := :new.primary_item_id;
  -- ELSE
  --   l_op_assembly_id := :new.routing_reference_id;
  --  END IF;

  SELECT bor.attribute1
    INTO l_schedule_group_id
    FROM bom_operational_routings bor
   WHERE bor.common_routing_sequence_id = :new.common_routing_sequence_id --Ginat b.
        --bor.organization_id = :NEW.organization_id 
        --AND bor.assembly_item_id = l_op_assembly_id
     AND attribute1 IS NOT NULL;

  :new.schedule_group_id := l_schedule_group_id;

EXCEPTION
  WHEN OTHERS THEN
    NULL;
  
END xxwip_discrete_jobs_bir_trg;
/
