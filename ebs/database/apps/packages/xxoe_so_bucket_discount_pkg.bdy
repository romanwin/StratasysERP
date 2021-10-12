CREATE OR REPLACE PACKAGE BODY xxoe_so_bucket_discount_pkg IS
  --------------------------------------------------------------------
  --  name:            xxoe_so_bucket_discount_pkg
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   16/11/2014
  --------------------------------------------------------------------
  --  purpose :        CHG0033422 – Sales Discount Bucket Program
  --------------------------------------------------------------------
  --  ver    date          name             desc
  --  1.0    16.11.2014    Michal Tzvik     Initial Build
  --  1.1    07.12.2014    Michal Tzvik     CHG0034003 - Resin Bucket:
  --                                        1. Procedure gen_report: update main sql
  --                                        2. global variables: 
  --                                           c_resin_discount_percent
  --                                           c_enable_resin_bucket_pricing
  --                                        3. Function before_report: add call to new procedure update_usage_amount
  --                                        4. Add new functions/procedures:
  --                                           get_resin_bckt_remain_amount
  --                                           get_line_resin_discount_amount
  --                                           get_so_resin_discount_amount
  --                                           get_resin_discount_percent
  --                                           is_order_in_resin_bucket
  --                                           update_usage_amount
  --                                           run_report
  --------------------------------------------------------------------

  c_resin_discount_percent      CONSTANT NUMBER := fnd_profile.value('XXOE_BUCKET_RESIN_DISC_PERCENT'); -- 14.12.2014  Michal Tzvik CHG0034003 - Resin Bucket
  c_enable_resin_bucket_pricing CONSTANT VARCHAR2(1) := nvl(fnd_profile.value('XX_ENABLE_RESIN_BUCKET_PRICING'), 'N'); -- 01.01.2015  Michal Tzvik CHG0034003 - Resin Bucket
  --------------------------------------------------------------------
  --  name:            get_resin_bucket_header_id
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   08/12/2014
  --------------------------------------------------------------------
  --  purpose :        
  --------------------------------------------------------------------
  --  ver    date        name             desc
  --  1.0    08/12/2014  Michal Tzvik     Initial Build - CHG0034003
  --------------------------------------------------------------------
  PROCEDURE get_resin_bucket_header(p_order_header_id         NUMBER,
                                    x_resin_bucket_header_rec OUT xxoe_discount_bucket_headers%ROWTYPE) IS
  
  BEGIN
  
    SELECT xdbh.*
    INTO   x_resin_bucket_header_rec
    FROM   oe_order_headers_all         ooha,
           oe_order_headers_all_dfv     oohad,
           hz_cust_site_uses_all        hcsua,
           hz_cust_acct_sites_all       hcasa,
           xxoe_discount_bucket_headers xdbh
    WHERE  1 = 1
    AND    ooha.header_id = p_order_header_id
    AND    oohad.row_id = ooha.rowid
    AND    oohad.indirect_use = 'Demo'
    AND    hcsua.site_use_id = ooha.ship_to_org_id
    AND    hcasa.cust_acct_site_id = hcsua.cust_acct_site_id
    AND    hcasa.cust_account_id = xdbh.customer_id
    AND    xxoe_so_bucket_discount_pkg.conv_date_to_quarter(oohad.sys_booking_date) =
           xdbh.period_name
    AND    xdbh.bucket_type_code = 'BENCHMARK'
    AND    xdbh.enable_flag = 'Y'
    AND    EXISTS
     (SELECT 1
            FROM   xxoe_discount_bucket_lines xdbl
            WHERE  xdbl.bucket_header_id = xdbh.bucket_header_id
            AND    xdbl.order_type_id = ooha.order_type_id
            AND    xdbl.enable_flag = 'Y')
    AND    rownum = 1;
  
  EXCEPTION
    WHEN no_data_found THEN
      NULL;
  END get_resin_bucket_header;

  --------------------------------------------------------------------
  --  name:            get_resin_bckt_remain_amount
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   08/12/2014
  --------------------------------------------------------------------
  --  purpose :        Get remaining amounts of resin bucket for given SO 
  --------------------------------------------------------------------
  --  ver    date        name             desc
  --  1.0    08/12/2014  Michal Tzvik     Initial Build - CHG0034003
  --------------------------------------------------------------------
  FUNCTION get_resin_bckt_remain_amount(p_order_header_id NUMBER)
    RETURN NUMBER IS
    l_remaining_amount NUMBER;
  BEGIN
    SELECT xdbh.bucket_amount_usd - nvl(xdbh.total_bucket_usage_amount, 0)
    INTO   l_remaining_amount
    FROM   xxoe_discount_bucket_headers xdbh,
           oe_order_headers_all         ooha,
           oe_order_headers_all_dfv     oohad,
           hz_cust_site_uses_all        hcsua,
           hz_cust_acct_sites_all       hcasa
    WHERE  1 = 1
    AND    ooha.header_id = p_order_header_id
    AND    oohad.row_id = ooha.rowid
    AND    oohad.indirect_use = 'Demo'
    AND    hcsua.site_use_id = ooha.ship_to_org_id
    AND    hcasa.cust_acct_site_id = hcsua.cust_acct_site_id
    AND    hcasa.cust_account_id = xdbh.customer_id
    AND    xdbh.bucket_type_code = 'BENCHMARK'
    AND    xxoe_so_bucket_discount_pkg.conv_date_to_quarter(oohad.sys_booking_date) =
           xdbh.period_name
    AND    xdbh.enable_flag = 'Y'
    AND    EXISTS
     (SELECT 1
            FROM   xxoe_discount_bucket_lines xdbl
            WHERE  xdbl.bucket_header_id = xdbh.bucket_header_id
            AND    xdbl.order_type_id = ooha.order_type_id
            AND    xdbl.enable_flag = 'Y');
  
    RETURN l_remaining_amount;
  
  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
  END get_resin_bckt_remain_amount;

  --------------------------------------------------------------------
  --  name:            get_line_adjustment_rate
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   08/12/2014
  --------------------------------------------------------------------
  --  purpose :        Get XX_BENCHMARK_ALLOWANCE adjustment rate of so line
  --                   used by QP_CUSTOM and form personalization (OEXOEORD)
  --------------------------------------------------------------------
  --  ver    date        name             desc
  --  1.0    08/12/2014  Michal Tzvik     Initial Build - CHG0034003
  --------------------------------------------------------------------
  FUNCTION get_line_adjustment_rate(p_line_id NUMBER) RETURN NUMBER IS
    l_rate NUMBER := 0;
  
  BEGIN
    SELECT opa.operand
    INTO   l_rate
    FROM   oe_price_adjustments opa,
           qp_list_headers_all  qlha
    WHERE  opa.list_line_type_code = 'DIS'
    AND    opa.line_id = p_line_id
    AND    opa.list_header_id = qlha.list_header_id
    AND    qlha.name = 'XX_BENCHMARK_ALLOWANCE';
  
    RETURN l_rate;
  
  EXCEPTION
    WHEN no_data_found THEN
      RETURN 0;
  END get_line_adjustment_rate;

  --------------------------------------------------------------------
  --  name:            get_line_resin_discount_amount
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   08/12/2014
  --------------------------------------------------------------------
  --  purpose :        Get potential amount of resin discount for given SO line.
  --                   used by QP_CUSTOM and form personalization (OEXOEORD)
  --------------------------------------------------------------------
  --  ver    date        name             desc
  --  1.0    08/12/2014  Michal Tzvik     Initial Build - CHG0034003
  --------------------------------------------------------------------
  FUNCTION get_line_resin_discount_amount(p_currency_code    VARCHAR2,
                                          p_sys_booking_date DATE,
                                          p_ordered_quantity NUMBER,
                                          p_unit_list_price  NUMBER)
    RETURN NUMBER IS
    l_discount_amount NUMBER := 0;
  BEGIN
    l_discount_amount := gl_currency_api.convert_amount(x_from_currency => p_currency_code,
                                                        
                                                        x_to_currency => 'USD',
                                                        
                                                        x_conversion_date => p_sys_booking_date,
                                                        
                                                        x_conversion_type => 'Corporate',
                                                        
                                                        x_amount => (c_resin_discount_percent / 100) *
                                                                     p_ordered_quantity *
                                                                     p_unit_list_price);
    RETURN l_discount_amount;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;
  END get_line_resin_discount_amount;

  --------------------------------------------------------------------
  --  name:            get_total_so_resin_disc_amount
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   08/12/2014
  --------------------------------------------------------------------
  --  purpose :        Get total amount of resin discount for given SO.
  --                   used by message XX_BUCKET_CALC_RESIN_2014
  --------------------------------------------------------------------
  --  ver    date        name             desc
  --  1.0    08/12/2014  Michal Tzvik     Initial Build - CHG0034003
  --------------------------------------------------------------------
  FUNCTION get_total_so_resin_disc_amount(p_order_header_id NUMBER,
                                          p_currency_code   VARCHAR2)
    RETURN NUMBER IS
    l_so_discount_amount NUMBER := 0;
  BEGIN
    SELECT gl_currency_api.convert_amount(x_from_currency => ooha.transactional_curr_code,
                                          
                                          x_to_currency => p_currency_code,
                                          
                                          x_conversion_date => oohad.sys_booking_date,
                                          
                                          x_conversion_type => 'Corporate',
                                          
                                          x_amount => SUM(nvl((-1) *
                                                               oola.ordered_quantity *
                                                               nvl(opa.adjusted_amount, 0), 0)))
    INTO   l_so_discount_amount
    FROM   oe_price_adjustments     opa,
           qp_secu_list_headers_vl  qsl,
           oe_order_headers_all     ooha,
           oe_order_headers_all_dfv oohad,
           oe_order_lines_all       oola
    WHERE  opa.list_line_type_code = 'DIS'
    AND    ooha.header_id = opa.header_id
    AND    oola.line_id = opa.line_id
    AND    opa.list_header_id = qsl.list_header_id
    AND    qsl.name = 'XX_BENCHMARK_ALLOWANCE'
    AND    oe_line_status_pub.get_line_status(oola.line_id, oola.flow_status_code) NOT IN
           ('Cancelled')
    AND    oola.line_category_code != 'RETURN'
    AND    oohad.row_id = ooha.rowid
    AND    ooha.header_id = p_order_header_id
    GROUP  BY ooha.transactional_curr_code,
              oohad.sys_booking_date;
  
    RETURN l_so_discount_amount;
  
  EXCEPTION
    WHEN no_data_found THEN
      RETURN 0;
  END get_total_so_resin_disc_amount;
  --------------------------------------------------------------------
  --  name:            get_so_resin_discount_amount
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   08/12/2014
  --------------------------------------------------------------------
  --  purpose :        Get amount of resin discount for given SO that
  --                   is not already calculated for xxoe_discount_bucket_headers.field total_bucket_usage_amount
  --                   and without p_exclude_line_id 
  --                   used by QP_CUSTOM, form personalization (OEXOEORD)
  --------------------------------------------------------------------
  --  ver    date        name             desc
  --  1.0    08/12/2014  Michal Tzvik     Initial Build - CHG0034003
  --------------------------------------------------------------------
  FUNCTION get_so_resin_discount_amount(p_exclude_line_id NUMBER,
                                        p_order_header_id NUMBER,
                                        p_currency_code   VARCHAR2)
    RETURN NUMBER IS
    l_so_discount_amount      NUMBER := 0;
    l_resin_bucket_header_rec xxoe_discount_bucket_headers%ROWTYPE;
  BEGIN
    get_resin_bucket_header(p_order_header_id, l_resin_bucket_header_rec);
  
    SELECT gl_currency_api.convert_amount(x_from_currency => ooha.transactional_curr_code,
                                          
                                          x_to_currency => p_currency_code,
                                          
                                          x_conversion_date => oohad.sys_booking_date,
                                          
                                          x_conversion_type => 'Corporate',
                                          
                                          x_amount => SUM(nvl((-1) *
                                                               oola.ordered_quantity *
                                                               nvl(opa.adjusted_amount, 0), 0)))
    INTO   l_so_discount_amount
    FROM   oe_price_adjustments     opa,
           qp_secu_list_headers_vl  qsl,
           oe_order_headers_all     ooha,
           oe_order_headers_all_dfv oohad,
           oe_order_lines_all       oola
    WHERE  opa.list_line_type_code = 'DIS'
    AND    ooha.header_id = opa.header_id
    AND    oola.line_id = opa.line_id
    AND    opa.list_header_id = qsl.list_header_id
    AND    qsl.name = 'XX_BENCHMARK_ALLOWANCE'
    AND    oe_line_status_pub.get_line_status(oola.line_id, oola.flow_status_code) NOT IN
           ('Cancelled')
    AND    oola.line_category_code != 'RETURN'
    AND    oohad.row_id = ooha.rowid
    AND    ooha.header_id = p_order_header_id
    AND    oola.line_id != nvl(p_exclude_line_id, -1) -- Current line discount is calculated separately
          -- Avoid calculating lines that were already calulated for total_bucket_usage_amount
    AND    oola.creation_date >
           nvl(l_resin_bucket_header_rec.usage_amount_update_date, oola.creation_date - 1)
    GROUP  BY ooha.transactional_curr_code,
              oohad.sys_booking_date;
  
    RETURN l_so_discount_amount;
  
  EXCEPTION
    WHEN no_data_found THEN
      RETURN 0;
  END get_so_resin_discount_amount;

  --------------------------------------------------------------------
  --  name:            get_resin_discount_percent
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   08/12/2014
  --------------------------------------------------------------------
  --  purpose :        Used by QP_CUSTOM in order to determine discount
  --                   for resin bucket. 
  --------------------------------------------------------------------
  --  ver    date        name             desc
  --  1.0    08/12/2014  Michal Tzvik     Initial Build - CHG0034003
  --------------------------------------------------------------------
  FUNCTION get_resin_discount_percent(p_order_line_id NUMBER) RETURN NUMBER IS
    l_order_line_rec          oe_order_lines_all%ROWTYPE;
    l_so_discount_amount      NUMBER := 0; -- total resin discount given in current sales order
    l_line_discount_amount    NUMBER := 0; -- Discount amount that should be applied to current line
    l_bucket_remaining_amount NUMBER;
    l_currency_code           oe_order_headers_all.transactional_curr_code%TYPE;
    l_sys_booking_date        DATE;
  
  BEGIN
  
    SELECT *
    INTO   l_order_line_rec
    FROM   oe_order_lines_all oola
    WHERE  oola.line_id = p_order_line_id;
  
    SELECT ooha.transactional_curr_code,
           oohad.sys_booking_date
    INTO   l_currency_code,
           l_sys_booking_date
    FROM   oe_order_headers_all     ooha,
           oe_order_headers_all_dfv oohad
    WHERE  ooha.header_id = l_order_line_rec.header_id
    AND    oohad.row_id(+) = ooha.rowid;
  
    -- total resin discount given in current sales order
    l_so_discount_amount := get_so_resin_discount_amount(l_order_line_rec.line_id, l_order_line_rec.header_id, 'USD');
  
    --get_so_resin_discount_amount(l_order_line_rec.header_id, 'USD');
  
    -- Get bucket remaining amount
    l_bucket_remaining_amount := get_resin_bckt_remain_amount(l_order_line_rec.header_id);
  
    -- Discount amount that should be applied to current line
    l_line_discount_amount := get_line_resin_discount_amount(p_currency_code => l_currency_code,
                                                             
                                                             p_sys_booking_date => l_sys_booking_date,
                                                             
                                                             p_ordered_quantity => l_order_line_rec.ordered_quantity,
                                                             
                                                             p_unit_list_price => l_order_line_rec.unit_list_price);
  
    IF l_bucket_remaining_amount >=
       l_so_discount_amount + l_line_discount_amount THEN
      RETURN c_resin_discount_percent;
    ELSE
      RETURN 0;
    END IF;
  
  END get_resin_discount_percent;

  --------------------------------------------------------------------
  --  name:            is_order_in_resin_bucket
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   08/12/2014
  --------------------------------------------------------------------
  --  purpose :        Return Y if sales order is included in bucket
  --                   
  --------------------------------------------------------------------
  --  ver    date        name             desc
  --  1.0    08/12/2014  Michal Tzvik     Initial Build - CHG0034003
  --------------------------------------------------------------------
  FUNCTION is_order_in_resin_bucket(p_order_header_id NUMBER) RETURN VARCHAR2 IS
    l_resin_bucket_header_rec xxoe_discount_bucket_headers%ROWTYPE;
  BEGIN
    IF c_enable_resin_bucket_pricing = 'N' THEN
      RETURN 'N';
    ELSE
      get_resin_bucket_header(p_order_header_id, l_resin_bucket_header_rec);
      IF l_resin_bucket_header_rec.bucket_header_id IS NULL THEN
        RETURN 'N';
      ELSE
        RETURN 'Y';
      END IF;
    END IF;
  
  END is_order_in_resin_bucket;

  --------------------------------------------------------------------
  --  name:            is_demo_order
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   27/11/2014
  --------------------------------------------------------------------
  --  purpose :        Check if it is a demo order. return Y/N
  --------------------------------------------------------------------
  --  ver    date        name             desc
  --  1.0    27/11/2014  Michal Tzvik     Initial Build - CHG0033422
  --------------------------------------------------------------------
  FUNCTION is_demo_order(p_order_header_id NUMBER) RETURN VARCHAR2 IS
    l_is_demo VARCHAR2(1);
  BEGIN
  
    SELECT nvl(MAX('Y'), 'N')
    INTO   l_is_demo
    FROM   oe_order_headers_all ooha
    WHERE  1 = 1
    AND    ooha.header_id = p_order_header_id
    AND    ooha.attribute11 = 'Demo'
    AND    NOT EXISTS
     (SELECT 1
            FROM   oe_order_lines_all oola,
                   mtl_system_items_b msib
            WHERE  oola.header_id = ooha.header_id
            AND    msib.inventory_item_id = oola.inventory_item_id
            AND    msib.organization_id = oola.ship_from_org_id
            AND    msib.inventory_item_id =
                   fnd_profile.value('XXOE_BUCKET_DEMO')); --'OBJ-14000'
  
    RETURN l_is_demo;
  
  END is_demo_order;

  --------------------------------------------------------------------
  --  name:            get_demo_allowed_discount
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   27/11/2014
  --------------------------------------------------------------------
  --  purpose :        Get demo allowed discount
  --  parameters:
  --   p_order_header_id       - Sales order header id
  --   p_pl_deviation_percent  - Allowed deviation from list price (percent)
  --   p_so_deviation_percent  - When item does not exist in direct PL,
  --                             use this value to calculate discount (percent)
  --------------------------------------------------------------------
  --  ver    date        name             desc
  --  1.0    27/11/2014  Michal Tzvik     Initial Build - CHG0033422
  --------------------------------------------------------------------
  FUNCTION get_demo_allowed_discount(p_order_header_id      NUMBER,
                                     p_pl_deviation_percent NUMBER,
                                     p_so_deviation_percent NUMBER)
    RETURN NUMBER IS
    l_discount_amount NUMBER;
  BEGIN
  
    SELECT SUM(nvl(oola.ordered_quantity *
                   (nvl(nvl((SELECT qpl.operand
                            FROM   qp_list_lines_v qpl -- direct pl
                            WHERE  qpl.list_header_id = qlhab.attribute11
                            AND    qpl.product_attribute_context = 'ITEM'
                            AND    oohad.sys_booking_date BETWEEN
                                   nvl(qpl.start_date_active, oohad.sys_booking_date - 1) AND
                                   nvl(qpl.end_date_active, oohad.sys_booking_date + 1)
                            AND    qpl.product_attr_value =
                                   to_char(oola.inventory_item_id)), (SELECT qpl.operand
                              FROM   qp_list_lines_v qpl -- direct pl
                              WHERE  qpl.list_header_id =
                                     qlhab.attribute11
                              AND    qpl.product_attribute_context =
                                     'ITEM'
                              AND    qpl.end_date_active IS NULL
                              AND    qpl.product_attr_value =
                                     to_char(oola.inventory_item_id))), oola.unit_list_price *
                         (100 +
                         p_so_deviation_percent) / 100) *
                   p_pl_deviation_percent / 100), 0))
    INTO   l_discount_amount
    FROM   oe_order_headers_all     ooha,
           oe_order_headers_all_dfv oohad,
           oe_order_lines_all       oola,
           qp_list_headers_all_b    qlhab
    WHERE  1 = 1
    AND    ooha.header_id = p_order_header_id
    AND    oohad.row_id = ooha.rowid
    AND    oola.header_id = ooha.header_id
    AND    oe_line_status_pub.get_line_status(oola.line_id, oola.flow_status_code) NOT IN
           ('Entered', 'Cancelled')
    AND    oola.line_category_code != 'RETURN'
    AND    qlhab.list_header_id(+) = oola.price_list_id;
  
    RETURN l_discount_amount;
  
  EXCEPTION
    WHEN no_data_found THEN
      RETURN 0;
  END get_demo_allowed_discount;

  --------------------------------------------------------------------
  --  name:            get_order_manual_discount
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   16/11/2014
  --------------------------------------------------------------------
  --  purpose :        Get manual discount of sales order
  --------------------------------------------------------------------
  --  ver    date        name             desc
  --  1.0    16/11/2014  Michal Tzvik     Initial Build - CHG0033422
  --------------------------------------------------------------------
  FUNCTION get_order_manual_discount(p_order_header_id NUMBER) RETURN NUMBER IS
    l_manual_discount NUMBER;
  BEGIN
    SELECT SUM(t.line_amount)
    INTO   l_manual_discount
    FROM   (SELECT (-1) * oola.ordered_quantity *
                   nvl(opa.adjusted_amount, 0) line_amount
            FROM   oe_price_adjustments opa,
                   oe_order_lines_all   oola,
                   mtl_system_items_b   msib
            WHERE  opa.list_line_type_code = 'DIS'
            AND    opa.automatic_flag = 'N'
            AND    opa.header_id = p_order_header_id
            AND    oola.line_id = opa.line_id
            AND    oe_line_status_pub.get_line_status(oola.line_id, oola.flow_status_code) NOT IN
                   ('Entered', 'Cancelled')
            AND    oola.line_category_code != 'RETURN'
            AND    msib.inventory_item_id = oola.inventory_item_id
            AND    msib.organization_id =
                   xxinv_utils_pkg.get_master_organization_id
            AND    msib.item_type !=
                   fnd_profile.value('XXAR_FREIGHT_AR_ITEM')
            AND    xxoe_utils_pkg.is_item_resin_credit(msib.inventory_item_id) = 'N'
            UNION ALL
            --resin_credit
            SELECT (-1) * oola.ordered_quantity * (nvl(oola.unit_selling_price, 0) -
                   nvl(oola.attribute4, 0)) line_amount
            FROM   oe_order_lines_all oola,
                   mtl_system_items_b msib
            WHERE  1 = 1
            AND    oola.header_id = p_order_header_id
            AND    oe_line_status_pub.get_line_status(oola.line_id, oola.flow_status_code) NOT IN
                   ('Entered', 'Cancelled')
            AND    oola.line_category_code != 'RETURN'
            AND    msib.inventory_item_id = oola.inventory_item_id
            AND    msib.organization_id =
                   xxinv_utils_pkg.get_master_organization_id
            AND    msib.item_type !=
                   fnd_profile.value('XXAR_FREIGHT_AR_ITEM')
            AND    xxoe_utils_pkg.is_item_resin_credit(msib.inventory_item_id) = 'Y') t;
  
    RETURN l_manual_discount;
  
  END get_order_manual_discount;

  --------------------------------------------------------------------
  --  name:            get_new_printer_list_price
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   16/11/2014
  --------------------------------------------------------------------
  --  purpose :        Get max list_price of new printer in sales order
  --------------------------------------------------------------------
  --  ver    date        name             desc
  --  1.0    16/11/2014  Michal Tzvik     Initial Build - CHG0033422
  --------------------------------------------------------------------
  FUNCTION get_new_printer_list_price(p_order_header_id NUMBER) RETURN NUMBER IS
    l_list_price NUMBER;
  BEGIN
  
    SELECT MAX(oola.unit_list_price)
    INTO   l_list_price
    FROM   oe_order_lines_all oola
    WHERE  oola.header_id = p_order_header_id
    AND    oola.cancelled_flag = 'N'
    AND    oe_line_status_pub.get_line_status(oola.line_id, oola.flow_status_code) NOT IN
           ('Entered', 'Cancelled')
    AND    xxinv_utils_pkg.get_category_segment('SEGMENT1', 1100000221, oola.inventory_item_id) =
           'Systems'
    AND    oola.ordered_quantity > 0;
  
    RETURN l_list_price;
  
  END get_new_printer_list_price;

  --------------------------------------------------------------------
  --  name:            get_retrnd_printer_list_price
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   16/11/2014
  --------------------------------------------------------------------
  --  purpose :        Get max list_price of returned printer in sales order
  --------------------------------------------------------------------
  --  ver    date        name             desc
  --  1.0    16/11/2014  Michal Tzvik     Initial Build - CHG0033422
  --------------------------------------------------------------------
  FUNCTION get_retrnd_printer_list_price(p_order_header_id NUMBER)
    RETURN NUMBER IS
    l_list_price NUMBER;
  BEGIN
  
    SELECT MAX(oola.unit_list_price)
    INTO   l_list_price
    FROM   oe_order_lines_all oola
    WHERE  oola.header_id = p_order_header_id
    AND    oola.cancelled_flag = 'N'
    AND    oe_line_status_pub.get_line_status(oola.line_id, oola.flow_status_code) NOT IN
           ('Entered', 'Cancelled')
    AND    xxinv_utils_pkg.get_category_segment('SEGMENT1', 1100000221, oola.inventory_item_id) =
           'Systems'
    AND    oola.ordered_quantity < 0;
  
    RETURN nvl(l_list_price, 0);
  
  END get_retrnd_printer_list_price;

  --------------------------------------------------------------------
  --  name:            get_so_total_amount
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   16/11/2014
  --------------------------------------------------------------------
  --  purpose :        Get total amount of sales order
  --------------------------------------------------------------------
  --  ver    date        name             desc
  --  1.0    16/11/2014  Michal Tzvik     Initial Build - CHG0033422
  --------------------------------------------------------------------
  FUNCTION get_so_total_amount(p_order_header_id NUMBER) RETURN NUMBER IS
    l_total_amount NUMBER;
  BEGIN
    SELECT SUM(oola.ordered_quantity * oola.unit_list_price)
    INTO   l_total_amount
    FROM   oe_order_lines_all oola
    WHERE  oola.header_id = p_order_header_id
    AND    oe_line_status_pub.get_line_status(oola.line_id, oola.flow_status_code) NOT IN
           ('Entered', 'Cancelled')
    AND    oola.cancelled_flag = 'N'
    AND    oola.line_category_code != 'RETURN';
  
    RETURN l_total_amount;
  
  END get_so_total_amount;

  --------------------------------------------------------------------
  --  name:            conv_date_to_quarter
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   16/11/2014
  --------------------------------------------------------------------
  --  purpose :        Convert date to quarter
  --------------------------------------------------------------------
  --  ver    date        name             desc
  --  1.0    16/11/2014  Michal Tzvik     Initial Build - CHG0033422
  --------------------------------------------------------------------
  FUNCTION conv_date_to_quarter(p_date DATE) RETURN VARCHAR2 IS
    l_quarter_name VARCHAR2(15);
  
  BEGIN
  
    l_quarter_name := 'Q' || to_char(p_date, 'Q') || '-' ||
                      to_char(p_date, 'YYYY');
  
    RETURN l_quarter_name;
  
  END conv_date_to_quarter;

  --------------------------------------------------------------------
  --  name:            get_quarter_first_day
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   16/11/2014
  --------------------------------------------------------------------
  --  purpose :        get date of first day in quarter
  --                   Format of parameter p_quarter_name is Q1-2014
  --------------------------------------------------------------------
  --  ver    date        name             desc
  --  1.0    16/11/2014  Michal Tzvik     Initial Build - CHG0033422
  --------------------------------------------------------------------
  FUNCTION get_quarter_first_day(p_quarter_name VARCHAR2) RETURN DATE IS
    l_date DATE;
  
  BEGIN
  
    SELECT gps.start_date
    INTO   l_date
    FROM   gl_period_statuses gps
    WHERE  gps.period_year = substr(p_quarter_name, 4)
    AND    gps.quarter_num = substr(p_quarter_name, 2, 1)
    AND    rownum = 1;
  
    RETURN l_date;
  
    /*  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;*/
  END get_quarter_first_day;

  --------------------------------------------------------------------
  --  name:            execute_dyn_sql
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   16/11/2014
  --------------------------------------------------------------------
  --  purpose :        Execute logic that is storen in application message
  --------------------------------------------------------------------
  --  ver    date        name             desc
  --  1.0    16/11/2014  Michal Tzvik     Initial Build - CHG0033422
  --------------------------------------------------------------------
  PROCEDURE execute_dyn_sql(p_message_name IN VARCHAR2,
                            p_header_id    IN NUMBER,
                            x_amount       OUT NUMBER,
                            x_percent      OUT NUMBER,
                            x_err_code     OUT NUMBER,
                            x_err_msg      OUT VARCHAR2) IS
    l_sql VARCHAR(2000);
  BEGIN
  
    fnd_message.set_name('XXOBJT', p_message_name);
    fnd_message.set_token('HEADER_ID', p_header_id);
    l_sql := fnd_message.get;
  
    EXECUTE IMMEDIATE l_sql
      USING p_header_id, OUT x_err_code, OUT x_err_msg, OUT x_amount, OUT x_percent;
  
  EXCEPTION
    WHEN OTHERS THEN
      x_err_code := 1;
      x_err_msg  := SQLERRM;
  END execute_dyn_sql;

  --------------------------------------------------------------------
  --  name:            gen_report
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   16/11/2014
  --------------------------------------------------------------------
  --  purpose :        Generate report: insert records to temporary table.
  --                   It is used by concurrent "XX: OM Sales Orders Discount Bucket Report"
  --                   (XXOMDISBUCKETREP)
  --------------------------------------------------------------------
  --  ver    date        name             desc
  --  1.0    16/11/2014  Michal Tzvik     Initial Build - CHG0033422
  --  1.1    07/12/2014  Michal Tzvik     CHG0034003 - Resin Bucket
  --                                      add out parameters
  --------------------------------------------------------------------
  PROCEDURE gen_report(x_err_code OUT NUMBER,
                       x_err_msg  OUT VARCHAR2) IS
    l_amount   NUMBER;
    l_percent  NUMBER;
    l_err_code NUMBER;
    l_err_msg  VARCHAR2(2000);
  
    CURSOR c_so IS
      SELECT xxinv_utils_pkg.get_lookup_meaning('XXOE_BUCKET_TYPE', xdbh.bucket_type_code) bucket_type,
             xdbh.parent_customer_location,
             xdbh.period_name,
             ooha.order_number,
             ooha.header_id,
             to_date(ooha.attribute2, 'YYYY/MM/DD HH24:MI:SS') so_sys_book_date,
             hou.name operating_unit,
             xdbl.calc_method_code,
             xdbl.limit_type,
             xdbl.from_limit,
             xdbl.to_limit,
             NULL bucket_usage_amount,
             xdbh.bucket_amount_usd,
             xdbl.bucket_header_id,
             xdbl.bucket_line_id,
             -- 04.12.2014 Michal Tzvik CHG0034003
             NULL             total_bucket_usage_amount,
             xdbh.customer_id
      FROM   oe_order_headers_all         ooha,
             xxoe_discount_bucket_headers xdbh,
             xxoe_discount_bucket_lines   xdbl,
             hr_operating_units           hou,
             -- 09.12.2014 Michal Tzvik CHG0034003 
             fnd_lookup_values     flv, -- bucket_type
             fnd_lookup_values_dfv flvd
      WHERE  1 = 1
      AND    xdbl.bucket_header_id = xdbh.bucket_header_id
      AND    xxoe_so_bucket_discount_pkg.conv_date_to_quarter(to_date(ooha.attribute2, 'YYYY/MM/DD HH24:MI:SS')) =
             xdbh.period_name
      AND    xdbh.parent_customer_location =
             xxhz_util.get_so_parent_cust_location(ooha.header_id)
      AND    ooha.order_type_id = xdbl.order_type_id
            -- AND    ooha.flow_status_code = 'BOOKED' -- 09.12.2014 Michal Tzvik CHG0034003: Move this condition down. it depends on DFF value.
      AND    hou.organization_id = ooha.org_id
      AND    xdbh.parent_customer_location =
             nvl(p_parent_customer_location, xdbh.parent_customer_location)
      AND    xdbh.bucket_type_code =
             nvl(p_bucket_type_code, xdbh.bucket_type_code)
      AND    (p_from_period_name IS NULL OR
            xxoe_so_bucket_discount_pkg.get_quarter_first_day(xdbh.period_name) >=
            xxoe_so_bucket_discount_pkg.get_quarter_first_day(p_from_period_name))
      AND    (p_to_period_name IS NULL OR
            xxoe_so_bucket_discount_pkg.get_quarter_first_day(xdbh.period_name) <=
            xxoe_so_bucket_discount_pkg.get_quarter_first_day(p_to_period_name))
      AND    (nvl(p_run_global, 'N') = 'Y' OR EXISTS
             (SELECT 1
               FROM   xxgl_location_seg_v xlsv
               WHERE  xlsv.org_id = fnd_global.org_id
               AND    xlsv.parent_location_desc =
                      xdbh.parent_customer_location))
      AND    (nvl(p_permission_by_org, 'N') = 'N' OR
            ooha.org_id = fnd_global.org_id)
            -- 07.12.2014 Michal Tzvik CHG0034003
      AND    flv.lookup_type = 'XXOE_BUCKET_TYPE'
      AND    flv.language = 'US'
      AND    SYSDATE BETWEEN nvl(flv.start_date_active, SYSDATE - 1) AND
             nvl(flv.end_date_active, SYSDATE + 1)
      AND    flv.enabled_flag = 'Y'
      AND    flv.lookup_code = xdbh.bucket_type_code
      AND    flvd.row_id(+) = flv.rowid
      AND    ooha.flow_status_code IN
             ('BOOKED', 'CLOSED', decode(flvd.include_so_with_status_entered, 'Y', 'ENTERED', ''))
      AND    (nvl(xdbh.customer_id, -1) =
            nvl(p_customer_id, nvl(xdbh.customer_id, -1)) AND
            (xdbh.customer_id IS NULL OR EXISTS
             (SELECT 1
                FROM   hz_cust_site_uses_all  hcsua,
                       hz_cust_acct_sites_all hcasa
                WHERE  hcsua.site_use_id = ooha.ship_to_org_id
                AND    hcasa.cust_acct_site_id = hcsua.cust_acct_site_id
                AND    hcasa.cust_account_id = xdbh.customer_id)));
  
    -- 16.12.2014 Michal Tzvik CHG0034003: Bug fix: Display buckets that no sales order use
    CURSOR c_bucket_without_so IS
      SELECT xxinv_utils_pkg.get_lookup_meaning('XXOE_BUCKET_TYPE', xdbh.bucket_type_code) bucket_type,
             xdbh.parent_customer_location,
             xdbh.period_name,
             xdbh.bucket_amount_usd,
             0 total_bucket_usage_amount,
             xdbh.customer_id,
             xdbh.bucket_header_id
      FROM   xxoe_discount_bucket_headers xdbh
      WHERE  1 = 1
      AND    xdbh.parent_customer_location =
             nvl(p_parent_customer_location, xdbh.parent_customer_location)
      AND    xdbh.bucket_type_code =
             nvl(p_bucket_type_code, xdbh.bucket_type_code)
      AND    (p_from_period_name IS NULL OR
            xxoe_so_bucket_discount_pkg.get_quarter_first_day(xdbh.period_name) >=
            xxoe_so_bucket_discount_pkg.get_quarter_first_day(p_from_period_name))
      AND    (p_to_period_name IS NULL OR
            xxoe_so_bucket_discount_pkg.get_quarter_first_day(xdbh.period_name) <=
            xxoe_so_bucket_discount_pkg.get_quarter_first_day(p_to_period_name))
      AND    (nvl(p_run_global, 'N') = 'Y' OR EXISTS
             (SELECT 1
               FROM   xxgl_location_seg_v xlsv
               WHERE  xlsv.org_id = fnd_global.org_id
               AND    xlsv.parent_location_desc =
                      xdbh.parent_customer_location))
      AND    nvl(xdbh.customer_id, -1) =
             nvl(p_customer_id, nvl(xdbh.customer_id, -1))
      AND    NOT EXISTS
       (SELECT 1
              FROM   xxoe_discount_bucket_rep_tmp xdbrt
              WHERE  xdbrt.bucket_header_id = xdbh.bucket_header_id);
  
  BEGIN
    x_err_code := '0';
    x_err_msg  := '';
  
    FOR r_so IN c_so LOOP
    
      execute_dyn_sql(r_so.calc_method_code, r_so.header_id, l_amount, l_percent, l_err_code, l_err_msg);
    
      IF l_err_code != 0 THEN
        x_err_code := '1';
        x_err_msg  := 'Error in executing code from ' ||
                      r_so.calc_method_code || ' for header id = ' ||
                      r_so.header_id || ': ' || l_err_msg;
        RETURN;
      ELSE
      
        IF (r_so.limit_type = 'PERCENT' AND
           l_percent BETWEEN r_so.from_limit AND r_so.to_limit) OR
           (r_so.limit_type = 'AMOUNT' AND l_amount BETWEEN r_so.from_limit AND
           r_so.to_limit) OR
           (r_so.limit_type IS NULL AND nvl(l_amount, 0) != 0) THEN
        
          r_so.bucket_usage_amount := l_amount;
        
          INSERT INTO xxoe_discount_bucket_rep_tmp
          VALUES r_so;
        END IF;
      END IF;
    
    END LOOP;
  
    -- 04.12.2014 Michal Tzvik CHG0034003: Start
  
    -- Bug fix: Display buckets that no sales order use
    FOR r_bucket IN c_bucket_without_so LOOP
      INSERT INTO xxoe_discount_bucket_rep_tmp
        (bucket_type,
         parent_customer_location,
         period_name,
         bucket_amount_usd,
         bucket_header_id,
         total_bucket_usage_amount,
         customer_id)
      VALUES
        (r_bucket.bucket_type,
         r_bucket.parent_customer_location,
         r_bucket.period_name,
         r_bucket.bucket_amount_usd,
         r_bucket.bucket_header_id,
         r_bucket.total_bucket_usage_amount,
         r_bucket.customer_id);
    END LOOP;
  
    -- Update bucket usage amount
    UPDATE xxoe_discount_bucket_rep_tmp xdbrt
    SET    xdbrt.total_bucket_usage_amount =
           (SELECT SUM(xdbrt1.bucket_usage_amount)
            FROM   xxoe_discount_bucket_rep_tmp xdbrt1
            WHERE  xdbrt1.bucket_header_id = xdbrt.bucket_header_id);
  
  EXCEPTION
    WHEN OTHERS THEN
      x_err_code := '1';
      x_err_msg  := 'Error gen_report: ' || SQLERRM;
      -- 04.12.2014 Michal Tzvik CHG0034003: End
  END gen_report;

  --------------------------------------------------------------------
  --  name:            update_usage_amount
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   16/12/2014
  --------------------------------------------------------------------
  --  purpose :        Update usage amount in bucket header table.
  --                   Used by modifier XX_RESIN_BUCKET in order to determine
  --                   discount percent.
  --------------------------------------------------------------------
  --  ver    date        name             desc
  --  1.0    16/12/2014  Michal Tzvik     Initial Build - CHG0034003  Resin Bucket
  --------------------------------------------------------------------
  PROCEDURE update_usage_amount(x_err_code OUT NUMBER,
                                x_err_msg  OUT VARCHAR2) IS
  BEGIN
    x_err_code := '0';
    x_err_msg  := '';
  
    IF nvl(p_run_global, 'N') = 'Y' AND nvl(p_permission_by_org, 'N') = 'N' THEN
      fnd_file.put_line(fnd_file.log, 'Updating total_bucket_usage_amount...');
      FOR r_bucket IN (SELECT DISTINCT xdbrt.bucket_header_id,
                                       xdbrt.total_bucket_usage_amount
                       FROM   xxoe_discount_bucket_rep_tmp xdbrt) LOOP
      
        UPDATE xxoe_discount_bucket_headers xdbh
        SET    xdbh.total_bucket_usage_amount = r_bucket.total_bucket_usage_amount,
               xdbh.usage_amount_update_date  = SYSDATE,
               xdbh.last_update_date          = SYSDATE,
               xdbh.last_updated_by           = fnd_global.user_id,
               xdbh.last_update_login         = fnd_global.login_id
        WHERE  xdbh.bucket_header_id = r_bucket.bucket_header_id;
      
      END LOOP;
    END IF;
  
    COMMIT;
  
  EXCEPTION
    WHEN OTHERS THEN
      x_err_code := 1;
      x_err_msg  := 'Error in update_usage_amount: ' || SQLERRM;
  END update_usage_amount;
  --------------------------------------------------------------------
  --  name:            before_report
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   16/11/2014
  --------------------------------------------------------------------
  --  purpose :        Before report trigger: call gen_report
  --                   It is used by concurrent "XX: OM Sales Orders Discount Bucket Report"
  --                   (XXOMDISBUCKETREP)
  --------------------------------------------------------------------
  --  ver    date        name             desc
  --  1.0    16/11/2014  Michal Tzvik     Initial Build - CHG0033422
  --  1.1    16/12/2014  Michal Tzvik     CHG0034003 - update bucket's usage amount 
  --------------------------------------------------------------------
  FUNCTION before_report RETURN BOOLEAN IS
    l_err_code NUMBER;
    l_err_msg  VARCHAR2(2000);
  BEGIN
  
    gen_report(l_err_code, l_err_msg);
    -- 16.12.2014 Michal Tzvik CHG0034003: start
    IF l_err_code != 0 THEN
      fnd_file.put_line(fnd_file.log, l_err_msg);
      RETURN FALSE;
    END IF;
    update_usage_amount(l_err_code, l_err_msg);
    IF l_err_code != 0 THEN
      fnd_file.put_line(fnd_file.log, l_err_msg);
      RETURN FALSE;
    END IF;
    -- 16.12.2014 Michal Tzvik CHG0034003: end
  
    RETURN TRUE;
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log, 'Unexpected error in XXOE_SO_BUCKET_DISCOUNT_PKG.before_report: ' ||
                         SQLERRM);
      RETURN FALSE;
  END before_report;

  --------------------------------------------------------------------
  --  name:            run_report
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   31/12/2014
  --------------------------------------------------------------------
  --  purpose :        Shell concurrent that will be scheduled.
  --                   It is needed in order to calculate parameters
  --                   of from/to period according to sysdate.
  --                   Concurrent short name: XXOMUPDATEBUCKBALANCE
  --------------------------------------------------------------------
  --  ver    date        name             desc
  --  1.0    31/12/2014  Michal Tzvik     Initial Build - CHG0034003
  --------------------------------------------------------------------
  PROCEDURE run_report(errbuf                     OUT VARCHAR2,
                       retcode                    OUT VARCHAR2,
                       p_run_global               VARCHAR2,
                       p_parent_customer_location VARCHAR2,
                       p_customer_id              NUMBER,
                       p_bucket_type_code         VARCHAR2,
                       p_previous_quarters        NUMBER) IS
  
    l_request_id NUMBER;
    l_phase      VARCHAR2(150);
    l_dev_status VARCHAR2(150);
    l_dev_phase  VARCHAR2(150);
    l_message    VARCHAR2(150);
    l_return     BOOLEAN;
    l_status     VARCHAR2(150);
  
    l_from_period_name VARCHAR2(10);
    l_to_period_name   VARCHAR2(10);
  BEGIN
    errbuf  := '';
    retcode := '0';
  
    l_to_period_name   := conv_date_to_quarter(SYSDATE);
    l_from_period_name := conv_date_to_quarter(add_months(SYSDATE, -3 *
                                                           nvl(p_previous_quarters, 0)));
  
    fnd_file.put_line(fnd_file.log, 'From period: ' || l_from_period_name ||
                       ' to period: ' || l_to_period_name);
  
    l_return := fnd_request.add_layout(template_appl_name => 'XXOBJT',
                                       
                                       template_code => 'XXOMDISBUCKETREP',
                                       
                                       template_language => 'en',
                                       
                                       template_territory => 'US',
                                       
                                       output_format => 'EXCEL');
    IF NOT l_return THEN
      errbuf  := 'Failed to add layout';
      retcode := '0';
      fnd_file.put_line(fnd_file.log, 'Failed to add layout');
    ELSE
      l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                                 
                                                 program => 'XXOMDISBUCKETREP',
                                                 
                                                 start_time => '',
                                                 
                                                 sub_request => FALSE,
                                                 
                                                 argument1 => p_run_global,
                                                 
                                                 argument2 => p_parent_customer_location,
                                                 
                                                 argument3 => p_customer_id,
                                                 
                                                 argument4 => p_bucket_type_code,
                                                 
                                                 argument5 => l_from_period_name,
                                                 
                                                 argument6 => l_to_period_name,
                                                 
                                                 argument7 => 'N' --p_permission_by_org
                                                 );
    
      IF l_request_id = 0 THEN
        errbuf  := 'Failed to submit request.';
        retcode := '1';
      ELSE
      
        COMMIT;
        fnd_file.put_line(fnd_file.log, 'Request id = ' || l_request_id);
      
        l_return := fnd_concurrent.wait_for_request(request_id => l_request_id,
                                                    
                                                    INTERVAL => 10,
                                                    
                                                    max_wait => 300,
                                                    
                                                    phase => l_phase,
                                                    
                                                    status => l_status,
                                                    
                                                    dev_phase => l_dev_phase,
                                                    
                                                    dev_status => l_dev_status,
                                                    
                                                    message => l_message);
        IF l_return THEN
          fnd_file.put_line(fnd_file.log, 'Request id ' || l_request_id ||
                             ' completed normal');
        ELSE
          errbuf  := 'Request has been failed.';
          retcode := '1';
          fnd_file.put_line(fnd_file.log, 'Request id ' || l_request_id ||
                             ' failed with the message: ' ||
                             l_message);
        END IF;
      END IF;
    END IF;
  END run_report;

END xxoe_so_bucket_discount_pkg;
/
