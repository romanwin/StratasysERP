CREATE OR REPLACE PACKAGE xxcs_salesforce_utils_pkg IS

  --------------------------------------------------------------------
  --  customization code: CUST276 - Salesforce
  --  name:               xxcs_salesforce_utils_pkg
  --  create by:          ELLA.MALCHI
  --  $Revision:          1.0 $
  --  creation date:      23/04/2010
  --  Purpose :           Salceforce Integration
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   23/04/2010    ELLA.MALCHI     initial build
  --   --  1.2  5.7.11       YUVAL TAL    initiate_rates_process :  add dyn env param to bpel 
  -----------------------------------------------------------------------
  PROCEDURE initiate_rates_process(errbuf OUT VARCHAR2, retcode OUT NUMBER);
END xxcs_salesforce_utils_pkg;
/
