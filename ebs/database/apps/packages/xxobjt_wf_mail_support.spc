CREATE OR REPLACE PACKAGE xxobjt_wf_mail_support AS
  ---------------------------------------------------------------------------
  -- $Header: xxfnd_smtp_utilities 120.0 2009/08/31  $
  ---------------------------------------------------------------------------
  -- Package: xxobjt_wf_mail_support
  -- Created: 
  -- Author  : 
  --------------------------------------------------------------------------
  -- Perpose: WF  Send mail
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  6.1.11    yuval tal         Initial Build
  --     1.1  14.12.11  yuval tal         get_header_html :  support internal logo

  ---------------------------------------------------------------------------

  PROCEDURE get_body_html(document_id   IN VARCHAR2,
                          display_type  IN VARCHAR2,
                          document      IN OUT NOCOPY CLOB,
                          document_type IN OUT NOCOPY VARCHAR2);

  PROCEDURE sample_attchment_proc(document_id   IN VARCHAR2,
                                  display_type  IN VARCHAR2,
                                  document      IN OUT BLOB,
                                  document_type IN OUT VARCHAR2);

  PROCEDURE sample_clob_body(document_id   IN VARCHAR2,
                             display_type  IN VARCHAR2,
                             document      IN OUT CLOB,
                             document_type IN OUT VARCHAR2);

  FUNCTION get_header_html(p_logo_location VARCHAR2 DEFAULT NULL)
    RETURN VARCHAR2;
  FUNCTION get_footer_html RETURN VARCHAR2;
END;
/
