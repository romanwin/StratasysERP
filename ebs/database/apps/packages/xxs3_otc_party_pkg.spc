CREATE OR REPLACE PACKAGE xxs3_otc_party_pkg AUTHID CURRENT_USER AS

  ----------------------------------------------------------------------------
  --  name:            XXS3_OTC_PARTY_PKG
  --  create by:       Mishal Kumar
  --  Revision:        1.0
  --  creation date:   26/04/2016
  ----------------------------------------------------------------------------
  --  purpose :        Package to extract PPARTY fields
  --                   from Legacy system
  ----------------------------------------------------------------------------
  --  ver  date        name                         desc
  --  1.0  26/04/2016  Mishal Kumar                 Initial build
  ----------------------------------------------------------------------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: Insert in to DQ table for validation of errors and update the master table
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  26/04/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  PROCEDURE insert_update_dq(p_xx_party_id NUMBER
                            ,p_rule_name   IN VARCHAR2
                            ,p_reject_code IN VARCHAR2);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Extract data from staging tables for quality check of PARTY track
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  26/04/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  PROCEDURE quality_check_party;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required PARTY fields and insert into
  --           staging table XXS3_OTC_PARTY_TAB
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  26/04/2016  Mishal Kumar                  Initial build  XXS3OTCPARTY XXS3PARTYEQT
  -- --------------------------------------------------------------------------------------------
  PROCEDURE party_extract_data(x_errbuf  OUT VARCHAR2
                              ,x_retcode OUT NUMBER
                               /*p_email_id IN VARCHAR2,*/);
  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required Party Sites fields and insert into
  --           staging table XXS3_OTC_PARTIES
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0 26/04/2016  Mishal Kumar                  Initial build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE party_sites_extract_data(x_errbuf  OUT VARCHAR2
                                    ,x_retcode OUT NUMBER
                                     /*p_email_id IN VARCHAR2,*/);
  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required Party Site Uses fields and insert into
  --           staging table XXS3_OTC_PARTIES
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0 26/04/2016  Mishal Kumar                  Initial build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE party_site_uses_extract_data(x_errbuf  OUT VARCHAR2
                                        ,x_retcode OUT NUMBER
                                         /*p_email_id IN VARCHAR2,*/);
  --PROCEDURE dq_party_report_data;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will generate Reject
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0 26/04/2016  Mishal Kumar                  Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE dq_party_report_data_reject(p_entity IN VARCHAR2);
  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will generate DQ Report
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0 26/04/2016  Mishal Kumar                  Initial build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE dq_party_cont_report_data(p_entity IN VARCHAR2);
  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will generate DQ Report
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0 26/04/2016  Mishal Kumar                  Initial build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE data_cleanse_cont_report(p_entity IN VARCHAR2);
  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required Party Site Uses fields and insert into
  --           staging table XXS3_OTC_PARTIES
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0 26/04/2016  Mishal Kumar                  Initial build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE party_relation_extract_data(x_errbuf  OUT VARCHAR2
                                       ,x_retcode OUT NUMBER
                                        /*p_email_id IN VARCHAR2,*/);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required Party Contact fields and insert into
  --           staging table XXS3_OTC_PARTY_CONTACTS
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0 17/08/2016  Debarati Banerjee                Initial build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE party_contact_extract_data(x_errbuf  OUT VARCHAR2
                                      ,x_retcode OUT NUMBER);
  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required Party Site Uses fields and insert into
  --           staging table XXS3_OTC_PARTIES
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0 26/04/2016  Mishal Kumar                  Initial build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE party_contact_pts_extract_data(x_errbuf  OUT VARCHAR2
                                          ,x_retcode OUT NUMBER
                                           /*p_email_id IN VARCHAR2,*/);
  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required Party Site Uses fields and insert into
  --           staging table XXS3_OTC_PARTIES
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0 26/04/2016  Mishal Kumar                  Initial build
  -- --------------------------------------------------------------------------------------------
  /*PROCEDURE party_role_extract_data(x_errbuf  OUT VARCHAR2,
  x_retcode OUT NUMBER);*/
  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will generate DQ Report
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0 26/04/2016  Mishal Kumar                  Initial build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE data_cleanse_report(p_entity IN VARCHAR2);
  
    --------------------------------------------------------------------
  --  name:              data_transform_report
  --  create by:       Debarati banerjee
  --  Revision:          1.0
  --  creation date:     06/01/2016
  --------------------------------------------------------------------
  --  purpose :          write data transform report to output
  --
  --------------------------------------------------------------------
  --  ver  date          name                   desc
  --  1.0  06/01/2016   Debarati banerjee       report data transform
  --------------------------------------------------------------------

  PROCEDURE data_transform_report(p_entity IN VARCHAR2);

END xxs3_otc_party_pkg;
/
