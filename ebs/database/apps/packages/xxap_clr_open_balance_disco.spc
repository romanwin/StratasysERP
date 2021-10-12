create or replace package xxap_clr_open_balance_disco is

  -- Author  : DANIEL.KATZ
  -- Created : 12/05/2010 1:23:41 PM
  -- Purpose : ap cash clearing open balance report
  
    -- Public variable declarations
  g_last_date  date := to_date('20090101','yyyymmdd');
  g_as_of_date date;

  g_sla_last_date  date := to_date('20090101','yyyymmdd');
  g_sla_as_of_date date;

  -- Public function and procedure declarations
  FUNCTION set_last_date(p_end_date DATE) RETURN NUMBER;
  FUNCTION get_last_date RETURN DATE;
  FUNCTION set_as_of_date(p_as_of_date DATE) RETURN NUMBER;
  FUNCTION get_as_of_date RETURN DATE;
  FUNCTION set_sla_last_date(p_end_date DATE) RETURN NUMBER;
  FUNCTION get_sla_last_date RETURN DATE;
  FUNCTION set_sla_as_of_date(p_as_of_date DATE) RETURN NUMBER;
  FUNCTION get_sla_as_of_date RETURN DATE;
  PROCEDURE test_upload_clr_open_bal_data(errbuf        OUT VARCHAR2,
                                           retcode       OUT NUMBER,
                                           p_account IN VARCHAR2);
  PROCEDURE test_upl_clr_sla_open_bal_dat(errbuf        OUT VARCHAR2,
                                           retcode       OUT NUMBER,
                                           p_account    IN VARCHAR2);                                                

end xxap_clr_open_balance_disco;
/

