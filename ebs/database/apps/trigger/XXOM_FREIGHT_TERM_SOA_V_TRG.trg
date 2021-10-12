CREATE OR REPLACE TRIGGER XXOM_FREIGHT_TERM_SOA_V_TRG
  INSTEAD OF UPDATE ON XXOM_FREIGHT_TERM_SOA_V

  FOR EACH ROW
--------------------------------------------------------------------
--  name:     XXOM_FREIGHT_TERM_SOA_V_TRG    
--  Description:     freight interface list for strataforce system 
--                  used by soa     
--------------------------------------------------------------------
--  ver   date          name            desc
--  1.0   9.11.17       yuval tal       CHG0041765 - strataforce  project freight term  Interface initial build
--------------------------------------------------------------------
BEGIN
  IF :new.status = 'IN_PROCESS' AND nvl(:old.status, 'NEW') = 'NEW' THEN

    UPDATE XXSSYS_EVENTS t
    SET    t.status = 'IN_PROCESS' 
    WHERE  t.event_id =
           nvl(:old.event_id, :new.event_id);
  END IF;

end XXOM_FREIGHT_TERM_SOA_V_TRG;
/
