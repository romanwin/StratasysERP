CREATE OR REPLACE PACKAGE xxs3_otc_location_pkg AUTHID CURRENT_USER AS

  ----------------------------------------------------------------------------
  --  name:            XXS3_OTC_LOCATION_PKG
  --  create by:       Mishal Kumar
  --  Revision:        1.0
  --  creation date:   06/05/2016
  ----------------------------------------------------------------------------
  --  purpose :        Package to extract LOCATION fields
  --                   from Legacy system
  ----------------------------------------------------------------------------
  --  ver  date        name                         desc
  --  1.0  06/05/2016  Mishal Kumar                 Initial build
  ----------------------------------------------------------------------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: Insert in to DQ table for validation of errors and update the master table
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  06/05/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  PROCEDURE insert_update_dq(p_xx_location_id     NUMBER,
                             p_rule_name          IN VARCHAR2,
                             p_reject_code        IN VARCHAR2,
                             p_legacy_location_id NUMBER);
  -- --------------------------------------------------------------------------------------------
  -- Purpose: Generate Data Quality Report
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0 26/04/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  PROCEDURE report_data_locations(p_entity VARCHAR2);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Extract data from staging tables for quality check of LOCATION track
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  06/05/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  PROCEDURE quality_check_locations;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required LOCATION fields and insert into
  --           staging table XXS3_OTC_PARTY_LOCATION
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  06/05/2016  Mishal Kumar                  Initial build  XXS3OTCPARTY XXS3PARTYEQT
  -- --------------------------------------------------------------------------------------------
  PROCEDURE location_extract_data(x_errbuf  OUT VARCHAR2,
                                  x_retcode OUT NUMBER
                                  /*p_email_id IN VARCHAR2,*/);

END xxs3_otc_location_pkg;
/
