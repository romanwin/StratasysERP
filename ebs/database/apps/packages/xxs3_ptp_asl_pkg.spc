CREATE OR REPLACE PACKAGE xxs3_ptp_asl_pkg AUTHID CURRENT_USER

-- --------------------------------------------------------------------------------------------
-- Purpose: This Package is used for Approved Suppliers List Extract, Quality Check and Report
--           
-- --------------------------------------------------------------------------------------------
-- Ver  Date        Name                          Description
-- 1.0  18/05/2016  TCS                           Initial build  
-- --------------------------------------------------------------------------------------------

 AS

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for Approved Suppliers List Data Quality Check
  --           
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build  
  -- --------------------------------------------------------------------------------------------
  PROCEDURE quality_check_asl(p_err_code OUT VARCHAR2
                             ,p_err_msg  OUT VARCHAR2);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for Approved Suppliers List Data Extract
  --           
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build  
  -- --------------------------------------------------------------------------------------------
  PROCEDURE asl_extract_data(x_errbuf  OUT VARCHAR2
                            ,x_retcode OUT NUMBER);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used to report the error data
  --           
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build  
  -- --------------------------------------------------------------------------------------------                            
  PROCEDURE dq_asl_report_data(p_err_code OUT VARCHAR2
                              ,p_err_msg  OUT VARCHAR2);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used to report the DQ issues and to be rejected data
  --           
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build  
  -- --------------------------------------------------------------------------------------------

  PROCEDURE asl_report_data(p_entity_name IN VARCHAR2);
  PROCEDURE asl_xml_report_data(x_errbuff OUT VARCHAR2
                               ,x_retcode OUT VARCHAR2);
  PROCEDURE data_transform_report(p_entity VARCHAR2);

END xxs3_ptp_asl_pkg;
/
