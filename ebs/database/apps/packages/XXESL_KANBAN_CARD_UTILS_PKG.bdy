-----------------------------------------------------------------------
--  Name:               xxesl_kanban_card_utils_pkg
--  Created by:         Hubert, Eric
--  Revision:           1.0
--  Creation Date:      05-Jan-2021
--  Purpose:            Electronic Shelf Labels for Kanban Cards
----------------------------------------------------------------------------------
--  Ver   Date          Name            Desc
--  1.0   05-Jan-2021   Eric Hubert     CHG0048556: initial build
----------------------------------------------------------------------------------

CREATE OR REPLACE PACKAGE BODY apps.xxesl_kanban_card_utils_pkg AS
    c_ac_two_stage_kanban       CONSTANT mtl_kanban_pull_sequences.attribute_category%TYPE := 'TWO_STAGE_KANBAN';

    /* Constants for the XX Replenishment Status (per Value Set XXINV_SSYS_KANBAN_REPLENISHMENT_STATUS)
       These are based on the standard Kanban Supply Statuses but there are many additional values
       that describe the state of the replenishment process in further detail, so that we can
       can display it on the ESLs or simply include it in reports.
    */
    c_rs_new                       CONSTANT mtl_kanban_cards.attribute2%TYPE := 'NEW'; --Standard "New" Supply Status
    c_rs_empty                     CONSTANT mtl_kanban_cards.attribute2%TYPE := 'EMPTY'; --Standard "Empty" Supply Status
    c_rs_wait                      CONSTANT mtl_kanban_cards.attribute2%TYPE := 'WAIT'; --Standard "Wait" Supply Status
    c_rs_in_process                CONSTANT mtl_kanban_cards.attribute2%TYPE := 'IN_PROCESS'; --Standard "In Process" Supply Status
    c_rs_in_process_no_stock       CONSTANT mtl_kanban_cards.attribute2%TYPE := 'IN_PROCESS_NO_STOCK'; --Move Order created but zero inventory in source subinventory
    c_rs_in_process_unallocated    CONSTANT mtl_kanban_cards.attribute2%TYPE := 'IN_PROCESS_UNALLOCATED'; --Move Order is not yet allocated
    c_rs_in_process_allocated      CONSTANT mtl_kanban_cards.attribute2%TYPE := 'IN_PROCESS_ALLOCATED'; --Move Order is allocated
    c_rs_in_process_printed        CONSTANT mtl_kanban_cards.attribute2%TYPE := 'IN_PROCESS_PRINTED'; --Move Order is allocated and traveler has been printed
    c_rs_in_transit                CONSTANT mtl_kanban_cards.attribute2%TYPE := 'IN_TRANSIT'; --Standard "In Transit" Supply Status
    c_rs_full                      CONSTANT mtl_kanban_cards.attribute2%TYPE := 'FULL'; --Standard "Full" Supply Status
    c_rs_full_in_transit           CONSTANT mtl_kanban_cards.attribute2%TYPE := 'FULL_IN_TRANSIT';  --MO transacted and presumed to be on truck (2-stage only);
    c_rs_full_pending_delivery     CONSTANT mtl_kanban_cards.attribute2%TYPE := 'FULL_PENDING_DELIVERY';  --Subinventory transfer to final destination completed within manufacturing facility (2-stage only)andr pending delivery to bin (standard & 2-stage)
    c_rs_full_delivery_confirmed   CONSTANT mtl_kanban_cards.attribute2%TYPE := 'FULL_DELIVERY_CONFIRMED'; --Checkmark button pushed on ESL to confirm delivery
    c_rs_full_delivery_assumed     CONSTANT mtl_kanban_cards.attribute2%TYPE := 'FULL_DELIVERY_ASSUMED'; --Checkmark button was not pushed on ESL within time limit
    c_rs_hold                      CONSTANT mtl_kanban_cards.attribute2%TYPE := 'HOLD'; --Card status is Hold
    c_rs_cancelled                 CONSTANT mtl_kanban_cards.attribute2%TYPE := 'CANCELLED'; --Card status is Cancelled
    c_rs_undetermined              CONSTANT mtl_kanban_cards.attribute2%TYPE := 'UNDETERMINED'; --Status could not be determined
    c_rs_exc                       CONSTANT mtl_kanban_cards.attribute2%TYPE := 'EXCEPTION'; --Standard "Exception" Supply Status
    c_rs_exc_document_cancelled    CONSTANT mtl_kanban_cards.attribute2%TYPE := 'EXCEPTION_DOCUMENT_CANCELLED'; --Document (Move Order, PO, Blanket Release, Job, etc.) cancelled/closed while kanban in process
    c_rs_exc_delivery_timeout      CONSTANT mtl_kanban_cards.attribute2%TYPE := 'EXCEPTION_DELIVERY_TIMEOUT'; --Confirm button not pushed before timeout period reached.
    c_rs_exc_esl_on_multiple_cards CONSTANT mtl_kanban_cards.attribute2%TYPE := 'EXCEPTION_ESL_MULTIPLE_CARDS'; --ESL ID is associated with multiple kanban cards
    c_rs_exc_replenishment_failed  CONSTANT mtl_kanban_cards.attribute2%TYPE := 'EXCEPTION_REPLENISHMENT_FAILED'; --API call to replenish kanban card failed

    /* Constants pertaining to the attempt to trigger a kanban replenishment via API */
    c_kbr_not_attempted CONSTANT VARCHAR2(30) := 'REPLENISHMENT_NOT_ATTEMPTED';
    c_kbr_success       CONSTANT VARCHAR2(30) := 'REPLENISHMENT_SUCCESS';
    c_kbr_fail          CONSTANT VARCHAR2(30) := 'REPLENISHMENT_FAIL';

    /* Constants for MTL_KANBAN_CARD_STATUS lookup */
    c_cs_active        CONSTANT NUMBER := 1; --Active
    c_cs_hold          CONSTANT NUMBER := 2; --Hold
    c_cs_cancelled     CONSTANT NUMBER := 3; --Canceled        

    /* Constants for MTL_KANBAN_SUPPLY_STATUS lookup */
    c_ss_new           CONSTANT NUMBER := 1; --New
    c_ss_full          CONSTANT NUMBER := 2; --Full
    c_ss_wait          CONSTANT NUMBER := 3; --Wait
    c_ss_empty         CONSTANT NUMBER := 4; --Empty
    c_ss_in_process    CONSTANT NUMBER := 5; --In Process
    c_ss_in_transit    CONSTANT NUMBER := 6; --In Transit
    c_ss_in_exception  CONSTANT NUMBER := 7; --Exception

    /* Constants for MTL_KANBAN_SOURCE_TYPE lookup */
    c_st_inter_org     CONSTANT NUMBER := 1; --Inter Org
    c_st_supplier      CONSTANT NUMBER := 2; --Supplier
    c_st_intra_org     CONSTANT NUMBER := 3; --Intra Org
    c_st_production    CONSTANT NUMBER := 4; --Production

    /* Constants for MTL_TXN_REQUEST_STATUS lookup (Move Order Status) */
    c_ms_incomplete         CONSTANT NUMBER := 1;	--Incomplete
    c_ms_pending_approval   CONSTANT NUMBER := 2;	--Pending Approval
    c_ms_approved           CONSTANT NUMBER := 3;	--Approved
    c_ms_not_approved       CONSTANT NUMBER := 4;	--Not Approved
    c_ms_closed             CONSTANT NUMBER := 5;	--Closed
    c_ms_canceled           CONSTANT NUMBER := 6;	--Canceled
    c_ms_pre_approved       CONSTANT NUMBER := 7;	--Pre Approved
    c_ms_partially_approved CONSTANT NUMBER := 8;	--Partially Approved
    c_ms_canceled_by_source CONSTANT NUMBER := 9;	--Canceled by Source

    /* Return/error codes for procedures */
    c_success      CONSTANT NUMBER := 0; --Success
    c_fail         CONSTANT NUMBER := 1; --Fail
    
    /* Retcode values for concurrent programs*/
    c_retcode_s     CONSTANT NUMBER := 0; --Success
    c_retcode_sw    CONSTANT NUMBER := 1; --Success with Warning
    c_retcode_e     CONSTANT NUMBER := 2; --Error
    
    c_event_acknowledged_code CONSTANT VARCHAR2(30) := 'EVENT_ACKNOWLEDGED';
    
    /* Private variables to package body */
    v_kbr_api_status    VARCHAR2(30) := c_kbr_not_attempted; --Result of attempt to trigger kanban replenishment via API
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
--NONE
--------------------------------------------------------------------------------
/* Private Functions - End */
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
/* Public Functions - Start: */
--------------------------------------------------------------------------------
    ----------------------------------------------------------------------------------------------------
    --  Name:               update_esl_display_fp
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      05-Jan-2021
    --  Purpose :           This function will create a concurrent request for the
    --  'XXESL: Update Kanban Cards' (XXESL_UPDATE_KANBAN_CARDS).  It intended to 
    --  be called from a forms personalization on the kanban card or pull sequence form.
    --    
    --  Description: The function has
    --  separate arguments for the Kanban Card Number, Kanban Card ID, and Pull Sequence ID.
    --  This allows for the printing of a specific scope of kanban cards, for a
    --  single specific card or for all cards in a pull sequence.  The intent
    --  is to call this function from a forms personalization on the Pull
    --  Sequence and/or Kanban Card forms.
    --
    ----------------------------------------------------------------------------------------------------
    --  Version     Date          Name            Description
    --  1.0         05-Jan-2021   Hubert, Eric    CHG0041284 - Initial build
    ----------------------------------------------------------------------------------------------------
    FUNCTION update_esl_display_fp (
         p_organization_id      IN NUMBER
         ,p_kanban_card_id      IN NUMBER  --Either Kanban Card ID or pull sequence id need to be specified.
         ,p_pull_sequence_id    IN NUMBER
    ) RETURN NUMBER --Return Concurrent Request ID
    IS
        /* Local Variables*/
        l_request_id NUMBER;

    BEGIN
        /* Check that the necessary parameters and variables have values. */
        IF p_kanban_card_id IS NULL AND p_pull_sequence_id IS NULL THEN
            RAISE_APPLICATION_ERROR (-20001, 'update_esl_display_fp: Kanban Card ID or Pull Sequence ID must be provided.');
        END IF;

        /*Submit Request*/
        l_request_id := fnd_request.submit_request (
            application=> 'XXOBJT',
            program => 'XXESL_UPDATE_KANBAN_CARDS',
            description=> 'XXESL: Update Kanban Cards',
            start_time => '',
            sub_request=> FALSE,
            argument1  => p_organization_id, --Organization Identifier
            argument2  => p_kanban_card_id, --Kanban Card ID
            argument3  => p_pull_sequence_id, --Pull Sequence ID
            argument4  => NULL, --ESL ID
            argument5  => NULL, --Source Subinventory
            argument6  => NULL,  --Final Destination Subinventory
            argument7  => xxesl_utils_pkg.c_em_sesl,  --ESL Manufacturer Code (yes, we're totally cheating here by hardcoding it.  To be technically correct we'd need to interrogate the ESL Registry.)
            argument8  => NULL,  --ESL Model Code
            argument9  => 'N',  --Labels with events only
            argument10 => 'Y', --Run ESL Replenishment Manager
            argument11 => 'Y'  --Send to ESL Server
        );

        COMMIT;

        /*Exceptions*/
        IF ( l_request_id <> 0)
        THEN
             dbms_output.put_line('Concurrent request succeeded: ' || l_request_id);
        ELSE
             dbms_output.put_line('Concurrent Request failed to submit: ' || l_request_id);
             dbms_output.put_line('Request Not Submitted due to "' || fnd_message.get || '".');
        END IF;

        RETURN l_request_id;

        EXCEPTION
            WHEN OTHERS THEN
                /* If function was called in the context of a concurrent program,
                write the error to the log file.  Otherwise write to dbms_output. */
                IF fnd_global.conc_request_id <> -1 THEN
                    write_message('Unhandled exception: ' || SQLERRM );
                    dbms_output.put_line('Unhandled exception: ' || SQLERRM );
                ELSE
                    write_message(SQLERRM);
                    dbms_output.put_line(SQLERRM);
                END IF;
                
                /* Return*/
                RETURN NULL;
    END update_esl_display_fp;
