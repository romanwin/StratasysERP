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

CREATE OR REPLACE PACKAGE BODY apps.xxesl_utils_pkg AS
    /* MIME Types */
    c_mime_type_xml     CONSTANT VARCHAR2(30) := 'application/xml';
    c_mime_type_json    CONSTANT VARCHAR2(30) := 'application/json';
    c_mime_type_default CONSTANT VARCHAR2(30) := c_mime_type_xml;    
    
    /* HTTP Protocols */
    c_http_protocol_default CONSTANT VARCHAR2(30) := 'HTTP/1.1';
    
    /* HTTP Methods */
    c_http_method_get  CONSTANT VARCHAR2(30) := 'GET';
    c_http_method_post CONSTANT VARCHAR2(30) := 'POST';
   
    /* Misc. SES-imagotag constants */
    c_ssys_root_element CONSTANT VARCHAR2(30) := 'ssysCompositeSeslResponse'; --name of root element under which pages responses will be combined
 
    c_iso_8601_to_timestamp_tz_1    CONSTANT VARCHAR2(50) := 'yyyy-mm-dd"T"hh24:mi:ss.ff3tzh:tzm'; --Convert SES core server event date (ISO 8601) to Oracle timestamp 2015-02-23T16:26:41.485+05:30 >> 2015-02-23 16:26:41.485000 +05:30

    /* Constants for common values */
    c_yes CONSTANT VARCHAR2(1) := 'Y';
    c_no  CONSTANT VARCHAR2(1) := 'N';

    /* Return/error codes for procedures */
    c_success      CONSTANT NUMBER := 0; --Success
    c_fail         CONSTANT NUMBER := 1; --Fail

    /* Retcode values for concurrent programs */
    c_retcode_s     CONSTANT NUMBER := 0; --Success
    c_retcode_sw    CONSTANT NUMBER := 1; --Success with Warning
    c_retcode_e     CONSTANT NUMBER := 2; --Error

    /* Private variables to package body */
    v_server_time_diff INTERVAL DAY TO SECOND;
    
--------------------------------------------------------------------------------
/* Forward Declarations - Start: */
--------------------------------------------------------------------------------
    PROCEDURE write_message(
        p_msg VARCHAR2
        ,p_file_name VARCHAR2 DEFAULT fnd_file.log
    );

--------------------------------------------------------------------------------
/* Forward Declarations - End */
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
/* Private Functions - Start: */
--------------------------------------------------------------------------------
    ----------------------------------------------------------------------------------------------------
    --  Name:               utl_print_clob_to_output
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      05-Jan-2021
    --  Purpose:            Send contents of a CLOB to write_message for debugging purposes.
    --                               
    --  Description:        
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   05-Jan-2021   Eric Hubert     CHG0048556: initial build
    ----------------------------------------------------------------------------------------------------
    PROCEDURE utl_print_output_clob (p_clob IN CLOB)  
    IS
        c_method_name   CONSTANT VARCHAR(30) := 'utl_print_output_clob';
        c_length        CONSTANT NUMBER := 255;
           l_offset     NUMBER := 1;  
    BEGIN  
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('Start of: ' || c_method_name);
   
        LOOP  
            EXIT WHEN l_offset > dbms_lob.getlength(p_clob);  
            
            dbms_output.put_line(
                dbms_lob.substr(
                    lob_loc => p_clob,
                    amount => c_length,
                    offset =>l_offset
                )
            );  
            
            l_offset := l_offset + c_length;  
        END LOOP;  
    END utl_print_output_clob;

    ----------------------------------------------------------------------------------------------------
    --  Name:               utl_xml_combine
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      05-Jan-2021
    --  Purpose:            Combine multiple XML responses into a single file/doc
    --                               
    --  Description:        
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   05-Jan-2021   Eric Hubert     CHG0048556: initial build
    ----------------------------------------------------------------------------------------------------
    FUNCTION utl_xml_combine (
         p_xml_parent   IN  XMLTYPE
        ,p_xml_child    IN  XMLTYPE

    ) RETURN XMLTYPE
    IS
        c_method_name CONSTANT VARCHAR(30) := 'utl_xml_combine';
    
        l_dp    dbms_xmldom.domdocument; --Parent Document
        l_np    dbms_xmldom.domnode;     --Parent Node
        l_dc    dbms_xmldom.domdocument; --Child Document
        l_ec    dbms_xmldom.domelement;  --Child Element
        l_nc    dbms_xmldom.domnode;     --Child Node
        xml_result  XMLTYPE; --Return value                   

    BEGIN 
        gv_log_program_unit := c_method_name; --store procedure name for logging
        --write_message('Start of: ' || c_method_name);
        
        /* Create parent document from first XML */
        l_dp := dbms_xmldom.newdomdocument(xmldoc => p_xml_parent);--Returns a new DOMDOCUMENT instance created from the specified XMLType object.

        /* Get the root node for the parent document. */
        l_np := dbms_xmldom.makenode(doc => l_dp);    --Casts the DOMDOCUMENT to a DOMNODE, and returns that DOMNODE.
        l_np := dbms_xmldom.getfirstchild(n => l_np); --Retrieves the first child of this node. If there is no such node, this returns NULL.

        /* Create the child document, that will be appended to the first, using the second XML. */  
        l_dc := dbms_xmldom.newdomdocument(xmldoc => p_xml_child); 
        
        /* Get the root element from the child document created above. */
        l_ec := dbms_xmldom.getdocumentelement(doc => l_dc);  

        /* Get the node from the child document. */
        l_nc := dbms_xmldom.importnode(
                    doc           => l_dp
                    ,importedNode => dbms_xmldom.makenode(elem => l_ec)
                    ,deep         => TRUE
                );  
    
        /* Converts the child node to an element. */
        l_ec := dbms_xmldom.makeelement(l_nc);  

        /* Add the child element to the parent node. */  
        l_np := dbms_xmldom.appendchild(
                    l_np
                    ,dbms_xmldom.makenode(l_ec)
                );

        /* Convert to XMLTYPE. */
        xml_result := dbms_xmldom.getxmltype(l_dp);

        dbms_xmldom.freedocument(l_dp);
        dbms_xmldom.freedocument(l_dc);
        
        RETURN xml_result;
        
    EXCEPTION
        WHEN OTHERS THEN
            write_message(c_method_name || ': ' || SQLERRM);
            RETURN NULL;
    END utl_xml_combine;

