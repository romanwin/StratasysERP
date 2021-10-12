CREATE OR REPLACE PACKAGE xxiby_bank_conv_pkg IS
  --------------------------------------------------------------------
  --  name:            XXIBY_BANK_CONV_PKG
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   03/08/2015
  --------------------------------------------------------------------
  --  purpose :        CHG0035411 – Global Banking Change to JP Morgan Chase Phase III
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  03/08/2015  Michal Tzvik    initial build
  --------------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:              main
  --  create by:         Michal Tzvik
  --  Revision:          1.0
  --  creation date:     24/08/2015
  --------------------------------------------------------------------
  --  purpose :   main procedure. Used by concurrent executable 
  --              XXIBY_BANK_CONV_INTERFACE
  --
  --  Logic:     1. upload data from csv to interface table 
  --             2. process data
  --             3. set final status to records in interface table
  --             4. generate output report
  --
  --  parameters:
  --       x_err_code        OUT : 0- success, 1-warning, 2-error
  --       x_err_msg         OUT : error message
  --       p_table_name      IN  : Table name for uploading csv file 
  --       p_template_name   IN  : Template name for uploading csv file 
  --       p_file_name       IN  : File name for uploading csv file
  --       p_directory       IN  : Directory path for uploading csv file 
  --       p_simulation_mode IN  : If Y then run validations without API

  --------------------------------------------------------------------
  --  ver  date          name             desc
  --  1.0  24/08/2015    Michal Tzvik     CHG0035411 - initial build
  --------------------------------------------------------------------
  PROCEDURE main(errbuf            OUT VARCHAR2,
                 retcode           OUT VARCHAR2,
                 p_table_name      IN VARCHAR2, -- XXIBY_BANK_CONV_INTERFACE
                 p_template_name   IN VARCHAR2, -- JPMC
                 p_file_name       IN VARCHAR2,
                 p_directory       IN VARCHAR2,
                 p_simulation_mode IN VARCHAR2);

END xxiby_bank_conv_pkg;
/
