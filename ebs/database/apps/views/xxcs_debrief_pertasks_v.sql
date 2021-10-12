﻿CREATE OR REPLACE VIEW XXCS_DEBRIEF_PERTASKS_V
(debrief_header_id, debrief_line_id, channel_code, service_date, inventory_item_id, uom_code, quantity, expense_amount, currency_code, creation_date, business_process_id, transaction_type_id, txn_type, expense_meaning, charge_upload_status, txn_type_description, labor_start_date, labor_end_date, instance_id, instance_number, inventory_org_id, sub_inventory_code, parent_product_id, removed_product_id, item_revision, item_serial_number, line_order_category_code, material_meaning, ib_update_status, spare_update_status, return_reason_code, return_reason, error_text, attribute1, attribute2, attribute3, attribute4, attribute5, attribute6, attribute7, attribute8, attribute9, attribute10, attribute11, attribute12, attribute13, attribute14, attribute15, line_type)
AS
select debrief_header_id,
       debrief_line_id,
       channel_code,
       service_date,
       inventory_item_id,
       uom_code,
       quantity,
       null,
       null,
       creation_date,
       business_process_id,
       transaction_type_id,
       txn_type,
       null,
       charge_upload_status,
       txn_type_description,
       labor_start_date,
       labor_end_date,
       null,
       null,
       null,
       null,
       null,
       null,
       null,
       null,
       null,
       null,
       null,
       null,
       null,
       null,
       null,
       null,
       null,
       null,
       null,
       null,
       null,
       null,
       null,
       null,
       null,
       null,
       null,
       null,
       null,
       null,
       'LABOR'
  FROM csf_debrief_lab_lines_v

UNION ALL

SELECT debrief_header_id,
       debrief_line_id,
       channel_code,
       service_date,
       inventory_item_id,
       uom_code,
       quantity,
       expense_amount,
       currency_code,
       creation_date,
       business_process_id,
       transaction_type_id,
       txn_type,
       expense_meaning,
       charge_upload_status,
       null,
       null,
       null,
       null,
       null,
       null,
       null,
       null,
       null,
       null,
       null,
       null,
       null,
       null,
       null,
       null,
       null,
       null,
       null,
       null,
       null,
       null,
       null,
       null,
       null,
       null,
       null,
       null,
       null,
       null,
       null,
       null,
       null,
       'EXPANCE'
  FROM csf_debrief_exp_lines_v

UNION ALL

SELECT debrief_header_id,
       debrief_line_id,
       channel_code,
       service_date,
       inventory_item_id,
       uom_code,
       quantity,
       null,
       null,
       creation_date,
       business_process_id,
       transaction_type_id,
       txn_type,
       null,
       charge_upload_status,
       null,
       null,
       null,
       instance_id,
       instance_number,
       inventory_org_id,
       sub_inventory_code,
       parent_product_id,
       removed_product_id,
       item_revision,
       item_serial_number,
       line_order_category_code,
       material_meaning,
       ib_update_status,
       spare_update_status,
       return_reason_code,
       return_reason,
       error_text,
       attribute1,
       attribute2,
       attribute3,
       attribute4,
       attribute5,
       attribute6,
       attribute7,
       attribute8,
       attribute9,
       attribute10,
       attribute11,
       attribute12,
       attribute13,
       attribute14,
       attribute15,
       'MATERIAL'
  FROM csf_debrief_mat_lines_v;

