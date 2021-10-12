CREATE OR REPLACE PACKAGE xxobjt_sec IS

--------------------------------------------------------------------
--  customization code: CUST375 - Security - elemant entries values
--                      CUST422 - MSS - Handle Security
--  name:               xxobjt_sec
--  create by:          yuval tal
--  $Revision:          1.0 
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
-----------------------------------------------------------------------  


  xxobjt_no_key_found EXCEPTION;

  FUNCTION encrypt(p_value VARCHAR2, p_key VARCHAR2 DEFAULT NULL)
    RETURN VARCHAR2;
  FUNCTION decrypt(p_value VARCHAR2, p_key VARCHAR2 DEFAULT NULL)
    RETURN VARCHAR2;
  FUNCTION get_user_status RETURN VARCHAR2;

  PROCEDURE insert_user(p_user_id     NUMBER,
                        p_pass1       VARCHAR2,
                        p_pass2       VARCHAR2,
                        p_err_code    OUT NUMBER,
                        p_err_message OUT VARCHAR2);

  PROCEDURE upload_user_session_key(p_pass        VARCHAR,
                                    p_err_code    OUT NUMBER,
                                    p_err_message OUT VARCHAR2);

  FUNCTION upload_user_session_key(p_pass VARCHAR) RETURN NUMBER;

  PROCEDURE init_primary_key(p_token1_1    VARCHAR2,
                             p_token1_2    VARCHAR2,
                             p_token2_1    VARCHAR2,
                             p_token2_2    VARCHAR2,
                             p_update      VARCHAR2 DEFAULT 'N',
                             p_err_code    OUT NUMBER,
                             p_err_message OUT VARCHAR2);

  FUNCTION is_primary_hash_key_exist RETURN NUMBER;
  FUNCTION is_upk_exist RETURN NUMBER;

  PROCEDURE change_key(p_old_key     VARCHAR2,
                       p_new_key1_1  VARCHAR2,
                       p_new_key1_2  VARCHAR2,
                       p_new_key2_1  VARCHAR2,
                       p_new_key2_2  VARCHAR2,
                       p_err_code    OUT NUMBER,
                       p_err_message OUT VARCHAR2);

  PROCEDURE upload_primary_key(p_token1      VARCHAR2,
                               p_token2      VARCHAR2,
                               p_err_code    OUT NUMBER,
                               p_err_message OUT VARCHAR2);

  PROCEDURE change_user_pass(p_old_pass    VARCHAR2,
                             p_new_pass1   VARCHAR2,
                             p_new_pass2   VARCHAR2,
                             p_err_code    OUT NUMBER,
                             p_err_message OUT VARCHAR2);

  FUNCTION get_user_login_count(p_user_id NUMBER) RETURN NUMBER;
  
  --------------------------------------------------------------------
  --  name:               disable_session_open
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0 
  --  creation date:      20/09/2011
  --  Purpose :           This function will call from MSS.
  --                      each time MSS will open customer will nead to 
  --                      enter security password.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   20/09/2011    Dalit A. Raviv  initial build
  ----------------------------------------------------------------------- 
  function disable_session_open return number;
  
  --FUNCTION repeat_string(str       IN VARCHAR2,
--        times     IN NUMBER DEFAULT 1,
--     delimiter IN CHAR DEFAULT '') RETURN VARCHAR2;

END;
/
