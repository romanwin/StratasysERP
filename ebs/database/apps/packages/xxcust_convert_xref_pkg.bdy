CREATE OR REPLACE PACKAGE BODY xxcust_convert_xref_pkg IS

  ----------------------------------------------------------------------------
  --  name:            XXCUST_CONVERT_XREF_PKG
  --  create by:       TCS
  --  Revision:        1.0
  --  creation date:   11/07/2016
  ----------------------------------------------------------------------------
  --  purpose :        Package containing Functions to map legacy,S3 and sfdc Ids

  ----------------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  11/07/2016  TCS           Initial build
  ----------------------------------------------------------------------------

  ----------------------------------------------------------------------------
  --   Name   :        CONVERT_ALLIED_TO_S3
  --  purpose :        Function to get s3 id for corresponding legacy id.

  ----------------------------------------------------------------------------
  --  ver  date        name           desc
  --  1.0  11/07/2016  TCS           Initial build
  --  1.1  26/10/2016  TCS           convert_allied_to_legacy - Function modified in the Exception Section
  ----------------------------------------------------------------------------

  FUNCTION convert_allied_to_s3(p_entity_name IN VARCHAR2,
		        p_allied_id   IN VARCHAR2) RETURN VARCHAR2 IS
  
    l_sql     VARCHAR2(100);
    l_meaning VARCHAR2(100);
    l_id      VARCHAR2(100);
  BEGIN
  
    SELECT meaning
    INTO   l_meaning
    FROM   fnd_lookups
    WHERE  lookup_type = 'XX_CROSS_REF_ENTITIES'
    AND    lookup_code = p_entity_name;
  
    l_sql := 'SELECT s3_id FROM ' || l_meaning ||
	 ' where allied_system_id  = :allied_system_id';
  
    BEGIN
      EXECUTE IMMEDIATE l_sql
        INTO l_id
        USING p_allied_id;
    EXCEPTION
      WHEN no_data_found THEN
        l_id := p_allied_id;
    END;
  
    RETURN(l_id);
  
  END convert_allied_to_s3;

  ----------------------------------------------------------------------------
  --   Name   :        CONVERT_S3_TO_ALLIED
  --  purpose :        Function to get allied id for corresponding s3 id.

  ----------------------------------------------------------------------------
  --  ver  date        name           desc
  --  1.0  11/07/2016  TCS           Initial build
  ----------------------------------------------------------------------------

  FUNCTION convert_s3_to_allied(p_entity_name IN VARCHAR2,
		        p_s3_id       IN VARCHAR2) RETURN VARCHAR2 IS
  
    l_sql     VARCHAR2(100);
    l_meaning VARCHAR2(100);
    l_id      VARCHAR2(100);
  BEGIN
  
    SELECT meaning
    INTO   l_meaning
    FROM   fnd_lookups
    WHERE  lookup_type = 'XX_CROSS_REF_ENTITIES'
    AND    lookup_code = p_entity_name;
  
    l_sql := 'SELECT allied_system_id FROM ' || l_meaning ||
	 ' where s3_id = :s3_id';
  
    BEGIN
      EXECUTE IMMEDIATE l_sql
        INTO l_id
        USING p_s3_id;
    EXCEPTION
      WHEN no_data_found THEN
        l_id := p_s3_id;
    END;
  
    RETURN l_id;
  
  END convert_s3_to_allied;

  ----------------------------------------------------------------------------
  --   Name   :        convert_legacy_to_allied
  --  purpose :        Function to get allied id for corresponding s3 id.

  ----------------------------------------------------------------------------
  --  ver  date        name           desc
  --  1.0  11/07/2016  TCS           Initial build
  ----------------------------------------------------------------------------

  FUNCTION convert_legacy_to_allied(p_entity_name IN VARCHAR2,
			p_legacy_id   IN VARCHAR2)
    RETURN VARCHAR2 IS
  
    l_sql     VARCHAR2(100);
    l_meaning VARCHAR2(100);
    l_id      VARCHAR2(100);
  BEGIN
  
    SELECT meaning
    INTO   l_meaning
    FROM   fnd_lookups
    WHERE  lookup_type = 'XX_CROSS_REF_ENTITIES'
    AND    lookup_code = p_entity_name;
  
    l_sql := 'SELECT allied_system_id FROM ' || l_meaning ||
	 ' where legacy_id = :legacy_id';
  
    BEGIN
      EXECUTE IMMEDIATE l_sql
        INTO l_id
        USING p_legacy_id;
    EXCEPTION
      WHEN no_data_found THEN
        l_id := NULL;
    END;
  
    RETURN l_id;
  
  END convert_legacy_to_allied;

  ----------------------------------------------------------------------------
  --   Name   :        CONVERT_ALLIED_TO_LEGACY
  --  purpose :        Function to get legacy id for corresponding allied id.

  ----------------------------------------------------------------------------
  --  ver  date        name           desc
  --  1.0  11/07/2016  TCS           Initial build
  ----------------------------------------------------------------------------

  FUNCTION convert_allied_to_legacy(p_entity_name IN VARCHAR2,
			p_allied_id   IN VARCHAR2)
    RETURN VARCHAR2 IS
  
    l_sql     VARCHAR2(100);
    l_meaning VARCHAR2(100);
    l_id      VARCHAR2(100);
  BEGIN

    SELECT meaning
    INTO   l_meaning
    FROM   fnd_lookups
    WHERE  lookup_type = 'XX_CROSS_REF_ENTITIES'
    AND    lookup_code = p_entity_name;
  
    l_sql := 'SELECT legacy_id FROM ' || l_meaning ||
	 ' where allied_system_id = :allied_system_id';
  
    EXECUTE IMMEDIATE l_sql
      INTO l_id
      USING p_allied_id;
  
    RETURN(l_id);
  
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
       RETURN NULL;  
    WHEN OTHERS THEN
      dbms_output.put_line('Legacy Id not found');
      raise_application_error(-20900,
		      'Error occured while selecting legacy id for allied id.Please check interfaces');
  END convert_allied_to_legacy;

  ----------------------------------------------------------------------------
  --   Name   :        CONVERT_ALLIED_TO_LEGACY
  --  purpose :        Function to get legacy id for corresponding allied id.

  ----------------------------------------------------------------------------
  --  ver  date        name           desc
  --  1.0  11/07/2016  TCS           Initial build
  ----------------------------------------------------------------------------

  PROCEDURE upsert_legacy_cross_ref_table(p_entity_name IN VARCHAR2,
			      p_legacy_id   VARCHAR,
			      p_s3_id       IN VARCHAR2,
			      p_org_id      IN NUMBER,
			      p_attribute1  IN VARCHAR2,
			      p_attribute2  IN VARCHAR2,
			      p_attribute3  IN VARCHAR2,
			      p_attribute4  IN VARCHAR2,
			      p_attribute5  IN VARCHAR2,
			      p_err_code    OUT NUMBER,
			      p_err_message OUT VARCHAR2) IS
  
    l_meaning VARCHAR2(100);
    l_sql     VARCHAR2(1000);
  BEGIN
    p_err_code := 0;
  
    SELECT meaning
    INTO   l_meaning
    FROM   fnd_lookups
    WHERE  lookup_type = 'XX_CROSS_REF_ENTITIES'
    AND    lookup_code = p_entity_name;
  
    --  l_meaning := 'XXCREF_AR_CUST_ACCOUNTS';
  
    l_sql := 'INSERT INTO ' || l_meaning || '
  (legacy_id,
   s3_id,
   org_id,
   allied_system_id,
   create_date,
   created_by,
   attribute1,
   attribute2,
   attribute3,
   attribute4,
   attribute5)
