CREATE OR REPLACE TRIGGER xxpo_vendor_site_soa_v_trg
------------------------------------------------------------------------------------------
  -- Trigger: XXPO_VENDOR_SITE_SOA_V_TRG
  -- Created:
  -- Author  :
  -- Version: 1.0
  -------------------------------------------------------------------------------------------
  -- Ver When        Who        Description
  -- --- ----------  ---------  -------------------------------------------------------------
  -- 1.0 20/03/2018  Roman.W    Init Version
  --                            CHG0042545 - New Vendors interface from Oracle to  Stratadoc
  --                            trigger used by soa
  -------------------------------------------------------------------------------------------
  INSTEAD OF UPDATE ON xxpo_vendor_site_soa_v
  FOR EACH ROW
-----------------------
  --   Code Section
  -----------------------
BEGIN
  IF :new.status = 'IN_PROCESS' AND nvl(:old.status, 'NEW') = 'NEW' THEN
  
    UPDATE xxssys_events t
    SET    t.status = 'IN_PROCESS'
    WHERE  t.event_id = nvl(:old.event_id, :new.event_id);
  END IF;
END;
/
