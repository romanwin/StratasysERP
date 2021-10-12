CREATE OR REPLACE PACKAGE xxs3_ptm_item_recon_pkg AUTHID CURRENT_USER AS
  p_item     VARCHAR2(100);
  p_org_code VARCHAR2(10);
    ----------------------------------------------------------------------------
  --  Name:            xxs3_ptm_item_recon_main_prc
  --  Create by:       V.V.SATEESH
  --  Revision:        1.0
  --  Creation date:  10/11/2016
  ----------------------------------------------------------------------------
  --  Purpose :        Item Master Extract Recon Report
  ----------------------------------------------------------------------------
  --  Ver  Date        Name                         Description
  --  1.0 17/08/2016  V.V.SATEESH                   Initial build
  ----------------------------------------------------------------------------
  PROCEDURE xxs3_ptm_item_recon_prc(x_errbuf   OUT VARCHAR2
                                   ,x_retcode  OUT NUMBER
                                   ,p_item     IN VARCHAR2
                                   ,p_org_code IN VARCHAR2);
 --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used to Update Values in stage table
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  17/11/2016  V.V.Sateesh                Initial build
  -- --------------------------------------------------------------------------------------------
                                  

  PROCEDURE xxs3_item_recon_report_prc(p_stage_tab IN VARCHAR2
                                       -- ,p_stage_column in varchar2
                                      ,p_stage_status_col_val      IN VARCHAR2
                                      ,p_stage_legacy_org_code_val IN VARCHAR2
                                      ,p_ts3_org_code_col_val      IN VARCHAR2
                                      ,p_leg_attr_usr_value_val    IN VARCHAR2
                                      ,p_s3_eqt_attr_value_val     IN VARCHAR2
                                      ,p_s3_eqt_attr_usr_value_val IN VARCHAR2
                                      ,p_s3_loaded_value_val       IN VARCHAR2
                                      ,p_cleanse_rule_val          IN VARCHAR2
                                      ,p_dq_rpt_rule_val           IN VARCHAR2
                                      ,p_dq_rjt_rule_val           IN VARCHAR2
                                      ,p_transform_rule_val        IN VARCHAR2
                                      ,p_extract_rule_val          IN VARCHAR2
                                      ,p_eqt_process_flag_val      IN VARCHAR2
                                      ,p_date_extracted_val        IN VARCHAR2
                                      ,p_date_load_on_val          IN VARCHAR2
                                      ,p_attr_grp_name_val         IN VARCHAR2
                                      ,p_attr_name_val             IN VARCHAR2
                                      ,p_org_mstr_cntrl_val        IN VARCHAR2
                                      ,p_stage_primary_col         IN VARCHAR2
                                      ,p_stage_primary_col_val     IN VARCHAR2
                                      ,p_primary_item_col          IN VARCHAR2
                                      ,p_primary_item_col_val      IN VARCHAR2
                                      ,p_err_code                  OUT VARCHAR2
                                      , -- Output error code
                                       p_err_msg                   OUT VARCHAR2);

END xxs3_ptm_item_recon_pkg;
/