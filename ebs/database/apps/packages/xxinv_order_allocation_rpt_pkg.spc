create or replace PACKAGE xxinv_order_allocation_rpt_pkg AS
-- ---------------------------------------------------------------------------------
-- Name:       XXINV_ORDER_ALLOCATION_RPT_PKG.spc
-- Created By: MMAZANET
-- Revision:   1.0
-- ---------------------------------------------------------------------------------
-- Purpose: Called from the XXINV_ORDER_ALLOCATIONS_MH and XXINV_ORDER_ALLOCATIONS_PP
--          concurrent program.  This program then calls the XXINV_ORDER_ALLOCATIONS_XML
--          XML Publisher concurrent request.  This allows us to have two different
--          concurrent programs call the same XML report, rather than having one where
--          the users have to remember how to set all the parameters for their needs.
--          In addition, we set the output type of one report to EXCEL and one to RTF.
-- ---------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  04/21/2014  MMAZANET    Initial Creation for CHG0031927
-- 2.0  02/20/2015  Gubendran K Added new function - get_intransit_receipt_qty to get intransit receipt quantity for CHG0033329
-- ---------------------------------------------------------------------------------

   P_SHIP_FROM_ORG_ID               NUMBER;
   P_AVAILABLE_ORG_ID               NUMBER;
   P_INCLUDE_HOLDS                  VARCHAR2(1);
   P_TOTAL_EXCEEDS_ON_HAND          VARCHAR2(1);
   P_ON_HAND_EXCEEDS_AVAILABLE      VARCHAR2(1);
   p_item_id                        NUMBER;
   p_to_org                         NUMBER;

   -- ---------------------------------------------------------------------------------
   -- This procedure is called from either the
   -- or the .  The program then calls
   -- the .  Because this report is for two separate audiences, I've created two concurrent
   -- programs, which call the same XML Publisher report with different params on and off
   -- ---------------------------------------------------------------------------------
   PROCEDURE submit_xxinv_ord_qty_rpt(
      x_errbuff                     OUT NUMBER
   ,  x_retcode                     OUT VARCHAR2
   ,  p_ship_from_org_id            IN NUMBER
   ,  p_available_org_id            IN NUMBER
   ,  p_include_holds               IN VARCHAR2 DEFAULT NULL
   ,  p_total_exceeds_on_hand       IN VARCHAR2 DEFAULT NULL
   ,  p_on_hand_exceeds_available   IN VARCHAR2 DEFAULT NULL
   ,  p_template_code               IN VARCHAR2 DEFAULT 'XXINV_ORDER_ALLOCATIONS_XML'
   ,  p_output_type                 IN VARCHAR2 DEFAULT 'EXCEL'
   );
   
  
-- ---------------------------------------------------------------------------------
-- Ver  Date        Name          Description
-- 1.0  02/20/2015  Gubendran K   This Function returns Intransit receipt quantity for calculating Net Needed Quantity - CHG0033329
-- ---------------------------------------------------------------------------------
   
FUNCTION get_intransit_receipt_qty(p_item_id IN NUMBER, p_to_org IN NUMBER) 
RETURN NUMBER;


END xxinv_order_allocation_rpt_pkg;
/