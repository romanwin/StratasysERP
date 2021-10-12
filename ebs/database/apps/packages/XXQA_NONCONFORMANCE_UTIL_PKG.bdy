CREATE OR REPLACE PACKAGE BODY APPS.xxqa_nonconformance_util_pkg AS
----------------------------------------------------------------------------------------------------
--  Name:               xxqa_nonconformance_util_pkg
--  Created By:         Hubert, Eric
--  Revision:           4.0
--  Creation Date:      Dec-2016
--  Purpose:            CHG0040770 - Quality Nonconformance Report
----------------------------------------------------------------------------------------------------
--  Ver   Date          Name            Desc
--  1.0   Dec-2016      Hubert, Eric    S3 Initial Build
--  1.1   12-Jun-2017   Lingaraj(TCS)   CHG0040770 - Quality Nonconformance Report
--  2.0   20-Jun-2018   Hubert, Eric    CHG0042754:
--                                      -Renamed package to xxqa_nonconformance_util_pkg (was xxqa_nc_rpt_pkg)
--                                      -Added ability to programa  tically update Nonconformance Statuses
--                                      -Renamed function "f_report_data" to be "nonconformance_report_data"
--                                      -Renamed "f_report_parameter_lov" to "report_sequence_parameter_lov"
--                                      -Added columns to nonconformance_report_data: n_lot_number, n_email_addresses, n_manual_lot_serial_number, v_nc_comments_reference, d_quantity, d_capa_status, d_item_cost_frozen, d_nc_comments_reference, d_purchasing_entered_date
--  2.1   25-Jan-2019   Hubert, Eric    CHG0042589: enhanced update_nonconformance_status to optionally directly update qa_results without the results open interface for performance improvement and workaround for SR 3-19222349401 until Patch 17033939 can be applied.
--  3.0   16-Oct-2019   Hubert, Eric    CHG0042815: added procedures update_disposition_status, create_quality_action_log_row, build_action_log_message, log_manual_status_update
--  4.0   24-Oct-2019   Hubert, Eric    CHG0046276: Scrap disposition approval via XX Doc Approval Workflow
--  4.1   01-Apr-2020   Hubert, Eric    CHG0047103: 
--                                      -Email notification for material handlers after Scrap and Use As-Is dispositions are approved, to alert them of a new move order.
--                                      -Bug fixes for Scrap approval workflow
--                                      -deprecated submit_report_qa_notify
--                                      -bug fix for nonconformance_report_data
--                                      -print_ncr_from_occurrence performance improvement
--                                      -more consistent use of standardized return variables (p_err_msg and p_err_code)
--                                      -New programs: XXQA: Initiate Disposition Approval and XXQA: Create Disposition Move Orders
--  4.2   01-Apr-2021   Hubert, Eric    CHG0049611:
--                                      -Refactored nonconformance_report_data
--                                      -Refactored receiving_inspection_data
--                                      -Improved email format validation check for notifications (build_email_address_table)
--                                      -Disabled immediate NC/Disp status update upon Scrap workflow completion (Approve/Reject)
--                                      -Changed from hardcoded "Yes" to value of profile to determine if update_nonconformance_status is called when running XXQA: Nonconformance Report
----------------------------------------------------------------------------------------------------
/*  Bug/Enhancement List for this package:
To Do for CHG0049611:
-COMPLETED (high) remoed ref cursor cur_dynamic as it was not used.
-COMPLETED (high) Add email address format validation
-COMPLETED (med) Refactor nc_report_data SQL to use bind variables for nc, v, d numbers in the where clauses.
-COMPLETED (low) Add optional p_occurrence parameter to nc_report_data function.

Deferred tasks from CHG0047103:
-OPEN (low): Are get_global_value and set_global_value needed?  I don't see code referencing them in this package, quality actions, or forms personalizations.  Delete this on a future CR if it is dead code.
-DEFERRED (med): [NOT STARTED] create procedure to purge notification HTML files for old/inactive disposition workflows.  Need to see of html is retreieved from file for each notification.
-CANCELLED (low): [NOT STARTED] consider deleting a burst file if wf status is reset to NEW.  user may want to change a value on the disp record and reinitiate the wf with a revised notification.  workaround exists, however. Update 4/23/20: the bursting process will overwrite files with the same name.  We don't need to manually delete the file.
-DEFERRED (low): [NOT STARTED] get the org id via the occurrence rather than the MFG_ORGANIZATION_ID profile.  Functions that need the org id may not be called from a session that has set the this profile value.  Update 4/23/20: the only functions that use this profile (print_rir_from_collection_id and print_rir_from_occurrence) are indeed called from a forms session so there is very little risk in the current approach.
-DEFERRED (low): make cur_results in update_disposition_status be based on gv_nc_rpt_tab, which has a limited set of rows, rather than all dispositions.  And/or add optional filter for Disposition to limit to just Scrap, for example. Update 4/23/20: the performance of this cursor really isn't much of an issue (performance issue was with one of the disp status criteria calling is_xml).
-DEFERRED (med): RTV output has no disposition row but the disp is still being updated to PENDING_PURCHASING.  May need to check content of email program before attempting to burst.  Could burst to file and check contents for disposition number before updating status.  #difficult to reproduce this so am deferring#
-DEFERRED (low): update status to PENDING_APPROVAL if we "keep" existing workflows without canceling (wf mgmt option). #requires reworking of several business rules that add a lot of retesting for a condition that should not happen often and can be handled by manually updating the disp. status# 

Deferred tasks from CHG0046276:
-DEFERRED (med): In wf_inquire_open_doc_approvals, add wf msg and/or action log logging when exception ABORT_OPEN_WF_FAILURE is raised.
-DEFERRED (low): In override_disposition_status, build a function for getting the organization_id and plan_id from qa_results based on the disposition number. 

Deferred tasks from CHG0042815:
-DEFERRED (med): if no nonconformance XML is created (because of some SQL error in the data template), then supress the quality action log and status update activity in the after report trigger (which is based on "temp" table data, not XML).
-DEFERRED (low): make lov for XX_DISPOSITION_STATUS dynamic based on XX_DISPOSITION (for DISPOSITION_xxx collection plan), if possible, using dynamic LOV functionality.
-DEFERRED (low): Resolve error with err_buf being too small for log message contained in variable, l_log_comment.
-DEFERRED (low): make business rules in qa_notify_before_report be data-driven instead of hard-coded.

To do on future Change Requests, as time/resources permit:
-DEFERRED (low): add n_total_dispositions to custom type and reference it in update_nonconformance_status.
*/

    /* Types of views Oracle generates for quality collection plans */
    c_plan_view_type_result CONSTANT VARCHAR2(10) := 'RESULT'; --Type of collection plan view for viewing results
    c_plan_view_type_import CONSTANT VARCHAR2(10) := 'IMPORT'; --Type of collection plan view for importing/updating results
    
    /* Statuses for monitoring of the Collection Import process */
    c_import_status_s       CONSTANT VARCHAR2(30) := 'STARTED';      --Monitoring of Collection Import process has started.
    c_import_status_n       CONSTANT VARCHAR2(30) := 'NOT_REQUIRED'; --Monitoring of Collection Import process is not required.
    c_import_status_c       CONSTANT VARCHAR2(30) := 'COMPLETED';    --Monitoring of Collection Import process has completed.
    c_import_status_t       CONSTANT VARCHAR2(30) := 'TIMED_OUT';    --Monitoring of Collection Import process has timed-out.
    c_import_status_e       CONSTANT VARCHAR2(30) := 'EXCEPTION';    --Monitoring of Collection Import process had an exception.
    c_max_sleep_duration    CONSTANT NUMBER       := 600;      --Max total time (seconds) to sleep while monitoring the Collection Import process.  We may want to consider making this a profile option or concurrent request parameter in the future.

    /* Return/error codes for procedures */
    c_success      CONSTANT NUMBER := 0; --Success
    c_fail         CONSTANT NUMBER := 1; --Fail

    /* Workflow types */
    c_wf_item_type_xxwfdoc  CONSTANT VARCHAR2(100) := 'XXWFDOC';

    /* Constants for XXOBJT_WF_DOC_STATUS Value Set Values (CHG0046276)*/
    c_xwds_approved    CONSTANT VARCHAR2(10) :=  'APPROVED';
    c_xwds_cancelled   CONSTANT VARCHAR2(10) :=  'CANCELLED';
    c_xwds_error       CONSTANT VARCHAR2(10) :=  'ERROR';
    c_xwds_inprocess   CONSTANT VARCHAR2(10) :=  'IN_PROCESS';
    c_xwds_rejected    CONSTANT VARCHAR2(10) :=  'REJECTED';

    /* Workflow action codes used in XX Doc Approval (CHG0046276)*/
    c_ac_answer     CONSTANT VARCHAR2(10) := 'ANSWER';
    c_ac_approve    CONSTANT VARCHAR2(10) := 'APPROVE';
    c_ac_cancel     CONSTANT VARCHAR2(10) := 'CANCEL';
    c_ac_forward    CONSTANT VARCHAR2(10) := 'FORWARD';
    c_ac_info       CONSTANT VARCHAR2(10) := 'INFO';
    c_ac_no_action  CONSTANT VARCHAR2(10) := 'NO_ACTION';
    c_ac_question   CONSTANT VARCHAR2(10) := 'QUESTION';
    c_ac_reject     CONSTANT VARCHAR2(10) := 'REJECT';
    c_ac_submit     CONSTANT VARCHAR2(10) := 'SUBMIT';
    c_ac_waiting    CONSTANT VARCHAR2(10) := 'WAITING';

    /* Constants for emails (CHG0047103)*/
    c_email_donotreply          CONSTANT VARCHAR2(50) := 'Please.Do.Not.Reply@stratasys.com';
    c_egs_supplier_quality      CONSTANT qa_results.character1%TYPE := '_SUPPLIER_QUALITY'; --This is the email group suffix.  The org code prefix is prepended in a procedure.
    c_egs_material_handler_s    CONSTANT qa_results.character1%TYPE := '_MATERIAL_HANDLERS_S'; --This is the email group suffix.  The org code prefix is prepended in a procedure. -Scrap
    c_egs_material_handler_uai  CONSTANT qa_results.character1%TYPE := '_MATERIAL_HANDLERS_UAI'; --This is the email group suffix.  The org code prefix is prepended in a procedure. --Use As-Is

    /* Local constants for recipient types (To, CC, BCC) (CHG0074103: moved to body declaration from build_email_address_table procedure) */
    c_recipient_type_to         CONSTANT VARCHAR2(10) := 'TO'; --"To" recipient on email 
    c_recipient_type_cc         CONSTANT VARCHAR2(10) := 'CC'; --"Cc" recipient on email 
    c_recipient_type_bcc        CONSTANT VARCHAR2(10) := 'BCC'; --"Bcc" recipient on email
    c_recipient_type_from       CONSTANT VARCHAR2(10) := 'FROM'; --Sender of email 
    c_recipient_type_reply_to   CONSTANT VARCHAR2(10) := 'REPLY_TO'; --Reply to email
    c_recipient_type_no_email   CONSTANT VARCHAR2(10) := 'NO_EMAIL'; --An email will not be sent to this address but may be included for reference in the email body.  This an alternative to BCC.
    
    /* Constants for event names passed from PL/SQL blocks on "Docs - Extra" tab of Objet Doc Approval Set Up form (CHG0046276). */
    c_doc_before_approval       CONSTANT VARCHAR2(30) := 'BEFORE_APPROVAL';
    c_doc_after_user_approval   CONSTANT VARCHAR2(30) := 'AFTER_USER_APPROVAL';
    c_doc_after_approval        CONSTANT VARCHAR2(30) := 'AFTER_APPROVAL';
    c_doc_after_reject          CONSTANT VARCHAR2(30) := 'AFTER_REJECTION';

    /* Constants for directories */
    c_directory_qa_wf           CONSTANT VARCHAR2(100) := 'XXQA_DISP_APPROVAL_ATTMNT_DIR'; --(CHG0047103) In lower environments this is /mnt/oracle/qa/wf

    /* Constants for concurrent request output files (CHG0047103)*/
    c_file_name_element_separator   CONSTANT VARCHAR2(1) := '_'; --separator between data elements that constitute the file name produced by a quality-related concurrent program's post-processing or bursting
    c_ext_pdf                       CONSTANT VARCHAR2(5) := '.PDF';
    c_ext_html                      CONSTANT VARCHAR2(5) := '.HTML';

    /* Constants relating to move orders (CHG0074103)*/
    c_mo_batch_prefix           CONSTANT VARCHAR2(30)  := 'BATCH='; --Used in conjunction with the Print Event DFF on mtl_txn_request_lines
    
    /* Constants for use with override_disposition_status's p_source_ref parameter (o.d.s.s.r) */
    c_odssr_fp CONSTANT VARCHAR2(30) := 'FORMS_PERSONALIZATION';
        
    ----------------------------------------------------------------------------------------------------
    -- BEGIN FORWARD DECLARATION of private functions & procedures defined later in this package
    ----------------------------------------------------------------------------------------------------
    FUNCTION blob_to_clob (
        p_data  IN  BLOB --CHG0046276
    ) RETURN CLOB;
    
    FUNCTION delimited_list_to_rows(--CHG0042815
        p_delimited_string IN VARCHAR2
        ,p_delimiter       IN VARCHAR2
    ) RETURN SYS_REFCURSOR;
    
    FUNCTION eval_disp_status_criteria( --CHG0042815
         p_organization_id        IN NUMBER
        ,p_disposition_number     IN qa_results.sequence7%TYPE
        ,p_criteria_sql_statement IN VARCHAR2
    ) RETURN BOOLEAN;

    FUNCTION get_delimited_email_recipients(--CHG0047103
        p_recipient_type      IN VARCHAR2
    ) RETURN VARCHAR2;
    
    FUNCTION get_notification_group_email(
        p_email_group_name IN VARCHAR2 --CHG0042815
    ) RETURN VARCHAR2;
    
    FUNCTION get_user_defined_element_value (--CHG0047103
        p_value_element_name IN qa_chars.name%TYPE
        ,p_occurrence        IN qa_results.occurrence%TYPE
    ) RETURN VARCHAR2;

    FUNCTION is_conc_request_bursted ( --CHG0047103
        p_request_id IN NUMBER
    ) RETURN VARCHAR2;

    FUNCTION qa_result_row_via_occurrence( --CHG0041284
        p_occurrence IN qa_results.occurrence%TYPE
    ) RETURN qa_results%ROWTYPE;

    FUNCTION get_scrap_account( --CHG0047103
        p_org_id IN NUMBER
    ) RETURN NUMBER;
 
    FUNCTION wf_get_doc_instance_row ( --CHG0046276
        p_doc_instance_id   NUMBER
    ) RETURN xxobjt_wf_doc_instance%ROWTYPE;--CHG0046276

    FUNCTION wf_get_last_doc_instance_row( --CHG0046276
        p_disposition_number   IN  qa_results.sequence7%TYPE
        ,p_doc_code            IN  xxobjt_wf_docs.doc_code%TYPE
    ) RETURN xxobjt_wf_doc_instance%ROWTYPE;
    
    FUNCTION move_output_file(p_file_name IN VARCHAR2) RETURN VARCHAR2; --CHG0047103

    PROCEDURE build_email_address_table; --CHG0042815
        
    PROCEDURE launch_collection_import( --CHG0042754
         p_transaction_type     IN  NUMBER
        ,p_wait_for_completion  IN  BOOLEAN
        ,p_max_sleep_duration   IN  NUMBER DEFAULT c_max_sleep_duration
        ,p_import_result_status OUT VARCHAR2
    );
    
    PROCEDURE mo_disposition_manager_main; --CHG0047103

    PROCEDURE wf_disposition_manager_main; --CHG0047103
    
    PROCEDURE wf_update_disposition_msg( --CHG0046276
        p_plan_id        IN  qa_plans.plan_id%TYPE
        ,p_occurrence    IN  qa_results.occurrence%TYPE
        ,p_new_value     IN  qa_results.character1%TYPE
        ,p_err_code      OUT NUMBER
    );
        
    PROCEDURE write_message(
        p_msg VARCHAR2,
        p_file_name VARCHAR2 DEFAULT fnd_file.log
    );

    PROCEDURE wf_initiate_scrap_approval ( --CHG0046276
        p_nvd_record            IN  apps.xxqa_nc_rpt_rec_type --CHG0047103
        ,p_doc_instance_id      OUT NUMBER
        ,p_err_code             OUT NUMBER
        ,p_err_msg              OUT VARCHAR2
    );

    ----------------------------------------------------------------------------------------------------
    -- END FORWARD DECLARATION of private functions & procedures
    ----------------------------------------------------------------------------------------------------

    ----------------------------------------------------------------------------------------------------
    -- BEGIN PUBLIC FUNCTIONS
    ----------------------------------------------------------------------------------------------------

    ----------------------------------------------------------------------------------------------------
    --  Name:               nonconformance_report_data
    --  Created By:         Hubert, Eric
    --  Revision:           1.3
    --  Creation Date:      Dec-2016
    --  Purpose:            CHG0040770 - Quality Nonconformance Report
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   Dec-2016      Hubert, Eric    S3 Initial Build
    --  1.1   12-June-2017  Lingaraj(TCS)   CHG0040770  - Quality Nonconformance Report
    --  1.2   21-May-2018   Hubert, Eric    Renamed "f_report_data" to "nonconformance_report_data"
    --  1.3   16-Oct-2019   Hubert, Eric    CHG0042815: -added xx_disposition_status to cursor
    --                                                  -added v_nc_notification_where_clause  
    --  1.4   24-Oct-2019   Hubert, Eric    CHG0046276: -added xx_workflow_message to cursor
    --  2.0   01-Apr-2021   Hubert, Eric    CHG0049611: -refactored dynamic SQL to use bind variables (removed v_nc_notification_where_clause)
    ----------------------------------------------------------------------------------------------------
    FUNCTION nonconformance_report_data (
         p_sequence_1_value    IN qa_results.character1%TYPE --Nonconformance Number (changed from VARCHAR2 to %TYPE CHG0049611)
        ,p_sequence_2_value    IN qa_results.character1%TYPE --Verify Nonconformance Number (changed from VARCHAR2 to %TYPE CHG0049611)
        ,p_sequence_3_value    IN qa_results.character1%TYPE --Disposition Number (changed from VARCHAR2 to %TYPE CHG0049611)
        ,p_organization_id     IN NUMBER
        ,p_occurrence          IN NUMBER DEFAULT NULL --Occurrence for a nonconformance, verification, or disposition result CHG0049611
        ,p_nc_active_flag      IN VARCHAR2 DEFAULT NULL --CHG0049611
        ,p_disp_active_flag    IN VARCHAR2 DEFAULT NULL --CHG0049611
        ,p_disposition_status  IN qa_results.character1%TYPE DEFAULT NULL --CHG0049611
        ,p_disposition         IN qa_results.character1%TYPE DEFAULT NULL --CHG0049611
    ) RETURN apps.xxqa_nc_rpt_tab_type
    --  Description:
    --    This function returns rows for the data required in the Quality
    --    Nonconformance Report.
    --    This package is required due to the dynamic way in which Oracle Quality
    --    stores results in qa_results.  There is no guarantee that a given
    --    collection element will be mapped to a specific column (CHARACTER1
    --    through CHARACTER100) in qa_results.  To work around this, we use the
    --    collection plan-specific result views that are generated by Oracle EBS.
    --    These result views abstract the underlying columns in qa_results by
    --    providing column names that are the same as the Collection Element name.
    --    Using these views solves the element-to-column mapping issue with
    --    qa_results.  However, each collection plan has its own unique results
    --    view, such that a "Nonconformance" collection plan in one org will have a
    --    different view than a nonconformance collection plan in another org.  To
    --    make sure that the correct view is used, we use dynamic SQL, with the
    --    Organization Code and Collection Play Type being the key variables in
    --    this SQL.  This allows us to have a "global" report rather than org
    --    -specific reports.
    --
    --    COMMENTARY ON PERFORMANCE 31-Dec-2018 (Eric Hubert): There is simplicity
    --      in using the named quality results views for making this procedure work
    --      for multiple nonconformance plans (diffeent orgs).  However, there is
    --      a performance price to be paid to use these views in the dynamic SQL
    --      statement.  A more complex, but perhaps better-performing option is
    --      to (dynamically) build the SQL against the qa_results table itself.  To do this
    --      would require interrogating qa_plan_chars for the result_column_name
    --      for each collection element assigned to the plan to get the column
    --      name in qa_results (there is a seeded private function for this). 
    --      [UPDATE 3/13/2019: the function, result_element_value, in this package, can 
    --      be used as a model for doing this.  The key thing is to examine this function
    --      for how to get the result column name but do so for every element on 
    --      a collection plan (maybe more appropriate would be for every column in the 
    --      type, xxqa_nonconformance_util_pkg.t_disposition_status_row.]
    --
    --      Also required would be getting foreign table
    --      values for those elements in which just the "ID" is stored, such as
    --      for item. This last detail would probably be the most complex part
    --      of using qa_results directly [UPDATE 3/13/2019: this has been partially 
    --      solved as part of the Dynamic LOVs CRs in the 
    --      xxqa_dynamic_lov_pkg.foreign_table_value function].  
    --
    --      Another option might be to add some
    --      new indexes to qa_results based on the "Sequence" fields utilized by
    --      XX_NONCONFORMANCE_NUMBER, XX_VERIFY_NC_NUMBER, and XX_DISPOSITION_NUMBER.  However,
    --      AD HOC testing with adding such indexes did not make a big impact.
    --      (end of COMMENTARY ON PERFORMANCE)
    --
    --  Inputs:
    --    p_sequence_1_value: Nonconformance Number (optional)
    --    p_sequence_2_value: Verify Nonconformance Number (optional)
    --    p_sequence_3_value: Disposition Number (optional)
    --    p_organization_id: Organization ID for which the quality nonconformance
    --    was entered.  (required)
    --    p_occurrence: Occurrence from nonconformance, verification, or disposition result record (optional)
    --    p_active_only_flag: 
    --    p_disposition_status: 
    --    p_disposition:
    --  Outputs:
    --    APPS.XXQA_NC_RPT_TAB_TYPE: contains one row for each branch
    --    (combination) in the quality result parent-child hierarchy for:
    --    Nonconformance Number>Verify Nonconformance Number>Disposition Number.
    --    p_sequence_1_value, p_sequence_2_value and
    --    p_sequence_3_value are optional.  
    --
    --  Future Enhancements:
    --
    IS
        c_method_name CONSTANT VARCHAR(30) := 'nonconformance_report_data'; 

        /* Local Variables */
        l_plan_type_code fnd_lookup_values.lookup_code%TYPE; --CHG0049611
        l_n_occurrence NUMBER; --CHG0049611
        l_v_occurrence NUMBER; --CHG0049611
        l_d_occurrence NUMBER; --CHG0049611

        /* View Names */
        l_view_name_n qa_plans.view_name%TYPE; --View name for org-specific Nonconformance collection plan
        l_view_name_v qa_plans.view_name%TYPE; --View name for org-specific Verify Nonconformance collection plan
        l_view_name_d qa_plans.view_name%TYPE; --View name for org-specific Disposition collection plan

        l_result_temp APPS.XXQA_NC_RPT_TAB_TYPE := APPS.XXQA_NC_RPT_TAB_TYPE();  -- Holds the result of the dynamic sql query

        /* Local variables for dynamic SQL */
        l_dynamic_sql   VARCHAR2(32000);  --Stores dynamic SQL statement
        
        ORG_NOT_NC_PROCESS_ENABLED EXCEPTION;

    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('program unit: ' || gv_log_program_unit);
        --write_message(c_output_header);

        /* Check that the organization is set up with a Nonconformance, Verify Nonconformance, and Disposition collection plan. (CHG0047103) */
        IF is_nc_process_enabled_org(p_organization_id => p_organization_id) <> c_yes THEN
            RAISE ORG_NOT_NC_PROCESS_ENABLED;
        END IF;

        /* Determine occurrence values (CHG0049611)*/
        IF p_occurrence IS NOT NULL THEN
            /* Get the plan type associated with the occurrence */
            l_plan_type_code := plan_type(p_plan_id => NULL, p_occurrence => p_occurrence);
            write_message('l_plan_type_code: ' || l_plan_type_code);
            
            /* Determine which collection plan's results need to be filtered by the occurremce. */
            CASE l_plan_type_code
            WHEN c_plan_type_code_n THEN
                l_n_occurrence := p_occurrence;
            WHEN c_plan_type_code_v THEN
                l_v_occurrence := p_occurrence;
            WHEN c_plan_type_code_d THEN
                l_d_occurrence := p_occurrence;
            ELSE
                NULL;
            END CASE;
        END IF;
        write_message('l_n_occurrence: ' || l_n_occurrence);
        write_message('l_v_occurrence: ' || l_v_occurrence);
        write_message('l_d_occurrence: ' || l_d_occurrence);

        /* Get the view names that will be used in the dynamic SQL. */
        l_view_name_n := collection_plan_view_name(p_plan_type => c_plan_type_code_n, p_organization_id => p_organization_id, p_view_type => c_plan_view_type_result); --View name for org-specific Nonconformance collection plan
        l_view_name_v := collection_plan_view_name(p_plan_type => c_plan_type_code_v, p_organization_id => p_organization_id, p_view_type => c_plan_view_type_result); --View name for org-specific Verify Nonconformance collection plan
        l_view_name_d := collection_plan_view_name(p_plan_type => c_plan_type_code_d, p_organization_id => p_organization_id, p_view_type => c_plan_view_type_result); --View name for org-specific Disposition collection plan

        --write_message('Names of views determined: ' || l_view_name_n || ', ' || l_view_name_v || ', ' || l_view_name_d);

        /* Verify that each view name is valid, in part to reduce risk of SQL injection.
           Oracle will raise the exception, ORA-44002: invalid object name, if one
           of these views do not exist.
        */
        l_view_name_n := DBMS_ASSERT.SQL_OBJECT_NAME(str => l_view_name_n);
        l_view_name_v := DBMS_ASSERT.SQL_OBJECT_NAME(str => l_view_name_v);
        l_view_name_d := DBMS_ASSERT.SQL_OBJECT_NAME(str => l_view_name_d);

        --write_message('Existence of views confirmed.');
        --write_message('Begin build of dynamic SQL.');

        /* Build a dynamic SQL Statement.  Note the use of the alternative quoting
           mechanism (Q') using "[" as the quote_delimiter.  This is to make the
           use of single quotes in the variable clearer. Note that bind variables
           are not, and cannot, be used because the view/table names will be
           different across orgs. (Bind variables can't be used to specify table or
           view names.)
        */
        l_dynamic_sql := Q'[
        /* This SQL returns all of the information required for the Quality
        Nonconformance Report.  This is affixed to nonconforming material as it
        progresses through an inspection and eventually disposiiton.  The report
        provides information at each of these three levels.  Therefore, it can be
        reprinted as information is entered/updated in each collection plan
        so that the report affixed to the nonconforming material is as up-to-date
        as possible.*/

        WITH sq_n
            /* Subquery for nonconformance-level data.*/
        AS (
            SELECT qnv.*
            ,ROW_NUMBER() OVER (PARTITION BY qnv.xx_nonconformance_number
            ORDER BY qnv.xx_nonconformance_number) nonconformance_row
            FROM  ]' || l_view_name_n || Q'[ qnv
            )
            ,sq_v
            /* Subquery for verify nonconformance-level data.*/
        AS (
            SELECT qiv.*
            ,ROW_NUMBER() OVER (PARTITION BY qiv.xx_nonconformance_no_reference
            ORDER BY qiv.xx_verify_nc_number) verify_nc_row
            ,count(qiv.xx_verify_nc_number) OVER (PARTITION BY qiv.xx_nonconformance_no_reference) verify_nc_row_count
            FROM ]' || l_view_name_v || Q'[ qiv
            )
            ,sq_d
            /* Subquery for disposition-level data.*/
        AS (
            SELECT qdv.*
            ,ROW_NUMBER() OVER (PARTITION BY qdv.xx_nonconformance_no_reference
            ORDER BY qdv.xx_disposition_number) disposition_row
            ,count(qdv.xx_disposition_number) OVER (PARTITION BY qdv.xx_nonconformance_no_reference) disposition_row_count
            FROM ]' || l_view_name_d || Q'[ qdv
            )
            ,sq_pcrr
            /* Subquery for parent-child results relationship. */
        AS (
            SELECT parent_plan_id
                ,parent_occurrence
                ,child_plan_id
                ,child_occurrence
            FROM qa_pc_results_relationship_v
            )
            ,sq_nid
            /* Join results of Nonconformance, Verify Nonconformances, and Dispositions. */
        AS (
            SELECT
            sq_n.nonconformance_row              n_nonconformance_row
            ,sq_n.plan_id                        n_plan_id
            ,sq_n.plan_name                      n_plan_name
            ,sq_n.organization_id                n_organization_id
            ,sq_n.organization_name              n_organization_name
            ,sq_n.collection_id                  n_collection_id
            ,sq_n.occurrence                     n_occurrence
            ,sq_n.last_update_date               n_last_update_date
            ,sq_n.last_updated_by_id             n_last_updated_by_id
            ,sq_n.last_updated_by                n_last_updated_by
            ,sq_n.creation_date                  n_creation_date
            ,sq_n.created_by_id                  n_created_by_id
            ,sq_n.created_by                     n_created_by
            ,sq_n.last_update_login              n_last_update_login
            ,sq_n.xx_nonconformance_number       n_nonconformance_number
            ,sq_n.xx_inspector_name              n_inspector_name
            ,sq_n.xx_event_date                  n_event_date
            ,sq_n.wip_entity_id                  n_wip_entity_id
            ,sq_n.job                            n_job
            ,sq_n.item_id                        n_item_id
            ,sq_n.item                           n_item
            ,sq_n.xx_item_description            n_item_description
            ,sq_n.quantity                       n_quantity
            ,sq_n.uom_name                       n_uom_name
            ,sq_n.serial_number                  n_serial_number
            ,sq_n.xx_failure_location_general    n_failure_location_general
            ,sq_n.xx_failure_location_detail     n_failure_location_detail
            ,sq_n.xx_nonconformance_symptom      n_nonconformance_symptom
            ,sq_n.xx_comments_long               n_comments_long
            ,sq_n.xx_rcv_inspection_no_reference n_rcv_inspection_no_reference
            ,sq_n.xx_wip_inspection_no_reference n_wip_inspection_no_reference
            ,sq_n.vendor_id                      n_vendor_id
            ,sq_n.supplier                       n_supplier
            ,sq_n.supplier_site                  n_supplier_site
            ,sq_n.po_header_id                   n_po_header_id
            ,sq_n.po_number                      n_po_number
            ,sq_n.po_line_number                 n_po_line_number
            ,sq_n.xx_nonconformance_status       n_nonconformance_status
            ,sq_n.xx_organization_code           n_organization_code
            ,sq_n.xx_collection_plan_name        n_collection_plan_name
            ,sq_n.xx_database_name               n_database_name
            ,sq_n.lot_number                     n_lot_number               --CHG0042754
            ,sq_n.xx_email_addresses             n_email_addresses          --CHG0042754
            ,sq_n.xx_manual_lot_serial_number    n_manual_lot_serial_number --CHG0042754
            ,pcrr1.parent_plan_id                v_parent_plan_id
            ,pcrr1.parent_occurrence             v_parent_occurrence
            ,pcrr1.child_plan_id                 v_child_plan_id
            ,pcrr1.child_occurrence              v_child_occurrence
            ,sq_v.verify_nc_row                  v_verify_nc_row
            ,sq_v.verify_nc_row_count            v_verify_nc_row_count
            ,sq_v.plan_id                        v_plan_id
            ,sq_v.plan_name                      v_plan_name
            ,sq_v.organization_id                v_organization_id
            ,sq_v.organization_name              v_organization_name
            ,sq_v.collection_id                  v_collection_id
            ,sq_v.occurrence                     v_occurrence
            ,sq_v.last_update_date               v_last_update_date
            ,sq_v.last_updated_by_id             v_last_updated_by_id
            ,sq_v.last_updated_by                v_last_updated_by
            ,sq_v.creation_date                  v_creation_date
            ,sq_v.created_by_id                  v_created_by_id
            ,sq_v.created_by                     v_created_by
            ,sq_v.last_update_login              v_last_update_login
            ,sq_v.xx_verify_nc_number            v_verify_nc_number
            ,sq_v.xx_inspector_name              v_inspector_name
            ,sq_v.xx_event_date                  v_event_date
            ,sq_v.xx_nonconformance_no_reference v_nonconformance_no_reference
            ,sq_v.xx_rcv_inspection_no_reference v_rcv_inspection_no_reference
            ,sq_v.xx_wip_inspection_no_reference v_wip_inspection_no_reference
            ,sq_v.item_id                        v_item_id
            ,sq_v.item                           v_item
            ,sq_v.xx_item_description            v_item_description
            ,sq_v.quantity                       v_quantity
            ,sq_v.uom_name                       v_uom_name
            ,sq_v.xx_quantity_dispositioned      v_quantity_dispositioned
            ,sq_v.xx_defective_component         v_defective_component
            ,sq_v.xx_serial_number_component     v_serial_number_component
            ,sq_v.xx_part_number_disposition     v_part_number_disposition
            ,sq_v.xx_verify_nc_location          v_verify_nc_location
            ,sq_v.root_cause                     v_root_cause
            ,sq_v.xx_responsibility_general      v_responsibility_general
            ,sq_v.xx_comments_long               v_comments_long
            ,sq_v.xx_nonconformance_class        v_nonconformance_class
            ,sq_v.xx_disposition                 v_disposition
            ,sq_v.xx_item_shown_to               v_item_shown_to
            ,sq_v.xx_buy_item_under_warranty     v_buy_item_under_warranty
            ,sq_v.xx_failure_location_general    v_failure_location_general
            ,sq_v.xx_failure_location_detail     v_failure_location_detail
            ,sq_v.xx_organization_code           v_organization_code
            ,sq_v.xx_collection_plan_name        v_collection_plan_name
            ,sq_v.xx_database_name               v_database_name
            ,sq_v.xx_nc_comments_reference       v_nc_comments_reference    --CHG0042754
            ,pcrr2.parent_plan_id                d_parent_plan_id
            ,pcrr2.parent_occurrence             d_parent_occurrence
            ,pcrr2.child_plan_id                 d_child_plan_id
            ,pcrr2.child_occurrence              d_child_occurrence
            ,sq_d.disposition_row                d_disposition_row
            ,sq_d.disposition_row_count          d_disposition_row_count
            ,sq_d.plan_id                        d_plan_id
            ,sq_d.plan_name                      d_plan_name
            ,sq_d.organization_id                d_organization_id
            ,sq_d.organization_name              d_organization_name
            ,sq_d.collection_id                  d_collection_id
            ,sq_d.occurrence                     d_occurrence
            ,sq_d.last_update_date               d_last_update_date
            ,sq_d.last_updated_by_id             d_last_updated_by_id
            ,sq_d.last_updated_by                d_last_updated_by
            ,sq_d.creation_date                  d_creation_date
            ,sq_d.created_by_id                  d_created_by_id
            ,sq_d.created_by                     d_created_by
            ,sq_d.last_update_login              d_last_update_login
            ,sq_d.xx_disposition_number          d_disposition_number
            ,sq_d.xx_inspector_name              d_inspector_name
            ,sq_d.xx_event_date                  d_event_date
            ,sq_d.xx_nonconformance_no_reference d_nonconformance_no_reference
            ,sq_d.xx_rcv_inspection_no_reference d_rcv_inspection_no_reference
            ,sq_d.xx_verify_nc_no_reference      d_verify_nc_no_reference
            ,sq_d.xx_wip_inspection_no_reference d_wip_inspection_no_reference
            ,sq_d.xx_part_number_disposition     d_part_number_disposition
            ,sq_d.item_id                        d_item_id
            ,sq_d.item                           d_item
            ,sq_d.xx_item_description            d_item_description
            ,sq_d.xx_disposition                 d_disposition
            ,sq_d.uom_name                       d_uom_name
            ,sq_d.xx_quantity_dispositioned      d_quantity_dispositioned
            ,sq_d.xx_comments_long               d_comments_long
            ,sq_d.xx_responsibility_general      d_responsibility_general
            ,sq_d.xx_nonconformance_class        d_nonconformance_class
            ,sq_d.xx_repair_rework_location      d_repair_rework_location
            ,sq_d.vendor_id                      d_vendor_id
            ,sq_d.supplier                       d_supplier
            ,sq_d.supplier_site                  d_supplier_site
            ,sq_d.po_header_id                   d_po_header_id
            ,sq_d.po_number                      d_po_number
            ,sq_d.po_line_number                 d_po_line_number
            ,sq_d.xx_return_to_vendor_org        d_return_to_vendor_org
            ,sq_d.xx_rma_number_supplier         d_rma_number_supplier
            ,sq_d.xx_buyer_email_address         d_buyer_email_address
            ,sq_d.xx_supplier_email_address      d_supplier_email_address
            ,sq_d.xx_organization_code           d_organization_code
            ,sq_d.xx_collection_plan_name        d_collection_plan_name
            ,sq_d.xx_database_name               d_database_name
            ,sq_d.quantity                       d_quantity                 --CHG0042754
            ,sq_d.xx_capa_status                 d_capa_status              --CHG0042754
            ,sq_d.xx_item_cost_frozen            d_item_cost_frozen         --CHG0042754
            ,sq_d.xx_nc_comments_reference       d_nc_comments_reference    --CHG0042754
            ,sq_d.xx_purchasing_entered_date     d_purchasing_entered_date  --CHG0042754
            ,sq_d.xx_disposition_status          d_disposition_status       --CHG0042815
            ,sq_d.xx_workflow_message            d_workflow_message         --CHG0046276
            ,sq_d.xx_disposition_move_order      d_disposition_move_order   --CHG0047103
            ,sq_d.xx_segregation_locator         d_segregation_locator      --CHG0047103
            ,sq_d.xx_segregation_subinventory    d_segregation_subinventory --CHG0047103
            ,sq_d.xx_production_subinventory     d_production_subinventory  --CHG0047103
            ,sq_d.xx_production_locator          d_production_locator       --CHG0047103
        FROM sq_n
        LEFT JOIN sq_pcrr pcrr1 ON (
                sq_n.plan_id = pcrr1.parent_plan_id
                AND sq_n.occurrence = pcrr1.parent_occurrence
                )
        LEFT JOIN sq_v ON (
                pcrr1.child_plan_id = sq_v.plan_id
                AND pcrr1.child_occurrence = sq_v.occurrence
                )
        LEFT JOIN sq_pcrr pcrr2 ON (
                sq_v.plan_id = pcrr2.parent_plan_id
                AND sq_v.occurrence = pcrr2.parent_occurrence
                )
        /* CHG0047103: in rare cases, a disposition may not be "fully" saved, such as one for V016878. */
        LEFT JOIN sq_d ON (
                pcrr2.child_plan_id = sq_d.plan_id
                AND pcrr2.child_occurrence = sq_d.occurrence
                )
        )
            /* Return rows into custom object. */
            SELECT XXQA_NC_RPT_REC_TYPE(
                n_nonconformance_row
                ,n_plan_id
                ,n_plan_name
                ,n_organization_id
                ,n_organization_name
                ,n_collection_id
                ,n_occurrence
                ,n_last_update_date
                ,n_last_updated_by_id
                ,n_last_updated_by
                ,n_creation_date
                ,n_created_by_id
                ,n_created_by
                ,n_last_update_login
                ,n_nonconformance_number
                ,n_inspector_name
                ,n_event_date
                ,n_wip_entity_id
                ,n_job
                ,n_item_id
                ,n_item
                ,n_item_description
                ,n_quantity
                ,n_uom_name
                ,n_serial_number
                ,n_failure_location_general
                ,n_failure_location_detail
                ,n_nonconformance_symptom
                ,n_comments_long
                ,n_rcv_inspection_no_reference
                ,n_wip_inspection_no_reference
                ,n_vendor_id
                ,n_supplier
                ,n_supplier_site
                ,n_po_header_id
                ,n_po_number
                ,n_po_line_number
                ,n_nonconformance_status
                ,n_organization_code
                ,n_collection_plan_name
                ,n_database_name
                ,n_lot_number               --CHG0042754
                ,n_email_addresses          --CHG0042754
                ,n_manual_lot_serial_number --CHG0042754
                ,v_parent_plan_id
                ,v_parent_occurrence
                ,v_child_plan_id
                ,v_child_occurrence
                ,v_verify_nc_row
                ,v_verify_nc_row_count
                ,v_plan_id
                ,v_plan_name
                ,v_organization_id
                ,v_organization_name
                ,v_collection_id
                ,v_occurrence
                ,v_last_update_date
                ,v_last_updated_by_id
                ,v_last_updated_by
                ,v_creation_date
                ,v_created_by_id
                ,v_created_by
                ,v_last_update_login
                ,v_verify_nc_number
                ,v_inspector_name
                ,v_event_date
                ,v_nonconformance_no_reference
                ,v_rcv_inspection_no_reference
                ,v_wip_inspection_no_reference
                ,v_item_id
                ,v_item
                ,v_item_description
                ,v_quantity
                ,v_uom_name
                ,v_quantity_dispositioned
                ,v_defective_component
                ,v_serial_number_component
                ,v_part_number_disposition
                ,v_verify_nc_location
                ,v_root_cause
                ,v_responsibility_general
                ,v_comments_long
                ,v_nonconformance_class
                ,v_disposition
                ,v_item_shown_to
                ,v_buy_item_under_warranty
                ,v_failure_location_general
                ,v_failure_location_detail
                ,v_organization_code
                ,v_collection_plan_name
                ,v_database_name
                ,v_nc_comments_reference --CHG0042754
                ,d_parent_plan_id
                ,d_parent_occurrence
                ,d_child_plan_id
                ,d_child_occurrence
                ,d_disposition_row
                ,d_disposition_row_count
                ,d_plan_id
                ,d_plan_name
                ,d_organization_id
                ,d_organization_name
                ,d_collection_id
                ,d_occurrence
                ,d_last_update_date
                ,d_last_updated_by_id
                ,d_last_updated_by
                ,d_creation_date
                ,d_created_by_id
                ,d_created_by
                ,d_last_update_login
                ,d_disposition_number
                ,d_inspector_name
                ,d_event_date
                ,d_nonconformance_no_reference
                ,d_rcv_inspection_no_reference
                ,d_verify_nc_no_reference
                ,d_wip_inspection_no_reference
                ,d_part_number_disposition
                ,d_item_id
                ,d_item
                ,d_item_description
                ,d_disposition
                ,d_uom_name
                ,d_quantity_dispositioned
                ,d_comments_long
                ,d_responsibility_general
                ,d_nonconformance_class
                ,d_repair_rework_location
                ,d_vendor_id
                ,d_supplier
                ,d_supplier_site
                ,d_po_header_id
                ,d_po_number
                ,d_po_line_number
                ,d_return_to_vendor_org
                ,d_rma_number_supplier
                ,d_buyer_email_address
                ,d_supplier_email_address
                ,d_organization_code
                ,d_collection_plan_name
                ,d_database_name
                ,d_quantity                 --CHG0042754
                ,d_capa_status              --CHG0042754
                ,d_item_cost_frozen         --CHG0042754
                ,d_nc_comments_reference    --CHG0042754
                ,d_purchasing_entered_date  --CHG0042754
                ,d_disposition_status       --CHG0042815
                ,d_workflow_message         --CHG0046276
                ,d_disposition_move_order   --CHG0047103
                ,d_segregation_subinventory --CHG0047103
                ,d_segregation_locator      --CHG0047103
                ,d_production_subinventory  --CHG0047103
                ,d_production_locator       --CHG0047103
            ) FROM sq_nid
            /* CHG0049611: We need to reference the value of the bind variables multiple times in this query so we put them in a subquery and cross join so that we can filter on them later in the where clause. */
            CROSS JOIN (
                SELECT
                    :x_nonconformance_number    x_nonconformance_number
                    ,:x_verify_nc_number        x_verify_nc_number
                    ,:x_disposition_number      x_disposition_number
                    ,:x_n_occurrence            x_n_occurrence
                    ,:x_v_occurrence            x_v_occurrence
                    ,:x_d_occurrence            x_d_occurrence
                    ,:x_nc_active_flag          x_nc_active_flag
                    ,:x_disp_active_flag        x_disp_active_flag
                    ,:x_disposition_status      x_disposition_status
                    ,:x_disposition             x_disposition
                FROM dual) x
            WHERE 1=1 
            /* CHG0047103: prevent "unsaved" verifications and dispositions from being included in results. */
            AND NOT (v_child_occurrence IS NOT NULL AND v_verify_nc_number IS NULL) --PC record exists for n/v but verifictaion isn't returned by its view (CHG0047103)
            AND NOT (d_child_occurrence IS NOT NULL AND d_disposition_number IS NULL) --PC record exists for v/d but disposition isn't returned by its view (CHG0047103)
            
            /* CHG0049611: replaced "dynamic" where clauses, such as v_nc_notification_where_clause, with static expressions and bind variables.  Hardcoded some status values that were previously referenced as constants, from the spec. */
            AND (x_nonconformance_number IS NULL OR n_nonconformance_number = x_nonconformance_number)
            AND (x_verify_nc_number      IS NULL OR v_verify_nc_number      = x_verify_nc_number)
            AND (x_disposition_number    IS NULL OR d_disposition_number    = x_disposition_number)
            AND (x_n_occurrence IS NULL OR n_occurrence = x_n_occurrence)
            AND (x_v_occurrence IS NULL OR v_occurrence = x_v_occurrence)
            AND (x_d_occurrence IS NULL OR d_occurrence = x_d_occurrence)
            AND (x_nc_active_flag IS NULL
                    OR (
                        x_nc_active_flag = 'Y'
                        AND n_nonconformance_status NOT IN ('CLOSED', 'CANCELLED')
                        AND n_nonconformance_status IS NOT NULL
                    )
                )
            AND (x_disp_active_flag IS NULL
                    OR (
                        x_disp_active_flag = 'Y'
                        AND d_disposition_status NOT IN ('CLOSED', 'CANCELLED', 'REJECTED')
                        AND d_disposition_status NOT LIKE '%EXCEPTION%'
                        AND d_disposition_status IS NOT NULL
                    )
                )
            AND (x_disposition_status IS NULL OR d_disposition_status = x_disposition_status)
            AND (x_disposition IS NULL OR d_disposition = x_disposition)
            ]'
            || ' ORDER BY sq_nid.n_nonconformance_number, sq_nid.v_verify_nc_number, sq_nid.d_disposition_number'
            ;
        --write_message('SQL Statement in variable "l_dynamic_sql":' );
        --write_message(l_dynamic_sql);

        write_message('Bind variable values for l_dynamic_sql:' );
        write_message('  x_nonconformance_number (p_sequence_1_value): ' || p_sequence_1_value);
        write_message('  x_verify_nc_number (p_sequence_2_value): ' || p_sequence_2_value);
        write_message('  x_disposition_number (p_sequence_3_value): ' || p_sequence_3_value);
        write_message('  x_n_occurrence (l_n_occurrence): ' || l_n_occurrence);
        write_message('  x_v_occurrence (l_v_occurrence): ' || l_v_occurrence);
        write_message('  x_d_occurrence (l_d_occurrence): ' || l_d_occurrence);
        write_message('  x_nc_active_flag (p_nc_active_flag): ' || p_nc_active_flag);
        write_message('  x_disp_active_flag (p_disp_active_flag): ' || p_disp_active_flag);
        write_message('  x_disposition_status (p_disposition_status): ' || p_disposition_status);
        write_message('  x_disposition (p_disposition): ' || p_disposition);

        /* Execute the dynamic SQL statement. */
        EXECUTE IMMEDIATE l_dynamic_sql BULK COLLECT INTO l_result_temp
        /* CHG0049611: use bind variables to improve performance */
        USING
            p_sequence_1_value
            ,p_sequence_2_value
            ,p_sequence_3_value
            ,l_n_occurrence
            ,l_v_occurrence
            ,l_d_occurrence
            ,p_nc_active_flag
            ,p_disp_active_flag
            ,p_disposition_status
            ,p_disposition
        ;

        write_message('Rows returned in nonconformance_report_data: ' || l_result_temp.COUNT);
        --write_message('Request ID: ' || fnd_global.conc_request_id);
        --write_message(c_output_footer);

        RETURN l_result_temp;

    EXCEPTION
        WHEN ORG_NOT_NC_PROCESS_ENABLED THEN --CHG0047103
            write_message('This inventory organization is not enabled for the Stratasys Nonconformance process.  Check that the necessary collection plans are enabled.');
            RETURN NULL;
        
        WHEN OTHERS THEN
        write_message('Exception in ' || c_method_name || ': ' || SQLERRM );

        /* Return*/
        RETURN NULL; --Returning NULL as place holder for more targeted exception handling, if required by Stratasys coding standards.
    END nonconformance_report_data;
    
    ----------------------------------------------------------------------------------------------------
    --  Name:               report_sequence_parameter_lov
    --  Created By:         Hubert, Eric
    --  Revision:           1.3
    --  Creation Date:      Dec-2016
    --  Purpose:            CHG0040770 - Quality Nonconformance Report
    --  Description:
    --    This function facilitates the construction of a dynamic list of org-specific values as a user is
    --    entering parameters (based on sequence-related collection elements) to run the Quality
    --    Nonconformance Report and Quality Receiving Inspection Report.
    --
    --    As it pertains to the Quality Nonconformance Report for a given org,
    --    all Nonconformacne Numbers would appear in the NC# paramaater LOV.  Once the NC# is chosen, the
    --    LOV for the Verify Nonconformance Number is restricted to just those
    --    associated with the parent NC#.  Once the VNC# is selected, only those
    --    Dispositions associated with the VNC# will be shown in the Disposition
    --    Number LOV.
    --
    --    As it pertains to the Quality Receiving Inspection Report  for a given org,
    --    all Receiving Inspection Numbers would appear in the parameter LOV.
    --
    --  Inputs:
    --    p_plan_type_code: Collection Plan Type
    --    p_sequence_number: Sequence number (Nonconformance Number, Verfiy Nonconformance Number, or Disposition Number)
    --    for specific result for the collection plan type.
    --    p_organization_id: Organization ID for which the quality nonconformance
    --    was entered.
    --  Outputs:
    --    XXQA_RPT_SEQ_LOV_TAB_TYPE: contains one row for each List of Values row for the associated report parameter.
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   Dec-2016      Hubert, Eric    S3 Initial Build
    --  1.1   12-June-2017  Lingaraj(TCS)   CHG0040770  - Quality Nonconformance Report
    --  1.2   20-Jun-2018   Hubert, Eric    CHG0042754:
    --                                      Renamed "f_report_parameter_lov" to "report_sequence_parameter_lov" and added support for Receiving Inspection Number.
    --                                      Changed refernce of XXQA_NCR_SEQ_LOV_TAB_TYPE to XXQA_RPT_SEQ_LOV_TAB_TYPE.
    --                                      Removed parameter p_sequence_number since it was not actually used.
    --  1.3   16-Oct-2019  Hubert, Eric     CHG0042815: reduced size of several local variables from 30 to 50.
    ----------------------------------------------------------------------------------------------------
    FUNCTION report_sequence_parameter_lov (
        p_plan_type_code IN VARCHAR2, --Plan type on collection plan header
        p_organization_id IN NUMBER
    ) RETURN APPS.XXQA_RPT_SEQ_LOV_TAB_TYPE
    IS
        c_method_name CONSTANT VARCHAR(30) := 'report_sequence_parameter_lov';
        
        /* Local Variables*/
        l_view_source            VARCHAR2(30); --View upon which the List of Values will be based
        l_sequence_column        VARCHAR2(30);  --Column in view that represents the sequence (effectively the this the unique identifier from a user's perspective).
        l_parent_sequence_column VARCHAR2(30);  --Column in view that represents the parent plan's sequence.

        l_view_name_n qa_plans.view_name%TYPE; --View name for org-specific Nonconformance collection plan
        l_view_name_v qa_plans.view_name%TYPE; --View name for org-specific Verify Nonconformance collection plan
        l_view_name_d qa_plans.view_name%TYPE; --View name for org-specific Disposition collection plan
        l_view_name_r qa_plans.view_name%TYPE; --View name for org-specific Receiving Inspection collection plan [CHG0042754]
        l_sequence_type     VARCHAR2(150);
        l_organization_id   NUMBER;

        l_result_temp APPS.XXQA_RPT_SEQ_LOV_TAB_TYPE := APPS.XXQA_RPT_SEQ_LOV_TAB_TYPE();  -- Holds the result of the dynamic sql query
        l_dynamic_sql VARCHAR2(32000);  --Stores dynamic SQL statement

        /* Exceptions */
        PLAN_TYPE_CODE_NOT_FOUND EXCEPTION;
        PRAGMA EXCEPTION_INIT (PLAN_TYPE_CODE_NOT_FOUND, -20000);

    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('program unit: ' || gv_log_program_unit);
        --write_message(c_output_header);

        /* Prepare Parameters. */
        l_sequence_type := dbms_assert.enquote_literal(str => p_plan_type_code);--Add single quotes
        l_organization_id := p_organization_id;

        /* Get the view names that will be used in the dynamic SQL. */
        l_view_name_n := collection_plan_view_name(p_plan_type => c_plan_type_code_n, p_organization_id => l_organization_id, p_view_type => c_plan_view_type_result); --View name for org-specific Nonconformance collection plan
        l_view_name_v := collection_plan_view_name(p_plan_type => c_plan_type_code_v, p_organization_id => l_organization_id, p_view_type => c_plan_view_type_result); --View name for org-specific Verify Nonconformance collection plan
        l_view_name_d := collection_plan_view_name(p_plan_type => c_plan_type_code_d, p_organization_id => l_organization_id, p_view_type => c_plan_view_type_result); --View name for org-specific Disposition collection plan
        l_view_name_r := collection_plan_view_name(p_plan_type => c_plan_type_code_r, p_organization_id => l_organization_id, p_view_type => c_plan_view_type_result); --View name for org-specific Receiving Inspection collection plan [CHG0042754]

        --write_message('Names of views determined:' );
        write_message('Names of views determined: ' || l_view_name_n || ', ' || l_view_name_v || ', ' || l_view_name_d);


        /* Verify that each view name is valid, in part to reduce risk of SQL injection.
           Oracle will raise the exception, ORA-44002: invalid object name, if one
           of these views do not exist.

           For CHG0042754, added the IF statement to conditionally check for
           Nonconformance plan-related views without checking for the Receiving
           Inspection view since we can implement the NC plan without RI.
        */
        IF p_plan_type_code <> c_plan_type_code_r THEN
            l_view_name_n := DBMS_ASSERT.SQL_OBJECT_NAME(str => l_view_name_n);
            l_view_name_v := DBMS_ASSERT.SQL_OBJECT_NAME(str => l_view_name_v);
            l_view_name_d := DBMS_ASSERT.SQL_OBJECT_NAME(str => l_view_name_d);
        ELSE
            l_view_name_r := DBMS_ASSERT.SQL_OBJECT_NAME(str => l_view_name_r);
        end if;

        --write_message('Existence of views confirmed');
        --write_message('Build dynamic SQL');

        /* Build a dynamic SQL Statement.  Note the use of the alternative quoting
           mechanism (Q') using "[" as the quote_delimiter.  This is to make the
           use of single quotes in the variable clearer. Note that bind variables
           are not, and cannot, be used because the view/table names will be
           different across orgs. (Bind variables can't be used to specify table or
           view names.) */

        /* Determine the view that should be the source of the LOV. */
        CASE p_plan_type_code
        WHEN c_plan_type_code_n THEN
            l_view_source := l_view_name_n;
            l_sequence_column:= c_sequence_column_n; --Nonconformance Number
            l_parent_sequence_column := c_parent_sequence_column_n; --Nonconformance Number
        WHEN c_plan_type_code_v THEN
                l_view_source := l_view_name_v;
                l_sequence_column:= c_sequence_column_v; --Verify Nonconformance Number
                l_parent_sequence_column := c_parent_sequence_column_v; --Nonconformance Number
        WHEN c_plan_type_code_d THEN
                l_view_source := l_view_name_d;
                l_sequence_column:= c_sequence_column_d; --Disposition Number
                l_parent_sequence_column := c_parent_sequence_column_d; --Verify Nonconformance Number
        /* Added the following condition for CHG0042754. */
        WHEN c_plan_type_code_r THEN
                l_view_source := l_view_name_r;
                l_sequence_column:= c_sequence_column_r; --Receiving Inspection Number
                l_parent_sequence_column := c_parent_sequence_column_r; --Receiving Inspection Number
        /* Raise and exception if the Plan Type is not found*/
        ELSE
            RAISE PLAN_TYPE_CODE_NOT_FOUND;
        END CASE;

        /* Build dynamic SQL statement to produce a List of Values for a report parameter. */
        l_dynamic_sql := 'SELECT XXQA_RPT_SEQ_LOV_REC_TYPE(' ||
            '''' || p_plan_type_code || '''' ||
            ',' || l_parent_sequence_column ||
            ',' || l_sequence_column ||
            ',' || '''' || 'add description for this field' || '''' ||
            ', last_updated_by_id' ||
            ', last_updated_by' ||
            ', last_update_date' ||
            ', created_by_id' ||
            ', created_by' ||
            ', creation_date' ||
            ', organization_id' ||
            ', occurrence' ||
            ', xx_database_name' ||
            ') FROM ' || l_view_source;

        /* Write the SQL statement to the log file so that it can be debugged should issues arise. */
        --write_message('SQL Statement in variable "l_dynamic_sql":' );
        --write_message(l_dynamic_sql);

        /* Execute the dynamic SQL statement. */
        EXECUTE IMMEDIATE l_dynamic_sql BULK COLLECT INTO l_result_temp;
        --write_message('Rows returned: ' || l_result_temp.COUNT);
        --write_message('Request ID: ' || fnd_global.conc_request_id);
        --write_message(c_output_footer);

        RETURN l_result_temp;

    EXCEPTION
        WHEN PLAN_TYPE_CODE_NOT_FOUND THEN
            write_message('ERROR: The collection plan type, ' || p_plan_type_code || ', is not a valid plan type on which to base the list of values.');

            /* Return*/
            RETURN NULL; --Returning NULL as place holder for more targeted exception handling, if required by Stratasys coding standards.

        WHEN OTHERS THEN
            write_message('Exception in ' || c_method_name || ': ' || SQLERRM );

            /* Return*/
            RETURN NULL; --Returning NULL as place holder for more targeted exception handling, if required by Stratasys coding standards.
    END report_sequence_parameter_lov;

    ----------------------------------------------------------------------------------------------------
    --  Name:               print_nc_report
    --  Created By:         Hubert, Eric
    --  Revision:           1.3
    --  Creation Date:      31-Jul-2017
    --  Purpose: Initiate submission of request for XXQA: Quality Nonconformance Report.
    --  Description: This function will create a concurrent request for the
    --    'XXQA: Quality Nonconformance Report' (XXQA_NONCONFORMANCE_RPT).  The
    --    PRAGMA AUTONOMOUS_TRANSACTION clause is used so that this function can be called
    --    from a SQL statement in a forms personalization and return the request_id, so that
    --    a meaningful message can be be displayed for the user to indicate that the
    --    request submission was successfull.
    --
    --  Inputs:  The function has separate arguments for the Nonconformance Number, Verify Nonconformance
    --    Number, and Disposition Number.  This allows for the printing of a
    --    specific branch in the three-level parent-child collection plan
    --    hierarchy.  However, in practice, there will typically be only a single
    --    verification and disposition record for a given nonconformance, thus
    --    providing just the Nonconformacne Number is sufficient.
    --
    --    There is an argument for explicitly indicating which printer should be used,
    --    to bypass any rules within the function for determining which printer should
    --    be used.
    --
    --      p_organization_id: Organization ID for which the quality nonconformance
    --        was entered.
    --      p_sequence_1_value: Nonconformance Number
    --      p_sequence_2_value: Verify Nonconformance Number
    --      p_sequence_3_value: Disposition Number
    --      p_printer_name: Optional printer name  (if null, it is determined with a profile option).
    --      p_update_nc_status: Update the Nonconformance Status before report is produced
    --      p_layout_name: physical layout to be used in RTF template
    --
    --  Outputs:
    --    Concurrent Request ID for XXQA: Quality Nonconformance Report
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   31-Jul-2017   Hubert, Eric    CHG0041284 - Add Tools menu item to print Quality Nonconformance Report from quality results forms
    --  1.1   20-Jun-2018   Hubert, Eric    CHG0042754: added parameter, p_layout_name.  Added PRAGMA AUTONOMOUS_TRANSACTION so that
    --                                      this function can be called from a SQL statement in a forms personalization and return
    --                                      the request_id to be displayed for the user.
    --  1.2   24-Oct-2019   Hubert, Eric    CHG0046276: Added p_wait_for_completion
    --  1.3   01-Apr-2020   Hubert, Eric    CHG0047103: renamed p_sequence_1 - 3 to p_nonconformance_number, p_verify_nc_number, and p_disposition_number
    ----------------------------------------------------------------------------------------------------
    FUNCTION print_nc_report (
        p_organization_id        IN NUMBER
        ,p_nonconformance_number IN qa_results.sequence5%TYPE --Nonconformance Number
        ,p_verify_nc_number      IN qa_results.sequence6%TYPE DEFAULT NULL --Verify Nonconformance Number
        ,p_disposition_number    IN qa_results.sequence7%TYPE DEFAULT NULL--Disposition Number
        ,p_printer_name          IN VARCHAR2 --Optional printer name  (if null, it is determined with a profile option).
        ,p_update_nc_status      IN VARCHAR2
        ,p_layout_name           IN VARCHAR2 --CHG0042754
        ,p_wait_for_completion   IN VARCHAR2 DEFAULT c_no --CHG0046276
    ) RETURN NUMBER IS PRAGMA AUTONOMOUS_TRANSACTION;--Return Concurrent Request ID

    c_method_name CONSTANT VARCHAR(30) := 'print_nc_report';

    /* Local Variables*/
    l_nonconformance_number qa_results.sequence5%TYPE := p_nonconformance_number; --Nonconformance Number
    l_verify_nc_number      qa_results.sequence6%TYPE := p_verify_nc_number; --Verify Nonconformance Number
    l_disposition_number    qa_results.sequence7%TYPE := p_disposition_number; --Disposition Number
    l_organization_id       NUMBER := p_organization_id;
    l_printer_name          fnd_concurrent_requests.printer%TYPE;--Optional printer name
    l_printer_qa_default    fnd_profile_option_values.profile_option_value%TYPE;--Profile option value for QA default label printer
    l_printer_default       fnd_profile_option_values.profile_option_value%TYPE;--Profile option value for default printer
    l_copies_default        fnd_profile_option_values.profile_option_value%TYPE;--Profile option value for default copies
    l_report_layout         fnd_profile_option_values.profile_option_value%TYPE;--Profile option value for report layout code
    l_copies NUMBER;

    l_layout_result BOOLEAN;
    l_print_options_result BOOLEAN;
    l_request_id_1 NUMBER; --XXQA: Update Nonconformance Status
    l_request_id_2 NUMBER; --XXQA: Quality Nonconformance Report

    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('program unit: ' || gv_log_program_unit);
        
        /* Determine the printer to be used. */
        l_printer_qa_default := fnd_profile.value('XXQA_DEFAULT_LABEL_PRINTER');
        l_printer_default    := fnd_profile.value('PRINTER');--CHG0047103
        l_copies_default     := fnd_profile.value('CONC_COPIES');--CHG0047103
        l_report_layout      := fnd_profile.value('XXQA_DEFAULT_NONCONFORMANCE_REPORT_LAYOUT');

        CASE WHEN p_printer_name IS NOT NULL THEN --Use printer explicitly passed to function
            l_printer_name := p_printer_name;
        WHEN l_printer_qa_default IS NOT NULL THEN
            l_printer_name := l_printer_qa_default; --Printer from profile option (XX: QA Default Label Printer)
        WHEN l_printer_default IS NOT NULL THEN
            l_printer_name := l_printer_default; --Printer from profile option (Printer)
        ELSE
            l_printer_name := 'noprint';  --Hardcoded default printer (noprint)
        END CASE;

        /* Determine number of copies*/
        l_copies := TO_NUMBER(l_copies_default); --Printer from profile option (Printer)

         /*Assign template*/
        l_layout_result := fnd_request.add_layout (
            template_appl_name => c_asn_xxobjt,
            template_code      => c_psn_ncr, --XXQA_NONCONFORMANCE_RPT
            template_language  => 'en',
            template_territory => 'US',
            output_format      => 'PDF'
        );

        /*Printing options*/
        l_print_options_result := fnd_request.set_print_options (
            printer        => l_printer_name,
            style          => '',
            copies         => l_copies,
            save_output    => TRUE,
            print_together => c_no
        );

        /*Submit Request*/
        l_request_id_2 := fnd_request.submit_request (
            application => c_asn_xxobjt,
            program     => c_psn_ncr, --XXQA_NONCONFORMANCE_RPT,
            description => 'XXQA: Quality Nonconformance Report',
            start_time  => '',
            sub_request => FALSE,
            argument1   => l_organization_id,
            argument2   => l_nonconformance_number,
            argument3   => l_verify_nc_number,
            argument4   => l_disposition_number,
            argument5   => c_yes,--Print Verify NC Result
            argument6   => 'No',--Print Header Footer
            argument7   => l_report_layout,
            argument8   => p_update_nc_status --Update Nonconformance Status
        );

        COMMIT;

        /*Exceptions*/
        IF ( l_request_id_2 <> 0)
        THEN
             write_message('Concurrent request succeeded: ' || l_request_id_2);
        ELSE
             write_message('Concurrent Request failed to submit: ' || l_request_id_2);
             write_message('Request Not Submitted due to "' || fnd_message.get || '".');
        END IF;

        /* CHG0046276: adding optional wait for request completion. 
           For scrap approval notifications, we want to include the html output of the request
           into the workflow notifications/emails.  To do this we must wait until
           the html has been generated by this request.
        */
        IF p_wait_for_completion = c_yes THEN
            DECLARE
                /* Local constants*/
                c_max_wait   CONSTANT NUMBER := 300; --Max amount of time to wait (in seconds) for request's completion
                
                /* Local variables*/
                l_phase      VARCHAR2(30);
                l_status     VARCHAR2(30);
                l_dev_phase  VARCHAR2(30);
                l_dev_status VARCHAR2(30);
                l_message    VARCHAR2(30);
                l_interval   NUMBER := fnd_profile.value('XX: QA Concurrent Request Wait Interval'); --Number of seconds to wait between checks.
                l_result     BOOLEAN;

            BEGIN
                l_result := fnd_concurrent.wait_for_request(
                    request_id  => l_request_id_2--IN number default NULL,
                    ,interval   => l_interval  --IN  number default 60,
                    ,max_wait   => c_max_wait  --IN  number default 0,
                    ,phase      => l_phase     --OUT NOCOPY varchar2,
                    ,status     => l_status    --OUT NOCOPY varchar2,
                    ,dev_phase  => l_dev_phase --OUT NOCOPY varchar2,
                    ,dev_status => l_dev_status--OUT NOCOPY varchar2,
                    ,message    => l_message   --OUT NOCOPY varchar2
                    );

                write_message('l_phase: ' || l_phase);
                write_message('l_status: ' || l_status);
                write_message('l_dev_phase: ' || l_dev_phase);
                write_message('l_dev_status: ' || l_dev_status);
                write_message('l_message: ' || l_message);
            EXCEPTION WHEN OTHERS THEN
                NULL;
            END;
        END IF;
        
        RETURN l_request_id_2;

    EXCEPTION
        WHEN OTHERS THEN
            write_message('Exception in ' || c_method_name || ': ' || SQLERRM );

            /* Return*/
            RETURN NULL; --Returning NULL as place holder for more targeted exception handling, if required by Stratasys coding standards.
    END print_nc_report;

    ----------------------------------------------------------------------------------------------------
    --  Name:               receiving_inspection_data
    --  Created By:         Hubert, Eric
    --  Revision:           1.3
    --  Creation Date:      Dec-2016
    --  Purpose:            CHG0042754 - Receiving Inspection Report (formerly Inspection Release Sticker)
    --  Description:
    --    This function returns rows for the data required in the Receiving
    --    Inspection Report.
    --    This package is required due to the dynamic way in which Oracle Quality
    --    stores results in qa_results.  There is no guarantee that a given
    --    collection element will be mapped to a specific column (CHARACTER1
    --    through CHARACTER100) in qa_results.  To work around this, we use the
    --    collection plan-specific result views that are generated by Oracle EBS.
    --    These result views abstract the underlying columns in qa_results by
    --    providing column names that are the same as the Collection Element name.
    --    Using these views solves the element-to-column mapping issue with
    --    qa_results.  However, each collection plan has its own unique results
    --    view, such that a "Receiving Inspection" collection plan in one org will have a
    --    different view than a receiving inspection collection plan in another org.  To
    --    make sure that the correct view is used, we use dynamic SQL, with the
    --    Organization Code and Collection Play Type being the key variables in
    --    this SQL.  This allows us to have a "global" report rather than org
    --    -specific reports.
    -- Inputs:
    --    p_sequence_1_value: Receiving Inspection Number (optional)
    --    p_collection_id: collection_id as found in qa_results table and plan result views (optional)
    --    p_organization_id: Organization ID for which the receiving inspection result
    --    was entered.  (required)
    -- Outputs:
    --    APPS.XXQA_RI_RPT_TAB_TYPE: contains one row for each receiving inspection result.

    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   20-Jun-2018   Hubert, Eric    CHG0042754: Initial build
    --  1.3   16-Oct-2019   Hubert, Eric    CHG0042815: reduced size of some local variables from 30 to 50.
    --  2.0   01-Apr-2021   Hubert, Eric    CHG0049611: -refactored dynamic SQL to use bind variables [in process]
    ----------------------------------------------------------------------------------------------------
    FUNCTION receiving_inspection_data (
        p_sequence_1_value  IN VARCHAR2 --Receiving Inspection Number (changed from VARCHAR2 to %TYPE CHG0049611)
        ,p_collection_id    IN NUMBER -- Collection ID in qa_results and plan view
        ,p_organization_id  IN NUMBER
    ) RETURN apps.xxqa_ri_rpt_tab_type
    IS
        c_method_name CONSTANT VARCHAR(30) := 'receiving_inspection_data';

        /* Local Variables*/
        /* View Names */
        l_view_name_r qa_plans.view_name%TYPE; --View name for org-specific Receiving Inspection collection plan

        /* Local copy of function parameter values*/
        l_receiving_inspection_number qa_results.sequence1%TYPE;  --Receiving Inspection Number
        l_collection_id               NUMBER; --Collection ID
        l_organization_id             NUMBER;

        l_result_temp apps.xxqa_ri_rpt_tab_type := apps.xxqa_ri_rpt_tab_type();  -- Holds the result of the dynamic sql query

        /* Local variables for dynamic SQL */
        l_dynamic_sql                   VARCHAR2(32000);  --Stores dynamic SQL statement

        /* Cursors*/
        TYPE t_ref_cursor IS REF CURSOR;-- (REF CURSOR is the same thing as SYS_REFCURSOR)
        cur_dynamic t_ref_cursor;

    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('program unit: ' || gv_log_program_unit);

        write_message(c_output_header);

        /* Prepare Parameters*/
        l_receiving_inspection_number := dbms_assert.enquote_literal(str => p_sequence_1_value);--Add single quotes
        l_collection_id := p_collection_id;
        l_organization_id   := p_organization_id;

        /* Get the view names that will be used in the dynamic SQL*/
        l_view_name_r := collection_plan_view_name(p_plan_type => c_plan_type_code_r, p_organization_id => l_organization_id, p_view_type => c_plan_view_type_result); --View name for org-specific Receiving Inspection collection plan

        --write_message('Names of views determined: ' || l_view_name_r);

        /* Verify that each view name is valid, in part to reduce risk of SQL injection.
           Oracle will raise the exception, ORA-44002: invalid object name, if one
           of these views do not exist.
        */
        l_view_name_r := DBMS_ASSERT.SQL_OBJECT_NAME(str => l_view_name_r);

        --write_message('Existence of views confirmed.');
        write_message('Begin build of dynamic SQL for Nonconformance data.');

        /* Build a dynamic SQL Statement.  Note the use of the alternative quoting
           mechanism (Q') using "[" as the quote_delimiter.  This is to make the
           use of single quotes in the variable clearer. Note that bind variables
           are not, and cannot, be used because the view/table names will be
           different across orgs. (Bind variables can't be used to specify table or
           view names.)
        */
        l_dynamic_sql := Q'[
        /* This SQL returns all of the information required for the Receiving
        Inspection Report.  This is affixed to inspected material after it
        progresses through receiving inspection.  It is typically used just for
        Accepted shipments and serves as an "Inspection Release Sticker" to
        visually show that the shipment is accepted.  This report contains
        fields that facilitate the subsequent delivery transaction into inventory,
        with the use of barcodes.
        
        CHG0049611: added bind variables.
        */

        WITH sq_r
            /* Subquery for Receiving Inspection data.*/
        AS (
            SELECT qrv.*
            ,ROW_NUMBER() OVER (PARTITION BY qrv.xx_receiving_inspection_number
            ORDER BY qrv.xx_receiving_inspection_number) receiving_inspection_row
            FROM  ]' || l_view_name_r || Q'[ qrv
            )
            ,sq_intermediate
            /* Join results of Receiving Inspection to other tables (follows similar query structure as the nonconformance report query even though we don't need such joins at this time). */
        AS (
            SELECT
                sr.receiving_inspection_row r_receiving_inspection_row
                ,sr.plan_id r_plan_id
                ,sr.plan_name r_plan_name
                ,sr.organization_id r_organization_id
                ,sr.organization_name r_organization_name
                ,sr.collection_id r_collection_id
                ,sr.occurrence r_occurrence
                ,sr.last_update_date r_last_update_date
                ,sr.last_updated_by_id r_last_updated_by_id
                ,sr.last_updated_by r_last_updated_by
                ,sr.creation_date r_creation_date
                ,sr.created_by_id r_created_by_id
                ,sr.created_by r_created_by
                ,sr.last_update_login r_last_update_login
                ,sr.xx_receiving_inspection_number r_receiving_inspection_number
                ,sr.xx_inspector_name r_inspector_name
                ,sr.po_receipt_number r_po_receipt_number
                ,sr.item r_item
                ,sr.item_id r_item_id
                ,sr.xx_item_description r_item_description
                ,sr.po_header_id r_po_header_id
                ,sr.po_line_number r_po_line_number
                ,sr.po_number r_po_number
                ,sr.supplier r_supplier
                ,sr.vendor_id r_vendor_id
                ,sr.supplier_site r_supplier_site
                ,sr.lot_number r_lot_number
                ,sr.xx_manual_lot_serial_number r_manual_lot_serial_number
                ,sr.xx_expiration_date r_expiration_date
                ,sr.quantity r_quantity
                ,sr.uom_name r_uom_name
                ,sr.sample_size r_sample_size
                ,sr.xx_coa_provided r_coa_provided
                ,sr.xx_visual_inspection_result r_visual_inspection_result
                ,sr.inspection_result r_inspection_result
                ,sr.xx_comments_long r_comments_long
                ,sr.xx_buyer r_buyer
                ,sr.xx_buyer_email_address r_buyer_email_address
                ,sr.xx_planner r_planner
                ,sr.xx_failure_location_detail r_failure_location_detail
                ,sr.xx_failure_location_general r_failure_location_general
                ,sr.xx_event_date r_event_date
                ,sr.transaction_date r_transaction_date
                ,sr.xx_nonconformance_no_reference r_nonconformance_no_reference
                ,sr.license_plate_number r_license_plate_number
                ,sr.lpn_id r_lpn_id
                ,sr.xx_organization_code r_organization_code
                ,sr.xx_collection_plan_name r_collection_plan_name
                ,sr.xx_database_name r_database_name
        FROM sq_r sr
        )
            /* Return rows into custom object. */
            SELECT XXQA_RI_RPT_REC_TYPE(
                si.r_receiving_inspection_row
                ,si.r_plan_id
                ,si.r_plan_name
                ,si.r_organization_id
                ,si.r_organization_name
                ,si.r_collection_id
                ,si.r_occurrence
                ,si.r_last_update_date
                ,si.r_last_updated_by_id
                ,si.r_last_updated_by
                ,si.r_creation_date
                ,si.r_created_by_id
                ,si.r_created_by
                ,si.r_last_update_login
                ,si.r_receiving_inspection_number
                ,si.r_inspector_name
                ,si.r_po_receipt_number
                ,si.r_item
                ,si.r_item_id
                ,si.r_item_description
                ,si.r_po_header_id
                ,si.r_po_line_number
                ,si.r_po_number
                ,si.r_supplier
                ,si.r_vendor_id
                ,si.r_supplier_site
                ,si.r_lot_number
                ,si.r_manual_lot_serial_number
                ,si.r_expiration_date
                ,si.r_quantity
                ,si.r_uom_name
                ,si.r_sample_size
                ,si.r_coa_provided
                ,si.r_visual_inspection_result
                ,si.r_inspection_result
                ,si.r_comments_long
                ,si.r_buyer
                ,si.r_buyer_email_address
                ,si.r_planner
                ,si.r_failure_location_detail
                ,si.r_failure_location_general
                ,si.r_event_date
                ,si.r_transaction_date
                ,si.r_nonconformance_no_reference
                ,si.r_license_plate_number
                ,si.r_lpn_id
                ,si.r_organization_code
                ,si.r_collection_plan_name
                ,si.r_database_name
            ) FROM sq_intermediate si
            /* CHG0049611: We need to reference the value of the bind variables multiple times in this query so we put them in a subquery and cross join so that we can filter on them later in the where clause. */
            CROSS JOIN (
                SELECT
                    :x_receiving_inspection_number  x_receiving_inspection_number
                    ,:x_collection_id               x_collection_id
                    ,:x_organization_id             x_organization_id
                FROM dual) x
            WHERE 1=1 
                AND (r_receiving_inspection_number = x.x_receiving_inspection_number OR x.x_receiving_inspection_number IS NULL)
                AND (r_collection_id               = x.x_collection_id               OR x.x_collection_id IS NULL)
                AND (r_organization_id             = x.x_organization_id             OR x.x_organization_id IS NULL)
            ORDER BY si.r_receiving_inspection_number]';
        --write_message('SQL Statement in variable "l_dynamic_sql":' );
        --write_message(l_dynamic_sql );

        /* Execute the dynamic SQL statement. */
        EXECUTE IMMEDIATE l_dynamic_sql BULK COLLECT INTO l_result_temp
        /* CHG0049611: use bind variables to improve performance */
        USING
            p_sequence_1_value
            ,p_collection_id
            ,p_organization_id
        ;

        write_message('Rows returned: ' || l_result_temp.COUNT);
        write_message('Request ID: ' || fnd_global.conc_request_id);
        write_message(c_output_footer);

        RETURN l_result_temp;

    EXCEPTION
        WHEN OTHERS THEN
        write_message('Exception in ' || c_method_name || ': ' || SQLERRM );

        /* Return*/
        RETURN NULL; --Returning NULL as place holder for more targeted exception handling, if required by Stratasys coding standards.
    END receiving_inspection_data;

    ----------------------------------------------------------------------------------------------------
    --  Name:               print_ri_report
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      20-Jun-2018
    --  Purpose:           CHG0042754
    --  Description: This function will create a concurrent request for the
    --    'XXQA: Quality Receiving Inspection Report' (XXQA_RCV_INSPECTION_RPT).
    --    To limit the rows returned, the Receiving Inspection Number and/or Collection ID
    --    should be specified.  The PRAGMA AUTONOMOUS_TRANSACTION clause is used so that this
    --    function can be called from a SQL statement in a forms personalization and return the
    --    request_id, so that a meaningful message can be be displayed for the user to indicate that the
    --    request submission was successfull.
    --
    --  Inputs:
    --    There is an argument for explicitly indicating which printer should be used,
    --    to bypass any rules within the function for determining which printer should
    --    be used.
    --
    --    A parameter to specify the layouts allows for building different visual
    --    layouts in the RTF template while using a standardized set of underlying data.
    --    The first layout implemented is to replace the legacy "Inspection Release
    --    Sticker".

    --      p_organization_id: Organization ID for which the quality nonconformance
    --        was entered.
    --      p_sequence_1_value: Nonconformance Number
    --      p_collection_id: identifies quality result row(s) associated with a specific instance of a receiving inspection.
    --      p_printer_name: Optional printer name  (if null, it is determined with a profile option).
    --      p_layout_name: physical layout to be used in RTF template
    --
    --  Outputs:
    --    Concurrent Request ID for XXQA: Receiving Inspection Report

    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   20-Jun-2018   Hubert, Eric    CHG0042754: Initial build
    ----------------------------------------------------------------------------------------------------
    FUNCTION print_ri_report (
        p_organization_id               IN NUMBER
        ,p_receiving_inspection_number  IN qa_results.sequence1%TYPE --Receiving Inspection Number
        ,p_collection_id                IN NUMBER --Collection_ID in qa_results table/plan view
        ,p_layout_name                  IN VARCHAR2 -- Layout code
        ,p_printer_name                 IN VARCHAR2 --Optional printer name
    ) RETURN NUMBER IS PRAGMA AUTONOMOUS_TRANSACTION;--Return Concurrent Request ID
    
    c_method_name CONSTANT VARCHAR(30) := 'print_ri_report';

    /* Local Variables*/
    l_receiving_inspection_number   qa_results.sequence1%TYPE := p_receiving_inspection_number; --Receiving Inspection Number
    l_collection_id                 NUMBER := p_collection_id; --Relates to collection_id column in qa_results and plan result views
    l_organization_id               NUMBER := p_organization_id;
    l_printer_name                  fnd_concurrent_requests.printer%TYPE;--Optional printer name
    l_printer_qa_default            fnd_profile_option_values.profile_option_value%TYPE;--Profile option value for QA default label printer
    l_printer_default               fnd_profile_option_values.profile_option_value%TYPE;--Profile option value for default printer
    l_copies_default                fnd_profile_option_values.profile_option_value%TYPE;--Profile option value for default copies
    l_copies                        NUMBER;
    l_layout_result                 BOOLEAN;
    l_print_options_result          BOOLEAN;
    l_request_id_1                  NUMBER; --XXQA: Quality Receiving Inspection Report

    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('program unit: ' || gv_log_program_unit);
        
        /* Determine the printer to be used. */
        l_printer_qa_default := fnd_profile.value('XXQA_DEFAULT_LABEL_PRINTER');
        l_printer_default    := fnd_profile.value('PRINTER');--CHG0047103
        l_copies_default     := fnd_profile.value('CONC_COPIES');--CHG0047103

        CASE WHEN p_printer_name IS NOT NULL THEN --Use printer explicitly passed to function
            l_printer_name := p_printer_name;
        WHEN l_printer_qa_default IS NOT NULL THEN
            l_printer_name := l_printer_qa_default; --Printer from profile option (XX: QA Default Label Printer)
        WHEN l_printer_default IS NOT NULL THEN
            l_printer_name := l_printer_default; --Printer from profile option (Printer)
        ELSE
            l_printer_name := 'noprint';  --Hardcoded default printer (noprint)
        END CASE;

        /* Determine number of copies*/
        l_copies := TO_NUMBER(l_copies_default); --Printer from profile option (Printer)

         /*Assign template*/
        l_layout_result := fnd_request.add_layout (
            template_appl_name => c_asn_xxobjt,
            template_code      => c_psn_rir, --XXQA_RCV_INSPECTION_RPT
            template_language  => 'en',
            template_territory => 'US',
            output_format      => 'PDF'
        );

        /*Printing options*/
        l_print_options_result := fnd_request.set_print_options (
            printer        => l_printer_name,
            style          => '',
            copies         => l_copies,
            save_output    => TRUE,
            print_together => c_no
        );

        /*Submit Request*/
        l_request_id_1 := fnd_request.submit_request (
            application => c_asn_xxobjt,
            program     => c_psn_rir, --XXQA_RCV_INSPECTION_RPT
            description => 'XXQA: Quality Receiving Inspection Report',
            start_time  => '',
            sub_request => FALSE,
            argument1   => l_organization_id,
            argument2   => l_receiving_inspection_number,
            argument3   => l_collection_id,
            argument4   => p_layout_name,
            argument5   => 'No'--Print Header Footer
        );

        COMMIT;

        /*Exceptions*/
        IF ( l_request_id_1 <> 0)
        THEN
             write_message('Concurrent request succeeded: ' || l_request_id_1);
        ELSE
             write_message('Concurrent Request failed to submit: ' || l_request_id_1);
             write_message('Request Not Submitted due to "' || fnd_message.get || '".');
        END IF;

        RETURN l_request_id_1;

    EXCEPTION
        WHEN OTHERS THEN
            write_message('Exception in ' || c_method_name || ': ' || SQLERRM );

            /* Return*/
            RETURN NULL; --Returning NULL as place holder for more targeted exception handling, if required by Stratasys coding standards.
    END print_ri_report;

    ----------------------------------------------------------------------------------------------------
    --  Name:               run_mot_report
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      01-Apr-2020
    --  Purpose:            CHG0047103
    --  Description: This function will create a concurrent request for XXINV: Move Order Traveler

    --  Inputs:

    --
    --  Outputs:
    --    Concurrent Request ID for XXINV: Move Order Traveler

    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   01-Apr-2020   Hubert, Eric    CHG0047103
    ----------------------------------------------------------------------------------------------------
    FUNCTION run_mot_report(
        p_organization_id               IN NUMBER
        ,p_move_order_number            IN mtl_txn_request_headers.request_number%TYPE
        ,p_inv_pick_slip_print_option   IN NUMBER := 99 --Per lookup, INV_PICK_SLIP_PRINT_OPTIONS: 99 = All (Prints all the Tasks)
        ,p_auto_allocate                IN VARCHAR2 := c_no --Allocates move orders (often desireable but does run slower)
        ,p_batch                        IN mtl_txn_request_lines.attribute3%TYPE --Print Event DFF
        ,p_report_layout_style          IN fnd_flex_values.flex_value%TYPE := 'Medium'--Per Value Set XXINV_REPORT_LAYOUT_STYLE
    ) RETURN NUMBER IS--Return Concurrent Request ID
    
    c_method_name CONSTANT VARCHAR(30) := 'run_mot_report';
    
    c_printer_name CONSTANT VARCHAR2(10) := 'noprint';
    c_copies       CONSTANT NUMBER := 0;
    
    /* Local Variables*/
    l_layout_result        BOOLEAN;
    l_delivery             BOOLEAN;
    l_print_options_result BOOLEAN;
    l_request_id           NUMBER; --XXQA: Quality Receiving Inspection Report
    l_subject              VARCHAR2(78); --Per type delivery_record_type in fnd_request package the size can be 255 characters but using a more conservative guideline of 78

    /* Local variables for email addresses (Sizes per delivery_record_type in fnd_request package)*/
    l_email_to             VARCHAR2(255);
    l_email_cc             VARCHAR2(255);
    l_email_bcc            VARCHAR2(255);
    l_email_from           VARCHAR2(255);
    l_email_reply_to       VARCHAR2(255);
    
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('program unit: ' || gv_log_program_unit);

        write_message('p_organization_id: ' || p_organization_id);
        write_message('p_move_order_number: ' || p_move_order_number);
        write_message('p_inv_pick_slip_print_option: ' || p_inv_pick_slip_print_option);
        write_message('p_batch: ' || p_batch);
        write_message('p_report_layout_style: ' || p_report_layout_style);

         /*Assign template*/
        l_layout_result := fnd_request.add_layout (
            template_appl_name  => c_asn_xxobjt,
            template_code       => c_psn_mot, --XXINV_MOVE_ORDER_TRAVELER,
            template_language   => 'en',
            template_territory  => 'US',
            output_format       => 'PDF'
        );

        /* Get the email addresses */
        l_email_to       := get_delimited_email_recipients(c_recipient_type_to);
        l_email_cc       := get_delimited_email_recipients(c_recipient_type_cc);
        l_email_bcc      := get_delimited_email_recipients(c_recipient_type_bcc);
        l_email_from     := get_delimited_email_recipients(c_recipient_type_from);
        l_email_reply_to := get_delimited_email_recipients(c_recipient_type_reply_to);

        write_message('l_email_to: ' || l_email_to);
        write_message('l_email_cc: ' || l_email_cc);
        write_message('l_email_bcc: ' || l_email_bcc);
        write_message('l_email_from: ' || l_email_from);
        write_message('l_email_reply_to: ' || l_email_reply_to);

        /* We don't want to run the move order traveler "wide open" so check that we have
           a batch number or move order number to limit the results. */
        IF p_batch IS NOT NULL OR p_move_order_number IS NOT NULL THEN

            /* Define email attributes if provided. */
            IF l_email_to IS NOT NULL AND l_email_from IS NOT NULL THEN
                IF p_move_order_number IS NOT NULL THEN
                    l_subject := SUBSTR('Move Order ' || p_move_order_number || ' created for QA', 1, 78);
                ELSE
                    l_subject := SUBSTR('Move Orders created for QA', 1, 78);
                END IF;

                l_delivery := fnd_request.add_delivery_option (
                    type             => 'E', -- EMAIL
                    p_argument1      => l_subject,    -- Email Subject
                    p_argument2      => l_email_from, -- From Address
                    p_argument3      => l_email_to,   -- To Address
                    p_argument4      => l_email_cc    -- CC
                );
            END IF;
            
            /*Printing options*/
            l_print_options_result := fnd_request.set_print_options (
                printer         => c_printer_name,
                style           => '',
                copies          => c_copies,
                save_output     => TRUE,
                print_together  => c_no
            );

            write_message('Before mot submit_request');
            /*Submit Request*/
            l_request_id := fnd_request.submit_request (
                application => c_asn_xxobjt,
                program     => c_psn_mot, --XXINV_MOVE_ORDER_TRAVELER,
                description => NULL,
                start_time  => '',
                sub_request => FALSE,
                argument1   => p_organization_id,           --ORGANIZATION_ID
                argument2   => p_move_order_number,         --MOVE_ORDER_LOW
                argument3   => p_move_order_number,         --MOVE_ORDER_HIGH
                argument4   => NULL,
                argument5   => NULL,
                argument6   => NULL,
                argument7   => NULL,
                argument8   => NULL,
                argument9   => NULL,
                argument10  => NULL,
                argument11  => NULL,
                argument12  => NULL,
                argument13  => NULL,
                argument14  => NULL,
                argument15  => NULL,
                argument16  => NULL,
                argument17  => p_inv_pick_slip_print_option,--PRINT_OPTION
                argument18  => NULL,                
                argument19  => NULL,                
                argument20  => NULL,                
                argument21  => NULL,                
                argument22  => NULL,                
                argument23  => p_auto_allocate,             --AUTO_ALLOCATE
                argument24  => NULL,
                argument25  => NULL,
                argument26  => c_no,                        --PRINT_REPORT_HEADER_FOOTER
                argument27  => p_report_layout_style,       --REPT_TYPE_PARAM
                argument28  => NULL,
                argument29  => c_yes,                       --INCLUDE_REPRINTS
                argument30  => c_yes,                       --UPDATE_PRINT_EVENT_DFF (this will cause the "batch" to be overwritten by the standard Print Event information)
                argument31  => p_batch                      --PRINT_EVENT (new parameter for XXINV: Move Order Traveler on CHG0047103)
            );
            write_message('After mot submit_request');

            COMMIT;

            /*Exceptions*/
            IF l_request_id <> 0
            THEN
                 write_message('Concurrent request succeeded: ' || l_request_id);
            ELSE
                 write_message('Concurrent Request failed to submit: ' || l_request_id);
                 write_message('Request Not Submitted due to "' || fnd_message.get || '".');
            END IF;
        
        ELSE
            write_message('p_batch is null');
        END IF;

        RETURN l_request_id;
        
        --write_message('end of run_mot_report');

    EXCEPTION
        WHEN OTHERS THEN
            write_message('Exception in ' || c_method_name || ': ' || SQLERRM );

            /* Return*/
            RETURN NULL; --Returning NULL as place holder for more targeted exception handling, if required by Stratasys coding standards.
    END run_mot_report;

    ----------------------------------------------------------------------------------------------------
    --  Name:               p_plan_type
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      31-Jul-2017
    --  Purpose:            Return the Plan Type or a given
    --  collection plan, via the plan ID.
    --
    --  Description:  Various procedures and forms personalizations need to know
    --   the Plan Type for a given Collection Plan in order properly execute
    --   business rules.  This function will return the plan type for a given
    --   collection plan.
    --
    --  Inputs:
    --    p_plan_id: collection plan ID
    --
    --  Outputs:
    --    Collection Plan Type
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   31-Jul-2017   Hubert, Eric    CHG0041284 - Add Tools menu item to print Quality Nonconformance Report from quality results forms
    --  1.1   01-Apr-2021   Hubert, Eric    CHG0049611 - Added functionality to get the plan type by specifying the occurrence instead
    ----------------------------------------------------------------------------------------------------
    FUNCTION plan_type (
        p_plan_id IN NUMBER DEFAULT NULL
        ,p_occurrence IN NUMBER DEFAULT NULL)
    RETURN VARCHAR2
    IS
        c_method_name CONSTANT VARCHAR(30) := 'plan_type';
        
        /* Local variables*/
        l_plan_id        qa_plans.plan_id%TYPE; --CHG0049611
        l_plan_type_code fnd_lookup_values.lookup_code%TYPE;

        /* Exceptions */
        PLAN_TYPE_CODE_NOT_FOUND EXCEPTION;
        PRAGMA EXCEPTION_INIT (PLAN_TYPE_CODE_NOT_FOUND, -20000);

    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('program unit: ' || gv_log_program_unit);

        BEGIN
            /* If the occurrence is specified then find the plan ID */
            CASE WHEN p_occurrence IS NOT NULL THEN
                    SELECT plan_id
                    INTO l_plan_id
                    FROM qa_results
                    WHERE occurrence = p_occurrence;
                
            WHEN p_plan_id IS NOT NULL THEN 
                l_plan_id := p_plan_id;
            ELSE
                NULL;
            END CASE;
        EXCEPTION
            WHEN OTHERS THEN
                l_plan_id := NULL;
        END;
                    
        --write_message('p_plan_id: ' || p_plan_id);
        
        /* Get the plan type for the collection plan*/
        SELECT plan_type_code
        INTO l_plan_type_code
        FROM qa_plans
        WHERE plan_id = l_plan_id;

        --write_message('Plan Type Code: ' || l_plan_type_code);

        IF l_plan_type_code IS NULL THEN
            RAISE PLAN_TYPE_CODE_NOT_FOUND;
        END IF;

        /* Return Plan Type Code*/
        RETURN l_plan_type_code;

    EXCEPTION
        WHEN PLAN_TYPE_CODE_NOT_FOUND THEN
            write_message('ERROR: The collection plan type ID, ' || p_plan_id || ', is not a valid plan type ID.');

            /* Return*/
            RETURN NULL; --Returning NULL as place holder for more targeted exception handling, if required by Stratasys coding standards.

        WHEN OTHERS THEN
            write_message('Exception in ' || c_method_name || ': ' || SQLERRM );

            /* Return*/
            RETURN NULL; --Returning NULL as place holder for more targeted exception handling, if required by Stratasys coding standards.
    END plan_type;

    ----------------------------------------------------------------------------------------------------
    --  Name:               print_ncr_from_occurrence
    --  Created By:         Hubert, Eric
    --  Revision:           1.2
    --  Creation Date:      31-Jul-2017
    --  Purpose:            Wrapper function for print_nc_report.
    --  Description:        This procedure simplifies the creation of the
    --    concurrent request for the report by only requiring the collection
    --    result occurrence, which is a unique ID number  within the qa_results
    --    table.  From this occurrence, the required arguments can be
    --    determined to make a call of print_nc_report.
    --
    --  Inputs:
    --    p_occurrence: Quality Result Occurrence.  This is a number that uniquely
    --      identifies each row in qa_results.
    --
    --  Outputs:
    --    Concurrent Request ID for XXQA: Quality Nonconformance Report.
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   31-Jul-2017   Hubert, Eric    CHG0041284 - Add Tools menu item to print Quality Nonconformance Report from quality results forms
    --  1.1   16-Oct-2019   Hubert, Eric    CHG0042815 - Rewrote function to get values via qa_result_row_via_occurrence()
    --  1.2   01-Apr-2020   Hubert, Eric    CHG0047103 - Performance enhancements by submitting NC report with parent sequence numbers
    --  1.3   01-May-2021   Hubert, Eric    CHG0049611 - Repalced c_update_nonconformance_status with profile, XX: QA Update Nonconformance Status Default
    ----------------------------------------------------------------------------------------------------
    FUNCTION print_ncr_from_occurrence (
        p_occurrence IN qa_results.occurrence%TYPE
    ) RETURN NUMBER --Return Concurrent Request ID
    IS
        c_method_name CONSTANT VARCHAR(30) := 'print_ncr_from_occurrence';
        
        /* Local Constants*/
        --CHG0049611: c_update_nonconformance_status CONSTANT VARCHAR2(1) := c_yes;  --Indicates if the nonconformance be updated before running the report (make this a User Profile later).
        c_report_layout_name           CONSTANT VARCHAR2(30) := '01';  --01: 10 cm x 15 cm (4" x 6")

        /* Local Variables*/
        l_plan_type_code                fnd_lookup_values.lookup_code%TYPE;
        l_printer_name                  fnd_concurrent_requests.printer%TYPE; --Optional printer name
        l_request_id                    NUMBER;
        l_qa_results_row                qa_results%ROWTYPE; --CHG0042815
        l_nonconformance_number         qa_results.sequence5%TYPE; --Nonconformance Number (CHG0047103)
        l_verify_nc_number              qa_results.sequence6%TYPE; --Verify Nonconformance Number (CHG0047103)
        l_disposition_number            qa_results.sequence7%TYPE; --Disposition Number (CHG0047103)
        l_update_nonconformance_status  VARCHAR2(1); --CHG0049611
 
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('program unit: ' || gv_log_program_unit);

        l_qa_results_row := qa_result_row_via_occurrence(p_occurrence => p_occurrence);--CHG0042815: get the entire qa_results row

        /* Get some values from the result row*/
        l_plan_type_code := plan_type(p_plan_id => l_qa_results_row.plan_id, p_occurrence => NULL); --CHG0049611
        write_message('l_plan_type_code: ' || l_plan_type_code);

        /* Get the NC, verify, and disposition number  (CHG0047103) */
        CASE l_plan_type_code
            WHEN c_plan_type_code_n THEN
                l_nonconformance_number := l_qa_results_row.sequence5;
                l_verify_nc_number      := NULL;
                l_disposition_number    := NULL;
                
            WHEN c_plan_type_code_v THEN
                --l_nonconformance_number := get_user_defined_element_value(p_value_element_name => c_parent_sequence_column_v, p_occurrence => p_occurrence);
                l_nonconformance_number := NULL; --Experimentally, but perhaps counterintuitively, the report finishes faster when the NC# is null, when initiated from a verification record.
                l_verify_nc_number      := l_qa_results_row.sequence6;
                l_disposition_number    := NULL;
                
            WHEN c_plan_type_code_d THEN
                /* Get the nonconformance and verifiction numbers directly from qa_results (fast), via get_user_defined_element_value, versus using the results view (slow). */
                l_nonconformance_number := get_user_defined_element_value(p_value_element_name => c_parent_sequence_column_v, p_occurrence => p_occurrence);
                l_verify_nc_number      := get_user_defined_element_value(p_value_element_name => c_parent_sequence_column_d, p_occurrence => p_occurrence);
                l_disposition_number    := l_qa_results_row.sequence7;
        END CASE;
        
        write_message('l_nonconformance_number: ' || l_nonconformance_number);
        write_message('l_verify_nc_number: ' || l_verify_nc_number);
        write_message('l_disposition_number: ' || l_disposition_number);

        /* Check that not all sequence variables are NULL, to prevent the
        report from running wide open or without rows (no org id). */
        IF NOT (
                l_nonconformance_number IS NULL
                AND l_verify_nc_number IS NULL
                AND l_disposition_number IS NULL
            ) AND l_qa_results_row.organization_id IS NOT NULL THEN

            l_update_nonconformance_status := NVL(fnd_profile.value('XXQA_UPDATE_NONCONFORMANCE_STATUS_DEFAULT'), c_yes); --CHG0049611

            /* Create the concurrent request*/
            l_request_id := print_nc_report(
                p_organization_id         => l_qa_results_row.organization_id,
                p_nonconformance_number   => l_nonconformance_number,
                p_verify_nc_number        => l_verify_nc_number,
                p_disposition_number      => l_disposition_number,
                p_printer_name            => l_printer_name,
                p_update_nc_status        => l_update_nonconformance_status,
                p_layout_name             => c_report_layout_name
            );
        ELSE
            l_request_id := -1;
            write_message('All sequence variables are null or org_id is null.');
        END IF;

        RETURN l_request_id;

    EXCEPTION
        WHEN OTHERS THEN
            write_message('Exception in ' || c_method_name || ': ' || SQLERRM );

            /* Return*/
            RETURN NULL;--Place holder for more targeted exception handling per SSYS standards.
    END print_ncr_from_occurrence;

    ----------------------------------------------------------------------------------------------------
    --  Name:               print_rir_from_collection_id
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      20-Jun-2018
    --
    --  Purpose:            Wrapper function for print_ri_report.
    --  Description:
    --    Simplifies the creation of the concurrent request for the report by only
    --    requiring the collection result collection_id, which is an ID number
    --    within the qa_results common to all result rows (occurrences) saved at the
    --    same time.  From this collection_id, the required arguments
    --    can be determined to make a call of print_ri_report.  Multiple receiving
    --    inspection results could be printed via this function because multiple
    --    results may be associated with the collection_id.
    --
    --  Inputs:
    --    p_collection_id: identifies quality result row(s) associated with a specific instance of a receiving inspection.
    --
    --  Outputs:
    --    Concurrent Request ID for XXQA: Receiving Inspection Report
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   20-Jun-2018  Hubert, Eric    CHG0042754: Initial build
    ----------------------------------------------------------------------------------------------------
    FUNCTION print_rir_from_collection_id (
        p_collection_id IN NUMBER
    ) RETURN NUMBER --Return Concurrent Request ID
    IS
        c_method_name CONSTANT VARCHAR(30) := 'print_rir_from_collection_id';
        
        /* Local Constants*/
        c_report_layout_name CONSTANT fnd_flex_values.flex_value%TYPE := '01';  --01: 10 cm x 15 cm (4" x 6").  If more than one layout is used in the future, this should be replaced with a reference to a profile option.

        /* Local Variables*/
        l_sequence_1_value qa_results.sequence1%TYPE; --Receiving Inspection Number
        l_organization_id  NUMBER := fnd_profile.value('MFG_ORGANIZATION_ID'); --In tht future we should get the org id via the occurrence in case this procedure is not called from a session that sets this profile value.
        l_printer_name     fnd_concurrent_requests.printer%TYPE; --Optional printer name
        l_request_id       NUMBER;
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('program unit: ' || gv_log_program_unit);
        
        --write_message('p_collection_id: ' || p_collection_id);
        --write_message('l_organization_id: ' || l_organization_id);

        /* Check that the collection ID and org id are not null, to prevent the
        report from running wide open or without rows (for no org). */
        IF (p_collection_id IS NOT NULL AND l_organization_id IS NOT NULL) THEN

            /* Create the concurrent request*/
            l_request_id := print_ri_report (
                p_organization_id               => l_organization_id
                ,p_receiving_inspection_number  => NULL
                ,p_collection_id                => p_collection_id
                ,p_layout_name                  => c_report_layout_name
                ,p_printer_name                 => l_printer_name
            );
        ELSE
            l_request_id := -1;
            write_message('Collection ID or Org ID is null.');
        END IF;

        RETURN l_request_id;

    EXCEPTION
        WHEN OTHERS THEN
            write_message('Exception in ' || c_method_name || ': ' || SQLERRM );

            /* Return*/
            RETURN NULL; --Returning NULL as place holder for more targeted exception handling, if required by Stratasys coding standards.
    END print_rir_from_collection_id;

    ----------------------------------------------------------------------------------------------------
    --  Name:               print_rir_from_occurrence
    --  Created By:         Hubert, Eric
    --  Revision:           1.1
    --  Creation Date:      20-Jun-2018
    --  Purpose:            This is a wrapper function for print_ri_report.
    --  Descripiton:
    --    Simplifies the creation of the concurrent request for the report by only
    --    requiring the collection result occurrence, which is a unique ID number
    --    within the qa_results table.  From this occurrence, the required arguments
    --    can be determined to make a call of print_ri_report.
    --
    --  Inputs:
    --    p_occurrence: Quality Result Occurrence.  This is a number that uniquely
    --      identifies each row in qa_results.
    --
    --  Outputs:
    --    Concurrent Request ID for XXQA: Receiving Inspection Report.
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   20-Jun-2018   Hubert, Eric    CHG0042754: Initial build
    --  1.1   16-Oct-2019   Hubert, Eric    CHG0042815: get receiving inspection number via qa_result_row_via_occurrence()
    ----------------------------------------------------------------------------------------------------
    FUNCTION print_rir_from_occurrence (
        p_occurrence IN qa_results.occurrence%TYPE
    ) RETURN NUMBER --Return Concurrent Request ID
    IS
        c_method_name CONSTANT VARCHAR(30) := 'print_rir_from_occurrence';
        
        /* Local Constants*/
        c_report_layout_name CONSTANT VARCHAR2(30) := '01';  --01: 10 cm x 15 cm (4" x 6")

        /* Local Variables*/
        l_sequence_1_value qa_results.sequence1%TYPE; --Receiving Inspection Number
        l_organization_id  NUMBER := fnd_profile.value('MFG_ORGANIZATION_ID');--In tht future we should get the org id via the occurrence in case this procedure is not called from a session that sets this profile value.
        l_printer_name     VARCHAR2(30); --Optional printer name
        l_request_id       NUMBER;
        l_qa_results_row   qa_results%ROWTYPE;--CHG0042815
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('program unit: ' || gv_log_program_unit);
        
        --write_message('p_occurrence: ' || p_occurrence);
        --write_message('l_organization_id: ' || l_organization_id);

        l_qa_results_row := qa_result_row_via_occurrence(p_occurrence => p_occurrence);--CHG0042815: get the entire qa_results row
        l_sequence_1_value := l_qa_results_row.sequence1; --CHG0042815: assign Receiving Inspection Number

        /* Check that the Receiivng Inspection Number is not null, to prevent the
        report from running wide open. */
        IF (l_sequence_1_value IS NOT NULL and l_organization_id IS NOT NULL) THEN

            /* Create the concurrent request*/
            l_request_id := print_ri_report (
                p_organization_id               => l_organization_id
                ,p_receiving_inspection_number  => l_sequence_1_value
                ,p_collection_id                => NULL
                ,p_layout_name                  => c_report_layout_name
                ,p_printer_name                 => l_printer_name
            );
        ELSE
            l_request_id := -1;
            write_message('Receiving Inspection Number or Org ID is null.');
        END IF;

        RETURN l_request_id;

    EXCEPTION
        WHEN OTHERS THEN
            write_message('Exception in ' || c_method_name || ': ' || SQLERRM );

            /* Return*/
            RETURN NULL; --Returning NULL as place holder for more targeted exception handling, if required by Stratasys coding standards.
    END print_rir_from_occurrence;

    ----------------------------------------------------------------------------------------------------
    --  Name:               key_sequence_result_value
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      01-Apr-2020
    --  Purpose:            Simplified method of getting value of an element on a result record given a key sequence number 
    --                      A key sequence number would be Nonconformance, Verify Nonconformance, Disposition, 
    --                      or Receiving Inspection Number.  This function is useful in SQL statements
    --                      where we can't easily handle errors returned by result_element_value.  Use 
    --                      result_element_value when we need to trap errors getting the value of an element.
    --                      
    --                      All of these numbers are stored in one of the SEQUENCEn columns in qa_results.  
    --                      This is a wrapper function for result_element_value that simplifies the call
    --                      to just two required parameters.  The key column is inferred from the first 
    --                      character of the p_sequence_number parameter.  
    --                        N = Nonconformance Number
    --                        V = Verify Nonconformance Number
    --                        D = Disposition Number
    --                        R = Receiving Inspection Number
    --
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   01-Apr-2020   Hubert, Eric    CHG0047103: initial build
    ----------------------------------------------------------------------------------------------------
    FUNCTION key_sequence_result_value (
        p_sequence_number    IN VARCHAR2 --Nonconformance, Verify Nonconformance, Disposition, Receiving Inspection Number 
        ,p_element_name      IN qa_chars.name%TYPE--Name of element related to the action
        ) RETURN VARCHAR2
    IS
        c_method_name CONSTANT VARCHAR(30) := 'key_sequence_result_value';
        
        l_key_column_name   all_tab_columns.column_name%TYPE; --Column name in qa_results
        l_return_value      qa_results.comment1%TYPE; --Element value (sized to largest column in qa_results)
        l_err_code          NUMBER := c_success;
        
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        --write_message('program unit: ' || gv_log_program_unit);
        
        /* Determine the value of the key column for which the element value should be queried,
           by examining the prefix. */
        CASE SUBSTR(p_sequence_number, 1, 1)
        WHEN c_sequence_prefix_n THEN
            l_key_column_name := c_key_seq_nonconformance_plan;
        WHEN c_sequence_prefix_v THEN
            l_key_column_name := c_key_seq_verify_nc_plan;
        WHEN c_sequence_prefix_d THEN
            l_key_column_name := c_key_seq_disposition_plan;
        WHEN c_sequence_prefix_r THEN
            l_key_column_name := c_key_seq_rcv_inspection_plan;
        ELSE
            l_err_code := c_fail;
        END CASE;
        
        --write_message('l_key_column_name: ' || l_key_column_name);
        --write_message('l_err_code: ' || l_err_code);
        
        IF l_err_code = c_success THEN
            /* Get the element's value */
            result_element_value(
                 p_plan_name                   => NULL
                ,p_value_element_name          => p_element_name
                ,p_value_column_name           => NULL
                ,p_key_element_name            => NULL
                ,p_key_column_name             => l_key_column_name
                ,p_key_value                   => p_sequence_number
                ,p_return_foreign_tbl_val_flag => c_no
                ,p_err_code                    => l_err_code
                ,p_return_value                => l_return_value
                );
        END IF;

        IF l_err_code = c_success THEN
            RETURN l_return_value;
        ELSE
            RETURN NULL;
        END IF;
    END key_sequence_result_value;

    ----------------------------------------------------------------------------------------------------
    --  Name:               get_user_defined_element_value
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      16-Oct-2019
    --  Purpose:            Get the result value for a user-defined element value 
    --                      using a simpler set of arguments than the general
    --                      purpose function, result_element_value.
    --  
    --  Design notes: Because user-defined collection elements can't store "ID"
    --                references to foreign tables, we can make some assumptions
    --                about the arguments needed to be passed to result_element_value.
    --
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   16-Oct-2019   Hubert, Eric    CHG0042815
    ----------------------------------------------------------------------------------------------------
    FUNCTION get_user_defined_element_value (
        p_value_element_name IN qa_chars.name%TYPE --Nonconformance Number
        ,p_occurrence        IN qa_results.occurrence%TYPE --Result Occurrence #
        ) RETURN VARCHAR2
    IS
        c_method_name CONSTANT VARCHAR(30) := 'get_user_defined_element_value';
        
        l_return_value  qa_results.comment1%TYPE; --Element value (sized to largest column in qa_results)
        l_err_code      NUMBER;
        
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        --write_message('program unit: ' || gv_log_program_unit);
        
        result_element_value(
            p_plan_name                     => NULL
            , p_value_element_name          => p_value_element_name
            , p_value_column_name           => NULL
            , p_key_element_name            => NULL
            , p_key_column_name             => c_occurrence_column
            , p_key_value                   => p_occurrence
            , p_return_foreign_tbl_val_flag => c_no
            , p_err_code                    => l_err_code
            , p_return_value                => l_return_value
            );

        IF l_err_code = c_success THEN
            RETURN l_return_value;
        ELSE
            RETURN NULL;
        END IF;
    END get_user_defined_element_value;

    ----------------------------------------------------------------------------------------------------
    --  Name:               qa_notify_before_report
    --  Created By:         Hubert, Eric
    --  Revision:           1.2
    --  Creation Date:      16-Oct-2019 
    --  Purpose:            This is the "before report" trigger for XXQA: Quality Nonconformance Notifications.
    --    Populates two global variables (user table types) with nonconformance details and
    --    the email list.  This is done to reduce calls to get nonconformance details, simplify
    --    the SQL statement in the data template for getting email addresses, and because
    --    the nonconformance details need to persist to the after report trigger so that
    --    nonconformance and disposition statuses can be updated after the notifications are sent.
    --
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   16-Oct-2019   Hubert, Eric    CHG0042815: initial build
    --  1.1   24-Oct-2019   Hubert, Eric    CHG0046276: added support for Scrap disposition
    --  1.2   01-Apr-2020   Hubert, Eric    CHG0047103: added support for S_PRE_APPROVAL notification type (not really a notification-just bursts html for the next step)
    --  2.0   01-Apr-2021   Hubert, Eric    CHG0049611: -refactored to pass additional paramaters to nonconformance_report_data without "dynamic where clause" variables.
    ----------------------------------------------------------------------------------------------------
    FUNCTION qa_notify_before_report RETURN BOOLEAN IS--CHG0042815
        c_method_name CONSTANT VARCHAR(30) := 'qa_notify_before_report';

        /* Local Variables */
        l_disposition_status    qa_results.character1%TYPE;
        l_disposition           qa_results.character1%TYPE;

        /* Exceptions */
        UNKNOWN_NOTIFICATION_TYPE_CODE EXCEPTION; --CHG0047103
    
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('program unit: ' || gv_log_program_unit);

        /* Determine some criteria for the dynamic WHERE clause based on the Notification Type.
            Note: Currently (2019), all of our notification requirements are driven by Dispositions.  In the future, we may 
              need to expand this to be driven by Nonconformances (such as for pulling in some business rules for Triple Check-based
              alerts into the XXQA: Quality Notifications program).  Just add the relevant control structures to handle such business rules here.
              
              Also, right now (2019) it is convenient to use a hard-coded CASE statement because of the limited number of rules. In
              the future it may make sense to have this data driven by a new "QA_NOTIFICATIONS_OMA" collection plan and a new
              element on DISPOSITION_STATUS_OMA collection plan to link a given disposition status to a specific notification.
        */
        
        CASE p_notification_type_code
        WHEN c_notification_type_spa THEN --CHG0047103: S_PRE_APPROVAL
            l_disposition        := c_disp_s;
            l_disposition_status := c_d_status_new;--NEW        
         
        WHEN c_notification_type_rav THEN --RAV_APPROVED
            l_disposition        := c_disp_rav;
            l_disposition_status := c_d_status_app; --APPROVED
        
        WHEN c_notification_type_rtv THEN --RTV_APPROVED
            l_disposition        := c_disp_rtv;  
            l_disposition_status := c_d_status_app; --APPROVED

        WHEN c_notification_type_sim THEN --CHG0047103
            l_disposition        := c_disp_s;  
            l_disposition_status := c_d_status_moc;
        
        WHEN c_notification_type_rts THEN --CHG0047103
            l_disposition        := c_disp_uai;  
            l_disposition_status := c_d_status_moc;
          
        ELSE --CHG0047103
            RAISE UNKNOWN_NOTIFICATION_TYPE_CODE;
        END CASE;

        --write_message('l_disposition_status: ' || l_disposition_status);

        /* Write nc rows into package variable which will later be used by a SQL statement in the the data template. */
        gv_nc_rpt_tab := xxqa_nonconformance_util_pkg.nonconformance_report_data (
                    p_sequence_1_value    => p_nonconformance_number
                    ,p_sequence_2_value   => p_verify_nonconformance_number
                    ,p_sequence_3_value   => p_disposition_number
                    ,p_organization_id    => p_organization_id
                    ,p_occurrence         => NULL
                    ,p_nc_active_flag     => c_yes
                    ,p_disp_active_flag   => c_yes
                    ,p_disposition_status => l_disposition_status
                    ,p_disposition        => l_disposition
            );
        --write_message('gv_nc_rpt_tab.COUNT: ' || gv_nc_rpt_tab.COUNT);
    
        /* Make sure some rows were returned. */
        IF gv_nc_rpt_tab.COUNT > 0 THEN

            /* Build the recipient email list. */
            build_email_address_table;

        END IF;

        write_message('end of qa_notify_before_report');
        
        RETURN TRUE;

    EXCEPTION
        WHEN UNKNOWN_NOTIFICATION_TYPE_CODE THEN
            write_message('ERROR: The notification type, ' || p_notification_type_code || ', is not valid.');

            RETURN FALSE;

        WHEN OTHERS THEN
            write_message('Exception in ' || c_method_name || ': ' || SQLERRM );

            /* Return*/
            RETURN FALSE;
    END qa_notify_before_report;

    ----------------------------------------------------------------------------------------------------
    --  Name:               qa_notify_after_report
    --  Created By:         Hubert, Eric
    --  Revision:           1.1
    --  Creation Date:      16-Oct-2019
    --  Purpose:            This is the "after report" trigger for XXQA: Quality Nonconformance Notifications.
    --    It is used to update the status for all dispositions (and nonconformances) for which notifications
    --    were sent.  Currently, this procedure only creates action log entries for dispositions but can be 
    --    enhanced to accomodate nonconformance-driven log entries in the future.
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   16-Oct-2019   Hubert, Eric    CHG0042815: initial build
    --  1.1   01-Apr-2020   Hubert, Eric    CHG0047103: moved the initiation of the scrap approval workflow to a separate concurrent program
    --  2.0   01-Apr-2021   Hubert, Eric    CHG0049611: refactored to pass additional paramaters to nonconformance_report_data without "dynamic where clause" variables.
    ----------------------------------------------------------------------------------------------------
    FUNCTION qa_notify_after_report RETURN BOOLEAN IS--CHG0042815
        c_method_name CONSTANT VARCHAR(30) := 'qa_notify_after_report';
        
        /* Local variables for writing to the Quality Action Log */
        l_char_id_disposition_status    NUMBER; --char_id for XX_DISPOSITION_STATUS
        l_action_log_message            qa_action_log.action_log_message%TYPE;--VARCHAR2(4000); --Message for Quality Action Log
        l_log_number                    NUMBER; --Quality Action Log number
        l_log_entry_needed_flag         BOOLEAN := FALSE; --CHG0047103
        l_note                          VARCHAR2(1000); --The size of this can be increased as-needed (up to near 4,000).
        
        /* Other Local Variables */
        l_err_msg   VARCHAR2(1000);
        l_err_code  NUMBER;
        
        /* Local return variables when calling procedures that are designed to be called from EBS executables. */
        l_errbuf    VARCHAR2(200);
        l_retcode   VARCHAR2(1);
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('program unit: ' || gv_log_program_unit);

        /* Get some values that will remain the same through the loop. */
        l_char_id_disposition_status := qa_core_pkg.get_element_id(c_cen_disposition_status);

        write_message('gv_nc_rpt_tab.count: ' || gv_nc_rpt_tab.count);
        
        /* Perform some actions based on the type of notification. */
        IF p_notification_type_code IN (
                c_notification_type_rav --RAV_APPROVED
                ,c_notification_type_rtv --RTV_APPROVED
                ,c_notification_type_sim --S_ISSUE_MATERIAL (CHG0047103)
                ,c_notification_type_rts --UAI_RETURN_TO_STOCK (CHG0047103)
            ) THEN

            /* Loop through each nonconformance/verification/disposition in the table variable and insert a record into the Quality Action Log. */
            FOR i IN 1 .. gv_nc_rpt_tab.count LOOP

                write_message(i || ': ' || gv_nc_rpt_tab(i).n_nonconformance_number);
                write_message(i || ': ' || gv_nc_rpt_tab(i).d_disposition_number);

                --write_message('l_action_log_message: ' || l_action_log_message);

                /* Create an entry in the quality log to indicate that the notification has been sent.
                   This needs to happen before updating the disposition status because criteria for
                   updating the disposition status may be based upon the existince of the quality
                   action log record.
                   CHG0046276: added IF
                */
                IF p_notification_type_code IN (
                        c_notification_type_rav --RAV_APPROVED
                        ,c_notification_type_rtv --RTV_APPROVED
                    ) THEN
                    
                    l_log_entry_needed_flag := TRUE; --CHG0047103
                    l_note := 'Email has been sent to the supplier (site): ' || gv_nc_rpt_tab(i).d_supplier || ' (' || gv_nc_rpt_tab(i).d_supplier_site || ').';
                    
                /* Added additional notification types (CHG0047103) */
                ELSIF p_notification_type_code IN (
                        c_notification_type_sim --S_ISSUE_MATERIAL
                        ,c_notification_type_rts --UAI_RETURN_TO_STOCK
                    ) 
                    /* If a Move Order is not referenced then don't create a log entry to say that a notification was sent.
                       We prevent notifications with a null MO# from being sent with a rule on the RTF template.
                    */
                    AND gv_nc_rpt_tab(i).d_disposition_move_order IS NOT NULL
                    THEN
                    
                    l_log_entry_needed_flag := TRUE;
                    l_note := 'Email has been sent referencing Move Order: ' || gv_nc_rpt_tab(i).d_disposition_move_order || ' (' || gv_nc_rpt_tab(i).d_organization_code || ').';
                
                ELSE
                    l_log_entry_needed_flag := FALSE;
                    l_note := NULL;
                END IF;

                IF l_log_entry_needed_flag THEN--CHG0047103

                    /* Construct message for Quality Action Log Entry */
                    build_action_log_message(
                        p_element_name              => c_cen_disposition_status
                        ,p_action_name              => c_d_action_sad 
                        ,p_nonconformance_number    => gv_nc_rpt_tab(i).n_nonconformance_number  
                        ,p_verify_nc_number         => gv_nc_rpt_tab(i).v_verify_nc_number   
                        ,p_disposition_number       => gv_nc_rpt_tab(i).d_disposition_number 
                        ,p_new_status               => gv_nc_rpt_tab(i).d_disposition_status  
                        ,p_old_status               => gv_nc_rpt_tab(i).d_disposition_status 
                        ,p_disposition              => gv_nc_rpt_tab(i).d_disposition
                        ,p_occurrence               => gv_nc_rpt_tab(i).d_occurrence
                        ,p_move_order_number        => gv_nc_rpt_tab(i).d_disposition_move_order --CHG0047103
                        ,p_doc_instance_id          => NULL
                        ,p_note                     => l_note
                        ,p_message                  => l_action_log_message    
                    );  
                
                    create_quality_action_log_row(
                        p_plan_id       => gv_nc_rpt_tab(i).d_plan_id,
                        p_collection_id => gv_nc_rpt_tab(i).d_collection_id,
                        p_creation_date => SYSDATE,
                        p_char_id       => l_char_id_disposition_status,
                        p_operator      => 7, --We use 7 which is "is entered" only because p_operator can't be null and if set to 0 it won't be visible in Action log.
                        p_low_value     => NULL,
                        p_high_value    => NULL,
                        p_message       => l_action_log_message,
                        p_result        => NULL,
                        p_concurrent    => 1, --"online" (is being called as part of a concurrent request).  As of the initial release, this is always called in the context of a concurrent request so we hardcod this to 1.
                        p_log_number    => l_log_number
                        );
                    write_message('l_log_number: ' || l_log_number);

                END IF;

            END LOOP;
        END IF;

        /* Check to see if we need to update the Nonconformance Status, per a program parameter. */
        write_message('p_update_nonconformance_status: ' || p_update_nonconformance_status);
        IF p_update_nonconformance_status = c_yes THEN
            /* Loop through dispositions to update their status. */
            FOR i IN 1 .. gv_nc_rpt_tab.count LOOP

                /* If there is an exception in the following block to update the nonconformance and disposition status,
                   then allow this procedure to continue.  If it isn't allowed to continue, the email notification
                   will not be sent and an "erroneous" quality log record will exist saying that the notification
                   was sent.
                */
                BEGIN

                    /* Update the statuses to reflect the notification activity.*/
                    update_nonconformance_status (
                         errbuf                  => l_errbuf
                        ,retcode                 => l_retcode
                        ,p_organization_id       => p_organization_id
                        ,p_nonconformance_number => gv_nc_rpt_tab(i).n_nonconformance_number--p_nonconformance_number--Nonconformance Number
                        ,p_verify_nc_number      => gv_nc_rpt_tab(i).v_verify_nc_number--p_verify_nonconformance_number --Verify Nonconformance Number
                        ,p_disposition_number    => gv_nc_rpt_tab(i).d_disposition_number--p_disposition_number --Disposition Number
                        ,p_status_update_method  => c_qrum_direct --direct update (CHG0047103)
                        ,p_run_import            => c_no -- Don't run Collection Import Manager after inserting records into interface table
                    );

                    write_message('l_errbuf: ' || l_errbuf);
                    write_message('l_retcode: ' || l_retcode);
                EXCEPTION
                    WHEN OTHERS THEN
                    write_message('Exception in ' || c_method_name || ': ' || SQLERRM );
                END;
            END LOOP;
        END IF;
        
        /* For reference, write to log if bursting was selected. (CHG0047103)*/
        write_message('Bursting enabled: ' || is_conc_request_bursted(fnd_global.conc_request_id));
        
        RETURN TRUE;
        
    EXCEPTION --CHG0047103
        WHEN OTHERS THEN
           
            RETURN FALSE;

    END qa_notify_after_report;

    ----------------------------------------------------------------------------------------------------
    --  Name:               supplier_contact_email_list
    --  Created By:         Hubert, Eric
    --  Revision:           1.1
    --  Creation Date:      16-Oct-2019
    --  Purpose:            This return a comma-delimited list of values containing
    --     the email addresses for all quality contacts associated with a supplier
    --     site.  A quality contact is inferred by a designated Job Title value
    --     on the record.  Multiple contacts are supported but the maximum
    --     list size is constrained to 150 charaters due to the CHARACTER columns'
    --     size in qa_results (where the value returned from this function will
    --     typically be stored.      
    --
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   16-Oct-2019  Hubert, Eric    CHG0042815: initial release
    --  1.1   01-Apr-2020  Hubert, Eric    CHG0047223/CHG0047103: use profile XXQA_SUPPLIER_QUALITY_CONTACT_JOB_TITLE instead of procedure constant c_job_title
    ----------------------------------------------------------------------------------------------------
    FUNCTION supplier_contact_email_list (
         p_vendor_name       IN VARCHAR2
        ,p_vendor_site_code  IN VARCHAR2
        ,p_contact_type      IN VARCHAR2
        ) RETURN VARCHAR2
    IS
        c_method_name CONSTANT VARCHAR(30) := 'supplier_contact_email_list';
        
        /* Local variables */
        l_sql               VARCHAR2(5000);
        l_ct_where_clause   VARCHAR2(100);
        l_result            qa_results.character1%TYPE;
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('program unit: ' || gv_log_program_unit);
 
        --write_message('p_vendor_name: ' || p_vendor_name);
        --write_message('p_vendor_site_code: ' || p_vendor_site_code);
        --write_message('p_contact_type: ' || p_contact_type);
       
        /* Construct a portion of a WHERE clause for getting a specific "type" of contact associated with a supplier site.*/
        l_ct_where_clause :=
                CASE WHEN p_contact_type = c_sct_quality THEN
                    Q'[ AND hoc_job_title = :c ]'
                WHEN p_contact_type = c_sct_purchasing THEN
                    Q'[ AND (hoc_job_title <> :c OR hoc_job_title IS NULL) ]'
                ELSE
                    Q'[ AND EXISTS (SELECT :c FROM dual) ]' --Get all contacts (need to include bind variable in a dummy where clause to avoid error)
                END;
                
        write_message('l_ct_where_clause: ' || l_ct_where_clause);
        
        /* SQL to get the quality contact for the supplier site from the supplier contact directory. 
           The contact needs to be associated with the address that is associated with the specified site.
           
           The joins required to return the necessary information was not trivial, so 
           I'm leaving all of the "ID" fields in the select statement in case it needs 
           to be examined on a later date for debugging or enhancement.
        */
        l_sql := Q'[
            WITH sq_tca AS (
                SELECT
                    asx.vendor_id           asx_vendor_id
                    ,asx.vendor_name        asx_vendor_name
                    ,asx.party_id           asx_party_id
                    ,hp.party_name          hp_party_name
                    ,hp.party_type          hp_party_type
                    ,hr.relationship_id     hr_relationship_id
                    ,hr.subject_id          hr_subject_id
                    ,hr.subject_type        hr_subject_type
                    ,hr.subject_table_name  hrl_subject_table_name
                    ,hr.object_type         hr_object_type
                    ,hr.object_table_name   hrl_object_table_name
                    ,hr.party_id            hr_party_id
                    /* Branch A */
                    ,hp2.party_name         hp2_party_name
                    ,hp2.party_type         hp2_party_type
                    ,hcp.email_address      hcp_email_address
                    /* Branch B */
                    ,hoc.org_contact_id     hoc_org_contact_id
                    ,hoc.job_title          hoc_job_title
                    ,ascx.vendor_contact_id ascx_vendor_contact_id
                    ,ascx.party_site_id     ascx_party_site_id
                    ,hps.party_site_id      hps_party_site_id
                    ,hps.location_id        hps_location_id
                    ,assa.vendor_site_id    assa_vendor_site_id
                    ,assa.vendor_site_code  assa_vendor_site_code --Site Name
                    ,assa.party_site_id     assa_party_site_id
                    ,hpsu.site_use_type     hpsu_site_use_type
                    
                FROM 
                    ap_suppliers asx
                    INNER JOIN hz_parties hp                 ON (hp.party_id = asx.party_id) --Supplier party
                    INNER JOIN hz_relationships hr           ON (hr.subject_id = hp.party_id
                                                                 AND hr.object_type = 'PERSON')
                    /* Branch A - get contact point email address (is not at supplier site level, just supplier)*/
                    INNER JOIN hz_parties hp2                ON (hp2.party_id = hr.party_id) --Contact party
                    INNER JOIN hz_contact_points hcp         ON (hcp.owner_table_id = hp2.party_id
                                                                 AND hcp.owner_table_name = 'HZ_PARTIES'
                                                                 AND hcp.contact_point_type = 'EMAIL')
                    /* Branch B - get supplier site */
                    INNER JOIN hz_org_contacts hoc           ON (hoc.party_relationship_id = hr.relationship_id)
                    INNER JOIN ap_supplier_contacts ascx     ON (ascx.org_contact_id = hoc.org_contact_id
                                                                 AND ascx.inactive_date is null)
                    INNER JOIN hz_party_sites hps            ON (hps.party_site_id = ascx.party_site_id)
                    INNER JOIN ap_supplier_sites_all assa    ON (assa.location_id = hps.location_id)
                    LEFT JOIN hz_party_site_uses hpsu        ON (hpsu.party_site_id = assa.party_site_id) --May need to change to inner and restrict hpsu_site_use_type   
                )
            , sq_contacts AS (
                SELECT
                    DISTINCT
                    asx_vendor_name
                    ,assa_vendor_site_code
                    --,hpsu_site_use_type
                    ,hoc_job_title
                    ,hcp_email_address
                FROM sq_tca
                WHERE 1=1
                    AND asx_vendor_name = :a
                    AND UPPER(assa_vendor_site_code) = UPPER(:b) --We need to make this case insensitive because of an artifact of dynamic LOVs (user may select a site in the seeded Supplier Site element that is of a different case than the Supplier Site LOV)
                    --AND hpsu_site_use_type = 'PURCHASING'
                    ]' || l_ct_where_clause || Q'[
                )
            ,sq_list AS (
                SELECT
                    LISTAGG(TRIM(hcp_email_address),:d) WITHIN GROUP (ORDER BY hcp_email_address) concatenated_email_addresses
                FROM sq_contacts)
            SELECT
            SUBSTR((SELECT concatenated_email_addresses FROM sq_list),1,150) supplier_contact_email_list
            FROM dual
            ]';
        --write_message('p_contact_type: ' || p_contact_type);
        --write_message('l_sql: ' || l_sql);

        EXECUTE IMMEDIATE l_sql
        INTO l_result 
        USING --bind variable
            p_vendor_name --a
            ,p_vendor_site_code --b
            --,c_job_title --c
            ,fnd_profile.value('XXQA_SUPPLIER_QUALITY_CONTACT_JOB_TITLE') --CHG0047223
            ,c_delimiter --d
            ;
        
        RETURN l_result;
    EXCEPTION
        WHEN OTHERS THEN
        write_message('Exception in ' || c_method_name || ': ' || SQLERRM );

        /* Return*/
        RETURN NULL; --Returning NULL as place holder for more targeted exception handling, if required by Stratasys coding standards.
    END supplier_contact_email_list;

    ----------------------------------------------------------------------------------------------------
    --  Name:               local_datetime
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      24-Oct-2019
    --  Purpose:            Get current local datetime as a string that that contains the timezone.
    --                               
    --  Description:        By explicitly providing values for optional parameters, any datetime
    --                      can be converted to another timezone in any format that is needed.
    --
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   24-Oct-2019   Hubert, Eric    CHG0046276: initial build
    ----------------------------------------------------------------------------------------------------
    FUNCTION local_datetime(
        p_date                  IN DATE     DEFAULT SYSDATE
        ,p_timezone_id_from     IN NUMBER   DEFAULT fnd_profile.value('SERVER_TIMEZONE_ID')
        ,p_timezone_id_to       IN NUMBER   DEFAULT fnd_profile.value('CLIENT_TIMEZONE_ID')
        ,p_datetime_format_to   IN VARCHAR2 DEFAULT 'DD-MON-YYYY HH:MI:SS AM TZD' --Format of the Date/Time that is returned
    ) RETURN VARCHAR2 IS
        c_method_name CONSTANT VARCHAR(30) := 'local_datetime';

        /* Constants*/
        c_datetime_format_1  CONSTANT VARCHAR2(30)  := 'DD-MON-YYYY HH:MI:SS AM'; --Format of the Date/Time for intermediate calculation
        c_error_msg_1        CONSTANT VARCHAR2(150) := 'Date could not be converted';--Function value to return upon error

        /* Local Variables*/
        l_date_temp          VARCHAR2(30);  --Temp string for user-friendly concurrent request date
        l_timezone_code_from VARCHAR2(100);
        l_timezone_code_to   VARCHAR2(100);

    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        --write_message('program unit: ' || gv_log_program_unit);
        --write_message('p_timezone_id_from: ' || p_timezone_id_from);
        --write_message('p_timezone_id_to: ' || p_timezone_id_to);
        --write_message('p_datetime_format_to: ' || p_datetime_format_to);
        
        /* Get the timezone code for the server. */
        SELECT timezone_code INTO l_timezone_code_from
        FROM fnd_timezones_vl
        WHERE upgrade_tz_id = p_timezone_id_from;

        /* Get the timezone code for the user. */
        SELECT timezone_code INTO l_timezone_code_to
        FROM fnd_timezones_vl WHERE
                upgrade_tz_id = p_timezone_id_to;

        --write_message('l_timezone_code_from: ' || l_timezone_code_from);
        --write_message('l_timezone_code_to: ' || l_timezone_code_to);

        /* Determine the date and time in terms of the user's preferred time zone. */
        l_date_temp :=
            TO_CHAR(
                    FROM_TZ(
                             TO_TIMESTAMP(TO_CHAR(SYSDATE, c_datetime_format_1), c_datetime_format_1)
                             , (l_timezone_code_from)) AT TIME ZONE l_timezone_code_to
                    , p_datetime_format_to
                   )
            ;

    RETURN l_date_temp;

    EXCEPTION
        WHEN OTHERS THEN
            RETURN NULL;
    END local_datetime;
 
    ----------------------------------------------------------------------------------------------------
    --  Name:               wf_get_history_row
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      24-Oct-2019
    --  Purpose:            Get attributes of a particular workflow history record.
    --                               
    --  Description:        By default, attributes from the most recent hostory row
    --                      are returned.  But an offset parameter facilitates
    --                      getting prior rows.   
    --
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   24-Oct-2019   Hubert, Eric    CHG0046276: initial build
    ----------------------------------------------------------------------------------------------------
    FUNCTION wf_get_history_row(
        p_doc_instance_id           IN NUMBER
        ,p_action_offset            IN NUMBER DEFAULT 0 --0: no offset (current action) 1/-1: previous action
    ) RETURN xxobjt_wf_doc_history_v%ROWTYPE
    IS
        c_method_name CONSTANT VARCHAR(30) := 'wf_get_history_row';
        
        l_xowdhv    xxobjt_wf_doc_history_v%ROWTYPE;
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        --write_message('program unit: ' || gv_log_program_unit);
        
        --write_message('p_doc_instance_id: ' || p_doc_instance_id); 
        --write_message('p_action_offset: ' || p_action_offset); 

        SELECT xowdhv.*
        INTO l_xowdhv
        FROM xxobjt_wf_doc_history_v xowdhv
        WHERE 
            xowdhv.doc_instance_id = p_doc_instance_id
            AND xowdhv.seq = 
                (
                    SELECT (MAX(seq) - ABS(p_action_offset)) desired_seq
                    FROM xxobjt_wf_doc_history_v
                    WHERE 
                        doc_instance_id = p_doc_instance_id 
                    GROUP BY doc_instance_id      
                );

        RETURN l_xowdhv;

    EXCEPTION       
        WHEN TOO_MANY_ROWS THEN
            write_message('Exception: TOO_MANY_ROWS in ' || c_method_name);
            RETURN NULL;
        WHEN NO_DATA_FOUND THEN
            write_message('Exception: NO_DATA_FOUND in ' || c_method_name);
            RETURN NULL;
        WHEN OTHERS THEN
            write_message('Exception in ' || c_method_name || ': ' || SQLERRM );
            RETURN NULL;
    END wf_get_history_row;

    ----------------------------------------------------------------------------------------------------
    --  Name:               collection_plan_view_name
    --  Created By:         Hubert, Eric
    --  Revision:           1.2
    --  Creation Date:      31-Jul-2017
    --  Purpose:            Returns the results view name for a plan type within
    --    a specific org. In the event that more than one plan for the type is
    --    found within an org, an exception is raised.
    --
    --  Description:  Various procedures and forms personalizations need to know
    --    the view name for a given collection plan (inferred from its Plan Type)
    --    in order properly execute business rules.  This function will return
    --    the name of the results view, or the import view, associated with the.
    --    collection plan.
    --
    --    A key assumption is that there is only one plan in each org having a
    --    plan type (for Nonconformance, Verify Nonconformance, Disposition,
    --    and Receiving Inspection).  This assumption is valid per the current
    --    quality nonconformance process design for Stratasys.
    --
    --  Inputs:
    --    p_plan_type: Plan Type (code) assigned to a collection plan.
    --    p_organization_id: Inventory Organization ID
    --    p_view_type: RESULT or IMPORT
    --
    --  Outputs:
    --    Collection Plan View Name (import view name or result view name)
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   Dec-2016      Hubert, Eric    S3 Initial Build
    --  1.1   31-Jul-2017   Hubert, Eric    CHG0041284 - Add Tools menu item to print Quality Nonconformance Report from quality results forms
    --  1.2   20-Jun-2018   Hubert, Eric    CHG0042754 - Add ability to get import view name (could only get result view name prior to this).  Made function public.
    ----------------------------------------------------------------------------------------------------
    FUNCTION collection_plan_view_name (
        p_plan_type IN VARCHAR2
        ,p_organization_id IN NUMBER
        ,p_view_type IN VARCHAR2
    ) RETURN VARCHAR2

    IS
        c_method_name CONSTANT VARCHAR(30) := 'collection_plan_view_name';
        
        l_view_name qa_plans.view_name%TYPE := NULL;
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        --write_message('program unit: ' || gv_log_program_unit);
        
        /* Query to get the view name from the Collection Plan definition.*/
        SELECT subquery.requested_view_name INTO l_view_name FROM
        (SELECT plan_id
            ,organization_id
            ,NAME
            ,plan_type_code
            ,view_name
            ,import_view_name
            ,(CASE p_view_type --Do we need to get the name of the Result View, or, the Import View?
            WHEN c_plan_view_type_result THEN
                view_name
            WHEN c_plan_view_type_import THEN
                import_view_name
            END) requested_view_name
            ,effective_from
            ,effective_to
        FROM apps.qa_plans
        WHERE organization_id = p_organization_id
            /* Typical values for plan_type_code are 'XX_NONCONFORMANCE', 'XX_VERIFY_NONCONFORMANCE', 'XX_DISPOSITION', and XX_RECEIVING_INSPECTION. */
            AND plan_type_code = p_plan_type
            /* Include only active collection plans*/
            AND TRUNC(SYSDATE) BETWEEN NVL(effective_from, TRUNC(SYSDATE))
                AND NVL(effective_to, TRUNC(SYSDATE))) subquery;

    RETURN l_view_name;

    /* Exception handling */
    EXCEPTION
        WHEN TOO_MANY_ROWS THEN
            write_message('Exception: TOO_MANY_ROWS in ' || c_method_name);
            RETURN '';
        WHEN NO_DATA_FOUND THEN
            write_message('Exception: NO_DATA_FOUND in ' || c_method_name);
            RETURN '';
        WHEN OTHERS THEN
            write_message('Exception in ' || c_method_name || ': '|| SQLERRM );
            RETURN '';
    END collection_plan_view_name;

    ----------------------------------------------------------------------------------------------------
    --  Name:               collection_plan_name
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      16-Oct-2019
    --  Purpose:            Returns the name of a collection plan for a plan type within
    --    a specific org. In the event that more than one plan for the type is
    --    found within an org, an exception is raised.
    --
    --  Description:  Various procedures and forms personalizations need to know
    --    the plan name for a given collection plan (inferred from its Plan Type)
    --    in order properly execute business rules.  This function will return
    --    the name of the results view, or the import view, associated with the.
    --    collection plan.
    --
    --    A key assumption is that there is only one plan in each org having a
    --    plan type (for Nonconformance, Verify Nonconformance, Disposition,
    --    and Receiving Inspection).  This assumption is valid per the current
    --    quality nonconformance process design for Stratasys.
    --
    --  Inputs:
    --    p_plan_type: Plan Type (code) assigned to a collection plan.
    --    p_organization_id: Inventory Organization ID
    --
    --  Outputs:
    --    Collection Plan Name
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   16-Oct-2019   Hubert, Eric    CHG0042815 - Initial Build
    ----------------------------------------------------------------------------------------------------
    FUNCTION collection_plan_name (
        p_plan_type IN VARCHAR2
        ,p_organization_id IN NUMBER
    ) RETURN VARCHAR2

    IS
        c_method_name CONSTANT VARCHAR(30) := 'collection_plan_name';
        
        l_plan_name qa_plans.view_name%TYPE := NULL;
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('program unit: ' || gv_log_program_unit);
        
        /* Query to get the view name from the Collection Plan definition.*/
        SELECT subquery.name INTO l_plan_name FROM
        (SELECT plan_id
            ,organization_id
            ,name
            ,plan_type_code
            ,effective_from
            ,effective_to
        FROM apps.qa_plans
        WHERE organization_id = p_organization_id
            /* Typical values for plan_type_code are 'XX_NONCONFORMANCE', 'XX_VERIFY_NONCONFORMANCE', 'XX_DISPOSITION', and XX_RECEIVING_INSPECTION. */
            AND plan_type_code = p_plan_type
            /* Include only active collection plans*/
            AND TRUNC(SYSDATE) BETWEEN NVL(effective_from, TRUNC(SYSDATE))
                AND NVL(effective_to, TRUNC(SYSDATE))) subquery;

    RETURN l_plan_name;

    /* Exception handling */
    EXCEPTION
        WHEN TOO_MANY_ROWS THEN
            write_message('Exception: TOO_MANY_ROWS in ' || c_method_name);
            RETURN '';
        WHEN NO_DATA_FOUND THEN
            write_message('Exception: NO_DATA_FOUND in ' || c_method_name);
            RETURN '';
        WHEN OTHERS THEN
            write_message('Exception in ' || c_method_name || ': ' || SQLERRM );
            RETURN '';
    END collection_plan_name;
    
    ----------------------------------------------------------------------------------------------------
    --  Name:          ncr_before_report
    --  Created By:    Hubert, Eric
    --  Revision:      1.0
    --  Creation Date: 20-Jun-2018
    --  Purpose:       Before Report trigger for XXQA: Quality Nonconformance Report.
    --                 The paramaters are passed in from the concurrent request
    --                 paramaters via the data template.  A key purpose of this function
    --                 is to initiate the updating of a Nonconformance's status.  This
    --                 needs to occur before the main query of the NCR report runs
    --                 to ensure that the proper status is printed to the NCR report.
    --
    --  Description:   see Purpose
    --  Inputs: none
    --
    --  Outputs: TRUE/FALSE (Boolean)
    --
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   20-Jun-2018   Hubert, Eric    CHG0042754: initial build
    FUNCTION ncr_before_report RETURN BOOLEAN
    IS
        c_method_name CONSTANT VARCHAR(30) := 'ncr_before_report';
        
        /* Local Variables*/
        l_err_code NUMBER;
        l_err_msg  VARCHAR2(1000);
        
        /* Local return variables when calling procedures that are designed to be called from EBS executables. */
        l_errbuf    VARCHAR2(200);
        l_retcode   VARCHAR2(1);
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('program unit: ' || gv_log_program_unit);

        /* Check to see if we need to update the Nonconformance Status. */
        IF p_update_nonconformance_status = c_yes THEN
            --write_message('p_update_nonconformance_status: ' || p_update_nonconformance_status);

            /* Update the nonformance status before proceding with the execution of the nonconformance report.
               The procedure, update_nonconformance_status, will not complete until collection import has finished.
               Therefore, the execution of the nonconformance report won't continue until after the  completion
               of the status updating. */

            update_nonconformance_status (
                 errbuf                  => l_errbuf
                ,retcode                 => l_retcode
                ,p_organization_id       => p_organization_id
                ,p_nonconformance_number => p_nonconformance_number--Nonconformance Number
                ,p_verify_nc_number      => p_verify_nonconformance_number --Verify Nonconformance Number
                ,p_disposition_number    => p_disposition_number --Disposition Number
                ,p_status_update_method  => c_qrum_direct --direct update (CHG0047103)
                ,p_run_import            => c_no --CHG0047103 (was 'Y') -- Run Collection Import Manager after inserting records into interface table
            );
            write_message('l_errbuf: ' || l_errbuf);
            write_message('l_retcode: ' || l_retcode);
        ELSE
            write_message('p_update_nonconformance_status: ' || p_update_nonconformance_status);
        END IF;

        write_message('Function, ncr_before_report, ended at ' || SYSDATE);
        RETURN(TRUE);

    /* Exception handling */
    EXCEPTION
        WHEN OTHERS THEN
            write_message('Exception in ' || c_method_name || ': ' || SQLERRM );
            RETURN(FALSE);
    END ncr_before_report;

    ----------------------------------------------------------------------------------------------------
    --  Name:               user_element_result_value
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      16-Oct-2019
    --  Purpose:            Get the result value of an arbitrary user-defined (not hardcoded) element.
    -- 
    --  Description:        This is a use-specific wraper function for result_element_value to 
    --                      simplify SQL on "Assign a value to a collection element" Quality Actions.                         
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   16-Oct-2019   Hubert, Eric    CHG0042815
    ----------------------------------------------------------------------------------------------------
    FUNCTION user_element_result_value(
         p_plan_name IN VARCHAR2
        , p_value_element_name IN VARCHAR2
        , p_key_element_name IN VARCHAR2
        , p_key_value IN VARCHAR2
    ) RETURN VARCHAR2 IS
        c_method_name CONSTANT VARCHAR(30) := 'user_element_result_value';
        
        l_return_value  qa_results.comment1%TYPE; --Element value (sized to largest column in qa_results)
        l_err_code NUMBER;
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        --write_message('program unit: ' || gv_log_program_unit);
 
        --write_message('p_plan_name: ' || p_plan_name);
        --write_message('p_value_element_name: ' || p_value_element_name);
        --write_message('p_key_element_name: ' || p_key_element_name);
        --write_message('p_key_value: ' || p_key_value);
       
        result_element_value(
            p_plan_name                     => p_plan_name
            , p_value_element_name          => p_value_element_name
            , p_value_column_name           => NULL
            , p_key_element_name            => p_key_element_name
            , p_key_column_name             => NULL
            , p_key_value                   => p_key_value
            , p_return_foreign_tbl_val_flag => c_no
            , p_err_code                    => l_err_code
            , p_return_value                => l_return_value
            );
            
        IF l_err_code = c_success THEN
            RETURN l_return_value;
        ELSE
            RETURN NULL;
        END IF;
    END user_element_result_value;

    ----------------------------------------------------------------------------------------------------
    --  Name:               get_global_value
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      01-Apr-2020
    --  Purpose:            Get the value of a global variable defined for this package.
    --  **Are get_global_value and set_global_value needed?  I don't see code referencing them in this package, quality actions, or forms personalizations.
    --  Parameters :
    --       Name             Type    Purpose
    --       --------         ----    -----------
    --       
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date            Name            Desc
    --  1.0   01-Apr-2020     Hubert, Eric    CHG0047103: initial build
    FUNCTION get_global_value(
        p_variable_name IN VARCHAR2
    ) RETURN VARCHAR2
    IS
        c_method_name CONSTANT VARCHAR(30) := 'get_global_value';
        
        /* Local variables */
        l_value VARCHAR2(1000);
        
        /* Exceptions */
        UNSUPPORTED_VARIABLE EXCEPTION;
        
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('program unit: ' || gv_log_program_unit);

        CASE UPPER(p_variable_name)
        WHEN 'GV_FP_EXECUTE_PROCEDURE_RESULT' THEN
            l_value := gv_fp_execute_procedure_result;
        ELSE
            RAISE UNSUPPORTED_VARIABLE;
        END CASE;
        
        RETURN l_value;
        
    EXCEPTION
        WHEN OTHERS THEN
            RETURN NULL;
    END get_global_value;

    ----------------------------------------------------------------------------------------------------
    --  Name:               get_mrb_location
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      01-Apr-2020
    --  Purpose:            Get information about the location of the material.  This includes both the
    --                      segregation subinventory/locator (MRB) and the subinventory/locator where it resided
    --                      before MRB.  The transaction reference will typically be the nonconformance
    --                      number.
    --
    --  Parameters :
    --       Name             Type    Purpose
    --       --------         ----    -----------
    --        
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date            Name            Desc
    --  1.0   01-Apr-2020     Hubert, Eric    CHG0047103: initial build
    ----------------------------------------------------------------------------------------------------
    FUNCTION get_mrb_location(
        p_item                   IN mtl_system_items_b.segment1%TYPE
        ,p_organization_id       IN NUMBER
        ,p_transaction_reference IN mtl_material_transactions.transaction_reference%TYPE --typically the Nonconformance Number
        ,p_element_name          IN qa_chars.name%TYPE
    ) RETURN VARCHAR2
    IS
        c_method_name CONSTANT VARCHAR(30) := 'get_mrb_location';
    
        /* Local Constants*/
        c_mrb_subinv_name_pattern CONSTANT VARCHAR2(10) := '%MRB%'; --Our MRB subinventory names contain "MRB" in the US
        c_mrb_subinv_desc_pattern CONSTANT VARCHAR2(10) := '%MRB%'; --Our MRB subinventory descriptions contain "MRB" in IL
        c_go_back_days            CONSTANT NUMBER       := 90;  --Days of "recent" transaction history to examine.
        c_default_return_value    CONSTANT VARCHAR2(1)  := '';  --Return empty string instead of null to play nicely with the Assign a Value to a Collection Element Quality Action

        /* Local Variables*/
        l_result qa_results.character1%TYPE;
        
        /* Cursor gets the subinventory and locator fields' values for recent subinventory transfers into "MRB" subinventories. */
        CURSOR cur_mtt IS 
            SELECT
                mtt.transfer_subinventory    from_subinventory --Production subinventory
                ,milk1.concatenated_segments from_locator      --Production locator
                ,mtt.subinventory_code       to_subinventory   --Segregation subinventory
                ,milk2.concatenated_segments to_locator        --Segregation locator
            FROM mtl_material_transactions mtt
                INNER JOIN mtl_secondary_inventories si ON (si.secondary_inventory_name = mtt.subinventory_code AND si.organization_id = mtt.organization_id)
                INNER JOIN mtl_system_items_b msi ON (msi.inventory_item_id = mtt.inventory_item_id  AND msi.organization_id = mtt.organization_id)
                LEFT JOIN mtl_item_locations_kfv milk1 ON (milk1.inventory_location_id = mtt.transfer_locator_id) 
                LEFT JOIN mtl_item_locations_kfv milk2 ON (milk2.inventory_location_id = mtt.locator_id) 
            WHERE 1=1
                AND mtt.organization_id = p_organization_id
                AND (si.secondary_inventory_name LIKE c_mrb_subinv_name_pattern OR si.description LIKE c_mrb_subinv_desc_pattern) --Look for MRB in subinventory name or description
                AND mtt.transaction_action_id = 2 --Subinventory Transfer	
                AND mtt.transaction_date >= SYSDATE - c_go_back_days
                AND UPPER(mtt.transaction_reference) = UPPER(p_transaction_reference) --Nonconformance number
                AND msi.segment1 = p_item
            ORDER BY mtt.transaction_id DESC;
        
        l_cur_mtt_row cur_mtt%ROWTYPE;
    BEGIN
    
        OPEN cur_mtt;
            
            /* We're only concerned with the first row, thus there is no loop. */
            FETCH cur_mtt INTO l_cur_mtt_row;
            
            /* Determine which column's value we need to return. */
            CASE p_element_name
            WHEN c_cen_segregation_subinventory THEN
                l_result := l_cur_mtt_row.to_subinventory;

            WHEN c_cen_segregation_locator THEN
                l_result := l_cur_mtt_row.to_locator;
                
            WHEN c_cen_production_subinventory THEN
                l_result := l_cur_mtt_row.from_subinventory;  
                           
            WHEN c_cen_production_locator THEN
                l_result := l_cur_mtt_row.from_locator;
                
            ELSE
                l_result := c_default_return_value;
                
            END CASE;
        CLOSE cur_mtt;
        
        RETURN l_result;
    
    EXCEPTION
        WHEN OTHERS THEN
            RETURN c_default_return_value;
    END get_mrb_location;

    ----------------------------------------------------------------------------------------------------
    --  Name:               get_nc_rpt_tab
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      16-Oct-2019
    --  Purpose:            Return the package-level variable, gv_nc_rpt_tab.
    --
    --                      The original purpose (CHG0042815) is to call this from
    --                      an XML Publisher Data template, after the variable contents
    --                      have been processed/interrogated by an internal procedure
    --                      as part of a "before report" trigger.
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   16-Oct-2019   Hubert, Eric    CHG0042815
    ----------------------------------------------------------------------------------------------------
    FUNCTION get_nc_rpt_tab RETURN apps.xxqa_nc_rpt_tab_type
    IS
    
        c_method_name CONSTANT VARCHAR(30) := 'get_nc_rpt_tab';
    
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('program unit: ' || gv_log_program_unit);
    
        RETURN gv_nc_rpt_tab;
        
    EXCEPTION
        WHEN OTHERS THEN
        write_message('Exception in ' || c_method_name || ': ' || SQLERRM );

        /* Return*/
        RETURN NULL; --Returning NULL as place holder for more targeted exception handling, if required by Stratasys coding standards.
    END get_nc_rpt_tab; 

    ----------------------------------------------------------------------------------------------------
    --  Name:               get_recipient_tab
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      16-Oct-2019 
    --  Purpose:            Return the package-level variable, gv_recipient_tab.
    --
    --                      The original purpose (CHG0042815) is to call this from
    --                      an XML Publisher Data template, after the variable contents
    --                      have been processed/interrogated by an internal procedure
    --                      as part of a "before report" trigger.
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   16-Oct-2019   Hubert, Eric    CHG0042815
    ----------------------------------------------------------------------------------------------------
    FUNCTION get_recipient_tab RETURN apps.xxqa_recipient_tab_type
    IS
    
        c_method_name CONSTANT VARCHAR(30) := 'get_recipient_tab';
    
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('program unit: ' || gv_log_program_unit);
    
        RETURN gv_recipient_tab;
        
    EXCEPTION
        WHEN OTHERS THEN
        write_message('Exception in ' || c_method_name || ': ' || SQLERRM );

        /* Return*/
        RETURN NULL; --Returning NULL as place holder for more targeted exception handling, if required by Stratasys coding standards.
    END get_recipient_tab; 

    ----------------------------------------------------------------------------------------------------
    --  Name:               is_file_exist
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      01-Apr-2020
    --  Purpose:            Checks if a file exists
    --
    --  Parameters :
    --       Name             Type    Purpose
    --       --------         ----    -----------
    --       p_directory_name IN      Provide name of directory
    --       p_filename       IN      Name of file
    --       Returns: Y or N
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date           Name            Desc
    --  1.0   01-Apr-2020    Hubert, Eric    CHG0047103: initial build
    ----------------------------------------------------------------------------------------------------
    FUNCTION is_file_exists (
        p_directory_name IN VARCHAR2
        ,p_filename IN VARCHAR2
    ) RETURN VARCHAR2
    AS
        l_fexists       BOOLEAN := FALSE;
        l_file_length   NUMBER;
        l_block_size    BINARY_INTEGER;
        l_result        VARCHAR2(1) := c_no;
    BEGIN
        UTL_FILE.fgetattr (
            location     => p_directory_name,
            filename     => p_filename,
            fexists      => l_fexists,
            file_length  => l_file_length,
            block_size   => l_block_size
        );

        IF l_fexists THEN
            l_result:= c_yes;
        ELSE
            l_result:= c_no;
        END IF;

        RETURN l_result;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN c_no;
    END is_file_exists;
    
    ----------------------------------------------------------------------------------------------------
    --  Name:               is_nc_process_enabled_org
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      01-Apr-2020
    --  Purpose:            Return Y/N if the current inventory organization is set up
    --                      for the Quality Nonconformance process.
    --                               
    --  Description:        Check that the nonconformance, verification, and disposition
    --                      collection plans are enabled for the org.
    --
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   01-Apr-2020   Hubert, Eric    CHG0047103: initial build
    ----------------------------------------------------------------------------------------------------
    
    FUNCTION is_nc_process_enabled_org (p_organization_id IN NUMBER)
    RETURN VARCHAR2 IS
    
        c_method_name CONSTANT VARCHAR(30) := 'is_nc_process_enabled_org';
    
        l_row_count NUMBER;
    BEGIN
    
        /* Count the number of enabled plans enabled in the org without counting the same plan type multiple times. */
        SELECT COUNT (DISTINCT plan_type_code)
        INTO l_row_count
        FROM qa_plans
        WHERE 
            organization_id = p_organization_id
            AND effective_to IS NULL --crude but practical
            AND plan_type_code IN (
                c_plan_type_code_n
                ,c_plan_type_code_v
                ,c_plan_type_code_d);
        
        /* Check that each of the three required plans exist. */    
        IF l_row_count = 3 THEN
            RETURN c_yes;
        ELSE
            RETURN c_no;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN c_no;
    END is_nc_process_enabled_org;

    ----------------------------------------------------------------------------------------------------
    --  Name:               is_ri_process_enabled_org
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      01-Apr-2020
    --  Purpose:            Return Y/N if the current inventory organization is set up
    --                      for the Quality Receiving Inspection process.
    --                               
    --  Description:        Check that the receiving inspection 
    --                      collection plan, of type XX_RECEIVING_INSPECTION is enabled for the org.
    --                      The Nonconformance process also needs to be enabled since it works
    --                      in conjunction with the receiving inspection process when there are rejections.
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   01-Apr-2020   Hubert, Eric    CHG0047103: initial build
    ----------------------------------------------------------------------------------------------------
    
    FUNCTION is_ri_process_enabled_org (p_organization_id IN NUMBER)
    RETURN VARCHAR2 IS
        c_method_name CONSTANT VARCHAR(30) := 'is_ri_process_enabled_org';
        
        l_row_count NUMBER;
    BEGIN
    
        /* Count the number of enabled plans enabled in the org without counting the same plan type multiple times. */
        SELECT COUNT (DISTINCT plan_type_code)
        INTO l_row_count
        FROM qa_plans
        WHERE 
            organization_id = p_organization_id
            AND effective_to IS NULL --crude but practical
            AND plan_type_code IN (c_plan_type_code_r);
        
        /* Check that the required plan exists. */    
        IF l_row_count = 1 
         AND is_nc_process_enabled_org(p_organization_id => p_organization_id) = c_yes THEN
           RETURN c_yes;
        ELSE
            RETURN c_no;
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN c_no;
    END is_ri_process_enabled_org;
    
    ----------------------------------------------------------------------------------------------------
    --  Name:               is_xml
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      16-Oct-2019
    --  Purpose:            Checks if input is well-formed XML.
    --
    --  Description:        Return 1 if well-formed XML, otherwise 0.
    --
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   16-Oct-2019   Hubert, Eric    CHG0042815   
    ----------------------------------------------------------------------------------------------------
    FUNCTION is_xml(p_xml IN CLOB) --CHG0042815
    RETURN NUMBER
    AS
        c_method_name CONSTANT VARCHAR(30) := 'is_xml';
        
        xmldata XMLTYPE;
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        --write_message('program unit: ' || gv_log_program_unit);
        
        xmldata := XMLTYPE(p_xml);
        
        RETURN 1;
    EXCEPTION
        WHEN OTHERS THEN
        RETURN 0;
    END is_xml;

    ----------------------------------------------------------------------------------------------------
    --  Name:               set_global_value
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      01-Apr-2020
    --  Purpose:            Set the value of a global variable defined for this package.
    --  **Are get_global_value and set_global_value needed?  I don't see code referencing them in this package, quality actions, or forms personalizations.
    --  Parameters :
    --       Name             Type    Purpose
    --       --------         ----    -----------
    --       
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date            Name            Desc
    --  1.0   01-Apr-2020     Hubert, Eric    CHG0047103: initial build
    ----------------------------------------------------------------------------------------------------
    PROCEDURE set_global_value(
        p_variable_name IN  VARCHAR2
        ,p_value        IN  VARCHAR2
        ,p_err_code     OUT NUMBER
        ,p_err_msg      OUT VARCHAR
    )
    IS
        c_method_name CONSTANT VARCHAR(30) := 'set_global_value';
        
        UNSUPPORTED_VARIABLE EXCEPTION;
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('program unit: ' || gv_log_program_unit);

        CASE UPPER(p_variable_name)
        WHEN 'GV_FP_EXECUTE_PROCEDURE_RESULT' THEN
            gv_fp_execute_procedure_result := p_value;
        ELSE
            RAISE UNSUPPORTED_VARIABLE;
        END CASE;
        
        p_err_code := 0;
        p_err_msg  := NULL;
        
    EXCEPTION
        WHEN UNSUPPORTED_VARIABLE THEN 
            p_err_code := 1;
            p_err_msg  := 'Variable not supported by set_global_value: ' || p_variable_name;
        WHEN OTHERS THEN
            p_err_code := 1;
            p_err_msg  := 'Exception in ' || c_method_name || ': '  || SQLERRM;
    END set_global_value;
    
    ----------------------------------------------------------------------------------------------------
    --  Name:               wf_notification_subject
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      24-Oct-2019
    --  Purpose:            Construct the email subject for XX Doc Approval workflow notifications
    --                               
    --  Description:        
    --
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   24-Oct-2019   Hubert, Eric    CHG0046276: initial build
    ----------------------------------------------------------------------------------------------------
    FUNCTION wf_notification_subject(p_doc_instance_id IN NUMBER) RETURN VARCHAR2
    IS
        c_method_name CONSTANT VARCHAR(30) := 'wf_notification_subject';
        
        c_subject_prefix VARCHAR2(100) := 'Quality Scrap Approval Request';
    
        l_wdi_rec               xxobjt_wf_doc_instance%ROWTYPE;
        l_organization_code     mtl_parameters.organization_code%TYPE; --Inventory Org Code
        l_disposition_number    qa_results.sequence1%TYPE;--Disposition Number
        l_scrap_value           VARCHAR2(30);
        l_subject               VARCHAR2(78);
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        --write_message('program unit: ' || gv_log_program_unit);
        
        l_wdi_rec := wf_get_doc_instance_row(p_doc_instance_id => p_doc_instance_id);
        l_organization_code := xxinv_utils_pkg.get_org_code(l_wdi_rec.attribute1);
        l_disposition_number := NVL(l_wdi_rec.attribute4, '');
        l_scrap_value := TRIM(TO_CHAR(l_wdi_rec.attribute5, 'L999,999,999.00'));--format as currency
        
        l_subject := c_subject_prefix || ' (' || l_organization_code || ', ' || l_disposition_number || ', ' || l_scrap_value || ')';
        RETURN l_subject;
        
    EXCEPTION
        WHEN OTHERS THEN
            RETURN c_subject_prefix;
    END wf_notification_subject;
    
    ----------------------------------------------------------------------------------------------------
    --  Name:               wf_get_last_doc_inst_status
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      24-Oct-2019
    --  Purpose:            Get the XX Doc Approval workflow status for the most  
    --                      recent doc instance for a disposition.
    --
    --
    --  Parameters :
    --       Name             Type    Purpose
    --       --------         ----    -----------
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date            Name            Desc
    --  1.0   24-Oct-2019     Hubert, Eric    CHG0046276: initial build
    ----------------------------------------------------------------------------------------------------
    FUNCTION wf_get_last_doc_inst_status(
        p_disposition_number   IN  qa_results.sequence7%TYPE
        ,p_doc_code            IN  xxobjt_wf_docs.doc_code%TYPE
    ) RETURN VARCHAR2
    IS
        c_method_name CONSTANT VARCHAR(30) := 'wf_get_last_doc_inst_status';
        
        l_xwdi_row            xxobjt_wf_doc_instance%ROWTYPE;
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        --write_message('program unit: ' || gv_log_program_unit);
        
        l_xwdi_row := wf_get_last_doc_instance_row(
            p_disposition_number   => p_disposition_number
            ,p_doc_code            => c_wf_doc_code_scrap);
            
        RETURN l_xwdi_row.doc_status;
        
    EXCEPTION
        WHEN OTHERS THEN
            RETURN NULL;
    END wf_get_last_doc_inst_status;
 
    ----------------------------------------------------------------------------------------------------
    -- END PUBLIC FUNCTIONS
    ----------------------------------------------------------------------------------------------------
   
    ----------------------------------------------------------------------------------------------------
    -- BEGIN PUBLIC PROCEDURES
    ----------------------------------------------------------------------------------------------------

    ----------------------------------------------------------------------------------------------------
    --  Name:               update_nonconformance_status
    --  Created By:         Hubert, Eric
    --  Revision:           1.2
    --  Creation Date:      20-Jun-2018
    --  Purpose:            Updates the Nonconformance Status element of a
    --    Nonconformance result record based on business rules (detailed in code
    --    comments below).
    --  Description:  The Nonconformance Status field on the nonconformance record
    --    needs to reflect its progression through the nonconformance process.
    --    This progression is NEW >> VERIFIED >> DISPOSITIONED >> CLOSED.  The status is
    --    to correspond with the existence, or lack thereof, of result rows for
    --    the Verify Nonconformance collection plan and Disposition collection
    --    plan.  It is not practical (nor effective) to maintain the proper status
    --    using functional setups of Quality Actions and/or Parent-Child Relationships.
    --    Because of this, a PL/SQL solution is used.  
    --
    --    This procedure is used in two different contexts
    --      1) Called during the XXQA: Quality Nonconformance Report to update the NC Status
    --         of a single nonconformance before returning control back to this report.
    --      2) Called from the XXQA: Update Nonconformance Status concurrent program
    --         to update the NC Status independent of printing the nonconformance report. In
    --         this context, it be run en masse for an entire org (typical use) or it can
    --         be run for a specific nonconformance (atypical use) in an org.
    --
    --    After the evaluation of the business rules completes for a given nonconformance,
    --    if it is determined that a NC status update is required, then a row is inserted
    --    into the Quality Results Open Interface table via a named import view
    --    specific to the collection plan of interest.  If at least one row is
    --    inserted then a request to run the Collection Import Manager request
    --    submitted.
    --
    --    While technically expedient, a direct update of the nonconformance status (or ANY column)
    --    in qa_results is not officially supported by Oracle.  Therefore provide two options
    --    for performing the update of the Nonconformance status
    --    1) direct update (simple and fast; does not execute Quality Actions)
    --    2) Quality Results Open Interface (slow but supported by Oracle; does execute Quality Actions)
    
    --  Inputs:
    --    p_organization_id: Inventory Organization ID
    --    p_nonconformance_number: Nonconformance Number
    --    p_verify_nc_number: Verify Nonconformance Number (has no purpose for current usage but is included to support future enhancements)
    --    p_disposition_number: Disposition Number (has no purpose for current usage but is included to support future enhancements)
    --    p_run_import: Indicates that standard program, Collection Import Manager, should run  after inserting records into interface table
    --
    --  Outputs:
    --    errbuf: standard "out" parameter to execute a procedure from a PL/SQL executable
    --    retcode: standard "out" parameter to execute a procedure from a PL/SQL executable
    --

    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   20-Jun-2018   Hubert, Eric    CHG0042754
    --  1.1   25-Jan-2019   Hubert, Eric    CHG0042589: Added ability to directly update qa_results without the results open interface for performance improvement
    --  1.2   16-Oct-2019   Hubert, Eric    CHG0042815:
    --                                      -Moved and renamed ("c_status_" >> "c_nc_status_") nonconformance status constants to package spec. 
    --                                      -Added disposition count-related columns to cursor
    --                                      -4/16/19: Internally "null-out" p_verify_nc_number and p_disposition_number, if provided, and use only p_nonconformance_number.  If p_nonconformance_number is null and either p_verify_nc_number or p_disposition_number are not null, derive a value for p_nonconformance_number.  Procedure can run if all three are null (wide-open).
    --  1.3   01-Apr-2020   Hubert, Eric    CHG0047013: added p_results_update_method; default value for p_run_import
    --                                      -added p_results_update_method
    --                                      -created default value for p_run_import
    --  1.4   01-Apr-2021   Hubert, Eric    CHG0049611: paramaters for nonconformance_report_data call updated
    ----------------------------------------------------------------------------------------------------
    PROCEDURE update_nonconformance_status (
        errbuf                  OUT VARCHAR2
       ,retcode                 OUT VARCHAR2
       ,p_organization_id       IN NUMBER
       ,p_nonconformance_number IN qa_results.sequence5%TYPE --Nonconformance Number
       ,p_verify_nc_number      IN qa_results.sequence6%TYPE DEFAULT NULL --Verify Nonconformance Number
       ,p_disposition_number    IN qa_results.sequence7%TYPE DEFAULT NULL--Disposition Number
       ,p_status_update_method  IN NUMBER DEFAULT c_qrum_direct --Addded parameter (CHG0047103)
       ,p_run_import            IN VARCHAR2 DEFAULT c_no -- Run Collection Import Manager after inserting records into interface table (added default c_no - CHG0047103)
    )

    IS
        c_method_name CONSTANT VARCHAR(30) := 'update_nonconformance_status';
        
        /* Local Constants for program control and debugging. */
        c_bypass_update_flag            CONSTANT BOOLEAN := FALSE; --Execute the procedure without inserting rows into the Quality Results Open Interface table or directly updating the Disposition Status. (CHG0042589: was c_bypass_insert_flag)

        /* Local variables for writing to the Quality Action Log */
        l_action_log_char_id            NUMBER; --char_id for Quality Action Log
        l_action_log_message            qa_action_log.action_log_message%TYPE;--VARCHAR2(4000); --Message for Quality Action Log
        l_log_number                    NUMBER; --Quality Action Log number
        l_log_business_rule_ref         VARCHAR2(100); --Stores a reference to the business rule/condition satisfied, for debugging purposes.

        /* Local Variables */
        l_nonconformance_number         qa_results.sequence1%TYPE; --Nonconformance Number (CHG0042815)
        l_verify_nc_number              qa_results.sequence1%TYPE; --Verify Nonconformance Number (CHG0042815)
        l_disposition_number            qa_results.sequence1%TYPE;--Disposition Number (CHG0042815)
        l_plan_name                     qa_plans.name%TYPE; --Collection plan name

        l_organization_code             mtl_parameters.organization_code%TYPE; --Inventory Org Code
        l_new_nc_status                 qa_results.character1%TYPE; --New status of nonconformance as determined by business rules
        l_new_inspector_name            qa_results.character1%TYPE; --We'll use the EXISTING Inspector Name for the nonconformance.
        l_rule_exception_flag           BOOLEAN := FALSE; --Flags an exception condition when a business rule is being evaluated.
        l_status_update_required_flag   BOOLEAN := FALSE; --The status of a given nonconformance needs to be updated after rules were evaluated.
        l_previous_row_updated_flag     BOOLEAN := FALSE; --Previous Nonconformance in loop had its status updated.
        l_log_comment                   VARCHAR2(1024); -- Debug/concurrent request log comment. [CHG0042754: changed from 200 to 1024 to be consistent with other procedures in package]
        l_prior_n_number                qa_results.sequence5%TYPE := '0'; --Prior Nonconformance Number in cursor loop (initialized with a dummy, non-null value)
        l_prior_v_number                qa_results.sequence6%TYPE := '0'; --Prior Verify Nonconformance Number in cursor loop (initialized with a dummy, non-null value)
        l_prior_d_number                qa_results.sequence7%TYPE := '0'; --Prior Disposition Number in cursor loop (initialized with a dummy, non-null value)
        l_view_name_import              VARCHAR2(30); --Import view name for org-specific Nonconformance collection plan
        l_rows_inserted_count           NUMBER := 0; --Keeps track of how many rows were inserted into the quality results interface table
        l_dynamic_sql                   VARCHAR2(2000);  --Stores dynamic SQL statement
        l_import_result_status          VARCHAR2(30); --Status of the import process (if Collection Import is run, per the p_run_import parameter)
        l_err_code                      NUMBER;
        l_err_msg                       VARCHAR2(1000);

        /* Cursors */
        CURSOR cur_results IS (
            /* This SQL return information from nonconformance, verification, and disposition
            records. */
            SELECT
                n_plan_id
                ,n_plan_name
                ,n_organization_id
                ,n_collection_id
                ,n_occurrence
                ,n_nonconformance_number
                ,n_nonconformance_status
                ,n_organization_code
                ,n_inspector_name
                ,n_item
                /* CHG0042815: calculate some disposition totals for each nonconformance, to be used in evaluating the business rules later. */
                ,SUM(CASE WHEN d_disposition_number IS NOT NULL THEN 1 ELSE 0 END) OVER (PARTITION BY n_nonconformance_number) n_total_dispositions--CHG0042815
                ,SUM(CASE WHEN d_disposition_status = c_d_status_clo THEN 1 ELSE 0 END) OVER (PARTITION BY n_nonconformance_number) n_closed_dispositions_count--CHG0042815, CHG0047103
                ,SUM(CASE WHEN d_disposition_status = c_d_status_can THEN 1 ELSE 0 END) OVER (PARTITION BY n_nonconformance_number) n_canceled_dispositions_count--CHG0042815, CHG0047103
                ,v_verify_nc_row
                ,v_verify_nc_row_count
                ,v_plan_name
                ,v_collection_id
                ,v_occurrence
                ,v_verify_nc_number
                ,v_disposition
                ,d_disposition_row
                ,d_disposition_row_count--This only counts the dispositions related to the verification
                ,d_plan_name
                ,d_organization_name
                ,d_collection_id
                ,d_occurrence
                ,d_disposition_number
                ,d_disposition_status--CHG0042815
            FROM TABLE (
                nonconformance_report_data(
                        /* CHG0049611: revised parameters */
                        ----p_sequence_1_value => l_nonconformance_number,
                        ----p_sequence_2_value => l_verify_nc_number,
                        ----p_sequence_3_value => l_disposition_number,
                        ----p_organization_id => p_organization_id
                        
                         p_sequence_1_value   => l_nonconformance_number
                        ,p_sequence_2_value   => l_verify_nc_number
                        ,p_sequence_3_value   => l_disposition_number
                        ,p_organization_id    => p_organization_id
                        ,p_occurrence         => NULL
                        ,p_nc_active_flag     => c_yes
                        ,p_disp_active_flag   => NULL
                        ,p_disposition_status => NULL
                        ,p_disposition        => NULL                  
                    )
                )
                /* CHG0049611: eliminated WHERE clause because we now have a p_nc_active_flag parameter for nonconformance_report_data (above). */
                ----WHERE
                ----/* Ignore Closed and Cancelled nonconformances. */
                ----n_nonconformance_status NOT IN (c_nc_status_clo, c_nc_status_can) --**parameterize this
        )
        ORDER BY n_organization_id, n_nonconformance_number, v_verify_nc_number, d_disposition_number
        ;

        l_rr cur_results%ROWTYPE; --Result Row

    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('program unit: ' || gv_log_program_unit);

        --write_message('p_status_update_method: ' || p_status_update_method);

        /* Get the char_id for the nonconformance status element. */
        l_action_log_char_id := qa_core_pkg.get_element_id(c_cen_nonconformance_status);

        /* CHG0042815: While it is perfectly valid to initiate the update of a Nonconformance Status by referencing
           just a verification and/or disposition number, the status update must actually be executed at the 
           nonconformance level. The issue with referencing a specific verification or disposition number 
           is that the nonconformance status rules will only take those dispositions into account which is not correct
           as all Disposition Statuses related to a nonconformance need to be CLOSED before the Nonconformance Status
           can be changed to CLOSED.  We may ignore a non-CLOSED disposition and erroneously close the NC prematurely.
           
           Therefore, we determine the nonconformance number (either explicitly passed through the p_nonconformance_number parameter
           or via the p_verify_nc_number/p_disposition_number parameters) and use only that when opening the cursor, using NULL 
           for the verification number and disposition number.           
        */
        CASE
        WHEN p_nonconformance_number IS NOT NULL THEN
            l_nonconformance_number := p_nonconformance_number;
            l_verify_nc_number      := NULL;
            l_disposition_number    := NULL;
            l_err_code              := c_success;
            
        WHEN p_verify_nc_number IS NOT NULL THEN
            /* Get the verification plan name */
            l_plan_name := collection_plan_name(c_plan_type_code_d, p_organization_id);
             
           /* Get the Nonconformance number based on the Verification #. */
            result_element_value(
                p_plan_name                     => l_plan_name
                , p_value_element_name          => c_parent_sequence_column_v
                , p_value_column_name           => NULL
                , p_key_element_name            => c_sequence_column_v
                , p_key_column_name             => NULL
                , p_key_value                   => p_verify_nc_number
                , p_return_foreign_tbl_val_flag => c_no
                , p_err_code                    => l_err_code
                , p_return_value                => l_nonconformance_number
                );
            
            l_verify_nc_number      := NULL;
            l_disposition_number    := NULL;
            
        WHEN p_disposition_number IS NOT NULL THEN
            /* Get the disposition plan name */
            l_plan_name := collection_plan_name(c_plan_type_code_d, p_organization_id);
            
            /* Get the Nonconformance number based on the Disposition #. */
            result_element_value(
                p_plan_name                     => l_plan_name
                , p_value_element_name          => c_parent_sequence_column_v
                , p_value_column_name           => NULL
                , p_key_element_name            => c_sequence_column_d
                , p_key_column_name             => NULL
                , p_key_value                   => p_disposition_number
                , p_return_foreign_tbl_val_flag => c_no
                , p_err_code                    => l_err_code
                , p_return_value                => l_nonconformance_number
                );

            l_verify_nc_number      := NULL;
            l_disposition_number    := NULL;
            
        ELSE --Run wide open
            l_nonconformance_number := NULL;
            l_verify_nc_number      := NULL;
            l_disposition_number    := NULL;
            l_err_code              := c_success;
        END CASE;
        
        /* CHG0042815: Confirm that we have valid values for the nonconformance number. */
        IF l_err_code = c_success THEN
            l_err_code := NULL;  --reset
        
            /* CHG0042815: Update dispositions before handling nonconformances. */
            BEGIN
                update_disposition_status(
                    p_organization_id       => p_organization_id,
                    p_nonconformance_number => l_nonconformance_number,
                    p_verify_nc_number      => l_verify_nc_number,
                    p_disposition_number    => l_disposition_number,
                    p_status_update_method  => p_status_update_method,--CHG0047103
                    p_run_import            => p_run_import,
                    p_err_code              => l_err_code,
                    p_err_msg               => l_err_msg
                    );
            END;

            --write_message('l_nonconformance_number := ' || l_nonconformance_number);
            --write_message('l_verify_nc_number := ' || l_verify_nc_number);
            --write_message('l_disposition_number := ' || l_disposition_number);
            --write_message('p_organization_id := ' || p_organization_id);
            
            OPEN cur_results;
            
            --write_message('After cur_results in update_nonconformance_status');

            /* Loop through each of the nonconformances that may need to have their status updated. */
            LOOP
                /* (Re)initialize variables. */
                l_new_nc_status := NULL;
                l_rule_exception_flag := FALSE;
                l_status_update_required_flag := FALSE;
                l_log_number := NULL;--CHG0042815
                l_action_log_message := NULL;--CHG0042815
                l_log_business_rule_ref := NULL;--CHG0042815

                --write_message('Before FETCH in update_nonconformance_status');

                FETCH cur_results INTO l_rr;
                --write_message('After FETCH in update_nonconformance_status');
                EXIT WHEN cur_results%NOTFOUND;
                --write_message('After EXIT WHEN cur_results%NOTFOUND in update_nonconformance_status');
    
                --write_message('---' ||l_rr.n_nonconformance_number || ';' || l_rr.v_verify_nc_number|| ';' || l_rr.d_disposition_number || ';' ||l_rr.n_nonconformance_status || ' ---');
                --write_message('Prior/Current NC#: ' || l_prior_n_number || '/' || l_rr.n_nonconformance_number);

                /* Check if the current row has the same Nonconformance # as the previous row.
                       Commentary: Currently, business rules dictate that we only need to
                       examine the count of verification records and the count of
                       disposition records (and count of dispositions by status)  
                       in order to determine the new status.  Therefore,
                       we only need to examine the first row in the cursor for a given
                       nonconformance number.  Since we have fields that count the
                       verification and disposition records, we can check these and then "skip" over
                       additional rows for the nonconformance (which would occur if there
                       are multiple verifications or dispositions associated with it).

                       However, in the future, we may need to analyze individual fields
                       at the verification and/or disposition level to determine the
                       status of the nonconformance.  If this happens we can remove the
                       condition below and loop through each verification/disposition
                       since the cursor already has this level of detail (separate
                       rows for each combination of Nonconformance-Verification-
                       Disposition).
                    */

                IF l_prior_n_number <> l_rr.n_nonconformance_number THEN
                    --write_message('Start Case for determining the new Nonconformance Status.');
                    --write_message('l_rr.n_nonconformance_status: ' || l_rr.n_nonconformance_status);
                    --write_message('l_rr.v_verify_nc_row_count: ' || l_rr.v_verify_nc_row_count);
                    --write_message('l_rr.d_disposition_row_count: ' || l_rr.d_disposition_row_count);
                    --write_message('l_rr.d_disposition_status: ' || l_rr.d_disposition_status);
                    --write_message('l_rr.n_total_dispositions: ' || l_rr.n_total_dispositions);
                    --write_message('l_rr.n_closed_dispositions_count: ' || l_rr.n_closed_dispositions_count);
                    --write_message('l_rr.n_canceled_dispositions_count: ' || l_rr.n_canceled_dispositions_count);

                    /* Update variables that do not depend upon the business rules*/
                    l_new_inspector_name := l_rr.n_inspector_name;  --If using the Quality Results Interface to process the update, the inspector would otherwise get updated to be the user running the concurrent request to update the NC status.

                    /* Determine what the new status should be.  As business rules evolve, the criteria below can be modified to set the appropriate status. 
                       
                       Also, an option is to implement data driven business rules where the rules are defind in the from of a SQL statement that
                       is stored in a collection plan, similar to how Disposition Status rules are defined in the DISPOSITION_STATUSES_OMA collection plan.
                       The rules are relatively simple now so a CASE statement is sufficient.
                    */
                    CASE
                    /* 1.1) Nonconformance has neither a verification nor a disposition.  Current status is NEW.*/
                    WHEN l_rr.n_nonconformance_status = c_nc_status_new AND NVL(l_rr.v_verify_nc_row_count, 0) = 0 AND NVL(l_rr.n_total_dispositions, 0) = 0 THEN
                        l_log_business_rule_ref := 'Nonconformance Status - Business Rule #1.1';
                        --No status update is required
                        l_status_update_required_flag := FALSE;
                        l_rule_exception_flag := FALSE;

                    /* 1.2) CHG0042815: Nonconformance has a verification and a disposition. Current status is NEW, VERIFIED, or DISPOSITIONED.  At least one closed disposition exists.  All dispositions are closed or canceled.*/
                    WHEN l_rr.n_nonconformance_status IN (c_nc_status_new, c_nc_status_ver, c_nc_status_dis) --Current status is NEW, VERIFIED, or DISPOSITIONED.
                        AND NVL(l_rr.v_verify_nc_row_count, 0) <> 0 AND NVL(l_rr.n_total_dispositions, 0) <> 0 --At least one disposition exists, with a related verification and nonconformance.
                        AND (l_rr.n_closed_dispositions_count + l_rr.n_canceled_dispositions_count = NVL(l_rr.n_total_dispositions, 0)) --No disposition should have a status other than closed or canceled.
                        AND l_rr.n_closed_dispositions_count >= 1 --Need to have at least one closed disposition
                        THEN
                        l_log_business_rule_ref := 'Nonconformance Status - Business Rule #1.2';
                        l_new_nc_status := c_nc_status_clo; --CLOSED
                        l_status_update_required_flag := TRUE;
                        l_rule_exception_flag := FALSE;

                    /* 2.1) Nonconformance has a verification but does not have a disposition.  Current status is not VERIFIED. */
                    WHEN l_rr.n_nonconformance_status <> c_nc_status_ver AND NVL(l_rr.v_verify_nc_row_count, 0) <> 0 AND NVL(l_rr.n_total_dispositions, 0) = 0 THEN
                        l_log_business_rule_ref := 'Nonconformance Status - Business Rule #2.1';
                        l_new_nc_status := c_nc_status_ver;--VERIFIED
                        l_status_update_required_flag := TRUE;
                        l_rule_exception_flag := FALSE;

                    /* 2.2) Nonconformance has a verification but does not have a disposition.  Current status is VERIFIED. */
                    WHEN l_rr.n_nonconformance_status = c_nc_status_ver AND NVL(l_rr.v_verify_nc_row_count, 0) <> 0 AND NVL(l_rr.n_total_dispositions, 0) = 0 THEN
                        l_log_business_rule_ref := 'Nonconformance Status - Business Rule #2.2';
                        --No status update is required
                        l_status_update_required_flag := FALSE;
                        l_rule_exception_flag := FALSE;

                    /* 3.1) Nonconformance has a verification and a disposition. Current status is not DISPOSITIONED.*/
                    WHEN l_rr.n_nonconformance_status <> c_nc_status_dis AND NVL(l_rr.v_verify_nc_row_count, 0) <> 0 AND NVL(l_rr.n_total_dispositions, 0) <> 0 THEN
                        l_log_business_rule_ref := 'Nonconformance Status - Business Rule #3.1';
                        l_new_nc_status := c_nc_status_dis;--DISPOSITIONED
                        l_status_update_required_flag := TRUE;
                        l_rule_exception_flag := FALSE;

                    /* 4.1) Nonconformance has a verification and a disposition. Current status is DISPOSITIONED.  Not all dispositions are closed or cancelled.*/
                    WHEN l_rr.n_nonconformance_status = c_nc_status_dis AND NVL(l_rr.v_verify_nc_row_count, 0) <> 0 AND NVL(l_rr.n_total_dispositions, 0) <> 0 
                        AND (l_rr.n_closed_dispositions_count + l_rr.n_canceled_dispositions_count < NVL(l_rr.n_total_dispositions, 0))--Added for CHG0042815: no disposition should have a status other than closed or cancelled.
                        THEN
                        l_log_business_rule_ref := 'Nonconformance Status - Business Rule #4.1';
                        --No status update is required.
                        l_status_update_required_flag := FALSE;
                        l_rule_exception_flag := FALSE;
                    /* 5) Else */
                    ELSE
                        l_log_business_rule_ref := 'Nonconformance Status - Business Rule #5';
                        l_new_nc_status := NULL;
                        l_status_update_required_flag := FALSE;
                        l_rule_exception_flag := FALSE;

                    END CASE;
                    
                    write_message('l_log_business_rule_ref: ' || l_log_business_rule_ref);

                    /* Check to see if a status update is required (and if bypass is enabled). */
                    IF l_status_update_required_flag AND NOT c_bypass_update_flag THEN
                        --write_message('Update required and will not bypass it.' );
                        
                        /* CHG0042589: Check with method we need to used to update the Nonconformance Status (direct update vs. Quality Results Open Interface). */
                        
                        --IF c_direct_status_update_flag THEN
                        IF p_status_update_method = c_qrum_direct THEN --CHG0047103
                            --write_message('Direct update of Nonconformance Status is being used.' );
                            
                            /* Update the nonconformance status directly. */
                            update_result_value(
                                p_plan_id        => l_rr.n_plan_id --added CHG0046276
                                ,p_occurrence    => l_rr.n_occurrence
                                ,p_char_name     => c_cen_nonconformance_status
                                ,p_new_value     => l_new_nc_status
                                ,p_err_code      => l_err_code
                                ,p_err_msg       => l_err_msg --CHG0047103
                                );

                            /* If the ststus was successfully updated then log it. (CHG0042815)*/
                            IF l_err_code = c_success THEN
                                 /* Construct message for Quality Action Log Entry (CHG0042815)*/
                                build_action_log_message(
                                    p_element_name              => c_cen_nonconformance_status
                                    ,p_action_name              => c_n_action_uns 
                                    ,p_nonconformance_number    => l_rr.n_nonconformance_number  
                                    ,p_verify_nc_number         => l_rr.v_verify_nc_number   
                                    ,p_disposition_number       => l_rr.d_disposition_number 
                                    ,p_new_status               => l_new_nc_status  
                                    ,p_old_status               => l_rr.n_nonconformance_status
                                    ,p_disposition              => NULL
                                    ,p_occurrence               => l_rr.n_occurrence
                                    ,p_move_order_number        => NULL
                                    ,p_doc_instance_id          => NULL
                                    ,p_note                     => l_log_business_rule_ref
                                    ,p_message                  => l_action_log_message    
                                );
                                                            
                                /* Write to the Quality Action (CHG0042815)*/
                                create_quality_action_log_row(
                                    p_plan_id       => l_rr.n_plan_id,
                                    p_collection_id => l_rr.n_collection_id,
                                    p_creation_date => SYSDATE,
                                    p_char_id       => l_action_log_char_id, --For XX_NONCONFORMANCE_STATUS
                                    p_operator      => 7, --We use 7 which is "is entered" only because p_operator can't be null and if set to 0 it won't be visible in Action log.
                                    p_low_value     => NULL,
                                    p_high_value    => NULL,
                                    p_message       => l_action_log_message,
                                    p_result        => NULL,
                                    p_concurrent    => 1, --"online" (is being called as part of a concurrent request).  As of the initial release, this is always called in the context of a concurrent request so we hardcod this to 1.
                                    p_log_number    => l_log_number
                                    );
                            END IF;
                        --ELSE
                        ELSIF p_status_update_method = c_qrum_interface THEN --CHGOO47103
                            /* Use Quality Results Open Interface to update the nonconformance status. */
                            --write_message('Insert record into Quality Results Open Interface table.' );

                             /* Get the view names that will be used in the dynamic SQL*/
                            l_view_name_import := collection_plan_view_name(p_plan_type => c_plan_type_code_n, p_organization_id => l_rr.n_organization_id, p_view_type => c_plan_view_type_import); --Import view name for org-specific Nonconformance collection plan
                            --write_message('Name of import view determined: ' || l_view_name_import);

                            /* Verify that the view name is valid, in part to reduce risk of SQL injection.
                               Oracle will raise the exception, ORA-44002: invalid object name, if the view
                               does not exist. */
                            l_view_name_import := DBMS_ASSERT.SQL_OBJECT_NAME(str => l_view_name_import);--See the Oracle white paper, "How to write SQL injection proof PL/SQL".

                            --write_message('Existence of views confirmed');
                            --write_message('Build dynamic SQL');

                            l_organization_code := xxinv_utils_pkg.get_org_code(l_rr.n_organization_id);

                            /* Build a dynamic SQL Statement to insert a row in the Quality Results Open Interface Table.
                               Note the use of the alternative quoting
                               mechanism (Q') using "[" as the quote_delimiter.  This is to make the
                               use of single quotes in the variable clearer. Note that bind variables
                               are not, and cannot, be used because the view/table names will be
                               different across orgs. (Bind variables can't be used to specify table or
                               view names.)
                            */
                            l_dynamic_sql :=
                                Q'[INSERT INTO ]' || l_view_name_import || Q'[
                                (
                                    qa_last_updated_by_name
                                    ,collection_id
                                    ,process_status
                                    ,organization_code
                                    ,plan_name
                                    ,insert_type
                                    ,matching_elements
                                    ,xx_nonconformance_number
                                    ,xx_nonconformance_status
                                    ,xx_inspector_name
                                    ,item
                                )
                                VALUES (
                                    fnd_global.USER_NAME --qa_last_updated_by_name
                                    ,]' || l_rr.n_collection_id || Q'[--collection_id
                                    ,1 --process_status  --Running(2), Error(3) or Completed(4) MANDATORY FIELD
                                    ,']' || l_organization_code || Q'[' --organization_code MANDATORY FIELD
                                    ,']' || l_rr.n_plan_name || Q'[' --plan_name MANDATORY FIELD
                                    ,2 --insert_type  (1: create, 2: update) We choose 2 here since we want to update an existing record.
                                    ,'COLLECTION_ID,XX_NONCONFORMANCE_NUMBER' --Matching Elements: This is a comma-separated list of column names. Collection Import uses these column names as search keys when it updates existing records in the Quality data repository.
                                    ,']' || l_rr.n_nonconformance_number || Q'[' --xx_nonconformance_number
                                    ,']' || l_new_nc_status || Q'[' --New Nonconformance Status
                                    ,']' || l_new_inspector_name || Q'[' --Inspector Name
                                    ,']' || l_rr.n_item || Q'[' --Item 01-Mar-2019
                                    )]'
                                    ;
                            /* Write the SQL statement to the log file so that it can be debugged should issues arise. */
                            --write_message('SQL Statement in variable "l_dynamic_sql":' );
                            --write_message(l_dynamic_sql );

                            /* Execute the dynamic SQL statement. */
                            EXECUTE IMMEDIATE l_dynamic_sql;

                            COMMIT;

                            l_rows_inserted_count := l_rows_inserted_count + 1; --Increment the counter

                            write_message('Request ID: ' || fnd_global.conc_request_id);
                        ELSE
                            write_message('Unrecognized value for p_status_update_method: ' || p_status_update_method);
                        END IF;
                        
                        l_previous_row_updated_flag := TRUE; --Flag that we did an update for this row

                    ELSE
                        --write_message('Update not required or insert bypassed.');
                        
                        l_previous_row_updated_flag := FALSE; --Don't flag that we did an update for this row
                    END IF;
                ELSE
                    --write_message('Prior NC and current NC are the same');
                    NULL;
                END IF;

                /* Construct the log file message. */
                l_log_comment :='Nonconformance #' || l_rr.n_nonconformance_number
                || ' (' || l_rr.n_plan_name || ')'
                || ', Verify Nonconformance #' || l_rr.v_verify_nc_number
                || ' (' || l_rr.v_verify_nc_row || ' of ' || l_rr.v_verify_nc_row_count || ')'
                || ', Disposition #' || l_rr.d_disposition_number
                || ' (' || l_rr.d_disposition_row || ' of ' || l_rr.d_disposition_row_count || ').';

                IF NOT l_rule_exception_flag THEN
                    IF l_status_update_required_flag THEN
                        l_log_comment:= l_log_comment
                        || ' Status to be updated from ' || l_rr.n_nonconformance_status
                        || ' to ' ||  l_new_nc_status || '.';
                    ELSE
                        l_log_comment:= l_log_comment
                        || ' Status update is not required. Current status is ' || l_rr.n_nonconformance_status || '.';
                    END IF;

                ELSE
                    l_log_comment:= l_log_comment
                    || ' Exception encountered.';
                END IF;

                /* Write to log file. */
                write_message('Log comment: ' || l_log_comment);

                /* Assign "prior" values for Nonconformance #, Verification #, and Disposition # in preparation for the next iteration in the loop. */
                l_prior_n_number := l_rr.n_nonconformance_number;
                l_prior_v_number := l_rr.v_verify_nc_number;
                l_prior_d_number := l_rr.d_disposition_number;

            END LOOP;

            write_message('Rows inserted into interface table: ' || l_rows_inserted_count);

            /* Did we put any rows into the interface table? */
            IF l_rows_inserted_count > 0 THEN
                /* Do we need to run Collection Import Manager?*/
                IF p_run_import = c_yes THEN
                    write_message('Call launch_collection_import in update mode (transaction type: 2).');
                    launch_collection_import(
                        p_transaction_type      => 2 --Transaction Type [1: Insert Transaction, 2: Update Transaction]
                        ,p_wait_for_completion  => TRUE --TRUE: wait until the entire result import process has completed
                        ,p_max_sleep_duration   => c_max_sleep_duration
                        ,p_import_result_status => l_import_result_status --Status of the import process
                    );

                write_message('Import Result Status: ' || l_import_result_status);

                ELSE
                    write_message('Bypassed running Collection Import Manager.');
                END IF;
            END IF;

            /* Set the status of the concurrent request via retcode. This is necessary when this procedure
               is called directly from an EBS executable. */
            CASE WHEN l_import_result_status IN (c_import_status_s, c_import_status_t) THEN
                l_log_comment   := 'Collection import has not yet finished running so the nonconformance status may not yet be updated.';
                write_message(l_log_comment);
                errbuf := NULL;
                retcode := '1'; --Warning - Yellow
            WHEN l_import_result_status = c_import_status_e THEN
                l_log_comment   := 'An exception was encountered during the collection import process.  The nonconformance status may not have been updated.';
                write_message(l_log_comment);
                errbuf := NULL;
                retcode := '1'; --Warning - Yellow
            ELSE
                l_log_comment   := 'Nonconformance status updated successfully.';
                write_message(l_log_comment);
                errbuf := NULL;
                retcode := '0'; --Success - Green
            END CASE;
        END IF;--l_result_status
    EXCEPTION
        WHEN OTHERS THEN  -- Handle all other errors
            l_log_comment := 'Exception in ' || c_method_name || ': ' || SQLERRM ;
            write_message(l_log_comment);
            errbuf  := l_log_comment;
            retcode := '2'; --Error - Red
    END update_nonconformance_status;

    ----------------------------------------------------------------------------------------------------
    --  Name:               update_disposition_status
    --  Created By:         Hubert, Eric
    --  Revision:           1.1
    --  Creation Date:      16-Oct-2019
    --  Purpose:            Updates the Disposition Status element of a
    --    disposition record and manages related actions.
    --
    --  Description:
    --    Loops through all eligible dispositions and updates the status if needed.
    --    It is possible that a disposition could have its status updated
    --    multiple times as long as the business rules continue to be met.
    --
    -- In the future, the logic could be reimplemented as a true Oracle Workflow.
    --
    --  Also, some business rules and bug fixes have been implemented in this procedure
    --  since it was first developed.  As a result, this procedure could probably
    --  be rewritten to be more efficient/elegant/easier-to-understand.
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   16-Oct-2019   Hubert, Eric    CHG0042815
    --  1.1   24-Oct-2019   Hubert, Eric    CHG0046276: pseudo-parallel branching for evaluating status rules
    --  2.0   01-Apr-2020   Hubert, Eric    CHG0047103:
    --                                      -rewrote loop control structure for disposition status criteria rules to simplify it and improve readability
    --                                      -added p_results_update_method
    --                                      -created default value for p_run_import
    --                                      -added p_err_code and p_err_msg
    --  2.0   01-Apr-2021   Hubert, Eric    CHG0049611: updated parameters for call to nonconformance_report_data
    /* Future improvements:
    1) read the rows returned by quality rules into a table variable and reference that table in the select for cur_disposition_status_rules 
       to reduce database reads.  Table with records same as type q_disposition_statuses_oma_v
    2) There is a current limitation in that a given Disposition Status can't be used multiple times for the same Disposition in DISPOSITION_STATUSES_OMA.
       For example, using Scrap, we can't have an APPROVED rule at Seq 30 and another APPROVED rule at Seq 100.  This is because we look up the starting
       rule based on the current Disposition Status (and then start checking the next rule) and the cursor would error if it matches on two APPROVED rows.  There is no immediate
       need to change this behavior but is being mentioned in case somebody tries to use the same Disposition Status twice for the same disposition
       in DISPOSITION_STATUSES_OMA.
    */
    ----------------------------------------------------------------------------------------------------
    PROCEDURE update_disposition_status (
         p_organization_id        IN NUMBER
        ,p_nonconformance_number  IN qa_results.sequence5%TYPE --Nonconformance Number
        ,p_verify_nc_number       IN qa_results.sequence6%TYPE DEFAULT NULL --Verify Nonconformance Number
        ,p_disposition_number     IN qa_results.sequence7%TYPE DEFAULT NULL--Disposition Number
        ,p_status_update_method   IN NUMBER DEFAULT c_qrum_direct --Added parameter (CHG0047103)
        ,p_run_import             IN VARCHAR2 DEFAULT c_no -- Run Collection Import Manager after inserting records into interface table
        ,p_err_code               OUT NUMBER --CHG0047103
        ,p_err_msg                OUT VARCHAR2 --CHG0047103
    )
    IS
        c_method_name CONSTANT VARCHAR(30) := 'update_disposition_status';
        
        /* Local constants for program control and debugging. */
        --c_direct_status_update_flag CONSTANT BOOLEAN := TRUE; --Use TRUE to directly update Nonconformance Status and Disposition Status in qa_results.  Use FALSE to use the Quality Results Open Interface.  The direct update option was introduced to improve the user experience so that they would not need to wait a "long" time for control to return to the form.
        c_bypass_update_flag        CONSTANT BOOLEAN := FALSE; --Execute the procedure without inserting rows into the Quality Results Open Interface table or directly updating the Disposition Status.

        /* Local constants for modes on how to Disposition Status rules/criteria will be retrieved in a cursor.*/
        c_dsrm_ds CONSTANT VARCHAR2(30) := 'DISPOSITION_STATUS';
        c_dsrm_cs CONSTANT VARCHAR2(30) := 'CRITERIA_SEQUENCE';
        
        /* Cursors */
        CURSOR cur_results IS (
            /* This SQL returns information required for disposition status processing. 
               
               Note: nonconformance_report_data is not a particularly fast-performing 
               function, so keep that in mind if looking for ways to improve the 
               performance of update_disposition_status.
            */
            SELECT *
            FROM TABLE (nonconformance_report_data
                    (
                        p_sequence_1_value    => p_nonconformance_number
                        ,p_sequence_2_value   => p_verify_nc_number
                        ,p_sequence_3_value   => p_disposition_number
                        ,p_organization_id    => p_organization_id
                        ,p_occurrence         => NULL
                        ,p_nc_active_flag     => c_yes
                        ,p_disp_active_flag   => c_yes
                        ,p_disposition_status => NULL
                        ,p_disposition        => NULL               
                    )
                )

        )
        ORDER BY n_organization_id, n_nonconformance_number, v_verify_nc_number, d_disposition_number;

        CURSOR cur_disposition_status_rules
            /* Parameters for cursor*/
            (
                cp_mode                 VARCHAR2                    --Indicates if we'll retrieve rules based on a criteria sequence number, or, a disposition status
                ,cp_disposition         qa_results.character1%TYPE  --Disposition
                ,cp_disposition_status  qa_results.character1%TYPE  --Disposition Status (optional)
                ,cp_rule_sequence       NUMBER                      --Criteria/rule Sequence number (optional) as specified in collection plan DISPOSITION_STATUSES_OMA result records
                ,cp_sequence_offset     NUMBER := 0                 --For all modes, an offset to the specified disposition status or criteria sequence number can be specified
            )
        IS
            /* We'll build relative complexity into the SQL of the cursor in order to keep the subsequent loops in the procedure as simple as possible. */
            SELECT * FROM
            (
            WITH sq_qdsov AS (
                /* This subquery returns criteria for a specific Disposition with some calculations to order and count the rules
                   for use later in the SQL statement.
                */
                SELECT
                    DENSE_RANK() OVER (PARTITION BY xx_disposition ORDER BY xx_sequence) intra_disposition_dense_rank --Order the rules for a given type of disposition.  Rows sharing the same sequence number will have the same rank.
                    ,xx_sequence --Order of execution of the rules 
                    ,ROW_NUMBER() OVER (PARTITION BY xx_disposition, xx_sequence ORDER BY xx_disposition_status) intra_sequence_row_number --Row numbering within a group of rows sharing the same sequence.  Rules sharing the same sequence are inferred to be logical "OR" statements.
                    ,COUNT(*) OVER (PARTITION BY xx_disposition, xx_sequence) intra_sequence_row_count --Count of rows sharing the same sequence
                    ,xx_disposition
                    ,xx_disposition_status
                    ,xx_disposition_status_criteria --If the SQL statement in this field return one or more rows, then the criteria for that Disposition Statuses (xx_disposition_status) have been satisfied.
                    ,xx_comments_long --BA/developer comments
                FROM q_disposition_statuses_oma_v --qdsov
                WHERE 1=1
                    AND xx_disposition = cp_disposition
                ORDER BY
                    xx_disposition
                    ,xx_sequence
                    ,xx_disposition_status
            )
            SELECT  
                sq_qdsov.*
            FROM sq_qdsov
            WHERE
                /* There are two scenarios supported by a conditional WHERE clause: get rules to try based on the 
                   name of the (current) Disposition Status, or, by specifying the Sequence number associated with a criteria/rule record.
                   For both scenarios, an offset can be specified.  This offset is based on the xx_sequence and not "intra-sequence"
                   rows.  
                   
                   Example: assume we have rules (for a specific disposition) defined with sequences of 10, 20, 20, 30, 30, 30, and 40.
                   -If we request the rules for 20 with an offset of +1 then we'll be returned the three rows with a sequence of 30.
                   -If we request the rules for 30 with an offset of -1 then we'll be returned the two rows with a sequence of 20.
                   -If we request the rules for 30 with an offset of +1 then we'll be returned the one row with a sequence of 40.
                */
                CASE 
                    /* Scenario 1: explicit disposition status name, and, offset */
                    WHEN cp_mode = c_dsrm_ds --disposition status
                         AND intra_disposition_dense_rank = (
                            SELECT DISTINCT intra_disposition_dense_rank --Distinct because we could have the same sequence for multiple criteria rows
                            FROM sq_qdsov
                            WHERE xx_disposition_status = cp_disposition_status
                            ) + cp_sequence_offset --Add the specified offset
                    THEN
                        1
                        
                    /* Scenario 2: explicit criteria sequence number, and, offset */
                    WHEN cp_mode = c_dsrm_cs --criteria sequence
                         AND intra_disposition_dense_rank = (
                            SELECT DISTINCT intra_disposition_dense_rank --Distinct because we could have the same sequence for multiple criteria rows
                            FROM sq_qdsov
                            WHERE xx_sequence = cp_rule_sequence
                            ) + cp_sequence_offset --Add the specified offset
                    THEN
                        1
                    ELSE
                        0
                END = 1 --There is nothing special about the number "1".  It's just used to match the "THEN"s to create a conditional WHERE clause.
        
        );
        
        /* Cursor row type variables */
        l_rr   cur_results%ROWTYPE;
        l_dsr  cur_disposition_status_rules%ROWTYPE;
                
        /* Local Variables */
        l_organization_code         mtl_parameters.organization_code%TYPE; --Inventory Org Code
        l_new_inspector_name        qa_results.character1%TYPE; --We'll use the EXISTING Inspector Name for the disposition.
        l_log_comment               VARCHAR2(1024); -- Debug/concurrent request log comment.
        l_view_name_import          qa_plans.view_name%TYPE; --Import view name for org-specific Disposition collection plan
        l_dynamic_sql               VARCHAR2(2000);  --Stores dynamic SQL statement
        l_err_code                  NUMBER;
        l_err_msg                   VARCHAR2(1000);

        /* Local variables for workflow message updating*/
        l_wf_msg                    qa_results.character1%TYPE;

        /* Local variables for writing to the Quality Action Log */
        l_action_log_char_id        NUMBER; --char_id for Quality Action Log
        l_action_log_message        qa_action_log.action_log_message%TYPE; --Message for Quality Action Log
        l_log_number                NUMBER; --Quality Action Log number
        
        /* Local variables for program control/flow */
        l_status_update_required_flag   BOOLEAN; --The status of a given disposition needs to be updated after rules were evaluated.
        l_rows_inserted_count           NUMBER := 0; --Keeps track of how many rows were inserted into the quality results interface table
        l_import_result_status          VARCHAR2(30); --Status of the import process (if Collection Import is run, per the p_run_import parameter)
        l_rules_exhausted_flag          BOOLEAN; --Flags the program flow to stop evaluating rules for the current disposition
       
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('program unit: ' || gv_log_program_unit);

        --write_message('p_status_update_method: ' || p_status_update_method );
        
        /* Get the char_id for the disposition status element. */
        l_action_log_char_id := qa_core_pkg.get_element_id(c_cen_disposition_status);

        OPEN cur_results;
        
        write_message(c_method_name || ': Before Dispositions Loop');
        
        /* Loop through each of the nonconformance dispositions that may need to have their status updated. 
            FUTURE REFACTORING: Ideally, to eliminate redundant code, this loop should be integrated into update_nonconformance status for CHG0042815, and
            call update_disposition_status within the loop, if business rules require it. However, the business rules for updating
            the nonconformance status are currently not as elaborate as for the disposition status so it is ok to keep them separate now.
        */
        LOOP

            FETCH cur_results INTO l_rr;
            
            --write_message('--update_disposition_status: after cur_results fetch');
            
            EXIT WHEN cur_results%NOTFOUND;

            write_message('--- ' || l_rr.n_nonconformance_number || ';' || l_rr.v_verify_nc_number|| ';' || l_rr.d_disposition_number || ';' || l_rr.n_nonconformance_status || ' ---');
            --write_message('l_rr.n_nonconformance_status: ' || l_rr.n_nonconformance_status);
            --write_message('l_rr.v_verify_nc_row_count: ' || l_rr.v_verify_nc_row_count);
            --write_message('l_rr.d_disposition_row_count: ' || l_rr.d_disposition_row_count);
            --write_message('l_rr.d_disposition_status: ' || l_rr.d_disposition_status);

            /* Update variables that do not depend upon the business rules*/
            l_new_inspector_name := l_rr.n_inspector_name;  --If using the Quality Results Interface to process the update, the inspector would otherwise get updated to be the user running the concurrent request to update the NC status.

            /* Initialize some variables before the rules loop */
            l_rules_exhausted_flag := FALSE;

            /* Continue to evaluate disposition status criteria/rules until no rows for a given sequence evaluate to true. */
            WHILE NOT l_rules_exhausted_flag LOOP

                --write_message('--Cursor Parameters--');
                --write_message('c_dsrm_ds: ' || c_dsrm_ds);
                --write_message('l_rr.d_disposition: ' || l_rr.d_disposition);
                --write_message('l_rr.d_disposition_status: ' || l_rr.d_disposition_status);

                /* Open cursor to get the disposition rules for the sequence after the disposition's current status. (No need to evaluate the rule for the current status)*/
                OPEN cur_disposition_status_rules(
                    cp_mode                 => c_dsrm_ds --Get rules based on matching the status of the current disposition record to a rule
                    ,cp_disposition         => l_rr.d_disposition
                    ,cp_disposition_status  => l_rr.d_disposition_status --Need to update this as we update the status.  Use a table type for l_rr so that we can do this on the fly
                    ,cp_rule_sequence       => NULL --Not required when we're getting rules based on the disposition status
                    ,cp_sequence_offset     => 1 --Get the rules for one sequence past the disposition's current status
                );

                /* Loop through all rules for the sequence number, exiting when a rule evaluates to True. */
                LOOP
                    FETCH cur_disposition_status_rules INTO l_dsr;

                    IF cur_disposition_status_rules%NOTFOUND THEN

                        --write_message('cur_disposition_status_rules%NOTFOUND');
                       
                        /* No more rules to test for this disposition. */
                        l_rules_exhausted_flag := TRUE;

                        CLOSE cur_disposition_status_rules;
                        
                        EXIT;
                    ELSE
                        /* CHG0046276: for dispositions that require a workflow for approval (i.e. Scrap), update the workflow
                           comment field on the disposition to indicate the next approver.  Note: this branch of code can
                           be eliminated if a Workflow History sub form is ever implemented for the Disposition Collection plan result forms.
                           Yuval informally indicated that such a from should not be too much work.
                           
                           Criteria:
                           1) Disposition = S (Scrap) 
                           2) Disposition Status = NEW, PENDING_APPROVAL, APPROVED or REJECTED (it is not optimal, but we need to include APPROVED/REJECTED so that the WF msg doesn't get stuck on Status=IN_PROCESS)
                        */
                        
                        IF l_rr.d_disposition = c_disp_s AND l_rr.d_disposition_status IN
                            (
                                 c_d_status_pea --pending approval
                                ,c_d_status_app --approved
                                ,c_d_status_rej --rejected
                            ) THEN

                            /* If the workflow message indicates In Process then allow the message to continue to be updated.
                               Skipping this will keep the user from having to re-query the disposition record on the Update Quality Results form
                               if they make a change to the record after the update_disposition_status procedure runs while they have the disposition record
                               displayed.
                            */
                            IF l_rr.d_workflow_message LIKE ('%' || c_xwds_inprocess ||'%') THEN
                                /* Build the workflow status message. */
                                l_wf_msg := build_disposition_wf_message(
                                    p_disposition_number => l_rr.d_disposition_number
                                    ,p_event_name        => NULL
                                    ,p_note              => NULL
                                );

                                /* Write the message to the XX_WORKFLOW_MESSAGE element on the Disposition record.
                                   This update will be done directly.  If there is a need to update the value via the
                                   Quality Results Open Interface, then use an approach similar to the update_disposition_status
                                   procedure that facilitates both methods.
                                */
                                --write_message('before wf_update_disposition_msg');

                                wf_update_disposition_msg (
                                    p_plan_id        => l_rr.d_plan_id
                                    ,p_occurrence    => l_rr.d_occurrence
                                    ,p_new_value     => l_wf_msg
                                    ,p_err_code      => l_err_code);

                                --We're not bothering to check l_err_code since updating the message is informational and not critical to the process.
                            END IF;
                        END IF; --End workflow message update (CHG0046276)

                        --write_message('--Rule Record--');
                        --write_message('l_dsr.xx_sequence: ' || l_dsr.xx_sequence);
                        --write_message('l_dsr.intra_sequence_row_number: ' || l_dsr.intra_sequence_row_number);
                        --write_message('l_dsr.xx_disposition_status: ' || l_dsr.xx_disposition_status);
                                                
                        /* Evaluate criteria for disposition status row. */
                        l_status_update_required_flag := eval_disp_status_criteria(
                             p_organization_id        => l_rr.n_organization_id
                            ,p_disposition_number     => l_rr.d_disposition_number
                            ,p_criteria_sql_statement => l_dsr.xx_disposition_status_criteria  
                        );
                        
                        --write_message('l_status_update_required_flag: ' || CASE WHEN l_status_update_required_flag THEN 'TRUE' ELSE 'FALSE' END);

                        IF l_status_update_required_flag THEN

                            /* Criteria is met for the current disposition status row.  Need to update the disposition to have this status. */
                            --write_message('Criteria evaluates to TRUE.  Need to update to next status.' );
                            
                            /* Check if bypass is enabled (for debugging). */
                            IF NOT c_bypass_update_flag THEN
                                --write_message('Update required and will not bypass it.' );
                                
                                /* CHG0042815: Check witch method we need to use to update the Disposition Status (direct update vs. Quality Results Open Interface). 
                                   Both options are provided.  The direct update to allows for much faster performance and bypasses the firing of quality actions, 
                                   which keeps collection plan setup (and regression testing) simple for the BA.  However, using the interface is the method
                                   that Oracle supports for updating quality results, so we have that available if we need it.
                                */
                                --IF c_direct_status_update_flag THEN
                                IF p_status_update_method = c_qrum_direct THEN --CHG0047103
                                    --write_message('update_disposition_status p_status_update_method = c_qrum_direct' );
                                    
                                    /* Update the disposition status directly. */
                                    update_result_value(
                                        p_plan_id        => l_rr.d_plan_id --added CHG0046276
                                        ,p_occurrence    => l_rr.d_occurrence
                                        ,p_char_name     => c_cen_disposition_status
                                        ,p_new_value     => l_dsr.xx_disposition_status
                                        ,p_err_code      => l_err_code
                                        ,p_err_msg       => l_err_msg --CHG0047103
                                        );

                                --ELSE
                                ELSIF p_status_update_method = c_qrum_interface THEN --CHGOO47103
                                    /* Use Quality Results Open Interface to update the disposition status. */
                                    --write_message('Insert record into Quality Results Open Interface table.' );

                                     /* Get the view names that will be used in the dynamic SQL*/
                                    l_view_name_import := collection_plan_view_name(p_plan_type => c_plan_type_code_d, p_organization_id => l_rr.n_organization_id, p_view_type => c_plan_view_type_import); --Import view name for org-specific Disposition collection plan
                                    --write_message('Name of import view determined: ' || l_view_name_import);

                                    /* Verify that the view name is valid, in part to reduce risk of SQL injection.
                                       Oracle will raise the exception, ORA-44002: invalid object name, if the view
                                       does not exist. */
                                    l_view_name_import := DBMS_ASSERT.SQL_OBJECT_NAME(str => l_view_name_import);

                                    --write_message('Existence of views confirmed');
                                    --write_message('Build dynamic SQL');

                                    l_organization_code := xxinv_utils_pkg.get_org_code(l_rr.n_organization_id);

                                    /* Build a dynamic SQL Statement to insert a row in the Quality Results Open Interface Table.
                                       Note the use of the alternative quoting
                                       mechanism (Q') using "[" as the quote_delimiter.  This is to make the
                                       use of single quotes in the variable clearer. Note that bind variables
                                       are not, and cannot, be used because the view/table names will be
                                       different across orgs. (Bind variables can't be used to specify table or
                                       view names.)
                                    */
                                    l_dynamic_sql :=
                                        Q'[INSERT INTO ]' || l_view_name_import || Q'[
                                        (
                                            qa_last_updated_by_name
                                            ,collection_id
                                            ,process_status
                                            ,organization_code
                                            ,plan_name
                                            ,insert_type
                                            ,matching_elements
                                            ,xx_disposition_number
                                            ,xx_disposition_status
                                            ,xx_inspector_name
                                        )
                                        VALUES (
                                            fnd_global.USER_NAME --qa_last_updated_by_name
                                            ,]' || l_rr.d_collection_id || Q'[--collection_id
                                            ,1 --process_status  --Running(2), Error(3) or Completed(4) MANDATORY FIELD
                                            ,']' || l_organization_code || Q'[' --organization_code MANDATORY FIELD
                                            ,']' || l_rr.d_plan_name || Q'[' --plan_name MANDATORY FIELD
                                            ,2 --insert_type  (1: create, 2: update) We choose 2 here since we want to update an existing record.
                                            ,'COLLECTION_ID,XX_DISPOSITION_NUMBER' --Matching Elements: This is a comma-separated list of column names. Collection Import uses these column names as search keys when it updates existing records in the Quality data repository.
                                            ,']' || l_rr.d_disposition_number || Q'[' --xx_disposition_number
                                            ,']' || l_dsr.xx_disposition_status || Q'[' --New Disposition Status
                                            ,']' || l_new_inspector_name || Q'[' --Inspector Name
                                            )]'
                                            ;
                                            
                                    /* Write the SQL statement to the log file so that it can be debugged should issues arise. */
                                    --write_message('----SQL Statement in variable "l_dynamic_sql":' );
                                    --write_message(l_dynamic_sql );

                                    /* Execute the dynamic SQL statement. */
                                    EXECUTE IMMEDIATE l_dynamic_sql;

                                    COMMIT;

                                    l_rows_inserted_count := l_rows_inserted_count + 1; --Increment the counter
                                    --write_message('l_rows_inserted_count: ' || l_rows_inserted_count);
                                    --write_message('----Request ID: ' || fnd_global.conc_request_id);
                                ELSE
                                    write_message('Unrecognized value for p_status_update_method: ' || p_status_update_method); --CHGOO47103
                                END IF; --check p_status_update_method                            
                                
                                /* If the status was successfully updated then log it. (CHG0042815)
                                   
                                   This is only applicable to directly-update records currently, but
                                   this could be expanded to write a message to the action log
                                   to indicate that a Disposition Status is pending via
                                   the Quality Results interface.                                
                                */
                                IF l_err_code = c_success THEN
                                    /* Construct message for Quality Action Log Entry */
                                    build_action_log_message(
                                        p_element_name              => c_cen_disposition_status
                                        ,p_action_name              => c_d_action_uds 
                                        ,p_nonconformance_number    => l_rr.n_nonconformance_number  
                                        ,p_verify_nc_number         => l_rr.v_verify_nc_number   
                                        ,p_disposition_number       => l_rr.d_disposition_number 
                                        ,p_new_status               => l_dsr.xx_disposition_status   
                                        ,p_old_status               => l_rr.d_disposition_status 
                                        ,p_disposition              => l_rr.d_disposition
                                        ,p_occurrence               => l_rr.d_occurrence
                                        ,p_move_order_number        => l_rr.d_disposition_move_order
                                        ,p_doc_instance_id          => NULL
                                        ,p_note                     => NULL
                                        ,p_message                  => l_action_log_message    
                                    );
                                                                
                                    /* Write to the Quality Action Log BASE MESSAGE ON TYPE OF UPDATE (p_concurrent)*/
                                    create_quality_action_log_row(
                                        p_plan_id       => l_rr.d_plan_id,
                                        p_collection_id => l_rr.d_collection_id,
                                        p_creation_date => SYSDATE,
                                        p_char_id       => l_action_log_char_id, --For XX_DISPOSITION_STATUS
                                        p_operator      => 7, --We use 7 which is "is entered" only because p_operator can't be null and if set to 0 it won't be visible in Action log.
                                        p_low_value     => NULL,
                                        p_high_value    => NULL,
                                        p_message       => l_action_log_message,
                                        p_result        => NULL,
                                        p_concurrent    => 1, --"online" (is being called as part of a concurrent request).  As of the initial release, this is always called in the context of a concurrent request, so we hardcode this to 1.
                                        p_log_number    => l_log_number
                                        );

                                    write_message('l_log_number: ' || l_log_number);

                                END IF;
                            ELSE
                                write_message('Update bypassed.');
                            END IF; --check c_bypass_update_flag

                            /* Update l_rr.d_disposition_status to be the new status value.  This will allow the same disposition to 
                               be evaluated again, without having to reopen cur_results, which will significantly help performance. */
                            --write_message('----Update l_rr.d_disposition_status to:' || ds.xx_disposition_status);
                            l_rr.d_disposition_status :=  l_dsr.xx_disposition_status;
                            write_message('Post-update, l_rr.d_disposition_status: ' || l_rr.d_disposition_status);

                            /* No need to test any more rules for this sequence, so update the flag so that we keep trying to progress the disposition status. */
                            l_rules_exhausted_flag := FALSE;
                            
                            CLOSE cur_disposition_status_rules;
                            
                            EXIT; --Exit the loop for the current sequence.

                        END IF; --check l_status_update_required_flag

                    END IF; --cur_disposition_status_rules%NOTFOUND
                    
                END LOOP; --l_dsr

            END LOOP; --l_rules_exhausted_flag 

        END LOOP; --l_rr
        write_message(c_method_name || ': After Dispositions Loop');

        /* Did we put any rows into the interface table? */
        IF l_rows_inserted_count > 0 THEN
        
            /* Do we need to run Collection Import Manager?*/
            IF p_run_import = c_yes THEN
                write_message('Call launch_collection_import in update mode (transaction type: 2).');
                launch_collection_import(
                    p_transaction_type      => 2 --Transaction Type [1: Insert Transaction, 2: Update Transaction]
                    ,p_wait_for_completion  => TRUE --TRUE: wait until the entire result import process has completed
                    ,p_max_sleep_duration   => c_max_sleep_duration
                    ,p_import_result_status => l_import_result_status --Status of the import process
                );

            write_message('Import Result Status: ' || l_import_result_status);

            ELSE
                write_message('Bypassed running Collection Import Manager.');
            END IF;
        END IF;
        
        /* Set the status of the concurrent request. */
        CASE WHEN l_import_result_status IN (c_import_status_s, c_import_status_t) THEN
            l_log_comment   := 'Collection import has not yet finished running so the disposition status may not yet be updated.';
            write_message(l_log_comment);
        WHEN l_import_result_status = c_import_status_e THEN
            l_log_comment   := 'An exception was encountered during the collection import process.  The disposition status may not have been updated.';
            write_message(l_log_comment);
        ELSE
            l_log_comment   := 'Disposition status processing completed successfully.';
            write_message(l_log_comment);
        END CASE;

        p_err_code := c_success;
        p_err_msg  := l_log_comment;

    EXCEPTION
        WHEN OTHERS THEN  -- Handle all other errors
            p_err_code := c_fail;
            l_log_comment := 'Exception in ' || c_method_name || ': ' || SQLERRM;
            write_message(l_log_comment);
    END update_disposition_status;

    ----------------------------------------------------------------------------------------------------
    --  Name:               build_action_log_message
    --  Created By:         Hubert, Eric
    --  Revision:           1.1
    --  Creation Date:      16-Oct-2019
    --  Purpose:            Builds a message for insertion into the Quality Action Log.
    --                      The message is in the from of an XML element string.
    --
    --  Description:        This can be used for both Disposition Status updates
    --                      and Nonconformance Status updates.  
    --                      Reasons why XML is used:
    --                       1) We don't need to come up with our own delimited attribute/value pair format
    --                       2) While the message in the Quality Action Log does need to be human-readable (and it is with XML), for our purposes, it is more likely to be consumed in a programatic manner.
    --                       3) XML-based parsing can be optionally employed on the Quality Action Log message, instead of basic string functions or even Regular Expressions.
    --                       4) The quality action log message field is sufficiently large to handle the extra characters due to XML tags.
    --
    --                       At this time, there is no schema and we don't use a prolog i.e., "<?xml version="1.0" encoding="UTF-8"?>", though this could be easily added in the future.  It simply is not needed right now.
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   16-Oct-2019   Hubert, Eric    CHG0042815
    --  1.1   01-Apr-2020   Hubert, Eric    CHG0047103: added parameters p_move_order_number and p_doc_instance_id
    ----------------------------------------------------------------------------------------------------
    PROCEDURE build_action_log_message(
        p_element_name           IN qa_chars.name%TYPE--Name of element related to the action
        ,p_action_name           IN VARCHAR2--Name of current action
        ,p_nonconformance_number IN qa_results.sequence5%TYPE --Nonconformance Number
        ,p_verify_nc_number      IN qa_results.sequence6%TYPE DEFAULT NULL --Verify Nonconformance Number
        ,p_disposition_number    IN qa_results.sequence7%TYPE DEFAULT NULL--Disposition Number
        ,p_new_status            IN VARCHAR2 DEFAULT NULL--Nonconformance/Disposition Status
        ,p_old_status            IN VARCHAR2 DEFAULT NULL--Nonconformance/Disposition Status
        ,p_disposition           IN VARCHAR2 DEFAULT NULL--Disposition
        ,p_occurrence            IN qa_results.occurrence%TYPE--Occurrence # from qa_results
        ,p_move_order_number     IN mtl_txn_request_headers.request_number%TYPE DEFAULT NULL--CHG0047103
        ,p_doc_instance_id       IN NUMBER   DEFAULT NULL--CHG0047103
        ,p_note                  IN VARCHAR2 DEFAULT NULL --Additional note text
        ,p_message               OUT VARCHAR2
        ) AS
            c_method_name CONSTANT VARCHAR(30) := 'build_action_log_message';

            /* Local variables */
            l_xml XMLType;
            l_action_log_message qa_action_log.action_log_message%TYPE; --Message for Quality Action Log
            l_sql VARCHAR2(2000); --Dynamic SQL
                                    
            /* Move these XML-related constants for element names to the package spec or body header when/if they ever need to be referenced when parsing the action log message. */
            c_xml_elm_ssys  CONSTANT VARCHAR2(30) := 'xxSsys';
            c_xml_elm_occ   CONSTANT VARCHAR2(30) := 'occurrence';
            c_xml_elm_nn    CONSTANT VARCHAR2(30) := 'nonconformanceNumber';
            c_xml_elm_vn    CONSTANT VARCHAR2(30) := 'verifyNonconformanceNumber';
            c_xml_elm_dn    CONSTANT VARCHAR2(30) := 'dispositionNumber';
            c_xml_elm_ns    CONSTANT VARCHAR2(30) := 'newStatus';
            c_xml_elm_os    CONSTANT VARCHAR2(30) := 'oldStatus';
            c_xml_elm_d     CONSTANT VARCHAR2(30) := 'disposition';
            c_xml_elm_an    CONSTANT VARCHAR2(30) := 'actionName';
            c_xml_elm_un    CONSTANT VARCHAR2(30) := 'userName';
            c_xml_elm_nt    CONSTANT VARCHAR2(30) := 'note';
            c_xml_elm_rid   CONSTANT VARCHAR2(30) := 'requestId'; 
            c_xml_elm_mon   CONSTANT VARCHAR2(30) := 'moveOrderNumber'; --CHG0047103 
            c_xml_elm_did   CONSTANT VARCHAR2(30) := 'docInstanceId'; --CHG0047103
                        
        BEGIN
            gv_log_program_unit := c_method_name; --store procedure name for logging
            --write_message('program unit: ' || gv_log_program_unit);
        
            CASE p_element_name
            WHEN c_cen_nonconformance_status THEN
                --write_message('Case c_cen_nonconformance_status');
                /* Construct XML message for Quality Action Log Entry */
                l_sql :=
                'SELECT XMLELEMENT (
                          "' || c_xml_elm_ssys ||  '"
                          ,XMLATTRIBUTES (
                             "' || c_xml_elm_an  ||  '" 
                            ,"' || c_xml_elm_nn  ||  '"
                            ,"' || c_xml_elm_occ ||  '"
                            )
                          ,XMLFOREST (
                             "' || c_xml_elm_ns  ||  '"
                            ,"' || c_xml_elm_os  ||  '"
                            ,"' || c_xml_elm_un  ||  '"
                            ,"' || c_xml_elm_nt  ||  '"
                            ,"' || c_xml_elm_rid ||  '"
                          )
                        ) AS result
                  FROM 
                  (
                  SELECT
                     ''' || p_action_name                 || ''' AS "'  || c_xml_elm_an  ||  '"
                    ,''' || p_nonconformance_number       || ''' AS "'  || c_xml_elm_nn  ||  '"
                    ,''' || p_new_status                  || ''' AS "'  || c_xml_elm_ns  ||  '"
                    ,''' || p_old_status                  || ''' AS "'  || c_xml_elm_os  ||  '"
                    ,''' || p_occurrence                  || ''' AS "'  || c_xml_elm_occ ||  '"
                    ,''' || fnd_profile.value('USERNAME') || ''' AS "'  || c_xml_elm_un  ||  '"
                    ,''' || p_note                        || ''' AS "'  || c_xml_elm_nt  ||  '"
                    ,''' || fnd_global.conc_request_id    || ''' AS "'  || c_xml_elm_rid ||  '"
                  FROM dual
                  )
                ';

                --write_message('l_sql: ' || l_sql);

                EXECUTE IMMEDIATE l_sql INTO l_xml;
            
            WHEN c_cen_disposition_status THEN
                --write_message('Case c_cen_disposition_status');
                
                l_sql :=
                'SELECT XMLELEMENT (
                          "' || c_xml_elm_ssys || '"
                          ,XMLATTRIBUTES (
                             "' || c_xml_elm_an  || '"
                            ,"' || c_xml_elm_dn  || '"
                            ,"' || c_xml_elm_occ || '"
                            )
                          ,XMLFOREST (
                             "' || c_xml_elm_nn  || '"
                            ,"' || c_xml_elm_vn  || '"
                            ,"' || c_xml_elm_ns  || '"
                            ,"' || c_xml_elm_os  || '"
                            ,"' || c_xml_elm_d   || '"
                            ,"' || c_xml_elm_un  || '"
                            ,"' || c_xml_elm_nt  || '"
                            ,"' || c_xml_elm_rid || '" 
                            ,"' || c_xml_elm_mon || '" 
                            ,"' || c_xml_elm_did || '" 
                          )
                        ) AS result
                  FROM 
                  (
                  SELECT
                    '''  || p_action_name                 || ''' AS "' || c_xml_elm_an  || '"
                    ,''' || p_disposition_number          || ''' AS "' || c_xml_elm_dn  || '"
                    ,''' || p_nonconformance_number       || ''' AS "' || c_xml_elm_nn  || '"
                    ,''' || p_verify_nc_number            || ''' AS "' || c_xml_elm_vn  || '"
                    ,''' || p_new_status                  || ''' AS "' || c_xml_elm_ns  || '"
                    ,''' || p_old_status                  || ''' AS "' || c_xml_elm_os  || '"
                    ,''' || p_disposition                 || ''' AS "' || c_xml_elm_d   || '"
                    ,''' || p_occurrence                  || ''' AS "' || c_xml_elm_occ || '"
                    ,''' || fnd_profile.value('USERNAME') || ''' AS "' || c_xml_elm_un  || '" 
                    ,''' || p_note                        || ''' AS "' || c_xml_elm_nt  || '"
                    ,''' || fnd_global.conc_request_id    || ''' AS "' || c_xml_elm_rid || '"                 
                    ,''' || p_move_order_number           || ''' AS "' || c_xml_elm_mon || '" 
                    ,''' || p_doc_instance_id             || ''' AS "' || c_xml_elm_did || '"
                 FROM dual
                  )
                ';

                --write_message('l_sql: ' || l_sql);

                EXECUTE IMMEDIATE l_sql INTO l_xml;

            ELSE
                l_action_log_message := NULL;
            END CASE;
            
            l_action_log_message := l_xml.getStringVal();
            
            --write_message('l_action_log_message: ' || l_action_log_message);
            
        p_message := l_action_log_message;
        
    /* Exception handling */
    EXCEPTION
        WHEN OTHERS THEN
            p_message := NULL;
            write_message('Exception in ' || c_method_name || ': ' || SQLERRM );
    END build_action_log_message;

    ----------------------------------------------------------------------------------------------------
    --  Name:               result_element_value
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      16-Oct-2019
    --  Purpose:            Get the value of an arbitrary result element (column) value.
    --                               
    --  Description: This procedure will return the value of a single column in qa_results.
    --     The design intent is to provide a high-performing way of getting a single value
    --     without the overhead of using named result views, as is the case with some other
    --     functions in this package that are designed to return multiple fields and rows
    --     for reporting purposes.  This procedure (via a wrapper function to simplify the
    --     arguments) can be called via SQL in Quality Actions, by other modules within
    --     Oracle EBS, or even external applications for interfaces.
    --
    --     There is a slight bit of complexity in determining the plan_id based on the particular
    --     set of parameters values provided to this procedure during a call. This is to simplify code in the calling functions
    --     and encapsulate the complexity within this procedure.  Future optimization/simplification
    --     should focus within this procedure.
    --
    --  Care needs to be taken in ensuring that data conversions are done properly.  Also, some elements
    --    store IDs for foreign tables (such as Item) so care must be taken to
    --    update the "id" value.  There is NOT any validation done on the new value!
    --
    --  Inputs:
    --    p_
    --
    --  Outputs:
    --    p_:
    -- 
    --  To Do:
    --  -Build functionality based on p_return_foreign_tbl_val_flag (examine oracle code for generating result views to see how to do this)
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   16-Oct-2019   Hubert, Eric    CHG0042815: initial build
    --  1.1   01-Apr-2020   Hubert, Eric    CHG0047103: added ability to infer plan_id when p_key_element_name is a "sequence" column
    ----------------------------------------------------------------------------------------------------
    PROCEDURE result_element_value(
         p_plan_name                    IN VARCHAR2 --Collection Plan Name 
        , p_value_element_name          IN VARCHAR2 --Collection Element Name for which the value is requested. (This is not the name of the column in qa_results.)  This should be NULL if p_value_column_name is specified.
        , p_value_column_name           IN VARCHAR2 --Column name in qa_results for which the value is requested. (This is not the name of the collection element.)  This should be NULL if p_value_element_name is specified.
        , p_key_element_name            IN VARCHAR2 --Collection Element Name by which the result records should be filtered.  (This is not the name of the column in qa_results.)  This should be NULL if p_key_column_name is specified.
        , p_key_column_name             IN VARCHAR2 --Column name in qa_results by which the result record should be filtered.  (This is not the name of the collection element.) This should be NULL if p_key_element_name is specified.
        , p_key_value                   IN VARCHAR2 --Value for Key Type for which the result record should be filtered.
        , p_return_foreign_tbl_val_flag IN VARCHAR2 DEFAULT c_no --For seeded elements that store an "ID" value in qa_results column, indicate if the ID value should be returned ('N') or get the value from the foreign table ('Y').
        , p_err_code                    OUT NUMBER
        , p_return_value                OUT VARCHAR2
    )
    IS
        c_method_name CONSTANT VARCHAR(30) := 'result_element_value';
        
        /* Local Variables */
        l_plan_id           NUMBER;
        l_value_element_id  NUMBER;
        l_key_element_id    NUMBER;
        l_sql               VARCHAR2(500); --Dynamic SQL
        l_value_column_name all_tab_columns.column_name%TYPE; --Column name in qa_results
        l_key_column_name   all_tab_columns.column_name%TYPE; --Column name in qa_results
        l_return_value      qa_results.comment1%TYPE; --Element value (sized to largest column in qa_results)

    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        --write_message('program unit: ' || gv_log_program_unit);

        --write_message('p_plan_name: ' || p_plan_name);
        --write_message('p_value_element_name: ' || p_value_element_name);
        --write_message('p_value_column_name: ' || p_value_column_name);
        --write_message('p_key_element_name: ' || p_key_element_name);
        --write_message('p_key_column_name: ' || p_key_column_name);
        --write_message('p_key_value: ' || p_key_value);

        /* Different situations require different steps to determine the plan_id, which is ultimately needed for a SQL statement later in this procedure. */
        CASE
        /* Occurrence was provided but not the p_plan_name, get the plan_id from the occurrence. */
        WHEN p_key_column_name = c_occurrence_column AND p_plan_name IS NULL THEN
            SELECT plan_id INTO l_plan_id FROM qa_results WHERE occurrence = p_key_value;
        
        /* Neither the Occurrence or the Plan Name were provided, but the key column is one of the sequence columns used for the nonconformance or receiving inspection solution. */
        WHEN p_key_column_name IN (
                c_key_seq_rcv_inspection_plan
                ,c_key_seq_nonconformance_plan
                ,c_key_seq_verify_nc_plan
                ,c_key_seq_disposition_plan)
             AND p_plan_name IS NULL THEN

            l_sql := Q'[SELECT plan_id FROM qa_results WHERE ]' || p_key_column_name || Q'[ = ']' || p_key_value || Q'[']';

            --write_message('l_sql: ' || l_sql);

            EXECUTE IMMEDIATE l_sql INTO l_plan_id;

        /* Neither the Occurrence or the Plan Name were provided, but the key element is one of the sequence columns used for the nonconformance or receiving inspection solution. (CHG0047103) */
        WHEN p_key_element_name IN (
                c_sequence_column_r
                ,c_sequence_column_n
                ,c_sequence_column_v
                ,c_sequence_column_d)
             AND p_plan_name IS NULL THEN
            
            /* Determine key column name corresponding to the key element name. */
            CASE p_key_element_name
            WHEN c_sequence_column_r THEN
                l_key_column_name := c_key_seq_rcv_inspection_plan;
            WHEN c_sequence_column_n THEN
                l_key_column_name := c_key_seq_nonconformance_plan;
            WHEN c_sequence_column_v THEN
                l_key_column_name := c_key_seq_verify_nc_plan;
            WHEN c_sequence_column_d THEN
                l_key_column_name := c_key_seq_disposition_plan;
            END CASE;
                
            --l_sql := Q'[SELECT plan_id FROM qa_results WHERE ]' || l_key_column_name || Q'[ = ']' || p_key_value || Q'[']';

            write_message('l_sql: ' || l_sql);

            EXECUTE IMMEDIATE l_sql INTO l_plan_id;  

        ELSE
            
            l_plan_id := qa_core_pkg.get_plan_id(p_plan_name);
        END CASE;
        
        /* Determine if the value column in qa_results was explicitly provided or if we need to get it from the element name. */
        CASE WHEN p_value_element_name IS NOT NULL THEN
            --write_message(' *1' );
            /* Get column name for element name*/
            l_value_element_id := qa_core_pkg.get_element_id(p_value_element_name);
            l_value_column_name := qa_core_pkg.get_result_column_name(l_value_element_id, l_plan_id);
            --write_message('l_value_element_id: ' || l_value_element_id );
            --write_message('l_value_column_name: ' || l_value_column_name );
        WHEN p_value_column_name IS NOT NULL THEN
            --write_message(' *2' );
            l_value_column_name := p_value_column_name;
        ELSE
            --write_message(' *3' );
            l_value_column_name := NULL;
        END CASE;

        /* Determine if the key column in qa_results was explicitly provided or if we need to get it from the element name. */
        CASE WHEN p_key_element_name IS NOT NULL THEN
            /* Get column name for element name*/
            l_key_element_id := qa_core_pkg.get_element_id(p_key_element_name);
            l_key_column_name := qa_core_pkg.get_result_column_name(l_key_element_id, l_plan_id);
        WHEN p_key_column_name IS NOT NULL THEN
            l_key_column_name := p_key_column_name;
        ELSE
            l_key_column_name := NULL;
        END CASE;

        /* Select the value for the specified column in a specified result record. */
        l_sql := 'SELECT ' || l_value_column_name ||
            ' FROM qa_results WHERE '
            || l_key_column_name || ' = ''' || p_key_value
            || ''' AND plan_id = ' || l_plan_id;
            
        --write_message('l_sql: ' || l_sql);

        EXECUTE IMMEDIATE l_sql INTO l_return_value;
        
        p_return_value := l_return_value;
        p_err_code     := c_success; 

    /* Exception handling */
    EXCEPTION 
        WHEN OTHERS THEN
            p_return_value := NULL;
            p_err_code     := c_fail;
            write_message('Exception in ' || c_method_name || ': ' || SQLERRM );
    END result_element_value;

    ----------------------------------------------------------------------------------------------------
    --  Name:               create_quality_action_log_row
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      16-Oct-2019 
    --  Purpose:            Insert a row into the Quality Action Log.
    --                               
    --  Description: This function is modeled after QLTDACTB.INSERT_ACTION_LOG.
    --
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   16-Oct-2019   Hubert, Eric    CHG0042815
    ----------------------------------------------------------------------------------------------------
    PROCEDURE create_quality_action_log_row(
        p_plan_id       IN NUMBER,
        p_collection_id IN NUMBER,
        p_creation_date IN DATE,
        p_char_id       IN NUMBER,
        p_operator      IN NUMBER,
        p_low_value     IN VARCHAR2,
        p_high_value    IN VARCHAR2,
        p_message       IN VARCHAR2,
        p_result        IN VARCHAR2,
        p_concurrent    IN NUMBER, --1: is being called as part of a concurrent request
        p_log_number    OUT NUMBER
        ) IS

        c_method_name CONSTANT VARCHAR(30) := 'create_quality_action_log_row';

        l_user_id                   NUMBER;
        l_request_id                NUMBER;
        l_program_application_id    NUMBER;
        l_program_id                NUMBER;
        l_last_update_login         NUMBER;
        l_log_number                NUMBER;

    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        --write_message('program unit: ' || gv_log_program_unit);
        
        l_user_id := NVL(FND_PROFILE.VALUE('USER_ID'), 0);
        l_log_number := qa_action_log_s.NEXTVAL; --Get next Log Number

        IF p_concurrent = 1 THEN -- Online

            l_request_id := fnd_global.conc_request_id;
            l_program_application_id := fnd_global.prog_appl_id;
            l_program_id := fnd_global.conc_program_id;
            l_last_update_login := fnd_global.conc_login_id;

            --write_message('DEBUG l_request_id: ' || l_request_id);
            --write_message('DEBUG l_program_application_id: ' || l_program_application_id);
            --write_message('DEBUG l_program_id: ' || l_program_id);
            --write_message('DEBUG l_last_update_login: ' || l_last_update_login);
            INSERT INTO qa_action_log (
                log_id,
                last_update_date,
                last_updated_by,
                creation_date,
                created_by,
                last_update_login,
                request_id,
                program_application_id,
                program_id,
                program_update_date,
                plan_id,
                collection_id,
                transaction_date,
                char_id,
                operator,
                low_value,
                high_value,
                action_log_message,
                result_value)
            VALUES (
                l_log_number,
                SYSDATE,
                l_user_id,
                SYSDATE,
                l_user_id,
                l_last_update_login,
                l_request_id,
                l_program_application_id,
                l_program_id,
                SYSDATE,
                p_plan_id,
                p_collection_id,
                p_creation_date,
                p_char_id,
                p_operator,
                p_low_value,
                p_high_value,
                p_message,
                p_result);

        ELSE

            INSERT INTO qa_action_log (
                log_id,
                last_update_date,
                last_updated_by,
                creation_date,
                created_by,
                plan_id,
                collection_id,
                transaction_date,
                char_id,
                operator,
                low_value,
                high_value,
                action_log_message,
                result_value)
            VALUES (
                l_log_number,
                SYSDATE,
                l_user_id,
                SYSDATE,
                l_user_id,
                p_plan_id,
                p_collection_id,
                p_creation_date,
                p_char_id,
                p_operator,
                p_low_value,
                p_high_value,
                p_message,
                p_result);
        END IF;

        COMMIT;

        p_log_number := l_log_number;
        
    /* Exception handling */
    EXCEPTION
        WHEN OTHERS THEN
            p_log_number := NULL;
            write_message('Exception in ' || c_method_name || ': ' || SQLERRM );
    END create_quality_action_log_row;

    ----------------------------------------------------------------------------------------------------
    --  Name:               log_manual_status_update
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      16-Oct-2019
    --  Purpose:            Wrapper function to insert a row into the Quality 
    --                      Action Log from a Quality Action to log when 
    --                      a user manually changes a Diposition or Nonconformance
    --                      Status from the Update or Enter Quality Results
    --                      form.  
    --
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   16-Oct-2019   Hubert, Eric    CHG0042815
    --  1.1   01-Apr-2020   Hubert, Eric    CHG0047103: added p_old_status and p_source_ref as optional
    ----------------------------------------------------------------------------------------------------
    PROCEDURE log_manual_status_update(
        p_new_status       IN VARCHAR2 --New Nonconformance or Disposition Status
        ,p_old_status      IN VARCHAR2 DEFAULT NULL --Helpful to see this in the log if known so added it as an optional parameter. (CHG0047103)
        ,p_sequence_number IN VARCHAR2 --Nonconformance or Disposition Number
        ,p_source_ref      IN VARCHAR2 DEFAULT NULL --Optional field to identify the source of the calling procedure (forms personalization, concurrent request, ad hoc script, etc.) (CHG0047103)

    ) AS
        c_method_name CONSTANT VARCHAR(30) := 'log_manual_status_update';
    
        /* Local variables*/ 
        l_occurrence            NUMBER;
        l_qa_results_row        qa_results%ROWTYPE;
        l_plan_type_code        fnd_lookup_values.lookup_code%TYPE;--Collection Plan Type
        l_action_log_char_id    qa_plan_chars.char_id%TYPE; --char_id for Quality Action Log
        l_action_log_message    qa_action_log.action_log_message%TYPE; --Message for Quality Action Log
        l_log_number            NUMBER; --Quality Action Log number
        l_disposition           qa_results.character1%TYPE;
        l_action_name           qa_results.character1%TYPE;
        l_status_element        qa_chars.name%TYPE;--xx_nonconformance_status/xx_disposition_status
        l_sequence_column_name  all_tab_columns.column_name%TYPE;--Column name in qa_results for the sequence of interest
        l_nonconformance_number qa_results.character5%TYPE;  --Nonconformance Number
        l_verify_nc_number      qa_results.character6%TYPE;  --Verify Nonconformance Number
        l_disposition_number    qa_results.character7%TYPE;  --Disposition Number
        l_return_value          qa_results.comment1%TYPE; --Element value (to be safe, this is sized to largest column in qa_results which is a comment column)
        l_err_code              NUMBER;
        
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('program unit: ' || gv_log_program_unit);
        
        /* Get some values based upon whether we're logging a Nonconformance or Disposition Status update. */
        CASE SUBSTR(p_sequence_number, 1, 1)
        WHEN 'N' THEN --Look for the letter "N" which is the prefix of th enonconformance number.
            l_status_element := c_cen_nonconformance_status;
            l_sequence_column_name := c_key_seq_nonconformance_plan; --Nonconformance Number
        WHEN 'D' THEN --Look for the letter "D" which is the prefix of th enonconformance number.
            l_status_element := c_cen_disposition_status;
            l_sequence_column_name := c_key_seq_disposition_plan; --Disposition Number
        END CASE;

        /* Get the occurrence */
        result_element_value(
            p_plan_name                     => NULL
            , p_value_element_name          => NULL
            , p_value_column_name           => c_occurrence_column
            , p_key_element_name            => NULL
            , p_key_column_name             => l_sequence_column_name
            , p_key_value                   => p_sequence_number
            , p_return_foreign_tbl_val_flag => c_no
            , p_err_code                    => l_err_code
            , p_return_value                => l_occurrence
            );  

        /* Make sure that an occurrence was found. */
        IF l_err_code = c_success THEN
            /* Get entire qa_results record for the occurrence. */
            l_qa_results_row := qa_result_row_via_occurrence(p_occurrence => l_occurrence);

            /* Get plan type */
            l_plan_type_code := plan_type(p_plan_id => l_qa_results_row.plan_id, p_occurrence => NULL); --CHG0049611
            
            CASE l_plan_type_code
            WHEN c_plan_type_code_n THEN --Nonconformance
                
                l_nonconformance_number := l_qa_results_row.sequence5;--Nonconformance Number (https://asktom.oracle.com/pls/apex/f?p=100:11:0::::P11_QUESTION_ID:2170326695312
                l_action_name := c_n_action_uns;
            WHEN c_plan_type_code_d THEN --Disposition
                
                l_disposition_number := l_qa_results_row.sequence7;--Disposition Number
                l_action_name := c_d_action_uds;
                
                /* Get the Disposition from the result record. */
                result_element_value(
                    p_plan_name                     => qa_core_pkg.get_plan_name(l_qa_results_row.plan_id)
                    , p_value_element_name          => c_cen_disposition
                    , p_value_column_name           => NULL
                    , p_key_element_name            => c_sequence_column_d
                    , p_key_column_name             => NULL
                    , p_key_value                   => l_disposition_number
                    , p_return_foreign_tbl_val_flag => c_no
                    , p_err_code                    => l_err_code
                    , p_return_value                => l_return_value
                    );

                IF l_err_code = c_success THEN
                    l_disposition := l_return_value;
                ELSE
                    NULL;
                END IF;

            ELSE
                NULL;
            END CASE;
         
            /* Construct message for Quality Action Log Entry */
            build_action_log_message(
                p_element_name              => l_status_element
                ,p_action_name              => l_action_name
                ,p_nonconformance_number    => l_nonconformance_number
                ,p_verify_nc_number         => l_verify_nc_number
                ,p_disposition_number       => l_disposition_number
                ,p_new_status               => p_new_status  
                ,p_old_status               => p_old_status --CHG0047103
                ,p_disposition              => l_disposition
                ,p_occurrence               => l_occurrence
                ,p_move_order_number        => NULL
                ,p_doc_instance_id          => NULL
                ,p_note                     => NULL
                ,p_message                  => l_action_log_message    
            );  

            --write_message('l_status_element: ' || l_status_element);

            /* Get the char_id for the disposition status element. */
            l_action_log_char_id := qa_core_pkg.get_element_id(l_status_element);

            /* Write to the Quality Action Log BASE MESSAGE ON TYPE OF UPDATE (p_concurrent)*/
            create_quality_action_log_row(
                p_plan_id       => l_qa_results_row.plan_id,
                p_collection_id => l_qa_results_row.collection_id,
                p_creation_date => SYSDATE,
                p_char_id       => l_action_log_char_id,
                /* We use operator id 7 which is "is entered" only because p_operator can't be null and if set to 0 it won't be visible in Action log. */
                p_operator      => 7, --operator id
                p_low_value     => NULL,
                p_high_value    => NULL,
                p_message       => l_action_log_message,
                p_result        => NULL,
                p_concurrent    => 1, --"online" (is being called as part of a concurrent request).  As of the initial release, this is always called in the context of a concurrent request so we hardcod this to 1.
                p_log_number    => l_log_number);
                
                write_message('l_log_number: ' || l_log_number );
    
        ELSE
            /* Placeholder for actions to take if occurrence could not be found. */
            NULL;
        END IF;

    /* Exception handling */
    EXCEPTION
        WHEN OTHERS THEN
            write_message('Exception in ' || c_method_name || ': ' || SQLERRM );
    END log_manual_status_update;

    ----------------------------------------------------------------------------------------------------
    --  Name:               wf_scrap_approver_username
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      24-Oct-2019
    --  Purpose:            Get the user name for an approver of the scrap approval workflow
    --  Parameters :
    --       Name             Type    Purpose
    --       --------         ----    -----------
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date            Name            Desc
    --  1.0   24-Oct-2019     Hubert, Eric    CHG0046276: initial build
    ----------------------------------------------------------------------------------------------------

    PROCEDURE wf_scrap_approver_username(
        p_doc_instance_id   IN  NUMBER --Workflow instance
        ,p_level            IN  NUMBER --Level in scrap approval hierarchy
        ,p_approver         OUT VARCHAR2 --username
        ,p_err_code         OUT NUMBER
        ,p_err_msg          OUT VARCHAR2
        ) 
    IS
        c_method_name CONSTANT VARCHAR(30) := 'wf_scrap_approver_username';
    
        /* Local variables */
        l_organization_code mtl_parameters.organization_code%TYPE; --Inventory Org Code
        l_username          fnd_user.user_name%TYPE;
        l_wdi_rec           xxobjt_wf_doc_instance%ROWTYPE;
        l_scrap_value       NUMBER;
        
        /* Exceptions */
        EXCEPTION_NULL_APPROVER     EXCEPTION;  
    
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        --write_message('program unit: ' || gv_log_program_unit);
    
        /* Get the the workflow instance record. */
        l_wdi_rec := wf_get_doc_instance_row(p_doc_instance_id => p_doc_instance_id);
        
        --write_message('l_wdi_rec.attribute1: ' || l_wdi_rec.attribute1); --ORG ID
        --write_message('l_wdi_rec.attribute2: ' || l_wdi_rec.attribute2); --plan id
        --write_message('l_wdi_rec.attribute3: ' || l_wdi_rec.attribute3); --collection id
        --write_message('l_wdi_rec.attribute4: ' || l_wdi_rec.attribute4); --disposition number
        --write_message('p_level: ' || p_level); --level
          
        l_organization_code := xxinv_utils_pkg.get_org_code(l_wdi_rec.attribute1);
        --write_message('l_organization_code: ' || l_organization_code);
        
        l_scrap_value := NVL(l_wdi_rec.attribute5, 0);
        
        /* Use a SQL statement to get the relevant approver for the scrap value and current approval level.
           Via NO_DATA_FOUND exception, return -2 if an approver is not required for the specified level. */
        SELECT xx_username
        INTO l_username
        FROM (
            SELECT xx_approval_amount_minimum from_amount,
                   ROW_NUMBER() OVER (ORDER BY xx_approval_amount_minimum) AS approval_level,
                   xx_username
            FROM   q_disposition_approval_limit_v
            WHERE  xx_organization_code =  l_organization_code
            AND    xx_disposition = c_disp_s --Scrap
        )
        WHERE l_scrap_value >= from_amount
        AND approval_level= p_level;
              
        --write_message('l_username: ' || l_username);
        
        IF l_username IS NOT NULL THEN
            p_approver := l_username;
            p_err_code := c_success;
            p_err_msg  := NULL;
        ELSE       
            RAISE EXCEPTION_NULL_APPROVER;
        END IF;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            --write_message('Approval is not required for this level.');
            p_approver := NULL;
            p_err_code :=  '-2';  --Special value that signifies to XX Doc Approval that an approver is not required for the specified dynamic approver level
            p_err_msg  := ('Approval is not required for this level.');
        WHEN EXCEPTION_NULL_APPROVER THEN
            write_message('The approver for hierachy level ' || p_level || ' is null.');
            p_approver := NULL;
            p_err_code := c_fail;
            p_err_msg  := ('The approver for hierachy level ' || p_level || ' is null.');
        WHEN OTHERS THEN
            p_approver := NULL;
            p_err_code := c_fail;
            p_err_msg  := ('Exception in ' || c_method_name || ': ' || SQLERRM );
            write_message('Exception in ' || c_method_name || ': ' || SQLERRM );
    END wf_scrap_approver_username;

    ----------------------------------------------------------------------------------------------------
    --  Name:               override_disposition_status
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      01-Apr-2020
    --  Purpose:            Take action on changes to the Disposition Status element.
    --                               
    --  Description: replaces disp_status_updt_event_handler
    --
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   01-Apr-2020   Hubert, Eric    CHG0047103: -Cancel wf and mo upon cancelling disposition
    --                                                  -Moved triggering of workflow creation from form-based events to status-based criteria 
    --                                                   in the notification program.  Form-based triggering has intermittent issues.  Bursting 
    --                                                   now handles the creation of disposition-specific HTML that is included in the apprvoal 
    --                                                   request notifications.
    --                                                  -Added Tools menu items (via forms personalization) for Cancelling or Closing a disposition.
    -- Future enhancements:
    --      -Eliminate the use of multiple result_element_value and get_disposition_status calls with a single get_nc_rpt_tab call.
    --      -Don't allow an update if the Nonconformance Status (as opposed to the Disposition Status) is Closed or Cancelled. 
    ----------------------------------------------------------------------------------------------------
    PROCEDURE override_disposition_status(
        p_disposition_number IN qa_results.sequence7%TYPE
        ,p_occurrence        IN qa_results.occurrence%TYPE
        ,p_new_status        IN VARCHAR2
        ,p_source_ref        IN VARCHAR2 DEFAULT NULL --Optional field to identify the source of the calling procedure (forms personalization, concurrent request, ad hoc script, etc.)
        ,p_err_code          OUT NUMBER
        ,p_err_msg           OUT VARCHAR2
    )
    IS
        c_method_name CONSTANT VARCHAR(30) := 'override_disposition_status';
        
        /* local variables */
        l_organization_id           NUMBER;
        l_plan_id                   qa_plans.plan_id%TYPE;
        l_plan_name                 qa_plans.name%TYPE;
        l_disposition               qa_results.character1%TYPE;
        l_disposition_number        qa_results.sequence7%TYPE;
        l_occurrence                qa_results.occurrence%TYPE;
        l_return_value              qa_results.character1%TYPE;
        l_err_code                  NUMBER := c_success;
        l_err_code_mo               NUMBER := c_success;
        l_err_code_wf               NUMBER := c_success;
        l_err_msg                   VARCHAR2(1000);
        l_err_msg_wf                VARCHAR2(1000); --Retains the message from cancelling workflows
        l_err_msg_mo                VARCHAR2(1000); --Retains the message from cancelling move orders
        l_old_disposition_status    qa_results.character1%TYPE;
        l_abort_workflow_flag       BOOLEAN := FALSE; 
        l_cancel_move_order_flag    BOOLEAN := FALSE; 
        l_wf_msg                    qa_results.character1%TYPE; --for workflow message updating
               
        /* Exceptions */
        NO_DISPOSITION_IDENTIFIER     EXCEPTION;
        DISPOSITION_NOT_FOUND         EXCEPTION;
        NULL_DISPOSITION              EXCEPTION;
        UPDATE_NOT_ALLOWED            EXCEPTION;
        NO_UPDATE_REQUIRED            EXCEPTION;
        CANEL_WORKFLOW_ERROR          EXCEPTION;
        CANCEL_MOVE_ORDER_ERROR       EXCEPTION;
        UPDATE_DISP_STATUS_ERROR      EXCEPTION;
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('program unit: ' || gv_log_program_unit);
       
        /* We need one of these two identifiers */
        IF COALESCE (p_disposition_number, TO_CHAR(p_occurrence)) IS NULL THEN
            RAISE NO_DISPOSITION_IDENTIFIER;
        END IF;
        
        /* Check that the new disposition status is a valid value. */
        --we're not going to implement a check at this time since there is no free-text entry of a status.  It is all programatically-driven.

        /* Get the plan id, occurrence, and disposition number for the disposition number or occurrence. */
        BEGIN
            SELECT organization_id, plan_id, occurrence, sequence7
            INTO l_organization_id, l_plan_id, l_occurrence, l_disposition_number
            FROM qa_results
            WHERE 
                /* Find the disposition record based on either the disposition number or the occurrence. */
                sequence7 = p_disposition_number OR occurrence = p_occurrence 
            ;
        EXCEPTION
            WHEN OTHERS THEN
            write_message('SQLERRM: ' || SQLERRM);
                RAISE DISPOSITION_NOT_FOUND;
        END;

        l_plan_name := qa_core_pkg.get_plan_name(l_plan_id);

        /* Get the current disposition status */
        l_old_disposition_status := xxqa_nonconformance_util_pkg.key_sequence_result_value (
            p_sequence_number  => l_disposition_number
            ,p_element_name    => c_cen_disposition_status); --CHG0047103
       
        write_message('p_new_status: ' || p_new_status);
        write_message('l_old_disposition_status: ' || l_old_disposition_status);
 
        /* Don't allow an update is the status isn't going to change. */
        IF l_old_disposition_status = p_new_status THEN
            RAISE NO_UPDATE_REQUIRED;
        END IF;

        /* When an update to APPROVED is requested via a forms personalization,
           don't allow it unless the currect status is MOVE_ORDER_EXCEPTION.  We're just giving
           the user a chance to fix some fields on the disposition and then let them try
           to progress the status after that (such as for material handler notifications). */
        IF  p_source_ref = c_odssr_fp --is forms personalization
            AND p_new_status = c_d_status_app --new status is APPROVED
            AND l_old_disposition_status <> c_d_status_emo --old status is not MOVE_ORDER_EXCEPTION
            THEN
                RAISE UPDATE_NOT_ALLOWED;
        END IF;

        /* Get the Disposition from the result record. */
        result_element_value(
            p_plan_name                     => l_plan_name
            , p_value_element_name          => c_cen_disposition
            , p_value_column_name           => NULL
            , p_key_element_name            => c_sequence_column_d
            , p_key_column_name             => NULL
            , p_key_value                   => l_disposition_number
            , p_return_foreign_tbl_val_flag => c_no
            , p_err_code                    => l_err_code
            , p_return_value                => l_return_value
            );

        --write_message('l_err_code: ' || l_err_code);

        /* Raise an exception if the disposition status is null. */
        IF l_err_code = c_success AND l_return_value IS NOT NULL THEN
            l_disposition := l_return_value;
        ELSE
            RAISE NULL_DISPOSITION;
        END IF;

        write_message('l_disposition: ' || l_disposition);

        /* Take action based on the type of disposition*/
        CASE l_disposition
        WHEN c_disp_s THEN
            
            /* Flag to cancel workflows */
            l_abort_workflow_flag := TRUE;

            /* Flag to cancel move orders */
            l_cancel_move_order_flag := TRUE;
        
        WHEN c_disp_uai THEN --CHG0047103

            /* Flag to cancel move orders */
            l_cancel_move_order_flag := TRUE;

        ELSE --Place holder for future rules for other disposition types

            write_message('no actions being taken');
            
        END CASE;

        --write_message('l_abort_workflow_flag: ' || l_abort_workflow_flag);

        /* Check if workflows need to be cancelled. */
        IF l_abort_workflow_flag THEN
                /* Cancel the workflow. */
                --write_message('before wf_abort_disposition_approvals');
                
                /* Abort existing doc approval workflow instances, if any, per the workflow management option. (CHG0047103)*/
                wf_abort_disposition_approvals(
                    p_disposition_number => l_disposition_number
                    ,p_wf_mgmt_option    => c_wmo_cancel_all
                    ,p_doc_code          => c_wf_doc_code_scrap --Currently, this is the only type of Disposition approval workflow that we have
                    ,p_err_code          => l_err_code_wf
                    ,p_err_msg           => l_err_msg_wf
                );
                
                --write_message('after wf_abort_disposition_approvals');
                --write_message('l_err_code_wf: ' || l_err_code_wf);
                --write_message('l_err_msg_wf: ' || l_err_msg_wf);

                IF l_err_code_wf = c_fail THEN                
                    /* Log error */
                    write_message('error in wf_abort_disposition_approvals');
                    RAISE CANEL_WORKFLOW_ERROR;
                END IF;
        END IF;

        --write_message('l_cancel_move_order_flag: ' || l_cancel_move_order_flag);

        /* Check if move orders need to be cancelled. */
        IF l_cancel_move_order_flag THEN
        
            /* Cancel all move orders that are associated with the disposition. */
            write_message('Before mo_cancel_disp_move_orders');
            mo_cancel_disp_move_orders(
                p_disposition_number   => l_disposition_number
                ,p_org_id              => l_organization_id
                ,p_err_code            => l_err_code_mo
                ,p_err_msg             => l_err_msg_mo
            );
            
            --write_message('l_err_code (mo_cancel_disp_move_orders): ' || l_err_code_mo);
            --write_message('l_err_msg_mo (mo_cancel_disp_move_orders): ' || l_err_msg_mo);
            
            IF l_err_code_mo = c_fail THEN                
                /* Log error */
                write_message('error in mo_cancel_disp_move_orders');
                RAISE CANCEL_MOVE_ORDER_ERROR;
            ELSE
                NULL;
                /* Clear the move order number value directly. */
                update_result_value(
                    p_plan_id        => l_plan_id
                    ,p_occurrence    => l_occurrence
                    ,p_char_name     => c_cen_move_order_number
                    ,p_new_value     => NULL
                    ,p_err_code      => l_err_code
                    ,p_err_msg       => l_err_msg
                    );
            END IF;
        END IF;

        /* Update the disposition status directly. */
        update_result_value(
            p_plan_id        => l_plan_id --added CHG0046276
            ,p_occurrence    => l_occurrence
            ,p_char_name     => c_cen_disposition_status
            ,p_new_value     => p_new_status
            ,p_err_code      => l_err_code
            ,p_err_msg       => l_err_msg --CHG0047103
            );

        /* Raise an exception if the disposition status is null. */
        IF l_err_code = c_success THEN

            /* Update the workflow message. */        
            l_wf_msg := 'Status overridden to ' || p_new_status || ' by ' || fnd_profile.value('USERNAME') || ' on ' || local_datetime;
        
            wf_update_disposition_msg (
                p_plan_id        => l_plan_id
                ,p_occurrence    => l_occurrence
                ,p_new_value     => l_wf_msg
                ,p_err_code      => l_err_code);
        
            /* Log the status change (create a record in the quality action log).*/
            log_manual_status_update(
                p_new_status       => p_new_status
                ,p_old_status      => l_old_disposition_status
                ,p_sequence_number => l_disposition_number); 
        ELSE
            RAISE UPDATE_DISP_STATUS_ERROR;
        END IF;

        write_message('l_err_msg_wf: ' || l_err_msg_wf);
        write_message('l_err_msg_mo: ' || l_err_msg_mo);

        p_err_code := c_success;
        p_err_msg  := 'Disposition Status has been updated to ' || p_new_status || ' for ' || l_disposition_number || '.'
                      || CHR(10) || COALESCE(l_err_msg_wf, l_err_msg_mo, 'No workflows or move orders were cancelled.')
                      || CHR(10) || 'Please requery the block to see the change to the status.';
          
    EXCEPTION
        WHEN NO_DISPOSITION_IDENTIFIER THEN
            p_err_code := c_fail;
            p_err_msg  := 'Null Disposition Number and Occurrence.';
        WHEN DISPOSITION_NOT_FOUND THEN
            p_err_code := c_fail;
            p_err_msg  := 'Disposition Number ' || l_disposition_number || ' was not found.';
        WHEN NO_UPDATE_REQUIRED THEN
            p_err_code := c_success;
            p_err_msg  := 'Disposition Status is already status ' || p_new_status || ' for ' || l_disposition_number || '.';
        WHEN NULL_DISPOSITION THEN
            p_err_code := c_fail;
            p_err_msg  := 'Null Disposition for ' || l_disposition_number  || '.';
        WHEN UPDATE_NOT_ALLOWED THEN
            p_err_code := c_fail;
            p_err_msg  := 'Resetting the Disposition Status (to APPROVED) is only allowed when the current status is MOVE_ORDER_EXCEPTION.';
        WHEN CANEL_WORKFLOW_ERROR THEN
            p_err_code := c_fail;
            p_err_msg  := 'Error cancelling workflow for ' || l_disposition_number || ': ' || l_err_msg_wf;
        WHEN CANCEL_MOVE_ORDER_ERROR THEN
            p_err_code := c_fail;
            p_err_msg  := 'Error cancelling move order for ' || l_disposition_number || ': ' || l_err_msg_mo;
        WHEN UPDATE_DISP_STATUS_ERROR THEN
            p_err_code := c_fail;
            p_err_msg  := 'Error occurred updating Disposition Status for ' || l_disposition_number || '. ' || l_err_msg;
        WHEN OTHERS THEN
            p_err_code := c_fail;
            p_err_msg  := 'Exception in ' || c_method_name || ' for Disposition Number ' || l_disposition_number  || ': ' || SQLERRM ;
            write_message(p_err_msg);
    END override_disposition_status;

    ----------------------------------------------------------------------------------------------------
    --  Name:               override_disp_status_wrapper
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      01-Apr-2020
    --  Purpose:            Take action on changes to the Disposition Status element.
    --                               
    --  Description:        Wrapper function that can be used in a forms personalization
    --
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   01-Apr-2020   Hubert, Eric    CHG0047103: initial release
    ----------------------------------------------------------------------------------------------------
    FUNCTION override_disp_status_wrapper(
        p_disposition_number IN qa_results.sequence7%TYPE
        ,p_occurrence        IN qa_results.occurrence%TYPE
        ,p_new_status        IN VARCHAR2
        ,p_source_ref        IN VARCHAR2 DEFAULT NULL 
        ) RETURN VARCHAR2 IS
        
        c_method_name CONSTANT VARCHAR(30) := 'override_disp_status_wrapper';
        
        l_err_code                  NUMBER;
        l_err_msg                   VARCHAR2(1000);

    BEGIN
        override_disposition_status(
            p_disposition_number => p_disposition_number
            ,p_occurrence        => p_occurrence
            ,p_new_status        => p_new_status
            ,p_source_ref        => p_source_ref
            ,p_err_code          => l_err_code
            ,p_err_msg           => l_err_msg);

        RETURN l_err_msg;

    EXCEPTION
        WHEN OTHERS THEN
            RETURN 'Exception in ' || c_method_name || '.';
    END;
    

    
    ----------------------------------------------------------------------------------------------------
    --  Name:               wf_doc_approval_event_handler
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      24-Oct-2019
    --  Purpose:            Take action on events from XX Doc Approval workflow.
    --                               
    --  Description: 
    --
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   24-Oct-2019   Hubert, Eric    CHG0046276: initial build
    --  1.1   01-Apr-2021   Hubert, Eric    CHG0049611: eliminated immediate status update for Approval/Rejection events
    ----------------------------------------------------------------------------------------------------
    PROCEDURE wf_doc_approval_event_handler(
        p_doc_instance_id   IN  NUMBER,
        p_event_name        IN  VARCHAR2,
        p_err_code          OUT NUMBER,
        p_err_msg           OUT VARCHAR2        
        )
    IS
        c_method_name CONSTANT VARCHAR(30) := 'wf_doc_approval_event_handler';
        
        /* Local variables */
        l_wdi_rec               xxobjt_wf_doc_instance%ROWTYPE;
        l_wdh_rec               xxobjt_wf_doc_history%ROWTYPE;
        l_plan_name             qa_plans.name%TYPE;
        l_occurrence            NUMBER;
        l_note                  qa_results.character1%TYPE;
        l_wf_msg                qa_results.character1%TYPE; --workflow message
        l_disposition           qa_results.character1%TYPE;
        l_action_name           qa_results.character1%TYPE;
        l_action_log_message    qa_action_log.action_log_message%TYPE;
        l_log_number            NUMBER;
        l_disposition_status    qa_results.character1%TYPE;
        l_action_log_required_flag      BOOLEAN := FALSE; --Log a workflow action in the quality action log?
        l_status_update_required_flag   BOOLEAN := FALSE; --The status of a given disposition needs to be updated after rules were evaluated.
        l_update_wf_message_flag        BOOLEAN := FALSE; --The workflow message element needs to be updated after rules were evaluated.
        
        l_err_code        NUMBER := c_success;
        l_err_msg         VARCHAR2(1000);
        
        /* Exceptions */
        UPDATE_WF_MSG_ERROR EXCEPTION;
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('program unit: ' || gv_log_program_unit);
        
        --write_message('p_doc_instance_id: ' || p_doc_instance_id);
        --write_message('p_event_name: ' || p_event_name); 
        
        /* Get the Disposition number from the doc instance. */
        l_wdi_rec := wf_get_doc_instance_row(p_doc_instance_id => p_doc_instance_id);
        --write_message('l_wdi_rec.n_attribute1: ' || l_wdi_rec.n_attribute1); --OCCURRENCE        
        --write_message('l_wdi_rec.attribute1: ' || l_wdi_rec.attribute1); --ORG ID
        --write_message('l_wdi_rec.attribute2: ' || l_wdi_rec.attribute2); --plan id
        --write_message('l_wdi_rec.attribute3: ' || l_wdi_rec.attribute3); --collection id
        --write_message('l_wdi_rec.attribute4: ' || l_wdi_rec.attribute4); --disposition #

        /* Get some information about the disposition */
        l_plan_name  := qa_plans_api.plan_name(TO_NUMBER(l_wdi_rec.attribute2));
        l_occurrence := TO_NUMBER(l_wdi_rec.n_attribute1);

        l_disposition_status := xxqa_nonconformance_util_pkg.key_sequence_result_value (
            p_sequence_number  => l_wdi_rec.attribute4
            ,p_element_name    => c_cen_disposition_status); --CHG0047103
                   
        result_element_value(
            p_plan_name                     => NULL
            , p_value_element_name          => c_cen_disposition
            , p_value_column_name           => NULL
            , p_key_element_name            => NULL
            , p_key_column_name             => c_occurrence_column
            , p_key_value                   => l_occurrence
            , p_return_foreign_tbl_val_flag => c_no
            , p_err_code                    => l_err_code
            , p_return_value                => l_disposition
            );
            
        write_message('before CASE p_event_name'); 
            
        /* Construct the Quality Action Log message based on the event type. */
        CASE p_event_name
        WHEN c_doc_before_approval THEN
            write_message('case = c_doc_before_approval'); 
            l_action_name                   := c_d_action_awi;
            l_action_log_required_flag      := TRUE;
            l_status_update_required_flag   := TRUE;
            l_update_wf_message_flag        := FALSE; --The workflow event fires before the WF history table is updated, so the wf message would be one action behind.  Therefore, we will update it periodically via update_disposition_status.
        WHEN c_doc_after_user_approval THEN
            /* no need to log after each user approval */
            l_action_name                   := NULL;
            l_action_log_required_flag      := FALSE;
            l_status_update_required_flag   := FALSE;
            l_update_wf_message_flag        := FALSE; --The workflow event fires before the WF history table is updated, so the wf message would be one action behind.  Therefore, we will update it periodically via update_disposition_status.
        WHEN c_doc_after_approval THEN
            l_action_name                   := c_d_action_awc;
            l_action_log_required_flag      := TRUE;
            --CHG0049611 l_status_update_required_flag   := TRUE;
            l_status_update_required_flag   := FALSE; --CHG0049611: decoupling status update from approval to improve performance for user when approving with standard notification approval form.  Otherwise, control is not returned to user until disposition status is updated which can take about a minute.
            l_update_wf_message_flag        := FALSE; --The workflow event fires before the WF history table is updated, so the wf message would be one action behind.  Therefore, we will update it periodically via update_disposition_status.
        WHEN c_doc_after_reject THEN
            l_action_name                   := c_d_action_awr;
            l_action_log_required_flag      := TRUE;
            --CHG0049611 l_status_update_required_flag   := TRUE;
            l_status_update_required_flag   := FALSE; --CHG0049611: decoupling status update from rejection to improve performance for user when approving with standard notification approval form.  Otherwise, control is not returned to user until disposition status is updated which can take about a minute.
            l_update_wf_message_flag        := FALSE; --The workflow event fires before the WF history table is updated, so the wf message would be one action behind.  Therefore, we will update it periodically via update_disposition_status.
        ELSE--Does an event fire that we can catch here when the status of Doc Approval wf changes to ERROR?  Ask Yuval.
            l_action_log_required_flag      := TRUE;
            l_status_update_required_flag   := FALSE;
            l_update_wf_message_flag        := FALSE;
        END CASE;
        
        write_message('before check l_action_log_required_flag'); 
        
        IF l_action_log_required_flag THEN
            /* Construct message for Quality Action Log Entry */
            build_action_log_message(
                p_element_name              => c_cen_disposition_status
                ,p_action_name              => l_action_name
                ,p_nonconformance_number    => NULL  
                ,p_verify_nc_number         => NULL  
                ,p_disposition_number       => l_wdi_rec.attribute4
                ,p_new_status               => l_disposition_status  
                ,p_old_status               => l_disposition_status
                ,p_disposition              => l_disposition
                ,p_occurrence               => l_occurrence
                ,p_move_order_number        => NULL
                ,p_doc_instance_id          => p_doc_instance_id --CHG0047103                
                ,p_note                     => l_note
                ,p_message                  => l_action_log_message    
            ); 
            /* Log the initiation of the workflow in the Quality Action Log*/
            create_quality_action_log_row(
                p_plan_id       => l_wdi_rec.attribute2,
                p_collection_id => l_wdi_rec.attribute3,
                p_creation_date => SYSDATE,
                p_char_id       => qa_core_pkg.get_element_id(c_cen_disposition_status),--XX_DISPOSITION_STATUS
                p_operator      => 7, --We use 7 which is "is entered" only because p_operator can't be null and if set to 0 it won't be visible in Action log.
                p_low_value     => NULL,
                p_high_value    => NULL,
                p_message       => l_action_log_message,
                p_result        => NULL,
                p_concurrent    => 0, --"online" (is being called as part of a concurrent request).  As of the initial release, this is always called in the context of a concurrent request so we hardcod this to 1.
                p_log_number    => l_log_number
                );

        END IF;
        
        write_message('before check l_update_wf_message_flag'); 
        
        IF l_update_wf_message_flag THEN
            /* Build the workflow status message. */
            l_wf_msg := build_disposition_wf_message(
                p_disposition_number => l_wdi_rec.attribute4
                ,p_event_name        => p_event_name
                ,p_note              => NULL
            );

            /* Write the message to the XX_WORKFLOW_MESSAGE element on the Disposition record.
               This update will be done directly.  If there is a need to update the value via the
               Quality Results Open Interface, then use an approach similar to the update_disposition_status
               procedure that supports both methods (direct update and results interface).
            */
            wf_update_disposition_msg (
                p_plan_id        => l_wdi_rec.attribute2
                ,p_occurrence    => l_occurrence
                ,p_new_value     => l_wf_msg
                ,p_err_code      => l_err_code);
            IF l_err_code = c_success THEN--'SUCCESS' THEN
                NULL;
            ELSE
                RAISE UPDATE_WF_MSG_ERROR;
            END IF;
        END IF;
        
        write_message('before check l_status_update_required_flag'); 
        
        IF l_status_update_required_flag THEN
            /* Update the Disposition Status to reflect the workflow event.*/
            --write_message('before update_disposition_status'); 
            update_disposition_status (
                p_organization_id        => l_wdi_rec.attribute1
                ,p_nonconformance_number => NULL
                ,p_verify_nc_number      => NULL
                ,p_disposition_number    => l_wdi_rec.attribute4 --Disposition Number
                ,p_run_import            => c_no -- Don't run Collection Import Manager after inserting records into interface table
                ,p_err_code              => l_err_code
                ,p_err_msg               => l_err_msg
            );
        END IF;
        
        p_err_code := l_err_code;
        p_err_msg  := l_err_msg;

        --write_message('end of wf_doc_approval_event_handler'); 

    EXCEPTION
        WHEN UPDATE_WF_MSG_ERROR THEN
            write_message('Handle UPDATE_WF_MSG_ERROR'); 
            p_err_code := c_fail;
            --l_err_msg  := 'Failed to update ' || c_cen_workflow_message || '; #' || l_current_line;  
            p_err_msg  := l_err_msg; 
              
        WHEN OTHERS THEN 
            write_message('Handle OTHERS'); 
            p_err_code := c_fail;
            l_err_msg  := SQLERRM; --|| '; #' || l_current_line;
            p_err_msg  := 'wf_doc_approval_event_handler:' || l_err_msg;
    END wf_doc_approval_event_handler;

    ----------------------------------------------------------------------------------------------------
    --  Name:               update_result_value
    --  Created By:         Hubert, Eric
    --  Revision:           1.2
    --  Creation Date:      25-Jan-2019
    --  Purpose:            Directly update a collection result value to avoid
    --                      the complexity and performance decrease of using
    --                      the using the Quality Results Open Interface.
    --
    --  Description: This function is currently limited to updating result values
    --    for user-defined elements defined with a data type of Character.  This
    --    could be expanded in scope in the future but it meets the immediate
    --    needs of updating the xx_nonconformance_status and xx_disposition_status
    --    collection elements with minimal complexity.  Care would need to be taken
    --    in ensuring that data conversions are done properly.  Also, some elements
    --    store IDs for foreign tables (such as Item) so care must be taken to
    --    update the "id" value.  There is NOT any validation done on the new value!
    --
    --  Inputs:
    --    
    --
    --  Outputs:
    --    p_: Status of the update
    --
    --  Future Enhancements:
    --   Use qa_results_api.update_row to do update.
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   25-Jan-2019   Hubert, Eric    CHG0042589
    --  1.2   01-Apr-2020   Hubert, Eric    CHG0047103: added parameter p_err_msg
    ----------------------------------------------------------------------------------------------------
    PROCEDURE update_result_value(
        p_plan_id        IN  qa_plans.plan_id%TYPE
        ,p_occurrence    IN  qa_results.occurrence%TYPE
        ,p_char_name     IN  qa_chars.name%TYPE
        ,p_new_value     IN  VARCHAR2 --
        ,p_err_code      OUT NUMBER --Status of the import process
        ,p_err_msg       OUT VARCHAR2 --CHG0047103
    )
    IS
        c_method_name CONSTANT VARCHAR(30) := 'update_result_value';
        
        l_column_name   all_tab_columns.column_name%TYPE;
        l_plan_id       NUMBER;
        l_update_sql    VARCHAR2(500);
        l_err_msg       VARCHAR2(1000);
    
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        --write_message('program unit: ' || gv_log_program_unit);

        /* Get the result column name and plan id for a plan-element record. 
           CHG0046276: find column via plan_id instead of plan name. */
        EXECUTE IMMEDIATE 'SELECT
                result_column_name
            FROM qa_plan_chars_v
            WHERE  enabled_flag = 1 --Enabled
                AND SUBSTR(result_column_name,1,9) = ''CHARACTER'' --Is a user-defined field
                AND datatype = 1 --Character
            AND plan_id = :planid
            AND char_name = :charname'
        INTO l_column_name
        USING p_plan_id, p_char_name;
        
        --write_message('l_column_name: ' || l_column_name);
        --write_message('l_plan_id: ' || l_plan_id);
        
        IF l_column_name IS NOT NULL AND p_plan_id IS NOT NULL THEN
            --write_message('p_occurrence: ' || p_occurrence);
            --write_message('p_new_value: ' || p_new_value);

            /* Build SQL to update the necessary column*/
            l_update_sql := 
                'UPDATE qa_results
                SET ' || l_column_name || ' = :newvalue
                , last_updated_by = fnd_profile.value(''USER_ID'')
                , last_update_date =  SYSDATE 
                , last_update_login =  USERENV(''SESSIONID'')
                WHERE
                occurrence = :occurrence
                and plan_id = :planid';
            
            --write_message('l_update_sql: ' || l_update_sql);

            /* Update the value for the specified column in a specified result record */
            EXECUTE IMMEDIATE l_update_sql
            USING p_new_value, p_occurrence, p_plan_id;
            COMMIT;

            p_err_code := c_success;
        ELSE
            write_message('l_column_name or p_plan_id exception');
            p_err_code := c_fail;
        END IF;

    /* Exception handling */
    EXCEPTION
        WHEN OTHERS THEN
            p_err_code := c_fail;
            p_err_msg  := ('Exception in ' || c_method_name || ': ' || SQLERRM );
            --write_message('Exception in ' || c_method_name || ': ' || SQLERRM );
    END update_result_value;

    ----------------------------------------------------------------------------------------------------
    --  Name:               wf_inquire_open_doc_approvals
    --  Created By:         Hubert, Eric
    --  Revision:           2.0
    --  Creation Date:      24-Oct-2019
    --  Purpose:            Returns the number of "open" workflows for the 
    --                      disposition.  Optionally abort all open instances 
    --                      of a doc approval workflow for a disposition.
    --
    --  Parameters :
    --       Name             Type    Purpose
    --       --------         ----    -----------
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date            Name            Desc
    --  1.0   24-Oct-2019     Hubert, Eric    CHG0046276: initial build
    --  2.0   01-Apr-2020     Hubert, Eric    CHG0047103: 
    --                                        -renamed from "inquire_open_doc_approvals" to follow local naming convention
    --                                        -Simplify procedure to just return open workflows.
    --                                        -Move code to abort workflows to wf_abort_disposition_approvals.
    ----------------------------------------------------------------------------------------------------
    PROCEDURE wf_inquire_open_doc_approvals(
        p_disposition_number   IN  qa_results.sequence7%TYPE
        ,p_doc_code            IN  xxobjt_wf_docs.doc_code%TYPE
        ,p_open_doc_count      OUT NUMBER
        )
    IS
        c_method_name CONSTANT VARCHAR(30) := 'wf_inquire_open_doc_approvals';
        
        l_err_code              NUMBER := c_success;
        l_err_msg               VARCHAR2(1000);
        l_open_wf_count         NUMBER := 0;
        
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        --write_message('program unit: ' || gv_log_program_unit);

        SELECT COUNT(*)
        INTO l_open_wf_count
        FROM xxobjt_wf_doc_instance xfdi
        INNER JOIN xxobjt_wf_docs xwd ON (xwd.doc_id = xfdi.doc_id)
        WHERE doc_code = p_doc_code
            AND doc_status IN (c_xwds_inprocess)
            AND xfdi.attribute4 = p_disposition_number;
            
            p_open_doc_count := NVL(l_open_wf_count, 0);
            
            --write_message('end of wf_inquire_open_doc_approvals 1');
        
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            p_open_doc_count := 0;
            write_message('l_err_code: ' || l_err_code);
            write_message('l_err_msg: ' || l_err_msg);
        WHEN OTHERS THEN     
            p_open_doc_count := -1; --"-1" will represent an error
            write_message('l_err_code: ' || l_err_code);
            write_message('l_err_msg: ' || l_err_msg);
    END wf_inquire_open_doc_approvals;

    ----------------------------------------------------------------------------------------------------
    --  Name:               conc_output_file_name
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      01-Apr-2020
    --  Purpose:            Build/get the file name of the concurrent request output file or burst
    --                      file for a specific notification type and disposition number.  This 
    --                      procedure keeps us from having to construct the file name in each
    --                      procedure/function that it is referenced.
    --
    --  Parameters :
    --       Name             Type    Purpose
    --       --------         ----    -----------
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date            Name            Desc
    --  1.0   01-Apr-2020     Hubert, Eric    CHG0047103: initial build
    ----------------------------------------------------------------------------------------------------
    FUNCTION conc_output_file_name(
        p_notification_type_code IN  VARCHAR2,
        p_request_id             IN  NUMBER := NULL,
        p_disposition_number     IN  qa_results.sequence7%TYPE := NULL
        ) RETURN VARCHAR2
    IS
        c_method_name CONSTANT VARCHAR(30) := 'conc_output_file_name';
        
        l_file_name VARCHAR2(200);
        l_sep       VARCHAR2(1) := c_file_name_element_separator; --default separator character to the one defined at the package body level
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        --write_message('program unit: ' || gv_log_program_unit);
        
        IF p_disposition_number IS NULL 
           AND p_request_id IS NOT NULL THEN
            /* If the disposition number was not passed, we infer this to mean that the file
               name produced is the "standard" XML Publisher naming convention consisting
               of the program short name, concurrent request number, count component (typically "1"), and the
               file extension (as opposed by bursted files in which we get to specify
               how they are named).
               
               Cuurently, we only need to be concerned about html files produced by 
               XXQA: Quality Nonconformance Notifications (XXQA_NONCONFORMANCE_NOTIFY).
            */
            l_file_name   := c_psn_ncn || l_sep || p_request_id || l_sep || '1' || c_ext_html;
        ELSIF p_disposition_number IS NOT NULL THEN
            /* If the disposition number is passed, we infer this to mean that the file
               is for bursted output.  Our chosen naming convention for this is 
               the program short name, notification type code, disposition number, and 
               the file extension.
               
               Cuurently (initial build), we only need to be concerned about bursted html files produced by 
               XXQA: Quality Nonconformance Notifications (XXQA_NONCONFORMANCE_NOTIFY).
            */        
            --write_message('c_notification_type_spa :' || c_notification_type_spa);
            CASE p_notification_type_code
            WHEN c_notification_type_spa THEN --S_PRE_APPROVAL
                l_file_name := c_psn_ncn || l_sep || c_notification_type_spa || l_sep || p_disposition_number || c_ext_html;
            
            WHEN c_notification_type_rav THEN --RAV_APPROVED
                l_file_name := c_psn_ncn || l_sep || c_notification_type_rav || l_sep || p_disposition_number || c_ext_html;
                
            WHEN c_notification_type_rtv THEN --RTV_APPROVED
                l_file_name := c_psn_ncn || l_sep || c_notification_type_rtv || l_sep || p_disposition_number || c_ext_html;
            
            WHEN c_notification_type_sim THEN --S_ISSUE_MATERIAL
                l_file_name := c_psn_ncn || l_sep || c_notification_type_sim || l_sep || p_disposition_number || c_ext_html;
            
            WHEN c_notification_type_rts THEN --UAI_RETURN_TO_STOCK
                l_file_name := c_psn_ncn || l_sep || c_notification_type_rts || l_sep || p_disposition_number || c_ext_html;
                
            ELSE
                NULL;
                
            END CASE;
        ELSE
            l_file_name := NULL;
        END IF;
        
        RETURN l_file_name;
        
    EXCEPTION
        WHEN OTHERS THEN
            RETURN NULL;
    END conc_output_file_name;

    ----------------------------------------------------------------------------------------------------
    --  Name:               directory_path
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      01-Apr-2020
    --  Purpose:            Getthe directory path for an Oracle EBS directory name.
    --
    --  Parameters :
    --       Name             Type    Purpose
    --       --------         ----    -----------
    --       p_directory_name IN      Provide name of directory
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date            Name            Desc
    --  1.0   01-Apr-2020     Hubert, Eric    CHG0047103: initial build
    ----------------------------------------------------------------------------------------------------
    FUNCTION directory_path(p_directory_name IN VARCHAR2) RETURN VARCHAR2 IS --CHG0047103
        c_method_name CONSTANT VARCHAR(30) := 'directory_path';
        
        l_directory_path all_directories.directory_path%TYPE;
    BEGIN
        SELECT directory_path
        INTO   l_directory_path
        FROM   all_directories
        WHERE  directory_name IN (p_directory_name);
        
        RETURN l_directory_path;
        
    EXCEPTION
        WHEN OTHERS THEN
            RETURN NULL;
    END;

    ----------------------------------------------------------------------------------------------------
    --  Name:               get_conc_request_output_html
    --  Created By:         Hubert, Eric
    --  Revision:           2.0
    --  Creation Date:      24-Oct-2019
    --  Purpose:            This Procedure gets the HTML output of a program and puts it into a BLOB Variable.
    --                      To get the report file; first custom code in "Before Approval" should execute sucessfully (Refer to Objet Doc Approval Set Up)
    --                               
    --  Description:        Adapted from Sandeep Akula's get_conc_request_output procedure per CHG0033620 to get PDF output.
    --                      It is currently designged to get/return just html output but that could be enhanced in the future for a general-purpose function
    --
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   24-Oct-2019   Hubert, Eric    CHG0046276: initial build
    --  2.0   01-Apr-2020   Hubert, Eric    CHG0047103:
    --                                      -simplified derivation of file name by getting it from an attribute on the xxobjt_wf_doc_instance record via p_doc_instance_id
    --                                      -alternatively, the p_file_name can be explicilty specified instead of the doc instance ID (p_doc_instance_id)
    ----------------------------------------------------------------------------------------------------
    PROCEDURE get_conc_request_output_html(
        p_doc_instance_id    IN     VARCHAR2
        ,p_file_name         IN     VARCHAR2
        ,p_display_type      IN     VARCHAR2
        ,p_document          IN OUT BLOB
        ,p_document_type     IN OUT VARCHAR2
        ,p_err_code          OUT    NUMBER
        ,p_err_msg           OUT    VARCHAR2
    ) IS

        c_method_name CONSTANT VARCHAR(30) := 'get_conc_request_output_html';

        l_doc_instance_id       NUMBER; --XX Doc Approval ID
        l_source_bfile          BFILE;
        l_temp_lob              BLOB;
        l_offset                NUMBER := 1; --Offset in bytes
        l_file_name             VARCHAR2(200);
        l_err_msg              VARCHAR2(2000);
        
        NO_FILE_NAME EXCEPTION;
        
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('program unit: ' || gv_log_program_unit);

        IF p_file_name IS NOT NULL THEN --Use the passed file name, if provided.
            l_file_name := p_file_name;
            
        ELSIF  p_doc_instance_id IS NOT NULL THEN --Otherwise, get it from the xx dox approval record.
            /* Convert doc instance id string to number. */
            l_err_msg         := 'Error Occured while deriving l_doc_instance_id';
            l_doc_instance_id := TO_NUMBER(p_doc_instance_id);

            /* Get the file name from the XX Doc Approval record. */
            l_err_msg   := c_method_name || ': Error Occured while deriving l_file_name';
            SELECT
                xwdi.attribute6 --file name
            INTO
                l_file_name --CHG0047103
            FROM   xxobjt_wf_docs         xwd,
                   xxobjt_wf_doc_instance xwdi
            WHERE  xwd.doc_id = xwdi.doc_id
            AND    xwd.doc_code = c_wf_doc_code_scrap --QA_NC_DISP_SCRAP
            AND    xwdi.doc_instance_id = l_doc_instance_id;
        END IF;
        
        IF l_file_name IS NULL THEN
            l_err_msg := ': l_file_name is NULL. p_doc_instance_id=' || p_doc_instance_id ||' p_file_name=' || p_file_name;
            RAISE NO_FILE_NAME;
        END IF;
        
        /* Creates a temporary BLOB or CLOB and its corresponding index in the user's default temporary tablespace */
        l_err_msg := 'Error Occured in dbms_lob.createtemporary';
        dbms_lob.createtemporary(
            lob_loc => l_temp_lob
            ,cache  => TRUE
            ,dur    => dbms_lob.session);

        /* BFILE Returns a BFILE locator that is associated with a physical LOB binary file on the server file system.*/
        l_err_msg := 'Error Occured in bfilename';
        l_source_bfile := BFILENAME(c_directory_qa_wf, l_file_name); --directory , filename
        
        /* procedure opens a BFILE for read-only access. BFILE data may not be written through the database. */
        l_err_msg := 'Error Occured in dbms_lob.fileopen for file "' || l_file_name || '".';
        dbms_lob.fileopen(
            file_loc   => l_source_bfile
            ,open_mode => dbms_lob.file_readonly);
        
        /* loads data from BFILE to internal BLOB. */
        l_err_msg := 'Error Occured in dbms_lob.loadblobfromfile';
        dbms_lob.loadblobfromfile(
                dest_lob    => l_temp_lob,
                src_bfile   => l_source_bfile,
                amount      => dbms_lob.getlength(l_source_bfile),
                dest_offset => l_offset,
                src_offset  => l_offset);

        /* Closes a BFILE that has already been opened through the input locator. */
        l_err_msg := 'Error Occured in dbms_lob.fileclose';
        dbms_lob.fileclose(file_loc => l_source_bfile);
 
        /* Construct documenttype string. */
        l_err_msg         := 'Error Occured in document_type';
        p_document_type   := 'application/html' || ';name=' || l_file_name;
 
        /* Copy the BLOB. */
        l_err_msg := 'Error Occured in dbms_lob.copy';
        dbms_lob.copy(
            dest_lob => p_document
            ,src_lob => l_temp_lob
            ,amount  => dbms_lob.getlength(l_temp_lob));
        
        /* Clean up. */
        l_err_msg := 'Error Occured in dbms_lob.freetemporary';
        dbms_lob.freetemporary(lob_loc => l_temp_lob);

        l_err_msg  := 'HTML retrieved from concurrent request output file "' || l_file_name || '".';
        
        p_err_code := c_success;
        p_err_msg  := l_err_msg;

    EXCEPTION
        WHEN NO_FILE_NAME THEN
            p_err_code := c_fail;
            l_err_msg := 'Exception in ' || c_method_name || ': ' || l_err_msg;
            p_err_msg  := l_err_msg;
            write_message(l_err_msg);

            --redundant with write_message above fnd_log.string(
            --     log_level => fnd_log.level_event,
            --     module    => gv_api_name || c_method_name,
            --     message   => l_err_msg);
                 
            wf_core.context(
                'XXQA_DISP_DOC_APPROVAL_WF_PKG',
                c_method_name,
                p_doc_instance_id,
                p_display_type,
                l_err_msg);
                
        WHEN OTHERS THEN
            p_err_code := c_fail;
            l_err_msg := 'Exception in ' || c_method_name || ': ' || l_err_msg  || '-' || SQLERRM;
            p_err_msg  := l_err_msg;
            write_message(l_err_msg);

            --redundant with write_message above fnd_log.string(
            --     log_level => fnd_log.level_event,
            --     module    => gv_api_name || c_method_name,
            --     message   => l_err_msg);
            
            IF p_doc_instance_id IS NOT NULL THEN --CHG0047103: there is no workflow context unless the doc instance id (p_doc_instance_id) was passed.
                wf_core.context(
                    'XXQA_DISP_DOC_APPROVAL_WF_PKG',
                    c_method_name,
                    p_doc_instance_id,
                    p_display_type,
                    l_err_msg);
            END IF;
            
            RAISE;
    END get_conc_request_output_html;

    ----------------------------------------------------------------------------------------------------
    --  Name:               wf_disposition_mgr_wrapper
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      01-Apr-2020
    --  Purpose:            Wrapper procedure used to call private procedure, wf_disposition_manager_main, from a concurrent
    --                      program, typically for the purpose of inititating a workflow to approve a disposition.  However,
    --                      it can also be used to cancel workflows, via the p_workflow_management_option parameter.
    --
    --  Description:
    --                      It is important to note that a workflow can only be initiated if the Disposition Status is "PRE_APPROVAL", which
    --                      means that the html to be used for the notification body has already been created.  This html is created
    --                      by running XXQA_NONCONFORMANCE_NOTIFICATIONS with a notifiation type of "S_PRE_APPROVAL".
    --
    --                      This wrapper procedure will optionally limit the dispositions  processed in wf_disposition_manager_main based upon a Nonconformance, Verification,
    --                      or disposition number passed by the concurrent request.
    --           
    --                      Called by program XXQA_INITIATE_DISP_APPROVAL
    --  Parameters :
    --       Name                 Type    Purpose
    --       --------             ----    -----------

    ----------------------------------------------------------------------------------------------------
    --  Ver   Date            Name            Desc
    --  1.1   01-Apr-2020     Hubert, Eric    CHG0047103: initial release (Scrap is the only Disposition that currently requires approval.)
    --  2.0   01-Apr-2021     Hubert, Eric    CHG0049611: -efactored to pass additional paramaters to nonconformance_report_data without "dynamic where clause" variables.
    ----------------------------------------------------------------------------------------------------
    PROCEDURE wf_disposition_mgr_wrapper(
                                    errbuf                          OUT VARCHAR2,
                                    retcode                         OUT VARCHAR2,
                                    p_organization_id               IN NUMBER, --Required
                                    p_disposition                   IN VARCHAR2 DEFAULT c_disp_s, --The only disposition currently requiring approvals is Scrap so this will be defaulted at the program level.
                                    p_nonconformance_number         IN VARCHAR2 DEFAULT NULL,
                                    p_verify_nonconformance_number  IN VARCHAR2 DEFAULT NULL,
                                    p_disposition_number            IN VARCHAR2 DEFAULT NULL,
                                    p_workflow_management_option    IN NUMBER   DEFAULT c_wmo_cancel_all_create
                                    
                                    ) IS
        
        /* Local Constants */
        c_method_name CONSTANT VARCHAR(30) := 'wf_disposition_mgr_wrapper';

        /* Local Variables */
        l_disposition_status    qa_results.character1%TYPE;
  
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('program unit: ' || gv_log_program_unit);
        
        retcode := 0; --Success (Green)

        /* Set public variables based on the concurrent request parameters. */
        xxqa_nonconformance_util_pkg.p_organization_id              := p_organization_id;
        xxqa_nonconformance_util_pkg.p_nonconformance_number        := p_nonconformance_number;
        xxqa_nonconformance_util_pkg.p_verify_nonconformance_number := p_verify_nonconformance_number;
        xxqa_nonconformance_util_pkg.p_disposition_number           := p_disposition_number;  
        xxqa_nonconformance_util_pkg.p_workflow_management_option   := p_workflow_management_option;

        /* Set some values based upon the Disposition. */
        CASE p_disposition
        WHEN c_disp_s THEN --We only need to be concerned about scrap, currently.
            l_disposition_status := c_d_status_pra;  --Scrap approval workflow should only be initiated when the Disposition status is PRE_APPROVAL.
        ELSE
            l_disposition_status := NULL;
        END CASE;            

        --write_message('l_disposition_status: ' || l_disposition_status);

        /* Write nc rows into package variable which will later be used by a SQL statement in the the data template. */
        gv_nc_rpt_tab := xxqa_nonconformance_util_pkg.nonconformance_report_data (
                    p_sequence_1_value    => p_nonconformance_number
                    ,p_sequence_2_value   => p_verify_nonconformance_number
                    ,p_sequence_3_value   => p_disposition_number
                    ,p_organization_id    => p_organization_id
                    ,p_occurrence         => NULL
                    ,p_nc_active_flag     => c_yes
                    ,p_disp_active_flag   => c_yes
                    ,p_disposition_status => l_disposition_status
                    ,p_disposition        => p_disposition
            );
        --write_message('gv_nc_rpt_tab.COUNT: ' || gv_nc_rpt_tab.COUNT);        

        IF gv_nc_rpt_tab.COUNT > 0 THEN
            /* Call the Disposition Workflow Manager */
            wf_disposition_manager_main;
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            retcode := 2; --Error (Red)
            errbuf  := 'Error in xxqa_nonconformance_util_pkg.wf_disposition_mgr_wrapper ' || SQLERRM;
    
        write_message('errbuf: ' || errbuf);
    END wf_disposition_mgr_wrapper;

    ----------------------------------------------------------------------------------------------------
    --  Name:               wf_get_notif_body_scrap_pvt
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      01-Apr-2020
    --  Purpose:            Private/local procedure to construct HTML body for approval notifications/emails.
    --                               
    --  Description:        Core HTML is extracted from the concurrent request output of XXQA: Quality Nonconformance Notifications.
    --                      Special characters are repalced and the HTML is converted to XML where it is queried for content of 
    --                      interest related to the Quality Nonconformance Disposition.
    --
    --                      Action history information is appended to the disposition information.
    --                      Content is returned as HTML.
    --
    --                      This procedure is most frequently called via wf_get_notify_body_wrapper by the XX Doc Approval engine 
    --                      passing the doc instance ID.  However, it is also called before the workflow is created so that we can check that the html file that is to
    --                      be used for the notifications is not "empty".  For this situation, we don't pass the doc id because
    --                      it is not yet known/created.  Instead, we pass the Disposition Number from which we can infer the
    --                      file name of the burst concurrent request output.  The Action History won't (can't) be appended in this situation.
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   01-Apr-2020   Hubert, Eric    CHG0047103: initial build
    ----------------------------------------------------------------------------------------------------
    PROCEDURE wf_get_notif_body_scrap_pvt(
        p_doc_instance_id    IN VARCHAR2,
        p_disposition_number IN qa_results.sequence7%TYPE := NULL, --CHG0047103
        p_display_type       IN VARCHAR2,
        p_document           IN OUT NOCOPY CLOB,
        p_document_type      IN OUT NOCOPY VARCHAR2,
        p_err_code           OUT NUMBER, --CHG0047103
        p_err_msg            OUT VARCHAR2 --CHG0047103
        ) IS
        
        c_method_name CONSTANT VARCHAR(30) := 'wf_get_notif_body_scrap_pvt';
        
        c_namespace_attb          CONSTANT VARCHAR2(5)  := 'xmlns';
        c_namespace_value         CONSTANT VARCHAR2(30) := '"http://www.w3.org/1999/xhtml"';
        c_namespace_attb_val      CONSTANT VARCHAR2(50) := c_namespace_attb || '=' || c_namespace_value;
        c_action_history_tag_name CONSTANT VARCHAR2(50) := 'actionhistory';
        c_action_history_element  CONSTANT VARCHAR2(50) := '<' || c_action_history_tag_name || '/>';

        g_item_type                  VARCHAR2(100) := 'XXWFDOC';
        l_doc_instance_id            NUMBER := TO_NUMBER(p_doc_instance_id);
        l_file_name                  VARCHAR2(200); --CHG0047103
        l_conc_request_output_blob   BLOB;
        l_conc_req_output_xhtml_clob CLOB;
        l_action_history_clob        CLOB;
        l_history_detail_clob        CLOB;
        l_clob_out                   CLOB;
        l_html_style_element_clob    CLOB;
        l_html_body_element_clob     CLOB;
        l_conc_req_output_xmltype    XMLType;
        l_xmltype_temp               XMLType;
        l_xquery_string              VARCHAR2(32000);
        l_clob_string                VARCHAR2(32000);
        l_err_code                   NUMBER;--CHG0047103
        l_err_msg                    VARCHAR2(1000);--CHG0047103
        
        HTML_RETRIEVAL_ERROR          EXCEPTION; --CHG0047103

    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('program unit: ' || gv_log_program_unit);

        /* Determine how we are going to get the html output: referencing doc instance id vs disposition number.*/
        IF p_disposition_number IS NOT NULL THEN
            /* Get the file name that contains the raw html that will be included in the workflow's notifications. */
            l_file_name := conc_output_file_name(
                    --p_notification_type_code => p_notification_type_code,
                    p_notification_type_code => c_notification_type_spa, --CHG0047103: hard-coded, was "p_notification_type_code"
                    p_request_id             => NULL,
                    p_disposition_number     => p_disposition_number
                );
        END IF;
        
        p_document_type := 'text/html';
        p_document      := ' ';

        dbms_lob.createtemporary(l_conc_request_output_blob, TRUE, dbms_lob.session);
        dbms_lob.createtemporary(l_clob_out, TRUE, dbms_lob.session);
        dbms_lob.createtemporary(l_action_history_clob, TRUE, dbms_lob.session);
        dbms_lob.createtemporary(l_history_detail_clob, TRUE, dbms_lob.session);

        /* Extract html from the output file of XXQA: Quality Nonconformance Notifications concurrent request. */
        get_conc_request_output_html(
            p_doc_instance_id => l_doc_instance_id,
            p_file_name       => l_file_name, --CHG0047103
            p_display_type    => p_display_type,
            p_document        => l_conc_request_output_blob,
            p_document_type   => p_document_type,
            p_err_code        => l_err_code,--CHG0047103
            p_err_msg         => l_err_msg  --CHG0047103          
            );
       
        IF l_err_code = c_fail THEN
            RAISE HTML_RETRIEVAL_ERROR;
        END IF;

        l_conc_req_output_xhtml_clob := blob_to_clob (p_data  => l_conc_request_output_blob);

        /* -Per Doc ID 1407634.1: "Starting in 11g, outbound connections from the database for DTD validation are disallowed.  
            Specifically, XDB's code explicitly disallows outbound connections from the db for DTD validation, regardless of any configured ACL.
           -As a workaround, we will remove the doc type <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
           -We do two separate replacements for the doctype because of a line feed character before the double quotes that was causing matching 
            issues with REGEXP_REPLACE. (A little more time working with this would have yielded a more elegant single regexp_replace solution).
        */
        l_conc_req_output_xhtml_clob := REGEXP_REPLACE(l_conc_req_output_xhtml_clob, '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"', ''); --First line
        l_conc_req_output_xhtml_clob := REGEXP_REPLACE(l_conc_req_output_xhtml_clob, '"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">', ''); --Second line, after line feed CHR(10)
        l_conc_req_output_xhtml_clob := REGEXP_REPLACE(l_conc_req_output_xhtml_clob, '&nbsp', '&#160');  --Because we lack a DTD which indicates what &nbsp  means, we need to replace it with a non-breaking space and will use deciamal &#160. 
        l_conc_req_output_xhtml_clob := REGEXP_REPLACE(l_conc_req_output_xhtml_clob, '''Consolas'';', 'Consolas;');  --Single quotes around the font name cause the font to not be used.  We use Consolas because it has "slashed" zeros to differentiate them from the letter "O" and is the font used for several other XML publisher reports. 

        
        /* Create an xmltype variable from the concurrent request output so that we can extract specific elements. */
        l_conc_req_output_xmltype := XMLTYPE.createXML(l_conc_req_output_xhtml_clob);

        /* Add a dummy/placeholder element for the action history. */
        l_xquery_string :='xquery version "1.0";
            declare default element namespace ' || c_namespace_value || ';
            copy $tmp := . modify insert node 
            ' || c_action_history_element || '
            as last into $tmp/html/body
            return $tmp';

        SELECT 
          XMLQuery(l_xquery_string --xquery-string-literal
                   PASSING l_conc_req_output_xmltype RETURNING CONTENT
                   )
            INTO l_conc_req_output_xmltype
        FROM dual;

        /* Extract the style element */
        l_html_style_element_clob :=  l_conc_req_output_xmltype.extract('/html/head/style', c_namespace_attb_val).getclobval;
        dbms_lob.append(l_clob_out, l_html_style_element_clob);

        /* Extract the body element */
        l_html_body_element_clob :=  l_conc_req_output_xmltype.extract('/html/body', c_namespace_attb_val).getclobval;
        dbms_lob.append(l_clob_out, l_html_body_element_clob);

        /* Append the Action History if we aren't doing the pre-workflow file content check. */
        IF l_file_name IS NULL THEN
            /* Get the Action History detail */
            xxobjt_wf_doc_rg.get_history_wf(
                document_id   => p_doc_instance_id,
                display_type  => '',
                document      => l_history_detail_clob,
                document_type => p_document_type);

            /* Build the action log html*/
            dbms_lob.append(l_action_history_clob, '<font face="Consolas" style="color:black;" size="2">');
            --dbms_lob.append(l_action_history_clob, '<DEBUG_NOTE>(wf_get_notif_body_scrap_pvt - Action Log: ' || local_datetime || ')</DEBUG_NOTE>');--CHG0047103: put the current time in the body.  Want to see if this is called for every notification.
            dbms_lob.append(l_action_history_clob, '<p> <font face="Consolas" style="color:darkblue" size="3"> <strong>Action History</strong> </font> </p>');
            dbms_lob.append(l_action_history_clob, l_history_detail_clob);

            /* Replace the dummy/placeholder element with the action history html. */
            l_clob_out := REGEXP_REPLACE(l_clob_out, '<actionhistory xmlns="http://www.w3.org/1999/xhtml"/>', l_action_history_clob);
        END IF;

        dbms_lob.copy(p_document, l_clob_out, dbms_lob.getlength(l_clob_out));
        
        p_err_code := c_success;
        p_err_msg  := NULL;
        
        /* Clean up*/
        dbms_lob.freetemporary(l_conc_req_output_xhtml_clob);
        dbms_lob.freetemporary(l_html_style_element_clob);
        dbms_lob.freetemporary(l_html_body_element_clob);
        dbms_lob.freetemporary(l_action_history_clob);
        dbms_lob.freetemporary(l_history_detail_clob);
        dbms_lob.freetemporary(l_clob_out);
        
    EXCEPTION
        WHEN HTML_RETRIEVAL_ERROR THEN
            p_err_code := c_fail;
            p_err_msg  := l_err_msg;
            p_document := NULL; --CHG0047103: without explicitly returning NULL, an "empty" (but not null) CLOB is returned, leading to a notification that was blank.  We want to force an error rather than send a blank notification.

            write_message('Exeption in ' || c_method_name);

        WHEN OTHERS THEN
            p_err_code := c_fail;
            p_err_msg  := l_err_msg;
            p_document := NULL; --CHG0047103: without explicitly returning NULL, an "empty" (but not null) CLOB is returned, leading to a notification that was blank.  We want to force an error rather than send a blank notification.
            
            write_message('Exeption in ' || c_method_name);

    END wf_get_notif_body_scrap_pvt;

    ----------------------------------------------------------------------------------------------------
    --  Name:               wf_get_notification_body_scrap
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      01-Apr-2020
    --  Purpose:            Public procedure to get HTML body for approval notifications/emails, called
    --                      from XX Doc Approval extension.
    --                               
    --  Description:        See wf_get_notif_body_scrap_pvt for details.
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   01-Apr-2020   Hubert, Eric    CHG0047103: refactored to call wf_get_notif_body_scrap_pvt
    ----------------------------------------------------------------------------------------------------
    PROCEDURE wf_get_notification_body_scrap(
        p_document_id        IN VARCHAR2, --doc instance _id
        p_display_type       IN VARCHAR2,
        p_document           IN OUT NOCOPY CLOB,
        p_document_type      IN OUT NOCOPY VARCHAR2
        ) IS
        
        c_method_name CONSTANT VARCHAR(30) := 'wf_get_notification_body_scrap';
        
        l_err_code  NUMBER;
        l_err_msg   VARCHAR2(1000);
        
    BEGIN
        --/* Based on the document type, call the appropriate function to get the notification body. */
        CASE wf_get_doc_instance_row(p_doc_instance_id => p_document_id).doc_id
        
        /* Our only doc approval workflow implemented is QA_NC_DISP_SCRAP. */
        WHEN  xxobjt_wf_doc_util.get_doc_id(p_doc_code => c_wf_doc_code_scrap) THEN
            wf_get_notif_body_scrap_pvt(
                    p_doc_instance_id    => p_document_id,
                    p_disposition_number => NULL,
                    p_display_type       => p_display_type,
                    p_document           => p_document,
                    p_document_type      => p_document_type,
                    p_err_code           => l_err_code, --CHG0047103
                    p_err_msg            => l_err_msg --CHG0047103
            );
        END CASE;

    EXCEPTION WHEN OTHERS THEN
        write_message('Exception in ' || c_method_name || ': ' || l_err_msg);
        RAISE;
    END wf_get_notification_body_scrap;

    ----------------------------------------------------------------------------------------------------
    --  Name:               mo_create_disp_move_order
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      01-Apr-2020
    --  Purpose:            Create a move order in response to a Scrap or Use As-Is disposition being approved
    --                      
    --  Parameters :
    --       Name             Type    Purpose
    --       --------         ----    -----------
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date            Name            Desc
    --  1.0   01-Apr-2020     Hubert, Eric    CHG0047103: initial build
    ----------------------------------------------------------------------------------------------------
    PROCEDURE mo_create_disp_move_order (
        p_nvd_record            IN  apps.xxqa_nc_rpt_rec_type
        ,p_move_order_number    OUT mtl_txn_request_headers.request_number%TYPE
        ,p_err_code             OUT NUMBER
        ,p_err_msg              OUT VARCHAR2
        )
    IS
        c_method_name CONSTANT VARCHAR(30) := 'mo_create_disp_move_order';
        
        /* Constants */
        c_mo_hdr_desc_prefix_sim    CONSTANT    VARCHAR2(200) := 'Scrap nonconforming material for approved disposition ';
        c_mo_hdr_desc_prefix_rts    CONSTANT    VARCHAR2(200) := 'Return nonconforming material to stock ';
        c_verify_allocation         CONSTANT    BOOLEAN       := FALSE; --Perform a check that the move order line got allocated.  Setting to false now as there is a performance penalty for this.  Also, had instances of two allocation records being created for a mo line qty of 1.  Per Oren 2/4/19, material handlers can select the inventory when they transact the move order.
        
        /* Common Declarations */
        c_api_version   CONSTANT NUMBER := 1.0; 
        l_init_msg_list VARCHAR2(2) := FND_API.G_TRUE; 
        l_return_values VARCHAR2(2) := FND_API.G_FALSE; 
        l_commit        VARCHAR2(2) := FND_API.G_FALSE; 
        x_return_status VARCHAR2(2);
        x_msg_count     NUMBER      := 0;
        x_msg_data      VARCHAR2(255);
        
        /* API specific declarations - Move Order Header */
        l_trohdr_rec             INV_MOVE_ORDER_PUB.TROHDR_REC_TYPE;
        l_trohdr_val_rec         INV_MOVE_ORDER_PUB.TROHDR_VAL_REC_TYPE;
        x_trohdr_rec             INV_MOVE_ORDER_PUB.TROHDR_REC_TYPE;
        x_trohdr_val_rec         INV_MOVE_ORDER_PUB.TROHDR_VAL_REC_TYPE;
        l_validation_flag        VARCHAR2(2) := INV_MOVE_ORDER_PUB.G_VALIDATION_YES;

        /* API specific declarations - Move Order Line */
        l_trolin_tbl             INV_MOVE_ORDER_PUB.TROLIN_TBL_TYPE;
        l_trolin_val_tbl         INV_MOVE_ORDER_PUB.TROLIN_VAL_TBL_TYPE;
        x_trolin_tbl             INV_MOVE_ORDER_PUB.TROLIN_TBL_TYPE;
        x_trolin_val_tbl         INV_MOVE_ORDER_PUB.TROLIN_VAL_TBL_TYPE;

        /* Other */
        l_transaction_reason_name  mtl_transaction_reasons.reason_name%TYPE;
        l_request_number           mtl_txn_request_headers.request_number%TYPE;--desired move order number
        l_header_desc              mtl_txn_request_headers.description%TYPE;
        l_request_number_instance  NUMBER := 1; --In the event that multiple move orders are needed for a single disposition, use a numerical suffix.  Start with this value.
        l_move_order_batch         VARCHAR2(30) := c_mo_batch_prefix || fnd_global.conc_request_id; --Build the move order batch number that will be placed in the Print Event DFF on the move order line.
        l_user_id                  NUMBER := NVL(FND_PROFILE.VALUE('USER_ID'), 0);
        l_row_cnt                  NUMBER := 1;
        l_account_id               NUMBER;
        l_reason_id                NUMBER;
        l_inventory_item_id        NUMBER;
        l_uom_code                 mtl_system_items_b.primary_unit_of_measure%TYPE;

        l_from_subinv_code         mtl_secondary_inventories.secondary_inventory_name%TYPE;
        l_from_locator             mtl_item_locations_kfv.concatenated_segments%TYPE;
        l_from_locator_id          NUMBER;
        l_to_subinv_code           mtl_secondary_inventories.secondary_inventory_name%TYPE;
        l_to_locator               mtl_item_locations_kfv.concatenated_segments%TYPE;
        l_to_locator_id            NUMBER;
        l_date_required_offset     NUMBER := 1; --days
        l_transaction_type_id      NUMBER;
        l_application_id           NUMBER;
        l_program_id               NUMBER;
        
        l_number_of_rows           NUMBER; --allocations
        l_detailed_qty             NUMBER;
        l_revision                 mtl_material_transactions_temp.revision%TYPE;
        l_locator_id               NUMBER;
        l_transfer_to_location     NUMBER;
        l_lot_number               mtl_material_transactions_temp.lot_number%TYPE;
        l_serial_number_start      mtl_serial_numbers.serial_number%TYPE;
        l_serial_number_end        mtl_serial_numbers.serial_number%TYPE;
        l_expiration_date          DATE;
        l_transaction_temp_id      NUMBER;
 
        l_err_msg                  VARCHAR2(1000);
       
        KEY_MOVE_ORDER_ATTRIBUTE_NULL EXCEPTION;
        INVALID_LOCATOR               EXCEPTION;
        
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('program unit: ' || gv_log_program_unit);
       
        BEGIN
        /* Get some values related to the concurrent request. */
            SELECT
                fcr.concurrent_program_id
                ,fcp.application_id
            INTO
                l_program_id
                ,l_application_id
            FROM fnd_concurrent_requests fcr
            INNER JOIN fnd_concurrent_programs fcp ON (fcp.concurrent_program_id = fcr.concurrent_program_id)
            WHERE request_id = fnd_global.conc_request_id;
        EXCEPTION
            WHEN OTHERS THEN
            NULL;
        END;

        /* Get some values needed to create the move order: */
        /* Get the item id for the dispositioned item (not necessarily the nonconformance item) */
        l_inventory_item_id := xxinv_utils_pkg.get_item_id(p_nvd_record.d_part_number_disposition);

        /* Determine the (MRB) subinventory and locator in which the material is located/segregated.
           If more than one row is returned then we can't assume where the inventory is located.
           If no rows are returned then we won't be able to allocate it.
        */
        l_from_subinv_code := p_nvd_record.d_segregation_subinventory;
        l_from_locator     := p_nvd_record.d_segregation_locator;
        
        /* Determine the Serial Numbers
            -Currently, we don't have an adequately normalized data structure on the nonconformance and disposition plans to properly support specifying
             multiple serial numbers on a move order.  Therefore we leave the start/end serial fields null and leave it up to the person transacting
             the move order to allocate the correct serials (as communicated on the email notification).
            -Get this from the disposition record if we ever need to handle serial-controlled scrap. Per Oren, the material handler can specify this at the time of the transaction.
            -The most robust wayto handle this is to have a new LOT_SERIAL_NUMBERS collection plan that would be child plans to both the Nonconformance and Disposition collection plans.
             Multiple serials/lot numbers could be entered for a nonconformance as multiple result rows for this new plan.  This plan would support serialized items, lot-controlled items, and even an item that is both lot and serial controlled (which we don't have).
             Entery of the serials/lots on the nonconformance could be optional if-needed but would be required on the disposition.
             Once entered on the disposition, separate move orders lines for each lot number or continuous range of serials could be created.
            -Per 12-Feb-2020 meeting with Oren, he agrees with the approach described above: simple functionality to start and make more robust if needed in the future.
             
        */
        l_serial_number_start := NULL;
        l_serial_number_end   := NULL;

        /* Determine the Lot Number
            -The same constraints exist for multiple lot numbers as serials.
        */
        l_lot_number := NULL;
        
        /* Get the UOM code for the dispositioned item. */
        SELECT mum.uom_code
        INTO l_uom_code
        FROM mtl_system_items_b msi
        INNER JOIN mtl_units_of_measure mum ON (mum.unit_of_measure = msi.primary_unit_of_measure)
        WHERE
            msi.inventory_item_id = l_inventory_item_id
            AND msi.organization_id = p_nvd_record.d_organization_id;
        
        /* Get the reason id. */
        l_transaction_reason_name := fnd_profile.value('XXQA_TRANSACTION_REASON_NAME_QUALITY_SCRAP');
        SELECT reason_id
        INTO l_reason_id
        FROM mtl_transaction_reasons
        WHERE reason_name = l_transaction_reason_name;

        /* Get some values depending upon the disposition. */
        CASE p_nvd_record.d_disposition
        WHEN c_disp_s THEN
            l_header_desc         := c_mo_hdr_desc_prefix_sim || p_nvd_record.d_disposition_number;
            l_transaction_type_id := INV_GLOBALS.G_TYPE_TRANSFER_ORDER_ISSUE;
            l_to_subinv_code      := NULL; --We're issuing the material, not moving it
            l_to_locator          := NULL;
            l_account_id          := get_scrap_account(p_org_id => p_nvd_record.d_organization_id);
            
        WHEN c_disp_uai THEN
            l_header_desc         := c_mo_hdr_desc_prefix_rts || p_nvd_record.d_disposition_number;
            l_transaction_type_id := INV_GLOBALS.G_TYPE_TRANSFER_ORDER_SUBXFR;
            l_to_subinv_code      := p_nvd_record.d_production_subinventory;
            l_to_locator          := p_nvd_record.d_production_locator;
            l_account_id          := NULL;
        END CASE;

        --write_message('l_from_locator: ' || l_from_locator);

        /* Get the "from" locator_id if needed */
        IF l_from_locator IS NOT NULL THEN
            BEGIN
                SELECT inventory_location_id
                INTO l_from_locator_id
                FROM mtl_item_locations_kfv
                WHERE concatenated_segments = l_from_locator
                AND organization_id = p_nvd_record.d_organization_id;
            EXCEPTION 
                WHEN OTHERS THEN
                    RAISE INVALID_LOCATOR;
            END;
        END IF;

        --write_message('l_from_locator_id: ' || l_from_locator_id);
 
        --write_message('l_to_locator: ' || l_to_locator);
       
        /* Get the "to" locator_id if needed */
        IF l_to_locator IS NOT NULL THEN
            --write_message('l_to_locator IS NOT NULL.');
        
            BEGIN
                SELECT inventory_location_id
                INTO l_to_locator_id
                FROM mtl_item_locations_kfv
                WHERE concatenated_segments = l_to_locator
                AND organization_id = p_nvd_record.d_organization_id;
            EXCEPTION 
                WHEN OTHERS THEN
                    RAISE INVALID_LOCATOR;
            END;
        END IF;
        
        --write_message('l_to_locator_id: ' || l_to_locator_id);
        
        /* Build the desired Move Order number */
        BEGIN
            /* Find existing move orders for the disposition, if any, and get the next instance (suffix) number to use. */
            SELECT NVL(MAX(instance_number) + 1, 1) --Highest existing number for disposition, plus one.  If instance_number is null return 1.
            INTO l_request_number_instance
            FROM
            (
                SELECT
                    /* Move Order Number*/
                    request_number
                    
                    /* Disposition number parsed from the left side of the Move Order/Request Number */
                    ,SUBSTR(request_number, 1, LENGTH(p_nvd_record.d_disposition_number)) disposition_number
                    
                    /* "Instance number" parsed from the right side of the Move Order/Request Number */
                    ,TO_NUMBER(SUBSTR(request_number, LENGTH(p_nvd_record.d_disposition_number || c_file_name_element_separator) + 1)) instance_number
                FROM mtl_txn_request_headers
                WHERE 1=1
                    /* Match on the disposition number and org*/
                    AND request_number LIKE (p_nvd_record.d_disposition_number || '%')
                    AND organization_id = p_organization_id
            );
        EXCEPTION WHEN OTHERS THEN
            write_message('Exception determining l_request_number_instance; defaulting to "1"');
            l_request_number_instance := 1;
        END;
        
        --write_message('l_request_number_instance: ' || l_request_number_instance);
        
        l_request_number := p_nvd_record.d_disposition_number || c_file_name_element_separator || l_request_number_instance; --Build the move order (request) number

        --write_message('l_inventory_item_id: ' || l_inventory_item_id);
        --write_message('l_from_subinv_code: ' || l_from_subinv_code);
        --write_message('l_account_id: ' || l_account_id);
        --write_message('l_uom_code: ' || l_uom_code);
        --write_message('l_request_number: ' || l_request_number);
        --write_message('p_nvd_record.d_quantity_dispositioned: ' || p_nvd_record.d_quantity_dispositioned );

        /* Check that some key values are not null */
        IF
            l_inventory_item_id    IS NOT NULL
            AND l_from_subinv_code IS NOT NULL 
            AND l_uom_code         IS NOT NULL
            AND l_request_number   IS NOT NULL
            AND l_reason_id        IS NOT NULL
            AND p_nvd_record.d_quantity_dispositioned > 0
            AND NOT (p_nvd_record.d_disposition = c_disp_s and l_account_id IS NULL) --scrap account mandatory for Scrap disposition
            AND NOT (p_nvd_record.d_disposition = c_disp_uai and l_to_subinv_code IS NULL) --to subinventory mandatory for Use As-Is disposition
        THEN
            --write_message('before header variable initializations');
            
            /* Create Move Order Header */
            -- Initialize the variables
            l_trohdr_rec.date_required              := SYSDATE + l_date_required_offset;
            l_trohdr_rec.organization_id            := p_nvd_record.d_organization_id;
            l_trohdr_rec.from_subinventory_code     := l_from_subinv_code;
            l_trohdr_rec.to_subinventory_code       := l_to_subinv_code;
            l_trohdr_rec.to_account_id              := l_account_id;
            l_trohdr_rec.status_date                := SYSDATE;
            l_trohdr_rec.request_number             := l_request_number; --Disposition number, separator, and instance number
            l_trohdr_rec.header_status              := INV_Globals.G_TO_STATUS_PREAPPROVED; -- preApproved
            l_trohdr_rec.transaction_type_id        := l_transaction_type_id;
            l_trohdr_rec.move_order_type            := INV_GLOBALS.G_MOVE_ORDER_REQUISITION;
            l_trohdr_rec.db_flag                    := FND_API.G_TRUE;
            l_trohdr_rec.operation                  := INV_GLOBALS.G_OPR_CREATE;
            l_trohdr_rec.description                := l_header_desc;

            /* Who columns */     
            l_trohdr_rec.created_by                 :=  l_user_id;
            l_trohdr_rec.creation_date              :=  SYSDATE;
            l_trohdr_rec.last_updated_by            :=  l_user_id;
            l_trohdr_rec.last_update_date           :=  SYSDATE;
            l_trohdr_rec.last_update_login          :=  FND_GLOBAL.login_id;

            /* Concurrent columns*/
            l_trohdr_rec.program_application_id  := l_application_id;
            l_trohdr_rec.program_id              := l_program_id;
            l_trohdr_rec.program_update_date     := SYSDATE;
            l_trohdr_rec.request_id              := fnd_global.conc_request_id; 

            --write_message('l_trohdr_rec.date_required: ' || l_trohdr_rec.date_required );
            --write_message('l_trohdr_rec.organization_id: ' || l_trohdr_rec.organization_id );
            --write_message('l_trohdr_rec.from_subinventory_code: ' || l_trohdr_rec.from_subinventory_code );
            --write_message('l_trohdr_rec.to_subinventory_code: ' || l_trohdr_rec.to_subinventory_code );
            --write_message('l_trohdr_rec.to_account_id: ' || l_trohdr_rec.to_account_id );
            --write_message('l_trohdr_rec.status_date: ' || l_trohdr_rec.status_date );
            --write_message('l_trohdr_rec.request_number: ' || l_trohdr_rec.request_number );
            --write_message('l_trohdr_rec.header_status: ' || l_trohdr_rec.header_status );
            --write_message('l_trohdr_rec.transaction_type_id: ' || l_trohdr_rec.transaction_type_id );
            --write_message('l_trohdr_rec.move_order_type: ' || l_trohdr_rec.move_order_type );
            --write_message('l_trohdr_rec.db_flag: ' || l_trohdr_rec.db_flag );
            --write_message('l_trohdr_rec.operation: ' || l_trohdr_rec.operation );
            --write_message('l_trohdr_rec.description: ' || l_trohdr_rec.description );
            --write_message('l_trohdr_rec.created_by: ' || l_trohdr_rec.created_by );
            --write_message('l_trohdr_rec.creation_date: ' || l_trohdr_rec.creation_date );
            --write_message('l_trohdr_rec.last_updated_by: ' || l_trohdr_rec.last_updated_by );
            --write_message('l_trohdr_rec.last_update_date: ' || l_trohdr_rec.last_update_date );
            --write_message('l_trohdr_rec.last_update_login: ' || l_trohdr_rec.last_update_login );
            --write_message('l_trohdr_rec.program_application_id: ' || l_trohdr_rec.program_application_id );
            --write_message('l_trohdr_rec.program_id: ' || l_trohdr_rec.program_id );
            --write_message('l_trohdr_rec.program_update_date: ' || l_trohdr_rec.program_update_date );
            --write_message('l_trohdr_rec.request_id: ' || l_trohdr_rec.request_id );

            --write_message('before create_move_order_header');

            /* Call API to create move order header */
            inv_move_order_pub.create_move_order_header(
                 p_api_version_number   => c_api_version
                ,p_init_msg_list        => l_init_msg_list
                ,p_return_values        => l_return_values
                ,p_commit               => l_commit
                ,x_return_status        => x_return_status
                ,x_msg_count            => x_msg_count
                ,x_msg_data             => x_msg_data
                ,p_trohdr_rec           => l_trohdr_rec
                ,p_trohdr_val_rec       => l_trohdr_val_rec
                ,x_trohdr_rec           => x_trohdr_rec
                ,x_trohdr_val_rec       => x_trohdr_val_rec
                ,p_validation_flag      => l_validation_flag
            ); 

            IF x_return_status = FND_API.G_RET_STS_SUCCESS THEN
                write_message('Move Order Header Created Successfully');
            
                /* Initialize the variables before creating the move order line */
                l_trolin_tbl(l_row_cnt).header_id               := x_trohdr_rec.header_id;
                l_trolin_tbl(l_row_cnt).date_required           := x_trohdr_rec.date_required;
                l_trolin_tbl(l_row_cnt).organization_id         := p_nvd_record.d_organization_id;
                l_trolin_tbl(l_row_cnt).inventory_item_id       := l_inventory_item_id;
                l_trolin_tbl(l_row_cnt).from_subinventory_code  := x_trohdr_rec.from_subinventory_code;
                l_trolin_tbl(l_row_cnt).from_locator_id         := l_from_locator_id;
                l_trolin_tbl(l_row_cnt).to_subinventory_code    := x_trohdr_rec.to_subinventory_code;
                l_trolin_tbl(l_row_cnt).to_locator_id           := l_to_locator_id;
                l_trolin_tbl(l_row_cnt).quantity                := p_nvd_record.d_quantity_dispositioned;
                l_trolin_tbl(l_row_cnt).status_date             := SYSDATE;
                l_trolin_tbl(l_row_cnt).uom_code                := l_uom_code;
                l_trolin_tbl(l_row_cnt).line_number             := l_row_cnt;
                l_trolin_tbl(l_row_cnt).line_status             := x_trohdr_rec.header_status;
                l_trolin_tbl(l_row_cnt).db_flag                 := FND_API.G_TRUE;
                l_trolin_tbl(l_row_cnt).operation               := INV_GLOBALS.G_OPR_CREATE;
                l_trolin_tbl(l_row_cnt).reason_id               := l_reason_id;
                l_trolin_tbl(l_row_cnt).reference               := p_nvd_record.d_disposition_number;
                l_trolin_tbl(l_row_cnt).to_account_id           := x_trohdr_rec.to_account_id;
                l_trolin_tbl(l_row_cnt).transaction_type_id     := x_trohdr_rec.transaction_type_id;
                l_trolin_tbl(l_row_cnt).lot_number              := l_lot_number;--p_nvd_record.d_lot_number_disposition;
                l_trolin_tbl(l_row_cnt).serial_number_start     := l_serial_number_start;
                l_trolin_tbl(l_row_cnt).serial_number_end       := l_serial_number_end;
                l_trolin_tbl(l_row_cnt).attribute3              := l_move_order_batch; --"Print Event" DFF which can also be used as a batch number for running XXINV: Move Order Traveler
 
                /* Who columns */
                l_trolin_tbl(l_row_cnt).created_by              := l_user_id;
                l_trolin_tbl(l_row_cnt).creation_date           := SYSDATE;
                l_trolin_tbl(l_row_cnt).last_updated_by         := l_user_id;
                l_trolin_tbl(l_row_cnt).last_update_date        := SYSDATE;
                l_trolin_tbl(l_row_cnt).last_update_login       := FND_GLOBAL.login_id;

                /* Concurrent columns */
                l_trolin_tbl(l_row_cnt).program_application_id  := l_application_id;
                l_trolin_tbl(l_row_cnt).program_id              := l_program_id;
                l_trolin_tbl(l_row_cnt).program_update_date     := SYSDATE;
                l_trolin_tbl(l_row_cnt).request_id              := fnd_global.conc_request_id; 
                
                --write_message('before create_move_order_lines');
                
                /* Call API to create Move Order lines.
                  -Creates lines for every header created before, and provides the line_id   
                */
                inv_move_order_pub.create_move_order_lines( 
                         p_api_version_number   => c_api_version
                      ,  p_init_msg_list        => l_init_msg_list
                      ,  p_return_values        => l_return_values
                      ,  p_commit               => l_commit
                      ,  x_return_status        => x_return_status
                      ,  x_msg_count            => x_msg_count
                      ,  x_msg_data             => x_msg_data
                      ,  p_trolin_tbl           => l_trolin_tbl
                      ,  p_trolin_val_tbl       => l_trolin_val_tbl
                      ,  x_trolin_tbl           => x_trolin_tbl
                      ,  x_trolin_val_tbl       => x_trolin_val_tbl
                      ,  p_validation_flag      => l_validation_flag
                ); 

                IF (x_return_status = FND_API.G_RET_STS_SUCCESS) THEN
                    write_message('Move Order Lines Created Successfully for '|| x_trolin_tbl(l_row_cnt).header_id);
                    COMMIT;
                    p_move_order_number := l_trohdr_rec.request_number;

                    --write_message('x_trolin_tbl(l_row_cnt).line_id: ' || x_trolin_tbl(l_row_cnt).line_id );

                ELSE
                    write_message('create_move_order_lines x_return_status: '|| x_return_status);
                    write_message('create_move_order_lines x_msg_count: '    || x_msg_count);
                    write_message('create_move_order_lines x_msg_data: '     || x_msg_data);
                    ROLLBACK;
                END IF;
                
            ELSE
                write_message('create_move_order_header x_return_status: '|| x_return_status);
                write_message('create_move_order_header x_msg_count: '    || x_msg_count);
                write_message('create_move_order_header x_msg_data: '     || x_msg_data);
                ROLLBACK;
            END IF;
            
        ELSE
            RAISE KEY_MOVE_ORDER_ATTRIBUTE_NULL;
        END IF;
        
        IF p_move_order_number IS NOT NULL THEN
            p_err_code := c_success;
        ELSE
            p_err_code := c_fail;
            p_err_msg  := 'null move order';
        END IF;
        
        --write_message('end mo_create_disp_move_order');
        
    EXCEPTION
            WHEN KEY_MOVE_ORDER_ATTRIBUTE_NULL THEN
                p_err_code := c_fail;
                p_move_order_number := NULL;
                write_message('l_err_msg:' || 'One or more important values are null.');
                write_message('l_inventory_item_id :' || l_inventory_item_id);
                write_message('l_from_subinv_code :' || l_from_subinv_code);
                write_message('l_uom_code :' || l_uom_code);
                write_message('l_request_number :' || l_request_number);
                write_message('l_account_id :' || l_account_id);
                write_message('l_to_subinv_code :' || l_to_subinv_code);
                           
            WHEN INVALID_LOCATOR THEN
                p_err_code := c_fail;
                write_message('A locator id can''t be found for locator ' || l_to_locator);
                
            WHEN OTHERS THEN
                p_err_code := c_fail;
                write_message('Exception Occured in mo_create_disp_move_order:');
                write_message(SQLCODE ||':'||SQLERRM);
        
    END mo_create_disp_move_order;

    ----------------------------------------------------------------------------------------------------
    --  Name:               inv_cancel_move_order
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      01-Apr-2020 
    --  Purpose:            Cancel all move orders, lines, and allocations
    --  Description:        Either the Move Order Number (request number) and/or the header_id can be
    --                      passed to this procedure.  All allocations associated with the
    --                      move order lines will be deleted so that the move order lines and
    --                      move order header can be cancelled.
    --
    --                      There is at least one known situation that will prevent the move order
    --                      from being Canceled.  That is when one of the lines is partially-
    --                      transacted.  There is not a message returned by the API to indicate
    --                      that this specifically was the reason the call failed, however.
    --                      
    --  Parameters :
    --       Name             Type    Purpose
    --       --------         ----    -----------
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date            Name            Desc
    --  1.0   01-Apr-2020     Hubert, Eric    CHG0047103: initial build
    ----------------------------------------------------------------------------------------------------
    PROCEDURE inv_cancel_move_order (
        p_request_number IN OUT  mtl_txn_request_headers.request_number%TYPE
        ,p_header_id     IN OUT  NUMBER
        ,p_org_id        IN      NUMBER
        ,p_err_code      OUT     NUMBER
        ,p_err_msg       OUT     VARCHAR2
    )
    IS
        c_method_name CONSTANT VARCHAR(30) := 'inv_cancel_move_order';
        
        /* Local Constants */
        c_api_version        CONSTANT NUMBER := 1.0;

        /* Local variables for move order data structures */
        l_trohdr_rec         inv_move_order_pub.trohdr_rec_type; --Record of move order header
        l_trolin_tbl         inv_move_order_pub.trolin_tbl_type; --Table of move order lines
        l_trolin_old_tbl     inv_move_order_pub.trolin_tbl_type; --Table of move order lines
        x_trolin_tbl         inv_move_order_pub.trolin_tbl_type; --Table of move order lines
        l_mmtt_tbl           inv_mo_line_detail_util.g_mmtt_tbl_type; --Table of allocation records        
     
        /* Local variables for information returned from API calls */
        x_return_status      VARCHAR2(10);
        x_msg_count          NUMBER := 0;
        x_msg_data           VARCHAR2 (255);
        x_message_list       error_handler.error_tbl_type;
        
        /* Other local variables */
        l_allocation_deleted_flag BOOLEAN := FALSE;
        
        /* Exceptions*/
        MO_ALREADY_CANCELLED            EXCEPTION;
        MO_ALLOCATION_NOT_DELETED       EXCEPTION;
        MO_LINE_UPDATE_UNSUCCESSFULL    EXCEPTION;
        MO_NOT_CANCELLED                EXCEPTION;
        
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('program unit: ' || gv_log_program_unit);
        
        /* Get the header_id and request_number (Move Order #) from the move order number. 
           If more than one row is returned than that means a header_id and request_number
           for two different move orders were passed and we should want/expect an error to
           occur.
        */
        SELECT header_id
        INTO p_header_id
        FROM mtl_txn_request_headers
        WHERE
            (
            request_number = p_request_number
            OR
            header_id = p_header_id
            )
            AND organization_id = p_org_id;

        l_trohdr_rec := inv_trohdr_util.query_row(p_header_id => p_header_id);

        /* Return values*/
        p_request_number := l_trohdr_rec.request_number;
        p_header_id      := l_trohdr_rec.header_id; --return the header id
        
        /* Check if the Move Order is already cancelled*/
        IF l_trohdr_rec.header_status = 6 THEN --6: Canceled
            RAISE MO_ALREADY_CANCELLED;
        END IF;

        write_message('l_request_number: ' || l_trohdr_rec.request_number);
        write_message('l_trohdr_rec.header_id: ' || l_trohdr_rec.header_id);

        /* Get a table of all the move order lines for the move order header. */
        l_trolin_tbl := inv_trolin_util.get_lines(l_trohdr_rec.header_id);
        
        /* Loop through each line for the move order */
        FOR i in 1..l_trolin_tbl.count LOOP
            write_message('line_number: ' || l_trolin_tbl(i).line_number);
            write_message('line_id: ' || l_trolin_tbl(i).line_id);
        
            /* Get a table of all the allocations for the move order line. 
               There may not be any allocations which is fine.
            */
            l_mmtt_tbl := inv_mo_line_detail_util.query_rows(
                p_line_id         => l_trolin_tbl(i).line_id
                ,p_line_detail_id => NULL
            );
        
            /* Loop through each allocation. */
            FOR j in 1..l_mmtt_tbl.count LOOP
                write_message('transaction_temp_id: ' || l_mmtt_tbl(j).transaction_temp_id);

                x_return_status  := NULL;
                x_msg_count      := NULL;
                x_msg_data       := NULL;

                /* Delete the allocation. */
                inv_replenish_detail_pub.delete_details(
                    p_transaction_temp_id   => l_mmtt_tbl(j).transaction_temp_id, 
                    p_move_order_line_id    => l_trolin_tbl(i).line_id,
                    p_reservation_id        => NULL,
                    p_transaction_quantity  => NULL,
                    p_transaction_quantity2 => NULL,
                    p_primary_trx_qty       => NULL,
                    x_return_status         => x_return_status,
                    x_msg_count             => x_msg_count,
                    x_msg_data              => x_msg_data,
                    p_delete_temp_records   => TRUE
                );
                
                /* Check the result of the allocation deletion attempt. */
                IF x_return_status = 'S' then
                    l_allocation_deleted_flag := TRUE;
                    COMMIT; --need to commit the update to the move order line
                    write_message('Allocation deleted.  transaction_temp_id: ' || l_mmtt_tbl(j).transaction_temp_id);
                ELSE
                    ROLLBACK;
                    write_message('Allocation not deleted.  transaction_temp_id: ' || l_mmtt_tbl(j).transaction_temp_id);
                    RAISE MO_ALLOCATION_NOT_DELETED;
                END IF;
                
            END LOOP;

            --------------------------------------------------------------------
            -------- Oracle-endorsed workaround for Oracle Bug 4506481 ---------
            --------------------------------------------------------------------
            /* Check if there were any allocations deleted. */
            IF l_allocation_deleted_flag THEN
                /* Update the move order line to reduce the detailed quantity. */
                l_trolin_old_tbl(i)               := l_trolin_tbl(i);
                l_trolin_tbl(i).operation         := INV_GLOBALS.G_OPR_UPDATE;
                l_trolin_tbl(i).quantity_detailed := 0; --Set the allocated quantity to zero

                x_return_status  := NULL;
                x_msg_count      := NULL;
                x_msg_data       := NULL;

                /* Process the update to the move order line. */
                inv_move_order_pub.process_move_order_line(
                     p_api_version_number => c_api_version
                    ,p_init_msg_list      => FND_API.G_TRUE 
                    ,p_return_values      => FND_API.G_FALSE
                    ,p_commit             => FND_API.G_FALSE
                    ,x_return_status      => x_return_status 
                    ,x_msg_count          => x_msg_count 
                    ,x_msg_data           => x_msg_data 
                    ,p_trolin_tbl         => l_trolin_tbl
                    ,p_trolin_old_tbl     => l_trolin_old_tbl
                    ,x_trolin_tbl         => x_trolin_tbl
                );
                
                /* Check the result of processing the move order line. */
                IF x_return_status = 'S' then
                    COMMIT; --need to commit the update to the move order line
                    write_message('Move Order Line processed successfully after allocations deleted for MO Line #: ' || l_trolin_tbl(i).line_number);
                ELSE
                    ROLLBACK;
                    RAISE MO_LINE_UPDATE_UNSUCCESSFULL;
                    write_message('Move Order Line not processed after allocations deleted for MO Line #: ' || l_trolin_tbl(i).line_number);
                END IF;
            
            ELSE
                write_message('Move Order Line processing not required for MO Line #: ' || l_trolin_tbl(i).line_number);
            END IF;
            --------------------------------------------------------------------
            -------- End of workaround for Oracle Bug 4506481 ------------------
            --------------------------------------------------------------------            
            
        END LOOP;
        
        x_return_status  := NULL;
        x_msg_count      := NULL;
        x_msg_data       := NULL;

        /* Cancel the Move Order.  The child line(s) should also be cancelled. 
          -Partially-transacted move orders can not Cancelled (a "U" status is returned), but they can be Closed.
           No attempt is made to close them here.        
        */
        inv_mo_admin_pub.cancel_order(
            p_api_version      => c_api_version,
            p_init_msg_list    => FND_API.G_FALSE,
            p_commit           => FND_API.G_FALSE,
            p_validation_level => FND_API.G_VALID_LEVEL_FULL,
            p_header_Id        => l_trohdr_rec.header_id,
            x_return_status    => x_return_status,
            x_msg_count        => x_msg_count,
            x_msg_data         => x_msg_data
        );

        write_message('x_return_status: ' || x_return_status);

        /* Report errors cancelling the move order. */
        error_handler.get_message_list(x_message_list => x_message_list);
        write_message('x_msg_data: ' || x_msg_data);
        
        IF (x_return_status != FND_API.G_RET_STS_SUCCESS) THEN
            write_message('Move Order not cancelled.  MO#: ' || l_trohdr_rec.request_number);
            RAISE MO_NOT_CANCELLED;
        ELSE
            COMMIT;
            
            p_err_msg := ('Move Order Number "' || l_trohdr_rec.request_number || '" has been cancelled.');
            
            write_message('Move Order cancelled.  MO#: ' || l_trohdr_rec.request_number);
        END IF;

        p_err_code := c_success;
        
    EXCEPTION
        WHEN MO_ALREADY_CANCELLED THEN
            p_err_code := c_success; --No problem, just let the calling procedure know via p_err_msg.s
            p_err_msg := 'EXCEPTION (inv_cancel_move_order): Move Order "' || l_trohdr_rec.request_number ||  '" is already cancelled.';
            write_message('p_err_msg: ' || p_err_msg);  
        
        WHEN MO_LINE_UPDATE_UNSUCCESSFULL THEN
            p_err_code := c_fail;
            p_err_msg := 'EXCEPTION (inv_cancel_move_order): A line for Move Order "' || l_trohdr_rec.request_number ||  '" was not processed after allocations deleted.';
            write_message('p_err_msg: ' || p_err_msg);
        
        WHEN MO_ALLOCATION_NOT_DELETED THEN
            p_err_code := c_fail;
            p_err_msg :='EXCEPTION (inv_cancel_move_order): An allocation could not be deleted for Move Order "' || l_trohdr_rec.request_number ||  '".';
            write_message('p_err_msg: ' || p_err_msg);
        
        WHEN MO_NOT_CANCELLED THEN
            p_err_code := c_fail;
            
            IF x_msg_count IS NOT NULL THEN
                FOR i IN 1..x_msg_count LOOP
                    
                    write_message('i = ' || i);
                    
                    --write_message(x_message_list(i).message_text);
                    --p_err_msg := p_err_msg || x_message_list(i).message_text;
                END LOOP;

                FOR i IN 1..x_message_list.COUNT LOOP
                    write_message('Entity Id    : '|| x_message_list(i).entity_id);
                    write_message('Index        : '|| x_message_list(i).entity_index);
                    write_message('Message Type : '|| x_message_list(i).message_type);
                    write_message('Mesg         : '|| SUBSTR(x_message_list(i).message_text,1,500));
                    write_message('-------------------------------------------------------------------');
                END LOOP;
            END IF;
        
            ROLLBACK; --IS THIS NEEDED? 2/6/20: doesn't seem to cause issues. 
            p_err_msg := 'EXCEPTION (inv_cancel_move_order): Move Order "' || l_trohdr_rec.request_number ||  '" could not be cancelled.';  
            write_message('p_err_msg: ' || p_err_msg); 
        
        WHEN TOO_MANY_ROWS THEN
            p_err_code := c_fail;
            p_err_msg := 'EXCEPTION (inv_cancel_move_order): p_header_id is for different record than p_request_number: ' || p_header_id || ', ' || p_request_number;
            write_message('p_err_msg: ' || p_err_msg);
        
        WHEN OTHERS THEN
            p_err_code := c_fail;
            p_err_msg := 'EXCEPTION (inv_cancel_move_order): ' || SQLERRM;
            write_message('p_err_msg: ' || p_err_msg);
    END inv_cancel_move_order;

    ----------------------------------------------------------------------------------------------------
    --  Name:               mo_cancel_disp_move_orders
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      01-Apr-2020
    --  Purpose:            Cancel all move orders, lines, and allocations associated with a disposition
    --                      
    --  Parameters :
    --       Name             Type    Purpose
    --       --------         ----    -----------
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date            Name            Desc
    --  1.0   01-Apr-2020     Hubert, Eric    CHG0047103: initial build
    ----------------------------------------------------------------------------------------------------
    PROCEDURE mo_cancel_disp_move_orders (
        p_disposition_number   IN qa_results.sequence7%TYPE
        ,p_org_id              IN NUMBER
        ,p_err_code            OUT NUMBER
        ,p_err_msg             OUT VARCHAR2
    )
    IS
        c_method_name CONSTANT VARCHAR(30) := 'mo_cancel_disp_move_orders';
        
        /* Cursor returns unique move order header ids that have a child line 
           with disposition number in their reference field.
           
           Per Oracle, the status of the move order header is not guaranteed to change to reflect what happens to its lines.
           Therefore, we need to exclude move orders for which all of its lines are are Closed/Cancelled.
        */
        CURSOR cur_mo(
            p_reference mtl_txn_request_lines.reference%TYPE
            ,p_org_id   NUMBER
        )
        IS (
            SELECT 
                mtrh.header_id
                ,mtrh.request_number
                ,COUNT(*) row_count
            FROM mtl_txn_request_headers mtrh
            INNER JOIN mtl_txn_request_lines mtrl ON (mtrl.header_id = mtrh.header_id)
            WHERE 1=1
                AND mtrl.reference = p_reference
                AND mtrh.organization_id = p_org_id
                AND mtrl.line_status NOT IN ( --Exclude move order lines that are already cancelled or closed
                    6  --Canceled
                    ,9 --Canceled by Source
                    ,5 --Closed
                )
            GROUP BY
                mtrh.header_id
                ,mtrh.request_number
            HAVING COUNT(*) >= 1 --Count of "open" lines for the move order 
        ) ORDER BY header_id;
        
        l_header_id                 mtl_txn_request_headers.header_id%TYPE;
        l_request_number            mtl_txn_request_headers.request_number%TYPE;
        l_row_count                 NUMBER;
        l_success_count             NUMBER := 0;
        l_fail_count                NUMBER := 0;
        l_mo_list_success           VARCHAR2(1000);
        l_mo_list_fail              VARCHAR2(1000);
        l_delimiter                 VARCHAR2(1);
        l_err_code                  NUMBER;
        l_err_msg                   VARCHAR2(1000);

    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('program unit: ' || gv_log_program_unit);

        p_err_code := c_success;
        p_err_msg  := NULL;
  
        OPEN cur_mo(
            p_reference => p_disposition_number
            ,p_org_id   => p_org_id);

            /* loop through each move order header */
            LOOP
                FETCH cur_mo INTO
                    l_header_id --move order "ID"
                    ,l_request_number --Move Order Number
                    ,l_row_count
                ;
                EXIT WHEN cur_mo%NOTFOUND;
                write_message('l_header_id: ' || l_header_id);
                write_message('l_request_number: ' || l_request_number);
                
                /* cancel the move order */
                inv_cancel_move_order(
                    p_request_number       => l_request_number
                    ,p_header_id           => l_header_id
                    ,p_org_id              => p_org_id
                    ,p_err_code            => l_err_code
                    ,p_err_msg             => l_err_msg           
                );

                --write_message('l_err_code (inv_cancel_move_order): ' || l_err_code);
                --write_message('l_err_msg (inv_cancel_move_order): ' || l_err_msg);

                /* Build a messages based on the result of the cancelation attempt. */
                IF l_err_code = c_success THEN
                    l_success_count := l_success_count + 1;
                    
                    /* Add a delimiter if there are multiple values. */
                    IF l_success_count > 1 THEN
                        l_delimiter := c_delimiter;
                    ELSE
                        l_delimiter := NULL;
                    END IF;
                    
                    l_mo_list_success := SUBSTR(l_mo_list_success || l_delimiter || ' ' || l_request_number, 1, 1000);
                
                ELSE
                    l_fail_count    := l_fail_count + 1;

                    /* Add a delimiter if there are multiple values. */
                    IF l_fail_count > 1 THEN
                        l_delimiter := c_delimiter;
                    ELSE
                        l_delimiter := NULL;
                    END IF;

                    l_mo_list_fail    := SUBSTR(l_mo_list_fail    || l_delimiter || ' ' || l_request_number, 1, 1000);
                END IF;
            END LOOP;

        CLOSE cur_mo;

		/* Build a message summarizing the results of the cancellation(s). */
        l_mo_list_success := SUBSTR('Move Orders Cancelled ('     || l_success_count || '): ' || l_mo_list_success, 1, 1000);
        l_mo_list_fail    := SUBSTR('Move Orders NOT Cancelled (' || l_fail_count    || '): ' || l_mo_list_fail,    1, 1000);

        write_message('l_mo_list_success: ' || l_mo_list_success);
        write_message('l_mo_list_fail: ' || l_mo_list_fail);
        
        l_err_msg  := NULL;

        IF l_success_count > 0  THEN
            l_err_msg  := l_mo_list_success;
        END IF;

        IF l_fail_count > 0  THEN
            p_err_code := c_fail;
            l_err_msg  := l_err_msg || CHR(10) || l_mo_list_fail;
        END IF;

        /* Return values to the calling procedure. */
        p_err_msg  := l_err_msg;

        --write_message('p_err_code: ' || p_err_code);
        --write_message('p_err_msg: ' || p_err_msg);
        --write_message('end of mo_cancel_disp_move_orders');
    EXCEPTION WHEN OTHERS THEN
        p_err_code  := c_fail;
        p_err_msg := 'Exception in ' || c_method_name || ': ' || SQLERRM ;
        write_message(p_err_msg);
    END mo_cancel_disp_move_orders;
    
    ----------------------------------------------------------------------------------------------------
    --  Name:               mo_disposition_mgr_wrapper
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      01-Apr-2020
    --  Purpose:            Wrapper procedure used to call private procedure, mo_disposition_manager_main, from a concurrent
    --                      program.  Move orders are created for Scrap and Use As-Is dispositions after the disposition
    --                      reaches an APPROVED status.  
    --
    --  Description:        This wrapper procedure will optionally limit the dispositions  rocessed in mo_disposition_manager_main based upon a Nonconformance, Verification,
    --                      or disposition number passed by the concurrent request.
    --           
    --                      Called by program XXQA_CREATE_DISP_MOVE_ORDERS
    --  Parameters :
    --       Name                 Type    Purpose
    --       --------             ----    -----------

    ----------------------------------------------------------------------------------------------------
    --  Ver   Date            Name            Desc
    --  1.1   01-Apr-2020     Hubert, Eric    CHG0047103: initial release (Scrap is the only Disposition that currently requires approval.)
    --  2.0   01-Apr-2021     Hubert, Eric    CHG0049611: -refactored to pass additional paramaters to nonconformance_report_data without "dynamic where clause" variables.
    ----------------------------------------------------------------------------------------------------
    PROCEDURE mo_disposition_mgr_wrapper(
                                    errbuf                          OUT VARCHAR2,
                                    retcode                         OUT VARCHAR2,
                                    p_organization_id               IN NUMBER, --Required
                                    p_disposition                   IN VARCHAR2 DEFAULT NULL,
                                    p_nonconformance_number         IN VARCHAR2 DEFAULT NULL,
                                    p_verify_nonconformance_number  IN VARCHAR2 DEFAULT NULL,
                                    p_disposition_number            IN VARCHAR2 DEFAULT NULL
                                    ) 
    IS

        /* Local Constants */
        c_method_name CONSTANT VARCHAR(30) := 'mo_disposition_mgr_wrapper';

        /* Local Variables */
        l_disposition_status    qa_results.character1%TYPE;
  
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('program unit: ' || gv_log_program_unit);
        
        retcode := 0; --Success (Green)

        /* Set public variables based on the concurrent request parameters. */
        xxqa_nonconformance_util_pkg.p_organization_id              := p_organization_id;
        xxqa_nonconformance_util_pkg.p_nonconformance_number        := p_nonconformance_number;
        xxqa_nonconformance_util_pkg.p_verify_nonconformance_number := p_verify_nonconformance_number;
        xxqa_nonconformance_util_pkg.p_disposition_number           := p_disposition_number;                

        /* Write nc rows into package variable which will later be used by a SQL statement in the the data template. */
        gv_nc_rpt_tab := xxqa_nonconformance_util_pkg.nonconformance_report_data (
                    p_sequence_1_value    => p_nonconformance_number
                    ,p_sequence_2_value   => p_verify_nonconformance_number
                    ,p_sequence_3_value   => p_disposition_number
                    ,p_organization_id    => p_organization_id
                    ,p_occurrence         => NULL
                    ,p_nc_active_flag     => c_yes
                    ,p_disp_active_flag   => c_yes
                    ,p_disposition_status => c_d_status_app
                    ,p_disposition        => p_disposition
            );
        --write_message('gv_nc_rpt_tab.COUNT: ' || gv_nc_rpt_tab.COUNT);        
        
        IF gv_nc_rpt_tab.COUNT > 0 THEN
            /* Call the Disposition Workflow Manager */
            mo_disposition_manager_main;
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            retcode := 2; --Error (Red)
            errbuf  := 'Error in xxqa_nonconformance_util_pkg.mo_disposition_manager_main ' || SQLERRM;
    
        write_message('errbuf: ' || errbuf);
    END mo_disposition_mgr_wrapper;
            
    ----------------------------------------------------------------------------------------------------
    -- END PUBLIC PROCEDURES
    ----------------------------------------------------------------------------------------------------
    
    ----------------------------------------------------------------------------------------------------
    -- BEGIN PRIVATE FUNCTIONS
    ----------------------------------------------------------------------------------------------------
    ----------------------------------------------------------------------------------------------------
    --  Name:               eval_disp_status_criteria
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      16-Oct-2019
    --  Purpose:            Determine if the critera are satisfied for a Disposition
    --                      to progress to the next status.
    --
    --  Description: If the provided SQL statement parameter return at least one row
    --    then the function will return TRUE.  If no rows are returned, FALSE.  
    --
    --    To minimize the chance of SQL injection, the following measures are taken:
    --    1) val_disp_status_criteria is defined as a function, as opposed to a procedure, since DML, DDL or Oracle database functions can't be executed in a function without the AUTONOMOUS_TRANSACTION pragma (which we are NOT using here).
    --    2) Bind variables are used when exeuting l_dynamic_sql
    --    3) the incoming statement is "wrapped" in a Select statement.
    --    4) Only the APPLICATIONS_OPERATIONS Quality Security Group has the ability to maintain the SQL (stored in the DISPOSITION_STATUSES_OMA Collection Plan).
    --
    --  Inputs:
    --    p_disposition_number: Disposition Number from DISPOSITION_xxx Collection Plan
    --    p_criteria_sql_statement: value of XX_DISPOSITION_STATUS_CRITERIA from DISPOSITION_STATUSES_OMA Collection Plan
    --
    --  Outputs:
    --    BOOLEAN: True - criteria are satisfied | False - criteria are not satisfied
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   16-Oct-2019   Hubert, Eric    CHG0042815 - Initial release
    ----------------------------------------------------------------------------------------------------
    FUNCTION eval_disp_status_criteria(
        p_organization_id         IN NUMBER
        ,p_disposition_number     IN qa_results.sequence7%TYPE
        ,p_criteria_sql_statement IN VARCHAR2
    ) RETURN BOOLEAN IS
        c_method_name CONSTANT VARCHAR(30) := 'eval_disp_status_criteria';
        
        /* Constants*/
        c_sql_wrapper_prefix CONSTANT VARCHAR2(100) := 'SELECT COUNT(*) FROM ('; --
        c_sql_wrapper_suffix CONSTANT VARCHAR2(100) := CHR(10) || ')'; --Line feed is to force a new row if comments are at the end of the sql
        
        /* Local Variables*/
        l_dynamic_sql   VARCHAR2(2200); --sized to fit qa_results comments columns plus c_sql_wrapper_prefix/c_sql_wrapper_suffix
        l_rows_returned NUMBER := 0;
        l_result        BOOLEAN;
    
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        --write_message('program unit: ' || gv_log_program_unit);
        
        IF p_criteria_sql_statement IS NOT NULL THEN
            --write_message('p_criteria_sql_statement: ' || p_criteria_sql_statement);
            write_message('p_organization_id: ' || p_organization_id);
            write_message('p_disposition_number: ' || p_disposition_number);
            
            /* Build SQL statement */
            l_dynamic_sql := c_sql_wrapper_prefix || p_criteria_sql_statement || c_sql_wrapper_suffix;
            --write_message('l_dynamic_sql: ' || l_dynamic_sql);
   
            /* The SQL statement in a DISPOSITION_STATUSES_OMA collection result record to be evaluated here
               needs to be defined with a bind variables for Organization ID (":org_id") and Disposition Number (":disposition_number").
            */
            EXECUTE IMMEDIATE l_dynamic_sql 
            INTO l_rows_returned
            USING p_organization_id, p_disposition_number
            ;
            
            write_message('l_rows_returned: ' || l_rows_returned);
        
        END IF;
        
        /* If at least one row is returned by the query, or no criteria was specified, then the criteria is considered satisfied. */
        IF l_rows_returned >= 1 OR p_criteria_sql_statement IS NULL THEN
            l_result := TRUE;
        ELSE
            l_result := FALSE;
        END IF;
        
        RETURN l_result;
        
    /* Exception handling */
    EXCEPTION
        WHEN OTHERS THEN
            write_message('Exception in ' || c_method_name || ': ' || SQLERRM );
            RETURN(FALSE);
    END eval_disp_status_criteria;

    ----------------------------------------------------------------------------------------------------
    --  Name:               qa_result_row_via_occurrence
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      16-Oct-2019 
    --  Purpose:            Return an entire qa_results row for the provided occurrence.
    --
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   16-Oct-2019   Hubert, Eric    CHG0042815
    ----------------------------------------------------------------------------------------------------
    FUNCTION qa_result_row_via_occurrence(p_occurrence IN qa_results.occurrence%TYPE)
        RETURN qa_results%ROWTYPE IS
        
        c_method_name CONSTANT VARCHAR(30) := 'qa_result_row_via_occurrence';
        
        l_qa_results_row qa_results%ROWTYPE;
        
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('program unit: ' || gv_log_program_unit);

        SELECT * INTO l_qa_results_row
        FROM qa_results
        WHERE occurrence = p_occurrence;
        
        RETURN l_qa_results_row;
        
    EXCEPTION
        WHEN OTHERS THEN
        write_message('Exception in ' || c_method_name || ': ' || SQLERRM );

        /* Return*/
        RETURN NULL; --Returning NULL as place holder for more targeted exception handling, if required by Stratasys coding standards.
    END qa_result_row_via_occurrence;

    ----------------------------------------------------------------------------------------------------
    --  Name:               delimited_list_to_rows
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      16-Oct-2019
    --  Purpose:            For a string of delimited values, return a REF CURSOR.
    --
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   16-Oct-2019   Hubert, Eric    CHG0042815    
    FUNCTION delimited_list_to_rows(--CHG0042815
        p_delimited_string IN VARCHAR2
        ,p_delimiter IN VARCHAR2
        ) RETURN SYS_REFCURSOR
        
        IS
        
        c_method_name CONSTANT VARCHAR(30) := 'delimited_list_to_rows';
        
        l_refcur      SYS_REFCURSOR;
        l_element     VARCHAR2(254);
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        --write_message('program unit: ' || gv_log_program_unit); 

       OPEN l_refcur FOR
            /* SQL below takes a delimited string and returns one row for each element in the string. Duplicates are not returned.
                   Design note: Several different methods are available to split a delimited string into rows.  I chose
                   this XML-based approach over others because it appeared less complex, including
                   those that use regular expressions or loops.*/
            Q'[
            SELECT DISTINCT list_element
            FROM
            (SELECT
                DENSE_RANK() OVER (
                    PARTITION BY :a ORDER BY ROWNUM
                    ) AS seq
                ,TRIM(x.column_value.extract('e/text()')) AS list_element
            FROM dual
            JOIN TABLE (xmlsequence(xmltype('<e><e>' || REPLACE(:b, :c, '</e><e>') || '</e></e>').EXTRACT('e/e'))) x ON (1 = 1))
            WHERE list_element IS NOT NULL
            ORDER BY list_element]'
            USING
                p_delimited_string --a
                , p_delimited_string --b
                , p_delimiter --c
            ;
        
        RETURN l_refcur;

    END delimited_list_to_rows;

    ----------------------------------------------------------------------------------------------------
    --  Name:               get_notification_group_email
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      16-Oct-2019
    --  Purpose:            For a given quality email group name, return the individual
    --                      email addresses.  These email groups are maintained in a
    --                      collection plan in the OMA org.
    --
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   16-Oct-2019   Hubert, Eric    CHG0042815   
    FUNCTION get_notification_group_email(p_email_group_name IN VARCHAR2) --CHG0042815
    RETURN VARCHAR2
    AS
        c_method_name CONSTANT VARCHAR(30) := 'get_notification_group_email';
        
        l_result qa_results.character1%TYPE;
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('program unit: ' || gv_log_program_unit);
        --write_message('p_email_group_name: ' || p_email_group_name);
        
        SELECT xx_email_addresses
        INTO l_result
        FROM q_email_notification_groups__v  --Collection plan (OMA) where we store group and individual email addresses 
        WHERE xx_email_group_name = p_email_group_name
        AND xx_enabled_flag = c_yes;

        RETURN l_result;
        
    /* Exception handling */
    EXCEPTION
        WHEN TOO_MANY_ROWS THEN
            write_message('Exception: TOO_MANY_ROWS in ' || c_method_name);
            RETURN NULL;
        WHEN NO_DATA_FOUND THEN
            write_message('Exception: NO_DATA_FOUND in ' || c_method_name);
            RETURN NULL;
        WHEN OTHERS THEN
            write_message('Exception in ' || c_method_name || ': ' || SQLERRM );
            RETURN NULL;
    END get_notification_group_email;

    ----------------------------------------------------------------------------------------------------
    --  Name:               wf_get_doc_instance_row
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      24-Oct-2019
    --  Purpose:            Get a specific doc approval instance row
    --                               
    --  Description: 
    --
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   24-Oct-2019   Hubert, Eric    CHG0046276: initial build
    ----------------------------------------------------------------------------------------------------
    FUNCTION wf_get_doc_instance_row (
        p_doc_instance_id   NUMBER) RETURN xxobjt_wf_doc_instance%ROWTYPE
    IS
        c_method_name CONSTANT VARCHAR(30) := 'wf_get_doc_instance_row';
        
        l_wdi_rec   xxobjt_wf_doc_instance%ROWTYPE;
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        --write_message('program unit: ' || gv_log_program_unit);
        
        /* Get the the workflow instance record. */
        SELECT * 
        INTO l_wdi_rec
        FROM xxobjt_wf_doc_instance
        WHERE doc_instance_id = p_doc_instance_id;
        
        RETURN l_wdi_rec;
        EXCEPTION
            WHEN OTHERS THEN
                RETURN NULL;
    END wf_get_doc_instance_row;

    ----------------------------------------------------------------------------------------------------
    --  Name:               move_output_file
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      24-Oct-2019
    --  Purpose:            Moves the report output file from Standard Oracle Directory to a shared directory
    --                               
    --  Description: 
    --
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   24-Oct-2019   Hubert, Eric    CHG0046276: initial build (adapted from Sandeep Akula's work on CHG0033620)
    ----------------------------------------------------------------------------------------------------
    FUNCTION move_output_file(p_file_name IN VARCHAR2) RETURN VARCHAR2 IS
        c_method_name CONSTANT VARCHAR(30) := 'move_output_file';
        
        c_directory_name_source CONSTANT VARCHAR2(100) := 'XXFND_OUT_DIR';--
        c_max_wait          CONSTANT NUMBER := 3600; --Max amount of time to wait (in seconds) for request's completion
        
        l_error_message    VARCHAR2(2000);
        l_dest_directory   VARCHAR2(1000);
        l_source_directory VARCHAR2(1000);
        l_request_id       NUMBER;
        l_prg_exe_counter  VARCHAR2(10);
        l_completed        BOOLEAN;
        l_phase            VARCHAR2(200);
        l_vstatus          VARCHAR2(200);
        l_dev_phase        VARCHAR2(200);
        l_dev_status       VARCHAR2(200);
        l_message          VARCHAR2(200);
        l_status_code      VARCHAR2(1);
        l_interval         NUMBER := fnd_profile.value('XX: QA Concurrent Request Wait Interval'); --Number of seconds to wait between checks.
        move_submit_excp   EXCEPTION;
        move_error         EXCEPTION;
        move_warning       EXCEPTION;

    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('program unit: ' || gv_log_program_unit);

        l_error_message   := 'Error Occured while deriving Source Directory';
        SELECT directory_path
        INTO   l_source_directory
        FROM   all_directories
        WHERE  directory_name IN (c_directory_name_source);

        l_error_message   := 'Error Occured while deriving Destination Directory';
        SELECT directory_path
        INTO   l_dest_directory
        FROM   all_directories
        WHERE  directory_name IN (c_directory_qa_wf);

        l_error_message := 'Error Occured while Calling the Move Host Program';
        l_request_id    := fnd_request.submit_request(
            application => c_asn_xxobjt,
            program     => c_psn_cfl, --XXCPFILE (XX: Copy File)
            argument1   => l_source_directory, -- from_dir
            argument2   => p_file_name, -- from_file_name
            argument3   => l_dest_directory, -- to_dir
            argument4   => p_file_name -- to_file_name
            );
        COMMIT;

        IF l_request_id = 0 THEN
            l_error_message   := 'Move Program Could not be submitted.' ||
               ' Error Message :' || l_error_message;
            RAISE move_submit_excp;

        ELSE
            apps.fnd_file.put_line(apps.fnd_file.log,
                 'Submitted the Move concurrent program with request_id :' ||
                 l_request_id);
        END IF;

        /* Wait for the completion of the concurrent request (if submitted successfully) */
        l_error_message := 'Error Occured while Waiting for the completion of the Move concurrent request';
        l_completed     := apps.fnd_concurrent.wait_for_request(
            request_id => l_request_id,
            interval   => fnd_profile.value('XX: QA Concurrent Request Wait Interval'),  --IN  number default 60,
            max_wait   => c_max_wait,
            phase      => l_phase,
            status     => l_vstatus,
            dev_phase  => l_dev_phase,
            dev_status => l_dev_status,
            message    => l_message);

        /* Check for the Concurrent Program status */
        l_error_message := 'Error Occured while deriving the status code of the submitted program';
        SELECT status_code
        INTO   l_status_code
        FROM   fnd_concurrent_requests
        WHERE  request_id = l_request_id;

        IF l_status_code = 'E' THEN-- Error      
            l_error_message   := 'Move Program Request with Request ID :' ||
               l_request_id || ' completed in Error';
            RAISE move_error;

        ELSIF l_status_code = 'G' THEN-- Warning
            l_error_message   := 'Move Program Request with Request ID :' ||
               l_request_id || ' completed in Warning';
            RAISE move_warning;

        ELSIF l_status_code = 'C' THEN-- Success
            fnd_file.put_line(fnd_file.log, 'Move Program Completed Sucessfully');
            l_error_message := NULL;
        END IF;

        RETURN(l_error_message);

    EXCEPTION
        WHEN move_submit_excp THEN
            RETURN(l_error_message);
        WHEN move_error THEN
            RETURN(l_error_message);
        WHEN move_warning THEN
            RETURN(l_error_message);
        WHEN OTHERS THEN
            RETURN(l_error_message || '-' || l_prg_exe_counter || '-' || SQLERRM);
    END move_output_file;  

    ----------------------------------------------------------------------------------------------------
    --  Name:               build_disposition_wf_message
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      24-Oct-2019
    --  Purpose:            Build a message reporting on status/activity of a Doc Approval workflow instance.
    --                               
    --  Description:        
    --
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   24-Oct-2019   Hubert, Eric    CHG0046276: initial build
    ----------------------------------------------------------------------------------------------------
    FUNCTION build_disposition_wf_message(
        p_disposition_number IN qa_results.sequence7%TYPE
        ,p_event_name        IN VARCHAR2 DEFAULT NULL
        ,p_note              IN VARCHAR2 DEFAULT NULL) --CHG0046276
    RETURN qa_results.character1%TYPE
    IS
        c_method_name CONSTANT VARCHAR(30) := 'build_disposition_wf_message';
        
        l_open_doc_count        NUMBER;
        l_doc_instance_id       NUMBER;
        l_wdi_rec               xxobjt_wf_doc_instance%ROWTYPE;
        l_xowdhv                xxobjt_wf_doc_history_v%ROWTYPE;
        l_role_description_0    xxobjt_wf_doc_history_v.role_description%TYPE;
        l_action_desc_0         xxobjt_wf_doc_history_v.action_desc%TYPE;
        l_role_description_1    xxobjt_wf_doc_history_v.role_description%TYPE;
        l_action_desc_1         xxobjt_wf_doc_history_v.action_desc%TYPE;
        l_result                qa_results.character1%TYPE;  
 
     BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        --write_message('program unit: ' || gv_log_program_unit);
        
        --get the doc_instance_id for the disposition (we're just concerned about Scrap approval at this point in time.)
        wf_inquire_open_doc_approvals(
                p_disposition_number => p_disposition_number
                ,p_doc_code          => c_wf_doc_code_scrap
                --CHG0047103,p_abort_flag        => FALSE --Do NOT abort any open scrap approval workflows for this disposition
                ,p_open_doc_count    => l_open_doc_count
                );

        l_wdi_rec := wf_get_last_doc_instance_row(
            p_disposition_number   => p_disposition_number
            ,p_doc_code            => c_wf_doc_code_scrap);
      
        CASE WHEN l_open_doc_count IN (0, 1) --Will be 1 while in process but 0 after approved
            AND l_wdi_rec.doc_instance_id IS NOT NULL THEN
      
            /* Next Action */
            l_xowdhv := wf_get_history_row(
                p_doc_instance_id   => l_wdi_rec.doc_instance_id
                ,p_action_offset    => 0
                );
            
            l_role_description_0 := l_xowdhv.role_description;
            l_action_desc_0      := l_xowdhv.action_desc;
            --write_message('l_wdi_rec.doc_instance_id: ' || l_wdi_rec.doc_instance_id);
            --write_message('l_role_description_0: ' || l_role_description_0);
            --write_message('l_action_desc_0: ' || l_action_desc_0);
            
            /* Previous Action */
            l_xowdhv := wf_get_history_row(
                p_doc_instance_id   => l_wdi_rec.doc_instance_id
                ,p_action_offset    => 1
                ); 

            l_role_description_1 := l_xowdhv.role_description;
            l_action_desc_1      := l_xowdhv.action_desc;
                
            l_result := 'Status=' || l_wdi_rec.doc_status; --base message

            /* Append status/event-specific details to message*/
            CASE WHEN l_wdi_rec.doc_status = c_xwds_inprocess THEN
                IF p_event_name = c_doc_before_approval THEN
                    l_result := l_result
                        || ', Prev=' || l_role_description_0
                        || ' (' || l_action_desc_0 || ')';
                ELSE
                    l_result := l_result
                        || ', Current=' || l_role_description_0
                        || ' (' || l_action_desc_0 || ')'
                        || ', Prev=' || l_role_description_1
                        || ' (' || l_action_desc_1 || ')';
                END IF;
            WHEN l_wdi_rec.doc_status = c_xwds_error THEN
                l_result := l_result
                    || ', Current=' || l_role_description_0
                    || ' (' || l_action_desc_0 || ')'
                    || ', Prev=' || l_role_description_1
                    || ' (' || l_action_desc_1 || ')';
            WHEN l_wdi_rec.doc_status IN (
                    c_xwds_cancelled
                    ,c_xwds_rejected
                ) THEN
                l_result := l_result
                    || ', Prev=' || l_role_description_0
                    || ' (' || l_action_desc_0 || ')';
            WHEN l_wdi_rec.doc_status = c_xwds_approved THEN
                l_result := l_result;
            ELSE
                l_result := 'Unknown document status: ' || l_wdi_rec.doc_status;
            END CASE;
            
        WHEN l_open_doc_count > 1 AND l_wdi_rec.doc_instance_id IS NOT NULL THEN
            l_result := 'Exception: multiple workflows open';
        ELSE
            l_result := 'Exception: no workflow found';
        END CASE;
        
        /* finish building the message */
        l_result := SUBSTR(
                l_result
                || CASE WHEN p_event_name IS NULL THEN NULL ELSE ', Event=' || p_event_name END --include the event, if provided
                || CASE WHEN p_note IS NULL THEN NULL ELSE ', Note=' || p_note END --include the note, if provided
                || ', DocID=' || l_wdi_rec.doc_instance_id
                || ', Date=' || local_datetime --current local date/time
            ,1
            ,150 --truncate to max size of qa_results CHARACTERxx fields.
        );
        RETURN l_result;

    EXCEPTION
        WHEN OTHERS THEN
        RETURN gv_log_program_unit || ': ' || SQLERRM;
    END build_disposition_wf_message;
    
    ----------------------------------------------------------------------------------------------------
    --  Name:               blob_to_clob
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      24-Oct-2019
    --  Purpose:            Converts a BLOB to a CLOB
    --                               
    --  Description:        Adapted from https://oracle-base.com/dba/miscellaneous/blob_to_clob.sql
    --
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   24-Oct-2019   Hubert, Eric    CHG0046276: initial build
    ----------------------------------------------------------------------------------------------------
    FUNCTION blob_to_clob (p_data  IN  BLOB)
      RETURN CLOB
    AS

        c_method_name CONSTANT VARCHAR(30) := 'blob_to_clob'; 

        l_clob         CLOB;
        l_dest_offset  PLS_INTEGER := 1;
        l_src_offset   PLS_INTEGER := 1;
        l_lang_context PLS_INTEGER := dbms_lob.default_lang_ctx;
        l_warning      PLS_INTEGER;
    BEGIN

        dbms_lob.createtemporary(
            lob_loc => l_clob,
            cache   => TRUE);

        dbms_lob.converttoclob(
            dest_lob      => l_clob,
            src_blob      => p_data,
            amount        => dbms_lob.lobmaxsize,
            dest_offset   => l_dest_offset,
            src_offset    => l_src_offset, 
            blob_csid     => dbms_lob.default_csid,
            lang_context  => l_lang_context,
            warning       => l_warning);

        RETURN l_clob;
    END blob_to_clob;
   
    ----------------------------------------------------------------------------------------------------
    --  Name:               wf_get_last_doc_instance_row
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      24-Oct-2019
    --  Purpose:            Get infomation about the last doc approval instance for a disposition.
    --
    --
    --  Parameters :
    --       Name             Type    Purpose
    --       --------         ----    -----------
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date            Name            Desc
    --  1.0   24-Oct-2019     Hubert, Eric    CHG0046276: initial build
    ----------------------------------------------------------------------------------------------------
    FUNCTION wf_get_last_doc_instance_row(
        p_disposition_number   IN  qa_results.sequence7%TYPE
        ,p_doc_code            IN  xxobjt_wf_docs.doc_code%TYPE
    ) RETURN xxobjt_wf_doc_instance%ROWTYPE
    IS
        c_method_name CONSTANT VARCHAR(30) := 'wf_get_last_doc_instance_row';
        
        l_xwdi_row            xxobjt_wf_doc_instance%ROWTYPE;

    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        --write_message('program unit: ' || gv_log_program_unit);

        WITH
            sq_last_id AS
            (
                /* Get doc_instance_id for most recent instance for disposition*/
                SELECT MAX(xfdi1.doc_instance_id) max_doc_instance_id
                FROM xxobjt_wf_doc_instance xfdi1
                INNER JOIN xxobjt_wf_docs xwd ON (xwd.doc_id = xfdi1.doc_id)
                WHERE
                    xwd.doc_code = p_doc_code
                    AND xfdi1.attribute4 = p_disposition_number --disposition number        
            )
        SELECT xfdi2.*
        INTO l_xwdi_row
        FROM xxobjt_wf_doc_instance xfdi2
        /* Pseudo self-join to make it easy to do a select into with the correct columns */
        INNER JOIN sq_last_id ON (xfdi2.doc_instance_id = sq_last_id.max_doc_instance_id);

        RETURN l_xwdi_row;
            
    EXCEPTION
        WHEN OTHERS THEN 
            RETURN NULL;
    END wf_get_last_doc_instance_row;
    
    ----------------------------------------------------------------------------------------------------
    --  Name:               get_delimited_email_recipients
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      01-Apr-2020
    --  Purpose:            Get a delimited string containg the emails for a specified recipient type.
    --                      The procedure, build_email_address_table, needs to be called before this 
    --                      function.
    --
    --  Parameters :
    --       Name             Type    Purpose
    --       --------         ----    -----------
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date            Name            Desc
    --  1.0   01-Apr-2020     Hubert, Eric    CHG0047103: initial build
    ----------------------------------------------------------------------------------------------------
    FUNCTION get_delimited_email_recipients(
        p_recipient_type      IN VARCHAR2
    ) RETURN VARCHAR2
    IS
        c_method_name CONSTANT VARCHAR(30) := 'get_delimited_email_recipients';
        
        l_concatenated_email_addresses VARCHAR2(255);
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('program unit: ' || gv_log_program_unit);
        write_message('p_recipient_type: ' || p_recipient_type);
                
        /* Concatenates email addresses by receipient type and nonconformance/disposition, with a delimiter. */
        SELECT
            --e_notification_type
            --,n_nonconformance_number
            --,v_verify_nc_number
            --,d_disposition_number
            --,e_recipient_type
            (LISTAGG(e_email_address, ',') WITHIN GROUP (ORDER BY e_email_address))
        INTO l_concatenated_email_addresses
        FROM TABLE (get_recipient_tab)
        WHERE e_recipient_type = p_recipient_type
        GROUP BY
                e_notification_type
                ,n_nonconformance_number
                ,v_verify_nc_number
                ,d_disposition_number
                ,e_recipient_type;
                
        RETURN l_concatenated_email_addresses;
        
    EXCEPTION --CHG0047103
        WHEN OTHERS THEN
            write_message('Exception in ' || c_method_name || ': ' || SQLERRM );

            /* Return*/
            RETURN NULL; --Returning NULL as place holder for more targeted exception handling, if required by Stratasys coding standards.
    END get_delimited_email_recipients;

    ----------------------------------------------------------------------------------------------------
    --  Name:               get_scrap_account
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      01-Apr-2020
    --  Purpose:            Get the account id to be used for issuing scrap from inventory
    --                               
    --  Description:        Account segment value is stored in an Site-level profile.  Build the
    --                      rest of the account string based on the the balancing account segment
    --                      of the Material Valuation Account parameter defined for the inventory
    --                      organization.
    --
    --                      We make assumptions that al of the other segments must be zeros.  If this
    --                      is not a reasonable assumption in the future then additional business
    --                      rules will need to be implemented.
    --
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   01-Apr-2020   Hubert, Eric    CHG0047103: initial build
    ----------------------------------------------------------------------------------------------------
    FUNCTION get_scrap_account(p_org_id IN NUMBER) RETURN NUMBER
    IS
        c_method_name CONSTANT VARCHAR(30) := 'get_scrap_account';
        
        l_code_combination_id_scrap  NUMBER;
        l_scrap_acount_segment_value fnd_profile_option_values.profile_option_value%TYPE;
    BEGIN
        /* Get the value of the third account string segment from the profile, XX: QA Scrap Account Segment Value.*/
        l_scrap_acount_segment_value := fnd_profile.value('XXQA_SCRAP_ACCOUNT_SEGMENT_VALUE');

        /* Get the scrap account ID*/
        SELECT
            --mp.organization_code
            --,mp.organization_id
            --,gccl_1.segment1 mp_company_segment
            gccl_2.code_combination_id
            --,gccl_2.segment1 company_segment
            --,gccl_2.segment3 account_segment
            --,gcck.concatenated_segments
        INTO l_code_combination_id_scrap
        FROM mtl_parameters mp
        LEFT JOIN gl_code_combinations gccl_1 ON (mp.material_account = gccl_1.code_combination_id) --Material Valuation Account for Org Paramater
        LEFT JOIN gl_code_combinations gccl_2 ON ( --Scrap Account for Inventory Org
                NVL(gccl_2.segment1, 0) = gccl_1.segment1 --Company
            AND NVL(gccl_2.segment2, 0) = 0 --Department
            AND NVL(gccl_2.segment3, 0) = l_scrap_acount_segment_value --Account
            AND NVL(gccl_2.segment4, 0) = 0 --Sub Account
            AND NVL(gccl_2.segment5, 0) = 0 --Product Line
            AND NVL(gccl_2.segment6, 0) = 0 --Location
            AND NVL(gccl_2.segment7, 0) = 0 --Intercompany
            AND NVL(gccl_2.segment8, 0) = 0 --Project
            AND NVL(gccl_2.segment9, 0) = 0 --Future2
            )
        WHERE 1=1
            AND mp.organization_id = p_org_id;
    
        RETURN l_code_combination_id_scrap;
    
    EXCEPTION
        WHEN OTHERS THEN
            RETURN NULL;
    END get_scrap_account;

    ----------------------------------------------------------------------------------------------------
    --  Name:               is_conc_request_bursted
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      01-Apr-2020
    --  Purpose:            Returns 'Y' if bursting was selected for the concurrent request.
    --                               
    --  Description:        
    --
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   01-Apr-2020   Hubert, Eric    CHG0047103: initial build
    ----------------------------------------------------------------------------------------------------
    FUNCTION is_conc_request_bursted (p_request_id IN NUMBER) RETURN VARCHAR2
    IS
        l_row_count NUMBER;
    BEGIN
        SELECT COUNT(*)
        INTO l_row_count
        FROM fnd_conc_pp_actions
        WHERE
            action_type = 8 --This is the action for bursting.
            AND concurrent_request_id = p_request_id;

        IF l_row_count > 0 THEN
            RETURN c_yes;
        ELSE
            RETURN c_no;
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            RETURN c_no;
    END is_conc_request_bursted;
    
    ----------------------------------------------------------------------------------------------------
    -- END PRIVATE FUNCTIONS
    ----------------------------------------------------------------------------------------------------

    ----------------------------------------------------------------------------------------------------
    -- BEGIN PRIVATE PROCEDURES
    ----------------------------------------------------------------------------------------------------
    
    ----------------------------------------------------------------------------------------------------
    --  Name:               write_message
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      Dec-2016
    --  Purpose:            CHG0040770 - Quality Nonconformance Report
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   Dec-2016      Hubert, Eric    S3 Initial Build
    --  1.1   08-Mar-2019   Hubert, Eric    Added ability to selectively write to log file or log table.
    --  1.2   05-Mar-2020   Hubert, Eric    CHG0047013: added local_datetime to help diagnose performance issues
    PROCEDURE write_message(p_msg VARCHAR2,
                            p_file_name VARCHAR2 DEFAULT fnd_file.log) IS
        
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
                buff  => '[' || local_datetime || '] ' || p_msg --CHG0047013: add local_datetime to help diagnose performance issues
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
            dbms_output.put_line(
                --p_msg
                '[' || local_datetime || '] ' || p_msg --CHG0047013: add local_datetime to help diagnose performance issues
            );
           
        ELSE --Other - do nothing
            NULL;
        END CASE;
    END write_message;

   ----------------------------------------------------------------------------------------------------
    --  Name:               launch_collection_import
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      20-Jun-2018
    --  Purpose:            Launch the Collection Import Manager and wait for
    --                      it to finish.
    --
    --  Description: After records are inserted into the Quality Results Open Interface table,
    --    they need to be processed to create or update quality result rows in qa_results.  This involves
    --    running the standard concurrent program, Collection Import Manager, which in turn may launch
    --    one or more child requests for the standard program Collection Import Worker and the
    --    standard program Quality Actions.  A detailed description of these three programs can
    --    be found on the Oracle Support website.
    --
    --    A key concept to understand for this procedure is that we can optionally wait for
    --    the Collection Import Manager request (and its child requests) to finish before returning
    --    control to the calling procedure.  This is a necessary feature so that the calling procedure
    --    can be assured that the affected rows in qa_results are "up to date" to facilitate
    --    accurrate reporting.  With that said, there are limits to how long we will "wait"
    --    before returning control to the calling procedure.  This time limit is parameterized.
    --
    --    Note - 30-Sep-2019 (Eric Hubert): it may be simpler to use FND_CONCURRENT.WAIT_FOR_REQUEST to wait for the 
    --                        neccessary concurrent requests to finish.  I wasn't aware of this functionality at the time
    --                        I created this procedure.
    --
    --  Inputs:
    --    p_transaction_type: Transaction Type [1: Insert Transaction, 2: Update Transaction]
    --    p_wait_for_completion: indicates if we need to wait until the entire result import process has completed before returning control to the calling procedure.
    --    p_max_sleep_duration: Max total time (seconds) to sleep while monitoring the Collection Import process
    --
    --  Outputs:
    --    p_import_return_status: Status of the import process
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   20-Jun-2018   Hubert, Eric    CHG0042754 - Add ability to get import view name (could only get result view name prior to this)
    ----------------------------------------------------------------------------------------------------
    PROCEDURE launch_collection_import(
        p_transaction_type      IN NUMBER --Transaction Type [1: Insert Transaction, 2: Update Transaction]
        ,p_wait_for_completion  IN BOOLEAN --TRUE: wait until the entire result import process has completed
        ,p_max_sleep_duration   IN NUMBER DEFAULT c_max_sleep_duration --Max total time (seconds) to sleep while monitoring the Collection Import process
        ,p_import_result_status OUT VARCHAR2 --Status of the import process
    )
    IS
        c_method_name CONSTANT VARCHAR(30) := 'launch_collection_import';
        
        /* Local Constants*/
        c_sleep_time CONSTANT   NUMBER := fnd_profile.value('XX: QA Concurrent Request Wait Interval');  --Seconds to sleep between checks of the Collection Import process

        /* Local Variables*/
        l_request_id            NUMBER; --Concurrent Request ID for Collection Import Manager
        l_dynamic_sql           VARCHAR(4000); --Holds constructed dynamic SQL statement
        l_request_count         NUMBER := 0; --Current number of requests related to the submitted Collection Import Manager parent request.
        l_completed_requests    NUMBER := 0; --Number of completed requests related to the submitted Collection Import Manager parent request.
        l_exception_requests    NUMBER := 0; --Number of requests with exceptions related to the submitted Collection Import Manager parent request.
        l_log_comment           VARCHAR2(1024); --Message indicating the current status of the import process.  Used for the log file.
        l_monitoring_loops      NUMBER; --Max time to monitor import-related concurrent requests before returning control back to procedure.
        l_counter               NUMBER; --Counter for loop
        l_import_result_status  VARCHAR2(30) := c_import_status_n; --Status to be returned by this procedure.

    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('program unit: ' || gv_log_program_unit);

        /* Submit a concurrent request for Collection Import Manager to process all of the inserted rows.
           This will subsequently launch requests for Collection Import Worker and Quality Actions. HOW DO WE WAIT FOR THESE TO FINISH?*/
        l_request_id :=  FND_REQUEST.SUBMIT_REQUEST (
                   application  =>  'QA' -- Short name of the application associated with the concurrent request to be submitted.
                  ,program      =>  'QLTTRAMB' -- Program short name for "Collection Import Manager"
                  ,description  =>  'Collection Import Manager launched from script' -- Description of the request that is displayed in the Concurrent Requests form (Optional.)
                  ,start_time   =>  SYSDATE -- Time at which the request should start running, formatted as HH24:MI or HH24:MI:SS (Optional.)
                  ,sub_request  =>  FALSE --Set to TRUE if the request is submitted from another request and should be treated as a sub-request.
                  ,argument1    =>  '200' --Worker Rows (default is 200)
                  ,argument2    =>  '2' --Transaction Type [1: Insert Transaction, 2: Update Transaction]
                  ,argument3    =>  fnd_profile.value('USER_ID')
                  ,argument4    =>  'Yes' --p_gather_statistics
         );

        COMMIT;

        /* Was request submission successfull? */
        IF l_request_id <> 0 THEN
            write_message('Successfully submitted Collection Import Manager, request ID:' || l_request_id);

            /* Do we need to wait for the Collection Import process to finish before returning control to the calling procedure? */
            IF p_wait_for_completion THEN

                l_import_result_status := c_import_status_s; --Update status to Started

                /* Build the dynamic SQL*/
                l_dynamic_sql :=
                    Q'[
                    /* Use a hierarchial query to get all child requests for the Collection Import Manager request
                       and summarize the phases and statuses of each. */
                    SELECT
                        COUNT(*) request_count
                        ,SUM(completed_flag) completed_requests
                        ,SUM(exception_flag) exception_requests
                    FROM
                    (SELECT
                        concurrent_program_id
                        ,request_id
                        ,parent_request_id
                        ,phase_code
                        ,DECODE(phase_code, 'C', 1, 0) completed_flag
                        ,status_code
                        /* D:Cancelled E:Error G:Warning M:No Manager T:Terminated U:Disabled */
                        ,(CASE WHEN status_code IN ('D','E','G','M','T','U') THEN 1 ELSE 0 END) exception_flag
                        ,CONNECT_BY_ROOT request_id AS root_request_id
                        ,CONNECT_BY_ISLEAF AS is_leaf
                    FROM fnd_concurrent_requests
                    START WITH request_id = ]' || l_request_id || Q'[
                    CONNECT BY NOCYCLE parent_request_id = PRIOR request_id)
                    ]';

                --write_message('SQL Statement in variable "l_dynamic_sql":' );
                --write_message(l_dynamic_sql);

                /* Determine how much time should be allowed for the loop to run while we monitor the progression of the collection import process. */
                l_monitoring_loops := TRUNC(p_max_sleep_duration / c_sleep_time);
                --write_message('Maximum monitoring loops:' || l_monitoring_loops);

                /* Iterate through a loop while we monitor the Collection Import process. */
                FOR i IN 1 .. l_monitoring_loops
                LOOP
                    l_counter := i;
                    --write_message('Starting loop #' || l_counter || ' of ' || l_monitoring_loops);

                    /* Execute the dynamic SQL statement. */
                    EXECUTE IMMEDIATE l_dynamic_sql
                    INTO l_request_count, l_completed_requests, l_exception_requests;

                    --write_message('l_request_count: ' || l_request_count);
                    --write_message('l_completed_requests: ' || l_completed_requests);
                    --write_message('l_exception_requests: ' || l_exception_requests);
                    --write_message('Ready to check status of requests.');

                    l_log_comment := NULL; --Reset

                    /* Check for the completion of the requests and for exceptions. */
                    CASE WHEN  (l_completed_requests = l_request_count AND l_exception_requests = 0) THEN
                        /* 1) All requests completed without excpetions.*/
                        l_import_result_status := c_import_status_c; --Update status to Completed

                        l_log_comment := 'Case 1, all '|| l_request_count || ' requests completed without excpetions.  Exiting monitoring loop.';
                        write_message(l_log_comment);

                        EXIT;
                    WHEN l_exception_requests = 0 THEN
                        /* 2) No exceptions yet but not all requests have completed. */
                        l_log_comment := 'Case 2, requests still pending completion: ' || (l_request_count - l_completed_requests);
                        write_message(l_log_comment);
                    WHEN l_exception_requests > 0 THEN
                        /* 3) Exceptions exist. */
                        l_import_result_status := c_import_status_e; --Update status to Exceptions

                        l_log_comment := 'Case 3, requests completed with excpetions: ' || l_exception_requests || ' Exiting monitoring loop.';
                        write_message(l_log_comment);

                        EXIT;
                    END CASE;

                    write_message(l_counter || ' Sleep for ' || c_sleep_time || ' seconds, starting at ' || CURRENT_TIMESTAMP || '.');

                    /* Pause program execution for a period of time (so that we're not constatntly running the query above).*/
                    dbms_lock.sleep(c_sleep_time);
                END LOOP;

                --write_message('Loop finished at #' || l_counter || ' of ' || l_monitoring_loops);
                --write_message('  l_request_count: ' || l_request_count);
                --write_message('  l_completed_requests: ' || l_completed_requests);
                --write_message('  l_exception_requests: ' || l_exception_requests);

                /* Have we reached our maximum number of monitoring loops? */
                IF l_counter >= l_monitoring_loops THEN
                    l_import_result_status := c_import_status_t; --Update status to Timed out
                    l_log_comment := 'The maximum time (' || l_monitoring_loops || ' seconds) allowed for monitoring the collection import process has been reached. ';
                    write_message(l_log_comment);
                END IF;

            END IF;
        ELSE
            /* We have an exception.*/
            l_import_result_status := c_import_status_e; --Update status to Exceptions
            write_message('Error while submitting Collection Import Manager request: ' || SQLERRM);
        END IF;

        p_import_result_status := l_import_result_status;
        write_message('p_import_result_status: ' || p_import_result_status);
        write_message('Ending launch_collection_import.');

    EXCEPTION
        WHEN OTHERS THEN  -- handles all other errors
            p_import_result_status := c_import_status_e;--CHG0047103
            l_log_comment := 'Exception in ' || c_method_name || ': ' || SQLERRM;
            write_message(l_log_comment);--
            write_message('Exiting launch_collection_import.');
    END launch_collection_import;

    ----------------------------------------------------------------------------------------------------
    --  Name:               build_email_address_table
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      16-Oct-2019 
    --  Purpose:            Populate a table with the To, Cc, Bcc, and From
    --                      attributes for the email notification.  This is an
    --                      integral procedure used by the XXQA: Quality Nonconformance Notifications 
    --                      program.  It contains the business rules for determining which
    --                      email addresses are used for the various types of bursted notifications.
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   16-Oct-2019   Hubert, Eric    CHG0042815
    --  1.1   01-Apr-2020   Hubert, Eric    CHG0047103: added material handler notifications for approved scrap and use as-is dispositions.
    --  1.2   01-Apr-2021   Hubert, Eric    CHG0049611: use xxobjt_general_utils_pkg.is_mail_valid to validate email address
    ----------------------------------------------------------------------------------------------------
    PROCEDURE build_email_address_table IS
        c_method_name CONSTANT VARCHAR(30) := 'build_email_address_table';
        
        /* Local constants for roles related to email addresses. */
        c_role_buyer                CONSTANT VARCHAR2(30) := 'Buyer';
        c_role_external_om          CONSTANT VARCHAR2(30) := 'External Order Management';
        c_role_external_qa          CONSTANT VARCHAR2(30) := 'External Quality';
        c_role_supplier_quality     CONSTANT VARCHAR2(30) := 'Stratasys Supplier Quality';
        c_role_dispositioner        CONSTANT VARCHAR2(30) := 'Dispositioned By';
        c_role_scrap_approver       CONSTANT VARCHAR2(30) := 'Scrap Approver';
        c_role_scrap_approver_cc    CONSTANT VARCHAR2(30) := 'Scrap Approver CC';
        c_role_system               CONSTANT VARCHAR2(30) := 'System';
        c_role_mtl_handler          CONSTANT VARCHAR2(30) := 'Material Handler'; --CHG0047103

        /* Local constants for static email addresses. */
        c_email_debug_prefix        CONSTANT VARCHAR2(10) := '~~';  --Prepends email addresses in email address table when profile, XXQA_NOTIFICATION_WHITELIST_DEBUG_MODE, is enabled.   

        /* Local Variables */
        l_supplier_quality_email    qa_results.character1%TYPE;
        l_dispositioner_email       qa_results.character1%TYPE;
        l_buyer_email_addresses     qa_results.character1%TYPE;
        l_mtl_handler_email         qa_results.character1%TYPE; --CHG0047103
        l_cc_email                  qa_results.character1%TYPE;
        l_extended_cost             NUMBER;
        l_sql                       VARCHAR2(2000);
        l_supplier_email_addresses  VARCHAR2(1000); --Delimited list of supplier contact email addresses
        i                           NUMBER;
        j                           NUMBER;
        cur_email                   SYS_REFCURSOR;

        /* Sub procedure (private to just this function) to reduce redundant statements in main procedure.
           Will append email addresses to global table variable, gv_recipient_tab, for email recipients. */
        PROCEDURE append_email_table (
                p_refcur_email          IN SYS_REFCURSOR --one row per email address being appended
                , p_nvd_rec             IN apps.xxqa_nc_rpt_rec_type --nonconformance metadata for email address
                , p_notification_type   IN VARCHAR2
                , p_recipient_type      IN VARCHAR2
                , p_role                IN VARCHAR2
                , p_role_description    IN VARCHAR2 DEFAULT NULL
            ) IS
            l_email_address             VARCHAR2(254);
            i                           NUMBER;

        BEGIN
            gv_log_program_unit := c_method_name; --store procedure name for logging
            --write_message('program unit: ' || gv_log_program_unit);

            /* Loop through each row of the table. */
            LOOP
                FETCH p_refcur_email INTO l_email_address;
                EXIT WHEN p_refcur_email%NOTFOUND;

                /* Perform a rudimentary check on the format of the email address before inserting it. */
                --IF REGEXP_LIKE(l_email_address, '.+\@.+\..+') THEN --CHG0049611/INC0201447: deprecated
                IF xxobjt_general_utils_pkg.is_mail_valid(l_email_address) = 'Y' THEN --CHG0049611/INC0201447: use custom Stratasys function
                    gv_recipient_tab.extend; --add a row to the table
                    i := gv_recipient_tab.count; --get the last position in the table

                    /* Optionally keep emails from going to real email addresses during development phase.
                       Below is a "white list" of email addreses for use while debugging/testing.
                    */
                    IF fnd_profile.value('XXQA_NOTIFICATION_WHITELIST_DEBUG_MODE') = c_yes --CHG0047103
                       AND LOWER(l_email_address) NOT IN (
                            'eric.hubert@stratasys.com' 
                            ,'eric.hubert@redeyeondemand.com'
                            ,'erichubert@solidconcepts.com'
                            ,'erichubert@solidview.com'
                            ,'erichubert@stratasysdirect.com'
                            ,'erichubert@zoobuild_emrp.com'
                            ,'eric.hubert@cuc-pub.stratasys.com'
                            --,'mandar.sabane@stratasys.com'
                            --,'uri.landesberg@stratasys.com'
                            --,'oren.pinchevsky@stratasys.com'
                            --,'orenp@stratasys.com'
                            --UAT testers are below (9/6/19):
                            --,'supplier.gen@gmail.com'--Oren's external email for testing
                            --,'supplier.qa8@gmail.com'--Oren's external email for testing
                            --,'moran.cohen-hanya@stratasys.com'--MORAN.COHEN (no user defined in TEST).  Created user with "PUR Buyer + ASL, SSYS IL".  Does not have HR record or buyer record.
                            --,'anna.shlez@stratasys.com'--ANNA.SHLEZ
                            --,'noa.wilensky-tal@stratasys.com'--NOA.WILENSKY-TAL
                            --,'ella.zaiger@stratasys.com'--ELLA.ZAIGER
                            --,'dima.shissel@stratasys.com'--DIMA.SHISSEL
                            --,'refael.sakara@stratasys.com'--REFAEL.SAKARA (no user defined in TEST).  Created user with "PUR Buyer + ASL, SSYS IL".  Does not have HR record or buyer record.
                            )
                        THEN
                            l_email_address := c_email_debug_prefix || l_email_address;
                    END IF;

                    /* Insert the email address into the recipient table. */
                    gv_recipient_tab(i) := xxobjt.xxqa_recipient_rec_type(
                        n_nonconformance_number => p_nvd_rec.n_nonconformance_number
                        ,v_verify_nc_number     => p_nvd_rec.v_verify_nc_number
                        ,d_disposition_number   => p_nvd_rec.d_disposition_number
                        ,e_notification_type    => p_notification_type
                        ,e_email_address        => l_email_address
                        ,e_recipient_type       => p_recipient_type
                        ,e_role                 => p_role
                        ,e_role_description     => p_role_description
                    );
                    --write_message('gv_recipient_tab(' || i || ').e_email_address: ' || gv_recipient_tab(i).e_email_address); 
                ELSE
                    write_message('invalid email address: ' || l_email_address);
                END IF;
                    
            END LOOP;
        END;

    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        --write_message('program unit: ' || gv_log_program_unit);
        
        gv_recipient_tab := apps.xxqa_recipient_tab_type(); --Initialize object

        /* Loop through each nonconformance/verification/disposition in the table variable. */
        FOR i IN 1 .. gv_nc_rpt_tab.count LOOP

            --write_message(i || ': ' || gv_nc_rpt_tab(i).n_nonconformance_number);
            --write_message(i || ': ' || gv_nc_rpt_tab(i).d_disposition_number);
            
            BEGIN
                /* Get the email for the disposition's inspector supplier quality email group.*/
                SELECT email_address
                INTO l_dispositioner_email
                FROM fnd_user
                WHERE user_name = gv_nc_rpt_tab(i).d_inspector_name;

                IF l_dispositioner_email IS NOT NULL THEN
                    /* Parse for commas-delimited email addresses and get back separate rows for each one. */
                    cur_email := delimited_list_to_rows(p_delimited_string => l_dispositioner_email, p_delimiter => c_delimiter);
                    /* Insert a row into the recipient table. */
                    append_email_table (
                         p_refcur_email      => cur_email
                        ,p_nvd_rec           => gv_nc_rpt_tab(i)
                        ,p_notification_type => p_notification_type_code
                        ,p_recipient_type    => c_recipient_type_cc
                        ,p_role              => c_role_dispositioner
                        ,p_role_description  => NULL
                        );
                    CLOSE cur_email;
                END IF;
                
            /* Exception handling */
            EXCEPTION
                WHEN OTHERS THEN
                    l_dispositioner_email := NULL;
            END;

            --write_message('p_notification_type_code: ' || p_notification_type_code);
            
            /* Which type of notification needs recipients? */
            CASE

            WHEN p_notification_type_code IN (c_notification_type_rav) THEN --RAV_APPROVED
                /* Get the "TO" supplier email address from the disposition plan result (supplier site "regular" contact).
                   During bursting, each "TO" will be a separate email.
                */
                l_supplier_email_addresses := gv_nc_rpt_tab(i).d_supplier_email_address;
                
                /* Parse for commas-delimited email addresses */
                cur_email := delimited_list_to_rows(p_delimited_string => l_supplier_email_addresses, p_delimiter => c_delimiter);
                
                /* Insert a row into the recipient table. */
                append_email_table (
                     p_refcur_email      => cur_email
                    ,p_nvd_rec           => gv_nc_rpt_tab(i)
                    ,p_notification_type => p_notification_type_code
                    ,p_recipient_type    => c_recipient_type_to
                    ,p_role              => c_role_external_om
                    ,p_role_description  => 'Order management for supplier site'
                    );
                CLOSE cur_email;
                
                /* Determine a "CC" email address (supplier site's quality contact) */
                l_supplier_email_addresses := supplier_contact_email_list(
                                                 p_vendor_name       => gv_nc_rpt_tab(i).d_supplier
                                                ,p_vendor_site_code  => gv_nc_rpt_tab(i).d_supplier_site
                                                ,p_contact_type      => c_sct_quality
                                                );
                
                /* Parse for commas-delimited email addresses */
                cur_email := delimited_list_to_rows(p_delimited_string => l_supplier_email_addresses, p_delimiter => c_delimiter);
                
                /* Insert a row into the recipient table. */
                append_email_table (
                     p_refcur_email      => cur_email
                    ,p_nvd_rec           => gv_nc_rpt_tab(i)
                    ,p_notification_type => p_notification_type_code
                    ,p_recipient_type    => c_recipient_type_cc
                    ,p_role              => c_role_external_qa
                    ,p_role_description  => 'Quality''s contact at supplier site'
                    );
                CLOSE cur_email;

                /* Determine a "CC" email address (item's buyer). */
                l_buyer_email_addresses := gv_nc_rpt_tab(i).d_buyer_email_address;
                
                /* Parse for commas-delimited email addresses */
                cur_email := delimited_list_to_rows(p_delimited_string => l_buyer_email_addresses, p_delimiter => c_delimiter);
                
                /* Insert a row into the recipient table. */
                append_email_table (
                     p_refcur_email      => cur_email
                    ,p_nvd_rec           => gv_nc_rpt_tab(i)
                    ,p_notification_type => p_notification_type_code
                    ,p_recipient_type    => c_recipient_type_cc
                    ,p_role              => c_role_buyer
                    ,p_role_description  => 'Item''s buyer'
                    );
                CLOSE cur_email;

                /* Determine a "CC" email address (org's supplier quality email group).*/
                l_supplier_quality_email := get_notification_group_email(p_email_group_name => gv_nc_rpt_tab(i).n_organization_code || c_egs_supplier_quality);

                /* Parse for commas-delimited email addresses */
                cur_email := delimited_list_to_rows(p_delimited_string => l_supplier_quality_email, p_delimiter => c_delimiter);
                /* Insert a row into the recipient table. */
                append_email_table (
                     p_refcur_email      => cur_email
                    ,p_nvd_rec           => gv_nc_rpt_tab(i)
                    ,p_notification_type => p_notification_type_code
                    ,p_recipient_type    => c_recipient_type_cc
                    ,p_role              => c_role_supplier_quality
                    ,p_role_description  => NULL
                    );
                CLOSE cur_email;

                /* Get the "REPLY_TO" email address, which will be the org's supplier quality email group, for the scrap notification. */
                l_supplier_quality_email := get_notification_group_email(p_email_group_name => gv_nc_rpt_tab(i).n_organization_code || c_egs_supplier_quality);

                /* Parse for commas-delimited email addresses */
                cur_email := delimited_list_to_rows(p_delimited_string => l_supplier_quality_email, p_delimiter => c_delimiter);
                /* Insert a row into the recipient table. */
                append_email_table (
                     p_refcur_email      => cur_email
                    ,p_nvd_rec           => gv_nc_rpt_tab(i)
                    ,p_notification_type => p_notification_type_code
                    ,p_recipient_type    => c_recipient_type_reply_to --REPLY_TO: During testing I found that this needs to be a SINGLE valid Stratasys email address (or group) in order for the email to be sent from the email server.
                    ,p_role              => c_role_supplier_quality
                    ,p_role_description  => NULL
                    );
                CLOSE cur_email; 
                
                /* Get the "FROM" email address*/
                cur_email := delimited_list_to_rows(p_delimited_string => c_email_donotreply, p_delimiter => c_delimiter);
                /* Insert a row into the recipient table. */
                append_email_table (
                     p_refcur_email      => cur_email
                    ,p_nvd_rec           => gv_nc_rpt_tab(i)
                    ,p_notification_type => p_notification_type_code
                    ,p_recipient_type    => c_recipient_type_from
                    ,p_role              => c_role_system
                    ,p_role_description  => NULL
                    );
                CLOSE cur_email;
                
            WHEN p_notification_type_code IN (c_notification_type_rtv) THEN --RTV_APPROVED
                /* Get the "TO" supplier email address from the disposition plan result (supplier site quality contact). 
                   During bursting, each "TO" will be a separate email.             
                */
                l_supplier_email_addresses := gv_nc_rpt_tab(i).d_supplier_email_address;
                
                --write_message('l_supplier_email_addresses: ' || l_supplier_email_addresses);

                /* Parse for commas-delimited email addresses */
                cur_email := delimited_list_to_rows(p_delimited_string => l_supplier_email_addresses, p_delimiter => c_delimiter);
                
                /* Insert a row into the recipient table. */
                append_email_table (
                     p_refcur_email      => cur_email
                    ,p_nvd_rec           => gv_nc_rpt_tab(i)
                    ,p_notification_type => p_notification_type_code
                    ,p_recipient_type    => c_recipient_type_to
                    ,p_role              => c_role_external_qa
                    ,p_role_description  => 'Quality''s contact at supplier site'
                    );
                CLOSE cur_email;
                
                /* Determine a "CC" email address ("regular" contact for supplier site). */
                l_supplier_email_addresses := supplier_contact_email_list(
                                                 p_vendor_name       => gv_nc_rpt_tab(i).d_supplier
                                                ,p_vendor_site_code  => gv_nc_rpt_tab(i).d_supplier_site
                                                ,p_contact_type      => c_sct_purchasing
                                                );
                
                /* Parse for commas-delimited email addresses */
                cur_email := delimited_list_to_rows(p_delimited_string => l_supplier_email_addresses, p_delimiter => c_delimiter);
                
                /* Insert a row into the recipient table. */
                append_email_table (
                     p_refcur_email      => cur_email
                    ,p_nvd_rec           => gv_nc_rpt_tab(i)
                    ,p_notification_type => p_notification_type_code
                    ,p_recipient_type    => c_recipient_type_cc
                    ,p_role              => c_role_external_om
                    ,p_role_description  => 'Order management for supplier site'
                    );
                CLOSE cur_email;
                
                /* Determine a "CC" email address (item's buyer). Per 16-Oct-2019 meeting with Oren and US users, the buyer does need to be copied for RTVs, in spite of the objections of IL-based buyers. */
                l_buyer_email_addresses := gv_nc_rpt_tab(i).d_buyer_email_address;
                
                /* Parse for commas-delimited email addresses */
                cur_email := delimited_list_to_rows(p_delimited_string => l_buyer_email_addresses, p_delimiter => c_delimiter);
                
                /* Insert a row into the recipient table. */
                append_email_table (
                     p_refcur_email      => cur_email
                    ,p_nvd_rec           => gv_nc_rpt_tab(i)
                    ,p_notification_type => p_notification_type_code
                    ,p_recipient_type    => c_recipient_type_cc
                    ,p_role              => c_role_buyer
                    ,p_role_description  => 'Item''s buyer'
                    );
                CLOSE cur_email;

                /* Determine a "CC" email address (org's supplier quality email group).*/
                l_supplier_quality_email := get_notification_group_email(p_email_group_name => gv_nc_rpt_tab(i).n_organization_code || c_egs_supplier_quality);

                /* Parse for commas-delimited email addresses */
                cur_email := delimited_list_to_rows(p_delimited_string => l_supplier_quality_email, p_delimiter => c_delimiter);
                /* Insert a row into the recipient table. */
                append_email_table (
                     p_refcur_email      => cur_email
                    ,p_nvd_rec           => gv_nc_rpt_tab(i)
                    ,p_notification_type => p_notification_type_code
                    ,p_recipient_type    => c_recipient_type_cc
                    ,p_role              => c_role_supplier_quality
                    ,p_role_description  => NULL
                    );
                CLOSE cur_email;

                /* Get the "REPLY_TO" email address, which will be the org's supplier quality email group, for the scrap notification. */
                l_supplier_quality_email := get_notification_group_email(p_email_group_name => gv_nc_rpt_tab(i).n_organization_code || c_egs_supplier_quality);

                /* Parse for commas-delimited email addresses */
                cur_email := delimited_list_to_rows(p_delimited_string => l_supplier_quality_email, p_delimiter => c_delimiter);
                /* Insert a row into the recipient table. */
                append_email_table (
                     p_refcur_email      => cur_email
                    ,p_nvd_rec           => gv_nc_rpt_tab(i)
                    ,p_notification_type => p_notification_type_code
                    ,p_recipient_type    => c_recipient_type_reply_to --REPLY_TO: During testing I found that this needs to be a SINGLE valid Stratasys email address (or group) in order for the email to be sent from the email server.
                    ,p_role              => c_role_supplier_quality
                    ,p_role_description  => NULL
                    );
                CLOSE cur_email; 
                
                /* Get the "FROM" email address*/
                cur_email := delimited_list_to_rows(p_delimited_string => c_email_donotreply, p_delimiter => c_delimiter);
                /* Insert a row into the recipient table. */
                append_email_table (
                     p_refcur_email      => cur_email
                    ,p_nvd_rec           => gv_nc_rpt_tab(i)
                    ,p_notification_type => p_notification_type_code
                    ,p_recipient_type    => c_recipient_type_from
                    ,p_role              => c_role_system
                    ,p_role_description  => NULL
                    );
                CLOSE cur_email;

            /* CHG0047103: S_PRE_APPROVAL:
              Even though we don't send an email for this notification type, we need to build a "dummy" email
              list due to the way the query in the data template is written to facilitate bursting
              to the correct email addresses.  (A join from email addresses to the nonconformance
              data is used and thus we need to ensure we have an email address.)
            */
            WHEN p_notification_type_code IN (c_notification_type_spa) THEN
                /* Parse for commas-delimited email addresses */
                cur_email := delimited_list_to_rows(
                    p_delimited_string => 'dummy_email@stratasys.com'--Dummy email to ensure that there is a TO email address because of the inner join in the data template
                    , p_delimiter => c_delimiter);
                
                /* Insert a row into the recipient table. */
                append_email_table (
                     p_refcur_email      => cur_email
                    ,p_nvd_rec           => gv_nc_rpt_tab(i)
                    ,p_notification_type => p_notification_type_code
                    ,p_recipient_type    => c_recipient_type_to
                    ,p_role              => c_role_system
                    ,p_role_description  => 'technical'
                    );
                CLOSE cur_email;

            /* CHG0047103: S_ISSUE_MATERIAL */
            WHEN p_notification_type_code = c_notification_type_sim THEN
                /* Determine a "TO" email address (org's material handler/inventory control email group).*/
                l_mtl_handler_email := get_notification_group_email(p_email_group_name => gv_nc_rpt_tab(i).n_organization_code || c_egs_material_handler_s);
                --write_message('group name: ' || gv_nc_rpt_tab(i).n_organization_code || c_egs_material_handler_s);
                --write_message('l_mtl_handler_email: ' || l_mtl_handler_email);

                /* Parse for commas-delimited email addresses */
                cur_email := delimited_list_to_rows(p_delimited_string => l_mtl_handler_email, p_delimiter => c_delimiter);
                
                /* Insert a row into the recipient table. */
                append_email_table (
                     p_refcur_email      => cur_email
                    ,p_nvd_rec           => gv_nc_rpt_tab(i)
                    ,p_notification_type => p_notification_type_code
                    ,p_recipient_type    => c_recipient_type_to
                    ,p_role              => c_role_mtl_handler
                    ,p_role_description  => 'Material handler (S)'
                    );
                CLOSE cur_email;

                /* Get the "FROM" email address*/
                cur_email := delimited_list_to_rows(p_delimited_string => c_email_donotreply, p_delimiter => c_delimiter);
                /* Insert a row into the recipient table. */
                append_email_table (
                     p_refcur_email      => cur_email
                    ,p_nvd_rec           => gv_nc_rpt_tab(i)
                    ,p_notification_type => p_notification_type_code
                    ,p_recipient_type    => c_recipient_type_from
                    ,p_role              => c_role_system
                    ,p_role_description  => NULL
                    );
                CLOSE cur_email;

                /* Get the "REPLY_TO" email address, which will be the org's supplier quality email group, for the scrap notification. */
                l_supplier_quality_email := get_notification_group_email(p_email_group_name => gv_nc_rpt_tab(i).n_organization_code || c_egs_supplier_quality);

                /* Parse for commas-delimited email addresses */
                cur_email := delimited_list_to_rows(p_delimited_string => l_supplier_quality_email, p_delimiter => c_delimiter);
               
                /* Insert a row into the recipient table. */
                append_email_table (
                     p_refcur_email      => cur_email
                    ,p_nvd_rec           => gv_nc_rpt_tab(i)
                    ,p_notification_type => p_notification_type_code
                    ,p_recipient_type    => c_recipient_type_reply_to
                    ,p_role              => c_role_supplier_quality
                    ,p_role_description  => NULL
                    );
                CLOSE cur_email;
                
            /* CHG0047103: UAI_RETURN_TO_STOCK */
            WHEN p_notification_type_code = c_notification_type_rts THEN
                /* Determine a "TO" email address (org's material handler/inventory control email group).*/
                l_mtl_handler_email := get_notification_group_email(p_email_group_name => gv_nc_rpt_tab(i).n_organization_code || c_egs_material_handler_uai);
                --write_message('group name: ' || gv_nc_rpt_tab(i).n_organization_code || c_egs_material_handler_uai);
                --write_message('l_mtl_handler_email: ' || l_mtl_handler_email);

                /* Parse for commas-delimited email addresses */
                cur_email := delimited_list_to_rows(p_delimited_string => l_mtl_handler_email, p_delimiter => c_delimiter);
                
                /* Insert a row into the recipient table. */
                append_email_table (
                     p_refcur_email      => cur_email
                    ,p_nvd_rec           => gv_nc_rpt_tab(i)
                    ,p_notification_type => p_notification_type_code
                    ,p_recipient_type    => c_recipient_type_to
                    ,p_role              => c_role_mtl_handler
                    ,p_role_description  => 'Material handler (UAI)'
                    );
                CLOSE cur_email;

                /* Get the "FROM" email address*/
                cur_email := delimited_list_to_rows(p_delimited_string => c_email_donotreply, p_delimiter => c_delimiter);
                /* Insert a row into the recipient table. */
                append_email_table (
                     p_refcur_email      => cur_email
                    ,p_nvd_rec           => gv_nc_rpt_tab(i)
                    ,p_notification_type => p_notification_type_code
                    ,p_recipient_type    => c_recipient_type_from
                    ,p_role              => c_role_system
                    ,p_role_description  => NULL
                    );
                CLOSE cur_email;

                /* Get the "REPLY_TO" email address, which will be the org's supplier quality email group, for the scrap notification. */
                l_supplier_quality_email := get_notification_group_email(p_email_group_name => gv_nc_rpt_tab(i).n_organization_code || c_egs_supplier_quality);

                /* Parse for commas-delimited email addresses */
                cur_email := delimited_list_to_rows(p_delimited_string => l_supplier_quality_email, p_delimiter => c_delimiter);
               
                /* Insert a row into the recipient table. */
                append_email_table (
                     p_refcur_email      => cur_email
                    ,p_nvd_rec           => gv_nc_rpt_tab(i)
                    ,p_notification_type => p_notification_type_code
                    ,p_recipient_type    => c_recipient_type_reply_to
                    ,p_role              => c_role_supplier_quality
                    ,p_role_description  => NULL
                    );
                CLOSE cur_email; 
            ELSE
                NULL;
            END CASE;

        END LOOP;
    
    END build_email_address_table;

    ----------------------------------------------------------------------------------------------------
    --  Name:               wf_update_disposition_msg
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      24-Oct-2019
    --  Purpose:            Update XX_WORKFLOW_MESSAGE on the disposition record.
    --                      given the plan and occurrence.            
    --  Description: 
    --
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   24-Oct-2019   Hubert, Eric    CHG0046276: initial build
    ----------------------------------------------------------------------------------------------------
    PROCEDURE wf_update_disposition_msg(
        p_plan_id        IN  qa_plans.plan_id%TYPE
        ,p_occurrence    IN  qa_results.occurrence%TYPE
        ,p_new_value     IN  qa_results.character1%TYPE
        ,p_err_code      OUT NUMBER
        )
    IS
        c_method_name CONSTANT VARCHAR(30) := 'wf_update_disposition_msg';
        
        l_err_code VARCHAR2(30);
        l_err_msg  VARCHAR2(1000);
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        --write_message('program unit: ' || gv_log_program_unit);
        
        /* Write the message to the XX_WORKFLOW_MESSAGE element on the Disposition record.
           This update will be done directly.  If there is a need to update the value via the
           Quality Results Open Interface, then use an approach similar to the update_disposition_status
           procedure that facilitates both methods.
        */
        update_result_value(
            p_plan_id        => p_plan_id
            ,p_occurrence    => p_occurrence
            ,p_char_name     => c_cen_workflow_message
            ,p_new_value     => p_new_value
            ,p_err_code      => l_err_code
            ,p_err_msg       => l_err_msg --CHG0047103
            );
        
        p_err_code := l_err_code;
    END wf_update_disposition_msg;

    ----------------------------------------------------------------------------------------------------
    --  Name:               wf_initiate_scrap_approval
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      24-Oct-2019
    --  Purpose:            Initiate a workflow to approve a scrap disposition
    --  Parameters :
    --       Name                 Type    Purpose
    --       --------             ----    -----------
    --       p_organization_id    In      inventory organization id
    --       p_doc_instance_id    Out     ID for XX Doc Approval Workflow
    --       p_err_code           Out     0: no error; 1: error
    --       p_err_msg            Out     error message/return value
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date            Name            Desc
    --  1.0   24-Oct-2019     Hubert, Eric    CHG0046276
    --  1.1   01-Apr-2020     Hubert, Eric    CHG0047103:
    --                                        -Replaced cursor with loop through gv_nc_rpt_tab
    --                                        -Ensure that the HTML content has been created before initiating a workflow.  
    --                                        -Store html file name as an attribute of the document
    ----------------------------------------------------------------------------------------------------
    PROCEDURE wf_initiate_scrap_approval (
        p_nvd_record            IN  apps.xxqa_nc_rpt_rec_type --CHG0047103
        ,p_doc_instance_id      OUT NUMBER
        ,p_err_code             OUT NUMBER
        ,p_err_msg              OUT VARCHAR2
        )
    IS
        c_method_name CONSTANT VARCHAR(30) := 'wf_initiate_scrap_approval';
              
        /* Local variables */
        l_doc_instance_header       xxobjt_wf_doc_instance%ROWTYPE;
        l_err_code                  NUMBER;
        l_err_msg                   VARCHAR2(1000);
        l_itemkey                   VARCHAR2(25);
        l_requestor_id              NUMBER;
        l_plan_id                   NUMBER;
        l_occurrence                NUMBER;
        l_collection_id             NUMBER;
        l_extended_cost             NUMBER;
        l_action_log_message        qa_action_log.action_log_message%TYPE;--Message for Quality Action Log
        l_log_number                NUMBER;
        l_wf_msg                    qa_results.character1%TYPE;
        l_wf_msg_note               VARCHAR2(100);
        l_file_name                 VARCHAR2(1000);
        l_error_message             VARCHAR2(2000); 
        l_display_type              VARCHAR2(100); --CHG0047103 (unsure of proper size so arbitrarily chose 100)
        l_document                  CLOB; --CHG0047103
        l_document_type             VARCHAR2(100); --CHG0047103 (unsure of proper size so arbitrarily chose 100)
       
        /* Exceptions */
        NO_NOTIFICATION_BODY      EXCEPTION;  --CHG0047103
        NO_DISPOSITION_IN_HTML    EXCEPTION; --CHG0047103
        INVALID_OCCURRENCE        EXCEPTION;
        NO_REQUESTOR              EXCEPTION;
        NO_SCRAP_VALUE            EXCEPTION;
        NO_DOC_ID                 EXCEPTION;
        NO_WF_INSTANCE            EXCEPTION;
        INIT_APPROVAL_ERROR       EXCEPTION;
        --MOVE_FILE_EXCP            EXCEPTION;
        
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('program unit: ' || gv_log_program_unit);

        /* Get the file name that contains the raw html that will be included in the workflow's notifications. */
        l_file_name := conc_output_file_name(
                --p_notification_type_code => p_notification_type_code,
                p_notification_type_code => c_notification_type_spa,--CHG0047103: broke the scrap approval workflow initiation into two parts: 1 - generate/burst HTML (S_PRE_APPROVAL) and 2 - initiate workflow (referencing HTML file created with "S_PRE_APPROVAL" in its file name.
                p_request_id             => NULL,
                p_disposition_number     => p_nvd_record.d_disposition_number
            ); --Get the file name for this notification type and disposition number
        
        /* CHG0047103: there is no need to move the file from the conc output directory like before but we do need to check that
           it has some key data and does not simply contain column headings (a "blank" notification). */
        wf_get_notif_body_scrap_pvt(
                p_doc_instance_id    => NULL,
                p_disposition_number => p_nvd_record.d_disposition_number,
                p_display_type       => l_display_type,
                p_document           => l_document,
                p_document_type      => l_document_type,
                p_err_code           => l_err_code, --CHG0047103
                p_err_msg            => l_err_msg --CHG0047103
                );


        /* Perform rudimentary checks to see that content related to the disposition is included in the HTML file.
           Checking that the disposition number is included should be sufficient. (CHG0047103)
        */
        IF l_err_code = c_fail THEN
            RAISE NO_NOTIFICATION_BODY;
        ELSIF INSTR(l_document, p_nvd_record.d_disposition_number) = 0 THEN
            RAISE NO_DISPOSITION_IN_HTML;
        ELSE
            l_err_msg := NULL;
        END IF;
        
        BEGIN
            /* Get person_id from the user_id from the inspector's username. */
            SELECT xxhr_util_pkg.get_user_person_id(user_id)
            INTO l_requestor_id
            FROM fnd_user
            WHERE user_name = p_nvd_record.d_inspector_name; --CHG0047103
            
            --write_message('l_requestor_id: ' || l_requestor_id);
        
        EXCEPTION
            WHEN OTHERS THEN RAISE NO_REQUESTOR;
        END;

        /* Calculate the value of the scrap disposition. */
        l_extended_cost := p_nvd_record.d_item_cost_frozen * p_nvd_record.d_quantity_dispositioned; --(Frozen Cost)*(Dispositioned Quantity)* --CHG0047103
        --write_message('l_extended_cost: ' || l_extended_cost);
        IF l_extended_cost IS NULL THEN
            RAISE NO_SCRAP_VALUE;
        END IF;

        /* Get some internal Oracle ID values relating to the disposition result record. */
        l_plan_id       := p_nvd_record.d_plan_id;
        l_occurrence    := p_nvd_record.d_occurrence;
        l_collection_id := p_nvd_record.d_collection_id;
        
        --write_message('l_occurrence: ' || l_occurrence);

        /* Assign values for the workflow doc instance*/
        l_doc_instance_header.user_id               := fnd_global.user_id;
        l_doc_instance_header.resp_id               := fnd_global.resp_id;
        l_doc_instance_header.resp_appl_id          := fnd_global.resp_appl_id;
        l_doc_instance_header.creator_person_id     := fnd_global.employee_id;
        l_doc_instance_header.requestor_person_id   := l_requestor_id;
        l_doc_instance_header.n_attribute1          := l_occurrence; --Unique identifier in qa_results
        l_doc_instance_header.attribute1            := p_nvd_record.d_organization_id; --Org id
        l_doc_instance_header.attribute2            := l_plan_id; --Collection plan id
        l_doc_instance_header.attribute3            := l_collection_id; --Collection ID for disposition record
        l_doc_instance_header.attribute4            := p_nvd_record.d_disposition_number; --Disposition Number
        l_doc_instance_header.attribute5            := l_extended_cost; --Collection ID for disposition record
        l_doc_instance_header.attribute6            := l_file_name; --File that contains the raw html to be used for notifications (CHG0047103)

        -- Deriving the Doc ID for creating a Workflow Instance
        l_doc_instance_header.doc_id := xxobjt_wf_doc_util.get_doc_id(p_doc_code => c_wf_doc_code_scrap); --QA_NC_DISP_SCRAP
        
        --write_message('l_doc_instance_header.doc_id: ' || l_doc_instance_header.doc_id);
     
        IF l_doc_instance_header.doc_id IS NULL THEN
            RAISE NO_DOC_ID;
        END IF;

        /* Initialize error variables. */
        l_err_code := c_success; --CHG0047103 (was '')
        l_err_msg  := '';
      
        -- Call package to create Workflow Instance
        xxobjt_wf_doc_util.create_instance(
            p_err_code            => l_err_code,
            p_err_msg             => l_err_msg,
            p_doc_instance_header => l_doc_instance_header,
            p_doc_code            => c_wf_doc_code_scrap --QA_NC_DISP_SCRAP
            );

        write_message('after xxobjt_wf_doc_util.create_instance');
        write_message('l_err_code: ' || l_err_code);
        write_message('l_err_msg: ' || l_err_msg);

        IF l_err_code = c_fail THEN
            RAISE NO_WF_INSTANCE;
        ELSE
            --write_message('l_doc_instance_header.doc_instance_id: ' || l_doc_instance_header.doc_instance_id);
          
            l_err_code := c_success;
            l_err_msg  := '';

            -- Starting Workflow Process
            xxobjt_wf_doc_util.initiate_approval_process(
                p_err_code        => l_err_code,
                p_err_msg         => l_err_msg,
                p_doc_instance_id => l_doc_instance_header.doc_instance_id,
                p_wf_item_key     => l_itemkey,
                p_note            => NULL
                ); --truncated internally to 500 chars
                
            write_message('after xxobjt_wf_doc_util.initiate_approval_process');
            write_message('l_err_code: ' || l_err_code);
            write_message('l_err_msg: ' || l_err_msg);
            write_message('l_itemkey: ' || l_itemkey);

            IF l_err_code = c_fail THEN
                RAISE INIT_APPROVAL_ERROR;
            ELSE

                IF l_err_code = 0 THEN
                    l_err_msg := 'Approval request was successfully submitted for: '
                                    || xxobjt_wf_doc_util.get_doc_name(l_doc_instance_header.doc_id)
                                    || '. doc_instance_id (user_key)='
                                    || l_doc_instance_header.doc_instance_id
                                    || ' item_key=' || l_itemkey
                                    --|| ' Disposition Number=' || l_rr.d_disposition_number;
                                    || ' Disposition Number=' || p_nvd_record.d_disposition_number; --CHG0047103
                    l_wf_msg_note := 'Scrap Approval Workflow initiated';
                ELSE
                    /* If an error occurs for the XXQA: Quality Nonconformance Notification request then, indicate that in the WF Message. */
                    l_err_msg := 'Approval request initiated but error occurred generating notification HTML content: '
                                    || xxobjt_wf_doc_util.get_doc_name(l_doc_instance_header.doc_id)
                                    || '. doc_instance_id (user_key)='
                                    || l_doc_instance_header.doc_instance_id
                                    || ' item_key=' || l_itemkey
                                    --|| ' Disposition Number=' || l_rr.d_disposition_number;
                                    || ' Disposition Number=' || p_nvd_record.d_disposition_number; --CHG0047103
                    l_wf_msg_note := 'Scrap Approval Workflow initiated; error generating HTML';
                END IF;

                /* Build the workflow status message. */
                l_wf_msg := build_disposition_wf_message(
                    p_disposition_number => p_nvd_record.d_disposition_number --CHG0047103
                    ,p_event_name        => NULL
                    ,p_note              => l_wf_msg_note
                );
                
                /* Write the message to the XX_WORKFLOW_MESSAGE element on the Disposition record.
                   This update will be done directly.  If there is a need to update the value via the
                   Quality Results Open Interface, then use an approach similar to the update_disposition_status
                   procedure that facilitates both methods.
                */
                wf_update_disposition_msg (
                    p_plan_id        => l_plan_id
                    ,p_occurrence    => l_occurrence
                    ,p_new_value     => l_wf_msg
                    ,p_err_code      => l_err_code);

            END IF;

        END IF;

        /* Return values to calling procedure. */
        p_doc_instance_id   := l_doc_instance_header.doc_instance_id;
        p_err_code          := c_success;
        p_err_msg           := l_err_msg;
        
    EXCEPTION
    WHEN NO_NOTIFICATION_BODY THEN
        p_err_code   := c_fail;
        p_err_msg    := ('Notification body could not be obtained: ' || l_err_msg);
    WHEN NO_DISPOSITION_IN_HTML THEN
        p_err_code   := c_fail;
        p_err_msg    := ('Disposition number was not found in the HTML: ' || l_err_msg);
    WHEN INVALID_OCCURRENCE THEN
        p_err_code   := c_fail;
        p_err_msg    := ('Unable to determine workflow requestor: ' || l_err_msg);
    WHEN NO_REQUESTOR THEN
        p_err_code   := c_fail;
        p_err_msg    := ('Unable to determine workflow requestor: ' || l_err_msg);
    WHEN NO_SCRAP_VALUE THEN
        p_err_code   := c_fail;
        p_err_msg    := ('Unable to determine the value of the scrapped material: ' || l_err_msg);
    WHEN NO_DOC_ID THEN
        p_err_code   := c_fail;
        p_err_msg    := ('Unable to determine the workflow document type'  || l_err_msg);
    WHEN NO_WF_INSTANCE THEN
        p_err_code   := c_fail;
        p_err_msg    := ('Unable to create a workflow instance: ' || l_err_msg);
    WHEN INIT_APPROVAL_ERROR THEN
        p_err_code   := c_fail;
        p_err_msg    := ('Error in initiate_approval_processe: ' || l_err_msg);
    WHEN OTHERS THEN
        p_err_code   := c_fail;
        p_err_msg    := ('Error in inititating scrap approval: ' || l_err_msg);
    END wf_initiate_scrap_approval;
 
    ----------------------------------------------------------------------------------------------------
    --  Name:               wf_abort_disposition_approvals
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      01-Apr-2020
    --  Purpose:            Abort a XX Doc Approval workflow for a scrap disposition
    --  Parameters :
    --       Name                 Type    Purpose
    --       --------             ----    -----------
    --       p_disposition_number In      disposition number
    --       p_wf_mgmt_option     In      Dicate which workflows, if any, to cancel
    --       p_doc_code           In      Workflow type for XX Doc Approval Workflow
    --       p_err_code           Out     0: no error; 1: error
    --       p_err_msg            Out     error message/return value
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date            Name            Desc
    --  1.0   01-Apr-2020     Hubert, Eric    CHG0047103
    ----------------------------------------------------------------------------------------------------
    PROCEDURE wf_abort_disposition_approvals (
        p_disposition_number IN  qa_results.sequence7%TYPE
        ,p_wf_mgmt_option    IN  NUMBER
        ,p_doc_code          IN  VARCHAR2 DEFAULT c_wf_doc_code_scrap --Currently, this is the only type of Disposition approval workflow that we have
        ,p_err_code          OUT NUMBER
        ,p_err_msg           OUT VARCHAR2
        )
    IS
        c_method_name CONSTANT VARCHAR(30) := 'wf_abort_disposition_approvals';
        
       /* Cursors */
        CURSOR cur_wf (
            p_doc_code            VARCHAR2
            ,p_disposition_number qa_results.sequence7%TYPE
            ,p_wf_mgmt_option     NUMBER
        ) IS
        WITH sq_wf AS (
        SELECT
            xfdi.doc_instance_id
            ,xfdi.doc_status
            ,xfdi.n_attribute1 occurrence
            ,xfdi.attribute1   organization_id
            ,xfdi.attribute2   plan_id
            ,xfdi.attribute3   collection_id
            ,xfdi.attribute4   disposition_number
            ,xfdi.creation_date
            ,COUNT(*) OVER (PARTITION BY xfdi.attribute4)  disp_doc_count
            ,MIN(xfdi.doc_instance_id) OVER (PARTITION BY xfdi.attribute4)  disp_doc_id_min
            ,MAX(xfdi.doc_instance_id) OVER (PARTITION BY xfdi.attribute4)  disp_doc_id_max
            ,p_wf_mgmt_option AS cancel_option --Concurrent program parameter
        FROM 
            xxobjt_wf_doc_instance xfdi
            INNER JOIN xxobjt_wf_docs xwd ON (xwd.doc_id = xfdi.doc_id)
        WHERE 1=1
            AND doc_code = p_doc_code--'QA_NC_DISP_SCRAP'
            AND doc_status IN (
                c_xwds_inprocess  --(there is no "New" status)
                )
        )
        SELECT * FROM sq_wf
        WHERE 1=1
            AND disposition_number = p_disposition_number
            AND
                /* The following conditional where clause criteria are based on the "cancel option" parameter. */
                (
                    CASE
                        /* Option #1: Cancel all existing workflows.  Create new workflow. */
                        WHEN cancel_option = c_wmo_cancel_all_create THEN --select all doc instances
                            1
                        
                        /* Option #2: Don't cancel existing workflows.  Create new workflow.*/
                        WHEN cancel_option = c_wmo_keep_all_create THEN --don't select any doc instances
                            0
                        
                        /* Option #3: Keep last existing in-process workflow only and cancel the rest.  Don't create new workflow. */
                        WHEN cancel_option = c_wmo_keep_last AND doc_instance_id <> disp_doc_id_max THEN --select all but the last doc instance
                            1
                        
                        /* Option #4: Keep first existing in-process workflow only and cancel the rest.  Don't create new workflow.*/
                        WHEN cancel_option = c_wmo_keep_first AND doc_instance_id <> disp_doc_id_min THEN --select all but the first doc instance
                            1
                        
                        /* Option #5: Neither cancel nor create workflows. */
                        WHEN cancel_option = c_wmo_keep_all THEN --don't select any doc instances
                            0
                        
                        /* Option #6: Cancel all existing workflows.  Do not create new workflow. */
                        WHEN cancel_option = c_wmo_cancel_all THEN --select all doc instances
                            1
                        
                        ELSE --don't select any doc instances
                            0
                    END   
                ) = 1
        ORDER BY
            disposition_number
            ,doc_instance_id;

        l_cur_wf_row            cur_wf%ROWTYPE;
        l_delimiter             VARCHAR2(1);
        l_err_code              NUMBER := c_success;
        l_err_msg               VARCHAR2(1000);
        l_open_count            NUMBER := 0;
        l_success_count         NUMBER := 0;
        l_fail_count            NUMBER := 0;
        l_wf_list_success       VARCHAR2(1000);
        l_wf_list_fail          VARCHAR2(1000);
        
        /* Local variables for the Quality Action Log */
        l_action_log_message    qa_action_log.action_log_message%TYPE;--VARCHAR2(4000); --Message for Quality Action Log
        l_msg                   qa_results.character1%TYPE;
        l_disposition           qa_results.character1%TYPE;
        l_log_number            NUMBER;

    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('program unit: ' || gv_log_program_unit);
        write_message('p_wf_mgmt_option: ' || p_wf_mgmt_option);

        p_err_code := c_success;
        p_err_msg  := NULL;

        /* Loop through existing open workflows for the disposition*/
        OPEN cur_wf(
            p_doc_code            => p_doc_code
            ,p_disposition_number => p_disposition_number
            ,p_wf_mgmt_option     => p_wf_mgmt_option
            );
            
            write_message('after OPEN cur_wf');
            
            LOOP
            
                --write_message('before fetch');
            
                FETCH cur_wf INTO l_cur_wf_row;
                
                --write_message('after fetch');
                
                EXIT WHEN cur_wf%NOTFOUND;
                
                --write_message('after EXIT WHEN');
            
                l_open_count := l_cur_wf_row.disp_doc_count;
                
                --write_message('l_open_count: ' || l_open_count);

                write_message('l_cur_wf_row.doc_instance_id: ' || l_cur_wf_row.doc_instance_id);
                
                xxobjt_wf_doc_util.abort_process(
                    p_err_code        => l_err_code,
                    p_err_msg         => l_err_msg,
                    p_doc_instance_id => l_cur_wf_row.doc_instance_id);
                
                write_message('workflow aborted for: ' || l_cur_wf_row.doc_instance_id);
                
                /* Keep track of the successfull and failed attempts to abort the workflow. */
                IF l_err_code = c_fail THEN
                    l_fail_count      := l_fail_count + 1;

                    /* Add a delimiter if there are multiple values. */
                    IF l_fail_count > 1 THEN
                        l_delimiter := c_delimiter;
                    ELSE
                        l_delimiter := NULL;
                    END IF;

                    l_wf_list_fail    := SUBSTR(l_wf_list_fail    || l_delimiter || ' ' || l_cur_wf_row.doc_instance_id, 1, 1000);
                    
                    p_err_code := c_fail; --Indicate an error if any of the workflows can't be aborted.
                ELSE
                    l_success_count   := l_success_count + 1;

                    /* Add a delimiter if there are multiple values. */
                    IF l_success_count > 1 THEN
                        l_delimiter := c_delimiter;
                    ELSE
                        l_delimiter := NULL;
                    END IF;

                    l_wf_list_success := SUBSTR(l_wf_list_success || l_delimiter || ' ' || l_cur_wf_row.doc_instance_id, 1, 1000);  
                    
                    /* Get some values for the message construction. */
                    CASE p_doc_code--infer the disposition from the document type
                    WHEN c_wf_doc_code_scrap THEN
                        l_disposition := c_disp_s;
                        l_msg := 'Aborted approval workflow (' || c_wf_doc_code_scrap || ') for this disposition.';
                    ELSE
                        l_disposition := NULL;
                    END CASE;

                     /* Construct message for Quality Action Log Entry */
                    build_action_log_message(
                        p_element_name              => c_cen_disposition_status
                        ,p_action_name              => c_d_action_awa --approval workflow aborted 
                        ,p_nonconformance_number    => NULL  
                        ,p_verify_nc_number         => NULL   
                        ,p_disposition_number       => p_disposition_number
                        ,p_new_status               => NULL
                        ,p_old_status               => NULL 
                        ,p_disposition              => l_disposition 
                        ,p_occurrence               => l_cur_wf_row.occurrence 
                        ,p_move_order_number        => NULL
                        ,p_doc_instance_id          => l_cur_wf_row.doc_instance_id --CHG0047103
                        ,p_note                     => l_msg
                        ,p_message                  => l_action_log_message    
                    ); 

                    /* Log the initiation of the workflow in the Quality Action Log */
                    create_quality_action_log_row(
                        p_plan_id       => l_cur_wf_row.plan_id,
                        p_collection_id => l_cur_wf_row.collection_id,
                        p_creation_date => SYSDATE,
                        p_char_id       => qa_core_pkg.get_element_id(c_cen_disposition_status),--XX_DISPOSITION_STATUS
                        p_operator      => 7, --We use 7 which is "is entered" only because p_operator can't be null and if set to 0 it won't be visible in Action log.
                        p_low_value     => NULL,
                        p_high_value    => NULL,
                        p_message       => l_action_log_message,
                        p_result        => NULL,
                        p_concurrent    => 0, --"online" (is being called as part of a concurrent request).  As of the initial release, this is always called in the context of a concurrent request so we hardcod this to 1.
                        p_log_number    => l_log_number
                        );
                END IF;
            END LOOP;
        CLOSE cur_wf;

		/* Build a message summarizing the results of the cancellation(s). */
        l_wf_list_success := SUBSTR('XX Doc Instance IDs (workflows) Cancelled (count='     || l_success_count || '): ' || l_wf_list_success, 1, 1000);
        l_wf_list_fail    := SUBSTR('XX Doc Instance IDs (workflows) NOT Cancelled (count=' || l_fail_count    || '): ' || l_wf_list_fail,    1, 1000);
        
        l_err_msg := NULL;

        IF l_success_count > 0  THEN
            l_err_msg  := l_wf_list_success;
        END IF;

        IF l_fail_count > 0  THEN
            p_err_code := c_fail;
            l_err_msg  := l_err_msg || CHR(10) || l_wf_list_fail;
        END IF;

        /* Return values to the calling procedure. */
        p_err_msg  := l_err_msg;

        --write_message('p_err_code: ' || p_err_code);
        --write_message('p_err_msg: ' || p_err_msg);
        --write_message('end of wf_abort_disposition_approvals');
        
    EXCEPTION
        WHEN OTHERS THEN
            p_err_code := c_fail;
            write_message('l_err_code: ' || l_err_code);
            write_message('Exception in ' || c_method_name || ': ' || SQLERRM );
            p_err_msg := l_err_msg || '; Open count=' || l_open_count ||'; Success count=' || l_success_count || '; Failed count=' || l_fail_count;
            write_message('l_err_msg: ' || l_err_msg);

    END wf_abort_disposition_approvals;
 
    ----------------------------------------------------------------------------------------------------
    --  Name:               wf_disposition_manager_main
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      01-Apr-2020
    --  Purpose:            Main procedure that handles the creation and cancelation of workflows related to dispositions
    --                               
    --  Description:        Loops through disposiiton records in gv_nc_rpt_tab.
    --
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   01-Apr-2020   Hubert, Eric    CHG0047103: initial build
    ----------------------------------------------------------------------------------------------------
    PROCEDURE wf_disposition_manager_main IS
        c_method_name CONSTANT VARCHAR(30) := 'wf_disposition_manager_main';
        
        l_doc_instance_id       NUMBER;

        /* Local variables for workflow message updating*/
        l_wf_msg                qa_results.character1%TYPE;

        l_err_code              NUMBER := c_success;
        l_err_msg               VARCHAR2(1000);
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('program unit: ' || gv_log_program_unit);
        
        write_message('gv_nc_rpt_tab.count: ' || gv_nc_rpt_tab.count);

        /* Loop through each nonconformance/verification/disposition in the table variable. */
        FOR i IN 1 .. gv_nc_rpt_tab.count LOOP

            write_message(i || ': ' || gv_nc_rpt_tab(i).n_nonconformance_number);
            write_message(i || ': ' || gv_nc_rpt_tab(i).d_disposition_number);

            /* Determine which actions to take based on the disposition.
                The main action is the document approval workflow to initiate. (We only have an approval for scrap defined for the inital build.)
                Other actions include:
                -cancelling existing workflows (CHG0047103)
                -cancelling existing move orders (CHG0047103)
            */
            write_message('gv_nc_rpt_tab(i).d_disposition: ' || gv_nc_rpt_tab(i).d_disposition);

            CASE gv_nc_rpt_tab(i).d_disposition --CHG0047103
            WHEN c_disp_s THEN  --Scrap
            
                write_message('before wf_abort_disposition_approvals');
                
                /* Abort existing doc approval workflow instances, if any, per the workflow management option. (CHG0047103)*/
                wf_abort_disposition_approvals(
                    p_disposition_number => gv_nc_rpt_tab(i).d_disposition_number
                    ,p_wf_mgmt_option    => p_workflow_management_option
                    ,p_doc_code          => c_wf_doc_code_scrap --Currently, this is the only type of Disposition approval workflow that we have
                    ,p_err_code          => l_err_code
                    ,p_err_msg           => l_err_msg
                );
                
                --write_message('after wf_abort_disposition_approvals');
                --write_message('l_err_code: ' || l_err_code);
                --write_message('l_err_msg: ' || l_err_msg);

                /* If no error cancelling workflows then move on to creating a new one*/
                IF l_err_code = c_success THEN
                    --write_message('before checking disp status = PRE_APPROVAL');

                    --write_message('gv_nc_rpt_tab(i).d_disposition_status: ' || gv_nc_rpt_tab(i).d_disposition_status);
                    --write_message('p_workflow_management_option: ' || p_workflow_management_option);

                    /* Check if current Disposition Status is PRE_APPROVAL and the workflow management option. */
                    IF gv_nc_rpt_tab(i).d_disposition_status = c_d_status_pra
                        AND p_workflow_management_option IN (
                            c_wmo_cancel_all_create --Cancel all existing workflows.  Create new workflow.
                            ,c_wmo_keep_all_create  --Don't cancel existing workflows.  Create new workflow.
                        ) THEN

                        --write_message('before wf_initiate_scrap_approval');
                        
                        wf_initiate_scrap_approval (
                            p_nvd_record            => gv_nc_rpt_tab(i) --CHG0047103
                            ,p_doc_instance_id      => l_doc_instance_id
                            ,p_err_code             => l_err_code
                            ,p_err_msg              => l_err_msg
                            );
                            
                        write_message('after wf_initiate_scrap_approval');
                        write_message('l_err_code: ' || l_err_code);
                        write_message('l_err_msg: ' || l_err_msg);
                        
                        IF l_err_code = c_fail THEN
                            /* Change disposition status to APPROVAL_EXCEPTION (ensuring this gets logged). */
                            override_disposition_status(
                                p_disposition_number => gv_nc_rpt_tab(i).d_disposition_number
                                ,p_occurrence        => NULL
                                ,p_new_status        => c_d_status_eap
                                ,p_source_ref        => c_method_name
                                ,p_err_code          => l_err_code
                                ,p_err_msg           => l_err_msg);
                                
                            /* Update the workflow message so that users can see the issue and notify IT */
                            l_wf_msg := 'EXCEPTION: unable to initiate a workflow for this disposition.';
                            write_message(l_wf_msg);

                            wf_update_disposition_msg (
                                p_plan_id        => gv_nc_rpt_tab(i).d_plan_id
                                ,p_occurrence    => gv_nc_rpt_tab(i).d_occurrence
                                ,p_new_value     => l_wf_msg
                                ,p_err_code      => l_err_code);

                        END IF;

                    END IF;
                ELSE
                    /* Change disposition status to APPROVAL_EXCEPTION (ensuring this gets logged). */
                    override_disposition_status(
                        p_disposition_number => gv_nc_rpt_tab(i).d_disposition_number
                        ,p_occurrence        => NULL
                        ,p_new_status        => c_d_status_eap
                        ,p_source_ref        => c_method_name
                        ,p_err_code          => l_err_code
                        ,p_err_msg           => l_err_msg);
                        
                    /* Update the workflow message so that users can see the issue and notify IT */
                    l_wf_msg := 'EXCEPTION: unable to cancel existing workflow for this disposition.';
                    write_message(l_wf_msg);

                    wf_update_disposition_msg (
                        p_plan_id        => gv_nc_rpt_tab(i).d_plan_id
                        ,p_occurrence    => gv_nc_rpt_tab(i).d_occurrence
                        ,p_new_value     => l_wf_msg
                        ,p_err_code      => l_err_code);
                END IF;
            ELSE --Place holder for future approvals of other disposition types

                NULL;--Do nothing
                
            END CASE;
        END LOOP;
        
    EXCEPTION
        WHEN OTHERS THEN
        write_message('Exception in ' || c_method_name || ': ' || SQLERRM );
    END wf_disposition_manager_main;

    ----------------------------------------------------------------------------------------------------
    --  Name:               mo_disposition_manager_main
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      01-Apr-2020
    --  Purpose:            Main procedure that handles the creation and cancelation of move orders related to dispositions
    --                               
    --  Description:        Loops through disposiiton records in gv_nc_rpt_tab.
    --
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   01-Apr-2020   Hubert, Eric    CHG0047103: initial build
    ----------------------------------------------------------------------------------------------------
    PROCEDURE mo_disposition_manager_main IS
        c_method_name CONSTANT VARCHAR(30) := 'mo_disposition_manager_main';
        
        /* Constants relating to running XXINV: Move Order Traveler*/
        c_run_mot           CONSTANT VARCHAR2(1) := c_no; --CHG0047103: run XXINV: Move Order Traveler before material handler notification
        c_attach_mot        CONSTANT VARCHAR2(1) := c_yes; --CHG0047103: attach XXINV: Move Order Traveler to material handler notification
        c_max_wait          CONSTANT NUMBER      := 3600; --Max amount of time to wait (in seconds) for request's completion    
    
        /* Local variables */
        l_request_id        NUMBER;
        l_move_order_number mtl_txn_request_headers.request_number%TYPE; --CHG0047103
        l_move_order_batch  VARCHAR2(30) := c_mo_batch_prefix || fnd_global.conc_request_id;  --Batch number assigned to one or more move orders that is used as a parameter of XXINV: Move Order Traveler to select multiple move orders
        l_error_message     VARCHAR2(2000);
        l_completed         BOOLEAN;
        l_phase             VARCHAR2(200);
        l_vstatus           VARCHAR2(200);
        l_dev_phase         VARCHAR2(200);
        l_dev_status        VARCHAR2(200);
        l_message           VARCHAR2(200);
        l_conc_status_code  VARCHAR2(1);
        l_wf_msg            qa_results.character1%TYPE; --for workflow message updating
        l_err_code          NUMBER := c_success;
        l_err_msg           VARCHAR2(1000);
        l_organization_code mtl_parameters.organization_code%TYPE; --Inventory Org Code
        l_mtl_handler_email qa_results.character1%TYPE; --CHG0047103
        l_interval          NUMBER := fnd_profile.value('XX: QA Concurrent Request Wait Interval'); --Number of seconds to wait between checks.
        
        /* Exceptions */
        RPT_SUBMIT_EXCP EXCEPTION;
        RPT_ERROR       EXCEPTION;
        RPT_WARNING     EXCEPTION;
        MOVE_FILE_EXCP  EXCEPTION; 
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('program unit: ' || gv_log_program_unit);
        
        /* Loop through each disposition */
        FOR i IN gv_nc_rpt_tab.FIRST .. gv_nc_rpt_tab.LAST LOOP

            write_message('gv_nc_rpt_tab(i).d_disposition_number: ' || gv_nc_rpt_tab(i).d_disposition_number);
        

            IF gv_nc_rpt_tab(i).d_disposition IN (c_disp_s, c_disp_uai) THEN  --Scrap, Use As-Is

               --write_message('Disposition is Scrap or UAI');

                /* Check to see if a move order is referenced on the disposition.  If not,
                   then cancel all move orders that may still be reference the disposition (we don't anticipate this happening often but do this to be safe).
                   If a move order is referenced, then don't cancel or create any move
                   orders. */
                IF gv_nc_rpt_tab(i).d_disposition_move_order IS NULL THEN
                    /* Cancel all move orders that are associated with the disposition.
                       It is unlikely that other move orders are associated with the disposition
                       but this is to be safe.
                    */
                    --write_message('Before mo_cancel_disp_move_orders');
                    mo_cancel_disp_move_orders(
                        p_disposition_number   => gv_nc_rpt_tab(i).d_disposition_number
                        ,p_org_id              => gv_nc_rpt_tab(i).d_organization_id
                        ,p_err_code            => l_err_code
                        ,p_err_msg             => l_err_msg
                    );

                    /* Proceed to create a new move order only if the cancellation action was successfull so that we don't have multiple move orders to scrap the same material. */
                    IF l_err_code = c_success THEN
                    
                        /* Create a move order for the disposition. */
                        --write_message('Before mo_create_disp_move_order');
                        mo_create_disp_move_order (
                                p_nvd_record            => gv_nc_rpt_tab(i)
                                ,p_move_order_number    => l_move_order_number
                                ,p_err_code             => l_err_code
                                ,p_err_msg              => l_err_msg
                                );

                        write_message('l_move_order_number: ' || l_move_order_number);
                        
                        /* Populate the Move Order on nc rpt variable and disposition record */
                        IF l_move_order_number IS NOT NULL THEN
                            --write_message('MO not null');
                            gv_nc_rpt_tab(i).d_disposition_move_order := l_move_order_number; --Variable
                            
                            --write_message('Before update_result_value');
                            
                            /* Update the move order number directly. */
                            update_result_value(
                                p_plan_id        => gv_nc_rpt_tab(i).d_plan_id
                                ,p_occurrence    => gv_nc_rpt_tab(i).d_occurrence
                                ,p_char_name     => c_cen_move_order_number
                                ,p_new_value     => l_move_order_number
                                ,p_err_code      => l_err_code
                                ,p_err_msg       => l_err_msg
                                );
                            --write_message('After update_result_value');

                        ELSE
                            /* Change disposition status to MOVE_ORDER_EXCEPTION (ensuring this gets logged). */
                            override_disposition_status(
                                p_disposition_number => gv_nc_rpt_tab(i).d_disposition_number
                                ,p_occurrence        => NULL
                                ,p_new_status        => c_d_status_emo
                                ,p_source_ref        => 'mo_disposition_manager_main'
                                ,p_err_code          => l_err_code
                                ,p_err_msg           => l_err_msg);
                                
                            /* Update the workflow message so that users can see the issue and notify IT */
                            l_wf_msg := 'EXCEPTION: unable to create move order.';
                            write_message(l_wf_msg);

                            wf_update_disposition_msg (
                                p_plan_id        => gv_nc_rpt_tab(i).d_plan_id
                                ,p_occurrence    => gv_nc_rpt_tab(i).d_occurrence
                                ,p_new_value     => l_wf_msg
                                ,p_err_code      => l_err_code);
                        
                        END IF;
                    ELSE
                        /* Change disposition status to MOVE_ORDER_EXCEPTION (ensuring this gets logged). */
                        override_disposition_status(
                            p_disposition_number => gv_nc_rpt_tab(i).d_disposition_number
                            ,p_occurrence        => NULL
                            ,p_new_status        => c_d_status_emo
                            ,p_source_ref        => 'mo_disposition_manager_main'
                            ,p_err_code          => l_err_code
                            ,p_err_msg           => l_err_msg);
                            
                        /* Update the workflow message so that users can see the issue and notify IT */
                        l_wf_msg := 'EXCEPTION: unable to cancel move order.';
                        write_message(l_wf_msg);

                        wf_update_disposition_msg (
                            p_plan_id        => gv_nc_rpt_tab(i).d_plan_id
                            ,p_occurrence    => gv_nc_rpt_tab(i).d_occurrence
                            ,p_new_value     => l_wf_msg
                            ,p_err_code      => l_err_code);

                    END IF;
                END IF;
            END IF;
            
        END LOOP;
        
        /* Run XXINV: Move Order Traveler (MOT) for two purposes:
           1) Allocate material to the Move Order.
              -Lot-based items will not have allocated within mo_cancel_disp_move_orders due to a limitation of the API
               so we run the MOT with the allocate paramater = Y to do this now. 
              -An allocated move order is desireabe for approved scrap because it minimizes the effort required by the 
               material handler to transact the move order (they don't need to manually allocate the MO).  Also, it makes 
               it more difficult for another user to move the material out of MRB (for some other reason such as using the 
               material on a job) without first removing the allocation.
           2) Produce an output file that that can be included (or attached) on the notification to the material handler.
              -This saves the step of manually printing the MOT by the material handler.
              -We parameterize the creation of the output file, however.  This is because some sites
               may want to limit the printing of the MOTs only be explict submission of a concurrent request by
               the material handler (to minimize the chance of duplicate physical paper copies of the MOT that could
               cause an attempt of the material to be physically and/or logically scrapped twice, even though Oracle
               would not allow a MO to be transacted twice.)
        */
        IF c_run_mot = c_yes THEN
        
            l_organization_code := xxinv_utils_pkg.get_org_code(p_organization_id);  --Org code from concurrent request org id parameter
        
            --/* Get the email address for the material handlers group */
            --l_mtl_handler_email := get_notification_group_email(p_email_group_name => l_organization_code || c_egs_supplier_mtl_handler);
        
            write_message('Before run_mot_report');
            
            /* Submit a request for XXINV: Move Order Traveler. */
            l_request_id := run_mot_report(
                p_organization_id               => p_organization_id --conc request parameter
                ,p_move_order_number            => NULL --We're running this for an entire "batch", not just a single move order
                ,p_inv_pick_slip_print_option   => 99 -- All (Prints all the Tasks)
                ,p_batch                        => l_move_order_batch  --This will limit the results to just just the move orders created for the current (quality notification) request.
                ,p_report_layout_style          => 'Medium' --Per Value Set XXINV_REPORT_LAYOUT_STYLE
                );
            write_message('After run_mot_report');
            write_message('l_request_id: ' || l_request_id);
            
            /* Wait for the completion of the concurrent request (if submitted successfully) */
            l_error_message := 'Error Occured while Waiting for the completion of the XXINV: Move Order Traveler concurrent request';
            l_completed     := apps.fnd_concurrent.wait_for_request(
                            request_id => l_request_id,
                            interval   => l_interval,
                            max_wait   => c_max_wait,
                            phase      => l_phase,
                            status     => l_vstatus,
                            dev_phase  => l_dev_phase,
                            dev_status => l_dev_status,
                            message    => l_message);

            /* Check the Concurrent Program status */
            l_error_message := 'Error Occured while deriving the status code of the XXINV: Move Order Traveler';
            SELECT status_code
            INTO   l_conc_status_code
            FROM   fnd_concurrent_requests
            WHERE  request_id = l_request_id;
            
            write_message('l_conc_status_code: ' || l_conc_status_code);

            IF l_conc_status_code = 'E' THEN-- Error
                l_error_message   := 'XXINV: Move Order Traveler with Request ID :' ||
                   l_request_id || ' completed in Error';
                RAISE rpt_error;

            ELSIF l_conc_status_code = 'G' THEN-- Warning
                l_error_message   := 'XXINV: Move Order Traveler request with Request ID :' ||
                    l_request_id || ' completed in Warning';
                RAISE rpt_warning;

            ELSIF l_conc_status_code = 'C' THEN-- Success
                --l_file_name       :=  c_psn_mot || '_' || l_request_id ||'_1.PDF';
                --l_move_msg        := '';
                --l_error_message   := 'Error Occured in function move_output_file';
                --l_move_msg        := move_output_file(l_file_name);
                --  
                --IF l_move_msg IS NOT NULL THEN
                --    l_error_message   := l_move_msg;
                --    RAISE move_file_excp;
                --END IF;

                l_err_code    := c_success;
                l_error_message := NULL;

            END IF;
            
        END IF;
        
        write_message('end of mo_disposition_manager_main');

    EXCEPTION
        WHEN OTHERS THEN
        write_message('Exception in ' || c_method_name || ': ' || SQLERRM );

    END mo_disposition_manager_main;
    ----------------------------------------------------------------------------------------------------
    -- END PRIVATE PROCEDURES
    ----------------------------------------------------------------------------------------------------

END xxqa_nonconformance_util_pkg;
/