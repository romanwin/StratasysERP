CREATE OR REPLACE PACKAGE BODY xxoe_dflt_rules_pkg
-- ----------------------------------------------------------------------------------------
--  Name        : xxoe_dflt_rules_pkg
--  Created By  : mmazanet
--
--  Purpose     : Package to hold defaulting rules for OM.
--
--  Ver Date        Name          Description
-- -----------------------------------------------------------------------------------------
--  1.0 12/01/2015  mmazanet      CHG0033020. Initial Creation
--  1.1 30/03/2015  Michal Tzvik  CHG0034935 - Add logic for eCommerce orders.
--                                             Modify function default_us_warehouse
--  1.2 11/09/2015  Diptasurjya   CHG0036423 - New funtion added for shipping method defaulting
--                  Chatterjee                 for dangerous items - ship_method_default_rule
--  1.3 13/08/2015  Michal Tzvik  CHG0035224 - New fuctions: default_political_warehouse, default_political_subinventory
--  1.4 03/09/2015  Michal Tzvik  CHG0036321 - change logic in function default_us_warehouse
--  1.5 22-NOV-2015 Sandeep Akula CHG0037039 - Modified Function ship_method_default_rule
--                                           - Added New Function freight_terms_default_rule
--  1.5 03/12/2015  Diptasurjya   CHG0037039 - Modify freight_terms_default_rule to default for non material orders only
--                                           - Added new function salesperson_default_rule
--  1.6 22-Mar-2016 Lingaraj      CHG0037870 - Modify defaulting rules to satisfy changed Dangerous Goods definitions
--  1.7 15-Apr-2016 Lingaraj      CHG0038326 - UME Warehouse defaulting error fix
--  1.8 05-Apr-2017 Rimpi         CHG0040568: Default  a value in Intermediate ship to field at order header line in order to create separate deliveries for DG items
--  1.9  22.10.17   Yuval tal     CHG0040750 add default_ou_functional_currency
-- -----------------------------------------------------------------------------------------
 AS

  g_log              VARCHAR2(1) := fnd_profile.value('AFLOG_ENABLED');
  g_log_module       VARCHAR2(100) := fnd_profile.value('AFLOG_MODULE');
  g_request_id       NUMBER := fnd_profile.value('CONC_REQUEST_ID');
  g_log_program_unit VARCHAR2(100);

  -- Michal Tzvik
  g_line_id NUMBER;
  g_ind     NUMBER := 0;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: Write to request log if 'FND: Debug Log Enabled' is set to Yes
  -- ---------------------------------------------------------------------------------------------
  -- Ver  Date        Name        Description
  -- 1.0  12/12/2014  MMAZANET    Initial Creation for CHG003877.
  -- ---------------------------------------------------------------------------------------------
  PROCEDURE write_log(p_msg VARCHAR2) IS
  BEGIN
    g_ind := g_ind + 1; -- Michal Tzvik
    IF g_log = 'Y' AND 'xxoe.order_default.xxoe_dflt_rules_pkg.' ||
       g_log_program_unit LIKE lower(g_log_module) || '%' THEN
      fnd_log.string(log_level => fnd_log.level_unexpected, --
	         module    => 'xxoe.order_default.xxoe_dflt_rules_pkg.' ||
		          g_log_program_unit, --
	         message   => g_line_id || '.' || g_ind || ')' || p_msg);
    END IF;
  END write_log;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Get on-hand quantities from standard Oracle API
  -- ---------------------------------------------------------------------------------------------
  -- Ver  Date        Name        Description
  -- 1.0  12/12/2014  MMAZANET    Initial Creation for CHG003877.
  -- 1.1  07.09.2015  Michal Tzvik CHG0036321 - Add parameter p_subinventory_code
  -- ---------------------------------------------------------------------------------------------
  PROCEDURE get_qty_available(p_inventory_item_id         IN NUMBER,
		      p_org_id                    IN NUMBER,
		      p_subinventory_code         IN VARCHAR2, -- CHG0036321 07.09.2015  Michal Tzvik
		      x_qty_available_to_transact OUT NUMBER) IS
    x_return_status VARCHAR2(1);
    x_msg_data      VARCHAR2(4000);
    x_msg_count     NUMBER;
    x_qoh           NUMBER;
    x_rqoh          NUMBER;
    x_qr            NUMBER;
    x_qs            NUMBER;
    x_att           NUMBER;
    x_atr           NUMBER;
    x_sqoh          NUMBER;
    x_srqoh         NUMBER;
    x_sqr           NUMBER;
    x_sqs           NUMBER;
    x_satt          NUMBER;
    x_sqtr          NUMBER;
  
    l_is_revision_control      NUMBER;
    l_is_lot_control           NUMBER;
    l_is_serial_control        NUMBER;
    l_is_revision_control_bool BOOLEAN;
    l_is_lot_control_bool      BOOLEAN;
    l_is_serial_control_bool   BOOLEAN;
  BEGIN
    write_log('START GET_QTY_AVAILABLE');
    --  write_log('p_inventory_item_id: ' || p_inventory_item_id);
    --  write_log('p_org_id:            ' || p_org_id);
    --  write_log('p_subinventory_code:            ' || p_org_id);
  
    SELECT decode(nvl(lot_control_code, 1), 2, 1, 0) lot_control_code,
           decode(nvl(serial_number_control_code, 1), 1, 0, 1) serial_number_control_code,
           decode(nvl(revision_qty_control_code, 1), 2, 1, 0) revision_control_code
    INTO   l_is_lot_control,
           l_is_serial_control,
           l_is_revision_control
    FROM   mtl_system_items_b
    WHERE  inventory_item_id = p_inventory_item_id
    AND    organization_id = 91;
  
    l_is_revision_control_bool := sys.diutil.int_to_bool(l_is_revision_control);
    l_is_lot_control_bool      := sys.diutil.int_to_bool(l_is_lot_control);
    l_is_serial_control_bool   := sys.diutil.int_to_bool(l_is_serial_control);
  
    inv_quantity_tree_pub.clear_quantity_cache;
    inv_quantity_tree_pub.query_quantities(p_api_version_number  => 1.0, --
			       x_return_status       => x_return_status, --
			       x_msg_count           => x_msg_count, --
			       x_msg_data            => x_msg_data, --
			       p_organization_id     => p_org_id, --
			       p_inventory_item_id   => p_inventory_item_id, --
			       p_tree_mode           => 1, --
			       p_is_revision_control => FALSE, -- l_is_revision_control_bool, -- CHG0036321 07.09.2015  Michal Tzvik: fix bug: If the parameter p_is_revision_control=TRUE
			       ------------------------------------------------------- then it will return 0 for lot control item on-hand/available quantity (see readme of PATCH 17452665)
			       p_is_lot_control => FALSE, -- l_is_lot_control_bool, -- CHG0036321 07.09.2015  Michal Tzvik: fix bug: If the parameter p_is_lot_control=TRUE
			       ------------------------------------------------------- then it will return 0 for lot control item on-hand/available quantity (see readme of PATCH 17452665)
			       p_is_serial_control => l_is_serial_control_bool, --
			       p_grade_code        => NULL, --
			       p_revision          => NULL, --
			       p_lot_number        => NULL, --
			       p_subinventory_code => p_subinventory_code, -- CHG0036321 07.09.2015  Michal Tzvik
			       p_locator_id        => NULL, --
			       x_qoh               => x_qoh,
			       x_rqoh              => x_rqoh,
			       x_qr                => x_qr,
			       x_qs                => x_qs,
			       x_att               => x_att,
			       x_atr               => x_atr,
			       x_sqoh              => x_sqoh,
			       x_srqoh             => x_srqoh,
			       x_sqr               => x_sqr,
			       x_sqs               => x_sqs,
			       x_satt              => x_satt,
			       x_satr              => x_sqtr);
  
    write_log('x_return_status from query_quantities: ' || x_return_status);
  
    IF x_return_status <> 'S' THEN
      x_qty_available_to_transact := 0;
    
      IF x_msg_count > 1 THEN
        FOR i IN 1 .. x_msg_count LOOP
          write_log(substr(i || '. ' || substr(fnd_msg_pub.get(p_encoded => fnd_api.g_false),
			           1,
			           255),
		   1,
		   4000));
        END LOOP;
      END IF;
    ELSE
      x_qty_available_to_transact := x_att;
    END IF;
  
    write_log('p_inventory_item_id: ' || p_inventory_item_id ||
	  ', p_org_id: ' || p_org_id || ', p_subinventory_code: ' ||
	  p_subinventory_code || ', x_qty_available_to_transact: ' ||
	  x_qty_available_to_transact);
  EXCEPTION
    WHEN OTHERS THEN
      write_log('Exception block for GET_QTY_AVAILABLE: ' ||
	    dbms_utility.format_error_stack);
      x_qty_available_to_transact := 0;
  END get_qty_available;

  -- ----------------------------------------------------------------------------------------
  --  Purpose : Defaults the ship _from_org_id on the order line depending on the warehouse
  --            set at the header level (primary org).  If the warehouse has a secondary org
  --            defined (attribute3 on mtl_parameters), the code will check which org (primary
  --            or secondary) has more inventory.  The warehouse will then default to that org.
  --            If no secondary org is defined, it will default to the warehouse on the order header.
  --
  --            In addition, this sets the ship set on the line.  By default, Oracle sets all the
  --            lines' ship sets to 1.  If we have different ship_from_org_ids on the lines, but
  --            the ship sets are the same, the ship_from_org_ids all get set back to the first
  --            line's ship_from_org_id, which essentially defeats the purposes of defaulting the
  --            ship_from_org_id.  To get around this, we need to set a unique ship set for each
  --            unique ship_from_org_id on the order.  If we had the following scenario, the
  --            code would set the ship sets as follows
  --
  --            Line No.   Item        Ship From Org   Ship Set
  --            --------   ----------- -------------   --------
  --                   1   OBJ-13000   UTP             1
  --                   2   350-80107   USE             2
  --                   3   OBJ-13070   UTP             1
  --
  --            If we did not save line 2's ship set to '2', all Ship From Org's would be set to
  --            UTP when we saved.  However, since we've put it on a different ship set, it will
  --            preserve the org.  Also, notice that since lines 1 and 3 are both UTP, they have
  --            the same ship set.  The code below accomplishes this.
  --
  --  Ver Date        Name          Description
  -- -----------------------------------------------------------------------------------------
  --  1.0 12/01/2015  mmazanet      CHG0033020. Initial Creation
  --  1.1 30/03/2015  Michal Tzvik  CHG0034935 - Add logic for eCommerce orders
  --  1.2 13/08/2015  Michal Tzvik  CHG0035224 - remove logic for ship set (not needed after applying a new patch from Oracle)
  --  1.3 03/09/2015  Michal Tzvik  CHG0036321 - Fix for OM Warehouse defaulting rule: compare qty of specific subinventory in the WH
  --                                             instead of checking qty in all subinventories of the WH.
  --  1.4 22-Mar-2016 Lingaraj      CHG0037870 - Modify defaulting rules to satisfy changed Dangerous Goods definitions
  --  1.5 15-Apr-2016 Lingaraj      CHG0038326 - UME Warehouse defaulting error fix
  -- -----------------------------------------------------------------------------------------
  FUNCTION default_us_warehouse(p_database_object_name IN VARCHAR2,
		        p_attribute_code       IN VARCHAR2)
    RETURN NUMBER IS
    l_line_rec   oe_ak_order_lines_v%ROWTYPE;
    l_header_rec oe_ak_order_headers_v%ROWTYPE;
    l_wh_org_id  NUMBER;
  
    l_primary_org_id   NUMBER;
    l_secondary_org_id NUMBER;
    l_primary_qty      NUMBER := 0;
    l_secondary_qty    NUMBER := 0;
  
    l_test_count              NUMBER := 0;
    l_max_ship_set            oe_ak_order_lines_v.ship_set%TYPE;
    l_is_dangerous_goods_flag VARCHAR2(1) := 'N';
    l_assign_ship_set_flag    VARCHAR2(1) := 'Y';
  
    e_skip EXCEPTION;
  
    -- Find all lines on the order
    CURSOR c_lines(p_header_id NUMBER) IS
      SELECT oaolv.line_id,
	 oaolv.ship_set_id,
	 oaolv.ship_from_org_id,
	 os.set_name ship_set,
	 -- Get the MAX ship set name that is a number (they all should be numbers)
	 MAX(nvl(regexp_replace(os.set_name, '[^[:digit:]]', ''), 0)) over(PARTITION BY oaolv.header_id) max_ship_set
      FROM   oe_ak_order_lines_v oaolv,
	 oe_sets             os
      WHERE  oaolv.header_id = p_header_id
      AND    oaolv.ship_set_id = os.set_id(+)
      AND    nvl(oaolv.cancelled_flag, 'N') = 'N' -- CHG0034935 Michal Tzvik 14.04.2015
      AND    'SHIP_SET' = os.set_type(+);
  
    -- CHG0034935
    l_default_wh_for_order_src NUMBER := fnd_profile.value('XXOM_DEFAULT_WH_FOR_ORDER_SRC');
    l_category_segment         VARCHAR2(240);
    l_mtl_item_rec             mtl_system_items_b%ROWTYPE;
    l_polyjet_organization_id  NUMBER;
    l_fdm_organization_id      NUMBER;
    l_utp_qty                  NUMBER;
    l_use_qty                  NUMBER;
  
    --CHG0036321
    l_primary_subinventory   VARCHAR2(15);
    l_secondary_subinventory VARCHAR2(15);
  BEGIN
    g_log_program_unit        := 'default_us_warehouse';
    l_line_rec                := ont_line_def_hdlr.g_record;
    l_header_rec              := ont_header_def_hdlr.g_record;
    l_primary_org_id          := l_header_rec.ship_from_org_id;
    l_is_dangerous_goods_flag := 'N';
    l_assign_ship_set_flag    := 'Y';
  
    write_log('*** BEGIN DEFAULT_US_WAREHOUSE ***');
    write_log('l_primary_org_id: ' || l_primary_org_id);
    write_log('l_line_rec.inventory_item_id: ' ||
	  l_line_rec.inventory_item_id);
  
    -- All dangerous & Restricted goods must be shipped from a profile set warehouse.
    IF nvl(xxinv_utils_pkg.is_item_hazard_restricted(l_line_rec.inventory_item_id),
           'N') = 'Y' THEN
      /*CHG0037870*/
      write_log('Dangerous goods item');
      l_wh_org_id := nvl(fnd_profile.value('XXINV_DANGEROUS_GOODS_WH'),
		 l_primary_org_id);
    ELSE
    
      BEGIN
        -- Check for secondary org
        SELECT to_number(attribute3),
	   attribute4 -- CHG0036321
        INTO   l_secondary_org_id,
	   l_primary_subinventory -- CHG0036321
        FROM   mtl_parameters
        WHERE  organization_id = l_primary_org_id;
      
        write_log('l_primary_subinventory: ' || l_primary_subinventory);
        write_log('l_secondary_org_id: ' || l_secondary_org_id);
      
      EXCEPTION
        -- If no secondary org set up, return header level org id.
        WHEN no_data_found THEN
          write_log('Secondary org not set up for l_primary_org_id' ||
	        l_primary_org_id);
          l_wh_org_id := l_primary_org_id;
          RAISE e_skip;
      END;
    
      --CHG0036321: Check for secondary subinventory
      --CHG0038326: Begin and Exception Block added in the secondary subinventory Query
      BEGIN
        SELECT attribute4
        INTO   l_secondary_subinventory
        FROM   mtl_parameters
        WHERE  organization_id = l_secondary_org_id;
      EXCEPTION
        WHEN no_data_found THEN
          l_wh_org_id := l_primary_org_id;
          RAISE e_skip;
      END;
    
      write_log('l_secondary_org_id: ' || l_secondary_org_id);
    
      -- Check primary org on hand quantity
      get_qty_available(p_inventory_item_id         => l_line_rec.inventory_item_id, --
		p_org_id                    => l_primary_org_id, --
		p_subinventory_code         => l_primary_subinventory, --CHG0036321 07/09/2015  Michal Tzvik
		x_qty_available_to_transact => l_primary_qty);
    
      write_log('l_primary_qty: ' || l_primary_qty);
    
      /*  IF l_secondary_org_id = 740 THEN
        -- USE
        l_secondary_subinventory := 'FG-K2';
      ELSIF l_secondary_org_id = 742 THEN
        -- UTP
        l_secondary_subinventory := '3200';
      END IF;*/
    
      write_log('l_secondary_subinventory: ' || l_secondary_subinventory);
      -- Check secondary org on hand quantity
      get_qty_available(p_inventory_item_id         => l_line_rec.inventory_item_id, --
		p_org_id                    => l_secondary_org_id, --
		p_subinventory_code         => l_secondary_subinventory, --CHG0036321 07/09/2015  Michal Tzvik
		x_qty_available_to_transact => l_secondary_qty);
    
      write_log('l_secondary_qty: ' || l_secondary_qty);
    
      -- Set org based on org with most quantity
      IF l_primary_qty < l_secondary_qty THEN
        write_log('Return l_secondary_org_id: ' || l_secondary_org_id);
        l_wh_org_id := l_secondary_org_id;
      
      ELSIF l_primary_qty > 0 THEN
      
        write_log('Return l_primary_org_id: ' || l_primary_org_id);
        l_wh_org_id := l_primary_org_id;
      
        -- CHG0034935: start
      ELSE
        -- No on hand exists
        BEGIN
          SELECT *
          INTO   l_mtl_item_rec
          FROM   mtl_system_items_b msib
          WHERE  msib.inventory_item_id = l_line_rec.inventory_item_id
          AND    msib.organization_id = 91;
        
        EXCEPTION
          WHEN no_data_found THEN
	write_log('Invalid item');
	RAISE e_skip;
        END;
      
        write_log('l_default_wh_for_order_src: ' ||
	      l_default_wh_for_order_src);
        -----------------------------------------------------------------------------
        -- l_default_wh_for_order_src may be populated with 3 kind of values:
        -- 1. -1 = NONE : No order source is using this logic.
        -- 2. -2 = ALL  : All order sources are using this logic.
        -- 3.  A specific order_source_id: only this order source is using this logic.
        ------------------------------------------------------------------------------
        --if the profile value=?None?,
        -- or profile is not ALL and current source is not the one
        --    which defined in the profile
        -- then Retain original default warehouse
        IF nvl(l_default_wh_for_order_src, -1) = -1 OR
           (l_default_wh_for_order_src != -2 AND
	l_default_wh_for_order_src != l_header_rec.order_source_id) THEN
          -- NONE
          l_wh_org_id := l_primary_org_id;
        
        ELSIF l_default_wh_for_order_src = -2 OR
	  l_default_wh_for_order_src = l_header_rec.order_source_id THEN
        
          l_fdm_organization_id     := fnd_profile.value('XXOM_FDM_WH_FOR_ORDER_SRC');
          l_polyjet_organization_id := fnd_profile.value('XXOM_POLYJET_WH_FOR_ORDER_SRC');
        
          IF l_mtl_item_rec.inventory_item_flag = 'Y' THEN
	l_wh_org_id := l_primary_org_id;
	-- Inventory item
	l_category_segment := xxinv_utils_pkg.get_category_segment('SEGMENT6',
					           1100000221,
					           l_line_rec.inventory_item_id);
	write_log('l_category_segment: ' || l_category_segment);
	--For hazardous & Restricted Goods (although they are PJ ) populate USE
	IF nvl(xxinv_utils_pkg.is_item_hazard_restricted(l_line_rec.inventory_item_id),
	       'N') = 'Y' THEN
	  /* CHG0037870 */
	  l_wh_org_id := nvl(fnd_profile.value('XXINV_DANGEROUS_GOODS_WH'),
		         l_primary_org_id);
	  --l_wh_org_id := l_fdm_organization_id;
	  --For PJ inventory items (exclude hazardous ) populate UTP
	ELSIF l_category_segment = 'POLYJET' THEN
	  l_wh_org_id := l_polyjet_organization_id;
	  --For FDM inventory items populate USE
	ELSIF l_category_segment = 'FDM' THEN
	  l_wh_org_id := l_fdm_organization_id;
	END IF;
          
          ELSE
	-- non inventory item
	IF l_mtl_item_rec.shippable_item_flag = 'Y' THEN
	  write_log('non inventory, shippable item');
	
	  BEGIN
	    SELECT ship_from_org_id
	    INTO   l_wh_org_id
	    FROM   (SELECT ship_from_org_id
		FROM   oe_order_lines_all oola,
		       mtl_system_items_b msib
		WHERE  oola.header_id = l_line_rec.header_id
		AND    msib.inventory_item_id =
		       oola.inventory_item_id
		AND    msib.organization_id = 91
		AND    msib.inventory_item_flag = 'Y'
		AND    nvl(oola.cancelled_flag, 'N') = 'N'
		GROUP  BY oola.ship_from_org_id
		ORDER  BY SUM(oola.ordered_quantity) DESC)
	    WHERE  rownum = 1;
	    write_log('max cnt l_wh_org_id=' || l_wh_org_id);
	  
	  EXCEPTION
	    WHEN no_data_found THEN
	      write_log('max cnt l_wh_org_id: no data found');
	      l_wh_org_id := l_primary_org_id;
	  END;
	
	END IF;
          END IF;
        END IF;
        -- CHG0034935: end
      END IF;
    END IF; -- END IF for dangerous materials
  
    -- ---------------------------------------------------------------------
    -- Lines with different ship_from_org_ids must have different ship sets
    -- However, the same org lines should have the same ship sets.  So if we
    -- had the following, we would want the ship sets on lines 1 and 3 to be
    -- the same...
    --   Line No.   Item        Ship From Org   Ship Set
    --   --------   ----------- -------------   --------
    --          1   OBJ-13000   UTP             1
    --          2   350-80107   USE             2
    --          3   OBJ-13070   UTP             1
    -- ----------------------------------------------------------------------
  
    -----> CHG0035224 Michal Tzvik : remove logic for ship set.
    -----> A new patch from Oracle fix the issue.
    /*
    -- Loop through all order lines
    
    FOR rec IN c_lines(l_line_rec.header_id) LOOP
      -- Get the max ship set that is a number
      write_log('** LOOP FOR rec.line_id: ' || rec.line_id);
      l_max_ship_set := rec.max_ship_set;
    
      write_log('rec.ship_set: ' || rec.ship_set);
    
      write_log('rec.ship_from_org_id: ' || rec.ship_from_org_id ||
                ' l_wh_org_id: ' || l_wh_org_id);
      -- Look for the first line where the ship_from_org_id matches the new order
      -- line's ship_from_org_id.  If we find one set new line's ship set to existing
      -- line's ship set
      IF rec.ship_from_org_id = l_wh_org_id THEN
        -- When we find a match we do not need to create a new ship set
        l_assign_ship_set_flag              := 'N';
        ont_line_def_hdlr.g_record.ship_set := rec.ship_set;
        EXIT;
      END IF;
      write_log('** END LOOP FOR rec.line_id: ' || rec.line_id);
    END LOOP;
    
    -- If we didn't find any lines with a matching ship_from_org_id in c_lines, then
    -- we need to set a new ship set on the new line
    write_log('l_assign_ship_set_flag: ' || l_assign_ship_set_flag);
    IF l_assign_ship_set_flag = 'Y' THEN
      l_max_ship_set := l_max_ship_set + 1;
      write_log('setting ship set to: ' || l_max_ship_set);
      ont_line_def_hdlr.g_record.ship_set := l_max_ship_set;
    END IF;*/
  
    write_log('l_wh_org_id: ' || l_wh_org_id);
  
    RETURN l_wh_org_id;
  EXCEPTION
    WHEN e_skip THEN
      write_log('In e_skip for l_wh_org_id: ' || l_wh_org_id);
      RETURN l_wh_org_id;
    WHEN OTHERS THEN
      write_log('Exception block for is_inventory_available: ' ||
	    dbms_utility.format_error_stack);
      RAISE fnd_api.g_exc_unexpected_error;
  END default_us_warehouse;

  --------------------------------------------------------------------
  --  name:              default_political_warehouse
  --  create by:         Michal Tzvik
  --  Revision:          1.0
  --  creation date:     28/07/2015
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date          name             desc
  --  1.0  28/07/2015    Michal Tzvik     CHG0035224 - initial build
  --------------------------------------------------------------------
  FUNCTION default_political_warehouse(p_database_object_name IN VARCHAR2,
			   p_attribute_code       IN VARCHAR2)
    RETURN NUMBER IS
    l_line_rec          oe_ak_order_lines_v%ROWTYPE;
    l_header_rec        oe_ak_order_headers_v%ROWTYPE;
    l_wh_org_id         NUMBER;
    is_header_political VARCHAR2(1);
    l_political_wh      NUMBER;
    l_is_line_political NUMBER;
  BEGIN
    g_log_program_unit := 'xxoe.order_default.xxoe_dflt_rules_pkg.default_political_warehouse';
    l_line_rec         := ont_line_def_hdlr.g_record;
    l_header_rec       := ont_header_def_hdlr.g_record;
    g_line_id          := l_line_rec.line_id;
    l_political_wh     := fnd_profile.value('XXOM_POLITICAL_WH_FOR_ORDER_SRC');
  
    write_log('*** BEGIN DEFAULT_POLITICAL_WAREHOUSE ***');
    write_log('l_line_rec.inventory_item_id: ' ||
	  l_line_rec.inventory_item_id);
  
    IF xxwsh_political.is_so_hdr_political(l_header_rec.header_id) = 1 AND
       xxwsh_political.is_item_political(l_line_rec.inventory_item_id) = 'Y' THEN
    
      write_log('SO line is political');
      l_wh_org_id := l_political_wh;
      --   ont_line_def_hdlr.g_record.subinventory := fnd_profile.value('XXWSH_POLITICAL_SUBINVENTORY');
    ELSE
      write_log('SO line is not political');
    END IF;
    RETURN l_wh_org_id;
  
  EXCEPTION
    WHEN OTHERS THEN
      write_log('default_political_warehouse Exception: ' ||
	    dbms_utility.format_error_stack);
      RAISE fnd_api.g_exc_unexpected_error;
  END default_political_warehouse;

  --------------------------------------------------------------------
  --  name:              default_political_subinventory
  --  create by:         Michal Tzvik
  --  Revision:          1.0
  --  creation date:     13/08/2015
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date          name             desc
  --  1.0  13/08/2015    Michal Tzvik     CHG0035224 - initial build
  --------------------------------------------------------------------
  FUNCTION default_political_subinventory(p_database_object_name IN VARCHAR2,
			      p_attribute_code       IN VARCHAR2)
    RETURN VARCHAR2 IS
    l_line_rec          oe_ak_order_lines_v%ROWTYPE;
    l_header_rec        oe_ak_order_headers_v%ROWTYPE;
    l_subinventory      oe_order_lines_all.subinventory%TYPE;
    is_header_political VARCHAR2(1);
    l_political_wh      NUMBER;
    l_is_line_political NUMBER;
  BEGIN
    g_log_program_unit := 'xxoe.order_default.xxoe_dflt_rules_pkg.default_political_subinventory';
    l_line_rec         := ont_line_def_hdlr.g_record;
    l_header_rec       := ont_header_def_hdlr.g_record;
    g_line_id          := l_line_rec.line_id;
    l_political_wh     := fnd_profile.value('XXOM_POLITICAL_WH_FOR_ORDER_SRC');
  
    write_log('*** BEGIN DEFAULT_POLITICAL_SUBINVENTORY ***');
    write_log('l_line_rec.inventory_item_id: ' ||
	  l_line_rec.inventory_item_id);
  
    IF xxwsh_political.is_so_hdr_political(l_header_rec.header_id) = 1 AND
       xxwsh_political.is_item_political(l_line_rec.inventory_item_id) = 'Y' THEN
    
      write_log('Item is political');
      l_subinventory := fnd_profile.value('XXWSH_POLITICAL_SUBINVENTORY');
    ELSE
      write_log('Item is not political');
    END IF;
    RETURN l_subinventory;
  
  EXCEPTION
    WHEN OTHERS THEN
      write_log('default_political_subinventory Exception: ' ||
	    dbms_utility.format_error_stack);
      RAISE fnd_api.g_exc_unexpected_error;
  END default_political_subinventory;

  -- ----------------------------------------------------------------------------------------
  --  Purpose : Defaults the shipping_method_code on the order line depending on the item_ordered
  --            If item is hazardous material, the Shipping Method is to be set with the value from
  --            profile option XXOM_DEFAULT_SM_FOR_DANGEROUS_ITEM
  --  ----------------------------------------------------------------------------------------
  --  Ver Date        Name          Description
  -- -----------------------------------------------------------------------------------------
  --  1.0 09/10/2015  Diptasurjya   CHG0036423 - Initial Build
  --                  Chatterjee
  --  1.1 22-NOV-2015 Sandeep Akula CHG0037039 - Changed logic ofthe function to first check if the Order Type exists in the Lookup XXOE_DG_SHIP_METHOD_EXCLUSION
  --                                             If the Order type exists in the Lookup then function will return a NULL value as a result of which the defaulting rule
  --                                             will execute the 2nd step where the Order type will be copied from order header
  --                                             If the Order Type does  not exists in the Lookup and is a Dangerous good then ship method is derived from the value stored
  --                                             in the profile option XXOM_DEFAULT_SM_FOR_DANGEROUS_ITEM
  -- -----------------------------------------------------------------------------------------
  FUNCTION ship_method_default_rule(p_database_object_name IN VARCHAR2,
			p_attribute_code       IN VARCHAR2)
    RETURN VARCHAR2 IS
    l_line_rec   oe_ak_order_lines_v%ROWTYPE;
    l_header_rec oe_ak_order_headers_v%ROWTYPE;
  
    l_line_type_rec oe_order_cache.line_type_rec_type;
  
    l_ship_method      VARCHAR2(240);
    l_cnt              NUMBER;
    l_item_id          NUMBER;
    l_order_type_id    NUMBER;
    l_ship_from_org_id NUMBER;
  
    l_err VARCHAR2(2000);
  BEGIN
    g_log_program_unit := 'ship_method_default_rule';
    l_line_rec         := ont_line_def_hdlr.g_record;
    l_header_rec       := ont_header_def_hdlr.g_record;
  
    write_log('*** BEGIN DEFAULT_US_SHIP_METHOD ***');
    write_log('l_line_rec.inventory_item_id: ' ||
	  l_line_rec.inventory_item_id);
    write_log('l_line_rec.ship_from_org_id: ' ||
	  l_line_rec.ship_from_org_id);
    write_log('l_header_rec.order_type_id: ' || l_header_rec.order_type_id);
    write_log('l_line_rec.line_number: ' || l_line_rec.line_number);
  
    l_item_id          := l_line_rec.inventory_item_id;
    l_order_type_id    := l_header_rec.order_type_id;
    l_ship_from_org_id := l_line_rec.ship_from_org_id;
  
    SELECT COUNT(*)
    INTO   l_cnt
    FROM   fnd_lookup_values_vl    flv,
           oe_transaction_types_tl ott,
           mtl_parameters          mp
    WHERE  flv.lookup_type = 'XXOE_DG_SHIP_METHOD_EXCLUSION'
    AND    flv.enabled_flag = 'Y'
    AND    trunc(SYSDATE) BETWEEN trunc(flv.start_date_active) AND
           trunc(nvl(flv.end_date_active, trunc(SYSDATE)))
    AND    upper(ott.name) = flv.lookup_code
    AND    ott.language = 'US'
    AND    to_number(flv.attribute1) = mp.organization_id
    AND    ott.transaction_type_id = l_order_type_id
    AND    mp.organization_id = l_ship_from_org_id
    AND    xxinv_utils_pkg.is_hazard_item(l_item_id, 91) = 'Y';
  
    write_log('l_cnt:' || l_cnt);
  
    IF l_cnt = 0 THEN
    
      IF xxinv_utils_pkg.is_hazard_item(l_item_id, 91) = 'Y' AND
         l_ship_from_org_id = 740 /* USE */
       THEN
      
        SELECT lookup_code
        INTO   l_ship_method
        FROM   fnd_lookup_values_vl
        WHERE  lookup_type = 'SHIP_METHOD'
        AND    enabled_flag = 'Y'
        AND    lookup_code =
	   fnd_profile.value('XXOM_DEFAULT_SM_FOR_DANGEROUS_ITEM');
      
      END IF;
    
    END IF;
  
    /* IF xxinv_utils_pkg.is_hazard_item(l_item_id, 91) = 'Y' THEN
      SELECT lookup_code
      INTO   l_ship_method
      FROM   fnd_lookup_values_vl
      WHERE  lookup_type = 'SHIP_METHOD'
      AND    enabled_flag = 'Y'
      AND    lookup_code =
             fnd_profile.value('XXOM_DEFAULT_SM_FOR_DANGEROUS_ITEM');
    END IF;*/
  
    write_log('l_ship_method:' || l_ship_method);
  
    RETURN l_ship_method;
  EXCEPTION
    WHEN OTHERS THEN
      IF oe_msg_pub.check_msg_level(oe_msg_pub.g_msg_lvl_unexp_error) THEN
        oe_msg_pub.add_exc_msg('xxoe_dflt_rules_pkg',
		       'SHIP_METHOD_DEFAULT_RULE');
      END IF;
      RAISE fnd_api.g_exc_unexpected_error;
  END ship_method_default_rule;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    freight_terms_default_rule
  Author's Name:   Sandeep Akula
  Date Written:    22-NOV-2015
  Purpose:         This Function defaults the freight terms on the order line depending on the Item Ordered.
                   If the Item is Dangerous good and WareHouse, Order type is listed in Lookup XXOE_DG_ITEM_FREIGHT_TERM then freight terms is
                   derived from the Lookup code DFF (attribute2).
                   If Order Type is not listed in the Lookup then function looks for an entry with Lookup code as "ELSE-" concatenated with warehosue; in this case
                   freight terms is derived from Lookup code DFF (attribute2) for all other order types
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version            Name            Remarks
  -----------    ----------------   -------------   ------------------
  22-NOV-2015    1.0                Sandeep Akula   Initial Version -- CHG0037039
  03-DEC-2015    1.1                Diptasurjya     Handle blank freight terms in lookup setup
  ---------------------------------------------------------------------------------------------------*/
  FUNCTION freight_terms_default_rule(p_database_object_name IN VARCHAR2,
			  p_attribute_code       IN VARCHAR2)
    RETURN VARCHAR2 IS
  
    l_line_rec   oe_ak_order_lines_v%ROWTYPE;
    l_header_rec oe_ak_order_headers_v%ROWTYPE;
  
    l_line_type_rec oe_order_cache.line_type_rec_type;
  
    l_lookup_org VARCHAR2(240);
  
    l_freight_term     VARCHAR2(240);
    l_item_id          NUMBER;
    l_order_type_id    NUMBER;
    l_ship_from_org_id NUMBER;
  
    l_err VARCHAR2(2000);
  BEGIN
  
    g_log_program_unit := 'freight_terms_default_rule';
    l_line_rec         := ont_line_def_hdlr.g_record;
    l_header_rec       := ont_header_def_hdlr.g_record;
  
    write_log('*** BEGIN DEFAULT_US_FREIGHT_TERM ***');
    write_log('l_line_rec.inventory_item_id: ' ||
	  l_line_rec.inventory_item_id);
    write_log('l_line_rec.ship_from_org_id: ' ||
	  l_line_rec.ship_from_org_id);
    write_log('l_header_rec.order_type_id: ' || l_header_rec.order_type_id);
    write_log('l_line_rec.line_number: ' || l_line_rec.line_number);
  
    l_item_id          := l_line_rec.inventory_item_id;
    l_order_type_id    := l_header_rec.order_type_id;
    l_ship_from_org_id := l_line_rec.ship_from_org_id;
  
    BEGIN
      SELECT flv.attribute2,
	 flv.attribute1
      INTO   l_freight_term,
	 l_lookup_org
      FROM   fnd_lookup_values_vl    flv,
	 oe_transaction_types_tl ott,
	 mtl_parameters          mp
      WHERE  flv.lookup_type = 'XXOE_DG_ITEM_FREIGHT_TERM'
      AND    flv.enabled_flag = 'Y'
      AND    trunc(SYSDATE) BETWEEN trunc(flv.start_date_active) AND
	 trunc(nvl(flv.end_date_active, trunc(SYSDATE)))
      AND    upper(ott.name) = flv.lookup_code
      AND    ott.language = 'US'
      AND    to_number(flv.attribute1) = mp.organization_id
      AND    ott.transaction_type_id = l_order_type_id
      AND    mp.organization_id = l_ship_from_org_id
      AND    xxinv_utils_pkg.is_hazard_item(l_item_id, 91) = 'Y';
    EXCEPTION
      WHEN OTHERS THEN
        l_freight_term := NULL;
    END;
  
    write_log('l_freight_term1: ' || l_freight_term);
  
    IF l_freight_term IS NULL AND l_lookup_org IS NULL THEN
    
      /* Deriving Freight Terms for all Other Order Types */
      BEGIN
        SELECT flv.attribute2
        INTO   l_freight_term
        FROM   fnd_lookup_values_vl flv,
	   mtl_parameters       mp
        WHERE  flv.lookup_type = 'XXOE_DG_ITEM_FREIGHT_TERM'
        AND    flv.enabled_flag = 'Y'
        AND    trunc(SYSDATE) BETWEEN trunc(flv.start_date_active) AND
	   trunc(nvl(flv.end_date_active, trunc(SYSDATE)))
        AND    to_number(flv.attribute1) = mp.organization_id
        AND    mp.organization_id = l_ship_from_org_id
        AND    xxinv_utils_pkg.is_hazard_item(l_item_id, 91) = 'Y'
        AND    flv.lookup_code = 'ELSE-' || mp.organization_code;
      EXCEPTION
        WHEN OTHERS THEN
          l_freight_term := NULL;
      END;
    
    END IF;
  
    write_log('l_freight_term2: ' || l_freight_term);
  
    RETURN l_freight_term;
  EXCEPTION
    WHEN OTHERS THEN
      IF oe_msg_pub.check_msg_level(oe_msg_pub.g_msg_lvl_unexp_error) THEN
        oe_msg_pub.add_exc_msg('xxoe_dflt_rules_pkg',
		       'FREIGHT_TERM_DEFAULT_RULE');
      END IF;
      RAISE fnd_api.g_exc_unexpected_error;
  END freight_terms_default_rule;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    salesperson_default_rule
  Author's Name:   Diptasurjya Chatterjee
  Date Written:    03-DEC-2015
  Purpose:         This Function defaults the Salesrep on the order header depending on the Order Type
                   If Order Type is not listed in the Lookup XXOE_SALESREP_ORDER_TYPE then function
                   defaults salesrep with attribute1 value from lookup otherwise it will return null
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version            Name            Remarks
  -----------    ----------------   -------------   ------------------
  03-DEC-2015    1.0                Diptasurjya     Initial Version -- CHG0037039
  ---------------------------------------------------------------------------------------------------*/

  FUNCTION salesperson_default_rule(p_database_object_name IN VARCHAR2,
			p_attribute_code       IN VARCHAR2)
    RETURN VARCHAR2 IS
  
    l_header_rec oe_ak_order_headers_v%ROWTYPE;
  
    l_line_type_rec oe_order_cache.line_type_rec_type;
  
    l_lookup_org VARCHAR2(240);
  
    l_salesrep_id      VARCHAR2(240);
    l_item_id          NUMBER;
    l_order_type_id    NUMBER;
    l_ship_from_org_id NUMBER;
  
    l_err VARCHAR2(2000);
  BEGIN
  
    g_log_program_unit := 'salesperson_default_rule';
    l_header_rec       := ont_header_def_hdlr.g_record;
  
    write_log('*** BEGIN DEFAULT_US_SALESPERSON ***');
    write_log('l_header_rec.order_type_id: ' || l_header_rec.order_type_id);
  
    l_order_type_id := l_header_rec.order_type_id;
  
    BEGIN
      SELECT flv.attribute1
      INTO   l_salesrep_id
      FROM   fnd_lookup_values_vl    flv,
	 oe_transaction_types_vl ott
      WHERE  flv.lookup_type = 'XXOE_SALESREP_ORDER_TYPE'
      AND    flv.meaning = ott.name
      AND    ott.transaction_type_id = l_order_type_id;
    EXCEPTION
      WHEN no_data_found THEN
        l_salesrep_id := NULL;
    END;
  
    write_log('Sales rep ID: ' || l_salesrep_id);
  
    RETURN l_salesrep_id;
  EXCEPTION
    WHEN OTHERS THEN
      IF oe_msg_pub.check_msg_level(oe_msg_pub.g_msg_lvl_unexp_error) THEN
        oe_msg_pub.add_exc_msg('xxoe_dflt_rules_pkg',
		       'SALESPERSON_DEFAULT_RULE');
      END IF;
      RAISE fnd_api.g_exc_unexpected_error;
  END salesperson_default_rule;

  --------------------------------------------------------------------
  --  name:            default_inter_loc_DG_item
  --  create by:       Rimpi
  --  Revision:        1.0
  --  creation date:   20-Apr-2016
  --------------------------------------------------------------------
  --  ver  date              name              desc
  --  1.0  05-Apr-2017 Rimpi          CHG0040568: Default  a value in Intermediate ship to field at order header line in order to create separate deliveries for DG items
  --------------------------------------------------------------------

  FUNCTION default_inter_loc_dg_item(p_database_object_name IN VARCHAR2,
			 p_attribute_code       IN VARCHAR2)
    RETURN NUMBER IS
  
    l_line_rec           oe_ak_order_lines_v%ROWTYPE;
    l_inter_ship_to_locn NUMBER;
  
  BEGIN
    g_log_program_unit := 'default_inter_loc_dg_item';
    l_line_rec         := ont_line_def_hdlr.g_record;
  
    write_log('*** BEGIN default_inter_loc_DG_item ***');
    write_log('l_line_rec.inventory_item_id: ' ||
	  l_line_rec.inventory_item_id);
  
    IF xxinv_utils_pkg.is_item_hazard_restricted(l_line_rec.inventory_item_id) = 'Y' THEN
    
      l_inter_ship_to_locn := fnd_profile.value('XXOM_DG_INTER_SHIP_TO_LOCATION');
    
      RETURN l_inter_ship_to_locn;
    
    ELSE
    
      RETURN NULL;
    END IF;
  
  END default_inter_loc_dg_item;

  --------------------------------------------------------------------
  --  name:            default_ou_functional_currency
  --  create by:      
  --  Revision:        1.0
  --  creation date:   22.10.17 
  --------------------------------------------------------------------
  --  ver  date              name              desc
  --  1.0  22.10.17       YUval tal            CHG0040750
  --------------------------------------------------------------------

  FUNCTION default_ou_functional_currency(p_database_object_name IN VARCHAR2,
			      p_attribute_code       IN VARCHAR2)
    RETURN VARCHAR2 IS
  
    l_header_rec oe_ak_order_headers_v%ROWTYPE;
    l_curr       gl_ledgers.currency_code%TYPE;
  BEGIN
    g_log_program_unit := 'default_ou_functional_currency';
    l_header_rec       := ont_header_def_hdlr.g_record;
    write_log('*** BEGIN default_ou_functional_currency ***');
    write_log('*** BEGIN source_document_id=' ||
	  l_header_rec.source_document_id);
    --   Default OU Functional Currency
  
    /* SELECT gld.currency_code
    INTO   l_curr
    FROM   hr_operating_units         hou,
           gl_ledgers                 gld,
           po_requisition_headers_all th
    WHERE  hou.set_of_books_id = gld.ledger_id
    AND    hou.organization_id = th.org_id
    AND    th.requisition_header_id = l_header_rec.source_document_id;*/
  
    SELECT currency_code
    INTO   l_curr
    FROM   (SELECT gld.currency_code
	
	FROM   hr_operating_units            hou,
	       gl_ledgers                    gld,
	       po_requisition_headers_all    th,
	       mtl_intercompany_parameters_v b
	WHERE  hou.set_of_books_id = gld.ledger_id
	AND    hou.organization_id = th.org_id
	AND    th.requisition_header_id =
	       l_header_rec.source_document_id
	AND    b.ship_organization_id = l_header_rec.org_id
	AND    b.sell_organization_id = th.org_id
	AND    b.inv_currency_code = 2
	UNION ALL
	
	SELECT gld.currency_code
	--  INTO   l_curr
	FROM   hr_operating_units            hou,
	       gl_ledgers                    gld,
	       po_requisition_headers_all    th,
	       mtl_intercompany_parameters_v b
	WHERE  hou.set_of_books_id = gld.ledger_id
	AND    hou.organization_id = l_header_rec.org_id
	AND    th.requisition_header_id =
	       l_header_rec.source_document_id
	AND    b.ship_organization_id = l_header_rec.org_id
	AND    b.sell_organization_id = th.org_id
	AND    b.inv_currency_code = 1);
  
    RETURN l_curr;
  EXCEPTION
    WHEN OTHERS THEN
    
      write_log('*** Exception  default_ou_functional_currency ***');
    
      write_log('*** Exception ' || substr(SQLERRM, 200));
      RETURN NULL;
    
  END;

END xxoe_dflt_rules_pkg;
/
