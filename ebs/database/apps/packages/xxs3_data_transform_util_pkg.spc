CREATE OR REPLACE PACKAGE xxs3_data_transform_util_pkg

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
  PROCEDURE coa_transform(p_field_name IN VARCHAR2
                          --Field Name
                         ,
                          p_legacy_company_val      IN VARCHAR2, --Legacy Company Value
                          p_legacy_department_val   IN VARCHAR2, --Legacy Department Value
                          p_legacy_account_val      IN VARCHAR2, --Legacy Account Value
                          p_legacy_product_val      IN VARCHAR2, --Legacy Product Value
                          p_legacy_location_val     IN VARCHAR2, --Legacy Location Value
                          p_legacy_intercompany_val IN VARCHAR2, --Legacy Intercompany Value
                          p_legacy_division_val     IN VARCHAR2,
                          p_item_number             IN VARCHAR2 DEFAULT NULL,
                          p_s3_gl_string            OUT VARCHAR2,
                          p_err_code                OUT VARCHAR2 --Output error code
                         ,
                          p_err_msg                 OUT VARCHAR2); --Output Message VARCHAR2(4000)

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CoA transformation main procedure for item master. This returns the concatenated
  --          GL string
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  01/08/2016  TCS                           Initial build
  -----------------------------------------------------------------------------------------------


  PROCEDURE coa_item_master_transform(p_field_name              IN VARCHAR2,
                                      p_s3_org_code             IN VARCHAR2,
                                      p_legacy_company_val      IN VARCHAR2, --Legacy Company Value
                                      p_legacy_department_val   IN VARCHAR2, --Legacy Department Value
                                      p_legacy_account_val      IN VARCHAR2, --Legacy Account Value
                                      p_legacy_product_val      IN VARCHAR2, --Legacy Product Value
                                      p_legacy_location_val     IN VARCHAR2, --Legacy Location Value
                                      p_legacy_intercompany_val IN VARCHAR2, --Legacy Intercompany Value
                                      p_legacy_division_val     IN VARCHAR2,
                                      p_item_number             IN VARCHAR2 DEFAULT NULL,
                                      p_s3_gl_string            OUT VARCHAR2,
                                      p_err_code                OUT VARCHAR2, -- Output error code
                                      p_err_msg                 OUT VARCHAR2);

      -- --------------------------------------------------------------------------------------------
  -- Purpose: CoA transformation main procedure for Open GL Balances. This returns the concatenated
  --          GL string
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  23/09/2016  TCS                           Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE coa_gl_balance_transform(p_field_name              IN VARCHAR2,
                          p_legacy_company_val      IN VARCHAR2, --Legacy Company Value
                          p_legacy_department_val   IN VARCHAR2, --Legacy Department Value
                          p_legacy_account_val      IN VARCHAR2, --Legacy Account Value
                          p_legacy_product_val      IN VARCHAR2, --Legacy Product Value
                          p_legacy_location_val     IN VARCHAR2, --Legacy Location Value
                          p_legacy_intercompany_val IN VARCHAR2, --Legacy Intercompany Value
                          p_legacy_division_val     IN VARCHAR2,
                          p_item_number             IN VARCHAR2 DEFAULT NULL,
                          p_s3_gl_string            OUT VARCHAR2,
                          p_err_code                OUT VARCHAR2, -- Output error code
                          p_err_msg                 OUT VARCHAR2) ;
    -- --------------------------------------------------------------------------------------------
  -- Purpose: CoA transformation main procedure for Open PO. This returns the concatenated
  --          GL string
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  23/09/2016  TCS                           Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE coa_open_po_transform(p_field_name              IN VARCHAR2,
                          p_legacy_company_val      IN VARCHAR2, --Legacy Company Value
                          p_legacy_department_val   IN VARCHAR2, --Legacy Department Value
                          p_legacy_account_val      IN VARCHAR2, --Legacy Account Value
                          p_legacy_product_val      IN VARCHAR2, --Legacy Product Value
                          p_legacy_location_val     IN VARCHAR2, --Legacy Location Value
                          p_legacy_intercompany_val IN VARCHAR2, --Legacy Intercompany Value
                          p_legacy_division_val     IN VARCHAR2,
                          p_item_number             IN VARCHAR2 DEFAULT NULL,
                          p_s3_gl_string            OUT VARCHAR2,
                          p_err_code                OUT VARCHAR2, -- Output error code
                          p_err_msg                 OUT VARCHAR2);

   -- --------------------------------------------------------------------------------------------
  -- Purpose: .This procedure takes the S3 GL string as input and updates the S3 CoA segments in
  --           extract table
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  16/05/2016  TCS                           Initial build
  -----------------------------------------------------------------------------------------------                                    p_err_msg                 OUT VARCHAR2); --Output Message VARCHAR2(4000)
PROCEDURE coa_update(p_gl_string               IN VARCHAR2,--concatenated GL string
                       p_stage_tab               IN VARCHAR2,-- staging table name
                       p_stage_primary_col       IN VARCHAR2,-- staging table primary column name
                       p_stage_primary_col_val   IN VARCHAR2,-- staging table primary column value
                       p_stage_company_col       IN VARCHAR2,-- s3_segment1
                       p_stage_business_unit_col IN VARCHAR2,--s3_segment2
                       p_stage_department_col    IN VARCHAR2,--s3_segment3
                       p_stage_account_col       IN VARCHAR2,--s3_segment4
                       p_stage_product_line_col  IN VARCHAR2,--s3_segment5
                       p_stage_location_col      IN VARCHAR2,--s3_segment6
                       p_stage_intercompany_col  IN VARCHAR2,--s3_segment7
                       p_stage_future_col        IN VARCHAR2,--s3_segment8
                       p_coa_err_msg             IN VARCHAR2,--error message during CoA transform
                       p_err_code                OUT VARCHAR2,
                       p_err_msg                 OUT VARCHAR2);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Transformations for inventory stock Locator - Attribute2 parsing
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date         Name                          Description
  -- 1.0  29/07/2016 Paulami Ray                   Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE ptm_locator_attr2_parse(p_attribute2          IN VARCHAR2,
                                    p_att_org_code        OUT VARCHAR2,
                                    p_att_subinv          OUT VARCHAR2,
                                    p_att_concat_segments OUT VARCHAR2,
                                    p_att_row             OUT VARCHAR2,
                                    p_att_rack            OUT VARCHAR2,
                                    p_att_bin             OUT VARCHAR2,
                                    p_error_message       OUT VARCHAR2);
  -- --------------------------------------------------------------------------------------------
  -- Purpose: Generic Transformation procedure which will call the transform_function procedure
  --          to derive the S3 transformed value for a legacy value and update the relevant column
  --          in staging table
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  11/07/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE transform(p_mapping_type IN VARCHAR2,           --Mapping Type
                      p_stage_tab             IN VARCHAR2, --Staging Table Name
                      p_stage_primary_col     IN VARCHAR2, --Staging Table Primary Column Name
                      p_stage_primary_col_val IN VARCHAR2, --Staging Table Primary Column Value
                      p_legacy_val            IN VARCHAR2, --Legacy Value
                      p_stage_col             IN VARCHAR2, -- Staging Table Transformed Column Name
                      p_other_col             IN VARCHAR2 DEFAULT NULL,--Required for additional attributes required during transformation
                      p_err_code OUT VARCHAR2, -- Output error code
                      p_err_msg  OUT VARCHAR2);

END xxs3_data_transform_util_pkg;
/
