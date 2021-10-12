CREATE OR REPLACE VIEW xxcn_system_orders_v
-- ---------------------------------------------------------------------------------
-- Name:       xxcn_system_items_v
-- Created By: MMAZANET
-- Revision:   1.0
-- ---------------------------------------------------------------------------------
-- Purpose: View used to show system order lines.  This is used by the 
--          xxoe_reseller_order_rel_pkg.insert_xxoe_reseller_order_rel
--          and the XXOERESELLORDRREL.fmb form to get system order lines
-- ---------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  06/10/2014  MMAZANET    Initial Creation for CHG0031576.
-- ---------------------------------------------------------------------------------
AS
SELECT
   ooh.header_id                                   order_header_id
,  ool.line_id                                     order_line_id
,  ooh.order_number                                order_number                                                                 
,  ottt_header.name                                order_type
,  ool.line_number                                 order_line_number
,  ool.org_id                                      order_org_id
,  ottt_line.name                                  order_line_type
,  flvv_order_type.lookup_type                     order_line_type_category                                                     
,  wd.confirm_date                                 delivery_confirm_date
,  wsn.delivery_detail_id                          delivery_detail_id 
,  wsn.fm_serial_number                            serial_number                                                                                                                    
,  ool.sold_to_org_id                              customer_id 
,  hca.account_number                              customer_number
,  hp.party_name                                   customer_name
,  rctla.customer_trx_line_id                      customer_trx_line_id
,  TO_NUMBER(ooh.attribute10)                      reseller_id                                                                  
,  jrre.source_name                                reseller_name                                                                
,  TO_NUMBER(NULL)                                 reseller_indirect_id             -- Need definition from Kim                 
,  NULL                                            reseller_indirect_name  
,  msib.segment1                                   inventory_item_number
,  msib.description                                inventory_item_description
,  ool.inventory_item_id                           inventory_item_id
,  micv.segment3                                   business_line
,  micv.segment1                                   product
,  micv.segment2                                   family
,  100                                             revenue_pct                                                                                                                                     
,  wsn.delivery_detail_id                          source_id                                                                    
,  'ORDER_DELIVERY'                                source_name                                                                  
,  qslhv.name                                      price_list_name
,  ool.ship_to_org_id                              ship_to_site_use_id 
,  hca_ship.account_number                         ship_to_customer_number
,  hp_ship.party_name                              ship_to_customer
,  hps_ship.party_site_number                      ship_to_site_number
,  hl_ship.country                                 ship_to_country                                                              
,  hl_bill.country                                 bill_to_country                                                              
,  ooh_ref.order_number                            order_source_reference                                                       
FROM 
-- Get item info
   mtl_item_categories_v            micv
,  mtl_system_items_b               msib
,  mtl_parameters                   mp
-- Get order info
,  oe_order_headers_all             ooh
,  oe_transaction_types_tl          ottt_line
,  oe_transaction_types_tl          ottt_header
,  oe_order_lines_all               ool
,  oe_order_headers_all             ooh_ref
-- Get pricelist
,  qp_secu_list_headers_v           qslhv
-- Get reseller
,  jtf_rs_resource_extns            jrre
--,  oe_transaction_types             otta
-- Get invoice info
,  ra_customer_trx_lines_all        rctla
-- Get shipping/serial number 
,  wsh_delivery_details             wdd
,  wsh_delivery_assignments         wdda
,  wsh_new_deliveries               wd
,  wsh_serial_numbers               wsn
-- get reseller off order
,  fnd_descr_flex_col_usage_vl      fdfcuv 
,  fnd_flex_value_sets              ffvs
,  fnd_lookup_values_vl             flvv
,  fnd_lookup_values_vl             flvv_order_type
-- Get customer info
,  hz_cust_accounts_all             hca
,  hz_parties                       hp
-- Get Ship To
,  hz_parties                       hp_ship
,  hz_cust_accounts_all             hca_ship
,  hz_cust_site_uses_all            hcsua_ship
,  hz_cust_acct_sites_all           hcasa_ship
,  hz_party_sites                   hps_ship
,  hz_locations                     hl_ship
-- Get Bill To location
,  hz_cust_site_uses_all            hcsua_bill
,  hz_cust_acct_sites_all           hcasa_bill
,  hz_party_sites                   hps_bill
,  hz_locations                     hl_bill
WHERE micv.category_set_name              = 'Commissions'
-- Only pulls systems set up in the xxcn_system_items table at the business line/product level
AND   EXISTS  (SELECT null -- Find eligible systems
               FROM xxcn_system_items  xsi
               WHERE SYSDATE                 BETWEEN NVL(start_date,'01-JAN-1900')
                                                AND NVL(end_date,'31-DEC-4712')
               AND   parent_system_flag      = 'Y'
               AND   exclude_flag            = 'N'
               AND   xsi.business_line       = micv.segment3
               AND   xsi.product             = micv.segment1)
