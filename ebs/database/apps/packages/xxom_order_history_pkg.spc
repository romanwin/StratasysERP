CREATE OR REPLACE PACKAGE xxom_order_history_pkg AUTHID CURRENT_USER AS
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
  --  1.2  03/20/2018  Diptasurjya           CHG0042550 - Search algorithm changed based on unifid search string for Order number
  --                                         PO Number and Ship to customer name
  --  1.3  30-MAY-2019 Diptasurjya           CHG0045755 - Add new input parameter to customer_order_history procedure
  --    1.4  15/12/2020  Yuval Tal             CHG0048217 - add to spec get_delivery_status
  --------------------------------------------------------------------

  TYPE xxom_ord_hist_hdr_rec IS RECORD(
    header_id             NUMBER,
    ordernumber           NUMBER,
    orderdate             DATE,
    formatted_order_date  VARCHAR2(50),
    cust_po_number        VARCHAR2(50),
    ship_to_org_id        NUMBER,
    invoice_to_org_id     NUMBER,
    sold_to_contact_id    NUMBER,
    ship_to_contact_id    NUMBER,
    invoice_to_contact_id NUMBER,
    bill_address          VARCHAR2(1206),
    ship_address          VARCHAR2(1206),
    bill_contact          VARCHAR2(1206),
    sold_contact          VARCHAR2(1206),
    ship_contact          VARCHAR2(1206),
    payment_terms         VARCHAR2(15),
    chanel_org            VARCHAR2(240),
    channel               VARCHAR2(240),
    status                VARCHAR2(30),
    currency_code         VARCHAR2(10),
    shipping_method       VARCHAR2(240));

  TYPE xxom_ord_hist_hdr_tab IS TABLE OF xxom_ord_hist_hdr_rec;
  FUNCTION get_delivery_status(p_header_id NUMBER) RETURN VARCHAR2;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0042550 - This function returns the customer name for an input site_use_id
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                      Description
  -- 1.0  03/20/2018  Diptasurjya Chatterjee    Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION get_cust_namefor_siteuse(p_site_use_id NUMBER) RETURN VARCHAR2;

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
  --                   Chatterjee
  --  1.4  30-MAY-2019 Diptasurjya           CHG0045755 - CTASK0042105 - Show orders based on contact level DFF setting
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
		           x_status_message     OUT VARCHAR2);
END xxom_order_history_pkg;
/
