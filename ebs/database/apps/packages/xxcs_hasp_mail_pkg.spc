CREATE OR REPLACE PACKAGE xxcs_hasp_mail_pkg AS
  ---------------------------------------------------------------------------
  -- $Header: xxcs_hasp_mail_pkg   $
  ---------------------------------------------------------------------------
  -- Package: xxcs_hasp_mail_pkg
  -- Created: 
  -- Author  : 
  --------------------------------------------------------------------------
  -- Perpose: support hasp interface process cust419
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  04.06.12   yuval tal            Initial Build

  ---------------------------------------------------------------------------

  PROCEDURE generate_success_alert_msg_wf(document_id   IN VARCHAR2,
                                          display_type  IN VARCHAR2,
                                          document      IN OUT NOCOPY CLOB,
                                          document_type IN OUT NOCOPY VARCHAR2);

  PROCEDURE generate_error_alert_msg_wf(document_id   IN VARCHAR2,
                                        display_type  IN VARCHAR2,
                                        document      IN OUT NOCOPY CLOB,
                                        document_type IN OUT NOCOPY VARCHAR2);
END;
/
