CREATE OR REPLACE TRIGGER XXOBJT_OA2SF_ACC_REL_V_TRG
  INSTEAD OF UPDATE ON xxobjt_oa2sf_acc_relate_intr_v
  FOR EACH ROW
BEGIN
----------------------------------------------------------------------------------------
--  customization code: CHG0034741 - New Interface OA2SF for Account relationships
--  name:               XXOBJT_OA2SF_ACC_REL_V_TRG
--  create by:          Yuval Tal
--  $Revision:          1.0
--  creation date:      20/05/2015
--  Purpose :           will use by Bpel process - oa2sf_UpsertAccountRelationShip
--                      this is an "instead of" trigger that do update to a table by using a view
----------------------------------------------------------------------------------------
--  ver   date          name             desc
--  1.0   20/05/2015    Yuval Tal        initial build
----------------------------------------------------------------------------------------
  IF :new.int_status = 'IN_PROCESS' AND nvl(:old.int_status, 'NEW') = 'NEW' THEN
  
    UPDATE xxobjt_oa2sf_interface t
    SET    t.status = 'IN_PROCESS' --:new.int_status
    WHERE  t.oracle_event_id =
           nvl(:old.oracle_event_id, :new.oracle_event_id);
  END IF;

END;
/
