CREATE OR REPLACE PACKAGE xxpo_attch_mf_doc_pkg IS

  --------------------------------------------------------------------
  --  name:             XXPO_ATTCH_MF_DOC_PKG
  --  ver  date        name              desc
  --  1.0  8.5.11  YUVAL TAL    initial build

  --------------------------------------------------------------------
  --  purpose :         CUST315 - PO Attach automatically MFs to RFRs and to the POs
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  8.5.11  YUVAL TAL    initial build
  --  1.1  07.06.12 yuval tal    move mf attach file from header to line level
  --  1.2  15.7.12     YUVAL TAL    ADD check_mf_att_header_exist
  --------------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:            attach_mf_to_po
  --  create by:        YUVAL TAL
  --  Revision:        1.0
  --  creation date:   8.5.11
  --------------------------------------------------------------------
  --  purpose :        for each MF number ;
  --                   1) run XX: Malfunctuion report
  --                   2) attche pdf output to PO
  --  In Param:        p_mf_number - Malfunction number
  --                   p_po_header_id - Unique Po header id to attch the MF to.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  8.5.11      YUVAL TAL    initial build

  --------------------------------------------------------------------
  PROCEDURE attach_mf_to_po_wf(itemtype  IN VARCHAR2,
                               itemkey   IN VARCHAR2,
                               actid     IN NUMBER,
                               funcmode  IN VARCHAR2,
                               resultout OUT NOCOPY VARCHAR2);

  PROCEDURE is_mf_related(itemtype  IN VARCHAR2,
                          itemkey   IN VARCHAR2,
                          actid     IN NUMBER,
                          funcmode  IN VARCHAR2,
                          resultout OUT NOCOPY VARCHAR2);
  FUNCTION check_mf_att_header_exist(p_po_header_id NUMBER,
                                     p_data_type    VARCHAR2,
                                     p_desc         VARCHAR2) RETURN NUMBER;

  FUNCTION check_mf_att_exist(p_po_line_id NUMBER,
                              p_data_type  VARCHAR2,
                              p_desc       VARCHAR2) RETURN NUMBER;
  PROCEDURE attach_mf_to_po(errbuf       OUT VARCHAR2,
                            retcode      OUT NUMBER,
                            p_mf_number  IN VARCHAR2,
                            p_po_line_id IN NUMBER);

  PROCEDURE attach_mf_to_po_main(errbuf         OUT VARCHAR2,
                                 retcode        OUT NUMBER,
                                 p_po_header_id IN NUMBER);

  PROCEDURE attached_short_text(p_entity_name          VARCHAR2,
                                p_pk1                  VARCHAR2,
                                p_document_text        VARCHAR2,
                                p_document_category    NUMBER,
                                p_document_description VARCHAR2);

  PROCEDURE log(p_message VARCHAR2);

END xxpo_attch_mf_doc_pkg;
/
