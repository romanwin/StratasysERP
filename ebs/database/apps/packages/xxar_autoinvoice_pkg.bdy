create or replace package body xxar_autoinvoice_pkg IS

  --------------------------------------------------------------------
  --  name:              XXAR_AUTOINVOICE_PKG
  --  create by:         XXX
  --  Revision:          1.0
  --  creation date:     31/08/2009
  --------------------------------------------------------------------
  --  purpose :          Auto invoice modifications
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  31/08/2009    XXX               initial build
  --  1.1  XX/xx/XXxx    Daniel Katz
  --  1.2  15/01/2012    Ofer Suad         add procedure handle_contracts_from_om_trx
  --                                       Update accounting rule and DE tax code for Service contracts from OM
  --  1.3  29/01/2012    Ofer Suad         Add Sale order number to resin credit error messages
  --       20/05/2012    Ofer Suad         Add Coupon accounting
  --  1.4  1.7.12        ofer suad         add safe divisor to handle_coupon_pos_trx
  --  1.5  27-dec-2012   Ofer Suad         Move Call to handle_coupon_pos_trx out of Intial order block
  --  1.6  02-Jun-2013   Ofer Suad         Add hold to Japan invoice when running Standard /Trad in order
  --                                       for all sale order - Run only if specifing the sale order number
  --  1.7  11-08-2013    Ofer suad         round total amount to invoice currency precision - In JPY case precision=01 */
  --  1.8  13/10/2013    ofer Suad         Cahnges to support ssys bundle sale orders and new chart of account  CR -1122
  --  1.9  15/10/2014    ofer Suad         Fix org Id CR-1122
  --  2.0  11/03/2014    Ofer Suad         Add OKL Logic CR 1336
  --  2.1  04/15/2014    Venu Kandi        CR # CHG0031959 - Code fix for invoices program
  --  2.2  20/06/2014    Mike Mazanet      CHG0032527. Added p_batch_source parameter to handle_coupon_neg_trx to prevent double
  --                                       counting of ra_interface_lines which for different interface_line_contexts
  --  2.3  29/06/2014    Ofer Suad         CR # CHG0032527   Update transaction type and item for LEASEOP lines
  --  2.4  08/07/2014    Ofer Suad         CR # CHG0032527 Change Resin crdit check - Enable using against FDM Items
  --  2.5  25/08/2014    Ofer Suad         CR #CHG0032772 - Set that the autoinvoice process will not fall if only one or few sales order have error.
  --  2.6  20/10/2014    Ofer Suad         CR #CHG0033506 AR clearing account 403000 for bundle invoices with multiple ship set is wrong
  --  2.7  20/10/2014    Ofer Suad         CR #CHG0033168 Enable using resin credit against all items type
  --  2.8  22/10/2014    Ofer Suad         CR #CHG0032650?PTOs: Average Discount Calculation and Revenue Distribution
  --  2.9  04/12/2014    Michal Tzvik      CHG0033952 ?Resin Credit Program attribute11 change
  --  3.0  18/21/2015    Ofer Suad         CHG0032677?verage discount for all orders type
  --  3.1  18/02/2015    M.Mazanet         CHG0033379.  Added call to xxar_intercompany_pkg.process_intercompany_invoices for
  --                                       invoicing partial receipt of invoices.
  --  3.2  17/02/2015    Ofer Suad         CHG0034523-100% Average discount and add Activty details to service contracts
  --  3.3  18/06/2015    ofer Suad(yuval)  CHG0035690 get_price_list_dist : Fix Revenue Distribution Divide to zero bug
  --  3.4  30/07/2015    ofer Suad(Dalit)  CHG0035457 - XXAutoinvoice program for Service credits
  --                                       handle_contracts_from_om_trx add update of rla.invoicing_rule_id
  --  3.5  27-Jan-2016   Diptasurjya       CHG0037525 - make payment terms null for Credit Memo OKL transactions in handle_okl_contracts_trx
  --  3.6  10-Feb-2016   Ofer Suad         CHG0037700-  fix 100% Resin credit accounting
  --  3.7  31-May-2016   Ofer Suad         CHG0036536 -  Invoice date for Contract orders
  --                     L Sarangi         CHG0036536 - Code added to Package
  --  3.8  21.7.2016     yuval tal         CHG0038970 - get_price_list_dist logic moved to xxoe_utils_pkg.get_price_list_dist
  --  3.9  18-Aug-2016   Yuval tal         CHG0038192 - Revenue distribution mechanisim for Buy&Get items
  --  4.0  30/03/2017    Lingaraj Sarangi  CHG0040281 - Auto Invoice failing to import Service Contract Invoices if the Contract Start Date is a Future Date
  --                                                  New Procedure Added [handle_invoice_conversion_date]
  --  4.2  11/07/2017    Lingaraj Sarangi  CHG0040750 - Allocate revenue to LE that own IP when item assembled in another LE
  --                                                  Changes Done for Inter Company Invoices
  --  4.1  02/10/2017    Yuval tal         CHG0041505 - Modify handle_maintenance_trx_date : Invoice Date for DE Rental Orders should be the date when it was interfaced to AR Interface.
  --  4.3  17/07/2017    Erik Morgan       CHG0040938 - Modify process_trx_lines : Remove restriction for JP batch
  --                                                  Code modified By Piyali Bhowmick
  --  4.4  04/03/2018    Dan.M             CHG0042261 - Autoinvoice does not calculate correct resin credit balance
  --  5.0  08/05/2018    Ofer S./Roman W.  CHG0042417 - Remove condition for drop shipment
  --  5.1  17/07/2018    Lingaraj          CHG0043603 - REASON_CODE need to Remove for Defective SO Line types to create a single CM
  --  5.2  03/12/2019    Roman W.          CHG0044816 - Some JP invoices does not have avarage discunt calcualted
  --  5.3  09/12/2019    Roman W.          CHG0044863 - As result of moving to OKS module - need to set contract lines rule start date for
  --                                                     Initial Order to ship date+ warranty period +60 days (profile)
  --  5.4  10/05/2019    Bellona(TCS)      CHG0045219 - Add exclude_from_avg_discount
  --  5.5  11/07/2019    Roman W.          CHG0045869 - changes in invoice date for service contracts
  --                                                procedure : handle_maintenance_trx_date
  --  5.6  12-NOV-2020   Diptasurjya       CHG0048763 - Modify rounding_remainder_handling to not update Avg Discount excluded lines
  --------------------------------------------------------------------

  TYPE rila_order_numbers_type IS TABLE OF NUMBER INDEX BY BINARY_INTEGER;
  TYPE rila_order_headers_type IS TABLE OF NUMBER INDEX BY BINARY_INTEGER;
  TYPE rila_order_currencies_type IS TABLE OF oe_order_headers_all.transactional_curr_code%TYPE INDEX BY BINARY_INTEGER;

  -- 18/08/2016 #CHG0038192
  TYPE g_item_price_type IS TABLE OF NUMBER INDEX BY BINARY_INTEGER;
  g_item_price g_item_price_type;

  --------------------------------------------------------------------

  PROCEDURE submit_request(errbuf                      OUT NOCOPY VARCHAR2,
                           retcode                     OUT NOCOPY NUMBER,
                           p_num_of_instances          IN VARCHAR2,
                           p_organization              NUMBER,
                           p_batch_source_id           IN ra_batch_sources.batch_source_id%TYPE,
                           p_batch_source_name         IN VARCHAR2,
                           p_default_date              IN VARCHAR2,
                           p_trans_flexfield           IN VARCHAR2,
                           p_trx_type_id               IN ra_cust_trx_types.cust_trx_type_id%TYPE,
                           p_low_bill_to_cust_num      IN hz_cust_accounts.account_number%TYPE,
                           p_high_bill_to_cust_num     IN hz_cust_accounts.account_number%TYPE,
                           p_low_bill_to_cust_name     IN hz_parties.party_name%TYPE,
                           p_high_bill_to_cust_name    IN hz_parties.party_name%TYPE,
                           p_low_gl_date               IN VARCHAR2,
                           p_high_gl_date              IN VARCHAR2,
                           p_low_ship_date             IN VARCHAR2,
                           p_high_ship_date            IN VARCHAR2,
                           p_low_trans_number          IN ra_interface_lines.trx_number%TYPE,
                           p_high_trans_number         IN ra_interface_lines.trx_number%TYPE,
                           p_low_sales_order_num       IN ra_interface_lines.sales_order%TYPE,
                           p_high_sales_order_num      IN ra_interface_lines.sales_order%TYPE,
                           p_low_invoice_date          IN VARCHAR2,
                           p_high_invoice_date         IN VARCHAR2,
                           p_low_ship_to_cust_num      IN hz_cust_accounts.account_number%TYPE,
                           p_high_ship_to_cust_num     IN hz_cust_accounts.account_number%TYPE,
                           p_low_ship_to_cust_name     IN hz_parties.party_name%TYPE,
                           p_high_ship_to_cust_name    IN hz_parties.party_name%TYPE,
                           p_base_due_date_on_trx_date IN fnd_lookups.meaning%TYPE,
                           p_due_date_adj_days         IN NUMBER) IS

    x_req_id NUMBER(38);
    --call_status BOOLEAN;
    rphase  VARCHAR2(30);
    rstatus VARCHAR2(30);
    dphase  VARCHAR2(30);
    dstatus VARCHAR2(30);
    message VARCHAR2(240);

  BEGIN

    fnd_file.put_line(fnd_file.log,
                      'submit_request: ' || 'XXOBJT Submitting Autoinvoice');

    x_req_id := fnd_request.submit_request('AR',
                                           'RAXMTR',
                                           'Autoinvoice Master Program',
                                           SYSDATE,
                                           FALSE,
                                           p_num_of_instances,
                                           p_organization,
                                           p_batch_source_id,
                                           p_batch_source_name,
                                           p_default_date,
                                           p_trans_flexfield,
                                           p_trx_type_id,
                                           p_low_bill_to_cust_num,
                                           p_high_bill_to_cust_num,
                                           p_low_bill_to_cust_name,
                                           p_high_bill_to_cust_name,
                                           p_low_gl_date,
                                           p_high_gl_date,
                                           p_low_ship_date,
                                           p_high_ship_date,
                                           p_low_trans_number,
                                           p_high_trans_number,
                                           p_low_sales_order_num,
                                           p_high_sales_order_num,
                                           p_low_invoice_date,
                                           p_high_invoice_date,
                                           p_low_ship_to_cust_num,
                                           p_high_ship_to_cust_num,
                                           p_low_ship_to_cust_name,
                                           p_high_ship_to_cust_name,
                                           p_base_due_date_on_trx_date,
                                           p_due_date_adj_days);

    COMMIT;
    IF x_req_id = 0 THEN
      retcode := 2;
      errbuf  := 'Could not run Autoinvoice';
    ELSE

      IF fnd_concurrent.wait_for_request(request_id => x_req_id,
                                         INTERVAL   => 5,
                                         phase      => rphase,
                                         status     => rstatus,
                                         dev_phase  => dphase,
                                         dev_status => dstatus,
                                         message    => message) THEN

        NULL;

      END IF;
    END IF;

  END submit_request;

  --------------------------------------------------------------------
  FUNCTION safe_devisor(p_devisor NUMBER) RETURN NUMBER IS
  BEGIN
    IF p_devisor IS NULL THEN
      RETURN 1;
    ELSIF p_devisor = 0 THEN
      RETURN 1;
    ELSE
      RETURN p_devisor;
    END IF;

  END safe_devisor;
  -------------------------------------------------------------
  -- 18/08/2016 #CHG0038192

  FUNCTION get_item_price(p_line_id NUMBER) RETURN NUMBER IS

  BEGIN
    RETURN g_item_price(p_line_id);
  EXCEPTION
    WHEN OTHERS THEN

      fnd_file.put_line(fnd_file.log,
                        'Exception in Get item price calculation');
      RETURN NULL;

  END get_item_price;

  --------------------------------------------------------------------
  FUNCTION get_precision(p_currency_code VARCHAR2) RETURN NUMBER IS
    lv_precision fnd_currencies.precision%TYPE;
  BEGIN

    SELECT PRECISION
      INTO lv_precision
      FROM fnd_currencies c
     WHERE c.currency_code = p_currency_code;

    RETURN lv_precision;

  END get_precision;

  --------------------------------------------------------------------
  -- Ofer Suad 13/10/2013  add Boundle transactions
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  18/06/2015         ofer Suad(yuval)   CHG0035690 get_price_list_dist : Fix Revenue Distribution Divide to zero bug
  --  21.7.2016      yuval tal              CHG0038970- logic moved to xxoe_utils_pkg.get_price_list_dist
  FUNCTION get_price_list_dist(p_line_id    NUMBER,
                               p_price_list NUMBER,
                               p_attribute4 NUMBER) RETURN NUMBER IS

    /* l_is_resin              VARCHAR2(1);
    l_cupon_amt             NUMBER;
    l_bundle_line_amt       NUMBER;
    l_comp_bundle_total_amt NUMBER;
    l_option_total_amt      NUMBER; --22/10/2014 Ofer Suad #CHG0032650
    l_option_qty            NUMBER; --22/10/2014 Ofer Suad #CHG0032650
    l_temp_option_total_amt NUMBER; --22/10/2014 Ofer Suad #CHG0032650
    l_option_line_amt       NUMBER; --22/10/2014 Ofer Suad #CHG0032650
    l_model_amt             NUMBER; --22/10/2014 Ofer Suad #CHG0032650
    l_resin_amt             NUMBER; --22/10/2014 Ofer Suad #CHG0032650*/

    /* CURSOR c_option_line IS --22/10/2014 Ofer Suad #CHG0032650
    SELECT ol.inventory_item_id,
           ol.ordered_quantity,
           ol.line_id,
           ol.price_list_id,
           ol.order_quantity_uom
    FROM   oe_order_lines_all ol
    WHERE  (ol.header_id, ol.top_model_line_id) =
           (SELECT header_id,
                   ol1.top_model_line_id
            FROM   oe_order_lines_all ol1
            WHERE  ol1.line_id = p_line_id)
    AND    xxoe_utils_pkg.is_option_line(ol.line_id) = 'Y';*/

  BEGIN

    RETURN xxoe_utils_pkg.get_price_list_dist(p_line_id,
                                              p_price_list,
                                              p_attribute4);

    /*   --Begin 22/10/2014 Ofer Suad #CHG0032650
    SELECT decode(msi.item_type,
                  fnd_profile.value('XXAR_CREDIT_RESIN_ITEM_TYPE'),
                  'Y',
                  'N')
    INTO   l_is_resin
    FROM   oe_order_lines_all ol,
           mtl_system_items_b msi
    WHERE  ol.line_id = p_line_id
    AND    ol.inventory_item_id = msi.inventory_item_id
    AND    nvl(ol.ship_from_org_id,
               xxinv_utils_pkg.get_master_organization_id) =
           msi.organization_id;

    SELECT nvl(SUM(ol.attribute4), 0)
    INTO   l_resin_amt
    FROM   oe_order_lines_all ol,
           mtl_system_items_b msi
    WHERE  (ol.header_id, ol.top_model_line_id) =
           (SELECT header_id,
                   ol1.top_model_line_id
            FROM   oe_order_lines_all ol1
            WHERE  ol1.line_id = p_line_id)
    AND    ol.inventory_item_id = msi.inventory_item_id
    AND    nvl(ol.ship_from_org_id,
               xxinv_utils_pkg.get_master_organization_id) =
           msi.organization_id
    AND    msi.item_type = fnd_profile.value('XXAR_CREDIT_RESIN_ITEM_TYPE');

    SELECT round(nvl(SUM(ol.ordered_quantity * ol.unit_list_price), 0),
                 get_precision(MAX(oh.transactional_curr_code)))
    INTO   l_model_amt
    FROM   oe_order_lines_all   ol,
           oe_order_headers_all oh
    WHERE  xxoe_utils_pkg.is_model_line(ol.line_id) = 'Y'
    AND    oh.header_id = ol.header_id
    AND    (ol.header_id, ol.top_model_line_id) =
           (SELECT header_id,
                    ol1.top_model_line_id
             FROM   oe_order_lines_all ol1
             WHERE  ol1.line_id = p_line_id);

    l_option_total_amt := 0;

    FOR i IN c_option_line LOOP
      IF i.line_id = p_line_id THEN
        l_option_qty := i.ordered_quantity;
      END IF;
      l_temp_option_total_amt := 0;
      SELECT MAX(i.ordered_quantity *
                 inv_convert.inv_um_convert_new(i.inventory_item_id,
                                                NULL,
                                                pll1.operand,
                                                i.order_quantity_uom,
                                                pll1.product_uom_code,
                                                NULL,
                                                NULL,
                                                'U'))
      INTO   l_temp_option_total_amt
      FROM   apps.qp_list_lines_v pll1
      WHERE  pll1.list_header_id = i.price_list_id
      AND    nvl(trunc(pll1.end_date_active), trunc(SYSDATE + 1)) >=
             trunc(SYSDATE)
      AND    pll1.product_attr_value = to_char(i.inventory_item_id);
      IF l_temp_option_total_amt IS NULL THEN
        BEGIN
          SELECT operand * i.ordered_quantity
          INTO   l_temp_option_total_amt
          FROM   (SELECT inv_convert.inv_um_convert_new(i.inventory_item_id,
                                                        NULL,
                                                        pll2.operand,
                                                        i.order_quantity_uom,
                                                        pll2.product_uom_code,

                                                        NULL,
                                                        NULL,
                                                        'U') operand,
                         qspl.precedence

                  FROM   apps.qp_secondary_price_lists_v qspl,
                         apps.qp_list_lines_v            pll2
                  WHERE  to_char(i.price_list_id) =
                         qspl.parent_price_list_id
                  AND    pll2.list_header_id = qspl.list_header_id
                  AND    nvl(trunc(pll2.end_date_active),
                             trunc(SYSDATE + 1)) >= trunc(SYSDATE)
                  AND    to_char(i.inventory_item_id) =
                         pll2.product_attr_value
                  ORDER  BY precedence)
          WHERE  rownum = 1;
        EXCEPTION
          WHEN no_data_found THEN
            l_temp_option_total_amt := 0;
        END;
      END IF;
      l_option_total_amt := l_option_total_amt + l_temp_option_total_amt;
    END LOOP;

    BEGIN
      SELECT MAX(ol.ordered_quantity *
                 inv_convert.inv_um_convert_new(ol.inventory_item_id,
                                                NULL,
                                                pll1.operand,
                                                ol.order_quantity_uom,
                                                pll1.product_uom_code,

                                                NULL,
                                                NULL,
                                                'U')) operand
      INTO   l_option_line_amt
      FROM   apps.qp_list_lines_v pll1,
             oe_order_lines_all   ol
      WHERE  pll1.list_header_id = ol.price_list_id
      AND    nvl(trunc(pll1.end_date_active), trunc(SYSDATE + 1)) >=
             trunc(SYSDATE)
      AND    pll1.product_attr_value = to_char(ol.inventory_item_id)
      AND    ol.line_id = p_line_id;

      IF l_option_line_amt IS NULL THEN
        SELECT operand
        INTO   l_option_line_amt
        FROM   (SELECT ol.ordered_quantity *
                       inv_convert.inv_um_convert_new(ol.inventory_item_id,
                                                      NULL,
                                                      pll2.operand,
                                                      ol.order_quantity_uom,
                                                      pll2.product_uom_code,

                                                      NULL,
                                                      NULL,
                                                      'U') operand,
                       qspl.precedence

                FROM   apps.qp_secondary_price_lists_v qspl,
                       apps.qp_list_lines_v            pll2,
                       oe_order_lines_all              ol
                WHERE  ol.line_id = p_line_id
                AND    to_char(ol.price_list_id) = qspl.parent_price_list_id
                AND    pll2.list_header_id = qspl.list_header_id
                AND    nvl(trunc(pll2.end_date_active), trunc(SYSDATE + 1)) >=
                       trunc(SYSDATE)
                AND    to_char(ol.inventory_item_id) =
                       pll2.product_attr_value
                ORDER  BY qspl.precedence)
        WHERE  rownum = 1;
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        l_option_line_amt := 0;
    END;
    -- end 22/10/2014 Ofer Suad #CHG0032650

    IF xxoe_utils_pkg.is_bundle_line(p_line_id) = 'Y' OR
       xxoe_utils_pkg.is_model_line(p_line_id) = 'Y' THEN
      RETURN 0;
    ELSIF xxoe_utils_pkg.is_comp_bundle_line(p_line_id) = 'Y' THEN
      SELECT SUM(ol.unit_list_price)
      INTO   l_bundle_line_amt
      FROM   oe_order_lines_all ol
      WHERE  ol.header_id = (SELECT ol1.header_id
                             FROM   oe_order_lines_all ol1
                             WHERE  ol1.line_id = p_line_id)
      AND    xxoe_utils_pkg.is_bundle_line(ol.line_id) = 'Y';

      SELECT SUM(ol.unit_list_price * ol.ordered_quantity)
      INTO   l_comp_bundle_total_amt
      FROM   oe_order_lines_all ol
      WHERE  ol.header_id = (SELECT ol1.header_id
                             FROM   oe_order_lines_all ol1
                             WHERE  ol1.line_id = p_line_id)
      AND    xxoe_utils_pkg.is_comp_bundle_line(ol.line_id) = 'Y';
      RETURN l_bundle_line_amt *(p_price_list /
                                 safe_devisor(l_comp_bundle_total_amt)); --CHG0035690 add safe_devisor

    ELSIF xxoe_utils_pkg.is_option_line(p_line_id) = 'Y'

     THEN
      IF l_is_resin = 'N' THEN
        RETURN(l_option_line_amt / safe_devisor(l_option_qty)) *(l_model_amt / ----CHG0035690 add safe_devisor
                                                                 safe_devisor(l_option_total_amt + --CHG0035690 add safe_devisor
                                                                              l_resin_amt));
      ELSE
        RETURN l_resin_amt *(l_model_amt /
                             safe_devisor(l_option_total_amt + l_resin_amt)); --CHG0035690 add safe_devisor
      END IF;
    ELSE
      BEGIN

        SELECT ol.unit_selling_price
        INTO   l_cupon_amt
        FROM   oe_order_lines_all ol,
               mtl_system_items_b msi
        WHERE  ol.line_id = p_line_id
        AND    ol.inventory_item_id = msi.inventory_item_id
        AND    ol.ship_from_org_id = msi.organization_id
        AND    msi.item_type = fnd_profile.value('XXAR_COUPON_ITEM_TYPE');
        RETURN l_cupon_amt;
      EXCEPTION
        WHEN no_data_found THEN
          BEGIN

            SELECT 'Y'
            INTO   l_is_resin
            FROM   oe_order_lines_all ol,
                   mtl_system_items_b msi
            WHERE  ol.line_id = p_line_id
            AND    ol.inventory_item_id = msi.inventory_item_id
            AND    nvl(ol.ship_from_org_id,
                       xxinv_utils_pkg.get_master_organization_id) =
                   msi.organization_id
            AND    msi.item_type !=
                   fnd_profile.value('XXAR_CREDIT_RESIN_ITEM_TYPE');

            RETURN p_price_list;

          EXCEPTION
            WHEN no_data_found THEN

              RETURN p_attribute4;

          END;

      END;
    END IF;*/
  END get_price_list_dist;

  -------------------------------------------------------------------
  FUNCTION get_price_list_for_resin(p_line_id    NUMBER,
                                    p_price_list NUMBER,
                                    p_attribute4 NUMBER) RETURN NUMBER IS

    l_is_resin  VARCHAR2(1);
    l_cupon_amt NUMBER;

    -- 18/08/2016 #CHG0038192

    CURSOR price_detail_cur IS

      SELECT oola.line_id,
             ooha.price_list_id,
             oola.inventory_item_id,
             oola.pricing_date
        FROM oe_order_headers_all ooha, oe_order_lines_all oola
       WHERE ooha.header_id = oola.header_id
         AND oola.header_id =
             (SELECT ol.header_id
                FROM oe_order_lines_all ol
               WHERE ol.line_id = p_line_id)
         AND xxqp_get_item_avg_dis_pkg.is_get_item_line(oola.line_id) = 'Y';

  BEGIN
    BEGIN

      FOR price_detail_rec IN price_detail_cur LOOP

        g_item_price(price_detail_rec.line_id) := xxqp_get_item_avg_dis_pkg.get_price(price_detail_rec.inventory_item_id,
                                                                                      price_detail_rec.price_list_id,
                                                                                      price_detail_rec.pricing_date,
                                                                                      price_detail_rec.line_id);

      END LOOP;

    EXCEPTION
      WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log,
                          'Exception in Get item price calculation');

    END;
    -- Ofer Suad 13/10/2013  add Boundle transactions
    IF xxoe_utils_pkg.is_comp_bundle_line(p_line_id) = 'Y' THEN
      RETURN 0;
    ELSIF xxqp_get_item_avg_dis_pkg.is_get_item_line(p_line_id) = 'Y' THEN
      RETURN get_item_price(p_line_id);
    ELSE
      BEGIN

        SELECT ol.unit_selling_price
          INTO l_cupon_amt
          FROM oe_order_lines_all ol, mtl_system_items_b msi
         WHERE ol.line_id = p_line_id
           AND ol.inventory_item_id = msi.inventory_item_id
           AND ol.ship_from_org_id = msi.organization_id
           AND msi.item_type = fnd_profile.value('XXAR_COUPON_ITEM_TYPE');
        RETURN l_cupon_amt;
      EXCEPTION
        WHEN no_data_found THEN
          BEGIN

            SELECT 'Y'
              INTO l_is_resin
              FROM oe_order_lines_all ol, mtl_system_items_b msi
             WHERE ol.line_id = p_line_id
               AND ol.inventory_item_id = msi.inventory_item_id
               AND nvl(ol.ship_from_org_id,
                       xxinv_utils_pkg.get_master_organization_id) =
                   msi.organization_id
               AND (msi.item_type !=
                   fnd_profile.value('XXAR_CREDIT_RESIN_ITEM_TYPE') OR
                   xxoe_utils_pkg.is_option_line(p_line_id) = 'Y');

            RETURN p_price_list;

          EXCEPTION
            WHEN no_data_found THEN

              RETURN p_attribute4;

          END;

      END;
    END IF;
  END get_price_list_for_resin;

  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  31/08/2009    XXX               initial build
  --  1.1  10/05/2019    Ofer Suad         CHG0045219 - that lines with modifier marked with Exclude from Avg Discount
  --                          Calc flag will not be added to rounding differences.
  --  1.2  12-NOV-2020   Diptasurjya       CHG0048763 - Change update section to not adjust rounding difference on 
  --                                       Avg discount excluded lines
  --------------------------------------------------------------------
  PROCEDURE rounding_remainder_handling(pn_header_id        NUMBER,
                                        pn_order_number     NUMBER,
                                        pn_avarage_discount NUMBER,
                                        pn_precision        NUMBER,
                                        --added by daniel katz on 25-nov-09
                                        pn_org_id NUMBER) IS

    lv_non_invoiced_lines VARCHAR2(20);
    l_so_amount           NUMBER;
    l_avg_inter_amount    NUMBER;
    l_avg_ar_amount       NUMBER;
    l_rounding_difference NUMBER;
  BEGIN

    --if non invoiced row exists - return
    BEGIN

      SELECT to_char(line_id)
        INTO lv_non_invoiced_lines
        FROM oe_order_lines_all ol, oe_transaction_types_all ott
       WHERE header_id = pn_header_id
         AND ol.line_type_id = ott.transaction_type_id
         AND ol.cancelled_flag = 'N'
         AND ol.flow_status_code != 'CANCELLED'
            --following condition commited and replaced below by daniel katz because invociced auantity not alwyas exists
            --AND ol.invoiced_quantity >= 0
         AND ol.line_category_code = 'ORDER'
         AND nvl(ott.attribute2, 'Y') = 'Y'
         AND
            --added conditions below by daniel katz (this check should be only on relevant lines who participate in average discount calculation)
             unit_selling_price >= 0
         AND NOT EXISTS
       (SELECT 1
                FROM mtl_system_items_b msi
               WHERE msi.inventory_item_id = ol.inventory_item_id
                 AND msi.organization_id = ol.ship_from_org_id
                 AND msi.item_type IN
                     (fnd_profile.value('XXAR PREPAYMENT ITEM TYPES'),
                      fnd_profile.value('XXAR_FREIGHT_AR_ITEM')))
      ----------------------------------------------------------------------------------------------------------------
      MINUS
      SELECT interface_line_attribute6
        FROM ra_interface_lines_all
      --added by daniel katz to_char
       WHERE interface_line_attribute1 = to_char(pn_order_number)
            --added by daniel katz on 25-nov-09 to ignore intercompany invoice
         AND org_id = pn_org_id

      MINUS
      SELECT interface_line_attribute6
        FROM ra_customer_trx_lines_all
       WHERE sales_order = to_char(pn_order_number)
            --added by daniel katz on 25-nov-09 to ignore intercompany invoice
         AND org_id = pn_org_id;

      -- not all order lines in invoice
      RETURN;

      NULL;
    EXCEPTION
      WHEN too_many_rows THEN
        -- not all order lines in invoice
        RETURN;
      WHEN no_data_found THEN
        NULL;
    END;
    --else check if corrction needed and update the line with max amount
    BEGIN
      --commented by daniel katz and add below --> replaced the round with the sum
      --         SELECT round(SUM(ordered_quantity * unit_selling_price),
      --                      pn_precision)
      SELECT SUM(round(ordered_quantity * unit_selling_price, pn_precision))
        INTO l_so_amount
        FROM oe_order_lines_all ol, oe_transaction_types_all ott
       WHERE header_id = pn_header_id
         AND ol.line_type_id = ott.transaction_type_id
         AND ol.cancelled_flag = 'N'
         AND ol.flow_status_code != 'CANCELLED'
         AND ol.invoiced_quantity >= 0
         AND nvl(ott.attribute2, 'Y') = 'Y'
         AND

            --added conditions below by daniel katz (this check should be only on relevant lines who participate in average discount calculation)
             unit_selling_price >= 0
         AND NOT EXISTS
       (SELECT 1
                FROM mtl_system_items_b msi
               WHERE msi.inventory_item_id = ol.inventory_item_id
                 AND msi.organization_id = ol.ship_from_org_id
                 AND msi.item_type IN
                     (fnd_profile.value('XXAR PREPAYMENT ITEM TYPES'),
                      fnd_profile.value('XXAR_FREIGHT_AR_ITEM')))
         AND exclude_from_avg_discount(ol.line_id) = 'N'; --CHG0045219

    EXCEPTION
      WHEN OTHERS THEN
        l_so_amount := 0;
    END;

    BEGIN
      --commented by daniel katz and replaced below (added function get price list for resin)
      --  CR #CHG0033506 get_price_list_dist imstead of unit_standard_price
      --         SELECT SUM(round(unit_standard_price * quantity *
      SELECT SUM(round(get_price_list_dist(rila.interface_line_attribute6,
                                           unit_standard_price,
                                           rila.attribute4) * quantity *
                       (100 - pn_avarage_discount) / 100,
                       pn_precision))
        INTO l_avg_inter_amount
        FROM ra_interface_lines_all rila
      --commented by daniel katz following condition line and added full set of conditions to only relevant lines
      --          WHERE interface_line_attribute1 = pn_order_number;

       WHERE rila.interface_line_attribute1 = to_char(pn_order_number)
         AND rila.quantity_ordered >= 0
         AND rila.unit_selling_price >= 0
         AND rila.line_type = 'LINE'
         AND exclude_from_avg_discount(rila.interface_line_attribute6) = 'N' --CHG0045219
         AND NOT EXISTS
       (SELECT 1
                FROM mtl_system_items_b msi
               WHERE msi.inventory_item_id = rila.inventory_item_id
                 AND msi.organization_id = rila.warehouse_id
                 AND msi.item_type IN
                     (fnd_profile.value('XXAR PREPAYMENT ITEM TYPES'),
                      fnd_profile.value('XXAR_FREIGHT_AR_ITEM')))
         AND EXISTS
       (SELECT 1
              --ott table and conditions added by daniel katz on 24-jan-10
                FROM oe_order_lines_all ol, oe_transaction_types_all ott
               WHERE ol.line_id = rila.interface_line_attribute6
                 AND ol.header_id = pn_header_id
                 AND ol.line_type_id = ott.transaction_type_id
                 AND nvl(ott.attribute2, 'Y') = 'Y')
         AND rila.interface_line_context IN ('ORDER ENTRY', 'INTERCOMPANY')
            --added by daniel katz on 25-nov-09 to ignore intercompany invoice
         AND rila.org_id = pn_org_id;
      -------------------------------------------------------------------------------------
    EXCEPTION
      WHEN OTHERS THEN
        l_avg_inter_amount := 0;
    END;

    BEGIN
      --  CR #CHG0033506 get_price_list_dist imstead of unit_standard_price
      --<daniel katz> here standard unit price takes into account resin credit if exists
      SELECT SUM(round( /*unit_standard_price*/decode(xxqp_get_item_avg_dis_pkg.is_get_item_line(rctl.interface_line_attribute6),
                              'Y',
                              get_item_price(rctl.interface_line_attribute6),
                              xxar_autoinvoice_pkg.get_price_list_dist(rctl.interface_line_attribute6,
                                                                       rctl.unit_standard_price,
                                                                       rctl.attribute4)) *
                       quantity_invoiced *
                       (100 - pn_avarage_discount) / 100,
                       pn_precision))
        INTO l_avg_ar_amount
        FROM ra_customer_trx_lines_all rctl
      --commented by daniel katz following condition line and added full set of conditions to only relevant lines + sales order is with index
      --          WHERE interface_line_attribute1 = pn_order_number;

       WHERE rctl.sales_order = to_char(pn_order_number)
         AND rctl.quantity_invoiced >= 0
         AND rctl.unit_selling_price >= 0
         AND rctl.line_type = 'LINE'
         AND exclude_from_avg_discount(rctl.interface_line_attribute6) = 'N' --CHG0045219
         AND NOT EXISTS
       (SELECT 1
                FROM mtl_system_items_b msi
               WHERE msi.inventory_item_id = rctl.inventory_item_id
                 AND msi.organization_id = rctl.warehouse_id
                 AND msi.item_type IN
                     (fnd_profile.value('XXAR PREPAYMENT ITEM TYPES'),
                      fnd_profile.value('XXAR_FREIGHT_AR_ITEM')))
         AND EXISTS
       (SELECT 1
                FROM oe_order_lines_all ol
               WHERE ol.line_id = rctl.interface_line_attribute6
                 AND ol.header_id = pn_header_id)
         AND rctl.interface_line_context IN ('ORDER ENTRY', 'INTERCOMPANY')
         AND rctl.attribute10 IS NOT NULL
            --added by daniel katz on 25-nov-09 to ignore intercompany invoice
         AND rctl.org_id = pn_org_id;
      -------------------------------------------------------------------
    EXCEPTION
      WHEN OTHERS THEN
        l_avg_ar_amount := 0;
    END;

    l_rounding_difference := nvl(l_so_amount, 0) -
                             nvl(l_avg_inter_amount, 0) -
                             nvl(l_avg_ar_amount, 0);

    UPDATE ra_interface_lines_all rila
       SET amount = amount + l_rounding_difference
    --commented by daniel katz and replaced with other condition set
    --because there is no value in interface line id (there is value only if line rejected by auto invoice program),
    -- + the amount should be descending (to take the MAX) + missing specific order number and more conditions... .
    /*       WHERE rila.interface_line_id =
                 (SELECT interface_line_id
                    FROM (SELECT interface_line_id, amount
                            FROM ra_interface_lines_all rila1
                           WHERE rila1.interface_line_attribute1 =
                                 rila1.interface_line_attribute1 AND
                                 rila1.quantity_ordered >= 0 AND
                                 rila1.unit_selling_price >= 0 AND
                                 rila1.line_type = 'LINE' AND
                                 NOT EXISTS
                           (SELECT 1
                                    FROM mtl_system_items_b msi
                                   WHERE msi.inventory_item_id =
                                         rila1.inventory_item_id AND
                                         msi.organization_id = rila1.warehouse_id AND
                                         msi.item_type IN
                                         (fnd_profile.VALUE('XXAR PREPAYMENT ITEM TYPES'),
                                          fnd_profile.VALUE('XXAR_FREIGHT_AR_ITEM')))
                           ORDER BY amount)
                   WHERE rownum < 2);
    */
     WHERE ROWID =
           (SELECT ROWID
              FROM (SELECT ROWID, amount
                      FROM ra_interface_lines_all rila_in
                     WHERE rila_in.interface_line_attribute1 =
                           to_char(pn_order_number)
                       AND rila_in.quantity_ordered >= 0
                       AND rila_in.unit_selling_price >= 0
                       AND rila_in.line_type = 'LINE'
                       AND NOT EXISTS
                     (SELECT 1
                              FROM mtl_system_items_b msi
                             WHERE msi.inventory_item_id =
                                   rila_in.inventory_item_id
                               AND msi.organization_id = rila_in.warehouse_id
                               AND msi.item_type IN
                                   (fnd_profile.value('XXAR PREPAYMENT ITEM TYPES'),
                                    fnd_profile.value('XXAR_FREIGHT_AR_ITEM')))
                          --ott table and conditions added by daniel katz on 24-jan-10
                       AND EXISTS
                     (SELECT 1
                              FROM oe_order_lines_all       ol,
                                   oe_transaction_types_all ott
                             WHERE ol.line_id =
                                   rila_in.interface_line_attribute6
                               AND ol.header_id = pn_header_id
                               AND ol.line_type_id = ott.transaction_type_id
                               AND nvl(ott.attribute2, 'Y') = 'Y')
                       AND rila_in.interface_line_context IN
                           ('ORDER ENTRY', 'INTERCOMPANY')
                       and exclude_from_avg_discount(rila_in.interface_line_attribute6) = 'N'  -- CHG0048763 added
                          --added by daniel katz on 25-nov-09 to ignore intercompany invoice
                       AND rila_in.org_id = pn_org_id
                     ORDER BY amount DESC)
             WHERE rownum < 2);
  EXCEPTION
    WHEN OTHERS THEN
      NULL;

  END rounding_remainder_handling;

  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  31/08/2009    XXX               initial build
  --  1.1  10/05/2019    Ofer Suad         CHG0045219 - lines with modifier marked with Exclude from Avg Discount
  --                    Calc flag will not be taken into account in avarage discount calculation.
  --------------------------------------------------------------------
  FUNCTION calculate_avarage_discount(pn_header_id    NUMBER,
                                      pn_order_number NUMBER,
                                      x_rate          OUT NUMBER,
                                      x_return_status OUT VARCHAR2,
                                      x_err_msg       OUT VARCHAR2)
    RETURN NUMBER IS

    ln_calc_avg_discount     NUMBER(10);
    ln_new_calc_avg_discount NUMBER(10);
    l_is_not_valid           NUMBER;

  BEGIN

    -- check if attribute4 on resin credit exists
    BEGIN

      SELECT 1
        INTO l_is_not_valid
        FROM ra_interface_lines_all rila,
             mtl_system_items_b     msi_mas,
             oe_order_lines_all     ol
       WHERE rila.inventory_item_id = msi_mas.inventory_item_id
         AND msi_mas.organization_id =
             xxinv_utils_pkg.get_master_organization_id
         AND rila.interface_line_attribute1 = to_char(pn_order_number)
         AND rila.interface_line_attribute6 = to_char(ol.line_id)
         AND ol.header_id = pn_header_id
         AND rila.amount >= 0
         AND msi_mas.item_type =
             fnd_profile.value('XXAR_CREDIT_RESIN_ITEM_TYPE')
         AND rila.attribute4 IS NULL
         AND rownum < 2;

      fnd_message.set_name('XXOBJT', 'XXAR_AUTOINV_MISS_CREDIT_RESIN');
      -- 1.3  29/01/2012 Ofer Suad Add sale order number to error message
      fnd_message.set_token('SALE_ORDER', to_char(pn_order_number));
      fnd_file.put_line(fnd_file.output, fnd_message.get);
      fnd_file.put_line(fnd_file.log, fnd_message.get);
      x_err_msg := 'NO_ATTRIBUTE4';
      RETURN 0;

    EXCEPTION
      WHEN no_data_found THEN
        NULL;
    END;

    --check if invoice already exists
    BEGIN
      SELECT rctl.attribute10, rct.exchange_rate
        INTO ln_calc_avg_discount, x_rate
      --added by daniel katz table oe order lines for retrieving by order header id in addition to sale order for safe
        FROM ra_customer_trx_all       rct,
             ra_customer_trx_lines_all rctl,
             oe_order_lines_all        ol
       WHERE rct.customer_trx_id = rctl.customer_trx_id
         AND rctl.sales_order = to_char(pn_order_number)
         AND rctl.interface_line_attribute6 = to_char(ol.line_id)
         AND ol.header_id = pn_header_id
         AND rctl.attribute10 IS NOT NULL
         AND rownum < 2;

    EXCEPTION
      WHEN no_data_found THEN
        NULL;
    END;

    --Round(100*{1- [SUM(ORDERED_QUANTITY*UNIT_SELLING_PRICE)/
    --                                        SUM(ORDERED_QUANTITY*UNIT_LIST_PRICE)]},2)

    SELECT round(100 * (1 -
                 (SUM(ordered_quantity * unit_selling_price) /
                 safe_devisor(SUM(ordered_quantity *
                                          get_price_list_for_resin(ol.line_id,
                                                                   ol.unit_list_price,
                                                                   ol.attribute4))))),
                 2)
      INTO ln_new_calc_avg_discount
      FROM oe_order_lines_all ol, oe_transaction_types_all ott
     WHERE header_id = pn_header_id
       AND ol.line_type_id = ott.transaction_type_id
       AND ol.cancelled_flag = 'N'
       AND ol.flow_status_code != 'CANCELLED'
          --commented and replaced below by daniel katz as invoiced quantity not always exists
          --AND ol.invoiced_quantity >= 0
       AND ol.line_category_code = 'ORDER'
       AND unit_selling_price >= 0
       AND nvl(ott.attribute2, 'Y') = 'Y'
       AND NOT EXISTS
     (SELECT 1
              FROM mtl_system_items_b msi
             WHERE msi.inventory_item_id = ol.inventory_item_id
               AND msi.organization_id = ol.ship_from_org_id
               AND msi.item_type IN
                   (fnd_profile.value('XXAR PREPAYMENT ITEM TYPES'),
                    fnd_profile.value('XXAR_FREIGHT_AR_ITEM')))
       and exclude_from_avg_discount(ol.line_id) = 'N'; --CHG0045219

    IF nvl(ln_calc_avg_discount, nvl(ln_new_calc_avg_discount, 0)) !=
       nvl(ln_new_calc_avg_discount, 0) THEN

      fnd_file.put_line(fnd_file.log,
                        'for order :' || pn_order_number ||
                        ' current average discount: ' ||
                        ln_calc_avg_discount || ', new average discount: ' ||
                        ln_new_calc_avg_discount);

      --<daniel katz> this value will determine whether rounding remainder will be handled at main procedure.
      --in this case it won't raise any exception on main procedure

      x_return_status := fnd_api.g_ret_sts_error;

    ELSE
      ln_calc_avg_discount := ln_new_calc_avg_discount;
      --added by daniel katz
      x_return_status := fnd_api.g_ret_sts_success;

    END IF;

    RETURN ln_calc_avg_discount;

  END calculate_avarage_discount;

  --------------------------------------------------------------------
  PROCEDURE handle_pos_prepayments_trx(p_order_numbers IN rila_order_numbers_type,
                                       p_organization  IN NUMBER,
                                       x_return_status OUT VARCHAR2,
                                       x_err_msg       OUT VARCHAR2) IS

  BEGIN

    x_return_status := fnd_api.g_ret_sts_success;

    --  Update prepayments transaction type FOR POSITIVE LINE
    FORALL idx IN 1 .. p_order_numbers.count
      UPDATE ra_interface_lines_all rila
         SET rila.cust_trx_type_id = fnd_profile.value_specific('XXAR_PREPAYMENT_DEST_TRX_TYPE',
                                                                NULL,
                                                                NULL,
                                                                NULL,
                                                                p_organization),
             rila.gl_date          = trunc(SYSDATE), --added by daniel katz on 19-sep-10
             rila.trx_date         = trunc(SYSDATE), --added by daniel katz on 19-sep-10
             rila.rule_start_date  = trunc(SYSDATE) /*decode(rila.rule_start_date,
                                                                                                                                                                                                                                                                                null,
                                                                                                                                                                                                                                                                                null,
                                                                                                                                                                                                                                                                                trunc(sysdate))*/ --added by daniel katz on 6-feb-10
       WHERE interface_line_attribute1 = to_char(p_order_numbers(idx))
         AND rila.amount >= 0
         AND EXISTS
       (SELECT 1
                FROM mtl_system_items_b msi
               WHERE msi.inventory_item_id = rila.inventory_item_id
                 AND msi.organization_id = rila.warehouse_id
                 AND msi.item_type =
                     fnd_profile.value('XXAR PREPAYMENT ITEM TYPES'));

  END handle_pos_prepayments_trx;

  --------------------------------------------------------------------
  -- 20/05/2012    Ofer Suad         Add Coupon accounting
  PROCEDURE handle_coupon_pos_trx(p_order_header_id NUMBER,
                                  p_order_number    NUMBER,
                                  p_organization    IN NUMBER,
                                  x_return_status   OUT VARCHAR2,
                                  x_err_msg         OUT VARCHAR2) IS

    --t_resin_pos_lines rila_order_headers_type;

  BEGIN

    --  Update resin credit line for positive amount
    INSERT INTO ra_interface_distributions_all
      (interface_distribution_id,
       interface_line_id,
       account_class,
       interface_line_context,
       amount,
       percent,
       segment1,
       segment2,
       segment3,
       segment4,
       segment5,
       segment6,
       segment7,
       segment8,
       segment9,
       segment10,
       interface_line_attribute1,
       interface_line_attribute2,
       interface_line_attribute3,
       interface_line_attribute4,
       interface_line_attribute5,
       interface_line_attribute6,
       interface_line_attribute7,
       interface_line_attribute8,
       interface_line_attribute9,
       interface_line_attribute10,
       interface_line_attribute11,
       interface_line_attribute12,
       interface_line_attribute13,
       interface_line_attribute14,
       interface_line_attribute15,
       creation_date,
       created_by,
       last_update_date,
       last_updated_by,
       org_id)
      SELECT ra_cust_trx_line_gl_dist_s.nextval,
             rila.interface_line_id,
             'REV',
             rila.interface_line_context,
             rila.amount,
             100,
             nvl(gcc_su.segment1, gcc_mas.segment1),
             gcc_mas.segment2,
             gcc_mas.segment3,
             -- Ofer Suad 03/12/2013  Support new chart of account
             nvl(gcc_mas.segment4, gcc_mas.segment5),
             decode(gcc_mas.segment4,
                    NULL,
                    nvl(gcc_su.segment6, '000'),
                    gcc_mas.segment5),
             decode(gcc_mas.segment4,
                    NULL,
                    gcc_mas.segment7,
                    nvl(gcc_su.segment6, '000')), --nvl added by daniel katz on 3-feb-11
             decode(gcc_mas.segment4,
                    NULL,
                    gcc_mas.segment10,
                    gcc_mas.segment7),
             decode(gcc_mas.segment8,
                    NULL,
                    gcc_mas.segment9,
                    gcc_mas.segment8),
             decode(gcc_mas.segment8, NULL, NULL, gcc_mas.segment9),
             decode(gcc_mas.segment8, NULL, NULL, gcc_mas.segment10),
             /*gcc_mas.segment4,
             gcc_mas.segment5,
             nvl(gcc_su.segment6, '000'), --nvl added by daniel katz on 3-feb-11
             gcc_mas.segment7,
             gcc_mas.segment8,
             gcc_mas.segment9,
             gcc_mas.segment10,*/
             -- End   Support new chart of account
             rila.interface_line_attribute1,
             rila.interface_line_attribute2,
             rila.interface_line_attribute3,
             rila.interface_line_attribute4,
             rila.interface_line_attribute5,
             rila.interface_line_attribute6,
             rila.interface_line_attribute7,
             rila.interface_line_attribute8,
             rila.interface_line_attribute9,
             rila.interface_line_attribute10,
             rila.interface_line_attribute11,
             rila.interface_line_attribute12,
             rila.interface_line_attribute13,
             rila.interface_line_attribute14,
             rila.interface_line_attribute15,
             SYSDATE,
             fnd_global.user_id,
             SYSDATE,
             fnd_global.login_id,
             p_organization
        FROM ra_interface_lines_all rila,
             mtl_system_items_b     msi_mas,
             hz_cust_site_uses_all  hcsu,
             gl_code_combinations   gcc_su,
             gl_code_combinations   gcc_mas,
             oe_order_lines_all     ol
       WHERE rila.inventory_item_id = msi_mas.inventory_item_id
         AND msi_mas.organization_id = ol.ship_from_org_id --Ofer Suad 03/12/2013  Support new chart of account
            --   xxinv_utils_pkg.get_master_organization_id
         AND rila.orig_system_bill_address_id = hcsu.cust_acct_site_id
         AND hcsu.site_use_code = 'BILL_TO'
         AND hcsu.gl_id_rev = gcc_su.code_combination_id(+)
         AND msi_mas.sales_account = gcc_mas.code_combination_id
         AND rila.interface_line_attribute1 = to_char(p_order_number)
         AND rila.interface_line_attribute6 = to_char(ol.line_id)
         AND ol.header_id = p_order_header_id
         AND rila.amount > 0
         AND msi_mas.item_type = fnd_profile.value('XXAR_COUPON_ITEM_TYPE');
    -----------------------------------------------------------------------

    INSERT INTO ra_interface_distributions_all
      (interface_distribution_id,
       interface_line_id,
       account_class,
       interface_line_context,
       amount,
       percent,
       segment1,
       segment2,
       segment3,
       segment4,
       segment5,
       segment6,
       segment7,
       segment8,
       segment9,
       segment10,
       interface_line_attribute1,
       interface_line_attribute2,
       interface_line_attribute3,
       interface_line_attribute4,
       interface_line_attribute5,
       interface_line_attribute6,
       interface_line_attribute7,
       interface_line_attribute8,
       interface_line_attribute9,
       interface_line_attribute10,
       interface_line_attribute11,
       interface_line_attribute12,
       interface_line_attribute13,
       interface_line_attribute14,
       interface_line_attribute15,
       creation_date,
       created_by,
       last_update_date,
       last_updated_by,
       org_id)
      SELECT ra_cust_trx_line_gl_dist_s.nextval,
             rila.interface_line_id,
             'REV',
             rila.interface_line_context,
             -1 * rila.amount, -- -1 * rila.attribute4,????????????????????????????
             100, --  100 * (-1 * rila.attribute4 / rila.amount),????????????????????????????
             nvl(gcc_su.segment1, gcc_mas.segment1),
             gcc_mas.segment2,
             gcc_mas.segment3,
             -- Ofer Suad 03/12/2013  Support new chart of account
             nvl(gcc_mas.segment4, gcc_mas.segment5),
             decode(gcc_mas.segment4,
                    NULL,
                    nvl(gcc_su.segment6, '000'),
                    gcc_mas.segment5),
             decode(gcc_mas.segment4,
                    NULL,
                    gcc_mas.segment7,
                    nvl(gcc_su.segment6, '000')), --nvl added by daniel katz on 3-feb-11
             decode(gcc_mas.segment4,
                    NULL,
                    gcc_mas.segment10,
                    gcc_mas.segment7),
             decode(gcc_mas.segment8,
                    NULL,
                    gcc_mas.segment9,
                    gcc_mas.segment8),
             decode(gcc_mas.segment8, NULL, NULL, gcc_mas.segment9),
             decode(gcc_mas.segment8, NULL, NULL, gcc_mas.segment10),
             /*gcc_mas.segment4,
             gcc_mas.segment5,
             nvl(gcc_su.segment6, '000'),
             gcc_mas.segment7,
             gcc_mas.segment8,
             gcc_mas.segment9,
             gcc_mas.segment10,*/
             -- End   Support new chart of account
             rila.interface_line_attribute1,
             rila.interface_line_attribute2,
             rila.interface_line_attribute3,
             rila.interface_line_attribute4,
             rila.interface_line_attribute5,
             rila.interface_line_attribute6,
             rila.interface_line_attribute7,
             rila.interface_line_attribute8,
             rila.interface_line_attribute9,
             rila.interface_line_attribute10,
             rila.interface_line_attribute11,
             rila.interface_line_attribute12,
             rila.interface_line_attribute13,
             rila.interface_line_attribute14,
             rila.interface_line_attribute15,
             SYSDATE,
             fnd_global.user_id,
             SYSDATE,
             fnd_global.login_id,
             p_organization
        FROM ra_interface_lines_all rila,
             mtl_system_items_b     msi_mas,
             hz_cust_site_uses_all  hcsu,
             gl_code_combinations   gcc_su,
             gl_code_combinations   gcc_mas,
             oe_order_lines_all     ol
       WHERE rila.inventory_item_id = msi_mas.inventory_item_id
         AND msi_mas.organization_id = ol.ship_from_org_id --Ofer Suad 03/12/2013  Support new chart of account
            --   xxinv_utils_pkg.get_master_organization_id
         AND rila.orig_system_bill_address_id = hcsu.cust_acct_site_id
         AND hcsu.site_use_code = 'BILL_TO'
         AND hcsu.gl_id_rev = gcc_su.code_combination_id(+)
         AND msi_mas.sales_account = gcc_mas.code_combination_id
         AND rila.interface_line_attribute1 = to_char(p_order_number)
         AND rila.interface_line_attribute6 = to_char(ol.line_id)
         AND ol.header_id = p_order_header_id
         AND rila.amount > 0
         AND msi_mas.item_type = fnd_profile.value('XXAR_COUPON_ITEM_TYPE');
    -----------------------------------------------------------------------

    INSERT INTO ra_interface_distributions_all
      (interface_distribution_id,
       interface_line_id,
       account_class,
       interface_line_context,
       amount,
       percent,
       segment1,
       segment2,
       segment3,
       segment4,
       segment5,
       segment6,
       segment7,
       segment8,
       segment9,
       segment10,
       interface_line_attribute1,
       interface_line_attribute2,
       interface_line_attribute3,
       interface_line_attribute4,
       interface_line_attribute5,
       interface_line_attribute6,
       interface_line_attribute7,
       interface_line_attribute8,
       interface_line_attribute9,
       interface_line_attribute10,
       interface_line_attribute11,
       interface_line_attribute12,
       interface_line_attribute13,
       interface_line_attribute14,
       interface_line_attribute15,
       creation_date,
       created_by,
       last_update_date,
       last_updated_by,
       org_id)
      (SELECT ra_cust_trx_line_gl_dist_s.nextval,
              rila.interface_line_id,
              'REV',
              rila.interface_line_context,
              rila.quantity * rila.unit_selling_price, --1 * rila.attribute4,????????????????????????????
              100 * (rila.quantity * rila.unit_selling_price /
              safe_devisor(rila.amount)), --100 * (rila.attribute4 / rila.amount),????????????????????????????
              nvl(gcc_su.segment1, gcc_mas.segment1),
              gcc_mas.segment2,
              gcc_mas.segment3,
              -- Ofer Suad 03/12/2013  Support new chart of account
              nvl(gcc_mas.segment4, gcc_mas.segment5),
              decode(gcc_mas.segment4,
                     NULL,
                     nvl(gcc_su.segment6, '000'),
                     gcc_mas.segment5),
              decode(gcc_mas.segment4,
                     NULL,
                     gcc_mas.segment7,
                     nvl(gcc_su.segment6, '000')), --nvl added by daniel katz on 3-feb-11
              decode(gcc_mas.segment4,
                     NULL,
                     gcc_mas.segment10,
                     gcc_mas.segment7),
              decode(gcc_mas.segment8,
                     NULL,
                     gcc_mas.segment9,
                     gcc_mas.segment8),
              decode(gcc_mas.segment8, NULL, NULL, gcc_mas.segment9),
              decode(gcc_mas.segment8, NULL, NULL, gcc_mas.segment10),
              /*gcc_mas.segment4,
              gcc_mas.segment5,
              nvl(gcc_su.segment6, '000'),
              gcc_mas.segment7,
              gcc_mas.segment8,
              gcc_mas.segment9,
              gcc_mas.segment10,*/
              -- End   Support new chart of account
              rila.interface_line_attribute1,
              rila.interface_line_attribute2,
              rila.interface_line_attribute3,
              rila.interface_line_attribute4,
              rila.interface_line_attribute5,
              rila.interface_line_attribute6,
              rila.interface_line_attribute7,
              rila.interface_line_attribute8,
              rila.interface_line_attribute9,
              rila.interface_line_attribute10,
              rila.interface_line_attribute11,
              rila.interface_line_attribute12,
              rila.interface_line_attribute13,
              rila.interface_line_attribute14,
              rila.interface_line_attribute15,
              SYSDATE,
              fnd_global.user_id,
              SYSDATE,
              fnd_global.login_id,
              p_organization
         FROM ra_interface_lines_all rila,
              mtl_system_items_b     msi_mas,
              hz_cust_site_uses_all  hcsu,
              gl_code_combinations   gcc_su,
              gl_code_combinations   gcc_mas,
              oe_order_lines_all     ol
        WHERE rila.inventory_item_id = msi_mas.inventory_item_id
          AND msi_mas.organization_id = ol.ship_from_org_id --Ofer Suad 03/12/2013  Support new chart of account
             --   xxinv_utils_pkg.get_master_organization_id
          AND rila.orig_system_bill_address_id = hcsu.cust_acct_site_id
          AND hcsu.site_use_code = 'BILL_TO'
          AND hcsu.gl_id_rev = gcc_su.code_combination_id(+)
          AND msi_mas.cost_of_sales_account = gcc_mas.code_combination_id
          AND rila.interface_line_attribute1 = to_char(p_order_number)
          AND rila.interface_line_attribute6 = to_char(ol.line_id)
          AND --added by daniel katz
              ol.header_id = p_order_header_id
          AND rila.amount > 0
          AND msi_mas.item_type =
              fnd_profile.value('XXAR_COUPON_ITEM_TYPE'));

    UPDATE ra_interface_lines_all rila
       SET unit_standard_price = rila.unit_selling_price,
           description        =
           (SELECT description || ': ' || rila.amount || ' ' ||
                   rila.currency_code
              FROM mtl_system_items_b msi
             WHERE msi.inventory_item_id = rila.inventory_item_id
               AND msi.organization_id =
                   xxinv_utils_pkg.get_master_organization_id)
     WHERE rila.interface_line_attribute1 = to_char(p_order_number)
       AND rila.amount >= 0
       AND EXISTS
     (SELECT 1
              FROM mtl_system_items_b msi
             WHERE msi.inventory_item_id = rila.inventory_item_id
               AND msi.organization_id =
                   xxinv_utils_pkg.get_master_organization_id
               AND msi.item_type =
                   fnd_profile.value('XXAR_COUPON_ITEM_TYPE'))
       AND EXISTS
     (SELECT 1
              FROM oe_order_lines_all ol
             WHERE rila.interface_line_attribute6 = to_char(ol.line_id)
               AND ol.header_id = p_order_header_id);

  EXCEPTION
    WHEN OTHERS THEN

      fnd_file.put_line(fnd_file.log,
                        'HANDLE_CREDIT_CUPON_POS_TRX: ' || SQLERRM);
      x_err_msg       := NULL;
      x_return_status := fnd_api.g_ret_sts_error;

  END handle_coupon_pos_trx;
  -----------------------------------
  --20/05/2012    Ofer Suad         Add Coupon accounting
  --20/06/2014    Mike Mazanet      CHG0032527. Added p_batch_source parameter
  PROCEDURE handle_coupon_neg_trx(p_organization      NUMBER,
                                  p_order_header_id   rila_order_headers_type,
                                  p_batch_source_name VARCHAR2,
                                  x_return_status     OUT VARCHAR2,
                                  x_err_msg           OUT VARCHAR2) IS
    l_adj_amt      NUMBER;
    l_cup_line_id  NUMBER;
    l_avg_discount NUMBER;
    l_curr_code    ra_interface_lines_all.currency_code%TYPE;
    l_inv_item_id  NUMBER;

    CURSOR cur_neg_cup_line_c(l_order_header_id NUMBER) IS
      SELECT qc.coupon_number,
             oal.inventory_item_id,
             ril.rowid,
             ril.interface_line_attribute6,
             oal.ship_from_org_id
        FROM oe_order_price_attribs opa,
             qp_coupons             qc,
             oe_order_lines_all     oal,
             ra_interface_lines_all ril,
             mtl_system_items_b     mb
       WHERE opa.line_id = oal.line_id
         AND qc.coupon_id = opa.pricing_attribute3
         AND oal.header_id = l_order_header_id
         AND ril.interface_line_attribute6 = to_char(oal.line_id)
         AND mb.inventory_item_id = oal.inventory_item_id
         AND mb.organization_id =
             xxinv_utils_pkg.get_master_organization_id
         AND mb.item_type = fnd_profile.value('XXAR_COUPON_ITEM_TYPE');

  BEGIN
    FOR idx IN 1 .. p_order_header_id.count LOOP
      BEGIN
        --  25/08/2014          Ofer Suad       CR #CHG0032772
        FOR cur_neg_cup_line IN cur_neg_cup_line_c(p_order_header_id(idx)) LOOP

          SELECT 1 / COUNT(*) * oel.unit_selling_price *
                 oel.ordered_quantity,
                 oel.line_id
            INTO l_adj_amt, l_cup_line_id
            FROM oe_price_adjustments_v opa, oe_order_lines_all oel
           WHERE opa.line_id = oel.line_id
             AND opa.adjustment_type_code = 'CIE'
             AND opa.line_id =
                 (SELECT line_id
                    FROM oe_price_adjustments_v opa1
                   WHERE opa1.list_line_no = cur_neg_cup_line.coupon_number)
           GROUP BY oel.unit_selling_price,
                    oel.ordered_quantity,
                    oel.line_id;
          fnd_file.put_line(fnd_file.log,
                            'in neg coupon l_adj_amt ' || l_adj_amt);

          SELECT ril.inventory_item_id, ril.currency_code
            INTO l_inv_item_id, l_curr_code
            FROM ra_interface_lines_all ril
           WHERE ril.interface_line_attribute6 =
                 (SELECT to_char(opres.line_id)
                    FROM oe_price_adjustments_v opcup,
                         oe_price_adj_assocs_v  opaa,
                         oe_price_adjustments_v opres
                   WHERE opcup.line_id =
                         cur_neg_cup_line.interface_line_attribute6
                        --CHG0032527. This was previously returning multiple rows
                        --because the same value for interface_line_attribute6 was
                        --shared across multiple contexts.
                     AND ril.interface_line_context = p_batch_source_name
                     AND opaa.price_adjustment_id =
                         opcup.price_adjustment_id
                     AND opres.price_adjustment_id = opaa.rltd_price_adj_id);

          SELECT nvl(rctl.attribute10, 0) / 100
            INTO l_avg_discount
            FROM ra_customer_trx_lines_all rctl
           WHERE rctl.interface_line_attribute6 = to_char(l_cup_line_id);

          INSERT INTO ra_interface_distributions_all
            (interface_distribution_id,
             interface_line_id,
             account_class,
             interface_line_context,
             amount,
             percent,
             segment1,
             segment2,
             segment3,
             segment4,
             segment5,
             segment6,
             segment7,
             segment8,
             segment9,
             segment10,
             interface_line_attribute1,
             interface_line_attribute2,
             interface_line_attribute3,
             interface_line_attribute4,
             interface_line_attribute5,
             interface_line_attribute6,
             interface_line_attribute7,
             interface_line_attribute8,
             interface_line_attribute9,
             interface_line_attribute10,
             interface_line_attribute11,
             interface_line_attribute12,
             interface_line_attribute13,
             interface_line_attribute14,
             interface_line_attribute15,
             creation_date,
             created_by,
             last_update_date,
             last_updated_by,
             org_id)
            SELECT ra_cust_trx_line_gl_dist_s.nextval,
                   rila.interface_line_id,
                   'REV',
                   rila.interface_line_context,
                   l_adj_amt,
                   100,
                   nvl(gcc_su.segment1, gcc_mas.segment1),
                   gcc_mas.segment2,
                   gcc_mas.segment3,
                   -- Ofer Suad 03/12/2013  Support new chart of account
                   nvl(gcc_mas.segment4, gcc_mas.segment5),
                   decode(gcc_mas.segment4,
                          NULL,
                          nvl(gcc_su.segment6, '000'),
                          gcc_mas.segment5),
                   decode(gcc_mas.segment4,
                          NULL,
                          gcc_mas.segment7,
                          nvl(gcc_su.segment6, '000')), --nvl added by daniel katz on 3-feb-11
                   decode(gcc_mas.segment4,
                          NULL,
                          gcc_mas.segment10,
                          gcc_mas.segment7),
                   decode(gcc_mas.segment8,
                          NULL,
                          gcc_mas.segment9,
                          gcc_mas.segment8),
                   decode(gcc_mas.segment8, NULL, NULL, gcc_mas.segment9),
                   decode(gcc_mas.segment8, NULL, NULL, gcc_mas.segment10),
                   /* gcc_mas.segment4,
                   gcc_mas.segment5,
                   nvl(gcc_su.segment6, '000'),
                   gcc_mas.segment7,
                   gcc_mas.segment8,
                   gcc_mas.segment9,
                   gcc_mas.segment10,*/
                   -- End   Support new chart of account
                   rila.interface_line_attribute1,
                   rila.interface_line_attribute2,
                   rila.interface_line_attribute3,
                   rila.interface_line_attribute4,
                   rila.interface_line_attribute5,
                   rila.interface_line_attribute6,
                   rila.interface_line_attribute7,
                   rila.interface_line_attribute8,
                   rila.interface_line_attribute9,
                   rila.interface_line_attribute10,
                   rila.interface_line_attribute11,
                   rila.interface_line_attribute12,
                   rila.interface_line_attribute13,
                   rila.interface_line_attribute14,
                   rila.interface_line_attribute15,
                   SYSDATE,
                   fnd_global.user_id,
                   SYSDATE,
                   fnd_global.login_id,
                   p_organization
              FROM ra_interface_lines_all rila,
                   mtl_system_items_b     msi_mas,
                   gl_code_combinations   gcc_mas,
                   hz_cust_site_uses_all  hcsu,
                   gl_code_combinations   gcc_su
             WHERE rila.inventory_item_id = msi_mas.inventory_item_id
               AND msi_mas.organization_id =
                   cur_neg_cup_line.ship_from_org_id --Ofer Suad 03/12/2013  Support new chart of account
                  --    xxinv_utils_pkg.get_master_organization_id
               AND rila.orig_system_bill_address_id =
                   hcsu.cust_acct_site_id
               AND hcsu.site_use_code = 'BILL_TO'
               AND hcsu.gl_id_rev = gcc_su.code_combination_id(+)
               AND msi_mas.cost_of_sales_account =
                   gcc_mas.code_combination_id
               AND rila.rowid = cur_neg_cup_line.rowid;

          INSERT INTO ra_interface_distributions_all
            (interface_distribution_id,
             interface_line_id,
             account_class,
             interface_line_context,
             amount,
             percent,
             segment1,
             segment2,
             segment3,
             segment4,
             segment5,
             segment6,
             segment7,
             segment8,
             segment9,
             segment10,
             interface_line_attribute1,
             interface_line_attribute2,
             interface_line_attribute3,
             interface_line_attribute4,
             interface_line_attribute5,
             interface_line_attribute6,
             interface_line_attribute7,
             interface_line_attribute8,
             interface_line_attribute9,
             interface_line_attribute10,
             interface_line_attribute11,
             interface_line_attribute12,
             interface_line_attribute13,
             interface_line_attribute14,
             interface_line_attribute15,
             creation_date,
             created_by,
             last_update_date,
             last_updated_by,
             org_id)
            SELECT ra_cust_trx_line_gl_dist_s.nextval,
                   rila.interface_line_id,
                   'REV',
                   rila.interface_line_context,
                   round(l_adj_amt * l_avg_discount,
                         get_precision(l_curr_code)),
                   100 * l_avg_discount,
                   nvl(gcc_su.segment1, gcc_mas.segment1),
                   gcc_mas.segment2,
                   gcc_mas.segment3,
                   -- Ofer Suad 03/12/2013  Support new chart of account
                   nvl(gcc_mas.segment4, gcc_mas.segment5),
                   decode(gcc_mas.segment4,
                          NULL,
                          nvl(gcc_su.segment6, '000'),
                          gcc_mas.segment5),
                   decode(gcc_mas.segment4,
                          NULL,
                          gcc_mas.segment7,
                          nvl(gcc_su.segment6, '000')), --nvl added by daniel katz on 3-feb-11
                   decode(gcc_mas.segment4,
                          NULL,
                          gcc_mas.segment10,
                          gcc_mas.segment7),
                   decode(gcc_mas.segment8,
                          NULL,
                          gcc_mas.segment9,
                          gcc_mas.segment8),
                   decode(gcc_mas.segment8, NULL, NULL, gcc_mas.segment9),
                   decode(gcc_mas.segment8, NULL, NULL, gcc_mas.segment10),

                   /*gcc_mas.segment4,
                   gcc_mas.segment5,
                   nvl(gcc_su.segment6, '000'),
                   gcc_mas.segment7,
                   gcc_mas.segment8,
                   gcc_mas.segment9,
                   gcc_mas.segment10,*/
                   -- End   Support new chart of account
                   rila.interface_line_attribute1,
                   rila.interface_line_attribute2,
                   rila.interface_line_attribute3,
                   rila.interface_line_attribute4,
                   rila.interface_line_attribute5,
                   rila.interface_line_attribute6,
                   rila.interface_line_attribute7,
                   rila.interface_line_attribute8,
                   rila.interface_line_attribute9,
                   rila.interface_line_attribute10,
                   rila.interface_line_attribute11,
                   rila.interface_line_attribute12,
                   rila.interface_line_attribute13,
                   rila.interface_line_attribute14,
                   rila.interface_line_attribute15,
                   SYSDATE,
                   fnd_global.user_id,
                   SYSDATE,
                   fnd_global.login_id,
                   p_organization
              FROM ra_interface_lines_all rila,
                   mtl_system_items_b     msi_mas,
                   gl_code_combinations   gcc_mas,
                   hz_cust_site_uses_all  hcsu,
                   gl_code_combinations   gcc_su
             WHERE msi_mas.inventory_item_id = l_inv_item_id
                  --cur_neg_cup_line.inventory_item_id
               AND msi_mas.organization_id =
                   cur_neg_cup_line.ship_from_org_id --Ofer Suad 03/12/2013  Support new chart of account
                  --  xxinv_utils_pkg.get_master_organization_id
               AND msi_mas.sales_account = gcc_mas.code_combination_id
               AND rila.orig_system_bill_address_id =
                   hcsu.cust_acct_site_id
               AND hcsu.site_use_code = 'BILL_TO'
               AND hcsu.gl_id_rev = gcc_su.code_combination_id(+)
               AND rila.rowid = cur_neg_cup_line.rowid;

          INSERT INTO ra_interface_distributions_all
            (interface_distribution_id,
             interface_line_id,
             account_class,
             interface_line_context,
             amount,
             percent,
             segment1,
             segment2,
             segment3,
             segment4,
             segment5,
             segment6,
             segment7,
             segment8,
             segment9,
             segment10,
             interface_line_attribute1,
             interface_line_attribute2,
             interface_line_attribute3,
             interface_line_attribute4,
             interface_line_attribute5,
             interface_line_attribute6,
             interface_line_attribute7,
             interface_line_attribute8,
             interface_line_attribute9,
             interface_line_attribute10,
             interface_line_attribute11,
             interface_line_attribute12,
             interface_line_attribute13,
             interface_line_attribute14,
             interface_line_attribute15,
             creation_date,
             created_by,
             last_update_date,
             last_updated_by,
             org_id)
            SELECT ra_cust_trx_line_gl_dist_s.nextval,
                   rila.interface_line_id,
                   'REV',
                   rila.interface_line_context,
                   round(-1 * l_adj_amt * l_avg_discount,
                         get_precision(l_curr_code)),
                   -100 * l_avg_discount,
                   nvl(gcc_su.segment1, gcc_mas.segment1),
                   gcc_mas.segment2,
                   gcc_mas.segment3,
                   nvl(gcc_mas.segment4, gcc_mas.segment5),
                   decode(gcc_mas.segment4,
                          NULL,
                          nvl(gcc_su.segment6, '000'),
                          gcc_mas.segment5),
                   decode(gcc_mas.segment4,
                          NULL,
                          gcc_mas.segment7,
                          nvl(gcc_su.segment6, '000')), --nvl added by daniel katz on 3-feb-11
                   decode(gcc_mas.segment4,
                          NULL,
                          gcc_mas.segment10,
                          gcc_mas.segment7),
                   decode(gcc_mas.segment8,
                          NULL,
                          gcc_mas.segment9,
                          gcc_mas.segment8),
                   decode(gcc_mas.segment8, NULL, NULL, gcc_mas.segment9),
                   decode(gcc_mas.segment8, NULL, NULL, gcc_mas.segment10),
                   -- Ofer Suad 03/12/2013  Support new chart of account
                   /*gcc_mas.segment4,
                   gcc_mas.segment5,
                   nvl(gcc_su.segment6, '000'),
                   gcc_mas.segment7,
                   gcc_mas.segment8,
                   gcc_mas.segment9,
                   gcc_mas.segment10,*/
                   -- End   Support new chart of account
                   rila.interface_line_attribute1,
                   rila.interface_line_attribute2,
                   rila.interface_line_attribute3,
                   rila.interface_line_attribute4,
                   rila.interface_line_attribute5,
                   rila.interface_line_attribute6,
                   rila.interface_line_attribute7,
                   rila.interface_line_attribute8,
                   rila.interface_line_attribute9,
                   rila.interface_line_attribute10,
                   rila.interface_line_attribute11,
                   rila.interface_line_attribute12,
                   rila.interface_line_attribute13,
                   rila.interface_line_attribute14,
                   rila.interface_line_attribute15,
                   SYSDATE,
                   fnd_global.user_id,
                   SYSDATE,
                   fnd_global.login_id,
                   p_organization
              FROM ra_interface_lines_all rila,
                   mtl_system_items_b     msi_mas,
                   hz_cust_site_uses_all  hcsu,
                   gl_code_combinations   gcc_su,
                   gl_code_combinations   gcc_mas
             WHERE rila.inventory_item_id = msi_mas.inventory_item_id
               AND msi_mas.organization_id =
                   cur_neg_cup_line.ship_from_org_id --Ofer Suad 03/12/2013  Support new chart of account
                  --    xxinv_utils_pkg.get_master_organization_id
               AND rila.orig_system_bill_address_id =
                   hcsu.cust_acct_site_id
               AND hcsu.site_use_code = 'BILL_TO'
               AND hcsu.gl_id_rev = gcc_su.code_combination_id(+)
               AND msi_mas.sales_account = gcc_mas.code_combination_id
               AND rila.rowid = cur_neg_cup_line.rowid;

          UPDATE ra_interface_lines_all rla
             SET rla.amount = l_adj_amt
           WHERE rla.interface_line_attribute6 =
                 (SELECT to_char(opres.line_id)
                    FROM oe_price_adjustments_v opcup,
                         oe_price_adj_assocs_v  opaa,
                         oe_price_adjustments_v opres
                   WHERE opcup.line_id =
                         cur_neg_cup_line.interface_line_attribute6
                     AND opaa.price_adjustment_id =
                         opcup.price_adjustment_id
                     AND opres.price_adjustment_id = opaa.rltd_price_adj_id);

          UPDATE ra_interface_lines_all rla
             SET rla.amount = -l_adj_amt
           WHERE rla.interface_line_attribute6 =
                 cur_neg_cup_line.interface_line_attribute6;

        END LOOP;
      EXCEPTION
        --  25/08/2014          Ofer Suad       CR #CHG0032772
        WHEN OTHERS THEN
          fnd_file.put_line(fnd_file.log,
                            'HANDLE_CREDIT_CUPON_NEGTRX: ' || SQLERRM);
          x_err_msg       := 'HANDLE_CREDIT_CUPON_NEGTRX: ' || SQLERRM;
          x_return_status := fnd_api.g_ret_sts_error;
          UPDATE ra_interface_lines_all ril
             SET ril.request_id = -99
           WHERE interface_line_attribute6 IN
                 (SELECT ol.line_id
                    FROM oe_order_lines_all ol
                   WHERE ol.header_id = p_order_header_id(idx))

             AND ril.org_id = p_organization;
      END;
    END LOOP;
  EXCEPTION
    WHEN OTHERS THEN

      fnd_file.put_line(fnd_file.log,
                        'HANDLE_CREDIT_CUPON_NEGTRX: ' || SQLERRM);
      x_err_msg       := NULL;
      x_return_status := fnd_api.g_ret_sts_error;
  END handle_coupon_neg_trx;
  -------------------------------------------
  PROCEDURE handle_neg_prepayments_trx(p_order_numbers IN rila_order_numbers_type,
                                       p_organization  IN NUMBER,
                                       x_return_status OUT VARCHAR2,
                                       x_err_msg       OUT VARCHAR2,
                                       --added parameter by daniel katz on 19-sep-10
                                       p_neg_prep_as_credit IN VARCHAR2) IS

    lv_memo_segment1      gl_code_combinations.segment1%TYPE;
    lv_memo_segment2      gl_code_combinations.segment2%TYPE;
    lv_memo_segment3      gl_code_combinations.segment3%TYPE;
    lv_memo_segment4      gl_code_combinations.segment4%TYPE;
    lv_memo_segment5      gl_code_combinations.segment5%TYPE;
    lv_memo_segment6      gl_code_combinations.segment6%TYPE;
    lv_memo_segment7      gl_code_combinations.segment7%TYPE;
    lv_memo_segment8      gl_code_combinations.segment8%TYPE;
    lv_memo_segment9      gl_code_combinations.segment9%TYPE;
    lv_memo_segment10     gl_code_combinations.segment10%TYPE;
    l_credit_memo_type_id NUMBER;

  BEGIN

    x_return_status := fnd_api.g_ret_sts_success;

    BEGIN
      SELECT gcc.segment1,
             gcc.segment2,
             gcc.segment3,
             gcc.segment4,
             gcc.segment5,
             gcc.segment6,
             gcc.segment7,
             gcc.segment8,
             gcc.segment9,
             gcc.segment10
        INTO lv_memo_segment1,
             lv_memo_segment2,
             lv_memo_segment3,
             lv_memo_segment4,
             lv_memo_segment5,
             lv_memo_segment6,
             lv_memo_segment7,
             lv_memo_segment8,
             lv_memo_segment9,
             lv_memo_segment10
        FROM ar_memo_lines_all_b aml, gl_code_combinations gcc
       WHERE aml.memo_line_id =
             fnd_profile.value_specific('XXAR_PREPAYMENT_MEMO_LINE',
                                        NULL,
                                        NULL,
                                        NULL,
                                        p_organization)
         AND aml.gl_id_rev = gcc.code_combination_id;

    EXCEPTION
      WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.output, 'Invalid Memo line.');
        fnd_file.put_line(fnd_file.log, 'Invalid Memo line.');
        x_err_msg       := 'Invalid Memo line.';
        x_return_status := fnd_api.g_ret_sts_error;
        RETURN;
    END;

    --  Update prepayments memo line for negative amount
    FORALL idx IN 1 .. p_order_numbers.count
      INSERT INTO ra_interface_distributions_all
        (interface_distribution_id,
         interface_line_id,
         account_class,
         interface_line_context,
         amount,
         percent,
         segment1,
         segment2,
         segment3,
         segment4,
         segment5,
         segment6,
         segment7,
         segment8,
         segment9,
         segment10,
         interface_line_attribute1,
         interface_line_attribute2,
         interface_line_attribute3,
         interface_line_attribute4,
         interface_line_attribute5,
         interface_line_attribute6,
         interface_line_attribute7,
         interface_line_attribute8,
         interface_line_attribute9,
         interface_line_attribute10,
         interface_line_attribute11,
         interface_line_attribute12,
         interface_line_attribute13,
         interface_line_attribute14,
         interface_line_attribute15,
         creation_date,
         created_by,
         last_update_date,
         last_updated_by,
         org_id)
        SELECT ra_cust_trx_line_gl_dist_s.nextval,
               rila.interface_line_id,
               'REV',
               rila.interface_line_context,
               rila.amount,
               '100',
               lv_memo_segment1,
               lv_memo_segment2,
               lv_memo_segment3,
               nvl(lv_memo_segment4, lv_memo_segment5),
               decode(lv_memo_segment4,
                      NULL,
                      nvl(gcc_su.segment6, '000'),
                      lv_memo_segment5),
               decode(lv_memo_segment4,
                      NULL,
                      lv_memo_segment7,
                      nvl(gcc_su.segment6, '000')),
               decode(lv_memo_segment4,
                      NULL,
                      lv_memo_segment10,
                      lv_memo_segment7),
               decode(lv_memo_segment8,
                      NULL,
                      lv_memo_segment9,
                      lv_memo_segment8),
               decode(lv_memo_segment8, NULL, NULL, lv_memo_segment9),
               decode(lv_memo_segment8, NULL, NULL, lv_memo_segment10),
               rila.interface_line_attribute1,
               rila.interface_line_attribute2,
               rila.interface_line_attribute3,
               rila.interface_line_attribute4,
               rila.interface_line_attribute5,
               rila.interface_line_attribute6,
               rila.interface_line_attribute7,
               rila.interface_line_attribute8,
               rila.interface_line_attribute9,
               rila.interface_line_attribute10,
               rila.interface_line_attribute11,
               rila.interface_line_attribute12,
               rila.interface_line_attribute13,
               rila.interface_line_attribute14,
               rila.interface_line_attribute15,
               SYSDATE,
               fnd_global.user_id,
               SYSDATE,
               fnd_global.login_id,
               p_organization
          FROM ra_interface_lines_all rila,
               hz_cust_site_uses_all  hcsu,
               gl_code_combinations   gcc_su
         WHERE rila.orig_system_bill_address_id = hcsu.cust_acct_site_id
           AND hcsu.site_use_code = 'BILL_TO'
           AND hcsu.gl_id_rev = gcc_su.code_combination_id(+) --outer join added by daniel katz on 3-feb-11
           AND rila.interface_line_attribute1 =
               to_char(p_order_numbers(idx))
           AND rila.amount < 0
           AND EXISTS
         (SELECT 1
                  FROM mtl_system_items_b msi
                 WHERE msi.inventory_item_id = rila.inventory_item_id
                   AND msi.organization_id = rila.warehouse_id
                   AND msi.item_type =
                       fnd_profile.value('XXAR PREPAYMENT ITEM TYPES'))
              --added by daniel katz on 19-sep-10
           AND rila.interface_line_attribute6 !=
               nvl(p_neg_prep_as_credit, 'xx');

    -------------------------------------------------
    --following block added by daniel katz on 19-sep-10 to deal with negative prepayment as credit

    SELECT rctt.credit_memo_type_id
      INTO l_credit_memo_type_id
      FROM ra_cust_trx_types_all rctt
     WHERE rctt.org_id = p_organization
       AND rctt.cust_trx_type_id =
           fnd_profile.value_specific('XXAR_PREPAYMENT_DEST_TRX_TYPE',
                                      NULL,
                                      NULL,
                                      NULL,
                                      p_organization);

    FORALL idx IN 1 .. p_order_numbers.count
      UPDATE ra_interface_lines_all rila
         SET rila.cust_trx_type_id   = l_credit_memo_type_id,
             rila.term_id            = NULL,
             rila.accounting_rule_id = NULL,
             rila.invoicing_rule_id  = NULL,
             rila.gl_date            = trunc(SYSDATE),
             rila.trx_date           = trunc(SYSDATE)

       WHERE rila.interface_line_attribute6 = p_neg_prep_as_credit
         AND rila.interface_line_attribute1 = to_char(p_order_numbers(idx))
         AND rila.amount < 0
         AND rila.interface_line_context = 'ORDER ENTRY';
    --no need adding additional conditions for the prepayment because in the value set
    --for the program there is a validation for that

    ---------------------------------------------------

  EXCEPTION
    WHEN OTHERS THEN

      fnd_file.put_line(fnd_file.log,
                        'HANDLE_NEG_PREPAYMENTS_TRX: ' || SQLERRM);
      x_err_msg       := NULL;
      x_return_status := fnd_api.g_ret_sts_error;

  END handle_neg_prepayments_trx;

  --------------------------------------------------------------------
  PROCEDURE handle_freight_items_trx(p_order_numbers IN rila_order_numbers_type,
                                     p_organization  IN NUMBER,
                                     x_return_status OUT VARCHAR2,
                                     x_err_msg       OUT VARCHAR2) IS

  BEGIN

    --  Update freight line
    FORALL idx IN 1 .. p_order_numbers.count
      INSERT INTO ra_interface_distributions_all
        (interface_distribution_id,
         interface_line_id,
         account_class,
         interface_line_context,
         amount,
         percent,
         segment1,
         segment2,
         segment3,
         segment4,
         segment5,
         segment6,
         segment7,
         segment8,
         segment9,
         segment10,
         interface_line_attribute1,
         interface_line_attribute2,
         interface_line_attribute3,
         interface_line_attribute4,
         interface_line_attribute5,
         interface_line_attribute6,
         interface_line_attribute7,
         interface_line_attribute8,
         interface_line_attribute9,
         interface_line_attribute10,
         interface_line_attribute11,
         interface_line_attribute12,
         interface_line_attribute13,
         interface_line_attribute14,
         interface_line_attribute15,
         creation_date,
         created_by,
         last_update_date,
         last_updated_by,
         org_id)
        SELECT ra_cust_trx_line_gl_dist_s.nextval,
               rila.interface_line_id,
               'REV',
               rila.interface_line_context,
               rila.amount,
               '100',
               gcc_org.segment1,
               gcc_mas.segment2,
               gcc_mas.segment3,
               gcc_mas.segment4,
               gcc_mas.segment5,
               gcc_mas.segment6,
               gcc_mas.segment7,
               gcc_mas.segment8,
               gcc_mas.segment9,
               gcc_mas.segment10,
               rila.interface_line_attribute1,
               rila.interface_line_attribute2,
               rila.interface_line_attribute3,
               rila.interface_line_attribute4,
               rila.interface_line_attribute5,
               rila.interface_line_attribute6,
               rila.interface_line_attribute7,
               rila.interface_line_attribute8,
               rila.interface_line_attribute9,
               rila.interface_line_attribute10,
               rila.interface_line_attribute11,
               rila.interface_line_attribute12,
               rila.interface_line_attribute13,
               rila.interface_line_attribute14,
               rila.interface_line_attribute15,
               SYSDATE,
               fnd_global.user_id,
               SYSDATE,
               fnd_global.login_id,
               p_organization
          FROM ra_interface_lines_all rila,
               mtl_system_items_b     msi_mas,
               mtl_system_items_b     msi_org,
               gl_code_combinations   gcc_mas,
               gl_code_combinations   gcc_org
         WHERE rila.inventory_item_id = msi_mas.inventory_item_id
           AND msi_mas.organization_id = rila.warehouse_id
              --    xxinv_utils_pkg.get_master_organization_id
           AND rila.inventory_item_id = msi_org.inventory_item_id
           AND rila.warehouse_id = msi_org.organization_id
           AND msi_mas.sales_account = gcc_mas.code_combination_id
           AND msi_org.sales_account = gcc_org.code_combination_id
           AND rila.interface_line_attribute1 =
               to_char(p_order_numbers(idx))
           AND rila.sales_order_line IS NOT NULL
           AND msi_mas.item_type =
               fnd_profile.value('XXAR_FREIGHT_AR_ITEM');

  EXCEPTION
    WHEN OTHERS THEN

      fnd_file.put_line(fnd_file.log,
                        'HANDLE_FREIGHT_ITEMS_TRX: ' || SQLERRM);
      x_err_msg       := NULL;
      x_return_status := fnd_api.g_ret_sts_error;

  END handle_freight_items_trx;
  -------------------------------------------

  PROCEDURE handle_credit_resin_pos_trx(p_order_header_id NUMBER, --added by daniel katz
                                        p_order_number    NUMBER,
                                        p_organization    IN NUMBER,
                                        x_return_status   OUT VARCHAR2,
                                        x_err_msg         OUT VARCHAR2) IS

    --t_resin_pos_lines rila_order_headers_type;
    l_suspense_account ra_account_default_segments.constant%TYPE; --CHG0037700-  fix 100% Resin credit accounting
  BEGIN

    --CHG0037700-  fix 100% Resin credit accounting
    BEGIN
      SELECT rads.constant
        INTO l_suspense_account
        FROM ra_account_defaults         rad,
             ra_account_default_segments rads,
             fnd_id_flex_segments        fif,
             hr_operating_units          hu,
             gl_ledgers                  gl
       WHERE rad.type = 'SUSPENSE'
         AND rads.gl_default_id = rad.gl_default_id
         AND fif.application_id = 101
         AND fif.id_flex_code = 'GL#'
         AND upper(fif.segment_name) = 'ACCOUNT'
         AND fif.application_column_name = rads.segment
         AND hu.organization_id = rad.org_id
         AND gl.ledger_id = hu.set_of_books_id
         AND gl.chart_of_accounts_id = fif.id_flex_num;
    EXCEPTION
      WHEN OTHERS THEN
        l_suspense_account := NULL;
    END;

    --  Update resin credit line for positive amount
    INSERT INTO ra_interface_distributions_all
      (interface_distribution_id,
       interface_line_id,
       account_class,
       interface_line_context,
       amount,
       percent,
       segment1,
       segment2,
       segment3,
       segment4,
       segment5,
       segment6,
       segment7,
       segment8,
       segment9,
       segment10,
       interface_line_attribute1,
       interface_line_attribute2,
       interface_line_attribute3,
       interface_line_attribute4,
       interface_line_attribute5,
       interface_line_attribute6,
       interface_line_attribute7,
       interface_line_attribute8,
       interface_line_attribute9,
       interface_line_attribute10,
       interface_line_attribute11,
       interface_line_attribute12,
       interface_line_attribute13,
       interface_line_attribute14,
       interface_line_attribute15,
       creation_date,
       created_by,
       last_update_date,
       last_updated_by,
       org_id)
      SELECT ra_cust_trx_line_gl_dist_s.nextval,
             rila.interface_line_id,
             'REV',
             rila.interface_line_context,
             decode(rila.attribute10, 100, rila.attribute4, rila.amount), --CHG0037700-  fix 100% Resin credit accounting
             '100',
             nvl(gcc_su.segment1, gcc_mas.segment1),
             gcc_mas.segment2,
             decode(rila.attribute10,
                    100,
                    nvl(l_suspense_account, gcc_mas.segment3),
                    gcc_mas.segment3), --CHG0037700-  fix 100% Resin credit accounting ,
             -- Ofer Suad 03/12/2013  Support new chart of account
             decode(rila.attribute10,
                    100,
                    decode(gcc_mas.segment4, NULL, '000', '0000000'),
                    nvl(gcc_mas.segment4, gcc_mas.segment5)),
             decode(rila.attribute10,
                    100,
                    '000',
                    decode(gcc_mas.segment4,
                           NULL,
                           nvl(gcc_su.segment6, '000'),
                           gcc_mas.segment5)),
             decode(rila.attribute10,
                    100,
                    decode(gcc_mas.segment4, NULL, '00', '000'),
                    decode(gcc_mas.segment4,
                           NULL,
                           gcc_mas.segment7,
                           nvl(gcc_su.segment6, '000'))), --nvl added by daniel katz on 3-feb-11
             decode(gcc_mas.segment4,
                    NULL,
                    gcc_mas.segment10,
                    gcc_mas.segment7),
             decode(gcc_mas.segment8,
                    NULL,
                    gcc_mas.segment9,
                    gcc_mas.segment8),
             decode(gcc_mas.segment8, NULL, NULL, gcc_mas.segment9),
             decode(gcc_mas.segment8, NULL, NULL, gcc_mas.segment10),
             -- End   Support new chart of account
             rila.interface_line_attribute1,
             rila.interface_line_attribute2,
             rila.interface_line_attribute3,
             rila.interface_line_attribute4,
             rila.interface_line_attribute5,
             rila.interface_line_attribute6,
             rila.interface_line_attribute7,
             rila.interface_line_attribute8,
             rila.interface_line_attribute9,
             rila.interface_line_attribute10,
             rila.interface_line_attribute11,
             rila.interface_line_attribute12,
             rila.interface_line_attribute13,
             rila.interface_line_attribute14,
             rila.interface_line_attribute15,
             SYSDATE,
             fnd_global.user_id,
             SYSDATE,
             fnd_global.login_id,
             p_organization
        FROM ra_interface_lines_all rila,
             mtl_system_items_b     msi_mas,
             hz_cust_site_uses_all  hcsu,
             gl_code_combinations   gcc_su,
             gl_code_combinations   gcc_mas,
             oe_order_lines_all     ol --added by daniel katz
       WHERE rila.inventory_item_id = msi_mas.inventory_item_id
         AND msi_mas.organization_id = ol.ship_from_org_id --Ofer Suad 03/12/2013  Support new chart of account
            -- xxinv_utils_pkg.get_master_organization_id
         AND rila.orig_system_bill_address_id = hcsu.cust_acct_site_id
         AND hcsu.site_use_code = 'BILL_TO'
         AND hcsu.gl_id_rev = gcc_su.code_combination_id(+) --outer join added by daniel katz on 3-feb-11
         AND msi_mas.sales_account = gcc_mas.code_combination_id
         AND rila.interface_line_attribute1 = to_char(p_order_number)
         AND --added to char by daniel katz
             rila.interface_line_attribute6 = to_char(ol.line_id)
         AND --added by daniel katz
             ol.header_id = p_order_header_id
         AND --added by daniel katz
             rila.amount >= 0
         AND
            --commented by daniel katz
            --                rila.sales_order_line IS NOT NULL AND
             msi_mas.item_type =
             fnd_profile.value('XXAR_CREDIT_RESIN_ITEM_TYPE');
    -----------------------------------------------------------------------

    INSERT INTO ra_interface_distributions_all
      (interface_distribution_id,
       interface_line_id,
       account_class,
       interface_line_context,
       amount,
       percent,
       segment1,
       segment2,
       segment3,
       segment4,
       segment5,
       segment6,
       segment7,
       segment8,
       segment9,
       segment10,
       interface_line_attribute1,
       interface_line_attribute2,
       interface_line_attribute3,
       interface_line_attribute4,
       interface_line_attribute5,
       interface_line_attribute6,
       interface_line_attribute7,
       interface_line_attribute8,
       interface_line_attribute9,
       interface_line_attribute10,
       interface_line_attribute11,
       interface_line_attribute12,
       interface_line_attribute13,
       interface_line_attribute14,
       interface_line_attribute15,
       creation_date,
       created_by,
       last_update_date,
       last_updated_by,
       org_id)
      SELECT ra_cust_trx_line_gl_dist_s.nextval,
             rila.interface_line_id,
             'REV',
             rila.interface_line_context,
             -1 * rila.attribute4,
             100 * (-1 * rila.attribute4 / safe_devisor(rila.amount)),
             nvl(gcc_su.segment1, gcc_mas.segment1),
             gcc_mas.segment2,
             gcc_mas.segment3,
             -- Ofer Suad 03/12/2013  Support new chart of account
             nvl(gcc_mas.segment4, gcc_mas.segment5),
             decode(gcc_mas.segment4,
                    NULL,
                    nvl(gcc_su.segment6, '000'),
                    gcc_mas.segment5),
             decode(gcc_mas.segment4,
                    NULL,
                    gcc_mas.segment7,
                    nvl(gcc_su.segment6, '000')), --nvl added by daniel katz on 3-feb-11
             decode(gcc_mas.segment4,
                    NULL,
                    gcc_mas.segment10,
                    gcc_mas.segment7),
             decode(gcc_mas.segment8,
                    NULL,
                    gcc_mas.segment9,
                    gcc_mas.segment8),
             decode(gcc_mas.segment8, NULL, NULL, gcc_mas.segment9),
             decode(gcc_mas.segment8, NULL, NULL, gcc_mas.segment10),

             /*gcc_mas.segment4,
              gcc_mas.segment5,
              nvl(gcc_su.segment6, '000'), --nvl added by daniel katz on 3-feb-11
              gcc_mas.segment7,
             gcc_mas.segment8,
              gcc_mas.segment9,
              gcc_mas.segment10,*/
             -- End   Support new chart of account
             rila.interface_line_attribute1,
             rila.interface_line_attribute2,
             rila.interface_line_attribute3,
             rila.interface_line_attribute4,
             rila.interface_line_attribute5,
             rila.interface_line_attribute6,
             rila.interface_line_attribute7,
             rila.interface_line_attribute8,
             rila.interface_line_attribute9,
             rila.interface_line_attribute10,
             rila.interface_line_attribute11,
             rila.interface_line_attribute12,
             rila.interface_line_attribute13,
             rila.interface_line_attribute14,
             rila.interface_line_attribute15,
             SYSDATE,
             fnd_global.user_id,
             SYSDATE,
             fnd_global.login_id,
             p_organization
        FROM ra_interface_lines_all rila,
             mtl_system_items_b     msi_mas,
             hz_cust_site_uses_all  hcsu,
             gl_code_combinations   gcc_su,
             gl_code_combinations   gcc_mas,
             oe_order_lines_all     ol --added by daniel katz
       WHERE rila.inventory_item_id = msi_mas.inventory_item_id
         AND msi_mas.organization_id = ol.ship_from_org_id --Ofer Suad 03/12/2013  Support new chart of account
            --  xxinv_utils_pkg.get_master_organization_id
         AND rila.orig_system_bill_address_id = hcsu.cust_acct_site_id
         AND hcsu.site_use_code = 'BILL_TO'
         AND hcsu.gl_id_rev = gcc_su.code_combination_id(+) --outer join added by daniel katz on 3-feb-11
         AND msi_mas.sales_account = gcc_mas.code_combination_id
         AND rila.interface_line_attribute1 = to_char(p_order_number)
         AND --added to char by daniel katz
             rila.interface_line_attribute6 = to_char(ol.line_id)
         AND --added by daniel katz
             ol.header_id = p_order_header_id
         AND --added by daniel katz
             rila.amount >= 0
         AND
            --commented by daniel katz
            --                rila.sales_order_line IS NOT NULL AND
             msi_mas.item_type =
             fnd_profile.value('XXAR_CREDIT_RESIN_ITEM_TYPE');
    -----------------------------------------------------------------------
    --end if;
    INSERT INTO ra_interface_distributions_all
      (interface_distribution_id,
       interface_line_id,
       account_class,
       interface_line_context,
       amount,
       percent,
       segment1,
       segment2,
       segment3,
       segment4,
       segment5,
       segment6,
       segment7,
       segment8,
       segment9,
       segment10,
       interface_line_attribute1,
       interface_line_attribute2,
       interface_line_attribute3,
       interface_line_attribute4,
       interface_line_attribute5,
       interface_line_attribute6,
       interface_line_attribute7,
       interface_line_attribute8,
       interface_line_attribute9,
       interface_line_attribute10,
       interface_line_attribute11,
       interface_line_attribute12,
       interface_line_attribute13,
       interface_line_attribute14,
       interface_line_attribute15,
       creation_date,
       created_by,
       last_update_date,
       last_updated_by,
       org_id)
      (SELECT ra_cust_trx_line_gl_dist_s.nextval,
              rila.interface_line_id,
              'REV',
              rila.interface_line_context,
              1 * rila.attribute4, --CHG0037700-  fix 100% Resin credit accounting
              100 * (rila.attribute4 / safe_devisor(rila.amount)),
              nvl(gcc_su.segment1, gcc_mas.segment1),
              gcc_mas.segment2,
              gcc_mas.segment3,
              -- Ofer Suad 03/12/2013  Support new chart of account
              nvl(gcc_mas.segment4, gcc_mas.segment5),
              decode(gcc_mas.segment4,
                     NULL,
                     nvl(gcc_su.segment6, '000'),
                     gcc_mas.segment5),
              decode(gcc_mas.segment4,
                     NULL,
                     gcc_mas.segment7,
                     nvl(gcc_su.segment6, '000')), --nvl added by daniel katz on 3-feb-11
              decode(gcc_mas.segment4,
                     NULL,
                     gcc_mas.segment10,
                     gcc_mas.segment7),
              decode(gcc_mas.segment8,
                     NULL,
                     gcc_mas.segment9,
                     gcc_mas.segment8),
              decode(gcc_mas.segment8, NULL, NULL, gcc_mas.segment9),
              decode(gcc_mas.segment8, NULL, NULL, gcc_mas.segment10),

              /*gcc_mas.segment4,
              gcc_mas.segment5,
              nvl(gcc_su.segment6, '000'), --nvl added by daniel katz on 3-feb-11
              gcc_mas.segment7,
              gcc_mas.segment8,
              gcc_mas.segment9,
              gcc_mas.segment10,*/
              -- End   Support new chart of account
              rila.interface_line_attribute1,
              rila.interface_line_attribute2,
              rila.interface_line_attribute3,
              rila.interface_line_attribute4,
              rila.interface_line_attribute5,
              rila.interface_line_attribute6,
              rila.interface_line_attribute7,
              rila.interface_line_attribute8,
              rila.interface_line_attribute9,
              rila.interface_line_attribute10,
              rila.interface_line_attribute11,
              rila.interface_line_attribute12,
              rila.interface_line_attribute13,
              rila.interface_line_attribute14,
              rila.interface_line_attribute15,
              SYSDATE,
              fnd_global.user_id,
              SYSDATE,
              fnd_global.login_id,
              p_organization
         FROM ra_interface_lines_all rila,
              mtl_system_items_b     msi_mas,
              hz_cust_site_uses_all  hcsu,
              gl_code_combinations   gcc_su,
              gl_code_combinations   gcc_mas,
              oe_order_lines_all     ol --added by daniel katz
        WHERE rila.inventory_item_id = msi_mas.inventory_item_id
          AND msi_mas.organization_id = ol.ship_from_org_id --Ofer Suad 03/12/2013  Support new chart of account
             --  xxinv_utils_pkg.get_master_organization_id
          AND rila.orig_system_bill_address_id = hcsu.cust_acct_site_id
          AND hcsu.site_use_code = 'BILL_TO'
          AND hcsu.gl_id_rev = gcc_su.code_combination_id(+) --outer join added by daniel katz on 3-feb-11
          AND msi_mas.cost_of_sales_account = gcc_mas.code_combination_id
          AND rila.interface_line_attribute1 = to_char(p_order_number)
          AND --added to char by daniel katz
              rila.interface_line_attribute6 = to_char(ol.line_id)
          AND --added by daniel katz
              ol.header_id = p_order_header_id
          AND --added by daniel katz
              rila.amount >= 0
          AND
             --commented by daniel katz
             --                rila.sales_order_line IS NOT NULL AND
              msi_mas.item_type =
              fnd_profile.value('XXAR_CREDIT_RESIN_ITEM_TYPE'));

    UPDATE ra_interface_lines_all rila
       SET unit_standard_price = attribute4,
           description        =
           (SELECT description || ': ' || rila.attribute4 || ' ' ||
                   rila.currency_code
              FROM mtl_system_items_b msi
             WHERE msi.inventory_item_id = rila.inventory_item_id
               AND msi.organization_id =
                   xxinv_utils_pkg.get_master_organization_id)
     WHERE rila.interface_line_attribute1 = to_char(p_order_number)
       AND --added to char by daniel katz
          --commented by daniel katz - next line isn't needed
          --             rila.sales_order_line IS NOT NULL AND
           rila.amount >= 0
       AND EXISTS
     (SELECT 1
              FROM mtl_system_items_b msi
             WHERE msi.inventory_item_id = rila.inventory_item_id
               AND msi.organization_id =
                   xxinv_utils_pkg.get_master_organization_id
                  --added  by daniel katz (to restrict to the resin credit item line)
               AND msi.item_type =
                   fnd_profile.value('XXAR_CREDIT_RESIN_ITEM_TYPE'))
          --added by daniel katz following condition to restrict also by order header id
       AND EXISTS
     (SELECT 1
              FROM oe_order_lines_all ol
             WHERE rila.interface_line_attribute6 = to_char(ol.line_id)
               AND ol.header_id = p_order_header_id);

  EXCEPTION
    WHEN OTHERS THEN

      fnd_file.put_line(fnd_file.log,
                        'HANDLE_CREDIT_RESIN_POS_TRX: ' || SQLERRM);
      x_err_msg       := NULL;
      x_return_status := fnd_api.g_ret_sts_error;

  END handle_credit_resin_pos_trx;

  --------------------------------------------------------------------
  PROCEDURE handle_credit_resin_neg_trx( /*p_order_header_id NUMBER,*/ --commented by daniel katz and added other parameters
                                        p_cust_acct_id    NUMBER,
                                        p_currency        VARCHAR2,
                                        p_organization    NUMBER,
                                        p_precision       IN NUMBER,
                                        p_order_header_id rila_order_headers_type,
                                        x_return_status   OUT VARCHAR2,
                                        x_err_msg         OUT VARCHAR2) IS

    -- Cursor adjusted by daniel katz so it will be for all lines for same customer but only to relevant sale orders
    CURSOR csr_neg_resin_lines(p_crs_ord_header_id NUMBER) IS
    --adjusted by daniel katz to rowid isntead of interface line id (interface line id is null. only when line is rejected there is a value)
      SELECT /*rila.interface_line_id*/
       rila.rowid,
       rila.amount,
       --commented by daniel katz and replaced below
       /*                rila.orig_system_bill_customer_id,
       rila.currency_code,
       inventory_item_id
       */
       rila.interface_line_attribute6 line_id,
       rila.interface_line_attribute1 order_number,
       ol.ship_from_org_id
        FROM ra_interface_lines_all rila,
             --ra_cust_trx_types_all  rctt,--18/021/2015         Ofer Suad       CHG0032677?verage discount for all orders type
             oe_order_lines_all   ol,
             oe_order_headers_all oh
      --commented by daniel katz and replaced by other condition
      --          WHERE rila.interface_line_attribute1 = p_order_number AND
       WHERE rila.orig_system_bill_customer_id = p_cust_acct_id
         AND rila.currency_code = p_currency
         AND
            --added by daniel katz
             rila.org_id = p_organization
         AND rila.amount < 0
            -- 18/021/2015         Ofer Suad       CHG0032677?verage discount for all orders type
            -- AND    rctt.cust_trx_type_id = rila.cust_trx_type_id
            --  AND    rctt.org_id = rila.org_id
            --  AND    nvl(rctt.attribute5, 'N') = 'N'
            -- end CHG0032677
         AND
            --commented by daniel katz -->this line isn't needed
            --                rila.sales_order_line IS NOT NULL AND
             EXISTS
       (SELECT 1
                FROM mtl_system_items_b msi
               WHERE msi.inventory_item_id = rila.inventory_item_id
                 AND msi.organization_id =
                     xxinv_utils_pkg.get_master_organization_id
                    --added  by daniel katz (to restrict to the resin credit item line)
                 AND msi.item_type =
                     fnd_profile.value('XXAR_CREDIT_RESIN_ITEM_TYPE'))
         AND ol.header_id = oh.header_id
         AND rila.interface_line_attribute6 = to_char(ol.line_id)
         AND ol.header_id = p_crs_ord_header_id
         AND rila.sales_order = to_char(oh.order_number)
       ORDER BY rila.sales_order_date,
                rila.sales_order,
                rila.sales_order_line;

    cur_neg_resin_line  csr_neg_resin_lines%ROWTYPE;
    l_customer          hz_parties.party_name%TYPE;
    l_inventory_item_id NUMBER;
    --l_is_resin          NUMBER;
    l_continue NUMBER;

    --t_order_numbers    rila_order_numbers_type;
    --t_order_headers_id rila_order_headers_type;

    /*      l_temp_pos_counter    NUMBER := 0;
    l_positive_counter    NUMBER := 0;
    l_credit_resin_amount NUMBER;
    t_negative_ids        rila_order_numbers_type;
    t_negative_amounts    rila_order_numbers_type;
    t_positive_ids        rila_order_numbers_type;
    t_positive_amounts    rila_order_numbers_type;
    t_positive_discounts  rila_order_numbers_type;

    l_remain_negative_amount NUMBER;
    l_remain_positive_amount NUMBER;*/
    l_return_status VARCHAR2(1);

    l_acc_negative_amount NUMBER;
    l_amount_for_adjust   NUMBER;
    l_adjust_high         NUMBER := 0;
    l_adjust_low          NUMBER := 0;
    l_check_balance       NUMBER := -1;

  BEGIN

    --commented by daniel katz (moved below)
    --      FOR cur_neg_resin_line IN csr_neg_resin_lines LOOP

    SELECT party_name
      INTO l_customer
      FROM hz_parties hp, hz_cust_accounts hca
     WHERE hp.party_id = hca.party_id
       AND hca.cust_account_id = p_cust_acct_id;

    --  is sum of attribute4 on positive lines [that their attribute10 is not null] +
    --     sum of selling price on negative lines (incl. current line on interface)
    --  >= 0 for same currency+Bill To Customer) ***  and Item - Ella ***.

    --ADDED BY daniel katz
    BEGIN
      SELECT nvl(SUM(amount), 0)
        INTO l_check_balance
        FROM (SELECT SUM(nvl(ol.attribute4, 0)) amount
                FROM oe_order_lines_all     ol,
                     hz_cust_site_uses_all  hcsu,
                     hz_cust_acct_sites_all hcas,
                     oe_order_headers_all   oh,
                     mtl_system_items_b     msi
               WHERE decode(oh.attribute8,
                            'SHIP_TO',
                            ol.ship_to_org_id,
                            ol.invoice_to_org_id) = hcsu.site_use_id
                    --ol.invoice_to_org_id = hcsu.site_use_id
                 AND hcsu.cust_acct_site_id = hcas.cust_acct_site_id
                 AND hcas.cust_account_id = p_cust_acct_id
                 AND oh.header_id = ol.header_id
                 AND oh.transactional_curr_code = p_currency
                 AND decode(oh.org_id, 89, 737, oh.org_id) = p_organization --   15/10/2014         ofer Suad       Fix org Id CR-1122
                 AND msi.inventory_item_id = ol.inventory_item_id
                 AND msi.organization_id = ol.ship_from_org_id
                 AND msi.item_type =
                     fnd_profile.value('XXAR_CREDIT_RESIN_ITEM_TYPE')
                 AND ol.unit_selling_price >= 0
                 AND ol.attribute10 IS NOT NULL
                 AND ol.cancelled_flag = 'N'
              UNION ALL
              SELECT SUM(decode(ol.line_category_code, 'RETURN', -1, 1) *
                         ol.unit_selling_price * ol.ordered_quantity) amount
                FROM oe_order_lines_all     ol,
                     hz_cust_site_uses_all  hcsu,
                     hz_cust_acct_sites_all hcas,
                     oe_order_headers_all   oh,
                     mtl_system_items_b     msi
               WHERE decode(oh.attribute8,
                            'SHIP_TO',
                            ol.ship_to_org_id,
                            ol.invoice_to_org_id) = hcsu.site_use_id
                    --ol.invoice_to_org_id = hcsu.site_use_id
                 AND hcsu.cust_acct_site_id = hcas.cust_acct_site_id
                 AND hcas.cust_account_id = p_cust_acct_id
                 AND oh.header_id = ol.header_id
                 AND oh.transactional_curr_code = p_currency
                 AND decode(oh.org_id, 89, 737, oh.org_id) = p_organization --   15/10/2014         ofer Suad       Fix org Id CR-1122
                 AND msi.inventory_item_id = ol.inventory_item_id
                 AND msi.organization_id = ol.ship_from_org_id
                 AND msi.item_type =
                     fnd_profile.value('XXAR_CREDIT_RESIN_ITEM_TYPE')
                 AND ol.unit_selling_price < 0
                 AND ol.cancelled_flag = 'N');

      IF l_check_balance < 0 THEN
        -- ofer
        fnd_message.set_name('XXOBJT', 'XXAR_AUTOINV_RESIN_OPEN_BANCE');
        fnd_message.set_token('CUSTOMER', l_customer);
        fnd_message.set_token('CURRENCY', p_currency);
        fnd_file.put_line(fnd_file.output, fnd_message.get);
        fnd_file.put_line(fnd_file.log, fnd_message.get);

        x_return_status := fnd_api.g_ret_sts_error;
        RETURN;

      END IF;

    EXCEPTION
      WHEN OTHERS THEN
        fnd_message.set_name('XXOBJT', 'XXAR_AUTOINV_RESIN_OPEN_BANCE');
        fnd_message.set_token('CUSTOMER', l_customer);
        fnd_message.set_token('CURRENCY', p_currency);
        fnd_file.put_line(fnd_file.output, fnd_message.get);
        fnd_file.put_line(fnd_file.log, fnd_message.get);

        x_return_status := fnd_api.g_ret_sts_error;
        RETURN;

    END;

    --commented by daniel katz
    /*         SELECT rctl.customer_trx_line_id,
           nvl(rctl.attribute4, 0),
           rctl.attribute10 BULK COLLECT
      INTO t_positive_ids, t_positive_amounts, t_positive_discounts
      FROM ra_customer_trx_all       rct,
           ra_customer_trx_lines_all rctl,
           ra_cust_trx_types_all     rctt
     WHERE rct.customer_trx_id = rctl.customer_trx_id AND
           rct.cust_trx_type_id = rctt.cust_trx_type_id AND
           nvl(rctt.attribute5, 'N') = 'Y' AND
           rct.bill_to_customer_id =
           cur_neg_resin_line.orig_system_bill_customer_id AND
           rct.invoice_currency_code =
           cur_neg_resin_line.currency_code AND
           rctl.inventory_item_id =
           cur_neg_resin_line.inventory_item_id AND
           rctl.attribute10 IS NOT NULL AND
           rctl.extended_amount >= 0
     ORDER BY rctl.sales_order_date, rctl.sales_order_line;

    SELECT rctl.customer_trx_line_id, nvl(rctl.unit_selling_price, 0) BULK COLLECT
      INTO t_negative_ids, t_negative_amounts
      FROM ra_customer_trx_all       rct,
           ra_customer_trx_lines_all rctl,
           ra_cust_trx_types_all     rctt
     WHERE rct.customer_trx_id = rctl.customer_trx_id AND
           rct.cust_trx_type_id = rctt.cust_trx_type_id AND
           nvl(rctt.attribute5, 'N') = 'N' AND
           rct.bill_to_customer_id =
           cur_neg_resin_line.orig_system_bill_customer_id AND
           rct.invoice_currency_code =
           cur_neg_resin_line.currency_code AND
           rctl.inventory_item_id =
           cur_neg_resin_line.inventory_item_id AND
           rctl.extended_amount < 0
     ORDER BY rctl.sales_order_date, rctl.sales_order_line;*/

    --added by daniel katz to calculate accumulated negative resin exists in AR.
    /*SELECT nvl(SUM(nvl(rctl.extended_amount, 0)), 0)
    INTO   l_acc_negative_amount
    FROM   ra_customer_trx_all       rct,
           ra_customer_trx_lines_all rctl,
           mtl_system_items_b        msi
    WHERE  rct.customer_trx_id = rctl.customer_trx_id
    AND    rct.bill_to_customer_id = p_cust_acct_id
    AND    rct.invoice_currency_code = p_currency
    AND    decode(rct.org_id, 89, 737, rct.org_id) = p_organization --   15/10/2014         ofer Suad       Fix org Id CR-1122
    AND    rctl.inventory_item_id = msi.inventory_item_id
    AND    msi.organization_id = xxinv_utils_pkg.get_master_organization_id
    AND    msi.item_type = fnd_profile.value('XXAR_CREDIT_RESIN_ITEM_TYPE')
    AND    rctl.unit_selling_price < 0
    AND    rctl.line_type = 'LINE';*/

    -- CHG0042261 ?fix autoinvoice Rasin credit balance calculation : fix for calculation of accumulated resin in AR.
    SELECT nvl(SUM(nvl(rctl.extended_amount, 0)), 0)
      INTO l_acc_negative_amount
      FROM ra_customer_trx_all       rct,
           ra_customer_trx_lines_all rctl,
           mtl_system_items_b        msi,
           oe_order_lines_all        ol, --CHG0042261
           oe_order_headers_all      oh --CHG0042261
     WHERE rct.invoice_currency_code = p_currency
       AND rct.bill_to_customer_id = p_cust_acct_id
       AND decode(rct.org_id, 89, 737, rct.org_id) = p_organization --   15/10/2014         ofer Suad       Fix org Id CR-1122
       AND rct.customer_trx_id = rctl.customer_trx_id
       AND rctl.inventory_item_id = msi.inventory_item_id
       AND msi.organization_id = xxinv_utils_pkg.get_master_organization_id
       AND msi.item_type = fnd_profile.value('XXAR_CREDIT_RESIN_ITEM_TYPE')
       AND rctl.unit_selling_price < 0
       AND rctl.line_type = 'LINE' --CHG0042261
       AND to_char(ol.line_id) = rctl.interface_line_attribute6
       AND oh.header_id = ol.header_id
       AND decode(oh.attribute8,
                  'SHIP_TO',
                  ol.ship_to_org_id,
                  ol.invoice_to_org_id) = rct.bill_to_site_use_id;

    l_adjust_high := get_acc_resin_credit_avg_bal(p_cust_acct_id,
                                                  p_organization,
                                                  p_currency,
                                                  -1 * l_acc_negative_amount,
                                                  l_return_status);

    IF l_return_status != fnd_api.g_ret_sts_success THEN
      x_return_status := l_return_status;
      fnd_file.put_line(fnd_file.output,
                        'There is not enough Resin Credit balance in AR');
      fnd_file.put_line(fnd_file.log,
                        'There is not enough Resin Credit balance in AR');

      RETURN;
    END IF;

    FOR idx IN 1 .. p_order_header_id.count LOOP

      BEGIN

        SELECT 1
          INTO l_continue
          FROM oe_order_headers_all   oh,
               hz_cust_site_uses_all  hcsu,
               hz_cust_acct_sites_all hcas
         WHERE oh.invoice_to_org_id = hcsu.site_use_id
           AND hcsu.cust_acct_site_id = hcas.cust_acct_site_id
           AND hcas.cust_account_id = p_cust_acct_id
           AND oh.header_id = p_order_header_id(idx)
           AND oh.transactional_curr_code = p_currency
           AND oh.org_id = p_organization
           AND rownum < 2;

      EXCEPTION
        WHEN OTHERS THEN
          l_continue := 0;
      END;

      IF l_continue = 1 THEN
        FOR cur_neg_resin_line IN csr_neg_resin_lines(p_order_header_id(idx)) LOOP

          --commented by daniel katz
          /*         l_positive_counter       := 1;
          l_remain_positive_amount := t_positive_amounts(l_positive_counter);

          -- runs over negative lines and check for positive existance
          FOR i IN 1 .. t_negative_ids.COUNT LOOP

             l_remain_negative_amount := t_negative_amounts(i);

             -- if negative amount smaller or equal to positive amount remaining, adjust positive remaining
             -- and go to next negative line, positive counter does not increase
             IF l_remain_negative_amount <= l_remain_positive_amount THEN

                l_remain_positive_amount := l_remain_positive_amount -
                                            l_remain_negative_amount;

                -- if negative line is bigger than positive remaining, adjust negative remaining so that positive
                -- remaining would be 0, then increase positive counter. and recheck
                --
             ELSE

                l_remain_negative_amount := l_remain_negative_amount -
                                            l_remain_positive_amount;
                l_remain_positive_amount := 0;

                IF l_positive_counter + 1 = t_positive_ids.COUNT THEN

                   fnd_message.set_name('XXOBJT',
                                        'XXAR_AUTOINV_RESIN_OPEN_BANCE');
                   fnd_message.set_token('CUSTOMER', l_customer);
                   fnd_message.set_token('CURRENCY',
                                         cur_neg_resin_line.currency_code);

                   x_return_status := fnd_api.g_ret_sts_error;
                   RETURN;
                END IF;

                FOR j IN l_positive_counter + 1 .. t_positive_ids.COUNT LOOP

                   l_temp_pos_counter       := j;
                   l_remain_positive_amount := t_positive_amounts(j);

                   EXIT WHEN l_remain_positive_amount > l_remain_negative_amount;

                   l_remain_negative_amount := l_remain_negative_amount -
                                               l_remain_positive_amount;

                END LOOP;
                l_positive_counter := l_temp_pos_counter;

                l_remain_positive_amount := l_remain_positive_amount -
                                            l_remain_negative_amount;

             END IF;
          END LOOP;

          --calculate resin amount
          BEGIN
             l_credit_resin_amount := 0;

             IF l_remain_positive_amount >= cur_neg_resin_line.amount THEN

                l_credit_resin_amount := cur_neg_resin_line.amount *
                                         t_positive_discounts(l_positive_counter) / 100;
             ELSE

                l_remain_negative_amount := cur_neg_resin_line.amount;

                FOR i IN l_positive_counter .. t_positive_ids.COUNT LOOP

                   IF l_remain_negative_amount > l_remain_positive_amount THEN
                      l_credit_resin_amount := l_credit_resin_amount +
                                               l_remain_positive_amount *
                                               t_positive_discounts(i) / 100;

                   ELSE
                      l_credit_resin_amount := l_credit_resin_amount +
                                               l_remain_negative_amount *
                                               t_positive_discounts(i) / 100;

                      EXIT;
                   END IF;
                   l_remain_negative_amount := l_remain_negative_amount -
                                               t_positive_amounts(i);
                   l_remain_positive_amount := t_positive_amounts(i + 1);
                END LOOP;

             END IF;

             l_remain_positive_amount := round(l_remain_positive_amount,
                                               p_precision);
          EXCEPTION
             WHEN OTHERS THEN

                fnd_message.set_name('XXOBJT',
                                     'XXAR_AUTOINV_RESIN_OPEN_BANCE');
                fnd_message.set_token('CUSTOMER', l_customer);
                fnd_message.set_token('CURRENCY',
                                      cur_neg_resin_line.currency_code);

                x_err_msg       := fnd_message.get;
                x_return_status := fnd_api.g_ret_sts_error;
                RETURN;
          END;*/
          --Round{Credit Resins amount (i.e. the amount in current negative line for Resin Credit item) * Original average discount (from Attribute10)/100, l_precision

          l_adjust_low := l_adjust_high;

          l_acc_negative_amount := l_acc_negative_amount +
                                   cur_neg_resin_line.amount;

          l_adjust_high := get_acc_resin_credit_avg_bal(p_cust_acct_id,
                                                        p_organization,
                                                        p_currency,
                                                        -1 *
                                                        l_acc_negative_amount,
                                                        l_return_status);

          IF l_return_status != fnd_api.g_ret_sts_success THEN
            x_return_status := l_return_status;
            fnd_file.put_line(fnd_file.output,
                              'There is not enough Resin Credit balance in AR');
            fnd_file.put_line(fnd_file.log,
                              'There is not enough Resin Credit balance in AR');

            RETURN;
          END IF;

          l_amount_for_adjust := round((l_adjust_high - l_adjust_low),
                                       p_precision);

          INSERT INTO ra_interface_distributions_all
            (interface_distribution_id,
             interface_line_id,
             account_class,
             interface_line_context,
             amount,
             percent,
             segment1,
             segment2,
             segment3,
             segment4,
             segment5,
             segment6,
             segment7,
             segment8,
             segment9,
             segment10,
             interface_line_attribute1,
             interface_line_attribute2,
             interface_line_attribute3,
             interface_line_attribute4,
             interface_line_attribute5,
             interface_line_attribute6,
             interface_line_attribute7,
             interface_line_attribute8,
             interface_line_attribute9,
             interface_line_attribute10,
             interface_line_attribute11,
             interface_line_attribute12,
             interface_line_attribute13,
             interface_line_attribute14,
             interface_line_attribute15,
             creation_date,
             created_by,
             last_update_date,
             last_updated_by,
             org_id)
            SELECT ra_cust_trx_line_gl_dist_s.nextval,
                   rila.interface_line_id,
                   'REV',
                   rila.interface_line_context,
                   rila.amount,
                   100,
                   nvl(gcc_su.segment1, gcc_mas.segment1),
                   gcc_mas.segment2,
                   gcc_mas.segment3,
                   -- Ofer Suad 03/12/2013  Support new chart of account
                   nvl(gcc_mas.segment4, gcc_mas.segment5),
                   decode(gcc_mas.segment4,
                          NULL,
                          nvl(gcc_su.segment6, '000'),
                          gcc_mas.segment5),
                   decode(gcc_mas.segment4,
                          NULL,
                          gcc_mas.segment7,
                          nvl(gcc_su.segment6, '000')), --nvl added by daniel katz on 3-feb-11
                   decode(gcc_mas.segment4,
                          NULL,
                          gcc_mas.segment10,
                          gcc_mas.segment7),
                   decode(gcc_mas.segment8,
                          NULL,
                          gcc_mas.segment9,
                          gcc_mas.segment8),
                   decode(gcc_mas.segment8, NULL, NULL, gcc_mas.segment9),
                   decode(gcc_mas.segment8, NULL, NULL, gcc_mas.segment10),
                   /*gcc_mas.segment4,
                   gcc_mas.segment5,
                   nvl(gcc_su.segment6, '000'), --nvl added by daniel katz on 3-feb-11
                   gcc_mas.segment7,
                   gcc_mas.segment8,
                   gcc_mas.segment9,
                   gcc_mas.segment10,*/
                   -- End   Support new chart of account
                   rila.interface_line_attribute1,
                   rila.interface_line_attribute2,
                   rila.interface_line_attribute3,
                   rila.interface_line_attribute4,
                   rila.interface_line_attribute5,
                   rila.interface_line_attribute6,
                   rila.interface_line_attribute7,
                   rila.interface_line_attribute8,
                   rila.interface_line_attribute9,
                   rila.interface_line_attribute10,
                   rila.interface_line_attribute11,
                   rila.interface_line_attribute12,
                   rila.interface_line_attribute13,
                   rila.interface_line_attribute14,
                   rila.interface_line_attribute15,
                   SYSDATE,
                   fnd_global.user_id,
                   SYSDATE,
                   fnd_global.login_id,
                   p_organization
              FROM ra_interface_lines_all rila,
                   mtl_system_items_b     msi_mas,
                   gl_code_combinations   gcc_mas,
                   hz_cust_site_uses_all  hcsu,
                   gl_code_combinations   gcc_su
             WHERE rila.inventory_item_id = msi_mas.inventory_item_id
               AND msi_mas.organization_id =
                   cur_neg_resin_line.ship_from_org_id --Ofer Suad 03/12/2013  Support new chart of account
                  --    xxinv_utils_pkg.get_master_organization_id
               AND rila.orig_system_bill_address_id =
                   hcsu.cust_acct_site_id
               AND hcsu.site_use_code = 'BILL_TO'
               AND hcsu.gl_id_rev = gcc_su.code_combination_id(+) --outer join added by daniel katz on 3-feb-11
               AND msi_mas.cost_of_sales_account =
                   gcc_mas.code_combination_id
               AND
                  --adjusted by daniel katz instead of interface line id to rowid
                   rila.rowid = cur_neg_resin_line.rowid;

          BEGIN
            --commented by daniel katz and replaced with other (will use attribute 5 as a reference to original line)
            /*            SELECT inventory_item_id
                          INTO l_inventory_item_id
                          FROM oe_order_headers_all oh, oe_order_lines_all ol
                         WHERE oh.header_id = ol.header_id AND
                               ol.line_id =
                               (SELECT MAX(line_id)
                                  FROM oe_order_lines_all ol1
                                 WHERE ol1.header_id = ol.header_id AND
                                       ol1.line_id < ol.line_id) AND
                               oh.order_number = p_order_number;
            */
            -- 08/07/2014 Ofer Suad CR # CHG0032527 -Add FDM Items
            SELECT ol_ref.inventory_item_id
              INTO l_inventory_item_id
              FROM oe_order_lines_all   ol,
                   oe_order_lines_all   ol_ref,
                   oe_order_headers_all oh
             WHERE ol.line_id = cur_neg_resin_line.line_id
               AND ol.header_id = oh.header_id
               AND oh.order_number = cur_neg_resin_line.order_number
               AND ol_ref.header_id = ol.header_id
               AND ol_ref.line_number = ol.attribute5
               AND ol.cancelled_flag = 'N'
                  -- #CHG0033168 we can use resin credit against all items
                  -- and xxinv_item_classification.is_item_material(ol_ref.inventory_item_id) = 'Y'
               AND rownum < 2;

            /*SELECT 1
             INTO l_is_resin
             FROM mtl_categories_b mc, mtl_item_categories mic
            WHERE mic.inventory_item_id = l_inventory_item_id
              AND mic.organization_id =
                  xxinv_utils_pkg.get_master_organization_id
              AND mic.category_id = mc.category_id
              AND mic.category_set_id =
                  xxinv_utils_pkg.get_default_category_set_id
              AND mc.segment1 = 'Resins';*/

          EXCEPTION
            WHEN no_data_found THEN
              fnd_message.set_name('XXOBJT', 'XXAR_AUTOINV_NEG_RESIN_ITEM');
              -- 1.3  29/01/2012  Ofer Suad Add sale order number to error message
              fnd_message.set_token('SALE_ORDER',
                                    cur_neg_resin_line.order_number);
              fnd_file.put_line(fnd_file.output, fnd_message.get);
              fnd_file.put_line(fnd_file.log, fnd_message.get);

              --added by daniel katz
              x_return_status := fnd_api.g_ret_sts_error;
              RETURN;
          END;

          INSERT INTO ra_interface_distributions_all
            (interface_distribution_id,
             interface_line_id,
             account_class,
             interface_line_context,
             amount,
             percent,
             segment1,
             segment2,
             segment3,
             segment4,
             segment5,
             segment6,
             segment7,
             segment8,
             segment9,
             segment10,
             interface_line_attribute1,
             interface_line_attribute2,
             interface_line_attribute3,
             interface_line_attribute4,
             interface_line_attribute5,
             interface_line_attribute6,
             interface_line_attribute7,
             interface_line_attribute8,
             interface_line_attribute9,
             interface_line_attribute10,
             interface_line_attribute11,
             interface_line_attribute12,
             interface_line_attribute13,
             interface_line_attribute14,
             interface_line_attribute15,
             creation_date,
             created_by,
             last_update_date,
             last_updated_by,
             org_id)
            SELECT ra_cust_trx_line_gl_dist_s.nextval,
                   rila.interface_line_id,
                   'REV',
                   rila.interface_line_context,
                   -1 * l_amount_for_adjust,
                   100 * (-1 * l_amount_for_adjust) / rila.amount,
                   nvl(gcc_su.segment1, gcc_mas.segment1),
                   gcc_mas.segment2,
                   gcc_mas.segment3,
                   -- Ofer Suad 03/12/2013  Support new chart of account
                   nvl(gcc_mas.segment4, gcc_mas.segment5),
                   decode(gcc_mas.segment4,
                          NULL,
                          nvl(gcc_su.segment6, '000'),
                          gcc_mas.segment5),
                   decode(gcc_mas.segment4,
                          NULL,
                          gcc_mas.segment7,
                          nvl(gcc_su.segment6, '000')), --nvl added by daniel katz on 3-feb-11
                   decode(gcc_mas.segment4,
                          NULL,
                          gcc_mas.segment10,
                          gcc_mas.segment7),
                   decode(gcc_mas.segment8,
                          NULL,
                          gcc_mas.segment9,
                          gcc_mas.segment8),
                   decode(gcc_mas.segment8, NULL, NULL, gcc_mas.segment9),
                   decode(gcc_mas.segment8, NULL, NULL, gcc_mas.segment10),
                   /*gcc_mas.segment4,
                   gcc_mas.segment5,
                   nvl(gcc_su.segment6, '000'), --nvl added by daniel katz on 3-feb-11
                   gcc_mas.segment7,
                   gcc_mas.segment8,
                   gcc_mas.segment9,
                   gcc_mas.segment10,*/
                   -- End   Support new chart of account
                   rila.interface_line_attribute1,
                   rila.interface_line_attribute2,
                   rila.interface_line_attribute3,
                   rila.interface_line_attribute4,
                   rila.interface_line_attribute5,
                   rila.interface_line_attribute6,
                   rila.interface_line_attribute7,
                   rila.interface_line_attribute8,
                   rila.interface_line_attribute9,
                   rila.interface_line_attribute10,
                   rila.interface_line_attribute11,
                   rila.interface_line_attribute12,
                   rila.interface_line_attribute13,
                   rila.interface_line_attribute14,
                   rila.interface_line_attribute15,
                   SYSDATE,
                   fnd_global.user_id,
                   SYSDATE,
                   fnd_global.login_id,
                   p_organization
              FROM ra_interface_lines_all rila,
                   mtl_system_items_b     msi_mas,
                   gl_code_combinations   gcc_mas,
                   hz_cust_site_uses_all  hcsu,
                   gl_code_combinations   gcc_su
            --commented by daniel katz and changed (it can't be against rila as the rila here is other record not according the l inventory item)
             WHERE /*rila.inventory_item_id*/
             msi_mas.inventory_item_id = l_inventory_item_id
             AND msi_mas.organization_id = cur_neg_resin_line.ship_from_org_id --Ofer Suad 03/12/2013  Support new chart of account
            --   xxinv_utils_pkg.get_master_organization_id
             AND msi_mas.sales_account = gcc_mas.code_combination_id
             AND rila.orig_system_bill_address_id = hcsu.cust_acct_site_id
             AND hcsu.site_use_code = 'BILL_TO'
             AND hcsu.gl_id_rev = gcc_su.code_combination_id(+) --outer join added by daniel katz on 3-feb-11
             AND
            --adjusted by daniel katz instead of interface line id to rowid
             rila.rowid = cur_neg_resin_line.rowid;

          INSERT INTO ra_interface_distributions_all
            (interface_distribution_id,
             interface_line_id,
             account_class,
             interface_line_context,
             amount,
             percent,
             segment1,
             segment2,
             segment3,
             segment4,
             segment5,
             segment6,
             segment7,
             segment8,
             segment9,
             segment10,
             interface_line_attribute1,
             interface_line_attribute2,
             interface_line_attribute3,
             interface_line_attribute4,
             interface_line_attribute5,
             interface_line_attribute6,
             interface_line_attribute7,
             interface_line_attribute8,
             interface_line_attribute9,
             interface_line_attribute10,
             interface_line_attribute11,
             interface_line_attribute12,
             interface_line_attribute13,
             interface_line_attribute14,
             interface_line_attribute15,
             creation_date,
             created_by,
             last_update_date,
             last_updated_by,
             org_id)
            SELECT ra_cust_trx_line_gl_dist_s.nextval,
                   rila.interface_line_id,
                   'REV',
                   rila.interface_line_context,
                   l_amount_for_adjust,
                   -100 * (-1 * l_amount_for_adjust) / rila.amount,
                   nvl(gcc_su.segment1, gcc_mas.segment1),
                   gcc_mas.segment2,
                   gcc_mas.segment3,
                   -- Ofer Suad 03/12/2013  Support new chart of account
                   nvl(gcc_mas.segment4, gcc_mas.segment5),
                   decode(gcc_mas.segment4,
                          NULL,
                          nvl(gcc_su.segment6, '000'),
                          gcc_mas.segment5),
                   decode(gcc_mas.segment4,
                          NULL,
                          gcc_mas.segment7,
                          nvl(gcc_su.segment6, '000')), --nvl added by daniel katz on 3-feb-11
                   decode(gcc_mas.segment4,
                          NULL,
                          gcc_mas.segment10,
                          gcc_mas.segment7),
                   decode(gcc_mas.segment8,
                          NULL,
                          gcc_mas.segment9,
                          gcc_mas.segment8),
                   decode(gcc_mas.segment8, NULL, NULL, gcc_mas.segment9),
                   decode(gcc_mas.segment8, NULL, NULL, gcc_mas.segment10),
                   /*gcc_mas.segment4,
                   gcc_mas.segment5,
                   nvl(gcc_su.segment6, '000'), --nvl added by daniel katz on 3-feb-11
                   gcc_mas.segment7,
                   gcc_mas.segment8,
                   gcc_mas.segment9,
                   gcc_mas.segment10,*/
                   -- End   Support new chart of account
                   rila.interface_line_attribute1,
                   rila.interface_line_attribute2,
                   rila.interface_line_attribute3,
                   rila.interface_line_attribute4,
                   rila.interface_line_attribute5,
                   rila.interface_line_attribute6,
                   rila.interface_line_attribute7,
                   rila.interface_line_attribute8,
                   rila.interface_line_attribute9,
                   rila.interface_line_attribute10,
                   rila.interface_line_attribute11,
                   rila.interface_line_attribute12,
                   rila.interface_line_attribute13,
                   rila.interface_line_attribute14,
                   rila.interface_line_attribute15,
                   SYSDATE,
                   fnd_global.user_id,
                   SYSDATE,
                   fnd_global.login_id,
                   p_organization
              FROM ra_interface_lines_all rila,
                   mtl_system_items_b     msi_mas,
                   hz_cust_site_uses_all  hcsu,
                   gl_code_combinations   gcc_su,
                   gl_code_combinations   gcc_mas
             WHERE rila.inventory_item_id = msi_mas.inventory_item_id
               AND msi_mas.organization_id =
                   cur_neg_resin_line.ship_from_org_id --Ofer Suad 03/12/2013  Support new chart of account
                  --   xxinv_utils_pkg.get_master_organization_id
               AND rila.orig_system_bill_address_id =
                   hcsu.cust_acct_site_id
               AND hcsu.site_use_code = 'BILL_TO'
               AND hcsu.gl_id_rev = gcc_su.code_combination_id(+) --outer join added by daniel katz on 3-feb-11
               AND
                  --commented by daniel katz and changed to sales account
                  /*                   msi_mas.cost_of_sales_account =
                                     gcc_mas.code_combination_id AND
                                     msi_org.cost_of_sales_account =
                                     gcc_org.code_combination_id AND
                  */
                   msi_mas.sales_account = gcc_mas.code_combination_id
               AND
                  --adjusted by daniel katz instead of interface line id to rowid
                   rila.rowid = cur_neg_resin_line.rowid;
          --3.3.3.  1 line with ?Unearned Revenue Resins? account = as mentioned in 2.2.1 above.
        -- Amount = -1* amount to adjust [i.e. the amount that was calculated in 3.2 above, but positive].
        --Percent = -1*Percent from 3.3.2 above.

        END LOOP;
      END IF;
    END LOOP;
  EXCEPTION
    WHEN OTHERS THEN

      fnd_file.put_line(fnd_file.log,
                        'HANDLE_CREDIT_RESIN_NEG_TRX: ' || SQLERRM);

      x_err_msg       := NULL;
      x_return_status := fnd_api.g_ret_sts_error;

  END handle_credit_resin_neg_trx;

  --------------------------------------------------------------------
  --  name:              handle_maintenance_trx_date
  --  create by:         ofer suad
  --  Revision:          1.0
  --  creation date:    31-May-2016
  --------------------------------------------------------------------
  --  purpose :   CHG0036536 -  Invoice date for Contract orders
  --------------------------------------------------------------------
  --  ver  date          name             desc
  --  ---  ------------  --------------   -------------------------------------------------------------
  --  1.0  31-May-2016   ofer suad        CHG0036536 -  Invoice date for Contract orders
  --                     L Sarangi        CHG0036536 - Code added to Package
  -- 1.1   02/10/2017    Yuval tal        CHG0041505 - modify Invoice Date for DE Rental Orders should be the date when it was interfaced to AR Interface.
  -- 1.2   09/01/2019    Roman W.         CHG0044863 - as result of moving to OKS module
  --                                                    - need to set contract lines rule start date for Initial
  --                                                         Order to ship date+ warranty period +60 days (profile)
  -- 1.3   11/07/2019    Roman W.         CHG0045869 - changes in invoice date for service contracts
  -----------------------------------------------------------------------------------------------------
  PROCEDURE handle_maintenance_trx_date(p_order_numbers rila_order_numbers_type,
                                        p_organization  NUMBER,
                                        p_return_status OUT VARCHAR2,
                                        p_err_msg       OUT VARCHAR2) IS

    -------------------------------
    --     Local Definition
    -------------------------------
    l_warranty_ship_days number;

    -------------------------------
    --       Code Section
    -------------------------------
  BEGIN

    FORALL idx IN 1 .. p_order_numbers.count

      UPDATE ra_interface_lines_all rla
         SET rla.trx_date = trunc(SYSDATE)
       WHERE rla.cust_trx_type_id IN
             (SELECT l.cust_trx_type_id
                FROM ra_cust_trx_types_all l
               WHERE l.attribute9 = 'Y')
         AND interface_line_attribute1 = to_char(p_order_numbers(idx))
         AND EXISTS (SELECT 1
                FROM ra_interface_lines_all rll
               WHERE rll.interface_line_attribute1 =
                     to_char(p_order_numbers(idx))
                    --  AND    rll.rule_start_date < trunc(SYSDATE) -- CHG0041505
                 AND (
                       (nvl(trunc(rll.rule_start_date),trunc(rll.sales_order_date)) < trunc(SYSDATE))
                       or
                       (last_day(nvl(trunc(rll.rule_start_date), trunc(rll.sales_order_date)))= trunc(last_day(sysdate)))
                     ) -- CHG0045869
              );

    if 'Y' = fnd_profile.value('XXAR_VSOE_WARRANTY_UPDATE_ENABLE_FLAG') then
      --CHG0044863

      l_warranty_ship_days := to_number(fnd_profile.value('XXAR_VSOE_WARRANTY_SHIP_DAYS')); --CHG0044863

      FORALL idx IN 1 .. p_order_numbers.count --CHG0044863
        UPDATE ra_interface_lines_all rla
           set rla.rule_start_date = rla.rule_start_date +
                                     l_warranty_ship_days,
               rla.Rule_End_Date   = rla.Rule_End_Date +
                                     l_warranty_ship_days
         where interface_line_attribute1 = to_char(p_order_numbers(idx))
           and exists
         (select 1
                  from oe_order_lines_all oll
                 where oll.line_id = rla.interface_line_attribute6
                   and oll.service_reference_type_code = 'ORDER');

    end if;

  END handle_maintenance_trx_date;
  --------------------------------------------------------------------
  --  name:              handle_invoice_conversion_date
  --  create by:         Lingaraj Sarangi
  --  Revision:          1.0
  --  creation date:    30-March-2017
  --------------------------------------------------------------------
  --  purpose :   CHG0040281 - Auto Invoice failing to import Service Contract Invoices if the Contract Start Date is a Future Date
  --------------------------------------------------------------------
  --  ver  date          name                 desc
  --  1.0  30.03.2017    Lingaraj Sarangi     CHG0040281 - Update Future Date to Today's Date
  ---------------------------------------------------------------------
  PROCEDURE handle_invoice_conversion_date(p_order_numbers rila_order_numbers_type) IS
  BEGIN
    FORALL idx IN 1 .. p_order_numbers.count
    /*If Service Contract Sales Orders having Future Contract Start Date,
                                                                    Invoice was failing due to missing conversion Rate.
                                                                    So Updating Interface Conversion date to system date for Future Servivce contact Invoices Only
                                                                  */
      UPDATE ra_interface_lines_all rla
         SET conversion_date = trunc(SYSDATE)
       WHERE 1 = 1
         AND batch_source_name = 'OBJ SERVICE'
         AND interface_line_attribute1 = to_char(p_order_numbers(idx))
         AND to_date(rla.attribute12, 'YYYY/MM/DD HH24:MI:SS') >
             trunc(SYSDATE);

  END handle_invoice_conversion_date;
  --------------------------------------------------------------------
  --  name:              handle_invoice_reason_code
  --  create by:         Lingaraj Sarangi
  --  Revision:          1.0
  --  creation date:    17-Sep-2018
  --------------------------------------------------------------------
  --  purpose :   CHG0043603 - REASON_CODE need to Remove for Defective SO Line types to create a single CM
  --------------------------------------------------------------------
  --  ver  date          name                 desc
  --  1.0  17-Sep-2018   Lingaraj Sarangi     CHG0043603 - REASON_CODE need to Remove for Defective SO Line types to create a single CM
  ---------------------------------------------------------------------
  PROCEDURE handle_invoice_reason_code(p_order_numbers rila_order_numbers_type) IS
  BEGIN
    /*
      1. AR Invoices created from SO type ?efective material replace, DE?will have Return Lines with multiple Return Reason Codes in the Order management system.
         Return Reason is a mandatory information for such order lines in the OM system. See attached screen shots
      2. The Return Reason information flows as it is in the AR system, after shipping process is complete.
      3. During AR Interface, Auto-Invoice Import program groups the Order Lines based on ?eturn Reason?and create multiple CM in AR.
      4. In order to avoid above and As part of solution, ?eturn Reason?information needs to be deleted from AR Interface to prevent multiple CM creation.
    */

    FORALL idx IN 1 .. p_order_numbers.count
      UPDATE ra_interface_lines_all rla
         SET reason_code = null
       WHERE 1 = 1
         AND interface_line_context = 'ORDER ENTRY'
         AND interface_line_attribute2 is not null
         AND interface_line_attribute2 in
             (select ffv.flex_value order_type_name
                from fnd_flex_values ffv, fnd_flex_value_sets ffvs
               where ffv.flex_value_set_id = ffvs.flex_value_set_id
                 and nvl(ffv.enabled_flag, 'N') = 'Y'
                 and ffvs.flex_value_set_name = 'XXAR_REASON_CODE_SO_TYPE')
         AND interface_line_attribute1 = to_char(p_order_numbers(idx));

    fnd_file.put_line(fnd_file.log,
                      'No Of records Reson code changed to Null :' ||
                      (sql%rowcount));
  END handle_invoice_reason_code;
  --------------------------------------------------------------------
  --  name:              handle_OKL_contracts_trx
  --  create by:         Ofer Suad
  --  Revision:          1.0
  --  creation date:     16/02/2014
  --------------------------------------------------------------------
  --  purpose :          Auto invoice modifications
  --                     update OKL contracts item,terms and transaction type
  -- 29-Jun-2014         CHG0032527 - Update transaction type and item for LEASEOP lines
  -- 27-Jan-2016         CHG0037525 - make payment terms null for Credit Memo transactions
  --------------------------------------------------------------------

  PROCEDURE handle_okl_contracts_trx(p_organization  IN NUMBER,
                                     x_return_status OUT VARCHAR2,
                                     x_err_msg       OUT VARCHAR2) IS
    CURSOR c_okl_lines IS
      SELECT DISTINCT --ril.orig_system_bill_address_id,
                      --ril.orig_system_ship_address_id,
                       ril.rowid,
                      pqv.value,
                      /* CHG0037525 Start - Dipta - Fetch transaction type*/
                      (SELECT rct.type
                         FROM ra_cust_trx_types_all rct
                        WHERE rct.cust_trx_type_id = ril.cust_trx_type_id) trans_type
      /* CHG0037525 End - Dipta - Fetch transaction type*/
        FROM ra_interface_lines_all ril,
             okc_k_headers_all_b    chr,
             okl_k_headers          khr,
             okl_products           pdt,
             okl_pdt_pqy_vals_uv    pqv
       WHERE chr.contract_number = ril.interface_line_attribute6
         AND chr.id = khr.id
         AND khr.pdt_id = pdt.id
         AND pqv.pdt_id = pdt.id
         AND pqv.name = 'LEASE'
            --AND pqv.VALUE = 'LEASEOP'
         AND ril.org_id = p_organization;

    l_terms_id NUMBER;
  BEGIN
    SELECT rct.default_term
      INTO l_terms_id
      FROM ra_cust_trx_types_all rct
     WHERE rct.cust_trx_type_id =
           fnd_profile.value('XXAR_OKL_LEASE_TRX_TYPE');

    FOR i IN c_okl_lines LOOP

      /*begin
        if i.orig_system_ship_address_id is not null then
          SELECT nvl(hcu_bill.payment_term_id,
                     nvl(hcu_ship.payment_term_id, hc.payment_term_id))
            into l_terms_id
            FROM hz_cust_site_uses_all  hcu_bill,
                 hz_cust_site_uses_all  hcu_ship,
                 hz_cust_acct_sites_all hcs,
                 hz_cust_accounts       hc
           where hcu_bill.cust_acct_site_id = i.orig_system_bill_address_id
             and hcs.cust_acct_site_id = hcu_bill.cust_acct_site_id
             and hcs.cust_account_id = hc.cust_account_id
             and hcu_ship.cust_acct_site_id(+) =
                 i.orig_system_ship_address_id
             and nvl(hcu_ship.site_use_code, 'SHIP_TO') = 'SHIP_TO'
             and hcu_bill.site_use_code = 'BILL_TO';
        else
          SELECT nvl(hcu_bill.payment_term_id, hc.payment_term_id)
            into l_terms_id
            FROM hz_cust_site_uses_all  hcu_bill,
                 hz_cust_acct_sites_all hcs,
                 hz_cust_accounts       hc
           where hcu_bill.cust_acct_site_id = i.orig_system_bill_address_id
             and hcs.cust_acct_site_id = hcu_bill.cust_acct_site_id
             and hcs.cust_account_id = hc.cust_account_id
             and hcu_bill.site_use_code = 'BILL_TO';
        end if;
      exception
        when no_data_found then
           l_terms_id := null;

      end;*/
      --  if l_terms_id is null then

      --  end if;

      IF i.value = 'LEASEOP' THEN
        UPDATE ra_interface_lines_all ril
           SET ril.term_id           = l_terms_id,
               ril.cust_trx_type_id  = fnd_profile.value('XXAR_OKL_LEASE_TRX_TYPE'),
               ril.inventory_item_id = fnd_profile.value('XXAR_OKL_LEASE_ITEM'),
               ril.uom_code          = nvl(ril.uom_code, 'EA')
         WHERE ril.rowid = i.rowid;
      ELSE
        UPDATE ra_interface_lines_all ril
           SET ril.term_id = l_terms_id /*,
                                                                                                                                                                                                                                                                ril.cust_trx_type_id=fnd_profile.VALUE('XXAR_OKL_LEASE_TRX_TYPE'),
                                                                                                                                                                                                                                                                ril.inventory_item_id=fnd_profile.VALUE('XXAR_OKL_LEASE_ITEM')*/
         WHERE ril.rowid = i.rowid;
      END IF;

      IF i.trans_type = 'CM' THEN
        -- CHG0037525 Start - Dipta - Update Payment term to null for Credit Memo transactions
        UPDATE ra_interface_lines_all ril
           SET ril.term_id = NULL
         WHERE ril.rowid = i.rowid;
      END IF; -- CHG0037525 End - Dipta - Update Payment term to null for Credit Memo transactions
    END LOOP;
  EXCEPTION
    WHEN OTHERS THEN

      fnd_file.put_line(fnd_file.output,
                        'Error while updating OKL Contracts Lines');
      fnd_file.put_line(fnd_file.log,
                        'Error while updating OKL Contracts Lines');

      --added by daniel katz
      --   x_return_status := fnd_api.g_ret_sts_error;
      RETURN;

  END handle_okl_contracts_trx;
  --------------------------------------------------------------------
  --  name:              is_service_item
  --  create by:         Ofer Suad
  --  Revision:          1.0
  --  creation date:     24/07/2012
  --------------------------------------------------------------------
  --  purpose :          Auto invoice modifications
  --                     Check if item is Service or SYSS Service

  -- 1.1 30.05.2013 Adi Safin - Change UOM class from Period to Time
  --     17.02.2015 CHG0034523-  Add Activity Analysis logic
  --------------------------------------------------------------------
  FUNCTION is_service_item(p_inventory_item_id NUMBER) RETURN NUMBER IS
    l_cnt NUMBER;
  BEGIN
    l_cnt := 0;
    BEGIN
      SELECT 1
        INTO l_cnt
        FROM mtl_system_items_b msib
       WHERE msib.inventory_item_id = p_inventory_item_id
         AND msib.contract_item_type_code = 'SERVICE'
         AND msib.organization_id =
             xxinv_utils_pkg.get_master_organization_id;
    EXCEPTION
      WHEN no_data_found THEN
        BEGIN
          SELECT 1
            INTO l_cnt
            FROM mtl_item_categories_v   mic,
                 mtl_system_items_b      msib,
                 mtl_categories_b        mcb,
                 mtl_units_of_measure_tl mut
           WHERE mic.inventory_item_id = msib.inventory_item_id
             AND msib.organization_id =
                 xxinv_utils_pkg.get_master_organization_id
             AND mic.organization_id =
                 xxinv_utils_pkg.get_master_organization_id
             AND mcb.category_id = mic.category_id
                -- and mcb.attribute8 = 'FDM' -- Ofer Suad - Japan no need for FDM
             AND mic.category_set_name = 'Main Category Set'
             AND mic.segment1 = 'Maintenance'
             AND mut.language = 'US'
             AND mut.uom_class = 'Time' -- 1.1 30.05.2013 Adi Safin
             AND msib.primary_uom_code = mut.uom_code
             AND mic.inventory_item_id = p_inventory_item_id;

        EXCEPTION
          WHEN no_data_found THEN
            --  CHG0034523-  Add Activity Analysis logic - new service contract  items are set
            --               according to this logic
            BEGIN

              SELECT 1
                INTO l_cnt
                FROM mtl_item_categories_v mic_sc, mtl_system_items_b msi --,
              --  xxcs_items_printers_v pr
               WHERE mic_sc.inventory_item_id = msi.inventory_item_id
                 AND mic_sc.organization_id = msi.organization_id
                 AND msi.inventory_item_id = p_inventory_item_id
                 AND msi.organization_id =
                     xxinv_utils_pkg.get_master_organization_id
                 AND mic_sc.category_set_name = 'Activity Analysis'
                 AND mic_sc.segment1 = 'Contracts'
                 AND msi.coverage_schedule_id IS NULL;
            EXCEPTION
              WHEN no_data_found THEN
                l_cnt := 0;
            END;
        END;
    END;
    RETURN l_cnt;
  END is_service_item;

  --------------------------------------------------------------------
  --  name:              handle_contracts_from_om_trx
  --  create by:         Ofer Suad
  --  Revision:          1.0
  --  creation date:     15/01/2012
  --------------------------------------------------------------------
  --  purpose :          Auto invoice modifications
  --                     Update accounting rule and DE tax code for Service contracts from OM
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  15/01/2012    Ofer Suad         initial build
  --  1.1  30/07/2015    Dalit A. Raviv    CHG0035457 - XXAutoinvoice program for Service credits
  --                                       add update of rla.invoicing_rule_id
  --------------------------------------------------------------------
  PROCEDURE handle_contracts_from_om_trx(p_order_numbers rila_order_numbers_type,
                                         p_organization  NUMBER,
                                         l_return_status OUT VARCHAR2,
                                         l_err_msg       OUT VARCHAR2) IS
  BEGIN
    -- fnd_file.PUT_LINE(fnd_file.LOG, 'in service ');
    FORALL idx IN 1 .. p_order_numbers.count
      UPDATE ra_interface_lines_all rla
         SET rla.accounting_rule_id = fnd_profile.value('XXAR_CONTRACTS_ACCT_RULE_ID'),
             rla.tax_code           = decode(p_organization,
                                             96,
                                             'DE SERVICE',
                                             rla.tax_code),
             rla.invoicing_rule_id =
             (CASE (SELECT t.type
                  FROM ra_cust_trx_types_all t
                 WHERE t.cust_trx_type_id = rla.cust_trx_type_id)
               WHEN 'CM' THEN
                -2
               ELSE
                rla.invoicing_rule_id
             END)
       WHERE interface_line_attribute1 = to_char(p_order_numbers(idx))
         AND rla.interface_line_context = 'ORDER ENTRY'
         AND is_service_item(rla.inventory_item_id) = 1;

  END handle_contracts_from_om_trx;

  --------------------------------------------------------------------
  --  name:              get_acc_resin_credit_avg_bal
  --  create by:         daniel katz
  --  Revision:          1.0
  --  creation date:     XX/XX/2011
  --------------------------------------------------------------------
  --  purpose :          retrieve accumulated averagee discount multiplied by the open resin credit amount
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  XX/XX/2011    daniel katz       initial build
  --------------------------------------------------------------------
  FUNCTION get_acc_resin_credit_avg_bal(p_cust_acct_id  NUMBER,
                                        p_org_id        NUMBER,
                                        p_currency      VARCHAR2,
                                        p_pos_amount    NUMBER,
                                        x_return_status OUT VARCHAR2)
    RETURN NUMBER IS

    l_acc_avg_balance    NUMBER := 0;
    l_amount             NUMBER := p_pos_amount;
    l_acc_pos_amount     NUMBER := 0;
    t_positive_amounts   rila_order_numbers_type;
    t_positive_discounts rila_order_numbers_type;

  BEGIN
    x_return_status := fnd_api.g_ret_sts_error;

    /* SELECT rctl.unit_standard_price, rctl.attribute10 BULK COLLECT
        INTO t_positive_amounts, t_positive_discounts
        FROM ra_customer_trx_all       rct,
             ra_customer_trx_lines_all rctl,
             mtl_system_items_b        msi
       WHERE rct.customer_trx_id = rctl.customer_trx_id
         AND msi.inventory_item_id = rctl.inventory_item_id
         AND msi.organization_id = xxinv_utils_pkg.get_master_organization_id
         AND rct.bill_to_customer_id = p_cust_acct_id
         AND rct.org_id = p_org_id
         AND rct.invoice_currency_code = p_currency
         AND rctl.attribute10 IS NOT NULL
         AND rctl.unit_selling_price >= 0
         AND msi.item_type = fnd_profile.value('XXAR_CREDIT_RESIN_ITEM_TYPE')
       ORDER BY rctl.sales_order_date, rctl.sales_order;
    */
    SELECT rctl.unit_standard_price, rctl.attribute10
      BULK COLLECT
      INTO t_positive_amounts, t_positive_discounts
      FROM ra_customer_trx_all       rct,
           ra_customer_trx_lines_all rctl,
           mtl_system_items_b        msi,
           oe_order_lines_all        oel,
           oe_order_headers_all      oh,
           hz_cust_site_uses_all     hcsu,
           hz_cust_acct_sites_all    hcas
     WHERE rct.customer_trx_id = rctl.customer_trx_id
       AND msi.inventory_item_id = rctl.inventory_item_id
       AND msi.organization_id = xxinv_utils_pkg.get_master_organization_id
       AND rctl.interface_line_attribute6 = to_char(oel.line_id)
       AND oh.header_id = oel.header_id
       AND decode(oh.attribute8,
                  'SHIP_TO',
                  oel.ship_to_org_id,
                  oel.invoice_to_org_id) = hcsu.site_use_id
       AND hcas.cust_acct_site_id = hcsu.cust_acct_site_id
       AND hcas.cust_account_id = p_cust_acct_id
          --AND rct.bill_to_customer_id = 1668040
       AND decode(rct.org_id, 89, 737, rct.org_id) = p_org_id --   15/10/2014         ofer Suad       Fix org Id CR-1122
       AND rct.invoice_currency_code = p_currency
       AND rctl.attribute10 IS NOT NULL
       AND rctl.unit_selling_price >= 0
       AND msi.item_type = fnd_profile.value('XXAR_CREDIT_RESIN_ITEM_TYPE')
     ORDER BY rctl.sales_order_date, rctl.sales_order;

    FOR i IN 1 .. t_positive_amounts.count LOOP
      l_acc_pos_amount := l_acc_pos_amount + t_positive_amounts(i);
      IF p_pos_amount <= l_acc_pos_amount THEN
        l_acc_avg_balance := l_acc_avg_balance +
                             l_amount * t_positive_discounts(i) / 100;
        x_return_status   := fnd_api.g_ret_sts_success;
        EXIT;
      ELSE
        l_acc_avg_balance := l_acc_avg_balance +
                             t_positive_amounts(i) *
                             t_positive_discounts(i) / 100;
        l_amount          := l_amount - t_positive_amounts(i);
      END IF;
    END LOOP;

    RETURN l_acc_avg_balance;

  EXCEPTION
    WHEN no_data_found THEN
      x_return_status := fnd_api.g_ret_sts_error;
      RETURN 0;

  END get_acc_resin_credit_avg_bal;
  ---------------------------------------------------------------------------------------
  -- Ver      When         Who           Description
  -- -------  -----------  ------------  ------------------------------------------------
  -- 1.0      03/12/2019   Roman W.      CHG0044816
  ---------------------------------------------------------------------------------------
  PROCEDURE build_sql(p_num_of_instances          IN VARCHAR2,
                      p_organization              NUMBER,
                      p_batch_source_id           IN ra_batch_sources.batch_source_id%TYPE,
                      p_batch_source_name         IN VARCHAR2,
                      p_default_date              IN VARCHAR2 DEFAULT NULL,
                      p_trans_flexfield           IN VARCHAR2 DEFAULT NULL,
                      p_trx_type_id               IN ra_cust_trx_types.cust_trx_type_id%TYPE DEFAULT NULL,
                      p_low_bill_to_cust_num      IN hz_cust_accounts.account_number%TYPE DEFAULT NULL,
                      p_high_bill_to_cust_num     IN hz_cust_accounts.account_number%TYPE DEFAULT NULL,
                      p_low_bill_to_cust_name     IN hz_parties.party_name%TYPE DEFAULT NULL,
                      p_high_bill_to_cust_name    IN hz_parties.party_name%TYPE DEFAULT NULL,
                      p_low_gl_date               IN VARCHAR2 DEFAULT NULL,
                      p_high_gl_date              IN VARCHAR2 DEFAULT NULL,
                      p_low_ship_date             IN VARCHAR2 DEFAULT NULL,
                      p_high_ship_date            IN VARCHAR2 DEFAULT NULL,
                      p_low_trans_number          IN ra_interface_lines.trx_number%TYPE DEFAULT NULL,
                      p_high_trans_number         IN ra_interface_lines.trx_number%TYPE DEFAULT NULL,
                      p_low_sales_order_num       IN ra_interface_lines.sales_order%TYPE DEFAULT NULL,
                      p_high_sales_order_num      IN ra_interface_lines.sales_order%TYPE DEFAULT NULL,
                      p_low_invoice_date          IN VARCHAR2 DEFAULT NULL,
                      p_high_invoice_date         IN VARCHAR2 DEFAULT NULL,
                      p_low_ship_to_cust_num      IN hz_cust_accounts.account_number%TYPE DEFAULT NULL,
                      p_high_ship_to_cust_num     IN hz_cust_accounts.account_number%TYPE DEFAULT NULL,
                      p_low_ship_to_cust_name     IN hz_parties.party_name%TYPE,
                      p_high_ship_to_cust_name    IN hz_parties.party_name%TYPE,
                      p_base_due_date_on_trx_date IN fnd_lookups.meaning%TYPE,
                      p_due_date_adj_days         IN NUMBER,
                      p_query_clause              OUT VARCHAR2) IS

    l_query_clause VARCHAR2(4000);

  BEGIN

    l_query_clause := 'SELECT header_id, order_number, oh.transactional_curr_code  ' ||
                      chr(10) || 'FROM oe_order_headers_all oh ' || chr(10);

    fnd_file.put_line(fnd_file.log, 'Main Query:');
    fnd_file.put_line(fnd_file.log, '---------------------------------');
    fnd_file.put_line(fnd_file.log, l_query_clause);

    l_query_clause := l_query_clause || 'WHERE EXISTS(SELECT 1  ' ||
                     --commented by daniel katz and added oe order lines all table and additional conditions
                     --to retrieve by order header id and not order number that is not unique
                     /*                        chr(10) || 'FROM ra_interface_lines_all rila  ' ||
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        chr(10) ||
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        'WHERE rila.interface_line_attribute1 = oh.order_number AND  ' ||
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        chr(10) ||
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                */
                      chr(10) ||
                      'FROM ra_interface_lines_all rila, oe_order_lines_all ol  ' ||
                      chr(10) ||
                      'WHERE rila.interface_line_attribute6 = ol.line_id AND  ' ||
                      chr(10) || 'ol.header_id = oh.header_id AND  ' ||
                      chr(10) ||
                      'rila.interface_line_attribute1 = to_char(oh.order_number) AND  ' ||
                      chr(10) ||
                      'rila.interface_line_context in (''ORDER ENTRY'',''INTERCOMPANY'') AND  ' ||

                      chr(10) ||
                      'batch_source_name = :p_batch_source_name AND  ' ||
                      chr(10) || 'rila.org_id = :p_organization AND ' ||
                      chr(10) ||
                      'rila.cust_trx_type_id = nvl(:p_trx_type_id, rila.cust_trx_type_id) AND ' ||
                     --commented by daniel katz (there is no rctt table)
                     --                        chr(10) || 'rila.org_id = rctt.org_id AND ' ||
                      chr(10) ||
                      'rila.interface_line_attribute1 BETWEEN nvl(:p_low_sales_order_num, interface_line_attribute1) AND ' ||
                      chr(10) ||
                      'nvl(:p_high_sales_order_num, interface_line_attribute1) AND ' ||
                      chr(10) || 'rila.line_type = ''LINE''  ' || chr(10);

    fnd_file.put_line(fnd_file.log, 'WHERE EXISTS(SELECT 1  ');
    --commented and added by daniel katz oe order lines all table and additional conditions as above
    /*      fnd_file.put_line(fnd_file.output,
                            'FROM ra_interface_lines_all rila ');
          fnd_file.put_line(fnd_file.output,
                            'WHERE rila.interface_line_attribute1 = oh.order_number AND  ');
    */
    fnd_file.put_line(fnd_file.log,
                      'FROM ra_interface_lines_all rila, oe_order_lines_all ol ');
    fnd_file.put_line(fnd_file.log,
                      'WHERE rila.interface_line_attribute6 = ol.line_id AND  ');
    fnd_file.put_line(fnd_file.log, 'ol.header_id = oh.header_id AND  ');
    fnd_file.put_line(fnd_file.log,
                      'rila.interface_line_attribute1 = to_char(oh.order_number) AND  ');
    fnd_file.put_line(fnd_file.log,
                      'rila.interface_line_context in (''ORDER ENTRY'',''INTERCOMPANY'') AND  ');

    fnd_file.put_line(fnd_file.log,
                      'batch_source_name = ''' || p_batch_source_name ||
                      ''' AND  ');
    fnd_file.put_line(fnd_file.log,
                      'rila.org_id = ' || p_organization || ' AND ');
    fnd_file.put_line(fnd_file.log,
                      'rila.cust_trx_type_id = nvl(''' || p_trx_type_id ||
                      ''', rila.cust_trx_type_id) AND ');
    --commented by daniel katz (there is no rctt table)
    --      fnd_file.put_line(fnd_file.output, 'rila.org_id = rctt.org_id AND ');
    fnd_file.put_line(fnd_file.log,
                      'rila.interface_line_attribute1 BETWEEN nvl(' ||
                      p_low_sales_order_num ||
                      ', interface_line_attribute1) AND ');
    fnd_file.put_line(fnd_file.log,
                      'nvl(' || p_high_sales_order_num ||
                      ', interface_line_attribute1) AND ');
    fnd_file.put_line(fnd_file.log, 'rila.line_type = ''LINE''  ');

    IF p_low_ship_date IS NOT NULL AND p_high_ship_date IS NOT NULL THEN

      l_query_clause := l_query_clause ||
                        'AND trunc(rila.ship_date_actual) BETWEEN to_date(''' ||
                        p_low_ship_date ||
                        ''', ''YYYY/MM/DD HH24:MI:SS'') AND ' || chr(10) ||
                        'to_date(''' || p_high_ship_date ||
                        ''', ''YYYY/MM/DD HH24:MI:SS'') ' || chr(10);

      fnd_file.put_line(fnd_file.log,
                        'AND trunc(rila.ship_date_actual) BETWEEN to_date(''' ||
                        p_low_ship_date ||
                        ''', ''YYYY/MM/DD HH24:MI:SS'') AND ');
      fnd_file.put_line(fnd_file.log,
                        'to_date(''' || p_high_ship_date ||
                        ''', ''YYYY/MM/DD HH24:MI:SS'') ');

    ELSIF p_low_ship_date IS NOT NULL THEN

      l_query_clause := l_query_clause ||
                        'AND trunc(rila.ship_date_actual) >= to_date(''' ||
                        p_low_ship_date || ''', ''YYYY/MM/DD HH24:MI:SS'')' ||
                        chr(10);
      fnd_file.put_line(fnd_file.log,
                        'AND trunc(rila.ship_date_actual) >= to_date(''' ||
                        p_low_ship_date || ''', ''YYYY/MM/DD HH24:MI:SS'')');

    ELSIF p_high_ship_date IS NOT NULL THEN

      l_query_clause := l_query_clause ||
                        'AND trunc(rila.ship_date_actual) <= to_date(''' ||
                        p_high_ship_date ||
                        ''', ''YYYY/MM/DD HH24:MI:SS'')' || chr(10);
      fnd_file.put_line(fnd_file.log,
                        'AND trunc(rila.ship_date_actual) <= to_date(''' ||
                        p_high_ship_date ||
                        ''', ''YYYY/MM/DD HH24:MI:SS'')');

    END IF;

    IF p_low_bill_to_cust_num IS NOT NULL OR
       p_high_bill_to_cust_num IS NOT NULL OR
       p_low_bill_to_cust_name IS NOT NULL OR
       p_high_bill_to_cust_name IS NOT NULL THEN

      l_query_clause := l_query_clause ||
                        'AND orig_system_bill_customer_id IN (SELECT cust_acct.cust_account_id ' ||
                        chr(10) ||
                        '                                       FROM hz_cust_accounts cust_acct, hz_parties party ' ||
                        chr(10) ||
                        '                                      WHERE cust_acct.party_id = party.party_id AND ' ||
                        chr(10) ||
                        '                                            cust_acct.account_number >= nvl(''' ||
                        p_low_bill_to_cust_num ||
                       --commented by daniel katz and replaced by new line below
                       --                           ''', orig_system_bill_customer_id) AND  ' ||
                        ''', cust_acct.account_number) AND  ' || chr(10) ||
                        '                                            cust_acct.account_number <= nvl(''' ||
                        p_high_bill_to_cust_num ||
                       --commented by daniel katz and replaced by new line below
                       --                           ''', orig_system_bill_customer_id) AND  ' ||
                        ''', cust_acct.account_number) AND  ' || chr(10) ||
                        '                                            party.party_name >= nvl(''' ||
                        p_low_bill_to_cust_name ||
                        ''', party.party_name) AND  ' || chr(10) ||
                        '                                            party.party_name <= nvl(''' ||
                        p_high_bill_to_cust_name ||
                        ''', party.party_name)) ' || chr(10);

      fnd_file.put_line(fnd_file.log,
                        'AND orig_system_bill_customer_id IN (SELECT cust_acct.cust_account_id ');
      fnd_file.put_line(fnd_file.log,
                        '                                       FROM hz_cust_accounts cust_acct, hz_parties party ');
      fnd_file.put_line(fnd_file.log,
                        '                                      WHERE cust_acct.party_id = party.party_id AND ');
      fnd_file.put_line(fnd_file.log,
                        '                                            cust_acct.account_number >= nvl(''' ||
                         p_low_bill_to_cust_num ||
                        --commented by daniel katz and replaced by new line below
                        --                           ''', orig_system_bill_customer_id) AND  ');
                         ''', cust_acct.account_number) AND  ');
      fnd_file.put_line(fnd_file.log,
                        '                                            cust_acct.account_number <= nvl(''' ||
                         p_high_bill_to_cust_num ||
                        --commented by daniel katz and replaced by new line below
                        --                           ''', orig_system_bill_customer_id) AND  ');
                         ''', cust_acct.account_number) AND  ');
      fnd_file.put_line(fnd_file.log,
                        '                                            party.party_name >= nvl(''' ||
                        p_low_bill_to_cust_name ||
                        ''', party.party_name) AND  ');
      fnd_file.put_line(fnd_file.log,
                        '                                            party.party_name <= nvl(''' ||
                        p_high_bill_to_cust_name ||
                        ''', party.party_name)) ');
    END IF;

    IF p_low_ship_to_cust_num IS NOT NULL OR
       p_high_ship_to_cust_num IS NOT NULL OR
      --added by daniel katz 2 conditions below to be the same as for the bill to conditions above
       p_low_ship_to_cust_name IS NOT NULL OR
       p_high_ship_to_cust_name IS NOT NULL THEN

      l_query_clause := l_query_clause ||
                        'AND orig_system_ship_customer_id IN (SELECT cust_acct.cust_account_id ' ||
                        chr(10) ||
                        '                                       FROM hz_cust_accounts cust_acct, hz_parties party ' ||
                        chr(10) ||
                        '                                      WHERE cust_acct.party_id = party.party_id AND ' ||
                        chr(10) ||
                        '                                            cust_acct.account_number >= nvl(''' ||
                        p_low_ship_to_cust_num ||
                       --commented by daniel katz and replaced by new line below
                       --                           ''', orig_system_ship_customer_id) AND  ' ||
                        ''', cust_acct.account_number) AND  ' || chr(10) ||
                        '                                            cust_acct.account_number <= nvl(''' ||
                        p_high_ship_to_cust_num ||
                       --commented by daniel katz and replaced by new line below
                       --                           ''', orig_system_ship_customer_id)) ' || chr(10);
                        ''', cust_acct.account_number)) ' || --chr(10);

                       --added by daniel katz following block (for ship to customer name and for view output all the sql):
                       -----------------------------------------------------------------------------------------------------------
                        chr(10) ||
                        '                                            party.party_name >= nvl(''' ||
                        p_low_ship_to_cust_name ||
                        ''', party.party_name) AND  ' || chr(10) ||
                        '                                            party.party_name <= nvl(''' ||
                        p_high_ship_to_cust_name ||
                        ''', party.party_name)) ' || chr(10);

      fnd_file.put_line(fnd_file.log,
                        'AND orig_system_ship_customer_id IN (SELECT cust_acct.cust_account_id ');
      fnd_file.put_line(fnd_file.log,
                        '                                       FROM hz_cust_accounts cust_acct, hz_parties party ');
      fnd_file.put_line(fnd_file.log,
                        '                                      WHERE cust_acct.party_id = party.party_id AND ');
      fnd_file.put_line(fnd_file.log,
                        '                                            cust_acct.account_number >= nvl(''' ||
                        p_low_ship_to_cust_num ||
                        ''', cust_acct.account_number) AND  ');
      fnd_file.put_line(fnd_file.log,
                        '                                            cust_acct.account_number <= nvl(''' ||
                        p_high_ship_to_cust_num ||

                        ''', cust_acct.account_number) AND  ');
      fnd_file.put_line(fnd_file.log,
                        '                                            party.party_name >= nvl(''' ||
                        p_low_ship_to_cust_name ||
                        ''', party.party_name) AND  ');
      fnd_file.put_line(fnd_file.log,
                        '                                            party.party_name <= nvl(''' ||
                        p_high_ship_to_cust_name ||
                        ''', party.party_name)) ');
      -----------------------------------------------------------------------------------------------------------

    END IF;

    /* Ofer Suad  02-06-2013 Japan restriction - must be specific so for Standrd and Trade in */

    /* Rem By Roman W. 03/12/2019 CHG0044816
    IF xxhz_util.get_operating_unit_name(p_organization) = 'OBJET JP (OU)' AND
       (p_low_sales_order_num IS NULL OR p_high_sales_order_num IS NULL) THEN
      l_query_clause := l_query_clause || chr(10) ||
    'and not exists (SELECT 1
          FROM ra_cust_trx_types_all rctt
         WHERE rctt.cust_trx_type_id = rila.cust_trx_type_id
           AND nvl(rctt.attribute5, ''N'') = ''Y''
           AND rctt.org_id = rila.org_id)';
      fnd_file.put_line(fnd_file.log,
    'and not exists (SELECT 1
          FROM ra_cust_trx_types_all rctt
         WHERE rctt.cust_trx_type_id = rila.cust_trx_type_id
           AND nvl(rctt.attribute5, ''N'') = ''Y''
           AND rctt.org_id = rila.org_id)');
    END IF;
    */

    l_query_clause := l_query_clause || ')';
    /* End Japan restriction  */

    l_query_clause := l_query_clause || ' ORDER BY header_id';
    fnd_file.put_line(fnd_file.log, ')');
    fnd_file.put_line(fnd_file.log, ' ORDER BY header_id');
    fnd_file.put_line(fnd_file.log, '---------------------------------');

    --added by daniel katz (value for output paramter)
    p_query_clause := l_query_clause;

  END build_sql;

  --------------------------------------------------------------------
  --  name:              handle_contracts_from_om_trx
  --  create by:         Daniel Katz
  --  Revision:          1.0
  --  creation date:     xx/xx/2011
  --------------------------------------------------------------------
  --  purpose :          Negative Resin credits
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  xx/xx/2011    Daniel Katz       initial build
  --------------------------------------------------------------------
  PROCEDURE build_sql_resin_credit(p_num_of_instances          IN VARCHAR2,
                                   p_organization              NUMBER,
                                   p_batch_source_id           IN ra_batch_sources.batch_source_id%TYPE,
                                   p_batch_source_name         IN VARCHAR2,
                                   p_default_date              IN VARCHAR2 DEFAULT NULL,
                                   p_trans_flexfield           IN VARCHAR2 DEFAULT NULL,
                                   p_trx_type_id               IN ra_cust_trx_types.cust_trx_type_id%TYPE DEFAULT NULL,
                                   p_low_bill_to_cust_num      IN hz_cust_accounts.account_number%TYPE DEFAULT NULL,
                                   p_high_bill_to_cust_num     IN hz_cust_accounts.account_number%TYPE DEFAULT NULL,
                                   p_low_bill_to_cust_name     IN hz_parties.party_name%TYPE DEFAULT NULL,
                                   p_high_bill_to_cust_name    IN hz_parties.party_name%TYPE DEFAULT NULL,
                                   p_low_gl_date               IN VARCHAR2 DEFAULT NULL,
                                   p_high_gl_date              IN VARCHAR2 DEFAULT NULL,
                                   p_low_ship_date             IN VARCHAR2 DEFAULT NULL,
                                   p_high_ship_date            IN VARCHAR2 DEFAULT NULL,
                                   p_low_trans_number          IN ra_interface_lines.trx_number%TYPE DEFAULT NULL,
                                   p_high_trans_number         IN ra_interface_lines.trx_number%TYPE DEFAULT NULL,
                                   p_low_sales_order_num       IN ra_interface_lines.sales_order%TYPE DEFAULT NULL,
                                   p_high_sales_order_num      IN ra_interface_lines.sales_order%TYPE DEFAULT NULL,
                                   p_low_invoice_date          IN VARCHAR2 DEFAULT NULL,
                                   p_high_invoice_date         IN VARCHAR2 DEFAULT NULL,
                                   p_low_ship_to_cust_num      IN hz_cust_accounts.account_number%TYPE DEFAULT NULL,
                                   p_high_ship_to_cust_num     IN hz_cust_accounts.account_number%TYPE DEFAULT NULL,
                                   p_low_ship_to_cust_name     IN hz_parties.party_name%TYPE,
                                   p_high_ship_to_cust_name    IN hz_parties.party_name%TYPE,
                                   p_base_due_date_on_trx_date IN fnd_lookups.meaning%TYPE,
                                   p_due_date_adj_days         IN NUMBER,
                                   p_query_clause              OUT VARCHAR2) IS

    l_query_clause VARCHAR2(4000);

  BEGIN

    l_query_clause := 'SELECT distinct rila.orig_system_bill_customer_id, rila.currency_code  ' ||
                      chr(10) ||
                      'FROM ra_interface_lines_all rila, oe_order_lines_all ol, oe_order_headers_all oh, ' ||
                      chr(10) ||
                      'mtl_system_items_b msi, ra_cust_trx_types_all rctt ' ||
                      chr(10);

    fnd_file.put_line(fnd_file.log,
                      'Query for negative Resin Credit lines:');
    fnd_file.put_line(fnd_file.log, '---------------------------------');
    fnd_file.put_line(fnd_file.log, l_query_clause);

    l_query_clause := l_query_clause ||
                      'WHERE rila.interface_line_attribute6 = ol.line_id AND  ' ||
                      chr(10) || 'ol.header_id = oh.header_id AND  ' ||
                      chr(10) ||
                      'rila.interface_line_attribute1 = to_char(oh.order_number) AND  ' ||
                      chr(10) ||
                      'rila.interface_line_context in (''ORDER ENTRY'',''INTERCOMPANY'') AND  ' ||
                      chr(10) ||
                      'rila.cust_trx_type_id = rctt.cust_trx_type_id and ' ||
                      chr(10) || 'rila.org_id = rctt.org_id and ' ||
                     -- chr(10) || 'nvl(rctt.attribute5,''N'') = ''N'' and ' ||--  CHG0032677?verage discount for all orders type
                      chr(10) ||
                      'msi.inventory_item_id = rila.inventory_item_id and ' ||
                      chr(10) ||
                      'msi.organization_id = xxinv_utils_pkg.get_master_organization_id and ' ||
                      chr(10) ||
                      'msi.item_type = fnd_profile.VALUE(''XXAR_CREDIT_RESIN_ITEM_TYPE'') and ' ||
                      chr(10) || 'rila.unit_selling_price < 0 and ' ||
                      chr(10) ||
                      'batch_source_name = :p_batch_source_name AND  ' ||
                      chr(10) || 'rila.org_id = :p_organization AND ' ||
                      chr(10) ||
                      'rila.cust_trx_type_id = nvl(:p_trx_type_id, rila.cust_trx_type_id) AND ' ||
                      chr(10) ||
                      'rila.interface_line_attribute1 BETWEEN nvl(:p_low_sales_order_num, interface_line_attribute1) AND ' ||
                      chr(10) ||
                      'nvl(:p_high_sales_order_num, interface_line_attribute1) AND ' ||
                      chr(10) || 'rila.line_type = ''LINE''  ' || chr(10);

    fnd_file.put_line(fnd_file.log,
                      'WHERE rila.interface_line_attribute6 = ol.line_id AND  ');
    fnd_file.put_line(fnd_file.log, 'ol.header_id = oh.header_id AND  ');
    fnd_file.put_line(fnd_file.log,
                      'rila.interface_line_attribute1 = to_char(oh.order_number) AND  ');
    fnd_file.put_line(fnd_file.log,
                      'rila.interface_line_context in (''ORDER ENTRY'',''INTERCOMPANY'') AND  ');
    fnd_file.put_line(fnd_file.log,
                      'rila.cust_trx_type_id = rctt.cust_trx_type_id and ');
    fnd_file.put_line(fnd_file.log, 'rila.org_id = rctt.org_id and ');
    -- fnd_file.put_line(fnd_file.log, 'nvl(rctt.attribute5,''N'') = ''N'' and '); --CHG0032677?verage discount for all orders type
    fnd_file.put_line(fnd_file.log,
                      'msi.inventory_item_id = rila.inventory_item_id and ');
    fnd_file.put_line(fnd_file.log,
                      'msi.organization_id = xxinv_utils_pkg.get_master_organization_id and ');
    fnd_file.put_line(fnd_file.log,
                      'msi.item_type = fnd_profile.VALUE(''XXAR_CREDIT_RESIN_ITEM_TYPE'') and ');
    fnd_file.put_line(fnd_file.log, 'rila.unit_selling_price < 0 and ');
    fnd_file.put_line(fnd_file.log,
                      'batch_source_name = ''' || p_batch_source_name ||
                      ''' AND  ');
    fnd_file.put_line(fnd_file.log,
                      'rila.org_id = ' || p_organization || ' AND ');
    fnd_file.put_line(fnd_file.log,
                      'rila.cust_trx_type_id = nvl(''' || p_trx_type_id ||
                      ''', rila.cust_trx_type_id) AND ');
    fnd_file.put_line(fnd_file.log,
                      'rila.interface_line_attribute1 BETWEEN nvl(' ||
                      p_low_sales_order_num ||
                      ', interface_line_attribute1) AND ');
    fnd_file.put_line(fnd_file.log,
                      'nvl(' || p_high_sales_order_num ||
                      ', interface_line_attribute1) AND ');
    fnd_file.put_line(fnd_file.log, 'rila.line_type = ''LINE''  ');

    IF p_low_ship_date IS NOT NULL AND p_high_ship_date IS NOT NULL THEN

      l_query_clause := l_query_clause ||
                        'AND trunc(rila.ship_date_actual) BETWEEN to_date(''' ||
                        p_low_ship_date ||
                        ''', ''YYYY/MM/DD HH24:MI:SS'') AND ' || chr(10) ||
                        'to_date(''' || p_high_ship_date ||
                        ''', ''YYYY/MM/DD HH24:MI:SS'') ' || chr(10);

      fnd_file.put_line(fnd_file.log,
                        'AND trunc(rila.ship_date_actual) BETWEEN to_date(''' ||
                        p_low_ship_date ||
                        ''', ''YYYY/MM/DD HH24:MI:SS'') AND ');
      fnd_file.put_line(fnd_file.log,
                        'to_date(''' || p_high_ship_date ||
                        ''', ''YYYY/MM/DD HH24:MI:SS'') ');

    ELSIF p_low_ship_date IS NOT NULL THEN

      l_query_clause := l_query_clause ||
                        'AND trunc(rila.ship_date_actual) >= to_date(''' ||
                        p_low_ship_date || ''', ''YYYY/MM/DD HH24:MI:SS'')' ||
                        chr(10);
      fnd_file.put_line(fnd_file.log,
                        'AND trunc(rila.ship_date_actual) >= to_date(''' ||
                        p_low_ship_date || ''', ''YYYY/MM/DD HH24:MI:SS'')');

    ELSIF p_high_ship_date IS NOT NULL THEN

      l_query_clause := l_query_clause ||
                        'AND trunc(rila.ship_date_actual) <= to_date(''' ||
                        p_high_ship_date ||
                        ''', ''YYYY/MM/DD HH24:MI:SS'')' || chr(10);
      fnd_file.put_line(fnd_file.log,
                        'AND trunc(rila.ship_date_actual) <= to_date(''' ||
                        p_high_ship_date ||
                        ''', ''YYYY/MM/DD HH24:MI:SS'')');

    END IF;

    IF p_low_bill_to_cust_num IS NOT NULL OR
       p_high_bill_to_cust_num IS NOT NULL OR
       p_low_bill_to_cust_name IS NOT NULL OR
       p_high_bill_to_cust_name IS NOT NULL THEN

      l_query_clause := l_query_clause ||
                        'AND orig_system_bill_customer_id IN (SELECT cust_acct.cust_account_id ' ||
                        chr(10) ||
                        '                                       FROM hz_cust_accounts cust_acct, hz_parties party ' ||
                        chr(10) ||
                        '                                      WHERE cust_acct.party_id = party.party_id AND ' ||
                        chr(10) ||
                        '                                            cust_acct.account_number >= nvl(''' ||
                        p_low_bill_to_cust_num ||
                        ''', cust_acct.account_number) AND  ' || chr(10) ||
                        '                                            cust_acct.account_number <= nvl(''' ||
                        p_high_bill_to_cust_num ||
                        ''', cust_acct.account_number) AND  ' || chr(10) ||
                        '                                            party.party_name >= nvl(''' ||
                        p_low_bill_to_cust_name ||
                        ''', party.party_name) AND  ' || chr(10) ||
                        '                                            party.party_name <= nvl(''' ||
                        p_high_bill_to_cust_name ||
                        ''', party.party_name)) ' || chr(10);

      fnd_file.put_line(fnd_file.log,
                        'AND orig_system_bill_customer_id IN (SELECT cust_acct.cust_account_id ');
      fnd_file.put_line(fnd_file.log,
                        '                                       FROM hz_cust_accounts cust_acct, hz_parties party ');
      fnd_file.put_line(fnd_file.log,
                        '                                      WHERE cust_acct.party_id = party.party_id AND ');
      fnd_file.put_line(fnd_file.log,
                        '                                            cust_acct.account_number >= nvl(''' ||
                        p_low_bill_to_cust_num ||
                        ''', cust_acct.account_number) AND  ');
      fnd_file.put_line(fnd_file.log,
                        '                                            cust_acct.account_number <= nvl(''' ||
                        p_high_bill_to_cust_num ||
                        ''', cust_acct.account_number) AND  ');
      fnd_file.put_line(fnd_file.log,
                        '                                            party.party_name >= nvl(''' ||
                        p_low_bill_to_cust_name ||
                        ''', party.party_name) AND  ');
      fnd_file.put_line(fnd_file.log,
                        '                                            party.party_name <= nvl(''' ||
                        p_high_bill_to_cust_name ||
                        ''', party.party_name)) ');
    END IF;

    IF p_low_ship_to_cust_num IS NOT NULL OR
       p_high_ship_to_cust_num IS NOT NULL OR
       p_low_ship_to_cust_name IS NOT NULL OR
       p_high_ship_to_cust_name IS NOT NULL THEN

      l_query_clause := l_query_clause ||
                        'AND orig_system_ship_customer_id IN (SELECT cust_acct.cust_account_id ' ||
                        chr(10) ||
                        '                                       FROM hz_cust_accounts cust_acct, hz_parties party ' ||
                        chr(10) ||
                        '                                      WHERE cust_acct.party_id = party.party_id AND ' ||
                        chr(10) ||
                        '                                            cust_acct.account_number >= nvl(''' ||
                        p_low_ship_to_cust_num ||
                        ''', cust_acct.account_number) AND  ' || chr(10) ||
                        '                                            cust_acct.account_number <= nvl(''' ||
                        p_high_ship_to_cust_num ||
                        ''', cust_acct.account_number)) ' ||

                        chr(10) ||
                        '                                            party.party_name >= nvl(''' ||
                        p_low_ship_to_cust_name ||
                        ''', party.party_name) AND  ' || chr(10) ||
                        '                                            party.party_name <= nvl(''' ||
                        p_high_ship_to_cust_name ||
                        ''', party.party_name)) ' || chr(10);

      fnd_file.put_line(fnd_file.log,
                        'AND orig_system_ship_customer_id IN (SELECT cust_acct.cust_account_id ');
      fnd_file.put_line(fnd_file.log,
                        '                                       FROM hz_cust_accounts cust_acct, hz_parties party ');
      fnd_file.put_line(fnd_file.log,
                        '                                      WHERE cust_acct.party_id = party.party_id AND ');
      fnd_file.put_line(fnd_file.log,
                        '                                            cust_acct.account_number >= nvl(''' ||
                        p_low_ship_to_cust_num ||
                        ''', cust_acct.account_number) AND  ');
      fnd_file.put_line(fnd_file.log,
                        '                                            cust_acct.account_number <= nvl(''' ||
                        p_high_ship_to_cust_num ||

                        ''', cust_acct.account_number) AND  ');
      fnd_file.put_line(fnd_file.log,
                        '                                            party.party_name >= nvl(''' ||
                        p_low_ship_to_cust_name ||
                        ''', party.party_name) AND  ');
      fnd_file.put_line(fnd_file.log,
                        '                                            party.party_name <= nvl(''' ||
                        p_high_ship_to_cust_name ||
                        ''', party.party_name)) ');

    END IF;
    fnd_file.put_line(fnd_file.log, '---------------------------------');

    p_query_clause := l_query_clause;

  END build_sql_resin_credit;
  --------------------------------------------------------------------
  --  name:              process_trx_lines
  --  create by:         ofer suad
  --  Revision:          1.0
  --  creation date:
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0                ofer suad        initial build
  --  1.1  31-May-2016   ofer suad        CHG0036536 -  Invoice date for Contract orders
  --                     L Sarangi        CHG0036536 - Code Modified
  --  1.2  30.Mar-2017   L Sarangi         failing to import Service Contract Invoices if the Contract Start Date is a Future Date
  --                                       Call to handle_invoice_conversion_date Procedure Added
  --  1.3  11/07/2017    Lingaraj Sarangi CHG0040750 - Allocate revenue to LE that own IP when item assembled in another LE
  --                                      Changes Done for Inter Company Invoices
  --  1.4  17/07/2017    Erik Morgan      CHG0040938 - Remove restriction for JP batch
  --                                      Code modified By Piyali Bhowmick
  --  2.0  08/05/2018    Ofer S./Roman W. CHG0042417 - Remove ondition for drop shipment
  --  2.1  17/07/2018    Lingaraj         CHG0043603 - REASON_CODE need to Remove for Defective SO Line types to create a single CM
  --  2.2  03/01/2019    Roman W.         CHG0044816 - some JP invoices does not have avarage discunt calcualted
  --  2.3  10/05/2019    Ofer Suad        CHG0045219 - distribution of lines with modifier marked with Exclude from Avg Discount
  --                        Calc flag will stay zero (selling price) and average discount will not impact them.
  ---------------------------------------------------------------------
  PROCEDURE process_trx_lines(errbuf                      OUT VARCHAR2,
                              retcode                     OUT NUMBER,
                              p_num_of_instances          IN VARCHAR2,
                              p_organization              NUMBER,
                              p_batch_source_id           IN ra_batch_sources.batch_source_id%TYPE,
                              p_batch_source_name         IN VARCHAR2,
                              p_default_date              IN VARCHAR2 DEFAULT NULL,
                              p_trans_flexfield           IN VARCHAR2 DEFAULT NULL,
                              p_trx_type_id               IN ra_cust_trx_types.cust_trx_type_id%TYPE DEFAULT NULL,
                              p_low_bill_to_cust_num      IN hz_cust_accounts.account_number%TYPE DEFAULT NULL,
                              p_high_bill_to_cust_num     IN hz_cust_accounts.account_number%TYPE DEFAULT NULL,
                              p_low_bill_to_cust_name     IN hz_parties.party_name%TYPE DEFAULT NULL,
                              p_high_bill_to_cust_name    IN hz_parties.party_name%TYPE DEFAULT NULL,
                              p_low_gl_date               IN VARCHAR2 DEFAULT NULL,
                              p_high_gl_date              IN VARCHAR2 DEFAULT NULL,
                              p_low_ship_date             IN VARCHAR2 DEFAULT NULL,
                              p_high_ship_date            IN VARCHAR2 DEFAULT NULL,
                              p_low_trans_number          IN ra_interface_lines.trx_number%TYPE DEFAULT NULL,
                              p_high_trans_number         IN ra_interface_lines.trx_number%TYPE DEFAULT NULL,
                              p_low_sales_order_num       IN ra_interface_lines.sales_order%TYPE DEFAULT NULL,
                              p_high_sales_order_num      IN ra_interface_lines.sales_order%TYPE DEFAULT NULL,
                              p_neg_prep_as_credit        IN VARCHAR2, --added by daniel katz on 19-sep-10
                              p_low_invoice_date          IN VARCHAR2 DEFAULT NULL,
                              p_high_invoice_date         IN VARCHAR2 DEFAULT NULL,
                              p_low_ship_to_cust_num      IN hz_cust_accounts.account_number%TYPE DEFAULT NULL,
                              p_high_ship_to_cust_num     IN hz_cust_accounts.account_number%TYPE DEFAULT NULL,
                              p_low_ship_to_cust_name     IN hz_parties.party_name%TYPE,
                              p_high_ship_to_cust_name    IN hz_parties.party_name%TYPE,
                              p_base_due_date_on_trx_date IN fnd_lookups.meaning%TYPE,
                              p_due_date_adj_days         IN NUMBER) IS

    t_order_numbers          rila_order_numbers_type;
    t_order_headers_id       rila_order_headers_type;
    t_order_currencies       rila_order_currencies_type;
    t_order_currencies_resin rila_order_currencies_type;
    t_updated_lines          rila_order_headers_type;
    t_updated_lines_miss     rila_order_headers_type;
    t_cust_accounts          rila_order_numbers_type;
    t_xxoe_order_numbers     xxar_intercompany_pkg.xxoe_order_numbers_type;

    lv_is_valid         VARCHAR2(1);
    l_trx_type_name     ra_cust_trx_types_all.name%TYPE;
    ln_avarage_discount NUMBER;
    lv_precision        NUMBER;
    l_return_status     VARCHAR2(1);
    l_err_msg           VARCHAR2(500);
    l_first             VARCHAR2(1) := 'Y';
    l_rate              NUMBER := NULL;
    --l_prepayment_dest_trx_type NUMBER;
    --l_prepeyment_item_type     NUMBER;
    l_update_rounding_reminder BOOLEAN := TRUE;
    l_query_clause             VARCHAR2(4000);
    l_is_valid                 NUMBER;
    l_program_request_id       NUMBER := -1;
    l_is_resin_credit_item     VARCHAR2(1); --CHG0037700-  fix 100% Resin credit accounting
    trx_error EXCEPTION;
  BEGIN

    IF fnd_profile.value_specific('XXAR_PREPAYMENT_DEST_TRX_TYPE',
                                  NULL,
                                  NULL,
                                  NULL,
                                  p_organization) IS NULL THEN

      fnd_file.put_line(fnd_file.output,
                        'Profile "XX: Prepayment AR Transaction Type" is missing.');
      fnd_file.put_line(fnd_file.log,
                        'Profile "XX: Prepayment AR Transaction Type" is missing.');

      errbuf  := 'Profile "XX: Prepayment AR Transaction Type" is missing.';
      retcode := 1;
      RETURN;
    ELSIF fnd_profile.value('XXAR PREPAYMENT ITEM TYPES') IS NULL THEN
      fnd_file.put_line(fnd_file.output,
                        'Profile "XX: Prepayment Item Type" is missing.');
      fnd_file.put_line(fnd_file.log,
                        'Profile "XX: Prepayment Item Type" is missing.');

      errbuf  := 'Profile "XX: Prepayment Item Types" is missing.';
      retcode := 1;
      RETURN;
    ELSIF fnd_profile.value_specific('XXAR_PREPAYMENT_MEMO_LINE',
                                     NULL,
                                     NULL,
                                     NULL,
                                     p_organization) IS NULL THEN
      fnd_file.put_line(fnd_file.output,
                        'Profile "XX: Prepayment AR Memo Line" is missing.');
      fnd_file.put_line(fnd_file.log,
                        'Profile "XX: Prepayment AR Memo Line" is missing.');

      errbuf  := 'Profile "XX: Prepayment AR Memo Line" is missing.';
      retcode := 1;
      RETURN;
    ELSIF fnd_profile.value_specific('XXAR_FREIGHT_AR_ITEM') IS NULL THEN
      fnd_file.put_line(fnd_file.output,
                        'Profile XX: Freight AR Item Type" is missing.');
      fnd_file.put_line(fnd_file.log,
                        'Profile XX: Freight AR Item Type" is missing.');

      errbuf  := 'Profile "XX: Prepayment AR Memo Line.';
      retcode := 1;
      RETURN;
    END IF;
    --  25/08/2014          Ofer Suad       CR #CHG0032772
    UPDATE ra_interface_lines_all ril
       SET ril.request_id = NULL
     WHERE ril.request_id = -99
       AND ril.org_id = p_organization;

    ---------------------------------------------------------------------
    --Start v1.3 CHG0040750 Added on 11 JUL 17
    --Mark the Invoice Lines which are
    --?I/C invoice lines .
    --?Item is marked with IP in different OU ?see new item catgory below .
    --?IP Owing OU is different from buying OU.

    -------------------------------------------------------------------------
    IF fnd_profile.value('XXAR_ENABLE_IP_REV_ALLOCATION') IS NOT NULL THEN
      UPDATE ra_interface_lines_all ril_upd
         SET request_id = -99
       WHERE EXISTS
       (SELECT 1
                FROM ra_interface_lines_all ril,
                     mtl_item_categories_v  mc,
                     mtl_category_sets      mts,
                     oe_order_lines_all     ol,
                     oe_order_headers_all   oh
               WHERE mc.organization_id =
                     xxinv_utils_pkg.get_master_organization_id
                 AND mc.inventory_item_id = ril.inventory_item_id
                 AND mts.category_set_id = mc.category_set_id
                 AND mts.category_set_name = 'XX IP Operating Units' --?       Item is marked with IP in different OU
                 AND ril.interface_line_context = 'INTERCOMPANY' -- ?        I/C invoice lines
                 AND ril.request_id IS NULL
                    --AND    ril.org_id = ol.org_id --CHG0042417 - Remove condition for drop shipment
                 AND (mc.segment1 = to_char(ril.org_id) AND
                     mc.segment2 <> ril.interface_line_attribute4 OR
                     mc.segment1 = ril.interface_line_attribute4 AND
                     mc.segment2 <> to_char(ril.org_id))
                 AND nvl(mc.segment1, '-99') <> nvl(mc.segment2, '-99') --?       IP Owing OU is different from buying OU
                    --and ril.inventory_item_id = 492002 -- (For Testing)
                 AND ril_upd.rowid = ril.rowid
                 AND ol.line_id = ril.interface_line_attribute6
                 AND ol.header_id = oh.header_id
                 AND oh.creation_date >
                     fnd_profile.value('XXAR_ENABLE_IP_REV_ALLOCATION'));
      fnd_file.put_line(fnd_file.log,
                        'CHG0040750 :No Of Invoice Lines Updated to (REQUEST_ID) -99 for Inter Company :' ||
                        SQL%ROWCOUNT);
    END IF;
    -- END v1.3 CHG0040750 Added on 11 JUL 17

    /***  Build  Query  ***/
    build_sql(p_num_of_instances,
              p_organization,
              p_batch_source_id,
              p_batch_source_name,
              p_default_date,
              p_trans_flexfield,
              p_trx_type_id,
              p_low_bill_to_cust_num,
              p_high_bill_to_cust_num,
              p_low_bill_to_cust_name,
              p_high_bill_to_cust_name,
              p_low_gl_date,
              p_high_gl_date,
              p_low_ship_date,
              p_high_ship_date,
              p_low_trans_number,
              p_high_trans_number,
              p_low_sales_order_num,
              p_high_sales_order_num,
              p_low_invoice_date,
              p_high_invoice_date,
              p_low_ship_to_cust_num,
              p_high_ship_to_cust_num,
              p_low_ship_to_cust_name,
              p_high_ship_to_cust_name,
              p_base_due_date_on_trx_date,
              p_due_date_adj_days,
              l_query_clause);

    EXECUTE IMMEDIATE l_query_clause BULK COLLECT
      INTO t_order_headers_id, t_order_numbers, t_order_currencies
      USING p_batch_source_name, p_organization, p_trx_type_id, p_low_sales_order_num, p_high_sales_order_num;

    fnd_file.put_line(fnd_file.log, 'after execute immediate - first');

    build_sql_resin_credit(p_num_of_instances,
                           p_organization,
                           p_batch_source_id,
                           p_batch_source_name,
                           p_default_date,
                           p_trans_flexfield,
                           p_trx_type_id,
                           p_low_bill_to_cust_num,
                           p_high_bill_to_cust_num,
                           p_low_bill_to_cust_name,
                           p_high_bill_to_cust_name,
                           p_low_gl_date,
                           p_high_gl_date,
                           p_low_ship_date,
                           p_high_ship_date,
                           p_low_trans_number,
                           p_high_trans_number,
                           p_low_sales_order_num,
                           p_high_sales_order_num,
                           p_low_invoice_date,
                           p_high_invoice_date,
                           p_low_ship_to_cust_num,
                           p_high_ship_to_cust_num,
                           p_low_ship_to_cust_name,
                           p_high_ship_to_cust_name,
                           p_base_due_date_on_trx_date,
                           p_due_date_adj_days,
                           l_query_clause);

    EXECUTE IMMEDIATE l_query_clause BULK COLLECT
      INTO t_cust_accounts, t_order_currencies_resin
      USING p_batch_source_name, p_organization, p_trx_type_id, p_low_sales_order_num, p_high_sales_order_num;

    fnd_file.put_line(fnd_file.log, 'after execute immediate - second');

    -- population uniqness check

    l_program_request_id := fnd_global.conc_request_id;

    --     02-Jun-2013      Ofer Suad        Add hold to Japan invoice when running Standard /Trad in order
    --                                       for all sale order - Run only if specifing the sale order number

    /*-- Commented on 17/07/2017 for CHG0040938

          IF xxhz_util.get_operating_unit_name(p_organization) = 'OBJET JP (OU)' AND
           (p_low_sales_order_num IS NULL OR p_high_sales_order_num IS NULL) THEN

          UPDATE ra_interface_lines_all ril
          SET    ril.request_id = -1
          WHERE  EXISTS (SELECT 1
                  FROM   ra_cust_trx_types_all rctt
                  WHERE  rctt.cust_trx_type_id = ril.cust_trx_type_id
                  AND    nvl(rctt.attribute5, 'N') = 'Y'
                  AND    rctt.org_id = ril.org_id)
          AND    ril.request_id IS NULL
          AND    ril.org_id = p_organization;

        END IF;
    */ --CHG0040938

    FOR idx IN 1 .. t_order_headers_id.count LOOP

      /* 11/08/2013 Ofer susad - rount total amount to invoice currency precision - In JPY case precision=01 */
      IF xxhz_util.get_operating_unit_name(p_organization) =
         'OBJET JP (OU)' THEN
        UPDATE ra_interface_lines_all rila
           SET rila.unit_selling_price = floor(rila.unit_selling_price),
               rila.amount             = round(rila.quantity *
                                               floor(rila.unit_selling_price),
                                               get_precision(rila.currency_code))
         WHERE EXISTS
         (SELECT 1
                  FROM oe_order_lines_all l
                 WHERE to_char(l.line_id) = rila.interface_line_attribute6
                   AND l.header_id = t_order_headers_id(idx));

        /* Rem by Roman W 03/01/2019 CHG0044816
        IF p_low_sales_order_num IS NOT NULL AND
           p_high_sales_order_num IS NOT NULL THEN
          UPDATE ra_interface_lines_all ril
             SET ril.request_id = NULL
           WHERE EXISTS (SELECT 1
                    FROM ra_cust_trx_types_all rctt
                   WHERE rctt.cust_trx_type_id = ril.cust_trx_type_id
                     AND nvl(rctt.attribute5, 'N') = 'Y'
                     AND rctt.org_id = ril.org_id)
             AND ril.org_id = fnd_global.org_id
             AND EXISTS
           (SELECT 1
                    FROM oe_order_lines_all l
                   WHERE to_char(l.line_id) = ril.interface_line_attribute6
                     AND l.header_id = t_order_headers_id(idx));

        END IF;
        */

      END IF;
      --     02-Jun-2013      Ofer Suad   End Japan

      BEGIN
        SELECT 1
          INTO l_is_valid
          FROM ra_interface_lines_all  rila,
               oe_order_lines_all      ol,
               fnd_concurrent_requests fcr

        -- Begin changes for CR # CHG0031959 Venu
        -- WHERE rila.interface_line_attribute6 = to_char(ol.line_id)
         WHERE to_char(rila.interface_line_attribute6) =
               to_char(ol.line_id)
              -- End changes for CR # CHG0031959 Venu

           AND rila.interface_line_context IN
               ('ORDER ENTRY', 'INTERCOMPANY')
           AND nvl(rila.attribute11, '-1') = to_char(fcr.request_id) -- 4.12.2014 Michal Tzvik CHG0033952 : replace nvl(rila.attribute11, -1), add to_char
           AND fcr.phase_code = 'R'
           AND ol.header_id = t_order_headers_id(idx)
              --added by daniel katz
           AND rownum < 2;

        ROLLBACK;
        fnd_file.put_line(fnd_file.output,
                          'Program already running for this population');
        fnd_file.put_line(fnd_file.log,
                          'Program already running for this population');
        retcode := 2;
        RETURN;

      EXCEPTION

        WHEN no_data_found THEN

          UPDATE ra_interface_lines_all rila
             SET attribute11 = l_program_request_id
           WHERE rila.interface_line_context IN
                 ('ORDER ENTRY', 'INTERCOMPANY')
             AND EXISTS
           (SELECT 1
                    FROM oe_order_lines_all l
                   WHERE to_char(l.line_id) = rila.interface_line_attribute6
                     AND l.header_id = t_order_headers_id(idx));

        WHEN OTHERS THEN

          ROLLBACK;
          fnd_file.put_line(fnd_file.output,
                            'Program already running for this population');
          fnd_file.put_line(fnd_file.log,
                            'Program already running for this population');
          retcode := 2;
          RETURN;

      END;

    END LOOP;

    COMMIT;

    FOR idx IN 1 .. t_cust_accounts.count LOOP

      BEGIN
        SELECT 1
          INTO l_is_valid
          FROM ra_interface_lines_all  rila,
               mtl_system_items_b      msi,
               ra_cust_trx_types_all   rctt,
               fnd_concurrent_requests fcr
         WHERE rila.interface_line_context IN
               ('ORDER ENTRY', 'INTERCOMPANY')
           AND rila.orig_system_bill_customer_id = t_cust_accounts(idx)
           AND rila.currency_code = t_order_currencies_resin(idx)
           AND rila.org_id = p_organization
           AND nvl(rila.attribute11, '-1') = to_char(fcr.request_id) -- 4.12.2014 Michal Tzvik CHG0033952 : replace nvl(rila.attribute11, -1), add to_char
              --ADDED BY DANIEL KATZ
           AND nvl(rila.attribute11, '-1') != to_char(l_program_request_id) -- 4.12.2014 Michal Tzvik CHG0033952 : replace nvl(rila.attribute11, -1), add to_char
           AND fcr.phase_code = 'R'
           AND rila.cust_trx_type_id = rctt.cust_trx_type_id
           AND rctt.org_id = rila.org_id
              --AND    nvl(rctt.attribute5, 'N') = 'N'
           AND msi.inventory_item_id = rila.inventory_item_id
           AND msi.organization_id =
               xxinv_utils_pkg.get_master_organization_id
           AND msi.item_type =
               fnd_profile.value('XXAR_CREDIT_RESIN_ITEM_TYPE')
           AND rila.unit_selling_price < 0
           AND EXISTS
         (SELECT 1
                  FROM oe_order_lines_all l
                 WHERE to_char(l.line_id) = rila.interface_line_attribute6)
              --added by daniel katz
           AND rownum < 2;

        ROLLBACK;
        fnd_file.put_line(fnd_file.output,
                          'Program already running for this population (Resin)');
        fnd_file.put_line(fnd_file.log,
                          'Program already running for this population (Resin)');
        retcode := 2;
        RETURN;

      EXCEPTION
        WHEN no_data_found THEN

          UPDATE ra_interface_lines_all rila
             SET attribute11 = l_program_request_id
           WHERE rila.interface_line_context IN
                 ('ORDER ENTRY', 'INTERCOMPANY')
             AND rila.orig_system_bill_customer_id = t_cust_accounts(idx)
             AND rila.currency_code = t_order_currencies_resin(idx)
             AND rila.org_id = p_organization
             AND rila.unit_selling_price < 0
                --  CHG0032677?verage discount for all orders type
                /* AND    EXISTS
                (SELECT 1
                       FROM   ra_cust_trx_types_all rctt
                       WHERE  rctt.cust_trx_type_id = rila.cust_trx_type_id
                       AND    nvl(rctt.attribute5, 'N') = 'N'
                       AND    rctt.org_id = rila.org_id)*/
             AND EXISTS
           (SELECT 1
                    FROM mtl_system_items_b msi
                   WHERE msi.inventory_item_id = rila.inventory_item_id
                     AND msi.organization_id =
                         xxinv_utils_pkg.get_master_organization_id
                     AND msi.item_type =
                         fnd_profile.value('XXAR_CREDIT_RESIN_ITEM_TYPE'));

        WHEN OTHERS THEN
          ROLLBACK;
          fnd_file.put_line(fnd_file.output,
                            'Program already running for this population (Resin)');
          fnd_file.put_line(fnd_file.log,
                            'Program already running for this population (Resin)');
          retcode := 2;
          RETURN;

      END;

    END LOOP;

    COMMIT;

    --commented by daniel katz and replaced to delete by header id and not order numbers
    /*      FORALL idx IN 1 .. t_order_numbers.COUNT
             DELETE ra_interface_distributions_all
              WHERE interface_line_attribute1 = t_order_numbers(idx);
    */

    FORALL idx IN 1 .. t_order_headers_id.count

      DELETE ra_interface_distributions_all
       WHERE interface_line_attribute6 IN
             (SELECT ol.line_id
                FROM oe_order_lines_all ol
               WHERE ol.header_id = t_order_headers_id(idx))
         AND interface_line_attribute1 = to_char(t_order_numbers(idx));

    --  Update accounting rule and DE tax code for Service contracts from OM
    -- <Ofer Suad> 15.01.20112
    IF nvl(fnd_profile.value('XXAR_ACTIVATE_CONTRACT_FROM_OKS'), 'N') = 'Y' THEN
      handle_contracts_from_om_trx(t_order_numbers,
                                   p_organization,
                                   l_return_status,
                                   l_err_msg);
      --  25/08/2014          Ofer Suad       CR #CHG0032772
      /*IF l_return_status != fnd_api.g_ret_sts_success THEN
       RAISE trx_error;
      END IF;*/
    END IF;

    ---CHG0036536 - Invoice date for Contract orders - Added On 31 may 2016 - Ofer Suad
    -- Code added by L Sarangi
    handle_maintenance_trx_date(t_order_numbers,
                                p_organization,
                                l_return_status,
                                l_err_msg);

    --CHG0040281 - Auto Invoice failing to import Service Contract Invoices if the Contract Start Date is a Future Date
    --Call to handle_invoice_conversion_date Procedure added on 30.03.17 for CHG0040281
    handle_invoice_conversion_date(t_order_numbers);

    --Change Added on 17 Sep 2018
    --CHG0043603 - REASON_CODE need to Remove for Defective SO Line types to create a single CM
    handle_invoice_reason_code(t_order_numbers);

    --  update OKL contracts item,terms and transaction type
    -- <Ofer Suad> 15.01.20112
    handle_okl_contracts_trx(p_organization, l_return_status, l_err_msg);
    --  25/08/2014          Ofer Suad       CR #CHG0032772
    /*
    IF l_return_status != fnd_api.g_ret_sts_success THEN
        RAISE trx_error;
    END IF;*/
    fnd_file.put_line(fnd_file.log, 'after handle OKL Contracts');
    --  Update prepayments transaction type FOR POSITIVE LINE
    -- <daniel katz> here it can be by order numbers as anyway it manipulates only perpayment lines.
    handle_pos_prepayments_trx(t_order_numbers,
                               p_organization,
                               l_return_status,
                               l_err_msg);
    --  25/08/2014          Ofer Suad       CR #CHG0032772
    /*IF l_return_status != fnd_api.g_ret_sts_success THEN
            RAISE trx_error;
    END IF;*/

    fnd_file.put_line(fnd_file.log, 'after handle positive prepayment');

    --  Update prepayments memo line for negative amount
    --commented by dnaiel katz and replaced (it was procedure for positive prepayments instead of negative)
    --      handle_pos_prepayments_trx(t_order_numbers,

    -- <daniel katz> here it can be by order numbers as anyway it manipulates only perpayment lines.
    handle_neg_prepayments_trx(t_order_numbers,
                               p_organization,
                               l_return_status,
                               l_err_msg,
                               --added parameter by daniel katz on 19-sep-10
                               p_neg_prep_as_credit);

    IF l_return_status != fnd_api.g_ret_sts_success THEN
      RAISE trx_error;
    END IF;

    fnd_file.put_line(fnd_file.log, 'after handle negative prepayment');

    -- <daniel katz> here it could be by order numbers as anyway it manipulates only freight lines.
    --commented by daniel katz on 1-jul-10 because freight account comes according to the item type of freight
    /*handle_freight_items_trx(t_order_numbers,
                             p_organization,
                             l_return_status,
                             l_err_msg);

    IF l_return_status != fnd_api.g_ret_sts_success THEN
      RAISE trx_error;
    END IF;*/

    COMMIT;

    --fnd_file.put_line(fnd_file.LOG, 'after handle freight item');

    --Run over all orders in request population
    --commented by daniel katz and replaced to loop thru order header ids instead of order numbers
    --      FOR i IN 1 .. t_order_numbers.COUNT LOOP
    FOR i IN 1 .. t_order_headers_id.count LOOP
      BEGIN

        --moved by daniel katz from below this block because if next step will go to exception then this value already should be.
        lv_precision               := get_precision(t_order_currencies(i));
        l_update_rounding_reminder := TRUE;
        --commented by daniel katz and replaced below because:
        --there may be more than 1 line + it is not restricted to particular record in loop + refer to order header id
        /*            SELECT 'Y'
                      INTO lv_is_valid
                      FROM ra_interface_lines_all rila, ra_cust_trx_types_all rctt,
                     WHERE rila.cust_trx_type_id = rctt.cust_trx_type_id AND
                           nvl(rctt.attribute5, 'N') = 'Y';
        */

        fnd_file.put_line(fnd_file.log,
                          'in for i in 1.t_order_headers_id.count loop');

        SELECT DISTINCT 'Y'
          INTO lv_is_valid
          FROM ra_cust_trx_types_all rctt
         WHERE nvl(rctt.attribute5, 'N') = 'Y'
           AND EXISTS
         (SELECT 1
                  FROM ra_interface_lines_all rila, oe_order_lines_all ol
                 WHERE rila.interface_line_attribute6 = to_char(ol.line_id)
                   AND rila.cust_trx_type_id = rctt.cust_trx_type_id
                   AND rila.org_id = rctt.org_id
                   AND ol.header_id = t_order_headers_id(i)
                      --added by daniel katz on 16-nov-09 to ignore intercompany invoice
                   AND rila.org_id = p_organization);

        -- validate batch_source_name
        BEGIN
          IF l_first = 'Y' THEN
            SELECT 'Y'
              INTO lv_is_valid
              FROM ra_batch_sources_all rbs
             WHERE rbs.name = p_batch_source_name
               AND nvl(rbs.create_clearing_flag, 'N') = 'Y'
               AND rbs.org_id = p_organization; -- Check nvl !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

            l_first := 'N';
          END IF;
        EXCEPTION
          WHEN OTHERS THEN

            SELECT NAME
              INTO l_trx_type_name
              FROM ra_interface_lines_all rila,
                   ra_cust_trx_types_all  rctt,
                   --add by daniel katz table oe order lines and additional conditions to retreive by order header id
                   oe_order_lines_all ol
            --                   WHERE rila.interface_line_attribute1 =
            --                         t_order_numbers(i) AND
             WHERE rila.interface_line_attribute6 = to_char(ol.line_id)
               AND ol.header_id = t_order_headers_id(i)
               AND rila.sales_order = to_char(t_order_numbers(i))
               AND --to avoid other lines that could come not from sale order
                   rila.cust_trx_type_id = rctt.cust_trx_type_id
               AND rila.org_id = rctt.org_id
               AND rownum < 2;
            ----------------------------       Not Transaction Dependent               ------------------
            fnd_message.set_name('XXOBJT',
                                 'XXAR_AUTOINV_SOURCE_VALIDATION');
            fnd_message.set_token('TRX_TYPE', l_trx_type_name);
            fnd_message.set_token('TRX_SOURCE', p_batch_source_name);
            fnd_file.put_line(fnd_file.output, fnd_message.get);
            fnd_file.put_line(fnd_file.log, fnd_message.get);
            errbuf  := fnd_message.get;
            retcode := 1;
            RETURN;
        END;

        fnd_file.put_line(fnd_file.log,
                          'before average disocunt calculation');
        --commented by daniel katz and removed to beginning of the loop (because when it goes there to exception precision already should have a value)
        --lv_precision := get_precision(t_order_currencies(i));

        --<daniel katz> here the l_err_msg should be reset because on following function it may be populated by value that should be used in
        --"if" block for the rounding handler procedure.

        -- for each order, calculate the avarage price and update to valid lines
        l_err_msg           := '';
        ln_avarage_discount := calculate_avarage_discount(t_order_headers_id(i),
                                                          t_order_numbers(i),
                                                          l_rate,
                                                          l_return_status,
                                                          l_err_msg);

        fnd_file.put_line(fnd_file.log,
                          'after average discount calculation');

        --commented by daniel katz following if block.
        --in this case the new averaged discount<>existing on invoice average discount. but it shouldn't end as exception.
        --it should proceed adjusting by existing averaged discount but wihtout rounding remainder handling

        /*** Changed by Ella - check when to rounding rerminder  ***/
        IF l_err_msg = 'NO_ATTRIBUTE4' THEN

          --  25/08/2014          Ofer Suad       CR #CHG0032772
          retcode := 2;
          errbuf  := l_err_msg;
          UPDATE ra_interface_lines_all ril
             SET ril.request_id = -99
           WHERE interface_line_attribute6 IN
                 (SELECT ol.line_id
                    FROM oe_order_lines_all ol
                   WHERE ol.header_id = t_order_headers_id(i))

             AND ril.org_id = p_organization;
          --
          -- RAISE trx_error;
        ELSIF l_return_status != fnd_api.g_ret_sts_success THEN
          l_update_rounding_reminder := FALSE;
        END IF;

        /*** Added by Ella - reset t_update_lines ***/
        t_updated_lines := t_updated_lines_miss;

        UPDATE ra_interface_lines_all rila

           SET attribute10 = ln_avarage_discount,
               --added by daniel katz get price list for resin credit function for the unit standard price
               --?????? the first parameter to the function is number and interface line attribute6 is varchar. need adjust ????????
               -- Ofer Suad 13/10/2013  cahnge CS_INCIDENTS_ALL_B CAL to get price list to support Boundle transactions
               amount =
               --CHG0037700-  fix 100% Resin credit accounting
                CASE
                  WHEN (is_resin_credit_item(rila.inventory_item_id) = 'Y') AND
                       ln_avarage_discount = 100 THEN
                   to_number(rila.attribute4)
                /*round(get_price_list_dist(rila.interface_line_attribute6,
                                    unit_standard_price,
                                    rila.attribute4) *
                quantity *
                ((100 - ln_avarage_discount) / 100),
                lv_precision)*/

                  ELSE
                   round(get_price_list_dist(rila.interface_line_attribute6,
                                             unit_standard_price,
                                             rila.attribute4) * quantity *
                         (decode(ln_avarage_discount,
                                 100,
                                 0, --1,--CHG0034523 To avoid clearin accout balance 100% will not affect the distribution,
                                 (100 - ln_avarage_discount) / 100)),
                         lv_precision)
                END,
               rila.conversion_rate = decode(l_rate,
                                             NULL,
                                             rila.conversion_rate,
                                             l_rate),
               rila.conversion_type = decode(l_rate,
                                             NULL,
                                             --commented by daniel katz and replaced with line below (it should be conversion type)
                                             --                                                 rila.conversion_rate,
                                             rila.conversion_type,
                                             'User')
         WHERE rila.interface_line_attribute1 = to_char(t_order_numbers(i))
           AND rila.quantity_ordered >= 0
           AND rila.unit_selling_price >= 0
           AND rila.line_type = 'LINE'

              --      EXISTS
              --  (SELECT 1
              --          FROM ra_cust_trx_types_all rctt
              --         WHERE rctt.cust_trx_type_id = rila.cust_trx_type_id AND
              --               nvl(rctt.attribute5, 'N') = 'Y' AND
              --               rctt.org_id = rila.org_id) AND
           AND exclude_from_avg_discount(rila.interface_line_attribute6) = 'N' --CHG0045219
           AND NOT EXISTS
         (SELECT 1
                  FROM mtl_system_items_b msi
                 WHERE msi.inventory_item_id = rila.inventory_item_id
                   AND msi.organization_id = rila.warehouse_id
                   AND msi.item_type IN
                       (fnd_profile.value('XXAR PREPAYMENT ITEM TYPES'),
                        fnd_profile.value('XXAR_FREIGHT_AR_ITEM')))
              --added by daniel katz condition for header id in addition to order number + CONTEXT OF ORDER ENTRY and INTERCOMPANY for safe
           AND EXISTS
         (SELECT 1
                --ott table and conditions added by daniel katz on 24-jan-10
                  FROM oe_order_lines_all ol, oe_transaction_types_all ott
                 WHERE to_char(ol.line_id) = rila.interface_line_attribute6
                   AND ol.header_id = t_order_headers_id(i)
                   AND ol.line_type_id = ott.transaction_type_id
                   AND nvl(ott.attribute2, 'Y') = 'Y')
           AND rila.interface_line_context IN
               ('ORDER ENTRY', 'INTERCOMPANY')
              --added by daniel katz on 25-nov-09 to ignore intercompany invoice
           AND rila.org_id = p_organization

        -- commented by daniel katz and replaced to interface attribute6 (because t updated lined is used as line_id and not line number)
        --????? sales_order_line is a varchar. t_updated_lines is a collection of numbers. ?????????
        RETURNING /*sales_order_line*/
        rila.interface_line_attribute6 BULK COLLECT INTO t_updated_lines;

        fnd_file.put_line(fnd_file.log, 'after update interface lines all');

        --<daniel> ???????????how the t_updated_lines collection is reset on the next record of order header id????????????
        FORALL idx IN 1 .. t_updated_lines.count
          UPDATE oe_order_lines_all
             SET attribute10 = ln_avarage_discount
           WHERE line_id = t_updated_lines(idx);

        fnd_file.put_line(fnd_file.log,
                          'after update attribute10 in sale order line');

        -----------------------------------------------------------------------
        --<daniel katz> Here should be if condition before rounding remainder handling that checks whether existing avg discount is different
        --than new avg discount. in this case no need handling rounding remainder.
        --The if should be according to l_err_msg which should come from the program calculate_avarage_discount in case there is
        --a difference between 2 avg discounts. !!!THIS VALUE ALSO SHOULD BE RESET before calling to that program!!!).

        --commented by daniel katz and rplaced the order of the order number and order headers parameters according to the
        --rounding remainder procedure.
        --            rounding_remainder_handling(t_order_numbers(i),
        --                                        t_order_headers_id(i),
        /*** Added by Ella condition for reminder ***/
        IF l_update_rounding_reminder THEN

          rounding_remainder_handling(t_order_headers_id(i),
                                      t_order_numbers(i),
                                      ln_avarage_discount,
                                      lv_precision,
                                      --addd by daniel katz on 25-nov-09
                                      p_organization);

        END IF;

        fnd_file.put_line(fnd_file.log, 'after update rounding remainder');

        --added by daniel katz additional parameter for order header id (here the parameter sended is header id but in the function
        --the parameter is order number).
        --i also changed accordingly the procedure
        handle_credit_resin_pos_trx(t_order_headers_id(i),
                                    t_order_numbers(i), --added by daniel katz
                                    p_organization,
                                    l_return_status,
                                    l_err_msg);

        IF l_return_status != fnd_api.g_ret_sts_success THEN
          --  25/08/2014          Ofer Suad       CR #CHG0032772
          retcode := 2;
          errbuf  := l_err_msg;
          UPDATE ra_interface_lines_all ril
             SET ril.request_id = -99
           WHERE interface_line_attribute6 IN
                 (SELECT ol.line_id
                    FROM oe_order_lines_all ol
                   WHERE ol.header_id = t_order_headers_id(i))

             AND ril.org_id = p_organization;
          --  RAISE trx_error;
        END IF;
        --20/05/2012    Ofer Suad         Add Coupon accounting
        -- 27-dec-2012    Ofer Suad        Move Call to handle_coupon_pos_trx out of Intial order block

      EXCEPTION
        WHEN no_data_found THEN

          --commented by daniel katz - this procedure should be on customer level and not sale order level as the balance changes for each negative line for the customer.
          -- i moved this procedure below and changed it.
          /*               handle_credit_resin_neg_trx(t_order_headers_id(i),
                                      t_order_numbers(i), --added by daniel katz
                                      p_organization,
                                      lv_precision,
                                      l_return_status,
                                      l_err_msg);

          IF l_return_status != fnd_api.g_ret_sts_success THEN
             RAISE trx_error;
          END IF;*/
          NULL;

      END;

      -- 27-dec-2012    Ofer Suad        Move Call to handle_coupon_pos_trx out of Intial order block
      handle_coupon_pos_trx(t_order_headers_id(i),
                            t_order_numbers(i), --added by daniel katz
                            p_organization,
                            l_return_status,
                            l_err_msg);

      IF l_return_status != fnd_api.g_ret_sts_success THEN
        --  25/08/2014          Ofer Suad       CR #CHG0032772
        retcode := 2;
        errbuf  := l_err_msg;
        UPDATE ra_interface_lines_all ril
           SET ril.request_id = -99
         WHERE interface_line_attribute6 IN
               (SELECT ol.line_id
                  FROM oe_order_lines_all ol
                 WHERE ol.header_id = t_order_headers_id(i))

           AND ril.org_id = p_organization;
        --  RAISE trx_error;
      END IF;

      fnd_file.put_line(fnd_file.log,
                        'after handling coupon postive lines');

      COMMIT;

    END LOOP;
    -------------------------------------------------------------------------------------------------
    --added by daniel katz for negative resin credit:
    /***  Build  Query  for negtive resin credit ***/

    -- 20/05/2012    Ofer Suad         Add Coupon accounting
    fnd_file.put_line(fnd_file.log,
                      'out of loop and before handling negative coupon credit');

    BEGIN

      handle_coupon_neg_trx(p_organization,
                            t_order_headers_id,
                            p_batch_source_name,
                            l_return_status,
                            l_err_msg);
      IF l_return_status != fnd_api.g_ret_sts_success THEN
        retcode := 2;
        errbuf  := l_err_msg;

        -- RAISE trx_error;
      END IF;

      fnd_file.put_line(fnd_file.log,
                        'out of loop and before handling negative resin credit');

      fnd_file.put_line(fnd_file.log,
                        'after handling coupon negative lines');

      FOR i IN 1 .. t_cust_accounts.count LOOP
        handle_credit_resin_neg_trx(t_cust_accounts(i),
                                    t_order_currencies_resin(i),
                                    p_organization,
                                    lv_precision,
                                    t_order_headers_id,
                                    l_return_status,
                                    l_err_msg);

        IF l_return_status != fnd_api.g_ret_sts_success THEN
          retcode := 2;
          errbuf  := l_err_msg;

          UPDATE ra_interface_lines_all rl
             SET rl.request_id = -99
           WHERE rl.org_id = p_organization
             AND rl.interface_line_attribute1 IN
                 (SELECT ril.interface_line_attribute1
                    FROM ra_interface_lines_all ril
                   WHERE ril.orig_system_bill_customer_id =
                         t_cust_accounts(i)
                     AND ril.currency_code = t_order_currencies_resin(i)
                     AND ril.org_id = p_organization
                     AND EXISTS
                   (SELECT 1
                            FROM mtl_system_items_b msi
                           WHERE msi.inventory_item_id =
                                 ril.inventory_item_id
                             AND msi.organization_id =
                                 xxinv_utils_pkg.get_master_organization_id
                                --added  by daniel katz (to restrict to the resin credit item line)
                             AND msi.item_type =
                                 fnd_profile.value('XXAR_CREDIT_RESIN_ITEM_TYPE')));
          -- RAISE trx_error;
        END IF;
      END LOOP;

      /*   exception
      when others then
        null;*/
    END;
    ---------------------------------------------------------------------------------

    -- Process Intercompany
    IF p_batch_source_id = 8 THEN
      FOR i IN 1 .. t_order_numbers.count LOOP
        t_xxoe_order_numbers(i) := t_order_numbers(i);
      END LOOP;

      xxar_intercompany_pkg.process_intercompany_invoices(p_order_numbers_tbl => t_xxoe_order_numbers,
                                                          p_organization_id   => p_organization,
                                                          p_show_success_flag => 'Y',
                                                          x_return_message    => l_err_msg,
                                                          x_return_status     => l_return_status);

      IF l_return_status != fnd_api.g_ret_sts_success THEN
        RAISE trx_error;
      END IF;
    END IF;

    submit_request(errbuf,
                   retcode,
                   p_num_of_instances,
                   p_organization,
                   p_batch_source_id,
                   p_batch_source_name,
                   p_default_date,
                   p_trans_flexfield,
                   p_trx_type_id,
                   p_low_bill_to_cust_num,
                   p_high_bill_to_cust_num,
                   p_low_bill_to_cust_name,
                   p_high_bill_to_cust_name,
                   p_low_gl_date,
                   p_high_gl_date,
                   p_low_ship_date,
                   p_high_ship_date,
                   p_low_trans_number,
                   p_high_trans_number,
                   p_low_sales_order_num,
                   p_high_sales_order_num,
                   p_low_invoice_date,
                   p_high_invoice_date,
                   p_low_ship_to_cust_num,
                   p_high_ship_to_cust_num,
                   p_low_ship_to_cust_name,
                   p_high_ship_to_cust_name,
                   p_base_due_date_on_trx_date,
                   p_due_date_adj_days);

  EXCEPTION
    WHEN trx_error THEN
      retcode := 2;
      errbuf  := l_err_msg;
    WHEN OTHERS THEN
      retcode := 2;
      errbuf  := SQLERRM;
  END process_trx_lines;

  --------------------------------------------------------------------
  --  name:              is_resin_credit_item
  --  create by:         ofer suad
  --  Revision:          1.0
  --  creation date:     14.3.16
  --------------------------------------------------------------------
  --  purpose :   CHG0037700-  fix 100% Resin credit accounting
  --               Function to find if item is Resin Credit item
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  14.3.16       ofer suad        initial build
  ---------------------------------------------------------------------

  FUNCTION is_resin_credit_item(p_item_id NUMBER) RETURN VARCHAR2 IS
    l_is_resin VARCHAR2(1);
  BEGIN
    SELECT decode(msi.item_type,
                  fnd_profile.value('XXAR_CREDIT_RESIN_ITEM_TYPE'),
                  'Y',
                  'N')
      INTO l_is_resin
      FROM mtl_system_items_b msi
     WHERE msi.inventory_item_id = p_item_id
       AND xxinv_utils_pkg.get_master_organization_id = msi.organization_id;

    RETURN l_is_resin;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'N';

  END is_resin_credit_item;

  --------------------------------------------------------------------
  --  name:              exclude_from_avg_discount
  --  create by:         Bellona(TCS)
  --  Revision:          CHG0045219
  --  creation date:     10/05/2019
  --------------------------------------------------------------------
  --  purpose :   CHG0045219 - Exclude average discount for all order lines
  --                           related to AYCP project.
  --              Function to find if line to be excluded from avg discount
  --------------------------------------------------------------------
  --  ver  date          name              desc
  -- 1.0   10/05/2019    Bellona(TCS)  CHG0045219 - Exclude average discount
  --                                   for all order lines related to AYCP project.
  ---------------------------------------------------------------------
  FUNCTION exclude_from_avg_discount(p_line_id number) return varchar2 is
    l_count NUMBER;

  BEGIN
    select count(1)
      into l_count
      from OE_PRICE_ADJUSTMENTS opa, QP_LIST_HEADERS_ALL_B qlh
     where opa.line_id = p_line_id
       and opa.list_header_id = qlh.list_header_id
       and qlh.attribute10 = 'Y';

    IF l_count > 0 THEN
      return 'Y';
    ELSE
      return 'N';
    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      return 'N';
  END exclude_from_avg_discount;
END xxar_autoinvoice_pkg;
/
