CREATE OR REPLACE PACKAGE xxobjt_table_loader_util_pkg IS
  ---------------------------------------------------------------------------
  -- $Header: xxobjt_table_loader_util_pkg   $
  ---------------------------------------------------------------------------
  -- Package: xxobjt_table_loader_util_pkg
  -- Created:
  -- Author:
  --------------------------------------------------------------------------
  -- Purpose: Populate Conversions Table from Excel 
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  11.6.13     Vitaly       initial build
  ------------------------------------------------------------------

  PROCEDURE load_file(errbuf                 OUT VARCHAR2,
                      retcode                OUT VARCHAR2,
                      p_table_name           IN VARCHAR2,
                      p_template_name        IN VARCHAR2,
                      p_file_name            IN VARCHAR2,
                      p_directory            IN VARCHAR2,
                      p_expected_num_of_rows IN NUMBER);

  PROCEDURE load_bad_file_to_clob(p_file_name      IN VARCHAR2,
                                  p_directory      IN VARCHAR2,
                                  p_clob           OUT CLOB,
                                  p_exists         OUT VARCHAR2,
                                  p_rejected_count OUT NUMBER);

  FUNCTION submit_request_build_template(p_table_name    IN VARCHAR2,
                                         p_template_name IN VARCHAR2)
    RETURN NUMBER;

END xxobjt_table_loader_util_pkg;
/
