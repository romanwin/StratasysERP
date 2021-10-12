CREATE OR REPLACE VIEW xxcs_ib_customers_v AS
SELECT
--------------------------------------------------------------------
--  name:            XXCS_IB_CUSTOMERS_V
--  create by:       Yoram Zamir
--  Revision:        1.3
--  creation date:   13/04/2010
--------------------------------------------------------------------
--  purpose :        For Disco Reports
--------------------------------------------------------------------
--  ver  date        name             desc
--  1.0  13/04/2010  Yoram Zamir      initial build
--  1.1  09/06/2010  Vitaly           Security by OU was added
--  1.2  15/05/2011  Roman V          Added End_Customers from system
--  1.3  17/01/2012  Roman V          Added creation_date
--------------------------------------------------------------------
       cust.org_id,
       cust.party_id,
       cust.ACOOUNT_ID,
       cust.cust_acct_site_id,
       cust.party_site_id,
       cust.location_id,
       cust.site_use_id,
       cust.site_use_code,
       cust.location,
       cust.party_name,
       cust.party_number,
       cust.region,
       cust.party_site_name,
       cust.country,
       cust.country_desc,
       cust.county,
       cust.state,
       cust.province,
       cust.address1,
       cust.address2,
       cust.address3,
       cust.address4,
       cust.city,
       cust.postal_code,
       cust.operating_unit_party,
       cust.sales_channel_code,
       cust.creation_date
FROM   XXCS_CUSTOMER_ADDRESSES_V cust
WHERE  (EXISTS (SELECT 1
                 FROM  csi_item_instances ibcust
                 WHERE ibcust.owner_party_id = cust.PARTY_ID) OR
       EXISTS (SELECT 1
                 FROM CSI_ITEM_INSTANCES    CII,
                      CSI_INSTANCE_STATUSES CIS,
                      CSI_SYSTEMS_B         CSB
                WHERE CII.INSTANCE_STATUS_ID = CIS.INSTANCE_STATUS_ID
                  AND CIS.TERMINATED_FLAG = 'N'
                  AND CII.SYSTEM_ID = CSB.SYSTEM_ID
                  AND CSB.ATTRIBUTE2 = cust.PARTY_ID))
AND    XXCS_UTILS_PKG.CHECK_SECURITY_BY_OPER_UNIT(cust.org_id,cust.party_id)='Y';
