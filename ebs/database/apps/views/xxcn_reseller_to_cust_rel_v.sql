CREATE OR REPLACE VIEW xxcn_reseller_to_cust_rel_v
-- ---------------------------------------------------------------------------------
-- Name:       xxcn_reseller_to_cust_rel_v
-- Created By: MMAZANET
-- Revision:   1.0
-- ---------------------------------------------------------------------------------
-- Purpose: View used by the XXOERESELLORDRREL form to show reseller to customer 
--          relationships.
-- ---------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  04/14/2014  MMAZANET    Initial Creation for CHG0032042.
-- 1.1  06/10/2014  MMAZANET    CHG0031576.  Added exclude_ar_from_comm_calc_flag
-- ---------------------------------------------------------------------------------
AS
SELECT    
   xr.reseller_id             reseller_id
,  NVL(xr.exclude_ar_from_comm_calc_flag,'N') 
                              exclude_ar_from_comm_calc_flag
,  pv.vendor_name             reseller_name
,  pv.segment1                reseller_number
,  xr.email                   reseller_email
,  xr.start_date              reseller_start_date
,  xr.end_date                reseller_end_date
,  xr.creation_date           reseller_creation_date
,  xr.created_by              reseller_created_by
,  fu_r_create.user_name      reseller_created_by_name
,  xr.last_update_date        reseller_last_update_date
,  xr.last_updated_by         reseller_last_updated_by
,  fu_r_update.user_name      reseller_last_updated_by_name   
,  xr.last_update_login       reseller_last_update_login
,  xrc.customer_party_id      customer_party_id
,  hp.party_name              customer_party_name
,  hp.party_number            customer_registry_id
,  xrc.start_date             customer_rel_start_date
,  xrc.end_date               customer_rel_end_date
,  xrc.creation_date          customer_rel_creation_date
,  xrc.created_by             customer_rel_created_by
,  fu_rc_create.user_name     customer_rel_created_by_name
,  xrc.last_update_date       customer_rel_update_date
,  xrc.last_updated_by        customer_rel_updated_by
,  fu_rc_update.user_name     customer_rel_updated_by_name   
,  xrc.last_update_login      customer_rel_last_update_login
,  ROW_NUMBER() OVER (PARTITION BY xr.reseller_id ORDER BY xr.creation_date)
                              rn
FROM 
   xxcn_reseller              xr
,  xxcn_reseller_to_customer  xrc
,  po_vendors                 pv
,  hz_parties                 hp
,  fnd_user                   fu_r_create
,  fnd_user                   fu_r_update
,  fnd_user                   fu_rc_create
,  fnd_user                   fu_rc_update
WHERE xr.reseller_id          = pv.party_id
AND   xr.created_by           = fu_r_create.user_id
AND   xr.last_updated_by      = fu_r_update.user_id
AND   xr.reseller_id          = xrc.reseller_id (+)
AND   xrc.customer_party_id   = hp.party_id (+)
AND   xrc.created_by          = fu_rc_create.user_id (+)
AND   xrc.last_updated_by     = fu_rc_update.user_id (+)
/

SHOW ERRORS