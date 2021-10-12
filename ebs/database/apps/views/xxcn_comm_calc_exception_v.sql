CREATE OR REPLACE VIEW xxcn_comm_calc_exception_v
-- ---------------------------------------------------------------------------------
-- Name:       xxcn_comm_calc_exception_v
-- Created By: MMAZANET
-- Revision:   1.0
-- ---------------------------------------------------------------------------------
-- Purpose: Shows exceptions for Custom Commissions Calculation application, which 
--          Could cause issues when running the commissions application.
-- ---------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  06/10/2014  MMAZANET    Initial Creation for CHG0031576.
-- ---------------------------------------------------------------------------------
AS
-- Detect product rollups defined with multiple commission percentages, as we
-- only want one per element
SELECT 
   'MULTI ITEM COMM'                error_type
,  eligible_products||' on plan element '||plan_element_name
                                    error_msg
,  TO_NUMBER(NULL)                  reseller_order_rel_id
,  NULL                             order_number          
,  NULL                             serial_number
,  NULL                             ship_to_account_number
,  NULL                             reseller_name
FROM 
  (SELECT DISTINCT 
      plan_element_name
   ,  eligible_products
   ,  business_line
   ,  product
   ,  family
   FROM xxcn_commissions_v
   WHERE commission_ct > 1
   ORDER BY eligible_products
   ) 
UNION ALL 
-- Detects inactive Ship Tos on the custom system order table
SELECT 
   'INACTIVE SHIP TO'                  error_type
,  'Site Number: '||hps.party_site_number||' for Customer Account Number: '||hca.account_number
                                       error_msg
,  xrorv.reseller_order_rel_id         reseller_order_rel_id
,  xrorv.order_number                  order_number                                     
,  xrorv.serial_number                 serial_number
,  xrorv.ship_to_account_number        ship_to_account_number
,  xrorv.agent_rep                     reseller_name
FROM
   xxoe_reseller_order_rel_v        xrorv
,  hz_cust_site_uses_all            hcsua
,  hz_cust_acct_sites_all           hcasa
,  hz_party_sites                   hps
,  hz_locations                     hl
,  hz_cust_accounts_all             hca
,  hz_parties                       hp
WHERE xrorv.ship_to_site_use_id  = hcsua.site_use_id
AND   hcsua.site_use_code           = 'SHIP_TO'
AND   hcsua.status                  = 'I'
AND   hcsua.cust_acct_site_id       = hcasa.cust_acct_site_id
AND   hcasa.party_site_id           = hps.party_site_id
AND   hps.location_id               = hl.location_id
AND   hcasa.cust_account_id         = hca.cust_account_id 
AND   hca.party_id                  = hp.party_id
UNION ALL
-- Detects a change of reseller on an order vs what is on the
-- custom system order table
SELECT 
   'RESELLER CHANGE'                   error_type
,  'Order Reseller Changed to "'||jrre.source_name||'"'
                                       error_msg
,  xrorv.reseller_order_rel_id
,  xrorv.order_number
,  xrorv.serial_number
,  xrorv.ship_to_account_number
,  xrorv.agent_rep
FROM 
   xxoe_reseller_order_rel_v        xrorv
,  oe_order_headers_all             ooh
,  jtf_rs_resource_extns            jrre 
WHERE xrorv.order_id             = ooh.header_id
AND   TO_CHAR(xrorv.reseller_id) <> ooh.attribute10
AND   ooh.attribute10            = jrre.resource_id 
AND   'SUPPLIER CONTACT'         = jrre.category
/

SHOW ERRORS