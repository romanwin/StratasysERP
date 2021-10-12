CREATE OR REPLACE TRIGGER XXRA_TERMS_TL_AIUR_TRG1
--------------------------------------------------------------------------------------------------
--  name:              XXRA_TERMS_TL_AIUR_TRG1
--  create by:         Lingaraj Sarangi
--  Revision:          1.0
--  creation date:     22-Jun-2018
--------------------------------------------------------------------------------------------------
--  purpose :          CHG0041763  : Whenever there is an insert / Update on Table "RA_TERMS_TL"
--                                   new event need to Execute.
--
--  Modification History
--------------------------------------------------------------------------------------------------
--  ver   date          Name                       Desc
--  1.0   22-Jun-2018   Lingaraj Sarangi           CHG0041763 - Create Interface for Payment Terms object
--------------------------------------------------------------------------------------------------
AFTER INSERT OR UPDATE  ON "AR"."RA_TERMS_TL"
FOR EACH ROW

when(1 = 1 )
DECLARE

  l_trigger_name    VARCHAR2(50) := 'XXRA_TERMS_TL_AIUR_TRG1';
  l_error_message   VARCHAR2(2000);
  l_trigger_action   VARCHAR2(10) := '#';
  l_xxssys_event_rec xxssys_events%ROWTYPE;
BEGIN

  IF INSERTING THEN
     l_trigger_action := 'INSERT';
  ELSIF UPDATING THEN
     l_trigger_action := 'UPDATE';
  END IF;

  --Call Trigger Event Processor
  xxssys_strataforce_events_pkg.payterm_trg_processor(p_term_id         => :NEW.TERM_ID,
                                                      p_term_name       => :NEW.NAME,
                                                      p_start_date      => NULL,
                                                      p_end_date        => NULL,
                                                      p_created_by      => :NEW.Created_By,
                                                      p_last_updated_by => :NEW.last_updated_by,
                                                      p_trigger_name   => l_trigger_name,
                                                      p_trigger_action => l_trigger_action
                                                      );
EXCEPTION
WHEN OTHERS THEN
  l_error_message := substrb(sqlerrm,1,500);
  RAISE_APPLICATION_ERROR(-20999,l_error_message);
END XXRA_TERMS_TL_AIUR_TRG1;
/
