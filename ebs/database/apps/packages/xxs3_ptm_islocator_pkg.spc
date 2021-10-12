CREATE OR REPLACE PACKAGE xxs3_ptm_islocator_pkg
-- ----------------------------------------------------------------------------------------------------------
-- Purpose:  This Package is used for Inventory Stock Locator Extraction, Quality Check and Report generation
--
-- ----------------------------------------------------------------------------------------------------------
-- Ver  Date        Name                          Description
-- 1.0  25/07/2016  TCS                           Initial build
-- ----------------------------------------------------------------------------------------------------------

 AS

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used to extract data for Inventory stock locator
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  25/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE inv_stock_locator_extract_data(p_errbuf  OUT VARCHAR2
                                          ,p_retcode OUT NUMBER);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used to cleanse data for Inventory stock locator
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  25/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE cleanse_data_isloc(p_errbuf  OUT VARCHAR2
                              ,p_retcode OUT NUMBER);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used to create report on data cleansing for Inventory stock locator
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  25/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE data_cleanse_report(p_entity VARCHAR2);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used to create report on data transformation for Inventory stock locator
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  25/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE data_transform_report(p_entity VARCHAR2);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used to create report on data Quality for Inventory stock locator
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  21/09/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE dq_report_islocator(p_entity VARCHAR2);

END xxs3_ptm_islocator_pkg;
/
