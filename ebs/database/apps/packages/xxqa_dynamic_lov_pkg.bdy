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
CREATE OR REPLACE PACKAGE BODY apps.xxqa_dynamic_lov_pkg IS
    ----------------------------------------------------------------------------
    --  Name:              write_log
    --  Created by:        Hubert, Eric
    --  Revision:          1.0
    --  Creation Date:     21-OCT-2019
    --  Change Request:    CHG0042589
    --  Description:       Modeled after xxssys_event_pkg.write_log for writing
    --                     debug messages to FND_LOG_MESSAGES.
    --  Ver   Date          Name            Desc
    --  1.0   25-Jan-2019   Hubert, Eric    CHG0042589: Initial Build
    ----------------------------------------------------------------------------
    PROCEDURE write_log(p_msg VARCHAR2) IS
        l_dlov_key_values VARCHAR2(200); --Holds global variables that identify the result record.
        BEGIN
            
            /* The context provided by the values of these global variables will be important for trouble-shooting. */
            l_dlov_key_values := ' [gv_collection_id = ' || gv_collection_id || '; gv_plan_id = ' ||gv_plan_id || '; gv_occurrence = ' ||gv_occurrence || ']';

            IF gv_log = 'Y' AND gv_api_name || gv_log_program_unit LIKE lower(gv_log_module) THEN          
                fnd_log.string(
                    log_level => fnd_log.level_unexpected,
                    module    => gv_api_name || gv_log_program_unit,
                    message   => p_msg || l_dlov_key_values);

            END IF;

    END write_log;  


    ----------------------------------------------------------------------------
    --  Name:              write_element_value
    --  Created by:        Hubert, Eric
    --  Revision:          1.0
    --  Creation Date:     25-Jan-2019
    --  Change Request:    CHG0042589
    --  Description:       Write the value of a single collection plan result element to a temporary table.
    --                     The value may be queried at a later time during the same session by 
    --                     the SQL Validation Statement of a second element.  This in turn facilitates
    --                     a dynamic list of values without requiring the use of from variables
    --                     on the Enter and Update Quality Results forms.
    --
    --  Ver   Date          Name            Desc
    --  1.0   25-Jan-2019   Hubert, Eric    CHG0042589: Initial Build
    ----------------------------------------------------------------------------
    FUNCTION write_element_value(
        p_char_name VARCHAR2,
        p_element_value IN VARCHAR2
        )
    RETURN NUMBER IS
    PRAGMA AUTONOMOUS_TRANSACTION  --We need to be able to run a DML action from a Select statement in a Quality Action.  This clause allows DML in a function.
    ;
        l_id NUMBER;  --Return value (id column of temp table)
    BEGIN
        gv_log_program_unit := 'write_element_value'; --store procedure name for logging
        write_log('gv_log_program_unit: ' || gv_log_program_unit);
        write_log('FND_PROFILE.VALUE(''MFG_ORGANIZATION_ID'') = ' || FND_PROFILE.VALUE('MFG_ORGANIZATION_ID'));
        write_log('p_char_name = ' || p_char_name || '; p_element_value = ' || p_element_value);
        
        /* Frist try to update an existing record.  If it fails, then we'll insert it. */
        MERGE INTO XXQA_ELEMENT_VALUES_TEMP xevt
            USING (SELECT
                    gv_collection_id AS collection_id
                    ,gv_plan_id AS plan_id
                    ,gv_occurrence AS occurrence
                    ,p_char_name AS char_name
                    ,p_element_value AS element_value
                    FROM dual) d
            ON (xevt.occurrence = d.occurrence AND xevt.plan_id = d.plan_id AND xevt.char_name = d.char_name)
            
        /* If the occurrence-element record already exists then update it.*/
        WHEN MATCHED THEN
            UPDATE SET
                xevt.element_value = d.element_value
                ,xevt.last_update_date = SYSDATE
            WHERE (xevt.occurrence = d.occurrence AND xevt.plan_id = d.plan_id AND xevt.char_name = d.char_name)
        
        /* If the occurrence-element record already exists then insert it.*/
        WHEN NOT MATCHED THEN 
            INSERT (
                xevt.collection_id
                ,xevt.plan_id
                ,xevt.occurrence
                ,xevt.char_name
                ,xevt.element_value)
            VALUES (
                d.collection_id
                ,d.plan_id
                ,d.occurrence
                ,d.char_name
                ,d.element_value);

        COMMIT;

        /* Get the ID and return it*/
        SELECT id
        INTO l_id
        FROM XXQA_ELEMENT_VALUES_TEMP xevt 
        WHERE 
            xevt.occurrence = gv_occurrence
            AND xevt.plan_id = gv_plan_id
            AND xevt.char_name = p_char_name;

        RETURN l_id;
    EXCEPTION WHEN OTHERS THEN
        write_log('SQLERRM = ' || SQLERRM );
        
        RETURN -1;
    END write_element_value;

    ----------------------------------------------------------------------------
    --  Name:              read_element_value
    --  Created by:        Hubert, Eric
    --  Revision:          1.0
    --  Creation Date:     25-Jan-2019
    --  Change Request:    CHG0042589
    --  Description:       Read the value of a single collection plan result element from the temporary table.
    --                     Only the element name must be specified since global variables store references
    --                     to the record.
    --
    --  Ver   Date          Name            Desc
    --  1.0   25-Jan-2019   Hubert, Eric    CHG0042589: Initial Build
    ----------------------------------------------------------------------------
    FUNCTION read_element_value(
        p_char_name IN VARCHAR2
        ) RETURN VARCHAR2
    IS
        l_result VARCHAR2(150);  --150 characters is the size of the CHARACTERxx columns in qa_results.
    BEGIN
        gv_log_program_unit := 'read_element_value'; --store procedure name for logging
        write_log('gv_log_program_unit: ' || gv_log_program_unit);
        
        write_log('p_char_name = ' || p_char_name );
        
        SELECT element_value
        INTO l_result
        FROM XXQA_ELEMENT_VALUES_TEMP xevt 
        WHERE 
            xevt.occurrence = gv_occurrence
            AND xevt.plan_id = gv_plan_id
            AND xevt.char_name = p_char_name;
        
        write_log('l_result = ' || l_result );
        
        RETURN l_result;
                
    EXCEPTION WHEN OTHERS THEN
        write_log('SQLERRM = ' || SQLERRM );
        RETURN NULL;
    END read_element_value;
 
    ----------------------------------------------------------------------------
    --  Name:              write_all_element_values (PRIVATE)
    --  Created by:        Hubert, Eric
    --  Revision:          1.0
    --  Creation Date:     25-Jan-2019
    --  Change Request:    CHG0042589
    --  Description:       For a specified quality result record, via its plan id and occurrence, 
    --                     create rows in the temp table, XXQA_ELEMENT_VALUES_TEMP.  One row
    --                     will be created for each element defined for the plan
    --                     as long as the value is not null.  The purpose of this is
    --                     to pre-populate values for use with dynamic LOVs when editing
    --                     records on the Update Quality Results form.    
    --
    --                     Only Character, Number, Date, Sequence, and Date and Time
    --                     element types are supported at this time.  I.e. Comments are not supported
    --                     due to their potentially large size and there is no business requirement for them.
    --
    --  Ver   Date          Name            Desc
    --  1.0   25-Jan-2019   Hubert, Eric    CHG0042589: Initial Build
    ----------------------------------------------------------------------------   
    PROCEDURE write_all_element_values (
        p_plan_id       IN NUMBER
        ,p_occurrence   IN NUMBER
        ,p_rows         OUT NUMBER
        )
    IS
        /* Cursors */
        CURSOR cur_plan_elements IS
            SELECT
                qpc.plan_id
                ,qpc.prompt_sequence
                ,qpc.result_column_name
                ,qc.name
                ,qp.organization_id
                ,dtc.data_type 
            FROM qa_plan_chars qpc
            
            /* Join to get attributes of the collection element. */
            INNER JOIN qa_chars qc ON (qc.char_id = qpc.char_id)

            /* Join to get attributes of the plan. */
            INNER JOIN qa_plans qp ON (qp.plan_id = qpc.plan_id)
            
            /* Join to get attributes of the result column. */
            INNER JOIN dba_tab_columns dtc ON (
                qpc.result_column_name = dtc.column_name
                AND dtc.table_name = 'QA_RESULTS' 
                AND dtc.owner = 'QA') 
            WHERE
                qc.enabled_flag = 1
                AND qpc.enabled_flag = 1
                AND qpc.plan_id = p_plan_id
                AND qc.datatype <> 4 --Comments
            ORDER BY prompt_sequence;

        TYPE element_value_type IS RECORD (
            col_name        VARCHAR2(150)
            ,col_value      VARCHAR2(150)
            ,pk_id          VARCHAR2(30)
            ,pk_id2         VARCHAR2(30)
            ,pk_id3         VARCHAR2(30)
            );
            
        /* Local variables */
        l_cpe                       cur_plan_elements%ROWTYPE; --Result Row
        l_element_value_type_rec    element_value_type;
        l_element_value_cur         SYS_REFCURSOR;
        l_element_value             VARCHAR2(150);
        
        l_pk2_value                 VARCHAR2(150) := NULL;
        l_pk3_value                 VARCHAR2(150) := NULL;

        /* Local variables for dynamic SQL*/
        l_dynamic_column_list       VARCHAR2(10000);
        l_dynamic_value_list        VARCHAR2(10000);
        l_dynamic_sql               VARCHAR2(32000);  --Holds dynamic SQL statement
        l_temp_table_id             NUMBER;
        l_row_count1                NUMBER := 0;
        l_row_count2                NUMBER := 0;

    BEGIN
        gv_log_program_unit := 'write_all_element_values'; --store procedure name for logging
        write_log('gv_log_program_unit: ' || gv_log_program_unit);

        /* Get list of element names. */
        OPEN cur_plan_elements;
        LOOP
            FETCH cur_plan_elements INTO l_cpe;
            EXIT WHEN cur_plan_elements%NOTFOUND;
            l_row_count1 := l_row_count1 + 1;
            
            /* If this is not the first time through the loop then append a comma to the column and value lists. */
            IF l_row_count1 > 1 THEN
               l_dynamic_column_list := l_dynamic_column_list || ', ';
               l_dynamic_value_list := l_dynamic_value_list || ', ';
            END IF;
            
            l_dynamic_column_list := l_dynamic_column_list || l_cpe.result_column_name; --Append the current column to the list
            
            /* Append the current column's value to the list. 
               For the UNPIVOT that we use later, it needs to have columns all of the same data 
               type so we conditionally convert non-character columns to character. */
            CASE WHEN l_cpe.data_type = 'VARCHAR2' THEN
                l_dynamic_value_list := l_dynamic_value_list || l_cpe.result_column_name;
            WHEN l_cpe.data_type = 'DATE' THEN
                l_dynamic_value_list := l_dynamic_value_list || 'TO_CHAR(' || l_cpe.result_column_name || ') ' || l_cpe.result_column_name;
            ELSE --NUMBER
                l_dynamic_value_list := l_dynamic_value_list || 'TO_CHAR(' || l_cpe.result_column_name || ') ' || l_cpe.result_column_name;
            END CASE;
        END LOOP;
        
        CLOSE cur_plan_elements;
        
        /* Build a dynamic SQL Statement.  We are querying directly against qa_results and not the collection plan's result view since the latter has a significant performance penalty.
		   Note the use of the alternative quoting mechanism (Q') using "[" as the quote_delimiter.  This is to make the use of any single quotes in the variable clearer.
		*/        
        l_dynamic_sql:= Q'[SELECT
            qpcv.char_name
            ,x.element_value
            ,qc.pk_id
            ,qc.pk_id2
            ,qc.pk_id3
        FROM (
            SELECT ]' || l_dynamic_value_list || Q'[
            FROM qa_results
            WHERE plan_id = ]' || p_plan_id || Q'[
                AND occurrence = ]' || p_occurrence || Q'[
            )
        UNPIVOT(element_value FOR result_column_name IN (]' || l_dynamic_column_list || Q'[)) x  --Make every selected column from qa_results its own row.
        INNER JOIN qa_plan_chars_v qpcv ON (qpcv.result_column_name = x.result_column_name AND qpcv.plan_id = ]' || p_plan_id || Q'[)
        INNER JOIN qa_chars qc ON (qc.char_id = qpcv.char_id)]';
        
        /* Open a cursor based on the dynamic sql. */
        OPEN l_element_value_cur FOR l_dynamic_sql;        
        
        LOOP
            FETCH l_element_value_cur INTO l_element_value_type_rec;
        
            EXIT WHEN l_element_value_cur%NOTFOUND;
            l_row_count2 := l_row_count2 + 1;
            
            /* Look up the current element to see if its value needs to be "translated" to a value stored in foreign table.
               
               We make some practical assumptions to simplify the code:
               1) pk_id3 is not currenlty specified for any row in qa_chars, so we don't put much effort into translating a value for it.
               2) If pk_id2 is not null, it's value will almost always be "ORGANIZATION_ID".  See #3.
               3) Ignore when pk_id2 is "PROJECT_ID".  Only one element, Task Number, has this value.  We don't think this is important at this time with no foreseeable future business requirement.
            */
            CASE WHEN l_element_value_type_rec.pk_id2 = 'ORGANIZATION_ID' THEN
                l_pk2_value := l_cpe.organization_id; --We know the org id from any record returned by the cur_plan_elements cursor.
            WHEN l_element_value_type_rec.pk_id2 = 'PROJECT_ID' THEN
                l_pk2_value := NULL;--If we ever need to get a value based off of PROJECT_ID, then write some code here to get it.  As a placeholder for now, we simply assign null.
            ELSE
                l_pk2_value := NULL;
            END CASE;

            CASE WHEN l_element_value_type_rec.pk_id3 = 'ORGANIZATION_ID' THEN --No known instances of this condition being true currently exist, but we include it as a placeholder for future rules on pk_id3 in the future.
                l_pk2_value := l_cpe.organization_id; --We know the org id from any record returned by the cur_plan_elements cursor.
            WHEN l_element_value_type_rec.pk_id3 = 'PROJECT_ID' THEN
                l_pk3_value := NULL; --If we ever need to get a value based off of PROJECT_ID, then write some code here to get it.  As a placeholder for now, we simply assign null.
            ELSE
                l_pk3_value := NULL;
            END CASE;
            
            /* Translate the stored value to the foreign table value. */
            CASE WHEN COALESCE(
                l_element_value_type_rec.pk_id
                ,l_element_value_type_rec.pk_id2
                ,l_element_value_type_rec.pk_id3
                ) IS NOT NULL
                THEN

                l_element_value :=xxqa_dynamic_lov_pkg.foreign_table_value(
                    p_char_name => l_element_value_type_rec.col_name
                    ,p_pk1_value => l_element_value_type_rec.col_value
                    ,p_pk2_value => l_pk2_value
                    ,p_pk3_value => l_pk3_value);

            ELSE
                l_element_value := l_element_value_type_rec.col_value;
            END CASE;        

            /* Write element values to the temp table as they are selected from qa_results for the occurrence. */
            l_temp_table_id := write_element_value(
                p_char_name => l_element_value_type_rec.col_name
                ,p_element_value => l_element_value
                );

        END LOOP;

        CLOSE l_element_value_cur;
        
        p_rows := l_row_count2;  --Return the number of rows written/updated to the temp table.

    EXCEPTION WHEN OTHERS THEN
        write_log('SQLERRM = ' || SQLERRM );

    END write_all_element_values;

    ----------------------------------------------------------------------------
    --  Name:              write_result_element_values
    --  Created by:        Hubert, Eric
    --  Revision:          1.0
    --  Creation Date:     25-Jan-2019
    --  Change Request:    CHG0042589
    --  Description:       Wrapper function for write_all_element_values that
    --                     can be called from within the from personalization
    --                     on the Update Quality Results form.  In order for this  
    --                     wrapper function to work, before it is called the
    --                     global variables GV_PLAN_ID and GV_OCCURRENCE must
    --                     be updated with the values for the current quality
    --                     results record.
    --
    --  Ver   Date          Name            Desc
    --  1.0   25-Jan-2019   Hubert, Eric    CHG0042589: Initial Build
    ----------------------------------------------------------------------------   
    FUNCTION write_result_element_values RETURN NUMBER
    IS
        l_result NUMBER;
    BEGIN
        gv_log_program_unit := 'write_result_element_values'; --store procedure name for logging
        write_log('gv_log_program_unit: ' || gv_log_program_unit);
                
        xxqa_dynamic_lov_pkg.write_all_element_values(
            p_plan_id => xxqa_dynamic_lov_pkg.gv_plan_id
            ,p_occurrence => xxqa_dynamic_lov_pkg.gv_occurrence
            ,p_rows => l_result);    
        
        RETURN l_result;

    EXCEPTION WHEN OTHERS THEN
        write_log('SQLERRM = ' || SQLERRM );
        RETURN NULL;        
        
    END write_result_element_values;

    ----------------------------------------------------------------------------
    --  Name:              foreign_table_value
    --  Created by:        Hubert, Eric
    --  Revision:          1.0
    --  Creation Date:     25-Jan-2019
    --  Change Request:    CHG0042589
    --  Description:       Certain collection elements are stored in the
    --                     qa_results table as an ID or code but displayed on
    --                     the from as a "business" meaning/description.  
    --                     This function wiil return the meaning/description
    --                     for a given element and value.
    --
    --                     To minimize the complexity of this function, practical
    --                     assumptions are made about values passed in the parameters
    --                     p_pk2_value and p_pk3_value.  Additional commentary is
    --                     provided below.
    --
    --                     In qa_chars, Oracle seems to put in the pk_id column what really
    --                     should be in the fk_id column and vice versa, which
    --                     is not at all intuitive.  That is, they have the name
    --                     of the foreign table's column in the pk_id column.
    --                     In contrast, they do "correctly" have fk_meaning and 
    --                     fk_description with the foreign table column names.
    --                     Because of this, the code in the procedure may be
    --                     a little unintuitive when looking at the pk_id,
    --                     pk_id1, pk_id2, fk_id, fk_id1, and fk_id2 column values.
    --                     
    --  Ver   Date          Name            Desc
    --  1.0   25-Jan-2019   Hubert, Eric    CHG0042589: Initial Build
    ----------------------------------------------------------------------------   
    FUNCTION foreign_table_value(
        p_char_name IN VARCHAR2
        , p_pk1_value IN VARCHAR2
        , p_pk2_value IN VARCHAR2 DEFAULT NULL --If used, this will almost always refer to the Inventory Org ID
        , p_pk3_value IN VARCHAR2 DEFAULT NULL --Available, but not currently used by Oracle.
        ) RETURN VARCHAR2
    IS

        /* Constants */
        c_sql_char_attb     CONSTANT VARCHAR2(1000):= 'SELECT fk_table_name, fk_table_short_name, pk_id, fk_id, pk_id2, fk_id2, pk_id3, fk_id3, fk_meaning, fk_add_where FROM qa_chars WHERE name = :a'; --Holds dynamic SQL statement to get element attributes

        /* Local Variables*/
        l_pk1_value VARCHAR2(150) := p_pk1_value; --Local copy of paramater
        l_pk2_value VARCHAR2(150) := p_pk2_value; --Local copy of paramater
        l_pk3_value VARCHAR2(150) := p_pk3_value; --Local copy of paramater
        l_fk_value              VARCHAR2(150);
        l_fk_table_name         qa_chars.fk_table_name%TYPE;
        l_fk_table_short_name   qa_chars.fk_table_short_name%TYPE;
        l_pk_id                 qa_chars.pk_id%TYPE;
        l_fk_id                 qa_chars.fk_id%TYPE;
        l_pk_id2                qa_chars.pk_id2%TYPE;
        l_fk_id2                qa_chars.fk_id2%TYPE;
        l_pk_id3                qa_chars.pk_id3%TYPE;
        l_fk_id3                qa_chars.fk_id3%TYPE;
        l_fk_meaning            qa_chars.fk_meaning%TYPE;
        l_fk_add_where          qa_chars.fk_add_where%TYPE;
        
        l_sql_fk VARCHAR2(1000);--Holds dynamic SQL statement to get foreign table value
        
        l_element_value_cur         SYS_REFCURSOR;

    BEGIN
        gv_log_program_unit := 'foreign_table_value'; --store procedure name for logging
        write_log('gv_log_program_unit: ' || gv_log_program_unit);
            
        /* Check that at least p_char_name and l_pk1_value are not null.*/
        IF p_char_name IS NULL OR l_pk1_value IS NULL THEN
            RETURN NULL;
        END IF;

        /* Get element attributes. */
        EXECUTE IMMEDIATE c_sql_char_attb
        INTO
            l_fk_table_name
            ,l_fk_table_short_name
            ,l_pk_id
            ,l_fk_id
            ,l_pk_id2
            ,l_fk_id2
            ,l_pk_id3
            ,l_fk_id3
            ,l_fk_meaning
            ,l_fk_add_where
        USING p_char_name;

        /* Handle known issues with elements 'UOM Name' and 'PO Receipt Number' */
        CASE WHEN p_char_name = 'UOM Name' THEN
            /* For some reason, the fk_id column for 'UOM Name' is "UOM".  However, there is no column named "UOM" in MTL_UNITS_OF_MEASURE.
            As a workaround, we will manually change the foreign table id and meaning columns. */
            l_pk_id := 'UNIT_OF_MEASURE';
            l_fk_meaning := l_pk_id;
        WHEN p_char_name = 'PO Receipt Number' THEN
            l_pk_id := 'RECEIPT_NUM';
            l_fk_meaning := l_pk_id;
        ELSE
            NULL; --Do nothing
        END CASE;

        /* Prepare Parameters*/
        l_pk1_value := dbms_assert.enquote_literal(str => l_pk1_value);--Add single quotes
        l_pk2_value := dbms_assert.enquote_literal(str => l_pk2_value);--Add single quotes
        l_pk3_value := dbms_assert.enquote_literal(str => l_pk3_value);--Add single quotes
  
        /* Verify that the foreign table name is valid, in part to reduce risk of SQL injection.
           Oracle will raise the exception, ORA-44002: invalid object name, if the table does not exist. */
        l_fk_table_name := DBMS_ASSERT.SQL_OBJECT_NAME(str => l_fk_table_name);

        /* Build SQL Statement*/
        l_sql_fk := 'SELECT ' || l_fk_meaning || ' FROM ' || l_fk_table_name || ' ' || l_fk_table_short_name;
        
        l_sql_fk := l_sql_fk || ' WHERE ' || l_fk_table_short_name || '.' || l_pk_id || ' = ' || l_pk1_value;
        
        /* Conditionally append the WHERE clause, if a second key column is specified. */
        IF l_fk_id2 IS NOT NULL AND l_pk_id2 IS NOT NULL THEN
            l_sql_fk := l_sql_fk || ' AND ' || l_fk_table_short_name || '.' || l_pk_id2 || ' = ' || l_pk2_value;
        END IF;

        /* Conditionally append the WHERE clause, if a third key column is specified. */
        IF l_fk_id3 IS NOT NULL AND l_pk_id3 IS NOT NULL THEN
            l_sql_fk := l_sql_fk || ' AND ' || l_fk_table_short_name || '.' || l_pk_id3 || ' = ' || l_pk3_value;
        END IF;            

        /* Conditionally append the WHERE clause, if an additional WHERE clause is specified. */
        IF l_fk_add_where IS NOT NULL THEN
            l_sql_fk := l_sql_fk || ' AND ' || l_fk_add_where;
        END IF; 

        /* Open a cursor based on the dynamic sql. 
           There are some instances of multiple rows returned in the foreign table, particularly as "PO Receipt Number".
           We choose to return just the first record so we do not use a loop.
        */
        OPEN l_element_value_cur FOR l_sql_fk;        
        
        FETCH l_element_value_cur INTO l_fk_value;
        
        IF ( l_element_value_cur%NOTFOUND ) THEN
            l_fk_value := NULL;
        END IF;
        
        CLOSE l_element_value_cur;

        RETURN l_fk_value;
        
    EXCEPTION WHEN OTHERS THEN
        write_log('SQLERRM = ' || SQLERRM );
        RETURN NULL;
          
    END foreign_table_value;

    ----------------------------------------------------------------------------
    --  Name:              clear_temp_table
    --  Created by:        Hubert, Eric
    --  Revision:          1.0
    --  Creation Date:     21-OCT-2019
    --  Change Request:    CHG0042589
    --  Description:       Clear entire temp table
    --
    --  Ver   Date          Name            Desc
    --  1.0   25-Jan-2019   Hubert, Eric    CHG0042589: Initial Build
    ----------------------------------------------------------------------------
    PROCEDURE clear_temp_table IS
    BEGIN
        gv_log_program_unit := 'clear_temp_table'; --store procedure name for logging
        write_log('gv_log_program_unit: ' || gv_log_program_unit);
        
        EXECUTE IMMEDIATE 'TRUNCATE TABLE apps.xxqa_element_values_temp';
        
    EXCEPTION WHEN OTHERS THEN
        write_log('SQLERRM = ' || SQLERRM );
        
    END clear_temp_table;
END xxqa_dynamic_lov_pkg;
/

