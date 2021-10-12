create or replace package xxap_prep_open_balance_disco is

  -- Author  : DANIEL.KATZ
  -- Created : 11/10/2010 6:23:41 PM
  -- Purpose : prepayment open balance report
  
    -- Public variable declarations
  g_last_date  date := to_date('20090101','yyyymmdd');
  g_as_of_date date;
  g_remain_prep_amount number;
  g_sla_last_date  date := to_date('20090101','yyyymmdd');
  g_sla_as_of_date date;

  TYPE varchar_table_type IS TABLE OF varchar2(50) INDEX BY BINARY_INTEGER;
  t_sla_prep_account varchar_table_type;
  
  -- Public function and procedure declarations
  FUNCTION set_last_date(p_end_date DATE) RETURN NUMBER;
  FUNCTION get_last_date RETURN DATE;
  FUNCTION set_as_of_date(p_as_of_date DATE) RETURN NUMBER;
  FUNCTION get_as_of_date RETURN DATE;
  FUNCTION set_get_prep_to_pay(p_prep_amount number, p_prep_invoice_id number) RETURN NUMBER;
  FUNCTION get_prep_to_pay RETURN number;
  FUNCTION set_sla_last_date(p_end_date DATE) RETURN NUMBER;
  FUNCTION get_sla_last_date RETURN DATE;
  FUNCTION set_sla_as_of_date(p_as_of_date DATE) RETURN NUMBER;
  FUNCTION get_sla_as_of_date RETURN DATE;
  FUNCTION set_sla_prep_accounts(p_accounts varchar2) RETURN NUMBER;
  FUNCTION get_sla_prep_accounts (p_count number) RETURN varchar2;
  FUNCTION is_inventory_po(p_po_header_id number) RETURN VARCHAR2;
  PROCEDURE test_upload_prep_open_inv_data(errbuf        OUT VARCHAR2,
                                           retcode       OUT NUMBER);
  PROCEDURE test_upl_prep_sla_open_inv_dat(errbuf        OUT VARCHAR2,
                                           retcode       OUT NUMBER,
                                           p_accounts    IN VARCHAR2);                                                

end xxap_prep_open_balance_disco;
/

