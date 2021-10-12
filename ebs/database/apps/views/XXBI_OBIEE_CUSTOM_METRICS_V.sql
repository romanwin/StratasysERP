CREATE OR REPLACE VIEW XXBI_OBIEE_CUSTOM_METRICS_V AS
SELECT
  --------------------------------------------------------------------
  --  name: XXBI_OBIEE_CUSTOM_METRICS_V
  --  created by: Piyali Bhowmick
  --  Revision: 1.0  $
  --  creation date: 7/31/2017
  --------------------------------------------------------------------
  --  purpose : CHG0040698 - Production Paid Hours Metric

  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  31/7/2017   Piyali Bhowmick   CHG0040698 - Production Paid Hours Metric
  --------------------------------------------------------------------
   ocm.metric_value_id   id,
       ocm.metric_name,
       ocm.period_day,
       ocm.metric_value,
       ocm.department_number department_number,

       xxobjt_general_utils_pkg.get_valueset_desc('XXGL_DEPARTMENT_SEG',
				  ocm.department_number) department_description,

       (SELECT cat.segment1
        FROM   mtl_item_categories_v cat
        WHERE  cat.category_set_name = 'Product Hierarchy'
        AND    ocm.inventory_item_id = cat.inventory_item_id
        AND    ocm.organization_id = cat.organization_id) line_of_business,
       (SELECT  cat.segment6
        FROM   mtl_item_categories_v cat
        WHERE  cat.category_set_name = 'Product Hierarchy'
        AND    ocm.inventory_item_id = cat.inventory_item_id
        AND    ocm.organization_id = cat.organization_id)  company_technology,

       (SELECT glc.segment5
        FROM   gl_code_combinations glc,
	   mtl_system_items_b   mtl
        WHERE  mtl.cost_of_sales_account = glc.code_combination_id
        AND    mtl.inventory_item_id = ocm.inventory_item_id
        AND    mtl.organization_id = ocm.organization_id) product_line_gl_code,
       ocm.inventory_item_id,
       xxinv_utils_pkg.get_item_segment(ocm.inventory_item_id,
			    ocm.organization_id) item_number,
       (SELECT organization_code
        FROM   mtl_parameters mp
        WHERE  mp.organization_id = ocm.organization_id) organization_code,
       (SELECT hou.name
        FROM   hr_operating_units hou
        WHERE  ocm.operating_unit_id = hou.organization_id) operating_unit,
       ocm.region,
       ocm.attribute_category,
       ocm.attribute1,
       ocm.attribute2,
       ocm.attribute3,
       ocm.attribute4,
       ocm.attribute5,
       ocm.attribute6,
       ocm.attribute7,
       ocm.attribute8,
       ocm.attribute9,
       ocm.attribute10,
       ocm.creation_date,
       ocm.created_by,
       ocm.last_update_date,
       ocm.last_updated_by

FROM   XXBI.xxbi_obiee_custom_metrics ocm
;
--  mtl_system_items          msi,
--    mtl_item_categories_v cat
--   mtl_parameters        mp,

--WHERE
--AND    ocm.inventory_item_id = msi.inventory_item_id
-- ocm.organization_id = mp.organization_id
--ocm.operating_unit_id(+) = hou.organization_id

-- AND    ocm.inventory_item_id = micv.inventory_item_id(+)
--AND    msi.inventory_item_id = micv.inventory_item_id
-- AND    ocm.organization_id = micv.organization_id(+)
--AND    ocm.organization_id = micv.organization_id
-- AND    micv.category_id(+) = 111295
--and ocm.PRODUCT_LINE_GL_CODE = glc.segment5
--AND    msi.cost_of_sales_account = glc.code_combination_id;

--select * from XXBI_OBIEE_CUSTOM_METRICS_V

--select * from xxbi_obiee_custom_metrics

--select segment1,segment6 ,cat.* from mtl_item_categories_v cat where cat.CATEGORY_SET_NAME='Product Hierarchy' and
--category_id = 111295;