--------------------------------------------------------------------------------
/* Private Functions - End */
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
/* Public Functions - Start: */
--------------------------------------------------------------------------------
    ----------------------------------------------------------------------------------------------------
    --  Name:               ebssvr_tz_offset
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      05-Jan-2021
    --  Purpose:            Get the Oracle EBS application server timezone offset from GMT
    --                               
    --  Description:        Date/time comparisons are done between Oracle and ESL systems.  This 
    --                      function facilitates an accurate comparison by making sure we know
    --                      the time zone in which the EBS server is running.
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   05-Jan-2021   Eric Hubert     CHG0048556: initial build
    ----------------------------------------------------------------------------------------------------
    FUNCTION ebssvr_tz_offset RETURN VARCHAR2
    IS
        c_method_name CONSTANT VARCHAR(30) := 'utl_get_db_xml_doc';
          
        l_tz_id     NUMBER;
        l_result    VARCHAR2(6);
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        --write_message('Start of: ' || c_method_name);

        l_tz_id := fnd_profile.value('SERVER_TIMEZONE_ID');
        
        SELECT TZ_OFFSET(timezone_code)
        INTO l_result
        FROM fnd_timezones_vl
        WHERE upgrade_tz_id = l_tz_id;
        
        RETURN l_result;
        
    EXCEPTION
        WHEN OTHERS THEN
            write_message(c_method_name || ': ' || SQLERRM);
            RETURN NULL;        
    END ebssvr_tz_offset;

    ----------------------------------------------------------------------------------------------------
    --  Name:               eslsvr_db_time_diff
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      05-Jan-2021
    --  Purpose:            Determine the time difference between the ESL server and the Oracle database.
    --                      This does not account for any lag in the server response but in practice
    --                      it should not be an issue for the intended uses of this function.     
    --         
    --  Description:        Date/time comparisons are done between Oracle and ESL systems.  This 
    --                      function facilitates an accurate comparison by estimating
    --                      the time difference betwen Oracle and an ESL server.  In practice, this
    --                      will be a very small amount
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   05-Jan-2021   Eric Hubert     CHG0048556: initial build
    ----------------------------------------------------------------------------------------------------
    FUNCTION eslsvr_db_time_diff (
        p_esl_mfg_code     IN fnd_flex_values.flex_value%TYPE--SES-imagotag is the initially-supported ESL manufacturer
        ,p_force_recheck   IN BOOLEAN   DEFAULT FALSE --recalculate or usethe stored value
    ) RETURN INTERVAL DAY TO SECOND
    IS
        c_method_name CONSTANT VARCHAR(30) := 'eslsvr_db_time_diff';
        
        l_xml_response              XMLTYPE;
        l_err_code                  NUMBER;
        l_err_msg                   VARCHAR2(1000);
        l_iso_server_time_string    VARCHAR2(50);
        l_iso_server_time_ts        TIMESTAMP WITH TIME ZONE;--TIMESTAMP;
        l_result                    INTERVAL DAY TO SECOND;
    
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('Start of: ' || c_method_name);
         
        IF p_force_recheck OR v_server_time_diff IS NULL THEN

            --write_message('Need to ask ESL server its time');

            IF p_esl_mfg_code = c_em_sesl THEN 
                sesl_retrieve_info (
                    p_uri_path          => c_getservicestatus
                    ,p_records_per_page => 1 --we expect only one record
                    ,p_xml_response     => l_xml_response  
                    ,p_err_code         => l_err_code
                    ,p_err_msg          => l_err_msg
                );
                
                --write_message('l_xml_response: ' || xmltype.getstringval(l_xml_response));
                --Simplified expected response: <ServiceStatus><Property key="server-time-iso" value="2020-12-03T04:00:56.099Z"/></ServiceStatus>

                /* Parse the response to get the server time */
                SELECT property_value
                INTO l_iso_server_time_string
                FROM
                    XMLTABLE(
                    ('/' || c_ssys_root_element || '/ServiceStatus/Property')
                    PASSING l_xml_response
                    COLUMNS
                        property_key    VARCHAR2(100) PATH '@key'
                        ,property_value VARCHAR2(100) PATH '@value'
                     )
                WHERE property_key = 'server-time-iso';

                l_iso_server_time_ts := TO_TIMESTAMP_TZ(l_iso_server_time_string, c_iso_8601_to_timestamp_tz_1); --convert ESL server timestamp to Oracle timestamp
            
                /* calculate the time difference between the ESL server and this Oracle database */
                l_result := CURRENT_TIMESTAMP - l_iso_server_time_ts;
                
                /* Update the body-level variable*/
                v_server_time_diff := l_result;
                       
            ELSE
                l_result := NULL;
            END IF;
        ELSE
            --write_message('Use existing ESL server time');
            /* Return the current "saved" value */
            l_result := v_server_time_diff;
        END IF;

        write_message('l_iso_server_time_string: ' || l_iso_server_time_string);        
        write_message('l_iso_server_time_ts: ' || l_iso_server_time_ts);
        write_message('CURRENT_TIMESTAMP: ' || CURRENT_TIMESTAMP);
        write_message('l_result: ' || l_result);
        
        RETURN l_result;
        
    EXCEPTION
        WHEN OTHERS THEN
            write_message(c_method_name || ': ' || SQLERRM);
            RETURN NULL;
    END eslsvr_db_time_diff;

    ----------------------------------------------------------------------------------------------------
    --  Name:               local_datetime
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      05-Jan-2021
    --  Purpose:            Get current local datetime as a string that that contains the timezone.
    --                               
    --  Description:        By explicitly providing values for optional parameters, any datetime
    --                      can be converted to another timezone in any format that is needed.
    --
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   05-Jan-2021   Eric Hubert     CHG0048556: initial build
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
                    TO_TIMESTAMP(TO_CHAR(p_date, c_datetime_format_1), c_datetime_format_1)
                    ,(l_timezone_code_from)) AT TIME ZONE l_timezone_code_to
                    ,p_datetime_format_to
            )
            ;

    RETURN l_date_temp;

    EXCEPTION
        WHEN OTHERS THEN
            --write_message(c_method_name || ': ' || SQLERRM);
            RETURN NULL;
    END local_datetime;
    
    ----------------------------------------------------------------------------------------------------
    --  Name:               utl_get_db_xml_doc
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      05-Jan-2021
    --  Purpose:            Retrieve an XML document from the table, XXESL_UTIL_XML_DOCUMENTS
    --                               
    --  Description:        Rather than hard-coding XML into this package, or try to utilize an 
    --                      existing application table (for which columns may be too small), we
    --                      have a database repository of key XML files (XMLTYPE column).
    --
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   05-Jan-2021   Eric Hubert     CHG0048556: initial build
    ----------------------------------------------------------------------------------------------------
    FUNCTION utl_get_db_xml_doc (
        p_file_name IN xxesl_util_xml_documents.doc_name%TYPE
    ) RETURN XMLTYPE
    IS
        c_method_name CONSTANT VARCHAR(30) := 'utl_get_db_xml_doc';

        l_xml   XMLTYPE;
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        --write_message('Start of: ' || c_method_name);

        /* Get the xml from database table */
        SELECT doc_content
        INTO l_xml
        FROM xxesl_util_xml_documents
        WHERE doc_name = p_file_name;
        
        RETURN l_xml;
        
    EXCEPTION
        WHEN OTHERS THEN
            write_message(c_method_name || ': ' || SQLERRM);
            RETURN NULL;
    END utl_get_db_xml_doc;

    ----------------------------------------------------------------------------------------------------
    --  Name:               utl_record_count_in_xml
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      05-Jan-2021
    --  Purpose:            Counts the number of nodes ("records") for a given path in an XML document
    --                               
    --  Description:        Given XML and a path, use an XML Query to get the number of nodes.
    --
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   05-Jan-2021   Eric Hubert     CHG0048556: initial build
    ----------------------------------------------------------------------------------------------------
    FUNCTION utl_record_count_in_xml (
        p_xml           IN  XMLTYPE
        ,p_record_path  IN  VARCHAR2
    ) RETURN NUMBER
    IS
        c_method_name CONSTANT VARCHAR(30) := 'utl_record_count_in_xml';
        
        l_xml_query_string  VARCHAR2(100) := 'count($xml/:rp)'; --XML Query String to count number of nodes (has a token for the "record path").
        l_result_xml        XMLTYPE;
        l_record_count      NUMBER;
    
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        --write_message('Start of: ' || c_method_name);
        
        /* Replace*/
        l_xml_query_string := REPLACE(l_xml_query_string, ':rp', p_record_path);

        /* Count the number of "records" (nodes) in the XML. */
        SELECT XMLQUERY(
            l_xml_query_string
            PASSING p_xml AS "xml"
            RETURNING CONTENT
        )
        INTO l_result_xml
        FROM dual;
        
        /* Get the numerical value and return it. */
        l_record_count := l_result_xml.getstringval;
        
        RETURN l_record_count;
        
    EXCEPTION
        WHEN OTHERS THEN
            write_message(c_method_name || ': ' || SQLERRM);
            RETURN NULL;
    END utl_record_count_in_xml;

--------------------------------------------------------------------------------
/* Public Functions - End */
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
/* Private Procedures - Start: */
--------------------------------------------------------------------------------
    ----------------------------------------------------------------------------------------------------
    --  Name:               write_message
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      05-Jan-2021
    --  Purpose:            Write a (debug) message to the specified target
    --
    --  Description:        This can be used to write to the concurrent request log file,
    --                      dbms_output, or fnd_log_messages.  The target location is 
    --                      controlled by a package-level constant.
    --
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   05-Jan-2021   Eric Hubert     CHG0048556: initial build
    ----------------------------------------------------------------------------------------------------
    PROCEDURE write_message(
        p_msg VARCHAR2
        ,p_file_name VARCHAR2 DEFAULT fnd_file.log
    ) IS
        
        c_method_name CONSTANT VARCHAR(30) := 'write_message';
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        
        CASE
        WHEN c_log_method = 0 THEN --No logging
            NULL;
        
        /* Concurrent request and fnd_file.log. */
        WHEN c_log_method = 1 and fnd_global.conc_request_id <> '-1' THEN
            /* Write to concurrent request log file. */
            fnd_file.put_line(
                which => p_file_name,
                --buff  => p_msg
                buff  => '[' || local_datetime || '] ' || p_msg
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
                '[' || local_datetime || '] ' || p_msg
            );
           
        ELSE --Other - do nothing
            NULL;
        END CASE;
    END write_message;

