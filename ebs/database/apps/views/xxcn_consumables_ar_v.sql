CREATE OR REPLACE VIEW xxcn_consumables_ar_v(
   reseller_bill_to_mismatch_flag
,  commission_exception_flag
,  org_id
,  reseller_id
,  comm_reseller_name
,  reseller_name
,  bill_to_customer_id
,  bill_to_customer_number
,  bill_to_customer
,  bill_to_site_use_id
,  ship_to_customer_id
,  ship_to_customer_number
,  ship_to_customer
,  ship_to_site_use_id
,  ship_to_site_number
,  ship_to_address
,  ship_to_city
,  ship_to_state_province
,  order_number
,  order_type
,  order_line_number
,  order_line_type
,  orig_order_number
,  customer_trx_id
,  customer_trx_line_id
,  invoice_number
,  invoice_line_number
,  invoice_date
,  purchase_order
,  inventory_item_id
,  item_number
,  item_description
,  item_technology
,  price_list
,  qty_invoiced
,  usd_standard_unit_price
,  usd_discount_unit_price
,  comm_factored_line_amount_usd
,  usd_amount                                    
,  weight_kg
,  ct_shared_resellers
,  request_id
)
AS
-- ---------------------------------------------------------------------------------
-- Name:       xxoe_reseller_order_rel_v
-- Created By: MMAZANET
-- Revision:   1.0
-- ---------------------------------------------------------------------------------
-- Purpose: This report shows consumable AR transactions.  For resellers it will show
--          if a transaction is split across multiple resellers as dictated by the
--          commissions module (table xxcn_calc_commission).  The definition of consumables
--          is slightly different for this report than it is for commissions.  Therefore,
--          not all these lines will be on the xxcn_calc_commission table, which is 
--          the reason for the UNION ALL.  Look at the msi table joins in the 
--          master_info WITH clause for a clearer look at how this report defines
--          consumables.
-- ---------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.1  06/15/2014  MMAZANET    Initial Creation for CHG0031576. 
-- ---------------------------------------------------------------------------------
WITH master_info AS
-- Gets base consumable AR data 
/* master_info... */
  (SELECT
   -- Added to show if there were exceptions when bringing this data into the pre-commissions table
   -- (xxcn_calc_commission)
      DECODE(xcce.customer_trx_line_id
      ,  NULL, 'N'
      ,  'Y')                             commission_exception_flag
   ,  xrcav.reseller_name                 bill_to_reseller
   ,  rct.org_id                          org_id
   ,  hca_bill.cust_account_id            bill_to_customer_id
   ,  hca_bill.account_number             bill_to_customer_number
   ,  hp_bill.party_name                  bill_to_customer
   ,  rct.bill_to_site_use_id             bill_to_site_use_id
   ,  hca_ship.cust_account_id            ship_to_customer_id
   ,  hca_ship.account_number             ship_to_customer_number
   ,  hp_ship.party_name                  ship_to_customer
   ,  rct.ship_to_site_use_id             ship_to_site_use_id
   ,  hps_ship.party_site_number          ship_to_site_number
   ,  hl_ship.address1
      ||DECODE(hl_ship.address2,NULL,NULL,', '||hl_ship.address2)
      ||DECODE(hl_ship.address3,NULL,NULL,', '||hl_ship.address3)
      ||DECODE(hl_ship.address4,NULL,NULL,', '||hl_ship.address4)
                                          ship_address
   ,  hl_ship.city                        ship_to_city
   ,  NVL(hl_ship.state,hl_ship.province) ship_to_state_province
   ,  rct.ct_reference                    order_number
   ,  rctl.interface_line_attribute2      order_type
   ,  ool.line_number                     order_line_number
   ,  ottt.name                           order_line_type
   ,  ooh_src.order_number                orig_order_number
   ,  rct.customer_trx_id                 customer_trx_id
   ,  rctl.customer_trx_line_id           customer_trx_line_id
   ,  rct.trx_number                      invoice_number
   ,  rctl.line_number                    invoice_line_number
   ,  rct.trx_date                        invoice_date
   ,  rct.purchase_order                  purchase_order
   ,  msib.inventory_item_id              inventory_item_id
   ,  msib.segment1                       item_number
   ,  msib.description                    item_description 
   ,  micv.segment6                       item_technology
   ,  rctl.quantity_invoiced              qty_invoiced
   ,  pl.name                             price_list
   ,  DECODE(rct.invoice_currency_code
      ,  'USD',   NVL(ool.unit_list_price,0) 
      ,  DECODE(rct.invoice_currency_code
         ,  'USD',   NVL(ool.unit_list_price,0) 
         ,  (NVL(ool.unit_list_price,0)  *
               gl_currency_api.get_closest_rate( 
                  /*from*/rct.invoice_currency_code /*to*/
               ,  'USD' /*date*/
               ,  NVL(rct.exchange_date,rct.trx_date)
               ,  'Corporate'
               ,  10))))                  usd_standard_unit_price
   ,  DECODE(rct.invoice_currency_code
      ,  'USD',   NVL(ool.unit_selling_price,0) 
      ,  DECODE(rct.invoice_currency_code
         ,  'USD',   NVL(ool.unit_selling_price,0) 
         ,  (NVL(ool.unit_selling_price,0) *
               gl_currency_api.get_closest_rate( 
                  /*from*/rct.invoice_currency_code /*to*/
               ,  'USD' /*date*/
               ,  NVL(rct.exchange_date,rct.trx_date)
               ,  'Corporate'
               ,  10))))                  usd_discount_unit_price
   ,  DECODE(rct.invoice_currency_code
      ,  'USD',   rctl.extended_amount
      ,  DECODE(rct.invoice_currency_code
         ,  'USD',   rctl.extended_amount
         ,  (rctl.extended_amount *
               gl_currency_api.get_closest_rate( 
                  /*from*/rct.invoice_currency_code /*to*/
               ,  'USD' /*date*/
               ,  NVL(rct.exchange_date,rct.trx_date)
               ,  'Corporate'
               ,  10))))                  usd_amount   
   -- Taken from the XXINV_OM_GENERAL_REPORT_V
   ,  ROUND(
         DECODE(xxinv_utils_pkg.is_fdm_item(ool.ordered_item_id,NULL)
         ,  'Y',  ROUND(msib.unit_weight * ool.ordered_quantity,0) 
         ,  'N',  DECODE(catalog_weight.element_value
               ,  NULL, NULL
               ,  catalog_weight.element_value * ool.ordered_quantity)
         ,  NULL)
      ,  3)                               weight_kg
   FROM   
      ra_customer_trx_lines_all              rctl
   ,  ra_customer_trx_all                    rct
   -- Order Info
   ,  oe_order_lines_all                     ool
   ,  qp_secu_list_headers_v                 pl
   ,  oe_transaction_types_tl                ottt
   ,  oe_order_headers_all                   ooh_src
   ,  ra_cust_trx_types_all                  ctt
   ,  ar_lookups                             l1
   -- Item info 
   ,  mtl_system_items_b                     msib
   ,  mtl_parameters                         mp
   ,  mtl_item_categories_v                  micv
   -- Customer info
   ,  hz_cust_accounts_all                   hca_bill
   ,  hz_parties                             hp_bill
   ,  hz_cust_accounts_all                   hca_ship
   ,  hz_parties                             hp_ship
   ,  hz_cust_site_uses_all                  hcsua_ship
   ,  hz_cust_acct_sites_all                 hcasa_ship
   ,  hz_party_sites                         hps_ship
   ,  hz_locations                           hl_ship   
   ,  hz_cust_site_uses_all                  hcsua_bill
   ,  hz_cust_acct_sites_all                 hcasa_bill
   ,  hz_party_sites                         hps_bill
   ,  hz_locations                           hl_bill
   -- Reseller custom mapping
   ,  xxcn_reseller_to_cust_acct_v           xrcav
   -- Commission exceptions
   ,  xxcn_calc_commission_exception         xcce
   /* catalog_weight... */
   , (SELECT 
         mde.inventory_item_id
      ,  mde.element_value 
      FROM
         mtl_system_items_b            msib
      ,  mtl_parameters                mp
      ,  mtl_descr_element_values_v    mde
      WHERE msib.organization_id          =  mp.organization_id
      AND   mp.organization_id            =  mp.master_organization_id
      AND   mde.inventory_item_id         =  msib.inventory_item_id
      AND   mde.item_catalog_group_id     =  msib.item_catalog_group_id
      AND   msib.item_catalog_group_id    = 2
      AND   mde.element_name              = 'Weight Factor (Kg)') 
                                             catalog_weight   
   /* ...catalog_weight */        
   WHERE rctl.line_type                   = 'LINE' 
   AND   rctl.customer_trx_id             = rct.customer_trx_id
   AND   rctl.interface_line_context      = 'ORDER ENTRY'
   -- Definition  consumables for this paticular report as dictated by Aaron Hall
   AND   msib.inventory_item_id           = micv.inventory_item_id
   AND   msib.organization_id             = micv.organization_id 
   AND   micv.category_set_name           = 'Product Hierarchy'
   AND   micv.segment1                    = 'Materials'
   AND   micv.segment2                    <> 'Cleaning'
   -- Item join
   AND   rctl.inventory_item_id           = msib.inventory_item_id
   AND   msib.organization_id             = mp.organization_id
   AND   mp.organization_id               = mp.master_organization_id
   -- AR to OM Join
   AND   TO_NUMBER(rctl.interface_line_attribute6)   
                                          = ool.line_id
   AND   ool.reference_header_id          = ooh_src.header_id (+)
   AND   ool.line_type_id                 = ottt.transaction_type_id
   AND   ool.price_list_id                = pl.list_header_id (+)
   AND   ottt.language                    = userenv('LANG')
   AND   rct.complete_flag                = 'Y'
   -- reference field lookups
   AND   rct.cust_trx_type_id             = ctt.cust_trx_type_id
   AND   rct.org_id                       = ctt.org_id
   AND   ctt.post_to_gl                   = 'Y'
   AND   ctt.type                         = l1.lookup_code
   AND   l1.lookup_type                   = 'INV/CM'
   -- Customer join
   AND   rct.ship_to_customer_id          = hca_ship.cust_account_id 
   AND   hca_ship.party_id                = hp_ship.party_id
   AND   rct.ship_to_site_use_id          = hcsua_ship.site_use_id 
   AND   hcsua_ship.cust_acct_site_id     = hcasa_ship.cust_acct_site_id  
   AND   hcasa_ship.party_site_id         = hps_ship.party_site_id
   AND   hps_ship.location_id             = hl_ship.location_id
   AND   hl_ship.country                  IN ('US','CA') 
   AND   rct.bill_to_customer_id          = hca_bill.cust_account_id 
   AND   hca_bill.party_id                = hp_bill.party_id
   AND   rct.bill_to_site_use_id          = hcsua_bill.site_use_id 
   AND   hcsua_bill.cust_acct_site_id     = hcasa_bill.cust_acct_site_id 
   AND   hcasa_bill.party_site_id         = hps_bill.party_site_id 
   AND   hps_bill.location_id             = hl_bill.location_id 
   AND   hl_bill.country                  IN ('US','CA')                      
   -- Delivery Info
   AND   msib.inventory_item_id           = catalog_weight.inventory_item_id (+)
   AND   hca_bill.cust_account_id         = xrcav.customer_id (+)
   AND   rctl.customer_trx_line_id        = xcce.customer_trx_line_id (+)
)
-- Get any lines existing in xxcn_calc_commission
SELECT
   -- Added to detect when the reseller does not match the reseller the bill to 
   -- customer is linked to
   CASE 
      WHEN mi.bill_to_reseller <> NVL(jrre.source_name,'X') THEN
         'Y'
      ELSE 'N'
   END                                                                                 reseller_bill_to_mismatch_flag
