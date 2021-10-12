CREATE OR REPLACE TRIGGER "APPS"."XXHZ_CUST_ACCOUNT_ROLES_TRG2" 
  before update on "AR"."HZ_CUST_ACCOUNT_ROLES"
  for each row
declare
  -------------------------------------------------------------------------
  -- Ver   When        Who        Descr
  -- ----  ----------  ---------  -----------------------------------------
  -- 1.0   01/07/2020  Roman W.   CHG0047450 - Add a validation on contact 
  --                                in Oracle to allow changing contact status 
  --                                to inactive only when PARTNER_USER flag = false
  --                                (HZ_CUST_ACCOUNT_ROLES.ATTRIBUTE6)
  -------------------------------------------------------------------------
begin
  if :old.status = 'A' and :new.status = 'I' then
    if :old.attribute6 = 'Y' or :new.attribute6 = 'Y' then
      raise_application_error(-20001,
                              'This contact has an active Salesforce user, pleae disable this user in order to changr the contact status');
    end if;
  end if;
end XXHZ_CUST_ACCOUNT_ROLES_TRG2;

--ALTER TRIGGER "APPS"."XXHZ_CUST_ACCOUNT_ROLES_TRG2" ENABLE
/