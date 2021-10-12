CREATE OR REPLACE PACKAGE BODY xx_ptm_item_mstr_recon_rpt_pkg AS
  p_item     VARCHAR2(100);
  p_org_code VARCHAR2(10);
   g_delimiter     VARCHAR2(5) := '~';
   --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used to write in concurrent log
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  17/11/2016  V.V.Sateesh                Initial build
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
  -- 1.0  17/11/2016  V.V.Sateesh                Initial build
  -- --------------------------------------------------------------------------------------------

PROCEDURE out_p(p_msg VARCHAR2) IS
  BEGIN

    fnd_file.put_line(fnd_file.output, p_msg);

  END out_p;
  
   ----------------------------------------------------------------------------
  --  Purpose :        Item Master Extract Recon Report
  ----------------------------------------------------------------------------
  --  Ver  Date        Name                         Description
  --  1.0 10/11/2016  V.V.SATEESH                   Initial build
  ----------------------------------------------------------------------------

PROCEDURE xx_ptm_item_master_recon_prc(x_errbuf   OUT VARCHAR2
                                      ,x_retcode  OUT NUMBER
                                      ,p_item     IN VARCHAR2
                                      ,p_org_code IN VARCHAR2) IS
l_value          VARCHAR2(100);
l_dyn_statement  VARCHAR2(3000);
l_sql            VARCHAR2(3000);
l_dq_concat      VARCHAR2(100);
l_dq_concat_st   VARCHAR2(100);
l_err_code       VARCHAR2(4000);
l_err_msg        VARCHAR2(4000);
l_legacy_value   VARCHAR2(100);
l_s3_value       VARCHAR2(100);
l_dq_rule_value  VARCHAR2(100);

CURSOR c_main IS

SELECT xpm.segment1 item
      ,pic.column_name item_column_name
      ,mia.attribute_name
      ,(SELECT meaning
        FROM   mfg_lookups mfg1
        WHERE  mfg1.lookup_type = 'ITEM_CHOICES_GUI'
        AND    mfg1.lookup_code = mia.attribute_group_id_gui) attribute_group_name
      ,(SELECT meaning
        FROM   mfg_lookups mfg2
        WHERE  mfg2.lookup_type = 'ITEM_CONTROL_LEVEL_GUI'
        AND    mfg2.lookup_code = mia.control_level) org_master_controlled
      ,nvl(user_attribute_name, user_attribute_name_gui) user_attribute_name
      ,xpm.legacy_organization_code
      ,xpm.s3_organization_code
      ,date_extracted_on
      ,process_flag
      ,xx_ptm_extract_rule_fun(xpm.segment1, xpm.legacy_organization_code) extract_rule
FROM   mtl_item_attributes              mia
      ,xxobjt.xxs3_ptm_item_columns     pic
      ,xxobjt.xxs3_ptm_master_items_stg xpm
WHERE  mia.attribute_name(+) = 'MTL_SYSTEM_ITEMS.' || column_name
AND    xpm.segment1 = nvl(p_item, segment1)
AND    legacy_organization_code = p_org_code;


CURSOR c_stage IS
 SELECT *
 FROM   xxobjt.xxs3_ptm_master_items_stg
       ,xxobjt.xxs3_ptm_item_columns
 WHERE  segment1 = nvl(p_item, segment1)
 AND    legacy_organization_code = p_org_code;
 
  CURSOR c_dq_name(p_dq_column VARCHAR2, p_dq_segment1 VARCHAR2) IS
    SELECT DISTINCT rule_name
    FROM   xxobjt.xxs3_ptm_mtl_mstr_items_dq_stg
    WHERE  dq_column = p_dq_column
    AND    segment1 = p_dq_segment1;

BEGIN
BEGIN
   -- fnd_file.put_line(fnd_file.log, 'Insert Item Number and Columns in the Stage Table');
EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_ptm_item_eqt_recon_stg';
    FOR r IN c_main LOOP
      INSERT INTO xxobjt.xxs3_ptm_item_eqt_recon_stg
        (row_id
        ,item
        ,item_column_name
        ,attribute_group_name
        ,attribute_name
        ,org_master_controlled
        ,target_s3_org_code
        ,source_legacy_org_code
        ,extract_rule
        ,eqt_process_flag
        ,date_extracted_on
        ,date_load_on
        ,transform_rule
        ,dq_reject_rule
        ,dq_report_rule
        ,clenase_rule
        ,s3_loaded_value
        ,s3_eqt_attribute_user_value
        ,s3_eqt_attribute_value
        ,legacy_attribute_user_value
        ,legacy_attribute_value
        )
      VALUES
        (xxs3_ptm_item_eqt_rcn_stg_seq.NEXTVAL
        ,r.item
        ,r.item_column_name
        ,r.attribute_group_name
        ,r.user_attribute_name
        ,r.org_master_controlled
        ,r.s3_organization_code
        ,r.legacy_organization_code
        ,r.extract_rule
        ,r.process_flag
        ,r.date_extracted_on
        ,null
        ,null
        ,null
        ,null
        ,null
        ,null
        ,null
        ,null
        ,null
        ,null
        );

    END LOOP;
    COMMIT;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
         fnd_file.put_line(fnd_file.log, 'ERROR IN INSERT-->' ||SQLERRM);
    END;
 BEGIN   
  
    FOR k IN c_stage LOOP 
    
    SELECT xx_ptm_legacy_attr_value_fn(k.segment1,k.legacy_organization_code,k.column_name) INTO l_legacy_value from dual; --xx_legacy_attribute_value
    
    SELECT xx_ptm_s3_attr_value_fn(k.segment1,k.legacy_organization_code,k.column_name) INTO l_s3_value from dual; --xx_s3_attribute_value
    
    SELECT xx_ptm_get_attr_dq_rule_fn(k.segment1,k.legacy_organization_code,k.column_name) INTO l_dq_rule_value from dual; --xx_ptm_attr_dq_rule_fn
    
   -- IF k.column_name = 'BUYER_ID' THEN
    
     --BEGIN
     /*   l_dq_concat := NULL;
        FOR r IN c_dq_name(k.column_name, k.segment1) LOOP
          l_dq_concat := l_dq_concat || ',' || r.rule_name;
        END LOOP;
        l_dq_concat_st := l_dq_concat;
      EXCEPTION
        WHEN no_data_found THEN
          dbms_output.put_line('no data found in dq' || l_dq_concat_st);
          l_dq_concat_st := NULL;
        WHEN OTHERS THEN
          dbms_output.put_line('error found in dq' || SQLERRM);
      END; */
      
           xx_item_mstr_recon_report_prc(  p_stage_primary_col         => 'ITEM_COLUMN_NAME'
                                          ,p_primary_item_col_val      => k.column_name--BUYER_ID
                                          ,p_leg_attr_value            => l_legacy_value--k.legacy_buyer_id 
                                       	  ,p_leg_attr_usr_value_val    => ''
                                          ,p_s3_eqt_attr_value_val     => l_s3_value--k.s3_buyer_number
                                          ,p_s3_eqt_attr_usr_value_val => ''
                                          ,p_s3_loaded_value_val       => '' 
                                          ,p_cleanse_rule_val          => ''
                                          ,p_dq_rpt_rule_val           => l_dq_rule_value--l_dq_concat_st 
                                          ,p_dq_rjt_rule_val           => ''
                                          ,p_transform_rule_val        => ''
                                          ,p_date_load_on_val          => ''
                                          ,p_segment1_val              => k.segment1
                                          ,p_err_code                  => l_err_code
                                          ,p_err_msg                   => l_err_msg);
  -- END IF;
   END LOOP; 
   COMMIT;
   BEGIN
   xx_ptm_recon_report('ITEM-RECON');
   EXCEPTION WHEN OTHERS THEN
   fnd_file.put_line(fnd_file.log, 'ERROR IN Output generation report Procedure Call-->' ||SQLERRM);
   END;  
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         fnd_file.put_line(fnd_file.log, 'NO DATA FOUND IN Update Procedure Call-->' ||SQLERRM);
      WHEN OTHERS THEN   
      fnd_file.put_line(fnd_file.log, 'ERROR IN Update Procedure Call-->' ||SQLERRM);
   END;  
          
 END xx_ptm_item_master_recon_prc;
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
                                           p_err_msg  OUT VARCHAR2) IS
