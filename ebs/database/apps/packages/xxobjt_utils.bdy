CREATE OR REPLACE PACKAGE BODY xxatc_erp.xxobjt_utils IS
  ---------------------------------------------------------------------------
  -- Package: xxobjt_utils
  -- Created: 11.2.13
  -- Author  : 
  --------------------------------------------------------------------------
  -- Perpose: called from bi database
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  18.2.13   yuval tal       cust 659: performance : change syntax of select in proc 
  --                                    get_cs_installation_date, get_cs_instance_type  after upgrade 11g
  FUNCTION get_parent_cust_location(p_cust_trx_line_gl_dist_id IN NUMBER)
    RETURN VARCHAR2 IS
    v_gl_code_combin_id NUMBER;
    v_desc              VARCHAR2(240);
  BEGIN
    SELECT hcsu.gl_id_rev
      INTO v_gl_code_combin_id
      FROM ar.ra_cust_trx_line_gl_dist_all rclg,
           ar.ra_customer_trx_all          rct,
           ar.hz_cust_site_uses_all        hcsu
     WHERE rct.customer_trx_id = rclg.customer_trx_id
       AND hcsu.site_use_id = rct.bill_to_site_use_id
       AND rclg.cust_trx_line_gl_dist_id = p_cust_trx_line_gl_dist_id;
  
    SELECT MIN(ffv.description)
      INTO v_desc
      FROM apps.fnd_flex_value_children_v ffvc,
           apps.fnd_flex_values_vl        ffv,
           applsys.fnd_flex_hierarchies   ffh,
           gl.gl_code_combinations        gcc
     WHERE ffvc.flex_value_set_id = 1013892
       AND ffvc.flex_value_set_id = ffh.flex_value_set_id
       AND ffh.flex_value_set_id = ffv.flex_value_set_id
       AND ffh.hierarchy_id = ffv.structured_hierarchy_level
       AND ffvc.parent_flex_value = ffv.flex_value
       AND ffh.hierarchy_code = 'ACCOUNTING'
       AND ffvc.flex_value = gcc.segment6
       AND gcc.code_combination_id = v_gl_code_combin_id;
    RETURN(v_desc);
  EXCEPTION
    WHEN no_data_found THEN
      RETURN(NULL);
  END get_parent_cust_location;

  FUNCTION get_om_parent_cust_location(p_invoice_to_org_id IN NUMBER)
    RETURN VARCHAR2 IS
    v_desc   VARCHAR2(240);
    v_gcc_id NUMBER;
  BEGIN
    SELECT hzusg_bill_to.gl_id_rev
      INTO v_gcc_id
      FROM ar.hz_cust_site_uses_all  hzusg_bill_to,
           ar.hz_cust_acct_sites_all hzcas_bill_to,
           ar.hz_party_sites         hzps_bill_to,
           ar.hz_parties             hzp_bill_to
     WHERE hzusg_bill_to.site_use_id = p_invoice_to_org_id
       AND hzusg_bill_to.cust_acct_site_id =
           hzcas_bill_to.cust_acct_site_id
       AND hzcas_bill_to.party_site_id = hzps_bill_to.party_site_id
       AND hzps_bill_to.party_id = hzp_bill_to.party_id;
  
    SELECT MIN(ffv.description)
      INTO v_desc
      FROM apps.fnd_flex_value_children_v ffvc,
           apps.fnd_flex_values_vl        ffv,
           applsys.fnd_flex_hierarchies   ffh,
           gl.gl_code_combinations        gcc
     WHERE ffvc.flex_value_set_id = 1013892
       AND ffvc.flex_value_set_id = ffh.flex_value_set_id
       AND ffh.flex_value_set_id = ffv.flex_value_set_id
       AND ffh.hierarchy_id = ffv.structured_hierarchy_level
       AND ffvc.parent_flex_value = ffv.flex_value
       AND ffh.hierarchy_code = 'ACCOUNTING'
       AND ffvc.flex_value = gcc.segment6
       AND gcc.code_combination_id = v_gcc_id;
    RETURN(v_desc);
  EXCEPTION
    WHEN no_data_found THEN
      RETURN(NULL);
  END;
  /*
  Function Get_OM_Parent_Cust_Location (P_Item_ID in number) return varchar2
  Is
    v_SalesAccountID  Number;
    v_Desc            Varchar2(240);
  Begin
    Select msi.sales_account Into v_SalesAccountID
      From inv.mtl_system_items_b msi
     Where msi.organization_id = (Select min(master_organization_id) From inv.mtl_parameters mp)
       and msi.inventory_item_id = P_Item_ID;
       
    select min(ffv.DESCRIPTION) Into v_Desc
      from APPS.fnd_flex_value_children_v ffvc,
           APPS.fnd_flex_values_vl        ffv,
           APPLSYS.fnd_flex_hierarchies   ffh,
           GL.gl_code_combinations        gcc
    where ffvc.flex_value_set_id = 1013892
      and ffvc.flex_value_set_id = ffh.FLEX_VALUE_SET_ID
      and ffh.flex_value_set_id = ffv.flex_value_set_id
      and ffh.hierarchy_id = ffv.STRUCTURED_HIERARCHY_LEVEL
      and ffvc.parent_flex_value = ffv.FLEX_VALUE
      and ffh.hierarchy_code = 'ACCOUNTING'
      and ffvc.flex_value = gcc.segment6
      and gcc.code_combination_id = v_SalesAccountID;
  
    Return(v_Desc);
  Exception
    When no_data_found then
         return(null);
  End;
  */
  FUNCTION get_prod_line_family(p_cust_trx_line_gl_dist_id IN NUMBER)
    RETURN VARCHAR2 IS
    v_item_type   VARCHAR2(30);
    v_item_id     NUMBER;
    v_gccsegment5 VARCHAR2(30);
    v_partycateg  VARCHAR2(50);
    v_retval      VARCHAR2(25);
  BEGIN
    -- Get HZ Values
    SELECT rctl.inventory_item_id, gcc.segment5, hp.category_code
      INTO v_item_id, v_gccsegment5, v_partycateg
      FROM ar.ra_cust_trx_line_gl_dist_all rclg,
           ar.ra_customer_trx_lines_all    rctl,
           ar.ra_customer_trx_all          rct,
           ar.hz_cust_site_uses_all        hcsu,
           ar.hz_cust_accounts             hca,
           ar.hz_parties                   hp,
           gl.gl_code_combinations         gcc
     WHERE rct.customer_trx_id = rclg.customer_trx_id
       AND rctl.customer_trx_line_id(+) = rclg.customer_trx_line_id
       AND hcsu.site_use_id = rct.bill_to_site_use_id
       AND hca.cust_account_id = rct.bill_to_customer_id
       AND hp.party_id = hca.party_id
       AND gcc.code_combination_id = rclg.code_combination_id
       AND rclg.cust_trx_line_gl_dist_id = p_cust_trx_line_gl_dist_id;
    -- Get Item Type
    BEGIN
      SELECT msi.item_type
        INTO v_item_type
        FROM inv.mtl_system_items_b msi
       WHERE msi.organization_id =
             (SELECT MIN(master_organization_id) FROM inv.mtl_parameters mp)
         AND msi.inventory_item_id = v_item_id;
    EXCEPTION
      WHEN no_data_found THEN
        v_item_type := NULL;
    END;
  
    IF to_number(v_gccsegment5) BETWEEN 191 AND 199 OR
       v_partycateg = 'SUBCONTRACTOR' THEN
      v_retval := 'Equipment Other';
    ELSIF to_number(v_gccsegment5) BETWEEN 101 AND 189 THEN
      v_retval := 'Equipment';
    ELSIF substr(v_gccsegment5, 1, 1) = 5 THEN
      v_retval := 'Resins';
    ELSIF substr(v_gccsegment5, 1, 1) = 8 THEN
      v_retval := 'Service';
    ELSIF v_item_type = 'FRT' THEN
      --Freight item 
      v_retval := 'Freight';
    ELSE
      v_retval := 'Other';
    END IF;
    RETURN(v_retval);
  EXCEPTION
    WHEN OTHERS THEN
      RETURN(NULL);
  END get_prod_line_family;

  --------------------------------------------------------------------------
  -- get_cs_installation_date
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  18.2.13   yuval tal       performance : change select in proc 

  FUNCTION get_cs_installation_date(pf_interface_line_context IN VARCHAR2,
                                    interface_line_attribute6 IN VARCHAR2,
                                    p_treat_expected_inst     IN CHAR)
    RETURN DATE IS
    v_retval DATE;
  BEGIN
    IF p_treat_expected_inst = 'Y' THEN
      SELECT MAX(installation_date)
        INTO v_retval
        FROM (SELECT nvl(cii.install_date,
                          (SELECT MAX(task.scheduled_start_date)
                             FROM jtf.jtf_tasks_b       task,
                                  cs.cs_incidents_all_b cia
                            WHERE cia.incident_id = task.source_object_id
                              AND task.source_object_type_code = 'SR'
                              AND task.task_type_id = 11009 -- TASK_TYPE = 'Installation'
                              AND cia.customer_product_id = cii.instance_id)) installation_date
                 FROM csi.csi_item_instances     cii,
                      apps.xxcs_items_printers_v itmtypes
                WHERE /* cii.last_oe_order_line_id --= to_number(interface_line_attribute6)
                                                                                                                                                                                                                                                                                                                                                         in (Select ol.line_id
                                                                                                                                                                                                                                                                                                                                                               From ont.oe_order_lines_all ol
                                                                                                                                                                                                                                                                                                                                                              Where header_id = (Select ol2.header_id
                                                                                                                                                                                                                                                                                                                                                                                   From ont.oe_order_lines_all ol2
                                                                                                                                                                                                                                                                                                                                                                                  Where ol2.line_id = to_number(interface_line_attribute6)
                                                                                                                                                                                                                                                                                                                                                                                )
                                                                                                                                                                                                                                                                                                                                                            )*/
               
                cii.last_oe_order_line_id IN
                (SELECT ol.line_id
                   FROM ont.oe_order_lines_all ol, ont.oe_order_lines_all ol2
                  WHERE ol.header_id = ol2.header_id
                    AND ol2.line_id = to_number(interface_line_attribute6))
             AND itmtypes.inventory_item_id = cii.inventory_item_id
             AND itmtypes.item_type = 'PRINTER'
             AND pf_interface_line_context IN ('ORDER ENTRY', 'INTERCOMPANY'));
    ELSE
      SELECT MAX(cii.install_date)
        INTO v_retval
        FROM csi.csi_item_instances     cii,
             apps.xxcs_items_printers_v itmtypes
       WHERE cii.last_oe_order_line_id --= to_number(interface_line_attribute6)
            /*  IN (SELECT ol.line_id
             FROM ont.oe_order_lines_all ol
            WHERE header_id =
                  (SELECT ol2.header_id
                     FROM ont.oe_order_lines_all ol2
                    WHERE ol2.line_id =
                          to_number(interface_line_attribute6)))*/
             IN
             (SELECT ol.line_id
                FROM ont.oe_order_lines_all ol, ont.oe_order_lines_all ol2
               WHERE ol.header_id = ol2.header_id
                 AND ol2.line_id = to_number(interface_line_attribute6))
         AND itmtypes.inventory_item_id = cii.inventory_item_id
         AND itmtypes.item_type = 'PRINTER'
         AND pf_interface_line_context IN ('ORDER ENTRY', 'INTERCOMPANY');
    END IF;
    RETURN(v_retval);
  EXCEPTION
    WHEN OTHERS THEN
      RETURN(NULL);
  END get_cs_installation_date;

  FUNCTION get_om_discount_multiplication(p_order_header_id IN NUMBER)
    RETURN NUMBER IS
    v_retval NUMBER;
  BEGIN
    SELECT trunc((100 - to_number(nvl(oh.attribute15, 0))) / 100, 2)
      INTO v_retval
      FROM ont.oe_order_headers_all oh
     WHERE oh.header_id = p_order_header_id;
    RETURN(v_retval);
  EXCEPTION
    WHEN no_data_found THEN
      RETURN(1);
  END get_om_discount_multiplication;

  FUNCTION get_om_invoice_number(p_oe_line_id IN NUMBER) RETURN VARCHAR2 IS
    v_retval      VARCHAR2(20);
    v_sales_order VARCHAR2(50);
  BEGIN
  
    SELECT oh.order_number
      INTO v_sales_order
      FROM ont.oe_order_lines_all ol, ont.oe_order_headers_all oh
     WHERE oh.header_id = ol.header_id
       AND ol.line_id = p_oe_line_id;
  
    SELECT MIN(rct.trx_number)
      INTO v_retval
      FROM ar.ra_customer_trx_lines_all rctl, ar.ra_customer_trx_all rct
     WHERE rct.customer_trx_id = rctl.customer_trx_id
       AND rctl.interface_line_attribute6 = to_char(p_oe_line_id)
       AND rctl.sales_order = v_sales_order
       AND rctl.interface_line_context IN ('ORDER ENTRY', 'INTERCOMPANY');
    RETURN(v_retval);
  EXCEPTION
    WHEN no_data_found THEN
      RETURN(NULL);
  END get_om_invoice_number;

  FUNCTION get_om_invoice_date(p_oe_line_id IN NUMBER) RETURN DATE IS
    v_retval      DATE;
    v_sales_order VARCHAR2(50);
  BEGIN
  
    SELECT oh.order_number
      INTO v_sales_order
      FROM ont.oe_order_lines_all ol, ont.oe_order_headers_all oh
     WHERE oh.header_id = ol.header_id
       AND ol.line_id = p_oe_line_id;
  
    SELECT MIN(rct.trx_date)
      INTO v_retval
      FROM ar.ra_customer_trx_lines_all rctl, ar.ra_customer_trx_all rct
     WHERE rct.customer_trx_id = rctl.customer_trx_id
       AND rctl.interface_line_attribute6 = to_char(p_oe_line_id)
       AND rctl.sales_order = v_sales_order
       AND rctl.interface_line_context IN ('ORDER ENTRY', 'INTERCOMPANY');
    RETURN(v_retval);
  EXCEPTION
    WHEN no_data_found THEN
      RETURN(NULL);
  END get_om_invoice_date;

  /*
  Function Get_OM_Instal_Date (P_Oe_Line_Id in number) return date
  Is
  v_retVal                         date;
  Begin
    Select min(cii.install_date) Into v_retVal
    From   csi.csi_item_instances cii
    Where  cii.last_oe_order_line_id = P_Oe_Line_Id;
    
    return(v_retVal);
  Exception
    When others then
         return(null);
  End Get_OM_Instal_Date;
  */
  FUNCTION get_is_installdate_relevant(p_oe_line_id           IN NUMBER,
                                       p_customer_trx_line_id IN NUMBER)
    RETURN CHAR IS
    v_is_typerelevant      CHAR(1) := 'N';
    v_is_relevant          CHAR(1) := 'N';
    v_customer_trx_line_id NUMBER;
    v_segment5             VARCHAR2(50);
    v_sales_order          VARCHAR2(30);
  BEGIN
    -- Check If Installation Date Is Relevant In Revenue Recognition
    IF p_customer_trx_line_id IS NOT NULL THEN
      BEGIN
        SELECT MIN(rctt.attribute5), MIN(rctl.customer_trx_line_id)
          INTO v_is_typerelevant, v_customer_trx_line_id
          FROM ar.ra_cust_trx_types_all     rctt,
               ar.ra_customer_trx_lines_all rctl,
               ar.ra_customer_trx_all       rct
         WHERE rctt.cust_trx_type_id = rct.cust_trx_type_id
           AND rct.customer_trx_id = rctl.customer_trx_id
           AND rctl.customer_trx_line_id = p_customer_trx_line_id;
      EXCEPTION
        WHEN OTHERS THEN
          v_is_typerelevant      := 'N';
          v_customer_trx_line_id := NULL;
      END;
    
    ELSE
      BEGIN
        SELECT oh.order_number
          INTO v_sales_order
          FROM ont.oe_order_lines_all ol, ont.oe_order_headers_all oh
         WHERE oh.header_id = ol.header_id
           AND ol.line_id = p_oe_line_id;
        SELECT MIN(rctt.attribute5), MIN(rctl.customer_trx_line_id)
          INTO v_is_typerelevant, v_customer_trx_line_id
          FROM ar.ra_cust_trx_types_all     rctt,
               ar.ra_customer_trx_lines_all rctl,
               ar.ra_customer_trx_all       rct
         WHERE rctt.cust_trx_type_id = rct.cust_trx_type_id
           AND rct.customer_trx_id = rctl.customer_trx_id
           AND rctl.interface_line_attribute6 = to_char(p_oe_line_id)
           AND rctl.sales_order = v_sales_order
           AND rctl.interface_line_context IN
               ('ORDER ENTRY', 'INTERCOMPANY');
      EXCEPTION
        WHEN OTHERS THEN
          v_is_typerelevant      := 'N';
          v_customer_trx_line_id := NULL;
      END;
    END IF;
    -- Only If Relevant Check If Relevant Through OM Line
    IF v_is_typerelevant = 'Y' THEN
      BEGIN
        SELECT MAX(gcc.segment5)
          INTO v_segment5
          FROM ar.ra_cust_trx_line_gl_dist_all rclg,
               gl.gl_code_combinations         gcc
         WHERE gcc.code_combination_id = rclg.code_combination_id
           AND rclg.account_class = 'REV'
           AND rclg.customer_trx_line_id = v_customer_trx_line_id;
      EXCEPTION
        WHEN OTHERS THEN
          v_segment5 := NULL;
      END;
      IF v_segment5 BETWEEN '100' AND '199' OR v_segment5 = '820' THEN
        v_is_relevant := 'Y';
      END IF;
    END IF;
    RETURN(v_is_relevant);
  EXCEPTION
    WHEN no_data_found THEN
      RETURN(NULL);
  END get_is_installdate_relevant;

  FUNCTION get_om_range_date(p_oe_line_id IN NUMBER) RETURN VARCHAR2 IS
    v_invoice_to_org_id  NUMBER;
    v_shipped_qty        NUMBER;
    v_exp_ship_date      DATE;
    v_direct_indirect    VARCHAR2(10);
    v_partyid            NUMBER;
    v_sales_channel_code VARCHAR2(30);
    v_schedule_ship_date DATE;
    v_invoice_date       DATE;
    v_installdate        DATE;
    v_retval             VARCHAR2(8);
  BEGIN
    -- Get Bill To Customer
    SELECT ol.invoice_to_org_id,
           ol.shipped_quantity,
           ol.schedule_ship_date,
           (CASE
             WHEN oh.context LIKE 'Standard Order%' OR
                  oh.context LIKE 'Trade In Order%' THEN
              to_date(oh.attribute1, 'MON-YYYY')
             ELSE
              NULL
           END), -- Expected Shipping Month
           (CASE
             WHEN (oh.context LIKE 'Standard Order%' OR
                  oh.context LIKE 'Trade In Order%') AND
                  oh.attribute7 LIKE 'Direct%' THEN
              'DIRECT'
             WHEN (oh.context LIKE 'Standard Order%' OR
                  oh.context LIKE 'Trade In Order%') AND
                  oh.attribute7 LIKE 'Indirect%' THEN
              'INDIRECT'
             ELSE
              NULL
           END) -- direct/indirect Deal 
      INTO v_invoice_to_org_id,
           v_shipped_qty,
           v_schedule_ship_date,
           v_exp_ship_date,
           v_direct_indirect
      FROM ont.oe_order_lines_all ol, ont.oe_order_headers_all oh
     WHERE oh.header_id = ol.header_id
       AND ol.line_id = p_oe_line_id;
    -- Get Customer Direct OR Indirect
    SELECT hzps_bill_to.party_id
      INTO v_partyid
      FROM ar.hz_cust_site_uses_all  hzusg_bill_to,
           ar.hz_cust_acct_sites_all hzcas_bill_to,
           ar.hz_party_sites         hzps_bill_to
     WHERE hzusg_bill_to.site_use_id = v_invoice_to_org_id
       AND hzusg_bill_to.cust_acct_site_id =
           hzcas_bill_to.cust_acct_site_id
       AND hzcas_bill_to.party_site_id = hzps_bill_to.party_site_id;
    SELECT MAX(ca.sales_channel_code)
      INTO v_sales_channel_code
      FROM ar.hz_cust_accounts ca
     WHERE ca.sales_channel_code IS NOT NULL
       AND ca.party_id = v_partyid;
    -- Set The Range Date
    IF nvl(v_direct_indirect, v_sales_channel_code) = 'INDIRECT' THEN
      v_invoice_date := get_om_invoice_date(p_oe_line_id);
      v_retval       := to_char(nvl(v_invoice_date,
                                    nvl(v_exp_ship_date,
                                        v_schedule_ship_date)),
                                'YYYYMMDD');
    ELSIF nvl(v_direct_indirect, v_sales_channel_code) = 'DIRECT' THEN
      v_installdate := get_cs_installation_date('ORDER ENTRY',
                                                to_number(p_oe_line_id),
                                                'Y');
      v_retval      := to_char(nvl(v_installdate,
                                   nvl(v_exp_ship_date, v_schedule_ship_date)),
                               'YYYYMMDD');
      /*
      Elsif nvl(v_direct_indirect, v_sales_channel_code) = 'DIRECT' and nvl(v_shipped_qty, 0) > 0 then
         v_retVal := to_char(nvl(v_exp_ship_date, v_schedule_ship_date), 'YYYYMMDD');
      Elsif nvl(v_direct_indirect, v_sales_channel_code) = 'DIRECT' and nvl(v_shipped_qty, 0) = 0 then
         v_retVal := to_char(nvl(Get_CS_Installation_date('ORDER ENTRY', P_OE_Line_id), v_schedule_ship_date), 'YYYYMMDD');
      */
    ELSE
      v_retval := to_char(v_schedule_ship_date, 'YYYYMMDD');
    END IF;
    RETURN(v_retval);
  EXCEPTION
    WHEN OTHERS THEN
      RETURN(NULL);
  END get_om_range_date;

  FUNCTION get_ar_range_date(p_cust_trx_line_gl_dist_id IN NUMBER)
    RETURN VARCHAR2 IS
    v_oe_line_id           VARCHAR2(20);
    v_gl_date              DATE;
    v_installdate          DATE;
    v_invoice_to_org_id    NUMBER;
    v_exp_ship_date        DATE;
    v_direct_indirect      VARCHAR2(10);
    v_partyid              NUMBER;
    v_sales_channel_code   VARCHAR2(30);
    v_retval               VARCHAR2(8);
    v_customer_trx_line_id NUMBER;
  BEGIN
    SELECT rctl.interface_line_attribute6,
           rclg.gl_date,
           rctl.customer_trx_line_id
      INTO v_oe_line_id, v_gl_date, v_customer_trx_line_id
      FROM ar.ra_cust_trx_line_gl_dist_all rclg,
           ar.ra_customer_trx_lines_all    rctl
     WHERE rctl.customer_trx_line_id = rclg.customer_trx_line_id
       AND rclg.cust_trx_line_gl_dist_id = p_cust_trx_line_gl_dist_id;
  
    IF get_is_installdate_relevant(to_number(v_oe_line_id),
                                   v_customer_trx_line_id) = 'Y' THEN
      -- Get Bill To Customer
      BEGIN
        SELECT ol.invoice_to_org_id,
               (CASE
                 WHEN oh.context LIKE 'Standard Order%' OR
                      oh.context LIKE 'Trade In Order%' THEN
                  to_date(oh.attribute1, 'MON-YYYY')
                 ELSE
                  NULL
               END), -- Expected Shipping Month
               (CASE
                 WHEN (oh.context LIKE 'Standard Order%' OR
                      oh.context LIKE 'Trade In Order%') AND
                      oh.attribute7 LIKE 'Direct%' THEN
                  'DIRECT'
                 WHEN (oh.context LIKE 'Standard Order%' OR
                      oh.context LIKE 'Trade In Order%') AND
                      oh.attribute7 LIKE 'Indirect%' THEN
                  'INDIRECT'
                 ELSE
                  NULL
               END) -- direct/indirect Deal 
          INTO v_invoice_to_org_id, v_exp_ship_date, v_direct_indirect
          FROM ont.oe_order_lines_all ol, ont.oe_order_headers_all oh
         WHERE oh.header_id = ol.header_id
           AND ol.line_id = to_number(v_oe_line_id);
        -- Get Customer Direct OR Indirect
        SELECT hzps_bill_to.party_id
          INTO v_partyid
          FROM ar.hz_cust_site_uses_all  hzusg_bill_to,
               ar.hz_cust_acct_sites_all hzcas_bill_to,
               ar.hz_party_sites         hzps_bill_to
         WHERE hzusg_bill_to.site_use_id = v_invoice_to_org_id
           AND hzusg_bill_to.cust_acct_site_id =
               hzcas_bill_to.cust_acct_site_id
           AND hzcas_bill_to.party_site_id = hzps_bill_to.party_site_id;
        SELECT MAX(ca.sales_channel_code)
          INTO v_sales_channel_code
          FROM ar.hz_cust_accounts ca
         WHERE ca.sales_channel_code IS NOT NULL
           AND ca.party_id = v_partyid;
      EXCEPTION
        WHEN OTHERS THEN
          v_exp_ship_date   := NULL;
          v_direct_indirect := NULL;
      END;
    
      -- Set The Range Date
      IF nvl(v_direct_indirect, v_sales_channel_code) = 'INDIRECT' THEN
        v_retval := to_char(v_gl_date, 'YYYYMMDD');
      ELSE
        v_installdate := get_cs_installation_date('ORDER ENTRY',
                                                  to_number(v_oe_line_id),
                                                  'Y');
        v_retval      := to_char(nvl(v_exp_ship_date,
                                     nvl(v_installdate, v_gl_date)),
                                 'YYYYMMDD');
      END IF;
    ELSE
      v_retval := to_char(v_gl_date, 'YYYYMMDD');
    END IF;
    RETURN(v_retval);
  EXCEPTION
    WHEN OTHERS THEN
      RETURN(NULL);
  END get_ar_range_date;

  FUNCTION get_so_sales_channel(p_customer_trx_line_id IN NUMBER)
    RETURN VARCHAR2 IS
    v_oe_line_id NUMBER;
    v_result     VARCHAR2(50);
  BEGIN
  
    SELECT rctl.interface_line_attribute6
      INTO v_oe_line_id
      FROM ar.ra_customer_trx_lines_all rctl
     WHERE rctl.customer_trx_line_id = p_customer_trx_line_id
       AND rctl.interface_line_context IN ('ORDER ENTRY', 'INTERCOMPANY');
  
    SELECT (CASE
             WHEN (oh.context LIKE 'Standard Order%' OR
                  oh.context LIKE 'Trade In Order%') AND
                  oh.attribute7 LIKE 'Direct%' THEN
              'DIRECT'
             WHEN (oh.context LIKE 'Standard Order%' OR
                  oh.context LIKE 'Trade In Order%') AND
                  oh.attribute7 LIKE 'Indirect%' THEN
              'INDIRECT'
             ELSE
              NULL
           END)
      INTO v_result
      FROM ont.oe_order_lines_all ol, ont.oe_order_headers_all oh
     WHERE oh.header_id = ol.header_id
       AND ol.line_id = v_oe_line_id;
    RETURN(v_result);
  EXCEPTION
    WHEN OTHERS THEN
      RETURN(NULL);
  END get_so_sales_channel;

  FUNCTION get_so_typecontext(p_customer_trx_line_id IN NUMBER)
    RETURN VARCHAR2 IS
    v_oe_line_id NUMBER;
    v_result     VARCHAR2(50);
  BEGIN
  
    SELECT rctl.interface_line_attribute6
      INTO v_oe_line_id
      FROM ar.ra_customer_trx_lines_all rctl
     WHERE rctl.customer_trx_line_id = p_customer_trx_line_id
       AND rctl.interface_line_context IN ('ORDER ENTRY', 'INTERCOMPANY');
  
    SELECT oh.context
      INTO v_result
      FROM ont.oe_order_lines_all ol, ont.oe_order_headers_all oh
     WHERE oh.header_id = ol.header_id
       AND ol.line_id = v_oe_line_id;
    RETURN(v_result);
  EXCEPTION
    WHEN OTHERS THEN
      RETURN(NULL);
  END get_so_typecontext;

  --------------------------------------------------------------------------
  -- get_cs_instance_type
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  18.2.13   yuval tal       performance : change select in proc 

  FUNCTION get_cs_instance_type(p_oe_line_id IN NUMBER) RETURN VARCHAR2 IS
    v_result VARCHAR2(50);
  BEGIN
    SELECT MAX(cii.instance_type_code)
      INTO v_result
      FROM csi.csi_item_instances cii
     WHERE cii.last_oe_order_line_id IN
           (SELECT ol.line_id
              FROM ont.oe_order_lines_all ol, ont.oe_order_lines_all ol2
             WHERE ol.header_id = ol2.header_id
               AND ol2.line_id = p_oe_line_id);
    /* IN
    (SELECT ol.line_id
       FROM ont.oe_order_lines_all ol
      WHERE header_id =
            (SELECT ol2.header_id
               FROM ont.oe_order_lines_all ol2
              WHERE ol2.line_id = p_oe_line_id));*/
    RETURN(v_result);
  EXCEPTION
    WHEN OTHERS THEN
      RETURN(NULL);
  END get_cs_instance_type;

END xxobjt_utils;
/
