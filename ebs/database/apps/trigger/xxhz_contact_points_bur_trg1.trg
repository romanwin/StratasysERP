create or replace trigger xxhz_contact_points_bur_trg1
  before update on HZ_CONTACT_POINTS
  for each row


when ((NEW.owner_table_name = 'HZ_PARTIES') and (NEW.contact_point_type in ('PHONE','EMAIL','WEB')) and (NEW.last_updated_by <> 4290))
DECLARE
  --------------------------------------------------------------------
  --  name:            XXHZ_CONTACT_POINTS_BUR_TRG1
  --  create by:       Dalit A. Raviv
  --  Revision:        1.1
  --  creation date:   06/09/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Trigger that will fier each update just when
  --                   primary_flag = 'Y' and contact_point_type in ('PHONE','WEB')
  --                   Check for change in fields: status, phone_area_code, phone_country_code,
  --                   phone_number, phone_extension, url.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/09/2010  Dalit A. Raviv    initial build
  --  1.1  05/01/2014  Dalit A. Raviv    CUST776 - Customer support SF-OA interfaces CR 1215
  --                                     check that this contact point relate to party from type ORGANIZATION
  --                                     This trigger handle contact rows too
  --                                     last_updated_by <> 4290 -> Salesforce
  --------------------------------------------------------------------
  -- local variables here
  l_oa2sf_rec       xxobjt_oa2sf_interface_pkg.t_oa2sf_rec;
  l_err_code        VARCHAR2(10) := 0;
  l_err_desc        VARCHAR2(2500) := NULL;
  l_cust_account_id NUMBER := NULL;

  CURSOR pop_c(p_owner_table_id IN NUMBER) IS
    SELECT DISTINCT cust_roles.cust_account_role_id contact_id
      FROM hz_cust_accounts      cust_acc,
           hz_cust_account_roles cust_roles,
           hz_relationships      cust_rel,
           hz_parties            cust_party,
           hz_parties            cust_party1,
           hz_org_contacts       cust_cont
     WHERE cust_acc.cust_account_id = cust_roles.cust_account_id
       AND cust_acc.status = 'A'
       AND cust_roles.role_type = 'CONTACT'
       AND cust_roles.cust_acct_site_id IS NULL
       AND cust_roles.party_id = cust_rel.party_id
       AND cust_rel.subject_type = 'PERSON'
       AND cust_rel.subject_id = cust_party.party_id
       AND cust_cont.party_relationship_id = cust_rel.relationship_id
       AND cust_acc.party_id = cust_party1.party_id
       AND cust_party1.party_type = 'ORGANIZATION'
       AND cust_acc.attribute4 IS NOT NULL -- sf_is exists
       AND cust_roles.party_id = p_owner_table_id
       and nvl(cust_roles.attribute2,'Y')!='N'; -- migrate  Y/N;; --:NEW.owner_table_id;
BEGIN
  -- Handle account
  IF (:new.contact_point_type = 'PHONE' AND
     :new.phone_line_type IN ('GEN', 'FAX')) OR
     (:new.contact_point_type = 'WEB') THEN
    IF ((:new.status <> :old.status) OR
       (nvl(:new.phone_area_code, '-1') <> nvl(:old.phone_area_code, '-1')) OR
       (nvl(:new.phone_country_code, '-1') <>
       nvl(:old.phone_country_code, '-1')) OR
       (nvl(:new.phone_number, '-1') <> nvl(:old.phone_number, '-1')) OR
       (nvl(:new.phone_extension, '-1') <> nvl(:old.phone_extension, '-1')) OR
       (nvl(:new.url, '-1') <> nvl(:old.url, '-1'))) THEN
    
      -- get cust_account_id
      l_cust_account_id := xxobjt_oa2sf_interface_pkg.is_valid_to_sf('ACCOUNT',
                                                                     :new.owner_table_id);
      IF l_cust_account_id IS NOT NULL THEN
      
        l_oa2sf_rec.source_id   := l_cust_account_id;
        l_oa2sf_rec.source_name := 'ACCOUNT';
        xxobjt_oa2sf_interface_pkg.insert_into_interface(p_oa2sf_rec => l_oa2sf_rec, -- i t_oa2sf_rec,
                                                         p_err_code  => l_err_code, -- o v
                                                         p_err_msg   => l_err_desc); -- o v
      END IF; -- l_cust_account_id is not null
    END IF; -- field changed
  END IF;

  -- Handle Contact
  -- !!!!!!!!!!!!!!!!!!!!!!!!! do i need to check contact relate to party type ORGANIZATION  ?????????????????? !!!!!!!!!!!!!!!!
  IF (:new.contact_point_type IN ('PHONE', 'EMAIL', 'WEB')) THEN
    IF ((:new.status <> :old.status) OR
       (nvl(:new.phone_area_code, '-1') <> nvl(:old.phone_area_code, '-1')) OR
       (nvl(:new.phone_country_code, '-1') <>
       nvl(:old.phone_country_code, '-1')) OR
       (nvl(:new.phone_number, '-1') <> nvl(:old.phone_number, '-1')) OR
       (nvl(:new.phone_extension, '-1') <> nvl(:old.phone_extension, '-1')) OR
       (nvl(:new.url, '-1') <> nvl(:old.url, '-1')) OR
       (nvl(:new.email_address, '-1') <> nvl(:old.email_address, '-1'))) THEN
      FOR pop_r IN pop_c(:new.owner_table_id) LOOP
        -- check party type = organization is handle at the cursor
        l_oa2sf_rec.source_id   := pop_r.contact_id;
        l_oa2sf_rec.source_name := 'CONTACT';
        xxobjt_oa2sf_interface_pkg.insert_into_interface(p_oa2sf_rec => l_oa2sf_rec, -- i t_oa2sf_rec,
                                                         p_err_code  => l_err_code, -- o v
                                                         p_err_msg   => l_err_desc); -- o v
      END LOOP;
    END IF; -- field changed
  END IF;
  --EXCEPTION
  -- WHEN OTHERS THEN
  --  NULL;
END xxhz_contact_points_bur_trg1;
/
