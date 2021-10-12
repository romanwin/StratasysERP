CREATE OR REPLACE  TRIGGER "APPS"."XXSSYS_DPL_LINES_TRG" 
  before insert on "XXOBJT"."XXSSYS_DPL_LINES"
  for each row
declare
  -----------------------------------------------------------------------------
  -- Ver    When        Who         Descr
  -- -----  ----------  ----------  -------------------------------------------
  -- 1.0    18/02/2020  Roman W.    CHG0047260
  -----------------------------------------------------------------------------
  -- local variables here
begin
  :new.DPL_LINE_ID := XXSSYS_DPL_LINES_S.NEXTVAL;
end XXSSYS_DPL_LINES_T1;

--ALTER TRIGGER "APPS"."XXSSYS_DPL_LINES_TRG" ENABLE
/