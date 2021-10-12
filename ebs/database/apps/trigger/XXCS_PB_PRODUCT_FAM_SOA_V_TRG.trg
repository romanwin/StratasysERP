CREATE OR REPLACE TRIGGER  XXCS_PB_PRODUCT_FAM_SOA_V_TRG
  INSTEAD OF UPDATE ON XXCS_PB_PRODUCT_FAMILY_SOA_V

  FOR EACH ROW
--------------------------------------------------------------------
--  name:     XXCS_PB_PRODUCT_FAM_SOA_V_TRG   
--  Description:    XXCS_PB_PRODUCT_FAMILY value set interface list for CPQ system 
--                  used by soa     
--------------------------------------------------------------------
--  ver   date          name            desc
--  1.0   04.12.18      Diptasurjya     CHG0042706 - strataforce  project XXCS_PB_PRODUCT_FAMILY value set Interface initial build
--------------------------------------------------------------------
BEGIN
  IF :new.status = 'IN_PROCESS' AND nvl(:old.status, 'NEW') = 'NEW' THEN

    UPDATE XXSSYS_EVENTS t
    SET    t.status = 'IN_PROCESS' 
    WHERE  t.event_id =
           nvl(:old.event_id, :new.event_id);
  END IF;

end XXCS_PB_PRODUCT_FAM_SOA_V_TRG;
/
