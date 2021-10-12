CREATE OR REPLACE PACKAGE xxs3_ptm_master_item_pkg AUTHID CURRENT_USER AS

----------------------------------------------------------------------------
  --  name:            xxs3_ptm_master_item_pkg
  --  create by:      V.V.SATEESH
  --  Revision:        1.0
  --  creation date:  17/08/2016
  ----------------------------------------------------------------------------
  --  purpose :        Package to extract the Item fields
  --                   from Legacy system
  ----------------------------------------------------------------------------
  --  ver  date        name                         desc
  --  1.0 17/08/2016  V.V.SATEESH                 Initial build
  ----------------------------------------------------------------------------
  
  
  -- --------------------------------------------------------------------------------------------
  -- Purpose: Insert into Master Item DQ table for validation of errors and update the master table
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0 17/08/2016  V.V.SATEESH                    Initial build
  -----------------------------------------------------------------------------------------------
  
   PROCEDURE insert_update_master_item_dq(p_xx_inventory_item_id IN NUMBER
                                       ,p_rule_name        IN VARCHAR2
                                       ,p_reject_code      IN VARCHAR2
                                       ) ;
 
  
  -- --------------------------------------------------------------------------------------------
  -- Purpose: Extract data from staging tables for Cleanse check of Master Items
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0                                         Initial build
  -----------------------------------------------------------------------------------------------
  
  PROCEDURE cleanse_master_items;

 -- --------------------------------------------------------------------------------------------
  -- Purpose: Extract data from staging tables for quality check of Master Items
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date          Name                          Description
  -- 1.0  17/08/2016  V.V.SATEESH                     Initial build
  -----------------------------------------------------------------------------------------------
 
   PROCEDURE quality_check_master_items;
   -- --------------------------------------------------------------------------------------------
  -- Purpose: Extract file generation for Master Items
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date          Name                          Description
  -- 1.0  17/08/2016  V.V.SATEESH                     Initial build
  -----------------------------------------------------------------------------------------------
 
   PROCEDURE utl_file_extract_out(p_s3_org_code IN VARCHAR2) ;
  
 -- --------------------------------------------------------------------------------------------
  -- Purpose: Report for Cleanse details 
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date     	   Name                          Description
  -- 1.0  17/08/2016  V.V.Sateesh                   Initial build
  ----------------------------------------------------------------------------------------------- 

  PROCEDURE data_cleanse_report(p_entity IN VARCHAR2);
 
 -- --------------------------------------------------------------------------------------------
  -- Purpose: Transform Report for the Items
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date          Name                          Description
  -- 1.0 17/08/2016   V.V.SATEESH                     Initial build
  -----------------------------------------------------------------------------------------------
  
  PROCEDURE data_transform_report(p_entity IN VARCHAR2) ;
   
   -- --------------------------------------------------------------------------------------------
  -- Purpose: Generate Data Quality Report for Items
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date          Name                          Description
  --  1.0 17/08/2016   V.V.SATEESH                    Initial build
  -----------------------------------------------------------------------------------------------
  
 
  PROCEDURE report_data_items(p_entity IN VARCHAR2);
  

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure transform the Buyer id from legacy to Employee number of Buyer in S3
  --          staging table XXOBJT.XXS3_PTM_MTL_MASTER_ITEMS
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --1.0   17/08/2016 V.V.SATEESH				   Initial build	
  -- --------------------------------------------------------------------------------------------

  PROCEDURE update_buyer_number(p_xx_inventory_item_id IN NUMBER,p_buyer_id IN NUMBER,p_transformerr IN VARCHAR2) ;
  
  
  
   --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will transform the Atp Rule Name from legacy to S3 Atp Rule Name
  --           staging table XXS3_PTM_MTL_MASTER_ITEMS
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --1.0  17/08/2016   V.V.SATEESH				    Initial build				
  -- --------------------------------------------------------------------------------------------
  PROCEDURE update_atp_rule_name(p_xx_inventory_item_id IN NUMBER,p_atp_rule_name IN VARCHAR2) ;

