CREATE OR REPLACE PACKAGE xxar_revenue_recognition_disco IS

  -- Author  : DANIEL.KATZ
  -- Created : 1/18/2010 1:27:43 PM
  -- Purpose : Revenue Recognition Disco Report

  -- Public declarations
  TYPE date_table_type IS TABLE OF DATE INDEX BY BINARY_INTEGER;
  t_start_date date_table_type;

  TYPE number_table_type IS TABLE OF NUMBER INDEX BY BINARY_INTEGER;
  t_ledger_id number_table_type;

  g_warranty_start_date DATE;
  g_warranty_end_date   DATE;
  g_warranty_service    VARCHAR2(50);

  -- Public function and procedure declarations

  FUNCTION set_revrecog_glstrt_date(p_segment3_rev  VARCHAR2,
                                    p_segment3_cogs VARCHAR2,
                                    p_end_date      DATE) RETURN NUMBER;

  FUNCTION get_revrecog_glstrt_date(p_ledger_id IN NUMBER) RETURN DATE;

  FUNCTION get_invoice_balance(p_invoice_id        NUMBER,
                               p_as_of_date        DATE,
                               p_accounted_entered VARCHAR2 DEFAULT 'E')
    RETURN NUMBER;

  FUNCTION get_set_warranty_data(p_serial VARCHAR2, p_cust_acct_id NUMBER)
    RETURN DATE;

  FUNCTION get_applied_invoice_info(p_invoice_id NUMBER) RETURN VARCHAR2;

  FUNCTION get_warranty_end_date RETURN DATE;

  FUNCTION get_warranty_service RETURN VARCHAR2;

  FUNCTION get_order_header_id(p_order_number VARCHAR2, p_org_id NUMBER)
    RETURN NUMBER;
  FUNCTION is_ssys_item(pc_itemid NUMBER) RETURN NUMBER;
  FUNCTION is_ssys_900_item(pc_itemid NUMBER) RETURN NUMBER;

END xxar_revenue_recognition_disco;
/
