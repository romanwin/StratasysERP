create or replace package body xxwsh_political IS
  --------------------------------------------------------------------
  --  name:               xxwsh_political
  --  create by:          yuval tal
  --  $Revision:          1.0
  --  creation date:      20.12.10
  --  Purpose :           support political shipments
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   20.12.10     yuval tal       initial build
  --  1.1   19.12.13     Dovik pollak    cust361-cr1206 :Change functions is_delivery_political
  --                                     and is_delivery_detail_political to exclude FDM
  --  1.2   30/09/2014   Ginat B.        CHG0033137 change logic for PDM items
  --                                     Change functions is_delivery_political and is_delivery_detail_political
  --  1.3   12/07/215    Michal Tzvik    CHG0035224:
  --                                     1. New function: is_item_political
  --                                     2. Modify functions:
  --                                       - is_delivery_political
  --                                       - is_delivery_detail_political
  --                                       - is_so_line_political
  --  1.4   20.02.2018  bellona banerjee CHG0041294- Added P_Delivery_Name to is_delivery_political,
  --									   is_delivery_political_mixed,  is_dlv_politic_shippable 
  --									   as part of delivery_id to delivery_name conversion
  -----------------------------------------------------------------------

  -----------------------------------------------------------------------
  -- is_country_political(p_country varchar2) return boolean is
  -----------------------------------------------------------------------
  FUNCTION is_country_political(p_country VARCHAR2) RETURN NUMBER IS
    l_tmp NUMBER(1);
  BEGIN

    SELECT COUNT(1)
    INTO   l_tmp
    FROM   fnd_lookup_values_vl fv
    WHERE  fv.lookup_type = 'XXOM_POLITICAL_COUNTRIES'
    AND    fv.enabled_flag = 'Y'
    AND    fv.view_application_id = 660
    AND    fv.lookup_code = p_country;

    IF l_tmp = 1 THEN
      RETURN 1;

    ELSE
      RETURN 0;
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN 0;
  END;

  -----------------------------------------------------------------------
  -- get_ship_to_country
  -----------------------------------------------------------------------
  FUNCTION get_ship_to_country(p_ship_to_org_id NUMBER) RETURN VARCHAR2 IS
    l_country VARCHAR2(50);

  BEGIN

    SELECT loc.country
    INTO   l_country
    FROM   hz_cust_site_uses_all  l,
           hz_cust_acct_sites_all p,
           hz_party_sites         p2,
           hz_locations           loc
    WHERE  l.site_use_id = p_ship_to_org_id -- ship to from SO
    AND    p.cust_acct_site_id = l.cust_acct_site_id
    AND    p.party_site_id = p2.party_site_id
    AND    loc.location_id = p2.location_id;

    RETURN l_country;

  END;

  -----------------------------------------------------------------------
  -- get_attribute18 header
  -----------------------------------------------------------------------
  FUNCTION get_attribute18(p_oe_header_id NUMBER) RETURN VARCHAR2 IS
    l_tmp VARCHAR2(50);
  BEGIN
    SELECT oh.attribute18
    INTO   l_tmp
    FROM   oe_order_headers_all oh
    WHERE  oh.header_id = p_oe_header_id;

    RETURN l_tmp;

  END;

  -----------------------------------------------------------------------
  -- is_job_political
  -----------------------------------------------------------------------
  FUNCTION is_job_political(p_wip_entity_id NUMBER) RETURN NUMBER IS

    l_tmp NUMBER;
    CURSOR c IS
      SELECT demand_source_line_id
      FROM   wip_reservations_v wrv
      WHERE  wrv.wip_entity_id = p_wip_entity_id;

    p_class_code wip_discrete_jobs.class_code%TYPE;

  BEGIN

    FOR i IN c LOOP
      l_tmp := xxwsh_political.is_so_line_political(i.demand_source_line_id);
      IF l_tmp = 1 THEN
        RETURN 1;
      END IF;
    END LOOP;

    -- get the accounting class for this job
    SELECT we.class_code
    INTO   p_class_code
    FROM   wip_discrete_jobs we
    WHERE  we.wip_entity_id = p_wip_entity_id;
    -- if the accounting class is political then this job is treated as political too
    IF p_class_code = 'Political' THEN
      RETURN 1;
    END IF;

    RETURN 0;
  END;

  -----------------------------------------------------------------------
  -- is_so_hdr_political
  -----------------------------------------------------------------------
  FUNCTION is_so_hdr_political(p_oe_header_id NUMBER) RETURN NUMBER IS
    l_attribute18    VARCHAR2(240);
    l_ship_to_org_id NUMBER;
    l_order_type_id  NUMBER;
  BEGIN

    SELECT attribute18,
           ship_to_org_id,
           t.order_type_id
    INTO   l_attribute18,
           l_ship_to_org_id,
           l_order_type_id
    FROM   oe_order_headers_all t
    WHERE  header_id = p_oe_header_id;

    RETURN is_so_hdr_political(l_attribute18, l_ship_to_org_id, l_order_type_id);
    /*    l_country := get_ship_to_country(p_oe_header_id);
    IF is_country_political(l_country) = 1 THEN
      RETURN 1;
    ELSE
      IF get_attribute18(p_oe_header_id) = 'Political' THEN
        --  Else ? check the header DFF :
        RETURN 1;
      END IF;
    END IF;
    RETURN 0;*/
  END;

  -----------------------------------------------------------------------
  -- is_so_hdr_political
  -- call from trigger : xxoe_order_headers_all_trg

  --   1.2    10.4.11      yuval tal       change logic at is_so_hdr_political -
  --                                       exclude check in transaction types  mark with att10=Y     cr-241
  -----------------------------------------------------------------------
  FUNCTION is_so_hdr_political(p_attribute18    VARCHAR2,
                               p_ship_to_org_id NUMBER,
                               p_order_type_id  NUMBER) RETURN NUMBER IS
    l_country hz_locations.country%TYPE;
    l_att10   VARCHAR2(240);
  BEGIN
    -- check not exclude
    SELECT nvl(attribute10, 'N')
    INTO   l_att10
    FROM   oe_transaction_types_all t
    WHERE  t.transaction_type_id = p_order_type_id;

    l_country := get_ship_to_country(p_ship_to_org_id);
    IF is_country_political(l_country) = 1 AND l_att10 = 'N' THEN
      RETURN 1;
    ELSE
      IF nvl(p_attribute18, '-1') = 'Political' THEN
        --  Else ? check the header DFF :
        RETURN 1;
      END IF;
    END IF;
    RETURN 0;
  END;

  --------------------------------------------------------------------
  --  name:              is_so_line_political
  --  create by:
  --  Revision:
  --  creation date:
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date          name             desc
  --  1.0                                 initial build
  --  1.1  28/07/2105    Michal Tzvik     CHG0035224 - call is_item_political
  --------------------------------------------------------------------
  FUNCTION is_so_line_political(p_oe_line_id NUMBER) RETURN NUMBER IS
    l_header_id         NUMBER;
    l_inventory_item_id NUMBER; -- 1.1  Michal Tzvik  CHG0035224
  BEGIN
    SELECT l.header_id,
           l.inventory_item_id -- 1.1  Michal Tzvik  CHG0035224
    INTO   l_header_id,
           l_inventory_item_id -- 1.1  Michal Tzvik  CHG0035224
    FROM   oe_order_lines_all l
    WHERE  l.line_id = p_oe_line_id;

    IF is_so_hdr_political(l_header_id) = 1 AND
       is_item_political(l_inventory_item_id) = 'Y' -- 1.1  Michal Tzvik  CHG0035224
     THEN
      RETURN 1;
    END IF;

    RETURN 0;
  END;

  --------------------------------------------------------------------
  --  name:              is_delivery_political
  --  create by:         XXX
  --  Revision:          1.0
  --  creation date:     XX/XXX/XXXX
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  XX/XXX/XXXX   XXX               initial build
  --  1.1  19.12.13      yuval tal         cust361-cr1206 add xxinv_utils_pkg.is_fdm_item
  --  1.2  30/09/2014    Ginat B.          CHG0033137 change logic for PDM items
  --  1.3  12/07/2015    Michal Tzvik      CHG0035224 change logic for PDM items: use xxwsh_political.is_item_political
  --------------------------------------------------------------------
  FUNCTION is_delivery_political(p_delivery_name in varchar2)--(p_delivery_id NUMBER) -- CHG0041294 on 20/02/2018 for delivery id to name change
  RETURN NUMBER IS
    l_tmp NUMBER;
    CURSOR c IS
      SELECT DISTINCT wdd.source_header_id
      FROM   wsh_delivery_assignments wda,
             wsh_delivery_details     wdd
      WHERE  wda.delivery_id = xxinv_trx_in_pkg.get_delivery_id(p_delivery_name)--p_delivery_id    -- CHG0041294 on 20/02/2018 for delivery id to name change
      AND    wdd.delivery_detail_id = wda.delivery_detail_id
      AND    wdd.source_code = 'OE'
            --  1.2  30/09/2014    Ginat B.
            -- AND xxinv_utils_pkg.is_fdm_item(wdd.inventory_item_id) = 'N';
            /*AND    (xxinv_item_classification.is_item_polyjet(wdd.inventory_item_id) = 'Y' OR
            xxinv_utils_pkg.get_item_category(wdd.inventory_item_id, 1100000221) IS NULL)*/
      AND    xxwsh_political.is_item_political(wdd.inventory_item_id) = 'Y' -- 1.3 12/07/2015 Michal Tzvik
      -- end 1.2
      ;
  BEGIN

    FOR i IN c LOOP
      l_tmp := is_so_hdr_political(i.source_header_id);

      IF l_tmp = 1 THEN
        RETURN 1;

      END IF;
    END LOOP;
    RETURN 0;
  END;

  -----------------------------------------------------------------------
  -- is_delivery_political_mixed
  -----------------------------------------------------------------------
  FUNCTION is_delivery_political_mixed(p_delivery_name in varchar2)--(p_delivery_id NUMBER)    -- CHG0041294 on 20/02/2018 for delivery id to name change 
  RETURN NUMBER IS
    l_tmp_0 NUMBER(1) := 0;
    l_tmp_1 NUMBER(1) := 0;
    l_tmp   NUMBER(1);
    CURSOR c IS
      SELECT DISTINCT wdd.source_header_id
      FROM   wsh_new_deliveries       wnd,
             wsh_delivery_assignments wda,
             wsh_delivery_details     wdd
      WHERE  wnd.delivery_id = xxinv_trx_in_pkg.get_delivery_id(p_delivery_name)--p_delivery_id		--CHG0041294
      AND    wda.delivery_id = wnd.delivery_id
      AND    wdd.delivery_detail_id = wda.delivery_detail_id
      AND    wdd.source_code = 'OE';

  BEGIN

    FOR i IN c LOOP
      l_tmp := is_so_hdr_political(i.source_header_id);

      IF l_tmp = 1 THEN
        l_tmp_1 := l_tmp_1 + 1;
      ELSE
        l_tmp_0 := l_tmp_0 + 0;
      END IF;

      IF l_tmp_0 > 0 AND l_tmp_1 > 0 THEN
        RETURN 1;
      END IF;

    END LOOP;
    RETURN 0;
  END;
  -----------------------------------------------------------------------
  -- is_dlv_politic_shippable
  -----------------------------------------------------------------------
  FUNCTION is_dlv_politic_shippable(p_delivery_name in varchar2)--(p_delivery_id NUMBER)    -- CHG0041294 on 20/02/2018 for delivery id to name change  
  RETURN NUMBER IS

    l_tmp   NUMBER(1);
    l_count NUMBER;
  BEGIN
    l_tmp := is_delivery_political(p_delivery_name);--p_delivery_id);    -- CHG0041294 on 20/02/2018 for delivery id to name change  

    IF l_tmp = 1 THEN

      SELECT COUNT(*)
      INTO   l_count
      FROM   wsh_new_deliveries wnd
      WHERE  wnd.delivery_id = xxinv_trx_in_pkg.get_delivery_id(p_delivery_name)--p_delivery_id    -- CHG0041294 on 20/02/2018 for delivery id to name change  
      AND    wnd.attribute11 = 'Y';

      IF l_count > 0 THEN
        RETURN 1;
      END IF;
    ELSE

      RETURN 0;
    END IF;
    RETURN 0;
  END;

  FUNCTION is_ship_to_political(p_site_id NUMBER) RETURN NUMBER IS
    l_country VARCHAR2(50);

    l_tmp NUMBER(1);

  BEGIN

    SELECT loc.country
    INTO   l_country
    FROM   hz_cust_site_uses_all  l,
           hz_cust_acct_sites_all p,
           hz_party_sites         p2,
           hz_locations           loc
    WHERE  l.site_use_id = p_site_id -- ship to from SO
    AND    p.cust_acct_site_id = l.cust_acct_site_id
    AND    p.party_site_id = p2.party_site_id
    AND    loc.location_id = p2.location_id;

    l_tmp := is_country_political(l_country);

    IF l_tmp = 1 THEN
      RETURN 1;
    ELSE
      RETURN 0;
    END IF;

  END;

  --------------------------------------------------------------------
  --  name:              is_delivery_detail_political
  --  create by:         XXX
  --  Revision:          1.0
  --  creation date:     XX/XXX/XXXX
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date          name             desc
  --  1.0  XX/XXX/XXXX   XXX              initial build
  --  1.1  19.12.13      yuval tal        cust361-cr1206 add xxinv_utils_pkg.is_fdm_item
  --  1.2  30/09/2014    Ginat B.         CHG0033137 change logic for PDM items
  --  1.3  12/07/2015    Michal Tzvik     CHG0035224 remove the conditions from query. use new logic in is_so_line_political instead.
  --------------------------------------------------------------------
  FUNCTION is_delivery_detail_political(p_delivery_detail_id NUMBER)
    RETURN NUMBER IS
    l_tmp     NUMBER;
    l_so_line NUMBER;

  BEGIN

    SELECT wdd.source_line_id
    INTO   l_so_line
    FROM   wsh_delivery_details wdd
    WHERE  wdd.delivery_detail_id = p_delivery_detail_id
    AND    wdd.source_code = 'OE'
    --  1.2  30/09/2014    Ginat B.
    --AND xxinv_utils_pkg.is_fdm_item(wdd.inventory_item_id) = 'N';
    -- 1.3 12/07/2015 Michal Tzvik: remove the following conditions. use new logic in is_so_line_political instead.
    /* AND    (xxinv_item_classification.is_item_polyjet(wdd.inventory_item_id) = 'Y' OR
    xxinv_utils_pkg.get_item_category(wdd.inventory_item_id, 1100000221) IS NULL)*/
    ;
    l_tmp := is_so_line_political(l_so_line);

    IF l_tmp = 1 THEN
      RETURN 1;

    END IF;

    RETURN 0;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN 0;
  END;

  --------------------------------------------------------------------
  --  name:              is_item_political
  --  create by:         Yuval Tal
  --  Revision:          1.0
  --  creation date:     12/07/2015
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date          name             desc
  --  1.0  12/07/2015    Yuval Tal        CHG0035224 - initial build
  --------------------------------------------------------------------
  FUNCTION is_item_political(p_inventory_item_id NUMBER) RETURN VARCHAR2 IS

    l_inventory_flag mtl_system_items_b.inventory_item_flag%TYPE;
    l_coo            VARCHAR2(240);

  BEGIN

    SELECT msib.inventory_item_flag,
           msibd.coo
    INTO   l_inventory_flag,
           l_coo
    FROM   mtl_system_items_b     msib,
           mtl_system_items_b_dfv msibd
    WHERE  msibd.row_id(+) = msib.rowid
    AND    msib.inventory_item_id = p_inventory_item_id
    AND    msib.organization_id =
           xxinv_utils_pkg.get_master_organization_id;

    IF l_inventory_flag = 'Y' AND nvl(l_coo, 'IL') = 'IL' THEN
      RETURN 'Y';
    ELSE
      RETURN 'N';
    END IF;
    -- political_item_flag

  EXCEPTION
    WHEN no_data_found THEN
      RETURN 'Y';
  END is_item_political;

END xxwsh_political;
/