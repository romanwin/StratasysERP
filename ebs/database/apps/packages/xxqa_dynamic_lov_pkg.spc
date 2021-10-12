----------------------------------------------------------------------------
--  Name:              xxqa_dynamic_lov_pkg
--  Created by:        Hubert, Eric
--  Revision:          1.0
--  Creation Date:     25-JAN-2019
--  Change Request:    CHG0042589
--  Description:       Enhances standard Oracle Quality functionality pertaining 
--                     to defining SQL Validation Statements for a Collection
--                     Element.  This package allows for user-entered element values
--                     on the Enter/Update Quality Results from to be referenced
--                     in the SQL, thus providing a "Dynamic List of Values".
--
--  Ver   Date          Name            Desc
--  1.0   25-Jan-2019   Hubert, Eric    CHG0042589: Initial Build
----------------------------------------------------------------------------
CREATE OR REPLACE PACKAGE apps.xxqa_dynamic_lov_pkg IS
    /* Global variables for storing ID values to identify a specific quality result record.*/
    gv_collection_id NUMBER;  --Group of records within qa_results, created at the same time.
    gv_plan_id NUMBER;        --ID of Quality Collection Plan
    gv_occurrence NUMBER;     --Uniquely identifies a result record within qa_results
    
    /* Global Variable declaration for Logging unit*/
    gv_log              VARCHAR2(1) := fnd_profile.value('AFLOG_ENABLED');  --FND: Debug Log Enabled
    gv_log_module       VARCHAR2(100) := fnd_profile.value('AFLOG_MODULE'); --FND: Debug Log Module
    gv_api_name         VARCHAR2(30) := 'xxqa_dynamic_lov_pkg';
    gv_log_program_unit VARCHAR2(100);
    

    FUNCTION write_element_value (
        p_char_name VARCHAR2,
        p_element_value IN VARCHAR2
        )
    RETURN NUMBER;
    
    FUNCTION read_element_value(
        p_char_name IN VARCHAR2
    ) RETURN VARCHAR2;

    FUNCTION write_result_element_values RETURN NUMBER;
    
    FUNCTION foreign_table_value(
        p_char_name IN VARCHAR2
        , p_pk1_value IN VARCHAR2
        , p_pk2_value IN VARCHAR2 DEFAULT NULL
        , p_pk3_value IN VARCHAR2 DEFAULT NULL
        ) RETURN VARCHAR2;
    
    PROCEDURE clear_temp_table;

END xxqa_dynamic_lov_pkg;
/