l_dyn_statement     VARCHAR2(3000);

BEGIN
l_dyn_statement := 'UPDATE  xxobjt.xxs3_ptm_item_eqt_recon_stg set
                    LEGACY_ATTRIBUTE_VALUE=:1
                  , LEGACY_ATTRIBUTE_USER_VALUE=:2
						      , S3_EQT_ATTRIBUTE_VALUE=:3
                  , S3_EQT_ATTRIBUTE_USER_VALUE=:4
                  , S3_LOADED_VALUE=:5
                  , CLENASE_RULE=:6
                  , DQ_REPORT_RULE=:7
						      , DQ_REJECT_RULE=:8
                  , TRANSFORM_RULE=:9
                  , DATE_LOAD_ON=:10
						   WHERE '|| p_stage_primary_col || ' = ' ||
                         ':11'||'AND ITEM = :12';
  BEGIN
  EXECUTE IMMEDIATE l_dyn_statement USING p_leg_attr_value
                                          ,p_leg_attr_usr_value_val
                                          ,p_s3_eqt_attr_value_val
                                          ,p_s3_eqt_attr_usr_value_val
                                          ,p_s3_loaded_value_val
                                          ,p_cleanse_rule_val
                                          ,p_dq_rpt_rule_val
                                          ,p_dq_rjt_rule_val
                                          ,p_transform_rule_val
                                          ,p_date_load_on_val
                                          ,p_primary_item_col_val
                                          ,p_segment1_val;
   EXCEPTION
      WHEN OTHERS THEN
         ROLLBACK;
    fnd_file.put_line(fnd_file.log,'ERROR IN UPDATE xx_item_mstr_recon_report_prc PROCEDURE-->'||SQLERRM);
      END;
                     
  END xx_item_mstr_recon_report_prc;
  
  ----------------------------------------------------------------------------
  --  Purpose :        Item Master Extract Recon Report
  ----------------------------------------------------------------------------
  --  Ver  Date        Name                         Description
  --  1.0 10/11/2016  V.V.SATEESH                   Initial build
  ----------------------------------------------------------------------------
  
FUNCTION xx_ptm_extract_rule_fun(p_segment IN VARCHAR2,p_org IN VARCHAR2)
return VARCHAR2 is

l_eqt_rule_con     VARCHAR2(100);
l_extract_rule_conc VARCHAR2(100);

CURSOR c_extratrul(p_segment1 VARCHAR2,p_org_code VARCHAR2) IS
      SELECT nvl(extract_rule, 'bom') extract_rule
      FROM   (SELECT 'EXT-RULE-10' extract_rule
              FROM   mtl_system_items_b msi
              WHERE  EXISTS
               (SELECT mtt.inventory_item_id
                      FROM   mtl_material_transactions mtt
                      WHERE  mtt.inventory_item_id = msi.inventory_item_id
                      AND    mtt.creation_date > SYSDATE - 730)
              AND    (SELECT organization_code
                      FROM   mtl_parameters
                      WHERE  organization_id = msi.organization_id) =
                     p_org_code -- 'OMA'
              AND    segment1 = p_segment1
              UNION
              SELECT 'EXT-RULE-20' extract_rule
              FROM   mtl_system_items_b msi
              WHERE  EXISTS
               (SELECT ool.inventory_item_id
                      FROM   oe_order_lines_all ool
                      WHERE  ool.inventory_item_id = msi.inventory_item_id
                      AND    ool.creation_date > SYSDATE - 730)
              AND    (SELECT organization_code
                      FROM   mtl_parameters
                      WHERE  organization_id = msi.organization_id) =
                     p_org_code --'OMA'
              AND    segment1 = p_segment1
              UNION
              SELECT 'EXT-RULE-30' extract_rule
              FROM   mtl_system_items_b msi
              WHERE  EXISTS
               (SELECT mmt.inventory_item_id
                      FROM   mtl_onhand_quantities mmt
                      WHERE  mmt.inventory_item_id = msi.inventory_item_id)
              AND    (SELECT organization_code
                      FROM   mtl_parameters
                      WHERE  organization_id = msi.organization_id) =
                     p_org_code --'OMA'
              AND    segment1 = p_segment1
              UNION
              SELECT 'EXT-RULE-40' extract_rule
              FROM   mtl_system_items_b msi
              WHERE  msi.inventory_item_status_code = 'Active PTO'
              AND    (SELECT organization_code
                      FROM   mtl_parameters
                      WHERE  organization_id = msi.organization_id) =
                     p_org_code --'OMA'
              AND    segment1 = p_segment1
              UNION
              SELECT 'EXT-RULE-50' extract_rule
              FROM   mtl_system_items_b msi
              WHERE  msi.inventory_item_status_code IN
                     ('XX_BETA', 'Inactive', 'Active', 'XX_PROD')
              AND    (msi.segment1 LIKE ('%-S') OR
                    msi.segment1 LIKE ('%-CS'))
              AND    (SELECT organization_code
                      FROM   mtl_parameters
                      WHERE  organization_id = msi.organization_id) =
                     p_org_code --'OMA'
              AND    segment1 = p_segment1
              UNION
              SELECT 'EXT-RULE-60' extract_rule
              FROM   mtl_system_items_b msi
              WHERE  msi.creation_date > SYSDATE - 365
              AND    (SELECT organization_code
                      FROM   mtl_parameters
                      WHERE  organization_id = msi.organization_id) =
                     p_org_code -- 'OMA'
              AND    segment1 = p_segment1
              UNION
              SELECT 'EXT-RULE-70' extract_rule
              FROM   mtl_system_items_b msi
              WHERE  msi.inventory_item_status_code IN
                     ('Obsolete', 'XX_DISCONT')
              AND    msi.comms_nl_trackable_flag IS NOT NULL
              AND    (SELECT organization_code
                      FROM   mtl_parameters
                      WHERE  organization_id = msi.organization_id) =
                     p_org_code --'OMA'
              AND    segment1 = p_segment1
              UNION
              SELECT 'EXT-RULE-75' extract_rule
              FROM   mtl_system_items_b msi
              WHERE  msi.item_type = 'PTO'
              AND    (SELECT organization_code
                      FROM   mtl_parameters
                      WHERE  organization_id = msi.organization_id) =
                     p_org_code -- 'OMA'
              AND    segment1 = p_segment1);
BEGIN
        FOR i IN c_extratrul(p_segment,p_org) LOOP

          l_eqt_rule_con := l_eqt_rule_con || ',' || i.extract_rule;

        END LOOP;

      
      fnd_file.put_line(fnd_file.log, 'Extract Rules for Item' ||
                         l_eqt_rule_con);

      l_extract_rule_conc := NVL(l_eqt_rule_con,'BOM-EXPLODE-COMPONENT');

 return l_extract_rule_conc;
 EXCEPTION
      WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log, 'Exception in Extract Rules for Item Function xx_ptm_extract_rule_fun' ||
                           SQLERRM);
           l_extract_rule_conc:=NULL;
    


END xx_ptm_extract_rule_fun;

