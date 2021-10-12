CREATE OR REPLACE TRIGGER "XXIBY_CC_DEBUG_TBL_TRG"
  before insert or update on "XXOBJT"."XXIBY_CC_DEBUG_TBL"
  for each row
declare
  l_sysdate DATE;
  l_user_id NUMBER;
  l_login   NUMBER;

begin
  -----------------------------------------------------------------
  -- Ver  When         Who         Descr
  -- ---- -----------  ----------  --------------------------------
  -- 1.0  07/04/2021   Roman W.    CHG0049588
  -----------------------------------------------------------------
  l_sysdate := SYSDATE;
  l_user_id := fnd_global.USER_ID;
  l_login   := fnd_global.LOGIN_ID;

  if :NEW.ROW_ID is NULL then
    :NEW.Row_Id := XXIBY_CC_DEBUG_TBL_S.nextval;
  end if;

  IF INSERTING THEN
    :NEW.CREATION_DATE := l_sysdate;
    :NEW.CREATED_BY    := l_user_id;
  END IF;

  :NEW.LAST_UPDATE_DATE  := l_sysdate;
  :NEW.LAST_UPDATED_BY   := l_user_id;
  :NEW.LAST_UPDATE_LOGIN := l_login;

end XXIBY_CC_DEBUG_TBL_TRG;
--ALTER TRIGGER "APPS"."XXIBY_CC_DEBUG_TBL_TRG" ENABLE
/
