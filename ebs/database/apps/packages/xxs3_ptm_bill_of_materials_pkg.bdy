CREATE OR REPLACE PACKAGE BODY xxs3_ptm_bill_of_materials_pkg

-- --------------------------------------------------------------------------------------------
-- Purpose: This Package is used for Bills Of Material Extract, Quality Check and Report
--
-- --------------------------------------------------------------------------------------------
-- Ver  Date        Name                          Description
-- 1.0  18/05/2016  Santanu                           Initial build
-- --------------------------------------------------------------------------------------------

 AS

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used to write in concurrent log
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  Santanu                           Initial build
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
  -- 1.0  18/05/2016  Santanu                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE out_p(p_msg VARCHAR2) IS
  BEGIN

    fnd_file.put_line(fnd_file.output, p_msg);
   /* dbms_output.put_line(p_msg);*/

  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log, 'Error in writting Output File. ' || SQLERRM);
  END out_p;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used to Update process flag and Quality Check Result
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  Santanu                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE insert_update_bom_dq(p_xx_bom_id   NUMBER
                                ,p_rule_name   IN VARCHAR2
                                ,p_reject_code IN VARCHAR2
                                ,p_err_code    OUT VARCHAR2
                                ,p_err_msg     OUT VARCHAR2) IS

  BEGIN
  /* Update process flag as Q for the DQ records */

    UPDATE xxobjt.xxs3_ptm_bill_of_materials
	SET process_flag = 'Q'
	WHERE xx_bom_id = p_xx_bom_id;

  /* Insert DQ records details in the dq table */
    INSERT INTO xxs3_ptm_bill_of_materials_dq
      (xx_dq_bom_id
      ,xx_bom_id
      ,rule_name
      ,notes)
    VALUES
      (xxs3_ptm_bill_of_mat_dq_seq.NEXTVAL
      ,p_xx_bom_id
      ,p_rule_name
      ,p_reject_code);

    p_err_code := '0';
    p_err_msg  := '';

  EXCEPTION
    WHEN OTHERS THEN
      p_err_code := '2';
      p_err_msg  := 'SQLERRM: ' || SQLERRM;
      ROLLBACK;

  END insert_update_bom_dq;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used to cleanse Supply Type
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  Santanu                        Initial build
  -- --------------------------------------------------------------------------------------------
  /*
    PROCEDURE cleanse_supply_type(p_xx_bom_id             NUMBER,
                                  p_component_item_number VARCHAR2,
                                  p_organization_code     VARCHAR2,
                                  p_supply_type           NUMBER) IS
      l_count       NUMBER := 0;
      l_err_message VARCHAR2(1000);
    BEGIN
      IF p_supply_type IS NOT NULL THEN
        SELECT COUNT(1)
        INTO   l_count
        FROM   mtl_system_items_b msi,
               mtl_parameters     mpt
        WHERE  msi.segment1 = p_component_item_number
        AND    msi.organization_id = mpt.organization_id
        AND    mpt.organization_code = p_organization_code
        AND    nvl(wip_supply_type, -99) = p_supply_type;
      END IF;
      IF l_count != 0 THEN
        BEGIN
          UPDATE xxobjt.xxs3_ptm_bill_of_materials
          SET    s3_c_supply_type = NULL,
                 cleanse_status   = cleanse_status || ' SUPPLY_TYPE :PASS, '
          WHERE  xx_bom_id = p_xx_bom_id;
        EXCEPTION
          WHEN OTHERS THEN
            l_err_message := SQLERRM;
            UPDATE xxobjt.xxs3_ptm_bill_of_materials
            SET    cleanse_status = cleanse_status || ' SUPPLY_TYPE :FAIL, ',
                   cleanse_error  = cleanse_error || ' SUPPLY_TYPE :' ||
                                    l_err_message || ' ,'
            WHERE  xx_bom_id = p_xx_bom_id;
        END;
      ELSE
        BEGIN
          UPDATE xxobjt.xxs3_ptm_bill_of_materials
          SET    s3_c_supply_type = p_supply_type,
                 cleanse_status   = cleanse_status || ' SUPPLY_TYPE :PASS, '
          WHERE  xx_bom_id = p_xx_bom_id;
        EXCEPTION
          WHEN OTHERS THEN
            l_err_message := SQLERRM;
            UPDATE xxobjt.xxs3_ptm_bill_of_materials
            SET    cleanse_status = cleanse_status || ' SUPPLY_TYPE :FAIL, ',
                   cleanse_error  = cleanse_error || ' SUPPLY_TYPE :' ||
                                    l_err_message || ' ,'
            WHERE  xx_bom_id = p_xx_bom_id;
        END;
      END IF;
    END;
  */
  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used to cleanse Common Organization
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  /*  PROCEDURE cleanse_common_organization(p_xx_bom_id                NUMBER,
                                        p_common_organization_code VARCHAR2) IS
    l_count       NUMBER := 0;
    l_err_message VARCHAR2(1000);
  BEGIN
    IF p_common_organization_code != 'GIM' OR
       p_common_organization_code IS NULL THEN

      BEGIN
        UPDATE xxobjt.xxs3_ptm_bill_of_materials
        SET    s3_h_common_organization_code = 'GIM',
               cleanse_status                = cleanse_status ||
                                               ' COMMON_ORGANIZATION_CODE :PASS, '
        WHERE  xx_bom_id = p_xx_bom_id;
      EXCEPTION
        WHEN OTHERS THEN
          l_err_message := SQLERRM;
          UPDATE xxobjt.xxs3_ptm_bill_of_materials
          SET    cleanse_status = cleanse_status ||
                                  ' COMMON_ORGANIZATION_CODE :FAIL, ',
                 cleanse_error  = cleanse_error ||
                                  ' COMMON_ORGANIZATION_CODE :' ||
                                  l_err_message || ' ,'
          WHERE  xx_bom_id = p_xx_bom_id;
      END;
    END IF;
  END;*/

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used to cleanse BOM
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  Santanu                        Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE cleanse_bom(p_err_code OUT VARCHAR2
                       ,p_err_msg  OUT VARCHAR2) IS
    l_status     VARCHAR2(10) := 'SUCCESS';
    l_check_rule VARCHAR2(10) := 'TRUE';
    /*CURSOR cur_bom IS
    SELECT *
    FROM   xxobjt.xxs3_ptm_bill_of_materials;*/
  BEGIN
  /* Cleanse rule update for the s3_h_common_organization_code attribute */

    UPDATE xxobjt.xxs3_ptm_bill_of_materials
       SET s3_h_common_organization_code = 'GIM'
          ,s3_c_supply_type              = NULL
          ,cleanse_status                = 'PASS';
    /* FOR i IN cur_bom LOOP
      cleanse_supply_type(i.xx_bom_id, i.c_component_item_number, i.h_organization_code, i.c_supply_type);

      cleanse_common_organization(i.xx_bom_id, i.h_common_organization_code);
    END LOOP;*/
    COMMIT;
  END;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used to qality check BOM
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  Santanu                       Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE quality_check_bom(p_err_code OUT VARCHAR2
                             ,p_err_msg  OUT VARCHAR2) IS
    l_status     VARCHAR2(10) := 'SUCCESS';
    l_check_rule VARCHAR2(10) := 'TRUE';

    CURSOR c_bom IS
      SELECT *
	  FROM xxobjt.xxs3_ptm_bill_of_materials
	  WHERE process_flag = 'N';
  BEGIN

  /* Quality Check section */

    FOR i IN c_bom LOOP
      l_status := 'SUCCESS';
      --SUPPLY_SUBINVENTORY
      IF xxs3_dq_util_pkg.eqt_030(i.c_supply_subinventory) THEN
        insert_update_bom_dq(i.xx_bom_id
                            ,'EQT_030:Should be NULL'
                            ,'SUPPLY_SUBINVENTORY Should be NULL'
                            ,p_err_code
                            ,p_err_msg);
        l_status := 'ERR';
      END IF;
      --LOCATOR
      IF xxs3_dq_util_pkg.eqt_030(i.c_locator) THEN
        insert_update_bom_dq(i.xx_bom_id
                            ,'EQT_030:Should be NULL'
                            ,'LOCATOR Should be NULL'
                            ,p_err_code
                            ,p_err_msg);
        l_status := 'ERR';
      END IF;
      IF l_status <> 'ERR' THEN

	  /* Update process flag for records as Y*/

        UPDATE xxobjt.xxs3_ptm_bill_of_materials
           SET process_flag = 'Y'
         WHERE xx_bom_id = i.xx_bom_id;
      END IF;
    END LOOP;
  END;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is for Cleanse Report
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  Santanu                       Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE data_cleanse_report(p_entity VARCHAR2) IS
  /* Variables */

    p_delimiter     VARCHAR2(5) := '~';
    l_err_msg       VARCHAR2(2000);
    l_count_success NUMBER;
    l_count_fail    NUMBER;

  /* Cleanse cursor */

    CURSOR c_report_bom IS
      SELECT xpb.xx_bom_id
            ,xpb.h_assembly_item_number
            ,xpb.c_component_item_number
            ,xpb.h_common_organization_code
            ,xpb.s3_h_common_organization_code
            ,xpb.c_supply_type
            ,xpb.s3_c_supply_type
            ,xpb.cleanse_status
            ,xpb.cleanse_error
        FROM xxs3_ptm_bill_of_materials xpb
       WHERE xpb.cleanse_status LIKE '%PASS%'
          OR xpb.cleanse_status LIKE '%FAIL%';


  BEGIN
  /* Count for Success Records */

    SELECT COUNT(1)
      INTO l_count_success
      FROM xxs3_ptm_bill_of_materials xpb
     WHERE xpb.cleanse_status LIKE '%PASS%';

  /* Count for Fail Records */
    SELECT COUNT(1)
      INTO l_count_fail
      FROM xxs3_ptm_bill_of_materials xpb
     WHERE xpb.cleanse_status LIKE '%FAIL%';

  /* Report generation section */

    out_p(rpad('Report name = Automated Cleanse & Standardize Report' || p_delimiter, 100, ' '));
    out_p(rpad('====================================================' || p_delimiter, 100, ' '));
    out_p(rpad('Data Migration Object Name = ' || 'BOM' || p_delimiter, 100, ' '));
    out_p('');
    out_p(rpad('Run date and time:    ' || to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') || p_delimiter
              ,100
              ,' '));
    out_p(rpad('Total Record Count Success = ' || l_count_success || p_delimiter, 100, ' '));
    out_p(rpad('Total Record Count Failure = ' || l_count_fail || p_delimiter, 100, ' '));

    out_p('');

    out_p(rpad('Track Name', 10, ' ') || p_delimiter || rpad('Entity Name', 11, ' ') ||
          p_delimiter || rpad('XX BOM ID  ', 14, ' ') || p_delimiter ||
          rpad('Assembly Item Number', 30, ' ') || p_delimiter ||
          rpad('Component Item Number', 30, ' ') || p_delimiter ||
          rpad('Common Organization Code', 30, ' ') || p_delimiter ||
          rpad('S3 Common Organization Code', 30, ' ') || p_delimiter ||
          rpad('Supply Type', 30, ' ') || p_delimiter || rpad('S3 Supply Type', 30, ' ') ||
          p_delimiter || rpad('Status', 10, ' ') || p_delimiter || rpad('Error Message', 200, ' '));

    FOR r_data IN c_report_bom LOOP
      out_p(rpad('PTM', 10, ' ') || p_delimiter || rpad('BOM', 11, ' ') || p_delimiter ||
            rpad(r_data.xx_bom_id, 14, ' ') || p_delimiter ||
            rpad(r_data.h_assembly_item_number, 30, ' ') || p_delimiter ||
            rpad(r_data.c_component_item_number, 30, ' ') || p_delimiter ||
            rpad(r_data.h_common_organization_code, 30, ' ') || p_delimiter ||
            rpad(r_data.s3_h_common_organization_code, 30, ' ') || p_delimiter ||
            rpad(NVL(r_data.c_supply_type,-999), 30, ' ') || p_delimiter ||
            rpad(nvl(r_data.s3_c_supply_type,-999), 30, ' ') || p_delimiter ||
            rpad(r_data.cleanse_status, 10, ' ') || p_delimiter ||
            rpad(nvl(r_data.cleanse_error, 'NULL'), 200, ' '));

    END LOOP;

    fnd_file.put_line(fnd_file.output, '');
    fnd_file.put_line(fnd_file.output, 'Stratasys Confidential' || p_delimiter);
  END;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used to BOM extract data
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  Santanu                           Initial build
  -- 1.1  06/01/2017  Sateesh                        Commented  bom_enabled_flag = 'Y'              
  -- --------------------------------------------------------------------------------------------

  PROCEDURE bill_of_materials_extract_data(x_errbuf  OUT VARCHAR2
                                          ,x_retcode OUT NUMBER
                                          /*,p_orgcode IN VARCHAR2*/) AS
    l_err_code NUMBER;
    l_err_msg  VARCHAR2(1000);

  /* Cursor for transform */

    CURSOR cur_transform IS
      SELECT xx_bom_id
            ,h_organization_code
            ,h_common_organization_code
        FROM xxs3_ptm_bill_of_materials
       WHERE process_flag IN ('Y', 'Q');

  /* Main Cursor for BOM Extract */
    CURSOR cur_bill_of_materials IS
