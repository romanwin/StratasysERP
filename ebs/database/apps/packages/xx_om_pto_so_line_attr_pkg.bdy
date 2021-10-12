CREATE OR REPLACE PACKAGE BODY xx_om_pto_so_line_attr_pkg IS
  --------------------------------------------------------------------
  --  name:            XX_OM_PTO_SO_LINE_ATTR_PKG
  --  create by:       Gary Altman
  --  Revision:        1.0
  --  creation date:   25.08.2014
  --------------------------------------------------------------------
  --  purpose :        CHG0032648 - PTO definition form
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   25.08.2014    Gary Altman     CHG0032648 - initial version
  --  1.1   04/05/2015    Dalit A. Raviv  CHG0034234 - Update PTO Validation Setup
  --  1.1   04/05/2015    Dalit A. Raviv  CHG0034234 - Update PTO Validation Setup
  --                                      add: get_max_materials_qty, get_pto_parent_category, get_bdl_sc_dates
  --                                      Modify: check_pto_setup_fp add 2 validations
  -- 1.2   28.01.16       yuval atl       CHG0036068 - modify get_cresid_resin,check_pto_setup_fp 
  --------------------------------------------------------------------

  --------------------------------------------------------------------
  --  customization code: CHG0032648 - PTO definition form
  --  name:               get_line_id
  --  create by:          Gary Altman
  --  Revision:           1.0
  --  creation date:      26/08/2014
  --  Purpose :           Get printer line id
  --
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   26/08/2014    Gary Altman    initial build
  -----------------------------------------------------------------------
  FUNCTION get_line_id(p_header_id NUMBER,
	           p_model_id  NUMBER) RETURN NUMBER IS
  
    l_line_id NUMBER;
  
    PRAGMA AUTONOMOUS_TRANSACTION;
  
  BEGIN
  
    SELECT oola.line_id
    INTO   l_line_id
    FROM   oe_order_lines_all    oola,
           xxcs_items_printers_v xip
    WHERE  oola.top_model_line_id =
           (SELECT ol.top_model_line_id
	FROM   oe_order_lines_all ol
	WHERE  ol.header_id = p_header_id
	AND    ol.line_id = ol.top_model_line_id
	AND    ol.top_model_line_id = p_model_id)
    AND    oola.inventory_item_id = xip.inventory_item_id
    AND    xip.item_type = 'PRINTER'
    AND    oola.header_id = p_header_id;
  
    COMMIT;
  
    RETURN l_line_id;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;

  --------------------------------------------------------------------
  --  customization code: CHG0032648 - PTO definition form
  --  name:               get_parent_item_id
  --  create by:          Gary Altman
  --  Revision:           1.0
  --  creation date:      26/08/2014
  --  Purpose :           get parent inventory item id
  --
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   26/08/2014    Gary Altman    initial build
  -----------------------------------------------------------------------
  FUNCTION get_parent_item_id(p_header_id NUMBER,
		      p_model_id  NUMBER) RETURN NUMBER IS
  
    l_item_id NUMBER;
  
    PRAGMA AUTONOMOUS_TRANSACTION; -- do not take off - this is must for the trigger to be able to work
  
  BEGIN
  
    SELECT msib.inventory_item_id
    INTO   l_item_id
    FROM   mtl_system_items_b msib,
           fnd_lookup_values  lv,
           oe_order_lines_all ol
    WHERE  1 = 1
    AND    msib.organization_id = 91 -- Master Org
    AND    (msib.pick_components_flag = 'Y' OR
          msib.replenish_to_order_flag = 'Y')
    AND    msib.bom_item_type = lv.lookup_code
    AND    lv.lookup_type = 'BOM_ITEM_TYPE'
    AND    lv.language = 'US'
    AND    lv.meaning IN ('Model', 'Standard')
    AND    ol.ordered_item = msib.segment1
    AND    ol.top_model_line_id = ol.line_id
    AND    ol.top_model_line_id = p_model_id
    AND    ol.header_id = p_header_id;
  
    COMMIT;
  
    RETURN l_item_id;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;

  --------------------------------------------------------------------
  --  customization code: CHG0032648 - PTO definition form
  --  name:               is_Service_Contract_Item
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      22/09/2014
  --  Purpose :           Check if given item is Service Contract
  --
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   22/09/2014    Michal Tzvik    initial build
  -----------------------------------------------------------------------
  FUNCTION is_service_contract_item(p_inventory_item_id NUMBER)
    RETURN VARCHAR2 IS
    l_is_service_contract_item VARCHAR2(1);
  
  BEGIN
  
    SELECT nvl(MAX('Y'), 'N')
    INTO   l_is_service_contract_item
    FROM   mtl_item_categories_v mic_sc,
           mtl_system_items_b    msi
    WHERE  msi.inventory_item_id = p_inventory_item_id
    AND    mic_sc.inventory_item_id = msi.inventory_item_id
    AND    mic_sc.organization_id = msi.organization_id
    AND    msi.organization_id = 91
    AND    mic_sc.category_set_name = 'Activity Analysis'
    AND    mic_sc.segment1 = 'Contracts'
    AND    msi.inventory_item_status_code NOT IN
           ('XX_DISCONT', 'Inactive', 'Obsolete')
    AND    msi.coverage_schedule_id IS NULL
    AND    msi.primary_uom_code != 'EA';
  
    RETURN l_is_service_contract_item;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END is_service_contract_item;

  --------------------------------------------------------------------
  --  customization code: CHG0032648 - PTO definition form
  --  name:               get_resin_credit_amount
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      22/09/2014
  --  Purpose :           Get resin credit amount for oe_order_lines.attribute4.
  --                      Called by trigger XXOE_ORDER_LINES_ALL_BUR_TRG2
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   22/09/2014    Michal Tzvik    initial build
  -- 1.2   28.01.16       yuval atl       CHG0036068 - add 2 parameters p_to_currency_code , p_conversion_date
  -----------------------------------------------------------------------
  FUNCTION get_resin_credit_amount(p_pto_item_id      NUMBER,
		           p_price_list_id    NUMBER,
		           p_to_currency_code VARCHAR2 /*DEFAULT NULL*/,
		           p_conversion_date  DATE /*DEFAULT SYSDATE*/)
    RETURN NUMBER IS
    l_rslt       NUMBER;
    l_price_curr qp_list_headers_all_b.currency_code%TYPE;
  BEGIN
    SELECT resin_credit_amount
    INTO   l_rslt
    FROM   xx_om_pto_so_lines_attributes
    WHERE  pto_item = p_pto_item_id
    AND    price_list = p_price_list_id;
  
    -- convert amount CHG0036068
  
    SELECT h.currency_code
    INTO   l_price_curr
    FROM   qp_list_headers_all_b h
    WHERE  h.list_header_id = p_price_list_id;
  
    -- CHECK different currency CHG0036068
    IF l_price_curr != nvl(p_to_currency_code, l_price_curr) THEN
      l_rslt := round(l_rslt *
	          gl_currency_api.get_closest_rate(x_from_currency   => l_price_curr,
				       x_to_currency     => p_to_currency_code,
				       x_conversion_date => nvl(p_conversion_date,
						        SYSDATE),
				       x_conversion_type => 'Corporate',
				       x_max_roll_days   => 100),
	          2);
    
    END IF;
  
    RETURN l_rslt;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_resin_credit_amount;

  --------------------------------------------------------------------
  --  customization code: CHG0032648 - PTO definition form
  --  name:               get_Maintenance_Start_Date
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      22/09/2014
  --  Purpose :           Get Maintenance Start Date for oe_order_lines.attribute12
  --                      Called by trigger XXOE_ORDER_LINES_ALL_BUR_TRG2
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   22/09/2014    Michal Tzvik    initial build
  -----------------------------------------------------------------------
  FUNCTION get_maintenance_start_date(p_pto_item_id       NUMBER,
			  p_price_list_id     NUMBER,
			  p_inventory_item_id NUMBER)
    RETURN VARCHAR2 IS
    l_rslt VARCHAR2(255);
  BEGIN
    SELECT fnd_date.date_to_canonical(add_months(trunc(SYSDATE),
				 warranty_period))
    INTO   l_rslt
    FROM   xx_om_pto_so_lines_attributes
    WHERE  pto_item = p_pto_item_id
    AND    price_list = p_price_list_id
    AND    service_contract_item = p_inventory_item_id;
  
    RETURN l_rslt;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_maintenance_start_date;

  --------------------------------------------------------------------
  --  customization code: CHG0032648 - PTO definition form
  --  name:               get_bdl_sc_dates
  --  create by:          Dalit A. Raviv
  --  Revision:           1.0
  --  creation date:      12/05/2015
  --  Purpose :           Get BDL_SC Start Date for oe_order_lines.attribute12
  --                      Called by trigger XXOE_ORDER_LINES_ALL_BUR_TRG2
  --                      Get BDL_SC end Date for oe_order_lines.attribute13
  --                      Called by trigger XXOE_ORDER_LINES_ALL_BUR_TRG2
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   12/05/2015    Dalit A. Raviv  initial build
  -----------------------------------------------------------------------
  PROCEDURE get_bdl_sc_dates(p_serial_number     IN VARCHAR2,
		     p_so_line_id        IN NUMBER,
		     p_entity            IN VARCHAR2,
		     p_pto_item_id       IN NUMBER,
		     p_price_list_id     IN NUMBER,
		     p_inventory_item_id IN NUMBER,
		     p_start_date        OUT VARCHAR2,
		     p_end_date          OUT VARCHAR2) IS
  
    l_instance_id       NUMBER;
    l_contract_end_date DATE;
    l_sf_id             VARCHAR2(240);
    -- to ask Moni if this is correct or i need to send the p_pto_item_id
    l_inventory_item_id       NUMBER := p_inventory_item_id;
    l_service_contract_period NUMBER := NULL;
  BEGIN
    -- get start date
    -- to ask Moni if this is correct or i need to send the p_pto_item_id !!!!!!!!!!!
    xxcsi_utils_pkg.get_printer_and_contract_info(p_serial_number     => p_serial_number, -- i v
				  p_so_line_id        => p_so_line_id, -- i n
				  p_entity            => p_entity, /*'TRIGGER',*/ -- i v
				  p_instance_id       => l_instance_id, -- o v
				  p_contract_end_date => l_contract_end_date, -- o d
				  p_sf_id             => l_sf_id, -- o v
				  p_inventory_item_id => l_inventory_item_id); -- i/o n
  
    IF l_instance_id IS NULL AND l_contract_end_date IS NULL AND
       l_sf_id IS NULL AND l_inventory_item_id IS NULL THEN
      p_start_date := NULL;
      p_end_date   := NULL;
    ELSE
      IF nvl(l_contract_end_date, (SYSDATE - 1)) < trunc(SYSDATE) THEN
        p_start_date := fnd_date.date_to_canonical(SYSDATE);
      ELSE
        p_start_date := fnd_date.date_to_canonical((l_contract_end_date + 1));
      END IF;
      -- get end date
      -- get end date from pto setup
      BEGIN
        SELECT service_contract_period
        INTO   l_service_contract_period
        FROM   xx_om_pto_so_lines_attributes
        WHERE  pto_item = p_pto_item_id
        AND    price_list = p_price_list_id
        AND    service_contract_item = p_inventory_item_id;
      
        p_end_date := fnd_date.date_to_canonical(add_months(trunc(l_contract_end_date),
					l_service_contract_period));
      EXCEPTION
        WHEN OTHERS THEN
          p_end_date := NULL;
      END;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      p_start_date := NULL;
      p_end_date   := NULL;
  END get_bdl_sc_dates;

  --------------------------------------------------------------------
  --  customization code: CHG0032648 - PTO definition form
  --  name:               get_Maintenance_End_Date
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      22/09/2014
  --  Purpose :           Get Maintenance End Date for oe_order_lines.attribute13
  --                      Called by trigger XXOE_ORDER_LINES_ALL_BUR_TRG2
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   22/09/2014    Michal Tzvik    initial build
  -----------------------------------------------------------------------
  FUNCTION get_maintenance_end_date(p_pto_item_id       NUMBER,
			p_price_list_id     NUMBER,
			p_inventory_item_id NUMBER)
    RETURN VARCHAR2 IS
    l_rslt VARCHAR2(255);
  BEGIN
    SELECT fnd_date.date_to_canonical(add_months(trunc(SYSDATE),
				 warranty_period +
				 service_contract_period))
    INTO   l_rslt
    FROM   xx_om_pto_so_lines_attributes
    WHERE  pto_item = p_pto_item_id
    AND    price_list = p_price_list_id
    AND    service_contract_item = p_inventory_item_id;
  
    RETURN l_rslt;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_maintenance_end_date;

  --------------------------------------------------------------------
  --  customization code: CHG0032648 - PTO definition form
  --  name:               service_contract_period
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      15/01/2015
  --  Purpose :           Get service contract period from setup table
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   15/01/2015    Michal Tzvik    initial build
  -----------------------------------------------------------------------
  FUNCTION get_service_contract_period(p_pto_item_id       NUMBER,
			   p_price_list_id     NUMBER,
			   p_inventory_item_id NUMBER)
    RETURN VARCHAR2 IS
    l_rslt VARCHAR2(255);
  BEGIN
    SELECT service_contract_period
    INTO   l_rslt
    FROM   xx_om_pto_so_lines_attributes
    WHERE  pto_item = p_pto_item_id
    AND    price_list = p_price_list_id
    AND    service_contract_item = p_inventory_item_id;
  
    RETURN l_rslt;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_service_contract_period;

  --------------------------------------------------------------------
  --  customization code: CHG0034234 - Update PTO Validation Setup
  --  name:               get_max_materials_qty
  --  create by:          Dalit A. Raviv
  --  Revision:           1.0
  --  creation date:      04/05/2015
  --  Purpose :
  --                      Get max material qty from setup table
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   04/05/2015    Dalit A. Raviv  initial build
  -----------------------------------------------------------------------
  FUNCTION get_max_materials_qty(p_pto_item_id       NUMBER,
		         p_price_list_id     NUMBER,
		         p_inventory_item_id NUMBER) RETURN NUMBER IS
  
    l_max_materials_qty NUMBER := 0;
  BEGIN
    SELECT a.max_materials_qty
    INTO   l_max_materials_qty
    FROM   xx_om_pto_so_lines_attributes a
    WHERE  pto_item = p_pto_item_id
    AND    price_list = p_price_list_id
    AND    a.option_class = p_inventory_item_id;
  
    RETURN l_max_materials_qty;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 0;
  END get_max_materials_qty;

  --------------------------------------------------------------------
  --  customization code: CHG0034234 - Update PTO Validation Setup
  --  name:               get_pto_parent_category
  --  create by:          Dalit A. Raviv
  --  Revision:           1.0
  --  creation date:      04/05/2015
  --  Purpose :
  --                      Get pto parent category
  --                      if 'BDL-SC' return Y else N
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   04/05/2015    Dalit A. Raviv  initial build
  -----------------------------------------------------------------------
  FUNCTION get_pto_parent_category(p_line_id IN NUMBER) RETURN VARCHAR2 IS
  
    PRAGMA AUTONOMOUS_TRANSACTION; -- do not take off - this is must for the trigger to be able to work
    l_parent VARCHAR2(10) := 'N';
  BEGIN
    SELECT 'Y'
    INTO   l_parent
    FROM   inv.mtl_categories_b   c,
           mtl_item_categories_v  icat,
           ont.oe_order_lines_all oola
    WHERE  c.category_id = icat.category_id
    AND    c.structure_id = icat.structure_id
    AND    icat.inventory_item_id =
           xx_om_pto_so_line_attr_pkg.get_parent_item_id(oola.header_id,
				          oola.top_model_line_id)
    AND    icat.organization_id = oola.ship_from_org_id
    AND    icat.category_set_name = 'Activity Analysis'
    AND    c.segment1 = 'BDL-SC'
    AND    oola.line_id = p_line_id;
  
    RETURN l_parent;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'N';
  END get_pto_parent_category;

  --------------------------------------------------------------------
  --  customization code: CHG0032648 - PTO definition form
  --  name:               check_pto_setup_fp
  --  create by:          Michal Tzvik
  --  Revision:           1.0
  --  creation date:      18.09.2014
  --  Purpose :           Check if PTO definition exists for given order
  --                      line id. Used by form personalization in Sales Order
  --                      Form in order to avoid Book if there is no valid setup.
  --                      Return null if setup is valid
  --                      else, return Error message.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   18.09.2014    Michal Tzvik    initial build
  --  1.1   04/05/2015    Dalit A. Raviv  CHG0034234 - Update PTO Validation Setup
  -- 1.2    28.1.16       yuval tal       CHG0036068 add 2 parameter to get_resin_credit_amount call , change cursor c_lines
  --                                      check Items for Direct Orders Only
  -----------------------------------------------------------------------
  FUNCTION check_pto_setup_fp(p_header_id NUMBER,
		      p_line_id   NUMBER) RETURN VARCHAR2 IS
  
    CURSOR c_lines(p_header_id NUMBER,
	       p_line_id   NUMBER) IS
      SELECT h.header_id, -- CHG0036068
	 h.ordered_date, -- CHG0036068
	 h.transactional_curr_code, -- CHG0036068
	 h.attribute7, -- CHG0036068
	 ol.line_id,
	 ol.top_model_line_id,
	 ol.line_number,
	 ol.inventory_item_id,
	 ol.price_list_id,
	 ol.ordered_quantity,
	 ol.shipment_number,
	 ol.option_number,
	 ol.item_type_code,
	 ol.attribute14,
	 ol.component_number
      FROM   oe_order_lines_all   ol,
	 oe_order_headers_all h
      WHERE  ol.header_id = h.header_id
      AND    ol.line_id = nvl(p_line_id, ol.line_id)
      AND    ol.header_id = p_header_id
      AND    ol.link_to_line_id IS NOT NULL;
  
    -- CHG0034234 - Update PTO Validation Setup
    CURSOR c_pto_pop(p_header_id IN NUMBER,
	         p_line_id   IN NUMBER) IS
      SELECT lpto.inventory_item_id pto_item,
	 lpto.price_list_id price_list,
	 oola.inventory_item_id option_class,
	 a.max_materials_qty,
	 SUM(lcomp.ordered_quantity) materials_qty
      FROM   ont.oe_order_lines_all        oola,
	 ont.oe_order_lines_all        lpto,
	 ont.oe_order_lines_all        lcomp, -- all componenet for the option class
	 xx_om_pto_so_lines_attributes a -- PTO setup table
      WHERE  oola.item_type_code = 'CLASS'
      AND    oola.top_model_line_id = lpto.line_id
      AND    oola.line_id = lcomp.link_to_line_id
      AND    oola.header_id = p_header_id -- 970186
      AND    a.pto_item = lpto.inventory_item_id
      AND    a.price_list = lpto.price_list_id
      AND    a.option_class = oola.inventory_item_id
      AND    oola.line_id = p_line_id -- 1839216
      GROUP  BY lpto.inventory_item_id,
	    lpto.price_list_id,
	    oola.inventory_item_id,
	    a.max_materials_qty;
  
    l_msg                     VARCHAR2(1000);
    l_pto_item_id             NUMBER;
    l_is_service_contract     VARCHAR2(1);
    l_resin_credit_amount     NUMBER;
    l_maintenance_start_date  VARCHAR2(255);
    l_item_number             VARCHAR2(150);
    l_service_contract_period NUMBER;
  
    pto_def_error EXCEPTION;
    l_direct_order_items NUMBER;
  BEGIN
    l_msg := '';
  
    FOR r_line IN c_lines(p_header_id, p_line_id) LOOP
      BEGIN
        l_pto_item_id := get_parent_item_id(r_line.header_id,
			        r_line.top_model_line_id);
        IF l_pto_item_id IS NULL THEN
          -- 'Failed to get PTO item for line number '||r_line.line_number;
          fnd_message.set_name('XXOBJT', 'XXOM_PTO_VALIDATION_PTO_ITEM');
          fnd_message.set_token(token => 'LINE_NUMBER',
		        VALUE => r_line.line_number);
          l_msg := fnd_message.get;
          RETURN l_msg;
        END IF;
      
        SELECT msi.segment1
        INTO   l_item_number
        FROM   mtl_system_items_b msi
        WHERE  msi.inventory_item_id = r_line.inventory_item_id
        AND    msi.organization_id = 91;
      
        IF l_item_number = 'RESIN CREDIT' THEN
          l_resin_credit_amount := get_resin_credit_amount(p_pto_item_id      => l_pto_item_id,
				           p_price_list_id    => r_line.price_list_id,
				           p_to_currency_code => r_line.transactional_curr_code, -- CHG0036068
				           p_conversion_date  => r_line.ordered_date); -- CHG0036068
          IF l_resin_credit_amount IS NULL THEN
	RAISE pto_def_error;
          END IF;
        END IF;
      
        l_is_service_contract := is_service_contract_item(r_line.inventory_item_id);
        IF l_is_service_contract = 'Y' THEN
          l_maintenance_start_date := get_maintenance_start_date(p_pto_item_id       => l_pto_item_id,
					     p_price_list_id     => r_line.price_list_id,
					     p_inventory_item_id => r_line.inventory_item_id);
          IF l_maintenance_start_date IS NULL THEN
	RAISE pto_def_error;
          END IF;
        
          l_service_contract_period := get_service_contract_period(p_pto_item_id       => l_pto_item_id,
					       p_price_list_id     => r_line.price_list_id,
					       p_inventory_item_id => r_line.inventory_item_id);
          IF nvl(l_service_contract_period, 0) != r_line.ordered_quantity THEN
	RAISE pto_def_error;
          END IF;
        END IF;
      EXCEPTION
        WHEN pto_def_error THEN
          -- 'No data found. Order lines entries do not match PTO setup definitions. (Line number: '||
          --       r_line.line_number||'.'||r_line.shipment_number||'.'||r_line.option_number||')';
          fnd_message.set_name('XXOBJT', 'XXOM_PTO_VALIDATION_ERR');
          fnd_message.set_token(token => 'LINE_NUMBER',
		        VALUE => r_line.line_number);
          fnd_message.set_token(token => 'SHIPMENT_NUMBER',
		        VALUE => r_line.shipment_number);
          fnd_message.set_token(token => 'OPTION_NUMBER',
		        VALUE => r_line.option_number);
          l_msg := fnd_message.get;
          RETURN l_msg;
      END;
      -- 1.1 04/05/2015 Dalit A. Raviv CHG0034234 - Update PTO Validation Setup
      -- validation for max qty
      IF r_line.item_type_code = 'CLASS' THEN
        FOR r_pop IN c_pto_pop(r_line.header_id, r_line.line_id) LOOP
          IF r_pop.materials_qty != r_pop.max_materials_qty THEN
	-- 'The selected quantity of Materials exceeds the limit defined to this bundle'
	-- The selected quantity of Materials doesn't match bundle definitions
	fnd_message.set_name('XXOBJT', 'XXOM_PTO_VALIDATION_MAXQTY');
	l_msg := fnd_message.get;
	RETURN l_msg;
          END IF;
        END LOOP;
      END IF;
      -- validation for serial number
      IF l_is_service_contract = 'Y' THEN
        IF get_pto_parent_category(r_line.line_id) = 'Y' THEN
          IF r_line.attribute14 IS NULL THEN
	-- serial Number DFF
	-- Line &LINE_NUMBER||'.'||&SHIPMENT_NUMBER||'.'||&OPTION_NUMBER||'.'||&COMPONENT_NUMBER has not a Serial number.
	fnd_message.set_name('XXOBJT',
		         'XXOM_PTO_VALIDATION_SERIAL_NUM');
	fnd_message.set_token(token => 'LINE_NUMBER',
		          VALUE => r_line.line_number);
	fnd_message.set_token(token => 'SHIPMENT_NUMBER',
		          VALUE => r_line.shipment_number);
	fnd_message.set_token(token => 'OPTION_NUMBER',
		          VALUE => r_line.option_number);
	fnd_message.set_token(token => 'COMPONENT_NUMBER',
		          VALUE => r_line.component_number);
	l_msg := fnd_message.get;
	RETURN l_msg;
          END IF;
        END IF;
      END IF;
      -- end CHG0034234
    
      -- check Items for Direct Orders Only
      --CHG0036068
      l_direct_order_items := 0;
    
      BEGIN
        SELECT 1
        INTO   l_direct_order_items
        FROM   fnd_lookup_values flv
        WHERE  flv.lookup_type = 'XXOE_DIRECT_ORDER_ITEMS'
        AND    flv.lookup_code =
	   xxinv_utils_pkg.get_item_segment(r_line.inventory_item_id,
				 xxinv_utils_pkg.get_master_organization_id)
        AND    flv.language = userenv('LANG')
        AND    nvl(flv.enabled_flag, 'Y') = 'Y'
        AND    trunc(SYSDATE) BETWEEN
	   nvl(flv.start_date_active, SYSDATE - 1) AND
	   nvl(flv.end_date_active, SYSDATE + 1)
        AND    rownum = 1;
      
      EXCEPTION
      
        WHEN no_data_found THEN
          NULL;
      END;
    
      IF l_direct_order_items = 1 AND r_line.attribute7 IS NULL THEN
      
        RETURN 'Please fill Direct/Indirect deal information in the order header DFF';
      
      ELSIF l_direct_order_items = 1 AND
	nvl(r_line.attribute7, 'Indirect deal') = 'Indirect deal' THEN
      
        fnd_message.set_name('XXOBJT', 'XXOM_PTO_ITEMS_DIRECT_ORD_ONLY');
        fnd_message.set_token(token => 'LINE_NUMBER',
		      VALUE => r_line.line_number);
        fnd_message.set_token(token => 'SHIPMENT_NUMBER',
		      VALUE => r_line.shipment_number);
        fnd_message.set_token(token => 'OPTION_NUMBER',
		      VALUE => r_line.option_number);
        fnd_message.set_token(token => 'COMPONENT_NUMBER',
		      VALUE => r_line.component_number);
        l_msg := fnd_message.get;
      
        /* l_msg := 'Item in line ' || r_line.line_number || '.' ||
        r_line.shipment_number || '.' || r_line.option_number || '.' ||
        r_line.component_number ||
        ' is sold only to direct customers. Please fill the Direct/Indirect information in the Order Header DFF or remove this line from the order';*/
        RETURN l_msg;
      END IF;
    
    -- END IF;
    
    --end CHG0036068
    END LOOP;
  
    RETURN NULL;
  END check_pto_setup_fp;

END xx_om_pto_so_line_attr_pkg;
/
