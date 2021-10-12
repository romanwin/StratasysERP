﻿create or replace view xxcs_contracts_installbase_v
(instance_id, instance_number, inventory_item_id, inventory_revision, inv_master_organization_id, serial_number, mfg_serial_number_flag, lot_number, quantity, unit_of_measure, accounting_class_code, instance_status_id, customer_view_flag, system_id, active_start_date, active_end_date, location_type_code, location_id, inv_organization_id, inv_subinventory_name, inv_locator_id, wip_job_id, po_order_line_id, last_oe_order_line_id, last_oe_rma_line_id, last_po_po_line_id, last_oe_po_number, last_wip_job_id, install_date, manually_created_flag, return_by_date, actual_return_date, creation_complete_flag, context, cust16, record_id_data_conv, coi, embedded_sw_version, objet_studio_sw_version, ship_date, coi_date, itm_attribute8, itm_attribute9, itm_attribute10, itm_attribute11, itm_attribute12, itm_attribute13, itm_attribute14, itm_attribute15, itm_attribute16, itm_attribute17, itm_attribute18, itm_attribute19, itm_attribute20, itm_attribute21, itm_attribute22, itm_attribute23, itm_attribute24, itm_attribute25, itm_attribute26, itm_attribute27, itm_attribute28, itm_attribute29, itm_attribute30, created_by, creation_date, last_updated_by, last_update_date, object_version_number, install_location_type_code, install_location_id, instance_usage_code, owner_party_source_table, owner_party_id, owner_party_account_id, last_vld_organization_id, instance_description, sales_unit_price, sales_currency_code, instance_type_code, operating_unit_id, operating_unit_name, cust_account_id, customer_name, party_number, account_number, system_type_code, system_type, end_customer, item, organization_id, instance_association_id, source_object_code, last_update_login, cou_attribute1, cou_attribute2, cou_attribute3, cou_attribute4, cou_attribute5, cou_attribute6, cou_attribute7, cou_attribute8, cou_attribute9, cou_attribute10, cou_attribute11, cou_attribute12, cou_attribute13, cou_attribute14, cou_attribute15, attribute_category, security_group_id, migrated_flag, counter_id, start_date_active, end_date_active, maint_organization_id, primary_failure_flag, owner_name, owner_cs_region, item_type, item_description, item_type_meaning, counter_reading, optimax_upgrade_date, tempo_upgrade_date, contract_service, contract_coverage, contract_number, contract_status, contract_start_date, contract_end_date, contract_line_status, contract_line_start_date, contract_line_end_date, warranty_service, warranty_coverage, warranty_number, warranty_status, warranty_start_date, warranty_end_date, warranty_line_status, warranty_line_start_date, warranty_line_end_date)
as
select
--> csi_item_instances cii
    cii.instance_id,
    cii.instance_number,
    cii.inventory_item_id,
    cii.inventory_revision,
    cii.inv_master_organization_id,
    cii.serial_number,
    cii.mfg_serial_number_flag,
    cii.lot_number,
    cii.quantity,
    cii.unit_of_measure,
    cii.accounting_class_code,
    cii.instance_status_id,
    cii.customer_view_flag,
    cii.system_id,
    cii.active_start_date,
    cii.active_end_date,
    cii.location_type_code,
    cii.location_id,
    cii.inv_organization_id,
    cii.inv_subinventory_name,
    cii.inv_locator_id,
    cii.wip_job_id,
    cii.po_order_line_id,
    cii.last_oe_order_line_id,
    cii.last_oe_rma_line_id,
    cii.last_po_po_line_id,
    cii.last_oe_po_number,
    cii.last_wip_job_id,
    cii.install_date,
    cii.manually_created_flag,
    cii.return_by_date,
    cii.actual_return_date,
    cii.creation_complete_flag,
    cii.context,
    cii.attribute1 itm_attribute1,
    cii.attribute2 itm_attribute2,
    cii.attribute3 itm_attribute3,
    cii.attribute4 itm_attribute4,
    cii.attribute5 itm_attribute5,
    cii.attribute6 itm_attribute6,
    to_date(cii.attribute7,'yyyy/mm/dd hh24:mi:ss') itm_attribute7,
    cii.attribute8 itm_attribute8,
    cii.attribute9 itm_attribute9,
    cii.attribute10 itm_attribute10,
    cii.attribute11 itm_attribute11,
    cii.attribute12 itm_attribute12,
    cii.attribute13 itm_attribute13,
    cii.attribute14 itm_attribute14,
    cii.attribute15 itm_attribute15,
    cii.attribute16 itm_attribute16,
    cii.attribute17 itm_attribute17,
    cii.attribute18 itm_attribute18,
    cii.attribute19 itm_attribute19,
    cii.attribute20 itm_attribute20,
    cii.attribute21 itm_attribute21,
    cii.attribute22 itm_attribute22,
    cii.attribute23 itm_attribute23,
    cii.attribute24 itm_attribute24,
    cii.attribute25 itm_attribute25,
    cii.attribute26 itm_attribute26,
    cii.attribute27 itm_attribute27,
    cii.attribute28 itm_attribute28,
    cii.attribute29 itm_attribute29,
    cii.attribute30 itm_attribute30,
    cii.created_by,
    cii.creation_date,
    cii.last_updated_by,
    cii.last_update_date,
    cii.object_version_number,
    cii.install_location_type_code,
    cii.install_location_id,
    cii.instance_usage_code,
    cii.owner_party_source_table,
    cii.owner_party_id,
    cii.owner_party_account_id,
    cii.last_vld_organization_id,
    cii.instance_description,
    cii.sales_unit_price,
    cii.sales_currency_code,
    cii.instance_type_code,
