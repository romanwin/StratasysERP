CREATE OR REPLACE PACKAGE xxcs_attach_doc_pkg IS

  -- Author  : MAOZ.DEKEL
  -- Created : 9/13/2009 5:17:17 PM
  -- Purpose : 

  --------------------------------------------------------------------
  --  name:            XXCS_FSR_INTERFACE_PKG
  --  create by:       Ella malchi
  --  Revision:        1.0 
  --  creation date:   xx/xx/2010 
  --------------------------------------------------------------------
  --  purpose :        process_fsr_request
  --------------------------------------------------------------------
  --  ver  date        name             desc

  -- 1.2  10.01.2011   yuval tal         add file_content_tipe to objet_store_pdf
  -- 1.3 8.5.11       yuval tal           add default param p_oracle_directory ,p_description to load_file_to_db/objet_store_pdf
  --------------------------------------------------------------------

  PROCEDURE objet_store_pdf(p_entity_name       IN VARCHAR2,
                            p_pk1               IN VARCHAR2,
                            p_pk2               IN VARCHAR2,
                            p_pk3               IN VARCHAR2,
                            p_pk4               IN VARCHAR2,
                            p_pk5               IN VARCHAR2,
                            p_conc_req_id       IN NUMBER,
                            p_doc_categ         IN VARCHAR2,
                            p_file_name         IN VARCHAR2,
                            resultout           OUT NOCOPY VARCHAR2,
                            p_file_content_type VARCHAR2 DEFAULT 'application/pdf',
                            p_oracle_directory  VARCHAR2 DEFAULT NULL,
                            p_description       VARCHAR2 DEFAULT NULL);

  PROCEDURE load_file_to_db(p_file_name        VARCHAR2,
                            p_blob             OUT BLOB,
                            p_oracle_directory VARCHAR2 DEFAULT 'XXOBJT_DIR');
  ------------------------------------------------------------
  PROCEDURE relevant_sr_for_attach(errbuf        OUT VARCHAR2,
                                   retcode       OUT NUMBER,
                                   p_incident_id NUMBER DEFAULT NULL);

END xxcs_attach_doc_pkg;
/

