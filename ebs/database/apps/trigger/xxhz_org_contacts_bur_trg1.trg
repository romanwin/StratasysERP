create or replace trigger xxhz_org_contacts_bur_trg1
  before update on HZ_ORG_CONTACTS
  for each row

when (( ( nvl(NEW.job_title ,'DAR') <> nvl(OLD.job_title  ,'DAR')) or
        ( nvl(NEW.job_title_code ,'DAR') <> nvl(OLD.job_title_code  ,'DAR')) or
        ( nvl(NEW.contact_number ,'DAR') <> nvl(OLD.contact_number  ,'DAR')) ) and (NEW.last_updated_by <> 4290))
DECLARE
  --------------------------------------------------------------------
  --  name:            XXHZ_ORG_CONTACTS_BUR_TRG1
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   08/01/2014
  --------------------------------------------------------------------
  --  purpose :        Trigger that will fire each update of job_title,
  --                   job_title_code, contact_number
  --                   CUST776 - Customer support SF-OA interfaces CR 1215
  --                   last_updated_by <> 4290 -> Salesforce
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  08/01/2014  Dalit A. Raviv    initial build
  --
  --------------------------------------------------------------------
  -- local variables here
  l_oa2sf_rec xxobjt_oa2sf_interface_pkg.t_oa2sf_rec;
  l_err_code  VARCHAR2(10) := 0;
  l_err_desc  VARCHAR2(2500) := NULL;

  CURSOR pop_c(p_party_relationship_id IN NUMBER) IS
    SELECT cust_roles.cust_account_role_id contact_id
      FROM hz_cust_accounts      cust_acc,
           hz_cust_account_roles cust_roles,
           hz_relationships      cust_rel,
           hz_parties            cust_party,
           hz_parties            party
     WHERE cust_acc.cust_account_id = cust_roles.cust_account_id
       AND cust_acc.status = 'A'
       AND cust_roles.role_type = 'CONTACT'
       AND cust_roles.cust_acct_site_id IS NULL
       AND cust_roles.party_id = cust_rel.party_id
       AND cust_rel.subject_type = 'PERSON'
       AND cust_rel.subject_id = cust_party.party_id
       AND cust_rel.relationship_id = p_party_relationship_id
       AND party.party_type = 'ORGANIZATION'
       AND cust_acc.attribute5 = 'Y'
       AND cust_acc.party_id = party.party_id
      and nvl(cust_roles.attribute2,'Y')!='N'; -- migrate  Y/N

BEGIN
  -- check for contact
  FOR pop_r IN pop_c(:new.party_relationship_id) LOOP
    l_oa2sf_rec.source_id   := pop_r.contact_id;
    l_oa2sf_rec.source_name := 'CONTACT';
    xxobjt_oa2sf_interface_pkg.insert_into_interface(p_oa2sf_rec => l_oa2sf_rec, -- i t_oa2sf_rec,
                                                     p_err_code  => l_err_code, -- o v
                                                     p_err_msg   => l_err_desc); -- o v
  END LOOP;

EXCEPTION
  WHEN OTHERS THEN
    NULL;
END xxhz_org_contacts_bur_trg1;
/
