CREATE OR REPLACE PACKAGE BODY xxcs_vpd_security_pkg IS

  --------------------------------------------------------------------
  --  name:            xxcs_vpd_security_pkg
  --  create by:      
  --  Revision:        1.1 
  --  creation date:   
  --------------------------------------------------------------------
  --  purpose :        
  --------------------------------------------------------------------
  --  ver  date         name              desc
  --  1.x  28.11.2013   Adi Safin         cr1028-  Add SSUS operating unit : modify procedure service_request_sec
  --------------------------------------------------------------------  

  FUNCTION party_sec(obj_schema VARCHAR2, obj_name VARCHAR2) RETURN VARCHAR2 IS
    v_org_id NUMBER;
  BEGIN
    v_org_id := fnd_profile.value('ORG_ID');
    IF nvl(fnd_profile.value('XXCS_VPD_SECURITY_ENABLED'), 'N') = 'Y' AND
       v_org_id IS NOT NULL THEN
      RETURN 'party_type != ''ORGANIZATION'' OR ' || 'country IS NULL OR ' || 'attribute2=''Y'' OR ' || '(party_type = ''ORGANIZATION'' AND EXISTS ' || '(SELECT 1 ' || '   FROM fnd_lookup_values flv ' || '  WHERE flv.lookup_type = ''XXSERVICE_COUNTRIES_SECURITY'' AND ' || '        flv.LANGUAGE = ''US'' AND ' || '        flv.enabled_flag = ''Y'' AND ' || '        flv.attribute1 = ' || v_org_id || ' AND ' || '        lookup_code = nvl(country, lookup_code))) ';
    
    ELSE
      RETURN '1=1';
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN '1=1';
  END party_sec;
  ----------------------------------------------
  FUNCTION party_org_security(obj_schema VARCHAR2, obj_name VARCHAR2)
    RETURN VARCHAR2 IS
    v_org_id NUMBER;
  BEGIN
    IF dbms_mview.i_am_a_refresh THEN
      RETURN NULL;
    ELSIF USER IN ('XXOBJT', 'XXATC') THEN
      RETURN NULL;
    END IF;
  
    v_org_id := fnd_profile.value('ORG_ID');
    IF nvl(fnd_profile.value('XXCS_VPD_SECURITY_ENABLED'), 'N') = 'Y' THEN
      -- RETURN 'nvl(attribute2, ''N'') = ''N'' and nvl(attribute3, -1) = decode(attribute3, null, -1, sys_context(''multi_org2'',''current_org_id''))';
      RETURN '(nvl(attribute2, ''N'') = ''Y'' or nvl(attribute3, -1) = decode(attribute3, null, -1, ' || v_org_id || '))';
    ELSE
      RETURN '1 = 1';
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN '1=1';
  END party_org_security;

  ---------------------------------------------- 
  -- 1.1   Adi Safin     07-OCT-2013       Add Suuport for SSUS operating unit
  ---------------------------------------------
  FUNCTION service_request_sec(obj_schema VARCHAR2, obj_name VARCHAR2)
    RETURN VARCHAR2 IS
    v_org_id    NUMBER;
    v_us_org_id NUMBER := fnd_profile.value('XXCS_US_ORGANIZATION_ID'); -- 1.1   Adi Safin     07-OCT-2013
  BEGIN
    IF dbms_mview.i_am_a_refresh THEN
      RETURN NULL;
    ELSIF USER IN ('XXOBJT', 'XXATC') THEN
      RETURN NULL;
    END IF;
    v_org_id := fnd_profile.value('ORG_ID');
    IF nvl(fnd_profile.value('XXCS_VPD_SECURITY_ENABLED'), 'N') = 'Y' AND
       v_org_id IS NOT NULL THEN
      IF v_org_id = v_us_org_id THEN
        RETURN ' (org_id in( ' || v_org_id || ',89) OR EXISTS (SELECT 1 ' || ' FROM HZ_PARTIES p ' || ' WHERE p.attribute2=''Y'' ' || ' AND p.party_id=customer_id)) '; -- 1.1   Adi Safin     07-OCT-2013
      ELSE
        RETURN ' (org_id = ' || v_org_id || ' OR EXISTS (SELECT 1 ' || ' FROM HZ_PARTIES p ' || ' WHERE p.attribute2=''Y'' ' || ' AND p.party_id=customer_id)) ';
      END IF;
    ELSE
      RETURN '1=1';
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN '1=1';
  END service_request_sec;
  ---------------------------------------------- 
  PROCEDURE update_hz_parties_vpd_attr3(errbuf    OUT VARCHAR2,
                                        errcode   OUT VARCHAR2,
                                        p_org_id  IN NUMBER,
                                        p_country IN VARCHAR2) IS
  
    l_step          VARCHAR2(100);
    l_error_message VARCHAR2(3000);
    l_rows_updated  NUMBER;
  
    CURSOR get_country(in_org_id NUMBER, in_country VARCHAR2) IS
      SELECT flv.lookup_code country, flv.attribute1 org_id
        FROM fnd_lookup_types flt, fnd_lookup_values flv
       WHERE flt.lookup_type = flv.lookup_type
         AND flt.lookup_type = 'XXSERVICE_COUNTRIES_SECURITY'
         AND flv.language = 'US'
         AND flv.enabled_flag = 'Y'
         AND flv.lookup_code = nvl(in_country, flv.lookup_code)
         AND flv.attribute1 = nvl(in_org_id, flv.attribute1)
         AND flv.attribute1 IS NOT NULL;
  
  BEGIN
  
    l_step := 'Step 1';
    FOR country_rec IN get_country(p_org_id, p_country) LOOP
      -------------------------------------
      UPDATE hz_parties hp
         SET hp.attribute3 = country_rec.org_id
       WHERE hp.party_type = 'ORGANIZATION'
         AND hp.country IS NOT NULL
         AND nvl(hp.attribute2, 'N') = 'N'
         AND hp.country = country_rec.country
         AND nvl(hp.attribute3, -777) != country_rec.org_id;
      l_rows_updated := SQL%ROWCOUNT;
      IF l_rows_updated > 0 THEN
        fnd_file.put_line(fnd_file.log, ''); --empty line
        fnd_file.put_line(fnd_file.log,
                          '*********Country ''' || country_rec.country ||
                          ''' : Attribute3 was updated for ' ||
                          l_rows_updated ||
                          ' ORGANIZATION parties ***********');
      END IF;
      COMMIT;
      -------------------------------------
    END LOOP;
  
  EXCEPTION
    WHEN OTHERS THEN
      l_error_message := ' Unexpected ERROR in XXCS_VPD_SECURITY_PKG.update_hz_parties_vpd_attr3 (step=' ||
                         l_step || ') : ' || SQLERRM;
      errcode         := '2';
      errbuf          := l_error_message;
      fnd_file.put_line(fnd_file.log, '========' || l_error_message);
  END update_hz_parties_vpd_attr3;
  ----------------------------------------------    
END xxcs_vpd_security_pkg;
/
