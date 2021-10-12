CREATE OR REPLACE PACKAGE BODY xxcs_utils_pkg IS
  -----------------------------------------------------------------------
  --  customization code: GENERAL
  --  name:               XXCS_UTILS_PKG
  --  create by:          XXX
  --  $Revision:          1.0
  --  creation date:      31/08/09
  --  Purpose :           Service generic package
  -----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   31/08/09      XXX             initial build
  --  1.1   07/03/2010    Dalit A. Raviv  add function - get_resource_name_by_id
  --                                      for commission report
  --  1.2   07/06/2010    Vitaly          add function - check_security_by_oper_unit
  --                                      for security at Service disco reports
  --  1.3   10/08/2011    Dalit A. Raviv  new function get_SR_is_repeated
  --  1.4   09/02/2012    Dalit A. Raviv  Procedure check_security_by_oper_unit
  --                                      add ability to OU HK to see OU CN reports
  --  1.5   14/06/2012    Adi Safin       add function: get_SUB_for_order_line
  --  1.6   30/07/2013    Dalit Raviv     add new function get_SR_is_repeated_new
  --  1.7   01/12/2013    Yuval Tal       get_region_by_ou : CR1163-Service - Customization support new operating unit 737
  --  1.8   22/02/2017    Adi Safin       CHG0040155 - add new function get_contract_entitlement
  --  1.9   19/06/2017    Lingaraj(TCS)   CHG0040890 - updated the upgrade advisor to support selling an upgrade in an initial sale
  --                                      Adding a New Procedure which will Update (Item + Serial Number) Instance id to Attribute1
  --                                      Upgrade Sales Order line.
  --                                      Procedure Name : Update_upg_instance_id
  --  2.0  13/08/2017     Adi Safin       CHG0040196 - modify get_contract_entitlement/update_upg_instance_id :Support features lookup (like Voxel) and update salesforce interface in update_upg_instance_id procedure
  --  2.1  14-Feb-2019    Diptasurjya     INC0147595 - modify get_contract_entitlement for performance issue
  --  2.2  04.03.19       Lingaraj        INC0148774 - remove all call s to  xxobjt_oa2sf_interface_pkg.insert_into_interface
  --  2.3  01.04.19       yuval tal       INC0152534 - get_contract_entitlement  change cursor source to new copystorm
  --  2.4  22-May-2019    Adi Safin       CHG0045785 - change in procedure update_upg_instance_id.Add adittional query to cursor in order to update printer lines with poulation that the PN associate to Printer line (like warranty)
  --  2.5  15-Sep-2019    Adi Safin       CHG0046812 - modify update_upg_instance_id
  --  2.6  02.02.2020     Yuval Tal       CHG0047309 - update update_upg_instance_id
  --  2.7  5/11/2021      Yuval tal        CHG0049822 - modify update_upg_instance_id
  --------------------------------------------------------------------

  -----------------------------------------------------------------------
  -- Function and procedure implementations
  FUNCTION get_last_assignee(p_incident_id NUMBER,
		     p_source_name VARCHAR2) RETURN VARCHAR2 IS
    --v_assignment_status VARCHAR2(10);
    v_assignee  VARCHAR2(100);
    v_task_id   NUMBER;
    v_status_id NUMBER;
    v_ass_flag  VARCHAR2(1);
  
  BEGIN
  
    BEGIN
      SELECT MAX(tt.task_id)
      INTO   v_task_id
      FROM   jtf_tasks_b         tt,
	 jtf_task_statuses_b stt
      WHERE  tt.source_object_type_code = 'SR'
      AND    tt.task_status_id = stt.task_status_id
      AND    nvl(stt.closed_flag, 'N') = 'N'
	--and  stt.assignment_status_flag = 'Y'
      AND    tt.source_object_id = p_incident_id; --ciab.incident_id
    
      SELECT tt2.task_status_id
      INTO   v_status_id
      FROM   jtf_tasks_b tt2
      WHERE  tt2.task_id = v_task_id;
    
      SELECT stt2.assignment_status_flag
      INTO   v_ass_flag
      FROM   jtf_task_statuses_b stt2
      WHERE  stt2.task_status_id = v_status_id;
    
    EXCEPTION
      WHEN no_data_found THEN
        v_task_id := NULL;
    END;
  
    IF v_task_id IS NOT NULL AND v_ass_flag = 'Y' THEN
      BEGIN
        SELECT decode(jtaa.assignee_role,
	          'ASSIGNEE',
	          jrret.resource_name,
	          p_source_name) resource_name
        INTO   v_assignee
        FROM   cs_incidents_all_b       ciab,
	   jtf_tasks_b              jtb,
	   jtf_task_all_assignments jtaa,
	   jtf_rs_resource_extns    jrre,
	   jtf_rs_resource_extns_tl jrret
        WHERE  jtb.source_object_type_code = 'SR'
        AND    jtb.source_object_id = ciab.incident_id
        AND    jtb.task_id = v_task_id
        AND    jtaa.task_id = jtb.task_id
        AND    jtaa.resource_type_code = 'RS_EMPLOYEE'
        AND    jtaa.task_assignment_id IN
	   (SELECT MAX(jj.task_assignment_id)
	     FROM   jtf_task_all_assignments jj
	     WHERE  jj.task_id = jtb.task_id
	     AND    jj.resource_type_code = 'RS_EMPLOYEE')
        AND    jrre.resource_id = jtaa.resource_id
        AND    jrret.resource_id = jrre.resource_id
        AND    jrret.language = 'US'
        AND    ciab.incident_id = p_incident_id;
      
        RETURN(v_assignee);
      
      EXCEPTION
        WHEN no_data_found THEN
          v_assignee := p_source_name;
          RETURN v_assignee;
      END;
    ELSIF v_task_id IS NOT NULL AND v_ass_flag = 'N' THEN
      RETURN NULL;
    ELSE
      v_assignee := p_source_name;
      RETURN v_assignee;
    END IF;
  
  END get_last_assignee;

  FUNCTION get_sr_related_orders_message(p_incident_id NUMBER)
    RETURN VARCHAR2 IS
  
    CURSOR get_sr_related_orders IS
      SELECT 1,
	 charges_order_tab.line_text
      FROM   (SELECT DISTINCT 'Charges order #' || oh.order_number || ' ' ||
		      decode(ol.open_flag,
			 'Y',
			 'is open',
			 'is closed') line_text
	  FROM   cs_estimate_details  ch,
	         cs_incidents_all_b   cs,
	         oe_order_lines_all   ol,
	         oe_order_headers_all oh
	  WHERE  ch.incident_id = cs.incident_id
	  AND    cs.incident_id = p_incident_id --param
	  AND    ch.interface_to_oe_flag = 'Y'
	  AND    ch.order_line_id = ol.line_id
	  AND    ol.header_id = oh.header_id
	  AND    ch.charge_line_type = 'ACTUAL'
	  AND    oh.order_number NOT IN
	         (SELECT oh.order_number
	           FROM   csd_repairs              r,
		      cs_incidents_all_b       b,
		      csd_product_transactions tr2,
		      oe_order_headers_all     oh2,
		      oe_order_lines_all       ol2
	           WHERE  r.incident_id = b.incident_id
	           AND    b.incident_number = cs.incident_number
	           AND    tr2.repair_line_id = r.repair_line_id
	           AND    oh2.header_id = tr2.order_header_id
	           AND    r.status IN ('O', 'C')
	           AND    ol2.header_id = oh2.header_id)) charges_order_tab
      UNION
      SELECT 2,
	 repair_sales_order_tab.line_text
      FROM   (SELECT 'Repair sales order #' || oh.order_number || ' ' ||
	         'is closed' line_text
	  FROM   csd_repairs              r,
	         cs_incidents_all_b       b,
	         csd_product_transactions tr,
	         oe_order_headers_all     oh
	  WHERE  r.incident_id = b.incident_id
	  AND    b.incident_id = p_incident_id --param
	  AND    tr.repair_line_id = r.repair_line_id
	  AND    oh.header_id = tr.order_header_id
	  AND    r.status IN ('O', 'C')
	  AND    oh.header_id NOT IN
	         (SELECT ol.header_id
	           FROM   oe_order_lines_all ol
	           WHERE  ol.header_id = oh.header_id
	           AND    ol.open_flag = 'Y')
	  UNION
	  SELECT 'Repair sales order #' || oh.order_number || ' ' ||
	         'is open' line_text
	  FROM   csd_repairs              r,
	         cs_incidents_all_b       b,
	         csd_product_transactions tr,
	         oe_order_headers_all     oh
	  WHERE  r.incident_id = b.incident_id
	  AND    b.incident_id = p_incident_id --param
	  AND    tr.repair_line_id = r.repair_line_id
	  AND    oh.header_id = tr.order_header_id
	  AND    r.status IN ('O', 'C')
	  AND    oh.header_id IN
	         (SELECT ol.header_id
	           FROM   oe_order_lines_all ol
	           WHERE  ol.header_id = oh.header_id
	           AND    ol.open_flag = 'Y')) repair_sales_order_tab
      UNION
      SELECT 3,
	 parts_requirment_order_tab.line_text
      FROM   (SELECT DISTINCT 'Parts requirment order #' || oh.order_number || ' ' ||
		      decode(ol.open_flag,
			 'Y',
			 'is open',
			 'is closed ') line_text
	  FROM   csp_requirement_lines   l,
	         csp_requirement_headers h,
	         jtf_tasks_b             t,
	         cs_incidents_all_b      b,
	         csp_req_line_details    ll,
	         oe_order_lines_all      ol,
	         oe_order_headers_all    oh
	  WHERE  h.task_id = t.task_id
	  AND    t.source_object_type_code = 'SR'
	  AND    t.source_object_id = b.incident_id
	  AND    l.requirement_header_id = h.requirement_header_id
	  AND    ll.requirement_line_id = l.requirement_line_id
	  AND    b.incident_id = p_incident_id --param
	  AND    ll.source_id = ol.line_id
	  AND    ol.header_id = oh.header_id) parts_requirment_order_tab
      UNION
      SELECT 4,
	 move_order_tab.line_text
      FROM   (SELECT 'Move order #' || mh.request_number || ' ' || 'is open' line_text
	  FROM   mtl_txn_request_headers mh,
	         cs_incidents_all_b      cb
	  WHERE  mh.description = cb.incident_number
	  AND    cb.incident_id = p_incident_id --param
	  AND    mh.header_id IN
	         (SELECT ml.header_id
	           FROM   mtl_txn_request_lines ml,
		      fnd_lookup_values     flv
	           WHERE  flv.lookup_type = 'MTL_TXN_REQUEST_STATUS'
	           AND    flv.lookup_code = ml.line_status
	           AND    flv.language = 'US'
	           AND    flv.meaning NOT IN ('Canceled', 'Closed'))
	  UNION
	  -- This SQL Returns Closed Move Orders
	  SELECT 'Move order #' || mh.request_number || ' ' ||
	         'is closed'
	  FROM   mtl_txn_request_headers mh,
	         cs_incidents_all_b      cb
	  WHERE  mh.description = cb.incident_number
	  AND    cb.incident_id = p_incident_id --param
	  AND    mh.header_id NOT IN
	         (SELECT ml.header_id
	           FROM   mtl_txn_request_lines ml,
		      fnd_lookup_values     flv
	           WHERE  flv.lookup_type = 'MTL_TXN_REQUEST_STATUS'
	           AND    flv.lookup_code = ml.line_status
	           AND    flv.language = 'US'
	           AND    flv.meaning NOT IN ('Canceled', 'Closed'))) move_order_tab
      UNION
      SELECT 5,
	 open_tasks_tab.line_text
      FROM   (SELECT decode(COUNT(*),
		    0,
		    'There are open tasks',
		    'All tasks are closed') line_text
	  FROM   cs_incidents_all_b cb
	  WHERE  cb.incident_id = p_incident_id --param
	  AND    cb.incident_id NOT IN
	         (SELECT t.source_object_id
	           FROM   jtf_tasks_b         t,
		      jtf_task_statuses_b s
	           WHERE  t.source_object_type_code = 'SR'
	           AND    t.source_object_id = cb.incident_id
	           AND    t.task_status_id = s.task_status_id
	           AND    (s.closed_flag = 'N' OR s.closed_flag IS NULL))) open_tasks_tab
      UNION
      -- Vitaly k. 28/04/2010
      SELECT 6,
	 'Task# ' || jtb.task_number ||
	 ' : Debrief completed with error' text
      FROM   cs_incidents_all_b       ciab,
	 jtf_tasks_b              jtb,
	 jtf_task_all_assignments jtaa,
	 csf_debrief_headers      cdh
      WHERE  ciab.incident_id = p_incident_id --param
      AND    ciab.incident_id = jtb.source_object_id
      AND    jtb.task_id = jtaa.task_id
      AND    jtaa.task_assignment_id = cdh.task_assignment_id
      AND    cdh.processed_flag = 'COMPLETED W/ERRORS'
      UNION
      SELECT 7,
	 'Resolution code is missing' text
      FROM   cs_incidents_all_b ciab
      WHERE  ciab.incident_id = p_incident_id --param
      AND    ciab.incident_attribute_2 IS NULL
      ORDER  BY 1;
  
    -------------------
    stop_processing EXCEPTION;
    v_sr_related_orders_info VARCHAR2(1000);
  
  BEGIN
  
    IF p_incident_id IS NULL THEN
      RAISE stop_processing;
    END IF;
  
    FOR orders_info_rec IN get_sr_related_orders
    LOOP
      IF v_sr_related_orders_info IS NULL THEN
        v_sr_related_orders_info := orders_info_rec.line_text;
      ELSE
        v_sr_related_orders_info := v_sr_related_orders_info || chr(10) ||
			orders_info_rec.line_text;
      END IF;
    END LOOP;
  
    RETURN v_sr_related_orders_info;
  
  EXCEPTION
    WHEN stop_processing THEN
      RETURN '';
    WHEN OTHERS THEN
      RETURN '';
  END get_sr_related_orders_message;

  FUNCTION get_region_by_ou(p_operating_unit_id NUMBER) RETURN VARCHAR2 IS
    l_ou_name hr_operating_units.name%TYPE;
  BEGIN
  
    SELECT NAME
    INTO   l_ou_name
    FROM   hr_operating_units
    WHERE  organization_id = p_operating_unit_id;
  
    IF l_ou_name = 'OBJET IL (OU)' THEN
      RETURN 'IL';
    ELSIF l_ou_name IN ('OBJET US (OU)', 'Stratasys US OU') THEN
      RETURN 'USA';
    ELSIF l_ou_name = 'OBJET DE (OU)' THEN
      RETURN 'EU';
    ELSIF l_ou_name = 'OBJET HK (OU)' THEN
      RETURN 'FE';
    ELSE
      RETURN ' ';
    END IF;
  
  END get_region_by_ou;

  --------------------------------------------------------------------
  --  name:            XXOE_COMMISSION
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   07/03/2010
  --------------------------------------------------------------------
  --  purpose :        Function that get salesperson_id and return
  --                   resource name
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  07/03/2010  Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  FUNCTION get_resource_name_by_id(p_resource_id IN NUMBER) RETURN VARCHAR2 IS
  
    l_resource_name VARCHAR2(360) := NULL;
  
  BEGIN
    SELECT rs_reg_mang.resource_name
    INTO   l_resource_name
    FROM   jtf_rs_resource_extns_vl rs_reg_mang,
           jtf.jtf_rs_salesreps     t
    WHERE  rs_reg_mang.resource_id = t.resource_id
    AND    t.salesrep_id = p_resource_id
          --rs_reg_mang.resource_id  =
    AND    rownum = 1;
  
    RETURN l_resource_name;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_resource_name_by_id;

  -----------------------------------------------------------------------
  --  customization code:
  --  name:               check_security_by_oper_unit
  --  create by:          Vitaly
  --  $Revision:          1.0
  --  creation date:      07/06/2010
  --  Purpose :           Check the privilege of seeing the information according to the profile :
  --                      "XX: VPD Security Enabled" (profile short name 'XXCS_VPD_SECURITY_ENABLED')
  --                      The function gets the ORG_ID, PARTY_ID and four additional parameters (for future use)
  --                      ORG_ID --> For the VPD
  --                      PARTY_ID --> For the exceptions parties
  -----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   07/06/2010    Vitaly          initial build
  --  1.1   09/02/2012    Dalit A. Raviv  add ability to OU HK to see OU CN reports
  --                                      The solution was to create new responsibility -> Dispatcher Reports, OBJET HK&CN
  --                                      that can see all OU but this package handle the report security
  --                                      that give the ability of HK to see CN data.
  -----------------------------------------------------------------------
  FUNCTION check_security_by_oper_unit(p_org_id     IN NUMBER,
			   p_party_id   IN NUMBER DEFAULT NULL,
			   p_add_param1 IN VARCHAR2 DEFAULT NULL,
			   p_add_param2 IN VARCHAR2 DEFAULT NULL,
			   p_add_param3 IN VARCHAR2 DEFAULT NULL,
			   p_add_param4 IN VARCHAR2 DEFAULT NULL)
    RETURN VARCHAR2 IS
  
    v_numeric_dummy NUMBER;
  BEGIN
    ----Check parameters---
    -- case new resp and org_id HK or CN
    IF fnd_global.resp_id = 51917 AND nvl(p_org_id, 81) IN (103, 161) THEN
      RETURN 'Y';
      -- case new resp and org_id not HK or CN
    ELSIF fnd_global.resp_id = 51917 AND
          nvl(p_org_id, 81) NOT IN (103, 161) THEN
      RETURN 'N';
      -- case for exception for the new resp
    ELSIF fnd_global.resp_id = 51917 AND p_party_id IS NOT NULL THEN
      BEGIN
        -- Check party vpd exception flag
        SELECT 1
        INTO   v_numeric_dummy
        FROM   hz_parties hp
        WHERE  hp.party_id = p_party_id
        AND    upper(hp.attribute2) = 'Y'; --  No VPD for this part (exception)
        RETURN 'Y';
      EXCEPTION
        WHEN OTHERS THEN
          RETURN 'N';
      END;
      -- all other responsibilities
    ELSE
      IF p_org_id IS NULL THEN
        RETURN 'N';
      END IF;
      -- 10003 responsibility level value
      IF nvl(xxobjt_general_utils_pkg.get_profile_specific_value('XXCS_VPD_SECURITY_ENABLED',
					     10003),
	 'Y') = 'Y' AND p_org_id = fnd_profile.value('org_id') THEN
        RETURN 'Y';
      END IF;
      IF nvl(xxobjt_general_utils_pkg.get_profile_specific_value('XXCS_VPD_SECURITY_ENABLED',
					     10003),
	 'Y') = 'N' THEN
        RETURN 'Y';
      END IF;
      IF p_party_id IS NOT NULL THEN
        -- Check party vpd exception flag
        SELECT 1
        INTO   v_numeric_dummy
        FROM   hz_parties hp
        WHERE  hp.party_id = p_party_id
        AND    upper(hp.attribute2) = 'Y'; --  No VPD for this part (exception)
        RETURN 'Y';
      END IF; -- p_party_id is not null
    END IF; -- responsibility check
    RETURN 'N';
  EXCEPTION
    WHEN no_data_found THEN
      RETURN 'N'; ---exception does not found for this party_id
    WHEN OTHERS THEN
      RETURN 'N';
  END check_security_by_oper_unit;

  --------------------------------------------------------------------
  --  name:            upd_external_att_in_sr
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   07/04/2011
  --------------------------------------------------------------------
  --  purpose :        Procedute taht update SR external_attribute1
  --                   by specific logic
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  07/04/2011  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE upd_external_att_in_sr(errbuf  OUT VARCHAR2,
		           retcode OUT VARCHAR2) IS
  BEGIN
    errbuf  := NULL;
    retcode := 0;
    FOR rec IN (SELECT to_char(cii.attribute8) region,
	           to_number(ciab.incident_id) incident_id
	    FROM   csi_item_instances cii,
	           cs_incidents_all_b ciab
	    WHERE  cii.attribute8 IS NOT NULL
	    AND    ciab.external_attribute_1 IS NULL
	    AND    cii.instance_id = ciab.customer_product_id)
    LOOP
      BEGIN
        UPDATE cs_incidents_all_b
        SET    external_attribute_1 = rec.region
        WHERE  incident_id = rec.incident_id;
      
        fnd_file.put_line(fnd_file.log,
		  'Success Incident id - ' || rec.incident_id);
      EXCEPTION
        WHEN OTHERS THEN
          fnd_file.put_line(fnd_file.log,
		    'Failed update Incident id - ' ||
		    rec.incident_id);
          errbuf  := 'At Least One Incident did not update';
          retcode := 1;
      END;
    END LOOP;
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'GEN EXC - upd_external_att_in_sr - ' ||
	     substr(SQLERRM, 1, 240);
      retcode := 2;
  END upd_external_att_in_sr;

  --------------------------------------------------------------------
  --  name:            get_SR_is_repeated
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   10/08/2011
  --------------------------------------------------------------------
  --  purpose :        function that check if SR is repeate:
  --                   check that type is reactive if yes check 30 days back
  --                   if there is SR for the same customer_product_id(instance)
  --                   if yes check that the SR is reactive if Yes -> return Y
  --                   else return N
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10/08/2011  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_sr_is_repeated(p_incident_id NUMBER) RETURN VARCHAR2 IS
  
    l_reactive               VARCHAR2(150) := NULL;
    l_customer_product_id    NUMBER := NULL;
    l_incident_id            NUMBER := NULL;
    l_incident_occurred_date DATE := NULL;
  BEGIN
    -- check SR type is REACTIVE
    SELECT nvl(cit.attribute4, 'DD') xxcs_proactive_reactive,
           cia.customer_product_id,
           cia.incident_occurred_date
    --, cia.incident_id, cia.incident_number, cia.creation_date
    INTO   l_reactive,
           l_customer_product_id,
           l_incident_occurred_date
    FROM   cs_incident_types_b cit,
           cs_incidents_all_b  cia
    WHERE  cit.incident_type_id = cia.incident_type_id
    AND    cia.incident_id = p_incident_id;
  
    IF l_reactive <> 'REACTIVE' THEN
      RETURN 'N';
    ELSE
      SELECT nvl(cit.attribute4, 'DD') xxcs_proactive_reactive,
	 cia.incident_id
      --, cia.incident_id, cia.incident_number, cia.creation_date
      INTO   l_reactive,
	 l_incident_id
      FROM   cs_incident_types_b cit,
	 cs_incidents_all_b  cia
      WHERE  cit.incident_type_id = cia.incident_type_id
      AND    cia.incident_id <> p_incident_id
      AND    cia.customer_product_id = l_customer_product_id
      AND    cia.incident_occurred_date BETWEEN
	 l_incident_occurred_date - 30 AND l_incident_occurred_date
      AND    cit.attribute4 = l_reactive
      AND    rownum = 1;
    
      IF l_reactive <> 'REACTIVE' THEN
        RETURN 'N';
      ELSE
        RETURN 'Y';
      END IF;
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'N';
  END get_sr_is_repeated;

  --------------------------------------------------------------------
  --  name:            XXCS_GET_SUB_FOR_ORDER_LINE
  --  create by:       Adi Safin
  --  Revision:        1.0
  --  creation date:   14/06/2012
  --------------------------------------------------------------------
  --  purpose :        function that get the subinventory for each order line.
  --                  if it from stock to customer. get the subinventory before Stage subinventory
  --                  if it a recieving line it will get the subinventory where the part will be "sit".
  --                  This function is been used in view XXCS_SHIPPING_REPORT_V
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  14/06/2012  Adi Safin         initial build
  --------------------------------------------------------------------
  FUNCTION get_sub_for_order_line(p_org_id            IN NUMBER,
		          p_inventory_item_id IN NUMBER,
		          p_line_id           IN NUMBER,
		          p_line_type         IN VARCHAR2)
    RETURN VARCHAR2 IS
    v_subinventory VARCHAR2(150) := NULL;
  BEGIN
  
    IF p_line_type != 'RETURN' THEN
      SELECT mmt.subinventory_code
      INTO   v_subinventory
      FROM   wsh_delivery_details      wdd,
	 wsh_delivery_assignments  wdda,
	 wsh_new_deliveries        wd,
	 mtl_material_transactions mmt,
	 mtl_system_items_b        msi
      WHERE  wdd.delivery_detail_id = wdda.delivery_detail_id(+)
      AND    wdda.delivery_id = wd.delivery_id(+)
      AND    wdd.org_id = p_org_id
      AND    wdd.source_line_id = p_line_id
      AND    mmt.inventory_item_id = msi.inventory_item_id
      AND    mmt.organization_id = msi.organization_id
      AND    mmt.transaction_id = wdd.transaction_id;
    ELSE
      SELECT t.subinventory_code
      INTO   v_subinventory
      FROM   mtl_material_transactions t
      WHERE  t.source_code = 'RCV'
      AND    t.trx_source_line_id = p_line_id
      AND    t.inventory_item_id = p_inventory_item_id;
    END IF;
  
    RETURN(v_subinventory);
  EXCEPTION
    WHEN OTHERS THEN
      RETURN v_subinventory;
  END get_sub_for_order_line;

  --------------------------------------------------------------------
  --  name:            Update_TM_PL_in_IB
  --  create by:       Adi Safin
  --  Revision:        1.0
  --  creation date:   27/12/2012
  --------------------------------------------------------------------
  --  purpose :        Procedure that update T&M price list in the IB
  --                   it checks the following logic
  --                   for each instance if it has PL defined in the IB
  --                   if the machine move from one CS region to another
  --                   if the machine is not under china location
  --                   Concurrent name : XX: Update TM Price list
  --                   Responsibility name : CRM Service super user.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  27/12/2012  Adi Safin         initial build
  --------------------------------------------------------------------

  PROCEDURE update_tm_pl_in_ib(errbuf  OUT VARCHAR2,
		       retcode OUT VARCHAR2) IS
  
    CURSOR ib_instance IS
      SELECT cii.instance_id,
	 rule_pl rule_pl_id
      FROM   csi_item_instances cii,
	 mtl_system_items_b msib,
	 mtl_item_categories mic,
	 mtl_categories_b mcb,
	 qp_list_headers_vl qlh,
	 qp_list_headers_vl qls,
	 xxcsi_inst_current_location_v loc,
	 (SELECT cii.instance_id rule_instance_id,
	         cii.attribute8  rule_region,
	         ffv.attribute7  rule_pl
	  FROM   csi_item_instances  cii,
	         fnd_flex_values_vl  ffv,
	         fnd_flex_value_sets ffvs
	  WHERE  cii.attribute8 IS NOT NULL
	  AND    ffv.flex_value_set_id = ffvs.flex_value_set_id
	  AND    ffvs.flex_value_set_name = 'XXCS_CS_REGIONS'
	  AND    cii.attribute8 = ffv.flex_value
	  AND    cii.owner_party_id NOT IN
	         (SELECT hp.party_id
	           FROM   fnd_flex_values_vl  ffv,
		      fnd_flex_value_sets ffvs,
		      hz_parties          hp
	           WHERE  ffv.flex_value_set_id = ffvs.flex_value_set_id
	           AND    ffvs.flex_value_set_name =
		      'XXCS_EXCEPTION_CUSTOMERS'
	           AND    hp.party_name = ffv.flex_value
	           AND    ffv.enabled_flag = 'Y')
	  UNION
	  SELECT cii.instance_id rule_instance_id,
	         cii.attribute8  rule_region,
	         ffv.attribute1  rule_pl
	  FROM   fnd_flex_values_vl  ffv,
	         fnd_flex_value_sets ffvs,
	         hz_parties          hp,
	         csi_item_instances  cii
	  WHERE  ffv.flex_value_set_id = ffvs.flex_value_set_id
	  AND    ffvs.flex_value_set_name = 'XXCS_EXCEPTION_CUSTOMERS'
	  AND    hp.party_name = ffv.flex_value
	  AND    ffv.enabled_flag = 'Y'
	  AND    hp.party_id = cii.owner_party_id)
      WHERE  cii.instance_id = rule_instance_id
      AND    cii.owner_party_id <> 10041
      AND    (cii.attribute11 IS NULL OR cii.attribute11 <> rule_pl)
      AND    mcb.category_id = mic.category_id
      AND    mcb.attribute4 IN ('PRINTER', 'WATER-JET')
      AND    msib.inventory_item_id = mic.inventory_item_id
      AND    cii.inventory_item_id = msib.inventory_item_id
      AND    msib.organization_id = 91
      AND    mic.organization_id = msib.organization_id
      AND    cii.attribute11 = qls.list_header_id
      AND    qls.currency_code = qlh.currency_code
      AND    cii.instance_id = loc.instance_id
      AND    rule_pl = qlh.list_header_id
      AND    loc.country != 'China';
  
  BEGIN
    FOR ii IN ib_instance
    LOOP
      BEGIN
        UPDATE csi_item_instances cii
        SET    cii.attribute11 = ii.rule_pl_id
        WHERE  cii.instance_id = ii.instance_id;
        COMMIT;
      EXCEPTION
        WHEN OTHERS THEN
        
          fnd_file.put_line(fnd_file.log, 'Instance - ' || ii.instance_id);
          fnd_file.put_line(fnd_file.log,
		    'Price list id - ' || ii.rule_pl_id);
          fnd_file.put_line(fnd_file.log,
		    'Sqlerrm - ' || substr(SQLERRM, 1, 240));
      END;
    END LOOP;
  END update_tm_pl_in_ib;

  --------------------------------------------------------------------
  --  name:            get_SR_is_repeated
  --  create by:       Dalit Raviv
  --  Revision:        1.0
  --  creation date:   30/06/2013
  --------------------------------------------------------------------
  --  purpose :        function that check if SR is repeate:
  --                   check that type is reactive and it has more the 1 SR on speicfic SN
  --                   in required period.
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  30/06/2013  Dalit Raviv    initial build
  --------------------------------------------------------------------

  FUNCTION get_sr_is_repeated_new(p_serial    IN VARCHAR2,
		          p_from_date IN DATE,
		          p_to_date   IN DATE) RETURN VARCHAR2 AS
  
    l_count NUMBER := 0;
  
  BEGIN
  
    SELECT COUNT(1)
    INTO   l_count
    FROM   xxcs_service_calls sc1
    WHERE  sc1.incident_occurred_date BETWEEN p_from_date AND p_to_date
    AND    sc1.incident_type_name IN
           (SELECT cit.name
	 FROM   cs_incident_types_vl cit
	 WHERE  cit.attribute4 = 'REACTIVE')
    AND    sc1.serial_number = p_serial;
  
    IF l_count > 1 THEN
      RETURN 'Y';
    ELSE
      RETURN 'N';
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'N';
  END;

  --------------------------------------------------------------------
  --  name:            get_contract_entitlement
  --  create by:       Adi Safin
  --  Revision:        1.0
  --  creation date:   22/02/2017
  --------------------------------------------------------------------
  --  purpose :        function that check IB is under service contract or warranty
  --                   CHG0040155 - Used for service contract entitlement
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  22/02/2017  Adi Safin         CHG0040155 - initial build
  --  1.1  14/08/2017  Adi Safin         CHG0040196 - add parameter p_ol_item_id , Add validation of technology between printer in order line
  --                                                  If technology is not the same - Discount won't given
  --  1.2  14-Feb-2019 Diptasurjya       INC0147595 - Change query to get technology of printer
  -- 1.3  1.4.19       yuval tal         INC0152534 - change cursor source to new copystorm
  --------------------------------------------------------------------

  FUNCTION get_contract_entitlement(p_instance_id VARCHAR2,
			p_ol_item_id  IN NUMBER) RETURN VARCHAR2 IS
  
    -- l_serial_number    VARCHAR2(30) := NULL;
    l_entitlement_type VARCHAR2(50) := NULL;
    v_ol_technology    VARCHAR2(100) := NULL;
    v_pr_technology    VARCHAR2(100) := NULL;
    --INC0152534
    CURSOR c_entitlement_type(p_instance_id VARCHAR2) IS
      SELECT sc_tmp.name                     service_contract_type__c,
	 sc.startdate,
	 sc.enddate,
	 ib.serialnumber                 serial_number__c,
	 ib.service_contract_warranty__c service_contract__c
      FROM   asset@source_sf2           ib,
	 servicecontract@source_sf2 sc,
	 servicecontract@source_sf2 sc_tmp,
	 product2@source_sf2        pr
      WHERE  ib.service_contract_warranty__c = sc.id
      AND    pr.id = sc.service_contract_product__c
      AND    pr.contract_template__c = sc_tmp.id
      AND    ib.external_key__c = p_instance_id;
  
  BEGIN
    -- CHG0040196
    -- Add validation of technology between printer in order line
    -- If technology is not the same - Discount won't given
    IF nvl(fnd_profile.value('XXCS_OM_CHK_TECH_ENTITLE'), 'Y') = 'Y' THEN
      SELECT xxinv_utils_pkg.get_category_segment('SEGMENT6',
				  '1100000221',
				  p_ol_item_id)
      INTO   v_ol_technology
      FROM   dual;
    
      /*INC0147595 - Comment below query*/
      /*SELECT xxinv_utils_pkg.get_category_segment('SEGMENT6',
                                                  '1100000221',
                                                  cii.inventory_item_id)
      INTO   v_pr_technology
      FROM   xxsf_csi_item_instances cii
      WHERE  cii.instance_id = p_instance_id;*/
    
      /*INC0147595 - Add below alternate query to get printer technology*/
      SELECT xxinv_utils_pkg.get_category_segment('SEGMENT6',
				  '1100000221',
				  msib.inventory_item_id)
      INTO   v_pr_technology
      FROM   csi_item_instances cii,
	 mtl_system_items_b msib
      WHERE  cii.instance_id = to_number(p_instance_id)
      AND    cii.inventory_item_id = msib.inventory_item_id
      AND    msib.organization_id =
	 xxinv_utils_pkg.get_master_organization_id;
    
      IF v_ol_technology != v_pr_technology THEN
        RETURN NULL;
      END IF;
    END IF; -- end CHG0040196
  
    IF p_instance_id IS NOT NULL THEN
      FOR l_entitlement_type_rec IN c_entitlement_type(p_instance_id)
      LOOP
        l_entitlement_type := l_entitlement_type_rec.service_contract_type__c;
      END LOOP;
    END IF;
  
    RETURN l_entitlement_type;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
    
  END get_contract_entitlement;
  --------------------------------------------------------------------
  --  name:            update_upg_instance_id
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   19/06/2017
  --------------------------------------------------------------------
  --  purpose :        This will be called from XXCS_HASP_PKG and XXCS_UPGRADE_IB_UPON_SHIPP_PKG
  --                   This procedure will help to update the Instance id of the Printer
  --                   in the Upgrade Line(Update Sales Order Line.Attribute1 of Upgrade Item line)
  --                   Instance id will fetched based on the Attribute15 of the Upgrade Item SO line
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16/07/2017  Adi Safin         CHG0040890 - updated the upgrade advisor to support selling an upgrade in an initial sale
  --  1.1  13/08/2017  Adi Safin         CHG0040196 - Support features lookup (like Voxel) and update salesforce interface with new information
  --  1.2  04.03.19    Lingaraj          INC0148774 - remove all call s to  xxobjt_oa2sf_interface_pkg.insert_into_interface
  --  1.3  22-May-2019 Adi Safin         CHG0045785 - Add adittional query to cursor in order to update printer lines with poulation that the PN associate to Printer line (like warranty)
  --  1.4  15-Sep-2019 Adi Safin         CHG0046812 - Fix program to support Warranty upgrade only lines
  --  1.5  02.02.2020  Yuval Tal         CHG0047309 - Add insert event to salesforce interface when IB updated on so line
  --  1.6  5/11/2021   Yuval tal         CHG0049822 - add in ('Warranty',’ SW-Printer’,’ SW-Account’) upg,
  --------------------------------------------------------------------
  PROCEDURE update_upg_instance_id(errbuf  OUT VARCHAR2,
		           retcode OUT VARCHAR2) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  
    CURSOR upd_printer_instance IS
      SELECT DISTINCT oola_upg.line_id upg_line_id,
	          (nvl(ooha.order_number, ooha.quote_number) || '-' ||
	          oola_upg.line_number) entity_code, --CHG0047309
	          oola_upg.ordered_item upg_item,
	          oola_printer.line_id printer_line_id,
	          oola_printer.ordered_item printer_item,
	          instance_info.serial_number printer_serial_number,
	          instance_info.instance_id printer_instance_id
      FROM   oe_order_lines_all oola_upg,
	 oe_order_lines_all oola_printer,
	 oe_order_headers_all ooha,
	 oe_order_lines_all_dfv oldf_upg,
	 (SELECT upgrade_item_id,
	         before_upgrade_item
	  FROM   xxcs_sales_ug_items_v upg
	  UNION ALL
	  SELECT msi.inventory_item_id,
	         flv.attribute1
	  FROM   fnd_lookup_values  flv,
	         mtl_system_items_b msi
	  WHERE  flv.lookup_type = 'XXOM_FEAT_MACHINE_LINE'
	  AND    msi.organization_id =
	         xxinv_utils_pkg.get_master_organization_id
	  AND    flv.language = 'US'
	  AND    msi.segment1 = flv.description
	  UNION ALL
	  SELECT oola.inventory_item_id,
	         (SELECT to_char(oola_pr.inventory_item_id)
	          FROM   oe_order_lines_all oola_pr
	          WHERE  to_char(oola_pr.line_id) = oola.attribute15) pr_inv_id
	  FROM   oe_order_lines_all     oola,
	         oe_order_headers_all   ooha,
	         oe_order_lines_all_dfv oldf
	  WHERE  ooha.header_id = oola.header_id
	  AND    oola.attribute15 IS NOT NULL
	  AND    oola.attribute1 IS NULL
	  AND    oola.rowid = oldf.row_id
	  AND    oldf.printer_water_jet_line IS NOT NULL
	  AND    xxssys_oa2sf_util_pkg.get_category_value('Activity Analysis',
					  oola.inventory_item_id) IN
	         ('Warranty', 'SW-Printer', 'SW-Account')) upg, -- CHG0049822 add 'SW-System', 'SW-Account'
	 (SELECT wsn.fm_serial_number serial_number,
	         cii.instance_id,
	         wdd.source_line_id
	  FROM   wsh_delivery_details     wdd,
	         wsh_delivery_assignments wda,
	         wsh_new_deliveries       wnd,
	         wsh_serial_numbers       wsn,
	         csi_item_instances       cii
	  WHERE  wdd.delivery_detail_id = wda.delivery_detail_id
	  AND    wdd.delivery_detail_id = wsn.delivery_detail_id
	  AND    wda.delivery_id = wnd.delivery_id
	  AND    cii.inventory_item_id = wdd.inventory_item_id
	  AND    cii.serial_number = wsn.fm_serial_number) instance_info
      WHERE  ooha.header_id = oola_upg.header_id
      AND    ooha.header_id = oola_printer.header_id
      AND    oola_upg.inventory_item_id = upg.upgrade_item_id
      AND    oola_printer.inventory_item_id =
	 to_number(upg.before_upgrade_item)
      AND    oola_upg.attribute15 = to_char(oola_printer.line_id)
      AND    oola_upg.attribute1 IS NULL
      AND    oldf_upg.row_id = oola_upg.rowid
      AND    oldf_upg.printer_water_jet_line IS NOT NULL
      AND    oola_upg.flow_status_code = 'CLOSED'
      AND    oola_printer.flow_status_code = 'CLOSED'
      AND    instance_info.source_line_id = oola_printer.line_id;
  
    l_xxssys_event_rec xxssys_events%ROWTYPE;
    l_err_code         VARCHAR2(10) := 0;
    l_err_desc         VARCHAR2(2500) := NULL;
  BEGIN
    retcode := 0;
  
    /* SELECT user_id
    INTO   l_user_id
    FROM   fnd_user
    WHERE  user_name = 'SALESFORCE';*/
  
    FOR upg_so_line_rec IN upd_printer_instance
    LOOP
    
      UPDATE oe_order_lines_all
      SET    attribute1       = upg_so_line_rec.printer_instance_id,
	 last_updated_by  = fnd_global.user_id,
	 last_update_date = SYSDATE
      WHERE  line_id = upg_so_line_rec.upg_line_id;
      -- CHG0047309
      l_xxssys_event_rec             := NULL;
      l_xxssys_event_rec.target_name := 'STRATAFORCE';
      l_xxssys_event_rec.entity_name := 'SO_LINE';
      l_xxssys_event_rec.entity_id   := upg_so_line_rec.upg_line_id;
      l_xxssys_event_rec.event_name  := 'xxcs_utils_pkg.update_upg_instance_id';
      l_xxssys_event_rec.entity_code := upg_so_line_rec.entity_code;
      --Insert SO LINE Event
      xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'Y');
    
    -- end CHG0047309
    
    END LOOP;
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      retcode := 2;
      errbuf  := 'Error in Order Line Attribute1 Instance Id Updation, Error :' ||
	     SQLERRM;
      ROLLBACK;
  END update_upg_instance_id;

END xxcs_utils_pkg;
/
