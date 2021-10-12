CREATE OR REPLACE PACKAGE xxoks_cover IS
  --------------------------------------------------------------------
  --  name:            xxoks_cover
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   4.4.11
  --------------------------------------------------------------------
  --  purpose :    
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0    4.4.11   yuval tal    initial build
  --------------------------------------------------------------------

  FUNCTION get_cover_param_text(p_org_id            NUMBER,
                                p_item_id           NUMBER,
                                p_platform_code     IN VARCHAR2,
                                p_platform_sub_code IN VARCHAR2,
                                p_to_date           DATE DEFAULT SYSDATE)
    RETURN VARCHAR2;

  FUNCTION get_cover_param_number(p_org_id            NUMBER,
                                  p_item_id           NUMBER,
                                  p_platform_code     IN VARCHAR2,
                                  p_platform_sub_code IN VARCHAR2,
                                  p_to_date           DATE DEFAULT SYSDATE)
    RETURN NUMBER;

  FUNCTION get_cover_param_date(p_org_id            NUMBER,
                                p_item_id           NUMBER,
                                p_platform_code     IN VARCHAR2,
                                p_platform_sub_code IN VARCHAR2,
                                p_to_date           DATE DEFAULT SYSDATE)
    RETURN DATE;

  FUNCTION get_visit_count(p_party_id    NUMBER,
                           p_resource_id NUMBER,
                           p_from_date   DATE,
                           p_to_date     DATE) RETURN NUMBER;
  FUNCTION get_visit_count4contract(p_incident_id     NUMBER,
                                    p_debrief_line_id NUMBER) RETURN NUMBER;

  FUNCTION is_valid_foc(p_business_process_id NUMBER,
                        p_transaction_type_id NUMBER) RETURN VARCHAR2;

  PROCEDURE update_charge_record(p_charges_rec cs_charge_details_pub.charges_rec_type,
                                 p_err_code    OUT NUMBER,
                                 p_err_message OUT VARCHAR2);

  PROCEDURE history_build;

  PROCEDURE recalculate(p_err_code    OUT NUMBER,
                        p_err_message OUT VARCHAR2,
                        p_incident_id NUMBER);

  PROCEDURE calc_foc(p_incident_id NUMBER,
                     p_err_code    OUT NUMBER,
                     p_err_message OUT VARCHAR2);

  PROCEDURE calc_tm(p_incident_id NUMBER,
                    p_err_code    OUT NUMBER,
                    p_err_message OUT VARCHAR2);

  PROCEDURE calc_sp(p_incident_id NUMBER,
                    p_err_code    OUT NUMBER,
                    p_err_message OUT VARCHAR2);
  FUNCTION get_sp_item_discount(p_item_id NUMBER, p_lookup_type VARCHAR2)
    RETURN NUMBER;

  PROCEDURE get_foc_definition(p_incident_id NUMBER,
                               p_type        OUT VARCHAR2,
                               p_foc_value   OUT NUMBER);

  FUNCTION get_printer_count(p_incident_id NUMBER) RETURN NUMBER;
  PROCEDURE get_contract_info4incident(p_incident_id        NUMBER,
                                       p_contract_header_id OUT NUMBER,
                                       p_contract_line_id   OUT NUMBER,
                                       p_from_date          OUT DATE,
                                       p_to_date            OUT DATE,
                                       p_inventory_id       OUT NUMBER,
                                       p_org_id             OUT NUMBER);

  FUNCTION get_incident_row(p_incident_id NUMBER)
    RETURN cs_incidents_all_b%ROWTYPE;

  FUNCTION get_incident_id(p_debrief_line_id NUMBER) RETURN NUMBER;

  FUNCTION get_incedent_timezone_code(p_incident_id NUMBER) RETURN VARCHAR2;

  FUNCTION convert_date2incident_tz(p_server_date DATE,
                                    p_incident_id NUMBER) RETURN DATE;

  FUNCTION get_foc_message(p_incident_id NUMBER) RETURN VARCHAR2;

  FUNCTION is_indirect(p_incident_id NUMBER) RETURN VARCHAR2;

  FUNCTION is_tm(p_incident_id NUMBER) RETURN VARCHAR2;
  PROCEDURE get_tm_related_info(p_incident_id         NUMBER,
                                p_unit_price          OUT NUMBER,
                                p_curr_code           OUT VARCHAR2,
                                p_price_header_id     OUT NUMBER,
                                p_wkhrs_item_id       OUT NUMBER,
                                p_uom                 OUT VARCHAR2,
                                p_org_id              OUT NUMBER,
                                p_business_process_id OUT NUMBER,
                                p_contract_id         OUT NUMBER,
                                p_contract_line_id    OUT NUMBER);
  FUNCTION get_dbf_count4incident(p_incident_id NUMBER) RETURN NUMBER;

  PROCEDURE log(p_message VARCHAR2);

  FUNCTION is_submit_allowed(p_incident_id NUMBER) RETURN VARCHAR2;

  FUNCTION get_incident_value(p_instance_number VARCHAR2, p_type VARCHAR2)
    RETURN VARCHAR2;

END;
/
