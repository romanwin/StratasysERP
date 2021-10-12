CREATE OR REPLACE PACKAGE xxap_shaam_pkg IS

  ---------------------------------------------------------------------------
  -- $Header: xxap_mpa_accounting_pkg 120.0 2009/08/31  $
  ---------------------------------------------------------------------------
  -- Package: xxap_shaam_pkg
  -- Created: yuval tal
  -- 
  --------------------------------------------------------------------------
  -- Perpose: Agile procedures
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  21.3.11                 Initial Build
  ---------------------------------------------------------------------------
  PROCEDURE submit_shaam_interface_program(p_file_name   VARCHAR2,
                                           p_request_id  OUT NUMBER,
                                           p_err_code    OUT NUMBER,
                                           p_err_message OUT VARCHAR2);

  PROCEDURE send_mail(p_err_code NUMBER, p_err_msg VARCHAR2);

  PROCEDURE copy_file(p_bpel_instance NUMBER,
                      p_dir           VARCHAR2,
                      p_file_name     VARCHAR2,
                      p_err_code      OUT NUMBER);

END;
/

