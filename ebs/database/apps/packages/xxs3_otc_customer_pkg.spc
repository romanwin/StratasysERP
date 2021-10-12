CREATE OR REPLACE PACKAGE xxs3_otc_customer_pkg AUTHID CURRENT_USER AS
  ----------------------------------------------------------------------------
  --  name:            XXS3_OTC_CUSTOMER_PKG
  --  create by:       Mishal Kumar
  --  Revision:        1.0
  --  creation date:   11/05/2016
  ----------------------------------------------------------------------------
  --  purpose :        Package to extract the Customer fields
  --                   from Legacy system
  ----------------------------------------------------------------------------
  --  ver  date        name                         desc
  --  1.0  11/05/2016  Mishal Kumar                 Initial build
  ----------------------------------------------------------------------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: Insert in to DQ table for validation of errors and update the master table
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  11/05/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  PROCEDURE insert_update_dq(p_xx_cust_account_id     IN NUMBER,
                             p_rule_name              IN VARCHAR2,
                             p_reject_code            IN VARCHAR2,
                             p_legacy_cust_account_id NUMBER);
  -- --------------------------------------------------------------------------------------------
  -- Purpose: Insert in to DQ table for validation of errors and update the master table
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  11/05/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  PROCEDURE insert_update_uses_dq(p_xx_cust_acct_site_use_id IN NUMBER,
                                  p_rule_name                IN VARCHAR2,
                                  p_reject_code              IN VARCHAR2,
                                  p_legacy_site_use_id       NUMBER);
                                  

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Extract data from staging tables for quality check of CUSTOMER track
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  11/05/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  PROCEDURE quality_check_cust_accounts;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: Generate Data Quality Report for Cusomer Accounts
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0 26/04/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  PROCEDURE report_data_cus_acct(p_entity VARCHAR2);
  -- --------------------------------------------------------------------------------------------
  -- Purpose: Extract data from staging tables for quality check of CUSTOMER_SITE_USES track
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  11/05/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  PROCEDURE quality_check_cust_site_uses;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: Generate Data Quality Report for Customer Account Uses
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0 26/04/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  PROCEDURE report_data_cus_acct_uses (p_entity VARCHAR2);
  -- --------------------------------------------------------------------------------------------
  -- Purpose: Generate excel report
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0 26/08/2016  vvsateesh                  Initial build
  ---------------------------------------------------------------------------------------------

   PROCEDURE data_transform_report(p_entity VARCHAR2);
  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required Customer Account  fields
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0 11/05/2016  Mishal Kumar                  Initial build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE customer_extract_data(x_errbuf  OUT VARCHAR2,
                                  x_retcode OUT NUMBER
                                  /*p_email_id IN VARCHAR2,*/);
  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required Customer site uses fields
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0 11/05/2016  Mishal Kumar                  Initial build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE cust_site_uses_extract_data(x_errbuf  OUT VARCHAR2,
                                        x_retcode OUT NUMBER);
  --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required Customer Sites  fields
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0 11/05/2016  Mishal Kumar                  Initial build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE cust_site_extract_data(x_errbuf  OUT VARCHAR2,
                                   x_retcode OUT NUMBER);
                                   
  --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required Customer Contact  fields
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0 11/05/2016  Mishal Kumar                  Initial build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE cust_contact_extract_data(x_errbuf  OUT VARCHAR2
                                  ,x_retcode OUT NUMBER);                                 
  --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required Customer Sites  fields
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0 11/05/2016  Mishal Kumar                  Initial build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE cust_relation_extract_data(x_errbuf  OUT VARCHAR2,
                                       x_retcode OUT NUMBER);
                                       
    -- --------------------------------------------------------------------------------------------
  -- Purpose: Data cleanse Report
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0 6/01/2017  Debarati banerjee                  Initial build
  -----------------------------------------------------------------------------------------------
  
  PROCEDURE data_cleanse_report(p_entity IN VARCHAR2);                                     
END xxs3_otc_customer_pkg;
/