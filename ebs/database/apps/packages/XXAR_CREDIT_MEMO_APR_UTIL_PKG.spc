create or replace package XXAR_CREDIT_MEMO_APR_UTIL_PKG is
  --------------------------------------------------------------------
  --  name:            XXAR_CREDIT_MEMO_APR_UTIL_PKG
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   08.2014
  --------------------------------------------------------------------
  --  purpose :        CHG0032802 - SOD-Credit Memo Approval Workflow
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  08.2014     Michal Tzvik      initial build
  --------------------------------------------------------------------



  --------------------------------------------------------------------
  --  customization code: CHG0032802 - SOD-Credit Memo Approval Workflow
  --  name:               get_approval_wf_itemkey
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      16/09/2014
  --  Purpose :           Get item key of XXWFDOC for given cistomer_trx_id
  --                      and doc_status.
  --                     It is been called by XXARCUSTOM.pll
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   16/09/2014    Michal Tzvik    initial build
  -----------------------------------------------------------------------
  FUNCTION  get_approval_wf_itemkey(p_customer_trx_id number,
                                    p_doc_status     varchar2) return varchar2;

  --------------------------------------------------------------------
  --  customization code: CHG0032802 - SOD-Credit Memo Approval Workflow
  --  name:               is_approval_required
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      26/08/2014
  --  Purpose :          Check if approval is needed for current cm
  --                     It is been called by XXARCUSTOM.pll
  --                     Use for hide Complete button, and in order to avoid
  --                     Submit WF if no approval is required.
  --                     Parameters:
  --                     p_customer_trx_id
  --                     p_previous_customer_trx_id - Default value is null.
  --                                          In case of Trancsaction -> Credit,
  --                                          customer_trx_id  of the credit memo
  --                                          still not exist in DB, so function will use
  --                                          p_previous_customer_trx_id instead
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   26/08/2014    Michal Tzvik    initial build
  -----------------------------------------------------------------------
  FUNCTION is_approval_required(p_customer_trx_id          NUMBER,
                                p_previous_customer_trx_id NUMBER DEFAULT NULL) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  customization code: CHG0032802 - SOD-Credit Memo Approval Workflow
  --  name:               call_apps_initialize
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      26/08/2014
  --  Purpose :           Update DFF CM Approval Status in transaction header
  --
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   26/08/2014    Michal Tzvik    initial build
  -----------------------------------------------------------------------
  PROCEDURE set_cm_approval_status(p_customer_trx_id  number,
                                   p_status           varchar2) ;

  --------------------------------------------------------------------
  --  customization code: CHG0032802 - SOD-Credit Memo Approval Workflow
  --  name:               get_customer_trx_id
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      26/08/2014
  --  Purpose :           get customer_trx_id of specific doc_instance_id
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   26/08/2014    Michal Tzvik    initial build
  -----------------------------------------------------------------------
  FUNCTION get_customer_trx_id(p_doc_instance_id number) return number;

  --------------------------------------------------------------------
  --  customization code: CHG0032802 - SOD-Credit Memo Approval Workflow
  --  name:               is_completion_enabled
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      18/08/2014
  --  Purpose :           Run validations on transaction, and check if
  --                      completion can be done

  --                      Called by personalization on Transaction form (AR)
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   18/08/2014    Michal Tzvik    initial build
  -----------------------------------------------------------------------
  FUNCTION is_completion_enabled(p_customer_trx_id        IN  NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  customization code: CHG0032802 - SOD-Credit Memo Approval Workflow
  --  name:               do_completion
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      26/08/2014
  --  Purpose :           Complete the transaction

  --                      Called by post approval script
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   26/08/2014    Michal Tzvik    initial build
  -----------------------------------------------------------------------
  PROCEDURE do_completion(p_doc_instance_id   IN  NUMBER,
                          x_err_code          OUT NUMBER,
                          x_err_msg           OUT VARCHAR2);

  --------------------------------------------------------------------
  --  customization code: CHG0032802 - SOD-Credit Memo Approval Workflow
  --  name:               generate_need_approval_msg_wf
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      26/08/2014
  --  Purpose :           Build message body for "Need Aproval" notification
  --
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   26/08/2014    Michal Tzvik    initial build
  -----------------------------------------------------------------------
  PROCEDURE generate_need_approval_msg_wf(document_id   IN VARCHAR2,
                                          display_type  IN VARCHAR2,
                                          document      IN OUT NOCOPY CLOB,
                                          document_type IN OUT NOCOPY VARCHAR2);

  --------------------------------------------------------------------
  --  customization code: CHG0032802 - SOD-Credit Memo Approval Workflow
  --  name:               submit_wf
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      26/08/2014
  --  Purpose :           Submit WF XXWFDOC for credit memo approval
  --
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   26/08/2014    Michal Tzvik    initial build
  -----------------------------------------------------------------------
  PROCEDURE submit_wf(p_customer_trx_id  IN  NUMBER,
                      p_attribute1       IN VARCHAR2 DEFAULT NULL,
                      p_attribute2       IN VARCHAR2 DEFAULT NULL,
                      p_attribute3       IN VARCHAR2 DEFAULT NULL,
                      x_err_code         OUT NUMBER,
                      x_err_msg          OUT VARCHAR2,
                      x_itemkey          OUT VARCHAR2);

  --------------------------------------------------------------------
  --  customization code: CHG0032802 - SOD-Credit Memo Approval Workflow
  --  name:               get_message
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      26/08/2014
  --  Purpose :           Get value of G_MESSAGE. Called by Form personalization.
  --
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   26/08/2014    Michal Tzvik    initial build
  -----------------------------------------------------------------------
  FUNCTION get_message RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  customization code: CHG0032802 - SOD-Credit Memo Approval Workflow
  --  name:               get_approver
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      27/08/2014
  --  Purpose :           get approver name

  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   27/08/2014    Michal Tzvik    initial build
  -----------------------------------------------------------------------
  PROCEDURE get_approver(p_doc_instance_id IN  NUMBER,
                         x_approver        OUT VARCHAR2,
                         x_err_code        OUT NUMBER,
                         x_err_msg         OUT VARCHAR2);

  --------------------------------------------------------------------
  --  customization code: CHG0032802 - SOD-Credit Memo Approval Workflow
  --  name:               get_trx_form_link
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      27/08/2014
  --  Purpose :           get link to Transaction form, to be used in notification body

  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   14/09/2014    Michal Tzvik    initial build
  -----------------------------------------------------------------------
  PROCEDURE get_trx_form_link( document_id   IN VARCHAR2
                              ,display_type  IN VARCHAR2
                              ,document      IN OUT VARCHAR2
                              ,document_type IN OUT VARCHAR2);
end XXAR_CREDIT_MEMO_APR_UTIL_PKG;
/
