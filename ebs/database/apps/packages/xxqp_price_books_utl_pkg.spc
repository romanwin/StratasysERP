CREATE OR REPLACE PACKAGE xxqp_price_books_utl_pkg IS
  --------------------------------------------------------------------
  --  customization code: CHG0033893 - Price Books Automation
  --  name:               xxqp_price_books_utl_pkg
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  creation date:      15/03/2015
  --  Description:        Price book utilities for setup form and excel report
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   15/03/2015    Michal Tzvik    initial build
  --------------------------------------------------------------------

  c_src_simulation1 VARCHAR2(25) := 'SIMULATION'; -- PL Simulation
  c_src_simulation CONSTANT VARCHAR2(25) := 'SIMULATION'; -- PL Simulation
  c_src_active     CONSTANT VARCHAR2(25) := 'ACTIVE'; -- Active PL Simulation

  -- Parameters for Excel report
  p_price_book_version_id NUMBER;
  p_generation_id         NUMBER;
  lp_generation           VARCHAR2(1000);

  FUNCTION get_price_list_name(p_price_list_id NUMBER) RETURN VARCHAR2;

  FUNCTION get_price_list_id(p_price_list_name NUMBER) RETURN VARCHAR2;

  FUNCTION get_price_book_name(p_price_book_id NUMBER) RETURN VARCHAR2;

  FUNCTION get_ver_status_name(p_status_code VARCHAR2) RETURN VARCHAR2;

  FUNCTION get_current_version_status(p_price_book_id NUMBER) RETURN VARCHAR2;

  FUNCTION get_version_status(p_price_book_version_id NUMBER) RETURN VARCHAR2;

  FUNCTION get_factor_category_desc(p_category_name VARCHAR2) RETURN VARCHAR2;

  PROCEDURE submit_price_book_report(p_price_book_version_id VARCHAR2,
                                     p_generation_id         NUMBER DEFAULT NULL,
                                     x_request_id            OUT NUMBER,
                                     x_err_code              OUT NUMBER,
                                     x_err_msg               OUT VARCHAR2);

  PROCEDURE run_simulation(errbuf  OUT VARCHAR2,
                           retcode OUT VARCHAR2,
                           --x_request_id            OUT NUMBER,
                           p_price_book_version_id VARCHAR2,
                           p_source_type           VARCHAR2);

  FUNCTION beforereport RETURN BOOLEAN;

  FUNCTION afterreport RETURN BOOLEAN;

END xxqp_price_books_utl_pkg;
/
