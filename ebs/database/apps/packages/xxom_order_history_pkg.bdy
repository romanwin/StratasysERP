CREATE OR REPLACE PACKAGE BODY xxom_order_history_pkg AS

  --------------------------------------------------------------------
  --  name:            xxom_order_history_pkg
  --  create by:       Kundan Bhagat
  --  Revision:        1.0
  --  creation date:   09/06/2015
  --------------------------------------------------------------------
  --  purpose :        Fetch Sales Order History data from Oracle ERP database
  --                   for provided set of parameters
  --------------------------------------------------------------------
  --  ver  date        name                           desc
  --  1.0  09/06/2015  Kundan Bhagat         CHG0035653 - initial build
  --  1.1  10/28/2015  Kundan Bhagat         CHG0036750 - Adjust ecommerce order history to include org id parameter
  --  1.1  10/30/2015  Kundan Bhagat         Added Input Parameter : p_order_source
  --  1.2  13.6.16     yuval tal             CHG0038756   : change customer_order_history : avoid to_timestamp feature use creation date instead
  --  1.3  03/20/2018  Diptasurjya           CHG0042550 - Search algorithm changed based on unifid search string for Order number
  --                                         PO Number and Ship to customer name
  --  1.4  07/18/2018  Diptasurjya           CHG0042626 - Change the date check to truncate the p_first_run date value received in customer_order_history
  --                                         Add local language checks in bill and ship address derivations
  --  1.5  23-May-2019 Diptasurjya           CHG0045755 - Make changes for PTO item history query
  --                                                      Change list of orders disaplyed based on contact level DFF setting
  --------------------------------------------------------------------

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0035653 - This function returns technology of item for provided header_id
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                      Description
  -- 1.0  09/06/2015  Kundan Bhagat    Initial Build
  -- --------------------------------------------------------------------------------------------

  FUNCTION get_item_technology(p_header_id NUMBER) RETURN VARCHAR2 IS
    l_item_technology VARCHAR2(1000);
  BEGIN
    SELECT listagg(item_technology, ',') within GROUP(ORDER BY header_id)
    INTO   l_item_technology
    FROM   (SELECT DISTINCT mc.segment6    item_technology,
		    oola.header_id header_id
	FROM   oe_order_lines_all  oola,
	       mtl_item_categories mic,
	       mtl_categories_kfv  mc,
	       mtl_category_sets   mcs
	WHERE  oola.header_id = p_header_id
	AND    mic.category_id = mc.category_id
	AND    mcs.category_set_id = mic.category_set_id
	AND    mic.inventory_item_id = oola.inventory_item_id
	AND    mic.organization_id =
	       xxinv_utils_pkg.get_master_organization_id
	AND    mcs.category_set_name = 'Product Hierarchy'
	AND    mc.segment6 IN ('FDM', 'POLYJET')
	AND    oola.ordered_item <> 'FREIGHT');
  
    RETURN l_item_technology;
  END get_item_technology;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0035653 - This function returns shipping address for provided ship_to_org_id.
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                      Description
  -- 1.0  09/06/2015  Kundan Bhagat             Initial Build
  -- 1.1  07/16/2018  Diptasurjya               CHG0042626 - Add local language support
  -- --------------------------------------------------------------------------------------------

  FUNCTION get_ship_address(p_ship_to_org_id NUMBER) RETURN VARCHAR2 IS
    l_ship_to_address VARCHAR2(1206);
  BEGIN
    SELECT nvl(ship_ps.attribute5 /* <-- CHG0042626 - Address local*/,
	   (ship_loc.address1 || ship_loc.address2 || ship_loc.address3 ||
	   ship_loc.address4)) || ', ' ||
           (decode(nvl(ship_ps.attribute4, ship_loc.city),
	       NULL,
	       NULL,
	       nvl(ship_ps.attribute4, ship_loc.city) || ', ') || /* <-- CHG0042626 - City local language*/
	decode(ship_loc.state,
	       NULL,
	       ship_loc.province || ', ',
	       ship_loc.state || ', ') ||
	decode(ship_loc.postal_code,
	       NULL,
	       NULL,
	       ship_loc.postal_code || ', ') ||
	decode(ship_loc.country, NULL, NULL, ship_loc.country))
    --decode(nvl(ship_ps.attribute3,ship_loc.country), NULL, NULL, nvl(ship_ps.attribute3,ship_loc.country)))  /* <-- CHG0042626 - Country local language*/
    INTO   l_ship_to_address
    FROM   hz_cust_site_uses_all  ship_su,
           hz_party_sites         ship_ps,
           hz_locations           ship_loc,
           hz_cust_acct_sites_all ship_cas
    WHERE  ship_su.site_use_id = p_ship_to_org_id
    AND    ship_su.cust_acct_site_id = ship_cas.cust_acct_site_id
    AND    ship_cas.party_site_id = ship_ps.party_site_id
    AND    ship_loc.location_id = ship_ps.location_id;
  
    RETURN l_ship_to_address;
  END get_ship_address;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0035653 - This function returns billing address for provided invoice_to_org_id.
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                      Description
  -- 1.0  09/06/2015  Kundan Bhagat             Initial Build
  -- 1.1  07/16/2018  Diptasurjya               CHG0042626 - Add local language support
  -- --------------------------------------------------------------------------------------------

  FUNCTION get_bill_address(p_invoice_to_org_id NUMBER) RETURN VARCHAR2 IS
    l_bill_to_address VARCHAR2(1206);
  BEGIN
    SELECT nvl(bill_ps.attribute5 /* <-- CHG0042626 - Address local*/,
	   (bill_loc.address1 || bill_loc.address2 || bill_loc.address3 ||
	   bill_loc.address4)) || ', ' ||
           (decode(nvl(bill_ps.attribute4, bill_loc.city),
	       NULL,
	       NULL,
	       nvl(bill_ps.attribute4, bill_loc.city) || ', ') || /* <-- CHG0042626 - City local language*/
	decode(bill_loc.state,
	       NULL,
	       bill_loc.province || ', ',
	       bill_loc.state || ', ') ||
	decode(bill_loc.postal_code,
	       NULL,
	       NULL,
	       bill_loc.postal_code || ', ') ||
	decode(bill_loc.country, NULL, NULL, bill_loc.country))
    --decode(nvl(bill_ps.attribute3,bill_loc.country), NULL, NULL, nvl(bill_ps.attribute3,bill_loc.country))) /* <-- CHG0042626 - Country local language*/
    INTO   l_bill_to_address
    FROM   hz_cust_site_uses_all  bill_su,
           hz_party_sites         bill_ps,
           hz_locations           bill_loc,
           hz_cust_acct_sites_all bill_cas
    WHERE  bill_su.site_use_id = p_invoice_to_org_id
    AND    bill_su.cust_acct_site_id = bill_cas.cust_acct_site_id
    AND    bill_cas.party_site_id = bill_ps.party_site_id
    AND    bill_loc.location_id = bill_ps.location_id;
  
    RETURN l_bill_to_address;
  END get_bill_address;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0035653 - This function returns Sold to contact name for provided sold_to_contact_id.
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                      Description
  -- 1.0  09/06/2015  Kundan Bhagat             Initial Build
  -- --------------------------------------------------------------------------------------------

  FUNCTION get_sold_contact(p_sold_to_contact_id NUMBER) RETURN VARCHAR2 IS
    l_sold_to_contact VARCHAR2(383);
  BEGIN
    SELECT sold_party.person_last_name ||
           decode(sold_party.person_first_name,
	      NULL,
	      NULL,
	      ', ' || sold_party.person_first_name)
    INTO   l_sold_to_contact
    FROM   hz_cust_account_roles sold_roles,
           hz_parties            sold_party,
           hz_cust_accounts      sold_acct,
           hz_relationships      sold_rel
    WHERE  sold_roles.cust_account_role_id = p_sold_to_contact_id
    AND    sold_roles.party_id = sold_rel.party_id
    AND    sold_roles.role_type = 'CONTACT'
    AND    sold_roles.cust_account_id = sold_acct.cust_account_id
    AND    nvl(sold_rel.object_id, -1) = nvl(sold_acct.party_id, -1)
    AND    sold_rel.subject_id = sold_party.party_id(+);
  
    RETURN l_sold_to_contact;
  END get_sold_contact;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0035653 - This function returns Ship to contact name for provided ship_to_contact_id.
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                      Description
  -- 1.0  09/06/2015  Kundan Bhagat             Initial Build
  -- --------------------------------------------------------------------------------------------

  FUNCTION get_ship_contact(p_ship_to_contact_id NUMBER) RETURN VARCHAR2 IS
    l_ship_to_contact VARCHAR2(383);
  BEGIN
    SELECT ship_party.person_last_name ||
           decode(ship_party.person_first_name,
	      NULL,
	      NULL,
	      ', ' || ship_party.person_first_name)
    INTO   l_ship_to_contact
    FROM   hz_cust_account_roles ship_roles,
           hz_parties            ship_party,
           hz_relationships      ship_rel,
           hz_cust_accounts      ship_acct
    WHERE  ship_roles.cust_account_role_id = p_ship_to_contact_id
    AND    ship_roles.party_id = ship_rel.party_id
    AND    ship_roles.role_type = 'CONTACT'
    AND    ship_roles.cust_account_id = ship_acct.cust_account_id
    AND    nvl(ship_rel.object_id, -1) = nvl(ship_acct.party_id, -1)
    AND    ship_rel.subject_id = ship_party.party_id;
  
    RETURN l_ship_to_contact;
  END get_ship_contact;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0035653 - This function returns Bill to contact name for provided invoice_to_contact_id.
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                      Description
  -- 1.0  09/06/2015  Kundan Bhagat             Initial Build
  -- --------------------------------------------------------------------------------------------

  FUNCTION get_bill_contact(p_invoice_to_contact_id NUMBER) RETURN VARCHAR2 IS
    l_invoice_to_contact VARCHAR2(383);
  BEGIN
    SELECT invoice_party.person_last_name ||
           decode(invoice_party.person_first_name,
	      NULL,
	      NULL,
	      ', ' || invoice_party.person_first_name)
    INTO   l_invoice_to_contact
    FROM   hz_cust_account_roles invoice_roles,
           hz_parties            invoice_party,
           hz_relationships      invoice_rel,
           hz_cust_accounts      invoice_acct
    WHERE  invoice_roles.cust_account_role_id = p_invoice_to_contact_id
    AND    invoice_roles.party_id = invoice_rel.party_id
    AND    invoice_roles.role_type = 'CONTACT'
    AND    invoice_roles.cust_account_id = invoice_acct.cust_account_id
    AND    nvl(invoice_rel.object_id, -1) = nvl(invoice_acct.party_id, -1)
    AND    invoice_rel.subject_id = invoice_party.party_id;
  
    RETURN l_invoice_to_contact;
  END get_bill_contact;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0035653 - This function returns Delivery Status for provided header_id.
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                      Description
  -- 1.0  09/06/2015  Kundan Bhagat             Initial Build
  -- --------------------------------------------------------------------------------------------

  FUNCTION get_delivery_status(p_header_id NUMBER) RETURN VARCHAR2 IS
    l_status       VARCHAR2(100);
    l_status_count NUMBER;
    l_line_count   NUMBER;
  BEGIN
    SELECT COUNT(*)
    INTO   l_status_count
    FROM   oe_order_lines_all oola
    WHERE  oola.ordered_item <> 'FREIGHT'
    AND    oola.flow_status_code IN ('SHIPPED', 'CLOSED')
    AND    oola.header_id = p_header_id;
  
    SELECT COUNT(*)
    INTO   l_line_count
    FROM   oe_order_lines_all oola
    WHERE  oola.ordered_item <> 'FREIGHT'
    AND    oola.flow_status_code <> 'CANCELLED'
    AND    oola.header_id = p_header_id;
  
    IF l_status_count = 0 THEN
      IF l_line_count = 0 THEN
        l_status := 'CANCELLED';
      ELSE
        l_status := 'NOT SHIPPED';
      END IF;
    ELSIF l_status_count > 0 THEN
      IF l_line_count = l_status_count THEN
        l_status := 'SHIPPED';
      ELSE
        l_status := 'PARTIAL SHIPPED';
      END IF;
    END IF;
    RETURN l_status;
  END get_delivery_status;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0035653 - This function returns Order Subtotal of order for provided header_id
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                      Description
  -- 1.0  15/06/2015  Kundan Bhagat    Initial Build
  -- --------------------------------------------------------------------------------------------

  FUNCTION get_order_subtotal(p_header_id NUMBER) RETURN NUMBER IS
    l_order_sub_total NUMBER;
  BEGIN
    SELECT round(SUM(oola.unit_selling_price * oola.ordered_quantity), 2)
    INTO   l_order_sub_total
    FROM   oe_order_lines_all oola,
           mtl_system_items_b msib
    WHERE  oola.header_id = p_header_id
    AND    msib.inventory_item_id = oola.inventory_item_id
    AND    msib.organization_id = oola.ship_from_org_id
    AND    msib.segment1 <> 'FREIGHT';
    RETURN l_order_sub_total;
  END get_order_subtotal;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0035653 - This function returns freight handling of order for provided header_id
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                      Description
  -- 1.0  15/06/2015  Kundan Bhagat    Initial Build
  -- --------------------------------------------------------------------------------------------

  FUNCTION get_freight_handling(p_header_id NUMBER) RETURN NUMBER IS
    l_freight_handling NUMBER;
  BEGIN
    SELECT nvl((SELECT round(SUM(oola.unit_selling_price *
		        oola.ordered_quantity),
		    2)
	   FROM   oe_order_lines_all oola,
	          mtl_system_items_b msib
	   WHERE  oola.header_id = p_header_id
	   AND    msib.inventory_item_id = oola.inventory_item_id
	   AND    msib.organization_id = oola.ship_from_org_id
	   AND    msib.segment1 = 'FREIGHT'),
	   0) +
           nvl(oe_totals_grp.get_order_total(p_header_id, NULL, 'CHARGES'),
	   0)
    INTO   l_freight_handling
    FROM   dual;
    RETURN l_freight_handling;
  END get_freight_handling;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0035653 - This function returns header level shipping_method of order for provided header_id
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                      Description
  -- 1.0  15/06/2015  Kundan Bhagat    Initial Build
  -- --------------------------------------------------------------------------------------------

  FUNCTION get_shipping_method(p_shipping_code VARCHAR2) RETURN VARCHAR2 IS
    l_shipping_method VARCHAR2(240);
  BEGIN
    /*SELECT meaning
    INTO   l_shipping_method
    FROM   fnd_lookup_values flv
    WHERE  flv.lookup_type = 'SHIP_METHOD'
    AND    flv.lookup_code = p_shipping_code
    AND    flv.enabled_flag = 'Y'
    AND    flv.LANGUAGE = userenv('LANG');*/
    l_shipping_method := xxobjt_general_utils_pkg.get_lookup_meaning('SHIP_METHOD',
					         p_shipping_code);
    RETURN l_shipping_method;
  END get_shipping_method;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0042550 - This function returns the customer name for an input site_use_id
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                      Description
  -- 1.0  03/20/2018  Diptasurjya Chatterjee    Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION get_cust_namefor_siteuse(p_site_use_id NUMBER) RETURN VARCHAR2 IS
    l_party_name VARCHAR2(360);
  BEGIN
    SELECT hp.party_name
    INTO   l_party_name
    FROM   hz_parties             hp,
           hz_cust_accounts       hca,
           hz_cust_site_uses_all  hcsua,
           hz_cust_acct_sites_all hcasa
    WHERE  hcsua.site_use_id = p_site_use_id
    AND    hcsua.cust_acct_site_id = hcasa.cust_acct_site_id
    AND    hcasa.cust_account_id = hca.cust_account_id
    AND    hca.party_id = hp.party_id;
  
    RETURN l_party_name;
  END get_cust_namefor_siteuse;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0035653 - Send Mail for errors
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                      Description
  -- 1.0  15/06/2015  Kundan Bhagat             Initial Build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE send_mail(p_program_name_to IN VARCHAR2,
	          p_program_name_cc IN VARCHAR2,
	          p_body            IN VARCHAR2) IS
    l_mail_to_list VARCHAR2(240);
    l_mail_cc_list VARCHAR2(240);
    l_err_code     VARCHAR2(4000);
    l_err_msg      VARCHAR2(4000);
  
  BEGIN
    l_mail_to_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
					      p_program_short_name => p_program_name_to);
    l_mail_cc_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
					      p_program_short_name => p_program_name_cc);
  
    xxobjt_wf_mail.send_mail_text(p_to_role     => l_mail_to_list,
		          p_cc_mail     => l_mail_cc_list,
		          p_subject     => 'eStore validation error in Oracle Sales Order History interface - IMPORTANT',
		          p_body_text   => p_body,
		          p_err_code    => l_err_code,
		          p_err_message => l_err_msg);
  
  END send_mail;

  --------------------------------------------------------------------
  --  name:           customer_order_history
  --  create by:      Kundan Bhagat
  --  Revision:       1.0
  --  creation date:  09/06/2015
  --  BPEL process:   http://srv-ire-bpeldev.2objet.com:8001/soa-infra/services/ecomm/QuerySalesOrderHybrisCmp/hybrissalesorderquerybpel_client_ep?WSDL
  --------------------------------------------------------------------
  --  purpose :        Fetch Sales Order History data from Oracle ERP database
  --                   for provided set of parameters
  --------------------------------------------------------------------
  --  ver  date        name                           desc
  --  1.0  09/06/2015  Kundan Bhagat         CHG0035653 - initial build
  --  1.1  10/28/2015  Kundan Bhagat         CHG0036750 - Adjust ecommerce order history to include org id parameter
  --  1.1  10/30/2015  Kundan Bhagat         Added Input Parameter : p_order_source
  --  1.2  13.6.16     yuval tal             CHG0038756  change customer_order_history : avoid to_timestamp feature use creation date instead
  --  1.3  20-MAR-2018 Diptasurjya           CHG0042550 - eCommerce order history search parameter change
  --                   Chatterjee            A single unified search string which might contain Order Number/PO Number
  --                                         or Ship to Customer name will be sent as input instead of order number, in ned parameter p_unified_search_str
  --                                         We will conduct wildcard case insenstive serach based on this input on the mentioned 3 field values
  --  1.4  07/18/2018  Diptasurjya           CHG0042626 - Change the date check to truncate the p_first_run date value received
  --  1.5  23-May-2019 Diptasurjya           CHG0045755 - Make changes for PTO item history query
  --  1.6  30-MAY-2019 Diptasurjya           CHG0045755 - CTASK0042105 - Show orders based on contact level DFF setting
  --------------------------------------------------------------------

  PROCEDURE customer_order_history(p_cust_account_id    IN NUMBER,
		           p_order_header_id    IN NUMBER,
		           p_order_number       IN NUMBER,
		           p_unified_search_str IN VARCHAR2, -- CHG0042550
		           p_days_to_fetch      IN NUMBER,
		           p_order_by           IN VARCHAR2,
		           p_start_index        IN NUMBER,
		           p_end_index          IN NUMBER,
		           p_from_date          IN DATE,
		           p_to_date            IN DATE,
		           p_operation          IN VARCHAR2,
		           p_first_run          IN VARCHAR2,
		           p_org_id             IN NUMBER,
		           p_order_source       IN VARCHAR2,
		           p_logged_contact_id  IN NUMBER, -- CHG0045755 - CTASK0042105
		           x_order_count        OUT NUMBER,
		           x_order_headers      OUT xxobjt.xxom_ord_hist_header_tab_type,
		           x_order_lines        OUT xxobjt.xxom_ord_hist_line_tab_type,
		           x_order_shipments    OUT xxobjt.xxom_ord_hist_ship_tab_type,
		           x_status             OUT VARCHAR2,
		           x_status_message     OUT VARCHAR2) AS
  
    --  used to fetch Sales Order lines information
    CURSOR cur_line(p_header_id IN NUMBER) IS
      SELECT oola.header_id,
	 oola.line_id,
	 ooha.ordered_date,
	 oola.ordered_item,
	 msib.description item_description,
	 msib.inventory_item_id item_id,
	 mc.segment6 item_technology,
	 oola.ordered_quantity,
	 oola.unit_selling_price,
	 (oola.unit_selling_price * oola.ordered_quantity) extended_price,
	 oola.tax_value,
	 flvv.attribute1 status,
	 oos.name chanel,
	 ooha.flow_status_code header_status
      FROM   oe_order_headers_all     ooha,
	 oe_order_lines_all       oola,
	 mtl_system_items_b       msib,
	 fnd_lookup_values_vl     flvv,
	 oe_transaction_types_all otta,
	 oe_order_sources         oos,
	 mtl_item_categories      mic,
	 mtl_categories_kfv       mc,
	 mtl_category_sets        mcs
      WHERE  ooha.header_id = oola.header_id
      AND    ooha.order_type_id = otta.transaction_type_id
      AND    otta.attribute15 = 'Y'
      AND    oola.inventory_item_id = msib.inventory_item_id
      AND    oola.ship_from_org_id = msib.organization_id
      AND    flvv.lookup_code = oola.flow_status_code
      AND    flvv.lookup_type = 'LINE_FLOW_STATUS'
      AND    msib.segment1 <> 'FREIGHT'
      AND    ooha.order_source_id = oos.order_source_id(+)
      AND    mic.category_id = mc.category_id
      AND    mcs.category_set_id = mic.category_set_id
      AND    mcs.category_set_name = 'Product Hierarchy'
      AND    mic.inventory_item_id = oola.inventory_item_id
      AND    mic.organization_id =
	 xxinv_utils_pkg.get_master_organization_id
	--AND    oola.component_sequence_id IS NULL -- To extract Child item  -- CHG0045755 commented to allow PTO items
      AND    oola.link_to_line_id IS NULL -- CHG0045755 added to show only parent PTO lines
      AND    ooha.header_id = p_header_id
      ORDER  BY oola.line_id; -- CHG0045755 added
  
    --  used to fetch Sales Order shipment information
    CURSOR cur_ship(p_header_id IN NUMBER) IS
      SELECT wdlsv.source_line_id ship_line_id,
	 wdlsv.delivery_detail_id ship_id,
	 ooha.ordered_date,
	 to_char(wdlsv.date_shipped, 'YYYY-MM-DD HH24:MI:SS') ship_date,
	 (SELECT carrier_name
	  FROM   wsh_carriers_v
	  WHERE  carrier_id = wdd.carrier_id) freight_carrier,
	 xxobjt_general_utils_pkg.get_lookup_meaning('SHIP_METHOD',
				         wdlsv.ship_method_code) shipping_method,
	 nvl(wnd.attribute1, wnd.waybill) tracking_number,
	 (SELECT SUM(oola.shipped_quantity)
	  FROM   oe_order_lines_all oola
	  WHERE  oola.header_id = ooha.header_id
	  AND    oola.line_id = wdlsv.source_line_id) shipped_qty,
	 oos.name chanel,
	 ooha.flow_status_code header_status
      FROM   wsh_delivery_line_status_v wdlsv,
	 wsh_delivery_assignments   wda,
	 wsh_new_deliveries         wnd,
	 wsh_delivery_details       wdd,
	 oe_order_headers_all       ooha,
	 oe_order_lines_all         oola,
	 oe_transaction_types_all   otta,
	 oe_order_sources           oos
      WHERE  wdlsv.source_header_id = ooha.header_id
      AND    ooha.header_id = oola.header_id
      AND    wdlsv.source_line_id = oola.line_id
      AND    wda.delivery_detail_id = wdd.delivery_detail_id
      AND    wda.delivery_id = wnd.delivery_id
      AND    oola.ordered_item <> 'FREIGHT'
      AND    ooha.order_type_id = otta.transaction_type_id
      AND    otta.attribute15 = 'Y'
      AND    wdd.delivery_detail_id = wdlsv.delivery_detail_id
      AND    ooha.order_source_id = oos.order_source_id(+)
	--AND    oola.component_sequence_id IS NULL -- To extract Child item  -- CHG0045755 commented to allow PTO items
      AND    oola.link_to_line_id IS NULL -- CHG0045755 added to show only parent PTO lines
      AND    ooha.header_id = p_header_id
      ORDER  BY wdlsv.source_line_id; -- CHG0045755 added
  
    TYPE cur_ref_typ IS REF CURSOR;
    cur_header_info cur_ref_typ;
  
    l_header_tab   xxom_ord_hist_header_tab_type := xxom_ord_hist_header_tab_type();
    l_header_data  xxom_ord_hist_hdr_rec;
    l_line_tab     xxom_ord_hist_line_tab_type;
    l_shipment_tab xxom_ord_hist_ship_tab_type;
    e_ord_history_exception EXCEPTION;
    l_header_count     NUMBER := 1;
    l_line_count       NUMBER := 1;
    l_ship_count       NUMBER := 1;
    l_ship_address     VARCHAR2(1206);
    l_bill_address     VARCHAR2(1206);
    l_ship_contact     VARCHAR2(383);
    l_bill_contact     VARCHAR2(383);
    l_sold_contact     VARCHAR2(383);
    l_technology       VARCHAR2(383);
    l_delivery_status  VARCHAR2(100);
    l_status           VARCHAR2(1) := 'S';
    l_status_message   VARCHAR2(2000);
    l_shipping_method  VARCHAR2(240);
    l_total_tax        NUMBER;
    l_order_total      NUMBER;
    l_freight_handling NUMBER;
    l_order_sub_total  NUMBER;
    l_header_str_1     VARCHAR2(4000);
    l_header_str_2     VARCHAR2(4000);
    l_header_str       VARCHAR2(4000);
    l_cond_str         VARCHAR2(4000);
  
    l_contact_order_hist_pref VARCHAR2(200); -- CHG0045755 adde
  
    -- l_select           VARCHAR2(2000); chg0034837
    --l_ordereddate_db  DATE; --    chg0034837  -- CHG0042626 disable
    --l_ordereddate_gmt DATE; --TIMESTAMP(0); CHG0034837  -- CHG0042626 disable
    --  l_ordered_date     VARCHAR2(240);
    l_mail_body   VARCHAR2(4000);
    l_mail_entity VARCHAR2(4000);
    l_from_date   DATE; --; TIMESTAMP(0); CHG0034837
    l_to_date     DATE; --     TIMESTAMP(0); CHG0034837
  BEGIN
    l_status_message := NULL;
    l_status         := 'S';
    l_header_count   := 1;
    l_line_count     := 1;
    l_ship_count     := 1;
    l_header_str_1   := NULL;
    l_header_str_2   := NULL;
    l_header_str     := NULL;
    l_cond_str       := NULL;
    -- l_select         := NULL;
    l_mail_body   := NULL;
    l_mail_entity := NULL;
  
    IF p_cust_account_id IS NULL THEN
      l_status         := 'E';
      l_status_message := l_status_message || chr(13) ||
		  'VALIDATION ERROR: Customer Account ID must be provided';
      RAISE e_ord_history_exception;
    ELSIF p_start_index IS NULL OR p_end_index IS NULL THEN
      l_status         := 'E';
      l_status_message := l_status_message || chr(13) ||
		  'VALIDATION ERROR: Start index and End index must be provided';
      RAISE e_ord_history_exception;
    ELSIF p_days_to_fetch IS NULL THEN
      l_status         := 'E';
      l_status_message := l_status_message || chr(13) ||
		  'VALIDATION ERROR: Number of days must be provided';
      RAISE e_ord_history_exception;
    ELSIF p_first_run IS NULL THEN
      l_status         := 'E';
      l_status_message := l_status_message || chr(13) ||
		  'VALIDATION ERROR: First run time must be provided';
      RAISE e_ord_history_exception;
    ELSIF p_order_source IS NULL THEN
      l_status         := 'E';
      l_status_message := l_status_message || chr(13) ||
		  'VALIDATION ERROR: Order Source must be provided';
      RAISE e_ord_history_exception;
    ELSIF p_org_id IS NULL THEN
      l_status         := 'E';
      l_status_message := l_status_message || chr(13) ||
		  'VALIDATION ERROR: Org Id must be provided';
      RAISE e_ord_history_exception;
      -- CHG0045755 add below validation
    ELSIF p_logged_contact_id IS NULL AND p_operation = 'HEADER' THEN
      l_status         := 'E';
      l_status_message := l_status_message || chr(13) ||
		  'VALIDATION ERROR: Logged In contact Id must be provided';
      RAISE e_ord_history_exception;
    END IF;
  
    l_header_tab   := xxom_ord_hist_header_tab_type();
    l_line_tab     := xxom_ord_hist_line_tab_type();
    l_shipment_tab := xxom_ord_hist_ship_tab_type();
  
    /* CHG0045755 - fetch contact based order history preference from DFF */
    BEGIN
      SELECT nvl(hcard.ecommerce_my_orders_page, 'View Account Orders')
      INTO   l_contact_order_hist_pref
      FROM   hz_cust_account_roles     hcar,
	 hz_cust_account_roles_dfv hcard
      WHERE  hcar.cust_account_role_id = p_logged_contact_id
      AND    hcard.row_id = hcar.rowid;
    EXCEPTION
      WHEN no_data_found THEN
        l_contact_order_hist_pref := 'View Account Orders';
    END;
    /* CHG0045755 - end*/
  
    /*BEGIN
      l_ordereddate_gmt := to_date(p_first_run, 'DD-MON-YYYY HH24:MI:SS');
    EXCEPTION
      WHEN OTHERS THEN
        l_status         := 'E';
        l_status_message := l_status_message || chr(13) ||
        'ERROR: While conversion of gmt date to ''DD-MON-YYYY HH24:MI:SS'' date format. ' ||
        SQLERRM;
        RAISE e_ord_history_exception;
    END;
    l_ordereddate_db := fnd_timezone_pub.adjust_datetime(l_ordereddate_gmt,
                 'GMT',
                 fnd_timezones.get_server_timezone_code);
    
    l_ordereddate_db := trunc(l_ordereddate_db); */ -- CHG0042626 commented
    -- l_ordered_date   := to_char(to_date(l_ordereddate_db,
    --        'DD-MON-YY HH.MI.SS AM'),
    --        'yyyy-mm-dd hh24:mi:ss');
    l_header_str_1 := ' SELECT i.order_header_id,i.ordernumber,i.orderdate,i.formatted_order_date,i.cust_po_number, ' ||
	          ' i.ship_to_org_id,i.invoice_to_org_id,i.sold_to_contact_id,i.ship_to_contact_id,i.invoice_to_contact_id, ' ||
	          ' i.bill_address,i.ship_address,i.bill_contact,i.sold_contact,i.ship_contact,i.payment_terms,i.chanel_org, ' ||
	          ' i.channel,i.status,i.currency_code,i.shipping_method FROM   (SELECT i.* FROM   (SELECT i.*, ' ||
	          ' rownum AS rn FROM  (select * from (SELECT ooha.ROWID AS a_rowid,ooha.header_id order_header_id, ' ||
	          ' ooha.order_number ordernumber,ooha.ordered_date orderdate,to_char(ooha.ordered_date, ''YYYY-MM-DD HH24:MI:SS'') ' ||
	          ' formatted_order_date,regexp_replace(ooha.cust_po_number , ''[[:cntrl:]]'', '''') cust_po_number,ooha.ship_to_org_id ship_to_org_id, ' ||
	          ' ooha.invoice_to_org_id invoice_to_org_id,ooha.sold_to_contact_id sold_to_contact_id, ' ||
	          ' ooha.ship_to_contact_id ship_to_contact_id,ooha.invoice_to_contact_id invoice_to_contact_id, ' ||
	          ' NULL bill_address,NULL ship_address,NULL bill_contact,NULL sold_contact,NULL ship_contact, ' ||
	          ' term.NAME payment_terms,oos.NAME chanel_org,decode(oos.NAME, ''eCommerce Order'', ''WEB'', NULL) channel, ' ||
	          ' ooha.flow_status_code status,ooha.transactional_curr_code currency_code,ooha.shipping_method_code shipping_method ' ||
	          ' FROM oe_order_headers_all ' /*AS OF TIMESTAMP to_timestamp( ' ||
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        ':pOrdDate1' || ',''yyyy-mm-dd hh24:mi:ss'')*/
	          || ' ooha,' || ' oe_transaction_types_all ' || /*AS OF TIMESTAMP to_timestamp( ' ||
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        ':pOrdDate2' || ',''yyyy-mm-dd hh24:mi:ss'')*/
	          ' otta,' || ' oe_order_sources ' || /*AS OF TIMESTAMP to_timestamp( ' ||
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        ':pOrdDate3' || ',''yyyy-mm-dd hh24:mi:ss'') */
	          ' oos,' || ' ra_terms_tl ' /*AS OF TIMESTAMP to_timestamp( ' || ':pOrdDate4' || -- CHG0034837
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               ',''yyyy-mm-dd hh24:mi:ss'')*/
	          || ' term ' ||
	          ' WHERE ooha.order_type_id = otta.transaction_type_id AND otta.attribute15 = ''Y'' ' || -- CHG0042626 removed where condition portion - ooha.creation_date<=:pCreation_date
	          ' AND ooha.payment_term_id = term.term_id(+) AND term.LANGUAGE(+) = userenv(''LANG'') ' ||
	          ' AND ooha.order_source_id = oos.order_source_id';
  
    --    IF p_cust_account_id IS NOT NULL THEN -- Commented as per Yuval's review comments on 1-Nov-2015
    -- CHG0045755 - CTASK0042105 - start changes for contact based order history preference handling
    IF l_contact_order_hist_pref = 'View Account Orders' THEN
      l_cond_str := l_cond_str || ' AND ooha.sold_to_org_id = ' ||
	        p_cust_account_id;
    ELSE
      l_cond_str := l_cond_str || ' AND ooha.sold_to_contact_id = ' ||
	        p_logged_contact_id;
      l_cond_str := l_cond_str || ' AND ooha.sold_to_org_id = ' ||
	        p_cust_account_id;
    END IF;
    -- CHG0045755 - CTASK0042105 - end
  
    --    END IF;
    l_cond_str := l_cond_str || ' AND ooha.org_id = :pOrgId';
  
    IF p_order_header_id IS NOT NULL THEN
      l_cond_str := l_cond_str || ' AND ooha.header_id = ' ||
	        p_order_header_id;
    END IF;
  
    IF p_from_date IS NOT NULL AND p_to_date IS NOT NULL THEN
      /*      l_cond_str := l_cond_str || ' AND ooha.ordered_date BETWEEN TO_DATE(''' ||
      p_from_date || ''')' || ' AND TO_DATE(''' || p_to_date || ''')';*/
    
      -- YUVAL
      /* l_from_date := to_date(p_from_date || ' 12:00:01 AM',
                             'DD-MON-YY HH:MI:SS AM');
      l_to_date   := to_date(p_to_date || ' 11:59:59 PM',
                             'DD-MON-YY HH:MI:SS AM');*/ --CHG0034837
      l_cond_str := l_cond_str ||
	        ' AND ooha.ordered_date BETWEEN TO_DATE(''' ||
	        p_from_date || ' 12:00:01 AM''' ||
	        ',''dd-MON-yy hh:mi:ss AM''' || ')' ||
	        ' AND TO_DATE(''' || p_to_date || ' 11:59:59 PM''' ||
	        ',''dd-MON-yy hh:mi:ss AM''' || ')';
    END IF;
  
    IF p_days_to_fetch IS NOT NULL THEN
      l_cond_str := l_cond_str ||
	        ' AND ooha.ordered_date BETWEEN (SYSDATE - :pdays) AND trunc(SYSDATE+1) ';
    END IF;
  
    IF p_order_number IS NOT NULL THEN
      l_cond_str := l_cond_str || ' AND ooha.order_number = ' ||
	        p_order_number;
    END IF;
  
    --CHG0042550 Start Handle unified search string
    IF p_unified_search_str IS NOT NULL THEN
      l_cond_str := l_cond_str ||
	        ' AND upper(ooha.order_number||chr(13)||xxom_order_history_pkg.get_cust_namefor_siteuse(ooha.ship_to_org_id)||chr(13)||regexp_replace(ooha.cust_po_number , ''[[:cntrl:]]'', '''')) LIKE ''%' ||
	        upper(REPLACE(TRIM(p_unified_search_str), ' ', '%')) ||
	        '%''';
      /*l_cond_str := l_cond_str||' AND (ooha.order_number LIKE ''%'||upper(replace(trim(p_unified_search_str),' ','%'))||'%'''||
                 'OR upper(xxom_order_history_pkg.get_cust_namefor_siteuse(ooha.ship_to_org_id)) LIKE ''%'||upper(replace(trim(p_unified_search_str),' ','%'))||'%'''||
                 'OR upper(regexp_replace(ooha.cust_po_number , ''[[:cntrl:]]'', '''')) LIKE ''%'||upper(replace(trim(p_unified_search_str),' ','%'))||'%'')';
      */
    END IF;
    --CHG0042550 end
  
    /*    l_cond_str := l_cond_str || ' ) where (chanel_org = ''eCommerce Order'' OR (chanel_org <> ''eCommerce Order'' AND
    status <> ''CANCELLED''))';*/
    l_cond_str := l_cond_str || ' ) where (chanel_org = :pOrderSource OR (chanel_org <> :pOrderSource AND
   status <> ''CANCELLED''))';
  
    IF p_order_by IS NOT NULL THEN
      -- l_select := p_order_by;
      /*      l_select:= decode(p_order_by,
                    'ORDERNUMBERASC',
                    'ORDERNUMBER ASC',
                    'ORDERNUMBERDESC',
                    'ORDERNUMBER DESC',
                    'STATUSDESC',
                    'STATUS DESC',
                    'STATUSASC',
                    'STATUS ASC',
                    'CHANNELDESC',
                    'CHANNEL DESC',
                    'CHANNELASC',
                    'CHANNEL ASC',
                    'ORDERDATEDESC',
                    'ORDERDATE DESC',
                    'ORDERDATEASC',
                    'ORDERDATE ASC') sory_by
      INTO   l_select
      FROM dual;*/
      l_cond_str := l_cond_str || ' ORDER BY ' ||
	        REPLACE(REPLACE(p_order_by, 'ASC', ' ASC'),
		    'DESC',
		    ' DESC') /*l_select*/
       ;
    ELSE
      l_cond_str := l_cond_str || ' ORDER BY orderdate desc';
    END IF;
  
    l_header_str_2 := ') i WHERE  rownum <= :pendindex ) i WHERE  rn >= :pstartindex ) i, oe_order_headers_all t WHERE  i.a_rowid = t.ROWID ORDER  BY rn';
  
    l_header_str := l_header_str_1 || l_cond_str || l_header_str_2;
  
    --dbms_output.put_line(l_header_str);
    OPEN cur_header_info FOR l_header_str
      USING /*l_ordereddate_db,*/ --CHG0042626 COmmented /*l_ordered_date, l_ordered_date, l_ordered_date  , l_ordered_date*/ --CHG0034837
    /*p_cust_account_id, */
    p_org_id, p_days_to_fetch, p_order_source, p_order_source, p_end_index, p_start_index; -- CHG0045755 - CTASK0042105 remove bind string for p_cust_account_id
    LOOP
      FETCH cur_header_info
        INTO l_header_data;
      l_ship_address     := NULL;
      l_bill_address     := NULL;
      l_ship_contact     := NULL;
      l_bill_contact     := NULL;
      l_sold_contact     := NULL;
      l_technology       := NULL;
      l_delivery_status  := NULL;
      l_shipping_method  := NULL;
      l_total_tax        := NULL;
      l_order_total      := NULL;
      l_freight_handling := NULL;
      l_order_sub_total  := NULL;
    
      EXIT WHEN cur_header_info%NOTFOUND;
    
      -- Fetching technologies of line item
      BEGIN
        l_technology := get_item_technology(l_header_data.header_id);
      EXCEPTION
        WHEN no_data_found THEN
          l_technology := NULL;
        WHEN OTHERS THEN
          l_status         := 'E';
          l_status_message := l_status_message || chr(13) ||
		      'ERROR: While fetching Printing Technology. ' ||
		      SQLERRM;
          EXIT;
      END;
    
      -- Fetching Delivery Status for provided header_id
      BEGIN
        l_delivery_status := get_delivery_status(l_header_data.header_id);
      EXCEPTION
        WHEN no_data_found THEN
          l_delivery_status := NULL;
        WHEN OTHERS THEN
          l_status         := 'E';
          l_status_message := l_status_message || chr(13) ||
		      'ERROR: While fetching Delivery Status. ' ||
		      SQLERRM;
          EXIT;
      END;
    
      -- Fetching Shipping Address for provided ship_to_org_id
      BEGIN
        l_ship_address := get_ship_address(l_header_data.ship_to_org_id);
      EXCEPTION
        WHEN no_data_found THEN
          l_ship_address := NULL;
        WHEN OTHERS THEN
          l_status         := 'E';
          l_status_message := l_status_message || chr(13) ||
		      'ERROR: While fetching Shipping address. ' ||
		      SQLERRM;
          EXIT;
      END;
    
      -- Fetching Billing Address for provided invoice_to_org_id
      BEGIN
        l_bill_address := get_bill_address(l_header_data.invoice_to_org_id);
      EXCEPTION
        WHEN no_data_found THEN
          l_bill_address := NULL;
        WHEN OTHERS THEN
          l_status         := 'E';
          l_status_message := l_status_message || chr(13) ||
		      'ERROR: While fetching Billing address. ' ||
		      SQLERRM;
          EXIT;
      END;
    
      -- Fetching Shipping Contact name for provided ship_to_contact_id
      BEGIN
        l_ship_contact := get_ship_contact(l_header_data.ship_to_contact_id);
      EXCEPTION
        WHEN no_data_found THEN
          l_ship_contact := NULL;
        WHEN OTHERS THEN
          l_status         := 'E';
          l_status_message := l_status_message || chr(13) ||
		      'ERROR: While fetching Ship to contact. ' ||
		      SQLERRM;
          EXIT;
      END;
    
      -- Fetching Billing Contact name for provided invoice_to_contact_id
      BEGIN
        l_bill_contact := get_bill_contact(l_header_data.invoice_to_contact_id);
      EXCEPTION
        WHEN no_data_found THEN
          l_bill_contact := NULL;
        WHEN OTHERS THEN
          l_status         := 'E';
          l_status_message := l_status_message || chr(13) ||
		      'ERROR: While fetching Bill to contact. ' ||
		      SQLERRM;
          EXIT;
      END;
    
      -- Fetching Cutomer contact name for provided sold_to_contact_id
      BEGIN
        l_sold_contact := get_sold_contact(l_header_data.sold_to_contact_id);
      EXCEPTION
        WHEN no_data_found THEN
          l_sold_contact := NULL;
        WHEN OTHERS THEN
          l_status         := 'E';
          l_status_message := l_status_message || chr(13) ||
		      'ERROR: While fetching sold to contact. ' ||
		      SQLERRM;
          EXIT;
      END;
    
      -- Calculating Order sub total for provided header_id
      BEGIN
        l_order_sub_total := get_order_subtotal(l_header_data.header_id);
      EXCEPTION
        WHEN no_data_found THEN
          l_order_sub_total := NULL;
        WHEN OTHERS THEN
          l_status         := 'E';
          l_status_message := l_status_message || chr(13) ||
		      'ERROR: While calculating Order Subtotal. ' ||
		      SQLERRM;
          EXIT;
      END;
    
      -- Calculating freight handling for provided header_id
      BEGIN
        l_freight_handling := get_freight_handling(l_header_data.header_id);
      EXCEPTION
        WHEN no_data_found THEN
          l_freight_handling := NULL;
        WHEN OTHERS THEN
          l_status         := 'E';
          l_status_message := l_status_message || chr(13) ||
		      'ERROR: While calculating freight handling. ' ||
		      SQLERRM;
          EXIT;
      END;
    
      -- Fetching shipping method for provided shipping_method_code
      BEGIN
        l_shipping_method := get_shipping_method(l_header_data.shipping_method);
      EXCEPTION
        WHEN no_data_found THEN
          l_shipping_method := NULL;
        WHEN OTHERS THEN
          l_status         := 'E';
          l_status_message := l_status_message || chr(13) ||
		      'ERROR: While fetching shipping method. ' ||
		      SQLERRM;
          EXIT;
      END;
    
      IF l_status <> 'E' THEN
        BEGIN
          -- Calculating total tax for provided header_id
          l_total_tax := oe_totals_grp.get_order_total(l_header_data.header_id,
				       NULL,
				       'TAXES');
        
          -- Calculating Order Total for provided header_id
          l_order_total := oe_totals_grp.get_order_total(l_header_data.header_id,
				         NULL,
				         'ALL');
        
          l_header_tab.extend();
          l_header_tab(l_header_count) := xxom_ord_hist_header_rec_type(NULL,
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
						NULL);
          l_header_tab(l_header_count).header_id := l_header_data.header_id;
          l_header_tab(l_header_count).order_number := l_header_data.ordernumber;
          l_header_tab(l_header_count).ordered_date := l_header_data.orderdate;
          l_header_tab(l_header_count).formatted_order_date := l_header_data.formatted_order_date;
          l_header_tab(l_header_count).cust_po_number := l_header_data.cust_po_number;
          l_header_tab(l_header_count).ship_to_org_id := l_header_data.ship_to_org_id;
          l_header_tab(l_header_count).invoice_to_org_id := l_header_data.invoice_to_org_id;
          l_header_tab(l_header_count).sold_to_contact_id := l_header_data.sold_to_contact_id;
          l_header_tab(l_header_count).ship_to_contact_id := l_header_data.ship_to_contact_id;
          l_header_tab(l_header_count).invoice_to_contact_id := l_header_data.invoice_to_contact_id;
          l_header_tab(l_header_count).bill_address := l_bill_address;
          l_header_tab(l_header_count).ship_address := l_ship_address;
          l_header_tab(l_header_count).bill_contact := l_bill_contact;
          l_header_tab(l_header_count).sold_contact := l_sold_contact;
          l_header_tab(l_header_count).ship_contact := l_ship_contact;
          l_header_tab(l_header_count).payment_terms := l_header_data.payment_terms;
          l_header_tab(l_header_count).chanel := l_header_data.channel;
          l_header_tab(l_header_count).status := l_header_data.status;
          l_header_tab(l_header_count).order_sub_total := l_order_sub_total;
          l_header_tab(l_header_count).freight_handling := l_freight_handling;
          l_header_tab(l_header_count).total_tax := l_total_tax;
          l_header_tab(l_header_count).order_total := l_order_total;
          l_header_tab(l_header_count).currency_code := l_header_data.currency_code;
          l_header_tab(l_header_count).shipping_method := l_shipping_method;
          l_header_tab(l_header_count).printing_technology := l_technology;
          l_header_tab(l_header_count).delivery_status := l_delivery_status;
          l_header_count := l_header_count + 1;
        
          IF p_operation = 'LINE' THEN
	FOR cur_line_rec IN cur_line(l_header_data.header_id)
	LOOP
	  l_line_tab.extend();
	  l_line_tab(l_line_count) := xxom_ord_hist_line_rec_type(NULL,
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
	  l_line_tab(l_line_count).order_header_id := cur_line_rec.header_id;
	  l_line_tab(l_line_count).order_line_id := cur_line_rec.line_id;
	  l_line_tab(l_line_count).order_date := cur_line_rec.ordered_date;
	  l_line_tab(l_line_count).item_number := cur_line_rec.ordered_item;
	  l_line_tab(l_line_count).item_description := cur_line_rec.item_description;
	  l_line_tab(l_line_count).item_id := cur_line_rec.item_id;
	  l_line_tab(l_line_count).item_technology := cur_line_rec.item_technology;
	  l_line_tab(l_line_count).ordered_quantity := cur_line_rec.ordered_quantity;
	  l_line_tab(l_line_count).unit_selling_price := cur_line_rec.unit_selling_price;
	  l_line_tab(l_line_count).extended_price := cur_line_rec.extended_price;
	  l_line_tab(l_line_count).tax := cur_line_rec.tax_value;
	  l_line_tab(l_line_count).status := cur_line_rec.status;
	  l_line_count := l_line_count + 1;
	END LOOP;
          
	FOR cur_ship_rec IN cur_ship(l_header_data.header_id)
	LOOP
	  l_shipment_tab.extend();
	  l_shipment_tab(l_ship_count) := xxom_ord_hist_ship_rec_type(NULL,
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
	  l_shipment_tab(l_ship_count).ship_line_id := cur_ship_rec.ship_line_id;
	  l_shipment_tab(l_ship_count).ship_id := cur_ship_rec.ship_id;
	  l_shipment_tab(l_ship_count).order_date := cur_ship_rec.ordered_date;
	  l_shipment_tab(l_ship_count).ship_date := cur_ship_rec.ship_date;
	  l_shipment_tab(l_ship_count).freight_carrier := cur_ship_rec.freight_carrier;
	  l_shipment_tab(l_ship_count).shipping_method := cur_ship_rec.shipping_method;
	  l_shipment_tab(l_ship_count).tracking_number := cur_ship_rec.tracking_number;
	  l_shipment_tab(l_ship_count).shipped_quantity := cur_ship_rec.shipped_qty;
	  l_ship_count := l_ship_count + 1;
	END LOOP;
          END IF;
        EXCEPTION
          WHEN OTHERS THEN
	l_status         := 'E';
	l_status_message := l_status_message || chr(10) || chr(13) ||
		        'Order Number: ' ||
		        l_header_data.ordernumber || chr(10) ||
		        'ERROR: Unexpected Error ' || SQLERRM;
	EXIT;
        END;
      END IF;
    END LOOP;
  
    --dbms_output.put_line('HERE: '||p_start_index||' '||p_operation||' '||l_status||' '||l_ordereddate_db);
  
    -- Fetch Total order header count
    IF p_start_index = 1 AND p_operation = 'HEADER' AND l_status <> 'E' THEN
      SELECT COUNT(1)
      INTO   x_order_count
      -- CHG0034837 rem to_timestamp
      FROM   oe_order_headers_all /* AS OF TIMESTAMP to_timestamp(l_ordered_date, 'yyyy-mm-dd hh24:mi:ss'    ) */     ooha,
	 oe_transaction_types_all /*AS OF TIMESTAMP to_timestamp(l_ordered_date, 'yyyy-mm-dd hh24:mi:ss')*/ otta,
	 oe_order_sources /* AS OF TIMESTAMP to_timestamp(l_ordered_date, 'yyyy-mm-dd hh24:mi:ss' ) */         oos
      WHERE  ooha.order_type_id = otta.transaction_type_id
      AND    otta.attribute15 = 'Y'
      AND    ooha.order_source_id = oos.order_source_id
      AND    ooha.order_number = nvl(p_order_number, ooha.order_number)
	-- CHG0042550 start
      AND    ((p_unified_search_str IS NOT NULL AND
	upper(ooha.order_number || chr(13) ||
	         xxom_order_history_pkg.get_cust_namefor_siteuse(ooha.ship_to_org_id) ||
	         chr(13) || regexp_replace(ooha.cust_po_number,
			           '[[:cntrl:]]',
			           ' ')) LIKE
	'%' || upper(REPLACE(TRIM(p_unified_search_str), ' ', '%')) || '%') OR
	p_unified_search_str IS NULL)
	-- CHG0042550 end
	/*      AND    ooha.ordered_date BETWEEN nvl(p_from_date, SYSDATE - p_days_to_fetch) AND
            nvl(p_to_date, SYSDATE)*/
      AND    ooha.ordered_date BETWEEN
	 nvl(l_from_date, SYSDATE - p_days_to_fetch) AND
	 nvl(l_to_date, SYSDATE)
      AND    ooha.header_id = nvl(p_order_header_id, ooha.header_id)
      AND    ooha.sold_to_org_id = p_cust_account_id
      AND    ooha.org_id = p_org_id
	/*      AND    (oos.NAME = 'eCommerce Order' OR (nvl(oos.NAME, '-1') <> 'eCommerce Order' AND
            ooha.flow_status_code <> 'CANCELLED'));*/
      AND    (oos.name = p_order_source OR
	(nvl(oos.name, '-1') <> p_order_source AND
	ooha.flow_status_code <> 'CANCELLED'))
	-- CHG0045755 - CTASK0042105 start
      AND    ((l_contact_order_hist_pref = 'View Account Orders' AND
	ooha.sold_to_org_id = p_cust_account_id) OR
	(l_contact_order_hist_pref <> 'View Account Orders' AND
	ooha.sold_to_contact_id = p_logged_contact_id AND
	ooha.sold_to_org_id = p_cust_account_id));
      -- CHG0045755 - CTASK0042105 - end;
      --AND    trunc(ooha.creation_date) <= l_ordereddate_db; -- CHG0034837 -- CHG0042626 commented
    END IF;
  
    IF l_status_message IS NOT NULL AND p_operation = 'HEADER' THEN
      l_mail_entity := 'Failed for below Inputs : ' || chr(13) || chr(10) ||
	           'Customer Account ID: ' || p_cust_account_id ||
	           chr(13) || chr(10) || 'Error Message: ' ||
	           l_status_message || chr(10) || chr(10);
    ELSIF l_status_message IS NOT NULL AND p_operation = 'LINE' THEN
      l_mail_entity := 'Failed records : ' || chr(13) || chr(10) ||
	           'Header ID: ' || p_order_header_id || chr(13) ||
	           chr(10) || 'Error Message: ' || l_status_message ||
	           chr(10) || chr(10);
    END IF;
  
    IF l_mail_entity IS NOT NULL THEN
      l_mail_entity := l_mail_entity || 'Thank you,' || chr(13) || chr(10);
      l_mail_entity := l_mail_entity || 'Stratasys eCommerce team' ||
	           chr(13) || chr(13) || chr(10) || chr(10);
      l_mail_body   := 'Hi,' || chr(10) || chr(10) ||
	           'The following unexpected exception occurred for Sales Order History Interface API.' ||
	           chr(13) || chr(10);
      l_mail_body   := l_mail_body || l_mail_entity;
      send_mail('XXOM_ORDER_HISTORY_PKG_TO',
	    'XXOM_ORDER_HISTORY_PKG_CC',
	    l_mail_body);
    ELSE
      x_order_headers   := l_header_tab;
      x_order_lines     := l_line_tab;
      x_order_shipments := l_shipment_tab;
    END IF;
  
    x_status         := l_status;
    x_status_message := l_status_message;
  EXCEPTION
    WHEN e_ord_history_exception THEN
      x_status         := 'E';
      x_status_message := l_status_message;
      l_mail_body      := 'Hi,' || chr(10) || chr(10) ||
		  'The following exception occurred for Sales Order History Interface API.' ||
		  chr(13) || chr(10);
      l_mail_body      := l_mail_body || '  Error Message: ' ||
		  x_status_message || chr(13) || chr(13) || chr(10) ||
		  chr(10);
      l_mail_body      := l_mail_body || 'Thank you,' || chr(13) || chr(10);
      l_mail_body      := l_mail_body || 'Stratasys eCommerce team' ||
		  chr(13) || chr(13) || chr(10) || chr(10);
      send_mail('XXOM_ORDER_HISTORY_PKG_TO',
	    'XXOM_ORDER_HISTORY_PKG_CC',
	    l_mail_body);
    WHEN OTHERS THEN
      x_status         := 'E';
      x_status_message := l_status_message || chr(13) || SQLERRM;
      l_mail_body      := 'Hi,' || chr(10) || chr(10) ||
		  'The following unexpected exception occurred for Sales Order History Interface API.' ||
		  chr(13) || chr(10);
      l_mail_body      := l_mail_body || '  Error Message: ' ||
		  x_status_message || chr(13) || chr(13) || chr(10) ||
		  chr(10);
      l_mail_body      := l_mail_body || 'Thank you,' || chr(13) || chr(10);
      l_mail_body      := l_mail_body || 'Stratasys eCommerce team' ||
		  chr(13) || chr(13) || chr(10) || chr(10);
      send_mail('XXOM_ORDER_HISTORY_PKG_TO',
	    'XXOM_ORDER_HISTORY_PKG_CC',
	    l_mail_body);
  END customer_order_history;
END xxom_order_history_pkg;
/
