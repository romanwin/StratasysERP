create or replace PACKAGE BODY xxinv_order_allocation_rpt_pkg AS
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

   -- ---------------------------------------------------------------------------------
   -- This procedure is called from either the XXINV_ORDER_ALLOCATIONS_PP
   -- or the XXINV_ORDER_ALLOCATIONS_MH.  The program then calls the XXINV_ORDER_ALLOCATIONS_XML.
   -- Because this report is for two separate audiences, I've created two concurrent
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
   )
   IS
      l_request_id   NUMBER;
      l_return       BOOLEAN;
      l_location     VARCHAR2(100);
      e_error        EXCEPTION;
   BEGIN
      IF p_ship_from_org_id IS NULL
         OR p_available_org_id IS NULL THEN
         l_location := 'Error: Ship From and Available Org are both required';
         RAISE e_error;
      END IF;

      -- Set BI Publisher template for request
      l_return := fnd_request.add_layout (
                     template_appl_name   => 'XXOBJT',
                     template_code        => p_template_code,
                     template_language    => 'en',
                     template_territory   => 'US',
                     output_format        => p_output_type
                  );
      IF NOT l_return THEN
         l_location := 'Unexpected Error adding layout';
         RAISE e_error;
      END IF;

      l_request_id := fnd_request.submit_request (
                        application          => 'XXOBJT'
                     ,  program              => 'XXINV_ORDER_ALLOCATIONS_XML'
                     ,  argument1            => p_ship_from_org_id
                     ,  argument2            => p_available_org_id
                     ,  argument3            => p_include_holds
                     ,  argument4            => p_total_exceeds_on_hand
                     ,  argument5            => p_on_hand_exceeds_available
                     );

      IF NVL(l_request_id,-9) = -9 THEN
         l_location := 'Unexpected Error submitting request';
         RAISE e_error;
      ELSE
         fnd_file.put_line(fnd_file.output,'Please view this request '||l_request_id||' for report output.');
      END IF;

      x_retcode := 0;
   EXCEPTION
      WHEN e_error THEN
         fnd_file.put_line(fnd_file.output,l_location);
         x_retcode := 2;
      WHEN OTHERS THEN
         fnd_file.put_line(fnd_file.output,'Error occurred running report '||SQLERRM);
         x_retcode := 2;
   END submit_xxinv_ord_qty_rpt;
   
  /*-------------------------------------------------------------------------------------------------
  $Revision:   1.0  $
  Function Name:   get_intransit_receipt_qty
  Author's Name:   Gubendran K
  Date Written:    20-JAN-2015
  Purpose:         This Function returns Intransit receipt quantity for calculating Net Needed Quantity 
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  20-FEB-2015        1.0                  Gubendran K     Initial Version -- CHG0033329
  ---------------------------------------------------------------------------------------------------*/
   
   FUNCTION get_intransit_receipt_qty(p_item_id IN NUMBER, p_to_org IN NUMBER) RETURN NUMBER IS
   l_ship_qty NUMBER;
   BEGIN
     BEGIN
       SELECT SUM(quantity)
         INTO l_ship_qty
         FROM mtl_supply
        WHERE item_id=p_item_id
          AND destination_type_code='INVENTORY'
          AND supply_type_code='SHIPMENT'
          AND to_organization_id=p_to_org;
     EXCEPTION
     WHEN OTHERS THEN
       l_ship_qty:= NULL;
     END; 
     RETURN(l_ship_qty);
   END get_intransit_receipt_qty;   

END xxinv_order_allocation_rpt_pkg;
/