create or replace trigger XXHZ_LOCATIONS_BUR_TRG1
  before update or insert on HZ_LOCATIONS
  for each row

when ((  nvl(NEW.address1,'DAR') <> nvl(OLD.address1 ,'DAR') or    nvl(NEW.address2,'DAR') <> nvl(OLD.address2 ,'DAR') or
         nvl(NEW.address3,'DAR') <> nvl(OLD.address3 ,'DAR') or    nvl(NEW.address4,'DAR') <> nvl(OLD.address4 ,'DAR') or
         nvl(NEW.city    ,'DAR') <> nvl(OLD.city     ,'DAR') or    nvl(NEW.postal_code,'DAR') <> nvl(OLD.postal_code,'DAR') or
         nvl(NEW.county  ,'DAR') <> nvl(OLD.county   ,'DAR') or    nvl(NEW.state   ,'DAR') <> nvl(OLD.state    ,'DAR') or
         nvl(NEW.country ,'DAR') <> nvl(OLD.country  ,'DAR') ) and (NEW.last_updated_by <> 4290))
DECLARE
  --------------------------------------------------------------------
  --  name:            XXHZ_LOCATIONS_BUR_TRG1
  --  create by:       Dalit A. Raviv
  --  Revision:        1.1
  --  creation date:   07/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Trigger that will fire each update of : address1 - 4, city, postal_code
  --                   county, state, country
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
  --                                     This trigger is used for contacts level.
  --                                     last_updated_by <> 4290 -> Salesforce
  --------------------------------------------------------------------
  -- local variables here
  l_oa2sf_rec         xxobjt_oa2sf_interface_pkg.t_oa2sf_rec;
  l_err_code          VARCHAR2(10) := 0;
  l_err_desc          VARCHAR2(2500) := NULL;
  l_cust_acct_site_id NUMBER := NULL;

  CURSOR pop_c(c_location_id IN NUMBER) IS
    SELECT cust_roles.cust_account_role_id contact_id
      FROM hz_cust_accounts      cust_acc,
           hz_cust_account_roles cust_roles,
           hz_relationships      cust_rel,
           hz_parties            cust_party,
           hz_org_contacts       cust_cont,
           hz_party_sites        x,
           hz_parties            party
     WHERE cust_cont.status = 'A'
       AND x.party_id = cust_roles.party_id
       AND x.location_id = c_location_id
       AND cust_acc.cust_account_id = cust_roles.cust_account_id
       AND cust_acc.status = 'A'
       AND cust_roles.role_type = 'CONTACT'
       AND cust_roles.cust_acct_site_id IS NULL
       AND cust_roles.party_id = cust_rel.party_id
       AND cust_rel.subject_type = 'PERSON'
       AND cust_rel.subject_id = cust_party.party_id
       AND cust_cont.party_relationship_id = cust_rel.relationship_id
       AND party.party_type IN ('PERSON', 'ORGANIZATION')
       AND cust_acc.attribute4 IS NOT NULL -- acc sf_is exists
       AND cust_acc.party_id = party.party_id
       AND nvl(cust_roles.attribute2, 'Y') != 'N'; -- migrate  Y/N;;

  CURSOR c_site(c_location_id IN NUMBER) IS
    SELECT site.cust_acct_site_id
    
      FROM hz_parties             hp,
           hz_cust_accounts       hca,
           hz_cust_acct_sites_all site,
           hz_party_sites         hps
     WHERE hca.party_id = hp.party_id
       AND hca.cust_account_id = site.cust_account_id
       AND site.party_site_id = hps.party_site_id
       AND hp.party_type IN ('PERSON', 'ORGANIZATION')
       AND (hca.attribute5 = 'Y' OR hca.attribute4 IS NOT NULL)
       AND hca.status = 'A'
       AND hps.status = 'A'
       AND site.status = 'A'
       AND hps.location_id = c_location_id;
BEGIN
  -- check for site
  l_cust_acct_site_id := xxobjt_oa2sf_interface_pkg.is_valid_to_sf('LOCATION',
                                                                   nvl(:old.location_id,
                                                                       :new.location_id));
  IF l_cust_acct_site_id IS NOT NULL THEN
    FOR i IN c_site(:new.location_id) LOOP
      l_oa2sf_rec.source_id   := i.cust_acct_site_id;
      l_oa2sf_rec.source_name := 'SITE';
      xxobjt_oa2sf_interface_pkg.insert_into_interface(p_oa2sf_rec => l_oa2sf_rec, -- i t_oa2sf_rec,
                                                       p_err_code  => l_err_code, -- o v
                                                       p_err_msg   => l_err_desc); -- o v
    END LOOP;
  END IF; -- l_flag

  -- check for contact
  FOR pop_r IN pop_c(:new.location_id) LOOP
    l_oa2sf_rec.source_id   := pop_r.contact_id;
    l_oa2sf_rec.source_name := 'CONTACT';
    xxobjt_oa2sf_interface_pkg.insert_into_interface(p_oa2sf_rec => l_oa2sf_rec, -- i t_oa2sf_rec,
                                                     p_err_code  => l_err_code, -- o v
                                                     p_err_msg   => l_err_desc); -- o v
  END LOOP;

EXCEPTION
  WHEN OTHERS THEN
    NULL;
END xxhz_locations_bur_trg1;
/