--> csi_systems_v csv
    csv.operating_unit_id,
    csv.operating_unit_name,
    csv.customer_id cust_account_id,
    csv.customer_name,
    csv.customer_party_number party_number,
    csv.customer_number account_number,
    csv.system_type_code,
    csv.system_type,
    csv.name end_customer,
    msi.segment1 item,
    msi.organization_id,
    cca.instance_association_id,
    cca.source_object_code,
    cca.last_update_login,
    cca.attribute1 cou_attribute1,
    cca.attribute2 cou_attribute2,
    cca.attribute3 cou_attribute3,
    cca.attribute4 cou_attribute4,
    cca.attribute5 cou_attribute5,
    cca.attribute6 cou_attribute6,
    cca.attribute7 cou_attribute7,
    cca.attribute8 cou_attribute8,
    cca.attribute9 cou_attribute9,
    cca.attribute10 cou_attribute10,
    cca.attribute11 cou_attribute11,
    cca.attribute12 cou_attribute12,
    cca.attribute13 cou_attribute13,
    cca.attribute14 cou_attribute14,
    cca.attribute15 cou_attribute15,
    cca.attribute_category,
    cca.security_group_id,
    cca.migrated_flag,
    cca.counter_id,
    cca.start_date_active,
    cca.end_date_active,
    cca.maint_organization_id,
    cca.primary_failure_flag,
--> csi_counter_readings ccr
   /* ccr.counter_value_id,
    ccr.value_timestamp,
    ccr.counter_reading,
    ccr.reset_mode,
    ccr.reset_reason,
    ccr.adjustment_type,
    ccr.adjustment_reading,
    ccr.net_reading,
    ccr.life_to_date_reading,
    ccr.automatic_rollover_flag,
    ccr.include_target_resets,
    ccr.source_counter_value_id,
    ccr.transaction_id,
    ccr.disabled_flag,
    ccr.comments,
    ccr.attribute1 rea_attribute1,
    ccr.attribute2 rea_attribute2,
    ccr.attribute3 rea_attribute3,
    ccr.attribute4 rea_attribute4,
    ccr.attribute5 rea_attribute5,
    ccr.attribute6 rea_attribute6,
    ccr.attribute7 rea_attribute7,
    ccr.attribute8 rea_attribute8,
    ccr.attribute9 rea_attribute9,
    ccr.attribute10 rea_attribute10,
    ccr.attribute11 rea_attribute11,
    ccr.attribute12 rea_attribute12,
    ccr.attribute13 rea_attribute13,
    ccr.attribute14 rea_attribute14,
    ccr.attribute15 rea_attribute15,
    ccr.attribute16 rea_attribute16,
    ccr.attribute17 rea_attribute17,
    ccr.attribute18 rea_attribute18,
    ccr.attribute19 rea_attribute19,
    ccr.attribute20 rea_attribute20,
    ccr.attribute21 rea_attribute21,
    ccr.attribute22 rea_attribute22,
    ccr.attribute23 rea_attribute23,
    ccr.attribute24 rea_attribute24,
    ccr.attribute25 rea_attribute25,
    ccr.attribute26 rea_attribute26,
    ccr.attribute27 rea_attribute27,
    ccr.attribute28 rea_attribute28,
    ccr.attribute29 rea_attribute29,
    ccr.attribute30 rea_attribute30,
    ccr.source_code,
    ccr.source_line_id,
    ccr.initial_reading_flag
--> csi_iea_values civ
    civ.attribute_value_id,
    civ.attribute_id,
    civ.attribute_value,
    civ.attribute1 val_attribute1,
    civ.attribute2 val_attribute2,
    civ.attribute3 val_attribute3,
    civ.attribute4 val_attribute4,
    civ.attribute5 val_attribute5,
    civ.attribute6 val_attribute6,
    civ.attribute7 val_attribute7,
    civ.attribute8 val_attribute8,
    civ.attribute9 val_attribute9,
    civ.attribute10 val_attribute10,
    civ.attribute11 val_attribute11,
    civ.attribute12 val_attribute12,
    civ.attribute13 val_attribute13,
    civ.attribute14 val_attribute14,
    civ.attribute15 val_attribute15,
-->  csi_i_extended_attribs cea
    cea.attribute_level,
    cea.master_organization_id,
    cea.item_category_id,
    cea.attribute_code,
    cea.attribute_name,
    cea.description,
    cea.attribute1 ext_attribute1,
    cea.attribute2 ext_attribute2,
    cea.attribute3 ext_attribute3,
    cea.attribute4 ext_attribute4,
    cea.attribute5 ext_attribute5,
    cea.attribute6 ext_attribute6,
    cea.attribute7 ext_attribute7,
    cea.attribute8 ext_attribute8,
    cea.attribute9 ext_attribute9,
    cea.attribute10 ext_attribute10,
    cea.attribute11 ext_attribute11,
    cea.attribute12 ext_attribute12,
    cea.attribute13 ext_attribute13,
    cea.attribute14 ext_attribute14,
    cea.attribute15 ext_attribute15,
    cea.created_by ext_attribute16,,*/
