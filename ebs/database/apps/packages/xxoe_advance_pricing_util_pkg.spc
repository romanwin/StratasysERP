CREATE OR REPLACE PACKAGE xxoe_advance_pricing_util_pkg IS
  --------------------------------------------------------------------
  --  name:            xxoe_advance_pricing_util_pkg
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   1.5.11
  --  cust:            
  --------------------------------------------------------------------
  --  purpose :        advanced pricing 
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  1.5.11  yuval tal             initial build
  --  1.1  12/03/2016  Diptasurjya       CHG0039786 - Add p_top_model_line_id as parameter 
  --                   Chatterjee        to procedure get_up_sell_item
  --------------------------------------------------------------------
  FUNCTION get_up_sell_item(p_item_id IN NUMBER, p_top_model_line_id IN VARCHAR2) RETURN VARCHAR2;

END xxoe_advance_pricing_util_pkg;
/