SELECT DISTINCT msi.segment1 h_assembly_item_number,
                mpt.organization_id,
                mpt.organization_code h_organization_code,
                mir.revision h_revision,
                bbm.alternate_bom_designator h_alternate_bom_designator,
                msi1.segment1 h_common_assembly_item_name,
                bbm.specific_assembly_comment h_specific_assembly_comment,
                bbm.assembly_type h_assembly_type,
                mpt1.organization_code h_common_organization_code,
                bbm.effectivity_control h_effectivity_control,
                bbm.attribute_category h_attribute_category,
                bbm.attribute1 h_attribute1,
                bbm.attribute2 h_attribute2,
                bbm.attribute3 h_attribute3,
                bbm.attribute4 h_attribute4,
                bbm.attribute5 h_attribute5,
                bbm.attribute6 h_attribute6,
                bbm.attribute7 h_attribute7,
                bbm.attribute8 h_attribute8,
                bbm.attribute9 h_attribute9,
                bbm.attribute10 h_attribute10,
                bbm.attribute11 h_attribute11,
                bbm.attribute12 h_attribute12,
                bbm.attribute13 h_attribute13,
                bbm.attribute14 h_attribute14,
                bbm.attribute15 h_attribute15,
                bic.item_num c_item_num,
                bic.operation_seq_num c_operation_seq_num,
                msi2.inventory_item_id,
                msi2.segment1 c_component_item_number,
                bic.basis_type c_basis_type,
                bic.component_quantity c_component_quantity,
                bic.eng_item_flag c_eng_item_flag,
                bic.auto_request_material c_auto_request_material,
                bic.effectivity_date c_from_date,
                bic.disable_date c_to_date,
                bic.planning_factor c_planning_factor,
                bic.component_yield_factor c_component_yield_factor,
                bic.enforce_int_requirements_desc c_enforce_int_requirement_desc,
                bic.include_in_cost_rollup c_include_in_cost_rollup,
                bic.wip_supply_type c_supply_type,
                bic.supply_subinventory c_supply_subinventory,
                bic.supply_locator_id c_locator,
                bic.check_atp c_check_atp,
                bic.optional c_optional,
                bic.mutually_exclusive_options c_mutually_exclusive_options,
                bic.low_quantity c_low_quantity,
                bic.high_quantity c_high_quantity,
                bic.so_basis c_so_basis,
                bic.shipping_allowed c_shippable_item_flag,
                bic.include_on_ship_docs c_include_on_ship_docs,
                bic.required_to_ship c_required_to_ship,
                bic.required_for_revenue c_required_for_revenue,
                bic.component_remarks c_component_remarks,
                bic.attribute_category c_attribute_category,
                bic.attribute1 c_attribute1,
                bic.attribute2 c_attribute2,
                bic.attribute3 c_attribute3,
                bic.attribute4 c_attribute4,
                bic.attribute5 c_attribute5,
                bic.attribute6 c_attribute6,
                bic.attribute7 c_attribute7,
                bic.attribute8 c_attribute8,
                bic.attribute9 c_attribute9,
                bic.attribute10 c_attribute10,
                bic.attribute11 c_attribute11,
                bic.attribute12 c_attribute12,
                bic.attribute13 c_attribute13,
                bic.attribute14 c_attribute14,
                bic.attribute15 c_attribute15
  FROM bom_bill_of_materials      bbm,
       mtl_system_items_b         msi,
       mtl_system_items_b         msi1,
       mtl_system_items_b         msi2,
       mtl_parameters             mpt,
       mtl_parameters             mpt1,
       mtl_item_revisions         mir,
       bom_inventory_components_v bic
 WHERE bbm.bill_sequence_id = bbm.source_bill_sequence_id /*extract rule seq 110 */
   AND msi2.segment1 NOT LIKE '%WARRANTY%'
   AND bbm.assembly_item_id = msi.inventory_item_id
   AND bbm.organization_id = msi.organization_id
      --    AND msi.bom_enabled_flag = 'Y'              --Commented by Sateesh As per 01-Jan-17 Fdd update
   AND bbm.organization_id = mpt.organization_id
   AND mir.inventory_item_id = msi.inventory_item_id
   AND mir.organization_id = msi.organization_id
   AND mir.revision =
       (SELECT MAX(mir1.revision)
          FROM mtl_item_revisions mir1
         WHERE mir1.inventory_item_id = bbm.assembly_item_id
           AND mir1.organization_id = bbm.organization_id)
   AND bbm.common_assembly_item_id = msi1.inventory_item_id(+)
   AND bbm.organization_id = msi1.organization_id(+)
   AND bbm.common_organization_id = mpt1.organization_id(+)
   AND bic.bill_sequence_id = bbm.bill_sequence_id
   AND bic.component_item_id = msi2.inventory_item_id
   AND bbm.organization_id = msi2.organization_id
   AND mpt.organization_code IN ('OMA', 'UME', 'IPK', 'IRK', 'WPI')
      -----Extract Rule Sequence-0 Scope of items -- Change made on 28-12-16---
   AND EXISTS (SELECT 1
          FROM xxs3_ptm_master_items_ext_stg xpmies
         WHERE xpmies.segment1 = msi.segment1
              --AND xpmies.legacy_organization_code = mpt.organization_code
           AND xpmies.extract_rule_name IS NOT NULL
           AND xpmies.process_flag <> 'R')
