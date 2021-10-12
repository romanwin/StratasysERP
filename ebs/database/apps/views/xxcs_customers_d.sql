CREATE OR REPLACE VIEW XXCS_CUSTOMERS_D AS
SELECT
--------------------------------------------------------------------
--  name:            XXCS_CUSTOMERS_D
--  create by:       Vitaly.K
--  Revision:        1.2
--  creation date:   01/09/2009
--------------------------------------------------------------------
--  purpose :        For Disco Reports
--------------------------------------------------------------------
--  ver  date        name             desc
--  1.0  01/09/2009  Vitaly           initial build
--  1.1  14/12/2009  Vitaly           table fnd_territories_tl was added (in "account"-level select
--                                    territory_short_name was added to "Country_Name" field instead of NULL (in "account"-level select)
--                                    County,Province,ADDRESS1,ADDRESS2,ADDRESS3,ADDRESS4,CITY,STATE,postal_code(ZIP),COUNTRY from hz_parties in use in "account"-level select INSTEAD OF "NULL"
-- 1.2   13/04/2010  Yoram Zamir      operating_unit was added
--------------------------------------------------------------------
       'site_uses'   customer_level,
       to_char(u.site_use_id) as BI_customer_code,
       u.site_use_id as bi_site_use_id,
       -999 as bi_cust_account_id,
       -999 as bi_party_id,
       -999 BI_PARTY_SITE_ID, --PK
       u.site_use_id,
       p.party_name,
       p.party_type,
       c.cust_account_id,
       c.customer_type,
       c.sales_channel_code,
       c.account_name,
       ps.location_id,
       L.Street,
       L.Street_Number,
       L.County,
       L.Province,
       ter.territory_short_name Country_Name,
       P.PARTY_NUMBER PARTY_NUMBER,
       c.account_number,
       P.PARTY_ID PARTY_ID,
       case
         when u.site_use_code = 'BILL_TO' and u.primary_flag = 'Y' then
          'BILL_TO_PRIMARY'
       END BI_PRIMARY_CODE,
       ---------
       PS.PARTY_SITE_ID, --PK
       L.DESCRIPTION lOCATION_DESC,
       PS.PARTY_SITE_NAME          PARTY_SITE_NAME,
       L.ADDRESS1                  ADDRESS1,
       L.ADDRESS2                  ADDRESS2,
       L.ADDRESS3                  ADDRESS3,
       L.ADDRESS4                  ADDRESS4,
       L.CITY                      CITY,
       L.STATE                     STATE,
       L.POSTAL_CODE               ZIP,
       L.COUNTRY                   COUNTRY,
       PS.START_DATE_ACTIVE        START_DATE_ACTIVE,
       PS.END_DATE_ACTIVE          END_DATE_ACTIVE,
       PS.STATUS                   STATUS,
       PS.IDENTIFYING_ADDRESS_FLAG IDENTIFYING_ADDRESS_FLAG,
       PS.PARTY_SITE_NUMBER PARTY_SITE_NUMBER,
       c.attribute1         Customer_att1,
       c.attribute2         Customer_att2,
       p.attribute1         party_attribute1,--region
       p.attribute3         operating_unit_code,
       ou.name              operating_unit
FROM   hz_cust_site_uses_all  u,
       hz_cust_acct_sites_all s,
       hz_cust_accounts       c,
       hz_parties             p,
       hz_party_sites         ps,
       hz_locations           l,
       fnd_territories_tl     ter,
       hr_operating_units     ou
WHERE  u.cust_acct_site_id = s.cust_acct_site_id
   and s.cust_account_id = c.cust_account_id
   and c.party_id = p.party_id
   and ps.party_site_id = s.party_site_id
   and l.location_id = ps.location_id
   and ter.territory_code = L.country
   and ter.language = userenv('LANG')
   AND p.attribute3 = ou.organization_id (+)
UNION ALL
-- party_site level
SELECT 'party_sites' customer_level,
       'CPS-' ||to_char(ps.party_site_id) as BI_customer_code,
       -999   as bi_site_use_id,
       -999   as bi_cust_account_id,
       -999   as bi_party_id,
       PS.PARTY_SITE_ID BI_PARTY_SITE_ID, --PK
       -999   as site_use_id,
       p.party_name,
       p.party_type,
       c.cust_account_id,
       c.customer_type,
       c.sales_channel_code,
       c.account_name,
       ps.location_id,
       L.Street,
       L.Street_Number,
       L.County,
       L.Province,
       ter.territory_short_name Country_Name,
       P.PARTY_NUMBER PARTY_NUMBER,
       c.account_number,
       P.PARTY_ID PARTY_ID,
       null       BI_PRIMARY_CODE,
       ---------
       PS.PARTY_SITE_ID, --PK
       L.DESCRIPTION lOCATION_DESC,
       PS.PARTY_SITE_NAME          PARTY_SITE_NAME,
       L.ADDRESS1                  ADDRESS1,
       L.ADDRESS2                  ADDRESS2,
       L.ADDRESS3                  ADDRESS3,
       L.ADDRESS4                  ADDRESS4,
       L.CITY                      CITY,
       L.STATE                     STATE,
       L.POSTAL_CODE               ZIP,
       L.COUNTRY                   COUNTRY,
       PS.START_DATE_ACTIVE        START_DATE_ACTIVE,
       PS.END_DATE_ACTIVE          END_DATE_ACTIVE,
       PS.STATUS                   STATUS,
       PS.IDENTIFYING_ADDRESS_FLAG IDENTIFYING_ADDRESS_FLAG,
       PS.PARTY_SITE_NUMBER PARTY_SITE_NUMBER,
       c.attribute1         Customer_att1,
       c.attribute2         Customer_att2,
       p.attribute1         party_attribute1,--region
       p.attribute3         operating_unit_code,
       ou.name              operating_unit
FROM   hz_cust_accounts       c,
       hz_parties             p,
       hz_party_sites         ps,
       hz_locations           l,
       fnd_territories_tl     ter,
       hr_operating_units     ou
WHERE  c.party_id = p.party_id
   and ps.party_id= p.party_id
   and l.location_id = ps.location_id
   and ter.territory_code = L.country
   and ter.language = userenv('LANG')
   AND p.attribute3 = ou.organization_id (+)
UNION ALL
SELECT 'accounts' customer_level,
       'CAI-' || to_char(c.cust_account_id) as BI_customer_code,
       -999 as bi_site_use_id,
       c.cust_account_id as bi_cust_account_id,
       p.party_id  bi_party_id,
       -999 BI_PARTY_SITE_ID, --PK
       null as site_use_id,
       p.party_name,
       p.party_type,
       c.cust_account_id,
       c.customer_type,
       c.sales_channel_code,
       c.account_name,
       null    location_id,
       null    Street,
       null    Street_Number,
       p.County,
       p.Province,
       ter.territory_short_name     Country_Name,
       P.PARTY_NUMBER PARTY_NUMBER,
       c.account_number,
       P.PARTY_ID PARTY_ID,
       'CUST_ACCOUNT_ID' as BI_PRIMARY_CODE,
       null, --PK  ---PARTY_SITE_ID
       null lOCATION_DESC,
       null PARTY_SITE_NAME,
       p.ADDRESS1,
       p.ADDRESS2,
       p.ADDRESS3,
       p.ADDRESS4,
       p.CITY,
       p.STATE,
       p.postal_code   ZIP,
       p.COUNTRY,
       null START_DATE_ACTIVE,
       null END_DATE_ACTIVE,
       null STATUS,
       null IDENTIFYING_ADDRESS_FLAG,
       null PARTY_SITE_NUMBER,
       c.attribute1         Customer_att1,
       c.attribute2         Customer_att2,
       null                 party_attribute1,--region
       p.attribute3         operating_unit_code,
       ou.name              operating_unit
FROM   hz_cust_accounts       c,
       hz_parties             p,
       fnd_territories_tl     ter,
       hr_operating_units     ou
WHERE  c.party_id = p.party_id
 and   ter.territory_code = p.country
 and   ter.language = userenv('LANG')
 AND   p.attribute3 = ou.organization_id (+);

