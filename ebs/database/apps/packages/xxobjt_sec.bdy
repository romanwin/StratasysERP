CREATE OR REPLACE PACKAGE BODY xxobjt_sec IS
  
--------------------------------------------------------------------
--  customization code: CUST375 - Security - elemant entries values
--                      CUST422 - MSS - Handle Security
--  name:               xxobjt_sec
--  create by:          yuval tal
--  $Revision:          1.3 
--  creation date:      20/12/2010
--  Purpose :           support hiding salary info 
----------------------------------------------------------------------
--  ver   date          name            desc
--  1.0   20/12/2010    yuval tal       initial build
--  1.1   31/05/2011    yuval tal       add key session support
--  1.2   20/09/2011    Dalit A. Raviv  1) correct function is_upk_exist
--                                      2) g_session_interval value will be handle 
--                                         at profile 15 minutes security will be open
--                                      3) new function disable_session_open
--  1.3   02/05/2013    Dalit A. Raviv  procedure decrypt
--                                      in 12.1.3 one of the employee VO's (MSS)
--                                      have new fiekd that go to elemenent.
--                                      the function can not encrypt the data and fail all the time.
--                                      the solution is to return -1 instead of the encrypt value itself.
----------------------------------------------------------------------- 
  
  -------------------------
  -- Global constants
  -------------------------

  -- session
  -- 1.2 Dalit A. Raviv 20/09/2011
  --g_session_interval CONSTANT NUMBER := 15 / 24 / 60; --fnd_profile.VALUE('XXOBJT_LDAP_SESSION_INTERVAL');
  g_session_interval CONSTANT NUMBER := fnd_profile.VALUE('XXOBJT_MINUTES_SESSION_INTERVAL') / (24 * 60);
  -- end 1.2
  --
  g_date_format VARCHAR2(50) := 'ddmmyyyy hh24:mi:ss';
  -- g_session_var_name CONSTANT VARCHAR2(50) := 'HR_ELEMENT';

  g_max_password_connections CONSTANT NUMBER := 5;
  ---------------------------------------------
  -- repeat_string
  ---------------------------------------------
  FUNCTION repeat_string(str       IN VARCHAR2,
                         times     IN NUMBER DEFAULT 1,
                         delimiter IN CHAR DEFAULT '') RETURN VARCHAR2 IS
    return_value VARCHAR2(32767);
  BEGIN
    IF times = 0 THEN
      RETURN '';
    ELSE
      FOR i IN 1 .. times LOOP
        IF i > 1 THEN
          return_value := return_value || delimiter || str;
        ELSE
          return_value := return_value || str;
        END IF;
      END LOOP;
      RETURN return_value;
    END IF;
  END;

  --------------------------------------------------------
  -- check_hard_pass
  --------------------------------------------------------
  PROCEDURE check_hard_pass(p_pass1       VARCHAR2,
                            p_pass2       VARCHAR2,
                            p_length      NUMBER,
                            p_err_code    OUT NUMBER,
                            p_err_message OUT VARCHAR2) IS
  BEGIN
    IF p_pass1 IS NULL OR p_pass2 IS NULL THEN
    
      p_err_code    := 1;
      p_err_message := 'Password/Token is empty';
      RETURN;
    END IF;
  
    IF p_pass1 != p_pass2 THEN
      p_err_code    := 1;
      p_err_message := 'Repeated new Password is not identical to New password';
      RETURN;
    END IF;
  
    IF length(p_pass1) != p_length THEN
    
      p_err_code    := 1;
      p_err_message := 'Password/Token must be ' || p_length ||
                       ' chars length';
      RETURN;
    END IF;
  
    IF lower(p_pass1) = p_pass1 THEN
    
      p_err_code    := 1;
      p_err_message := 'Password/Token must be mixed lower/upper chars';
      RETURN;
    
    END IF;
  
    p_err_code := 0;
  END;

  ----------------------------------------------
  -- set_upk
  ----------------------------------------------
  PROCEDURE set_upk(p_err_code NUMBER, p_pass VARCHAR2) IS
  
    l_key                      VARCHAR2(8) := substr(repeat_string(fnd_global.user_id,
                                                                   8),
                                                     1,
                                                     8);
    l_encrypted_user_pass_tmp  VARCHAR2(150);
    l_encrypted_last_pass_date VARCHAR2(150);
  
  BEGIN
  
    -- dbms_session.set_context('XXOBJT_SEC', 'UKEY', p_val);
    l_encrypted_user_pass_tmp  := encrypt(p_pass, l_key);
    l_encrypted_last_pass_date := encrypt(to_char(SYSDATE, g_date_format),
                                          l_key);
  
    UPDATE xxobjt_user_sessions t
       SET t.encrypted_user_pass_tmp  = decode(p_err_code,
                                               1,
                                               NULL,
                                               l_encrypted_user_pass_tmp),
           t.encrypted_last_pass_date = decode(p_err_code,
                                               1,
                                               NULL,
                                               l_encrypted_last_pass_date)
     WHERE t.user_id = fnd_global.user_id;
    COMMIT;
  END;

  --------------------------------------------------------------------
  --  name:               get_upk
  --  create by:          Yuval Tal
  --  $Revision:          1.0 
  --  creation date:      xx/xx/2010
  --  Purpose :           call from function is_upk_exist
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   xx/xx/2010    Yuval Tal       initial build
  --  1.1   20/09/2011    Dalit A. Raviv  because this fuction call by is_upk_exist
  --                                      function and it call from form personalization
  --                                      we can not use DML comand.
  ----------------------------------------------------------------------- 
  FUNCTION get_upk RETURN VARCHAR2 IS
    l_tmp         VARCHAR2(240);
    l_tmp2        VARCHAR2(240);
    l_key         VARCHAR2(8) := substr(repeat_string(fnd_global.user_id, 8),
                                        1,
                                        8);
    l_primary_key VARCHAR2(8);
  BEGIN
    /* IF sys_context('XXOBJT_SEC', 'UKEY') IS NOT NULL THEN
      RETURN sys_context('XXOBJT_SEC', 'UKEY');
    ELSE*/
    IF nvl(sys_context('USERENV', 'TERMINAL'), 'unknown') != 'unknown' THEN
      RETURN NULL;
    ELSE
      SELECT t.encrypted_user_key, decrypt(encrypted_user_pass_tmp, l_key)
        INTO l_tmp, l_tmp2
        FROM xxobjt_user_sessions t
       WHERE t.user_id = fnd_global.user_id
         AND to_date(decrypt(t.encrypted_last_pass_date, l_key),
                     g_date_format) > SYSDATE - g_session_interval;
    
      l_primary_key := decrypt(l_tmp, l_tmp2);
    
      RETURN l_primary_key;
    
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
  /*  
      UPDATE xxobjt_user_sessions t
         SET t.encrypted_last_pass_date = NULL,
             t.encrypted_user_pass_tmp  = NULL
       WHERE t.user_id = fnd_global.user_id;
      COMMIT;
  */  
      RETURN NULL;
  END;
  
  ----------------------------------------------
  -- get_pk
  ----------------------------------------------
  FUNCTION get_pk RETURN VARCHAR2 IS
  BEGIN
  
    RETURN sys_context('XXOBJT_SEC', 'PKEY');
  
  END;

  ----------------------------------------------
  -- set_pk
  ----------------------------------------------
  PROCEDURE set_pk(p_val VARCHAR2) IS
  BEGIN
  
    dbms_session.set_context('XXOBJT_SEC', 'PKEY', p_val);
  
  END;

  --------------------------------------------------------------------
  --  name:               is_upk_exist
  --  create by:          Yuval Tal
  --  $Revision:          1.0 
  --  creation date:      xx/xx/2010
  --  Purpose :           This function call from form personalization
  --                      on Entries and performance screens.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   xx/xx/2010    Yuval Tal       initial build
  --  1.1   20/09/2011    Dalit A. Raviv  return to old logic
  ----------------------------------------------------------------------- 
  FUNCTION is_upk_exist RETURN NUMBER IS
  BEGIN
    IF get_upk IS NOT NULL THEN
      RETURN 1;
    ELSE
      RETURN 0;
    END IF;
  
  END;

  --------------------------------------------------------------------
  --  name:               decrypt
  --  create by:          Yuval Tal
  --  $Revision:          1.0 
  --  creation date:      xx/xx/2010
  --  Purpose :           
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   xx/xx/2010    Yuval Tal       initial build
  --  1.1   02/05/2013    Dalit A. Raviv  in 12.1.3 one of the employee VO's (MSS)
  --                                      have new fiekd that go to elemenent.
  --                                      the function can not encrypt the data and fail all the time.
  --                                      the solution is to return -1 instead of the encrypt value itself.
  ----------------------------------------------------------------------- 
  FUNCTION decrypt(p_value VARCHAR2, p_key VARCHAR2 DEFAULT NULL)
    RETURN VARCHAR2 IS
    l_decrypted_raw RAW(2048);
    l_pk            VARCHAR2(50);
    l_pk_raw        RAW(2048);
  BEGIN
  
    -- RETURN decrypt2(p_value);
    IF p_value IS NULL THEN
      RETURN NULL;
    END IF;
    l_pk := p_key;
  
    IF p_key IS NULL THEN
      l_pk := get_upk;
    END IF;
  
    --  1.1   02/05/2013    Dalit A. Raviv
    IF l_pk IS NULL THEN
      RETURN -1;/*p_value;*//* 0;*/
    END IF;
  
    l_pk_raw := utl_raw.cast_to_raw(l_pk);
  
    l_decrypted_raw := sys.dbms_crypto.decrypt(src => p_value,
                                               typ => dbms_crypto.des_cbc_pkcs5,
                                               key => l_pk_raw);
    RETURN utl_raw.cast_to_varchar2(l_decrypted_raw);
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN p_value;
  END;

  --------------------------------------------------
  -- encrypt
  --------------------------------------------------
  FUNCTION encrypt(p_value VARCHAR2, p_key VARCHAR2 DEFAULT NULL)
    RETURN VARCHAR2 IS
    l_encrypted_raw RAW(2048);
    l_value         RAW(2048) := utl_raw.cast_to_raw(p_value);
    l_key           VARCHAR2(50);
    l_key_raw       RAW(2048);
  BEGIN
    IF p_value IS NULL THEN
      RETURN NULL;
    END IF;
  
    l_key := nvl(p_key, get_upk);
  
    IF l_key IS NOT NULL THEN
      l_key_raw       := utl_raw.cast_to_raw(l_key);
      l_encrypted_raw := sys.dbms_crypto.encrypt(src => l_value,
                                                 typ => dbms_crypto.des_cbc_pkcs5,
                                                 key => l_key_raw);
    
      RETURN l_encrypted_raw;
    ELSE
    
      RAISE xxobjt_no_key_found;
    END IF;
  
  END;

  ----------------------------------------------------
  -- get_hash
  ----------------------------------------------------

  FUNCTION get_hash(p_string VARCHAR2) RETURN VARCHAR2 IS
    --l_credit_card_no VARCHAR2(19) := p_string;--'Af78f234';
    l_ccn_raw       RAW(128) := utl_raw.cast_to_raw(p_string);
    l_encrypted_raw RAW(2048);
  BEGIN
  
    l_encrypted_raw := dbms_crypto.HASH(l_ccn_raw, 3);
  
    RETURN l_encrypted_raw;
  
  END;

  --------------------------------------------------------
  -- is_user_pass_valid
  ---------------------------------------------------------
  FUNCTION is_user_pass_valid(p_user_id NUMBER, p_pass VARCHAR) RETURN NUMBER IS
  
    l_encrypted_user_password xxobjt_user_sessions.encrypted_user_password%TYPE;
  
  BEGIN
  
    SELECT encrypted_user_password
      INTO l_encrypted_user_password
      FROM xxobjt_user_sessions t
     WHERE t.active_flag = 'Y'
       AND t.user_id = p_user_id;
  
    IF get_hash(p_pass) = l_encrypted_user_password THEN
    
      dbms_session.set_context('XXOBJT_SEC', 'LOG_COUNT', 0);
      RETURN 1;
    ELSE
      dbms_session.set_context('XXOBJT_SEC',
                               'LOG_COUNT',
                               nvl(sys_context('XXOBJT_SEC', 'LOG_COUNT'),
                                   0) + 1);
    
      RETURN 0;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 0;
  END;
  
  -----------------------------------------------
  -- get_token_status
  ------------------------------------------------
  FUNCTION get_user_status RETURN VARCHAR2 IS
    l_tmp VARCHAR2(50);
  
  BEGIN
  
    l_tmp := get_upk;
  
    IF get_hash(l_tmp) = fnd_profile.VALUE('XXOBJT_SEC_HASH_KEY') THEN
    
      RETURN 'Connected';
    
    ELSE
      RETURN 'Not Connected';
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN SQLERRM;
  END;
  
  ----------------------------------------------------------
  -- insert_user
  ----------------------------------------------------------
  PROCEDURE insert_user(p_user_id     NUMBER,
                        p_pass1       VARCHAR2,
                        p_pass2       VARCHAR2,
                        p_err_code    OUT NUMBER,
                        p_err_message OUT VARCHAR2) IS
    l_hash_user_pass     xxobjt_user_sessions.encrypted_user_password%TYPE;
    l_encrypted_user_key xxobjt_user_sessions.encrypted_user_key%TYPE;
  
    l_primary_key VARCHAR2(200);
    l_person_id   NUMBER;
  BEGIN
    p_err_code    := 0;
    p_err_message := 'Starting....';
    l_primary_key := get_pk;
    IF l_primary_key IS NULL THEN
    
      p_err_code    := 1;
      p_err_message := 'Error: Primary Key is not set';
      RETURN;
    
    END IF;
    -- check user_pass
    check_hard_pass(p_pass1       => p_pass1,
                    p_pass2       => p_pass2,
                    p_length      => 8,
                    p_err_code    => p_err_code,
                    p_err_message => p_err_message);
    IF p_err_code = 1 THEN
      RETURN;
    END IF;
    --
    l_hash_user_pass := get_hash(p_pass1);
  
    l_encrypted_user_key := encrypt(p_value => l_primary_key, --- ???????replace with session param
                                    p_key   => p_pass1);
    SELECT employee_id
      INTO l_person_id
      FROM fnd_user u
     WHERE u.user_id = p_user_id;
  
    INSERT INTO xxobjt_user_sessions
    
      (user_id,
       person_id,
       encrypted_user_password,
       encrypted_user_key,
       log_counter,
       active_flag,
       last_update_date,
       last_updated_by,
       creation_date,
       created_by,
       last_update_login)
    VALUES
      (p_user_id,
       l_person_id,
       l_hash_user_pass,
       l_encrypted_user_key,
       0,
       'Y',
       NULL,
       NULL,
       SYSDATE,
       fnd_global.user_id,
       fnd_global.login_id);
    COMMIT;
    p_err_message := 'Employee Successfully Added';
  EXCEPTION
  
    WHEN dup_val_on_index THEN
    
      UPDATE xxobjt_user_sessions t
         SET person_id               = l_person_id,
             encrypted_user_password = l_hash_user_pass,
             encrypted_user_key      = l_encrypted_user_key,
             log_counter             = 0,
             attribute1              = NULL,
             attribute2              = NULL,
             active_flag             = 'Y',
             last_update_date        = SYSDATE,
             last_updated_by         = fnd_global.user_id,
             last_update_login       = fnd_global.login_id
       WHERE user_id = p_user_id;
      COMMIT;
      p_err_message := 'Employee Successfully Updated';
    WHEN OTHERS THEN
      p_err_code    := 1;
      p_err_message := 'Error Insert/Update Employee :' || SQLERRM;
    
  END;
  
  --------------------------------------------------------
  -- update_user_pass
  ---------------------------------------------------------
  PROCEDURE change_user_pass(p_old_pass    VARCHAR2,
                             p_new_pass1   VARCHAR2,
                             p_new_pass2   VARCHAR2,
                             p_err_code    OUT NUMBER,
                             p_err_message OUT VARCHAR2) IS
  
    l_hash_user_pass     xxobjt_user_sessions.encrypted_user_password%TYPE;
    l_encrypted_user_key xxobjt_user_sessions.encrypted_user_key%TYPE;
    l_user_id            NUMBER := fnd_global.user_id;
  BEGIN
    p_err_code := 0;
  
    -- check current pass
  
    IF is_user_pass_valid(l_user_id, p_old_pass) = 0 THEN
      p_err_code    := 1;
      p_err_message := 'Current User/Password is invalid, try again';
      RETURN;
    END IF;
  
    ---
  
    check_hard_pass(p_pass1       => p_new_pass1,
                    p_pass2       => p_new_pass2,
                    p_length      => 8,
                    p_err_code    => p_err_code,
                    p_err_message => p_err_message);
    IF p_err_code = 1 THEN
      RETURN;
    END IF;
  
    --
  
    IF p_old_pass = p_new_pass1 THEN
    
      p_err_code    := 1;
      p_err_message := 'New password should be different then old password!';
      RETURN;
    
    END IF;
  
    ------------- set session with primary PK
    xxobjt_sec.upload_user_session_key(p_pass        => p_old_pass,
                                       p_err_code    => p_err_code,
                                       p_err_message => p_err_message);
  
    --IF p_err_code = 0 THEN
  
    l_hash_user_pass     := get_hash(p_new_pass2);
    l_encrypted_user_key := encrypt(p_value => get_upk, --- ???????replace with session param
                                    p_key   => p_new_pass2);
  
    -- upadte new enc user key
  
    UPDATE xxobjt_user_sessions t
       SET encrypted_user_password = l_hash_user_pass,
           t.log_counter           = t.log_counter + 1,
           encrypted_user_key      = l_encrypted_user_key,
           last_update_date        = SYSDATE,
           last_updated_by         = fnd_global.user_id,
           last_update_login       = fnd_global.login_id
     WHERE user_id = l_user_id;
  
    xxobjt_sec.upload_user_session_key( /*p_user_id     => l_user_id,*/p_pass        => p_new_pass2,
                                       p_err_code    => p_err_code,
                                       p_err_message => p_err_message);
    IF p_err_code = 0 THEN
      COMMIT;
      p_err_code    := 0;
      p_err_message := 'Password Changed';
    ELSE
      ROLLBACK;
      p_err_message := 'Unable to change Password, ' || p_err_message;
    END IF;
  
    -- END IF;
    ------------------------
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code    := 1;
      p_err_message := 'Error Insert/Update user :' || SQLERRM;
  END;

  ---------------------------------------------------------
  -- upload_primary_key
  --
  -- when add/remove users
  -------------------------------------------------------------
  PROCEDURE upload_primary_key(p_token1      VARCHAR2,
                               p_token2      VARCHAR2,
                               p_err_code    OUT NUMBER,
                               p_err_message OUT VARCHAR2) IS
  
  BEGIN
    p_err_code := 0;
  
    -- dbms_output.put_line('get_hash' || get_hash(p_token1 || p_token2));
  
    IF get_hash(p_token1 || p_token2) =
       fnd_profile.VALUE('XXOBJT_SEC_HASH_KEY') THEN
    
      set_pk(p_token1 || p_token2);
    
    ELSE
      p_err_code    := 1;
      p_err_message := 'Error: Wrong Tokens , action failed!.';
      RETURN;
    END IF;
    p_err_message := 'Tokens uploaded successfully';
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code    := 1;
      p_err_message := 'Error : Action failed ' || SQLERRM;
  END;

  -----------------------------------------------------------
  -- set_user_session_key
  -- 
  -- wil be done only when adding users
  -----------------------------------------------------------  
  PROCEDURE upload_user_session_key(p_pass        VARCHAR,
                                    p_err_code    OUT NUMBER,
                                    p_err_message OUT VARCHAR2) IS
  
    l_encrypted_user_key xxobjt_user_sessions.encrypted_user_key%TYPE;
    l_decrypted_raw      RAW(2048);
    l_user_key           VARCHAR2(200) := utl_raw.cast_to_raw(p_pass);
    l_primary_key        VARCHAR2(150);
    l_user_id            NUMBER := fnd_global.user_id;
  
  BEGIN
    p_err_code := 0;
  
    IF sys_context('XXOBJT_SEC', 'LOG_COUNT') > g_max_password_connections THEN
    
      p_err_code    := 1;
      p_err_message := 'Wrong Password , user Locked !';
    
      UPDATE xxobjt_user_sessions t
         SET t.active_flag = 'N'
       WHERE t.user_id = fnd_global.user_id;
      COMMIT;
      RETURN;
    
    END IF;
  
    IF is_user_pass_valid(fnd_global.user_id, p_pass) = 1 THEN
    
      SELECT t.encrypted_user_key
        INTO l_encrypted_user_key
        FROM xxobjt_user_sessions t
       WHERE t.user_id = l_user_id;
      --  dbms_output.put_line('l_user_key=' || l_user_key);
    
      l_decrypted_raw := sys.dbms_crypto.decrypt(src => l_encrypted_user_key,
                                                 typ => dbms_crypto.des_cbc_pkcs5,
                                                 key => l_user_key);
    
      l_primary_key := utl_raw.cast_to_varchar2(l_decrypted_raw);
    
      IF get_hash(l_primary_key) !=
         fnd_profile.VALUE('XXOBJT_SEC_HASH_KEY') THEN
        p_err_code    := 1;
        p_err_message := 'Encrypted Primary key is not valid , user should be register again by admin';
        RETURN;
      END IF;
    
      -- dbms_output.put_line(l_primary_key);
    
      -- set_upk(l_primary_key);
      p_err_message := 'User/Password is valid';
    ELSE
      --  set_upk(NULL);
      p_err_code    := 1;
      p_err_message := 'User/Password is not valid';
    END IF;
  
    set_upk(p_err_code, p_pass);
  
  END;

  ------------------------------------------------
  -- upload_user_session_key
  ------------------------------------------------
  FUNCTION upload_user_session_key(p_pass VARCHAR) RETURN NUMBER IS
  
    l_err_code NUMBER;
    l_err_msg  VARCHAR2(500);
  
  BEGIN
  
    upload_user_session_key(p_pass        => p_pass,
                            p_err_code    => l_err_code,
                            p_err_message => l_err_msg);
  
    IF l_err_code = 0 THEN
      RETURN 0;
    ELSE
      RETURN 1;
    END IF;
  
  END;

  ----------------------------------------------------
  -- is_primary_key_exist
  ----------------------------------------------------
  FUNCTION is_primary_hash_key_exist RETURN NUMBER IS
  
  BEGIN
  
    IF fnd_profile.VALUE('XXOBJT_SEC_HASH_KEY') IS NOT NULL THEN
      RETURN 1;
    ELSE
      RETURN 0;
    END IF;
  
  END;

  ----------------------------------------------------
  -- init_primary_key
  --
  -- first load by admin users
  ----------------------------------------------------
  PROCEDURE init_primary_key(p_token1_1    VARCHAR2,
                             p_token1_2    VARCHAR2,
                             p_token2_1    VARCHAR2,
                             p_token2_2    VARCHAR2,
                             p_update      VARCHAR2 DEFAULT 'N',
                             p_err_code    OUT NUMBER,
                             p_err_message OUT VARCHAR2) IS
    l_ret BOOLEAN;
  
    l_hash_key VARCHAR2(200);
  BEGIN
    p_err_code := 0;
  
    IF nvl(p_update, 'N') = 'N' AND is_primary_hash_key_exist = 1 THEN
      p_err_code    := 1;
      p_err_message := 'Error: Primary Hash key already exist, please contact administrator';
      RETURN;
    END IF;
  
    xxobjt_sec.check_hard_pass(p_pass1       => p_token1_1,
                               p_pass2       => p_token1_2,
                               p_length      => 4,
                               p_err_code    => p_err_code,
                               p_err_message => p_err_message);
    IF p_err_code = 1 THEN
      p_err_message := 'Token1:' || p_err_message;
      RETURN;
    
    END IF;
  
    xxobjt_sec.check_hard_pass(p_pass1       => p_token2_1,
                               p_pass2       => p_token2_2,
                               p_length      => 4,
                               p_err_code    => p_err_code,
                               p_err_message => p_err_message);
    IF p_err_code = 1 THEN
      p_err_message := 'Token2:' || p_err_message;
      RETURN;
    
    END IF;
  
    l_hash_key := get_hash(p_token1_1 || p_token2_1);
  
    l_ret         := fnd_profile_server.SAVE(x_name       => 'XXOBJT_SEC_HASH_KEY',
                                             x_value      => l_hash_key,
                                             x_level_name => 'SITE');
    p_err_message := 'Token successfully saved';
    IF NOT l_ret THEN
      p_err_code    := 1;
      p_err_message := 'Profile update failed';
      RETURN;
    END IF;
    COMMIT;
  
  EXCEPTION
  
    WHEN OTHERS THEN
      p_err_code    := 1;
      p_err_message := SQLERRM;
  END;

  ------------------------------------
  -- change_key
  ------------------------------------
  PROCEDURE change_key(p_old_key     VARCHAR2,
                       p_new_key1_1  VARCHAR2,
                       p_new_key1_2  VARCHAR2,
                       p_new_key2_1  VARCHAR2,
                       p_new_key2_2  VARCHAR2,
                       p_err_code    OUT NUMBER,
                       p_err_message OUT VARCHAR2) IS
    l_old_key VARCHAR2(150);
  BEGIN
    p_err_code := 0;
    --  p_err_message := 'Action not supported yet';
    -- RETURN; -- check old pass against profile hash current pk
    -- if OK 
    xxobjt_sec.upload_primary_key(p_token1      => substr(p_old_key, 1, 4),
                                  p_token2      => substr(p_old_key, 5, 4),
                                  p_err_code    => p_err_code,
                                  p_err_message => p_err_message);
    IF p_err_code = 1 THEN
      p_err_message := 'Error: Old Tokens , failed validation';
      RETURN;
    END IF;
  
    l_old_key := get_pk;
  
    -- backup tables encrypted fields
  
    EXECUTE IMMEDIATE 'truncate table xxobjt.xxpay_element_entry_values_bck';
    INSERT INTO xxpay_element_entry_values_bck
      SELECT * FROM hr.pay_element_entry_values_f;
    COMMIT;
  
    EXECUTE IMMEDIATE 'truncate table xxobjt.xxper_performance_reviews_bck';
    INSERT INTO xxper_performance_reviews_bck
      SELECT * FROM hr.per_performance_reviews;
  
    -- call init primary_key with update flag='Y'
    xxobjt_sec.init_primary_key(p_token1_1    => p_new_key1_1,
                                p_token1_2    => p_new_key1_2,
                                p_token2_1    => p_new_key2_1,
                                p_token2_2    => p_new_key2_2,
                                p_update      => 'Y',
                                p_err_code    => p_err_code,
                                p_err_message => p_err_message);
  
    IF p_err_code = 1 THEN
      ROLLBACK;
      p_err_message := 'Action failed ,' || p_err_message;
      RETURN;
    ELSE
      -- decrypt(old key) all fields and re-encrypt(new key)(DB trigger)
    
      upload_primary_key(p_token1      => p_new_key1_1,
                         p_token2      => p_new_key2_1,
                         p_err_code    => p_err_code,
                         p_err_message => p_err_message);
    
      IF p_err_code = 1 THEN
        ROLLBACK;
        p_err_message := 'Action failed ,' || p_err_message;
        RETURN;
      ELSE
      
        set_upk(0, get_pk);
      
        ------ update table
        UPDATE hr.pay_element_entry_values_f t
           SET t.screen_entry_value = decrypt(t.screen_entry_value,
                                              l_old_key);
      
        UPDATE hr.per_performance_reviews p
           SET p.performance_rating = encrypt(decrypt(p.performance_rating,
                                                      l_old_key));
        COMMIT;
      
        --------------------
      END IF;
    END IF;
    --   update all users to disable 
    UPDATE xxobjt_user_sessions t
       SET t.encrypted_user_password = NULL,
           t.encrypted_user_key      = NULL,
           t.active_flag             = 'N';
    p_err_message := 'Action completed successfully, All users need new Passwords';
    COMMIT;
  EXCEPTION
  
    WHEN OTHERS THEN
      ROLLBACK;
      xxobjt_sec.init_primary_key(p_token1_1    => substr(p_old_key, 1, 4),
                                  p_token1_2    => substr(p_old_key, 1, 4),
                                  p_token2_1    => substr(p_old_key, 5, 4),
                                  p_token2_2    => substr(p_old_key, 5, 4),
                                  p_update      => 'Y',
                                  p_err_code    => p_err_code,
                                  p_err_message => p_err_message);
      p_err_code    := 1;
      p_err_message := 'Action failed ,' || SQLERRM;
    
  END;

  ----------------------------------------------
  -- get_user_login_count
  -----------------------------------------------
  FUNCTION get_user_login_count(p_user_id NUMBER) RETURN NUMBER IS
    l_tmp NUMBER;
  BEGIN
  
    SELECT t.log_counter
      INTO l_tmp
      FROM xxobjt_user_sessions t
     WHERE t.active_flag = 'Y'
       AND user_id = p_user_id;
  
    RETURN l_tmp;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN - 1;
  END;
  
  --------------------------------------------------------------------
  --  name:               disable_session_open
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0 
  --  creation date:      20/09/2011
  --  Purpose:            This function will call from MSS.
  --                      each time MSS will open customer will nead to 
  --                      enter security password.
  --  Return:             0 - Success
  --                      1 - Filure       
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   20/09/2011    Dalit A. Raviv  initial build
  ----------------------------------------------------------------------- 
  function disable_session_open return number is
  
  begin
    UPDATE xxobjt_user_sessions t
    SET    t.encrypted_last_pass_date = NULL,
           t.encrypted_user_pass_tmp  = NULL
    WHERE  t.user_id                  = fnd_global.user_id;
    
    commit;
    return 0;
  exception
    when others then
       return 1;

  end disable_session_open;
  
END;
/
