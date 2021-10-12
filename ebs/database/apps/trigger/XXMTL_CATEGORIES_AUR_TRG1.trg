CREATE OR REPLACE TRIGGER XXMTL_CATEGORIES_AUR_TRG1
  --------------------------------------------------------------------------------------------------
  --  name:              XXMTL_CATEGORIES_AUR_TRG1
  --  create by:         Lingaraj Sarangi
  --  Revision:          1.0
  --  creation date:     12-Dec-2017
  --------------------------------------------------------------------------------------------------
  --  purpose :          CHG0035652  : Check and insert/update data into event table for Insert and Update
  --                                   triggers on QP_LIST_HEADERS_B
  --
  --  Modification History
  --------------------------------------------------------------------------------------------------
  --  ver   date          Name                       Desc
  --  1.0   12-Dec-2017   Lingaraj Sarangi           CHG0041829 - Strataforce Real Rime Product interface
  --------------------------------------------------------------------------------------------------

  BEFORE UPDATE on "INV"."MTL_CATEGORIES_B"
  for each row


when( 1 =  1 )
DECLARE
  l_trigger_name    VARCHAR2(30) := 'XXMTL_CATEGORIES_AUR_TRG1';
  l_error_message   VARCHAR2(500);
  l_trigger_action  VARCHAR2(10) := '';

  l_old_cat_rec     MTL_CATEGORIES_B%ROWTYPE;
  l_new_cat_rec     MTL_CATEGORIES_B%ROWTYPE;

BEGIN

  l_error_message := '';

  IF inserting THEN
    l_trigger_action := 'INSERT';
  ELSIF updating THEN
    l_trigger_action := 'UPDATE';
  ELSIF deleting THEN
    l_trigger_action := 'DELETE';
  END IF;

  IF UPDATING OR DELETING THEN
      l_old_cat_rec.CATEGORY_ID        := :OLD.CATEGORY_ID;
      l_old_cat_rec.STRUCTURE_ID       := :OLD.STRUCTURE_ID;
      l_old_cat_rec.ENABLED_FLAG       := :OLD.ENABLED_FLAG;
      l_old_cat_rec.ATTRIBUTE_CATEGORY := :OLD.ATTRIBUTE_CATEGORY;
      l_old_cat_rec.ATTRIBUTE1         := :OLD.ATTRIBUTE1;
      l_old_cat_rec.ATTRIBUTE2         := :OLD.ATTRIBUTE2;
      l_old_cat_rec.ATTRIBUTE3         := :OLD.ATTRIBUTE3;
      l_old_cat_rec.ATTRIBUTE4         := :OLD.ATTRIBUTE4;
      l_old_cat_rec.ATTRIBUTE5         := :OLD.ATTRIBUTE5;
      l_old_cat_rec.ATTRIBUTE6         := :OLD.ATTRIBUTE6;
      l_old_cat_rec.ATTRIBUTE7         := :OLD.ATTRIBUTE7;
      l_old_cat_rec.ATTRIBUTE8         := :OLD.ATTRIBUTE8;
      l_old_cat_rec.ATTRIBUTE9         := :OLD.ATTRIBUTE9;
      l_old_cat_rec.ATTRIBUTE10        := :OLD.ATTRIBUTE10;
      l_old_cat_rec.ATTRIBUTE11        := :OLD.ATTRIBUTE11;
      l_old_cat_rec.ATTRIBUTE12        := :OLD.ATTRIBUTE12;
      l_old_cat_rec.ATTRIBUTE13        := :OLD.ATTRIBUTE13;
      l_old_cat_rec.ATTRIBUTE14        := :OLD.ATTRIBUTE14;
      l_old_cat_rec.ATTRIBUTE15        := :OLD.ATTRIBUTE15;
      l_old_cat_rec.LAST_UPDATE_DATE   := :OLD.LAST_UPDATE_DATE;
      l_old_cat_rec.CREATION_DATE      := :OLD.CREATION_DATE;
  END IF;

   IF INSERTING OR UPDATING THEN
      l_new_cat_rec.CATEGORY_ID        := :NEW.CATEGORY_ID;
      l_new_cat_rec.STRUCTURE_ID       := :NEW.STRUCTURE_ID;
      l_new_cat_rec.ENABLED_FLAG       := :NEW.ENABLED_FLAG;
      l_new_cat_rec.ATTRIBUTE_CATEGORY := :NEW.ATTRIBUTE_CATEGORY;
      l_new_cat_rec.ATTRIBUTE1         := :NEW.ATTRIBUTE1;
      l_new_cat_rec.ATTRIBUTE2         := :NEW.ATTRIBUTE2;
      l_new_cat_rec.ATTRIBUTE3         := :NEW.ATTRIBUTE3;
      l_new_cat_rec.ATTRIBUTE4         := :NEW.ATTRIBUTE4;
      l_new_cat_rec.ATTRIBUTE5         := :NEW.ATTRIBUTE5;
      l_new_cat_rec.ATTRIBUTE6         := :NEW.ATTRIBUTE6;
      l_new_cat_rec.ATTRIBUTE7         := :NEW.ATTRIBUTE7;
      l_new_cat_rec.ATTRIBUTE8         := :NEW.ATTRIBUTE8;
      l_new_cat_rec.ATTRIBUTE9         := :NEW.ATTRIBUTE9;
      l_new_cat_rec.ATTRIBUTE10        := :NEW.ATTRIBUTE10;
      l_new_cat_rec.ATTRIBUTE11        := :NEW.ATTRIBUTE11;
      l_new_cat_rec.ATTRIBUTE12        := :NEW.ATTRIBUTE12;
      l_new_cat_rec.ATTRIBUTE13        := :NEW.ATTRIBUTE13;
      l_new_cat_rec.ATTRIBUTE14        := :NEW.ATTRIBUTE14;
      l_new_cat_rec.ATTRIBUTE15        := :NEW.ATTRIBUTE15;
      l_new_cat_rec.LAST_UPDATE_DATE   := :NEW.LAST_UPDATE_DATE;
      l_new_cat_rec.CREATION_DATE      := :NEW.CREATION_DATE;
  END IF;

  xxssys_strataforce_events_pkg.mtl_cat_trg_processor(p_old_cat_rec       => l_old_cat_rec,
                                                      p_new_cat_rec       => l_new_cat_rec,
                                                      p_trigger_name      => l_trigger_name,
                                                      p_trigger_action    => l_trigger_action
                                                     );

EXCEPTION
  WHEN OTHERS THEN
    l_error_message := substrb(SQLERRM, 1, 500);
    raise_application_error(-20999, l_error_message);
END XXMTL_CATEGORIES_AUR_TRG1;
/
