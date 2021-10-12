CREATE OR REPLACE PACKAGE APPS.xxqa_nonconformance_util_pkg AUTHID CURRENT_USER AS
----------------------------------------------------------------------------------------------------
--  Name:               xxqa_nonconformance_util_pkg
--  Created By:         Hubert, Eric
--  Revision:           4.1
--  Creation Date:      Dec-2016
--  Purpose:            CHG0040770 - Quality Nonconformance Report
----------------------------------------------------------------------------------------------------
--  Ver   Date          Name            Desc
--  1.0   Dec-2016      Hubert, Eric    S3 Initial Build
--  1.1   12-Jun-2017   Lingaraj(TCS)   CHG0040770 - Quality Nonconformance Report
--  1.2   31-Jul-2017   Hubert, Eric    CHG0041284 - Add Tools menu item to print Quality Nonconformance Report from quality results forms
--  2.0   20-Jun-2018   Hubert, Eric    CHG0042754:
--                                      -Renamed package to xxqa_nonconformance_util_pkg (was xxqa_nc_rpt_pkg)
--                                      -Added ability to programatically update Nonconformance Statuses
--                                      -Renamed function "f_report_data" to be "nonconformance_report_data"
--                                      -Renamed ""f_report_parameter_lov" to "report_sequence_parameter_lov"
--                                      -Added columns to nonconformance_report_data: n_lot_number, n_email_addresses, n_manual_lot_serial_number, v_nc_comments_reference, d_quantity, d_capa_status, d_item_cost_frozen, d_nc_comments_reference, d_purchasing_entered_date
--  2.1   25-Jan-2019   Hubert, Eric    CHG0042589: enhanced update_nonconformance_status to optionally directly update qa_results without the results open interface for performance improvement and workaround for SR 3-19222349401 until Patch 17033939 can be applied.
--  3.0   16-Oct-2019   Hubert, Eric    CHG0042815:
--                                      -Added procedures update_disposition_status, build_action_log_message, log_manual_status_update
--                                      -Moved and renamed nonconformance status constants to package spec from update_nonconformance_procedure
--                                      -Changed length of variables and constants that store view and column names, from 50 to 30, to match related table column sizes.
--                                      -Added global variable declaration for Logging unit
--  4.0   24-Oct-2019   Hubert, Eric    CHG0046276:
--                                      -Scrap disposition approval via XX Dox Approval Workflow
--                                      -Renamed constants with numerical suffixes to have descriptive abbreviations or acronyms for improved code readability
--  4.1   01-Apr-2020   Hubert, Eric    CHG0047103: 
--                                      -Email notification for material handlers after disposition is approved to alert them of a new move order.
--                                      -Bug fixes for Scrap approval workflow
--                                      -Deprecated get_nonconformance_status and get_disposition_status in favor of new function, key_sequence_result_value.
--                                      -New programs: XXQA: Initiate Disposition Approval and XXQA: Create Disposition Move Orders
--  4.2   01-Apr-2021   Hubert, Eric    CHG0049611:
--                                      -Refactored nonconformance_report_data
--                                      -Refactored receiving_inspection_data
--                                      -Improved email format validation check for notifications (build_email_address_table)
--                                      -Disabled immediate NC/Disp status update upon Scrap workflow completion (Approve/Reject)
--                                      -Changed from hardcoded "Yes" to value of profile to determine if update_nonconformance_status is called when running XXQA: Nonconformance Report
----------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------

/* Functional Overview: This package supports reporting and processing
  pertaining to Quality Nonconformances and related processes such as
  receiving inspection.

  1) XXQA: Quality Nonconformance Report:
  The Quality Nonconformance Report displays
  information pertaining to quality-related nonconformances.  It is physically
  affixed to the nonconforming material.  The Information displayed on this
  report comes from three Collection Plans (in each Org): Nonconformance,
  Nonconformance Verification, and Disposition.

      Technical Overview: Because of the "flexible" nature of Oracle Quality
      Collection Plan configurations, building a single nonconformance report that
      will work for collection plans in an arbitrary organization requires some
      complexity.  This package supports an XML Publisher-based report using
      dynamic SQL to allow it to be run in any org that strictly implements a
      Nonconformance--Verify Nonconformance--Disposition colelction plan hierachy.

      In addition to supporting the XML Publisher-based Quality Nonconformance
      report, this package can be used for analytical reporting, albeit with less
      than optimal performance due to the dynamic SQL utilized.

      A primary function used is nonconformance_report_data, which utilizes a reference
      cursor and returns a custom table type object.  This allows the function to
      be called directly from SQL by specifying (optional) paramaters for a
      specific Nonconformance Number, and/or Verify Nonconformance Number, and/or
      Disposition Number.  (The main query in the Data Template uses this
      function in a SQL statement).  See the description for the function,
      nonconformance_report_data, in the package body for a more detailed description.

  2) XXQA: Quality Receiving Inspection Report:
  The Receiving Inspection Report displays
  information pertaining to receiving inspections.  One specific use of this
  report is to physically affix it to material that has been inspected
  to serve as an "Inspection Release Sticker" (though it will also print for
  rejected inspections).  The Information displayed on this
  report comes from the Receiving Inspection collection plans in each org.

  A primary function used is receiving_inspection_data, which utilizes a reference
  cursor and returns a custom table type object.  This allows the function to
  be called directly from SQL by specifying a specific Receiving Inspection
  Number.  (The main query in the Data Template uses this
  function in a SQL statement).  See the description for the function,
  receiving_inspection_data, in the package body for a more detailed description.
  
  3) XXQA: Update Nonconformance Status
  
  4) XXQA: Quality Nonconformance Notifications  
  
*/