,  mi.commission_exception_flag
,  mi.org_id                                                                                              
,  xcc.reseller_id                                                                                        
,  jrre.source_name                                                                       comm_reseller_name
-- Remove 'Commissions, -' and 'No Commission, -' from resellers
,  SUBSTR(jrre.source_name,INSTR(jrre.source_name,',  - ')+5,LENGTH(jrre.source_name))    reseller_name
,  mi.bill_to_customer_id                                                                                 
,  mi.bill_to_customer_number                                                                             
,  mi.bill_to_customer                                                                                    
,  mi.bill_to_site_use_id                                                                                 
,  mi.ship_to_customer_id                                                                                 
,  mi.ship_to_customer_number                                                                             
,  mi.ship_to_customer                                                                                    
,  mi.ship_to_site_use_id   
,  mi.ship_to_site_number
,  mi.ship_address                                                                                        
,  mi.ship_to_city                                                                                        
,  mi.ship_to_state_province                                                                                 
,  mi.order_number  
,  mi.order_type
,  mi.order_line_number                                                                                   
,  mi.order_line_type                                                                                     
,  mi.orig_order_number                                                                                   
,  mi.customer_trx_id                                                                                     
,  mi.customer_trx_line_id                                                                                
,  mi.invoice_number                                                                                      
,  mi.invoice_line_number                                                                                 
,  mi.invoice_date                                                                                        
,  mi.purchase_order                                                                                      
,  mi.inventory_item_id                                                                                   
,  mi.item_number                                                                                         
,  mi.item_description
,  mi.item_technology
,  mi.price_list
,  mi.qty_invoiced                                                                                        
,  mi.usd_standard_unit_price                                                                             
,  mi.usd_discount_unit_price                                                                             
,  NVL(xcc.customer_trx_line_amount,mi.usd_amount)    comm_factored_line_amount_usd                       
,  mi.usd_amount                                                                                          
,  mi.weight_kg                                                                                           
,  COUNT(*) OVER (PARTITION BY xcc.customer_trx_line_id)                                                  
                                                      ct_shared_resellers 
