CREATE OR REPLACE PACKAGE BODY xxwsh_gtms_util_pkg IS
  --------------------------------------------------------------------
  --  customization code: CHG0034901
  --  name:               XXWSH_GTMS_UTIL_PKG
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  creation date:      19/05/2015
  --  Description:        General utilities to be used by GTMS
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   19/05/2015    Michal Tzvik    initial build
  --  1.1   14.9.17       yuval tal       INC0102209 add get_serials_and_lots/get_delivery_serials
  --------------------------------------------------------------------

  ----------------------------------------------------------------------
  --  customization code: CHG0034901
  --  name:               apps_initialize
  --  create by:          Michal Tzvik
  --  creation date:      19/05/2015
  --  Purpose :           CHG0034901
  --                      run fnd_global.apps_initialize
  --  Parameters:
  --                      x_err_code: 0-success, 1-error
  --                      x_err_msg: error message (if x_err_code != 0)
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   19/05/2015    Michal Tzvik    CHG0034901 - Initial Build
  ----------------------------------------------------------------------
  PROCEDURE apps_initialize(p_user_id      IN NUMBER,
		    p_resp_id      IN NUMBER,
		    p_resp_appl_id IN NUMBER,
		    x_err_code     OUT NUMBER,
		    x_err_msg      OUT VARCHAR2) IS
    l_is_valid VARCHAR2(1);
    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    x_err_code := 0;
    x_err_msg  := '';
  
    SELECT nvl(MAX('Y'), 'N')
    INTO   l_is_valid
    FROM   fnd_user_resp_groups_direct furgd
    WHERE  furgd.user_id = p_user_id
    AND    furgd.responsibility_id = p_resp_id
    AND    furgd.responsibility_application_id = p_resp_appl_id;
  
    IF l_is_valid = 'N' THEN
      x_err_code := 1;
      x_err_msg  := 'Invalid user_id/resp_id/resp_appl_id';
      RETURN;
    END IF;
  
    fnd_global.apps_initialize(user_id      => p_user_id, --
		       resp_id      => p_resp_id, --
		       resp_appl_id => p_resp_appl_id);
  EXCEPTION
    WHEN OTHERS THEN
      x_err_code := 1;
      x_err_msg  := 'Unexpected error: ' || SQLERRM;
  END apps_initialize;

  ----------------------------------------------------------------------
  --  customization code: CHG0034901
  --  name:               mo_global_init
  --  create by:          Michal Tzvik
  --  creation date:      19/05/2015
  --  Purpose :           CHG0034901
  --                      run mo_global.init
  --  Parameters:
  --                      x_err_code: 0-success, 1-error
  --                      x_err_msg: error message (if x_err_code != 0)
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   19/05/2015    Michal Tzvik    CHG0034901 - Initial Build
  ----------------------------------------------------------------------
  PROCEDURE mo_global_init(p_module_code IN VARCHAR2,
		   x_err_code    OUT NUMBER,
		   x_err_msg     OUT VARCHAR2) IS
    l_is_valid VARCHAR2(1);
    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    x_err_code := 0;
    x_err_msg  := '';
  
    mo_global.init(p_appl_short_name => p_module_code);
  
  EXCEPTION
    WHEN OTHERS THEN
      x_err_code := 1;
      x_err_msg  := 'Unexpected error: ' || SQLERRM;
  END mo_global_init;

  -------------------------------
  --- get_serials_and_lots
  -------------------------------
  --  ver   date          name            desc
  ------------------------------------------------------------------------------------------
  --  1.1   14.9.17       yuval tal       INC0102209 add get_serials_and_lots/get_delivery_serials
  --------------------------------

  FUNCTION get_serials_and_lots(p_order_line_id NUMBER,
		        p_reference_id  NUMBER DEFAULT NULL,
		        p_str_len       NUMBER DEFAULT NULL)
    RETURN VARCHAR2 IS
  BEGIN
  
    RETURN xxinv_utils_pkg.get_serials_and_lots(p_order_line_id,
				p_reference_id,
				p_str_len);
  
  END;

  -------------------------------
  --- get_delivery_serials
  ---------------------------------
  --  ver   date          name            desc
  -------------------------------------------------------------------------------------------------
  --  1.1   14.9.17       yuval tal       INC0102209 add get_serials_and_lots/get_delivery_serials
  --------------------------------

  FUNCTION get_delivery_serials(p_delivery_name VARCHAR2 DEFAULT NULL,
		        p_order_line_id NUMBER) RETURN VARCHAR2 IS
  BEGIN
  
    RETURN xxinv_utils_pkg.get_delivery_serials(p_delivery_name,
				p_order_line_id);
  
  END;

END xxwsh_gtms_util_pkg;
/
