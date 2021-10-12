CREATE OR REPLACE PACKAGE BODY xxinv_b2b_product_pkg IS
  --------------------------------------------------------------------
  -- Purpose : CHG0048217 oracle sfdc B2B sync  
  ---------------------------------------------------------------------
  --  ver  date          name                 desc
  -- 1.0   9/7/2020      yuval tal             CHG0048217 - initial 
  g_target_name VARCHAR2(30) := 'STRATAFORCE';
  g_pkg_name    VARCHAR2(30) := 'xxinv_b2b_product_pkg';

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
  --  Name :      get_category_sf_id
  ---------------------------------------------------------------------
  --  ver  date          name                 desc
  -- 1.0   9/7/2020      yuval tal             CHG0048217 - initial 
  FUNCTION get_category_sf_id(p_cat_ext_key VARCHAR2) RETURN VARCHAR2 IS
    l_id VARCHAR2(40);
  BEGIN
    IF p_cat_ext_key IS NOT NULL THEN
      SELECT id
      INTO   l_id
      FROM   productcategory@source_sf2
      WHERE  external_key__c = p_cat_ext_key;
    END IF;
    RETURN l_id;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
    
  END;
  --------------------------------------------------------------------
  --  Name :      get_product_category_sf_id
  ---------------------------------------------------------------------
  --  ver  date          name                 desc
  -- 1.0   9/7/2020      yuval tal             CHG0048217 - initial 
  FUNCTION get_product_category_sf_id(p_product_cat_ext_key VARCHAR2)
    RETURN VARCHAR2 IS
    l_id VARCHAR2(40);
  BEGIN
    IF p_product_cat_ext_key IS NOT NULL THEN
      SELECT id
      INTO   l_id
      FROM   productcategoryproduct@source_sf2
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
  ---------------------------------------------------------------------
  PROCEDURE create_product_category_events(err_buff OUT VARCHAR2,
			       err_code OUT VARCHAR2) IS
    l_proc_name VARCHAR2(40) := '.create_product_category_events';
    -- insert category structure event
    CURSOR c_insert_category IS
      SELECT category_name,
	 category_ext_key,
	 t.parent_external_key,
	 sort_order
      FROM   xxinv_product_family_unique_v t
      WHERE  (category_ext_key, sort_order) IN (
				
				SELECT category_ext_key,
				        sort_order
				FROM   xxinv_product_family_unique_v t
				WHERE  t.parent_external_key IS NOT NULL -- dont create events for level 0 it will be created manually in sfdc with same values as in  XXINV_PRODUCT_FAMILY_V.top level )
				MINUS
				SELECT external_key__c,
				        nvl(sortorder, -1)
				FROM   xxinv_sfdc_b2b_category_v t);
  
    --- delete category structure event 
    CURSOR c_delete_category IS
      SELECT TRIM(t.productcategory_id) productcategory_id,
	 t.external_key__c,
	 t.category_name
      FROM   xxinv_sfdc_b2b_category_v t
      WHERE  external_key__c IN
	 (SELECT external_key__c
	  
	  FROM   xxinv_sfdc_b2b_category_v
	  MINUS
	  SELECT category_ext_key
	  FROM   xxinv_product_family_unique_v);
  
    -- insert product assignment events 
    CURSOR c_insert_product_cat_assign IS
      SELECT t.ext_key_3,
	 t.ext_key_2,
	 item_code
      FROM   xxinv_product_family_v t
      WHERE  ext_key_3 IN
	 (SELECT ext_key_3
	  FROM   xxinv_product_family_v
	  MINUS
	  SELECT external_key__c
	  FROM   xxinv_sfdc_b2b_product_cat_v);
  
    -- insert DELETE PRODUCT category events
    CURSOR c_delete_product_cat_assign IS
      SELECT TRIM(t.productcategoryproduct_id) sf_product_category_product_id,
	 external_key__c,
	 t.item_code
      
      FROM   xxinv_sfdc_b2b_product_cat_v t
      WHERE  external_key__c IN
	 (SELECT external_key__c
	  FROM   xxinv_sfdc_b2b_product_cat_v
	  MINUS
	  SELECT ext_key_3
	  FROM   xxinv_product_family_v);
    l_xxssys_event_rec xxssys_events%ROWTYPE;
  BEGIN
    err_code := 0;
    -- insert structure
    logger(' creating below events');
  
    FOR i IN c_insert_category
    LOOP
      l_xxssys_event_rec := NULL;
      logger('new category ext_key= ' || i.category_ext_key);
    
      l_xxssys_event_rec.target_name := g_target_name;
      l_xxssys_event_rec.entity_name := 'B2B_PRODUCT_HIERARCHY';
      l_xxssys_event_rec.entity_code := i.category_name;
      l_xxssys_event_rec.event_name  := g_pkg_name || l_proc_name;
      l_xxssys_event_rec.attribute1  := i.category_ext_key;
      l_xxssys_event_rec.attribute3  := 'INSERT';
      l_xxssys_event_rec.attribute2  := i.parent_external_key; --PARENT EXY KEY 
      l_xxssys_event_rec.attribute4  := i.sort_order;
    
      xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'N');
    
    END LOOP;
  
    --
    FOR i IN c_delete_category
    LOOP
      l_xxssys_event_rec := NULL;
      logger('delete category ' || i.external_key__c);
    
      l_xxssys_event_rec.target_name := g_target_name;
      l_xxssys_event_rec.entity_name := 'B2B_PRODUCT_HIERARCHY';
      l_xxssys_event_rec.entity_code := i.category_name;
      l_xxssys_event_rec.event_name  := g_pkg_name || l_proc_name;
    
      l_xxssys_event_rec.attribute1 := i.external_key__c;
      l_xxssys_event_rec.attribute3 := 'DELETE';
      l_xxssys_event_rec.attribute4 := i.productcategory_id;
    
      xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'N');
    END LOOP;
  
    -- new product  assignment 
  
    FOR i IN c_insert_product_cat_assign
    LOOP
      l_xxssys_event_rec := NULL;
      logger('new product assignment ' || i.ext_key_3);
    
      l_xxssys_event_rec.target_name := g_target_name;
      l_xxssys_event_rec.entity_name := 'B2B_PRODUCT_ASSIGNMENT';
      l_xxssys_event_rec.entity_code := i.ext_key_3;
      l_xxssys_event_rec.event_name  := g_pkg_name || l_proc_name;
      l_xxssys_event_rec.attribute1  := 'INSERT';
      l_xxssys_event_rec.attribute2  := i.ext_key_2; --PARENT EXY KEY 
      l_xxssys_event_rec.attribute4  := i.item_code;
    
      xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'N');
    END LOOP;
  
    FOR j IN c_delete_product_cat_assign
    LOOP
      l_xxssys_event_rec := NULL;
      logger('delete product assignment ' || j.external_key__c ||
	 length(j.sf_product_category_product_id));
    
      l_xxssys_event_rec.target_name := g_target_name;
      l_xxssys_event_rec.entity_name := 'B2B_PRODUCT_ASSIGNMENT';
      l_xxssys_event_rec.entity_code := j.external_key__c;
      l_xxssys_event_rec.event_name  := g_pkg_name || l_proc_name;
      l_xxssys_event_rec.attribute1  := 'DELETE';
      l_xxssys_event_rec.attribute3  := j.sf_product_category_product_id;
      l_xxssys_event_rec.attribute4  := j.item_code;
    
      xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'N');
    END LOOP;
  EXCEPTION
    WHEN OTHERS THEN
      err_code := 2;
      err_buff := SQLERRM;
  END;

END xxinv_b2b_product_pkg;
/
