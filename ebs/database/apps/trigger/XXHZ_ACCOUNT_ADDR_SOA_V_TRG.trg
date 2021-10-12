CREATE OR REPLACE TRIGGER "APPS"."XXHZ_ACCOUNT_ADDR_SOA_V_TRG" 
  INSTEAD OF UPDATE ON XXHZ_ACCOUNT_ADDR_SOA_V
  FOR EACH ROW
---------------------------------------------------------------------------------------
  --  name:     XXHZ_ACCOUNT_ADDR_SOA_V_TRG
  --  Description:     update view support for soa use used by soa
  ---------------------------------------------------------------------------------------
  --  Ver   When         Who             Descr
  --  ----  -----------  --------------  ------------------------------------------------
  --  1.0   26/03/2020   Roman W.        CHG0047450 - Account, Contact interface - ReDo
  ---------------------------------------------------------------------------------------
BEGIN

  IF :new.status = 'IN_PROCESS' AND NVL(:old.status, 'NEW') = 'NEW' THEN
  
    UPDATE XXSSYS_EVENTS t
       SET t.status = 'IN_PROCESS'
     WHERE t.event_id = nvl(:old.event_id, :new.event_id);
  
  END IF;

END;

--ALTER TRIGGER "APPS"."XXHZ_ACCOUNT_ADDR_SOA_V_TRG" ENABLE
/