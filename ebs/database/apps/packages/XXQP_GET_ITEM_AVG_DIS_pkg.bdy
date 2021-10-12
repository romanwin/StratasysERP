create or replace package body xxqp_get_item_avg_dis_pkg IS
  /************************************************************************************************
  * Copyright (C) 2013  TCS, India                                                               *
  * All rights Reserved                                                                          *
  * Program Name: XXQP_GET_ITEM_AVG_DIS_pkg.pkb                                                    *
  * Parameters  : None                                                                           *
  * Description : Package contains the procedures and function to derive the Get Item price and  *
  *                average discount in the invoice                                               *
  *
  *                                                                                              *
  * Notes       : None
  * History     :                                                                                *
  * Creation Date : 19-May-2016
  * Created/Updated By  : TCS                                                                    *
  * Version: 1.0
  ------------------------------------------------------------------------------------------------
  --  ver  date         name              desc
  --  1.0  19-May-2016  TCS               initial build
  --  1.1  11/07/2017   TCS               Record Types Modifed [xxqp_pricereq_lines_rec_type & xxqp_pricereq_header_rec_type]
  --  1.2  01-NOV-2017  Diptasurjya       INC0106474 - Line number should be checked while fetching price in function get_price
  --                                      UOM conversion is incorporated for different pricing and order UOM
  --                                      Delete from pricing temporary tables commented as call in in FAILOVER mode
  ------------------------------------------------------------------------------------------------
  **********************************************************************************************/
  --
  -- Private variable declarations

  FUNCTION is_get_item_line(p_line_id IN NUMBER) RETURN VARCHAR2 IS
    l_count NUMBER;
  BEGIN
    BEGIN
      SELECT COUNT(1)
      INTO   l_count
      FROM   qp_pricing_attr_get_v g,
     fnd_lookup_values     flv,
     oe_price_adjustments  v,
     qp_list_lines         vv
      WHERE  v.line_id = p_line_id
      AND    v.list_line_id = g.list_line_id
      AND    vv.list_line_id = g.parent_list_line_id
      AND    flv.attribute1 = 'Y'
      AND    flv.lookup_code = vv.list_line_type_code
      AND    flv.language = 'US';

    EXCEPTION
      WHEN OTHERS THEN
        l_count := 0;
    END;
    IF l_count > 0 THEN
      RETURN 'Y';
    ELSE
      RETURN 'N';
    END IF;
  END;
  --------------------------------------------------------------------
  --  name:            get_price
  --  create by:
  --  Revision:        1.0
  --  creation date:
  --------------------------------------------------------------------
  --  purpose :
  ------------------------------------------------------------------------------------------------
  --  ver  date         name              desc
  --  1.0  19-May-2016  TCS               initial build
  --  1.1  11/07/2017   TCS               Record Types Modifed [xxqp_pricereq_lines_rec_type & xxqp_pricereq_header_rec_type]
  --  1.2  01-NOV-2017  Diptasurjya       INC0106474 - Line number should be checked while fetching price
  ------------------------------------------------------------------------------------------------
  FUNCTION get_price(p_item_id       NUMBER,
             p_price_list_id NUMBER,
             p_price_date    DATE,
             p_line_id       NUMBER DEFAULT NULL) RETURN NUMBER

   IS
    PRAGMA AUTONOMOUS_TRANSACTION;
    l_item_price NUMBER;

    p_order_header xxqp_pricereq_header_tab_type;
    p_item_lines   xxqp_pricereq_lines_tab_type;

    l_order_header_rec xxqp_pricereq_header_rec_type;
    l_item_lines_rec   xxqp_pricereq_lines_rec_type;

    l_session_details    xxqp_pricereq_session_tab_type := xxqp_pricereq_session_tab_type();
    l_order_details      xxqp_pricereq_header_tab_type := xxqp_pricereq_header_tab_type();
    l_line_details       xxqp_pricereq_lines_tab_type := xxqp_pricereq_lines_tab_type();
    l_modifier_details   xxqp_pricereq_mod_tab_type := xxqp_pricereq_mod_tab_type();
    l_attribute_details  xxqp_pricereq_attr_tab_type := xxqp_pricereq_attr_tab_type();
    l_related_adjustment xxqp_pricereq_reltd_tab_type := xxqp_pricereq_reltd_tab_type();
    l_cust_account_id    hz_cust_accounts.cust_account_id%TYPE;
    l_ship_to_site_id    hz_cust_site_uses_all.site_use_id%TYPE;
    l_bill_to_site_id    hz_cust_site_uses_all.site_use_id%TYPE;
    l_order_type_id      oe_order_headers_all.order_type_id%TYPE;
    l_org_id             NUMBER;

    l_status           VARCHAR2(10);
    l_status_message   VARCHAR2(1000);
    i                  BINARY_INTEGER;
    l_price_request_id VARCHAR2(100);
    
    l_item_uom         varchar2(3);
    l_order_line_uom   varchar2(3);
    
    l_uom_rate         number;
  BEGIN
    IF p_line_id IS NOT NULL THEN
      SELECT oh.sold_to_org_id,
     oh.invoice_to_org_id,
     oh.ship_to_org_id,
     oh.order_type_id,
     oh.org_id,
     msib.primary_uom_code,    -- INC0106474 - Get item primary UOM
     ol.pricing_quantity_uom   -- INC0106474 - Get Order line pricing UOM
      INTO   l_cust_account_id,
     l_bill_to_site_id,
     l_ship_to_site_id,
     l_order_type_id,
     l_org_id,
     l_item_uom,
     l_order_line_uom
      FROM   oe_order_lines_all   ol,
     oe_order_headers_all oh,
     mtl_system_items_b msib      -- INC0106474 - For item UOM
      WHERE  ol.line_id = p_line_id
      AND    ol.header_id = oh.header_id
      and    msib.inventory_item_id = ol.inventory_item_id
      and    msib.organization_id = xxinv_utils_pkg.get_master_organization_id;

    ELSE
      l_cust_account_id := get_default_values('XX_CUST_ACCT_ID');
      l_bill_to_site_id := get_default_values('XX_CUST_INV_ORG_ID');
      l_ship_to_site_id := get_default_values('XX_CUST_SHIP_ORG_ID');
      l_org_id          := get_default_values('XX_ORG_ID');
      l_order_type_id   := get_default_values('XX_ORDER_TYPE_ID');
    END IF;
    
    -- INC0106474 - Start - Check if UOM is different for Line pricing than Item Primary UOM, then calculate UOM conversion rate
    if nvl(l_item_uom,'XX') <> nvl(l_order_line_uom,'XX') then
      inv_convert.inv_um_conversion(l_order_line_uom,
			l_item_uom,
			null,
			l_uom_rate);
    else
      l_uom_rate := null;
    end if;
    -- INC0106474 - End
    
    l_price_request_id := 'GP' || xxqp_price_request_id_seq.nextval;
    l_order_header_rec := xxqp_pricereq_header_rec_type(l_price_request_id,
                        NULL,
                        l_cust_account_id, --get_default_values('XX_CUST_ACCT_ID'),
                        l_bill_to_site_id, --get_default_values('XX_CUST_INV_ORG_ID'),
                        l_ship_to_site_id, --get_default_values('XX_CUST_SHIP_ORG_ID'),
                        l_org_id, --get_default_values('XX_ORG_ID'),
                        get_default_values('XX_OPERATION_NO'),
                        '',
                        '',
                        p_price_list_id,
                        p_price_date,
                        '',
                        '',
                        '',
                        '',
                        l_order_type_id, --get_default_values('XX_ORDER_TYPE_ID'),
                        '',
                        '',
                        '',
                        '',
                        '',
                        '',
                        '',
                        '',
                        '',
                        '',
                        '',
                        '',
                        '',
                        '',
                        '',
                        '',
                        '',
                        '',
                        ''
                        );

    l_item_lines_rec := xxqp_pricereq_lines_rec_type(1,
                     '',
                     p_item_id,
                     '',
                     1,
                     '',
                     '',
                     '',
                     '',
                     '',
                     '',
                     '',
                     '',
                     '',
                     '','','','','','','');

    p_order_header := xxqp_pricereq_header_tab_type(l_order_header_rec);
    p_item_lines   := xxqp_pricereq_lines_tab_type(l_item_lines_rec);

    BEGIN

      xxqp_request_price_pkg.ecom_price_request(p_order_header       => p_order_header,
                p_item_lines         => p_item_lines,
                p_pricing_phase      => 'LINE', --'BATCH',
                p_debug_flag         => 'N',
                p_pricing_server     => 'FAILOVER', --'NORMAL',
                x_session_details    => l_session_details,
                x_order_details      => l_order_details,
                x_line_details       => l_line_details,
                x_modifier_details   => l_modifier_details,
                x_attribute_details  => l_attribute_details,
                x_related_adjustment => l_related_adjustment,
                x_status             => l_status,
                x_status_message     => l_status_message);

      /*dbms_output.put_line('x_status_message : ' || p_item_id || ' - ' ||
           l_status_message);*/   -- INC00xxx - Commented

    EXCEPTION
      WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log, 'Exception in Price Calculation');
        fnd_file.put_line(fnd_file.log, 'x_status_message : ' || SQLERRM);
        --dbms_output.put_line('x_status_message : ' || SQLERRM);  - INC00xxx - commented
    END;

    IF l_status = 'SP01' THEN
      i := l_line_details.first;

      IF i IS NOT NULL THEN
        LOOP

          IF l_line_details(i).unit_sales_price IS NOT NULL and l_line_details(i).line_num = 1 THEN  -- INC0106474 - check for line_num = 1
            l_item_price := l_line_details(i).unit_sales_price;
            
            /* INC0106474 - Start - Adjust for UOM difference */
            l_item_price := l_item_price*nvl(l_uom_rate,1);
            /* INC0106474 - End */
            exit;
          END IF;
          EXIT WHEN i = l_line_details.last;
          i := l_line_details.next(i);
        END LOOP;
      END IF;

      DELETE FROM xx_qp_pricereq_session
      WHERE  request_number = l_price_request_id;
      -- INC0106474 Commented as price request is in Failover mode
      /*DELETE FROM xx_qp_pricereq_modifiers
      WHERE  request_number = l_price_request_id;
      DELETE FROM xx_qp_pricereq_attributes
      WHERE  request_number = l_price_request_id;
      DELETE FROM xx_qp_pricereq_reltd_adj
      WHERE  request_number = l_price_request_id;*/

      COMMIT;

    END IF;

    RETURN(l_item_price);

  END;

  FUNCTION get_default_values(p_lookup_code VARCHAR2) RETURN VARCHAR2 IS
    l_default_value NUMBER;
  BEGIN
    SELECT to_number(meaning)
    INTO   l_default_value
    FROM   fnd_lookup_values
    WHERE  lookup_type = 'XXQP_PRICING_DEFAULT_VALUES'
    AND    lookup_code = p_lookup_code
    AND    enabled_flag = 'Y'
    AND    LANGUAGE = 'US';

    RETURN(l_default_value);
  EXCEPTION
    WHEN OTHERS THEN
      RETURN(-1);
  END;

END xxqp_get_item_avg_dis_pkg;
/
