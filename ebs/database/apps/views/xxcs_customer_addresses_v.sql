CREATE OR REPLACE VIEW xxcs_customer_addresses_v AS
SELECT
--------------------------------------------------------------------
--  name:            XXCS_CUSTOMER_ADDRESSES_V
--  create by:       Vitaly.K
--  Revision:        1.4
--  creation date:   01/09/2009
--------------------------------------------------------------------
--  purpose :      Disco Reports
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  01/09/2009  Vitaly            initial build
--  1.1  09/12/2009  Vitaly            party_number and country_desc are added
--  1.2  07/03/2010  Vitaly            Region = NULL
--  1.3  08/03/2010  Vitaly            Operating_Unit_Party and Sales_Channel were added
--  1.4  17/01/2012  Roman             Added hp.creation_date
--------------------------------------------------------------------
       hcsu.org_id,
       hps.party_id,
       hcas.cust_account_id      ACOOUNT_ID,
       hcsu.cust_acct_site_id,
       hcas.party_site_id,
       hps.location_id,
       hcsu.site_use_id,
       hcsu.site_use_code,
       hcsu.location,
       hp.party_name,
       hp.party_number,
       ''            region,
       hps.party_site_name,
       hl.country,
       ter.territory_short_name   country_desc,
       hl.county,
       hl.state,
       hl.province,
       hl.address1,
       hl.address2,
       hl.address3,
       hl.address4,
       hl.city,
       hl.postal_code,
       oup.name                operating_unit_party,
       SALES_CHANNEL_TAB.sales_channel_code,
       hp.creation_date
FROM   hz_cust_site_uses_all      hcsu,
       hz_cust_acct_sites_all     hcas,
       hz_party_sites             hps,
       hz_parties                 hp,
       hr_operating_units         oup,
      (SELECT ca.party_id,
                     MAX(ca.sales_channel_code)   sales_channel_code
              FROM   hz_cust_accounts   ca
              WHERE  ca.sales_channel_code IS NOT NULL
              GROUP BY ca.party_id)                       SALES_CHANNEL_TAB,
       hz_locations               hl,
       fnd_territories_tl         ter
WHERE  hcsu.cust_acct_site_id = hcas.cust_acct_site_id
AND    hcas.party_site_id =     hps.party_site_id
AND    hps.location_id =        hl.location_id
AND    hps.party_id=            hp.party_id
AND    hp.party_type='ORGANIZATION'
AND    hp.status='A'
AND    ter.language=userenv('LANG')
AND    hl.country=ter.territory_code(+)
AND    to_number(hp.attribute3)=oup.organization_id(+)
AND    hp.party_id=SALES_CHANNEL_TAB.party_id(+);
