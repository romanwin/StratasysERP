CREATE OR REPLACE PACKAGE xxs3_ptm_item_master_extrt_pkg AS
   ----------------------------------------------------------------------------
  --  Name:            xxs3_ptm_item_master_extrt_pkg
  --  Create by:       V.V.SATEESH
  --  Revision:        1.0
  --  Creation date:  30/11/2016
  ----------------------------------------------------------------------------
  --  Purpose :        Package to Explode BOM and Item Revisions
  --                   from Legacy system
  --                   1.Exploding the Assembly Items and it's Components using BOM API.
  --                   2.Insert Item Revisions in the Stage table
  ----------------------------------------------------------------------------
  --  Ver  Date        Name                         Description
  --  1.0 17/08/2016  V.V.SATEESH                   Initial build
  ----------------------------------------------------------------------------

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will explode BOM and insert into stage tables
  --           staging table xxobjt.xxs3_ptm_bom_item_expl_temp , xxs3_ptm_bom_cmpnt_item_stg
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  17/08/2016   V.V.SATEESH            Initial build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE items_bom_explode_prc(x_errbuf  OUT VARCHAR2,
                                  x_retcode OUT NUMBER) ;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will work for the Insert Revisions for Items
  --  insert into staging table xxs3_ptm_item_master_rev_stg
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date         Name                          Description
  -- 1.0  17/08/2016   V.V.SATEESH            Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE items_revision_extract_prc ;

-- --------------------------------------------------------------------------------------------
  -- Purpose: This function will work for the Return ORG/MASTER control Attributes
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date         Name                          Description
  -- 1.0  17/08/2016   V.V.SATEESH            Initial build
  -- --------------------------------------------------------------------------------------------
  FUNCTION get_org_master_cntrl_fn(p_attribue_name IN VARCHAR2)
    RETURN VARCHAR2;
    
 /*PROCEDURE bom_explosion(start_id IN ROWID,
 
                         end_id   IN ROWID);*/  
                         
   -- --------------------------------------------------------------------------------------------
  -- Purpose: This function will work for the Return Cleanse Vlaue of Buyer ID Attributes
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date         Name                          Description
  -- 1.0  17/08/2016   V.V.SATEESH            Initial build
  -- --------------------------------------------------------------------------------------------
 FUNCTION cleanse_buyer_id(p_xx_inventory_item_id IN number, p_organization_code IN VARCHAR2) 
 RETURN VARCHAR2 ;
 
  -- --------------------------------------------------------------------------------------------
  -- Purpose: This function will work for the Return Cleanse Vlaue of Buyer ID Attributes
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date         Name                          Description
  -- 1.0  17/08/2016   V.V.SATEESH            Initial build
  -- --------------------------------------------------------------------------------------------
FUNCTION cleanse_planner_code(p_xx_inventory_item_id IN number,
                              p_organization_code    IN VARCHAR2)
  RETURN VARCHAR2;                         

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Report for Cleanse details
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date         Name                          Description
  -- 1.0  12/07/2016   V.V.Sateesh                   Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE data_cleanse_report(p_entity IN VARCHAR2);
   -- --------------------------------------------------------------------------------------------
  -- Purpose: Report for Transformation details
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date         Name                          Description
  -- 1.0  12/07/2016   V.V.Sateesh                   Initial build
  -----------------------------------------------------------------------------------------------  
   PROCEDURE data_transform_report(p_entity IN VARCHAR2);
   -- --------------------------------------------------------------------------------------------
  -- Purpose: Generate Data Quality Report for Items
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date          Name                          Description
  --  1.0 07/12/2016   V.V.SATEESH                    Initial build
  -----------------------------------------------------------------------------------------------
  PROCEDURE report_data_items(p_entity IN VARCHAR2);
  -- --------------------------------------------------------------------------------------------
  -- Purpose: This function will work for the Return Transform Vlaue of Buyer ID Attributes
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date         Name                          Description
  -- 1.0  17/08/2016   V.V.SATEESH            Initial build
  -- --------------------------------------------------------------------------------------------
FUNCTION transform_buyer(p_inventory_item_id IN NUMBER,p_buyer_id IN NUMBER,p_organization_code IN VARCHAR2) 
RETURN VARCHAR2 ;

   
END xxs3_ptm_item_master_extrt_pkg;
/
