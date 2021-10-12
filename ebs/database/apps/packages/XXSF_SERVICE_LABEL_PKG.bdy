CREATE OR REPLACE PACKAGE BODY xxsf_service_label_pkg IS

  --------------------------------------------------------------------
  --  name:            XXSF_SERVICE_LABEL_PKG
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   24/11/2014 16:21:42
  --------------------------------------------------------------------
  --  purpose :        CHG0033507 XXSF - Service Label form report
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  24/11/2014  Dalit A. Raviv    initial build
  --  1.1  27/01/2015  Dalit A. Raviv    CHG0034438 - add parameter P_MOVE_ORDER_LOW
  --  1.2  08.06.20    yuval tal         CHG0048100 - modify before report 
  --------------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:            beforereport
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   24/11/2014
  --------------------------------------------------------------------
  --  purpose :        CHG0033507 XXSF - Service Label form report
  --                   Check if report need to be print.
  --                   when no data found or both parameters are null return false.
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  24/11/2014  Dalit A. Raviv  initial build
  --  1.1  27/01/2015  Dalit A. Raviv  CHG0034438 - add parameter P_MOVE_ORDER_LOW
  --  1.2  01/08/2019  Adi Safin       INC0153411 - Support Internal FOC orders add to 13 to ffv.attribute1  IN ('5','13')
  --  1.3  04/06/2020  yuval tal       CHG0048100 - improve performance - chg to dynamic sql 
  --------------------------------------------------------------------
  FUNCTION beforereport(p_delivery_id    IN NUMBER,
		p_order_num      IN NUMBER,
		p_move_order_low IN VARCHAR2) RETURN BOOLEAN IS
    l_count NUMBER := 0;
  
    l_sql VARCHAR2(5000);
  
    l_delivery_id    NUMBER := p_delivery_id;
    l_order_num      NUMBER := p_order_num;
    l_move_order_low VARCHAR2(50) := p_move_order_low;
  BEGIN
  
    IF p_delivery_id IS NULL AND p_order_num IS NULL AND
       p_move_order_low IS NULL THEN
      fnd_file.put_line(fnd_file.log,
		'All Parameters are null. Please enter order number, delivery number or move order number.');
      RETURN FALSE;
    END IF;
    -------------------- --CHG0048100
  
    p_query := q'[WITH QUA AS (SELECT LEVEL RNK FROM DUAL CONNECT BY LEVEL <= 500)
