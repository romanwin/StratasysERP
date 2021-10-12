CREATE OR REPLACE PACKAGE xxobjt_interface_check AUTHID CURRENT_USER AS
  ---------------------------------------------------------------------------
  -- $Header: xxobjt_interface_check   $
  ---------------------------------------------------------------------------
  -- Package: xxobjt_interface_check
  -- Created:
  -- Author  : yuval tal
  --------------------------------------------------------------------------
  -- Perpose: support dynamic check for interface tables
  ---------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  11.2.2013  yuval tal            Initial Build

  PROCEDURE handle_check(p_group_id     NUMBER,
                         p_table_name   VARCHAR2,
                         p_table_source VARCHAR2,
                         p_check_id     NUMBER DEFAULT NULL,
                         p_id           NUMBER,
                         p_err_code     OUT NUMBER,
                         p_err_message  OUT VARCHAR2);

  FUNCTION get_err_string(p_group_id   NUMBER,
                          p_table_name VARCHAR2,
                          p_id         NUMBER) RETURN VARCHAR2;

  PROCEDURE insert_error(p_err_rec xxobjt_interface_errors%ROWTYPE);

  FUNCTION get_check_name(p_check_id NUMBER) RETURN VARCHAR2;
  PROCEDURE check_sql(p_sql VARCHAR2);

  PROCEDURE assign_check(p_check_id NUMBER, p_table_source VARCHAR2);
  FUNCTION get_check_sql(p_check_id NUMBER) RETURN VARCHAR2;

  FUNCTION is_check_assigned(p_check_id NUMBER) RETURN NUMBER;
END;
/
