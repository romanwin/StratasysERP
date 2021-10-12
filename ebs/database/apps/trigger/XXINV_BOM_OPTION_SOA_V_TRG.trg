CREATE OR REPLACE TRIGGER XXINV_BOM_OPTION_SOA_V_TRG
  INSTEAD OF UPDATE ON XXINV_BOM_OPTION_SOA_V

  FOR EACH ROW
--------------------------------------------------------------------
--  name       :     XXINV_BOM_OPTION_SOA_V_TRG
--  Description:     update Trigger view support for soa use
--                   used by soa, This Trigger will Update the XXSSYS_EVENTS Table Records to In_Process.
--------------------------------------------------------------------
--  ver   date          name            desc
--  1.0   9.11.17       yuval tal       CHG0041630 - PTO Interface
--------------------------------------------------------------------
BEGIN

  IF :new.status = 'IN_PROCESS' AND nvl(:old.status, 'NEW') = 'NEW' THEN

    UPDATE XXSSYS_EVENTS t
    SET    t.status = 'IN_PROCESS'
    WHERE  t.event_id =
           nvl(:old.event_id, :new.event_id);
  END IF;

END XXINV_BOM_OPTION_SOA_V_TRG;
/
