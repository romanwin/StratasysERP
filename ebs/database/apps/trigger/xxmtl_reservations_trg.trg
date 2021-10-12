create or replace trigger XXMTL_RESERVATIONS_TRG

---------------------------------------------------------------------------
-- Trigger   :        XXMTL_RESERVATIONS_TRG
-- Created by:        YUVAL TAL
-- creation date:     3.8.10
-- Revision:          1.0
---------------------------------------------------------------------------
-- Perpose:
---------------------------------------------------------------------------
--  ver    date        name            desc
--  1.0   3.8.10       yuval tal       Add the internal source to the reservation screen
--  1.1   18.08.2013   Vitaly          CR 870 std cost - change hard-coded organization and fix mulitple intercompany transaction flows
---------------------------------------------------------------------------
  before insert  on  MTL_RESERVATIONS
  FOR EACH ROW
  
when (new.DEMAND_SOURCE_TYPE_ID=8)
DECLARE
  l_tmp NUMBER;
BEGIN
    SELECT 1
    INTO l_tmp
    FROM oe_order_lines_all            oola,
         oe_order_headers_all          ooha,
         hz_cust_accounts              hca, --Customer
         hz_cust_site_uses_all         hcsua, -- holds the site uses  --OM
         mtl_intercompany_parameters_v mip, -- intercompany releations 
         mtl_transaction_flow_headers_v mtfh -- intercompany transaction flows
   WHERE :new.organization_id = 736 /*ITA*/ ---90 /*WPI*/
     AND oola.header_id = ooha.header_id
     AND :new.demand_source_line_id = oola.line_id
     AND ooha.order_source_id = 10 -- Internal Source
     AND oola.sold_to_org_id = hca.cust_account_id
     AND oola.ship_to_org_id = hcsua.site_use_id -- to connect to the order ship to
     AND mip.customer_site_id = oola.invoice_to_org_id
     AND mip.customer_id = oola.sold_to_org_id
     AND mtfh.START_ORG_ID=mip.SHIP_ORGANIZATION_ID
     AND mtfh.END_ORG_ID= mip.SELL_ORGANIZATION_ID
     and nvl(mtfh.END_DATE,sysdate+1)>sysdate;

  :new.attribute1 := 'Internal Region';

EXCEPTION
  WHEN no_data_found THEN
  
    :new.attribute1 := 'Internal dept';
  
END xxmtl_reservations_trg;
/
