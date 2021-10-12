CREATE OR REPLACE TRIGGER XXINV_SYSTEM_SETUP_SOA_V_TRG
  INSTEAD OF UPDATE ON XXINV_SYSTEM_SETUP_SOA_V

  FOR EACH ROW
--------------------------------------------------------------------
--  name       :     XXINV_SYSTEM_SETUP_SOA_V_TRG
--  Description:
--                   used by soa (Strataforce Project)
--------------------------------------------------------------------
--  ver   date          name            desc
--  1.0   24.01.2018    yuval tal       CHG0042203 - New 'System' item setup interface
--------------------------------------------------------------------
BEGIN
  IF :new.status = 'IN_PROCESS' AND nvl(:old.status, 'NEW') = 'NEW' THEN

    UPDATE XXSSYS_EVENTS t
    SET    t.status = 'IN_PROCESS'
    WHERE  t.event_id =
           nvl(:old.event_id, :new.event_id);
  END IF;

End XXINV_SYSTEM_SETUP_SOA_V_TRG;
/