select        hp.party_name CUSTOMER_NAME,
		ooha.cust_po_number FIELS_SERVICE_ENGINEER,
		ooha.attribute11 SR_NUMBER,
		ooha.attribute12 MACHINE_SERIAL,
		ooha.order_number ORDER_NUMBER,
		el_fix_barcode(IDAUTOMATION_UNI.CODE128A(ooha.order_number)) ORDER_BARCODE,
		case
			when XXINV_UTILS_PKG.get_related_item(null,
			           msi.inventory_item_id,
			           XXINV_UTILS_PKG.is_fdm_item(MSI.INVENTORY_ITEM_ID),
			           'CODE') is not null then
				oola.ordered_item || '    ' ||
				XXINV_UTILS_PKG.get_related_item(null,
												msi.inventory_item_id,
												XXINV_UTILS_PKG.is_fdm_item(MSI.INVENTORY_ITEM_ID),
												'CODE')
        else
          oola.ordered_item
		end PART_NUMBER,
		msi.description PART_DESCRIPTION,
		oola.ship_from_org_id SHIP_FROM_ORG_ID,
		oola.ordered_quantity ORDERED_QUANTITY,
		oola.line_id LINE_ID,
		wnd.delivery_id DELIVERY_ID,
		DECODE(MSI.ATTRIBUTE12, 'Y', 'Yes', 'No') RETURNABLE
  from fnd_flex_value_sets          ffvs,
       fnd_flex_values              ffv,
       fnd_flex_values_tl           ffvt,
       oe_order_headers_all         ooha,
       oe_order_lines_all           oola,
       QUA,
       mtl_system_items_b           msi,
       hz_cust_accounts             hca,
       hz_parties                   hp,
       wsh.wsh_new_deliveries       wnd,
       wsh.wsh_delivery_assignments wda,
       wsh.wsh_delivery_details     wdd,
       mtl_txn_request_headers      trh,
       mtl_txn_request_lines        trl
 where ffvs.flex_value_set_name = 'XXOM_SF2OA_Order_Types_Mapping'
   and ffvs.flex_value_set_id = ffv.flex_value_set_id
   and ffvt.flex_value_id = ffv.flex_value_id
   and ffvt.language = 'US'
   and ffv.enabled_flag = 'Y'
   and msi.inventory_item_id = oola.inventory_item_id
   and msi.organization_id = 91
   and ffv.attribute1 in ('5','13')
   and ffv.attribute3 = to_char(ooha.order_type_id)
   and ooha.header_id = oola.header_id
   and oola.ordered_quantity <> 0
   and hp.party_id = hca.party_id
   and hp.party_type = 'ORGANIZATION'
   and hca.cust_account_id = ooha.sold_to_org_id
   and oola.line_category_code = 'ORDER'
   and qua.rnk <= wdd.requested_quantity
   and wnd.delivery_id = wda.delivery_id
   and wda.delivery_detail_id = wdd.delivery_detail_id
   and wdd.source_header_id = ooha.header_id
   and wdd.source_line_id = oola.line_id
   and trl.line_id = wdd.move_order_line_id
   and trh.header_id = trl.header_id]';
  
    l_sql := q'[select 1
    FROM   fnd_flex_value_sets          ffvs,
           fnd_flex_values              ffv,
           fnd_flex_values_tl           ffvt,
           oe_order_headers_all         ooha,
           oe_order_lines_all           oola,
           mtl_system_items_b           msi,
           hz_cust_accounts             hca,
           hz_parties                   hp,
           wsh.wsh_new_deliveries       wnd,
           wsh.wsh_delivery_assignments wda,
           wsh.wsh_delivery_details     wdd,
           mtl_txn_request_headers      trh,
           mtl_txn_request_lines        trl
    WHERE  rownum = 1
    AND    ffvs.flex_value_set_name = 'XXOM_SF2OA_Order_Types_Mapping'
    AND    ffvs.flex_value_set_id = ffv.flex_value_set_id
    AND    ffvt.flex_value_id = ffv.flex_value_id
    AND    ffvt.language = 'US'
    AND    ffv.enabled_flag = 'Y'
    AND    msi.inventory_item_id = oola.inventory_item_id
    AND    msi.organization_id = 91
    AND    ffv.attribute1 IN ('5', '13')
    AND    ffv.attribute3 = to_char(ooha.order_type_id)
    AND    ooha.header_id = oola.header_id
    AND    oola.ordered_quantity <> 0
    AND    hp.party_id = hca.party_id
    AND    hp.party_type = 'ORGANIZATION'
    AND    hca.cust_account_id = ooha.sold_to_org_id
    AND    oola.line_category_code = 'ORDER'
    AND    wnd.delivery_id = wda.delivery_id
    AND    wda.delivery_detail_id = wdd.delivery_detail_id
    AND    wdd.source_header_id = ooha.header_id
    AND    wdd.source_line_id = oola.line_id
    AND    trl.line_id = wdd.move_order_line_id
    AND    trh.header_id = trl.header_id]';
  
    IF l_move_order_low IS NOT NULL THEN
      l_sql := l_sql || ' and trh.request_number = :p_move_order_low';
    
      p_query := p_query || ' ' ||
	     ' and trh.request_number = :p_move_order_low';
    
    ELSE
      l_sql            := l_sql || ' and  1 = :p_move_order_low';
      l_move_order_low := '1';
    END IF;
  
    IF l_order_num IS NOT NULL THEN
      l_sql   := l_sql || ' and ooha.order_number = :p_order_num';
      p_query := p_query || ' ' || ' and ooha.order_number = :p_order_num';
    ELSE
      l_sql       := l_sql || ' and  1 = :p_order_num';
      l_order_num := 1;
    END IF;
  
    IF l_delivery_id IS NOT NULL THEN
      l_sql   := l_sql || ' and wnd.delivery_id = :p_delivery_id';
      p_query := p_query || ' ' || ' and wnd.delivery_id = :p_delivery_id';
    ELSE
      l_sql         := l_sql || ' and 1 = :p_delivery_id';
      l_delivery_id := 1;
    END IF;
  
    -- AND    trh.request_number = nvl(p_move_order_low, trh.request_number)
    -- AND    ooha.order_number = nvl(p_order_num, ooha.order_number)
    --  AND    wnd.delivery_id = nvl(p_delivery_id, wnd.delivery_id);
    fnd_file.put_line(fnd_file.log,
	          '--------------------------------------');
    fnd_file.put_line(fnd_file.log, p_query);
    fnd_file.put_line(fnd_file.log,
	          '--------------------------------------');
  
    EXECUTE IMMEDIATE l_sql
      INTO l_count
      USING l_move_order_low, l_order_num, l_delivery_id;
  
    IF l_count <> 0 THEN
      RETURN TRUE;
    ELSE
      fnd_file.put_line(fnd_file.log,
		'----------------------------------------');
      IF p_delivery_id IS NOT NULL THEN
        fnd_file.put_line(fnd_file.log,
		  'Delivery - ' || p_delivery_id ||
		  ' Delivery not relate to service internal order');
      END IF;
      IF p_order_num IS NOT NULL THEN
        fnd_file.put_line(fnd_file.log,
		  'SO Order - ' || p_order_num ||
		  ' Order not relate to service internal order');
      END IF;
      fnd_file.put_line(fnd_file.log,
		'----------------------------------------');
    
      RETURN FALSE;
    END IF;
  EXCEPTION
    WHEN no_data_found THEN
      fnd_file.put_line(fnd_file.log, 'no_data_found');
      RETURN FALSE;
    
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log,
		'----------------------------------------');
      fnd_file.put_line(fnd_file.log,
		'General error - ' || substr(SQLERRM, 1, 240));
      fnd_file.put_line(fnd_file.log, 'Delivery   - ' || p_delivery_id);
      fnd_file.put_line(fnd_file.log, 'SO Order   - ' || p_order_num);
      fnd_file.put_line(fnd_file.log, 'Move Order - ' || p_move_order_low);
      fnd_file.put_line(fnd_file.log,
		'----------------------------------------');
      RETURN FALSE;
  END beforereport;

END xxsf_service_label_pkg;
/
