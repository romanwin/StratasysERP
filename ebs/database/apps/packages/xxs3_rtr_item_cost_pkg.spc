CREATE OR REPLACE PACKAGE xxs3_rtr_item_cost_pkg

-- --------------------------------------------------------------------------------------------
-- Purpose: This Package is used for Item Cost Extract, Quality Check and Report
--
-- --------------------------------------------------------------------------------------------
-- Ver  Date        Name                          Description
-- 1.0  29/07/2016  TCS                           Initial build
-- --------------------------------------------------------------------------------------------

 AS

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for Item Cost Extract
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  29/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE item_cost_extract_data(x_errbuf  OUT VARCHAR2
                                  ,x_retcode OUT NUMBER);

  PROCEDURE quality_check_item_cost(p_err_code OUT VARCHAR2
                                   ,p_err_msg  OUT VARCHAR2);

  PROCEDURE data_transform_report(p_entity VARCHAR2);

  PROCEDURE item_cost_report_data(p_entity_name IN VARCHAR2);

END xxs3_rtr_item_cost_pkg;
