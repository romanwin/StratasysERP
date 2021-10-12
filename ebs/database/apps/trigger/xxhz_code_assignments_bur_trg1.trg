create or replace trigger XXHZ_CODE_ASSIGNMENTS_BUR_TRG1
  before update OR INSERT on HZ_CODE_ASSIGNMENTS
  for each row


when ( NEW.class_category = 'Objet Business Type' and NEW.last_updated_by <> 4290 )
DECLARE
  --------------------------------------------------------------------
  --  name:            XXHZ_CODE_ASSIGNMENTS_BUR_TRG1
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   06/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Trigger that will fier each update of class_code.
  --                   and class_category = 'Objet Business Type' and status = 'A'
  --                   and end_date_active is null or future < sysdate.
  --                   will check that the cust_account relate to this party (:NEW.owner_table_id)
  --                   is relate to SF (att4 keep SF_ID)
  --                   check if there is a row at interface tbl XXOBJT_OA2SF_INTERFACE
  --                   if not insert row to interface tbl XXOBJT_OA2SF_INTERFACE
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/09/2010  Dalit A. Raviv    initial build
  --  1.1  07/11/2010  Dalit A. Raviv    correct When condition (remove and NEW.class_code <> OLD.class_code)
  --  1.2  25.3.14     Dalit A. Raviv    CUST776 - Customer support SF-OA interfaces CR 1215
  --  1.3  12/01/2016  Ofer Suad         CHG0037406 - Add Transfer to SF? logic
  --------------------------------------------------------------------
  -- local variables here
  l_oa2sf_rec xxobjt_oa2sf_interface_pkg.t_oa2sf_rec;
  l_err_code  VARCHAR2(10) := 0;
  l_err_desc  VARCHAR2(2500) := NULL;

  l_cust_account_id NUMBER := NULL;
  l_sf_id           VARCHAR2(150) := NULL;

BEGIN

  -- get cust_account_id + party_id

  SELECT hca.cust_account_id, hca.attribute4
    INTO l_cust_account_id, l_sf_id
    FROM hz_cust_accounts hca, hz_parties hp
   WHERE hca.party_id = hp.party_id
     AND hp.party_id = :new.owner_table_id
     AND hca.status = 'A'
     AND hp.party_type IN ('PERSON', 'ORGANIZATION')
     and nvl(hca.attribute5,'Y')='Y' --CHG0037406 - Add Transfer to SF? logic
     AND rownum = 1;

  l_oa2sf_rec.status      := 'NEW';
  l_oa2sf_rec.source_id   := l_cust_account_id;
  l_oa2sf_rec.source_name := 'ACCOUNT';
  l_oa2sf_rec.sf_id       := l_sf_id;
  xxobjt_oa2sf_interface_pkg.insert_into_interface(p_oa2sf_rec => l_oa2sf_rec, -- i t_oa2sf_rec,
                                                   p_err_code  => l_err_code, -- o v
                                                   p_err_msg   => l_err_desc); -- o v

EXCEPTION
  WHEN OTHERS THEN
    NULL;

END xxhz_code_assignments_bur_trg1;
/
