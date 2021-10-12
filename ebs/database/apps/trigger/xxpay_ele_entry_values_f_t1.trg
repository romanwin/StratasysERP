create or replace trigger xxpay_ele_entry_values_f_t1
--------------------------------------------------------------------
--  name:            XXPAY_ELE_ENTRY_VALUES_F_T1
--  create by:       yuval tal
--  Revision:        1.2 
--  creation date:   10.8.10
--------------------------------------------------------------------
--  purpose :        
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  10.8.10     yuval tal         initial build
--  1.1  19/02/2013  Dalit A. Raviv    add condition for the trigger
--                                     give ability to end employment for person 
--                                     without the need to enter security password.
--  1.2  08/05/2013  Dalit A. Raviv    due to the upgrade to 12.1.3 
--                                     when user did not use the security token to open the encrypt data
--                                     it will return -1, in this caes need to do nothing.
--------------------------------------------------------------------
before update or insert   on hr.pay_element_entry_values_f
  for each row

begin
 if :new.screen_entry_value is not null and (  nvl(:new.screen_entry_value,'-1')  <> nvl(:old.screen_entry_value,'-1')) and (:new.screen_entry_value <> -1) then
    :new.screen_entry_value := xxobjt_sec.encrypt(:new.screen_entry_value);
 end if;

end xxpay_ele_entry_values_f_t1;
/
