CREATE OR REPLACE PACKAGE xxs3_ptm_category_set_pkg
-- --------------------------------------------------------------------------------------------
-- Purpose: This Package is used for Item Category Set Extract, Quality Check and Report
--
-- --------------------------------------------------------------------------------------------
-- Ver  Date        Name                          Description
-- 1.0  18/05/2016  Santanu                           Initial build
-- --------------------------------------------------------------------------------------------

 AS

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for Item Category Set Extract
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  Santanu                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE extract_category_set(x_retcode OUT VARCHAR2
                                ,x_errbuf  OUT VARCHAR2);
  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for Item Category Set DQ Report
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  Santanu                           Initial build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE dq_report_category_set(p_entity VARCHAR2);

END xxs3_ptm_category_set_pkg;
/
