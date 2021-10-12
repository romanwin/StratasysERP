create or replace trigger xxpay_element_entry_val_f_t1
  instead of insert on xxpay_element_entry_values_f
  for each row
declare

begin
  --------------------------------------------------------------------
  --  name:            XXPAY_ELEMENT_ENTRY_VAL_F_T1
  --  create by:       Yuval Tal
  --  Revision:        1.0
  --  creation date:   XX/XX/201X 
  --------------------------------------------------------------------
  --  purpose :        HR encrypt
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  XX/XX/201X  Yuval Tal         initial build
  --  1.1  08/05/2013  Dalit A. Raviv    due to the upgrade to 12.1.3 
  --                                     when user did not use the security token to open the encrypt data
  --                                     it will return -1, in this caes need to do nothing.
  -------------------------------------------------------------------- 
  if :NEW.screen_entry_value <> -1 then
    INSERT INTO hr.pay_element_entry_values_f
      (element_entry_value_id,
       effective_start_date,
       effective_end_date,
       input_value_id,
       element_entry_id,
       screen_entry_value)
    VALUES
      (:NEW.element_entry_value_id,
       :NEW.effective_start_date,
       :NEW.effective_end_date,
       :NEW.input_value_id,
       :NEW.element_entry_id,
       :NEW.screen_entry_value);
  end if;
exception
  when others then
    null;
end;
/
