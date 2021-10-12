CREATE OR REPLACE PACKAGE xxpo_communication_report_pkg AUTHID CURRENT_USER IS
  ---------------------------------------------------------------------------
  -- $Header: xxpo_communication_report_pkg 120.0 2009/08/31  $
  ---------------------------------------------------------------------------
  -- Package: xxpo_communication_report_pkg
  -- Created: 
  -- Author  : 
  --------------------------------------------------------------------------
  -- Perpose: Wrapper for po doscuments
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  31/08/09                  Initial Build
  --     2.0   4.11.10                  change logic in get_release_remain_quantity
  --     3.0  22.4.12   YUVAL TAL        Add : is_multi_ship_to_org
  ---------------------------------------------------------------------------
  FUNCTION get_total(x_object_type IN VARCHAR2, x_object_id IN NUMBER)
    RETURN NUMBER;

  FUNCTION get_rate_cur_for_xml(po_number     IN VARCHAR2,
                                p_relsase_num NUMBER) RETURN VARCHAR2;

  FUNCTION get_rate_baserate_for_xml(po_number     IN VARCHAR2,
                                     p_relsase_num NUMBER) RETURN NUMBER;

  FUNCTION get_rate_basedate_for_xml(po_number     IN VARCHAR2,
                                     p_relsase_num NUMBER) RETURN DATE;

  FUNCTION get_approved_details_for_xml(po_number IN VARCHAR2,
                                        p_field   IN VARCHAR2 DEFAULT NULL)
    RETURN VARCHAR;

  FUNCTION get_logo(po_number IN VARCHAR2) RETURN VARCHAR2;

  FUNCTION get_balance_quantity(p_po_line_id NUMBER) RETURN NUMBER;

  FUNCTION get_converted_amount(p_amount      IN NUMBER,
                                po_number     IN VARCHAR2,
                                p_release_num NUMBER) RETURN NUMBER;

  FUNCTION get_last_release_num(po_number IN VARCHAR2) RETURN VARCHAR2;

  FUNCTION get_rel_balance_quantity(p_po_line_loc_id NUMBER) RETURN NUMBER;
  FUNCTION get_release_remain_quantity(p_line_id NUMBER) RETURN NUMBER;

  FUNCTION is_promised_date_changed(p_line_location_id IN NUMBER)
    RETURN VARCHAR2;

  FUNCTION is_need_by_date_changed(p_line_location_id IN NUMBER)
    RETURN VARCHAR2;
  FUNCTION is_multi_ship_to_org(p_po_header_id NUMBER) RETURN NUMBER;
  FUNCTION get_release_num(p_po_release_id NUMBER) RETURN NUMBER;
  FUNCTION get_uom_tl(p_inventory_item_id NUMBER,
                      p_organization_id   NUMBER,
                      p_unit_of_measure   VARCHAR2) RETURN VARCHAR2;

  FUNCTION get_ap_term_name_tl(p_term_id NUMBER, p_org_id NUMBER)
    RETURN VARCHAR2;
END xxpo_communication_report_pkg;
/
