DROP VIEW APPS.XXIEX_F_HK_RESL_V;

CREATE OR REPLACE VIEW IEX_F_HK_RESL_V AS
SELECT 
---------------------------------------------------------------------
-- Ver    When        Who       Description
-- -----  ----------  --------  -------------------------------------
-- 1.1    15-10-2019  Roman W.  INC0172066
---------------------------------------------------------------------
DISTINCT CUSTOMER_SITE_USE_ID
       FROM IEX_DELINQUENCIES ide,
            hz_cust_accounts_all hca,
            hz_party_sites hps
       WHERE ide.STATUS <> 'CURRENT'
       AND ide.cust_account_id = hca.cust_account_id
and hca.party_id = hps.party_id
       AND hps.attribute20 = 'RESELLER'
       /*AND ide.CUSTOMER_SITE_USE_ID NOT IN (*/
	   AND ide.CUSTOMER_SITE_USE_ID IN (
                   SELECT  hcsua.site_use_id
                     FROM hz_cust_account_roles hcar,
                          ar_contacts_v acv,
                          hz_role_responsibility hrr,
                          hz_contact_points hcp,
                          hz_cust_site_uses_all hcsua
                    WHERE hcar.cust_account_role_id = acv.contact_id
                      AND hrr.cust_account_role_id = acv.contact_id
                      AND hcar.cust_acct_site_id = hcsua.cust_acct_site_id
                      AND hrr.responsibility_type = 'DUN'
                      AND hcp.status = 'A'
                      AND hcp.owner_table_id = hcar.party_id
                      AND hcp.contact_point_type = 'EMAIL'
                      AND hcar.cust_acct_site_id  IS NOT NULL
                      );