----------------------------------------------------------------------------
  --  Purpose :        Item Master Extract Recon Report
  ----------------------------------------------------------------------------
  --  Ver  Date        Name                         Description
  --  1.0 10/11/2016  V.V.SATEESH                   Initial build
  ----------------------------------------------------------------------------
FUNCTION xx_ptm_legacy_attr_value_fn(p_segment IN VARCHAR2,p_org IN VARCHAR2,p_column_name in varchar2)
return VARCHAR2 is

l_value     VARCHAR2(100);

BEGIN


select column_value into l_value from (
SELECT segment1,'ATTRIBUTE2' as column_name, to_char(attribute2) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'BUYER_ID' as column_name, to_char(legacy_buyer_id) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'INVENTORY_ITEM_ID' as column_name, to_char(l_inventory_item_id) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'ACCOUNTING_RULE_ID' as column_name, to_char(legacy_accounting_rule_name) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'ORGANIZATION_ID' as column_name, to_char(legacy_organization_id) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'ATP_RULE_ID' as column_name, to_char(atp_rule_name) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'VEHICLE_ITEM_FLAG' as column_name, to_char(vehicle_item_flag) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'CONTAINER_ITEM_FLAG' as column_name, to_char(container_item_flag) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'RELEASE_TIME_FENCE_DAYS' as column_name, to_char(release_time_fence_days) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'RELEASE_TIME_FENCE_CODE' as column_name, to_char(release_time_fence_code) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'ATO_FORECAST_CONTROL' as column_name, to_char(ato_forecast_control) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'MRP_PLANNING_CODE' as column_name, to_char(mrp_planning_code) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'SHIP_MODEL_COMPLETE_FLAG' as column_name, to_char(ship_model_complete_flag) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'ITEM_TYPE' as column_name, to_char(item_type) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'CYCLE_COUNT_ENABLED_FLAG' as column_name, to_char(cycle_count_enabled_flag) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'COSTING_ENABLED_FLAG' as column_name, to_char(costing_enabled_flag) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'SAFETY_STOCK_BUCKET_DAYS' as column_name, to_char(safety_stock_bucket_days) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'OUTSIDE_OPERATION_UOM_TYPE' as column_name, to_char(outside_operation_uom_type) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'OUTSIDE_OPERATION_FLAG' as column_name, to_char(outside_operation_flag) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'INVOICE_ENABLED_FLAG' as column_name, to_char(invoice_enabled_flag) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'INVOICEABLE_ITEM_FLAG' as column_name, to_char(invoiceable_item_flag) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'PRORATE_SERVICE_FLAG' as column_name, to_char(prorate_service_flag) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'MATERIAL_BILLABLE_FLAG' as column_name, to_char(material_billable_flag) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'SERVICEABLE_PRODUCT_FLAG' as column_name, to_char(serviceable_product_flag) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'VENDOR_WARRANTY_FLAG' as column_name, to_char(vendor_warranty_flag) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'RESERVABLE_TYPE' as column_name, to_char(reservable_type) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'MAXIMUM_ORDER_QUANTITY' as column_name, to_char(maximum_order_quantity) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'FIXED_DAYS_SUPPLY' as column_name, to_char(fixed_days_supply) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'FIXED_ORDER_QUANTITY' as column_name, to_char(fixed_order_quantity) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'MINIMUM_ORDER_QUANTITY' as column_name, to_char(minimum_order_quantity) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'MAX_MINMAX_QUANTITY' as column_name, to_char(max_minmax_quantity) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'MIN_MINMAX_QUANTITY' as column_name, to_char(min_minmax_quantity) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'MRP_SAFETY_STOCK_CODE' as column_name, to_char(mrp_safety_stock_code) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'MRP_SAFETY_STOCK_PERCENT' as column_name, to_char(mrp_safety_stock_percent) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'FULL_LEAD_TIME' as column_name, to_char(full_lead_time) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'PREPROCESSING_LEAD_TIME' as column_name, to_char(preprocessing_lead_time) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'POSTPROCESSING_LEAD_TIME' as column_name, to_char(postprocessing_lead_time) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'ROUNDING_CONTROL_TYPE' as column_name, to_char(rounding_control_type) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'FIXED_LOT_MULTIPLIER' as column_name, to_char(fixed_lot_multiplier) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'PLANNING_MAKE_BUY_CODE' as column_name, to_char(planning_make_buy_code) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'PLANNER_CODE' as column_name, to_char(planner_code) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'INVENTORY_PLANNING_CODE' as column_name, to_char(inventory_planning_code) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'INVENTORY_ITEM_STATUS_CODE' as column_name, to_char(inventory_item_status_code) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'DEFAULT_INCLUDE_IN_ROLLUP_FLAG' as column_name, to_char(default_include_in_rollup_flag) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'SALES_ACCOUNT' as column_name, to_char(sales_account) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'COST_OF_SALES_ACCOUNT' as column_name, to_char(cost_of_sales_account) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'ALLOWED_UNITS_LOOKUP_CODE' as column_name, to_char(allowed_units_lookup_code) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'PRIMARY_UNIT_OF_MEASURE' as column_name, to_char(primary_unit_of_measure) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'PRIMARY_UOM_CODE' as column_name, to_char(primary_uom_code) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'WIP_SUPPLY_SUBINVENTORY' as column_name, to_char(wip_supply_subinventory) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'WIP_SUPPLY_TYPE' as column_name, to_char(wip_supply_type) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'ATP_FLAG' as column_name, to_char(atp_flag) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'REPAIR_LEADTIME' as column_name, to_char(repair_leadtime) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'RETEST_INTERVAL' as column_name, to_char(retest_interval) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'RECIPE_ENABLED_FLAG' as column_name, to_char(recipe_enabled_flag) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'HAZARDOUS_MATERIAL_FLAG' as column_name, to_char(hazardous_material_flag) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'EXPIRATION_ACTION_INTERVAL' as column_name, to_char(expiration_action_interval) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'EXPIRATION_ACTION_CODE' as column_name, to_char(expiration_action_code) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'ATTRIBUTE25' as column_name, to_char(attribute25) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'ATTRIBUTE19' as column_name, to_char(attribute19) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'ATTRIBUTE18' as column_name, to_char(attribute18) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'ATTRIBUTE17' as column_name, to_char(attribute17) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'SO_AUTHORIZATION_FLAG' as column_name, to_char(so_authorization_flag) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'SECONDARY_DEFAULT_IND' as column_name, to_char(secondary_default_ind) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'ONT_PRICING_QTY_SOURCE' as column_name, to_char(ont_pricing_qty_source) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'TRACKING_QUANTITY_IND' as column_name, to_char(tracking_quantity_ind) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'OBJECT_VERSION_NUMBER' as column_name, to_char(object_version_number) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'DEFAULT_SO_SOURCE_TYPE' as column_name, to_char(default_so_source_type) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'SERV_BILLING_ENABLED_FLAG' as column_name, to_char(serv_billing_enabled_flag) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'SERV_REQ_ENABLED_CODE' as column_name, to_char(SERV_REQ_ENABLED_CODE) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'CONTRACT_ITEM_TYPE_CODE' as column_name, to_char(CONTRACT_ITEM_TYPE_CODE) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'DUAL_UOM_DEVIATION_LOW' as column_name, to_char(DUAL_UOM_DEVIATION_LOW) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'DUAL_UOM_DEVIATION_HIGH' as column_name, to_char(DUAL_UOM_DEVIATION_HIGH) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'SECONDARY_UOM_CODE' as column_name, to_char(SECONDARY_UOM_CODE) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'DUAL_UOM_CONTROL' as column_name, to_char(DUAL_UOM_CONTROL) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'UNIT_HEIGHT' as column_name, to_char(UNIT_HEIGHT) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'UNIT_WIDTH' as column_name, to_char(UNIT_WIDTH) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'UNIT_LENGTH' as column_name, to_char(UNIT_LENGTH) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'DIMENSION_UOM_CODE' as column_name, to_char(DIMENSION_UOM_CODE) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'WEB_STATUS' as column_name, to_char(WEB_STATUS) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'ORDERABLE_ON_WEB_FLAG' as column_name, to_char(ORDERABLE_ON_WEB_FLAG) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'COMMS_NL_TRACKABLE_FLAG' as column_name, to_char(COMMS_NL_TRACKABLE_FLAG) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'DOWNLOADABLE_FLAG' as column_name, to_char(DOWNLOADABLE_FLAG) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'ELECTRONIC_FLAG' as column_name, to_char(ELECTRONIC_FLAG) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'EVENT_FLAG' as column_name, to_char(EVENT_FLAG) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'EFFECTIVITY_CONTROL' as column_name, to_char(EFFECTIVITY_CONTROL) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'GDSN_OUTBOUND_ENABLED_FLAG' as column_name, to_char(GDSN_OUTBOUND_ENABLED_FLAG) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'SEGMENT1' as column_name, to_char(SEGMENT1) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'DESCRIPTION' as column_name, to_char(DESCRIPTION) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'CREATED_BY' as column_name, to_char(CREATED_BY) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'CREATION_DATE' as column_name, to_char(CREATION_DATE) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'LAST_UPDATED_BY' as column_name, to_char(LAST_UPDATED_BY) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'LAST_UPDATE_DATE' as column_name, to_char(LAST_UPDATE_DATE) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'ATP_COMPONENTS_FLAG' as column_name, to_char(ATP_COMPONENTS_FLAG) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'REPLENISH_TO_ORDER_FLAG' as column_name, to_char(REPLENISH_TO_ORDER_FLAG) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'PICK_COMPONENTS_FLAG' as column_name, to_char(PICK_COMPONENTS_FLAG) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'BOM_ITEM_TYPE' as column_name, to_char(BOM_ITEM_TYPE) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'END_ASSEMBLY_PEGGING_FLAG' as column_name, to_char(END_ASSEMBLY_PEGGING_FLAG) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'PLANNING_TIME_FENCE_DAYS' as column_name, to_char(PLANNING_TIME_FENCE_DAYS) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'ACCEPTABLE_RATE_DECREASE' as column_name, to_char(ACCEPTABLE_RATE_DECREASE) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'ACCEPTABLE_RATE_INCREASE' as column_name, to_char(ACCEPTABLE_RATE_INCREASE) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'MRP_CALCULATE_ATP_FLAG' as column_name, to_char(MRP_CALCULATE_ATP_FLAG) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'OVERRUN_PERCENTAGE' as column_name, to_char(OVERRUN_PERCENTAGE) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'STD_LOT_SIZE' as column_name, to_char(STD_LOT_SIZE) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'LEAD_TIME_LOT_SIZE' as column_name, to_char(LEAD_TIME_LOT_SIZE) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'PLANNING_TIME_FENCE_CODE' as column_name, to_char(PLANNING_TIME_FENCE_CODE) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'ACCEPTABLE_EARLY_DAYS' as column_name, to_char(ACCEPTABLE_EARLY_DAYS) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'SHRINKAGE_RATE' as column_name, to_char(SHRINKAGE_RATE) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'UNIT_VOLUME' as column_name, to_char(UNIT_VOLUME) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'VOLUME_UOM_CODE' as column_name, to_char(VOLUME_UOM_CODE) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'WEIGHT_UOM_CODE' as column_name, to_char(WEIGHT_UOM_CODE) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'UNIT_WEIGHT' as column_name, to_char(UNIT_WEIGHT) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'RESTRICT_SUBINVENTORIES_CODE' as column_name, to_char(RESTRICT_SUBINVENTORIES_CODE) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'EXPENSE_ACCOUNT' as column_name, to_char(EXPENSE_ACCOUNT) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'SOURCE_SUBINVENTORY' as column_name, to_char(SOURCE_SUBINVENTORY) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'SOURCE_TYPE' as column_name, to_char(SOURCE_TYPE) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'AUTO_SERIAL_ALPHA_PREFIX' as column_name, to_char(AUTO_SERIAL_ALPHA_PREFIX) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'START_AUTO_SERIAL_NUMBER' as column_name, to_char(START_AUTO_SERIAL_NUMBER) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'SERIAL_NUMBER_CONTROL_CODE' as column_name, to_char(SERIAL_NUMBER_CONTROL_CODE) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'SHELF_LIFE_DAYS' as column_name, to_char(SHELF_LIFE_DAYS) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'SHELF_LIFE_CODE' as column_name, to_char(SHELF_LIFE_CODE) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'LOT_CONTROL_CODE' as column_name, to_char(LOT_CONTROL_CODE) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'START_AUTO_LOT_NUMBER' as column_name, to_char(START_AUTO_LOT_NUMBER) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'AUTO_LOT_ALPHA_PREFIX' as column_name, to_char(AUTO_LOT_ALPHA_PREFIX) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'RECEIVING_ROUTING_ID' as column_name, to_char(RECEIVING_ROUTING_ID) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'RECEIPT_DAYS_EXCEPTION_CODE' as column_name, to_char(RECEIPT_DAYS_EXCEPTION_CODE) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'DAYS_LATE_RECEIPT_ALLOWED' as column_name, to_char(DAYS_LATE_RECEIPT_ALLOWED) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'DAYS_EARLY_RECEIPT_ALLOWED' as column_name, to_char(DAYS_EARLY_RECEIPT_ALLOWED) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'ALLOW_EXPRESS_DELIVERY_FLAG' as column_name, to_char(ALLOW_EXPRESS_DELIVERY_FLAG) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'ALLOW_UNORDERED_RECEIPTS_FLAG' as column_name, to_char(ALLOW_UNORDERED_RECEIPTS_FLAG) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'ALLOW_SUBSTITUTE_RECEIPTS_FLAG' as column_name, to_char(ALLOW_SUBSTITUTE_RECEIPTS_FLAG) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'UNIT_OF_ISSUE'as column_name, to_char(UNIT_OF_ISSUE) as column_Value
from xxobjt.xxs3_ptm_master_items_stg
union all
SELECT segment1,'ASSET_CATEGORY_ID' as column_name, to_char(UNIT_OF_ISSUE) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'LIST_PRICE_PER_UNIT' as column_name, to_char(LIST_PRICE_PER_UNIT) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'QTY_RCV_TOLERANCE' as column_name, to_char(QTY_RCV_TOLERANCE) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'RECEIPT_REQUIRED_FLAG' as column_name, to_char(RECEIPT_REQUIRED_FLAG) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'INSPECTION_REQUIRED_FLAG' as column_name, to_char(INSPECTION_REQUIRED_FLAG) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'ALLOW_ITEM_DESC_UPDATE_FLAG' as column_name, to_char(ALLOW_ITEM_DESC_UPDATE_FLAG) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 

union all
SELECT segment1,'TAXABLE_FLAG' as column_name, to_char(TAXABLE_FLAG) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'COLLATERAL_FLAG' as column_name, to_char(COLLATERAL_FLAG) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'RETURNABLE_FLAG' as column_name, to_char(RETURNABLE_FLAG) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'CATALOG_STATUS_FLAG' as column_name, to_char(CATALOG_STATUS_FLAG) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'ITEM_CATALOG_GROUP_ID' as column_name, to_char(ITEM_CATALOG_GROUP_ID) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'REVISION_QTY_CONTROL_CODE' as column_name, to_char(REVISION_QTY_CONTROL_CODE) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'BUILD_IN_WIP_FLAG' as column_name, to_char(BUILD_IN_WIP_FLAG) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'BOM_ENABLED_FLAG' as column_name, to_char(BOM_ENABLED_FLAG) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'STOCK_ENABLED_FLAG' as column_name, to_char(STOCK_ENABLED_FLAG) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'MTL_TRANSACTIONS_ENABLED_FLAG' as column_name, to_char(MTL_TRANSACTIONS_ENABLED_FLAG) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'SO_TRANSACTIONS_FLAG' as column_name, to_char(SO_TRANSACTIONS_FLAG) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'INTERNAL_ORDER_ENABLED_FLAG' as column_name, to_char(INTERNAL_ORDER_ENABLED_FLAG) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'CUSTOMER_ORDER_ENABLED_FLAG' as column_name, to_char(CUSTOMER_ORDER_ENABLED_FLAG) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'PURCHASING_ENABLED_FLAG' as column_name, to_char(PURCHASING_ENABLED_FLAG) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'INVENTORY_ASSET_FLAG' as column_name, to_char(INVENTORY_ASSET_FLAG) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'INVENTORY_ITEM_FLAG' as column_name, to_char(INVENTORY_ITEM_FLAG) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'SERVICE_ITEM_FLAG' as column_name, to_char(SERVICE_ITEM_FLAG) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'INTERNAL_ORDER_FLAG' as column_name, to_char(INTERNAL_ORDER_FLAG) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'CUSTOMER_ORDER_FLAG' as column_name, to_char(CUSTOMER_ORDER_FLAG) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'SHIPPABLE_ITEM_FLAG' as column_name, to_char(SHIPPABLE_ITEM_FLAG) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'PURCHASING_ITEM_FLAG' as column_name, to_char(PURCHASING_ITEM_FLAG) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'ATTRIBUTE13' as column_name, to_char(ATTRIBUTE13) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'ATTRIBUTE12' as column_name, to_char(ATTRIBUTE12) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'ATTRIBUTE11' as column_name, to_char(ATTRIBUTE11) as column_Value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'ATTRIBUTE9' as column_name, to_char(ATTRIBUTE9) as column_Value
from xxobjt.xxs3_ptm_master_items_stg) xx_temp
WHERE SEGMENT1=P_SEGMENT AND column_name=p_column_name;

