create or replace trigger XXFND_VSET_VALUE_OIC_TRG3

  -----------------------------------------------------------------------
  -- Ver    When          Who         Descr
  -- -----  ------------  ----------  -----------------------------------
  -- 1.0    08/12/2020    Roman W.    CHG0048579 - OIC
  -----------------------------------------------------------------------
  before insert or update OF ATTRIBUTE3, ATTRIBUTE5 on FND_FLEX_VALUES
  for each row
declare
  -- local variables here
  l_flex_value_set_id   FND_FLEX_VALUE_SETS.FLEX_VALUE_SET_ID%TYPE;
  l_flex_value_set_name FND_FLEX_VALUE_SETS.FLEX_VALUE_SET_NAME%TYPE;
  result                BOOLEAN;
  l_request_id          NUMBER;
  l_attribute3          VARCHAR2(240);
  l_attribute5          VARCHAR2(240);
  ------------------------------------------------------
  -- Ver    When          Who         Descr
  -- -----  ------------  ----------  ------------------
  -- 1.0    08/12/2020    Roman W.    CHG0048579 - OIC
  ------------------------------------------------------
  procedure message(p_str VARCHAR2) is
  begin
    dbms_output.put_line(p_str);
  end message;
begin

  l_flex_value_set_id := nvl(:NEW.FLEX_VALUE_SET_ID, :OLD.FLEX_VALUE_SET_ID);

  select ffvs.flex_value_set_name
    into l_flex_value_set_name
    from FND_FLEX_VALUE_SETS ffvs
   where ffvs.flex_value_set_id = l_flex_value_set_id;

  if 'XXSSYS_OIC_ENDPOINT' = l_flex_value_set_name then

    if :NEW.ATTRIBUTE3 != :OLD.ATTRIBUTE3 and :NEW.ATTRIBUTE3 IS NOT NULL THEN

      l_attribute3    := :NEW.ATTRIBUTE3;
      :NEW.ATTRIBUTE3 := xxssys_oic_util_pkg.encrypt(p_str => l_attribute3);

    end if;

    if :NEW.ATTRIBUTE5 != :OLD.ATTRIBUTE5 and :NEW.ATTRIBUTE5 IS NOT NULL THEN

      l_attribute5    := :NEW.ATTRIBUTE5;
      :NEW.ATTRIBUTE5 := xxssys_oic_util_pkg.encrypt(p_str => l_attribute5);

    end if;
  end if;

end XXFND_VSET_VALUE_OIC_TRG3;
/
