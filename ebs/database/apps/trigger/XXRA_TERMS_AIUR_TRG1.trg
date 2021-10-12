CREATE OR REPLACE TRIGGER XXRA_TERMS_AIUR_TRG1
--------------------------------------------------------------------------------------------------
--  name:              XXRA_TERMS_AIUR_TRG1
--  create by:         Lingaraj Sarangi
--  Revision:          1.0
--  creation date:     12-Dec-2017
--------------------------------------------------------------------------------------------------
--  purpose :          CHG0035652  : Check and insert/update data into event table for Insert and Update
--                                   triggers on QP_LIST_HEADERS_B
--                     When we are Changing the PRICE LST Name or Description also the  QP_LIST_HEADERS_B Table Get Updated.
--  Modification History
--------------------------------------------------------------------------------------------------
--  ver   date          Name                       Desc
--  1.0   12-Dec-2017   Lingaraj Sarangi           CHG0041829 - Strataforce Real Rime Product interface
--------------------------------------------------------------------------------------------------
AFTER INSERT OR UPDATE  ON "AR"."RA_TERMS_B"
FOR EACH ROW

when(1 = 1 )
DECLARE

  l_trigger_name    VARCHAR2(50) := 'XXRA_TERMS_AIUR_TRG1';
  l_error_message   VARCHAR2(2000);
  l_old_PL_rec      QP.QP_LIST_HEADERS_B%rowtype;
  l_new_PL_rec      QP.QP_LIST_HEADERS_B%rowtype;
  l_trigger_action   VARCHAR2(10) := '#';
  l_PriceEntry_action VARCHAR2(10):= '#';
  l_xxssys_event_rec xxssys_events%ROWTYPE;
BEGIN

  IF INSERTING THEN
     l_trigger_action := 'INSERT';
  ELSIF UPDATING THEN
     l_trigger_action := 'UPDATE';   
  END IF;

  --Call Trigger Event Processor
  xxssys_strataforce_events_pkg.payterm_trg_processor(p_term_id         => :NEW.TERM_ID,
                                                      p_start_date      => :NEW.start_date_active,
                                                      p_end_date        => :NEW.end_date_active,
                                                      p_created_by      => :NEW.Created_By,
                                                      p_last_updated_by => :NEW.last_updated_by,
                                                      p_trigger_name   => l_trigger_name,
                                                      p_trigger_action => l_trigger_action
                                                      );
EXCEPTION
WHEN OTHERS THEN
  l_error_message := substrb(sqlerrm,1,500);
  RAISE_APPLICATION_ERROR(-20999,l_error_message);
END XXRA_TERMS_AIUR_TRG1;
/