return  l_value;
EXCEPTION
      WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log, 'Exception in Extract Rules for Item Function xx_ptm_extract_rule_fun' ||
                           SQLERRM);
      
    
end xx_ptm_legacy_attr_value_fn;
----------------------------------------------------------------------------
  --  Purpose :        Item Master Extract Recon Report
  ----------------------------------------------------------------------------
  --  Ver  Date        Name                         Description
  --  1.0 10/11/2016  V.V.SATEESH                   Initial build
  ----------------------------------------------------------------------------
FUNCTION xx_ptm_s3_attr_value_fn(p_segment IN VARCHAR2,p_org IN VARCHAR2,p_column_name in varchar2)
return VARCHAR2 is

l_value     VARCHAR2(100);


BEGIN


select s3_column_value into l_value from (
SELECT segment1,'ATTRIBUTE2' as s3_column_name, to_char(attribute2) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'BUYER_ID' as s3_column_name, to_char(s3_buyer_number) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'INVENTORY_ITEM_ID' as s3_column_name, to_char(S3_inventory_item_id) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'ACCOUNTING_RULE_ID' as s3_column_name, to_char(s3_accounting_rule_name) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'ORGANIZATION_ID' as s3_column_name, NULL as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'ATP_RULE_ID' as s3_column_name, to_char(S3_atp_rule_name) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'VEHICLE_ITEM_FLAG' as s3_column_name, to_char(vehicle_item_flag) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'CONTAINER_ITEM_FLAG' as s3_column_name, to_char(container_item_flag) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'RELEASE_TIME_FENCE_DAYS' as s3_column_name, to_char(release_time_fence_days) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'RELEASE_TIME_FENCE_CODE' as s3_column_name, to_char(release_time_fence_code) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'ATO_FORECAST_CONTROL' as s3_column_name, to_char(ato_forecast_control) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'MRP_PLANNING_CODE' as s3_column_name, to_char(mrp_planning_code) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'SHIP_MODEL_COMPLETE_FLAG' as s3_column_name, to_char(ship_model_complete_flag) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'ITEM_TYPE' as s3_column_name, to_char(S3_item_type) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'CYCLE_COUNT_ENABLED_FLAG' as s3_column_name, to_char(cycle_count_enabled_flag) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'COSTING_ENABLED_FLAG' as s3_column_name, to_char(costing_enabled_flag) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'SAFETY_STOCK_BUCKET_DAYS' as s3_column_name, to_char(safety_stock_bucket_days) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'OUTSIDE_OPERATION_UOM_TYPE' as s3_column_name, to_char(outside_operation_uom_type) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'OUTSIDE_OPERATION_FLAG' as s3_column_name, to_char(outside_operation_flag) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'INVOICE_ENABLED_FLAG' as s3_column_name, to_char(invoice_enabled_flag) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'INVOICEABLE_ITEM_FLAG' as s3_column_name, to_char(invoiceable_item_flag) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'PRORATE_SERVICE_FLAG' as s3_column_name, to_char(prorate_service_flag) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'MATERIAL_BILLABLE_FLAG' as s3_column_name, to_char(material_billable_flag) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'SERVICEABLE_PRODUCT_FLAG' as s3_column_name, to_char(serviceable_product_flag) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'VENDOR_WARRANTY_FLAG' as s3_column_name, to_char(vendor_warranty_flag) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'RESERVABLE_TYPE' as s3_column_name, to_char(reservable_type) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'MAXIMUM_ORDER_QUANTITY' as s3_column_name, to_char(maximum_order_quantity) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'FIXED_DAYS_SUPPLY' as s3_column_name, to_char(fixed_days_supply) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'FIXED_ORDER_QUANTITY' as s3_column_name, to_char(fixed_order_quantity) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'MINIMUM_ORDER_QUANTITY' as s3_column_name, to_char(minimum_order_quantity) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'MAX_MINMAX_QUANTITY' as s3_column_name, to_char(max_minmax_quantity) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'MIN_MINMAX_QUANTITY' as s3_column_name, to_char(min_minmax_quantity) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'MRP_SAFETY_STOCK_CODE' as s3_column_name, to_char(mrp_safety_stock_code) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'MRP_SAFETY_STOCK_PERCENT' as s3_column_name, to_char(mrp_safety_stock_percent) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'FULL_LEAD_TIME' as s3_column_name, to_char(full_lead_time) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'PREPROCESSING_LEAD_TIME' as s3_column_name, to_char(preprocessing_lead_time) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'POSTPROCESSING_LEAD_TIME' as s3_column_name, to_char(postprocessing_lead_time) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'ROUNDING_CONTROL_TYPE' as s3_column_name, to_char(rounding_control_type) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'FIXED_LOT_MULTIPLIER' as s3_column_name, to_char(fixed_lot_multiplier) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'PLANNING_MAKE_BUY_CODE' as s3_column_name, to_char(planning_make_buy_code) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'PLANNER_CODE' as s3_column_name, to_char(S3_planner_code) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'INVENTORY_PLANNING_CODE' as s3_column_name, to_char(inventory_planning_code) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'INVENTORY_ITEM_STATUS_CODE' as s3_column_name, to_char(S3_inventory_item_status_code) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'DEFAULT_INCLUDE_IN_ROLLUP_FLAG' as s3_column_name, to_char(default_include_in_rollup_flag) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'SALES_ACCOUNT' as s3_column_name, to_char(sales_account) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'COST_OF_SALES_ACCOUNT' as s3_column_name, to_char(cost_of_sales_account) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'ALLOWED_UNITS_LOOKUP_CODE' as s3_column_name, to_char(allowed_units_lookup_code) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'PRIMARY_UNIT_OF_MEASURE' as s3_column_name, to_char(primary_unit_of_measure) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'PRIMARY_UOM_CODE' as s3_column_name, to_char(primary_uom_code) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'WIP_SUPPLY_SUBINVENTORY' as s3_column_name, to_char(S3_wip_supply_subinventory) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'WIP_SUPPLY_TYPE' as s3_column_name, to_char(wip_supply_type) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'ATP_FLAG' as s3_column_name, to_char(atp_flag) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'REPAIR_LEADTIME' as s3_column_name, to_char(repair_leadtime) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'RETEST_INTERVAL' as s3_column_name, to_char(retest_interval) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'RECIPE_ENABLED_FLAG' as s3_column_name, to_char(recipe_enabled_flag) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'HAZARDOUS_MATERIAL_FLAG' as s3_column_name, to_char(hazardous_material_flag) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'EXPIRATION_ACTION_INTERVAL' as s3_column_name, to_char(S3_expiration_action_interval) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'EXPIRATION_ACTION_CODE' as s3_column_name, to_char(expiration_action_code) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'ATTRIBUTE25' as s3_column_name, to_char(S3_attribute25) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'ATTRIBUTE19' as s3_column_name, to_char(attribute19) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'ATTRIBUTE18' as s3_column_name, to_char(attribute18) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'ATTRIBUTE17' as s3_column_name, to_char(attribute17) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'SO_AUTHORIZATION_FLAG' as s3_column_name, to_char(so_authorization_flag) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'SECONDARY_DEFAULT_IND' as s3_column_name, to_char(S3_secondary_default_ind) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'ONT_PRICING_QTY_SOURCE' as s3_column_name, to_char(S3_ont_pricing_qty_source) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'TRACKING_QUANTITY_IND' as s3_column_name, to_char(S3_tracking_quantity_ind) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'OBJECT_VERSION_NUMBER' as s3_column_name, to_char(object_version_number) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'DEFAULT_SO_SOURCE_TYPE' as s3_column_name, to_char(default_so_source_type) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'SERV_BILLING_ENABLED_FLAG' as s3_column_name, to_char(serv_billing_enabled_flag) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'SERV_REQ_ENABLED_CODE' as s3_column_name, to_char(SERV_REQ_ENABLED_CODE) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'CONTRACT_ITEM_TYPE_CODE' as s3_column_name, to_char(CONTRACT_ITEM_TYPE_CODE) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'DUAL_UOM_DEVIATION_LOW' as s3_column_name, to_char(DUAL_UOM_DEVIATION_LOW) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'DUAL_UOM_DEVIATION_HIGH' as s3_column_name, to_char(DUAL_UOM_DEVIATION_HIGH) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'SECONDARY_UOM_CODE' as s3_column_name, to_char(S3_SECONDARY_UOM_CODE) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'DUAL_UOM_CONTROL' as s3_column_name, to_char(DUAL_UOM_CONTROL) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'UNIT_HEIGHT' as s3_column_name, to_char(UNIT_HEIGHT) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'UNIT_WIDTH' as s3_column_name, to_char(UNIT_WIDTH) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'UNIT_LENGTH' as s3_column_name, to_char(UNIT_LENGTH) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'DIMENSION_UOM_CODE' as s3_column_name, to_char(DIMENSION_UOM_CODE) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'WEB_STATUS' as s3_column_name, to_char(WEB_STATUS) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'ORDERABLE_ON_WEB_FLAG' as s3_column_name, to_char(ORDERABLE_ON_WEB_FLAG) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'COMMS_NL_TRACKABLE_FLAG' as s3_column_name, to_char(COMMS_NL_TRACKABLE_FLAG) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'DOWNLOADABLE_FLAG' as s3_column_name, to_char(DOWNLOADABLE_FLAG) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'ELECTRONIC_FLAG' as s3_column_name, to_char(ELECTRONIC_FLAG) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'EVENT_FLAG' as s3_column_name, to_char(EVENT_FLAG) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'EFFECTIVITY_CONTROL' as s3_column_name, to_char(EFFECTIVITY_CONTROL) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'GDSN_OUTBOUND_ENABLED_FLAG' as s3_column_name, to_char(GDSN_OUTBOUND_ENABLED_FLAG) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'SEGMENT1' as s3_column_name, to_char(SEGMENT1) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'DESCRIPTION' as s3_column_name, to_char(DESCRIPTION) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'CREATED_BY' as s3_column_name, to_char(CREATED_BY) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'CREATION_DATE' as s3_column_name, to_char(CREATION_DATE) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'LAST_UPDATED_BY' as s3_column_name, to_char(LAST_UPDATED_BY) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'LAST_UPDATE_DATE' as s3_column_name, to_char(LAST_UPDATE_DATE) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'ATP_COMPONENTS_FLAG' as s3_column_name, to_char(ATP_COMPONENTS_FLAG) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'REPLENISH_TO_ORDER_FLAG' as s3_column_name, to_char(REPLENISH_TO_ORDER_FLAG) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'PICK_COMPONENTS_FLAG' as s3_column_name, to_char(PICK_COMPONENTS_FLAG) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'BOM_ITEM_TYPE' as s3_column_name, to_char(BOM_ITEM_TYPE) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'END_ASSEMBLY_PEGGING_FLAG' as s3_column_name, to_char(END_ASSEMBLY_PEGGING_FLAG) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'PLANNING_TIME_FENCE_DAYS' as s3_column_name, to_char(PLANNING_TIME_FENCE_DAYS) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'ACCEPTABLE_RATE_DECREASE' as s3_column_name, to_char(ACCEPTABLE_RATE_DECREASE) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'ACCEPTABLE_RATE_INCREASE' as s3_column_name, to_char(ACCEPTABLE_RATE_INCREASE) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'MRP_CALCULATE_ATP_FLAG' as s3_column_name, to_char(MRP_CALCULATE_ATP_FLAG) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'OVERRUN_PERCENTAGE' as s3_column_name, to_char(OVERRUN_PERCENTAGE) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'STD_LOT_SIZE' as s3_column_name, to_char(STD_LOT_SIZE) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'LEAD_TIME_LOT_SIZE' as s3_column_name, to_char(LEAD_TIME_LOT_SIZE) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'PLANNING_TIME_FENCE_CODE' as s3_column_name, to_char(PLANNING_TIME_FENCE_CODE) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'ACCEPTABLE_EARLY_DAYS' as s3_column_name, to_char(ACCEPTABLE_EARLY_DAYS) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'SHRINKAGE_RATE' as s3_column_name, to_char(SHRINKAGE_RATE) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'UNIT_VOLUME' as s3_column_name, to_char(UNIT_VOLUME) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'VOLUME_UOM_CODE' as s3_column_name, to_char(VOLUME_UOM_CODE) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'WEIGHT_UOM_CODE' as s3_column_name, to_char(WEIGHT_UOM_CODE) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'UNIT_WEIGHT' as s3_column_name, to_char(UNIT_WEIGHT) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'RESTRICT_SUBINVENTORIES_CODE' as s3_column_name, to_char(RESTRICT_SUBINVENTORIES_CODE) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'EXPENSE_ACCOUNT' as s3_column_name, to_char(EXPENSE_ACCOUNT) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'SOURCE_SUBINVENTORY' as s3_column_name, to_char(SOURCE_SUBINVENTORY) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'SOURCE_TYPE' as s3_column_name, to_char(SOURCE_TYPE) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'AUTO_SERIAL_ALPHA_PREFIX' as s3_column_name, to_char(AUTO_SERIAL_ALPHA_PREFIX) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'START_AUTO_SERIAL_NUMBER' as s3_column_name, to_char(START_AUTO_SERIAL_NUMBER) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'SERIAL_NUMBER_CONTROL_CODE' as s3_column_name, to_char(SERIAL_NUMBER_CONTROL_CODE) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'SHELF_LIFE_DAYS' as s3_column_name, to_char(SHELF_LIFE_DAYS) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'SHELF_LIFE_CODE' as s3_column_name, to_char(SHELF_LIFE_CODE) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'LOT_CONTROL_CODE' as s3_column_name, to_char(LOT_CONTROL_CODE) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'START_AUTO_LOT_NUMBER' as s3_column_name, to_char(START_AUTO_LOT_NUMBER) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'AUTO_LOT_ALPHA_PREFIX' as s3_column_name, to_char(AUTO_LOT_ALPHA_PREFIX) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'RECEIVING_ROUTING_ID' as s3_column_name, to_char(S3_RECEIVING_ROUTING_ID) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'RECEIPT_DAYS_EXCEPTION_CODE' as s3_column_name, to_char(RECEIPT_DAYS_EXCEPTION_CODE) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'DAYS_LATE_RECEIPT_ALLOWED' as s3_column_name, to_char(DAYS_LATE_RECEIPT_ALLOWED) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'DAYS_EARLY_RECEIPT_ALLOWED' as s3_column_name, to_char(DAYS_EARLY_RECEIPT_ALLOWED) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'ALLOW_EXPRESS_DELIVERY_FLAG' as s3_column_name, to_char(ALLOW_EXPRESS_DELIVERY_FLAG) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'ALLOW_UNORDERED_RECEIPTS_FLAG' as s3_column_name, to_char(ALLOW_UNORDERED_RECEIPTS_FLAG) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'ALLOW_SUBSTITUTE_RECEIPTS_FLAG' as s3_column_name, to_char(ALLOW_SUBSTITUTE_RECEIPTS_FLAG) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'UNIT_OF_ISSUE'as s3_column_name, to_char(UNIT_OF_ISSUE) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg
union all
SELECT segment1,'ASSET_CATEGORY_ID' as s3_column_name, to_char(UNIT_OF_ISSUE) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'LIST_PRICE_PER_UNIT' as s3_column_name, to_char(LIST_PRICE_PER_UNIT) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'QTY_RCV_TOLERANCE' as s3_column_name, to_char(QTY_RCV_TOLERANCE) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'RECEIPT_REQUIRED_FLAG' as s3_column_name, to_char(RECEIPT_REQUIRED_FLAG) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'INSPECTION_REQUIRED_FLAG' as s3_column_name, to_char(INSPECTION_REQUIRED_FLAG) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'ALLOW_ITEM_DESC_UPDATE_FLAG' as s3_column_name, to_char(ALLOW_ITEM_DESC_UPDATE_FLAG) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 

union all
SELECT segment1,'TAXABLE_FLAG' as s3_column_name, to_char(TAXABLE_FLAG) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'COLLATERAL_FLAG' as s3_column_name, to_char(COLLATERAL_FLAG) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'RETURNABLE_FLAG' as s3_column_name, to_char(RETURNABLE_FLAG) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'CATALOG_STATUS_FLAG' as s3_column_name, to_char(CATALOG_STATUS_FLAG) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'ITEM_CATALOG_GROUP_ID' as s3_column_name, to_char(S3_ITEM_CATALOG_GROUP_ID) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'REVISION_QTY_CONTROL_CODE' as s3_column_name, to_char(REVISION_QTY_CONTROL_CODE) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'BUILD_IN_WIP_FLAG' as s3_column_name, to_char(BUILD_IN_WIP_FLAG) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'BOM_ENABLED_FLAG' as s3_column_name, to_char(BOM_ENABLED_FLAG) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'STOCK_ENABLED_FLAG' as s3_column_name, to_char(STOCK_ENABLED_FLAG) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'MTL_TRANSACTIONS_ENABLED_FLAG' as s3_column_name, to_char(MTL_TRANSACTIONS_ENABLED_FLAG) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'SO_TRANSACTIONS_FLAG' as s3_column_name, to_char(SO_TRANSACTIONS_FLAG) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'INTERNAL_ORDER_ENABLED_FLAG' as s3_column_name, to_char(INTERNAL_ORDER_ENABLED_FLAG) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'CUSTOMER_ORDER_ENABLED_FLAG' as s3_column_name, to_char(CUSTOMER_ORDER_ENABLED_FLAG) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'PURCHASING_ENABLED_FLAG' as s3_column_name, to_char(PURCHASING_ENABLED_FLAG) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'INVENTORY_ASSET_FLAG' as s3_column_name, to_char(INVENTORY_ASSET_FLAG) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'INVENTORY_ITEM_FLAG' as s3_column_name, to_char(INVENTORY_ITEM_FLAG) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'SERVICE_ITEM_FLAG' as s3_column_name, to_char(SERVICE_ITEM_FLAG) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'INTERNAL_ORDER_FLAG' as s3_column_name, to_char(INTERNAL_ORDER_FLAG) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'CUSTOMER_ORDER_FLAG' as s3_column_name, to_char(CUSTOMER_ORDER_FLAG) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'SHIPPABLE_ITEM_FLAG' as s3_column_name, to_char(SHIPPABLE_ITEM_FLAG) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'PURCHASING_ITEM_FLAG' as s3_column_name, to_char(PURCHASING_ITEM_FLAG) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'ATTRIBUTE13' as s3_column_name, to_char(ATTRIBUTE13) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'ATTRIBUTE12' as s3_column_name, to_char(ATTRIBUTE12) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'ATTRIBUTE11' as s3_column_name, to_char(ATTRIBUTE11) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg 
union all
SELECT segment1,'ATTRIBUTE9' as s3_column_name, to_char(ATTRIBUTE9) as s3_column_value
from xxobjt.xxs3_ptm_master_items_stg) xx_temp
WHERE SEGMENT1=P_SEGMENT AND s3_column_name=p_column_name;

