CREATE OR REPLACE TRIGGER xxcsi_asset_soa_v_trg
  INSTEAD OF UPDATE ON xxcsi_asset_soa_v
  FOR EACH ROW
-----------------------------------------------------------------------
  --  name:     XXCSI_ASSET_SOA_V_TRG
  --  Description:     CHG0042619 - Install base interface from Oracle to salesforce
  --                  used by soa
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   28.3.18      yuval tal       CHG0042619 - Install base interface from Oracle to salesforce
  --------------------------------------------------------------------
BEGIN
  IF :new.status = 'IN_PROCESS' AND nvl(:old.status, 'NEW') = 'NEW' THEN
  
    UPDATE xxssys_events t
    SET    t.status = 'IN_PROCESS'
    WHERE  t.event_id = nvl(:old.event_id, :new.event_id);
  END IF;
END xxcsi_asset_soa_v_trg;
/
