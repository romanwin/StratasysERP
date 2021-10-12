CREATE OR REPLACE PACKAGE xxs3_otc_cust_profile_pkg AUTHID CURRENT_USER AS

  ----------------------------------------------------------------------------
  --  name:            XXS3_OTC_CUST_PROFILE_PKG
  --  create by:       Mishal Kumar
  --  Revision:        1.0
  --  creation date:   23/05/2016
  ----------------------------------------------------------------------------
  --  purpose :        Package to extract the Customer Profile fields
  --                   from Legacy system
  ----------------------------------------------------------------------------
  --  ver  date        name                         desc
  --  1.0  23/05/2016  Mishal Kumar                 Initial build
  ----------------------------------------------------------------------------
  report_error EXCEPTION;

  g_request_id CONSTANT NUMBER := fnd_global.conc_request_id;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Insert in to DQ table for validation of errors and update the master table
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  26/04/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  PROCEDURE insert_update_dq(p_xx_customer_profiles_id     IN NUMBER,
                             p_rule_name                   IN VARCHAR2,
                             p_reject_code                 IN VARCHAR2,
                             p_legacy_cust_acct_profile_id NUMBER);
  -- --------------------------------------------------------------------------------------------
  -- Purpose: Insert in to DQ table for validation of errors and update the master table against reject
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  26/04/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  PROCEDURE insert_update_dq_r(p_xx_customer_profiles_id     IN NUMBER,
                               p_rule_name                   IN VARCHAR2,
                               p_reject_code                 IN VARCHAR2,
                               p_legacy_cust_acct_profile_id NUMBER);
  -- --------------------------------------------------------------------------------------------
  -- Purpose: Insert in to DQ table for validation of errors for Customer profile amounts
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  26/04/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  PROCEDURE insert_update_amt_dq(p_xx_cust_profile_amt_id       IN NUMBER,
                                 p_rule_name                    IN VARCHAR2,
                                 p_reject_code                  IN VARCHAR2,
                                 p_legacy_cust_acct_prof_amt_id NUMBER);
  -- --------------------------------------------------------------------------------------------
  -- Purpose: Extract data from staging tables for quality check of Customer Profiles
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  26/04/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE quality_check_profiles;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: Extract data from staging tables for quality check of Customer Profile Amounts
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  23/05/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE quality_check_profile_amts;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: Generate Data Quality Report for Customer Profiles
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0 24/05/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  PROCEDURE report_data_cust_profiles(p_entity IN VARCHAR2);
  -- --------------------------------------------------------------------------------------------
  -- Purpose: Generate Data Quality Report for Customer Profile Amounts
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0 24/05/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  PROCEDURE report_data_cust_profile_amts(p_entity IN VARCHAR2);
  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required Customer Profiles fields and insert into
  --           staging table XXS3_OTC_CUSTOMER_PROFILES
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0 26/04/2016  Mishal Kumar                  Initial build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE profile_extract_data(x_errbuf  OUT VARCHAR2,
                                 x_retcode OUT NUMBER);
  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required Customer Profiles fields and insert into
  --           staging table XXS3_OTC_CUSTOMER_PROFILES
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0 26/04/2016  Mishal Kumar                  Initial build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE profile_amt_extract_data(x_errbuf  OUT VARCHAR2,
                                     x_retcode OUT NUMBER);
END xxs3_otc_cust_profile_pkg;
/

