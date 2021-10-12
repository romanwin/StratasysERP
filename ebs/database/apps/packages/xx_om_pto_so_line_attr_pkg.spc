CREATE OR REPLACE PACKAGE xx_om_pto_so_line_attr_pkg IS
  --------------------------------------------------------------------
  --  name:            XX_OM_PTO_SO_LINE_ATTR_PKG
  --  create by:       Gary Altman
  --  Revision:        1.0
  --  creation date:   25.08.2014
  --------------------------------------------------------------------
  --  purpose :        CHG0032648 - PTO definition form
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   25.08.2014    Gary Altman     CHG0032648 - initial version
  --  1.1   04/05/2015    Dalit A. Raviv  CHG0034234 - Update PTO Validation Setup
  --                                      add function get_max_materials_qty, get_pto_parent_category
  -- 1.2   28.01.16       yuval atl       CHG0036068 - add 2 parameters p_to_currency_code , p_conversion_date
  --------------------------------------------------------------------
  FUNCTION get_line_id(p_header_id NUMBER,
	           p_model_id  NUMBER) RETURN NUMBER;

  FUNCTION get_parent_item_id(p_header_id NUMBER,
		      p_model_id  NUMBER) RETURN NUMBER;

  -- Attribute4
  FUNCTION get_resin_credit_amount(p_pto_item_id      NUMBER,
		           p_price_list_id    NUMBER,
		           p_to_currency_code VARCHAR2 /*DEFAULT NULL*/,
		           p_conversion_date  DATE /*DEFAULT SYSDATE*/)
    RETURN NUMBER;

  -- Attribute12
  FUNCTION get_maintenance_start_date(p_pto_item_id       NUMBER,
			  p_price_list_id     NUMBER,
			  p_inventory_item_id NUMBER)
    RETURN VARCHAR2;

  -- Attribute13
  FUNCTION get_maintenance_end_date(p_pto_item_id       NUMBER,
			p_price_list_id     NUMBER,
			p_inventory_item_id NUMBER)
    RETURN VARCHAR2;

  FUNCTION check_pto_setup_fp(p_header_id NUMBER,
		      p_line_id   NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  customization code: CHG0034234 - Update PTO Validation Setup
  --  name:               get_max_materials_qty
  --  create by:          Dalit A. Raviv
  --  Revision:           1.0
  --  creation date:      04/05/2015
  --  Purpose :           Get max material qty from setup table
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   04/05/2015    Dalit A. Raviv  initial build
  -----------------------------------------------------------------------
  FUNCTION get_max_materials_qty(p_pto_item_id       NUMBER,
		         p_price_list_id     NUMBER,
		         p_inventory_item_id NUMBER) RETURN NUMBER;

  --------------------------------------------------------------------
  --  customization code: CHG0034234 - Update PTO Validation Setup
  --  name:               get_pto_parent_category
  --  create by:          Dalit A. Raviv
  --  Revision:           1.0
  --  creation date:      04/05/2015
  --  Purpose :           Get pto parent category
  --                      if 'BDL-SC' return Y else N
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   04/05/2015    Dalit A. Raviv  initial build
  -----------------------------------------------------------------------
  FUNCTION get_pto_parent_category(p_line_id IN NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  customization code: CHG0032648 - PTO definition form
  --  name:               get_bdl_sc_dates
  --  create by:          Dalit A. Raviv
  --  Revision:           1.0
  --  creation date:      12/05/2015
  --  Purpose :           Get BDL_SC Start Date for oe_order_lines.attribute12
  --                      Called by trigger XXOE_ORDER_LINES_ALL_BUR_TRG2
  --                      Get BDL_SC end Date for oe_order_lines.attribute13
  --                      Called by trigger XXOE_ORDER_LINES_ALL_BUR_TRG2
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   12/05/2015    Dalit A. Raviv  initial build
  -----------------------------------------------------------------------
  PROCEDURE get_bdl_sc_dates(p_serial_number     IN VARCHAR2,
		     p_so_line_id        IN NUMBER,
		     p_entity            IN VARCHAR2,
		     p_pto_item_id       IN NUMBER,
		     p_price_list_id     IN NUMBER,
		     p_inventory_item_id IN NUMBER,
		     p_start_date        OUT VARCHAR2,
		     p_end_date          OUT VARCHAR2);

END xx_om_pto_so_line_attr_pkg;
/