-- Get system item 
AND   micv.inventory_item_id              = ool.inventory_item_id
AND   micv.organization_id                = msib.organization_id
AND   msib.inventory_item_id              = ool.inventory_item_id
AND   msib.organization_id                = mp.organization_id
AND   mp.organization_id                  = mp.master_organization_id
-- Get order info
AND   ooh.header_id                       = ool.header_id
AND   ool.price_list_id                   = qslhv.list_header_id
AND   ool.source_document_id              = ooh_ref.header_id (+)
AND   ooh.order_type_id                   = ottt_header.transaction_type_id
-- Join to get only specific header types
AND   ottt_header.language                = userenv('LANG')
                                            -- Order type and line type are concatenated together in the description
                                            -- field by ~
AND   ottt_header.name                    = SUBSTR(flvv_order_type.description,1,INSTR(flvv_order_type.description,'~')-1)
-- Join to get only specific line types
AND   ool.line_type_id                    = ottt_line.transaction_type_id
AND   ottt_line.language                  = userenv('LANG')
                                            -- Order type and line type are concatenated together in the description
                                            -- field by ~
AND   ottt_line.name                      = SUBSTR(flvv_order_type.description,INSTR(flvv_order_type.description,'~')+1,LENGTH(flvv_order_type.description))
AND   flvv_order_type.lookup_type         IN ('XXCN_SYS_ORDER_CREDIT','XXCN_SYS_ORDER_STANDARD','XXCN_SYS_INVOICE_ONLY') 
AND   flvv_order_type.enabled_flag        = 'Y'
-- Join to reseller
AND   TO_NUMBER(ooh.attribute10)          = jrre.resource_id (+)
AND   'SUPPLIER_CONTACT'                  = jrre.category (+)         
-- Join to AR
AND   rctla.org_id                        = ool.org_id
AND   rctla.interface_line_Attribute6     = ool.line_id
AND   rctla.interface_line_context        IN ('ORDER ENTRY', 'INTERCOMPANY')
-- Join to shipping for serial numbers
AND   ool.line_id                         = wdd.source_line_id (+)
AND   'OE'                                = wdd.source_code (+)
AND   wdd.delivery_detail_id              = wsn.delivery_detail_id (+)
AND   wdd.delivery_detail_id              = wdda.delivery_detail_id(+)
AND   wdda.delivery_id                    = wd.delivery_id(+)
-- Join to get any order contexts using ATTRIBUTE10 for reseller
AND   ottt_header.name                    = fdfcuv.descriptive_flex_context_code (+) 
AND   'OE_HEADER_ATTRIBUTES'              = fdfcuv.descriptive_flexfield_name (+)
AND   'ATTRIBUTE10'                       = fdfcuv.application_column_name (+)
AND   fdfcuv.flex_value_set_id            = ffvs.flex_value_set_id (+)
AND   'XXCRM_RESELLER_RESOURCE_NAME'      = ffvs.flex_value_set_name (+)
--AND   ooh.attribute10                     IS NOT NULL
-- Join to exclude certain items
AND   msib.item_type                      = flvv.lookup_code
AND   flvv.lookup_type                    = 'ITEM_TYPE'
AND   flvv.enabled_flag                   = 'Y'
AND   NOT EXISTS                         (SELECT null -- item exclusions 
                                          FROM fnd_lookup_values_vl   flvv_item_type_excl
                                          WHERE flvv_item_type_excl.lookup_type  = 'XXCN_SYS_ITEM_EXCLUSION'
                                          AND   flvv_item_type_excl.enabled_flag = 'Y'
                                          AND   flvv_item_type_excl.description  = flvv.meaning)
-- Get ship to info
AND   ooh.ship_to_org_id                  = hcsua_ship.site_use_id (+)          
AND   hcsua_ship.cust_acct_site_id        = hcasa_ship.cust_acct_site_id(+)
AND   hcasa_ship.party_site_id            = hps_ship.party_site_id (+)
AND   hps_ship.location_id                = hl_ship.location_id (+)
AND   hcasa_ship.cust_account_id          = hca_ship.cust_account_id (+)
AND   hca_ship.party_id                   = hp_ship.party_id (+)
-- Get bill to info
AND   ooh.invoice_to_org_id               = hcsua_bill.site_use_id (+)          
AND   hcsua_bill.cust_acct_site_id        = hcasa_bill.cust_acct_site_id(+)
AND   hcasa_bill.party_site_id            = hps_bill.party_site_id (+)
AND   hps_bill.location_id                = hl_bill.location_id (+)
-- Get sold to info
AND   ooh.sold_to_org_id                  = hca.cust_account_id 
AND   hca.party_id                        = hp.party_id 
/

SHOW ERRORS