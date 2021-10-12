CREATE OR REPLACE PACKAGE BODY xxssys_oic_util_pkg IS

  ----------------------------------------------------------------------------------------
  -- Ver   When        Who           Descr
  -- ----  ----------  ------------  -----------------------------------------------------
  -- 1.0   07/12/2020  Roman W.      CHG0048579 - OIC new integration tool implementation
  ----------------------------------------------------------------------------------------
  c_type CONSTANT BINARY_INTEGER := dbms_crypto.encrypt_rc4;
  c_key  CONSTANT RAW(128) := utl_raw.cast_to_raw(get_instance);
  ----------------------------------------------------------------------------------------
  -- Ver   When        Who           Descr
  -- ----  ----------  ------------  -----------------------------------------------------
  -- 1.0   07/12/2020  Roman W.      CHG0048579 - OIC new integration tool implementation
  ----------------------------------------------------------------------------------------
  PROCEDURE message(p_msg IN VARCHAR2) IS
    l_msg VARCHAR(32676);
  BEGIN
  
    l_msg := substr(to_char(SYSDATE, 'DD/MM/YYYY HH24:MI:SS  ') || p_msg,
                    1,
                    32676);
  
    IF fnd_global.conc_request_id > 0 THEN
      fnd_file.put_line(fnd_file.log, l_msg);
    ELSE
      dbms_output.put_line(l_msg);
    END IF;
  END message;

  ----------------------------------------------------------------------------------------
  -- Ver   When        Who           Descr
  -- ----  ----------  ------------  -----------------------------------------------------
  -- 1.0   07/12/2020  Roman W.      CHG0048579 - OIC new integration tool implementation
  ----------------------------------------------------------------------------------------
  FUNCTION get_instance RETURN VARCHAR2 IS
    ---------------------------
    --  Local definition
    ---------------------------
    l_instance VARCHAR2(240);
    ---------------------------
    --    Code Section
    ---------------------------
  BEGIN
  
    --l_instance := replace (sys_context('USERENV', 'INSTANCE_NAME'),'CDB');
    l_instance := sys_context('userenv', 'db_name');
  
    RETURN l_instance;
  
  END get_instance;
  -------------------------------------------------------------------------------------------
  -- Ver    When         Who           Descr
  -- ----   -----------  ------------  ------------------------------------------------------
  -- 1.0    21/12/2020   Roman W.       CHG0048579 - OIC new integration tool implementation
  -------------------------------------------------------------------------------------------
  FUNCTION xml_replace_special_chr(p_str VARCHAR2) RETURN VARCHAR2 IS
    --------------------------
    --    Local Definition
    --------------------------
    CURSOR xml_spec_chr_cur IS
      SELECT ffv.flex_value old_value, ffv.description new_value
        FROM fnd_flex_value_sets ffvs, fnd_flex_values_vl ffv
       WHERE ffvs.flex_value_set_name = 'XXSSYS_XML_SPECIAL_CHARS'
         AND ffv.enabled_flag = 'Y'
         AND trunc(SYSDATE) BETWEEN
             nvl(ffv.start_date_active, trunc(SYSDATE)) AND
             nvl(ffv.end_date_active, trunc(SYSDATE))
         AND ffv.flex_value_set_id = ffvs.flex_value_set_id;
  
    l_ret_value VARCHAR2(1000);
    --------------------------
    --    Code Section
    --------------------------
  BEGIN
    l_ret_value := p_str;
    FOR xml_spec_chr_ind IN xml_spec_chr_cur LOOP
      l_ret_value := REPLACE(l_ret_value,
                             xml_spec_chr_ind.old_value,
                             xml_spec_chr_ind.new_value);
    END LOOP;
  
    RETURN l_ret_value;
  
  END xml_replace_special_chr;
  ----------------------------------------------------------------------------------------
  -- Ver   When        Who           Descr
  -- ----  ----------  ------------  -----------------------------------------------------
  -- 1.0   07/12/2020  Roman W.      CHG0048579 - OIC new integration tool implementation
  ----------------------------------------------------------------------------------------
  FUNCTION encrypt(p_str VARCHAR2) RETURN VARCHAR2 IS
    ------------------------
    --  Local Definition
    ------------------------
    l_ret_val      VARCHAR2(240);
    l_cipheredtext RAW(500);
    l_plaintext    RAW(200);
    l_key          VARCHAR2(120);
    l_test         VARCHAR2(500);
    ------------------------
    --  Code Section
    ------------------------
  BEGIN
  
    l_plaintext := utl_raw.cast_to_raw(p_str);
  
    l_cipheredtext := dbms_crypto.encrypt(src => l_plaintext,
                                          typ => c_type,
                                          key => c_key);
  
    RETURN l_cipheredtext;
  
  END encrypt;

  ----------------------------------------------------------------------------------------
  -- Ver   When        Who           Descr
  -- ----  ----------  ------------  -----------------------------------------------------
  -- 1.0   07/12/2020  Roman W.      CHG0048579 - OIC new integration tool implementation
  ----------------------------------------------------------------------------------------
  FUNCTION decrypt(p_str RAW) RETURN VARCHAR2 IS
    ------------------------
    --  Local Definition
    ------------------------
    l_plaintext  RAW(200);
    l_deciphered VARCHAR2(500);
    l_ret_val    VARCHAR2(240);
    l_key        VARCHAR2(120);
    l_ret_value  VARCHAR2(120);
    ------------------------
    --  Code Section
    ------------------------
  
  BEGIN
  
    --    l_plaintext  := UTL_RAW.cast_to_raw(p_str);
    l_deciphered := dbms_crypto.decrypt(src => p_str, -- l_plaintext,
                                        typ => c_type,
                                        key => c_key);
  
    RETURN utl_raw.cast_to_varchar2(l_deciphered);
  EXCEPTION
    WHEN OTHERS THEN
      message('EXCEPTION_OTHERS : XXSSYS_OIC_UTIL_PKG.decrypt()-' ||
              SQLERRM);
      RETURN NULL;
  END decrypt;

  ---------------------------------------------------------------------------
  -- Ver    When         Who           Descr
  -- -----  -----------  ------------  --------------------------------------
  -- 1.0    16/12/2020   Roman W.      CHG0048579
  ---------------------------------------------------------------------------
  FUNCTION get_service_oic_enable_flag(p_service IN VARCHAR2) RETURN VARCHAR2 IS
    ---------------------------
    --    Local Definitioin
    ---------------------------
    l_enable_flag VARCHAR2(10);
    ---------------------------
    --    Code Section
    ---------------------------
  BEGIN
    SELECT ffv.attribute1 enable_flag
      INTO l_enable_flag
      FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv
     WHERE ffvs.flex_value_set_name = 'XXSSYS_OIC_SERVICE'
       AND ffv.flex_value_set_id = ffvs.flex_value_set_id
       AND ffv.enabled_flag = 'Y'
       AND trunc(SYSDATE) BETWEEN
           nvl(ffv.start_date_active, trunc(SYSDATE)) AND
           nvl(ffv.end_date_active, trunc(SYSDATE))
       AND ffv.flex_value = p_service;
  
    RETURN l_enable_flag;
  EXCEPTION
    WHEN OTHERS THEN
      l_enable_flag := 'N';
      RETURN l_enable_flag;
  END get_service_oic_enable_flag;
  -------------------------------------------------------------------------------------
  -- Ver   When        Who        Descr
  -- ----  ----------  ---------  -----------------------------------------------------
  -- 1.0   10/12/2020  Roman W.   CHG0048579 - OIC new integration tool implementation
  --                                  DFF : Flexfield Segment Values (Application Object Library) / XXSSYS_OIC_SERVICE
  -- 1.1   31/05/2021  Roman W.   CHG0048579 - OIC
  -------------------------------------------------------------------------------------
  PROCEDURE get_service_details(p_service     IN VARCHAR2,
                                p_enable_flag OUT VARCHAR2,
                                p_url         OUT VARCHAR2,
                                p_wallet_loc  OUT VARCHAR2,
                                p_wallet_pwd  OUT VARCHAR2,
                                p_auth_user   OUT VARCHAR2,
                                p_auth_pwd    OUT VARCHAR2,
                                p_error_code  OUT VARCHAR2,
                                p_error_desc  OUT VARCHAR2) IS
  
    ----------------------------
    --    Local Definition
    ----------------------------
    l_host         VARCHAR2(500);
    l_service_host VARCHAR2(500);
    l_service_path VARCHAR2(500);
    ----------------------------
    --    Code Section
    ----------------------------
  BEGIN
    p_error_code := '0';
    p_error_desc := NULL;
  
    SELECT ffv.attribute1 enable_flag,
           ffv.attribute2 host,
           ffv.attribute3 service_path
      INTO p_enable_flag, l_service_host, l_service_path
      FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv
     WHERE ffvs.flex_value_set_name = 'XXSSYS_OIC_SERVICE'
       AND ffv.flex_value_set_id = ffvs.flex_value_set_id
       AND ffv.enabled_flag = 'Y' -- Added By Roman W. 31/05/2021 
       AND ffv.flex_value = p_service;
  
    IF 'Y' = p_enable_flag THEN
    
      get_end_point_details(p_host       => l_host,
                            p_wallet_loc => p_wallet_loc,
                            p_wallet_pwd => p_wallet_pwd,
                            p_auth_user  => p_auth_user,
                            p_auth_pwd   => p_auth_pwd,
                            p_error_code => p_error_code,
                            p_error_desc => p_error_desc);
    END IF;
  
    p_url := nvl(l_service_host, l_host) || l_service_path;
  
  EXCEPTION
    WHEN OTHERS THEN
      p_error_code := '2';
      p_error_desc := 'EXCEPTION_OTHER XXSSYS_OIC_UTIL_PKG.get_service_details() - ' ||
                      SQLERRM;
    
  END get_service_details;

  -------------------------------------------------------------------------------------
  -- Ver   When        Who        Descr
  -- ----  ----------  ---------  -----------------------------------------------------
  -- 1.0   10/12/2020  Roman W.   CHG0048579 - OIC new integration tool implementation
  --                                  DFF : Flexfield Segment Values (Application Object Library) / XXSSYS_OIC_SERVICE
  -- 1.1   31/05/2021  Roman W.   CHG0048579 - OIC
  -------------------------------------------------------------------------------------
  PROCEDURE get_service_details2(p_service     IN VARCHAR2,
                                 p_enable_flag OUT VARCHAR2,
                                 p_url         OUT VARCHAR2,
                                 p_wallet_loc  OUT VARCHAR2,
                                 p_wallet_pwd  OUT VARCHAR2,
                                 p_auth_user   OUT VARCHAR2,
                                 p_auth_pwd    OUT VARCHAR2,
                                 p_token       OUT VARCHAR2,
                                 p_error_code  OUT VARCHAR2,
                                 p_error_desc  OUT VARCHAR2) IS
  
    ----------------------------
    --    Local Definition
    ----------------------------
    l_host         VARCHAR2(500);
    l_service_host VARCHAR2(500);
    l_service_path VARCHAR2(500);
    ----------------------------
    --    Code Section
    ----------------------------
  BEGIN
    p_error_code := '0';
    p_error_desc := NULL;
  
    SELECT ffv.attribute1 enable_flag,
           ffv.attribute2 host,
           ffv.attribute3 service_path
      INTO p_enable_flag, l_service_host, l_service_path
      FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv
     WHERE ffvs.flex_value_set_name = 'XXSSYS_OIC_SERVICE'
       AND ffv.flex_value_set_id = ffvs.flex_value_set_id
       AND ffv.enabled_flag = 'Y' -- Added By Roman W. 31/05/2021 
       AND ffv.flex_value = p_service;
  
    IF 'Y' = p_enable_flag THEN
    
      get_end_point_details2(p_host       => l_host,
                             p_wallet_loc => p_wallet_loc,
                             p_wallet_pwd => p_wallet_pwd,
                             p_auth_user  => p_auth_user,
                             p_auth_pwd   => p_auth_pwd,
                             p_token      => p_token,
                             p_error_code => p_error_code,
                             p_error_desc => p_error_desc);
    END IF;
  
    p_url := nvl(l_service_host, l_host) || l_service_path;
  
  EXCEPTION
    WHEN OTHERS THEN
      p_error_code := '2';
      p_error_desc := 'EXCEPTION_OTHER XXSSYS_OIC_UTIL_PKG.get_service_details2(' ||
                      p_service || ') - ' || SQLERRM;
    
  END get_service_details2;

  ----------------------------------------------------------------------------------------
  -- Ver   When        Who           Descr
  -- ----  ----------  ------------  -----------------------------------------------------
  -- 1.0   07/12/2020  Roman W.      CHG0048579 - OIC new integration tool implementation
  --                                     DFF : Flexfield Segment Values (Application Object Library) / XXSSYS_OIC_ENDPOINT
  ----------------------------------------------------------------------------------------
  PROCEDURE get_end_point_details(p_host       OUT VARCHAR2,
                                  p_wallet_loc OUT VARCHAR2,
                                  p_wallet_pwd OUT VARCHAR2,
                                  p_auth_user  OUT VARCHAR2,
                                  p_auth_pwd   OUT VARCHAR2,
                                  p_error_code OUT VARCHAR2,
                                  p_error_desc OUT VARCHAR2) IS
    -----------------------
    --  Local Definition
    -----------------------
    l_instance  VARCHAR2(120);
    l_end_point VARCHAR2(500);
    -----------------------
    --   Code Section
    -----------------------
  BEGIN
    p_error_code := '0';
    p_error_desc := NULL;
  
    l_instance := get_instance;
  
    SELECT ffv.attribute1 host,
           'file:' || ffv.attribute2 wallet_loc,
           xxssys_oic_util_pkg.decrypt(ffv.attribute3) wallet_pwd,
           ffv.attribute4 auth_user,
           xxssys_oic_util_pkg.decrypt(ffv.attribute5) auth_pwd
      INTO p_host, p_wallet_loc, p_wallet_pwd, p_auth_user, p_auth_pwd
      FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv
     WHERE ffvs.flex_value_set_name = 'XXSSYS_OIC_ENDPOINT'
       AND ffv.flex_value_set_id = ffvs.flex_value_set_id
       AND ffv.flex_value = l_instance;
  
  EXCEPTION
    WHEN OTHERS THEN
      p_error_code := '2';
      p_error_desc := 'EXCEPTION_OTHERS XXSSYS_OIC_UTIL_PKG.get_end_point_details() - ' ||
                      SQLERRM;
    
  END get_end_point_details;
  ----------------------------------------------------------------------------------------
  -- Ver   When        Who           Descr
  -- ----  ----------  ------------  -----------------------------------------------------
  -- 1.0   07/12/2020  Roman W.      CHG0048579 - OIC new integration tool implementation
  --                                     DFF : Flexfield Segment Values (Application Object Library) / XXSSYS_OIC_ENDPOINT
  ----------------------------------------------------------------------------------------
  PROCEDURE get_end_point_details2(p_host       OUT VARCHAR2,
                                   p_wallet_loc OUT VARCHAR2,
                                   p_wallet_pwd OUT VARCHAR2,
                                   p_auth_user  OUT VARCHAR2,
                                   p_auth_pwd   OUT VARCHAR2,
                                   p_token      OUT VARCHAR2,
                                   p_error_code OUT VARCHAR2,
                                   p_error_desc OUT VARCHAR2) IS
    -----------------------
    --  Local Definition
    -----------------------
    l_instance  VARCHAR2(120);
    l_end_point VARCHAR2(500);
    -----------------------
    --   Code Section
    -----------------------
  BEGIN
    p_error_code := '0';
    p_error_desc := NULL;
  
    l_instance := get_instance;
  
    SELECT ffv.attribute1 host,
           'file:' || ffv.attribute2 wallet_loc,
           xxssys_oic_util_pkg.decrypt(ffv.attribute3) wallet_pwd,
           ffv.attribute4 auth_user,
           xxssys_oic_util_pkg.decrypt(ffv.attribute5) auth_pwd,
           ffv.attribute6 token
      INTO p_host,
           p_wallet_loc,
           p_wallet_pwd,
           p_auth_user,
           p_auth_pwd,
           p_token
      FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv
     WHERE ffvs.flex_value_set_name = 'XXSSYS_OIC_ENDPOINT'
       AND ffv.flex_value_set_id = ffvs.flex_value_set_id
       AND ffv.flex_value = l_instance;
  
  EXCEPTION
    WHEN OTHERS THEN
      p_error_code := '2';
      p_error_desc := 'EXCEPTION_OTHERS XXSSYS_OIC_UTIL_PKG.get_end_point_details2() - ' ||
                      SQLERRM;
    
  END get_end_point_details2;

  ---------------------------------------------------------------------------
  -- Ver   When        Who        Descr
  -- ----  ----------  ---------  -------------------------------------------
  -- 1.0   08/12/2020  Roman W.   CHG0048579 - OIC
  ---------------------------------------------------------------------------
  PROCEDURE update_pwd_attr_conc(errbuf              OUT VARCHAR2,
                                 retcode             OUT NUMBER,
                                 p_flex_value_set_id IN NUMBER,
                                 p_flex_value_id     IN NUMBER,
                                 p_attr_name         IN VARCHAR2,
                                 p_attr_value        IN VARCHAR2) IS
    ----------------------------
    --    Local Definition
    ----------------------------
    l_attr_decrypt_val VARCHAR2(500);
    ----------------------------
    --    Code Section
    ----------------------------
  BEGIN
    errbuf  := NULL;
    retcode := '0';
  
    l_attr_decrypt_val := xxssys_oic_util_pkg.encrypt(p_str => p_attr_value);
  
    CASE p_attr_name
    
      WHEN 'ATTRIBUTE3' THEN
      
        UPDATE fnd_flex_values ffv
           SET ffv.attribute3 = l_attr_decrypt_val
         WHERE flex_value_set_id = p_flex_value_set_id
           AND flex_value_id = p_flex_value_id;
      
        COMMIT;
      
      WHEN 'ATTRIBUTE5' THEN
      
        UPDATE fnd_flex_values ffv
           SET ffv.attribute5 = l_attr_decrypt_val
         WHERE flex_value_set_id = p_flex_value_set_id
           AND flex_value_id = p_flex_value_id;
      
        COMMIT;
      
    END CASE;
  
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'EXCEPTION_OTHERS XXSSYS_OIC_UTIL_PKG.update_pwd_attr_conc(' ||
                 p_flex_value_set_id || ',' || p_flex_value_id || ',' ||
                 p_attr_name || ',' || p_attr_value || ') - ' || SQLERRM;
      retcode := '2';
    
  END update_pwd_attr_conc;
  ---------------------------------------------------------------------------
  -- Ver   When        Who        Descr
  -- ----  ----------  ---------  -------------------------------------------
  -- 1.0   08/12/2020  Roman W.   CHG0048579 - OIC
  ---------------------------------------------------------------------------
  PROCEDURE update_pwd_attr(p_flex_value_set_id IN NUMBER,
                            p_flex_value_id     IN NUMBER,
                            p_attr_name         IN VARCHAR2,
                            p_attr_value        IN VARCHAR2,
                            p_request_id        OUT NUMBER) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
    ---------------------------
    --   Code Section
    ---------------------------
  BEGIN
  
    p_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                               program     => 'XXSSYS_OIC_UPDATE_PWD_ATTR', -- XXSSYS_OIC_UTIL_PKG.update_pwd_attr_conc
                                               description => NULL,
                                               start_time  => to_char(SYSDATE + (5 /
                                                                      86400),
                                                                      'DD-MON-YYYY HH24:MI:SS'),
                                               sub_request => FALSE,
                                               argument1   => p_flex_value_set_id,
                                               argument2   => p_flex_value_id,
                                               argument3   => p_attr_name,
                                               argument4   => p_attr_value);
  
    message('REQUEST_ID : ' || p_request_id);
  
    COMMIT;
  
  END update_pwd_attr;

  ------------------------------------------------------------------------------
  -- Ver   When         Who        Descr
  -- ----  -----------  ---------  ---------------------------------------------
  -- 1.0   14/12/2020   Roman W.   CHG0048579 - OIC
  ------------------------------------------------------------------------------
  PROCEDURE html_parser(p_in_text    IN VARCHAR2,
                        p_out_text   OUT VARCHAR2,
                        p_error_code OUT VARCHAR2,
                        p_error_desc OUT VARCHAR2) IS
    ------------------------
    --   Local Definition
    ------------------------
    l_clob     CLOB;
    l_rows     wwv_flow_global.vc_arr2;
    l_row_text VARCHAR2(32000);
    ------------------------
    --   Code Section
    ------------------------
  BEGIN
    p_error_code := '0';
    p_error_desc := NULL;
    p_out_text   := '';
  
    l_clob := to_clob(regexp_replace(p_in_text, '<[^>]+>'));
  
    l_rows := apex_util.string_to_table(l_clob, chr(10));
  
    FOR i IN 1 .. l_rows.count LOOP
      l_row_text := TRIM(REPLACE(l_rows(i), chr(10)));
      IF length(l_row_text) > 0 THEN
        p_out_text := p_out_text || l_rows(i) || chr(10);
      END IF;
    END LOOP;
  
  EXCEPTION
    WHEN OTHERS THEN
      p_error_code := '2';
      p_error_desc := 'EXCEPTION_OTHERS xxom_denied_parties_pkg.html_parser() - ' ||
                      SQLERRM;
  END html_parser;

  ------------------------------------------------------------------------------
  -- Ver   When         Who        Descr
  -- ----  -----------  ---------  ---------------------------------------------
  -- 1.0   14/12/2020   yuval tal   CHG0048579 - OIC
  ------------------------------------------------------------------------------
  PROCEDURE wait(p_sec NUMBER) IS
  BEGIN
  
    dbms_lock.sleep(p_sec);
  END;

END xxssys_oic_util_pkg;
/
