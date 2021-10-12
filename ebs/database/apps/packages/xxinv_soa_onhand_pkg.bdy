CREATE OR REPLACE PACKAGE BODY xxinv_soa_onhand_pkg AS
  ----------------------------------------------------------------------------
  --  name:            xxinv_realtime_interfaces_pkg
  --  create by:       Diptasurjya Chatterjee (TCS)
  --  Revision:        1.0
  --  creation date:   10/26/2017
  ----------------------------------------------------------------------------
  --  purpose :        CHG0041332 - This is a generic package which will be used for
  --                   all future Inventory related realtime interfaces to/from Oracle
  --                   to downstream systems
  ----------------------------------------------------------------------------
  --  ver  date        name                         desc
  --  1.0  10/26/2017  Diptasurjya Chatterjee(TCS)  CHG0041332 - Initial build
  --  1.1  14-May-2018 Lingaraj (TCS)               CHG0042879 - Inventory Check From Sales Force to Oracle
  --  1.2  01-Aug-2018 Lingaraj                     CHG0042879[CTASK0037719] - New parameter to the interface,
  --                                                add car stock and filter main warehouses per region
  --  1.3  15-Jul-2019 Diptasurjya                  CHG0045755 - PTO item onhand calculation changes for HYBRIS
  --  1.4  05-Feb-2019 Lingaraj                     CHG0046372-INC0146338-global_availibility = Yes Should Support org_id & organization_id with out any Value
  --  1.5  9/7/2020    yuval tal                    CHG0048217  support non strataforce source  
  --  1.6  4.11.20     yuval tal                    CHG0048217  modify request_onhand_quantity parameter type
  ----------------------------------------------------------------------------

  g_log              VARCHAR2(1) := fnd_profile.value('AFLOG_ENABLED');
  g_log_module       VARCHAR2(100) := fnd_profile.value('AFLOG_MODULE');
  g_api_name         VARCHAR2(30) := 'xxinv_soa_onhand_pkg';
  g_log_program_unit VARCHAR2(100);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Write to request log if 'FND: Debug Log Enabled' is set to Yes
  -- ---------------------------------------------------------------------------------------------
  -- Ver  Date        Name            Description
  -- 1.0  10/26/2017  Diptasurjya     CHG0041332 - Initial build
  --                  Chatterjee
  -- ---------------------------------------------------------------------------------------------
  PROCEDURE write_log(p_msg VARCHAR2) IS
    l_log VARCHAR2(1);
  BEGIN
    IF g_log = 'Y' THEN
      fnd_log.string(log_level => fnd_log.level_unexpected,
	         module    => g_api_name || g_log_program_unit,
	         message   => p_msg);
    END IF;
    --dbms_output.put_line(p_msg);
  END write_log;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0041332 - This Procedure validates the onahnd request input data. It populates all
  --          derived fields into the type structure
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  10/26/2017  Diptasurjya Chatterjee (TCS)    CHG0041332 - Initial build
  -- 1.1  14-May-2018 Lingaraj (TCS)                  CHG0042879 - Inventory Check From Sales Force to Oracle
  --                                                  #In Case of STRATAFOCE the Organization Code will send on the Organization Name Field
  -- 1.2  05-Feb-2019 Lingaraj                        CHG0046372-INC0146338-global_availibility = Yes
  --                                                  Should Support org_id & organization_id with out any Value
  -- --------------------------------------------------------------------------------------------
  PROCEDURE validate_onhand_input(p_onhand_details      IN OUT xxobjt.xxinv_onhand_tab_type,
		          p_source_system       IN VARCHAR2, -- Added a new Parameter on 05Feb19 #CHG0046372-INC0146338
		          p_global_availibility IN VARCHAR2, -- Added a new Parameter on 05Feb19 #CHG0046372-INC0146338
		          x_status              OUT VARCHAR2,
		          x_status_message      OUT VARCHAR2) IS
    l_validation_status  VARCHAR2(1) := 'S';
    l_validation_message VARCHAR2(2000);
  
    l_item_id     NUMBER;
    l_ou_id       NUMBER;
    l_inv_org_id  NUMBER;
    l_subinv_code VARCHAR2(10);
  BEGIN
  
    FOR i IN 1 .. p_onhand_details.count
    LOOP
      l_item_id     := NULL;
      l_ou_id       := NULL;
      l_inv_org_id  := NULL;
      l_subinv_code := NULL;
    
      l_validation_status  := 'S';
      l_validation_message := NULL;
    
      -- Item validation
      IF p_onhand_details(i).item_code IS NULL AND p_onhand_details(i)
         .inventory_item_id IS NULL THEN
        l_validation_status  := 'E';
        l_validation_message := l_validation_message ||
		        'VALIDATION ERROR: Either Item code or Item ID is mandatory' ||
		        chr(13);
      ELSE
        BEGIN
          SELECT msib.inventory_item_id
          INTO   l_item_id
          FROM   mtl_system_items_b msib
          WHERE  msib.segment1 =
	     nvl(p_onhand_details(i).item_code, msib.segment1)
          AND    msib.inventory_item_id =
	     nvl(p_onhand_details(i).inventory_item_id,
	          msib.inventory_item_id)
          AND    msib.organization_id =
	     xxinv_utils_pkg.get_master_organization_id;
        
          IF p_onhand_details(i).inventory_item_id IS NULL THEN
	p_onhand_details(i).inventory_item_id := l_item_id;
          END IF;
        EXCEPTION
          WHEN no_data_found THEN
	l_validation_status  := 'E';
	l_validation_message := l_validation_message ||
			'VALIDATION ERROR: Item code or Item ID is not valid' ||
			chr(13);
        END;
      END IF;
    
      -- Operating Unit validation
      IF p_onhand_details(i)
       .ou_name IS NOT NULL OR p_onhand_details(i).org_id IS NOT NULL THEN
        BEGIN
          SELECT hou.organization_id
          INTO   l_ou_id
          FROM   hr_operating_units hou
          WHERE  hou.name = nvl(p_onhand_details(i).ou_name, hou.name)
          AND    hou.organization_id =
	     nvl(p_onhand_details(i).org_id, hou.organization_id);
        
          IF p_onhand_details(i).org_id IS NULL THEN
	p_onhand_details(i).org_id := l_ou_id;
          END IF;
        EXCEPTION
          WHEN no_data_found THEN
	l_validation_status  := 'E';
	l_validation_message := l_validation_message ||
			'VALIDATION ERROR: Operating Unit Name or Operating Unit Org ID is not valid' ||
			chr(13);
        END;
      END IF;
    
      -- Inventory Organization validation
      IF p_onhand_details(i).organization_name IS NOT NULL OR p_onhand_details(i)
         .organization_id IS NOT NULL THEN
        BEGIN
          SELECT ood.organization_id,
	     ood.operating_unit
          INTO   l_inv_org_id,
	     l_ou_id
          FROM   org_organization_definitions ood
          WHERE  (ood.organization_name =
	     nvl(p_onhand_details(i).organization_name,
	          ood.organization_name) OR
	     --CHG0042879# OR Condition Added
	     ood.organization_code =
	     nvl(p_onhand_details(i).organization_name,
	          ood.organization_code))
          AND    ood.organization_id =
	     nvl(p_onhand_details(i).organization_id,
	          ood.organization_id);
        
          IF p_onhand_details(i).organization_id IS NULL THEN
	p_onhand_details(i).organization_id := l_inv_org_id;
          END IF;
        
          IF p_onhand_details(i).org_id IS NULL THEN
	p_onhand_details(i).org_id := l_ou_id;
          END IF;
        EXCEPTION
          WHEN no_data_found THEN
	l_validation_status  := 'E';
	l_validation_message := l_validation_message ||
			'VALIDATION ERROR: Inventory organization Name or Inventory Organization ID is not valid' ||
			chr(13);
        END;
      END IF;
    
      -- Added if on 05Feb19 #CHG0046372-INC0146338
      IF NOT (upper(p_source_system) = 'STRATAFORCE' AND
          upper(p_global_availibility) = 'YES') THEN
        --#CHG0046372-INC0146338
        -- Operating Unit or Inventory Organization must be provided
        IF p_onhand_details(i)
         .org_id IS NULL AND p_onhand_details(i).organization_id IS NULL THEN
          l_validation_status  := 'E';
          l_validation_message := l_validation_message ||
		          'VALIDATION ERROR: Either Operating Unit or Inventory Organization is mandatory' ||
		          chr(13);
        END IF;
      END IF;
    
      -- If Subinventory is provided Inventory Organization is mandatory
      IF p_onhand_details(i).organization_id IS NULL AND p_onhand_details(i)
         .subinventory_code IS NOT NULL THEN
        l_validation_status  := 'E';
        l_validation_message := l_validation_message ||
		        'VALIDATION ERROR: Inventory Organization is mandatory if Subinventory is provided' ||
		        chr(13);
      END IF;
    
      -- Sub-Inventory validation
      IF p_onhand_details(i).subinventory_code IS NOT NULL AND p_onhand_details(i)
         .organization_id IS NOT NULL THEN
        BEGIN
          SELECT msi.secondary_inventory_name
          INTO   l_subinv_code
          FROM   mtl_secondary_inventories msi
          WHERE  msi.secondary_inventory_name = p_onhand_details(i)
	    .subinventory_code
          AND    msi.organization_id = p_onhand_details(i).organization_id;
        
        EXCEPTION
          WHEN no_data_found THEN
	l_validation_status  := 'E';
	l_validation_message := l_validation_message ||
			'VALIDATION ERROR: Subinventory code is not valid' ||
			chr(13);
        END;
      END IF;
    
      p_onhand_details(i).status := l_validation_status;
      p_onhand_details(i).error_message := l_validation_message;
    END LOOP;
    x_status := 'S';
  EXCEPTION
    WHEN OTHERS THEN
      x_status         := 'E';
      x_status_message := 'VALIDATION ERROR: ' || SQLERRM;
  END validate_onhand_input;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0042879 - This Procedure fetched the Related Item details depend on the
  --                       Relation Type (like Substitute)
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date         Name                Description
  -- 1.0  17/05/2018   Lingaraj            CHG0042879 - Inventory check - from salesforce to Oracle
  -- --------------------------------------------------------------------------------------------
  PROCEDURE get_related_item(p_item_code         IN VARCHAR2 DEFAULT NULL,
		     p_related_item_code IN VARCHAR2 DEFAULT NULL,
		     p_relation_type     IN VARCHAR2,
		     
		     x_related_item_id   OUT NUMBER,
		     x_related_item_code OUT VARCHAR2,
		     x_related_item_desc OUT VARCHAR2,
		     x_parent_item_id    OUT NUMBER,
		     x_parent_item_code  OUT VARCHAR2,
		     x_parent_item_desc  OUT VARCHAR2) IS
  BEGIN
  
    SELECT msib_related.inventory_item_id,
           msib_related.segment1,
           msib_related.description,
           --
           msib.inventory_item_id,
           msib.segment1,
           msib.description
    
    INTO   x_related_item_id,
           x_related_item_code,
           x_related_item_desc,
           x_parent_item_id,
           x_parent_item_code,
           x_parent_item_desc
    
    FROM   mtl_related_items  mri,
           fnd_lookup_values  flv,
           mtl_system_items_b msib,
           mtl_system_items_b msib_related
    WHERE  (mri.end_date IS NULL OR mri.end_date > SYSDATE)
    AND    flv.lookup_type = 'MTL_RELATIONSHIP_TYPES'
    AND    flv.language = 'US'
    AND    flv.lookup_code = mri.relationship_type_id
    AND    msib.organization_id = mri.organization_id
    AND    mri.inventory_item_id = msib.inventory_item_id
    AND    msib_related.organization_id = mri.organization_id
    AND    mri.related_item_id = msib_related.inventory_item_id
    AND    msib_related.segment1 =
           nvl(p_related_item_code, msib_related.segment1)
    AND    msib.segment1 = nvl(p_item_code, msib.segment1)
    AND    flv.meaning = p_relation_type
    AND    mri.organization_id = 91
    AND    rownum = 1;
  
  EXCEPTION
    WHEN no_data_found THEN
      x_related_item_id   := NULL;
      x_related_item_code := NULL;
      x_related_item_desc := NULL;
      x_parent_item_id    := NULL;
      x_parent_item_code  := NULL;
      x_parent_item_desc  := NULL;
  END get_related_item;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0042879 - This Procedure have all the logic to fetch the onhand details of a product
  --                       for Source = STRATAFORCE
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date         Name                Description
  -- 1.0  01-Aug-2018  Lingaraj            CHG0042879[CTASK0037719] - New parameter to the interface,
  --                                       add car stock and filter main warehouses per region
  -- --------------------------------------------------------------------------------------------
  FUNCTION get_product_message(p_inventory_item_id NUMBER) RETURN VARCHAR2 IS
    l_product_msg fnd_documents_short_text.short_text%TYPE;
  BEGIN
    SELECT DISTINCT fdst.short_text
    INTO   l_product_msg
    FROM   fnd_document_categories_tl fdct,
           fnd_documents_tl           fdt,
           fnd_attached_documents     fad,
           fnd_documents_short_text   fdst,
           fnd_documents              fd
    WHERE  fad.pk2_value = p_inventory_item_id -- Parameter
          --fad.pk2_value(+) = p_inventory_item_id -- Parameter
    AND    fdct.user_name = 'Product Messages'
    AND    fad.entity_name = 'MTL_SYSTEM_ITEMS'
    AND    fdct.language = fdt.language
    AND    fdt.language = 'US'
    AND    fad.document_id = fd.document_id
    AND    fd.document_id = fdt.document_id
    AND    fd.category_id = fdct.category_id
    AND    fd.media_id = fdst.media_id
          --AND    fd.category_id IN
          --       (SELECT fdct.category_id FROM fnd_document_categories_tl fdct)
    AND    rownum = 1;
  
    RETURN l_product_msg;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN '';
  END get_product_message;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0045755 - This function checks if bom_item_type for an item is PTO MODEL or KIT
  --                       and does not have an option class defined in BOM components
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  15/07/2019  Diptasurjya Chatterjee (TCS)    CHG0045755 - Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION is_item_bom_type_valid(p_inventory_item_id IN NUMBER)
    RETURN VARCHAR2 IS
    l_bom_item_type_valid VARCHAR2(1) := 'N';
  BEGIN
    SELECT 'Y' --msib.segment1, msib.inventory_item_status_code, msib.bom_item_type, msib.item_type
    INTO   l_bom_item_type_valid
    FROM   bom_bill_of_materials_v x,
           mtl_system_items_b      msib
    WHERE  msib.bom_item_type <> 2 --OPTION CLASS
    AND    msib.inventory_item_id = x.assembly_item_id
    AND    x.organization_id = msib.organization_id
    AND    msib.organization_id =
           xxinv_utils_pkg.get_master_organization_id
    AND    msib.inventory_item_id = p_inventory_item_id
    AND    msib.item_type IN ('XXSSYS_PTO_MODEL', 'XXSSYS_PTO_KIT')
    AND    NOT EXISTS
     (SELECT 1
	FROM   bom_inventory_components_v b
	WHERE  b.bom_item_type = 2 -- OPTION CLASS
	AND    b.bill_sequence_id = x.bill_sequence_id
	AND    trunc(SYSDATE) BETWEEN b.implementation_date AND
	       nvl(b.disable_date, (SYSDATE + 1)));
  
    RETURN l_bom_item_type_valid;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN 'N';
  END is_item_bom_type_valid;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0042879 - This Procedure have all the logic to fetch the onhand details of a product
  --                       for Source = STRATAFORCE
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date         Name                Description
  -- 1.0  17/05/2018   Lingaraj            CHG0042879 - Inventory check - from salesforce to Oracle
  -- 1.2  01-Aug-2018 Lingaraj             CHG0042879[CTASK0037719] - New parameter to the interface,
  --                                       add car stock and filter main warehouses per region
  -- 1.3  05-Feb-2019 Lingaraj             CHG0046372-INC0146338-global_availibility = Yes
  --                                       Should Support org_id & organization_id with out any Value
  -- 1.4  08-SEP-2019  Roman W.            CHG0046372 added call to "get_product_message"
  -- --------------------------------------------------------------------------------------------
  PROCEDURE strataforce_onhand_request(p_onhand_details         IN OUT xxobjt.xxinv_onhand_tab_type,
			   p_global_availibility    IN VARCHAR2, --#Values Permitted Yes or No
			   p_car_stock_availability IN VARCHAR2 DEFAULT 'No', --#CTASK0037719 Values Permitted Yes or No
			   p_source_system          IN VARCHAR2,
			   p_onhand_type            IN VARCHAR2) IS
    --Get all the Inv Organization where Subinventory's Attribute11 = Y
    CURSOR c_dist_inv_org(p_organization_id NUMBER) IS
      SELECT ood.organization_id,
	 ood.organization_code,
	 ood.operating_unit
      FROM   org_organization_definitions ood
      WHERE  (p_global_availibility = 'No' AND
	 ood.organization_id = nvl(p_organization_id, -1))
      OR     (p_global_availibility = 'Yes' AND
	ood.organization_id IN
	(SELECT allowed_warehouse_id
	   FROM   (SELECT '1' q,
		      mp.organization_code warehouse_location,
		      mp.organization_code allowed_warehouse,
		      mp.organization_id allowed_warehouse_id
	           FROM   mtl_parameters mp
	           WHERE  EXISTS
		(SELECT 1
		       FROM   mtl_subinventories_all_v ms
		       WHERE  ms.organization_id = mp.organization_id
		       AND    ms.attribute11 = 'Y'
		       AND    nvl(disable_date, (SYSDATE + 1)) >
			  SYSDATE)
	           AND    mp.organization_id =
		      nvl(p_organization_id, mp.organization_id) --CHG0046372-INC0146338 # NVL Added to p_organization_id
	           UNION
	           SELECT '2' q,
		      mp.organization_code,
		      msn.to_organization_code,
		      msn.to_organization_id
	           FROM   hr_organization_units     hou,
		      mtl_parameters            mp,
		      mtl_shipping_network_view msn
	           WHERE  mp.organization_id = hou.organization_id
	           AND    mp.organization_id = msn.from_organization_id
	           AND    mp.organization_id =
		      nvl(p_organization_id, mp.organization_id) --CHG0046372-INC0146338 # NVL Added to p_organization_id
	           AND    EXISTS
		(SELECT 1
		       FROM   mtl_subinventories_all_v ms
		       WHERE  ms.organization_id = mp.organization_id
		       AND    ms.attribute11 = 'Y')
	           AND    EXISTS
		(SELECT 1
		       FROM   mtl_subinventories_all_v ms
		       WHERE  ms.organization_id =
			  msn.to_organization_id
		       AND    ms.attribute11 = 'Y'))));
  
    --Below query will fetch all the Inv Org , Sub Inv and Item (Item Assigned to Inv Orgs and Sub Inv attr11 = Y)
    CURSOR c_onhand_qry(p_inventory_item_id NUMBER,
		p_organization_id   NUMBER) IS
      SELECT msib.inventory_item_id,
	 ood.organization_id,
	 ood.organization_code,
	 ood.operating_unit,
	 msi.secondary_inventory_name,
	 msib.inventory_item_status_code item_status_code
      
      FROM   org_organization_definitions ood,
	 mtl_secondary_inventories    msi,
	 mtl_system_items_b           msib
      WHERE  msib.organization_id = ood.organization_id
      AND    ood.organization_id = msi.organization_id
      AND    msi.attribute11 = 'Y'
      AND    msib.inventory_item_id = p_inventory_item_id --Parameter
      AND    ood.organization_id = p_organization_id --Parameter
      AND    nvl(msi.disable_date, trunc(SYSDATE)) >= trunc(SYSDATE);
  
    --#CTASK0037719 CAR subinventory
    CURSOR c_car_subinv(p_organization_id   NUMBER,
		p_inventory_item_id NUMBER) IS
      SELECT msib.inventory_item_id,
	 ood.organization_id,
	 ood.organization_code,
	 ood.operating_unit,
	 msi.secondary_inventory_name,
	 msib.inventory_item_status_code item_status_code
      FROM   org_organization_definitions ood,
	 mtl_secondary_inventories    msi,
	 mtl_system_items_b           msib
      WHERE  msib.organization_id = ood.organization_id
      AND    ood.organization_id = msi.organization_id
      AND    msi.secondary_inventory_name LIKE '%CAR'
      AND    msib.inventory_item_id = p_inventory_item_id --Parameter
      AND    ood.organization_id = p_organization_id --Parameter
      AND    nvl(msi.disable_date, trunc(SYSDATE)) >= trunc(SYSDATE);
  
    l_onhand_details_in  xxobjt.xxinv_onhand_tab_type := xxobjt.xxinv_onhand_tab_type();
    l_onhand_details_out xxobjt.xxinv_onhand_tab_type := xxobjt.xxinv_onhand_tab_type();
    l_onhand_details_t   xxobjt.xxinv_onhand_tab_type := xxobjt.xxinv_onhand_tab_type();
  
    l_reservable_quantity NUMBER := 0;
    l_sub_qty             NUMBER := 0;
    l_rec_cnt             NUMBER := 0;
    l_rec_cnt_t           NUMBER := 0;
    l_item_status_code    VARCHAR2(15) := '';
    l_related_item_desc   VARCHAR2(500);
    l_related_item_id     NUMBER;
    l_related_item_code   VARCHAR2(240);
    l_parent_item_id      NUMBER;
    l_parent_item_code    VARCHAR2(240);
    l_parent_item_desc    VARCHAR2(500);
    l_attribute1          VARCHAR2(4000);
  
  BEGIN
    l_onhand_details_in := p_onhand_details;
    write_log('Source System :' || p_source_system);
    write_log('global_availibility :' || p_global_availibility);
  
    -- For Loop 1 # No Of Item OnHand Request
    FOR i IN 1 .. l_onhand_details_in.count
    LOOP
    
      IF l_onhand_details_in(i).status = 'S' THEN
      
        --For Loop 2 # Distinct Organization Code , with Search Org Name on Top
        FOR rec_dist_inv_org IN c_dist_inv_org(l_onhand_details_in(i)
			           .organization_id)
        LOOP
          l_reservable_quantity := 0;
          l_sub_qty             := 0;
          l_rec_cnt_t           := 0;
          l_related_item_desc   := NULL;
          l_related_item_id     := NULL;
          l_related_item_code   := NULL;
          l_parent_item_id      := NULL;
          l_parent_item_code    := NULL;
          l_parent_item_desc    := NULL;
          l_attribute1          := NULL;
          l_item_status_code    := NULL;
          l_onhand_details_t    := xxobjt.xxinv_onhand_tab_type();
        
          --Begin CHG0042879[CTASK0037719] Get the CAR Stock
          IF p_car_stock_availability = 'Yes' AND
	 nvl(l_onhand_details_in(i).organization_id,
	     rec_dist_inv_org.organization_id) =
	 rec_dist_inv_org.organization_id --CHG0046372-INC0146338 # NVL Added to Organization_id
           THEN
          
	FOR car_rec IN c_car_subinv(nvl(l_onhand_details_in(i)
			        .organization_id,
			        rec_dist_inv_org.organization_id),
			    l_onhand_details_in(i)
			    .inventory_item_id)
	LOOP
	
	  l_reservable_quantity := xxinv_utils_pkg.get_avail_to_reserve(p_inventory_item_id => l_onhand_details_in(i)
								   .inventory_item_id,
						    p_organization_id   => car_rec.organization_id,
						    p_subinventory      => car_rec.secondary_inventory_name);
	
	  IF l_reservable_quantity > 0 THEN
	    l_rec_cnt := l_rec_cnt + 1;
	    l_onhand_details_out.extend();
	    l_onhand_details_out(l_rec_cnt) := l_onhand_details_in(i);
	    l_onhand_details_out(l_rec_cnt).reservable_quantity := l_reservable_quantity;
	    l_onhand_details_out(l_rec_cnt).organization_name := car_rec.organization_code;
	    l_onhand_details_out(l_rec_cnt).organization_id := car_rec.organization_id;
	    l_onhand_details_out(l_rec_cnt).org_id := car_rec.operating_unit;
	    l_onhand_details_out(l_rec_cnt).subinventory_code := car_rec.secondary_inventory_name;
	    l_onhand_details_out(l_rec_cnt).attribute2 := i; -- Original Record Index
	  END IF;
	END LOOP;
          END IF;
          --End CHG0042879[CTASK0037719] Get the CAR Stock
          write_log('Loop 3 : Organization ID :' ||
	        rec_dist_inv_org.organization_id);
          write_log('Loop 3 :INV Organization ID :' || l_onhand_details_in(i)
	        .organization_id);
          write_log('Loop 3 :INV ID :' || l_onhand_details_in(i)
	        .inventory_item_id);
          --For Loop 3 # Query all the Subinventories for a Specific Organization Name
          FOR rec IN c_onhand_qry(l_onhand_details_in(i).inventory_item_id,
		          rec_dist_inv_org.organization_id)
          LOOP
	l_sub_qty := xxinv_utils_pkg.get_avail_to_reserve(p_inventory_item_id => rec.inventory_item_id,
					  p_organization_id   => rec.organization_id,
					  p_subinventory      => rec.secondary_inventory_name);
          
	l_reservable_quantity := l_reservable_quantity + l_sub_qty;
          
	write_log('reservable_quantity  :' || l_reservable_quantity ||
	          ' for Subinventory :' ||
	          rec.secondary_inventory_name ||
	          ' and Organization Id ' || rec.organization_id);
	l_reservable_quantity := nvl(l_reservable_quantity, 0);
          
	IF p_global_availibility = 'No' OR
	   (p_global_availibility = 'Yes' --Global Yes and Requested Inv Org
	   AND nvl(l_onhand_details_in(i).organization_id, -1) =
	   rec_dist_inv_org.organization_id --CHG0046372-INC0146338 #NVL Added to ORGANIZATION_ID
	   ) OR (p_global_availibility = 'Yes' --Global Yes and not Requested Inv Org and Qty > 0
	   AND l_sub_qty > 0 AND
	   nvl(l_onhand_details_in(i).organization_id, -1) !=
	   rec_dist_inv_org.organization_id --CHG0046372-INC0146338 #NVL Added to ORGANIZATION_ID
	   ) THEN
	  write_log('Record Inserted.');
	  --At the End Of Each Inventory Organization Onhand Qry  Populate Records
	  l_rec_cnt_t := l_rec_cnt_t + 1;
	  l_onhand_details_t.extend();
	  l_onhand_details_t(l_rec_cnt_t) := l_onhand_details_in(i);
	  l_onhand_details_t(l_rec_cnt_t).reservable_quantity := l_sub_qty;
	  l_onhand_details_t(l_rec_cnt_t).organization_name := rec_dist_inv_org.organization_code;
	  l_onhand_details_t(l_rec_cnt_t).organization_id := rec_dist_inv_org.organization_id;
	  l_onhand_details_t(l_rec_cnt_t).org_id := rec_dist_inv_org.operating_unit;
	  l_onhand_details_t(l_rec_cnt_t).subinventory_code := rec.secondary_inventory_name;
	  l_onhand_details_t(l_rec_cnt_t).attribute2 := i; -- Original Record Index
	END IF;
          
	l_item_status_code := rec.item_status_code;
          END LOOP; --# Get the Summation of Reservable qty
          --For Requested Inv Organization Only
          IF (nvl(l_onhand_details_in(i).organization_id, -1) =
	 rec_dist_inv_org.organization_id) OR
	 (nvl(l_onhand_details_in(i).organization_id,
	      rec_dist_inv_org.organization_id) =
	 rec_dist_inv_org.organization_id AND
	 p_global_availibility = 'Yes') THEN
	--CHG0046372-INC0146338 # NVL Added tol the Organziation Id
          
	--Extra Conditions For Comments
	IF l_reservable_quantity = 0 THEN
	  /*--Comment Condition = 1
                If the part number status is ?Phase out? and there is no available stock
                on the required inventory organization and there is ?substituted? item in
                the item relation need to add the following message.
              */
	
	  IF nvl(l_item_status_code, '-1') = 'XX_PHASOUT' THEN
	  
	    --Is Related Substitute item available ?
	    get_related_item(p_item_code         => l_onhand_details_in(i)
				        .item_code,
		         p_related_item_code => NULL,
		         p_relation_type     => 'Substitute'
		         ---
		        ,
		         x_related_item_id   => l_related_item_id,
		         x_related_item_code => l_related_item_code,
		         x_related_item_desc => l_related_item_desc,
		         x_parent_item_id    => l_parent_item_id,
		         x_parent_item_code  => l_parent_item_code,
		         x_parent_item_desc  => l_parent_item_desc);
	  
	    IF l_related_item_code IS NOT NULL THEN
	      fnd_message.clear;
	      fnd_message.set_name('XXOBJT',
			   'XXOBJT_OA2SF_ONHAND_QUERY_001');
	      fnd_message.set_token('PARENT_ITEM_CODE',
			    l_parent_item_code);
	      fnd_message.set_token('RELATED_ITEM_CODE',
			    l_related_item_code);
	      fnd_message.set_token('RELATED_ITEM_DESC',
			    l_related_item_desc);
	    
	      l_attribute1 := fnd_message.get;
	      l_attribute1 := l_attribute1 ||
		          get_product_message(l_related_item_id); --#CTASK0037719
	      write_log('Message Condition = 1 Satisfied');
	    
	    END IF;
	  
	  ELSE
	    /* Comment Condition = 2
                   there is no available stock for the product on the required inventory
                   organization and there
                    is ?Superseded? item in the item relationship need to add the message.
                */
	    --Is Related Superseded item available ?
	    get_related_item(p_item_code         => l_onhand_details_in(i)
				        .item_code,
		         p_related_item_code => NULL,
		         p_relation_type     => 'Superseded'
		         ------
		        ,
		         x_related_item_id   => l_related_item_id,
		         x_related_item_code => l_related_item_code,
		         x_related_item_desc => l_related_item_desc,
		         x_parent_item_id    => l_parent_item_id,
		         x_parent_item_code  => l_parent_item_code,
		         x_parent_item_desc  => l_parent_item_desc);
	  
	    IF l_related_item_id IS NOT NULL THEN
	      fnd_message.clear;
	      fnd_message.set_name('XXOBJT',
			   'XXOBJT_OA2SF_ONHAND_QUERY_002');
	      fnd_message.set_token('PARENT_ITEM_CODE',
			    l_parent_item_code);
	      fnd_message.set_token('RELATED_ITEM_CODE',
			    l_related_item_code);
	      fnd_message.set_token('RELATED_ITEM_DESC',
			    l_related_item_desc);
	    
	      l_attribute1 := fnd_message.get;
	      l_attribute1 := l_attribute1 ||
		          get_product_message(l_parent_item_id); --#CTASK0037719
	      write_log('Message Condition = 2 Satisfied');
	    
	    END IF;
	  END IF;
	
	ELSE
	  /* Comment Condition 3
                the required product is defined as substitute to other product and there is
                available stock from the other product add the  message.
              */
	  get_related_item(p_item_code         => NULL,
		       p_related_item_code => l_onhand_details_in(i)
				      .item_code,
		       p_relation_type     => 'Substitute'
		       -----
		      ,
		       x_related_item_id   => l_related_item_id,
		       x_related_item_code => l_related_item_code,
		       x_related_item_desc => l_related_item_desc,
		       x_parent_item_id    => l_parent_item_id,
		       x_parent_item_code  => l_parent_item_code,
		       x_parent_item_desc  => l_parent_item_desc);
	  IF l_parent_item_id IS NOT NULL THEN
	    l_reservable_quantity := 0;
	  
	    --Check if the Parent Item Having Onhand Stock
	    FOR rec IN c_onhand_qry(l_parent_item_id,
			    rec_dist_inv_org.organization_id)
	    LOOP
	      l_reservable_quantity := l_reservable_quantity +
			       xxinv_utils_pkg.get_avail_to_reserve(p_inventory_item_id => rec.inventory_item_id,
						        p_organization_id   => rec.organization_id,
						        p_subinventory      => rec.secondary_inventory_name);
	    
	    END LOOP; --# Get the Summation of Reservable qty
	  
	    IF l_reservable_quantity > 0 THEN
	    
	      fnd_message.clear;
	      fnd_message.set_name('XXOBJT',
			   'XXOBJT_OA2SF_ONHAND_QUERY_003');
	      fnd_message.set_token('PARENT_ITEM_CODE',
			    l_parent_item_code);
	      fnd_message.set_token('PARENT_ITEM_DESC',
			    l_parent_item_desc);
	      fnd_message.set_token('RELATED_ITEM_CODE',
			    l_related_item_code);
	      fnd_message.set_token('RELATED_ITEM_DESC',
			    l_related_item_desc);
	    
	      l_attribute1 := fnd_message.get;
	      l_attribute1 := l_attribute1 ||
		          get_product_message(l_parent_item_id); --#CTASK0037719
	      write_log('Message Condition = 3 Satisfied');
	    
	    END IF;
	  
	  END IF;
	END IF;
          
          END IF;
        
          --Attribute1 Comment
          FOR j IN 1 .. l_onhand_details_t.count
          LOOP
	IF nvl(l_onhand_details_t(j).reservable_quantity, 0) = 0 AND
	   l_attribute1 IS NULL THEN
	  l_rec_cnt := l_rec_cnt + 1;
	  l_onhand_details_out.extend();
	  l_onhand_details_out(l_rec_cnt) := l_onhand_details_t(j);
	  l_onhand_details_out(l_rec_cnt).attribute1 := 'No Available stock';
	ELSE
	  l_rec_cnt := l_rec_cnt + 1;
	  l_onhand_details_out.extend();
	  l_onhand_details_out(l_rec_cnt) := l_onhand_details_t(j);
	
	  IF nvl(l_onhand_details_t(j).reservable_quantity, 0) > 0 THEN
	    l_onhand_details_out(l_rec_cnt).attribute1 := get_product_message(l_onhand_details_in(i)
						          .inventory_item_id);
	  ELSE
	    l_onhand_details_out(l_rec_cnt).attribute1 := l_attribute1;
	  END IF;
	
	END IF;
          END LOOP;
        
          l_attribute1 := NULL;
        END LOOP; --#2nd For Loop , Distinct Inv Org
      
      ELSE
        --If Validation Failed onhand Item Record need to assigned to Output  with Error Details
        l_rec_cnt := l_rec_cnt + 1;
        l_onhand_details_out.extend();
        l_onhand_details_out(l_rec_cnt) := l_onhand_details_in(i);
      END IF;
    END LOOP; --#1st For Loop , No of Records onhand Qry
  
    p_onhand_details := l_onhand_details_out;
  END strataforce_onhand_request;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0041332 - This procedure will fetch ohand reservable and/or transactable quantity
  --          for given item/items at Operating Unit/Inventory Org/Subinventory level.
  --          Inputs:  p_onhand_details => Table type containing item ID and Operating Unit, Inventory Org, Subinventory
  --                                       information.
  --                   p_onhand_level   => Valid values - OU / INV / SUBINV if NULL then processed at level till which data is sent in input p_onhand_details
  --                   p_onhand_type    => Valid values - A - ALL / R - RESERVABLE / T - TRANSACTABLE If ALL both reservable and transactable quantities sent
  --                   p_source_ref_id  => Requesting system reference ID
  --                   p_soa_ref_id     => SOA BPEL instance ID
  --                   p_source_system  => Source system name
  --          Outputs: x_onhand_details => Table type containing item ID and Operating Unit, Inventory Org, Subinventory
  --                                       information along with the corresponding quantities
  --                   x_status         => Request status - Valid values S/E
  --                   x_status_message => Request status message
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  10/26/2017  Diptasurjya Chatterjee (TCS)    CHG0041332 - Initial Build
  -- 1.1  14-May-2018 Lingaraj (TCS)                  CHG0042879 - Inventory Check From Sales Force to Oracle
  --                                                  New Parameter Added [p_global_availibility] Values Permitted Y or N
  -- 1.2  01-Aug-2018 Lingaraj                        CHG0042879[CTASK0037719] - New parameter to the interface,
  --                                                  add car stock and filter main warehouses per region
  -- 1.3  15-Jul-2019 Diptasurjya                     CHG0045755 - Add logic for calculation of PTO item onhand
  --                                                  Calculate the min on-hand quantity among all stockable components
  --                                                  of the parent PTO item
  -- 1.3  05-Feb-2019 Lingaraj                        CHG0046372-INC0146338-global_availibility = Yes
  --                                                  Should Support org_id & organization_id with out any Value
  -- 1.4  4.11.20     yuval tal                       CHG0048217  - change p_source_ref_id change type from number to varchar2
  -- --------------------------------------------------------------------------------------------

  PROCEDURE request_onhand_quantity(p_onhand_details         IN xxobjt.xxinv_onhand_tab_type,
			p_onhand_level           IN VARCHAR2 DEFAULT NULL,
			p_onhand_type            IN VARCHAR2 DEFAULT 'A',
			p_source_ref_id          IN VARCHAR2 DEFAULT NULL,
			p_soa_ref_id             IN NUMBER,
			p_source_system          IN VARCHAR2,
			p_global_availibility    IN VARCHAR2 DEFAULT 'No', -- Values Permitted Yes or No
			p_car_stock_availability IN VARCHAR2 DEFAULT 'No', --#CTASK0037719 Values Permitted Yes or No
			x_onhand_details         OUT xxobjt.xxinv_onhand_tab_type,
			x_status                 OUT VARCHAR2,
			x_status_message         OUT VARCHAR2) IS
    l_reservable_quantity   NUMBER := 0;
    l_transactable_quantity NUMBER := 0;
  
    l_source_system VARCHAR2(150);
  
    l_onhand_details_in xxobjt.xxinv_onhand_tab_type := xxobjt.xxinv_onhand_tab_type();
  
    l_validation_status  VARCHAR2(1);
    l_validation_message VARCHAR2(2000);
  
    e_validation_error EXCEPTION;
  BEGIN
    g_log_program_unit := 'request_onhand_quantity';
  
    l_onhand_details_in := p_onhand_details;
  
    /* Start - Validate input values */
    IF p_soa_ref_id IS NULL THEN
      x_status         := 'E';
      x_status_message := 'ERROR: SOA reference ID is mandatory' || chr(13);
      RETURN;
    END IF;
  
    IF l_onhand_details_in IS NULL OR l_onhand_details_in.count = 0 THEN
      x_status         := 'E';
      x_status_message := 'ERROR: At least 1 item is required for API to work' ||
		  chr(13);
    END IF;
  
    write_log('1. ' || l_onhand_details_in.count);
  
    validate_onhand_input(l_onhand_details_in,
		  p_source_system, -- Added a new Parameter on 05Feb19 #CHG0046372-INC0146338
		  p_global_availibility, -- Added a new Parameter on 05Feb19 #CHG0046372-INC0146338
		  l_validation_status,
		  l_validation_message);
  
    IF l_validation_status = 'E' THEN
      x_status         := 'E';
      x_status_message := 'ERROR: Unexpected error while validating input. Please contact system administrator. ' ||
		  l_validation_message || chr(13);
    END IF;
  
    IF p_onhand_level IS NOT NULL AND
       p_onhand_level NOT IN ('OU', 'INV', 'SUBINV') THEN
      x_status         := 'E';
      x_status_message := 'ERROR: Parameter Onahand Level should be blank or have valid values: OU, INV or SUBINV' ||
		  chr(13);
    END IF;
  
    IF p_onhand_type NOT IN ('A', 'R', 'T') THEN
      x_status         := 'E';
      x_status_message := 'ERROR: Valid values for parameter Onahand Tytpe are: A, R or T' ||
		  chr(13);
    END IF;
  
    IF p_source_system IS NULL THEN
      x_status         := 'E';
      x_status_message := 'ERROR: Source system is mandatory' || chr(13);
    ELSE
      BEGIN
        SELECT upper(ffv.flex_value)
        INTO   l_source_system
        FROM   fnd_flex_values_vl  ffv,
	   fnd_flex_value_sets ffvs
        WHERE  ffvs.flex_value_set_id = ffv.flex_value_set_id
        AND    ffvs.flex_value_set_name = 'XXSSYS_EVENT_TARGET_NAME'
        AND    ffv.enabled_flag = 'Y'
        AND    upper(ffv.flex_value) = upper(p_source_system)
        AND    SYSDATE BETWEEN nvl(ffv.start_date_active, SYSDATE - 1) AND
	   nvl(ffv.end_date_active, SYSDATE + 1);
      EXCEPTION
        WHEN no_data_found THEN
          x_status         := 'E';
          x_status_message := 'ERROR: Source system is not valid' ||
		      chr(13);
      END;
    END IF;
  
    IF x_status = 'E' THEN
      write_log('SOA BPEL Instance ID: ' || p_soa_ref_id || ' :: ' ||
	    x_status_message);
      RETURN;
    END IF;
    /* End - Validate input values */
  
    write_log('2. ' || l_onhand_details_in.count || ' ' ||
	  l_validation_status);
  
    IF l_source_system != 'STRATAFORCE' THEN
      --    CHG0048217 --= 'HYBRIS' THEN -- yuval 
      --CHG0042879 # If Condition Added
      FOR i IN 1 .. l_onhand_details_in.count
      LOOP
        write_log('3. ' || p_source_system || ' ' ||
	      l_onhand_details_in.count || ' ' || l_onhand_details_in(i)
	      .status);
      
        IF l_onhand_details_in(i).status = 'S' THEN
          write_log('3.1 ' || p_source_system || ' ' ||
	        l_onhand_details_in.count || ' ' || l_onhand_details_in(i)
	        .status);
        
          write_log('4. ' || l_onhand_details_in(i).inventory_item_id || ' ' || l_onhand_details_in(i)
	        .org_id || ' ' ||
	        nvl(l_onhand_details_in(i).organization_id, 0) || ' ' ||
	        nvl(to_char(l_onhand_details_in(i).subinventory_code),
		'-'));
        
          -- CHG0045755 start - check item BOM type
          IF is_item_bom_type_valid(l_onhand_details_in(i).inventory_item_id) = 'Y' THEN
	-- item is PTO model or KIT
	FOR subinv_rec IN (SELECT ood.organization_id,
			  ood.operating_unit,
			  msi.secondary_inventory_name
		       FROM   org_organization_definitions ood,
			  mtl_secondary_inventories    msi
		       WHERE  ood.organization_id =
			  msi.organization_id
		       AND    msi.attribute11 = 'Y'
		       AND    ood.operating_unit = l_onhand_details_in(i)
			 .org_id
		       AND    ood.organization_id =
			  nvl(l_onhand_details_in(i)
			       .organization_id,
			       ood.organization_id)
		       AND    msi.secondary_inventory_name =
			  nvl(l_onhand_details_in(i)
			       .subinventory_code,
			       msi.secondary_inventory_name)
		       AND    nvl(msi.disable_date, trunc(SYSDATE)) >=
			  trunc(SYSDATE))
	LOOP
	
	  SELECT l_reservable_quantity + MIN(atr),
	         l_transactable_quantity + MIN(att)
	  INTO   l_reservable_quantity,
	         l_transactable_quantity
	  FROM   (SELECT bbo.assembly_item_id,
		     bic.component_item_id,
		     decode(p_onhand_type,
			'T',
			0,
			nvl(xxinv_utils_pkg.get_avail_to_reserve(p_inventory_item_id => bic.component_item_id,
						     p_organization_id   => subinv_rec.organization_id,
						     p_subinventory      => subinv_rec.secondary_inventory_name),
			    0)) atr,
		     decode(p_onhand_type,
			'R',
			0,
			nvl(xxinv_utils_pkg.get_avail_to_transact(p_inventory_item_id => bic.component_item_id,
						      p_organization_id   => subinv_rec.organization_id,
						      p_subinventory      => subinv_rec.secondary_inventory_name),
			    0)) att
	          FROM   bom_bill_of_materials_v    bbo,
		     bom_inventory_components_v bic,
		     mtl_system_items_b         msib_c
	          WHERE  bbo.bill_sequence_id = bic.bill_sequence_id
	          AND    bbo.assembly_item_id = l_onhand_details_in(i)
		    .inventory_item_id
	          AND    bbo.organization_id =
		     xxinv_utils_pkg.get_master_organization_id
	          AND    msib_c.organization_id = bbo.organization_id
	          AND    msib_c.inventory_item_id =
		     bic.component_item_id
	          AND    msib_c.stock_enabled_flag = 'Y'
	          AND    SYSDATE BETWEEN
		     nvl(bic.implementation_date, SYSDATE - 1) AND
		     nvl(bic.disable_date, SYSDATE + 1))
	  GROUP  BY assembly_item_id;
	
	END LOOP;
	-- CHG0045755 end
          ELSE
	-- CHG0045755 item is not PTO
	FOR rec IN (SELECT msib.inventory_item_id,
		       ood.organization_id,
		       ood.operating_unit,
		       msi.secondary_inventory_name
		FROM   org_organization_definitions ood,
		       mtl_secondary_inventories    msi,
		       mtl_system_items_b           msib
		WHERE  msib.organization_id = ood.organization_id
		AND    ood.organization_id = msi.organization_id
		AND    msi.attribute11 = 'Y'
		AND    msib.inventory_item_id = l_onhand_details_in(i)
		      .inventory_item_id
		AND    ood.operating_unit = l_onhand_details_in(i)
		      .org_id
		AND    ood.organization_id =
		       nvl(l_onhand_details_in(i).organization_id,
			ood.organization_id)
		AND    msi.secondary_inventory_name =
		       nvl(l_onhand_details_in(i).subinventory_code,
			msi.secondary_inventory_name)
		AND    nvl(msi.disable_date, trunc(SYSDATE)) >=
		       trunc(SYSDATE))
	LOOP
	  write_log('5. ' || p_onhand_type || ' ' ||
		rec.inventory_item_id || ' ' ||
		rec.organization_id || ' ' ||
		rec.secondary_inventory_name);
	
	  IF p_onhand_type IN ('A', 'R') THEN
	    l_reservable_quantity := l_reservable_quantity +
			     xxinv_utils_pkg.get_avail_to_reserve(p_inventory_item_id => rec.inventory_item_id,
						      p_organization_id   => rec.organization_id,
						      p_subinventory      => rec.secondary_inventory_name);
	  END IF;
	
	  IF p_onhand_type IN ('A', 'T') THEN
	    l_transactable_quantity := l_transactable_quantity +
			       xxinv_utils_pkg.get_avail_to_transact(p_inventory_item_id => rec.inventory_item_id,
						         p_organization_id   => rec.organization_id,
						         p_subinventory      => rec.secondary_inventory_name);
	  END IF;
	
	  write_log('5.1 ' || l_reservable_quantity);
	END LOOP;
          
          END IF; -- CHG0045755 end if
          write_log('6. ');
          --end if;
        
          l_onhand_details_in(i).reservable_quantity := l_reservable_quantity;
          l_onhand_details_in(i).transactable_quantity := l_transactable_quantity;
        
          l_reservable_quantity   := 0; -- CHG0045755  added
          l_transactable_quantity := 0; -- CHG0045755  added
        END IF;
      END LOOP;
    
      --CHG0042879 # STRATAFORCE condition added
    ELSIF l_source_system = 'STRATAFORCE' THEN
      strataforce_onhand_request(p_onhand_details         => l_onhand_details_in,
		         p_global_availibility    => p_global_availibility,
		         p_car_stock_availability => p_car_stock_availability,
		         p_source_system          => l_source_system,
		         p_onhand_type            => p_onhand_type);
    END IF;
    x_onhand_details := l_onhand_details_in;
    x_status         := 'S';
  EXCEPTION
    WHEN OTHERS THEN
      x_onhand_details := NULL;
      x_status         := 'E';
      x_status_message := 'UNEXPECTED ERROR: ' || SQLERRM;
      write_log(x_status_message);
  END request_onhand_quantity;

END xxinv_soa_onhand_pkg;
/
