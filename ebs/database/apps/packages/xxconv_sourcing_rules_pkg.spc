CREATE OR REPLACE PACKAGE xxconv_sourcing_rules_pkg AUTHID CURRENT_USER IS
  ---------------------------------------------------------------------------
  -- $Header: xxconv_sourcing_rules_pkg   $
  ---------------------------------------------------------------------------
  -- Package: xxconv_sourcing_rules_pkg
  -- Created:
  -- Author:
  --------------------------------------------------------------------------
  -- Purpose: Create Sourcing Rules for new Organizations 
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  03.7.13     Vitaly       initial build
  ------------------------------------------------------------------
  PROCEDURE upload_sourcing_rules(errbuf          OUT VARCHAR2,
                                  retcode         OUT VARCHAR2,
                                  p_table_name    IN VARCHAR2,
                                  p_template_name IN VARCHAR2,
                                  p_file_name     IN VARCHAR2,
                                  p_directory     IN VARCHAR2);
END xxconv_sourcing_rules_pkg;
/
