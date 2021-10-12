CREATE OR REPLACE TRIGGER xxom_pricebook_soa_v_trg
  INSTEAD OF UPDATE ON xxom_pricebook_soa_v

  FOR EACH ROW
------------------------------------------------------------------------------------------
  --  name:     XXINV_PRODUCT_SOA_V_TRG
  --  Description:     update view support for soa use
  --                   used by soa
  ------------------------------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   9.11.17       yuval tal       CHG0041565 - Pricelist Interface - initial build
  ------------------------------------------------------------------------------------------
BEGIN

  IF :new.status = 'IN_PROCESS' AND nvl(:old.status, 'NEW') = 'NEW' THEN
  
    UPDATE xxssys_events t
    SET    t.status = 'IN_PROCESS'
    WHERE  t.event_id = nvl(:old.event_id, :new.event_id);
  END IF;

END xxom_pricebook_soa_v_trg;
/
