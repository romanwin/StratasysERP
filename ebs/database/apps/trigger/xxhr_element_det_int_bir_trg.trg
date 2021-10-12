create or replace trigger XXHR_ELEMENT_DET_INT_BIR_TRG
  before insert on xxhr_element_det_interface  
  for each row
declare
  -- local variables here
begin
--------------------------------------------------------------------
--  name:            XXHR_ELEMENT_DET_INT_BIR_TRG
--  create by:       Dalit A. Raviv
--  Revision:        1.0 
--  creation date:   01/03/2011 
--------------------------------------------------------------------
--  purpose:         Yhis trigger fier before insert to interface 
--                   table and do the encript of the values data
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  01/03/2011  Dalit A. Raviv    initial build
-------------------------------------------------------------------- 
  :NEW.entry_value1 := xxobjt_sec.encrypt(:NEW.entry_value1);
  :NEW.entry_value2 := xxobjt_sec.encrypt(:NEW.entry_value2);
  :NEW.entry_value3 := xxobjt_sec.encrypt(:NEW.entry_value3);
  :NEW.entry_value4 := xxobjt_sec.encrypt(:NEW.entry_value4);
  :NEW.entry_value5 := xxobjt_sec.encrypt(:NEW.entry_value5);
  :NEW.entry_value6 := xxobjt_sec.encrypt(:NEW.entry_value6);

end XXHR_ELEMENT_DET_INT_BIR_TRG;
/