UNION
SELECT DISTINCT msi.segment1 h_assembly_item_number,
                mpt.organization_id,
                mpt.organization_code h_organization_code,
                mir.revision h_revision,
                bbm.alternate_bom_designator h_alternate_bom_designator,
                msi1.segment1 h_common_assembly_item_name,
                bbm.specific_assembly_comment h_specific_assembly_comment,
                bbm.assembly_type h_assembly_type,
                mpt1.organization_code h_common_organization_code,
                bbm.effectivity_control h_effectivity_control,
                bbm.attribute_category h_attribute_category,
                bbm.attribute1 h_attribute1,
                bbm.attribute2 h_attribute2,
                bbm.attribute3 h_attribute3,
                bbm.attribute4 h_attribute4,
                bbm.attribute5 h_attribute5,
                bbm.attribute6 h_attribute6,
                bbm.attribute7 h_attribute7,
                bbm.attribute8 h_attribute8,
                bbm.attribute9 h_attribute9,
                bbm.attribute10 h_attribute10,
                bbm.attribute11 h_attribute11,
                bbm.attribute12 h_attribute12,
                bbm.attribute13 h_attribute13,
                bbm.attribute14 h_attribute14,
                bbm.attribute15 h_attribute15,
                bic.item_num c_item_num,
                bic.operation_seq_num c_operation_seq_num,
                msi2.inventory_item_id,
                msi2.segment1 c_component_item_number,
                bic.basis_type c_basis_type,
                bic.component_quantity c_component_quantity,
                bic.eng_item_flag c_eng_item_flag,
                bic.auto_request_material c_auto_request_material,
                bic.effectivity_date c_from_date,
                bic.disable_date c_to_date,
                bic.planning_factor c_planning_factor,
                bic.component_yield_factor c_component_yield_factor,
                bic.enforce_int_requirements_desc c_enforce_int_requirement_desc,
                bic.include_in_cost_rollup c_include_in_cost_rollup,
                bic.wip_supply_type c_supply_type,
                bic.supply_subinventory c_supply_subinventory,
                bic.supply_locator_id c_locator,
                bic.check_atp c_check_atp,
                bic.optional c_optional,
                bic.mutually_exclusive_options c_mutually_exclusive_options,
                bic.low_quantity c_low_quantity,
                bic.high_quantity c_high_quantity,
                bic.so_basis c_so_basis,
                bic.shipping_allowed c_shippable_item_flag,
                bic.include_on_ship_docs c_include_on_ship_docs,
                bic.required_to_ship c_required_to_ship,
                bic.required_for_revenue c_required_for_revenue,
                bic.component_remarks c_component_remarks,
                bic.attribute_category c_attribute_category,
                bic.attribute1 c_attribute1,
                bic.attribute2 c_attribute2,
                bic.attribute3 c_attribute3,
                bic.attribute4 c_attribute4,
                bic.attribute5 c_attribute5,
                bic.attribute6 c_attribute6,
                bic.attribute7 c_attribute7,
                bic.attribute8 c_attribute8,
                bic.attribute9 c_attribute9,
                bic.attribute10 c_attribute10,
                bic.attribute11 c_attribute11,
                bic.attribute12 c_attribute12,
                bic.attribute13 c_attribute13,
                bic.attribute14 c_attribute14,
                bic.attribute15 c_attribute15
  FROM bom_bill_of_materials      bbm,
       mtl_system_items_b         msi,
       mtl_system_items_b         msi1,
       mtl_system_items_b         msi2,
       mtl_parameters             mpt,
       mtl_parameters             mpt1,
       mtl_item_revisions         mir,
       bom_inventory_components_v bic
 WHERE bbm.bill_sequence_id = bbm.source_bill_sequence_id /*extract rule seq 110 */
   AND bbm.bill_sequence_id IN
       (SELECT bbm.bill_sequence_id
          FROM bom_bill_of_materials bbm,
               mtl_parameters        mpt,
               mtl_item_categories_v mic
         WHERE bbm.organization_id = mpt.organization_id
           AND mpt.organization_code IN ('UME', 'USE')
           AND mic.inventory_item_id = bbm.assembly_item_id
           AND bbm.organization_id = mic.organization_id
           AND mic.category_set_name = 'Product Hierarchy'
           AND mic.segment6 IN ('Common', 'FDM', 'Unassigned')
           AND mpt.organization_code IN ('OMA', 'UME', 'IPK', 'IRK') --= p_orgcode
        UNION
        SELECT bbm.bill_sequence_id
          FROM bom_bill_of_materials bbm,
               mtl_parameters        mpt,
               mtl_item_categories_v mic
         WHERE bbm.organization_id = mpt.organization_id
           AND mpt.organization_code IN ('UTP', 'IPK', 'IRK')
           AND mic.inventory_item_id = bbm.assembly_item_id
           AND bbm.organization_id = mic.organization_id
           AND mic.category_set_name = 'Product Hierarchy'
           AND mic.segment6 IN ('Common', 'POLYJET', 'Unassigned')
           AND mpt.organization_code IN ('OMA', 'UME', 'IPK', 'IRK') --= p_orgcode
        UNION
        SELECT bbm.bill_sequence_id
          FROM bom_bill_of_materials bbm, mtl_parameters mpt
         WHERE bbm.organization_id = mpt.organization_id
           AND mpt.organization_code = 'OMA'
           AND mpt.organization_code IN ('OMA', 'UME', 'IPK', 'IRK')) --= p_orgcode)
   AND msi2.segment1 NOT LIKE '%WARRANTY%'
   AND bbm.assembly_item_id = msi.inventory_item_id
   AND bbm.organization_id = msi.organization_id
      --    AND msi.bom_enabled_flag = 'Y'              --Commented by Sateesh As per 01-Jan-17 Fdd update
   AND bbm.organization_id = mpt.organization_id
   AND mir.inventory_item_id = msi.inventory_item_id
   AND mir.organization_id = msi.organization_id
   AND mir.revision =
       (SELECT MAX(mir1.revision)
          FROM mtl_item_revisions mir1
         WHERE mir1.inventory_item_id = bbm.assembly_item_id
           AND mir1.organization_id = bbm.organization_id)
   AND bbm.common_assembly_item_id = msi1.inventory_item_id(+)
   AND bbm.organization_id = msi1.organization_id(+)
   AND bbm.common_organization_id = mpt1.organization_id(+)
   AND bic.bill_sequence_id = bbm.bill_sequence_id
   AND bic.component_item_id = msi2.inventory_item_id
   AND bbm.organization_id = msi2.organization_id
      -----Extract Rule Sequence-0 Scope of items -- Change made on 28-12-16---
   AND EXISTS (SELECT 1
          FROM xxs3_ptm_master_items_ext_stg xpmies
         WHERE xpmies.segment1 = msi.segment1
              --AND xpmies.legacy_organization_code = mpt.organization_code
           AND xpmies.extract_rule_name IS NOT NULL
           AND xpmies.process_flag <> 'R');
          
    --Below query backup -10 jan 17
      /*SELECT DISTINCT msi.segment1 h_assembly_item_number
                     ,mpt.organization_id
                     ,mpt.organization_code h_organization_code
                     ,mir.revision h_revision
                     ,bbm.alternate_bom_designator h_alternate_bom_designator
                     ,msi1.segment1 h_common_assembly_item_name
                     ,bbm.specific_assembly_comment h_specific_assembly_comment
                     ,bbm.assembly_type h_assembly_type
                     ,mpt1.organization_code h_common_organization_code
                     ,bbm.effectivity_control h_effectivity_control
                     ,bbm.attribute_category h_attribute_category
                     ,bbm.attribute1 h_attribute1
                     ,bbm.attribute2 h_attribute2
                     ,bbm.attribute3 h_attribute3
                     ,bbm.attribute4 h_attribute4
                     ,bbm.attribute5 h_attribute5
                     ,bbm.attribute6 h_attribute6
                     ,bbm.attribute7 h_attribute7
                     ,bbm.attribute8 h_attribute8
                     ,bbm.attribute9 h_attribute9
                     ,bbm.attribute10 h_attribute10
                     ,bbm.attribute11 h_attribute11
                     ,bbm.attribute12 h_attribute12
                     ,bbm.attribute13 h_attribute13
                     ,bbm.attribute14 h_attribute14
                     ,bbm.attribute15 h_attribute15
                     ,bic.item_num c_item_num
                     ,bic.operation_seq_num c_operation_seq_num
                     ,msi2.inventory_item_id
                     ,msi2.segment1 c_component_item_number
                     ,bic.basis_type c_basis_type
                     ,bic.component_quantity c_component_quantity
                     ,bic.eng_item_flag c_eng_item_flag
                     ,bic.auto_request_material c_auto_request_material
                     ,bic.effectivity_date c_from_date
                     ,bic.disable_date c_to_date
                     ,bic.planning_factor c_planning_factor
                     ,bic.component_yield_factor c_component_yield_factor
                     ,bic.enforce_int_requirements_desc c_enforce_int_requirement_desc
                     ,bic.include_in_cost_rollup c_include_in_cost_rollup
                     ,bic.wip_supply_type c_supply_type
                     ,bic.supply_subinventory c_supply_subinventory
                     ,bic.supply_locator_id c_locator
                     ,bic.check_atp c_check_atp
                     ,bic.optional c_optional
                     ,bic.mutually_exclusive_options c_mutually_exclusive_options
                     ,bic.low_quantity c_low_quantity
                     ,bic.high_quantity c_high_quantity
                     ,bic.so_basis c_so_basis
                     ,bic.shipping_allowed c_shippable_item_flag
                     ,bic.include_on_ship_docs c_include_on_ship_docs
                     ,bic.required_to_ship c_required_to_ship
                     ,bic.required_for_revenue c_required_for_revenue
                     ,bic.component_remarks c_component_remarks
                     ,bic.attribute_category c_attribute_category
                     ,bic.attribute1 c_attribute1
                     ,bic.attribute2 c_attribute2
                     ,bic.attribute3 c_attribute3
                     ,bic.attribute4 c_attribute4
                     ,bic.attribute5 c_attribute5
                     ,bic.attribute6 c_attribute6
                     ,bic.attribute7 c_attribute7
                     ,bic.attribute8 c_attribute8
                     ,bic.attribute9 c_attribute9
                     ,bic.attribute10 c_attribute10
                     ,bic.attribute11 c_attribute11
                     ,bic.attribute12 c_attribute12
                     ,bic.attribute13 c_attribute13
                     ,bic.attribute14 c_attribute14
                     ,bic.attribute15 c_attribute15
        FROM bom_bill_of_materials      bbm
            ,mtl_system_items_b         msi
            ,mtl_system_items_b         msi1
            ,mtl_system_items_b         msi2
            ,mtl_parameters             mpt
            ,mtl_parameters             mpt1
            ,mtl_item_revisions         mir
            ,bom_inventory_components_v bic
       WHERE bbm.bill_sequence_id = bbm.source_bill_sequence_id \*extract rule seq 110 *\
         AND bbm.bill_sequence_id IN
             (SELECT bbm.bill_sequence_id
                FROM bom_bill_of_materials bbm
                    ,mtl_parameters        mpt
                    ,mtl_item_categories_v mic
               WHERE bbm.organization_id = mpt.organization_id
                 AND mpt.organization_code IN ('UME', 'USE')
                 AND mic.inventory_item_id = bbm.assembly_item_id
                 AND bbm.organization_id = mic.organization_id
                 AND mic.category_set_name = 'Product Hierarchy'
                 AND mic.segment6 IN ('Common', 'FDM', 'Unassigned')
                 AND mpt.organization_code IN('OMA','UME','IPK','IRK')--= p_orgcode
              UNION
              SELECT bbm.bill_sequence_id
                FROM bom_bill_of_materials bbm
                    ,mtl_parameters        mpt
                    ,mtl_item_categories_v mic
               WHERE bbm.organization_id = mpt.organization_id
                 AND mpt.organization_code IN ('UTP', 'IPK', 'IRK')
                 AND mic.inventory_item_id = bbm.assembly_item_id
                 AND bbm.organization_id = mic.organization_id
                 AND mic.category_set_name = 'Product Hierarchy'
                 AND mic.segment6 IN ('Common', 'POLYJET', 'Unassigned')
                 AND mpt.organization_code IN('OMA','UME','IPK','IRK')--= p_orgcode
              UNION
              SELECT bbm.bill_sequence_id
                FROM bom_bill_of_materials bbm
                    ,mtl_parameters        mpt
               WHERE bbm.organization_id = mpt.organization_id
                 AND mpt.organization_code = 'OMA'
                 AND mpt.organization_code IN('OMA','UME','IPK','IRK'))--= p_orgcode)
         AND msi2.segment1 NOT LIKE '%WARRANTY%'
         AND bbm.assembly_item_id = msi.inventory_item_id
         AND bbm.organization_id = msi.organization_id
     --    AND msi.bom_enabled_flag = 'Y'              --Commented by Sateesh As per 01-Jan-17 Fdd update
         AND bbm.organization_id = mpt.organization_id
         AND mir.inventory_item_id = msi.inventory_item_id
         AND mir.organization_id = msi.organization_id
         AND mir.revision = (SELECT MAX(mir1.revision)
                               FROM mtl_item_revisions mir1
                              WHERE mir1.inventory_item_id = bbm.assembly_item_id
                                AND mir1.organization_id = bbm.organization_id)
         AND bbm.common_assembly_item_id = msi1.inventory_item_id(+)
         AND bbm.organization_id = msi1.organization_id(+)
         AND bbm.common_organization_id = mpt1.organization_id(+)
         AND bic.bill_sequence_id = bbm.bill_sequence_id
         AND bic.component_item_id = msi2.inventory_item_id
         AND bbm.organization_id = msi2.organization_id
         -----Extract Rule Sequence-0 Scope of items -- Change made on 28-12-16---
         AND EXISTS
         (SELECT 1
          FROM xxs3_ptm_master_items_ext_stg xpmies
         WHERE xpmies.segment1 = msi.segment1
           --AND xpmies.legacy_organization_code = mpt.organization_code
           AND xpmies.extract_rule_name IS NOT NULL
           AND xpmies.process_flag <> 'R');*/
         -------------------------------------------------------------------------
        
    --l_file utl_file.file_type;
  BEGIN
    --l_file := utl_file.fopen('/UtlFiles/shared/DEV', 'ptm_bom_extract_25_08_2016.XLS', 'w', 32767);

	/* Delete the records form stage table before insert */

    DELETE FROM xxobjt.xxs3_ptm_bill_of_materials;
    DELETE FROM xxobjt.xxs3_ptm_bill_of_materials_dq;

	/* Insert the records into stage table */
    FOR i IN cur_bill_of_materials LOOP
      INSERT INTO xxobjt.xxs3_ptm_bill_of_materials
        (xx_bom_id
        ,data_extracted_on
        ,process_flag
        ,h_assembly_item_number
        ,h_organization_code
         /*,s3_h_organization_code*/
        ,h_revision
        ,h_alternate_bom_designator
        ,h_common_assembly_item_name
        ,h_specific_assembly_comment
        ,h_assembly_type
        ,h_common_organization_code
         /*,s3_h_common_organization_code*/
        ,h_effectivity_control
        ,h_attribute_category
        ,h_attribute1
        ,h_attribute2
        ,h_attribute3
        ,h_attribute4
        ,h_attribute5
        ,h_attribute6
        ,h_attribute7
        ,h_attribute8
        ,h_attribute9
        ,h_attribute10
        ,h_attribute11
        ,h_attribute12
        ,h_attribute13
        ,h_attribute14
        ,h_attribute15
        ,c_item_num
        ,c_operation_seq_num
        ,c_component_item_number
        ,c_basis_type
        ,c_component_quantity
        ,c_eng_item_flag
        ,c_auto_request_material
        ,c_from_date
        ,c_to_date
        ,c_planning_factor
        ,c_component_yield_factor
        ,c_enforce_int_requirement_desc
        ,c_include_in_cost_rollup
        ,c_supply_type
        ,c_supply_subinventory
        ,c_locator
        ,c_check_atp
        ,c_optional
        ,c_mutually_exclusive_options
        ,c_low_quantity
        ,c_high_quantity
        ,c_so_basis
        ,c_shippable_item_flag
        ,c_include_on_ship_docs
        ,c_required_to_ship
        ,c_required_for_revenue
        ,c_component_remarks
        ,c_attribute_category
        ,c_attribute1
        ,c_attribute2
        ,c_attribute3
        ,c_attribute4
        ,c_attribute5
        ,c_attribute6
        ,c_attribute7
        ,c_attribute8
        ,c_attribute9
        ,c_attribute10
        ,c_attribute11
        ,c_attribute12
        ,c_attribute13
        ,c_attribute14
        ,c_attribute15)
      VALUES
        (xxobjt.xxs3_ptm_bill_of_mat_seq.NEXTVAL
        ,SYSDATE
        ,'N'
        ,i.h_assembly_item_number
        ,i.h_organization_code
         /*        ,decode(i.h_organization_code
                                 ,'UME'
                                 ,'M01'
                                 ,'USE'
                                 ,'T01'
                                 ,'UTP'
                                 ,'M02'
                                 ,'OMA'
                                 ,'GIM'
                                 ,i.h_organization_code)*/
        ,i.h_revision
        ,i.h_alternate_bom_designator
        ,i.h_common_assembly_item_name
        ,i.h_specific_assembly_comment
        ,i.h_assembly_type
        ,i.h_common_organization_code
         /*        ,decode(i.h_common_organization_code
                                 ,'UME'
                                 ,'M01'
                                 ,'USE'
                                 ,'T01'
                                 ,'UTP'
                                 ,'M02'
                                 ,'OMA'
                                 ,'GIM'
                                 ,i.h_common_organization_code)*/
        ,i.h_effectivity_control
        ,i.h_attribute_category
        ,i.h_attribute1
        ,i.h_attribute2
        ,i.h_attribute3
        ,i.h_attribute4
        ,i.h_attribute5
        ,i.h_attribute6
        ,i.h_attribute7
        ,i.h_attribute8
        ,i.h_attribute9
        ,i.h_attribute10
        ,i.h_attribute11
        ,i.h_attribute12
        ,i.h_attribute13
        ,i.h_attribute14
        ,i.h_attribute15
        ,i.c_item_num
        ,i.c_operation_seq_num
        ,i.c_component_item_number
        ,i.c_basis_type
        ,i.c_component_quantity
        ,i.c_eng_item_flag
        ,i.c_auto_request_material
        ,i.c_from_date
        ,i.c_to_date
        ,i.c_planning_factor
        ,i.c_component_yield_factor
        ,i.c_enforce_int_requirement_desc
        ,i.c_include_in_cost_rollup
        ,i.c_supply_type
        ,i.c_supply_subinventory
        ,i.c_locator
        ,i.c_check_atp
        ,i.c_optional
        ,i.c_mutually_exclusive_options
        ,i.c_low_quantity
        ,i.c_high_quantity
        ,i.c_so_basis
        ,i.c_shippable_item_flag
        ,i.c_include_on_ship_docs
        ,i.c_required_to_ship
        ,i.c_required_for_revenue
        ,i.c_component_remarks
        ,i.c_attribute_category
        ,i.c_attribute1
        ,i.c_attribute2
        ,i.c_attribute3
        ,i.c_attribute4
        ,i.c_attribute5
        ,i.c_attribute6
        ,i.c_attribute7
        ,i.c_attribute8
        ,i.c_attribute9
        ,i.c_attribute10
        ,i.c_attribute11
        ,i.c_attribute12
        ,i.c_attribute13
        ,i.c_attribute14
        ,i.c_attribute15);
    END LOOP;
	/* Calling Cleans procedure and DQ procedure */
    cleanse_bom(l_err_code, l_err_msg);
    quality_check_bom(l_err_code, l_err_msg);
    COMMIT;

  /* Transformation section */
    FOR j IN cur_transform LOOP
      IF j.h_organization_code IN ('UME', 'USE', 'UTP', 'OMA') THEN
        xxs3_data_transform_util_pkg.transform(p_mapping_type          => 'inventory_org'
                                              ,p_stage_tab             => 'XXS3_PTM_BILL_OF_MATERIALS'
                                              , --Staging Table Name
                                               p_stage_primary_col     => 'XX_BOM_ID'
                                              , --Staging Table Primary Column Name
                                               p_stage_primary_col_val => j.xx_bom_id
                                              , --Staging Table Primary Column Value
                                               p_legacy_val            => j.h_organization_code
                                              , --Legacy Value
                                               p_stage_col             => 'S3_H_ORGANIZATION_CODE'
                                              , --Staging Table Name
                                               p_err_code              => l_err_code
                                              , -- Output error code
                                               p_err_msg               => l_err_msg);
      END IF;
      IF j.h_common_organization_code IN ('UME', 'USE', 'UTP', 'OMA') THEN
        xxs3_data_transform_util_pkg.transform(p_mapping_type          => 'inventory_org'
                                              ,p_stage_tab             => 'XXS3_PTM_BILL_OF_MATERIALS'
                                              , --Staging Table Name
                                               p_stage_primary_col     => 'XX_BOM_ID'
                                              , --Staging Table Primary Column Name
                                               p_stage_primary_col_val => j.xx_bom_id
                                              , --Staging Table Primary Column Value
                                               p_legacy_val            => j.h_common_organization_code
                                              , --Legacy Value
                                               p_stage_col             => 'S3_H_COMMON_ORGANIZATION_CODE'
                                              , --Staging Table Name
                                               p_err_code              => l_err_code
                                              , -- Output error code
                                               p_err_msg               => l_err_msg);
      END IF;
      IF j.h_organization_code IN ('IPK', 'IRK') THEN
        UPDATE xxobjt.xxs3_ptm_bill_of_materials
           SET s3_h_organization_code        = j.h_organization_code
              ,transform_status              = 'PASS'
              where XX_BOM_ID=j.xx_bom_id;

      END IF;