-->  hz_parties hzp
    hzp.party_name owner_name,
    hzp.attribute1 owner_cs_region,
-->  mtl_system_items_b msi
    msi.item_type,
    msi.description,
--> fnd_lookup_values_vl flv
    flv.meaning,
 (select ccr.counter_reading
    from csi_counter_readings ccr
   where ccr.counter_id = cca.counter_id
     and ccr.counter_value_id =
         (select max(ccr.counter_value_id)
            from csi_counter_readings ccr
           where ccr.counter_id = cca.counter_id
           group by ccr.counter_id)) as counter_reading,
 (select civ.attribute_value
    from csi_iea_values civ
   where civ.attribute_id = 10000 -- Optimax upgrade date
      and civ.instance_id = cii.instance_id),
 (select civ.attribute_value
    from csi_iea_values civ
   where civ.attribute_id = 11000 -- Tempo upgrade date
      and civ.instance_id = cii.instance_id),
--> xxcs_instance_contract IC
    ic.CONTRACT_SERVICE,
    ic.CONTRACT_COVERAGE,
    ic.CONTRACT_NUMBER,
    ic.CONTRACT_STATUS,
    ic.CONTRACT_START_DATE,
    ic.CONTRACT_END_DATE,
    ic.CONTRACT_LINE_STATUS,
    ic.CONTRACT_LINE_START_DATE,
    ic.CONTRACT_LINE_END_DATE,
-->xxcs_instance_warranty IW
    iw.WARRANTY_SERVICE,
    iw.WARRANTY_COVERAGE,
    iw.WARRANTY_NUMBER,
    iw.WARRANTY_STATUS,
    iw.WARRANTY_START_DATE,
    iw.WARRANTY_END_DATE,
    iw.WARRANTY_LINE_STATUS,
    iw.WARRANTY_LINE_START_DATE,
    iw.WARRANTY_LINE_END_DATE

from csi_item_instances cii,
       csi_systems_v csv,
       mtl_system_items_b msi,
       csi_counter_associations_v cca,
      -- csi_counter_readings ccr,
      -- csi_iea_values civ,
      -- csi_i_extended_attribs cea,
       hz_parties hzp,
       fnd_lookup_values_vl flv,
       xxcs_instance_contract_all IC,
       xxcs_instance_warranty_all IW
where cii.system_id = csv.system_id (+)
   and cii.inventory_item_id (+) = msi.inventory_item_id
   and msi.organization_id = 91
   and cii.instance_id = cca.source_object_id (+)
  -- and cca.counter_id = ccr.counter_id (+)
  -- and cii.instance_id = civ.instance_id (+)
  -- and civ.attribute_id  = cea.attribute_id (+)
   and cii.owner_party_id = hzp.party_id
   and msi.item_type = flv.lookup_code
   and flv.lookup_type  = 'ITEM_TYPE'
   AND cii.instance_id = ic.CONTRACT_INSTANCE_ID (+)
   AND cii.instance_id = iw.WARRANTY_INSTANCE_ID (+);
