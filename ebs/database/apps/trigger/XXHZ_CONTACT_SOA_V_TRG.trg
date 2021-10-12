CREATE OR REPLACE TRIGGER "APPS"."XXHZ_CONTACT_SOA_V_TRG" 
  INSTEAD OF UPDATE ON XXHZ_CONTACT_SOA_V

  FOR EACH ROW
--------------------------------------------------------------------
  --  name:     XXHZ_CONTACT_SOA_V_TRG
  --  Description:     update view support for soa use
  --                   used by soa
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   9.11.17       yuval tal       CHG0042010
  --------------------------------------------------------------------
BEGIN
  IF :new.status = 'IN_PROCESS' AND nvl(:old.status, 'NEW') = 'NEW' THEN
  
    UPDATE XXSSYS_EVENTS t
       SET t.status = 'IN_PROCESS'
     WHERE t.event_id = nvl(:old.event_id, :new.event_id);
  END IF;

end;

--ALTER TRIGGER "APPS"."XXHZ_CONTACT_SOA_V_TRG" ENABLE
/