/*            IF j.h_common_organization_code IN ('IPK', 'IRK') THEN
        UPDATE xxobjt.xxs3_ptm_bill_of_materials
           SET s3_h_common_organization_code = j.h_common_organization_code
              ,transform_status              = 'PASS'
              where XX_BOM_ID=j.xx_bom_id;
      END IF;*/
    END LOOP;
    
    /* ADDED 1/4/17 as per FDD Update */
        
    BEGIN
    UPDATE xxs3_ptm_bill_of_materials
    SET c_basis_type = NULL
    WHERE S3_H_ORGANIZATION_CODE='GIM';
    COMMIT;
    EXCEPTION
      WHEN OTHERS THEN
    fnd_file.put_line(fnd_file.log, 'Error in c_basis_type for GIM'||SQLERRM);
    END;


    /*utl_file.put(l_file, '~' || 'XX_BOM_ID');
    utl_file.put(l_file, '~' || 'data_extracted_on');
    utl_file.put(l_file, '~' || 'process_flag');
    utl_file.put(l_file, '~' || 'h_assembly_item_number');
    utl_file.put(l_file, '~' || 'h_organization_code');
    utl_file.put(l_file, '~' || 's3_h_organization_code');
    utl_file.put(l_file, '~' || 'h_revision');
    utl_file.put(l_file, '~' || 'h_alternate_bom_designator');
    utl_file.put(l_file, '~' || 'h_common_assembly_item_name');
    utl_file.put(l_file, '~' || 'h_specific_assembly_comment');
    utl_file.put(l_file, '~' || 'h_assembly_type');
    utl_file.put(l_file, '~' || 'h_common_organization_code');
    utl_file.put(l_file, '~' || 's3_h_common_organization_code');
    utl_file.put(l_file, '~' || 'h_effectivity_control');
    utl_file.put(l_file, '~' || 'h_attribute_category');
    utl_file.put(l_file, '~' || 'h_attribute1');
    utl_file.put(l_file, '~' || 'h_attribute2');
    utl_file.put(l_file, '~' || 'h_attribute3');
    utl_file.put(l_file, '~' || 'h_attribute4');
    utl_file.put(l_file, '~' || 'h_attribute5');
    utl_file.put(l_file, '~' || 'h_attribute6');
    utl_file.put(l_file, '~' || 'h_attribute7');
    utl_file.put(l_file, '~' || 'h_attribute8');
    utl_file.put(l_file, '~' || 'h_attribute9');
    utl_file.put(l_file, '~' || 'h_attribute10');
    utl_file.put(l_file, '~' || 'h_attribute11');
    utl_file.put(l_file, '~' || 'h_attribute12');
    utl_file.put(l_file, '~' || 'h_attribute13');
    utl_file.put(l_file, '~' || 'h_attribute14');
    utl_file.put(l_file, '~' || 'h_attribute15');
    utl_file.put(l_file, '~' || 'c_item_num');
    utl_file.put(l_file, '~' || 'c_operation_seq_num');
    utl_file.put(l_file, '~' || 'c_component_item_number');
    utl_file.put(l_file, '~' || 'c_basis_type');
    utl_file.put(l_file, '~' || 'c_component_quantity');
    utl_file.put(l_file, '~' || 'c_eng_item_flag');
    utl_file.put(l_file, '~' || 'c_auto_request_material');
    utl_file.put(l_file, '~' || 'c_from_date');
    utl_file.put(l_file, '~' || 'c_to_date');
    utl_file.put(l_file, '~' || 'c_planning_factor');
    utl_file.put(l_file, '~' || 'c_component_yield_factor');
    utl_file.put(l_file, '~' || 'c_enforce_int_requirement_desc');
    utl_file.put(l_file, '~' || 'c_include_in_cost_rollup');
    utl_file.put(l_file, '~' || 'c_supply_type');
    utl_file.put(l_file, '~' || 'c_supply_subinventory');
    utl_file.put(l_file, '~' || 'c_locator');
    utl_file.put(l_file, '~' || 'c_check_atp');
    utl_file.put(l_file, '~' || 'c_optional');
    utl_file.put(l_file, '~' || 'c_mutually_exclusive_options');
    utl_file.put(l_file, '~' || 'c_low_quantity');
    utl_file.put(l_file, '~' || 'c_high_quantity');
    utl_file.put(l_file, '~' || 'c_so_basis');
    utl_file.put(l_file, '~' || 'c_shippable_item_flag');
    utl_file.put(l_file, '~' || 'c_include_on_ship_docs');
    utl_file.put(l_file, '~' || 'c_required_to_ship');
    utl_file.put(l_file, '~' || 'c_required_for_revenue');
    utl_file.put(l_file, '~' || 'c_component_remarks');
    utl_file.put(l_file, '~' || 'c_attribute_category');
    utl_file.put(l_file, '~' || 'c_attribute1');
    utl_file.put(l_file, '~' || 'c_attribute2');
    utl_file.put(l_file, '~' || 'c_attribute3');
    utl_file.put(l_file, '~' || 'c_attribute4');
    utl_file.put(l_file, '~' || 'c_attribute5');
    utl_file.put(l_file, '~' || 'c_attribute6');
    utl_file.put(l_file, '~' || 'c_attribute7');
    utl_file.put(l_file, '~' || 'c_attribute8');
    utl_file.put(l_file, '~' || 'c_attribute9');
    utl_file.put(l_file, '~' || 'c_attribute10');
    utl_file.put(l_file, '~' || 'c_attribute11');
    utl_file.put(l_file, '~' || 'c_attribute12');
    utl_file.put(l_file, '~' || 'c_attribute13');
    utl_file.put(l_file, '~' || 'c_attribute14');
    utl_file.put(l_file, '~' || 'c_attribute15');
    utl_file.new_line(l_file);
    FOR c1 IN (SELECT * FROM xxobjt.xxs3_ptm_bill_of_materials) LOOP
      utl_file.put(l_file, '~' || to_char(c1.xx_bom_id));
      utl_file.put(l_file, '~' || to_char(c1.data_extracted_on));
      utl_file.put(l_file, '~' || to_char(c1.process_flag));
      utl_file.put(l_file, '~' || to_char(c1.h_assembly_item_number));
      utl_file.put(l_file, '~' || to_char(c1.h_organization_code));
      utl_file.put(l_file, '~' || to_char(c1.s3_h_organization_code));
      utl_file.put(l_file, '~' || to_char(c1.h_revision));
      utl_file.put(l_file, '~' || to_char(c1.h_alternate_bom_designator));
      utl_file.put(l_file, '~' || to_char(c1.h_common_assembly_item_name));
      utl_file.put(l_file, '~' || to_char(c1.h_specific_assembly_comment));
      utl_file.put(l_file, '~' || to_char(c1.h_assembly_type));
      utl_file.put(l_file, '~' || to_char(c1.h_common_organization_code));
      utl_file.put(l_file, '~' || to_char(c1.s3_h_common_organization_code));
      utl_file.put(l_file, '~' || to_char(c1.h_effectivity_control));
      utl_file.put(l_file, '~' || to_char(c1.h_attribute_category));
      utl_file.put(l_file, '~' || to_char(c1.h_attribute1));
      utl_file.put(l_file, '~' || to_char(c1.h_attribute2));
      utl_file.put(l_file, '~' || to_char(c1.h_attribute3));
      utl_file.put(l_file, '~' || to_char(c1.h_attribute4));
      utl_file.put(l_file, '~' || to_char(c1.h_attribute5));
      utl_file.put(l_file, '~' || to_char(c1.h_attribute6));
      utl_file.put(l_file, '~' || to_char(c1.h_attribute7));
      utl_file.put(l_file, '~' || to_char(c1.h_attribute8));
      utl_file.put(l_file, '~' || to_char(c1.h_attribute9));
      utl_file.put(l_file, '~' || to_char(c1.h_attribute10));
      utl_file.put(l_file, '~' || to_char(c1.h_attribute11));
      utl_file.put(l_file, '~' || to_char(c1.h_attribute12));
      utl_file.put(l_file, '~' || to_char(c1.h_attribute13));
      utl_file.put(l_file, '~' || to_char(c1.h_attribute14));
      utl_file.put(l_file, '~' || to_char(c1.h_attribute15));
      utl_file.put(l_file, '~' || to_char(c1.c_item_num));
      utl_file.put(l_file, '~' || to_char(c1.c_operation_seq_num));
      utl_file.put(l_file, '~' || to_char(c1.c_component_item_number));
      utl_file.put(l_file, '~' || to_char(c1.c_basis_type));
      utl_file.put(l_file, '~' || to_char(c1.c_component_quantity));
      utl_file.put(l_file, '~' || to_char(c1.c_eng_item_flag));
      utl_file.put(l_file, '~' || to_char(c1.c_auto_request_material));
      utl_file.put(l_file, '~' || to_char(c1.c_from_date));
      utl_file.put(l_file, '~' || to_char(c1.c_to_date));
      utl_file.put(l_file, '~' || to_char(c1.c_planning_factor));
      utl_file.put(l_file, '~' || to_char(c1.c_component_yield_factor));
      utl_file.put(l_file, '~' ||
                    to_char(c1.c_enforce_int_requirement_desc));
      utl_file.put(l_file, '~' || to_char(c1.c_include_in_cost_rollup));
      utl_file.put(l_file, '~' || to_char(c1.c_supply_type));
      utl_file.put(l_file, '~' || to_char(c1.c_supply_subinventory));
      utl_file.put(l_file, '~' || to_char(c1.c_locator));
      utl_file.put(l_file, '~' || to_char(c1.c_check_atp));
      utl_file.put(l_file, '~' || to_char(c1.c_optional));
      utl_file.put(l_file, '~' || to_char(c1.c_mutually_exclusive_options));
      utl_file.put(l_file, '~' || to_char(c1.c_low_quantity));
      utl_file.put(l_file, '~' || to_char(c1.c_high_quantity));
      utl_file.put(l_file, '~' || to_char(c1.c_so_basis));
      utl_file.put(l_file, '~' || to_char(c1.c_shippable_item_flag));
      utl_file.put(l_file, '~' || to_char(c1.c_include_on_ship_docs));
      utl_file.put(l_file, '~' || to_char(c1.c_required_to_ship));
      utl_file.put(l_file, '~' || to_char(c1.c_required_for_revenue));
      utl_file.put(l_file, '~' || to_char(c1.c_component_remarks));
      utl_file.put(l_file, '~' || to_char(c1.c_attribute_category));
      utl_file.put(l_file, '~' || to_char(c1.c_attribute1));
      utl_file.put(l_file, '~' || to_char(c1.c_attribute2));
      utl_file.put(l_file, '~' || to_char(c1.c_attribute3));
      utl_file.put(l_file, '~' || to_char(c1.c_attribute4));
      utl_file.put(l_file, '~' || to_char(c1.c_attribute5));
      utl_file.put(l_file, '~' || to_char(c1.c_attribute6));
      utl_file.put(l_file, '~' || to_char(c1.c_attribute7));
      utl_file.put(l_file, '~' || to_char(c1.c_attribute8));
      utl_file.put(l_file, '~' || to_char(c1.c_attribute9));
      utl_file.put(l_file, '~' || to_char(c1.c_attribute10));
      utl_file.put(l_file, '~' || to_char(c1.c_attribute11));
      utl_file.put(l_file, '~' || to_char(c1.c_attribute12));
      utl_file.put(l_file, '~' || to_char(c1.c_attribute13));
      utl_file.put(l_file, '~' || to_char(c1.c_attribute14));
      utl_file.put(l_file, '~' || to_char(c1.c_attribute15));

    END LOOP;*/
    /*utl_file.fclose(l_file);*/

  END bill_of_materials_extract_data;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used for Approved Suppliers Transform Report
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  Santanu                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE data_transform_report(p_entity VARCHAR2) IS

  /* Cursor for the Transform Report */

    CURSOR c_report_bom IS
      SELECT xpb.xx_bom_id
            ,xpb.h_assembly_item_number
            ,xpb.c_component_item_number
            ,xpb.h_organization_code
            ,xpb.s3_h_organization_code
