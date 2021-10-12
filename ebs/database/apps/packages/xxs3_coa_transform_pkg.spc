CREATE OR REPLACE PACKAGE xxs3_coa_transform_pkg

-- --------------------------------------------------------------------------------------------
-- Purpose: Package for legacy to S3 data transformation
-- --------------------------------------------------------------------------------------------
-- Ver  Date        Name                          Description
-- 1.0  16/05/2016  TCS               Initial build
-----------------------------------------------------------------------------------------------

 AS

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CoA transformation main procedure. This returns the concatenated GL string
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  16/05/2016  TCS                           Initial build
  -----------------------------------------------------------------------------------------------
  PROCEDURE coa_transform(p_field_name              IN VARCHAR2
                         ,p_legacy_company_val      IN VARCHAR2
                         , --Legacy Company Value
                          p_legacy_department_val   IN VARCHAR2
                         , --Legacy Department Value
                          p_legacy_account_val      IN VARCHAR2
                         , --Legacy Account Value
                          p_legacy_product_val      IN VARCHAR2
                         , --Legacy Product Value
                          p_legacy_location_val     IN VARCHAR2
                         , --Legacy Location Value
                          p_legacy_intercompany_val IN VARCHAR2
                         , --Legacy Intercompany Value
                          p_legacy_division_val     IN VARCHAR2
                         ,p_item_number             IN VARCHAR2 DEFAULT NULL
                         ,p_s3_org                  IN VARCHAR2 DEFAULT NULL
                         ,p_trx_type                IN VARCHAR2 --DEFAULT 'ALL'
                         ,p_set_of_books_id         IN VARCHAR2 DEFAULT NULL
                         ,p_debug_flag              IN VARCHAR2 DEFAULT 'N'
                         ,p_s3_gl_string            OUT VARCHAR2
                         ,p_err_code                OUT VARCHAR2
                         , -- Output error code
                          p_err_msg                 OUT VARCHAR2); --Output Message VARCHAR2(4000)



  -- --------------------------------------------------------------------------------------------
  -- Purpose: .This procedure takes the S3 GL string as input and updates the S3 CoA segments in 
  --           extract table 
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  16/05/2016  TCS                           Initial build
  -----------------------------------------------------------------------------------------------                                    p_err_msg                 OUT VARCHAR2); --Output Message VARCHAR2(4000)                         
  PROCEDURE coa_update(p_gl_string               IN VARCHAR2
                      , --concatenated GL string
                       p_stage_tab               IN VARCHAR2
                      , -- staging table name
                       p_stage_primary_col       IN VARCHAR2
                      , -- staging table primary column name
                       p_stage_primary_col_val   IN VARCHAR2
                      , -- staging table primary column value
                       p_stage_company_col       IN VARCHAR2
                      , -- s3_segment1
                       p_stage_business_unit_col IN VARCHAR2
                      , --s3_segment2
                       p_stage_department_col    IN VARCHAR2
                      , --s3_segment3
                       p_stage_account_col       IN VARCHAR2
                      , --s3_segment4
                       p_stage_product_line_col  IN VARCHAR2
                      , --s3_segment5
                       p_stage_location_col      IN VARCHAR2
                      , --s3_segment6
                       p_stage_intercompany_col  IN VARCHAR2
                      , --s3_segment7
                       p_stage_future_col        IN VARCHAR2
                      , --s3_segment8
                       p_coa_err_msg             IN VARCHAR2
                      , --error message during CoA transform
                       p_err_code                OUT VARCHAR2
                      ,p_err_msg                 OUT VARCHAR2);




END xxs3_coa_transform_pkg;
/
