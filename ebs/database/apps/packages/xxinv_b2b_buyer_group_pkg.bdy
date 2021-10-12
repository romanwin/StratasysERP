CREATE OR REPLACE PACKAGE BODY xxinv_b2b_buyer_group_pkg IS
  --------------------------------------------------------------------
  -- Purpose : CHG0048217 oracle sfdc B2B sync  
  ---------------------------------------------------------------------
  --  ver  date          name                 desc
  -- 1.0   9/7/2020      yuval tal             CHG0048217 - initial 
  g_target_name VARCHAR2(30) := 'STRATAFORCE';
  g_pkg_name    VARCHAR2(30) := 'XXINV_B2B_BUYER_GROUP_PKG';

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
  --  Name :      get_EntitlementPolicy_sf_id
  ---------------------------------------------------------------------
  --  ver  date          name                 desc
  -- 1.0   9/7/2020      yuval tal             CHG0048217 - initial 
  FUNCTION get_entitlementpolicy_sf_id(p_cat_ext_key VARCHAR2)
    RETURN VARCHAR2 IS
    l_id VARCHAR2(40);
  BEGIN
    IF p_cat_ext_key IS NOT NULL THEN
      SELECT id
      INTO   l_id
      FROM   commerceentitlementpolicy@source_sf2
      WHERE  external_key__c = p_cat_ext_key;
    END IF;
    RETURN l_id;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
    
  END;
  --------------------------------------------------------------------
  --  Name :      get_BuyerGroup_sf_id
  ---------------------------------------------------------------------
  --  ver  date          name                 desc
  -- 1.0   9/7/2020      yuval tal             CHG0048217 - initial 
  FUNCTION get_buyergroup_sf_id(p_product_cat_ext_key VARCHAR2)
    RETURN VARCHAR2 IS
    l_id VARCHAR2(40);
  BEGIN
    IF p_product_cat_ext_key IS NOT NULL THEN
      SELECT id
      INTO   l_id
      FROM   buyergroup@source_sf2
      WHERE  external_key__c = p_product_cat_ext_key;
    END IF;
    RETURN l_id;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
    
  END;

  --------------------------------------------------------------------
  --  Name :      create_product_category_events
  --
  --Create/delete  categories 
  --Create/delete  product category assignments 
  --
  ---------------------------------------------------------------------
  --  ver  date          name                 desc
  -- 1.0   9/7/2020      yuval tal            CHG0048217 - initial  

  PROCEDURE populate_events(err_buff         OUT VARCHAR2,
		    err_code         OUT VARCHAR2,
		    p_price_list_id  NUMBER,
		    p_account_number VARCHAR2) IS
    l_proc_name        VARCHAR2(40) := '.populate_events';
    l_xxssys_event_rec xxssys_events%ROWTYPE;
    -- insert buyer group event
  
    CURSOR c_insert_buyer_group(c_account_number VARCHAR2,
		        c_price_list_id  NUMBER) IS
      SELECT ext_key,
	 substr(ext_key, 1, instr(ext_key, '|') - 1) price_list_id,
	 substr(ext_key, instr(ext_key, '|') + 1) account_number --,
      /*(SELECT substr(account_name, 1, 200)
      FROM   hz_cust_accounts
      WHERE  account_number =
             substr(ext_key, instr(ext_key, '|') + 1)) account_name*/
      FROM   (SELECT price_list_id || '|' || account_number ext_key
	  FROM   xxhz_b2b_buyer_group_member_v
	  WHERE  account_number = nvl(c_account_number, account_number)
	  -- AND    price_list_id = nvl(c_price_list_id, price_list_id)
	  MINUS
	  SELECT external_key__c
	  FROM   buyergroupmember@source_sf2);
  
    CURSOR c_delete_buyer_group IS
      SELECT id,
	 external_key__c
      FROM   buyergroupmember @source_sf2
      WHERE  external_key__c IN
	 (SELECT external_key__c
	  FROM   buyergroupmember@source_sf2
	  WHERE  external_key__c IS NOT NULL
	  MINUS
	  SELECT price_list_id || '|' || account_number ext_key
	  FROM   xxhz_b2b_buyer_group_member_v);
  
    -- entitlment product events 
  
    CURSOR c_insert_entitlment(c_price_list_id NUMBER) IS
      SELECT external_key,
	 substr(external_key, 1, instr(external_key, '|') - 1) price_list_id,
	 substr(external_key, instr(external_key, '|') + 1) item_code
      FROM   (SELECT external_key
	  FROM   xxinv_b2b_entitlementproduct_v t
	  WHERE  t.list_header_id =
	         nvl(c_price_list_id, t.list_header_id)
	  MINUS
	  SELECT external_key__c
	  FROM   commerceentitlementproduct@source_sf2);
  
    CURSOR c_delete_entitlment IS
      SELECT id,
	 external_key__c external_key
      FROM   commerceentitlementproduct@source_sf2
      WHERE  external_key__c IN
	 (SELECT external_key__c
	  FROM   commerceentitlementproduct@source_sf2
	  WHERE  external_key__c IS NOT NULL
	  MINUS
	  SELECT external_key
	  FROM   xxinv_b2b_entitlementproduct_v);
    TYPE t_isbuyer IS TABLE OF NUMBER INDEX BY VARCHAR2(50);
    l_is_buyer_arr t_isbuyer;
  BEGIN
    -- insert buyer group 
    logger('Start creating buyer group member events');
  
    FOR i IN c_insert_buyer_group(p_account_number, p_price_list_id)
    LOOP
      -- insert only account buyer
    
      DECLARE
        --l_tmp NUMBER;
      BEGIN
      
        IF l_is_buyer_arr.exists(i.account_number) THEN
        
          IF l_is_buyer_arr(i.account_number) = 0 THEN
          
	CONTINUE;
          END IF;
        
        ELSE
        
          BEGIN
	SELECT isbuyer
	INTO   l_is_buyer_arr(i.account_number)
	FROM   xxsf2_account a
	WHERE  a.external_key__c = i.account_number;
          EXCEPTION
	WHEN no_data_found THEN
	
	  l_is_buyer_arr(i.account_number) := 0;
	  logger('Account  ' || i.account_number ||
	         ' was not sync to sfdc/ not sync to copyStorm');
	  CONTINUE;
          END;
        
          IF l_is_buyer_arr(i.account_number) = 0 THEN
	CONTINUE;
          END IF;
          -- WHEN no_data_found THEN
        
        END IF;
      
      END;
    
      l_xxssys_event_rec := NULL;
      logger('new buyer group ext_key= ' || i.ext_key);
    
      l_xxssys_event_rec.target_name := g_target_name;
      l_xxssys_event_rec.entity_name := 'B2B_BUYER_GROUP_MEMBER';
      l_xxssys_event_rec.entity_code := i.ext_key;
      l_xxssys_event_rec.event_name  := g_pkg_name || l_proc_name;
      l_xxssys_event_rec.attribute1  := i.price_list_id;
      l_xxssys_event_rec.attribute2  := i.account_number;
      l_xxssys_event_rec.attribute3  := 'INSERT';
    
      xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'N');
    
    END LOOP;
  
    -- delete member group 
  
    FOR i IN c_delete_buyer_group
    LOOP
      l_xxssys_event_rec := NULL;
      logger('delete buyer group ext_key= ' || i.external_key__c);
    
      l_xxssys_event_rec.target_name := g_target_name;
      l_xxssys_event_rec.entity_name := 'B2B_BUYER_GROUP_MEMBER';
      l_xxssys_event_rec.entity_code := i.external_key__c;
      l_xxssys_event_rec.event_name  := g_pkg_name || l_proc_name;
      l_xxssys_event_rec.attribute3  := 'DELETE';
      l_xxssys_event_rec.attribute4  := i.id;
    
      xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'N');
    
    END LOOP;
  
    -- entitlement product 
    logger('Start entitlement product event');
    FOR i IN c_insert_entitlment(p_price_list_id)
    LOOP
      l_xxssys_event_rec := NULL;
      logger('new entitlement product ext_key= ' || i.external_key);
    
      l_xxssys_event_rec.target_name := g_target_name;
      l_xxssys_event_rec.entity_name := 'B2B_ENTITLEMENT_PRODUCT';
      l_xxssys_event_rec.entity_code := i.external_key;
      l_xxssys_event_rec.event_name  := g_pkg_name || l_proc_name;
      l_xxssys_event_rec.attribute1  := i.price_list_id;
      l_xxssys_event_rec.attribute2  := i.item_code;
      l_xxssys_event_rec.attribute3  := 'INSERT';
    
      xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'N');
    
    END LOOP;
  
    -- delete entitlement 
  
    FOR i IN c_delete_entitlment
    LOOP
      l_xxssys_event_rec := NULL;
      logger('new entitlement product ext_key= ' || i.external_key);
    
      l_xxssys_event_rec.target_name := g_target_name;
      l_xxssys_event_rec.entity_name := 'B2B_ENTITLEMENT_PRODUCT';
      l_xxssys_event_rec.entity_code := i.external_key;
      l_xxssys_event_rec.event_name  := g_pkg_name || l_proc_name;
      l_xxssys_event_rec.attribute3  := 'DELETE';
      l_xxssys_event_rec.attribute4  := i.id;
      xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'N');
    
    END LOOP;
  
  EXCEPTION
    WHEN OTHERS THEN
      err_code := 2;
      err_buff := SQLERRM;
  END;

END xxinv_b2b_buyer_group_pkg;
/
