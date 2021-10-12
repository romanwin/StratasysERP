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
CREATE OR REPLACE PACKAGE BODY xxs3_ptp_asl_pkg

-- --------------------------------------------------------------------------------------------
-- Purpose: This Package is used for Approved Suppliers List Extract, Quality Check and Report
--           
-- --------------------------------------------------------------------------------------------
-- Ver  Date        Name                          Description
-- 1.0  18/05/2016  TCS                           Initial build  
-- --------------------------------------------------------------------------------------------

 AS

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used to write in concurrent log
  --           
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build  
  -- --------------------------------------------------------------------------------------------
  PROCEDURE log_p(p_msg VARCHAR2) IS
  BEGIN
  
    fnd_file.put_line(fnd_file.log, p_msg);
    /*dbms_output.put_line(i_msg);*/
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log, 'Error in writting Log File. ' || SQLERRM);
  END log_p;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used to write in concurrent output
  --           
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build  
  -- --------------------------------------------------------------------------------------------

  PROCEDURE out_p(p_msg VARCHAR2) IS
  BEGIN
  
    fnd_file.put_line(fnd_file.output, p_msg);
    /*dbms_output.put_line(p_msg);*/
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log, 'Error in writting Output File. ' || SQLERRM);
  END out_p;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used to Update process flag and Quality Check Result
  --           
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build  
  -- --------------------------------------------------------------------------------------------

  PROCEDURE insert_update_asl_dq(p_xx_asl_id   NUMBER
                                ,p_rule_name   IN VARCHAR2
                                ,p_reject_code IN VARCHAR2
                                ,p_err_code    OUT VARCHAR2
                                ,p_err_msg     OUT VARCHAR2) IS
  
  BEGIN
    UPDATE xxobjt.xxs3_ptp_asl SET process_flag = 'Q' WHERE xx_asl_id = p_xx_asl_id;
  
    INSERT INTO xxobjt.xxs3_ptp_asl_dq
      (xx_dq_asl_id
      ,xx_asl_id
      ,rule_name
      ,notes)
    VALUES
      (xxobjt.xxs3_ptp_asl_dq_seq.NEXTVAL
      ,p_xx_asl_id
      ,p_rule_name
      ,p_reject_code);
    p_err_code := '0';
    p_err_msg  := '';
  
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := '2';
      p_err_msg  := 'SQLERRM: ' || SQLERRM;
      ROLLBACK;
    
  END insert_update_asl_dq;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used to Update process flag and Quality Check Result
  --           
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build  
  -- --------------------------------------------------------------------------------------------

  PROCEDURE insert_update_asl_reject_dq(p_xx_asl_id   NUMBER
                                       ,p_rule_name   IN VARCHAR2
                                       ,p_reject_code IN VARCHAR2
                                       ,p_err_code    OUT VARCHAR2
                                       ,p_err_msg     OUT VARCHAR2) IS
  
  BEGIN
    UPDATE xxobjt.xxs3_ptp_asl SET process_flag = 'R' WHERE xx_asl_id = p_xx_asl_id;
  
    INSERT INTO xxobjt.xxs3_ptp_asl_dq
      (xx_dq_asl_id
      ,xx_asl_id
      ,rule_name
      ,notes)
    VALUES
      (xxobjt.xxs3_ptp_asl_dq_seq.NEXTVAL
      ,p_xx_asl_id
      ,p_rule_name
      ,p_reject_code);
    p_err_code := '0';
    p_err_msg  := '';
  
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := '2';
      p_err_msg  := 'SQLERRM: ' || SQLERRM;
      ROLLBACK;
    
  END insert_update_asl_reject_dq;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for Approves Suppliers List Data Quality Check
  --           
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build  
  -- --------------------------------------------------------------------------------------------

  PROCEDURE quality_check_asl(p_err_code OUT VARCHAR2
                             ,p_err_msg  OUT VARCHAR2) IS
    l_status     VARCHAR2(10) := 'SUCCESS';
    l_check_rule VARCHAR2(10) := 'TRUE';
    CURSOR cur_asl IS
      SELECT * FROM xxobjt.xxs3_ptp_asl WHERE process_flag = 'N';
  BEGIN
    FOR i IN cur_asl LOOP
      l_status     := 'SUCCESS';
      l_check_rule := xxs3_dq_util_pkg.eqt_053(i.business);
      IF l_check_rule = 'FALSE' THEN
        insert_update_asl_reject_dq(i.xx_asl_id
                                   ,'EQT_053:Valid US Supplier Business Type'
                                   ,'Inalid US Supplier Business Type'
                                   ,p_err_code
                                   ,p_err_msg);
        l_status := 'ERR';
      END IF;
      IF i.status IS NULL THEN
        insert_update_asl_dq(i.xx_asl_id
                            ,'EQT-028:Is Not Null'
                            ,'Missing value ' || '' || 'for field ' || 'ASL Status'
                            ,p_err_code
                            ,p_err_msg);
        l_status := 'ERR';
      END IF;
      IF i.supplier IS NULL THEN
        insert_update_asl_dq(i.xx_asl_id
                            ,'EQT-028:Is Not Null'
                            ,'Missing value ' || '' || 'for field ' || 'Vendor'
                            ,p_err_code
                            ,p_err_msg);
        l_status := 'ERR';
      END IF;
      IF i.item IS NULL THEN
        insert_update_asl_dq(i.xx_asl_id
                            ,'EQT-028:Is Not Null'
                            ,'Missing value ' || '' || 'for field ' || 'Item'
                            ,p_err_code
                            ,p_err_msg);
        l_status := 'ERR';
      END IF;
      IF i.site IS NULL THEN
        insert_update_asl_dq(i.xx_asl_id
                            ,'EQT-028:Is Not Null'
                            ,'Missing value ' || '' || 'for field ' || 'Vendor Site'
                            ,p_err_code
                            ,p_err_msg);
        l_status := 'ERR';
      END IF;
      /*      IF i.enable_planning_schedules IS NULL THEN
        insert_update_asl_dq(i.xx_asl_id
                            ,'EQT-028:Is Not Null'
                            ,'Missing value ' || '' || 'for field ' || 'Enable planning schedules'
                            ,p_err_code
                            ,p_err_msg);
        l_status := 'ERR';
      END IF;
      IF i.enable_shipping_schedules IS NULL THEN
        insert_update_asl_dq(i.xx_asl_id
                            ,'EQT-028:Is Not Null'
                            ,'Missing value ' || '' || 'for field ' || 'Enable shipping schedules'
                            ,p_err_code
                            ,p_err_msg);
        l_status := 'ERR';
      END IF;*/
    
      IF l_status <> 'ERR' THEN
        UPDATE xxobjt.xxs3_ptp_asl SET process_flag = 'Y' WHERE xx_asl_id = i.xx_asl_id;
      END IF;
    
    END LOOP;
    COMMIT;
    p_err_code := '0';
    p_err_msg  := '';
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := '2';
      p_err_msg  := 'SQLERRM: ' || SQLERRM;
      ROLLBACK;
  END quality_check_asl;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used for Approved Suppliers List Data Extract
  --           
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build  
  -- --------------------------------------------------------------------------------------------

  PROCEDURE asl_extract_data(x_errbuf  OUT VARCHAR2
                            ,x_retcode OUT NUMBER) AS
  
    l_err_code NUMBER;
    l_err_msg  VARCHAR2(100);
  
    TYPE asl_record IS RECORD(
       asl_id                     NUMBER
      ,TYPE                       VARCHAR2(9)
      ,commodity                  VARCHAR2(286)
      ,item                       VARCHAR2(40)
      ,business                   VARCHAR2(80)
      ,supplier                   VARCHAR2(240)
      ,site                       VARCHAR2(60)
      ,operating_unit             VARCHAR2(240)
      ,status                     VARCHAR2(25)
      ,disabled                   VARCHAR2(1)
      ,supplier_item              VARCHAR2(25)
      ,manufacturer               VARCHAR2(30)
      ,review_by                  DATE
      ,global                     VARCHAR2(1)
      ,owning_org                 VARCHAR2(240)
      ,owning_organization_code   VARCHAR2(3)
      ,using_organization_code    VARCHAR2(3)
      ,comments                   VARCHAR2(240)
      ,global_local               VARCHAR2(1)
      ,purchasing_uom             VARCHAR2(25)
      ,release_method             VARCHAR2(80)
      ,price_update_tolerance     NUMBER
      ,country_of_origin          VARCHAR2(2)
      ,seq                        NUMBER
      ,doc_type                   VARCHAR2(80)
      ,doc_number                 VARCHAR2(50)
      ,line                       VARCHAR2(240)
      ,enable_planning_schedules  VARCHAR2(1)
      ,enable_shipping_schedules  VARCHAR2(1)
      ,scheduler                  VARCHAR2(240)
      ,enable_auto_schedule       VARCHAR2(1)
      ,enable_authorizations      VARCHAR2(1)
      ,plan_bucket_pattern        VARCHAR2(25)
      ,ship_bucket_pattern        VARCHAR2(25)
      ,plan_schedule_type         VARCHAR2(80)
      ,ship_schedule_type         VARCHAR2(80)
      ,sequence                   NUMBER
      ,authorization              VARCHAR2(25)
      ,cutoff_days                NUMBER
      ,supplier_capacity_calendar VARCHAR2(10)
      ,processing_lead_time       NUMBER
      ,from_date                  DATE
      ,to_date                    DATE
      ,capacity_per_day           NUMBER
      ,days_in_advance            NUMBER
      ,tolerance_percentage       NUMBER
      ,minimum_order_quantity     NUMBER
      ,fixed_lot_multiple         NUMBER
      ,vmi_enabled                VARCHAR2(1)
      ,automatic_allowed          VARCHAR2(1)
      ,approval                   VARCHAR2(30)
      ,forecast_horizon_days      NUMBER
      ,minimum_quantity           NUMBER
      ,maximum_quantity           NUMBER
      ,consigned_from_supplier    VARCHAR2(1)
      ,billing_cycle_days         NUMBER
      ,consume_on_aging           VARCHAR2(1));
    TYPE asl_stg_table_type IS TABLE OF asl_record INDEX BY BINARY_INTEGER;
    stage_table asl_stg_table_type;
  
    CURSOR cur_transform IS
      SELECT xx_asl_id
            ,owning_organization_code
            ,using_organization_code
            ,status
        FROM xxs3_ptp_asl
       WHERE process_flag IN ('Y', 'Q');
  
    CURSOR cur_ptp_asl IS
      SELECT pas.asl_id                         asl_id
            ,pai.item_commodity_flag            TYPE
            ,pai.commodity                      commodity
            ,pai.item_num                       item
            ,pas.vendor_business_type_dsp       business
            ,pas.vendor_name                    supplier
            ,pas.vendor_site_code               site
            ,hao.NAME                           operating_unit
            ,pas.asl_status_dsp                 status
            ,pas.disable_flag                   disabled
            ,pas.primary_vendor_item            supplier_item
            ,pas.asl_manufacturer               manufacturer
            ,pas.review_by_date                 review_by
            ,pas.global_flag                    global
            ,pas.owning_organization_name       owning_org
            ,mpt1.organization_code             owning_organization_code
            ,mpt2.organization_code             using_organization_code
            ,pas.comments                       comments
            ,pas.global_flag                    global_local
            ,paa.purchasing_uom                 purchasing_uom
            ,paa.release_generation_method_dsp  release_method
            ,paa.price_update_tolerance         price_update_tolerance
            ,paa.country_of_origin_code         country_of_origin
            ,pad.sequence_num                   seq
            ,pad.document_type_dsp              doc_type
            ,pad.document_num                   doc_number
            ,pad.line_num                       line
            ,paa.enable_plan_schedule_flag      enable_planning_schedules
            ,paa.enable_ship_schedule_flag      enable_shipping_schedules
            ,paa.scheduler_name                 scheduler
            ,paa.enable_autoschedule_flag       enable_auto_schedule
            ,paa.enable_authorizations_flag     enable_authorizations
            ,paa.plan_bucket_pattern            plan_bucket_pattern
            ,paa.ship_bucket_pattern            ship_bucket_pattern
            ,paa.plan_schedule_type_dsp         plan_schedule_type
            ,paa.ship_schedule_type_dsp         ship_schedule_type
            ,cau.authorization_sequence         sequence
            ,cau.authorization_code             authorization
            ,cau.timefence_days                 cutoff_days
            ,paa.delivery_calendar              supplier_capacity_calendar
            ,paa.processing_lead_time           processing_lead_time
            ,psi.from_date                      from_date
            ,psi.to_date                        to_date
            ,psi.capacity_per_day               capacity_per_day
            ,pst.number_of_days                 days_in_advance
            ,pst.tolerance                      tolerance_percentage
            ,paa.min_order_qty                  minimum_order_quantity
            ,paa.fixed_lot_multiple             fixed_lot_multiple
            ,paa.enable_vmi_flag                vmi_enabled
            ,paa.enable_vmi_auto_replenish_flag automatic_allowed
            ,paa.vmi_replenishment_approval     approval
            ,paa.forecast_horizon               forecast_horizon_days
            ,paa.vmi_min_qty                    minimum_quantity
            ,paa.vmi_max_qty                    maximum_quantity
            ,paa.consigned_from_supplier_flag   consigned_from_supplier
            ,paa.consigned_billing_cycle        billing_cycle_days
            ,paa.consume_on_aging_flag          consume_on_aging
        FROM po_asl_items_v             pai
            ,po_asl_suppliers_v         pas
            ,po_asl_attributes_v        paa
            ,po_asl_documents_v         pad
            ,chv_authorizations         cau
            ,po_supplier_item_capacity  psi
            ,po_supplier_item_tolerance pst
            ,ap_supplier_sites_all      aps
            ,hr_all_organization_units  hao
            ,mtl_parameters             mpt1
            ,mtl_parameters             mpt2
       WHERE ((pas.item_id = pai.item_id AND pas.item_id IS NOT NULL) OR
             (pas.commodity_id = pai.commodity_id AND pas.commodity_id IS NOT NULL))
         AND pai.using_organization_id = pas.using_organization_id
         AND pas.asl_id = paa.asl_id(+)
         AND pas.using_organization_id = paa.using_organization_id(+)
         AND pas.asl_id = pad.asl_id(+)
         AND pas.using_organization_id = pad.using_organization_id(+)
         AND pas.asl_id = cau.reference_id(+)
         AND pas.using_organization_id = cau.using_organization_id(+)
         AND pas.asl_id = psi.asl_id(+)
         AND pas.using_organization_id = psi.using_organization_id(+)
         AND pas.asl_id = pst.asl_id(+)
         AND pas.using_organization_id = pst.using_organization_id(+)
         AND pas.owning_organization_id = mpt1.organization_id(+)
         AND pas.using_organization_id = mpt2.organization_id(+)
         AND pas.vendor_id = aps.vendor_id(+)
         AND pas.vendor_site_id = aps.vendor_site_id(+)
         AND aps.org_id = hao.organization_id(+)
         AND (pas.disable_flag != 'Y' OR pas.disable_flag IS NULL)
         AND pas.owning_organization_id IN (739, 740);
  BEGIN
    mo_global.init('PO');
    mo_global.set_policy_context('M', NULL);
    x_retcode := 0;
    x_errbuf  := 'COMPLETE';
    DELETE FROM xxs3_ptp_asl;
    DELETE FROM xxs3_ptp_asl_dq;
    SELECT pas.asl_id                         asl_id
          ,pai.item_commodity_flag            TYPE
          ,pai.commodity                      commodity
          ,pai.item_num                       item
          ,pas.vendor_business_type_dsp       business
          ,pas.vendor_name                    supplier
          ,pas.vendor_site_code               site
          ,hao.NAME                           operating_unit
          ,pas.asl_status_dsp                 status
          ,pas.disable_flag                   disabled
          ,pas.primary_vendor_item            supplier_item
          ,pas.asl_manufacturer               manufacturer
          ,pas.review_by_date                 review_by
          ,pas.global_flag                    global
          ,pas.owning_organization_name       owning_org
          ,mpt1.organization_code             owning_organization_code
          ,mpt2.organization_code             using_organization_code
          ,pas.comments                       comments
          ,pas.global_flag                    global_local
          ,paa.purchasing_uom                 purchasing_uom
          ,paa.release_generation_method_dsp  release_method
          ,paa.price_update_tolerance         price_update_tolerance
          ,paa.country_of_origin_code         country_of_origin
          ,pad.sequence_num                   seq
          ,pad.document_type_dsp              doc_type
          ,pad.document_num                   doc_number
          ,pad.line_num                       line
          ,paa.enable_plan_schedule_flag      enable_planning_schedules
          ,paa.enable_ship_schedule_flag      enable_shipping_schedules
          ,paa.scheduler_name                 scheduler
          ,paa.enable_autoschedule_flag       enable_auto_schedule
          ,paa.enable_authorizations_flag     enable_authorizations
          ,paa.plan_bucket_pattern            plan_bucket_pattern
          ,paa.ship_bucket_pattern            ship_bucket_pattern
          ,paa.plan_schedule_type_dsp         plan_schedule_type
          ,paa.ship_schedule_type_dsp         ship_schedule_type
          ,cau.authorization_sequence         sequence
          ,cau.authorization_code             authorization
          ,cau.timefence_days                 cutoff_days
          ,paa.delivery_calendar              supplier_capacity_calendar
          ,paa.processing_lead_time           processing_lead_time
          ,psi.from_date                      from_date
          ,psi.to_date                        to_date
          ,psi.capacity_per_day               capacity_per_day
          ,pst.number_of_days                 days_in_advance
          ,pst.tolerance                      tolerance_percentage
          ,paa.min_order_qty                  minimum_order_quantity
          ,paa.fixed_lot_multiple             fixed_lot_multiple
          ,paa.enable_vmi_flag                vmi_enabled
          ,paa.enable_vmi_auto_replenish_flag automatic_allowed
          ,paa.vmi_replenishment_approval     approval
          ,paa.forecast_horizon               forecast_horizon_days
          ,paa.vmi_min_qty                    minimum_quantity
          ,paa.vmi_max_qty                    maximum_quantity
          ,paa.consigned_from_supplier_flag   consigned_from_supplier
          ,paa.consigned_billing_cycle        billing_cycle_days
          ,paa.consume_on_aging_flag          consume_on_aging BULK COLLECT
      INTO stage_table
      FROM po_asl_items_v             pai
          ,po_asl_suppliers_v         pas
          ,po_asl_attributes_v        paa
          ,po_asl_documents_v         pad
          ,chv_authorizations         cau
          ,po_supplier_item_capacity  psi
          ,po_supplier_item_tolerance pst
          ,ap_supplier_sites_all      aps
          ,hr_all_organization_units  hao
          ,mtl_parameters             mpt1
          ,mtl_parameters             mpt2
     WHERE ((pas.item_id = pai.item_id AND pas.item_id IS NOT NULL) OR
           (pas.commodity_id = pai.commodity_id AND pas.commodity_id IS NOT NULL))
       AND pai.using_organization_id = pas.using_organization_id
       AND pas.asl_id = paa.asl_id(+)
       AND pas.using_organization_id = paa.using_organization_id(+)
       AND pas.asl_id = pad.asl_id(+)
       AND pas.using_organization_id = pad.using_organization_id(+)
       AND pas.asl_id = cau.reference_id(+)
       AND pas.using_organization_id = cau.using_organization_id(+)
       AND pas.asl_id = psi.asl_id(+)
       AND pas.using_organization_id = psi.using_organization_id(+)
       AND pas.asl_id = pst.asl_id(+)
       AND pas.using_organization_id = pst.using_organization_id(+)
       AND pas.owning_organization_id = mpt1.organization_id(+)
       AND pas.using_organization_id = mpt2.organization_id(+)
       AND pas.vendor_id = aps.vendor_id(+)
       AND pas.vendor_site_id = aps.vendor_site_id(+)
       AND aps.org_id = hao.organization_id(+)
       AND (pas.disable_flag != 'Y' OR pas.disable_flag IS NULL)
       AND pas.owning_organization_id IN (739, 740);
    FORALL i IN stage_table.FIRST .. stage_table.LAST SAVE EXCEPTIONS
      INSERT INTO xxs3_ptp_asl
        (xx_asl_id
        ,date_extracted_on
        ,process_flag
        ,asl_id
        ,TYPE
        ,commodity
        ,item
        ,business
        ,supplier
        ,site
        ,operating_unit
        ,status
        ,disabled
        ,supplier_item
        ,manufacturer
        ,review_by
        ,global
        ,owning_org
        ,owning_organization_code
        ,using_organization_code
        ,comments
        ,global_local
        ,purchasing_uom
        ,release_method
        ,price_update_tolerance
        ,country_of_origin
        ,seq
        ,doc_type
        ,doc_number
        ,line
        ,enable_planning_schedules
        ,enable_shipping_schedules
        ,scheduler
        ,enable_auto_schedule
        ,enable_authorizations
        ,plan_bucket_pattern
        ,ship_bucket_pattern
        ,plan_schedule_type
        ,ship_schedule_type
        ,sequence
        ,authorization
        ,cutoff_days
        ,supplier_capacity_calendar
        ,processing_lead_time
        ,from_date
        ,to_date
        ,capacity_per_day
        ,days_in_advance
        ,tolerance_percentage
        ,minimum_order_quantity
        ,fixed_lot_multiple
        ,vmi_enabled
        ,automatic_allowed
        ,approval
        ,forecast_horizon_days
        ,minimum_quantity
        ,maximum_quantity
        ,consigned_from_supplier
        ,billing_cycle_days
        ,consume_on_aging)
      
      VALUES
        (xxs3_ptp_asl_seq.NEXTVAL
        ,SYSDATE
        ,'N'
        ,stage_table(i).asl_id
        ,stage_table(i).TYPE
        ,stage_table(i).commodity
        ,stage_table(i).item
        ,stage_table(i).business
        ,stage_table(i).supplier
        ,stage_table(i).site
        ,stage_table(i).operating_unit
        ,stage_table(i).status
        ,stage_table(i).disabled
        ,stage_table(i).supplier_item
        ,stage_table(i).manufacturer
        ,stage_table(i).review_by
        ,stage_table(i).global
        ,stage_table(i).owning_org
        ,stage_table(i).owning_organization_code
        ,stage_table(i).using_organization_code
        ,stage_table(i).comments
        ,stage_table(i).global_local
        ,stage_table(i).purchasing_uom
        ,stage_table(i).release_method
        ,stage_table(i).price_update_tolerance
        ,stage_table(i).country_of_origin
        ,stage_table(i).seq
        ,stage_table(i).doc_type
        ,stage_table(i).doc_number
        ,stage_table(i).line
        ,stage_table(i).enable_planning_schedules
        ,stage_table(i).enable_shipping_schedules
        ,stage_table(i).scheduler
        ,stage_table(i).enable_auto_schedule
        ,stage_table(i).enable_authorizations
        ,stage_table(i).plan_bucket_pattern
        ,stage_table(i).ship_bucket_pattern
        ,stage_table(i).plan_schedule_type
        ,stage_table(i).ship_schedule_type
        ,stage_table(i).sequence
        ,stage_table(i).authorization
        ,stage_table(i).cutoff_days
        ,stage_table(i).supplier_capacity_calendar
        ,stage_table(i).processing_lead_time
        ,stage_table(i).from_date
        ,stage_table(i).to_date
        ,stage_table(i).capacity_per_day
        ,stage_table(i).days_in_advance
        ,stage_table(i).tolerance_percentage
        ,stage_table(i).minimum_order_quantity
        ,stage_table(i).fixed_lot_multiple
        ,stage_table(i).vmi_enabled
        ,stage_table(i).automatic_allowed
        ,stage_table(i).approval
        ,stage_table(i).forecast_horizon_days
        ,stage_table(i).minimum_quantity
        ,stage_table(i).maximum_quantity
        ,stage_table(i).consigned_from_supplier
        ,stage_table(i).billing_cycle_days
        ,stage_table(i).consume_on_aging);
  
    quality_check_asl(l_err_code, l_err_msg);
  
    FOR j IN cur_transform LOOP
      IF j.owning_organization_code IS NOT NULL THEN
        xxs3_data_transform_util_pkg.transform(p_mapping_type          => 'inventory_org'
                                              ,p_stage_tab             => 'XXS3_PTP_ASL'
                                              , --Staging Table Name
                                               p_stage_primary_col     => 'XX_ASL_ID'
                                              , --Staging Table Primary Column Name
                                               p_stage_primary_col_val => j.xx_asl_id
                                              , --Staging Table Primary Column Value
                                               p_legacy_val            => j.owning_organization_code
                                              , --Legacy Value
                                               p_stage_col             => 'S3_OWNING_ORGANIZATION_CODE'
                                              , --Staging Table Name
                                               p_err_code              => l_err_code
                                              , -- Output error code
                                               p_err_msg               => l_err_msg);
      END IF;
      IF j.using_organization_code IS NOT NULL THEN
        xxs3_data_transform_util_pkg.transform(p_mapping_type          => 'inventory_org'
                                              ,p_stage_tab             => 'XXS3_PTP_ASL'
                                              , --Staging Table Name
                                               p_stage_primary_col     => 'XX_ASL_ID'
                                              , --Staging Table Primary Column Name
                                               p_stage_primary_col_val => j.xx_asl_id
                                              , --Staging Table Primary Column Value
                                               p_legacy_val            => j.using_organization_code
                                              , --Legacy Value
                                               p_stage_col             => 'S3_using_ORGANIZATION_CODE'
                                              , --Staging Table Name
                                               p_err_code              => l_err_code
                                              , -- Output error code
                                               p_err_msg               => l_err_msg);
      END IF;
      IF j.status IS NOT NULL THEN
      
        xxs3_data_transform_util_pkg.transform(p_mapping_type          => 'asl_status'
                                              ,p_stage_tab             => 'XXS3_PTP_ASL'
                                              , --Staging Table Name
                                               p_stage_primary_col     => 'XX_ASL_ID'
                                              , --Staging Table Primary Column Name
                                               p_stage_primary_col_val => j.xx_asl_id
                                              , --Staging Table Primary Column Value
                                               p_legacy_val            => j.status
                                              , --Legacy Value
                                               p_stage_col             => 'S3_STATUS'
                                              , --Staging Table Name
                                               p_err_code              => l_err_code
                                              , -- Output error code
                                               p_err_msg               => l_err_msg);
      END IF;
    END LOOP;
  
    /*dq_asl_report_data(l_err_code, l_err_msg);
    asl_report_data('ASL');*/
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      x_retcode := 2;
      x_errbuf  := 'Unexpected error in inserting Value to xxs3_ptp_asl.';
      log_p('Unexpected error in inserting Value to xxs3_ptp_asl Error: ' || SQLERRM);
      log_p(dbms_utility.format_error_backtrace);
  END asl_extract_data;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used for Approved Suppliers Transform Report
  --           
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build  
  -- --------------------------------------------------------------------------------------------

  PROCEDURE data_transform_report(p_entity VARCHAR2) IS
    CURSOR c_report_asl IS
      SELECT xpa.xx_asl_id
            ,xpa.asl_id
            ,xpa.owning_organization_code
            ,xpa.s3_owning_organization_code
            ,xpa.using_organization_code
            ,xpa.s3_using_organization_code
            ,xpa.status
            ,xpa.s3_status
            ,xpa.transform_status
            ,xpa.transform_error
        FROM xxs3_ptp_asl xpa
       WHERE xpa.transform_status IN ('PASS', 'FAIL');
    p_delimiter     VARCHAR2(5) := '~';
    l_err_msg       VARCHAR2(2000);
    l_count_success NUMBER;
    l_count_fail    NUMBER;
  BEGIN
  
    SELECT COUNT(1) INTO l_count_success FROM xxs3_ptp_asl xci WHERE xci.transform_status = 'PASS';
  
    SELECT COUNT(1) INTO l_count_fail FROM xxs3_ptp_asl xci WHERE xci.transform_status = 'FAIL';
  
    out_p(rpad('Report name = Data Transformation Report' || p_delimiter, 100, ' '));
    out_p(rpad('========================================' || p_delimiter, 100, ' '));
    out_p(rpad('Data Migration Object Name = ' || 'ASL' || p_delimiter, 100, ' '));
    out_p('');
    out_p(rpad('Run date and time:    ' || to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') || p_delimiter
              ,100
              ,' '));
    out_p(rpad('Total Record Count Success = ' || l_count_success || p_delimiter, 100, ' '));
    out_p(rpad('Total Record Count Failure = ' || l_count_fail || p_delimiter, 100, ' '));
  
    out_p('');
  
    out_p(rpad('Track Name', 10, ' ') || p_delimiter || rpad('Entity Name', 11, ' ') ||
          p_delimiter || rpad('XX ASL ID  ', 14, ' ') || p_delimiter || rpad('ASL ID', 10, ' ') ||
          p_delimiter || rpad('Owning Organization Code', 30, ' ') || p_delimiter ||
          rpad('S3 Owning Organization Code', 30, ' ') || p_delimiter ||
          rpad('Using Organization Code', 30, ' ') || p_delimiter ||
          rpad('S3 Using Organization Code', 30, ' ') || p_delimiter || rpad('Status', 10, ' ') ||
          p_delimiter || rpad('Error Message', 200, ' '));
  
    FOR r_data IN c_report_asl LOOP
      out_p(rpad('PTP', 10, ' ') || p_delimiter || rpad('ASL', 11, ' ') || p_delimiter ||
            rpad(r_data.xx_asl_id, 14, ' ') || p_delimiter || rpad(r_data.asl_id, 10, ' ') ||
            p_delimiter || rpad(r_data.owning_organization_code, 30, ' ') || p_delimiter ||
            rpad(r_data.s3_owning_organization_code, 30, ' ') || p_delimiter ||
            rpad(nvl(r_data.using_organization_code, 'NULL'), 30, ' ') || p_delimiter ||
            rpad(nvl(r_data.s3_using_organization_code, 'NULL'), 30, ' ') || p_delimiter ||
            rpad(r_data.transform_status, 10, ' ') || p_delimiter ||
            rpad(nvl(r_data.transform_error, 'NULL'), 200, ' '));
    END LOOP;
  
    fnd_file.put_line(fnd_file.output, '');
    fnd_file.put_line(fnd_file.output, 'Stratasys Confidential' || p_delimiter);
  END;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used to report the data quality error data
  --           
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build  
  -- --------------------------------------------------------------------------------------------

  PROCEDURE dq_asl_report_data(p_err_code OUT VARCHAR2
                              ,p_err_msg  OUT VARCHAR2) AS
    CURSOR c_report IS
      SELECT xps.xx_asl_id
            ,xps.TYPE
            ,decode(xps.TYPE, 'ITEM', xps.item, 'COMMODITY', xps.commodity) item_or_commodity
            ,xps.supplier
            ,xpa.rule_name
            ,xpa.notes
        FROM xxobjt.xxs3_ptp_asl    xps
            ,xxobjt.xxs3_ptp_asl_dq xpa
       WHERE xps.xx_asl_id = xpa.xx_asl_id
         AND xps.process_flag = 'Q'
       ORDER BY 1;
    p_delimiter VARCHAR2(5) := ';';
  BEGIN
    log_p('"Track Name","Entity Name","XX_ASL_ID","TYPE","ITEM/COMMODITY","SUPPLIER","RULE NAME","NOTES"');
  
    FOR i IN c_report LOOP
      log_p('PTP' || p_delimiter || 'ASL' || p_delimiter || i.xx_asl_id || p_delimiter || i.TYPE ||
            p_delimiter || i.item_or_commodity || p_delimiter || i.supplier || p_delimiter ||
            i.rule_name || p_delimiter || i.notes);
    END LOOP;
    log_p('!!END OF REPORT!!');
    p_err_code := '0';
    p_err_msg  := '';
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := '2';
      p_err_msg  := 'SQLERRM: ' || SQLERRM;
      log_p('Failed to generate report: ' || SQLERRM);
  END dq_asl_report_data;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used to report the DQ issues and to be rejected data
  --           
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build  
  -- --------------------------------------------------------------------------------------------

  PROCEDURE asl_report_data(p_entity_name IN VARCHAR2) AS
    CURSOR c_report IS
      SELECT xps.xx_asl_id
            ,xps.asl_id
            ,xps.TYPE
            ,decode(xps.TYPE, 'ITEM', xps.item, 'COMMODITY', xps.commodity) item_or_commodity
            ,xps.supplier
            ,xpa.rule_name
            ,xpa.notes
            ,decode(xps.process_flag, 'R', 'Y', 'Q', 'N') reject_record
        FROM xxobjt.xxs3_ptp_asl    xps
            ,xxobjt.xxs3_ptp_asl_dq xpa
       WHERE xps.xx_asl_id = xpa.xx_asl_id
         AND xps.process_flag IN ('Q', 'R')
       ORDER BY 1;
    p_delimiter VARCHAR2(5) := '~';
    l_count_dq     NUMBER;
    l_count_reject NUMBER;
  BEGIN
      SELECT COUNT(1)
      INTO l_count_dq
      FROM xxs3_ptp_asl xci
     WHERE xci.process_flag IN ('Q', 'R');
  
    SELECT COUNT(1)
      INTO l_count_reject
      FROM xxs3_ptp_asl xci
     WHERE xci.process_flag = 'R';
  
  
    out_p(rpad('Report name = Data Quality Error Report' || p_delimiter, 100, ' '));
    out_p(rpad('========================================' || p_delimiter, 100, ' '));
    out_p(rpad('Data Migration Object Name = ' || 'ASL' || p_delimiter, 100, ' '));
    out_p( '');
    out_p(rpad('Run date and time:    ' || to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') ||
                           p_delimiter
                          ,100
                          ,' '));
    out_p(rpad('Total Record Count Having DQ Issues = ' || l_count_dq || p_delimiter
                          ,100
                          ,' '));
    out_p(rpad('Total Record Count Rejected =  ' || l_count_reject || p_delimiter
                          ,100
                          ,' '));
  
    out_p('');

  
    out_p(rpad('Track Name', 10, ' ') || p_delimiter || rpad('Entity Name', 11, ' ') ||
          p_delimiter || rpad('XX ASL ID  ', 14, ' ') || p_delimiter || rpad('ASL ID', 10, ' ') ||p_delimiter ||
          rpad('Reject Record Flag(Y/N)', 25, ' ') || p_delimiter ||
          p_delimiter || rpad('Rule Name', 45, ' ') || p_delimiter || rpad('Reason Code', 50, ' '));
  
    FOR i IN c_report LOOP
      out_p(rpad('PTP', 10, ' ') || p_delimiter || rpad('ASL', 11, ' ') || p_delimiter ||
            rpad(i.xx_asl_id, 14, ' ') || p_delimiter || rpad(i.asl_id, 10, ' ') || p_delimiter ||
            rpad(i.reject_record, 25, ' ') || p_delimiter ||
            rpad(i.rule_name, 45, ' ') || p_delimiter || rpad(i.notes, 50, ' '));
    END LOOP;
    fnd_file.put_line(fnd_file.output, '');
    fnd_file.put_line(fnd_file.output, 'Stratasys Confidential' || p_delimiter);
    /* p_err_code := '0';
    p_err_msg  := '';*/
  EXCEPTION
    WHEN OTHERS THEN
      /* p_err_code := '2';
      p_err_msg  := 'SQLERRM: ' || SQLERRM;*/
      log_p('Failed to generate report: ' || SQLERRM);
  END asl_report_data;

  PROCEDURE asl_xml_report_data(x_errbuff OUT VARCHAR2
                               ,x_retcode OUT VARCHAR2) AS
    l_refcursor   SYS_REFCURSOR;
    l_xmltype     xmltype;
    l_xml_length  NUMBER;
    l_xml_len_tmp NUMBER := 0;
    l_buff_size   NUMBER := 0;
  
  BEGIN
    x_errbuff := 'SUCCESS';
    x_retcode := '0';
    OPEN l_refcursor FOR
      SELECT xps.xx_asl_id
            ,xps.asl_id
            ,xps.TYPE
            ,decode(xps.TYPE, 'ITEM', xps.item, 'COMMODITY', xps.commodity) item_or_commodity
            ,xps.supplier
            ,xpa.rule_name
            ,xpa.notes
        FROM xxobjt.xxs3_ptp_asl    xps
            ,xxobjt.xxs3_ptp_asl_dq xpa
       WHERE xps.xx_asl_id = xpa.xx_asl_id
         AND xps.process_flag IN ('Q', 'R')
       ORDER BY 1;
    /* p_delimiter VARCHAR2(5) := '~';*/
  
    ------------------------------------------
  
    --Generating XML from refcursor
    l_xmltype    := xmltype(l_refcursor);
    l_xml_length := dbms_lob.getlength(l_xmltype.getclobval);
    IF l_xml_length > 2000 THEN
      WHILE (l_xml_len_tmp < l_xml_length) LOOP
        l_buff_size := instr(l_xmltype.getclobval, '</ROW>', l_xml_len_tmp + 1) + 5 - l_xml_len_tmp;
        IF l_buff_size > 0 THEN
          fnd_file.put(fnd_file.output
                      ,substr(l_xmltype.getclobval, l_xml_len_tmp + 1, l_buff_size));
          l_xml_len_tmp := l_xml_len_tmp + l_buff_size;
        ELSE
          --Putting the XML in output file
          fnd_file.put_line(fnd_file.output, substr(l_xmltype.getclobval, l_xml_len_tmp + 1));
          l_xml_len_tmp := l_xml_length;
        END IF;
      END LOOP;
    ELSE
      --Putting the XML in output file
      fnd_file.put_line(fnd_file.output, l_xmltype.getclobval);
    END IF;
  
    -------------------------------------------------------------------                          
  
    /*out_p(rpad('ASL DQ status report', 100, ' '));
    out_p(rpad('=============================', 100, ' '));
    out_p('');
    out_p('Date:    ' || to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI'));
    
    out_p('');
    
    out_p(rpad('Track Name', 10, ' ') || p_delimiter || rpad('Entity Name', 11, ' ') ||
          p_delimiter || rpad('XX ASL ID  ', 14, ' ') || p_delimiter || rpad('ASL ID', 10, ' ') ||
          p_delimiter || rpad('Rule Name', 45, ' ') || p_delimiter ||
          rpad('Reject Reason', 50, ' '));
    
    FOR i IN c_report LOOP
      out_p(rpad('PTP', 10, ' ') || p_delimiter || rpad('ASL', 11, ' ') || p_delimiter ||
            rpad(i.xx_asl_id, 14, ' ') || p_delimiter || rpad(i.asl_id, 10, ' ') || p_delimiter ||
            rpad(i.rule_name, 45, ' ') || p_delimiter || rpad(i.notes, 50, ' '));
    END LOOP;*/
    CLOSE l_refcursor;
  EXCEPTION
    WHEN OTHERS THEN
      CLOSE l_refcursor;
      log_p('Failed to generate report: ' || SQLERRM);
      x_errbuff := 'ERROR' || SQLERRM || dbms_utility.format_error_backtrace;
      x_retcode := '2';
      fnd_file.put_line(fnd_file.log, 'Unexpected Error :' || SQLERRM);
      fnd_file.put_line(fnd_file.log, 'Unexpected Error :' || dbms_utility.format_error_backtrace);
  END asl_xml_report_data;

END xxs3_ptp_asl_pkg;
/
