create or replace trigger xxhz_cust_acct_sites_bur_trg1
  before update on HZ_CUST_ACCT_SITES_ALL
  for each row

when (NEW.last_updated_by <> 4290)
DECLARE
  --------------------------------------------------------------------
  --  name:            XXHZ_CUST_ACCT_SITES_BUR_TRG1
  --  create by:       Dalit A. Raviv
  --  Revision:        1.1
  --  creation date:   07/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Trigger that will fire each update of status.
  --                   will check that the cust_acct_site_id relate to this party is relate to
  --                   SF (att4 keep SF_ID or att5 = Y)
  --                   check if there is a row at interface tbl XXOBJT_OA2SF_INTERFACE
  --                   if not insert row to interface tbl XXOBJT_OA2SF_INTERFACE
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  07/09/2010  Dalit A. Raviv    initial build
  --  1.1  05/01/2014  Dalit A. Raviv    CUST776 - Customer support SF-OA interfaces CR 1215
  --                                     check that this account site relate to party
  --                                     from type ORGANIZATION
  --                                     last_updated_by <> 4290 -> Salesforce
  --------------------------------------------------------------------
  -- local variables here
  l_oa2sf_rec xxobjt_oa2sf_interface_pkg.t_oa2sf_rec;
  l_err_code  VARCHAR2(10) := 0;
  l_err_desc  VARCHAR2(2500) := NULL;
  l_entity_id NUMBER := NULL;
BEGIN

  l_entity_id := xxobjt_oa2sf_interface_pkg.is_valid_to_sf('CUST_ACC_SITE',
                                                           :new.cust_account_id);

  IF l_entity_id IS NOT NULL THEN
    l_oa2sf_rec.source_id   := :new.cust_acct_site_id;
    l_oa2sf_rec.source_name := 'SITE';
    xxobjt_oa2sf_interface_pkg.insert_into_interface(p_oa2sf_rec => l_oa2sf_rec, -- i t_oa2sf_rec,
                                                     p_err_code  => l_err_code, -- o v
                                                     p_err_msg   => l_err_desc); -- o v
  END IF;

EXCEPTION
  WHEN OTHERS THEN
    NULL;
END xxhz_cust_acct_sites_bur_trg1;
/
