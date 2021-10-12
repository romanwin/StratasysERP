create or replace package xxcs_wf_send_mail_pkg is

--------------------------------------------------------------------
--  name:            XXCS_WF_SEND_MAIL_PKG
--  create by:       Dalit A. Raviv
--  Revision:        1.0
--  creation date:   12/06/2012 15:45:51
--------------------------------------------------------------------
--  purpose :        CRM - Handle all WF send mail, HTML body
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  12/06/2012  Dalit A. Raviv    initial build
--------------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:            prepare_coupon_body
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   12/06/2012
  --------------------------------------------------------------------
  --  purpose:         procedure that prepare the CLOB string to attach to
  --                   the mail body that send
  --  In  Params:      p_document_id   - 
  --                   p_display_type  - HTML
  --  Out Params:      p_document      - clob of all data to show
  --                   p_document_type - TEXT/HTML - LOG.HTML
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  12/06/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE prepare_coupon_body (p_document_id   in varchar2,
                                 p_display_type  in varchar2,
                                 p_document      in out clob,
                                 p_document_type in out varchar2);

  --------------------------------------------------------------------
  --  name:            prepare_coupon_attachment
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   12/06/2012
  --------------------------------------------------------------------
  --  purpose:         procedure that prepare the BLOB to attach to
  --                   the mail as attachment 
  --  In  Params:      p_document_id   - 
  --                   p_display_type  - HTML
  --  Out Params:      p_document      - clob of all data to show
  --                   p_document_type - TEXT/HTML - LOG.HTML / application/pdf
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  12/06/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure prepare_coupon_attachment(document_id   IN VARCHAR2,
                                      display_type  IN VARCHAR2,
                                      document      IN OUT BLOB,
                                      document_type IN OUT VARCHAR2);
    

end xxcs_wf_send_mail_pkg;
/
