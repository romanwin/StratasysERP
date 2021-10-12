create or replace trigger APPS."XXINV_PRONTO_ONHAND_V_TRG"
  INSTEAD OF UPDATE ON XXINV_PRONTO_ONHAND_V
  FOR EACH ROW
BEGIN
----------------------------------------------------------------------------------------
--  customization code: CHG0036886 PRONTO INTERFACE
--  name:               XXINV_PRONTO_ONHAND_V_TRG
--  create by:          ABHJIT 
--  $Revision:          1.0
--  creation date:      
--  Purpose :           
----------------------------------------------------------------------------------------
--  ver   date          name             desc
--  1.0   20/05/2015    Abhijit         initial build
----------------------------------------------------------------------------------------
  IF :new.status = 'IN_PROCESS' AND nvl(:old.status, 'NEW') = 'NEW' THEN

    UPDATE XXSSYS_EVENTS t
    SET    t.status = 'IN_PROCESS' --:new.int_status
    WHERE  t.event_id =
           nvl(:old.event_id, :new.event_id);
  END IF;

end;
/

ALTER TRIGGER "APPS"."XXINV_PRONTO_ONHAND_V_TRG" ENABLE;
