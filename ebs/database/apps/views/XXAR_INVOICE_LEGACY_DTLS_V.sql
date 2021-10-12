CREATE OR REPLACE VIEW XXAR_INVOICE_LEGACY_DTLS_V AS
SELECT
-- =============================================================================
-- Copyright(c) :
-- Application  : Custom Application
-- -----------------------------------------------------------------------------
-- Program name                    Creation Date    Original Ver    Created by
-- XXAR_INVOICE_LEGACY_DTLS_V        17-aug-2016      1.0             Vindhya
-- -----------------------------------------------------------------------------
-- Usage: Table creation script
--
-- -----------------------------------------------------------------------------
-- Description: This is a Detailed view script. This table will be used to
--              hold AR Invoice table information.
-- Parameter    : None
-- Return value : None
-- -----------------------------------------------------------------------------
-- Modification History:
-- Modified Date     Version      Done by       Change Description
--
-- =============================================================================
       rcta.customer_trx_id,
       rcta.trx_number || '-Interim' invoice_num,
       rctla.customer_trx_line_id,
       flvv.attribute1 operating_unit,
       flvv.attribute4 so_operating_unit,
       flvv.attribute9 email_address,
       substr(ooha.cust_po_number, 1, instr(ooha.cust_po_number, '-') - 1) po_number,
       substr(ooha.CUST_PO_NUMBER,
              instr(ooha.CUST_PO_NUMBER, '-') + 1,
              (instr(ooha.CUST_PO_NUMBER, '-', 1, 2) - 1) -
              (instr(ooha.CUST_PO_NUMBER, '-'))) release_number,
       substr(ooha.CUST_PO_NUMBER,
              (instr(ooha.CUST_PO_NUMBER, '-', 1, 2) + 1)) release_revision,
       ooha.orig_sys_document_ref release_id,
       substr(oola.orig_sys_line_ref,
              (instr(oola.orig_sys_line_ref, '-') + 1)) line_location_id,
       rctla.quantity_invoiced,
       msib.segment1 item_number,
       msib.description,
       rcta.interface_header_attribute1 sales_order_num,
       oola.line_number  sales_order_line_num,
	   rcta.trx_date     invoice_date
  FROM ra_customer_trx_all       rcta,
       ra_customer_trx_lines_all rctla,
       oe_order_headers_all      ooha,
       oe_order_lines_all        oola,
       oe_order_sources          oos,
       hz_cust_accounts          hca,
       fnd_lookup_values_vl      flvv,
       mtl_system_items_b        msib,
       hr_operating_units        hou,
       hz_cust_acct_sites_all    hcasa,
       hz_cust_site_uses_all     hcsua,
       hz_party_sites            hps
 where rcta.customer_trx_id = rctla.customer_trx_id
   and rcta.interface_header_attribute1 = to_char(ooha.order_number)
   and ooha.header_id = oola.header_id
   and rctla.interface_line_attribute6 = to_char(oola.line_id)
   and ooha.org_id = rcta.org_id
   and rctla.interface_line_attribute1 = to_char(ooha.order_number)
   and rctla.sales_order = to_char(ooha.order_number)
   and rctla.line_type = 'LINE'
   and rctla.inventory_item_id = msib.inventory_item_id
   and msib.organization_id =
       (SELECT DISTINCT master_organization_id FROM mtl_parameters)
   and ooha.sold_to_org_id = hca.cust_account_id
   and hou.organization_id = ooha.org_id
   and ooha.invoice_to_org_id = hcsua.site_use_id
   and hcasa.cust_acct_site_id = hcsua.cust_acct_site_id
   and hps.party_site_id = hcasa.party_site_id
   and ooha.order_source_id = oos.order_source_id
   and flvv.lookup_type = 'XX_S3_INTERIM_SHIPPING_NETWORK'
   and nvl(flvv.enabled_flag, 'N') = 'Y'
   and sysdate between nvl(flvv.START_DATE_ACTIVE, sysdate) and
       nvl(flvv.END_DATE_ACTIVE, sysdate + 1)
   and hca.account_name = flvv.attribute5
   and hps.party_site_name = flvv.attribute6
   and hou.name = flvv.attribute4
   and oos.name = 'S3 INTERIM'

-- =============================================================================
--           End Of view Creation script for XXAR_INVOICE_LEGACY_DTLS_V
-- =============================================================================
/
-- =============================================================================
--            Provide Grant on XXAR_INVOICE_LEGACY_DTLS_V to XXSYNC
-- =============================================================================
GRANT SELECT 
   ON XXAR_INVOICE_LEGACY_DTLS_V
   TO xxsync
/
-- =============================================================================
--            Provide Grant on ra_customer_trx_all to XXSYNC
-- =============================================================================
GRANT SELECT 
   ON ra_customer_trx_all
   TO xxsync
/
-- =============================================================================
--            Provide Grant on ra_customer_trx_lines_all to XXSYNC
-- =============================================================================
GRANT SELECT 
   ON ra_customer_trx_lines_all
   TO xxsync
/
-- =============================================================================
--            Provide Grant on oe_order_headers_all to XXSYNC
-- =============================================================================
GRANT SELECT 
   ON oe_order_headers_all
   TO xxsync
/
-- =============================================================================
--            Provide Grant on oe_order_lines_all to XXSYNC
-- =============================================================================
GRANT SELECT 
   ON oe_order_lines_all
   TO xxsync
/
-- =============================================================================
--            Provide Grant on hz_cust_accounts to XXSYNC
-- =============================================================================
GRANT SELECT 
   ON hz_cust_accounts
   TO xxsync
/
-- =============================================================================
--            Provide Grant on fnd_lookup_values_vl to XXSYNC
-- =============================================================================
GRANT SELECT 
   ON fnd_lookup_values_vl
   TO xxsync
/
-- =============================================================================
--            Provide Grant on mtl_system_items_b to XXSYNC
-- =============================================================================
GRANT SELECT 
   ON mtl_system_items_b
   TO xxsync
/
-- =============================================================================
--            Provide Grant on hr_operating_units to XXSYNC
-- =============================================================================
GRANT SELECT 
   ON hr_operating_units
   TO xxsync
/
-- =============================================================================
--            Provide Grant on hz_cust_acct_sites_all to XXSYNC
-- =============================================================================
GRANT SELECT 
   ON hz_cust_acct_sites_all
   TO xxsync
/
-- =============================================================================
--            Provide Grant on hz_cust_site_uses_all to XXSYNC
-- =============================================================================
GRANT SELECT 
   ON hz_cust_site_uses_all
   TO xxsync
/
-- =============================================================================
--            Provide Grant on hz_party_sites to XXSYNC
-- =============================================================================
GRANT SELECT 
   ON hz_party_sites
   TO xxsync
/
-- =============================================================================
--                                 End Of script
-- =============================================================================