return  l_value;
EXCEPTION
      WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log, 'Exception in Extract Rules for Item Function xx_ptm_extract_rule_fun' ||
                           SQLERRM);
      
    
end xx_ptm_s3_attr_value_fn;
----------------------------------------------------------------------------
  --  Purpose :        Item Master Extract Recon Report
  ----------------------------------------------------------------------------
  --  Ver  Date        Name                         Description
  --  1.0 10/11/2016  V.V.SATEESH                   Initial build
  ----------------------------------------------------------------------------

FUNCTION xx_ptm_get_attr_dq_rule_fn(p_segment IN VARCHAR2,p_org IN VARCHAR2,p_column_name in varchar2)
return VARCHAR2 is

l_value     VARCHAR2(100);
l_dq_concat      VARCHAR2(100);
l_dq_concat_st   VARCHAR2(100);

CURSOR c_dq_name(p_dq_column VARCHAR2, p_dq_segment1 VARCHAR2) IS
    SELECT DISTINCT rule_name
    FROM   xxobjt.xxs3_ptm_mtl_mstr_items_dq_stg
    WHERE  dq_column = p_dq_column
    AND    segment1 = p_dq_segment1;


 BEGIN
        l_dq_concat := NULL;
        FOR r IN c_dq_name(p_column_name, p_segment) LOOP
          l_dq_concat := l_dq_concat || ',' || r.rule_name;
        END LOOP;
        l_dq_concat_st := l_dq_concat;
        
        return l_dq_concat_st;
      EXCEPTION
        WHEN no_data_found THEN
          fnd_file.put_line(fnd_file.log,'no data found in dq' || l_dq_concat_st);
          l_dq_concat_st := NULL;
        WHEN OTHERS THEN
           fnd_file.put_line(fnd_file.log,'error found in dq' || SQLERRM);
           
      END xx_ptm_get_attr_dq_rule_fn;
      
       -- --------------------------------------------------------------------------------------------
  -- Purpose: Report for Recon details
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date     	   Name                          Description
  -- 1.0  11/17/2016   V.V.Sateesh                   Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE xx_ptm_recon_report(p_entity IN VARCHAR2)  IS

     --Variables
    l_count_success NUMBER;
    l_count_fail    NUMBER;

	 --Cursor for generate Cleanse Report

    CURSOR c_report_recon IS

      SELECT row_id
            ,item
            ,item_column_name
            ,attribute_group_name
            ,attribute_name
            ,org_master_controlled
            ,target_s3_org_code
            ,source_legacy_org_code
            ,legacy_attribute_value
            ,legacy_attribute_user_value
            ,s3_eqt_attribute_value
            ,s3_eqt_attribute_user_value
            ,s3_loaded_value
            ,clenase_rule
            ,dq_report_rule
            ,dq_reject_rule
            ,transform_rule
            ,extract_rule
            ,eqt_process_flag
            ,date_extracted_on
            ,date_load_on
            FROM xxobjt.xxs3_ptm_item_eqt_recon_stg;

  BEGIN
  fnd_file.put_line(fnd_file.log, 'begin xx_ptm_recon_report procedure'||SYSTIMESTAMP);

  IF p_entity = 'ITEM-RECON' THEN

  
      out_p('Report name = XX PTM Item Extract Recon Report');
      out_p('====================================================');
      out_p('Data Migration Object Name = ' || 'ITEM MASTER ');
      out_p('Run date and time: ' ||TO_CHAR(SYSDATE, 'dd-Mon-YYYY HH24:MI'));
      out_p('');


      out_p(rpad('Track Name', 10, ' ') || g_delimiter ||
                       rpad('Entity Name', 20, ' ') || g_delimiter ||
                       rpad('ROW_ID ', 20, ' ') || g_delimiter ||
                       rpad('ITEM', 20, ' ') || g_delimiter ||
                       rpad('ITEM_COLUMN_NAME', 30, ' ') || g_delimiter ||
                       rpad('ATTRIBUTE_GROUP_NAME', 30, ' ') || g_delimiter ||
                       rpad('ATTRIBUTE_NAME', 30, ' ') || g_delimiter ||
					   rpad('ORG_MASTER_CONTROLLED', 30, ' ') || g_delimiter ||
                       rpad('TARGET_S3_ORG_CODE', 30, ' ') || g_delimiter ||
                       rpad('SOURCE_LEGACY_ORG_CODE', 30, ' ') || g_delimiter || 
					   rpad('LEGACY_ATTRIBUTE_VALUE', 30, ' ') || g_delimiter ||
					   rpad('LEGACY_ATTRIBUTE_USER_VALUE', 30, ' ') || g_delimiter ||
					   rpad('S3_EQT_ATTRIBUTE_VALUE', 30, ' ') || g_delimiter ||
					   rpad('S3_EQT_ATTRIBUTE_USER_VALUE', 30, ' ') || g_delimiter ||
					   rpad('S3_LOADED_VALUE', 30, ' ') || g_delimiter ||
				       rpad('CLENASE_RULE', 30, ' ') || g_delimiter ||
					   rpad('DQ_REPORT_RULE', 30, ' ') || g_delimiter ||
					   rpad('DQ_REJECT_RULE', 30, ' ') || g_delimiter ||
					   rpad('TRANSFORM_RULE', 30, ' ') || g_delimiter ||
					   rpad('EXTRACT_RULE', 30, ' ') || g_delimiter ||
					   rpad('EQT_PROCESS_FLAG', 30, ' ') || g_delimiter ||
					   rpad('DATE_EXTRACTED_ON', 30, ' ') || g_delimiter ||
					   rpad('DATE_LOAD_ON', 30, ' ') );


    FOR r_data IN c_report_recon LOOP
                 out_p(rpad('PTM', 10, ' ') || g_delimiter ||
                       rpad('ITEMS-RECONCILIATION-REPORT', 20, ' ') || g_delimiter ||                        
					   rpad(nvl(to_char(r_data.ROW_ID),'NULL'), 20, ' ') || g_delimiter ||
                       rpad(nvl(to_char(r_data.ITEM),'NULL'), 20, ' ') || g_delimiter ||
                       rpad(nvl(to_char(r_data.ITEM_COLUMN_NAME),'NULL'), 30, ' ') || g_delimiter ||
                       rpad(nvl(to_char(r_data.ATTRIBUTE_GROUP_NAME),'NULL'), 30, ' ') || g_delimiter ||
                       rpad(nvl(to_char(r_data.ATTRIBUTE_NAME),'NULL'), 30, ' ') || g_delimiter ||
					   rpad(nvl(to_char(r_data.ORG_MASTER_CONTROLLED),'NULL'), 30, ' ') || g_delimiter ||
                       rpad(nvl(to_char(r_data.target_s3_org_code),'NULL'), 30, ' ') || g_delimiter ||
                       rpad(nvl(to_char(r_data.source_legacy_org_code),'NULL'), 30, ' ') || g_delimiter || 
					   rpad(nvl(to_char(r_data.legacy_attribute_value),'NULL'), 30, ' ') || g_delimiter ||
					   rpad(nvl(to_char(r_data.legacy_attribute_user_value),'NULL'), 30, ' ') || g_delimiter ||
					   rpad(nvl(to_char(r_data.s3_eqt_attribute_value),'NULL'), 30, ' ') || g_delimiter ||
					   rpad(nvl(to_char(r_data.s3_eqt_attribute_user_value),'NULL'), 30, ' ') || g_delimiter ||
					   rpad(nvl(to_char(r_data.s3_loaded_value),'NULL'), 30, ' ') || g_delimiter ||
				       rpad(nvl(to_char(r_data.clenase_rule),'NULL'), 30, ' ') || g_delimiter ||
					   rpad(nvl(to_char(r_data.dq_report_rule),'NULL'), 30, ' ') || g_delimiter ||
					   rpad(nvl(to_char(r_data.dq_reject_rule),'NULL'), 30, ' ') || g_delimiter ||
					   rpad(nvl(to_char(r_data.transform_rule),'NULL'), 30, ' ') || g_delimiter ||
					   rpad(nvl(to_char(r_data.extract_rule),'NULL'), 30, ' ') || g_delimiter ||
					   rpad(nvl(to_char(r_data.eqt_process_flag),'NULL'), 30, ' ') || g_delimiter ||
					   rpad(nvl(to_char(r_data.date_extracted_on),'NULL'), 30, ' ') || g_delimiter ||
					   rpad(nvl(to_char(r_data.date_load_on),'NULL'), 30, ' '));

    END LOOP;

    out_p('');
    out_p('Stratasys Confidential'|| g_delimiter);
    END IF;
fnd_file.put_line(fnd_file.output, 'End of xx_ptm_recon_report procedure'||SYSTIMESTAMP);

    EXCEPTION
      WHEN NO_DATA_FOUND THEN
	  log_p('No data found'||' '||SQLCODE||'-' ||SQLERRM);

  END xx_ptm_recon_report;

 END xx_ptm_item_mstr_recon_rpt_pkg;
 /
