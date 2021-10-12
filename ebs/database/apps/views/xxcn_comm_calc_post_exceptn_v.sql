CREATE OR REPLACE VIEW xxcn_comm_calc_post_exceptn_v
-- ---------------------------------------------------------------------------------
-- Name:       xxcn_comm_calc_post_exceptn_v
-- Created By: MMAZANET
-- Revision:   1.0
-- ---------------------------------------------------------------------------------
-- Purpose: This view is used by the XXCN_COMM_CALC_POST_EXCEPTN XML Publisher report.
--          The report is intended to show any exceptions encountered while running 
--          the xxcn_calc_commission_pkg.link_systems_to_consumables procedure, and
--          is automatically kicked off from that procedure.  The error reporting 
--          was getting too complex for simple concurrent program output, so 
--          exceptions are dumped to a table and reported here.  Exceptions dealing
--          with consumables not finding systems fall into the following error_category
--          which are defined below
--
--          SHIP TO SITE MATCH
--          These are records where the consumable's ship to site_use_id matches to
--          a system's site_use_id, however, the consumable itself is not mapped to 
--          a system.  Columns beginning 'sys_' are the matches to the consumable
--
--          SHIP TO ACCOUNT MATCH
--          These are records where the consumable's ship to account matches to a 
--          system's ship to account.  This is used to assist in resolving issues.
--          All sites with a system under that account are in the columns beginning
--          'sys_a_'
--
--          NO MATCH
--          These are records where the consumable's ship to site_use_id and account
--          number don't match to any systems.
--
--          These errors require further research by the users.
-- ---------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  08/10/2014  MMAZANET    Initial Creation for CHG0031576.
-- ---------------------------------------------------------------------------------
AS
WITH systems AS
/* systems... */
  (SELECT
      reseller_order_rel_id                
   ,  source_name                          
   ,  agent_rep                            
   ,  revenue_pct                          
   ,  order_number                         
   ,  order_line_number                    
   ,  inventory_item_number                
   ,  inventory_item_description           
   ,  business_line                        
   ,  product                              
   ,  family                               
   ,  serial_number                        
   ,  ship_to_site_use_id                  
   ,  ship_to_cust_account_id              
   ,  ship_to_account_number               
   ,  ship_to_cust_name                    
   ,  ship_to_site_number                  
   ,  ship_to_address1                     
   ,  ship_to_address2                     
   ,  ship_to_city                         
   ,  ship_to_state                        
   ,  ship_to_zip
   ,  ship_to_country
   FROM xxoe_reseller_order_rel_v
   WHERE order_line_type_category IN ('XXCN_SYS_ORDER_STANDARD','INSTALL_BASE','SFDC'))             
/* ...systems */
SELECT 
   xcce.processing_message
,  CASE 
      WHEN systems_ship.reseller_order_rel_id IS NOT NULL
      THEN 'SHIP TO SITE MATCH'
      WHEN systems_acct.reseller_order_rel_id IS NOT NULL
      THEN 'SHIP TO ACCOUNT MATCH'
      ELSE 'NO MATCH'
   END                                          error_category
,  xcce.customer_trx_line_id
,  xcce.request_id
,  xcce.consumable_id
,  rct.trx_number                               consumable_invoice_number
,  rct.ct_reference                             consumable_order_number
,  rct.trx_date                                 consumable_invoice_date
,  rctl.line_number                             consumable_invoice_line
,  msib.segment1                                consumable_item_number
,  msib.description                             consumable_item_description
,  micv.segment3                                consumable_business_line
,  micv.segment1                                consumable_product
,  micv.segment2                                consumable_family
,  hca_bill_c.account_number                    consumable_bill_cust_number
,  hp_bill_c.party_name                         consumable_bill_cust_name
,  hca_ship_c.account_number                    consumable_ship_cust_number
,  hp_ship_c.party_name                         consumable_ship_cust_name
,  hps_ship_c.party_site_number                 consumable_ship_cust_site_num
,  hl_ship_c.address1
   ||' | '||hl_ship_c.city  
   ||' | '||hl_ship_c.state
   ||' | '||hl_ship_c.postal_code               consumable_ship_address                          
,  hl_ship_c.country                            consumable_country
,  rctl.quantity_invoiced                       qty_invoiced
,  pl.name                                      price_list
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
            ,  10))))                           usd_standard_unit_price
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
            ,  10))))                           usd_discount_unit_price
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
            ,  10))))                           usd_amount   
,  DECODE(systems_ship.reseller_order_rel_id
   ,  NULL, 'N'
   ,  'Y')                                      sys_ship_match_flag
