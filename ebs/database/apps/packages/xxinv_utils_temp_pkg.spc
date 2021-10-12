CREATE OR REPLACE PACKAGE xxinv_utils_temp_pkg IS

   FUNCTION get_delivery_serials(p_delivery_name VARCHAR2 DEFAULT NULL,
                                 p_order_line_id NUMBER) RETURN VARCHAR2;
END xxinv_utils_temp_pkg;
/

