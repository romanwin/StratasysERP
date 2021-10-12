CREATE OR REPLACE PACKAGE xxatc_erp.xxobjt_utils IS

  -- Author  : AVIH
  -- Created : 7/28/2010 3:37:59 PM
  -- Purpose : Handle Objet Custom Utilities

  FUNCTION get_parent_cust_location(p_cust_trx_line_gl_dist_id IN NUMBER)
    RETURN VARCHAR2;

  FUNCTION get_om_parent_cust_location(p_invoice_to_org_id IN NUMBER)
    RETURN VARCHAR2;

  FUNCTION get_prod_line_family(p_cust_trx_line_gl_dist_id IN NUMBER)
    RETURN VARCHAR2;

  FUNCTION get_cs_installation_date(pf_interface_line_context IN VARCHAR2,
                                    interface_line_attribute6 IN VARCHAR2,
                                    p_treat_expected_inst     IN CHAR DEFAULT 'N')
    RETURN DATE;

  FUNCTION get_om_discount_multiplication(p_order_header_id IN NUMBER)
    RETURN NUMBER;

  FUNCTION get_om_invoice_number(p_oe_line_id IN NUMBER) RETURN VARCHAR2;

  FUNCTION get_om_invoice_date(p_oe_line_id IN NUMBER) RETURN DATE;

  FUNCTION get_is_installdate_relevant(p_oe_line_id           IN NUMBER,
                                       p_customer_trx_line_id IN NUMBER)
    RETURN CHAR;

  FUNCTION get_om_range_date(p_oe_line_id IN NUMBER) RETURN VARCHAR2;

  FUNCTION get_ar_range_date(p_cust_trx_line_gl_dist_id IN NUMBER)
    RETURN VARCHAR2;

  FUNCTION get_so_sales_channel(p_customer_trx_line_id IN NUMBER)
    RETURN VARCHAR2;

  FUNCTION get_so_typecontext(p_customer_trx_line_id IN NUMBER)
    RETURN VARCHAR2;

  FUNCTION get_cs_instance_type(p_oe_line_id IN NUMBER) RETURN VARCHAR2;

END xxobjt_utils;
/
