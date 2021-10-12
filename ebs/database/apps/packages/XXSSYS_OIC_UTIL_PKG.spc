CREATE OR REPLACE PACKAGE xxssys_oic_util_pkg IS
  ----------------------------------------------------------------------------------------
  -- Ver   When        Who           Descr
  -- ----  ----------  ------------  -----------------------------------------------------
  -- 1.0   07/12/2020  Roman W.      CHG0048579 - OIC new integration tool implementation
  ----------------------------------------------------------------------------------------

  ----------------------------------------------------------------------------------------
  -- Ver   When        Who           Descr
  -- ----  ----------  ------------  -----------------------------------------------------
  -- 1.0   07/12/2020  Roman W.      CHG0048579 - OIC new integration tool implementation
  ----------------------------------------------------------------------------------------
  PROCEDURE message(p_msg IN VARCHAR2);

  ----------------------------------------------------------------------------------------
  -- Ver   When        Who           Descr
  -- ----  ----------  ------------  -----------------------------------------------------
  -- 1.0   07/12/2020  Roman W.      CHG0048579 - OIC new integration tool implementation
  ----------------------------------------------------------------------------------------
  FUNCTION get_instance RETURN VARCHAR2;

  -------------------------------------------------------------------------------------------
  -- Ver    When         Who           Descr
  -- ----   -----------  ------------  ------------------------------------------------------
  -- 1.0    21/12/2020   Roman W.       CHG0048579 - OIC new integration tool implementation
  -------------------------------------------------------------------------------------------
  FUNCTION xml_replace_special_chr(p_str VARCHAR2) RETURN VARCHAR2;

  ----------------------------------------------------------------------------------------
  -- Ver   When        Who           Descr
  -- ----  ----------  ------------  -----------------------------------------------------
  -- 1.0   07/12/2020  Roman W.      CHG0048579 - OIC new integration tool implementation
  ----------------------------------------------------------------------------------------
  FUNCTION encrypt(p_str VARCHAR2) RETURN VARCHAR2;

  ----------------------------------------------------------------------------------------
  -- Ver   When        Who           Descr
  -- ----  ----------  ------------  -----------------------------------------------------
  -- 1.0   07/12/2020  Roman W.      CHG0048579 - OIC new integration tool implementation
  ----------------------------------------------------------------------------------------
  FUNCTION decrypt(p_str RAW) RETURN VARCHAR2;

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
                                 p_attr_value        IN VARCHAR2);
  ---------------------------------------------------------------------------
  -- Ver   When        Who        Descr
  -- ----  ----------  ---------  -------------------------------------------
  -- 1.0   08/12/2020  Roman W.   CHG0048579 - OIC
  ---------------------------------------------------------------------------
  PROCEDURE update_pwd_attr(p_flex_value_set_id IN NUMBER,
                            p_flex_value_id     IN NUMBER,
                            p_attr_name         IN VARCHAR2,
                            p_attr_value        IN VARCHAR2,
                            p_request_id        OUT NUMBER);

  ---------------------------------------------------------------------------
  -- Ver    When         Who           Descr
  -- -----  -----------  ------------  --------------------------------------
  -- 1.0    16/12/2020   Roman W.      CHG0048579 - OIC
  ---------------------------------------------------------------------------
  FUNCTION get_service_oic_enable_flag(p_service IN VARCHAR2) RETURN VARCHAR2;

  -------------------------------------------------------------------------------------
  -- Ver   When        Who        Descr
  -- ----  ----------  ---------  -----------------------------------------------------
  -- 1.0   10/12/2020  Roman W.   CHG0048579 - OIC new integration tool implementation
  --                                  DFF : Flexfield Segment Values (Application Object Library) / XXSSYS_OIC_SERVICE
  -------------------------------------------------------------------------------------
  PROCEDURE get_service_details(p_service     IN VARCHAR2,
                                p_enable_flag OUT VARCHAR2,
                                p_url         OUT VARCHAR2,
                                p_wallet_loc  OUT VARCHAR2,
                                p_wallet_pwd  OUT VARCHAR2,
                                p_auth_user   OUT VARCHAR2,
                                p_auth_pwd    OUT VARCHAR2,
                                p_error_code  OUT VARCHAR2,
                                p_error_desc  OUT VARCHAR2);

  -------------------------------------------------------------------------------------
  -- Ver   When        Who        Descr
  -- ----  ----------  ---------  -----------------------------------------------------
  -- 1.0   10/12/2020  Roman W.   CHG0048579 - OIC new integration tool implementation
  --                                  DFF : Flexfield Segment Values (Application Object Library) / XXSSYS_OIC_SERVICE
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
                                 p_error_desc  OUT VARCHAR2);

  -------------------------------------------------------------------------------------
  -- Ver   When        Who        Descr
  -- ----  ----------  ---------  -----------------------------------------------------
  -- 1.0   10/12/2020  Roman W.   CHG0048579 - OIC new integration tool implementation
  --                                  DFF : Flexfield Segment Values (Application Object Library) / XXSSYS_OIC_SERVICE
  -------------------------------------------------------------------------------------
  PROCEDURE get_end_point_details(p_host       OUT VARCHAR2,
                                  p_wallet_loc OUT VARCHAR2,
                                  p_wallet_pwd OUT VARCHAR2,
                                  p_auth_user  OUT VARCHAR2,
                                  p_auth_pwd   OUT VARCHAR2,
                                  p_error_code OUT VARCHAR2,
                                  p_error_desc OUT VARCHAR2);

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
                                   p_error_desc OUT VARCHAR2);

  ------------------------------------------------------------------------------
  -- Ver   When         Who        Descr
  -- ----  -----------  ---------  ---------------------------------------------
  -- 1.0   14/12/2020   Roman W.   CHG0048579 - OIC
  ------------------------------------------------------------------------------
  PROCEDURE html_parser(p_in_text    IN VARCHAR2,
                        p_out_text   OUT VARCHAR2,
                        p_error_code OUT VARCHAR2,
                        p_error_desc OUT VARCHAR2);

  ------------------------------------------------------------------------------
  -- Ver   When         Who        Descr
  -- ----  -----------  ---------  ---------------------------------------------
  -- 1.0   14/12/2020   yuval tal   CHG0048579 - OIC
  ------------------------------------------------------------------------------
  PROCEDURE wait(p_sec NUMBER);

END xxssys_oic_util_pkg;
/
