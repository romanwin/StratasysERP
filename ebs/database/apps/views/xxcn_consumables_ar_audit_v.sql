CREATE OR REPLACE VIEW xxcn_consumables_ar_audit_v(
   customer_trx_line_id                
,  customer_trx_id
,  invoice_date
,  invoice_number
,  invoice_line_number
,  consumable_item
,  consumable_item_description
,  consumable_business_line
,  consumable_product
,  consumable_family
,  reseller_order_rel_id
,  system_order_number
,  system_order_line_number
,  system_reseller_name
,  system_ship_to_cust_number
,  system_ship_to_cust_name
,  system_ship_to_site_number
,  system_serial_number
,  system_item
,  system_item_description
,  system_item_business_line
,  system_item_product
,  system_item_family
,  system_revenue_pct
)
AS
-- ---------------------------------------------------------------------------------
-- Name:       xxcn_consumables_ar_audit_v
-- Created By: MMAZANET
-- Revision:   1.0
-- ---------------------------------------------------------------------------------
-- Purpose: This view is used to show how calculations are derived on the 
--          xxcn_calc_commission table.  This will trace back to any system orders 
--          on xxoe_reseller_order_rel that make up the calculation for a paticular
--          row in the xxcn_calc_commission table.
-- ---------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.1  06/15/2014  MMAZANET    Initial Creation for CHG0031576. 
-- ---------------------------------------------------------------------------------
SELECT 
   xcc.customer_trx_line_id                  customer_trx_line_id                
,  rct.customer_trx_id                       customer_trx_id
,  rct.trx_date                              invoice_date
,  rct.trx_number                            invoice_number
,  rctl.line_number                          invoice_line_number
,  msib.segment1                             consumable_item
,  msib.description                          consumable_item_description
,  xcca.consumable_business_line             consumable_business_line
,  xcca.consumable_product                   consumable_product
,  xcca.consumable_family                    consumable_family
,  xror.reseller_order_rel_id                reseller_order_rel_id
,  NVL(TO_CHAR(ooh.order_number),TO_CHAR(xror.source_id))
                                             system_order_number
,  NVL(TO_CHAR(ool.line_number),'HISTORICAL')
                                             system_order_line_number
,  jrre.source_name                          system_reseller_name
,  hca_ship.account_number                   system_ship_to_cust_number
,  hp_ship.party_name                        system_ship_to_cust_name
,  hps_ship.party_site_number                system_ship_to_site_number
,  xror.serial_number                        system_serial_number
,  sys_item.item_number                      system_item
,  sys_item.item_description                 system_item_description
,  xcca.system_business_line                 system_item_business_line
,  xcca.system_product                       system_item_product
,  xcca.system_family                        system_item_family
,  xcca.revenue_pct                          system_revenue_pct
FROM 
   xxcn_calc_commission_audit       xcca
,  ra_customer_trx_lines_all        rctl
,  ra_customer_trx_all              rct
,  mtl_system_items_b               msib
,  mtl_parameters                   mp
-- Get linking Ship To info
,  hz_parties                       hp_ship
,  hz_cust_accounts_all             hca_ship
,  hz_cust_site_uses_all            hcsua_ship
,  hz_cust_acct_sites_all           hcasa_ship
,  hz_party_sites                   hps_ship
-- Get data for sys orders
,  xxoe_reseller_order_rel          xror
,  jtf_rs_resource_extns            jrre
,  oe_order_lines_all               ool
,  oe_order_headers_all             ooh
/* sys_item... */
, (SELECT
      msib.inventory_item_id  inventory_item_id
   ,  msib.segment1           item_number
   ,  msib.description        item_description
   FROM   
      mtl_system_items_b               msib
   ,  mtl_parameters                   mp
   WHERE msib.organization_id = mp.organization_id 
   AND   mp.organization_id   = mp.master_organization_id)
                                    sys_item
/* ...sys_item */
-- Get unique customer transation lines, which will join to audit table
/* xcc... */
, (SELECT
      calc_commission_id                        calc_commission_id
   ,  customer_trx_line_id                      customer_trx_line_id
   --,  reseller_order_rel_id                     reseller_order_rel_id
   ,  ROW_NUMBER() OVER (PARTITION BY customer_trx_line_id ORDER BY processing_date) 
                                                rn
   FROM xxcn_calc_commission)       xcc
/* ...xcc */   
WHERE xcc.rn                              = 1
AND   xcc.calc_commission_id              = xcca.calc_commission_id
AND   xcc.customer_trx_line_id            = rctl.customer_trx_line_id
AND   rctl.customer_trx_id                = rct.customer_trx_id
AND   xcca.ship_to_site_use_id            = hcsua_ship.site_use_id(+)
AND   hcsua_ship.cust_acct_site_id        = hcasa_ship.cust_acct_site_id(+)
AND   hcasa_ship.party_site_id            = hps_ship.party_site_id (+)
AND   hcasa_ship.cust_account_id          = hca_ship.cust_account_id (+)
AND   hca_ship.party_id                   = hp_ship.party_id (+)
AND   rctl.inventory_item_id              = msib.inventory_item_id
AND   msib.organization_id                = mp.organization_id
AND   mp.organization_id                  = mp.master_organization_id
AND   xcca.reseller_order_rel_id          = xror.reseller_order_rel_id (+)
AND   xcca.reseller_id                    = jrre.resource_id (+)
AND   'SUPPLIER_CONTACT'                  = jrre.category (+)
AND   xror.inventory_item_id              = sys_item.inventory_item_id (+)
AND   xror.order_line_id                  = ool.line_id (+)
AND   ool.header_id                       = ooh.header_id (+)
/

SHOW ERRORS
                     