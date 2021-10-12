CREATE OR REPLACE PACKAGE xxgl_journal_wf_pkg AUTHID CURRENT_USER IS

  --------------------------------------------------------------------
  --  name:            XXOBJT_WF_DOC_RG
  --  create by:       Yuval tal
  --  Revision:        1.0 
  --  creation date:   6.12.12
  --------------------------------------------------------------------
  --  purpose :        CUST611 : document approval engine 
  --                   support workflow XXWFDOC
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  6.12.12     Yuval tal         initial build
  --------------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:            approval_message_body
  --  create by:       Yuval tal
  --  Revision:        1.0 
  --  creation date:   22.8.13
  --------------------------------------------------------------------
  --  purpose :          draw journal approval body notification 
  --                     CUST420 : CR 985 - support changes in Journal wf approval
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  22.8.13     Yuval tal         initial build

  --------------------------------------------------------------------
  PROCEDURE approval_message_body(document_id   IN VARCHAR2,
                                  display_type  IN VARCHAR2,
                                  document      IN OUT NOCOPY CLOB,
                                  document_type IN OUT NOCOPY VARCHAR2);

  PROCEDURE approval_message_cc_mgr_body(document_id   IN VARCHAR2,
                                         display_type  IN VARCHAR2,
                                         document      IN OUT NOCOPY CLOB,
                                         document_type IN OUT NOCOPY VARCHAR2);

---
END xxgl_journal_wf_pkg;
/
