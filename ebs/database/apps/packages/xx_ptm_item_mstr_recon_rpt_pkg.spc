CREATE OR REPLACE PACKAGE xx_ptm_item_mstr_recon_rpt_pkg AS
  p_item     VARCHAR2(100);
  p_org_code VARCHAR2(10);
   ----------------------------------------------------------------------------
  --  Purpose :        Item Master Extract Recon Report
  ----------------------------------------------------------------------------
  --  Ver  Date        Name                         Description
  --  1.0 10/11/2016  V.V.SATEESH                   Initial build
  ----------------------------------------------------------------------------

PROCEDURE xx_ptm_item_master_recon_prc(x_errbuf   OUT VARCHAR2
                                      ,x_retcode  OUT NUMBER
                                      ,p_item     IN VARCHAR2
                                      ,p_org_code IN VARCHAR2) ;
   ----------------------------------------------------------------------------
  --  Purpose :        Item Master Extract Recon Report
  ----------------------------------------------------------------------------
  --  Ver  Date        Name                         Description
  --  1.0 10/11/2016  V.V.SATEESH                   Initial build
  ----------------------------------------------------------------------------
  procedure xx_item_mstr_recon_report_prc(p_stage_primary_col IN VARCHAR2
                                          ,p_primary_item_col_val IN VARCHAR2
                                          ,p_leg_attr_value IN VARCHAR2
                                       	  ,p_leg_attr_usr_value_val IN VARCHAR2
                                          ,p_s3_eqt_attr_value_val     IN VARCHAR2
                                          ,p_s3_eqt_attr_usr_value_val IN VARCHAR2
                                          ,p_s3_loaded_value_val       IN VARCHAR2
                                          ,p_cleanse_rule_val          IN VARCHAR2
                                          ,p_dq_rpt_rule_val           IN VARCHAR2
                                          ,p_dq_rjt_rule_val           IN VARCHAR2
                                          ,p_transform_rule_val        IN VARCHAR2
                                           ,p_date_load_on_val          IN VARCHAR2
                                          ,p_segment1_val  IN VARCHAR2
													                ,p_err_code OUT VARCHAR2, -- Output error code
                                           p_err_msg  OUT VARCHAR2)    ;
 ----------------------------------------------------------------------------
  --  Purpose :        Item Master Extract Recon Report
  ----------------------------------------------------------------------------
  --  Ver  Date        Name                         Description
  --  1.0 10/11/2016  V.V.SATEESH                   Initial build
  ----------------------------------------------------------------------------                                                                           
 FUNCTION xx_ptm_extract_rule_fun(p_segment IN VARCHAR2,p_org IN VARCHAR2) return VARCHAR2;     
 ----------------------------------------------------------------------------
  --  Purpose :        Item Master Extract Recon Report
  ----------------------------------------------------------------------------
  --  Ver  Date        Name                         Description
  --  1.0 10/11/2016  V.V.SATEESH                   Initial build
  ----------------------------------------------------------------------------
FUNCTION xx_ptm_legacy_attr_value_fn(p_segment IN VARCHAR2,p_org IN VARCHAR2,p_column_name in varchar2)
return VARCHAR2;
----------------------------------------------------------------------------
  --  Purpose :        Item Master Extract Recon Report
  ----------------------------------------------------------------------------
  --  Ver  Date        Name                         Description
  --  1.0 10/11/2016  V.V.SATEESH                   Initial build
  ----------------------------------------------------------------------------
FUNCTION xx_ptm_s3_attr_value_fn(p_segment IN VARCHAR2,p_org IN VARCHAR2,p_column_name in varchar2)
return VARCHAR2 ;
----------------------------------------------------------------------------
  --  Purpose :        Item Master Extract Recon Report
  ----------------------------------------------------------------------------
  --  Ver  Date        Name                         Description
  --  1.0 10/11/2016  V.V.SATEESH                   Initial build
  ----------------------------------------------------------------------------
FUNCTION xx_ptm_get_attr_dq_rule_fn(p_segment IN VARCHAR2,p_org IN VARCHAR2,p_column_name in varchar2)
return VARCHAR2 ;
-- --------------------------------------------------------------------------------------------
  -- Purpose: Report for Recon details
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date     	   Name                          Description
  -- 1.0  11/17/2016   V.V.Sateesh                   Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE xx_ptm_recon_report(p_entity IN VARCHAR2) ;

 END xx_ptm_item_mstr_recon_rpt_pkg;
 /
