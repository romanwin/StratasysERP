CREATE OR REPLACE TRIGGER xxobjt_fnd_profile_val_bar_trg
BEFORE INSERT OR UPDATE OF profile_option_value OR DELETE ON FND_PROFILE_OPTION_VALUES
FOR EACH ROW
DECLARE
  l_audit_transaction_type varchar2(10);
  l_audit_user_name        varchar2(500);
  l_level_id               number;
  l_level_value            number;
  l_profile_option_id      number;
  l_new_profile_value      varchar2(240);
  l_old_profile_value      varchar2(240);
  l_user_id                number;
  l_application_id         number;

BEGIN

  l_audit_user_name        := fnd_global.USER_name;
  l_user_id                := fnd_global.user_id; 

  CASE
    WHEN INSERTING THEN
      -- Include any code specific for when the trigger is fired from an INSERT.
      l_audit_transaction_type := 'INS';
      l_level_id               := :NEW.level_id;
      l_level_value            := :NEW.level_value;
      l_profile_option_id      := :NEW.profile_option_id;
      l_new_profile_value      := :NEW.profile_option_value;
      l_old_profile_value      := null;
      l_application_id         := :NEW.application_id;

    WHEN UPDATING THEN
      l_audit_transaction_type := 'UPD';
      l_level_id               := :NEW.level_id;
      l_level_value            := :NEW.level_value;
      l_profile_option_id      := :NEW.profile_option_id;
      l_new_profile_value      := :NEW.profile_option_value;
      l_old_profile_value      := :OLD.profile_option_value;
      l_application_id         := :NEW.application_id;
    WHEN DELETING THEN
      l_audit_transaction_type := 'DEL';
      l_level_id               := :OLD.level_id;
      l_level_value            := :OLD.level_value;
      l_profile_option_id      := :OLD.profile_option_id;
      l_new_profile_value      := null;
      l_old_profile_value      := :OLD.profile_option_value;
      l_application_id         := :OLD.application_id;
  END CASE;

  insert into XXOBJT_FND_PROFILE_VAL_AUDIT( audit_timestamp,
                                            audit_transaction_type,
                                            audit_user_name,
                                            level_id,
                                            level_value, 
                                            profile_option_id,
                                            new_profile_option_value,
                                            old_profile_option_value,
                                            application_id,
                                            last_updated_by,
                                            last_update_date,
                                            created_by,
                                            creation_date,
                                            last_update_login
                                          )
                                   values(  sysdate,
                                            l_audit_transaction_type,
                                            l_audit_user_name,
                                            l_level_id,
                                            l_level_value,
                                            l_profile_option_id,
                                            l_new_profile_value,
                                            l_old_profile_value,
                                            l_application_id,
                                            l_user_id,
                                            sysdate,
                                            l_user_id,
                                            sysdate,
                                            -1
                                          );

exception
  when others then
    null;
END;
/
