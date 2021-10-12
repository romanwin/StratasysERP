CREATE OR REPLACE VIEW XXCSI_INST_LEGACY_DTLS_V AS
SELECT
-- =============================================================================
-- Copyright(c) :
-- Application  : Custom Application
-- -----------------------------------------------------------------------------
-- Program name                 	Creation Date    Original Ver    Created by
-- XXCSI_INST_LEGACY_DTLS_V	    		01-JUL-2016      1.0             TCS
-- -----------------------------------------------------------------------------
-- Usage: View creation script
--
-- -----------------------------------------------------------------------------
-- Description: This is a view creation script for install base interim solution.
--
--
-- Parameter    : None
-- Return value : None
-- -----------------------------------------------------------------------------
-- Modification History:
-- Modified Date     Version      Done by       Change Description
--
-- =============================================================================
    x_base.instance_id,
    x_base.parent_id ,
    x_base.child_id,
    x_base.instance_number,
    x_base.relationship_type_code,
    x_base.relationship_end_date ,
    x_base.instance_end_date,
    x_base.serial_number,
    x_base.mstr_serial_num,
    x_base.mstr_segment1,
    x_base.lot_number,
    x_base.inv_locator_id,
    x_base.inventory_item_id,
    x_base.inv_master_organization_id,
    x_base.inv_organization_id,
    x_base.instance_status_id,
    x_base.INSTANCE_USAGE_CODE,
    x_base.customer_view_flag,
    x_base.merchant_view_flag,
    x_base.inv_subinventory_name,
    x_base.quantity,
    x_base.unit_of_measure,
    x_base.mfg_serial_number_flag,
    x_base.active_start_date,
    x_base.install_date,
    x_base.owner_party_source_table,
    x_base.owner_party_id,
    x_base.owner_party_account_id,
    x_base.instance_description,
    X_BASE.segment1,
    X_BASE.segment2,
    X_BASE.last_oe_order_line_id,
    X_BASE.attribute1,
    X_BASE.attribute2,
    X_BASE.attribute3,
    X_BASE.attribute4,
    X_BASE.attribute5,
    X_BASE.attribute6,
    X_BASE.attribute7,
    X_BASE.attribute8,
    X_BASE.legacy_instance_id,
    X_BASE.attribute10,
    X_BASE.attribute11,
    X_BASE.sf_id,
    X_BASE.attribute13,
    X_BASE.attribute14,
    X_BASE.attribute15,
    X_BASE.attribute16,
    X_BASE.attribute17,
    X_BASE.attribute18,
    X_BASE.attribute19,
    X_BASE.attribute20,
    X_BASE.attribute21,
    X_BASE.attribute22,
    X_BASE.attribute23,
    X_BASE.attribute24,
    X_BASE.attribute25,
    X_BASE.attribute26,
    X_BASE.attribute27,
    X_BASE.attribute28,
    X_BASE.attribute29,
    X_BASE.attribute30,
    x_base.location_type_code,
    x_base.location_id,
    x_base.install_location_type_code,
    x_base.install_location_id,
    ooh.cust_po_number,
    OOH.ORIG_SYS_DOCUMENT_REF,
    ott.name
  FROM
    (SELECT CII.instance_id,
      CIR.parent_id,
      CIR.child_id,
      CII.instance_number,
      CIR.relationship_type_code,
      CIR.rel_active_start_date relationship_end_date ,
      CIR.rel_active_end_date instance_end_date,
      CII.serial_number,
      MSTR_cii.serial_number mstr_serial_num,
      MSTR_msi.segment1 mstr_segment1,
      CII.lot_number,
      CII.inv_locator_id,
      CII.inventory_item_id,
      CII.inv_master_organization_id,
      CII.inv_organization_id,
      CII.instance_status_id,
      CII.instance_usage_code,
      CII.customer_view_flag,
      CII.merchant_view_flag,
      CII.inv_subinventory_name,
      CII.quantity,
      CII.unit_of_measure,
      CII.mfg_serial_number_flag,
      CII.active_start_date,
      CII.install_date,
      CII.owner_party_source_table,
      CII.owner_party_id,
      CII.owner_party_account_id,
      CII.instance_description,
      MSI.segment1,
      MSI.segment2,
      CII.last_oe_order_line_id,
      CII.attribute1,
      CII.attribute2,
      CII.attribute3,
      CII.attribute4,
      CII.attribute5,
      CII.attribute6,
      CII.attribute7,
      CII.attribute8,
      CII.attribute9 legacy_instance_id,
      CII.attribute10,
      CII.attribute11,
      CII.attribute12 sf_id,
      CII.attribute13,
      CII.attribute14,
      CII.attribute15,
      CII.attribute16,
      CII.attribute17,
      CII.attribute18,
      CII.attribute19,
      CII.attribute20,
      CII.attribute21,
      CII.attribute22,
      CII.attribute23,
      CII.attribute24,
      CII.attribute25,
      CII.attribute26,
      CII.attribute27,
      CII.attribute28,
      CII.attribute29,
      CII.attribute30,
       -- Locations
      CII.location_type_code,
      CII.location_id,
      CII.install_location_type_code,
      CII.install_location_id
    FROM csi_item_instances CII,
      csi_item_instances MSTR_CII,
      csi_inst_child_details_v CIR,
      mtl_system_items_b MSI,
      mtl_system_items_b MSTR_MSI,
      csi_instance_statuses CIS
      --
    WHERE CII.instance_id                 = CIR.child_id
    AND CII.last_vld_organization_id      = MSI.organization_id
    AND MSI.inventory_item_id             = CII.inventory_item_id
    AND CIS.instance_status_id            = CII.instance_status_id
    AND MSTR_CII.instance_id              = CIR.parent_id
    AND MSTR_CII.inventory_item_id        = MSTR_msi.inventory_item_id
    AND MSTR_CII.last_vld_organization_id = MSTR_msi.organization_id
    AND CIS.Name                          ='Shipped'
    ) X_BASE,
    APPS.oe_order_lines_all OOL,
    APPS.oe_order_headers_all OOH,
    APPS.oe_transaction_types_tl OTT
  WHERE 1                          =1
  AND X_BASE.last_oe_order_line_id = OOL.line_id
  AND OOH.header_id                = OOL.header_id
  AND OOH.ORDER_TYPE_ID            = OTT.TRANSACTION_TYPE_ID
  AND ott.name                     = 'Internal Interim Order-OBJ IL'
  AND OTT.language                 = 'US'
