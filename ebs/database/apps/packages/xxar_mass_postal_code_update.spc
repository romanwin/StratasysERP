CREATE OR REPLACE PACKAGE xxar_mass_postal_code_update IS
  --------------------------------------------------------------------
  --  customization code: CHG0033182 – Mass Upload Customer Postal codes
  --  name:               XXAR_MASS_POSTAL_CODE_UPDATE
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  creation date:      18/01/2015
  --  Description:        Mass upload of postal_code to hz_locations
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   18/01/2015    Michal Tzvik    initial build
  --------------------------------------------------------------------

  PROCEDURE main(errbuf          OUT VARCHAR2,
                 retcode         OUT VARCHAR2,
                 p_table_name    IN VARCHAR2, -- hidden parameter. default value ='XXQP_PRICE_LIST_LINES_INT' independent value set XXOBJT_LOADER_TABLES
                 p_template_name IN VARCHAR2, -- hidden parameter. default value ='XXQP_ASCII_UPLOAD'
                 p_file_name     IN VARCHAR2,
                 p_directory     IN VARCHAR2);

END xxar_mass_postal_code_update;
/
