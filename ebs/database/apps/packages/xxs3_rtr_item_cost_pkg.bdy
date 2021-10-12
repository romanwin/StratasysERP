CREATE OR REPLACE PACKAGE BODY xxs3_rtr_item_cost_pkg AS

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used to write in concurrent log
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  19/08/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE log_p(p_msg VARCHAR2) IS
  BEGIN
  
    fnd_file.put_line(fnd_file.log, p_msg);
    /*dbms_output.put_line(i_msg);*/
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log, 'Error in writting Log File. ' ||
                         SQLERRM);
  END log_p;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used to write in concurrent output
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  19/08/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE out_p(p_msg VARCHAR2) IS
  BEGIN
  
    fnd_file.put_line(fnd_file.output, p_msg);
    /*dbms_output.put_line(p_msg);*/
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log, 'Error in writting Output File. ' ||
                         SQLERRM);
  END out_p;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for Item cost Data Quality Report
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  19/08/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE item_cost_report_data(p_entity_name IN VARCHAR2) AS
    CURSOR c_report IS
      SELECT xicd.*
      FROM xxs3_rtr_item_cost    xic
          ,xxs3_rtr_item_cost_dq xicd
      WHERE xic.xx_item_cost_id = xicd.xx_item_cost_id
      AND xic.process_flag IN ('Q', 'R')
      ORDER BY 1;
    p_delimiter VARCHAR2(5) := '~';
  BEGIN
    out_p(rpad('Item Cost DQ status report', 100, ' '));
    out_p(rpad('=============================', 100, ' '));
    out_p('');
    out_p('Date:    ' || to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI'));
  
    out_p('');
  
    out_p(rpad('Track Name', 15, ' ') || p_delimiter ||
          rpad('Entity Name', 20, ' ') || p_delimiter ||
          rpad('XX ITEM COST ID  ', 15, ' ') || p_delimiter ||
          rpad('Rule Name', 50, ' ') || p_delimiter ||
          rpad('Reason Code', 50, ' '));
  
    FOR i IN c_report
    LOOP
      out_p(rpad('RTR', 15, ' ') || p_delimiter ||
            rpad('ITEM COST', 20, ' ') || p_delimiter ||
            rpad(i.xx_item_cost_id, 15, ' ') || p_delimiter ||
            rpad(i.rule_name, 50, ' ') || p_delimiter ||
            rpad(i.notes, 50, ' '));
    END LOOP;
  
    --   p_err_code := '0';
    --  p_err_msg  := '';
  EXCEPTION
    WHEN OTHERS THEN
      -- p_err_code := '2';
      -- p_err_msg  := 'SQLERRM: ' || SQLERRM;
      log_p('Failed to generate report: ' || SQLERRM);
  END item_cost_report_data;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for Item cost Data Quality Report Rules
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  19/08/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE insert_update_item_cost_dq(p_item_cost_id NUMBER
                                      ,p_rule_name    IN VARCHAR2
                                      ,p_reject_code  IN VARCHAR2
                                      ,p_err_code     OUT VARCHAR2
                                      ,p_err_msg      OUT VARCHAR2) IS
  
  BEGIN
    UPDATE xxs3_rtr_item_cost
    SET process_flag = 'Q'
    WHERE xx_item_cost_id = p_item_cost_id;
  
    INSERT INTO xxs3_rtr_item_cost_dq
      (xx_item_cost_dq_id
      ,xx_item_cost_id
      ,rule_name
      ,notes)
    VALUES
      (xxs3_rtr_item_cost_dq_seq.NEXTVAL
      ,p_item_cost_id
      ,p_rule_name
      ,p_reject_code);
  
    p_err_code := '0';
    p_err_msg  := '';
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := '2';
      p_err_msg  := 'SQLERRM: ' || SQLERRM;
    
  END insert_update_item_cost_dq;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used for Approved Suppliers Transform Report
  --           
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  19/08/2016  TCS                           Initial build  
  -- --------------------------------------------------------------------------------------------

  PROCEDURE data_transform_report(p_entity VARCHAR2) IS
    CURSOR c_report_item_cost IS
      SELECT *
      FROM xxs3_rtr_item_cost xic
      WHERE xic.transform_status IN ('PASS', 'FAIL');
    p_delimiter     VARCHAR2(5) := '~';
    l_err_msg       VARCHAR2(2000);
    l_count_success NUMBER;
    l_count_fail    NUMBER;
  BEGIN
  
    SELECT COUNT(1)
    INTO l_count_success
    FROM xxs3_rtr_item_cost xic
    WHERE xic.transform_status = 'PASS';
  
    SELECT COUNT(1)
    INTO l_count_fail
    FROM xxs3_rtr_item_cost xic
    WHERE xic.transform_status = 'FAIL';
  
    out_p(rpad('Report name = Data Transformation Report' || p_delimiter, 100, ' '));
    out_p(rpad('========================================' || p_delimiter, 100, ' '));
    out_p(rpad('Data Migration Object Name = ' || p_entity || p_delimiter, 100, ' '));
    out_p('');
    out_p(rpad('Run date and time:    ' ||
               to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') || p_delimiter, 100, ' '));
    out_p(rpad('Total Record Count Success = ' || l_count_success ||
               p_delimiter, 100, ' '));
    out_p(rpad('Total Record Count Failure = ' || l_count_fail ||
               p_delimiter, 100, ' '));
  
    out_p('');
  
    out_p(rpad('Track Name', 10, ' ') || p_delimiter ||
          rpad('Entity Name', 11, ' ') || p_delimiter ||
          rpad('XX ITEM COST ID  ', 14, ' ') || p_delimiter ||
          rpad('CIC Organization Code', 240, ' ') || p_delimiter ||
          rpad('S3 CIC Organization Code', 30, ' ') || p_delimiter ||
          rpad('CCT Organization Code', 240, ' ') || p_delimiter ||
          rpad('S3 CCT Organization Code', 30, ' ') || p_delimiter ||
          rpad('Status', 10, ' ') || p_delimiter ||
          rpad('Error Message', 200, ' '));
  
    FOR r_data IN c_report_item_cost
    LOOP
      out_p(rpad('RTR', 10, ' ') || p_delimiter ||
            rpad('ITEM COST', 11, ' ') || p_delimiter ||
            rpad(r_data.xx_item_cost_id, 14, ' ') || p_delimiter ||
            rpad(r_data.cic_organization_code, 240, ' ') || p_delimiter ||
            rpad(r_data.s3_cic_organization_code, 30, ' ') || p_delimiter ||
            rpad(r_data.cct_organization_code, 240, ' ') || p_delimiter ||
            rpad(r_data.s3_cct_organization_code, 30, ' ') || p_delimiter ||
            rpad(r_data.transform_status, 10, ' ') || p_delimiter ||
            rpad(nvl(r_data.transform_error, 'NULL'), 200, ' '));
    END LOOP;
  
    fnd_file.put_line(fnd_file.output, '');
    fnd_file.put_line(fnd_file.output, 'Stratasys Confidential' ||
                       p_delimiter);
  END;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for Item cost Data Quality Rules Check
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  19/08/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE quality_check_item_cost(p_err_code OUT VARCHAR2
                                   ,p_err_msg  OUT VARCHAR2) IS
    l_status     VARCHAR2(10) := 'SUCCESS';
    l_check_rule VARCHAR2(10) := 'TRUE';
    CURSOR cur_item_cost IS
      SELECT * FROM xxs3_rtr_item_cost WHERE process_flag = 'N';
  BEGIN
    FOR i IN cur_item_cost
    LOOP
      l_status     := 'SUCCESS';
      l_check_rule := 'TRUE';
    
      IF xxs3_dq_util_pkg.eqt_198(i.make_or_buy_item, i.based_on_rollup_flag)
      THEN
      
        insert_update_item_cost_dq(i.xx_item_cost_id, 'EQT_198:Valid Cost Roll-up Flag for MAKE', 'Valid Cost Roll-up Flag for MAKE', p_err_code, p_err_msg);
        l_status := 'ERR';
      
      END IF;
    
      IF xxs3_dq_util_pkg.eqt_199(i.make_or_buy_item, i.based_on_rollup_flag)
      THEN
      
        insert_update_item_cost_dq(i.xx_item_cost_id, 'EQT_199:Valid Cost Roll-up Flag for BUY', 'Valid Cost Roll-up Flag for BUY', p_err_code, p_err_msg);
        l_status := 'ERR';
      
      END IF;
    
      IF xxs3_dq_util_pkg.eqt_200(i.make_or_buy_item, i.cic_organization_id, i.inventory_item_id, i.source_type, i.cost_type_id)
      THEN
      
        insert_update_item_cost_dq(i.xx_item_cost_id, 'EQT_200:Valid Material Costs for MAKE', 'Valid Material Costs for MAKE', p_err_code, p_err_msg);
        l_status := 'ERR';
      
      END IF;
    
      IF xxs3_dq_util_pkg.eqt_201(i.make_or_buy_item, i.cic_organization_id, i.inventory_item_id, i.source_type, i.cost_type_id)
      THEN
      
        insert_update_item_cost_dq(i.xx_item_cost_id, 'EQT_201:Valid Material Costs for BUY', 'Valid Material Costs for BUY', p_err_code, p_err_msg);
        l_status := 'ERR';
      
      END IF;
    
      IF l_status <> 'ERR'
      THEN
        UPDATE xxs3_rtr_item_cost
        SET process_flag = 'Y'
        WHERE xx_item_cost_id = i.xx_item_cost_id;
      END IF;
    END LOOP;
    COMMIT;
  
  END quality_check_item_cost;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for Item Cost Extract
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  19/08/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE item_cost_extract_data(x_errbuf  OUT VARCHAR2
                                  ,x_retcode OUT NUMBER) AS
    l_err_code            NUMBER;
    l_err_msg             VARCHAR2(100);
    l_error_message       VARCHAR2(2000); -- mock
    l_get_org             VARCHAR2(50);
    l_get_concat_segments VARCHAR2(50);
    l_get_sub_inv_name    VARCHAR2(50);
    l_get_row             VARCHAR2(50);
    l_get_rack            VARCHAR2(50);
    l_get_bin             VARCHAR2(50);
  
    CURSOR cur_rtr_item_cost IS
    
      SELECT DISTINCT (cic.inventory_item_id)
                     ,new_items.segment1
                     ,decode(new_items.planning_make_buy_code, '2', 'BUY', '1', 'MAKE') make_or_buy_item
                     ,cic.organization_id cic_org_id
                     ,(SELECT organization_code
                       FROM org_organization_definitions
                       WHERE organization_id = cic.organization_id) cic_organization_code
                     ,new_items.s3_org_id AS s3_cic_org_id
                     ,cct.disable_date cct_disable_date
                     ,cic.inventory_asset_flag
                     ,cic.lot_size
                     ,cic.based_on_rollup_flag
                     ,cic.shrinkage_rate
                     ,cic.defaulted_flag
                     ,cic.cost_update_id
                     ,cic.pl_material
                     ,cic.pl_material_overhead
                     ,cic.pl_resource
                     ,cic.pl_outside_processing
                     ,cic.pl_overhead
                     ,cic.tl_material
                     ,cic.tl_material_overhead
                     ,cic.tl_resource
                     ,cic.tl_outside_processing
                     ,cic.tl_overhead
                     ,cic.material_cost
                     ,cic.material_overhead_cost
                     ,cic.resource_cost
                     ,cic.outside_processing_cost
                     ,cic.overhead_cost
                     ,cic.pl_item_cost
                     ,cic.tl_item_cost
                     ,cic.item_cost cic_item_cost
                     ,cic.unburdened_cost
                     ,cic.burden_cost
                     ,cct.organization_id cct_org_id
                     ,(SELECT organization_code
                       FROM org_organization_definitions
                       WHERE organization_id = cct.organization_id) cct_organization_code
                     ,new_items.s3_org_id s3_cct_org_id
                     ,cct.cost_type
                     ,cct.description
                     ,cct.costing_method_type
                     ,cct.frozen_standard_flag
                     ,cct.default_cost_type_id
                     ,cct.bom_snapshot_flag
                     ,cct.alternate_bom_designator
                     ,cct.allow_updates_flag
                     ,cct.pl_element_flag
                     ,cct.pl_resource_flag
                     ,cct.pl_operation_flag
                     ,cct.pl_activity_flag
                     ,cct.attribute_category
                     ,cicdv.organization_id cicdv_org_id
                     ,cicdv.cost_type_id
                     ,cicdv.cost_element
                     ,cicdv.item_cost cicdv_item_cost
                     ,cicdv.source_type
      FROM cst_item_costs          cic
          ,cst_item_cost_details_v cicdv
          ,cst_cost_types          cct
          ,
           --   mtl_system_items_b      msib
           (SELECT msib.inventory_item_id
                  ,msib.segment1
                  ,msib.organization_id
                  ,msib.planning_make_buy_code
                  ,'M01' AS s3_org_id
            FROM mtl_item_categories_v mic
                ,mtl_system_items_b    msib
            WHERE mic.organization_id = msib.organization_id
            AND mic.inventory_item_id = msib.inventory_item_id
            AND mic.segment6 <> 'POLYJET'
            AND msib.organization_id IN (739) --- UME / M01 items
            UNION
            SELECT msib.inventory_item_id
                  ,msib.segment1
                  ,msib.organization_id
                  ,msib.planning_make_buy_code
                  ,'T01' AS s3_org_id
            FROM mtl_item_categories_v mic
                ,mtl_system_items_b    msib
            WHERE mic.organization_id = msib.organization_id
            AND mic.inventory_item_id = msib.inventory_item_id
            AND mic.segment6 <> 'POLYJET'
            AND msib.organization_id IN (740) -- USE/T01 items
            UNION
            SELECT msib.inventory_item_id
                  ,msib.segment1
                  ,msib.organization_id
                  ,msib.planning_make_buy_code
                  ,'T02' AS s3_org_id
            FROM mtl_item_categories_v mic
                ,mtl_system_items_b    msib
            WHERE mic.organization_id = msib.organization_id
            AND mic.inventory_item_id = msib.inventory_item_id
            AND msib.organization_id = 742 -- UTP/T02
            UNION
            SELECT msib.inventory_item_id
                  ,msib.segment1
                  ,msib.organization_id
                  ,msib.planning_make_buy_code
                  ,'T03' AS s3_org_id
            FROM mtl_item_categories_v mic
                ,mtl_system_items_b    msib
            WHERE mic.organization_id = msib.organization_id
            AND mic.inventory_item_id = msib.inventory_item_id
            AND mic.segment6 <> 'POLYJET'
            AND msib.organization_id IN (739)
            AND msib.planning_make_buy_code = 2 -- UME/T03
            UNION
            SELECT msib.inventory_item_id
                  ,msib.segment1
                  ,msib.organization_id
                  ,msib.planning_make_buy_code
                  ,'S01' AS s3_org_id
            FROM mtl_item_categories_v mic
                ,mtl_system_items_b    msib
            WHERE mic.organization_id = msib.organization_id
            AND mic.inventory_item_id = msib.inventory_item_id
            AND mic.segment6 <> 'POLYJET'
            AND (mic.segment7 = 'FG' OR mic.segment1 = 'Customer Support')
            AND msib.organization_id IN (739) --UME/S01
            UNION
            SELECT msib.inventory_item_id
                  ,msib.segment1
                  ,msib.organization_id
                  ,msib.planning_make_buy_code
                  ,'S02' AS s3_org_id
            FROM mtl_item_categories_v mic
                ,mtl_system_items_b    msib
            WHERE mic.organization_id = msib.organization_id
            AND mic.inventory_item_id = msib.inventory_item_id
            AND mic.segment6 <> 'POLYJET'
            AND (mic.segment7 = 'FG' OR mic.segment1 = 'Customer Support')
            AND msib.organization_id IN (739) --UME/S02
            UNION
            SELECT msib.inventory_item_id
                  ,msib.segment1
                  ,msib.organization_id
                  ,msib.planning_make_buy_code
                  ,'S03' AS s3_org_id
            FROM mtl_item_categories_v mic
                ,mtl_system_items_b    msib
            WHERE mic.organization_id = msib.organization_id
            AND mic.inventory_item_id = msib.inventory_item_id
            AND mic.segment6 <> 'POLYJET'
            AND (mic.segment7 = 'FG' OR mic.segment1 = 'Customer Support')
            AND msib.organization_id IN (739)) new_items
      WHERE cic.cost_type_id = cct.cost_type_id
      AND new_items.inventory_item_id = cic.inventory_item_id
      AND new_items.organization_id = cic.organization_id
      AND cicdv.inventory_item_id = cic.inventory_item_id
      AND cicdv.organization_id = cic.organization_id
      AND cicdv.cost_type_id = cic.cost_type_id
           --  and cic.organization_id in (739, 740, 741, 742)
      AND new_items.planning_make_buy_code = 2
      AND cicdv.cost_type_id IN ('1', '3')
      AND cicdv.source_type IN ('User defined', 'Rolled up', 'Default');
  
    CURSOR cur_transform IS
      SELECT * FROM xxs3_rtr_item_cost WHERE process_flag IN ('Y', 'Q');
  
  BEGIN
    --------------------------------- Remove existing data in staging --------------------------------
  
    DELETE FROM xxobjt.xxs3_rtr_item_cost;
  
    DELETE FROM xxobjt.xxs3_rtr_item_cost_dq;
  
    -------------------------------- Insert Legacy Data in Staging-----------------------------------
  
    FOR i IN cur_rtr_item_cost
    LOOP
    
      INSERT INTO xxs3_rtr_item_cost
        (xx_item_cost_id
        ,date_of_extract
        ,process_flag
        ,inventory_item_id
        ,item_segment1
        ,make_or_buy_item
        ,cic_organization_id
        ,cic_organization_code
        ,s3_cic_organization_code
        ,cct_disable_date
        ,inventory_asset_flag
        ,lot_size
        ,based_on_rollup_flag
        ,shrinkage_rate
        ,defaulted_flag
        ,cost_update_id
        ,pl_material
        ,pl_material_overhead
        ,pl_resource
        ,pl_outside_processing
        ,pl_overhead
        ,tl_material
        ,tl_material_overhead
        ,tl_resource
        ,tl_outside_processing
        ,tl_overhead
        ,material_cost
        ,material_overhead_cost
        ,resource_cost
        ,outside_processing_cost
        ,overhead_cost
        ,pl_item_cost
        ,tl_item_cost
        ,cic_item_cost
        ,unburdened_cost
        ,burden_cost
        ,cct_organization_id
        ,cct_organization_code
        ,s3_cct_organization_code
        ,cost_type
        ,description
        ,costing_method_type
        ,frozen_standard_flag
        ,default_cost_type_id
        ,bom_snapshot_flag
        ,alternate_bom_designator
        ,allow_updates_flag
        ,pl_element_flag
        ,pl_resource_flag
        ,pl_operation_flag
        ,pl_activity_flag
        ,attribute_category
        ,cicdv_organization_id
        ,cost_type_id
        ,cost_element
        ,cicdv_item_cost
        ,source_type)
      VALUES
      
        (xxs3_rtr_item_cost_seq.NEXTVAL
        ,SYSDATE
        ,'N'
        ,i.inventory_item_id
        ,i.segment1
        ,i.make_or_buy_item
        ,i.cic_org_id
        ,i.cic_organization_code
        ,i.s3_cic_org_id
        ,i.cct_disable_date
        ,i.inventory_asset_flag
        ,i.lot_size
        ,i.based_on_rollup_flag
        ,i.shrinkage_rate
        ,i.defaulted_flag
        ,i.cost_update_id
        ,i.pl_material
        ,i.pl_material_overhead
        ,i.pl_resource
        ,i.pl_outside_processing
        ,i.pl_overhead
        ,i.tl_material
        ,i.tl_material_overhead
        ,i.tl_resource
        ,i.tl_outside_processing
        ,i.tl_overhead
        ,i.material_cost
        ,i.material_overhead_cost
        ,i.resource_cost
        ,i.outside_processing_cost
        ,i.overhead_cost
        ,i.pl_item_cost
        ,i.tl_item_cost
        ,i.cic_item_cost
        ,i.unburdened_cost
        ,i.burden_cost
        ,i.cct_org_id
        ,i.cct_organization_code
        ,i.s3_cct_org_id
        ,i.cost_type
        ,i.description
        ,i.costing_method_type
        ,i.frozen_standard_flag
        ,i.default_cost_type_id
        ,i.bom_snapshot_flag
        ,i.alternate_bom_designator
        ,i.allow_updates_flag
        ,i.pl_element_flag
        ,i.pl_resource_flag
        ,i.pl_operation_flag
        ,i.pl_activity_flag
        ,i.attribute_category
        ,i.cicdv_org_id
        ,i.cost_type_id
        ,i.cost_element
        ,i.cicdv_item_cost
        ,i.source_type);
    END LOOP;
  
    -------------------------------- Quality check Data------------------------------
  
    quality_check_item_cost(l_err_code, l_err_msg);
  
    item_cost_report_data('ITEM COST');
  
  END item_cost_extract_data;
END xxs3_rtr_item_cost_pkg;
