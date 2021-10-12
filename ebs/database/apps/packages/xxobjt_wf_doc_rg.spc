CREATE OR REPLACE PACKAGE xxobjt_wf_doc_rg AUTHID CURRENT_USER IS

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

  -- Public variable declarations
  
  --------------------------------------------------------------------
  --  name:            get_history_wf
  --  create by:       Yuval tal
  --  Revision:        1.0 
  --  creation date:   6.12.12
  --------------------------------------------------------------------
  --  purpose :        draw history table in notification
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  6.12.12     Yuval tal         initial build
  --------------------------------------------------------------------
  PROCEDURE get_history_wf(document_id   IN VARCHAR2,
                           display_type  IN VARCHAR2,
                           document      IN OUT NOCOPY CLOB,
                           document_type IN OUT NOCOPY VARCHAR2);
  ---

---
END xxobjt_wf_doc_rg;

 
/
