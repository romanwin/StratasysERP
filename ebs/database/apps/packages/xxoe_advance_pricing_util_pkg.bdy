CREATE OR REPLACE PACKAGE BODY xxoe_advance_pricing_util_pkg IS

  --------------------------------------------------------------------
  --  name:            xxoe_advance_pricing_util_pkg
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   1.5.11
  --  cust:            
  --------------------------------------------------------------------

  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  1.5.11      yuval tal         initial build
  --  1.1  12/03/2016  Diptasurjya       CHG0039786 - Add p_top_model_line_id as parameter 
  --                   Chatterjee        to procedure get_up_sell_item
  --------------------------------------------------------------------

  ----------------------------------------------
  -- get_up_sell_item
  -- used in adv pricing : XXSELLUP attribute plsql att
  ----------------------------------------------
  FUNCTION get_up_sell_item(p_item_id IN NUMBER, p_top_model_line_id IN VARCHAR2) RETURN VARCHAR2 IS
  
    CURSOR c_item_rel IS
      SELECT 'Y'
        FROM mtl_related_items_all_v y
       WHERE y.relationship_type_id = 4
         AND y.inventory_item_id = p_item_id;
    l_result VARCHAR2(1);
  BEGIN
    if p_top_model_line_id is null then -- CHG0039786
      OPEN c_item_rel;
      FETCH c_item_rel
        INTO l_result;
      CLOSE c_item_rel;
    else                                -- CHG0039786
      return 'N';                       -- CHG0039786
    end if;                             -- CHG0039786
  
    RETURN nvl(l_result, 'N');
  EXCEPTION
  
    WHEN OTHERS THEN
      RETURN 'N';
  END;

END xxoe_advance_pricing_util_pkg;
/
