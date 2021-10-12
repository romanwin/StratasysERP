CREATE OR REPLACE PACKAGE xxoe_so_bucket_discount_pkg IS
  --------------------------------------------------------------------
  --  name:            xxoe_so_bucket_discount_pkg
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   16/11/2014
  --------------------------------------------------------------------
  --  purpose :        CHG0033422 – Sales Discount Bucket Program
  --------------------------------------------------------------------
  --  ver    date          name             desc
  --  1.0    16.11.2014    Michal Tzvik     Initial Build
  --  1.1    07.12.2014    Michal Tzvik     CHG0034003 - Resin Bucket:
  --                                        1. Add global variable p_customer_id
  --                                        2. Procedure gen_report: add out parameters
  --                                        3. Add new functions/procedures:
  --                                           get_resin_bckt_remain_amount
  --                                           get_line_resin_discount_amount
  --                                           get_line_adjustment_rate
  --                                           get_total_so_resin_disc_amount
  --                                           get_so_resin_discount_amount
  --                                           get_resin_discount_percent
  --                                           is_order_in_resin_bucket
  --                                           run_report
  --------------------------------------------------------------------

  -- Report Parameters
  p_run_global               VARCHAR2(5);
  p_parent_customer_location VARCHAR2(30);
  p_customer_id              NUMBER; -- 07.12.2014    Michal Tzvik     CHG0034003
  p_bucket_type_code         VARCHAR2(30);
  p_from_period_name         VARCHAR2(30);
  p_to_period_name           VARCHAR2(30);
  p_permission_by_org        VARCHAR2(5);

  ------ 08.12.2014 Michal Tzvik CHG0034003: Start ------
  FUNCTION get_resin_bckt_remain_amount(p_order_header_id NUMBER)
    RETURN NUMBER;

  FUNCTION get_line_resin_discount_amount(p_currency_code    VARCHAR2,
                                          p_sys_booking_date DATE,
                                          p_ordered_quantity NUMBER,
                                          p_unit_list_price  NUMBER)
    RETURN NUMBER;

  FUNCTION get_line_adjustment_rate(p_line_id NUMBER) RETURN NUMBER;

  FUNCTION get_total_so_resin_disc_amount(p_order_header_id NUMBER,
                                          p_currency_code   VARCHAR2)
    RETURN NUMBER;

  FUNCTION get_so_resin_discount_amount(p_exclude_line_id NUMBER,
                                        p_order_header_id NUMBER,
                                        p_currency_code   VARCHAR2)
    RETURN NUMBER;

  FUNCTION get_resin_discount_percent(p_order_line_id NUMBER) RETURN NUMBER;

  FUNCTION is_order_in_resin_bucket(p_order_header_id NUMBER) RETURN VARCHAR2;

  ------ 08.12.2014 Michal Tzvik CHG0034003: End ------

  FUNCTION is_demo_order(p_order_header_id NUMBER) RETURN VARCHAR2;

  FUNCTION get_demo_allowed_discount(p_order_header_id      NUMBER,
                                     p_pl_deviation_percent NUMBER,
                                     p_so_deviation_percent NUMBER)
    RETURN NUMBER;

  FUNCTION get_order_manual_discount(p_order_header_id NUMBER) RETURN NUMBER;

  FUNCTION get_new_printer_list_price(p_order_header_id NUMBER) RETURN NUMBER;

  FUNCTION get_retrnd_printer_list_price(p_order_header_id NUMBER)
    RETURN NUMBER;

  FUNCTION get_so_total_amount(p_order_header_id NUMBER) RETURN NUMBER;

  FUNCTION conv_date_to_quarter(p_date DATE) RETURN VARCHAR2;

  FUNCTION get_quarter_first_day(p_quarter_name VARCHAR2) RETURN DATE;

  PROCEDURE gen_report(x_err_code OUT NUMBER, -- 17.12.2014 Michal Tzvik CHG0034003: add out parameters
                       x_err_msg  OUT VARCHAR2);

  -- CHG0034003 Michal Tzvik 31.12.2014
  PROCEDURE run_report(errbuf                     OUT VARCHAR2,
                       retcode                    OUT VARCHAR2,
                       p_run_global               VARCHAR2,
                       p_parent_customer_location VARCHAR2,
                       p_customer_id              NUMBER,
                       p_bucket_type_code         VARCHAR2,
                       p_previous_quarters        NUMBER);

  FUNCTION before_report RETURN BOOLEAN;

END xxoe_so_bucket_discount_pkg;
/
