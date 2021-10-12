CREATE OR REPLACE VIEW XXAGILE_ITEM_OUTGING_V AS
SELECT rpad(msib.segment1, 15, ' ') item_num,
       lpad(mcb.segment1, 20, ' ') item_group,
       lpad(round(nvl(xxagile_file_export_pkg.get_item_last_price(msib.inventory_item_id),
                      0),
                  4),
            14,
            ' ') last_price,
       nvl(xxagile_file_export_pkg.get_item_last_currency(msib.inventory_item_id),
           '   ') currency,
       lpad(nvl(xxagile_file_export_pkg.get_item_onhand_qty(msib.inventory_item_id),
                0),
            13,
            ' ') onhand_qty,
       lpad(nvl(xxagile_file_export_pkg.get_item_open_po(msib.inventory_item_id),
                0),
            13,
            ' ') open_po_qty, chr(13) last_col
  FROM mtl_system_items_b  msib,
       mtl_parameters      mp,
       mtl_categories_b    mcb,
       mtl_item_categories mic,
       mtl_category_sets_vl mcsb
 WHERE msib.mtl_transactions_enabled_flag = 'Y'
   AND msib.costing_enabled_flag = 'Y'
   AND msib.organization_id = mp.organization_id
   AND mp.organization_code = 'OMA'
   and msib.organization_id = mic.organization_id
   and msib.inventory_item_id = mic.inventory_item_id
   and mic.category_set_id = mcsb.category_set_id
   and mcsb.CATEGORY_SET_NAME = 'Main Category Set'
   and mp.organization_id = mic.organization_id
   and mic.category_id = mcb.category_id;

