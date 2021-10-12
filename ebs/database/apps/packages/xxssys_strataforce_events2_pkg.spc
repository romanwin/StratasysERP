CREATE OR REPLACE PACKAGE xxssys_strataforce_events2_pkg IS

  ---------------------------------------------------------------------------------------
  -- Ver  Date        Who         Description
  -- ---  ----------  ----------  -------------------------------------------------------
  -- 1.0  27/03/2020  Roman W.    CHG0047450 - Account, Contact interface - ReDo
  -- 1.1  4.1.2021    yuval tal   CHG0048217 add populate_inactive_site_events
  ---------------------------------------------------------------------------------------

  ---------------------------------------------------------------------------------------
  -- Ver  Date        Who         Description
  -- ---  ----------  ----------  -------------------------------------------------------
  -- 2.8  30/03/2020  Roman W.    CHG0047450 - Account, Contact interface - ReDo
  ---------------------------------------------------------------------------------------
  PROCEDURE message(p_msg IN VARCHAR2);

  ---------------------------------------------------------------------------------------
  -- Ver   When        Who           Descr
  -- ----  ----------  ------------  ----------------------------------------------------
  -- 1.0   30/03/2020  Roman W.      CHG0047450 - Account, Contact interface - ReDo
  ---------------------------------------------------------------------------------------
  PROCEDURE find_alternative_site(p_cust_account_id       IN NUMBER,
                                  p_cust_acct_site_id     IN NUMBER,
                                  p_party_site_id         IN NUMBER,
                                  p_org_id                IN NUMBER,
                                  p_site_country          IN VARCHAR2,
                                  p_out_cust_acct_site_id OUT NUMBER,
                                  p_update_account_addr   OUT VARCHAR2,
                                  p_error_code            OUT VARCHAR2,
                                  p_error_desc            OUT VARCHAR2);

  ---------------------------------------------------------------------------------------
  -- Ver  Date        Who         Description
  -- ---  ----------  ----------  -------------------------------------------------------
  -- 2.8  27/03/2020  Roman W.    CHG0047450 - Account, Contact interface - ReDo
  ---------------------------------------------------------------------------------------
  PROCEDURE sync_account_address(errbuf OUT VARCHAR2, retcode OUT NUMBER);

  ---------------------------------------------------------------------------------------
  -- Ver  Date        Who         Description
  -- ---  ----------  ----------  -------------------------------------------------------
  -- 1.0  17/06/2020  Roman W.    CHG0047450 - Account, Contact interface - ReDo
  ---------------------------------------------------------------------------------------
  PROCEDURE acct_site_delete_trg(p_cust_account_id        IN NUMBER,
                                 p_cust_acct_site_id      IN NUMBER,
                                 p_old_sf_account_address IN VARCHAR2,
                                 p_error_code             OUT VARCHAR2,
                                 p_error_desc             OUT VARCHAR2);

  -----------------------------------------------------------------------------------
  -- Ver   When        Who        Descr
  -- ----  ----------  ---------  ---------------------------------------------------
  -- 1.0   01/09/2020  Roman W.   CHG0047450
  -----------------------------------------------------------------------------------
  PROCEDURE is_acct_ou_valid(p_party_id        IN NUMBER, -- 8649223
                             p_org_id          IN NUMBER,
                             p_validation_flag OUT VARCHAR2,
                             p_error_code      OUT VARCHAR2,
                             p_error_desc      OUT VARCHAR2);

  ---------------------------------------------------------------------------------------
  -- Ver  Date        Who         Description
  -- ---  ----------  ----------  -------------------------------------------------------
  -- 1.0  17/06/2020  Roman W.    CHG0047450 - Account, Contact interface - ReDo
  -- 1.1  25/03/2021  Roman W.                 Added parameter "p_created_by_module"
  ---------------------------------------------------------------------------------------
  PROCEDURE acct_site_insert_trg(p_created_by_module      IN VARCHAR2,
                                 p_cust_account_id        IN NUMBER,
                                 p_cust_acct_site_id      IN NUMBER,
                                 p_status                 IN VARCHAR2,
                                 p_new_sf_account_address IN OUT VARCHAR2,
                                 p_error_code             OUT VARCHAR2,
                                 p_error_desc             OUT VARCHAR2);

  ---------------------------------------------------------------------------------------
  -- Ver  Date        Who         Description
  -- ---  ----------  ----------  -------------------------------------------------------
  -- 1.0  17/06/2020  Roman W.    CHG0047450 - Account, Contact interface - ReDo
  ---------------------------------------------------------------------------------------
  PROCEDURE acct_site_updpdate_trg(p_cust_account_id        IN NUMBER,
                                   p_cust_acct_site_id      IN NUMBER,
                                   p_old_status             IN VARCHAR2,
                                   p_new_status             IN VARCHAR2,
                                   p_old_sf_account_address IN VARCHAR2,
                                   p_new_sf_account_address IN VARCHAR2,
                                   p_error_code             OUT VARCHAR2,
                                   p_error_desc             OUT VARCHAR2);

  ---------------------------------------------------------------------------------------
  -- Ver  Date        Who         Description
  -- ---  ----------  ----------  -------------------------------------------------------
  -- 2.8  27/03/2020  Roman W.    CHG0047450 - Account, Contact interface - ReDo
  ---------------------------------------------------------------------------------------
  PROCEDURE acct_site_upd_attr4_conc(errbuf              OUT VARCHAR2,
                                     retcode             OUT VARCHAR2,
                                     p_cust_account_id   IN NUMBER,
                                     p_cust_acct_site_id IN NUMBER);

  ---------------------------------------------------------------------------------------
  -- Ver  Date        Who         Description
  -- ---  ----------  ----------  -------------------------------------------------------
  -- 1.0   4.1.2021   Yuval Tal   CHG0048217 - push inactive sites which were merged and need to set new account to be able to
  --                                            be fetch by XXHZ_SITE_SOA_V and sync it to sfdc
  ---------------------------------------------------------------------------------------
  PROCEDURE populate_inactive_site_events(errbuf  OUT VARCHAR2,
                                          retcode OUT VARCHAR2);

END xxssys_strataforce_events2_pkg;
/
