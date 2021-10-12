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

CREATE OR REPLACE PACKAGE apps.xxesl_kanban_card_utils_pkg AS
    /* Global Variable declaration for Logging unit (CHG0048556) */
    gv_log              VARCHAR2(1)     := fnd_profile.value('AFLOG_ENABLED');  --FND: Debug Log Enabled (default="N")
    gv_log_module       VARCHAR2(100)   := fnd_profile.value('AFLOG_MODULE'); --FND: Debug Log Module (default="%")
    gv_api_name         VARCHAR2(30)    := 'xxesl_kanban_card_utils_pkg';
    gv_log_program_unit VARCHAR2(100);

    /* Debug Constants*/
    c_log_method                    NUMBER := 1;  --0: no logging, 1: fnd_file.log, 2: fnd_log_messages, 3: dbms_output  (CHG0048556)

    c_yes CONSTANT VARCHAR2(1) := 'Y';
    c_no  CONSTANT VARCHAR2(1) := 'N';

    /* CHG0048556 */
    FUNCTION update_esl_display_fp (
         p_organization_id      IN NUMBER
         ,p_kanban_card_id      IN NUMBER  --Either Kanban Card ID or pull sequence id need to be specified.
         ,p_pull_sequence_id    IN NUMBER
    ) RETURN NUMBER; --Return Concurrent Request ID

    /* CHG0048556 */
    PROCEDURE esl_replenishment_manager(
        p_org_id                IN  NUMBER
        ,p_esl_kb_cards_only    IN  VARCHAR2 DEFAULT 'Y' --Y: only update cards that have an ESL ID assigned
        ,p_pending_events_only  IN  VARCHAR2 DEFAULT 'N' --Y: only update cards for which there is an unprocessed label event (i.e. a button was pushed on the ESL).
        ,p_kanban_card_id       IN  NUMBER               --Only update this specific kanban card
        ,p_pull_sequence_id     IN  NUMBER
        ,p_err_code             OUT NUMBER
        ,p_err_msg              OUT VARCHAR2
    );

    /* CHG0048556 */      
    PROCEDURE eval_replenishment_status(
        p_kanban_card_id        IN NUMBER
        ,p_replenishment_status OUT VARCHAR2
        ,p_err_code             OUT NUMBER
        ,p_err_msg              OUT VARCHAR2
    );

    /* CHG0048556 */
    PROCEDURE update_esl_display_main (
        errbuf                      OUT VARCHAR2,
        retcode                     OUT NUMBER,
        p_org_id                    IN NUMBER,   --Organization in which kanban card is defined
        p_kanban_card_id            IN NUMBER, --optional way to target a specific kanban card
        p_pull_sequence_id          IN NUMBER,   --optional way to target a specific pull sequence
        p_esl_id                    IN VARCHAR2, --optional way to target a specific ESL label
        p_source_subinv             IN VARCHAR2, --Kanban Source Subinventory
        p_fdt_subinv                IN VARCHAR2, --Kanban Final Deliver-To Subinventory (Destination Subinventory unless Final Destination Subinventory on Pull Sequence is specified)
        p_esl_mfg_code              IN fnd_flex_values.flex_value%TYPE, --
        p_esl_model_code            IN VARCHAR2,
        p_pending_events_only       IN VARCHAR2, --Only update ESLs that have pending events
        p_run_esl_repl_mgr          IN VARCHAR2, --Run the ESL Replenishment Manager before generating XML
        p_send_to_esl_server    IN VARCHAR2  --Send the XML created by the concurrent request to the ESL Server (first integration is with SES-imagotag's on premesis "Core Service").  Use No for debugging.
    );

END xxesl_kanban_card_utils_pkg;
/
