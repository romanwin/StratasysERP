CREATE OR REPLACE PACKAGE xxinv_onhand_asofdate_pkg IS

  -- Author  : ELLA.MALCHI
  -- Created : 27-Jan-10 20:27:57
  -- Purpose : 

  FUNCTION calc_onhand_asofdate(p_asofdate        IN DATE,
                                p_organization_id IN NUMBER)
  --RETURN xxinv_onhand_asofdate_tbl_type;
   RETURN NUMBER;

END xxinv_onhand_asofdate_pkg;
/

