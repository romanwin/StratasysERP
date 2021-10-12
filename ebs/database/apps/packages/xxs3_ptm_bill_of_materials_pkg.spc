CREATE OR REPLACE PACKAGE xxs3_ptm_bill_of_materials_pkg

-- --------------------------------------------------------------------------------------------
-- Purpose: This Package is used for Bills Of Material Extract, Quality Check and Report
--
-- --------------------------------------------------------------------------------------------
-- Ver  Date        Name                          Description
-- 1.0  18/05/2016  Santanu                           Initial build
-- --------------------------------------------------------------------------------------------

 AS

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used to BOM extract data
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  Santanu                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE bill_of_materials_extract_data(x_errbuf  OUT VARCHAR2
                                          ,x_retcode OUT NUMBER
                                          /*,p_orgcode IN VARCHAR2*/);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used to qality check BOM
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  Santanu                       Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE quality_check_bom(p_err_code OUT VARCHAR2
                             ,p_err_msg  OUT VARCHAR2);

   -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used for Approved Suppliers Transform Report
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  Santanu                           Initial build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE data_transform_report(p_entity VARCHAR2);
   -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used to BOM Quality Report
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  Santanu                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE bom_report_data(p_entity VARCHAR2);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is for cleanse BOM
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  Santanu                       Initial build
  -- --------------------------------------------------------------------------------------------

   PROCEDURE cleanse_bom(p_err_code OUT VARCHAR2
                       ,p_err_msg  OUT VARCHAR2);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is for Cleanse Report
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  Santanu                       Initial build
  -- --------------------------------------------------------------------------------------------

   PROCEDURE data_cleanse_report(p_entity VARCHAR2) ;

END xxs3_ptm_bill_of_materials_pkg;
/