VALUES
  (:legacy_id,
   :s3_id,
   :org_id,
   :allied_system_id,
   :create_date,
   :created_by,
   :att1,
   :att2,
   :att3,
   :att4,
   :att5)';
    BEGIN
      EXECUTE IMMEDIATE l_sql
        USING p_legacy_id, p_s3_id, p_org_id, p_s3_id, SYSDATE, fnd_global.user_id, p_attribute1, p_attribute2, p_attribute3, p_attribute4, p_attribute5;
      p_err_message := SQL%ROWCOUNT || ' rows inserted';
    EXCEPTION
      WHEN dup_val_on_index THEN
        fnd_file.put_line(fnd_file.log, 'in Reference 3333333333');
        l_sql := '
UPDATE ' || l_meaning || --xxcref_ar_cust_accounts
	     ' SET    legacy_id        = :1,
       allied_system_id = :2,
       update_date      = :3,
       attribute1       = nvl(:att1, attribute1),
       attribute2       = nvl(:att2, attribute2),
       attribute3       = nvl(:att3, attribute3),
       attribute4       = nvl(:att4, attribute4),
       attribute5       = nvl(:att5, attribute5)
WHERE  s3_id = :4';
      
        EXECUTE IMMEDIATE l_sql
          USING p_legacy_id, p_s3_id, SYSDATE, p_attribute1, p_attribute2, p_attribute3, p_attribute4, p_attribute5, p_s3_id;
        p_err_message := SQL%ROWCOUNT || ' rows Updated';
        fnd_file.put_line(fnd_file.log, 'in Reference 444444444444');
      WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log, 'in Reference 55555555' || SQLERRM);
        p_err_code    := 1;
        p_err_message := SQLERRM;
    END;
  
  END;

  ----------------------------------------------------------------------------
  --   Name   :        is_s3_id_exist
  --  purpose :        

  ----------------------------------------------------------------------------
  --  ver  date        name           desc
  --  1.0  11/07/2016  TCS           Initial build
  ----------------------------------------------------------------------------
  FUNCTION get_legacy_id_by_s3_id(p_entity_name IN VARCHAR2,
		          p_s3_id       IN VARCHAR2) RETURN VARCHAR2 IS
  
    l_sql       VARCHAR2(100);
    l_meaning   VARCHAR2(100);
    l_legacy_id VARCHAR2(100);
  BEGIN
  
    SELECT meaning
    INTO   l_meaning
    FROM   fnd_lookups
    WHERE  lookup_type = 'XX_CROSS_REF_ENTITIES'
    AND    lookup_code = p_entity_name;
  
    l_sql := 'SELECT legacy_id  FROM ' || l_meaning ||
	 ' where s3_id  = :s3_id';
  
    BEGIN
      EXECUTE IMMEDIATE l_sql
        INTO l_legacy_id
        USING p_s3_id;
    EXCEPTION
      WHEN no_data_found THEN
        l_legacy_id := NULL;
    END;
  
    RETURN l_legacy_id;
  END;

END xxcust_convert_xref_pkg; 
/