,  systems_ship.order_number                    sys_order_number
,  systems_ship.order_line_number               sys_order_line_number
,  systems_ship.business_line                   sys_business_line
,  systems_ship.product                         sys_product
,  systems_ship.family                          sys_family
,  systems_ship.inventory_item_number           sys_inventory_item_number
,  systems_ship.inventory_item_description      sys_inventory_item
,  systems_ship.reseller_order_rel_id           sys_reseller_order_rel_id
,  systems_ship.source_name                     sys_source_name
,  systems_ship.agent_rep                       sys_agent_rep
,  systems_ship.revenue_pct                     sys_revenue_pct
,  systems_ship.serial_number                   sys_serial_number
,  systems_ship.ship_to_site_use_id             sys_ship_to_site_use_id
,  systems_ship.ship_to_cust_account_id         sys_ship_to_cust_account_id
,  systems_ship.ship_to_account_number          sys_ship_to_account_number
,  systems_ship.ship_to_cust_name               sys_ship_to_cust_name
,  systems_ship.ship_to_site_number             sys_ship_to_site_number
,  systems_ship.ship_to_address1                
   ||' | '||systems_ship.ship_to_city
   ||' | '||systems_ship.ship_to_state
   ||' | '||systems_ship.ship_to_zip
                                                sys_ship_to_address
,  systems_ship.ship_to_country                 sys_ship_country
,  DECODE(systems_acct.reseller_order_rel_id
   ,  NULL, 'N'
   ,  'Y')                                      sys_a_acct_match_flag
,  systems_acct.order_number                    sys_a_order_number
,  systems_acct.order_line_number               sys_a_order_line_number
,  systems_acct.business_line                   sys_a_business_line
,  systems_acct.product                         sys_a_product
,  systems_acct.family                          sys_a_family
,  systems_acct.inventory_item_number           sys_a_inventory_item_number
,  systems_acct.inventory_item_description      sys_a_inventory_item
,  systems_acct.reseller_order_rel_id           sys_a_reseller_order_rel_id
,  systems_acct.source_name                     sys_a_source_name
,  systems_acct.agent_rep                       sys_a_agent_rep
,  systems_acct.revenue_pct                     sys_a_revenue_pct
,  systems_acct.serial_number                   sys_a_serial_number
,  systems_acct.ship_to_site_use_id             sys_a_ship_to_site_use_id
,  systems_acct.ship_to_cust_account_id         sys_a_ship_to_cust_account_id
,  systems_acct.ship_to_account_number          sys_a_ship_to_account_number
,  systems_acct.ship_to_cust_name               sys_a_ship_to_cust_name
,  systems_acct.ship_to_site_number             sys_a_ship_to_site_number
,  systems_acct.ship_to_address1                
   ||' | '||systems_acct.ship_to_city
   ||' | '||systems_acct.ship_to_state
   ||' | '||systems_acct.ship_to_zip
                                                sys_a_ship_to_address
,  systems_acct.ship_to_country                 sys_a_ship_to_country
FROM 
   xxcn_calc_commission_exception            xcce
,  ra_customer_trx_lines_all                 rctl
,  ra_customer_trx_all                       rct
,  mtl_item_categories_v                     micv   
,  mtl_system_items_b                        msib
,  mtl_parameters                            mp
,  hz_parties                                hp_ship_c
,  hz_cust_accounts_all                      hca_ship_c
,  hz_cust_site_uses_all                     hcsua_ship_c
,  hz_cust_acct_sites_all                    hcasa_ship_c
,  hz_party_sites                            hps_ship_c
,  hz_locations                              hl_ship_c
,  hz_cust_accounts_all                      hca_bill_c
,  hz_parties                                hp_bill_c
,  systems                                   systems_ship
,  systems                                   systems_acct
,  oe_order_lines_all                        ool
,  qp_secu_list_headers_v                    pl
WHERE xcce.customer_trx_line_id           = rctl.customer_trx_line_id
AND   rctl.org_id                         = 737
AND   rctl.customer_trx_id                = rct.customer_trx_id
AND   rctl.inventory_item_id              = msib.inventory_item_id
AND   msib.organization_id                = mp.organization_id
AND   mp.organization_id                  = mp.master_organization_id
AND   msib.inventory_item_id              = micv.inventory_item_id
AND   msib.organization_id                = micv.organization_id
AND   micv.category_set_name              = 'Commissions'
AND   rct.ship_to_site_use_id             = hcsua_ship_c.site_use_id
AND   hcsua_ship_c.cust_acct_site_id      = hcasa_ship_c.cust_acct_site_id
AND   hcasa_ship_c.party_site_id          = hps_ship_c.party_site_id 
AND   hps_ship_c.location_id              = hl_ship_c.location_id
AND   hcasa_ship_c.cust_account_id        = hca_ship_c.cust_account_id 
AND   hca_ship_c.party_id                 = hp_ship_c.party_id
AND   rct.bill_to_customer_id             = hca_bill_c.cust_account_id (+)
AND   hca_bill_c.party_id                 = hp_bill_c.party_id (+)
AND   rctl.interface_line_context         = 'ORDER ENTRY'
AND   TO_NUMBER(rctl.interface_line_attribute6)   
                                          = ool.line_id 
AND   ool.price_list_id                   = pl.list_header_id                                          
-- Find all ship to sites under ship to account.  Analysis will be done 
-- Look for systems on consumable ship to
AND   rct.ship_to_site_use_id             = systems_ship.ship_to_site_use_id (+)
AND   hca_ship_c.cust_account_id          = systems_acct.ship_to_cust_account_id (+)
/

SHOW ERRORS