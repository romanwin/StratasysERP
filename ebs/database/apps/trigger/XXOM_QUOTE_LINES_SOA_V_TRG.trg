CREATE OR REPLACE TRIGGER XXOM_QUOTE_LINES_SOA_V_TRG
  INSTEAD OF UPDATE ON XXOM_QUOTE_LINES_SOA_V
  FOR EACH ROW
--------------------------------------------------------------------
--  name:     XXOM_QUOTE_LINES_SOA_V_TRG
--  Description:
--                   used by soa
--------------------------------------------------------------------
--  ver   date          name            desc
--1.0    21.1.18        yuval tal       CHG0042204 - Quote expiration on discontinued items
--------------------------------------------------------------------
BEGIN
  IF :new.status = 'IN_PROCESS' AND nvl(:old.status, 'NEW') = 'NEW' THEN

    UPDATE XXSSYS_EVENTS t
    SET    t.status = 'IN_PROCESS'
    WHERE  t.event_id =
           nvl(:old.event_id, :new.event_id);
  END IF;

end XXOM_QUOTE_LINES_SOA_V_TRG;
/
