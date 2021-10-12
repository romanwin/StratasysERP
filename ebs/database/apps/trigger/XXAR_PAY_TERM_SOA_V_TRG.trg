CREATE OR REPLACE TRIGGER xxar_pay_term_soa_v_trg
  INSTEAD OF UPDATE ON xxar_pay_term_soa_v

  FOR EACH ROW
----------------------------------------------------------------------------------------------------------------
  --  name:             XXAR_PAY_TERM_SOA_V_TRG
  --  Description:      update view support for soa use
  --                    This Will be Get Called by SOA When SOA Will try to Update VIEW [XXAR_PAY_TERM_SOA_V]
  ----------------------------------------------------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   9.11.17       yuval tal       CHG0041763 - strataforce  project payment term  Interface initial build
  ----------------------------------------------------------------------------------------------------------------
BEGIN
  IF :new.status = 'IN_PROCESS' AND nvl(:old.status, 'NEW') = 'NEW' THEN
  
    UPDATE xxssys_events t
    SET    t.status = 'IN_PROCESS'
    WHERE  t.event_id = nvl(:old.event_id, :new.event_id);
  END IF;

END xxar_pay_term_soa_v_trg;
/
