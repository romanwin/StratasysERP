CREATE OR REPLACE VIEW xxcn_consumables_comm_calc_v AS
-- ---------------------------------------------------------------------------------
-- Name:       xxcn_consumables_comm_calc_v
-- Created By: MMAZANET
-- Revision:   1.0
-- ---------------------------------------------------------------------------------
-- Purpose: View used by xxcn_calc_commission_pkg.link_consumables_to_systems procedure
--          to gather eligible consumable AR lines for possible interface to the
--          commissions module.
-- ---------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  04/14/2014  MMAZANET    Initial Creation for CHG0032042.
-- ---------------------------------------------------------------------------------
SELECT 
   rct.trx_number             customer_trx_number
,  rct.customer_trx_id        customer_trx_id
,  rctl.line_number           customer_trx_line_number
,  rctl.customer_trx_line_id  customer_trx_line_id
,  rctl.extended_amount       customer_trx_line_extended_amt
,  rct.trx_date               customer_trx_date
,  rct.org_id                 customer_trx_org_id
,  rct.bill_to_site_use_id    bill_to_site_use_id
,  hca_bill.account_number    bill_to_customer_number
,  hps_bill.party_site_number bill_to_site_number
,  hp_bill.party_name         bill_to_customer
,  hl_bill.country            bill_country
,  rct.ship_to_site_use_id    ship_to_site_use_id
,  hca_ship.account_number    ship_to_customer_number
,  hp_ship.party_name         ship_to_customer
,  hps_ship.party_site_number ship_to_site_number
,  hl_ship.address1           ship_to_address1
,  hl_ship.address2           ship_to_address2
,  hl_ship.city               ship_to_city
,  hl_ship.state              ship_to_state
,  hl_ship.postal_code        ship_to_zip
,  hl_ship.country            ship_country
,  msib.inventory_item_id     inventory_item_id
,  msib.segment1              inventory_item_number
,  msib.description           inventory_item_description
,  msib.organization_id       inventory_organization_id
,  haou.name                  inventory_organization
,  micv.segment3              business_line
,  micv.segment1              product
,  micv.segment2              family
,  pl.name                    price_list
,  ool.line_id                order_line_id
,  xxcn_calc_commission_pkg.get_consumable_id(
      p_business_line      => micv.segment3
   ,  p_product            => micv.segment1
   ,  p_family             => micv.segment2
   ,  p_inventory_item_id  => msib.inventory_item_id
   ,  p_inventory_org_id   => msib.organization_id
   )                          consumable_id
FROM 
   ra_customer_trx_all              rct
,  ra_customer_trx_lines_all        rctl
--,  cn_item_category_v               cic
--,  ra_cust_trx_line_salesreps rctls
,  mtl_item_categories_v            micv   
,  mtl_system_items_b               msib
,  mtl_parameters                   mp
,  hr_all_organization_units        haou
,  hz_cust_site_uses_all            hcsua_ship
,  hz_cust_acct_sites_all           hcasa_ship
,  hz_cust_accounts_all             hca_ship
,  hz_party_sites                   hps_ship
,  hz_locations                     hl_ship
,  hz_parties                       hp_ship
,  hz_cust_site_uses_all            hcsua_bill
,  hz_cust_acct_sites_all           hcasa_bill
,  hz_cust_accounts_all             hca_bill
,  hz_party_sites                   hps_bill
,  hz_locations                     hl_bill
,  hz_parties                       hp_bill
,  oe_order_lines_all         ool
,  qp_secu_list_headers_v     pl
WHERE rct.customer_trx_id              = rctl.customer_trx_id
AND   rctl.interface_line_context      = 'ORDER ENTRY'
AND   rctl.org_id                      = 737
--AND   rct.ct_reference                 = ooh.header_id
AND   ool.org_id                       = 737
AND   TO_NUMBER(rctl.interface_line_attribute6)   
                                       = ool.line_id 
AND   ool.price_list_id                = pl.list_header_id
-- Get Consumables eligible for commissions
AND   rctl.interface_line_attribute2   = 'Standard Materials Order, SSUS'
--AND   rctl.customer_trx_line_id        = cic.customer_trx_line_id
AND   rctl.inventory_item_id           = msib.inventory_item_id
AND   msib.organization_id             = mp.organization_id
AND   mp.organization_id               = mp.master_organization_id
AND   msib.inventory_item_id           = micv.inventory_item_id
AND   msib.organization_id             = micv.organization_id
AND   micv.category_set_name           = 'Commissions'
AND   msib.organization_id             = haou.organization_id
AND   rct.ship_to_site_use_id          = hcsua_ship.site_use_id 
AND   hcsua_ship.cust_acct_site_id     = hcasa_ship.cust_acct_site_id 
AND   hcasa_ship.party_site_id         = hps_ship.party_site_id 
AND   hps_ship.location_id             = hl_ship.location_id 
AND   hcasa_ship.cust_account_id       = hca_ship.cust_account_id 
AND   hca_ship.party_id                = hp_ship.party_id 
AND   rct.bill_to_site_use_id          = hcsua_bill.site_use_id 
AND   hcsua_bill.cust_acct_site_id     = hcasa_bill.cust_acct_site_id 
AND   hcasa_bill.party_site_id         = hps_bill.party_site_id 
AND   hps_bill.location_id             = hl_bill.location_id 
AND   hcasa_bill.cust_account_id       = hca_bill.cust_account_id 
AND   hca_bill.party_id                = hp_bill.party_id
AND   hl_ship.country                  IN ('US','CA')
AND   hl_bill.country                  IN ('US','CA')
AND   NOT EXISTS (SELECT null -- Exclude Business Line
                  FROM fnd_lookup_values_vl       flvv_cons_excl
                  WHERE flvv_cons_excl.lookup_type    = 'XXCN_COMM_BUS_LINE_EXCL'
                  AND   flvv_cons_excl.enabled_flag   = 'Y'
                  AND   flvv_cons_excl.description    = micv.segment3)
/

SHOW ERRORS