/*            ,xpb.h_common_organization_code
            ,xpb.s3_h_common_organization_code*/
            ,xpb.transform_status
            ,xpb.transform_error
        FROM xxs3_ptm_bill_of_materials xpb
      /*WHERE xpb.transform_status IN ('PASS', 'FAIL')*/
      ;
    p_delimiter     VARCHAR2(5) := '~';
    l_err_msg       VARCHAR2(2000);
    l_count_success NUMBER;
    l_count_fail    NUMBER;
  BEGIN

    SELECT COUNT(1)
      INTO l_count_success
      FROM xxs3_ptm_bill_of_materials xpb
     WHERE xpb.transform_status = 'PASS';

    SELECT COUNT(1)
      INTO l_count_fail
      FROM xxs3_ptm_bill_of_materials xpb
     WHERE xpb.transform_status = 'FAIL';

    out_p(rpad('Report name = Data Transformation Report' || p_delimiter, 100, ' '));
    out_p(rpad('========================================' || p_delimiter, 100, ' '));
    out_p(rpad('Data Migration Object Name = ' || p_entity || p_delimiter, 100, ' '));
    out_p('');
    out_p(rpad('Run date and time:    ' || to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') || p_delimiter
              ,100
              ,' '));
    out_p(rpad('Total Record Count Success = ' || l_count_success || p_delimiter, 100, ' '));
    out_p(rpad('Total Record Count Failure = ' || l_count_fail || p_delimiter, 100, ' '));

    out_p('');

    out_p(rpad('Track Name', 10, ' ') || p_delimiter || rpad('Entity Name', 11, ' ') ||
          p_delimiter || rpad('XX BOM ID  ', 14, ' ') || p_delimiter ||
          rpad('Assembly Item Number', 30, ' ') || p_delimiter ||
          rpad('Component Item Number', 30, ' ') || p_delimiter ||
          rpad('Organization Code', 30, ' ') || p_delimiter ||
          rpad('S3 Organization Code', 30, ' ') || p_delimiter ||
          /*rpad('Common Organization Code', 30, ' ') || p_delimiter ||
          rpad('S3 Common Organization Code', 30, ' ') || p_delimiter ||*/ rpad('Status', 10, ' ') ||
          p_delimiter || rpad('Error Message', 200, ' '));

    FOR r_data IN c_report_bom LOOP
      out_p(rpad('PTM', 10, ' ') || p_delimiter || rpad('BOM', 11, ' ') || p_delimiter ||
            rpad(r_data.xx_bom_id, 14, ' ') || p_delimiter ||
            rpad(r_data.h_assembly_item_number, 30, ' ') || p_delimiter ||
            rpad(r_data.c_component_item_number, 30, ' ') || p_delimiter ||
            rpad(r_data.h_organization_code, 30, ' ') || p_delimiter ||
            rpad(r_data.s3_h_organization_code, 30, ' ') || p_delimiter ||
            /*rpad(r_data.h_common_organization_code, 30, ' ') || p_delimiter ||
            rpad(r_data.s3_h_common_organization_code, 30, ' ') || p_delimiter ||*/
            rpad(r_data.transform_status, 10, ' ') || p_delimiter ||
            rpad(nvl(r_data.transform_error, 'NULL'), 200, ' '));
    END LOOP;

    fnd_file.put_line(fnd_file.output, '');
    fnd_file.put_line(fnd_file.output, 'Stratasys Confidential' || p_delimiter);
  END;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used to BOM Quality Report
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  Santanu                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE bom_report_data(p_entity VARCHAR2) AS

  /*Cursor for the DQ Report*/
    CURSOR c_report_bom IS
      SELECT xpb.xx_bom_id
            ,xpb.h_assembly_item_number
            ,xpb.c_component_item_number
            ,xpq.rule_name
            ,xpq.notes
            ,decode(xpb.process_flag, 'R', 'Y', 'Q', 'N') reject_record
        FROM xxs3_ptm_bill_of_materials    xpb
            ,xxs3_ptm_bill_of_materials_dq xpq
       WHERE xpb.xx_bom_id = xpq.xx_bom_id;
    p_delimiter    VARCHAR2(5) := '~';
    l_count_dq     NUMBER;
    l_count_reject NUMBER;
  BEGIN
    SELECT COUNT(1)
      INTO l_count_dq
      FROM xxs3_ptm_bill_of_materials xci
     WHERE xci.process_flag IN ('Q', 'R');

    SELECT COUNT(1)
      INTO l_count_reject
      FROM xxs3_ptm_bill_of_materials xci
     WHERE xci.process_flag = 'R';

    out_p(rpad('Report name = Data Transformation Report' || p_delimiter, 100, ' '));
    out_p(rpad('========================================' || p_delimiter, 100, ' '));
    out_p(rpad('Data Migration Object Name = ' || 'BOM' || p_delimiter, 100, ' '));
    out_p('');
    out_p(rpad('Run date and time:    ' || to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') || p_delimiter
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
          p_delimiter || rpad('XX BOM ID  ', 14, ' ') || p_delimiter ||
          rpad('Assembly Item Number', 30, ' ') || p_delimiter ||
          rpad('Component Item Number', 30, ' ') || p_delimiter ||
          rpad('Reject Record Flag(Y/N)', 25, ' ') || p_delimiter || rpad('Rule Name', 50, ' ') ||
          p_delimiter || rpad('Reason Code', 200, ' '));

    FOR r_data IN c_report_bom LOOP
      out_p(rpad('PTM', 10, ' ') || p_delimiter || rpad('BOM', 11, ' ') || p_delimiter ||
            rpad(r_data.xx_bom_id, 14, ' ') || p_delimiter ||
            rpad(r_data.h_assembly_item_number, 30, ' ') || p_delimiter ||
            rpad(r_data.c_component_item_number, 30, ' ') || p_delimiter ||
            rpad(r_data.reject_record, 25, ' ') || p_delimiter || rpad(r_data.rule_name, 50, ' ') ||
            p_delimiter || rpad(r_data.notes, 200, ' '));
    END LOOP;

    fnd_file.put_line(fnd_file.output, '');
    fnd_file.put_line(fnd_file.output, 'Stratasys Confidential' || p_delimiter);
  END;

END xxs3_ptm_bill_of_materials_pkg;
/