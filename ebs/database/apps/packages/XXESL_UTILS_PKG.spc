-----------------------------------------------------------------------
--  Name:               xxesl_utils_pkg
--  Created by:         Hubert, Eric
--  Revision:           1.0
--  Creation Date:      05-Jan-2021
--  Purpose:            Utilities for Electronic Shelf Labels (ESL)
----------------------------------------------------------------------------------
--  Ver   Date          Name            Desc
--  1.0   05-Jan-2021   Eric Hubert     CHG0048556: initial build
----------------------------------------------------------------------------------

CREATE OR REPLACE PACKAGE apps.xxesl_utils_pkg AS
    /* Global Variable declaration for Logging unit (CHG0048556) */
    gv_log              VARCHAR2(1)     := fnd_profile.value('AFLOG_ENABLED');  --FND: Debug Log Enabled (default="N")
    gv_log_module       VARCHAR2(100)   := fnd_profile.value('AFLOG_MODULE'); --FND: Debug Log Module (default="%")
    gv_api_name         VARCHAR2(30)    := 'XXESL_UTILS_PKG';
    gv_log_program_unit VARCHAR2(100);

    /* Debug Constants*/
    c_log_method             NUMBER := 1;  --0: no logging, 1: fnd_file.log, 2: fnd_log_messages, 3: dbms_output  (CHG0048556)
    
    /* Constants representing the name of each ESL manufacturer */
    c_em_sesl CONSTANT fnd_flex_values.flex_value%TYPE := 'SES_IMAGOTAG'; --SES-imagotag (the prefix "SESL" also refers to this manufacturer as well-some procedures and tables use the to indicate that they are specific to SES-Imagotag.)
    
    /* Constants specific to SES-imagotag's "Bossard" button ESLs.
      These values correspond to the "<Type>" element in label events.
    */
    c_esl_btn_option_2  CONSTANT VARCHAR(30) := 'BUTTONS_2'; --The type of buttons that ESL models have are maintained on the XX_ESL_MODELS_OMA collection plan.
    c_btn_shopping_cart CONSTANT NUMBER := 1; --Button with a shopping cart icon.  Value corresponds to the event type reported by the button to the core server.
    c_btn_check_mark    CONSTANT NUMBER := 2; --Button with a checkmark icon.  Value corresponds to the event type reported by the button to the core server.
    
    /* SES-imagotag constants for "useful" GET resources (URI Path values); this is not a complete list. */
    c_getregisteredaccesspoints CONSTANT VARCHAR2(50) := '/service/accesspoint';
    c_getaccesspoints           CONSTANT VARCHAR2(50) := '/service/accesspointinfo';
    c_getconfiguration          CONSTANT VARCHAR2(50) := '/service/configuration';
    c_getlabels                 CONSTANT VARCHAR2(50) := '/service/labelinfo';
    c_getevents                 CONSTANT VARCHAR2(50) := '/service/labelevent';
    c_getregisteredlabels       CONSTANT VARCHAR2(50) := '/service/label';--No paged results
    c_getproblems               CONSTANT VARCHAR2(50) := '/service/problem';--No paged results
    c_getservicestatus          CONSTANT VARCHAR2(50) := '/service/status';--No paged results
    c_gettags                   CONSTANT VARCHAR2(50) := '/service/tag';
    c_gettemplates              CONSTANT VARCHAR2(50) := '/service/template';
    c_getinvalidtemplates       CONSTANT VARCHAR2(50) := '/service/template/invalid';
    c_getallupdates             CONSTANT VARCHAR2(50) := '/service/updatestatus';
    c_getunsuccessfulupdates    CONSTANT VARCHAR2(50) := '/service/updatestatus/unsuccessful';
    c_getwaitingupdates         CONSTANT VARCHAR2(50) := '/service/updatestatus/waiting';                    
    c_exportusers               CONSTANT VARCHAR2(50) := '/service/export/level1/user'; --No paged results 
    c_exportconfigurationkeys   CONSTANT VARCHAR2(50) := '/service/export/level1/configuration'; --No paged results 
    c_exportlicenses            CONSTANT VARCHAR2(50) := '/service/export/level1/license'; --No paged results
    
    /* SES-imagotag constants for "useful" resources using POST (URI Path values); this is not a complete list. */
    c_getrenderingdocument      CONSTANT VARCHAR2(50) := '/service/task/preview/document';
    c_getrenderingimage         CONSTANT VARCHAR2(50) := '/service/task/preview/image';
    c_getrenderingsourcerecord  CONSTANT VARCHAR2(50) := '/service/task/preview/source';
    c_scheduletasks             CONSTANT VARCHAR2(50) := '/service/task';
    c_registerlabels            CONSTANT VARCHAR2(50) := '/service/label';
    c_unlocklabels              CONSTANT VARCHAR2(50) := '/service/label/unlock';
    c_unregisterlabels          CONSTANT VARCHAR2(50) := '/service/label/unregister';
    
    /* Process Flag values for importing data from ESL server. */
    pf_1 CONSTANT NUMBER := 1; --Unprocessed
    pf_2 CONSTANT NUMBER := 2; --Imported
    pf_3 CONSTANT NUMBER := 3; --Ignored/bypassed
    pf_4 CONSTANT NUMBER := 4; --Exception

    /* Key collection plan and element names: */
    c_cpn_esl_registry      CONSTANT qa_plans.name%TYPE := 'XX_ESL_REGISTRY_OMA';
    c_cen_esl_event_id      CONSTANT qa_chars.name%TYPE := 'XX_ESL_EVENT_ID';

    /* CHG0048556 */
    FUNCTION ebssvr_tz_offset RETURN VARCHAR2;

    /* CHG0048556 */
    FUNCTION eslsvr_db_time_diff (
        p_esl_mfg_code     IN fnd_flex_values.flex_value%TYPE--SES-imagotag is the initially-supported ESL manufacturer
        ,p_force_recheck   IN BOOLEAN   DEFAULT FALSE --recalculate or use the stored value
    ) RETURN INTERVAL DAY TO SECOND;

    /* CHG0048556 */
    FUNCTION local_datetime(
        p_date                  IN DATE     DEFAULT SYSDATE
        ,p_timezone_id_from     IN NUMBER   DEFAULT fnd_profile.value('SERVER_TIMEZONE_ID')
        ,p_timezone_id_to       IN NUMBER   DEFAULT fnd_profile.value('CLIENT_TIMEZONE_ID')
        ,p_datetime_format_to   IN VARCHAR2 DEFAULT 'DD-MON-YYYY HH:MI:SS AM TZD' --Format of the Date/Time that is returned
    ) RETURN VARCHAR2;

    /* CHG0048556 */
    FUNCTION utl_get_db_xml_doc (
        p_file_name IN xxesl_util_xml_documents.doc_name%TYPE
    ) RETURN XMLTYPE;

    /* CHG0048556 */
    FUNCTION utl_record_count_in_xml (
        p_xml           IN  XMLTYPE
        ,p_record_path  IN  VARCHAR2
    ) RETURN NUMBER;

    /* CHG0048556 */
    PROCEDURE eslsvr_create_resource (
        p_esl_mfg_code      IN fnd_flex_values.flex_value%TYPE
        ,p_resource_name    IN VARCHAR2
        ,p_payload_xml      IN XMLTYPE
        ,p_err_code         OUT NUMBER
        ,p_err_msg          OUT VARCHAR2
    );

    /* CHG0048556 */
    PROCEDURE eslsvr_import_label_events (
        p_esl_mfg_code  IN fnd_flex_values.flex_value%TYPE
        ,p_org_id       IN NUMBER
        ,p_err_code     OUT NUMBER
        ,p_err_msg      OUT VARCHAR2
    );
    
    --/* CHG0048556 */
    --PROCEDURE eslsvr_import_labels ( [FUTURE]
    --    p_esl_mfg_code  IN fnd_flex_values.flex_value%TYPE
    --    ,p_err_code     OUT NUMBER
    --    ,p_err_msg      OUT VARCHAR2
    --);

    /* CHG0048556 */
    PROCEDURE sesl_event_row(
        p_event_id      IN VARCHAR2
        ,p_event_row    OUT xxesl_label_events_sesl%ROWTYPE
        ,p_err_code     OUT NUMBER
        ,p_err_msg      OUT VARCHAR2
    );
    
    /* CHG0048556 */
    PROCEDURE sesl_ignore_old_events(
        p_err_code     OUT NUMBER
        ,p_err_msg      OUT VARCHAR2
    );
    
    /* CHG0048556 */
    PROCEDURE esl_registry_row(
        p_esl_id        IN  VARCHAR2
        ,p_registry_row OUT q_xx_esl_registry_oma_v%ROWTYPE
        ,p_err_code     OUT NUMBER
        ,p_err_msg      OUT VARCHAR2
    );

    /* CHG0048556 */
    PROCEDURE esl_system_row(
        p_esl_mfg_code  IN fnd_flex_values.flex_value%TYPE
        ,p_system_row   OUT q_xx_esl_systems_oma_v%ROWTYPE
        ,p_err_code     OUT NUMBER
        ,p_err_msg      OUT VARCHAR2
    );
    
    /* CHG0048556 */
    PROCEDURE sesl_retrieve_info (
        p_uri_path          IN  VARCHAR2
        ,p_records_per_page IN  NUMBER
        ,p_xml_response     OUT  XMLTYPE
        ,p_err_code         OUT NUMBER
        ,p_err_msg          OUT VARCHAR2
    );

    /* CHG0048556 */
    PROCEDURE sesl_retrieve_labelevents (
        p_err_code  OUT NUMBER
        ,p_err_msg  OUT VARCHAR2
    );

    /* CHG0048556 */
    PROCEDURE sesl_update_event_process_flag (
        p_event_id          VARCHAR2
        ,p_process_flag     NUMBER
        ,p_err_code         OUT NUMBER
        ,p_err_msg          OUT VARCHAR2
    );

    /* CHG0048556 */
    PROCEDURE eslreg_update_label_event(
        p_esl_mfg_code       IN fnd_flex_values.flex_value%TYPE
        ,p_esl_id            IN VARCHAR2
        ,p_event_id          IN VARCHAR2
        ,p_err_code          OUT NUMBER
        ,p_err_msg           OUT VARCHAR2
    ); 

    /* CHG0048556 */
    PROCEDURE update_result_value(
        p_plan_id        IN  qa_plans.plan_id%TYPE
        ,p_occurrence    IN  qa_results.occurrence%TYPE
        ,p_char_name     IN  qa_chars.name%TYPE
        ,p_new_value     IN  VARCHAR2
        ,p_err_code      OUT NUMBER
        ,p_err_msg       OUT VARCHAR2
    );

    /* CHG0048556 */
    PROCEDURE update_unassigned_esl_displays (
        errbuf              OUT VARCHAR2
        ,retcode            OUT NUMBER
        ,p_esl_mfg_code     IN fnd_flex_values.flex_value%TYPE
        ,p_esl_model_code   IN VARCHAR2
    );

    /* CHG0048556 */
    PROCEDURE utl_get_request(
        p_url           IN  VARCHAR2
        ,p_response     OUT CLOB
        ,p_err_code     OUT NUMBER
        ,p_err_msg      OUT VARCHAR2
    );

    /* CHG0048556 */
    PROCEDURE utl_post_request(
        p_url           IN  VARCHAR2
        ,p_content      IN  CLOB
        ,p_content_type IN  VARCHAR2
        ,p_err_code     OUT NUMBER
        ,p_err_msg      OUT VARCHAR2
    );
    
    /* CHG0048556 */
    PROCEDURE utl_purge_esl_table (
        errbuf                      OUT VARCHAR2,
        retcode                     OUT NUMBER,
        p_esl_table_name            IN  dba_tables.table_name%TYPE,
        p_purge_before_date_text    IN  VARCHAR2
    );
    
    /* CHG0048556 */
    PROCEDURE utl_split_payload (
        p_payload_xml       IN XMLTYPE
        ,p_record_path      IN VARCHAR2
        ,p_index            IN NUMBER --record index
        ,p_records          IN NUMBER
        ,p_xml_chunk        OUT XMLTYPE
        ,p_err_code         OUT NUMBER
        ,p_err_msg          OUT VARCHAR2
    );
    
    /* CHG0048556 */
    PROCEDURE utl_update_xml_doc_from_file (
        errbuf              OUT VARCHAR2,
        retcode             OUT NUMBER,
        p_directory         IN  VARCHAR2, --Oracle directory mapped to shared folder
        p_file_name         IN  VARCHAR2, --Source file name (in shared folder)
        p_char_set_name     IN  VARCHAR2, --Oracle name for character set (see https://docs.oracle.com/cd/B28359_01/server.111/b28298/applocaledata.htm#i635047)
        p_doc_name          IN  VARCHAR2, --doc_name column
        p_doc_schema        IN  VARCHAR2, --doc_schema column
        p_doc_desc          IN  VARCHAR2, --description column
        p_delete_flag       IN  VARCHAR2 DEFAULT 'N' --Delete file if 'Y'
    );
END xxesl_utils_pkg;
/