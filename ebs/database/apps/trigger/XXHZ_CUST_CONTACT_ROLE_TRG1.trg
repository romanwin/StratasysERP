CREATE OR REPLACE TRIGGER XXHZ_CUST_CONTACT_ROLE_TRG1
--------------------------------------------------------------------------------------------------
--  name:              XXHZ_CUST_CONTACT_ROLE_TRG1
--  create by:         Debarati Banerjee
--  Revision:          1.0
--  creation date:     14/08/2015
--------------------------------------------------------------------------------------------------
--  purpose :          CHG0035649  : Check and insert data into event table for Delete
--                                   triggers on HZ_ROLE_RESPONSIBILITY
--
--  Modification History
--------------------------------------------------------------------------------------------------
--  ver   date          Name                       Desc
--  1.0   14/08/2015    Debarati Banerjee    CHG0035649 - eCommerce Real Time  Customer interface
--------------------------------------------------------------------------------------------------
AFTER DELETE ON HZ_ROLE_RESPONSIBILITY
FOR EACH ROW

DECLARE
  l_trigger_name      varchar2(30) := 'XXHZ_CUST_CONTACT_ROLE_TRG1';  
  l_contact_id     number;
  l_error_message     varchar2(2000);

BEGIN
  l_error_message := '';

  -- Old Values before delete

  l_contact_id  := :old.cust_account_role_id;  

 --call handle_contact
  
  xxhz_ecomm_event_pkg.handle_contact(p_contact_id => l_contact_id  
                                      );
  
  
EXCEPTION
WHEN OTHERS THEN
  l_error_message := substrb(sqlerrm,1,500);
  RAISE_APPLICATION_ERROR(-20999,l_error_message);
END XXHZ_CUST_CONTACT_ROLE_TRG1;
/
