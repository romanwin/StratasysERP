CREATE OR REPLACE PACKAGE BODY xxhz_party_ga_util AS
  --------------------------------------------------------------------
  -- $Header: http://sv-glo-tools01p.stratasys.dmn/svn/ERP/ebs/database/apps/packages/xxhz_party_ga_util.bdy 3431 2017-06-05 08:38:19Z yuval.tal $
  --------------------------------------------------------------------
  --  name:            XXHZ_PARTY_GA_UTIL
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   26.12.10
  --------------------------------------------------------------------
  --  purpose :        global account pricing
  --------------------------------------------------------------------
  --  ver  date        name         desc
  --  1.0  26.12.10    yuval tal    initial build
  --  1.1  2.1.2011    yuval tal    add p_agreement to chk_sys_agreement_ga_interval+get_ga_system_agreement_cnt
  --                                get_ga_system_agreement_cnt add logic
  --  1.2  05/07/2011  Dalit A. Raviv  add functions: get_primary_party_id
  --                                                  get_secondary_party_id
  --                                                  get_party_is_vested
  --  1.3  02/10/2011  Dalit A. Raviv  add function get_constant_discount
  --  1.4  19/01/2012  Dalit A. RAviv  add function is_vip
  --                                   Procedure update_vip_ga_party
  --  1.5  12/09/2013  Adi Safin       add function is_vip_without_ga
  --  1.6  09/07/2014  Gary Altman     CHG0032654 - check attributes value for SAM customers
  --------------------------------------------------------------------

  -------------------------------------------
  -- get_parent_party
  -------------------------------------------
  CURSOR c_ga_parties_relate(c_cust_account_id NUMBER) IS
    SELECT DISTINCT g.party_id
    FROM   xxhz_party_ga_v g
    WHERE  g.parent_party_id =
           get_parent_party_id(get_party_id(c_cust_account_id));

  ------------------------------------------
  -- get_parent_party_id
  ------------------------------------------

  FUNCTION get_parent_party_id(p_party_id NUMBER) RETURN NUMBER IS
    l_parent_id NUMBER;
  BEGIN
    SELECT tt.parent_party_id
    INTO   l_parent_id
    FROM   xxhz_party_ga_v tt
    WHERE  tt.party_id = p_party_id;
  
    RETURN l_parent_id;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN p_party_id;
  END;

  ------------------------------------------
  -- check_sam_attributes
  -- 1.6  09/07/2014  Gary Altman  CHG0032654
  ------------------------------------------

  FUNCTION check_sam_attribute(p_party_id NUMBER) RETURN VARCHAR2 IS
    l_result VARCHAR2(50);
  BEGIN
    SELECT CASE to_number(decode(hpv.xxglobal_account, 'Y', 1, 0)) +
	to_number(decode(hpv.xxkam_customer, 'Y', 2, 0))
	 WHEN 1 THEN
	  'Global Account'
	 WHEN 2 THEN
	  'Key Account'
	 WHEN 3 THEN
	  'Duplicate'
	 ELSE
	  NULL
           END
    INTO   l_result
    FROM   hz_parties     hp,
           hz_parties_dfv hpv
    WHERE  hp.party_id = p_party_id
    AND    hp.rowid = hpv.row_id;
  
    RETURN l_result;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN l_result;
  END check_sam_attribute;

  ------------------------------------------
  -- get_parent_party_id4cust
  ------------------------------------------

  FUNCTION get_parent_party_id4cust(p_cust_account_id NUMBER) RETURN NUMBER IS
    l_parent_id NUMBER;
  BEGIN
    SELECT tt.parent_party_id
    INTO   l_parent_id
    FROM   xxhz_party_ga_v tt
    WHERE  tt.cust_account_id = p_cust_account_id;
  
    RETURN l_parent_id;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
  END;

  -------------------------------------------
  -- get_party_name
  -------------------------------------------
  FUNCTION get_party_name(p_party_id   NUMBER,
		  p_party_type VARCHAR2 DEFAULT 'ORGANIZATION')
    RETURN VARCHAR2 IS
    l_name hz_parties.party_name%TYPE;
  BEGIN
    SELECT party_name
    INTO   l_name
    FROM   hz_parties t
    WHERE  t.party_id = p_party_id
    AND    t.party_type = p_party_type;
    RETURN l_name;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN - 1;
  END;

  ---------------------------------
  -- get_party_name4account
  ---------------------------------
  FUNCTION get_party_name4account(p_cust_account_id NUMBER) RETURN VARCHAR2 IS
    l_party_id hz_parties.party_id%TYPE;
  BEGIN
    SELECT party_id
    INTO   l_party_id
    FROM   hz_cust_accounts t
    WHERE  t.cust_account_id = p_cust_account_id;
  
    RETURN get_party_name(l_party_id);
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN - 1;
  END;

  -------------------------------------------------------------
  -- get_resin_kg_sold2party
  -------------------------------------------------------------

  FUNCTION get_ga_resin_kg_sold2party(p_party_id NUMBER) RETURN NUMBER IS
    l_sum NUMBER;
  BEGIN
  
    /* SELECT SUM(qp_sourcing_api_pub.get_line_weight_or_volume('Volume',
                                                            ola.inventory_item_id,
                                                            ola.ordered_quantity,
                                                            ola.pricing_quantity_uom)) --line_weight
     INTO l_kg
    
     FROM oe_order_lines_all   ola,
          oe_order_headers_all oha,
          xxhz_party_ga_v      rel
    WHERE rel.cust_account_id = oha.sold_to_org_id
      AND rel.party_id = p_party_id
      AND ola.header_id = oha.header_id
      AND is_resin_item(ola.inventory_item_id) = 'Y'
      AND ola.flow_status_code = 'CLOSED'
      AND ola.actual_shipment_date >=
          greatest(fnd_date.canonical_to_date(rel.ga_start_date),
                   add_months(SYSDATE, -12));*/
  
    SELECT SUM(t.kg)
    INTO   l_sum
    FROM   xxhz_party_ga_resin_details_v t
    WHERE  t.party_id = p_party_id;
  
    RETURN l_sum;
  
  END;
  --------------------------------------
  --get_resin_lines4order
  --------------------------------------
  FUNCTION get_system_lines4order(p_header_id         NUMBER,
		          p_inventory_item_id NUMBER) RETURN NUMBER IS
    l_count NUMBER;
  BEGIN
    SELECT COUNT(*)
    INTO   l_count
    FROM   oe_order_lines_all t
    WHERE  t.header_id = p_header_id
    AND    t.inventory_item_id = p_inventory_item_id
          
    AND    nvl(t.cancelled_flag, 'N') = 'N';
  
    RETURN greatest(1, nvl(l_count, 1), 0);
  END;

  -------------------------------------------
  -- get_resin_kg_sold2ga
  ----------------------------------------------

  FUNCTION get_ga_resin_kg_sold2account(p_cust_account_id NUMBER)
    RETURN NUMBER IS
  
    l_sum NUMBER := 0;
  
  BEGIN
  
    /* SELECT SUM(qp_sourcing_api_pub.get_line_weight_or_volume('Volume',
                                                            ola.inventory_item_id,
                                                            ola.ordered_quantity,
                                                            ola.pricing_quantity_uom)) --line_weight
     INTO l_sum
    
     FROM oe_order_lines_all   ola,
          oe_order_headers_all oha,
          xxhz_party_ga_v      rel
    WHERE rel.cust_account_id = oha.sold_to_org_id
      AND rel.cust_account_id = p_cust_account_id
      AND ola.header_id = oha.header_id
      AND is_resin_item(ola.inventory_item_id) = 'Y'
      AND ola.flow_status_code = 'CLOSED'
      AND SYSDATE >= add_months(ola.actual_shipment_date, -12)
      AND ola.actual_shipment_date >=
          fnd_date.canonical_to_date(rel.ga_start_date);*/
  
    SELECT SUM(t.kg)
    INTO   l_sum
    FROM   xxhz_party_ga_resin_details_v t
    WHERE  t.cust_account_id = p_cust_account_id;
  
    RETURN l_sum;
  END;
  --------------------------------------
  -- is_account_ga
  ----------------------------------------

  FUNCTION is_account_ga(p_cust_account_id NUMBER,
		 p_to_date         DATE DEFAULT SYSDATE)
    RETURN VARCHAR2 IS
    l_flag VARCHAR2(1);
  BEGIN
  
    SELECT 'Y'
    INTO   l_flag
    FROM   xxhz_party_ga_v t
    WHERE  t.cust_account_id = p_cust_account_id
    AND    t.ga_start_date <= p_to_date;
  
    RETURN l_flag;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN 'N';
    WHEN too_many_rows THEN
      RETURN 'Y';
    
  END;

  --------------------------------------
  -- is_account_ga
  ----------------------------------------

  FUNCTION is_party_ga(p_party_id NUMBER,
	           p_to_date  DATE DEFAULT SYSDATE) RETURN VARCHAR2 IS
    l_flag VARCHAR2(1);
  BEGIN
  
    SELECT 'Y'
    INTO   l_flag
    FROM   xxhz_party_ga_v t
    WHERE  t.party_id = p_party_id
    AND    t.ga_start_date <= p_to_date;
  
    RETURN l_flag;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN 'N';
    WHEN too_many_rows THEN
      RETURN 'Y';
    
  END;
  ---------------------------------------
  -- is_resin_item
  ---------------------------------------
  FUNCTION is_resin_item(p_item_id NUMBER) RETURN VARCHAR2 IS
    l_ret VARCHAR2(10);
  BEGIN
    SELECT 'Y'
    INTO   l_ret --msi.segment1, mcv.description
    FROM   mtl_system_items_b  msi,
           mtl_item_categories mic,
           mtl_categories_v    mcv
    WHERE  msi.inventory_item_id = mic.inventory_item_id
    AND    msi.organization_id = mic.organization_id
    AND    mic.category_set_id = 1100000041 -- Objet Main Item Category
    AND    mcv.description LIKE '%Resins%'
    AND    mcv.category_id = mic.category_id
    AND    msi.segment1 LIKE 'OBJ%'
    AND    msi.organization_id = xxinv_utils_pkg.get_master_organization_id -- Master_org
    AND    msi.inventory_item_id = p_item_id;
    RETURN l_ret;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN 'N';
    
    WHEN too_many_rows THEN
      RETURN 'Y';
    
  END;
  ---------------------------------------
  -- is_system_item
  -- 30.4.17 yuval tal           CHG0040061 : modify to call item classification pkg
  -- originly is_system hold polyjet-system 
  ---------------------------------------
  FUNCTION is_system_item(p_item_id NUMBER) RETURN VARCHAR2 IS
    l_ret VARCHAR2(10);
  
    /*  SELECT 'Y'
        INTO l_ret
        FROM mtl_system_items_b msi, mtl_item_categories_v mic
       WHERE mic.inventory_item_id = msi.inventory_item_id
         AND msi.organization_id = mic.organization_id
         AND msi.organization_id = 91 --OMA
         AND mic.category_set_id = 1100000041 -- Main Category Set
         AND mic.category_concat_segs LIKE 'Systems%'
         AND msi.item_type = 'XXOBJ_SYS_FG'
         AND msi.inventory_item_id = p_item_id;
      RETURN l_ret;
    EXCEPTION
      WHEN no_data_found THEN
        RETURN 'N';
    
      WHEN too_many_rows THEN
        RETURN 'Y';*/
  
    l_master_org_id NUMBER;
  BEGIN
  
    l_master_org_id := xxinv_utils_pkg.get_master_organization_id;
  
    IF xxinv_item_classification.is_system_item(p_item_id, l_master_org_id) = 'Y' AND
       xxinv_item_classification.is_item_polyjet(p_item_id, l_master_org_id) = 'Y' THEN
      RETURN 'Y';
    
    ELSE
      RETURN 'N';
    END IF;
  
  END;
  --------------------------------------
  --get_resin_lines4order
  --------------------------------------
  FUNCTION get_resin_lines4order(p_header_id NUMBER) RETURN NUMBER IS
    l_count NUMBER;
  BEGIN
    SELECT COUNT(*)
    INTO   l_count
    FROM   oe_order_lines_all t
    WHERE  t.header_id = p_header_id
    AND    is_resin_item(t.inventory_item_id) = 'Y'
    AND    nvl(t.cancelled_flag, 'N') = 'N';
  
    RETURN greatest(1, nvl(l_count, 1), 0);
  END;

  -------------------------------------------
  -- get_line_weight_or_volume
  -- for advanced price calc
  -- add average GA consumption
  -- -------------------------------------------------------
  FUNCTION get_line_weight_or_volume(p_uom_class          IN VARCHAR2,
			 p_inventory_item_id  IN NUMBER,
			 p_ordered_quantity   IN NUMBER,
			 p_order_quantity_uom IN VARCHAR2,
			 p_sold_to_org_id     IN NUMBER,
			 p_header_id          IN NUMBER)
    RETURN NUMBER IS
    l_rowcount              NUMBER;
    l_ga_qty                NUMBER;
    l_ordered_quantity_calc NUMBER;
  BEGIN
  
    -- get ga quantity
    l_ga_qty                := get_ga_resin_kg_sold2account(p_sold_to_org_id);
    l_rowcount              := get_resin_lines4order(p_header_id);
    l_ordered_quantity_calc := nvl((l_ga_qty / l_rowcount), 0);
    -- get divide qty
    RETURN l_ordered_quantity_calc + to_char(qp_sourcing_api_pub.get_line_weight_or_volume(p_uom_class,
							       p_inventory_item_id,
							       p_ordered_quantity,
							       p_order_quantity_uom));
  
  END;

  -----------------------------------------------
  -- get party_id
  -----------------------------------------------
  FUNCTION get_party_id(p_cust_account_id NUMBER) RETURN NUMBER IS
    l_party_id NUMBER;
  BEGIN
  
    SELECT party_id
    INTO   l_party_id
    FROM   hz_cust_accounts acc
    WHERE  acc.cust_account_id = p_cust_account_id;
    RETURN l_party_id;
  EXCEPTION
    WHEN OTHERS THEN
    
      RETURN NULL;
  END;
  --------------------------------------------------
  -- get_ststem_ib4party

  -- count all system for specific party
  -------------------------------------------------

  FUNCTION get_system_ib4party(p_party_id NUMBER) RETURN NUMBER IS
    l_count NUMBER;
  BEGIN
  
    /* SELECT COUNT(*)
     INTO l_count
     FROM csi_item_instances cii, hz_parties p
    WHERE cii.owner_party_id = p.party_id
         --  AND cii.inventory_item_id = p_inventory_item_id
      AND is_system_item(cii.inventory_item_id) = 'Y'
      AND SYSDATE < nvl(cii.active_end_date, SYSDATE + 1)
      AND p.party_id = p_party_id;*/
  
    SELECT COUNT(*)
    INTO   l_count
    FROM   csi_item_instances cii,
           csi_systems_b      csb
    WHERE  is_system_item(cii.inventory_item_id) = 'Y'
    AND    SYSDATE < nvl(cii.active_end_date, SYSDATE + 1)
    AND    cii.system_id = csb.system_id
    AND    csb.attribute2 = p_party_id;
  
    RETURN nvl(l_count, 0);
  END;
  ----------------------------------------------------
  -- get_ststem_ga_ib4party

  -- count all system for all related parties to p_cust_account_id
  -----------------------------------------------------

  FUNCTION get_system_ga_ib4acc(p_cust_account_id NUMBER) RETURN NUMBER IS
    l_count NUMBER := 0;
  BEGIN
    FOR i IN c_ga_parties_relate(p_cust_account_id) LOOP
    
      l_count := l_count + get_system_ib4party(i.party_id);
    
    END LOOP;
  
    -- group by party_id,period
    RETURN l_count;
  END;

  ----------------------------------------------------------
  -- get_line_system_count
  ---------------------------------------------------------

  FUNCTION get_line_ga_system_count(p_inventory_item_id NUMBER,
			p_ordered_quantity  IN NUMBER,
			p_sold_to_org_id    IN NUMBER,
			p_header_id         IN NUMBER)
    RETURN NUMBER IS
    l_rowcount         NUMBER;
    l_ga_sys_count     NUMBER;
    l_ga_sys_count_rel NUMBER;
  BEGIN
    l_rowcount         := get_system_lines4order(p_header_id,
				 p_inventory_item_id);
    l_ga_sys_count     := get_system_ga_ib4acc(p_cust_account_id => p_sold_to_org_id);
    l_ga_sys_count_rel := l_ga_sys_count / l_rowcount;
    RETURN l_ga_sys_count_rel + p_ordered_quantity;
  
  END;

  ----------------------------------------------------------
  -- get_line_system_count2
  ---------------------------------------------------------

  FUNCTION get_line_ga_system_count2(p_sold_to_org_id IN NUMBER,
			 p_header_id      IN NUMBER,
			 p_line_number    NUMBER) RETURN NUMBER IS
  
    l_ga_sys_count   NUMBER;
    l_order_qty      NUMBER;
    l_ga_sys_related NUMBER;
  BEGIN
    l_ga_sys_related := get_system_ga4related_orders(p_sold_to_org_id,
				     p_header_id);
  
    l_ga_sys_count := get_system_ga_ib4acc(p_cust_account_id => p_sold_to_org_id);
  
    SELECT SUM(t.ordered_quantity)
    INTO   l_order_qty
    FROM   oe_order_lines_all t
    WHERE  t.header_id = p_header_id
          -- AND t.inventory_item_id = p_inventory_item_id
    AND    is_system_item(t.inventory_item_id) = 'Y'
    AND    nvl(t.cancelled_flag, 'N') = 'N'
    AND    t.line_number <= p_line_number;
  
    RETURN l_ga_sys_count + nvl(l_order_qty, 0) + l_ga_sys_related;
  
  END;
  -----------------------------------------------------------
  -- get_system_ga4related_orders

  -- count all system  in  orders NOT IN status ('ENTERED', 'CLOSED', 'CANCELLED')
  -- for all related parties to p_sold_to_org_id except order p_header_id
  ------------------------------------------------------------------
  FUNCTION get_system_ga4related_orders(p_sold_to_org_id IN NUMBER,
			    p_header_id      IN NUMBER)
    RETURN NUMBER IS
  
    l_order_qty NUMBER;
  BEGIN
  
    SELECT SUM(t.ordered_quantity)
    INTO   l_order_qty
    FROM   oe_order_headers_all h,
           oe_order_lines_all   t,
           xxhz_party_ga_v      g
    WHERE  h.header_id = t.header_id
    AND    t.header_id != p_header_id
          --  AND t.inventory_item_id = p_inventory_item_id
    AND    xxhz_party_ga_util.is_system_item(t.inventory_item_id) = 'Y'
    AND    nvl(t.cancelled_flag, 'N') = 'N'
    AND    t.flow_status_code NOT IN ('ENTERED', 'CLOSED', 'CANCELLED')
          
    AND    g.parent_party_id =
           xxhz_party_ga_util.get_parent_party_id4cust(p_sold_to_org_id)
    AND    g.cust_account_id = h.sold_to_org_id;
  
    RETURN nvl(l_order_qty, 0);
  
  END;
  -----------------------------------------------------------
  -- get_ga_system_count_string
  ------------------------------------------------------------------

  FUNCTION get_ga_system_count_string(p_cust_account_id NUMBER)
    RETURN VARCHAR2 IS
  
    CURSOR c_sys IS
      SELECT msi.segment1 || ' (' || msi.description || ')' segment1,
	 cii.inventory_item_id,
	 COUNT(*) cnt
      FROM   csi_item_instances cii,
	 hz_parties         p,
	 mtl_system_items_b msi,
	 xxhz_party_ga_v    rel
      WHERE  msi.organization_id = 91
      AND    msi.inventory_item_id = cii.inventory_item_id
      AND    cii.owner_party_id = p.party_id
      AND    xxhz_party_ga_util.is_system_item(cii.inventory_item_id) = 'Y'
      AND    SYSDATE < nvl(cii.active_end_date, SYSDATE + 1)
      AND    p.party_id = rel.party_id
      AND    rel.cust_account_id = p_cust_account_id
      GROUP  BY msi.segment1 || ' (' || msi.description || ')',
	    cii.inventory_item_id;
    l_tmp VARCHAR2(1000);
  BEGIN
  
    FOR i IN c_sys LOOP
      l_tmp := l_tmp || i.segment1 || ' - ' || i.cnt || chr(10) || chr(13);
    
    END LOOP;
    RETURN l_tmp;
  
  END;

  ------------------------------------------------------
  -- get_ga_system_agreement_cnt
  -------------------------------------------------------

  FUNCTION get_ga_system_agreement_cnt(p_cust_account_id NUMBER,
			   p_agreement_id    NUMBER)
    RETURN VARCHAR2 IS
  
    l_tmp  NUMBER;
    l_tmp2 NUMBER;
  BEGIN
  
    SELECT COUNT(cii.instance_id) num
    INTO   l_tmp
    FROM   okc_k_headers_all_b h,
           okc_k_lines_b       l1,
           okc_k_lines_b       l2,
           okc_k_items         oki1, --IB
           okc_k_items         oki2, --Contract
           csi_item_instances  cii,
           hz_cust_accounts    hca,
           mtl_system_items_b  msib,
           mtl_item_categories mic,
           mtl_categories_b    mcb,
           xxhz_party_ga_v     rel
    WHERE  h.id = l1.dnz_chr_id
    AND    oki1.object1_id1 = cii.instance_id
    AND    oki1.cle_id = l1.id
    AND    oki1.object1_id1 = cii.instance_id
    AND    oki2.cle_id = l2.id
    AND    l2.chr_id = h.id
    AND    l1.sts_code IN ('ACTIVE', 'SIGNED')
    AND    cii.owner_party_id = hca.party_id
    AND    mcb.category_id = mic.category_id
    AND    mcb.attribute4 = 'PRINTER'
    AND    msib.inventory_item_id = mic.inventory_item_id
    AND    cii.inventory_item_id = msib.inventory_item_id
    AND    msib.organization_id = 91
    AND    mic.organization_id = msib.organization_id
    AND    h.scs_code = 'SERVICE'
    AND    xxhz_party_ga_util.is_system_item(cii.inventory_item_id) = 'Y'
    AND    cii.owner_party_id = rel.party_id
    AND    rel.cust_account_id = p_cust_account_id;
  
    SELECT COUNT(cii.instance_id) num
    INTO   l_tmp2
    FROM   okc_k_headers_all_b h,
           okc_k_lines_b       l1,
           okc_k_lines_b       l2,
           okc_k_items         oki1, --IB
           okc_k_items         oki2, --Contract
           csi_item_instances  cii,
           hz_cust_accounts    hca,
           mtl_system_items_b  msib,
           mtl_item_categories mic,
           mtl_categories_b    mcb,
           xxhz_party_ga_v     rel
    WHERE  h.id = l1.dnz_chr_id
    AND    oki1.object1_id1 = cii.instance_id
    AND    oki1.cle_id = l1.id
    AND    oki1.object1_id1 = cii.instance_id
    AND    oki2.cle_id = l2.id
    AND    l2.chr_id = h.id
    AND    l1.sts_code = 'ENTERED'
    AND    cii.owner_party_id = hca.party_id
    AND    mcb.category_id = mic.category_id
    AND    mcb.attribute4 = 'PRINTER'
    AND    msib.inventory_item_id = mic.inventory_item_id
    AND    cii.inventory_item_id = msib.inventory_item_id
    AND    msib.organization_id = 91
    AND    mic.organization_id = msib.organization_id
    AND    h.scs_code = 'SERVICE'
    AND    xxhz_party_ga_util.is_system_item(cii.inventory_item_id) = 'Y'
    AND    cii.owner_party_id = rel.party_id
    AND    rel.cust_account_id = p_cust_account_id
    AND    h.id = p_agreement_id;
  
    RETURN nvl(l_tmp2, 0) + nvl(l_tmp, 0);
  
  END;

  -----------------------------------------------------------
  -- check_sys_ga_interval
  ----------------------------------------------------------
  FUNCTION chk_sys_agreement_ga_interval(p_cust_account_id NUMBER,
			     p_min             NUMBER,
			     p_max             NUMBER,
			     p_agreement_id    NUMBER)
    RETURN VARCHAR2 IS
    l_get_ga_system_agreement_cnt NUMBER;
  BEGIN
    l_get_ga_system_agreement_cnt := get_ga_system_agreement_cnt(p_cust_account_id,
					     p_agreement_id);
    IF l_get_ga_system_agreement_cnt > p_min AND
       l_get_ga_system_agreement_cnt <= p_max THEN
      RETURN 'Y';
    ELSE
      RETURN 'N';
    END IF;
  END;

  --------------------------------------------------------------------
  --  name:            get average resin discount
  --  create by:       Yuval Tal
  --  Revision:        1.0
  --  creation date:   xx/xx/2011
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  xx/xx/2011  Yuval Tal       initial build
  --  1.1  21/07/2011  Yuval Tal       correct calculation
  --  1.2  02/10/2011  Dalit A. Raviv  Add parameter p_party_id
  --------------------------------------------------------------------
  FUNCTION get_ga_average_discount(p_amount   NUMBER,
		           p_date     DATE,
		           p_party_id NUMBER) RETURN NUMBER IS
    CURSOR c_pct IS
      SELECT h.name,
	 l.start_date_active,
	 l.end_date_active,
	 t.pricing_attr_value_from,
	 nvl(t.pricing_attr_value_to, 99999999999999999) pricing_attr_value_to,
	 t.operand
      FROM   qp_price_breaks_v       t,
	 qp_secu_list_headers_vl h,
	 qp_modifier_summary_v   l
      WHERE  h.list_header_id = l.list_header_id
      AND    l.list_line_id = t.parent_list_line_id
      AND    h.list_header_id = t.list_header_id
      AND    h.name =
	 fnd_profile.value('XX_GA_RESIN_AVERAGE_DISCOUNT_TABLE')
      AND    p_date BETWEEN l.start_date_active AND
	 nvl(l.end_date_active, SYSDATE + 99999)
      ORDER  BY to_number(t.pricing_attr_value_from);
  
    l_amount            NUMBER;
    l_interval          NUMBER;
    l_sum               NUMBER;
    l_constant_discount NUMBER;
  
  BEGIN
  
    l_amount := p_amount;
    l_sum    := 0;
    FOR i IN c_pct LOOP
      EXIT WHEN l_amount = 0;
      l_interval := least(to_number(i.pricing_attr_value_to) -
		  to_number(i.pricing_attr_value_from),
		  l_amount);
      l_sum      := l_sum + (l_interval * i.operand);
      l_amount   := l_amount - l_interval;
    END LOOP;
  
    -- 1.2  02/10/2011  Dalit A. Raviv  Add parameter p_party_id
    -- get party constant discount
    -- if there is no discount return avg discount (what you found)
    -- if avg discount is less or equal to constant discount return 0
    -- if avg discount is grater then constant discount return avg_discount - constant
  
    IF p_party_id IS NULL THEN
      RETURN round(l_sum / p_amount, 2);
    ELSE
      l_constant_discount := xxhz_party_ga_util.get_constant_discount(p_party_id);
    
      IF l_constant_discount = 0 THEN
        RETURN round(l_sum / p_amount, 2);
      ELSIF (round(l_sum / p_amount, 2)) <= l_constant_discount THEN
        RETURN 0;
      ELSIF (round(l_sum / p_amount, 2)) > l_constant_discount THEN
        RETURN(round(l_sum / p_amount, 2)) - l_constant_discount;
      END IF;
    END IF;
    -- end 1.2
    --RETURN round(l_sum / p_amount, 2);
  END get_ga_average_discount;

  FUNCTION get_ga_discount_steps(p_amount   NUMBER,
		         p_date     DATE,
		         p_party_id NUMBER) RETURN NUMBER IS
    CURSOR c_pct IS
      SELECT h.name,
	 l.start_date_active,
	 l.end_date_active,
	 t.pricing_attr_value_from,
	 nvl(t.pricing_attr_value_to, 99999999999999999) pricing_attr_value_to,
	 t.operand
      FROM   qp_price_breaks_v       t,
	 qp_secu_list_headers_vl h,
	 qp_modifier_summary_v   l
      WHERE  h.list_header_id = l.list_header_id
      AND    l.list_line_id = t.parent_list_line_id
      AND    h.list_header_id = t.list_header_id
      AND    h.name =
	 fnd_profile.value('XX_GA_RESIN_AVERAGE_DISCOUNT_TABLE')
      AND    p_date BETWEEN l.start_date_active AND
	 nvl(l.end_date_active, SYSDATE + 99999)
      ORDER  BY to_number(t.pricing_attr_value_from);
  
    l_amount            NUMBER;
    l_interval          NUMBER;
    l_sum               NUMBER;
    l_constant_discount NUMBER;
    l_new_discount      NUMBER;
  
  BEGIN
  
    l_amount := p_amount;
    l_sum    := 0;
    FOR i IN c_pct LOOP
      EXIT WHEN l_amount = 0;
      l_interval := least(to_number(i.pricing_attr_value_to) -
		  to_number(i.pricing_attr_value_from),
		  l_amount);
      l_sum      := l_sum + (l_interval * i.operand);
      l_amount   := l_amount - l_interval;
    END LOOP;
  
    IF p_party_id IS NULL THEN
      RETURN round(l_sum / p_amount, 2);
    ELSE
      l_constant_discount := xxhz_party_ga_util.get_constant_discount(p_party_id);
    
      -- Calculate the discount according to steps instead of average
    
      IF p_amount <= 300 THEN
        l_new_discount := 0;
      ELSIF p_amount BETWEEN 301 AND 600 THEN
        l_new_discount := 5;
      ELSIF p_amount BETWEEN 601 AND 900 THEN
        l_new_discount := 10;
      ELSIF p_amount BETWEEN 901 AND 1200 THEN
        l_new_discount := 15;
      ELSIF p_amount >= 1201 THEN
        l_new_discount := 20;
      END IF;
    
      IF l_constant_discount = 0 THEN
        RETURN l_new_discount;
      ELSIF l_new_discount <= round(l_constant_discount) THEN
        RETURN 0;
      ELSIF l_new_discount > l_constant_discount THEN
        RETURN l_new_discount - round(l_constant_discount);
      END IF;
    END IF;
    -- end 1.2
    --RETURN round(l_sum / p_amount, 2);
  END get_ga_discount_steps;
  --------------------------------------------------------------------
  --  name:            get_party_is_vested
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   05/07/2011
  --------------------------------------------------------------------
  --  purpose :        Vested = ‘Y’ – should consider the following:
  --                   1) GA Creation Date < GA Program Date
  --                   2) 2 systems were already bought by the GA (after GA Program Date)
  --                   3) The GA has no Active Primary Dealer Party Relationship
  --                   Vested = ‘N’ – if do not answear to any of the abouve case
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  05/07/2011  Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  FUNCTION get_party_is_vested(p_party_id IN NUMBER,
		       p_order_id IN NUMBER) RETURN VARCHAR2 IS
  
    is_vested NUMBER := 0;
    l_count   NUMBER := 0;
  
    CURSOR get_so_c IS
      SELECT DISTINCT ooha1.header_id,
	          oola1.fulfillment_date
      --into   is_vested
      FROM   hz_parties              hp,
	 hz_cust_accounts        acc,
	 oe_order_headers_all    ooha1,
	 oe_transaction_types_tl ottl1,
	 oe_order_lines_all      oola1,
	 xxhz_party_ga_v         t
      WHERE  hp.party_id = acc.party_id
      AND    acc.cust_account_id = ooha1.sold_to_org_id
      AND    ooha1.order_type_id = ottl1.transaction_type_id
      AND    ooha1.header_id = oola1.header_id
      AND    ottl1.language = 'US'
      AND    ottl1.name LIKE 'Standard Order%'
      AND    oola1.cancelled_flag = 'N'
      AND    oola1.inventory_item_id IN
	 (SELECT xipv.inventory_item_id
	   FROM   xxcs_items_printers_v xipv)
      AND    oola1.fulfillment_date >= t.ga_start_date --(GA Program Date)
      AND    hp.party_id = t.party_id
      AND    hp.party_id = p_party_id -- 26031;
      ORDER  BY 2 ASC;
  
  BEGIN
    -- Case 1
    -- parent party create late then the son party
    -- party_id field represent the son party
    -- ga_start_date present parent start date (attribute4)
    SELECT COUNT(1)
    INTO   is_vested
    FROM   xxhz_party_ga_v t,
           hz_parties      hp
    WHERE  t.party_id = p_party_id -- 26031
    AND    hp.party_id = t.party_id
    AND    hp.creation_date < t.ga_start_date;
  
    IF is_vested > 0 THEN
      RETURN 'Y';
    END IF;
  
    -- Case 2
    -- 2 systems were already boughtby the GA (after GA Program Date)
    is_vested := 0;
  
    FOR get_so_r IN get_so_c LOOP
      l_count := l_count + 1;
      IF get_so_r.header_id = p_order_id THEN
        EXIT;
      END IF;
    END LOOP;
  
    is_vested := l_count;
  
    IF is_vested > 2 THEN
      RETURN 'Y';
    END IF;
  
    /*-- Case 3
    -- The GA has no active primary dealer party relationship
    is_vested := 0;
    
    select count(1)
    into   is_vested
    from   hz_relationships     tt,
           hz_cust_accounts     acc
    where  tt.object_table_name = 'HZ_PARTIES'
    and    tt.object_type       = 'ORGANIZATION'
    and    tt.subject_type      = 'ORGANIZATION'
    and    tt.status            = 'A'
    and    sysdate              between tt.start_date and nvl(tt.end_date, sysdate + 1)
    and    tt.relationship_code = 'INDIRECTLY_MANAGES_CUSTOMER'
    and    tt.relationship_type = 'PARTNER_MANAGED_CUSTOMER'
    and    acc.party_id         = tt.object_id
    and    acc.party_id         = p_party_id; -- 26031;
    
    if nvl(is_vested,0) = 0 then -- Case no primary for this party
      return 'Y';
    else
      return 'N';         -- Case exists primary for this party
    end if;*/
  
    RETURN 'N';
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'N';
  END get_party_is_vested;

  --------------------------------------------------------------------
  --  name:            get_party_is_vested
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   05/07/2011
  --------------------------------------------------------------------
  --  purpose :        Get GA party id and return the primary party id that connect to it
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  05/07/2011  Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  FUNCTION get_primary_party_id(p_party_id        IN NUMBER,
		        p_cust_account_id IN NUMBER) RETURN NUMBER IS
  
    l_primary_party_id NUMBER := 0;
  BEGIN
    IF p_party_id IS NOT NULL THEN
      --Find Primary Party ID (use for Function ‘Primary Dealer’ (return party_id):
      SELECT --acc.cust_account_id,
      --object_id            party_id,
       subject_id primary_party_id
      INTO   l_primary_party_id
      FROM   hz_relationships tt,
	 hz_cust_accounts acc
      WHERE  tt.object_table_name = 'HZ_PARTIES'
      AND    tt.object_type = 'ORGANIZATION'
      AND    tt.subject_type = 'ORGANIZATION'
      AND    tt.status = 'A'
      AND    SYSDATE BETWEEN tt.start_date AND
	 nvl(tt.end_date, SYSDATE + 1)
      AND    tt.relationship_code = 'INDIRECTLY_MANAGES_CUSTOMER'
      AND    tt.relationship_type = 'PARTNER_MANAGED_CUSTOMER'
      AND    acc.party_id = tt.object_id
      AND    acc.party_id = p_party_id; --26031
    
      RETURN l_primary_party_id;
    ELSIF p_cust_account_id IS NOT NULL THEN
      --Find Primary Party ID (use for Function ‘Primary Dealer’ (return party_id):
      SELECT --acc.cust_account_id,
      --object_id            party_id,
       subject_id primary_party_id
      INTO   l_primary_party_id
      FROM   hz_relationships tt,
	 hz_cust_accounts acc
      WHERE  tt.object_table_name = 'HZ_PARTIES'
      AND    tt.object_type = 'ORGANIZATION'
      AND    tt.subject_type = 'ORGANIZATION'
      AND    tt.status = 'A'
      AND    SYSDATE BETWEEN tt.start_date AND
	 nvl(tt.end_date, SYSDATE + 1)
      AND    tt.relationship_code = 'INDIRECTLY_MANAGES_CUSTOMER'
      AND    tt.relationship_type = 'PARTNER_MANAGED_CUSTOMER'
      AND    acc.party_id = tt.object_id
      AND    acc.cust_account_id = p_cust_account_id; --26031
    
      RETURN l_primary_party_id;
    
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_primary_party_id;

  --------------------------------------------------------------------
  --  name:            get_party_is_vested
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   05/07/2011
  --------------------------------------------------------------------
  --  purpose :        Get GA party id and return the secondary party id that connect to it
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  05/07/2011  Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  FUNCTION get_secondary_party_id(p_party_id        IN NUMBER,
		          p_cust_account_id IN NUMBER) RETURN NUMBER IS
  
    l_secondary_party_id NUMBER := 0;
  BEGIN
    IF p_party_id IS NOT NULL THEN
      --Find Secondary Party ID:
      SELECT --acc.cust_account_id,
      --object_id            party_id,
       subject_id secondary_party_id
      INTO   l_secondary_party_id
      FROM   hz_relationships tt,
	 hz_cust_accounts acc
      WHERE  tt.object_table_name = 'HZ_PARTIES'
      AND    tt.object_type = 'ORGANIZATION'
      AND    tt.subject_type = 'ORGANIZATION'
      AND    tt.status = 'A'
      AND    SYSDATE BETWEEN tt.start_date AND
	 nvl(tt.end_date, SYSDATE + 1)
      AND    tt.relationship_code = 'SEC_DISTRIBUTOR_MANAGES'
      AND    tt.relationship_type = 'XX_DISTRIBUTOR_SEC'
      AND    acc.party_id = tt.object_id
      AND    acc.party_id = p_party_id; --26031
    
      RETURN l_secondary_party_id;
    ELSIF p_cust_account_id IS NOT NULL THEN
      --Find Secondary Party ID:
      SELECT --acc.cust_account_id,
      --object_id            party_id,
       subject_id secondary_party_id
      INTO   l_secondary_party_id
      FROM   hz_relationships tt,
	 hz_cust_accounts acc
      WHERE  tt.object_table_name = 'HZ_PARTIES'
      AND    tt.object_type = 'ORGANIZATION'
      AND    tt.subject_type = 'ORGANIZATION'
      AND    tt.status = 'A'
      AND    SYSDATE BETWEEN tt.start_date AND
	 nvl(tt.end_date, SYSDATE + 1)
      AND    tt.relationship_code = 'SEC_DISTRIBUTOR_MANAGES'
      AND    tt.relationship_type = 'XX_DISTRIBUTOR_SEC'
      AND    acc.party_id = tt.object_id
      AND    acc.cust_account_id = p_cust_account_id; --26031
    
      RETURN l_secondary_party_id;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_secondary_party_id;

  --------------------------------------------------------------------
  --  name:            get_parent_ga_start_date
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   05/07/2011
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  05/07/2011  Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  FUNCTION get_parent_ga_start_date(p_party_id IN NUMBER) RETURN DATE IS
  
    l_ga_start_date DATE;
  
  BEGIN
    SELECT ga_start_date
    INTO   l_ga_start_date
    FROM   xxhz_party_ga_v t
    WHERE  ga_start_date IS NOT NULL
    AND    party_id = p_party_id;
  
    RETURN l_ga_start_date;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_parent_ga_start_date;

  --------------------------------------------------------------------
  --  name:            get_party_is_vested_resin
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   13/07/2011
  --------------------------------------------------------------------
  --  purpose :        Vested = ‘Y’ – should consider the following:
  --                   1) GA Creation Date < GA Program Date
  --                   2) For the first & second deals (sold systems after GA Program Date) –
  --                      in order to be consider ‘Resin Vested’,  2 years should passed since
  --                      last Sales Order fulfillment date
  --                   3)The GA has no Active Primary Dealer Party Relationship
  --                   Vested = ‘N’ – if do not answear to any of the abouve case
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  13/07/2011  Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  FUNCTION get_party_is_vested_resin(p_party_id         IN NUMBER,
			 p_fullfilment_date IN DATE)
    RETURN VARCHAR2 IS
  
    is_vested   NUMBER := 0;
    l_count     NUMBER := 0;
    l_header_id NUMBER := 0;
    l_date      DATE := NULL;
  
    CURSOR get_so_c IS
      SELECT DISTINCT ooha1.header_id,
	          trunc(oola1.fulfillment_date) fulfillment_date
      --into   is_vested
      FROM   hz_parties              hp,
	 hz_cust_accounts        acc,
	 oe_order_headers_all    ooha1,
	 oe_transaction_types_tl ottl1,
	 oe_order_lines_all      oola1,
	 xxhz_party_ga_v         t
      WHERE  hp.party_id = acc.party_id
      AND    acc.cust_account_id = ooha1.sold_to_org_id
      AND    ooha1.order_type_id = ottl1.transaction_type_id
      AND    ooha1.header_id = oola1.header_id
      AND    ottl1.language = 'US'
      AND    ottl1.name LIKE 'Standard Order%'
      AND    oola1.cancelled_flag = 'N'
      AND    oola1.inventory_item_id IN
	 (SELECT xipv.inventory_item_id
	   FROM   xxcs_items_resins_v xipv)
      AND    oola1.fulfillment_date >= t.ga_start_date --(GA Program Date)
      AND    hp.party_id = t.party_id
      AND    hp.party_id = p_party_id -- 26031;
      AND    trunc(oola1.fulfillment_date) <= trunc(p_fullfilment_date)
      ORDER  BY 2 ASC;
  
  BEGIN
    -- Case 1
    -- parent party create late then the son party
    -- party_id field represent the son party
    -- ga_start_date present parent start date (attribute4)
    SELECT COUNT(1)
    INTO   is_vested
    FROM   xxhz_party_ga_v t,
           hz_parties      hp
    WHERE  t.party_id = p_party_id -- 26031
    AND    hp.party_id = t.party_id
    AND    hp.creation_date < t.ga_start_date;
  
    IF is_vested > 0 THEN
      RETURN 'Y';
    END IF;
  
    -- Case 2
    -- 2 systems were already boughtby the GA (after GA Program Date)
    FOR get_so_r IN get_so_c LOOP
      l_count     := l_count + 1;
      l_header_id := get_so_r.header_id;
      l_date      := get_so_r.fulfillment_date;
      --if get_so_r.header_id = p_order_id then
      IF get_so_r.fulfillment_date = p_fullfilment_date THEN
        EXIT;
      END IF;
    END LOOP;
  
    --if l_header_id = p_order_id and (l_count > 2 or l_date > sysdate - 730) then
    -- The calculation of vested is
    -- For the first & second deals (sold systems after GA Program Date) –
    -- in order to be consider ‘Resin Vested’,  2 years should passed since Sales Order fulfillment date
    IF l_count > 2 THEN
      RETURN 'Y';
      -- 2 orders that allready passed 2 years then vested
    ELSIF l_count = 2 AND l_date > SYSDATE - 730 THEN
      RETURN 'Y';
      -- One order that allready passed 2 years then vested
    ELSIF l_count = 1 AND l_date > SYSDATE - 730 THEN
      RETURN 'Y';
    ELSE
      RETURN 'N';
    END IF;
  
    RETURN 'N';
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'N';
  END get_party_is_vested_resin;

  --------------------------------------------------------------------
  --  name:            get_constant_discount
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   02/10/2011
  --------------------------------------------------------------------
  --  purpose :        get constant discount for party
  --                   if do not have constant discount return 0.
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  02/10/2011  Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  FUNCTION get_constant_discount(p_party_id IN NUMBER) RETURN NUMBER IS
    l_discount NUMBER := 0;
  BEGIN
    SELECT --hca.cust_account_id,
    --hp.party_id,
    --hp.party_name,
     (SELECT DISTINCT v.operand
      FROM   qp_modifier_summary_v v
      WHERE  v.list_header_id = qh.list_header_id) discount
    INTO   l_discount
    FROM   qp_qualifiers_v     v,
           hz_cust_accounts    hca,
           hz_parties          hp,
           qp_list_headers_all qh
    WHERE  v.qualifier_attribute = 'QUALIFIER_ATTRIBUTE2'
    AND    hca.cust_account_id = v.qualifier_attr_value
    AND    hp.party_id = hca.party_id
    AND    hp.status = 'A'
    AND    hca.status = 'A'
    AND    nvl(v.end_date_active, SYSDATE + 1) > SYSDATE
    AND    qh.description LIKE '%Off resins'
    AND    v.list_header_id = qh.list_header_id
    AND    hp.party_id = p_party_id;
  
    RETURN l_discount;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 0;
  END get_constant_discount;

  --------------------------------------------------------------------
  --  name:            is_vip
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   19/01/2012
  --------------------------------------------------------------------
  --  purpose :        check party if it is VIP
  --                   Return Y / N
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  19/01/2012  Dalit A. Raviv  initial build
  --  1.1  12/09/2013  Adi Safin       Change logic to distinguish between vip customer and GA customers (both of them like VIP)
  --------------------------------------------------------------------
  FUNCTION is_vip(p_party_id NUMBER) RETURN VARCHAR2 IS
    l_tmp VARCHAR(1);
  BEGIN
  
    SELECT 'Y'
    INTO   l_tmp
    FROM   hz_parties hp
    WHERE  hp.attribute7 = 'Y'
    AND    hp.party_id = p_party_id;
  
    IF l_tmp IS NOT NULL THEN
      RETURN l_tmp;
    ELSE
      l_tmp := is_party_ga(p_party_id, SYSDATE);
      RETURN l_tmp;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'N';
  END is_vip;
  --------------------------------------------------------------------
  --  name:            is_vip_without_ga
  --  create by:       Adi Safin
  --  Revision:        1.0
  --  creation date:   12/09/2013
  --------------------------------------------------------------------
  --  purpose :        check party if it is VIP
  --                   Return Y / N
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  12/09/2013  Adi Safin      initial build
  --------------------------------------------------------------------

  FUNCTION is_vip_without_ga(p_party_id NUMBER) RETURN VARCHAR2 IS
    l_tmp VARCHAR(1);
  BEGIN
  
    SELECT 'Y'
    INTO   l_tmp
    FROM   hz_parties hp
    WHERE  hp.attribute7 = 'Y'
    AND    hp.party_id = p_party_id;
  
    RETURN l_tmp;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'N';
  END is_vip_without_ga;
  --------------------------------------------------------------------
  --  name:            update_vip_ga_party
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   29/01/2012
  --------------------------------------------------------------------
  --  purpose :        once a day run on all GA parties check that attribute7
  --                   is null -> check if GA party. If Yes update attribute7 with Y
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  29/01/2012  Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  PROCEDURE update_vip_ga_party(errbuf  OUT VARCHAR2,
		        retcode OUT VARCHAR2) IS
  
    CURSOR get_party_pop_c IS
      SELECT gav.cust_account_id,
	 gav.party_id,
	 hp.attribute7
      FROM   xxhz_party_ga_v gav,
	 hz_parties      hp
      WHERE  gav.party_id = hp.party_id
      AND    hp.attribute7 IS NULL
      UNION ALL
      SELECT gav.cust_account_id,
	 gav.parent_party_id party_id,
	 hp.attribute7
      FROM   xxhz_party_ga_v gav,
	 hz_parties      hp
      WHERE  hp.party_id = gav.parent_party_id
      AND    hp.attribute7 IS NULL;
  
    l_user_id NUMBER := NULL;
  
  BEGIN
    -- Set out param
    errbuf  := NULL;
    retcode := 0;
    -- Get user Scheduler id
    SELECT user_id
    INTO   l_user_id
    FROM   fnd_user
    WHERE  user_name = 'SCHEDULER';
  
    -- Update all parties found as GA to be mark as VIP
    FOR get_party_pop_r IN get_party_pop_c LOOP
      BEGIN
        UPDATE hz_parties hp
        SET    attribute7          = 'Y',
	   hp.last_update_date = SYSDATE,
	   hp.last_updated_by  = l_user_id
        WHERE  hp.party_id = get_party_pop_r.party_id;
      
        COMMIT;
      EXCEPTION
        WHEN OTHERS THEN
          ROLLBACK;
          fnd_file.put_line(fnd_file.log,
		    'Failed to update party id - ' ||
		    get_party_pop_r.party_id || ' - ' ||
		    substr(SQLERRM, 1, 200));
          errbuf  := 'Failed to update party id - ' ||
	         get_party_pop_r.party_id || ' - ' ||
	         substr(SQLERRM, 1, 200);
          retcode := 1;
      END;
    END LOOP;
  
  END update_vip_ga_party;

END xxhz_party_ga_util;
/
