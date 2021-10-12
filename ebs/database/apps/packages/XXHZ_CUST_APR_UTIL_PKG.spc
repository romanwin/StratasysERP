CREATE OR REPLACE PACKAGE xxhz_cust_apr_util_pkg IS
  --------------------------------------------------------------------
  --  name:            XXHZ_CUST_APR_UTIL_PKG
  --  create by:       Michal Tzvik
  --  Revision:        1.1
  --  creation date:   07.2014
  --------------------------------------------------------------------
  --  purpose :        CHG0031856- SOD-Customer Update Workflow
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  07.2014     Michal Tzvik      initial build
  --------------------------------------------------------------------

  FUNCTION get_dsp_value(p_entity_code VARCHAR2,
                         p_value       VARCHAR2) RETURN VARCHAR2;

  PROCEDURE generate_need_approval_msg_wf(document_id   IN VARCHAR2,
                                          display_type  IN VARCHAR2,
                                          document      IN OUT NOCOPY CLOB,
                                          document_type IN OUT NOCOPY VARCHAR2);

  FUNCTION get_period_length(p_term_id NUMBER) RETURN NUMBER;

  PROCEDURE is_approval_required(p_entity_code          IN VARCHAR2,
                                 p_old_value            IN VARCHAR2,
                                 p_new_value            IN VARCHAR2,
                                 p_cust_acct_id         IN NUMBER,
                                 p_site_id              IN NUMBER,
                                 p_site_use_id          IN NUMBER,
                                 p_attribute1           IN VARCHAR2 DEFAULT NULL, -- Used for currency code in case of credit limit update
                                 p_attribute2           IN VARCHAR2 DEFAULT NULL,
                                 p_attribute3           IN VARCHAR2 DEFAULT NULL,
                                 x_is_approval_required OUT VARCHAR2, -- Y / N
                                 x_err_code             OUT NUMBER,
                                 x_err_msg              OUT VARCHAR2);

  PROCEDURE submit_wf(p_entity_code              IN VARCHAR2,
                      p_old_value                IN VARCHAR2,
                      p_new_value                IN VARCHAR2,
                      p_cust_acct_id             IN NUMBER,
                      p_site_id                  IN NUMBER,
                      p_site_use_id              IN NUMBER,
                      p_cust_account_profile_id  IN NUMBER,
                      p_cust_acct_profile_amt_id IN NUMBER,
                      p_attribute1               IN VARCHAR2 DEFAULT NULL,
                      p_attribute2               IN VARCHAR2 DEFAULT NULL,
                      p_attribute3               IN VARCHAR2 DEFAULT NULL,
                      x_err_code                 OUT NUMBER,
                      x_err_msg                  OUT VARCHAR2,
                      x_itemkey                  OUT VARCHAR2,
                      x_appr_needed              OUT VARCHAR2);

  PROCEDURE get_wf_info(p_cust_acct_id      IN NUMBER,
                        p_site_id           IN NUMBER,
                        p_site_use_id       IN NUMBER,
                        p_entity_code       IN VARCHAR2,
                        x_err_code          OUT NUMBER,
                        x_err_msg           OUT VARCHAR2,
                        x_exists_pending_wf OUT VARCHAR2,
                        x_info              OUT VARCHAR2);

  PROCEDURE update_cust_profile_amt(p_doc_instance_id IN NUMBER,
                                    
                                    x_err_code OUT NUMBER,
                                    x_err_msg  OUT VARCHAR2);

  PROCEDURE update_credit_checking(p_doc_instance_id         IN NUMBER,
                                   p_cust_account_profile_id IN NUMBER,
                                   p_credit_checking         IN VARCHAR2,
                                   x_err_code                OUT NUMBER,
                                   x_err_msg                 OUT VARCHAR2);

  PROCEDURE update_credit_hold(p_doc_instance_id         IN NUMBER,
                               p_cust_account_profile_id IN NUMBER,
                               p_credit_hold             IN VARCHAR2,
                               x_err_code                OUT NUMBER,
                               x_err_msg                 OUT VARCHAR2);

  PROCEDURE update_payment_terms(p_doc_instance_id         IN NUMBER,
                                 p_cust_account_profile_id IN NUMBER,
                                 p_payment_terms_id        IN NUMBER,
                                 x_err_code                OUT NUMBER,
                                 x_err_msg                 OUT VARCHAR2);

  PROCEDURE get_credit_limit_fyi(p_doc_instance_id IN NUMBER,
                                 -- x_fyi             OUT VARCHAR2,
                                 x_err_code OUT NUMBER,
                                 x_err_msg  OUT VARCHAR2);

  PROCEDURE get_credit_limit_approver(p_doc_instance_id IN NUMBER,
                                      x_approver        OUT VARCHAR2,
                                      x_err_code        OUT NUMBER,
                                      x_err_msg         OUT VARCHAR2);

  PROCEDURE get_payment_term_approver(p_doc_instance_id IN NUMBER,
                                      x_approver        OUT VARCHAR2,
                                      x_err_code        OUT NUMBER,
                                      x_err_msg         OUT VARCHAR2);

  PROCEDURE get_credit_ch_hold_approver(p_doc_instance_id IN NUMBER,
                                        x_approver        OUT VARCHAR2,
                                        x_err_code        OUT NUMBER,
                                        x_err_msg         OUT VARCHAR2);
  /*
    PROCEDURE update_customer_profile(p_doc_instance_id           IN NUMBER,
                                      p_customer_profile_rec_type hz_customer_profile_v2pub.customer_profile_rec_type,
                                      x_cust_account_profile_id   OUT NUMBER,
                                      x_err_code                  OUT NUMBER,
                                      x_err_msg                   OUT VARCHAR2);
  */
  PROCEDURE get_credit_limit_usd(p_new_credit_limit  IN VARCHAR2,
                                 p_new_currency_code IN VARCHAR2,
                                 --p_cust_acct_profile_amt_id IN NUMBER,
                                 x_usd_credit_limit OUT VARCHAR2,
                                 x_err_code         OUT NUMBER,
                                 x_err_msg          OUT VARCHAR2);

  FUNCTION get_party_name(p_doc_instance_id NUMBER) RETURN VARCHAR2;
END xxhz_cust_apr_util_pkg;
/
