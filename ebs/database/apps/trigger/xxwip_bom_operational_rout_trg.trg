CREATE OR REPLACE TRIGGER xxwip_bom_operational_rout_trg
  BEFORE UPDATE OF attribute1 ON bom_operational_routings
  FOR EACH ROW
when (OLD.attribute1 IS NULL AND NEW.attribute1 IS NOT NULL)
BEGIN

  UPDATE wip_discrete_jobs wdj
     SET wdj.schedule_group_id = :NEW.attribute1
   WHERE wdj.organization_id = :NEW.organization_id
     AND (CASE WHEN wdj.job_type = 1 THEN wdj.primary_item_id ELSE
          wdj.routing_reference_id END) = :NEW.assembly_item_id;

EXCEPTION
  WHEN OTHERS THEN
    NULL;
  
END xxwip_bom_operational_rout_trg;
/

