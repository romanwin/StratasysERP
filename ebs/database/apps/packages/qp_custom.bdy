CREATE OR REPLACE PACKAGE BODY qp_custom AS
  --------------------------------------------------------------------
  --  name:            QP_CUSTOM
  --  create by:       Yuval Tal
  --  Revision:        1.0
  --  creation date:   01/05/2011
  --------------------------------------------------------------------
  --  purpose :        Advance Pricing Util
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  01/05/2011  Yuval Tal         initial build
  --  1.1  21/06/2011  Roman V.
  --  1.2 19/7/2011    yuval tal        change logic : get packed price
  --  1.3 15.9.11      yuval .tal       pack of : support conversion between differnt curr price list and order
  --  1.4 29/11/2012   yuval tal        bugfix : XXPACK_OF  fix : get conversion date from order line field pricing_date
  --  1.5 16.8.13      yuval tal        CR 1174 Bug Fix: fix discount calculation in SO when using modifier with a formula
  --                                    find line_id from table qp_preq_lines_tmp
  --  1.6 28/04/2014   Sandeep Akula    Added Logic for getting Standard Cost for Formulas stored in Lookup XXQP_STD_COST_FORMULAS_LIST (CHG0031469)
  --                                    Added Cursor c_lookup (CHG0031469)
  --  1.7 07/12/2014   Michal Tzvik     CHG0034004 - Resin Bucket Discount
  --  1.8 17/04/2015   Diptasurjya      CHG0034837 - XXPACK_OF fix: get price_list_id from p_req_line_attrs_tbl IN parameter
  --                   Chatterjee       added exception block to handle PRICE_REQUEST scenario, in exception block line quantity
  --                                    is being calculated from temporary tables qp_npreq_lines_tmp, qp_npreq_line_attrs_tmp, qp_npreq_ldets_tmp
  --  1.9 22/05/2015   MMAZANET         CHG0035447 - Added handling for XXVERO items.  Also added log procedure.
  --  2.0 04/08/2015   Diptasurjya      CHG0036152 - Added adition filter conditions in XXPACK_OF formula to filter INCLUDED, CLASS, OPTION item types
  --                   Chatterjee                    while picking up order lines to apply descount upon
  --  2.1 02/02/2016   Diptasurjya      CHG0036750 - Exclude Other Item discount lines during pack of calculations
  --  2.2 14/11/2017   Ofer Suad        CHG0040750 - Return STD cost for cost + logic
  --  2.3 24-SEP-2020  Diptasurjya      CHG0048665 - Add handling for new formula XXCN_INTERCOMPANY_PRICE
  --------------------------------------------------------------------

  g_log          VARCHAR2(1) := fnd_profile.value('AFLOG_ENABLED');
  g_log_module   VARCHAR2(100) := fnd_profile.value('AFLOG_MODULE');
  g_request_id   NUMBER := TO_NUMBER(fnd_global.conc_request_id);
  g_program_unit VARCHAR2(30);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Write to request log if 'FND: Debug Log Enabled' is set to Yes
  -- ---------------------------------------------------------------------------------------------
  -- Ver  Date        Name        Description
  -- 1.0  12/12/2014  MMAZANET    Initial Creation for CHG0035447.
  -- ---------------------------------------------------------------------------------------------
  PROCEDURE write_log(p_msg VARCHAR2) IS
  BEGIN
    IF g_log = 'Y' AND
       UPPER('xxqp.custom_pricing.qp_custom.' || g_program_unit) LIKE
       UPPER(g_log_module) THEN
      fnd_log.STRING(log_level => fnd_log.LEVEL_UNEXPECTED,
                     module    => 'xxqp.custom_pricing.qp_custom.' ||
                                  g_program_unit,
                     message   => p_msg);
    END IF;
  END write_log;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Standard Oracle hook function for custom pricing.
  -- ---------------------------------------------------------------------------------------------
  FUNCTION get_custom_price(p_price_formula_id     IN NUMBER,
                            p_list_price           IN NUMBER,
                            p_price_effective_date IN DATE,
                            p_req_line_attrs_tbl   IN qp_formula_price_calc_pvt.req_line_attrs_tbl)
    RETURN NUMBER IS

    v_requested_item  NUMBER;
    l_pack_price      NUMBER;
    l_qty             NUMBER;
    l_calc_unit_price NUMBER;
    l_total           NUMBER;
    l_item_id         NUMBER;
    l_formula_name    VARCHAR2(50);
    l_line_id         NUMBER;
    l_price_list_id   NUMBER;

    -- get_xxpack_of

    l_related_item_id         NUMBER;
    l_divide_fact             NUMBER;
    l_list_curr_code          VARCHAR2(5);
    l_conversion_type_code    VARCHAR2(15);
    l_transactional_curr_code VARCHAR2(5);
    l_oe_line_creation_date   DATE;
    l_formula_cnt             NUMBER; -- 28-APR-2014 SAkula Added Variable (CHG0031469)
    l_std_cost                NUMBER; -- 28-APR-2014 SAkula Added Variable (CHG0031469)

    -- Added for CHG0035447 --
    l_discount_amt   NUMBER := 0;
    l_discount_qty   NUMBER := 0;
    l_new_price      NUMBER := 0;
    l_dis_price      NUMBER := 0;
    l_reg_price      NUMBER := 0;
    l_list_header_id NUMBER;
    l_master_org_id  NUMBER;
    l_priced_flag    BOOLEAN := FALSE;
    -- End Added for CHG0035447 --
    l_ic_ip_flag Number; -- Added for CHG0040750 --

    l_cn_ic_price number;  /* CHG0048665 - DIPTA added below formula handler - for CN intercomany pricing */

    CURSOR c_item_rel(c_item_id NUMBER) IS
      SELECT y.related_item_id, y.attr_num1 divide_fact
        FROM mtl_related_items_all_v y
       WHERE y.relationship_type_id = 4
         AND y.inventory_item_id = c_item_id;
    --l_progress NUMBER;

    -- CHG0031469 - SAkula (Added Cursor )
    CURSOR c_lookup(cp_lookup_type IN VARCHAR2) IS
      SELECT flvv.meaning
        FROM fnd_lookup_types_vl fltv, fnd_lookup_values_vl flvv
       WHERE fltv.security_group_id = flvv.security_group_id
         AND fltv.view_application_id = flvv.view_application_id
         AND fltv.lookup_type = flvv.lookup_type
         AND fltv.lookup_type = upper(cp_lookup_type)
         AND trunc(SYSDATE) BETWEEN trunc(flvv.start_date_active) AND
             nvl(flvv.end_date_active, trunc(SYSDATE))
       ORDER BY to_number(trunc(flvv.meaning)) ASC;

  BEGIN

    -----------------------------------------------------------------------------------------
    SELECT NAME
      INTO l_formula_name
      FROM qp_price_formulas_vl t
     WHERE t.price_formula_id = p_price_formula_id;

    -- xxobjt_debug_proc(p_message1 => 'l_formula_name=' || l_formula_name);

    ------------------------------------------------------------------------------------------
    -- XXITEM_VERO
    -- CHG0035447 - Calculates discounts for certain items.  Users need to apply promo code to
    -- get discount.
    ------------------------------------------------------------------------------------------
    IF l_formula_name = 'XXITEM_VERO' AND p_req_line_attrs_tbl(1)
      .line_index IS NOT NULL THEN

      write_log('*** In XXITEM_VER0 ***');

      g_program_unit := 'GET_CUSTOM_PRICE.XXITEM_VERO';

      -- Get the current line for pricing
      SELECT qplt.line_id
        INTO l_line_id
        FROM qp_preq_lines_tmp qplt
       WHERE qplt.line_index = p_req_line_attrs_tbl(1).line_index;

      write_log('line_id ' || l_line_id);

      -- Get VERO promo. This could be a lookup to make things more generic but because
      -- of time constraints it is hard-coded.
      SELECT list_header_id
        INTO l_list_header_id
        FROM qp_list_headers
       WHERE name = 'VEROQ2PRO';

      l_master_org_id := xxinv_utils_pkg.get_master_organization_id;

      -- Get distinct list Activity Analysis values to cycle through
      FOR cat_rec IN (SELECT DISTINCT micv.category_set_name,
                                      micv.segment1,
                                      flv.attribute1         promo_factor,
                                      flv.attribute2         promo_value
                        FROM oe_order_lines_all    ool,
                             mtl_item_categories_v micv,
                             fnd_lookup_values     flv
                       WHERE ool.header_id = oe_order_pub.g_hdr.header_id
                         AND ool.inventory_item_id = micv.inventory_item_id
                         AND l_master_org_id = micv.organization_id
                         AND micv.category_set_name = 'Activity Analysis'
                         AND micv.segment1 = flv.meaning
                         AND flv.lookup_type = 'XXINV_ACTIVITY_ANALYSIS'
                         AND flv.language = USERENV('LANG')
                         AND flv.enabled_flag = 'Y') LOOP

        write_log('*** NEXT CATEGORY ***');
        write_log('cat_rec.category_set_name: ' ||
                  cat_rec.category_set_name);
        write_log('cat_rec.segment1: ' || cat_rec.segment1);
        write_log('cat_rec.promo_factor: ' || cat_rec.promo_factor);
        write_log('cat_rec.promo_value: ' || cat_rec.promo_value);

        -- get total quantity per item.  Original requirement was to take the quantity *
        -- item's 'pack of' quantity.  However, that was reversed to be just quantity, so I've
        -- hard-coded 'pack of' to 1 in item inline view.
        SELECT SUM((ool.ordered_quantity - nvl(ool.cancelled_quantity, 0)) *
                   NVL(item.pack_of, 1))
          INTO l_qty
          FROM oe_order_lines_all ool,
               /* item... */
               (SELECT
                -- uncomment and remove '1' line to factor pack of qty
                -- mdevv.element_value         pack_of,
                 1                      pack_of,
                 msib.inventory_item_id inventory_item_id,
                 msib.organization_id   inventory_org_id
                  FROM mtl_system_items_b         msib,
                       mtl_descr_element_values_v mdevv
                 WHERE msib.organization_id = l_master_org_id
                   AND msib.inventory_item_id = mdevv.inventory_item_id(+)
                      -- Resin Weights catalog
                   AND 2 = mdevv.item_catalog_group_id(+)
                   AND mdevv.element_name(+) = 'pack of') item,
               /* ...item */
               mtl_item_categories_v micv_aa,
               mtl_item_categories_v micv_ph
         WHERE ool.header_id = oe_order_pub.g_hdr.header_id
           AND ool.inventory_item_id = item.inventory_item_id(+)
           AND l_master_org_id = item.inventory_org_id(+)
           AND ool.inventory_item_id = micv_aa.inventory_item_id
           AND l_master_org_id = micv_aa.organization_id
           AND micv_aa.category_set_name = cat_rec.category_set_name
           AND micv_aa.segment1 = cat_rec.segment1
           AND ool.inventory_item_id = micv_ph.inventory_item_id
           AND l_master_org_id = micv_ph.organization_id
           AND micv_ph.category_set_name = 'Product Hierarchy'
           AND EXISTS
         ( /*
                                                      -- At the Product Hierarcy item category level
                                                      SELECT NULL
                                                      FROM qp_modifier_summary_v      qmsv
                                                      WHERE qmsv.list_header_id   = l_list_header_id
                                                      AND   qmsv.product_attr     = 'PRICING_ATTRIBUTE30'
                                                      AND   qmsv.product_attr_val = micv_ph.category_concat_segs
                                                      AND   SYSDATE               BETWEEN NVL(qmsv.start_date_active,'01-JAN-1900')
                                                                                    AND NVL(qmsv.end_date_active,'31-DEC-4712')
                                                      */
                -- Find other items eligible for promotion on same order
                SELECT NULL
                  FROM qp_modifier_summary_v qmsv
                 WHERE qmsv.list_header_id = l_list_header_id
                   AND qmsv.product_attribute_context = 'ITEM'
                   AND qmsv.product_attr = 'PRICING_ATTRIBUTE1'
                   AND qmsv.product_attr_val = item.inventory_item_id
                   AND SYSDATE BETWEEN
                       NVL(qmsv.start_date_active, '01-JAN-1900') AND
                       NVL(qmsv.end_date_active, '31-DEC-4712'));

        -- Get total number of items to be discounted
        l_discount_qty := FLOOR(l_qty / cat_rec.promo_factor) *
                          cat_rec.promo_factor;

        write_log('factor ' || l_discount_qty);
        write_log('********* oe_order_pub.g_line.line_id' ||
                  oe_order_pub.g_line.line_id);
        -- Cycle through all order lines
        FOR rec IN (SELECT ool.ordered_quantity * NVL(item.pack_of, 1) ordered_quantity,
                           ool.ordered_quantity no_pack_ordered_quantity,
                           ool.inventory_item_id inventory_item_id,
                           ool.unit_list_price / NVL(item.pack_of, 1) list_price,
                           ool.unit_list_price no_pack_list_price,
                           item.pack_of item_pack_of,
                           ool.line_id line_id,
                           NVL(ool.unit_list_price, 0) line_amt
                      FROM oe_order_lines_all ool,
                           /* item... */
                           (SELECT
                            -- uncomment and remove '1' line to factor pack of qty
                            -- mdevv.element_value         pack_of,
                             1                      pack_of,
                             msib.inventory_item_id inventory_item_id,
                             msib.organization_id   inventory_org_id
                              FROM mtl_system_items_b         msib,
                                   mtl_descr_element_values_v mdevv
                             WHERE msib.organization_id = l_master_org_id
                               AND msib.inventory_item_id =
                                   mdevv.inventory_item_id(+)
                                  -- Resin Weights catalog
                               AND 2 = mdevv.item_catalog_group_id(+)
                               AND mdevv.element_name(+) = 'pack of') item,
                           /* ...item */
                           mtl_item_categories_v micv_aa,
                           mtl_item_categories_v micv_ph
                     WHERE ool.header_id = oe_order_pub.g_hdr.header_id
                       AND ool.inventory_item_id = item.inventory_item_id(+)
                       AND l_master_org_id = item.inventory_org_id(+)
                       AND ool.inventory_item_id = micv_aa.inventory_item_id
                       AND l_master_org_id = micv_aa.organization_id
                       AND micv_aa.category_set_name =
                           cat_rec.category_set_name
                       AND micv_aa.segment1 = cat_rec.segment1
                       AND ool.inventory_item_id = micv_ph.inventory_item_id
                       AND l_master_org_id = micv_ph.organization_id
                       AND micv_ph.category_set_name = 'Product Hierarchy'
                       AND EXISTS
                     ( /*
                                                                              -- At the Product Hierarcy item category level
                                                                              SELECT NULL
                                                                              FROM qp_modifier_summary_v      qmsv
                                                                              WHERE qmsv.list_header_id   = l_list_header_id
                                                                              AND   qmsv.product_attr     = 'PRICING_ATTRIBUTE30'
                                                                              AND   qmsv.product_attr_val = micv_ph.category_concat_segs
                                                                              AND   SYSDATE               BETWEEN NVL(qmsv.start_date_active,'01-JAN-1900')
                                                                                                            AND NVL(qmsv.end_date_active,'31-DEC-4712')
                                                                              */
                            -- Find other items eligible for promotion on same order
                            SELECT NULL
                              FROM qp_modifier_summary_v qmsv
                             WHERE qmsv.list_header_id = l_list_header_id
                               AND qmsv.product_attribute_context = 'ITEM'
                               AND qmsv.product_attr = 'PRICING_ATTRIBUTE1'
                               AND qmsv.product_attr_val =
                                   item.inventory_item_id
                               AND SYSDATE BETWEEN
                                   NVL(qmsv.start_date_active, '01-JAN-1900') AND
                                   NVL(qmsv.end_date_active, '31-DEC-4712'))
                    -- Least expensive items should be discounted first
                     ORDER BY line_amt) LOOP

          write_log('rec.line_id: ' || rec.line_id);
          write_log('order_line_id: ' || l_line_id);
          write_log('l_discount_qty: ' || l_discount_qty);
          write_log('rec.ordered_quantity: ' || rec.ordered_quantity);
          write_log('rec.no_pack_list_price: ' || rec.no_pack_list_price);
          write_log('rec.no_pack_ordered_quantity: ' ||
                    rec.no_pack_ordered_quantity);

          -- If discounted quantity exceeds current order line quantity
          -- then entire quantity is discounted
          IF l_discount_qty >= rec.ordered_quantity THEN
            l_discount_qty := l_discount_qty - rec.ordered_quantity;
            l_new_price    := rec.no_pack_list_price * cat_rec.promo_value;

            write_log('new price ' || l_new_price);

            -- If discounted quantity is less than or equal to 0 then no
            -- quantity is discounted on current order line
          ELSIF l_discount_qty <= 0 THEN
            l_new_price := rec.no_pack_list_price;

            write_log('new price2 ' || l_new_price);

            -- If discounted quantity is less than order line quantity but
            -- greater than 0, then some of the current order line quantity is
            -- discounted
          ELSE
            l_dis_price    := l_discount_qty * rec.list_price *
                              cat_rec.promo_value;
            l_reg_price    := (rec.ordered_quantity - l_discount_qty) *
                              rec.list_price;
            l_new_price    := (l_dis_price + l_reg_price) /
                              rec.no_pack_ordered_quantity;
            l_discount_qty := l_discount_qty - rec.ordered_quantity;

            write_log('new price3 ' || l_new_price);
          END IF;

          -- If on the current pricing line, exit the loop and return the price
          IF rec.line_id = l_line_id THEN
            l_priced_flag := TRUE;
            EXIT;
          END IF;
          --END IF;
        END LOOP;

        -- If on the current pricing line, exit the loop and return the price
        IF l_priced_flag THEN
          EXIT;
        END IF;
      END LOOP; -- cat_rec

      RETURN l_new_price;
    END IF;
    -- END XX_VERO

    ---------------------------
    -- Benchmark Allowance
    ---------------------------
    -- 08.12.2014 Michal Tzvik CHG0034003
    IF l_formula_name = 'XX_BENCHMARK_ALLOWANCE' AND p_req_line_attrs_tbl(1)
      .line_index IS NOT NULL THEN
      IF fnd_profile.value('XX_ENABLE_RESIN_BUCKET_PRICING') = 'Y' THEN

        SELECT qplt.line_id
          INTO l_line_id
          FROM qp_preq_lines_tmp qplt
         WHERE qplt.line_index = p_req_line_attrs_tbl(1).line_index;

        IF l_line_id = oe_order_pub.g_line.line_id THEN
          RETURN xxoe_so_bucket_discount_pkg.get_resin_discount_percent(l_line_id);
        ELSE
          RETURN xxoe_so_bucket_discount_pkg.get_line_adjustment_rate(l_line_id);
        END IF;
      ELSE
        RETURN 0;
      END IF;
    END IF;

    ---------------------------
    -- XXPACK_OF
    ---------------------------
    --- yuval 1.5.11
    IF l_formula_name = 'XXPACK_OF' AND
       fnd_profile.value('XXPACK_OF_PRICING_ENABLED') = 'Y' THEN
      FOR i IN 1 .. p_req_line_attrs_tbl.count LOOP
        IF p_req_line_attrs_tbl(i).attribute_type = 'PRODUCT' AND p_req_line_attrs_tbl(i)
           .context = 'ITEM' AND p_req_line_attrs_tbl(i)
           .attribute = 'PRICING_ATTRIBUTE1' THEN
          l_item_id := p_req_line_attrs_tbl(i).value;
        END IF;

        /** CHG0034837 - Code added by DIPTASURJYA CHATTERJEE (TCS) for Price Request handling */
        IF p_req_line_attrs_tbl(i).attribute_type = 'QUALIFIER' AND p_req_line_attrs_tbl(i)
           .context = 'MODLIST' AND p_req_line_attrs_tbl(i)
           .attribute = 'QUALIFIER_ATTRIBUTE4' THEN
          l_price_list_id := p_req_line_attrs_tbl(i).value;
        END IF;

      /** CHG0034837 - Ends changes by DIPTASURJYA CHATTERJEE (TCS) */

      /*  xxobjt_debug_proc(p_message1 => 'p_req_line_attrs_tbl(i)
                    .attribute_type' ||
                                                    p_req_line_attrs_tbl(i)
                                                   .attribute_type,
                                      p_message2 => 'p_req_line_attrs_tbl(i).VALUE=' ||
                                                    p_req_line_attrs_tbl(i).VALUE,
                                      p_message3 => ' p_req_line_attrs_tbl(i)
                    .attribute=' ||
                                                    p_req_line_attrs_tbl(i).attribute);*/

      -- END IF;

      END LOOP;

      -- check related item exists
      --l_progress := 1;
      OPEN c_item_rel(l_item_id);
      FETCH c_item_rel
        INTO l_related_item_id, l_divide_fact;
      CLOSE c_item_rel;
      --l_progress := 2;
      IF l_related_item_id IS NULL THEN
        RETURN oe_order_pub.g_line.unit_list_price;
      END IF;

      --l_progress := 3;
      -- get packed price
      /** CHG0034837 - Following BEGIN added by DIPTASURJYA CHATTERJEE (TCS) for Price Request handling */
      BEGIN
        /** CHG0034837 - End */
        SELECT l.operand,
               b.currency_code list_curr_code,
               h.conversion_type_code,
               h.transactional_curr_code,
               --  ol.creation_date
               ol.pricing_date
          INTO l_pack_price,
               l_list_curr_code,
               l_conversion_type_code,
               l_transactional_curr_code,
               l_oe_line_creation_date
          FROM qp_list_headers_all_b b,
               qp_list_headers_tl    t,
               qp_list_lines         l,
               qp_pricing_attributes qpa,
               mtl_system_items_b    msib,
               oe_order_lines_all    ol, --qp_npreq_lines_tmp if the line_type_code is ORDER, LINE
               oe_order_headers_all  h
         WHERE h.header_id = ol.header_id
           AND l.list_header_id = ol.price_list_id --oe_order_pub.g_line.price_list_id
           AND ol.inventory_item_id = l_item_id
           AND ol.header_id = oe_order_pub.g_hdr.header_id
           AND b.list_header_id = t.list_header_id
           AND b.list_header_id = l.list_header_id
           AND t.language = 'US'
           AND nvl(ol.cancelled_flag, 'N') = 'N'
           AND nvl(ol.item_type_code, 'A') not in
               ('INCLUDED', 'OPTION', 'CLASS') -- CHG0036152 - Diptasurjya Chatterjee
           AND l.list_line_id = qpa.list_line_id
           AND to_char(qpa.product_attr_value) =
               to_char(msib.inventory_item_id)
           AND msib.organization_id = 91
           AND SYSDATE BETWEEN nvl(l.start_date_active, SYSDATE - 1) AND
               nvl(l.end_date_active, SYSDATE + 1)
           AND msib.inventory_item_id = l_related_item_id
           AND rownum = 1;
        --l_progress := 4;
        -- get  item quantity

        SELECT SUM(t.ordered_quantity - nvl(t.cancelled_quantity, 0))
          INTO l_qty
          FROM oe_order_lines_all t
         WHERE t.header_id = oe_order_pub.g_hdr.header_id
           AND t.cancelled_flag = 'N'
           AND t.inventory_item_id = l_item_id
           AND nvl(t.item_type_code, 'A') not in
               ('INCLUDED', 'OPTION', 'CLASS'); -- CHG0036152 - Diptasurjya Chatterjee

        IF nvl(l_list_curr_code, '-1') !=
           nvl(l_transactional_curr_code, '-1') THEN

          /*  xxobjt_debug_proc(p_message1 => 'l_pack_price=' || l_pack_price ||
          ' l_list_curr_code=' ||
          l_list_curr_code ||
          ' l_transactional_curr_code=' ||
          l_transactional_curr_code ||
          ' l_transactional_curr_code=' ||
          l_transactional_curr_code);*/

          l_pack_price := gl_currency_api.convert_amount(x_from_currency   => l_list_curr_code,
                                                         x_to_currency     => l_transactional_curr_code,
                                                         x_conversion_date => l_oe_line_creation_date,
                                                         x_conversion_type => l_conversion_type_code,
                                                         x_amount          => l_pack_price);

        END IF;
        /** CHG0034837 - Following EXCEPTION block added by DIPTASURJYA CHATTERJEE (TCS) for Price Request handling */
      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          SELECT l.operand, b.currency_code list_curr_code
            INTO l_pack_price, l_list_curr_code
            FROM qp_list_headers_all_b b,
                 qp_list_headers_tl    t,
                 qp_list_lines         l,
                 qp_pricing_attributes qpa,
                 mtl_system_items_b    msib
           WHERE l.list_header_id = l_price_list_id
             AND b.list_header_id = t.list_header_id
             AND b.list_header_id = l.list_header_id
             AND t.language = 'US'
             AND l.list_line_id = qpa.list_line_id
             AND to_char(qpa.product_attr_value) =
                 to_char(msib.inventory_item_id)
             AND msib.organization_id = 91
             AND SYSDATE BETWEEN nvl(l.start_date_active, SYSDATE - 1) AND
                 nvl(l.end_date_active, SYSDATE + 1)
             AND msib.inventory_item_id = l_related_item_id
             AND rownum = 1;

          select sum(a.line_quantity)
            into l_qty
            from qp_npreq_lines_tmp      a,
                 qp_npreq_line_attrs_tmp b,
                 qp_npreq_ldets_tmp      c
           where a.request_id = QP_Price_Request_Context.Get_Request_Id
             and b.request_id = QP_Price_Request_Context.Get_Request_Id
             and a.line_index = c.line_index
             and c.LINE_detail_INDEX = b.line_detail_index
             and b.ATTRIBUTE_TYPE = 'PRODUCT'
             and b.context = 'ITEM'
             and b.attribute = 'PRICING_ATTRIBUTE1'
             and b.value_from = l_item_id
             and c.created_from_list_line_type not in ('OID'); -- CHG0036750 - Added by Dipta 2.2.2016

      END;
      /** CHG0034837 - End DIPTASURJYA CHATTERJEE (TCS) */

      --oe_order_pub.g_line.inventory_item_id;
      --l_progress := 5;

      -- get new calculated price

      -- check  list price currency and order currency

      l_total           := l_pack_price * trunc(l_qty / l_divide_fact) +
                           (l_qty -
                           l_divide_fact * trunc(l_qty / l_divide_fact)) *
                           p_list_price; -- oe_order_pub.g_line.unit_list_price;
      l_calc_unit_price := l_total / l_qty;

      RETURN l_calc_unit_price;

    END IF; -- end XXPACK_OF
    -------------------------------------------------------------------------------

    /*      IF p_price_formula_id = 46039 THEN


        Select line_id
        into l_line_id
        from qp_preq_lines_tmp
        where line_index = p_req_line_attrs_tbl(1).line_index;

      RETURN l_line_id;

    END IF;*/

    -- -- yuval 1.3.2011
    IF p_price_formula_id = fnd_profile.value('XXQP_SPFORMULA') THEN

      -- CR 1174 Bug Fix: fix discount calculation in SO when using modifier with a formula
      -- find line_id from table qp_preq_lines_tmp
      SELECT line_id
        INTO l_line_id
        FROM qp_preq_lines_tmp
       WHERE line_index = p_req_line_attrs_tbl(1).line_index;

      RETURN xxcs_advance_pricing_util_pkg.get_spcoverage_discount(l_line_id);
      --      RETURN xxcs_advance_pricing_util_pkg.get_spcoverage_discount(oe_order_pub.g_line.line_id);

    END IF;

    -- END yuval 1.3.2011

    ---- Roman 21/06/2011
    IF p_price_formula_id = fnd_profile.value('XXQP_SERVICEITEM_FORMULA') THEN

      -- CR 1174 Bug Fix: fix discount calculation in SO when using modifier with a formula
      -- find line_id from table qp_preq_lines_tmp
      SELECT line_id
        INTO l_line_id
        FROM qp_preq_lines_tmp
       WHERE line_index = p_req_line_attrs_tbl(1).line_index;

      RETURN xxcs_advance_pricing_util_pkg.get_service_item_price(l_line_id);

      --        RETURN xxcs_advance_pricing_util_pkg.get_service_item_price(oe_order_pub.g_line.line_id);

    END IF;
    ---- End Roman 21/06/2011

    IF p_price_formula_id = 11027 THEN
      --Formula Name: XXITEM_AVG_COST

      FOR i IN 1 .. p_req_line_attrs_tbl.count LOOP
        IF p_req_line_attrs_tbl(i).attribute_type = 'PRODUCT' AND p_req_line_attrs_tbl(i)
           .context = 'ITEM' AND p_req_line_attrs_tbl(i)
           .attribute = 'PRICING_ATTRIBUTE1' THEN
          v_requested_item := p_req_line_attrs_tbl(i).value;
        END IF;

      END LOOP;

      RETURN xxinv_utils_pkg.get_item_cost(v_requested_item, 735);
    END IF;
    
    
    /* CHG0048665 - DIPTA added below formula handler - for CN intercomany pricing */
    if l_formula_name = 'XXCN_INTERCOMPANY_PRICE' then
       FOR i IN 1 .. p_req_line_attrs_tbl.count LOOP
        IF p_req_line_attrs_tbl(i).attribute_type = 'PRODUCT' AND p_req_line_attrs_tbl(i)
           .context = 'ITEM' AND p_req_line_attrs_tbl(i)
           .attribute = 'PRICING_ATTRIBUTE1' THEN
          v_requested_item := p_req_line_attrs_tbl(i).value;
        END IF;

      END LOOP;
      
      begin
        select qll.operand
          into l_cn_ic_price
          from qp_list_headers_all   qlh,
               qp_list_lines         qll,
               QP_PRICING_ATTRIBUTES qpa
         where qlh.name = 'CN INTERCOMPANY'
           and qlh.LIST_HEADER_ID = qll.list_header_id
           and qlh.LIST_TYPE_CODE = 'PRL'
           and qll.list_line_type_code = 'PLL'
           and qll.list_line_id = qpa.list_line_id
           and qpa.pricing_attribute_context is null
           and qpa.pricing_attribute is null
           and qpa.product_attribute_context = 'ITEM'
           and qpa.product_attribute = 'PRICING_ATTRIBUTE1'
           and qlh.ACTIVE_FLAG = 'Y'
           and trunc(sysdate) < nvl(qlh.END_DATE_ACTIVE,sysdate+1)
           and trunc(sysdate) < nvl(qll.end_date_active,sysdate+1)
           and qpa.product_attr_value = to_char(v_requested_item);
      exception when no_data_found then
        l_cn_ic_price := null;
      end;
      
      return l_cn_ic_price;
    end if;

    /* 28-APR-2014  Sandeep Akula Added Logic to get Standard Price for Formula Listed in Lookup XXQP_STD_COST_FORMULAS_LIST  (CHG0031469) */
    l_formula_cnt := '';
    BEGIN
      SELECT COUNT(*)
        INTO l_formula_cnt
        FROM qp_price_formulas
       WHERE price_formula_id = p_price_formula_id
         AND upper(NAME) IN
             (SELECT upper(flvv.meaning)
                FROM fnd_lookup_types_vl fltv, fnd_lookup_values_vl flvv
               WHERE fltv.security_group_id = flvv.security_group_id
                 AND fltv.view_application_id = flvv.view_application_id
                 AND fltv.lookup_type = flvv.lookup_type
                 AND fltv.lookup_type = 'XXQP_STD_COST_FORMULAS_LIST'
                 AND trunc(SYSDATE) BETWEEN trunc(flvv.start_date_active) AND
                     nvl(flvv.end_date_active, trunc(SYSDATE)));
    EXCEPTION
      WHEN OTHERS THEN
        l_formula_cnt := '0';
    END;

    IF l_formula_cnt > '0' THEN

      FOR i IN 1 .. p_req_line_attrs_tbl.count LOOP
        IF p_req_line_attrs_tbl(i).attribute_type = 'PRODUCT' AND p_req_line_attrs_tbl(i)
           .context = 'ITEM' AND p_req_line_attrs_tbl(i)
           .attribute = 'PRICING_ATTRIBUTE1' THEN
          v_requested_item := p_req_line_attrs_tbl(i).value;
        END IF;
      END LOOP;

      FOR c_1 IN c_lookup('XXQP_STD_COST_INV_ORGS_ORDER') LOOP
        l_std_cost := '';
        l_std_cost := xxinv_utils_pkg.get_std_cst_bsd_orgs_in_lookup('FROZEN',
                                                                     'XXQP_STD_COST_INV_ORGS_ORDER',
                                                                     c_1.meaning,
                                                                     v_requested_item);

        IF l_std_cost IS NOT NULL AND l_std_cost <> '0' THEN
          EXIT;
        END IF;

      END LOOP;

      IF l_std_cost IS NOT NULL THEN
        RETURN(l_std_cost);
      ELSIF l_std_cost IS NULL THEN
        RETURN('0');
      END IF;

    END IF;

    --  4/11/2017   Ofer Suad        CHG0040750  - Return STD cost for cost + logic

    IF l_formula_name = 'XX_GET_COGS' and  p_req_line_attrs_tbl(1)
      .line_index IS NOT NULL THEN
      l_ic_ip_flag := 0;

                     SELECT qplt.line_id
        INTO l_line_id
        FROM qp_preq_lines_tmp qplt
       WHERE qplt.line_index = p_req_line_attrs_tbl(1).line_index;


      begin
        SELECT count(1), ol.inventory_item_id
          into l_ic_ip_flag, v_requested_item
          FROM mtl_item_categories_v         mc,
               mtl_category_sets             mts,
               MTL_INTERCOMPANY_PARAMETERS_V mip,
               mtl_system_items_b            misb,
               oe_order_lines_all            ol,
               oe_order_headers_all          oh

         where ol.line_id = l_line_id
           and mc.organization_id =
               xxinv_utils_pkg.get_master_organization_id
           and misb.organization_id =
               xxinv_utils_pkg.get_master_organization_id
           and misb.inventory_item_id = ol.inventory_item_id
           and mc.inventory_item_id = ol.inventory_item_id
           and (mc.SEGMENT1 = to_char(ol.org_id)  and mc.SEGMENT2 = mip.SELL_ORGANIZATION_ID
           or mc.SEGMENT1 =mip.SELL_ORGANIZATION_ID   and mc.SEGMENT2 = to_char(ol.org_id))
           and mip.SHIP_ORGANIZATION_ID = oh.org_id
           and oh.INVOICE_TO_ORG_ID = mip.CUSTOMER_SITE_ID

           and mts.CATEGORY_SET_ID = mc.Category_Set_Id
           and mts.CATEGORY_SET_NAME = 'XX IP Operating Units'
           and ol.header_id = oh.header_id
           and oh.creation_date >
               fnd_profile.value('XXAR_ENABLE_IP_REV_ALLOCATION')
         group by ol.inventory_item_id;

      exception
        when others then
          l_ic_ip_flag := 0;
      end;
      IF l_ic_ip_flag = 0 THEN
        RETURN p_list_price;
      ELSE
        l_std_cost := xxcst_ratam_pkg.get_il_std_cost(null,
                                                      sysdate,
                                                      v_requested_item)*
                                                     (1+fnd_profile.VALUE('XXAR_COST_PLUS_PERCENT')/100);

        IF l_std_cost IS NOT NULL THEN
          RETURN(l_std_cost);
        ELSE
          RETURN p_list_price;
        END IF;
      end if;

    end if;

    -- End CHG0040750

    RETURN p_list_price;
  EXCEPTION
    WHEN OTHERS THEN

      RETURN NULL;

  END get_custom_price;
END qp_custom;
/
