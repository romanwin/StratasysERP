CREATE OR REPLACE PACKAGE xxs3_ptm_item_cat_assign_pkg
  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Package is used for Item Category Assignment Data Extract
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  Santanu                           Initial build
  -- --------------------------------------------------------------------------------------------

AS

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used for Item Category Assignment Data Extract
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  Satanu                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE item_cat_assign_extract(p_retcode OUT VARCHAR2
                                   ,p_errbuf  OUT VARCHAR2);
END xxs3_ptm_item_cat_assign_pkg;
/
