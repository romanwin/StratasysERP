CREATE OR REPLACE PACKAGE BODY xxom_salesorder_util AS

  --------------------------------------------------------------------

  --  name:          XXOM_SALESORDER_UTIL
  --  created by:    Debarati Banerjee
  --  Revision       1.0
  --  creation date: 20/03/2015
  --------------------------------------------------------------------
  --  purpose :      CHG0034837: Sales Order interface between Hybris
  --                 and Oracle Apps to handle order creation
  --------------------------------------------------------------------------------------------------------------------
  --  ver  date          name                 desc
  --  1.0  20/03/2015    debarati banerjee    Initial Build - CHG0034837
  --  1.1  17/06/2015    debarati banerjee    CHG0035717 - Used profile option in create_order procedure for debug log file location
  --  1.2  15/07/2015    debarati banerjee    CHG0035705 - Added logic to populated ack email and ship email in additional header info DFF
  --  1.3  26/10/2015    debarati banerjee    CHG0036623 - Added logic to determine order status based on order state specified in
  --                                          XXOM_SF2OA_Order_Types_Mapping value set and include the partial shipment functionality.
  --                                          Salesperson will be populated from Defaulting Rules setup.Added logic to fetch fob code
  --                                          for EMEA orders
  --  1.4 14-Jun-2016    Lingaraj Sarangi     CHG0038756 - Adjust ecommerce create order interface to support credit card process
  --  1.5 12-OCT-2016    Lingaraj Sarangi     CHG0039481 - Adjust ecommerce create order interface to support Creditcard Token integration with eStore.
  --  1.6 27.2.17        yuval tal            CHG0040236 - modify create_order : change incoterm logic
  --  1.7 29.6.17        yuval tal            CHG0040839 - modify create order : set default value to header attribute18
  --  1.8 27-OCT-2017    Diptasurjya          CHG0041715 - Promo code change (ask for modifier). Order header pricing attribute is being populated
  --                     Chatterjee           and sent to process_order API
  --  2.0 12/04/2017     Bellona              INC0108633 - trim and remove control characters from po_number field
  --  2.1 07-JUL-2018    Diptasurjya          INC0127634 - Character conversion from cart ID
  --  2.2 08/07/2018     Diptasurjya          INC0128351 - Remove end date filter from adjustment selection
  --  3.0 01/17/2019     Diptasurjya          CHG0044725 - Make changes for calling CC authorization code in case order is created in ENTERED state
  --  3.1 04-Mar-2019    Diptasurjya          CHG0044403 - Exclude some item-carrier combination from Dangerous goods string
  --  3.2 22-May-2019    Diptasurjya          CHG0045755 - PTO model item handling
  --  3.3 09/12/2019     Diptasurjya          CHG0045128 - generate ack emails using single common function
  --  3.4 09/07/2020     yuval tal            CHG0048217 - modify validate_order,create_order add account number/ item code support/is_order_dg_eligible
  --  3.5 07/10/2020     Roman W              CHG0048217 - update_pricing_tables changed parameter p_cartid type from NUMBER to VARCHAR2
  --  1.0 14/01/2021     Roman W.             CHG0047450 - Re-Do 
  --                                             changed logic in "FUNCTION get_file_extension(p_filename IN VARCHAR2)" 
  ----------------------------------------------------------------------------------------------------------------------

  g_status          VARCHAR2(10) := 'S';
  g_status_message  VARCHAR2(4000);
  g_status_message1 VARCHAR2(4000);
  g_debug_flag      VARCHAR2(1) := 'N';
  g_debug_file_name VARCHAR2(2000);
  g_language        VARCHAR2(240) := userenv('LANG');

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0044725
  --          This Procedure is used to send Mail for errors and is called in autonomous transaction mode
  --          This will allow it to be called from business event rule functions exception block,
  --          and not cause the BE system to throw error due to commit being performed with the send_mail procedure
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  01/17/2019  Diptasurjya Chatterjee        Initial Build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE send_mail_autonomous(pa_org_id NUMBER,
		         pa_body   IN VARCHAR2) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  
    l_err_code NUMBER;
    l_error    VARCHAR2(4000);
  BEGIN
    xxobjt_wf_mail.send_mail_text(p_to_role     => xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => pa_org_id,
							           p_program_short_name => 'XX_ECOM_SALESORDER_API_TO'),
		          p_cc_mail     => xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => pa_org_id,
							           p_program_short_name => 'XX_ECOM_SALESORDER_API_CC'),
		          p_subject     => 'eStore unexpected error in Oracle while processing order import',
		          p_body_text   => pa_body,
		          p_err_code    => l_err_code,
		          p_err_message => l_error);
    IF l_err_code = 1 THEN
      oe_debug_pub.add('SSYS CUSTOM: Mailer error : ' || l_error);
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      oe_debug_pub.add('SSYS CUSTOM: Mailer error : ' || SQLERRM);
  END send_mail_autonomous;

  --------------------------------------------------------------------

  --  name:          get_user_details
  --  created by:    Debarati Banerjee
  --  Revision       1.0
  --  creation date: 20/03/2015
  ----------------------------------------------------------------------
  --  purpose :      CHG0034837: Set user,responsibility and application
  ----------------------------------------------------------------------

  PROCEDURE get_user_details(p_username IN VARCHAR2,
		     l_user     OUT NUMBER,
		     --l_resp           OUT NUMBER,
		     l_appl           OUT NUMBER,
		     g_status         OUT VARCHAR2,
		     g_status_message OUT VARCHAR2) IS
  
  BEGIN
    g_status := 'S';
    SELECT DISTINCT t1.user_id,
	        responsibility_application_id
    INTO   l_user,
           l_appl
    FROM   fnd_user_resp_groups t1,
           fnd_user             t2
    WHERE  t1.user_id = t2.user_id
    AND    t2.user_name = p_username
    AND    SYSDATE BETWEEN nvl(t1.start_date, trunc(SYSDATE)) AND
           nvl(t1.end_date, SYSDATE)
    AND    rownum = 1;
  
  EXCEPTION
    WHEN no_data_found THEN
      g_status         := 'E100';
      g_status_message := g_status_message || chr(13) || 'ERROR: User:' ||
		  p_username || ' is not valid';
    WHEN OTHERS THEN
      g_status         := 'E101';
      g_status_message := g_status_message || chr(13) ||
		  'ERROR: While fetching user details' || SQLERRM;
  END get_user_details;

  --------------------------------------------------------------------

  --  name:          get_order_type_details
  --  created by:    Debarati Banerjee
  --  Revision       1.0
  --  creation date: 20/03/2015
  ----------------------------------------------------------------------
  --  purpose :      CHG0034837: Set order type id and lines type id
  --  ver  date          name                 desc
  --  1.3  26/10/2015    debarati banerjee    CHG0036623 - Added logic to
  --                                          determine order status based
  --                                          on order state specified in
  --                                          XXOM_SF2OA_Order_Types_Mapping
  --                                          value set.
  ----------------------------------------------------------------------

  PROCEDURE get_order_type_details(p_org_id           IN NUMBER,
		           p_operation        IN NUMBER,
		           l_order_type_id    OUT NUMBER,
		           l_pos_line_type_id OUT NUMBER,
		           l_neg_line_type_id OUT NUMBER,
		           l_resp_id          OUT NUMBER,
		           l_order_state      OUT VARCHAR2,
		           g_status           OUT VARCHAR2,
		           g_status_message   OUT VARCHAR2) IS
  BEGIN
  
    g_status := 'S';
  
    SELECT attribute3 order_type_id,
           attribute4 pos_line_type_id,
           nvl(attribute5, attribute4) neg_line_type_id,
           attribute6 resp_id,
           nvl(attribute7, 'ENTERED') order_status
    INTO   l_order_type_id,
           l_pos_line_type_id,
           l_neg_line_type_id,
           l_resp_id,
           l_order_state
    FROM   fnd_flex_values_vl  p,
           fnd_flex_value_sets vs
    WHERE  p.flex_value_set_id = vs.flex_value_set_id
    AND    vs.flex_value_set_name = 'XXOM_SF2OA_Order_Types_Mapping'
    AND    attribute1 = p_operation
    AND    attribute2 = p_org_id;
  
  EXCEPTION
    WHEN no_data_found THEN
      g_status         := 'E100';
      g_status_message := g_status_message || chr(13) ||
		  'ERROR: Transaction type could not be fetched for ORG ID:' ||
		  p_org_id || ' and Operation No:' || p_operation;
    WHEN OTHERS THEN
      g_status         := 'E101';
      g_status_message := g_status_message || chr(13) ||
		  'ERROR: While fetching Transaction Type ID.' ||
		  SQLERRM;
  END get_order_type_details;

  --------------------------------------------------------------------

  --  name:          get_order_type_name
  --  created by:    Debarati Banerjee
  --  Revision       1.0
  --  creation date: 20/03/2015
  ----------------------------------------------------------------------
  --  purpose :      CHG0034837: Set order type name
  ----------------------------------------------------------------------

  FUNCTION get_order_type_name(p_order_type_id oe_transaction_types_tl.transaction_type_id%TYPE)
    RETURN VARCHAR2 IS
    l_order_type_name oe_transaction_types_tl.name%TYPE;
  
  BEGIN
  
    g_status := 'S';
  
    SELECT t.name
    INTO   l_order_type_name
    FROM   oe_transaction_types_tl t
    WHERE  t.transaction_type_id = p_order_type_id
    AND    t.language = 'US';
    RETURN l_order_type_name;
  END;

  --------------------------------------------------------------------

  --  name:          get_source_id
  --  created by:    Debarati Banerjee
  --  Revision       1.0
  --  creation date: 20/03/2015
  ----------------------------------------------------------------------
  --  purpose :      CHG0034837: Set Order Source
  ----------------------------------------------------------------------

  FUNCTION get_source_id(p_source_name oe_order_sources.name%TYPE)
    RETURN NUMBER IS
  
    l_order_source_id oe_order_sources.order_source_id%TYPE;
  
  BEGIN
  
    SELECT o.order_source_id
    INTO   l_order_source_id
    FROM   oe_order_sources o
    WHERE  o.name = p_source_name;
  
    RETURN l_order_source_id;
  END;

  --------------------------------------------------------------------

  --  name:          get_lookup_meaning
  --  created by:    Debarati Banerjee
  --  Revision       1.0
  --  creation date: 20/03/2015
  ----------------------------------------------------------------------
  --  purpose :      CHG0034837: Check Lookups
  ----------------------------------------------------------------------

  FUNCTION get_lookup_meaning(p_lookup_type VARCHAR2,
		      p_lookup_code VARCHAR2) RETURN VARCHAR2 IS
  
    l_meaning fnd_lookup_values.meaning%TYPE;
  BEGIN
  
    SELECT meaning
    INTO   l_meaning
    FROM   fnd_lookup_values flv
    WHERE  flv.lookup_type = p_lookup_type
    AND    flv.lookup_code = p_lookup_code
    AND    flv.language = userenv('LANG');
  
    RETURN l_meaning;
  
  END;
  --------------------------------------------------------------------

  --  name:          get_line_type_id
  --  created by:    Debarati Banerjee
  --  Revision       1.0
  --  creation date: 20/03/2015
  ----------------------------------------------------------------------
  --  purpose :      CHG0034837: Set order line type id
  ----------------------------------------------------------------------

  FUNCTION get_line_type_id(p_ordered_quantity NUMBER,
		    p_pos_line_type_id NUMBER,
		    p_neg_line_type_id NUMBER) RETURN NUMBER IS
    l_line_type_id NUMBER;
  
  BEGIN
  
    SELECT decode(sign(p_ordered_quantity),
	      -1,
	      p_neg_line_type_id,
	      p_pos_line_type_id)
    INTO   l_line_type_id
    FROM   dual;
  
    RETURN l_line_type_id;
  END;

  --------------------------------------------------------------------

  --  name:          get_inv_item_id
  --  created by:    Debarati Banerjee
  --  Revision       1.0
  --  creation date: 20/03/2015
  ----------------------------------------------------------------------
  --  purpose :      CHG0034837: Set inventory_item_id
  ----------------------------------------------------------------------

  FUNCTION get_inv_item_id(p_ordered_item mtl_system_items.segment1%TYPE)
    RETURN NUMBER IS
  
    l_inventory_item_id mtl_system_items.inventory_item_id%TYPE := -999;
  
  BEGIN
  
    SELECT msib.inventory_item_id
    INTO   l_inventory_item_id
    FROM   mtl_system_items_b msib
    WHERE  msib.segment1 = p_ordered_item
    AND    rownum = 1;
  
    RETURN l_inventory_item_id;
  
  END;

  --------------------------------------------------------------------

  --  name:          check_customer_account
  --  created by:    Debarati Banerjee
  --  Revision       1.0
  --  creation date: 20/03/2015
  ----------------------------------------------------------------------
  --  purpose :      CHG0034837: This function checks if Customer Account
  --                 ID is valid
  --  ver  date          name                 desc
  -- 1.3   9/7/2020      yuval tal            CHG0048217 - add account number support
  ----------------------------------------------------------------------

  FUNCTION check_customer_account(p_cust_account_id IN NUMBER,
		          p_account_number  VARCHAR2) RETURN NUMBER IS
    l_exists NUMBER := 0;
  BEGIN
    BEGIN
      SELECT cust_account_id
      INTO   l_exists
      FROM   hz_cust_accounts hca
      WHERE  hca.account_number = p_account_number
      AND    hca.status = 'A';
    
      RETURN l_exists;
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;
  
    SELECT cust_account_id
    INTO   l_exists
    FROM   hz_cust_accounts hca
    WHERE  hca.cust_account_id = p_cust_account_id
    AND    hca.status = 'A';
  
    RETURN l_exists;
  END;

  --------------------------------------------------------------------

  --  name:          check_bill_to_site
  --  created by:    Debarati Banerjee
  --  Revision       1.0
  --  creation date: 20/03/2015
  ----------------------------------------------------------------------
  --  purpose :      CHG0034837: This function checks if Bill-to-Site ID
  --                 is valid
  ----------------------------------------------------------------------

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

  --------------------------------------------------------------------

  --  name:          check_ship_to_site
  --  created by:    Debarati Banerjee
  --  Revision       1.0
  --  creation date: 20/03/2015
  ----------------------------------------------------------------------
  --  purpose :      CHG0034837: This function checks if Ship-to-Site ID
  --                 is valid
  ----------------------------------------------------------------------

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

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0044403 - This function checks SO is having any DG items in it
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  03/04/2019  Diptasurjya Chatterjee (TCS)    CHG0044403 - Initial Build
  -- 1.2  09/07/2020     yuval tal                    CHG0048217  - support item_code
  -- --------------------------------------------------------------------------------------------
  FUNCTION is_order_dg_eligible(p_line_tab        xxecom.xxom_order_line_tab_type,
		        p_shipping_method VARCHAR2) RETURN VARCHAR2 IS
    l_is_dg_order VARCHAR2(1);
  BEGIN
  
    -- support item code
  
    SELECT 'Y'
    INTO   l_is_dg_order
    FROM   TABLE(CAST(p_line_tab AS xxom_order_line_tab_type)) t
    WHERE  xxinv_utils_pkg.is_item_hazard_restricted(nvl(t.inventory_item_id,
				         xxinv_utils_pkg.get_item_id(t.item_code))) = 'Y' --CHG0048217
    AND    NOT EXISTS
     (SELECT 1
	FROM   wsh_carrier_services wcs,
	       fnd_flex_values      ffv,
	       fnd_flex_value_sets  ffvs,
	       mtl_system_items_b   msib
	WHERE  wcs.ship_method_code = p_shipping_method
	AND    ffvs.flex_value_set_name = 'XXOM_DG_SHIP_INSTR_EXCLUSION'
	AND    ffvs.flex_value_set_id = ffv.flex_value_set_id
	AND    ffv.attribute1 = wcs.mode_of_transport
	AND    ffv.enabled_flag = 'Y'
	AND    trunc(SYSDATE) BETWEEN
	       nvl(trunc(ffv.start_date_active), SYSDATE - 1) AND
	       nvl(trunc(ffv.end_date_active), SYSDATE + 1)
	AND    msib.inventory_item_id = t.inventory_item_id
	AND    msib.organization_id =
	       xxinv_utils_pkg.get_master_organization_id
	AND    ffv.flex_value = msib.segment1)
    AND    rownum = 1;
  
    RETURN l_is_dg_order;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN 'N';
  END is_order_dg_eligible;

  --------------------------------------------------------------------

  --  name:          fetch_item_name
  --  created by:    Debarati Banerjee
  --  Revision       1.0
  --  creation date: 20/03/2015
  ----------------------------------------------------------------------
  --  purpose :      CHG0034837: This function fetches Item Name from
  --                 Item ID

  --  ver  date          name                      desc
  ------------------------------------------------------------------------------
  --  1.1  9/7/2020      yuval tal                 CHG0048217 - support item_code
  ----------------------------------------------------------------------

  FUNCTION fetch_item_name(p_item_id   IN NUMBER,
		   p_item_code VARCHAR2) RETURN VARCHAR2 IS
    l_item_name     VARCHAR2(30);
    l_master_org_id NUMBER;
  BEGIN
    l_master_org_id := xxinv_utils_pkg.get_master_organization_id();
  
    BEGIN
      --CHG0048217
      SELECT segment1
      INTO   l_item_name
      FROM   mtl_system_items_b
      WHERE  organization_id = l_master_org_id
      AND    segment1 = p_item_code;
    
      RETURN l_item_name;
    EXCEPTION
      WHEN no_data_found THEN
        NULL;
    END;
    --CHG0048217
    SELECT segment1
    INTO   l_item_name
    FROM   mtl_system_items_b
    WHERE  organization_id = l_master_org_id
    AND    inventory_item_id = p_item_id;
  
    RETURN l_item_name;
  END;

  ---------------------------------------------------------------------------

  --  name:          fetch_fob_code
  --  created by:    Debarati Banerjee
  --  Revision       1.0
  --  creation date: 16/02/2016
  ----------------------------------------------------------------------
  --  purpose :      CHG0036623: This function fetches FOB point code
  --
  ----------------------------------------------------------------------
  FUNCTION fetch_fob_code(p_lookup_type VARCHAR2,
		  p_lookup_code VARCHAR2) RETURN VARCHAR2 IS
  
    l_fob fnd_lookup_values.attribute6%TYPE;
  BEGIN
  
    SELECT attribute6
    INTO   l_fob
    FROM   fnd_lookup_values flv
    WHERE  flv.lookup_type = p_lookup_type
    AND    flv.lookup_code = p_lookup_code
    AND    flv.language = userenv('LANG');
  
    RETURN l_fob;
  
  END;

  --------------------------------------------------------------------

  --  name:          validate_order
  --  created by:    Debarati Banerjee
  --  Revision       1.0
  --  creation date: 20/03/2015
  ----------------------------------------------------------------------
  --  purpose :      CHG0034837: Validate order input parameters
  --  ver  date          name                 desc
  -- 1.3   9/7/2020      yuval tal            CHG0048217 - add account number support
  ----------------------------------------------------------------------

  PROCEDURE validate_order(p_header         IN xxom_order_header_rec_type,
		   p_line           IN xxom_order_line_tab_type,
		   g_status         OUT VARCHAR2,
		   g_status_message OUT VARCHAR2) IS
    l_sold_to_org_id NUMBER; -- CHG0048217
  
    l_tmp       VARCHAR2(200);
    l_exists    NUMBER := 0;
    l_item_name VARCHAR2(30);
  
  BEGIN
    g_status := 'S';
  
    IF g_debug_flag = 'Y' THEN
      oe_debug_pub.add('SSYS CUSTOM: Order header Input Received: ' ||
	           chr(13) || 'SSYS CUSTOM: Order Number  : ' ||
	           p_header.order_number || chr(13) ||
	           'SSYS CUSTOM: Org ID: ' || p_header.org_id ||
	           chr(13) || 'SSYS CUSTOM: sold_to_org_id: ' ||
	           p_header.sold_to_org_id || chr(13) ||
	           'SSYS CUSTOM: account_number: ' ||
	           p_header.account_number || chr(13) ||
	           'SSYS CUSTOM: ship_to_org_id         : ' ||
	           p_header.ship_to_org_id || chr(13) ||
	           'SSYS CUSTOM: invoice_to_org_id    : ' ||
	           p_header.invoice_to_org_id || chr(13) ||
	           'SSYS CUSTOM: ship_to_contact_id    : ' ||
	           p_header.ship_to_contact_id || chr(13) ||
	           'SSYS CUSTOM: sold_to_contact_id    : ' ||
	           p_header.sold_to_contact_id || chr(13) ||
	           'SSYS CUSTOM: invoice_to_contact_id    : ' ||
	           p_header.invoice_to_contact_id || chr(13) ||
	           'SSYS CUSTOM: ordered_date    : ' ||
	           p_header.ordered_date || chr(13) ||
	           'SSYS CUSTOM: operation    : ' ||
	           p_header.operation || chr(13) ||
	           'SSYS CUSTOM: cust_po_number    : ' ||
	           p_header.cust_po_number || chr(13) ||
	           'SSYS CUSTOM: shipping_method_code    : ' ||
	           p_header.shipping_method_code || chr(13) ||
	           'SSYS CUSTOM: freight_terms_code    : ' ||
	           p_header.freight_terms_code || chr(13) ||
	           'SSYS CUSTOM: incoterms    : ' ||
	           p_header.incoterms || chr(13) ||
	           'SSYS CUSTOM: payment_term_id    : ' ||
	           p_header.payment_term_id || chr(13) ||
	           'SSYS CUSTOM: contractNumber    : ' ||
	           p_header.contractnumber || chr(13) ||
	           'SSYS CUSTOM: freightCost    : ' ||
	           p_header.freightcost || chr(13) ||
	           'SSYS CUSTOM: Price_list_id    : ' ||
	           p_header.price_list_id || chr(13) ||
	           'SSYS CUSTOM: splitOrder    : ' ||
	           p_header.splitorder || chr(13) ||
	           'SSYS CUSTOM: comments    : ' || p_header.comments ||
	           chr(13) || 'SSYS CUSTOM: salesrep_id    : ' ||
	           p_header.salesrep_id || chr(13) ||
	           'SSYS CUSTOM: order_source_name    : ' ||
	           p_header.order_source_name);
    END IF;
  
    IF p_header.order_number IS NULL THEN
      g_status         := 'E102';
      g_status_message := g_status_message || chr(13) ||
		  'VALIDATION ERROR: Order Header: Order Number is mandatory';
    END IF;
  
    IF p_header.org_id IS NULL THEN
      g_status         := 'E102';
      g_status_message := g_status_message || chr(13) ||
		  'VALIDATION ERROR: Order Header: Org_id is mandatory';
    END IF;
  
    IF p_header.sold_to_org_id IS NULL AND p_header.account_number IS NULL THEN
      g_status         := 'E102';
      g_status_message := g_status_message || chr(13) ||
		  'VALIDATION ERROR: Order Header: Sold_to_org_id or Account_Number is mandatory';
    END IF;
  
    IF p_header.ship_to_org_id IS NULL THEN
      g_status         := 'E102';
      g_status_message := g_status_message || chr(13) ||
		  'VALIDATION ERROR: Order Header: ship_to_org_id is mandatory';
    END IF;
  
    IF p_header.invoice_to_org_id IS NULL THEN
      g_status         := 'E102';
      g_status_message := g_status_message || chr(13) ||
		  'VALIDATION ERROR: Order Header: invoice_to_org_id is mandatory';
    END IF;
  
    IF p_header.ordered_date IS NULL THEN
      g_status         := 'E102';
      g_status_message := g_status_message || chr(13) ||
		  'VALIDATION ERROR: Order Header: ordered_date is mandatory';
    END IF;
  
    IF p_header.operation IS NULL THEN
      g_status         := 'E102';
      g_status_message := g_status_message || chr(13) ||
		  'VALIDATION ERROR: Order Header: operation is mandatory';
    END IF;
  
    /*IF p_header.payment_term_id IS NULL THEN
      g_status         := 'E102';
      g_status_message := g_status_message || CHR(13) ||
                          'VALIDATION ERROR: Order Header: payment_term_id is mandatory';
    END IF;*/
  
    IF p_header.price_list_id IS NULL THEN
      g_status         := 'E102';
      g_status_message := g_status_message || chr(13) ||
		  'VALIDATION ERROR: Order Header: Price_list_id is mandatory';
    END IF;
  
    IF p_header.salesrep_id IS NULL THEN
      g_status         := 'E102';
      g_status_message := g_status_message || chr(13) ||
		  'VALIDATION ERROR: Order Header: SALESREP_ID is mandatory';
    END IF;
  
    IF p_header.order_source_name IS NULL THEN
      g_status         := 'E102';
      g_status_message := g_status_message || chr(13) ||
		  'VALIDATION ERROR: Order Header: order_source_name is mandatory';
    END IF;
  
    IF p_header.pofile IS NOT NULL THEN
      IF p_header.pocontenttype IS NULL THEN
        g_status         := 'E102';
        g_status_message := g_status_message || chr(13) ||
		    'VALIDATION ERROR: Order Header: poContentType is mandatory if poFile is not null';
      END IF;
    END IF;
  
    IF p_header.shipping_method_code IS NOT NULL THEN
    
      BEGIN
        l_tmp := get_lookup_meaning(p_lookup_type => 'SHIP_METHOD',
			p_lookup_code => p_header.shipping_method_code);
      
        IF l_tmp IS NULL THEN
          g_status         := 'E102';
          g_status_message := g_status_message || chr(13) ||
		      'VALIDATION ERROR: Shipping Method Code does not exist';
        END IF;
      
      EXCEPTION
        WHEN OTHERS THEN
          g_status         := 'E101';
          g_status_message := g_status_message || chr(13) ||
		      'Error in fetching shipping method code' ||
		      SQLERRM;
        
      END;
    END IF;
  
    IF p_header.freight_terms_code IS NOT NULL THEN
    
      BEGIN
        l_tmp := get_lookup_meaning(p_lookup_type => 'FREIGHT_TERMS',
			p_lookup_code => p_header.freight_terms_code);
      
        IF l_tmp IS NULL THEN
          g_status         := 'E102';
          g_status_message := g_status_message || chr(13) ||
		      'VALIDATION ERROR: Freight Terms Code does not exist';
        END IF;
      
      EXCEPTION
        WHEN OTHERS THEN
          g_status         := 'E101';
          g_status_message := g_status_message || chr(13) ||
		      'Error in fetching Freight Terms code' ||
		      SQLERRM;
        
      END;
    END IF;
  
    BEGIN
      l_sold_to_org_id := check_customer_account(p_header.sold_to_org_id,
				 p_header.account_number);
      IF l_sold_to_org_id = 0 THEN
        g_status         := 'E102';
        g_status_message := g_status_message || chr(13) ||
		    'VALIDATION ERROR: Customer Account ID ' ||
		    p_header.sold_to_org_id ||
		    ' Or Account Number ' ||
		    p_header.account_number ||
		    ' does not exist in Oracle';
      END IF;
    EXCEPTION
      WHEN no_data_found THEN
        g_status         := 'E100';
        g_status_message := g_status_message || chr(13) ||
		    'VALIDATION ERROR: Customer Account ID ' ||
		    p_header.sold_to_org_id ||
		    ' Or Account Number ' ||
		    p_header.account_number ||
		    ' does not exist in Oracle';
      
      WHEN OTHERS THEN
        g_status         := 'E101';
        g_status_message := g_status_message || chr(13) ||
		    'ERROR: While checking customer account ID Or Account Number ' ||
		    p_header.account_number ||
		    substr(SQLERRM, 1, 100);
    END;
  
    l_exists := 0;
    BEGIN
      l_exists := check_bill_to_site(l_sold_to_org_id /*p_header.sold_to_org_id*/,
			 p_header.invoice_to_org_id,
			 p_header.org_id);
      IF l_exists = 0 THEN
        g_status         := 'E102';
        g_status_message := g_status_message || chr(13) ||
		    'VALIDATION ERROR: Bill To Site ID ' ||
		    p_header.invoice_to_org_id ||
		    ' is not valid for given customer account id/account number and org id';
      END IF;
    EXCEPTION
      WHEN no_data_found THEN
        g_status         := 'E100';
        g_status_message := g_status_message || chr(13) ||
		    'VALIDATION ERROR: Bill To Site ID ' ||
		    p_header.invoice_to_org_id ||
		    ' is not valid for given customer account id and org id';
      WHEN OTHERS THEN
        g_status         := 'E101';
        g_status_message := g_status_message || chr(13) ||
		    'ERROR: While checking bill to site ID' ||
		    SQLERRM;
    END;
  
    l_exists := 0;
  
    FOR j IN 1 .. p_line.count
    LOOP
    
      IF p_line(j).line_number IS NULL THEN
        g_status         := 'E102';
        g_status_message := g_status_message || chr(13) ||
		    'VALIDATION ERROR: Order Line Number is mandatory';
      END IF;
      --CHG0048217 item code
      IF p_line(j).inventory_item_id IS NULL AND p_line(j).item_code IS NULL THEN
        g_status         := 'E102';
        g_status_message := g_status_message || chr(13) ||
		    'VALIDATION ERROR: Order Line Number:' || j ||
		    ': Inventory Item ID or Item Code is mandatory';
      END IF;
    
      IF p_line(j)
       .ordered_quantity IS NULL OR p_line(j).ordered_quantity <= 0 THEN
        g_status         := 'E102';
        g_status_message := g_status_message || chr(13) ||
		    'VALIDATION ERROR: Order Line Number:' || j ||
		    ': Quantity must be provided';
      END IF;
    
      IF p_line(j).unit_list_price IS NULL THEN
        g_status         := 'E102';
        g_status_message := g_status_message || chr(13) ||
		    'VALIDATION ERROR: Unit List Price is mandatory';
      END IF;
    
      IF p_line(j).unit_selling_price IS NULL THEN
        g_status         := 'E102';
        g_status_message := g_status_message || chr(13) ||
		    'VALIDATION ERROR: Unit Selling Price is mandatory';
      END IF;
    
      BEGIN
        IF p_line(j).inventory_item_id IS NOT NULL THEN
          l_item_name := NULL;
          -- CHG0048217
          l_item_name := fetch_item_name(p_line(j).inventory_item_id,
			     p_line(j).item_code);
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          g_status         := 'E101';
          g_status_message := g_status_message || chr(13) ||
		      'ERROR: While fetching Line Item Name. Line Number:' || p_line(j)
		     .line_number || '. Item ID is ' || p_line(j)
		     .inventory_item_id || '. Item Code is ' || p_line(j)
		     .item_code || ' .' || SQLERRM;
      END;
    
    END LOOP;
  
  EXCEPTION
  
    WHEN OTHERS THEN
      g_status         := 'E101';
      g_status_message := g_status_message || chr(13) ||
		  'Validation not passed' || SQLERRM;
    
  END validate_order;

  -------------------------------------------------------------------------------
  --  name:          update_pricing_tables
  --  created by:    Debarati Banerjee
  --  Revision       1.0
  --  creation date: 20/03/2015
  -------------------------------------------------------------------------------
  --  purpose :      CHG0034837: Set order_created_flag as 'Y' if order
  --                 creation is successful.Else set it as 'E' for error
  -------------------------------------------------------------------------------
  --  ver  date          name                desc
  --  ---  ------------  ------------------  ------------------------------------
  --  1.0  20/03/2015    debarati banerjee   Initial Build - CHG0034837
  --  1.1  28-NOV-2017   Diptasurjya         CHG0041897 - handle request source for pricing tables
  --  1.2  07-JUL-2018   Diptasurjya         INC0127634 - Character conversion from cart ID
  --  3.5  07/10/2020    Roman W             CHG0048217 - changed parameter p_cartid type from NUMBER to VARCHAR2
  -------------------------------------------------------------------------------
  PROCEDURE update_pricing_tables(p_cartid IN VARCHAR2, -- Added By R.W 07/10/2020 CHG0048217
		          /*p_cartid          IN NUMBER, -- Rem By R.W 07/10/2020 CHG0048217 */
		          p_flag            IN VARCHAR2,
		          p_request_source  IN VARCHAR2, -- CHG0041897
		          g_status_message1 OUT VARCHAR2,
		          g_status1         OUT VARCHAR2) IS
  
  BEGIN
  
    g_status1 := 'S';
  
    UPDATE xx_qp_pricereq_session adj
    SET    adj.order_created_flag = p_flag,
           adj.end_date           = SYSDATE
    WHERE  1 = 1
          --    and    adj.request_number = to_char(p_cartid) -- INC0127634 -- Rem By R.W 07/10/2020 CHG0048217
    AND    adj.request_number = p_cartid -- Added By R.W 07/10/2020 CHG0048217
    AND    adj.order_created_flag IS NULL
    AND    request_source = p_request_source; -- CHG0041897
  
    UPDATE xx_qp_pricereq_modifiers adj
    SET    adj.order_created_flag = p_flag,
           adj.end_date           = SYSDATE
    WHERE  1 = 1
          -- and    adj.request_number = to_char(p_cartid) -- INC0127634 -- Rem By R.W 07/10/2020 XXX
    AND    adj.request_number = p_cartid -- Added By R.W 07/10/2020 CHG0048217
    AND    adj.order_created_flag IS NULL
    AND    request_source = p_request_source; -- CHG0041897
  
    UPDATE xx_qp_pricereq_attributes adj
    SET    adj.order_created_flag = p_flag,
           adj.end_date           = SYSDATE
    WHERE  1 = 1
          -- and    adj.request_number = to_char(p_cartid) -- INC0127634 -- Rem By R.W 07/10/2020 CHG0048217
    AND    adj.request_number = p_cartid -- Added By R.W 07/10/2020 CHG0048217
    AND    adj.order_created_flag IS NULL
    AND    request_source = p_request_source; -- CHG0041897
  
    UPDATE xx_qp_pricereq_reltd_adj adj
    SET    adj.order_created_flag = p_flag,
           adj.end_date           = SYSDATE
    WHERE  1 = 1
          --AND    adj.request_number = to_char(p_cartid) -- INC0127634 -- Rem By R.W 07/10/2020 CHG0048217
    AND    adj.request_number = p_cartid -- Added By R.W 07/10/2020 CHG0048217
    AND    adj.order_created_flag IS NULL
    AND    request_source = p_request_source; -- CHG0041897
  
  EXCEPTION
    WHEN no_data_found THEN
      -- g_status         := 'E100';
      g_status1         := 'E100';
      g_status_message1 := g_status_message || chr(13) ||
		   'ERROR: No data found for Request Number:' ||
		   p_cartid;
    WHEN OTHERS THEN
      -- g_status         := 'E101';
      g_status1         := 'E101';
      g_status_message1 := g_status_message || chr(13) ||
		   'ERROR: While updating pricing table' || '' ||
		   SQLERRM;
  END update_pricing_tables;

  ----------------------------------------------------------------------

  --  name:          get_doc_category_id
  --  created by:    Debarati Banerjee
  --  Revision       1.0
  --  creation date: 20/03/2015
  ----------------------------------------------------------------------
  --  purpose :      CHG0034837: This function returns document category
  --                 ID for a provided document category
  ----------------------------------------------------------------------

  FUNCTION get_doc_category_id(p_document_category IN VARCHAR2) RETURN NUMBER IS
    l_category_id NUMBER;
  BEGIN
    SELECT category_id
    INTO   l_category_id
    FROM   fnd_document_categories_tl
    WHERE  user_name = p_document_category
    AND    LANGUAGE = g_language;
  
    RETURN l_category_id;
  END;

  ----------------------------------------------------------------------

  --  name:          get_file_extension
  --  created by:    Debarati Banerjee
  --  Revision       1.0
  --  creation date: 20/03/2015
  ---------------------------------------------------------------------------
  --  purpose :      CHG0034837: This function returns the file extension for
  --                   a PO attachment
  -- Ver  When        Who          Descr 
  -- ---  ----------  ---------  -------------------------------------------
  -- 1.0  14/01/2021  Roman W.   CHG0047450 - Re-Do 
  ---------------------------------------------------------------------------
  FUNCTION get_file_extension(p_filename IN VARCHAR2) RETURN VARCHAR2 IS
    l_file_ext       VARCHAR2(20);
    l_point_position NUMBER;
  BEGIN
    /* Rem by Roman W. 14/01/2021
    SELECT substr(p_filename, instr(p_filename, '.') + 1)
      INTO l_file_ext
      FROM dual;
    */
  
    -- Added By Roman W. 14/01/2021
    l_point_position := instr(p_filename, '.', -1);
  
    IF l_point_position > 0 THEN
      l_file_ext := substr(p_filename, l_point_position + 1);
    ELSE
      l_file_ext := NULL;
    END IF;
  
    RETURN l_file_ext;
  END;

  ----------------------------------------------------------------------

  --  name:          get_ack_email
  --  created by:    Debarati Banerjee
  --  Revision       1.0
  --  creation date: 20/05/2015
  ---------------------------------------------------------------------------
  --  purpose :      CHG0035705: This function returns the Additional header
  --                 information DFF attribute 19 value
  ---------------------------------------------------------------------------
  --  ver  date          name                 desc
  --  1.0  20/03/2015    debarati banerjee    Initial Build - CHG0034837
  --  1.1  09/12/2019    Diptasurjya          CHG0045128 - generate emails using single common function
  ---------------------------------------------------------------------------

  FUNCTION get_ack_email(p_order_type_id      IN NUMBER,
		 p_sold_to_contact_id IN NUMBER, -- CHG0045128 added
		 p_ship_to_contact_id IN NUMBER, -- CHG0045128 added
		 p_bill_to_contact_id IN NUMBER) RETURN VARCHAR2 IS
    -- CHG0045128 added
    l_ack_email VARCHAR2(300);
  BEGIN
    -- CHG0045128 commented below
    /*SELECT fvv.description
    INTO   l_ack_email
    FROM   fnd_flex_values_vl  fvv,
           fnd_flex_value_sets fvs
    WHERE  fvv.flex_value_set_id = fvs.flex_value_set_id
    AND    fvv.flex_value = p_order_type_id
    AND    fvs.flex_value_set_name = 'XX_ORDER_ACK_DEFAULT_EMAIL_LIST';*/
  
    -- CHG0045128 added below
    l_ack_email := xxoe_utils_pkg.generate_ack_dist_list(p_order_type_id      => p_order_type_id,
				         p_ship_contact_id    => p_ship_to_contact_id,
				         p_bill_contact_id    => p_bill_to_contact_id,
				         p_sold_contact_id    => p_sold_to_contact_id,
				         p_existing_dist_list => NULL,
				         p_distribution_type  => 'XX_ORDER_ACK_DEFAULT_EMAIL_LIST');
  
    RETURN l_ack_email;
  END;

  ----------------------------------------------------------------------

  --  name:          get_ship_email
  --  created by:    Debarati Banerjee
  --  Revision       1.0
  --  creation date: 20/05/2015
  ---------------------------------------------------------------------------
  --  purpose :      CHG0035705: This function returns the Additional header
  --                 information DFF attribute 20 value
  ---------------------------------------------------------------------------
  --  ver  date          name                 desc
  --  1.0  20/03/2015    debarati banerjee    Initial Build - CHG0034837
  --  1.1  09/12/2019    Diptasurjya          CHG0045128 - generate emails using single common function
  ---------------------------------------------------------------------------

  FUNCTION get_ship_email(p_order_type_id      IN NUMBER,
		  p_sold_to_contact_id IN NUMBER, -- CHG0045128 added
		  p_ship_to_contact_id IN NUMBER, -- CHG0045128 added
		  p_bill_to_contact_id IN NUMBER) RETURN VARCHAR2 IS
    -- CHG0045128 added
    l_ship_email VARCHAR2(300);
  BEGIN
    -- CHG0045128 commented below
    /*SELECT fvv.description
    INTO   l_ship_email
    FROM   fnd_flex_values_vl  fvv,
           fnd_flex_value_sets fvs
    WHERE  fvv.flex_value_set_id = fvs.flex_value_set_id
    AND    fvv.flex_value = p_order_type_id
    AND    fvs.flex_value_set_name = 'XX_SHIP_ACK_DEFAULT_EMAIL_LIST';*/
  
    -- CHG0045128 added below
    l_ship_email := xxoe_utils_pkg.generate_ack_dist_list(p_order_type_id      => p_order_type_id,
				          p_ship_contact_id    => p_ship_to_contact_id,
				          p_bill_contact_id    => p_bill_to_contact_id,
				          p_sold_contact_id    => p_sold_to_contact_id,
				          p_existing_dist_list => NULL,
				          p_distribution_type  => 'XX_SHIP_ACK_DEFAULT_EMAIL_LIST');
  
    RETURN l_ship_email;
  END;

  --------------------------------------------------------------------

  --  name:          create_cc_authorization
  --  created by:    Diptasurjya Chatterjee
  --  Revision       1.0
  --  creation date: 01/16/2019
  --------------------------------------------------------------------
  --  purpose :      CHG0044725: Create a Credit Card voice authorization in IBY
  --------------------------------------------------------------------------------------------------------------------
  --  ver  date          name                      desc
  --  1.0  01/16/2019    Diptasurjya Chatterjee    CHG0044725 - Initial Build
  --  1.1  9/7/2020      yuval tal                 CHG0048217 - support account number
  ----------------------------------------------------------------------------------------------------------------------

  PROCEDURE create_cc_authorization(p_header_rec    IN xxecom.xxom_order_header_rec_type,
			p_header_id     IN NUMBER,
			p_ipay_instr_id IN NUMBER,
			p_debug_flag    IN VARCHAR2 DEFAULT 'N',
			p_err_code      OUT VARCHAR2,
			p_err_message   OUT VARCHAR2) IS
    l_return_status        VARCHAR2(1000);
    l_msg_count            NUMBER;
    l_msg_data             VARCHAR2(4000);
    l_customer_context_rec iby_fndcpt_common_pub.payercontext_rec_type;
    l_payeecontext_rec     iby_fndcpt_trxn_pub.payeecontext_rec_type;
    l_authattribs_rec      iby_fndcpt_trxn_pub.authattribs_rec_type;
    l_amount_rec           iby_fndcpt_trxn_pub.amount_rec_type;
    l_tax_amount_rec       iby_fndcpt_trxn_pub.amount_rec_type;
    l_authresult_rec       iby_fndcpt_trxn_pub.authresult_rec_type;
    l_trx_entity_id        NUMBER;
    l_result_rec_type      iby_fndcpt_common_pub.result_rec_type;
  
    l_order_discount NUMBER;
    l_order_charges  NUMBER;
    l_order_subtotal NUMBER;
    l_order_tax      NUMBER;
  
    l_data      VARCHAR2(4000);
    l_msg_index NUMBER;
  BEGIN
    --dbms_output.put_line('In CC authorization');
    p_err_code    := 'S';
    p_err_message := '';
  
    --------------------------------------------------------------------------------------------------------------------------------
    l_customer_context_rec.payment_function := 'CUSTOMER_PAYMENT';
    --l_customer_context_rec.cust_account_id  := p_header_rec.sold_to_org_id; -- CHG0048217 - Dipta comment to support account number
  
    BEGIN
      SELECT party_id,
	 cust_account_id -- CHG0048217 - Dipta added cust_account_id
      INTO   l_customer_context_rec.party_id,
	 l_customer_context_rec.cust_account_id -- CHG0048217 - Dipta added fetch into custom_account_id
      FROM   hz_cust_accounts
      WHERE  (cust_account_id = p_header_rec.sold_to_org_id OR
	 account_number = p_header_rec.account_number);
    EXCEPTION
      WHEN no_data_found THEN
        p_err_code    := 'E';
        p_err_message := p_err_message || chr(13) ||
		 'VALIDATION ERR: CC Auth: While fetching party_id/account_id for account_id: ' ||
		 p_header_rec.sold_to_org_id;
    END;
  
    l_customer_context_rec.account_site_id := p_header_rec.invoice_to_org_id;
    l_customer_context_rec.org_id          := p_header_rec.org_id;
    l_customer_context_rec.org_type        := 'OPERATING_UNIT';
    --------------------------------------------------------------------------------------------------------------------------------
  
    --Start p_payee values
    l_payeecontext_rec.org_type := 'OPERATING_UNIT';
    l_payeecontext_rec.org_id   := p_header_rec.org_id;
    --l_PayeeContext_rec.Int_Bank_Country_Code := 'US';
    --End p_payee values
  
    BEGIN
      SELECT hl.postal_code,
	 hcsua.site_use_id
      INTO   l_authattribs_rec.shipto_postalcode,
	 l_authattribs_rec.shipto_siteuse_id
      FROM   hz_cust_site_uses_all  hcsua,
	 hz_cust_acct_sites_all hcasa,
	 hz_party_sites         hps,
	 hz_locations           hl
      WHERE  hcsua.site_use_id = p_header_rec.invoice_to_org_id
      AND    hcsua.cust_acct_site_id = hcasa.cust_acct_site_id
      AND    hcasa.party_site_id = hps.party_site_id
      AND    hps.location_id = hl.location_id;
    EXCEPTION
      WHEN no_data_found THEN
        p_err_code    := 'E';
        p_err_message := p_err_message || chr(13) ||
		 'VALIDATION ERR: CC Auth: While fetching postal_code for site_use_id: ' ||
		 p_header_rec.invoice_to_org_id;
    END;
  
    BEGIN
      SELECT asp.irec_cc_receipt_method_id
      INTO   l_authattribs_rec.receipt_method_id
      FROM   ar_system_parameters_all asp
      WHERE  asp.org_id = p_header_rec.org_id;
    EXCEPTION
      WHEN no_data_found THEN
        p_err_code    := 'E';
        p_err_message := p_err_message || chr(13) ||
		 'VALIDATION ERR: CC Auth: No default CC receipt method has been set in AR system Parameters for org_id: ' ||
		 p_header_rec.org_id;
    END;
  
    BEGIN
      SELECT ite.trxn_extension_id
      INTO   l_trx_entity_id
      FROM   iby_trxn_extensions_v ite
      WHERE  order_id = to_char(p_header_id)
      AND    instrument_id = p_ipay_instr_id;
    EXCEPTION
      WHEN no_data_found THEN
        p_err_code    := 'E';
        p_err_message := p_err_message || chr(13) ||
		 'VALIDATION ERR: CC Auth: While fetching Trx Extn ID for order header and p_ipay_instr_id: ' ||
		 p_ipay_instr_id;
    END;
  
    BEGIN
      SELECT oh.transactional_curr_code,
	 oh.transactional_curr_code
      INTO   l_tax_amount_rec.currency_code,
	 l_amount_rec.currency_code
      FROM   oe_order_headers_all oh
      WHERE  header_id = p_header_id;
    EXCEPTION
      WHEN no_data_found THEN
        p_err_code    := 'E';
        p_err_message := p_err_message || chr(13) ||
		 'VALIDATION ERR: CC Auth: While fetching currency code for order header';
    END;
  
    BEGIN
      oe_oe_totals_summary.order_totals(p_header_id => p_header_id,
			    p_subtotal  => l_order_subtotal,
			    p_discount  => l_order_discount,
			    p_charges   => l_order_charges,
			    p_tax       => l_order_tax);
    
      l_tax_amount_rec.value := l_order_tax;
      l_amount_rec.value     := l_order_subtotal + l_order_charges +
		        l_order_tax;
    EXCEPTION
      WHEN OTHERS THEN
        p_err_code    := 'E';
        p_err_message := p_err_message || chr(13) ||
		 'VALIDATION ERR: CC Auth: While fetching order totals: ' ||
		 SQLERRM;
    END;
  
    p_err_message := ltrim(p_err_message, chr(13));
  
    l_authattribs_rec.payment_factor_flag  := 'N';
    l_authattribs_rec.tax_amount           := l_tax_amount_rec;
    l_authattribs_rec.riskeval_enable_flag := 'N';
  
    /*dbms_output.put_line('l_customer_context_rec.Cust_Account_Id: '||l_customer_context_rec.Cust_Account_Id);
    dbms_output.put_line('l_customer_context_rec.Party_Id: '||l_customer_context_rec.Party_Id);
    dbms_output.put_line('l_customer_context_rec.Account_Site_Id: '||l_customer_context_rec.Account_Site_Id);
    dbms_output.put_line('l_customer_context_rec.Org_Id: '||l_customer_context_rec.Org_Id);
    dbms_output.put_line('l_tax_amount_rec.Currency_Code: '||l_tax_amount_rec.Currency_Code);
    dbms_output.put_line('l_AuthAttribs_rec.ShipTo_PostalCode: '||l_AuthAttribs_rec.ShipTo_PostalCode);
    dbms_output.put_line('l_AuthAttribs_rec.ShipTo_SiteUse_Id: '||l_AuthAttribs_rec.ShipTo_SiteUse_Id);
    dbms_output.put_line('l_AuthAttribs_rec.Receipt_Method_Id: '||l_AuthAttribs_rec.Receipt_Method_Id);
    dbms_output.put_line('l_trx_entity_id: '||l_trx_entity_id);
    dbms_output.put_line('p_err_code: '||p_err_code);*/
  
    IF p_err_code <> 'E' THEN
      iby_fndcpt_trxn_pub.create_authorization(p_api_version       => 1.0,
			           p_init_msg_list     => fnd_api.g_false,
			           x_return_status     => l_return_status,
			           x_msg_count         => l_msg_count,
			           x_msg_data          => l_msg_data,
			           p_payer             => l_customer_context_rec, --Identifies the payer
			           p_payer_equivalency => iby_fndcpt_common_pub.g_payer_equiv_full, --Must be one of the equivalency constants
			           p_payee             => l_payeecontext_rec,
			           p_trxn_entity_id    => l_trx_entity_id, --use value from step 3
			           p_auth_attribs      => l_authattribs_rec, --AuthAttribs_rec_type,
			           p_amount            => l_amount_rec,
			           x_auth_result       => l_authresult_rec, --OUT AuthResult_rec_type,
			           x_response          => l_result_rec_type --OUT  IBY_FNDCPT_COMMON_PUB.Result_rec_type
			           );
    
      IF l_return_status = fnd_api.g_ret_sts_success THEN
        p_err_code    := 'S';
        p_err_message := NULL;
      
        --dbms_output.put_line('p_err_code: '||p_err_code);
      ELSE
        p_err_code    := 'E';
        p_err_message := 'API ERROR: CC Authorization: IBY_Fndcpt_Trxn_Pub.Create_Authorization: ';
      
        FOR i IN 1 .. l_msg_count
        LOOP
          fnd_msg_pub.get(p_msg_index     => i, -- DIPTA - change to fnd_msg_pub instead of oe_msg_pub
		  p_encoded       => fnd_api.g_false,
		  p_data          => l_data,
		  p_msg_index_out => l_msg_index);
        
          p_err_message := p_err_message || l_data;
        END LOOP;
        --dbms_output.put_line('p_err_code: '||p_err_code);
        --dbms_output.put_line(l_msg_data);
      END IF;
    END IF;
    --dbms_output.put_line('Leaving CC authorization: Status: '||p_err_code);
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code    := 'E';
      p_err_message := 'ERROR: While CC authorization. ' || SQLERRM;
  END create_cc_authorization;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0045755 - This function checks if bom_item_type for an item is valid for explicit
  --                       explosion during order line import
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  22/05/2019  Diptasurjya Chatterjee (TCS)    CHG0045755 - Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION is_item_bom_type_valid(p_inventory_item_id IN NUMBER)
    RETURN VARCHAR2 IS
    l_bom_item_type_valid VARCHAR2(1) := 'N';
  BEGIN
    SELECT 'Y'
    INTO   l_bom_item_type_valid
    FROM   bom_bill_of_materials_v x,
           mtl_system_items_b      msib
    WHERE  rownum = 1
    AND    msib.bom_item_type = 1 --MODEL
    AND    msib.inventory_item_id = x.assembly_item_id
    AND    x.organization_id = msib.organization_id
    AND    msib.organization_id =
           xxinv_utils_pkg.get_master_organization_id
    AND    msib.inventory_item_id = p_inventory_item_id
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

  --------------------------------------------------------------------
  --  name:          generate_order_output
  --  created by:    Diptasurjya Chatterjee
  --  Revision       1.0
  --  creation date: 15-DEC-2020
  --------------------------------------------------------------------
  --  purpose :      CHG0048217 : generate output data
  --------------------------------------------------------------------------------------------------------------------
  --  ver  date           name                      desc
  --  1.0  15-DEC-2020    Diptasurjya Chatterjee    Initial Build - CHG0048217
  --  1.1  27.1.2021      Yuval Tal                 CHG0048217 exclude exploded items 
  ----------------------------------------------------------------------------------------------------------------------

  PROCEDURE generate_order_output(p_header_id IN NUMBER,
		          x_order     OUT xxecom.xxom_order_header_rec_type,
		          x_lines     OUT xxecom.xxom_order_line_tab_type) IS
    l_order_out xxom_order_header_rec_type;
    l_lines_out xxom_order_line_tab_type := xxom_order_line_tab_type();
    l_cnt       NUMBER := 0;
  BEGIN
  
    l_order_out := xxom_order_header_rec_type(NULL,
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
			          NULL,
			          NULL,
			          NULL,
			          NULL,
			          NULL,
			          NULL);
    FOR header_rec IN (SELECT oh.header_id,
		      oh.orig_sys_document_ref
	           FROM   oe_order_headers_all oh
	           WHERE  oh.header_id = p_header_id)
    LOOP
    
      l_order_out.header_id           := header_rec.header_id;
      l_order_out.external_ref_number := header_rec.orig_sys_document_ref;
    END LOOP;
  
    FOR line_rec IN (SELECT ol.line_id,
		    ol.orig_sys_line_ref,
		    ol.ordered_item,
		    ol.ordered_quantity,
		    ol.unit_list_price,
		    ol.unit_selling_price
	         FROM   oe_order_lines_all ol
	         WHERE  header_id = p_header_id
	         AND    ol.link_to_line_id IS NULL)
    LOOP
      -- CHG0048217
      l_cnt := l_cnt + 1;
      l_lines_out.extend();
      l_lines_out(l_cnt) := xxom_order_line_rec_type(NULL,
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
    
      l_lines_out(l_cnt).line_id := line_rec.line_id;
      l_lines_out(l_cnt).external_ref_number := line_rec.orig_sys_line_ref;
      l_lines_out(l_cnt).item_code := line_rec.ordered_item;
      l_lines_out(l_cnt).ordered_quantity := line_rec.ordered_quantity;
      l_lines_out(l_cnt).unit_list_price := line_rec.unit_list_price;
      l_lines_out(l_cnt).unit_selling_price := line_rec.unit_selling_price;
    
    END LOOP;
  
    x_order := l_order_out;
    x_lines := l_lines_out;
  END generate_order_output;

  --------------------------------------------------------------------

  --  name:          create_order
  --  created by:    Debarati Banerjee
  --  Revision       1.0
  --  creation date: 20/03/2015
  --------------------------------------------------------------------
  --  purpose :      CHG0034837: Sales Order interface between Hybris
  --                 and Oracle Apps to handle order creation
  --------------------------------------------------------------------------------------------------------------------
  --  ver  date          name                 desc
  --  1.0  20/03/2015    debarati banerjee    Initial Build - CHG0034837
  --  1.1  17/06/2015    debarati banerjee    CHG0035717 - Used profile option in create_order procedure for debug log file location
  --  1.2  02/07/2015    debarati banerjee    CHG0035705 - Added logic to populated ack email and ship email in additional header info DFF
  --  1.3  26/10/2015    debarati banerjee    CHG0036623 - Added logic to determine order status based on order state specified in
  --                                          XXOM_SF2OA_Order_Types_Mapping value set and include the partial shipment functionality.
  --                                          Salesperson will be populated from Defaulting Rules setup.Freight_term_code will be populated
  --                                          with the value sent in Incoterms field in case of EMEA orders.Added logic to fetch fob code
  --                                          for EMEA orders
  --  1.4 14-Jun-2016    Lingaraj Sarangi     CHG0038756 - Adjust ecommerce create order interface to support credit card process
  --  1.5 12-OCT-2016    Lingaraj Sarangi     CHG0039481 - Adjust ecommerce create order interface to support Creditcard Token integration with eStore.
  --  1.6 27.2.17        yuval tal            CHG0040236 - change incoterm logic remove attribute9 assignments
  --  1.7 29.6.17        yuval tal            1818 - modify create order : set default value to header attribute 18
  --  1.8 27-OCT-2017    Diptasurjya          CHG0041715 - Promo code change (ask for modifier). Order header pricing attribute is being populated
  --                                          Assumptions: a. Promo code will always be applied at header level
  --                                                       b. Only 1 promo code will be applied per order header
  --                                                       c. Promo code will appear in Promotions window of SO even though no actual pricing
  --                                                          adjustment was done (due to qualifiers)
  --                                                       d. Invalid promo code will cause order creation failure
  --  1.9 28-NOV-2017    Diptasurjya          CHG0041897 - Handle SFDC changes made to pricing temporary tables
  --  2.0 12/04/2017     Bellona              INC0108633 - trim and remove control characters from po_number field
  --  2.1 08/07/2018     Diptasurjya          INC0128351 - Remove end date filter from adjustment selection
  --  3.0 01/17/2019     Diptasurjya          CHG0044725 - Make changes for calling CC authorization code in case order is created in ENTERED state
  --  3.1 03/04/2019     Diptasurjya          CHG0044403 - Remove Dangerous Good shipping instruction for specific item-carrier combination
  --  3.2 22/05/2019     Diptasurjya          CHG0045755 - Handle PTO BOM explode
  --  3.3 09/12/2019     Diptasurjya          CHG0045128 - Change order and ship ack email generation calls
  --  3.4 09/07/2020     yuval tal            CHG0048217 - support new header account number and line record  item code support
  ----------------------------------------------------------------------------------------------------------------------

  PROCEDURE create_order(p_header_rec      IN xxecom.xxom_order_header_rec_type,
		 p_line_tab        IN xxecom.xxom_order_line_tab_type,
		 p_debug_flag      IN VARCHAR2 DEFAULT 'N',
		 p_username        IN VARCHAR2,
		 p_request_source  IN VARCHAR2, -- CHG0041897
		 p_err_code        OUT VARCHAR2,
		 p_err_message     OUT VARCHAR2,
		 p_order_number    OUT NUMBER,
		 p_order_header_id OUT NUMBER,
		 p_order_status    OUT VARCHAR2,
		 x_header_rec      OUT xxecom.xxom_order_header_rec_type, -- CHG0048217 add
		 x_line_tab        OUT xxecom.xxom_order_line_tab_type) IS
    -- CHG0048217 add
  
    --declare cursors
  
    CURSOR c_adjustment IS
      SELECT *
      FROM   xx_qp_pricereq_modifiers adj
      WHERE  adj.request_number = p_header_rec.cartid
	--AND    trunc(end_date) IS NULL  -- INC0128351 commented
      AND    request_source = p_request_source -- CHG0041897
      ORDER  BY line_num,
	    line_adj_num;
  
    CURSOR c_attributes IS
      SELECT *
      FROM   xx_qp_pricereq_attributes attrib
      WHERE  attrib.request_number = p_header_rec.cartid
	--AND    trunc(end_date) IS NULL  -- INC0128351 commented
      AND    request_source = p_request_source -- CHG0041897
      ORDER  BY line_num,
	    line_adj_num;
  
    CURSOR c_assoc IS
      SELECT *
      FROM   xx_qp_pricereq_reltd_adj assoc
      WHERE  assoc.request_number = p_header_rec.cartid
	--AND    trunc(end_date) IS NULL  -- INC0128351 commented
      AND    request_source = p_request_source -- CHG0041897
      ORDER  BY line_num,
	    line_adj_num;
  
    CURSOR c_lines(p_header_id NUMBER) IS
      SELECT oola.line_id
      FROM   oe_order_lines_all oola
      WHERE  oola.header_id = p_header_id;
  
    -- CHG0045755 - Change to handle PTO explode
    CURSOR cur_model_items(cp_inventory_item_id NUMBER) IS
      SELECT bic.component_quantity,
	 bbo.assembly_item_id,
	 bic.component_item_id,
	 bic.item_num,
	 msib_c.bom_item_type child_bom_item_type
      FROM   bom_bill_of_materials_v    bbo,
	 bom_inventory_components_v bic,
	 mtl_system_items_b         msib_c
      WHERE  bbo.bill_sequence_id = bic.bill_sequence_id
      AND    bbo.assembly_item_id = cp_inventory_item_id
      AND    bbo.organization_id =
	 xxinv_utils_pkg.get_master_organization_id
      AND    msib_c.organization_id = bbo.organization_id
      AND    msib_c.inventory_item_id = bic.component_item_id
      AND    SYSDATE BETWEEN nvl(bic.implementation_date, SYSDATE - 1) AND
	 nvl(bic.disable_date, SYSDATE + 1)
      ORDER  BY bic.item_num;
  
    l_api_version_number   NUMBER := 1;
    l_return_status        VARCHAR2(2000);
    l_return_status1       VARCHAR2(2000);
    g_status_message_count NUMBER;
  
    g_status_message_data  VARCHAR2(2000);
    l_msg_count            NUMBER;
    l_msg_data             VARCHAR2(2000);
    l_msg_count1           NUMBER;
    l_msg_data1            VARCHAR2(2000);
    l_xxstatus             VARCHAR2(1000);
    l_order_type_id        NUMBER;
    l_order_type           VARCHAR2(240);
    l_max_line_number      NUMBER := 0;
    l_pos_line_type_id     NUMBER;
    l_neg_line_type_id     NUMBER;
    l_resp_id              NUMBER;
    j                      NUMBER := 1;
    l_attchment_status     VARCHAR2(5);
    l_attchment_status_msg VARCHAR2(2000);
    l_media_id             NUMBER := NULL;
    l_prg_index            NUMBER := 0;
    l_dis_index            NUMBER := 0;
    l_adj_inx              NUMBER := 0;
    l_att_inx              NUMBER := 0;
    l_assoc_inx            NUMBER := 0;
    l_category_id          NUMBER := 0;
    l_file_ext             VARCHAR2(20);
    l_ordered_date         DATE;
    l_ordered_date1        DATE;
    l_date                 VARCHAR2(30);
    l_debug_level          NUMBER := 1;
    l_org                  NUMBER := p_header_rec.org_id; -- Org ID
    l_ship_set_id          NUMBER;
    l_inx                  NUMBER;
    l_order_state          VARCHAR2(100);
    l_fob_point_code       VARCHAR2(200);
  
    l_header_rec             oe_order_pub.header_rec_type;
    l_header_rec_upd         oe_order_pub.header_rec_type;
    l_line_tbl               oe_order_pub.line_tbl_type;
    l_line_tbl_upd           oe_order_pub.line_tbl_type;
    l_action_request_tbl     oe_order_pub.request_tbl_type;
    l_action_request_tbl_upd oe_order_pub.request_tbl_type;
    l_header_adj_tbl         oe_order_pub.header_adj_tbl_type;
  
    l_header_prc_att_tbl oe_order_pub.header_price_att_tbl_type; -- CHG0041715
  
    l_line_adj_tbl          oe_order_pub.line_adj_tbl_type;
    l_line_adj_assoc_tbl    oe_order_pub.line_adj_assoc_tbl_type;
    l_line_adj_attrib_tbl   oe_order_pub.line_adj_att_tbl_type;
    l_header_adj_attrib_tbl oe_order_pub.header_adj_att_tbl_type;
    l_user                  NUMBER;
    l_resp                  NUMBER;
    l_appl                  NUMBER;
  
    -- Out
  
    l_header_rec_out             oe_order_pub.header_rec_type;
    l_header_val_rec_out         oe_order_pub.header_val_rec_type;
    l_header_adj_tbl_out         oe_order_pub.header_adj_tbl_type;
    l_header_adj_val_tbl_out     oe_order_pub.header_adj_val_tbl_type;
    l_header_price_att_tbl_out   oe_order_pub.header_price_att_tbl_type;
    l_header_adj_att_tbl_out     oe_order_pub.header_adj_att_tbl_type;
    l_header_adj_assoc_tbl_out   oe_order_pub.header_adj_assoc_tbl_type;
    l_header_scredit_tbl_out     oe_order_pub.header_scredit_tbl_type;
    l_header_scredit_val_tbl_out oe_order_pub.header_scredit_val_tbl_type;
    l_line_tbl_out               oe_order_pub.line_tbl_type;
    l_line_val_tbl_out           oe_order_pub.line_val_tbl_type;
    l_line_adj_tbl_out           oe_order_pub.line_adj_tbl_type;
    l_line_adj_val_tbl_out       oe_order_pub.line_adj_val_tbl_type;
    l_line_price_att_tbl_out     oe_order_pub.line_price_att_tbl_type;
    l_line_adj_att_tbl_out       oe_order_pub.line_adj_att_tbl_type;
    l_line_adj_assoc_tbl_out     oe_order_pub.line_adj_assoc_tbl_type;
    l_line_scredit_tbl_out       oe_order_pub.line_scredit_tbl_type;
    l_line_scredit_val_tbl_out   oe_order_pub.line_scredit_val_tbl_type;
    l_lot_serial_tbl_out         oe_order_pub.lot_serial_tbl_type;
    l_lot_serial_val_tbl_out     oe_order_pub.lot_serial_val_tbl_type;
    l_action_request_tbl_out     oe_order_pub.request_tbl_type;
    l_header_payment_rec         oe_order_pub.header_payment_rec_type; --added for CHG0039481
    l_header_payment_tbl         oe_order_pub.header_payment_tbl_type := oe_order_pub.g_miss_header_payment_tbl; --added for CHG0039481
  
    l_msg_index  NUMBER;
    l_data       VARCHAR2(2000);
    l_loop_count NUMBER;
    l_debug_file VARCHAR2(200);
    --l_username VARCHAR2(100) := 'ECOMMERCE';
  
    l_line_index_calc    NUMBER := 1;
    l_adj_index_calc     NUMBER := 1;
    l_adj_index_hdr_calc NUMBER := 1;
    l_rel_adj_index_calc NUMBER := 1;
    g_status1            VARCHAR2(10) := 'S';
  
    --CHG0031464 - Credit Card Functionality for AR - iPayments - Modified on 26-May-2016
    l_attachment_category_id NUMBER;
    l_att_category_name      VARCHAR2(20) := fnd_profile.value('XX_OM_IPAY_ATT_CATEGORY');
    l_document_id            NUMBER := NULL;
    l_short_text             VARCHAR2(500);
    l_attch_err_code         VARCHAR2(1000);
    l_attch_err_msg          VARCHAR2(1000);
    l_err_code               NUMBER;
    l_error                  VARCHAR2(1000);
    l_payment_type_code      VARCHAR2(15) := '-999999';
    l_ipay_instrid           NUMBER;
  
    --CHG0041715 - promo code
    l_modifier_id NUMBER;
  
    -- CHG0041897 - Strataforce
    l_request_source_user VARCHAR2(200);
  
    -- CHG0044725
    l_cc_auth_err_code VARCHAR2(200);
    l_cc_auth_err_msg  VARCHAR2(4000);
  
    -- CHG0044403
    l_is_order_dg VARCHAR2(1);
  
    -- l_sold_to_org_id number ;
  BEGIN
    --dbms_lock.sleep(120);
  
    g_debug_flag     := p_debug_flag;
    g_status         := 'S';
    g_status_message := NULL;
  
    IF g_debug_flag = 'Y' THEN
      oe_debug_pub.add('SSYS CUSTOM: Start Log for ORDER NUMBER : ' ||
	           p_header_rec.order_number);
    END IF;
  
    /* CHG0041897 - Start request source validation */
    BEGIN
      SELECT attribute2
      INTO   l_request_source_user
      FROM   fnd_flex_values     ffv,
	 fnd_flex_value_sets ffvs
      WHERE  ffvs.flex_value_set_name = 'XXSSYS_EVENT_TARGET_NAME'
      AND    ffvs.flex_value_set_id = ffv.flex_value_set_id
      AND    upper(ffv.flex_value) = upper(p_request_source)
      AND    ffv.enabled_flag = 'Y'
      AND    SYSDATE BETWEEN nvl(ffv.start_date_active, SYSDATE - 1) AND
	 nvl(ffv.end_date_active, SYSDATE + 1);
    EXCEPTION
      WHEN no_data_found THEN
        p_err_code    := 'E';
        p_err_message := 'VALIDATION ERROR: Order Request source input parameter is not valid' ||
		 chr(13);
        RETURN;
    END;
    /* CHG0041897 - End request source validation */
  
    get_user_details(p_username => p_username,
	         l_user     => l_user,
	         --l_resp           => l_resp,
	         l_appl           => l_appl,
	         g_status         => g_status,
	         g_status_message => g_status_message);
  
    --fnd_global.apps_initialize(l_user, l_resp, l_appl);
    /*mo_global.set_policy_context('S', p_header_rec.org_id);
    mo_global.init('ONT');*/
  
    IF g_debug_flag = 'Y' THEN
      oe_debug_pub.setdebuglevel(5);
      oe_debug_pub.g_dir := fnd_profile.value('OE_DEBUG_LOG_DIRECTORY'); -- Must be registered UTL Directory
      g_debug_file_name  := oe_debug_pub.set_debug_mode('FILE');
      dbms_output.put_line(g_debug_file_name);
      g_status_message := 'OM Debug Log location: ' || g_debug_file_name;
      oe_debug_pub.initialize;
      oe_debug_pub.debug_on;
    
      dbms_output.put_line(g_debug_file_name);
      oe_debug_pub.add('SSYS CUSTOM: OM Debug log location: ' ||
	           g_debug_file_name);
    END IF;
  
    dbms_output.put_line('g_status1: ' || g_status);
    dbms_output.put_line('g_status_message1: ' || g_status_message);
  
    IF g_status = 'S' THEN
    
      --validate order data
    
      validate_order(p_header         => p_header_rec,
	         p_line           => p_line_tab,
	         g_status         => g_status,
	         g_status_message => g_status_message);
    
      --g_status_message := g_status_message||CHR(13)||'Data After Validation';
    
    END IF;
    dbms_output.put_line('g_status2: ' || g_status);
    dbms_output.put_line('g_status_message2: ' || g_status_message);
    IF g_status = 'S' THEN
      ---get the order type details
    
      --------------------------------------------------------------------------------------------------------------------
      --  ver  date          name                 desc
      --  1.3 26/10/2015    debarati banerjee    CHG0036623 - Added l_order_state as output param to derive order status
      ----------------------------------------------------------------------------------------------------------------------
    
      get_order_type_details(p_org_id           => p_header_rec.org_id,
		     p_operation        => p_header_rec.operation,
		     l_order_type_id    => l_order_type_id,
		     l_pos_line_type_id => l_pos_line_type_id,
		     l_neg_line_type_id => l_neg_line_type_id,
		     l_resp_id          => l_resp_id,
		     l_order_state      => l_order_state,
		     g_status           => g_status,
		     g_status_message   => g_status_message);
    
    END IF;
  
    -- Initialize user
  
    fnd_global.apps_initialize(l_user, l_resp_id, l_appl);
    mo_global.set_policy_context('S', p_header_rec.org_id);
    mo_global.init('ONT');
  
    l_header_rec := oe_order_pub.g_miss_header_rec;
    l_header_rec.operation := oe_globals.g_opr_create;
    l_header_payment_tbl(1) := l_header_payment_rec;
  
    IF g_status = 'S' THEN
      --Set header DFF attributes
      l_header_rec.attribute1 := nvl(p_header_rec.attribute1,
			 fnd_api.g_miss_char);
      l_header_rec.attribute2 := nvl(p_header_rec.attribute2,
			 fnd_api.g_miss_char);
      l_header_rec.attribute3 := 'N'; --nvl(p_header_rec.attribute3, 'N');
      l_header_rec.attribute4 := nvl(p_header_rec.attribute4,
			 fnd_api.g_miss_char);
      l_header_rec.attribute5 := nvl(p_header_rec.contractnumber,
			 fnd_api.g_miss_char);
      l_header_rec.attribute6 := nvl(p_header_rec.attribute6,
			 fnd_api.g_miss_char);
      l_header_rec.attribute7 := nvl(p_header_rec.attribute7,
			 fnd_api.g_miss_char);
      l_header_rec.attribute8 := nvl(p_header_rec.attribute8,
			 fnd_api.g_miss_char);
      --  l_header_rec.attribute9  := nvl(p_header_rec.attribute9, --CHG0040236 comment out
      --  fnd_api.g_miss_char);
      l_header_rec.attribute10 := nvl(p_header_rec.attribute10,
			  fnd_api.g_miss_char);
      l_header_rec.attribute11 := nvl(p_header_rec.attribute11,
			  fnd_api.g_miss_char);
      l_header_rec.attribute12 := nvl(p_header_rec.attribute12,
			  fnd_api.g_miss_char);
      l_header_rec.attribute13 := nvl(p_header_rec.attribute13,
			  fnd_api.g_miss_char);
      l_header_rec.attribute14 := nvl(p_header_rec.attribute14,
			  fnd_api.g_miss_char);
      l_header_rec.attribute15 := nvl(p_header_rec.attribute15,
			  fnd_api.g_miss_char);
    
      -- CHG0048217 -- set sold to org id
      BEGIN
        IF p_header_rec.account_number IS NOT NULL THEN
          SELECT cust_account_id
          INTO   l_header_rec.sold_to_org_id
          FROM   hz_cust_accounts ac
          WHERE  ac.account_number = p_header_rec.account_number;
        ELSE
          l_header_rec.sold_to_org_id := p_header_rec.sold_to_org_id;
        END IF;
      EXCEPTION
        WHEN no_data_found THEN
          NULL;
        
      END;
    
      -- end CHG0048217
      -- CHG0040839 set attribute18
    
      BEGIN
        SELECT 'Political'
        INTO   l_header_rec.attribute18
        FROM   hz_cust_accounts hca
        WHERE  hca.cust_account_id = l_header_rec.sold_to_org_id --CHG0048217
	  
        AND    hca.attribute6 = 'Y'
        AND    EXISTS
         (SELECT 1
	    FROM   oe_transaction_types_all ott
	    WHERE  ott.transaction_type_id = l_order_type_id
	    AND    nvl(ott.attribute10, 'N') != 'Y');
      
      EXCEPTION
        WHEN OTHERS THEN
          l_header_rec.attribute18 := fnd_api.g_miss_char;
      END;
      --------------------------------------------------------------------------------------------------------------------
      --  ver  date          name                 desc
      --  1.2  02/07/2015    debarati banerjee    CHG0035705 - Added logic to populated ack email and ship email in additional header info DFF
      ----------------------------------------------------------------------------------------------------------------------
      BEGIN
        l_header_rec.attribute19 := get_ack_email(l_order_type_id,
				  p_header_rec.sold_to_contact_id, -- CHG0045128 added
				  p_header_rec.ship_to_contact_id, -- CHG0045128 added
				  p_header_rec.invoice_to_contact_id); -- CHG0045128 added
      EXCEPTION
        WHEN no_data_found THEN
          l_header_rec.attribute19 := NULL;
        WHEN OTHERS THEN
          g_status         := 'E101';
          g_status_message := g_status_message || chr(13) ||
		      'ERROR: Fetching DFF ACK Email details' || '' ||
		      SQLERRM;
      END;
    
      IF g_status = 'S' THEN
        BEGIN
          l_header_rec.attribute20 := get_ship_email(l_order_type_id,
				     p_header_rec.sold_to_contact_id, -- CHG0045128 added
				     p_header_rec.ship_to_contact_id, -- CHG0045128 added
				     p_header_rec.invoice_to_contact_id); -- CHG0045128 added);
        EXCEPTION
          WHEN no_data_found THEN
	l_header_rec.attribute20 := NULL;
          WHEN OTHERS THEN
	g_status         := 'E101';
	g_status_message := g_status_message || chr(13) ||
		        'ERROR: Fetching DFF Ship Email details' || '' ||
		        SQLERRM;
        END;
      END IF;
    END IF;
  
    IF g_status = 'S' THEN
    
      l_ordered_date1 := to_date(p_header_rec.ordered_date,
		         'DD-MON-YYYY HH24:MI:SS');
      l_ordered_date  := fnd_timezone_pub.adjust_datetime(l_ordered_date1,
				          'GMT',
				          fnd_timezones.get_server_timezone_code);
      --l_ordered_date := fnd_timezone_pub.adjust_datetime(p_header_rec.ordered_date, 'GMT', fnd_timezones.get_server_timezone_code);
    
      l_header_rec.order_number  := p_header_rec.order_number;
      l_header_rec.order_type_id := l_order_type_id;
    
      l_header_rec.ship_to_org_id        := p_header_rec.ship_to_org_id;
      l_header_rec.invoice_to_org_id     := p_header_rec.invoice_to_org_id;
      l_header_rec.ship_to_contact_id    := p_header_rec.ship_to_contact_id;
      l_header_rec.sold_to_contact_id    := p_header_rec.sold_to_contact_id;
      l_header_rec.invoice_to_contact_id := p_header_rec.invoice_to_contact_id;
      l_header_rec.shipping_method_code  := nvl(p_header_rec.shipping_method_code,
				fnd_api.g_miss_char);
      --------------------------------------------------------------------------------------------------------------------
      --  ver  date          name                 desc
      --  1.3 26/10/2015    debarati banerjee    CHG0036623 - Freight _terms_code will be populated with the value coming in
      --                                         Incoterms field for EMEA orders
      ----------------------------------------------------------------------------------------------------------------------
    
      --CHG0040236  - new logic for freight_terms_code
      l_header_rec.freight_terms_code := nvl(p_header_rec.incoterms,
			         p_header_rec.freight_terms_code);
    
      IF p_header_rec.org_id = 96 THEN
        /* l_header_rec.freight_terms_code := nvl(p_header_rec.incoterms,
        fnd_api.g_miss_char);*/
      
        -- CHG0040236 comment out
        --  l_header_rec.freight_terms_code := p_header_rec.incoterms;
        --  l_header_rec.attribute9         := NULL;
      
        --------------------------------------------------------------------------------------------------------------------
        --  ver  date          name                 desc
        --  1.3 16/02/2016    debarati banerjee    CHG0036623 - FOB point code will be populated with the value stored in
        --                                         attribute6 of FREIGHT_TERMS lookup
        ----------------------------------------------------------------------------------------------------------------------
      
        IF l_header_rec.freight_terms_code IS NOT NULL THEN
        
          BEGIN
	l_fob_point_code            := fetch_fob_code(p_lookup_type => 'FREIGHT_TERMS',
				          p_lookup_code => l_header_rec.freight_terms_code);
	l_header_rec.fob_point_code := l_fob_point_code;
          
          EXCEPTION
	WHEN no_data_found THEN
	  g_status         := 'E102';
	  g_status_message := g_status_message || chr(13) ||
		          'VALIDATION ERROR: FOB point code does not exist in DFF';
	WHEN OTHERS THEN
	  g_status         := 'E101';
	  g_status_message := g_status_message || chr(13) ||
		          'Error in fetching FOB point code' ||
		          SQLERRM;
	
          END;
        END IF;
        --CHG0040236 comment out
        --  ELSE
        /*l_header_rec.freight_terms_code    := nvl(p_header_rec.freight_terms_code,
        fnd_api.g_miss_char);*/
        --   l_header_rec.freight_terms_code := p_header_rec.freight_terms_code;
      END IF;
    
      l_header_rec.payment_term_id := nvl(p_header_rec.payment_term_id,
			      fnd_api.g_miss_num);
      l_header_rec.ordered_date    := l_ordered_date;
      /*INC0108633 - Added logic for E commerce orders - trimming spaces
      and illegal chars from the relevant order fields (Customer PO, instructions etc.) */
      l_header_rec.cust_po_number := TRIM(regexp_replace(p_header_rec.cust_po_number,
				         '[[:cntrl]]')); --p_header_rec.cust_po_number; -- INC0108633
      l_header_rec.price_list_id  := p_header_rec.price_list_id;
      --l_header_rec.shipping_instructions := p_header_rec.comments;  -- INC0108633 commented
      -- CHG0044403 added below
      l_is_order_dg := is_order_dg_eligible(p_line_tab,
			        p_header_rec.shipping_method_code);
    
      IF l_is_order_dg = 'N' THEN
        l_header_rec.shipping_instructions := TRIM(regexp_replace(REPLACE(p_header_rec.comments,
						  'DANGEROUS GOOD',
						  ' '),
					      '[[:cntrl]]'));
      ELSE
        -- CHG0044403 end
        l_header_rec.shipping_instructions := TRIM(regexp_replace(p_header_rec.comments,
					      '[[:cntrl]]')); --INC0108633 p_header_rec.comments;
      END IF; -- CHG0044403 end if
    
      l_header_rec.pricing_date     := l_ordered_date;
      l_header_rec.flow_status_code := 'ENTERED';
      --l_header_rec.orig_sys_document_ref := p_header_rec.order_number;   -- CHG0048217 comment
      -- CHG0048217 START - add external ref as orig sys doc ref
      IF p_header_rec.external_ref_number IS NOT NULL THEN
        l_header_rec.orig_sys_document_ref := p_header_rec.external_ref_number;
      ELSE
        l_header_rec.orig_sys_document_ref := p_header_rec.order_number;
      END IF;
      -- CHG0048217 END
    
      --START CHG0039481 Added On 12-OCT-2016 by L.Sarangi
      l_ipay_instrid := p_header_rec.ipay_instrid;
      IF p_header_rec.ipay_instrid IS NOT NULL THEN
      
        IF p_header_rec.ipay_instrid = -999 THEN
          -- Add this to Order Validation
          --This is a New Card Case, need to Register Card in EBS
          xxiby_process_cust_paymt_pkg.create_new_creditcard(p_token               => p_header_rec.ipay_customerrefnum,
					 p_cust_number         => NULL,
					 p_cust_account_id     => l_header_rec.sold_to_org_id, -- CHG0048217
					 p_bill_to_contact_id  => p_header_rec.invoice_to_contact_id,
					 p_org_id              => p_header_rec.org_id,
					 p_bill_to_site_use_id => p_header_rec.invoice_to_org_id,
					 x_instr_id            => l_ipay_instrid,
					 x_chname              => l_header_rec.credit_card_holder_name,
					 x_expiry_date         => l_header_rec.credit_card_expiration_date,
					 x_cc_issuer_code      => l_header_rec.credit_card_code,
					 x_cc_number           => l_header_rec.credit_card_number,
					 x_error_code          => l_err_code,
					 x_error               => l_error);
          IF l_err_code = 1 THEN
	dbms_output.put_line('Error in create_new_creditcard :' ||
		         l_error);
	g_status         := 'E';
	g_status_message := g_status_message || chr(13) || l_error; --added on 21-OCT-2016 CHG0039481
          
	oe_debug_pub.add('New Credit Card Creation Failed in Oracle :' ||
		     l_error);
          ELSE
	dbms_output.put_line('CARD CREATED SUCESSFULLY');
	dbms_output.put_line('l_ipay_Instrid :' || l_ipay_instrid);
	dbms_output.put_line('credit_card_number :' ||
		         l_header_rec.credit_card_number);
	dbms_output.put_line('credit_card_expiration_date :' ||
		         l_header_rec.credit_card_expiration_date);
	dbms_output.put_line('credit_card_code :' ||
		         l_header_rec.credit_card_code);
	dbms_output.put_line('credit_card_holder_name :' ||
		         l_header_rec.credit_card_holder_name);
          
	l_payment_type_code                    := 'CREDIT_CARD';
	l_header_rec.payment_type_code         := 'CREDIT_CARD';
	l_header_rec.credit_card_approval_code := p_header_rec.ipay_approvalcode;
	l_header_rec.credit_card_approval_date := trunc(SYSDATE);
          
          END IF;
        
        ELSE
          --Existing Credit Card Case
          BEGIN
	SELECT ibycc.ccnumber,
	       ibycc.chname,
	       ibycc.card_issuer_code,
	       ibycc.expirydate
	INTO   l_header_rec.credit_card_number,
	       l_header_rec.credit_card_holder_name,
	       l_header_rec.credit_card_code,
	       l_header_rec.credit_card_expiration_date
	FROM   iby_creditcard ibycc
	WHERE  1 = 1
	AND    ibycc.instrid = p_header_rec.ipay_instrid;
          
	l_payment_type_code                    := 'CREDIT_CARD';
	l_header_rec.payment_type_code         := 'CREDIT_CARD';
	l_header_rec.credit_card_approval_code := p_header_rec.ipay_approvalcode;
	l_header_rec.credit_card_approval_date := trunc(SYSDATE);
          EXCEPTION
	WHEN OTHERS THEN
	  dbms_output.put_line('error during credit card info fetch :' ||
		           SQLERRM);
          END;
        
        END IF;
      END IF;
      --END CHG0039481 On 12-OCT-2016 by L.Sarangi
    
      --------------------------------------------------------------------------------------------------------------------
      --  ver  date          name                 desc
      --  1.3 26/10/2015    debarati banerjee    CHG0036623 - Salesperson to be derived from Defaulting Rules setup
      ----------------------------------------------------------------------------------------------------------------------
      --l_header_rec.SALESREP_ID           := p_header_rec.salesrep_id;
    
      --------------------------------------------------------------------------------------------------------------------
      --  ver  date          name                 desc
      --  1.3 26/10/2015    debarati banerjee    CHG0036623 - Added logic for partial shipment functionality
      ----------------------------------------------------------------------------------------------------------------------
    
      IF p_header_rec.splitorder = 'Y' THEN
        l_ship_set_id                             := NULL;
        l_header_rec.customer_preference_set_code := NULL;
      ELSE
        l_ship_set_id := fnd_api.g_miss_num;
      END IF;
    
      BEGIN
        l_header_rec.order_source_id := get_source_id(p_source_name => p_header_rec.order_source_name);
      
      EXCEPTION
        WHEN no_data_found THEN
          g_status         := 'E100';
          g_status_message := g_status_message || chr(13) ||
		      'ERROR: Source' || '' ||
		      p_header_rec.order_source_name || '' ||
		      'does not exist';
        WHEN OTHERS THEN
          g_status         := 'E101';
          g_status_message := g_status_message || chr(13) ||
		      'ERROR: Fetching Source Details' || '' ||
		      SQLERRM;
      END;
    
    END IF;
  
    IF g_status = 'S' THEN
    
      BEGIN
        l_order_type := get_order_type_name(l_order_type_id);
      
      EXCEPTION
        WHEN no_data_found THEN
          g_status         := 'E100';
          g_status_message := g_status_message || chr(13) ||
		      'ERROR: Transaction type does not exist';
        WHEN OTHERS THEN
          g_status         := 'E101';
          g_status_message := g_status_message || chr(13) ||
		      'ERROR: Fetching Order Type Name' || '' ||
		      SQLERRM;
      END;
    
    END IF;
  
    -- context
  
    IF g_status = 'S' THEN
      BEGIN
      
        SELECT con.descriptive_flex_context_code
        INTO   l_header_rec.context
        FROM   fnd_descr_flex_contexts_vl con,
	   fnd_application_vl         fav
        WHERE  con.descriptive_flex_context_code = l_order_type
        AND    fav.application_id = con.application_id
        AND    con.enabled_flag = 'Y'
        AND    fav.application_name = 'Order Management'
        AND    con.descriptive_flexfield_name = 'OE_HEADER_ATTRIBUTES';
      
      EXCEPTION
        WHEN OTHERS THEN
          g_status         := 'E';
          g_status_message := g_status_message || chr(13) ||
		      'Error setting Context' || '' || SQLERRM;
        
      END;
    
    END IF;
  
    --------------------------------------------------------------------------------------------------------------------
    --  ver  date         name                      desc
    --  1.3 10/27/2017    Diptasurjya Chatterjee    CHG0041715 - Added logic for promo code
    ----------------------------------------------------------------------------------------------------------------------
  
    /* CHG0041715 - Start adding header pricing attribute details for promo code */
    IF p_header_rec.ask_for_modifier_name IS NOT NULL AND g_status = 'S' THEN
      BEGIN
        SELECT qlh.list_header_id
        INTO   l_modifier_id
        FROM   qp_list_headers_all qlh
        WHERE  qlh.name = p_header_rec.ask_for_modifier_name;
      EXCEPTION
        WHEN no_data_found THEN
          g_status         := 'E';
          g_status_message := g_status_message || chr(13) ||
		      'Invalid promo code provided';
        WHEN OTHERS THEN
          g_status         := 'E';
          g_status_message := g_status_message || chr(13) ||
		      'Error: While fetching promo code ID. ' ||
		      SQLERRM;
      END;
    
      IF l_modifier_id IS NOT NULL THEN
        l_header_prc_att_tbl(1) := oe_order_pub.g_miss_header_price_att_rec;
        l_header_prc_att_tbl(1).flex_title := 'QP_ATTR_DEFNS_QUALIFIER';
        l_header_prc_att_tbl(1).pricing_context := 'MODLIST';
        l_header_prc_att_tbl(1).pricing_attribute1 := l_modifier_id;
        l_header_prc_att_tbl(1).operation := oe_globals.g_opr_create;
      END IF;
    END IF;
    /* CHG0041715 - End adding header pricing attribute details for promo code  */
  
    --------------------------------------------------------------------------------------------------------------------
    --  ver  date          name                 desc
    --  1.3 26/10/2015    debarati banerjee    CHG0036623 - Added logic for order booking
    ----------------------------------------------------------------------------------------------------------------------
  
    ---Book the order if splitorder flag='N' and mapping value='BOOKED'
  
    IF nvl(p_header_rec.splitorder, 'N') = 'N' THEN
      IF upper(l_order_state) = 'BOOKED' THEN
        l_action_request_tbl(1) := oe_order_pub.g_miss_request_rec;
        l_action_request_tbl(1).request_type := oe_globals.g_book_order;
        l_action_request_tbl(1).entity_code := oe_globals.g_entity_header;
      END IF;
    END IF;
  
    IF g_status = 'S' THEN
      --set line variables
      FOR i IN 1 .. p_line_tab.count
      LOOP
      
        l_line_tbl(i) := oe_order_pub.g_miss_line_rec;
        l_line_tbl(i).operation := oe_globals.g_opr_create;
        --(i).line_number := i;
        --l_line_tbl(i).tax_code := 'SSUS_TAX_RATE';
        ----l_line_tbl(i).tax_date:= sysdate;
        --l_line_tbl(i).line_number := p_line_tab(i).line_number;
      
        --CHG0048217
        IF p_line_tab(i).item_code IS NOT NULL THEN
          l_line_tbl(i).inventory_item_id := xxinv_utils_pkg.get_item_id(p_line_tab(i)
						 .item_code);
        ELSE
        
          l_line_tbl(i).inventory_item_id := p_line_tab(i).inventory_item_id;
        END IF;
      
        IF p_line_tab(i).external_ref_number IS NOT NULL THEN
          l_line_tbl(i).orig_sys_line_ref := p_line_tab(i)
			         .external_ref_number;
        END IF;
        --end CHG0048217
        l_line_tbl(i).ordered_quantity := p_line_tab(i).ordered_quantity;
        l_line_tbl(i).unit_selling_price := p_line_tab(i).unit_selling_price;
        l_line_tbl(i).unit_list_price := p_line_tab(i).unit_list_price;
        l_line_tbl(i).tax_value := p_line_tab(i).tax_value;
        l_line_tbl(i).calculate_price_flag := 'N';
        l_line_tbl(i).ship_set_id := l_ship_set_id;
        -- l_line_tbl(i).line_type_id      := get_line_type_id(p_line_tab(i).ordered_quantity,l_pos_line_type_id,l_neg_line_type_id );
      
        --set line level DFF attributes
      
        l_line_tbl(i).attribute1 := nvl(p_line_tab(i).attribute1,
			    fnd_api.g_miss_char);
        l_line_tbl(i).attribute2 := nvl(p_line_tab(i).attribute2,
			    fnd_api.g_miss_char);
        l_line_tbl(i).attribute3 := nvl(p_line_tab(i).attribute3,
			    fnd_api.g_miss_char);
        l_line_tbl(i).attribute4 := nvl(p_line_tab(i).attribute4,
			    fnd_api.g_miss_char);
        l_line_tbl(i).attribute5 := nvl(p_line_tab(i).attribute5,
			    fnd_api.g_miss_char);
        l_line_tbl(i).attribute6 := nvl(p_line_tab(i).attribute6,
			    fnd_api.g_miss_char);
        l_line_tbl(i).attribute7 := nvl(p_line_tab(i).attribute7,
			    fnd_api.g_miss_char);
        l_line_tbl(i).attribute8 := nvl(p_line_tab(i).attribute8,
			    fnd_api.g_miss_char);
        l_line_tbl(i).attribute9 := nvl(p_line_tab(i).attribute9,
			    fnd_api.g_miss_char);
        l_line_tbl(i).attribute10 := nvl(p_line_tab(i).attribute10,
			     fnd_api.g_miss_char);
        l_line_tbl(i).attribute11 := nvl(p_line_tab(i).attribute11,
			     fnd_api.g_miss_char);
        l_line_tbl(i).attribute12 := nvl(p_line_tab(i).attribute12,
			     fnd_api.g_miss_char);
        l_line_tbl(i).attribute13 := nvl(p_line_tab(i).attribute13,
			     fnd_api.g_miss_char);
        l_line_tbl(i).attribute14 := nvl(p_line_tab(i).attribute14,
			     fnd_api.g_miss_char);
        l_line_tbl(i).attribute15 := nvl(p_line_tab(i).attribute15,
			     fnd_api.g_miss_char);
      
        -- CHG0045755 start PTO BOM change
        IF is_item_bom_type_valid(l_line_tbl(i).inventory_item_id /*p_line_tab(i).inventory_item_id*/) = 'Y' THEN
          -- CHG0048217 support item code
          l_line_tbl(i).top_model_line_index := i;
        END IF;
        -- CHG0045755 end
      
        j := j + 1;
      
      END LOOP;
    
      -- CHG0045755 start PTO BOM explode
      FOR ii IN 1 .. l_line_tbl.count
      LOOP
      
        IF is_item_bom_type_valid(l_line_tbl(ii).inventory_item_id) = 'Y' THEN
          FOR rec_model IN cur_model_items(l_line_tbl(ii).inventory_item_id)
          LOOP
	l_line_tbl(j) := oe_order_pub.g_miss_line_rec;
	l_line_tbl(j).operation := oe_globals.g_opr_create;
	l_line_tbl(j).inventory_item_id := rec_model.component_item_id;
	l_line_tbl(j).ordered_quantity := rec_model.component_quantity * l_line_tbl(ii)
			         .ordered_quantity;
	l_line_tbl(j).top_model_line_index := ii;
	l_line_tbl(j).link_to_line_index := ii;
          
	j := j + 1;
          END LOOP;
        END IF;
      END LOOP;
      -- CHG0045755 end
    
      ---Add Freight as a line
      IF p_header_rec.freightcost IS NOT NULL AND
         p_header_rec.freightcost > 0 THEN
      
        l_line_tbl(j) := oe_order_pub.g_miss_line_rec;
        l_line_tbl(j).operation := oe_globals.g_opr_create;
        --l_line_tbl(j).line_number := l_max_line_number+1;
      
        BEGIN
          l_line_tbl(j).inventory_item_id := get_inv_item_id('FREIGHT');
        EXCEPTION
          WHEN no_data_found THEN
	g_status         := 'E100';
	g_status_message := 'Item' || '' || 'not found';
          WHEN OTHERS THEN
	g_status         := 'E101';
	g_status_message := g_status_message || chr(13) ||
		        'Error Fetching Item details' || '' ||
		        SQLERRM;
        END;
      
        l_line_tbl(j).ordered_quantity := 1;
        l_line_tbl(j).unit_selling_price := p_header_rec.freightcost;
        l_line_tbl(j).unit_list_price := 0;
        l_line_tbl(j).tax_value := p_header_rec.freightcosttax;
        l_line_tbl(j).calculate_price_flag := 'N';
        --l_line_tbl(j).line_type_id      := get_line_type_id(l_line_tbl(j).ordered_quantity,l_pos_line_type_id,l_neg_line_type_id );
      
      END IF;
    END IF;
  
    IF g_status = 'S' THEN
    
      --FOR i IN 1..p_adjustment_tab.count
      --LOOP
      FOR i IN c_adjustment
      LOOP
        l_adj_inx         := c_adjustment%ROWCOUNT;
        l_line_index_calc := 1;
      
        IF i.adjustment_level = 'HEADER' THEN
          l_header_adj_tbl(l_adj_inx) := oe_order_pub.g_miss_header_adj_rec;
        
          l_header_adj_tbl(l_adj_inx).list_header_id := i.list_header_id;
          l_header_adj_tbl(l_adj_inx).list_line_id := i.list_line_id;
          l_header_adj_tbl(l_adj_inx).applied_flag := i.applied_flag;
          l_header_adj_tbl(l_adj_inx).automatic_flag := i.automatic_flag;
          --l_header_adj_tbl(i).orig_sys_discount_ref := 'SSYS_ECOM_PRICE_ADJUSTMENTS'||p_adjustment_tab(i).line_number;
          l_header_adj_tbl(l_adj_inx).list_line_type_code := i.list_type_code;
          l_header_adj_tbl(l_adj_inx).update_allowed := i.update_allowed;
          l_header_adj_tbl(l_adj_inx).updated_flag := i.updated_flag;
          l_header_adj_tbl(l_adj_inx).operand := i.operand;
          l_header_adj_tbl(l_adj_inx).adjusted_amount := i.adjusted_amount;
          l_header_adj_tbl(l_adj_inx).adjusted_amount_per_pqty := i.adjusted_amount;
          l_header_adj_tbl(l_adj_inx).range_break_quantity := i.line_quantity;
          l_header_adj_tbl(l_adj_inx).operand_per_pqty := i.operand;
          l_header_adj_tbl(l_adj_inx).pricing_phase_id := i.pricing_phase_id;
          l_header_adj_tbl(l_adj_inx).accrual_flag := i.accrual_flag;
          l_header_adj_tbl(l_adj_inx).source_system_code := 'QP';
          l_header_adj_tbl(l_adj_inx).modifier_level_code := i.modifier_level_code;
          l_header_adj_tbl(l_adj_inx).price_break_type_code := i.price_break_type_code;
          l_header_adj_tbl(l_adj_inx).arithmetic_operator := i.operand_calculation_code;
          l_header_adj_tbl(l_adj_inx).operation := oe_globals.g_opr_create;
        
        ELSIF i.adjustment_level = 'LINE' THEN
          l_line_adj_tbl(l_adj_inx) := oe_order_pub.g_miss_line_adj_rec;
          l_line_adj_tbl(l_adj_inx).line_index := NULL;
        
          FOR j IN 1 .. p_line_tab.count
          LOOP
	IF i.line_num = p_line_tab(j).line_number AND l_line_adj_tbl(l_adj_inx)
	  .line_index IS NULL THEN
	  l_line_adj_tbl(l_adj_inx).line_index := l_line_index_calc;
	  EXIT;
	END IF;
          
	l_line_index_calc := l_line_index_calc + 1;
          END LOOP;
        
          l_line_adj_tbl(l_adj_inx).list_header_id := i.list_header_id;
          l_line_adj_tbl(l_adj_inx).list_line_id := i.list_line_id;
          l_line_adj_tbl(l_adj_inx).applied_flag := i.applied_flag;
        
          l_line_adj_tbl(l_adj_inx).automatic_flag := i.automatic_flag;
          l_line_adj_tbl(l_adj_inx).orig_sys_discount_ref := 'SSYS_ECOM_PRICE_ADJUSTMENTS' ||
					 i.line_num;
          l_line_adj_tbl(l_adj_inx).list_line_type_code := i.list_type_code;
          l_line_adj_tbl(l_adj_inx).update_allowed := i.update_allowed;
          l_line_adj_tbl(l_adj_inx).updated_flag := i.updated_flag;
          l_line_adj_tbl(l_adj_inx).operand := i.operand;
          --l_line_adj_tbl(i).arithmetic_operator := p_adjustment_tab(i).;
          l_line_adj_tbl(l_adj_inx).adjusted_amount := i.adjusted_amount;
          l_line_adj_tbl(l_adj_inx).adjusted_amount_per_pqty := i.adjusted_amount;
          l_line_adj_tbl(l_adj_inx).range_break_quantity := i.line_quantity;
          l_line_adj_tbl(l_adj_inx).operand_per_pqty := i.operand;
          l_line_adj_tbl(l_adj_inx).pricing_phase_id := i.pricing_phase_id;
          l_line_adj_tbl(l_adj_inx).accrual_flag := i.accrual_flag;
          --l_line_adj_tbl(i).list_line_no := v_list_line_id;
          l_line_adj_tbl(l_adj_inx).source_system_code := 'QP';
          l_line_adj_tbl(l_adj_inx).modifier_level_code := i.modifier_level_code;
          l_line_adj_tbl(l_adj_inx).price_break_type_code := i.price_break_type_code;
          l_line_adj_tbl(l_adj_inx).arithmetic_operator := i.operand_calculation_code;
          --l_line_adj_tbl(i).proration_type_code := 'N';
          --l_line_adj_tbl(i).operand_per_pqty := v_operand;
          --l_line_adj_tbl(i).adjusted_amount_per_pqty := -v_operand;
        
          l_line_adj_tbl(l_adj_inx).operation := oe_globals.g_opr_create;
        
        END IF;
      
      END LOOP;
    
      --FOR i IN 1..p_adj_attrib_tab.count
      FOR i IN c_attributes
      LOOP
        l_att_inx := c_attributes%ROWCOUNT;
        --LOOP
        --Debarati
        IF i.adjustment_level = 'HEADER' THEN
          l_header_adj_attrib_tbl(l_att_inx) := oe_order_pub.g_miss_header_adj_att_rec;
        
          l_adj_index_hdr_calc := 1;
        
          IF i.context_type = 'PRICING_ATTRIBUTE' THEN
	l_header_adj_attrib_tbl(l_att_inx).flex_title := 'QP_ATTR_DEFNS_PRICING';
          ELSE
	l_header_adj_attrib_tbl(l_att_inx).flex_title := 'QP_ATTR_DEFNS_QUALIFIER';
          END IF;
        
          l_header_adj_attrib_tbl(l_att_inx).adj_index := NULL;
        
          --FOR j IN 1..p_adjustment_tab.count
          --LOOP
        
          FOR j IN c_adjustment
          LOOP
	IF i.line_adj_num = j.line_adj_num AND l_header_adj_attrib_tbl(l_att_inx)
	  .adj_index IS NULL THEN
	  l_header_adj_attrib_tbl(l_att_inx).adj_index := l_adj_index_hdr_calc;
	END IF;
          
	IF l_header_adj_attrib_tbl(l_att_inx).adj_index IS NOT NULL THEN
	  EXIT;
	END IF;
          
	l_adj_index_hdr_calc := l_adj_index_hdr_calc + 1;
          
          END LOOP;
        
          dbms_output.put_line('Start attrib hdr: ' || l_header_adj_attrib_tbl(l_att_inx)
		       .adj_index);
          -- l_header_adj_attrib_tbl(i).adj_index := p_adj_attrib_tab(i).line_adj_num;
        
          l_header_adj_attrib_tbl(l_att_inx).pricing_context := i.context;
          l_header_adj_attrib_tbl(l_att_inx).pricing_attribute := i.attribute_col;
          l_header_adj_attrib_tbl(l_att_inx).pricing_attr_value_from := i.attr_value_from;
          l_header_adj_attrib_tbl(l_att_inx).pricing_attr_value_to := i.attr_value_to;
          l_header_adj_attrib_tbl(l_att_inx).comparison_operator := i.qual_comp_operator_code;
          l_header_adj_attrib_tbl(l_att_inx).operation := oe_globals.g_opr_create;
        
        ELSIF i.adjustment_level = 'LINE' THEN
          --Debarati
          l_adj_index_calc := 1;
        
          l_line_adj_attrib_tbl(l_att_inx) := oe_order_pub.g_miss_line_adj_att_rec;
        
          IF i.context_type = 'PRICING_ATTRIBUTE' THEN
	l_line_adj_attrib_tbl(l_att_inx).flex_title := 'QP_ATTR_DEFNS_PRICING';
          ELSE
	l_line_adj_attrib_tbl(l_att_inx).flex_title := 'QP_ATTR_DEFNS_QUALIFIER';
          
          END IF;
        
          l_line_adj_attrib_tbl(l_att_inx).adj_index := NULL;
        
          --FOR j IN 1..p_adjustment_tab.count
          --LOOP
          FOR j IN c_adjustment
          LOOP
	IF i.line_adj_num = j.line_adj_num AND l_line_adj_attrib_tbl(l_att_inx)
	  .adj_index IS NULL THEN
	  l_line_adj_attrib_tbl(l_att_inx).adj_index := l_adj_index_calc;
	END IF;
          
	IF l_line_adj_attrib_tbl(l_att_inx).adj_index IS NOT NULL THEN
	  EXIT;
	END IF;
          
	l_adj_index_calc := l_adj_index_calc + 1;
          END LOOP;
        
          l_line_adj_attrib_tbl(l_att_inx).pricing_context := i.context;
          l_line_adj_attrib_tbl(l_att_inx).pricing_attribute := i.attribute_col;
          l_line_adj_attrib_tbl(l_att_inx).pricing_attr_value_from := i.attr_value_from;
          l_line_adj_attrib_tbl(l_att_inx).pricing_attr_value_to := i.attr_value_to;
          l_line_adj_attrib_tbl(l_att_inx).comparison_operator := i.qual_comp_operator_code;
          l_line_adj_attrib_tbl(l_att_inx).operation := oe_globals.g_opr_create;
        
          --Debarati
        END IF;
        --Debarati
      END LOOP;
    
      --DBMS_OUTPUT.PUT_LINE('Start Assoc 1: '||p_adjustment_assoc_tab.count);
    
      --FOR i IN 1..p_adjustment_assoc_tab.count
      --LOOP
      FOR i IN c_assoc
      LOOP
        l_assoc_inx := c_assoc%ROWCOUNT;
        IF i.adjustment_level = 'LINE' THEN
        
          l_adj_index_calc  := 1;
          l_line_index_calc := 1;
        
          l_line_adj_assoc_tbl(l_assoc_inx) := oe_order_pub.g_miss_line_adj_assoc_rec;
          l_line_adj_assoc_tbl(l_assoc_inx).line_index := NULL;
        
          FOR j IN 1 .. p_line_tab.count
          LOOP
          
	IF i.line_num = p_line_tab(j).line_number AND l_line_adj_assoc_tbl(l_assoc_inx)
	  .line_index IS NULL THEN
	  l_line_adj_assoc_tbl(l_assoc_inx).line_index := l_line_index_calc;
	  EXIT;
	END IF;
          
	l_line_index_calc := l_line_index_calc + 1;
          END LOOP;
        
          dbms_output.put_line('Start Assoc 2: ' || l_line_adj_assoc_tbl(l_assoc_inx)
		       .line_index);
        
          l_line_adj_assoc_tbl(l_assoc_inx).adj_index := NULL;
          l_line_adj_assoc_tbl(l_assoc_inx).rltd_adj_index := NULL;
        
          -- FOR j IN 1..p_adjustment_tab.count
          --LOOP
          FOR j IN c_adjustment
          LOOP
          
	IF i.line_adj_num = j.line_adj_num AND l_line_adj_assoc_tbl(l_assoc_inx)
	  .adj_index IS NULL THEN
	  l_line_adj_assoc_tbl(l_assoc_inx).adj_index := l_adj_index_calc;
	END IF;
          
	IF i.related_line_adj_num = j.line_adj_num AND l_line_adj_assoc_tbl(l_assoc_inx)
	  .rltd_adj_index IS NULL THEN
	  l_line_adj_assoc_tbl(l_assoc_inx).rltd_adj_index := l_adj_index_calc;
	END IF;
          
	IF l_line_adj_assoc_tbl(l_assoc_inx)
	 .adj_index IS NOT NULL AND l_line_adj_assoc_tbl(l_assoc_inx)
	   .rltd_adj_index IS NOT NULL THEN
	  EXIT;
	END IF;
          
	l_adj_index_calc := l_adj_index_calc + 1;
          END LOOP;
        
          dbms_output.put_line('Start Assoc 3: ' || l_line_adj_assoc_tbl(l_assoc_inx)
		       .adj_index || ' ' || l_line_adj_assoc_tbl(l_assoc_inx)
		       .rltd_adj_index);
        
          l_line_adj_assoc_tbl(l_assoc_inx).operation := oe_globals.g_opr_create;
        
        END IF;
      
      END LOOP;
    
    END IF;
  
    IF g_status = 'S' THEN
    
      dbms_output.put_line('END ');
      IF p_debug_flag = 'Y' THEN
        dbms_output.put_line('Entering OE_ORDER_PUB.Process_Order  Api' ||
		     'for Order Number ' ||
		     p_header_rec.order_number);
      END IF;
    
      --dbms_output.put_line('Entering OE_ORDER_PUB.Process_Order  Api' ||
      -- to_char(SYSDATE, 'hh24:mi:ss'));
    
      oe_order_pub.process_order(p_api_version_number   => l_api_version_number,
		         p_header_rec           => l_header_rec,
		         p_line_tbl             => l_line_tbl,
		         p_action_request_tbl   => l_action_request_tbl,
		         p_header_adj_tbl       => l_header_adj_tbl,
		         p_header_price_att_tbl => l_header_prc_att_tbl, -- CHG0041715 - for ask for modifier
		         p_line_adj_tbl         => l_line_adj_tbl,
		         p_line_adj_assoc_tbl   => l_line_adj_assoc_tbl,
		         p_header_adj_att_tbl   => l_header_adj_attrib_tbl,
		         p_line_adj_att_tbl     => l_line_adj_attrib_tbl,
		         --OUT variables
		         x_header_rec             => l_header_rec_out,
		         x_header_val_rec         => l_header_val_rec_out,
		         x_header_adj_tbl         => l_header_adj_tbl_out,
		         x_header_adj_val_tbl     => l_header_adj_val_tbl_out,
		         x_header_price_att_tbl   => l_header_price_att_tbl_out,
		         x_header_adj_att_tbl     => l_header_adj_att_tbl_out,
		         x_header_adj_assoc_tbl   => l_header_adj_assoc_tbl_out,
		         x_header_scredit_tbl     => l_header_scredit_tbl_out,
		         x_header_scredit_val_tbl => l_header_scredit_val_tbl_out,
		         x_line_tbl               => l_line_tbl_out,
		         x_line_val_tbl           => l_line_val_tbl_out,
		         x_line_adj_tbl           => l_line_adj_tbl_out,
		         x_line_adj_val_tbl       => l_line_adj_val_tbl_out,
		         x_line_price_att_tbl     => l_line_price_att_tbl_out,
		         x_line_adj_att_tbl       => l_line_adj_att_tbl_out,
		         x_line_adj_assoc_tbl     => l_line_adj_assoc_tbl_out,
		         x_line_scredit_tbl       => l_line_scredit_tbl_out,
		         x_line_scredit_val_tbl   => l_line_scredit_val_tbl_out,
		         x_lot_serial_tbl         => l_lot_serial_tbl_out,
		         x_lot_serial_val_tbl     => l_lot_serial_val_tbl_out,
		         x_action_request_tbl     => l_action_request_tbl_out,
		         --x_Header_Payment_tbl     => l_header_payment_tbl, -- added for CHG0039481
		         x_return_status => l_return_status,
		         x_msg_count     => l_msg_count,
		         x_msg_data      => l_msg_data);
    
      --dbms_output.put_line('Order Number='|| l_line_tbl_out.order_number);
      -- g_status := l_return_status;
      -- g_status_message := g_status_message||CHR(13)||l_msg_data;
      FOR i IN 1 .. l_msg_count
      LOOP
        oe_msg_pub.get(p_msg_index     => i,
	           p_encoded       => fnd_api.g_false,
	           p_data          => l_data,
	           p_msg_index_out => l_msg_index);
        dbms_output.put_line('Msg ' || l_data);
      END LOOP;
    
      dbms_output.put_line('Error Msg Count' || l_msg_count);
      dbms_output.put_line('Error Msg' || l_msg_data || '-' || l_msg_count);
    
      IF l_return_status = fnd_api.g_ret_sts_success THEN
        dbms_output.put_line('Return status is success');
        --dbms_output.put_line('l_debug_level '||l_debug_level);
      
        p_order_status    := 'SUCCESS';
        p_order_header_id := l_header_rec_out.header_id;
        p_order_number    := l_header_rec_out.order_number;
        p_err_code        := 'S';
        p_err_message     := l_msg_data;
        dbms_output.put_line('Order Number=' ||
		     l_header_rec_out.order_number);
      
        /* CHG0044725 - Start call to create CC authorization */
        /* To be called only if order is created in ENTERED state and is a CC order */
        dbms_output.put_line(upper(l_order_state));
        IF upper(l_order_state) = 'ENTERED' AND
           p_header_rec.ipay_instrid IS NOT NULL THEN
          create_cc_authorization(p_header_rec    => p_header_rec,
		          p_header_id     => p_order_header_id,
		          p_ipay_instr_id => l_ipay_instrid,
		          p_debug_flag    => p_debug_flag,
		          p_err_code      => l_cc_auth_err_code,
		          p_err_message   => l_cc_auth_err_msg);
        
          IF l_cc_auth_err_code <> 'S' THEN
	p_order_status   := 'FAILED';
	g_status         := 'E101';
	p_err_code       := 'E101';
	p_err_message    := 'Oracle CC Auth API ERROR: ' ||
		        l_cc_auth_err_msg || '.' ||
		        ' For details please ask Oracle EBS OM team to check debug log located at - ' ||
		        g_debug_file_name;
	g_status_message := 'Oracle CC Auth API ERROR: ' ||
		        l_cc_auth_err_msg || '.' ||
		        ' For details please ask Oracle EBS OM team to check debug log located at - ' ||
		        g_debug_file_name;
	ROLLBACK;
          
	RETURN;
          END IF;
        END IF;
        /* CHG0044725 - End CC authorization call */
      
        ----------------------------------------------------------------------------------------------------------------
        --  ver  date          name                 desc
        --  1.3 26/10/2015    debarati banerjee    CHG0036623 - Added logic for order booking and partial shipment functionality
        ----------------------------------------------------------------------------------------------------------------------
      
        --set ship set null if splitorder flag= 'Y'
      
        IF p_header_rec.splitorder = 'Y' THEN
          BEGIN
	l_header_rec_upd.customer_preference_set_code := NULL;
	FOR i IN c_lines(p_order_header_id)
	LOOP
	  l_inx := c_lines%ROWCOUNT;
	  l_line_tbl_upd(l_inx) := oe_order_pub.g_miss_line_rec;
	  l_line_tbl_upd(l_inx).ship_set_id := NULL;
	  l_line_tbl_upd(l_inx).line_id := i.line_id;
	  -- l_line_tbl_upd(i).change_reason := 'Not provided';
	  l_line_tbl_upd(l_inx).operation := oe_globals.g_opr_update;
	END LOOP;
          
	IF upper(l_order_state) = 'BOOKED' THEN
	  --Book order
	  l_action_request_tbl_upd(1) := oe_order_pub.g_miss_request_rec;
	  l_action_request_tbl_upd(1).request_type := oe_globals.g_book_order;
	  l_action_request_tbl_upd(1).entity_code := oe_globals.g_entity_header;
	  l_action_request_tbl_upd(1).entity_id := p_order_header_id;
	END IF;
          
	-- CALL TO PROCESS ORDER
	oe_order_pub.process_order(p_api_version_number     => 1.0,
			   p_header_rec             => l_header_rec_upd,
			   p_line_tbl               => l_line_tbl_upd,
			   p_action_request_tbl     => l_action_request_tbl_upd,
			   p_init_msg_list          => fnd_api.g_false,
			   p_return_values          => fnd_api.g_false,
			   p_action_commit          => fnd_api.g_false,
			   x_header_rec             => l_header_rec_out,
			   x_header_val_rec         => l_header_val_rec_out,
			   x_header_adj_tbl         => l_header_adj_tbl_out,
			   x_header_adj_val_tbl     => l_header_adj_val_tbl_out,
			   x_header_price_att_tbl   => l_header_price_att_tbl_out,
			   x_header_adj_att_tbl     => l_header_adj_att_tbl_out,
			   x_header_adj_assoc_tbl   => l_header_adj_assoc_tbl_out,
			   x_header_scredit_tbl     => l_header_scredit_tbl_out,
			   x_header_scredit_val_tbl => l_header_scredit_val_tbl_out,
			   x_line_tbl               => l_line_tbl_out,
			   x_line_val_tbl           => l_line_val_tbl_out,
			   x_line_adj_tbl           => l_line_adj_tbl_out,
			   x_line_adj_val_tbl       => l_line_adj_val_tbl_out,
			   x_line_price_att_tbl     => l_line_price_att_tbl_out,
			   x_line_adj_att_tbl       => l_line_adj_att_tbl_out,
			   x_line_adj_assoc_tbl     => l_line_adj_assoc_tbl_out,
			   x_line_scredit_tbl       => l_line_scredit_tbl_out,
			   x_line_scredit_val_tbl   => l_line_scredit_val_tbl_out,
			   x_lot_serial_tbl         => l_lot_serial_tbl_out,
			   x_lot_serial_val_tbl     => l_lot_serial_val_tbl_out,
			   x_action_request_tbl     => l_action_request_tbl_out,
			   x_return_status          => l_return_status1,
			   x_msg_count              => l_msg_count1,
			   x_msg_data               => l_msg_data1);
	IF l_return_status1 = fnd_api.g_ret_sts_success THEN
	  dbms_output.put_line('Order updated successfully');
	  --dbms_output.put_line('l_debug_level '||l_debug_level);
	
	  p_order_status := 'SUCCESS';
	  p_err_code     := 'S';
	  p_err_message  := l_msg_data1;
	
	  update_pricing_tables(p_cartid         => p_header_rec.cartid,
			p_flag           => 'Y',
			p_request_source => p_request_source,
			-- g_status         => g_status,
			g_status_message1 => g_status_message1,
			g_status1         => g_status1);
	
	  --COMMIT;
	
	ELSE
	  --order not updated successfully
	  p_order_status := 'FAILED';
	  --dbms_output.put_line('Error Msg' || g_status_message);
	
	  FOR i IN 1 .. l_msg_count1
	  LOOP
	    oe_msg_pub.get(p_msg_index     => i,
		       p_encoded       => fnd_api.g_false,
		       p_data          => l_data,
		       p_msg_index_out => l_msg_index);
	    dbms_output.put_line('Msg ' || l_data);
	    dbms_output.put_line('Msg index ' || l_msg_index);
	    --p_err_message :=  l_data;
	  
	  END LOOP;
	  g_status         := 'E101';
	  p_err_code       := 'E101';
	  p_err_message    := 'Oracle API ERROR: ' || l_data || '.' ||
		          ' For details please ask Oracle EBS OM team to check debug log located at - ' ||
		          g_debug_file_name;
	  g_status_message := 'Oracle API ERROR: ' || l_data || '.' ||
		          ' For details please ask Oracle EBS OM team to check debug log located at - ' ||
		          g_debug_file_name;
	
	  ROLLBACK;
	
	  update_pricing_tables(p_cartid         => p_header_rec.cartid,
			p_flag           => 'E',
			p_request_source => p_request_source,
			--g_status         => g_status,
			g_status_message1 => g_status_message1,
			g_status1         => g_status1);
	
	END IF;
          END;
        END IF; -- splitorder flag=Y
        /*ELSE --splitorder flag=N
          update_pricing_tables(p_cartid         => p_header_rec.cartid,
                            p_flag           => 'Y',
                           -- g_status         => g_status,
                            g_status_message1 => g_status_message1,
                            g_status1        => g_status1);                       --commit;
        END IF;*/
      
        generate_order_output(p_header_id => p_order_header_id,
		      x_order     => x_header_rec,
		      x_lines     => x_line_tab); --CHG0048217 - CTASK0049292 add output generation call
      ELSE
        --order not created successfully
      
        dbms_output.put_line('Return status failure');
        p_order_status := 'FAILED';
        --dbms_output.put_line('Error Msg' || g_status_message);
      
        FOR i IN 1 .. l_msg_count
        LOOP
          oe_msg_pub.get(p_msg_index     => i,
		 p_encoded       => fnd_api.g_false,
		 p_data          => l_data,
		 p_msg_index_out => l_msg_index);
          dbms_output.put_line('Msg ' || l_data);
          dbms_output.put_line('Msg index ' || l_msg_index);
          --p_err_message :=  l_data;
        
        END LOOP;
        g_status         := 'E101';
        p_err_code       := 'E101';
        p_err_message    := 'Oracle API ERROR: ' || l_data || '.' ||
		    ' For details please ask Oracle EBS OM team to check debug log located at - ' ||
		    g_debug_file_name;
        g_status_message := 'Oracle API ERROR: ' || l_data || '.' ||
		    ' For details please ask Oracle EBS OM team to check debug log located at - ' ||
		    g_debug_file_name;
      
        ROLLBACK;
        --update pricing tables
        update_pricing_tables(p_cartid         => p_header_rec.cartid,
		      p_flag           => 'E',
		      p_request_source => p_request_source,
		      --g_status         => g_status,
		      g_status_message1 => g_status_message1,
		      g_status1         => g_status1);
      
        -- COMMIT;
      END IF;
    END IF;
  
    IF g_status1 <> 'S' THEN
      ROLLBACK;
    ELSE
      COMMIT;
    END IF;
  
    IF p_header_rec.pofile IS NOT NULL AND g_status = 'S' AND
       g_status1 = 'S' AND p_order_header_id IS NOT NULL THEN
      --call attachment upload procedure
    
      BEGIN
        l_file_ext := get_file_extension(p_header_rec.pocontenttype);
      
      EXCEPTION
      
        WHEN OTHERS THEN
          g_status         := 'E101';
          g_status_message := 'ERROR in getting file extension for filename: ' ||
		      p_header_rec.pocontenttype || ';' || SQLERRM;
        
      END;
    
      IF g_status = 'S' THEN
      
        BEGIN
        
          xxfnd_load_attachment_pkg.load_file_attachment(p_pk_id             => p_order_header_id, --l_header_rec_out.header_id,/* Modified on 14 Jun2016 CHG0038756 - Lingaraj Sarangi */
				         p_entity_name       => 'OE_ORDER_HEADERS',
				         p_file_type         => l_file_ext, --'PDF',
				         p_document_category => 'Customer PO Attachment',
				         p_attachment_desc   => 'Customer PO Attchment for Order Number' || ' ' ||
						        l_header_rec_out.order_number,
				         p_filename          => p_header_rec.pocontenttype,
				         p_filepath          => NULL,
				         p_file_blob         => p_header_rec.pofile,
				         -- p_debug_flag          => p_debug_flag,
				         x_status         => l_attchment_status,
				         x_status_message => l_attchment_status_msg);
          dbms_output.put_line('Status: ' || l_attchment_status);
          dbms_output.put_line('Status Message: ' ||
		       l_attchment_status_msg);
          g_status         := l_attchment_status;
          g_status_message := g_status_message || chr(13) ||
		      l_attchment_status_msg;
        
          oe_debug_pub.add('SSYS CUSTOM: End of Order Creation');
        
        EXCEPTION
        
          WHEN OTHERS THEN
	g_status         := 'E101';
	g_status_message := 'ERROR in creating attachment for Order Number: ' ||
		        p_header_rec.order_number || ';' || SQLERRM;
          
        END;
      END IF;
    END IF;
  
    -- CHG0044725 - Start - No commits present in this sections of code. SO added below commit if above operations were successful
    IF g_status = 'S' THEN
      COMMIT;
    ELSE
      ROLLBACK;
    END IF;
    -- CHG0044725 End
  
    --CHG0038756 START
    ----------------------------------------------------------------------------------------------------------------
    --  ver  date          name                Description
    --  1.4 14-Jun-2016    Lingaraj Sarangi    CHG0038756 - Adjust ecommerce create order interface to support credit card process
    ----------------------------------------------------------------------------------------------------------------------
  
    IF g_status = 'S' AND l_att_category_name IS NOT NULL AND
       p_order_header_id IS NOT NULL THEN
      -- If Sales Order Created Sucessfully
      BEGIN
        SELECT category_id
        INTO   l_attachment_category_id
        FROM   fnd_document_categories_tl
        WHERE  upper(user_name) = upper(l_att_category_name)
        AND    LANGUAGE = userenv('LANG');
      EXCEPTION
        WHEN OTHERS THEN
          l_attachment_category_id := NULL;
      END;
    
      IF (p_header_rec.ipay_approvalcode IS NOT NULL OR
         --p_header_rec.ipay_extToken       IS NOT NULL OR
         p_header_rec.ipay_transactionid IS NOT NULL OR
         --p_header_rec.ipay_customerRefNum IS NOT NULL OR
         p_header_rec.ipayccnumber IS NOT NULL) AND
         l_attachment_category_id IS NOT NULL THEN
      
        l_short_text := 'CC Num=' || p_header_rec.ipayccnumber || chr(10) ||
		'Approval Code=' || p_header_rec.ipay_approvalcode
	           --  || chr(10) ||'Ext Token='||p_header_rec.ipay_extToken
	           --  || chr(10) ||'Customer Ref Num='||p_header_rec.ipay_customerRefNum
		|| chr(10) || 'Transactio NID=' ||
		p_header_rec.ipay_transactionid;
      
        --Attach the Received Token information to the Sales Order Header
        xxobjt_fnd_attachments.create_short_text_att(err_code                  => l_attch_err_code,
				     err_msg                   => l_attch_err_msg,
				     p_document_id             => l_document_id, --OUT PARAMETER
				     p_category_id             => l_attachment_category_id, -- Category the Short Text Attachment will Be Added
				     p_entity_name             => 'OE_ORDER_HEADERS',
				     p_file_name               => NULL,
				     p_title                   => NULL,
				     p_description             => NULL,
				     p_short_text              => l_short_text,
				     p_short_text_message_name => NULL,
				     p_pk1                     => p_order_header_id,
				     p_pk2                     => NULL,
				     p_pk3                     => NULL);
      
        IF l_attch_err_code = 1 THEN
          -- Attachment Error Out
          oe_debug_pub.add('Sales Order attachment Failed With Error : ' ||
		   l_attch_err_msg);
          g_status := 'E'; -- CHG0044725
        ELSE
          g_status := 'S'; -- CHG0044725
        
          oe_debug_pub.add('Sales Order attachment Sucessfull With Document Id: ' ||
		   l_document_id);
        END IF;
      END IF;
    END IF;
    --END CHG0038756 - Adjust ecommerce create order interface to support credit card process
  
    -- CHG0044725 - Start - No commits present in this sections of code. SO added below commit if above operations were successful
    IF g_status = 'S' THEN
      COMMIT;
    ELSE
      ROLLBACK;
    END IF;
    -- CHG0044725 End
  
    IF g_status = 'S' AND l_payment_type_code = 'CREDIT_CARD' THEN
      -- UPDATE the PSON / Tangable ID in IBY table
      xxiby_process_cust_paymt_pkg.update_estore_pson(p_estore_pson  => p_header_rec.ipay_orderidpson,
				      p_so_header_id => p_order_header_id,
				      x_error_code   => l_err_code,
				      x_error        => l_error);
    
      /* CHG0044725 - Send error mail if update PSON fails */
      IF l_err_code = 1 THEN
        oe_debug_pub.add('ERROR: While update of PSON: ' || l_error);
        dbms_output.put_line('ERROR: While update of PSON: ' || l_error);
      
        send_mail_autonomous(p_header_rec.org_id,
		     'Error while processing update of PSON number of eStore credit card order ' ||
		     p_header_rec.order_number || chr(13) ||
		     'Please contact IT for further assistance.' ||
		     chr(13) || 'ERROR: ' || l_error);
      END IF;
      /* CHG0044725 - End*/
    
      --Insert the Transaction to the Custom Table
      l_err_code := NULL;
      l_error    := NULL;
      xxiby_process_cust_paymt_pkg.insert_orb_trn_mapping(p_ordernumber   => p_header_rec.ipay_orderidpson,
				          p_trnrefnum     => p_header_rec.ipay_transactionid,
				          p_orbital_token => p_header_rec.ipay_customerrefnum,
				          p_err_code      => l_err_code,
				          p_err_message   => l_error);
    
      /* CHG0044725 - Send error mail if update orbital transaction fails */
      IF l_err_code = 1 THEN
        oe_debug_pub.add('ERROR: While update of Orbital Transaction: ' ||
		 l_error);
        dbms_output.put_line('ERROR: While update of Orbital Transaction: ' ||
		     l_error);
      
        send_mail_autonomous(p_header_rec.org_id,
		     'Error while processing update of Orbital Transaction of eStore credit card order ' ||
		     p_header_rec.order_number || chr(13) ||
		     'Please contact IT for further assistance.' ||
		     chr(13) || 'ERROR: ' || l_error);
      END IF;
    
      COMMIT;
      /* CHG0044725 - End*/
    END IF;
  
    IF g_debug_flag = 'Y' THEN
      oe_debug_pub.debug_off;
    END IF;
  
    IF g_status <> 'S' THEN
      p_err_code    := g_status;
      p_err_message := g_status_message;
    END IF;
  
    IF g_status = 'S' AND g_status1 <> 'S' THEN
      p_err_code    := g_status;
      p_err_message := 'Order Created successfully but failed in updating pricing tables.' || ':' ||
	           g_status_message1;
    END IF;
  
    IF g_status = 'S' THEN
      p_err_code    := g_status;
      p_err_message := 'Order Created successfully';
    END IF;
  
    dbms_output.put_line('p_err_code: ' || p_err_code);
    dbms_output.put_line('p_err_message: ' || p_err_message);
  
  EXCEPTION
  
    WHEN OTHERS THEN
    
      p_err_code    := 'E101';
      p_err_message := 'ERROR in order creation for Order Number: ' ||
	           p_header_rec.order_number || ':' || SQLERRM;
    
  END create_order;

END xxom_salesorder_util;
/