--------------------------------------------------------------------------------
/* Private Procedures - End */
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
/* Public Procedures - Start: */
--------------------------------------------------------------------------------
    ----------------------------------------------------------------------------------------------------
    --  Name:               eslsvr_create_resource
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      05-Jan-2021
    --  Purpose:            Consume a web service resource on an ESL server
    --
    --  Description:        For a given XML payload, split it up into smaller chunks
    --                      and consume the resource for chunk.  This is a generic function
    --                      that requires the ESL manufacturer code so that it can determine
    --                      where the web service is located.
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   05-Jan-2021   Eric Hubert     CHG0048556: initial build
    ----------------------------------------------------------------------------------------------------
    PROCEDURE eslsvr_create_resource (
        p_esl_mfg_code      IN fnd_flex_values.flex_value%TYPE
        ,p_resource_name    IN VARCHAR2
        ,p_payload_xml      IN XMLTYPE
        ,p_err_code         OUT NUMBER
        ,p_err_msg          OUT VARCHAR2
    ) AS
    
    c_method_name   CONSTANT VARCHAR2(30) := 'eslsvr_create_resource';
    c_rp_sesl_tt    CONSTANT VARCHAR2(30) := 'TaskOrder/TemplateTask';  --record path to individual Template Tasks in generated XML for SES-imagotag
    c_max_requests  CONSTANT NUMBER := 100; --
    
    l_system_row    q_xx_esl_systems_oma_v%ROWTYPE;
    l_url           q_xx_esl_systems_oma_v.xx_esl_server_url%TYPE;

    /* Local variables for splitting the payload */
    i                   NUMBER := 0;
    l_index             NUMBER := 1;
    l_rows_per_request  NUMBER := fnd_profile.value('XXESL_MAX_RECORDS_PER_POST');
    l_records_in_result NUMBER := 0;
    l_xml_chunk         XMLTYPE;
    l_record_path       VARCHAR2(50);    

    /* Other Local Variables */
    l_err_msg       VARCHAR2(1000);
    l_err_code      NUMBER;
    
    EXC_NULL_XML_PAYLOAD    EXCEPTION;
    EXC_POST_REQUEST_FAILED EXCEPTION;

    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('Start of: ' || c_method_name);

        IF p_payload_xml IS NULL THEN
            RAISE EXC_NULL_XML_PAYLOAD;
        END IF;

        esl_system_row(
            p_esl_mfg_code  => p_esl_mfg_code
            ,p_system_row   => l_system_row
            ,p_err_code     => l_err_msg
            ,p_err_msg      => l_err_msg
        );
        
        /* Get some values based upon the manufacturer of the ESL labels. */
        CASE l_system_row.xx_esl_manufacturer_code
        WHEN c_em_sesl THEN
            /* We'll need to support more requests than just this type */
            CASE p_resource_name WHEN c_scheduletasks THEN
                l_url := l_system_row.xx_esl_server_url || c_scheduletasks;
                l_record_path := c_rp_sesl_tt;
            ELSE
                l_url           := NULL;
                l_record_path   := NULL;
                
            END CASE;
        ELSE
            NULL;
        END CASE;
        
        /* Split the payload up into manageable "chunks" */
        LOOP
            write_message('l_index: ' || l_index);
            i := i + 1;
            write_message('Loop iteration: ' || i);            
            
            EXIT WHEN l_index >= c_max_requests; --Exit if the maximum "safe" number of loops is reached
            
            /* Break up the XML into smaller chunks before sending to the ESL server.  
                Specifically in the use case of kanban, we could have hundreds (or theoretically even even thousands), of kanban ESLs that 
                need updating and we want to minimize performance issues. 
            */
            write_message('l_rows_per_request: ' || l_rows_per_request);
            utl_split_payload(
                p_payload_xml   => p_payload_xml
                ,p_record_path  => l_record_path
                ,p_index        => l_index
                ,p_records      => l_rows_per_request
                ,p_xml_chunk    => l_xml_chunk
                ,p_err_code     => l_err_code
                ,p_err_msg      => l_err_msg
            );
            --write_message('l_xml_chunk: ' || l_xml_chunk.getclobval);
            --utl_print_output_clob(l_xml_chunk.getclobval);   
            /* Look for the numver of child records.  If none are found then exit. */
            l_records_in_result := utl_record_count_in_xml(
                p_xml           => l_xml_chunk
                ,p_record_path  => l_record_path
            );
            write_message('l_records_in_result: ' || l_records_in_result);    
            
            IF l_records_in_result > 0 THEN        
                write_message('Before utl_post_request');
                utl_post_request(
                    p_url           => l_url
                    ,p_content      => l_xml_chunk.getclobval
                    ,p_content_type => c_mime_type_default
                    ,p_err_code     => l_err_code
                    ,p_err_msg      => l_err_msg
                );
                
                IF l_err_code <> c_success THEN
                    RAISE EXC_POST_REQUEST_FAILED;
                END IF;
            ELSE
                /* No more records to send.  Exit the loop. */
                EXIT;
            END IF;

            l_index := l_index + l_rows_per_request;

        END LOOP;
   
        --write_message('After utl_post_request');
        --write_message('  l_err_code: ' || l_err_code);
        --write_message('  l_err_msg: ' || l_err_msg);        

    EXCEPTION
        WHEN EXC_NULL_XML_PAYLOAD THEN
            p_err_code := c_fail;
            p_err_msg  := c_method_name || ': null xml payload';
            write_message('p_err_msg: ' || p_err_msg);
        WHEN EXC_POST_REQUEST_FAILED THEN 
            p_err_code := c_fail;
            p_err_msg  := c_method_name || ': utl_post_request failed';
            write_message('p_err_msg: ' || p_err_msg);
        WHEN OTHERS
        THEN
            p_err_code := c_fail;
            p_err_msg  := c_method_name || ': ' || SQLERRM;
            write_message('p_err_msg: ' || p_err_msg);
    END eslsvr_create_resource;

    ----------------------------------------------------------------------------------------------------
    --  Name:               eslsvr_import_label_events
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      05-Jan-2021
    --  Purpose:            Retrieve and process SESL labels events 
    --                               
    --  Description:        The labels events are imported via a web service and then stored in a custom table.
    --                      This procedure itself does not react (initiate any activity in Oracle) to these events.
    --                      It merely informs the ESL record in the ESL Registry card that a button was pushed by updating 
    --                      its label event column with the newest event id.  It overwites any previous value, which
    --                      means that we're only focused on getting the most recent button event.  Any events
    --                      created since the previous call are marked as "ignored", exception for the most recent
    --                      event.
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   05-Jan-2021   Eric Hubert     CHG0048556: initial build
    ----------------------------------------------------------------------------------------------------  
    PROCEDURE eslsvr_import_label_events (
        p_esl_mfg_code  IN fnd_flex_values.flex_value%TYPE
        ,p_org_id       IN NUMBER
        ,p_err_code     OUT NUMBER
        ,p_err_msg      OUT VARCHAR2
    )
    AS
        c_method_name CONSTANT VARCHAR(30) := 'eslsvr_import_label_events';
        
        /* Other Local Variables */
        l_new_process_flag  NUMBER;
        l_err_code          NUMBER;
        l_err_msg           VARCHAR2(1000);
        
        CURSOR c_sesl IS
            SELECT 
                qxerov.xx_esl_id
                ,xelesv.event_id
            FROM
                q_xx_esl_registry_oma_v qxerov
                INNER JOIN xxesl_label_events_sesl_v xelesv ON (xelesv.labelid =  qxerov.xx_esl_id)
                INNER JOIN mtl_parameters mp ON (mp.organization_code = qxerov.xx_organization_code)
            WHERE 1=1
                AND mp.organization_id = p_org_id
            ORDER BY event_timestamp;
                
        l_events_row c_sesl%ROWTYPE;
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('Start of: ' || c_method_name);  
        
        /* Call ESL manufacturer-specific procedure to get button events.  SES-imagotag is the only one currently. */
        CASE  p_esl_mfg_code  WHEN c_em_sesl THEN
        
            /* Get label events from ESL server (populates Oracle-side staging table) */
            sesl_retrieve_labelevents(
                p_err_code => l_err_code
                ,p_err_msg => l_err_msg
            );
            
            write_message('Result of sesl_retrieve_labelevents:' || l_err_code);

            /* Mark old events as ignored (without updating the newest event for each label). */
            sesl_ignore_old_events(
                p_err_code => l_err_code
                ,p_err_msg => l_err_msg
            );
            
            write_message('Result of sesl_ignore_old_events:' || l_err_code);          
            
            /* Check if event import was successful. */
            IF l_err_code = c_success THEN
                l_err_msg  := NULL;--reset
                
                OPEN c_sesl;
                
                /* Iterate through all of the events for a label */
                LOOP 

                    FETCH c_sesl INTO l_events_row;
                    
                    write_message('--c_sesl: after fetch');

                    EXIT WHEN c_sesl%NOTFOUND;
                    write_message('--c_sesl: records found');
                    
                    l_new_process_flag := NULL; --reinitialize

                    /* Update the label eevnt column inthe ESL Registry with the event id. */
                    eslreg_update_label_event(
                        p_esl_mfg_code      =>  c_em_sesl
                        ,p_esl_id           =>  l_events_row.xx_esl_id
                        ,p_event_id         =>  l_events_row.event_id
                        ,p_err_code         =>  l_err_code
                        ,p_err_msg          =>  l_err_msg
                    );

                    write_message('Result of eslreg_update_label_event:' || l_err_code);
                        
                    /* Examine the result of the update to the label event process flag */
                    IF l_err_code = c_success THEN
                        l_new_process_flag := pf_2; --Processed
                    ELSE   
                        l_new_process_flag := pf_4; --Exception
                    END IF;
                    
                    /* Update process flag */
                    sesl_update_event_process_flag(
                        p_event_id          => l_events_row.event_id
                        ,p_process_flag     => l_new_process_flag
                        ,p_err_code         => l_err_code
                        ,p_err_msg          => l_err_msg
                    );
                    
                END LOOP;
                
                CLOSE c_sesl;
            END IF;
        ELSE --Other ESL manufacturer
            NULL;
        END CASE;

        p_err_code  := l_err_code;
        p_err_msg   := l_err_msg;

    EXCEPTION
         WHEN OTHERS THEN
            p_err_code := c_fail;
            p_err_msg  := c_method_name || ': ' || SQLERRM;
            write_message('p_err_msg: ' || p_err_msg);
    END eslsvr_import_label_events;

    ----------------------------------------------------------------------------------------------------
    --  Name:               eslsvr_import_labels [FUTURE]
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      05-Jan-2021
    --  Purpose:            Import ESLs (ESL IDs) defined on the ESL server into the Oracle ESL Registry.  This
    --                      eliminates the need to manually enter ESLs in the registry.  Once discovered
    --                      by the ESL server and imported into Oracle, they are available for
    --                      association with Oracle entities like Kanban Cards.
    --
    --                      In addition to getting the defined labels, it also imports certain label
    --                      attributes that are relevant for assigning ESLs to Oracle entities.  For 
    --                      example, as label "status" is imported which we'll use to determine if
    --                      that label should be available to a user to assign to something such as a
    --                      kanban card record.
    --  Description:        This is a generic, manufacturer-agnostic procedure.  It will call the 
    --                      necessary import procedure specific to the ESL manufacturer.
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   05-Jan-2021   Eric Hubert     CHG0048556: initial build
    ----------------------------------------------------------------------------------------------------  
    --PROCEDURE eslsvr_import_labels (
    --    p_esl_mfg_code  IN fnd_flex_values.flex_value%TYPE
    --    ,p_err_code     OUT NUMBER
    --    ,p_err_msg      OUT VARCHAR2
    --)
    --AS
    --    c_method_name CONSTANT VARCHAR(30) := 'eslsvr_import_labels';
    --  
    --    /* Other Local Variables */
    --    l_err_code          NUMBER;
    --    l_err_msg           VARCHAR2(1000);
    --
    --BEGIN
    --    gv_log_program_unit := c_method_name; --store procedure name for logging
    --    write_message('Start of: ' || c_method_name);  
    --
    --    /* Only SES-imagotag is supported initially. */
    --    CASE p_esl_mfg_code WHEN xxesl_utils_pkg.c_em_sesl THEN
    --        
    --        null;
    --    ELSE
    --        /* Not SES-imagotag */
    --        null;
    --    END CASE;
    --
    --    p_err_code  := l_err_code;
    --    p_err_msg   := l_err_msg;
    --
    --EXCEPTION
    --     WHEN OTHERS THEN
    --        p_err_code := c_fail;
    --        p_err_msg  := c_method_name || ': ' || SQLERRM;
    --        write_message('p_err_msg: ' || p_err_msg);
    --END eslsvr_import_labels;

    ----------------------------------------------------------------------------------------------------
    --  Name:               sesl_event_row
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      05-Jan-2021
    --  Purpose:            Get an entire xxesl_label_events_sesl table row for specefied event ID.
    --                               
    --  Description:        
    --
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   05-Jan-2021   Eric Hubert     CHG0048556: initial build
    ----------------------------------------------------------------------------------------------------
    PROCEDURE sesl_event_row(
        p_event_id      IN VARCHAR2
        ,p_event_row    OUT xxesl_label_events_sesl%ROWTYPE
        ,p_err_code     OUT NUMBER
        ,p_err_msg      OUT VARCHAR2
    ) AS
        c_method_name CONSTANT VARCHAR(30) := 'sesl_event_row';
      
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        --write_message('Start of: ' || c_method_name);

        SELECT *
        INTO p_event_row
        FROM xxesl_label_events_sesl
        WHERE event_id = p_event_id; 
    
        p_err_code := c_success;

        --write_message('End of sesl_event_row');
    EXCEPTION
         WHEN OTHERS THEN
            p_event_row := NULL;
            p_err_code := c_fail;
            p_err_msg  := c_method_name || ': ' || SQLERRM;
            write_message('p_err_msg: ' || p_err_msg);
    END sesl_event_row;
    
    ----------------------------------------------------------------------------------------------------
    --  Name:               sesl_ignore_old_events
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      05-Jan-2021
    --  Purpose:            Mark older unprocessed events for each label as ignored/bypassed.  The 
    --                      newest event for each label is not updated.
    --                               
    --  Description:        Use a MERGE statement to perform the update.  In this ESL solution, we
    --                      only consider the most recent event for importing into Oracle.  Therefore, 
    --                      we mark older, unprocessed events as ignored/bypassed, while still retaining
    --                      their history (until a purge).
    --
    --                      No consideration is given as to which org the labels are used in.  This
    --                      procedure considers all labels/ESLs' events.
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   05-Jan-2021   Eric Hubert     CHG0048556: initial build
    ----------------------------------------------------------------------------------------------------
    PROCEDURE sesl_ignore_old_events(
        p_err_code     OUT NUMBER
        ,p_err_msg      OUT VARCHAR2
    ) AS
        c_method_name CONSTANT VARCHAR(30) := 'sesl_ignore_old_events';
      
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        --write_message('Start of: ' || c_method_name);
        
        /* Mark older unprocessed events for each label as ignored/bypassed.  The newest event for each label is not updated. */
        MERGE INTO xxesl_label_events_sesl xeles
        USING
            /* Subquery returns all unprocessed events for a label, except for the newest one. */
            (
                SELECT
                    event_id
                    ,event_seq
                FROM
                    (
                        SELECT
                            xeles2.event_id
                            /* Order the events within each label/ESL. */
                            ,DENSE_RANK ()
                                OVER (PARTITION BY xeles2.labelid
                                      ORDER BY xeles2.event_timestamp DESC) event_seq
                        FROM xxesl_label_events_sesl xeles2
                        WHERE process_flag = 1 --Unprocessed
                    )
                WHERE event_seq <> 1 --exclude the most recent event
            ) ue --unprocessed events
        ON (xeles.event_id = ue.event_id)
        WHEN MATCHED THEN
            /* Update the process_flag to ignored; update who columns. */
            UPDATE SET
                xeles.process_flag         = 3 --Ignored/bypassed
                ,xeles.last_updated_by     = NVL(fnd_profile.value('USER_ID'), -1)
                ,xeles.last_update_date    = SYSDATE
                ,xeles.last_update_login   = USERENV('SESSIONID') 
                ,xeles.request_id          = fnd_global.conc_request_id
                ,xeles.program_id          = fnd_global.conc_program_id;
    
        COMMIT;
    
        p_err_code := c_success;

        --write_message('End of sesl_ignore_old_events');
    EXCEPTION
         WHEN OTHERS THEN
            p_err_code := c_fail;
            p_err_msg  := c_method_name || ': ' || SQLERRM;
            write_message('p_err_msg: ' || p_err_msg);
    END sesl_ignore_old_events;
        
    ----------------------------------------------------------------------------------------------------
    --  Name:               esl_registry_row
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      05-Jan-2021
    --  Purpose:            Get an entire q_xx_esl_registry_oma_v view row for specefied ESL Mfg and ID.
    --                               
    --  Description:        
    --
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   05-Jan-2021   Eric Hubert     CHG0048556: initial build
    ----------------------------------------------------------------------------------------------------
    PROCEDURE esl_registry_row(
        p_esl_id       IN  VARCHAR2
        ,p_registry_row OUT q_xx_esl_registry_oma_v%ROWTYPE
        ,p_err_code     OUT NUMBER
        ,p_err_msg      OUT VARCHAR2
    ) AS
        c_method_name CONSTANT VARCHAR(30) := 'esl_registry_row';
      
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('Start of: ' || c_method_name);

        SELECT *
        INTO p_registry_row
        FROM q_xx_esl_registry_oma_v
        WHERE
            xx_esl_id = p_esl_id
            AND xx_enabled_flag = 'Y';

        p_err_code := c_success;

    EXCEPTION
         WHEN OTHERS THEN
            p_registry_row := NULL;
            p_err_code := c_fail;
            p_err_msg  := c_method_name || ': ' || SQLERRM;
            write_message('p_err_msg: ' || p_err_msg);
    END esl_registry_row;
    
    ----------------------------------------------------------------------------------------------------
    --  Name:               esl_system_row
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      05-Jan-2021
    --  Purpose:            Retrieve system information from XX_ESL_SYSTEMS collection plan.
    --                               
    --  Description:        Rows will only be returned where the target Oracle Environment listed
    --                      on the system record matches the current database name.  This helps to
    --                      avoid issue after cloning (where the cloned environment would otherwise
    --                      interface to the production environment).
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   05-Jan-2021   Eric Hubert     CHG0048556: initial build  
    ----------------------------------------------------------------------------------------------------  
    PROCEDURE esl_system_row(
        p_esl_mfg_code  IN fnd_flex_values.flex_value%TYPE
        ,p_system_row   OUT q_xx_esl_systems_oma_v%ROWTYPE
        ,p_err_code     OUT NUMBER
        ,p_err_msg      OUT VARCHAR2
    ) AS
        c_method_name CONSTANT VARCHAR(30) := 'esl_system_row';

    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('Start of: ' || c_method_name);

        SELECT *
        INTO p_system_row
        FROM q_xx_esl_systems_oma_v
        WHERE
            xx_enabled_flag = 'Y'
            AND xx_esl_manufacturer_code = p_esl_mfg_code
            AND xx_database_name = SYS_CONTEXT('USERENV', 'DB_NAME')
        FETCH FIRST 1 ROWS ONLY --This implies that we currently only support one active ESL system per ESL manufacturer            
        ;
        
        p_err_code := c_success;

    EXCEPTION
         WHEN OTHERS THEN
            p_system_row := NULL;
            p_err_code := c_fail;
            p_err_msg  := c_method_name || ': ' || SQLERRM;
            write_message('p_err_msg: ' || p_err_msg);
    END esl_system_row;
    
    ----------------------------------------------------------------------------------------------------
    --  Name:               sesl_retrieve_info
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      05-Jan-2021
    --  Purpose:            Generic procedure to get resource from SES-imagotag core service
    --                               
    --  Description:        Used to obtain various information from the core service.  Paged results
    --                      are combined within this procedure to create a composite XML response
    --                      document.
    --
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   05-Jan-2021   Eric Hubert     CHG0048556: initial build
    ----------------------------------------------------------------------------------------------------
    PROCEDURE sesl_retrieve_info ( --Get resource for SES-imagotag
            p_uri_path          IN  VARCHAR2
            ,p_records_per_page IN  NUMBER
            ,p_xml_response     OUT XMLTYPE
            ,p_err_code         OUT NUMBER
            ,p_err_msg          OUT VARCHAR2
        )
    IS
        c_method_name CONSTANT VARCHAR(20) := 'sesl_retrieve_info';
        
        /* SES-imagotag GET parameter names (per WADL) */
        c_pn_accesspointid      VARCHAR2(16) := 'accessPointId';
        c_pn_clear              VARCHAR2(16) := 'clear';
        c_pn_connectionstatus   VARCHAR2(16) := 'connectionStatus';
        c_pn_dataid             VARCHAR2(16) := 'dataId';
        c_pn_day                VARCHAR2(16) := 'day';
        c_pn_externalid         VARCHAR2(16) := 'externalId';
        c_pn_firmware           VARCHAR2(16) := 'firmware';
        c_pn_font               VARCHAR2(16) := 'font';
        c_pn_hour               VARCHAR2(16) := 'hour';
        c_pn_key                VARCHAR2(16) := 'key';
        c_pn_label              VARCHAR2(16) := 'label';
        c_pn_labelid            VARCHAR2(16) := 'labelId';
        c_pn_level              VARCHAR2(16) := 'level';
        c_pn_minute             VARCHAR2(16) := 'minute';
        c_pn_minutes            VARCHAR2(16) := 'minutes';
        c_pn_month              VARCHAR2(16) := 'month';
        c_pn_page               VARCHAR2(16) := 'page';
        c_pn_powerstatus        VARCHAR2(16) := 'powerStatus';
        c_pn_recordsperpage     VARCHAR2(16) := 'recordsPerPage';
        c_pn_registrationcode   VARCHAR2(16) := 'registrationCode';
        c_pn_second             VARCHAR2(16) := 'second';
        c_pn_tag                VARCHAR2(16) := 'tag';
        c_pn_taskid             VARCHAR2(16) := 'taskId';
        c_pn_template           VARCHAR2(16) := 'template';
        c_pn_timestamp          VARCHAR2(16) := 'timestamp';
        c_pn_transactionid      VARCHAR2(16) := 'transactionId';
        c_pn_value              VARCHAR2(16) := 'value';
        c_pn_year               VARCHAR2(16) := 'year';
        
        l_system_row           q_xx_esl_systems_oma_v%ROWTYPE;
        l_uri               VARCHAR2(100);
        l_uri_parameters    VARCHAR2(100);
        l_url               VARCHAR2(100);

        /* Variables for volume of resource records returned by request. */
        l_records_per_page      NUMBER;
        l_max_page_requests     NUMBER  := fnd_profile.value('XXESL_MAX_RESPONSE_PAGES');
        l_res_records           NUMBER;
        l_res_totalRecords      NUMBER;
        l_res_totalPages        NUMBER := 0;
        l_res_page              NUMBER := 0;
        l_res_recordsPerPage    NUMBER;
        l_loop_count            NUMBER := 0;

        /* Other Local Variables */
        l_err_msg       VARCHAR2(1000);
        l_err_code      NUMBER;
        
        l_response_clob CLOB;
        l_xml_response  XMLTYPE;
        l_response_root_element_name    VARCHAR2(50) := 'LabelInfoPagedResult';
        --l_xml_composite XMLTYPE := XMLTYPE('<?xml version="1.0" encoding="utf-8"?><' || c_ssys_root_element || '/>');  --Default XML containing a root node
        l_xml_composite XMLTYPE := XMLTYPE('<' || c_ssys_root_element || '/>');  --Default XML containing a root node

        EXC_REQUEST_FAILED EXCEPTION;
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('Start of: ' || c_method_name);
       
        esl_system_row(
                p_esl_mfg_code  => c_em_sesl
                ,p_system_row   => l_system_row
                ,p_err_code     => l_err_msg
                ,p_err_msg      => l_err_msg
            );
            
        l_uri           := l_system_row.xx_esl_server_url || p_uri_path; --append path to the scheme/authority
        
        l_records_per_page  := COALESCE(p_records_per_page, fnd_profile.value('XXESL_RECORDS_PER_RESPONSE_PAGE'));
     
        /* Break the request responses into manageable chunks by limiting the number of records returned per page.
           Make requests until we'e completed requesting all of the pages (or a hard-coded limit has ben reached).
        */
        LOOP
            --write_message('l_loop_count: ' || l_loop_count);
        
            /* Append parameters to limit the number of records returned at one time */
            l_uri_parameters := '?' || c_pn_page || '=' || l_loop_count ||'&' || c_pn_recordsperpage || '=' || l_records_per_page;
            l_url := l_uri || l_uri_parameters;
            write_message('l_url: ' || l_url);
       
            utl_get_request(
                p_url       => l_url
                ,p_response => l_response_clob
                ,p_err_code => l_err_code
                ,p_err_msg  => l_err_msg
            );
            
            IF l_err_code <> c_success THEN
                RAISE EXC_REQUEST_FAILED;
            END IF;
            
            --write_message('l_response_clob: ' || l_response_clob);
            
            /* Assume the response is XML (we're not using JSON) */
            l_xml_response := XMLTYPE.createXML(l_response_clob);
            
            /* Get the name of the root element in the response. We'll need this for the following query against response. */
            l_response_root_element_name := XMLType.getRootElement(l_xml_response);
            
            --write_message('before select into');

            /* Get the total number of pages and see if we need to make more calls.
            
               Note: All requests supporting paging accept the parameters page and recordsPerPage 
               in order to generate the result page-wise. If page is not set, the whole result 
               list will be transmitted (no paging). The page number starts with 0. If 
               recordsPerPage isn't set, a default value is used.
            */
            SELECT *
            INTO 
                    l_res_records
                    ,l_res_totalRecords
                    ,l_res_totalPages
                    ,l_res_page
                    ,l_res_recordsPerPage
            FROM
            XMLTABLE(
                ('/' || l_response_root_element_name) --root element in response
                PASSING l_xml_response
                /* Columns below per attributes in response */
                COLUMNS a1 VARCHAR2(100) PATH '@records',
                        a2 VARCHAR2(100) PATH '@totalRecords',
                        a3 VARCHAR2(100) PATH '@totalPages',
                        a4 VARCHAR2(100) PATH '@page',
                        a5 VARCHAR2(100) PATH '@recordsPerPage'
            );
                --write_message('l_res_records: '         || l_res_records);       
                --write_message('l_res_totalRecords: '    || l_res_totalRecords);      
                --write_message('l_res_totalPages: '      || l_res_totalPages);      
                --write_message('l_res_page: '            || l_res_page);      
                --write_message('l_res_recordsPerPage: '  || l_res_recordsPerPage);              
        
            /* Append the response to prior responses. */
            l_xml_composite := utl_xml_combine(
                 p_xml_parent => l_xml_composite
                ,p_xml_child  => l_xml_response
            );

            EXIT WHEN
                /* Some situations where we want to stop requesting additional pages: */
                (l_res_page IS NULL)                     --will be null if request does not support paging.
                OR (l_res_page >= l_res_totalPages - 1)  --Page count starts at zero so we adjust for that
                OR (l_loop_count >= l_max_page_requests) --safeguard to prevent an infinite loop, or, other performance issues that might be addressed by requesting a specific record
                ;
            
            l_loop_count := l_loop_count + 1;  --move on to the next page

        END LOOP;
    
        p_xml_response  := l_xml_composite;
        p_err_code      := c_success;
        p_err_msg       := NULL; 
        
        --write_message('l_xml_composite: ' || xmltype.getstringval(l_xml_composite));
        
        --write_message('End of sesl_retrieve_info');
    EXCEPTION
        WHEN EXC_REQUEST_FAILED THEN
            p_err_code := c_fail;
            p_err_msg  := c_method_name || ': ' || SQLERRM;
            write_message('p_err_msg: ' || p_err_msg);
    
        WHEN OTHERS THEN
            p_err_code := c_fail;
            p_err_msg  := c_method_name || ': ' || SQLERRM;
            write_message('p_err_msg: ' || p_err_msg);
 
    END sesl_retrieve_info;    

    ----------------------------------------------------------------------------------------------------
    --  Name:               sesl_retrieve_labelevents
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      05-Jan-2021
    --  Purpose:            Retrieve label events from the SES-imagotag core service.
    --                               
    --  Description:        The label events are for the buttons pushed on the physical ESLs.
    --
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   05-Jan-2021   Eric Hubert     CHG0048556: initial build
    ----------------------------------------------------------------------------------------------------
    PROCEDURE sesl_retrieve_labelevents(
        p_err_code  OUT NUMBER
        ,p_err_msg  OUT VARCHAR2
    ) AS
        c_method_name CONSTANT VARCHAR(30) := 'sesl_retrieve_labelevents';
    
        l_xml_response  XMLTYPE;
        l_err_code      NUMBER;
        l_err_msg       VARCHAR2(1000);
        l_path          VARCHAR2(100);
    
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        --write_message('Start of: ' || c_method_name);
        
        sesl_retrieve_info (
            p_uri_path          => c_getevents
            ,p_records_per_page => 10
            ,p_xml_response     => l_xml_response  
            ,p_err_code         => l_err_code
            ,p_err_msg          => l_err_msg
        );

        --write_message.put_line('l_err_code: ' || l_err_code);
        --write_message.put_line('l_err_msg: ' || l_err_msg);
        
        --write_message.put_line('l_xml_response: ' || xmltype.getstringval(l_xml_response));

        /* For reference, here is the portion of ESLLabelEventPagedResult.xsd related to LabelEvent: */
            --  <xs:complexType name="LabelEvent">
            --  <xs:sequence>
            --    <xs:element name="LabelId" type="xs:string"/>
            --    <xs:element name="Type" type="xs:int" minOccurs="0"/>
            --    <xs:element name="Data" type="xs:int" minOccurs="0"/>
            --    <xs:element name="ReceivedTime" type="xs:dateTime" minOccurs="0"/>
            --    <xs:element name="Confirmed" type="xs:boolean"/>
            --  </xs:sequence>
            --  <xs:attribute name="id" type="xs:string" use="required"/>
            --  </xs:complexType>
        
        l_path := '/' || c_ssys_root_element || '/LabelEventPagedResult/LabelEvent'; --Build the path

        /* Insert new events only. */
        MERGE INTO xxesl_label_events_sesl le
        USING
        XMLTABLE(
            l_path
            PASSING l_xml_response
            COLUMNS event_id        VARCHAR2(100) PATH '@id',
                    labelid         VARCHAR2(100) PATH 'LabelId',
                    event_type      VARCHAR2(100) PATH 'Type',
                    event_data      VARCHAR2(100) PATH 'Date',
                    receivedtime    VARCHAR2(100) PATH 'ReceivedTime',
                    confirmed       VARCHAR2(100) PATH 'Confirmed'
        ) xt
        ON (le.event_id = xt.event_id)
        /* No need to do any updates when matched, just when not matched. */
        WHEN NOT MATCHED THEN
            INSERT (
                le.event_id
                ,le.labelid
                ,le.event_type
                ,le.event_data
                ,le.receivedtime
                ,le.confirmed    
                ,le.event_timestamp
                ,le.process_flag
                ,le.created_by
                ,le.creation_date
                ,le.last_updated_by
                ,le.last_update_date
                ,le.last_update_login
                ,le.request_id
                ,le.program_id
            )
            VALUES (
                xt.event_id
                ,xt.labelid
                ,xt.event_type
                ,xt.event_data
                ,xt.receivedtime
                ,xt.confirmed
                ,TO_TIMESTAMP_TZ(xt.receivedtime, c_iso_8601_to_timestamp_tz_1) --convert ESL server timestamp to Oracle timestamp
                ,pf_1
                ,NVL(fnd_profile.value('USER_ID'), -1)
                ,SYSDATE 
                ,NVL(fnd_profile.value('USER_ID'), -1)
                ,SYSDATE 
                ,USERENV('SESSIONID') 
                ,fnd_global.conc_request_id
                ,fnd_global.conc_program_id
            );
    
        p_err_code := c_success;

        --write_message('End of sesl_retrieve_labelevents');
    EXCEPTION
         WHEN OTHERS THEN
            p_err_code := c_fail;
            p_err_msg  := c_method_name || ': ' || SQLERRM;
            write_message('p_err_msg: ' || p_err_msg);
    END sesl_retrieve_labelevents;

    ----------------------------------------------------------------------------------------------------
    --  Name:               sesl_update_event_process_flag
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      05-Jan-2021
    --  Purpose:            For a specified ESL event ID, update the process_flag column in the xxesl_label_events_sesl
    --                      table that has the label events for SES-imagotag button-enabled ESLs.
    --
    --  Description:        The process_flag column indicates the Oracle-side processing "state" for the event.
    --
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   05-Jan-2021   Eric Hubert     CHG0048556: initial build
    ----------------------------------------------------------------------------------------------------
    PROCEDURE sesl_update_event_process_flag(
        p_event_id          VARCHAR2
        ,p_process_flag     NUMBER
        ,p_err_code         OUT NUMBER
        ,p_err_msg          OUT VARCHAR2
    )  IS
        c_method_name CONSTANT VARCHAR(30) := 'sesl_update_event_process_flag';
                            
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        --write_message('Start of: ' || c_method_name);

        UPDATE xxesl_label_events_sesl
        SET
            process_flag         = p_process_flag
            ,last_updated_by     = NVL(fnd_profile.value('USER_ID'), -1)
            ,last_update_date    = SYSDATE
            ,last_update_login   = USERENV('SESSIONID') 
            ,request_id          = fnd_global.conc_request_id
            ,program_id          = fnd_global.conc_program_id
        WHERE event_id = p_event_id;
        
        COMMIT;       

        p_err_code := c_success;
        p_err_msg  := NULL;
        
    EXCEPTION
        WHEN OTHERS THEN
            p_err_code := c_fail;
            p_err_msg  := c_method_name || ': ' || SQLERRM;
            write_message('p_err_msg: ' || p_err_msg);
    END sesl_update_event_process_flag;

    ----------------------------------------------------------------------------------------------------
    --  Name:               eslreg_update_label_event
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      05-Jan-2021
    --  Purpose:            Update the button event on the ESL rgistry record.  This is a wrapper
    --                      function that calls update_result_value.
    --
    --  Description:        
    --
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   05-Jan-2021   Eric Hubert     CHG0048556: initial build
    ----------------------------------------------------------------------------------------------------
    PROCEDURE eslreg_update_label_event(
        p_esl_mfg_code       IN fnd_flex_values.flex_value%TYPE
        ,p_esl_id            IN VARCHAR2
        ,p_event_id          IN VARCHAR2
        ,p_err_code          OUT NUMBER
        ,p_err_msg           OUT VARCHAR2
    )  IS

        c_method_name CONSTANT VARCHAR(30) := 'eslreg_update_label_event';
        
        l_registry_row  q_xx_esl_registry_oma_v%ROWTYPE;
        l_err_code      NUMBER;
        l_err_msg       VARCHAR2(1000);

    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('Start of: ' || c_method_name);

        /* Get the plan_id and occurrence for the ESL Registry row. */
        esl_registry_row(
            p_esl_id       => p_esl_id
            ,p_registry_row => l_registry_row
            ,p_err_code     => l_err_code
            ,p_err_msg      => l_err_msg);
        
        
        /* Update the nonconformance status directly. */
        update_result_value(
            p_plan_id        => l_registry_row.plan_id
            ,p_occurrence    => l_registry_row.occurrence
            ,p_char_name     => c_cen_esl_event_id
            ,p_new_value     => p_event_id
            ,p_err_code      => l_err_code
            ,p_err_msg       => l_err_msg
            );
            
        p_err_code := l_err_code;
        p_err_msg  := l_err_msg;
        
    EXCEPTION
        WHEN OTHERS THEN
            p_err_code := c_fail;
            p_err_msg  := c_method_name || ': ' || SQLERRM;
            write_message('p_err_msg: ' || p_err_msg);
    END eslreg_update_label_event;
 
    ----------------------------------------------------------------------------------------------------
    --  Name:               update_result_value
    --  Created By:         Hubert, Eric
    --  Revision:           1.2
    --  Creation Date:      05-Jan-2021
    --  Purpose:            Directly update a collection result value for plan, XX_ESL_REGISTRY_OMA,
    --                      to avoid the complexity and performance decrease of using
    --                      the using the Quality Results Open Interface.
    --
    --  Description: 
    --    A nearly identical procedure, xxqa_nonconformance_util_pkg, has been thoroughly tested through 
    --    multiple years of usage as part of the Quality Nonconformance process to update tha values of
    --    nonconformance and disposition status elements.  The usage for ESLs is very similar so that
    --    function was copied to this package.  We are adding the hard-coded restriction in this procedure
    --    to limit updates only to the XX_ESL_REGISTRY_OMA collection plan, to be safe.
    --
    --    This function is currently limited to updating result values
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
    --   Use qa_results_pub or qa_results_api.update_row to do update.
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   05-Jan-2021   Eric Hubert     CHG0048556: initial build
    ----------------------------------------------------------------------------------------------------
    PROCEDURE update_result_value(
        p_plan_id        IN  qa_plans.plan_id%TYPE
        ,p_occurrence    IN  qa_results.occurrence%TYPE
        ,p_char_name     IN  qa_chars.name%TYPE
        ,p_new_value     IN  VARCHAR2
        ,p_err_code      OUT NUMBER
        ,p_err_msg       OUT VARCHAR2
    )
    IS
        c_method_name CONSTANT VARCHAR(30) := 'update_result_value';

        l_column_name   all_tab_columns.column_name%TYPE;
        l_update_sql    VARCHAR2(1000);
    
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('Start of: ' || c_method_name);
        
        write_message('p_plan_id: ' || p_plan_id);
        write_message('p_occurrence: ' || p_occurrence);
        write_message('p_char_name: ' || p_char_name);
        write_message('p_new_value: ' || p_new_value);

        /* Limit updates to specific ESL-related tables. */
        IF qa_core_pkg.get_plan_name(p_plan_id) = c_cpn_esl_registry THEN

            /* Get the result column name and plan id for a plan-element record. 
               CHG0046276: find column via plan_id instead of plan name. */
            SELECT result_column_name
            INTO l_column_name
            FROM qa_plan_chars_v
            WHERE  enabled_flag = 1 --Enabled
                AND SUBSTR(result_column_name,1,9) = 'CHARACTER' --Is a user-defined field
                AND datatype = 1 --Character
                AND plan_id = p_plan_id
                AND char_name = p_char_name;
            
            write_message('l_column_name: ' || l_column_name);
            --write_message('l_plan_id: ' || l_plan_id);
            
            IF l_column_name IS NOT NULL AND p_plan_id IS NOT NULL THEN
                --write_message('p_occurrence: ' || p_occurrence);
                --write_message('p_new_value: ' || p_new_value);

                /* Build SQL to update the necessary column*/
                l_update_sql := 
                    'UPDATE qa_results
                    SET ' || l_column_name || ' = :newvalue
                    , last_updated_by     = NVL(fnd_profile.value(''USER_ID''), -1)
                    , last_update_date    = SYSDATE 
                    , last_update_login   = USERENV(''SESSIONID'')
                    , request_id          = fnd_global.conc_request_id
                    , program_id          = fnd_global.conc_program_id
                    WHERE
                    occurrence = :occurrence
                    and plan_id = :planid';
                
                write_message('l_update_sql: ' || l_update_sql);

                /* Update the value for the specified column in a specified result record */
                EXECUTE IMMEDIATE l_update_sql
                USING p_new_value, p_occurrence, p_plan_id;
                COMMIT;

                p_err_code := c_success;
            ELSE
                write_message('l_column_name or p_plan_id exception');
                p_err_code := c_fail;
            END IF;

        ELSE
            p_err_code      := c_fail;
            p_err_msg       := 'Updates to results this for this collection plan are not supported.'; 
        END IF;

    /* Exception handling */
    EXCEPTION
        WHEN OTHERS THEN
            p_err_code := c_fail;
            p_err_msg  := c_method_name || ': ' || SQLERRM;
            write_message('p_err_msg: ' || p_err_msg);
    END update_result_value;
   
    ----------------------------------------------------------------------------------------------------
    --  Name:               update_unassigned_esl_displays
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      05-Jan-2021
    --  Purpose:            Update the display of ESLs that lack any assignment to an Oracle "entity",
    --                      such as a kanban card.  If a user clears the ESL ID field (DFF) from the entity
    --                      record, its prior image would otherwise persist indefinitely, potentially
    --                      causing confusion on the shop floor.
    --
    --  Description:        Check if there were other kanban uses for the same ESL model type since we 
    --                      wouldn't want to overwrite an ESL for a discrete job, move order, nonconformance, 
    --                      etc.  It would need to be some kind of loop through the ESL registry that for each 
    --                      card would loop through each of the allowed usages and check if an Oracle "entity" 
    --                      had the ESL assigned to it.  If no assignements were found, we wouldn't necessarily 
    --                      push out an exception message since the ESL may be new and unassigned.  We would 
    --                      need to check that that either the ESL image is not the default/new image, or, that 
    --                      the ESL is in some state that we can infer that the current image is not indictive 
    --                      of not being assigned to any Oracle entity.
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   05-Jan-2021   Eric Hubert     CHG0048556: initial build
    ----------------------------------------------------------------------------------------------------
    PROCEDURE update_unassigned_esl_displays(
        errbuf              OUT VARCHAR2
        ,retcode            OUT NUMBER
        ,p_esl_mfg_code     IN fnd_flex_values.flex_value%TYPE
        ,p_esl_model_code   IN VARCHAR2
    ) IS
        c_method_name CONSTANT VARCHAR(30) := 'update_unassigned_esl_displays';

        /* Local Constants */
        l_sql VARCHAR2(4000);
        l_ctx dbms_xmlgen.ctxhandle;
    
        l_xml         XMLTYPE;
        l_xsl         XMLTYPE;
        l_trans_xml   XMLTYPE; --Transformed XML
 
        /* Other Local Variables */
        l_resource_name VARCHAR2(50);
        l_err_msg       VARCHAR2(1000);
        l_err_code      NUMBER;
        
        EXC_NO_DATA_FOUND           EXCEPTION;
        EXC_CREATE_RESOURCE_FAILED  EXCEPTION; 
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('Start of: ' || c_method_name);      
        
        /* SQL to get a wide variety of kanban-related information */
        l_sql := Q'[
        SELECT
            xueiv.e_esl_manufacturer_code
            ,xueiv.e_esl_model_code
            ,xueiv.e_esl_id
            ,xueiv.e_organization_code
            ,xueiv.e_organization_id
            ,'XXESL_UNASSIGNED_ESL_IDS_V' data_source_name --Used by XSL to determine which template to use on ESL server
        FROM xxesl_unassigned_esl_ids_v xueiv
        WHERE 1=1 
            AND xueiv.e_esl_manufacturer_code = :bv_esl_mfg_code
            AND xueiv.e_esl_model_code        = :bv_esl_model_code
        ]';

        l_ctx := dbms_xmlgen.newContext(queryString => l_sql);
        
        /* Set bind variables */
        dbms_xmlgen.setbindvalue(ctx => l_ctx, bindname => 'bv_esl_mfg_code',     bindvalue => p_esl_mfg_code);
        dbms_xmlgen.setbindvalue(ctx => l_ctx, bindname => 'bv_esl_model_code',   bindvalue => p_esl_model_code);
        
        /* Make sure tags are generated for all fields even if they are null. */
        dbms_xmlgen.setnullhandling(ctx => l_ctx, flag => dbms_xmlgen.empty_tag);
   
        /* Produce the genric XML */
        l_xml := dbms_xmlgen.getxmltype(ctx => l_ctx, dtdOrSchema => dbms_xmlgen.none);

        IF l_xml IS NULL THEN
            RAISE EXC_NO_DATA_FOUND;
        END IF;
        
        --write_message('Generic XML: ' || l_xml.getclobval);
        --write_message('Length of l_xml: ' || dbms_lob.getlength(l_xml.getclobval()));

        CASE WHEN p_esl_mfg_code = xxesl_utils_pkg.c_em_sesl THEN
            /* Get the XSL from database table
               This XSL is to transform the generic ESL Kanban XML into manufacturer-specific XML that is passed to an ESL server. 
            */
            l_xsl := xxesl_utils_pkg.utl_get_db_xml_doc(p_file_name => 'SESL_TEMPLATE_TASK.XSL');
        ELSE
            l_xsl := NULL;
        END CASE;

        /* Transform the generic XML into structure suitable for the ESL server */
        l_trans_xml := l_xml.transform(xsl => l_xsl);

        --dbms_output.put_line(l_trans_xml.getclobval());
        --dbms_output.put_line(l_trans_xml.getstringval());
        write_message('transformed record count: ' || xxesl_utils_pkg.utl_record_count_in_xml (
            p_xml           => l_trans_xml
            ,p_record_path  => 'TaskOrder/TemplateTask'
        ));

        write_message('Length of l_trans_xml: ' || dbms_lob.getlength(l_trans_xml.getclobval()));
        --write_message('l_trans_xml: ' || l_trans_xml.getclobval());

        /* Only SES-imagotag is supported initially. */
        CASE p_esl_mfg_code WHEN xxesl_utils_pkg.c_em_sesl THEN
            l_resource_name := xxesl_utils_pkg.c_scheduletasks;
        ELSE
            /* Not SES-imagotag */
            l_resource_name := NULL;
        END CASE;
    
        /* Send the XML to the ESL server */
        xxesl_utils_pkg.eslsvr_create_resource(
            p_esl_mfg_code    => p_esl_mfg_code
            ,p_resource_name  => l_resource_name
            ,p_payload_xml    => l_trans_xml
            ,p_err_code       => l_err_code
            ,p_err_msg        => l_err_msg
        );
        
        IF l_err_code <> c_success THEN
            RAISE EXC_CREATE_RESOURCE_FAILED;
        END IF;
        
        retcode := c_retcode_s;
        errbuf  := 'Completed successfully';
        
    EXCEPTION
        WHEN EXC_NO_DATA_FOUND THEN 
            retcode  := c_retcode_s;
            errbuf   := c_method_name || ': No unassigned ESLs found.';
            write_message (errbuf);
        WHEN EXC_CREATE_RESOURCE_FAILED THEN 
            retcode  := c_retcode_sw;
            errbuf   := c_method_name || ': eslsvr_create_resource failed.';
            write_message (errbuf);
        WHEN OTHERS THEN
            retcode  := c_retcode_e;
            errbuf   := c_method_name || ': ' ||  SQLERRM;
            write_message (errbuf);
    END update_unassigned_esl_displays;

    ----------------------------------------------------------------------------------------------------
    --  Name:               get_request
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      05-Jan-2021
    --  Purpose:            Execute GET request against an ESL server
    --                               
    --  Description:        Generic host-agnostic procedure.  Can be used
    --                      with any web service-enabled ESL server.
    --
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   05-Jan-2021   Eric Hubert     CHG0048556: initial build
    ----------------------------------------------------------------------------------------------------
    PROCEDURE utl_get_request(
            p_url           IN  VARCHAR2
            ,p_response     OUT CLOB
            ,p_err_code     OUT NUMBER
            ,p_err_msg      OUT VARCHAR2
        )
    IS
        c_method_name CONSTANT VARCHAR(30) := 'utl_get_request';

        /* Local variables */
        l_req UTL_HTTP.REQ;
        l_res UTL_HTTP.RESP;

        l_buffer VARCHAR2(4000);
        l_response_text CLOB;

    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('Start of: ' || c_method_name);
        
        -- Define Http Version And Request Type
        l_req := utl_http.begin_request(p_url, c_http_method_get);

        -- SenD HTTP Request
        utl_http.write_text(l_req, NULL);
        
        --write_message('Before UTL_HTTP.GET_RESPONSE');

        l_res := utl_http.get_response(l_req);
        
        --write_message('After UTL_HTTP.GET_RESPONSE');

        -- Get The Response From The HTTP Call
        BEGIN
            LOOP
                utl_http.read_line(l_res, l_buffer);
                l_response_text := l_response_text || l_buffer;
            END LOOP;
        EXCEPTION
            WHEN utl_http.end_of_body THEN
                utl_http.end_response(l_res);
        END;
    
        --write_message('l_response_text: ' || l_response_text);

        utl_http.end_response(l_res);
        
        --write_message('After UTL_HTTP.END_RESPONSE');
        
        p_response := l_response_text;

        p_err_code := c_success;
        p_err_msg  := NULL;
        --write_message('End of get_request');
        
    EXCEPTION
        WHEN utl_http.end_of_body THEN
            utl_http.end_response(l_res);
            p_err_code := c_fail;
            p_err_msg  := c_method_name || ': ' || SQLERRM;
            --We expect this error to be raised, so we don't need to write the error to the log.
            write_message('l_response_text: ' || l_response_text); 
        
        WHEN OTHERS THEN --ORA-29273: HTTP request failed | ORA-12535: TNS:operation timed out
            utl_http.end_response(l_res);
            p_err_code := c_fail;
            p_err_msg  := c_method_name || ': ' || SQLERRM;
            write_message('p_err_msg: ' || p_err_msg);
            write_message('l_response_text: ' || l_response_text);            
    END utl_get_request;

    ----------------------------------------------------------------------------------------------------
    --  Name:               utl_post_request
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      05-Jan-2021
    --  Purpose:            Post request to server
    --                               
    --  Description:        Generic host-agnostic procedure.  Can be used
    --                      with any web service-enabled ESL server.
    --
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   05-Jan-2021   Eric Hubert     CHG0048556: initial build
    ----------------------------------------------------------------------------------------------------
    PROCEDURE utl_post_request(
            p_url           IN  VARCHAR2
            ,p_content      IN  CLOB
            ,p_content_type IN  VARCHAR2
            ,p_err_code     OUT NUMBER
            ,p_err_msg      OUT VARCHAR2
        )
    IS
        c_method_name CONSTANT VARCHAR(30) := 'utl_post_request';
        
        /* HTTP header names */
        c_hn_user_agent         CONSTANT VARCHAR2(30):= 'user-agent';
        c_hn_content_type       CONSTANT VARCHAR2(30):= 'content-type';
        c_hn_transfer_encoding  CONSTANT VARCHAR2(30):= 'Transfer-Encoding';
        
        /* Transfer encoding directives */
        c_ted_chunked  CONSTANT VARCHAR2(30):= 'chunked';
        
        /* HTTP header values */
        c_hv_user_agent   CONSTANT VARCHAR2(100):= gv_api_name || '/' || c_method_name; --name of package/procedure
        
        l_req utl_http.req;  --Max of 5 open at one time per Oracle
        l_res utl_http.resp;

        /* Varuabled for chunking the write and read content. */
        l_req_length    BINARY_INTEGER;
        l_buffer_req    VARCHAR2(32767);
        l_amount        PLS_INTEGER := 2000;
        l_offset        PLS_INTEGER := 1;
        l_buffer_res    VARCHAR2(32767);
        l_response_text CLOB;

    
        EXC_NULL_CONTENT        EXCEPTION;
        EXC_ESL_SERVER_ERROR    EXCEPTION;
        EXC_UNKNOWN             EXCEPTION;

    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('Start of: ' || c_method_name);
        
        IF p_content IS NULL THEN
            RAISE EXC_NULL_CONTENT;
        END IF;
        
        write_message('  p_url: ' || p_url);
        --write_message('  p_content: ' || p_content);
        --write_message('  p_content_type: ' || p_content_type);
     
        -- Define Http Version And Request Type
        l_req := utl_http.begin_request(p_url, c_http_method_post, c_http_protocol_default);

        write_message('Before UTL_HTTP.SET_HEADER');
        -- Define Browser Type
        utl_http.set_header(l_req, c_hn_user_agent, c_hv_user_agent);

        -- Define Content Type (XML, JSON .. etc)
        utl_http.set_header(l_req, c_hn_content_type, p_content_type);

        -- Define chunked transfer encoding
        utl_http.set_header(l_req, c_hn_transfer_encoding, c_ted_chunked);
        l_req_length := dbms_lob.getlength(p_content);
        
        write_message('Before UTL_HTTP.WRITE_TEXT');

        /* Send HTTP Request in chunks
          Note: this chunking was implemented some time after the "payload splitter".  There is some obvious redundancy in 
          the functionality (and the payload splitter would probably not be used if starting from scratch).  However,
          because the payload splitter breaks the payload into multiple requests, based on the number of rows
          specified in a profile option (XXESL: Maximum Request Records Per Post), we do have some level of 
          administrative control over how much information we send at one time, so both functionalities are being 
          left in place.
        */
        WHILE (l_offset < l_req_length) LOOP
            dbms_lob.read (
                lob_loc => p_content
                ,amount => l_amount
                ,offset => l_offset
                ,buffer => l_buffer_req
            );
            
            utl_http.write_text(l_req, l_buffer_req); --32767 is the PL/SQL max string limit which also applies to UTL_HTTP
            l_offset := l_offset + l_amount;
            
        END LOOP;

        write_message('Before UTL_HTTP.GET_RESPONSE');
        l_res := utl_http.get_response(l_req);

        BEGIN
            -- Get The Response From The HTTP Call
            LOOP
                utl_http.read_line(l_res, l_buffer_res);
                l_response_text := l_response_text || l_buffer_res;
            END LOOP;
            
        EXCEPTION
        /* We expect this error to be raised. */
            WHEN utl_http.end_of_body THEN
                utl_http.end_response(l_res);
        END;

        /* Perform some basic checks to see if the call to the ESL server was functionally successfull.
            1) Response should be XML.  If it is not that means there was an exception on the ESL server.  Return fail.
            2) In this procedure we don't technically know which ESL manufcaturer is being called. We are
              going to blatently take a shortcut and assume that it is SES-imagotag (though we could infer it from the URL).  For SES-imagotag, we expect to 
              get a Transaction Id returned in the response, such as:
              "<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Transaction id="2448"/>"
              If we don't see a transaction id then return fail.
              
              **At a later time, this package can be refactored to return the response in a CLOB and allow the calling procedures
              to determine if the response is considered succesful or failed.
        */
        IF DBMS_LOB.INSTR(l_response_text, '<Transaction id="' ) = 0 THEN
            RAISE EXC_ESL_SERVER_ERROR;
        END IF;

        write_message('l_response_text: ' || dbms_lob.substr(l_response_text));

        write_message('Before UTL_HTTP.END_RESPONSE');
        utl_http.end_response(l_res);
        write_message('After UTL_HTTP.END_RESPONSE');

        p_err_code := c_success;
        p_err_msg  := NULL;

    EXCEPTION
        WHEN EXC_NULL_CONTENT THEN
            utl_http.end_response(l_res);
            p_err_code := c_fail;
            p_err_msg  := c_method_name || ': no content passed to procedure.';
            write_message('p_err_msg: ' || p_err_msg);
            write_message('l_response_text: ' || dbms_lob.substr(l_response_text));  
        WHEN EXC_ESL_SERVER_ERROR THEN
            utl_http.end_response(l_res);
            p_err_code := c_fail;
            p_err_msg  := c_method_name || ': error processing request on ESL server.';
            write_message('p_err_msg: ' || p_err_msg);
            write_message('l_response_text: ' || dbms_lob.substr(l_response_text)); 
        WHEN OTHERS THEN --ORA-29273: HTTP request failed | ORA-12535: TNS:operation timed out
            utl_http.end_response(l_res);
            p_err_code := c_fail;
            p_err_msg  := c_method_name || ': ' || SQLERRM;
            write_message('p_err_msg: ' || p_err_msg);
            write_message('l_response_text: ' || dbms_lob.substr(l_response_text));
    END utl_post_request;
 
     ----------------------------------------------------------------------------------------------------
    --  Name:               utl_purge_esl_table
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      05-Jan-2021
    --  Purpose:            Purge records from a custom ESL-related table
    --
    --  Description:        The name of the table to be purged is a parameter, but only
    --                      certain tables, hard-coded in this procedure, are supported.
    --                      A "before date" is required.
    --
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   05-Jan-2021   Eric Hubert     CHG0048556: initial build
    ----------------------------------------------------------------------------------------------------
    PROCEDURE utl_purge_esl_table (
        errbuf                      OUT VARCHAR2,
        retcode                     OUT NUMBER,
        p_esl_table_name            IN  dba_tables.table_name%TYPE,
        p_purge_before_date_text    IN  VARCHAR2
    ) IS
        c_method_name CONSTANT VARCHAR(30) := 'utl_purge_esl_table';
        
        l_purge_before_date DATE;
        l_count_before NUMBER;
        l_count_after  NUMBER;
        l_purge_count  NUMBER;
    
        EXC_UNSUPPORTED_TABLE   EXCEPTION;
    
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('Start of: ' || c_method_name);  

        write_message('p_esl_table_name: ' || p_esl_table_name);
        write_message('p_purge_before_date_text: ' || p_purge_before_date_text);
        
        /* Convert date string to date */
        l_purge_before_date := TO_DATE(p_purge_before_date_text, 'RRRR/MM/DD HH24:MI:SS');

        /* Check that the target table is supported by this procedure. */
        CASE UPPER(p_esl_table_name)
        WHEN 'XXESL_LABEL_EVENTS_SESL' THEN

            /* Get record count before purge. */
            SELECT COUNT(*)
            INTO l_count_before
            FROM xxesl_label_events_sesl;

            /* Delete records before date. */
            DELETE xxesl_label_events_sesl
            WHERE creation_date < l_purge_before_date;
           
            COMMIT;

            /* Get record count after purge. */
            SELECT COUNT(*)
            INTO l_count_after
            FROM xxesl_label_events_sesl;
            
        ELSE
            RAISE EXC_UNSUPPORTED_TABLE;            
        
        END CASE;

        write_message('Record count (before): ' || l_count_before);
        write_message('Record count (after): ' || l_count_after);
        write_message('Deleted records: ' || TO_CHAR(l_count_before - l_count_after));

        retcode := c_retcode_s;

    EXCEPTION
        WHEN EXC_UNSUPPORTED_TABLE THEN
            retcode := c_retcode_sw;
            errbuf  := c_method_name || ': table not supported for purging';
            write_message('errbuf: ' || errbuf);  
        WHEN OTHERS THEN
            ROLLBACK;
            retcode := c_retcode_e;
            errbuf  := c_method_name || ': ' || SQLERRM;
            write_message('errbuf: ' || errbuf);        
    
    END utl_purge_esl_table;
    
    ----------------------------------------------------------------------------------------------------
    --  Name:               utl_split_payload
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      05-Jan-2021
    --  Purpose:            Get an portion of an XML payload.
    --                               
    --  Description:        Given XML payload, retrieve a "chunk" of the XML, with a size (in terms of number of records)
    --                      and a starting poistion (index).  The path to the records is also needed.
    --
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   05-Jan-2021   Eric Hubert     CHG0048556: initial build
    ----------------------------------------------------------------------------------------------------
    PROCEDURE utl_split_payload(
        p_payload_xml       IN XMLTYPE
        ,p_record_path      IN VARCHAR2
        ,p_index            IN NUMBER --record index
        ,p_records          IN NUMBER
        ,p_xml_chunk        OUT XMLTYPE
        ,p_err_code         OUT NUMBER
        ,p_err_msg          OUT VARCHAR2
    ) AS
        c_method_name CONSTANT VARCHAR(30) := 'utl_split_payload';

        l_xsl           XMLTYPE;
        l_xsl_generic   VARCHAR2(2000);
        l_paramap       VARCHAR2(100) := Q'[firstrow=":fr"  lastrow=":lr"]';--paramaters to pass to xmltype.translate
        l_trans_xml     XMLTYPE; --Transformed XML
        l_first_record  NUMBER;
        l_last_record   NUMBER;
        
        EXC_NULL_XML_PAYLOAD EXCEPTION;
 
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('Start of: ' || c_method_name);

        IF p_payload_xml IS NULL THEN
            RAISE EXC_NULL_XML_PAYLOAD;
        END IF;
        
        --write_message('p_payload_xml: ' || p_payload_xml.getclobval);
        
        l_first_record := p_index;
        l_last_record  := (l_first_record + p_records - 1);
        
        --write_message('l_first_record: ' || l_first_record);
        --write_message('l_last_record: ' || l_last_record);
        
        /* Substitute values for tokens */
        l_paramap := REPLACE(l_paramap, ':fr', l_first_record);
        l_paramap := REPLACE(l_paramap, ':lr', l_last_record);        
        
        /* Get the XSL from database table */
        l_xsl := utl_get_db_xml_doc(p_file_name => 'PAYLOAD_SPLITTER.XSL');
        
        /* Convert XSL to string and replace record path token with string
           (We can't use standard XSL parameters for element names, so this
           is why we do this.)
        */
        l_xsl_generic := l_xsl.getclobval;
        l_xsl_generic := REPLACE(l_xsl_generic, 'RECORD_PATH', p_record_path);
        --write_message('l_xsl_generic: ' || l_xsl_generic);
        
        l_xsl := XMLTYPE(l_xsl_generic);
        
        --write_message('l_xsl: ' || l_xsl.getclobval);
        --write_message('p_payload_xml: ' || p_payload_xml.getclobval);
    
        l_trans_xml := p_payload_xml.transform(
            xsl         => l_xsl
            ,parammap   => l_paramap
        );
        
        p_xml_chunk := l_trans_xml;
        
    EXCEPTION
        WHEN EXC_NULL_XML_PAYLOAD THEN
            p_err_code := c_fail;
            p_err_msg  := c_method_name || ': null xml payload';
            write_message('p_err_msg: ' || p_err_msg);
        WHEN OTHERS THEN
            p_err_code := c_fail;
            p_err_msg  := c_method_name || ': ' || SQLERRM;
            write_message('p_err_msg: ' || p_err_msg);
    END utl_split_payload;
    
    ----------------------------------------------------------------------------------------------------
    --  Name:               update_esl_xml_doc_from_file
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      04-Jan-2021
    --  Purpose:            Update XML document stored in the XXESL_UTIL_XML_DOCUMENTS table by uploading
    --                      an XML file from a shared folder.
    --
    --  Description:        
    --                      
    --                      
    --
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   04-Jan-2021   Eric Hubert     CHG0048556: initial build
    ----------------------------------------------------------------------------------------------------
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
    ) IS
        c_method_name CONSTANT VARCHAR(30) := 'update_esl_xml_doc_from_file';
        
        /* Local variables */
        l_count     NUMBER;
        l_bfile     BFILE;
        --l_clob      CLOB;
        l_length    INTEGER;
        l_xml       XMLTYPE;
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('Start of: ' || c_method_name);
        
        /* Write parameters to log. */
        write_message('p_directory: '       || p_directory);
        write_message('p_file_name: '       || p_file_name);
        write_message('p_char_set_name: '   || p_char_set_name);
        write_message('p_doc_name: '        || p_doc_name);
        write_message('p_doc_schema: '      || p_doc_schema);
        write_message('p_doc_desc: '        || p_doc_desc);
        write_message('p_delete_flag: '     || p_delete_flag);
   
        /* Check if the XML document record needs to be deleted. */
        IF p_delete_flag = 'Y' THEN
            /* Delete the record. */
            DELETE xxobjt.xxesl_util_xml_documents
            WHERE doc_name = p_doc_name;
            
            COMMIT;
            
            write_message('XML document record deleted successfully.');
        
        ELSE
            /* Get file and load it into an XMLTYPE variable (use utl dir for development and mnt for testing) */
            l_bfile := BFILENAME(
                directory => p_directory
                ,filename => p_file_name
            );
     
            /* Check if the file exists. */
            IF (dbms_lob.fileexists(file_loc => l_bfile) = 1) THEN
                write_message('File exists in directory.');
    
                l_xml :=XMLTYPE(
                    l_bfile
                    ,nls_charset_id(p_char_set_name)
                );
                
                /* Create a record if it is a new file, otherwise, updating the existing record. */
                MERGE INTO xxobjt.xxesl_util_xml_documents xuxd
                USING (
                    SELECT
                        p_doc_name      doc_name
                        ,l_xml          doc_content
                        ,p_doc_schema   doc_schema
                        ,p_doc_desc     description
                    FROM dual
                ) x
                ON (x.doc_name = xuxd.doc_name)
                WHEN MATCHED THEN
                    /* Update the process_flag to ignored; update who columns. */
                    UPDATE SET
                        xuxd.doc_content          = x.doc_content
                        ,xuxd.doc_schema          = x.doc_schema
                        ,xuxd.description         = x.description
                        ,xuxd.last_updated_by     = NVL(fnd_profile.value('USER_ID'), -1)
                        ,xuxd.last_update_date    = SYSDATE
                        ,xuxd.last_update_login   = USERENV('SESSIONID') 
                        ,xuxd.request_id          = fnd_global.conc_request_id
                        ,xuxd.program_id          = fnd_global.conc_program_id   
                WHEN NOT MATCHED THEN
                    INSERT (
                        xuxd.doc_name
                        ,xuxd.doc_content
                        ,xuxd.doc_schema
                        ,xuxd.description
                        ,xuxd.created_by
                        ,xuxd.creation_date
                        ,xuxd.last_updated_by
                        ,xuxd.last_update_date
                        ,xuxd.last_update_login
                        ,xuxd.request_id
                        ,xuxd.program_id
                    )
                    VALUES (
                        x.doc_name
                        ,x.doc_content
                        ,x.doc_schema
                        ,x.description
                        ,NVL(fnd_profile.value('USER_ID'), -1)
                        ,SYSDATE 
                        ,NVL(fnd_profile.value('USER_ID'), -1)
                        ,SYSDATE 
                        ,USERENV('SESSIONID') 
                        ,fnd_global.conc_request_id
                        ,fnd_global.conc_program_id
                    );
                    
                COMMIT;
                
                write_message('XML document record inserted/updated successfully.');
            ELSE
                write_message('File does not exist.');
            END IF;
        END IF;
        
        retcode := c_retcode_s;
    
    EXCEPTION
         WHEN OTHERS THEN
            ROLLBACK;
            retcode := c_retcode_e;
            errbuf  := c_method_name || ': ' || SQLERRM;
            write_message('errbuf: ' || errbuf);  
    END utl_update_xml_doc_from_file;
--------------------------------------------------------------------------------
/* Public Procedures - End */
--------------------------------------------------------------------------------
END XXESL_UTILS_PKG;
/