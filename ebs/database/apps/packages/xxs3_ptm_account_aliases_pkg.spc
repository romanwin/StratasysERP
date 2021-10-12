CREATE OR REPLACE PACKAGE xxs3_ptm_account_aliases_pkg

-- --------------------------------------------------------------------------------------------
-- Purpose: This Package is used for Account Aliases Extract
--
-- --------------------------------------------------------------------------------------------
-- Ver  Date        Name                          Description
-- 1.0  18/05/2016  TCS                           Initial build
-- --------------------------------------------------------------------------------------------

 AS

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Package is used for Account Aliases Extract
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE account_aliases_extract_data(x_errbuf  OUT VARCHAR2
                                        ,x_retcode OUT NUMBER);
END xxs3_ptm_account_aliases_pkg;
/
