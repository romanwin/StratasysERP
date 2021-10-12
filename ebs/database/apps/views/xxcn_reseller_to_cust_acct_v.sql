CREATE OR REPLACE VIEW xxcn_reseller_to_cust_acct_v AS
-- ---------------------------------------------------------------------------------
-- Name:       xxcn_reseller_to_cust_acct_v
-- Created By: MMAZANET
-- Revision:   1.0
-- ---------------------------------------------------------------------------------
-- Purpose: Used to link custom xxcn tables, to the associated resource_id and to the
--          associated customer accounts for reseller to customer relationship.
-- ---------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  04/14/2014  MMAZANET    Initial Creation for CHG0031576.
-- ---------------------------------------------------------------------------------
SELECT
   hca.cust_account_id                 customer_id
,  hca.account_number                  customer_number
,  hp.party_name                       customer_name
,  pv.vendor_id                        vendor_id
,  pv.vendor_name                      vendor_name
,  pv.segment1                         vendor_number
,  jrre.resource_id                    reseller_id
,  jrre.source_name                    reseller_name
FROM
   xxcn_reseller                 xr
,  xxcn_reseller_to_customer     xrc
,  jtf_rs_salesreps              jrs
,  jtf_rs_resource_extns         jrre
,  ap_supplier_sites_all         assa
,  po_vendors                    pv
,  hz_cust_accounts              hca
,  hz_parties                    hp
WHERE jrs.resource_id               = jrre.resource_id
AND   jrre.category                 = 'SUPPLIER_CONTACT'
AND   jrre.address_id               = assa.vendor_site_id
AND   TRUNC(SYSDATE)                <= NVL(TRUNC(assa.inactive_date),'31-DEC-4712')
AND   assa.vendor_id                = pv.vendor_id
AND   pv.party_id                   = xr.reseller_id
AND   xr.reseller_id                = xrc.reseller_id
AND   xrc.customer_party_id         = hp.party_id
AND   SYSDATE                       BETWEEN NVL(jrre.start_date_active,TO_DATE('01011900','DDMMYYYY'))
                                       AND NVL(jrre.end_date_active,TO_DATE('31124712','DDMMYYYY'))
AND   hp.party_id                   = hca.party_id 
/

SHOW ERRORS