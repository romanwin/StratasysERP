CREATE OR REPLACE TRIGGER XXQP_LIST_HEADERS_TL_AIUR_TRG1
--------------------------------------------------------------------------------------------------
--  name:              XXQP_LIST_HEADERS_TL_AIUR_TRG1
--  create by:         Lingaraj Sarangi
--  Revision:          1.0
--  creation date:     12-Dec-2017
--------------------------------------------------------------------------------------------------
--  purpose :          CHG0035652  : Check and insert/update data into event table for Insert and Update
--                                   triggers on QP_LIST_HEADERS_TL
--                     When we are Changing the PRICE LST Name or Dscription also the  QP_LIST_HEADERS_B Table Get Updated.
--  Modification History
--------------------------------------------------------------------------------------------------
--  ver   date          Name                       Desc
--  1.0   12-Dec-2017   Lingaraj Sarangi           CHG0041829 - Strataforce Real Rime Product interface
--------------------------------------------------------------------------------------------------
AFTER INSERT OR UPDATE ON "QP"."QP_LIST_HEADERS_TL"
FOR EACH ROW

when( NEW.language = 'US' AND
       (
          (NEW.name <> OLD.name) OR
          (NEW.description <> OLD.description)
         )
       )
DECLARE
  l_trigger_name    VARCHAR2(50) := 'XXQP_LIST_HEADERS_TL_AIUR_TRG1';
  l_error_message   VARCHAR2(500);
  l_trigger_action  VARCHAR2(10) := '';
BEGIN
  l_error_message := '';
  
  IF INSERTING THEN
     l_trigger_action := 'INSERT';
  ELSIF UPDATING THEN
     l_trigger_action := 'UPDATE';
  ELSIF DELETING THEN
     l_trigger_action := 'DELETE';
  END IF;

  --Call Trigger Event Processor
  xxssys_strataforce_events_pkg.pricebook_TL_trg_processor(p_list_header_id  => :NEW.list_header_id,
                                                           p_created_by      => :NEW.created_by,
                                                           p_last_updated_by => :NEW.last_updated_by,
                                                           p_trigger_name    => l_trigger_name,
                                                           p_trigger_action  => l_trigger_action
                                                          );


Exception
WHEN OTHERS THEN
  l_error_message := substrb(sqlerrm,1,500);
  RAISE_APPLICATION_ERROR(-20999,l_error_message);
END XXQP_LIST_HEADERS_TL_AIUR_TRG1;
/
