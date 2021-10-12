CREATE OR REPLACE TRIGGER "APPS"."XXINV_ECO_LINES_TRG" 
  before insert or update on "XXOBJT"."XXINV_ECO_LINES"
  for each row
declare
  -- local variables here
  ln_user_id  NUMBER := fnd_global.USER_ID;
  ld_date     DATE := sysdate;
  ln_login_id NUMBER := fnd_global.LOGIN_ID;
begin
  ------------------------------------------------------------------
  -- Ver   When          Who         Descr
  -- ----  ------------  ----------  -------------------------------
  -- 1.0   05/10/2020    Roman W.    CHG0048470
  ------------------------------------------------------------------
  :new.ECO_LINE_ID       := nvl(:old.ECO_LINE_ID, XXINV_ECO_LINES_S.Nextval);
  :new.last_update_login := ln_login_id;
  :new.last_update_date  := ld_date;
  :new.last_updated_by   := ln_user_id;
  :new.created_by        := nvl(:old.created_by, ln_user_id);
  :new.creation_date     := nvl(:old.creation_date, ld_date);

end XXINV_ECO_LINES_TRG;

  ----ALTER TRIGGER "APPS"."XXINV_ECO_LINES_TRG" ENABLE

--ALTER TRIGGER "APPS"."XXINV_ECO_LINES_TRG" ENABLE
/