,  xcc.request_id
FROM
/* xcc... */  
  (SELECT
      customer_trx_line_id  
   ,  reseller_id
   ,  request_id
   ,  SUM(customer_trx_line_amount) customer_trx_line_amount
   FROM xxcn_calc_commission          
   GROUP BY 
      customer_trx_line_id
   ,  reseller_id
   ,  request_id)                  xcc
/* ...xcc */
,  master_info                      mi
,  jtf_rs_resource_extns            jrre
WHERE xcc.customer_trx_line_id      = mi.customer_trx_line_id
AND   xcc.reseller_id               = jrre.resource_id
AND   jrre.category                 = 'SUPPLIER_CONTACT'
UNION ALL
-- Get all other lines not existing in xxcn_calc_commission
SELECT 
-- This would never mismatch because the reseller is being derived from the bill to customer
   'N'                                                                                             reseller_bill_to_mismatch_flag
,  mi.commission_exception_flag
,  mi.org_id
,  xrcav.reseller_id
,  xrcav.reseller_name                                                                             comm_reseller_name
-- Remove 'Commissions, -' and 'No Commission, -' from resellers
,  SUBSTR(xrcav.reseller_name,INSTR(xrcav.reseller_name,',  - ')+5,LENGTH(xrcav.reseller_name))    reseller_name
,  mi.bill_to_customer_id
,  mi.bill_to_customer_number
,  mi.bill_to_customer
,  mi.bill_to_site_use_id
,  mi.ship_to_customer_id
,  mi.ship_to_customer_number
,  mi.ship_to_customer
,  mi.ship_to_site_use_id
,  mi.ship_to_site_number
,  mi.ship_address
,  mi.ship_to_city
,  mi.ship_to_state_province
,  mi.order_number
,  mi.order_type
,  mi.order_line_number
,  mi.order_line_type
,  mi.orig_order_number
,  mi.customer_trx_id
,  mi.customer_trx_line_id
,  mi.invoice_number
,  mi.invoice_line_number
,  mi.invoice_date
,  mi.purchase_order
,  mi.inventory_item_id
,  mi.item_number
,  mi.item_description
,  mi.item_technology
,  mi.price_list
,  mi.qty_invoiced
,  mi.usd_standard_unit_price
,  mi.usd_discount_unit_price
,  mi.usd_amount                          comm_factored_line_amount_usd
,  mi.usd_amount                                    
,  mi.weight_kg
,  TO_NUMBER(NULL)                        ct_shared_resellers
,  TO_NUMBER(NULL)                        request_id
FROM
   master_info                   mi
,  xxcn_reseller_to_cust_acct_v  xrcav
WHERE mi.bill_to_customer_id  = xrcav.customer_id (+)
-- Exclude records from first half of UNION
AND   NOT EXISTS (SELECT null
                  FROM
                     xxcn_calc_commission    xcc1
                  WHERE xcc1.customer_trx_line_id = mi.customer_trx_line_id)
/

SHOW ERRORS
                     