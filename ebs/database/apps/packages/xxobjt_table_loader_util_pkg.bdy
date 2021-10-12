CREATE OR REPLACE PACKAGE BODY xxobjt_table_loader_util_pkg IS
  ---------------------------------------------------------------------------
  -- $Header: xxobjt_table_loader_util_pkg   $
  ---------------------------------------------------------------------------
  -- Package: xxobjt_table_loader_util_pkg
  -- Created:
  -- Author:
  ------------------------------------------------------------------------------------------------
  -- Purpose: Populate Conversions Table from Excel
  ------------------------------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ----------------------------------------------------------
  --     1.0  11.6.13    Vitaly         initial build
  --     1.1  10.12.16   yuval tal      CHG0041985  NEWLINE replaced by '\r\n'
  --     1.2  11/04/2018 Roman.W        INC0119392 - XX Table Loader Definition
  --                                      in function load_file changed logic for
  --                                      data_type ="NUMBER", changed to default VARCHAR(250)
  ------------------------------------------------------------------------------------------------

  g_date_format VARCHAR2(30) := 'DD-MON-RRRR';
  -----------------------------------------------------------------------------
  PROCEDURE message(p_message VARCHAR2) IS
  
  BEGIN
    ---dbms_output.put_line(p_message);
    fnd_file.put_line(fnd_file.log, '========= ' || p_message);
  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END message;

  --------------------------------------------------------------------
  -- load_bad_file_to_clob
  -------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -----------------------------
  --     1.0  11.6.13    Vitaly      initial build
  -------------------------------------------------------------------- 
  PROCEDURE load_bad_file_to_clob(p_file_name      IN VARCHAR2,
                                  p_directory      IN VARCHAR2,
                                  p_clob           OUT CLOB,
                                  p_exists         OUT VARCHAR2,
                                  p_rejected_count OUT NUMBER) IS
  
    l_bfile                    BFILE;
    l_clob                     CLOB := empty_clob();
    l_destination_offset       INTEGER := 1;
    l_source_offset            INTEGER := 1;
    l_lang_ctx                 INTEGER := 0;
    l_warning                  INTEGER;
    l_start_pos                NUMBER;
    l_char13_10_pos            NUMBER;
    l_record_from_bad_file     VARCHAR2(3000);
    l_rejected_records_counter NUMBER := 0;
  BEGIN
    p_exists := 'Y';
    dbms_lob.createtemporary(l_clob, TRUE, dbms_lob.session);
    ----------
    BEGIN
      l_bfile := bfilename(p_directory, p_file_name);
      dbms_lob.fileopen(l_bfile, dbms_lob.file_readonly);
    EXCEPTION
      WHEN OTHERS THEN
        p_exists := 'N';
        RETURN;
    END;
    ----------
  
    dbms_lob.loadclobfromfile(l_clob,
                              l_bfile,
                              dbms_lob.getlength(l_bfile),
                              l_destination_offset,
                              l_source_offset,
                              dbms_lob.default_csid,
                              l_lang_ctx,
                              l_warning);
    --dbms_lob.freetemporary(b_lob); 
    dbms_lob.fileclose(l_bfile);
  
    message('********** See first 10 records rejected into BAD-file************');
    l_start_pos := 1;
    LOOP
      l_char13_10_pos := dbms_lob.instr(l_clob,
                                        chr(13) || chr(10),
                                        l_start_pos,
                                        1); ---end of line position
      EXIT WHEN l_char13_10_pos = 0;
      l_rejected_records_counter := l_rejected_records_counter + 1;
      l_record_from_bad_file     := dbms_lob.substr(l_clob,
                                                    l_char13_10_pos -
                                                    l_start_pos,
                                                    l_start_pos);
      IF l_rejected_records_counter <= 10 THEN
        message(l_record_from_bad_file); ---put in the log
      END IF;
      l_start_pos := l_char13_10_pos + 2;
    END LOOP;
    ---
    p_rejected_count := l_rejected_records_counter;
    p_clob           := l_clob;
  
  END load_bad_file_to_clob;
  -----------------------------------------------------------------------------
  --load_file
  ------------------------------------------------------------------------------
  --------------------------------------------------------------------------------------------------
  -- Version  Date        Performer       Comments
  ----------  ----------  --------------  ----------------------------------------------------------
  --     1.1  10.12.16    yuval tal      CHG0041985  NEWLINE replaced by '\r\n'  
  --                                      to support item long text which has end line inside \r
  --
  --     2.0  17-04-2017  Roman.W        INC0119392-XX Table Loader Definition 
  --------------------------------------------------------------------------------------------------
  PROCEDURE load_file(errbuf                 OUT VARCHAR2,
                      retcode                OUT VARCHAR2,
                      p_table_name           IN  VARCHAR2,
                      p_template_name        IN  VARCHAR2,
                      p_file_name            IN  VARCHAR2,
                      p_directory            IN  VARCHAR2,
                      p_expected_num_of_rows IN  NUMBER) IS
  
    ---Defined in our Setup...and included in CSV-file (in the same order order_seq)
    CURSOR c_get_columns_names_and_types IS
      SELECT tab.column_name,
             tab.date_format,
             tab.order_seq,
             tab.data_type,
             tab.data_length,
             decode(tab.next_column_name, '0', 'LAST_COLUMN', '') last_column_flag
        FROM (SELECT ltc.column_name,
                     ltc.order_seq,
                     ltc.date_format,
                     tabc.data_type,
                     tabc.data_length,
                     lead(ltc.column_name, 1, 0) over(ORDER BY ltc.order_seq) AS next_column_name
                FROM xxobjt_loader_table_columns ltc, dba_tab_columns tabc
               WHERE ltc.table_name = p_table_name --param
                 AND ltc.template_name = p_template_name --param  
                 AND ltc.table_name = tabc.table_name
                 AND ltc.column_name = tabc.column_name
                 AND ltc.formula IS NULL) tab
       ORDER BY tab.order_seq;
    ---Defined in our Setup...and NOT INCLUDED in CSV-file
    CURSOR c_get_formula_columns IS
      SELECT ltc.column_name, ltc.formula
        FROM xxobjt_loader_table_columns ltc, dba_tab_columns tabc
       WHERE ltc.table_name = p_table_name --param
         AND ltc.template_name = p_template_name --param  
         AND ltc.table_name = tabc.table_name
         AND ltc.column_name = tabc.column_name
         AND ltc.formula IS NOT NULL;
  
    v_error_messsage VARCHAR2(5000);
    stop_processing EXCEPTION;
    v_step                         VARCHAR2(100);
    v_numeric_dummy                NUMBER;
    v_concurrent_request_id        NUMBER := fnd_global.conc_request_id;
    v_bad_file_name                VARCHAR2(100);
    v_directory_name               VARCHAR2(30) := 'XXOBJT_TAB_LOADER_DIR';
    v_external_table_name          VARCHAR2(30);
    v_sql_statement                VARCHAR2(5000);
    v_column_data_type_and_length  VARCHAR2(30);
    v_columns_names_and_types_list VARCHAR2(5000);
    v_columns_names_and_typ_list_c VARCHAR2(5000);
    v_columns_names_list           VARCHAR2(5000);
    v_select_columns_names_list    VARCHAR2(5000);
  
    ----For Who columns---
    v_insert_creation_date_column  VARCHAR2(100);
    v_insert_creation_date_value   VARCHAR2(100);
    v_insert_created_by_column     VARCHAR2(100);
    v_insert_created_by_value      VARCHAR2(100);
    v_insert_last_update_date_col  VARCHAR2(100);
    v_insert_last_update_date_val  VARCHAR2(100);
    v_insert_last_updated_by_col   VARCHAR2(100);
    v_insert_last_updated_by_val   VARCHAR2(100);
    v_insert_last_update_login_col VARCHAR2(100);
    v_insert_last_update_login_val VARCHAR2(100);
  
    ----For our "formula" columns---for example:for column XXOBJT_CONV_ROUTING.ERROR_CODE you can insert formula='N'
    v_formula_column_names  VARCHAR2(5000);
    v_formula_column_values VARCHAR2(5000);
  
    v_num_of_inserted_records NUMBER;
    v_bad_file_clob           CLOB;
    v_bad_file_exists         VARCHAR2(100); ---- if 'Y' then bad-file exists (with rejected records)
    v_num_of_rejected_records NUMBER;
  
  BEGIN
  
    v_step  := 'Step 0';
    retcode := '0';
    errbuf  := 'Success';
  
    ---*****parameters******
    message('Parameter p_table_name=' || p_table_name);
    message('Parameter p_template_name=' || p_template_name);
    message('Parameter p_file_name=' || p_file_name);
    message('Parameter p_directory=''' || p_directory || '''');
    message('Parameter p_expected_num_of_rows=' || p_expected_num_of_rows);
    ----*******************
  
    v_bad_file_name := v_concurrent_request_id || '_' ||
                       REPLACE(p_file_name, ' ', '_') || '.bad';
  
    message('BAD-file name: ' || v_bad_file_name);
  
    v_step := 'Step 10';
    ---Check parameter p_table_name-----  
    IF p_table_name IS NULL THEN
      ---Error----
      v_error_messsage := 'Missing parameter p_table_name';
      RAISE stop_processing;
    ELSE
      ------
      BEGIN
        SELECT 1
          INTO v_numeric_dummy
          FROM dba_tables dt
         WHERE dt.table_name = p_table_name; --param
      EXCEPTION
        WHEN no_data_found THEN
          ---Error----
          v_error_messsage := 'Invalid parameter p_table_name value';
          RAISE stop_processing;
      END;
      ------
    END IF;
  
    v_step := 'Step 12';
    ---Check parameter p_template_name-----  
    IF p_template_name IS NULL THEN
      ---Error----
      v_error_messsage := 'Missing parameter p_template_name';
      RAISE stop_processing;
    ELSE
      ------
      BEGIN
        SELECT 1
          INTO v_numeric_dummy
          FROM xxobjt_flex_dependent_v a
         WHERE a.parent_value = p_table_name --param
           AND a.child_value = p_template_name --param
           AND a.parent_vs_name = 'XXOBJT_LOADER_TABLES'
           AND a.child_vs_name = 'XXOBJT_LOADER_TEMPLATES';
      EXCEPTION
        WHEN no_data_found THEN
          ---Error----
          v_error_messsage := 'Invalid parameter p_template_name value';
          RAISE stop_processing;
      END;
      ------
    END IF;
  
    v_step := 'Step 20';
    ---Check NOT-NULLABLE columns in destination table that are not defined ...-----  
    BEGIN
      SELECT 1
        INTO v_numeric_dummy
        FROM dba_tab_columns tabc
       WHERE tabc.table_name = p_table_name --param
         AND nvl(tabc.nullable, 'N') = 'N' --not nullable
         AND tabc.column_name NOT IN
             ('LAST_UPDATE_DATE',
              'LAST_UPDATED_BY',
              'CREATION_DATE',
              'CREATED_BY',
              'LAST_UPDATE_LOGIN')
         AND NOT EXISTS (SELECT 1
                FROM xxobjt_loader_table_columns ltc
               WHERE tabc.table_name = ltc.table_name
                 AND ltc.template_name = p_template_name --param
                 AND tabc.column_name = ltc.column_name)
         AND rownum = 1;
      ---Error----
      v_error_messsage := 'There are NON-Nullable columns in destination table ' ||
                          p_table_name ||
                          ' that are not defined in XXOBJT_LOADER_TABLE_COLUMNS table';
      RAISE stop_processing;
    EXCEPTION
      WHEN no_data_found THEN
        NULL;
    END;
    ------
  
    v_step := 'Step 25';
    ---Search CREATION_DATE in this conversion table-----
    BEGIN
      SELECT ',CREATION_DATE ', ',SYSDATE '
        INTO v_insert_creation_date_column, v_insert_creation_date_value
        FROM dba_tab_columns tabc
       WHERE tabc.table_name = p_table_name --param
         AND tabc.column_name = 'CREATION_DATE' ---param
         AND NOT EXISTS
       (SELECT 1
                FROM xxobjt_loader_table_columns ltc
               WHERE tabc.table_name = ltc.table_name
                 AND ltc.template_name = p_template_name --param
                 AND tabc.column_name = ltc.column_name);
    EXCEPTION
      WHEN no_data_found THEN
        v_insert_creation_date_column := NULL;
        v_insert_creation_date_value  := NULL;
    END;
    ---------------------
    v_step := 'Step 25.2';
    ---Search CREATED_BY in this conversion table-----
    BEGIN
      SELECT ',CREATED_BY ', ',' || fnd_global.user_id || ' '
        INTO v_insert_created_by_column, v_insert_created_by_value
        FROM dba_tab_columns tabc
       WHERE tabc.table_name = p_table_name --param
         AND tabc.column_name = 'CREATED_BY' ---param
         AND NOT EXISTS
       (SELECT 1
                FROM xxobjt_loader_table_columns ltc
               WHERE tabc.table_name = ltc.table_name
                 AND ltc.template_name = p_template_name --param
                 AND tabc.column_name = ltc.column_name);
    EXCEPTION
      WHEN no_data_found THEN
        v_insert_created_by_column := NULL;
        v_insert_created_by_value  := NULL;
    END;
    ---------------------
    v_step := 'Step 25.3';
    ---Search LAST_UPDATE_DATE in this conversion table-----
    BEGIN
      SELECT ',LAST_UPDATE_DATE ', ',SYSDATE '
        INTO v_insert_last_update_date_col, v_insert_last_update_date_val
        FROM dba_tab_columns tabc
       WHERE tabc.table_name = p_table_name --param
         AND tabc.column_name = 'LAST_UPDATE_DATE' ---param
         AND NOT EXISTS
       (SELECT 1
                FROM xxobjt_loader_table_columns ltc
               WHERE tabc.table_name = ltc.table_name
                 AND ltc.template_name = p_template_name --param
                 AND tabc.column_name = ltc.column_name);
    EXCEPTION
      WHEN no_data_found THEN
        v_insert_last_update_date_col := NULL;
        v_insert_last_update_date_val := NULL;
    END;
    ---------------------
    v_step := 'Step 25.4';
    ---Search LAST_UPDATED_BY in this conversion table-----
    BEGIN
      SELECT ',LAST_UPDATED_BY ', ',' || fnd_global.user_id || ' '
        INTO v_insert_last_updated_by_col, v_insert_last_updated_by_val
        FROM dba_tab_columns tabc
       WHERE tabc.table_name = p_table_name --param
         AND tabc.column_name = 'LAST_UPDATED_BY' ---param
         AND NOT EXISTS
       (SELECT 1
                FROM xxobjt_loader_table_columns ltc
               WHERE tabc.table_name = ltc.table_name
                 AND ltc.template_name = p_template_name --param
                 AND tabc.column_name = ltc.column_name);
    EXCEPTION
      WHEN no_data_found THEN
        v_insert_last_updated_by_col := NULL;
        v_insert_last_updated_by_val := NULL;
    END;
    ---------------------
    v_step := 'Step 25.5';
    ---Search LAST_UPDATE_LOGIN in this conversion table-----
    BEGIN
      SELECT ',LAST_UPDATE_LOGIN ', ',' || fnd_global.conc_login_id || ' '
        INTO v_insert_last_update_login_col, v_insert_last_update_login_val
        FROM dba_tab_columns tabc
       WHERE tabc.table_name = p_table_name --param
         AND tabc.column_name = 'LAST_UPDATE_LOGIN' ---param
         AND NOT EXISTS
       (SELECT 1
                FROM xxobjt_loader_table_columns ltc
               WHERE tabc.table_name = ltc.table_name
                 AND ltc.template_name = p_template_name --param
                 AND tabc.column_name = ltc.column_name);
    EXCEPTION
      WHEN no_data_found THEN
        v_insert_last_update_login_col := NULL;
        v_insert_last_update_login_val := NULL;
    END;
    ---------------------
  
    v_step := 'Step 30';
    ---Get all (non-formula) columns names and types-----
    FOR column_rec IN c_get_columns_names_and_types LOOP
      IF column_rec.data_type IN ('VARCHAR2', 'CHAR') THEN
        v_column_data_type_and_length := column_rec.data_type || '(' ||
                                         column_rec.data_length || ')';
      ELSE
        v_column_data_type_and_length := column_rec.data_type;
      END IF;
      -- remove replace CHG0041985 10/13
      IF column_rec.last_column_flag = 'LAST_COLUMN' THEN
        v_select_columns_names_list := v_columns_names_list || ',' ||
                                      /* replace(replace(' ||
                                                                                                                                                                                               column_rec.column_name' 
                                                                                                                                                                                             ',chr(13),''''),chr(10),'''') ' ||*/
                                       column_rec.column_name;
        -- Rem by Roman.W 11/04/2018 --                               
        -- IF column_rec.data_type IN ('NUMBER', 'VARCHAR2', 'CHAR') THEN                                       
        IF column_rec.data_type IN ('VARCHAR2', 'CHAR') THEN
          ---if last column is "NUMBER" then it will be VARCHAR2(100) in external table definition
          ---this is our solution for chr(13)chr(10) at the end of record
          ---chr(13)chr(10) will be removed when Insert..Select...replace(replace(...
          v_columns_names_and_types_list := v_columns_names_and_types_list || ',' ||
                                            column_rec.column_name || '  ' ||
                                            'VARCHAR2(' ||
                                            column_rec.data_length || ')' || ' ';
          v_columns_names_and_typ_list_c := v_columns_names_and_typ_list_c || ',' ||
                                            column_rec.column_name || '  ' ||
                                            'VARCHAR2(' ||
                                            column_rec.data_length || ')' || ' ';
          -- INC0119392 Added by Roman.W 11/04/2018 --                                                                           
        ELSIF column_rec.data_type = 'NUMBER' THEN
        
          v_columns_names_and_types_list := v_columns_names_and_types_list || ',' ||
                                            column_rec.column_name || '  ' ||
                                            'VARCHAR2(250)' || ' ';
          v_columns_names_and_typ_list_c := v_columns_names_and_typ_list_c || ',' ||
                                            column_rec.column_name || '  ' ||
                                            'VARCHAR2(250)' || ' ';
          -- INC0119392 End added by Roman.W 11/04/2018 --                                                                                                                       
        ELSE
          v_columns_names_and_types_list := v_columns_names_and_types_list || ',' ||
                                            column_rec.column_name || '  ' ||
                                            v_column_data_type_and_length || ' ';
          v_columns_names_and_typ_list_c := v_columns_names_and_typ_list_c || ',' ||
                                            column_rec.column_name || '  ' ||
                                            REPLACE(v_column_data_type_and_length,
                                                    'DATE',
                                                    ' DATE "' ||
                                                    nvl(column_rec.date_format,
                                                        g_date_format) || '"') || ' ';
        END IF;
      ELSE
        v_columns_names_and_types_list := v_columns_names_and_types_list || ',' ||
                                          column_rec.column_name || '  ' ||
                                          v_column_data_type_and_length || ' ';
        v_columns_names_and_typ_list_c := v_columns_names_and_typ_list_c || ',' ||
                                          column_rec.column_name || '  ' ||
                                          REPLACE(v_column_data_type_and_length,
                                                  'DATE',
                                                  ' DATE "' ||
                                                  nvl(column_rec.date_format,
                                                      g_date_format) || '"') || ' ';
      END IF;
      v_columns_names_list := v_columns_names_list || ',' ||
                              column_rec.column_name;
      /*   v_columns_names_and_types_list := v_columns_names_and_types_list || ',' ||
      column_rec.column_name || '  ' ||
      v_column_data_type_and_length || ' ';*/ --- I need blank at the end for REPLACE below
    END LOOP;
    v_columns_names_list           := ltrim(v_columns_names_list, ',');
    v_select_columns_names_list    := ltrim(v_select_columns_names_list,
                                            ',');
    v_columns_names_and_types_list := ltrim(v_columns_names_and_types_list,
                                            ',');
    v_columns_names_and_typ_list_c := ltrim(v_columns_names_and_typ_list_c,
                                            ',');
    v_columns_names_and_typ_list_c := REPLACE(REPLACE(v_columns_names_and_typ_list_c,
                                                      'VARCHAR2',
                                                      'CHAR'), -- replace VARCHAR2(...) to CHAR(...) (below)
                                              ' NUMBER ',
                                              ' CHAR(250) '); -- NO type "NUMBER" for numeric columns (below)                                              
    /*v_columns_names_and_typ_list_c := REPLACE(REPLACE(REPLACE(v_columns_names_and_types_list,
                                                            'VARCHAR2',
                                                            'CHAR'), -- replace VARCHAR2(...) to CHAR(...) (below)
                                                    ' NUMBER ',
                                                    ' CHAR(50) '), -- NO type "NUMBER" for numeric columns (below)
                                            ' DATE ',
                                            ' DATE "' || g_date_format || '"'); --replace DATE to DATE "DD-MON-YYYY"
    */
    v_formula_column_names  := NULL;
    v_formula_column_values := NULL;
    FOR formula_column_rec IN c_get_formula_columns LOOP
      v_formula_column_names  := v_formula_column_names || ',' ||
                                 formula_column_rec.column_name;
      v_formula_column_values := v_formula_column_values || ',' ||
                                 formula_column_rec.formula;
    END LOOP;
    v_formula_column_names  := v_formula_column_names || ' ';
    v_formula_column_values := v_formula_column_values || ' ';
  
    message('Columns names list: ' || v_columns_names_list);
    message('Select columns names list: ' || v_select_columns_names_list);
    message('Columns names and types list: ' ||
            v_columns_names_and_types_list);
    message('Columns names and types list CHAR: ' ||
            v_columns_names_and_typ_list_c);
    message('Formula Columns names: ' || v_formula_column_names);
    message('Formula Columns values:' || v_formula_column_values);
  
    v_step := 'Step 40';
    ---Prepare external table name-----(maximum table name length=30)------
    v_external_table_name := substr(p_table_name, 1, 26) || '_EXT';
    message('External table name=' || v_external_table_name);
  
    v_step := 'Step 50';
    ---Check parameter p_file_name-----
    IF p_file_name IS NULL THEN
      ---Error----
      v_error_messsage := 'Missing parameter p_file_name';
      RAISE stop_processing;
    END IF;
  
    v_step := 'Step 60';
    ---Check parameter p_directory-----
    IF p_directory IS NULL THEN
      -----p_directory value for example:  
      --------'/UtlFiles/shared/DEV/CONV' ---( \\objet-data\Oracle_Files\shared\DEV\CONV)
      ---Error----
      v_error_messsage := 'Missing parameter p_directory';
      RAISE stop_processing;
    END IF;
  
    v_step := 'Step 70';
    ---Create or replace our directory-----
    v_sql_statement := 'CREATE OR REPLACE DIRECTORY ' || v_directory_name ||
                       ' AS ''' || p_directory || '''';
    ------
    BEGIN
      EXECUTE IMMEDIATE v_sql_statement;
      message('Directory ' || v_directory_name ||
              ' was created/replaced successfully');
    EXCEPTION
      WHEN OTHERS THEN
        ---Error----
        v_error_messsage := substr('Create/Replace Directory Error: ' ||
                                   SQLERRM,
                                   1,
                                   200);
        RAISE stop_processing;
    END;
    ------ 
  
    v_step := 'Step 80';
    ---Drop existing external table-----
    v_sql_statement := 'DROP TABLE ' || v_external_table_name;
    ------
    BEGIN
      EXECUTE IMMEDIATE v_sql_statement;
      message('Existing external table ' || v_external_table_name ||
              ' was dropped successfully');
    EXCEPTION
      WHEN OTHERS THEN
        message('External table ' || v_external_table_name ||
                ' does not exist and will be created');
    END;
    ------
  
    v_step := 'Step 90';
    ---Create external table-----
    v_sql_statement := 'CREATE TABLE ' || v_external_table_name || ' ( ' ||
                       v_columns_names_and_types_list ||
                       ' ) ORGANIZATION EXTERNAL ( ' ||
                       ' TYPE ORACLE_LOADER DEFAULT DIRECTORY ' ||
                       v_directory_name || ' ACCESS PARAMETERS ( ' ||
                       ' RECORDS DELIMITED BY ' || q'[ '\r\n' ]' ||
                       ' SKIP=1 ' || -- CHG0041985  NEWLINE replaced by '\r\n'
                       ' BADFILE ''' || v_bad_file_name || --- see all invalid(rejected) records from CSV-file
                      ---' NOBADFILE NODISCARDFILE NOLOGFILE ' ||
                       ''' NODISCARDFILE NOLOGFILE ' ||
                       ' FIELDS TERMINATED BY ''' || ',' || '''' ||
                       ' OPTIONALLY ENCLOSED BY ''' || '"' || '''' ||
                       ' MISSING FIELD VALUES ARE NULL ( ' ||
                       v_columns_names_and_typ_list_c || ' )) ' ||
                       ' LOCATION (''' || p_file_name || '''' ||
                       ' )) PARALLEL 5 REJECT LIMIT UNLIMITED ';
  
    message('-------- Create external table statement -------');
    message(v_sql_statement);
    ------
    BEGIN
      EXECUTE IMMEDIATE v_sql_statement;
      message('External table ' || v_external_table_name ||
              ' was created successfully');
    
    EXCEPTION
      WHEN OTHERS THEN
        ---Error----
        v_error_messsage := substr('Create External Table Error: ' ||
                                   SQLERRM,
                                   1,
                                   200);
        RAISE stop_processing;
    END;
    ------
  
    v_step := 'Step 100';
    ----Loading data from CSV-file to destination table-----------------
    ---(Insert into destination table as Select from external table)----
    v_sql_statement := 'INSERT INTO ' || p_table_name || ' ( ' ||
                       v_columns_names_list ||
                       v_insert_creation_date_column ||
                       v_insert_created_by_column ||
                       v_insert_last_update_date_col ||
                       v_insert_last_updated_by_col ||
                       v_insert_last_update_login_col ||
                       v_formula_column_names || ' ) SELECT ' ||
                       v_select_columns_names_list ||
                       v_insert_creation_date_value ||
                       v_insert_created_by_value ||
                       v_insert_last_update_date_val ||
                       v_insert_last_updated_by_val ||
                       v_insert_last_update_login_val ||
                       v_formula_column_values || ' FROM ' ||
                       v_external_table_name;
  
    message('--------Insert into..Select..statement-------');
    message(v_sql_statement);
    ------
    BEGIN
      EXECUTE IMMEDIATE v_sql_statement;
      v_num_of_inserted_records := SQL%ROWCOUNT;
      COMMIT;
      /*message(v_num_of_inserted_records ||
      ' records were loaded into table ' || p_table_name ||
      ' from file ' || p_file_name);*/
    
    EXCEPTION
      WHEN OTHERS THEN
        ---Error----
        v_error_messsage := substr('Insert Into ' || p_table_name ||
                                   ' Select from ' || v_external_table_name ||
                                   ' Error: ' || SQLERRM,
                                   1,
                                   200);
        RAISE stop_processing;
    END;
  
    ------
  
    v_step := 'Step 110';
  
    load_bad_file_to_clob(p_file_name      => v_bad_file_name,
                          p_directory      => v_directory_name, ---XXOBJT_TAB_LOADER_DIR
                          p_clob           => v_bad_file_clob,
                          p_exists         => v_bad_file_exists,
                          p_rejected_count => v_num_of_rejected_records);
    message('concurrent was completed =================================================');
    message('RESULTS ==================================================================');
    message(v_num_of_inserted_records ||
            ' records were LOADED SUCCESSFULLY');
  
    IF v_bad_file_exists = 'Y' THEN
      message('WARNING  ---- ' || v_num_of_rejected_records ||
              ' records were rejected -- see rejected rows in file :' ||
              v_directory_name || '/' || v_bad_file_name);
      retcode := '1';
      errbuf  := 'WARNING  ---- ' || v_num_of_rejected_records ||
                 ' records were rejected -- see bad file';
    END IF;
  
    IF p_expected_num_of_rows IS NOT NULL AND
       v_num_of_inserted_records <> p_expected_num_of_rows THEN
    
      message('WARNING ---- THE NUMBER OF SUCCESSFULLY LOADED RECORDS IS NOT EQUEL TO EXPECTED NUMBER OF RECORDS ');
      retcode := '1';
      errbuf  := 'The number of successfully loaded records is not equel to expected number of records ';
    
    END IF;
  
  EXCEPTION
    WHEN stop_processing THEN
      v_error_messsage := 'ERROR in xxobjt_table_loader_util_pkg.load_file: ' ||
                          v_error_messsage;
      fnd_file.put_line(fnd_file.log, '========= ' || v_error_messsage);
      retcode := '2';
      errbuf  := v_error_messsage;
    WHEN OTHERS THEN
      v_error_messsage := substr('Unexpected ERROR in xxobjt_table_loader_util_pkg.load_file (' ||
                                 v_step || ') ' || SQLERRM,
                                 1,
                                 200);
      fnd_file.put_line(fnd_file.log, '========= ' || v_error_messsage);
      retcode := '2';
      errbuf  := v_error_messsage;
  END load_file;
  ----------------------------------------------------------------------------------------- 
  FUNCTION submit_request_build_template(p_table_name    IN VARCHAR2,
                                         p_template_name IN VARCHAR2)
    RETURN NUMBER IS
    ------ request_id will be returned------
    l_request_id      NUMBER;
    l_is_layout_added BOOLEAN;
  
  BEGIN
    IF p_table_name IS NULL THEN
      RETURN NULL;
    END IF;
    l_is_layout_added := fnd_request.add_layout(template_appl_name => 'XXOBJT',
                                                template_code      => 'XXOBJTLDR',
                                                template_language  => 'en',
                                                template_territory => 'US',
                                                output_format      => 'EXCEL');
    IF l_is_layout_added THEN
      l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                                 program     => 'XXOBJTLDR',
                                                 argument1   => p_table_name,
                                                 argument2   => p_template_name);
      COMMIT;
    END IF;
  
    RETURN l_request_id;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
      ----- substr('Unexpected Error in xxobjt_table_loader_util_pkg.submit_request_build_template: ' ||
    -----           SQLERRM,1,150);
  END submit_request_build_template;
  ----------------------------------------------------------------------------------------- 
END xxobjt_table_loader_util_pkg;
/
