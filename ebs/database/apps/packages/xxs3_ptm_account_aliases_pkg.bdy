CREATE OR REPLACE PACKAGE BODY xxs3_ptm_account_aliases_pkg

-- --------------------------------------------------------------------------------------------
-- Purpose: This Package is used for Account Aliases Extract
--
-- --------------------------------------------------------------------------------------------
-- Ver  Date        Name                          Description
-- 1.0  18/05/2016  TCS                           Initial build
-- --------------------------------------------------------------------------------------------

 AS

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for Account Aliases Extract
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE account_aliases_extract_data(x_errbuf  OUT VARCHAR2
                                        ,x_retcode OUT NUMBER) AS

    CURSOR cur_account_aliases IS
      SELECT mgd.distribution_account
            ,mtp.organization_code
            ,mgd.segment1 alias
            ,mgd.description
            ,gcc.segment1 distribution_account_segment1
            ,gcc.segment2 distribution_account_segment2
            ,gcc.segment3 distribution_account_segment3
            ,gcc.segment4 distribution_account_segment4
            ,gcc.segment5 distribution_account_segment5
            ,gcc.segment6 distribution_account_segment6
            ,gcc.segment7 distribution_account_segment7
            ,gcc.segment8 distribution_account_segment8
            ,gcc.segment9 distribution_account_segment9
            ,mgd.effective_date effective_on
        FROM mtl_generic_dispositions mgd
            ,gl_code_combinations     gcc
            ,mtl_parameters           mtp
       WHERE mgd.distribution_account = gcc.code_combination_id
         AND mgd.organization_id = mtp.organization_id
       ORDER BY organization_code;

      /* cursor c_transform AS select * from xxobjt.XXS3_PTM_ACCOUNT_ALIASES*/
  BEGIN
    DELETE FROM xxobjt.XXS3_PTM_ACCOUNT_ALIASES;
    FOR i IN cur_account_aliases LOOP
      INSERT INTO xxobjt.XXS3_PTM_ACCOUNT_ALIASES
        (xx_account_aliases_id
        ,distribution_account
        ,organization_code
        ,description
        ,distribution_account_segment1
        ,distribution_account_segment2
        ,distribution_account_segment3
        ,distribution_account_segment4
        ,distribution_account_segment5
        ,distribution_account_segment6
        ,distribution_account_segment7
        ,distribution_account_segment8
        ,distribution_account_segment9
        ,effective_on)
      VALUES
        (xx_ptm_account_aliases_seq.NEXTVAL
        ,i.distribution_account
        ,i.organization_code
        ,i.description
        ,i.distribution_account_segment1
        ,i.distribution_account_segment2
        ,i.distribution_account_segment3
        ,i.distribution_account_segment4
        ,i.distribution_account_segment5
        ,i.distribution_account_segment6
        ,i.distribution_account_segment7
        ,i.distribution_account_segment8
        ,i.distribution_account_segment9
        ,i.effective_on);
    END LOOP;
    COMMIT;

  /*  FOR k in c_transform LOOP

     l_s3_gl_string := null;

	  IF k.distribution_account IS NOT NULL THEN
	  l_step := 'distribution_accountt';
          xxs3_data_transform_util_pkg.coa_item_master_transform(p_field_name              => 'DISTRIBUTION_ACCOUNT',                    -- Field Name
                                                                  p_s3_org_code             => k.s3_organization_code,              -- s3 org code
                                                                  p_legacy_company_val      => k.distribution_account_segment1,      -- legacy company value
                                                                  p_legacy_department_val   => k.distribution_account_segment2,      -- legacy department value
                                                                  p_legacy_account_val      => k.distribution_account_segment3,      -- legacy account value
                                                                  p_legacy_product_val      => k.distribution_account_segment5,      -- legacy product value
                                                                  p_legacy_location_val     => k.distribution_account_segment6,      -- legacy location value
                                                                  p_legacy_intercompany_val => k.distribution_account_segment7,      -- legacy intercompany value
                                                                  p_legacy_division_val     => k.distribution_account_segment10,     -- legacy division value
                                                                  p_item_number             => NULL,					              	-- Item Number
                                                                  p_s3_gl_string            => l_s3_gl_string,
                                                                  p_err_code                => l_output_code,                       -- Error Code
                                                                  p_err_msg                 => l_output);                           -- Output Message

          xxs3_data_transform_util_pkg.coa_update(p_gl_string               => l_s3_gl_string,
                                                   p_stage_tab               => 'xxobjt.XXS3_PTM_ACCOUNT_ALIASES',     -- Staging Table Name
                                                   p_stage_primary_col       => 'xx_account_aliases_id',				   -- Staging Table Primary Column Name
                                                   p_stage_primary_col_val   => k.xx_account_aliases_id,				   -- Staging Table Primary Column Value
                                                   p_stage_company_col       => 's3_distribution_account_segment1',      -- S3 Company Value
                                                   p_stage_business_unit_col => 's3_distribution_account_segment2',		   -- S3 Busineess Unit Value
                                                   p_stage_department_col    => 's3_distribution_account_segment3',      -- S3 Department Value
                                                   p_stage_account_col       => 's3_distribution_account_segment4',      -- S3 Account Value
                                                   p_stage_product_line_col  => 's3_distribution_account_segment5',      -- S3 Product Line Value
                                                   p_stage_location_col      => 's3_distribution_account_segment6',      -- S3 Location Value
                                                   p_stage_intercompany_col  => 's3_distribution_account_segment7',      -- S3 InterCompany Value
                                                   p_stage_future_col        => 's3_distribution_account_segment8',      -- S3 Featuere Value
                                                   p_coa_err_msg             => l_output,
                                                   p_err_code                => l_output_code_coa_update,        -- Error Code
                                                   p_err_msg                 => l_output_coa_update);            -- Error Message
        END IF;


        xxs3_data_transform_util_pkg.transform(p_mapping_type          => 'inventory_org',				             --Mapping type
                                                p_stage_tab             => 'xxobjt.XXS3_PTM_ACCOUNT_ALIASES', -- Staging Table Name
                                                p_stage_primary_col     => 'xx_account_aliases_id',             -- Staging Table Primary Column Name
                                                p_stage_primary_col_val => k.xx_account_aliases_id,             -- Staging Table Primary Column Value
                                                p_legacy_val            => k.legacy_organization_code,         -- Legacy Value
                                                p_stage_col             => 's3_organization_code',             -- Staging Table Name
                                                p_err_code              => l_err_code,                         -- Output error code
                                                p_err_msg               => l_err_msg);                         -- Error Message


        END LOOP;
        COMMIT;*/

  END account_aliases_extract_data;
END xxs3_ptm_account_aliases_pkg;
/