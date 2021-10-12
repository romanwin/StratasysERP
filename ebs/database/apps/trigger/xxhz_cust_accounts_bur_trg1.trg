create or replace trigger xxhz_cust_accounts_bur_trg1
  before update on HZ_CUST_ACCOUNTS
  for each row

when (/*((NEW.status <> OLD.status) or (NEW.account_number <> OLD.account_number)
      or (nvl(NEW.sales_channel_code,'DAR') <> nvl(OLD.sales_channel_code ,'DAR') ))
      and*/ (NEW.last_updated_by <> 4290))
DECLARE
  -- local variables here
  l_oa2sf_rec xxobjt_oa2sf_interface_pkg.t_oa2sf_rec;
  l_err_code  VARCHAR2(10) := 0;
  l_err_desc  VARCHAR2(2500) := NULL;
  l_entity_id NUMBER := NULL;
BEGIN
  --------------------------------------------------------------------
  --  name:            XXHZ_CUST_ACCOUNTS_BUR_TRG1
  --  create by:       Dalit A. Raviv
  --  Revision:        1.1
  --  creation date:   06/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Trigger that will fire each update of status or sales channel or account number
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/09/2010  Dalit A. Raviv    initial build
  --  1.1  05/01/2014  Dalit A. Raviv    CUST776 - Customer support SF-OA interfaces CR 1215
  --                                     check that this cust account relate to party from type ORGANIZATION
  --                                     last_updated_by <> 4290 -> Salesforce
  -- 21.2 12/01/2016   Ofer Suad         CHG0037406 - Add Transfer to SF? logic
  --------------------------------------------------------------------

  l_entity_id := xxobjt_oa2sf_interface_pkg.is_valid_to_sf('PARTY',
				           :new.party_id);

  IF l_entity_id IS NOT NULL AND
     nvl(nvl(:new.attribute5, :old.attribute5), 'Y') = 'Y' THEN--CHG0037406 - Add Transfer to SF? logic
    l_oa2sf_rec.source_id   := :new.cust_account_id;
    l_oa2sf_rec.source_name := 'ACCOUNT';
    xxobjt_oa2sf_interface_pkg.insert_into_interface(p_oa2sf_rec => l_oa2sf_rec, -- i t_oa2sf_rec,
				     p_err_code  => l_err_code, -- o v
				     p_err_msg   => l_err_desc); -- o v
  END IF; -- l_entity_id

EXCEPTION
  WHEN OTHERS THEN
    NULL;
END xxhz_cust_accounts_bur_trg1;
/