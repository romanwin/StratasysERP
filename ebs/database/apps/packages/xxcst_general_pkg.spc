CREATE OR REPLACE PACKAGE xxcst_general_pkg AUTHID CURRENT_USER IS
  ------------------------------------------------------------------
  -- $Header: xxcst_general_pkg   $
  ------------------------------------------------------------------
  -- Package: XXCST_GENERAL_PKG
  -- Created:
  -- Author:  Vitaly
  ------------------------------------------------------------------
  -- Purpose: 
  ------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ----------------------------
  --     1.0  03.10.13   Vitaly         initial build
  ------------------------------------------------------------------
  FUNCTION get_buy_item_avg_material_cost(p_organization_id   IN NUMBER,
                                          p_inventory_item_id IN NUMBER,
                                          p_from_date         IN DATE,
                                          p_to_date           IN DATE)
    RETURN NUMBER;

  FUNCTION get_buy_item_prev_mat_cost(p_organization_id   IN NUMBER,
                                      p_inventory_item_id IN NUMBER,
                                      p_date              IN DATE)
    RETURN NUMBER;

  FUNCTION get_buy_item_curr_std_cost(p_organization_id   IN NUMBER,
                                      p_inventory_item_id IN NUMBER)
    RETURN NUMBER;

  FUNCTION get_buy_item_last_unit_price(p_inventory_item_id IN NUMBER)
    RETURN NUMBER;

  FUNCTION get_buy_item_last_need_by_date(p_inventory_item_id IN NUMBER)
    RETURN DATE;

END xxcst_general_pkg;
/
