CREATE OR REPLACE PACKAGE BODY xxqp_request_price_pkg AS

  g_header_index          NUMBER := -1;
  g_debug_flag            VARCHAR2(1) := 'N';
  g_debug_file_name       VARCHAR2(2000);
  g_transaction_value_set VARCHAR2(30) := 'XXOM_SF2OA_Order_Types_Mapping';
  g_high_date_const       DATE := to_date('31-DEC-4712', 'dd-MON-rrrr'); -- CTASK0036572 Qualifier end date change

  e_prc_request_exception EXCEPTION;
  --g_status varchar2(10) := 'S';
  --g_status_message varchar2(4000);

  ----------------------------------------------------------------------------
  --  name:            xxqp_request_price_pkg
  --  create by:       Diptasurjya Chatterjee (TCS)
  --  Revision:        1.0
  --  creation date:   10/03/2015
  ----------------------------------------------------------------------------
  --  purpose :        CHG0034837 - Simulate Line and Order pricing by
  --                   calling Oracle Advanced Pricing engine via
  --                   API QP_PREQ_PUB.PRICE_REQUEST
  ----------------------------------------------------------------------------
  --  ver  date        name                         desc
  -- 1.0  10/03/2015  Diptasurjya Chatterjee (TCS)    CHG0034837 - Initial Build
  -- 1.1  04/11/2015  Diptasurjya Chatterjee (TCS)    CHG0036750 - Set policy context before every pricing call
  --                                                               Set rounding flag for pricing engine call to Q
  -- 1.2  22.8.2016   yuval tal                       CHG0038192 - modify validate_data : remove validation of ship/bill to site
  -- 1.3  01/09/2017  Diptasurjya Chatterjee (TCS)    CHG0039953 - Procedure insert_pricereq_tables changed - before inserting data into attribute
  --                                                  and related adjustment tables, checking if associated
  --                                                  adjustment information is present in the modifier table
  -- 1.4  25/05/2017  yuval tal                       CHG0040839   modify build_header_contexts set attribute1..10/build_line_contexts set att1..10
  -- 1.5  26/06/2017  Diptasurjya Chatterjee(TCS)     CHG0041715 - Make changes to handle ask for modifier application
  -- 2.0  11/27/2017  Diptasurjya Chatterjee(TCS)     CHG0041897 - Modify API to be compatiable with both SFDC and Hybris calls
  --       28.1.2018   yuval tal                       CHG0041897   price_request :modify line number in case line number is null put max value +1
  -- 2.1  08/07/2018  Diptasurjya                     INC0128351 - Modify pricing temporary table deletes to not consider end date filters
  -- 2.2  08/30/2018  Diptasurjya                     INC0131607 - Modify procedure price_order_batch to reset the line table type variable
  -- 2.3  10/17/2018  Diptasurjya                     CHG0044153 - Allow saving of pricing line output information
  --                                                  CTASK0039215 - Fix bug for Other Item Discount adjustment information string generation
  -- 2.4  01/29/2019  Diptasurjya                     CHG0044970 - Make modifications for return lines and fix attribute validation procedure
  -- 2.5  27/12/2019  Diptasurjya                     CHG0046948 - Modify price_order_batch to send adjustment amounts grouped by modifier type
  --                                                               as order header level output
  -- 2.6  02/17/2020  Diptasurjya                     CHG0047446 - Allow pricing API to take custom attributes at line level
  -- 2.7  03/15/2020  Diptasurjya                     INC0186599 - Pricing custom attribute null check missing in price_request package
  -- 2.8  10-AUG-2020 Diptasurjya                     CHG0048217 - eCommerce B2B change
  ----------------------------------------------------------------------------

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0034837 - This procedure calls standard Oracle API to build all header level Qualifier and
  --          Pricing attributes based on various Order level inputs received as input
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  10/03/2015  Diptasurjya Chatterjee (TCS)    CHG0034837 - Initial Build
  -- 1.1  25/05/2017  yuval tal                       CHG0040839   modify build_header_contexts set attribute1..10/build_line_contexts set att1..10
  -- 1.2  18/12/2017  Diptasurjya                     CHG0041897 - Add end customer ID for building contexts
  -- --------------------------------------------------------------------------------------------

  PROCEDURE build_header_contexts(p_order_header             IN xxqp_pricereq_header_tab_type,
		          x_h_pricing_contexts_tbl   OUT qp_attr_mapping_pub.contexts_result_tbl_type,
		          x_h_qualifier_contexts_tbl OUT qp_attr_mapping_pub.contexts_result_tbl_type,
		          x_status                   OUT VARCHAR2,
		          x_status_message           OUT VARCHAR2) IS
  
  BEGIN
    oe_order_pub.g_hdr.header_id               := g_header_index;
    oe_order_pub.g_hdr.sold_to_org_id          := p_order_header(1)
				  .cust_account_id;
    oe_order_pub.g_hdr.ship_to_org_id          := p_order_header(1)
				  .cust_ship_site_id;
    oe_order_pub.g_hdr.invoice_to_org_id       := p_order_header(1)
				  .cust_bill_site_id;
    oe_order_pub.g_hdr.order_type_id           := p_order_header(1)
				  .transaction_type_id;
    oe_order_pub.g_hdr.order_category_code     := p_order_header(1)
				  .order_category;
    oe_order_pub.g_hdr.price_list_id           := p_order_header(1)
				  .price_list_id;
    oe_order_pub.g_hdr.transactional_curr_code := p_order_header(1).currency;
    oe_order_pub.g_hdr.org_id                  := p_order_header(1).org_id;
    oe_order_pub.g_hdr.freight_terms_code      := p_order_header(1)
				  .freight_terms_code;
    oe_order_pub.g_hdr.payment_term_id         := p_order_header(1)
				  .payment_terms_id;
    oe_order_pub.g_hdr.shipping_method_code    := p_order_header(1)
				  .shipping_method_code;
    oe_order_pub.g_hdr.ordered_date            := nvl(p_order_header(1)
				      .transaction_date,
				      SYSDATE);
    oe_order_pub.g_hdr.pricing_date            := nvl(p_order_header(1)
				      .transaction_date,
				      SYSDATE);
    oe_order_pub.g_hdr.request_date            := nvl(p_order_header(1)
				      .transaction_date,
				      SYSDATE);
    oe_order_pub.g_hdr.end_customer_id         := p_order_header(1)
				  .end_customer_account_id; -- CHG0041897
  
    oe_order_pub.g_hdr.attribute1  := p_order_header(1).attribute1; -- CHG0040839 instance_id
    oe_order_pub.g_hdr.attribute2  := p_order_header(1).attribute2; -- CHG0040839 instance_id
    oe_order_pub.g_hdr.attribute3  := p_order_header(1).attribute3; -- CHG0040839 instance_id
    oe_order_pub.g_hdr.attribute4  := p_order_header(1).attribute4; -- CHG0040839 instance_id
    oe_order_pub.g_hdr.attribute5  := p_order_header(1).attribute5; -- CHG0040839 instance_id
    oe_order_pub.g_hdr.attribute6  := p_order_header(1).attribute6; -- CHG0040839 instance_id
    oe_order_pub.g_hdr.attribute7  := p_order_header(1).attribute7; -- CHG0040839 instance_id
    oe_order_pub.g_hdr.attribute8  := p_order_header(1).attribute8; -- CHG0040839 instance_id
    oe_order_pub.g_hdr.attribute9  := p_order_header(1).attribute9; -- CHG0040839 instance_id
    oe_order_pub.g_hdr.attribute10 := p_order_header(1).attribute10; -- CHG0040839 instance_id
  
    qp_attr_mapping_pub.build_contexts(p_request_type_code         => 'ONT',
			   p_pricing_type              => 'H',
			   x_price_contexts_result_tbl => x_h_pricing_contexts_tbl,
			   x_qual_contexts_result_tbl  => x_h_qualifier_contexts_tbl);
  
    oe_order_pub.g_hdr.header_id               := NULL;
    oe_order_pub.g_hdr.transactional_curr_code := NULL;
    oe_order_pub.g_hdr.sold_to_org_id          := NULL;
    oe_order_pub.g_hdr.order_type_id           := NULL;
    oe_order_pub.g_hdr.price_list_id           := NULL;
    oe_order_pub.g_hdr.org_id                  := NULL;
    oe_order_pub.g_hdr.ship_to_org_id          := NULL;
    oe_order_pub.g_hdr.invoice_to_org_id       := NULL;
    oe_order_pub.g_hdr.order_category_code     := NULL;
    oe_order_pub.g_hdr.ordered_date            := NULL;
    oe_order_pub.g_hdr.pricing_date            := NULL;
    oe_order_pub.g_hdr.request_date            := NULL;
    oe_order_pub.g_hdr.freight_terms_code      := NULL;
    oe_order_pub.g_hdr.payment_term_id         := NULL;
    oe_order_pub.g_hdr.shipping_method_code    := NULL;
    oe_order_pub.g_hdr.end_customer_id         := NULL; -- CHG0041897
  
    x_status         := 'S';
    x_status_message := NULL;
  EXCEPTION
    WHEN OTHERS THEN
      x_status         := 'E';
      x_status_message := 'ERROR: While calling build header pricing and qualifier contexts. ' ||
		  SQLERRM;
  END build_header_contexts;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0034837 - This procedure calls standard Oracle API to build all line level Qualifier and
  --          Pricing attributes based on various Order level and line level inputs received
  --          as input
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                           Description
  -- 1.0  10/03/2015  Diptasurjya Chatterjee(TCS)    CHG0034837 - Initial Build
  -- 1.1  25/05/2017  yuval tal                      CHG0040839   modify build_line_contexts set attribute1 ..10 line/header
  -- 1.2  18/12/2017  Diptasurjya                    CHG0041897 - Add end customer ID for building contexts
  -- 1.3  29/01/2019  Diptasurjya                    CHG0044970 - Changes related to return lines
  -- --------------------------------------------------------------------------------------------

  PROCEDURE build_line_contexts(p_order_header             IN xxqp_pricereq_header_tab_type,
		        p_lines                    IN xxqp_pricereq_lines_tab_type,
		        x_l_pricing_contexts_tbl   OUT qp_attr_mapping_pub.contexts_result_tbl_type,
		        x_l_qualifier_contexts_tbl OUT qp_attr_mapping_pub.contexts_result_tbl_type,
		        x_status                   OUT VARCHAR2,
		        x_status_message           OUT VARCHAR2) IS
  
  BEGIN
  
    oe_order_pub.g_hdr.header_id               := g_header_index;
    oe_order_pub.g_hdr.sold_to_org_id          := p_order_header(1)
				  .cust_account_id;
    oe_order_pub.g_hdr.ship_to_org_id          := p_order_header(1)
				  .cust_ship_site_id;
    oe_order_pub.g_hdr.invoice_to_org_id       := p_order_header(1)
				  .cust_bill_site_id;
    oe_order_pub.g_hdr.order_type_id           := p_order_header(1)
				  .transaction_type_id;
    oe_order_pub.g_hdr.price_list_id           := p_order_header(1)
				  .price_list_id;
    oe_order_pub.g_hdr.transactional_curr_code := p_order_header(1).currency;
    oe_order_pub.g_hdr.org_id                  := p_order_header(1).org_id;
    oe_order_pub.g_hdr.order_category_code     := p_order_header(1)
				  .order_category;
    oe_order_pub.g_hdr.freight_terms_code      := p_order_header(1)
				  .freight_terms_code;
    oe_order_pub.g_hdr.payment_term_id         := p_order_header(1)
				  .payment_terms_id;
    oe_order_pub.g_hdr.shipping_method_code    := p_order_header(1)
				  .shipping_method_code;
    oe_order_pub.g_hdr.ordered_date            := nvl(p_order_header(1)
				      .transaction_date,
				      SYSDATE);
    oe_order_pub.g_hdr.pricing_date            := nvl(p_order_header(1)
				      .transaction_date,
				      SYSDATE);
    oe_order_pub.g_hdr.request_date            := nvl(p_order_header(1)
				      .transaction_date,
				      SYSDATE);
    oe_order_pub.g_hdr.end_customer_id         := p_order_header(1)
				  .end_customer_account_id; -- CHG0041897
  
    oe_order_pub.g_hdr.attribute1  := p_order_header(1).attribute1; -- CHG0040839 instance_id
    oe_order_pub.g_hdr.attribute2  := p_order_header(1).attribute2; -- CHG0040839
    oe_order_pub.g_hdr.attribute3  := p_order_header(1).attribute3; -- CHG0040839
    oe_order_pub.g_hdr.attribute4  := p_order_header(1).attribute4; -- CHG0040839
    oe_order_pub.g_hdr.attribute5  := p_order_header(1).attribute5; -- CHG0040839
    oe_order_pub.g_hdr.attribute6  := p_order_header(1).attribute6; -- CHG0040839
    oe_order_pub.g_hdr.attribute7  := p_order_header(1).attribute7; -- CHG0040839
    oe_order_pub.g_hdr.attribute8  := p_order_header(1).attribute8; -- CHG0040839
    oe_order_pub.g_hdr.attribute9  := p_order_header(1).attribute9; -- CHG0040839
    oe_order_pub.g_hdr.attribute10 := p_order_header(1).attribute10; -- CHG0040839
  
    FOR i IN 1 .. p_lines.count
    LOOP
    
      oe_order_pub.g_line.header_id          := g_header_index;
      oe_order_pub.g_line.line_id            := p_lines(i).line_num;
      oe_order_pub.g_line.sold_to_org_id     := p_order_header(1)
				.cust_account_id;
      oe_order_pub.g_line.price_list_id      := p_order_header(1)
				.price_list_id;
      oe_order_pub.g_line.inventory_item_id  := p_lines(i).inventory_item_id;
      oe_order_pub.g_line.order_quantity_uom := p_lines(i).item_uom;
      oe_order_pub.g_line.ordered_quantity   := abs(p_lines(i).quantity); -- CHG0044970 add absolute. Oracle Sales order stores this vield as absolute value
      oe_order_pub.g_line.pricing_quantity   := abs(p_lines(i).quantity); -- CHG0044970 add absolute. Oracle Sales order stores this vield as absolute value
    
      oe_order_pub.g_line.ordered_item      := p_lines(i).item;
      oe_order_pub.g_line.invoice_to_org_id := p_order_header(1)
			           .cust_bill_site_id;
      oe_order_pub.g_line.ship_to_org_id    := p_order_header(1)
			           .cust_ship_site_id;
    
      -- CHG0044970 Set line_category_code as RETURN in case quantity is negative
      IF p_lines(i).quantity < 0 THEN
        oe_order_pub.g_line.line_category_code := 'RETURN';
      ELSE
        oe_order_pub.g_line.line_category_code := 'ORDER';
      END IF;
    
      oe_order_pub.g_line.org_id := p_order_header(1).org_id;
      --OE_ORDER_PUB.G_LINE.ordered_date := null;
      oe_order_pub.g_line.pricing_date         := nvl(p_order_header(1)
				      .transaction_date,
				      SYSDATE);
      oe_order_pub.g_line.request_date         := nvl(p_order_header(1)
				      .transaction_date,
				      SYSDATE);
      oe_order_pub.g_line.line_type_id         := p_order_header(1)
				  .transaction_line_type_id;
      oe_order_pub.g_line.freight_terms_code   := p_order_header(1)
				  .freight_terms_code;
      oe_order_pub.g_line.payment_term_id      := p_order_header(1)
				  .payment_terms_id;
      oe_order_pub.g_line.shipping_method_code := p_order_header(1)
				  .shipping_method_code;
      oe_order_pub.g_line.end_customer_id      := p_order_header(1)
				  .end_customer_account_id; -- CHG0041897
    
      oe_order_pub.g_line.attribute1  := p_lines(i).attribute1; -- CHG0040839
      oe_order_pub.g_line.attribute2  := p_lines(i).attribute2; -- CHG0040839
      oe_order_pub.g_line.attribute3  := p_lines(i).attribute3; -- CHG0040839
      oe_order_pub.g_line.attribute4  := p_lines(i).attribute4; -- CHG0040839
      oe_order_pub.g_line.attribute5  := p_lines(i).attribute5; -- CHG0040839
      oe_order_pub.g_line.attribute7  := p_lines(i).attribute7; -- CHG0040839
      oe_order_pub.g_line.attribute8  := p_lines(i).attribute8; -- CHG0040839
      oe_order_pub.g_line.attribute9  := p_lines(i).attribute9; -- CHG0040839
      oe_order_pub.g_line.attribute10 := p_lines(i).attribute10; -- CHG0040839
    
      qp_attr_mapping_pub.build_contexts(p_request_type_code         => 'ONT',
			     p_pricing_type              => 'L',
			     p_org_id                    => p_order_header(1)
						.org_id,
			     x_price_contexts_result_tbl => x_l_pricing_contexts_tbl,
			     x_qual_contexts_result_tbl  => x_l_qualifier_contexts_tbl);
    
      oe_order_pub.g_line := NULL; -- CHG0040839
      /*    oe_order_pub.g_line.header_id            := NULL;
      oe_order_pub.g_line.line_id              := NULL;
      oe_order_pub.g_line.sold_to_org_id       := NULL;
      oe_order_pub.g_line.price_list_id        := NULL;
      oe_order_pub.g_line.inventory_item_id    := NULL;
      oe_order_pub.g_line.order_quantity_uom   := NULL;
      oe_order_pub.g_line.ordered_quantity     := NULL;
      oe_order_pub.g_line.pricing_quantity     := NULL;
      oe_order_pub.g_line.ordered_item         := NULL;
      oe_order_pub.g_line.invoice_to_org_id    := NULL;
      oe_order_pub.g_line.ship_to_org_id       := NULL;
      oe_order_pub.g_line.line_category_code   := NULL;
      oe_order_pub.g_line.org_id               := NULL;
      oe_order_pub.g_line.pricing_date         := NULL;
      oe_order_pub.g_line.request_date         := NULL;
      oe_order_pub.g_line.line_type_id         := NULL;
      oe_order_pub.g_line.freight_terms_code   := NULL;
      oe_order_pub.g_line.payment_term_id      := NULL;
      oe_order_pub.g_line.shipping_method_code := NULL;*/
      --rollback;
    
      EXIT;
    END LOOP;
    oe_order_pub.g_hdr := NULL; -- CHG0040839
    /*   oe_order_pub.g_hdr.header_id               := NULL;
    oe_order_pub.g_hdr.transactional_curr_code := NULL;
    oe_order_pub.g_hdr.sold_to_org_id          := NULL;
    oe_order_pub.g_hdr.order_type_id           := NULL;
    oe_order_pub.g_hdr.price_list_id           := NULL;
    oe_order_pub.g_hdr.org_id                  := NULL;
    oe_order_pub.g_hdr.ship_to_org_id          := NULL;
    oe_order_pub.g_hdr.invoice_to_org_id       := NULL;
    oe_order_pub.g_hdr.order_category_code     := NULL;
    oe_order_pub.g_hdr.freight_terms_code      := NULL;
    oe_order_pub.g_hdr.payment_term_id         := NULL;
    oe_order_pub.g_hdr.shipping_method_code    := NULL;
    oe_order_pub.g_hdr.ordered_date            := NULL;
    oe_order_pub.g_hdr.pricing_date            := NULL;
    oe_order_pub.g_hdr.request_date            := NULL;*/
  
    x_status         := 'S';
    x_status_message := NULL;
  EXCEPTION
    WHEN OTHERS THEN
      x_status         := 'E';
      x_status_message := 'ERROR: While calling build header pricing and qualifier contexts. ' ||
		  SQLERRM;
  END build_line_contexts;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0034837 - This procedure will be used for creating debug log from fetched context attribute
  --          values
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  30/04/2015  Diptasurjya Chatterjee (TCS)    CHG0034837 - Initial Build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE print_debug_output(p_pricing_contexts_tbl   IN qp_attr_mapping_pub.contexts_result_tbl_type,
		       p_qualifier_contexts_tbl IN qp_attr_mapping_pub.contexts_result_tbl_type,
		       p_level                  IN VARCHAR2) IS
  
  BEGIN
    oe_debug_pub.add('SSYS CUSTOM: ' || p_level || ' PRICING CONTEXTS');
    oe_debug_pub.add('SSYS CUSTOM: ' || '-------------------------------' ||
	         '-------------------------------' ||
	         '-------------------------------');
    oe_debug_pub.add('SSYS CUSTOM: ' || rpad('CONTEXT_NAME', 30, ' ') ||
	         rpad('ATTRIBUTE_NAME', 30, ' ') ||
	         rpad('ATTRIBUTE_VALUE', 30, ' '));
    oe_debug_pub.add('SSYS CUSTOM: ' || '-------------------------------' ||
	         '-------------------------------' ||
	         '-------------------------------');
    FOR k IN 1 .. p_pricing_contexts_tbl.count
    LOOP
      oe_debug_pub.add('SSYS CUSTOM: ' ||
	           rpad(p_pricing_contexts_tbl(k).context_name,
		    30,
		    ' ') ||
	           rpad(p_pricing_contexts_tbl(k).attribute_name,
		    30,
		    ' ') ||
	           rpad(p_pricing_contexts_tbl(k).attribute_value,
		    30,
		    ' '));
    END LOOP;
  
    oe_debug_pub.add('SSYS CUSTOM: ' || '-------------------------------' ||
	         '-------------------------------' ||
	         '-------------------------------');
    oe_debug_pub.add('SSYS CUSTOM: ' || ' QUALIFIER CONTEXTS');
    oe_debug_pub.add('SSYS CUSTOM: ' || '-------------------------------' ||
	         '-------------------------------' ||
	         '-------------------------------');
    oe_debug_pub.add('SSYS CUSTOM: ' || rpad('CONTEXT_NAME', 30, ' ') ||
	         rpad('ATTRIBUTE_NAME', 30, ' ') ||
	         rpad('ATTRIBUTE_VALUE', 30, ' '));
    oe_debug_pub.add('SSYS CUSTOM: ' || '-------------------------------' ||
	         '-------------------------------' ||
	         '-------------------------------');
    FOR k IN 1 .. p_qualifier_contexts_tbl.count
    LOOP
      oe_debug_pub.add('SSYS CUSTOM: ' ||
	           rpad(p_qualifier_contexts_tbl(k).context_name,
		    30,
		    ' ') ||
	           rpad(p_qualifier_contexts_tbl(k).attribute_name,
		    30,
		    ' ') ||
	           rpad(p_qualifier_contexts_tbl(k).attribute_value,
		    30,
		    ' '));
    END LOOP;
  
    oe_debug_pub.add('SSYS CUSTOM: ' || '-------------------------------' ||
	         '-------------------------------' ||
	         '-------------------------------');
  
  END print_debug_output;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0041897 - This procedure will be used for creating debug log after custom attribute setting
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  27/11/2017  Diptasurjya Chatterjee (TCS)    CHG0041897 - Initial Build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE print_debug_output2(p_qual_tbl      IN qp_preq_grp.qual_tbl_type,
		        p_line_attr_tbl IN qp_preq_grp.line_attr_tbl_type) IS
  
  BEGIN
    oe_debug_pub.add('-------------------------------------------------------------------------------------------------');
    oe_debug_pub.add('SSYS CUSTOM: PRICING ATTRIBUTE VALUES after setting custom attributes sent by calling application');
    oe_debug_pub.add('-------------------------------------------------------------------------------------------------');
    oe_debug_pub.add('SSYS CUSTOM: ' || ' PRICING CONTEXTS');
    oe_debug_pub.add('SSYS CUSTOM: ' || '------------' ||
	         '-------------------------------' ||
	         '-------------------------------' ||
	         '-------------------------------');
    oe_debug_pub.add('SSYS CUSTOM: ' || rpad('LINE_INDEX', 12, ' ') ||
	         rpad('CONTEXT_NAME', 30, ' ') ||
	         rpad('ATTRIBUTE_NAME', 30, ' ') ||
	         rpad('ATTRIBUTE_VALUE', 30, ' '));
    oe_debug_pub.add('SSYS CUSTOM: ' || '-------------------------------' ||
	         '-------------------------------' ||
	         '-------------------------------');
    FOR k IN 1 .. p_line_attr_tbl.count
    LOOP
      oe_debug_pub.add('SSYS CUSTOM: ' ||
	           rpad(p_line_attr_tbl(k).line_index, 12, ' ') ||
	           rpad(p_line_attr_tbl(k).pricing_context, 30, ' ') ||
	           rpad(p_line_attr_tbl(k).pricing_attribute, 30, ' ') ||
	           rpad(p_line_attr_tbl(k).pricing_attr_value_from,
		    30,
		    ' '));
    END LOOP;
    oe_debug_pub.add('-------------------------------------------------------------------------------------------------');
    oe_debug_pub.add('SSYS CUSTOM: QUALIFIER ATTRIBUTE VALUES after setting custom attributes sent by calling application');
    oe_debug_pub.add('SSYS CUSTOM: ' || '-------------------------------' ||
	         '-------------------------------' ||
	         '-------------------------------');
    oe_debug_pub.add('SSYS CUSTOM: ' || ' QUALIFIER CONTEXTS');
    oe_debug_pub.add('SSYS CUSTOM: ' || '------------' ||
	         '-------------------------------' ||
	         '-------------------------------' ||
	         '-------------------------------');
    oe_debug_pub.add('SSYS CUSTOM: ' || rpad('LINE_INDEX', 12, ' ') ||
	         rpad('CONTEXT_NAME', 30, ' ') ||
	         rpad('ATTRIBUTE_NAME', 30, ' ') ||
	         rpad('ATTRIBUTE_VALUE', 30, ' '));
    oe_debug_pub.add('SSYS CUSTOM: ' || '------------' ||
	         '-------------------------------' ||
	         '-------------------------------' ||
	         '-------------------------------');
    FOR k IN 1 .. p_qual_tbl.count
    LOOP
      oe_debug_pub.add('SSYS CUSTOM: ' ||
	           rpad(p_qual_tbl(k).line_index, 12, ' ') ||
	           rpad(p_qual_tbl(k).qualifier_context, 30, ' ') ||
	           rpad(p_qual_tbl(k).qualifier_attribute, 30, ' ') ||
	           rpad(p_qual_tbl(k).qualifier_attr_value_from,
		    30,
		    ' '));
    END LOOP;
  
    oe_debug_pub.add('SSYS CUSTOM: ' || '------------' ||
	         '-------------------------------' ||
	         '-------------------------------' ||
	         '-------------------------------');
  
  END print_debug_output2;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0034837 - This function calculates the Order Volume attribute value using the same logic as
  --          present in the Oracle Standard function QP_SOURCING_API_PUB.Get_Order_Weight_Or_Volume.
  --
  --          Important: In case of change in calculation logic of the standard function the same
  --                     must be reflected here.
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  30/04/2015  Diptasurjya Chatterjee (TCS)    CHG0034837 - Initial Build
  -- --------------------------------------------------------------------------------------------

  FUNCTION fetch_order_volume_attr(p_item_lines IN xxecom.xxqp_pricereq_lines_tab_type)
    RETURN VARCHAR2 IS
    l_item_id               NUMBER;
    l_quantity              NUMBER;
    l_item_uom              VARCHAR2(30);
    l_line_vol_uom_prof_val VARCHAR2(30);
  
    l_order_total NUMBER;
    l_uom_rate    NUMBER;
  BEGIN
    l_order_total           := 0;
    l_line_vol_uom_prof_val := fnd_profile.value('QP_LINE_VOLUME_UOM_CODE');
  
    FOR j IN 1 .. p_item_lines.count
    LOOP
      l_item_id  := p_item_lines(j).inventory_item_id;
      l_quantity := p_item_lines(j).quantity;
      l_item_uom := p_item_lines(j).item_uom;
    
      inv_convert.inv_um_conversion(l_item_uom,
			l_line_vol_uom_prof_val,
			l_item_id,
			l_uom_rate);
    
      IF l_uom_rate > 0 THEN
        l_order_total := (l_order_total + trunc(l_uom_rate * l_quantity, 2));
      ELSE
        IF g_debug_flag = 'Y' THEN
          oe_debug_pub.add('SSYS CUSTOM: ' ||
		   'No conversion information is available for converting from ' ||
		   l_item_uom || ' TO ' || l_line_vol_uom_prof_val ||
		   ' for Item ' || p_item_lines(j).item);
        END IF;
        --RETURN NULL;
      END IF;
    END LOOP;
  
    RETURN qp_number.number_to_canonical(l_order_total);
  END;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0041715 - This function fetches Minimum End date for a give Modifier Line ID
  --                       This funtion will consider header end date if line end date is blank
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  26/06/2017  Diptasurjya Chatterjee (TCS)    CHG0041715 - Initial Build
  -- 1.1  05/08/2018  Diptasurjya                     CTASK0036572 - Qualifier end date should be considered
  -- --------------------------------------------------------------------------------------------
  FUNCTION fetch_modifier_end_date(p_list_line_id      IN NUMBER,
		           p_adjustment_number IN NUMBER, -- CTASK0036572 Qualifier end date change
		           p_qual_attributes   IN xxqp_pricereq_attr_tab_type)
    RETURN DATE IS
    --  CTASK0036572 Qualifier end date change
    l_modifier_end_date DATE := NULL; -- CTASK0036572 Qualifier end date change
  
    l_list_header_id     NUMBER; -- CTASK0036572 Qualifier end date change
    l_qualifier_end_date DATE := NULL; -- CTASK0036572 Qualifier end date change
  
    l_final_end_date DATE; -- CTASK0036572 Qualifier end date change
  BEGIN
    -- CTASK0036572 Start - Qualifier end date change
    l_qualifier_end_date := g_high_date_const;
  
    SELECT qll.list_header_id
    INTO   l_list_header_id
    FROM   qp_list_lines qll
    WHERE  qll.list_line_id = p_list_line_id;
  
    --dbms_output.put_line('Here: '||l_list_header_id||' '||p_adjustment_number);
  
    IF p_qual_attributes IS NOT NULL AND p_qual_attributes.count > 0 THEN
      FOR i IN 1 .. p_qual_attributes.count
      LOOP
        IF p_qual_attributes(i).context_type = 'QUALIFIER' AND p_qual_attributes(i)
           .line_adj_num = p_adjustment_number THEN
          BEGIN
	--dbms_output.put_line('In loop: '||p_qual_attributes(i).context||' '||p_qual_attributes(i).attribute_col||' '||p_qual_attributes(i).attr_value_from||' '||
	--p_qual_attributes(i).attr_value_to||' '||p_qual_attributes(i).qual_comp_operator_code||' List line: '||p_list_line_id||' '||l_list_header_id);
	SELECT nvl(qq.end_date_active, g_high_date_const)
	INTO   l_qualifier_end_date
	FROM   qp_qualifiers qq
	WHERE  (qq.list_line_id = p_list_line_id OR
	       (qq.list_header_id = l_list_header_id AND
	       qq.list_line_id = -1)) -- Check for header level qualifiers also
	AND    qq.qualifier_context = p_qual_attributes(i).context
	AND    qq.qualifier_attribute = p_qual_attributes(i)
	      .attribute_col
	AND    qq.qualifier_attr_value = p_qual_attributes(i)
	      .attr_value_from
	AND    nvl(qq.qualifier_attr_value_to, 'XXNODATA') =
	       nvl(p_qual_attributes(i).attr_value_to, 'XXNODATA')
	AND    qq.comparison_operator_code = p_qual_attributes(i)
	      .qual_comp_operator_code
	AND    SYSDATE BETWEEN nvl(qq.start_date_active, SYSDATE - 1) AND
	       nvl(qq.end_date_active, SYSDATE + 1)
	AND    rownum = 1
	AND    nvl(qq.end_date_active, g_high_date_const) <
	       l_qualifier_end_date;
          
	--dbms_output.put_line('here 2: '||p_qual_attributes(i).context||' '||p_qual_attributes(i).attribute_col||' '||p_qual_attributes(i).attr_value_from||' '||l_qualifier_end_date);
          EXCEPTION
	WHEN no_data_found THEN
	  NULL;
	  --dbms_output.put_line('here 2: '||p_qual_attributes(i).context||' '||p_qual_attributes(i).attribute_col||' '||p_qual_attributes(i).attr_value_from||' NO DATA FOUND');
          END;
        END IF;
      END LOOP;
    END IF;
    -- CTASK0036572 End - Qualifier end date change
  
    --dbms_output.put_line('here 3: '||to_char(l_qualifier_end_date,'dd-MON-rrrr'));
  
    SELECT decode(qlh.end_date_active,
	      NULL,
	      qll.end_date_active,
	      qlh.end_date_active)
    INTO   l_modifier_end_date -- CTASK0036572 Qualifier end date change
    FROM   qp_list_lines       qll,
           qp_list_headers_all qlh
    WHERE  qll.list_line_id = p_list_line_id
    AND    qll.list_header_id = qlh.list_header_id;
  
    -- CTASK0036572 Start - Qualifier end date change
    l_final_end_date := least(nvl(l_modifier_end_date, g_high_date_const),
		      l_qualifier_end_date);
  
    IF l_final_end_date = g_high_date_const THEN
      l_final_end_date := NULL;
    END IF;
    -- CTASK0036572 End - Qualifier end date change
  
    RETURN l_final_end_date;
  END;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0041715 - This function fetches Modifier ID from modifier name
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  26/06/2017  Diptasurjya Chatterjee (TCS)    CHG0041715 - Initial Build
  -- 1.1  05/08/2018  Diptasurjya                     CTASK0036572 - Qualifier end date to be considered
  -- 1.2  05/08/2018  Diptasurjya                     CTASK0036580 - 0 amount discounts should not be
  --                                                  considered for modifier string creation
  -- 1.3  11/09/2018  Diptasurjya                     CHG0044153-CTASK0039215 - Error while generating string for Other Item Discount generated lines
  --                                                  The adjustment index provided by standard pricing API
  --                                                  for OID generated lines is not a valid line adj index as per the
  --                                                  modifier information generated by pricing API causing no_data_found
  --                                                  A exception check for no_data_found sould be included and in exception
  --                                                  block check should be done against the related line adj index
  -- --------------------------------------------------------------------------------------------
  FUNCTION fetch_modifier_info_str(p_adjustment_level       VARCHAR2,
		           p_list_line_id           IN NUMBER,
		           p_adj_amount             IN NUMBER,
		           p_adjustment_number      IN NUMBER,
		           p_modifier_details_out   IN xxqp_pricereq_mod_tab_type, -- CTASK0036572
		           p_qual_attributes        IN xxqp_pricereq_attr_tab_type, -- CTASK0036572
		           p_related_adjustment_out IN xxqp_pricereq_reltd_tab_type) -- CTASK0036572
   RETURN VARCHAR2 IS
    l_adj_str      VARCHAR2(1000);
    l_mod_end_date DATE;
  
    l_related_end_date     DATE;
    l_related_list_line_id NUMBER;
  BEGIN
    IF p_adj_amount <> 0 THEN
      -- CTASK0036580
      -- CTASK0036572 - Start
      l_related_end_date := g_high_date_const;
      IF p_related_adjustment_out IS NOT NULL AND
         p_related_adjustment_out.count > 0 THEN
      
        FOR rel_rec IN (SELECT t1.line_adj_num
		FROM   TABLE(CAST(p_related_adjustment_out AS
			      xxqp_pricereq_reltd_tab_type)) t1
		WHERE  t1.related_line_adj_num = p_adjustment_number
		AND    t1.line_adj_num <> p_adjustment_number)
        LOOP
          BEGIN
	-- CTASK0039215
	SELECT t2.list_line_id
	INTO   l_related_list_line_id
	FROM   TABLE(CAST(p_modifier_details_out AS
		      xxqp_pricereq_mod_tab_type)) t2
	WHERE  t2.line_adj_num = rel_rec.line_adj_num;
          EXCEPTION
	WHEN no_data_found THEN
	  -- CTASK0039215 start - exception block added
	  SELECT t2.list_line_id
	  INTO   l_related_list_line_id
	  FROM   TABLE(CAST(p_modifier_details_out AS
		        xxqp_pricereq_mod_tab_type)) t2
	  WHERE  t2.line_adj_num = p_adjustment_number;
          END; -- CTASK0039215 end
        
          l_related_end_date := least(l_related_end_date,
			  nvl(fetch_modifier_end_date(l_related_list_line_id,
					      rel_rec.line_adj_num,
					      p_qual_attributes),
			      g_high_date_const));
        END LOOP;
      END IF;
      -- CTASK0036572 - end
      l_mod_end_date := fetch_modifier_end_date(p_list_line_id,
				p_adjustment_number,
				p_qual_attributes); -- CTASK0036572 - add new parameters
      l_mod_end_date := least(nvl(l_mod_end_date, g_high_date_const),
		      l_related_end_date); -- CTASK0036572
    
      IF l_mod_end_date = g_high_date_const THEN
        l_mod_end_date := NULL;
      END IF;
    
      SELECT 'Discount Program: ' || qlh.name || chr(13) ||
	 'Discount Amount: ' || p_adj_amount || chr(13) || 'End Date: ' ||
	 to_char(l_mod_end_date, 'dd-MON-rrrr') || chr(13) || chr(13)
      INTO   l_adj_str
      FROM   qp_list_headers_all qlh,
	 qp_list_lines       qll
      WHERE  qll.list_line_id = p_list_line_id
      AND    qll.list_header_id = qlh.list_header_id;
    END IF; -- CTASK0036580
  
    RETURN l_adj_str;
  END;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0034837 - This function fetches Item Name from Item ID
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  10/03/2015  Diptasurjya Chatterjee (TCS)    CHG0034837 - Initial Build
  -- --------------------------------------------------------------------------------------------

  FUNCTION fetch_item_name(p_item_id IN NUMBER) RETURN VARCHAR2 IS
    l_item_name     VARCHAR2(30);
    l_master_org_id NUMBER;
  BEGIN
    l_master_org_id := xxinv_utils_pkg.get_master_organization_id();
  
    SELECT segment1
    INTO   l_item_name
    FROM   mtl_system_items_b
    WHERE  organization_id = l_master_org_id
    AND    inventory_item_id = p_item_id;
  
    RETURN l_item_name;
  END;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0044970 - This function fetches Pricelist primary UOM for an item
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date         Name                            Description
  -- 1.0  06-Feb-2019  Diptasurjya Chatterjee (TCS)    CHG0044970 - Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION fetch_pl_primary_uom(p_list_header_id    NUMBER,
		        p_inventory_item_id NUMBER) RETURN VARCHAR2 IS
    l_pl_primary_uom VARCHAR2(10);
  BEGIN
    SELECT qll.product_uom_code
    INTO   l_pl_primary_uom
    FROM   qp_list_lines_v qll
    WHERE  qll.list_header_id = p_list_header_id
    AND    qll.product_id = p_inventory_item_id
    AND    trunc(SYSDATE) BETWEEN nvl(qll.start_date_active, SYSDATE - 1) AND
           nvl(qll.end_date_active, SYSDATE + 1)
    AND    qll.primary_uom_flag = 'Y';
  
    RETURN l_pl_primary_uom;
  END fetch_pl_primary_uom;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0034837 - This function fetches Pricelist rounding factor
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  01/02/2017  Diptasurjya Chatterjee (TCS)    CHG0041897 - Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION fetch_pl_round_factor(p_list_header_id IN NUMBER) RETURN NUMBER IS
    l_round_factor NUMBER;
  BEGIN
    SELECT qc.base_rounding_factor * -1
    INTO   l_round_factor
    FROM   qp_list_headers_all  qh,
           qp_currency_lists_vl qc
    WHERE  qh.currency_header_id = qc.currency_header_id
    AND    qh.list_header_id = p_list_header_id;
  
    RETURN l_round_factor;
  END fetch_pl_round_factor;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0041897 - This function fetches price of an item from input pricelist
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  01/02/2017  Diptasurjya Chatterjee (TCS)    CHG0041897 - Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION fetch_pl_price_for_get_item(p_inventory_item_id NUMBER,
			   p_list_header_id    NUMBER,
			   p_pricing_date      DATE)
    RETURN NUMBER IS
    l_pl_price NUMBER := 0;
  BEGIN
    SELECT operand
    INTO   l_pl_price
    FROM   qp_list_lines_v
    WHERE  product_id = p_inventory_item_id
    AND    list_header_id = p_list_header_id
    AND    trunc(p_pricing_date) BETWEEN
           nvl(start_date_active, SYSDATE - 1) AND
           nvl(end_date_active, SYSDATE + 1);
  
    RETURN l_pl_price;
  END fetch_pl_price_for_get_item;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0034837 - This procedure builds all required input table types and calls the standard Oracle
  --          API QP_PREQ_PUB PRICE_REQEUST. This procedure will calculate both Header and Line
  --          level attributes and call PRICE_REQUEST in BATCH mode.
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  10/03/2015  Diptasurjya Chatterjee (TCS)    CHG0034837 - Initial Build
  -- 1.1  04/11/2015  Diptasurjya Chatterjee (TCS)    CHG0036750 - Set rounding flag for pricing engine call to Q
  -- 1.2  26/06/2017  Diptasurjya Chatterjee(TCS)     CHG0041715 - Set MODLIST attribute explicitly for promo code at both header and line level
  -- 1.3  11/27/2017  Diptasurjya Chatterjee (TCS)    CHG0041897 - Modify procedure to be compatiable with SFDC calls
  -- 1.4  05/08/2018  Diptasurjya                     CTASK0036572 - Qualifier end date change
  -- 1.5  08/30/2018  Diptasurjya                     INC0131607 - The table type variable l_linenum_tab is
  --                                                  set with a list of line numbers which needs to be set with the custom attribute values
  --                                                  If no line number is passed with a custom attribute record, then
  --                                                  all lines of the order will be set with the attribute value.
  --                                                  If specific line number is passed with a custom attribute then only that line number should
  --                                                  be set in the above variable
  --                                                  But this variable is not being initialized during the custom attribute line number determination
  --                                                  This incident is about re-setting this variable for every custom attribute handling
  -- 2.0  01/29/2019  Diptasurjya                     CHG0044970 - Service item pricing handling
  -- 2.1  27/12/2019  Diptasurjya                     CHG0046948 - Add header output string to group total discount amount by modifier type
  -- --------------------------------------------------------------------------------------------

  PROCEDURE price_order_batch(p_order_header           IN xxqp_pricereq_header_tab_type,
		      p_item_lines             IN xxqp_pricereq_lines_tab_type,
		      p_custom_attributes      IN xxobjt.xxqp_pricereq_custatt_tab_type, -- CHG0041897
		      p_debug_flag             IN VARCHAR2,
		      p_pricing_server         IN VARCHAR2,
		      p_request_number         IN VARCHAR2,
		      p_process_xtra_field     IN VARCHAR2, -- CHG0041897
		      p_request_source         IN VARCHAR2, -- CHG0041897
		      x_session_details_out    OUT xxqp_pricereq_session_tab_type,
		      x_order_details_out      OUT xxqp_pricereq_header_tab_type,
		      x_line_details_out       OUT xxqp_pricereq_lines_tab_type,
		      x_modifier_details_out   OUT xxqp_pricereq_mod_tab_type,
		      x_attribute_details_out  OUT xxqp_pricereq_attr_tab_type,
		      x_related_adjustment_out OUT xxqp_pricereq_reltd_tab_type,
		      x_status                 OUT VARCHAR2,
		      x_status_message         OUT VARCHAR2) IS
    /* Start Variable declaration for Price Request API IN OUT Parameters*/
    p_line_tbl             qp_preq_grp.line_tbl_type;
    p_qual_tbl             qp_preq_grp.qual_tbl_type;
    p_line_attr_tbl        qp_preq_grp.line_attr_tbl_type;
    p_line_detail_tbl      qp_preq_grp.line_detail_tbl_type;
    p_line_detail_qual_tbl qp_preq_grp.line_detail_qual_tbl_type;
    p_line_detail_attr_tbl qp_preq_grp.line_detail_attr_tbl_type;
    p_related_lines_tbl    qp_preq_grp.related_lines_tbl_type;
    p_control_rec          qp_preq_grp.control_record_type;
    x_line_tbl             qp_preq_grp.line_tbl_type;
    x_line_qual            qp_preq_grp.qual_tbl_type;
    x_line_attr_tbl        qp_preq_grp.line_attr_tbl_type;
    x_line_detail_tbl      qp_preq_grp.line_detail_tbl_type;
    x_line_detail_qual_tbl qp_preq_grp.line_detail_qual_tbl_type;
    x_line_detail_attr_tbl qp_preq_grp.line_detail_attr_tbl_type;
    x_related_lines_tbl    qp_preq_grp.related_lines_tbl_type;
    x_return_status        VARCHAR2(240);
    x_return_status_text   VARCHAR2(240);
    /* End Variable declaration for Price Request API IN OUT Parameters*/
  
    /* Start local Variable declaration to be sent to pricing engine*/
    l_qual_rec      qp_preq_grp.qual_rec_type;
    l_line_attr_rec qp_preq_grp.line_attr_rec_type;
    l_line_rec      qp_preq_grp.line_rec_type;
    l_rltd_rec      qp_preq_grp.related_lines_rec_type;
    /* End local Variable declaration to be sent to pricing engine*/
  
    /* Start Variable declaration for Build Context */
    l_l_pricing_contexts_tbl   qp_attr_mapping_pub.contexts_result_tbl_type;
    l_l_qualifier_contexts_tbl qp_attr_mapping_pub.contexts_result_tbl_type;
  
    l_h_pricing_contexts_tbl   qp_attr_mapping_pub.contexts_result_tbl_type;
    l_h_qualifier_contexts_tbl qp_attr_mapping_pub.contexts_result_tbl_type;
    /* End Variable declaration for Build Context */
  
    l_line_rec_context xxqp_pricereq_lines_tab_type := xxqp_pricereq_lines_tab_type();
  
    l_session_details_out    xxqp_pricereq_session_tab_type := xxqp_pricereq_session_tab_type();
    l_order_details_out      xxqp_pricereq_header_tab_type := xxqp_pricereq_header_tab_type();
    l_line_details_out       xxqp_pricereq_lines_tab_type := xxqp_pricereq_lines_tab_type();
    l_modifier_details_out   xxqp_pricereq_mod_tab_type := xxqp_pricereq_mod_tab_type();
    l_attribute_details_out  xxqp_pricereq_attr_tab_type := xxqp_pricereq_attr_tab_type();
    l_related_adjustment_out xxqp_pricereq_reltd_tab_type := xxqp_pricereq_reltd_tab_type();
  
    l_order_vol_attr_value VARCHAR2(240);
  
    l_order_total_price    NUMBER := 0;
    l_order_total_discount NUMBER := 0;
    l_prg_line_index       NUMBER := 0;
  
    l_attr_tbl_index NUMBER := 0;
    l_qual_tbl_index NUMBER := 0;
  
    i                    BINARY_INTEGER;
    i_i                  BINARY_INTEGER;
    j_j                  BINARY_INTEGER;
    is_mod_line_eligible VARCHAR2(1) := 'N';
    mod_count            BINARY_INTEGER := 1;
    attr_count           BINARY_INTEGER := 1;
    l_version            VARCHAR2(240);
  
    l_hdr_context_status      VARCHAR2(10) := 'S';
    l_hdr_context_status_msg  VARCHAR2(2000);
    l_line_context_status     VARCHAR2(10) := 'S';
    l_line_context_status_msg VARCHAR2(2000);
    l_main_status             VARCHAR2(10) := 'S';
    l_main_status_message     VARCHAR2(2000);
  
    l_custom_attr_inserted NUMBER := 0; -- CHG0041897
  
    --l_high_date_const       DATE := to_date('31-DEC-4712','dd-MON-rrrr');
  
    l_least_mod_end_date DATE; -- CHG0041897
    l_header_adj_str     VARCHAR2(1000); -- CHG0041897
  
    TYPE line_num_tab_type IS TABLE OF NUMBER INDEX BY BINARY_INTEGER; -- CHG0041897
    l_linenum_tab line_num_tab_type; -- CHG0041897
  
    l_linenum_tab_blank line_num_tab_type; -- INC0131607
  
    l_uom_rate        NUMBER := 1; -- CHG0041897
    l_pl_round_factor NUMBER; -- CHG0041897
  
    l_is_get_item_line VARCHAR2(1) := 'Y';
    /*l_date11  number;
    l_date12  number;
    l_date13  number;
    l_date14  number;*/
  BEGIN
    l_order_vol_attr_value := NULL;
    l_least_mod_end_date   := g_high_date_const;
  
    qp_price_request_context.set_request_id();
  
    /* Prepare the Control Record. This determines the pricing engine functioning */
    p_control_rec.pricing_event            := 'BATCH';
    p_control_rec.calculate_flag           := 'Y';
    p_control_rec.simulation_flag          := 'N';
    p_control_rec.rounding_flag            := 'Q'; --'N'; -- CHG0036750 - Dipta - Round selling price based on profile QP: Selling Price Rounding options
    p_control_rec.manual_discount_flag     := 'N';
    p_control_rec.request_type_code        := 'ONT';
    p_control_rec.source_order_amount_flag := 'Y';
    p_control_rec.temp_table_insert_flag   := 'Y';
  
    --l_date11 := DBMS_UTILITY.GET_TIME;
  
    l_order_vol_attr_value := fetch_order_volume_attr(p_item_lines);
    IF p_debug_flag = 'Y' THEN
      oe_debug_pub.add('SSYS CUSTOM: ' ||
	           'Order Volume Attribute calculated: ' ||
	           l_order_vol_attr_value);
    END IF;
  
    FOR j IN 1 .. p_item_lines.count
    LOOP
      l_line_rec.request_type_code := 'ONT';
      l_line_rec.header_id := g_header_index;
      l_line_rec.line_id := p_item_lines(j).line_num; -- Order Line Id. This can be any thing for this script
      l_line_rec.line_index := '' || p_item_lines(j).line_num || ''; -- Request Line Index
      l_line_rec.line_type_code := 'LINE'; -- LINE or ORDER(Summary Line)
      l_line_rec.pricing_effective_date := nvl(p_order_header(1)
			           .transaction_date,
			           SYSDATE); -- Pricing as of what date ?
      l_line_rec.active_date_first := nvl(p_order_header(1).transaction_date,
			      SYSDATE); -- Can be Ordered Date or Ship Date
      l_line_rec.active_date_second := nvl(p_order_header(1)
			       .transaction_date,
			       SYSDATE); -- Can be Ordered Date or Ship Date
      l_line_rec.active_date_first_type := 'NO TYPE'; -- ORD/SHIP
      l_line_rec.active_date_second_type := 'NO TYPE'; -- ORD/SHIP
      l_line_rec.line_quantity := p_item_lines(j).quantity; -- Ordered Quantity
      l_line_rec.line_uom_code := p_item_lines(j).item_uom; -- Ordered UOM Code
      l_line_rec.currency_code := p_order_header(1).currency; -- Currency Code
      l_line_rec.price_flag := 'Y'; -- Price Flag can have 'Y' , 'N'(No pricing) , 'P'(Phase)
      p_line_tbl(j + 1) := l_line_rec;
    
      IF j = 1 THEN
        l_line_rec_context.extend();
      END IF;
      l_line_rec_context(1) := p_item_lines(j);
    
      build_line_contexts(p_order_header             => p_order_header,
		  p_lines                    => l_line_rec_context,
		  x_l_pricing_contexts_tbl   => l_l_pricing_contexts_tbl,
		  x_l_qualifier_contexts_tbl => l_l_qualifier_contexts_tbl,
		  x_status                   => l_line_context_status,
		  x_status_message           => l_line_context_status_msg);
    
      l_main_status         := l_line_context_status;
      l_main_status_message := l_main_status_message ||
		       l_line_context_status_msg || chr(13);
    
      IF l_main_status = 'E' THEN
        RAISE e_prc_request_exception;
      END IF;
    
      IF p_debug_flag = 'Y' THEN
        print_debug_output(l_l_pricing_contexts_tbl,
		   l_l_qualifier_contexts_tbl,
		   'LINE');
      END IF;
    
      FOR k IN 1 .. l_l_pricing_contexts_tbl.count
      LOOP
        l_line_attr_rec.line_index := p_item_lines(j).line_num;
        l_line_attr_rec.pricing_context := l_l_pricing_contexts_tbl(k)
			       .context_name;
        l_line_attr_rec.pricing_attribute := l_l_pricing_contexts_tbl(k)
			         .attribute_name;
        l_line_attr_rec.pricing_attr_value_from := l_l_pricing_contexts_tbl(k)
				   .attribute_value;
        l_line_attr_rec.validated_flag := 'N';
        l_attr_tbl_index := l_attr_tbl_index + 1;
        p_line_attr_tbl(l_attr_tbl_index) := l_line_attr_rec;
      END LOOP;
    
      FOR k IN 1 .. l_l_qualifier_contexts_tbl.count
      LOOP
        l_qual_rec.line_index := p_item_lines(j).line_num;
        l_qual_rec.qualifier_context := l_l_qualifier_contexts_tbl(k)
			    .context_name;
        l_qual_rec.qualifier_attribute := l_l_qualifier_contexts_tbl(k)
			      .attribute_name;
        l_qual_rec.qualifier_attr_value_from := l_l_qualifier_contexts_tbl(k)
				.attribute_value;
        l_qual_rec.validated_flag := 'N';
        l_qual_tbl_index := l_qual_tbl_index + 1;
        p_qual_tbl(l_qual_tbl_index) := l_qual_rec;
      END LOOP;
    
      /** Added following portion for Order Volume Qualifier addition at Line level */
      l_qual_rec.line_index := p_item_lines(j).line_num;
      l_qual_rec.qualifier_context := 'VOLUME';
      l_qual_rec.qualifier_attribute := 'QUALIFIER_ATTRIBUTE17';
      l_qual_rec.qualifier_attr_value_from := l_order_vol_attr_value;
      l_qual_rec.validated_flag := 'N';
      l_qual_tbl_index := l_qual_tbl_index + 1;
      p_qual_tbl(l_qual_tbl_index) := l_qual_rec;
      /* End Qualifier add portion */
    
      /** CHG0041715 - Start Dipta 5-AUG-2016 - Promo Code*/
      IF p_order_header(1).ask_for_modifier_id IS NOT NULL THEN
        l_qual_rec.line_index := p_item_lines(j).line_num;
        l_qual_rec.qualifier_context := 'MODLIST';
        l_qual_rec.qualifier_attribute := 'QUALIFIER_ATTRIBUTE1';
        l_qual_rec.qualifier_attr_value_from := p_order_header(1)
				.ask_for_modifier_id; --Ask for modifier header ID
        l_qual_rec.comparison_operator_code := '=';
        l_qual_rec.validated_flag := 'N';
        l_qual_tbl_index := l_qual_tbl_index + 1;
        p_qual_tbl(l_qual_tbl_index) := l_qual_rec;
      END IF;
      /* CHG0041715 - End Dipta 5-AUG-2016 - Promo Code*/
    END LOOP;
  
    l_line_rec.request_type_code := 'ONT';
    --l_line_rec.header_id             := g_header_index;
    l_line_rec.line_id := g_header_index; -- Order Line Id. This can be any thing for this script
    l_line_rec.line_index := '' || g_header_index || ''; -- Request Line Index
    l_line_rec.line_type_code := 'ORDER'; -- LINE or ORDER(Summary Line)
    l_line_rec.pricing_effective_date := nvl(p_order_header(1)
			         .transaction_date,
			         SYSDATE); -- Pricing as of what date ?
    l_line_rec.active_date_first := nvl(p_order_header(1).transaction_date,
			    SYSDATE); -- Can be Ordered Date or Ship Date
    l_line_rec.active_date_second := nvl(p_order_header(1).transaction_date,
			     SYSDATE); -- Can be Ordered Date or Ship Date
    l_line_rec.active_date_first_type := 'NO TYPE'; -- ORD/SHIP
    l_line_rec.active_date_second_type := 'NO TYPE'; -- ORD/SHIP
    l_line_rec.currency_code := p_order_header(1).currency; -- Currency Code
    l_line_rec.price_flag := 'Y'; -- Price Flag can have 'Y' , 'N'(No pricing) , 'P'(Phase)
    p_line_tbl(1) := l_line_rec;
  
    build_header_contexts(p_order_header             => p_order_header,
		  x_h_pricing_contexts_tbl   => l_h_pricing_contexts_tbl,
		  x_h_qualifier_contexts_tbl => l_h_qualifier_contexts_tbl,
		  x_status                   => l_hdr_context_status,
		  x_status_message           => l_hdr_context_status_msg);
  
    l_main_status         := l_hdr_context_status;
    l_main_status_message := l_main_status_message ||
		     l_hdr_context_status_msg || chr(13);
  
    IF l_main_status = 'E' THEN
      RAISE e_prc_request_exception;
    END IF;
  
    IF p_debug_flag = 'Y' THEN
      print_debug_output(l_h_pricing_contexts_tbl,
		 l_h_qualifier_contexts_tbl,
		 'HEADER');
    END IF;
  
    FOR k IN 1 .. l_h_pricing_contexts_tbl.count
    LOOP
      l_line_attr_rec.line_index := g_header_index;
      l_line_attr_rec.pricing_context := l_h_pricing_contexts_tbl(k)
			     .context_name;
      l_line_attr_rec.pricing_attribute := l_h_pricing_contexts_tbl(k)
			       .attribute_name;
      l_line_attr_rec.pricing_attr_value_from := l_h_pricing_contexts_tbl(k)
				 .attribute_value;
      l_line_attr_rec.validated_flag := 'N';
      l_attr_tbl_index := l_attr_tbl_index + 1;
      p_line_attr_tbl(l_attr_tbl_index) := l_line_attr_rec;
    END LOOP;
  
    FOR k IN 1 .. l_h_qualifier_contexts_tbl.count
    LOOP
      l_qual_rec.line_index := g_header_index;
      l_qual_rec.qualifier_context := l_h_qualifier_contexts_tbl(k)
			  .context_name;
      l_qual_rec.qualifier_attribute := l_h_qualifier_contexts_tbl(k)
			    .attribute_name;
      l_qual_rec.qualifier_attr_value_from := l_h_qualifier_contexts_tbl(k)
			          .attribute_value;
      l_qual_rec.validated_flag := 'N';
      l_qual_tbl_index := l_qual_tbl_index + 1;
      p_qual_tbl(l_qual_tbl_index) := l_qual_rec;
    END LOOP;
  
    /** Added following portion for Order Volume Qualifier addition at Order level */
    l_qual_rec.line_index := g_header_index;
    l_qual_rec.qualifier_context := 'VOLUME';
    l_qual_rec.qualifier_attribute := 'QUALIFIER_ATTRIBUTE17';
    l_qual_rec.qualifier_attr_value_from := l_order_vol_attr_value;
    l_qual_rec.validated_flag := 'N';
    l_qual_tbl_index := l_qual_tbl_index + 1;
    p_qual_tbl(l_qual_tbl_index) := l_qual_rec;
    /* End Qualifier add portion */
  
    /** Start Dipta 5-AUG-2016 - Promo Code*/
    IF p_order_header(1).ask_for_modifier_id IS NOT NULL THEN
      l_qual_rec.line_index := g_header_index;
      l_qual_rec.qualifier_context := 'MODLIST';
      l_qual_rec.qualifier_attribute := 'QUALIFIER_ATTRIBUTE1';
      l_qual_rec.qualifier_attr_value_from := p_order_header(1)
			          .ask_for_modifier_id; --Ask for modifier header ID
      l_qual_rec.comparison_operator_code := '=';
      l_qual_rec.validated_flag := 'N';
      l_qual_tbl_index := l_qual_tbl_index + 1;
      p_qual_tbl(l_qual_tbl_index) := l_qual_rec;
    END IF;
    /* End Dipta 5-AUG-2016 - Promo Code*/
  
    /* CHG0041897 - Start Custom Attribute value setting */
    /*
    Custom attributes will be received in below format along with their values:
    QUALIFIER|XX_OBJ|XX PROMOTIONAL
    <Attribute Context Type>|<Attribute Context>|<Attribute Name>
    
    Based on data received in above format, the procedure validate_data will determine the attribute column (QUALIFIER_ATTRIBUTE57)
    to be updated and store the same in the input type p_custom_attributes
    
    The value of the custom attributes will be validated using the procedure validate_cust_attributes, this will ensure that
    the values passed via the custom attribute record types are in line with the corresponding value sets
    
    Custom Attribute setting logic:
    1. Loop through all passed custom attributes
    2. Determine all line numbers which needs to be applied with the passed custom attribute
        If line number is sent with custom attribute records then use the specific line number
        Else set attribute for all lines and header
    3. Loop through all determined line numbers
    4. There will be distintly different flows for QUALIFIER/PRICING attributes and for HEADER and LINE level attribute setting
       Header level lines are determined by the line_num = -1
    5. For every attribute that is received, we will remove any attribute values which are calculated using the Oracle standard
       attribute calculation process in procedures build_header_contexts and build_line_contexts.
       This is to overide Oracle calculated values with custom values passed by calling application
    6. Set the custom value passed in the table types p_qual_tbl (for QUALIFIER) and
       p_line_attr_tbl (for PRICING and PRODUCT attributes)
    */
    --dbms_output.put_line('0');
    IF p_custom_attributes IS NOT NULL AND p_custom_attributes.count > 0 THEN
      --dbms_output.put_line('1');
      FOR att_rec IN 1 .. p_custom_attributes.count
      LOOP
        --dbms_output.put_line('2: '||p_custom_attributes.count);
        l_custom_attr_inserted := 0;
        l_linenum_tab          := l_linenum_tab_blank; -- INC0131607
      
        IF p_custom_attributes(att_rec).line_num IS NULL THEN
          FOR lr IN 1 .. p_line_tbl.count
          LOOP
	l_linenum_tab(lr) := p_line_tbl(lr).line_index;
          END LOOP;
        ELSE
          l_linenum_tab(1) := p_custom_attributes(att_rec).line_num;
        END IF;
      
        FOR lnum IN 1 .. l_linenum_tab.count
        LOOP
          IF p_custom_attributes(att_rec)
           .attribute_context_type = 'QUALIFIER' THEN
	-- Qualifier Attributes
	--dbms_output.put_line('3: QUALIFIER');
	IF p_custom_attributes(att_rec)
	 .attribute_sourcing_level IN ('LINE', 'BOTH') AND
	    l_linenum_tab(lnum) <> -1 THEN
	  /*dbms_output.put_line('4: Q LINE BOTH '||l_linenum_tab(lnum) ||' '||
              p_custom_attributes(att_rec).attribute_context||' '||
              p_custom_attributes(att_rec).attribute_column||' '||p_custom_attributes(att_rec).attribute_value);*/
	
	  l_qual_rec.line_index                := l_linenum_tab(lnum);
	  l_qual_rec.qualifier_context         := p_custom_attributes(att_rec)
				      .attribute_context;
	  l_qual_rec.qualifier_attribute       := p_custom_attributes(att_rec)
				      .attribute_column;
	  l_qual_rec.qualifier_attr_value_from := p_custom_attributes(att_rec)
				      .attribute_value;
	  l_qual_rec.validated_flag            := 'N';
	
	  FOR qr IN 1 .. p_qual_tbl.count
	  LOOP
	    IF p_qual_tbl(qr)
	     .line_index = l_linenum_tab(lnum) AND p_qual_tbl(qr)
	       .qualifier_context = p_custom_attributes(att_rec)
	       .attribute_context AND p_qual_tbl(qr).qualifier_attribute = p_custom_attributes(att_rec)
	       .attribute_column THEN
	      p_qual_tbl.delete(qr);
	      p_qual_tbl(qr) := l_qual_rec;
	    
	      l_custom_attr_inserted := l_custom_attr_inserted + 1;
	      EXIT;
	    END IF;
	  END LOOP;
	
	  IF l_custom_attr_inserted = 0 THEN
	    l_qual_tbl_index := l_qual_tbl_index + 1;
	    p_qual_tbl(l_qual_tbl_index) := l_qual_rec;
	  END IF;
	ELSIF p_custom_attributes(att_rec)
	 .attribute_sourcing_level IN ('ORDER', 'BOTH') AND
	       l_linenum_tab(lnum) = -1 THEN
	  --dbms_output.put_line('4: Q ORDER BOTH');
	
	  l_qual_rec.line_index                := l_linenum_tab(lnum);
	  l_qual_rec.qualifier_context         := p_custom_attributes(att_rec)
				      .attribute_context;
	  l_qual_rec.qualifier_attribute       := p_custom_attributes(att_rec)
				      .attribute_column;
	  l_qual_rec.qualifier_attr_value_from := p_custom_attributes(att_rec)
				      .attribute_value;
	  l_qual_rec.validated_flag            := 'N';
	
	  FOR qr IN 1 .. p_qual_tbl.count
	  LOOP
	    IF p_qual_tbl(qr)
	     .line_index = l_linenum_tab(lnum) AND p_qual_tbl(qr)
	       .qualifier_context = p_custom_attributes(att_rec)
	       .attribute_context AND p_qual_tbl(qr).qualifier_attribute = p_custom_attributes(att_rec)
	       .attribute_column THEN
	      p_qual_tbl.delete(qr);
	      p_qual_tbl(qr) := l_qual_rec;
	    
	      l_custom_attr_inserted := l_custom_attr_inserted + 1;
	    
	      EXIT;
	    END IF;
	  END LOOP;
	
	  IF l_custom_attr_inserted = 0 THEN
	    l_qual_tbl_index := l_qual_tbl_index + 1;
	    p_qual_tbl(l_qual_tbl_index) := l_qual_rec;
	  END IF;
	END IF;
          ELSE
	-- Pricing and Product attributes
	--dbms_output.put_line('3: NON QUALIFIER');
	IF p_custom_attributes(att_rec)
	 .attribute_sourcing_level IN ('LINE', 'BOTH') AND
	    l_linenum_tab(lnum) <> -1 THEN
	  --dbms_output.put_line('4: NQ LINE BOTH');
	  l_line_attr_rec.line_index              := l_linenum_tab(lnum);
	  l_line_attr_rec.pricing_context         := p_custom_attributes(att_rec)
				         .attribute_context;
	  l_line_attr_rec.pricing_attribute       := p_custom_attributes(att_rec)
				         .attribute_column;
	  l_line_attr_rec.pricing_attr_value_from := p_custom_attributes(att_rec)
				         .attribute_value;
	  l_line_attr_rec.validated_flag          := 'N';
	
	  FOR pr IN 1 .. p_line_attr_tbl.count
	  LOOP
	    IF p_line_attr_tbl(pr).line_index = l_linenum_tab(lnum) AND p_line_attr_tbl(pr)
	       .pricing_context = p_custom_attributes(att_rec)
	       .attribute_context AND p_line_attr_tbl(pr)
	       .pricing_attribute = p_custom_attributes(att_rec)
	       .attribute_column THEN
	      p_line_attr_tbl.delete(pr);
	      p_line_attr_tbl(pr) := l_line_attr_rec;
	    
	      l_custom_attr_inserted := l_custom_attr_inserted + 1;
	    
	      EXIT;
	    END IF;
	  END LOOP;
	
	  IF l_custom_attr_inserted = 0 THEN
	    l_attr_tbl_index := l_attr_tbl_index + 1;
	    p_line_attr_tbl(l_attr_tbl_index) := l_line_attr_rec;
	  END IF;
	ELSIF p_custom_attributes(att_rec)
	 .attribute_sourcing_level IN ('ORDER', 'BOTH') AND
	       l_linenum_tab(lnum) = -1 THEN
	  --dbms_output.put_line('4: NQ ORDER BOTH');
	  l_line_attr_rec.line_index              := l_linenum_tab(lnum);
	  l_line_attr_rec.pricing_context         := p_custom_attributes(att_rec)
				         .attribute_context;
	  l_line_attr_rec.pricing_attribute       := p_custom_attributes(att_rec)
				         .attribute_column;
	  l_line_attr_rec.pricing_attr_value_from := p_custom_attributes(att_rec)
				         .attribute_value;
	  l_line_attr_rec.validated_flag          := 'N';
	
	  FOR pr IN 1 .. p_line_attr_tbl.count
	  LOOP
	    IF p_line_attr_tbl(pr).line_index = l_linenum_tab(lnum) AND p_line_attr_tbl(pr)
	       .pricing_context = p_custom_attributes(att_rec)
	       .attribute_context AND p_line_attr_tbl(pr)
	       .pricing_attribute = p_custom_attributes(att_rec)
	       .attribute_column THEN
	      p_line_attr_tbl.delete(pr);
	      p_line_attr_tbl(pr) := l_line_attr_rec;
	    
	      l_custom_attr_inserted := l_custom_attr_inserted + 1;
	    
	      EXIT;
	    END IF;
	  END LOOP;
	
	  IF l_custom_attr_inserted = 0 THEN
	    l_attr_tbl_index := l_attr_tbl_index + 1;
	    p_line_attr_tbl(l_attr_tbl_index) := l_line_attr_rec;
	  END IF;
	END IF;
          END IF;
        END LOOP;
      END LOOP;
      --dbms_output.put_line('5');
      IF p_debug_flag = 'Y' THEN
        print_debug_output2(p_qual_tbl, p_line_attr_tbl);
      END IF;
    END IF;
    /* CHG0041897 - End Custom Attribute value setting */
  
    l_main_status_message := l_main_status_message ||
		     'Data Used For API Call: Header: ' ||
		     p_order_header.count || ' Line: ' ||
		     p_item_lines.count || chr(13);
  
    l_version := qp_preq_grp.get_version;
  
    IF p_debug_flag = 'Y' THEN
      oe_debug_pub.add('SSYS CUSTOM: ' || 'Testing version ' || l_version);
    END IF;
  
    --l_date12 := DBMS_UTILITY.GET_TIME;
  
    -- Actual Call to the Pricing Engine
    qp_preq_pub.price_request(p_line_tbl,
		      p_qual_tbl,
		      p_line_attr_tbl,
		      p_line_detail_tbl,
		      p_line_detail_qual_tbl,
		      p_line_detail_attr_tbl,
		      p_related_lines_tbl,
		      p_control_rec,
		      x_line_tbl,
		      x_line_qual,
		      x_line_attr_tbl,
		      x_line_detail_tbl,
		      x_line_detail_qual_tbl,
		      x_line_detail_attr_tbl,
		      x_related_lines_tbl,
		      x_return_status,
		      x_return_status_text);
  
    --l_date13 := DBMS_UTILITY.GET_TIME;
  
    /* PREPARE OUTPUT */
    -------------
    l_main_status_message := l_main_status_message || x_return_status_text ||
		     chr(13);
  
    IF x_return_status = fnd_api.g_ret_sts_success THEN
      l_main_status := 'S';
    ELSE
      l_main_status := 'E';
      RAISE e_prc_request_exception;
    END IF;
  
    -- Prepare Line Output
    i := x_line_tbl.first;
    IF i IS NOT NULL THEN
      mod_count := 1;
      LOOP
        IF i <> g_header_index THEN
          IF x_line_tbl(i)
           .status_code IN
	  ('N',
	   'X',
	   'UPDATED' /*QP_PREQ_GREP.G_STATUS_NEW,QP_PREQ_GREP.G_STATUS_UPDATED,QP_PREQ_GREP.G_STATUS_UNCHANGED*/) THEN
	l_line_details_out.extend();
	l_line_details_out(mod_count) := xxqp_pricereq_lines_rec_type(NULL,
						  NULL,
						  NULL,
						  NULL,
						  NULL,
						  NULL,
						  NULL,
						  NULL,
						  NULL,
						  NULL,
						  NULL,
						  NULL,
						  NULL,
						  NULL,
						  NULL,
						  NULL,
						  NULL,
						  NULL,
						  NULL,
						  NULL,
						  NULL,
						  NULL,
						  NULL,
						  NULL,
						  NULL);
          
	l_line_details_out(mod_count).line_num := x_line_tbl(i)
				      .line_index;
	l_line_details_out(mod_count).item_uom := x_line_tbl(i)
				      .line_uom_code; -- CHG0041897 added
	l_line_details_out(mod_count).priced_uom := x_line_tbl(i)
				        .priced_uom_code; -- CHG0041897 added
          
	i_i := x_related_lines_tbl.first;
	IF i_i IS NOT NULL THEN
	  LOOP
	    IF x_related_lines_tbl(i_i)
	     .line_index = x_line_tbl(i).line_index AND x_related_lines_tbl(i_i)
	       .relationship_type_code = qp_preq_grp.g_generated_line THEN
	      --l_prg_line_index := x_related_lines_tbl(I_I).RELATED_LINE_INDEX;
	      IF l_line_details_out(mod_count)
	       .promotion_line_num IS NOT NULL THEN
	        l_line_details_out(mod_count).promotion_line_num := l_line_details_out(mod_count)
						.promotion_line_num || ',';
	      END IF;
	      l_line_details_out(mod_count).promotion_line_num := l_line_details_out(mod_count)
					          .promotion_line_num || x_related_lines_tbl(i_i)
					          .related_line_index;
	      --exit;
	    END IF;
	  
	    EXIT WHEN i_i = x_related_lines_tbl.last;
	    i_i := x_related_lines_tbl.next(i_i);
	  END LOOP;
	END IF;
	--l_line_details_out(mod_count).promotion_line_num := substr
          
	j_j := x_line_detail_tbl.first;
	IF j_j IS NOT NULL THEN
	  LOOP
	    IF x_line_detail_tbl(j_j)
	     .line_index = x_line_tbl(i).line_index THEN
	      i_i := x_line_detail_attr_tbl.first;
	      IF i_i IS NOT NULL THEN
	        LOOP
	          IF x_line_detail_attr_tbl(i_i)
	           .line_detail_index = x_line_detail_tbl(j_j)
		 .line_detail_index AND x_line_detail_attr_tbl(i_i)
		 .pricing_context = 'ITEM' AND x_line_detail_attr_tbl(i_i)
		 .pricing_attribute = 'PRICING_ATTRIBUTE1' THEN
		l_line_details_out(mod_count).inventory_item_id := x_line_detail_attr_tbl(i_i)
						   .pricing_attr_value_from;
	          
		IF l_line_details_out(mod_count)
		 .inventory_item_id IS NOT NULL THEN
		  l_line_details_out(mod_count).item := fetch_item_name(l_line_details_out(mod_count)
						        .inventory_item_id); -- CHG0048217 added as common
		  EXIT;
		END IF;
	          END IF;
	          EXIT WHEN i_i = x_line_detail_attr_tbl.last;
	          i_i := x_line_detail_attr_tbl.next(i_i);
	        END LOOP;
	      END IF;
	    
	      IF l_line_details_out(mod_count)
	       .inventory_item_id IS NOT NULL THEN
	        EXIT;
	      END IF;
	    END IF;
	    EXIT WHEN j_j = x_line_detail_tbl.last;
	    j_j := x_line_detail_tbl.next(j_j);
	  END LOOP;
	END IF;
          
	-- CHG0041897 Added below portion to set Unit Line price for generated item lines
	i_i := x_related_lines_tbl.first;
	IF i_i IS NOT NULL THEN
	  LOOP
	  
	    IF x_related_lines_tbl(i_i)
	     .related_line_index = x_line_tbl(i).line_index AND x_related_lines_tbl(i_i)
	       .relationship_type_code = qp_preq_grp.g_generated_line THEN
	    
	      BEGIN
	        -- Include check here for O price NEWPRICE adjustmnents only
	        j_j := x_line_detail_tbl.first;
	        IF j_j IS NOT NULL THEN
	          LOOP
		IF x_line_detail_tbl(j_j).line_index = l_line_details_out(mod_count)
		   .line_num AND x_line_detail_tbl(j_j)
		   .line_detail_index = x_related_lines_tbl(i_i)
		   .related_line_detail_index AND x_line_detail_tbl(j_j)
		   .applied_flag = 'Y' THEN
		  BEGIN
		    SELECT 'Y'
		    INTO   l_is_get_item_line
		    FROM   qp_list_lines     qll_p,
		           qp_rltd_modifiers qrm,
		           qp_list_lines     qll_c
		    WHERE  qll_c.list_line_id = x_line_detail_tbl(j_j)
		          .list_line_id
		    AND    qll_c.list_line_id =
		           qrm.to_rltd_modifier_id
		    AND    qrm.rltd_modifier_grp_type = 'BENEFIT'
		    AND    qrm.from_rltd_modifier_id =
		           qll_p.list_line_id
		    AND    qll_p.list_line_type_code = 'PRG'
		    AND    qll_c.arithmetic_operator = 'NEWPRICE'
		    AND    qll_c.operand = 0;
		  EXCEPTION
		    WHEN no_data_found THEN
		      l_is_get_item_line := 'N';
		  END;
		  EXIT;
		END IF;
		EXIT WHEN j_j = x_line_detail_tbl.last;
		j_j := x_line_detail_tbl.next(j_j);
	          END LOOP;
	        END IF;
	      
	        IF l_is_get_item_line = 'Y' THEN
	          l_line_details_out(mod_count).unit_sales_price := fetch_pl_price_for_get_item(p_inventory_item_id => l_line_details_out(mod_count)
										   .inventory_item_id,
								    p_list_header_id    => p_order_header(1)
										   .price_list_id,
								    p_pricing_date      => nvl(p_order_header(1)
										       .transaction_date,
										       SYSDATE));
	          EXIT;
	        END IF;
	      EXCEPTION
	        WHEN no_data_found THEN
	          l_main_status         := 'E';
	          l_main_status_message := l_main_status_message ||
			           'ERROR: PL line price not found for get Item Code: ' ||
			           fetch_item_name(l_line_details_out(mod_count)
					   .inventory_item_id) ||
			           ' PL Name: ' ||
			           xxqp_utils_pkg.get_price_list_name(p_order_header(1)
						          .price_list_id) ||
			           ' Pricing date: ' || p_order_header(1)
			          .transaction_date || chr(13);
	        
	          RAISE e_prc_request_exception;
	        WHEN OTHERS THEN
	          l_main_status         := 'E';
	          l_main_status_message := l_main_status_message ||
			           'UNEXPECTED ERROR: Fetching price for get Item ID: ' ||
			           fetch_item_name(l_line_details_out(mod_count)
					   .inventory_item_id) ||
			           ' PL Name: ' ||
			           xxqp_utils_pkg.get_price_list_name(p_order_header(1)
						          .price_list_id) ||
			           ' Pricing date: ' || p_order_header(1)
			          .transaction_date || ' ' ||
			           SQLERRM || chr(13);
	        
	          RAISE e_prc_request_exception;
	      END;
	    
	    END IF;
	  
	    EXIT WHEN i_i = x_related_lines_tbl.last;
	    i_i := x_related_lines_tbl.next(i_i);
	  END LOOP;
	END IF;
          
	/* CHG0041897 - Start UOM conversion */
	l_uom_rate := 1;
	IF x_line_tbl(i).line_uom_code <> x_line_tbl(i).priced_uom_code THEN
	  inv_convert.inv_um_conversion(x_line_tbl(i).line_uom_code,
			        x_line_tbl(i).priced_uom_code,
			        NULL,
			        l_uom_rate);
	
	  IF l_uom_rate = -99999 THEN
	    l_main_status         := 'E';
	    l_main_status_message := l_main_status_message ||
			     'ERROR: During UOM conversion from ' || x_line_tbl(i)
			    .line_uom_code || ' to ' || x_line_tbl(i)
			    .priced_uom_code || chr(13);
	  
	    RAISE e_prc_request_exception;
	  END IF;
	END IF;
          
	IF l_uom_rate <> 1 THEN
	  BEGIN
	    l_pl_round_factor := fetch_pl_round_factor(p_order_header(1)
				           .price_list_id);
	  EXCEPTION
	    WHEN no_data_found THEN
	      l_main_status         := 'E';
	      l_main_status_message := l_main_status_message ||
			       'ERROR: During fetching round factor for PL ID: ' || p_order_header(1)
			      .price_list_id || chr(13);
	    
	      RAISE e_prc_request_exception;
	  END;
	END IF;
	-- CHG0041897 End
          
	--l_line_details_out(mod_count).inventory_item_id := x_line_detail_tbl(I).inventory_item_id;
	l_line_details_out(mod_count).quantity := x_line_tbl(i)
				      .line_quantity;
          
	-- CHG0041897 - If sales price is not already set then set with line_unit_price, this is as part of
	-- handling get item unit price setting
	IF l_line_details_out(mod_count).unit_sales_price IS NULL THEN
	  l_line_details_out(mod_count).unit_sales_price := x_line_tbl(i)
					    .line_unit_price;
	END IF;
          
	-- CHG0041897 - Start UOM conv and round handling
	IF l_uom_rate <> 1 THEN
	  l_line_details_out(mod_count).adj_unit_sales_price := round((x_line_tbl(i)
						  .adjusted_unit_price *
						   l_uom_rate),
						  l_pl_round_factor);
	ELSE
	  l_line_details_out(mod_count).adj_unit_sales_price := x_line_tbl(i)
					        .adjusted_unit_price;
	END IF;
	-- CHG0041897 - End UOM conv and round handling
          
	l_line_details_out(mod_count).total_line_price := x_line_tbl(i)
					  .line_quantity * l_line_details_out(mod_count)
					  .adj_unit_sales_price;
	--l_line_details_out(mod_count).line_discount := (x_line_tbl(i).line_unit_price - l_line_details_out(mod_count).adj_unit_sales_price) * x_line_tbl(i).line_quantity;  -- CHG0041897 commented
	l_line_details_out(mod_count).line_discount := (l_line_details_out(mod_count)
				           .unit_sales_price - l_line_details_out(mod_count)
				           .adj_unit_sales_price) * x_line_tbl(i)
				          .line_quantity; -- CHG0041897 added
          
	/* CHG0041897 - Start setting source_ref_id */
	BEGIN
	  SELECT t1.source_ref_id
	  INTO   l_line_details_out(mod_count).source_ref_id
	  FROM   TABLE(CAST(p_item_lines AS
		        xxqp_pricereq_lines_tab_type)) t1
	  WHERE  t1.line_num = l_line_details_out(mod_count).line_num;
	EXCEPTION
	  WHEN no_data_found THEN
	    l_line_details_out(mod_count).source_ref_id := NULL;
	END;
	/* CHG0041897 - End setting source_ref_id */
	l_line_details_out(mod_count).request_source := p_request_source; -- CHG0041897 - request source set
          
	IF x_line_tbl(i).line_index <> g_header_index THEN
	  l_order_total_price    := l_order_total_price + l_line_details_out(mod_count)
			   .total_line_price;
	  l_order_total_discount := l_order_total_discount + l_line_details_out(mod_count)
			   .line_discount;
	END IF;
	IF p_debug_flag = 'Y' THEN
	  oe_debug_pub.add('SSYS CUSTOM: ' || 'Calculated Amounts: ' ||
		       l_order_total_price || ' ' ||
		       l_order_total_discount);
	END IF;
	mod_count := mod_count + 1;
          ELSE
	l_main_status         := 'E';
	l_main_status_message := l_main_status_message ||
			 'Error In Line: Line Number: ' || x_line_tbl(i)
			.line_index || '. ERROR Text:' || x_line_tbl(i)
			.status_text || chr(13);
	RAISE e_prc_request_exception;
          END IF;
        END IF;
        EXIT WHEN i = x_line_tbl.last;
        i := x_line_tbl.next(i);
      END LOOP;
    END IF;
  
    /*for line_rec in (SELECT t1.source_ref_id
                     FROM   TABLE(CAST(l_line_details_out AS
                            xxqp_pricereq_lines_tab_type)) t1
                     WHERE  t1.promotion_line_num is not null) loop
    
    end loop;*/
  
    -- Prepare Header Output
    l_order_details_out.extend();
    l_order_details_out(1) := xxqp_pricereq_header_rec_type(NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL); -- CHG0046948
  
    l_order_details_out(1).status := x_return_status;
    l_order_details_out(1).total_price := l_order_total_price;
    l_order_details_out(1).total_discount := l_order_total_discount;
    l_order_details_out(1).currency := p_order_header(1).currency;
    l_order_details_out(1).source_ref_id := p_order_header(1).source_ref_id; --   CHG0041897
    l_order_details_out(1).request_source := p_request_source; -- CHG0041897 - request source set
    IF x_return_status <> 'S' THEN
      l_order_details_out(1).error_message := x_return_status_text || '.' ||
			          ' For details please ask Oracle EBS OM team to check debug log located at - ' ||
			          g_debug_file_name;
    END IF;
  
    -- Prepare Session Output
    l_session_details_out.extend();
    l_session_details_out(1) := xxqp_pricereq_session_rec_type(NULL,
					   NULL,
					   NULL,
					   NULL,
					   NULL,
					   NULL,
					   NULL);
    l_session_details_out(1).request_number := p_request_number;
    l_session_details_out(1).start_date := SYSDATE;
    l_session_details_out(1).debug_log_name := g_debug_file_name;
    l_session_details_out(1).pricing_server := p_pricing_server;
    l_session_details_out(1).request_source := p_request_source; -- CHG0041897 - request source set
  
    -- Prepare Modifier Output
    i := x_line_detail_tbl.first;
    IF i IS NOT NULL THEN
      mod_count := 1;
      LOOP
        is_mod_line_eligible := 'N';
        IF x_line_detail_tbl(i).list_line_type_code <> 'PLL' THEN
          IF x_line_detail_tbl(i).applied_flag = 'Y' THEN
	is_mod_line_eligible := 'Y';
          ELSE
	i_i := x_related_lines_tbl.first;
	IF i_i IS NOT NULL THEN
	  LOOP
	    IF x_related_lines_tbl(i_i)
	     .related_line_index = x_line_detail_tbl(i).line_index AND x_related_lines_tbl(i_i)
	       .related_line_detail_index = x_line_detail_tbl(i)
	       .line_detail_index THEN
	      is_mod_line_eligible := 'Y';
	      EXIT;
	    END IF;
	    EXIT WHEN i_i = x_related_lines_tbl.last;
	    i_i := x_related_lines_tbl.next(i_i);
	  END LOOP;
	END IF;
          END IF;
        
          IF is_mod_line_eligible = 'Y' THEN
	l_modifier_details_out.extend();
	l_modifier_details_out(mod_count) := xxqp_pricereq_mod_rec_type(NULL,
						    NULL,
						    NULL,
						    NULL,
						    NULL,
						    NULL,
						    NULL,
						    NULL,
						    NULL,
						    NULL,
						    NULL,
						    NULL,
						    NULL,
						    NULL,
						    NULL,
						    NULL,
						    NULL,
						    NULL,
						    NULL,
						    NULL,
						    NULL,
						    NULL);
          
	IF x_line_detail_tbl(i).line_index = -1 THEN
	  l_modifier_details_out(mod_count).adjustment_level := 'HEADER';
	ELSE
	  l_modifier_details_out(mod_count).adjustment_level := 'LINE';
	END IF;
          
	l_modifier_details_out(mod_count).line_num := x_line_detail_tbl(i)
				          .line_index;
	l_modifier_details_out(mod_count).line_adj_num := x_line_detail_tbl(i)
					  .line_detail_index;
	l_modifier_details_out(mod_count).list_header_id := x_line_detail_tbl(i)
					    .list_header_id;
	l_modifier_details_out(mod_count).list_line_id := x_line_detail_tbl(i)
					  .list_line_id;
	l_modifier_details_out(mod_count).list_type_code := x_line_detail_tbl(i)
					    .list_line_type_code;
          
	l_modifier_details_out(mod_count).automatic_flag := x_line_detail_tbl(i)
					    .automatic_flag;
	l_modifier_details_out(mod_count).update_allowed := x_line_detail_tbl(i)
					    .override_flag;
	l_modifier_details_out(mod_count).updated_flag := x_line_detail_tbl(i)
					  .updated_flag;
	l_modifier_details_out(mod_count).operand := x_line_detail_tbl(i)
				         .operand_value;
	l_modifier_details_out(mod_count).operand_calculation_code := x_line_detail_tbl(i)
						  .operand_calculation_code;
	l_modifier_details_out(mod_count).adjusted_amount := x_line_detail_tbl(i)
					     .adjustment_amount;
	l_modifier_details_out(mod_count).pricing_phase_id := x_line_detail_tbl(i)
					      .pricing_phase_id;
	l_modifier_details_out(mod_count).accrual_flag := x_line_detail_tbl(i)
					  .accrual_flag;
	l_modifier_details_out(mod_count).modifier_level_code := x_line_detail_tbl(i)
					         .modifier_level_code;
	l_modifier_details_out(mod_count).price_break_type_code := x_line_detail_tbl(i)
					           .price_break_type_code;
	l_modifier_details_out(mod_count).applied_flag := x_line_detail_tbl(i)
					  .applied_flag;
	l_modifier_details_out(mod_count).line_quantity := x_line_detail_tbl(i)
					   .line_quantity;
	l_modifier_details_out(mod_count).request_source := p_request_source; -- CHG0041897 - request source set
	--l_modifier_details_out(mod_count).applied_flag := x_line_detail_tbl(I).applied_flag||' '||x_line_detail_tbl(I).OPERAND_CALCULATION_CODE||' '||x_line_detail_tbl(I).OPERAND_VALUE||' '||x_line_detail_tbl(I).ADJUSTMENT_AMOUNT||' '||x_line_detail_tbl(I).MODIFIER_LEVEL_CODE||' '||x_line_detail_tbl(I).PRICING_PHASE_ID;
	mod_count := mod_count + 1;
          END IF;
        END IF;
        EXIT WHEN i = x_line_detail_tbl.last;
        i := x_line_detail_tbl.next(i);
      END LOOP;
    END IF;
  
    -- Prepare Attribute Output
    attr_count := 1;
    i          := x_line_detail_attr_tbl.first;
    IF i IS NOT NULL THEN
      --attr_count := 1;
      LOOP
      
        j_j := x_line_detail_tbl.first;
        IF j_j IS NOT NULL THEN
          LOOP
	IF x_line_detail_tbl(j_j).line_detail_index = x_line_detail_attr_tbl(i)
	   .line_detail_index AND x_line_detail_tbl(j_j)
	   .list_line_type_code <> 'PLL' THEN
	  l_attribute_details_out.extend();
	  l_attribute_details_out(attr_count) := xxqp_pricereq_attr_rec_type(NULL,
						         NULL,
						         NULL,
						         NULL,
						         NULL,
						         NULL,
						         NULL,
						         NULL,
						         NULL,
						         NULL,
						         NULL,
						         NULL,
						         NULL);
	
	  l_attribute_details_out(attr_count).line_num := x_line_detail_tbl(j_j)
					  .line_index;
	
	  l_attribute_details_out(attr_count).line_adj_num := x_line_detail_attr_tbl(i)
					      .line_detail_index;
	
	  IF l_attribute_details_out(attr_count).line_num = -1 THEN
	    l_attribute_details_out(attr_count).adjustment_level := 'HEADER';
	  ELSE
	    l_attribute_details_out(attr_count).adjustment_level := 'LINE';
	  END IF;
	
	  l_attribute_details_out(attr_count).context_type := 'PRICING_ATTRIBUTE';
	  l_attribute_details_out(attr_count).context := x_line_detail_attr_tbl(i)
					 .pricing_context;
	  l_attribute_details_out(attr_count).attribute_col := x_line_detail_attr_tbl(i)
					       .pricing_attribute;
	  l_attribute_details_out(attr_count).attr_value_from := x_line_detail_attr_tbl(i)
					         .pricing_attr_value_from;
	  l_attribute_details_out(attr_count).attr_value_to := x_line_detail_attr_tbl(i)
					       .pricing_attr_value_to;
	  l_attribute_details_out(attr_count).request_source := p_request_source; -- CHG0041897 - request source set
	  attr_count := attr_count + 1;
	  EXIT;
	END IF;
          
	EXIT WHEN j_j = x_line_detail_tbl.last;
	j_j := x_line_detail_tbl.next(j_j);
          END LOOP;
        END IF;
      
        EXIT WHEN i = x_line_detail_attr_tbl.last;
        i := x_line_detail_attr_tbl.next(i);
      END LOOP;
    END IF;
  
    i := x_line_detail_qual_tbl.first;
    IF i IS NOT NULL THEN
      --attr_count := 1;
      LOOP
      
        l_attribute_details_out.extend();
        l_attribute_details_out(attr_count) := xxqp_pricereq_attr_rec_type(NULL,
						   NULL,
						   NULL,
						   NULL,
						   NULL,
						   NULL,
						   NULL,
						   NULL,
						   NULL,
						   NULL,
						   NULL,
						   NULL,
						   NULL);
      
        j_j := x_line_detail_tbl.first;
        IF j_j IS NOT NULL THEN
          LOOP
	IF x_line_detail_tbl(j_j).line_detail_index = x_line_detail_qual_tbl(i)
	   .line_detail_index THEN
	  l_attribute_details_out(attr_count).line_num := x_line_detail_tbl(j_j)
					  .line_index;
	  EXIT;
	END IF;
          
	EXIT WHEN j_j = x_line_detail_tbl.last;
	j_j := x_line_detail_tbl.next(j_j);
          END LOOP;
        END IF;
      
        l_attribute_details_out(attr_count).line_adj_num := x_line_detail_qual_tbl(i)
					.line_detail_index;
      
        IF l_attribute_details_out(attr_count).line_num = -1 THEN
          l_attribute_details_out(attr_count).adjustment_level := 'HEADER';
        ELSE
          l_attribute_details_out(attr_count).adjustment_level := 'LINE';
        END IF;
      
        l_attribute_details_out(attr_count).context_type := 'QUALIFIER';
        l_attribute_details_out(attr_count).context := x_line_detail_qual_tbl(i)
				       .qualifier_context;
        l_attribute_details_out(attr_count).attribute_col := x_line_detail_qual_tbl(i)
					 .qualifier_attribute;
        l_attribute_details_out(attr_count).attr_value_from := x_line_detail_qual_tbl(i)
					   .qualifier_attr_value_from;
        l_attribute_details_out(attr_count).attr_value_to := x_line_detail_qual_tbl(i)
					 .qualifier_attr_value_to;
        l_attribute_details_out(attr_count).qual_comp_operator_code := x_line_detail_qual_tbl(i)
					           .comparison_operator_code;
        l_attribute_details_out(attr_count).request_source := p_request_source; -- CHG0041897 - request source set
      
        attr_count := attr_count + 1;
      
        EXIT WHEN i = x_line_detail_qual_tbl.last;
        i := x_line_detail_qual_tbl.next(i);
      END LOOP;
    END IF;
  
    /** Start - Prepare Related Adjustments output */
    mod_count := 1;
    i         := x_related_lines_tbl.first;
    IF i IS NOT NULL THEN
      LOOP
        IF x_related_lines_tbl(i).related_line_index IS NOT NULL AND x_related_lines_tbl(i)
           .related_line_detail_index IS NOT NULL THEN
          l_related_adjustment_out.extend();
          l_related_adjustment_out(mod_count) := xxqp_pricereq_reltd_rec_type(NULL,
						      NULL,
						      NULL,
						      NULL,
						      NULL,
						      NULL,
						      NULL);
        
          IF x_related_lines_tbl(i).line_index = -1 THEN
	l_related_adjustment_out(mod_count).adjustment_level := 'HEADER';
          ELSE
	l_related_adjustment_out(mod_count).adjustment_level := 'LINE';
          END IF;
        
          l_related_adjustment_out(mod_count).line_num := x_related_lines_tbl(i)
				          .line_index;
          l_related_adjustment_out(mod_count).line_adj_num := x_related_lines_tbl(i)
					  .line_detail_index;
          l_related_adjustment_out(mod_count).relationship_type_code := x_related_lines_tbl(i)
						.relationship_type_code;
          l_related_adjustment_out(mod_count).related_line_num := x_related_lines_tbl(i)
					      .related_line_index;
          l_related_adjustment_out(mod_count).related_line_adj_num := x_related_lines_tbl(i)
					          .related_line_detail_index;
          l_related_adjustment_out(mod_count).request_source := p_request_source; -- CHG0041897 - request source set
        
          mod_count := mod_count + 1;
        END IF;
      
        EXIT WHEN i = x_related_lines_tbl.last;
        i := x_related_lines_tbl.next(i);
      END LOOP;
    END IF;
    /** End - Prepare Related Adjustments output */
    --dbms_output.put_line('here: 1');
    /* CHG0041897 - Start Prepare extra output for STRATAFORCE */
    IF p_process_xtra_field = 'Y' THEN
      IF p_request_source = 'STRATAFORCE' THEN
        -- Set Minimum modifier end date on order level output
        FOR mr IN 1 .. l_modifier_details_out.count
        LOOP
          IF l_modifier_details_out(mr).applied_flag = 'Y' THEN
	l_least_mod_end_date := least(l_least_mod_end_date,
			      nvl(fetch_modifier_end_date(l_modifier_details_out (mr)
					          .list_line_id,
					          l_modifier_details_out (mr)
					          .line_adj_num, -- CTASK0036572 Qualifier end date change
					          l_attribute_details_out), -- CTASK0036572 Qualifier end date change
			          l_least_mod_end_date));
	--dbms_output.put_line('end date received: '||l_least_mod_end_date);
          END IF;
        END LOOP;
      
        SELECT decode(l_least_mod_end_date,
	          g_high_date_const,
	          NULL,
	          l_least_mod_end_date)
        INTO   l_order_details_out(1).min_modifier_end_date
        FROM   dual;
      
        --dbms_output.put_line('end date final: '||l_order_details_out(1).min_modifier_end_date);
      
        -- Set Adjustment Information on line level output
        FOR mr IN 1 .. l_modifier_details_out.count
        LOOP
          IF l_modifier_details_out(mr).adjustment_level = 'HEADER' AND l_modifier_details_out(mr)
	 .applied_flag = 'Y' THEN
	l_header_adj_str := l_header_adj_str ||
		        fetch_modifier_info_str(l_modifier_details_out (mr)
				        .adjustment_level,
				        l_modifier_details_out (mr)
				        .list_line_id,
				        l_modifier_details_out (mr)
				        .adjusted_amount,
				        l_modifier_details_out (mr)
				        .line_adj_num, -- CTASK0036572 Qualifier end date change
				        NULL, -- CTASK0036572
				        l_attribute_details_out, -- CTASK0036572 Qualifier end date change
				        NULL);
          END IF;
        END LOOP;
      
        FOR lr IN 1 .. l_line_details_out.count
        LOOP
          /* Start UOM conversion */
          l_uom_rate        := 1;
          l_pl_round_factor := NULL;
        
          IF l_line_details_out(lr)
           .item_uom <> l_line_details_out(lr).priced_uom THEN
	inv_convert.inv_um_conversion(l_line_details_out(lr).item_uom,
			      l_line_details_out(lr).priced_uom,
			      NULL,
			      l_uom_rate);
          
	IF l_uom_rate = -99999 THEN
	  l_main_status         := 'E';
	  l_main_status_message := l_main_status_message ||
			   'ERROR: During UOM conversion from ' || l_line_details_out(lr)
			  .item_uom || ' to ' || l_line_details_out(lr)
			  .priced_uom || chr(13);
	
	  RAISE e_prc_request_exception;
	END IF;
          END IF;
        
          IF l_uom_rate <> 1 THEN
	BEGIN
	  l_pl_round_factor := fetch_pl_round_factor(p_order_header(1)
				         .price_list_id);
	EXCEPTION
	  WHEN no_data_found THEN
	    l_main_status         := 'E';
	    l_main_status_message := l_main_status_message ||
			     'ERROR: During fetching round factor for PL ID: ' || p_order_header(1)
			    .price_list_id || chr(13);
	  
	    RAISE e_prc_request_exception;
	END;
          END IF;
          -- End UOM conversion
        
          /*dbms_output.put_line('Test 1: Line Num:' || l_line_details_out(lr)
          .line_num || ' ' || l_line_details_out(lr)
          .item_uom || ' ' || l_line_details_out(lr)
          .priced_uom || ' ' || l_uom_rate);*/
        
          l_line_details_out(lr).item := fetch_item_name(l_line_details_out(lr)
				         .inventory_item_id);
          l_line_details_out(lr).adjustment_info := l_header_adj_str;
          FOR mr IN 1 .. l_modifier_details_out.count
          LOOP
	IF l_line_details_out(lr)
	 .line_num = l_modifier_details_out(mr).line_num AND l_modifier_details_out(mr)
	   .applied_flag = 'Y' THEN
	  BEGIN
	    SELECT 'Y'
	    INTO   l_is_get_item_line
	    FROM   qp_list_lines     qll_p,
	           qp_rltd_modifiers qrm,
	           qp_list_lines     qll_c
	    WHERE  qll_c.list_line_id = l_modifier_details_out(mr)
	          .list_line_id
	    AND    qll_c.list_line_id = qrm.to_rltd_modifier_id
	    AND    qrm.rltd_modifier_grp_type = 'BENEFIT'
	    AND    qrm.from_rltd_modifier_id = qll_p.list_line_id
	    AND    qll_p.list_line_type_code = 'PRG'
	    AND    qll_c.arithmetic_operator = 'NEWPRICE'
	    AND    qll_c.operand = 0;
	  EXCEPTION
	    WHEN no_data_found THEN
	      l_is_get_item_line := 'N';
	  END;
	
	  IF l_is_get_item_line = 'N' THEN
	    IF l_uom_rate <> 1 THEN
	      l_line_details_out(lr).adjustment_info := l_line_details_out(lr)
					.adjustment_info ||
					 fetch_modifier_info_str(l_modifier_details_out(mr)
							 .adjustment_level,
							 l_modifier_details_out(mr)
							 .list_line_id,
							 round(l_modifier_details_out(mr)
							       .adjusted_amount *
							        l_uom_rate * l_line_details_out(lr)
							       .quantity,
							       l_pl_round_factor),
							 l_modifier_details_out(mr)
							 .line_adj_num, -- CTASK0036572 Qualifier end date change
							 l_modifier_details_out, -- CTASK0036572 Qualifier end date change
							 l_attribute_details_out, -- CTASK0036572 Qualifier end date change
							 l_related_adjustment_out); -- CTASK0036572 Qualifier end date change
	    ELSE
	      l_line_details_out(lr).adjustment_info := l_line_details_out(lr)
					.adjustment_info ||
					 fetch_modifier_info_str(l_modifier_details_out  (mr)
							 .adjustment_level,
							 l_modifier_details_out  (mr)
							 .list_line_id,
							 l_modifier_details_out  (mr)
							 .adjusted_amount * l_line_details_out(lr)
							 .quantity,
							 l_modifier_details_out  (mr)
							 .line_adj_num, -- CTASK0036572 Qualifier end date change
							 l_modifier_details_out, -- CTASK0036572 Qualifier end date change
							 l_attribute_details_out, -- CTASK0036572 Qualifier end date change
							 l_related_adjustment_out); -- CTASK0036572 Qualifier end date change
	    END IF;
	  ELSE
	    IF l_uom_rate <> 1 THEN
	      l_line_details_out(lr).adjustment_info := l_line_details_out(lr)
					.adjustment_info ||
					 fetch_modifier_info_str(l_modifier_details_out(mr)
							 .adjustment_level,
							 l_modifier_details_out(mr)
							 .list_line_id,
							 round((l_line_details_out(lr)
							       .unit_sales_price - l_line_details_out(lr)
							       .adj_unit_sales_price) *
							       l_uom_rate * l_line_details_out(lr)
							       .quantity,
							       l_pl_round_factor),
							 l_modifier_details_out(mr)
							 .line_adj_num, -- CTASK0036572 Qualifier end date change
							 l_modifier_details_out, -- CTASK0036572 Qualifier end date change
							 l_attribute_details_out, -- CTASK0036572 Qualifier end date change
							 l_related_adjustment_out); -- CTASK0036572 Qualifier end date change
	    ELSE
	      l_line_details_out(lr).adjustment_info := l_line_details_out(lr)
					.adjustment_info ||
					 fetch_modifier_info_str(l_modifier_details_out(mr)
							 .adjustment_level,
							 l_modifier_details_out(mr)
							 .list_line_id,
							 (l_line_details_out(lr)
							  .unit_sales_price - l_line_details_out(lr)
							  .adj_unit_sales_price) * l_line_details_out(lr)
							 .quantity,
							 l_modifier_details_out(mr)
							 .line_adj_num, -- CTASK0036572 Qualifier end date change
							 l_modifier_details_out, -- CTASK0036572 Qualifier end date change
							 l_attribute_details_out, -- CTASK0036572 Qualifier end date change
							 l_related_adjustment_out); -- CTASK0036572 Qualifier end date change
	    END IF;
	  END IF;
	END IF;
          END LOOP;
        
          l_line_details_out(lr).adjustment_info := rtrim(l_line_details_out(lr)
				          .adjustment_info,
				          chr(13));
        END LOOP;
      
        -- CHG0046948 start
        SELECT listagg(qh.attribute2 || ': ' || p_order_header(1).currency || ' ' ||
	           ltrim(to_char(SUM(t1.line_discount), '999,999,999')) || ' (' ||
	           round(SUM(t1.line_discount) * 100 / l_order_details_out(1)
		     .total_discount,
		     1) || '%)',
	           ' | ') within GROUP(ORDER BY qh.attribute2)
        INTO   l_order_details_out(1).adj_group_by_mod_type
        FROM   TABLE(CAST(l_modifier_details_out AS
		  xxqp_pricereq_mod_tab_type)) t2,
	   TABLE(CAST(l_line_details_out AS
		  xxqp_pricereq_lines_tab_type)) t1,
	   qp_list_lines ql,
	   qp_list_headers_all qh
        WHERE  t2.list_line_id = ql.list_line_id
        AND    ql.list_header_id = qh.list_header_id
        AND    t2.line_num = t1.line_num
        AND    t1.line_discount > 0
        AND    t2.applied_flag = 'Y'
        GROUP  BY qh.attribute2;
        -- CHG0046948 end
      END IF;
    END IF;
    /* CHG0041897 - End */
  
    x_session_details_out    := l_session_details_out;
    x_order_details_out      := l_order_details_out;
    x_line_details_out       := l_line_details_out;
    x_modifier_details_out   := l_modifier_details_out;
    x_attribute_details_out  := l_attribute_details_out;
    x_related_adjustment_out := l_related_adjustment_out;
  
    x_status         := l_main_status;
    x_status_message := l_main_status_message;
    ---------------------------------------------------------------------------------------
  
  EXCEPTION
    WHEN e_prc_request_exception THEN
      x_status         := l_main_status;
      x_status_message := l_main_status_message;
    WHEN OTHERS THEN
      x_status         := 'E';
      x_status_message := l_main_status_message || SQLERRM || chr(13);
  END price_order_batch;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0034837 - This procedure builds all required input table types and calls the standard Oracle
  --          API QP_PREQ_PUB PRICE_REQEUST. This procedure will calculate Line level attributes
  --          and call PRICE_REQUEST in LINE mode.
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  10/03/2015  Diptasurjya Chatterjee (TCS)    CHG0034837 - Initial Build
  -- 1.1  01/13/2016  Diptasurjya Chatterjee (TCS)    CHG0036750 - Change rounding option to Q
  -- 1.2  11/27/2017  Diptasurjya Chatterjee (TCS)    CHG0041897 - Modify procedure to be compatiable with SFDC calls
  -- 1.3  05/08/2018  Diptasurjya                     CTASK0036572 - Qualifier end date change
  -- 1.4  01/29/2019  Diptasurjya                     CHG0044970 - Make changes to price service items
  -- 1.5  10-AUG-2020 Diptasurjya                     CHG0048217 - Fetch Item Code in output for all calls and not specifically for STRATAFORCE
  -- --------------------------------------------------------------------------------------------

  PROCEDURE price_single_line(p_order_header           IN xxqp_pricereq_header_tab_type,
		      p_item_lines             IN xxqp_pricereq_lines_tab_type,
		      p_custom_attributes      IN xxobjt.xxqp_pricereq_custatt_tab_type, -- CHG0041897
		      p_debug_flag             IN VARCHAR2,
		      p_request_source         IN VARCHAR2, -- CHG0041897
		      p_process_xtra_field     IN VARCHAR2, -- CHG0041897
		      x_order_details_out      OUT xxqp_pricereq_header_tab_type,
		      x_line_details_out       OUT xxqp_pricereq_lines_tab_type,
		      x_modifier_details_out   OUT xxqp_pricereq_mod_tab_type,
		      x_attribute_details_out  OUT xxqp_pricereq_attr_tab_type,
		      x_related_adjustment_out OUT xxqp_pricereq_reltd_tab_type,
		      x_status                 OUT VARCHAR2,
		      x_status_message         OUT VARCHAR2) IS
    p_line_tbl             qp_preq_grp.line_tbl_type;
    p_qual_tbl             qp_preq_grp.qual_tbl_type;
    p_line_attr_tbl        qp_preq_grp.line_attr_tbl_type;
    p_line_detail_tbl      qp_preq_grp.line_detail_tbl_type;
    p_line_detail_qual_tbl qp_preq_grp.line_detail_qual_tbl_type;
    p_line_detail_attr_tbl qp_preq_grp.line_detail_attr_tbl_type;
    p_related_lines_tbl    qp_preq_grp.related_lines_tbl_type;
    p_control_rec          qp_preq_grp.control_record_type;
    x_line_tbl             qp_preq_grp.line_tbl_type;
    x_line_qual            qp_preq_grp.qual_tbl_type;
    x_line_attr_tbl        qp_preq_grp.line_attr_tbl_type;
    x_line_detail_tbl      qp_preq_grp.line_detail_tbl_type;
    x_line_detail_qual_tbl qp_preq_grp.line_detail_qual_tbl_type;
    x_line_detail_attr_tbl qp_preq_grp.line_detail_attr_tbl_type;
    x_related_lines_tbl    qp_preq_grp.related_lines_tbl_type;
    x_return_status        VARCHAR2(240);
    x_return_status_text   VARCHAR2(240);
  
    l_qual_rec      qp_preq_grp.qual_rec_type;
    l_line_attr_rec qp_preq_grp.line_attr_rec_type;
    l_line_rec      qp_preq_grp.line_rec_type;
    l_rltd_rec      qp_preq_grp.related_lines_rec_type;
  
    l_l_pricing_contexts_tbl   qp_attr_mapping_pub.contexts_result_tbl_type;
    l_l_qualifier_contexts_tbl qp_attr_mapping_pub.contexts_result_tbl_type;
  
    --l_h_pricing_contexts_Tbl    QP_Attr_Mapping_PUB.Contexts_Result_Tbl_Type;
    --l_h_qualifier_Contexts_Tbl  QP_Attr_Mapping_PUB.Contexts_Result_Tbl_Type;
  
    l_line_rec_context xxqp_pricereq_lines_tab_type := xxqp_pricereq_lines_tab_type();
  
    l_order_details_out      xxqp_pricereq_header_tab_type := xxqp_pricereq_header_tab_type();
    l_line_details_out       xxqp_pricereq_lines_tab_type := xxqp_pricereq_lines_tab_type();
    l_modifier_details_out   xxqp_pricereq_mod_tab_type := xxqp_pricereq_mod_tab_type();
    l_attribute_details_out  xxqp_pricereq_attr_tab_type := xxqp_pricereq_attr_tab_type();
    l_related_adjustment_out xxqp_pricereq_reltd_tab_type := xxqp_pricereq_reltd_tab_type();
  
    l_attr_tbl_index NUMBER := 0;
    l_qual_tbl_index NUMBER := 0;
  
    l_order_vol_attr_value VARCHAR2(240);
    l_custom_attr_inserted NUMBER := 0; -- CHG0041897
  
    i          BINARY_INTEGER;
    j_j        BINARY_INTEGER;
    mod_count  BINARY_INTEGER := 1;
    attr_count BINARY_INTEGER := 1;
    l_version  VARCHAR2(240);
  
    l_line_context_status     VARCHAR2(10) := 'S';
    l_line_context_status_msg VARCHAR2(2000);
    l_main_status             VARCHAR2(10) := 'S';
    l_main_status_message     VARCHAR2(2000);
  
    l_linenum_cust_attr  NUMBER; -- CHG0041897
    l_uom_rate           NUMBER := 1; -- CHG0041897
    l_pl_round_factor    NUMBER; -- CHG0041897
    l_least_mod_end_date DATE; -- CHG0041897
  
    l_is_get_item_line VARCHAR2(1) := 'Y'; -- CHG0041897
  BEGIN
  
    /*  Calculate the Order Volume for line */
    l_order_vol_attr_value := fetch_order_volume_attr(p_item_lines);
    IF p_debug_flag = 'Y' THEN
      oe_debug_pub.add('SSYS CUSTOM: ' ||
	           'Order Volume Attribute calculated: ' ||
	           l_order_vol_attr_value);
    END IF;
  
    /* Prepare the COntrol Record. This determines the pricing engine functioning */
    p_control_rec.pricing_event          := 'LINE';
    p_control_rec.calculate_flag         := 'Y';
    p_control_rec.simulation_flag        := 'N';
    p_control_rec.rounding_flag          := 'Q'; --'N';-- CHG0036750 - Dipta - Round selling price based on profile QP: Selling Price Rounding options
    p_control_rec.manual_discount_flag   := 'N';
    p_control_rec.request_type_code      := 'ONT';
    p_control_rec.temp_table_insert_flag := 'Y';
  
    FOR j IN 1 .. p_item_lines.count
    LOOP
      l_line_rec.request_type_code       := 'ONT';
      l_line_rec.line_id                 := j; -- Order Line Id. This can be any thing for this script
      l_line_rec.line_index              := '' || p_item_lines(j).line_num || ''; -- Request Line Index
      l_line_rec.line_type_code          := 'LINE'; -- LINE or ORDER(Summary Line)
      l_line_rec.pricing_effective_date  := nvl(p_order_header(1)
				.transaction_date,
				SYSDATE); -- Pricing as of what date ?
      l_line_rec.active_date_first       := nvl(p_order_header(1)
				.transaction_date,
				SYSDATE); -- Can be Ordered Date or Ship Date
      l_line_rec.active_date_second      := nvl(p_order_header(1)
				.transaction_date,
				SYSDATE); -- Can be Ordered Date or Ship Date
      l_line_rec.active_date_first_type  := 'NO TYPE'; -- ORD/SHIP
      l_line_rec.active_date_second_type := 'NO TYPE'; -- ORD/SHIP
      l_line_rec.line_quantity           := p_item_lines(j).quantity; -- Ordered Quantity
      l_line_rec.line_uom_code           := p_item_lines(j).item_uom; -- Ordered UOM Code
      l_line_rec.currency_code           := p_order_header(1).currency; -- Currency Code
      l_line_rec.price_flag              := 'Y'; -- Price Flag can have 'Y' , 'N'(No pricing) , 'P'(Phase)
    
      p_line_tbl(j) := l_line_rec;
    
      l_line_rec_context.extend();
      l_line_rec_context(1) := p_item_lines(j);
    
      build_line_contexts(p_order_header             => p_order_header,
		  p_lines                    => l_line_rec_context,
		  x_l_pricing_contexts_tbl   => l_l_pricing_contexts_tbl,
		  x_l_qualifier_contexts_tbl => l_l_qualifier_contexts_tbl,
		  x_status                   => l_line_context_status,
		  x_status_message           => l_line_context_status_msg);
    
      l_main_status         := l_line_context_status;
      l_main_status_message := l_main_status_message ||
		       l_line_context_status_msg || chr(13);
    
      IF l_main_status = 'E' THEN
        RAISE e_prc_request_exception;
      END IF;
    
      IF p_debug_flag = 'Y' THEN
        print_debug_output(l_l_pricing_contexts_tbl,
		   l_l_qualifier_contexts_tbl,
		   'LINE');
      END IF;
    
      FOR k IN 1 .. l_l_pricing_contexts_tbl.count
      LOOP
        l_line_attr_rec.line_index := p_item_lines(j).line_num;
        l_line_attr_rec.pricing_context := l_l_pricing_contexts_tbl(k)
			       .context_name;
        l_line_attr_rec.pricing_attribute := l_l_pricing_contexts_tbl(k)
			         .attribute_name;
        l_line_attr_rec.pricing_attr_value_from := l_l_pricing_contexts_tbl(k)
				   .attribute_value;
        l_line_attr_rec.validated_flag := 'N';
        l_attr_tbl_index := l_attr_tbl_index + 1;
        p_line_attr_tbl(l_attr_tbl_index) := l_line_attr_rec;
      END LOOP;
    
      FOR k IN 1 .. l_l_qualifier_contexts_tbl.count
      LOOP
        l_qual_rec.line_index := p_item_lines(j).line_num;
        l_qual_rec.qualifier_context := l_l_qualifier_contexts_tbl(k)
			    .context_name;
        l_qual_rec.qualifier_attribute := l_l_qualifier_contexts_tbl(k)
			      .attribute_name;
        l_qual_rec.qualifier_attr_value_from := l_l_qualifier_contexts_tbl(k)
				.attribute_value;
        l_qual_rec.validated_flag := 'N';
        l_qual_tbl_index := l_qual_tbl_index + 1;
        p_qual_tbl(l_qual_tbl_index) := l_qual_rec;
      END LOOP;
      /** Added following portion for Order Volume Qualifier addition at Line level */
      l_qual_rec.line_index := p_item_lines(j).line_num;
      l_qual_rec.qualifier_context := 'VOLUME';
      l_qual_rec.qualifier_attribute := 'QUALIFIER_ATTRIBUTE17';
      l_qual_rec.qualifier_attr_value_from := l_order_vol_attr_value;
      l_qual_rec.validated_flag := 'N';
      l_qual_tbl_index := l_qual_tbl_index + 1;
      p_qual_tbl(l_qual_tbl_index) := l_qual_rec;
      /* End Qualifier add portion */
    
      EXIT;
    END LOOP;
  
    /* CHG0041897 - Start Custom Attribute value setting */
    IF p_custom_attributes IS NOT NULL AND p_custom_attributes.count > 0 THEN
      FOR att_rec IN 1 .. p_custom_attributes.count
      LOOP
        l_custom_attr_inserted := 0;
      
        IF p_custom_attributes(att_rec).line_num IS NULL THEN
          FOR lr IN 1 .. p_line_tbl.count
          LOOP
	l_linenum_cust_attr := p_line_tbl(lr).line_index;
          END LOOP;
        ELSE
          l_linenum_cust_attr := p_custom_attributes(att_rec).line_num;
        END IF;
      
        IF p_custom_attributes(att_rec).attribute_context_type = 'QUALIFIER' THEN
          -- Qualifier Attributes
          IF p_custom_attributes(att_rec)
           .attribute_sourcing_level IN ('LINE', 'BOTH') THEN
	l_qual_rec.line_index                := l_linenum_cust_attr;
	l_qual_rec.qualifier_context         := p_custom_attributes(att_rec)
				    .attribute_context;
	l_qual_rec.qualifier_attribute       := p_custom_attributes(att_rec)
				    .attribute_column;
	l_qual_rec.qualifier_attr_value_from := p_custom_attributes(att_rec)
				    .attribute_value;
	l_qual_rec.validated_flag            := 'N';
          
	FOR qr IN 1 .. p_qual_tbl.count
	LOOP
	  IF p_qual_tbl(qr)
	   .line_index = l_linenum_cust_attr AND p_qual_tbl(qr)
	     .qualifier_context = p_custom_attributes(att_rec)
	     .attribute_context AND p_qual_tbl(qr).qualifier_attribute = p_custom_attributes(att_rec)
	     .attribute_column THEN
	    p_qual_tbl.delete(qr);
	    p_qual_tbl(qr) := l_qual_rec;
	  
	    l_custom_attr_inserted := l_custom_attr_inserted + 1;
	    EXIT;
	  END IF;
	END LOOP;
          
	IF l_custom_attr_inserted = 0 THEN
	  l_qual_tbl_index := l_qual_tbl_index + 1;
	  p_qual_tbl(l_qual_tbl_index) := l_qual_rec;
	END IF;
          ELSIF p_custom_attributes(att_rec)
           .attribute_sourcing_level IN ('ORDER', 'BOTH') THEN
	NULL;
          END IF;
        ELSE
          -- Pricing and Product attributes
          IF p_custom_attributes(att_rec)
           .attribute_sourcing_level IN ('LINE', 'BOTH') THEN
	l_line_attr_rec.line_index              := l_linenum_cust_attr;
	l_line_attr_rec.pricing_context         := p_custom_attributes(att_rec)
				       .attribute_context;
	l_line_attr_rec.pricing_attribute       := p_custom_attributes(att_rec)
				       .attribute_column;
	l_line_attr_rec.pricing_attr_value_from := p_custom_attributes(att_rec)
				       .attribute_value;
	l_line_attr_rec.validated_flag          := 'N';
          
	FOR pr IN 1 .. p_line_attr_tbl.count
	LOOP
	  IF p_line_attr_tbl(pr)
	   .line_index = l_linenum_cust_attr AND p_line_attr_tbl(pr)
	     .pricing_context = p_custom_attributes(att_rec)
	     .attribute_context AND p_line_attr_tbl(pr).pricing_attribute = p_custom_attributes(att_rec)
	     .attribute_column THEN
	    p_line_attr_tbl.delete(pr);
	    p_line_attr_tbl(pr) := l_line_attr_rec;
	  
	    l_custom_attr_inserted := l_custom_attr_inserted + 1;
	  
	    EXIT;
	  END IF;
	END LOOP;
          
	IF l_custom_attr_inserted = 0 THEN
	  l_attr_tbl_index := l_attr_tbl_index + 1;
	  p_line_attr_tbl(l_attr_tbl_index) := l_line_attr_rec;
	END IF;
          ELSIF p_custom_attributes(att_rec)
           .attribute_sourcing_level IN ('ORDER', 'BOTH') THEN
	NULL;
          END IF;
        END IF;
      END LOOP;
    END IF;
    /* CHG0041897 - End Custom Attribute value setting */
  
    l_main_status_message := l_main_status_message ||
		     'Data Used For API Call: Header: ' ||
		     p_order_header.count || ' Line: ' ||
		     p_item_lines.count || chr(13);
  
    l_version := qp_preq_grp.get_version;
    IF p_debug_flag = 'Y' THEN
      oe_debug_pub.add('SSYS CUSTOM: ' || 'Testing version ' || l_version);
    END IF;
  
    -- Actual Call to the Pricing Engine
    qp_preq_pub.price_request(p_line_tbl,
		      p_qual_tbl,
		      p_line_attr_tbl,
		      p_line_detail_tbl,
		      p_line_detail_qual_tbl,
		      p_line_detail_attr_tbl,
		      p_related_lines_tbl,
		      p_control_rec,
		      x_line_tbl,
		      x_line_qual,
		      x_line_attr_tbl,
		      x_line_detail_tbl,
		      x_line_detail_qual_tbl,
		      x_line_detail_attr_tbl,
		      x_related_lines_tbl,
		      x_return_status,
		      x_return_status_text);
  
    /* PREPARE OUTPUT */
    -------------
    l_main_status         := x_return_status;
    l_main_status_message := l_main_status_message || x_return_status_text ||
		     chr(13);
  
    IF l_main_status = 'E' THEN
      RAISE e_prc_request_exception;
    END IF;
  
    -- Prepare Header Output
    l_order_details_out.extend();
    l_order_details_out(1) := xxqp_pricereq_header_rec_type(NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL); -- CHG0046948 added
  
    l_order_details_out(1).status := x_return_status;
    l_order_details_out(1).currency := p_order_header(1).currency;
    l_order_details_out(1).source_ref_id := p_order_header(1).source_ref_id; -- CHG0041897
    l_order_details_out(1).request_source := p_request_source; -- CHG0041897 - request source set
    IF x_return_status <> 'S' THEN
      l_order_details_out(1).error_message := x_return_status_text || '.' ||
			          ' For details please ask Oracle EBS OM team to check debug log located at - ' ||
			          g_debug_file_name;
    END IF;
  
    -- Prepare Line Output
    i := x_line_tbl.first;
    IF i IS NOT NULL THEN
      mod_count := 1;
      LOOP
        l_line_details_out.extend();
        l_line_details_out(mod_count) := xxqp_pricereq_lines_rec_type(NULL,
					          NULL,
					          NULL,
					          NULL,
					          NULL,
					          NULL,
					          NULL,
					          NULL,
					          NULL,
					          NULL,
					          NULL,
					          NULL,
					          NULL,
					          NULL,
					          NULL,
					          NULL,
					          NULL,
					          NULL,
					          NULL,
					          NULL,
					          NULL,
					          NULL,
					          NULL,
					          NULL,
					          NULL);
      
        /* CHG0041897 - Start UOM conversion */
        l_uom_rate := 1;
        IF x_line_tbl(i).line_uom_code <> x_line_tbl(i).priced_uom_code THEN
          inv_convert.inv_um_conversion(x_line_tbl(i).line_uom_code,
			    x_line_tbl(i).priced_uom_code,
			    NULL,
			    l_uom_rate);
        
          IF l_uom_rate = -99999 THEN
	l_main_status         := 'E';
	l_main_status_message := l_main_status_message ||
			 'ERROR: During UOM conversion from ' || x_line_tbl(i)
			.line_uom_code || ' to ' || x_line_tbl(i)
			.priced_uom_code || chr(13);
          
	RAISE e_prc_request_exception;
          END IF;
        END IF;
      
        IF l_uom_rate <> 1 THEN
          BEGIN
	l_pl_round_factor := fetch_pl_round_factor(p_order_header(1)
				       .price_list_id);
          EXCEPTION
	WHEN no_data_found THEN
	  l_main_status         := 'E';
	  l_main_status_message := l_main_status_message ||
			   'ERROR: During fetching round factor for PL ID: ' || p_order_header(1)
			  .price_list_id || chr(13);
	
	  RAISE e_prc_request_exception;
          END;
        END IF;
        -- CHG0041897 End
      
        l_line_details_out(mod_count).line_num := x_line_tbl(i).line_index;
        l_line_details_out(mod_count).quantity := x_line_tbl(i)
				  .line_quantity;
        l_line_details_out(mod_count).unit_sales_price := x_line_tbl(i)
				          .line_unit_price;
        l_line_details_out(mod_count).item_uom := x_line_tbl(i)
				  .line_uom_code; -- CHG0041897 added
        l_line_details_out(mod_count).priced_uom := x_line_tbl(i)
				    .priced_uom_code; -- CHG0041897 added
        -- CHG0041897 - Start UOM and round change
        IF l_uom_rate <> 1 THEN
          l_line_details_out(mod_count).adj_unit_sales_price := round((x_line_tbl(i)
					          .adjusted_unit_price *
					           l_uom_rate),
					          l_pl_round_factor);
        ELSE
          l_line_details_out(mod_count).adj_unit_sales_price := x_line_tbl(i)
					    .adjusted_unit_price;
        END IF;
        -- CHG0041897 - End UOM and round change
      
        l_line_details_out(mod_count).total_line_price := x_line_tbl(i)
				          .line_quantity * l_line_details_out(mod_count)
				          .adj_unit_sales_price;
        l_line_details_out(mod_count).line_discount := (x_line_tbl(i)
				       .line_unit_price - l_line_details_out(mod_count)
				       .adj_unit_sales_price) * x_line_tbl(i)
				      .line_quantity;
        l_line_details_out(mod_count).request_source := p_request_source; -- CHG0041897 - request source set
        /* CHG0041897 - Start setting source_ref_id */
        BEGIN
          SELECT t1.source_ref_id
          INTO   l_line_details_out(mod_count).source_ref_id
          FROM   TABLE(CAST(p_item_lines AS xxqp_pricereq_lines_tab_type)) t1
          WHERE  t1.line_num = l_line_details_out(mod_count).line_num;
        EXCEPTION
          WHEN no_data_found THEN
	l_line_details_out(mod_count).source_ref_id := NULL;
        END;
        /* CHG0041897 - End setting source_ref_id */
      
        mod_count := mod_count + 1;
        EXIT WHEN i = x_line_tbl.last;
        i := x_line_tbl.next(i);
      END LOOP;
    END IF;
  
    -- Prepare Modifier Output
    i := x_line_detail_tbl.first;
    IF i IS NOT NULL THEN
      mod_count := 1;
      LOOP
        IF x_line_detail_tbl(i).list_line_type_code <> 'PLL' AND x_line_detail_tbl(i)
           .applied_flag = 'Y' THEN
          l_modifier_details_out.extend();
          l_modifier_details_out(mod_count) := xxqp_pricereq_mod_rec_type(NULL,
						  NULL,
						  NULL,
						  NULL,
						  NULL,
						  NULL,
						  NULL,
						  NULL,
						  NULL,
						  NULL,
						  NULL,
						  NULL,
						  NULL,
						  NULL,
						  NULL,
						  NULL,
						  NULL,
						  NULL,
						  NULL,
						  NULL,
						  NULL,
						  NULL);
        
          l_modifier_details_out(mod_count).line_num := x_line_detail_tbl(i)
				        .line_index;
          l_modifier_details_out(mod_count).list_header_id := x_line_detail_tbl(i)
					  .list_header_id;
          l_modifier_details_out(mod_count).list_line_id := x_line_detail_tbl(i)
					.list_line_id;
          l_modifier_details_out(mod_count).list_type_code := x_line_detail_tbl(i)
					  .list_line_type_code;
          l_modifier_details_out(mod_count).attribute1 := x_line_detail_tbl(i)
				          .applied_flag;
          l_modifier_details_out(mod_count).request_source := p_request_source; -- CHG0041897 - request source set
          l_modifier_details_out(mod_count).adjusted_amount := x_line_detail_tbl(i)
					   .adjustment_amount; -- CHG0041897
        
          mod_count := mod_count + 1;
        END IF;
        EXIT WHEN i = x_line_detail_tbl.last;
        i := x_line_detail_tbl.next(i);
      END LOOP;
    END IF;
  
    /* CHG0041897 - Start Prepare extra output for STRATAFORCE */
    IF p_process_xtra_field = 'Y' THEN
      IF p_request_source = 'STRATAFORCE' THEN
      
        FOR lr IN 1 .. l_line_details_out.count
        LOOP
          /* Start UOM conversion */
          l_uom_rate        := 1;
          l_pl_round_factor := NULL;
        
          IF l_line_details_out(lr)
           .item_uom <> l_line_details_out(lr).priced_uom THEN
	inv_convert.inv_um_conversion(l_line_details_out(lr).item_uom,
			      l_line_details_out(lr).priced_uom,
			      NULL,
			      l_uom_rate);
          
	IF l_uom_rate = -99999 THEN
	  l_main_status         := 'E';
	  l_main_status_message := l_main_status_message ||
			   'ERROR: During UOM conversion from ' || l_line_details_out(lr)
			  .item_uom || ' to ' || l_line_details_out(lr)
			  .priced_uom || chr(13);
	
	  RAISE e_prc_request_exception;
	END IF;
          END IF;
        
          IF l_uom_rate <> 1 THEN
	BEGIN
	  l_pl_round_factor := fetch_pl_round_factor(p_order_header(1)
				         .price_list_id);
	EXCEPTION
	  WHEN no_data_found THEN
	    l_main_status         := 'E';
	    l_main_status_message := l_main_status_message ||
			     'ERROR: During fetching round factor for PL ID: ' || p_order_header(1)
			    .price_list_id || chr(13);
	  
	    RAISE e_prc_request_exception;
	END;
          END IF;
          -- End UOM conversion
        
          /*dbms_output.put_line('Test 1: Line Num:' || l_line_details_out(lr)
          .line_num || ' ' || l_line_details_out(lr)
          .item_uom || ' ' || l_line_details_out(lr)
          .priced_uom || ' ' || l_uom_rate||' '||l_modifier_details_out.count);*/
        
          --l_line_details_out(lr).item := fetch_item_name(l_line_details_out(lr).inventory_item_id);  -- CHG0048217 commented
        
          l_line_details_out(lr).adjustment_info := NULL;
          FOR mr IN 1 .. l_modifier_details_out.count
          LOOP
	--dbms_output.put_line('Test 2: M Line:'||l_modifier_details_out(mr).line_num||' M Applied:'||l_modifier_details_out(mr).applied_flag);
	IF l_line_details_out(lr)
	 .line_num = l_modifier_details_out(mr).line_num /*AND l_modifier_details_out(mr).applied_flag = 'Y'*/
	 THEN
	
	  BEGIN
	    SELECT 'Y'
	    INTO   l_is_get_item_line
	    FROM   qp_list_lines     qll_p,
	           qp_rltd_modifiers qrm,
	           qp_list_lines     qll_c
	    WHERE  qll_c.list_line_id = l_modifier_details_out(mr)
	          .list_line_id
	    AND    qll_c.list_line_id = qrm.to_rltd_modifier_id
	    AND    qrm.rltd_modifier_grp_type = 'BENEFIT'
	    AND    qrm.from_rltd_modifier_id = qll_p.list_line_id
	    AND    qll_p.list_line_type_code = 'PRG'
	    AND    qll_c.arithmetic_operator = 'NEWPRICE'
	    AND    qll_c.operand = 0;
	  EXCEPTION
	    WHEN no_data_found THEN
	      l_is_get_item_line := 'N';
	  END;
	
	  --dbms_output.put_line('Test 3:');
	
	  IF l_is_get_item_line = 'N' THEN
	    IF l_uom_rate <> 1 THEN
	      l_line_details_out(lr).adjustment_info := l_line_details_out(lr)
					.adjustment_info ||
					 fetch_modifier_info_str(l_modifier_details_out(mr)
							 .adjustment_level,
							 l_modifier_details_out(mr)
							 .list_line_id,
							 round(l_modifier_details_out(mr)
							       .adjusted_amount *
							        l_uom_rate * l_line_details_out(lr)
							       .quantity,
							       l_pl_round_factor),
							 NULL, -- CTASK0036572 Qualifier end date change
							 NULL, -- CTASK0036572 Qualifier end date change
							 NULL, -- CTASK0036572 Qualifier end date change
							 NULL); -- CTASK0036572 Qualifier end date change
	    ELSE
	      l_line_details_out(lr).adjustment_info := l_line_details_out(lr)
					.adjustment_info ||
					 fetch_modifier_info_str(l_modifier_details_out(mr)
							 .adjustment_level,
							 l_modifier_details_out(mr)
							 .list_line_id,
							 l_modifier_details_out(mr)
							 .adjusted_amount * l_line_details_out(lr)
							 .quantity,
							 NULL, -- CTASK0036572 Qualifier end date change
							 NULL, -- CTASK0036572 Qualifier end date change
							 NULL, -- CTASK0036572 Qualifier end date change
							 NULL); -- CTASK0036572 Qualifier end date change
	    END IF;
	  ELSE
	    IF l_uom_rate <> 1 THEN
	      l_line_details_out(lr).adjustment_info := l_line_details_out(lr)
					.adjustment_info ||
					 fetch_modifier_info_str(l_modifier_details_out(mr)
							 .adjustment_level,
							 l_modifier_details_out(mr)
							 .list_line_id,
							 round((l_line_details_out(lr)
							       .unit_sales_price - l_line_details_out(lr)
							       .adj_unit_sales_price) *
							       l_uom_rate * l_line_details_out(lr)
							       .quantity,
							       l_pl_round_factor),
							 NULL, -- CTASK0036572 Qualifier end date change
							 NULL, -- CTASK0036572 Qualifier end date change
							 NULL, -- CTASK0036572 Qualifier end date change
							 NULL); -- CTASK0036572 Qualifier end date change
	    ELSE
	      l_line_details_out(lr).adjustment_info := l_line_details_out(lr)
					.adjustment_info ||
					 fetch_modifier_info_str(l_modifier_details_out(mr)
							 .adjustment_level,
							 l_modifier_details_out(mr)
							 .list_line_id,
							 (l_line_details_out(lr)
							  .unit_sales_price - l_line_details_out(lr)
							  .adj_unit_sales_price) * l_line_details_out(lr)
							 .quantity,
							 NULL, -- CTASK0036572 Qualifier end date change
							 NULL, -- CTASK0036572 Qualifier end date change
							 NULL, -- CTASK0036572 Qualifier end date change
							 NULL); -- CTASK0036572 Qualifier end date change
	    END IF;
	  END IF;
	  --dbms_output.put_line('Test 4:');
	END IF;
          END LOOP;
        
          l_line_details_out(lr).adjustment_info := rtrim(l_line_details_out(lr)
				          .adjustment_info,
				          chr(13));
        END LOOP;
      END IF;
    END IF;
    /* CHG0041897 - End */
  
    x_order_details_out    := l_order_details_out;
    x_line_details_out     := l_line_details_out;
    x_modifier_details_out := l_modifier_details_out;
    x_status               := l_main_status;
    x_status_message       := l_main_status_message;
    ---------------------------------------------------------------------------------------
  
  EXCEPTION
    WHEN e_prc_request_exception THEN
      oe_debug_pub.add('SSYS CUSTOM: ERROR in LINE pricing');
      x_status         := l_main_status;
      x_status_message := l_main_status_message;
    WHEN OTHERS THEN
      oe_debug_pub.add('SSYS CUSTOM: ERROR in LINE pricing');
      x_status         := l_main_status;
      x_status_message := l_main_status_message || SQLERRM || chr(13);
  END price_single_line;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0034837 - This function fetches Operating Unit based on Region Code
  --          Not currently used. As calculation logic is not yet defined.
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  10/03/2015  Diptasurjya Chatterjee (TCS)    CHG0034837 - Initial Build
  -- --------------------------------------------------------------------------------------------

  FUNCTION fetch_org_id(p_region_code IN VARCHAR2) RETURN NUMBER IS
    l_org_id NUMBER;
  BEGIN
    IF p_region_code = '01' THEN
      NULL;
    ELSIF p_region_code = 'JP' THEN
      l_org_id := 683;
    END IF;
  
    RETURN l_org_id;
  END;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0034837 - This function fetches Transaction ID based on ORG_ID and Operation from the value
  --          set XXOM_SF2OA_Order_Types_Mapping
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  10/03/2015  Diptasurjya Chatterjee (TCS)    CHG0034837 - Initial Build
  -- --------------------------------------------------------------------------------------------

  FUNCTION fetch_transaction_id(p_org_id       IN NUMBER,
		        p_operation_no IN NUMBER) RETURN NUMBER IS
    l_transaction_type_id NUMBER;
  BEGIN
    SELECT to_number(ffvl.attribute3)
    INTO   l_transaction_type_id
    FROM   fnd_flex_values_vl  ffvl,
           fnd_flex_value_sets ffvs
    WHERE  ffvs.flex_value_set_id = ffvl.flex_value_set_id
    AND    ffvs.flex_value_set_name = g_transaction_value_set
    AND    ffvl.attribute1 = p_operation_no
    AND    ffvl.attribute2 = p_org_id;
  
    RETURN l_transaction_type_id;
  END;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0034837 - This function fetches Transaction Line ID based on ORG_ID and Operation from the value
  --          set XXOM_SF2OA_Order_Types_Mapping
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  10/03/2015  Diptasurjya Chatterjee (TCS)    CHG0034837 - Initial Build
  -- --------------------------------------------------------------------------------------------

  FUNCTION fetch_transaction_line_id(p_org_id       IN NUMBER,
			 p_operation_no IN NUMBER) RETURN NUMBER IS
    l_transaction_line_type_id NUMBER;
  BEGIN
    SELECT to_number(ffvl.attribute4)
    INTO   l_transaction_line_type_id
    FROM   fnd_flex_values_vl  ffvl,
           fnd_flex_value_sets ffvs
    WHERE  ffvs.flex_value_set_id = ffvl.flex_value_set_id
    AND    ffvs.flex_value_set_name = g_transaction_value_set
    AND    ffvl.attribute1 = p_operation_no
    AND    ffvl.attribute2 = p_org_id;
  
    RETURN l_transaction_line_type_id;
  END;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0034837 - This function fetches Order Category from Transaction ID
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  10/03/2015  Diptasurjya Chatterjee (TCS)    CHG0034837 - Initial Build
  -- --------------------------------------------------------------------------------------------

  FUNCTION fetch_order_category(p_transaction_type_id IN NUMBER)
    RETURN VARCHAR2 IS
    l_order_category VARCHAR2(30);
  BEGIN
    SELECT order_category_code
    INTO   l_order_category
    FROM   oe_transaction_types_all
    WHERE  transaction_type_id = p_transaction_type_id;
  
    RETURN l_order_category;
  END;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0034837 - This function fetches Conversion Type from Transaction ID
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  10/03/2015  Diptasurjya Chatterjee (TCS)    CHG0034837 - Initial Build
  -- --------------------------------------------------------------------------------------------

  FUNCTION fetch_conversion_type(p_transaction_type_id IN NUMBER)
    RETURN VARCHAR2 IS
    l_order_category VARCHAR2(30);
  BEGIN
    SELECT order_category_code
    INTO   l_order_category
    FROM   oe_transaction_types_all
    WHERE  transaction_type_id = p_transaction_type_id;
  
    RETURN l_order_category;
  END;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0034837 - This function fetches Currency Code from Price List ID
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  10/03/2015  Diptasurjya Chatterjee (TCS)    CHG0034837 - Initial Build
  -- --------------------------------------------------------------------------------------------

  FUNCTION fetch_currency_code(p_pricelist_id IN NUMBER) RETURN VARCHAR2 IS
    l_currency_code VARCHAR2(30);
  BEGIN
    SELECT currency_code
    INTO   l_currency_code
    FROM   qp_secu_list_headers_vl
    WHERE  list_header_id = p_pricelist_id;
  
    RETURN l_currency_code;
  END;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0034837 - This function fetches Item UOM Code based on Item ID
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  10/03/2015  Diptasurjya Chatterjee (TCS)    CHG0034837 - Initial Build
  -- --------------------------------------------------------------------------------------------

  FUNCTION fetch_item_uom_code(p_item_id IN NUMBER) RETURN VARCHAR2 IS
    l_uom_code      VARCHAR2(30);
    l_master_org_id NUMBER;
  BEGIN
    l_master_org_id := xxinv_utils_pkg.get_master_organization_id();
  
    SELECT primary_uom_code
    INTO   l_uom_code
    FROM   mtl_system_items_b
    WHERE  organization_id = l_master_org_id
    AND    inventory_item_id = p_item_id;
  
    RETURN l_uom_code;
  END;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0041715 - This function fetches Modifier ID from modifier name
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  26/06/2017  Diptasurjya Chatterjee (TCS)    CHG0041715 - Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION fetch_modifier_id(p_ask_for_mod_name IN VARCHAR2) RETURN NUMBER IS
    l_modifier_id NUMBER;
  BEGIN
  
    SELECT qlh.list_header_id
    INTO   l_modifier_id
    FROM   qp_list_headers_all qlh
    WHERE  qlh.name = p_ask_for_mod_name;
  
    RETURN l_modifier_id;
  END;
  --Procedure Declaration
  PROCEDURE get_territory_org_info(p_country        IN VARCHAR2,
		           x_territory_code OUT VARCHAR2,
		           x_org_id         OUT NUMBER,
		           x_ou_unit_name   OUT VARCHAR2,
		           x_error_code     OUT VARCHAR2,
		           x_error_msg      OUT VARCHAR2);
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0041897 - This function fetches Org ID from country code
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  11/27/2017  Diptasurjya Chatterjee (TCS)    CHG0041897 - Initial Build
  -- 1.1  05.06.2018  Lingaraj                        for Strataforce Deployment "xxhz_soa_api_pkg" call removed
  --                                                  xxhz_soa_api_pkg.get_territory_org_info removed
  --                                                  Code added localy
  -- --------------------------------------------------------------------------------------------
  FUNCTION fetch_org_id_for_country(p_country_code IN VARCHAR2) RETURN NUMBER IS
    l_org_id         NUMBER := NULL;
    l_territory_code fnd_territories_vl.territory_code%TYPE;
    l_ou_unit_name   VARCHAR2(50);
    l_error_code     VARCHAR2(5);
    l_error_msg      VARCHAR2(500);
  BEGIN
  
    get_territory_org_info(p_country        => p_country_code,
		   x_territory_code => l_territory_code,
		   x_org_id         => l_org_id,
		   x_ou_unit_name   => l_ou_unit_name,
		   x_error_code     => l_error_code,
		   x_error_msg      => l_error_msg);
    /* SELECT to_number(attribute1)
     INTO l_org_id
     FROM fnd_lookup_values_vl
    WHERE lookup_type = 'XXSERVICE_COUNTRIES_SECURITY'
      AND lookup_code = p_country_code;*/
  
    RETURN l_org_id;
  END;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0034837 - This function checks if Customer Account ID is valid
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  10/03/2015  Diptasurjya Chatterjee (TCS)    CHG0034837 - Initial Build
  -- 1.1  11/27/2017  Diptasurjya Chatterjee (TCS)    CHG0041897 - Check both Account ID and Account Number
  -- --------------------------------------------------------------------------------------------

  FUNCTION check_customer_account(p_cust_account_id     IN NUMBER,
		          p_cust_account_number IN VARCHAR2)
    RETURN NUMBER IS
    l_exists NUMBER := 0;
  BEGIN
    SELECT hca.cust_account_id
    INTO   l_exists
    FROM   hz_cust_accounts hca
    WHERE  hca.cust_account_id =
           nvl(p_cust_account_id, hca.cust_account_id)
    AND    hca.account_number =
           nvl(p_cust_account_number, hca.account_number)
    AND    hca.status = 'A';
  
    RETURN l_exists;
  END;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0034837 - This function checks if Bill-to-Site ID is valid
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  10/03/2015  Diptasurjya Chatterjee (TCS)    CHG0034837 - Initial Build
  -- --------------------------------------------------------------------------------------------

  FUNCTION check_bill_to_site(p_cust_account_id   IN NUMBER,
		      p_cust_bill_site_id IN NUMBER,
		      p_org_id            IN NUMBER) RETURN VARCHAR2 IS
    l_exists NUMBER := 0;
  BEGIN
    SELECT 1
    INTO   l_exists
    FROM   hz_cust_acct_sites_all hcasa,
           hz_cust_site_uses_all  hcsua
    WHERE  hcasa.cust_acct_site_id = hcsua.cust_acct_site_id
    AND    hcasa.cust_account_id = p_cust_account_id
    AND    hcasa.org_id = p_org_id
    AND    hcasa.org_id = hcsua.org_id
    AND    hcsua.site_use_id = p_cust_bill_site_id
    AND    hcsua.site_use_code = 'BILL_TO'
    AND    hcasa.status = 'A'
    AND    hcsua.status = 'A';
  
    RETURN l_exists;
  END;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0034837 - This function checks if Ship-to-Site ID is valid
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  10/03/2015  Diptasurjya Chatterjee (TCS)    CHG0034837 - Initial Build
  -- --------------------------------------------------------------------------------------------

  FUNCTION check_ship_to_site(p_cust_account_id   IN NUMBER,
		      p_cust_ship_site_id IN NUMBER,
		      p_org_id            IN NUMBER) RETURN VARCHAR2 IS
    l_exists NUMBER := 0;
  BEGIN
    SELECT 1
    INTO   l_exists
    FROM   hz_cust_acct_sites_all hcasa,
           hz_cust_site_uses_all  hcsua
    WHERE  hcasa.cust_acct_site_id = hcsua.cust_acct_site_id
    AND    hcasa.cust_account_id = p_cust_account_id
    AND    hcasa.org_id = p_org_id
    AND    hcasa.org_id = hcsua.org_id
    AND    hcsua.site_use_id = p_cust_ship_site_id
    AND    hcsua.site_use_code = 'SHIP_TO'
    AND    hcasa.status = 'A'
    AND    hcsua.status = 'A';
  
    RETURN l_exists;
  END;

  --------------------------------------------------------------------
  --  name:               is_number
  --  create by:          Diptasurjya Chatterjee
  --  $Revision:          1.0
  --  creation date:      12/13/2017
  --  Description:        CHG0041897 - check if a value is number
  --------------------------------------------------------------------
  --  ver   date          name                    desc
  --  1.0   12/13/2017    Diptasurjya Chatterjee  CHG0041897 - initial build
  --------------------------------------------------------------------
  FUNCTION is_number(p_string IN VARCHAR2) RETURN INT IS
    v_new_num NUMBER;
  BEGIN
    v_new_num := to_number(p_string);
    RETURN 1;
  EXCEPTION
    WHEN value_error THEN
      RETURN 0;
  END is_number;

  --------------------------------------------------------------------
  --  name:               validate_value_with_valueset
  --  create by:          Diptasurjya Chatterjee
  --  $Revision:          1.0
  --  creation date:      12/13/2017
  --  Description:        CHG0041897 - This procedure will validate a passed value against
  --                      passed valueset id.
  --                      This procedure will validate for table and independent
  --                      value sets only, for other valueset types please add
  --                      logic here or build your own validation logic
  --                      If a match is found in the value set, the storage
  --                      value i.e. the value to be saved in base table
  --                      will be sent as OUT parameter, otherwise error status
  --                      along with status message NO_DATA_FOUND will be sent as OUT parameter
  --------------------------------------------------------------------
  --  ver   date          name                    desc
  --  1.0   12/13/2017    Diptasurjya Chatterjee  CHG0041897 - initial build
  --  1.1   28-Mar-2019   Diptasurjya             CHG0044970 - Fix valueset validation query build
  --------------------------------------------------------------------
  PROCEDURE validate_value_with_valueset(p_value_set_id         IN NUMBER,
			     p_vset_validation_type IN VARCHAR2,
			     p_value                IN VARCHAR2,
			     x_status               OUT VARCHAR2,
			     x_status_message       OUT VARCHAR2,
			     x_storage_value        OUT VARCHAR2,
			     x_display_value        OUT VARCHAR2 -- CHG0044970 add new out var
			     ) IS
    l_storage_value    VARCHAR2(2000);
    l_additional_where VARCHAR2(2000);
  
    l_value_column_name   VARCHAR2(240);
    l_value_col_type      VARCHAR2(1);
    l_id_column_name      VARCHAR2(240);
    l_id_col_type         VARCHAR2(1);
    l_meaning_column_name VARCHAR2(240);
    l_meaning_col_type    VARCHAR2(1);
  
    l_select       VARCHAR2(4000);
    l_mapping_code VARCHAR2(2000);
    l_success      NUMBER;
  
    l_vset_value         VARCHAR2(2000);
    l_vset_value_id      VARCHAR2(2000);
    l_vset_value_meaning VARCHAR2(2000); -- CHG0044970
  
    l_meaning_col_required VARCHAR2(1); -- CHG0044970
  BEGIN
    --dbms_output.put_line(p_value_set_id||' '||p_vset_validation_type||' '||p_value);
  
    IF p_vset_validation_type = 'I' THEN
      l_value_column_name   := 'FLEX_VALUE';
      l_value_col_type      := 'C';
      l_id_column_name      := 'FLEX_VALUE';
      l_id_col_type         := 'C';
      l_meaning_column_name := 'DESCRIPTION';
      l_meaning_col_type    := 'C';
    ELSE
      SELECT value_column_name,
	 value_column_type,
	 id_column_name,
	 id_column_type,
	 meaning_column_name,
	 meaning_column_type
      INTO   l_value_column_name,
	 l_value_col_type,
	 l_id_column_name,
	 l_id_col_type,
	 l_meaning_column_name,
	 l_meaning_col_type
      FROM   fnd_flex_validation_tables
      WHERE  flex_value_set_id = p_value_set_id;
    
    END IF;
  
    l_additional_where := l_additional_where || ' AND (';
    IF l_value_col_type IN ('C', 'V') THEN
      l_additional_where := l_additional_where || l_value_column_name ||
		    ' = ''' || p_value || '''';
    ELSIF l_value_col_type = 'N' THEN
      l_additional_where := l_additional_where || l_value_column_name ||
		    ' = ' || p_value;
    END IF;
  
    IF l_meaning_column_name IS NOT NULL THEN
      l_additional_where := l_additional_where || ' OR ';
      IF l_meaning_col_type IN ('C', 'V') THEN
        l_additional_where := l_additional_where || l_meaning_column_name ||
		      ' = ''' || p_value || '''';
      ELSIF l_meaning_col_type = 'N' THEN
        l_additional_where := l_additional_where || l_meaning_column_name ||
		      ' = ' || p_value;
      END IF;
    END IF;
  
    IF l_id_column_name IS NOT NULL /* AND is_number(p_value) = 1*/
     THEN
      -- CHG0044970 no need to check for number
      l_additional_where := l_additional_where || ' OR ';
      IF l_id_col_type IN ('C', 'V') THEN
        l_additional_where := l_additional_where || l_id_column_name ||
		      ' = ''' || p_value || '''';
      ELSIF l_id_col_type = 'N' THEN
        l_additional_where := l_additional_where || l_id_column_name ||
		      ' = ' || p_value;
      END IF;
    END IF;
  
    l_additional_where := l_additional_where || ')';
  
    IF p_vset_validation_type = 'F' THEN
      -- CHG0044970 if meaning column defined then fetch meaning column in select
      IF l_meaning_column_name IS NOT NULL THEN
        l_meaning_col_required := 'Y';
      ELSE
        l_meaning_col_required := 'N';
      END IF;
      -- CHG0044970 end
    
      fnd_flex_val_api.get_table_vset_select(p_value_set_id          => p_value_set_id,
			         p_inc_user_where_clause => 'Y',
			         p_inc_meaning_col       => l_meaning_col_required, --'N', CHG0044970 - set as per variable
			         x_select                => l_select,
			         x_mapping_code          => l_mapping_code,
			         x_success               => l_success);
    ELSIF p_vset_validation_type = 'I' THEN
      l_meaning_col_required := 'Y'; -- CHG0044970 always Y
    
      fnd_flex_val_api.get_independent_vset_select(p_value_set_id => p_value_set_id,
				   --p_inc_user_where_clause => 'Y',
				   p_inc_meaning_col => l_meaning_col_required, --'N',  -- CHG0044970 - set as per variable
				   x_select          => l_select,
				   x_mapping_code    => l_mapping_code,
				   x_success         => l_success);
    END IF;
  
    l_select := REPLACE(REPLACE(l_select, chr(13), ' '), chr(10), ' '); -- CHG0044970 remove newline and carriage return characters
  
    IF l_success = 0 THEN
      --l_select := l_select || chr(10) || l_additional_where;  -- CHG0044970 comment
      -- CHG0044970 start
      IF instr(upper(l_select), 'ORDER BY', -1) <> 0 THEN
        l_select := substr(l_select,
		   1,
		   instr(upper(l_select), 'ORDER BY', -1) - 1) || ' ' ||
	        l_additional_where || ' ' ||
	        substr(l_select, instr(upper(l_select), 'ORDER BY', -1));
      ELSE
        l_select := l_select || ' ' || l_additional_where;
      END IF;
      -- CHG0044970 end
      --fnd_file.put_line(fnd_file.log, l_select);
    
      BEGIN
        IF l_id_column_name IS NOT NULL THEN
          IF l_meaning_col_required = 'N' THEN
	-- CHG0044970 check if meaning column added
	EXECUTE IMMEDIATE l_select
	  INTO l_vset_value, l_vset_value_id;
          ELSE
	-- CHG0044970 meaning column added in select
	EXECUTE IMMEDIATE l_select
	  INTO l_vset_value, l_vset_value_id, l_vset_value_meaning; -- CHG0044970 fetch meaning column into new variable
          END IF; -- CHG0044970 end if
        
        ELSE
          IF l_meaning_col_required = 'N' THEN
	-- CHG0044970 check if meaning column added
	EXECUTE IMMEDIATE l_select
	  INTO l_vset_value;
          ELSE
	-- CHG0044970 meaning column added in select
	EXECUTE IMMEDIATE l_select
	  INTO l_vset_value, l_vset_value_meaning; -- CHG0044970 fetch meaning column into new variable
          END IF; -- CHG0044970 end if
        
          l_vset_value_id := l_vset_value;
        END IF;
      
        -- CHG0044970 set display output
        IF l_vset_value_meaning IS NOT NULL THEN
          x_display_value := l_vset_value || ' (' || l_vset_value_meaning || ')';
        ELSE
          x_display_value := l_vset_value;
        END IF;
        -- CHG0044970 end
      
        x_storage_value  := l_vset_value_id;
        x_status         := '0';
        x_status_message := NULL;
      EXCEPTION
        WHEN no_data_found THEN
          x_storage_value  := NULL;
          x_status         := '1';
          x_status_message := 'NO_DATA_FOUND';
          -- CHG0044970 handle other errors below
        WHEN OTHERS THEN
          x_storage_value  := NULL;
          x_status         := '1';
          x_status_message := substr(SQLERRM, 1, 500);
      END;
    ELSE
      x_status         := '1';
      x_status_message := 'Error while validating value with valueset. validate_value_with_valueset: form select query';
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      x_status         := '1';
      x_status_message := 'Unexpected error while value with valueset. validate_value_with_valueset: ' ||
		  SQLERRM;
  END validate_value_with_valueset;

  --------------------------------------------------------------------
  --  name:               validate_cust_attributes
  --  create by:          Diptasurjya Chatterjee
  --  $Revision:          1.0
  --  creation date:      12/13/2017
  --  Description:        CHG0041897 - This is a generic procedure and can be used for validating pricing/qualifier
  --                      attribute values against their assigned value sets.
  --                      If assigned value set is table based or independent this procedure
  --                      will call validate_value_with_valueset to generate value set query dynamically
  --                      and validate passed segment value against the query
  --                      For Other value sets the value passed will be validated
  --                      against other attributes of value set like data format, length,
  --                      precision, max and min values etc
  --                      In case no value set is assigned, value will be passed as-is
  --                      Date type values will be converted to canonical form
  --------------------------------------------------------------------
  --  ver   date          name                    desc
  --  1.0   12/13/2017    Diptasurjya Chatterjee  CHG0041897 - initial build
  --------------------------------------------------------------------
  PROCEDURE validate_cust_attributes(p_custom_attributes IN xxqp_pricereq_custatt_tab_type,
			 x_status            OUT VARCHAR2,
			 x_status_message    OUT VARCHAR2,
			 x_custom_attributes OUT xxqp_pricereq_custatt_tab_type) IS
    l_dff_name        VARCHAR2(200);
    l_dff_title       VARCHAR2(240);
    l_segment_enabled VARCHAR2(1);
    l_col_user_name   VARCHAR2(240);
    l_value_set_name  VARCHAR2(60);
    l_value_set_id    NUMBER;
    l_format_type     VARCHAR2(1);
    l_max_size        NUMBER;
    l_num_precision   NUMBER;
    l_alpha_flag      VARCHAR2(1);
    l_uppercase_flag  VARCHAR2(1);
    l_min_val         NUMBER;
    l_max_value       NUMBER;
    l_numeric_mode    VARCHAR2(1);
    l_validation_type VARCHAR2(1);
  
    l_storage_value VARCHAR2(2000);
    l_display_value VARCHAR2(2000);
    l_success       BOOLEAN;
  
    l_custom_attributes xxqp_pricereq_custatt_tab_type;
  
    l_status         VARCHAR2(10);
    l_status_message VARCHAR2(4000);
  BEGIN
    l_custom_attributes := p_custom_attributes;
  
    FOR i IN 1 .. l_custom_attributes.count
    LOOP
      l_storage_value   := NULL;
      l_value_set_name  := NULL;
      l_value_set_id    := NULL;
      l_format_type     := NULL;
      l_max_size        := NULL;
      l_num_precision   := NULL;
      l_alpha_flag      := NULL;
      l_uppercase_flag  := NULL;
      l_min_val         := NULL;
      l_max_value       := NULL;
      l_numeric_mode    := NULL;
      l_validation_type := NULL;
      l_status          := NULL;
      l_display_value   := NULL;
      l_success         := NULL;
    
      BEGIN
        SELECT uvs.flex_value_set_name,
	   uvs.flex_value_set_id,
	   uvs.format_type,
	   uvs.maximum_size,
	   uvs.number_precision,
	   uvs.alphanumeric_allowed_flag,
	   uvs.uppercase_only_flag,
	   uvs.minimum_value,
	   uvs.maximum_value,
	   uvs.numeric_mode_enabled_flag,
	   uvs.validation_type
        INTO   l_value_set_name,
	   l_value_set_id,
	   l_format_type,
	   l_max_size,
	   l_num_precision,
	   l_alpha_flag,
	   l_uppercase_flag,
	   l_min_val,
	   l_max_value,
	   l_numeric_mode,
	   l_validation_type
        FROM   qp_prc_contexts_v   qpc,
	   qp_segments_v       qs,
	   qp_pte_segments     qps,
	   fnd_flex_value_sets uvs
        WHERE  qpc.prc_context_id = qs.prc_context_id
        AND    qps.segment_id = qs.segment_id
        AND    qps.pte_code = 'ORDFUL'
        AND    qs.user_valueset_id = uvs.flex_value_set_id
        AND    qpc.prc_context_type || '|' || qpc.prc_context_code || '|' ||
	   qs.segment_code = l_custom_attributes(i).attribute_key;
      EXCEPTION
        WHEN no_data_found THEN
          CONTINUE;
      END;
    
      -- **
      IF l_validation_type IN ('F', 'I') THEN
        validate_value_with_valueset(p_value_set_id         => l_value_set_id,
			 p_vset_validation_type => l_validation_type,
			 p_value                => l_custom_attributes(i)
					   .attribute_value,
			 x_status               => l_status,
			 x_status_message       => x_status_message,
			 x_storage_value        => l_storage_value,
			 x_display_value        => l_display_value -- CHG0044970 handle new out var
			 );
        IF l_status = '1' AND x_status_message = 'NO_DATA_FOUND' THEN
          x_status         := 'E';
          l_status_message := l_status_message ||
		      'VALIDATION ERROR: Value: ' || l_custom_attributes(i)
		     .attribute_value ||
		      ' of custom attribute key: ' || l_custom_attributes(i)
		     .attribute_key || ' is not valid' || chr(13);
        ELSIF l_status = '1' THEN
          x_status         := 'E';
          l_status_message := l_status_message ||
		      'UNEXPECTED ERROR: Value: ' || l_custom_attributes(i)
		     .attribute_value ||
		      ' of custom attribute key: ' || l_custom_attributes(i)
		     .attribute_key || ' ' || x_status_message ||
		      chr(13);
        ELSE
          IF l_storage_value <> l_custom_attributes(i).attribute_value THEN
	l_custom_attributes(i).attribute_value := l_storage_value;
          END IF;
        END IF;
      ELSE
        fnd_flex_val_util.validate_value(p_value          => l_custom_attributes(i)
					 .attribute_value,
			     p_vset_name      => l_value_set_name,
			     p_vset_format    => l_format_type,
			     p_max_length     => l_max_size,
			     p_precision      => l_num_precision,
			     p_alpha_allowed  => l_alpha_flag,
			     p_uppercase_only => l_uppercase_flag,
			     p_zero_fill      => l_numeric_mode,
			     p_min_value      => l_min_val,
			     p_max_value      => l_max_value,
			     x_storage_value  => l_storage_value,
			     x_display_value  => l_display_value,
			     x_success        => l_success);
        IF l_success THEN
          NULL;
        ELSE
          x_status         := 'E';
          l_status_message := l_status_message ||
		      'VALIDATION ERROR: Value: ' || l_custom_attributes(i)
		     .attribute_value ||
		      ' of custom attribute key: ' || l_custom_attributes(i)
		     .attribute_key || ' is not valid' || chr(13);
        END IF;
      END IF;
    
      l_custom_attributes(i).attribute3 := substr(l_display_value, 1, 199); -- CHG0044970 set display value in attribute3
    END LOOP;
  
    IF nvl(x_status, 'X') <> 'E' THEN
      x_status            := 'S';
      x_status_message    := NULL;
      x_custom_attributes := l_custom_attributes;
    ELSE
      x_status            := 'E';
      x_status_message    := l_status_message;
      x_custom_attributes := NULL;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      x_status         := 'E';
      x_status_message := 'Unexpected error occurred while validating custom attribute values';
  END validate_cust_attributes;

  --------------------------------------------------------------------
  --  name:               qp_attr_val_translation
  --  create by:          Diptasurjya Chatterjee
  --  $Revision:          1.0
  --  creation date:      03/29/2019
  --  Description:        CHG0044970 - Generic function which can be used to translate
  --                      pricing and qualifier attribute values
  --------------------------------------------------------------------
  --  ver   date          name                    desc
  --  1.0   03/29/2019    Diptasurjya Chatterjee  CHG0044970 - initial build
  --  1.1   02/17/2020    Diptasurjya             CHG0047446 - add new field in custom attribute record type
  --------------------------------------------------------------------
  FUNCTION qp_attr_val_translation(p_context_type      VARCHAR2,
		           p_context           VARCHAR2,
		           p_attr_segment_code VARCHAR2,
		           p_attr_segment_col  VARCHAR2,
		           p_attr_val          VARCHAR2,
		           p_return_type       VARCHAR2)
    RETURN VARCHAR2 IS
    l_custatt_tab_type     xxqp_pricereq_custatt_tab_type := xxqp_pricereq_custatt_tab_type();
    l_custatt_tab_type_out xxqp_pricereq_custatt_tab_type;
  
    l_valid_attr_key VARCHAR2(2000);
  
    l_status         VARCHAR2(20);
    l_status_message VARCHAR2(2000);
  BEGIN
    IF p_attr_val IS NULL THEN
      RETURN NULL;
    END IF;
  
    IF p_return_type NOT IN ('MEANING', 'VALUE') THEN
      --raise_application_error(-20001,'Input error: Valid values for p_return_type are MEANING and VALUE');
      RETURN 'ERROR: Valid values for p_return_type are MEANING and VALUE';
    ELSIF p_attr_segment_code IS NULL AND p_attr_segment_col IS NULL THEN
      --raise_application_error(-20001,'Input error: Either of parameters mandatory: p_attr_segment_code or p_attr_segment_col');
      RETURN 'ERROR: Either of parameters mandatory: p_attr_segment_code or p_attr_segment_col';
    ELSIF p_context_type IS NULL OR p_context IS NULL THEN
      --raise_application_error(-20001,'Input error: Parameters mandatory: p_context_type, p_context, p_attr_val');
      RETURN 'ERROR: Parameters mandatory: p_context_type, p_context';
    ELSE
      BEGIN
        SELECT qc.prc_context_type || '|' || qc.prc_context_code || '|' ||
	   qs.segment_code
        INTO   l_valid_attr_key
        FROM   qp_segments_b     qs,
	   qp_prc_contexts_b qc
        WHERE  qc.prc_context_id = qs.prc_context_id
        AND    qc.prc_context_type = p_context_type
        AND    qc.prc_context_code = p_context
        AND    qs.segment_code = nvl(p_attr_segment_code, qs.segment_code)
        AND    qs.segment_mapping_column =
	   nvl(p_attr_segment_col, qs.segment_mapping_column);
      EXCEPTION
        WHEN no_data_found THEN
          --raise_application_error(-20001,'Input error: Context type, code and Attribute segment combination is not valid');
          RETURN 'ERROR: Context type, code and Attribute segment combination is not valid';
      END;
    END IF;
  
    l_custatt_tab_type.extend();
    l_custatt_tab_type(1) := xxqp_pricereq_custatt_rec_type(NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL,
					NULL); -- CHG0047446 add
    l_custatt_tab_type(1).attribute_key := l_valid_attr_key;
    l_custatt_tab_type(1).attribute_value := p_attr_val;
  
    validate_cust_attributes(p_custom_attributes => l_custatt_tab_type,
		     x_status            => l_status,
		     x_status_message    => l_status_message,
		     x_custom_attributes => l_custatt_tab_type_out);
  
    IF l_custatt_tab_type_out IS NOT NULL AND
       l_custatt_tab_type_out.count > 0 THEN
      FOR i IN 1 .. l_custatt_tab_type_out.count
      LOOP
        IF p_return_type = 'MEANING' THEN
          RETURN l_custatt_tab_type_out(i).attribute3;
        ELSE
          RETURN l_custatt_tab_type_out(i).attribute_value;
        END IF;
      END LOOP;
    ELSE
      --raise_application_error(-20001,'Input error: The provided attribute and value combination is not valid');
      RETURN NULL;
    END IF;
  END;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0034837 - This Procedure validates the Order and Line level data passed. It populates all
  --          derived fields into the type structures
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  10/03/2015  Diptasurjya Chatterjee (TCS)    CHG0034837 - Initial Build
  -- 1.1  26/06/2017  Diptasurjya Chatterjee (TCS)    CHG0041715 - Add validation for ask-for modifier name
  -- 1.2  11/27/2017  Diptasurjya Chatterjee (TCS)    CHG0041897 - Add validation for custom attributes input
  --                                                  Also validations will be different for different request sources
  -- 1.3  29-Jan-2019 Diptasurjya                     CHG0044970 - Change validation for return lines
  -- --------------------------------------------------------------------------------------------

  PROCEDURE validate_data(p_order_header      IN xxqp_pricereq_header_tab_type,
		  p_item_lines        IN xxqp_pricereq_lines_tab_type,
		  p_custom_attributes IN xxqp_pricereq_custatt_tab_type, -- CHG0041897
		  p_pricing_phase     IN VARCHAR2,
		  p_request_source    IN VARCHAR2, -- CHG0041897
		  x_order_header      OUT xxqp_pricereq_header_tab_type,
		  x_item_lines        OUT xxqp_pricereq_lines_tab_type,
		  x_custom_attributes OUT xxqp_pricereq_custatt_tab_type, -- CHG0041897
		  x_status            OUT VARCHAR2,
		  x_status_message    OUT VARCHAR2) IS
    l_validation_status  VARCHAR2(10) := 'S';
    l_validation_message VARCHAR2(2000);
  
    l_org_id                   NUMBER;
    l_currency_code            VARCHAR2(30);
    l_transaction_type_id      NUMBER;
    l_transaction_line_type_id NUMBER;
    l_order_category           VARCHAR2(30);
    l_uom_code                 VARCHAR2(30);
    l_item_name                VARCHAR2(30);
    l_duplicate_row_count      NUMBER := 0;
    l_exists                   NUMBER := 0;
    l_cust_attr_line_cnt       NUMBER := 0; --  CHG0041897
    l_end_cust_account_id      NUMBER := 0; --  CHG0041897
    l_line_number_dup_cnt      NUMBER := 0; --  CHG0041897
  
    l_modifier_id NUMBER := 0;
  
    l_order_header      xxqp_pricereq_header_tab_type := p_order_header;
    l_item_lines        xxqp_pricereq_lines_tab_type := p_item_lines;
    l_custom_attributes xxqp_pricereq_custatt_tab_type := p_custom_attributes; --  CHG0041897
  
    l_custom_attributes_out xxqp_pricereq_custatt_tab_type := p_custom_attributes; --  CHG0041897
    l_cust_attr_status      VARCHAR2(1);
    l_cust_attr_status_msg  VARCHAR2(4000);
  BEGIN
  
    IF l_order_header IS NOT NULL AND l_order_header.count = 1 THEN
      IF g_debug_flag = 'Y' THEN
        oe_debug_pub.add('SSYS CUSTOM: Order header Input Received: ' ||
		 chr(13) || 'SSYS CUSTOM: Customer Account ID  : ' || l_order_header(1)
		 .cust_account_id || chr(13) ||
		 'SSYS CUSTOM: Customer Ship Site ID: ' || l_order_header(1)
		 .cust_ship_site_id || chr(13) ||
		 'SSYS CUSTOM: Customer Bill Site ID: ' || l_order_header(1)
		 .cust_bill_site_id || chr(13) ||
		 'SSYS CUSTOM: Pricelist ID         : ' || l_order_header(1)
		 .price_list_id || chr(13) ||
		 'SSYS CUSTOM: Operating Unit ID    : ' || l_order_header(1)
		 .org_id || chr(13) ||
		 'SSYS CUSTOM: Operation Number     : ' || l_order_header(1)
		 .operation_no);
      END IF;
    
      IF l_order_header(1)
       .price_request_number IS NULL AND p_pricing_phase = 'BATCH' THEN
        -- -- CHG0041897
        l_validation_status  := 'E';
        l_validation_message := l_validation_message ||
		        'VALIDATION ERROR: Order Header: Price Request ID is mandatory' ||
		        chr(13);
      END IF;
    
      IF p_request_source NOT IN ('STRATAFORCE') THEN
        IF l_order_header(1).cust_account_id IS NULL AND l_order_header(1)
           .cust_account_number IS NULL THEN
          -- CHG0041897 Either of Account ID or Number is mandatory
          l_validation_status  := 'E';
          l_validation_message := l_validation_message ||
		          'VALIDATION ERROR: Order Header: Customer Account ID or Account Number is mandatory' ||
		          chr(13); -- CHG0041897 Change message
        END IF;
      
        IF l_order_header(1).cust_ship_site_id IS NULL THEN
          l_validation_status  := 'E';
          l_validation_message := l_validation_message ||
		          'VALIDATION ERROR: Order Header: Ship-to-Site ID is mandatory' ||
		          chr(13);
        END IF;
      
        IF l_order_header(1).cust_bill_site_id IS NULL THEN
          l_validation_status  := 'E';
          l_validation_message := l_validation_message ||
		          'VALIDATION ERROR: Order Header: Bill-to-Site ID is mandatory' ||
		          chr(13);
        END IF;
      END IF;
    
      IF l_order_header(1).price_list_id IS NULL THEN
        l_validation_status  := 'E';
        l_validation_message := l_validation_message ||
		        'VALIDATION ERROR: Order Header: Pricelist ID is mandatory' ||
		        chr(13);
      END IF;
    
      IF l_order_header(1)
       .org_id IS NULL AND l_order_header(1).country_code IS NULL THEN
        -- CHG0041897 Either of Org ID or COuntry code is mandatory
        l_validation_status  := 'E';
        l_validation_message := l_validation_message ||
		        'VALIDATION ERROR: Order Header: Org ID or Country is mandatory' ||
		        chr(13); -- CHG0041897 change message
      END IF;
    
      IF l_order_header(1).operation_no IS NULL THEN
        l_validation_status  := 'E';
        l_validation_message := l_validation_message ||
		        'VALIDATION ERROR: Order Header: Operation Number is mandatory' ||
		        chr(13);
      END IF;
    
      IF (l_order_header(1).cust_account_id IS NOT NULL OR l_order_header(1)
         .cust_account_number IS NOT NULL) THEN
        BEGIN
          l_exists := check_customer_account(l_order_header(1)
			         .cust_account_id,
			         l_order_header(1)
			         .cust_account_number); -- CHG0041897
        
          l_order_header(1).cust_account_id := l_exists; -- CHG0041897
        
          /* CHG0041897 -- Commented by Dipta */
          /*IF l_exists = 0 THEN
            l_validation_status  := 'E';
            l_validation_message := l_validation_message ||
                'VALIDATION ERROR: Customer Account ID ' || l_order_header(1)
               .cust_account_id ||
                ' does not exist in Oracle' || chr(13);
          END IF;*/
        EXCEPTION
          WHEN no_data_found THEN
	l_validation_status  := 'E';
	l_validation_message := l_validation_message ||
			'VALIDATION ERROR: Customer Account ID: ' || l_order_header(1)
		           .cust_account_id ||
			' and/or Account Number: ' || l_order_header(1)
		           .cust_account_number ||
			' does not exist in Oracle' || chr(13);
          WHEN OTHERS THEN
	l_validation_status  := 'E';
	l_validation_message := l_validation_message ||
			'ERROR: While checking customer account' ||
			SQLERRM || chr(13);
        END;
      END IF;
    
      /* CHG0041897 - Start validation for end customer */
      IF l_order_header(1).end_customer_account_id IS NOT NULL OR l_order_header(1)
         .end_customer_account IS NOT NULL THEN
        BEGIN
          l_end_cust_account_id := check_customer_account(l_order_header(1)
				          .end_customer_account_id,
				          l_order_header(1)
				          .end_customer_account);
        
          IF l_end_cust_account_id IS NOT NULL AND
	 l_end_cust_account_id > 0 THEN
	l_order_header(1).end_customer_account_id := l_end_cust_account_id;
          ELSE
	l_validation_status  := 'E';
	l_validation_message := l_validation_message ||
			'VALIDATION ERROR: End customer account number: ' || l_order_header(1)
		           .end_customer_account || ' and/or ID: ' || l_order_header(1)
		           .end_customer_account_id ||
			' is not valid' || chr(13);
          END IF;
        
        EXCEPTION
          WHEN no_data_found THEN
	l_validation_status  := 'E';
	l_validation_message := l_validation_message ||
			'VALIDATION ERROR: End customer account number: ' || l_order_header(1)
		           .end_customer_account || ' and/or ID: ' || l_order_header(1)
		           .end_customer_account_id ||
			' is not valid' || chr(13);
          WHEN OTHERS THEN
	l_validation_status  := 'E';
	l_validation_message := l_validation_message ||
			'ERROR: While checking end customer ' ||
			SQLERRM || chr(13);
        END;
      END IF;
      /* CHG0041897 - End validation of end customer */
    
      /* CHG0041897 - Start validation for country code */
      IF l_order_header(1)
       .org_id IS NULL AND l_order_header(1).country_code IS NOT NULL THEN
        BEGIN
          l_org_id := fetch_org_id_for_country(l_order_header(1)
			           .country_code);
        
          IF l_org_id IS NOT NULL AND l_org_id > 0 THEN
	l_order_header(1).org_id := l_org_id;
          ELSE
	l_validation_status  := 'E';
	l_validation_message := l_validation_message ||
			'VALIDATION ERROR: Country Code: ' || l_order_header(1)
		           .country_code ||
			' is not associated with Operating Unit in Oracle' ||
			chr(13);
          END IF;
        
        EXCEPTION
          WHEN no_data_found THEN
	l_validation_status  := 'E';
	l_validation_message := l_validation_message ||
			'VALIDATION ERROR: Country Code: ' || l_order_header(1)
		           .country_code ||
			' is not associated with Operating Unit in Oracle' ||
			chr(13);
          WHEN OTHERS THEN
	l_validation_status  := 'E';
	l_validation_message := l_validation_message ||
			'ERROR: While checking country code ' ||
			SQLERRM || chr(13);
        END;
      END IF;
      /* CHG0041897 - End validation of country code */
    
      --  18.08.2016                    CHG0038192 Revenue distribution mechanisim for Buy&Get items
      /*l_exists := 0;
       begin
         l_exists := check_bill_to_site(l_order_header(1).cust_account_id,
                                        l_order_header(1).cust_bill_site_id,
                                        l_order_header(1).org_id);
         if l_exists = 0 then
           l_validation_status := 'E';
           l_validation_message := l_validation_message||'VALIDATION ERROR: Bill To Site ID '||l_order_header(1).cust_bill_site_id||' is not valid for given customer account id and org id'||CHR(13);
         end if;
       exception
       when no_data_found then
         l_validation_status := 'E';
         l_validation_message := l_validation_message||'VALIDATION ERROR: Bill To Site ID '||l_order_header(1).cust_bill_site_id||' is not valid for given customer account id and org id'||CHR(13);
       when others then
         l_validation_status := 'E';
         l_validation_message := l_validation_message||'ERROR: While checking bill to site ID'||SQLERRM||CHR(13);
       end;
      
       l_exists := 0;
       begin
         l_exists := check_ship_to_site(l_order_header(1).cust_account_id,
                                        l_order_header(1).cust_ship_site_id,
                                        l_order_header(1).org_id);
         if l_exists = 0 then
           l_validation_status := 'E';
           l_validation_message := l_validation_message||'VALIDATION ERROR: Ship To Site ID '||l_order_header(1).cust_ship_site_id||' is not valid for given customer account id and org id'||CHR(13);
         end if;
       exception
       when no_data_found then
         l_validation_status := 'E';
         l_validation_message := l_validation_message||'VALIDATION ERROR: Ship To Site ID '||l_order_header(1).cust_ship_site_id||' is not valid for given customer account id and org id'||CHR(13);
       when others then
         l_validation_status := 'E';
         l_validation_message := l_validation_message||'ERROR: While checking ship to site ID'||SQLERRM||CHR(13);
       end;
      */
      BEGIN
        IF l_order_header(1)
         .price_list_id IS NOT NULL AND l_order_header(1).currency IS NULL THEN
          l_currency_code := fetch_currency_code(l_order_header(1)
				 .price_list_id);
          l_order_header(1).currency := l_currency_code;
        END IF;
      EXCEPTION
        WHEN no_data_found THEN
          l_validation_status  := 'E';
          l_validation_message := l_validation_message ||
		          'ERROR: Currency Code not found for Price List ID:' || l_order_header(1)
		         .price_list_id || chr(13);
        WHEN OTHERS THEN
          l_validation_status  := 'E';
          l_validation_message := l_validation_message ||
		          'ERROR: While fetching Currency Code.' ||
		          SQLERRM || chr(13);
      END;
    
      /** CHG0041715 -- Start Promo Code modifier validation */
      BEGIN
        IF l_order_header(1).ask_for_modifier_name IS NOT NULL THEN
          l_modifier_id := fetch_modifier_id(l_order_header(1)
			         .ask_for_modifier_name);
          l_order_header(1).ask_for_modifier_id := l_modifier_id;
        ELSE
          l_order_header(1).ask_for_modifier_id := NULL;
        END IF;
      EXCEPTION
        WHEN no_data_found THEN
          l_validation_status  := 'EP';
          l_validation_message := l_validation_message ||
		          'ERROR: Promo Code entered is not valid: ' || l_order_header(1)
		         .ask_for_modifier_name || chr(13);
        WHEN OTHERS THEN
          l_validation_status  := 'EP';
          l_validation_message := l_validation_message ||
		          'ERROR: While validating Promo Code.' ||
		          SQLERRM || chr(13);
      END;
      /** CHG0041715 -- End Promo Code modifier validation */
    
      BEGIN
        IF l_order_header(1).transaction_type_id IS NULL THEN
          IF l_order_header(1).org_id IS NOT NULL AND l_order_header(1)
	 .operation_no IS NOT NULL THEN
	l_transaction_type_id := fetch_transaction_id(l_order_header(1)
				          .org_id,
				          l_order_header(1)
				          .operation_no);
	l_order_header(1).transaction_type_id := l_transaction_type_id;
          END IF;
        END IF;
      EXCEPTION
        WHEN no_data_found THEN
          l_validation_status  := 'E';
          l_validation_message := l_validation_message ||
		          'ERROR: Transaction type could not be fetched for ORG ID:' || l_order_header(1)
		         .org_id || ' and Operation No:' || l_order_header(1)
		         .operation_no || chr(13);
        WHEN OTHERS THEN
          l_validation_status  := 'E';
          l_validation_message := l_validation_message ||
		          'ERROR: While fetching Transaction Type ID.' ||
		          SQLERRM || chr(13);
      END;
    
      BEGIN
        IF l_order_header(1).org_id IS NOT NULL AND l_order_header(1)
           .operation_no IS NOT NULL THEN
          l_transaction_line_type_id := fetch_transaction_line_id(l_order_header(1)
					      .org_id,
					      l_order_header(1)
					      .operation_no);
          l_order_header(1).transaction_line_type_id := l_transaction_line_type_id;
        END IF;
      EXCEPTION
        WHEN no_data_found THEN
          l_validation_status  := 'E';
          l_validation_message := l_validation_message ||
		          'ERROR: Transaction line type could not be fetched for ORG ID:' || l_order_header(1)
		         .org_id || ' and Operation No:' || l_order_header(1)
		         .operation_no || chr(13);
        WHEN OTHERS THEN
          l_validation_status  := 'E';
          l_validation_message := l_validation_message ||
		          'ERROR: While fetching Transaction Line Type ID.' ||
		          SQLERRM || chr(13);
      END;
    
      BEGIN
        IF l_order_header(1).transaction_type_id IS NOT NULL THEN
          l_order_category := fetch_order_category(l_order_header(1)
				   .transaction_type_id);
          l_order_header(1).order_category := l_order_category;
        END IF;
      EXCEPTION
        WHEN no_data_found THEN
          l_validation_status  := 'E';
          l_validation_message := l_validation_message ||
		          'ERROR: Order Category Code not found for OM Transaction Type ID:' || l_order_header(1)
		         .transaction_type_id || chr(13);
        WHEN OTHERS THEN
          l_validation_status  := 'E';
          l_validation_message := l_validation_message ||
		          'ERROR: While fetching Order Category Code.' ||
		          SQLERRM || chr(13);
      END;
    
    ELSIF l_order_header IS NOT NULL OR l_order_header.count > 1 THEN
      l_validation_status  := 'E';
      l_validation_message := l_validation_message ||
		      'VALIDATION ERROR: Provide Single Order Header' ||
		      chr(13);
    ELSIF l_order_header IS NULL OR l_order_header.count <= 0 THEN
      l_validation_status  := 'E';
      l_validation_message := l_validation_message ||
		      'VALIDATION ERROR: Order Header information is required' ||
		      chr(13);
    END IF;
  
    IF l_item_lines IS NOT NULL AND l_item_lines.count > 0 THEN
      IF p_pricing_phase = 'LINE' AND l_item_lines.count > 1 THEN
        l_validation_status  := 'EL';
        l_validation_message := l_validation_message ||
		        'VALIDATION ERROR: Please provide single line information for pricing' ||
		        chr(13);
        NULL;
      END IF;
    
      IF l_validation_status <> 'EL' THEN
        FOR j IN 1 .. l_item_lines.count
        LOOP
          IF g_debug_flag = 'Y' THEN
	oe_debug_pub.add('SSYS CUSTOM: Order Line Input Received: Line Number : ' || l_item_lines(j)
		     .line_num || ' Item ID : ' || l_item_lines(j)
		     .inventory_item_id || ' Quantity : ' || l_item_lines(j)
		     .quantity);
          END IF;
        
          IF l_item_lines(j).line_num IS NULL THEN
	l_validation_status  := 'E';
	l_validation_message := l_validation_message ||
			'VALIDATION ERROR: Line: Line Number is mandatory' ||
			chr(13);
          END IF;
        
          /* CHG0041897 - Duplicate line number*/
          BEGIN
	IF l_validation_status <> 'E' THEN
	  SELECT COUNT(1)
	  INTO   l_line_number_dup_cnt
	  FROM   TABLE(CAST(l_item_lines AS
		        xxqp_pricereq_lines_tab_type)) t1
	  WHERE  t1.line_num = l_item_lines(j).line_num;
	
	  IF l_line_number_dup_cnt > 1 THEN
	    l_validation_status  := 'E';
	    l_validation_message := l_validation_message ||
			    'VALIDATION ERROR: Line: Line number ' || l_item_lines(j)
			   .line_num ||
			    ' occurs more than once in the input received ' ||
			    chr(13);
	  END IF;
	END IF;
          END;
          /* CHG0041897 - Duplicate line number*/
        
          IF l_item_lines(j)
           .inventory_item_id IS NULL AND l_item_lines(j).item IS NULL THEN
	l_validation_status  := 'E';
	l_validation_message := l_validation_message ||
			'VALIDATION ERROR: Line Number:' || l_item_lines(j)
		           .line_num ||
			': Inventory Item ID or Item Name is mandatory' ||
			chr(13);
          END IF;
          IF l_item_lines(j).quantity IS NULL /*OR l_item_lines(j).quantity <= 0 */
           THEN
	-- CHG0044970 commented negative quantity check
	l_validation_status  := 'E';
	l_validation_message := l_validation_message ||
			'VALIDATION ERROR: Line Number:' || l_item_lines(j)
		           .line_num || ': Quantity is mandatory' ||
			chr(13); -- CHG0044970 change message wording
          END IF;
        
          /* CHG0041897 - Start validation of item name*/
          BEGIN
	IF l_item_lines(j).inventory_item_id IS NULL AND l_item_lines(j)
	   .item IS NOT NULL THEN
	  l_item_lines(j).inventory_item_id := xxinv_utils_pkg.get_item_id(l_item_lines(j).item);
	
	  IF l_item_lines(j).inventory_item_id IS NULL THEN
	    l_validation_status  := 'E';
	    l_validation_message := l_validation_message ||
			    'VALIDATION ERROR: Line: Item code ' || l_item_lines(j).item ||
			    ' not found in Oracle ' || chr(13);
	  END IF;
	END IF;
          EXCEPTION
	WHEN OTHERS THEN
	  l_validation_status  := 'E';
	  l_validation_message := l_validation_message ||
			  'ERROR: While fetching Line Item ID. Line Number:' || l_item_lines(j)
			 .line_num || '. Item Code is ' || l_item_lines(j).item || '. ' ||
			  SQLERRM || chr(13);
          END;
          /* CHG0041897 - End validation of item name*/
        
          /* CHG0041897 - Start validation of item uom*/
          BEGIN
	IF l_item_lines(j).item_uom IS NOT NULL AND l_item_lines(j)
	   .inventory_item_id IS NOT NULL THEN
	  SELECT uom_code
	  INTO   l_uom_code
	  FROM   mtl_item_uoms_view
	  WHERE  inventory_item_id = l_item_lines(j).inventory_item_id
	  AND    organization_id =
	         xxinv_utils_pkg.get_master_organization_id
	  AND    uom_code = l_item_lines(j).item_uom;
	
	  l_uom_code := NULL;
	END IF;
          EXCEPTION
	WHEN no_data_found THEN
	  l_validation_status  := 'E';
	  l_validation_message := l_validation_message ||
			  'VALIDATION ERROR: While validating Line UOM. Line Number:' || l_item_lines(j)
			 .line_num || '. UOM: ' || l_item_lines(j)
			 .item_uom ||
			  '. UOM is not valid for item ID ' || l_item_lines(j)
			 .inventory_item_id || chr(13);
	WHEN OTHERS THEN
	  l_validation_status  := 'E';
	  l_validation_message := l_validation_message ||
			  'ERROR: While validating line item UOM. Line Number:' || l_item_lines(j)
			 .line_num || '. UOM Code is ' || l_item_lines(j)
			 .item_uom || '. ' || SQLERRM ||
			  chr(13);
          END;
          /* CHG0041897 - End validation of item uom*/
        
          BEGIN
	IF l_item_lines(j).inventory_item_id IS NOT NULL AND l_item_lines(j)
	   .item_uom IS NULL THEN
	  -- CHG0041897 check if item_uom is null only then assign item_uom
	  l_uom_code := NULL;
	  l_uom_code := fetch_item_uom_code(l_item_lines(j)
				.inventory_item_id);
	  l_item_lines(j).item_uom := l_uom_code;
	END IF;
          EXCEPTION
	WHEN no_data_found THEN
	  l_validation_status  := 'E';
	  l_validation_message := l_validation_message ||
			  'ERROR: While fetching Line Item UOM. Line Number:' || l_item_lines(j)
			 .line_num || '. Item ID is ' || l_item_lines(j)
			 .inventory_item_id ||
			  '. No data found' || chr(13);
	WHEN OTHERS THEN
	  l_validation_status  := 'E';
	  l_validation_message := l_validation_message ||
			  'ERROR: While fetching Line Item UOM. Line Number:' || l_item_lines(j)
			 .line_num || '. Item ID is ' || l_item_lines(j)
			 .inventory_item_id || '. ' || SQLERRM ||
			  chr(13);
          END;
        
          BEGIN
	IF l_item_lines(j).inventory_item_id IS NOT NULL AND l_item_lines(j)
	   .item IS NULL THEN
	  -- CHG0041897 check if item is null only then assign item value
	  l_item_name := NULL;
	  l_item_name := fetch_item_name(l_item_lines(j)
			         .inventory_item_id);
	  l_item_lines(j).item := l_item_name;
	END IF;
          EXCEPTION
	WHEN OTHERS THEN
	  l_validation_status  := 'E';
	  l_validation_message := l_validation_message ||
			  'ERROR: While fetching Line Item Name. Line Number:' || l_item_lines(j)
			 .line_num || '. Item ID is ' || l_item_lines(j)
			 .inventory_item_id || '. ' || SQLERRM ||
			  chr(13);
          END;
        
        END LOOP;
      ELSIF l_validation_status = 'EL' THEN
        l_validation_status := 'E';
      END IF;
    
    ELSIF l_item_lines IS NULL OR l_item_lines.count <= 0 THEN
      l_validation_status  := 'E';
      l_validation_message := l_validation_message ||
		      'VALIDATION ERROR: Order Line information is required' ||
		      chr(13);
    END IF;
  
    /* CHG0041897 - Start validate custom attribute information*/
    IF l_custom_attributes IS NOT NULL AND l_custom_attributes.count > 0 THEN
      FOR k IN 1 .. l_custom_attributes.count
      LOOP
        IF g_debug_flag = 'Y' THEN
          oe_debug_pub.add('SSYS CUSTOM: Custom Attribute Input Received: Line Number: ' || l_custom_attributes(k)
		   .line_num || chr(13) || ' Attribute Key : ' || l_custom_attributes(k)
		   .attribute_key || chr(13) ||
		   ' Attribute Value : ' || l_custom_attributes(k)
		   .attribute_value);
        END IF;
      
        /*if l_custom_attributes(k).attribute_key is null and l_custom_attributes(k).attribute_value IS NULL then
          l_custom_attributes.delete(k);
          continue;
        end if;*/
      
        IF l_custom_attributes(k).attribute_key IS NOT NULL AND l_custom_attributes(k)
           .attribute_value IS NULL THEN
          l_validation_status  := 'E';
          l_validation_message := l_validation_message ||
		          'VALIDATION ERROR: Attribute value must be provided for attribute key: ' || l_custom_attributes(k)
		         .attribute_key || chr(13);
        END IF;
      
        IF l_custom_attributes(k).attribute_key IS NULL AND l_custom_attributes(k)
           .attribute_value IS NOT NULL THEN
          l_validation_status  := 'E';
          l_validation_message := l_validation_message ||
		          'VALIDATION ERROR: Attribute key must be provided for attribute value: ' || l_custom_attributes(k)
		         .attribute_value || chr(13);
        END IF;
      
        -- Check that attribute line number if provided is -1 for header or exists in line records received for pricing
        BEGIN
          /* Rem By Roman W. 03/03/2020 CHG0047446
          IF l_custom_attributes(k).line_num IS NOT NULL THEN
            SELECT COUNT(1)
              INTO l_cust_attr_line_cnt
              FROM TABLE(CAST(l_item_lines AS xxqp_pricereq_lines_tab_type)) t1
             WHERE t1.line_num = l_custom_attributes(k).line_num; -- Rem By Roman W. 03/03/2020
          
          
          
            IF l_cust_attr_line_cnt > 0 OR l_custom_attributes(k)
              .line_num = -1 THEN
              NULL;
            ELSE
              l_validation_status  := 'E';
              l_validation_message := l_validation_message ||
                                      'VALIDATION ERROR: Custom attribute line number: ' || l_custom_attributes(k)
                                     .line_num ||
                                      ' not valid. Should be -1 (for header attribute) or be present in line inputs sent' ||
                                      chr(13);
            END IF;
          END IF;
          */
          -- Added By Roman W. 03/03/2020 CHG0047446
          IF l_custom_attributes(k).line_source_ref_id IS NOT NULL THEN
	SELECT COUNT(1)
	INTO   l_cust_attr_line_cnt
	FROM   TABLE(CAST(l_item_lines AS xxqp_pricereq_lines_tab_type)) t1
	WHERE  1 = 1 -- t1.line_num = l_custom_attributes(k).line_num; -- Rem By Roman W. 03/03/2020
	AND    t1.source_ref_id = l_custom_attributes(k)
	      .line_source_ref_id;
          
	IF l_cust_attr_line_cnt > 0 OR l_custom_attributes(k)
	  .line_num = -1 THEN
	  NULL;
	ELSE
	  l_validation_status  := 'E';
	  l_validation_message := l_validation_message ||
			  'VALIDATION ERROR: Custom attribute line number: ' || l_custom_attributes(k)
			 .line_num || ' ( ' || l_custom_attributes(k)
			 .line_source_ref_id || ' ) ' ||
			  ' not valid. Should be -1 (for header attribute) or be present in line inputs sent' ||
			  chr(13);
	END IF;
          END IF;
        
        EXCEPTION
          WHEN OTHERS THEN
	l_validation_status  := 'E';
	l_validation_message := l_validation_message ||
			'ERROR: While validating Custom attribute line number: ' || l_custom_attributes(k)
		           .line_num || ' ' || SQLERRM || chr(13);
        END;
      
        BEGIN
          SELECT qpc.prc_context_type,
	     qpc.prc_context_code,
	     qs.segment_mapping_column,
	     qps.segment_level
          INTO   l_custom_attributes(k).attribute_context_type,
	     l_custom_attributes(k).attribute_context,
	     l_custom_attributes(k).attribute_column,
	     l_custom_attributes(k).attribute_sourcing_level
          FROM   qp_prc_contexts_v qpc,
	     qp_segments_v     qs,
	     qp_pte_segments   qps
          WHERE  qpc.prc_context_id = qs.prc_context_id
          AND    qps.segment_id = qs.segment_id
          AND    qps.pte_code = 'ORDFUL'
          AND    qpc.prc_context_type || '|' || qpc.prc_context_code || '|' ||
	     qs.segment_code = l_custom_attributes(k).attribute_key;
        
          IF l_custom_attributes(k).attribute_context_type IS NULL OR l_custom_attributes(k)
	 .attribute_context IS NULL OR l_custom_attributes(k)
	 .attribute_column IS NULL OR l_custom_attributes(k)
	 .attribute_sourcing_level IS NULL THEN
	l_validation_status  := 'E';
	l_validation_message := l_validation_message ||
			'ERROR: While fetching Attribute information. Attribute Key:' || l_custom_attributes(k)
		           .attribute_key ||
			'. Context and segment information could not be sourced correctly.' ||
			chr(13);
          END IF;
        EXCEPTION
          WHEN no_data_found THEN
	l_validation_status  := 'E';
	l_validation_message := l_validation_message ||
			'ERROR: While fetching Attribute information. Attribute Key:' || l_custom_attributes(k)
		           .attribute_key || '. No data found' ||
			chr(13);
          WHEN OTHERS THEN
	l_validation_status  := 'E';
	l_validation_message := l_validation_message ||
			'ERROR: While fetching Attribute information. Attribute Key:' || l_custom_attributes(k)
		           .attribute_key || '. ' || SQLERRM ||
			chr(13);
        END;
      END LOOP;
      /* Start - validate custom attribute values against corresponding value sets */
      validate_cust_attributes(p_custom_attributes => l_custom_attributes,
		       x_status            => l_cust_attr_status,
		       x_status_message    => l_cust_attr_status_msg,
		       x_custom_attributes => l_custom_attributes_out);
    
      IF l_cust_attr_status = 'E' THEN
        l_validation_status  := 'E';
        l_validation_message := l_validation_message ||
		        l_cust_attr_status_msg;
      END IF;
    
      IF l_custom_attributes_out IS NOT NULL AND
         l_custom_attributes_out.count > 1 THEN
        l_custom_attributes := l_custom_attributes_out;
      END IF;
      /* End - validate custom attribute values against corresponding value sets */
    END IF;
    /* CHG0041897 - End */
    x_order_header      := l_order_header;
    x_item_lines        := l_item_lines;
    x_custom_attributes := l_custom_attributes;
  
    x_status         := l_validation_status;
    x_status_message := l_validation_message;
  EXCEPTION
    WHEN OTHERS THEN
      x_status         := 'E';
      x_status_message := l_validation_message || SQLERRM || chr(13);
  END validate_data;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0034837 - This is a AUTONOMOUS TRANSACTION procedure which inserts data into the price request
  --          custom tables. This funtions inserts data for Modifiers, Attributes and related
  --          modifiers into tables XX_QP_PRICEREQ_MODIFIERS, XX_QP_PRICEREQ_ATTRIBUTES,
  --          XX_QP_PRICEREQ_RELTD_ADJ
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  04/02/2015  Diptasurjya Chatterjee (TCS)    CHG0034837 - Initial Build
  -- 1.1  01/09/2017  Diptasurjya Chatterjee (TCS)    CHG0039953 - before inserting data into attribute
  --                                                  and related adjustment tables, checking if associated
  --                                                  adjustment information is present in the modifier table
  -- 1.2  11/27/2017  Diptasurjya Chatterjee (TCS)    CHG0041897 - handle request source
  -- 1.3  08/07/2018  Diptasurjya Chatterjee          INC0128351 - Delete all records before insert
  -- 1.4  10/17/2018  Diptasurjy Chatterjee           CHG0044153 - Allow saving of pricing line output
  -- --------------------------------------------------------------------------------------------

  PROCEDURE insert_pricereq_tables(p_session_details    IN xxecom.xxqp_pricereq_session_tab_type,
		           p_line_details       IN xxecom.xxqp_pricereq_lines_tab_type, -- CHG0044153
		           p_modifier_details   IN xxecom.xxqp_pricereq_mod_tab_type,
		           p_attribute_details  IN xxecom.xxqp_pricereq_attr_tab_type,
		           p_related_adjustment IN xxecom.xxqp_pricereq_reltd_tab_type,
		           p_pricing_server     IN VARCHAR2,
		           p_request_number     IN VARCHAR2 DEFAULT NULL,
		           p_request_source     IN VARCHAR2, -- CHG0041897
		           x_status             OUT VARCHAR2,
		           x_status_message     OUT VARCHAR2) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  
    l_request_number VARCHAR2(20);
    l_request_source VARCHAR2(150); -- CHG0041897
    l_modifier_count NUMBER := 0; -- CHG0039953 Dipta Change
  
    l_line_save_flag VARCHAR2(1); -- CHG0044153
  
    l_status         VARCHAR2(10) := 'S';
    l_status_message VARCHAR2(2000);
  BEGIN
    l_request_number := p_request_number;
    l_request_source := p_request_source;
  
    IF p_pricing_server = 'FAILOVER' THEN
      IF p_session_details IS NOT NULL AND p_session_details.count = 1 THEN
        l_request_number := p_session_details(1).request_number;
        l_request_source := nvl(l_request_source,
		        p_session_details(1).request_source); -- CHG0041897
      
        --dbms_output.put_line('Here: ' || l_request_source);
      
        DELETE FROM xxecom.xx_qp_pricereq_session
        WHERE  request_number = l_request_number
	  --AND    order_created_flag IS NULL - INC0128351 commented
	  --AND    end_date IS NULL - INC0128351 commented
        AND    request_source = l_request_source; -- CHG0041897
      
        INSERT INTO xxecom.xx_qp_pricereq_session
          (request_number,
           start_date,
           debug_log_name,
           pricing_server,
           request_source) -- CHG0041897
        VALUES
          (p_session_details(1).request_number,
           p_session_details(1).start_date,
           p_session_details(1).debug_log_name,
           p_session_details(1).pricing_server,
           l_request_source); -- CHG0041897
      
      END IF;
    END IF;
  
    DELETE FROM xxecom.xx_qp_pricereq_modifiers
    WHERE  request_number = l_request_number
          --AND    order_created_flag IS NULL - INC0128351 commented
          --AND    end_date IS NULL - INC0128351 commented
    AND    request_source = l_request_source; -- CHG0041897
  
    IF p_modifier_details IS NOT NULL AND p_modifier_details.count > 0 THEN
    
      FOR k IN 1 .. p_modifier_details.count
      LOOP
        INSERT INTO xxecom.xx_qp_pricereq_modifiers
          (request_number,
           adjustment_level,
           line_num,
           line_adj_num,
           list_header_id,
           list_line_id,
           list_type_code,
           automatic_flag,
           update_allowed,
           updated_flag,
           operand,
           operand_calculation_code,
           adjusted_amount,
           pricing_phase_id,
           accrual_flag,
           modifier_level_code,
           price_break_type_code,
           applied_flag,
           line_quantity,
           attribute1,
           attribute2,
           attribute3,
           start_date,
           request_source) -- CHG0041897
        VALUES
          (l_request_number,
           p_modifier_details(k).adjustment_level,
           p_modifier_details(k).line_num,
           p_modifier_details(k).line_adj_num,
           p_modifier_details(k).list_header_id,
           p_modifier_details(k).list_line_id,
           p_modifier_details(k).list_type_code,
           p_modifier_details(k).automatic_flag,
           p_modifier_details(k).update_allowed,
           p_modifier_details(k).updated_flag,
           p_modifier_details(k).operand,
           p_modifier_details(k).operand_calculation_code,
           p_modifier_details(k).adjusted_amount,
           p_modifier_details(k).pricing_phase_id,
           p_modifier_details(k).accrual_flag,
           p_modifier_details(k).modifier_level_code,
           p_modifier_details(k).price_break_type_code,
           p_modifier_details(k).applied_flag,
           p_modifier_details(k).line_quantity,
           p_modifier_details(k).attribute1,
           p_modifier_details(k).attribute2,
           p_modifier_details(k).attribute3,
           SYSDATE,
           l_request_source); -- CHG0041897
      END LOOP;
    END IF;
  
    DELETE FROM xxecom.xx_qp_pricereq_attributes
    WHERE  request_number = l_request_number
          --AND    order_created_flag IS NULL - INC0128351 commented
          --AND    end_date IS NULL - INC0128351 commented
    AND    request_source = l_request_source; -- CHG0041897
  
    IF p_attribute_details IS NOT NULL AND p_attribute_details.count > 0 THEN
      l_modifier_count := 0; -- CHG0039953 Dipta Change
      FOR k IN 1 .. p_attribute_details.count
      LOOP
        -- CHG0039953 Start Dipta Change
        SELECT COUNT(1)
        INTO   l_modifier_count
        FROM   xxecom.xx_qp_pricereq_modifiers
        WHERE  request_number = l_request_number
        AND    adjustment_level = p_attribute_details(k).adjustment_level
        AND    line_num = p_attribute_details(k).line_num
        AND    line_adj_num = p_attribute_details(k).line_adj_num
        AND    request_source = l_request_source; -- CHG0041897
      
        IF l_modifier_count > 0 THEN
          -- CHG0039953 End Dipta Change
          INSERT INTO xxecom.xx_qp_pricereq_attributes
	(request_number,
	 adjustment_level,
	 context_type,
	 line_num,
	 line_adj_num,
	 CONTEXT,
	 attribute_col,
	 attr_value_from,
	 attr_value_to,
	 qual_comp_operator_code,
	 attribute1,
	 attribute2,
	 attribute3,
	 start_date,
	 request_source) -- CHG0041897
          VALUES
	(l_request_number,
	 p_attribute_details(k).adjustment_level,
	 p_attribute_details(k).context_type,
	 p_attribute_details(k).line_num,
	 p_attribute_details(k).line_adj_num,
	 p_attribute_details(k).context,
	 p_attribute_details(k).attribute_col,
	 p_attribute_details(k).attr_value_from,
	 p_attribute_details(k).attr_value_to,
	 p_attribute_details(k).qual_comp_operator_code,
	 p_attribute_details(k).attribute1,
	 p_attribute_details(k).attribute2,
	 p_attribute_details(k).attribute3,
	 SYSDATE,
	 l_request_source); -- CHG0041897
        END IF; -- CHG0039953 Dipta Change
      END LOOP;
    END IF;
  
    DELETE FROM xxecom.xx_qp_pricereq_reltd_adj
    WHERE  request_number = l_request_number
          --AND    order_created_flag IS NULL - INC0128351 commented
          --AND    end_date IS NULL - INC0128351 commented
    AND    request_source = l_request_source; -- CHG0041897
  
    IF p_related_adjustment IS NOT NULL AND p_related_adjustment.count > 0 THEN
      l_modifier_count := 0; -- CHG0039953 Dipta Change
    
      FOR k IN 1 .. p_related_adjustment.count
      LOOP
        -- CHG0039953 Start Dipta Change
        SELECT COUNT(1)
        INTO   l_modifier_count
        FROM   xxecom.xx_qp_pricereq_modifiers
        WHERE  request_number = l_request_number
        AND    adjustment_level = p_related_adjustment(k).adjustment_level
        AND    line_num = p_related_adjustment(k).line_num
        AND    line_adj_num = p_related_adjustment(k).line_adj_num
        AND    request_source = l_request_source; -- CHG0041897
      
        IF l_modifier_count > 0 THEN
          -- CHG0039953 End Dipta Change
          INSERT INTO xxecom.xx_qp_pricereq_reltd_adj
	(request_number,
	 adjustment_level,
	 line_num,
	 line_adj_num,
	 relationship_type_code,
	 related_line_num,
	 related_line_adj_num,
	 start_date,
	 request_source) -- CHG0041897
          VALUES
	(l_request_number,
	 p_related_adjustment(k).adjustment_level,
	 p_related_adjustment(k).line_num,
	 p_related_adjustment(k).line_adj_num,
	 p_related_adjustment(k).relationship_type_code,
	 p_related_adjustment(k).related_line_num,
	 p_related_adjustment(k).related_line_adj_num,
	 SYSDATE,
	 l_request_source); -- CHG0041897
        END IF; -- CHG0039953 Dipta Change
      END LOOP;
    END IF;
  
    -- CHG0044153 - Start portion to save pricing line output
    BEGIN
      SELECT ffvd.save_pricing_line_output
      INTO   l_line_save_flag
      FROM   fnd_flex_values     ffv,
	 fnd_flex_value_sets ffvs,
	 fnd_flex_values_dfv ffvd
      WHERE  ffvs.flex_value_set_name = 'XXSSYS_EVENT_TARGET_NAME'
      AND    ffvs.flex_value_set_id = ffv.flex_value_set_id
      AND    ffv.rowid = ffvd.row_id
      AND    ffv.flex_value = l_request_source;
    EXCEPTION
      WHEN no_data_found THEN
        l_line_save_flag := 'N';
    END;
  
    IF l_line_save_flag = 'Y' THEN
      DELETE FROM xxobjt.xx_qp_pricereq_lines
      WHERE  request_number = l_request_number
      AND    request_source = l_request_source;
    
      IF p_line_details IS NOT NULL AND p_line_details.count > 0 THEN
      
        FOR k IN 1 .. p_line_details.count
        LOOP
          INSERT INTO xxobjt.xx_qp_pricereq_lines
	(request_number,
	 line_num,
	 item,
	 inventory_item_id,
	 item_uom,
	 priced_uom,
	 quantity,
	 unit_list_price,
	 unit_sales_price,
	 total_line_price,
	 line_discount,
	 adjustment_info,
	 error_message,
	 promotion_line_num,
	 attribute1,
	 attribute2,
	 attribute3,
	 attribute4,
	 attribute5,
	 attribute6,
	 attribute7,
	 attribute8,
	 attribute9,
	 attribute10,
	 source_ref_id,
	 request_source,
	 start_date,
	 end_date,
	 order_created_flag)
          VALUES
	(l_request_number,
	 p_line_details(k).line_num,
	 p_line_details(k).item,
	 p_line_details(k).inventory_item_id,
	 p_line_details(k).item_uom,
	 p_line_details(k).priced_uom,
	 p_line_details(k).quantity,
	 p_line_details(k).unit_sales_price,
	 p_line_details(k).adj_unit_sales_price,
	 p_line_details(k).total_line_price,
	 p_line_details(k).line_discount,
	 p_line_details(k).adjustment_info,
	 p_line_details(k).error_message,
	 p_line_details(k).promotion_line_num,
	 p_line_details(k).attribute1,
	 p_line_details(k).attribute2,
	 p_line_details(k).attribute3,
	 p_line_details(k).attribute4,
	 p_line_details(k).attribute5,
	 p_line_details(k).attribute6,
	 p_line_details(k).attribute7,
	 p_line_details(k).attribute8,
	 p_line_details(k).attribute9,
	 p_line_details(k).attribute10,
	 p_line_details(k).source_ref_id,
	 l_request_source,
	 SYSDATE,
	 NULL,
	 NULL);
        END LOOP;
      END IF;
    END IF;
    -- CHG0044153 End pricing line saving
    COMMIT;
  
    x_status         := l_status;
    x_status_message := l_status_message;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      x_status         := 'E';
      x_status_message := 'DATA INSERT ERROR: While inserting data into pricing tables. ' ||
		  SQLERRM;
  END insert_pricereq_tables;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0034837 - This is a AUTONOMOUS TRANSACTION funtion which inserts data into the price request
  --          custom table. This funtions inserts data for price request session initiated in
  --          table XX_QP_PRICEREQ_SESSION
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  04/02/2015  Diptasurjya Chatterjee (TCS)    CHG0034837 - Initial Build
  -- 1.1  11/27/2017  Diptasurjya Chatterjee (TCS)    CHG0041897 - handle request source
  -- 1.2  08/07/2018  Diptasurjya Chatterjee (TCS)    INC0128351 - Delete all records before insert
  -- --------------------------------------------------------------------------------------------

  FUNCTION insert_pricereq_session(p_debug_file     IN VARCHAR2,
		           p_pricing_server IN VARCHAR2,
		           p_price_request  IN VARCHAR2,
		           p_request_source IN VARCHAR2) -- CHG0041897
   RETURN NUMBER IS
    PRAGMA AUTONOMOUS_TRANSACTION;
    data_count NUMBER := 0;
  BEGIN
    DELETE FROM xxecom.xx_qp_pricereq_session
    WHERE  request_number = p_price_request
          --AND    order_created_flag IS NULL - INC0128351 commented
          --AND    end_date IS NULL - INC0128351 commented
    AND    request_source = p_request_source; -- CHG0041897
  
    INSERT INTO xxecom.xx_qp_pricereq_session
      (request_number,
       start_date,
       debug_log_name,
       pricing_server,
       request_source) -- CHG0041897
    VALUES
      (p_price_request,
       SYSDATE,
       p_debug_file,
       p_pricing_server,
       p_request_source); -- CHG0041897
    COMMIT;
  
    RETURN data_count + 1;
  END;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0034837 - This procedure will be registered in a Concurrent program which will
  --          enable users to purge processed the Price Request custom tables.
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  04/02/2015  Diptasurjya Chatterjee (TCS)    CHG0034837 - Initial Build
  -- 1.1  11/27/2017  Diptasurjya Chatterjee (TCS)    CHG0041897 - handle request source
  -- --------------------------------------------------------------------------------------------

  PROCEDURE purge_pricereq_tables(x_retcode        OUT NUMBER,
		          x_errbuf         OUT VARCHAR2,
		          p_request_source IN VARCHAR2) IS
  
  BEGIN
    DELETE FROM xxecom.xx_qp_pricereq_session
    WHERE  order_created_flag IS NOT NULL
    AND    order_created_flag = 'Y'
    AND    end_date IS NOT NULL
    AND    request_source = p_request_source; -- CHG0041897
  
    DELETE FROM xxecom.xx_qp_pricereq_modifiers
    WHERE  order_created_flag IS NOT NULL
    AND    order_created_flag = 'Y'
    AND    end_date IS NOT NULL
    AND    request_source = p_request_source; -- CHG0041897
  
    DELETE FROM xxecom.xx_qp_pricereq_attributes
    WHERE  order_created_flag IS NOT NULL
    AND    order_created_flag = 'Y'
    AND    end_date IS NOT NULL
    AND    request_source = p_request_source; -- CHG0041897
  
    DELETE FROM xxecom.xx_qp_pricereq_reltd_adj
    WHERE  order_created_flag IS NOT NULL
    AND    order_created_flag = 'Y'
    AND    end_date IS NOT NULL
    AND    request_source = p_request_source; -- CHG0041897
  
    COMMIT;
  
    x_retcode := 0;
    x_errbuf  := 'COMPLETE';
    fnd_file.put_line(fnd_file.log,
	          chr(13) ||
	          'SUCCESS: Pricing custom tables purged successfully for source ' ||
	          p_request_source);
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      x_retcode := 0;
      x_errbuf  := 'ERROR';
      fnd_file.put_line(fnd_file.log,
		chr(13) ||
		'ERROR: While purging pricing data for request source ' ||
		p_request_source || SQLERRM);
  END purge_pricereq_tables;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0034837 - This Procedure calls the validation procedure and the price_order_batch or the
  --          price_single_line procedure based on the input p_pricing_phase value.
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  10/03/2015  Diptasurjya Chatterjee (TCS)    CHG0034837 - Initial Build
  -- 1.1  04/11/2015  Diptasurjya Chatterjee (TCS)    CHG0036750 - Set policy context before every pricing call
  -- 1.2  10/27/2017  Diptasurjya Chatterjee (TCS)    CHG0041715 - Handle special error code EP03 for invalid promo code
  -- 1.3  11/27/2017  Diptasurjya Chatterjee (TCS)    CHG0041897 - Modify procedure to be compatiable with SFDC calls
  --                                                  a. procedure renamed to price_request from ecom_price_request
  --                                                  b. add new parameter p_custom_attributes based on table of records type xxqp_pricereq_custatt_tab_type
  --                                                     This attribute will hold key value pair of qualifier/pricing attributes which will be
  --                                                     overriding attribute values as calculated by Oracle
  --                                                  c. add new parameter p_request_source. This will be based on the value set XXSSYS_EVENT_TARGET_NAME
  --                                                     Only targets with DFF Price Request API set to Y will have access to this API
  --                                                  d. add new parameter p_process_xtra_field. Extra fields for any source if needed will be processed
  --                                                     based on this parameter value. DEFAULT value will be N
  --      28.1.2018   yuval tal                       CHG0041897   price_request :modify line number in case line number is null put max value +1
  -- 1.4  10/17/2018  Diptasurjya                     CHG0044153 - allow saving of pricing line output
  -- 1.5  02/17/2020  Diptasurjya                     CHG0047446 - Allow pricing API to generate line_num from source_ref_id field in custom attributes
  -- 1.6  03/15/2020  Diptasurjya                     INC0186599 - Pricing API issue for Hybris due to missing NULL check for custom attribute input
  ----------------------------------------------------------------------------

  -- --------------------------------------------------------------------------------------------

  PROCEDURE price_request(p_order_header       IN xxecom.xxqp_pricereq_header_tab_type,
		  p_item_lines         IN xxecom.xxqp_pricereq_lines_tab_type,
		  p_custom_attributes  IN xxobjt.xxqp_pricereq_custatt_tab_type, -- CHG0041897
		  p_pricing_phase      IN VARCHAR2,
		  p_debug_flag         IN VARCHAR2 DEFAULT 'N', -- CHG0041897 - Change default to N
		  p_pricing_server     IN VARCHAR2 DEFAULT 'NORMAL',
		  p_process_xtra_field IN VARCHAR2 DEFAULT 'N', -- CHG0041897
		  p_request_source     IN VARCHAR2, -- CHG0041897
		  x_session_details    OUT xxecom.xxqp_pricereq_session_tab_type,
		  x_order_details      OUT xxecom.xxqp_pricereq_header_tab_type,
		  x_line_details       OUT xxecom.xxqp_pricereq_lines_tab_type,
		  x_modifier_details   OUT xxecom.xxqp_pricereq_mod_tab_type,
		  x_attribute_details  OUT xxecom.xxqp_pricereq_attr_tab_type,
		  x_related_adjustment OUT xxecom.xxqp_pricereq_reltd_tab_type,
		  x_status             OUT VARCHAR2,
		  x_status_message     OUT VARCHAR2) IS
    l_pricing_mode   VARCHAR2(20);
    l_pricing_server VARCHAR2(20);
  
    l_request_number VARCHAR2(20);
  
    l_valid_order_header   xxqp_pricereq_header_tab_type := xxqp_pricereq_header_tab_type();
    l_valid_item_lines     xxqp_pricereq_lines_tab_type := xxqp_pricereq_lines_tab_type();
    l_valid_custom_attribs xxqp_pricereq_custatt_tab_type := xxqp_pricereq_custatt_tab_type();
  
    l_session_details_out    xxqp_pricereq_session_tab_type := xxqp_pricereq_session_tab_type();
    l_order_details_out      xxqp_pricereq_header_tab_type := xxqp_pricereq_header_tab_type();
    l_line_details_out       xxqp_pricereq_lines_tab_type := xxqp_pricereq_lines_tab_type();
    l_modifier_details_out   xxqp_pricereq_mod_tab_type := xxqp_pricereq_mod_tab_type();
    l_attribute_details_out  xxqp_pricereq_attr_tab_type := xxqp_pricereq_attr_tab_type();
    l_related_adjustment_out xxqp_pricereq_reltd_tab_type := xxqp_pricereq_reltd_tab_type();
  
    l_data_insert_count     NUMBER := 1;
    l_duplicate_request_cnt NUMBER := 0;
  
    l_main_status             VARCHAR2(10) := 'S';
    l_main_status_message     VARCHAR2(2000);
    l_prc_call_status         VARCHAR2(10) := 'S';
    l_prc_call_status_message VARCHAR2(2000);
    l_validation_status       VARCHAR2(10) := 'S';
    l_validation_message      VARCHAR2(2000);
    l_insert_status           VARCHAR2(10) := 'S';
    l_insert_message          VARCHAR2(2000);
  
    l_request_source_user VARCHAR2(200); -- CHG0041897
    l_max_line_number     NUMBER := 0;
    l_item_lines          xxecom.xxqp_pricereq_lines_tab_type;
    l_custom_attributes   xxobjt.xxqp_pricereq_custatt_tab_type; -- CHG0047446
  BEGIN
  
    l_pricing_mode   := upper(p_pricing_phase);
    l_pricing_server := upper(p_pricing_server);
  
    --CHG0041897 fill empty line number
    l_item_lines := p_item_lines;
    FOR i IN 1 .. p_item_lines.count
    LOOP
      l_max_line_number := greatest(l_max_line_number,
			nvl(p_item_lines(i).line_num, -1));
    
    END LOOP;
    -- set number
    FOR i IN 1 .. p_item_lines.count
    LOOP
      IF p_item_lines(i).line_num IS NULL THEN
        l_item_lines(i).line_num := l_max_line_number + 1;
        l_max_line_number := l_max_line_number + 1;
      END IF;
    
    END LOOP;
    --
  
    -- CHG0047446 set line number on custom attributes
    -- In case calling system cannot populate line_num, we will take source_ref_id of corresponding line for which attribute is to be applied
    -- and determine line_num from line record type 
    IF p_custom_attributes IS NOT NULL AND p_custom_attributes.count > 0 THEN
      -- INC0186599 add this check
      l_custom_attributes := p_custom_attributes;
      FOR i IN 1 .. p_custom_attributes.count
      LOOP
        IF p_custom_attributes(i).line_source_ref_id IS NOT NULL AND p_custom_attributes(i)
           .line_num IS NULL THEN
          BEGIN
	SELECT t1.line_num
	INTO   l_custom_attributes(i).line_num
	FROM   TABLE(CAST(l_item_lines AS xxqp_pricereq_lines_tab_type)) t1
	WHERE  t1.source_ref_id = p_custom_attributes(i)
	      .line_source_ref_id;
          EXCEPTION
	WHEN OTHERS THEN
	  l_custom_attributes(i).line_num := NULL;
          END;
        END IF;
      END LOOP;
    END IF; -- INC0186599 end
    -- end fill empty line number CHG0041897
  
    /* Start - Fatal error checks */
    IF l_pricing_server NOT IN ('NORMAL', 'FAILOVER') THEN
      l_main_status         := 'EP00';
      l_main_status_message := l_main_status_message ||
		       'VALIDATION ERROR: Pricing Server input parameter can have 2 possible values NORMAL and FAILOVER' ||
		       chr(13);
      RAISE e_prc_request_exception;
    END IF;
  
    IF l_pricing_mode NOT IN ('LINE', 'BATCH') THEN
      l_main_status         := 'EP00';
      l_main_status_message := l_main_status_message ||
		       'VALIDATION ERROR: Pricing Mode input parameter can have 2 possible values LINE and BATCH' ||
		       chr(13);
      RAISE e_prc_request_exception;
    END IF;
  
    /* CHG0041897 - Validate p_process_xtra_field */
    IF p_process_xtra_field NOT IN ('Y', 'N') THEN
      l_main_status         := 'EP00';
      l_main_status_message := l_main_status_message ||
		       'VALIDATION ERROR: Process extra fields parameter can have values: Y or N' ||
		       chr(13);
      RAISE e_prc_request_exception;
    END IF;
    /* CHG0041897 - End validation p_process_xtra_field */
  
    /* CHG0041897 - Start request source validation */
    BEGIN
      SELECT attribute2
      INTO   l_request_source_user
      FROM   fnd_flex_values     ffv,
	 fnd_flex_value_sets ffvs
      WHERE  ffvs.flex_value_set_name = 'XXSSYS_EVENT_TARGET_NAME'
      AND    ffvs.flex_value_set_id = ffv.flex_value_set_id
      AND    ffv.attribute1 = 'Y'
      AND    upper(ffv.flex_value) = upper(p_request_source)
      AND    ffv.enabled_flag = 'Y'
      AND    SYSDATE BETWEEN nvl(ffv.start_date_active, SYSDATE - 1) AND
	 nvl(ffv.end_date_active, SYSDATE + 1);
    EXCEPTION
      WHEN no_data_found THEN
        l_main_status         := 'EP00';
        l_main_status_message := l_main_status_message ||
		         'VALIDATION ERROR: Pricing Request source input parameter is not valid' ||
		         chr(13);
        RAISE e_prc_request_exception;
    END;
    /* CHG0041897 - End request source validation */
    /* End - Fatal error checks */
  
    /* CHG0041897 - Start - Change debug turn on logic */
    g_debug_flag := nvl(fnd_profile.value_specific('AFLOG_ENABLED',
				   l_request_source_user),
		p_debug_flag);
    /* CHG0041897 - End - Change debug turn on logic */
  
    /** Starting OM debug based on parameter p_debug_flag */
    IF g_debug_flag = 'Y' THEN
      oe_debug_pub.setdebuglevel(5);
      oe_debug_pub.g_dir    := fnd_profile.value('OE_DEBUG_LOG_DIRECTORY'); -- Must be registered UTL Directory
      g_debug_file_name     := oe_debug_pub.set_debug_mode('FILE');
      l_main_status_message := l_main_status_message ||
		       'OM Debug Log location: ' ||
		       g_debug_file_name || chr(13);
      oe_debug_pub.initialize;
      oe_debug_pub.debug_on;
      oe_debug_pub.add('SSYS CUSTOM: OM Debug log location: ' ||
	           g_debug_file_name);
    END IF;
    /** End debug flag setting */
  
    /** Insert Price Request Session data */
    IF l_pricing_mode = 'BATCH' AND l_pricing_server = 'NORMAL' THEN
      IF p_order_header(1).price_request_number IS NOT NULL THEN
        -- CHG0041897
        l_request_number := p_order_header(1).price_request_number; -- CHG0041897
      
        l_data_insert_count := insert_pricereq_session(g_debug_file_name,
				       p_pricing_server,
				       l_request_number,
				       p_request_source); -- CHG0041897
        l_main_status       := 'S';
      ELSE
        l_main_status         := 'E';
        l_main_status_message := l_main_status_message ||
		         'VALIDATION ERROR: Price Request ID must be provided.' ||
		         chr(13);
      END IF;
    END IF;
    /** End Price Request session data insert */
  
    IF g_debug_flag = 'Y' THEN
      oe_debug_pub.add('SSYS CUSTOM: Start Log for REQUEST NUMBER : ' ||
	           l_request_number);
    END IF;
  
    /** Validate input data for Price Request */
    IF l_main_status = 'S' THEN
      l_main_status_message := l_main_status_message ||
		       'Data Received: Header: ' ||
		       p_order_header.count || ' Line: ' ||
		       p_item_lines.count || chr(13);
    
      validate_data(p_order_header,
	        l_item_lines, -- CHG0041897 change from p_item_lines yuval
	        --p_custom_attributes, -- CHG0041897  -- CHG0047446 commented
	        l_custom_attributes, -- CHG0047446 added
	        l_pricing_mode,
	        p_request_source, -- CHG0041897
	        l_valid_order_header,
	        l_valid_item_lines,
	        l_valid_custom_attribs, -- CHG0041897
	        l_validation_status,
	        l_validation_message);
    
      l_request_number      := l_valid_order_header(1).price_request_number; -- CHG0041897
      l_main_status         := l_validation_status;
      l_main_status_message := l_main_status_message ||
		       l_validation_message || chr(13);
    
      l_main_status_message := l_main_status_message ||
		       'Data After Validation: Header: ' ||
		       l_valid_order_header.count || ' Line: ' ||
		       l_valid_item_lines.count || chr(13);
    
    END IF;
    /* End validate data for Price Request */
  
    IF l_main_status = 'S' THEN
      mo_global.set_policy_context('S', l_valid_order_header(1).org_id);
    
      IF l_pricing_mode = 'LINE' THEN
        price_single_line(l_valid_order_header,
		  l_valid_item_lines,
		  l_valid_custom_attribs, -- CHG0041897
		  g_debug_flag,
		  p_request_source, -- CHG0041897
		  p_process_xtra_field, -- CHG0041897
		  x_order_details,
		  x_line_details,
		  l_modifier_details_out,
		  l_attribute_details_out,
		  l_related_adjustment_out,
		  l_prc_call_status,
		  l_prc_call_status_message);
      
        l_main_status         := l_prc_call_status;
        l_main_status_message := l_main_status_message ||
		         l_prc_call_status_message || chr(13);
      
        IF l_main_status = 'S' THEN
          l_main_status := 'SP01';
        ELSE
          l_main_status := 'EP01';
        END IF;
      ELSE
      
        price_order_batch(p_order_header           => l_valid_order_header,
		  p_item_lines             => l_valid_item_lines,
		  p_custom_attributes      => l_valid_custom_attribs, -- CHG0041897
		  p_debug_flag             => g_debug_flag,
		  p_pricing_server         => l_pricing_server,
		  p_request_number         => l_request_number,
		  p_process_xtra_field     => p_process_xtra_field, -- CHG0041897
		  p_request_source         => p_request_source, -- CHG0041897
		  x_session_details_out    => l_session_details_out,
		  x_order_details_out      => x_order_details,
		  x_line_details_out       => x_line_details,
		  x_modifier_details_out   => l_modifier_details_out,
		  x_attribute_details_out  => l_attribute_details_out,
		  x_related_adjustment_out => l_related_adjustment_out,
		  x_status                 => l_prc_call_status,
		  x_status_message         => l_prc_call_status_message);
      
        l_main_status         := l_prc_call_status;
        l_main_status_message := l_main_status_message ||
		         l_prc_call_status_message || chr(13);
      
        IF l_main_status = 'S' AND l_pricing_server = 'NORMAL' THEN
          insert_pricereq_tables(l_session_details_out,
		         x_line_details, -- CHG0044153
		         l_modifier_details_out,
		         l_attribute_details_out,
		         l_related_adjustment_out,
		         l_pricing_server,
		         l_request_number,
		         p_request_source, -- CHG0041897
		         l_insert_status,
		         l_insert_message);
        
          l_main_status         := l_insert_status;
          l_main_status_message := l_main_status_message ||
		           l_insert_message || chr(13);
        END IF;
      
        IF l_main_status = 'S' THEN
          l_main_status := 'SP01';
        ELSE
          l_main_status := 'EP02';
        END IF;
      END IF;
    ELSE
      IF l_pricing_mode = 'LINE' THEN
        l_main_status := 'EP01';
        -- CHG0041715 - Start handling of speacial error code EP03 for promo codes
      ELSE
        IF l_main_status = 'EP' THEN
          l_main_status := 'EP03';
        ELSE
          l_main_status := 'EP02';
        END IF;
        -- CHG0041715 - End
      END IF;
    END IF;
  
    IF l_pricing_server = 'FAILOVER' AND l_pricing_mode = 'BATCH' THEN
      x_session_details    := l_session_details_out;
      x_modifier_details   := l_modifier_details_out;
      x_attribute_details  := l_attribute_details_out;
      x_related_adjustment := l_related_adjustment_out;
    END IF;
  
    IF g_debug_flag = 'Y' THEN
      oe_debug_pub.debug_off;
    END IF;
  
    x_status         := l_main_status;
    x_status_message := l_main_status_message;
    ROLLBACK;
  EXCEPTION
    WHEN e_prc_request_exception THEN
      x_status         := l_main_status;
      x_status_message := l_main_status_message;
    WHEN OTHERS THEN
      ROLLBACK;
      x_status         := 'EP00';
      x_status_message := l_main_status_message || SQLERRM || chr(13);
      oe_debug_pub.add('SSYS CUSTOM: ECOM_PRICE_REQUEST faced unexpected issues: ' ||
	           SQLERRM);
  END price_request;
  /******************************************************************************************************************************************
  * Type                : Procedure                                                                                                         *
  * Module Name         :
  * Name                :
  * Script Name         :
  *                                                                                                                                         *
  * Purpose             :
  
  * HISTORY                                                                                                                                 *
  * =======                                                                                                                                 *
  * VERSION  DATE        AUTHOR(S)          DESCRIPTION                                                                                        *
  * -------  ----------- ---------------    ------------------------------------                                                               *
  * 1.00     05/06/2018  Lingaraj           Initial version                                                                                      *
  ******************************************************************************************************************************************/
  PROCEDURE get_territory_org_info(p_country        IN VARCHAR2,
		           x_territory_code OUT VARCHAR2,
		           x_org_id         OUT NUMBER,
		           x_ou_unit_name   OUT VARCHAR2,
		           x_error_code     OUT VARCHAR2,
		           x_error_msg      OUT VARCHAR2) IS
    xxrecord_not_found EXCEPTION;
  BEGIN
    x_error_code := fnd_api.g_ret_sts_success;
    --Fetch territory_code
    BEGIN
      SELECT territory_code
      INTO   x_territory_code
      FROM   fnd_territories_vl t
      WHERE  upper(territory_short_name) = upper(p_country);
    EXCEPTION
      WHEN no_data_found THEN
        x_error_msg := 'Territory_Code Not Found for Country :' ||
	           p_country;
        RAISE xxrecord_not_found;
    END;
    --Fetch Operating Unit Id
    BEGIN
      SELECT to_number(attribute1)
      INTO   x_org_id
      FROM   fnd_lookup_values_vl
      WHERE  lookup_type = 'XXSERVICE_COUNTRIES_SECURITY'
      AND    lookup_code = x_territory_code;
    
      --Fetch Operating Unit  Name
      SELECT NAME
      INTO   x_ou_unit_name
      FROM   hr_operating_units
      WHERE  organization_id = x_org_id;
    EXCEPTION
      WHEN no_data_found THEN
        x_error_msg := 'The chosen Country is not associated with an operating unit.';
        RAISE xxrecord_not_found;
    END;
  
  EXCEPTION
    WHEN xxrecord_not_found THEN
      x_error_code := fnd_api.g_ret_sts_error;
    WHEN OTHERS THEN
      x_error_code := fnd_api.g_ret_sts_error;
      x_error_msg  := SQLERRM;
  END get_territory_org_info;

END xxqp_request_price_pkg;
/
