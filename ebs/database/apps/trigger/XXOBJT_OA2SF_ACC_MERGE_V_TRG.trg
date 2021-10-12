CREATE OR REPLACE TRIGGER XXOBJT_OA2SF_ACC_MERGE_V_TRG
  INSTEAD OF UPDATE ON XXOBJT_OA2SF_ACC_MERGE_INTR_V FOR EACH ROW
BEGIN
----------------------------------------------------------------------------------------
--  customization code: CHG0036771 - Merge Customers and SF 
--  name:               XXOBJT_OA2SF_ACC_MERGE_INTR_V
--  create by:          Dalit A. Raviv
--  $Revision:          1.0
--  creation date:      28-Oct-2015
--  Purpose :           will use by Bpel process - oa2sf_UpsertAccountMerge
--                      this is an "instead of" trigger that do update to a table by using a view
----------------------------------------------------------------------------------------
--  ver   date          name             desc
--  1.0   28-Oct-2015   Dalit A. Raviv   initial build
----------------------------------------------------------------------------------------
  IF :new.int_status = 'IN_PROCESS'
     AND nvl(:old.int_status, 'NEW') = 'NEW' THEN

    UPDATE xxobjt_oa2sf_interface t
    SET    t.status = 'IN_PROCESS' --:new.int_status
    WHERE  t.oracle_event_id =
           nvl(:old.oracle_event_id, :new.oracle_event_id);
  END IF;
END;
/
