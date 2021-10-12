CREATE OR REPLACE PACKAGE xxs3_otc_so_pkg AS

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used for Sales Order Header Data Extract
  --           
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build  
  -- --------------------------------------------------------------------------------------------
  PROCEDURE so_header_extract(p_retcode OUT VARCHAR2
                             ,p_errbuf  OUT VARCHAR2);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used for Sales Order Line Data Extract
  --           
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build  
  -- --------------------------------------------------------------------------------------------

  PROCEDURE so_line_extract(p_retcode OUT VARCHAR2
                           ,p_errbuf  OUT VARCHAR2);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used for Sales Order Hold Data Extract
  --           
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build  
  -- --------------------------------------------------------------------------------------------

  PROCEDURE so_hold_extract(p_retcode OUT VARCHAR2
                           ,p_errbuf  OUT VARCHAR2);


  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used for Sales Order Price Adjustment Data Extract
  --           
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build  
  -- --------------------------------------------------------------------------------------------

  PROCEDURE so_price_adjus_extract(p_retcode OUT VARCHAR2
                                  ,p_errbuf  OUT VARCHAR2);



  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used for Sales Order Attachment Data Extract
  --           
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build  
  -- --------------------------------------------------------------------------------------------                                  
  PROCEDURE so_attachment_extract(p_retcode OUT VARCHAR2
                                 ,p_errbuf  OUT VARCHAR2);


  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used for Sales Order Transform Report
  --           
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build  
  -- --------------------------------------------------------------------------------------------                                  

  PROCEDURE so_transform_report(p_entity VARCHAR2);


  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used for Sales Order Header Cleanse Report
  --           
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/10/2016  TCS                           Initial build  
  -- --------------------------------------------------------------------------------------------

  PROCEDURE so_cleanse_report(p_entity VARCHAR2);

END xxs3_otc_so_pkg;
/
