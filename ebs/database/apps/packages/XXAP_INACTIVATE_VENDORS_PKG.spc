CREATE OR REPLACE PACKAGE apps.xxap_inactivate_vendors_pkg AS
----------------------------------------------------------------------------------
--  Name:               xxap_inactivate_vendors_pkg
--  Created by:         Hubert, Eric
--  Revision:           1.0
--  Creation Date:      01-May-2021
--  Purpose:            Inactivate infrequently-used vendors
----------------------------------------------------------------------------------
--  Ver   Date          Name            Desc
--  1.0   01-May-2021   Eric Hubert     CHG0049706: initial build
----------------------------------------------------------------------------------

    /* Constants */
    c_log_method CONSTANT NUMBER := 1;

    /* Program parameters */
    p_ou_org_id             NUMBER;
    p_activity_cutoff_date  VARCHAR2(11);
    p_action_mode           VARCHAR2(10);
    p_execute_changes       VARCHAR2(1);
    p_update_vendor_name    ap_suppliers.vendor_name%TYPE;
    p_supplier_number       ap_suppliers.segment1%TYPE;
    
    /* Global Variable declaration for Logging unit */
    gv_log              VARCHAR2(1)     := fnd_profile.value('AFLOG_ENABLED');  --FND: Debug Log Enabled (default="N")
    gv_log_module       VARCHAR2(100)   := fnd_profile.value('AFLOG_MODULE'); --FND: Debug Log Module (default="%")
    gv_api_name         VARCHAR2(30)    := 'xxap_inactivate_vendors_pkg';
    gv_log_program_unit VARCHAR2(100);
    
    PROCEDURE main(
        p_err_code  OUT NUMBER
        ,p_err_msg  OUT VARCHAR2
    );

    FUNCTION before_report RETURN BOOLEAN;

    FUNCTION after_report RETURN BOOLEAN;
END xxap_inactivate_vendors_pkg;
/