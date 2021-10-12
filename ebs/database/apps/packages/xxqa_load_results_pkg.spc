CREATE OR REPLACE PACKAGE xxqa_load_results_pkg IS

  --------------------------------------------------------------------
  --  name:            XXQA_LOAD_RESULTS_PKG
  --  create by:       Eran Baram
  --  Revision:        1.0 
  --  creation date:   19/01/2011
  --------------------------------------------------------------------
  --  purpose :        CUST276 - Load QA plans from excel files
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  19/01/2011  Eran Baram    initial build
  --------------------------------------------------------------------

  PROCEDURE load_sn_reporting_plan(errbuf     OUT VARCHAR2,
                                   retcode    OUT VARCHAR2,
                                   p_location IN VARCHAR2,
                                   p_filename IN VARCHAR2);

END xxqa_load_results_pkg;
/

