create or replace package body xxmsc_utils_pkg IS

  --------------------------------------------------------------------
  --  customization code:
  --  name:               msc_vs_current_supply
  --  create by:
  --  $Revision:          1.0
  --  creation date:
  --  Description:
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   18.08.2013    Vitaly          CR 870 std cost - change hard-coded organization
  --  1.1   28/08/2019  Bellona(TCS)      CHG0046023 - add is_plan_operation_enable.
  --										called from form personalization.
  --                                      (Advanced Supply Chain Plan) 
  --------------------------------------------------------------------
  FUNCTION msc_vs_current_supply(p_organization_id IN NUMBER,
                                 p_plan_id         IN NUMBER,
                                 p_item_name       IN VARCHAR2) RETURN NUMBER IS

    v_mrp_supply_quantity  NUMBER;
    v_po_quantity          NUMBER;
    v_po_rcv_quantity      NUMBER;
    v_requisition_quantity NUMBER;
    stop_processing EXCEPTION;

  BEGIN

    IF p_organization_id IS NULL OR p_plan_id IS NULL OR
       p_item_name IS NULL THEN
      RAISE stop_processing;
    END IF;

    ---get mrp supply quantity----------
    BEGIN
      SELECT nvl(SUM(mscsp.new_order_quantity), 0)
        INTO v_mrp_supply_quantity
        FROM msc_supplies mscsp, msc_system_items mscitm
       WHERE mscitm.organization_id IN
             (736 /*ITA*/, 735 /*IPK*/, 734 /*IRK*/) ----(90 /*WPI*/, 92 /*WRI*/) --p_organization_id ---param
         AND mscsp.plan_id = p_plan_id ---param
         AND mscitm.item_name = p_item_name ---param
         AND mscsp.inventory_item_id = mscitm.inventory_item_id
         AND mscsp.organization_id = mscitm.organization_id
         AND mscsp.plan_id = mscitm.plan_id
         AND mscsp.order_type IN (1, 2)
         AND mscsp.disposition_status_type != 2;
    EXCEPTION
      WHEN OTHERS THEN
        RETURN NULL;
    END;
    -------------------------------------

    -- MINUS

    ---get PO quantity----------
    BEGIN
      SELECT --poh.segment1,msi.segment1 ,pol.item_description,
       nvl(SUM(pod.quantity_ordered - pod.quantity_delivered -
               pod.quantity_cancelled),
           0) qty
        INTO v_po_quantity
        FROM po_headers_all        poh,
             po_lines_all          pol,
             po_line_locations_all pols,
             po_distributions_all  pod,
             mtl_system_items_b    msi
       WHERE msi.organization_id IN (736 /*ITA*/, 735 /*IPK*/, 734 /*IRK*/) ----(90 /*WPI*/, 92 /*WRI*/) --p_organization_id ---param
         AND msi.segment1 = p_item_name ---param
         AND poh.po_header_id = pol.po_header_id
         AND poh.org_id = pol.org_id
         AND pol.po_line_id = pols.po_line_id
         AND pol.org_id = pols.org_id
         AND pols.line_location_id = pod.line_location_id
         AND pod.org_id = pols.org_id
         AND pod.destination_type_code = 'INVENTORY'
         AND (pod.destination_subinventory IS NULL OR
             pod.destination_subinventory IN
             (SELECT subdt.secondary_inventory_name
                 FROM mtl_secondary_inventories subdt
                WHERE subdt.organization_id = pols.ship_to_organization_id
                  AND subdt.secondary_inventory_name =
                      pod.destination_subinventory
                  AND subdt.availability_type = 1))
         AND poh.type_lookup_code = 'STANDARD'
         AND msi.inventory_item_id = pol.item_id
         AND msi.organization_id = pols.ship_to_organization_id
         AND poh.closed_code NOT IN ('CLOSED', 'FINALLY CLOSED')
         AND nvl(poh.cancel_flag, 'N') <> 'Y'
         AND nvl(pol.cancel_flag, 'N') <> 'Y'
         AND nvl(pols.cancel_flag, 'N') <> 'Y' HAVING
       SUM(pod.quantity_ordered - pod.quantity_delivered -
                 pod.quantity_cancelled) > 0;
      ---group by poh.segment1,  msi.segment1 , pol.item_description
    EXCEPTION
      WHEN OTHERS THEN
        RETURN NULL;
    END;
    -------------------------------------

    -- MINUS

    ---get PO RCV quantity Since the MRP run till sysdate----------
    BEGIN

      SELECT SUM(decode(rcvtrx.transaction_type,
                        'RETURN TO RECEIVING',
                        ((-1) * rcvtrx.quantity),
                        rcvtrx.quantity))
        INTO v_po_rcv_quantity
        FROM msc_plans          mscplan,
             rcv_transactions   rcvtrx,
             rcv_shipment_lines rcvshpln,
             mtl_system_items_b msi
       WHERE rcvtrx.transaction_date > nvl(mscplan.plan_run_date, SYSDATE)
         AND rcvtrx.transaction_date < SYSDATE
         AND rcvshpln.shipment_line_id = rcvtrx.shipment_line_id
         AND msi.organization_id = rcvtrx.organization_id
         AND msi.inventory_item_id = rcvshpln.item_id
         AND rcvtrx.source_document_code = 'PO'
         AND mscplan.plan_id = p_plan_id
         AND msi.segment1 = p_item_name
         AND rcvtrx.transaction_type IN ('DELIVER', 'RETURN TO RECEIVING');

    EXCEPTION
      WHEN OTHERS THEN
        RETURN NULL;
    END;

    ------Minus

    ---get Requisition quantity----------
    BEGIN
      SELECT ---prh.segment1 "PR NUM",
      ---msi.segment1 "Item Num",
      ---prl.item_description "Description",
       nvl(SUM(prl.quantity), 0) --- "Qty"
        INTO v_requisition_quantity
        FROM po.po_requisition_headers_all prh,
             po.po_requisition_lines_all prl,
             apps.per_people_f ppf1,
             (SELECT DISTINCT agent_id, agent_name FROM apps.po_agents_v) ppf2,
             po.po_req_distributions_all prd,
             inv.mtl_system_items_b msi,
             po.po_line_locations_all pll,
             po.po_lines_all pl,
             po.po_headers_all ph
       WHERE prl.destination_organization_id IN
             (736 /*ITA*/, 735 /*IPK*/, 734 /*IRK*/) ----(90 /*WPI*/, 92 /*WRI*/) --p_organization_id ---param
         AND msi.segment1 = p_item_name ---param
         AND prh.requisition_header_id = prl.requisition_header_id
         AND prl.requisition_line_id = prd.requisition_line_id
         AND ppf1.person_id = prh.preparer_id
         AND prh.creation_date BETWEEN ppf1.effective_start_date AND
             ppf1.effective_end_date
         AND ppf2.agent_id(+) = msi.buyer_id
         AND msi.inventory_item_id = prl.item_id
         AND msi.organization_id = prl.destination_organization_id
         AND pll.line_location_id(+) = prl.line_location_id
         AND pll.po_header_id = ph.po_header_id(+)
         AND pll.po_line_id = pl.po_line_id(+)
            --AND PRH.AUTHORIZATION_STATUS = 'APPROVED'
         AND pll.line_location_id IS NULL
         AND prl.closed_code IS NULL
         AND prl.destination_type_code = 'INVENTORY'
         AND (prl.destination_subinventory IS NULL OR
             prl.destination_subinventory IN
             (SELECT subdt.secondary_inventory_name
                 FROM mtl_secondary_inventories subdt
                WHERE subdt.organization_id =
                      prl.destination_organization_id
                  AND subdt.secondary_inventory_name =
                      prl.destination_subinventory
                  AND subdt.availability_type = 1))
         AND prh.type_lookup_code = 'PURCHASE'
         AND nvl(prl.cancel_flag, 'N') <> 'Y';
    EXCEPTION
      WHEN OTHERS THEN
        RETURN NULL;
    END;
    -------------------------------------

    IF (v_mrp_supply_quantity - v_po_quantity - v_po_rcv_quantity -
       v_requisition_quantity) < 0 THEN

      RETURN(v_mrp_supply_quantity - v_po_quantity - v_po_rcv_quantity -
             v_requisition_quantity);

    ELSE
      RETURN 0;

    END IF;

  EXCEPTION
    WHEN stop_processing THEN
      RETURN NULL;
    WHEN OTHERS THEN
      RETURN NULL;
  END msc_vs_current_supply;
  ------------------------------------------------------

  FUNCTION msc_excess_po_supply(p_po_header_id IN NUMBER,
                                p_plan_id      IN NUMBER,
                                p_item_name    IN VARCHAR2) RETURN NUMBER IS

    v_msc_excess_po_supp_qty NUMBER;

  BEGIN

    SELECT SUM(msfg.allocated_quantity)
      INTO v_msc_excess_po_supp_qty
      FROM msc_full_pegging msfg,
           msc_supplies     mssup,
           po_headers_all   poh,
           msc_system_items mmsi
     WHERE mssup.transaction_id = msfg.transaction_id
       AND msfg.inventory_item_id = mssup.inventory_item_id
       AND msfg.demand_quantity IS NULL
       AND msfg.demand_id = -1
       AND mssup.order_type = 1
       AND mssup.plan_id = p_plan_id
       AND mmsi.plan_id = mssup.plan_id
       AND mmsi.organization_id = mssup.organization_id
       AND mmsi.inventory_item_id = mssup.inventory_item_id
       AND poh.po_header_id = mssup.disposition_id
       AND poh.po_header_id = p_po_header_id
       AND mmsi.item_name = p_item_name;

    RETURN v_msc_excess_po_supp_qty;

  EXCEPTION

    WHEN OTHERS THEN
      RETURN NULL;

  END msc_excess_po_supply;

  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   28/08/2019  Bellona(TCS)   CHG0046023 - called from form-personalization.
  --                                   (Advanced Supply Chain Plan) 
  --                          Checks whether user and plan fall within a specific set of Valueset 
  --------------------------------------------------------------------
  FUNCTION is_plan_operation_enable(p_user_id in number,
                                    p_plan_name in varchar2) RETURN VARCHAR2 IS
  
  is_user_enabled varchar2(1);
  is_plan_enabled varchar2(1);
  
  BEGIN
                               
     IF p_user_id is not null and p_plan_name is not null THEN


        --check whether user exists in valueset of plan-admins
          BEGIN
             select 'Y' 
              into is_user_enabled 
              from fnd_flex_values ffv,
                   fnd_flex_value_sets ffvs
             where ffvs.FLEX_VALUE_SET_NAME='XX_MSC_OPERATION_PLANS_ADMIN'
               and ffvs.FLEX_VALUE_SET_ID = ffv.FLEX_VALUE_SET_ID
			   and nvl(ffv.enabled_flag,'N') ='Y' 
               and ffv.FLEX_VALUE= p_user_id; 
          EXCEPTION
            WHEN OTHERS THEN
            --user does not exist in list of plan-admins
               is_user_enabled := 'N';             
          END;
               
          
        --check whether plan exists in valueset of plans  
          BEGIN           
                 select 'Y' 
                  into is_plan_enabled 
                  from fnd_flex_values ffv,
                       fnd_flex_value_sets ffvs
                 where ffvs.FLEX_VALUE_SET_NAME='XX_MSC_OPERATION_PLANS'
                   and ffvs.FLEX_VALUE_SET_ID = ffv.FLEX_VALUE_SET_ID
				   and nvl(ffv.enabled_flag,'N') ='Y' 
                   and ffv.FLEX_VALUE= p_plan_name;        
          EXCEPTION
            WHEN OTHERS THEN
            --plan does not exist in list of plans
               is_plan_enabled := 'N';             
          END;
		  -------------------------------------------------------------
           /* If user is in the list, he/she can update all the plans.
		      If user is not in the list - he/she can update only plans 
			  that are not in the list. */
		  -------------------------------------------------------------	
           IF (is_user_enabled ='N' and is_plan_enabled='N')
             or (is_user_enabled ='Y')
           THEN
           --enable the plan: p_plan_name for user id: p_user_id
              RETURN 'Y';
           ELSE
		   --disable the plan: p_plan_name for user id: p_user_id
              RETURN 'N';   
           END IF;   
     ELSE
        RETURN 'N';
     END IF;
     
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'N';                                      
  END is_plan_operation_enable;                                  
END xxmsc_utils_pkg;
/
