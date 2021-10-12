CREATE OR REPLACE PACKAGE xxwsh_gtms_util_pkg IS
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
  --                      run apps_initialize for GTMS
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
		    x_err_msg      OUT VARCHAR2);

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
		   x_err_msg     OUT VARCHAR2);

  FUNCTION get_serials_and_lots(p_order_line_id NUMBER,
		        p_reference_id  NUMBER DEFAULT NULL,
		        p_str_len       NUMBER DEFAULT NULL)
    RETURN VARCHAR2;

  FUNCTION get_delivery_serials(p_delivery_name VARCHAR2 DEFAULT NULL,
		        p_order_line_id NUMBER) RETURN VARCHAR2;

END xxwsh_gtms_util_pkg;
/
