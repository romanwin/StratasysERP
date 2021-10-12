CREATE OR REPLACE PACKAGE xxgtms_util_pkg AUTHID DEFINER IS
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
  --  1.1   08/04/2015    Diptasurjya     CHG0035965 - New function update_promised_date 
  --                                      This function will update a standard PO or a
  --                                      purchase release based on the parameters provided
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

  --------------------------------------------------------------------
  --  name:            get_rate_cur_for_xml
  --  create by:       Diptasurjya Chatterjee
  --  Revision:        1.0
  --  creation date:   04-AUG-2015
  --------------------------------------------------------------------
  --  purpose :        CHG0035965 - This function will return the currency code for
  --                   given PO number and Org ID.
  --                   The function will return currency code for
  --                   STANDARD or BLANKET POs only
  --------------------------------------------------------------------
  --  ver    date           name             desc
  --  1.0    04-AUG-2015    Diptasurjya      Initial Build
  --                        Chatterjee
  --------------------------------------------------------------------
  FUNCTION get_rate_cur_for_xml(p_po_number VARCHAR2,
		        p_org_id    NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  name:            update_promised_date
  --  create by:       Diptasurjya Chatterjee
  --  Revision:        1.0
  --  creation date:   04-AUG-2015
  --------------------------------------------------------------------
  --  purpose :        CHG0035965 - This function will update a standard PO or a
  --                   purchase release based on the parameters provided
  --                     1. p_po_number - STANDARD / BLANKET PO Number
  --                     2. p_po_release_num - If BLANKET PO
  --                     3. p_org_id - OU Org ID
  --                     4. p_line_num - PO / Release line number
  --                     5. p_shipment_num - PO / Release Shipment number
  --                     6. p_new_promise_date - New Promise Date
  --------------------------------------------------------------------
  --  ver    date           name             desc
  --  1.0    04-AUG-2015    Diptasurjya      Initial Build
  --                        Chatterjee
  --------------------------------------------------------------------                              
  /* FUNCTION update_promised_date(p_po_number        VARCHAR2,
  p_po_release_num   NUMBER DEFAULT NULL,
  p_org_id           NUMBER,
  p_line_num         NUMBER,
  p_shipment_num     NUMBER,
  p_new_promise_date DATE) RETURN NUMBER;*/

  FUNCTION get_first_approve_date(p_po_header_id NUMBER,
		          p_type         VARCHAR2) RETURN DATE;

END xxgtms_util_pkg;
/
