CREATE OR REPLACE VIEW XXCS_ITEM_CATEGORY_V AS
SELECT
----------------------------------------------------
--xxcs_item_category_v
-- porpose
--     used in disco report : XXINV ITEM Category
--     folder : XXINV: items categories
 --------------------------------------------------------------------------
  --  ver  date          name                 desc
  --  1.0  15.6.17     yuval tal              CHG0040939 add image_jpeg_exists_flag
  --  1.1  13.02.19    yuval tal              INC0144683 - change image_pdf_exists_flag field name and logic for PNG
---------------------------------------------------------------------------

substr(nvl(xxobjt_general_utils_pkg.get_valueset_desc('XXCS_PB_PRODUCT_FAMILY',parent_flex_value),parent_flex_value),1,60) parent_flex_value,-- CHG0035863
       mcs.category_set_id,
       mcs.category_set_name,
       mc.concatenated_segments category_name,
       msib.segment1            part_number,

       xxobjt_general_utils_pkg.is_file_exist( 'XXCS_PZ_IMAGES_DIR',msib.segment1 || '.png' )  image_png_exists_flag,
       decode (xxobjt_general_utils_pkg.is_file_exist( 'XXCS_PZ_IMAGES_DIR',msib.segment1 || '.jpeg' ) ,'Y','Y','N',
       decode (xxobjt_general_utils_pkg.is_file_exist( 'XXCS_PZ_IMAGES_DIR',msib.segment1 || '.JPG' ),'Y','Y','N'),'N')   image_jpeg_exists_flag,
       xxinv_utils_pkg.get_category_segment('SEGMENT3',1100000272,MSIB.INVENTORY_ITEM_ID ) MAIN_SEGMENT3,
       xxinv_utils_pkg.get_category_segment('SEGMENT6',1100000221,MSIB.INVENTORY_ITEM_ID ) TECHNOLOGY,
       msib.description description,
       nvl( msib.attribute11,'N') returnable,
       nvl( msib.attribute26,'N') Consumable,
       replace(xxobjt_fnd_attachments.get_short_text_attached( 'INVIDITM',
                                                       'MTL_SYSTEM_ITEMS',
                                                       fnd_profile.value('XXCS_PZ_ATTACHMENT_CATEGORY'),
                                                      xxinv_utils_pkg.get_master_organization_id,
                                                       msib.inventory_item_id),'<BR>',' ') remarks,

       1                        flag
FROM   mtl_item_categories       mic,
       mtl_categories_kfv        mc,
       mtl_category_sets         mcs,
       mtl_system_items_b        msib,
       fnd_flex_value_children_v fl,
       fnd_flex_value_sets       vs
WHERE  msib.inventory_item_id = mic.inventory_item_id
AND    msib.organization_id = mic.organization_id
AND    mic.category_id = mc.category_id
AND    mcs.category_set_id = mic.category_set_id
AND    mic.organization_id = xxinv_utils_pkg.get_master_organization_id
AND    mcs.category_set_name = 'CS Price Book Product Type'
AND    vs.flex_value_set_name = 'XXCS_PB_PRODUCT_FAMILY'
AND    fl.flex_value_set_id = vs.flex_value_set_id
AND    fl.flex_value = mc.concatenated_segments
;
