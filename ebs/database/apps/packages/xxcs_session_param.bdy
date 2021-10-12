CREATE OR REPLACE PACKAGE BODY xxcs_session_param AS
   -- deafults:
   ---------date_sec(1)= cut off date
   --SET the parameters
   -- specific code:
   --  session_param_date 100 -> employee_hierarchy
   ----date_sec(1)            -> cut off date
   --------------------
   FUNCTION set_session_param_date(p_date IN DATE, p_sec IN NUMBER)
      RETURN NUMBER IS
   BEGIN
      date_sec(p_sec) := p_date;
      --  g_mgr := p_mgr ;
      RETURN(1);
   END set_session_param_date;

   FUNCTION set_session_param_number(p_no IN NUMBER, p_sec IN NUMBER)
      RETURN NUMBER IS
   BEGIN
      number_sec(p_sec) := p_no;
      --  g_mgr := p_mgr ;
      RETURN(1);
   END set_session_param_number;

   FUNCTION set_session_param_char(p_no IN VARCHAR2, p_sec IN NUMBER)
      RETURN NUMBER IS
   BEGIN
      char_sec(p_sec) := p_no;
      --  g_mgr := p_mgr ;
      RETURN(1);
   END set_session_param_char;

   --GET the parameters Value
   --------------------------- 
   FUNCTION get_session_param_date(p_sec IN NUMBER) RETURN DATE IS
   BEGIN
      RETURN(date_sec(p_sec));
   END;

   FUNCTION get_session_param_number(p_sec IN NUMBER) RETURN NUMBER IS
   BEGIN
      RETURN(number_sec(p_sec));
   END;

   FUNCTION get_session_param_char(p_sec IN NUMBER) RETURN VARCHAR2 IS
   BEGIN
      RETURN(char_sec(p_sec));
   END;

   ----------------------------
   FUNCTION set_session_param_char_rec(p_no IN VARCHAR2) RETURN NUMBER IS
   BEGIN
      char_rec := p_no;
      --  g_mgr := p_mgr ;
      RETURN(1);
   END set_session_param_char_rec;

   FUNCTION get_session_param_char_rec RETURN VARCHAR2 IS
   BEGIN
      RETURN(char_rec);
   END get_session_param_char_rec;

END xxcs_session_param;
/

