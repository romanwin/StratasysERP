CREATE OR REPLACE PACKAGE BODY xxhz_b2b_pkg IS
  --------------------------------------------------------------------
  -- Purpose : CHG0048217 oracle sfdc B2B sync
  ---------------------------------------------------------------------
  --  ver  date          name                 desc
  -- 1.0   9/7/2020      yuval tal             CHG0048217 - initial
  -- 1.1   26.5.21       yuval tal             INC0232831 -  modify populate events - remove is buyer 
  g_target_name VARCHAR2(30) := 'STRATAFORCE';
  g_pkg_name    VARCHAR2(30) := 'XXHZ_B2B_PKG';

  --------------------------------------------------------------------
  --  Name :      is_ecomm_contact
  --
  --eCom contact = contact that there is a User in the system where
  -- user.ContactId = this User.Id and that user’s
  --license user.license = “Customer Community Plus Login”
  ---------------------------------------------------------------------
  --  ver  date          name                 desc
  -- 1.0   9/7/2020      yuval tal            CHG0048217 - initial

  FUNCTION is_ecomm_contact(p_sf_contact_id VARCHAR2) RETURN VARCHAR2 IS
    l_tmp VARCHAR2(1);
  BEGIN
  
    SELECT 'Y'
    INTO   l_tmp
    FROM   xxsf2_contact c --,
    --   xxsf2_user        u,
    --   xxsf2_profile     p,
    --   xxsf2_userlicense ul
    WHERE  /* u.contactid = c.id
                                        AND    u.profileid = p.id*/
    -- AND    p.userlicenseid = ul.id
     c.id = p_sf_contact_id
     AND    c.ecom_operating_unit__c IS NOT NULL;
    --  AND    ul.name = 'Customer Community Plus Login';
  
    RETURN l_tmp;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'N';
    
  END;

  PROCEDURE logger(p_log_line VARCHAR2) IS
    l_msg VARCHAR2(4000);
  BEGIN
    IF TRIM(p_log_line) IS NOT NULL OR p_log_line != chr(10) THEN
      l_msg := to_char(SYSDATE, 'DD/MM/YYYY HH24:MI:SS') || ' - ' ||
	   p_log_line;
    END IF;
    IF fnd_global.conc_request_id = -1 THEN
      dbms_output.put_line(substr(l_msg, 1, 250));
    ELSE
      fnd_file.put_line(fnd_file.log, l_msg);
    END IF;
  END logger;

  --------------------------------------------------------------------
  --  Name :      create_product_category_events
  --
  -- populate contact address relation events ->b2b_contact_address__c
  --
  ---------------------------------------------------------------------
  --  ver  date          name                 desc
  -- 1.0   9/7/2020      yuval tal            CHG0048217 - initial
  -- 1.1   26.5.21       yuval tal             INC0232831 -  modify populate events - remove is buyer 

  PROCEDURE populate_events(err_buff OUT VARCHAR2,
		    err_code OUT VARCHAR2) IS
    l_proc_name        VARCHAR2(40) := '.populate_events';
    l_xxssys_event_rec xxssys_events%ROWTYPE;
    -- insert
    CURSOR c_insert_events IS
    
      SELECT con.external_key__c || '|' || l.external_key__c b2b_contract_address_ext_key,
	 con.id sf_contact_id,
	 cp.id sf_contactpointaddress_id,
	 acc.operating_unit__c
      FROM   xxsf2_account                  acc,
	 xxsf2_contact                  con,
	 xxsf2_locations                l,
	 contactpointaddress@source_sf2 cp
      WHERE  cp.external_key__c = l.external_key__c
      AND    con.accountid = acc.id
	--   AND    acc.isbuyer = 1 -- INC0232831
      AND    l.account__c = acc.id
      AND    l.status__c = 'Active'
      AND    l.operating_unit__c = con.ecom_operating_unit__c
      AND    con.external_key__c IS NOT NULL
      AND    l.external_key__c IS NOT NULL
	--  AND    is_ecomm_contact(con.id) = 'Y'
      AND    NOT EXISTS (SELECT 1
	  FROM   b2b_contact_address__c@source_sf2 ca
	  WHERE  ca.external_key__c = con.external_key__c || '|' ||
	         l.external_key__c);
  
    -- delete
    CURSOR c_delete_events IS
      SELECT id,
	 external_key__c
      FROM   b2b_contact_address__c@source_sf2
      WHERE  external_key__c IN
	 (
	  
	  SELECT ca.external_key__c
	  FROM   b2b_contact_address__c@source_sf2 ca
	  MINUS
	  SELECT con.external_key__c || '|' || l.external_key__c b2b_contract_address_ext_key
	  FROM   xxsf2_account   acc,
	          xxsf2_contact   con,
	          xxsf2_locations l
	  WHERE  con.accountid = acc.id
	        --    AND    acc.isbuyer = 1 -- INC0232831
	        --  AND    is_ecomm_contact(con.id) = 'Y'
	  AND    l.account__c = acc.id
	  AND    l.status__c = 'Active'
	  AND    l.operating_unit__c = con.ecom_operating_unit__c
	  AND    con.external_key__c IS NOT NULL
	  AND    l.external_key__c IS NOT NULL);
  
  BEGIN
    -- insert contact address
    logger(' creating below B2B_CONTACT_ADDRESS events ext = contactid|site id');
  
    FOR i IN c_insert_events
    LOOP
      -- insert only account buyer
    
      l_xxssys_event_rec := NULL;
      logger('new ext_key = ' || i.b2b_contract_address_ext_key);
    
      l_xxssys_event_rec.target_name := g_target_name;
      l_xxssys_event_rec.entity_name := 'B2B_CONTACT_ADDRESS';
      l_xxssys_event_rec.entity_code := i.b2b_contract_address_ext_key;
      l_xxssys_event_rec.event_name  := g_pkg_name || l_proc_name;
      l_xxssys_event_rec.attribute1  := i.sf_contact_id;
      l_xxssys_event_rec.attribute2  := i.sf_contactpointaddress_id;
      l_xxssys_event_rec.attribute3  := 'INSERT';
    
      xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'N');
    
    END LOOP;
  
    -- delete
    FOR i IN c_delete_events
    LOOP
      -- insert only account buyer
    
      l_xxssys_event_rec := NULL;
      logger('delete ext_key= ' || i.external_key__c);
    
      l_xxssys_event_rec.target_name := g_target_name;
      l_xxssys_event_rec.entity_name := 'B2B_CONTACT_ADDRESS';
      l_xxssys_event_rec.entity_code := i.external_key__c;
      l_xxssys_event_rec.event_name  := g_pkg_name || l_proc_name;
      l_xxssys_event_rec.attribute1  := '';
      l_xxssys_event_rec.attribute4  := i.id;
      l_xxssys_event_rec.attribute3  := 'DELETE';
    
      xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'N');
    
    END LOOP;
  
  EXCEPTION
    WHEN OTHERS THEN
      err_code := 2;
      err_buff := SQLERRM;
  END;

END;
/