--------------------------------------------------------------------------------
/* Public Functions - End */
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
/* Private Procedures - Start: */
--------------------------------------------------------------------------------

    ----------------------------------------------------------------------------------------------------
    --  Name:               utl_kb_mo_closed_date
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      05-Jan-2021
    --  Purpose:            Get date that a kanban-related Move Order was Closed.
    --
    --  Description:        A query, based on several kanban/ESL-specific views,
    --                      is executed by the dbms_xmlgen package to produce
    --
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   05-Jan-2021   Eric Hubert     CHG0048556: initial build
    ----------------------------------------------------------------------------------------------------
    PROCEDURE utl_kb_mo_closed_date (
        p_kanban_card_id        IN  NUMBER
        ,p_inventory_item_id    IN  NUMBER
        ,p_from_subinventory    IN  mtl_txn_request_lines.from_subinventory_code%TYPE
        ,p_to_subinventory      IN  mtl_txn_request_lines.to_subinventory_code%TYPE
        ,p_organization_id      IN  NUMBER
        ,p_status_date          OUT DATE
        ,p_err_code             OUT NUMBER
        ,p_err_msg              OUT VARCHAR2
    ) IS
        c_method_name   CONSTANT VARCHAR(30) := 'utl_kb_mo_closed_date';
        l_status_date   mtl_txn_request_lines.status_date%TYPE;

    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('Start of: ' || c_method_name);    
            
        /* We need to get information about the closed move order subinventory transfer from the "to" subinventory to the final destination subinventory. */

        --write_message('l_inventory_item_id: ' || l_inventory_item_id);
        --write_message('l_from_subinventory: ' || l_from_subinventory);
        --write_message('l_to_subinventory: ' || l_to_subinventory);
        --write_message('l_organization_id: ' || l_organization_id);

        SELECT
            status_date                            
        INTO l_status_date
        FROM mtl_txn_request_lines
        WHERE --Use several indexed columns to maximize performance:
            reference_id                    = p_kanban_card_id --Kanban Card ID
            AND inventory_item_id           = P_inventory_item_id
            AND from_subinventory_code      = P_from_subinventory
            AND to_subinventory_code        = P_to_subinventory
            AND line_status                 = 5 --Closed
            AND transaction_type_id         = 64 --Move Order Transfer
            AND transaction_source_type_id  = 4
            AND organization_id             = P_organization_id
        /*  We choose to get the newest move order. */
        ORDER BY line_id DESC
        FETCH FIRST 1 ROWS ONLY;

        p_status_date := l_status_date;

    EXCEPTION
         WHEN OTHERS THEN
            p_status_date := NULL;
            p_err_code  := c_fail;
            p_err_msg  := c_method_name || ': ' || SQLERRM;
            write_message('p_err_msg: ' || p_err_msg);
    END utl_kb_mo_closed_date;

    ----------------------------------------------------------------------------------------------------
    --  Name:               generate_esl_kb_card_xml
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      05-Jan-2021
    --  Purpose:            Create kanban-related XML for consumption by an ESL
    --                      server.
    --
    --  Description:        A query, based on several kanban/ESL-specific views,
    --                      is executed by the dbms_xmlgen package to produce
    --                      "generic" XML.  Subsequently, an ESL manufacturer-
    --                      specific XSL file is used to transform the XML into
    --                      a second XML file, relevant for that manufacturer's
    --                      ESL server.  For the initial rollout, we are using
    --                      ESLs manufactured by SES-imagotag.
    --
    --                      The XSL files are stored in a custom Oracle database
    --                      column, XXESL_UTIL_XML_DOCUMENTS.  This was chosen 
    --                      over hard-coding the XSL into this package, or 
    --                      trying to utilize an existing application table that
    --                      had a form/UI.
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   05-Jan-2021   Eric Hubert     CHG0048556: initial build
    ----------------------------------------------------------------------------------------------------
    PROCEDURE generate_esl_kb_card_xml(
        p_org_id                    IN NUMBER,   --Organization in which kanban card is defined
        p_kanban_card_id            IN NUMBER,   --Optional way to target a specific kanban card
        p_pull_sequence_id          IN NUMBER,   --optional way to target a specific pull sequence
        p_esl_id                    IN VARCHAR2, --Optional way to target a specific ESL label
        p_source_subinv             IN VARCHAR2, --Kanban Source Subinventory
        p_fdt_subinv                IN VARCHAR2, --Kanban Final Deliver-To Subinventory (Destination Subinventory unless Final Destination Subinventory on Pull Sequence is specified)
        p_esl_mfg_code              IN fnd_flex_values.flex_value%TYPE,
        p_esl_model_code            IN VARCHAR2,
        p_cards_with_events_only    IN VARCHAR2, --Y: only generate XML for cards that had a label event (i.e. a button was pushed on the ESL).  These events would have been processed and "flagged" via a package variable in a prior procedure.
        p_tasks_xml                 OUT XMLTYPE,
        p_err_code                  OUT NUMBER,
        p_err_msg                   OUT VARCHAR2

    ) IS
        c_method_name CONSTANT VARCHAR(30) := 'generate_esl_kb_card_xml';

        /* Local Constants */
        l_sql VARCHAR2(4000);
        l_ctx dbms_xmlgen.ctxhandle;
    
        l_xml XMLTYPE;
        l_xsl XMLTYPE;
        l_transformed XMLTYPE;
        
        EXC_NO_ROWS_IN_XML  EXCEPTION;
        PRAGMA EXCEPTION_INIT(EXC_NO_ROWS_IN_XML, -30625);
        
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('Start of: ' || c_method_name);      
 
        write_message('p_org_id: ' || p_org_id);
        write_message('p_kanban_card_id: ' || p_kanban_card_id); 
        write_message('p_pull_sequence_id: ' || p_pull_sequence_id); 
        write_message('p_source_subinv: ' || p_source_subinv); 
        write_message('p_fdt_subinv: ' || p_fdt_subinv); 
        write_message('p_esl_mfg_code: ' || p_esl_mfg_code); 
        write_message('p_esl_model_code: ' || p_esl_model_code); 
        write_message('p_cards_with_events_only: ' || p_cards_with_events_only); 
        
        /* SQL to get a wide variety of kanban-related information */
        l_sql := Q'[
        SELECT * 
        FROM xxesl_kb_main_v 
        WHERE 1=1
            AND k_esl_id_dff IS NOT NULL
            AND k_organization_id = :bv_org_id
            /* Conditional Kanban Card ID criteria */
            AND (
                CASE WHEN :bv_kanban_card_id IS NOT NULL AND k_kanban_card_id = :bv_kanban_card_id THEN
                    1
                WHEN :bv_kanban_card_id IS NULL THEN
                    1
                ELSE
                    0
                END
            ) = 1
            /* Conditional Pull Sequence ID criteria */
            AND (
                CASE WHEN :bv_pull_sequence_id IS NOT NULL AND k_pull_sequence_id = :bv_pull_sequence_id THEN
                    1
                WHEN :bv_pull_sequence_id IS NULL THEN
                    1
                ELSE
                    0
                END
            ) = 1
            /* Conditional ESL ID criteria */
            AND (
                CASE WHEN :bv_esl_id IS NOT NULL AND e_esl_id = :bv_esl_id THEN
                    1
                WHEN :bv_esl_id IS NULL THEN
                    1
                ELSE
                    0
                END
            ) = 1
            /* Conditional Source Subinventory criteria */
            AND (
                CASE WHEN :bv_source_subinv IS NOT NULL AND k_source_subinventory = :bv_source_subinv THEN
                    1
                WHEN :bv_source_subinv IS NULL THEN
                    1
                ELSE
                    0
                END
            ) = 1
            /* Conditional FDT Subinventory criteria */
            AND (
                CASE WHEN :bv_fdt_subinventory IS NOT NULL AND fdt_subinventory = :bv_fdt_subinventory THEN
                    1
                WHEN :bv_fdt_subinventory IS NULL THEN
                    1
                ELSE
                    0
                END
            ) = 1  
            /* Conditional ESL Manufacturer criteria */
            AND (
                CASE WHEN :bv_esl_mfg_code IS NOT NULL AND e_esl_manufacturer_code = :bv_esl_mfg_code THEN
                    1
                WHEN :bv_esl_mfg_code IS NULL THEN
                    1
                ELSE
                    0
                END
            ) = 1  
            /* Conditional ESL Model criteria */
            AND (
                CASE WHEN :bv_esl_model_code IS NOT NULL AND e_esl_model_code = :bv_esl_model_code THEN
                    1
                WHEN :bv_esl_model_code IS NULL THEN
                    1
                ELSE
                    0
                END
            ) = 1
            
            /* Conditional event criteria. Only cards that just had a label event should be included. */
            AND (
                CASE WHEN :bv_cards_with_events_only = 'Y' AND e_esl_event_id = :bv_event_acknowledged_code THEN
                    1
                WHEN :bv_cards_with_events_only <> 'Y' THEN
                    1
                ELSE
                    0
                END
            ) = 1 
        ]';

        l_ctx := dbms_xmlgen.newContext(queryString => l_sql);
        
        /* Set bind variables */
        dbms_xmlgen.setbindvalue(ctx => l_ctx, bindname => 'bv_org_id',                     bindvalue => p_org_id);
        dbms_xmlgen.setbindvalue(ctx => l_ctx, bindname => 'bv_kanban_card_id',             bindvalue => p_kanban_card_id);
        dbms_xmlgen.setbindvalue(ctx => l_ctx, bindname => 'bv_pull_sequence_id',           bindvalue => p_pull_sequence_id);
        dbms_xmlgen.setbindvalue(ctx => l_ctx, bindname => 'bv_esl_id',                     bindvalue => p_esl_id);
        dbms_xmlgen.setbindvalue(ctx => l_ctx, bindname => 'bv_source_subinv',              bindvalue => p_source_subinv);
        dbms_xmlgen.setbindvalue(ctx => l_ctx, bindname => 'bv_fdt_subinventory',           bindvalue => p_fdt_subinv);
        dbms_xmlgen.setbindvalue(ctx => l_ctx, bindname => 'bv_esl_mfg_code',               bindvalue => p_esl_mfg_code);
        dbms_xmlgen.setbindvalue(ctx => l_ctx, bindname => 'bv_esl_model_code',             bindvalue => p_esl_model_code);
        dbms_xmlgen.setbindvalue(ctx => l_ctx, bindname => 'bv_cards_with_events_only',     bindvalue => p_cards_with_events_only);
        dbms_xmlgen.setbindvalue(ctx => l_ctx, bindname => 'bv_event_acknowledged_code',    bindvalue => c_event_acknowledged_code);        
      
        /* Make sure tags are generated for all fields even if they are null. */
        dbms_xmlgen.setnullhandling(ctx => l_ctx, flag => dbms_xmlgen.empty_tag);
        
        /* Produce the genric XML */
        l_xml := dbms_xmlgen.getxmltype(ctx => l_ctx, dtdOrSchema => dbms_xmlgen.none);

        --write_message('Generic XML: ' || l_xml.getclobval);

        CASE WHEN p_esl_mfg_code = xxesl_utils_pkg.c_em_sesl THEN
            /* Get the XSL from database table
               This XSL is to transform the generic ESL Kanban XML into manufacturer-specific XML that is passed to an ESL server. 
            */
            l_xsl := xxesl_utils_pkg.utl_get_db_xml_doc(p_file_name => 'SESL_TEMPLATE_TASK.XSL');
        ELSE
            l_xsl := NULL;
        END CASE;

        /* Transform the generic XML into structure suitable for the ESL server */
        l_transformed := l_xml.transform(xsl => l_xsl);

        --write_message('l_transformed.getstringval(): ' || l_transformed.getstringval());
        write_message('transformed record count: ' || xxesl_utils_pkg.utl_record_count_in_xml (
            p_xml           => l_transformed
            ,p_record_path  => 'TaskOrder/TemplateTask'
        ));
       
        p_tasks_xml := l_transformed;
        
        p_err_code := c_success;
        p_err_msg  := NULL;
        
        EXCEPTION
            WHEN EXC_NO_ROWS_IN_XML THEN --We expect this to happen regularly when running this procedure to look for just labels with events.
                p_tasks_xml := NULL;
                p_err_code  := c_success;
                p_err_msg   := 'No rows in XML (no rows in source SQL)';
                write_message (p_err_msg);
            WHEN OTHERS THEN
                p_tasks_xml := NULL;
                p_err_code  := c_fail;
                p_err_msg   := c_method_name || ': ' ||  SQLERRM;
                write_message (p_err_msg);
                
    END generate_esl_kb_card_xml;

    ----------------------------------------------------------------------------------------------------
    --  Name:               replenish_kb_card
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      05-Jan-2021
    --  Purpose:            Call the API to replenish the kanban cards.
    --                               
    --  Description:        No business rules are evaluated here.  The decision
    --                      to replenish or not needs to be made by the calling
    --                      procedure.
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   05-Jan-2021   Eric Hubert     CHG0048556: initial build
    ----------------------------------------------------------------------------------------------------
    PROCEDURE replenish_kb_card(
        p_kanban_card_id     NUMBER
        ,p_err_code          OUT NUMBER
        ,p_err_msg           OUT VARCHAR2
    ) AS
        c_method_name CONSTANT VARCHAR(30) := 'replenish_kb_card';

        x_msg_count     NUMBER := 0;
        x_msg_data      VARCHAR2(1000);
        x_return_status VARCHAR2(2);    
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('Start of: ' || c_method_name);  
        
        inv_kanban_pub.update_card_supply_status (
            p_api_version_number => 1.0,
            p_commit             => fnd_api.g_true,
            x_return_status      => x_return_status,
            x_msg_count          => x_msg_count,
            x_msg_data           => x_msg_data,
            p_supply_status      => 4, --Empty: will trigger replenishment
            p_kanban_card_id     => p_kanban_card_id
        );
        
        --write_message('return status: '|| x_return_status);
        --write_message('msg count: '|| x_msg_count);
        --write_message('msg: '|| x_msg_data );
        
        IF x_return_status = fnd_api.g_ret_sts_success THEN
            p_err_code := c_success;
        ELSE
            p_err_code := c_fail;
        END IF;            
            
        p_err_msg  := x_msg_data;
        
    EXCEPTION
         WHEN OTHERS THEN
            p_err_code := c_fail;
            p_err_msg  := c_method_name || ': ' || SQLERRM;
            write_message('p_err_msg: ' || p_err_msg);
    END replenish_kb_card;

    ----------------------------------------------------------------------------------------------------
    --  Name:               update_kb_dff_repl_status
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      05-Jan-2021
    --  Purpose:            Update the (Stratasys) Replenishment Status DFF on
    --                      the kanban card.
    --                               
    --  Description:        The label event DFF is updated by the
    --                      eval_replenishment_status procedure.
    --
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   05-Jan-2021   Eric Hubert     CHG0048556: initial build   
    ----------------------------------------------------------------------------------------------------
    PROCEDURE update_kb_dff_repl_status(
        p_kanban_card_id     NUMBER
        ,p_new_status        mtl_kanban_cards.attribute2%TYPE
        ,p_err_code          OUT NUMBER
        ,p_err_msg           OUT VARCHAR2
    )  IS
        c_method_name CONSTANT VARCHAR(30) := 'update_kb_dff_repl_status';

    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('Start of: ' || c_method_name);  

        /* SQL to update the kanban card record*/
        UPDATE mtl_kanban_cards 
        SET
            attribute2         = p_new_status
            /* Who columns: */
            ,last_updated_by   = NVL(fnd_profile.value('USER_ID'), -1) 
            ,last_update_date  = SYSDATE
            ,last_update_login = USERENV('SESSIONID') 
            ,request_id        = fnd_global.conc_request_id
            ,program_id        = fnd_global.conc_program_id
        WHERE kanban_card_id = p_kanban_card_id;

        COMMIT;       
        
        p_err_code := c_success;
        p_err_msg  := NULL;
        
    EXCEPTION
        WHEN OTHERS THEN
            p_err_msg := c_method_name || ': ' || SQLERRM;
            write_message(p_err_msg);
            p_err_code := c_fail;
    END update_kb_dff_repl_status;

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
    BEGIN
        CASE
        WHEN c_log_method = 0 THEN --No logging
            NULL;
        
        /* Concurrent request and fnd_file.log. */
        WHEN c_log_method = 1 and fnd_global.conc_request_id <> '-1' THEN
            /* Write to concurrent request log file. */
            fnd_file.put_line(
                which => p_file_name,
                buff  => '[' || xxesl_utils_pkg.local_datetime || '] ' || p_msg
                );

        /* fnd_log_messages */
        WHEN c_log_method = 2 THEN
            /* Write to fnd_log_messages. */
            fnd_log.string(
                log_level => fnd_log.level_unexpected,
                module    => gv_api_name || '.' || gv_log_program_unit,
                message   => p_msg
                );
                
        /* dbms_output */
        WHEN c_log_method = 3 THEN
            dbms_output.put_line(
                '[' || xxesl_utils_pkg.local_datetime || '] ' || p_msg
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
    --  Name:               esl_replenishment_manager
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      05-Jan-2021
    --  Purpose:            Handles the response to label events and updating the replenishment status 
    --                               
    --  Description:        These three main activities happen in this procedure:
    --       1) First initiate any qualifying replenishments
    --       2) Update replenishment status, which will consider confirm button events
    --       3) Clear event DFF
    --  
    --   1) For Replenish Request: need to make sure that Replenishment Status is in a New or 
    --   Full Confirmed/Assumed state.  Do we need to know how long it has been in this status? No,
    --   because we would have cleared the event dff right after we updated it to that status, so
    --   any event since then would have occurred during the current replenishment status.
    --   
    --   There should be no need to evaluate the status before 
    --   this check because we need to view this event in terms of the current esl display 
    --   content.  Wouldn't be necessary because the server would
    --   report if there were issues pushing content to the label itself.  that in itself
    --   would be an exception.
    --   
    --   If we wanted to be fancy, we could interrogate the content of the label
    --   itself to see if it is displaying content for one of the approved statuses. In fact
    --   we theoretically use the PNG content on extra pages on the ESLs to store non-graphical 
    --   information.  Not sure what this would do to battery life.  The server stores the
    --   most recent image for each page so ther emay not be a need to retrieve it from the 
    --   label itself.  
    --
    --   2) For Confirm: need to examine label event date and see if it occurs after the 
    --   subinventory transfer transaction date.
    --   
    --   If the confirm button happens shortly after the sub transfer (or PO receipt, or
    --   job completion) then we won't have time to push the "pending delivery" person
    --   icon to the display before they do this button push.  Therefore, we SHOULD
    --   update the repl status to advance it as far as possible before checking to 
    --   see if the confirm button was pushed.  We should wait to clear the event dff
    --   until after the update.
    --
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   05-Jan-2021   Eric Hubert     CHG0048556: initial build   
    ---------------------------------------------------------------------------------------------------- 
    PROCEDURE esl_replenishment_manager(
        p_org_id                IN  NUMBER
        ,p_esl_kb_cards_only    IN  VARCHAR2 DEFAULT 'Y' --Y: only update cards that have an ESL ID assigned
        ,p_pending_events_only  IN  VARCHAR2 DEFAULT 'N' --Y: only update cards for which there is an unprocessed label event (i.e. a button was pushed on the ESL).
        ,p_kanban_card_id       IN  NUMBER               --Only update this specific kanban card
        ,p_pull_sequence_id     IN  NUMBER
        ,p_err_code             OUT NUMBER
        ,p_err_msg              OUT VARCHAR2
    )
    IS
        c_method_name CONSTANT VARCHAR(30) := 'esl_replenishment_manager';
    
        l_repl_status           VARCHAR2(30);
        l_sesl_event_row        xxesl_label_events_sesl%ROWTYPE;
        l_label_event           VARCHAR2(100);
        
        /* Other Local Variables */
        l_err_msg       VARCHAR2(1000);
        l_err_code      NUMBER;
        
        j NUMBER := 0; --loop counter
    
        /* Get kanban cards and related record in ESL registry. */
        CURSOR cur_kbc IS
        SELECT
            mkc.pull_sequence_id
            ,mkc.kanban_card_id
            ,mkc.attribute2 --Stratasys Replenishment Status DFF
            ,mkc.attribute3 --ESL ID
            ,qxerov.xx_esl_event_id
        FROM mtl_kanban_cards mkc
        /* Join to ESL registry (collection plan) */
        INNER JOIN q_xx_esl_registry_oma_v qxerov ON (
            qxerov.xx_esl_id = mkc.attribute3
            AND qxerov.xx_esl_manufacturer_code = xxesl_utils_pkg.c_em_sesl
        )--Only SES-imagotag has button events so we hardcode that here for convenience, for now.
        WHERE 1=1
            AND mkc.organization_id = p_org_id
            
            /* Exclude canceled cards that are not associated with an ESL.  We DO want to include Canceled cards that are associated with an ESL so that we can write a message indicating that they are indeed cancelled. */
            AND NOT (mkc.attribute3 IS NULL AND mkc.supply_status = c_cs_cancelled)
            
            /* Conditional criteria for limiting to only ESL-enabled cards. */
            AND (
                CASE
                WHEN p_esl_kb_cards_only = 'Y' AND mkc.attribute3 IS NOT NULL THEN --ESL ID is not null
                    1
                WHEN p_esl_kb_cards_only <> 'Y' THEN --all cards
                    1
                ELSE
                    0
                END
            ) = 1
            
            /* Conditional criteria for ESL with an unprocessed event. */
            AND (
                CASE
                WHEN p_pending_events_only = 'Y' AND qxerov.xx_esl_event_id IS NOT NULL THEN --A button was pushed
                    1
                WHEN p_pending_events_only <> 'Y' THEN --all cards
                    1
                ELSE
                    0
                END
            ) = 1
            
            /* Conditional criteria for specific kanban card. */
            AND (
                CASE
                WHEN p_kanban_card_id IS NOT NULL AND p_kanban_card_id = mkc.kanban_card_id THEN --Specific card
                    1
                WHEN p_kanban_card_id IS NULL THEN --all cards
                    1
                ELSE
                    0
                END
            ) = 1
            /* Conditional criteria for specific pull sequence. */
            AND (
                CASE
                WHEN p_pull_sequence_id IS NOT NULL AND p_pull_sequence_id = mkc.pull_sequence_id THEN --Specific pull sequence
                    1
                WHEN p_pull_sequence_id IS NULL THEN --all pull sequences
                    1
                ELSE
                    0
                END
            ) = 1;
            
        l_kbc_row cur_kbc%ROWTYPE;
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('Start of: ' || c_method_name);  

        /* Import label events (initially we have only one ESL manufacturer that we need to be concerned with) */
        xxesl_utils_pkg.eslsvr_import_label_events(
            p_org_id                => p_org_id
            ,p_esl_mfg_code         => xxesl_utils_pkg.c_em_sesl
            ,p_err_code             => l_err_code
            ,p_err_msg              => l_err_msg
        );
       
        /* If there was an issue importing the label events then raise a warning in the concurrent program but still continue in this procedure */
        IF l_err_code <> c_success THEN
            write_message('Unable to import label events: ' || l_err_msg);
        END IF;

        OPEN cur_kbc;
            
        LOOP
            FETCH cur_kbc INTO l_kbc_row;
            
            EXIT WHEN cur_kbc%NOTFOUND;
            j:= j + 1;
            write_message('k_kanban_card_id: ' || l_kbc_row.kanban_card_id);
            write_message('Loop [' || j || '] iteration start time: ' || xxesl_utils_pkg.local_datetime);

            v_kbr_api_status := c_kbr_not_attempted; --Reinitialize for each kanban card loop

            /* Make up two updates to the Stratasys Replenishment Status
               1) Get the status up to date to subsequently evaluate business rules
               2) If we needed to trigger a replenishment, then update it again after that.
            
            */
            FOR i IN 1..2
            LOOP
                
                /* Evaluate the Stratasys Replenishment Status*/
                eval_replenishment_status(
                        p_kanban_card_id        => l_kbc_row.kanban_card_id
                        ,p_replenishment_status => l_repl_status
                        ,p_err_code             => l_err_code
                        ,p_err_msg              => l_err_msg
                    );
                
                write_message('l_repl_status (proposed new value): ' || l_repl_status);
                write_message('Matched Rule: ' || l_err_msg);

                /* Update the Stratasys Replenishment Status if it has changed. */
                IF  (l_repl_status IS NOT NULL AND l_kbc_row.attribute2 IS NULL)
                    OR (l_repl_status <> l_kbc_row.attribute2) THEN
                        --write_message('before update_kb_dff_repl_status');
                    
                    update_kb_dff_repl_status(
                        p_kanban_card_id    => l_kbc_row.kanban_card_id
                        ,p_new_status       => l_repl_status
                        ,p_err_code         => l_err_code
                        ,p_err_msg          => l_err_msg            
                    );
                END IF;
                
                --write_message('l_err_code: ' || l_err_code);
                
                /* If status evaluation was successfull and there is an ESL ID associated 
                with the kanban card, then handle label/button events. */
                IF l_err_code = c_success AND l_kbc_row.attribute3 IS NOT NULL THEN
                
                    /* Check for a button event. */
                    xxesl_utils_pkg.sesl_event_row(
                        p_event_id      => l_kbc_row.xx_esl_event_id
                        ,p_event_row    => l_sesl_event_row
                        ,p_err_code     => l_err_code
                        ,p_err_msg      => l_err_msg);

                    l_label_event  := l_sesl_event_row.event_type;

                    /* Take action based upon button events*/
                    CASE WHEN l_label_event = TO_CHAR(xxesl_utils_pkg.c_btn_shopping_cart) --Shopping cart button pushed
                        AND l_kbc_row.attribute3 IS NOT NULL THEN--has an ESL assigned
                        /* A replenishment has been requested via the "shopping cart" button on the ESL.
                           Check if the current Stratasys Replenishment Status is one that allows for the
                           repelnishment to be triggered and call the API to update the Kanban Card Status
                           to trigger the replenishment.
                        */
                        
                        l_label_event := c_event_acknowledged_code;

                        IF l_repl_status IN (
                                c_rs_new
                                ,c_rs_full_delivery_confirmed
                                ,c_rs_full_delivery_assumed
                            ) THEN
                            
                            /* Trigger the replenishment */
                            replenish_kb_card(
                                p_kanban_card_id    => l_kbc_row.kanban_card_id
                                ,p_err_code         => l_err_code
                                ,p_err_msg          => l_err_msg 
                            );
                            
                            --write_message('after replenish_kb_card');
                            
                            /* If a kanban replenishment (API) was attempted and failed, we want to communicate
                               that to the shop floor by updating indicating such on the ESL display.  To do 
                               this we simply update a private package variable which will be checked in the
                               next loop when the repelnishment status is evaluated a second time.
                            */
                            IF l_err_code = c_success THEN
                                v_kbr_api_status := c_kbr_success;
                            ELSE
                                v_kbr_api_status := c_kbr_fail;
                            END IF;
                            
                            --loop on error to update to exception
                            
                        ELSE
                            EXIT;
                        END IF;
                        
                    WHEN l_label_event = TO_CHAR(xxesl_utils_pkg.c_btn_check_mark)                    
                        AND l_kbc_row.attribute3 IS NOT NULL THEN --has an ESL assigned
                            /* No special action is needed here to "process" events for the checkmark button.
                               We will "detect" this button when evaluating the replenishnment status 
                               (eval_replenishment_status).
                            */
                            
                            l_label_event := c_event_acknowledged_code;
                            
                            EXIT; --No need to evaluate status a second time.
                            
                    WHEN l_label_event = c_event_acknowledged_code THEN --This would be the case when thel had an event during the previous time the replenishment manager ran.
                        
                        l_label_event := NULL; --Clear the variable so that we can clear the Event ID in the ESL Registry after the loop end.
                        
                        EXIT;--No need to evaluate status a second time.
                        
                    ELSE
                        EXIT;--No need to evaluate status a second time.
                    END CASE;
                ELSE
                    EXIT;
                END IF;
            END LOOP;

            /* We consider button push events to be the equivalent of a "one shot"
               on a PLC (programmable logic controler).  Just as a one shot is 
               active for one "scan" on a PLC, a button event (as indicated in the
               corresponding DFF on the kanban card) is considered active for one
               loop in this procedure.  Here, at the end of the loop, we clear
               the button event DFF.  (The sesl_import_label_events procedure
               handles populating values in response to retrieving the label's
               most recent button event from the ESL server.)
               
               While there is no physical way to disable the buttons on the ESLs,
               we are effectively "soft" disabling them by only recognizing that
               they have been pushed when the Stratasys Replenishment Status
               has certain values.  If a button was pushed while the status is not
               one of these statuses, then we simply ignore that the button was `
               pushed.  It is a training exercise to show users when button-pushes
               will be recognized by Oracle.  There will be clear indications on 
               the bottom of the ESL display as to when button pushes will have 
               an effect, though it may take a while to update the entire display.
            */
            --write_message('before c_debug_clear_lbl_event_flag');
            IF l_kbc_row.xx_esl_event_id IS NOT NULL THEN --only clear it if it is not already null

                /* If we "acknowledged" that a button event occurred in this procedure, 
                  update the event ID to be a special value that can be recognized during 
                  the query for creating kanban card XML.  Otherwise set it to null.
                */
                IF l_label_event <> c_event_acknowledged_code THEN
                    l_label_event := NULL;
                END IF;

                /* Update the ESL Button Event. */
                xxesl_utils_pkg.eslreg_update_label_event(
                        p_esl_mfg_code      =>  xxesl_utils_pkg.c_em_sesl
                        ,p_esl_id           =>  l_kbc_row.attribute3
                        --,p_event_id         =>  NULL  --clear the event
                        ,p_event_id         =>  l_label_event
                        ,p_err_code         =>  l_err_code
                        ,p_err_msg          =>  l_err_msg
                );

                write_message('Result of eslreg_update_label_event:' || l_err_code);
                l_kbc_row.xx_esl_event_id := NULL; --Also clear the button event in the local record variable ( to be safe)
            END IF;

        END LOOP;
        --write_message('after outer loop');
        
        CLOSE cur_kbc;

        p_err_code := c_success;
        p_err_msg  := NULL;
    
    EXCEPTION
         WHEN OTHERS THEN
            p_err_code := c_fail;
            p_err_msg  := c_method_name || ': ' || SQLERRM;
            write_message('p_err_msg: ' || p_err_msg);    
    END esl_replenishment_manager;

    ----------------------------------------------------------------------------------------------------
    --  Name:               eval_replenishment_status
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      05-Jan-2021
    --  Purpose:            Evaluates business rules to determine the value of
    --                      the (Stratasys) Replenishment Status.  This status
    --                      (stored in a DFF) extends the standard Kanban Supply Status
    --                      to include intermediate steps that are not refelcted
    --                      in the standard status.  The need for this status was 
    --                      primarily driven by the desire to take full advantage
    --                      of the capabilites of electronic shelf labels (ESLs).
    --                      and the need to more precisely report on the status
    --                      of the custom "two-stage" kanban process used by the
    --                      UME org.  However, it is equally applicable to 
    --                      standard kanban processes as it provides visibility 
    --                      to such information as move order allocation state,
    --                      purchase order approval status (future fuinctionality),
    --                      job status (future functionality), and to-the-bin 
    --                      delivery confirmation via physical buttons on the
    --                      Bossard ESLs available from SES-imagotag.
    --
    --                               
    --  Description:        This is the heart of the process for ESL-enabled kanban.
    --
    --                      Numerous logical branches, using CASE and IF statements,
    --                      are used to model the business rules.  A variable keeps
    --                      track of which rule was actually used, and written to 
    --                      the log file, to aid in troublshooting.
    --
    --                      While the business rules are complex, there is structure.
    --                      Primary logic branches are based upon standard kanban
    --                      Card Status and Supply Status fields.  Additional rules
    --                      are based upon the state of the standard "documents" 
    --                      (move order PO, job, etc) associated with a replenishment
    --                      cycle.  Additional steps related to the two-stage kanban process
    --                      are a significant source of rules also.  While initially
    --                      designed to support a process using button-enabled ESLs,
    --                      this procedure supports ESLs without buttons as well
    --                      as a process that uses no ESLs whatsoever as it can still
    --                      provided valuable reporting data.
    --
    --                      Intra-org kanban is the primary type of kanban used in Stratasys,
    --                      so most of the focus is with this type.  Supplier kanban will
    --                      be supported in the future and other types as the business needs
    --                      arise.
    --
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   05-Jan-2021   Eric Hubert     CHG0048556: initial build
    ----------------------------------------------------------------------------------------------------
    PROCEDURE eval_replenishment_status(
            p_kanban_card_id        IN NUMBER
            ,p_replenishment_status OUT VARCHAR2
            ,p_err_code             OUT NUMBER
            ,p_err_msg              OUT VARCHAR2
        ) IS
    
        c_method_name CONSTANT VARCHAR(30) := 'eval_replenishment_status';
        
        l_cnt_cards_assigned_to_esl_id NUMBER;  --Number of kanban cards to which ESL ID is assigned (should be <= 1)
 
        /* Record variables for ESL extension records. */
        l_esl_registry_row  q_xx_esl_registry_oma_v%ROWTYPE;
        l_sesl_event_row    xxesl_label_events_sesl%ROWTYPE;

        l_label_event VARCHAR2(100);

        /* Kanban/Pull Sequence attributes */
        l_organization_id           NUMBER;
        l_inventory_item_id         NUMBER;
        l_card_status               NUMBER;
        l_supply_status             NUMBER;
        l_source_type               NUMBER;
        l_current_repl_status       mtl_kanban_cards.attribute2%TYPE;
        l_esl_id                    mtl_kanban_cards.attribute3%TYPE;
        l_ps_attribute_category     mtl_kanban_pull_sequences.attribute_category%TYPE;
        l_esl_has_button            BOOLEAN := FALSE;
        l_from_subinventory         mtl_kanban_cards.subinventory_name%TYPE;
        l_to_subinventory           mtl_kanban_cards.source_subinventory%TYPE;
        l_fdt_subinventory          mtl_kanban_pull_sequences.attribute1%TYPE;

        /* Move Order attributes*/
        l_mo_line_status        NUMBER;
        l_quantity_detailed     NUMBER;
        l_quantity_delivered    NUMBER;
        l_mo_print_event_dff    mtl_txn_request_lines.attribute3%TYPE;
        l_status_date           DATE;
        
        /* Item OHQ */
        l_ohq_source_subinventory   NUMBER;
        
        /* transaction dates/times */
        l_fdt_sub_transfer_ts   TIMESTAMP WITH TIME ZONE;
        l_last_button_event_ts  TIMESTAMP WITH TIME ZONE;
        l_eslsvr_db_time_diff   INTERVAL DAY TO SECOND;

        l_matched_rule  VARCHAR2(30) := NULL; --Rule found to be "true" for determining the replenishment status
        l_result        mtl_kanban_pull_sequences.attribute2%TYPE := NULL; --replenishment status

        l_err_code      NUMBER;
        l_err_msg       VARCHAR2(1000);
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('Start of: ' || c_method_name);
        
        BEGIN
            /* For performance, we initially just get the kanban/pull sequence records to evaluate preliminary business rules. 
               It is quick to get these records but other business rules require more extensive data (inventory transactions, kanban activity,
               move orders, etc.) for which their associated queries may be slower to complete.
            */
            SELECT
                 mkc.organization_id
                ,mkc.inventory_item_id
                ,mkc.card_status
                ,mkc.supply_status
                ,mkc.source_type
                ,mkc.subinventory_name
                ,mkc.source_subinventory
                ,mkc.attribute2 --Replenishment status
                ,mkc.attribute3 --ESL ID
                ,NVL(mkps.attribute_category, 'null')--dummy value when null
                ,(
                    CASE WHEN mkps.attribute_category = 'TWO_STAGE_KANBAN' THEN
                        mkps.attribute1 --2-Stage Kanban Destination Subinventory
                    ELSE
                        mkc.subinventory_name --Standard Kanban Destination Subinventory
                    END
                ) --final deliver-to subinventory
            INTO
                l_organization_id
                ,l_inventory_item_iD
                ,l_card_status
                ,l_supply_status
                ,l_source_type
                ,l_to_subinventory
                ,l_from_subinventory
                ,l_current_repl_status
                ,l_esl_id
                ,l_ps_attribute_category
                ,l_fdt_subinventory
            FROM  mtl_kanban_cards mkc
            /* Kanban Card must have a Pull Sequence*/
            INNER JOIN mtl_kanban_pull_sequences mkps ON (
                    mkps.pull_sequence_id = mkc.pull_sequence_id 
                    AND mkps.organization_id = mkc.organization_id
                )
            WHERE kanban_card_id = p_kanban_card_id;

        EXCEPTION WHEN OTHERS THEN
            --write_message('Q1 - SQLERRM: ' || SQLERRM);
            p_err_code := c_fail;
            p_err_msg  := 'Could not find Kanban Card and/or related Pull Sequence';
            l_result   := c_rs_undetermined;
        END;
    
        /* If an ESL is assigned to the kanban card, get information about the ESL. */
        IF l_esl_id IS NOT NULL THEN --kanban card is assigned to an ESL ID

            /* Get the ESL registry row*/
            xxesl_utils_pkg.esl_registry_row(
                p_esl_id       => l_esl_id
                ,p_registry_row => l_esl_registry_row
                ,p_err_code     => l_err_code
                ,p_err_msg      => l_err_msg);

            l_eslsvr_db_time_diff := xxesl_utils_pkg.eslsvr_db_time_diff(p_esl_mfg_code => l_esl_registry_row.xx_esl_manufacturer_code); 

            /* Check if the ESL has buttons.
               Only very specific type of ESL has buttons so we check a hard-coded rule here. */
            IF l_esl_registry_row.xx_esl_manufacturer_code = xxesl_utils_pkg.c_em_sesl
                AND l_esl_registry_row.xx_esl_model_code = '2.2 BWR'
                AND SUBSTR(l_esl_id, 1, 2) = 'A4'  --Per SES-imagotag's Label Type Specifications, there are two groups of 2.2 BWR labels.  One has label IDs that start with A4, and we know that these are the ones with buttons.
                THEN
                l_esl_has_button := TRUE;
                
            END IF;
                
            IF l_esl_has_button THEN
               write_message('l_esl_has_button: TRUE');
                
               /* Get event information from the manufacturer-specific event table. */
                CASE l_esl_registry_row.xx_esl_manufacturer_code WHEN XXESL_UTILS_PKG.c_em_sesl THEN
                    /* Get attributes of the button event */
                    xxesl_utils_pkg.sesl_event_row(
                        p_event_id      => l_esl_registry_row.xx_esl_event_id
                        ,p_event_row    => l_sesl_event_row
                        ,p_err_code     => l_err_code
                        ,p_err_msg      => l_err_msg);

                    l_label_event           := l_sesl_event_row.event_type;
                    l_last_button_event_ts  := l_sesl_event_row.event_timestamp;        

                ELSE
                    
                    l_label_event           := NULL;
                    l_last_button_event_ts  := NULL;  

                END CASE;
                
                /* Replace a null event wih a dummy value to avoid using multiple NVLs later. */
                l_label_event := NVL(l_label_event, -1);
                
            ELSE
                write_message('l_esl_has_button: FALSE');
                l_last_button_event_ts := NULL;
            END IF;

            /* Determine to how many kanban cards the current ESL ID is assigned (should be 1). */
            SELECT COUNT(*)
            INTO l_cnt_cards_assigned_to_esl_id
            FROM mtl_kanban_cards
            WHERE attribute3 = l_esl_id
            GROUP BY l_esl_id;
        END IF;
        
        /* Do some administrative/technical checks */  
        CASE
        WHEN l_cnt_cards_assigned_to_esl_id > 1 THEN
            l_matched_rule := ('Rule# 0.1');
            l_result := c_rs_exc_esl_on_multiple_cards;
            
        WHEN v_kbr_api_status = c_kbr_fail THEN
            l_matched_rule := ('Rule# 0.2');
            l_result := c_rs_exc_replenishment_failed;        
            
        /* Start evaluation of business rules. */
        ELSE
            --write_message('l_card_status: ' || l_card_status);
            l_matched_rule := ('Rule# 1');
            
            /* Check the card status */
            CASE l_card_status
            WHEN c_cs_active THEN
                l_matched_rule := ('Rule# 1.1');
            
                --write_message('l_supply_status: ' || l_supply_status);
                /* Check the supply status */
                CASE l_supply_status
                WHEN c_ss_new THEN
                    l_matched_rule := ('Rule# 1.1.1');
                    l_result := c_rs_new;
                
                WHEN c_ss_wait THEN
                    l_matched_rule := ('Rule# 1.1.3');
                    l_result := c_rs_wait;
                    
                WHEN c_ss_empty THEN
                    l_matched_rule := ('Rule# 1.1.4');
                    l_result := c_rs_empty;

                WHEN c_ss_in_process THEN
                    l_matched_rule := ('Rule# 1.1.5');
                    --write_message('l_source_type: ' || l_source_type);
                    
                    CASE l_source_type
                    WHEN c_st_intra_org THEN
                        l_matched_rule := ('Rule# 1.1.5.1');
                        --write_message('l_inventory_item_id: ' || l_inventory_item_id);
                        --write_message('l_from_subinventory: ' || l_from_subinventory);
                        --write_message('l_to_subinventory: ' || l_to_subinventory);
                        --write_message('l_organization_id: ' || l_organization_id);
                       
                        BEGIN
                            /* We need to get information about the replenishment Move Order in order to evaluate criteria for Intra Org kanban.
                               We could get this from the document id associated with the last replenishment cycle in the kanban activity table, but
                               this is relatively slow to do.
                            */
                            SELECT
                                 line_status
                                ,quantity_detailed --Transacted/Transaction quantity
                                ,quantity_delivered --Can use this because details about individual allocations are not required.  This quantity includes already-transacted allocations (quantity_delivered) and yet-to-be transacted allocations.
                                ,attribute3 --Print Event DFF
                            INTO
                                 l_mo_line_status
                                ,l_quantity_detailed
                                ,l_quantity_delivered
                                ,l_mo_print_event_dff
                            FROM mtl_txn_request_lines
                            WHERE --Use several indexed columns to maximize performance:
                                reference_id                    = p_kanban_card_id --Kanban Card ID
                                AND inventory_item_id           = l_inventory_item_id
                                AND from_subinventory_code      = l_from_subinventory
                                AND to_subinventory_code        = l_to_subinventory
                                AND transaction_type_id         = 64 --Move Order Transfer
                                AND transaction_source_type_id  = 4
                                AND organization_id             = l_organization_id
                            /* It is possible, due to a business process issue, to have multiple open move orders for a single kanban card.
                               We choose to get the newest move order.
                            */
                            ORDER BY line_id DESC
                            FETCH FIRST 1 ROWS ONLY;
                                
                        EXCEPTION WHEN OTHERS THEN
                            --write_message('Q5 - SQLERRM: ' || SQLERRM);
                            l_mo_line_status        := NULL;
                            l_quantity_detailed     := NULL; 
                            l_quantity_delivered    := NULL;
                            l_mo_print_event_dff    := NULL;
                        END;                       
                            
                        --write_message('after query');
                        --write_message('l_mo_line_status: ' || l_mo_line_status);
                        --write_message('l_quantity_detailed: ' || l_quantity_detailed);
                        --write_message('l_quantity_delivered: ' || l_quantity_delivered);
                        --write_message('l_mo_print_event_dff: ' || l_mo_print_event_dff);

                        /* Get OHQ information for source subinventory*/
                        BEGIN
                            SELECT quantity
                            INTO
                                l_ohq_source_subinventory
                            FROM xxesl_kb_ohq_v 
                            WHERE
                                inventory_item_id     = l_inventory_item_id
                                AND organization_id   = l_organization_id
                                AND subinventory_code = l_from_subinventory;

                        EXCEPTION WHEN OTHERS THEN
                            --write_message('Q5 - SQLERRM: ' || SQLERRM);
                            l_ohq_source_subinventory := 0;
                        END;

                        /* Examine details of the move order to determine the status. */
                        CASE
                        /* Move order Pre Approved but not allocated and no stock in source subinventory. */
                        WHEN l_mo_line_status = 7 AND (NVL(l_quantity_detailed, 0) - NVL(l_quantity_delivered, 0)) = 0 AND l_ohq_source_subinventory <= 0 THEN
                            l_matched_rule := ('Rule# 1.1.5.1.1');
                            l_result := c_rs_in_process_no_stock;
                            
                        /* Move order Pre Approved but not allocated */
                        WHEN l_mo_line_status = 7 AND (NVL(l_quantity_detailed, 0) - NVL(l_quantity_delivered, 0)) = 0 THEN
                            l_matched_rule := ('Rule# 1.1.5.1.2');
                            l_result := c_rs_in_process_unallocated;
                        
                        /* Move order order Pre Approved, allocated, but not yet printed */
                        WHEN l_mo_line_status = 7 AND (NVL(l_quantity_detailed, 0) - NVL(l_quantity_delivered, 0)) > 0 AND l_mo_print_event_dff IS NULL THEN
                            l_matched_rule := ('Rule# 1.1.5.1.3');
                            l_result := c_rs_in_process_allocated;
                        
                        /* Move order order Pre Approved, allocated, printed, but not yet picked/transacted */
                        WHEN l_mo_line_status = 7 AND (NVL(l_quantity_detailed, 0) - NVL(l_quantity_delivered, 0)) > 0 AND l_mo_print_event_dff IS NOT NULL THEN
                            l_matched_rule := ('Rule# 1.1.5.1.4');
                            l_result := c_rs_in_process_printed;
                       
                        /* Move order line was manually Closed/Canceled without transacting it. */
                        WHEN l_mo_line_status IN (c_ms_closed, c_ms_canceled) THEN
                            l_matched_rule := ('Rule# 1.1.5.1.5');
                            l_result := c_rs_exc_document_cancelled;   
                                             
                        ELSE
                            l_matched_rule := ('Rule# 1.1.5.1.6');
                            l_result := c_rs_undetermined;
                        END CASE;
                        
                    WHEN c_st_supplier THEN
                        l_matched_rule := ('Rule# 1.1.5.2');
                        l_result := c_rs_undetermined;
                    ELSE
                        l_matched_rule := ('Rule# 1.1.5.3');
                        l_result := c_rs_in_process;
                        
                    END CASE;  --End Source Type for In Process

                WHEN c_ss_full THEN
                    l_matched_rule := ('Rule# 1.1.6');
                    CASE l_source_type
                    WHEN c_st_intra_org THEN
                        --write_message('l_ps_attribute_category: ' || l_ps_attribute_category); 
                        --write_message('l_ps_attribute_category: ' || l_ps_attribute_category);
                        l_matched_rule := ('Rule# 1.1.6.1');

                        CASE
                        /* Standard Kanban; no ESL/ESL without buttons */
                        WHEN l_ps_attribute_category <> c_ac_two_stage_kanban AND NOT l_esl_has_button THEN
                            l_matched_rule := ('Rule# 1.1.6.1.1');

                            l_result := c_rs_full_delivery_assumed;
                    
                        /* Standard Kanban; ESL with buttons */
                        WHEN l_ps_attribute_category <> c_ac_two_stage_kanban AND l_esl_has_button THEN
                            l_matched_rule := ('Rule# 1.1.6.1.2');
                            
                            /* We need the date that the Move Order order was Closed in order to evaluate 
                               certain rules in this section.
                            */
                            utl_kb_mo_closed_date (
                                p_kanban_card_id        => p_kanban_card_id
                                ,p_inventory_item_id    => l_inventory_item_id
                                ,p_from_subinventory    => l_from_subinventory
                                ,p_to_subinventory      => l_to_subinventory
                                ,p_organization_id      => l_organization_id
                                ,p_status_date          => l_status_date
                                ,p_err_code             => l_err_code
                                ,p_err_msg              => l_err_msg
                            );
                            
                            write_message('l_status_date (formatted): ' || to_char(l_status_date, 'DD-MON-YYYY HH24:MI:SS'));
     
                            CASE WHEN l_current_repl_status IN (
                                c_rs_full_delivery_confirmed
                                ,c_rs_full_delivery_assumed
                                ,c_rs_new --Including "NEW" here to facilitate the user manually resetting the replenishment status (this is a more intuitive status to use for "resetting" than the full confirmed/assummed statuses).
                            ) THEN
                                l_matched_rule := ('Rule# 1.1.6.1.2.0');
                                /* Return the current status */
                                l_result := l_current_repl_status;
           
                            --CASE
                            WHEN l_label_event = xxesl_utils_pkg.c_btn_check_mark THEN
                                l_matched_rule := ('Rule# 1.1.6.1.2.1');
                                l_result := c_rs_full_delivery_confirmed;

                            WHEN l_label_event <> xxesl_utils_pkg.c_btn_check_mark
                                AND CURRENT_TIMESTAMP <= l_status_date + NUMTODSINTERVAL(fnd_profile.value('XXESL_KB_DELIVERY_TIMEOUT'), 'HOUR') THEN--Adds the number of hours from the profile option to the move order status timestamp
                                l_matched_rule := ('Rule# 1.1.6.1.2.2');
                                l_result := c_rs_full_pending_delivery;
                            
                            ELSE
                                l_matched_rule := ('Rule# 1.1.6.1.2.3');
                                l_result := c_rs_exc_delivery_timeout;
                            
                            END CASE;

                        /* Two-stage kanban (Intra Org); regardless of buttons */
                        ELSE
                            l_matched_rule := ('Rule# 1.1.6.1.3');
                            /* If already one of the "delivered" statuses, there is no need to evaluate additional rules.
                               Could be a minor issue if we don't run update repl status for this card until
                               the next time the supply status gets to full.  We'd incorrectly report that
                               the delivery was done when we may not have yet done the sub transfer to FDT subinv.
                               We'll live with this for now so that we don't need to run performance-expensive
                               queries below for a situation that is not likely to happen frequently.
                               
                               If this does become an issue in practice, we'll just need to use the "else" branch
                               here, or come up with some clever rule.
                               
                               More important than the minor issue described above is that this rul will also be very 
                               helpful if a user needs to "reset" the ESL display to help recover from a process exception.

                            */
                            IF l_current_repl_status IN (
                                c_rs_full_delivery_confirmed
                                ,c_rs_full_delivery_assumed
                                ,c_rs_new --Including "NEW" here to facilitate the user manually resetting the replenishment status (this is a more intuitive status to use for "resetting" than the full confirmed/assummed statuses).
                            ) THEN
                                l_matched_rule := ('Rule# 1.1.6.1.3.1');
                                /* Return the current status */
                                l_result := l_current_repl_status;
                                
                            ELSE
                                l_matched_rule := ('Rule# 1.1.6.1.3.2');

                                /* We need the date that the Move Order order was Closed in order to evaluate 
                                   certain rules in this section.
                                */
                                utl_kb_mo_closed_date (
                                    p_kanban_card_id        => p_kanban_card_id
                                    ,p_inventory_item_id    => l_inventory_item_id
                                    ,p_from_subinventory    => l_from_subinventory
                                    ,p_to_subinventory      => l_to_subinventory
                                    ,p_organization_id      => l_organization_id
                                    ,p_status_date          => l_status_date
                                    ,p_err_code             => l_err_code
                                    ,p_err_msg              => l_err_msg
                                );
                                
                                write_message('l_status_date (formatted): ' || to_char(l_status_date, 'DD-MON-YYYY HH24:MI:SS'));
                                
                                BEGIN
                                    /* Check if a subinventory transfer occurred after the move order was transacted (closed),
                                       for the kanban item, from the "in transit" subinventory (the "To" subinventory for the
                                       kanban, and to the final destination subinventory.
                                       
                                       Use of creation_date vs transaction_date:
                                           While MSCA subinventory transfers are unlikely to have this issue, an occasional problem could occur using forms.
                                           Use Creation Date instead of transaction_date since the latter is static per the value of the Date field on the 
                                           header portion of the subinventory transfer form.  If the user leaves this from open it could report a 
                                           transaaction date that occurs prior to the confirm button being pressed.
                                    */
                                    SELECT
                                        --transaction_date
                                        --creation_date
                                        FROM_TZ(CAST (creation_date AS TIMESTAMP), xxesl_utils_pkg.ebssvr_tz_offset)
                                    INTO l_fdt_sub_transfer_ts
                                    FROM xxesl_kb_twostage_subtfr_v
                                    WHERE 1=1
                                        AND organization_id         =  l_organization_id
                                        AND inventory_item_id       =  l_inventory_item_id
                                        AND subinventory_code       =  l_to_subinventory
                                        AND transfer_subinventory   =  l_fdt_subinventory
                                        AND creation_date           >= l_status_date
                                    ORDER BY transaction_date DESC
                                    FETCH FIRST 1 ROWS ONLY;

                                EXCEPTION WHEN OTHERS THEN
                                    --write_message('Q4 - SQLERRM: ' || SQLERRM);
                                    l_fdt_sub_transfer_ts := NULL; 
                                END;
                                
                                write_message('Key Times in eval_replenishment_status:');
                                write_message('  l_label_event: ' || l_label_event);
                                write_message('  l_fdt_sub_transfer_ts: ' || l_fdt_sub_transfer_ts);
                                write_message('  l_last_button_event_ts: ' || l_last_button_event_ts);
                                write_message('  l_eslsvr_db_time_diff: ' || l_eslsvr_db_time_diff);
                                                            
                                CASE 
                                /* Two-Stage Kanban; ESL with buttons */
                                WHEN l_ps_attribute_category =  c_ac_two_stage_kanban AND l_esl_has_button THEN

                                    l_matched_rule := ('Rule# 1.1.6.1.3.2.1');

                                    CASE
                                    /*  Affirmative confirmation of delivery by pressing the button after the subinventory transfer was performed.  
                                    
                                        Design Note: it is possible that the subinventory transfer will occur (via MSCA) immediately before
                                            the "confirm" button is pushed.  Because of this, the button would be pushed while the replenishment status is "FULL_IN_TRANSIT"
                                            as opposed to "FULL_PENDING_DELIVERY".  Therefore, we will consider the kanban delivered when the confirm button is pushed so long
                                            as the "two stage" subinventory transfer has been performed.  That is, there is no requirement for the repl status to be pending
                                            delivery in order for the confirm button to complete the replenishment process.

                                        Commentary on the date subtraction in the condition below:
                                           Even though the confirm button was pushed, we need to do one last check to see if it was pushed
                                           AFTER the subinventory transfer was performed.  (If it was done before, the label event will be cleared
                                           and the status will be full pending delivery until the button is pressed, again).  Note that we are
                                           comparing the time of the button event as reported by the ESL server (not when it was imported into Oracle)
                                           so that we can make an accurate calculation on the time difference.  We have also implemented 
                                           an "ESL Server-Database Time Difference" function to account for the possibility that the ESL server time 
                                           being different will be different than the database time.  There is time delay, of inconsistent length,
                                           between when the physical button is pushed and when the ESL server recognizes this event.  Because of this 
                                           the event will appear (to the ESL server and to Oracle) somewhat later than when the phyical button push
                                           occurred, having the effect of allowing some "grace period" to perform the subinventory transfer should
                                           the material handler happen to first push the button.
                                    */
                                    WHEN l_fdt_sub_transfer_ts IS NOT NULL
                                        AND l_label_event = xxesl_utils_pkg.c_btn_check_mark
                                        AND (l_last_button_event_ts >= l_fdt_sub_transfer_ts + l_eslsvr_db_time_diff) THEN--see commentary above
                                          
                                        l_matched_rule := ('Rule# 1.1.6.1.3.2.1.1');
                                        l_result := c_rs_full_delivery_confirmed;

                                    /* User prematurely pressed confirm button before performing the subinventory transfer.
                                       See commentary above for a detailed explanation.
                                    */
                                    WHEN l_fdt_sub_transfer_ts IS NOT NULL
                                        AND l_label_event = xxesl_utils_pkg.c_btn_check_mark
                                        AND NOT (l_last_button_event_ts >= l_fdt_sub_transfer_ts + l_eslsvr_db_time_diff) THEN
                                          
                                        l_matched_rule := ('Rule# 1.1.6.1.3.2.1.2');
                                        l_result := c_rs_full_pending_delivery;

                                    /* Subinventory transfer performed, still awaiting physical delivery to bin, and within the "timeout" period 
                                       allowed after the subinventory transfer to do the button confirm. */
                                    WHEN  l_fdt_sub_transfer_ts IS NOT NULL
                                        AND l_label_event <> xxesl_utils_pkg.c_btn_check_mark
                                        AND CURRENT_TIMESTAMP <= l_fdt_sub_transfer_ts + NUMTODSINTERVAL(fnd_profile.value('XXESL_KB_DELIVERY_TIMEOUT'), 'HOUR') THEN--Adds the number of hours from the profile option to the subinventory transfer timestamp
                                        
                                        l_matched_rule := ('Rule# 1.1.6.1.3.2.1.3');
                                        l_result := c_rs_full_pending_delivery;

                                    /* Physical delivery to bin has not occurred (confirm button has not beeen pushed) within the "timeout" period
                                       allowed after the subinventory transfer. */
                                    WHEN  l_fdt_sub_transfer_ts IS NOT NULL
                                        AND l_label_event <> xxesl_utils_pkg.c_btn_check_mark
                                        AND CURRENT_TIMESTAMP > l_fdt_sub_transfer_ts + NUMTODSINTERVAL(fnd_profile.value('XXESL_KB_DELIVERY_TIMEOUT'), 'HOUR') THEN--Adds the number of hours from the profile option to the subinventory transfer timestamp
                                        
                                        l_matched_rule := ('Rule# 1.1.6.1.3.2.1.4');
                                        l_result := c_rs_exc_delivery_timeout;
                                
                                    /* Waiting for subinventory transfer from in transit subinventory to final destination subinventory*/
                                    ELSE
                                        l_matched_rule := ('Rule# 1.1.6.1.3.2.1.5');
                                        l_result := c_rs_full_in_transit;

                                    END CASE;
                                
                                /* Two-Stage Kanban; no ESL, or, ESL without buttons */
                                WHEN l_ps_attribute_category =  c_ac_two_stage_kanban AND NOT l_esl_has_button THEN
                                    l_matched_rule := ('Rule# 1.1.6.1.3.2.2');
                                    /* Physical delivery to bin is automatically assumed completed immediately after the subinventory transfer (since we have no ESL button to confirm delivery). */
                                    IF  l_fdt_sub_transfer_ts IS NOT NULL THEN
                                        l_matched_rule := ('Rule# 1.1.6.1.3.2.2.1');
                                        l_result := c_rs_full_delivery_assumed;
                                    
                                    /* Waiting for subinventory transfer from in transit subinventory to final destination subinventory*/
                                    ELSE
                                        l_matched_rule := ('Rule# 1.1.6.1.3.2.2.2');
                                        l_result := c_rs_full_in_transit;
                                    END IF;
                                   
                                ELSE  --Other
                                    l_matched_rule := ('Rule# 1.1.6.1.3.2.3');
                                    l_result := c_rs_undetermined;
                                END CASE;           
                            END IF;
                        END CASE;  --End detailed rules for Intra Org 
                    WHEN c_st_supplier THEN
                        l_matched_rule := ('Rule# 1.1.6.2');
                        l_result := c_rs_full;
                    ELSE
                        l_matched_rule := ('Rule# 1.1.6.3');
                        l_result := c_rs_full;
                    END CASE;--End Source Type for Full
           
                WHEN c_ss_in_transit THEN
                    l_matched_rule := ('Rule# 1.1.7');
                    l_result := c_rs_in_transit;
                    
                WHEN c_ss_in_exception THEN
                    l_matched_rule := ('Rule# 1.1.8');
                    l_result := c_rs_exc;
                    
                ELSE
                    l_matched_rule := ('Rule# 1.1.9');
                    l_result := c_rs_undetermined;
                    
                END CASE; --End Supply Status
                
            WHEN c_cs_hold THEN
                l_matched_rule := ('Rule# 1.2');
                l_result := c_rs_hold;
                
            WHEN c_cs_cancelled THEN
                l_matched_rule := ('Rule# 1.3');
                l_result := c_rs_cancelled;
                
            ELSE
                l_matched_rule := ('Rule# 1.4');
                l_result := c_rs_undetermined;
            END CASE;  -- End Card Status
        END CASE;
        
        --write_message('l_matched_rule: ' || l_matched_rule);
        
        p_err_code              := c_success;
        p_err_msg               := l_matched_rule;
        p_replenishment_status  := l_result;
        --write_message('p_replenishment_status: ' || p_replenishment_status);

        EXCEPTION WHEN OTHERS THEN
            p_err_code := c_fail;
            p_err_msg  := c_method_name || ': ' || SQLERRM;
            p_replenishment_status := c_rs_undetermined;
    END eval_replenishment_status;

    ----------------------------------------------------------------------------------------------------
    --  Name:               update_esl_display_main
    --  Created By:         Hubert, Eric
    --  Revision:           1.0
    --  Creation Date:      05-Jan-2021
    --  Purpose:            Main procedure to update the ESL Kanban displays
    --                               
    --  Description:        Calls the replenishment manager, generates XML, and
    --                      sends the XML to the ESL server.
    --
    ----------------------------------------------------------------------------------------------------
    --  Ver   Date          Name            Desc
    --  1.0   05-Jan-2021   Eric Hubert     CHG0048556: initial build
    ----------------------------------------------------------------------------------------------------
    /* Handles pushing display content to ESLs. */
    PROCEDURE update_esl_display_main (
        errbuf                      OUT VARCHAR2,
        retcode                     OUT NUMBER,
        p_org_id                    IN NUMBER,   --Organization in which kanban card is defined
        p_kanban_card_id            IN NUMBER,   --optional way to target a specific kanban card
        p_pull_sequence_id          IN NUMBER,   --optional way to target a specific pull sequence
        p_esl_id                    IN VARCHAR2, --optional way to target a specific ESL label
        p_source_subinv             IN VARCHAR2, --Kanban Source Subinventory
        p_fdt_subinv                IN VARCHAR2, --Kanban Final Deliver-To Subinventory (Destination Subinventory unless Final Destination Subinventory on Pull Sequence is specified)
        p_esl_mfg_code              IN fnd_flex_values.flex_value%TYPE, --
        p_esl_model_code            IN VARCHAR2,
        p_pending_events_only       IN VARCHAR2, --Only update ESLs that have pending events
        p_run_esl_repl_mgr          IN VARCHAR2, --Run the ESL Replenishment Manager before generating XML
        p_send_to_esl_server        IN VARCHAR2  --Send the XML created by the concurrent request to the ESL Server (first integration is with SES-imagotag's on premesis "Core Service").  Use No for debugging.
    )
    IS
        c_method_name CONSTANT VARCHAR(30) := 'update_esl_display_main';
        
        /* Other Local Variables */
        l_resource_name VARCHAR2(50);
        l_tasks_xml     XMLTYPE;
        l_err_msg       VARCHAR2(1000);
        l_err_code      NUMBER;
        
        EXC_REPLENISHMENT_MGR_FAILED    EXCEPTION;
        EXC_XML_GENERATION_ERROR        EXCEPTION;
        EXC_NULL_XML                    EXCEPTION;
        EXC_CREATE_RESOURCE_FAILED      EXCEPTION;
        
    BEGIN
        gv_log_program_unit := c_method_name; --store procedure name for logging
        write_message('program unit: ' || gv_log_program_unit);
        
        /* Write request paramaters log: */
        write_message('p_org_id: '                  || p_org_id);
        write_message('p_kanban_card_id: '          || p_kanban_card_id);
        write_message('p_pull_sequence_id: '        || p_pull_sequence_id);
        write_message('p_esl_id: '                  || p_esl_id);
        write_message('p_source_subinv: '           || p_source_subinv);
        write_message('p_fdt_subinv: '              || p_fdt_subinv);
        write_message('p_esl_mfg_code: '            || p_esl_mfg_code);
        write_message('p_esl_model_code: '          || p_esl_model_code);
        write_message('p_pending_events_only: '     || p_pending_events_only);
        write_message('p_run_esl_repl_mgr: '        || p_run_esl_repl_mgr);
        write_message('p_send_to_esl_server: '      || p_send_to_esl_server);

        /* Conditionally run the replenishment manager (will typically do so). */
        IF p_run_esl_repl_mgr = 'Y' THEN
            esl_replenishment_manager(
                p_org_id                => p_org_id
                ,p_esl_kb_cards_only    => 'Y'
                ,p_pending_events_only  => p_pending_events_only
                ,p_kanban_card_id       => p_kanban_card_id
                ,p_pull_sequence_id     => p_pull_sequence_id
                ,p_err_code             => l_err_code
                ,p_err_msg              => l_err_msg
            );
        END IF;
        
        /* Generate XML for kanban cards. */
        IF l_err_code = c_success THEN
        
            generate_esl_kb_card_xml(
                p_org_id                    => p_org_id,
                p_kanban_card_id            => p_kanban_card_id,
                p_pull_sequence_id          => p_pull_sequence_id,
                p_esl_id                    => p_esl_id,
                p_source_subinv             => p_source_subinv,
                p_fdt_subinv                => p_fdt_subinv,
                p_esl_mfg_code              => p_esl_mfg_code,   
                p_esl_model_code            => p_esl_model_code,
                p_cards_with_events_only    => p_pending_events_only,
                p_tasks_xml                 => l_tasks_xml,
                p_err_code                  => l_err_code,
                p_err_msg                   => l_err_msg
            );
            
        ELSE
            RAISE EXC_REPLENISHMENT_MGR_FAILED;
        END IF;
        
        --write_message('l_err_msg (generate_esl_kb_card_xml): ' || l_err_msg);
    
        /* Send XML to the ESL server. */
        CASE
        WHEN    l_err_code = c_success AND l_tasks_xml IS NULL THEN
            RAISE EXC_NULL_XML;  --This will happen periodically if we're lloking just for labels with events
        WHEN  l_err_code = c_success THEN
            --write_message(l_tasks_xml.getstringval());
            
            IF p_send_to_esl_server = c_yes THEN
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
                    ,p_payload_xml    => l_tasks_xml
                    ,p_err_code       => l_err_code
                    ,p_err_msg        => l_err_msg
                );
                IF l_err_code <> c_success THEN
                    RAISE EXC_CREATE_RESOURCE_FAILED;
                END IF;
            END IF;
        
        ELSE
            RAISE EXC_XML_GENERATION_ERROR;     
        END CASE;
        
        retcode := c_retcode_s;
        errbuf  := 'Completed successfully';
            
    EXCEPTION
        WHEN EXC_REPLENISHMENT_MGR_FAILED THEN 
            retcode  := c_retcode_sw;
            errbuf   := c_method_name || ': esl_replenishment_manager failed.';
            write_message (errbuf);
        WHEN EXC_NULL_XML THEN
            retcode  := c_retcode_s;
            errbuf   := c_method_name || ': XML is null.';
            write_message (errbuf);
        WHEN EXC_XML_GENERATION_ERROR THEN 
            retcode  := c_retcode_sw;
            errbuf   := c_method_name || ': generate_esl_kb_card_xml failed.';
            write_message (errbuf);
        WHEN EXC_CREATE_RESOURCE_FAILED THEN 
            retcode  := c_retcode_sw;
            errbuf   := c_method_name || ': eslsvr_create_resource failed.';
            write_message (errbuf);
        WHEN OTHERS THEN
            retcode := c_retcode_e;
            errbuf  := c_method_name || ': ' || SQLERRM;
            write_message('errbuf: ' || errbuf);
    END update_esl_display_main;

--------------------------------------------------------------------------------
/* Public Procedures - End */
--------------------------------------------------------------------------------
END xxesl_kanban_card_utils_pkg;
/