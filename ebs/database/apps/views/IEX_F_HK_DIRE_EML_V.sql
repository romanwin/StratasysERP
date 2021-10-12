DROP VIEW APPS.XXIEX_F_HK_DIRE_EML_V;

CREATE OR REPLACE VIEW IEX_F_HK_DIRE_EML_V AS
SELECT
---------------------------------------------------------------------------------------
-- Ver     When        Who       Description
-- ------  ----------  --------  ------------------------------------------------------
-- 1.0     15-10-2019  Ofer S.   INC0172066 - Advance Collections APJ Implementation
---------------------------------------------------------------------------------------
DISTINCT ide.CUSTOMER_SITE_USE_ID
       FROM IEX_DELINQUENCIES ide,
            hz_cust_accounts_all hca,
            hz_party_sites hps,
            AR_PAYMENT_SCHEDULES_V AR
       WHERE ide.STATUS <> 'CURRENT'
       AND ide.cust_account_id = hca.cust_account_id
and hca.party_id = hps.party_id
and IDE.PAYMENT_SCHEDULE_ID = AR.PAYMENT_SCHEDULE_ID
       AND hps.attribute20 = 'DIRECT ENG'
AND AR.DAYS_PAST_DUE  not in (0,1,2,3,4,5,6,7)
       AND ide.CUSTOMER_SITE_USE_ID  IN (
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
                      )
;
