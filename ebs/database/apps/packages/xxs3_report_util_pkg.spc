CREATE OR REPLACE PACKAGE xxs3_report_util_pkg AUTHID CURRENT_USER

-- --------------------------------------------------------------------------------------------
-- Purpose: This Package is used for single Report Utilty Concurrent Program
--
-- --------------------------------------------------------------------------------------------
-- Ver  Date        Name                          Description
-- 1.0  18/05/2016  TCS                           Initial build
-- --------------------------------------------------------------------------------------------

 AS

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for single Report Utilty Concurrent Program
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE report_util(o_errbuff     OUT VARCHAR2
                       ,o_retcode     OUT VARCHAR2
                       ,i_entity_name IN VARCHAR2
                       ,i_report_type IN VARCHAR2);

END xxs3_report_util_pkg;
/