--------------------------------------------------------------------------------------------------
  -- Purpose: This procedure will update the Planner Code for the Master Items based on conditions
  --           staging table XXS3_PTM_MTL_MASTER_ITEMS
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --1.0  17/08/2016   V.V.SATEESH				    Initial build	
  ----------------------------------------------------------------------------------------------

  PROCEDURE update_planner(p_xx_inventory_item_id IN NUMBER,p_organization_code IN VARCHAR2,p_planner_code IN VARCHAR2) ;

  
  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will update the Buyer Id for the Master org Items
  --           staging table XXS3_PTM_MTL_MASTER_ITEMS
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --1.0  17/08/2016   V.V.SATEESH				    Initial build	
  -- --------------------------------------------------------------------------------------------
  PROCEDURE update_buyer_id(p_xx_inventory_item_id IN NUMBER,p_organization_code IN VARCHAR2);
  
  
  ---------------------------------------------------------------------------------------------
  -- Purpose: This procedure will update Tracking Quantity Ind
  --           staging table XXS3_PTM_MTL_MASTER_ITEMS
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --1.0  17/08/2016   V.V.SATEESH				    Initial build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE update_tracking_quantity_ind(p_inventory_item_id IN NUMBER,p_primary_uom_code IN VARCHAR2,p_transerr IN VARCHAR2);
 
 -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will update UPDATE_SECONDARY_DEFAULT_IND value
  --           staging table XXS3_PTM_MTL_MASTER_ITEMS
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  17/08/2016   V.V.SATEESH				    Initial build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE update_secondary_default_ind(p_inventory_item_id IN NUMBER,p_primary_uom_code IN VARCHAR2,p_transerr IN VARCHAR2) ;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will update UPDATE_ONT_PRICING_QTY_SOURCE value
  --           staging table XXS3_PTM_MTL_MASTER_ITEMS
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  17/08/2016   V.V.SATEESH				    Initial build
  -- --------------------------------------------------------------------------------------------
 
   PROCEDURE update_ont_pricing_qty_source(p_inventory_item_id IN NUMBER,p_s3_tracking_quantity_ind IN VARCHAR2,p_transerr IN VARCHAR2);
  
   -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all org rules for  based on PRODUCT_HIERARCHY
  --           staging table XXS3_PTM_MTL_MASTER_ITEMS
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date         Name                          Description
  -- 1.0  17/08/2016   V.V.SATEESH				    Initial build
  -- --------------------------------------------------------------------------------------------

   PROCEDURE org_rules_items(p_inventory_item_id IN NUMBER,p_organization_code IN VARCHAR2) ;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will update attribute25
  --           staging table XXS3_PTM_MTL_MASTER_ITEMS
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  17/08/2016   V.V.SATEESH				    Initial build
  -- --------------------------------------------------------------------------------------------
  
  PROCEDURE update_attribute25(p_inventory_item_id IN NUMBER,p_attribute25 IN VARCHAR2);
 

 
 -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will work for the BOM Explosion API,Assembly item Components and it's item details will
  --  insert into staging table XXS3_BOM_ITEM_EXPL_TEMP
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date         Name                          Description
  -- 1.0  17/08/2016   V.V.SATEESH				    Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE prc_s3_item_bom_explode/*(p_item_id IN NUMBER,p_org_id IN NUMBER)*/;



 -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required Master and Child Items Attributes and insert into
  --           staging table XXS3_PTM_MTL_MASTER_ITEMS
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  17/08/2016   V.V.SATEESH				    Initial build
  -- --------------------------------------------------------------------------------------------
 
  PROCEDURE master_item_extract_data(x_errbuf  OUT VARCHAR2,
                                     x_retcode OUT NUMBER,
                                     p_organization_code IN VARCHAR2 );
                                     
  
 
END xxs3_ptm_master_item_pkg;
/
