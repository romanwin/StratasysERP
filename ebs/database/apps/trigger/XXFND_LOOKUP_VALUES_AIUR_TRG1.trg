CREATE OR REPLACE TRIGGER XXFND_LOOKUP_VALUES_AIUR_TRG1
--------------------------------------------------------------------------------------------------
--  name:              XXFND_LOOKUP_VALUES_AIUR_TRG1
--  create by:         Lingaraj Sarangi
--  Revision:          1.0
--  creation date:     12-Dec-2017
--------------------------------------------------------------------------------------------------
--  purpose :          CHG0035652  : Check and insert/update data into event table for Insert and Update
--                                   triggers on FND_LOOKUP_TYPES
--
--  Modification History
--------------------------------------------------------------------------------------------------
--  ver   date          Name                       Desc
--  1.0   12-Dec-2017   Lingaraj Sarangi           CHG0041829 - Strataforce Real Rime Product interface
--------------------------------------------------------------------------------------------------
AFTER INSERT OR UPDATE OR DELETE ON "APPLSYS"."FND_LOOKUP_VALUES"
FOR EACH ROW
when(
          Nvl(NEW.LOOKUP_TYPE,OLD.LOOKUP_TYPE) IN ( 'FREIGHT_TERMS', 'FOB' ) 
      And Nvl(NEW.language,OLD.language) = 'US'
     )
DECLARE
  l_trigger_name    VARCHAR2(50) := 'XXFND_LOOKUP_VALUES_AIUR_TRG1';
  l_error_message   VARCHAR2(2000);
  l_old_flv_rec     FND_LOOKUP_VALUES%rowtype;
  l_new_flv_rec     FND_LOOKUP_VALUES%rowtype;   
  l_trigger_ation   VARCHAR2(10);   
  l_lookup_type     VARCHAR2(100);
BEGIN
  l_error_message := '';                 
  
  IF INSERTING THEN
     l_trigger_ation := 'INSERT';
     l_lookup_type   := :NEW.LOOKUP_TYPE;
  ELSIF UPDATING THEN
     l_trigger_ation := 'UPDATE';
     l_lookup_type   := :NEW.LOOKUP_TYPE;
  ELSIF DELETING THEN      
     l_trigger_ation := 'DELETE';
     l_lookup_type   := :OLD.LOOKUP_TYPE;
  END IF;
          
  -----------------------------------------------------------
  -- Old Values After Update
  -----------------------------------------------------------
    l_old_flv_rec.LOOKUP_TYPE       := :OLD.LOOKUP_TYPE ;
    l_old_flv_rec.LANGUAGE          := :OLD.LANGUAGE;
    l_old_flv_rec.LOOKUP_CODE       := :OLD.LOOKUP_CODE;
    l_old_flv_rec.MEANING           := :OLD.MEANING;
    l_old_flv_rec.DESCRIPTION       := :OLD.DESCRIPTION;
    l_old_flv_rec.ENABLED_FLAG      := :OLD.ENABLED_FLAG;
    l_old_flv_rec.START_DATE_ACTIVE := :OLD.START_DATE_ACTIVE;
    l_old_flv_rec.END_DATE_ACTIVE   := :OLD.END_DATE_ACTIVE;
    l_old_flv_rec.CREATED_BY        := :OLD.CREATED_BY;
    l_old_flv_rec.CREATION_DATE     := :OLD.CREATION_DATE;
    l_old_flv_rec.LAST_UPDATED_BY   := :OLD.LAST_UPDATED_BY;
    l_old_flv_rec.TAG               := :OLD.TAG;
  -----------------------------------------------------------
  -- New Values After Update
  -----------------------------------------------------------
  --IF UPDATING THEN
    l_new_flv_rec.LOOKUP_TYPE       := :NEW.LOOKUP_TYPE ;
    l_new_flv_rec.LANGUAGE          := :NEW.LANGUAGE;
    l_new_flv_rec.LOOKUP_CODE       := :NEW.LOOKUP_CODE;
    l_new_flv_rec.MEANING           := :NEW.MEANING;
    l_new_flv_rec.DESCRIPTION       := :NEW.DESCRIPTION;
    l_new_flv_rec.ENABLED_FLAG      := :NEW.ENABLED_FLAG;
    l_new_flv_rec.START_DATE_ACTIVE := :NEW.START_DATE_ACTIVE;
    l_new_flv_rec.END_DATE_ACTIVE   := :NEW.END_DATE_ACTIVE;
    l_new_flv_rec.CREATED_BY        := :NEW.CREATED_BY;
    l_new_flv_rec.CREATION_DATE     := :NEW.CREATION_DATE;
    l_new_flv_rec.LAST_UPDATED_BY   := :NEW.LAST_UPDATED_BY;
    l_new_flv_rec.TAG               := :NEW.TAG;
  --END IF;  
  -----------------------------------------------------------
   
  --Call Trigger Event Processor
  xxssys_strataforce_events_pkg.flv_common_trg_processor(p_old_flv_rec    => l_old_flv_rec,
                                                         p_new_flv_rec    => l_new_flv_rec, 
                                                         p_trigger_name   => l_trigger_name,
                                                         p_lookup_type    => l_lookup_type,
                                                         p_trigger_action => l_trigger_ation                                                  
                                                         ); 

EXCEPTION
WHEN OTHERS THEN
  l_error_message := substrb(sqlerrm,1,500);
  RAISE_APPLICATION_ERROR(-20999,l_error_message);                                                        
END XXFND_LOOKUP_VALUES_AIUR_TRG1;
/
