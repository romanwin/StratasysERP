CREATE OR REPLACE PACKAGE BODY xxhz_util AS
  --------------------------------------------------------------------
  --  name:            XXHZ_UTIL
  --  create by:       XXX
  --  Revision:        1.2
  --  creation date:   XX/XX/XXXX
  --------------------------------------------------------------------
  --  purpose :        global account pricing
  --------------------------------------------------------------------
  --  ver    date          name             desc
  --  1.0    17.01.2011    yuval tal        Initial Build
  --  1.1    23.4.2013     yuval tal        add get_operating_unit_name,get_ou_lang
  --  1.2    10.12.2013    Dalit A. Raviv   add functions: get_customer_email and Get_customer_mail_ar_letter
  --  1.3    22.1.2014     yuval tal        CR 1215 add get_customer_industry
  --  1.4    16.11.2014    Michal Tzvik     Add function get_parent_customer_location
  --  1.5    08.12.14      yuval tal        CHG0033946 - modify get_phone,get_fax order by primary desc
  --  1.6    07.01.2015    Michal Tzvik     CHG0034052: Add function get_party_id_of_site_use_id
  --  1.7    15.06.2015    Diptasurjya      CHG0035560: Add function get_account_id_of_site_use_id
  --                       Chatterjee
  --  1.8    29.06.2015    Diptasurjya      CHG0035652: Add function is_ecomm_customer, which
  --                       Chatterjee                   returns TRUE for accounts which have at least
  --                                                    1 contact with eCommerce flag marked 'Y', else FALSE is returned
  --  1.9    05.08.2015  Diptasurjya      CHG0034981: New function added check_education_customer. Returns TRUE is site_use_id
  --                     Chatterjee                 belongs to education classification enabled customer
  --  2.0    28.10.2015  Debarati Banerjee   CHG0036659:Modified Function is_ecomm_customer to handle the
  --                                         change of ecommerce flag to a new DFF
  --  2.1    08-MAR-2021   Diptasurjya      CHG0049516 - Add new function get_customer_subindustry
  --  2.2    12.5.21       yuval tal        CHG0049822 add get_account_num_of_site_use_id
  --------------------------------------------------------------------

  -------------------------------------------
  -- get_customer_industry
  --------------------------------------------------------------------
  --  ver    date          name             desc
  --  1.0    22.1.2014     yuval tal        CR 1215 intial build
  -------------------------------------------
  FUNCTION get_customer_industry(p_party_id NUMBER) RETURN VARCHAR2 IS
    l_tmp VARCHAR2(500);
  BEGIN
  
    SELECT t.class_code
    INTO   l_tmp
    FROM   xxcs_cust_classifications_v t
    WHERE  t.party_id = p_party_id
    AND    t.last_update_date =
           (SELECT MAX(tt.last_update_date)
	 FROM   xxcs_cust_classifications_v tt
	 WHERE  t.party_id = tt.party_id);
  
    RETURN l_tmp;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;

  -------------------------------------------
  -- get_customer_sub_industry
  --------------------------------------------------------------------
  --  ver    date          name             desc
  --  1.0    02-MAR-2021   Diptasurjya      CHG0049516 - intial build
  -------------------------------------------
  FUNCTION get_customer_subindustry(l_cust_account_id NUMBER) RETURN VARCHAR2 IS
    l_tmp VARCHAR2(240);
  BEGIN
  
    SELECT attribute16
    INTO   l_tmp
    FROM   hz_cust_accounts
    WHERE  cust_account_id = l_cust_account_id;
  
    RETURN l_tmp;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;

  -------------------------------------------
  -- get_contact_phone
  ----------------------------------------------
  --  ver    date          name             desc
  -- 1.0     08.12.14      yuval tal        CHG0033946 - modify get_phone order by primary desc
  -------------------------------------------
  FUNCTION get_phone(p_party_id NUMBER) RETURN VARCHAR2 IS
    l_tmp VARCHAR2(500);
  BEGIN
  
    SELECT phone
    INTO   l_tmp
    FROM   (SELECT decode(hzcp.phone_country_code,
		  NULL,
		  NULL,
		  hzcp.phone_country_code || '-') ||
	       hzcp.raw_phone_number phone
	FROM   hz_contact_points hzcp
	WHERE  hzcp.owner_table_name = 'HZ_PARTIES'
	AND    hzcp.contact_point_type = 'PHONE'
	AND    hzcp.phone_line_type = 'GEN'
	AND    hzcp.status = 'A'
	AND    hzcp.owner_table_id = p_party_id
	--ORDER  BY nvl(hzcp.primary_flag, 'N') DESC)
	ORDER  BY hzcp.primary_flag DESC NULLS LAST)
    WHERE  rownum = 1;
  
    RETURN l_tmp;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
  END;

  -------------------------------------------
  -- get_contact_fax
  --------------------------------------------------------------------
  --  ver    date          name             desc
  -- 1.0     08.12.14      yuval tal        CHG0033946 - modify get_fax order by primary desc
  -------------------------------------------
  FUNCTION get_fax(p_party_id NUMBER) RETURN VARCHAR2 IS
    l_tmp VARCHAR2(500);
  BEGIN
  
    SELECT fax
    INTO   l_tmp
    FROM   (SELECT decode(hzcp.phone_country_code,
		  NULL,
		  NULL,
		  hzcp.phone_country_code || '-') ||
	       hzcp.raw_phone_number fax
	FROM   hz_contact_points hzcp
	WHERE  hzcp.owner_table_name = 'HZ_PARTIES'
	AND    hzcp.contact_point_type = 'PHONE'
	AND    hzcp.phone_line_type = 'FAX'
	AND    hzcp.status = 'A'
	AND    hzcp.owner_table_id = p_party_id
	--ORDER  BY nvl(hzcp.primary_flag, 'N') DESC)
	ORDER  BY hzcp.primary_flag DESC NULLS LAST)
    WHERE  rownum = 1;
  
    RETURN l_tmp;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
  END;
  --------------------------------------------------------------------
  --  name:            get_op_name
  --  create by:       yuval tal
  --  Revision:        1.0
  --------------------------------------------------------------------
  --  purpose : general use
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  14.4.2013   yuval tal          initial build
  --------------------------------------------------------------------

  FUNCTION get_operating_unit_name(p_org_id NUMBER) RETURN VARCHAR2 AS
  
    v_name VARCHAR2(150);
  
  BEGIN
  
    BEGIN
      SELECT NAME
      INTO   v_name
      FROM   hr_operating_units opu
      
      WHERE  opu.organization_id = p_org_id
      AND    rownum = 1;
    
    EXCEPTION
      WHEN OTHERS THEN
        v_name := NULL;
    END;
  
    RETURN v_name;
  
  EXCEPTION
    WHEN OTHERS THEN
      v_name := NULL;
      RETURN v_name;
    
  END;

  --------------------------------------------------------------------
  -- get_ou_lang
  --  purpose : get operating unit language
  --            cust13 :cr724 : Invoice for Japan
  -- in  :  p_org_id operating unit id
  -- out : language_-code

  -- ?? logic my be replace with dff on operating unit screen
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  14.4.2013   yuval tal          initial build
  --------------------------------------------------------------------

  FUNCTION get_ou_lang(p_org_id NUMBER) RETURN VARCHAR2 IS
  BEGIN
    IF get_operating_unit_name(p_org_id) = 'OBJET JP (OU)' THEN
      RETURN 'JA';
    ELSE
      RETURN 'US';
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'US';
    
  END;
  --------------------------------------------------------------------
  --  name:            get_party_name_tl
  --  create by:       yuval tal
  --  Revision:        1.0
  --------------------------------------------------------------------
  --  purpose : support party name for differnt languages (part of japan project)
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  23.4.2013   yuval tal          initial build
  --------------------------------------------------------------------

  FUNCTION get_party_name_tl(p_party_id NUMBER,
		     p_org_id   NUMBER) RETURN VARCHAR2 IS
    l_name hz_parties.organization_name_phonetic%TYPE;
  BEGIN
  
    SELECT decode(get_ou_lang(p_org_id),
	      'JA',
	      p.organization_name_phonetic,
	      p.party_name)
    INTO   l_name
    FROM   hz_parties p
    WHERE  p.party_id = p_party_id;
  
    RETURN l_name;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
    
  END;

  -------------------------------------------------------------------
  -- get_inv_org_ou
  -------------------------------------------------------------------
  --  purpose : get operating unit for inventory organization (part of japan project)
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  23.4.2013   yuval tal          initial build
  --------------------------------------------------------------------

  FUNCTION get_inv_org_ou(p_organization_id NUMBER) RETURN NUMBER IS
    l_tmp NUMBER;
  BEGIN
    SELECT --inv.organization_id   inv_id,
    -- inv.organization_code inv_org,
     ou.organization_id ou_id
    INTO   l_tmp
    -- ou.name               ou_org
    FROM   org_organization_definitions inv,
           hr_all_organization_units    ou
    WHERE  inv.operating_unit = ou.organization_id
    AND    inv.organization_id = p_organization_id;
    RETURN l_tmp;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
    
  END;
  -------------------------------------------------------------------
  -- get_territory_tl
  -------------------------------------------------------------------
  --  purpose : get_territory_tl tanslation   for  organization (part of japan project)
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  23.4.2013   yuval tal          initial build
  --------------------------------------------------------------------
  FUNCTION get_territory_tl(p_territory_code VARCHAR2,
		    p_org_id         NUMBER) RETURN VARCHAR2 IS
    l_name fnd_territories_tl.territory_short_name%TYPE;
  BEGIN
  
    SELECT t.territory_short_name
    INTO   l_name
    FROM   fnd_territories_tl t
    WHERE  t.territory_code = p_territory_code
    AND    t.language = get_ou_lang(p_org_id);
  
    RETURN l_name;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
    
  END;

  --------------------------------------------------------------------
  --  name:            get_customer_email
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   10/12/2013
  --------------------------------------------------------------------
  --  purpose :        general function to get by table level Customer email
  --  In Param:        p_owner_table_name like HZ_PARTIES, HZ_PARTY_SITES
  --                   p_owner_table_id   depend on the owner table party_id for HZ_PARTIES and party site id for HZ_PARTY_SITES
  --                   p_primary          Y will retrieve only primary email
  --                                      null will retrieve all
  --------------------------------------------------------------------
  --  ver    date        name             desc
  --  1.0    10/12/2013  Dalit A. Raviv   Initial Build
  --------------------------------------------------------------------
  FUNCTION get_customer_email(p_owner_table_name IN VARCHAR2,
		      p_owner_table_id   IN NUMBER,
		      p_primary          IN VARCHAR2) RETURN VARCHAR2 IS
  
    l_email_address hz_contact_points.email_address%TYPE;
  
  BEGIN
    SELECT email_address
    INTO   l_email_address
    FROM   (SELECT hzcp.email_address,
	       hzcp.primary_flag
	FROM   hz_contact_points hzcp
	WHERE  hzcp.owner_table_name = p_owner_table_name --'hz_parties'
	AND    hzcp.contact_point_type = 'EMAIL'
	AND    hzcp.email_format = 'MAILTEXT'
	AND    hzcp.status = 'A'
	AND    hzcp.owner_table_id = p_owner_table_id -- p_party_id / party site id
	)
    WHERE  ((primary_flag = p_primary) OR (p_primary IS NULL))
    AND    rownum = 1;
  
    RETURN l_email_address;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_customer_email;

  --------------------------------------------------------------------
  --  name:            Get_customer_mail_ar_letter
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   10/12/2013
  --------------------------------------------------------------------
  --  purpose :        CR1022 Customer balance report
  --------------------------------------------------------------------
  --  ver    date        name             desc
  --  1.0    10/12/2013  Dalit A. Raviv   Initial Build
  --------------------------------------------------------------------
  FUNCTION get_customer_mail_ar_letter(p_account_number IN VARCHAR2)
    RETURN VARCHAR2 IS
  
    l_email_address hz_contact_points.email_address%TYPE;
  
  BEGIN
    SELECT hov.email_address
    INTO   l_email_address
    FROM   hz_cust_accounts      htc,
           hz_relationships      rl,
           hz_org_contacts_v     hov,
           hz_cust_account_roles hcar
    WHERE  htc.account_number = p_account_number --'C00125'
    AND    rl.subject_id = htc.party_id
    AND    hov.party_relationship_id = rl.relationship_id
    AND    hov.job_title = 'Customer Letter'
    AND    hov.job_title_code = 'XX_ACCOUNTS_PAYABLE'
    AND    nvl(hov.status, 'A') = 'A'
    AND    hov.contact_point_type = 'EMAIL'
    AND    hov.contact_primary_flag = 'Y'
    AND    hcar.party_id = rl.party_id
    AND    nvl(hcar.current_role_state, 'A') = 'A'
    AND    hcar.cust_account_id = htc.cust_account_id
    AND    rownum = 1;
  
    RETURN l_email_address;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_customer_mail_ar_letter;

  --------------------------------------------------------------------
  --  name:            get_parent_customer_location
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   16/11/2014
  --------------------------------------------------------------------
  --  purpose :        CHG0033422   Sales Discount Bucket Program
  --                   get parent customer location from value sets
  --                   'XXGL_COMPANY_SEG', 'XXGL_LOCATION_SEG'
  --------------------------------------------------------------------
  --  ver    date        name             desc
  --  1.0    16/11/2014  Michal Tzvik     Initial Build
  --------------------------------------------------------------------
  FUNCTION get_parent_customer_location(p_site_use_id NUMBER) RETURN VARCHAR2 IS
    l_parent_location VARCHAR2(30);
  BEGIN
  
    SELECT MAX(ffv.description)
    INTO   l_parent_location
    FROM   hz_cust_site_uses_all     hcsu,
           gl_code_combinations      gcb,
           fnd_flex_value_sets       ffvs,
           fnd_flex_values_vl        ffv,
           fnd_flex_value_children_v ffvc,
           fnd_flex_hierarchies      ffh
    WHERE  1 = 1
    AND    hcsu.site_use_id = p_site_use_id
    AND    gcb.code_combination_id(+) = hcsu.gl_id_rev
    AND    ffvc.flex_value = nvl(gcb.segment6, '803')
    AND    ffvs.flex_value_set_name = 'XXGL_LOCATION_SEG'
    AND    ffvs.flex_value_set_id = ffv.flex_value_set_id
    AND    ffvc.flex_value_set_id = ffv.flex_value_set_id
    AND    ffvc.parent_flex_value = ffv.flex_value
    AND    ffv.enabled_flag = 'Y'
    AND    SYSDATE BETWEEN nvl(ffv.start_date_active, SYSDATE - 1) AND
           nvl(ffv.end_date_active, SYSDATE + 1)
    AND    ffh.hierarchy_id = ffv.structured_hierarchy_level
    AND    ffh.hierarchy_code = 'ACCOUNTING';
  
    RETURN l_parent_location;
  
  END get_parent_customer_location;

  --------------------------------------------------------------------
  --  name:            get_so_parent_cust_location
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   16/11/2014
  --------------------------------------------------------------------
  --  purpose :        CHG0033422   Sales Discount Bucket Program
  --                   get parent customer location from value sets
  --                   'XXGL_COMPANY_SEG', 'XXGL_LOCATION_SEG'
  --------------------------------------------------------------------
  --  ver    date        name             desc
  --  1.0    16/11/2014  Michal Tzvik     Initial Build
  --------------------------------------------------------------------
  FUNCTION get_so_parent_cust_location(p_header_id NUMBER) RETURN VARCHAR2 IS
    l_site_use_id     NUMBER;
    l_parent_location VARCHAR2(30);
  BEGIN
    SELECT oh.invoice_to_org_id
    INTO   l_site_use_id
    FROM   oe_order_headers_all oh
    WHERE  oh.header_id = p_header_id;
  
    l_parent_location := get_parent_customer_location(l_site_use_id);
  
    RETURN l_parent_location;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_so_parent_cust_location;

  --------------------------------------------------------------------
  --  name:            is_permission_by_org
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   04/12/2014
  --------------------------------------------------------------------
  --  purpose :        CHG0033422   Sales Discount Bucket Program
  --                   get value of dff 'permission_by_org' from value sets
  --                   'XXGL_COMPANY_SEG'
  --                   In order to allow restrict population by org_id and
  --                   not just by parent location.
  --
  -- return Y/ N
  --------------------------------------------------------------------
  --  ver    date        name             desc
  --  1.0    04/12/2014  Michal Tzvik     Initial Build
  --------------------------------------------------------------------
  FUNCTION is_permission_by_org(p_org_id NUMBER) RETURN VARCHAR2 IS
    l_is_permission_by_org VARCHAR2(1);
  BEGIN
  
    SELECT nvl(MAX(ffv.attribute2), 'N') permission_by_org
    INTO   l_is_permission_by_org
    FROM   fnd_flex_value_sets     ffvs,
           fnd_flex_values         ffv,
           gl_ledger_norm_seg_vals glnsv,
           xle_entity_profiles     xep,
           hr_operating_units      hop
    WHERE  1 = 1
    AND    ffvs.flex_value_set_name = 'XXGL_COMPANY_SEG'
    AND    ffv.flex_value_set_id = ffvs.flex_value_set_id
    AND    glnsv.segment_value = ffv.flex_value
    AND    glnsv.legal_entity_id = xep.legal_entity_id
    AND    xep.transacting_entity_flag = 'Y'
    AND    xep.legal_entity_id = hop.default_legal_context_id
    AND    hop.organization_id = p_org_id;
  
    RETURN l_is_permission_by_org;
  
  END is_permission_by_org;

  --------------------------------------------------------------------
  --  name:            get_party_id_of_site_use_id
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   07/01/2015
  --------------------------------------------------------------------
  --  purpose :        CHG0034052  New personalization to support EMEA Resin pilot
  --                   get party id of current site use id
  --------------------------------------------------------------------
  --  ver    date        name             desc
  --  1.0    07/01/2015  Michal Tzvik     Initial Build
  --------------------------------------------------------------------
  FUNCTION get_party_id_of_site_use_id(p_site_use_id NUMBER) RETURN NUMBER IS
    l_party_id hz_parties.party_id%TYPE;
  BEGIN
    SELECT hp.party_id
    INTO   l_party_id
    FROM   hz_cust_site_uses_all  hcsu,
           hz_cust_acct_sites_all hcas,
           hz_cust_accounts       hca,
           hz_parties             hp
    WHERE  1 = 1
    AND    hcsu.site_use_id = p_site_use_id
    AND    hcas.cust_acct_site_id = hcsu.cust_acct_site_id
    AND    hca.cust_account_id = hcas.cust_account_id
    AND    hp.party_id = hca.party_id;
  
    RETURN l_party_id;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
  END get_party_id_of_site_use_id;

  --------------------------------------------------------------------
  --  purpose :        CHG0049822  Interface initial build  used in view XXOM_GC_ACC_FEATURE_SOA_V
  --------------------------------------------------------------------
  --  ver    date        name       desc
  --  1.0    12.5.21  yuval tal     CHG0049822 Initial Build
  --------------------------------------------------------------------
  FUNCTION get_account_num_of_site_use_id(p_site_use_id NUMBER)
    RETURN VARCHAR2 IS
    l_account_num hz_cust_accounts.account_number%TYPE;
  BEGIN
    SELECT h.account_number
    INTO   l_account_num
    FROM   hz_cust_accounts       h,
           hz_cust_site_uses_all  hcsu,
           hz_cust_acct_sites_all hcas
    WHERE  hcsu.site_use_id = p_site_use_id
    AND    hcas.cust_acct_site_id = hcsu.cust_acct_site_id
    AND    hcas.cust_account_id = h.cust_account_id;
  
    RETURN l_account_num;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
  END;

  --------------------------------------------------------------------
  --  name:            get_account_id_of_site_use_id
  --  create by:       Diptasurjya Chatterjee
  --  Revision:        1.0
  --  creation date:   07/01/2015
  --------------------------------------------------------------------
  --  purpose :        CHG0035560  New customization to get account_id
  --                   from current site use id
  --------------------------------------------------------------------
  --  ver    date        name                       desc
  --  1.0    07/01/2015  Diptasurjya Chatterjee     Initial Build
  --------------------------------------------------------------------
  FUNCTION get_account_id_of_site_use_id(p_site_use_id NUMBER) RETURN NUMBER IS
    l_account_id hz_cust_accounts.cust_account_id%TYPE;
  BEGIN
    SELECT hcas.cust_account_id
    INTO   l_account_id
    FROM   hz_cust_site_uses_all  hcsu,
           hz_cust_acct_sites_all hcas
    WHERE  hcsu.site_use_id = p_site_use_id
    AND    hcas.cust_acct_site_id = hcsu.cust_acct_site_id;
  
    RETURN l_account_id;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
  END get_account_id_of_site_use_id;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035652
  --          This function checks whether customer is eCommerce customer or not.
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  29/06/2015  Diptasurjya Chatterjee             Initial Build
  -- 1.1  28/10/2015  Debarati Banerjee                  CHG0036659:Modified Function to handle the
  --                                                     change of ecommerce flag to a new DFF
  -- --------------------------------------------------------------------------------------------

  FUNCTION is_ecomm_customer(p_cust_account_id IN NUMBER) RETURN VARCHAR2 IS
    isecom VARCHAR2(1);
    CURSOR cur_isecom IS
      SELECT 'Y'
      FROM   hz_cust_accounts      hca,
	 hz_cust_account_roles hcar,
	 hz_relationships      hr,
	 hz_parties            hp_contact,
	 hz_parties            hp_cust,
	 hz_party_sites        hps
      WHERE  hp_cust.party_id = hca.party_id
      AND    hps.party_id(+) = hcar.party_id
      AND    nvl(hps.identifying_address_flag, 'Y') = 'Y'
      AND    hca.cust_account_id = hcar.cust_account_id
      AND    hca.status = 'A'
      AND    hp_contact.status = 'A'
      AND    hp_cust.status = 'A'
      AND    nvl(hps.status, 'A') = 'A'
      AND    hcar.status = 'A'
      AND    hcar.role_type = 'CONTACT'
      AND    hcar.cust_acct_site_id IS NULL
      AND    hcar.party_id = hr.party_id
      AND    hr.subject_type = 'PERSON'
      AND    hr.subject_id = hp_contact.party_id
      AND    xxhz_ecomm_event_pkg.is_ecomm_contact(hcar.cust_account_role_id) =
	 'TRUE' -- change event pkg name
      AND    hca.cust_account_id = p_cust_account_id;
  BEGIN
    OPEN cur_isecom;
    FETCH cur_isecom
      INTO isecom;
    IF cur_isecom%FOUND THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
    CLOSE cur_isecom;
  END is_ecomm_customer;

  --------------------------------------------------------------------
  --  name:            check_education_customer
  --  create by:       Diptasurjya Chatterjee
  --  Revision:        1.0
  --  creation date:   08/05/2015
  --------------------------------------------------------------------
  --  purpose :        CHG0034981  New customization to check if site use id
  --                   belongs to Education customer.
  --------------------------------------------------------------------
  --  ver    date        name                       desc
  --  1.0    08/05/2015  Diptasurjya Chatterjee     Initial Build
  --------------------------------------------------------------------
  FUNCTION check_education_customer(p_site_use_id     NUMBER,
			p_cust_account_id NUMBER) RETURN VARCHAR2 IS
    l_is_education_cust VARCHAR2(10) := 'N';
    l_cust_account_id   NUMBER;
    l_valid_account     VARCHAR2(240);
  
    CURSOR cur_edu_cust_check IS
      SELECT hcas.cust_account_id
      FROM   hz_cust_site_uses_all  hcsu,
	 hz_cust_acct_sites_all hcas,
	 hz_cust_accounts       hca,
	 hz_code_assignments    hcasg
      WHERE  hcsu.site_use_id = p_site_use_id
      AND    hcas.cust_acct_site_id = hcsu.cust_acct_site_id
      AND    hcas.cust_account_id = hca.cust_account_id
	/*AND hca.account_number in (select flv.lookup_code
             from fnd_lookup_values flv
            where flv.lookup_type = 'XX_EDUCATION_CUSTOMER_LIST')*/
      AND    hca.party_id = hcasg.owner_table_id
      AND    hcasg.class_category = 'Objet Business Type'
      AND    hcasg.class_code = 'Education'
      AND    hcasg.status = 'A';
  
    CURSOR cur_check_account_valid IS
      SELECT account_number
      FROM   fnd_lookup_values flv,
	 hz_cust_accounts  hca
      WHERE  hca.account_number = flv.lookup_code
      AND    flv.lookup_type = 'XX_EDUCATION_CUSTOMER_LIST'
      AND    hca.cust_account_id = p_cust_account_id;
  BEGIN
    OPEN cur_check_account_valid;
    FETCH cur_check_account_valid
      INTO l_valid_account;
  
    IF cur_check_account_valid%NOTFOUND THEN
      l_is_education_cust := 'N';
    ELSE
      OPEN cur_edu_cust_check;
      FETCH cur_edu_cust_check
        INTO l_cust_account_id;
    
      IF cur_edu_cust_check%NOTFOUND THEN
        l_is_education_cust := 'N';
      ELSE
        l_is_education_cust := 'Y';
      END IF;
    
      CLOSE cur_edu_cust_check;
    END IF;
  
    CLOSE cur_check_account_valid;
  
    RETURN l_is_education_cust;
  END check_education_customer;

  --------------------------------------------------------------------
  --  name:            is_LATAM_customer
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   05/02/2015
  --------------------------------------------------------------------
  --  purpose :        CHG0034518 - by customer site get if this customer relate to LATAM
  --------------------------------------------------------------------
  --  ver    date        name             desc
  --  1.0    05/02/2015  Dalit A. Raviv   Initial Build
  --------------------------------------------------------------------
  FUNCTION is_latam_customer(p_site_use_id IN NUMBER,
		     p_site_id     IN NUMBER,
		     p_customer_id IN NUMBER) RETURN VARCHAR2 IS
  
    CURSOR c_pop IS
      SELECT ffv.description latam
      FROM   hz_parties                hp,
	 hz_party_sites            hps,
	 hz_party_site_uses        hpsu,
	 hz_cust_accounts          hca,
	 hz_cust_acct_sites_all    hcas,
	 hz_cust_site_uses_all     hcsu,
	 gl_code_combinations      gcb,
	 fnd_flex_value_sets       ffvs,
	 fnd_flex_values_vl        ffv,
	 fnd_flex_value_children_v ffvc
      WHERE  hp.party_id = hps.party_id
      AND    hp.party_id = hca.party_id
      AND    hps.party_site_id = hcas.party_site_id
      AND    hcsu.cust_acct_site_id = hcas.cust_acct_site_id
      AND    hps.party_site_id = hpsu.party_site_id
      AND    hcsu.site_use_code = hpsu.site_use_type
      AND    hcsu.site_use_code = 'BILL_TO'
      AND    hcsu.status = 'A'
      AND    hcas.party_site_id = nvl(p_site_id, hcas.party_site_id)
      AND    hcsu.site_use_id = nvl(p_site_use_id, hcsu.site_use_id)
      AND    hca.cust_account_id = nvl(p_customer_id, hca.cust_account_id)
      AND    gcb.code_combination_id = hcsu.gl_id_rev
      AND    ffvc.flex_value = gcb.segment6
      AND    ffvs.flex_value_set_name = 'XXGL_LOCATION_SEG'
      AND    ffvs.flex_value_set_id = ffv.flex_value_set_id
      AND    ffv.description = 'LATAM'
      AND    ffvc.flex_value_set_id = ffv.flex_value_set_id
      AND    ffvc.parent_flex_value = ffv.flex_value;
  
    l_return VARCHAR2(10) := 'N';
  BEGIN
    IF p_site_use_id IS NULL AND p_site_id IS NULL AND
       p_customer_id IS NULL THEN
      RETURN 'N';
    END IF;
  
    FOR r_pop IN c_pop
    LOOP
      IF r_pop.latam = 'LATAM' THEN
        l_return := 'Y';
        EXIT;
      END IF;
    END LOOP;
  
    RETURN l_return;
  
  END is_latam_customer;

END xxhz_util;
/
