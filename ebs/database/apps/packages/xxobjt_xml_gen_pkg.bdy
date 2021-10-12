CREATE OR REPLACE PACKAGE BODY xxobjt_xml_gen_pkg IS
  ---------------------------------------------------------------------------
  -- $Header: xxobjt_xml_gen_pkg   $
  ---------------------------------------------------------------------------
  -- Package: XXOBJT_XML_GEN_PKG
  -- Created:
  -- Author:  Vitaly
  ------------------------------------------------------------------
  -- Purpose: CUST-751 - Generic xml file generation (CR1047)
  ------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ----------------------------
  --     1.0  24.9.13   Vitaly         initial build
  --    1.1  18.09.14   yuval tal       CHG0032515 - modify create_xml_file 
  ------------------------------------------------------------------

  ------------------------------------------------------------------
  PROCEDURE message(p_message VARCHAR2) IS
  
  BEGIN
    ---dbms_output.put_line(p_message);
    fnd_file.put_line(fnd_file.log, '========= ' || p_message);
  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END message;

  ------------------------------------------------------------------
  -- validate_query
  ----------------------------------------------------------------
  -- Purpose: CUST-751 - Generic xml file generation (CR1047)
  -----------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------------------
  --     1.0  24.9.13   Vitaly         initial build
  -----------------------------------------------------------------
  FUNCTION validate_query(p_file_code           IN VARCHAR2,
                          p_error_message       OUT VARCHAR2,
                          p_num_of_rows_fetched OUT NUMBER) RETURN VARCHAR2 IS
    ---Return values: 'VALID','INVALID'
    v_error_messsage VARCHAR2(5000);
    stop_processing EXCEPTION;
  
    v_step VARCHAR2(100);
    ---Setup data for a given file_code ----
    v_setup_rec xxobjt_xml_gen%ROWTYPE;
  
    v_query_context dbms_xmlgen.ctxhandle;
    v_xml           CLOB;
  
  BEGIN
  
    ---*****parameters******
    message('Parameter p_file_code=' || p_file_code);
    message('****************************************************************');
    ----*******************
  
    v_step := 'Step 10';
    IF p_file_code IS NULL THEN
      ---Error----
      v_error_messsage := 'Missing parameter p_file_code';
      RAISE stop_processing;
    ELSE
      ------
      BEGIN
        SELECT *
          INTO v_setup_rec
          FROM xxobjt_xml_gen a
         WHERE a.file_code = p_file_code; --parameter
      EXCEPTION
        WHEN no_data_found THEN
          ---Error----
          v_error_messsage := 'Invalid parameter p_file_code value';
          RAISE stop_processing;
      END;
      ------
    END IF;
  
    --- Execute PRE_RUN_SQL (for example apps_initialize...)
    v_step := 'Step 35';
    IF v_setup_rec.pre_run_sql IS NOT NULL THEN
      ------
      BEGIN
        EXECUTE IMMEDIATE v_setup_rec.pre_run_sql;
      EXCEPTION
        WHEN OTHERS THEN
          ---Error----
          v_error_messsage := substr('Pre Run Sql Error: ' || SQLERRM,
                                     1,
                                     200);
          RAISE stop_processing;
      END;
      ------
    END IF;
  
    v_step := 'Step 70';
    -- Create new Context for the Query
    v_query_context := dbms_xmlgen.newcontext(v_setup_rec.query_select);
  
    v_step := 'Step 80';
    -- Set Query Parameters---- PARAM1, PARAM2, PARAM3, PARAM4, PARAM5, PARAM6
    IF v_setup_rec.param1 IS NOT NULL THEN
      dbms_xmlgen.setbindvalue(v_query_context,
                               'PARAM1',
                               v_setup_rec.param1);
    END IF;
    IF v_setup_rec.param2 IS NOT NULL THEN
      dbms_xmlgen.setbindvalue(v_query_context,
                               'PARAM2',
                               v_setup_rec.param2);
    END IF;
    IF v_setup_rec.param3 IS NOT NULL THEN
      dbms_xmlgen.setbindvalue(v_query_context,
                               'PARAM3',
                               v_setup_rec.param3);
    END IF;
    IF v_setup_rec.param4 IS NOT NULL THEN
      dbms_xmlgen.setbindvalue(v_query_context,
                               'PARAM4',
                               v_setup_rec.param4);
    END IF;
    IF v_setup_rec.param5 IS NOT NULL THEN
      dbms_xmlgen.setbindvalue(v_query_context,
                               'PARAM5',
                               v_setup_rec.param5);
    END IF;
    IF v_setup_rec.param6 IS NOT NULL THEN
      dbms_xmlgen.setbindvalue(v_query_context,
                               'PARAM6',
                               v_setup_rec.param6);
    END IF;
  
    v_step := 'Step 90';
    -- Special characters in the XML data must be converted into their escaped XML equivalent.
    ----------For example, the < sign is converted to     show error    ;
    dbms_xmlgen.setconvertspecialchars(v_query_context, TRUE);
  
    v_step := 'Step 100';
    -- Set Parent and Child Node
    dbms_xmlgen.setrowsettag(v_query_context, v_setup_rec.root_tag);
    dbms_xmlgen.setrowtag(v_query_context, v_setup_rec.row_tag);
  
    v_step := 'Step 110';
    -- setNullHandling to show Tag also when the value is NULL
    /*\*  DROP_NULLS CONSTANT NUMBER:= 0; (Default) Leaves out the tag for NULL elements.
    NULL_ATTR CONSTANT NUMBER:= 1; Sets xsi:nil="true".
    EMPTY_TAG CONSTANT NUMBER:= 2; Sets, for example, <foo/>.*\
    
    IF nvl(v_setup_rec.hide_empty_tag, 'N') = 'Y' THEN
      v_step := 'Step 120';
      dbms_xmlgen.setnullhandling(v_query_context, dbms_xmlgen.empty_tag);
    
    END IF;*/
  
    v_step := 'Step 130';
    -- getXML in CLOB
    BEGIN
      v_xml := dbms_xmlgen.getxml(v_query_context);
    EXCEPTION
      WHEN OTHERS THEN
        v_error_messsage := 'Invalid Sql Query - ' || SQLERRM;
        RAISE stop_processing;
    END;
    --------
  
    v_step                := 'Step 150';
    p_num_of_rows_fetched := dbms_xmlgen.getnumrowsprocessed(v_query_context);
  
    v_step := 'Step 160';
    -- Close Context
    dbms_xmlgen.closecontext(v_query_context);
  
    RETURN 'VALID';
  
  EXCEPTION
    WHEN stop_processing THEN
      p_error_message := v_error_messsage;
      RETURN 'INVALID';
    WHEN OTHERS THEN
      p_error_message := substr('Unexpected ERROR in xxobjt_xml_gen_pkg.validate_query (' ||
                                v_step || ') ' || SQLERRM,
                                1,
                                200);
    
      RETURN 'INVALID';
  END validate_query;
  -----------------------------------------------------------------
  -- create_xml_file
  ----------------------------------------------------------------
  -- Purpose: CUST-751 - Generic xml file generation (CR1047)
  -----------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------------------
  --     1.0  24.9.13   Vitaly         initial build
  --    1.1   18.09.13  yuval tal      CHG0032515 - Expeditors TPL Interfaces add rename action from tmp file to actual 
  -----------------------------------------------------------------

  PROCEDURE create_xml_file(errbuf             OUT VARCHAR2,
                            retcode            OUT VARCHAR2,
                            p_file_id          OUT NUMBER,
                            p_file_code        IN VARCHAR2,
                            p_directory        IN VARCHAR2 DEFAULT NULL,
                            p_file_name_prefix IN VARCHAR2 DEFAULT NULL,
                            p_param1           IN VARCHAR2 DEFAULT NULL,
                            p_param2           IN VARCHAR2 DEFAULT NULL,
                            p_param3           IN VARCHAR2 DEFAULT NULL,
                            p_param4           IN VARCHAR2 DEFAULT NULL,
                            p_param5           IN VARCHAR2 DEFAULT NULL,
                            p_param6           IN VARCHAR2 DEFAULT NULL) IS
  
    v_error_messsage VARCHAR2(5000);
    stop_processing EXCEPTION;
  
    v_step                  VARCHAR2(100);
    v_concurrent_request_id NUMBER := fnd_global.conc_request_id;
    v_sql_statement         VARCHAR2(3000);
    ---Setup data for a given file_code ----
    v_setup_rec xxobjt_xml_gen%ROWTYPE;
  
    v_file_id        NUMBER;
    v_file_name      VARCHAR2(50);
    v_directory_name VARCHAR2(50);
  
    v_query_context       dbms_xmlgen.ctxhandle;
    v_xml                 CLOB;
    v_num_of_rows_fetched NUMBER;
  
  BEGIN
  
    v_step  := 'Step 0';
    retcode := '0';
    errbuf  := 'Success';
  
    ---*****parameters******
    message('Parameter p_file_code=' || p_file_code);
    message('Parameter p_directory=' || p_directory);
    message('Parameter p_file_name_prefix=' || p_file_name_prefix);
    message('Parameter p_param1=' || p_param1);
    message('Parameter p_param2=' || p_param2);
    message('Parameter p_param3=' || p_param3);
    message('Parameter p_param4=' || p_param4);
    message('Parameter p_param5=' || p_param5);
    message('Parameter p_param6=' || p_param6);
    message('****************************************************************');
    ----*******************
  
    v_step := 'Step 5';
    IF p_file_code IS NULL THEN
      ---Error----
      v_error_messsage := 'Missing parameter p_file_code';
      RAISE stop_processing;
    ELSE
      ------
      BEGIN
        SELECT *
          INTO v_setup_rec
          FROM xxobjt_xml_gen a
         WHERE a.file_code = p_file_code; --parameter
      EXCEPTION
        WHEN no_data_found THEN
          ---Error----
          v_error_messsage := 'Invalid parameter p_file_code value';
          RAISE stop_processing;
      END;
      ------
    END IF;
  
    v_step := 'Step 10';
    IF p_directory IS NULL THEN
      ---Error----
      v_error_messsage := 'Missing parameter p_directory';
      RAISE stop_processing;
    END IF;
  
    v_step    := 'Step 20';
    v_file_id := xxobjt_interface_file_log_seq.nextval;
    message('file_id=' || v_file_id);
  
    v_step := 'Step 25';
  
    v_file_name := nvl(p_file_name_prefix, v_setup_rec.prefix_name) || '_' ||
                   to_char(SYSDATE, 'YYYYMMDD') || '_' || v_file_id ||
                   '.xml';
  
    message('file_id=' || v_file_id || ' --------- file_name=' ||
            v_file_name);
  
    --- Create or Replace Directory
    v_step           := 'Step 30';
    v_directory_name := 'XXOBJT_XML_' || p_file_code;
    v_sql_statement  := 'CREATE OR REPLACE DIRECTORY ' || v_directory_name ||
                        ' AS ''' || p_directory || '''';
    ------
    BEGIN
      EXECUTE IMMEDIATE v_sql_statement;
      message('Directory ' || v_directory_name ||
              ' was created/replaced successfully for p_directory=' ||
              p_directory);
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
  
    --- Execute PRE_RUN_SQL (for example apps_initialize...)
    v_step := 'Step 35';
    IF v_setup_rec.pre_run_sql IS NOT NULL THEN
      message('PRE_RUN_SQL :');
      message(v_setup_rec.pre_run_sql);
      ------
      BEGIN
        EXECUTE IMMEDIATE v_setup_rec.pre_run_sql;
        message('PRE_RUN_SQL was completed successfully');
      EXCEPTION
        WHEN OTHERS THEN
          ---Error----
          v_error_messsage := substr('PRE_RUN_SQL Error: ' || SQLERRM,
                                     1,
                                     200);
          RAISE stop_processing;
      END;
      ------
    END IF;
  
    v_step := 'Step 60';
    --------
    BEGIN
      INSERT INTO xxobjt_interface_file_log
        (file_id,
         file_name,
         row_count,
         file_directory,
         bpel_instance_id,
         status,
         transfer_date,
         SOURCE,
         program_request_id,
         last_update_date,
         last_updated_by,
         creation_date,
         created_by)
      VALUES
        (v_file_id,
         v_file_name,
         NULL, ---ROW_COUNT,
         p_directory,
         NULL, ---BPEL_INTANCE_ID,
         'P', ---STATUS,
         NULL, ---TRANSFER_DATE,
         v_setup_rec.source_code, ---SOURCE,
         v_concurrent_request_id,
         SYSDATE, ---LAST_UPDATE_DATE,
         fnd_global.user_id, ---LAST_UPDATED_BY,
         SYSDATE, ---CREATION_DATE,
         fnd_global.user_id ---CREATED_BY
         );
    
      COMMIT;
      message('1 record inserted into table XXOBJT_INTERFACE_FILE_LOG for file_id=' ||
              v_file_id);
    EXCEPTION
      WHEN OTHERS THEN
        v_error_messsage := 'Error when insert into XXOBJT_FILE_LOG: ' ||
                            SQLERRM;
        RAISE stop_processing;
    END;
    ---------
  
    v_step := 'Step 70';
    -- Create new Context for the Query
    message('Query=' || v_setup_rec.query_select);
    v_query_context := dbms_xmlgen.newcontext(v_setup_rec.query_select);
    message('Query Context was created for this query');
  
    v_step := 'Step 80';
    -- Set Query Parameters---- PARAM1, PARAM2, PARAM3, PARAM4, PARAM5, PARAM6
    v_setup_rec.param1 := nvl(p_param1, v_setup_rec.param1);
    v_setup_rec.param2 := nvl(p_param2, v_setup_rec.param2);
    v_setup_rec.param3 := nvl(p_param3, v_setup_rec.param3);
    v_setup_rec.param4 := nvl(p_param4, v_setup_rec.param4);
    v_setup_rec.param5 := nvl(p_param5, v_setup_rec.param5);
    v_setup_rec.param6 := nvl(p_param6, v_setup_rec.param6);
    IF v_setup_rec.param1 IS NOT NULL THEN
      dbms_xmlgen.setbindvalue(v_query_context,
                               'PARAM1',
                               v_setup_rec.param1);
      message('Set Bind Value PARAM1=' || v_setup_rec.param1);
    END IF;
    IF v_setup_rec.param2 IS NOT NULL THEN
      dbms_xmlgen.setbindvalue(v_query_context,
                               'PARAM2',
                               v_setup_rec.param2);
      message('Set Bind Value PARAM2=' || v_setup_rec.param2);
    END IF;
    IF v_setup_rec.param3 IS NOT NULL THEN
      dbms_xmlgen.setbindvalue(v_query_context,
                               'PARAM3',
                               v_setup_rec.param3);
      message('Set Bind Value PARAM3=' || v_setup_rec.param3);
    END IF;
    IF v_setup_rec.param4 IS NOT NULL THEN
      dbms_xmlgen.setbindvalue(v_query_context,
                               'PARAM4',
                               v_setup_rec.param4);
      message('Set Bind Value PARAM4=' || v_setup_rec.param4);
    END IF;
    IF v_setup_rec.param5 IS NOT NULL THEN
      dbms_xmlgen.setbindvalue(v_query_context,
                               'PARAM5',
                               v_setup_rec.param5);
      message('Set Bind Value PARAM5=' || v_setup_rec.param5);
    END IF;
    IF v_setup_rec.param6 IS NOT NULL THEN
      dbms_xmlgen.setbindvalue(v_query_context,
                               'PARAM6',
                               v_setup_rec.param6);
      message('Set Bind Value PARAM6=' || v_setup_rec.param6);
    END IF;
  
    v_step := 'Step 90';
    -- Special characters in the XML data must be converted into their escaped XML equivalent.
    ----------For example, the < sign is converted to     exit SQL.SQLCODE;
    dbms_xmlgen.setconvertspecialchars(v_query_context, TRUE);
    message('Special characters in the XML data will be converted into their escaped XML equivalent*****************');
  
    v_step := 'Step 100';
    -- Set Parent and Child Node
    dbms_xmlgen.setrowsettag(v_query_context, v_setup_rec.root_tag);
    dbms_xmlgen.setrowtag(v_query_context, v_setup_rec.row_tag);
  
    v_step := 'Step 110';
    -- setNullHandling to show Tag also when the value is NULL
    /*  DROP_NULLS CONSTANT NUMBER:= 0; (Default) Leaves out the tag for NULL elements.
    NULL_ATTR CONSTANT NUMBER:= 1; Sets xsi:nil="true".
    EMPTY_TAG CONSTANT NUMBER:= 2; Sets, for example, <foo/>.*/
  
    IF nvl(v_setup_rec.hide_empty_tag, 'N') = 'Y' THEN
      v_step := 'Step 120';
      dbms_xmlgen.setnullhandling(v_query_context, dbms_xmlgen.drop_nulls);
      message('Set dbms_xmlgen.drop_nulls');
    ELSE
      dbms_xmlgen.setnullhandling(v_query_context, dbms_xmlgen.empty_tag);
      message('Set dbms_xmlgen.empty_tag');
    END IF;
  
    v_step := 'Step 130';
    -- getXML in CLOB
    BEGIN
      v_xml := dbms_xmlgen.getxml(v_query_context);
    EXCEPTION
      WHEN OTHERS THEN
        v_error_messsage := 'Invalid sql statement in XXOBJT_XML_GEN.QUERY_SELECT - ' ||
                            SQLERRM;
        RAISE stop_processing;
    END;
    --------
  
    v_step := 'Step 140';
    -- Put encoding to the "Header"
    v_xml := REPLACE(v_xml,
                     '<?xml version="1.0"?>',
                     '<?xml version="1.0" encoding="utf-8" ?>');
  
    v_step                := 'Step 150';
    v_num_of_rows_fetched := nvl(dbms_xmlgen.getnumrowsprocessed(v_query_context),
                                 0);
    message(v_num_of_rows_fetched ||
            ' rows fetched from your query *****************');
  
    v_step := 'Step 160';
    -- Close Context
    dbms_xmlgen.closecontext(v_query_context);
  
    v_step := 'Step 170';
    -- Write the CLOB to a file on the server
  
    --
    IF v_xml IS NOT NULL THEN
    
      dbms_xslprocessor.clob2file(v_xml,
                                  v_directory_name,
                                  ---'Example2.xml');
                                  v_file_name || '.tmp'); -- CHG0032515
      -- CHG0032515
      utl_file.frename(v_directory_name,
                       v_file_name || '.tmp',
                       v_directory_name,
                       v_file_name,
                       TRUE);
    END IF;
  
    v_step := 'Step 300';
    -------- update file  status
  
    update_log(p_file_id   => v_file_id,
               p_status    => 'F',
               p_row_count => nvl(v_num_of_rows_fetched, 0));
  
    ---------
    p_file_id := v_file_id;
    message('THE PROGRAM WAS SUCCESSFULLY COMPLETED =============================');
  
  EXCEPTION
    WHEN stop_processing THEN
      IF v_file_id IS NOT NULL THEN
        -------
        BEGIN
          update_log(p_file_id => v_file_id, p_status => 'F');
        
        EXCEPTION
          WHEN OTHERS THEN
            NULL;
        END;
        ------
      END IF;
      v_error_messsage := 'ERROR in xxobjt_xml_gen_pkg.create_xml_file: ' ||
                          v_error_messsage;
      message(v_error_messsage);
      retcode := '2';
      errbuf  := v_error_messsage;
    WHEN OTHERS THEN
      v_error_messsage := substr('Unexpected ERROR in xxobjt_xml_gen_pkg.create_xml_file (' ||
                                 v_step || ') ' || SQLERRM,
                                 1,
                                 200);
      IF v_file_id IS NOT NULL THEN
        -------
        BEGIN
        
          update_log(p_file_id => v_file_id,
                     p_status  => 'E',
                     p_message => v_error_messsage);
        
        EXCEPTION
          WHEN OTHERS THEN
            NULL;
        END;
        ------
      END IF;
      message(v_error_messsage);
      retcode := '2';
      errbuf  := v_error_messsage;
    
  END;
  -----------------------------------------------------------------
  -- create_xml_file
  ----------------------------------------------------------------
  -- Purpose: CUST-751 - Generic xml file generation (CR1047)
  -----------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------------------
  --     1.0  24.9.13   Vitaly         initial build
  -----------------------------------------------------------------
  PROCEDURE create_xml_file(errbuf             OUT VARCHAR2,
                            retcode            OUT VARCHAR2,
                            p_file_code        IN VARCHAR2,
                            p_directory        IN VARCHAR2, ---'/UtlFiles/shared/DEV/SH' ---( \\objet-data\Oracle_Files\shared\DEV\SH)
                            p_file_name_prefix IN VARCHAR2,
                            p_param1           IN VARCHAR2,
                            p_param2           IN VARCHAR2,
                            p_param3           IN VARCHAR2,
                            p_param4           IN VARCHAR2,
                            p_param5           IN VARCHAR2,
                            p_param6           IN VARCHAR2) IS
  
    l_file_id NUMBER;
  BEGIN
    create_xml_file(errbuf             => errbuf,
                    retcode            => retcode,
                    p_file_id          => l_file_id,
                    p_file_code        => p_file_code,
                    p_directory        => p_directory,
                    p_file_name_prefix => p_file_name_prefix,
                    p_param1           => p_param1,
                    p_param2           => p_param2,
                    p_param3           => p_param3,
                    p_param4           => p_param4,
                    p_param5           => p_param5,
                    p_param6           => p_param6);
  
  END create_xml_file;

  -----------------------------------------------------------------
  -- update_log
  ------------------------------------------------------------------
  -- Purpose: CUST-751 - Generic xml file generation (CR1047)
  ------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ----------------------------
  --     1.0  24.9.13   Vitaly         initial build
  ------------------------------------------------------------------
  PROCEDURE update_log(p_file_id   NUMBER,
                       p_status    VARCHAR2,
                       p_row_count NUMBER DEFAULT NULL,
                       p_message   VARCHAR2 DEFAULT NULL) IS
  BEGIN
    UPDATE xxobjt_interface_file_log t
       SET row_count        = nvl(row_count, p_row_count),
           status           = p_status,
           last_update_date = SYSDATE,
           last_updated_by  = fnd_global.user_id,
           t.error_message  = nvl(p_message, t.error_message)
    
     WHERE file_id = p_file_id;
    COMMIT;
  
  END;

  -----------------------------------------------------------------
  -- update_log
  ------------------------------------------------------------------
  -- Purpose: CUST-751 - Generic xml file generation (CR1047)
  ------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ----------------------------
  --     1.0  24.9.13   Vitaly         initial build
  ------------------------------------------------------------------
  PROCEDURE update_log(p_file_name        VARCHAR2,
                       p_status           VARCHAR2,
                       p_row_count        NUMBER DEFAULT NULL,
                       p_row_count_verify NUMBER DEFAULT NULL,
                       p_message          VARCHAR2 DEFAULT NULL,
                       p_err_code         OUT NUMBER,
                       p_err_message      OUT VARCHAR2) IS
    l_count   NUMBER;
    l_message xxobjt_interface_file_log.error_message%TYPE;
    l_status  xxobjt_interface_file_log.status%TYPE;
  BEGIN
    l_message  := p_message;
    p_err_code := 0;
    l_status   := p_status;
    IF p_row_count_verify IS NOT NULL THEN
      SELECT row_count
        INTO l_count
        FROM xxobjt_interface_file_log
       WHERE file_name = p_file_name;
    
      IF p_row_count_verify != l_count THEN
        l_message := 'Acknowledge Failed';
        l_status  := 'E';
      END IF;
    END IF;
  
    UPDATE xxobjt_interface_file_log t
       SET row_count        = nvl(row_count, p_row_count),
           row_count_verify = nvl(row_count_verify, p_row_count_verify),
           status           = l_status,
           last_update_date = SYSDATE,
           last_updated_by  = fnd_global.user_id,
           t.error_message  = nvl(l_message, t.error_message),
           t.transfer_date  = decode(l_status, 'T', SYSDATE, transfer_date)
    
     WHERE file_name = p_file_name;
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      p_err_code    := 1;
      p_err_message := SQLERRM;
  END;
END xxobjt_xml_gen_pkg;
/
