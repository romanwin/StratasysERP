CREATE OR REPLACE TRIGGER xxokc_srv_contarct_soa_v_trg
  INSTEAD OF UPDATE ON xxokc_srv_contarct_soa_v

  FOR EACH ROW
--------------------------------------------------------------------
  --  name:     XXOKC_SRV_CONTARCT_SOA_V_TRG
  --  Description:     Any Service Contract line that its status change should be interface to salesforce
  --                    except status ?Entered? and ?Hold?.
  --                  used by SOA
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   03.May.18     Lingaraj       CHG0042873 - Service Contract interface - Oracle 2 SFDC
  --------------------------------------------------------------------
BEGIN
  IF :new.status = 'IN_PROCESS' AND nvl(:old.status, 'NEW') = 'NEW' THEN
  
    UPDATE xxssys_events t
    SET    t.status = 'IN_PROCESS'
    WHERE  t.event_id = nvl(:old.event_id, :new.event_id);
  END IF;

END xxokc_srv_contarct_soa_v_trg;
/
