CREATE OR REPLACE TRIGGER XXOKC_K_ITEMS_AIU_TRG
--------------------------------------------------------------------------------------------------
--  name:              XXOKC_K_ITEMS_AIU_TRG
--  create by:         Lingaraj Sarangi
--  Revision:          1.0
--  creation date:     10-May-2018
--------------------------------------------------------------------------------------------------
--  purpose :          CHG0042873 - Service Contract interface - Oracle 2 SFDC
--                                   trigger on OKC_K_ITEMS
--
--  Modification History
--------------------------------------------------------------------------------------------------
--  ver   date          Name                       Desc
--  1.0   10-May-2018   Lingaraj Sarangi           CHG0042873 - Service Contract interface - Oracle 2 SFDC
--------------------------------------------------------------------------------------------------
AFTER INSERT OR UPDATE  ON "OKC"."OKC_K_ITEMS"
FOR EACH ROW

when(1=1)
DECLARE
  l_trigger_name    VARCHAR2(50)   := 'XXOKC_K_ITEMS_AIU_TRG';
  l_error_message   VARCHAR2(500)  := '';
  l_old_okc_item_rec   okc.okc_k_items%ROWTYPE;
  l_new_okc_item_rec   okc.okc_k_items%ROWTYPE;
  l_trigger_action  VARCHAR2(10) := '';
BEGIN

  IF INSERTING THEN
     l_trigger_action := 'INSERT';
  ELSIF UPDATING THEN
     l_trigger_action := 'UPDATE';
  END IF;

  -----------------------------------------------------------
  -- Old Column Values Before Update
  -----------------------------------------------------------
  IF UPDATING THEN
      l_old_okc_item_rec.id                        := :OLD.ID;
      l_old_okc_item_rec.cle_id                    := :OLD.CLE_ID;
      l_old_okc_item_rec.chr_id                    := :OLD.CHR_ID;
      l_old_okc_item_rec.cle_id_for                := :OLD.CLE_ID_FOR;
      l_old_okc_item_rec.dnz_chr_id                := :OLD.DNZ_CHR_ID;
      l_old_okc_item_rec.object1_id1               := :OLD.OBJECT1_ID1;
      l_old_okc_item_rec.object1_id2               := :OLD.OBJECT1_ID2;
      l_old_okc_item_rec.jtot_object1_code         := :OLD.JTOT_OBJECT1_CODE;
      l_old_okc_item_rec.uom_code                  := :OLD.UOM_CODE;
      l_old_okc_item_rec.exception_yn              := :OLD.EXCEPTION_YN;
      l_old_okc_item_rec.number_of_items           := :OLD.NUMBER_OF_ITEMS;
      l_old_okc_item_rec.priced_item_yn            := :OLD.PRICED_ITEM_YN;
      l_old_okc_item_rec.object_version_number     := :OLD.OBJECT_VERSION_NUMBER;
      l_old_okc_item_rec.created_by                := :OLD.CREATED_BY;
      l_old_okc_item_rec.creation_date             := :OLD.CREATION_DATE;
      l_old_okc_item_rec.last_updated_by           := :OLD.LAST_UPDATED_BY;
      l_old_okc_item_rec.last_update_date          := :OLD.LAST_UPDATE_DATE;
      l_old_okc_item_rec.last_update_login         := :OLD.LAST_UPDATE_LOGIN;
      l_old_okc_item_rec.security_group_id         := :OLD.SECURITY_GROUP_ID;
      l_old_okc_item_rec.upg_orig_system_ref       := :OLD.UPG_ORIG_SYSTEM_REF;
      l_old_okc_item_rec.upg_orig_system_ref_id    := :OLD.UPG_ORIG_SYSTEM_REF_ID;
      l_old_okc_item_rec.program_application_id    := :OLD.PROGRAM_APPLICATION_ID;
      l_old_okc_item_rec.program_id                := :OLD.PROGRAM_ID;
      l_old_okc_item_rec.program_update_date       := :OLD.PROGRAM_UPDATE_DATE;
      l_old_okc_item_rec.request_id                := :OLD.REQUEST_ID;
  END IF;
  -----------------------------------------------------------
  -- New Column Values After Update
  -----------------------------------------------------------
  IF INSERTING OR UPDATING THEN
      l_new_okc_item_rec.id                        := :NEW.ID;
      l_new_okc_item_rec.cle_id                    := :NEW.CLE_ID;
      l_new_okc_item_rec.chr_id                    := :NEW.CHR_ID;
      l_new_okc_item_rec.cle_id_for                := :NEW.CLE_ID_FOR;
      l_new_okc_item_rec.dnz_chr_id                := :NEW.DNZ_CHR_ID;
      l_new_okc_item_rec.object1_id1               := :NEW.OBJECT1_ID1;
      l_new_okc_item_rec.object1_id2               := :NEW.OBJECT1_ID2;
      l_new_okc_item_rec.jtot_object1_code         := :NEW.JTOT_OBJECT1_CODE;
      l_new_okc_item_rec.uom_code                  := :NEW.UOM_CODE;
      l_new_okc_item_rec.exception_yn              := :NEW.EXCEPTION_YN;
      l_new_okc_item_rec.number_of_items           := :NEW.NUMBER_OF_ITEMS;
      l_new_okc_item_rec.priced_item_yn            := :NEW.PRICED_ITEM_YN;
      l_new_okc_item_rec.object_version_number     := :NEW.OBJECT_VERSION_NUMBER;
      l_new_okc_item_rec.created_by                := :NEW.CREATED_BY;
      l_new_okc_item_rec.creation_date             := :NEW.CREATION_DATE;
      l_new_okc_item_rec.last_updated_by           := :NEW.LAST_UPDATED_BY;
      l_new_okc_item_rec.last_update_date          := :NEW.LAST_UPDATE_DATE;
      l_new_okc_item_rec.last_update_login         := :NEW.LAST_UPDATE_LOGIN;
      l_new_okc_item_rec.security_group_id         := :NEW.SECURITY_GROUP_ID;
      l_new_okc_item_rec.upg_orig_system_ref       := :NEW.UPG_ORIG_SYSTEM_REF;
      l_new_okc_item_rec.upg_orig_system_ref_id    := :NEW.UPG_ORIG_SYSTEM_REF_ID;
      l_new_okc_item_rec.program_application_id    := :NEW.PROGRAM_APPLICATION_ID;
      l_new_okc_item_rec.program_id                := :NEW.PROGRAM_ID;
      l_new_okc_item_rec.program_update_date       := :NEW.PROGRAM_UPDATE_DATE;
      l_new_okc_item_rec.request_id                := :NEW.REQUEST_ID;
  END IF;


  --Call Trigger Event Processor
  xxssys_strataforce_events_pkg.okc_item_trg_processor(p_old_okc_item_rec     => l_old_okc_item_rec,
                                                       p_new_okc_item_rec     => l_new_okc_item_rec,
                                                       p_trigger_name         => l_trigger_name,
                                                       p_trigger_action       => l_trigger_action
                                                       );




Exception
WHEN OTHERS THEN
  l_error_message := substrb(sqlerrm,1,500);
  RAISE_APPLICATION_ERROR(-20999,l_error_message);
END XXOKC_K_ITEMS_AIU_TRG;
/