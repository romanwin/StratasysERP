CREATE OR REPLACE PACKAGE BODY xxpo_vpd_security_pkg IS
  --------------------------------------------------------------------
  --  name:             xxpo_vpd_security_pkg
  --  ver  date        name              desc
  --  1.0  15  .5.11  YUVAL TAL    initial build

  -- vpd rules

  /* BEGIN
   --dbms_rls.drop_policy(object_schema         => 'PO',object_name => 'PO_LINES_ALL', policy_name => 'XXPOSEC');
    
    dbms_rls.add_policy(object_schema         => 'PO',
                        object_name           => 'PO_LINES_ALL',
                        policy_name           => 'XXPOSEC',
                        function_schema       => 'APPS',
                        policy_function       => 'xxpo_vpd_security_pkg.po_lines_sec',
                        sec_relevant_cols     => 'ITEM_DESCRIPTION',
                        sec_relevant_cols_opt => dbms_rls.all_rows);
  
  END;*/

  --------------------------------------------------------------------
  --  purpose :  Add vpd rulew to po objects 
  FUNCTION po_lines_sec(obj_schema VARCHAR2, obj_name VARCHAR2)
    RETURN VARCHAR2 IS
  
  BEGIN
  
    RETURN 'xxpo_vpd_security_pkg.get_po_lines_sec_flag(po_header_id)=1';
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN '1=1';
    
  END;
  ----------------------------------------------
  -- get_po_lines_sec_flag
  ----------------------------------------------------

  FUNCTION get_po_lines_sec_flag(p_po_header_id NUMBER) RETURN NUMBER IS
    CURSOR c IS
      SELECT 'Y'
        FROM po_headers_all t
       WHERE nvl(t.attribute1, 'N') = 'Y'
         AND t.po_header_id = p_po_header_id
         AND fnd_global.user_id NOT IN
             (SELECT flex_value
                FROM fnd_flex_values_vl p, fnd_flex_value_sets vs
               WHERE --flex_value = p_code
               p.flex_value_set_id = vs.flex_value_set_id
            AND vs.flex_value_set_name = 'XX_HR_PO_LIST'
            AND p.enabled_flag = 'Y');
  
    l_tmp VARCHAR2(1);
  
  BEGIN
    -- check sec flag is Y and user not in list
    OPEN c;
    FETCH c
      INTO l_tmp;
    IF nvl(l_tmp, 'N') = 'Y' THEN
      RETURN 0;
    ELSE
      RETURN 1;
    END IF;
  
    CLOSE c;
  END;

  -----------------------------------------
  -- get_default_sec_flag
  -----------------------------------------
  FUNCTION get_default_sec_flag RETURN VARCHAR2 IS
  
    CURSOR c IS
      SELECT 'Y'
        FROM fnd_flex_values_vl p, fnd_flex_value_sets vs
       WHERE --flex_value = p_code            
       p.flex_value_set_id = vs.flex_value_set_id
       AND vs.flex_value_set_name = 'XX_HR_PO_LIST'
       AND p.enabled_flag = 'Y'
       AND fnd_global.user_id = flex_value;
    l_tmp VARCHAR2(5);
  BEGIN
    OPEN c;
    FETCH c
      INTO l_tmp;
    CLOSE c;
  
    RETURN nvl(l_tmp, 'N');
  END;

END xxpo_vpd_security_pkg;
/

