CREATE OR REPLACE PACKAGE BODY xxs3_ptm_item_cat_assign_pkg
  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Package is used for Item Category Assignment Data Extract
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  Santanu                           Initial build
  -- --------------------------------------------------------------------------------------------

AS
report_error EXCEPTION;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for Item Category Assignment Data Extract
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  Santanu                           Initial build
  -- 1.1  05/01/2017  Sateesh                      'SSYS Import Tariff Code' for Dry Run 3                                               
  -- --------------------------------------------------------------------------------------------

  PROCEDURE item_cat_assign_extract(p_retcode OUT VARCHAR2
                                   ,p_errbuf  OUT VARCHAR2) AS

		l_inventory_org_oma number:=91;
    l_inventory_org_m01 number:=739;
    l_inventory_org_t01 number:=740;
     l_inventory_org_t02 number:=742;
     l_status_message         VARCHAR2(4000);

		/* Main Cursor for the Extract */

	CURSOR c_item_cat_assign IS
      SELECT DISTINCT mic.inventory_item_id || '|' || mic.organization_id || '|' ||
                      mic.category_set_id || '|' || mic.category_id legacy_id
                     , /*mic.INVENTORY_ITEM_ID,*/xi.segment1 item_number
                     ,'GIM' organization_code
                     , /*mic.CATEGORY_SET_ID ,*/mic.category_set_name
                     , /*mic.CATEGORY_ID,*/mic.control_level_disp control_level
                     ,mic.category_concat_segs category_name /*,mic.segment1,mic.segment2,
             mic.segment3,mic.SEGMENT4,mic.segment5,mic.segment6,mic.segment7*/
        FROM mtl_item_categories_v mic
            ,mtl_system_items_b xi
            ,(SELECT mc.category_set_id
                    ,mc.category_set_name
                    ,mc.description
                    ,mc.structure_id
                    ,mc.structure_name
                    ,mc.control_level_disp
                    ,mc.default_category_id
                FROM mtl_category_sets_v mc
               WHERE mc.category_set_name IN
                     ('Class Category Set', 'Objet Embedded SW Version', 'Objet Studio SW Version',
                      'Objet INTRANSTAT Tariff Code', 'Product Hierarchy', 'Activity Analysis',
                      'Basis HASP', 'Commissions', 'CS Price Book Product Type',
                      'Japan Resin Pack Breakdown', 'Japan Unit of Measure Sign', --'AVA_TAX_CODE',
                      'Brand', 'DG Restriction Level','SSYS Import Tariff Code','CS Recommended Stock','CS Category Set')) set1  /*'SSYS Import Tariff Code','CS Recommended Stock','CS Category Set' */
       WHERE mic.organization_id = l_inventory_org_oma--org id
         AND mic.inventory_item_id = xi.inventory_item_id
         AND mic.organization_id = xi.organization_id
         AND mic.category_set_id = set1.category_set_id
         AND EXISTS(SELECT l_inventory_item_id
                    FROM xxs3_ptm_master_items_ext_stg xpm
                    WHERE extract_rule_name is not null
                    AND legacy_organization_code='OMA'
                    AND xpm.l_inventory_item_id=xi.inventory_item_id
                    AND xpm.legacy_organization_id=xi.organization_id
                    AND xpm.process_flag <> 'R')

      UNION

      SELECT DISTINCT mic.inventory_item_id || '|' || mic.organization_id || '|' ||
                      mic.category_set_id || '|' || mic.category_id legacy_id
                     , /*mic.INVENTORY_ITEM_ID,*/xi.segment1 item_number
                     ,'M01' organization_code
                     , /*mic.CATEGORY_SET_ID ,*/mic.category_set_name
                     , /*mic.CATEGORY_ID,*/mic.control_level_disp control_level
                     ,mic.category_concat_segs category_name /*,mic.segment1,mic.segment2,
             mic.segment3,mic.SEGMENT4,mic.segment5,mic.segment6,mic.segment7*/
        FROM mtl_item_categories_v mic
            ,mtl_system_items_b xi
            ,(SELECT mc.category_set_id
                    ,mc.category_set_name
                    ,mc.description
                    ,mc.structure_id
                    ,mc.structure_name
                    ,mc.control_level_disp
                    ,mc.default_category_id
                FROM mtl_category_sets_v mc
               WHERE mc.category_set_name = 'Objet INTRANSTAT Tariff Code') set1
       WHERE mic.organization_id = l_inventory_org_m01 --org_id
         AND mic.inventory_item_id = xi.inventory_item_id
         AND mic.organization_id = xi.organization_id
         AND mic.category_set_id = set1.category_set_id
          AND EXISTS(SELECT l_inventory_item_id
                     FROM xxobjt.xxs3_ptm_items_org_assign_stg xioa
                     WHERE xioa.l_inventory_item_id = xi.inventory_item_id
                     AND xioa.org_assign_rule IS NOT NULL
                     AND xioa.s3_organization_code='M01')

      UNION

      SELECT DISTINCT mic.inventory_item_id || '|' || mic.organization_id || '|' ||
                      mic.category_set_id || '|' || mic.category_id legacy_id
                     , /*mic.INVENTORY_ITEM_ID,*/xi.segment1 item_number
                     ,'T01' organization_code
                     , /*mic.CATEGORY_SET_ID ,*/mic.category_set_name
                     , /*mic.CATEGORY_ID,*/mic.control_level_disp control_level
                     ,mic.category_concat_segs category_name /*,mic.segment1,mic.segment2,
             mic.segment3,mic.SEGMENT4,mic.segment5,mic.segment6,mic.segment7*/
        FROM mtl_item_categories_v mic
            ,mtl_system_items_b xi
            ,(SELECT mc.category_set_id
                    ,mc.category_set_name
                    ,mc.description
                    ,mc.structure_id
                    ,mc.structure_name
                    ,mc.control_level_disp
                    ,mc.default_category_id
                FROM mtl_category_sets_v mc
               WHERE mc.category_set_name = 'Objet INTRANSTAT Tariff Code') set1
       WHERE mic.organization_id = l_inventory_org_t01--org_id
         AND mic.inventory_item_id = xi.inventory_item_id
         AND mic.organization_id = xi.organization_id
         AND mic.category_set_id = set1.category_set_id
          AND EXISTS(SELECT l_inventory_item_id
                     FROM xxobjt.xxs3_ptm_items_org_assign_stg xioa
                     WHERE xioa.l_inventory_item_id = xi.inventory_item_id
                     AND xioa.org_assign_rule IS NOT NULL
                     AND xioa.s3_organization_code='T01')

      UNION

      SELECT DISTINCT mic.inventory_item_id || '|' || mic.organization_id || '|' ||
                      mic.category_set_id || '|' || mic.category_id legacy_id
                     , /*mic.INVENTORY_ITEM_ID,*/xi.segment1 item_number
                     ,'T02' organization_code
                     , /*mic.CATEGORY_SET_ID ,*/mic.category_set_name
                     , /*mic.CATEGORY_ID,*/mic.control_level_disp control_level
                     ,mic.category_concat_segs category_name /*,mic.segment1,mic.segment2,
             mic.segment3,mic.SEGMENT4,mic.segment5,mic.segment6,mic.segment7*/
        FROM mtl_item_categories_v mic
            ,mtl_system_items_b xi
            ,(SELECT mc.category_set_id
                    ,mc.category_set_name
                    ,mc.description
                    ,mc.structure_id
                    ,mc.structure_name
                    ,mc.control_level_disp
                    ,mc.default_category_id
                FROM mtl_category_sets_v mc
               WHERE mc.category_set_name = 'Objet INTRANSTAT Tariff Code') set1
       WHERE mic.organization_id = l_inventory_org_t02--org_id
         AND mic.inventory_item_id = xi.inventory_item_id
         AND mic.organization_id = xi.organization_id
         AND mic.category_set_id = set1.category_set_id
          AND EXISTS(SELECT l_inventory_item_id
                     FROM xxobjt.xxs3_ptm_items_org_assign_stg xioa
                     WHERE xioa.l_inventory_item_id = xi.inventory_item_id
                     AND xioa.org_assign_rule IS NOT NULL
                     AND xioa.s3_organization_code='T02');
       
       CURSOR c_transform IS
       SELECT * FROM xxs3_ptm_item_cat_assign;
       
  BEGIN
	/* Delete records before insert into stage table */
    DELETE FROM xxobjt.xxs3_ptm_item_cat_assign;
    
  /* Insert the records into stage table */
   fnd_file.put_line(fnd_file.log, 'Insert Begin');
    FOR i IN c_item_cat_assign LOOP
    
      INSERT INTO xxobjt.xxs3_ptm_item_cat_assign
      (legacy_id,
      item_number,
      organization_code,
      category_set_name,
      control_level,
      category_name,
      process_flag,
      date_extracted_on,
      s3_category_set_name
      )
      VALUES
        (i.legacy_id
        ,i.item_number
        ,i.organization_code
        ,i.category_set_name
        ,i.control_level
        ,i.category_name
        ,'N'
        ,SYSDATE
        ,i.category_set_name);
    END LOOP;
    COMMIT;
    fnd_file.put_line(fnd_file.log, 'Insert End');
    
     /*Transformation */
    BEGIN
       UPDATE xxobjt.xxs3_ptm_item_cat_assign
       SET s3_category_set_name='Applicable System'
       WHERE category_set_name='CS Price Book Product Type';
       
      /* 
        UPDATE xxobjt.xxs3_ptm_item_cat_assign
       SET s3_category_set_name='CS Item Category'
       WHERE category_set_name='CS Category Set'; */ --Commented by Sateesh As per FDD update29Dec16
       
     EXCEPTION    
    WHEN OTHERS THEN
    fnd_file.put_line(fnd_file.log, 'Error in Transformation');
    END;
    
    EXCEPTION
      WHEN report_error THEN
      fnd_file.put_line(fnd_file.log, 'Failed to generate report');
      p_retcode := 1;
      p_errbuf  := 'Unexpected error: report error';

    WHEN OTHERS THEN
      p_retcode        := 2;
      p_errbuf         := 'Unexpected error: ' || SQLERRM;
      l_status_message := SQLCODE || chr(10) || SQLERRM;
      fnd_file.put_line(fnd_file.log, 'Unexpected error during data extraction : ' ||
                         chr(10) || l_status_message);
      fnd_file.put_line(fnd_file.log, '--------------------------------------');

  END item_cat_assign_extract;


END xxs3_ptm_item_cat_assign_pkg;
/
