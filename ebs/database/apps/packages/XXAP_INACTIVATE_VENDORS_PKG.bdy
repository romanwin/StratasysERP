CREATE OR REPLACE PACKAGE BODY apps.xxap_inactivate_vendors_pkg AS
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
    c_new_disabled_date CONSTANT DATE := SYSDATE;
    
    /* Action Modes (corresponds to parameter p_action_mode, which is free text) */
    c_am_inactivate   CONSTANT VARCHAR2(10) := 'INACTIVATE'; --This is the only mode available to users
    c_am_reactivate   CONSTANT VARCHAR2(10) := 'REACTIVATE'; --Useful for testing multiple times in an environment as it will reactivate suppliers
    c_am_none         CONSTANT VARCHAR2(10) := 'NONE'; --For debugging/testing

    /* Return/error codes for procedures */
    c_success      CONSTANT NUMBER := 0; --Success
    c_fail         CONSTANT NUMBER := 1; --Fail
    
    c_yes VARCHAR2(1) := 'Y';
    c_no  VARCHAR2(1) := 'N';
    
    ----------------------------------------------------------------------------------------------------
    --  Name:               write_message
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      01-May-2021
    --  Purpose:            Write debug/log messages
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   01-May-2021   Hubert, Eric    Initial Build
    ----------------------------------------------------------------------------------------------------
    PROCEDURE write_message(
        p_msg VARCHAR2,
        p_file_name VARCHAR2 DEFAULT fnd_file.log
    ) IS    
        c_method_name CONSTANT VARCHAR(30) := 'write_message';
    BEGIN
        CASE
        WHEN c_log_method = 0 THEN --No logging
            NULL;
        
        /* Concurrent request and fnd_file.log. */
        WHEN c_log_method = 1 and fnd_global.conc_request_id <> '-1' THEN
            /* Write to concurrent request log file. */
            fnd_file.put_line(
                which => p_file_name,
                --buff  => p_msg
                buff  => p_msg
                );

        /* fnd_log_messages */
        WHEN c_log_method = 2 THEN
            /* Write to fnd_log_messages. */
            fnd_log.string(
                log_level => fnd_log.level_unexpected,
                --module    => gv_api_name || gv_log_program_unit,
                module    => gv_api_name || '.' || gv_log_program_unit,
                message   => p_msg
                );
                
        /* dbms_output */
        WHEN c_log_method = 3 THEN
            dbms_output.put_line(p_msg);
        ELSE --Other - do nothing
            NULL;
        END CASE;
    END write_message;

    ----------------------------------------------------------------------------------------------------
    --  Name:               update_vendor_name
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      01-May-2021
    --  Purpose:            Update the name of the vendor
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   01-May-2021   Hubert, Eric    CHG0049706: Initial Build
    ----------------------------------------------------------------------------------------------------
    PROCEDURE update_vendor_name(
        p_party_id          IN NUMBER
        ,p_obj_ver_num      IN NUMBER
        ,p_vendor_name      IN VARCHAR2
        ,p_err_code         OUT NUMBER
        ,p_err_msg          OUT VARCHAR2
    ) IS
        c_method_name CONSTANT VARCHAR(30) := 'update_vendor_name'; 
        
        /* Local variables */
        l_organization_rec hz_party_v2pub.organization_rec_type;
        
        x_profile_id            NUMBER;
        l_object_version_number NUMBER := p_obj_ver_num;
        l_msg_count             NUMBER;
        l_msg_data              VARCHAR2(4000);
        l_return_status         VARCHAR2(10);
            
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('program unit: ' || gv_log_program_unit);
        
        l_organization_rec.party_rec.party_id := p_party_id;
        l_organization_rec.organization_name  := p_vendor_name;
        
        write_message('Before rename ' || l_organization_rec.organization_name);        
        
        hz_party_v2pub.update_organization (
            p_init_msg_list                 => fnd_api.g_true,
            p_organization_rec              => l_organization_rec,
            p_party_object_version_number   => l_object_version_number,
            x_profile_id                    => x_profile_id,
            x_return_status                 => l_return_status,
            x_msg_count                     => l_msg_count,
            x_msg_data                      => l_msg_data
        );
        
        write_message('l_return_status: ' || l_return_status);              
        
        IF l_return_status = fnd_api.g_ret_sts_success THEN
            p_err_code := c_success;
        ELSE
            p_err_code := c_fail;
        END IF;    
        
        FOR i IN 1..l_msg_count
        
        LOOP
        
            l_msg_data := l_msg_data || SUBSTR(FND_MSG_PUB.GET(p_encoded => 'T'), 1, 255);
        
             dbms_output.put_line(l_msg_data);
        
        END LOOP ;
        
        p_err_msg := l_msg_data;
        
    EXCEPTION WHEN OTHERS THEN
        p_err_code := c_fail;
        p_err_msg  := ('Exception in ' || c_method_name || ': ' || SQLERRM );
        write_message('p_err_msg: ' || p_err_msg);
    END update_vendor_name;

    ----------------------------------------------------------------------------------------------------
    --  Name:               revised_vendor_name
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      01-Apr-2021
    --  Purpose:            Determine the revised vendor name based upon whether it is being 
    --                      inactivated or activated.
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   01-May-2021   Hubert, Eric    CHG0049706: Initial Build
    ----------------------------------------------------------------------------------------------------
    PROCEDURE revised_vendor_name(
        p_vendor_name       IN OUT po_vendors.vendor_name%TYPE
        ,p_suffix           IN VARCHAR2 DEFAULT NULL
        ,p_err_code         OUT NUMBER
        ,p_err_msg          OUT VARCHAR2
    ) IS
        c_method_name CONSTANT VARCHAR(30) := 'revised_vendor_name';
        
        l_vendor_name   po_vendors.vendor_name%TYPE;
        l_suffix        VARCHAR2(30);
        l_err_msg       VARCHAR2(1000);
        l_err_code      NUMBER;
            
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('program unit: ' || gv_log_program_unit);
        
        /* Use the sufix passed to the procedure, if provided. */
        l_suffix := COALESCE(p_suffix, ' [INACTIVE ' || TO_CHAR(c_new_disabled_date, 'DD-MON-YYYY') || ']');
        
        CASE p_action_mode
        WHEN c_am_inactivate THEN
            /* Append text to vendor name indicating that they are inactive. */
            l_vendor_name := p_vendor_name || l_suffix;
            l_err_code := c_success;
        
        WHEN c_am_reactivate THEN
            /* First check if the suffix is found in the vendor name. We do this
               because we also call this procedure just to test for the existence
               of the suffix, without actually changing the vendor name.
            */
            IF INSTR(p_vendor_name, l_suffix) > 0 THEN
                /* Remove suffix and return just the vendor name. */
                l_vendor_name := REPLACE(p_vendor_name, l_suffix, NULL);
                l_err_code := c_success;
            ELSE
                l_err_code := c_fail;
                l_err_msg := '"' || l_suffix || ' " not found in vendor name.';
            END IF;
            
        ELSE
            l_vendor_name := p_vendor_name;
            l_err_code := c_fail;
            l_err_msg := 'Unrecognized mode';
        END CASE;
        
        p_vendor_name := l_vendor_name;
        p_err_code := l_err_code;

    EXCEPTION WHEN OTHERS THEN
        p_err_code := c_fail;
        p_err_msg  := ('Exception in ' || c_method_name || ': ' || SQLERRM );
        write_message('p_err_msg: ' || p_err_msg);
    END revised_vendor_name;

    ----------------------------------------------------------------------------------------------------
    --  Name:               update_names_for_vendors
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      01-May-2021
    --  Purpose:            Update the names of the vendors inactivated/reactivated during the concurrent request.
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   01-May-2021   Hubert, Eric    CHG0049706: Initial Build
    ----------------------------------------------------------------------------------------------------
    PROCEDURE update_names_for_vendors(
        p_err_code         OUT NUMBER
        ,p_err_msg         OUT VARCHAR2
    ) IS
        c_method_name CONSTANT VARCHAR(30) := 'update_names_for_vendors';         
        
        /* Local variables */
        l_vendor_name       VARCHAR2(360);
        l_api_result_msg    VARCHAR2(100);
        l_err_msg           VARCHAR2(1000);
        l_err_code          NUMBER;
        
        CURSOR gtt_cur IS
            SELECT *
            FROM xxap_vendor_activity_rvw_temp
            WHERE 1=1
                AND action_executed_flag = c_yes
                AND proposed_action = p_action_mode
            FOR UPDATE OF message;
        
        l_gtt_cur gtt_cur%ROWTYPE;
       
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('program unit: ' || gv_log_program_unit);
        
        OPEN gtt_cur;
    
        /* Loop thorugh all Vendors to be inactivated*/
        LOOP
            FETCH gtt_cur INTO l_gtt_cur;
            EXIT WHEN gtt_cur%NOTFOUND;

            l_vendor_name  := l_gtt_cur.vendor_name;
            
            /* Append/replace text after vendor name indicating that they are inactive/active. */
            revised_vendor_name(
                p_vendor_name   => l_vendor_name --In/out
                ,p_suffix       => NULL --use suffix as defined in procedure
                ,p_err_code     => l_err_code
                ,p_err_msg      => l_err_msg
            );

            write_message('l_vendor_name: ' || l_vendor_name);
            
            /* Check if revised name was determined. */
            IF l_err_code = c_success THEN
            
                /* Update the name of the supplier. */
                update_vendor_name(
                    p_party_id          => l_gtt_cur.party_id
                    ,p_obj_ver_num      => l_gtt_cur.party_object_version_number
                    ,p_vendor_name      => l_vendor_name
                    ,p_err_code         => l_err_code
                    ,p_err_msg          => l_err_msg
                );
    
                /* Check if name was updated. */
                IF l_err_code = c_success THEN
                    l_api_result_msg := 'Name updated.';
                ELSE
                    l_api_result_msg := 'Name update failed.';
                END IF;
                
            ELSE
                l_api_result_msg := l_err_msg;
            END IF;
            
            write_message('l_api_result_msg: ' || l_api_result_msg);
            
            /* Update the temp table with the recommendation and message. (To avoid an exception, we can't commit until we are outside of the loop.) */
            UPDATE xxap_vendor_activity_rvw_temp
            SET message = l_gtt_cur.message || '; ' || l_api_result_msg
            WHERE CURRENT OF gtt_cur;
        END LOOP;
        
        COMMIT;
        
        CLOSE gtt_cur;

        p_err_code := c_success;
        p_err_msg := NULL;
        
    EXCEPTION WHEN OTHERS THEN
        p_err_code := c_fail;
        p_err_msg  := ('Exception in ' || c_method_name || ': ' || SQLERRM );
        write_message('p_err_msg: ' || p_err_msg);
    END update_names_for_vendors;

    ----------------------------------------------------------------------------------------------------
    --  Name:               recommend_inactivation
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      01-May-2021
    --  Purpose:            Evaulate business rules to determine if a supplier should be inactivated.
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   01-May-2021   Hubert, Eric    CHG0049706: Initial Build
    ----------------------------------------------------------------------------------------------------
    FUNCTION recommend_inactivation(
        p_activity_cutoff_date          IN DATE
        ,p_ou_org_id                    IN NUMBER
        ,p_r0_vendor_enabled_flag       IN VARCHAR2
        ,p_r0_vendor_start_date_active  IN DATE
        ,p_r1_sole_org_id               IN NUMBER
        ,p_r2_has_open_po_flag          IN VARCHAR2
        ,p_r3_last_po_creation_date     IN VARCHAR2
        ,p_r4_last_paid_invoice_date    IN VARCHAR2
        ,p_r5_has_unpaid_invoice_flag   IN VARCHAR2
        ,p_r6_is_person_flag            IN VARCHAR2
        ,p_r7_explicit_exclusion_flag   IN VARCHAR2
        
    ) RETURN VARCHAR2
    IS
        c_method_name CONSTANT VARCHAR(30) := 'recommend_inactivation';   
        
        l_result VARCHAR2(1) := c_no;
    
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('program unit: ' || gv_log_program_unit);

        /*
            Business Rules Evaluated:
            0) Vendor must have been created on/before [activity cutt-off date], and is currently active.
            1) Vendor must be a US supplier. This is one that has supplier sites defined exclusively within the US operating unit.  
                There must be at least one site.  (Example of vendor with zero sites: 681001 has zero sites).
            2) Vendor does not have open POs.
            3) Vendor must not have been used in the US or in IL since [activity cutt-off date] (inclusive).
            4) Vendor does not have a recently-paid invoice (since [activity cutt-off date], inclusive).
            5) Vendor does not have unpaid invoices.
            6) Vendor must not be linked to an employee record.
            7) Explicit exclusions, including vendors that represent government entities should be excluded.  We don't have a way to identify these, so they'll be explicitly flagged by Vendor ID.
        */        
        IF 1=1     
            /* Rule 0*/
            AND (
                    p_r0_vendor_enabled_flag = c_yes --Don't recommend inactivation if already inactivated.
                    AND TRUNC(p_r0_vendor_start_date_active) <= p_activity_cutoff_date
                )
            /* Rule 1 */
            AND p_r1_sole_org_id = p_ou_org_id
            
            /* Rule 2 */
            AND p_r2_has_open_po_flag <> c_yes
            
            /* Rule 3 */
            AND (
                p_r3_last_po_creation_date  <= p_activity_cutoff_date
                OR p_r3_last_po_creation_date  IS NULL
            )
            
            /* Rule 4 */
            AND (
                p_r4_last_paid_invoice_date <= p_activity_cutoff_date 
                OR p_r4_last_paid_invoice_date IS NULL
            )
            
            /* Rule 5 */
            AND NVL(p_r5_has_unpaid_invoice_flag, c_no) <> c_yes
            
            /* Rule 6 */
            AND NVL(p_r6_is_person_flag, c_no) <> c_yes
            
            /* Rule 7 */
            AND NVL(p_r7_explicit_exclusion_flag, c_no) <> c_yes
        THEN
            l_result := c_yes; --All criteria met to recommend inactivating the supplier.
        ELSE
            l_result := c_no;  --One or more criteria not met.
        END IF;
        
        RETURN  l_result;
    
    EXCEPTION WHEN OTHERS THEN
        write_message('Exception in ' || c_method_name || ': ' || SQLERRM );
        RETURN c_no;    
    
    END recommend_inactivation;    

    ----------------------------------------------------------------------------------------------------
    --  Name:               main
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      01-May-2021
    --  Purpose:            Inactivate the vendor and update the vendors names.  
    --
    --                      There is a also a limited way to reactivate vendors that we inactivated using this program.
    --                      However, this was mainly built as a testing aid (to "reset" vendors) and this functionality
    --                      is not exposed to users running the concurrent program as the paramater is not displayed.
    --                      The cutoff date parameter is used to specify the date of inactivation in the "REACTIVATE"
    --                      mode.
    --
    --  Description:
    --    1) Populate a row into temp table for each active vendor, based upon view having same columns.
    --    2) Loop through each vendor in temp table and make a recommendation regarding their inactivation (or reactivation).
    --    3) If in execute mode, then call the API to inactivate (reactivate) the vendor.
    --    4) Update the temp table with the recommendation and the result of the inactivation (reactivation), which will be queried by the data template.
    --    5) If in execute mode, update the vendor names en masse.

    --    There is not a need to set the enabled flag to "N" to disable a supplier.  
    --    Setting the inactive date is sufficient.  Also, there are complications with
    --    a buyer re-enabling a supplier if the enabled flag was programatically disabled.
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   01-May-2021   Hubert, Eric    CHG0049706: Initial Build
    ----------------------------------------------------------------------------------------------------    
    PROCEDURE main(
        p_err_code  OUT NUMBER
        ,p_err_msg  OUT VARCHAR2
    )
    IS
        /* Constants */
        c_method_name   CONSTANT VARCHAR(30) := 'main'; 
        c_delimiter     CONSTANT VARCHAR2(1) := CHR(9); --Tab character
        c_commit_on     CONSTANT BOOLEAN := TRUE;  --Commit after each call to the API
     
        /* Local variables*/
        l_activity_cutoff_date          DATE;
        l_vendor_name                   po_vendors.vendor_name%TYPE;
        l_proposed_action               VARCHAR2(10);
        l_action_executed_flag          VARCHAR2(1) := c_no;
        l_return_status                 VARCHAR2(1) := NULL;
        l_msg_count                     NUMBER := 0;
        l_msg_data                      VARCHAR2(2000) := NULL;
        l_row_number                    NUMBER := 0;
        l_log_message                   VARCHAR2(500);
        l_api_result_msg                VARCHAR2(100);
        l_err_msg                       VARCHAR2(1000);
        l_err_code                      NUMBER;
        
        /* Cursor that return active vendors and a recommendation for inactivation. */
        CURSOR gtt_cur IS
            SELECT *
            FROM xxap_vendor_activity_rvw_temp
            FOR UPDATE OF
                proposed_action
                ,message;
    
        l_gtt_cur gtt_cur%ROWTYPE;
    
        l_vendor_rec ap_vendor_pub_pkg.r_vendor_rec_type;
        
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('program unit: ' || gv_log_program_unit);
        
        /* Write program parameters to log */
        write_message('p_ou_org_id: ' || p_ou_org_id);
        write_message('p_activity_cutoff_date: ' || p_activity_cutoff_date);
        write_message('p_action_mode: ' || p_action_mode);
        write_message('p_execute_changes: ' || p_execute_changes);
        write_message('p_update_vendor_name: ' || p_update_vendor_name);
        write_message('p_supplier_number: ' || p_supplier_number);
        
        l_activity_cutoff_date := TO_DATE(p_activity_cutoff_date, 'DD-MON-YYYY'); --Parameter is passed to procedure as text.
    
        /* Initialize */
        mo_global.init('PO');

        /* Clear the gloal temp table. */
        EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxap_vendor_activity_rvw_temp'; --need to have xxobjt.
     
        /* Populate global temp table */
        INSERT INTO xxap_vendor_activity_rvw_temp
        SELECT *
        FROM xxap_vendor_activity_review_v
        WHERE 1=1
            /* Conditionally-filter on vendor enabled based on the mode. */
            AND (
                CASE
                WHEN r0_vendor_end_date_active IS NULL AND p_action_mode = c_am_inactivate THEN
                    1
                WHEN r0_vendor_end_date_active = p_activity_cutoff_date AND p_action_mode = c_am_reactivate THEN --Repurposing p_activity_cutoff_date to be the inactive date criterion.
                    1
                WHEN p_action_mode = c_am_none THEN
                    1
                ELSE
                    0
                END
                ) = 1
            /* Optional filter on a specific vendor. */
            AND (
                    supplier_number = p_supplier_number 
                    OR p_supplier_number IS NULL
                ) --Optional filter on a specific vendor.
        ORDER BY supplier_number;

        /* Write a tab-delimited column header row to the log file. */
        l_log_message := ('Row Number' || CHR(9) || 'Vendor ID' || CHR(9) || 'Vendor Name'  || CHR(9) || 'Status' || CHR(9) || 'Message');
                    
        OPEN gtt_cur;
    
        /* Loop thorugh all Vendors to be inactivated*/
        LOOP
            FETCH gtt_cur INTO l_gtt_cur;
            EXIT WHEN gtt_cur%NOTFOUND;
            
            /* Reinitialize some variables for the loop. */
            l_action_executed_flag  := c_no;
            l_proposed_action       := c_am_none;
            l_return_status         := NULL;
            
            /* Populate the local variables that will be passed to the API.*/
            l_row_number := l_row_number + 1;  --increment row counter
            write_message('l_row_number: ' || l_row_number);
            write_message('l_gtt_cur.vendor_name: ' || l_gtt_cur.vendor_name);
            
            CASE p_action_mode
            WHEN c_am_inactivate THEN
                
                /* Determine if the vendor should be inactivated. */
                IF recommend_inactivation(
                    p_activity_cutoff_date          => l_activity_cutoff_date
                    ,p_ou_org_id                    => p_ou_org_id
                    ,p_r0_vendor_enabled_flag       => l_gtt_cur.r0_vendor_enabled_flag
                    ,p_r0_vendor_start_date_active  => l_gtt_cur.r0_vendor_start_date_active
                    ,p_r1_sole_org_id               => l_gtt_cur.r1_sole_org_id
                    ,p_r2_has_open_po_flag          => l_gtt_cur.r2_has_open_po_flag
                    ,p_r3_last_po_creation_date     => l_gtt_cur.r3_last_po_creation_date
                    ,p_r4_last_paid_invoice_date    => l_gtt_cur.r4_last_paid_invoice_date
                    ,p_r5_has_unpaid_invoice_flag   => l_gtt_cur.r5_has_unpaid_invoice_flag
                    ,p_r6_is_person_flag            => l_gtt_cur.r6_is_person_flag
                    ,p_r7_explicit_exclusion_flag   => l_gtt_cur.r7_explicit_exclusion_flag
                ) = c_yes THEN
                    
                    l_proposed_action := c_am_inactivate;
                    l_vendor_rec.end_date_active   := c_new_disabled_date; --End Date
                    
                ELSE
                    l_proposed_action := c_am_none;
                END IF;
            
            WHEN c_am_reactivate THEN
                
                /* Determine if the vendor should be reactivated. */
                l_vendor_name  := l_gtt_cur.vendor_name;
                
                revised_vendor_name(
                    p_vendor_name   => l_vendor_name --In/out
                    ,p_suffix       => NULL --use suffix as defined in procedure
                    ,p_err_code     => l_err_code
                    ,p_err_msg      => l_err_msg
                );
                
                IF l_err_code = c_success THEN --Suffix was found in vendor name
                    
                    l_proposed_action := c_am_reactivate;
                    l_vendor_rec.end_date_active   := FND_API.G_MISS_DATE; --Null
                
                ELSE
                    l_proposed_action := c_am_none;
                END IF;
                
            ELSE
                l_proposed_action := c_am_none;
            END CASE;
            
            write_message('l_proposed_action: ' || l_proposed_action);
            
            /* Attempt to inactivate the vendor if the necessary criteria are met. */
            IF p_action_mode = c_am_inactivate
                AND p_execute_changes = c_yes
                AND l_proposed_action = c_am_inactivate THEN
                    
                    /* Call API to update (inactivate) the vendor. */   
                    ap_vendor_pub_pkg.update_vendor(
                        p_api_version       => 1.0
                        ,p_init_msg_list    => fnd_api.g_true
                        ,p_commit           => fnd_api.g_false
                        ,p_validation_level => fnd_api.g_valid_level_full
                        ,x_return_status    => l_return_status
                        ,x_msg_count        => l_msg_count
                        ,x_msg_data         => l_msg_data
                        ,p_vendor_rec       => l_vendor_rec
                        ,p_vendor_id        => l_gtt_cur.vendor_id
                    );
                    
            ELSIF p_action_mode = c_am_reactivate
                AND p_execute_changes = c_yes
                AND l_proposed_action = c_am_reactivate THEN
                
                    /* Call API to update (activate) the vendor. */   
                    ap_vendor_pub_pkg.update_vendor(
                        p_api_version       => 1.0
                        ,p_init_msg_list    => fnd_api.g_true
                        ,p_commit           => fnd_api.g_false
                        ,p_validation_level => fnd_api.g_valid_level_full
                        ,x_return_status    => l_return_status
                        ,x_msg_count        => l_msg_count
                        ,x_msg_data         => l_msg_data
                        ,p_vendor_rec       => l_vendor_rec
                        ,p_vendor_id        => l_gtt_cur.vendor_id
                    );
            END IF;

                IF p_execute_changes = c_yes AND l_proposed_action = p_action_mode THEN
                    
                    /* Call API to update (inactivate) the vendor. */   
                    ap_vendor_pub_pkg.update_vendor(
                        p_api_version       => 1.0
                        ,p_init_msg_list    => fnd_api.g_true
                        ,p_commit           => fnd_api.g_false
                        ,p_validation_level => fnd_api.g_valid_level_full
                        ,x_return_status    => l_return_status
                        ,x_msg_count        => l_msg_count
                        ,x_msg_data         => l_msg_data
                        ,p_vendor_rec       => l_vendor_rec
                        ,p_vendor_id        => l_gtt_cur.vendor_id
                    );
                END IF;
            
            BEGIN

                /* Update messages.*/
                CASE
                WHEN p_execute_changes <> c_yes OR p_action_mode = c_am_none THEN
                    l_api_result_msg := 'Inquiry mode (no change made to vendor)';
                    l_log_message := (l_row_number || CHR(9) || l_gtt_cur.vendor_id || CHR(9) || l_gtt_cur.vendor_name || CHR(9) || l_api_result_msg);
                
                WHEN p_execute_changes = c_yes AND l_proposed_action = c_am_none THEN
                    l_api_result_msg := 'No action proposed';
                    l_log_message := (l_row_number || CHR(9) || l_gtt_cur.vendor_id || CHR(9) || l_gtt_cur.vendor_name || CHR(9) || l_api_result_msg);
                
                WHEN l_return_status = 'S' AND p_action_mode = c_am_inactivate THEN
                    l_api_result_msg := 'Vendor inactivated';
                    l_action_executed_flag := c_yes;

                WHEN l_return_status = 'S' AND p_action_mode = c_am_reactivate THEN
                    l_api_result_msg := 'Vendor reactivated';
                    l_action_executed_flag := c_yes;

                WHEN l_return_status <> 'S' AND p_action_mode = c_am_inactivate THEN
                    l_api_result_msg := 'Unable to inactivate vendor';   

                WHEN l_return_status <> 'S' AND p_action_mode = c_am_reactivate THEN
                    l_api_result_msg := 'Unable to reactivate vendor';   
                
                ELSE
                    l_action_executed_flag := c_no;
                    l_api_result_msg := 'Unknown exception';
                    l_log_message := (l_row_number || CHR(9) || l_gtt_cur.vendor_id || CHR(9) || l_gtt_cur.vendor_name || CHR(9) || 'EXCEPTION' || CHR(9) || 'Msg Count' || l_msg_count || ', Error : ' || l_msg_data);
                
                END CASE;
                
                write_message(l_log_message);
                write_message('l_api_result_msg: ' || l_api_result_msg);
                
                /* Update the temp table with the recommendation and message. (To avoid an exception, we can't commit until we are outside of the loop.) */
                UPDATE xxap_vendor_activity_rvw_temp
                SET
                    proposed_action = l_proposed_action
                    ,action_executed_flag = l_action_executed_flag
                    ,message = l_api_result_msg
                WHERE CURRENT OF gtt_cur;

            END; 
           
        END LOOP;

        COMMIT;
        
        CLOSE gtt_cur;
        
        /* Update the names of all of the vendors that were inactivated during this request. */
        IF p_update_vendor_name = c_yes AND p_execute_changes = c_yes THEN
            update_names_for_vendors(
                p_err_code => l_err_code
                ,p_err_msg => l_err_msg
            );
            
            /* Check result of renaming vendor. */
            IF l_err_code = c_success THEN
                p_err_code := c_success;
                p_err_msg  := NULL;
            ELSE
                p_err_code := c_fail;
                p_err_msg  := 'Renaming vendors failed';        
            END IF;
        ELSE
            p_err_code := c_success;
            p_err_msg  := NULL;        
        END IF;

        write_message('p_err_code: ' || p_err_code);
        write_message('p_err_msg: ' || p_err_msg);
    
    EXCEPTION WHEN OTHERS THEN
        ROLLBACK;
        p_err_code := 1;
        p_err_msg := ('Exception in ' || c_method_name || ': ' || SQLERRM );
        write_message('p_err_msg: ' || p_err_msg);
    END main;    

    ----------------------------------------------------------------------------------------------------
    --  Name:               before_report
    --  Created By:         Hubert, Eric
    --  Revision:           1.1
    --  Creation Date:      01-Apr-2021
    --  Purpose:            This is the "before report" trigger.
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   01-Apr-2021   Hubert, Eric    CHG0049706: initial build
    ----------------------------------------------------------------------------------------------------        
    FUNCTION before_report RETURN BOOLEAN IS
        c_method_name CONSTANT VARCHAR(30) := 'before_report'; 
        
        /* Other Local Variables */
        l_err_msg   VARCHAR2(1000);
        l_err_code  NUMBER;
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('program unit: ' || gv_log_program_unit);
        
        xxap_inactivate_vendors_pkg.main(
            p_err_code  => l_err_code
            ,p_err_msg  => l_err_msg
        );
        
        IF l_err_code <> c_success THEN
            RETURN FALSE;
        ELSE
            RETURN TRUE;
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            write_message('Exception in ' || c_method_name || ': ' || SQLERRM );
            RETURN FALSE;

    END before_report;

    ----------------------------------------------------------------------------------------------------
    --  Name:               after_report
    --  Created By:         Hubert, Eric
    --  Revision:           1.1
    --  Creation Date:      01-Apr-2021
    --  Purpose:            This is the "after report" trigger.  The global temp table is truncated.
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   01-Apr-2021   Hubert, Eric    CHG0049706: initial build
    ----------------------------------------------------------------------------------------------------        
    FUNCTION after_report RETURN BOOLEAN IS
        c_method_name CONSTANT VARCHAR(30) := 'after_report'; 
        
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('program unit: ' || gv_log_program_unit);
        
        /* Clear the gloal temp table. */
        EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxap_vendor_activity_rvw_temp'; --need to have xxobjt.
        
        RETURN TRUE;
        
    EXCEPTION
        WHEN OTHERS THEN
            write_message('Exception in ' || c_method_name || ': ' || SQLERRM );
            RETURN FALSE;

    END after_report;

END xxap_inactivate_vendors_pkg;
/