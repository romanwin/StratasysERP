CREATE OR REPLACE PACKAGE BODY xxgtms_util_pkg IS
  --------------------------------------------------------------------
  --  customization code: CHG0034901
  --  name:               XXGTMS_UTIL_PKG
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  creation date:      19/05/2015
  --  Description:        General utilities to be used by GTMS
  --                     ***** INSTAED OF PACKAGE XXWSH_GTMS_UTIL_PKG *****
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

  ------------------
  --------------------------------------------------------------------
  --  customization code: CHG0035965
  --  name:               get_rate_cur_for_xml
  --  create by:          Diptasurjya Chatterjee
  --  Revision:           1.0
  --  creation date:      04-AUG-2015
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
		        p_org_id    NUMBER) RETURN VARCHAR2 IS
  
    v_currency_code VARCHAR2(10);
  
  BEGIN
    SELECT currency_code
    INTO   v_currency_code
    FROM   po_headers_all
    WHERE  segment1 = p_po_number
    AND    org_id = p_org_id
    AND    type_lookup_code IN ('STANDARD', 'BLANKET');
  
    /*v_currency_code := xxpo_communication_report_pkg.get_rate_cur_for_xml(po_number => p_po_number, --
    p_relsase_num => p_relsase_num);*/
  
    RETURN v_currency_code;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_rate_cur_for_xml;

  --------------------------------------------------------------------
  --  customization code: CHG0035965
  --  name:               update_promised_date
  --  create by:          Diptasurjya Chatterjee
  --  Revision:           1.0
  --  creation date:      04-AUG-2015
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
  /*FUNCTION update_promised_date(p_po_number        VARCHAR2,
                                p_po_release_num   NUMBER DEFAULT NULL,
                                p_org_id           NUMBER,
                                p_line_num         NUMBER,
                                p_shipment_num     NUMBER,
                                p_new_promise_date DATE) RETURN NUMBER IS
    PRAGMA AUTONOMOUS_TRANSACTION;
    l_update_status   NUMBER := 0;
    l_launch_workflow VARCHAR2(1);
    l_api_error_msg   VARCHAR2(4000);
    l_api_errors      po_api_errors_rec_type;
  
    l_po_type_code VARCHAR2(200);
    l_release_num  NUMBER;
    l_revision_num NUMBER;
  
    l_user_id NUMBER;
    l_resp_id NUMBER;
  
    CURSOR cur_check_po_approval IS
      SELECT decode(approved_flag, NULL, 'N', 'Y'),
             revision_num
      FROM   po_headers_all
      WHERE  segment1 = p_po_number
      AND    org_id = p_org_id;
  
    CURSOR cur_check_rel_approval IS
      SELECT decode(pra.approved_flag, NULL, 'N', 'Y'),
             pra.revision_num
      FROM   po_headers_all  pha,
             po_releases_all pra
      WHERE  pha.segment1 = p_po_number
      AND    pha.org_id = p_org_id
      AND    pha.po_header_id = pra.po_header_id
      AND    pra.release_num = p_po_release_num;
  BEGIN
    mo_global.init('PO');
    mo_global.set_org_access(p_org_id_char     => p_org_id,
                             p_sp_id_char      => NULL,
                             p_appl_short_name => 'PO');
  
    mo_global.set_policy_context('S', p_org_id);
  
    BEGIN
      SELECT fur.user_id,
             fur.responsibility_id
      INTO   l_user_id,
             l_resp_id
      FROM   fnd_user_resp_groups_all fur,
             fnd_user                 fu
      WHERE  fur.responsibility_application_id = 201
      AND    fur.user_id = fu.user_id
      AND    fu.user_name = 'GTMS_USER'
      AND    rownum = 1;
    EXCEPTION
      WHEN no_data_found THEN
        raise_application_error(-20101,
                                'ERROR: User-responsibility not found while intializing application');
    END;
    fnd_global.apps_initialize(user_id      => l_user_id,
                               resp_id      => l_resp_id,
                               resp_appl_id => 201);
  
    l_release_num := p_po_release_num;
  
    -- Check Mandatory parameters
    IF p_po_number IS NULL OR p_org_id IS NULL OR p_shipment_num IS NULL OR
       p_line_num IS NULL OR p_new_promise_date IS NULL THEN
      raise_application_error(-20101,
                              'ERROR: PO Number, Org ID, Line Number, Shipment Number and new promise date is mandatory for promise date update');
    END IF;
  
    -- Fetch PO type
    BEGIN
      SELECT type_lookup_code
      INTO   l_po_type_code
      FROM   po_headers_all
      WHERE  segment1 = p_po_number
      AND    org_id = p_org_id
      AND    type_lookup_code IN ('STANDARD', 'BLANKET');
    EXCEPTION
      WHEN no_data_found THEN
        raise_application_error(-20101,
                                'ERROR: PO Number and Organization ID combination does not exist');
      WHEN OTHERS THEN
        raise_application_error(-20101,
                                'ERROR: Unexpected exception while validation PO number and Org ID. ' ||
                                SQLERRM);
    END;
  
    -- Validate release number based on PO type
    IF l_po_type_code = 'BLANKET' AND l_release_num IS NULL THEN
      raise_application_error(-20101,
                              'ERROR: Release number must be provided for blanket PO');
    ELSIF l_po_type_code <> 'BLANKET' THEN
      l_release_num := NULL;
    END IF;
  
    -- Determine if Workflow is to be launched based on approval history of PO / Release
    IF l_release_num IS NULL THEN
      -- Standard PO
      OPEN cur_check_po_approval;
      FETCH cur_check_po_approval
        INTO l_launch_workflow,
             l_revision_num;
    
      CLOSE cur_check_po_approval;
    ELSE
      -- Blanket Release
      OPEN cur_check_rel_approval;
      FETCH cur_check_rel_approval
        INTO l_launch_workflow,
             l_revision_num;
    
      CLOSE cur_check_rel_approval;
    END IF;
  
    --dbms_output.put_line('Vals: '||p_po_number||' '||l_release_num||' '||l_revision_num||' '||p_line_num||' '||p_shipment_num||' '||p_new_promise_date||' '||l_launch_workflow||' '||p_org_id);
    -- Call Standard Oracle API to update PO
    l_update_status := po_change_api1_s.update_po(x_po_number           => p_po_number,
                                                  x_release_number      => l_release_num,
                                                  x_revision_number     => l_revision_num,
                                                  x_line_number         => p_line_num,
                                                  x_shipment_number     => p_shipment_num,
                                                  new_quantity          => NULL,
                                                  new_price             => NULL,
                                                  new_promised_date     => p_new_promise_date,
                                                  new_need_by_date      => NULL,
                                                  launch_approvals_flag => l_launch_workflow,
                                                  update_source         => 'API',
                                                  version               => '1.0',
                                                  x_override_date       => NULL,
                                                  x_api_errors          => l_api_errors,
                                                  p_buyer_name          => NULL,
                                                  p_secondary_quantity  => NULL,
                                                  p_preferred_grade     => NULL,
                                                  p_org_id              => p_org_id);
  
    IF l_update_status <> 1 THEN
      FOR i IN 1 .. l_api_errors.message_text.count LOOP
        l_api_error_msg := l_api_error_msg || l_api_errors.message_text(i) ||
                           chr(10);
      END LOOP;
    
      ROLLBACK;
      raise_application_error(-20101,
                              'ERROR: API error while updating Promise Date. ' ||
                              l_api_error_msg);
    ELSE
      BEGIN
        IF l_po_type_code = 'BLANKET' THEN
          UPDATE po_line_locations_all
          SET    attribute4 = to_char(p_new_promise_date, 'rrrr/MON/dd')
          WHERE  line_location_id =
                 (SELECT plla.line_location_id
                  FROM   po_headers_all        pha,
                         po_lines_all          pla,
                         po_releases_all       pra,
                         po_line_locations_all plla
                  WHERE  pha.segment1 = p_po_number
                  AND    pha.org_id = p_org_id
                  AND    pra.release_num = l_release_num
                  AND    pla.line_num = p_line_num
                  AND    plla.shipment_num = p_shipment_num
                  AND    pha.po_header_id = plla.po_header_id
                  AND    pla.po_header_id = pha.po_header_id
                  AND    pla.po_line_id = plla.po_line_id
                  AND    pra.po_header_id = pha.po_header_id
                  AND    pra.po_release_id = plla.po_release_id);
        ELSE
          UPDATE po_line_locations_all
          SET    attribute4 = to_char(p_new_promise_date, 'rrrr/MON/dd')
          WHERE  line_location_id =
                 (SELECT plla.line_location_id
                  FROM   po_headers_all        pha,
                         po_lines_all          pla,
                         po_line_locations_all plla
                  WHERE  pha.segment1 = p_po_number
                  AND    pha.org_id = p_org_id
                  AND    pla.line_num = p_line_num
                  AND    plla.shipment_num = p_shipment_num
                  AND    pha.po_header_id = plla.po_header_id
                  AND    pla.po_header_id = pha.po_header_id
                  AND    pla.po_line_id = plla.po_line_id);
        END IF;
        COMMIT;
      EXCEPTION
        WHEN OTHERS THEN
          ROLLBACK;
          l_update_status := 0;
          raise_application_error(-20101,
                                  'ERROR: Failed to update original promised date on attribute4 in po_line_locations_all');
      END;
    END IF;
  
    RETURN l_update_status;
  END update_promised_date;*/

  --------------------------------------------------------------------
  --  customization code: CHG0035965
  --  name:               get_rate_cur_for_xml
  --  create by:          Diptasurjya Chatterjee
  --  Revision:           1.0
  --  creation date:      04-AUG-2015
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

  FUNCTION get_first_approve_date(p_po_header_id NUMBER,
		          p_type         VARCHAR2) RETURN DATE IS
  
  BEGIN
  
    RETURN xxpo_utils_pkg.get_first_approve_date(p_po_header_id, p_type);
  
  END;

END xxgtms_util_pkg;
/
