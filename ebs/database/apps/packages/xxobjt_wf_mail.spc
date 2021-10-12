CREATE OR REPLACE PACKAGE xxobjt_wf_mail AS
  ---------------------------------------------------------------------------
  -- $Header: xxobjt_wf_mail   $
  ---------------------------------------------------------------------------
  -- Package: xxobjt_wf_mail
  -- Created: 
  -- Author  : 
  --------------------------------------------------------------------------
  -- Perpose: WF  Send mail
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  10.01.11   yuval tal            Initial Build

  ---------------------------------------------------------------------------

  /*PROCEDURE send_mail(p_to_role     VARCHAR2,
  p_subject     VARCHAR2,
  p_body_text   VARCHAR2 DEFAULT NULL,
  p_body_html   VARCHAR2 DEFAULT NULL,
  p_body_proc   VARCHAR2 DEFAULT NULL,
  p_att1_proc   VARCHAR2 DEFAULT NULL,
  p_att2_proc   VARCHAR2 DEFAULT NULL,
  p_att3_proc   VARCHAR2 DEFAULT NULL,
  p_err_code    OUT NUMBER,
  p_err_message OUT VARCHAR2);*/

  PROCEDURE send_mail_html(p_to_role     VARCHAR2,
                           p_cc_mail     VARCHAR2 DEFAULT NULL,
                           p_bcc_mail    VARCHAR2 DEFAULT NULL,
                           p_subject     VARCHAR2,
                           p_body_html   VARCHAR2 DEFAULT NULL,
                           p_att1_proc   VARCHAR2 DEFAULT NULL,
                           p_att2_proc   VARCHAR2 DEFAULT NULL,
                           p_att3_proc   VARCHAR2 DEFAULT NULL,
                           p_err_code    OUT NUMBER,
                           p_err_message OUT VARCHAR2);

  PROCEDURE send_mail_text(p_to_role     VARCHAR2,
                           p_cc_mail     VARCHAR2 DEFAULT NULL,
                           p_bcc_mail    VARCHAR2 DEFAULT NULL,
                           p_subject     VARCHAR2,
                           p_body_text   VARCHAR2 DEFAULT NULL,
                           p_att1_proc   VARCHAR2 DEFAULT NULL,
                           p_att2_proc   VARCHAR2 DEFAULT NULL,
                           p_att3_proc   VARCHAR2 DEFAULT NULL,
                           p_err_code    OUT NUMBER,
                           p_err_message OUT VARCHAR2);

  PROCEDURE send_mail_body_proc(p_to_role     VARCHAR2,
                                p_cc_mail     VARCHAR2 DEFAULT NULL,
                                p_bcc_mail    VARCHAR2 DEFAULT NULL,
                                p_subject     VARCHAR2,
                                p_body_proc   VARCHAR2 DEFAULT NULL,
                                p_att1_proc   VARCHAR2 DEFAULT NULL,
                                p_att2_proc   VARCHAR2 DEFAULT NULL,
                                p_att3_proc   VARCHAR2 DEFAULT NULL,
                                p_err_code    OUT NUMBER,
                                p_err_message OUT VARCHAR2);
  FUNCTION get_header_html RETURN VARCHAR2;
  FUNCTION get_footer_html RETURN VARCHAR2;

END;
/

