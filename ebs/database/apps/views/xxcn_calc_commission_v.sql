CREATE OR REPLACE VIEW xxcn_calc_commission_v
-- ---------------------------------------------------------------------------------
-- Name:       xxcn_calc_commission_v
-- Created By: MMAZANET
-- Revision:   1.0
-- ---------------------------------------------------------------------------------
-- Purpose: View used by commissions module for Consumables commission calculation.
-- ---------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  06/10/2014  MMAZANET    Initial Creation for CHG0031576.
-- ---------------------------------------------------------------------------------
AS
SELECT
   xcc.customer_trx_line_id
,  cs.salesrep_id
,  cs.employee_number
,  xcc.customer_trx_line_amount
FROM 
   xxcn_calc_commission    xcc
,  cn_salesreps            cs
WHERE xcc.reseller_id         = cs.resource_id
AND   cs.name                 <> 'No Sales Credit'
AND   xcc.processing_status   = 'PENDING'
/

SHOW ERRORS