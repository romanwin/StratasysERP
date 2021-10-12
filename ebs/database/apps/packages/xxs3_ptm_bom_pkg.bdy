CREATE OR REPLACE PACKAGE BODY xxs3_ptm_bom_pkg AS
  ----------------------------------------------------------------------------
  --  name:            xxs3_ptm_bom_pkg
  --  create by:       Debarati Banerjee
  --  Revision:        1.0
  --  creation date:   01/07/2016
  ----------------------------------------------------------------------------
  --  purpose :        Package to extract the Bom Routings template fields
  --                   from Legacy system

  ----------------------------------------------------------------------------
  --  ver  date        name                         desc
  --  1.0  01/07/2016  Debarati Banerjee            Initial build
  ----------------------------------------------------------------------------

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Check item
  --          This function checks if item is Make item (Make/Buy item attribute)
  --          2) Is a component on the BOM of another assembly in the same org.
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  13/07/2016  Debarati Banerjee             Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION check_item(p_item_id IN NUMBER,
                      p_org_id  IN NUMBER) RETURN VARCHAR2 IS
    l_item_check NUMBER := 0;
  BEGIN
    SELECT COUNT(1)
      INTO L_ITEM_CHECK
      FROM MTL_SYSTEM_ITEMS_FVL MSIF
     WHERE MSIF.INVENTORY_ITEM_ID = P_ITEM_ID
       AND MSIF.PLANNING_MAKE_BUY_CODE IN (1, 2)
       AND MSIF.ORGANIZATION_ID = P_ORG_ID;

    IF l_item_check > 0 THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END check_item;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Check bom
  --          This function checks if item is a component on the BOM of another assembly
  --          in the same org.
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  13/07/2016  Debarati Banerjee                  Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION check_bom(p_item_id IN NUMBER,
                     p_org_id  IN NUMBER) RETURN VARCHAR2 IS
    l_item_check NUMBER := 0;
  BEGIN
    SELECT COUNT(1)
      INTO L_ITEM_CHECK
      FROM BOM_INVENTORY_COMPONENTS_V BICV, BOM_BILL_OF_MATERIALS_V BBOMV
     WHERE BICV.COMPONENT_ITEM_ID = P_ITEM_ID
       AND BBOMV.ORGANIZATION_ID = P_ORG_ID
       AND BICV.BILL_SEQUENCE_ID = BBOMV.BILL_SEQUENCE_ID;

    IF l_item_check > 0 THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END check_bom;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Update completion subinventory
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  13/07/2016  Debarati Banerjee            Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE update_completion_subinv(p_id IN NUMBER) IS

    l_error_msg VARCHAR2(2000);

  BEGIN

    UPDATE XXS3_PTM_BOM_ROUTING
       SET S3_COMPLETION_SUBINVENTORY = 'FLOOR', CLEANSE_STATUS = 'PASS'
     WHERE XX_ROUTING_SEQ_ID = P_ID;

  EXCEPTION
    WHEN OTHERS THEN
      l_error_msg := 'UNEXPECTED ERROR on Completion Subinventory update : ' ||
                     SQLERRM;

      UPDATE XXS3_PTM_BOM_ROUTING
         SET CLEANSE_STATUS = 'FAIL',
             CLEANSE_ERROR  = CLEANSE_ERROR || '' || '' || L_ERROR_MSG
       WHERE XX_ROUTING_SEQ_ID = P_ID;

  END update_completion_subinv;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Update legacy values
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  13/07/2016  Debarati Banerjee            Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE update_legacy_values(p_id                      IN NUMBER,
                                 p_completion_subinventory IN VARCHAR2) IS

  BEGIN

    UPDATE XXS3_PTM_BOM_ROUTING
       SET S3_COMPLETION_SUBINVENTORY = P_COMPLETION_SUBINVENTORY
     WHERE S3_COMPLETION_SUBINVENTORY IS NULL
       AND XX_ROUTING_SEQ_ID = P_ID;

  END update_legacy_values;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Insert in to DQ table for validation errors and update master table
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  13/07/2016   Debarati Banerjee            Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE insert_update_routing_dq(p_xx_routing_seq_id NUMBER,
                                     p_rule_name         IN VARCHAR2,
                                     p_reject_code       IN VARCHAR2) IS

  BEGIN
    UPDATE XXS3_PTM_BOM_ROUTING
       SET PROCESS_FLAG = 'Q'
     WHERE XX_ROUTING_SEQ_ID = P_XX_ROUTING_SEQ_ID;

    INSERT INTO xxs3_ptm_bom_routing_dq
      (xx_dq_routing_seq_id,
       xx_routing_seq_id,
       rule_name,
       notes)
    VALUES
      (xxs3_ptm_bom_routing_dq_seq.NEXTVAL,
       p_xx_routing_seq_id,
       p_rule_name,
       p_reject_code);

  END insert_update_routing_dq;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required Bom Department fields and insert into
  --           staging table XXS3_PTM_BOM_DEPT
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0  01/07/2016  Debarati Banerjee            Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE bom_dept_extract_data(x_errbuf  OUT VARCHAR2,
                                  x_retcode OUT NUMBER) IS

    l_errbuf             VARCHAR2(2000);
    l_retcode            VARCHAR2(1);
    l_requestor          NUMBER;
    l_program_short_name VARCHAR2(100);
    l_status_message     VARCHAR2(4000);
    l_output             VARCHAR2(4000);

    CURSOR c_dept_extract IS
    SELECT DISTINCT bdv.department_id,
                    (SELECT mp.organization_code
                       FROM mtl_parameters mp
                      WHERE mp.organization_id = bdv.organization_id) organization,
                    bdv.department_code,
                    bdv.description,
                    bdv.department_class_code,
                    bdv.class_description,
                    bdv.location_code,
                    bdv.attribute1,
                    bdv.attribute2,
                    bdv.attribute3,
                    bdv.attribute4,
                    bdv.attribute5,
                    bdv.attribute6,
                    bdv.attribute7,
                    bdv.attribute8,
                    bdv.attribute9,
                    bdv.attribute10,
                    bdv.attribute11,
                    bdv.attribute12,
                    bdv.attribute13,
                    bdv.attribute14,
                    bdv.attribute15,
                    bdv.attribute_category,
                    cdov.cost_type,
                    cdov.overhead_code,
                    cdov.activity,
                    cdov.basis_type,
                    cdov.rate_or_amount,
                    bomdrv.resource_code,
                    bomdrv.available_24_hours_flag,
                    bomdrv.share_capacity_flag,
                    bomdrv.capacity_units,
                    bomdrv.utilization,
                    bomrsv.shift_num,
                    bomrsv.capacity_units shift_capacity_units
      FROM bom_departments_v          bdv,
           cst_department_overheads_v cdov,
           bom_department_resources_v bomdrv,
           bom_resource_shifts_v      bomrsv,
           bom_operation_sequences_v  bomosv,
           bom_operational_routings_v bomrv
     WHERE bdv.department_id = cdov.department_id(+)
       AND bdv.department_id = bomdrv.department_id(+)
       AND bomdrv.department_id = bomrsv.department_id(+)
       AND bomdrv.resource_id = bomrsv.resource_id(+)
       AND bomdrv.organization_id = bomrsv.organization_id(+)
       AND bdv.department_id = bomosv.department_id
       AND bomosv.routing_sequence_id = bomrv.routing_sequence_id
          --AND BDV.ORGANIZATION_ID IN (739, 740)
       AND bdv.organization_id IN
           (SELECT (substr(TRIM(meaning), 1, instr(TRIM(meaning), '-') - 1)) v_org_id
              FROM fnd_lookup_values
             WHERE lookup_type = 'XXS3_COMMON_EXTRACT_LKP'
               AND substr(TRIM(meaning), instr(TRIM(meaning), '-') + 1) =
                   'DEPT'
               AND substr(TRIM(lookup_code),
                          instr(TRIM(lookup_code), '-') + 1) = 'DEPT'
               AND enabled_flag = 'Y'
               AND description = 'Inventoryorg'
               AND LANGUAGE = userenv('LANG')
               AND trunc(SYSDATE) BETWEEN
                   nvl(start_date_active, trunc(SYSDATE)) AND
                   nvl(end_date_active, trunc(SYSDATE)))
       AND bdv.disable_date IS NULL;

    CURSOR c_dept IS
    SELECT ORGANIZATION, XX_DEPARTMENT_ID FROM XXS3_PTM_BOM_DEPT;

    l_err_code VARCHAR2(4000);
    l_err_msg  VARCHAR2(4000);

  BEGIN

    x_retcode := 0;
    x_errbuf  := 'COMPLETE';

    DELETE FROM xxs3_ptm_bom_dept;

    FOR i IN c_dept_extract LOOP

      INSERT INTO xxs3_ptm_bom_dept
      VALUES
        (xxs3_ptm_bom_dept_seq.NEXTVAL,
         SYSDATE,
         'N',
         NULL,
         NULL,
         i.department_id,
         i.organization,
         NULL,
         i.department_code,
         i.description,
         i.department_class_code,
         i.class_description,
         i.location_code,
         i.attribute1,
         i.attribute2,
         i.attribute3,
         i.attribute4,
         i.attribute5,
         i.attribute6,
         i.attribute7,
         i.attribute8,
         i.attribute9,
         i.attribute10,
         i.attribute11,
         i.attribute12,
         i.attribute13,
         i.attribute14,
         i.attribute15,
         i.attribute_category,
         i.cost_type,
         i.overhead_code,
         i.activity,
         i.basis_type,
         i.rate_or_amount,
         i.resource_code,
         i.available_24_hours_flag,
         i.share_capacity_flag,
         i.capacity_units,
         i.utilization,
         i.shift_num,
         i.capacity_units,
         NULL,
         NULL,
         NULL,
         NULL);

    END LOOP;

    COMMIT;

    fnd_file.put_line(fnd_file.log, 'Loading complete');

    --Org code transformation
    FOR j IN c_dept LOOP
      xxs3_data_transform_util_pkg.transform(p_mapping_type => 'inventory_org', p_stage_tab => 'XXS3_PTM_BOM_DEPT', --Staging Table Name
                                             p_stage_primary_col => 'XX_DEPARTMENT_ID', --Staging Table Primary Column Name
                                             p_stage_primary_col_val => j.xx_department_id, --Staging Table Primary Column Value
                                             p_legacy_val => j.organization, --Legacy Value
                                             p_stage_col => 'S3_ORGANIZATION', --Staging Table Name
                                             p_err_code => l_err_code, -- Output error code
                                             p_err_msg => l_err_msg);
    END LOOP;

  EXCEPTION

    WHEN OTHERS THEN
      x_retcode        := 2;
      x_errbuf         := 'Unexpected error: ' || SQLERRM;
      l_status_message := SQLCODE || chr(10) || SQLERRM;
      fnd_file.put_line(fnd_file.log, 'Unexpected error during data extraction : ' ||
                         chr(10) || l_status_message);
      fnd_file.put_line(fnd_file.log, '--------------------------------------');

  END bom_dept_extract_data;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required Bom Resource fields and insert into
  --           staging table XXS3_PTM_BOM_RESOURCE
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0  01/07/2016  Debarati Banerjee            Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE bom_resource_extract_data(x_errbuf  OUT VARCHAR2,
                                      x_retcode OUT NUMBER) IS

    l_errbuf                 VARCHAR2(2000);
    l_retcode                VARCHAR2(1);
    l_requestor              NUMBER;
    l_program_short_name     VARCHAR2(100);
    l_status_message         VARCHAR2(4000);
    l_output                 VARCHAR2(4000);
    l_output_absorption      VARCHAR2(4000);
    l_err_code               VARCHAR2(4000);
    l_err_msg                VARCHAR2(4000);
    l_output_coa_update      VARCHAR2(4000);
    l_output_code_coa_update VARCHAR2(100);
    l_s3_gl_string           VARCHAR2(2000);
    l_output_code            VARCHAR2(100);

    CURSOR c_resource_extract IS
    SELECT DISTINCT brv.resource_id,
                    (SELECT mp.organization_code
                       FROM mtl_parameters mp
                      WHERE mp.organization_id = brv.organization_id) organization_code,
                    brv.resource_code,
                    brv.disable_date,
                    brv.description description,
                    (SELECT meaning
                       FROM mfg_lookups_v
                      WHERE lookup_type = 'BOM_RESOURCE_TYPE'
                        AND enabled_flag = 'Y'
                        AND lookup_code = brv.resource_type) TYPE,
                    brv.unit_of_measure uom,
                    (SELECT meaning
                       FROM mfg_lookups_v
                      WHERE lookup_type = 'BOM_AUTOCHARGE_TYPE'
                        AND enabled_flag = 'Y'
                        AND lookup_code = brv.autocharge_type) charge_type,
                    --DECODE(brv.cost_code_type, '4', 'Yes', 'No') outside_processing,
                    decode(brv.default_basis_type, '1', 'Item', 'Lot') basis,
                    brv.expenditure_type,
                    brv.attribute1,
                    brv.attribute2,
                    brv.attribute3,
                    brv.attribute4,
                    brv.attribute5,
                    brv.attribute6,
                    brv.attribute7,
                    brv.attribute8,
                    brv.attribute9,
                    brv.attribute10,
                    brv.attribute11,
                    brv.attribute12,
                    brv.attribute13,
                    brv.attribute14,
                    brv.attribute15,
                    brv.attribute_category,
                    brv.supply_subinventory,
                    brv.supply_locator_id,
                    decode(brv.cost_code_type, '4', 'Yes', 'No') outside_processing_flag,
                    (SELECT segment1
                       FROM mtl_system_items_b
                      WHERE inventory_item_id = brv.purchase_item_id
                        AND organization_id = brv.organization_id) outside_processing_item,
                    (SELECT segment1
                       FROM mtl_system_items_b
                      WHERE inventory_item_id = brv.billable_item_id
                        AND organization_id = brv.organization_id) billing_item,
                    decode(brv.allow_costs_flag, '1', 'Yes', 'No') allow_costs_flag,
                    brv.default_activity,
                    brv.standard_rate_flag,
                    (SELECT concatenated_segments
                       FROM gl_code_combinations_kfv gcck
                      WHERE gcck.code_combination_id =
                            brv.absorption_account) absorption_account,
                    (SELECT concatenated_segments
                       FROM gl_code_combinations_kfv gcck
                      WHERE gcck.code_combination_id =
                            brv.rate_variance_account) variance_account,
                    (SELECT segment1
                       FROM gl_code_combinations_kfv gcck
                      WHERE gcck.code_combination_id =
                            brv.absorption_account) absorption_acct_segment1,
                    (SELECT segment2
                       FROM gl_code_combinations_kfv gcck
                      WHERE gcck.code_combination_id =
                            brv.absorption_account) absorption_acct_segment2,
                    (SELECT segment3
                       FROM gl_code_combinations_kfv gcck
                      WHERE gcck.code_combination_id =
                            brv.absorption_account) absorption_acct_segment3,
                    (SELECT segment4
                       FROM gl_code_combinations_kfv gcck
                      WHERE gcck.code_combination_id =
                            brv.absorption_account) absorption_acct_segment4,
                    (SELECT segment5
                       FROM gl_code_combinations_kfv gcck
                      WHERE gcck.code_combination_id =
                            brv.absorption_account) absorption_acct_segment5,
                    (SELECT segment6
                       FROM gl_code_combinations_kfv gcck
                      WHERE gcck.code_combination_id =
                            brv.absorption_account) absorption_acct_segment6,
                    (SELECT segment7
                       FROM gl_code_combinations_kfv gcck
                      WHERE gcck.code_combination_id =
                            brv.absorption_account) absorption_acct_segment7,
                    (SELECT segment10
                       FROM gl_code_combinations_kfv gcck
                      WHERE gcck.code_combination_id =
                            brv.absorption_account) absorption_acct_segment10,
                    (SELECT segment1
                       FROM gl_code_combinations_kfv gcck
                      WHERE gcck.code_combination_id =
                            brv.rate_variance_account) variance_acct_segment1,
                    (SELECT segment2
                       FROM gl_code_combinations_kfv gcck
                      WHERE gcck.code_combination_id =
                            brv.rate_variance_account) variance_acct_segment2,
                    (SELECT segment3
                       FROM gl_code_combinations_kfv gcck
                      WHERE gcck.code_combination_id =
                            brv.rate_variance_account) variance_acct_segment3,
                    (SELECT segment4
                       FROM gl_code_combinations_kfv gcck
                      WHERE gcck.code_combination_id =
                            brv.rate_variance_account) variance_acct_segment4,
                    (SELECT segment5
                       FROM gl_code_combinations_kfv gcck
                      WHERE gcck.code_combination_id =
                            brv.rate_variance_account) variance_acct_segment5,
                    (SELECT segment6
                       FROM gl_code_combinations_kfv gcck
                      WHERE gcck.code_combination_id =
                            brv.rate_variance_account) variance_acct_segment6,
                    (SELECT segment7
                       FROM gl_code_combinations_kfv gcck
                      WHERE gcck.code_combination_id =
                            brv.rate_variance_account) variance_acct_segment7,
                    (SELECT segment10
                       FROM gl_code_combinations_kfv gcck
                      WHERE gcck.code_combination_id =
                            brv.rate_variance_account) variance_acct_segment10,
                    crov.cost_type,
                    crov.cost_type_desc cost_type_desc_overhead,
                    crov.overhead_code,
                    crov.overhead_desc,
                    crcv.cost_type_code,
                    crcv.cost_type_desc,
                    crcv.resource_rate,
                    brv.competence_id competence,
                    brv.rating_level_id skill,
                    brv.qualification_type_id qualification,
                    brv.batchable,
                    brv.min_batch_capacity,
                    brv.max_batch_capacity,
                    brv.batch_capacity_uom,
                    brv.batch_window,
                    brv.batch_window_uom
      FROM bom_resources_v brv,
           (SELECT cost_type,
                   cost_type_desc,
                   overhead_code,
                   overhead_desc,
                   resource_id
              FROM cst_resource_overheads_v) crov,
           cst_resource_costs_v crcv,
           bom_operational_routings_v borv,
           bom_operation_sequences_v bosv,
           bom_operation_resources_v bor
     WHERE brv.resource_id = crov.resource_id(+)
       AND brv.resource_id = crcv.resource_id(+)
       AND brv.resource_id = bor.resource_id
       AND borv.routing_sequence_id = bosv.routing_sequence_id
       AND bosv.operation_sequence_id = bor.operation_sequence_id(+)
          --AND brv.borvource_code = '109649-LBR'
          --AND BRV.ORGANIZATION_ID = 739
       AND brv.organization_id IN
           (SELECT (substr(TRIM(meaning), 1, instr(TRIM(meaning), '-') - 1)) v_org_id
              FROM fnd_lookup_values
             WHERE lookup_type = 'XXS3_COMMON_EXTRACT_LKP'
               AND substr(TRIM(meaning), instr(TRIM(meaning), '-') + 1) =
                   'RESOURCE'
               AND substr(TRIM(lookup_code),
                          instr(TRIM(lookup_code), '-') + 1) = 'RESOURCE'
               AND enabled_flag = 'Y'
               AND description = 'Inventoryorg'
               AND LANGUAGE = userenv('LANG')
               AND trunc(SYSDATE) BETWEEN
                   nvl(start_date_active, trunc(SYSDATE)) AND
                   nvl(end_date_active, trunc(SYSDATE)))
       AND brv.disable_date IS NULL;

    CURSOR c_resource IS
      SELECT *
      FROM   xxs3_ptm_bom_resource
      WHERE  process_flag = 'N';

  BEGIN

    x_retcode := 0;
    x_errbuf  := 'COMPLETE';

    DELETE FROM xxs3_ptm_bom_resource;

    FOR i IN c_resource_extract LOOP

      INSERT INTO xxs3_ptm_bom_resource
      VALUES
        (xxs3_ptm_bom_resource_seq.NEXTVAL,
         SYSDATE,
         'N',
         NULL,
         NULL,
         i.resource_id,
         i.organization_code,
         NULL,
         i.resource_code,
         i.disable_date,
         i.description,
         i.TYPE,
         i.uom,
         i.charge_type,
         i.basis,
         i.expenditure_type,
         i.attribute1,
         i.attribute2,
         i.attribute3,
         i.attribute4,
         i.attribute5,
         i.attribute6,
         i.attribute7,
         i.attribute8,
         i.attribute9,
         i.attribute10,
         i.attribute11,
         i.attribute12,
         i.attribute13,
         i.attribute14,
         i.attribute15,
         i.attribute_category,
         i.supply_subinventory,
         i.supply_locator_id,
         i.outside_processing_flag,
         i.outside_processing_item,
         i.billing_item,
         i.allow_costs_flag,
         i.default_activity,
         i.standard_rate_flag,
         i.absorption_account,
         i.absorption_acct_segment1,
         i.absorption_acct_segment2,
         i.absorption_acct_segment3,
         i.absorption_acct_segment4,
         i.absorption_acct_segment5,
         i.absorption_acct_segment6,
         i.absorption_acct_segment7,
         i.absorption_acct_segment10,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         i.variance_account,
         i.variance_acct_segment1,
         i.variance_acct_segment2,
         i.variance_acct_segment3,
         i.variance_acct_segment4,
         i.variance_acct_segment5,
         i.variance_acct_segment6,
         i.variance_acct_segment7,
         i.variance_acct_segment10,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         i.cost_type,
         i.cost_type_desc_overhead,
         i.overhead_code,
         i.overhead_desc,
         i.cost_type_code,
         i.cost_type_desc,
         i.resource_rate,
         i.competence,
         i.skill,
         i.qualification,
         i.batchable,
         i.min_batch_capacity,
         i.max_batch_capacity,
         i.batch_capacity_uom,
         i.batch_window,
         i.batch_window_uom,
         NULL,
         NULL,
         NULL,
         NULL);

    END LOOP;

    COMMIT;
    fnd_file.put_line(fnd_file.log, 'Loading complete');

    FOR k IN c_resource LOOP

      --Org code transformation

      xxs3_data_transform_util_pkg.transform(p_mapping_type => 'inventory_org', p_stage_tab => 'XXS3_PTM_BOM_RESOURCE', --Staging Table Name
                                              p_stage_primary_col => 'XX_RESOURCE_ID', --Staging Table Primary Column Name
                                              p_stage_primary_col_val => k.xx_resource_id, --Staging Table Primary Column Value
                                              p_legacy_val => k.organization_code, --Legacy Value
                                              p_stage_col => 'S3_ORGANIZATION_CODE', --Staging Table Name
                                              p_err_code => l_err_code, -- Output error code
                                              p_err_msg => l_err_msg);

      --CoA Transform
      IF k.absorption_account IS NOT NULL THEN
        /*xxs3_data_transform_util_pkg.coa_transform(p_field_name => 'ABSORPTION_ACCOUNT', p_legacy_company_val => k.absorption_acct_segment1, --Legacy Company Value
                                                    p_legacy_department_val => k.absorption_acct_segment2, --Legacy Department Value
                                                    p_legacy_account_val => k.absorption_acct_segment3, --Legacy Account Value
                                                    p_legacy_product_val => k.absorption_acct_segment5, --Legacy Product Value
                                                    p_legacy_location_val => k.absorption_acct_segment6, --Legacy Location Value
                                                    p_legacy_intercompany_val => k.absorption_acct_segment7, --Legacy Intercompany Value
                                                    p_legacy_division_val => k.absorption_acct_segment10, --Legacy Division Value
                                                    p_item_number => k.outside_processing_item, p_s3_gl_string => l_s3_gl_string, p_err_code => l_output_code, p_err_msg => l_output); --Output Message

        xxs3_data_transform_util_pkg.coa_update(p_gl_string => l_s3_gl_string, p_stage_tab => 'XXS3_PTM_BOM_RESOURCE', p_stage_primary_col => 'XX_RESOURCE_ID', p_stage_primary_col_val => k.xx_resource_id, p_stage_company_col => 's3_Absorption_acct_segment1', p_stage_business_unit_col => 's3_Absorption_acct_segment2', p_stage_department_col => 's3_Absorption_acct_segment3', p_stage_account_col => 's3_Absorption_acct_segment4', p_stage_product_line_col => 's3_Absorption_acct_segment5', p_stage_location_col => 's3_Absorption_acct_segment6', p_stage_intercompany_col => 's3_Absorption_acct_segment7', p_stage_future_col => 's3_Absorption_acct_segment8', p_coa_err_msg => l_output, p_err_code => l_output_code_coa_update, p_err_msg => l_output_coa_update);
*/
     --05th December(New CoA change) --
     
     xxs3_coa_transform_pkg.coa_transform(p_field_name => 'ABSORPTION_ACCOUNT'
                                            ,p_legacy_company_val => k.absorption_acct_segment1 --Legacy Company Value
                                            ,p_legacy_department_val => k.absorption_acct_segment2 --Legacy Department Value
                                            ,p_legacy_account_val => k.absorption_acct_segment3 --Legacy Account Value
                                            ,p_legacy_product_val => k.absorption_acct_segment5 --Legacy Product Value
                                            ,p_legacy_location_val => k.absorption_acct_segment6 --Legacy Location Value
                                            ,p_legacy_intercompany_val => k.absorption_acct_segment7 --Legacy Intercompany Value
                                            ,p_legacy_division_val => k.absorption_acct_segment10 --Legacy Division Value
                                            ,p_item_number => k.outside_processing_item
                                            ,p_s3_org => NULL
                                            ,p_trx_type => 'ALL'
                                            ,p_set_of_books_id => NULL
                                            ,p_debug_flag => 'N'
                                            ,p_s3_gl_string => l_s3_gl_string
                                            ,p_err_code => l_output_code
                                            ,p_err_msg => l_output);
      
        xxs3_coa_transform_pkg.coa_update(p_gl_string => l_s3_gl_string, 
                                          p_stage_tab => 'XXS3_PTM_BOM_RESOURCE', 
                                          p_stage_primary_col => 'XX_RESOURCE_ID', 
                                          p_stage_primary_col_val => k.xx_resource_id, 
                                          p_stage_company_col => 's3_Absorption_acct_segment1', 
                                          p_stage_business_unit_col => 's3_Absorption_acct_segment2', 
                                          p_stage_department_col => 's3_Absorption_acct_segment3', 
                                          p_stage_account_col => 's3_Absorption_acct_segment4', 
                                          p_stage_product_line_col => 's3_Absorption_acct_segment5', 
                                          p_stage_location_col => 's3_Absorption_acct_segment6', 
                                          p_stage_intercompany_col => 's3_Absorption_acct_segment7', 
                                          p_stage_future_col => 's3_Absorption_acct_segment8', 
                                          p_coa_err_msg => l_output, 
                                          p_err_code => l_output_code_coa_update, 
                                          p_err_msg => l_output_coa_update);
     
     --05th December(New CoA change)  --

      END IF;

      IF k.variance_account IS NOT NULL THEN

        /*xxs3_data_transform_util_pkg.coa_transform(p_field_name => 'VARIANCE_ACCOUNT', p_legacy_company_val => k.variance_acct_segment1, --Legacy Company Value
                                                    p_legacy_department_val => k.variance_acct_segment2, --Legacy Department Value
                                                    p_legacy_account_val => k.variance_acct_segment3, --Legacy Account Value
                                                    p_legacy_product_val => k.variance_acct_segment5, --Legacy Product Value
                                                    p_legacy_location_val => k.variance_acct_segment6, --Legacy Location Value
                                                    p_legacy_intercompany_val => k.variance_acct_segment7, --Legacy Intercompany Value
                                                    p_legacy_division_val => k.variance_acct_segment10, --Legacy Division Value
                                                    p_item_number => k.outside_processing_item, p_s3_gl_string => l_s3_gl_string, p_err_code => l_output_code, p_err_msg => l_output); --Output Message

        xxs3_data_transform_util_pkg.coa_update(p_gl_string => l_s3_gl_string, p_stage_tab => 'XXS3_PTM_BOM_RESOURCE', p_stage_primary_col => 'XX_RESOURCE_ID', p_stage_primary_col_val => k.xx_resource_id, p_stage_company_col => 's3_Variance_acct_segment1', p_stage_business_unit_col => 's3_Variance_acct_segment2', p_stage_department_col => 's3_Variance_acct_segment3', p_stage_account_col => 's3_Variance_acct_segment4', p_stage_product_line_col => 's3_Variance_acct_segment5', p_stage_location_col => 's3_Variance_acct_segment6', p_stage_intercompany_col => 's3_Variance_acct_segment7', p_stage_future_col => 's3_Variance_acct_segment8', p_coa_err_msg => l_output, p_err_code => l_output_code_coa_update, p_err_msg => l_output_coa_update);*/
        
        --05th December(New CoA change) --
        xxs3_coa_transform_pkg.coa_transform(p_field_name => 'VARIANCE_ACCOUNT'
                                            ,p_legacy_company_val => k.variance_acct_segment1 --Legacy Company Value
                                            ,p_legacy_department_val => k.variance_acct_segment2 --Legacy Department Value
                                            ,p_legacy_account_val => k.variance_acct_segment3 --Legacy Account Value
                                            ,p_legacy_product_val => k.variance_acct_segment5 --Legacy Product Value
                                            ,p_legacy_location_val => k.variance_acct_segment6 --Legacy Location Value
                                            ,p_legacy_intercompany_val => k.variance_acct_segment7 --Legacy Intercompany Value
                                            ,p_legacy_division_val => k.variance_acct_segment10 --Legacy Division Value
                                            ,p_item_number => k.outside_processing_item
                                            ,p_s3_org => NULL
                                            ,p_trx_type => 'ALL'
                                            ,p_set_of_books_id => NULL
                                            ,p_debug_flag => 'N'
                                            ,p_s3_gl_string => l_s3_gl_string
                                            ,p_err_code => l_output_code
                                            ,p_err_msg => l_output);
      
        xxs3_coa_transform_pkg.coa_update(p_gl_string => l_s3_gl_string, 
                                          p_stage_tab => 'XXS3_PTM_BOM_RESOURCE', 
                                          p_stage_primary_col => 'XX_RESOURCE_ID', 
                                          p_stage_primary_col_val => k.xx_resource_id, 
                                          p_stage_company_col => 's3_Variance_acct_segment1', 
                                          p_stage_business_unit_col => 's3_Variance_acct_segment2', 
                                          p_stage_department_col => 's3_Variance_acct_segment3', 
                                          p_stage_account_col => 's3_Variance_acct_segment4', 
                                          p_stage_product_line_col => 's3_Variance_acct_segment5', 
                                          p_stage_location_col => 's3_Variance_acct_segment6', 
                                          p_stage_intercompany_col => 's3_Variance_acct_segment7', 
                                          p_stage_future_col => 's3_Variance_acct_segment8', 
                                          p_coa_err_msg => l_output, 
                                          p_err_code => l_output_code_coa_update, 
                                          p_err_msg => l_output_coa_update);
        
        --05th December(New CoA change) --

      END IF;
    END LOOP;

    COMMIT;

  EXCEPTION

    WHEN OTHERS THEN
      x_retcode        := 2;
      x_errbuf         := 'Unexpected error: ' || SQLERRM;
      l_status_message := SQLCODE || chr(10) || SQLERRM;
      fnd_file.put_line(fnd_file.log, 'Unexpected error during data extraction : ' ||
                         chr(10) || l_status_message);
      fnd_file.put_line(fnd_file.log, '--------------------------------------');

  END bom_resource_extract_data;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required Bom Routing fields and insert into
  --           staging table XXS3_PTM_BOM_ROUTING
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0  012/07/2016  Debarati Banerjee            Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE bom_routing_extract_data(x_errbuf  OUT VARCHAR2,
                                     x_retcode OUT NUMBER) IS

    l_errbuf             VARCHAR2(2000);
    l_retcode            VARCHAR2(1);
    l_requestor          NUMBER;
    l_program_short_name VARCHAR2(100);
    l_status_message     VARCHAR2(4000);
    l_output             VARCHAR2(4000);
    l_file               utl_file.file_type;
    l_file1              utl_file.file_type;
    l_file2              utl_file.file_type;
    l_file_path          VARCHAR2(100);
    l_file_name          VARCHAR2(100);
    l_file_name1         VARCHAR2(100);
    l_file_name2         VARCHAR2(100);
    l_make_buy VARCHAR2(10);
    l_bom      VARCHAR2(10);
    l_err_code VARCHAR2(4000);
    l_err_msg  VARCHAR2(4000);

    CURSOR c_routing_extract IS
    SELECT borv.routing_sequence_id,
           borv.assembly_item_id,
           borv.organization_id,
           (SELECT organization_code
              FROM mtl_parameters
             WHERE organization_id = borv.organization_id) organization,
           (SELECT segment1
              FROM mtl_system_items_b
             WHERE inventory_item_id = borv.assembly_item_id
               AND organization_id = borv.organization_id) item_number,
           borv.alternate_routing_designator,
           borv.ctp_flag,
           (SELECT MAX(process_revision)
              FROM mtl_rtg_item_revisions
             WHERE organization_id = borv.organization_id
               AND inventory_item_id = borv.assembly_item_id) current_revision,
           borv.priority,
           borv.serialization_start_op,
           borv.completion_subinventory,
           borv.completion_locator_id,
           (SELECT concatenated_segments
              FROM mtl_item_locations_kfv
             WHERE inventory_location_id = borv.completion_locator_id) completion_locator,
           borv.routing_comment,
           (SELECT segment1
              FROM mtl_system_items_b
             WHERE inventory_item_id = borv.common_assembly_item_id
               AND organization_id = borv.organization_id) common_item,
           --borv.ATTRIBUTE1  H_ATTRIBUTE1 ,
           (SELECT schedule_group_name
              FROM wip_schedule_groups
             WHERE schedule_group_id = borv.attribute1) h_attribute1,
           borv.attribute2 h_attribute2,
           borv.attribute3 h_attribute3,
           borv.attribute4 h_attribute4,
           borv.attribute5 h_attribute5,
           borv.attribute6 h_attribute6,
           borv.attribute7 h_attribute7,
           borv.attribute8 h_attribute8,
           borv.attribute9 h_attribute9,
           borv.attribute10 h_attribute10,
           borv.attribute11 h_attribute11,
           borv.attribute12 h_attribute12,
           borv.attribute13 h_attribute13,
           borv.attribute14 h_attribute14,
           borv.attribute15 h_attribute15,
           bosv.operation_seq_num,
           bosv.standard_operation_code,
           bosv.reference_flag,
           bosv.department_code,
           bosv.option_dependent_flag,
           bosv.operation_lead_time_percent,
           bosv.effectivity_date,
           bosv.disable_date,
           bosv.count_point_type,
           bosv.backflush_flag,
           bosv.check_skill,
           bosv.minimum_transfer_quantity,
           bosv.yield,
           bosv.cumulative_yield,
           bosv.include_in_rollup,
           bosv.impl_cb,
           bosv.change_notice,
           bosv.operation_description,
           bosv.attribute1 o_attribute1,
           bosv.attribute2 o_attribute2,
           bosv.attribute3 o_attribute3,
           bosv.attribute4 o_attribute4,
           bosv.attribute5 o_attribute5,
           bosv.attribute6 o_attribute6,
           bosv.attribute7 o_attribute7,
           bosv.attribute8 o_attribute8,
           bosv.attribute9 o_attribute9,
           bosv.attribute10 o_attribute10,
           bosv.attribute11 o_attribute11,
           bosv.attribute12 o_attribute12,
           bosv.attribute13 o_attribute13,
           bosv.attribute14 o_attribute14,
           bosv.attribute15 o_attribute15,
           brv.resource_code,
           brv.basis_type,
           brv.usage_rate_or_amount,
           brv.available_24_hours_flag,
           brv.schedule_seq_num,
           brv.substitute_group_num,
           brv.assigned_units,
           brv.schedule_flag,
           brv.resource_offset_percent,
           brv.principle_flag,
           brv.setup_code,
           brv.activity,
           brv.standard_rate_flag,
           brv.autocharge_type,
           brv.resource_seq_num,
           brv.usage_rate_or_amount_inverse,
           brv.attribute1 r_attribute1,
           brv.attribute2 r_attribute2,
           brv.attribute3 r_attribute3,
           brv.attribute4 r_attribute4,
           brv.attribute5 r_attribute5,
           brv.attribute6 r_attribute6,
           brv.attribute7 r_attribute7,
           brv.attribute8 r_attribute8,
           brv.attribute9 r_attribute9,
           brv.attribute10 r_attribute10,
           brv.attribute11 r_attribute11,
           brv.attribute12 r_attribute12,
           brv.attribute13 r_attribute13,
           brv.attribute14 r_attribute14,
           brv.attribute15 r_attribute15
      FROM bom_operational_routings_v borv,
           bom_operation_sequences_v  bosv,
           bom_operation_resources_v  brv
     WHERE borv.routing_sequence_id = bosv.routing_sequence_id(+)
       AND bosv.operation_sequence_id = brv.operation_sequence_id(+) --22124
       AND bosv.disable_date IS NULL
          --AND BORV.ORGANIZATION_ID IN (739, 740);
       AND borv.organization_id IN
           (SELECT (substr(TRIM(meaning), 1, instr(TRIM(meaning), '-') - 1)) v_org_id
              FROM fnd_lookup_values
             WHERE lookup_type = 'XXS3_COMMON_EXTRACT_LKP'
               AND substr(TRIM(meaning), instr(TRIM(meaning), '-') + 1) =
                   'ROUTING'
               AND substr(TRIM(lookup_code),
                          instr(TRIM(lookup_code), '-') + 1) = 'ROUTING'
               AND enabled_flag = 'Y'
               AND description = 'Inventoryorg'
               AND LANGUAGE = userenv('LANG')
               AND trunc(SYSDATE) BETWEEN
                   nvl(start_date_active, trunc(SYSDATE)) AND
                   nvl(end_date_active, trunc(SYSDATE)))
           --condition to check if item exists in master item extract        
       AND EXISTS
     (SELECT l_inventory_item_id
              FROM xxs3_ptm_master_items_ext_stg
             WHERE extract_rule_name IS NOT NULL
               AND process_flag <> 'R'
               AND l_inventory_item_id = assembly_item_id
               AND legacy_organization_code IN ('UME', 'USE'));
            --condition to check if item exists in master item extract        
            
    CURSOR c_subinv IS
    SELECT COMPLETION_SUBINVENTORY,
           S3_COMPLETION_SUBINVENTORY,
           ASSEMBLY_ITEM_ID,
           ORGANIZATION_ID,
           ORGANIZATION,
           S3_ORGANIZATION,
           XX_ROUTING_SEQ_ID
      FROM XXS3_PTM_BOM_ROUTING;

    CURSOR c_transform IS
    SELECT ORGANIZATION, XX_ROUTING_SEQ_ID FROM XXS3_PTM_BOM_ROUTING;

    CURSOR c_utl_upload IS
    SELECT * FROM XXOBJT.XXS3_PTM_BOM_ROUTING;



  BEGIN

    x_retcode := 0;
    x_errbuf  := 'COMPLETE';

      BEGIN
         --Get the file path from the lookup
        SELECT TRIM(' ' from meaning) INTO l_file_path
        FROM  FND_LOOKUP_VALUES_VL
        WHERE lookup_type='XXS3_ITEM_OUT_FILE_PATH';

         --Get the file name
         l_file_name   := 'Routing_Header_Extract' || '_' || SYSDATE || '.xls';
         l_file_name1  := 'Routing_Operation_Seq_Extract' || '_' || SYSDATE || '.xls';
         l_file_name2  := 'Routing_Resource_Extract' || '_' || SYSDATE || '.xls';

          --Get the utl file open
         l_file := UTL_FILE.fopen  (l_file_path, l_file_name, 'w', 32767);
         l_file1 := UTL_FILE.fopen (l_file_path, l_file_name1, 'w', 32767);
         l_file2 := UTL_FILE.fopen (l_file_path, l_file_name2, 'w', 32767);
       EXCEPTION
             WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log, 'Invalid File Path'||SQLERRM);
        NULL;
       END;
    /*l_file    := utl_file.fopen('/UtlFiles/shared/DEV', 'ptm_routing_header_extract_06_09_2016.CSV', 'w', 32767);
    l_file1   := utl_file.fopen('/UtlFiles/shared/DEV', 'ptm_op_seq_header_06_09_2016.CSV', 'w', 32767);
    l_file2   := utl_file.fopen('/UtlFiles/shared/DEV', 'ptm_resource_extract_06_09_2016.CSV', 'w', 32767);*/

    DELETE FROM xxs3_ptm_bom_routing;

    FOR i IN c_routing_extract LOOP

      INSERT INTO xxs3_ptm_bom_routing
      VALUES
        (xxs3_ptm_bom_routing_seq.NEXTVAL,
         SYSDATE,
         'N',
         NULL,
         NULL,
         i.routing_sequence_id,
         i.assembly_item_id,
         i.organization_id,
         i.organization,
         NULL,
         i.item_number,
         i.alternate_routing_designator,
         i.ctp_flag,
         i.current_revision,
         i.priority,
         i.serialization_start_op,
         i.completion_subinventory,
         NULL,
         i.completion_locator_id,
         i.completion_locator,
         i.routing_comment,
         i.common_item,
         i.h_attribute1,
         i.h_attribute2,
         i.h_attribute3,
         i.h_attribute4,
         i.h_attribute5,
         i.h_attribute6,
         i.h_attribute7,
         i.h_attribute8,
         i.h_attribute9,
         i.h_attribute10,
         i.h_attribute11,
         i.h_attribute12,
         i.h_attribute13,
         i.h_attribute14,
         i.h_attribute15,
         i.operation_seq_num,
         i.standard_operation_code,
         i.reference_flag,
         i.department_code,
         i.option_dependent_flag,
         i.operation_lead_time_percent,
         i.effectivity_date,
         i.disable_date,
         i.count_point_type,
         i.backflush_flag,
         i.check_skill,
         i.minimum_transfer_quantity,
         i.yield,
         i.cumulative_yield,
         i.include_in_rollup,
         i.impl_cb,
         i.change_notice,
         i.operation_description,
         i.o_attribute1,
         i.o_attribute2,
         i.o_attribute3,
         i.o_attribute4,
         i.o_attribute5,
         i.o_attribute6,
         i.o_attribute7,
         i.o_attribute8,
         i.o_attribute9,
         i.o_attribute10,
         i.o_attribute11,
         i.o_attribute12,
         i.o_attribute13,
         i.o_attribute14,
         i.o_attribute15,
         i.resource_seq_num,
         i.usage_rate_or_amount_inverse,
         i.resource_code,
         i.basis_type,
         i.usage_rate_or_amount,
         i.available_24_hours_flag,
         i.schedule_seq_num,
         i.substitute_group_num,
         i.assigned_units,
         i.schedule_flag,
         i.resource_offset_percent,
         i.principle_flag,
         i.setup_code,
         i.activity,
         i.standard_rate_flag,
         i.autocharge_type,
         i.r_attribute1,
         i.r_attribute2,
         i.r_attribute3,
         i.r_attribute4,
         i.r_attribute5,
         i.r_attribute6,
         i.r_attribute7,
         i.r_attribute8,
         i.r_attribute9,
         i.r_attribute10,
         i.r_attribute11,
         i.r_attribute12,
         i.r_attribute13,
         i.r_attribute14,
         i.r_attribute15,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL,
         NULL);

    END LOOP;
    COMMIT;
    fnd_file.put_line(fnd_file.log, 'Loading complete');

    --Autocleanse

    FOR j IN c_subinv LOOP

      l_make_buy := check_item(j.assembly_item_id, j.organization_id);
      l_bom      := check_bom(j.assembly_item_id, j.organization_id);

      IF l_make_buy = 'TRUE' AND l_bom = 'TRUE' THEN
        update_completion_subinv(j.xx_routing_seq_id);
      END IF;

    END LOOP;

    FOR k IN c_subinv LOOP
      update_legacy_values(k.xx_routing_seq_id, k.completion_subinventory);
    END LOOP;

    COMMIT;

    --DQ check

    FOR l IN c_subinv LOOP
      IF l.s3_completion_subinventory NOT IN ('FG', 'FLOOR') THEN
        insert_update_routing_dq(l.xx_routing_seq_id, 'EQT-080:BOM Completion Sub Inventory AutoCorrect', 'BOM Completion Sub Inventory Auto Correct');
        l_status_message := 'ERR';
      END IF;

      IF l_status_message <> 'ERR' THEN
        UPDATE xxs3_ptm_bom_routing
        SET    process_flag = 'Y'
        WHERE  xx_routing_seq_id = l.xx_routing_seq_id;
      END IF;

    END LOOP;

    --Org code transformation
    FOR m IN c_transform LOOP
      xxs3_data_transform_util_pkg.transform(p_mapping_type => 'inventory_org', p_stage_tab => 'XXS3_PTM_BOM_ROUTING', --Staging Table Name
                                              p_stage_primary_col => 'XX_ROUTING_SEQ_ID', --Staging Table Primary Column Name
                                              p_stage_primary_col_val => m.xx_routing_seq_id, --Staging Table Primary Column Value
                                              p_legacy_val => m.organization, --Legacy Value
                                              p_stage_col => 'S3_ORGANIZATION', --Staging Table Name
                                              p_err_code => l_err_code, -- Output error code
                                              p_err_msg => l_err_msg);
    END LOOP;

    --generate csv files
    --1st
    utl_file.put(l_file, '~' || 'XX_ROUTING_SEQ_ID');
    utl_file.put(l_file, '~' || 'ASSEMBLY_ITEM_ID');
    utl_file.put(l_file, '~' || 'ORGANIZATION_ID');
    utl_file.put(l_file, '~' || 'ORGANIZATION');
    utl_file.put(l_file, '~' || 'S3_ORGANIZATION');
    utl_file.put(l_file, '~' || 'ITEM_NUMBER');
    utl_file.put(l_file, '~' || 'ALTERNATE_ROUTING_DESIGNATOR ');
    utl_file.put(l_file, '~' || 'CTP_FLAG');
    utl_file.put(l_file, '~' || 'COMPLETION_SUBINVENTORY');
    utl_file.put(l_file, '~' || 'S3_COMPLETION_SUBINVENTORY');
    utl_file.put(l_file, '~' || 'COMPLETION_LOCATOR_ID');
    utl_file.put(l_file, '~' || 'COMPLETION_LOCATOR');
    utl_file.put(l_file, '~' || 'PRIORITY');
    utl_file.put(l_file, '~' || 'SERIALIZATION_START_OP');
    utl_file.put(l_file, '~' || 'ROUTING_COMMENT');
    utl_file.put(l_file, '~' || 'CURRENT_REVISION');
    utl_file.put(l_file, '~' || 'COMMON_ITEM');
    utl_file.put(l_file, '~' || 'H_ATTRIBUTE1');
    utl_file.put(l_file, '~' || 'H_ATTRIBUTE2');
    utl_file.put(l_file, '~' || 'H_ATTRIBUTE3');
    utl_file.put(l_file, '~' || 'H_ATTRIBUTE4');
    utl_file.put(l_file, '~' || 'H_ATTRIBUTE5');
    utl_file.put(l_file, '~' || 'H_ATTRIBUTE6');
    utl_file.put(l_file, '~' || 'H_ATTRIBUTE7');
    utl_file.put(l_file, '~' || 'H_ATTRIBUTE8');
    utl_file.put(l_file, '~' || 'H_ATTRIBUTE9');
    utl_file.put(l_file, '~' || 'H_ATTRIBUTE10');
    utl_file.put(l_file, '~' || 'H_ATTRIBUTE11');
    utl_file.put(l_file, '~' || 'H_ATTRIBUTE12');
    utl_file.put(l_file, '~' || 'H_ATTRIBUTE13');
    utl_file.put(l_file, '~' || 'H_ATTRIBUTE14');
    utl_file.put(l_file, '~' || 'H_ATTRIBUTE15');
    utl_file.new_line(l_file);

    FOR c1 IN c_utl_upload LOOP
      utl_file.put(l_file, '~' || c1.xx_routing_seq_id);
      utl_file.put(l_file, '~' || c1.assembly_item_id);
      utl_file.put(l_file, '~' || c1.organization_id);
      utl_file.put(l_file, '~' || c1.organization);
      utl_file.put(l_file, '~' || c1.s3_organization);
      utl_file.put(l_file, '~' || c1.item_number);
      utl_file.put(l_file, '~' || c1.alternate_routing_designator);
      utl_file.put(l_file, '~' || c1.ctp_flag);
      utl_file.put(l_file, '~' || c1.completion_subinventory);
      utl_file.put(l_file, '~' || c1.s3_completion_subinventory);
      utl_file.put(l_file, '~' || c1.completion_locator_id);
      utl_file.put(l_file, '~' || c1.completion_locator);
      utl_file.put(l_file, '~' || c1.priority);
      utl_file.put(l_file, '~' || c1.serialization_start_op);
      utl_file.put(l_file, '~' || c1.routing_comment);
      utl_file.put(l_file, '~' || c1.current_revision);
      utl_file.put(l_file, '~' || c1.common_item);
      utl_file.put(l_file, '~' || c1.h_attribute1);
      utl_file.put(l_file, '~' || c1.h_attribute2);
      utl_file.put(l_file, '~' || c1.h_attribute3);
      utl_file.put(l_file, '~' || c1.h_attribute4);
      utl_file.put(l_file, '~' || c1.h_attribute5);
      utl_file.put(l_file, '~' || c1.h_attribute6);
      utl_file.put(l_file, '~' || c1.h_attribute7);
      utl_file.put(l_file, '~' || c1.h_attribute8);
      utl_file.put(l_file, '~' || c1.h_attribute9);
      utl_file.put(l_file, '~' || c1.h_attribute10);
      utl_file.put(l_file, '~' || c1.h_attribute11);
      utl_file.put(l_file, '~' || c1.h_attribute12);
      utl_file.put(l_file, '~' || c1.h_attribute13);
      utl_file.put(l_file, '~' || c1.h_attribute14);
      utl_file.put(l_file, '~' || c1.h_attribute15);

      utl_file.new_line(l_file);
    END LOOP;
    utl_file.fclose(l_file);

    --2nd

    utl_file.put(l_file1, '~' || 'ASSEMBLY_ITEM_ID');
    utl_file.put(l_file1, '~' || 'OPERATION_SEQ_NUM');
    utl_file.put(l_file1, '~' || 'STANDARD_OPERATION_CODE');
    utl_file.put(l_file1, '~' || 'ORGANIZATION');
    utl_file.put(l_file1, '~' || 'S3_ORGANIZATION');
    utl_file.put(l_file1, '~' || 'REFERENCE_FLAG');
    utl_file.put(l_file1, '~' || 'DEPARTMENT_CODE');
    utl_file.put(l_file1, '~' || 'OPTION_DEPENDENT_FLAG');
    utl_file.put(l_file1, '~' || 'OPERATION_LEAD_TIME_PERCENT');
    utl_file.put(l_file1, '~' || 'EFFECTIVITY_DATE');
    utl_file.put(l_file1, '~' || 'DISABLE_DATE');
    utl_file.put(l_file1, '~' || 'COUNT_POINT_TYPE');
    utl_file.put(l_file1, '~' || 'BACKFLUSH_FLAG');
    utl_file.put(l_file1, '~' || 'CHECK_SKILL');
    utl_file.put(l_file1, '~' || 'MINIMUM_TRANSFER_QUANTITY');
    utl_file.put(l_file1, '~' || 'YIELD');
    utl_file.put(l_file1, '~' || 'CUMULATIVE_YIELD');
    utl_file.put(l_file1, '~' || 'INCLUDE_IN_ROLLUP');
    utl_file.put(l_file1, '~' || 'IMPL_CB');
    utl_file.put(l_file1, '~' || 'CHANGE_NOTICE');
    utl_file.put(l_file1, '~' || 'OPERATION_DESCRIPTION');
    utl_file.put(l_file1, '~' || 'item_number');
    utl_file.put(l_file1, '~' || 'O_ATTRIBUTE1');
    utl_file.put(l_file1, '~' || 'O_ATTRIBUTE2');
    utl_file.put(l_file1, '~' || 'O_ATTRIBUTE3');
    utl_file.put(l_file1, '~' || 'O_ATTRIBUTE4');
    utl_file.put(l_file1, '~' || 'O_ATTRIBUTE5');
    utl_file.put(l_file1, '~' || 'O_ATTRIBUTE6');
    utl_file.put(l_file1, '~' || 'O_ATTRIBUTE7');
    utl_file.put(l_file1, '~' || 'O_ATTRIBUTE8');
    utl_file.put(l_file1, '~' || 'O_ATTRIBUTE9');
    utl_file.put(l_file1, '~' || 'O_ATTRIBUTE10');
    utl_file.put(l_file1, '~' || 'O_ATTRIBUTE11');
    utl_file.put(l_file1, '~' || 'O_ATTRIBUTE12');
    utl_file.put(l_file1, '~' || 'O_ATTRIBUTE13');
    utl_file.put(l_file1, '~' || 'O_ATTRIBUTE14');
    utl_file.put(l_file1, '~' || 'O_ATTRIBUTE15');

    utl_file.new_line(l_file1);

    FOR c1 IN c_utl_upload LOOP
      utl_file.put(l_file1, '~' || c1.assembly_item_id);
      utl_file.put(l_file1, '~' || c1.operation_seq_num);
      utl_file.put(l_file1, '~' || c1.standard_operation_code);
      utl_file.put(l_file1, '~' || c1.organization);
      utl_file.put(l_file1, '~' || c1.s3_organization);
      utl_file.put(l_file1, '~' || c1.reference_flag);
      utl_file.put(l_file1, '~' || c1.department_code);
      utl_file.put(l_file1, '~' || c1.option_dependent_flag);
      utl_file.put(l_file1, '~' || c1.operation_lead_time_percent);
      utl_file.put(l_file1, '~' || c1.effectivity_date);
      utl_file.put(l_file1, '~' || c1.disable_date);
      utl_file.put(l_file1, '~' || c1.count_point_type);
      utl_file.put(l_file1, '~' || c1.backflush_flag);
      utl_file.put(l_file1, '~' || c1.check_skill);
      utl_file.put(l_file1, '~' || c1.minimum_transfer_quantity);
      utl_file.put(l_file1, '~' || c1.yield);
      utl_file.put(l_file1, '~' || c1.cumulative_yield);
      utl_file.put(l_file1, '~' || c1.include_in_rollup);
      utl_file.put(l_file1, '~' || c1.impl_cb);
      utl_file.put(l_file1, '~' || c1.change_notice);
      utl_file.put(l_file1, '~' || c1.operation_description);
      utl_file.put(l_file1, '~' || c1.item_number);
      utl_file.put(l_file1, '~' || c1.o_attribute1);
      utl_file.put(l_file1, '~' || c1.o_attribute2);
      utl_file.put(l_file1, '~' || c1.o_attribute3);
      utl_file.put(l_file1, '~' || c1.o_attribute4);
      utl_file.put(l_file1, '~' || c1.o_attribute5);
      utl_file.put(l_file1, '~' || c1.o_attribute6);
      utl_file.put(l_file1, '~' || c1.o_attribute7);
      utl_file.put(l_file1, '~' || c1.o_attribute8);
      utl_file.put(l_file1, '~' || c1.o_attribute9);
      utl_file.put(l_file1, '~' || c1.o_attribute10);
      utl_file.put(l_file1, '~' || c1.o_attribute11);
      utl_file.put(l_file1, '~' || c1.o_attribute12);
      utl_file.put(l_file1, '~' || c1.o_attribute13);
      utl_file.put(l_file1, '~' || c1.o_attribute14);
      utl_file.put(l_file1, '~' || c1.o_attribute15);

      utl_file.new_line(l_file1);
    END LOOP;
      utl_file.fclose(l_file1);

    --3rd

    utl_file.put(l_file2, '~' || 'ASSEMBLY_ITEM_ID');
    utl_file.put(l_file2, '~' || 'OPERATION_SEQ_NUM');
    utl_file.put(l_file2, '~' || 'RESOURCE_CODE');
    utl_file.put(l_file2, '~' || 'RESOURCE_SEQ_NUM');
    utl_file.put(l_file2, '~' || 'item_number');
    utl_file.put(l_file2, '~' || 'ORGANIZATION');
    utl_file.put(l_file2, '~' || 'S3_ORGANIZATION');
    utl_file.put(l_file2, '~' || 'EFFECTIVITY_DATE');
    utl_file.put(l_file2, '~' || 'BASIS_TYPE');
    utl_file.put(l_file2, '~' || 'USAGE_RATE_OR_AMOUNT');
    utl_file.put(l_file2, '~' || 'USAGE_RATE_OR_AMOUNT_INVERSE');
    utl_file.put(l_file2, '~' || 'AVAILABLE_24_HOURS_FLAG');
    utl_file.put(l_file2, '~' || 'SCHEDULE_SEQ_NUM');
    utl_file.put(l_file2, '~' || 'SUBSTITUTE_GROUP_NUM');
    utl_file.put(l_file2, '~' || 'ASSIGNED_UNITS');
    utl_file.put(l_file2, '~' || 'SCHEDULE_FLAG');
    utl_file.put(l_file2, '~' || 'RESOURCE_OFFSET_PERCENT');
    utl_file.put(l_file2, '~' || 'PRINCIPLE_FLAG');
    utl_file.put(l_file2, '~' || 'SETUP_CODE');
    utl_file.put(l_file2, '~' || 'ACTIVITY');
    utl_file.put(l_file2, '~' || 'STANDARD_RATE_FLAG');
    utl_file.put(l_file2, '~' || 'AUTOCHARGE_TYPE');
    utl_file.put(l_file2, '~' || 'R_ATTRIBUTE1');
    utl_file.put(l_file2, '~' || 'R_ATTRIBUTE2');
    utl_file.put(l_file2, '~' || 'R_ATTRIBUTE3');
    utl_file.put(l_file2, '~' || 'R_ATTRIBUTE4');
    utl_file.put(l_file2, '~' || 'R_ATTRIBUTE5');
    utl_file.put(l_file2, '~' || 'R_ATTRIBUTE6');
    utl_file.put(l_file2, '~' || 'R_ATTRIBUTE7');
    utl_file.put(l_file2, '~' || 'R_ATTRIBUTE8');
    utl_file.put(l_file2, '~' || 'R_ATTRIBUTE9');
    utl_file.put(l_file2, '~' || 'R_ATTRIBUTE10');
    utl_file.put(l_file2, '~' || 'R_ATTRIBUTE11');
    utl_file.put(l_file2, '~' || 'R_ATTRIBUTE12');
    utl_file.put(l_file2, '~' || 'R_ATTRIBUTE13');
    utl_file.put(l_file2, '~' || 'R_ATTRIBUTE14');
    utl_file.put(l_file2, '~' || 'R_ATTRIBUTE15');

    utl_file.new_line(l_file2);

    FOR c1 IN c_utl_upload LOOP
      utl_file.put(l_file2, '~' || c1.assembly_item_id);
      utl_file.put(l_file2, '~' || c1.operation_seq_num);
      utl_file.put(l_file2, '~' || c1.resource_code);
      utl_file.put(l_file2, '~' || c1.resource_seq_num);
      utl_file.put(l_file2, '~' || c1.item_number);
      utl_file.put(l_file2, '~' || c1.organization);
      utl_file.put(l_file2, '~' || c1.s3_organization);
      utl_file.put(l_file2, '~' || c1.effectivity_date);
      utl_file.put(l_file2, '~' || c1.basis_type);
      utl_file.put(l_file2, '~' || c1.usage_rate_or_amount);
      utl_file.put(l_file2, '~' || c1.usage_rate_or_amount_inverse);
      utl_file.put(l_file2, '~' || c1.available_24_hours_flag);
      utl_file.put(l_file2, '~' || c1.schedule_seq_num);
      utl_file.put(l_file2, '~' || c1.substitute_group_num);
      utl_file.put(l_file2, '~' || c1.assigned_units);
      utl_file.put(l_file2, '~' || c1.schedule_flag);
      utl_file.put(l_file2, '~' || c1.resource_offset_percent);
      utl_file.put(l_file2, '~' || c1.principle_flag);
      utl_file.put(l_file2, '~' || c1.setup_code);
      utl_file.put(l_file2, '~' || c1.activity);
      utl_file.put(l_file2, '~' || c1.standard_rate_flag);
      utl_file.put(l_file2, '~' || c1.autocharge_type);
      utl_file.put(l_file2, '~' || c1.r_attribute1);
      utl_file.put(l_file2, '~' || c1.r_attribute2);
      utl_file.put(l_file2, '~' || c1.r_attribute3);
      utl_file.put(l_file2, '~' || c1.r_attribute4);
      utl_file.put(l_file2, '~' || c1.r_attribute5);
      utl_file.put(l_file2, '~' || c1.r_attribute6);
      utl_file.put(l_file2, '~' || c1.r_attribute7);
      utl_file.put(l_file2, '~' || c1.r_attribute8);
      utl_file.put(l_file2, '~' || c1.r_attribute9);
      utl_file.put(l_file2, '~' || c1.r_attribute10);
      utl_file.put(l_file2, '~' || c1.r_attribute11);
      utl_file.put(l_file2, '~' || c1.r_attribute12);
      utl_file.put(l_file2, '~' || c1.r_attribute13);
      utl_file.put(l_file2, '~' || c1.r_attribute14);
      utl_file.put(l_file2, '~' || c1.r_attribute15);

      utl_file.new_line(l_file2);

    END LOOP;
    utl_file.fclose(l_file2);

  EXCEPTION

    WHEN OTHERS THEN
      x_retcode        := 2;
      x_errbuf         := 'Unexpected error: ' || SQLERRM;
      l_status_message := SQLCODE || chr(10) || SQLERRM;
      fnd_file.put_line(fnd_file.log, 'Unexpected error during data extraction : ' ||
                         chr(10) || l_status_message);
      fnd_file.put_line(fnd_file.log, '--------------------------------------');

  END bom_routing_extract_data;

  --------------------------------------------------------------------
  --  name:              data_transform_report
  --  create by:         Debarati banerjee
  --  Revision:          1.0
  --  creation date:     11/07/2016
  --------------------------------------------------------------------
  --  purpose :          write data transform report to output
  --
  --------------------------------------------------------------------
  --  ver  date          name                   desc
  --  1.0  13/05/2016    Debarati banerjee     report data transform
  --------------------------------------------------------------------

  PROCEDURE data_transform_report(p_entity VARCHAR2) IS

    l_delimiter     VARCHAR2(5) := '~';
    l_err_msg       VARCHAR2(2000);
    l_count_success NUMBER;
    l_count_fail    NUMBER;

    CURSOR c_report_dept IS
    SELECT xpbd.department_code,
           xpbd.department_id,
           xpbd.xx_department_id,
           xpbd.organization,
           xpbd.s3_organization,
           xpbd.transform_status,
           xpbd.transform_error
      FROM xxs3_ptm_bom_dept xpbd
     WHERE xpbd.transform_status IN ('PASS', 'FAIL');

    CURSOR c_report_resource IS
    SELECT xpbr.xx_resource_id,
           xpbr.resource_id,
           xpbr.resource_code,
           xpbr.organization_code,
           xpbr.s3_organization_code,
           xpbr.absorption_acct_segment1,
           xpbr.absorption_acct_segment2,
           xpbr.absorption_acct_segment3,
           xpbr.absorption_acct_segment4,
           xpbr.absorption_acct_segment5,
           xpbr.absorption_acct_segment6,
           xpbr.absorption_acct_segment7,
           xpbr.absorption_acct_segment10,
           xpbr.s3_absorption_acct_segment1,
           xpbr.s3_absorption_acct_segment2,
           xpbr.s3_absorption_acct_segment3,
           xpbr.s3_absorption_acct_segment4,
           xpbr.s3_absorption_acct_segment5,
           xpbr.s3_absorption_acct_segment6,
           xpbr.s3_absorption_acct_segment7,
           xpbr.s3_absorption_acct_segment8,
           xpbr.variance_acct_segment1,
           xpbr.variance_acct_segment2,
           xpbr.variance_acct_segment3,
           xpbr.variance_acct_segment4,
           xpbr.variance_acct_segment5,
           xpbr.variance_acct_segment6,
           xpbr.variance_acct_segment7,
           xpbr.variance_acct_segment10,
           xpbr.s3_variance_acct_segment1,
           xpbr.s3_variance_acct_segment2,
           xpbr.s3_variance_acct_segment3,
           xpbr.s3_variance_acct_segment4,
           xpbr.s3_variance_acct_segment5,
           xpbr.s3_variance_acct_segment6,
           xpbr.s3_variance_acct_segment7,
           xpbr.s3_variance_acct_segment8,
           xpbr.transform_status,
           xpbr.transform_error
      FROM xxs3_ptm_bom_resource xpbr
     WHERE xpbr.transform_status IN ('PASS', 'FAIL');

    CURSOR c_report_routing IS
    SELECT xpbd.item_number,
           xpbd.routing_sequence_id,
           xpbd.xx_routing_seq_id,
           xpbd.organization,
           xpbd.s3_organization,
           xpbd.transform_status,
           xpbd.transform_error
      FROM xxs3_ptm_bom_routing xpbd
     WHERE xpbd.transform_status IN ('PASS', 'FAIL');



  BEGIN
    /*
    x_err_code := 0;
    x_err_msg  := '';*/
    IF p_entity = 'DEPT' THEN
      SELECT COUNT(1)
      INTO   l_count_success
      FROM   xxs3_ptm_bom_dept xpbd
      WHERE  xpbd.transform_status = 'PASS';

      SELECT COUNT(1)
      INTO   l_count_fail
      FROM   xxs3_ptm_bom_dept xpbd
      WHERE  xpbd.transform_status = 'FAIL';

      fnd_file.put_line(fnd_file.output, rpad('Report name = Data Transformation Report' ||
                              l_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('========================================' ||
                              l_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Data Migration Object Name = ' ||
                              p_entity || l_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, '');
      fnd_file.put_line(fnd_file.output, rpad('Run date and time:    ' ||
                              to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') ||
                              l_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Total Record Count Success = ' ||
                              l_count_success ||
                              l_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Total Record Count Failure = ' ||
                              l_count_fail || l_delimiter, 100, ' '));

      fnd_file.put_line(fnd_file.output, '');

      fnd_file.put_line(fnd_file.output, rpad('Track Name', 10, ' ') ||
                         l_delimiter ||
                         rpad('Entity Name', 15, ' ') ||
                         l_delimiter ||
                         rpad('XX Department ID  ', 20, ' ') ||
                         l_delimiter ||
                         rpad('Department ID', 15, ' ') ||
                         l_delimiter ||
                         rpad('Department Code', 20, ' ') ||
                         l_delimiter ||
                         rpad('ORGANIZATION', 25, ' ') ||
                         l_delimiter ||
                         rpad('S3_ORGANIZATION', 25, ' ') ||
                         l_delimiter ||
                         rpad('Status', 10, ' ') ||
                         l_delimiter ||
                         rpad('Error Message', 2000, ' '));

      FOR r_data IN c_report_dept LOOP
        fnd_file.put_line(fnd_file.output, rpad('PTM', 10, ' ') ||
                           l_delimiter ||
                           rpad('DEPARTMENT', 15, ' ') ||
                           l_delimiter ||
                           rpad(r_data.xx_department_id, 20, ' ') ||
                           l_delimiter ||
                           rpad(r_data.department_id, 15, ' ') ||
                           l_delimiter ||
                           rpad(r_data.department_code, 10, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.organization, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_organization, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(r_data.transform_status, 10, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.transform_error, 'NULL'), 2000, ' '));
      END LOOP;

      fnd_file.put_line(fnd_file.output, '');
      fnd_file.put_line(fnd_file.output, 'Stratasys Confidential' ||
                         l_delimiter);

    ELSIF p_entity = 'RESOURCE' THEN

      SELECT COUNT(1)
      INTO   l_count_success
      FROM   xxs3_ptm_bom_resource xpbr
      WHERE  xpbr.transform_status = 'PASS';

      SELECT COUNT(1)
      INTO   l_count_fail
      FROM   xxs3_ptm_bom_resource xpbr
      WHERE  xpbr.transform_status = 'FAIL';

      fnd_file.put_line(fnd_file.output, rpad('Report name = Data Transformation Report' ||
                              l_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('========================================' ||
                              l_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Data Migration Object Name = ' ||
                              p_entity || l_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, '');
      fnd_file.put_line(fnd_file.output, rpad('Run date and time:    ' ||
                              to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') ||
                              l_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Total Record Count Success = ' ||
                              l_count_success ||
                              l_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Total Record Count Failure = ' ||
                              l_count_fail || l_delimiter, 100, ' '));

      fnd_file.put_line(fnd_file.output, '');

      fnd_file.put_line(fnd_file.output, rpad('Track Name', 10, ' ') ||
                         l_delimiter ||
                         rpad('Entity Name', 15, ' ') ||
                         l_delimiter ||
                         rpad('XX Resource ID  ', 14, ' ') ||
                         l_delimiter ||
                         rpad('Resource ID', 15, ' ') ||
                         l_delimiter ||
                         rpad('Resource Code', 15, ' ') ||
                         l_delimiter ||
                         rpad('Organization Code', 30, ' ') ||
                         l_delimiter ||
                         rpad('S3 Organization Code', 30, ' ') ||
                         l_delimiter ||
                         rpad('ABSORPTION_SEGMENT1', 25, ' ') ||
                         l_delimiter ||
                         rpad('ABSORPTION_SEGMENT2', 25, ' ') ||
                         l_delimiter ||
                         rpad('ABSORPTION_SEGMENT3', 25, ' ') ||
                         l_delimiter ||
                         rpad('ABSORPTION_SEGMENT4', 25, ' ') ||
                         l_delimiter ||
                         rpad('ABSORPTION_SEGMENT5', 25, ' ') ||
                         l_delimiter ||
                         rpad('ABSORPTION_SEGMENT6', 25, ' ') ||
                         l_delimiter ||
                         rpad('ABSORPTION_SEGMENT7', 25, ' ') ||
                         l_delimiter ||
                         rpad('ABSORPTION_SEGMENT10', 25, ' ') ||
                         l_delimiter ||
                         rpad('S3_ABSORPTION_SEGMENT1', 25, ' ') ||
                         l_delimiter ||
                         rpad('S3_ABSORPTION_SEGMENT2', 25, ' ') ||
                         l_delimiter ||
                         rpad('S3_ABSORPTION_SEGMENT3', 25, ' ') ||
                         l_delimiter ||
                         rpad('S3_ABSORPTION_SEGMENT4', 25, ' ') ||
                         l_delimiter ||
                         rpad('S3_ABSORPTION_SEGMENT5', 25, ' ') ||
                         l_delimiter ||
                         rpad('S3_ABSORPTION_SEGMENT6', 25, ' ') ||
                         l_delimiter ||
                         rpad('S3_ABSORPTION_SEGMENT7', 25, ' ') ||
                         l_delimiter ||
                         rpad('S3_ABSORPTION_SEGMENT8', 25, ' ') ||
                         l_delimiter ||
                         rpad('VARIANCE_SEGMENT1', 25, ' ') ||
                         l_delimiter ||
                         rpad('VARIANCE_SEGMENT2', 25, ' ') ||
                         l_delimiter ||
                         rpad('VARIANCE_SEGMENT3', 25, ' ') ||
                         l_delimiter ||
                         rpad('VARIANCE_SEGMENT4', 25, ' ') ||
                         l_delimiter ||
                         rpad('VARIANCE_SEGMENT5', 25, ' ') ||
                         l_delimiter ||
                         rpad('VARIANCE_SEGMENT6', 25, ' ') ||
                         l_delimiter ||
                         rpad('VARIANCE_SEGMENT7', 25, ' ') ||
                         l_delimiter ||
                         rpad('VARIANCE_SEGMENT10', 25, ' ') ||
                         l_delimiter ||
                         rpad('S3_VARIANCE_SEGMENT1', 25, ' ') ||
                         l_delimiter ||
                         rpad('S3_VARIANCE_SEGMENT2', 25, ' ') ||
                         l_delimiter ||
                         rpad('S3_VARIANCE_SEGMENT3', 25, ' ') ||
                         l_delimiter ||
                         rpad('S3_VARIANCE_SEGMENT4', 25, ' ') ||
                         l_delimiter ||
                         rpad('S3_VARIANCE_SEGMENT5', 25, ' ') ||
                         l_delimiter ||
                         rpad('S3_VARIANCE_SEGMENT6', 25, ' ') ||
                         l_delimiter ||
                         rpad('S3_VARIANCE_SEGMENT7', 25, ' ') ||
                         l_delimiter ||
                         rpad('S3_VARIANCE_SEGMENT8', 25, ' ') ||
                         l_delimiter ||
                         rpad('Status', 10, ' ') ||
                         l_delimiter ||
                         rpad('Error Message', 2000, ' '));

      FOR r_data IN c_report_resource LOOP
        fnd_file.put_line(fnd_file.output, rpad('PTM', 10, ' ') ||
                           l_delimiter ||
                           rpad('RESOURCE', 15, ' ') ||
                           l_delimiter ||
                           rpad(r_data.xx_resource_id, 14, ' ') ||
                           l_delimiter ||
                           rpad(r_data.resource_id, 10, ' ') ||
                           l_delimiter ||
                           rpad(r_data.resource_code, 10, ' ') ||
                           l_delimiter ||
                           rpad(r_data.organization_code, 30, ' ') ||
                           l_delimiter ||
                           rpad(r_data.s3_organization_code, 30, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.absorption_acct_segment1, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.absorption_acct_segment2, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.absorption_acct_segment3, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.absorption_acct_segment4, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.absorption_acct_segment5, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.absorption_acct_segment6, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.absorption_acct_segment7, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.absorption_acct_segment10, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_absorption_acct_segment1, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_absorption_acct_segment2, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_absorption_acct_segment3, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_absorption_acct_segment4, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_absorption_acct_segment5, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_absorption_acct_segment6, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_absorption_acct_segment7, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_absorption_acct_segment8, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.variance_acct_segment1, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.variance_acct_segment2, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.variance_acct_segment3, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.variance_acct_segment4, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.variance_acct_segment5, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.variance_acct_segment6, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.variance_acct_segment7, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.variance_acct_segment10, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_variance_acct_segment1, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_variance_acct_segment2, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_variance_acct_segment3, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_variance_acct_segment4, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_variance_acct_segment5, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_variance_acct_segment6, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_variance_acct_segment7, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_variance_acct_segment8, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(r_data.transform_status, 10, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.transform_error, 'NULL'), 2000, ' '));
      END LOOP;

      fnd_file.put_line(fnd_file.output, '');
      fnd_file.put_line(fnd_file.output, 'Stratasys Confidential' ||
                         l_delimiter);

    ELSIF p_entity = 'ROUTING' THEN

      SELECT COUNT(1)
      INTO   l_count_success
      FROM   xxs3_ptm_bom_routing xpbd
      WHERE  xpbd.transform_status = 'PASS';

      SELECT COUNT(1)
      INTO   l_count_fail
      FROM   xxs3_ptm_bom_routing xpbd
      WHERE  xpbd.transform_status = 'FAIL';

      fnd_file.put_line(fnd_file.output, rpad('Report name = Data Transformation Report' ||
                              l_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('========================================' ||
                              l_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Data Migration Object Name = ' ||
                              p_entity || l_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, '');
      fnd_file.put_line(fnd_file.output, rpad('Run date and time:    ' ||
                              to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') ||
                              l_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Total Record Count Success = ' ||
                              l_count_success ||
                              l_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Total Record Count Failure = ' ||
                              l_count_fail || l_delimiter, 100, ' '));

      fnd_file.put_line(fnd_file.output, '');

      fnd_file.put_line(fnd_file.output, rpad('Track Name', 10, ' ') ||
                         l_delimiter ||
                         rpad('Entity Name', 15, ' ') ||
                         l_delimiter ||
                         rpad('XX Routing Seq ID  ', 30, ' ') ||
                         l_delimiter ||
                         rpad('Routing Seq ID', 30, ' ') ||
                         l_delimiter ||
                         rpad('Item number', 20, ' ') ||
                         l_delimiter ||
                         rpad('ORGANIZATION', 25, ' ') ||
                         l_delimiter ||
                         rpad('S3_ORGANIZATION', 25, ' ') ||
                         l_delimiter ||
                         rpad('Status', 10, ' ') ||
                         l_delimiter ||
                         rpad('Error Message', 2000, ' '));

      FOR r_data IN c_report_routing LOOP
        fnd_file.put_line(fnd_file.output, rpad('PTM', 10, ' ') ||
                           l_delimiter ||
                           rpad('ROUTING', 15, ' ') ||
                           l_delimiter ||
                           rpad(r_data.xx_routing_seq_id, 30, ' ') ||
                           l_delimiter ||
                           rpad(r_data.routing_sequence_id, 30, ' ') ||
                           l_delimiter ||
                           rpad(r_data.item_number, 20, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.organization, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_organization, 'NULL'), 25, ' ') ||
                           l_delimiter ||
                           rpad(r_data.transform_status, 10, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.transform_error, 'NULL'), 2000, ' '));
      END LOOP;

      fnd_file.put_line(fnd_file.output, '');
      fnd_file.put_line(fnd_file.output, 'Stratasys Confidential' ||
                         l_delimiter);
    END IF;

  END data_transform_report;

  --------------------------------------------------------------------
  --  name:              dq_report
  --  create by:         Debarati banerjee
  --  Revision:          1.0
  --  creation date:     13/07/2016
  --------------------------------------------------------------------
  --  purpose :          write dq report to output
  --
  --------------------------------------------------------------------
  --  ver  date          name                   desc
  --  1.0  13/07/2016    Debarati banerjee     report DQ errors
  --------------------------------------------------------------------

  PROCEDURE dq_report(p_entity VARCHAR2) IS

    CURSOR c_report_routing IS
    SELECT NVL(XPBRD.RULE_NAME, ' ') RULE_NAME,
           NVL(XPBRD.NOTES, ' ') NOTES,
           XPBR.ROUTING_SEQUENCE_ID ROUTING_SEQUENCE_ID,
           XPBR.ITEM_NUMBER ITEM_NUMBER,
           XPBRD.XX_DQ_ROUTING_SEQ_ID XX_DQ_ROUTING_SEQ_ID,
           DECODE(XPBR.PROCESS_FLAG, 'R', 'Y', 'Q', 'N') REJECT_RECORD
      FROM XXS3_PTM_BOM_ROUTING XPBR, XXS3_PTM_BOM_ROUTING_DQ XPBRD
     WHERE XPBR.XX_ROUTING_SEQ_ID = XPBRD.XX_ROUTING_SEQ_ID
       AND XPBR.PROCESS_FLAG IN ('Q', 'R')
     ORDER BY ROUTING_SEQUENCE_ID DESC;

    l_delimiter    VARCHAR2(5) := '~';
    l_err_msg      VARCHAR2(2000);
    l_count_dq     NUMBER;
    l_count_reject NUMBER;

  BEGIN

    IF p_entity = 'ROUTING' THEN

      SELECT COUNT(1)
      INTO   l_count_dq
      FROM   xxs3_ptm_bom_routing xpbr
      WHERE  xpbr.process_flag IN ('Q', 'R');

      SELECT COUNT(1)
      INTO   l_count_reject
      FROM   xxs3_ptm_bom_routing xpbr
      WHERE  xpbr.process_flag = 'R';

      fnd_file.put_line(fnd_file.output, rpad('Report name = Data Quality Error Report' ||
                              l_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('========================================' ||
                              l_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Data Migration Object Name = ' ||
                              p_entity || l_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, '');
      fnd_file.put_line(fnd_file.output, rpad('Run date and time:    ' ||
                              to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') ||
                              l_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Total Record Count Having DQ Issues = ' ||
                              l_count_dq || l_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Total Record Count Rejected =  ' ||
                              l_count_reject || l_delimiter, 100, ' '));

      fnd_file.put_line(fnd_file.output, '');

      fnd_file.put_line(fnd_file.output, rpad('Track Name', 10, ' ') ||
                         l_delimiter ||
                         rpad('Entity Name', 11, ' ') ||
                         l_delimiter ||
                         rpad('XX Routing Sequence ID', 30, ' ') ||
                         l_delimiter ||
                         rpad('Routing Sequence ID', 10, ' ') ||
                         l_delimiter ||
                         rpad('Item Number', 240, ' ') ||
                         l_delimiter ||
                         rpad('Reject Record Flag(Y/N)', 22, ' ') ||
                         l_delimiter ||
                         rpad('Rule Name', 45, ' ') ||
                         l_delimiter ||
                         rpad('Reason Code', 50, ' '));

      FOR r_data IN c_report_routing LOOP
        fnd_file.put_line(fnd_file.output, rpad('PTM', 10, ' ') ||
                           l_delimiter ||
                           rpad('ROUTING', 11, ' ') ||
                           l_delimiter ||
                           rpad(r_data.xx_dq_routing_seq_id, 30, ' ') ||
                           l_delimiter ||
                           rpad(r_data.routing_sequence_id, 10, ' ') ||
                           l_delimiter ||
                           rpad(r_data.item_number, 40, ' ') ||
                           l_delimiter ||
                           rpad(r_data.reject_record, 22, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.rule_name, 'NULL'), 45, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.notes, 'NULL'), 50, ' '));

      END LOOP;

      fnd_file.put_line(fnd_file.output, '');
      fnd_file.put_line(fnd_file.output, 'Stratasys Confidential' ||
                         l_delimiter);
    END IF;
  END dq_report;

  --------------------------------------------------------------------
  --  name:              data_cleanse_report
  --  create by:         Debarati banerjee
  --  Revision:          1.0
  --  creation date:     13/07/2016
  --------------------------------------------------------------------
  --  purpose :          write data cleanse report to output
  --
  --------------------------------------------------------------------
  --  ver  date          name                   desc
  --  1.0  13/05/2016    Debarati banerjee     report data cleanse
  --------------------------------------------------------------------

  PROCEDURE data_cleanse_report(p_entity VARCHAR2) IS

    CURSOR c_report_routing IS
    SELECT XPBR.ROUTING_SEQUENCE_ID ROUTING_SEQUENCE_ID,
           XPBR.ITEM_NUMBER ITEM_NUMBER,
           XPBR.COMPLETION_SUBINVENTORY,
           XPBR.S3_COMPLETION_SUBINVENTORY S3_COMPLETION_SUBINVENTORY,
           XPBR.XX_ROUTING_SEQ_ID XX_ROUTING_SEQ_ID,
           XPBR.CLEANSE_STATUS,
           XPBR.CLEANSE_ERROR
      FROM XXS3_PTM_BOM_ROUTING XPBR
     WHERE XPBR.CLEANSE_STATUS IN ('PASS', 'FAIL');

    l_delimiter     VARCHAR2(5) := '~';
    l_err_msg       VARCHAR2(2000);
    l_count_success NUMBER;
    l_count_fail    NUMBER;

  BEGIN
    /*
    x_err_code := 0;
    x_err_msg  := '';*/
    IF p_entity = 'ROUTING' THEN

      SELECT COUNT(1)
      INTO   l_count_success
      FROM   xxs3_ptm_bom_routing xpbr
      WHERE  xpbr.cleanse_status = 'PASS';

      SELECT COUNT(1)
      INTO   l_count_fail
      FROM   xxs3_ptm_bom_routing xpbr
      WHERE  xpbr.cleanse_status = 'FAIL';

      fnd_file.put_line(fnd_file.output, rpad('Report name = Automated Cleanse & Standardize Report' ||
                              l_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('====================================================' ||
                              l_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Data Migration Object Name = ' ||
                              p_entity || l_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, '');
      fnd_file.put_line(fnd_file.output, rpad('Run date and time:    ' ||
                              to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') ||
                              l_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Total Record Count Success = ' ||
                              l_count_success ||
                              l_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Total Record Count Failure = ' ||
                              l_count_fail || l_delimiter, 100, ' '));

      fnd_file.put_line(fnd_file.output, '');

      fnd_file.put_line(fnd_file.output, rpad('Track Name', 10, ' ') ||
                         l_delimiter ||
                         rpad('Entity Name', 11, ' ') ||
                         l_delimiter ||
                         rpad('XX Routing Sequence ID', 30, ' ') ||
                         l_delimiter ||
                         rpad('Routing Sequence ID', 30, ' ') ||
                         l_delimiter ||
                         rpad('Completion Subinventory', 40, ' ') ||
                         l_delimiter ||
                         rpad('S3 Completion Subinventory', 40, ' ') ||
                         l_delimiter ||
                         rpad('Item Number', 30, ' ') ||
                         l_delimiter ||
                         rpad('Status', 10, ' ') ||
                         l_delimiter ||
                         rpad('Error Message', 200, ' '));

      FOR r_data IN c_report_routing LOOP
        fnd_file.put_line(fnd_file.output, rpad('PTM', 10, ' ') ||
                           l_delimiter ||
                           rpad('ROUTING', 11, ' ') ||
                           l_delimiter ||
                           rpad(r_data.xx_routing_seq_id, 30, ' ') ||
                           l_delimiter ||
                           rpad(r_data.routing_sequence_id, 30, ' ') ||
                           l_delimiter ||
                           rpad(r_data.completion_subinventory, 40, ' ') ||
                           l_delimiter ||
                           rpad(r_data.s3_completion_subinventory, 40, ' ') ||
                           l_delimiter ||
                           rpad(r_data.item_number, 30, ' ') ||
                           l_delimiter ||
                           rpad(r_data.cleanse_status, 10, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.cleanse_error, 'NULL'), 200, ' '));

      END LOOP;

      fnd_file.put_line(fnd_file.output, '');
      fnd_file.put_line(fnd_file.output, 'Stratasys Confidential' ||
                         l_delimiter);

    END IF;
  END data_cleanse_report;
END xxs3_ptm_bom_pkg;
/
