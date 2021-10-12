CREATE OR REPLACE PACKAGE BODY xxs3_ptm_master_item_pkg AS

  ----------------------------------------------------------------------------
  --  Name:            xxs3_ptm_master_item_pkg
  --  Create by:       V.V.SATEESH
  --  Revision:        1.0
  --  Creation date:  17/08/2016
  ----------------------------------------------------------------------------
  --  Purpose :        Package to extract the Item Attributes
  --                   from Legacy system
  --                   1. Extract Items Details for Master and Child Org 
  --                      based on the business rules. 
  --                   2.Exploding the Assembly Items and it's Components using BOM API. 
  --                   3.Applying Data Quaity,Cleanse and Transformation Rules.          
  ----------------------------------------------------------------------------
  --  Ver  Date        Name                         Description
  --  1.0 17/08/2016  V.V.SATEESH                   Initial build
  ----------------------------------------------------------------------------
  report_error EXCEPTION;
  g_delimiter     VARCHAR2(5) := '~';
  
  --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used to write in concurrent log
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  17/08/2016  V.V.Sateesh                Initial build
  -- --------------------------------------------------------------------------------------------
  
  PROCEDURE log_p(p_msg VARCHAR2) IS
  BEGIN
       fnd_file.put_line(fnd_file.log, p_msg);
           
  END log_p;
  --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used to write in concurrent output
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  17/08/2016  V.V.Sateesh                Initial build
  -- --------------------------------------------------------------------------------------------
  
PROCEDURE out_p(p_msg VARCHAR2) IS
  BEGIN
  
    fnd_file.put_line(fnd_file.output, p_msg);
  
  END out_p;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Insert into Master Item DQ table for validation of errors and update the master table
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0 17/08/2016  V.V.SATEESH                    Initial build
  -----------------------------------------------------------------------------------------------
  PROCEDURE insert_update_master_item_dq(p_xx_inventory_item_id IN NUMBER
                                        ,p_rule_name            IN VARCHAR2
                                        ,p_reject_code          IN VARCHAR2) IS
  BEGIN
  
    -- Update stage table with the process flag 'Q'
     
    UPDATE xxobjt.xxs3_ptm_mtl_master_items
    SET    process_flag = 'Q'
    WHERE  xx_inventory_item_id = p_xx_inventory_item_id;
  
    --  Update DQ stage table with the Rule Name and Reject Code
  
    INSERT INTO xxobjt.xxs3_ptm_mtl_master_items_dq
      (xx_dq_inventory_item_id
      ,xx_inventory_item_id
      ,rule_name
      ,notes)
    VALUES
      (xxobjt.xxs3_ptm_master_items_dq_seq.NEXTVAL
      ,p_xx_inventory_item_id
      ,p_rule_name
      ,p_reject_code);
  
    COMMIT;
  
  EXCEPTION           --Exception Handling Block 
    WHEN no_data_found THEN
    
      log_p('Error:No data found in "insert_update_master_item_dq" Procedure' || ' ' || SQLCODE || '-' || SQLERRM);
    
    WHEN OTHERS THEN
    
      log_p('Error in "insert_update_master_item_dq" Procedure' || ' ' ||SQLCODE || '-' || SQLERRM);
    
  END insert_update_master_item_dq;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Update staging tables for Cleanse checks of Master Items
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  17/08/2016  V.V.SATEESH                   Initial build
  -----------------------------------------------------------------------------------------------
  PROCEDURE cleanse_master_items IS
  
    --Variables declaration
    
    l_xx_result NUMBER;
    l_status    BOOLEAN := TRUE;
    
   
   --Cursor for the Cleanse Rules
    CURSOR c_cleanse IS
    
      SELECT l_inventory_item_id
            ,legacy_organization_code
            ,s3_organization_code
      FROM   xxobjt.xxs3_ptm_mtl_master_items
      WHERE  process_flag IN ('N', 'Q', 'Y');
  
  BEGIN
  
    FOR i IN c_cleanse LOOP
    
      l_status := TRUE;
    
      -- RECEIVING_ROUTING_ID tranform value 
    
      l_xx_result := xxs3_dq_util_pkg.eqt_137(i.l_inventory_item_id
                                              , i.legacy_organization_code
                                              , i.s3_organization_code);
    --Update receiving routing id in stage table
    
      UPDATE xxobjt.xxs3_ptm_mtl_master_items
      SET    s3_receiving_routing_id = l_xx_result
            ,cleanse_status          = 'PASS'
      WHERE  l_inventory_item_id = i.l_inventory_item_id;
      
      
       /*-- RELEASE_TIME_FENCE_CODE tranform value 
    
      l_xx_result := xxs3_dq_util_pkg.eqt_151_1(i.l_inventory_item_id
                                              , i.legacy_organization_code
                                              , i.s3_organization_code);
    --Update RELEASE_TIME_FENCE_CODE in stage table
    
      UPDATE xxobjt.xxs3_ptm_mtl_master_items
      SET    RELEASE_TIME_FENCE_CODE = l_xx_result
            ,cleanse_status          = 'PASS'
      WHERE  l_inventory_item_id = i.l_inventory_item_id;*/
      
    END LOOP;
  
    COMMIT;
  
  EXCEPTION  --Exception Block
    WHEN no_data_found THEN
      log_p('Error:No data found "cleanse_master_items" Procedure'|| ' ' || SQLCODE || '-' || SQLERRM);
    
    WHEN others THEN
             
      log_p('Error in "cleanse_master_items" Procedure' || ' ' || SQLCODE || '-' ||SQLERRM);
    
  END cleanse_master_items;

 
  -- --------------------------------------------------------------------------------------------
  -- Purpose: Extract data from staging tables for quality check of Master Items
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date          Name                          Description
  -- 1.0  17/08/2016  V.V.SATEESH                     Initial build
  -----------------------------------------------------------------------------------------------
  PROCEDURE quality_check_master_items IS
     --  Variables declaration
   l_result   VARCHAR2(10);
   l_result1  VARCHAR2(10);
   l_result2  VARCHAR2(10);
   l_result3  VARCHAR2(10);
   l_result4  VARCHAR2(10);
   l_result5  VARCHAR2(10);
   l_result6  VARCHAR2(10);
   l_result7  VARCHAR2(10);
   l_result8  VARCHAR2(10);
   l_result9  VARCHAR2(10);
   l_result10 VARCHAR2(10);
   l_result11 VARCHAR2(10);
   l_result12 VARCHAR2(10);
   l_result13 VARCHAR2(10);
   l_result15 VARCHAR2(10);
   l_result16 VARCHAR2(10);
   l_result17 VARCHAR2(10);
   l_result18 VARCHAR2(10);
   l_result19 VARCHAR2(10);
   l_result20 VARCHAR2(10);
   l_result21 VARCHAR2(10);
   l_result22 VARCHAR2(10);
   l_result23 VARCHAR2(10);
   l_result24 VARCHAR2(10);
   l_result25 VARCHAR2(10);
   l_result26 VARCHAR2(10);
   l_result27 VARCHAR2(10);
   l_result28 VARCHAR2(10);
   l_result29 VARCHAR2(10);
   l_result30 VARCHAR2(10);
   l_result31 VARCHAR2(10);
   l_result32 VARCHAR2(10);
   l_result33 VARCHAR2(10);
   l_result34 VARCHAR2(10);
   l_result35 VARCHAR2(10);
   l_result36 VARCHAR2(10);
   l_result37 VARCHAR2(10);
   l_result38 VARCHAR2(10);
   l_result39 VARCHAR2(10);
   l_result40 VARCHAR2(10);
   l_result41 VARCHAR2(10);
   l_result42 VARCHAR2(10);
   l_result43 VARCHAR2(10);
   l_result44 VARCHAR2(10);
   l_result45 VARCHAR2(10);
   l_result46 VARCHAR2(10);
   l_result47 VARCHAR2(10);
   l_result48 VARCHAR2(10);
   l_result49 VARCHAR2(10);
   l_result50 VARCHAR2(10);
   l_result51 VARCHAR2(10);
   l_result52 VARCHAR2(10);
   l_result53 VARCHAR2(10);
   l_result54 VARCHAR2(10);
   l_result55 VARCHAR2(10);
   l_result56 VARCHAR2(10);
   l_result57 VARCHAR2(10);
   l_result58 VARCHAR2(10);
   l_result59 VARCHAR2(10);
   l_result60 VARCHAR2(10);
   l_result61 VARCHAR2(10);
   l_result62 VARCHAR2(10);
   l_result63 VARCHAR2(10);
   l_result64 VARCHAR2(10);
   l_result65 VARCHAR2(10);
   l_result66 VARCHAR2(10);
   l_status   BOOLEAN := TRUE;
  
  CURSOR c_dqr IS
           SELECT * 
           FROM xxobjt.xxs3_ptm_mtl_master_items
           WHERE process_flag = 'N';
  BEGIN
      --Cursor to get the records from the "xxs3_ptm_mtl_master_items" table with Process flag 'N' 
    FOR i IN c_dqr LOOP
               
		     l_status := TRUE;
			 
  --DQ functions Value storing in to Variables 
  
		l_result := xxs3_dq_util_pkg.eqt_082(i.planning_make_buy_code,
                                           i.purchasing_item_flag);

		l_result1 := xxs3_dq_util_pkg.eqt_083(i.item_type,
                                            i.shippable_item_flag);
 
		l_result2 := xxs3_dq_util_pkg.eqt_084(i.item_type,
                                            i.inventory_item_flag);
   
		l_result66 := xxs3_dq_util_pkg.eqt_085(i.inventory_asset_flag,i.costing_enabled_flag);									
	
		l_result3 := xxs3_dq_util_pkg.eqt_086(i.planning_make_buy_code,
                                            i.purchasing_enabled_flag);
  
		l_result4 := xxs3_dq_util_pkg.eqt_087(i.item_type,i.stock_enabled_flag );
         
		l_result5 := xxs3_dq_util_pkg.eqt_088(i.item_type,i.bom_enabled_flag);
		      
    l_result6  := xxs3_dq_util_pkg.eqt_090(i.collateral_flag);
         	
		l_result7  := xxs3_dq_util_pkg.eqt_091(i.allow_item_desc_update_flag);
    
  	l_result8  := xxs3_dq_util_pkg.eqt_092(i.inspection_required_flag);
              
		l_result9  := xxs3_dq_util_pkg.eqt_093(i.planning_make_buy_code,
                                             i.receipt_required_flag);
                                          
		l_result10 := xxs3_dq_util_pkg.eqt_094(i.qty_rcv_tolerance);
    
		l_result11 := xxs3_dq_util_pkg.eqt_095(i.planning_make_buy_code,
                                               i.list_price_per_unit);
                                               
    l_result12 := xxs3_dq_util_pkg.eqt_096(i.asset_category_id, i.item_type);
 
		l_result13 := xxs3_dq_util_pkg.eqt_097(i.unit_of_issue);
    
	  l_result15 := xxs3_dq_util_pkg.eqt_098(i.item_type,i.serial_number_control_code);
     
    l_result16 := xxs3_dq_util_pkg.eqt_099_1(i.source_subinventory);
    
	  l_result17 := xxs3_dq_util_pkg.eqt_100(i.item_type,i.expense_account);
    
		l_result18 := xxs3_dq_util_pkg.eqt_101(i.shrinkage_rate);
    
		l_result19 := xxs3_dq_util_pkg.eqt_102(i.std_lot_size);
    
	  l_result20 := xxs3_dq_util_pkg.eqt_103(i.item_type,i.end_assembly_pegging_flag);
     
    l_result21 := xxs3_dq_util_pkg.eqt_104(i.planning_make_buy_code,i.bom_item_type);
       
		l_result22 := xxs3_dq_util_pkg.eqt_105(i.pick_components_flag);
    
		l_result23 := xxs3_dq_util_pkg.eqt_106(i.replenish_to_order_flag);
    
		l_result24 := xxs3_dq_util_pkg.eqt_107(i.atp_components_flag);
    
    l_result25:= xxs3_dq_util_pkg.eqt_108(i.cost_of_sales_account);
       
    l_result26:= xxs3_dq_util_pkg.eqt_109(i.sales_account);
     
   	l_result27 := xxs3_dq_util_pkg.eqt_110(i.default_include_in_rollup_flag);
    
    l_result28 := xxs3_dq_util_pkg.eqt_111(i.planning_make_buy_code,     
                                             i.item_type);
 
    l_result29 := xxs3_dq_util_pkg.eqt_112(i.reservable_type, i.item_type);
       
		l_result30 := xxs3_dq_util_pkg.eqt_113(i.vendor_warranty_flag);
    
		l_result31 := xxs3_dq_util_pkg.eqt_114(i.serviceable_product_flag);
    
		l_result32 := xxs3_dq_util_pkg.eqt_115(i.prorate_service_flag);
    
   	l_result33 := xxs3_dq_util_pkg.eqt_116(i.invoiceable_item_flag);
  
		l_result34 := xxs3_dq_util_pkg.eqt_117(i.invoice_enabled_flag);
    
		l_result35 := xxs3_dq_util_pkg.eqt_118(i.costing_enabled_flag,
											   i.item_type);
                                              
		l_result36 := xxs3_dq_util_pkg.eqt_119(i.cycle_count_enabled_flag,
												i.item_type);
 
		l_result37 := xxs3_dq_util_pkg.eqt_120(i.ato_forecast_control,
                                             i.item_type);
 
		l_result38 := xxs3_dq_util_pkg.eqt_121(i.effectivity_control);
    
		l_result39 := xxs3_dq_util_pkg.eqt_122(i.event_flag);
     
		l_result40 := xxs3_dq_util_pkg.eqt_123(i.electronic_flag);
    	     
		l_result41 := xxs3_dq_util_pkg.eqt_124(i.downloadable_flag);
    
		l_result42 := xxs3_dq_util_pkg.eqt_125(i.comms_nl_trackable_flag,
												i.item_type);
		
		l_result43 := xxs3_dq_util_pkg.eqt_126(i.web_status);

		l_result44 := xxs3_dq_util_pkg.eqt_127(i.dimension_uom_code);
    
		l_result45 := xxs3_dq_util_pkg.eqt_128(i.unit_length);
    
    l_result46 := xxs3_dq_util_pkg.eqt_129(i.unit_width);
        
		l_result47 := xxs3_dq_util_pkg.eqt_130(i.unit_height);
         
		l_result48 := xxs3_dq_util_pkg.eqt_131(i.dual_uom_control);
         
		l_result49 := xxs3_dq_util_pkg.eqt_132(i.dual_uom_deviation_high);
    
		l_result50 := xxs3_dq_util_pkg.eqt_133(i.dual_uom_deviation_low);
    	
    l_result51 := xxs3_dq_util_pkg.eqt_134(i.default_so_source_type);
        
		l_result52 := xxs3_dq_util_pkg.eqt_135(i.hazardous_material_flag);
    		
		l_result53 := xxs3_dq_util_pkg.eqt_136(i.recipe_enabled_flag);
    
		l_result65 := xxs3_dq_util_pkg.eqt_138 (i.ato_forecast_control ,i.item_type );
    
		l_result54 := xxs3_dq_util_pkg.eqt_139 (i.cycle_count_enabled_flag ,i.item_type );
         
		l_result55:= xxs3_dq_util_pkg.eqt_140(i.reservable_type,i.item_type);
       	        
		l_result56:= xxs3_dq_util_pkg.eqt_141(i.mrp_planning_code ,i.item_type);
            
		l_result57:= xxs3_dq_util_pkg.eqt_142(i.receipt_required_flag,i.planning_make_buy_code);
            
		l_result58:= xxs3_dq_util_pkg.eqt_143(i.revision_qty_control_code);
        
		l_result59:= xxs3_dq_util_pkg.eqt_144(i.ship_model_complete_flag);
    
		l_result60:= xxs3_dq_util_pkg.eqt_145(i.source_subinventory);
    
		l_result61:= xxs3_dq_util_pkg.eqt_146(i.source_type);
    
    l_result62:= xxs3_dq_util_pkg.eqt_147(i.restrict_subinventories_code);
        
		l_result63:= xxs3_dq_util_pkg.eqt_148(i.contract_item_type_code);
             
		l_result64 := xxs3_dq_util_pkg.eqt_149(i.serv_req_enabled_code);
		
		
      --  Calling Procedure for Insert/Update the Error Message and Code in the DQ table  
      
      IF l_result = 'FALSE' THEN

        insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_082:Invalid Purchasing Flag',
                                     'Purchasing Item Flag should be Y');
         l_status := FALSE;
      END IF;

      IF l_result1 = 'FALSE' THEN
        
        insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_083',
                                     'EQT_083 :Invalid Shipping Flag');
        l_status := FALSE;
      END IF;

      IF l_result2 = 'FALSE' THEN

        insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_084',
                                     'EQT_084 :Invalid Inventory Item Flag');
        l_status := FALSE;

      END IF;
	  
	   IF l_result66 = 'FALSE' THEN

        insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_085',
                                     'EQT_085 :Invalid Inventory Assest Flag');
        l_status := FALSE;

      END IF;

      IF l_result3 = 'FALSE' THEN
       
        insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_086',
                                     'EQT_086 :Invalid Purchasing Enabled Flag');
        l_status := FALSE;

      END IF;


      IF l_result4 = 'FALSE' THEN

        insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_087:Invalid Stock Enabled Flag',
                                     'STOCK_ENABLED_FLAG should be N');
        l_status := FALSE;
      END IF;

	 IF l_result5 = 'FALSE' THEN

        insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_088:Invalid BOM Enabled Flag',
                                     'BOM_ENABLED_FLAG should be N');
        l_status := FALSE;
      END IF;

	 IF l_result6 = 'FALSE' THEN

        insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_090:Invalid Collateral Flag',
                                     'COLLATERAL_FLAG should be N or NULL');
        l_status := FALSE;
      END IF;

	 IF l_result7 = 'FALSE' THEN

        insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_091:Invalid Allow Item Desc Update Flag',
                                     'ALLOW_ITEM_DESC_UPDATE_FLAG should be N');
        l_status := FALSE;
      END IF;

	 IF l_result8 = 'FALSE' THEN

        insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_092:Inspection Required Flag Should be Null',
                                     'INSPECTION_REQUIRED_FLAG should be NULL');
        l_status := FALSE;
      END IF;

	 IF l_result9 = 'FALSE' THEN

        insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_093:Invalid Receipt Required Flag',
                                     'RECEIPT_REQUIRED_FLAG should be NULL');
        l_status := FALSE;
      END IF;
     IF l_result10 = 'FALSE' THEN

        insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_094: QtyRcv Tolerance Should be Null',
                                     'QTY_RCV_TOLERANCE should be NULL');
        l_status := FALSE;
      END IF;
     IF l_result11 = 'FALSE' THEN

        insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_95:Invalid ListPrice Per Unit',
                                     'LIST_PRICE_PER_UNIT should be NULL or ZERO');
        l_status := FALSE;
      END IF;
     IF l_result12 = 'FALSE' THEN

        insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_096:Invalid Asset Category ID',
                                     'ASSET_CATEGORY_ID---MACHINES.INVENTORY');
        l_status := FALSE;
      END IF;
     IF l_result13 = 'FALSE' THEN

        insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_097:Unit of Issue Should be Null',
                                     'UNIT_OF_ISSUE should be NULL');
        l_status := FALSE;
      END IF;

	 IF l_result15 = 'FALSE' THEN

        insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_098:Invalid Serial Control Code',
                                     'Serial_number_Control_Code');
        l_status := FALSE;
      END IF;

	 IF l_result16 = 'FALSE' THEN

        insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_099:Source Subinventory Should be Null',
                                     'SOURCE_SUBINVENTORY should be NULL');
        l_status := FALSE;
      END IF;

	 IF l_result17 = 'FALSE' THEN

        insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_100:Invalid SEGMENT4 in Expense Account',
                                     'EXPENSE_ACCOUNT');
        l_status := FALSE;
      END IF;

	 IF l_result18 = 'FALSE' THEN

        insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_101:Shrinkage Rate Should be Null',
                                     'SHRINKAGE_RATE Should be Null');
        l_status := FALSE;
      END IF;

	IF l_result19 = 'FALSE' THEN

        insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_102:Std Lot Size Should be Null',
                                     'STD_LOT_SIZE Should be NULL');
        l_status := FALSE;
      END IF;

	  IF l_result20 = 'FALSE' THEN

        insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_103:Invalid End Assembly Pegging Flag',
                                     'END_ASSEMBLY_PEGGING_FLAG should Null' );
        l_status := FALSE;
      END IF;

     IF l_result21 = 'FALSE' THEN

        insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_104:Invalid BOM Item Type',
                                     'BOM_ITEM_TYPE should Standard' );
        l_status := FALSE;
      END IF;

	   IF l_result22 = 'FALSE' THEN

        insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_105:Pick Components Flag Should be N',
                                     'PICK_COMPONENTS_FLAG should be N' );
        l_status := FALSE;
      END IF;

	    IF l_result23 = 'FALSE' THEN

        insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_106:Replenish Order Flag Should be N',
                                     'REPLENISH_TO_ORDER_FLAG should be N' );
        l_status := FALSE;
      END IF;

	  IF l_result24 = 'FALSE' THEN

        insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_107:ATP Components Flag Should be N',
                                     'ATP_COMPONENTS_FLAG should be N' );
        l_status := FALSE;
      END IF;

	   IF l_result25 = 'FALSE' THEN

        insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_108:Invalid SEGMENT4 in COGS Account',
                                     'COST_OF_SALES_ACCOUNT' );
        l_status := FALSE;
      END IF;


	   IF l_result26 = 'FALSE' THEN

        insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_109:Invalid SEGMENT4 in Sales  Account',
                                     'SALES_ACCOUNT' );
        l_status := FALSE;
      END IF;

	  IF l_result27 = 'FALSE' THEN

        insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_110:Default Incould in Rollup Flag Should Not Be NULL',
                                     'DEFAULT_INCLUDE_IN_ROLLUP_FLAG should not be NULL' );
        l_status := FALSE;
      END IF;

	  IF l_result28 = 'FALSE' THEN

        insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_111:Invalid Make Buy Code',
                                     'PLANNING_MAKE_BUY_CODE should be 2' );
        l_status := FALSE;
      END IF;

	  IF l_result29 = 'FALSE' THEN

        insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_112:Invalid Reservable Type',
                                     'RESERVABLE_TYPE should be N' );
        l_status := FALSE;
      END IF;
	  
      IF l_result30 = 'FALSE' THEN

        insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_113:Vendor Warranty Flag Should be N',
                                     'VENDOR_WARRANTY_FLAG should be N' );
        l_status := FALSE;
      END IF;


      IF l_result31 = 'FALSE' THEN

        insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_114:Service Product Flag Should be N',
                                     'SERVICEABLE_PRODUCT_FLAG should be N' );
        l_status := FALSE;
      END IF;

	   IF l_result32 = 'FALSE' THEN

        insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_115:Prorate Service Flag Should be N',
                                     'PRORATE_SERVICE_FLAG should be N' );
        l_status := FALSE;
      END IF;

	  IF l_result33 = 'FALSE' THEN

        insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_116:Invoiceable Item Flag Should be N',
                                     'INVOICEABLE_ITEM_FLAG should be N' );
        l_status := FALSE;
      END IF;

	  IF l_result34 = 'FALSE' THEN

        insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_117:Invoice Enabled Flag Should be Y',
                                     'INVOICE_ENABLED_FLAG should be Y' );
        l_status := FALSE;
      END IF;

	  	  IF l_result35 = 'FALSE' THEN

        insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_118:Invalid Costing Enabled Flag',
                                     'COSTING_ENABLED_FLAG should be N' );
        l_status := FALSE;
      END IF;

	   IF l_result36 = 'FALSE' THEN

        insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_119:Invalid Cycle Count Enabled Flag',
                                     'CYCLE_COUNT_ENABLED_FLAG should be N' );
        l_status := FALSE;
      END IF;

	   IF l_result37 = 'FALSE' THEN

        insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_120:Invalid ATO Forecast Control',
                                     'ATO_FORECAST_CONTROL should be Null' );
        l_status := FALSE;
      END IF;

	   IF l_result38 = 'FALSE' THEN

        insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_121:Invalid Effectively Control',
                                     'EFFECTIVITY_CONTROL should be 1' );
        l_status := FALSE;
      END IF;

	    IF l_result39 = 'FALSE' THEN

        insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_122:Event Flag Should be N or NULL',
                                     'EVENT_FLAG should be N or NULL' );
        l_status := FALSE;
      END IF;

	  IF l_result40 = 'FALSE' THEN

        insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_123:Electronic Flag Should be N or NULL',
                                     'ELECTRONIC_FLAG should be N or NULL' );
        l_status := FALSE;
      END IF;


	  IF l_result41 = 'FALSE' THEN

        insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_124:Downloadable Flag Should N or NULL',
                                     'DOWNLOADABLE_FLAG should be N or NULL' );
        l_status := FALSE;
      END IF;

	  IF l_result42 = 'FALSE' THEN

        insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_125:Invalid COMMS NL Trackable Flag',
                                     'COMMS_NL_TRACKABLE_FLAG should be Y' );
        l_status := FALSE;
      END IF;


	  IF l_result43 = 'FALSE' THEN

        insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_126:Web Status Should be Y',
                                     'WEB_STATUS should be Y' );
        l_status := FALSE;
      END IF;

	   IF l_result44 = 'FALSE' THEN

        insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_127:DimensionUoM Should be NULL',
                                     'DIMENSION_UOM_CODE should be NULL' );
        l_status := FALSE;
      END IF;

	  IF l_result45 = 'FALSE' THEN

        insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_128:Unit Length Should be NULL',
                                     'UNIT_LENGTH should be NULL' );
        l_status := FALSE;
      END IF;

	    IF l_result46 = 'FALSE' THEN

        insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_129:Unit Width Should be Null',
                                     'UNIT_WIDTH should be NULL' );
        l_status := FALSE;
      END IF;

	   IF l_result47 = 'FALSE' THEN

        insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_130:Unit Height Should be NULL',
                                     'UNIT_HEIGHT should be NULL' );
        l_status := FALSE;
      END IF;

	   IF l_result48 = 'FALSE' THEN

        insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_131:DUAL UOM CONTORL should be 1',
                                     'DUAL_UOM_CONTROL should be 1' );
        l_status := FALSE;
      END IF;

	   IF l_result49 = 'FALSE' THEN

        insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_132:Dual UOM Dev High Should be Zero',
                                     'DUAL_UOM_DEVIATION_HIGH should be Zero' );
        l_status := FALSE;
      END IF;

	     IF l_result50 = 'FALSE' THEN

        insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_133:Dual UOM Dev Low Should be Zero',
                                     'DUAL_UOM_DEVIATION_LOW should be Zero' );
        l_status := FALSE;
      END IF;

	     IF l_result51 = 'FALSE' THEN

        insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_134:Default SO Source Type Should be Internal',
                                     'DEFAULT_SO_SOURCE_TYPE should be INTERNAL' );
        l_status := FALSE;
      END IF;

	 IF l_result52 = 'FALSE' THEN

        insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_135:Hazardous Material Flag Should be NULL',
                                     'HAZARDOUS_MATERIAL_FLAG  Should be N ' );
        l_status := FALSE;
      END IF;

	 IF l_result53 = 'FALSE' THEN

        insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_136:Recipe Enabled Flag Should be NULL',
                                     'RECIPE_ENABLED_FLAG  Should be N ' );
        l_status := FALSE;
      END IF;

	IF l_result54='FALSE' THEN

        insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_139:Cycle Count Enabled Flag Should be Y',
                                     'CYCLE_COUNT_ENABLED_FLAG should be Y' );
        
	    l_status := FALSE;
     END IF;

     IF l_result55='FALSE' THEN
	 
	 insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_140:RESERVABLE_TYPE should be Y',
                                     'RESERVABLE_TYPE should be Y' );
        l_status := FALSE;
    END IF;

    IF l_result56='FALSE' THEN
		
		 insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_141:MRP_PLANNING_CODE_Not Planned',
                                     'MRP_PLANNING_CODE_Not Planned' );
    
		l_status := FALSE;
  
    END IF;

    IF l_result57='FALSE' THEN
	
          insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_142:RECEIPT_REQUIRED_FLAG should Y when PLAANING_MAKE_BY_CODE=1',
                                     'RECEIPT_REQUIRED_FLAG should Y when PLAANING_MAKE_BY_CODE=1' );
        l_status := FALSE;
	
       END IF;


    IF l_result58='FALSE' THEN
	
	  insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_143:REVISION_QTY_CONTROL_CODE should N',
                                     'REVISION_QTY_CONTROL_CODE should N' );
    
          l_status := FALSE;
     END IF;


	IF l_result59='FALSE' THEN
 
	insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_144:SHIP_MODEL_COMPLETE_FLAG should N',
                                     'SHIP_MODEL_COMPLETE_FLAG should N' );
    
    END IF;

   IF l_result60='FALSE' THEN

   insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_145:SOURCE_SUBINVENTORY should NULL',
                                     'SOURCE_SUBINVENTORY should NULL' );
        l_status := FALSE;
        END IF;


     IF l_result61='FALSE' THEN
	 
	  insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_146:SOURCE_TYPE should NULL',
                                     'SOURCE_TYPE should NULL' );
 
        l_status := FALSE;
    END IF;

     IF l_result62='FALSE' THEN
	 
	  insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_147:RESTRICT_SUBINVENTORIES_CODE should NULL',
                                     'RESTRICT_SUBINVENTORIES_CODE should NULL' );
       l_status := FALSE;

    END IF;

     IF l_result63='FALSE' THEN
	 
	  insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_148:CONTRACT_ITEM_TYPE_CODE should NULL',
                                     'CONTRACT_ITEM_TYPE_CODE should NULL' );
 

    END IF;

     IF l_result64='FALSE' THEN
	   insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_149:SERV_REQ_ENABLED_CODE should NULL',
                                     'SERV_REQ_ENABLED_CODE should NULL' );
        l_status := FALSE;
    END IF;

  IF l_result65='FALSE' THEN
	   insert_update_master_item_dq(i.xx_inventory_item_id,
                                     'EQT_138:ato_forecast_control 2',
                                     'ato_forecast_control  should 2' );
 
        l_status := FALSE;
    END IF;

	IF l_status = TRUE THEN
     -- Update process flag 'Y' 
	 
        UPDATE xxobjt.xxs3_ptm_mtl_master_items
        SET    process_flag = 'Y'
        WHERE  xx_inventory_item_id = i.xx_inventory_item_id;
       
      END IF;
  
    END LOOP;
    COMMIT;
    EXCEPTION --Exception Block
       WHEN no_data_found THEN
	       log_p('No data found'||' '||SQLCODE||'-' ||SQLERRM);
    
        WHEN others THEN
            log_p('Error in the "quality_check_master_items" Procedure'||' '||SQLCODE||'-' ||SQLERRM);
            
  END quality_check_master_items;

   -- --------------------------------------------------------------------------------------------
  -- Purpose: Report for Cleanse details 
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date     	   Name                          Description
  -- 1.0  08/17/2016   V.V.Sateesh                   Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE data_cleanse_report(p_entity IN VARCHAR2)  IS  
  
     --Variables    
    l_count_success NUMBER;
    l_count_fail    NUMBER;
	
	 --Cursor for generate Cleanse Report 
   
    CURSOR c_report_cleanse IS
    
      SELECT xx_inventory_item_id
            ,l_inventory_item_id
            ,segment1
            ,receiving_routing_id
            ,s3_receiving_routing_id
            ,cleanse_status
            ,cleanse_error
      FROM   xxobjt.xxs3_ptm_mtl_master_items
      WHERE  cleanse_status IN ('PASS', 'FAIL');
      
  BEGIN
  
  IF p_entity = 'ITEM' THEN
  
  -- Count of the the Cleanse Success records 
  
 SELECT COUNT(1)
 INTO   l_count_success
 FROM   xxs3_ptm_mtl_master_items
 WHERE  cleanse_status = 'PASS';
 
  --Count of the the Cleanse Failed records 
 
 SELECT COUNT(1)
 INTO   l_count_fail
 FROM   xxs3_ptm_mtl_master_items
 WHERE  cleanse_status = 'FAIL';
 
 
      out_p('Report name = Automated Cleanse & Standardize Report');
      out_p('====================================================');
      out_p('Data Migration Object Name = ' || 'ITEM MASTER');
      out_p('Run date and time: ' ||TO_CHAR(SYSDATE, 'dd-Mon-YYYY HH24:MI'));
      out_p('Total Record Count Success = ' || l_count_success);
      out_p('Total Record Count Failure = ' || l_count_fail);
      out_p('');
      
         
      out_p(rpad('Track Name', 10, ' ') || g_delimiter ||
                       rpad('Entity Name', 11, ' ') || g_delimiter ||
                       rpad('XX Inventory Item Id  ', 20, ' ') || g_delimiter ||
                       rpad('Inventory Item Id', 20, ' ') || g_delimiter ||
                       rpad('Item Number', 30, ' ') || g_delimiter ||
                       rpad('Receiving_routing_id', 30, ' ') || g_delimiter ||
                       rpad('S3_receiving_routing_id', 30, ' ') || g_delimiter ||
					             rpad('S3_receiving_routing_id', 30, ' ') || g_delimiter ||
                       rpad('Status', 10, ' ') || g_delimiter ||
                       rpad('Error Message', 200, ' ') );


    FOR r_data IN c_report_cleanse LOOP
      out_p(rpad('PTM', 10, ' ') || g_delimiter ||
                         rpad('ITEMS', 11, ' ') || g_delimiter ||
                         rpad(r_data.xx_inventory_item_id, 20, ' ') || g_delimiter ||
                         rpad(r_data.l_inventory_item_id, 20, ' ') || g_delimiter ||
                         rpad(r_data.segment1, 30, ' ') || g_delimiter ||
                         rpad(NVL(TO_CHAR(r_data.receiving_routing_id),'NULL'), 30, ' ') || g_delimiter ||
                         rpad(r_data.s3_receiving_routing_id, 30, ' ') || g_delimiter ||
                         rpad(r_data.cleanse_status, 10, ' ') || g_delimiter ||
                         rpad(r_data.cleanse_error, 200, ' ') );

    END LOOP;

    out_p('');
    out_p('Stratasys Confidential'|| g_delimiter);
    END IF;
    
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
	  log_p('No data found'||' '||SQLCODE||'-' ||SQLERRM);
    				
  END data_cleanse_report;
 -- --------------------------------------------------------------------------------------------
  -- Purpose: Generate Item Extract File into Server
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date          Name                          Description
  -- 1.0 17/08/2016   V.V.SATEESH                     Initial build
  -----------------------------------------------------------------------------------------------
  PROCEDURE utl_file_extract_out(p_s3_org_code IN VARCHAR2) IS
  
-- Variables 

 l_file_handle          UTL_FILE.file_type;
 l_file_path            VARCHAR2(100);
 l_file_name            VARCHAR2(100); 

 l_extract VARCHAR2(10):= 'E';
 l_revision VARCHAR2(10):= 'R';
 
 
 --Cursor for the records to be export in the file 
 
 CURSOR c_ext IS
 
 SELECT  l_inventory_item_id inventory_item_id
               ,REPLACE(REPLACE(description, chr(13), ''), chr(10), '') description
               ,s3_buyer_number buyer_number
               ,s3_accounting_rule_name accounting_rule_name --value of ACCOUNTING_RULE_ID                           
               ,segment1
               ,attribute2
               ,attribute9
               ,attribute11
               ,attribute12
               ,attribute13
               ,purchasing_item_flag
               ,shippable_item_flag
               ,customer_order_flag
               ,internal_order_flag
               ,service_item_flag
               ,inventory_item_flag
               ,inventory_asset_flag
               ,purchasing_enabled_flag
               ,customer_order_enabled_flag
               ,internal_order_enabled_flag
               ,so_transactions_flag
               ,mtl_transactions_enabled_flag
               ,stock_enabled_flag
               ,bom_enabled_flag
               ,build_in_wip_flag
               ,s3_item_catalog_group_id item_catalog_group_id
               ,catalog_status_flag
               ,returnable_flag
               ,s3_organization_code organization_code
               ,collateral_flag
               ,taxable_flag
               ,allow_item_desc_update_flag
               ,inspection_required_flag
               ,receipt_required_flag
               ,qty_rcv_tolerance
               ,list_price_per_unit
               ,asset_category_id
               ,unit_of_issue
               ,allow_substitute_receipts_flag
               ,allow_unordered_receipts_flag
               ,allow_express_delivery_flag
               ,days_early_receipt_allowed
               ,days_late_receipt_allowed
               ,receipt_days_exception_code
               ,receiving_routing_id
               ,auto_lot_alpha_prefix
               ,start_auto_lot_number
               ,lot_control_code
               ,shelf_life_code
               ,shelf_life_days
               ,serial_number_control_code
               ,source_type
               ,source_subinventory
               ,expense_account
               ,s3_expense_acct_segment1
               ,s3_expense_acct_segment2
               ,s3_expense_acct_segment3
               ,s3_expense_acct_segment4
               ,s3_expense_acct_segment5
               ,s3_expense_acct_segment6
               ,s3_expense_acct_segment7
               ,s3_expense_acct_segment8
               ,restrict_subinventories_code
               ,unit_weight
               ,weight_uom_code
               ,volume_uom_code
               ,unit_volume
               ,shrinkage_rate
               ,acceptable_early_days
               ,planning_time_fence_code
               ,lead_time_lot_size
               ,std_lot_size
               ,overrun_percentage
               ,mrp_calculate_atp_flag
               ,acceptable_rate_increase
               ,acceptable_rate_decrease
               ,planning_time_fence_days
               ,end_assembly_pegging_flag
               ,bom_item_type
               ,pick_components_flag
               ,replenish_to_order_flag
               ,atp_components_flag
               ,atp_flag
               ,wip_supply_type
               ,wip_supply_subinventory
               ,primary_uom_code
               ,s3_secondary_uom_code secondary_uom_code
               ,primary_unit_of_measure
               ,allowed_units_lookup_code
               ,cost_of_sales_account
               ,s3_cost_sales_acct_segment1
               ,s3_cost_sales_acct_segment2
               ,s3_cost_sales_acct_segment3
               ,s3_cost_sales_acct_segment4
               ,s3_cost_sales_acct_segment5
               ,s3_cost_sales_acct_segment6
               ,s3_cost_sales_acct_segment7
               ,s3_cost_sales_acct_segment8
               ,sales_account
               ,s3_sales_acct_segment1
               ,s3_sales_acct_segment2
               ,s3_sales_acct_segment3
               ,s3_sales_acct_segment4
               ,s3_sales_acct_segment5
               ,s3_sales_acct_segment6
               ,s3_sales_acct_segment7
               ,s3_sales_acct_segment8
               ,default_include_in_rollup_flag
               ,s3_inventory_item_status_code inventory_item_status_code
               ,inventory_planning_code
               ,s3_planner_code planner_code
               ,planning_make_buy_code
               ,fixed_lot_multiplier
               ,rounding_control_type
               ,postprocessing_lead_time
               ,preprocessing_lead_time
               ,full_lead_time
               ,mrp_safety_stock_percent
               ,mrp_safety_stock_code
               ,min_minmax_quantity
               ,max_minmax_quantity
               ,minimum_order_quantity
               ,fixed_order_quantity
               ,fixed_days_supply
               ,maximum_order_quantity
               ,s3_atp_rule_name atp_rule_name -- Value of ATP_RULE_ID                   
               ,reservable_type
               ,vendor_warranty_flag
               ,serviceable_product_flag
               ,material_billable_flag
               ,prorate_service_flag
               ,invoiceable_item_flag
               ,invoice_enabled_flag
               ,outside_operation_flag
               ,outside_operation_uom_type
               ,safety_stock_bucket_days
               ,costing_enabled_flag
               ,cycle_count_enabled_flag
               ,s3_item_type item_type
               ,ship_model_complete_flag
               ,mrp_planning_code
               ,ato_forecast_control
               ,release_time_fence_code
               ,release_time_fence_days
               ,container_item_flag
               ,vehicle_item_flag
               ,effectivity_control
               ,event_flag
               ,electronic_flag
               ,downloadable_flag
               ,comms_nl_trackable_flag
               ,orderable_on_web_flag
               ,web_status
               ,dimension_uom_code
               ,unit_length
               ,unit_width
               ,unit_height
               ,dual_uom_control
               ,dual_uom_deviation_high
               ,dual_uom_deviation_low
               ,contract_item_type_code
               ,serv_req_enabled_code
               ,serv_billing_enabled_flag
               ,default_so_source_type
               ,object_version_number
               ,tracking_quantity_ind
               ,secondary_default_ind
               ,ont_pricing_qty_source
               ,so_authorization_flag
               ,attribute17
               ,attribute18
               ,attribute19
               ,s3_attribute25 attribute25
               ,expiration_action_code
               ,s3_expiration_action_interval expiration_action_interval
               ,hazardous_material_flag
               ,recipe_enabled_flag
               ,retest_interval
               ,repair_leadtime
               ,gdsn_outbound_enabled_flag
               ,revision_qty_control_code
               ,start_auto_serial_number
               ,auto_serial_alpha_prefix
               ,NULL AS trasaction_type
               ,NULL AS process_flag
               ,NULL set_process_id
FROM   xxobjt.xxs3_ptm_mtl_master_items msi
WHERE ROWID=(SELECT MIN(ROWID) 
            FROM xxobjt.xxs3_ptm_mtl_master_items
            WHERE l_inventory_item_id=msi.l_inventory_item_id);


 --Cursor for the revision records into file 

CURSOR c_revision IS 
SELECT legacy_revision_id
      ,revision
      ,to_char(implementation_date, 'MM/DD/YYYY HH24:MI:SS') implementation_date
      ,to_char(effectivity_date, 'MM/DD/YYYY HH24:MI:SS') effectivity_date
      ,segment1 item_number
      ,s3_organization_code organization_code
      ,NULL AS process_flag
      ,NULL AS transaction_type
      ,NULL AS set_process_id
      ,revision_attribute10 attribute10
FROM   xxobjt.xxs3_ptm_mtl_master_items  msi
ORDER  BY segment1
         ,revision;

BEGIN

 --Begin for the Extract Records for the Items with out Revisions 
 
 IF l_extract = 'E' THEN
 
  BEGIN
  -- Get the file path from the lookup 
  
 /* SELECT TRIM(' ' FROM meaning)
  INTO   l_file_path
  FROM   fnd_lookup_values_vl
  WHERE  lookup_type = 'XXS3_ITEM_OUT_FILE_PATH';*/
  
    SELECT substr(meaning, 1, instr(meaning, '-') - 1)
    INTO   l_file_path
    FROM   fnd_lookup_values_vl
    WHERE  lookup_type = 'XXS3_COMMON_EXTRACT_LKP'
    AND    enabled_flag = 'Y'
    AND    description = 'outpath'
    AND    substr(lookup_code, instr(lookup_code, '-') + 1) = 'ITEM';
  
   -- Get the file name  
   l_file_name   := 'Items_Extract' || '_' || p_s3_org_code || '_' || SYSDATE || '.xls';
   
     -- Get the utl file open
   l_file_handle := UTL_FILE.fopen (l_file_path, l_file_name, 'W', 32767);  --Utl file open 
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
	     log_p('No data found'||' '||SQLCODE||'-' ||SQLERRM);

       WHEN OTHERS THEN
       log_p('Invalid File Path'||' '||SQLCODE||'-'||SQLERRM);
   
   END;
     --This will create the heading in file 
  

utl_file.put(l_file_handle,'~'||'l_inventory_item_id');
utl_file.put(l_file_handle,'~'||'description');
utl_file.put(l_file_handle,'~'||'s3_buyer_number');
utl_file.put(l_file_handle,'~'||'s3_accounting_rule_name');                                 
utl_file.put(l_file_handle,'~'||'segment1');
utl_file.put(l_file_handle,'~'||'attribute2');
utl_file.put(l_file_handle,'~'||'attribute9');
utl_file.put(l_file_handle,'~'||'attribute11');
utl_file.put(l_file_handle,'~'||'attribute12');
utl_file.put(l_file_handle,'~'||'attribute13');
utl_file.put(l_file_handle,'~'||'purchasing_item_flag');
utl_file.put(l_file_handle,'~'||'shippable_item_flag');
utl_file.put(l_file_handle,'~'||'customer_order_flag');
utl_file.put(l_file_handle,'~'||'internal_order_flag');
utl_file.put(l_file_handle,'~'||'service_item_flag');
utl_file.put(l_file_handle,'~'||'inventory_item_flag');
utl_file.put(l_file_handle,'~'||'inventory_asset_flag');
utl_file.put(l_file_handle,'~'||'purchasing_enabled_flag');
utl_file.put(l_file_handle,'~'||'customer_order_enabled_flag');
utl_file.put(l_file_handle,'~'||'internal_order_enabled_flag');
utl_file.put(l_file_handle,'~'||'so_transactions_flag');
utl_file.put(l_file_handle,'~'||'mtl_transactions_enabled_flag');
utl_file.put(l_file_handle,'~'||'stock_enabled_flag');
utl_file.put(l_file_handle,'~'||'bom_enabled_flag');
utl_file.put(l_file_handle,'~'||'build_in_wip_flag');
utl_file.put(l_file_handle,'~'||'s3_item_catalog_group_id');
utl_file.put(l_file_handle,'~'||'catalog_status_flag');
utl_file.put(l_file_handle,'~'||'returnable_flag');               
utl_file.put(l_file_handle,'~'||'s3_organization_code');       
utl_file.put(l_file_handle,'~'||'collateral_flag');
utl_file.put(l_file_handle,'~'||'taxable_flag');
utl_file.put(l_file_handle,'~'||'allow_item_desc_update_flag');
utl_file.put(l_file_handle,'~'||'inspection_required_flag');
utl_file.put(l_file_handle,'~'||'receipt_required_flag');
utl_file.put(l_file_handle,'~'||'qty_rcv_tolerance');
utl_file.put(l_file_handle,'~'||'list_price_per_unit');
utl_file.put(l_file_handle,'~'||'asset_category_id');
utl_file.put(l_file_handle,'~'||'unit_of_issue');
utl_file.put(l_file_handle,'~'||'allow_substitute_receipts_flag');	
utl_file.put(l_file_handle,'~'||'allow_unordered_receipts_flag');
utl_file.put(l_file_handle,'~'||'allow_express_delivery_flag');
utl_file.put(l_file_handle,'~'||'days_early_receipt_allowed');   
utl_file.put(l_file_handle,'~'||'days_late_receipt_allowed');
utl_file.put(l_file_handle,'~'||'receipt_days_exception_code');
utl_file.put(l_file_handle,'~'||'s3_receiving_routing_id');
utl_file.put(l_file_handle,'~'||'auto_lot_alpha_prefix');
utl_file.put(l_file_handle,'~'||'start_auto_lot_number');
utl_file.put(l_file_handle,'~'||'lot_control_code');
utl_file.put(l_file_handle,'~'||'shelf_life_code');
utl_file.put(l_file_handle,'~'||'shelf_life_days');
utl_file.put(l_file_handle,'~'||'serial_number_control_code');	
utl_file.put(l_file_handle,'~'||'source_type');
utl_file.put(l_file_handle,'~'||'source_subinventory');
utl_file.put(l_file_handle,'~'||'expense_account');
utl_file.put(l_file_handle,'~'||'s3_expense_acct_segment1');
utl_file.put(l_file_handle,'~'||'s3_expense_acct_segment2');
utl_file.put(l_file_handle,'~'||'s3_expense_acct_segment3');
utl_file.put(l_file_handle,'~'||'s3_expense_acct_segment4');
utl_file.put(l_file_handle,'~'||'s3_expense_acct_segment5');
utl_file.put(l_file_handle,'~'||'s3_expense_acct_segment6');
utl_file.put(l_file_handle,'~'||'s3_expense_acct_segment7');
utl_file.put(l_file_handle,'~'||'s3_expense_acct_segment8' );
utl_file.put(l_file_handle,'~'||'restrict_subinventories_code');
utl_file.put(l_file_handle,'~'||'unit_weight');
utl_file.put(l_file_handle,'~'||'weight_uom_code');
utl_file.put(l_file_handle,'~'||'volume_uom_code');
utl_file.put(l_file_handle,'~'||'unit_volume');
utl_file.put(l_file_handle,'~'||'shrinkage_rate');
utl_file.put(l_file_handle,'~'||'acceptable_early_days');
utl_file.put(l_file_handle,'~'||'planning_time_fence_code');
utl_file.put(l_file_handle,'~'||'lead_time_lot_size');
utl_file.put(l_file_handle,'~'||'std_lot_size');
utl_file.put(l_file_handle,'~'||'overrun_percentage');
utl_file.put(l_file_handle,'~'||'mrp_calculate_atp_flag');
utl_file.put(l_file_handle,'~'||'acceptable_rate_increase');
utl_file.put(l_file_handle,'~'||'acceptable_rate_decrease');
utl_file.put(l_file_handle,'~'||'planning_time_fence_days');
utl_file.put(l_file_handle,'~'||'end_assembly_pegging_flag');
utl_file.put(l_file_handle,'~'||'bom_item_type');
utl_file.put(l_file_handle,'~'||'pick_components_flag');
utl_file.put(l_file_handle,'~'||'replenish_to_order_flag');
utl_file.put(l_file_handle,'~'||'atp_components_flag');
utl_file.put(l_file_handle,'~'||'atp_flag');
utl_file.put(l_file_handle,'~'||'wip_supply_type');
utl_file.put(l_file_handle,'~'||'s3_wip_supply_subinventory');	
utl_file.put(l_file_handle,'~'||'primary_uom_code');		 	
utl_file.put(l_file_handle,'~'||'s3_secondary_uom_code');	
utl_file.put(l_file_handle,'~'||'primary_unit_of_measure');	
utl_file.put(l_file_handle,'~'||'allowed_units_lookup_code');
utl_file.put(l_file_handle,'~'||'cost_of_sales_account');
utl_file.put(l_file_handle,'~'||'s3_cost_sales_acct_segment1');
utl_file.put(l_file_handle,'~'||'s3_cost_sales_acct_segment2');
utl_file.put(l_file_handle,'~'||'s3_cost_sales_acct_segment3');
utl_file.put(l_file_handle,'~'||'s3_cost_sales_acct_segment4');
utl_file.put(l_file_handle,'~'||'s3_cost_sales_acct_segment5');
utl_file.put(l_file_handle,'~'||'s3_cost_sales_acct_segment6');
utl_file.put(l_file_handle,'~'||'s3_cost_sales_acct_segment7');
utl_file.put(l_file_handle,'~'||'s3_cost_sales_acct_segment8');
utl_file.put(l_file_handle,'~'||'sales_account');
utl_file.put(l_file_handle,'~'||'s3_sales_acct_segment1');
utl_file.put(l_file_handle,'~'||'s3_sales_acct_segment2');
utl_file.put(l_file_handle,'~'||'s3_sales_acct_segment3');
utl_file.put(l_file_handle,'~'||'s3_sales_acct_segment4');
utl_file.put(l_file_handle,'~'||'s3_sales_acct_segment5');
utl_file.put(l_file_handle,'~'||'s3_sales_acct_segment6');
utl_file.put(l_file_handle,'~'||'s3_sales_acct_segment7');
utl_file.put(l_file_handle,'~'||'s3_sales_acct_segment8');
utl_file.put(l_file_handle,'~'||'default_include_in_rollup_flag');
utl_file.put(l_file_handle,'~'||'s3_inventory_item_status_code');
utl_file.put(l_file_handle,'~'||'inventory_planning_code');
utl_file.put(l_file_handle,'~'||'s3_planner_code');			
utl_file.put(l_file_handle,'~'||'planning_make_buy_code');
utl_file.put(l_file_handle,'~'||'fixed_lot_multiplier');
utl_file.put(l_file_handle,'~'||'rounding_control_type');
utl_file.put(l_file_handle,'~'||'postprocessing_lead_time');
utl_file.put(l_file_handle,'~'||'preprocessing_lead_time');
utl_file.put(l_file_handle,'~'||'full_lead_time');
utl_file.put(l_file_handle,'~'||'mrp_safety_stock_percent');
utl_file.put(l_file_handle,'~'||'mrp_safety_stock_code');
utl_file.put(l_file_handle,'~'||'min_minmax_quantity');
utl_file.put(l_file_handle,'~'||'max_minmax_quantity');
utl_file.put(l_file_handle,'~'||'minimum_order_quantity');
utl_file.put(l_file_handle,'~'||'fixed_order_quantity');
utl_file.put(l_file_handle,'~'||'fixed_days_supply');
utl_file.put(l_file_handle,'~'||'maximum_order_quantity');				
utl_file.put(l_file_handle,'~'||'s3_atp_rule_name');
utl_file.put(l_file_handle,'~'||'reservable_type');
utl_file.put(l_file_handle,'~'||'vendor_warranty_flag');
utl_file.put(l_file_handle,'~'||'serviceable_product_flag');
utl_file.put(l_file_handle,'~'||'material_billable_flag');
utl_file.put(l_file_handle,'~'||'prorate_service_flag');
utl_file.put(l_file_handle,'~'||'invoiceable_item_flag');
utl_file.put(l_file_handle,'~'||'invoice_enabled_flag');
utl_file.put(l_file_handle,'~'||'outside_operation_flag');
utl_file.put(l_file_handle,'~'||'outside_operation_uom_type');	
utl_file.put(l_file_handle,'~'||'safety_stock_bucket_days');
utl_file.put(l_file_handle,'~'||'costing_enabled_flag');
utl_file.put(l_file_handle,'~'||'cycle_count_enabled_flag');				
utl_file.put(l_file_handle,'~'||'s3_item_type');
utl_file.put(l_file_handle,'~'||'ship_model_complete_flag');
utl_file.put(l_file_handle,'~'||'mrp_planning_code');
utl_file.put(l_file_handle,'~'||'ato_forecast_control');
utl_file.put(l_file_handle,'~'||'release_time_fence_code');
utl_file.put(l_file_handle,'~'||'release_time_fence_days');
utl_file.put(l_file_handle,'~'||'container_item_flag');
utl_file.put(l_file_handle,'~'||'vehicle_item_flag');
utl_file.put(l_file_handle,'~'||'effectivity_control');
utl_file.put(l_file_handle,'~'||'event_flag');
utl_file.put(l_file_handle,'~'||'electronic_flag');
utl_file.put(l_file_handle,'~'||'downloadable_flag');
utl_file.put(l_file_handle,'~'||'comms_nl_trackable_flag');
utl_file.put(l_file_handle,'~'||'orderable_on_web_flag');
utl_file.put(l_file_handle,'~'||'web_status');
utl_file.put(l_file_handle,'~'||'dimension_uom_code');
utl_file.put(l_file_handle,'~'||'unit_length');
utl_file.put(l_file_handle,'~'||'unit_width');
utl_file.put(l_file_handle,'~'||'unit_height');
utl_file.put(l_file_handle,'~'||'dual_uom_control');
utl_file.put(l_file_handle,'~'||'dual_uom_deviation_high');
utl_file.put(l_file_handle,'~'||'dual_uom_deviation_low');
utl_file.put(l_file_handle,'~'||'contract_item_type_code');
utl_file.put(l_file_handle,'~'||'serv_req_enabled_code');
utl_file.put(l_file_handle,'~'||'serv_billing_enabled_flag');
utl_file.put(l_file_handle,'~'||'default_so_source_type');
utl_file.put(l_file_handle,'~'||'object_version_number');
utl_file.put(l_file_handle,'~'||'s3_tracking_quantity_ind');	
utl_file.put(l_file_handle,'~'||'s3_secondary_default_ind');
utl_file.put(l_file_handle,'~'||'s3_ont_pricing_qty_source');
utl_file.put(l_file_handle,'~'||'so_authorization_flag');
utl_file.put(l_file_handle,'~'||'attribute17');
utl_file.put(l_file_handle,'~'||'attribute18');
utl_file.put(l_file_handle,'~'||'attribute19');				
utl_file.put(l_file_handle,'~'||'s3_attribute25');
utl_file.put(l_file_handle,'~'||'expiration_action_code'); 
utl_file.put(l_file_handle,'~'||'s3_expiration_action_interval');
utl_file.put(l_file_handle,'~'||'hazardous_material_flag');
utl_file.put(l_file_handle,'~'||'recipe_enabled_flag');
utl_file.put(l_file_handle,'~'||'retest_interval');
utl_file.put(l_file_handle,'~'||'repair_leadtime');
utl_file.put(l_file_handle,'~'||'gdsn_outbound_enabled_flag');
utl_file.put(l_file_handle,'~'||'revision_qty_control_code');
utl_file.put(l_file_handle,'~'||'start_auto_serial_number');
utl_file.put(l_file_handle,'~'||'auto_serial_alpha_prefix');
utl_file.put(l_file_handle,'~'||'Transaction_Type');
utl_file.put(l_file_handle,'~'||'Process Flag');
utl_file.put(l_file_handle,'~'||'Set Process ID');

utl_file.new_line(l_file_handle);

    FOR l_varc1 IN c_ext LOOP
     /*  This will print the records in file as per the query in cursor */
  
utl_file.put(l_file_handle,'~'||to_char(l_varc1.inventory_item_id));	  
utl_file.put(l_file_handle,'~'||NVL(TO_CHAR(l_varc1.description),null));
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.buyer_number));     			
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.accounting_rule_name)); 			                                 
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.segment1));						
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.attribute2));						
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.attribute9));						
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.attribute11));					
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.attribute12));					
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.attribute13));					
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.purchasing_item_flag));			
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.shippable_item_flag));			
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.customer_order_flag));			
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.internal_order_flag));			
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.service_item_flag));				
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.inventory_item_flag));			
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.inventory_asset_flag));			
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.purchasing_enabled_flag));	
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.customer_order_enabled_flag));	
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.internal_order_enabled_flag));	
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.so_transactions_flag));			
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.mtl_transactions_enabled_flag));	
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.stock_enabled_flag));				
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.bom_enabled_flag));				
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.build_in_wip_flag));			
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.item_catalog_group_id));		
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.catalog_status_flag));			
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.returnable_flag));				                 
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.organization_code));			             
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.collateral_flag));				
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.taxable_flag));					
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.allow_item_desc_update_flag));	
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.inspection_required_flag));		
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.receipt_required_flag));			
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.qty_rcv_tolerance));				
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.list_price_per_unit));				
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.asset_category_id));					
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.unit_of_issue));						
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.allow_substitute_receipts_flag));		
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.allow_unordered_receipts_flag));		
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.allow_express_delivery_flag));		
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.days_early_receipt_allowed));         
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.days_late_receipt_allowed));			
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.receipt_days_exception_code));		
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.receiving_routing_id));			
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.auto_lot_alpha_prefix));				
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.start_auto_lot_number));				
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.lot_control_code));					
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.shelf_life_code));					
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.shelf_life_days));					
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.serial_number_control_code));     	
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.source_type));						
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.source_subinventory));			
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.expense_account));		
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.s3_expense_acct_segment1)); 
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.s3_expense_acct_segment2)); 
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.s3_expense_acct_segment3)); 
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.s3_expense_acct_segment4)); 
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.s3_expense_acct_segment5)); 
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.s3_expense_acct_segment6)); 
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.s3_expense_acct_segment7)); 
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.s3_expense_acct_segment8)); 
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.restrict_subinventories_code));    
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.unit_weight));					
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.weight_uom_code));				
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.volume_uom_code));				
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.unit_volume));					
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.shrinkage_rate));					
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.acceptable_early_days));			
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.planning_time_fence_code));		
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.lead_time_lot_size));				
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.std_lot_size));					
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.overrun_percentage));				
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.mrp_calculate_atp_flag));		
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.acceptable_rate_increase));		
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.acceptable_rate_decrease));		
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.planning_time_fence_days));		
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.end_assembly_pegging_flag));		
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.bom_item_type));					
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.pick_components_flag));			
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.replenish_to_order_flag)); 		
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.atp_components_flag));			
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.atp_flag));						
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.wip_supply_type));					
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.wip_supply_subinventory));			
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.primary_uom_code));							 	
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.secondary_uom_code));			 	
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.primary_unit_of_measure));				
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.allowed_units_lookup_code));		
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.cost_of_sales_account));	
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.s3_cost_sales_acct_segment1)); 
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.s3_cost_sales_acct_segment2)); 
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.s3_cost_sales_acct_segment3)); 
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.s3_cost_sales_acct_segment4)); 
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.s3_cost_sales_acct_segment5)); 
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.s3_cost_sales_acct_segment6));
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.s3_cost_sales_acct_segment7));
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.s3_cost_sales_acct_segment8)); 
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.sales_account));		
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.s3_sales_acct_segment1));
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.s3_sales_acct_segment2));
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.s3_sales_acct_segment3));
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.s3_sales_acct_segment4));
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.s3_sales_acct_segment5));
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.s3_sales_acct_segment6));
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.s3_sales_acct_segment7));
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.s3_sales_acct_segment8));
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.default_include_in_rollup_flag));	
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.inventory_item_status_code));	
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.inventory_planning_code));		
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.planner_code));								
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.planning_make_buy_code));			
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.fixed_lot_multiplier));			
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.rounding_control_type));			
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.postprocessing_lead_time));		
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.preprocessing_lead_time));		
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.full_lead_time));					
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.mrp_safety_stock_percent));		
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.mrp_safety_stock_code));			
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.min_minmax_quantity));			
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.max_minmax_quantity));		
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.minimum_order_quantity));			
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.fixed_order_quantity));			
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.fixed_days_supply));			
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.maximum_order_quantity));							
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.atp_rule_name));					
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.reservable_type));			
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.vendor_warranty_flag));			
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.serviceable_product_flag));		
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.material_billable_flag));			
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.prorate_service_flag));			
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.invoiceable_item_flag));			
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.invoice_enabled_flag));			
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.outside_operation_flag));			
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.outside_operation_uom_type));			
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.safety_stock_bucket_days));		
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.costing_enabled_flag));			
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.cycle_count_enabled_flag));							
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.item_type));					
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.ship_model_complete_flag));		
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.mrp_planning_code));				
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.ato_forecast_control));			
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.release_time_fence_code));		
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.release_time_fence_days));		
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.container_item_flag));			
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.vehicle_item_flag));				
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.effectivity_control));			
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.event_flag));						
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.electronic_flag));				
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.downloadable_flag));				
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.comms_nl_trackable_flag));		
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.orderable_on_web_flag));			
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.web_status));						
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.dimension_uom_code));				
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.unit_length));					
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.unit_width));						
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.unit_height));				
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.dual_uom_control));				
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.dual_uom_deviation_high));		
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.dual_uom_deviation_low));			
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.contract_item_type_code));		
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.serv_req_enabled_code));			
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.serv_billing_enabled_flag));		
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.default_so_source_type));			
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.object_version_number));				
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.tracking_quantity_ind));				
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.secondary_default_ind));
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.ont_pricing_qty_source));	
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.so_authorization_flag));			
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.attribute17));						
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.attribute18));					
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.attribute19));									
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.attribute25));					
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.expiration_action_code));			 
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.expiration_action_interval));	
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.hazardous_material_flag));		
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.recipe_enabled_flag));			
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.retest_interval));				
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.repair_leadtime));				
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.gdsn_outbound_enabled_flag));		
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.revision_qty_control_code));		
utl_file.put(l_file_handle,'~'||TO_CHAR(l_varc1.start_auto_serial_number));

utl_file.new_line(l_file_handle);

END LOOP;

utl_file.fclose(l_file_handle);  -- Utl File Close 

END IF;

-- Begin for the Revision Files Extract 
IF l_revision = 'R' THEN

BEGIN

-- Get the file path from lookup 

  /*SELECT TRIM(' ' FROM meaning)
  INTO   l_file_path
  FROM   fnd_lookup_values_vl
  WHERE  lookup_type = 'XXS3_ITEM_OUT_FILE_PATH'
  AND    enabled_flag = 'Y'
  AND    trunc(SYSDATE) BETWEEN nvl(start_date_active, trunc(SYSDATE)) AND
         nvl(end_date_active, trunc(SYSDATE));*/
  
  SELECT substr(meaning, 1, instr(meaning, '-') - 1)
  INTO   l_file_path
  FROM   fnd_lookup_values_vl
  WHERE  lookup_type = 'XXS3_COMMON_EXTRACT_LKP'
  AND    enabled_flag = 'Y'
  AND    description = 'outpath'
  AND    substr(lookup_code, instr(lookup_code, '-') + 1) = 'ITEM';
  
   l_file_name   := 'Items_Extract_Revision' || '_' || p_s3_org_code || '_' || SYSDATE || '.txt';
   
   l_file_handle := UTL_FILE.fopen (l_file_path, l_file_name, 'W', 32767);  --Utl file Open 
   
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
	       log_p('No data found'||' '||SQLCODE||'-' ||SQLERRM);
      WHEN OTHERS THEN
         
       log_p('Invalid File Path'||' '||SQLCODE||'-'||SQLERRM);
    
   END;
    -- This will create the heading in  file 
    
  utl_file.put_line(l_file_handle,
'legacy_revision_id'	
||','||'revision' 
||','||'implementation_date'   
||','||'effectivity_date' 
||','||'ITEM'     	
||','||'s3_organization_code' 
||','||'Process Flag'
||','||'Transaction_Type'
||','||'Set Process ID'
||','||'revision_attribute10'  
||','||'revision_label'    
||','||'revision_description'     
||','||'ecn_initiation_date' 
||','||'change_notice'      
||','||'s3_revised_item_sequence_id'  
||','||'revision_language'  
||','||'source_lang' 
||','||'revision_tl_description'  
||','||'l_inventory_item_id'  
||','||'xxs3_revision_id'
||','||'legacy_organization_code'); 	


    FOR l_varrev IN c_revision LOOP
    --   This will print the records in excel sheet as per the query in cursor 
    utl_file.put_line(l_file_handle,
	'"' || l_varrev.legacy_revision_id	 
  ||'"'||','||'"'||l_varrev.revision 
  ||'"'||','||'"'||l_varrev.implementation_date 
  ||'"'||','||'"'||l_varrev.effectivity_date 
  ||'"'||','||'"'||l_varrev.item_number   		
||'"'||','||'"'||l_varrev.organization_code
||','||'NULL'
||','||'NULL'
||','||'NULL'
||'"'||','||'"'||l_varrev.attribute10       			 
);

END LOOP;
utl_file.fclose(l_file_handle); -- Utl file Close 

END IF;
EXCEPTION
    
     WHEN  utl_file.invalid_path THEN  
       log_p('Error : UTL File Directory Error (UTL_FILE_DIR) is invalid ..! '
                   || ' ' || SQLCODE||' : '|| SQLERRM);
                   
     WHEN utl_file.invalid_mode  THEN  
       log_p('Error : Data File has been opened in an invalid mode ...! '
                   || ' '|| SQLCODE||' : '|| SQLERRM);           
                   
     WHEN utl_file.invalid_operation THEN
       log_p('Error : UTL File has been performed an Invalid Operation ..! '
                   || ' '|| SQLCODE||' : '||SQLERRM);
                   
     WHEN utl_file.invalid_filehandle THEN
       log_p('Error : Invalid File handle has been Detected ..! '
                      || ' '|| SQLCODE|| ' : '|| SQLERRM);   
     WHEN utl_file.write_error THEN
       log_p('Error : UTL File Write Mode Error has been occurred ..! '
                   || ' '||SQLCODE|| ' : '|| SQLERRM);      
     WHEN utl_file.internal_error THEN
        log_p('Error : UTL File Internal Error has been occurred due to UTL File operation ..! '
                   || ' '|| SQLCODE|| ' : '|| SQLERRM);   
     WHEN OTHERS THEN
          log_p('Error:Utl_file_extract_out Procudure'||' '||SQLCODE||'-'||SQLERRM);                                                 
 END utl_file_extract_out;
 -- --------------------------------------------------------------------------------------------
  -- Purpose: Transform Report for the Items
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date          Name                          Description
  -- 1.0 17/08/2016   V.V.SATEESH                     Initial build
  -----------------------------------------------------------------------------------------------
  PROCEDURE data_transform_report (p_entity IN VARCHAR2)  IS
  
      --Variables 
      l_count_success NUMBER;
      l_count_fail NUMBER;
	  
        -- Cursor for the Data Transform report   
		
      CURSOR c_report_item IS
      
    SELECT xx_inventory_item_id
          ,l_inventory_item_id
          ,segment1
          ,xpmi.legacy_buyer_id
          ,s3_buyer_number
          ,legacy_accounting_rule_name
          ,s3_accounting_rule_name
          ,legacy_organization_code
          ,s3_organization_code
          ,l_source_organization_code
          ,s3_source_organization_code
          ,legacy_expense_acct_segment1
          ,legacy_expense_acct_segment2
          ,legacy_expense_acct_segment3
          ,legacy_expense_acct_segment4
          ,legacy_expense_acct_segment5
          ,legacy_expense_acct_segment6
          ,legacy_expense_acct_segment7
          ,legacy_expense_acct_segment8
          ,legacy_expense_acct_segment9
          ,legacy_expense_acct_segment10
          ,s3_expense_acct_segment1
          ,s3_expense_acct_segment2
          ,s3_expense_acct_segment3
          ,s3_expense_acct_segment4
          ,s3_expense_acct_segment5
          ,s3_expense_acct_segment6
          ,s3_expense_acct_segment7
          ,s3_expense_acct_segment8
          ,wip_supply_subinventory
          ,s3_wip_supply_subinventory
           --  ,primary_uom_code 
          ,secondary_uom_code
          ,s3_secondary_uom_code
          ,l_cost_of_sales_account
          ,l_cost_of_sales_acct_segment1
          ,l_cost_of_sales_acct_segment2
          ,l_cost_of_sales_acct_segment3
          ,l_cost_of_sales_acct_segment4
          ,l_cost_of_sales_acct_segment5
          ,l_cost_of_sales_acct_segment6
          ,l_cost_of_sales_acct_segment7
          ,l_cost_of_sales_acct_segment8
          ,l_cost_of_sales_acct_segment9
          ,l_cost_of_sales_acct_segment10
          ,s3_cost_sales_acct_segment1
          ,s3_cost_sales_acct_segment2
          ,s3_cost_sales_acct_segment3
          ,s3_cost_sales_acct_segment4
          ,s3_cost_sales_acct_segment5
          ,s3_cost_sales_acct_segment6
          ,s3_cost_sales_acct_segment7
          ,s3_cost_sales_acct_segment8
          ,s3_cost_sales_acct_segment9
          ,s3_cost_sales_acct_segment10
          ,legacy_sales_account
          ,legacy_sales_acct_segment1
          ,legacy_sales_acct_segment2
          ,legacy_sales_acct_segment3
          ,legacy_sales_acct_segment4
          ,legacy_sales_acct_segment5
          ,legacy_sales_acct_segment6
          ,legacy_sales_acct_segment7
          ,legacy_sales_acct_segment8
          ,legacy_sales_acct_segment9
          ,legacy_sales_acct_segment10
          ,s3_sales_acct_segment1
          ,s3_sales_acct_segment2
          ,s3_sales_acct_segment3
          ,s3_sales_acct_segment4
          ,s3_sales_acct_segment5
          ,s3_sales_acct_segment6
          ,s3_sales_acct_segment7
          ,s3_sales_acct_segment8
          ,s3_sales_acct_segment9
          ,s3_sales_acct_segment10
          ,inventory_item_status_code
          ,s3_inventory_item_status_code
          ,planner_code
          ,s3_planner_code
          ,atp_rule_name
          ,s3_atp_rule_name
          ,item_type
          ,s3_item_type
          ,tracking_quantity_ind
          ,s3_tracking_quantity_ind
          ,secondary_default_ind
          ,s3_secondary_default_ind
          ,ont_pricing_qty_source
          ,s3_ont_pricing_qty_source
          ,attribute25
          ,s3_attribute25
          ,expiration_action_code
          ,s3_expiration_action_code
          ,expiration_action_interval
          ,s3_expiration_action_interval
          ,legacy_revision_id
          ,xxs3_revision_id
          ,revised_item_sequence_id
          ,s3_revised_item_sequence_id
          ,xpmi.transform_status
          ,xpmi.transform_error
    FROM   xxs3_ptm_mtl_master_items xpmi
    WHERE  xpmi.transform_status IN ('PASS', 'FAIL');
  
  BEGIN
  IF p_entity = 'ITEM' THEN
    -- Query to get the count of the Transform status pass  
	
    SELECT COUNT(1)
    INTO   l_count_success
    FROM   xxs3_ptm_mtl_master_items xpmi
    WHERE  xpmi.transform_status = 'PASS';
	
 -- Query to get the count of the Transfor status fail  
 
    SELECT COUNT(1)
    INTO   l_count_fail
    FROM   xxs3_ptm_mtl_master_items xpmi
    WHERE  xpmi.transform_status = 'FAIL';

 -- Print the Transform details in the output 
 
	  out_p(rpad('Report name = Data Transformation Report'|| g_delimiter, 100, ' '));
    out_p(rpad('========================================'|| g_delimiter, 100, ' '));
    out_p(rpad('Data Migration Object Name = '||'ITEM MASTER' || g_delimiter, 100, ' '));
    out_p('');
    out_p(rpad('Run date and time:    ' ||
                       to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI')|| g_delimiter, 100, ' '));
    out_p(rpad('Total Record Count Success = '||l_count_success || g_delimiter, 100, ' '));
    out_p(rpad('Total Record Count Failure = '||l_count_fail|| g_delimiter , 100, ' '));
    out_p('');
    out_p(rpad('Track Name', 10, ' ') || g_delimiter ||
                       rpad('Entity Name', 15, ' ') || g_delimiter ||
                       rpad('XX Inventory Item ID  ', 20, ' ') || g_delimiter ||
                       rpad('Inventory Item ID', 20, ' ') || g_delimiter ||
                       rpad('Item Number', 30, ' ') || g_delimiter ||
                       rpad('Legacy_Buyer_Id', 17, ' ') || g_delimiter ||
                       rpad('S3_Buyer_Number', 50, ' ') || g_delimiter ||
                       rpad('Legacy_Accounting_Rule_Name', 50, ' ') || g_delimiter ||
                       rpad('S3_Accounting_Rule_Name', 50, ' ') || g_delimiter ||
                       rpad('Legacy_Organization_Code', 50, ' ') || g_delimiter ||
                       rpad('S3_Organization_Code', 50, ' ') || g_delimiter ||
                       rpad('L_Source_Organization_Code', 50, ' ') || g_delimiter ||
                       rpad('S3_Source_Organization_Code', 50, ' ') || g_delimiter ||
                       rpad('Wip_Supply_Subinventory', 50, ' ') || g_delimiter ||
                       rpad('s3_wip_supply_subinventory', 50, ' ') || g_delimiter ||
                       rpad('Secondary_Uom_Code', 50, ' ') || g_delimiter ||
                       rpad('S3_Secondary_Uom_Code', 50, ' ') || g_delimiter ||
                       rpad('Inventory_Item_Status_Code', 50, ' ') || g_delimiter ||
                       rpad('S3_Inventory_Item_Status_Code', 50, ' ') || g_delimiter ||
                       rpad('Planner_Code', 50, ' ') || g_delimiter ||
                       rpad('S3_Planner_Code', 50, ' ') || g_delimiter ||
                       rpad('Atp_Rule_Name', 50, ' ') || g_delimiter ||
                       rpad('S3_Atp_Rule_Name', 50, ' ') || g_delimiter ||
                       rpad('Item_Type', 50, ' ') || g_delimiter ||
                       rpad('S3_Item_Type', 50, ' ') || g_delimiter ||
                       rpad('Tracking_Quantity_Ind', 50, ' ') || g_delimiter ||
                       rpad('S3_Tracking_Quantity_Ind', 50, ' ') || g_delimiter ||
                       rpad('Secondary_Default_Ind', 50, ' ') || g_delimiter ||
                       rpad('S3_Secondary_Default_Ind', 50, ' ') || g_delimiter ||
					             rpad('Ont_Pricing_Qty_Source', 50, ' ') || g_delimiter ||
                       rpad('S3_Ont_Pricing_Qty_Source', 50, ' ') || g_delimiter ||
                       rpad('Attribute25', 50, ' ') || g_delimiter ||
                       rpad('S3_Attribute25', 50, ' ') || g_delimiter ||
                       rpad('Expiration_Action_Interval', 50, ' ') || g_delimiter ||
                       rpad('S3_Expiration_Action_Interval', 50, ' ') || g_delimiter ||
                       rpad('Expiration_Action_Code', 50, ' ') || g_delimiter ||
                       rpad('S3_Expiration_Action_Code', 50, ' ') || g_delimiter ||
                       rpad('Legacy_Revision_Id', 50, ' ') || g_delimiter ||
                       rpad('XXS3_Revision_Id', 50, ' ') || g_delimiter ||
                       rpad('Revised_Item_Sequence_Id', 50, ' ') || g_delimiter ||
                       rpad('S3_Revised_Item_Sequence_Id', 50, ' ') || g_delimiter ||
                       rpad('Expense_Acct_Segment1 ', 25, ' ') || g_delimiter ||
                       rpad('Expense_Acct_Segment2 ', 25, ' ') || g_delimiter ||
                       rpad('Expense_Acct_Segment3 ', 25, ' ') || g_delimiter ||
                       rpad('Expense_Acct_Segment4 ', 25, ' ') || g_delimiter ||
                       rpad('Expense_Acct_Segment5 ', 25, ' ') || g_delimiter ||
                       rpad('Expense_Acct_Segment6 ', 25, ' ') || g_delimiter ||
                       rpad('Expense_Acct_Segment7 ', 25, ' ') || g_delimiter ||
                       rpad('Expense_Acct_Segment8 ', 25, ' ') || g_delimiter ||
                       rpad('Expense_Acct_Segment9 ', 25, ' ') || g_delimiter ||
                       rpad('Expense_Acct_Segment10 ', 25, ' ') || g_delimiter ||
                       rpad('S3_Expense_Acct_Segment1', 25, ' ') || g_delimiter ||
                       rpad('S3_Expense_Acct_Segment2', 25, ' ') || g_delimiter ||
                       rpad('S3_Expense_Acct_Segment3', 25, ' ') || g_delimiter ||
                       rpad('S3_Expense_Acct_Segment4', 25, ' ') || g_delimiter ||
                       rpad('S3_Expense_Acct_Segment5', 25, ' ') || g_delimiter ||
                       rpad('S3_Expense_Acct_Segment6', 25, ' ') || g_delimiter ||
                       rpad('S3_Expense_Acct_Segment7', 25, ' ') || g_delimiter ||
                       rpad('S3_Expense_Acct_Segment8', 25, ' ') || g_delimiter ||
                       rpad('Cost_of_Sales_Acct_Segment1', 30, ' ') || g_delimiter ||
                       rpad('Cost_Of_Sales_Acct_Segment2', 30, ' ') || g_delimiter ||
                       rpad('Cost_Of_Sales_Acct_Segment3', 30, ' ') || g_delimiter ||
                       rpad('Cost_Of_Sales_Acct_Segment4', 30, ' ') || g_delimiter ||
                       rpad('Cost_Of_Sales_Acct_Segment5', 30, ' ') || g_delimiter ||
                       rpad('Cost_Of_Sales_Acct_Segment6', 30, ' ') || g_delimiter ||
                       rpad('Cost_Of_Sales_Acct_Segment7', 30, ' ') || g_delimiter ||
                       rpad('Cost_Of_Sales_Acct_Segment8', 30, ' ') || g_delimiter ||
                       rpad('Cost_Of_Sales_Acct_Segment9', 30, ' ') || g_delimiter ||
                       rpad('Cost_Of_sales_Acct_Segment10', 30, ' ') || g_delimiter ||
                       rpad('S3_Cost_Sales_Acct_Segment1', 30, ' ') || g_delimiter ||
                       rpad('S3_Cost_Sales_Acct_Segment2', 30, ' ') || g_delimiter ||
                       rpad('S3_Cost_Sales_Acct_Segment3', 30, ' ') || g_delimiter ||
                       rpad('S3_Cost_Sales_Acct_Segment4', 30, ' ') || g_delimiter ||
                       rpad('S3_Cost_Sales_Acct_Segment5', 30, ' ') || g_delimiter ||
                       rpad('S3_Cost_Sales_Acct_Segment6', 30, ' ') || g_delimiter ||
                       rpad('S3_Cost_Sales_Acct_Segment7', 30, ' ') || g_delimiter ||
                       rpad('S3_Cost_Sales_Acct_Segment8', 30, ' ') || g_delimiter ||
                       rpad('Sales_Acct_Segment1 ', 25, ' ') || g_delimiter ||
                       rpad('Sales_Acct_Segment2 ', 25, ' ') || g_delimiter ||
                       rpad('Sales_Acct_Segment3 ', 25, ' ') || g_delimiter ||
                       rpad('Sales_Acct_Segment4 ', 25, ' ') || g_delimiter ||
                       rpad('Sales_Acct_Segment5 ', 25, ' ') || g_delimiter ||
                       rpad('Sales_Acct_Segment6 ', 25, ' ') || g_delimiter ||
                       rpad('Sales_Acct_Segment7 ', 25, ' ') || g_delimiter ||
                       rpad('Sales_Acct_Segment8 ', 25, ' ') || g_delimiter ||
                       rpad('Sales_Acct_Segment9 ', 25, ' ') || g_delimiter ||
                       rpad('Sales_Acct_Segment10 ', 25, ' ') || g_delimiter ||
                       rpad('S3_Sales_Acct_Segment1', 25, ' ') || g_delimiter ||
                       rpad('S3_Sales_Acct_Segment2', 25, ' ') || g_delimiter ||
                       rpad('S3_Sales_Acct_Segment3', 25, ' ') || g_delimiter ||
                       rpad('S3_Sales_Acct_Segment4', 25, ' ') || g_delimiter ||
                       rpad('S3_Sales_Acct_Segment5', 25, ' ') || g_delimiter ||
                       rpad('S3_Sales_Acct_Segment6', 25, ' ') || g_delimiter ||
                       rpad('S3_Sales_Acct_Segment7', 25, ' ') || g_delimiter ||
                       rpad('S3_Sales_Acct_Segment8', 25, ' ') || g_delimiter ||
                       rpad('Status', 10, ' ') || g_delimiter ||
                       rpad('Error Message', 200, ' ') );

    FOR r_data IN c_report_item LOOP
                           
	              	out_p(rpad('PTM', 10, ' ') || g_delimiter ||
                       rpad('ITEM', 15, ' ') || g_delimiter ||
                       rpad(r_data.xx_inventory_item_id , 30, ' ') || g_delimiter ||
                       rpad(r_data.l_inventory_item_id, 30, ' ') || g_delimiter ||
                       rpad(r_data.SEGMENT1, 30, ' ') || g_delimiter ||
                       rpad(NVL(TO_CHAR(r_data.legacy_buyer_id),'NULL'), 17, ' ') || g_delimiter ||
                       rpad(NVL(r_data.s3_buyer_number,'NULL'), 50, ' ') || g_delimiter ||
                       rpad(NVL(r_data.legacy_accounting_rule_name,'NULL'), 50, ' ') || g_delimiter ||
                       rpad(NVL(r_data.s3_accounting_rule_name,'NULL'), 50, ' ') || g_delimiter ||
                       rpad(NVL(r_data.legacy_organization_code,'NULL'), 50, ' ') || g_delimiter ||
                       rpad(NVL(r_data.s3_organization_code,'NULL'), 50, ' ') || g_delimiter ||
                       rpad(NVL(r_data.l_source_organization_code,'NULL'), 50, ' ') || g_delimiter ||
                       rpad(NVL(r_data.s3_source_organization_code,'NULL'), 50, ' ') || g_delimiter ||
					             rpad(NVL(r_data.wip_supply_subinventory,'NULL'), 50, ' ') || g_delimiter ||
                       rpad(NVL(r_data.s3_wip_supply_subinventory,'NULL'), 50, ' ') || g_delimiter ||
                       rpad(NVL(r_data.secondary_uom_code,'NULL'), 50, ' ') || g_delimiter ||
                       rpad(NVL(r_data.s3_secondary_uom_code,'NULL'), 50, ' ') || g_delimiter ||
                       rpad(NVL(r_data.inventory_item_status_code,'NULL'), 50, ' ') || g_delimiter ||
                       rpad(NVL(r_data.s3_inventory_item_status_code,'NULL'), 50, ' ') || g_delimiter ||
                       rpad(NVL(r_data.planner_code,'NULL'), 50, ' ') || g_delimiter ||
                       rpad(NVL(r_data.s3_planner_code,'NULL'), 50, ' ') || g_delimiter ||
                       rpad(NVL(r_data.atp_rule_name,'NULL'), 50, ' ') || g_delimiter ||
                       rpad(NVL(r_data.s3_atp_rule_name,'NULL'), 50, ' ') || g_delimiter ||
                       rpad(NVL(r_data.item_type,'NULL'), 50, ' ') || g_delimiter ||
                       rpad(NVL(r_data.s3_item_type,'NULL'), 50, ' ') || g_delimiter ||
                       rpad(NVL(r_data.tracking_quantity_ind,'NULL'), 50, ' ') || g_delimiter ||
                       rpad(NVL(r_data.s3_tracking_quantity_ind,'NULL'), 50, ' ') || g_delimiter ||
                       rpad(NVL(r_data.secondary_default_ind,'NULL'), 50, ' ') || g_delimiter ||
                       rpad(NVL(r_data.s3_secondary_default_ind,'NULL'), 50, ' ') || g_delimiter ||
					             rpad(NVL(r_data.ont_pricing_qty_source,'NULL'), 50, ' ') || g_delimiter ||
                       rpad(NVL(r_data.s3_ont_pricing_qty_source,'NULL'), 50, ' ') || g_delimiter ||
                       rpad(NVL(r_data.attribute25,'NULL'), 50, ' ') || g_delimiter ||
                       rpad(NVL(r_data.s3_attribute25,'NULL'), 50, ' ') || g_delimiter ||
                       rpad(NVL(r_data.expiration_action_code,'NULL'), 50, ' ') || g_delimiter ||
                       rpad(NVL(r_data.s3_expiration_action_code,'NULL'), 50, ' ') || g_delimiter ||
                       rpad(NVL(TO_CHAR(r_data.expiration_action_interval),'NULL'), 50, ' ') || g_delimiter ||
                       rpad(NVL(r_data.s3_expiration_action_interval,'NULL'), 50, ' ') || g_delimiter ||
                       rpad(NVL(TO_CHAR(r_data.legacy_revision_id),'NULL'), 50, ' ') || g_delimiter ||
                       rpad(NVL(TO_CHAR(r_data.xxs3_revision_id),'NULL'), 50, ' ') || g_delimiter ||
                       rpad(NVL(TO_CHAR(r_data.revised_item_sequence_id),'NULL'), 50, ' ') || g_delimiter ||
                       rpad(NVL(TO_CHAR(r_data.s3_revised_item_sequence_id),'NULL'), 50, ' ') || g_delimiter ||
                       rpad(NVL(r_data.legacy_expense_acct_segment1,'NULL'), 25, ' ') || g_delimiter ||
                       rpad(NVL(r_data.legacy_expense_acct_segment2,'NULL'), 25, ' ') || g_delimiter ||
                       rpad(NVL(r_data.legacy_expense_acct_segment3,'NULL'), 25, ' ') || g_delimiter ||
                       rpad(NVL(r_data.legacy_expense_acct_segment4,'NULL'), 25, ' ') || g_delimiter ||
                       rpad(NVL(r_data.legacy_expense_acct_segment5,'NULL'), 25, ' ') || g_delimiter ||
                       rpad(NVL(r_data.legacy_expense_acct_segment6,'NULL'), 25, ' ') || g_delimiter ||
                       rpad(NVL(r_data.legacy_expense_acct_segment7,'NULL'), 25, ' ') || g_delimiter ||
                       rpad(NVL(r_data.legacy_expense_acct_segment8,'NULL'), 25, ' ') || g_delimiter ||
                       rpad(NVL(r_data.legacy_expense_acct_segment9,'NULL'), 25, ' ') || g_delimiter ||
                       rpad(NVL(r_data.legacy_expense_acct_segment10,'NULL'), 25, ' ') || g_delimiter ||
                       rpad(NVL(r_data.s3_expense_acct_segment1,'NULL'), 25, ' ') || g_delimiter ||
                       rpad(NVL(r_data.s3_expense_acct_segment2,'NULL'), 25, ' ') || g_delimiter ||
                       rpad(NVL(r_data.s3_expense_acct_segment3,'NULL'), 25, ' ') || g_delimiter ||
                       rpad(NVL(r_data.s3_expense_acct_segment4,'NULL'), 25, ' ') || g_delimiter ||
                       rpad(NVL(r_data.s3_expense_acct_segment5,'NULL'), 25, ' ') || g_delimiter ||
                       rpad(NVL(r_data.s3_expense_acct_segment6,'NULL'), 25, ' ') || g_delimiter ||
                       rpad(NVL(r_data.s3_expense_acct_segment7,'NULL'), 25, ' ') || g_delimiter ||
                       rpad(NVL(r_data.s3_expense_acct_segment8,'NULL'), 25, ' ') || g_delimiter ||
                       rpad(NVL(r_data.l_cost_of_sales_acct_segment1,'NULL'), 50, ' ') || g_delimiter ||
                       rpad(NVL(r_data.l_cost_of_sales_acct_segment2,'NULL'), 50, ' ') || g_delimiter ||
                       rpad(NVL(r_data.l_cost_of_sales_acct_segment3,'NULL'), 50, ' ') || g_delimiter ||
                       rpad(NVL(r_data.l_cost_of_sales_acct_segment4,'NULL'), 50, ' ') || g_delimiter ||
                       rpad(NVL(r_data.l_cost_of_sales_acct_segment5,'NULL'), 50, ' ') || g_delimiter ||
                       rpad(NVL(r_data.l_cost_of_sales_acct_segment6,'NULL'), 50, ' ') || g_delimiter ||
                       rpad(NVL(r_data.l_cost_of_sales_acct_segment7,'NULL'), 50, ' ') || g_delimiter ||
                       rpad(NVL(r_data.l_cost_of_sales_acct_segment8,'NULL'), 50, ' ') || g_delimiter ||
                       rpad(NVL(r_data.l_cost_of_sales_acct_segment9,'NULL'), 50, ' ') || g_delimiter ||
                       rpad(NVL(r_data.l_cost_of_sales_acct_segment10,'NULL'), 50, ' ') || g_delimiter ||
                       rpad(NVL(r_data.s3_cost_sales_acct_segment1,'NULL'), 50, ' ') || g_delimiter ||
                       rpad(NVL(r_data.s3_cost_sales_acct_segment2,'NULL'), 50, ' ') || g_delimiter ||
					             rpad(NVL(r_data.s3_cost_sales_acct_segment3,'NULL'), 50, ' ') || g_delimiter ||
					             rpad(NVL(r_data.s3_cost_sales_acct_segment4,'NULL'), 50, ' ') || g_delimiter ||
					             rpad(NVL(r_data.s3_cost_sales_acct_segment5,'NULL'), 50, ' ') || g_delimiter ||
					             rpad(NVL(r_data.s3_cost_sales_acct_segment6,'NULL'), 50, ' ') || g_delimiter ||
					             rpad(NVL(r_data.s3_cost_sales_acct_segment7,'NULL'), 50, ' ') || g_delimiter ||
					             rpad(NVL(r_data.s3_cost_sales_acct_segment8,'NULL'), 50, ' ') || g_delimiter ||
					             rpad(NVL(r_data.legacy_sales_acct_segment1,'NULL'), 25, ' ') || g_delimiter ||
                       rpad(NVL(r_data.legacy_sales_acct_segment2,'NULL'), 25, ' ') || g_delimiter ||
					             rpad(NVL(r_data.legacy_sales_acct_segment3,'NULL'), 25, ' ') || g_delimiter ||
					             rpad(NVL(r_data.legacy_sales_acct_segment4,'NULL'), 25, ' ') || g_delimiter ||
					             rpad(NVL(r_data.legacy_sales_acct_segment5,'NULL'), 25, ' ') || g_delimiter ||
					             rpad(NVL(r_data.legacy_sales_acct_segment6,'NULL'), 25, ' ') || g_delimiter ||
					             rpad(NVL(r_data.legacy_sales_acct_segment7,'NULL'), 25, ' ') || g_delimiter ||
					             rpad(NVL(r_data.legacy_sales_acct_segment8,'NULL'), 25, ' ') || g_delimiter ||
					             rpad(NVL(r_data.legacy_sales_acct_segment9,'NULL'), 25, ' ') || g_delimiter ||
					             rpad(NVL(r_data.legacy_sales_acct_segment10,'NULL'), 25, ' ') || g_delimiter ||
          					   rpad(NVL(r_data.s3_sales_acct_segment1,'NULL'), 25, ' ') || g_delimiter ||		
          					   rpad(NVL(r_data.s3_sales_acct_segment2,'NULL'), 25, ' ') || g_delimiter ||	
          					   rpad(NVL(r_data.s3_sales_acct_segment3,'NULL'), 25, ' ') || g_delimiter ||	
          					   rpad(NVL(r_data.s3_sales_acct_segment4,'NULL'), 25, ' ') || g_delimiter ||	
          					   rpad(NVL(r_data.s3_sales_acct_segment5,'NULL'), 25, ' ') || g_delimiter ||	
          					   rpad(NVL(r_data.s3_sales_acct_segment6,'NULL'), 25, ' ') || g_delimiter ||	
          					   rpad(NVL(r_data.s3_sales_acct_segment7,'NULL'), 25, ' ') || g_delimiter ||	
          					   rpad(NVL(r_data.s3_sales_acct_segment8,'NULL'), 25, ' ') || g_delimiter ||
          					   rpad(r_data.transform_status, 10, ' ') || g_delimiter ||
          					   rpad(NVL(r_data.transform_error,'NULL'), 200, ' ') );       
                   
    END LOOP;
         out_p('');
          out_p('Stratasys Confidential'|| g_delimiter);
   END IF;
    EXCEPTION
      WHEN no_data_found THEN
	    log_p('No data found'||' '||SQLCODE||'-' ||SQLERRM);
    
     WHEN others THEN
          log_p('Error:data_transform_report Procudure'||' '||SQLCODE||'-'||SQLERRM);  
	  
 END data_transform_report;

-- --------------------------------------------------------------------------------------------
  -- Purpose: Generate Data Quality Report for Items
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date          Name                          Description
  --  1.0 17/08/2016   V.V.SATEESH                    Initial build
  -----------------------------------------------------------------------------------------------
  PROCEDURE report_data_items(p_entity IN VARCHAR2) IS
  
  -- Variables 
   l_count_dq	 NUMBER;
   
   --Cursor for the Data Quality Report 
    CURSOR c_report_item IS
    
      SELECT nvl(c.rule_name, ' ') rule_name
            ,nvl(c.notes, ' ') notes
            ,c.xx_inventory_item_id xx_inventory_item_id
            ,d.l_inventory_item_id
            ,d.segment1
            ,decode(d.process_flag, 'R', 'Y', 'Q', 'N') reject_record
      FROM   xxobjt.xxs3_ptm_mtl_master_items_dq c
            ,xxobjt.xxs3_ptm_mtl_master_items    d
      WHERE  c.xx_inventory_item_id = d.xx_inventory_item_id
      AND    d.process_flag IN ('Q', 'R');
     
  BEGIN
  
     IF p_entity = 'ITEM' THEN
     
        SELECT COUNT(1)
        INTO   l_count_dq
        FROM   xxobjt.xxs3_ptm_mtl_master_items d
        WHERE  d.process_flag IN ('Q', 'R');
    
    
    out_p(rpad('Report name = Data Quality Error Report'|| g_delimiter, 100, ' '));
    out_p(rpad('========================================'|| g_delimiter, 100, ' '));
    out_p(rpad('Data Migration Object Name = '||'Item Master' || g_delimiter, 100, ' '));
    out_p('');
    out_p(rpad('Run date and time:    ' ||
                       to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI')|| g_delimiter, 100, ' '));
    out_p(rpad('Total Record Count Having DQ Issues = '||l_count_dq || g_delimiter, 100, ' '));
    /*out_p( rpad('Total Record Count Rejected =  '||l_count_reject|| g_delimiter , 100, ' '));*/
    out_p('');

    out_p(rpad('Track Name', 10, ' ') || g_delimiter ||
                       rpad('Entity Name', 11, ' ') || g_delimiter ||
                       rpad('XX Inventory Item Id  ', 20, ' ') || g_delimiter ||
                       rpad('Inventory Item Id', 20, ' ') || g_delimiter ||
                       rpad('Item Number', 30, ' ') || g_delimiter ||
                       rpad('Reject Record Flag(Y/N)', 22, ' ') || g_delimiter ||
                       rpad('Rule Name', 45, ' ') || g_delimiter ||
                       rpad('Reason Code', 50, ' ') );


    FOR r_data IN c_report_item LOOP
      out_p(rpad('PTM', 10, ' ') || g_delimiter ||
                         rpad('ITEMS', 11, ' ') || g_delimiter ||
                         rpad(r_data.xx_inventory_item_id, 20, ' ') || g_delimiter ||
                         rpad(r_data.l_inventory_item_id, 20, ' ') || g_delimiter ||
                         rpad(r_data.segment1, 30, ' ') || g_delimiter ||
                         rpad(r_data.reject_record, 22, ' ') || g_delimiter ||
                         rpad(NVL(r_data.rule_name,'NULL'), 45  , ' ') || g_delimiter ||
                         rpad(NVL(r_data.notes,'NULL'), 50, ' ') );

    END LOOP;

    out_p('');
    out_p('Stratasys Confidential'|| g_delimiter);
    END IF;
    
    EXCEPTION
      WHEN no_data_found THEN
	    log_p('Error:No data found in "report_data_items Procedure"'||' '||SQLCODE||'-' ||SQLERRM);
    
     WHEN others THEN
          log_p('Error:report_data_items Procudure'||' '||SQLCODE||'-'||SQLERRM);  
	  
  END report_data_items;

 -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure transform the Buyer id from legacy to Employee number of Buyer in S3
  --          staging table XXOBJT.XXS3_PTM_MTL_MASTER_ITEMS
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --1.0   17/08/2016 V.V.SATEESH				   Initial build	
  -- --------------------------------------------------------------------------------------------

PROCEDURE update_buyer_number(p_xx_inventory_item_id IN NUMBER
                              ,p_buyer_id IN NUMBER
							                ,p_transformerr IN VARCHAR2) IS
-- Variables 
l_buyer_number NUMBER;
l_error_msg VARCHAR2(4000);

BEGIN
  --Get the Employee Number of the Buyer 
 
   SELECT employee_number
   INTO   l_buyer_number
   FROM   per_all_people_f
   WHERE  person_id = p_buyer_id
   AND EMPLOYEE_NUMBER IS NOT NULL
   AND ROWNUM<2;
  
IF l_buyer_number IS NOT NULL THEN

 --Update the Employee Number of the Buyer in the stage table 

      UPDATE xxobjt.xxs3_ptm_mtl_master_items
      SET    s3_buyer_number = l_buyer_number
      WHERE  xx_inventory_item_id = p_xx_inventory_item_id
      AND    legacy_buyer_id = p_buyer_id;
      
      COMMIT;
      
END IF;

EXCEPTION
    WHEN no_data_found THEN		 
		 l_error_msg := 'Employee Not Found '||SQLERRM;
		 
         log_p(l_error_msg);
         --Update the if Employee not found in the stag table 
		
          UPDATE xxobjt.xxs3_ptm_mtl_master_items
          SET    transform_status = 'FAIL'
                ,transform_error  = p_transformerr || ',' || l_error_msg
          WHERE  xx_inventory_item_id = p_xx_inventory_item_id;
     
     WHEN others THEN
          log_p('Error:update_buyer_number Procudure'||' '||SQLCODE||'-'||SQLERRM); 
           
END update_buyer_number;

   --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will transform the Atp Rule Name from legacy to S3 Atp Rule Name
  --           staging table XXS3_PTM_MTL_MASTER_ITEMS
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --1.0  17/08/2016   V.V.SATEESH				    Initial build				
  -- --------------------------------------------------------------------------------------------

PROCEDURE update_atp_rule_name(p_xx_inventory_item_id IN NUMBER
                               ,p_atp_rule_name IN VARCHAR2) IS

l_atp_rule_name VARCHAR2(100);
l_error_msg     VARCHAR2(4000);

BEGIN

    SELECT rule_name
    INTO   l_atp_rule_name
    FROM   mtl_atp_rules r
    WHERE  rule_name = p_atp_rule_name;

IF l_atp_rule_name IN('Objet Consumables', 'Objet Systems','SSUS Standard')  THEN

    UPDATE xxobjt.xxs3_ptm_mtl_master_items
    SET    s3_atp_rule_name = p_atp_rule_name
    WHERE  xx_inventory_item_id = p_xx_inventory_item_id;
ELSE
   l_error_msg:='S3 ATP Rule Name  Mapping from legacy values';

      UPDATE xxobjt.xxs3_ptm_mtl_master_items
      SET    transform_status = 'PASS'
            ,s3_atp_rule_name = NULL
            ,transform_error  = l_error_msg
      WHERE  xx_inventory_item_id = p_xx_inventory_item_id;
END IF;

EXCEPTION
   WHEN no_data_found THEN
          l_error_msg := 'Accounting rule not found Not Found : '||SQLERRM;
		  
		    log_p(l_error_msg);
        
        UPDATE xxobjt.xxs3_ptm_mtl_master_items
        SET    transform_status = 'FAIL'
              ,transform_error  = l_error_msg
        WHERE  xx_inventory_item_id = p_xx_inventory_item_id;
    
     WHEN others THEN
          log_p('Error:update_atp_rule_name Procudure'||' '||SQLCODE||'-'||SQLERRM);
          
               
END update_atp_rule_name;

--------------------------------------------------------------------------------------------------
  -- Purpose: This procedure will update the Planner Code for the Master Items based on conditions
  --           staging table XXS3_PTM_MTL_MASTER_ITEMS
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --1.0  17/08/2016   V.V.SATEESH				    Initial build	
  ----------------------------------------------------------------------------------------------

 PROCEDURE update_planner(p_xx_inventory_item_id  IN NUMBER
				                  ,p_organization_code    IN VARCHAR2
						              ,p_planner_code         IN VARCHAR2) IS

l_count_fdm NUMBER;
l_count_poly NUMBER;
l_planner_code VARCHAR2(100);
l_error_msg     VARCHAR2(4000);

BEGIN

 IF p_organization_code = 'OMA' THEN
 
-- Query for get count of the PRODUCT_HIERARCHY.SEGMENT6='FDM' items 

    /*  SELECT COUNT(DISTINCT inventory_item_id)
      INTO   l_count_fdm
      FROM   mtl_item_categories_v mic
            ,mtl_parameters        mp
      WHERE  mic.inventory_item_id = p_xx_inventory_item_id
      AND    mic.organization_id = mp.organization_id
      AND    segment6 = 'FDM';*/
      
      SELECT COUNT(inventory_item_id)
      INTO   l_count_fdm
      FROM   (SELECT inventory_item_id
                    ,row_number() over(PARTITION BY inventory_item_id ORDER BY inventory_item_id) rn
              FROM   mtl_item_categories_v mic
                    ,mtl_parameters        mp
              WHERE  mic.inventory_item_id = p_xx_inventory_item_id
              AND    mic.organization_id = mp.organization_id
              AND    segment6 = 'FDM')
      WHERE  rn = 1;
      
-- Query for get count of the PRODUCT_HIERARCHY.SEGMENT6='POLYJET' items 	

     /* SELECT COUNT(DISTINCT inventory_item_id)
      INTO   l_count_poly
      FROM   mtl_item_categories_v mic
            ,mtl_parameters        mp
      WHERE  mic.inventory_item_id = p_xx_inventory_item_id
      AND    mic.organization_id = mp.organization_id
      AND    segment6 = 'POLYJET';*/
      
        SELECT COUNT(inventory_item_id)
        INTO   l_count_poly
        FROM   (SELECT inventory_item_id
                      ,row_number() over(PARTITION BY inventory_item_id ORDER BY inventory_item_id) rn
                FROM   mtl_item_categories_v mic
                      ,mtl_parameters        mp
                WHERE  mic.inventory_item_id = p_xx_inventory_item_id
                AND    mic.organization_id = mp.organization_id
                AND    segment6 = 'POLYJET')
        WHERE  rn = 1;

   
  IF l_count_fdm > 0 THEN
  
  -- Query for get Planner Code if the PRODUCT_HIERARCHY.SEGMENT6='FDM' items and org='UME' 
  
      SELECT planner_code
      INTO   l_planner_code
      FROM   mtl_parameters     mp
            ,mtl_system_items_b msi
      WHERE  msi.inventory_item_id = p_xx_inventory_item_id
      AND    msi.organization_id = mp.organization_id
      AND    mp.organization_code = 'UME';
    
    --Update Planner Code of the UME org if  PRODUCT_HIERARCHY.SEGMENT6='FDM' 
   
        UPDATE xxobjt.xxs3_ptm_mtl_master_items
        SET    s3_planner_code = l_planner_code
        WHERE  l_inventory_item_id = p_xx_inventory_item_id;
        
        COMMIT;  
   ELSIF  l_count_poly > 0 THEN
-- Query for get Planner Code if the PRODUCT_HIERARCHY.SEGMENT6='POLYJET' items and org NVL('IPK','IRK') 
     
          SELECT planner_code
          INTO   l_planner_code
          FROM   mtl_parameters     mp
                ,mtl_system_items_b msi
          WHERE  msi.inventory_item_id = p_xx_inventory_item_id
          AND    msi.organization_id = mp.organization_id
          AND    mp.organization_code = nvl('IPK', 'IRK');
	
 --Update Planner Code of the org NVL('IPK','IRK')  if  PRODUCT_HIERARCHY.SEGMENT6='POLYJET' 
 
           UPDATE xxobjt.xxs3_ptm_mtl_master_items
           SET    s3_planner_code = l_planner_code
           WHERE  l_inventory_item_id = p_xx_inventory_item_id;
           COMMIT;
     ELSE 
    -- Query for Planner Code of the org NVL('UME','IPK')  if above conditions not satisifies
    
           SELECT planner_code
           INTO   l_planner_code
           FROM   mtl_parameters     mp
                 ,mtl_system_items_b msi
           WHERE  msi.inventory_item_id = p_xx_inventory_item_id
           AND    msi.organization_id = mp.organization_id
           AND    mp.organization_code = nvl('UME', 'IPK');
           
  -- Update Planner Code of the org NVL('UME','IPK')  if above conditions not satisifies
  
          UPDATE xxobjt.xxs3_ptm_mtl_master_items
          SET    s3_planner_code = l_planner_code
          WHERE  l_inventory_item_id = p_xx_inventory_item_id;
          COMMIT;
  END IF;
   ELSE
      log_p('p_planner_code' || p_planner_code);
          
          UPDATE xxs3_ptm_mtl_master_items
          SET    s3_planner_code = p_planner_code
          WHERE  l_inventory_item_id = p_xx_inventory_item_id;
      
      COMMIT;
END IF;

EXCEPTION
    WHEN no_data_found THEN
    
	    log_p('Error:No data found in update_planner procedure'||' '||SQLCODE||'-' ||SQLERRM);
      
    WHEN others THEN
        
		  l_error_msg := 'Invalid Planner Code Found : '||' '||SQLCODE||'-' ||SQLERRM;
      
		  log_p(l_error_msg);
		 
         UPDATE xxs3_ptm_mtl_master_items
         SET    transform_status = 'FAIL'
               ,transform_error  = l_error_msg
         WHERE  l_inventory_item_id = p_xx_inventory_item_id;
         
END update_planner;


-- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will update the Buyer Id for the Master org Items
  --           staging table XXS3_PTM_MTL_MASTER_ITEMS
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --1.0  17/08/2016   V.V.SATEESH				    Initial build	
  -- --------------------------------------------------------------------------------------------

 PROCEDURE update_buyer_id(p_xx_inventory_item_id IN NUMBER
                          ,p_organization_code    IN VARCHAR2) IS

l_count_fdm  NUMBER;
l_count_poly NUMBER;
l_count_mat  NUMBER;
l_buyer_id   VARCHAR2(100);
l_error_msg  VARCHAR2(4000);

BEGIN

 IF p_organization_code = 'OMA' THEN
 --Query for get count of the PRODUCT_HIERARCHY.SEGMENT6='FDM' items 

        /*SELECT COUNT(DISTINCT inventory_item_id)
        INTO   l_count_fdm
        FROM   mtl_item_categories_v mic
              ,mtl_parameters        mp
        WHERE  mic.inventory_item_id = p_xx_inventory_item_id
        AND    mic.organization_id = mp.organization_id
        AND    segment6 = 'FDM';*/
          SELECT COUNT(inventory_item_id)
          INTO   l_count_fdm
          FROM   (SELECT inventory_item_id
                        ,row_number() over(PARTITION BY inventory_item_id ORDER BY inventory_item_id) rn
                  FROM   mtl_item_categories_v mic
                        ,mtl_parameters        mp
                  WHERE  mic.inventory_item_id = p_xx_inventory_item_id
                  AND    mic.organization_id = mp.organization_id
                  AND    segment6 = 'FDM')
          WHERE  rn = 1;
  
  -- Query for get count of the PRODUCT_HIERARCHY.SEGMENT6='POLYJET' items 	
    
      /*  SELECT COUNT(DISTINCT inventory_item_id)
        INTO   l_count_poly
        FROM   mtl_item_categories_v mic
              ,mtl_parameters        mp
        WHERE  mic.inventory_item_id = p_xx_inventory_item_id
        AND    mic.organization_id = mp.organization_id
        AND    segment6 = 'POLYJET';*/
        
        SELECT COUNT(inventory_item_id)
        INTO   l_count_poly
        FROM   (SELECT inventory_item_id
                      ,row_number() over(PARTITION BY inventory_item_id ORDER BY inventory_item_id) rn
                FROM   mtl_item_categories_v mic
                      ,mtl_parameters        mp
                WHERE  mic.inventory_item_id = p_xx_inventory_item_id
                AND    mic.organization_id = mp.organization_id
                AND    segment6 = 'POLYJET')
        WHERE  rn = 1;

    
 -- Query for get count of the PRODUCT_HIERARCHY.SEGMENT1='Materials' items 	
   /*
         SELECT COUNT(DISTINCT inventory_item_id)
         INTO   l_count_mat
         FROM   mtl_item_categories_v mic
               ,mtl_parameters        mp
         WHERE  mic.inventory_item_id = p_xx_inventory_item_id
         AND    mic.organization_id = mp.organization_id
         AND    segment1 = 'Materials';*/
         
          SELECT COUNT(inventory_item_id)
          INTO   l_count_mat
          FROM   (SELECT inventory_item_id
                        ,row_number() over(PARTITION BY inventory_item_id ORDER BY inventory_item_id) rn
                  FROM   mtl_item_categories_v mic
                        ,mtl_parameters        mp
                  WHERE  mic.inventory_item_id = p_xx_inventory_item_id
                  AND    mic.organization_id = mp.organization_id
                  AND    segment1 = 'Materials')
          WHERE  rn = 1;
  
      
  IF l_count_fdm > 0 THEN
     --Query for get Buyer id if the PRODUCT_HIERARCHY.SEGMENT6='FDM' items and org='UME' 
	
          SELECT buyer_id
          INTO   l_buyer_id
          FROM   mtl_parameters     mp
                ,mtl_system_items_b msi
          WHERE  msi.inventory_item_id = p_xx_inventory_item_id
          AND    msi.organization_id = mp.organization_id
          AND    mp.organization_code = 'UME';
     
   --Update Buyer id of the UME org if  PRODUCT_HIERARCHY.SEGMENT6='FDM' 	 
     
          UPDATE xxobjt.xxs3_ptm_mtl_master_items
          SET    legacy_buyer_id = l_buyer_id
          WHERE  l_inventory_item_id = p_xx_inventory_item_id;
            
            COMMIT;
            
   ELSIF  l_count_poly > 0 THEN 
   
       IF  l_count_mat > 0 THEN
	  --  Query for get Buyer id if the  PRODUCT_HIERARCHY.SEGMENT1='Materials' items and org='IRK' 
    
           SELECT buyer_id
           INTO   l_buyer_id
           FROM   mtl_parameters     mp
                 ,mtl_system_items_b msi
           WHERE  msi.inventory_item_id = p_xx_inventory_item_id
           AND    msi.organization_id = mp.organization_id
           AND    mp.organization_code = 'IRK';
       ELSE 
           SELECT buyer_id
           INTO   l_buyer_id
           FROM   mtl_parameters     mp
                 ,mtl_system_items_b msi
           WHERE  msi.inventory_item_id = p_xx_inventory_item_id
           AND    msi.organization_id = mp.organization_id
           AND    mp.organization_code = nvl('IPK', 'IRK');
           
    --Update Buyer id   
            UPDATE xxobjt.xxs3_ptm_mtl_master_items
            SET    legacy_buyer_id = l_buyer_id
            --transform_status='PASS'
            WHERE  l_inventory_item_id = p_xx_inventory_item_id;
            
            COMMIT;
     END IF;     
   ELSE 
     
             SELECT buyer_id
             INTO   l_buyer_id
             FROM   mtl_parameters     mp
                   ,mtl_system_items_b msi
             WHERE  msi.inventory_item_id = p_xx_inventory_item_id
             AND    msi.organization_id = mp.organization_id
             AND    mp.organization_code = nvl('UME', 'IPK');

     -- Update Buyer id
         
            UPDATE xxobjt.xxs3_ptm_mtl_master_items
            SET    legacy_buyer_id = l_buyer_id
            WHERE  l_inventory_item_id = p_xx_inventory_item_id;
            COMMIT;
  END IF;
END IF;
  
EXCEPTION
     WHEN no_data_found THEN
    
	    log_p('Error:No data found in update_buyer_id procedure'||' '||SQLCODE||'-' ||SQLERRM);
   
       WHEN others THEN
          
		  l_error_msg := 'Invalid Buyer ID Found : '||SQLERRM;
		   log_p(l_error_msg);
		  
             UPDATE xxs3_ptm_mtl_master_items
             SET    transform_status = 'FAIL'
                   ,transform_error  = l_error_msg
             WHERE  l_inventory_item_id = p_xx_inventory_item_id;
             
             COMMIT;
	   
END update_buyer_id;
-- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will update Tracking Quantity Ind
  --           staging table XXS3_PTM_MTL_MASTER_ITEMS
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --1.0  17/08/2016   V.V.SATEESH				    Initial build
  -- --------------------------------------------------------------------------------------------
PROCEDURE update_tracking_quantity_ind(p_inventory_item_id IN NUMBER
                                      ,p_primary_uom_code  IN VARCHAR2
                                      ,p_transerr          IN VARCHAR2) IS

l_error_msg VARCHAR2(4000); 

BEGIN

IF p_primary_uom_code IN ('CM','FT','IN','KM','M','MI','MM','YD','G','KG','LBS','TON','L','PT','OZ') THEN
 --Update S3_TRACKING_QUANTITY_IND='PS' if the Primary UOM Code above values
 
            UPDATE xxobjt.xxs3_ptm_mtl_master_items
            SET    s3_tracking_quantity_ind = 'PS'
            WHERE  xx_inventory_item_id = p_inventory_item_id;
           
            COMMIT;
	ELSE
	/* Update S3_TRACKING_QUANTITY_IND='PS' if the Primary UOM Code not in above values*/
             UPDATE xxobjt.xxs3_ptm_mtl_master_items
             SET    s3_tracking_quantity_ind = 'P'
             WHERE  xx_inventory_item_id = p_inventory_item_id;
          
             COMMIT;
 
END IF;

EXCEPTION
   WHEN no_data_found THEN
    
	    log_p('Error:No data found in update_tracking_quantity_ind procedure'||' '||SQLCODE||'-' ||SQLERRM);
   
         WHEN others THEN
    
          l_error_msg := 'Invalid PRIMARY_UOM_CODE for TRACKING_QUANTITY_IND : '||SQLERRM;
		  
		      log_p(l_error_msg);

          UPDATE xxobjt.xxs3_ptm_mtl_master_items
          SET    transform_status = 'FAIL'
                ,transform_error  = p_transerr || ',' || l_error_msg
          WHERE  xx_inventory_item_id = p_inventory_item_id;
          
		COMMIT;  
    
END update_tracking_quantity_ind;

 -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will update UPDATE_SECONDARY_DEFAULT_IND value
  --           staging table XXS3_PTM_MTL_MASTER_ITEMS
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  17/08/2016   V.V.SATEESH				    Initial build
  -- --------------------------------------------------------------------------------------------
PROCEDURE update_secondary_default_ind(p_inventory_item_id  IN NUMBER
                                      ,p_primary_uom_code   IN VARCHAR2
                                      ,p_transerr           IN VARCHAR2) IS
l_error_msg VARCHAR2(4000);

BEGIN

IF p_primary_uom_code IN ('CM','FT','IN','KM','M','MI','MM','YD','G','KG','LBS','TON','L','PT','OZ') THEN
-- Update S3_SECONDARY_DEFAULT_IND='D' if the Primary UOM Code above values
          
          UPDATE xxobjt.xxs3_ptm_mtl_master_items
          SET    s3_secondary_default_ind = 'D'
          WHERE  xx_inventory_item_id = p_inventory_item_id;
    
	        COMMIT;
  
	ELSE
		 --Update S3_SECONDARY_DEFAULT_IND='NULL' if the Primary UOM Code not in above values
		
           UPDATE xxobjt.xxs3_ptm_mtl_master_items
           SET    s3_secondary_default_ind = NULL
           WHERE  xx_inventory_item_id = p_inventory_item_id;
           
           COMMIT;
END IF;
EXCEPTION
WHEN no_data_found THEN
    
	    log_p('Error:No data found in update_secondary_default_ind procedure'||' '||SQLCODE||'-' ||SQLERRM);
   
         WHEN others THEN
  
          l_error_msg := 'Invalid PRIMARY_UOM_CODE for TRACKING_QUANTITY_IND : '||SQLERRM;
          
          log_p(l_error_msg);
        
        UPDATE xxobjt.xxs3_ptm_mtl_master_items
        SET    transform_status = 'FAIL'
              ,transform_error  = p_transerr || ',' || l_error_msg
        WHERE  xx_inventory_item_id = p_inventory_item_id;
        
		   COMMIT;
       
END update_secondary_default_ind; 

-- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will update UPDATE_ONT_PRICING_QTY_SOURCE value
  --           staging table XXS3_PTM_MTL_MASTER_ITEMS
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  17/08/2016   V.V.SATEESH				    Initial build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE update_ont_pricing_qty_source(p_inventory_item_id        IN NUMBER,
                                          p_s3_tracking_quantity_ind IN VARCHAR2,
                                          p_transerr                 IN VARCHAR2) IS
    l_error_msg VARCHAR2(4000);
  BEGIN
    
    IF p_s3_tracking_quantity_ind = 'PS' THEN
    -- update the 'ont_pricing_qty_source' with 'P' when s3_tracking_quantity_ind is "PS"                   
            UPDATE xxobjt.xxs3_ptm_mtl_master_items
            SET    s3_ont_pricing_qty_source = 'P'
            WHERE  xx_inventory_item_id = p_inventory_item_id;
            
            COMMIT;
    END IF;
    
  EXCEPTION
  
    WHEN no_data_found THEN
    
	    log_p('Error:No data found in update_ont_pricing_qty_source procedure'||' '||SQLCODE||'-' ||SQLERRM);
   
    WHEN others THEN
    
	l_error_msg := 'Invalid PRIMARY_UOM_CODE for ONT_PRICING_QTY_SOURCE : ' ||SQLERRM;
	
     log_p(l_error_msg);
	 
      UPDATE xxobjt.xxs3_ptm_mtl_master_items
      SET    transform_status = 'FAIL'
            ,transform_error  = p_transerr || ',' || l_error_msg
      WHERE  xx_inventory_item_id = p_inventory_item_id;
      
      COMMIT;
      
  END update_ont_pricing_qty_source;

    -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all org rules for  based on PRODUCT_HIERARCHY
  --           staging table XXS3_PTM_MTL_MASTER_ITEMS
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date         Name                          Description
  -- 1.0  17/08/2016   V.V.SATEESH				    Initial build
  -- --------------------------------------------------------------------------------------------

PROCEDURE org_rules_items(p_inventory_item_id IN NUMBER
                         ,p_organization_code IN VARCHAR2) IS
	 
	 
	 l_count_ume NUMBER;
	 l_count_use NUMBER;
  
  BEGIN
      
     IF p_organization_code = 'UME' THEN
    --Query to get the count of items if the PRODUCT_HIERARCHY.segment6='POLYJET'  for UME
    
             SELECT COUNT(*)
             INTO   l_count_ume
             FROM   mtl_item_categories_v mic
                   ,mtl_parameters        mp
             WHERE  mic.inventory_item_id = p_inventory_item_id
             AND    mic.organization_id = mp.organization_id
             AND    segment6 = 'POLYJET'
             AND    organization_code = 'UME'
                   --- AND    mic.inventory_item_id NOT IN
             AND    NOT EXISTS
              (SELECT mtt.inventory_item_id
                     FROM   mtl_material_transactions mtt
                     WHERE  mtt.inventory_item_id = mic.inventory_item_id);
								  
    END IF;

   IF  p_organization_code = 'USE' THEN
-- Query to get the count of items if the PRODUCT_HIERARCHY.segment6='POLYJET'  for USE

              SELECT COUNT(*)
              INTO   l_count_use
              FROM   mtl_item_categories_v mic
                    ,mtl_parameters        mp
              WHERE  mic.inventory_item_id = p_inventory_item_id
              AND    mic.organization_id = mp.organization_id
              AND    segment6 = 'POLYJET'
              AND    organization_code = 'USE'
                    -- AND mic.inventory_item_id NOT IN
              AND    NOT EXISTS
               (SELECT mtt.inventory_item_id
                      FROM   mtl_material_transactions mtt
                      WHERE  mtt.inventory_item_id = mic.inventory_item_id);
END IF;		
  
   IF l_count_ume > 0 AND p_organization_code = 'UME' THEN

 -- Avoid the Items if satisify the above condition in the stage table
    log_p('UME org rule'||p_inventory_item_id);

          DELETE FROM xxobjt.xxs3_ptm_mtl_master_items
          WHERE  l_inventory_item_id = p_inventory_item_id
          AND    legacy_organization_code = 'UME';
          
          COMMIT;
    END IF;	

IF l_count_use > 0 AND p_organization_code='USE' THEN
 --Avoid the Items if satisify the above condition in the stage table
 
         log_p('USE org rule'||p_inventory_item_id);

          DELETE FROM xxobjt.xxs3_ptm_mtl_master_items
          WHERE  l_inventory_item_id = p_inventory_item_id
          AND    legacy_organization_code = 'USE';
          
          COMMIT;
END IF;	
EXCEPTION
 WHEN no_data_found THEN
	  log_p('Error: No Data Found in org_rules_items Procedure '||' '||SQLCODE||'-' ||SQLERRM);
    
  WHEN others THEN
		  log_p('Error in the "Org_rules_items" Procedure'||SQLERRM);

END	org_rules_items  ;
  
  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will update attribute25
  --           staging table XXS3_PTM_MTL_MASTER_ITEMS
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  17/08/2016   V.V.SATEESH				    Initial build
  -- --------------------------------------------------------------------------------------------
PROCEDURE update_attribute25(p_inventory_item_id IN NUMBER
                             ,p_attribute25      IN VARCHAR2) is

 BEGIN

    IF p_attribute25 = '0' THEN
        --Update the S3 Attribute25 Value 
        
        UPDATE xxobjt.xxs3_ptm_mtl_master_items
        SET    s3_attribute25 = 'Y'
        WHERE  xx_inventory_item_id = p_inventory_item_id;
    
    ELSE
    --Update the S3 Attribute25 Value 
    
        UPDATE xxobjt.xxs3_ptm_mtl_master_items
        SET    s3_attribute25 = 'N'
        WHERE  xx_inventory_item_id = p_inventory_item_id;
    END IF;
   COMMIT;
    EXCEPTION
    WHEN no_data_found THEN
	  log_p('Error: No Data Found in org_rules_items Procedure '||' '||SQLCODE||'-' ||SQLERRM);
    
    UPDATE xxs3_ptm_mtl_master_items
    SET    transform_error  = 'ATTRIBUTE 25 VALUE FAIL'
          ,transform_status = 'FAIL'
    WHERE  xx_inventory_item_id = p_inventory_item_id;
  
  
  WHEN others THEN
    log_p('Error in the "update_attribute25" Procedure'||' '||SQLCODE||'-'||SQLERRM);
    
     UPDATE xxs3_ptm_mtl_master_items
    SET    transform_error  = 'ATTRIBUTE 25 VALUE FAIL'
          ,transform_status = 'FAIL'
    WHERE  xx_inventory_item_id = p_inventory_item_id;    
    
END update_attribute25;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will work for the BOM Explosion API,Assembly item Components and it's item details will
  --  insert into staging table XXS3_PTM_BOM_ITEM_EXPL_TEMP
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date         Name                          Description
  -- 1.0  17/08/2016   V.V.SATEESH				    Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE prc_s3_item_bom_explode IS
    l_group_id       NUMBER;
    l_error_message  VARCHAR2(2000);
    l_error_code     NUMBER;
    l_sess_id        NUMBER;
    l_rec_count      NUMBER;
    
     --Cursor for the BOM Explosion Procedure 
  
   /* CURSOR c_bom IS
      SELECT DISTINCT l_inventory_item_id, legacy_organization_id
      FROM xxobjt.xxs3_ptm_mtl_master_items; */
	  
	CURSOR c_bom IS  
          SELECT xpm.l_inventory_item_id
                ,xpm.legacy_organization_id
          FROM   bom_bill_of_materials     bbm
                ,xxs3_ptm_mtl_master_items xpm
          WHERE  bbm.assembly_item_id = xpm.l_inventory_item_id
          AND    bbm.organization_id = xpm.legacy_organization_id;
  
  BEGIN
  
    BEGIN
           log_p('Item BOM Explode Procedure');
          --  query for get the API Parameters 
        FOR i IN c_bom loop 
        
        SELECT bom_explosion_temp_s.NEXTVAL INTO l_group_id FROM dual;
      
        SELECT bom_explosion_temp_session_s.NEXTVAL INTO l_sess_id FROM dual;
    	
    	 --API used for the BOM Explosion for the given item 
      
        bompxinq.exploder_userexit(Verify_Flag       => 0,
                                   Org_Id            => i.legacy_organization_id,--p_org_id,
                                   Order_By          => 1, --:B_Bill_Of_Matls.Bom_Bill_Sort_Order_Type,
                                   Grp_Id            => l_group_id,
                                   Session_Id        => 0,
                                   Levels_To_Explode => 20, --:B_Bill_Of_Matls.Levels_To_Explode,
                                   Bom_Or_Eng        => 1, -- :Parameter.Bom_Or_Eng,
                                   Impl_Flag         => 1, --:B_Bill_Of_Matls.Impl_Only,
                                   Plan_Factor_Flag  => 2, --:B_Bill_Of_Matls.Planning_Percent,
                                   Explode_Option    => 3, --:B_Bill_Of_Matls.Bom_Inquiry_Display_Type,
                                   Module            => 2, --:B_Bill_Of_Matls.Costs,
                                   Cst_Type_Id       => 0, --:B_Bill_Of_Matls.Cost_Type_Id,
                                   Std_Comp_Flag     => 2,
                                   Expl_Qty          => 1, --:B_Bill_Of_Matls.Explosion_Quantity,
                                   Item_Id           => i.l_inventory_item_id,--p_item_id, --:B_Bill_Of_Matls.Assembly_Item_Id,
                                   Alt_Desg          => null, --:B_Bill_Of_Matls.Alternate_Bom_Designator,
                                   Comp_Code         => null,
                                   Unit_Number_From  => 0, --NVL(:B_Bill_Of_Matls.Unit_Number_From, :CONTEXT.UNIT_NUMBER_FROM),
                                   Unit_Number_To    => 'ZZZZZZZZZZZZZZZZZ', --NVL(:B_Bill_Of_Matls.Unit_Number_To, :CONTEXT.UNIT_NUMBER_TO), 
                                   Rev_Date          => sysdate, --:B_Bill_Of_Matls.Disp_Date,
                                   Show_Rev          => 1, -- yes
                                   Material_Ctrl     => 2, --:B_Bill_Of_Matls.Material_Control,
                                   Lead_Time         => 2, --:B_Bill_Of_Matls.Lead_Time,
                                   err_msg           => l_error_message, --err_msg
                                   error_code        => l_error_code); --error_code
      
       
        --Count of the Bom Explosion Records for group id 
       
           SELECT COUNT(*)
           INTO   l_rec_count
           FROM   xxobjt.xxs3_ptm_bom_item_expl_temp temp
           WHERE  temp.group_id = l_group_id;
      
       /* Insert the Records into custom table(XXS3_PTM_BOM_ITEM_EXPL_TEMP) from the Oracle Temp table (BOM_SMALL_EXPL_TEMP) */
       
          INSERT INTO xxobjt.xxs3_ptm_bom_item_expl_temp
            SELECT *
            FROM   bom_small_expl_temp
            WHERE  top_item_id = i.l_inventory_item_id;
       
      /* Get the Distinct Component details from the Custom table and insert into the stage table */
      
            INSERT INTO xxobjt.xxs3_ptm_bom_cmpnt_item_stg
             /* SELECT DISTINCT component_item_id
                             ,assembly_item_id
                             ,top_item_id
                             ,organization_id
                             ,plan_level
              FROM   xxobjt.xxs3_ptm_bom_item_expl_temp
              WHERE  top_item_id = i.l_inventory_item_id;*/ 
          SELECT component_item_id
                ,assembly_item_id
                ,top_item_id
                ,organization_id
                ,plan_level
          FROM   (SELECT component_item_id
                        ,assembly_item_id
                        ,top_item_id
                        ,organization_id
                        ,plan_level
                        ,row_number() over(PARTITION BY component_item_id, assembly_item_id, top_item_id, organization_id, plan_level 
                        ORDER BY component_item_id, assembly_item_id, top_item_id, organization_id, plan_level) rn
                  FROM   xxobjt.xxs3_ptm_bom_item_expl_temp xpbi
                  WHERE  top_item_id = i.l_inventory_item_id)
          WHERE  rn = 1;
      	
       --Print Log messages
        
        log_p(l_error_message);
        log_p(l_error_code);
        log_p('ITEM_ID = ' || i.l_inventory_item_id);
        log_p('grp_id = ' || l_group_id);
        log_p('sess_id = ' || l_sess_id);
    	  log_p('l_rec_count = ' || l_rec_count);
      
      END LOOP;
      COMMIT;
      EXCEPTION
        WHEN no_data_found THEN
          log_p('Error in "prc_s3_item_bom_explode" Procedure'||SQLERRM);
           
      END;
  EXCEPTION
    WHEN others THEN
      log_p('Error in "prc_s3_item_bom_explode" Procedure'||SQLERRM);
      
  END prc_s3_item_bom_explode;

   -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required Master and Child Items Attributes and insert into
  --           staging table XXS3_PTM_MTL_MASTER_ITEMS
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  17/08/2016   V.V.SATEESH				    Initial build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE master_item_extract_data(x_errbuf  OUT VARCHAR2,
                                     x_retcode OUT NUMBER,
                                     p_organization_code IN VARCHAR2) IS
   
	
	 --Variables Delaration
  
    l_status_message         VARCHAR2(4000);
    l_s3_gl_string 	         VARCHAR2(2000);
    l_output                 VARCHAR2(4000);
    l_output_code            VARCHAR2(100);
    l_output_coa_update      VARCHAR2(4000);
    l_output_code_coa_update VARCHAR2(100);
	  l_step                   VARCHAR2(50) ;
    l_Err_Count              NUMBER;
    l_count_item              NUMBER;


    --Cursor for Extract Master Items 
    
CURSOR c_master_items_extract IS
    
/*SELECT item_cur.*
      ,mir.revision_id
      ,mir.revision
      ,mir.revision_label
      ,mir.description revision_description
      ,mir.effectivity_date
      ,mir.implementation_date
      ,mir.ecn_initiation_date
      ,mir.change_notice
      ,mir.attribute10 r_attribute10
      ,mir.revised_item_sequence_id
      ,mirt.revision_id tl_revision_id
      ,mirt.LANGUAGE LANGUAGE
      ,mirt.source_lang
      ,mirt.description tl_description
FROM   (SELECT  msi.inventory_item_id
                       ,msi.inventory_item_id l_inventory_item_id
                       ,msi.description
                       ,msi.buyer_id
                       ,(SELECT NAME
                         FROM   ra_rules rr
                         WHERE  msi.accounting_rule_id = rr.rule_id) accounting_rule_name
                       ,msi.segment1
                       ,msi.attribute2
                       ,(SELECT  msib.segment1
                         FROM   mtl_system_items_b           msib
                               ,hr_all_organization_units_tl hou
                         WHERE  hou.LANGUAGE = 'US'
                         AND    hou.NAME LIKE 'OMA%'
                         AND    msib.organization_id = hou.organization_id
                         AND    (msib.end_date_active IS NULL OR
                               msib.end_date_active < SYSDATE)
                         AND    msib.inventory_item_id = msi.attribute9
                         AND ROWNUM<2) attribute9
                       ,msi.attribute11
                       ,msi.attribute12
                       ,msi.attribute13
                       ,msi.purchasing_item_flag
                       ,msi.shippable_item_flag
                       ,msi.customer_order_flag
                       ,msi.internal_order_flag
                       ,msi.service_item_flag
                       ,msi.inventory_item_flag
                       ,msi.inventory_asset_flag
                       ,msi.purchasing_enabled_flag
                       ,msi.customer_order_enabled_flag
                       ,msi.internal_order_enabled_flag
                       ,msi.so_transactions_flag
                       ,msi.mtl_transactions_enabled_flag
                       ,msi.stock_enabled_flag
                       ,msi.bom_enabled_flag
                       ,msi.build_in_wip_flag
                       ,msi.item_catalog_group_id
                       ,msi.catalog_status_flag
                       ,msi.returnable_flag
                       ,msi.default_shipping_org
                       ,msi.collateral_flag
                       ,msi.taxable_flag
                       ,msi.allow_item_desc_update_flag
                       ,msi.inspection_required_flag
                       ,msi.receipt_required_flag
                       ,msi.qty_rcv_tolerance
                       ,msi.list_price_per_unit
                       ,msi.asset_category_id
                       ,msi.unit_of_issue
                       ,msi.allow_substitute_receipts_flag
                       ,msi.allow_unordered_receipts_flag
                       ,msi.allow_express_delivery_flag
                       ,msi.days_early_receipt_allowed
                       ,msi.days_late_receipt_allowed
                       ,msi.receipt_days_exception_code
                       ,msi.receiving_routing_id
                       ,msi.auto_lot_alpha_prefix
                       ,msi.start_auto_lot_number
                       ,msi.lot_control_code
                       ,msi.shelf_life_code
                       ,msi.shelf_life_days
                       ,msi.serial_number_control_code
                       ,msi.source_type
                       ,msi.source_subinventory
                       ,msi.expense_account
                       ,msi.restrict_subinventories_code
                       ,msi.organization_id
                       ,(SELECT organization_code
                         FROM   mtl_parameters
                         WHERE  organization_id = msi.organization_id) organization_code
                       ,msi.source_organization_id
                       ,(SELECT organization_code
                         FROM   mtl_parameters
                         WHERE  organization_id = msi.source_organization_id) source_organization_code
                       ,msi.unit_weight
                       ,msi.weight_uom_code
                       ,msi.volume_uom_code
                       ,msi.unit_volume
                       ,msi.shrinkage_rate
                       ,msi.acceptable_early_days
                       ,msi.planning_time_fence_code
                       ,msi.lead_time_lot_size
                       ,msi.std_lot_size
                       ,msi.overrun_percentage
                       ,msi.mrp_calculate_atp_flag
                       ,msi.acceptable_rate_increase
                       ,msi.acceptable_rate_decrease
                       ,msi.planning_time_fence_days
                       ,msi.end_assembly_pegging_flag
                       ,msi.bom_item_type
                       ,msi.pick_components_flag
                       ,msi.replenish_to_order_flag
                       ,msi.atp_components_flag
                       ,msi.atp_flag
                       ,msi.wip_supply_type
                       ,msi.wip_supply_subinventory
                       ,msi.primary_uom_code
                       ,msi.primary_unit_of_measure
                       ,msi.allowed_units_lookup_code
                       ,msi.cost_of_sales_account
                       ,msi.sales_account
                       ,msi.default_include_in_rollup_flag
                       ,msi.inventory_item_status_code
                       ,msi.inventory_planning_code
                       ,msi.planner_code
                       ,msi.planning_make_buy_code
                       ,msi.fixed_lot_multiplier
                       ,msi.rounding_control_type
                       ,msi.postprocessing_lead_time
                       ,msi.preprocessing_lead_time
                       ,msi.full_lead_time
                       ,msi.mrp_safety_stock_percent
                       ,msi.mrp_safety_stock_code
                       ,msi.min_minmax_quantity
                       ,msi.max_minmax_quantity
                       ,msi.minimum_order_quantity
                       ,msi.fixed_order_quantity
                       ,msi.fixed_days_supply
                       ,msi.maximum_order_quantity
                       ,msi.creation_date
                       ,(SELECT rule_name
                         FROM   mtl_atp_rules mat
                         WHERE  msi.atp_rule_id = mat.rule_id) atp_rule_name
                       ,msi.reservable_type
                       ,msi.vendor_warranty_flag
                       ,msi.serviceable_product_flag
                       ,msi.material_billable_flag
                       ,msi.prorate_service_flag
                       ,msi.invoiceable_item_flag
                       ,msi.invoice_enabled_flag
                       ,msi.outside_operation_flag
                       ,msi.outside_operation_uom_type
                       ,msi.safety_stock_bucket_days
                       ,msi.costing_enabled_flag
                       ,msi.cycle_count_enabled_flag
                       ,msi.item_type
                       ,msi.ship_model_complete_flag
                       ,msi.mrp_planning_code
                       ,msi.ato_forecast_control
                       ,msi.release_time_fence_code
                       ,msi.release_time_fence_days
                       ,msi.container_item_flag
                       ,msi.vehicle_item_flag
                       ,msi.effectivity_control
                       ,msi.event_flag
                       ,msi.electronic_flag
                       ,msi.downloadable_flag
                       ,msi.comms_nl_trackable_flag
                       ,msi.orderable_on_web_flag
                       ,msi.web_status
                       ,msi.dimension_uom_code
                       ,msi.unit_length
                       ,msi.unit_width
                       ,msi.unit_height
                       ,msi.dual_uom_control
                       ,msi.dual_uom_deviation_high
                       ,msi.dual_uom_deviation_low
                       ,msi.contract_item_type_code
                       ,msi.serv_req_enabled_code
                       ,msi.serv_billing_enabled_flag
                       ,msi.default_so_source_type
                       ,msi.object_version_number
                       ,msi.tracking_quantity_ind
                       ,msi.secondary_default_ind
                       ,msi.so_authorization_flag
                       ,msi.attribute17
                       ,msi.attribute18
                       ,msi.attribute19
                       ,msi.attribute25
                       ,msi.expiration_action_code
                       ,msi.expiration_action_interval
                       ,msi.hazardous_material_flag
                       ,msi.recipe_enabled_flag
                       ,msi.retest_interval
                       ,msi.repair_leadtime
                       ,msi.gdsn_outbound_enabled_flag
                       ,msi.revision_qty_control_code
                       ,msi.start_auto_serial_number
                       ,msi.auto_serial_alpha_prefix
                       ,(SELECT concatenated_segments
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) legacy_expense_account
                       ,(SELECT concatenated_segments
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) legacy_cost_of_sales_account
                       ,(SELECT concatenated_segments
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) legacy_sales_account
                       ,
                        
                        (SELECT segment1
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment1
                       ,(SELECT segment2
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment2
                       ,
                        
                        (SELECT segment3
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment3
                       ,
                        
                        (SELECT segment4
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment4
                       ,
                        
                        (SELECT segment5
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment5
                       ,
                        
                        (SELECT segment6
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment6
                       ,
                        
                        (SELECT segment7
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment7
                       ,
                        
                        (SELECT segment8
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment8
                       ,(SELECT segment9
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment9
                       ,(SELECT segment10
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment10
                       ,
                        
                        (SELECT segment1
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment1
                       ,
                        
                        (SELECT segment2
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment2
                       ,
                        
                        (SELECT segment3
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment3
                       ,
                        
                        (SELECT segment4
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment4
                       ,
                        
                        (SELECT segment5
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment5
                       ,
                        
                        (SELECT segment6
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment6
                       ,
                        
                        (SELECT segment7
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment7
                       ,
                        
                        (SELECT segment8
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment8
                       ,(SELECT segment9
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment9
                       ,(SELECT segment10
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment10
                       ,
                        
                        (SELECT segment1
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment1
                       ,(SELECT segment2
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment2
                       ,
                        
                        (SELECT segment3
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment3
                       ,
                        
                        (SELECT segment4
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment4
                       ,
                        
                        (SELECT segment5
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment5
                       ,
                        
                        (SELECT segment6
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment6
                       ,
                        
                        (SELECT segment7
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment7
                       ,
                        
                        (SELECT segment8
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment8
                       ,(SELECT segment9
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment9
                       ,(SELECT segment10
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment10
        
        FROM   mtl_system_items_b msi
        WHERE  \*EXISTS
               (SELECT mtt.inventory_item_id --Condition for Inventory Transactons in Past Two Years
                FROM   mtl_material_transactions mtt
                WHERE  mtt.inventory_item_id = msi.inventory_item_id
                AND    msi.inventory_item_flag = 'Y'
                AND    mtt.creation_date > SYSDATE - 730 
                union
                 SELECT ool.inventory_item_id --Condition for  Sales Orders Items in Past Two Years
                 FROM   oe_order_lines_all ool
                 WHERE  ool.inventory_item_id = msi.inventory_item_id
                 AND    ool.creation_date > SYSDATE - 730 
                 union
                 SELECT mmt.inventory_item_id --Extract items with current On Hand Quantity
                 FROM   mtl_onhand_quantities mmt
                 WHERE  mmt.inventory_item_id = msi.inventory_item_id)*\
                 EXISTS
                         (select mtt.inventory_item_id
                        from mtl_material_transactions mtt
                       where mtt.inventory_item_id = msi.inventory_item_id
                         and msi.inventory_item_flag = 'Y'
                         and mtt.creation_date > sysdate - 730)
                  OR (EXISTS
                     (select ool.inventory_item_id
                         from oe_order_lines_all ool
                        where ool.inventory_item_id = msi.inventory_item_id
                          and ool.creation_date > sysdate - 730))
                  OR (EXISTS
                     (select mmt.inventory_item_id
                         from mtl_onhand_quantities mmt
                        where mmt.inventory_item_id = msi.inventory_item_id))
              
        OR     (msi.inventory_item_status_code = 'Active PTO') --Extract items with Item Status "Active PTO"
        OR     (msi.inventory_item_status_code IN
              ('XX_BETA', 'Inactive', 'Active', 'XX_PROD') AND
              msi.segment1 LIKE '%-CS')  --Items like -CS and item status code
        OR     (msi.inventory_item_status_code IN
              ('XX_BETA', 'Inactive', 'Active', 'XX_PROD') AND
              msi.segment1 LIKE '%-S')  --Items like -S and item status code
        OR     (msi.creation_date > SYSDATE - 365)  --Extract items created in the past year 
        OR     (msi.item_type = 'PTO') --If Item Type for Item contains "PTO"
        OR     (msi.inventory_item_status_code IN
              ('Obsolete', 'XX_DISCOUNT') AND
              msi.comms_nl_trackable_flag IS NOT NULL) --Items-Install Base-Trackable,Item Status of either "Obsolete" or "XX_DISCOUNT" 
        
        ) item_cur
      ,mtl_item_revisions_b mir
      ,mtl_item_revisions_tl mirt
WHERE  organization_code = p_organization_code ----IN('OMA','UME','USB','USE','UTP');
AND    mir.inventory_item_id = item_cur.inventory_item_id
AND    mir.organization_id = item_cur.organization_id
AND    mirt.inventory_item_id = item_cur.inventory_item_id
AND    mirt.organization_id = item_cur.organization_id
AND    mirt.LANGUAGE = 'US'
AND    mirt.source_lang = 'US'
AND    mirt.revision_id = mir.revision_id;*/

SELECT item_cur.*
      ,mir.revision_id
      ,mir.revision
      ,mir.revision_label
      ,mir.description revision_description
      ,mir.effectivity_date
      ,mir.implementation_date
      ,mir.ecn_initiation_date
      ,mir.change_notice
      ,mir.attribute10 r_attribute10
      ,mir.revised_item_sequence_id
      ,mirt.revision_id tl_revision_id
      ,mirt.LANGUAGE LANGUAGE
      ,mirt.source_lang
      ,mirt.description tl_description
FROM  (SELECT  msi.inventory_item_id
                       ,msi.inventory_item_id l_inventory_item_id
                       ,msi.description
                       ,msi.buyer_id
                       ,(SELECT NAME
                         FROM   ra_rules rr
                         WHERE  msi.accounting_rule_id = rr.rule_id) accounting_rule_name
                       ,msi.segment1
                       ,msi.attribute2
                       ,(SELECT  msib.segment1
                         FROM   mtl_system_items_b           msib
                               ,hr_all_organization_units_tl hou
                         WHERE  hou.LANGUAGE = 'US'
                         AND    hou.NAME LIKE 'OMA%'
                         AND    msib.organization_id = hou.organization_id
                         AND    (msib.end_date_active IS NULL OR
                               msib.end_date_active < SYSDATE)
                         AND    msib.inventory_item_id = msi.attribute9
                         AND ROWNUM<2) attribute9
                       ,msi.attribute11
                       ,msi.attribute12
                       ,msi.attribute13
                       ,msi.purchasing_item_flag
                       ,msi.shippable_item_flag
                       ,msi.customer_order_flag
                       ,msi.internal_order_flag
                       ,msi.service_item_flag
                       ,msi.inventory_item_flag
                       ,msi.inventory_asset_flag
                       ,msi.purchasing_enabled_flag
                       ,msi.customer_order_enabled_flag
                       ,msi.internal_order_enabled_flag
                       ,msi.so_transactions_flag
                       ,msi.mtl_transactions_enabled_flag
                       ,msi.stock_enabled_flag
                       ,msi.bom_enabled_flag
                       ,msi.build_in_wip_flag
                       ,msi.item_catalog_group_id
                       ,msi.catalog_status_flag
                       ,msi.returnable_flag
                       ,msi.default_shipping_org
                       ,msi.collateral_flag
                       ,msi.taxable_flag
                       ,msi.allow_item_desc_update_flag
                       ,msi.inspection_required_flag
                       ,msi.receipt_required_flag
                       ,msi.qty_rcv_tolerance
                       ,msi.list_price_per_unit
                       ,msi.asset_category_id
                       ,msi.unit_of_issue
                       ,msi.allow_substitute_receipts_flag
                       ,msi.allow_unordered_receipts_flag
                       ,msi.allow_express_delivery_flag
                       ,msi.days_early_receipt_allowed
                       ,msi.days_late_receipt_allowed
                       ,msi.receipt_days_exception_code
                       ,msi.receiving_routing_id
                       ,msi.auto_lot_alpha_prefix
                       ,msi.start_auto_lot_number
                       ,msi.lot_control_code
                       ,msi.shelf_life_code
                       ,msi.shelf_life_days
                       ,msi.serial_number_control_code
                       ,msi.source_type
                       ,msi.source_subinventory
                       ,msi.expense_account
                       ,msi.restrict_subinventories_code
                       ,msi.organization_id
                       ,(SELECT organization_code
                         FROM   mtl_parameters
                         WHERE  organization_id = msi.organization_id) organization_code
                       ,msi.source_organization_id
                       ,(SELECT organization_code
                         FROM   mtl_parameters
                         WHERE  organization_id = msi.source_organization_id) source_organization_code
                       ,msi.unit_weight
                       ,msi.weight_uom_code
                       ,msi.volume_uom_code
                       ,msi.unit_volume
                       ,msi.shrinkage_rate
                       ,msi.acceptable_early_days
                       ,msi.planning_time_fence_code
                       ,msi.lead_time_lot_size
                       ,msi.std_lot_size
                       ,msi.overrun_percentage
                       ,msi.mrp_calculate_atp_flag
                       ,msi.acceptable_rate_increase
                       ,msi.acceptable_rate_decrease
                       ,msi.planning_time_fence_days
                       ,msi.end_assembly_pegging_flag
                       ,msi.bom_item_type
                       ,msi.pick_components_flag
                       ,msi.replenish_to_order_flag
                       ,msi.atp_components_flag
                       ,msi.atp_flag
                       ,msi.wip_supply_type
                       ,msi.wip_supply_subinventory
                       ,msi.primary_uom_code
                       ,msi.primary_unit_of_measure
                       ,msi.allowed_units_lookup_code
                       ,msi.cost_of_sales_account
                       ,msi.sales_account
                       ,msi.default_include_in_rollup_flag
                       ,msi.inventory_item_status_code
                       ,msi.inventory_planning_code
                       ,msi.planner_code
                       ,msi.planning_make_buy_code
                       ,msi.fixed_lot_multiplier
                       ,msi.rounding_control_type
                       ,msi.postprocessing_lead_time
                       ,msi.preprocessing_lead_time
                       ,msi.full_lead_time
                       ,msi.mrp_safety_stock_percent
                       ,msi.mrp_safety_stock_code
                       ,msi.min_minmax_quantity
                       ,msi.max_minmax_quantity
                       ,msi.minimum_order_quantity
                       ,msi.fixed_order_quantity
                       ,msi.fixed_days_supply
                       ,msi.maximum_order_quantity
                       ,msi.creation_date
                       ,(SELECT rule_name
                         FROM   mtl_atp_rules mat
                         WHERE  msi.atp_rule_id = mat.rule_id) atp_rule_name
                       ,msi.reservable_type
                       ,msi.vendor_warranty_flag
                       ,msi.serviceable_product_flag
                       ,msi.material_billable_flag
                       ,msi.prorate_service_flag
                       ,msi.invoiceable_item_flag
                       ,msi.invoice_enabled_flag
                       ,msi.outside_operation_flag
                       ,msi.outside_operation_uom_type
                       ,msi.safety_stock_bucket_days
                       ,msi.costing_enabled_flag
                       ,msi.cycle_count_enabled_flag
                       ,msi.item_type
                       ,msi.ship_model_complete_flag
                       ,msi.mrp_planning_code
                       ,msi.ato_forecast_control
                       ,msi.release_time_fence_code
                       ,msi.release_time_fence_days
                       ,msi.container_item_flag
                       ,msi.vehicle_item_flag
                       ,msi.effectivity_control
                       ,msi.event_flag
                       ,msi.electronic_flag
                       ,msi.downloadable_flag
                       ,msi.comms_nl_trackable_flag
                       ,msi.orderable_on_web_flag
                       ,msi.web_status
                       ,msi.dimension_uom_code
                       ,msi.unit_length
                       ,msi.unit_width
                       ,msi.unit_height
                       ,msi.dual_uom_control
                       ,msi.dual_uom_deviation_high
                       ,msi.dual_uom_deviation_low
                       ,msi.contract_item_type_code
                       ,msi.serv_req_enabled_code
                       ,msi.serv_billing_enabled_flag
                       ,msi.default_so_source_type
                       ,msi.object_version_number
                       ,msi.tracking_quantity_ind
                       ,msi.secondary_default_ind
                       ,msi.so_authorization_flag
                       ,msi.attribute17
                       ,msi.attribute18
                       ,msi.attribute19
                       ,msi.attribute25
                       ,msi.expiration_action_code
                       ,msi.expiration_action_interval
                       ,msi.hazardous_material_flag
                       ,msi.recipe_enabled_flag
                       ,msi.retest_interval
                       ,msi.repair_leadtime
                       ,msi.gdsn_outbound_enabled_flag
                       ,msi.revision_qty_control_code
                       ,msi.start_auto_serial_number
                       ,msi.auto_serial_alpha_prefix
                       ,(SELECT concatenated_segments
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) legacy_expense_account
                       ,(SELECT concatenated_segments
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) legacy_cost_of_sales_account
                       ,(SELECT concatenated_segments
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) legacy_sales_account
                       ,
                        
                        (SELECT segment1
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment1
                       ,(SELECT segment2
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment2
                       ,
                        
                        (SELECT segment3
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment3
                       ,
                        
                        (SELECT segment4
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment4
                       ,
                        
                        (SELECT segment5
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment5
                       ,
                        
                        (SELECT segment6
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment6
                       ,
                        
                        (SELECT segment7
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment7
                       ,
                        
                        (SELECT segment8
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment8
                       ,(SELECT segment9
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment9
                       ,(SELECT segment10
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment10
                       ,
                        
                        (SELECT segment1
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment1
                       ,
                        
                        (SELECT segment2
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment2
                       ,
                        
                        (SELECT segment3
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment3
                       ,
                        
                        (SELECT segment4
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment4
                       ,
                        
                        (SELECT segment5
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment5
                       ,
                        
                        (SELECT segment6
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment6
                       ,
                        
                        (SELECT segment7
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment7
                       ,
                        
                        (SELECT segment8
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment8
                       ,(SELECT segment9
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment9
                       ,(SELECT segment10
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment10
                       ,
                        
                        (SELECT segment1
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment1
                       ,(SELECT segment2
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment2
                       ,
                        
                        (SELECT segment3
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment3
                       ,
                        
                        (SELECT segment4
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment4
                       ,
                        
                        (SELECT segment5
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment5
                       ,
                        
                        (SELECT segment6
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment6
                       ,
                        
                        (SELECT segment7
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment7
                       ,
                        
                        (SELECT segment8
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment8
                       ,(SELECT segment9
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment9
                       ,(SELECT segment10
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment10
from  mtl_system_items_b  msi
where  EXISTS (select mtt.inventory_item_id
                                  from mtl_material_transactions mtt
                                  where mtt.inventory_item_id = msi.inventory_item_id
                                  and   mtt.creation_date >sysdate -730)
								  and (SELECT organization_code
                         FROM   mtl_parameters
                         WHERE  organization_id = msi.organization_id)= p_organization_code
union								  
 SELECT  msi.inventory_item_id
                       ,msi.inventory_item_id l_inventory_item_id
                       ,msi.description
                       ,msi.buyer_id
                       ,(SELECT NAME
                         FROM   ra_rules rr
                         WHERE  msi.accounting_rule_id = rr.rule_id) accounting_rule_name
                       ,msi.segment1
                       ,msi.attribute2
                       ,(SELECT  msib.segment1
                         FROM   mtl_system_items_b           msib
                               ,hr_all_organization_units_tl hou
                         WHERE  hou.LANGUAGE = 'US'
                         AND    hou.NAME LIKE 'OMA%'
                         AND    msib.organization_id = hou.organization_id
                         AND    (msib.end_date_active IS NULL OR
                               msib.end_date_active < SYSDATE)
                         AND    msib.inventory_item_id = msi.attribute9
                         AND ROWNUM<2) attribute9
                       ,msi.attribute11
                       ,msi.attribute12
                       ,msi.attribute13
                       ,msi.purchasing_item_flag
                       ,msi.shippable_item_flag
                       ,msi.customer_order_flag
                       ,msi.internal_order_flag
                       ,msi.service_item_flag
                       ,msi.inventory_item_flag
                       ,msi.inventory_asset_flag
                       ,msi.purchasing_enabled_flag
                       ,msi.customer_order_enabled_flag
                       ,msi.internal_order_enabled_flag
                       ,msi.so_transactions_flag
                       ,msi.mtl_transactions_enabled_flag
                       ,msi.stock_enabled_flag
                       ,msi.bom_enabled_flag
                       ,msi.build_in_wip_flag
                       ,msi.item_catalog_group_id
                       ,msi.catalog_status_flag
                       ,msi.returnable_flag
                       ,msi.default_shipping_org
                       ,msi.collateral_flag
                       ,msi.taxable_flag
                       ,msi.allow_item_desc_update_flag
                       ,msi.inspection_required_flag
                       ,msi.receipt_required_flag
                       ,msi.qty_rcv_tolerance
                       ,msi.list_price_per_unit
                       ,msi.asset_category_id
                       ,msi.unit_of_issue
                       ,msi.allow_substitute_receipts_flag
                       ,msi.allow_unordered_receipts_flag
                       ,msi.allow_express_delivery_flag
                       ,msi.days_early_receipt_allowed
                       ,msi.days_late_receipt_allowed
                       ,msi.receipt_days_exception_code
                       ,msi.receiving_routing_id
                       ,msi.auto_lot_alpha_prefix
                       ,msi.start_auto_lot_number
                       ,msi.lot_control_code
                       ,msi.shelf_life_code
                       ,msi.shelf_life_days
                       ,msi.serial_number_control_code
                       ,msi.source_type
                       ,msi.source_subinventory
                       ,msi.expense_account
                       ,msi.restrict_subinventories_code
                       ,msi.organization_id
                       ,(SELECT organization_code
                         FROM   mtl_parameters
                         WHERE  organization_id = msi.organization_id) organization_code
                       ,msi.source_organization_id
                       ,(SELECT organization_code
                         FROM   mtl_parameters
                         WHERE  organization_id = msi.source_organization_id) source_organization_code
                       ,msi.unit_weight
                       ,msi.weight_uom_code
                       ,msi.volume_uom_code
                       ,msi.unit_volume
                       ,msi.shrinkage_rate
                       ,msi.acceptable_early_days
                       ,msi.planning_time_fence_code
                       ,msi.lead_time_lot_size
                       ,msi.std_lot_size
                       ,msi.overrun_percentage
                       ,msi.mrp_calculate_atp_flag
                       ,msi.acceptable_rate_increase
                       ,msi.acceptable_rate_decrease
                       ,msi.planning_time_fence_days
                       ,msi.end_assembly_pegging_flag
                       ,msi.bom_item_type
                       ,msi.pick_components_flag
                       ,msi.replenish_to_order_flag
                       ,msi.atp_components_flag
                       ,msi.atp_flag
                       ,msi.wip_supply_type
                       ,msi.wip_supply_subinventory
                       ,msi.primary_uom_code
                       ,msi.primary_unit_of_measure
                       ,msi.allowed_units_lookup_code
                       ,msi.cost_of_sales_account
                       ,msi.sales_account
                       ,msi.default_include_in_rollup_flag
                       ,msi.inventory_item_status_code
                       ,msi.inventory_planning_code
                       ,msi.planner_code
                       ,msi.planning_make_buy_code
                       ,msi.fixed_lot_multiplier
                       ,msi.rounding_control_type
                       ,msi.postprocessing_lead_time
                       ,msi.preprocessing_lead_time
                       ,msi.full_lead_time
                       ,msi.mrp_safety_stock_percent
                       ,msi.mrp_safety_stock_code
                       ,msi.min_minmax_quantity
                       ,msi.max_minmax_quantity
                       ,msi.minimum_order_quantity
                       ,msi.fixed_order_quantity
                       ,msi.fixed_days_supply
                       ,msi.maximum_order_quantity
                       ,msi.creation_date
                       ,(SELECT rule_name
                         FROM   mtl_atp_rules mat
                         WHERE  msi.atp_rule_id = mat.rule_id) atp_rule_name
                       ,msi.reservable_type
                       ,msi.vendor_warranty_flag
                       ,msi.serviceable_product_flag
                       ,msi.material_billable_flag
                       ,msi.prorate_service_flag
                       ,msi.invoiceable_item_flag
                       ,msi.invoice_enabled_flag
                       ,msi.outside_operation_flag
                       ,msi.outside_operation_uom_type
                       ,msi.safety_stock_bucket_days
                       ,msi.costing_enabled_flag
                       ,msi.cycle_count_enabled_flag
                       ,msi.item_type
                       ,msi.ship_model_complete_flag
                       ,msi.mrp_planning_code
                       ,msi.ato_forecast_control
                       ,msi.release_time_fence_code
                       ,msi.release_time_fence_days
                       ,msi.container_item_flag
                       ,msi.vehicle_item_flag
                       ,msi.effectivity_control
                       ,msi.event_flag
                       ,msi.electronic_flag
                       ,msi.downloadable_flag
                       ,msi.comms_nl_trackable_flag
                       ,msi.orderable_on_web_flag
                       ,msi.web_status
                       ,msi.dimension_uom_code
                       ,msi.unit_length
                       ,msi.unit_width
                       ,msi.unit_height
                       ,msi.dual_uom_control
                       ,msi.dual_uom_deviation_high
                       ,msi.dual_uom_deviation_low
                       ,msi.contract_item_type_code
                       ,msi.serv_req_enabled_code
                       ,msi.serv_billing_enabled_flag
                       ,msi.default_so_source_type
                       ,msi.object_version_number
                       ,msi.tracking_quantity_ind
                       ,msi.secondary_default_ind
                       ,msi.so_authorization_flag
                       ,msi.attribute17
                       ,msi.attribute18
                       ,msi.attribute19
                       ,msi.attribute25
                       ,msi.expiration_action_code
                       ,msi.expiration_action_interval
                       ,msi.hazardous_material_flag
                       ,msi.recipe_enabled_flag
                       ,msi.retest_interval
                       ,msi.repair_leadtime
                       ,msi.gdsn_outbound_enabled_flag
                       ,msi.revision_qty_control_code
                       ,msi.start_auto_serial_number
                       ,msi.auto_serial_alpha_prefix
                       ,(SELECT concatenated_segments
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) legacy_expense_account
                       ,(SELECT concatenated_segments
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) legacy_cost_of_sales_account
                       ,(SELECT concatenated_segments
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) legacy_sales_account
                       ,
                        
                        (SELECT segment1
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment1
                       ,(SELECT segment2
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment2
                       ,
                        
                        (SELECT segment3
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment3
                       ,
                        
                        (SELECT segment4
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment4
                       ,
                        
                        (SELECT segment5
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment5
                       ,
                        
                        (SELECT segment6
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment6
                       ,
                        
                        (SELECT segment7
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment7
                       ,
                        
                        (SELECT segment8
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment8
                       ,(SELECT segment9
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment9
                       ,(SELECT segment10
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment10
                       ,
                        
                        (SELECT segment1
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment1
                       ,
                        
                        (SELECT segment2
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment2
                       ,
                        
                        (SELECT segment3
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment3
                       ,
                        
                        (SELECT segment4
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment4
                       ,
                        
                        (SELECT segment5
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment5
                       ,
                        
                        (SELECT segment6
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment6
                       ,
                        
                        (SELECT segment7
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment7
                       ,
                        
                        (SELECT segment8
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment8
                       ,(SELECT segment9
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment9
                       ,(SELECT segment10
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment10
                       ,
                        
                        (SELECT segment1
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment1
                       ,(SELECT segment2
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment2
                       ,
                        
                        (SELECT segment3
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment3
                       ,
                        
                        (SELECT segment4
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment4
                       ,
                        
                        (SELECT segment5
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment5
                       ,
                        
                        (SELECT segment6
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment6
                       ,
                        
                        (SELECT segment7
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment7
                       ,
                        
                        (SELECT segment8
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment8
                       ,(SELECT segment9
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment9
                       ,(SELECT segment10
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment10
from  mtl_system_items_b  msi							  
where  EXISTS(select ool.inventory_item_id
                                  from oe_order_lines_all ool
                                  where ool.inventory_item_id = msi.inventory_item_id
                                  and   ool.creation_date > sysdate -730)
and (SELECT organization_code
                         FROM   mtl_parameters
                         WHERE  organization_id = msi.organization_id) = p_organization_code
union
								  
	 SELECT  msi.inventory_item_id
                       ,msi.inventory_item_id l_inventory_item_id
                       ,msi.description
                       ,msi.buyer_id
                       ,(SELECT NAME
                         FROM   ra_rules rr
                         WHERE  msi.accounting_rule_id = rr.rule_id) accounting_rule_name
                       ,msi.segment1
                       ,msi.attribute2
                       ,(SELECT  msib.segment1
                         FROM   mtl_system_items_b           msib
                               ,hr_all_organization_units_tl hou
                         WHERE  hou.LANGUAGE = 'US'
                         AND    hou.NAME LIKE 'OMA%'
                         AND    msib.organization_id = hou.organization_id
                         AND    (msib.end_date_active IS NULL OR
                               msib.end_date_active < SYSDATE)
                         AND    msib.inventory_item_id = msi.attribute9
                         AND ROWNUM<2) attribute9
                       ,msi.attribute11
                       ,msi.attribute12
                       ,msi.attribute13
                       ,msi.purchasing_item_flag
                       ,msi.shippable_item_flag
                       ,msi.customer_order_flag
                       ,msi.internal_order_flag
                       ,msi.service_item_flag
                       ,msi.inventory_item_flag
                       ,msi.inventory_asset_flag
                       ,msi.purchasing_enabled_flag
                       ,msi.customer_order_enabled_flag
                       ,msi.internal_order_enabled_flag
                       ,msi.so_transactions_flag
                       ,msi.mtl_transactions_enabled_flag
                       ,msi.stock_enabled_flag
                       ,msi.bom_enabled_flag
                       ,msi.build_in_wip_flag
                       ,msi.item_catalog_group_id
                       ,msi.catalog_status_flag
                       ,msi.returnable_flag
                       ,msi.default_shipping_org
                       ,msi.collateral_flag
                       ,msi.taxable_flag
                       ,msi.allow_item_desc_update_flag
                       ,msi.inspection_required_flag
                       ,msi.receipt_required_flag
                       ,msi.qty_rcv_tolerance
                       ,msi.list_price_per_unit
                       ,msi.asset_category_id
                       ,msi.unit_of_issue
                       ,msi.allow_substitute_receipts_flag
                       ,msi.allow_unordered_receipts_flag
                       ,msi.allow_express_delivery_flag
                       ,msi.days_early_receipt_allowed
                       ,msi.days_late_receipt_allowed
                       ,msi.receipt_days_exception_code
                       ,msi.receiving_routing_id
                       ,msi.auto_lot_alpha_prefix
                       ,msi.start_auto_lot_number
                       ,msi.lot_control_code
                       ,msi.shelf_life_code
                       ,msi.shelf_life_days
                       ,msi.serial_number_control_code
                       ,msi.source_type
                       ,msi.source_subinventory
                       ,msi.expense_account
                       ,msi.restrict_subinventories_code
                       ,msi.organization_id
                       ,(SELECT organization_code
                         FROM   mtl_parameters
                         WHERE  organization_id = msi.organization_id) organization_code
                       ,msi.source_organization_id
                       ,(SELECT organization_code
                         FROM   mtl_parameters
                         WHERE  organization_id = msi.source_organization_id) source_organization_code
                       ,msi.unit_weight
                       ,msi.weight_uom_code
                       ,msi.volume_uom_code
                       ,msi.unit_volume
                       ,msi.shrinkage_rate
                       ,msi.acceptable_early_days
                       ,msi.planning_time_fence_code
                       ,msi.lead_time_lot_size
                       ,msi.std_lot_size
                       ,msi.overrun_percentage
                       ,msi.mrp_calculate_atp_flag
                       ,msi.acceptable_rate_increase
                       ,msi.acceptable_rate_decrease
                       ,msi.planning_time_fence_days
                       ,msi.end_assembly_pegging_flag
                       ,msi.bom_item_type
                       ,msi.pick_components_flag
                       ,msi.replenish_to_order_flag
                       ,msi.atp_components_flag
                       ,msi.atp_flag
                       ,msi.wip_supply_type
                       ,msi.wip_supply_subinventory
                       ,msi.primary_uom_code
                       ,msi.primary_unit_of_measure
                       ,msi.allowed_units_lookup_code
                       ,msi.cost_of_sales_account
                       ,msi.sales_account
                       ,msi.default_include_in_rollup_flag
                       ,msi.inventory_item_status_code
                       ,msi.inventory_planning_code
                       ,msi.planner_code
                       ,msi.planning_make_buy_code
                       ,msi.fixed_lot_multiplier
                       ,msi.rounding_control_type
                       ,msi.postprocessing_lead_time
                       ,msi.preprocessing_lead_time
                       ,msi.full_lead_time
                       ,msi.mrp_safety_stock_percent
                       ,msi.mrp_safety_stock_code
                       ,msi.min_minmax_quantity
                       ,msi.max_minmax_quantity
                       ,msi.minimum_order_quantity
                       ,msi.fixed_order_quantity
                       ,msi.fixed_days_supply
                       ,msi.maximum_order_quantity
                       ,msi.creation_date
                       ,(SELECT rule_name
                         FROM   mtl_atp_rules mat
                         WHERE  msi.atp_rule_id = mat.rule_id) atp_rule_name
                       ,msi.reservable_type
                       ,msi.vendor_warranty_flag
                       ,msi.serviceable_product_flag
                       ,msi.material_billable_flag
                       ,msi.prorate_service_flag
                       ,msi.invoiceable_item_flag
                       ,msi.invoice_enabled_flag
                       ,msi.outside_operation_flag
                       ,msi.outside_operation_uom_type
                       ,msi.safety_stock_bucket_days
                       ,msi.costing_enabled_flag
                       ,msi.cycle_count_enabled_flag
                       ,msi.item_type
                       ,msi.ship_model_complete_flag
                       ,msi.mrp_planning_code
                       ,msi.ato_forecast_control
                       ,msi.release_time_fence_code
                       ,msi.release_time_fence_days
                       ,msi.container_item_flag
                       ,msi.vehicle_item_flag
                       ,msi.effectivity_control
                       ,msi.event_flag
                       ,msi.electronic_flag
                       ,msi.downloadable_flag
                       ,msi.comms_nl_trackable_flag
                       ,msi.orderable_on_web_flag
                       ,msi.web_status
                       ,msi.dimension_uom_code
                       ,msi.unit_length
                       ,msi.unit_width
                       ,msi.unit_height
                       ,msi.dual_uom_control
                       ,msi.dual_uom_deviation_high
                       ,msi.dual_uom_deviation_low
                       ,msi.contract_item_type_code
                       ,msi.serv_req_enabled_code
                       ,msi.serv_billing_enabled_flag
                       ,msi.default_so_source_type
                       ,msi.object_version_number
                       ,msi.tracking_quantity_ind
                       ,msi.secondary_default_ind
                       ,msi.so_authorization_flag
                       ,msi.attribute17
                       ,msi.attribute18
                       ,msi.attribute19
                       ,msi.attribute25
                       ,msi.expiration_action_code
                       ,msi.expiration_action_interval
                       ,msi.hazardous_material_flag
                       ,msi.recipe_enabled_flag
                       ,msi.retest_interval
                       ,msi.repair_leadtime
                       ,msi.gdsn_outbound_enabled_flag
                       ,msi.revision_qty_control_code
                       ,msi.start_auto_serial_number
                       ,msi.auto_serial_alpha_prefix
                       ,(SELECT concatenated_segments
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) legacy_expense_account
                       ,(SELECT concatenated_segments
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) legacy_cost_of_sales_account
                       ,(SELECT concatenated_segments
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) legacy_sales_account
                       ,
                        
                        (SELECT segment1
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment1
                       ,(SELECT segment2
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment2
                       ,
                        
                        (SELECT segment3
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment3
                       ,
                        
                        (SELECT segment4
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment4
                       ,
                        
                        (SELECT segment5
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment5
                       ,
                        
                        (SELECT segment6
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment6
                       ,
                        
                        (SELECT segment7
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment7
                       ,
                        
                        (SELECT segment8
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment8
                       ,(SELECT segment9
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment9
                       ,(SELECT segment10
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment10
                       ,
                        
                        (SELECT segment1
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment1
                       ,
                        
                        (SELECT segment2
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment2
                       ,
                        
                        (SELECT segment3
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment3
                       ,
                        
                        (SELECT segment4
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment4
                       ,
                        
                        (SELECT segment5
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment5
                       ,
                        
                        (SELECT segment6
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment6
                       ,
                        
                        (SELECT segment7
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment7
                       ,
                        
                        (SELECT segment8
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment8
                       ,(SELECT segment9
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment9
                       ,(SELECT segment10
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment10
                       ,
                        
                        (SELECT segment1
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment1
                       ,(SELECT segment2
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment2
                       ,
                        
                        (SELECT segment3
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment3
                       ,
                        
                        (SELECT segment4
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment4
                       ,
                        
                        (SELECT segment5
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment5
                       ,
                        
                        (SELECT segment6
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment6
                       ,
                        
                        (SELECT segment7
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment7
                       ,
                        
                        (SELECT segment8
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment8
                       ,(SELECT segment9
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment9
                       ,(SELECT segment10
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment10
from  mtl_system_items_b  msi	
where   EXISTS ( select mmt.inventory_item_id
                                 from mtl_onhand_quantities mmt
                                 where mmt.inventory_item_id = msi.inventory_item_id)
 and (SELECT organization_code
                         FROM   mtl_parameters
                         WHERE  organization_id = msi.organization_id) = p_organization_code
union
	 SELECT  msi.inventory_item_id
                       ,msi.inventory_item_id l_inventory_item_id
                       ,msi.description
                       ,msi.buyer_id
                       ,(SELECT NAME
                         FROM   ra_rules rr
                         WHERE  msi.accounting_rule_id = rr.rule_id) accounting_rule_name
                       ,msi.segment1
                       ,msi.attribute2
                       ,(SELECT  msib.segment1
                         FROM   mtl_system_items_b           msib
                               ,hr_all_organization_units_tl hou
                         WHERE  hou.LANGUAGE = 'US'
                         AND    hou.NAME LIKE 'OMA%'
                         AND    msib.organization_id = hou.organization_id
                         AND    (msib.end_date_active IS NULL OR
                               msib.end_date_active < SYSDATE)
                         AND    msib.inventory_item_id = msi.attribute9
                         AND ROWNUM<2) attribute9
                       ,msi.attribute11
                       ,msi.attribute12
                       ,msi.attribute13
                       ,msi.purchasing_item_flag
                       ,msi.shippable_item_flag
                       ,msi.customer_order_flag
                       ,msi.internal_order_flag
                       ,msi.service_item_flag
                       ,msi.inventory_item_flag
                       ,msi.inventory_asset_flag
                       ,msi.purchasing_enabled_flag
                       ,msi.customer_order_enabled_flag
                       ,msi.internal_order_enabled_flag
                       ,msi.so_transactions_flag
                       ,msi.mtl_transactions_enabled_flag
                       ,msi.stock_enabled_flag
                       ,msi.bom_enabled_flag
                       ,msi.build_in_wip_flag
                       ,msi.item_catalog_group_id
                       ,msi.catalog_status_flag
                       ,msi.returnable_flag
                       ,msi.default_shipping_org
                       ,msi.collateral_flag
                       ,msi.taxable_flag
                       ,msi.allow_item_desc_update_flag
                       ,msi.inspection_required_flag
                       ,msi.receipt_required_flag
                       ,msi.qty_rcv_tolerance
                       ,msi.list_price_per_unit
                       ,msi.asset_category_id
                       ,msi.unit_of_issue
                       ,msi.allow_substitute_receipts_flag
                       ,msi.allow_unordered_receipts_flag
                       ,msi.allow_express_delivery_flag
                       ,msi.days_early_receipt_allowed
                       ,msi.days_late_receipt_allowed
                       ,msi.receipt_days_exception_code
                       ,msi.receiving_routing_id
                       ,msi.auto_lot_alpha_prefix
                       ,msi.start_auto_lot_number
                       ,msi.lot_control_code
                       ,msi.shelf_life_code
                       ,msi.shelf_life_days
                       ,msi.serial_number_control_code
                       ,msi.source_type
                       ,msi.source_subinventory
                       ,msi.expense_account
                       ,msi.restrict_subinventories_code
                       ,msi.organization_id
                       ,(SELECT organization_code
                         FROM   mtl_parameters
                         WHERE  organization_id = msi.organization_id) organization_code
                       ,msi.source_organization_id
                       ,(SELECT organization_code
                         FROM   mtl_parameters
                         WHERE  organization_id = msi.source_organization_id) source_organization_code
                       ,msi.unit_weight
                       ,msi.weight_uom_code
                       ,msi.volume_uom_code
                       ,msi.unit_volume
                       ,msi.shrinkage_rate
                       ,msi.acceptable_early_days
                       ,msi.planning_time_fence_code
                       ,msi.lead_time_lot_size
                       ,msi.std_lot_size
                       ,msi.overrun_percentage
                       ,msi.mrp_calculate_atp_flag
                       ,msi.acceptable_rate_increase
                       ,msi.acceptable_rate_decrease
                       ,msi.planning_time_fence_days
                       ,msi.end_assembly_pegging_flag
                       ,msi.bom_item_type
                       ,msi.pick_components_flag
                       ,msi.replenish_to_order_flag
                       ,msi.atp_components_flag
                       ,msi.atp_flag
                       ,msi.wip_supply_type
                       ,msi.wip_supply_subinventory
                       ,msi.primary_uom_code
                       ,msi.primary_unit_of_measure
                       ,msi.allowed_units_lookup_code
                       ,msi.cost_of_sales_account
                       ,msi.sales_account
                       ,msi.default_include_in_rollup_flag
                       ,msi.inventory_item_status_code
                       ,msi.inventory_planning_code
                       ,msi.planner_code
                       ,msi.planning_make_buy_code
                       ,msi.fixed_lot_multiplier
                       ,msi.rounding_control_type
                       ,msi.postprocessing_lead_time
                       ,msi.preprocessing_lead_time
                       ,msi.full_lead_time
                       ,msi.mrp_safety_stock_percent
                       ,msi.mrp_safety_stock_code
                       ,msi.min_minmax_quantity
                       ,msi.max_minmax_quantity
                       ,msi.minimum_order_quantity
                       ,msi.fixed_order_quantity
                       ,msi.fixed_days_supply
                       ,msi.maximum_order_quantity
                       ,msi.creation_date
                       ,(SELECT rule_name
                         FROM   mtl_atp_rules mat
                         WHERE  msi.atp_rule_id = mat.rule_id) atp_rule_name
                       ,msi.reservable_type
                       ,msi.vendor_warranty_flag
                       ,msi.serviceable_product_flag
                       ,msi.material_billable_flag
                       ,msi.prorate_service_flag
                       ,msi.invoiceable_item_flag
                       ,msi.invoice_enabled_flag
                       ,msi.outside_operation_flag
                       ,msi.outside_operation_uom_type
                       ,msi.safety_stock_bucket_days
                       ,msi.costing_enabled_flag
                       ,msi.cycle_count_enabled_flag
                       ,msi.item_type
                       ,msi.ship_model_complete_flag
                       ,msi.mrp_planning_code
                       ,msi.ato_forecast_control
                       ,msi.release_time_fence_code
                       ,msi.release_time_fence_days
                       ,msi.container_item_flag
                       ,msi.vehicle_item_flag
                       ,msi.effectivity_control
                       ,msi.event_flag
                       ,msi.electronic_flag
                       ,msi.downloadable_flag
                       ,msi.comms_nl_trackable_flag
                       ,msi.orderable_on_web_flag
                       ,msi.web_status
                       ,msi.dimension_uom_code
                       ,msi.unit_length
                       ,msi.unit_width
                       ,msi.unit_height
                       ,msi.dual_uom_control
                       ,msi.dual_uom_deviation_high
                       ,msi.dual_uom_deviation_low
                       ,msi.contract_item_type_code
                       ,msi.serv_req_enabled_code
                       ,msi.serv_billing_enabled_flag
                       ,msi.default_so_source_type
                       ,msi.object_version_number
                       ,msi.tracking_quantity_ind
                       ,msi.secondary_default_ind
                       ,msi.so_authorization_flag
                       ,msi.attribute17
                       ,msi.attribute18
                       ,msi.attribute19
                       ,msi.attribute25
                       ,msi.expiration_action_code
                       ,msi.expiration_action_interval
                       ,msi.hazardous_material_flag
                       ,msi.recipe_enabled_flag
                       ,msi.retest_interval
                       ,msi.repair_leadtime
                       ,msi.gdsn_outbound_enabled_flag
                       ,msi.revision_qty_control_code
                       ,msi.start_auto_serial_number
                       ,msi.auto_serial_alpha_prefix
                       ,(SELECT concatenated_segments
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) legacy_expense_account
                       ,(SELECT concatenated_segments
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) legacy_cost_of_sales_account
                       ,(SELECT concatenated_segments
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) legacy_sales_account
                       ,
                        
                        (SELECT segment1
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment1
                       ,(SELECT segment2
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment2
                       ,
                        
                        (SELECT segment3
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment3
                       ,
                        
                        (SELECT segment4
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment4
                       ,
                        
                        (SELECT segment5
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment5
                       ,
                        
                        (SELECT segment6
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment6
                       ,
                        
                        (SELECT segment7
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment7
                       ,
                        
                        (SELECT segment8
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment8
                       ,(SELECT segment9
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment9
                       ,(SELECT segment10
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment10
                       ,
                        
                        (SELECT segment1
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment1
                       ,
                        
                        (SELECT segment2
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment2
                       ,
                        
                        (SELECT segment3
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment3
                       ,
                        
                        (SELECT segment4
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment4
                       ,
                        
                        (SELECT segment5
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment5
                       ,
                        
                        (SELECT segment6
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment6
                       ,
                        
                        (SELECT segment7
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment7
                       ,
                        
                        (SELECT segment8
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment8
                       ,(SELECT segment9
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment9
                       ,(SELECT segment10
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment10
                       ,
                        
                        (SELECT segment1
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment1
                       ,(SELECT segment2
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment2
                       ,
                        
                        (SELECT segment3
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment3
                       ,
                        
                        (SELECT segment4
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment4
                       ,
                        
                        (SELECT segment5
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment5
                       ,
                        
                        (SELECT segment6
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment6
                       ,
                        
                        (SELECT segment7
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment7
                       ,
                        
                        (SELECT segment8
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment8
                       ,(SELECT segment9
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment9
                       ,(SELECT segment10
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment10
from  mtl_system_items_b  msi	
where msi.inventory_item_status_code = 'Active PTO'
 and (SELECT organization_code
                         FROM   mtl_parameters
                         WHERE  organization_id = msi.organization_id)= p_organization_code
union
 SELECT  msi.inventory_item_id
                       ,msi.inventory_item_id l_inventory_item_id
                       ,msi.description
                       ,msi.buyer_id
                       ,(SELECT NAME
                         FROM   ra_rules rr
                         WHERE  msi.accounting_rule_id = rr.rule_id) accounting_rule_name
                       ,msi.segment1
                       ,msi.attribute2
                       ,(SELECT  msib.segment1
                         FROM   mtl_system_items_b           msib
                               ,hr_all_organization_units_tl hou
                         WHERE  hou.LANGUAGE = 'US'
                         AND    hou.NAME LIKE 'OMA%'
                         AND    msib.organization_id = hou.organization_id
                         AND    (msib.end_date_active IS NULL OR
                               msib.end_date_active < SYSDATE)
                         AND    msib.inventory_item_id = msi.attribute9
                         AND ROWNUM<2) attribute9
                       ,msi.attribute11
                       ,msi.attribute12
                       ,msi.attribute13
                       ,msi.purchasing_item_flag
                       ,msi.shippable_item_flag
                       ,msi.customer_order_flag
                       ,msi.internal_order_flag
                       ,msi.service_item_flag
                       ,msi.inventory_item_flag
                       ,msi.inventory_asset_flag
                       ,msi.purchasing_enabled_flag
                       ,msi.customer_order_enabled_flag
                       ,msi.internal_order_enabled_flag
                       ,msi.so_transactions_flag
                       ,msi.mtl_transactions_enabled_flag
                       ,msi.stock_enabled_flag
                       ,msi.bom_enabled_flag
                       ,msi.build_in_wip_flag
                       ,msi.item_catalog_group_id
                       ,msi.catalog_status_flag
                       ,msi.returnable_flag
                       ,msi.default_shipping_org
                       ,msi.collateral_flag
                       ,msi.taxable_flag
                       ,msi.allow_item_desc_update_flag
                       ,msi.inspection_required_flag
                       ,msi.receipt_required_flag
                       ,msi.qty_rcv_tolerance
                       ,msi.list_price_per_unit
                       ,msi.asset_category_id
                       ,msi.unit_of_issue
                       ,msi.allow_substitute_receipts_flag
                       ,msi.allow_unordered_receipts_flag
                       ,msi.allow_express_delivery_flag
                       ,msi.days_early_receipt_allowed
                       ,msi.days_late_receipt_allowed
                       ,msi.receipt_days_exception_code
                       ,msi.receiving_routing_id
                       ,msi.auto_lot_alpha_prefix
                       ,msi.start_auto_lot_number
                       ,msi.lot_control_code
                       ,msi.shelf_life_code
                       ,msi.shelf_life_days
                       ,msi.serial_number_control_code
                       ,msi.source_type
                       ,msi.source_subinventory
                       ,msi.expense_account
                       ,msi.restrict_subinventories_code
                       ,msi.organization_id
                       ,(SELECT organization_code
                         FROM   mtl_parameters
                         WHERE  organization_id = msi.organization_id) organization_code
                       ,msi.source_organization_id
                       ,(SELECT organization_code
                         FROM   mtl_parameters
                         WHERE  organization_id = msi.source_organization_id) source_organization_code
                       ,msi.unit_weight
                       ,msi.weight_uom_code
                       ,msi.volume_uom_code
                       ,msi.unit_volume
                       ,msi.shrinkage_rate
                       ,msi.acceptable_early_days
                       ,msi.planning_time_fence_code
                       ,msi.lead_time_lot_size
                       ,msi.std_lot_size
                       ,msi.overrun_percentage
                       ,msi.mrp_calculate_atp_flag
                       ,msi.acceptable_rate_increase
                       ,msi.acceptable_rate_decrease
                       ,msi.planning_time_fence_days
                       ,msi.end_assembly_pegging_flag
                       ,msi.bom_item_type
                       ,msi.pick_components_flag
                       ,msi.replenish_to_order_flag
                       ,msi.atp_components_flag
                       ,msi.atp_flag
                       ,msi.wip_supply_type
                       ,msi.wip_supply_subinventory
                       ,msi.primary_uom_code
                       ,msi.primary_unit_of_measure
                       ,msi.allowed_units_lookup_code
                       ,msi.cost_of_sales_account
                       ,msi.sales_account
                       ,msi.default_include_in_rollup_flag
                       ,msi.inventory_item_status_code
                       ,msi.inventory_planning_code
                       ,msi.planner_code
                       ,msi.planning_make_buy_code
                       ,msi.fixed_lot_multiplier
                       ,msi.rounding_control_type
                       ,msi.postprocessing_lead_time
                       ,msi.preprocessing_lead_time
                       ,msi.full_lead_time
                       ,msi.mrp_safety_stock_percent
                       ,msi.mrp_safety_stock_code
                       ,msi.min_minmax_quantity
                       ,msi.max_minmax_quantity
                       ,msi.minimum_order_quantity
                       ,msi.fixed_order_quantity
                       ,msi.fixed_days_supply
                       ,msi.maximum_order_quantity
                       ,msi.creation_date
                       ,(SELECT rule_name
                         FROM   mtl_atp_rules mat
                         WHERE  msi.atp_rule_id = mat.rule_id) atp_rule_name
                       ,msi.reservable_type
                       ,msi.vendor_warranty_flag
                       ,msi.serviceable_product_flag
                       ,msi.material_billable_flag
                       ,msi.prorate_service_flag
                       ,msi.invoiceable_item_flag
                       ,msi.invoice_enabled_flag
                       ,msi.outside_operation_flag
                       ,msi.outside_operation_uom_type
                       ,msi.safety_stock_bucket_days
                       ,msi.costing_enabled_flag
                       ,msi.cycle_count_enabled_flag
                       ,msi.item_type
                       ,msi.ship_model_complete_flag
                       ,msi.mrp_planning_code
                       ,msi.ato_forecast_control
                       ,msi.release_time_fence_code
                       ,msi.release_time_fence_days
                       ,msi.container_item_flag
                       ,msi.vehicle_item_flag
                       ,msi.effectivity_control
                       ,msi.event_flag
                       ,msi.electronic_flag
                       ,msi.downloadable_flag
                       ,msi.comms_nl_trackable_flag
                       ,msi.orderable_on_web_flag
                       ,msi.web_status
                       ,msi.dimension_uom_code
                       ,msi.unit_length
                       ,msi.unit_width
                       ,msi.unit_height
                       ,msi.dual_uom_control
                       ,msi.dual_uom_deviation_high
                       ,msi.dual_uom_deviation_low
                       ,msi.contract_item_type_code
                       ,msi.serv_req_enabled_code
                       ,msi.serv_billing_enabled_flag
                       ,msi.default_so_source_type
                       ,msi.object_version_number
                       ,msi.tracking_quantity_ind
                       ,msi.secondary_default_ind
                       ,msi.so_authorization_flag
                       ,msi.attribute17
                       ,msi.attribute18
                       ,msi.attribute19
                       ,msi.attribute25
                       ,msi.expiration_action_code
                       ,msi.expiration_action_interval
                       ,msi.hazardous_material_flag
                       ,msi.recipe_enabled_flag
                       ,msi.retest_interval
                       ,msi.repair_leadtime
                       ,msi.gdsn_outbound_enabled_flag
                       ,msi.revision_qty_control_code
                       ,msi.start_auto_serial_number
                       ,msi.auto_serial_alpha_prefix
                       ,(SELECT concatenated_segments
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) legacy_expense_account
                       ,(SELECT concatenated_segments
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) legacy_cost_of_sales_account
                       ,(SELECT concatenated_segments
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) legacy_sales_account
                       ,
                        
                        (SELECT segment1
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment1
                       ,(SELECT segment2
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment2
                       ,
                        
                        (SELECT segment3
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment3
                       ,
                        
                        (SELECT segment4
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment4
                       ,
                        
                        (SELECT segment5
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment5
                       ,
                        
                        (SELECT segment6
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment6
                       ,
                        
                        (SELECT segment7
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment7
                       ,
                        
                        (SELECT segment8
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment8
                       ,(SELECT segment9
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment9
                       ,(SELECT segment10
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment10
                       ,
                        
                        (SELECT segment1
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment1
                       ,
                        
                        (SELECT segment2
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment2
                       ,
                        
                        (SELECT segment3
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment3
                       ,
                        
                        (SELECT segment4
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment4
                       ,
                        
                        (SELECT segment5
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment5
                       ,
                        
                        (SELECT segment6
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment6
                       ,
                        
                        (SELECT segment7
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment7
                       ,
                        
                        (SELECT segment8
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment8
                       ,(SELECT segment9
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment9
                       ,(SELECT segment10
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment10
                       ,
                        
                        (SELECT segment1
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment1
                       ,(SELECT segment2
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment2
                       ,
                        
                        (SELECT segment3
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment3
                       ,
                        
                        (SELECT segment4
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment4
                       ,
                        
                        (SELECT segment5
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment5
                       ,
                        
                        (SELECT segment6
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment6
                       ,
                        
                        (SELECT segment7
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment7
                       ,
                        
                        (SELECT segment8
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment8
                       ,(SELECT segment9
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment9
                       ,(SELECT segment10
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment10
from  mtl_system_items_b  msi	
where msi.inventory_item_status_code in ('XX_BETA','Inactive','Active','XX_PROD')
and   (msi.segment1 like ('%-S') or msi.segment1 like ('%-CS'))
 and (SELECT organization_code
                         FROM   mtl_parameters
                         WHERE  organization_id = msi.organization_id) = p_organization_code
union
 SELECT  msi.inventory_item_id
                       ,msi.inventory_item_id l_inventory_item_id
                       ,msi.description
                       ,msi.buyer_id
                       ,(SELECT NAME
                         FROM   ra_rules rr
                         WHERE  msi.accounting_rule_id = rr.rule_id) accounting_rule_name
                       ,msi.segment1
                       ,msi.attribute2
                       ,(SELECT  msib.segment1
                         FROM   mtl_system_items_b           msib
                               ,hr_all_organization_units_tl hou
                         WHERE  hou.LANGUAGE = 'US'
                         AND    hou.NAME LIKE 'OMA%'
                         AND    msib.organization_id = hou.organization_id
                         AND    (msib.end_date_active IS NULL OR
                               msib.end_date_active < SYSDATE)
                         AND    msib.inventory_item_id = msi.attribute9
                         AND ROWNUM<2) attribute9
                       ,msi.attribute11
                       ,msi.attribute12
                       ,msi.attribute13
                       ,msi.purchasing_item_flag
                       ,msi.shippable_item_flag
                       ,msi.customer_order_flag
                       ,msi.internal_order_flag
                       ,msi.service_item_flag
                       ,msi.inventory_item_flag
                       ,msi.inventory_asset_flag
                       ,msi.purchasing_enabled_flag
                       ,msi.customer_order_enabled_flag
                       ,msi.internal_order_enabled_flag
                       ,msi.so_transactions_flag
                       ,msi.mtl_transactions_enabled_flag
                       ,msi.stock_enabled_flag
                       ,msi.bom_enabled_flag
                       ,msi.build_in_wip_flag
                       ,msi.item_catalog_group_id
                       ,msi.catalog_status_flag
                       ,msi.returnable_flag
                       ,msi.default_shipping_org
                       ,msi.collateral_flag
                       ,msi.taxable_flag
                       ,msi.allow_item_desc_update_flag
                       ,msi.inspection_required_flag
                       ,msi.receipt_required_flag
                       ,msi.qty_rcv_tolerance
                       ,msi.list_price_per_unit
                       ,msi.asset_category_id
                       ,msi.unit_of_issue
                       ,msi.allow_substitute_receipts_flag
                       ,msi.allow_unordered_receipts_flag
                       ,msi.allow_express_delivery_flag
                       ,msi.days_early_receipt_allowed
                       ,msi.days_late_receipt_allowed
                       ,msi.receipt_days_exception_code
                       ,msi.receiving_routing_id
                       ,msi.auto_lot_alpha_prefix
                       ,msi.start_auto_lot_number
                       ,msi.lot_control_code
                       ,msi.shelf_life_code
                       ,msi.shelf_life_days
                       ,msi.serial_number_control_code
                       ,msi.source_type
                       ,msi.source_subinventory
                       ,msi.expense_account
                       ,msi.restrict_subinventories_code
                       ,msi.organization_id
                       ,(SELECT organization_code
                         FROM   mtl_parameters
                         WHERE  organization_id = msi.organization_id) organization_code
                       ,msi.source_organization_id
                       ,(SELECT organization_code
                         FROM   mtl_parameters
                         WHERE  organization_id = msi.source_organization_id) source_organization_code
                       ,msi.unit_weight
                       ,msi.weight_uom_code
                       ,msi.volume_uom_code
                       ,msi.unit_volume
                       ,msi.shrinkage_rate
                       ,msi.acceptable_early_days
                       ,msi.planning_time_fence_code
                       ,msi.lead_time_lot_size
                       ,msi.std_lot_size
                       ,msi.overrun_percentage
                       ,msi.mrp_calculate_atp_flag
                       ,msi.acceptable_rate_increase
                       ,msi.acceptable_rate_decrease
                       ,msi.planning_time_fence_days
                       ,msi.end_assembly_pegging_flag
                       ,msi.bom_item_type
                       ,msi.pick_components_flag
                       ,msi.replenish_to_order_flag
                       ,msi.atp_components_flag
                       ,msi.atp_flag
                       ,msi.wip_supply_type
                       ,msi.wip_supply_subinventory
                       ,msi.primary_uom_code
                       ,msi.primary_unit_of_measure
                       ,msi.allowed_units_lookup_code
                       ,msi.cost_of_sales_account
                       ,msi.sales_account
                       ,msi.default_include_in_rollup_flag
                       ,msi.inventory_item_status_code
                       ,msi.inventory_planning_code
                       ,msi.planner_code
                       ,msi.planning_make_buy_code
                       ,msi.fixed_lot_multiplier
                       ,msi.rounding_control_type
                       ,msi.postprocessing_lead_time
                       ,msi.preprocessing_lead_time
                       ,msi.full_lead_time
                       ,msi.mrp_safety_stock_percent
                       ,msi.mrp_safety_stock_code
                       ,msi.min_minmax_quantity
                       ,msi.max_minmax_quantity
                       ,msi.minimum_order_quantity
                       ,msi.fixed_order_quantity
                       ,msi.fixed_days_supply
                       ,msi.maximum_order_quantity
                       ,msi.creation_date
                       ,(SELECT rule_name
                         FROM   mtl_atp_rules mat
                         WHERE  msi.atp_rule_id = mat.rule_id) atp_rule_name
                       ,msi.reservable_type
                       ,msi.vendor_warranty_flag
                       ,msi.serviceable_product_flag
                       ,msi.material_billable_flag
                       ,msi.prorate_service_flag
                       ,msi.invoiceable_item_flag
                       ,msi.invoice_enabled_flag
                       ,msi.outside_operation_flag
                       ,msi.outside_operation_uom_type
                       ,msi.safety_stock_bucket_days
                       ,msi.costing_enabled_flag
                       ,msi.cycle_count_enabled_flag
                       ,msi.item_type
                       ,msi.ship_model_complete_flag
                       ,msi.mrp_planning_code
                       ,msi.ato_forecast_control
                       ,msi.release_time_fence_code
                       ,msi.release_time_fence_days
                       ,msi.container_item_flag
                       ,msi.vehicle_item_flag
                       ,msi.effectivity_control
                       ,msi.event_flag
                       ,msi.electronic_flag
                       ,msi.downloadable_flag
                       ,msi.comms_nl_trackable_flag
                       ,msi.orderable_on_web_flag
                       ,msi.web_status
                       ,msi.dimension_uom_code
                       ,msi.unit_length
                       ,msi.unit_width
                       ,msi.unit_height
                       ,msi.dual_uom_control
                       ,msi.dual_uom_deviation_high
                       ,msi.dual_uom_deviation_low
                       ,msi.contract_item_type_code
                       ,msi.serv_req_enabled_code
                       ,msi.serv_billing_enabled_flag
                       ,msi.default_so_source_type
                       ,msi.object_version_number
                       ,msi.tracking_quantity_ind
                       ,msi.secondary_default_ind
                       ,msi.so_authorization_flag
                       ,msi.attribute17
                       ,msi.attribute18
                       ,msi.attribute19
                       ,msi.attribute25
                       ,msi.expiration_action_code
                       ,msi.expiration_action_interval
                       ,msi.hazardous_material_flag
                       ,msi.recipe_enabled_flag
                       ,msi.retest_interval
                       ,msi.repair_leadtime
                       ,msi.gdsn_outbound_enabled_flag
                       ,msi.revision_qty_control_code
                       ,msi.start_auto_serial_number
                       ,msi.auto_serial_alpha_prefix
                       ,(SELECT concatenated_segments
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) legacy_expense_account
                       ,(SELECT concatenated_segments
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) legacy_cost_of_sales_account
                       ,(SELECT concatenated_segments
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) legacy_sales_account
                       ,
                        
                        (SELECT segment1
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment1
                       ,(SELECT segment2
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment2
                       ,
                        
                        (SELECT segment3
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment3
                       ,
                        
                        (SELECT segment4
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment4
                       ,
                        
                        (SELECT segment5
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment5
                       ,
                        
                        (SELECT segment6
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment6
                       ,
                        
                        (SELECT segment7
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment7
                       ,
                        
                        (SELECT segment8
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment8
                       ,(SELECT segment9
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment9
                       ,(SELECT segment10
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment10
                       ,
                        
                        (SELECT segment1
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment1
                       ,
                        
                        (SELECT segment2
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment2
                       ,
                        
                        (SELECT segment3
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment3
                       ,
                        
                        (SELECT segment4
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment4
                       ,
                        
                        (SELECT segment5
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment5
                       ,
                        
                        (SELECT segment6
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment6
                       ,
                        
                        (SELECT segment7
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment7
                       ,
                        
                        (SELECT segment8
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment8
                       ,(SELECT segment9
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment9
                       ,(SELECT segment10
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment10
                       ,
                        
                        (SELECT segment1
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment1
                       ,(SELECT segment2
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment2
                       ,
                        
                        (SELECT segment3
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment3
                       ,
                        
                        (SELECT segment4
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment4
                       ,
                        
                        (SELECT segment5
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment5
                       ,
                        
                        (SELECT segment6
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment6
                       ,
                        
                        (SELECT segment7
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment7
                       ,
                        
                        (SELECT segment8
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment8
                       ,(SELECT segment9
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment9
                       ,(SELECT segment10
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment10
from  mtl_system_items_b  msi	
where msi.creation_date > sysdate - 365
 and (SELECT organization_code
                         FROM   mtl_parameters
                         WHERE  organization_id = msi.organization_id)= p_organization_code
union
 SELECT  msi.inventory_item_id
                       ,msi.inventory_item_id l_inventory_item_id
                       ,msi.description
                       ,msi.buyer_id
                       ,(SELECT NAME
                         FROM   ra_rules rr
                         WHERE  msi.accounting_rule_id = rr.rule_id) accounting_rule_name
                       ,msi.segment1
                       ,msi.attribute2
                       ,(SELECT  msib.segment1
                         FROM   mtl_system_items_b           msib
                               ,hr_all_organization_units_tl hou
                         WHERE  hou.LANGUAGE = 'US'
                         AND    hou.NAME LIKE 'OMA%'
                         AND    msib.organization_id = hou.organization_id
                         AND    (msib.end_date_active IS NULL OR
                               msib.end_date_active < SYSDATE)
                         AND    msib.inventory_item_id = msi.attribute9
                         AND ROWNUM<2) attribute9
                       ,msi.attribute11
                       ,msi.attribute12
                       ,msi.attribute13
                       ,msi.purchasing_item_flag
                       ,msi.shippable_item_flag
                       ,msi.customer_order_flag
                       ,msi.internal_order_flag
                       ,msi.service_item_flag
                       ,msi.inventory_item_flag
                       ,msi.inventory_asset_flag
                       ,msi.purchasing_enabled_flag
                       ,msi.customer_order_enabled_flag
                       ,msi.internal_order_enabled_flag
                       ,msi.so_transactions_flag
                       ,msi.mtl_transactions_enabled_flag
                       ,msi.stock_enabled_flag
                       ,msi.bom_enabled_flag
                       ,msi.build_in_wip_flag
                       ,msi.item_catalog_group_id
                       ,msi.catalog_status_flag
                       ,msi.returnable_flag
                       ,msi.default_shipping_org
                       ,msi.collateral_flag
                       ,msi.taxable_flag
                       ,msi.allow_item_desc_update_flag
                       ,msi.inspection_required_flag
                       ,msi.receipt_required_flag
                       ,msi.qty_rcv_tolerance
                       ,msi.list_price_per_unit
                       ,msi.asset_category_id
                       ,msi.unit_of_issue
                       ,msi.allow_substitute_receipts_flag
                       ,msi.allow_unordered_receipts_flag
                       ,msi.allow_express_delivery_flag
                       ,msi.days_early_receipt_allowed
                       ,msi.days_late_receipt_allowed
                       ,msi.receipt_days_exception_code
                       ,msi.receiving_routing_id
                       ,msi.auto_lot_alpha_prefix
                       ,msi.start_auto_lot_number
                       ,msi.lot_control_code
                       ,msi.shelf_life_code
                       ,msi.shelf_life_days
                       ,msi.serial_number_control_code
                       ,msi.source_type
                       ,msi.source_subinventory
                       ,msi.expense_account
                       ,msi.restrict_subinventories_code
                       ,msi.organization_id
                       ,(SELECT organization_code
                         FROM   mtl_parameters
                         WHERE  organization_id = msi.organization_id) organization_code
                       ,msi.source_organization_id
                       ,(SELECT organization_code
                         FROM   mtl_parameters
                         WHERE  organization_id = msi.source_organization_id) source_organization_code
                       ,msi.unit_weight
                       ,msi.weight_uom_code
                       ,msi.volume_uom_code
                       ,msi.unit_volume
                       ,msi.shrinkage_rate
                       ,msi.acceptable_early_days
                       ,msi.planning_time_fence_code
                       ,msi.lead_time_lot_size
                       ,msi.std_lot_size
                       ,msi.overrun_percentage
                       ,msi.mrp_calculate_atp_flag
                       ,msi.acceptable_rate_increase
                       ,msi.acceptable_rate_decrease
                       ,msi.planning_time_fence_days
                       ,msi.end_assembly_pegging_flag
                       ,msi.bom_item_type
                       ,msi.pick_components_flag
                       ,msi.replenish_to_order_flag
                       ,msi.atp_components_flag
                       ,msi.atp_flag
                       ,msi.wip_supply_type
                       ,msi.wip_supply_subinventory
                       ,msi.primary_uom_code
                       ,msi.primary_unit_of_measure
                       ,msi.allowed_units_lookup_code
                       ,msi.cost_of_sales_account
                       ,msi.sales_account
                       ,msi.default_include_in_rollup_flag
                       ,msi.inventory_item_status_code
                       ,msi.inventory_planning_code
                       ,msi.planner_code
                       ,msi.planning_make_buy_code
                       ,msi.fixed_lot_multiplier
                       ,msi.rounding_control_type
                       ,msi.postprocessing_lead_time
                       ,msi.preprocessing_lead_time
                       ,msi.full_lead_time
                       ,msi.mrp_safety_stock_percent
                       ,msi.mrp_safety_stock_code
                       ,msi.min_minmax_quantity
                       ,msi.max_minmax_quantity
                       ,msi.minimum_order_quantity
                       ,msi.fixed_order_quantity
                       ,msi.fixed_days_supply
                       ,msi.maximum_order_quantity
                       ,msi.creation_date
                       ,(SELECT rule_name
                         FROM   mtl_atp_rules mat
                         WHERE  msi.atp_rule_id = mat.rule_id) atp_rule_name
                       ,msi.reservable_type
                       ,msi.vendor_warranty_flag
                       ,msi.serviceable_product_flag
                       ,msi.material_billable_flag
                       ,msi.prorate_service_flag
                       ,msi.invoiceable_item_flag
                       ,msi.invoice_enabled_flag
                       ,msi.outside_operation_flag
                       ,msi.outside_operation_uom_type
                       ,msi.safety_stock_bucket_days
                       ,msi.costing_enabled_flag
                       ,msi.cycle_count_enabled_flag
                       ,msi.item_type
                       ,msi.ship_model_complete_flag
                       ,msi.mrp_planning_code
                       ,msi.ato_forecast_control
                       ,msi.release_time_fence_code
                       ,msi.release_time_fence_days
                       ,msi.container_item_flag
                       ,msi.vehicle_item_flag
                       ,msi.effectivity_control
                       ,msi.event_flag
                       ,msi.electronic_flag
                       ,msi.downloadable_flag
                       ,msi.comms_nl_trackable_flag
                       ,msi.orderable_on_web_flag
                       ,msi.web_status
                       ,msi.dimension_uom_code
                       ,msi.unit_length
                       ,msi.unit_width
                       ,msi.unit_height
                       ,msi.dual_uom_control
                       ,msi.dual_uom_deviation_high
                       ,msi.dual_uom_deviation_low
                       ,msi.contract_item_type_code
                       ,msi.serv_req_enabled_code
                       ,msi.serv_billing_enabled_flag
                       ,msi.default_so_source_type
                       ,msi.object_version_number
                       ,msi.tracking_quantity_ind
                       ,msi.secondary_default_ind
                       ,msi.so_authorization_flag
                       ,msi.attribute17
                       ,msi.attribute18
                       ,msi.attribute19
                       ,msi.attribute25
                       ,msi.expiration_action_code
                       ,msi.expiration_action_interval
                       ,msi.hazardous_material_flag
                       ,msi.recipe_enabled_flag
                       ,msi.retest_interval
                       ,msi.repair_leadtime
                       ,msi.gdsn_outbound_enabled_flag
                       ,msi.revision_qty_control_code
                       ,msi.start_auto_serial_number
                       ,msi.auto_serial_alpha_prefix
                       ,(SELECT concatenated_segments
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) legacy_expense_account
                       ,(SELECT concatenated_segments
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) legacy_cost_of_sales_account
                       ,(SELECT concatenated_segments
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) legacy_sales_account
                       ,
                        
                        (SELECT segment1
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment1
                       ,(SELECT segment2
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment2
                       ,
                        
                        (SELECT segment3
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment3
                       ,
                        
                        (SELECT segment4
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment4
                       ,
                        
                        (SELECT segment5
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment5
                       ,
                        
                        (SELECT segment6
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment6
                       ,
                        
                        (SELECT segment7
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment7
                       ,
                        
                        (SELECT segment8
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment8
                       ,(SELECT segment9
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment9
                       ,(SELECT segment10
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment10
                       ,
                        
                        (SELECT segment1
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment1
                       ,
                        
                        (SELECT segment2
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment2
                       ,
                        
                        (SELECT segment3
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment3
                       ,
                        
                        (SELECT segment4
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment4
                       ,
                        
                        (SELECT segment5
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment5
                       ,
                        
                        (SELECT segment6
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment6
                       ,
                        
                        (SELECT segment7
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment7
                       ,
                        
                        (SELECT segment8
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment8
                       ,(SELECT segment9
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment9
                       ,(SELECT segment10
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment10
                       ,
                        
                        (SELECT segment1
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment1
                       ,(SELECT segment2
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment2
                       ,
                        
                        (SELECT segment3
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment3
                       ,
                        
                        (SELECT segment4
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment4
                       ,
                        
                        (SELECT segment5
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment5
                       ,
                        
                        (SELECT segment6
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment6
                       ,
                        
                        (SELECT segment7
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment7
                       ,
                        
                        (SELECT segment8
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment8
                       ,(SELECT segment9
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment9
                       ,(SELECT segment10
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment10
from  mtl_system_items_b  msi	
where msi.inventory_item_status_code in ('Obsolete', 'XX_DISCONT')
and   msi.comms_nl_trackable_flag is not null
 and (SELECT organization_code
                         FROM   mtl_parameters
                         WHERE  organization_id = msi.organization_id)= p_organization_code
 union
 SELECT  msi.inventory_item_id
                       ,msi.inventory_item_id l_inventory_item_id
                       ,msi.description
                       ,msi.buyer_id
                       ,(SELECT NAME
                         FROM   ra_rules rr
                         WHERE  msi.accounting_rule_id = rr.rule_id) accounting_rule_name
                       ,msi.segment1
                       ,msi.attribute2
                       ,(SELECT  msib.segment1
                         FROM   mtl_system_items_b           msib
                               ,hr_all_organization_units_tl hou
                         WHERE  hou.LANGUAGE = 'US'
                         AND    hou.NAME LIKE 'OMA%'
                         AND    msib.organization_id = hou.organization_id
                         AND    (msib.end_date_active IS NULL OR
                               msib.end_date_active < SYSDATE)
                         AND    msib.inventory_item_id = msi.attribute9
                         AND ROWNUM<2) attribute9
                       ,msi.attribute11
                       ,msi.attribute12
                       ,msi.attribute13
                       ,msi.purchasing_item_flag
                       ,msi.shippable_item_flag
                       ,msi.customer_order_flag
                       ,msi.internal_order_flag
                       ,msi.service_item_flag
                       ,msi.inventory_item_flag
                       ,msi.inventory_asset_flag
                       ,msi.purchasing_enabled_flag
                       ,msi.customer_order_enabled_flag
                       ,msi.internal_order_enabled_flag
                       ,msi.so_transactions_flag
                       ,msi.mtl_transactions_enabled_flag
                       ,msi.stock_enabled_flag
                       ,msi.bom_enabled_flag
                       ,msi.build_in_wip_flag
                       ,msi.item_catalog_group_id
                       ,msi.catalog_status_flag
                       ,msi.returnable_flag
                       ,msi.default_shipping_org
                       ,msi.collateral_flag
                       ,msi.taxable_flag
                       ,msi.allow_item_desc_update_flag
                       ,msi.inspection_required_flag
                       ,msi.receipt_required_flag
                       ,msi.qty_rcv_tolerance
                       ,msi.list_price_per_unit
                       ,msi.asset_category_id
                       ,msi.unit_of_issue
                       ,msi.allow_substitute_receipts_flag
                       ,msi.allow_unordered_receipts_flag
                       ,msi.allow_express_delivery_flag
                       ,msi.days_early_receipt_allowed
                       ,msi.days_late_receipt_allowed
                       ,msi.receipt_days_exception_code
                       ,msi.receiving_routing_id
                       ,msi.auto_lot_alpha_prefix
                       ,msi.start_auto_lot_number
                       ,msi.lot_control_code
                       ,msi.shelf_life_code
                       ,msi.shelf_life_days
                       ,msi.serial_number_control_code
                       ,msi.source_type
                       ,msi.source_subinventory
                       ,msi.expense_account
                       ,msi.restrict_subinventories_code
                       ,msi.organization_id
                       ,(SELECT organization_code
                         FROM   mtl_parameters
                         WHERE  organization_id = msi.organization_id) organization_code
                       ,msi.source_organization_id
                       ,(SELECT organization_code
                         FROM   mtl_parameters
                         WHERE  organization_id = msi.source_organization_id) source_organization_code
                       ,msi.unit_weight
                       ,msi.weight_uom_code
                       ,msi.volume_uom_code
                       ,msi.unit_volume
                       ,msi.shrinkage_rate
                       ,msi.acceptable_early_days
                       ,msi.planning_time_fence_code
                       ,msi.lead_time_lot_size
                       ,msi.std_lot_size
                       ,msi.overrun_percentage
                       ,msi.mrp_calculate_atp_flag
                       ,msi.acceptable_rate_increase
                       ,msi.acceptable_rate_decrease
                       ,msi.planning_time_fence_days
                       ,msi.end_assembly_pegging_flag
                       ,msi.bom_item_type
                       ,msi.pick_components_flag
                       ,msi.replenish_to_order_flag
                       ,msi.atp_components_flag
                       ,msi.atp_flag
                       ,msi.wip_supply_type
                       ,msi.wip_supply_subinventory
                       ,msi.primary_uom_code
                       ,msi.primary_unit_of_measure
                       ,msi.allowed_units_lookup_code
                       ,msi.cost_of_sales_account
                       ,msi.sales_account
                       ,msi.default_include_in_rollup_flag
                       ,msi.inventory_item_status_code
                       ,msi.inventory_planning_code
                       ,msi.planner_code
                       ,msi.planning_make_buy_code
                       ,msi.fixed_lot_multiplier
                       ,msi.rounding_control_type
                       ,msi.postprocessing_lead_time
                       ,msi.preprocessing_lead_time
                       ,msi.full_lead_time
                       ,msi.mrp_safety_stock_percent
                       ,msi.mrp_safety_stock_code
                       ,msi.min_minmax_quantity
                       ,msi.max_minmax_quantity
                       ,msi.minimum_order_quantity
                       ,msi.fixed_order_quantity
                       ,msi.fixed_days_supply
                       ,msi.maximum_order_quantity
                       ,msi.creation_date
                       ,(SELECT rule_name
                         FROM   mtl_atp_rules mat
                         WHERE  msi.atp_rule_id = mat.rule_id) atp_rule_name
                       ,msi.reservable_type
                       ,msi.vendor_warranty_flag
                       ,msi.serviceable_product_flag
                       ,msi.material_billable_flag
                       ,msi.prorate_service_flag
                       ,msi.invoiceable_item_flag
                       ,msi.invoice_enabled_flag
                       ,msi.outside_operation_flag
                       ,msi.outside_operation_uom_type
                       ,msi.safety_stock_bucket_days
                       ,msi.costing_enabled_flag
                       ,msi.cycle_count_enabled_flag
                       ,msi.item_type
                       ,msi.ship_model_complete_flag
                       ,msi.mrp_planning_code
                       ,msi.ato_forecast_control
                       ,msi.release_time_fence_code
                       ,msi.release_time_fence_days
                       ,msi.container_item_flag
                       ,msi.vehicle_item_flag
                       ,msi.effectivity_control
                       ,msi.event_flag
                       ,msi.electronic_flag
                       ,msi.downloadable_flag
                       ,msi.comms_nl_trackable_flag
                       ,msi.orderable_on_web_flag
                       ,msi.web_status
                       ,msi.dimension_uom_code
                       ,msi.unit_length
                       ,msi.unit_width
                       ,msi.unit_height
                       ,msi.dual_uom_control
                       ,msi.dual_uom_deviation_high
                       ,msi.dual_uom_deviation_low
                       ,msi.contract_item_type_code
                       ,msi.serv_req_enabled_code
                       ,msi.serv_billing_enabled_flag
                       ,msi.default_so_source_type
                       ,msi.object_version_number
                       ,msi.tracking_quantity_ind
                       ,msi.secondary_default_ind
                       ,msi.so_authorization_flag
                       ,msi.attribute17
                       ,msi.attribute18
                       ,msi.attribute19
                       ,msi.attribute25
                       ,msi.expiration_action_code
                       ,msi.expiration_action_interval
                       ,msi.hazardous_material_flag
                       ,msi.recipe_enabled_flag
                       ,msi.retest_interval
                       ,msi.repair_leadtime
                       ,msi.gdsn_outbound_enabled_flag
                       ,msi.revision_qty_control_code
                       ,msi.start_auto_serial_number
                       ,msi.auto_serial_alpha_prefix
                       ,(SELECT concatenated_segments
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) legacy_expense_account
                       ,(SELECT concatenated_segments
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) legacy_cost_of_sales_account
                       ,(SELECT concatenated_segments
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) legacy_sales_account
                       ,
                        
                        (SELECT segment1
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment1
                       ,(SELECT segment2
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment2
                       ,
                        
                        (SELECT segment3
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment3
                       ,
                        
                        (SELECT segment4
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment4
                       ,
                        
                        (SELECT segment5
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment5
                       ,
                        
                        (SELECT segment6
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment6
                       ,
                        
                        (SELECT segment7
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment7
                       ,
                        
                        (SELECT segment8
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment8
                       ,(SELECT segment9
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment9
                       ,(SELECT segment10
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment10
                       ,
                        
                        (SELECT segment1
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment1
                       ,
                        
                        (SELECT segment2
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment2
                       ,
                        
                        (SELECT segment3
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment3
                       ,
                        
                        (SELECT segment4
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment4
                       ,
                        
                        (SELECT segment5
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment5
                       ,
                        
                        (SELECT segment6
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment6
                       ,
                        
                        (SELECT segment7
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment7
                       ,
                        
                        (SELECT segment8
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment8
                       ,(SELECT segment9
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment9
                       ,(SELECT segment10
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment10
                       ,
                        
                        (SELECT segment1
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment1
                       ,(SELECT segment2
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment2
                       ,
                        
                        (SELECT segment3
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment3
                       ,
                        
                        (SELECT segment4
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment4
                       ,
                        
                        (SELECT segment5
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment5
                       ,
                        
                        (SELECT segment6
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment6
                       ,
                        
                        (SELECT segment7
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment7
                       ,
                        
                        (SELECT segment8
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment8
                       ,(SELECT segment9
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment9
                       ,(SELECT segment10
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment10
from  mtl_system_items_b  msi
where msi.item_type = 'PTO'
 and (SELECT organization_code
                         FROM   mtl_parameters
                         WHERE  organization_id = msi.organization_id)= p_organization_code
union
 SELECT  msi.inventory_item_id
                       ,msi.inventory_item_id l_inventory_item_id
                       ,msi.description
                       ,msi.buyer_id
                       ,(SELECT NAME
                         FROM   ra_rules rr
                         WHERE  msi.accounting_rule_id = rr.rule_id) accounting_rule_name
                       ,msi.segment1
                       ,msi.attribute2
                       ,(SELECT  msib.segment1
                         FROM   mtl_system_items_b           msib
                               ,hr_all_organization_units_tl hou
                         WHERE  hou.LANGUAGE = 'US'
                         AND    hou.NAME LIKE 'OMA%'
                         AND    msib.organization_id = hou.organization_id
                         AND    (msib.end_date_active IS NULL OR
                               msib.end_date_active < SYSDATE)
                         AND    msib.inventory_item_id = msi.attribute9
                         AND ROWNUM<2) attribute9
                       ,msi.attribute11
                       ,msi.attribute12
                       ,msi.attribute13
                       ,msi.purchasing_item_flag
                       ,msi.shippable_item_flag
                       ,msi.customer_order_flag
                       ,msi.internal_order_flag
                       ,msi.service_item_flag
                       ,msi.inventory_item_flag
                       ,msi.inventory_asset_flag
                       ,msi.purchasing_enabled_flag
                       ,msi.customer_order_enabled_flag
                       ,msi.internal_order_enabled_flag
                       ,msi.so_transactions_flag
                       ,msi.mtl_transactions_enabled_flag
                       ,msi.stock_enabled_flag
                       ,msi.bom_enabled_flag
                       ,msi.build_in_wip_flag
                       ,msi.item_catalog_group_id
                       ,msi.catalog_status_flag
                       ,msi.returnable_flag
                       ,msi.default_shipping_org
                       ,msi.collateral_flag
                       ,msi.taxable_flag
                       ,msi.allow_item_desc_update_flag
                       ,msi.inspection_required_flag
                       ,msi.receipt_required_flag
                       ,msi.qty_rcv_tolerance
                       ,msi.list_price_per_unit
                       ,msi.asset_category_id
                       ,msi.unit_of_issue
                       ,msi.allow_substitute_receipts_flag
                       ,msi.allow_unordered_receipts_flag
                       ,msi.allow_express_delivery_flag
                       ,msi.days_early_receipt_allowed
                       ,msi.days_late_receipt_allowed
                       ,msi.receipt_days_exception_code
                       ,msi.receiving_routing_id
                       ,msi.auto_lot_alpha_prefix
                       ,msi.start_auto_lot_number
                       ,msi.lot_control_code
                       ,msi.shelf_life_code
                       ,msi.shelf_life_days
                       ,msi.serial_number_control_code
                       ,msi.source_type
                       ,msi.source_subinventory
                       ,msi.expense_account
                       ,msi.restrict_subinventories_code
                       ,msi.organization_id
                       ,(SELECT organization_code
                         FROM   mtl_parameters
                         WHERE  organization_id = msi.organization_id) organization_code
                       ,msi.source_organization_id
                       ,(SELECT organization_code
                         FROM   mtl_parameters
                         WHERE  organization_id = msi.source_organization_id) source_organization_code
                       ,msi.unit_weight
                       ,msi.weight_uom_code
                       ,msi.volume_uom_code
                       ,msi.unit_volume
                       ,msi.shrinkage_rate
                       ,msi.acceptable_early_days
                       ,msi.planning_time_fence_code
                       ,msi.lead_time_lot_size
                       ,msi.std_lot_size
                       ,msi.overrun_percentage
                       ,msi.mrp_calculate_atp_flag
                       ,msi.acceptable_rate_increase
                       ,msi.acceptable_rate_decrease
                       ,msi.planning_time_fence_days
                       ,msi.end_assembly_pegging_flag
                       ,msi.bom_item_type
                       ,msi.pick_components_flag
                       ,msi.replenish_to_order_flag
                       ,msi.atp_components_flag
                       ,msi.atp_flag
                       ,msi.wip_supply_type
                       ,msi.wip_supply_subinventory
                       ,msi.primary_uom_code
                       ,msi.primary_unit_of_measure
                       ,msi.allowed_units_lookup_code
                       ,msi.cost_of_sales_account
                       ,msi.sales_account
                       ,msi.default_include_in_rollup_flag
                       ,msi.inventory_item_status_code
                       ,msi.inventory_planning_code
                       ,msi.planner_code
                       ,msi.planning_make_buy_code
                       ,msi.fixed_lot_multiplier
                       ,msi.rounding_control_type
                       ,msi.postprocessing_lead_time
                       ,msi.preprocessing_lead_time
                       ,msi.full_lead_time
                       ,msi.mrp_safety_stock_percent
                       ,msi.mrp_safety_stock_code
                       ,msi.min_minmax_quantity
                       ,msi.max_minmax_quantity
                       ,msi.minimum_order_quantity
                       ,msi.fixed_order_quantity
                       ,msi.fixed_days_supply
                       ,msi.maximum_order_quantity
                       ,msi.creation_date
                       ,(SELECT rule_name
                         FROM   mtl_atp_rules mat
                         WHERE  msi.atp_rule_id = mat.rule_id) atp_rule_name
                       ,msi.reservable_type
                       ,msi.vendor_warranty_flag
                       ,msi.serviceable_product_flag
                       ,msi.material_billable_flag
                       ,msi.prorate_service_flag
                       ,msi.invoiceable_item_flag
                       ,msi.invoice_enabled_flag
                       ,msi.outside_operation_flag
                       ,msi.outside_operation_uom_type
                       ,msi.safety_stock_bucket_days
                       ,msi.costing_enabled_flag
                       ,msi.cycle_count_enabled_flag
                       ,msi.item_type
                       ,msi.ship_model_complete_flag
                       ,msi.mrp_planning_code
                       ,msi.ato_forecast_control
                       ,msi.release_time_fence_code
                       ,msi.release_time_fence_days
                       ,msi.container_item_flag
                       ,msi.vehicle_item_flag
                       ,msi.effectivity_control
                       ,msi.event_flag
                       ,msi.electronic_flag
                       ,msi.downloadable_flag
                       ,msi.comms_nl_trackable_flag
                       ,msi.orderable_on_web_flag
                       ,msi.web_status
                       ,msi.dimension_uom_code
                       ,msi.unit_length
                       ,msi.unit_width
                       ,msi.unit_height
                       ,msi.dual_uom_control
                       ,msi.dual_uom_deviation_high
                       ,msi.dual_uom_deviation_low
                       ,msi.contract_item_type_code
                       ,msi.serv_req_enabled_code
                       ,msi.serv_billing_enabled_flag
                       ,msi.default_so_source_type
                       ,msi.object_version_number
                       ,msi.tracking_quantity_ind
                       ,msi.secondary_default_ind
                       ,msi.so_authorization_flag
                       ,msi.attribute17
                       ,msi.attribute18
                       ,msi.attribute19
                       ,msi.attribute25
                       ,msi.expiration_action_code
                       ,msi.expiration_action_interval
                       ,msi.hazardous_material_flag
                       ,msi.recipe_enabled_flag
                       ,msi.retest_interval
                       ,msi.repair_leadtime
                       ,msi.gdsn_outbound_enabled_flag
                       ,msi.revision_qty_control_code
                       ,msi.start_auto_serial_number
                       ,msi.auto_serial_alpha_prefix
                       ,(SELECT concatenated_segments
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) legacy_expense_account
                       ,(SELECT concatenated_segments
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) legacy_cost_of_sales_account
                       ,(SELECT concatenated_segments
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) legacy_sales_account
                       ,
                        
                        (SELECT segment1
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment1
                       ,(SELECT segment2
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment2
                       ,
                        
                        (SELECT segment3
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment3
                       ,
                        
                        (SELECT segment4
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment4
                       ,
                        
                        (SELECT segment5
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment5
                       ,
                        
                        (SELECT segment6
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment6
                       ,
                        
                        (SELECT segment7
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment7
                       ,
                        
                        (SELECT segment8
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment8
                       ,(SELECT segment9
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment9
                       ,(SELECT segment10
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment10
                       ,
                        
                        (SELECT segment1
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment1
                       ,
                        
                        (SELECT segment2
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment2
                       ,
                        
                        (SELECT segment3
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment3
                       ,
                        
                        (SELECT segment4
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment4
                       ,
                        
                        (SELECT segment5
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment5
                       ,
                        
                        (SELECT segment6
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment6
                       ,
                        
                        (SELECT segment7
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment7
                       ,
                        
                        (SELECT segment8
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment8
                       ,(SELECT segment9
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment9
                       ,(SELECT segment10
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment10
                       ,
                        
                        (SELECT segment1
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment1
                       ,(SELECT segment2
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment2
                       ,
                        
                        (SELECT segment3
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment3
                       ,
                        
                        (SELECT segment4
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment4
                       ,
                        
                        (SELECT segment5
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment5
                       ,
                        
                        (SELECT segment6
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment6
                       ,
                        
                        (SELECT segment7
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment7
                       ,
                        
                        (SELECT segment8
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment8
                       ,(SELECT segment9
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment9
                       ,(SELECT segment10
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment10
from  mtl_system_items_b  msi,(select distinct bc.component_item_id
from bom_bill_of_materials_v bb, bom_components_b bc,(SELECT  msi.inventory_item_id
                       ,msi.inventory_item_id l_inventory_item_id
                       ,msi.description
                       ,msi.buyer_id
                       ,(SELECT NAME
                         FROM   ra_rules rr
                         WHERE  msi.accounting_rule_id = rr.rule_id) accounting_rule_name
                       ,msi.segment1
                       ,msi.attribute2
                       ,(SELECT  msib.segment1
                         FROM   mtl_system_items_b           msib
                               ,hr_all_organization_units_tl hou
                         WHERE  hou.LANGUAGE = 'US'
                         AND    hou.NAME LIKE 'OMA%'
                         AND    msib.organization_id = hou.organization_id
                         AND    (msib.end_date_active IS NULL OR
                               msib.end_date_active < SYSDATE)
                         AND    msib.inventory_item_id = msi.attribute9
                         AND ROWNUM<2) attribute9
                       ,msi.attribute11
                       ,msi.attribute12
                       ,msi.attribute13
                       ,msi.purchasing_item_flag
                       ,msi.shippable_item_flag
                       ,msi.customer_order_flag
                       ,msi.internal_order_flag
                       ,msi.service_item_flag
                       ,msi.inventory_item_flag
                       ,msi.inventory_asset_flag
                       ,msi.purchasing_enabled_flag
                       ,msi.customer_order_enabled_flag
                       ,msi.internal_order_enabled_flag
                       ,msi.so_transactions_flag
                       ,msi.mtl_transactions_enabled_flag
                       ,msi.stock_enabled_flag
                       ,msi.bom_enabled_flag
                       ,msi.build_in_wip_flag
                       ,msi.item_catalog_group_id
                       ,msi.catalog_status_flag
                       ,msi.returnable_flag
                       ,msi.default_shipping_org
                       ,msi.collateral_flag
                       ,msi.taxable_flag
                       ,msi.allow_item_desc_update_flag
                       ,msi.inspection_required_flag
                       ,msi.receipt_required_flag
                       ,msi.qty_rcv_tolerance
                       ,msi.list_price_per_unit
                       ,msi.asset_category_id
                       ,msi.unit_of_issue
                       ,msi.allow_substitute_receipts_flag
                       ,msi.allow_unordered_receipts_flag
                       ,msi.allow_express_delivery_flag
                       ,msi.days_early_receipt_allowed
                       ,msi.days_late_receipt_allowed
                       ,msi.receipt_days_exception_code
                       ,msi.receiving_routing_id
                       ,msi.auto_lot_alpha_prefix
                       ,msi.start_auto_lot_number
                       ,msi.lot_control_code
                       ,msi.shelf_life_code
                       ,msi.shelf_life_days
                       ,msi.serial_number_control_code
                       ,msi.source_type
                       ,msi.source_subinventory
                       ,msi.expense_account
                       ,msi.restrict_subinventories_code
                       ,msi.organization_id
                       ,(SELECT organization_code
                         FROM   mtl_parameters
                         WHERE  organization_id = msi.organization_id) organization_code
                       ,msi.source_organization_id
                       ,(SELECT organization_code
                         FROM   mtl_parameters
                         WHERE  organization_id = msi.source_organization_id) source_organization_code
                       ,msi.unit_weight
                       ,msi.weight_uom_code
                       ,msi.volume_uom_code
                       ,msi.unit_volume
                       ,msi.shrinkage_rate
                       ,msi.acceptable_early_days
                       ,msi.planning_time_fence_code
                       ,msi.lead_time_lot_size
                       ,msi.std_lot_size
                       ,msi.overrun_percentage
                       ,msi.mrp_calculate_atp_flag
                       ,msi.acceptable_rate_increase
                       ,msi.acceptable_rate_decrease
                       ,msi.planning_time_fence_days
                       ,msi.end_assembly_pegging_flag
                       ,msi.bom_item_type
                       ,msi.pick_components_flag
                       ,msi.replenish_to_order_flag
                       ,msi.atp_components_flag
                       ,msi.atp_flag
                       ,msi.wip_supply_type
                       ,msi.wip_supply_subinventory
                       ,msi.primary_uom_code
                       ,msi.primary_unit_of_measure
                       ,msi.allowed_units_lookup_code
                       ,msi.cost_of_sales_account
                       ,msi.sales_account
                       ,msi.default_include_in_rollup_flag
                       ,msi.inventory_item_status_code
                       ,msi.inventory_planning_code
                       ,msi.planner_code
                       ,msi.planning_make_buy_code
                       ,msi.fixed_lot_multiplier
                       ,msi.rounding_control_type
                       ,msi.postprocessing_lead_time
                       ,msi.preprocessing_lead_time
                       ,msi.full_lead_time
                       ,msi.mrp_safety_stock_percent
                       ,msi.mrp_safety_stock_code
                       ,msi.min_minmax_quantity
                       ,msi.max_minmax_quantity
                       ,msi.minimum_order_quantity
                       ,msi.fixed_order_quantity
                       ,msi.fixed_days_supply
                       ,msi.maximum_order_quantity
                       ,msi.creation_date
                       ,(SELECT rule_name
                         FROM   mtl_atp_rules mat
                         WHERE  msi.atp_rule_id = mat.rule_id) atp_rule_name
                       ,msi.reservable_type
                       ,msi.vendor_warranty_flag
                       ,msi.serviceable_product_flag
                       ,msi.material_billable_flag
                       ,msi.prorate_service_flag
                       ,msi.invoiceable_item_flag
                       ,msi.invoice_enabled_flag
                       ,msi.outside_operation_flag
                       ,msi.outside_operation_uom_type
                       ,msi.safety_stock_bucket_days
                       ,msi.costing_enabled_flag
                       ,msi.cycle_count_enabled_flag
                       ,msi.item_type
                       ,msi.ship_model_complete_flag
                       ,msi.mrp_planning_code
                       ,msi.ato_forecast_control
                       ,msi.release_time_fence_code
                       ,msi.release_time_fence_days
                       ,msi.container_item_flag
                       ,msi.vehicle_item_flag
                       ,msi.effectivity_control
                       ,msi.event_flag
                       ,msi.electronic_flag
                       ,msi.downloadable_flag
                       ,msi.comms_nl_trackable_flag
                       ,msi.orderable_on_web_flag
                       ,msi.web_status
                       ,msi.dimension_uom_code
                       ,msi.unit_length
                       ,msi.unit_width
                       ,msi.unit_height
                       ,msi.dual_uom_control
                       ,msi.dual_uom_deviation_high
                       ,msi.dual_uom_deviation_low
                       ,msi.contract_item_type_code
                       ,msi.serv_req_enabled_code
                       ,msi.serv_billing_enabled_flag
                       ,msi.default_so_source_type
                       ,msi.object_version_number
                       ,msi.tracking_quantity_ind
                       ,msi.secondary_default_ind
                       ,msi.so_authorization_flag
                       ,msi.attribute17
                       ,msi.attribute18
                       ,msi.attribute19
                       ,msi.attribute25
                       ,msi.expiration_action_code
                       ,msi.expiration_action_interval
                       ,msi.hazardous_material_flag
                       ,msi.recipe_enabled_flag
                       ,msi.retest_interval
                       ,msi.repair_leadtime
                       ,msi.gdsn_outbound_enabled_flag
                       ,msi.revision_qty_control_code
                       ,msi.start_auto_serial_number
                       ,msi.auto_serial_alpha_prefix
                       ,(SELECT concatenated_segments
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) legacy_expense_account
                       ,(SELECT concatenated_segments
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) legacy_cost_of_sales_account
                       ,(SELECT concatenated_segments
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) legacy_sales_account
                       ,
                        
                        (SELECT segment1
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment1
                       ,(SELECT segment2
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment2
                       ,
                        
                        (SELECT segment3
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment3
                       ,
                        
                        (SELECT segment4
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment4
                       ,
                        
                        (SELECT segment5
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment5
                       ,
                        
                        (SELECT segment6
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment6
                       ,
                        
                        (SELECT segment7
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment7
                       ,
                        
                        (SELECT segment8
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment8
                       ,(SELECT segment9
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment9
                       ,(SELECT segment10
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment10
                       ,
                        
                        (SELECT segment1
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment1
                       ,
                        
                        (SELECT segment2
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment2
                       ,
                        
                        (SELECT segment3
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment3
                       ,
                        
                        (SELECT segment4
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment4
                       ,
                        
                        (SELECT segment5
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment5
                       ,
                        
                        (SELECT segment6
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment6
                       ,
                        
                        (SELECT segment7
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment7
                       ,
                        
                        (SELECT segment8
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment8
                       ,(SELECT segment9
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment9
                       ,(SELECT segment10
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment10
                       ,
                        
                        (SELECT segment1
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment1
                       ,(SELECT segment2
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment2
                       ,
                        
                        (SELECT segment3
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment3
                       ,
                        
                        (SELECT segment4
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment4
                       ,
                        
                        (SELECT segment5
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment5
                       ,
                        
                        (SELECT segment6
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment6
                       ,
                        
                        (SELECT segment7
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment7
                       ,
                        
                        (SELECT segment8
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment8
                       ,(SELECT segment9
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment9
                       ,(SELECT segment10
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment10
from  mtl_system_items_b  msi
where   EXISTS (select mtt.inventory_item_id
                                  from mtl_material_transactions mtt
                                  where mtt.inventory_item_id = msi.inventory_item_id
                                  and   mtt.creation_date >sysdate -730)
								  and (SELECT organization_code
                         FROM   mtl_parameters
                         WHERE  organization_id = msi.organization_id)= p_organization_code
union								  
 SELECT  msi.inventory_item_id
                       ,msi.inventory_item_id l_inventory_item_id
                       ,msi.description
                       ,msi.buyer_id
                       ,(SELECT NAME
                         FROM   ra_rules rr
                         WHERE  msi.accounting_rule_id = rr.rule_id) accounting_rule_name
                       ,msi.segment1
                       ,msi.attribute2
                       ,(SELECT  msib.segment1
                         FROM   mtl_system_items_b           msib
                               ,hr_all_organization_units_tl hou
                         WHERE  hou.LANGUAGE = 'US'
                         AND    hou.NAME LIKE 'OMA%'
                         AND    msib.organization_id = hou.organization_id
                         AND    (msib.end_date_active IS NULL OR
                               msib.end_date_active < SYSDATE)
                         AND    msib.inventory_item_id = msi.attribute9
                         AND ROWNUM<2) attribute9
                       ,msi.attribute11
                       ,msi.attribute12
                       ,msi.attribute13
                       ,msi.purchasing_item_flag
                       ,msi.shippable_item_flag
                       ,msi.customer_order_flag
                       ,msi.internal_order_flag
                       ,msi.service_item_flag
                       ,msi.inventory_item_flag
                       ,msi.inventory_asset_flag
                       ,msi.purchasing_enabled_flag
                       ,msi.customer_order_enabled_flag
                       ,msi.internal_order_enabled_flag
                       ,msi.so_transactions_flag
                       ,msi.mtl_transactions_enabled_flag
                       ,msi.stock_enabled_flag
                       ,msi.bom_enabled_flag
                       ,msi.build_in_wip_flag
                       ,msi.item_catalog_group_id
                       ,msi.catalog_status_flag
                       ,msi.returnable_flag
                       ,msi.default_shipping_org
                       ,msi.collateral_flag
                       ,msi.taxable_flag
                       ,msi.allow_item_desc_update_flag
                       ,msi.inspection_required_flag
                       ,msi.receipt_required_flag
                       ,msi.qty_rcv_tolerance
                       ,msi.list_price_per_unit
                       ,msi.asset_category_id
                       ,msi.unit_of_issue
                       ,msi.allow_substitute_receipts_flag
                       ,msi.allow_unordered_receipts_flag
                       ,msi.allow_express_delivery_flag
                       ,msi.days_early_receipt_allowed
                       ,msi.days_late_receipt_allowed
                       ,msi.receipt_days_exception_code
                       ,msi.receiving_routing_id
                       ,msi.auto_lot_alpha_prefix
                       ,msi.start_auto_lot_number
                       ,msi.lot_control_code
                       ,msi.shelf_life_code
                       ,msi.shelf_life_days
                       ,msi.serial_number_control_code
                       ,msi.source_type
                       ,msi.source_subinventory
                       ,msi.expense_account
                       ,msi.restrict_subinventories_code
                       ,msi.organization_id
                       ,(SELECT organization_code
                         FROM   mtl_parameters
                         WHERE  organization_id = msi.organization_id) organization_code
                       ,msi.source_organization_id
                       ,(SELECT organization_code
                         FROM   mtl_parameters
                         WHERE  organization_id = msi.source_organization_id) source_organization_code
                       ,msi.unit_weight
                       ,msi.weight_uom_code
                       ,msi.volume_uom_code
                       ,msi.unit_volume
                       ,msi.shrinkage_rate
                       ,msi.acceptable_early_days
                       ,msi.planning_time_fence_code
                       ,msi.lead_time_lot_size
                       ,msi.std_lot_size
                       ,msi.overrun_percentage
                       ,msi.mrp_calculate_atp_flag
                       ,msi.acceptable_rate_increase
                       ,msi.acceptable_rate_decrease
                       ,msi.planning_time_fence_days
                       ,msi.end_assembly_pegging_flag
                       ,msi.bom_item_type
                       ,msi.pick_components_flag
                       ,msi.replenish_to_order_flag
                       ,msi.atp_components_flag
                       ,msi.atp_flag
                       ,msi.wip_supply_type
                       ,msi.wip_supply_subinventory
                       ,msi.primary_uom_code
                       ,msi.primary_unit_of_measure
                       ,msi.allowed_units_lookup_code
                       ,msi.cost_of_sales_account
                       ,msi.sales_account
                       ,msi.default_include_in_rollup_flag
                       ,msi.inventory_item_status_code
                       ,msi.inventory_planning_code
                       ,msi.planner_code
                       ,msi.planning_make_buy_code
                       ,msi.fixed_lot_multiplier
                       ,msi.rounding_control_type
                       ,msi.postprocessing_lead_time
                       ,msi.preprocessing_lead_time
                       ,msi.full_lead_time
                       ,msi.mrp_safety_stock_percent
                       ,msi.mrp_safety_stock_code
                       ,msi.min_minmax_quantity
                       ,msi.max_minmax_quantity
                       ,msi.minimum_order_quantity
                       ,msi.fixed_order_quantity
                       ,msi.fixed_days_supply
                       ,msi.maximum_order_quantity
                       ,msi.creation_date
                       ,(SELECT rule_name
                         FROM   mtl_atp_rules mat
                         WHERE  msi.atp_rule_id = mat.rule_id) atp_rule_name
                       ,msi.reservable_type
                       ,msi.vendor_warranty_flag
                       ,msi.serviceable_product_flag
                       ,msi.material_billable_flag
                       ,msi.prorate_service_flag
                       ,msi.invoiceable_item_flag
                       ,msi.invoice_enabled_flag
                       ,msi.outside_operation_flag
                       ,msi.outside_operation_uom_type
                       ,msi.safety_stock_bucket_days
                       ,msi.costing_enabled_flag
                       ,msi.cycle_count_enabled_flag
                       ,msi.item_type
                       ,msi.ship_model_complete_flag
                       ,msi.mrp_planning_code
                       ,msi.ato_forecast_control
                       ,msi.release_time_fence_code
                       ,msi.release_time_fence_days
                       ,msi.container_item_flag
                       ,msi.vehicle_item_flag
                       ,msi.effectivity_control
                       ,msi.event_flag
                       ,msi.electronic_flag
                       ,msi.downloadable_flag
                       ,msi.comms_nl_trackable_flag
                       ,msi.orderable_on_web_flag
                       ,msi.web_status
                       ,msi.dimension_uom_code
                       ,msi.unit_length
                       ,msi.unit_width
                       ,msi.unit_height
                       ,msi.dual_uom_control
                       ,msi.dual_uom_deviation_high
                       ,msi.dual_uom_deviation_low
                       ,msi.contract_item_type_code
                       ,msi.serv_req_enabled_code
                       ,msi.serv_billing_enabled_flag
                       ,msi.default_so_source_type
                       ,msi.object_version_number
                       ,msi.tracking_quantity_ind
                       ,msi.secondary_default_ind
                       ,msi.so_authorization_flag
                       ,msi.attribute17
                       ,msi.attribute18
                       ,msi.attribute19
                       ,msi.attribute25
                       ,msi.expiration_action_code
                       ,msi.expiration_action_interval
                       ,msi.hazardous_material_flag
                       ,msi.recipe_enabled_flag
                       ,msi.retest_interval
                       ,msi.repair_leadtime
                       ,msi.gdsn_outbound_enabled_flag
                       ,msi.revision_qty_control_code
                       ,msi.start_auto_serial_number
                       ,msi.auto_serial_alpha_prefix
                       ,(SELECT concatenated_segments
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) legacy_expense_account
                       ,(SELECT concatenated_segments
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) legacy_cost_of_sales_account
                       ,(SELECT concatenated_segments
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) legacy_sales_account
                       ,
                        
                        (SELECT segment1
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment1
                       ,(SELECT segment2
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment2
                       ,
                        
                        (SELECT segment3
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment3
                       ,
                        
                        (SELECT segment4
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment4
                       ,
                        
                        (SELECT segment5
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment5
                       ,
                        
                        (SELECT segment6
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment6
                       ,
                        
                        (SELECT segment7
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment7
                       ,
                        
                        (SELECT segment8
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment8
                       ,(SELECT segment9
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment9
                       ,(SELECT segment10
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment10
                       ,
                        
                        (SELECT segment1
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment1
                       ,
                        
                        (SELECT segment2
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment2
                       ,
                        
                        (SELECT segment3
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment3
                       ,
                        
                        (SELECT segment4
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment4
                       ,
                        
                        (SELECT segment5
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment5
                       ,
                        
                        (SELECT segment6
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment6
                       ,
                        
                        (SELECT segment7
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment7
                       ,
                        
                        (SELECT segment8
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment8
                       ,(SELECT segment9
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment9
                       ,(SELECT segment10
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment10
                       ,
                        
                        (SELECT segment1
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment1
                       ,(SELECT segment2
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment2
                       ,
                        
                        (SELECT segment3
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment3
                       ,
                        
                        (SELECT segment4
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment4
                       ,
                        
                        (SELECT segment5
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment5
                       ,
                        
                        (SELECT segment6
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment6
                       ,
                        
                        (SELECT segment7
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment7
                       ,
                        
                        (SELECT segment8
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment8
                       ,(SELECT segment9
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment9
                       ,(SELECT segment10
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment10
from  mtl_system_items_b  msi							  
where EXISTS (select ool.inventory_item_id
                                  from oe_order_lines_all ool
                                  where ool.inventory_item_id = msi.inventory_item_id
                                  and   ool.creation_date > sysdate -730)
and (SELECT organization_code
                         FROM   mtl_parameters
                         WHERE  organization_id = msi.organization_id)= p_organization_code
union
								  
	 SELECT  msi.inventory_item_id
                       ,msi.inventory_item_id l_inventory_item_id
                       ,msi.description
                       ,msi.buyer_id
                       ,(SELECT NAME
                         FROM   ra_rules rr
                         WHERE  msi.accounting_rule_id = rr.rule_id) accounting_rule_name
                       ,msi.segment1
                       ,msi.attribute2
                       ,(SELECT  msib.segment1
                         FROM   mtl_system_items_b           msib
                               ,hr_all_organization_units_tl hou
                         WHERE  hou.LANGUAGE = 'US'
                         AND    hou.NAME LIKE 'OMA%'
                         AND    msib.organization_id = hou.organization_id
                         AND    (msib.end_date_active IS NULL OR
                               msib.end_date_active < SYSDATE)
                         AND    msib.inventory_item_id = msi.attribute9
                         AND ROWNUM<2) attribute9
                       ,msi.attribute11
                       ,msi.attribute12
                       ,msi.attribute13
                       ,msi.purchasing_item_flag
                       ,msi.shippable_item_flag
                       ,msi.customer_order_flag
                       ,msi.internal_order_flag
                       ,msi.service_item_flag
                       ,msi.inventory_item_flag
                       ,msi.inventory_asset_flag
                       ,msi.purchasing_enabled_flag
                       ,msi.customer_order_enabled_flag
                       ,msi.internal_order_enabled_flag
                       ,msi.so_transactions_flag
                       ,msi.mtl_transactions_enabled_flag
                       ,msi.stock_enabled_flag
                       ,msi.bom_enabled_flag
                       ,msi.build_in_wip_flag
                       ,msi.item_catalog_group_id
                       ,msi.catalog_status_flag
                       ,msi.returnable_flag
                       ,msi.default_shipping_org
                       ,msi.collateral_flag
                       ,msi.taxable_flag
                       ,msi.allow_item_desc_update_flag
                       ,msi.inspection_required_flag
                       ,msi.receipt_required_flag
                       ,msi.qty_rcv_tolerance
                       ,msi.list_price_per_unit
                       ,msi.asset_category_id
                       ,msi.unit_of_issue
                       ,msi.allow_substitute_receipts_flag
                       ,msi.allow_unordered_receipts_flag
                       ,msi.allow_express_delivery_flag
                       ,msi.days_early_receipt_allowed
                       ,msi.days_late_receipt_allowed
                       ,msi.receipt_days_exception_code
                       ,msi.receiving_routing_id
                       ,msi.auto_lot_alpha_prefix
                       ,msi.start_auto_lot_number
                       ,msi.lot_control_code
                       ,msi.shelf_life_code
                       ,msi.shelf_life_days
                       ,msi.serial_number_control_code
                       ,msi.source_type
                       ,msi.source_subinventory
                       ,msi.expense_account
                       ,msi.restrict_subinventories_code
                       ,msi.organization_id
                       ,(SELECT organization_code
                         FROM   mtl_parameters
                         WHERE  organization_id = msi.organization_id) organization_code
                       ,msi.source_organization_id
                       ,(SELECT organization_code
                         FROM   mtl_parameters
                         WHERE  organization_id = msi.source_organization_id) source_organization_code
                       ,msi.unit_weight
                       ,msi.weight_uom_code
                       ,msi.volume_uom_code
                       ,msi.unit_volume
                       ,msi.shrinkage_rate
                       ,msi.acceptable_early_days
                       ,msi.planning_time_fence_code
                       ,msi.lead_time_lot_size
                       ,msi.std_lot_size
                       ,msi.overrun_percentage
                       ,msi.mrp_calculate_atp_flag
                       ,msi.acceptable_rate_increase
                       ,msi.acceptable_rate_decrease
                       ,msi.planning_time_fence_days
                       ,msi.end_assembly_pegging_flag
                       ,msi.bom_item_type
                       ,msi.pick_components_flag
                       ,msi.replenish_to_order_flag
                       ,msi.atp_components_flag
                       ,msi.atp_flag
                       ,msi.wip_supply_type
                       ,msi.wip_supply_subinventory
                       ,msi.primary_uom_code
                       ,msi.primary_unit_of_measure
                       ,msi.allowed_units_lookup_code
                       ,msi.cost_of_sales_account
                       ,msi.sales_account
                       ,msi.default_include_in_rollup_flag
                       ,msi.inventory_item_status_code
                       ,msi.inventory_planning_code
                       ,msi.planner_code
                       ,msi.planning_make_buy_code
                       ,msi.fixed_lot_multiplier
                       ,msi.rounding_control_type
                       ,msi.postprocessing_lead_time
                       ,msi.preprocessing_lead_time
                       ,msi.full_lead_time
                       ,msi.mrp_safety_stock_percent
                       ,msi.mrp_safety_stock_code
                       ,msi.min_minmax_quantity
                       ,msi.max_minmax_quantity
                       ,msi.minimum_order_quantity
                       ,msi.fixed_order_quantity
                       ,msi.fixed_days_supply
                       ,msi.maximum_order_quantity
                       ,msi.creation_date
                       ,(SELECT rule_name
                         FROM   mtl_atp_rules mat
                         WHERE  msi.atp_rule_id = mat.rule_id) atp_rule_name
                       ,msi.reservable_type
                       ,msi.vendor_warranty_flag
                       ,msi.serviceable_product_flag
                       ,msi.material_billable_flag
                       ,msi.prorate_service_flag
                       ,msi.invoiceable_item_flag
                       ,msi.invoice_enabled_flag
                       ,msi.outside_operation_flag
                       ,msi.outside_operation_uom_type
                       ,msi.safety_stock_bucket_days
                       ,msi.costing_enabled_flag
                       ,msi.cycle_count_enabled_flag
                       ,msi.item_type
                       ,msi.ship_model_complete_flag
                       ,msi.mrp_planning_code
                       ,msi.ato_forecast_control
                       ,msi.release_time_fence_code
                       ,msi.release_time_fence_days
                       ,msi.container_item_flag
                       ,msi.vehicle_item_flag
                       ,msi.effectivity_control
                       ,msi.event_flag
                       ,msi.electronic_flag
                       ,msi.downloadable_flag
                       ,msi.comms_nl_trackable_flag
                       ,msi.orderable_on_web_flag
                       ,msi.web_status
                       ,msi.dimension_uom_code
                       ,msi.unit_length
                       ,msi.unit_width
                       ,msi.unit_height
                       ,msi.dual_uom_control
                       ,msi.dual_uom_deviation_high
                       ,msi.dual_uom_deviation_low
                       ,msi.contract_item_type_code
                       ,msi.serv_req_enabled_code
                       ,msi.serv_billing_enabled_flag
                       ,msi.default_so_source_type
                       ,msi.object_version_number
                       ,msi.tracking_quantity_ind
                       ,msi.secondary_default_ind
                       ,msi.so_authorization_flag
                       ,msi.attribute17
                       ,msi.attribute18
                       ,msi.attribute19
                       ,msi.attribute25
                       ,msi.expiration_action_code
                       ,msi.expiration_action_interval
                       ,msi.hazardous_material_flag
                       ,msi.recipe_enabled_flag
                       ,msi.retest_interval
                       ,msi.repair_leadtime
                       ,msi.gdsn_outbound_enabled_flag
                       ,msi.revision_qty_control_code
                       ,msi.start_auto_serial_number
                       ,msi.auto_serial_alpha_prefix
                       ,(SELECT concatenated_segments
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) legacy_expense_account
                       ,(SELECT concatenated_segments
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) legacy_cost_of_sales_account
                       ,(SELECT concatenated_segments
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) legacy_sales_account
                       ,
                        
                        (SELECT segment1
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment1
                       ,(SELECT segment2
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment2
                       ,
                        
                        (SELECT segment3
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment3
                       ,
                        
                        (SELECT segment4
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment4
                       ,
                        
                        (SELECT segment5
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment5
                       ,
                        
                        (SELECT segment6
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment6
                       ,
                        
                        (SELECT segment7
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment7
                       ,
                        
                        (SELECT segment8
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment8
                       ,(SELECT segment9
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment9
                       ,(SELECT segment10
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment10
                       ,
                        
                        (SELECT segment1
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment1
                       ,
                        
                        (SELECT segment2
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment2
                       ,
                        
                        (SELECT segment3
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment3
                       ,
                        
                        (SELECT segment4
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment4
                       ,
                        
                        (SELECT segment5
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment5
                       ,
                        
                        (SELECT segment6
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment6
                       ,
                        
                        (SELECT segment7
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment7
                       ,
                        
                        (SELECT segment8
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment8
                       ,(SELECT segment9
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment9
                       ,(SELECT segment10
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment10
                       ,
                        
                        (SELECT segment1
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment1
                       ,(SELECT segment2
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment2
                       ,
                        
                        (SELECT segment3
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment3
                       ,
                        
                        (SELECT segment4
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment4
                       ,
                        
                        (SELECT segment5
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment5
                       ,
                        
                        (SELECT segment6
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment6
                       ,
                        
                        (SELECT segment7
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment7
                       ,
                        
                        (SELECT segment8
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment8
                       ,(SELECT segment9
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment9
                       ,(SELECT segment10
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment10
from  mtl_system_items_b  msi	
where EXISTS( select mmt.inventory_item_id
                                 from mtl_onhand_quantities mmt
                                 where mmt.inventory_item_id = msi.inventory_item_id)
 and (SELECT organization_code
                         FROM   mtl_parameters
                         WHERE  organization_id = msi.organization_id)= p_organization_code
union
	 SELECT  msi.inventory_item_id
                       ,msi.inventory_item_id l_inventory_item_id
                       ,msi.description
                       ,msi.buyer_id
                       ,(SELECT NAME
                         FROM   ra_rules rr
                         WHERE  msi.accounting_rule_id = rr.rule_id) accounting_rule_name
                       ,msi.segment1
                       ,msi.attribute2
                       ,(SELECT  msib.segment1
                         FROM   mtl_system_items_b           msib
                               ,hr_all_organization_units_tl hou
                         WHERE  hou.LANGUAGE = 'US'
                         AND    hou.NAME LIKE 'OMA%'
                         AND    msib.organization_id = hou.organization_id
                         AND    (msib.end_date_active IS NULL OR
                               msib.end_date_active < SYSDATE)
                         AND    msib.inventory_item_id = msi.attribute9
                         AND ROWNUM<2) attribute9
                       ,msi.attribute11
                       ,msi.attribute12
                       ,msi.attribute13
                       ,msi.purchasing_item_flag
                       ,msi.shippable_item_flag
                       ,msi.customer_order_flag
                       ,msi.internal_order_flag
                       ,msi.service_item_flag
                       ,msi.inventory_item_flag
                       ,msi.inventory_asset_flag
                       ,msi.purchasing_enabled_flag
                       ,msi.customer_order_enabled_flag
                       ,msi.internal_order_enabled_flag
                       ,msi.so_transactions_flag
                       ,msi.mtl_transactions_enabled_flag
                       ,msi.stock_enabled_flag
                       ,msi.bom_enabled_flag
                       ,msi.build_in_wip_flag
                       ,msi.item_catalog_group_id
                       ,msi.catalog_status_flag
                       ,msi.returnable_flag
                       ,msi.default_shipping_org
                       ,msi.collateral_flag
                       ,msi.taxable_flag
                       ,msi.allow_item_desc_update_flag
                       ,msi.inspection_required_flag
                       ,msi.receipt_required_flag
                       ,msi.qty_rcv_tolerance
                       ,msi.list_price_per_unit
                       ,msi.asset_category_id
                       ,msi.unit_of_issue
                       ,msi.allow_substitute_receipts_flag
                       ,msi.allow_unordered_receipts_flag
                       ,msi.allow_express_delivery_flag
                       ,msi.days_early_receipt_allowed
                       ,msi.days_late_receipt_allowed
                       ,msi.receipt_days_exception_code
                       ,msi.receiving_routing_id
                       ,msi.auto_lot_alpha_prefix
                       ,msi.start_auto_lot_number
                       ,msi.lot_control_code
                       ,msi.shelf_life_code
                       ,msi.shelf_life_days
                       ,msi.serial_number_control_code
                       ,msi.source_type
                       ,msi.source_subinventory
                       ,msi.expense_account
                       ,msi.restrict_subinventories_code
                       ,msi.organization_id
                       ,(SELECT organization_code
                         FROM   mtl_parameters
                         WHERE  organization_id = msi.organization_id) organization_code
                       ,msi.source_organization_id
                       ,(SELECT organization_code
                         FROM   mtl_parameters
                         WHERE  organization_id = msi.source_organization_id) source_organization_code
                       ,msi.unit_weight
                       ,msi.weight_uom_code
                       ,msi.volume_uom_code
                       ,msi.unit_volume
                       ,msi.shrinkage_rate
                       ,msi.acceptable_early_days
                       ,msi.planning_time_fence_code
                       ,msi.lead_time_lot_size
                       ,msi.std_lot_size
                       ,msi.overrun_percentage
                       ,msi.mrp_calculate_atp_flag
                       ,msi.acceptable_rate_increase
                       ,msi.acceptable_rate_decrease
                       ,msi.planning_time_fence_days
                       ,msi.end_assembly_pegging_flag
                       ,msi.bom_item_type
                       ,msi.pick_components_flag
                       ,msi.replenish_to_order_flag
                       ,msi.atp_components_flag
                       ,msi.atp_flag
                       ,msi.wip_supply_type
                       ,msi.wip_supply_subinventory
                       ,msi.primary_uom_code
                       ,msi.primary_unit_of_measure
                       ,msi.allowed_units_lookup_code
                       ,msi.cost_of_sales_account
                       ,msi.sales_account
                       ,msi.default_include_in_rollup_flag
                       ,msi.inventory_item_status_code
                       ,msi.inventory_planning_code
                       ,msi.planner_code
                       ,msi.planning_make_buy_code
                       ,msi.fixed_lot_multiplier
                       ,msi.rounding_control_type
                       ,msi.postprocessing_lead_time
                       ,msi.preprocessing_lead_time
                       ,msi.full_lead_time
                       ,msi.mrp_safety_stock_percent
                       ,msi.mrp_safety_stock_code
                       ,msi.min_minmax_quantity
                       ,msi.max_minmax_quantity
                       ,msi.minimum_order_quantity
                       ,msi.fixed_order_quantity
                       ,msi.fixed_days_supply
                       ,msi.maximum_order_quantity
                       ,msi.creation_date
                       ,(SELECT rule_name
                         FROM   mtl_atp_rules mat
                         WHERE  msi.atp_rule_id = mat.rule_id) atp_rule_name
                       ,msi.reservable_type
                       ,msi.vendor_warranty_flag
                       ,msi.serviceable_product_flag
                       ,msi.material_billable_flag
                       ,msi.prorate_service_flag
                       ,msi.invoiceable_item_flag
                       ,msi.invoice_enabled_flag
                       ,msi.outside_operation_flag
                       ,msi.outside_operation_uom_type
                       ,msi.safety_stock_bucket_days
                       ,msi.costing_enabled_flag
                       ,msi.cycle_count_enabled_flag
                       ,msi.item_type
                       ,msi.ship_model_complete_flag
                       ,msi.mrp_planning_code
                       ,msi.ato_forecast_control
                       ,msi.release_time_fence_code
                       ,msi.release_time_fence_days
                       ,msi.container_item_flag
                       ,msi.vehicle_item_flag
                       ,msi.effectivity_control
                       ,msi.event_flag
                       ,msi.electronic_flag
                       ,msi.downloadable_flag
                       ,msi.comms_nl_trackable_flag
                       ,msi.orderable_on_web_flag
                       ,msi.web_status
                       ,msi.dimension_uom_code
                       ,msi.unit_length
                       ,msi.unit_width
                       ,msi.unit_height
                       ,msi.dual_uom_control
                       ,msi.dual_uom_deviation_high
                       ,msi.dual_uom_deviation_low
                       ,msi.contract_item_type_code
                       ,msi.serv_req_enabled_code
                       ,msi.serv_billing_enabled_flag
                       ,msi.default_so_source_type
                       ,msi.object_version_number
                       ,msi.tracking_quantity_ind
                       ,msi.secondary_default_ind
                       ,msi.so_authorization_flag
                       ,msi.attribute17
                       ,msi.attribute18
                       ,msi.attribute19
                       ,msi.attribute25
                       ,msi.expiration_action_code
                       ,msi.expiration_action_interval
                       ,msi.hazardous_material_flag
                       ,msi.recipe_enabled_flag
                       ,msi.retest_interval
                       ,msi.repair_leadtime
                       ,msi.gdsn_outbound_enabled_flag
                       ,msi.revision_qty_control_code
                       ,msi.start_auto_serial_number
                       ,msi.auto_serial_alpha_prefix
                       ,(SELECT concatenated_segments
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) legacy_expense_account
                       ,(SELECT concatenated_segments
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) legacy_cost_of_sales_account
                       ,(SELECT concatenated_segments
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) legacy_sales_account
                       ,
                        
                        (SELECT segment1
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment1
                       ,(SELECT segment2
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment2
                       ,
                        
                        (SELECT segment3
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment3
                       ,
                        
                        (SELECT segment4
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment4
                       ,
                        
                        (SELECT segment5
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment5
                       ,
                        
                        (SELECT segment6
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment6
                       ,
                        
                        (SELECT segment7
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment7
                       ,
                        
                        (SELECT segment8
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment8
                       ,(SELECT segment9
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment9
                       ,(SELECT segment10
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment10
                       ,
                        
                        (SELECT segment1
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment1
                       ,
                        
                        (SELECT segment2
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment2
                       ,
                        
                        (SELECT segment3
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment3
                       ,
                        
                        (SELECT segment4
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment4
                       ,
                        
                        (SELECT segment5
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment5
                       ,
                        
                        (SELECT segment6
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment6
                       ,
                        
                        (SELECT segment7
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment7
                       ,
                        
                        (SELECT segment8
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment8
                       ,(SELECT segment9
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment9
                       ,(SELECT segment10
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment10
                       ,
                        
                        (SELECT segment1
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment1
                       ,(SELECT segment2
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment2
                       ,
                        
                        (SELECT segment3
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment3
                       ,
                        
                        (SELECT segment4
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment4
                       ,
                        
                        (SELECT segment5
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment5
                       ,
                        
                        (SELECT segment6
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment6
                       ,
                        
                        (SELECT segment7
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment7
                       ,
                        
                        (SELECT segment8
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment8
                       ,(SELECT segment9
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment9
                       ,(SELECT segment10
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment10
from  mtl_system_items_b  msi	
where msi.inventory_item_status_code = 'Active PTO'
 and (SELECT organization_code
                         FROM   mtl_parameters
                         WHERE  organization_id = msi.organization_id)= p_organization_code
union
 SELECT  msi.inventory_item_id
                       ,msi.inventory_item_id l_inventory_item_id
                       ,msi.description
                       ,msi.buyer_id
                       ,(SELECT NAME
                         FROM   ra_rules rr
                         WHERE  msi.accounting_rule_id = rr.rule_id) accounting_rule_name
                       ,msi.segment1
                       ,msi.attribute2
                       ,(SELECT  msib.segment1
                         FROM   mtl_system_items_b           msib
                               ,hr_all_organization_units_tl hou
                         WHERE  hou.LANGUAGE = 'US'
                         AND    hou.NAME LIKE 'OMA%'
                         AND    msib.organization_id = hou.organization_id
                         AND    (msib.end_date_active IS NULL OR
                               msib.end_date_active < SYSDATE)
                         AND    msib.inventory_item_id = msi.attribute9
                         AND ROWNUM<2) attribute9
                       ,msi.attribute11
                       ,msi.attribute12
                       ,msi.attribute13
                       ,msi.purchasing_item_flag
                       ,msi.shippable_item_flag
                       ,msi.customer_order_flag
                       ,msi.internal_order_flag
                       ,msi.service_item_flag
                       ,msi.inventory_item_flag
                       ,msi.inventory_asset_flag
                       ,msi.purchasing_enabled_flag
                       ,msi.customer_order_enabled_flag
                       ,msi.internal_order_enabled_flag
                       ,msi.so_transactions_flag
                       ,msi.mtl_transactions_enabled_flag
                       ,msi.stock_enabled_flag
                       ,msi.bom_enabled_flag
                       ,msi.build_in_wip_flag
                       ,msi.item_catalog_group_id
                       ,msi.catalog_status_flag
                       ,msi.returnable_flag
                       ,msi.default_shipping_org
                       ,msi.collateral_flag
                       ,msi.taxable_flag
                       ,msi.allow_item_desc_update_flag
                       ,msi.inspection_required_flag
                       ,msi.receipt_required_flag
                       ,msi.qty_rcv_tolerance
                       ,msi.list_price_per_unit
                       ,msi.asset_category_id
                       ,msi.unit_of_issue
                       ,msi.allow_substitute_receipts_flag
                       ,msi.allow_unordered_receipts_flag
                       ,msi.allow_express_delivery_flag
                       ,msi.days_early_receipt_allowed
                       ,msi.days_late_receipt_allowed
                       ,msi.receipt_days_exception_code
                       ,msi.receiving_routing_id
                       ,msi.auto_lot_alpha_prefix
                       ,msi.start_auto_lot_number
                       ,msi.lot_control_code
                       ,msi.shelf_life_code
                       ,msi.shelf_life_days
                       ,msi.serial_number_control_code
                       ,msi.source_type
                       ,msi.source_subinventory
                       ,msi.expense_account
                       ,msi.restrict_subinventories_code
                       ,msi.organization_id
                       ,(SELECT organization_code
                         FROM   mtl_parameters
                         WHERE  organization_id = msi.organization_id) organization_code
                       ,msi.source_organization_id
                       ,(SELECT organization_code
                         FROM   mtl_parameters
                         WHERE  organization_id = msi.source_organization_id) source_organization_code
                       ,msi.unit_weight
                       ,msi.weight_uom_code
                       ,msi.volume_uom_code
                       ,msi.unit_volume
                       ,msi.shrinkage_rate
                       ,msi.acceptable_early_days
                       ,msi.planning_time_fence_code
                       ,msi.lead_time_lot_size
                       ,msi.std_lot_size
                       ,msi.overrun_percentage
                       ,msi.mrp_calculate_atp_flag
                       ,msi.acceptable_rate_increase
                       ,msi.acceptable_rate_decrease
                       ,msi.planning_time_fence_days
                       ,msi.end_assembly_pegging_flag
                       ,msi.bom_item_type
                       ,msi.pick_components_flag
                       ,msi.replenish_to_order_flag
                       ,msi.atp_components_flag
                       ,msi.atp_flag
                       ,msi.wip_supply_type
                       ,msi.wip_supply_subinventory
                       ,msi.primary_uom_code
                       ,msi.primary_unit_of_measure
                       ,msi.allowed_units_lookup_code
                       ,msi.cost_of_sales_account
                       ,msi.sales_account
                       ,msi.default_include_in_rollup_flag
                       ,msi.inventory_item_status_code
                       ,msi.inventory_planning_code
                       ,msi.planner_code
                       ,msi.planning_make_buy_code
                       ,msi.fixed_lot_multiplier
                       ,msi.rounding_control_type
                       ,msi.postprocessing_lead_time
                       ,msi.preprocessing_lead_time
                       ,msi.full_lead_time
                       ,msi.mrp_safety_stock_percent
                       ,msi.mrp_safety_stock_code
                       ,msi.min_minmax_quantity
                       ,msi.max_minmax_quantity
                       ,msi.minimum_order_quantity
                       ,msi.fixed_order_quantity
                       ,msi.fixed_days_supply
                       ,msi.maximum_order_quantity
                       ,msi.creation_date
                       ,(SELECT rule_name
                         FROM   mtl_atp_rules mat
                         WHERE  msi.atp_rule_id = mat.rule_id) atp_rule_name
                       ,msi.reservable_type
                       ,msi.vendor_warranty_flag
                       ,msi.serviceable_product_flag
                       ,msi.material_billable_flag
                       ,msi.prorate_service_flag
                       ,msi.invoiceable_item_flag
                       ,msi.invoice_enabled_flag
                       ,msi.outside_operation_flag
                       ,msi.outside_operation_uom_type
                       ,msi.safety_stock_bucket_days
                       ,msi.costing_enabled_flag
                       ,msi.cycle_count_enabled_flag
                       ,msi.item_type
                       ,msi.ship_model_complete_flag
                       ,msi.mrp_planning_code
                       ,msi.ato_forecast_control
                       ,msi.release_time_fence_code
                       ,msi.release_time_fence_days
                       ,msi.container_item_flag
                       ,msi.vehicle_item_flag
                       ,msi.effectivity_control
                       ,msi.event_flag
                       ,msi.electronic_flag
                       ,msi.downloadable_flag
                       ,msi.comms_nl_trackable_flag
                       ,msi.orderable_on_web_flag
                       ,msi.web_status
                       ,msi.dimension_uom_code
                       ,msi.unit_length
                       ,msi.unit_width
                       ,msi.unit_height
                       ,msi.dual_uom_control
                       ,msi.dual_uom_deviation_high
                       ,msi.dual_uom_deviation_low
                       ,msi.contract_item_type_code
                       ,msi.serv_req_enabled_code
                       ,msi.serv_billing_enabled_flag
                       ,msi.default_so_source_type
                       ,msi.object_version_number
                       ,msi.tracking_quantity_ind
                       ,msi.secondary_default_ind
                       ,msi.so_authorization_flag
                       ,msi.attribute17
                       ,msi.attribute18
                       ,msi.attribute19
                       ,msi.attribute25
                       ,msi.expiration_action_code
                       ,msi.expiration_action_interval
                       ,msi.hazardous_material_flag
                       ,msi.recipe_enabled_flag
                       ,msi.retest_interval
                       ,msi.repair_leadtime
                       ,msi.gdsn_outbound_enabled_flag
                       ,msi.revision_qty_control_code
                       ,msi.start_auto_serial_number
                       ,msi.auto_serial_alpha_prefix
                       ,(SELECT concatenated_segments
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) legacy_expense_account
                       ,(SELECT concatenated_segments
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) legacy_cost_of_sales_account
                       ,(SELECT concatenated_segments
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) legacy_sales_account
                       ,
                        
                        (SELECT segment1
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment1
                       ,(SELECT segment2
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment2
                       ,
                        
                        (SELECT segment3
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment3
                       ,
                        
                        (SELECT segment4
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment4
                       ,
                        
                        (SELECT segment5
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment5
                       ,
                        
                        (SELECT segment6
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment6
                       ,
                        
                        (SELECT segment7
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment7
                       ,
                        
                        (SELECT segment8
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment8
                       ,(SELECT segment9
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment9
                       ,(SELECT segment10
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment10
                       ,
                        
                        (SELECT segment1
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment1
                       ,
                        
                        (SELECT segment2
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment2
                       ,
                        
                        (SELECT segment3
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment3
                       ,
                        
                        (SELECT segment4
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment4
                       ,
                        
                        (SELECT segment5
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment5
                       ,
                        
                        (SELECT segment6
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment6
                       ,
                        
                        (SELECT segment7
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment7
                       ,
                        
                        (SELECT segment8
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment8
                       ,(SELECT segment9
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment9
                       ,(SELECT segment10
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment10
                       ,
                        
                        (SELECT segment1
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment1
                       ,(SELECT segment2
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment2
                       ,
                        
                        (SELECT segment3
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment3
                       ,
                        
                        (SELECT segment4
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment4
                       ,
                        
                        (SELECT segment5
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment5
                       ,
                        
                        (SELECT segment6
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment6
                       ,
                        
                        (SELECT segment7
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment7
                       ,
                        
                        (SELECT segment8
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment8
                       ,(SELECT segment9
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment9
                       ,(SELECT segment10
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment10
from  mtl_system_items_b  msi	
where msi.inventory_item_status_code in ('XX_BETA','Inactive','Active','XX_PROD')
and   (msi.segment1 like ('%-S') or msi.segment1 like ('%-CS'))
 and (SELECT organization_code
                         FROM   mtl_parameters
                         WHERE  organization_id = msi.organization_id)= p_organization_code
union
 SELECT  msi.inventory_item_id
                       ,msi.inventory_item_id l_inventory_item_id
                       ,msi.description
                       ,msi.buyer_id
                       ,(SELECT NAME
                         FROM   ra_rules rr
                         WHERE  msi.accounting_rule_id = rr.rule_id) accounting_rule_name
                       ,msi.segment1
                       ,msi.attribute2
                       ,(SELECT  msib.segment1
                         FROM   mtl_system_items_b           msib
                               ,hr_all_organization_units_tl hou
                         WHERE  hou.LANGUAGE = 'US'
                         AND    hou.NAME LIKE 'OMA%'
                         AND    msib.organization_id = hou.organization_id
                         AND    (msib.end_date_active IS NULL OR
                               msib.end_date_active < SYSDATE)
                         AND    msib.inventory_item_id = msi.attribute9
                         AND ROWNUM<2) attribute9
                       ,msi.attribute11
                       ,msi.attribute12
                       ,msi.attribute13
                       ,msi.purchasing_item_flag
                       ,msi.shippable_item_flag
                       ,msi.customer_order_flag
                       ,msi.internal_order_flag
                       ,msi.service_item_flag
                       ,msi.inventory_item_flag
                       ,msi.inventory_asset_flag
                       ,msi.purchasing_enabled_flag
                       ,msi.customer_order_enabled_flag
                       ,msi.internal_order_enabled_flag
                       ,msi.so_transactions_flag
                       ,msi.mtl_transactions_enabled_flag
                       ,msi.stock_enabled_flag
                       ,msi.bom_enabled_flag
                       ,msi.build_in_wip_flag
                       ,msi.item_catalog_group_id
                       ,msi.catalog_status_flag
                       ,msi.returnable_flag
                       ,msi.default_shipping_org
                       ,msi.collateral_flag
                       ,msi.taxable_flag
                       ,msi.allow_item_desc_update_flag
                       ,msi.inspection_required_flag
                       ,msi.receipt_required_flag
                       ,msi.qty_rcv_tolerance
                       ,msi.list_price_per_unit
                       ,msi.asset_category_id
                       ,msi.unit_of_issue
                       ,msi.allow_substitute_receipts_flag
                       ,msi.allow_unordered_receipts_flag
                       ,msi.allow_express_delivery_flag
                       ,msi.days_early_receipt_allowed
                       ,msi.days_late_receipt_allowed
                       ,msi.receipt_days_exception_code
                       ,msi.receiving_routing_id
                       ,msi.auto_lot_alpha_prefix
                       ,msi.start_auto_lot_number
                       ,msi.lot_control_code
                       ,msi.shelf_life_code
                       ,msi.shelf_life_days
                       ,msi.serial_number_control_code
                       ,msi.source_type
                       ,msi.source_subinventory
                       ,msi.expense_account
                       ,msi.restrict_subinventories_code
                       ,msi.organization_id
                       ,(SELECT organization_code
                         FROM   mtl_parameters
                         WHERE  organization_id = msi.organization_id) organization_code
                       ,msi.source_organization_id
                       ,(SELECT organization_code
                         FROM   mtl_parameters
                         WHERE  organization_id = msi.source_organization_id) source_organization_code
                       ,msi.unit_weight
                       ,msi.weight_uom_code
                       ,msi.volume_uom_code
                       ,msi.unit_volume
                       ,msi.shrinkage_rate
                       ,msi.acceptable_early_days
                       ,msi.planning_time_fence_code
                       ,msi.lead_time_lot_size
                       ,msi.std_lot_size
                       ,msi.overrun_percentage
                       ,msi.mrp_calculate_atp_flag
                       ,msi.acceptable_rate_increase
                       ,msi.acceptable_rate_decrease
                       ,msi.planning_time_fence_days
                       ,msi.end_assembly_pegging_flag
                       ,msi.bom_item_type
                       ,msi.pick_components_flag
                       ,msi.replenish_to_order_flag
                       ,msi.atp_components_flag
                       ,msi.atp_flag
                       ,msi.wip_supply_type
                       ,msi.wip_supply_subinventory
                       ,msi.primary_uom_code
                       ,msi.primary_unit_of_measure
                       ,msi.allowed_units_lookup_code
                       ,msi.cost_of_sales_account
                       ,msi.sales_account
                       ,msi.default_include_in_rollup_flag
                       ,msi.inventory_item_status_code
                       ,msi.inventory_planning_code
                       ,msi.planner_code
                       ,msi.planning_make_buy_code
                       ,msi.fixed_lot_multiplier
                       ,msi.rounding_control_type
                       ,msi.postprocessing_lead_time
                       ,msi.preprocessing_lead_time
                       ,msi.full_lead_time
                       ,msi.mrp_safety_stock_percent
                       ,msi.mrp_safety_stock_code
                       ,msi.min_minmax_quantity
                       ,msi.max_minmax_quantity
                       ,msi.minimum_order_quantity
                       ,msi.fixed_order_quantity
                       ,msi.fixed_days_supply
                       ,msi.maximum_order_quantity
                       ,msi.creation_date
                       ,(SELECT rule_name
                         FROM   mtl_atp_rules mat
                         WHERE  msi.atp_rule_id = mat.rule_id) atp_rule_name
                       ,msi.reservable_type
                       ,msi.vendor_warranty_flag
                       ,msi.serviceable_product_flag
                       ,msi.material_billable_flag
                       ,msi.prorate_service_flag
                       ,msi.invoiceable_item_flag
                       ,msi.invoice_enabled_flag
                       ,msi.outside_operation_flag
                       ,msi.outside_operation_uom_type
                       ,msi.safety_stock_bucket_days
                       ,msi.costing_enabled_flag
                       ,msi.cycle_count_enabled_flag
                       ,msi.item_type
                       ,msi.ship_model_complete_flag
                       ,msi.mrp_planning_code
                       ,msi.ato_forecast_control
                       ,msi.release_time_fence_code
                       ,msi.release_time_fence_days
                       ,msi.container_item_flag
                       ,msi.vehicle_item_flag
                       ,msi.effectivity_control
                       ,msi.event_flag
                       ,msi.electronic_flag
                       ,msi.downloadable_flag
                       ,msi.comms_nl_trackable_flag
                       ,msi.orderable_on_web_flag
                       ,msi.web_status
                       ,msi.dimension_uom_code
                       ,msi.unit_length
                       ,msi.unit_width
                       ,msi.unit_height
                       ,msi.dual_uom_control
                       ,msi.dual_uom_deviation_high
                       ,msi.dual_uom_deviation_low
                       ,msi.contract_item_type_code
                       ,msi.serv_req_enabled_code
                       ,msi.serv_billing_enabled_flag
                       ,msi.default_so_source_type
                       ,msi.object_version_number
                       ,msi.tracking_quantity_ind
                       ,msi.secondary_default_ind
                       ,msi.so_authorization_flag
                       ,msi.attribute17
                       ,msi.attribute18
                       ,msi.attribute19
                       ,msi.attribute25
                       ,msi.expiration_action_code
                       ,msi.expiration_action_interval
                       ,msi.hazardous_material_flag
                       ,msi.recipe_enabled_flag
                       ,msi.retest_interval
                       ,msi.repair_leadtime
                       ,msi.gdsn_outbound_enabled_flag
                       ,msi.revision_qty_control_code
                       ,msi.start_auto_serial_number
                       ,msi.auto_serial_alpha_prefix
                       ,(SELECT concatenated_segments
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) legacy_expense_account
                       ,(SELECT concatenated_segments
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) legacy_cost_of_sales_account
                       ,(SELECT concatenated_segments
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) legacy_sales_account
                       ,
                        
                        (SELECT segment1
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment1
                       ,(SELECT segment2
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment2
                       ,
                        
                        (SELECT segment3
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment3
                       ,
                        
                        (SELECT segment4
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment4
                       ,
                        
                        (SELECT segment5
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment5
                       ,
                        
                        (SELECT segment6
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment6
                       ,
                        
                        (SELECT segment7
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment7
                       ,
                        
                        (SELECT segment8
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment8
                       ,(SELECT segment9
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment9
                       ,(SELECT segment10
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment10
                       ,
                        
                        (SELECT segment1
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment1
                       ,
                        
                        (SELECT segment2
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment2
                       ,
                        
                        (SELECT segment3
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment3
                       ,
                        
                        (SELECT segment4
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment4
                       ,
                        
                        (SELECT segment5
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment5
                       ,
                        
                        (SELECT segment6
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment6
                       ,
                        
                        (SELECT segment7
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment7
                       ,
                        
                        (SELECT segment8
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment8
                       ,(SELECT segment9
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment9
                       ,(SELECT segment10
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment10
                       ,
                        
                        (SELECT segment1
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment1
                       ,(SELECT segment2
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment2
                       ,
                        
                        (SELECT segment3
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment3
                       ,
                        
                        (SELECT segment4
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment4
                       ,
                        
                        (SELECT segment5
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment5
                       ,
                        
                        (SELECT segment6
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment6
                       ,
                        
                        (SELECT segment7
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment7
                       ,
                        
                        (SELECT segment8
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment8
                       ,(SELECT segment9
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment9
                       ,(SELECT segment10
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment10
from  mtl_system_items_b  msi	
where msi.creation_date > sysdate - 365
 and (SELECT organization_code
                         FROM   mtl_parameters
                         WHERE  organization_id = msi.organization_id)= p_organization_code
union
 SELECT  msi.inventory_item_id
                       ,msi.inventory_item_id l_inventory_item_id
                       ,msi.description
                       ,msi.buyer_id
                       ,(SELECT NAME
                         FROM   ra_rules rr
                         WHERE  msi.accounting_rule_id = rr.rule_id) accounting_rule_name
                       ,msi.segment1
                       ,msi.attribute2
                       ,(SELECT  msib.segment1
                         FROM   mtl_system_items_b           msib
                               ,hr_all_organization_units_tl hou
                         WHERE  hou.LANGUAGE = 'US'
                         AND    hou.NAME LIKE 'OMA%'
                         AND    msib.organization_id = hou.organization_id
                         AND    (msib.end_date_active IS NULL OR
                               msib.end_date_active < SYSDATE)
                         AND    msib.inventory_item_id = msi.attribute9
                         AND ROWNUM<2) attribute9
                       ,msi.attribute11
                       ,msi.attribute12
                       ,msi.attribute13
                       ,msi.purchasing_item_flag
                       ,msi.shippable_item_flag
                       ,msi.customer_order_flag
                       ,msi.internal_order_flag
                       ,msi.service_item_flag
                       ,msi.inventory_item_flag
                       ,msi.inventory_asset_flag
                       ,msi.purchasing_enabled_flag
                       ,msi.customer_order_enabled_flag
                       ,msi.internal_order_enabled_flag
                       ,msi.so_transactions_flag
                       ,msi.mtl_transactions_enabled_flag
                       ,msi.stock_enabled_flag
                       ,msi.bom_enabled_flag
                       ,msi.build_in_wip_flag
                       ,msi.item_catalog_group_id
                       ,msi.catalog_status_flag
                       ,msi.returnable_flag
                       ,msi.default_shipping_org
                       ,msi.collateral_flag
                       ,msi.taxable_flag
                       ,msi.allow_item_desc_update_flag
                       ,msi.inspection_required_flag
                       ,msi.receipt_required_flag
                       ,msi.qty_rcv_tolerance
                       ,msi.list_price_per_unit
                       ,msi.asset_category_id
                       ,msi.unit_of_issue
                       ,msi.allow_substitute_receipts_flag
                       ,msi.allow_unordered_receipts_flag
                       ,msi.allow_express_delivery_flag
                       ,msi.days_early_receipt_allowed
                       ,msi.days_late_receipt_allowed
                       ,msi.receipt_days_exception_code
                       ,msi.receiving_routing_id
                       ,msi.auto_lot_alpha_prefix
                       ,msi.start_auto_lot_number
                       ,msi.lot_control_code
                       ,msi.shelf_life_code
                       ,msi.shelf_life_days
                       ,msi.serial_number_control_code
                       ,msi.source_type
                       ,msi.source_subinventory
                       ,msi.expense_account
                       ,msi.restrict_subinventories_code
                       ,msi.organization_id
                       ,(SELECT organization_code
                         FROM   mtl_parameters
                         WHERE  organization_id = msi.organization_id) organization_code
                       ,msi.source_organization_id
                       ,(SELECT organization_code
                         FROM   mtl_parameters
                         WHERE  organization_id = msi.source_organization_id) source_organization_code
                       ,msi.unit_weight
                       ,msi.weight_uom_code
                       ,msi.volume_uom_code
                       ,msi.unit_volume
                       ,msi.shrinkage_rate
                       ,msi.acceptable_early_days
                       ,msi.planning_time_fence_code
                       ,msi.lead_time_lot_size
                       ,msi.std_lot_size
                       ,msi.overrun_percentage
                       ,msi.mrp_calculate_atp_flag
                       ,msi.acceptable_rate_increase
                       ,msi.acceptable_rate_decrease
                       ,msi.planning_time_fence_days
                       ,msi.end_assembly_pegging_flag
                       ,msi.bom_item_type
                       ,msi.pick_components_flag
                       ,msi.replenish_to_order_flag
                       ,msi.atp_components_flag
                       ,msi.atp_flag
                       ,msi.wip_supply_type
                       ,msi.wip_supply_subinventory
                       ,msi.primary_uom_code
                       ,msi.primary_unit_of_measure
                       ,msi.allowed_units_lookup_code
                       ,msi.cost_of_sales_account
                       ,msi.sales_account
                       ,msi.default_include_in_rollup_flag
                       ,msi.inventory_item_status_code
                       ,msi.inventory_planning_code
                       ,msi.planner_code
                       ,msi.planning_make_buy_code
                       ,msi.fixed_lot_multiplier
                       ,msi.rounding_control_type
                       ,msi.postprocessing_lead_time
                       ,msi.preprocessing_lead_time
                       ,msi.full_lead_time
                       ,msi.mrp_safety_stock_percent
                       ,msi.mrp_safety_stock_code
                       ,msi.min_minmax_quantity
                       ,msi.max_minmax_quantity
                       ,msi.minimum_order_quantity
                       ,msi.fixed_order_quantity
                       ,msi.fixed_days_supply
                       ,msi.maximum_order_quantity
                       ,msi.creation_date
                       ,(SELECT rule_name
                         FROM   mtl_atp_rules mat
                         WHERE  msi.atp_rule_id = mat.rule_id) atp_rule_name
                       ,msi.reservable_type
                       ,msi.vendor_warranty_flag
                       ,msi.serviceable_product_flag
                       ,msi.material_billable_flag
                       ,msi.prorate_service_flag
                       ,msi.invoiceable_item_flag
                       ,msi.invoice_enabled_flag
                       ,msi.outside_operation_flag
                       ,msi.outside_operation_uom_type
                       ,msi.safety_stock_bucket_days
                       ,msi.costing_enabled_flag
                       ,msi.cycle_count_enabled_flag
                       ,msi.item_type
                       ,msi.ship_model_complete_flag
                       ,msi.mrp_planning_code
                       ,msi.ato_forecast_control
                       ,msi.release_time_fence_code
                       ,msi.release_time_fence_days
                       ,msi.container_item_flag
                       ,msi.vehicle_item_flag
                       ,msi.effectivity_control
                       ,msi.event_flag
                       ,msi.electronic_flag
                       ,msi.downloadable_flag
                       ,msi.comms_nl_trackable_flag
                       ,msi.orderable_on_web_flag
                       ,msi.web_status
                       ,msi.dimension_uom_code
                       ,msi.unit_length
                       ,msi.unit_width
                       ,msi.unit_height
                       ,msi.dual_uom_control
                       ,msi.dual_uom_deviation_high
                       ,msi.dual_uom_deviation_low
                       ,msi.contract_item_type_code
                       ,msi.serv_req_enabled_code
                       ,msi.serv_billing_enabled_flag
                       ,msi.default_so_source_type
                       ,msi.object_version_number
                       ,msi.tracking_quantity_ind
                       ,msi.secondary_default_ind
                       ,msi.so_authorization_flag
                       ,msi.attribute17
                       ,msi.attribute18
                       ,msi.attribute19
                       ,msi.attribute25
                       ,msi.expiration_action_code
                       ,msi.expiration_action_interval
                       ,msi.hazardous_material_flag
                       ,msi.recipe_enabled_flag
                       ,msi.retest_interval
                       ,msi.repair_leadtime
                       ,msi.gdsn_outbound_enabled_flag
                       ,msi.revision_qty_control_code
                       ,msi.start_auto_serial_number
                       ,msi.auto_serial_alpha_prefix
                       ,(SELECT concatenated_segments
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) legacy_expense_account
                       ,(SELECT concatenated_segments
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) legacy_cost_of_sales_account
                       ,(SELECT concatenated_segments
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) legacy_sales_account
                       ,
                        
                        (SELECT segment1
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment1
                       ,(SELECT segment2
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment2
                       ,
                        
                        (SELECT segment3
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment3
                       ,
                        
                        (SELECT segment4
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment4
                       ,
                        
                        (SELECT segment5
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment5
                       ,
                        
                        (SELECT segment6
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment6
                       ,
                        
                        (SELECT segment7
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment7
                       ,
                        
                        (SELECT segment8
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment8
                       ,(SELECT segment9
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment9
                       ,(SELECT segment10
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment10
                       ,
                        
                        (SELECT segment1
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment1
                       ,
                        
                        (SELECT segment2
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment2
                       ,
                        
                        (SELECT segment3
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment3
                       ,
                        
                        (SELECT segment4
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment4
                       ,
                        
                        (SELECT segment5
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment5
                       ,
                        
                        (SELECT segment6
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment6
                       ,
                        
                        (SELECT segment7
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment7
                       ,
                        
                        (SELECT segment8
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment8
                       ,(SELECT segment9
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment9
                       ,(SELECT segment10
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment10
                       ,
                        
                        (SELECT segment1
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment1
                       ,(SELECT segment2
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment2
                       ,
                        
                        (SELECT segment3
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment3
                       ,
                        
                        (SELECT segment4
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment4
                       ,
                        
                        (SELECT segment5
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment5
                       ,
                        
                        (SELECT segment6
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment6
                       ,
                        
                        (SELECT segment7
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment7
                       ,
                        
                        (SELECT segment8
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment8
                       ,(SELECT segment9
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment9
                       ,(SELECT segment10
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment10
from  mtl_system_items_b  msi	
where msi.inventory_item_status_code in ('Obsolete', 'XX_DISCONT')
and   msi.comms_nl_trackable_flag is not null
 and (SELECT organization_code
                         FROM   mtl_parameters
                         WHERE  organization_id = msi.organization_id)= p_organization_code
 union
 SELECT  msi.inventory_item_id
                       ,msi.inventory_item_id l_inventory_item_id
                       ,msi.description
                       ,msi.buyer_id
                       ,(SELECT NAME
                         FROM   ra_rules rr
                         WHERE  msi.accounting_rule_id = rr.rule_id) accounting_rule_name
                       ,msi.segment1
                       ,msi.attribute2
                       ,(SELECT  msib.segment1
                         FROM   mtl_system_items_b           msib
                               ,hr_all_organization_units_tl hou
                         WHERE  hou.LANGUAGE = 'US'
                         AND    hou.NAME LIKE 'OMA%'
                         AND    msib.organization_id = hou.organization_id
                         AND    (msib.end_date_active IS NULL OR
                               msib.end_date_active < SYSDATE)
                         AND    msib.inventory_item_id = msi.attribute9
                         AND ROWNUM<2) attribute9
                       ,msi.attribute11
                       ,msi.attribute12
                       ,msi.attribute13
                       ,msi.purchasing_item_flag
                       ,msi.shippable_item_flag
                       ,msi.customer_order_flag
                       ,msi.internal_order_flag
                       ,msi.service_item_flag
                       ,msi.inventory_item_flag
                       ,msi.inventory_asset_flag
                       ,msi.purchasing_enabled_flag
                       ,msi.customer_order_enabled_flag
                       ,msi.internal_order_enabled_flag
                       ,msi.so_transactions_flag
                       ,msi.mtl_transactions_enabled_flag
                       ,msi.stock_enabled_flag
                       ,msi.bom_enabled_flag
                       ,msi.build_in_wip_flag
                       ,msi.item_catalog_group_id
                       ,msi.catalog_status_flag
                       ,msi.returnable_flag
                       ,msi.default_shipping_org
                       ,msi.collateral_flag
                       ,msi.taxable_flag
                       ,msi.allow_item_desc_update_flag
                       ,msi.inspection_required_flag
                       ,msi.receipt_required_flag
                       ,msi.qty_rcv_tolerance
                       ,msi.list_price_per_unit
                       ,msi.asset_category_id
                       ,msi.unit_of_issue
                       ,msi.allow_substitute_receipts_flag
                       ,msi.allow_unordered_receipts_flag
                       ,msi.allow_express_delivery_flag
                       ,msi.days_early_receipt_allowed
                       ,msi.days_late_receipt_allowed
                       ,msi.receipt_days_exception_code
                       ,msi.receiving_routing_id
                       ,msi.auto_lot_alpha_prefix
                       ,msi.start_auto_lot_number
                       ,msi.lot_control_code
                       ,msi.shelf_life_code
                       ,msi.shelf_life_days
                       ,msi.serial_number_control_code
                       ,msi.source_type
                       ,msi.source_subinventory
                       ,msi.expense_account
                       ,msi.restrict_subinventories_code
                       ,msi.organization_id
                       ,(SELECT organization_code
                         FROM   mtl_parameters
                         WHERE  organization_id = msi.organization_id) organization_code
                       ,msi.source_organization_id
                       ,(SELECT organization_code
                         FROM   mtl_parameters
                         WHERE  organization_id = msi.source_organization_id) source_organization_code
                       ,msi.unit_weight
                       ,msi.weight_uom_code
                       ,msi.volume_uom_code
                       ,msi.unit_volume
                       ,msi.shrinkage_rate
                       ,msi.acceptable_early_days
                       ,msi.planning_time_fence_code
                       ,msi.lead_time_lot_size
                       ,msi.std_lot_size
                       ,msi.overrun_percentage
                       ,msi.mrp_calculate_atp_flag
                       ,msi.acceptable_rate_increase
                       ,msi.acceptable_rate_decrease
                       ,msi.planning_time_fence_days
                       ,msi.end_assembly_pegging_flag
                       ,msi.bom_item_type
                       ,msi.pick_components_flag
                       ,msi.replenish_to_order_flag
                       ,msi.atp_components_flag
                       ,msi.atp_flag
                       ,msi.wip_supply_type
                       ,msi.wip_supply_subinventory
                       ,msi.primary_uom_code
                       ,msi.primary_unit_of_measure
                       ,msi.allowed_units_lookup_code
                       ,msi.cost_of_sales_account
                       ,msi.sales_account
                       ,msi.default_include_in_rollup_flag
                       ,msi.inventory_item_status_code
                       ,msi.inventory_planning_code
                       ,msi.planner_code
                       ,msi.planning_make_buy_code
                       ,msi.fixed_lot_multiplier
                       ,msi.rounding_control_type
                       ,msi.postprocessing_lead_time
                       ,msi.preprocessing_lead_time
                       ,msi.full_lead_time
                       ,msi.mrp_safety_stock_percent
                       ,msi.mrp_safety_stock_code
                       ,msi.min_minmax_quantity
                       ,msi.max_minmax_quantity
                       ,msi.minimum_order_quantity
                       ,msi.fixed_order_quantity
                       ,msi.fixed_days_supply
                       ,msi.maximum_order_quantity
                       ,msi.creation_date
                       ,(SELECT rule_name
                         FROM   mtl_atp_rules mat
                         WHERE  msi.atp_rule_id = mat.rule_id) atp_rule_name
                       ,msi.reservable_type
                       ,msi.vendor_warranty_flag
                       ,msi.serviceable_product_flag
                       ,msi.material_billable_flag
                       ,msi.prorate_service_flag
                       ,msi.invoiceable_item_flag
                       ,msi.invoice_enabled_flag
                       ,msi.outside_operation_flag
                       ,msi.outside_operation_uom_type
                       ,msi.safety_stock_bucket_days
                       ,msi.costing_enabled_flag
                       ,msi.cycle_count_enabled_flag
                       ,msi.item_type
                       ,msi.ship_model_complete_flag
                       ,msi.mrp_planning_code
                       ,msi.ato_forecast_control
                       ,msi.release_time_fence_code
                       ,msi.release_time_fence_days
                       ,msi.container_item_flag
                       ,msi.vehicle_item_flag
                       ,msi.effectivity_control
                       ,msi.event_flag
                       ,msi.electronic_flag
                       ,msi.downloadable_flag
                       ,msi.comms_nl_trackable_flag
                       ,msi.orderable_on_web_flag
                       ,msi.web_status
                       ,msi.dimension_uom_code
                       ,msi.unit_length
                       ,msi.unit_width
                       ,msi.unit_height
                       ,msi.dual_uom_control
                       ,msi.dual_uom_deviation_high
                       ,msi.dual_uom_deviation_low
                       ,msi.contract_item_type_code
                       ,msi.serv_req_enabled_code
                       ,msi.serv_billing_enabled_flag
                       ,msi.default_so_source_type
                       ,msi.object_version_number
                       ,msi.tracking_quantity_ind
                       ,msi.secondary_default_ind
                       ,msi.so_authorization_flag
                       ,msi.attribute17
                       ,msi.attribute18
                       ,msi.attribute19
                       ,msi.attribute25
                       ,msi.expiration_action_code
                       ,msi.expiration_action_interval
                       ,msi.hazardous_material_flag
                       ,msi.recipe_enabled_flag
                       ,msi.retest_interval
                       ,msi.repair_leadtime
                       ,msi.gdsn_outbound_enabled_flag
                       ,msi.revision_qty_control_code
                       ,msi.start_auto_serial_number
                       ,msi.auto_serial_alpha_prefix
                       ,(SELECT concatenated_segments
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) legacy_expense_account
                       ,(SELECT concatenated_segments
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) legacy_cost_of_sales_account
                       ,(SELECT concatenated_segments
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) legacy_sales_account
                       ,
                        
                        (SELECT segment1
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment1
                       ,(SELECT segment2
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment2
                       ,
                        
                        (SELECT segment3
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment3
                       ,
                        
                        (SELECT segment4
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment4
                       ,
                        
                        (SELECT segment5
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment5
                       ,
                        
                        (SELECT segment6
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment6
                       ,
                        
                        (SELECT segment7
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment7
                       ,
                        
                        (SELECT segment8
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment8
                       ,(SELECT segment9
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment9
                       ,(SELECT segment10
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.expense_account) expense_acct_segment10
                       ,
                        
                        (SELECT segment1
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment1
                       ,
                        
                        (SELECT segment2
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment2
                       ,
                        
                        (SELECT segment3
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment3
                       ,
                        
                        (SELECT segment4
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment4
                       ,
                        
                        (SELECT segment5
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment5
                       ,
                        
                        (SELECT segment6
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment6
                       ,
                        
                        (SELECT segment7
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment7
                       ,
                        
                        (SELECT segment8
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment8
                       ,(SELECT segment9
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment9
                       ,(SELECT segment10
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id =
                                msi.cost_of_sales_account) cost_of_sales_acct_segment10
                       ,
                        
                        (SELECT segment1
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment1
                       ,(SELECT segment2
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment2
                       ,
                        
                        (SELECT segment3
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment3
                       ,
                        
                        (SELECT segment4
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment4
                       ,
                        
                        (SELECT segment5
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment5
                       ,
                        
                        (SELECT segment6
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment6
                       ,
                        
                        (SELECT segment7
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment7
                       ,
                        
                        (SELECT segment8
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment8
                       ,(SELECT segment9
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment9
                       ,(SELECT segment10
                         FROM   gl_code_combinations_kfv gcck
                         WHERE  gcck.code_combination_id = msi.sales_account) sales_acct_segment10
from  mtl_system_items_b  msi
where msi.item_type = 'PTO'
 and (SELECT organization_code
                         FROM   mtl_parameters
                         WHERE  organization_id = msi.organization_id)= p_organization_code)mi
 where mi.inventory_item_id = bb.assembly_item_id
and   bc.bill_sequence_id = bb.bill_sequence_id)BBC
where bbc.component_item_id = msi.inventory_item_id
and  (SELECT organization_code
                         FROM   mtl_parameters
                         WHERE  organization_id = msi.organization_id)= p_organization_code) item_cur
      ,mtl_item_revisions_b mir
      ,mtl_item_revisions_tl mirt
WHERE  organization_code = p_organization_code ----IN('OMA','UME','USB','USE','UTP');
AND    mir.inventory_item_id = item_cur.inventory_item_id
AND    mir.organization_id = item_cur.organization_id
AND    mirt.inventory_item_id = item_cur.inventory_item_id
AND    mirt.organization_id = item_cur.organization_id
AND    mirt.LANGUAGE = 'US'
AND    mirt.source_lang = 'US'
AND    mirt.revision_id = mir.revision_id;







  
  /* Cursor for the BOM Exploded Components */
  
    CURSOR c_org_bom_exp_items IS
    
      SELECT xx.*
            ,mir.revision_id
            ,mir.revision
            ,mir.revision_label
            ,mir.description revision_description
            ,mir.effectivity_date
            ,mir.implementation_date
            ,mir.ecn_initiation_date
            ,mir.change_notice
            ,mir.attribute10 r_attribute10
            ,mir.revised_item_sequence_id
            ,mirt.revision_id tl_revision_id
            ,mirt.LANGUAGE LANGUAGE
            ,mirt.source_lang
            ,mirt.description tl_description
      FROM   (SELECT  msi.inventory_item_id
                             ,msi.inventory_item_id l_inventory_item_id
                             ,msi.description
                             ,msi.buyer_id
                             ,(SELECT NAME
                               FROM   ra_rules rr
                               WHERE  msi.accounting_rule_id = rr.rule_id) accounting_rule_name
                             ,msi.segment1
                             ,msi.attribute2
                             ,(SELECT  msib.segment1
                               FROM   mtl_system_items_b           msib
                                     ,hr_all_organization_units_tl hou
                               WHERE  hou.LANGUAGE = 'US'
                               AND    hou.NAME LIKE 'OMA%'
                               AND    msib.organization_id = hou.organization_id
                               AND    (msib.end_date_active IS NULL OR
                                     msib.end_date_active < SYSDATE)
                               AND    msib.inventory_item_id = msi.attribute9
                               AND ROWNUM<2)  attribute9
                             ,msi.attribute11
                             ,msi.attribute12
                             ,msi.attribute13
                             ,msi.purchasing_item_flag
                             ,msi.shippable_item_flag
                             ,msi.customer_order_flag
                             ,msi.internal_order_flag
                             ,msi.service_item_flag
                             ,msi.inventory_item_flag
                             ,msi.inventory_asset_flag
                             ,msi.purchasing_enabled_flag
                             ,msi.customer_order_enabled_flag
                             ,msi.internal_order_enabled_flag
                             ,msi.so_transactions_flag
                             ,msi.mtl_transactions_enabled_flag
                             ,msi.stock_enabled_flag
                             ,msi.bom_enabled_flag
                             ,msi.build_in_wip_flag
                             ,msi.item_catalog_group_id
                             ,msi.catalog_status_flag
                             ,msi.returnable_flag
                             ,msi.default_shipping_org
                             ,msi.collateral_flag
                             ,msi.taxable_flag
                             ,msi.allow_item_desc_update_flag
                             ,msi.inspection_required_flag
                             ,msi.receipt_required_flag
                             ,msi.qty_rcv_tolerance
                             ,msi.list_price_per_unit
                             ,msi.asset_category_id
                             ,msi.unit_of_issue
                             ,msi.allow_substitute_receipts_flag
                             ,msi.allow_unordered_receipts_flag
                             ,msi.allow_express_delivery_flag
                             ,msi.days_early_receipt_allowed
                             ,msi.days_late_receipt_allowed
                             ,msi.receipt_days_exception_code
                             ,msi.receiving_routing_id
                             ,msi.auto_lot_alpha_prefix
                             ,msi.start_auto_lot_number
                             ,msi.lot_control_code
                             ,msi.shelf_life_code
                             ,msi.shelf_life_days
                             ,msi.serial_number_control_code
                             ,msi.source_type
                             ,msi.source_subinventory
                             ,msi.expense_account
                             ,msi.restrict_subinventories_code
                             ,msi.organization_id
                             ,(SELECT organization_code
                               FROM   mtl_parameters
                               WHERE  organization_id = msi.organization_id) organization_code
                             ,msi.source_organization_id
                             ,(SELECT organization_code
                               FROM   mtl_parameters
                               WHERE  organization_id =
                                      msi.source_organization_id) source_organization_code
                             ,msi.unit_weight
                             ,msi.weight_uom_code
                             ,msi.volume_uom_code
                             ,msi.unit_volume
                             ,msi.shrinkage_rate
                             ,msi.acceptable_early_days
                             ,msi.planning_time_fence_code
                             ,msi.lead_time_lot_size
                             ,msi.std_lot_size
                             ,msi.overrun_percentage
                             ,msi.mrp_calculate_atp_flag
                             ,msi.acceptable_rate_increase
                             ,msi.acceptable_rate_decrease
                             ,msi.planning_time_fence_days
                             ,msi.end_assembly_pegging_flag
                             ,msi.bom_item_type
                             ,msi.pick_components_flag
                             ,msi.replenish_to_order_flag
                             ,msi.atp_components_flag
                             ,msi.atp_flag
                             ,msi.wip_supply_type
                             ,msi.wip_supply_subinventory
                             ,msi.primary_uom_code
                             ,msi.primary_unit_of_measure
                             ,msi.allowed_units_lookup_code
                             ,msi.cost_of_sales_account
                             ,msi.sales_account
                             ,msi.default_include_in_rollup_flag
                             ,msi.inventory_item_status_code
                             ,msi.inventory_planning_code
                             ,msi.planner_code
                             ,msi.planning_make_buy_code
                             ,msi.fixed_lot_multiplier
                             ,msi.rounding_control_type
                             ,msi.postprocessing_lead_time
                             ,msi.preprocessing_lead_time
                             ,msi.full_lead_time
                             ,msi.mrp_safety_stock_percent
                             ,msi.mrp_safety_stock_code
                             ,msi.min_minmax_quantity
                             ,msi.max_minmax_quantity
                             ,msi.minimum_order_quantity
                             ,msi.fixed_order_quantity
                             ,msi.fixed_days_supply
                             ,msi.maximum_order_quantity
                             ,msi.creation_date
                             ,(SELECT rule_name
                               FROM   mtl_atp_rules mat
                               WHERE  msi.atp_rule_id = mat.rule_id) atp_rule_name
                             ,msi.reservable_type
                             ,msi.vendor_warranty_flag
                             ,msi.serviceable_product_flag
                             ,msi.material_billable_flag
                             ,msi.prorate_service_flag
                             ,msi.invoiceable_item_flag
                             ,msi.invoice_enabled_flag
                             ,msi.outside_operation_flag
                             ,msi.outside_operation_uom_type
                             ,msi.safety_stock_bucket_days
                             ,msi.costing_enabled_flag
                             ,msi.cycle_count_enabled_flag
                             ,msi.item_type
                             ,msi.ship_model_complete_flag
                             ,msi.mrp_planning_code
                             ,msi.ato_forecast_control
                             ,msi.release_time_fence_code
                             ,msi.release_time_fence_days
                             ,msi.container_item_flag
                             ,msi.vehicle_item_flag
                             ,msi.effectivity_control
                             ,msi.event_flag
                             ,msi.electronic_flag
                             ,msi.downloadable_flag
                             ,msi.comms_nl_trackable_flag
                             ,msi.orderable_on_web_flag
                             ,msi.web_status
                             ,msi.dimension_uom_code
                             ,msi.unit_length
                             ,msi.unit_width
                             ,msi.unit_height
                             ,msi.dual_uom_control
                             ,msi.dual_uom_deviation_high
                             ,msi.dual_uom_deviation_low
                             ,msi.contract_item_type_code
                             ,msi.serv_req_enabled_code
                             ,msi.serv_billing_enabled_flag
                             ,msi.default_so_source_type
                             ,msi.object_version_number
                             ,msi.tracking_quantity_ind
                             ,msi.secondary_default_ind
                             ,msi.so_authorization_flag
                             ,msi.attribute17
                             ,msi.attribute18
                             ,msi.attribute19
                             ,msi.attribute25
                             ,msi.expiration_action_code
                             ,msi.expiration_action_interval
                             ,msi.hazardous_material_flag
                             ,msi.recipe_enabled_flag
                             ,msi.retest_interval
                             ,msi.repair_leadtime
                             ,msi.gdsn_outbound_enabled_flag
                             ,msi.revision_qty_control_code
                             ,msi.start_auto_serial_number
                             ,msi.auto_serial_alpha_prefix
                             ,(SELECT concatenated_segments
                               FROM   gl_code_combinations_kfv gcck
                               WHERE  gcck.code_combination_id =
                                      msi.expense_account) legacy_expense_account
                             ,(SELECT concatenated_segments
                               FROM   gl_code_combinations_kfv gcck
                               WHERE  gcck.code_combination_id =
                                      msi.cost_of_sales_account) legacy_cost_of_sales_account
                             ,(SELECT concatenated_segments
                               FROM   gl_code_combinations_kfv gcck
                               WHERE  gcck.code_combination_id =
                                      msi.sales_account) legacy_sales_account
                             ,
                              
                              (SELECT segment1
                               FROM   gl_code_combinations_kfv gcck
                               WHERE  gcck.code_combination_id =
                                      msi.expense_account) expense_acct_segment1
                             ,(SELECT segment2
                               FROM   gl_code_combinations_kfv gcck
                               WHERE  gcck.code_combination_id =
                                      msi.expense_account) expense_acct_segment2
                             ,
                              
                              (SELECT segment3
                               FROM   gl_code_combinations_kfv gcck
                               WHERE  gcck.code_combination_id =
                                      msi.expense_account) expense_acct_segment3
                             ,
                              
                              (SELECT segment4
                               FROM   gl_code_combinations_kfv gcck
                               WHERE  gcck.code_combination_id =
                                      msi.expense_account) expense_acct_segment4
                             ,
                              
                              (SELECT segment5
                               FROM   gl_code_combinations_kfv gcck
                               WHERE  gcck.code_combination_id =
                                      msi.expense_account) expense_acct_segment5
                             ,
                              
                              (SELECT segment6
                               FROM   gl_code_combinations_kfv gcck
                               WHERE  gcck.code_combination_id =
                                      msi.expense_account) expense_acct_segment6
                             ,
                              
                              (SELECT segment7
                               FROM   gl_code_combinations_kfv gcck
                               WHERE  gcck.code_combination_id =
                                      msi.expense_account) expense_acct_segment7
                             ,
                              
                              (SELECT segment8
                               FROM   gl_code_combinations_kfv gcck
                               WHERE  gcck.code_combination_id =
                                      msi.expense_account) expense_acct_segment8
                             ,(SELECT segment9
                               FROM   gl_code_combinations_kfv gcck
                               WHERE  gcck.code_combination_id =
                                      msi.expense_account) expense_acct_segment9
                             ,(SELECT segment10
                               FROM   gl_code_combinations_kfv gcck
                               WHERE  gcck.code_combination_id =
                                      msi.expense_account) expense_acct_segment10
                             ,
                              
                              (SELECT segment1
                               FROM   gl_code_combinations_kfv gcck
                               WHERE  gcck.code_combination_id =
                                      msi.cost_of_sales_account) cost_of_sales_acct_segment1
                             ,
                              
                              (SELECT segment2
                               FROM   gl_code_combinations_kfv gcck
                               WHERE  gcck.code_combination_id =
                                      msi.cost_of_sales_account) cost_of_sales_acct_segment2
                             ,
                              
                              (SELECT segment3
                               FROM   gl_code_combinations_kfv gcck
                               WHERE  gcck.code_combination_id =
                                      msi.cost_of_sales_account) cost_of_sales_acct_segment3
                             ,
                              
                              (SELECT segment4
                               FROM   gl_code_combinations_kfv gcck
                               WHERE  gcck.code_combination_id =
                                      msi.cost_of_sales_account) cost_of_sales_acct_segment4
                             ,
                              
                              (SELECT segment5
                               FROM   gl_code_combinations_kfv gcck
                               WHERE  gcck.code_combination_id =
                                      msi.cost_of_sales_account) cost_of_sales_acct_segment5
                             ,
                              
                              (SELECT segment6
                               FROM   gl_code_combinations_kfv gcck
                               WHERE  gcck.code_combination_id =
                                      msi.cost_of_sales_account) cost_of_sales_acct_segment6
                             ,
                              
                              (SELECT segment7
                               FROM   gl_code_combinations_kfv gcck
                               WHERE  gcck.code_combination_id =
                                      msi.cost_of_sales_account) cost_of_sales_acct_segment7
                             ,
                              
                              (SELECT segment8
                               FROM   gl_code_combinations_kfv gcck
                               WHERE  gcck.code_combination_id =
                                      msi.cost_of_sales_account) cost_of_sales_acct_segment8
                             ,(SELECT segment9
                               FROM   gl_code_combinations_kfv gcck
                               WHERE  gcck.code_combination_id =
                                      msi.cost_of_sales_account) cost_of_sales_acct_segment9
                             ,(SELECT segment10
                               FROM   gl_code_combinations_kfv gcck
                               WHERE  gcck.code_combination_id =
                                      msi.cost_of_sales_account) cost_of_sales_acct_segment10
                             ,
                              
                              (SELECT segment1
                               FROM   gl_code_combinations_kfv gcck
                               WHERE  gcck.code_combination_id =
                                      msi.sales_account) sales_acct_segment1
                             ,(SELECT segment2
                               FROM   gl_code_combinations_kfv gcck
                               WHERE  gcck.code_combination_id =
                                      msi.sales_account) sales_acct_segment2
                             ,
                              
                              (SELECT segment3
                               FROM   gl_code_combinations_kfv gcck
                               WHERE  gcck.code_combination_id =
                                      msi.sales_account) sales_acct_segment3
                             ,
                              
                              (SELECT segment4
                               FROM   gl_code_combinations_kfv gcck
                               WHERE  gcck.code_combination_id =
                                      msi.sales_account) sales_acct_segment4
                             ,
                              
                              (SELECT segment5
                               FROM   gl_code_combinations_kfv gcck
                               WHERE  gcck.code_combination_id =
                                      msi.sales_account) sales_acct_segment5
                             ,
                              
                              (SELECT segment6
                               FROM   gl_code_combinations_kfv gcck
                               WHERE  gcck.code_combination_id =
                                      msi.sales_account) sales_acct_segment6
                             ,
                              
                              (SELECT segment7
                               FROM   gl_code_combinations_kfv gcck
                               WHERE  gcck.code_combination_id =
                                      msi.sales_account) sales_acct_segment7
                             ,
                              
                              (SELECT segment8
                               FROM   gl_code_combinations_kfv gcck
                               WHERE  gcck.code_combination_id =
                                      msi.sales_account) sales_acct_segment8
                             ,(SELECT segment9
                               FROM   gl_code_combinations_kfv gcck
                               WHERE  gcck.code_combination_id =
                                      msi.sales_account) sales_acct_segment9
                             ,(SELECT segment10
                               FROM   gl_code_combinations_kfv gcck
                               WHERE  gcck.code_combination_id =
                                      msi.sales_account) sales_acct_segment10
              
              FROM   mtl_system_items_b msi
              WHERE  EXISTS
                     (SELECT  *
                      FROM   xxobjt.xxs3_ptm_bom_cmpnt_item_stg xpb
                      WHERE  ROWID = (SELECT MIN (ROWID)
                                      FROM xxs3_ptm_bom_cmpnt_item_stg
                                      WHERE component_item_id = xpb.component_item_id) 
                      AND NOT EXISTS
                             (SELECT  *
                              FROM   xxs3_ptm_mtl_master_items xpmm
                              WHERE  xpmm.l_inventory_item_id=xpb.component_item_id)
                       AND  msi.inventory_item_id=xpb.component_item_id)) xx
            ,mtl_item_revisions_b mir
            ,mtl_item_revisions_tl mirt
      WHERE  organization_code = p_organization_code /* Pass the Org Code here */ --p_organization_code ----IN('OMA','UME','USB','USE','UTP');
      AND    mir.inventory_item_id = xx.inventory_item_id
      AND    mir.organization_id = xx.organization_id
      AND    mirt.inventory_item_id = xx.inventory_item_id
      AND    mirt.organization_id = xx.organization_id
      AND    mirt.LANGUAGE = 'US'
      AND    mirt.source_lang = 'US'
      AND    mirt.revision_id = mir.revision_id;
  
  /*Cursor for the S01,S02,S03 org's based on the conditon */
  
    CURSOR c_ume_s01 IS
    
         SELECT msi.l_inventory_item_id
             ,msi.s3_inventory_item_id
             ,msi.description
             ,msi.legacy_buyer_id
             ,msi.s3_buyer_number
             ,msi.legacy_accounting_rule_name
             ,msi.s3_accounting_rule_name
             ,msi.created_by
             ,msi.creation_date
             ,msi.segment1
             ,msi.attribute2
              ,msi.attribute9   
            /* ,(SELECT msib.segment1
               FROM   mtl_system_items_b           msib
                     ,hr_all_organization_units_tl hou
               WHERE  hou.LANGUAGE = 'US'
               AND    hou.NAME LIKE 'OMA%'
               AND    msib.organization_id = hou.organization_id
               AND    (msib.end_date_active IS NULL OR
                     msib.end_date_active < SYSDATE)
               AND    msib.inventory_item_id = msi.attribute9
               AND    rownum < 2) attribute9*/
             ,msi.attribute11
             ,msi.attribute12
             ,msi.attribute13
             ,msi.purchasing_item_flag
             ,msi.shippable_item_flag
             ,msi.customer_order_flag
             ,msi.internal_order_flag
             ,msi.service_item_flag
             ,msi.inventory_item_flag
             ,msi.inventory_asset_flag
             ,msi.purchasing_enabled_flag
             ,msi.customer_order_enabled_flag
             ,msi.internal_order_enabled_flag
             ,msi.so_transactions_flag
             ,msi.mtl_transactions_enabled_flag
             ,msi.stock_enabled_flag
             ,msi.bom_enabled_flag
             ,msi.build_in_wip_flag
             ,msi.item_catalog_group_id
             ,msi.catalog_status_flag
             ,msi.returnable_flag
             ,msi.legacy_organization_id
             ,msi.legacy_organization_code
             ,'S01' s3_organization_code
             ,msi.legacy_source_organization_id
             ,msi.l_source_organization_code
             ,msi. s3_source_organization_code
             ,msi.collateral_flag
             ,msi.taxable_flag
             ,msi.allow_item_desc_update_flag
             ,msi.inspection_required_flag
             ,msi.receipt_required_flag
             ,msi.qty_rcv_tolerance
             ,msi.list_price_per_unit
             ,msi.asset_category_id
             ,msi.unit_of_issue
             ,msi.allow_substitute_receipts_flag
             ,msi.allow_unordered_receipts_flag
             ,msi.allow_express_delivery_flag
             ,msi.days_early_receipt_allowed
             ,msi.days_late_receipt_allowed
             ,msi.receipt_days_exception_code
             ,msi.receiving_routing_id
             ,msi.auto_lot_alpha_prefix
             ,msi.start_auto_lot_number
             ,msi.lot_control_code
             ,msi.shelf_life_code
             ,msi.shelf_life_days
             ,msi.serial_number_control_code
             ,msi.source_type
             ,msi.source_subinventory
             ,msi.expense_account
             ,msi.legacy_expense_account
             ,msi.legacy_expense_acct_segment1
             ,msi.legacy_expense_acct_segment2
             ,msi.legacy_expense_acct_segment3
             ,msi.legacy_expense_acct_segment4
             ,msi.legacy_expense_acct_segment5
             ,msi.legacy_expense_acct_segment6
             ,msi.legacy_expense_acct_segment7
             ,msi.legacy_expense_acct_segment8
             ,msi.legacy_expense_acct_segment9
             ,msi.legacy_expense_acct_segment10
             ,msi.s3_expense_acct_segment1
             ,msi.s3_expense_acct_segment2
             ,msi.s3_expense_acct_segment3
             ,msi.s3_expense_acct_segment4
             ,msi.s3_expense_acct_segment5
             ,msi.s3_expense_acct_segment6
             ,msi.s3_expense_acct_segment7
             ,msi.s3_expense_acct_segment8
             ,msi.restrict_subinventories_code
             ,msi.unit_weight
             ,msi.weight_uom_code
             ,msi.volume_uom_code
             ,msi.unit_volume
             ,msi.shrinkage_rate
             ,msi.acceptable_early_days
             ,msi.planning_time_fence_code
             ,msi.lead_time_lot_size
             ,msi.std_lot_size
             ,msi.overrun_percentage
             ,msi.mrp_calculate_atp_flag
             ,msi.acceptable_rate_increase
             ,msi.acceptable_rate_decrease
             ,msi.planning_time_fence_days
             ,msi.end_assembly_pegging_flag
             ,msi.bom_item_type
             ,msi.pick_components_flag
             ,msi.replenish_to_order_flag
             ,msi.atp_components_flag
             ,msi.atp_flag
             ,msi.wip_supply_type
              --,msi.wip_supply_subinventory
              --  ,msi.s3_wip_supply_subinventory
             ,msi.primary_uom_code
             ,msi.secondary_uom_code
             ,msi.s3_secondary_uom_code
             ,msi.primary_unit_of_measure
             ,msi.allowed_units_lookup_code
             ,msi.cost_of_sales_account
             ,msi.l_cost_of_sales_account
             ,msi.l_cost_of_sales_acct_segment1
             ,msi.l_cost_of_sales_acct_segment2
             ,msi.l_cost_of_sales_acct_segment3
             ,msi.l_cost_of_sales_acct_segment4
             ,msi.l_cost_of_sales_acct_segment5
             ,msi.l_cost_of_sales_acct_segment6
             ,msi.l_cost_of_sales_acct_segment7
             ,msi.l_cost_of_sales_acct_segment8
             ,msi.l_cost_of_sales_acct_segment9
             ,msi.l_cost_of_sales_acct_segment10
             ,msi.s3_cost_sales_acct_segment1
             ,msi.s3_cost_sales_acct_segment2
             ,msi.s3_cost_sales_acct_segment3
             ,msi.s3_cost_sales_acct_segment4
             ,msi.s3_cost_sales_acct_segment5
             ,msi.s3_cost_sales_acct_segment6
             ,msi.s3_cost_sales_acct_segment7
             ,msi.s3_cost_sales_acct_segment8
             ,msi.s3_cost_sales_acct_segment9
             ,msi.s3_cost_sales_acct_segment10
             ,msi.sales_account
             ,msi.legacy_sales_account
             ,msi.legacy_sales_acct_segment1
             ,msi.legacy_sales_acct_segment2
             ,msi.legacy_sales_acct_segment3
             ,msi.legacy_sales_acct_segment4
             ,msi.legacy_sales_acct_segment5
             ,msi.legacy_sales_acct_segment6
             ,msi.legacy_sales_acct_segment7
             ,msi.legacy_sales_acct_segment8
             ,msi.legacy_sales_acct_segment9
             ,msi.legacy_sales_acct_segment10
             ,msi.s3_sales_acct_segment1
             ,msi.s3_sales_acct_segment2
             ,msi.s3_sales_acct_segment3
             ,msi.s3_sales_acct_segment4
             ,msi.s3_sales_acct_segment5
             ,msi.s3_sales_acct_segment6
             ,msi.s3_sales_acct_segment7
             ,msi.s3_sales_acct_segment8
             ,msi.s3_sales_acct_segment9
             ,msi.s3_sales_acct_segment10
             ,msi.default_include_in_rollup_flag
             ,msi.inventory_item_status_code
             ,msi.s3_inventory_item_status_code
             ,msi.inventory_planning_code
             ,msi.planner_code
             ,msi.s3_planner_code
             ,msi.planning_make_buy_code
             ,msi.fixed_lot_multiplier
             ,msi.rounding_control_type
             ,msi.postprocessing_lead_time
             ,msi.preprocessing_lead_time
             ,msi.full_lead_time
             ,msi.mrp_safety_stock_percent
             ,msi.mrp_safety_stock_code
             ,msi.min_minmax_quantity
             ,msi.max_minmax_quantity
             ,msi.minimum_order_quantity
             ,msi.fixed_order_quantity
             ,msi.fixed_days_supply
             ,msi.maximum_order_quantity
             ,msi.atp_rule_name
             ,msi.s3_atp_rule_name
             ,msi.reservable_type
             ,msi.vendor_warranty_flag
             ,msi.serviceable_product_flag
             ,msi.material_billable_flag
             ,msi.prorate_service_flag
             ,msi.invoiceable_item_flag
             ,msi.invoice_enabled_flag
             ,msi.outside_operation_flag
             ,msi.outside_operation_uom_type
             ,msi.safety_stock_bucket_days
             ,msi.costing_enabled_flag
             ,msi.cycle_count_enabled_flag
             ,msi.item_type
             ,msi.s3_item_type
             ,msi.ship_model_complete_flag
             ,msi.mrp_planning_code
             ,msi.ato_forecast_control
             ,msi.release_time_fence_code
             ,msi.release_time_fence_days
             ,msi.container_item_flag
             ,msi.vehicle_item_flag
             ,msi.effectivity_control
             ,msi.event_flag
             ,msi.electronic_flag
             ,msi.downloadable_flag
             ,msi.comms_nl_trackable_flag
             ,msi.orderable_on_web_flag
             ,msi.web_status
             ,msi.dimension_uom_code
             ,msi.unit_length
             ,msi.unit_width
             ,msi.unit_height
             ,msi.dual_uom_control
             ,msi.dual_uom_deviation_high
             ,msi.dual_uom_deviation_low
             ,msi.contract_item_type_code
             ,msi.serv_req_enabled_code
             ,msi.serv_billing_enabled_flag
             ,msi.default_so_source_type
             ,msi.object_version_number
             ,msi.tracking_quantity_ind
             ,msi.s3_tracking_quantity_ind
             ,msi.secondary_default_ind
             ,msi.s3_secondary_default_ind
             ,msi.so_authorization_flag
             ,msi.attribute17
             ,msi.attribute18
             ,msi.attribute19
             ,msi.attribute25
             ,msi.s3_attribute25
             ,msi.expiration_action_code
             ,msi.s3_expiration_action_code
             ,msi.expiration_action_interval
             ,msi.s3_expiration_action_interval
             ,msi.hazardous_material_flag
             ,msi.recipe_enabled_flag
             ,msi.start_auto_serial_number
             ,msi.auto_serial_alpha_prefix
             ,msi.retest_interval
             ,msi.repair_leadtime
             ,msi.gdsn_outbound_enabled_flag
             ,msi.revision_qty_control_code
             ,msi.legacy_revision_id
             ,msi.xxs3_revision_id
             ,msi.revision
             ,msi.revision_label
             ,msi.revision_description
             ,msi.effectivity_date
             ,msi.implementation_date
             ,msi.ecn_initiation_date
             ,msi.change_notice
             ,msi.revision_attribute10
             ,msi.revised_item_sequence_id
             ,msi.s3_revised_item_sequence_id
             ,msi.revision_language
             ,msi.source_lang
             ,msi.revision_tl_description
             ,msi. last_update_date
             ,msi.last_updated_by
             ,msi.orig_system_reference
             ,msi.date_extracted_on
             ,msi.process_flag
             ,msi.transform_status
             ,msi.transform_error
             ,msi.cleanse_status
             ,msi.cleanse_error
       FROM    xxobjt.xxs3_ptm_mtl_master_items msi
       WHERE  legacy_organization_code = 'UME'
       AND S3_ORGANIZATION_CODE='M01'
              
       UNION
       SELECT msi.l_inventory_item_id
             ,msi.s3_inventory_item_id
             ,msi.description
             ,msi.legacy_buyer_id
             ,msi.s3_buyer_number
             ,msi.legacy_accounting_rule_name
             ,msi.s3_accounting_rule_name
             ,msi.created_by
             ,msi.creation_date
             ,msi.segment1
             ,msi.attribute2
              ,msi.attribute9   
           /*  ,(SELECT msib.segment1
               FROM   mtl_system_items_b           msib
                     ,hr_all_organization_units_tl hou
               WHERE  hou.LANGUAGE = 'US'
               AND    hou.NAME LIKE 'OMA%'
               AND    msib.organization_id = hou.organization_id
               AND    (msib.end_date_active IS NULL OR
                     msib.end_date_active < SYSDATE)
               AND    msib.inventory_item_id = msi.attribute9
               AND    rownum < 2) attribute9*/
             ,msi.attribute11
             ,msi.attribute12
             ,msi.attribute13
             ,msi.purchasing_item_flag
             ,msi.shippable_item_flag
             ,msi.customer_order_flag
             ,msi.internal_order_flag
             ,msi.service_item_flag
             ,msi.inventory_item_flag
             ,msi.inventory_asset_flag
             ,msi.purchasing_enabled_flag
             ,msi.customer_order_enabled_flag
             ,msi.internal_order_enabled_flag
             ,msi.so_transactions_flag
             ,msi.mtl_transactions_enabled_flag
             ,msi.stock_enabled_flag
             ,msi.bom_enabled_flag
             ,msi.build_in_wip_flag
             ,msi.item_catalog_group_id
             ,msi.catalog_status_flag
             ,msi.returnable_flag
             ,msi.legacy_organization_id
             ,msi.legacy_organization_code
             ,'S02' s3_organization_code
             ,msi.legacy_source_organization_id
             ,msi.l_source_organization_code
             ,msi. s3_source_organization_code
             ,msi.collateral_flag
             ,msi.taxable_flag
             ,msi.allow_item_desc_update_flag
             ,msi.inspection_required_flag
             ,msi.receipt_required_flag
             ,msi.qty_rcv_tolerance
             ,msi.list_price_per_unit
             ,msi.asset_category_id
             ,msi.unit_of_issue
             ,msi.allow_substitute_receipts_flag
             ,msi.allow_unordered_receipts_flag
             ,msi.allow_express_delivery_flag
             ,msi.days_early_receipt_allowed
             ,msi.days_late_receipt_allowed
             ,msi.receipt_days_exception_code
             ,msi.receiving_routing_id
             ,msi.auto_lot_alpha_prefix
             ,msi.start_auto_lot_number
             ,msi.lot_control_code
             ,msi.shelf_life_code
             ,msi.shelf_life_days
             ,msi.serial_number_control_code
             ,msi.source_type
             ,msi.source_subinventory
             ,msi.expense_account
             ,msi.legacy_expense_account
             ,msi.legacy_expense_acct_segment1
             ,msi.legacy_expense_acct_segment2
             ,msi.legacy_expense_acct_segment3
             ,msi.legacy_expense_acct_segment4
             ,msi.legacy_expense_acct_segment5
             ,msi.legacy_expense_acct_segment6
             ,msi.legacy_expense_acct_segment7
             ,msi.legacy_expense_acct_segment8
             ,msi.legacy_expense_acct_segment9
             ,msi.legacy_expense_acct_segment10
             ,msi.s3_expense_acct_segment1
             ,msi.s3_expense_acct_segment2
             ,msi.s3_expense_acct_segment3
             ,msi.s3_expense_acct_segment4
             ,msi.s3_expense_acct_segment5
             ,msi.s3_expense_acct_segment6
             ,msi.s3_expense_acct_segment7
             ,msi.s3_expense_acct_segment8
             ,msi.restrict_subinventories_code
             ,msi.unit_weight
             ,msi.weight_uom_code
             ,msi.volume_uom_code
             ,msi.unit_volume
             ,msi.shrinkage_rate
             ,msi.acceptable_early_days
             ,msi.planning_time_fence_code
             ,msi.lead_time_lot_size
             ,msi.std_lot_size
             ,msi.overrun_percentage
             ,msi.mrp_calculate_atp_flag
             ,msi.acceptable_rate_increase
             ,msi.acceptable_rate_decrease
             ,msi.planning_time_fence_days
             ,msi.end_assembly_pegging_flag
             ,msi.bom_item_type
             ,msi.pick_components_flag
             ,msi.replenish_to_order_flag
             ,msi.atp_components_flag
             ,msi.atp_flag
             ,msi.wip_supply_type
              --,msi.wip_supply_subinventory
              --  ,msi.s3_wip_supply_subinventory
             ,msi.primary_uom_code
             ,msi.secondary_uom_code
             ,msi.s3_secondary_uom_code
             ,msi.primary_unit_of_measure
             ,msi.allowed_units_lookup_code
             ,msi.cost_of_sales_account
             ,msi.l_cost_of_sales_account
             ,msi.l_cost_of_sales_acct_segment1
             ,msi.l_cost_of_sales_acct_segment2
             ,msi.l_cost_of_sales_acct_segment3
             ,msi.l_cost_of_sales_acct_segment4
             ,msi.l_cost_of_sales_acct_segment5
             ,msi.l_cost_of_sales_acct_segment6
             ,msi.l_cost_of_sales_acct_segment7
             ,msi.l_cost_of_sales_acct_segment8
             ,msi.l_cost_of_sales_acct_segment9
             ,msi.l_cost_of_sales_acct_segment10
             ,msi.s3_cost_sales_acct_segment1
             ,msi.s3_cost_sales_acct_segment2
             ,msi.s3_cost_sales_acct_segment3
             ,msi.s3_cost_sales_acct_segment4
             ,msi.s3_cost_sales_acct_segment5
             ,msi.s3_cost_sales_acct_segment6
             ,msi.s3_cost_sales_acct_segment7
             ,msi.s3_cost_sales_acct_segment8
             ,msi.s3_cost_sales_acct_segment9
             ,msi.s3_cost_sales_acct_segment10
             ,msi.sales_account
             ,msi.legacy_sales_account
             ,msi.legacy_sales_acct_segment1
             ,msi.legacy_sales_acct_segment2
             ,msi.legacy_sales_acct_segment3
             ,msi.legacy_sales_acct_segment4
             ,msi.legacy_sales_acct_segment5
             ,msi.legacy_sales_acct_segment6
             ,msi.legacy_sales_acct_segment7
             ,msi.legacy_sales_acct_segment8
             ,msi.legacy_sales_acct_segment9
             ,msi.legacy_sales_acct_segment10
             ,msi.s3_sales_acct_segment1
             ,msi.s3_sales_acct_segment2
             ,msi.s3_sales_acct_segment3
             ,msi.s3_sales_acct_segment4
             ,msi.s3_sales_acct_segment5
             ,msi.s3_sales_acct_segment6
             ,msi.s3_sales_acct_segment7
             ,msi.s3_sales_acct_segment8
             ,msi.s3_sales_acct_segment9
             ,msi.s3_sales_acct_segment10
             ,msi.default_include_in_rollup_flag
             ,msi.inventory_item_status_code
             ,msi.s3_inventory_item_status_code
             ,msi.inventory_planning_code
             ,msi.planner_code
             ,msi.s3_planner_code
             ,msi.planning_make_buy_code
             ,msi.fixed_lot_multiplier
             ,msi.rounding_control_type
             ,msi.postprocessing_lead_time
             ,msi.preprocessing_lead_time
             ,msi.full_lead_time
             ,msi.mrp_safety_stock_percent
             ,msi.mrp_safety_stock_code
             ,msi.min_minmax_quantity
             ,msi.max_minmax_quantity
             ,msi.minimum_order_quantity
             ,msi.fixed_order_quantity
             ,msi.fixed_days_supply
             ,msi.maximum_order_quantity
             ,msi.atp_rule_name
             ,msi.s3_atp_rule_name
             ,msi.reservable_type
             ,msi.vendor_warranty_flag
             ,msi.serviceable_product_flag
             ,msi.material_billable_flag
             ,msi.prorate_service_flag
             ,msi.invoiceable_item_flag
             ,msi.invoice_enabled_flag
             ,msi.outside_operation_flag
             ,msi.outside_operation_uom_type
             ,msi.safety_stock_bucket_days
             ,msi.costing_enabled_flag
             ,msi.cycle_count_enabled_flag
             ,msi.item_type
             ,msi.s3_item_type
             ,msi.ship_model_complete_flag
             ,msi.mrp_planning_code
             ,msi.ato_forecast_control
             ,msi.release_time_fence_code
             ,msi.release_time_fence_days
             ,msi.container_item_flag
             ,msi.vehicle_item_flag
             ,msi.effectivity_control
             ,msi.event_flag
             ,msi.electronic_flag
             ,msi.downloadable_flag
             ,msi.comms_nl_trackable_flag
             ,msi.orderable_on_web_flag
             ,msi.web_status
             ,msi.dimension_uom_code
             ,msi.unit_length
             ,msi.unit_width
             ,msi.unit_height
             ,msi.dual_uom_control
             ,msi.dual_uom_deviation_high
             ,msi.dual_uom_deviation_low
             ,msi.contract_item_type_code
             ,msi.serv_req_enabled_code
             ,msi.serv_billing_enabled_flag
             ,msi.default_so_source_type
             ,msi.object_version_number
             ,msi.tracking_quantity_ind
             ,msi.s3_tracking_quantity_ind
             ,msi.secondary_default_ind
             ,msi.s3_secondary_default_ind
             ,msi.so_authorization_flag
             ,msi.attribute17
             ,msi.attribute18
             ,msi.attribute19
             ,msi.attribute25
             ,msi.s3_attribute25
             ,msi.expiration_action_code
             ,msi.s3_expiration_action_code
             ,msi.expiration_action_interval
             ,msi.s3_expiration_action_interval
             ,msi.hazardous_material_flag
             ,msi.recipe_enabled_flag
             ,msi.start_auto_serial_number
             ,msi.auto_serial_alpha_prefix
             ,msi.retest_interval
             ,msi.repair_leadtime
             ,msi.gdsn_outbound_enabled_flag
             ,msi.revision_qty_control_code
             ,msi.legacy_revision_id
             ,msi.xxs3_revision_id
             ,msi.revision
             ,msi.revision_label
             ,msi.revision_description
             ,msi.effectivity_date
             ,msi.implementation_date
             ,msi.ecn_initiation_date
             ,msi.change_notice
             ,msi.revision_attribute10
             ,msi.revised_item_sequence_id
             ,msi.s3_revised_item_sequence_id
             ,msi.revision_language
             ,msi.source_lang
             ,msi.revision_tl_description
             ,msi. last_update_date
             ,msi.last_updated_by
             ,msi.orig_system_reference
             ,msi.date_extracted_on
             ,msi.process_flag
             ,msi.transform_status
             ,msi.transform_error
             ,msi.cleanse_status
             ,msi.cleanse_error
       FROM    xxobjt.xxs3_ptm_mtl_master_items msi
       WHERE  legacy_organization_code = 'UME'
       AND S3_ORGANIZATION_CODE='M01'
              
       UNION
       SELECT msi.l_inventory_item_id
             ,msi.s3_inventory_item_id
             ,msi.description
             ,msi.legacy_buyer_id
             ,msi.s3_buyer_number
             ,msi.legacy_accounting_rule_name
             ,msi.s3_accounting_rule_name
             ,msi.created_by
             ,msi.creation_date
             ,msi.segment1
             ,msi.attribute2
              ,msi.attribute9   
            /* ,(SELECT msib.segment1
               FROM   mtl_system_items_b           msib
                     ,hr_all_organization_units_tl hou
               WHERE  hou.LANGUAGE = 'US'
               AND    hou.NAME LIKE 'OMA%'
               AND    msib.organization_id = hou.organization_id
               AND    (msib.end_date_active IS NULL OR
                     msib.end_date_active < SYSDATE)
               AND    msib.inventory_item_id = msi.attribute9
               AND    rownum < 2) attribute9*/
             ,msi.attribute11
             ,msi.attribute12
             ,msi.attribute13
             ,msi.purchasing_item_flag
             ,msi.shippable_item_flag
             ,msi.customer_order_flag
             ,msi.internal_order_flag
             ,msi.service_item_flag
             ,msi.inventory_item_flag
             ,msi.inventory_asset_flag
             ,msi.purchasing_enabled_flag
             ,msi.customer_order_enabled_flag
             ,msi.internal_order_enabled_flag
             ,msi.so_transactions_flag
             ,msi.mtl_transactions_enabled_flag
             ,msi.stock_enabled_flag
             ,msi.bom_enabled_flag
             ,msi.build_in_wip_flag
             ,msi.item_catalog_group_id
             ,msi.catalog_status_flag
             ,msi.returnable_flag
             ,msi.legacy_organization_id
             ,msi.legacy_organization_code
             ,'S03' s3_organization_code
             ,msi.legacy_source_organization_id
             ,msi.l_source_organization_code
             ,msi. s3_source_organization_code
             ,msi.collateral_flag
             ,msi.taxable_flag
             ,msi.allow_item_desc_update_flag
             ,msi.inspection_required_flag
             ,msi.receipt_required_flag
             ,msi.qty_rcv_tolerance
             ,msi.list_price_per_unit
             ,msi.asset_category_id
             ,msi.unit_of_issue
             ,msi.allow_substitute_receipts_flag
             ,msi.allow_unordered_receipts_flag
             ,msi.allow_express_delivery_flag
             ,msi.days_early_receipt_allowed
             ,msi.days_late_receipt_allowed
             ,msi.receipt_days_exception_code
             ,msi.receiving_routing_id
             ,msi.auto_lot_alpha_prefix
             ,msi.start_auto_lot_number
             ,msi.lot_control_code
             ,msi.shelf_life_code
             ,msi.shelf_life_days
             ,msi.serial_number_control_code
             ,msi.source_type
             ,msi.source_subinventory
             ,msi.expense_account
             ,msi.legacy_expense_account
             ,msi.legacy_expense_acct_segment1
             ,msi.legacy_expense_acct_segment2
             ,msi.legacy_expense_acct_segment3
             ,msi.legacy_expense_acct_segment4
             ,msi.legacy_expense_acct_segment5
             ,msi.legacy_expense_acct_segment6
             ,msi.legacy_expense_acct_segment7
             ,msi.legacy_expense_acct_segment8
             ,msi.legacy_expense_acct_segment9
             ,msi.legacy_expense_acct_segment10
             ,msi.s3_expense_acct_segment1
             ,msi.s3_expense_acct_segment2
             ,msi.s3_expense_acct_segment3
             ,msi.s3_expense_acct_segment4
             ,msi.s3_expense_acct_segment5
             ,msi.s3_expense_acct_segment6
             ,msi.s3_expense_acct_segment7
             ,msi.s3_expense_acct_segment8
             ,msi.restrict_subinventories_code
             ,msi.unit_weight
             ,msi.weight_uom_code
             ,msi.volume_uom_code
             ,msi.unit_volume
             ,msi.shrinkage_rate
             ,msi.acceptable_early_days
             ,msi.planning_time_fence_code
             ,msi.lead_time_lot_size
             ,msi.std_lot_size
             ,msi.overrun_percentage
             ,msi.mrp_calculate_atp_flag
             ,msi.acceptable_rate_increase
             ,msi.acceptable_rate_decrease
             ,msi.planning_time_fence_days
             ,msi.end_assembly_pegging_flag
             ,msi.bom_item_type
             ,msi.pick_components_flag
             ,msi.replenish_to_order_flag
             ,msi.atp_components_flag
             ,msi.atp_flag
             ,msi.wip_supply_type
              --,msi.wip_supply_subinventory
              --  ,msi.s3_wip_supply_subinventory
             ,msi.primary_uom_code
             ,msi.secondary_uom_code
             ,msi.s3_secondary_uom_code
             ,msi.primary_unit_of_measure
             ,msi.allowed_units_lookup_code
             ,msi.cost_of_sales_account
             ,msi.l_cost_of_sales_account
             ,msi.l_cost_of_sales_acct_segment1
             ,msi.l_cost_of_sales_acct_segment2
             ,msi.l_cost_of_sales_acct_segment3
             ,msi.l_cost_of_sales_acct_segment4
             ,msi.l_cost_of_sales_acct_segment5
             ,msi.l_cost_of_sales_acct_segment6
             ,msi.l_cost_of_sales_acct_segment7
             ,msi.l_cost_of_sales_acct_segment8
             ,msi.l_cost_of_sales_acct_segment9
             ,msi.l_cost_of_sales_acct_segment10
             ,msi.s3_cost_sales_acct_segment1
             ,msi.s3_cost_sales_acct_segment2
             ,msi.s3_cost_sales_acct_segment3
             ,msi.s3_cost_sales_acct_segment4
             ,msi.s3_cost_sales_acct_segment5
             ,msi.s3_cost_sales_acct_segment6
             ,msi.s3_cost_sales_acct_segment7
             ,msi.s3_cost_sales_acct_segment8
             ,msi.s3_cost_sales_acct_segment9
             ,msi.s3_cost_sales_acct_segment10
             ,msi.sales_account
             ,msi.legacy_sales_account
             ,msi.legacy_sales_acct_segment1
             ,msi.legacy_sales_acct_segment2
             ,msi.legacy_sales_acct_segment3
             ,msi.legacy_sales_acct_segment4
             ,msi.legacy_sales_acct_segment5
             ,msi.legacy_sales_acct_segment6
             ,msi.legacy_sales_acct_segment7
             ,msi.legacy_sales_acct_segment8
             ,msi.legacy_sales_acct_segment9
             ,msi.legacy_sales_acct_segment10
             ,msi.s3_sales_acct_segment1
             ,msi.s3_sales_acct_segment2
             ,msi.s3_sales_acct_segment3
             ,msi.s3_sales_acct_segment4
             ,msi.s3_sales_acct_segment5
             ,msi.s3_sales_acct_segment6
             ,msi.s3_sales_acct_segment7
             ,msi.s3_sales_acct_segment8
             ,msi.s3_sales_acct_segment9
             ,msi.s3_sales_acct_segment10
             ,msi.default_include_in_rollup_flag
             ,msi.inventory_item_status_code
             ,msi.s3_inventory_item_status_code
             ,msi.inventory_planning_code
             ,msi.planner_code
             ,msi.s3_planner_code
             ,msi.planning_make_buy_code
             ,msi.fixed_lot_multiplier
             ,msi.rounding_control_type
             ,msi.postprocessing_lead_time
             ,msi.preprocessing_lead_time
             ,msi.full_lead_time
             ,msi.mrp_safety_stock_percent
             ,msi.mrp_safety_stock_code
             ,msi.min_minmax_quantity
             ,msi.max_minmax_quantity
             ,msi.minimum_order_quantity
             ,msi.fixed_order_quantity
             ,msi.fixed_days_supply
             ,msi.maximum_order_quantity
             ,msi.atp_rule_name
             ,msi.s3_atp_rule_name
             ,msi.reservable_type
             ,msi.vendor_warranty_flag
             ,msi.serviceable_product_flag
             ,msi.material_billable_flag
             ,msi.prorate_service_flag
             ,msi.invoiceable_item_flag
             ,msi.invoice_enabled_flag
             ,msi.outside_operation_flag
             ,msi.outside_operation_uom_type
             ,msi.safety_stock_bucket_days
             ,msi.costing_enabled_flag
             ,msi.cycle_count_enabled_flag
             ,msi.item_type
             ,msi.s3_item_type
             ,msi.ship_model_complete_flag
             ,msi.mrp_planning_code
             ,msi.ato_forecast_control
             ,msi.release_time_fence_code
             ,msi.release_time_fence_days
             ,msi.container_item_flag
             ,msi.vehicle_item_flag
             ,msi.effectivity_control
             ,msi.event_flag
             ,msi.electronic_flag
             ,msi.downloadable_flag
             ,msi.comms_nl_trackable_flag
             ,msi.orderable_on_web_flag
             ,msi.web_status
             ,msi.dimension_uom_code
             ,msi.unit_length
             ,msi.unit_width
             ,msi.unit_height
             ,msi.dual_uom_control
             ,msi.dual_uom_deviation_high
             ,msi.dual_uom_deviation_low
             ,msi.contract_item_type_code
             ,msi.serv_req_enabled_code
             ,msi.serv_billing_enabled_flag
             ,msi.default_so_source_type
             ,msi.object_version_number
             ,msi.tracking_quantity_ind
             ,msi.s3_tracking_quantity_ind
             ,msi.secondary_default_ind
             ,msi.s3_secondary_default_ind
             ,msi.so_authorization_flag
             ,msi.attribute17
             ,msi.attribute18
             ,msi.attribute19
             ,msi.attribute25
             ,msi.s3_attribute25
             ,msi.expiration_action_code
             ,msi.s3_expiration_action_code
             ,msi.expiration_action_interval
             ,msi.s3_expiration_action_interval
             ,msi.hazardous_material_flag
             ,msi.recipe_enabled_flag
             ,msi.start_auto_serial_number
             ,msi.auto_serial_alpha_prefix
             ,msi.retest_interval
             ,msi.repair_leadtime
             ,msi.gdsn_outbound_enabled_flag
             ,msi.revision_qty_control_code
             ,msi.legacy_revision_id
             ,msi.xxs3_revision_id
             ,msi.revision
             ,msi.revision_label
             ,msi.revision_description
             ,msi.effectivity_date
             ,msi.implementation_date
             ,msi.ecn_initiation_date
             ,msi.change_notice
             ,msi.revision_attribute10
             ,msi.revised_item_sequence_id
             ,msi.s3_revised_item_sequence_id
             ,msi.revision_language
             ,msi.source_lang
             ,msi.revision_tl_description
             ,msi. last_update_date
             ,msi.last_updated_by
             ,msi.orig_system_reference
             ,msi.date_extracted_on
             ,msi.process_flag
             ,msi.transform_status
             ,msi.transform_error
             ,msi.cleanse_status
             ,msi.cleanse_error
       FROM    xxobjt.xxs3_ptm_mtl_master_items msi
       WHERE  legacy_organization_code = 'UME'
       AND S3_ORGANIZATION_CODE='M01'
       UNION
       SELECT msi.l_inventory_item_id
             ,msi.s3_inventory_item_id
             ,msi.description
             ,msi.legacy_buyer_id
             ,msi.s3_buyer_number
             ,msi.legacy_accounting_rule_name
             ,msi.s3_accounting_rule_name
             ,msi.created_by
             ,msi.creation_date
             ,msi.segment1
             ,msi.attribute2
              ,msi.attribute9   
             /*,(SELECT msib.segment1
               FROM   mtl_system_items_b           msib
                     ,hr_all_organization_units_tl hou
               WHERE  hou.LANGUAGE = 'US'
               AND    hou.NAME LIKE 'OMA%'
               AND    msib.organization_id = hou.organization_id
               AND    (msib.end_date_active IS NULL OR
                     msib.end_date_active < SYSDATE)
               AND    msib.inventory_item_id = msi.attribute9
               AND    rownum < 2) attribute9*/
             ,msi.attribute11
             ,msi.attribute12
             ,msi.attribute13
             ,msi.purchasing_item_flag
             ,msi.shippable_item_flag
             ,msi.customer_order_flag
             ,msi.internal_order_flag
             ,msi.service_item_flag
             ,msi.inventory_item_flag
             ,msi.inventory_asset_flag
             ,msi.purchasing_enabled_flag
             ,msi.customer_order_enabled_flag
             ,msi.internal_order_enabled_flag
             ,msi.so_transactions_flag
             ,msi.mtl_transactions_enabled_flag
             ,msi.stock_enabled_flag
             ,msi.bom_enabled_flag
             ,msi.build_in_wip_flag
             ,msi.item_catalog_group_id
             ,msi.catalog_status_flag
             ,msi.returnable_flag
             ,msi.legacy_organization_id
             ,msi.legacy_organization_code
             ,'T03'  s3_organization_code
             ,msi.legacy_source_organization_id
             ,msi.l_source_organization_code
             ,msi. s3_source_organization_code
             ,msi.collateral_flag
             ,msi.taxable_flag
             ,msi.allow_item_desc_update_flag
             ,msi.inspection_required_flag
             ,msi.receipt_required_flag
             ,msi.qty_rcv_tolerance
             ,msi.list_price_per_unit
             ,msi.asset_category_id
             ,msi.unit_of_issue
             ,msi.allow_substitute_receipts_flag
             ,msi.allow_unordered_receipts_flag
             ,msi.allow_express_delivery_flag
             ,msi.days_early_receipt_allowed
             ,msi.days_late_receipt_allowed
             ,msi.receipt_days_exception_code
             ,msi.receiving_routing_id
             ,msi.auto_lot_alpha_prefix
             ,msi.start_auto_lot_number
             ,msi.lot_control_code
             ,msi.shelf_life_code
             ,msi.shelf_life_days
             ,msi.serial_number_control_code
             ,msi.source_type
             ,msi.source_subinventory
             ,msi.expense_account
             ,msi.legacy_expense_account
             ,msi.legacy_expense_acct_segment1
             ,msi.legacy_expense_acct_segment2
             ,msi.legacy_expense_acct_segment3
             ,msi.legacy_expense_acct_segment4
             ,msi.legacy_expense_acct_segment5
             ,msi.legacy_expense_acct_segment6
             ,msi.legacy_expense_acct_segment7
             ,msi.legacy_expense_acct_segment8
             ,msi.legacy_expense_acct_segment9
             ,msi.legacy_expense_acct_segment10
             ,msi.s3_expense_acct_segment1
             ,msi.s3_expense_acct_segment2
             ,msi.s3_expense_acct_segment3
             ,msi.s3_expense_acct_segment4
             ,msi.s3_expense_acct_segment5
             ,msi.s3_expense_acct_segment6
             ,msi.s3_expense_acct_segment7
             ,msi.s3_expense_acct_segment8
             ,msi.restrict_subinventories_code
             ,msi.unit_weight
             ,msi.weight_uom_code
             ,msi.volume_uom_code
             ,msi.unit_volume
             ,msi.shrinkage_rate
             ,msi.acceptable_early_days
             ,msi.planning_time_fence_code
             ,msi.lead_time_lot_size
             ,msi.std_lot_size
             ,msi.overrun_percentage
             ,msi.mrp_calculate_atp_flag
             ,msi.acceptable_rate_increase
             ,msi.acceptable_rate_decrease
             ,msi.planning_time_fence_days
             ,msi.end_assembly_pegging_flag
             ,msi.bom_item_type
             ,msi.pick_components_flag
             ,msi.replenish_to_order_flag
             ,msi.atp_components_flag
             ,msi.atp_flag
             ,msi.wip_supply_type
              --,msi.wip_supply_subinventory
              --  ,msi.s3_wip_supply_subinventory
             ,msi.primary_uom_code
             ,msi.secondary_uom_code
             ,msi.s3_secondary_uom_code
             ,msi.primary_unit_of_measure
             ,msi.allowed_units_lookup_code
             ,msi.cost_of_sales_account
             ,msi.l_cost_of_sales_account
             ,msi.l_cost_of_sales_acct_segment1
             ,msi.l_cost_of_sales_acct_segment2
             ,msi.l_cost_of_sales_acct_segment3
             ,msi.l_cost_of_sales_acct_segment4
             ,msi.l_cost_of_sales_acct_segment5
             ,msi.l_cost_of_sales_acct_segment6
             ,msi.l_cost_of_sales_acct_segment7
             ,msi.l_cost_of_sales_acct_segment8
             ,msi.l_cost_of_sales_acct_segment9
             ,msi.l_cost_of_sales_acct_segment10
             ,msi.s3_cost_sales_acct_segment1
             ,msi.s3_cost_sales_acct_segment2
             ,msi.s3_cost_sales_acct_segment3
             ,msi.s3_cost_sales_acct_segment4
             ,msi.s3_cost_sales_acct_segment5
             ,msi.s3_cost_sales_acct_segment6
             ,msi.s3_cost_sales_acct_segment7
             ,msi.s3_cost_sales_acct_segment8
             ,msi.s3_cost_sales_acct_segment9
             ,msi.s3_cost_sales_acct_segment10
             ,msi.sales_account
             ,msi.legacy_sales_account
             ,msi.legacy_sales_acct_segment1
             ,msi.legacy_sales_acct_segment2
             ,msi.legacy_sales_acct_segment3
             ,msi.legacy_sales_acct_segment4
             ,msi.legacy_sales_acct_segment5
             ,msi.legacy_sales_acct_segment6
             ,msi.legacy_sales_acct_segment7
             ,msi.legacy_sales_acct_segment8
             ,msi.legacy_sales_acct_segment9
             ,msi.legacy_sales_acct_segment10
             ,msi.s3_sales_acct_segment1
             ,msi.s3_sales_acct_segment2
             ,msi.s3_sales_acct_segment3
             ,msi.s3_sales_acct_segment4
             ,msi.s3_sales_acct_segment5
             ,msi.s3_sales_acct_segment6
             ,msi.s3_sales_acct_segment7
             ,msi.s3_sales_acct_segment8
             ,msi.s3_sales_acct_segment9
             ,msi.s3_sales_acct_segment10
             ,msi.default_include_in_rollup_flag
             ,msi.inventory_item_status_code
             ,msi.s3_inventory_item_status_code
             ,msi.inventory_planning_code
             ,msi.planner_code
             ,msi.s3_planner_code
             ,msi.planning_make_buy_code
             ,msi.fixed_lot_multiplier
             ,msi.rounding_control_type
             ,msi.postprocessing_lead_time
             ,msi.preprocessing_lead_time
             ,msi.full_lead_time
             ,msi.mrp_safety_stock_percent
             ,msi.mrp_safety_stock_code
             ,msi.min_minmax_quantity
             ,msi.max_minmax_quantity
             ,msi.minimum_order_quantity
             ,msi.fixed_order_quantity
             ,msi.fixed_days_supply
             ,msi.maximum_order_quantity
             ,msi.atp_rule_name
             ,msi.s3_atp_rule_name
             ,msi.reservable_type
             ,msi.vendor_warranty_flag
             ,msi.serviceable_product_flag
             ,msi.material_billable_flag
             ,msi.prorate_service_flag
             ,msi.invoiceable_item_flag
             ,msi.invoice_enabled_flag
             ,msi.outside_operation_flag
             ,msi.outside_operation_uom_type
             ,msi.safety_stock_bucket_days
             ,msi.costing_enabled_flag
             ,msi.cycle_count_enabled_flag
             ,msi.item_type
             ,msi.s3_item_type
             ,msi.ship_model_complete_flag
             ,msi.mrp_planning_code
             ,msi.ato_forecast_control
             ,msi.release_time_fence_code
             ,msi.release_time_fence_days
             ,msi.container_item_flag
             ,msi.vehicle_item_flag
             ,msi.effectivity_control
             ,msi.event_flag
             ,msi.electronic_flag
             ,msi.downloadable_flag
             ,msi.comms_nl_trackable_flag
             ,msi.orderable_on_web_flag
             ,msi.web_status
             ,msi.dimension_uom_code
             ,msi.unit_length
             ,msi.unit_width
             ,msi.unit_height
             ,msi.dual_uom_control
             ,msi.dual_uom_deviation_high
             ,msi.dual_uom_deviation_low
             ,msi.contract_item_type_code
             ,msi.serv_req_enabled_code
             ,msi.serv_billing_enabled_flag
             ,msi.default_so_source_type
             ,msi.object_version_number
             ,msi.tracking_quantity_ind
             ,msi.s3_tracking_quantity_ind
             ,msi.secondary_default_ind
             ,msi.s3_secondary_default_ind
             ,msi.so_authorization_flag
             ,msi.attribute17
             ,msi.attribute18
             ,msi.attribute19
             ,msi.attribute25
             ,msi.s3_attribute25
             ,msi.expiration_action_code
             ,msi.s3_expiration_action_code
             ,msi.expiration_action_interval
             ,msi.s3_expiration_action_interval
             ,msi.hazardous_material_flag
             ,msi.recipe_enabled_flag
             ,msi.start_auto_serial_number
             ,msi.auto_serial_alpha_prefix
             ,msi.retest_interval
             ,msi.repair_leadtime
             ,msi.gdsn_outbound_enabled_flag
             ,msi.revision_qty_control_code
             ,msi.legacy_revision_id
             ,msi.xxs3_revision_id
             ,msi.revision
             ,msi.revision_label
             ,msi.revision_description
             ,msi.effectivity_date
             ,msi.implementation_date
             ,msi.ecn_initiation_date
             ,msi.change_notice
             ,msi.revision_attribute10
             ,msi.revised_item_sequence_id
             ,msi.s3_revised_item_sequence_id
             ,msi.revision_language
             ,msi.source_lang
             ,msi.revision_tl_description
             ,msi. last_update_date
             ,msi.last_updated_by
             ,msi.orig_system_reference
             ,msi.date_extracted_on
             ,msi.process_flag
             ,msi.transform_status
             ,msi.transform_error
             ,msi.cleanse_status
             ,msi.cleanse_error
       FROM    xxobjt.xxs3_ptm_mtl_master_items msi
       WHERE  legacy_organization_code = 'UME'
       AND     S3_ORGANIZATION_CODE='M01'
       AND    planning_make_buy_code = 2;
     /* SELECT msi.l_inventory_item_id
            ,msi.s3_inventory_item_id
            ,msi.description
            ,msi.legacy_buyer_id
            ,msi.s3_buyer_number
            ,msi.legacy_accounting_rule_name
            ,msi.s3_accounting_rule_name
            ,msi.created_by
            ,msi.creation_date
            ,msi.segment1
            ,msi.attribute2
             --,msi.attribute9   
            ,(SELECT  msib.segment1
                         FROM   mtl_system_items_b           msib
                               ,hr_all_organization_units_tl hou
                         WHERE  hou.LANGUAGE = 'US'
                         AND    hou.NAME LIKE 'OMA%'
                         AND    msib.organization_id = hou.organization_id
                         AND    (msib.end_date_active IS NULL OR
                               msib.end_date_active < SYSDATE)
                         AND    msib.inventory_item_id = msi.attribute9
                         AND ROWNUM<2) attribute9
            ,msi.attribute11
            ,msi.attribute12
            ,msi.attribute13
            ,msi.purchasing_item_flag
            ,msi.shippable_item_flag
            ,msi.customer_order_flag
            ,msi.internal_order_flag
            ,msi.service_item_flag
            ,msi.inventory_item_flag
            ,msi.inventory_asset_flag
            ,msi.purchasing_enabled_flag
            ,msi.customer_order_enabled_flag
            ,msi.internal_order_enabled_flag
            ,msi.so_transactions_flag
            ,msi.mtl_transactions_enabled_flag
            ,msi.stock_enabled_flag
            ,msi.bom_enabled_flag
            ,msi.build_in_wip_flag
            ,msi.item_catalog_group_id
            ,msi.catalog_status_flag
            ,msi.returnable_flag
            ,msi.legacy_organization_id
            ,msi.legacy_organization_code
            ,mi.s3_org s3_organization_code
            ,msi.legacy_source_organization_id
            ,msi.l_source_organization_code
            ,msi. s3_source_organization_code
            ,msi.collateral_flag
            ,msi.taxable_flag
            ,msi.allow_item_desc_update_flag
            ,msi.inspection_required_flag
            ,msi.receipt_required_flag
            ,msi.qty_rcv_tolerance
            ,msi.list_price_per_unit
            ,msi.asset_category_id
            ,msi.unit_of_issue
            ,msi.allow_substitute_receipts_flag
            ,msi.allow_unordered_receipts_flag
            ,msi.allow_express_delivery_flag
            ,msi.days_early_receipt_allowed
            ,msi.days_late_receipt_allowed
            ,msi.receipt_days_exception_code
            ,msi.receiving_routing_id
            ,msi.auto_lot_alpha_prefix
            ,msi.start_auto_lot_number
            ,msi.lot_control_code
            ,msi.shelf_life_code
            ,msi.shelf_life_days
            ,msi.serial_number_control_code
            ,msi.source_type
            ,msi.source_subinventory
            ,msi.expense_account
            ,msi.legacy_expense_account
            ,msi.legacy_expense_acct_segment1
            ,msi.legacy_expense_acct_segment2
            ,msi.legacy_expense_acct_segment3
            ,msi.legacy_expense_acct_segment4
            ,msi.legacy_expense_acct_segment5
            ,msi.legacy_expense_acct_segment6
            ,msi.legacy_expense_acct_segment7
            ,msi.legacy_expense_acct_segment8
            ,msi.legacy_expense_acct_segment9
            ,msi.legacy_expense_acct_segment10
            ,msi.s3_expense_acct_segment1
            ,msi.s3_expense_acct_segment2
            ,msi.s3_expense_acct_segment3
            ,msi.s3_expense_acct_segment4
            ,msi.s3_expense_acct_segment5
            ,msi.s3_expense_acct_segment6
            ,msi.s3_expense_acct_segment7
            ,msi.s3_expense_acct_segment8
            ,msi.restrict_subinventories_code
            ,msi.unit_weight
            ,msi.weight_uom_code
            ,msi.volume_uom_code
            ,msi.unit_volume
            ,msi.shrinkage_rate
            ,msi.acceptable_early_days
            ,msi.planning_time_fence_code
            ,msi.lead_time_lot_size
            ,msi.std_lot_size
            ,msi.overrun_percentage
            ,msi.mrp_calculate_atp_flag
            ,msi.acceptable_rate_increase
            ,msi.acceptable_rate_decrease
            ,msi.planning_time_fence_days
            ,msi.end_assembly_pegging_flag
            ,msi.bom_item_type
            ,msi.pick_components_flag
            ,msi.replenish_to_order_flag
            ,msi.atp_components_flag
            ,msi.atp_flag
            ,msi.wip_supply_type
            ,msi.wip_supply_subinventory
            ,msi.s3_wip_supply_subinventory
            ,msi.primary_uom_code
            ,msi.secondary_uom_code
            ,msi.s3_secondary_uom_code
            ,msi.primary_unit_of_measure
            ,msi.allowed_units_lookup_code
            ,msi.cost_of_sales_account
            ,msi.l_cost_of_sales_account
            ,msi.l_cost_of_sales_acct_segment1
            ,msi.l_cost_of_sales_acct_segment2
            ,msi.l_cost_of_sales_acct_segment3
            ,msi.l_cost_of_sales_acct_segment4
            ,msi.l_cost_of_sales_acct_segment5
            ,msi.l_cost_of_sales_acct_segment6
            ,msi.l_cost_of_sales_acct_segment7
            ,msi.l_cost_of_sales_acct_segment8
            ,msi.l_cost_of_sales_acct_segment9
            ,msi.l_cost_of_sales_acct_segment10
            ,msi.s3_cost_sales_acct_segment1
            ,msi.s3_cost_sales_acct_segment2
            ,msi.s3_cost_sales_acct_segment3
            ,msi.s3_cost_sales_acct_segment4
            ,msi.s3_cost_sales_acct_segment5
            ,msi.s3_cost_sales_acct_segment6
            ,msi.s3_cost_sales_acct_segment7
            ,msi.s3_cost_sales_acct_segment8
            ,msi.s3_cost_sales_acct_segment9
            ,msi.s3_cost_sales_acct_segment10
            ,msi.sales_account
            ,msi.legacy_sales_account
            ,msi.legacy_sales_acct_segment1
            ,msi.legacy_sales_acct_segment2
            ,msi.legacy_sales_acct_segment3
            ,msi.legacy_sales_acct_segment4
            ,msi.legacy_sales_acct_segment5
            ,msi.legacy_sales_acct_segment6
            ,msi.legacy_sales_acct_segment7
            ,msi.legacy_sales_acct_segment8
            ,msi.legacy_sales_acct_segment9
            ,msi.legacy_sales_acct_segment10
            ,msi.s3_sales_acct_segment1
            ,msi.s3_sales_acct_segment2
            ,msi.s3_sales_acct_segment3
            ,msi.s3_sales_acct_segment4
            ,msi.s3_sales_acct_segment5
            ,msi.s3_sales_acct_segment6
            ,msi.s3_sales_acct_segment7
            ,msi.s3_sales_acct_segment8
            ,msi.s3_sales_acct_segment9
            ,msi.s3_sales_acct_segment10
            ,msi.default_include_in_rollup_flag
            ,msi.inventory_item_status_code
            ,msi.s3_inventory_item_status_code
            ,msi.inventory_planning_code
            ,msi.planner_code
            ,msi.s3_planner_code
            ,msi.planning_make_buy_code
            ,msi.fixed_lot_multiplier
            ,msi.rounding_control_type
            ,msi.postprocessing_lead_time
            ,msi.preprocessing_lead_time
            ,msi.full_lead_time
            ,msi.mrp_safety_stock_percent
            ,msi.mrp_safety_stock_code
            ,msi.min_minmax_quantity
            ,msi.max_minmax_quantity
            ,msi.minimum_order_quantity
            ,msi.fixed_order_quantity
            ,msi.fixed_days_supply
            ,msi.maximum_order_quantity
            ,msi.atp_rule_name
            ,msi.s3_atp_rule_name
            ,msi.reservable_type
            ,msi.vendor_warranty_flag
            ,msi.serviceable_product_flag
            ,msi.material_billable_flag
            ,msi.prorate_service_flag
            ,msi.invoiceable_item_flag
            ,msi.invoice_enabled_flag
            ,msi.outside_operation_flag
            ,msi.outside_operation_uom_type
            ,msi.safety_stock_bucket_days
            ,msi.costing_enabled_flag
            ,msi.cycle_count_enabled_flag
            ,msi.item_type
            ,msi.s3_item_type
            ,msi.ship_model_complete_flag
            ,msi.mrp_planning_code
            ,msi.ato_forecast_control
            ,msi.release_time_fence_code
            ,msi.release_time_fence_days
            ,msi.container_item_flag
            ,msi.vehicle_item_flag
            ,msi.effectivity_control
            ,msi.event_flag
            ,msi.electronic_flag
            ,msi.downloadable_flag
            ,msi.comms_nl_trackable_flag
            ,msi.orderable_on_web_flag
            ,msi.web_status
            ,msi.dimension_uom_code
            ,msi.unit_length
            ,msi.unit_width
            ,msi.unit_height
            ,msi.dual_uom_control
            ,msi.dual_uom_deviation_high
            ,msi.dual_uom_deviation_low
            ,msi.contract_item_type_code
            ,msi.serv_req_enabled_code
            ,msi.serv_billing_enabled_flag
            ,msi.default_so_source_type
            ,msi.object_version_number
            ,msi.tracking_quantity_ind
            ,msi.s3_tracking_quantity_ind
            ,msi.secondary_default_ind
            ,msi.s3_secondary_default_ind
            ,msi.so_authorization_flag
            ,msi.attribute17
            ,msi.attribute18
            ,msi.attribute19
            ,msi.attribute25
            ,msi.s3_attribute25
            ,msi.expiration_action_code
            ,msi.s3_expiration_action_code
            ,msi.expiration_action_interval
            ,msi.s3_expiration_action_interval
            ,msi.hazardous_material_flag
            ,msi.recipe_enabled_flag
            ,msi.start_auto_serial_number
            ,msi.auto_serial_alpha_prefix
            ,msi.retest_interval
            ,msi.repair_leadtime
            ,msi.gdsn_outbound_enabled_flag
            ,msi.revision_qty_control_code
            ,msi.legacy_revision_id
            ,msi.xxs3_revision_id
            ,msi.revision
            ,msi.revision_label
            ,msi.revision_description
            ,msi.effectivity_date
            ,msi.implementation_date
            ,msi.ecn_initiation_date
            ,msi.change_notice
            ,msi.revision_attribute10
            ,msi.revised_item_sequence_id
            ,msi.s3_revised_item_sequence_id
            ,msi.revision_language
            ,msi.source_lang
            ,msi.revision_tl_description
            ,msi. last_update_date
            ,msi.last_updated_by
            ,msi.orig_system_reference
            ,msi.date_extracted_on
            ,msi.process_flag
            ,msi.transform_status
            ,msi.transform_error
            ,msi.cleanse_status
            ,msi.cleanse_error
      FROM   xxobjt.xxs3_hub_spoke_org_map mi
            ,xxs3_ptm_mtl_master_items         msi
      WHERE  mi.legacy_org = msi.legacy_organization_code
      AND    mi.s3_org NOT IN ('M01', 'T03')
      AND EXISTS --  msi.l_inventory_item_id IN --exists
             (SELECT inventory_item_id
               FROM   mtl_item_categories_v mic
                     ,mtl_parameters        mp
               WHERE  organization_code = p_organization_code --'UME - only' 
               AND    (segment7 = 'FG' OR segment1 = 'Customer Support')
               AND    mic.inventory_item_id = msi.l_inventory_item_id
               AND    mic.organization_id = mp.organization_id)
      ORDER  BY l_inventory_item_id
               ,s3_org;
	   
 --Cursor for the T03 org for Buy Items  
 
    CURSOR c_ume_t03 IS
     SELECT mi.s3_org s3_organization_codes
           ,msi.*
     FROM   xxobjt.xxs3_hub_spoke_org_map mi
           ,xxs3_ptm_mtl_master_items         msi
     WHERE  mi.legacy_org = msi.legacy_organization_code
     AND    mi.s3_org NOT IN ('M01', 'S01', 'S02', 'S03')
     AND    planning_make_buy_code = '2';*/
     
-- Cursor for the transformation of the attributes 
  
    CURSOR c_transform IS
      SELECT *
      FROM   xxobjt.xxs3_ptm_mtl_master_items
      WHERE  process_flag IN ('N', 'Y', 'Q');
	   
 --Cursor for the BOM Explosion Procedure 
  
   /* CURSOR bom_cur IS
      SELECT DISTINCT l_inventory_item_id, legacy_organization_id
      FROM xxobjt.xxs3_ptm_mtl_master_items;
      --WHERE process_flag IN ('Y', 'N', 'Q');*/
      
  -- utl org cursor 
  CURSOR c_out IS
  /*SELECT DISTINCT s3_organization_code
  FROM   xxobjt.xxs3_ptm_mtl_master_items*/
  SELECT  s3_organization_code
  FROM   xxobjt.xxs3_ptm_mtl_master_items
  WHERE ROWNUM<2;
  
    l_err_code VARCHAR2(4000);
    l_err_msg  VARCHAR2(4000);
	
TYPE fetch_master IS TABLE OF c_master_items_extract%ROWTYPE;
bulk_master fetch_master;

TYPE fetch_bom IS TABLE OF c_org_bom_exp_items%ROWTYPE;
bulk_bom fetch_bom;

TYPE fetch_s01 IS TABLE OF c_ume_s01%ROWTYPE;
bulk_s01 fetch_s01;

/*TYPE fetch_t03 IS TABLE OF c_ume_t03%ROWTYPE;
bulk_t03 fetch_t03;*/
  
  BEGIN
    x_retcode := 0;
    x_errbuf  := 'COMPLETE';
    
    BEGIN
      log_p('Org Code Parameter'|| p_organization_code);
  
       --Delete the Records in the stage table before insert 
	  
       EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.XXS3_PTM_MTL_MASTER_ITEMS';
      
       -- Delete the Records in the DQ stage table before insert 
       EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_ptm_mtl_master_items_dq';
   
      -- Insert records into staging table 
	  BEGIN
    
	  OPEN c_master_items_extract;
 	  LOOP 
      FETCH c_master_items_extract BULK COLLECT INTO bulk_master LIMIT 10000;
      
	      FORALL i IN 1..bulk_master.COUNT 
        
        INSERT INTO xxobjt.xxs3_ptm_mtl_master_items
          (xx_inventory_item_id
          ,l_inventory_item_id
          ,description
          ,legacy_buyer_id
          ,legacy_accounting_rule_name
          ,segment1
          ,attribute2
          ,attribute9
          ,attribute11
          ,attribute12
          ,attribute13
          ,purchasing_item_flag
          ,shippable_item_flag
          ,customer_order_flag
          ,internal_order_flag
          ,service_item_flag
          ,inventory_item_flag
          ,inventory_asset_flag
          ,purchasing_enabled_flag
          ,customer_order_enabled_flag
          ,internal_order_enabled_flag
          ,so_transactions_flag
          ,mtl_transactions_enabled_flag
          ,stock_enabled_flag
          ,bom_enabled_flag
          ,build_in_wip_flag
          ,item_catalog_group_id
          ,catalog_status_flag
          ,returnable_flag
          ,legacy_organization_id
          ,legacy_organization_code
          ,legacy_source_organization_id
          ,l_source_organization_code
          ,collateral_flag
          ,taxable_flag
          ,allow_item_desc_update_flag
          ,inspection_required_flag
          ,receipt_required_flag
          ,qty_rcv_tolerance
          ,list_price_per_unit
          ,asset_category_id
          ,unit_of_issue
          ,allow_substitute_receipts_flag
          ,allow_unordered_receipts_flag
          ,allow_express_delivery_flag
          ,days_early_receipt_allowed
          ,days_late_receipt_allowed
          ,receipt_days_exception_code
          ,receiving_routing_id
          ,auto_lot_alpha_prefix
          ,start_auto_lot_number
          ,lot_control_code
          ,shelf_life_code
          ,shelf_life_days
          ,serial_number_control_code
          ,source_type
          ,source_subinventory
          ,expense_account
          ,legacy_expense_account
          ,legacy_expense_acct_segment1
          ,legacy_expense_acct_segment2
          ,legacy_expense_acct_segment3
          ,legacy_expense_acct_segment4
          ,legacy_expense_acct_segment5
          ,legacy_expense_acct_segment6
          ,legacy_expense_acct_segment7
          ,legacy_expense_acct_segment8
          ,legacy_expense_acct_segment9
          ,legacy_expense_acct_segment10
          ,restrict_subinventories_code
          ,unit_weight
          ,weight_uom_code
          ,volume_uom_code
          ,unit_volume
          ,shrinkage_rate
          ,acceptable_early_days
          ,planning_time_fence_code
          ,lead_time_lot_size
          ,std_lot_size
          ,overrun_percentage
          ,mrp_calculate_atp_flag
          ,acceptable_rate_increase
          ,acceptable_rate_decrease
          ,planning_time_fence_days
          ,end_assembly_pegging_flag
          ,bom_item_type
          ,pick_components_flag
          ,replenish_to_order_flag
          ,atp_components_flag
          ,atp_flag
          ,wip_supply_type
          ,wip_supply_subinventory
          ,primary_uom_code
          ,primary_unit_of_measure
          ,allowed_units_lookup_code
          ,cost_of_sales_account
          ,l_cost_of_sales_account
          ,l_cost_of_sales_acct_segment1
          ,l_cost_of_sales_acct_segment2
          ,l_cost_of_sales_acct_segment3
          ,l_cost_of_sales_acct_segment4
          ,l_cost_of_sales_acct_segment5
          ,l_cost_of_sales_acct_segment6
          ,l_cost_of_sales_acct_segment7
          ,l_cost_of_sales_acct_segment8
          ,l_cost_of_sales_acct_segment9
          ,l_cost_of_sales_acct_segment10
          ,sales_account
          ,legacy_sales_account
          ,legacy_sales_acct_segment1
          ,legacy_sales_acct_segment2
          ,legacy_sales_acct_segment3
          ,legacy_sales_acct_segment4
          ,legacy_sales_acct_segment5
          ,legacy_sales_acct_segment6
          ,legacy_sales_acct_segment7
          ,legacy_sales_acct_segment8
          ,legacy_sales_acct_segment9
          ,legacy_sales_acct_segment10
          ,default_include_in_rollup_flag
          ,inventory_item_status_code
          ,inventory_planning_code
          ,start_auto_serial_number
          ,auto_serial_alpha_prefix
          ,planner_code
          ,planning_make_buy_code
          ,fixed_lot_multiplier
          ,rounding_control_type
          ,postprocessing_lead_time
          ,preprocessing_lead_time
          ,full_lead_time
          ,mrp_safety_stock_percent
          ,mrp_safety_stock_code
          ,min_minmax_quantity
          ,max_minmax_quantity
          ,minimum_order_quantity
          ,fixed_order_quantity
          ,fixed_days_supply
          ,maximum_order_quantity
          ,atp_rule_name
          ,reservable_type
          ,vendor_warranty_flag
          ,serviceable_product_flag
          ,material_billable_flag
          ,prorate_service_flag
          ,invoiceable_item_flag
          ,invoice_enabled_flag
          ,outside_operation_flag
          ,outside_operation_uom_type
          ,safety_stock_bucket_days
          ,costing_enabled_flag
          ,cycle_count_enabled_flag
          ,item_type
          ,ship_model_complete_flag
          ,mrp_planning_code
          ,ato_forecast_control
          ,release_time_fence_code
          ,release_time_fence_days
          ,container_item_flag
          ,vehicle_item_flag
          ,effectivity_control
          ,event_flag
          ,electronic_flag
          ,downloadable_flag
          ,comms_nl_trackable_flag
          ,orderable_on_web_flag
          ,web_status
          ,dimension_uom_code
          ,unit_length
          ,unit_width
          ,unit_height
          ,dual_uom_control
          ,dual_uom_deviation_high
          ,dual_uom_deviation_low
          ,contract_item_type_code
          ,serv_req_enabled_code
          ,serv_billing_enabled_flag
          ,default_so_source_type
          ,object_version_number
          ,tracking_quantity_ind
          ,secondary_default_ind
          ,so_authorization_flag
          ,attribute17
          ,attribute18
          ,attribute19
          ,attribute25
          ,expiration_action_code
          ,expiration_action_interval
          ,hazardous_material_flag
          ,recipe_enabled_flag
          ,retest_interval
          ,repair_leadtime
          ,gdsn_outbound_enabled_flag
          ,revision_qty_control_code
          ,legacy_revision_id
          ,revision
          ,revision_label
          ,revision_description
          ,effectivity_date
          ,implementation_date
          ,ecn_initiation_date
          ,change_notice
          ,revision_attribute10
          ,revised_item_sequence_id
          ,revision_language
          ,source_lang
          ,revision_tl_description
          ,creation_date
          ,date_extracted_on
          ,process_flag)
        VALUES
          (xxobjt.xxs3_ptm_mtl_master_items_seq.NEXTVAL
          ,bulk_master(i).l_inventory_item_id
          ,bulk_master(i).description
          ,bulk_master(i).buyer_id
          ,bulk_master(i).accounting_rule_name
          ,bulk_master(i).segment1
          ,bulk_master(i).attribute2
          ,bulk_master(i).attribute9
          ,bulk_master(i).attribute11
          ,bulk_master(i).attribute12
          ,bulk_master(i).attribute13
          ,bulk_master(i).purchasing_item_flag
          ,bulk_master(i).shippable_item_flag
          ,bulk_master(i).customer_order_flag
          ,bulk_master(i).internal_order_flag
          ,bulk_master(i).service_item_flag
          ,bulk_master(i).inventory_item_flag
          ,bulk_master(i).inventory_asset_flag
          ,bulk_master(i).purchasing_enabled_flag
          ,bulk_master(i).customer_order_enabled_flag
          ,bulk_master(i).internal_order_enabled_flag
          ,bulk_master(i).so_transactions_flag
          ,bulk_master(i).mtl_transactions_enabled_flag
          ,bulk_master(i).stock_enabled_flag
          ,bulk_master(i).bom_enabled_flag
          ,bulk_master(i).build_in_wip_flag
          ,bulk_master(i).item_catalog_group_id
          ,bulk_master(i).catalog_status_flag
          ,bulk_master(i).returnable_flag
          ,bulk_master(i).organization_id
          ,bulk_master(i).organization_code
          ,bulk_master(i).source_organization_id
          ,bulk_master(i).source_organization_code
          ,bulk_master(i).collateral_flag
          ,bulk_master(i).taxable_flag
          ,bulk_master(i).allow_item_desc_update_flag
          ,bulk_master(i).inspection_required_flag
          ,bulk_master(i).receipt_required_flag
          ,bulk_master(i).qty_rcv_tolerance
          ,bulk_master(i).list_price_per_unit
          ,bulk_master(i).asset_category_id
          ,bulk_master(i).unit_of_issue
          ,bulk_master(i).allow_substitute_receipts_flag
          ,bulk_master(i).allow_unordered_receipts_flag
          ,bulk_master(i).allow_express_delivery_flag
          ,bulk_master(i).days_early_receipt_allowed
          ,bulk_master(i).days_late_receipt_allowed
          ,bulk_master(i).receipt_days_exception_code
          ,bulk_master(i).receiving_routing_id
          ,bulk_master(i).auto_lot_alpha_prefix
          ,bulk_master(i).start_auto_lot_number
          ,bulk_master(i).lot_control_code
          ,bulk_master(i).shelf_life_code
          ,bulk_master(i).shelf_life_days
          ,bulk_master(i).serial_number_control_code
          ,bulk_master(i).source_type
          ,bulk_master(i).source_subinventory
          ,bulk_master(i).expense_account
          ,bulk_master(i).legacy_expense_account
          ,bulk_master(i).expense_acct_segment1
          ,bulk_master(i).expense_acct_segment2
          ,bulk_master(i).expense_acct_segment3
          ,bulk_master(i).expense_acct_segment4
          ,bulk_master(i).expense_acct_segment5
          ,bulk_master(i).expense_acct_segment6
          ,bulk_master(i).expense_acct_segment7
          ,bulk_master(i).expense_acct_segment8
          ,bulk_master(i).expense_acct_segment9
          ,bulk_master(i).expense_acct_segment10
          ,bulk_master(i).restrict_subinventories_code
          ,bulk_master(i).unit_weight
          ,bulk_master(i).weight_uom_code
          ,bulk_master(i).volume_uom_code
          ,bulk_master(i).unit_volume
          ,bulk_master(i).shrinkage_rate
          ,bulk_master(i).acceptable_early_days
          ,bulk_master(i).planning_time_fence_code
          ,bulk_master(i).lead_time_lot_size
          ,bulk_master(i).std_lot_size
          ,bulk_master(i).overrun_percentage
          ,bulk_master(i).mrp_calculate_atp_flag
          ,bulk_master(i).acceptable_rate_increase
          ,bulk_master(i).acceptable_rate_decrease
          ,bulk_master(i).planning_time_fence_days
          ,bulk_master(i).end_assembly_pegging_flag
          ,bulk_master(i).bom_item_type
          ,bulk_master(i).pick_components_flag
          ,bulk_master(i).replenish_to_order_flag
          ,bulk_master(i).atp_components_flag
          ,bulk_master(i).atp_flag
          ,bulk_master(i).wip_supply_type
          ,bulk_master(i).wip_supply_subinventory
          ,bulk_master(i).primary_uom_code
          ,bulk_master(i).primary_unit_of_measure
          ,bulk_master(i).allowed_units_lookup_code
          ,bulk_master(i).cost_of_sales_account
          ,bulk_master(i).legacy_cost_of_sales_account
          ,bulk_master(i).cost_of_sales_acct_segment1
          ,bulk_master(i).cost_of_sales_acct_segment2
          ,bulk_master(i).cost_of_sales_acct_segment3
          ,bulk_master(i).cost_of_sales_acct_segment4
          ,bulk_master(i).cost_of_sales_acct_segment5
          ,bulk_master(i).cost_of_sales_acct_segment6
          ,bulk_master(i).cost_of_sales_acct_segment7
          ,bulk_master(i).cost_of_sales_acct_segment8
          ,bulk_master(i).cost_of_sales_acct_segment9
          ,bulk_master(i).cost_of_sales_acct_segment10
          ,bulk_master(i).sales_account
          ,bulk_master(i).legacy_sales_account
          ,bulk_master(i).sales_acct_segment1
          ,bulk_master(i).sales_acct_segment2
          ,bulk_master(i).sales_acct_segment3
          ,bulk_master(i).sales_acct_segment4
          ,bulk_master(i).sales_acct_segment5
          ,bulk_master(i).sales_acct_segment6
          ,bulk_master(i).sales_acct_segment7
          ,bulk_master(i).sales_acct_segment8
          ,bulk_master(i).sales_acct_segment9
          ,bulk_master(i).sales_acct_segment10
          ,bulk_master(i).default_include_in_rollup_flag
          ,bulk_master(i).inventory_item_status_code
          ,bulk_master(i).inventory_planning_code
          ,bulk_master(i).start_auto_serial_number
          ,bulk_master(i).auto_serial_alpha_prefix
          ,bulk_master(i).planner_code
          ,bulk_master(i).planning_make_buy_code
          ,bulk_master(i).fixed_lot_multiplier
          ,bulk_master(i).rounding_control_type
          ,bulk_master(i).postprocessing_lead_time
          ,bulk_master(i).preprocessing_lead_time
          ,bulk_master(i).full_lead_time
          ,bulk_master(i).mrp_safety_stock_percent
          ,bulk_master(i).mrp_safety_stock_code
          ,bulk_master(i).min_minmax_quantity
          ,bulk_master(i).max_minmax_quantity
          ,bulk_master(i).minimum_order_quantity
          ,bulk_master(i).fixed_order_quantity
          ,bulk_master(i).fixed_days_supply
          ,bulk_master(i).maximum_order_quantity
          ,bulk_master(i).atp_rule_name
          ,bulk_master(i).reservable_type
          ,bulk_master(i).vendor_warranty_flag
          ,bulk_master(i).serviceable_product_flag
          ,bulk_master(i).material_billable_flag
          ,bulk_master(i).prorate_service_flag
          ,bulk_master(i).invoiceable_item_flag
          ,bulk_master(i).invoice_enabled_flag
          ,bulk_master(i).outside_operation_flag
          ,bulk_master(i).outside_operation_uom_type
          ,bulk_master(i).safety_stock_bucket_days
          ,bulk_master(i).costing_enabled_flag
          ,bulk_master(i).cycle_count_enabled_flag
          ,bulk_master(i).item_type
          ,bulk_master(i).ship_model_complete_flag
          ,bulk_master(i).mrp_planning_code
          ,bulk_master(i).ato_forecast_control
          ,bulk_master(i).release_time_fence_code
          ,bulk_master(i).release_time_fence_days
          ,bulk_master(i).container_item_flag
          ,bulk_master(i).vehicle_item_flag
          ,bulk_master(i).effectivity_control
          ,bulk_master(i).event_flag
          ,bulk_master(i).electronic_flag
          ,bulk_master(i).downloadable_flag
          ,bulk_master(i).comms_nl_trackable_flag
          ,bulk_master(i).orderable_on_web_flag
          ,bulk_master(i).web_status
          ,bulk_master(i).dimension_uom_code
          ,bulk_master(i).unit_length
          ,bulk_master(i).unit_width
          ,bulk_master(i).unit_height
          ,bulk_master(i).dual_uom_control
          ,bulk_master(i).dual_uom_deviation_high
          ,bulk_master(i).dual_uom_deviation_low
          ,bulk_master(i).contract_item_type_code
          ,bulk_master(i).serv_req_enabled_code
          ,bulk_master(i).serv_billing_enabled_flag
          ,bulk_master(i).default_so_source_type
          ,bulk_master(i).object_version_number
          ,bulk_master(i).tracking_quantity_ind
          ,bulk_master(i).secondary_default_ind
          ,bulk_master(i).so_authorization_flag
          ,bulk_master(i).attribute17
          ,bulk_master(i).attribute18
          ,bulk_master(i).attribute19
          ,bulk_master(i).attribute25
          ,bulk_master(i).expiration_action_code
          ,bulk_master(i).expiration_action_interval
          ,bulk_master(i).hazardous_material_flag
          ,bulk_master(i).recipe_enabled_flag
          ,bulk_master(i).retest_interval
          ,bulk_master(i).repair_leadtime
          ,bulk_master(i).gdsn_outbound_enabled_flag
          ,'1'
          ,bulk_master(i).revision_id
          ,bulk_master(i).revision
          ,bulk_master(i).revision_label
          ,bulk_master(i).revision_description
          ,bulk_master(i).effectivity_date
          ,bulk_master(i).implementation_date
          ,bulk_master(i).ecn_initiation_date
          ,bulk_master(i).change_notice
          ,bulk_master(i).r_attribute10
          ,bulk_master(i).revised_item_sequence_id
          ,bulk_master(i).LANGUAGE
          ,bulk_master(i).source_lang
          ,bulk_master(i).tl_description
          ,bulk_master(i).creation_date
          ,SYSDATE
          ,'N');
          
       EXIT WHEN c_master_items_extract%NOTFOUND;
  END LOOP;
  CLOSE c_master_items_extract;
  COMMIT;
  EXCEPTION 
   WHEN no_data_found THEN
	  log_p('Error: No data found in Main Insert'||' '||SQLCODE||'-' ||SQLERRM);
    
  WHEN others THEN
    log_p('Exception in the Bulk Insert'||'-'||SQLERRM);
	  l_Err_Count := SQL%BULK_EXCEPTIONS.COUNT;
    log_p('Number of statements that failed:' || l_Err_Count);
    FOR i IN 1..l_Err_Count
   LOOP
     log_p('Error #'|| i || 'occurred during '||'iteration #' || SQL%BULK_EXCEPTIONS(i).ERROR_INDEX);
     log_p('Error message is ' ||
     SQLERRM(-SQL%BULK_EXCEPTIONS(i).ERROR_CODE));
     END LOOP;
 END; 
 
      log_p('Master Records Inserted for Organization'||p_organization_code);
            
      	 --  Org Business Rule 
       FOR org_cur IN c_transform LOOP
	  		
        IF org_cur.l_inventory_item_id IS NOT NULL THEN
         		  
          org_rules_items(org_cur.l_inventory_item_id,
                          org_cur.legacy_organization_code);   --Org Business Rule Procedure 
        END IF;
     END LOOP;
     COMMIT;
   
      --Delete the records from the bom custom stage tables before insert 
	 
      EXECUTE IMMEDIATE 'TRUNCATE TABLE XXOBJT.XXS3_PTM_BOM_ITEM_EXPL_TEMP';
	  
      EXECUTE IMMEDIATE 'TRUNCATE TABLE XXOBJT.XXS3_PTM_BOM_CMPNT_ITEM_STG';
        
      BEGIN
      prc_s3_item_bom_explode;  -- BOM Explode API Call Procedure 
      END;   
     --Insert the BOM Exploded Items in the stage table- no duplicate Items Insert 
	BEGIN
       OPEN c_org_bom_exp_items;
	  LOOP
      FETCH c_org_bom_exp_items BULK COLLECT INTO bulk_bom LIMIT 10000;
	   FORALL i IN 1..bulk_bom.COUNT      	
        INSERT INTO xxobjt.xxs3_ptm_mtl_master_items
          (xx_inventory_item_id
          ,l_inventory_item_id
          ,description
          ,legacy_buyer_id
          ,legacy_accounting_rule_name
          ,segment1
          ,attribute2
          ,attribute9
          ,attribute11
          ,attribute12
          ,attribute13
          ,purchasing_item_flag
          ,shippable_item_flag
          ,customer_order_flag
          ,internal_order_flag
          ,service_item_flag
          ,inventory_item_flag
          ,inventory_asset_flag
          ,purchasing_enabled_flag
          ,customer_order_enabled_flag
          ,internal_order_enabled_flag
          ,so_transactions_flag
          ,mtl_transactions_enabled_flag
          ,stock_enabled_flag
          ,bom_enabled_flag
          ,build_in_wip_flag
          ,item_catalog_group_id
          ,catalog_status_flag
          ,returnable_flag
          ,legacy_organization_id
          ,legacy_organization_code
          ,legacy_source_organization_id
          ,l_source_organization_code
          ,collateral_flag
          ,taxable_flag
          ,allow_item_desc_update_flag
          ,inspection_required_flag
          ,receipt_required_flag
          ,qty_rcv_tolerance
          ,list_price_per_unit
          ,asset_category_id
          ,unit_of_issue
          ,allow_substitute_receipts_flag
          ,allow_unordered_receipts_flag
          ,allow_express_delivery_flag
          ,days_early_receipt_allowed
          ,days_late_receipt_allowed
          ,receipt_days_exception_code
          ,receiving_routing_id
          ,auto_lot_alpha_prefix
          ,start_auto_lot_number
          ,lot_control_code
          ,shelf_life_code
          ,shelf_life_days
          ,serial_number_control_code
          ,source_type
          ,source_subinventory
          ,expense_account
          ,legacy_expense_account
          ,legacy_expense_acct_segment1
          ,legacy_expense_acct_segment2
          ,legacy_expense_acct_segment3
          ,legacy_expense_acct_segment4
          ,legacy_expense_acct_segment5
          ,legacy_expense_acct_segment6
          ,legacy_expense_acct_segment7
          ,legacy_expense_acct_segment8
          ,legacy_expense_acct_segment9
          ,legacy_expense_acct_segment10
          ,restrict_subinventories_code
          ,unit_weight
          ,weight_uom_code
          ,volume_uom_code
          ,unit_volume
          ,shrinkage_rate
          ,acceptable_early_days
          ,planning_time_fence_code
          ,lead_time_lot_size
          ,std_lot_size
          ,overrun_percentage
          ,mrp_calculate_atp_flag
          ,acceptable_rate_increase
          ,acceptable_rate_decrease
          ,planning_time_fence_days
          ,end_assembly_pegging_flag
          ,bom_item_type
          ,pick_components_flag
          ,replenish_to_order_flag
          ,atp_components_flag
          ,atp_flag
          ,wip_supply_type
          ,wip_supply_subinventory
          ,primary_uom_code
          ,primary_unit_of_measure
          ,allowed_units_lookup_code
          ,cost_of_sales_account
          ,l_cost_of_sales_account
          ,l_cost_of_sales_acct_segment1
          ,l_cost_of_sales_acct_segment2
          ,l_cost_of_sales_acct_segment3
          ,l_cost_of_sales_acct_segment4
          ,l_cost_of_sales_acct_segment5
          ,l_cost_of_sales_acct_segment6
          ,l_cost_of_sales_acct_segment7
          ,l_cost_of_sales_acct_segment8
          ,l_cost_of_sales_acct_segment9
          ,l_cost_of_sales_acct_segment10
          ,sales_account
          ,legacy_sales_account
          ,legacy_sales_acct_segment1
          ,legacy_sales_acct_segment2
          ,legacy_sales_acct_segment3
          ,legacy_sales_acct_segment4
          ,legacy_sales_acct_segment5
          ,legacy_sales_acct_segment6
          ,legacy_sales_acct_segment7
          ,legacy_sales_acct_segment8
          ,legacy_sales_acct_segment9
          ,legacy_sales_acct_segment10
          ,default_include_in_rollup_flag
          ,inventory_item_status_code
          ,inventory_planning_code
          ,start_auto_serial_number
          ,auto_serial_alpha_prefix
          ,planner_code
          ,planning_make_buy_code
          ,fixed_lot_multiplier
          ,rounding_control_type
          ,postprocessing_lead_time
          ,preprocessing_lead_time
          ,full_lead_time
          ,mrp_safety_stock_percent
          ,mrp_safety_stock_code
          ,min_minmax_quantity
          ,max_minmax_quantity
          ,minimum_order_quantity
          ,fixed_order_quantity
          ,fixed_days_supply
          ,maximum_order_quantity
          ,atp_rule_name
          ,reservable_type
          ,vendor_warranty_flag
          ,serviceable_product_flag
          ,material_billable_flag
          ,prorate_service_flag
          ,invoiceable_item_flag
          ,invoice_enabled_flag
          ,outside_operation_flag
          ,outside_operation_uom_type
          ,safety_stock_bucket_days
          ,costing_enabled_flag
          ,cycle_count_enabled_flag
          ,item_type
          ,ship_model_complete_flag
          ,mrp_planning_code
          ,ato_forecast_control
          ,release_time_fence_code
          ,release_time_fence_days
          ,container_item_flag
          ,vehicle_item_flag
          ,effectivity_control
          ,event_flag
          ,electronic_flag
          ,downloadable_flag
          ,comms_nl_trackable_flag
          ,orderable_on_web_flag
          ,web_status
          ,dimension_uom_code
          ,unit_length
          ,unit_width
          ,unit_height
          ,dual_uom_control
          ,dual_uom_deviation_high
          ,dual_uom_deviation_low
          ,contract_item_type_code
          ,serv_req_enabled_code
          ,serv_billing_enabled_flag
          ,default_so_source_type
          ,object_version_number
          ,tracking_quantity_ind
          ,secondary_default_ind
          ,so_authorization_flag
          ,attribute17
          ,attribute18
          ,attribute19
          ,attribute25
          ,expiration_action_code
          ,expiration_action_interval
          ,hazardous_material_flag
          ,recipe_enabled_flag
          ,retest_interval
          ,repair_leadtime
          ,gdsn_outbound_enabled_flag
          ,revision_qty_control_code
          ,legacy_revision_id
          ,revision
          ,revision_label
          ,revision_description
          ,effectivity_date
          ,implementation_date
          ,ecn_initiation_date
          ,change_notice
          ,revision_attribute10
          ,revised_item_sequence_id
          ,revision_language
          ,source_lang
          ,revision_tl_description
          ,creation_date
          ,date_extracted_on
          ,process_flag)
        VALUES
          (xxobjt.xxs3_ptm_mtl_master_items_seq.NEXTVAL
          ,bulk_bom(i).l_inventory_item_id
          ,bulk_bom(i).description
          ,bulk_bom(i).buyer_id
          ,bulk_bom(i).accounting_rule_name
          ,bulk_bom(i).segment1
          ,bulk_bom(i).attribute2
          ,bulk_bom(i).attribute9
          ,bulk_bom(i).attribute11
          ,bulk_bom(i).attribute12
          ,bulk_bom(i).attribute13
          ,bulk_bom(i).purchasing_item_flag
          ,bulk_bom(i).shippable_item_flag
          ,bulk_bom(i).customer_order_flag
          ,bulk_bom(i).internal_order_flag
          ,bulk_bom(i).service_item_flag
          ,bulk_bom(i).inventory_item_flag
          ,bulk_bom(i).inventory_asset_flag
          ,bulk_bom(i).purchasing_enabled_flag
          ,bulk_bom(i).customer_order_enabled_flag
          ,bulk_bom(i).internal_order_enabled_flag
          ,bulk_bom(i).so_transactions_flag
          ,bulk_bom(i).mtl_transactions_enabled_flag
          ,bulk_bom(i).stock_enabled_flag
          ,bulk_bom(i).bom_enabled_flag
          ,bulk_bom(i).build_in_wip_flag
          ,bulk_bom(i).item_catalog_group_id
          ,bulk_bom(i).catalog_status_flag
          ,bulk_bom(i).returnable_flag
          ,bulk_bom(i).organization_id
          ,bulk_bom(i).organization_code
          ,bulk_bom(i).source_organization_id
          ,bulk_bom(i).source_organization_code
          ,bulk_bom(i).collateral_flag
          ,bulk_bom(i).taxable_flag
          ,bulk_bom(i).allow_item_desc_update_flag
          ,bulk_bom(i).inspection_required_flag
          ,bulk_bom(i).receipt_required_flag
          ,bulk_bom(i).qty_rcv_tolerance
          ,bulk_bom(i).list_price_per_unit
          ,bulk_bom(i).asset_category_id
          ,bulk_bom(i).unit_of_issue
          ,bulk_bom(i).allow_substitute_receipts_flag
          ,bulk_bom(i).allow_unordered_receipts_flag
          ,bulk_bom(i).allow_express_delivery_flag
          ,bulk_bom(i).days_early_receipt_allowed
          ,bulk_bom(i).days_late_receipt_allowed
          ,bulk_bom(i).receipt_days_exception_code
          ,bulk_bom(i).receiving_routing_id
          ,bulk_bom(i).auto_lot_alpha_prefix
          ,bulk_bom(i).start_auto_lot_number
          ,bulk_bom(i).lot_control_code
          ,bulk_bom(i).shelf_life_code
          ,bulk_bom(i).shelf_life_days
          ,bulk_bom(i).serial_number_control_code
          ,bulk_bom(i).source_type
          ,bulk_bom(i).source_subinventory
          ,bulk_bom(i).expense_account
          ,bulk_bom(i).legacy_expense_account
          ,bulk_bom(i).expense_acct_segment1
          ,bulk_bom(i).expense_acct_segment2
          ,bulk_bom(i).expense_acct_segment3
          ,bulk_bom(i).expense_acct_segment4
          ,bulk_bom(i).expense_acct_segment5
          ,bulk_bom(i).expense_acct_segment6
          ,bulk_bom(i).expense_acct_segment7
          ,bulk_bom(i).expense_acct_segment8
          ,bulk_bom(i).expense_acct_segment9
          ,bulk_bom(i).expense_acct_segment10
          ,bulk_bom(i).restrict_subinventories_code
          ,bulk_bom(i).unit_weight
          ,bulk_bom(i).weight_uom_code
          ,bulk_bom(i).volume_uom_code
          ,bulk_bom(i).unit_volume
          ,bulk_bom(i).shrinkage_rate
          ,bulk_bom(i).acceptable_early_days
          ,bulk_bom(i).planning_time_fence_code
          ,bulk_bom(i).lead_time_lot_size
          ,bulk_bom(i).std_lot_size
          ,bulk_bom(i).overrun_percentage
          ,bulk_bom(i).mrp_calculate_atp_flag
          ,bulk_bom(i).acceptable_rate_increase
          ,bulk_bom(i).acceptable_rate_decrease
          ,bulk_bom(i).planning_time_fence_days
          ,bulk_bom(i).end_assembly_pegging_flag
          ,bulk_bom(i).bom_item_type
          ,bulk_bom(i).pick_components_flag
          ,bulk_bom(i).replenish_to_order_flag
          ,bulk_bom(i).atp_components_flag
          ,bulk_bom(i).atp_flag
          ,bulk_bom(i).wip_supply_type
          ,bulk_bom(i).wip_supply_subinventory
          ,bulk_bom(i).primary_uom_code
          ,bulk_bom(i).primary_unit_of_measure
          ,bulk_bom(i).allowed_units_lookup_code
          ,bulk_bom(i).cost_of_sales_account
          ,bulk_bom(i).legacy_cost_of_sales_account
          ,bulk_bom(i).cost_of_sales_acct_segment1
          ,bulk_bom(i).cost_of_sales_acct_segment2
          ,bulk_bom(i).cost_of_sales_acct_segment3
          ,bulk_bom(i).cost_of_sales_acct_segment4
          ,bulk_bom(i).cost_of_sales_acct_segment5
          ,bulk_bom(i).cost_of_sales_acct_segment6
          ,bulk_bom(i).cost_of_sales_acct_segment7
          ,bulk_bom(i).cost_of_sales_acct_segment8
          ,bulk_bom(i).cost_of_sales_acct_segment9
          ,bulk_bom(i).cost_of_sales_acct_segment10
          ,bulk_bom(i).sales_account
          ,bulk_bom(i).legacy_sales_account
          ,bulk_bom(i).sales_acct_segment1
          ,bulk_bom(i).sales_acct_segment2
          ,bulk_bom(i).sales_acct_segment3
          ,bulk_bom(i).sales_acct_segment4
          ,bulk_bom(i).sales_acct_segment5
          ,bulk_bom(i).sales_acct_segment6
          ,bulk_bom(i).sales_acct_segment7
          ,bulk_bom(i).sales_acct_segment8
          ,bulk_bom(i).sales_acct_segment9
          ,bulk_bom(i).sales_acct_segment10
          ,bulk_bom(i).default_include_in_rollup_flag
          ,bulk_bom(i).inventory_item_status_code
          ,bulk_bom(i).inventory_planning_code
          ,bulk_bom(i).start_auto_serial_number
          ,bulk_bom(i).auto_serial_alpha_prefix
          ,bulk_bom(i).planner_code
          ,bulk_bom(i).planning_make_buy_code
          ,bulk_bom(i).fixed_lot_multiplier
          ,bulk_bom(i).rounding_control_type
          ,bulk_bom(i).postprocessing_lead_time
          ,bulk_bom(i).preprocessing_lead_time
          ,bulk_bom(i).full_lead_time
          ,bulk_bom(i).mrp_safety_stock_percent
          ,bulk_bom(i).mrp_safety_stock_code
          ,bulk_bom(i).min_minmax_quantity
          ,bulk_bom(i).max_minmax_quantity
          ,bulk_bom(i).minimum_order_quantity
          ,bulk_bom(i).fixed_order_quantity
          ,bulk_bom(i).fixed_days_supply
          ,bulk_bom(i).maximum_order_quantity
          ,bulk_bom(i).atp_rule_name
          ,bulk_bom(i).reservable_type
          ,bulk_bom(i).vendor_warranty_flag
          ,bulk_bom(i).serviceable_product_flag
          ,bulk_bom(i).material_billable_flag
          ,bulk_bom(i).prorate_service_flag
          ,bulk_bom(i).invoiceable_item_flag
          ,bulk_bom(i).invoice_enabled_flag
          ,bulk_bom(i).outside_operation_flag
          ,bulk_bom(i).outside_operation_uom_type
          ,bulk_bom(i).safety_stock_bucket_days
          ,bulk_bom(i).costing_enabled_flag
          ,bulk_bom(i).cycle_count_enabled_flag
          ,bulk_bom(i).item_type
          ,bulk_bom(i).ship_model_complete_flag
          ,bulk_bom(i).mrp_planning_code
          ,bulk_bom(i).ato_forecast_control
          ,bulk_bom(i).release_time_fence_code
          ,bulk_bom(i).release_time_fence_days
          ,bulk_bom(i).container_item_flag
          ,bulk_bom(i).vehicle_item_flag
          ,bulk_bom(i).effectivity_control
          ,bulk_bom(i).event_flag
          ,bulk_bom(i).electronic_flag
          ,bulk_bom(i).downloadable_flag
          ,bulk_bom(i).comms_nl_trackable_flag
          ,bulk_bom(i).orderable_on_web_flag
          ,bulk_bom(i).web_status
          ,bulk_bom(i).dimension_uom_code
          ,bulk_bom(i).unit_length
          ,bulk_bom(i).unit_width
          ,bulk_bom(i).unit_height
          ,bulk_bom(i).dual_uom_control
          ,bulk_bom(i).dual_uom_deviation_high
          ,bulk_bom(i).dual_uom_deviation_low
          ,bulk_bom(i).contract_item_type_code
          ,bulk_bom(i).serv_req_enabled_code
          ,bulk_bom(i).serv_billing_enabled_flag
          ,bulk_bom(i).default_so_source_type
          ,bulk_bom(i).object_version_number
          ,bulk_bom(i).tracking_quantity_ind
          ,bulk_bom(i).secondary_default_ind
          ,bulk_bom(i).so_authorization_flag
          ,bulk_bom(i).attribute17
          ,bulk_bom(i).attribute18
          ,bulk_bom(i).attribute19
          ,bulk_bom(i).attribute25
          ,bulk_bom(i).expiration_action_code
          ,bulk_bom(i).expiration_action_interval
          ,bulk_bom(i).hazardous_material_flag
          ,bulk_bom(i).recipe_enabled_flag
          ,bulk_bom(i).retest_interval
          ,bulk_bom(i).repair_leadtime
          ,bulk_bom(i).gdsn_outbound_enabled_flag
          ,'1'
          , --rec_exp.revision_qty_control_code,
           bulk_bom(i).revision_id
          ,bulk_bom(i).revision
          ,bulk_bom(i).revision_label
          ,bulk_bom(i).revision_description
          ,bulk_bom(i).effectivity_date
          ,bulk_bom(i).implementation_date
          ,bulk_bom(i).ecn_initiation_date
          ,bulk_bom(i).change_notice
          ,bulk_bom(i).r_attribute10
          ,bulk_bom(i).revised_item_sequence_id
          ,bulk_bom(i).LANGUAGE
          ,bulk_bom(i).source_lang
          ,bulk_bom(i).tl_description
          ,bulk_bom(i).creation_date
          ,SYSDATE
          ,'N');
		   
		   EXIT WHEN c_org_bom_exp_items%NOTFOUND;
  END LOOP;
  CLOSE c_org_bom_exp_items;
  COMMIT;
  EXCEPTION 
  WHEN no_data_found THEN
	  log_p('Error: No data found in Bom Insert'||' '||SQLCODE||'-' ||SQLERRM);
  WHEN others THEN
      log_p('Error in bom explode insert'||SQLERRM);
      log_p('Exception in the BOM Bulk Insert'||'-'||SQLERRM);
	    l_Err_Count := SQL%BULK_EXCEPTIONS.COUNT;
      log_p('Number of statements that failed:' || l_Err_Count);
    FOR i IN 1..l_Err_Count
   LOOP
     log_p('Error #'|| i || 'occurred during '||'iteration #' || SQL%BULK_EXCEPTIONS(i).ERROR_INDEX);
     log_p('Error message is ' ||
     SQLERRM(-SQL%BULK_EXCEPTIONS(i).ERROR_CODE));
     END LOOP;
    END; 
      log_p('Loading complete');
         
         
	  --Beging for calling the DQ procedure for Quality Check 
      BEGIN
        quality_check_master_items;
        log_p('after quality check');
      END; 
      log_p('DQ complete');
    
	-- Transformation of the Attributes 
	BEGIN
      FOR k IN c_transform LOOP
            l_step := 'Update inventory org';
			
		  -- Org code transformation 
              
        xxs3_data_transform_util_pkg.transform(p_mapping_type          => 'inventory_org',				             --Mapping type 
                                                p_stage_tab             => 'xxobjt.xxs3_ptm_mtl_master_items', -- Staging Table Name 
                                                p_stage_primary_col     => 'xx_inventory_item_id',             -- Staging Table Primary Column Name 
                                                p_stage_primary_col_val => k.xx_inventory_item_id,             -- Staging Table Primary Column Value 
                                                p_legacy_val            => k.legacy_organization_code,         -- Legacy Value 
                                                p_stage_col             => 's3_organization_code',             -- Staging Table Name 
                                                p_err_code              => l_err_code,                         -- Output error code  
                                                p_err_msg               => l_err_msg);                         -- Error Message 
       
      
	  -- Source Organization code transformation 
	  l_step := 'Update source inventory org';
	  
        xxs3_data_transform_util_pkg.transform(p_mapping_type          => 'inventory_org',					             -- Mapping type 
                                                p_stage_tab             => 'xxobjt.xxs3_ptm_mtl_master_items',  -- Staging Table Name 
                                                p_stage_primary_col     => 'xx_inventory_item_id',             -- Staging Table Primary Column Name 
                                                p_stage_primary_col_val => k.xx_inventory_item_id,            -- Staging Table Primary Column Value 
                                                p_legacy_val            => k.l_source_organization_code,	   -- Legacy Value 
                                                p_stage_col             => 's3_source_organization_code', 	-- Staging Table Name 
                                                p_err_code              => l_err_code, 					           -- Output error code  
                                                p_err_msg               => l_err_msg);  				          -- Error Message 
       
      
       
       
       -- Item Type Transformation to S3 
         l_step := 'Update item_type';	   
        xxs3_data_transform_util_pkg.transform(p_mapping_type          => 'ptm_item_type',				               -- Mapping type 
                                                p_stage_tab             => 'xxobjt.xxs3_ptm_mtl_master_items',  -- Staging Table Name 
                                                p_stage_primary_col     => 'xx_inventory_item_id',		      	 --  Staging Table Primary Column Name 
                                                p_stage_primary_col_val => k.xx_inventory_item_id, 		        -- Staging Table Primary Column Value 
                                                p_legacy_val            => k.item_type, 					           -- Legacy Value 
                                                p_stage_col             => 's3_item_type', 				          -- Staging Table Name 
                                                p_err_code              => l_err_code,                     -- Output error code  
                                                p_err_msg               => l_err_msg); 				            -- Error Message 
       
	    --Item Status Code Transforamtion to S3 
        l_step := 'Update inventory_item_status_code';
        xxs3_data_transform_util_pkg.transform(p_mapping_type          => 'ptm_item_status_code',			            -- Mapping type 
                                                p_stage_tab             => 'xxobjt.xxs3_ptm_mtl_master_items',   --  Staging Table Name 
                                                p_stage_primary_col     => 'xx_inventory_item_id',              -- Staging Table Primary Column Name 
                                                p_stage_primary_col_val => k.xx_inventory_item_id, 			       -- Staging Table Primary Column Value 
                                                p_legacy_val            => k.inventory_item_status_code, 	    -- Legacy Value 
                                                p_stage_col             => 's3_inventory_item_status_code',  -- Staging Table Name 
                                                p_err_code              => l_err_code,    	                -- Output error code  
                                                p_err_msg               => l_err_msg);					           -- Error Message 
       
        
        --Primary UOM Code Transforamtion to S3 
	   l_step := 'Update primary_uom_code';
        xxs3_data_transform_util_pkg.transform(p_mapping_type          => 'ptm_puom',							                  -- Mapping type 
                                                p_stage_tab             => 'xxobjt.xxs3_ptm_mtl_master_items',     -- Staging Table Name 
                                                p_stage_primary_col     => 'xx_inventory_item_id',                -- Staging Table Primary Column Name 
                                                p_stage_primary_col_val => k.xx_inventory_item_id,               -- Staging Table Primary Column Value 
                                                p_legacy_val            => k.primary_uom_code,      	          -- Legacy Value 
                                                p_stage_col             => 's3_secondary_uom_code',            -- Staging Table Name 
                                                p_err_code              => l_err_code, 					              -- Output error code  
                                                p_err_msg               => l_err_msg);                       -- Error Message 
       
       --Accounting Rule Name Transformation to S3 
	   l_step := 'Update Accounting_rule_name';
        xxs3_data_transform_util_pkg.transform(p_mapping_type          => 'ptm_account_rule_name',                 -- Mapping type 
                                                p_stage_tab             => 'xxobjt.xxs3_ptm_mtl_master_items',    -- Staging Table Name 
                                                p_stage_primary_col     => 'xx_inventory_item_id',               -- Staging Table Primary Column Name 
                                                p_stage_primary_col_val => k.xx_inventory_item_id,  			      -- Staging Table Primary Column Value 
                                                p_legacy_val            => k.legacy_accounting_rule_name, 		 -- Legacy Value 
                                                p_stage_col             => 's3_accounting_rule_name',		      -- Staging Table Name 
                                                p_err_code              => l_err_code, 						           -- Output error code  
                                                p_err_msg               => l_err_msg);						          -- Error Message 	
      
        
      
      END LOOP;
	  COMMIT;
   -- Accounting Transforamtion 
	 	
		 
      FOR k IN c_transform LOOP
      
	 	  
      -- Expense Account segments Transformation to S3 segments 
	   l_s3_gl_string := null;
	   
	  IF k.expense_account IS NOT NULL THEN
	  l_step := 'Update expense_account';
          xxs3_data_transform_util_pkg.coa_item_master_transform(p_field_name              => 'EXPENSE_ACCOUNT',                    -- Field Name 
                                                                  p_s3_org_code             => k.s3_organization_code,              -- s3 org code 
                                                                  p_legacy_company_val      => k.legacy_expense_acct_segment1,      -- legacy company value 
                                                                  p_legacy_department_val   => k.legacy_expense_acct_segment2,      -- legacy department value 
                                                                  p_legacy_account_val      => k.legacy_expense_acct_segment3,      -- legacy account value 
                                                                  p_legacy_product_val      => k.legacy_expense_acct_segment5,      -- legacy product value 
                                                                  p_legacy_location_val     => k.legacy_expense_acct_segment6,      -- legacy location value 
                                                                  p_legacy_intercompany_val => k.legacy_expense_acct_segment7,      -- legacy intercompany value 
                                                                  p_legacy_division_val     => k.legacy_expense_acct_segment10,     -- legacy division value 
                                                                  p_item_number             => k.segment1,					              	-- Item Number 
                                                                  p_s3_gl_string            => l_s3_gl_string,  
                                                                  p_err_code                => l_output_code,                       -- Error Code 
                                                                  p_err_msg                 => l_output);                           -- Output Message  
        
          xxs3_data_transform_util_pkg.coa_update(p_gl_string               => l_s3_gl_string,
                                                   p_stage_tab               => 'xxs3_ptm_mtl_master_items',     -- Staging Table Name 
                                                   p_stage_primary_col       => 'xx_inventory_item_id',				   -- Staging Table Primary Column Name 
                                                   p_stage_primary_col_val   => k.xx_inventory_item_id,				   -- Staging Table Primary Column Value 
                                                   p_stage_company_col       => 's3_expense_acct_segment1',      -- S3 Company Value 			
                                                   p_stage_business_unit_col => 's3_expense_acct_segment2',		   -- S3 Busineess Unit Value 	 
                                                   p_stage_department_col    => 's3_expense_acct_segment3',      -- S3 Department Value 
                                                   p_stage_account_col       => 's3_expense_acct_segment4',      -- S3 Account Value  
                                                   p_stage_product_line_col  => 's3_expense_acct_segment5',      -- S3 Product Line Value   
                                                   p_stage_location_col      => 's3_expense_acct_segment6',      -- S3 Location Value 
                                                   p_stage_intercompany_col  => 's3_expense_acct_segment7',      -- S3 InterCompany Value 
                                                   p_stage_future_col        => 's3_expense_acct_segment8',      -- S3 Featuere Value 
                                                   p_coa_err_msg             => l_output,
                                                   p_err_code                => l_output_code_coa_update,        -- Error Code 
                                                   p_err_msg                 => l_output_coa_update);            -- Error Message 
        END IF;
      
        l_s3_gl_string := null;
		
       --Cost Of Sales Account segments Transformation to S3 segments 
	  
        IF k.cost_of_sales_account IS NOT NULL THEN
		 l_step := 'Update cost_of_sales_account';
          xxs3_data_transform_util_pkg.coa_item_master_transform(p_field_name              => 'COST_OF_SALES_ACCOUNT',          -- Field Name 
                                                                  p_s3_org_code             => k.s3_organization_code,		      -- s3 org code 
                                                                  p_legacy_company_val      => k.l_cost_of_sales_acct_segment1, -- legacy company value 
                                                                  p_legacy_department_val   => k.l_cost_of_sales_acct_segment2, -- legacy department value 
                                                                  p_legacy_account_val      => k.l_cost_of_sales_acct_segment3, -- legacy account value 
                                                                  p_legacy_product_val      => k.l_cost_of_sales_acct_segment5, -- legacy product value 
                                                                  p_legacy_location_val     => k.l_cost_of_sales_acct_segment6, -- legacy location value 
                                                                  p_legacy_intercompany_val => k.l_cost_of_sales_acct_segment7, -- legacy intercompany value
                                                                  p_legacy_division_val     => k.l_cost_of_sales_acct_segment10,-- Legacy Division Value 
                                                                  p_item_number             => k.segment1,					          	-- Item Number 
                                                                  p_s3_gl_string            => l_s3_gl_string,
                                                                  p_err_code                => l_output_code,                   --  Error Code 
                                                                  p_err_msg                 => l_output);                       -- Output Message 
        
          xxs3_data_transform_util_pkg.coa_update(p_gl_string               => l_s3_gl_string,
                                                   p_stage_tab               => 'xxs3_ptm_mtl_master_items',		     	--Staging Table Name 
                                                   p_stage_primary_col       => 'xx_inventory_item_id',               --Staging Table Primary Column Name 
                                                   p_stage_primary_col_val   => k.xx_inventory_item_id,               --Staging Table Primary Column Value 
                                                   p_stage_company_col       => 's3_cost_sales_acct_segment1',        --S3 Company Value 			
                                                   p_stage_business_unit_col => 's3_cost_sales_acct_segment2',        --S3 Busineess Unit Value 	 
                                                   p_stage_department_col    => 's3_cost_sales_acct_segment3',        --S3 Department Value 
                                                   p_stage_account_col       => 's3_cost_sales_acct_segment4',        --S3 Account Value  
                                                   p_stage_product_line_col  => 's3_cost_sales_acct_segment5',	      --S3 Product Line Value  
                                                   p_stage_location_col      => 's3_cost_sales_acct_segment6',        --S3 Location Value 
                                                   p_stage_intercompany_col  => 's3_cost_sales_acct_segment7',        --S3 InterCompany Value 
                                                   p_stage_future_col        => 's3_cost_sales_acct_segment8',        --S3 Featuere Value 
                                                   p_coa_err_msg             => l_output,
                                                   p_err_code                => l_output_code_coa_update,             --Error Code 
                                                   p_err_msg                 => l_output_coa_update);                 --Error Message 
        
        END IF;
      
        l_s3_gl_string := null;
      
	    --Sales Account segments Transformation to S3 segments 
	   
        IF k.sales_account IS NOT NULL THEN
		 l_step := 'Update sales_account';
          xxs3_data_transform_util_pkg.coa_item_master_transform(p_field_name              => 'SALES_ACCOUNT',               --Field Name 
                                                                  p_s3_org_code             => k.s3_organization_code,       --s3 org code 
                                                                  p_legacy_company_val      => k.legacy_sales_acct_segment1, --legacy company value 
                                                                  p_legacy_department_val   => k.legacy_sales_acct_segment2, --legacy department value
                                                                  p_legacy_account_val      => k.legacy_sales_acct_segment3, --legacy account value 
                                                                  p_legacy_product_val      => k.legacy_sales_acct_segment5, --legacy product value 
                                                                  p_legacy_location_val     => k.legacy_sales_acct_segment6, --legacy location value 
                                                                  p_legacy_intercompany_val => k.legacy_sales_acct_segment7, --legacy intercompany value 
                                                                  p_legacy_division_val     => k.legacy_sales_acct_segment10,--legacy division value 
                                                                  p_item_number             => k.segment1,					         --item number 	
                                                                  p_s3_gl_string            => l_s3_gl_string,
                                                                  p_err_code                => l_output_code,                --Error Code  
                                                                  p_err_msg                 => l_output);                    --Output Message 
        
          xxs3_data_transform_util_pkg.coa_update(p_gl_string               => l_s3_gl_string,
                                                   p_stage_tab               => 'xxs3_ptm_mtl_master_items',       		-- Staging Table Name  			
                                                   p_stage_primary_col       => 'xx_inventory_item_id',               -- Staging Table Primary Column Name 
                                                   p_stage_primary_col_val   => k.xx_inventory_item_id,               -- Staging Table Primary Column Value 
                                                   p_stage_company_col       => 's3_sales_acct_segment1',             -- S3 Company Value 			
                                                   p_stage_business_unit_col => 's3_sales_acct_segment2',             -- S3 Busineess Unit Value 	 
                                                   p_stage_department_col    => 's3_sales_acct_segment3',             -- S3 Department Value 
                                                   p_stage_account_col       => 's3_sales_acct_segment4',             -- S3 Account Value  
                                                   p_stage_product_line_col  => 's3_sales_acct_segment5',             -- S3 Product Line Value  
                                                   p_stage_location_col      => 's3_sales_acct_segment6',             -- S3 Location Value 
                                                   p_stage_intercompany_col  => 's3_sales_acct_segment7',             -- S3 InterCompany Value 
                                                   p_stage_future_col        => 's3_sales_acct_segment8',             -- S3 Featuere Value 
                                                   p_coa_err_msg             => l_output,
                                                   p_err_code                => l_output_code_coa_update,             -- Error Code 
                                                   p_err_msg                 => l_output_coa_update);                 -- Error Message 
        END IF;
      
      END LOOP;
      log_p('After Account Trnasformation');
      COMMIT;
	--Get Legacy Buyer Id based on the ORG's Conditions 
	
      FOR buy_cur IN c_transform LOOP
        IF buy_cur.legacy_buyer_id IS NULL THEN
		
          update_buyer_id(buy_cur.l_inventory_item_id,
                          buy_cur.legacy_organization_code);
        
        END IF;
       END LOOP;
       COMMIT;
       
      FOR up_cur IN c_transform LOOP
        
		   -- Update S3 attribute25 Value 
		 
		     log_p('Attribute 25 Trnasformation' || up_cur.attribute25);
		 
         update_attribute25(up_cur.xx_inventory_item_id, up_cur.attribute25);-- Update attribute25 procedure Call 
           
       --Update S3 Buyer Number from Legacy Buyer Id Value    
         
        log_p('Buyer Number Trnasformation' || up_cur.legacy_buyer_id);
              
        update_buyer_number(up_cur.xx_inventory_item_id,up_cur.legacy_buyer_id,up_cur.transform_error);-- Update Buyer Number procedure Call 
      
       -- Update S3 Atp Rule Name Value 
	   
        log_p('Atp Rule Name Trnasformation'||up_cur.atp_rule_name);
		
        update_atp_rule_name(up_cur.xx_inventory_item_id,up_cur.atp_rule_name); -- Update Atp Rule Name procedure Call 
		
       --S3 Planner Code Value update 
	     		
	   	log_p('Planner Code Trnasformation'||up_cur.planner_code);
		
       update_planner(up_cur.l_inventory_item_id,up_cur.legacy_organization_code,up_cur.planner_code); -- Planner Code procedure Call 
          
    
         --Update S3 Tracking Quantity Ind Value 
		    log_p('Tracking Quantity Ind Trnasformation'||up_cur.primary_uom_code);
		
        update_tracking_quantity_ind(up_cur.xx_inventory_item_id,up_cur.primary_uom_code,up_cur.transform_error);  --Tracking Quantity Ind Procedure Call 
             
      END LOOP;
      COMMIT;
  
	 
	  --Update S3 Secondary Default Ind Value 
	 FOR rec_sdi IN c_transform LOOP
	 log_p('Secondary Default Ind Value Transformation'||rec_sdi.primary_uom_code);
     update_secondary_default_ind(rec_sdi.xx_inventory_item_id,
                                     rec_sdi.primary_uom_code,
                                     rec_sdi.transform_error);  -- Update Secondary Default Ind Procedure Call 
     END LOOP;
     COMMIT;
	
	 --Update S3 Ont Pricing Qty Source Value 
     FOR rec_ont IN c_transform LOOP
	 log_p('Ont Pricing Qty Source Value Transformation'||rec_ont.s3_tracking_quantity_ind);
    
	 update_ont_pricing_qty_source(rec_ont.xx_inventory_item_id,
                                      rec_ont.s3_tracking_quantity_ind,
                                      rec_ont.transform_error);  -- Update Ont Pricing Qty Source Procedure Call 
      
      END LOOP;
      COMMIT;
	 EXCEPTION
   WHEN no_data_found THEN
	  log_p('Error: No data found in transformation section'||' '||SQLCODE||'-' ||SQLERRM);
    
      WHEN others THEN
        log_p('Unexpected error during transformation at step : ' ||
                     l_step ||chr(10) || SQLCODE || chr(10) || SQLERRM);
  END;	
		BEGIN  
		cleanse_master_items; -- Calling Cleanse Procedure 
		END;   
-- Insert S01,S02,S03 Org's 

IF p_organization_code = 'UME' THEN
 BEGIN
	  OPEN c_ume_s01;
	  LOOP
      FETCH c_ume_s01 BULK COLLECT INTO bulk_s01 LIMIT 10000;
	    FORALL i IN 1..bulk_s01.COUNT           
        INSERT INTO xxobjt.xxs3_ptm_mtl_master_items
          (xx_inventory_item_id
          ,l_inventory_item_id
          ,s3_inventory_item_id
          ,description
          ,legacy_buyer_id
          ,s3_buyer_number
          ,legacy_accounting_rule_name
          ,s3_accounting_rule_name
          ,created_by
          ,creation_date
          ,segment1
          ,attribute2
          ,attribute9
          ,attribute11
          ,attribute12
          ,attribute13
          ,purchasing_item_flag
          ,shippable_item_flag
          ,customer_order_flag
          ,internal_order_flag
          ,service_item_flag
          ,inventory_item_flag
          ,inventory_asset_flag
          ,purchasing_enabled_flag
          ,customer_order_enabled_flag
          ,internal_order_enabled_flag
          ,so_transactions_flag
          ,mtl_transactions_enabled_flag
          ,stock_enabled_flag
          ,bom_enabled_flag
          ,build_in_wip_flag
          ,item_catalog_group_id
          ,catalog_status_flag
          ,returnable_flag
          ,legacy_organization_id
          ,legacy_organization_code
          ,s3_organization_code
          ,legacy_source_organization_id
          ,l_source_organization_code
          ,s3_source_organization_code
          ,collateral_flag
          ,taxable_flag
          ,allow_item_desc_update_flag
          ,inspection_required_flag
          ,receipt_required_flag
          ,qty_rcv_tolerance
          ,list_price_per_unit
          ,asset_category_id
          ,unit_of_issue
          ,allow_substitute_receipts_flag
          ,allow_unordered_receipts_flag
          ,allow_express_delivery_flag
          ,days_early_receipt_allowed
          ,days_late_receipt_allowed
          ,receipt_days_exception_code
          ,receiving_routing_id
          ,auto_lot_alpha_prefix
          ,start_auto_lot_number
          ,lot_control_code
          ,shelf_life_code
          ,shelf_life_days
          ,serial_number_control_code
          ,source_type
          ,source_subinventory
          ,expense_account
          ,legacy_expense_account
          ,legacy_expense_acct_segment1
          ,legacy_expense_acct_segment2
          ,legacy_expense_acct_segment3
          ,legacy_expense_acct_segment4
          ,legacy_expense_acct_segment5
          ,legacy_expense_acct_segment6
          ,legacy_expense_acct_segment7
          ,legacy_expense_acct_segment8
          ,legacy_expense_acct_segment9
          ,legacy_expense_acct_segment10
          ,s3_expense_acct_segment1
          ,s3_expense_acct_segment2
          ,s3_expense_acct_segment3
          ,s3_expense_acct_segment4
          ,s3_expense_acct_segment5
          ,s3_expense_acct_segment6
          ,s3_expense_acct_segment7
          ,s3_expense_acct_segment8
          ,restrict_subinventories_code
          ,unit_weight
          ,weight_uom_code
          ,volume_uom_code
          ,unit_volume
          ,shrinkage_rate
          ,acceptable_early_days
          ,planning_time_fence_code
          ,lead_time_lot_size
          ,std_lot_size
          ,overrun_percentage
          ,mrp_calculate_atp_flag
          ,acceptable_rate_increase
          ,acceptable_rate_decrease
          ,planning_time_fence_days
          ,end_assembly_pegging_flag
          ,bom_item_type
          ,pick_components_flag
          ,replenish_to_order_flag
          ,atp_components_flag
          ,atp_flag
          ,wip_supply_type
         -- ,wip_supply_subinventory
         -- ,s3_wip_supply_subinventory
          ,primary_uom_code
          ,secondary_uom_code
          ,s3_secondary_uom_code
          ,primary_unit_of_measure
          ,allowed_units_lookup_code
          ,cost_of_sales_account
          ,l_cost_of_sales_account
          ,l_cost_of_sales_acct_segment1
          ,l_cost_of_sales_acct_segment2
          ,l_cost_of_sales_acct_segment3
          ,l_cost_of_sales_acct_segment4
          ,l_cost_of_sales_acct_segment5
          ,l_cost_of_sales_acct_segment6
          ,l_cost_of_sales_acct_segment7
          ,l_cost_of_sales_acct_segment8
          ,l_cost_of_sales_acct_segment9
          ,l_cost_of_sales_acct_segment10
          ,s3_cost_sales_acct_segment1
          ,s3_cost_sales_acct_segment2
          ,s3_cost_sales_acct_segment3
          ,s3_cost_sales_acct_segment4
          ,s3_cost_sales_acct_segment5
          ,s3_cost_sales_acct_segment6
          ,s3_cost_sales_acct_segment7
          ,s3_cost_sales_acct_segment8
          ,s3_cost_sales_acct_segment9
          ,s3_cost_sales_acct_segment10
          ,sales_account
          ,legacy_sales_account
          ,legacy_sales_acct_segment1
          ,legacy_sales_acct_segment2
          ,legacy_sales_acct_segment3
          ,legacy_sales_acct_segment4
          ,legacy_sales_acct_segment5
          ,legacy_sales_acct_segment6
          ,legacy_sales_acct_segment7
          ,legacy_sales_acct_segment8
          ,legacy_sales_acct_segment9
          ,legacy_sales_acct_segment10
          ,s3_sales_acct_segment1
          ,s3_sales_acct_segment2
          ,s3_sales_acct_segment3
          ,s3_sales_acct_segment4
          ,s3_sales_acct_segment5
          ,s3_sales_acct_segment6
          ,s3_sales_acct_segment7
          ,s3_sales_acct_segment8
          ,s3_sales_acct_segment9
          ,s3_sales_acct_segment10
          ,default_include_in_rollup_flag
          ,inventory_item_status_code
          ,s3_inventory_item_status_code
          ,inventory_planning_code
          ,start_auto_serial_number
          ,auto_serial_alpha_prefix
          ,planner_code
          ,s3_planner_code
          ,planning_make_buy_code
          ,fixed_lot_multiplier
          ,rounding_control_type
          ,postprocessing_lead_time
          ,preprocessing_lead_time
          ,full_lead_time
          ,mrp_safety_stock_percent
          ,mrp_safety_stock_code
          ,min_minmax_quantity
          ,max_minmax_quantity
          ,minimum_order_quantity
          ,fixed_order_quantity
          ,fixed_days_supply
          ,maximum_order_quantity
          ,atp_rule_name
          ,s3_atp_rule_name
          ,reservable_type
          ,vendor_warranty_flag
          ,serviceable_product_flag
          ,material_billable_flag
          ,prorate_service_flag
          ,invoiceable_item_flag
          ,invoice_enabled_flag
          ,outside_operation_flag
          ,outside_operation_uom_type
          ,safety_stock_bucket_days
          ,costing_enabled_flag
          ,cycle_count_enabled_flag
          ,item_type
          ,s3_item_type
          ,ship_model_complete_flag
          ,mrp_planning_code
          ,ato_forecast_control
          ,release_time_fence_code
          ,release_time_fence_days
          ,container_item_flag
          ,vehicle_item_flag
          ,effectivity_control
          ,event_flag
          ,electronic_flag
          ,downloadable_flag
          ,comms_nl_trackable_flag
          ,orderable_on_web_flag
          ,web_status
          ,dimension_uom_code
          ,unit_length
          ,unit_width
          ,unit_height
          ,dual_uom_control
          ,dual_uom_deviation_high
          ,dual_uom_deviation_low
          ,contract_item_type_code
          ,serv_req_enabled_code
          ,serv_billing_enabled_flag
          ,default_so_source_type
          ,object_version_number
          ,tracking_quantity_ind
          ,s3_tracking_quantity_ind
          ,secondary_default_ind
          ,s3_secondary_default_ind
          ,so_authorization_flag
          ,attribute17
          ,attribute18
          ,attribute19
          ,attribute25
          ,s3_attribute25
          ,expiration_action_code
          ,s3_expiration_action_code
          ,expiration_action_interval
          ,s3_expiration_action_interval
          ,hazardous_material_flag
          ,recipe_enabled_flag
          ,retest_interval
          ,repair_leadtime
          ,gdsn_outbound_enabled_flag
          ,revision_qty_control_code
          ,legacy_revision_id
          ,xxs3_revision_id
          ,revision
          ,revision_label
          ,revision_description
          ,effectivity_date
          ,implementation_date
          ,ecn_initiation_date
          ,change_notice
          ,revision_attribute10
          ,revised_item_sequence_id
          ,s3_revised_item_sequence_id
          ,revision_language
          ,source_lang
          ,revision_tl_description
          ,last_update_date
          ,last_updated_by
          ,orig_system_reference
          ,date_extracted_on
          ,process_flag
          ,transform_status
          ,transform_error
          ,cleanse_status
          ,cleanse_error)
        VALUES
          (xxobjt.xxs3_ptm_mtl_master_items_seq.NEXTVAL
          ,bulk_s01(i).l_inventory_item_id
          ,bulk_s01(i).s3_inventory_item_id
          ,bulk_s01(i).description
          ,bulk_s01(i).legacy_buyer_id
          ,bulk_s01(i).s3_buyer_number
          ,bulk_s01(i).legacy_accounting_rule_name
          ,bulk_s01(i).s3_accounting_rule_name
          ,bulk_s01(i).created_by
          ,bulk_s01(i).creation_date
          ,bulk_s01(i).segment1
          ,bulk_s01(i).attribute2
          ,bulk_s01(i).attribute9
          ,bulk_s01(i).attribute11
          ,bulk_s01(i).attribute12
          ,bulk_s01(i).attribute13
          ,bulk_s01(i).purchasing_item_flag
          ,bulk_s01(i).shippable_item_flag
          ,bulk_s01(i).customer_order_flag
          ,bulk_s01(i).internal_order_flag
          ,bulk_s01(i).service_item_flag
          ,bulk_s01(i).inventory_item_flag
          ,bulk_s01(i).inventory_asset_flag
          ,bulk_s01(i).purchasing_enabled_flag
          ,bulk_s01(i).customer_order_enabled_flag
          ,bulk_s01(i).internal_order_enabled_flag
          ,bulk_s01(i).so_transactions_flag
          ,bulk_s01(i).mtl_transactions_enabled_flag
          ,bulk_s01(i).stock_enabled_flag
          ,bulk_s01(i).bom_enabled_flag
          ,bulk_s01(i).build_in_wip_flag
          ,bulk_s01(i).item_catalog_group_id
          ,bulk_s01(i).catalog_status_flag
          ,bulk_s01(i).returnable_flag
          ,bulk_s01(i).legacy_organization_id
          ,bulk_s01(i).legacy_organization_code
          ,bulk_s01(i) . s3_organization_code
          ,bulk_s01(i).legacy_source_organization_id
          ,bulk_s01(i).l_source_organization_code
          ,bulk_s01(i).s3_source_organization_code
          ,bulk_s01(i).collateral_flag
          ,bulk_s01(i).taxable_flag
          ,bulk_s01(i).allow_item_desc_update_flag
          ,bulk_s01(i).inspection_required_flag
          ,bulk_s01(i).receipt_required_flag
          ,bulk_s01(i).qty_rcv_tolerance
          ,bulk_s01(i).list_price_per_unit
          ,bulk_s01(i).asset_category_id
          ,bulk_s01(i).unit_of_issue
          ,bulk_s01(i).allow_substitute_receipts_flag
          ,bulk_s01(i).allow_unordered_receipts_flag
          ,bulk_s01(i).allow_express_delivery_flag
          ,bulk_s01(i).days_early_receipt_allowed
          ,bulk_s01(i).days_late_receipt_allowed
          ,bulk_s01(i).receipt_days_exception_code
          ,bulk_s01(i).receiving_routing_id
          ,bulk_s01(i).auto_lot_alpha_prefix
          ,bulk_s01(i).start_auto_lot_number
          ,bulk_s01(i).lot_control_code
          ,bulk_s01(i).shelf_life_code
          ,bulk_s01(i).shelf_life_days
          ,bulk_s01(i).serial_number_control_code
          ,bulk_s01(i).source_type
          ,bulk_s01(i).source_subinventory
          ,bulk_s01(i).expense_account
          ,bulk_s01(i).legacy_expense_account
          ,bulk_s01(i).legacy_expense_acct_segment1
          ,bulk_s01(i).legacy_expense_acct_segment2
          ,bulk_s01(i).legacy_expense_acct_segment3
          ,bulk_s01(i).legacy_expense_acct_segment4
          ,bulk_s01(i).legacy_expense_acct_segment5
          ,bulk_s01(i).legacy_expense_acct_segment6
          ,bulk_s01(i).legacy_expense_acct_segment7
          ,bulk_s01(i).legacy_expense_acct_segment8
          ,bulk_s01(i).legacy_expense_acct_segment9
          ,bulk_s01(i).legacy_expense_acct_segment10
          ,bulk_s01(i).s3_expense_acct_segment1
          ,bulk_s01(i).s3_expense_acct_segment2
          ,bulk_s01(i).s3_expense_acct_segment3
          ,bulk_s01(i).s3_expense_acct_segment4
          ,bulk_s01(i).s3_expense_acct_segment5
          ,bulk_s01(i).s3_expense_acct_segment6
          ,bulk_s01(i).s3_expense_acct_segment7
          ,bulk_s01(i).s3_expense_acct_segment8
          ,bulk_s01(i).restrict_subinventories_code
          ,bulk_s01(i).unit_weight
          ,bulk_s01(i).weight_uom_code
          ,bulk_s01(i).volume_uom_code
          ,bulk_s01(i).unit_volume
          ,bulk_s01(i).shrinkage_rate
          ,bulk_s01(i).acceptable_early_days
          ,bulk_s01(i).planning_time_fence_code
          ,bulk_s01(i).lead_time_lot_size
          ,bulk_s01(i).std_lot_size
          ,bulk_s01(i).overrun_percentage
          ,bulk_s01(i).mrp_calculate_atp_flag
          ,bulk_s01(i).acceptable_rate_increase
          ,bulk_s01(i).acceptable_rate_decrease
          ,bulk_s01(i).planning_time_fence_days
          ,bulk_s01(i).end_assembly_pegging_flag
          ,bulk_s01(i).bom_item_type
          ,bulk_s01(i).pick_components_flag
          ,bulk_s01(i).replenish_to_order_flag
          ,bulk_s01(i).atp_components_flag
          ,bulk_s01(i).atp_flag
          ,bulk_s01(i).wip_supply_type
         -- ,bulk_s01(i).wip_supply_subinventory
          --,bulk_s01(i).s3_wip_supply_subinventory
          ,bulk_s01(i).primary_uom_code
          ,bulk_s01(i).secondary_uom_code
          ,bulk_s01(i).s3_secondary_uom_code
          ,bulk_s01(i).primary_unit_of_measure
          ,bulk_s01(i).allowed_units_lookup_code
          ,bulk_s01(i).cost_of_sales_account
          ,bulk_s01(i).l_cost_of_sales_account
          ,bulk_s01(i).l_cost_of_sales_acct_segment1
          ,bulk_s01(i).l_cost_of_sales_acct_segment2
          ,bulk_s01(i).l_cost_of_sales_acct_segment3
          ,bulk_s01(i).l_cost_of_sales_acct_segment4
          ,bulk_s01(i).l_cost_of_sales_acct_segment5
          ,bulk_s01(i).l_cost_of_sales_acct_segment6
          ,bulk_s01(i).l_cost_of_sales_acct_segment7
          ,bulk_s01(i).l_cost_of_sales_acct_segment8
          ,bulk_s01(i).l_cost_of_sales_acct_segment9
          ,bulk_s01(i).l_cost_of_sales_acct_segment10
          ,bulk_s01(i).s3_cost_sales_acct_segment1
          ,bulk_s01(i).s3_cost_sales_acct_segment2
          ,bulk_s01(i).s3_cost_sales_acct_segment3
          ,bulk_s01(i).s3_cost_sales_acct_segment4
          ,bulk_s01(i).s3_cost_sales_acct_segment5
          ,bulk_s01(i).s3_cost_sales_acct_segment6
          ,bulk_s01(i).s3_cost_sales_acct_segment7
          ,bulk_s01(i).s3_cost_sales_acct_segment8
          ,bulk_s01(i).s3_cost_sales_acct_segment9
          ,bulk_s01(i).s3_cost_sales_acct_segment10
          ,bulk_s01(i).sales_account
          ,bulk_s01(i).legacy_sales_account
          ,bulk_s01(i).legacy_sales_acct_segment1
          ,bulk_s01(i).legacy_sales_acct_segment2
          ,bulk_s01(i).legacy_sales_acct_segment3
          ,bulk_s01(i).legacy_sales_acct_segment4
          ,bulk_s01(i).legacy_sales_acct_segment5
          ,bulk_s01(i).legacy_sales_acct_segment6
          ,bulk_s01(i).legacy_sales_acct_segment7
          ,bulk_s01(i).legacy_sales_acct_segment8
          ,bulk_s01(i).legacy_sales_acct_segment9
          ,bulk_s01(i).legacy_sales_acct_segment10
          ,bulk_s01(i).s3_sales_acct_segment1
          ,bulk_s01(i).s3_sales_acct_segment2
          ,bulk_s01(i).s3_sales_acct_segment3
          ,bulk_s01(i).s3_sales_acct_segment4
          ,bulk_s01(i).s3_sales_acct_segment5
          ,bulk_s01(i).s3_sales_acct_segment6
          ,bulk_s01(i).s3_sales_acct_segment7
          ,bulk_s01(i).s3_sales_acct_segment8
          ,bulk_s01(i).s3_sales_acct_segment9
          ,bulk_s01(i).s3_sales_acct_segment10
          ,bulk_s01(i).default_include_in_rollup_flag
          ,bulk_s01(i).inventory_item_status_code
          ,bulk_s01(i).s3_inventory_item_status_code
          ,bulk_s01(i).inventory_planning_code
          ,bulk_s01(i).start_auto_serial_number
          ,bulk_s01(i).auto_serial_alpha_prefix
          ,bulk_s01(i).planner_code
          ,bulk_s01(i).s3_planner_code
          ,bulk_s01(i).planning_make_buy_code
          ,bulk_s01(i).fixed_lot_multiplier
          ,bulk_s01(i).rounding_control_type
          ,bulk_s01(i).postprocessing_lead_time
          ,bulk_s01(i).preprocessing_lead_time
          ,bulk_s01(i).full_lead_time
          ,bulk_s01(i).mrp_safety_stock_percent
          ,bulk_s01(i).mrp_safety_stock_code
          ,bulk_s01(i).min_minmax_quantity
          ,bulk_s01(i).max_minmax_quantity
          ,bulk_s01(i).minimum_order_quantity
          ,bulk_s01(i).fixed_order_quantity
          ,bulk_s01(i).fixed_days_supply
          ,bulk_s01(i).maximum_order_quantity
          ,bulk_s01(i).atp_rule_name
          ,bulk_s01(i).s3_atp_rule_name
          ,bulk_s01(i).reservable_type
          ,bulk_s01(i).vendor_warranty_flag
          ,bulk_s01(i).serviceable_product_flag
          ,bulk_s01(i).material_billable_flag
          ,bulk_s01(i).prorate_service_flag
          ,bulk_s01(i).invoiceable_item_flag
          ,bulk_s01(i).invoice_enabled_flag
          ,bulk_s01(i).outside_operation_flag
          ,bulk_s01(i).outside_operation_uom_type
          ,bulk_s01(i).safety_stock_bucket_days
          ,bulk_s01(i).costing_enabled_flag
          ,bulk_s01(i).cycle_count_enabled_flag
          ,bulk_s01(i).item_type
          ,bulk_s01(i).s3_item_type
          ,bulk_s01(i).ship_model_complete_flag
          ,bulk_s01(i).mrp_planning_code
          ,bulk_s01(i).ato_forecast_control
          ,bulk_s01(i).release_time_fence_code
          ,bulk_s01(i).release_time_fence_days
          ,bulk_s01(i).container_item_flag
          ,bulk_s01(i).vehicle_item_flag
          ,bulk_s01(i).effectivity_control
          ,bulk_s01(i).event_flag
          ,bulk_s01(i).electronic_flag
          ,bulk_s01(i).downloadable_flag
          ,bulk_s01(i).comms_nl_trackable_flag
          ,bulk_s01(i).orderable_on_web_flag
          ,bulk_s01(i).web_status
          ,bulk_s01(i).dimension_uom_code
          ,bulk_s01(i).unit_length
          ,bulk_s01(i).unit_width
          ,bulk_s01(i).unit_height
          ,bulk_s01(i).dual_uom_control
          ,bulk_s01(i).dual_uom_deviation_high
          ,bulk_s01(i).dual_uom_deviation_low
          ,bulk_s01(i).contract_item_type_code
          ,bulk_s01(i).serv_req_enabled_code
          ,bulk_s01(i).serv_billing_enabled_flag
          ,bulk_s01(i).default_so_source_type
          ,bulk_s01(i).object_version_number
          ,bulk_s01(i).tracking_quantity_ind
          ,bulk_s01(i).s3_tracking_quantity_ind
          ,bulk_s01(i).secondary_default_ind
          ,bulk_s01(i).s3_secondary_default_ind
          ,bulk_s01(i).so_authorization_flag
          ,bulk_s01(i).attribute17
          ,bulk_s01(i).attribute18
          ,bulk_s01(i).attribute19
          ,bulk_s01(i).attribute25
          ,bulk_s01(i).s3_attribute25
          ,bulk_s01(i).expiration_action_code
          ,bulk_s01(i).s3_expiration_action_code
          ,bulk_s01(i).expiration_action_interval
          ,bulk_s01(i).s3_expiration_action_interval
          ,bulk_s01(i).hazardous_material_flag
          ,bulk_s01(i).recipe_enabled_flag
          ,bulk_s01(i).retest_interval
          ,bulk_s01(i).repair_leadtime
          ,bulk_s01(i).gdsn_outbound_enabled_flag
          ,bulk_s01(i).revision_qty_control_code
          ,bulk_s01(i).legacy_revision_id
          ,bulk_s01(i).xxs3_revision_id
          ,bulk_s01(i).revision
          ,bulk_s01(i).revision_label
          ,bulk_s01(i).revision_description
          ,bulk_s01(i).effectivity_date
          ,bulk_s01(i).implementation_date
          ,bulk_s01(i).ecn_initiation_date
          ,bulk_s01(i).change_notice
          ,bulk_s01(i).revision_attribute10
          ,bulk_s01(i).revised_item_sequence_id
          ,bulk_s01(i).s3_revised_item_sequence_id
          ,bulk_s01(i).revision_language
          ,bulk_s01(i).source_lang
          ,bulk_s01(i).revision_tl_description
          ,bulk_s01(i).last_update_date
          ,bulk_s01(i).last_updated_by
          ,bulk_s01(i).orig_system_reference
          ,bulk_s01(i).date_extracted_on
          ,bulk_s01(i).process_flag
          ,bulk_s01(i).transform_status
          ,bulk_s01(i).transform_error
          ,bulk_s01(i).cleanse_status
          ,bulk_s01(i).cleanse_error);
      
     EXIT WHEN c_ume_s01%NOTFOUND;
  END LOOP;
  CLOSE c_ume_s01;
  COMMIT;
  EXCEPTION 
  WHEN no_data_found THEN
	  log_p('Error: No data found in S01,S02,S03 Insert'||' '||SQLCODE||'-' ||SQLERRM);
    
  WHEN others THEN
  log_p('Error in the UME-Bulk Insert'||SQLERRM);
  log_p('Exception in the UME Bulk Insert'||'-'||SQLERRM);
	  l_Err_Count := SQL%BULK_EXCEPTIONS.COUNT;
    log_p('Number of statements that failed:' || l_Err_Count);
    FOR i IN 1..l_Err_Count
   LOOP
     log_p('Error #'|| i || 'occurred during '||'iteration #' || SQL%BULK_EXCEPTIONS(i).ERROR_INDEX);
     log_p('Error message is ' ||
     SQLERRM(-SQL%BULK_EXCEPTIONS(i).ERROR_CODE));
     END LOOP;
  END;
END IF;	  
	  -- Insert for the T03 org 
	  /*IF p_organization_code='UME' THEN
    BEGIN
     OPEN c_ume_t03;
	  LOOP
      FETCH c_ume_t03 BULK COLLECT INTO bulk_t03 LIMIT 10000;
       FORALL i IN 1..bulk_t03.COUNT      
        INSERT INTO xxobjt.xxs3_ptm_mtl_master_items
          (xx_inventory_item_id
          ,l_inventory_item_id
          ,s3_inventory_item_id
          ,description
          ,legacy_buyer_id
          ,s3_buyer_number
          ,legacy_accounting_rule_name
          ,s3_accounting_rule_name
          ,created_by
          ,creation_date
          ,segment1
          ,attribute2
          ,attribute9
          ,attribute11
          ,attribute12
          ,attribute13
          ,purchasing_item_flag
          ,shippable_item_flag
          ,customer_order_flag
          ,internal_order_flag
          ,service_item_flag
          ,inventory_item_flag
          ,inventory_asset_flag
          ,purchasing_enabled_flag
          ,customer_order_enabled_flag
          ,internal_order_enabled_flag
          ,so_transactions_flag
          ,mtl_transactions_enabled_flag
          ,stock_enabled_flag
          ,bom_enabled_flag
          ,build_in_wip_flag
          ,item_catalog_group_id
          ,catalog_status_flag
          ,returnable_flag
          ,legacy_organization_id
          ,legacy_organization_code
          ,s3_organization_code
          ,legacy_source_organization_id
          ,l_source_organization_code
          ,s3_source_organization_code
          ,collateral_flag
          ,taxable_flag
          ,allow_item_desc_update_flag
          ,inspection_required_flag
          ,receipt_required_flag
          ,qty_rcv_tolerance
          ,list_price_per_unit
          ,asset_category_id
          ,unit_of_issue
          ,allow_substitute_receipts_flag
          ,allow_unordered_receipts_flag
          ,allow_express_delivery_flag
          ,days_early_receipt_allowed
          ,days_late_receipt_allowed
          ,receipt_days_exception_code
          ,receiving_routing_id
          ,auto_lot_alpha_prefix
          ,start_auto_lot_number
          ,lot_control_code
          ,shelf_life_code
          ,shelf_life_days
          ,serial_number_control_code
          ,source_type
          ,source_subinventory
          ,expense_account
          ,legacy_expense_account
          ,legacy_expense_acct_segment1
          ,legacy_expense_acct_segment2
          ,legacy_expense_acct_segment3
          ,legacy_expense_acct_segment4
          ,legacy_expense_acct_segment5
          ,legacy_expense_acct_segment6
          ,legacy_expense_acct_segment7
          ,legacy_expense_acct_segment8
          ,legacy_expense_acct_segment9
          ,legacy_expense_acct_segment10
          ,s3_expense_acct_segment1
          ,s3_expense_acct_segment2
          ,s3_expense_acct_segment3
          ,s3_expense_acct_segment4
          ,s3_expense_acct_segment5
          ,s3_expense_acct_segment6
          ,s3_expense_acct_segment7
          ,s3_expense_acct_segment8
          ,restrict_subinventories_code
          ,unit_weight
          ,weight_uom_code
          ,volume_uom_code
          ,unit_volume
          ,shrinkage_rate
          ,acceptable_early_days
          ,planning_time_fence_code
          ,lead_time_lot_size
          ,std_lot_size
          ,overrun_percentage
          ,mrp_calculate_atp_flag
          ,acceptable_rate_increase
          ,acceptable_rate_decrease
          ,planning_time_fence_days
          ,end_assembly_pegging_flag
          ,bom_item_type
          ,pick_components_flag
          ,replenish_to_order_flag
          ,atp_components_flag
          ,atp_flag
          ,wip_supply_type
          ,wip_supply_subinventory
          ,s3_wip_supply_subinventory
          ,primary_uom_code
          ,secondary_uom_code
          ,s3_secondary_uom_code
          ,primary_unit_of_measure
          ,allowed_units_lookup_code
          ,cost_of_sales_account
          ,l_cost_of_sales_account
          ,l_cost_of_sales_acct_segment1
          ,l_cost_of_sales_acct_segment2
          ,l_cost_of_sales_acct_segment3
          ,l_cost_of_sales_acct_segment4
          ,l_cost_of_sales_acct_segment5
          ,l_cost_of_sales_acct_segment6
          ,l_cost_of_sales_acct_segment7
          ,l_cost_of_sales_acct_segment8
          ,l_cost_of_sales_acct_segment9
          ,l_cost_of_sales_acct_segment10
          ,s3_cost_sales_acct_segment1
          ,s3_cost_sales_acct_segment2
          ,s3_cost_sales_acct_segment3
          ,s3_cost_sales_acct_segment4
          ,s3_cost_sales_acct_segment5
          ,s3_cost_sales_acct_segment6
          ,s3_cost_sales_acct_segment7
          ,s3_cost_sales_acct_segment8
          ,s3_cost_sales_acct_segment9
          ,s3_cost_sales_acct_segment10
          ,sales_account
          ,legacy_sales_account
          ,legacy_sales_acct_segment1
          ,legacy_sales_acct_segment2
          ,legacy_sales_acct_segment3
          ,legacy_sales_acct_segment4
          ,legacy_sales_acct_segment5
          ,legacy_sales_acct_segment6
          ,legacy_sales_acct_segment7
          ,legacy_sales_acct_segment8
          ,legacy_sales_acct_segment9
          ,legacy_sales_acct_segment10
          ,s3_sales_acct_segment1
          ,s3_sales_acct_segment2
          ,s3_sales_acct_segment3
          ,s3_sales_acct_segment4
          ,s3_sales_acct_segment5
          ,s3_sales_acct_segment6
          ,s3_sales_acct_segment7
          ,s3_sales_acct_segment8
          ,s3_sales_acct_segment9
          ,s3_sales_acct_segment10
          ,default_include_in_rollup_flag
          ,inventory_item_status_code
          ,s3_inventory_item_status_code
          ,inventory_planning_code
          ,start_auto_serial_number
          ,auto_serial_alpha_prefix
          ,planner_code
          ,s3_planner_code
          ,planning_make_buy_code
          ,fixed_lot_multiplier
          ,rounding_control_type
          ,postprocessing_lead_time
          ,preprocessing_lead_time
          ,full_lead_time
          ,mrp_safety_stock_percent
          ,mrp_safety_stock_code
          ,min_minmax_quantity
          ,max_minmax_quantity
          ,minimum_order_quantity
          ,fixed_order_quantity
          ,fixed_days_supply
          ,maximum_order_quantity
          ,atp_rule_name
          ,s3_atp_rule_name
          ,reservable_type
          ,vendor_warranty_flag
          ,serviceable_product_flag
          ,material_billable_flag
          ,prorate_service_flag
          ,invoiceable_item_flag
          ,invoice_enabled_flag
          ,outside_operation_flag
          ,outside_operation_uom_type
          ,safety_stock_bucket_days
          ,costing_enabled_flag
          ,cycle_count_enabled_flag
          ,item_type
          ,s3_item_type
          ,ship_model_complete_flag
          ,mrp_planning_code
          ,ato_forecast_control
          ,release_time_fence_code
          ,release_time_fence_days
          ,container_item_flag
          ,vehicle_item_flag
          ,effectivity_control
          ,event_flag
          ,electronic_flag
          ,downloadable_flag
          ,comms_nl_trackable_flag
          ,orderable_on_web_flag
          ,web_status
          ,dimension_uom_code
          ,unit_length
          ,unit_width
          ,unit_height
          ,dual_uom_control
          ,dual_uom_deviation_high
          ,dual_uom_deviation_low
          ,contract_item_type_code
          ,serv_req_enabled_code
          ,serv_billing_enabled_flag
          ,default_so_source_type
          ,object_version_number
          ,tracking_quantity_ind
          ,s3_tracking_quantity_ind
          ,secondary_default_ind
          ,s3_secondary_default_ind
          ,so_authorization_flag
          ,attribute17
          ,attribute18
          ,attribute19
          ,attribute25
          ,s3_attribute25
          ,expiration_action_code
          ,s3_expiration_action_code
          ,expiration_action_interval
          ,s3_expiration_action_interval
          ,hazardous_material_flag
          ,recipe_enabled_flag
          ,retest_interval
          ,repair_leadtime
          ,gdsn_outbound_enabled_flag
          ,revision_qty_control_code
          ,legacy_revision_id
          ,xxs3_revision_id
          ,revision
          ,revision_label
          ,revision_description
          ,effectivity_date
          ,implementation_date
          ,ecn_initiation_date
          ,change_notice
          ,revision_attribute10
          ,revised_item_sequence_id
          ,s3_revised_item_sequence_id
          ,revision_language
          ,source_lang
          ,revision_tl_description
          ,last_update_date
          ,last_updated_by
          ,orig_system_reference
          ,date_extracted_on
          ,process_flag
          ,transform_status
          ,transform_error
          ,cleanse_status
          ,cleanse_error)
        VALUES
          (xxobjt.xxs3_ptm_mtl_master_items_seq.NEXTVAL
          ,bulk_t03(i).l_inventory_item_id
          ,bulk_t03(i).s3_inventory_item_id
          ,bulk_t03(i).description
          ,bulk_t03(i).legacy_buyer_id
          ,bulk_t03(i).s3_buyer_number
          ,bulk_t03(i).legacy_accounting_rule_name
          ,bulk_t03(i).s3_accounting_rule_name
          ,bulk_t03(i).created_by
          ,bulk_t03(i).creation_date
          ,bulk_t03(i).segment1
          ,bulk_t03(i).attribute2
          ,bulk_t03(i).attribute9
          ,bulk_t03(i).attribute11
          ,bulk_t03(i).attribute12
          ,bulk_t03(i).attribute13
          ,bulk_t03(i).purchasing_item_flag
          ,bulk_t03(i).shippable_item_flag
          ,bulk_t03(i).customer_order_flag
          ,bulk_t03(i).internal_order_flag
          ,bulk_t03(i).service_item_flag
          ,bulk_t03(i).inventory_item_flag
          ,bulk_t03(i).inventory_asset_flag
          ,bulk_t03(i).purchasing_enabled_flag
          ,bulk_t03(i).customer_order_enabled_flag
          ,bulk_t03(i).internal_order_enabled_flag
          ,bulk_t03(i).so_transactions_flag
          ,bulk_t03(i).mtl_transactions_enabled_flag
          ,bulk_t03(i).stock_enabled_flag
          ,bulk_t03(i).bom_enabled_flag
          ,bulk_t03(i).build_in_wip_flag
          ,bulk_t03(i).item_catalog_group_id
          ,bulk_t03(i).catalog_status_flag
          ,bulk_t03(i).returnable_flag
          ,bulk_t03(i).legacy_organization_id
          ,bulk_t03(i).legacy_organization_code
          ,bulk_t03(i) . s3_organization_codes
          ,bulk_t03(i).legacy_source_organization_id
          ,bulk_t03(i).l_source_organization_code
          ,bulk_t03(i).s3_source_organization_code
          ,bulk_t03(i).collateral_flag
          ,bulk_t03(i).taxable_flag
          ,bulk_t03(i).allow_item_desc_update_flag
          ,bulk_t03(i).inspection_required_flag
          ,bulk_t03(i).receipt_required_flag
          ,bulk_t03(i).qty_rcv_tolerance
          ,bulk_t03(i).list_price_per_unit
          ,bulk_t03(i).asset_category_id
          ,bulk_t03(i).unit_of_issue
          ,bulk_t03(i).allow_substitute_receipts_flag
          ,bulk_t03(i).allow_unordered_receipts_flag
          ,bulk_t03(i).allow_express_delivery_flag
          ,bulk_t03(i).days_early_receipt_allowed
          ,bulk_t03(i).days_late_receipt_allowed
          ,bulk_t03(i).receipt_days_exception_code
          ,bulk_t03(i).receiving_routing_id
          ,bulk_t03(i).auto_lot_alpha_prefix
          ,bulk_t03(i).start_auto_lot_number
          ,bulk_t03(i).lot_control_code
          ,bulk_t03(i).shelf_life_code
          ,bulk_t03(i).shelf_life_days
          ,bulk_t03(i).serial_number_control_code
          ,bulk_t03(i).source_type
          ,bulk_t03(i).source_subinventory
          ,bulk_t03(i).expense_account
          ,bulk_t03(i).legacy_expense_account
          ,bulk_t03(i).legacy_expense_acct_segment1
          ,bulk_t03(i).legacy_expense_acct_segment2
          ,bulk_t03(i).legacy_expense_acct_segment3
          ,bulk_t03(i).legacy_expense_acct_segment4
          ,bulk_t03(i).legacy_expense_acct_segment5
          ,bulk_t03(i).legacy_expense_acct_segment6
          ,bulk_t03(i).legacy_expense_acct_segment7
          ,bulk_t03(i).legacy_expense_acct_segment8
          ,bulk_t03(i).legacy_expense_acct_segment9
          ,bulk_t03(i).legacy_expense_acct_segment10
          ,bulk_t03(i).s3_expense_acct_segment1
          ,bulk_t03(i).s3_expense_acct_segment2
          ,bulk_t03(i).s3_expense_acct_segment3
          ,bulk_t03(i).s3_expense_acct_segment4
          ,bulk_t03(i).s3_expense_acct_segment5
          ,bulk_t03(i).s3_expense_acct_segment6
          ,bulk_t03(i).s3_expense_acct_segment7
          ,bulk_t03(i).s3_expense_acct_segment8
          ,bulk_t03(i).restrict_subinventories_code
          ,bulk_t03(i).unit_weight
          ,bulk_t03(i).weight_uom_code
          ,bulk_t03(i).volume_uom_code
          ,bulk_t03(i).unit_volume
          ,bulk_t03(i).shrinkage_rate
          ,bulk_t03(i).acceptable_early_days
          ,bulk_t03(i).planning_time_fence_code
          ,bulk_t03(i).lead_time_lot_size
          ,bulk_t03(i).std_lot_size
          ,bulk_t03(i).overrun_percentage
          ,bulk_t03(i).mrp_calculate_atp_flag
          ,bulk_t03(i).acceptable_rate_increase
          ,bulk_t03(i).acceptable_rate_decrease
          ,bulk_t03(i).planning_time_fence_days
          ,bulk_t03(i).end_assembly_pegging_flag
          ,bulk_t03(i).bom_item_type
          ,bulk_t03(i).pick_components_flag
          ,bulk_t03(i).replenish_to_order_flag
          ,bulk_t03(i).atp_components_flag
          ,bulk_t03(i).atp_flag
          ,bulk_t03(i).wip_supply_type
          ,bulk_t03(i).wip_supply_subinventory
          ,bulk_t03(i).s3_wip_supply_subinventory
          ,bulk_t03(i).primary_uom_code
          ,bulk_t03(i).secondary_uom_code
          ,bulk_t03(i).s3_secondary_uom_code
          ,bulk_t03(i).primary_unit_of_measure
          ,bulk_t03(i).allowed_units_lookup_code
          ,bulk_t03(i).cost_of_sales_account
          ,bulk_t03(i).l_cost_of_sales_account
          ,bulk_t03(i).l_cost_of_sales_acct_segment1
          ,bulk_t03(i).l_cost_of_sales_acct_segment2
          ,bulk_t03(i).l_cost_of_sales_acct_segment3
          ,bulk_t03(i).l_cost_of_sales_acct_segment4
          ,bulk_t03(i).l_cost_of_sales_acct_segment5
          ,bulk_t03(i).l_cost_of_sales_acct_segment6
          ,bulk_t03(i).l_cost_of_sales_acct_segment7
          ,bulk_t03(i).l_cost_of_sales_acct_segment8
          ,bulk_t03(i).l_cost_of_sales_acct_segment9
          ,bulk_t03(i).l_cost_of_sales_acct_segment10
          ,bulk_t03(i).s3_cost_sales_acct_segment1
          ,bulk_t03(i).s3_cost_sales_acct_segment2
          ,bulk_t03(i).s3_cost_sales_acct_segment3
          ,bulk_t03(i).s3_cost_sales_acct_segment4
          ,bulk_t03(i).s3_cost_sales_acct_segment5
          ,bulk_t03(i).s3_cost_sales_acct_segment6
          ,bulk_t03(i).s3_cost_sales_acct_segment7
          ,bulk_t03(i).s3_cost_sales_acct_segment8
          ,bulk_t03(i).s3_cost_sales_acct_segment9
          ,bulk_t03(i).s3_cost_sales_acct_segment10
          ,bulk_t03(i).sales_account
          ,bulk_t03(i).legacy_sales_account
          ,bulk_t03(i).legacy_sales_acct_segment1
          ,bulk_t03(i).legacy_sales_acct_segment2
          ,bulk_t03(i).legacy_sales_acct_segment3
          ,bulk_t03(i).legacy_sales_acct_segment4
          ,bulk_t03(i).legacy_sales_acct_segment5
          ,bulk_t03(i).legacy_sales_acct_segment6
          ,bulk_t03(i).legacy_sales_acct_segment7
          ,bulk_t03(i).legacy_sales_acct_segment8
          ,bulk_t03(i).legacy_sales_acct_segment9
          ,bulk_t03(i).legacy_sales_acct_segment10
          ,bulk_t03(i).s3_sales_acct_segment1
          ,bulk_t03(i).s3_sales_acct_segment2
          ,bulk_t03(i).s3_sales_acct_segment3
          ,bulk_t03(i).s3_sales_acct_segment4
          ,bulk_t03(i).s3_sales_acct_segment5
          ,bulk_t03(i).s3_sales_acct_segment6
          ,bulk_t03(i).s3_sales_acct_segment7
          ,bulk_t03(i).s3_sales_acct_segment8
          ,bulk_t03(i).s3_sales_acct_segment9
          ,bulk_t03(i).s3_sales_acct_segment10
          ,bulk_t03(i).default_include_in_rollup_flag
          ,bulk_t03(i).inventory_item_status_code
          ,bulk_t03(i).s3_inventory_item_status_code
          ,bulk_t03(i).inventory_planning_code
          ,bulk_t03(i).start_auto_serial_number
          ,bulk_t03(i).auto_serial_alpha_prefix
          ,bulk_t03(i).planner_code
          ,bulk_t03(i).s3_planner_code
          ,bulk_t03(i).planning_make_buy_code
          ,bulk_t03(i).fixed_lot_multiplier
          ,bulk_t03(i).rounding_control_type
          ,bulk_t03(i).postprocessing_lead_time
          ,bulk_t03(i).preprocessing_lead_time
          ,bulk_t03(i).full_lead_time
          ,bulk_t03(i).mrp_safety_stock_percent
          ,bulk_t03(i).mrp_safety_stock_code
          ,bulk_t03(i).min_minmax_quantity
          ,bulk_t03(i).max_minmax_quantity
          ,bulk_t03(i).minimum_order_quantity
          ,bulk_t03(i).fixed_order_quantity
          ,bulk_t03(i).fixed_days_supply
          ,bulk_t03(i).maximum_order_quantity
          ,bulk_t03(i).atp_rule_name
          ,bulk_t03(i).s3_atp_rule_name
          ,bulk_t03(i).reservable_type
          ,bulk_t03(i).vendor_warranty_flag
          ,bulk_t03(i).serviceable_product_flag
          ,bulk_t03(i).material_billable_flag
          ,bulk_t03(i).prorate_service_flag
          ,bulk_t03(i).invoiceable_item_flag
          ,bulk_t03(i).invoice_enabled_flag
          ,bulk_t03(i).outside_operation_flag
          ,bulk_t03(i).outside_operation_uom_type
          ,bulk_t03(i).safety_stock_bucket_days
          ,bulk_t03(i).costing_enabled_flag
          ,bulk_t03(i).cycle_count_enabled_flag
          ,bulk_t03(i).item_type
          ,bulk_t03(i).s3_item_type
          ,bulk_t03(i).ship_model_complete_flag
          ,bulk_t03(i).mrp_planning_code
          ,bulk_t03(i).ato_forecast_control
          ,bulk_t03(i).release_time_fence_code
          ,bulk_t03(i).release_time_fence_days
          ,bulk_t03(i).container_item_flag
          ,bulk_t03(i).vehicle_item_flag
          ,bulk_t03(i).effectivity_control
          ,bulk_t03(i).event_flag
          ,bulk_t03(i).electronic_flag
          ,bulk_t03(i).downloadable_flag
          ,bulk_t03(i).comms_nl_trackable_flag
          ,bulk_t03(i).orderable_on_web_flag
          ,bulk_t03(i).web_status
          ,bulk_t03(i).dimension_uom_code
          ,bulk_t03(i).unit_length
          ,bulk_t03(i).unit_width
          ,bulk_t03(i).unit_height
          ,bulk_t03(i).dual_uom_control
          ,bulk_t03(i).dual_uom_deviation_high
          ,bulk_t03(i).dual_uom_deviation_low
          ,bulk_t03(i).contract_item_type_code
          ,bulk_t03(i).serv_req_enabled_code
          ,bulk_t03(i).serv_billing_enabled_flag
          ,bulk_t03(i).default_so_source_type
          ,bulk_t03(i).object_version_number
          ,bulk_t03(i).tracking_quantity_ind
          ,bulk_t03(i).s3_tracking_quantity_ind
          ,bulk_t03(i).secondary_default_ind
          ,bulk_t03(i).s3_secondary_default_ind
          ,bulk_t03(i).so_authorization_flag
          ,bulk_t03(i).attribute17
          ,bulk_t03(i).attribute18
          ,bulk_t03(i).attribute19
          ,bulk_t03(i).attribute25
          ,bulk_t03(i).s3_attribute25
          ,bulk_t03(i).expiration_action_code
          ,bulk_t03(i).s3_expiration_action_code
          ,bulk_t03(i).expiration_action_interval
          ,bulk_t03(i).s3_expiration_action_interval
          ,bulk_t03(i).hazardous_material_flag
          ,bulk_t03(i).recipe_enabled_flag
          ,bulk_t03(i).retest_interval
          ,bulk_t03(i).repair_leadtime
          ,bulk_t03(i).gdsn_outbound_enabled_flag
          ,bulk_t03(i).revision_qty_control_code
          ,bulk_t03(i).legacy_revision_id
          ,bulk_t03(i).xxs3_revision_id
          ,bulk_t03(i).revision
          ,bulk_t03(i).revision_label
          ,bulk_t03(i).revision_description
          ,bulk_t03(i).effectivity_date
          ,bulk_t03(i).implementation_date
          ,bulk_t03(i).ecn_initiation_date
          ,bulk_t03(i).change_notice
          ,bulk_t03(i).revision_attribute10
          ,bulk_t03(i).revised_item_sequence_id
          ,bulk_t03(i).s3_revised_item_sequence_id
          ,bulk_t03(i).revision_language
          ,bulk_t03(i).source_lang
          ,bulk_t03(i).revision_tl_description
          ,bulk_t03(i).last_update_date
          ,bulk_t03(i).last_updated_by
          ,bulk_t03(i).orig_system_reference
          ,bulk_t03(i).date_extracted_on
          ,bulk_t03(i).process_flag
          ,bulk_t03(i).transform_status
          ,bulk_t03(i).transform_error
          ,bulk_t03(i).cleanse_status
          ,bulk_t03(i).cleanse_error);
		  
       EXIT WHEN c_ume_t03%NOTFOUND;
      END LOOP;
	  CLOSE c_ume_t03;
      COMMIT;
      EXCEPTION
      WHEN no_data_found THEN
	     log_p('Error: No data found in T03 Insert'||' '||SQLCODE||'-' ||SQLERRM);
  
        WHEN others THEN
        log_p('Error in T03 org insert'||SQLERRM);
        log_p('Exception in the T03-Bulk Insert'||'-'||SQLERRM);
	      l_Err_Count := SQL%BULK_EXCEPTIONS.COUNT;
        log_p('Number of statements that failed:' || l_Err_Count);
    FOR i IN 1..l_Err_Count
   LOOP
     log_p('Error #'|| i || 'occurred during '||'iteration #' || SQL%BULK_EXCEPTIONS(i).ERROR_INDEX);
     log_p('Error message is ' ||
     SQLERRM(-SQL%BULK_EXCEPTIONS(i).ERROR_CODE));
     END LOOP;
    END; 
     END IF;  */
      BEGIN
      FOR i IN c_out LOOP
      utl_file_extract_out(i.s3_organization_code); -- Generate Extract file into Server 
      END LOOP;
       EXCEPTION 
       WHEN others THEN
	   log_p('Error in the Generate Extract File'||SQLERRM);
       
      END ;
      
      
		  SELECT COUNT(1)
         INTO   l_count_item
         FROM xxobjt.xxs3_ptm_mtl_master_items;
         
      fnd_file.put_line(fnd_file.output, RPAD('Item Extract Records Count Report', 100, ' '));
    fnd_file.put_line(fnd_file.output, RPAD('============================================================', 200, ' '));
    fnd_file.put_line(fnd_file.output, RPAD('Run date and time:    ' ||
                       to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI'), 100, ' '));
	  fnd_file.put_line(fnd_file.output, RPAD('============================================================', 200, ' '));
	  fnd_file.put_line(fnd_file.output, '');
    fnd_file.put_line(fnd_file.output,RPAD('Track Name', 10, ' ')||chr(32)||
                       RPAD('Entity Name', 30, ' ') || chr(32) ||
					   RPAD('Total Count', 15, ' ') );
  fnd_file.put_line(fnd_file.output, RPAD('===========================================================', 200, ' '));

    fnd_file.put_line(fnd_file.output, ''); 
    
      fnd_file.put_line(fnd_file.output,RPAD('PTM', 10, ' ')||' '||
                      RPAD('ITEM', 30, ' ') ||' ' ||
			          		   RPAD(l_count_item, 15, ' ') );
     fnd_file.put_line(fnd_file.output, RPAD('=========END OF REPORT===============', 200, ' '));
     fnd_file.put_line(fnd_file.output, '');       
      
    EXCEPTION
     WHEN no_data_found THEN
	   log_p('Error: No data found master_item_extract_data Procedure'||' '||SQLCODE||'-' ||SQLERRM);
     
      WHEN report_error THEN
	  	          log_p( 'Failed to generate report');
      x_retcode := 1;
      x_errbuf  := 'Unexpected error: report error';
	  
      WHEN others THEN
	  
	   x_retcode        := 2;
      x_errbuf         := 'Unexpected error: ' || SQLERRM;
      l_status_message := SQLCODE || chr(10) || SQLERRM;
	  
      log_p(
		'Unexpected error during data extraction : ' ||
		chr(10) || l_status_message);
		
      log_p('--------------------------------------');
             
    END;
  END master_item_extract_data;

END xxs3_ptm_master_item_pkg;
/
