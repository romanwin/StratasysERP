CREATE OR REPLACE PACKAGE xxs3_ptm_item_trx_def_pkg

-- --------------------------------------------------------------------------------------------
-- Purpose: This Package is used for Subinventories Extract, Quality Check and Report
--
-- --------------------------------------------------------------------------------------------
-- Ver  Date        Name                          Description
-- 1.0  29/07/2016  TCS                           Initial build
-- --------------------------------------------------------------------------------------------

 AS

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for Subinventories Extract
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  29/07/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE item_trx_def_extract_data(x_errbuf  OUT VARCHAR2,
                                      x_retcode OUT NUMBER);

  PROCEDURE data_cleanse_report(p_entity VARCHAR2);

  PROCEDURE data_transform_report(p_entity VARCHAR2);

END xxs3_ptm_item_trx_def_pkg;
/
