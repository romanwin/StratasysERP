CREATE OR REPLACE PACKAGE xxap_utils IS
  --------------------------------------------------------------------
  --  name:              XXAP_UTILS
  --  create by:         Ofer Suad
  --  Revision:          1.0
  --  creation date:     13/11/2011
  --------------------------------------------------------------------
  --  purpose :      Utils for Paybles
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  13/11/2011     Ofer Suad               initial build
  --  1.1  24/07/2014  ofer suad         CHG0032811 - add Update_IC_Interafce_GLDate
  --------------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:            wrong_po_encum_reversal_lines
  --  create by:       Ofer Suad
  --  Revision:        1.0
  --  creation date:   13/11/2011  10:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure to send mail in cases of Invoice Gl Date is prior
  --                   to PO Gl Date . In these cases the Encumrance is wrog and
  --                   users will have to Crate Manual Encumbarcne JE in order to
  --                   fix the wrong Encumbarcne.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/11/2011  Ofer Suad         initial build
  --------------------------------------------------------------------
  PROCEDURE wrong_po_encum_reversal_lines(errbuf  OUT NOCOPY VARCHAR2,
                                          retcode OUT NOCOPY NUMBER,
                                          p_date  VARCHAR2);

  --------------------------------------------------------------------
  --  name:            prepare_wrong_po_ecnu_body
  --  create by:       Ofer Suad
  --  Revision:        1.0
  --  creation date:   13/11/2011  10:30:11 PM
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/11/2011  Ofer Suad         initial build
  --------------------------------------------------------------------
  PROCEDURE prepare_wrong_po_ecnu_body(p_document_id   IN VARCHAR2,
                                       p_display_type  IN VARCHAR2,
                                       p_document      IN OUT CLOB,
                                       p_document_type IN OUT VARCHAR2);
  --------------------------------------------------------------------
  --  name:            undo_accounting
  --  create by:       Ofer Suad
  --  Revision:        1.0
  --  creation date:   13/11/2011  10:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        Create Wrper to oracle undo accounting
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/11/2011  Ofer Suad         initial build
  --------------------------------------------------------------------
  PROCEDURE undo_accounting(errbuf         OUT NOCOPY VARCHAR2,
                            retcode        OUT NOCOPY NUMBER,
                            p_source_table VARCHAR2,
                            p_source_id    NUMBER,
                            p_gl_date      VARCHAR2);
  ----------------------------------------------------------------------
  PROCEDURE update_ic_interafce_gldate(errbuf OUT NOCOPY VARCHAR2,

                                       retcode       OUT NOCOPY NUMBER,
                                       p_new_gl_date VARCHAR2);
  -------------------------------------------------------------------------------
  --  name:            get_deferred_flag
  --  create by:       Ofer Suad
  --  Revision:        1.0
  --  creation date:   31/03/2019
  --------------------------------------------------------------------

  --  ver  date        name              desc
  --  1.0  31/03/2019  Ofer Suad         CHG0045333
  --------------------------------------------------------------------
  function get_deferred_flag(p_inv_dist_id number) return varchar;
END xxap_utils;
/
