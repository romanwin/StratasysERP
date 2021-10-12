CREATE OR REPLACE PACKAGE APPS.xxpo_documents_action_pkg AUTHID CURRENT_USER IS

  ---------------------------------------------------------------------------
  -- $Header: xxpo_wf_notification_pkg 120.0 2009/08/31  $
  ---------------------------------------------------------------------------
  -- Package: xxpo_documents_action_pkg
  -- Created:
  -- Author  :
  --------------------------------------------------------------------------
  -- Perpose: Purchasing approval WF modifications
  --------------------------------------------------------------------------
  --  Ver     Date       Performer        Comments
  --------    --------   --------------   -------------------------------------
  --  1.0     ????                        Initial Build
  --  1.1     30.11.10   yuval tal        update_po_to_incomplete and update_req_status
  --                                      ignore reservation check
  --  1.2     30.11.10   yuval tal        change resend_notification procedure
  --  1.3     8.12.10    yuval tal        add close_po
  --  1.4     20.5.12    yuval tal        add abort_po_rel2incomplete
  --  1.2     04.12.14   mmazanet         Added the following procedures for
  --                                      CHG0032431... auto_close_po
  --  1.3     26/01/2015 Dalit A. Raviv   CHG0034145 - change close PO to Cancel,
  --                                      close PO do not release the encumbrance, cancel do.
  --                                      change cursor population to only expense lines
  --                                      Add 3 fields to log mail.
  --  1.4     25/02/2015 Dalit A. Raviv   CHG0034191 - add procedure approve_po_for_kanban
  --                                      Automatically PO approval process approve_po_for_kanban
  --  1.5     08-Aug-2018 Hubert, Eric    CHG0043721 - Added procedure, auto_finally_close_po, to Finally Close POs.
  ---------------------------------------------------------------------------

  PROCEDURE auto_close_po(
    errbuff             OUT VARCHAR2,
    retcode             OUT VARCHAR2,
    p_po_source         IN VARCHAR2,
    p_org_id            IN NUMBER,
    p_po_type           IN VARCHAR2   DEFAULT NULL,
    p_days_tolerance    IN VARCHAR2   DEFAULT 0,
    p_burst_flag        IN VARCHAR2,
    p_default_email     IN VARCHAR2,
    p_key_col           IN VARCHAR2,
    p_report_title      IN VARCHAR2,
    p_report_pre_text1  IN VARCHAR2,
    p_report_pre_text2  IN VARCHAR2,
    p_email_subject     IN VARCHAR2,
    p_email_body        IN VARCHAR2,
    p_file_name         IN VARCHAR2,
    p_purge_table       IN VARCHAR2,
    p_load_file_name    IN VARCHAR2   DEFAULT NULL,
    p_load_file_dir     IN VARCHAR2   DEFAULT NULL,
    p_test_report       IN VARCHAR2,
    p_use_default_email IN VARCHAR2
  );

  --------------------------------------------------------------------
  --  name:              auto_finally_close_po
  --  created by:        Hubert, Eric
  --  Revision:          1.0
  --  creation date:     09-Aug-2018
  --------------------------------------------------------------------
  --  purpose : Change status of PO lines to Finally Closed en masse
  --------------------------------------------------------------------
  --  ver  date          name            desc
  --  1.1  09-Aug-2018   Hubert, Eric    Initial CHG0043721
  --------------------------------------------------------------------
  PROCEDURE auto_finally_close_po(
    errbuff             OUT VARCHAR2,
    retcode             OUT VARCHAR2,
    p_po_source         IN VARCHAR2,
    p_org_id            IN NUMBER,
    p_po_type           IN VARCHAR2   DEFAULT NULL,
    --p_days_tolerance    IN VARCHAR2   DEFAULT 0,
    p_burst_flag        IN VARCHAR2,
    p_default_email     IN VARCHAR2,
    p_key_col           IN VARCHAR2,
    p_report_title      IN VARCHAR2,
    p_report_pre_text1  IN VARCHAR2,
    p_report_pre_text2  IN VARCHAR2,
    p_email_subject     IN VARCHAR2,
    p_email_body        IN VARCHAR2,
    p_file_name         IN VARCHAR2,
    p_purge_table       IN VARCHAR2,
    p_load_file_name    IN VARCHAR2   DEFAULT NULL,
    p_load_file_dir     IN VARCHAR2   DEFAULT NULL,
    p_test_report       IN VARCHAR2,
    p_use_default_email IN VARCHAR2
  );


  --------------------------------------------------------------------
  --  name:              auto_cancel_po
  --  create by:         Dalit A. Raviv
  --  Revision:          1.0
  --  creation date:     02/02/2015
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.1  02/02/2015    Dalit A. Raviv    Initial CHG0034145
  --------------------------------------------------------------------
  PROCEDURE auto_cancel_po (errbuff             OUT VARCHAR2,
                            retcode             OUT VARCHAR2,
                            p_po_source         IN VARCHAR2,
                            p_org_id            IN NUMBER,
                            p_po_type           IN VARCHAR2   DEFAULT NULL,
                            p_days_tolerance    IN VARCHAR2   DEFAULT 0,
                            p_burst_flag        IN VARCHAR2,
                            p_default_email     IN VARCHAR2,
                            p_key_col           IN VARCHAR2,
                            p_report_title      IN VARCHAR2,
                            p_report_pre_text1  IN VARCHAR2,
                            p_report_pre_text2  IN VARCHAR2,
                            p_email_subject     IN VARCHAR2,
                            p_email_body        IN VARCHAR2,
                            p_file_name         IN VARCHAR2,
                            p_purge_table       IN VARCHAR2,
                            p_load_file_name    IN VARCHAR2   DEFAULT NULL,
                            p_load_file_dir     IN VARCHAR2   DEFAULT NULL,
                            p_test_report       IN VARCHAR2,
                            p_use_default_email IN VARCHAR2,
                            p_send_sum_report   in varchar2);

  PROCEDURE cancel_requisition(p_req_header_id NUMBER,
                               p_req_sub_type  VARCHAR2 DEFAULT 'PURCHASE',
                               p_reject_reason VARCHAR2,
                               x_return_status OUT VARCHAR2,
                               x_err_msg       OUT VARCHAR2);

  PROCEDURE update_req_status(errbuf       OUT VARCHAR2,
                              errcode      OUT VARCHAR2,
                              v_req_number IN VARCHAR2,
                              v_org_id     IN NUMBER);

  PROCEDURE update_po_to_incomplete(errbuf            OUT VARCHAR2,
                                    retcode           OUT VARCHAR2,
                                    p_po_number       VARCHAR2,
                                    p_organization_id NUMBER,
                                    p_del_action_hist VARCHAR2 DEFAULT 'N');
  PROCEDURE abort_po_rel2incomplete(errbuf            OUT VARCHAR2,
                                    retcode           OUT VARCHAR2,
                                    p_po_release_id   NUMBER,
                                    p_organization_id NUMBER,
                                    p_del_action_hist VARCHAR2 DEFAULT 'N');

  PROCEDURE resend_notification(errbuf                    OUT VARCHAR2,
                                retcode                   OUT VARCHAR2,
                                p_item_type               VARCHAR2,
                                p_messages_name_delimited VARCHAR2,
                                p_notification_id         NUMBER,
                                p_days                    NUMBER);

  PROCEDURE close_po(errbuf      OUT VARCHAR2,
                     retcode     OUT VARCHAR2,
                     p_org_id    NUMBER,
                     p_from_date VARCHAR2,
                     p_to_date   VARCHAR2,
                     p_po_number VARCHAR2);

  --------------------------------------------------------------------
  --  name:              approve_po_for_kanban
  --  create by:         Dalit A. Raviv
  --  Revision:          1.0
  --  creation date:     25/02/2015
  --------------------------------------------------------------------
  --  purpose :          CHG0034191 - Automatically PO approval process
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.1  25/02/2015    Dalit A. Raviv    Initial
  --------------------------------------------------------------------
  procedure approve_po_for_kanban (errbuff out varchar2,
                                   retcode out varchar2);

END xxpo_documents_action_pkg;
/