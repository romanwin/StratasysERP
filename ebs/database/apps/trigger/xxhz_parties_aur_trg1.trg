create or replace trigger xxhz_parties_aur_trg1
  before update on HZ_PARTIES
  for each row

when (((NEW.party_type in ('PERSON', 'ORGANIZATION')) and   (NEW.last_updated_by <> 4290) ) and (
      nvl(NEW.attribute3,'DAR')  <> nvl(OLD.attribute3,'DAR')  or  -- customer_operating_unit
      nvl(NEW.attribute4,'DAR')  <> nvl(OLD.attribute4,'DAR')  or  -- program_date
      nvl(NEW.attribute5,'DAR')  <> nvl(OLD.attribute5,'DAR')  or  -- global_account
      nvl(NEW.attribute7,'DAR')  <> nvl(OLD.attribute7,'DAR')  or  -- kam_customer
      nvl(NEW.attribute8,'DAR')  <> nvl(OLD.attribute8,'DAR')  or
      -- 1.2 22/01/2015 Dalit A. Raviv CHG0033819
      nvl(NEW.attribute11,'DAR') <> nvl(OLD.attribute11,'DAR') or  -- Basket_Level
      nvl(NEW.party_name,'DAR') <> nvl(OLD.party_name,'DAR') or  -- Party_name
      --
      nvl(NEW.organization_name_phonetic,'DAR') <> nvl(OLD.organization_name_phonetic,'DAR') OR
      nvl(NEW.person_last_name,'DAR') <> nvl(OLD.person_last_name,'DAR') OR
      nvl(NEW.person_first_name,'DAR') <> nvl(OLD.person_first_name,'DAR') OR
      nvl(NEW.person_pre_name_adjunct,'DAR') <> nvl(OLD.person_pre_name_adjunct,'DAR')


      )    -- vip_customer
     )
DECLARE
  --------------------------------------------------------------------
  --  name:            XXHZ_PARTIES_AUR_TRG1
  --  create by:       Dalit A. Raviv
  --  Revision:        1.1
  --  creation date:   06/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Trigger that will fire each update of party name.
  --                   att3,4,5,7,8. Because party can have several accounts
  --                   the insert will be in loop.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/09/2010  Dalit A. Raviv    initial build
  --  1.1  05/01/2014  Dalit A. Raviv    CUST776 - Customer support SF-OA interfaces CR 1215
  --                                     check that this party relate to party
  --                                     from type ORGANIZATION
  --                                     last_updated_by <> 4290 -> Salesforce
  --  1.2  22/01/2015  Dalit A. Raviv    CHG0033819 - add check if att11 changed - need to transfer the info to SF.
  --  1.3  12/01/2016  Ofer Suad         CHG0037406 - Add Transfer to SF? logic
  --  1.4  30/04/2017  Adi Safin         INC0092499 - Add check if party_name changed
  --------------------------------------------------------------------
  -- local variables here
  l_oa2sf_rec xxobjt_oa2sf_interface_pkg.t_oa2sf_rec;
  l_err_code  VARCHAR2(10) := 0;
  l_err_desc  VARCHAR2(2500) := NULL;

  CURSOR c IS
    SELECT hca.cust_account_id
      FROM hz_cust_accounts hca
     WHERE hca.party_id = :new.party_id
       AND hca.attribute4 IS NOT NULL
       and nvl(hca.attribute5,'Y')='Y';--CHG0037406 - Add Transfer to SF? logic

  CURSOR c_contact IS
    SELECT cust_roles.attribute1 sf_contact_id,
           --  cust_party.person_last_name        last_name,
           --  cust_party.person_first_name       first_name,
           --   cust_party.person_pre_name_adjunct prefix,
           cust_roles.cust_account_role_id contact_id,
           cust_acc.account_number         cust_num,
           cust_acc.attribute4             sf_account_id,
           cust_acc.party_id,
           cust_acc.cust_account_id
      FROM hz_cust_accounts      cust_acc,
           hz_cust_account_roles cust_roles,
           hz_relationships      cust_rel,
           --  hz_parties                      cust_party,
           hz_org_contacts cust_cont

     WHERE --7167045
     cust_acc.cust_account_id = cust_roles.cust_account_id
     AND cust_acc.status = 'A'
     AND cust_roles.role_type = 'CONTACT'
     AND cust_roles.cust_acct_site_id IS NULL
     AND cust_roles.party_id = cust_rel.party_id
     AND cust_rel.subject_type = 'PERSON'
     AND cust_rel.subject_id = :new.party_id --cust_party.party_id
     AND cust_cont.party_relationship_id = cust_rel.relationship_id;

BEGIN
  IF :new.party_type = 'PERSON' THEN
    FOR r IN c_contact LOOP
      l_oa2sf_rec.source_id   := r.contact_id;
      l_oa2sf_rec.source_name := 'CONTACT';
      xxobjt_oa2sf_interface_pkg.insert_into_interface(p_oa2sf_rec => l_oa2sf_rec, -- i t_oa2sf_rec,
                                                       p_err_code  => l_err_code, -- o v
                                                       p_err_msg   => l_err_desc); -- o v
    END LOOP;
  END IF;

  -- CONTACT

  IF :new.party_type = 'ORGANIZATION' THEN
    FOR r IN c LOOP
      l_oa2sf_rec.source_id   := r.cust_account_id;
      l_oa2sf_rec.source_name := 'ACCOUNT';
      xxobjt_oa2sf_interface_pkg.insert_into_interface(p_oa2sf_rec => l_oa2sf_rec, -- i t_oa2sf_rec,
                                                       p_err_code  => l_err_code, -- o v
                                                       p_err_msg   => l_err_desc); -- o v
    END LOOP;
  END IF;

EXCEPTION
  WHEN OTHERS THEN
    NULL;
END xxhz_parties_aur_trg1;
/