/* Commentary on Naming Conventions:
    Within this package spec and body, the following naming conventions are generally employed.
    In general, constant and variable declarations err on the side of being long/verbose for the benefit of communicating design intent.
   
    Constants: prefixed with "c_"
        -"Groups" of constants with similar names/prefixes, but different values, are declared to communicate their purpose.
        -Constants are used extensively to
            -Eliminate needing to type the same value multiple times
            -Improve readability, clarity, and design intent. (avoids the use of "magic" values)
            -Only need to change a value in one place (single point of declaration)
            -Communicates better to another person maintaining the code that it should not be changed
    
    Types: prefixed with "t_"

    Cursors: prefixed with "cur_"
    
    Parameters: prefixed with "p_"
        -Used for procedure, function, and concurrent program parameters.
   
    Variables (defined in the lowest practical scope):
        -Public variables (spec declaration) prefix: "gv_"
        -Private variables (body declaration) prefix: "v_"
        -Local variables (procedure/function declaration) prefix: "l_"
        -Often declared with "%TYPE" and "%ROWTYPE" to communicate design intent
            -Specifically for the qa_results table, there are 99 columns, whose name starts 
             with "CHARACTER" (i.e CHARACTER1 through CHARACTER99), that are all of the same type.  
             Variables that relate to any of these 99 columns will be declared generically 
             referencing the CHARACTER1 column, i.e. "qa_results.character1%TYPE", rather than
             a specific numbered column.  This is done for simplicity and because Oracle
             can store the value for the same collection element in different character__ columns
             for two different collection plans.

    
    Procedures/Functions:
        -No extraordinary effort has been made regarding the naming of procedures and functions.
        -The names of come func/procs that relate to simialr purposes may share a similar prefix.
        -The location of the functions and procedures within the package body are maintained
         within logical groups of "Public Functions", "Public Procedures", "Private Functions",
         and "Public Procedures".  As much as possible they are kept in alphabetical order within
         these groupss.

    Other:
        -Where practical, the use of proc/function return parameters named "p_err_code" 
        and "p_err_msg" are used to align with other Stratasys custom packages.
*/

    /* Types to store rules for Disposition processing. (CHG0042815)*/
    TYPE t_disposition_status_row IS RECORD (
        xx_sequence                     NUMBER
        ,count_of_sequence              NUMBER --CHG0047103
        ,xx_disposition                 qa_results.character1%TYPE
        ,xx_disposition_status          qa_results.character1%TYPE
        ,xx_disposition_status_criteria qa_results.comment1%TYPE
        ,xx_comments_long               qa_results.comment1%TYPE
        ); 
    TYPE t_disposition_status_tbl IS TABLE OF t_disposition_status_row INDEX BY BINARY_INTEGER;

    /* Debug Constants*/
    c_log_method             NUMBER := 1;  --0: no logging, 1: fnd_file.log, 2: fnd_log_messages, 3: dbms_output  (CHG0042815)
    c_output_header CONSTANT VARCHAR2(200) :=  '~~~Beginning of Output~~~';--Used for log file/debug statements
    c_output_footer CONSTANT VARCHAR2(200) :=  '~~~End of Output~~~';--Used for log file/debug statements

    /*  Constants for Collection Plan Result Views.
        These constants are for building the name of each collection plan
        results view.  The collection plan names in each org must be globally unique
        so the convention is to use a standard name with an org code suffix, for
        example, "NONCONFORMANCE_UME" and "RECEIVING_INSPECTION_IFK".
    */
    c_plan_type_code_n CONSTANT fnd_lookup_values.lookup_code%TYPE := 'XX_NONCONFORMANCE'; --Nonconformance Collection Plan Type Code
    c_plan_type_code_v CONSTANT fnd_lookup_values.lookup_code%TYPE := 'XX_VERIFY_NONCONFORMANCE'; --Verify Nonconformance Collection Plan Type Code
    c_plan_type_code_d CONSTANT fnd_lookup_values.lookup_code%TYPE := 'XX_DISPOSITION'; --Disposition Collection Plan Type Code
    c_plan_type_code_r CONSTANT fnd_lookup_values.lookup_code%TYPE := 'XX_RECEIVING_INSPECTION'; --Receiving Inspection Collection Plan Type Code [CHG0042754]

    /* Names of Collection Elements that act as a functional "primary key" for certain collection plans.  The values of these elements are auto-populated with a sequence value. */
    c_sequence_column_n CONSTANT qa_chars.name%TYPE := 'XX_NONCONFORMANCE_NUMBER'; --Auto-incrementing (sequence) column for the Nonconformance number.
    c_sequence_column_v CONSTANT qa_chars.name%TYPE := 'XX_VERIFY_NC_NUMBER'; --Auto-incrementing (sequence) column for the Verify Nonconformance number.
    c_sequence_column_d CONSTANT qa_chars.name%TYPE := 'XX_DISPOSITION_NUMBER'; --Auto-incrementing (sequence) column for the Disposition number.
    c_sequence_column_r CONSTANT qa_chars.name%TYPE := 'XX_RECEIVING_INSPECTION_NUMBER'; --Auto-incrementing (sequence) column for the Receiving Inspection number. [CHG0042754]

    /* On child plans we don't/can't assign the same "key" sequence column on the parent record (can't assign XX_NONCONFORANCE_NUMBER to a verification plan) so we use "reference' elements instead and assign the parent sequence number. */
    c_parent_sequence_column_n CONSTANT qa_chars.name%TYPE := c_sequence_column_n; --can't be null (even though there really isn't a parent) but this is use in a dynamic query so that causes a problem and we just reference
    c_parent_sequence_column_v CONSTANT qa_chars.name%TYPE := 'XX_NONCONFORMANCE_NO_REFERENCE'; --Nonconformance
    c_parent_sequence_column_d CONSTANT qa_chars.name%TYPE := 'XX_VERIFY_NC_NO_REFERENCE'; --Verify Nonconformance
    c_parent_sequence_column_r CONSTANT qa_chars.name%TYPE := c_sequence_column_r; --can't be null (even though there really isn't a parent) but this is use in a dynamic query so that causes a problem and we just reference

    /* Constants for important sequence columns in qa_results table (these are different than the named columns in the view columns above) CHG0042815. */
    c_key_seq_rcv_inspection_plan  CONSTANT all_tab_columns.column_name%TYPE := 'SEQUENCE1'; --Receiving Inspection Number is defined in this column on receiving inspection plans
    c_key_seq_nonconformance_plan  CONSTANT all_tab_columns.column_name%TYPE := 'SEQUENCE5'; --Nonconformance Number is defined in this column on nonconformance plans
    c_key_seq_verify_nc_plan       CONSTANT all_tab_columns.column_name%TYPE := 'SEQUENCE6'; --Verify Nonconformance number is defined in this column on verify nonconformance plans
    c_key_seq_disposition_plan     CONSTANT all_tab_columns.column_name%TYPE := 'SEQUENCE7'; --Disposition Number is defined in this column on disposition plans

    /* Sequence Column Value Prefixes (CHG0047103) */
    c_sequence_prefix_n CONSTANT qa_chars.sequence_prefix%TYPE := 'N';
    c_sequence_prefix_v CONSTANT qa_chars.sequence_prefix%TYPE := 'V';
    c_sequence_prefix_d CONSTANT qa_chars.sequence_prefix%TYPE := 'D';
    c_sequence_prefix_r CONSTANT qa_chars.sequence_prefix%TYPE := 'R';
    
    /* Collection Element Names for frequently-used elements in this package. (Names can be up to 30 characters.) */
    c_cen_nonconformance_status     CONSTANT qa_chars.name%TYPE := 'XX_NONCONFORMANCE_STATUS';
    c_cen_disposition_status        CONSTANT qa_chars.name%TYPE := 'XX_DISPOSITION_STATUS';
    c_cen_disposition               CONSTANT qa_chars.name%TYPE := 'XX_DISPOSITION';
    c_cen_buyer_email_address       CONSTANT qa_chars.name%TYPE := 'XX_BUYER_EMAIL_ADDRESS';
    c_cen_supplier_email_address    CONSTANT qa_chars.name%TYPE := 'XX_SUPPLIER_EMAIL_ADDRESS';
    c_cen_workflow_message          CONSTANT qa_chars.name%TYPE := 'XX_WORKFLOW_MESSAGE';--'XX_DOC_APPROVAL_WF_MESSAGE';--CHG0046276
    c_cen_move_order_number         CONSTANT qa_chars.name%TYPE := 'XX_DISPOSITION_MOVE_ORDER'; --CHG0047103
    c_cen_segregation_subinventory  CONSTANT qa_chars.name%TYPE := 'XX_SEGREGATION_SUBINVENTORY'; --CHG0047103
    c_cen_segregation_locator       CONSTANT qa_chars.name%TYPE := 'XX_SEGREGATION_LOCATOR'; --CHG0047103
    c_cen_production_subinventory   CONSTANT qa_chars.name%TYPE := 'XX_PRODUCTION_SUBINVENTORY'; --CHG0047103
    c_cen_production_locator        CONSTANT qa_chars.name%TYPE := 'XX_PRODUCTION_LOCATOR'; --CHG0047103
    
    /* Constants for Quality Nonconformance Statuses.  These are the same values that are in the LOVs on the Nonconformance collection plans. (CHG0042815: moved here from update_nonconformance_status procedure)*/
    c_nc_status_new CONSTANT qa_results.character1%TYPE := 'NEW'; -- (Nonconformance record created)
    c_nc_status_ver CONSTANT qa_results.character1%TYPE := 'VERIFIED'; -- (Verify Nonconformance record created)
    c_nc_status_dis CONSTANT qa_results.character1%TYPE := 'DISPOSITIONED'; -- (Disposition record created)
    c_nc_status_clo CONSTANT qa_results.character1%TYPE := 'CLOSED'; -- (Disposition executed)
    c_nc_status_can CONSTANT qa_results.character1%TYPE := 'CANCELLED'; -- (Processing of the Nonconformance is no longer required) Changed from CANCELED to CANCELLED --CHG0047103

    /* Constants for Quality Disposition Statuses.  These are the same values that are in the LOVs on the Disposition collection plans for XX_DISPOSITION_STATUS. (CHG0042815)*/
    c_d_status_new CONSTANT qa_results.character1%TYPE := 'NEW'; --
    c_d_status_pra CONSTANT qa_results.character1%TYPE := 'PRE_APPROVAL'; --CHG0047103
    c_d_status_pea CONSTANT qa_results.character1%TYPE := 'PENDING_APPROVAL'; --
    c_d_status_app CONSTANT qa_results.character1%TYPE := 'APPROVED'; --
    c_d_status_rej CONSTANT qa_results.character1%TYPE := 'REJECTED'; --
    c_d_status_pep CONSTANT qa_results.character1%TYPE := 'PENDING_PURCHASING'; --
    c_d_status_moc CONSTANT qa_results.character1%TYPE := 'MOVE_ORDER_CREATED'; --CHG004710
    c_d_status_exp CONSTANT qa_results.character1%TYPE := 'EXECUTION_PENDING'; --
    c_d_status_clo CONSTANT qa_results.character1%TYPE := 'CLOSED'; --
    c_d_status_can CONSTANT qa_results.character1%TYPE := 'CANCELLED'; --
    c_d_status_exc CONSTANT qa_results.character1%TYPE := 'EXCEPTION'; --
    c_d_status_eap CONSTANT qa_results.character1%TYPE := 'APPROVAL_EXCEPTION'; --CHG0047103
    c_d_status_emo CONSTANT qa_results.character1%TYPE := 'MOVE_ORDER_EXCEPTION'; --CHG0047103
    
    /* Constants for Quality Disposition Actions. (CHG0042815)*/
    c_d_action_uds CONSTANT qa_results.character1%TYPE := 'UPDATED_DISPOSITION_STATUS';
    c_d_action_awi CONSTANT qa_results.character1%TYPE := 'APPROVAL_WORKFLOW_INITIATED';--CHG0046276: value updated
    c_d_action_awc CONSTANT qa_results.character1%TYPE := 'APPROVAL_WORKFLOW_COMPLETED';--CHG0046276: value updated
    c_d_action_awr CONSTANT qa_results.character1%TYPE := 'APPROVAL_WORKFLOW_REJECTED';--CHG0046276: value updated
    c_d_action_awa CONSTANT qa_results.character1%TYPE := 'APPROVAL_WORKFLOW_ABORTED';--CHG0046276: value updated
    c_d_action_sad CONSTANT qa_results.character1%TYPE := 'SENT_APPROVED_DISP_NOTIF'; --
    
    /* Constants for Disposition Codes.  These are the same codes as in the LOV for the XX_DISPOSITION_ELEMENT. (CHG0042815) */
    c_disp_uai  CONSTANT qa_results.character1%TYPE := 'UAI'; --Use As-Is
    c_disp_ri   CONSTANT qa_results.character1%TYPE := 'RI'; --Repair Internally
    c_disp_rtv  CONSTANT qa_results.character1%TYPE := 'RTV'; --Return to Vendor
    c_disp_rav  CONSTANT qa_results.character1%TYPE := 'RAV'; --Repair at Vendor
    c_disp_s    CONSTANT qa_results.character1%TYPE := 'S'; --Scrap

    /* Constants for Quality Nonconformance Actions. (CHG0042815)
       Nonconformance Actions are not built-out like Disposition Actions.  We currently only 
       need a single NC action which will be written to the the Quality Action Log
       when the Nonconformance Status is updated programatically or manually by a user.
    */
    c_n_action_uns CONSTANT qa_results.character1%TYPE := 'UPDATED_NONCONFORMANCE_STATUS';

    /* Constants for Notification Types  These are the same codes as in the LOV for the XXQA_NC_PROCESS_NOTIFY_TYPES. (CHG0042815) */
    c_notification_type_spa CONSTANT fnd_lookup_values.lookup_code%TYPE := 'S_PRE_APPROVAL';     --Scrap Pre-Approval(CHG0047103)
    c_notification_type_sim CONSTANT fnd_lookup_values.lookup_code%TYPE := 'S_ISSUE_MATERIAL';   --Scrap Issue Material (CHG0047103)
    c_notification_type_rav CONSTANT fnd_lookup_values.lookup_code%TYPE := 'RAV_APPROVED';       --Repair at Vendor Disposition Approved
    c_notification_type_rtv CONSTANT fnd_lookup_values.lookup_code%TYPE := 'RTV_APPROVED';       --Return to Vendor Disposition Approved
    c_notification_type_rts CONSTANT fnd_lookup_values.lookup_code%TYPE := 'UAI_RETURN_TO_STOCK';--Return Use-As-Is Material to stock (CHG0047103)

    /* Supplier Contact "types" */
    c_sct_quality    CONSTANT VARCHAR2(10) := 'QUALITY'; --Contact type
    c_sct_purchasing CONSTANT VARCHAR2(10) := 'PURCHASING'; --Contact type

    /* Miscellaneous Constants */
    c_occurrence_column CONSTANT all_tab_columns.column_name%TYPE := 'OCCURRENCE'; --CHG0042815: qa_results.occurrence
    c_delimiter         CONSTANT VARCHAR2(1) := ','; --Delimiter for lists used in this package

    /* Doc Codes for XX Doc Approval workflow */
    c_wf_doc_code_scrap CONSTANT xxobjt_wf_docs.doc_code%TYPE := 'QA_NC_DISP_SCRAP'; --CHG0046276

    /* Application Short Names (CHG00471013) */
    c_asn_xxobjt CONSTANT fnd_application.application_short_name%TYPE:= 'XXOBJT';

    /* Short Names for key Concurrent Programs that are programatically-submitted as part of the Stratasys nonconformance mangament solution  (CHG00471013) */
    c_psn_ncr CONSTANT fnd_concurrent_programs.concurrent_program_name%TYPE := 'XXQA_NONCONFORMANCE_RPT';   --XXQA: Quality Nonconformance Report
    c_psn_rir CONSTANT fnd_concurrent_programs.concurrent_program_name%TYPE := 'XXQA_RCV_INSPECTION_RPT';   --XXQA: Quality Receiving Inspection Report
    c_psn_uns CONSTANT fnd_concurrent_programs.concurrent_program_name%TYPE := 'XXQA_UPDATE_NC_STATUS';     --XXQA: Update Nonconformance Status
    c_psn_ncn CONSTANT fnd_concurrent_programs.concurrent_program_name%TYPE := 'XXQA_NONCONFORMANCE_NOTIFY';--XXQA: Quality Nonconformance Notifications
    c_psn_mot CONSTANT fnd_concurrent_programs.concurrent_program_name%TYPE := 'XXINV_MOVE_ORDER_TRAVELER'; --XXINV: Move Order Traveler
    c_psn_cfl CONSTANT fnd_concurrent_programs.concurrent_program_name%TYPE := 'XXCPFILE';                  --XX: Copy File
 
    /* Workflow Management Options for XX Doc Approval related to Scrap dispositions (CHG047103) */
    c_wmo_cancel_all_create CONSTANT NUMBER := 1; --Cancel all existing workflows.  Create new workflow.
    c_wmo_keep_all_create   CONSTANT NUMBER := 2; --Don't cancel existing workflows.  Create new workflow.
    c_wmo_keep_last         CONSTANT NUMBER := 3; --Keep last existing in-process workflow only and cancel the rest.  Don't create new workflow.
    c_wmo_keep_first        CONSTANT NUMBER := 4; --Keep first existing in-process workflow only and cancel the rest.  Don't create new workflow.
    c_wmo_keep_all          CONSTANT NUMBER := 5; --Neither cancel nor create workflows.
    c_wmo_cancel_all        CONSTANT NUMBER := 6; --Cancel all existing workflows.  Do not create new workflow.

    /* Quality Results Update Methods (CHG0047103) */
    c_qrum_interface   CONSTANT    NUMBER := 0; --Update columns in qa_results via the standard Quality Results Interface
    c_qrum_direct      CONSTANT    NUMBER := 1; --Directly update columns in qa_results (no API or interface)

    /* Account IDs for issuing scrap related to dispositions.  Need to make these profiles. (CHG0047103) */
    c_scrap_acount_id_il    CONSTANT NUMBER := 409007; --10.000.580010.0000000.000.000.00.0000.000000
    c_scrap_acount_id_us    CONSTANT NUMBER := 5321008; --26.000.580010.000.000.00.000.0000

    /* Yes (Y) / No (N)*/
    c_yes CONSTANT VARCHAR(1) := 'Y';
    c_no  CONSTANT VARCHAR(1) := 'N';

    /* Global Variable declaration for Logging unit (CHG0042815) */
    gv_log              VARCHAR2(1)     := fnd_profile.value('AFLOG_ENABLED');  --FND: Debug Log Enabled (default="N")
    gv_log_module       VARCHAR2(100)   := fnd_profile.value('AFLOG_MODULE'); --FND: Debug Log Module (default="%")
    gv_api_name         VARCHAR2(30)    := 'xxqa_nonconformance_util_pkg';
    gv_log_program_unit VARCHAR2(100);

    /* Global Variable declaration for use with XXQA: Quality Nonconformance Notifications */
    gv_nc_rpt_tab           apps.xxqa_nc_rpt_tab_type; --CHG0042815
    gv_recipient_tab        apps.xxqa_recipient_tab_type; --CHG0042815
   
    /* Global variables to facilitate forms personalizations. */
    gv_fp_execute_procedure_result  VARCHAR2(1000); --Forms Personalization Execute a Procedure (Builtin action) result
 
    /* Parameter Variables (required for XML Publisher-based reports/programs, including the following
        -XXQA: Quality Nonconformance Report
        -XXQA: Quality Receiving Inspection Report
        -XXQA: Update Nonconformance Status
        -XXQA: Quality Nonconformance Notifications
        -XXQA: Initiate Disposition Approval (this is a PL/SQL concurrent program but it does set values for some of these parameter variables.
        -XXQA: Create Disposition Move Orders (this is a PL/SQL concurrent program but it does set values for some of these parameter variables.
    )*/
    p_organization_id               NUMBER;
    p_collection_id                 NUMBER; --CHG0042754
    p_nonconformance_number         qa_results.sequence5%TYPE;--CHG0047103 --VARCHAR2(8);
    p_verify_nonconformance_number  qa_results.sequence6%TYPE;--CHG0047103 --VARCHAR2(8);
    p_disposition_number            qa_results.sequence7%TYPE;--CHG0047103 --VARCHAR2(8);
    p_receiving_inspection_number   VARCHAR2(8); --CHG0042754
    p_print_verify_nc_result        VARCHAR2(3);
    p_print_report_header_footer    VARCHAR2(3);
    p_report_layout_name            VARCHAR2(30);
    p_update_nonconformance_status  VARCHAR2(3);
    p_notification_type_code        VARCHAR2(30); --CHG0042815: XXQA: Quality Nonconformance Notifications
    p_workflow_management_option    NUMBER; --CHG0047103: added ability to control the cancelation/creation of workflows as a technical tool to address process/tecnical exceptions.
    p_results_update_method         NUMBER; --CHG0047103: controls how qa_results table is update (direct update vs quality results interface)
    
    ----------------------------------------------------------------------------------------------------
    --  Name:               ncr_before_report
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      20-Jun-2018
    --  Purpose:            Before Report trigger for XXQA: Quality Nonconformance Report
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   20-Jun-2018   Hubert, Eric    CHG0042754: initial build
    FUNCTION ncr_before_report RETURN BOOLEAN;

    ----------------------------------------------------------------------------------------------------
    --  Name:               nonconformance_report_data
    --  Created By:         Hubert, Eric
    --  Revision:           1.2
    --  Creation Date:      Dec-2016
    --  Purpose:            CHG0040770 - Quality Nonconformance Report
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   Dec-2016      Hubert, Eric    S3 Initial Build
    --  1.1   12-June-2017  Lingaraj(TCS)   CHG0040770  - Quality Nonconformance Report
    --  1.2   21-May-2018   Hubert, Eric    Renamed "f_report_data" to "nonconformance_report_data"
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
        ) RETURN apps.xxqa_nc_rpt_tab_type;

    ----------------------------------------------------------------------------------------------------
    --  name:               report_sequence_parameter_lov
    --  Created By:         Hubert, Eric
    --  Revision:           1.2
    --  Creation Date:      Dec-2016
    --  Purpose:            CHG0040770 - Quality Nonconformance Report
    --                      See package body for detailed description.
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   Dec-2016      Hubert, Eric    S3 Initial Build
    --  1.1   12-June-2017  Lingaraj(TCS)   CHG0040770  - Quality Nonconformance Report
    --  1.2   20-Jun-2018   Hubert, Eric    CHG0042754:
    --                                      Renamed ""f_report_parameter_lov" to "report_sequence_parameter_lov" and added support for Receiving Inspection Number.
    --                                      Changed refernce of XXQA_NCR_SEQ_LOV_REC_TYPE to XXQA_RPT_SEQ_LOV_REC_TYPE.
    ----------------------------------------------------------------------------------------------------
    FUNCTION report_sequence_parameter_lov (
        p_plan_type_code  IN VARCHAR2
       ,p_organization_id IN NUMBER
    ) RETURN apps.xxqa_rpt_seq_lov_tab_type;

    ----------------------------------------------------------------------------------------------------
    --  Name:               print_nc_report
    --  Created By:         Hubert, Eric
    --  Revision:           1.3
    --  Creation Date:      31-Jul-2017
    --  Purpose :           This function will create a concurrent request for the
    --  'XXQA: Quality Nonconformance Report' (XXQANCR1).  The function has
    --  separate arguments for the Nonconformance Number, Verify Nonconformance
    --  Number, and Disposition Number.  This allows for the printing of a
    --  specific branch in the three-level parent-child collection plan
    --  hierarchy.  However, in practice, there will typically be only a single
    --  verification and disposition record for a given nonconformance, thus
    --  providing just the Nonconformacne Number is sufficient.
    --
    --  There is an argument for explicitly indicating which printer should be used,
    --  to bypass any rules within the function for determining which printer should
    --  be used.
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
        ,p_printer_name          IN VARCHAR2 --Optional printer name
        ,p_update_nc_status      IN VARCHAR2
        ,p_layout_name           IN VARCHAR2 --report Layout Name (CHG0042754)
        ,p_wait_for_completion   IN VARCHAR2 DEFAULT c_no --CHG0046276
    ) RETURN NUMBER; --Return Concurrent Request ID

    ----------------------------------------------------------------------------------------------------
    --  Name:               receiving_inspection_data
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      Dec-2016
    --  Purpose:            CHG0042754 - Receiving Inspection Report (formerly Inspection Release Sticker)
    --                      See package body for detailed description.
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   20-Jun-2018   Hubert, Eric    CHG0042754: Initial build
    ----------------------------------------------------------------------------------------------------
    FUNCTION receiving_inspection_data (
        p_sequence_1_value IN VARCHAR2 -- Receiving Inspection Number
        ,p_collection_id   IN NUMBER -- Collection ID in qa_results and plan view
        ,p_organization_id IN NUMBER
    ) RETURN apps.xxqa_ri_rpt_tab_type;

    ----------------------------------------------------------------------------------------------------
    --  Name:               print_ri_report
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      20-Jun-2018
    --  Purpose :           CHG0042754 - This function will create a concurrent request for the
    --  'XXQA: Quality Receiving Inspection Report' (XXQA_RCV_INSPECTION_RPT).
    --
    --  There is an argument for explicitly indicating which printer should be used,
    --  to bypass any rules within the function for determining which printer should
    --  be used.
    --
    --  A parameter to specify the layouts allows for building different visual
    --  layouts in the RTF template while using a standardized set of underlying data.
    --  The first layout implemented is to replace the legacy "Inspection Release
    --  Sticker".
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   20-Jun-2018   Hubert, Eric    CHG0042754: Initlai build
    ----------------------------------------------------------------------------------------------------
    FUNCTION print_ri_report (
        p_organization_id               IN NUMBER
        ,p_receiving_inspection_number  IN qa_results.sequence1%TYPE --Receiving Inspection Number
        ,p_collection_id                IN NUMBER --Collection_ID in qa_results table/plan view
        ,p_layout_name                  IN VARCHAR2 -- Layout code
        ,p_printer_name                 IN VARCHAR2 --Optional printer name
    ) RETURN NUMBER; --Return Concurrent Request ID

    ----------------------------------------------------------------------------------------------------
    --  Name:               p_plan_type
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      31-Jul-2017
    --  Purpose :           This procedure will return the Plan Type or a given
    --  collection plan, via the plan ID.
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   31-Jul-2017   Hubert, Eric    CHG0041284 - Add Tools menu item to print Quality Nonconformance Report from quality results forms
    --  1.1   01-Apr-2021   Hubert, Eric    CHG0049611 - Added functinality to get the plan type by specifying the occurrence instead
    ----------------------------------------------------------------------------------------------------
    FUNCTION plan_type (
        p_plan_id     IN NUMBER DEFAULT NULL
        ,p_occurrence IN NUMBER DEFAULT NULL)
    RETURN VARCHAR2;

    ----------------------------------------------------------------------------------------------------
    --  Name:               print_ncr_from_occurrence
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      31-Jul-2017
    --  Purpose :           This is a wrapper function for print_nc_report.  It
    --  simplifies the creation of the concurrent request for the report by only
    --  requiring the collection result occurrence, which is a unique ID number
    --  within the qa_results table.  From this occurrence, the required arguments
    --  can be determined to make a call of print_nc_report.
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   31-Jul-2017   Hubert, Eric    CHG0041284 - Add Tools menu item to print Quality Nonconformance Report from quality results forms
    ----------------------------------------------------------------------------------------------------
    FUNCTION print_ncr_from_occurrence (
        p_occurrence IN qa_results.occurrence%TYPE
    ) RETURN NUMBER; --Return Concurrent Request ID

    ----------------------------------------------------------------------------------------------------
    --  Name:               print_rir_from_collection_id
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      20-Jun-2018
    --  Purpose:            This is a wrapper function for print_ri_report.  It
    --  simplifies the creation of the concurrent request for the report by only
    --  requiring the collection result collection_id, which is an ID number
    --  within the qa_results common to all result rows (occurrences) saved at the
    --  same time.  From this collection_id, the required arguments
    --  can be determined to make a call of print_ri_report.  Multiple receiving
    --  inspection results could be printed via this function because multiple
    --  results may be associated with the collection_id.
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   20-Jun-2018   Hubert, Eric    CHG0042754: Initial build
    ----------------------------------------------------------------------------------------------------
    FUNCTION print_rir_from_collection_id (
        p_collection_id IN NUMBER
    ) RETURN NUMBER;

    ----------------------------------------------------------------------------------------------------
    --  Name:               print_rir_from_occurrence
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      20-Jun-2018
    --  Purpose:            This is a wrapper function for print_ri_report.  It
    --  simplifies the creation of the concurrent request for the report by only
    --  requiring the collection result occurrence, which is a unique ID number
    --  within the qa_results table.  From this occurrence, the required arguments
    --  can be determined to make a call of print_ri_report.
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   20-Jun-2018   Hubert, Eric    CHG0042754: Initial build
    ----------------------------------------------------------------------------------------------------
    FUNCTION print_rir_from_occurrence (
        p_occurrence IN qa_results.occurrence%TYPE
    ) RETURN NUMBER;

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
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   25-Jan-2019   Hubert, Eric    CHG0042589
    --  1.1   24-Oct-2019   Hubert, Eric    CHG0046276: added parameter p_plan_id
    --  1.2   01-Apr-2020   Hubert, Eric    CHG0047103: added parameter p_err_msg
    ----------------------------------------------------------------------------------------------------
    PROCEDURE update_result_value(
        p_plan_id        IN  qa_plans.plan_id%TYPE
        ,p_occurrence    IN  qa_results.occurrence%TYPE
        ,p_char_name     IN  qa_chars.name%TYPE
        ,p_new_value     IN  VARCHAR2 --
        ,p_err_code      OUT NUMBER --Status of the import process
        ,p_err_msg       OUT VARCHAR2 --CHG0047103
    );

    ----------------------------------------------------------------------------------------------------
    --  Name:               update_nonconformance_status
    --  Created By:         Hubert, Eric
    --  Revision:           1.1
    --  Creation Date:      20-Jun-2018
    --  Purpose:            Updates the Nonconformance Status element of a
    --  Nonconformance result record based on business rules.
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   20-Jun-2018   Hubert, Eric    CHG0042754
    --  1.1   01-Apr-2020   Hubert, Eric    CHG0047013: added p_results_update_method; default value for p_run_import
    ----------------------------------------------------------------------------------------------------
    PROCEDURE update_nonconformance_status (
         errbuf                  OUT VARCHAR2
        ,retcode                 OUT VARCHAR2
        ,p_organization_id       IN NUMBER
        ,p_nonconformance_number IN qa_results.sequence5%TYPE --Nonconformance Number
        ,p_verify_nc_number      IN qa_results.sequence6%TYPE DEFAULT NULL --Verify Nonconformance Number
        ,p_disposition_number    IN qa_results.sequence7%TYPE DEFAULT NULL--Disposition Number
        ,p_status_update_method  IN NUMBER DEFAULT c_qrum_direct --Addded parameter (CHG0047103)
        ,p_run_import            IN VARCHAR2 DEFAULT c_no -- Run Collection Import Manager after inserting records into interface table (added default 'N' - CHG0047103)
    );

    ----------------------------------------------------------------------------------------------------
    --  Name:               update_disposition_status
    --  Created By:         Hubert, Eric
    --  Revision:           1.2
    --  Creation Date:      16-Oct-2019
    --  Purpose:            Updates the Disposition Status element of a
    --    disposition record and manages related actions.
    --
    --  Description:
    --    Loops through all eligible dispositions and updates the status if needed.
    --    It is possible that a disposition could have its status updated
    --    multpile times as long as the business rules continue to be met.
    --
    --  In the future, the logic could be reimplemented as a true Oracle Workflow.
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   16-Oct-2019   Hubert, Eric    CHG0042815
    --  1.1   24-Oct-2019   Hubert, Eric    CHG0046276: pseudo-parallel branching for evaluating status rules
    --  1.2   01-Apr-2020   Hubert, Eric    CHG0047013: added p_results_update_method; default value for p_run_import
    ----------------------------------------------------------------------------------------------------
    PROCEDURE update_disposition_status (
         p_organization_id        IN NUMBER
        ,p_nonconformance_number  IN qa_results.sequence5%TYPE --Nonconformance Number
        ,p_verify_nc_number       IN qa_results.sequence6%TYPE DEFAULT NULL --Verify Nonconformance Number
        ,p_disposition_number     IN qa_results.sequence7%TYPE DEFAULT NULL--Disposition Number
        ,p_status_update_method   IN NUMBER DEFAULT c_qrum_direct --Addded parameter (CHG0047103)
        ,p_run_import             IN VARCHAR2 DEFAULT c_no -- Run Collection Import Manager after inserting records into interface table
        ,p_err_code               OUT NUMBER --CHG0047103
        ,p_err_msg                OUT VARCHAR2 --CHG0047103
    );

    ----------------------------------------------------------------------------------------------------
    --  Name:               collection_plan_view_name
    --  Created By:         Hubert, Eric
    --  Revision:           1.2
    --  Creation Date:      31-Jul-2017
    --  Purpose:            Returns the results view name for a plan type within
    --  a specific org. In the event that more than one plan for the type is
    --  found within an org, an exception is raised.
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   Dec-2016      Hubert, Eric    S3 Initial Build
    --  1.1   31-Jul-2017   Hubert, Eric    CHG0041284 - Add Tools menu item to print Quality Nonconformance Report from quality results forms
    --  1.2   13-Apr-2018   Hubert, Eric    CHG0042754 - Add ability to get import view name (could only get result view name prior to this).  Made function public.
    ----------------------------------------------------------------------------------------------------
    FUNCTION collection_plan_view_name (
        p_plan_type       IN VARCHAR2,
        p_organization_id IN NUMBER,
        p_view_type       IN VARCHAR2
    ) RETURN VARCHAR2;

    ----------------------------------------------------------------------------------------------------
    --  Name:               collection_plan_name
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      16-Oct-2019
    --  Purpose:            Returns the name of a collection plan for a plan type within
    --    a specific org. In the event that more than one plan for the type is
    --    found within an org, an exception is raised.
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   16-Oct-2019   Hubert, Eric    CHG0042815 - Initial Build
    ----------------------------------------------------------------------------------------------------
    FUNCTION collection_plan_name (
        p_plan_type        IN VARCHAR2
        ,p_organization_id IN NUMBER
    ) RETURN VARCHAR2;

    ----------------------------------------------------------------------------------------------------
    --  Name:               key_sequence_result_value
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      01-Apr-2020
    --  Purpose:            Get the value of an element on a result record given a key sequence number.
    --                      A key sequence number would be Nonconformance, Verify Nonconformance, Disposition, 
    --                      or Receiving Inspection Number.
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
        p_sequence_number    IN VARCHAR2 --Nonconformance, Verify Nonconformance, Disposition, or Receiving Inspection Number. 
        ,p_element_name      IN qa_chars.name%TYPE--Name of element related to the action
        ) RETURN VARCHAR2;

    ----------------------------------------------------------------------------------------------------
    --  Name:               build_action_log_message
    --  Created By:         Hubert, Eric
    --  Revision:           1.1
    --  Creation Date:      16-Oct-2019
    --  Purpose:            Builds a message for insertion into the Quality Action Log
    --
    --  Description:        This can be used for both Disposition Status updates
    --                      and Nonconformance Status updates.
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
        );

    ----------------------------------------------------------------------------------------------------
    --  Name:               log_manual_status_update
    --  Created By:         Hubert, Eric
    --  Revision:           1.1
    --  Creation Date:      16-Oct-2019
    --  Purpose:            Wrapper function to insert a row into the Quality 
    --                      Action Log from a Quality Action to log when 
    --                      a user manually changes a Diposition or Nonconformance
    --                      Status from the Update or Enter Quality Results
    --                      form.  Minimal parameters are required since much
    --                      of the required information will be inferred from
    --                      global variables and the Dynamic LOV temp table.
    --
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   16-Oct-2019   Hubert, Eric    CHG0042815
    --  1.1   01-Apr-2020   Hubert, Eric    CHG0047103: added p_old_status as optional
    ----------------------------------------------------------------------------------------------------

    PROCEDURE log_manual_status_update(
        p_new_status       IN VARCHAR2 --New Nonconformance or Disposition Status
        ,p_old_status      IN VARCHAR2 DEFAULT NULL --Helpful to see this in the log if known so added it as an optional parameter. (CHG0047103)
        ,p_sequence_number IN VARCHAR2 --Nonconformance or Disposition Number
        ,p_source_ref      IN VARCHAR2 DEFAULT NULL --Optional field to identify the source of the calling procedure (forms personalization, concurrent request, ad hoc script, etc.) (CHG0047103)

        );        

    ----------------------------------------------------------------------------------------------------
    --  Name:               result_element_value
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      16-Oct-2019
    --  Purpose:            Get the value of an arbitrary result element (column) value.
    --                               
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   16-Oct-2019   Hubert, Eric    CHG0042815
    ----------------------------------------------------------------------------------------------------

    PROCEDURE result_element_value(
          p_plan_name                   IN VARCHAR2
        , p_value_element_name          IN VARCHAR2
        , p_value_column_name           IN VARCHAR2
        , p_key_element_name            IN VARCHAR2
		, p_key_column_name             IN VARCHAR2
		, p_key_value                   IN VARCHAR2
        , p_return_foreign_tbl_val_flag IN VARCHAR2 DEFAULT c_no
		, p_err_code                    OUT NUMBER
		, p_return_value                OUT VARCHAR2
	);	

    ----------------------------------------------------------------------------------------------------
    --  Name:               user_element_result_value
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      16-Oct-2019
    --  Purpose:            Get the result value of an arbitrary user-defined (not hardcoded) element.
    --                               
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   16-Oct-2019   Hubert, Eric    CHG0042815
    ----------------------------------------------------------------------------------------------------
    FUNCTION user_element_result_value(
		 p_plan_name           IN VARCHAR2
        , p_value_element_name IN VARCHAR2
		, p_key_element_name   IN VARCHAR2
		, p_key_value          IN VARCHAR2
	) RETURN VARCHAR2;

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
    ----------------------------------------------------------------------------------------------------
    FUNCTION qa_notify_before_report RETURN BOOLEAN;

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
    ----------------------------------------------------------------------------------------------------     
    FUNCTION qa_notify_after_report RETURN BOOLEAN;

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
    FUNCTION get_nc_rpt_tab RETURN apps.xxqa_nc_rpt_tab_type;

    ----------------------------------------------------------------------------------------------------
    --  Name:               get_recipient_tab
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
    FUNCTION get_recipient_tab RETURN apps.xxqa_recipient_tab_type;

    ----------------------------------------------------------------------------------------------------
    --  Name:               supplier_contact_email_list
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
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
    --  1.0   16-Oct-2019   Hubert, Eric    CHG0042815
    ---------------------------------------------------------------------------------------------------- 
    FUNCTION supplier_contact_email_list (
         p_vendor_name       IN VARCHAR2
        ,p_vendor_site_code  IN VARCHAR2
        ,p_contact_type      IN VARCHAR2
        ) RETURN VARCHAR2;

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
    RETURN VARCHAR2;

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
    RETURN VARCHAR2;
        
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
    FUNCTION is_xml(p_xml IN CLOB)
    RETURN NUMBER;

    ----------------------------------------------------------------------------------------------------
    --  Name:               create_quality_action_log_row
    --  Created By:         Hubert, Eric
    --  Revision:           1.1
    --  Creation Date:      16-Oct-2019 
    --  Purpose:            Insert a row into the Quality Action Log.
    --                               
    --  Description: This function is modeled after QLTDACTB.INSERT_ACTION_LOG.
    --
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   16-Oct-2019   Hubert, Eric    CHG0042815
    --  1.1   24-Oct-2019   Hubert, Eric    CHG0046276: made public procedure
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
        p_concurrent    IN NUMBER,
        p_log_number    OUT NUMBER);
   
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
    --  1.0   24-Oct-2019     Hubert, Eric    CHG0046276
    ----------------------------------------------------------------------------------------------------    
    PROCEDURE wf_scrap_approver_username(
        p_doc_instance_id   IN  NUMBER --Workflow instance
        ,p_level            IN  NUMBER --Level in scrap approval hierarchy
        ,p_approver         OUT VARCHAR2 --username
        ,p_err_code         OUT NUMBER
        ,p_err_msg          OUT VARCHAR2
        );
        
    ----------------------------------------------------------------------------------------------------
    --  Name:               override_disposition_status
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      01-Apr-2020
    --  Purpose:            Take action on changes to the Disposition Status element.
    --                               
    --  Description: 
    --
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   01-Apr-2020   Hubert, Eric    CHG0047103: refactored
    ----------------------------------------------------------------------------------------------------    
    PROCEDURE override_disposition_status(
        p_disposition_number IN qa_results.sequence7%TYPE
        ,p_occurrence        IN qa_results.occurrence%TYPE
        ,p_new_status        IN VARCHAR2
        ,p_source_ref        IN VARCHAR2 DEFAULT NULL --Optional field to identify the source of the calling procedure (forms personalization, concurrent request, ad hoc script, etc.)
        ,p_err_code          OUT NUMBER
        ,p_err_msg           OUT VARCHAR2
    );

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
    ) RETURN VARCHAR2;

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
        );

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
    ----------------------------------------------------------------------------------------------------           
    PROCEDURE wf_doc_approval_event_handler(
        p_doc_instance_id   IN NUMBER,
        p_event_name        IN VARCHAR2,
        p_err_code          OUT NUMBER,
        p_err_msg           OUT VARCHAR2        
        );    

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
    ) RETURN xxobjt_wf_doc_history_v%ROWTYPE;

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
        ,p_note              IN VARCHAR2 DEFAULT NULL
        )
    RETURN qa_results.character1%TYPE;

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
    --                                        -Simplify procedure to just return open workflows.
    --                                        -Move code to abort workflows to wf_abort_disposition_approvals.
    ---------------------------------------------------------------------------------------------------- 
    PROCEDURE wf_inquire_open_doc_approvals(
        p_disposition_number   IN  qa_results.sequence7%TYPE
        ,p_doc_code            IN  xxobjt_wf_docs.doc_code%TYPE
        ,p_open_doc_count      OUT NUMBER);

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
    ) RETURN VARCHAR2;

    ----------------------------------------------------------------------------------------------------
    --  Name:               wf_get_notification_body_scrap
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      01-Apr-2020
    --  Purpose:            Public procedure to get HTML body for approval notifications/emails, called
    --                      from XX Doc Approval extension.
    --                               
    --  Description:        See wf_get_notification_body_scrap for details.
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   01-Apr-2020   Hubert, Eric    CHG0047103: initial build
    ----------------------------------------------------------------------------------------------------    
    PROCEDURE wf_get_notification_body_scrap(
        p_document_id        IN VARCHAR2, --doc instance _id
        p_display_type       IN VARCHAR2,
        p_document           IN OUT NOCOPY CLOB,
        p_document_type      IN OUT NOCOPY VARCHAR2
    );

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
        );

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
    FUNCTION wf_notification_subject(p_doc_instance_id IN NUMBER) RETURN VARCHAR2;

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
    ) RETURN VARCHAR2;
	
    ----------------------------------------------------------------------------------------------------
    --  Name:               mo_create_disp_move_order
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      01-Apr-2020
    --  Purpose:            Create a move order in response to a Scrap or Use As-Is disposition being approved
    --                      
    --                      
    --
    --  Parameters :
    --       Name             Type    Purpose
    --       --------         ----    -----------
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date            Name            Desc
    --  1.0   01-Apr-2020     Hubert, Eric    CHG0047103: initial build
    ----------------------------------------------------------------------------------------------------
    PROCEDURE mo_create_disp_move_order(
        p_nvd_record            IN  apps.xxqa_nc_rpt_rec_type
        ,p_move_order_number    OUT mtl_txn_request_headers.request_number%TYPE
        ,p_err_code             OUT NUMBER
        ,p_err_msg              OUT VARCHAR2
    );

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
    );

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
    );

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
        ) RETURN VARCHAR2;

    ----------------------------------------------------------------------------------------------------
    --  Name:               directory_path
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      01-Apr-2020
    --  Purpose:            Get the directory path for an Oracle EBS directory name.
    --
    --  Parameters :
    --       Name             Type    Purpose
    --       --------         ----    -----------
    --       p_directory_name IN      Provide name of directory
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date            Name            Desc
    --  1.0   01-Apr-2020     Hubert, Eric    CHG0047103: initial build
    ----------------------------------------------------------------------------------------------------  
    FUNCTION directory_path(p_directory_name IN VARCHAR2) RETURN VARCHAR2;

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
    --  Ver   Date            Name            Desc
    --  1.0   01-Apr-2020    Hubert, Eric    CHG0047103: initial build
    ----------------------------------------------------------------------------------------------------  
    FUNCTION is_file_exists (
        p_directory_name IN VARCHAR2
        ,p_filename IN VARCHAR2
    ) RETURN VARCHAR2;

    ----------------------------------------------------------------------------------------------------
    --  Name:               set_global_value
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      01-Apr-2020
    --  Purpose:            Set the value of a global variable defined for this package.
    --
    --  Parameters :
    --       Name             Type    Purpose
    --       --------         ----    -----------
    --  **Are get_global_value and set_global_value needed?  I don't see code referencing them in this package, quality actions, or forms personalizations.      
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date            Name            Desc
    --  1.0   01-Apr-2020    Hubert, Eric    CHG0047103: initial build
    ---------------------------------------------------------------------------------------------------- 
    PROCEDURE set_global_value(
        p_variable_name IN  VARCHAR2
        ,p_value        IN  VARCHAR2
        ,p_err_code     OUT NUMBER
        ,p_err_msg      OUT VARCHAR
    );

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
    ----------------------------------------------------------------------------------------------------
    
    FUNCTION get_global_value(
        p_variable_name IN VARCHAR2
    ) RETURN VARCHAR2;

    ----------------------------------------------------------------------------------------------------
    --  Name:               get_mrb_location
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      01-Apr-2020
    --  Purpose:            Get information about the location of the material.  This includes both the
    --                      segregation subinventory (MRB) and the subinventory/locator where it resided
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
        ,p_transaction_reference IN mtl_material_transactions.transaction_reference%TYPE
        ,p_element_name          IN qa_chars.name%TYPE
    ) RETURN VARCHAR2;

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
                                    );

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
    ----------------------------------------------------------------------------------------------------
    PROCEDURE mo_disposition_mgr_wrapper(
                                    errbuf                          OUT VARCHAR2,
                                    retcode                         OUT VARCHAR2,
                                    p_organization_id               IN NUMBER, --Required
                                    p_disposition                   IN VARCHAR2 DEFAULT NULL,
                                    p_nonconformance_number         IN VARCHAR2 DEFAULT NULL,
                                    p_verify_nonconformance_number  IN VARCHAR2 DEFAULT NULL,
                                    p_disposition_number            IN VARCHAR2 DEFAULT NULL
                                    );
END xxqa_nonconformance_util_pkg;
/
