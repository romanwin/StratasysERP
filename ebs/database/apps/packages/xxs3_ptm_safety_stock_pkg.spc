CREATE OR REPLACE PACKAGE xxs3_ptm_safety_stock_pkg AS
  ----------------------------------------------------------------------------
  --  purpose :        Package to extract the Item Safety Stock Details
  --                   from Legacy system

  ----------------------------------------------------------------------------
  --  ver  date        name                         desc
  --  1.0  23/09/2016  V.V.Sateesh                Initial build
  ----------------------------------------------------------------------------

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required Safety Stock Details and insert into
  --           staging table XXS3_PTM_ITEM_SAFETY_STOCK
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
 --  1.0  23/09/2016  V.V.Sateesh                Initial build
  -- --------------------------------------------------------------------------------------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required template fields and insert into
  --           staging table
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0  23/09/2016  V.V.Sateesh                Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE safety_stock_extract_data(x_errbuf  OUT VARCHAR2,
                    		          x_retcode OUT NUMBER);

   -- --------------------------------------------------------------------------------------------
  -- Purpose: Transform Report for the Items
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date          Name                          Description
  -- 1.0 17/08/2016   V.V.SATEESH                     Initial build
  -----------------------------------------------------------------------------------------------
  PROCEDURE data_transform_report (p_entity IN VARCHAR2);

  END  xxs3_ptm_safety_stock_pkg;
/
