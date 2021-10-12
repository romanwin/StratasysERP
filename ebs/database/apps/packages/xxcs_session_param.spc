CREATE OR REPLACE PACKAGE xxcs_session_param AS
   TYPE number_table_type IS TABLE OF NUMBER INDEX BY BINARY_INTEGER;
   number_sec number_table_type;

   TYPE date_table_type IS TABLE OF DATE INDEX BY BINARY_INTEGER;
   date_sec date_table_type;

   TYPE char_table_type IS TABLE OF VARCHAR2(100) INDEX BY BINARY_INTEGER;
   char_sec char_table_type;

   char_rec VARCHAR2(250);

   FUNCTION set_session_param_date(p_date IN DATE, p_sec IN NUMBER)
      RETURN NUMBER;
   FUNCTION set_session_param_number(p_no IN NUMBER, p_sec IN NUMBER)
      RETURN NUMBER;
   FUNCTION set_session_param_char(p_no IN VARCHAR2, p_sec IN NUMBER)
      RETURN NUMBER;

   FUNCTION get_session_param_date(p_sec IN NUMBER) RETURN DATE;

   FUNCTION get_session_param_number(p_sec IN NUMBER) RETURN NUMBER;

   FUNCTION get_session_param_char(p_sec IN NUMBER) RETURN VARCHAR2;

   FUNCTION set_session_param_char_rec(p_no IN VARCHAR2) RETURN NUMBER;

   FUNCTION get_session_param_char_rec RETURN VARCHAR2;

END xxcs_session_param;
/

