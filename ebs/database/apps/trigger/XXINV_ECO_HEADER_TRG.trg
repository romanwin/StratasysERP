CREATE OR REPLACE TRIGGER "APPS"."XXINV_ECO_HEADER_TRG" 
  before insert or update on "XXOBJT"."XXINV_ECO_HEADER"
  for each row
declare
  -- local variables here
  ln_user_id  NUMBER := fnd_global.USER_ID;
  ld_date     DATE := sysdate;
  ln_login_id NUMBER := fnd_global.LOGIN_ID;
begin

  :new.eco_header_id     := nvl(:old.eco_header_id,
                                XXINV_ECO_HEADER_S.Nextval);
  :new.last_update_login := ln_login_id;
  :new.last_update_date  := ld_date;
  :new.last_updated_by   := ln_user_id;
  :new.created_by        := nvl(:old.created_by, ln_user_id);
  :new.creation_date     := nvl(:old.creation_date, ld_date);

end XXINV_ECO_HEADER_TRG;

--ALTER TRIGGER "APPS"."XXINV_ECO_HEADER_TRG" ENABLE
/