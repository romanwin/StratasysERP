CREATE OR REPLACE PACKAGE xxoe_so_bucket_discnt_int_pkg IS
  --------------------------------------------------------------------
  --  name:            XXOE_SO_BUCKET_DISCNT_INT_PKG
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   14/12/2014
  --------------------------------------------------------------------
  --  purpose :        CHG0034003-Resin bucket - Apply automatic discount in SO
  --------------------------------------------------------------------
  --  ver    date          name             desc
  --  1.0    14.12.2014    Michal Tzvik     Initial Build
  --------------------------------------------------------------------

  PROCEDURE main(errbuf          OUT VARCHAR2,
                 retcode         OUT VARCHAR2,
                 p_table_name    IN VARCHAR2,
                 p_template_name IN VARCHAR2,
                 p_file_name     IN VARCHAR2,
                 p_directory     IN VARCHAR2);

END xxoe_so_bucket_discnt_int_pkg;
/
