create or replace trigger xxoks_reprocessing_bir_trg
  before insert on oks_reprocessing
  for each row
declare
  -- local variables here
begin
--------------------------------------------------------------------
--  name:            XXOKS_REPROCESSING_BIR_TRG
--  create by:       Dalit A. Raviv
--  Revision:        1.0
--  creation date:   08/01/2012
--------------------------------------------------------------------
--  purpose:         This trigger fier before insert to to change
--                   success flag from N to S
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  08/01/2012  Dalit A. Raviv    initial build
--------------------------------------------------------------------

  :NEW.success_flag := 'S';
exception
  when others then null;

end XXHR_ELEMENT_DET_INT_BIR_TRG;
/
