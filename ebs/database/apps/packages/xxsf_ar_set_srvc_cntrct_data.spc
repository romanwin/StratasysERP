CREATE OR REPLACE PACKAGE xxsf_ar_set_srvc_cntrct_data IS
  --------------------------------------------------------------------
  --  customization code: CHG0035139
  --  name:               XXSF_AR_SET_SRVC_CNTRCT_DATA
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  creation date:      25/05/2015
  --  Description:        Several changes regarding entering service contract through initial sale
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   25/05/2015    Michal Tzvik    initial build
  --------------------------------------------------------------------

  ----------------------------------------------------------------------
  --  customization code: CHG0035139
  --  name:               main
  --  create by:          Michal Tzvik
  --  creation date:      25/05/2015
  --  Purpose :           CHG0035139
  --
  --                      Populate DFFs in AR invoice line for service contract items
  --                      If they are empty, with values from SalesForce and IB.
  --                      Concurrent executable name: XXSF_AR_SET_SRVC_CNTRCT_DATA
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   25/05/2015    Michal Tzvik    initial build
  ---------------------------------------------------------------------- 
  PROCEDURE main(errbuf  OUT VARCHAR2,
                 retcode OUT VARCHAR2);

END xxsf_ar_set_srvc_cntrct_data;
/
