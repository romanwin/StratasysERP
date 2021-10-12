CREATE OR REPLACE TRIGGER XXQP_LIST_HEADERS_AIUR_TRG1
--------------------------------------------------------------------------------------------------
--  name:              XXQP_LIST_HEADERS_AIUR_TRG1
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
AFTER INSERT OR UPDATE  ON "QP"."QP_LIST_HEADERS_B"
FOR EACH ROW

when(NEW.LIST_TYPE_CODE = 'PRL')
DECLARE
  l_trigger_name    VARCHAR2(50)   := 'XXQP_LIST_HEADERS_AIUR_TRG1';
  l_error_message   VARCHAR2(500) := '';
  l_old_PL_rec      QP.QP_LIST_HEADERS_B%rowtype;
  l_new_PL_rec      QP.QP_LIST_HEADERS_B%rowtype;
  l_trigger_action  VARCHAR2(10) := '';
  --l_PriceEntry_action VARCHAR2(10):= '';
  --l_xxssys_event_rec xxssys_events%ROWTYPE;
BEGIN
 
  IF INSERTING THEN
     l_trigger_action := 'INSERT';
     --If the Price Book Created with active flag as No Or Transfer To SF as No, no need to Create any Event
     If NVL(:NEW.active_flag,'N') <> 'Y' OR (NVL(:NEW.attribute6,'N')) = 'N' Then
       Return;
     End If;
  ELSIF UPDATING THEN
     l_trigger_action := 'UPDATE';
  ELSIF DELETING THEN
     l_trigger_action := 'DELETE';
  END IF;

  -----------------------------------------------------------
  -- Old Values After Update
  -----------------------------------------------------------
  IF UPDATING OR DELETING THEN

    l_old_PL_rec.list_header_id   := :OLD.list_header_id ;
    l_old_PL_rec.currency_code    := :OLD.currency_code ;
    l_old_PL_rec.active_flag      := :OLD.active_flag;    
    l_old_PL_rec.global_flag      := :OLD.global_flag ;
    l_old_PL_rec.orig_org_id      := :OLD.orig_org_id ;
    l_old_PL_rec.last_update_date := :OLD.last_update_date ;
    l_old_PL_rec.last_updated_by  := :OLD.last_updated_by ;
    l_old_PL_rec.created_by       := :OLD.created_by ;

    l_old_PL_rec.attribute3        := :OLD.attribute3 ; --Usage
    l_old_PL_rec.attribute6        := :OLD.attribute6 ; --Transfer to SF?    
    l_old_PL_rec.ATTRIBUTE10       := :OLD.ATTRIBUTE10 ; --GAM price list
    l_old_PL_rec.attribute11       := :OLD.attribute11 ; -- Direct PL
    l_old_PL_rec.attribute12       := :OLD.attribute12 ; --Pre-Commision enabled
    l_old_PL_rec.attribute14       := :OLD.attribute14  ; --Direct\Indirect

  END IF;
   -----------------------------------------------------------
  -- New Values After Update
  -----------------------------------------------------------
  IF INSERTING OR UPDATING THEN
    l_new_PL_rec.list_header_id   := :NEW.list_header_id ;
    l_new_PL_rec.currency_code    := :NEW.currency_code ;
    l_new_PL_rec.active_flag      := :NEW.active_flag;   
    l_new_PL_rec.global_flag      := :NEW.global_flag ;
    l_new_PL_rec.orig_org_id      := :NEW.orig_org_id ;
    l_new_PL_rec.last_update_date := :NEW.last_update_date ;
    l_new_PL_rec.last_updated_by  := :NEW.last_updated_by ;
    l_new_PL_rec.created_by       := :NEW.created_by ;

    l_new_PL_rec.attribute3        := :NEW.attribute3 ; --Usage
    l_new_PL_rec.attribute6        := :NEW.attribute6; --Transfer to SF?    
    l_new_PL_rec.ATTRIBUTE10       := :NEW.ATTRIBUTE10 ; --GAM price list
    l_new_PL_rec.attribute11       := :NEW.attribute11 ; -- Direct PL
    l_new_PL_rec.attribute12       := :NEW.attribute12 ; --Pre-Commision enabled
    l_new_PL_rec.attribute14       := :NEW.attribute14 ; --Direct\Indirect
  END IF;

  
  --Call Trigger Event Processor
  xxssys_strataforce_events_pkg.pricebook_trg_processor(p_old_PL_rec     => l_old_PL_rec,
                                                        p_new_PL_rec     => l_new_PL_rec,
                                                        p_trigger_name   => l_trigger_name,
                                                        p_trigger_action => l_trigger_action
                                                        );




Exception
WHEN OTHERS THEN
  l_error_message := substrb(sqlerrm,1,500);  
  RAISE_APPLICATION_ERROR(-20999,l_error_message);
END XXQP_LIST_HEADERS_AIUR_TRG1;
/
