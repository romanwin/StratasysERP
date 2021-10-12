CREATE OR REPLACE TRIGGER xxinv_b2b_family_soa_v_trg
  INSTEAD OF UPDATE ON xxinv_b2b_family_soa_v

  FOR EACH ROW
--------------------------------------------------------------------
  --  name:          XXINV_B2B_FAMILY_SOA_V_TRG
  --  created by:    
  --  Revision       1.0
  --  creation date: 7.10.20
  --------------------------------------------------------------------
  --  purpose :      used by soa
  --------------------------------------------------------------------------------------------------------------------
  --  ver  date          name                 desc

  -- 1.0   9/7/2020      yuval tal             CHG0048217 - initial 
  -------------------------------------------------------------
BEGIN
  IF :new.status = 'IN_PROCESS' AND nvl(:old.status, 'NEW') = 'NEW' THEN
  
    UPDATE xxssys_events t
    SET    t.status = 'IN_PROCESS'
    WHERE  t.event_id = nvl(:old.event_id, :new.event_id);
  END IF;

END;
/
