create or replace package xxqp_price_book_pkg AUTHID CURRENT_USER AS
  ----------------------------------------------------------------------------
  --  name:            XXQP_PRICE_BOOK_PKG
  --  create by:       Diptasurjya Chatterjee (TCS)
  --  Revision:        1.0
  --  creation date:   02-Mar-2018
  ----------------------------------------------------------------------------
  --  purpose :        CHG0042196 - Pricebook Generation as per request originating from Strataforce
  ----------------------------------------------------------------------------
  --  ver   date           name                            Desc
  --  1.0   02-Mar-2018    Diptasurjya Chatterjee (TCS)    CHG0042196 - Initial Build
  ----------------------------------------------------------------------------
  p_event_id            NUMBER;
  p_send_mail           VARCHAR2(100);
  p_email_address       VARCHAR2(1000);
  p_process_extra_field VARCHAR2(1);

  TYPE xxqp_sf_price_rec IS RECORD(
    event_id            NUMBER,
    list_header_id      NUMBER,
    account_number      VARCHAR2(30),
    email_address       VARCHAR2(200),
    end_cust_acct_num   VARCHAR2(30),
    operation_no        NUMBER,
    country_code        VARCHAR2(50),
    org_id              NUMBER,
    industry            VARCHAR2(200),
    related_to_machine  VARCHAR2(4000),
    related_to_prod_fam VARCHAR2(4000),
    inventory_item_id   NUMBER,
    product_family      VARCHAR2(1000),
    applicable_system   VARCHAR2(1000),
    product_code        VARCHAR2(1000),
    product_name        VARCHAR2(1000),
    prod_long_desc      VARCHAR2(1000),
    product_type        VARCHAR2(1000),
    reseller_price      NUMBER,
    direct_price        NUMBER,
    currency            VARCHAR2(10),
    adjustment_info     VARCHAR2(4000),
    item_uom            VARCHAR2(20), --CTASK0037204
    priced_uom          VARCHAR2(20) --CTASK0037204
    );

  TYPE xxqp_sf_price_tab IS TABLE OF xxqp_sf_price_rec INDEX BY BINARY_INTEGER;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0042196 - This function fetches Product Family for a item code from Strataforce
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  23/02/2018  Diptasurjya Chatterjee (TCS)    CHG0042196 - Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION get_sf_prod_family(p_item_code VARCHAR2) RETURN VARCHAR2;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0042196 - This function fetches Applicable Systems for a item code from Strataforce
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  23/02/2018  Diptasurjya Chatterjee (TCS)    CHG0042196 - Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION get_sf_appl_system(p_item_code VARCHAR2) RETURN VARCHAR2;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0042196 - This function checks if an item is valid for PB as per related product family filter
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  23/02/2018  Diptasurjya Chatterjee (TCS)    CHG0042196 - Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION is_eligible_per_prodfam(p_item_code   VARCHAR2,
		           p_prod_family VARCHAR2) RETURN VARCHAR2;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0042196 - This function checks if an item is valid for PB as per related machine filter
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  23/02/2018  Diptasurjya Chatterjee (TCS)    CHG0042196 - Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION is_eligible_per_machine(p_item_id         NUMBER,
		           p_related_machine VARCHAR2)
    RETURN VARCHAR2;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0042196 - This function checks if an item is valid for PB as per related Visible in PB
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  23/02/2018  Yuval tal                       CHG0042196 - Initial Build
  -- --------------------------------------------------------------------------------------------

  FUNCTION is_visible_in_pb(p_item_id NUMBER) RETURN VARCHAR2;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0042196
  --          This program will check for all NEW price book generation events and perform following activities:
  --          1. Prepare valid item list as per filter conditions provided
  --          2. Call pricing API in LINE pricing mode with proper inputs
  --          3. Populate table XXQP_PRICEBOOK_DATA with pricing information against an event_id
  --          4. Call procedure  generate_pricebook_excel to generate Excel report with above table data
  --             and send same via email
  -- --------------------------------------------------------------------------------------------
  -- Calling Entity: Concurrent Program: XXQP Process PriceBookGeneration event
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  03/02/2018  Diptasurjya Chatterjee        Initial Build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE generate_price_book_conc(errbuf                OUT VARCHAR2,
			 retcode               OUT NUMBER,
			 p_event_id            IN NUMBER DEFAULT NULL,
			 p_send_mail           IN VARCHAR2,
			 p_email_address       IN VARCHAR2 DEFAULT NULL,
			 p_process_extra_field IN VARCHAR2);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHG0042196 - is_valid_request
  -- called by soa to ensure no duplicate request inserted during proccesing pricebook
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                            Description
  -- 1.0  23/02/2018  Yuval tal                       CHG0042196 - Initial Build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE is_ready2process(p_source_name VARCHAR2,
		     p_entity_code VARCHAR2,
		     p_err_code    OUT VARCHAR2,
		     p_err_message OUT VARCHAR2);
END xxqp_price_book_pkg;
/