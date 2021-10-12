CREATE OR REPLACE PACKAGE xxpo_vpd_security_pkg IS

  FUNCTION po_lines_sec(obj_schema VARCHAR2, obj_name VARCHAR2)
    RETURN VARCHAR2;

  FUNCTION get_po_lines_sec_flag(p_po_header_id NUMBER) RETURN NUMBER;
  FUNCTION get_default_sec_flag RETURN VARCHAR2;
END xxpo_vpd_security_pkg;
/

