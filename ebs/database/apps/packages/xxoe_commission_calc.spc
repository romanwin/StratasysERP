CREATE OR REPLACE PACKAGE xxoe_commission_calc AS
  ---------------------------------------------------------------------------
  -- $Header: XXOE_COMMISSION_CALC   $
  ---------------------------------------------------------------------------
  -- Package: XXOE_COMMISSION_CALC
  -- Created: 
  -- Author  : 
  --------------------------------------------------------------------------
  -- Perpose: COMMISSION CALC PROCESS SUPPORT
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  1.9.11   yuval tal            Initial Build

  ---------------------------------------------------------------------------
  --FUNCTION check_in_value(p_chk VARCHAR2, p_string VARCHAR2) RETURN BOOLEAN;

  g_xxoe_commission_data_rec xxoe_commission_data%ROWTYPE;
  PROCEDURE init_global;
  FUNCTION get_upgrade_date(p_instance_id NUMBER) RETURN DATE;
  FUNCTION get_ap_info_desc(p_type VARCHAR2, p_line_id NUMBER)
    RETURN VARCHAR2;
  FUNCTION get_line_invoice_type(p_line_id NUMBER) RETURN VARCHAR2;

  FUNCTION get_param_type(p_param VARCHAR2) RETURN VARCHAR2;
  PROCEDURE check_sql(p_sql VARCHAR2);

  FUNCTION get_item_type(p_inventory_item_id NUMBER,
                         p_organization_id   NUMBER) RETURN VARCHAR2;
  FUNCTION is_stage_final(p_stage VARCHAR2) RETURN VARCHAR2;
  FUNCTION is_rule_used(p_rule_id NUMBER, p_ver NUMBER) RETURN NUMBER;
  PROCEDURE enable_last_rule(p_rule_id NUMBER, p_ver NUMBER);
  PROCEDURE create_new_rule_version(p_rule_id NUMBER, p_ver NUMBER);
  PROCEDURE copy_rule(p_rule_id NUMBER, p_ver NUMBER);

  PROCEDURE insert_history(p_rec xxoe_commission_data%ROWTYPE);
  PROCEDURE main(p_err_message OUT VARCHAR2, p_err_code OUT NUMBER);
  FUNCTION is_initial_order(p_oe_header_id NUMBER) RETURN VARCHAR2;
  FUNCTION is_dealer(p_party_id NUMBER, p_to_date DATE DEFAULT SYSDATE)
    RETURN VARCHAR2;

  FUNCTION is_upgrade_order(p_oe_header_id NUMBER) RETURN VARCHAR2;
  FUNCTION get_order_upgrade_date(p_order_number VARCHAR2) RETURN DATE;
  FUNCTION get_shipped_date(p_line_id NUMBER) RETURN DATE;
  FUNCTION is_ib_exists(p_header_id NUMBER) RETURN VARCHAR2;
  FUNCTION get_coi_date(p_header_id NUMBER) RETURN DATE;
  FUNCTION is_ar_payments_exists(p_order_number VARCHAR2,
                                 p_line_id      NUMBER,
                                 p_org_id       NUMBER) RETURN VARCHAR2;
  FUNCTION get_ar_avg_discount(p_order_number VARCHAR2, p_line_id NUMBER)
    RETURN VARCHAR2;
  PROCEDURE get_ar_info(p_order_number VARCHAR2,
                        p_line_id      NUMBER,
                        p_org_id       NUMBER,
                        p_amount       OUT NUMBER,
                        
                        p_inv_number       OUT VARCHAR2,
                        p_inv_line_number  OUT NUMBER,
                        p_inv_paid_flag    OUT VARCHAR2,
                        p_inv_date         OUT DATE,
                        p_avg_discount_pct OUT NUMBER,
                        p_err_code         OUT NUMBER,
                        p_err_message      OUT VARCHAR2);

  PROCEDURE delta(p_err_code OUT NUMBER, p_err_message OUT VARCHAR2);
  PROCEDURE match_ar_invoice_info(p_err_code    OUT NUMBER,
                                  p_err_message OUT VARCHAR2);
  PROCEDURE get_ap_paid_info(p_line_id           NUMBER,
                             p_amount            OUT NUMBER,
                             p_amount_prepayment OUT NUMBER,
                             p_exp_desc          OUT VARCHAR2,
                             p_prepay_desc       OUT VARCHAR2);
  PROCEDURE match_ap_commission_payments(p_err_code    OUT NUMBER,
                                         p_err_message OUT VARCHAR2,
                                         p_agent_id    NUMBER);
  PROCEDURE check_stages(p_err_code OUT NUMBER, p_err_message OUT VARCHAR2);
  FUNCTION get_stage_pct(p_stage VARCHAR2) RETURN NUMBER;
  FUNCTION get_order_system_type(p_oe_header_id NUMBER) RETURN VARCHAR2;

  PROCEDURE check_commission(p_err_code    OUT NUMBER,
                             p_err_message OUT VARCHAR2);

  FUNCTION get_rule_explain(p_line_id NUMBER,
                            p_stage   VARCHAR2,
                            p_rule_id NUMBER,
                            p_ver     NUMBER) RETURN VARCHAR2;
  FUNCTION get_rule_explain_his(p_line_id NUMBER,
                                p_stage   VARCHAR2,
                                p_rule_id NUMBER,
                                p_ver     NUMBER,
                                p_date    DATE) RETURN VARCHAR2;

  PROCEDURE create_invoices(p_err_code    OUT NUMBER,
                            p_err_message OUT VARCHAR2,
                            p_agent_id    NUMBER);
  PROCEDURE get_vendor_info(p_err_code       OUT NUMBER,
                            p_err_msg        OUT VARCHAR2,
                            p_resource_id    NUMBER,
                            p_vendor_id      OUT NUMBER,
                            p_vendor_site_id OUT NUMBER,
                            p_vendor_name    OUT VARCHAR2,
                            p_ccid           OUT NUMBER,
                            p_inv_curr       OUT VARCHAR2);
  PROCEDURE close_lines(p_err_code    OUT NUMBER,
                        p_err_message OUT VARCHAR2,
                        p_agent_id    NUMBER);
  PROCEDURE process_avg_discount(p_err_code    OUT NUMBER,
                                 p_err_message OUT VARCHAR2);
  PROCEDURE count_e_c_sys_printers(p_agent_id    NUMBER,
                                   p_party_id    NUMBER,
                                   p_base_count  OUT NUMBER,
                                   p_total_count OUT NUMBER);
  PROCEDURE open_order4recalc(p_err_code    OUT NUMBER,
                              p_err_message OUT VARCHAR2,
                              p_order_num   NUMBER);

END;
/
