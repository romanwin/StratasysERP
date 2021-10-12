CREATE OR REPLACE PACKAGE BODY xxfnd_attachments_util_pkg IS
  -------------------------------------------------------------------------------------------
  -- Ver     When        Who         Description
  -- ------  ----------  ----------  --------------------------------------------------------
  -- 1.0     09/01/2019              CHG0044283 - init version
  --                                     concurrent : XX FND Archive2Filesystem
  -- 1.1     15/04/2019              CHG0044283 - remark : l_num := regexp_replace(regexp_replace(l_num, ' ', '_'),'[^-a-zA-Z0-9_]');
  -- 1.2     27/10/2019  Roman W     CHG0046750
  -- 1.3     24-11-2019  Roman W.    CHG0046750 -  added error 'ERROR(3.1) :Invalid Directory : ' || l_directory_sql;
  -------------------------------------------------------------------------------------------

  -------------------------------------------------------------------------------------------
  -- Ver     When        Who         Description
  -- ------  ----------  ----------  --------------------------------------------------------
  -- 1.0     09/01/2019               CHG0044283 - write message log
  -------------------------------------------------------------------------------------------
  PROCEDURE message(p_msg IN VARCHAR2) IS
    -------------------------------
    --       Code Section
    -------------------------------
  BEGIN
    IF fnd_global.conc_request_id > 0 THEN
      fnd_file.put_line(fnd_file.log,
                        to_char(SYSDATE, 'DD/MM/YYYY HH24:MI:SS') || ' - ' ||
                        p_msg);
    ELSE
      dbms_output.put_line(to_char(SYSDATE, 'DD/MM/YYYY HH24:MI:SS') ||
                           ' - ' || p_msg);
    END IF;
  END message;

  -----------------------------------------------------------------------------------
  -- Ver    When          Who           Description
  -- -----  ------------  ------------  ------------------------------------------
  -- 1.0    09/01/2019    Roman W.      CHG0044283
  -----------------------------------------------------------------------------------
  PROCEDURE get_directory_path(p_org_id         IN VARCHAR2,
                               p_table_name     IN VARCHAR2,
                               p_directory_path OUT VARCHAR2,
                               p_error_code     OUT VARCHAR2,
                               p_error_desc     OUT VARCHAR2) IS
    --------------------------------
    --      Local Definition
    --------------------------------
    l_directory_path VARCHAR2(500);
    l_year           VARCHAR2(30);
    --------------------------------
    --      Code Section
    --------------------------------
  BEGIN
    p_error_code := '0';
    p_error_desc := NULL;

    SELECT ffvv.attribute3 directory_path
      INTO l_directory_path
      FROM fnd_flex_value_sets ffvs, fnd_flex_values_vl ffvv
     WHERE ffvs.flex_value_set_name = 'XXFNDARC2FS_PATH_BY_ORGID'
       AND ffvv.flex_value_set_id = ffvs.flex_value_set_id
       AND trunc(SYSDATE) BETWEEN
           nvl(ffvv.start_date_active, trunc(SYSDATE)) AND
           nvl(ffvv.end_date_active, trunc(SYSDATE))
       AND ffvv.enabled_flag = 'Y'
       AND ffvv.flex_value = p_org_id;

    -- Get Year --
    SELECT to_char(SYSDATE, 'YYYY') INTO l_year FROM dual;

    p_directory_path := l_directory_path || '/' || l_year || '/' ||
                        p_table_name;

  EXCEPTION
    WHEN no_data_found THEN
      p_directory_path := NULL;
      p_error_code     := '2';
      p_error_desc     := 'EXCEPTION_NO_DATA_FOUND XXFND_ATTACHMENTS_UTIL_PKG.get_directory_path(' ||
                          p_org_id || ',' || p_table_name ||
                          ') - missing setup in ValueSet : "XXFNDARC2FS_PATH_BY_ORGID"';

    WHEN OTHERS THEN
      p_directory_path := NULL;
      p_error_code     := '2';
      p_error_desc     := 'EXCEPTION_OTHERS XXFND_ATTACHMENTS_UTIL_PKG.get_directory_path(' ||
                          p_org_id || ',' || p_table_name || ') - ' ||
                          substr(SQLERRM, 1, 2000);

  END get_directory_path;

  -----------------------------------------------------------------------------------
  -- Ver    When          Who           Description
  -- -----  ------------  ------------  ------------------------------------------
  -- 1.0    09/01/2019    Roman W.      CHG0044283
  -- 1.1    24/02/2019    Roman W.
  -----------------------------------------------------------------------------------
  PROCEDURE archive2file_system_gen(p_directory       IN VARCHAR2,
                                    p_entity_name     IN VARCHAR2,
                                    p_category        IN VARCHAR2,
                                    p_pk1_value       IN VARCHAR2,
                                    p_pk2_value       IN VARCHAR2,
                                    p_pk_number       IN VARCHAR2,
                                    p_total_size_flag IN VARCHAR2,
                                    p_total_size      OUT NUMBER,
                                    errbuf            OUT VARCHAR2,
                                    retcode           OUT NUMBER) IS
    -------------------------------
    --     local definition
    -------------------------------
    CURSOR attch_cur(c_entity_name   VARCHAR2,
                     c_category_name VARCHAR2,
                     c_pk1_value     VARCHAR2,
                     c_pk2_value     VARCHAR2,
                     c_pk_number     VARCHAR2) IS
      SELECT f.file_data,
             c_pk_number || '_' || f.file_id ||
             REVERSE(substr(REVERSE(f.file_name),
                            1,
                            instr(REVERSE(f.file_name), '.'))) file_name,
             round(dbms_lob.getlength(f.file_data) / 1024) file_size_kb
        FROM fnd_document_datatypes     dat,
             fnd_document_entities_tl   det,
             fnd_documents_tl           dt,
             fnd_documents              d,
             fnd_document_categories_tl dct,
             fnd_attached_documents     ad,
             fnd_lobs                   f
       WHERE ad.entity_name = c_entity_name
         AND ad.pk1_value = c_pk1_value
         AND dct.name = nvl(c_category_name, dct.name)
         AND f.file_id = d.media_id
         AND d.document_id = ad.document_id
         AND dt.document_id = d.document_id
         AND dt.language = 'US'
         AND dct.category_id = d.category_id
         AND dct.language = 'US'
         AND d.datatype_id = dat.datatype_id
         AND dat.language = 'US'
         AND ad.entity_name = det.data_object_code
         AND det.language = 'US'
         AND d.datatype_id = 6;

    -------------------------------
    --       Code Section
    -------------------------------
  BEGIN
    errbuf       := NULL;
    retcode      := 0;
    p_total_size := 0;
    FOR attch_ind IN attch_cur(p_entity_name,
                               p_category,
                               p_pk1_value,
                               p_pk2_value,
                               p_pk_number) LOOP

      IF 'Y' = p_total_size_flag THEN
        p_total_size := p_total_size + attch_ind.file_size_kb;
      ELSE
        NULL;

        xxssys_file_util_pkg.save_blob_to_file(p_directory_name => p_directory,
                                               p_file_name      => attch_ind.file_name,
                                               p_blob           => attch_ind.file_data);

      END IF;

    END LOOP;

  EXCEPTION
    WHEN OTHERS THEN
      retcode := 2;
      errbuf  := substr('EXCEPTION_OTHERS XXFND_ATTACHMENTS_UTIL_PKG.archive2file_system_gen(' ||
                        p_directory || ',' || p_entity_name || ',' ||
                        p_category || ',' || p_pk1_value || ',' ||
                        p_pk2_value || ',' || p_pk_number || ') - ' ||
                        SQLERRM,
                        1,
                        2000);
  END archive2file_system_gen;
  -------------------------------------------------------------------------------------------
  -- Ver     When        Who         Description
  -- ------  ----------  ----------  --------------------------------------------------------
  -- 1.0     09/01/2019              CHG0044283 - Concurrent "XX FND Archive2Filesystem/XXFNDARC2FS"
  -- 1.1     11/02/2019              CHG0044283 - add total size calculation
  -- 1.2     24/03/2019              CHG0044283 - remark : l_num := regexp_replace(regexp_replace(l_num, ' ', '_'),'[^-a-zA-Z0-9_]');
  -- 1.3     15/04/2019              CHG0044283 - remark : l_num := regexp_replace(regexp_replace(l_num, ' ', '_'),'[^-a-zA-Z0-9_]');
  -------------------------------------------------------------------------------------------
  PROCEDURE archive2file_system_main(errbuf                OUT VARCHAR2,
                                     retcode               OUT NUMBER,
                                     p_org_id              IN NUMBER,
                                     p_entity              IN VARCHAR2,
                                     p_date_from           IN VARCHAR2,
                                     p_date_to             IN VARCHAR2,
                                     p_creation_date_setup IN VARCHAR2 -- XXFND_CREATION_DATE_OR_SETUP_VS :
                                     ) IS
    -------------------------------
    --     local definition
    -------------------------------
    l_select VARCHAR2(2000);
    l_tables VARCHAR2(2000);
    l_where  VARCHAR2(2000);

    l_table_name         VARCHAR2(300);
    l_pk1                VARCHAR2(300);
    l_category_name      VARCHAR2(300);
    l_docuent_number_col VARCHAR2(300);
    l_dates_col          VARCHAR2(300);
    l_sql                VARCHAR2(2000);

    TYPE cur IS REF CURSOR;
    v_main_cur       cur;
    l_pk             NUMBER;
    l_num            VARCHAR2(300);
    l_size           NUMBER;
    l_total_size     NUMBER;
    l_max_total_size NUMBER;
    l_date_from      DATE;
    l_date_to        DATE;
    l_directory_path VARCHAR2(2000);
    l_count          NUMBER;
    -------------------------------
    --       Code Section
    -------------------------------
  BEGIN
    errbuf       := NULL;
    retcode      := 0;
    l_total_size := 0;

    message('Concurrent Parameters : ');
    -- add print parameters in
    message('p_org_id : ' || p_org_id);
    message('p_entity : ' || p_entity);
    message('p_from_date : ' || p_date_from);
    message('p_to_date : ' || p_date_to);
    message('p_creation_date_setup: ' || p_creation_date_setup);

    l_date_from := fnd_conc_date.string_to_date(p_date_from);
    l_date_to   := fnd_conc_date.string_to_date(p_date_from);
    ------ Calculation max total size -------
    BEGIN
      l_max_total_size := to_number(fnd_profile.value('XXFND_ATTACHMENTS_MAX_TOTAL_SIZE_KB'));

      IF l_max_total_size IS NULL THEN
        errbuf  := 'profile XXFND_ATTACHMENTS_MAX_TOTAL_SIZE_KB value can''t be null';
        retcode := 2;
        message(errbuf);
        RETURN;
      END IF;
    EXCEPTION
      WHEN OTHERS THEN
        errbuf  := 'Value in profile XXFND_ATTACHMENTS_MAX_TOTAL_SIZE_KB should be numeric';
        retcode := 2;
        message(errbuf);
        RETURN;
    END;

    message('creating directory end');
    IF retcode = 0 THEN
      message('creating dynamic query start');
      BEGIN
        SELECT fv.attribute4 table_name,
               fv.attribute1 pk1,
               fv.attribute2 category_name,
               fv.attribute3 docuent_number,
               fv.attribute5 l_dates_col
          INTO l_table_name,
               l_pk1,
               l_category_name,
               l_docuent_number_col,
               l_dates_col
          FROM fnd_flex_value_sets fvs, fnd_flex_values_vl fv
         WHERE fvs.flex_value_set_name = 'XX_MASS_DOWLOAD_ENTITIES'
           AND fv.flex_value_set_id = fvs.flex_value_set_id
           AND fv.flex_value = p_entity; --'AP_INVOICES';

        IF 'CREATION_DATE' = p_creation_date_setup THEN
          l_dates_col := 'CREATION_DATE';
        END IF;

        --creating dynamic query
        l_select := chr(10) || 'with dates as( ' || chr(10) ||
                    ' select trunc(fnd_conc_date.string_to_date(:p_date_from)) date_from, ' ||
                    chr(10) ||
                    ' trunc(fnd_conc_date.string_to_date(:p_date_to)) date_to ' ||
                    chr(10) || '  from dual ' || ' ) ' || chr(10) ||
                    'SELECT TN.' || l_pk1 || chr(10) || ' PK1' || ', TN.' ||
                    l_docuent_number_col || ' OBJ_NUM' || chr(10);
        l_tables := ' FROM ' || l_table_name || ' TN , dates' || chr(10);
        l_where  := ' WHERE trunc( TN.' || l_dates_col || ')' || chr(10) ||
                   --                    ' BETWEEN trunc(fnd_conc_date.STRING_TO_DATE( :p_date_from )) and trunc(fnd_conc_date.STRING_TO_DATE( :p_date_to ))' ||
                    ' BETWEEN dates.date_from  and dates.date_to' ||
                    chr(10) || ' AND TN.ORG_ID = ' || ':p_org_id' ||
                    chr(10);

        l_sql := l_select || l_tables || l_where;
        message('');
        message('============================================================================');
        message('==                            S Q L                                       ==');
        message('============================================================================');
        message(l_sql);
        message('============================================================================');
      EXCEPTION
        WHEN OTHERS THEN
          retcode := 2;
          errbuf  := substr('EXCEPTION XXFND_ATTACHMENTS_UTIL_PKG.archive2file_system_main() - error creating dynamic query' ||
                            SQLERRM,
                            1,
                            2000);
          RETURN;
      END;
      message('creating dynamic query end');

      --------------------------------------
      ------- Get directory path -----------
      --------------------------------------
      get_directory_path(p_org_id         => p_org_id,
                         p_table_name     => l_table_name,
                         p_directory_path => l_directory_path,
                         p_error_code     => retcode,
                         p_error_desc     => errbuf);

      IF '0' != retcode THEN
        RETURN;
      ELSE
        message('');
        message('======================================================================================');
        message('==                       F i l e s   L o c a t i o n                                ==');
        message('======================================================================================');
        message('==  ' || l_directory_path || '  ==');
        message('======================================================================================');
      END IF;

      --------------------------------------
      ------- Creating directory -----------
      --------------------------------------
      BEGIN
        EXECUTE IMMEDIATE 'CREATE OR REPLACE DIRECTORY XXFNDARCDIR_' ||
                          p_org_id || ' AS ''' || l_directory_path || '''';
      EXCEPTION
        WHEN OTHERS THEN
          retcode := 1;
          errbuf  := substr('EXCEPTION XXFND_ATTACHMENTS_UTIL_PKG.archive2file_system_main() - failed to create directory: ' ||
                            'XXFNDARCDIR_' || p_org_id || '. ' || SQLERRM,
                            1,
                            2000);
      END;

      -------------------------------------------
      ---------- Calculate total size -----------
      -------------------------------------------
      l_count := 0;
      OPEN v_main_cur FOR l_sql
        USING p_date_from, p_date_to, p_org_id;

      message(chr(10) || '%ROWCOUNT : ' || v_main_cur%ROWCOUNT);
      LOOP
        FETCH v_main_cur
          INTO l_pk, l_num;
        EXIT WHEN v_main_cur%NOTFOUND;

        --l_num := regexp_replace(regexp_replace(l_num, ' ', '_'), '[^-a-zA-Z0-9_]'); -- 1.2
        l_num := REPLACE(l_num, '\', '_');
        l_num := REPLACE(l_num, '/', '_');

        xxfnd_attachments_util_pkg.archive2file_system_gen(p_directory       => 'XXFNDARCDIR_' ||
                                                                                p_org_id,
                                                           p_entity_name     => p_entity,
                                                           p_category        => l_category_name,
                                                           p_pk1_value       => l_pk,
                                                           p_pk2_value       => NULL,
                                                           p_pk_number       => l_num,
                                                           p_total_size_flag => 'Y',
                                                           p_total_size      => l_size,
                                                           errbuf            => errbuf,
                                                           retcode           => retcode);
        -- handling on parameters out
        l_total_size := l_total_size + l_size;

        l_count := l_count + 1;

      END LOOP;

      CLOSE v_main_cur;

      ------- End total size calculation -------
      message('');
      message('=========================================');
      message('TOTAL SIZE       : ' || l_total_size || ' KB');
      message('TOTAL FILE COUNT : ' || l_count);
      message('=========================================');

      --- Checking attachments total size
      IF l_total_size > l_max_total_size THEN

        errbuf  := 'Attachments total size exceeds alowable size, Choice a shorter period';
        retcode := 2;
        message(errbuf);
        RETURN;

      END IF;

      -------------------------------------------------------------
      ---------- Calculate archive files to file system -----------
      -------------------------------------------------------------

      message(chr(10) || '=========================================');
      message('      archive file to filesystem');
      message('=========================================');
      message(l_sql);
      OPEN v_main_cur FOR l_sql
        USING p_date_from, p_date_to, p_org_id;

      LOOP
        FETCH v_main_cur
          INTO l_pk, l_num;
        EXIT WHEN v_main_cur%NOTFOUND;

        message('l_pk: ' || l_pk);
        message('l_num: ' || l_num);

        --        l_num := regexp_replace(regexp_replace(l_num, ' ', '_'), '[^-a-zA-Z0-9_]');
        l_num := REPLACE(l_num, '\', '_');
        l_num := REPLACE(l_num, '/', '_');

        xxfnd_attachments_util_pkg.archive2file_system_gen(p_directory       => 'XXFNDARCDIR_' ||
                                                                                p_org_id,
                                                           p_entity_name     => p_entity,
                                                           p_category        => l_category_name,
                                                           p_pk1_value       => l_pk,
                                                           p_pk2_value       => NULL,
                                                           p_pk_number       => l_num,
                                                           p_total_size_flag => 'N',
                                                           p_total_size      => l_size,
                                                           errbuf            => errbuf,
                                                           retcode           => retcode);

      END LOOP;
      CLOSE v_main_cur;
    END IF; --<if retcode=0>
  EXCEPTION
    WHEN OTHERS THEN
      CLOSE v_main_cur;
      retcode := 2;
      errbuf  := substr('EXCEPTION_OTHERS XXFND_ATTACHMENTS_UTIL_PKG.archive2file_system_main() - ' ||
                        SQLERRM,
                        1,
                        2000);

  END archive2file_system_main;
  -------------------------------------------------------------------------------------------
  -- Ver   When          Who        Descr
  -- ----  ------------  ---------  --------------------------------------------------------------
  -- 1.0   27/10/2019    Roman W.   CHG0046750
  -- 1.1   10/11/2019    Roman W.   CHG0046750
  -------------------------------------------------------------------------------------------
  PROCEDURE is_directory_valid(p_directory  IN VARCHAR2,
                               p_valid_flag OUT VARCHAR2,
                               p_error_code OUT VARCHAR2,
                               p_error_desc OUT VARCHAR2) IS
    l_count NUMBER;
  BEGIN
    p_error_code := '0';
    p_error_desc := NULL;

    l_count := dbms_lob.fileexists(bfilename(p_directory, '.'));

    IF (l_count = 0) THEN
      p_valid_flag := 'N';
    ELSE
      p_valid_flag := 'Y';
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      p_error_code := '2';
      p_error_desc := 'EXCEPTION_OTHERS XXFND_ATTACHMENTS_UTIL_PKG.is_directory_valid(' ||
                      p_directory || ') - ' || SQLERRM;
  END is_directory_valid;

  -------------------------------------------------------------------------------------------
  -- Ver     When        Who         Description
  -- ------  ----------  ----------  --------------------------------------------------------
  -- 1.0     27/10/2019  Roman W     CHG0046750
  -- 1.1     11/11/2019  Roman W     CHG0046750 -  and 1 = (select count(*)
  --                                                        from xxobjt_fnd_file_documents_v xffd
  --                                                       where xffd.document_id = t.document_id);
  -- 1.2     24-11-2019  Roman W.    CHG0046750 -  added error 'ERROR(3.1) :Invalid Directory : ' || l_directory_sql;
  --------------------------------------------------------------------------------------------
  PROCEDURE attachment2archive(errbuf        OUT VARCHAR2,
                               retcode       OUT NUMBER,
                               p_entity_name IN VARCHAR2,
                               p_max_rows    IN VARCHAR2) IS
    ---------------------------------
    --    Local Definition
    ---------------------------------

    -- serach for distinct path from temp folder
    CURSOR c_arc_path IS
      SELECT xat.arc_path
        FROM xxssys_attachment2archive xat
       GROUP BY xat.arc_path;
    -- fetch relevnt files for folder
    CURSOR c_attachments(c_arc_path VARCHAR2) IS
      SELECT document_id,
             xat.arc_path,
             xat.file_id,
             xat.arc_file_name,
             xat.file_name,
             xat.file_data
        FROM xxssys_attachment2archive xat
       WHERE 1 = 1
         AND xat.arc_path = c_arc_path;

    c_directory CONSTANT VARCHAR2(120) := 'XXFND_ATTACHMENT2ARCHIVE';

    l_error_code           VARCHAR2(10);
    l_error_desc           VARCHAR2(2000);
    l_directory_valid_flag VARCHAR2(10);
    l_request_id           NUMBER;

    l_phase             VARCHAR2(100);
    l_status            VARCHAR2(100);
    l_dev_phase         VARCHAR2(100);
    l_dev_status        VARCHAR2(100);
    l_message           VARCHAR2(100);
    l_req_return_status BOOLEAN;
    l_file_name         VARCHAR2(500);
    l_file_data         BLOB;
    l_directory_sql     VARCHAR2(2000);
    l_insert_sql        VARCHAR2(2000);
    l_directory_path    VARCHAR2(2000);
    ---------------------------------
    --    Code Section
    ---------------------------------
  BEGIN
    errbuf  := NULL;
    retcode := '0';

    message('Delete data from XXOBJT.XXSSYS_ATTACHMENT2ARCHIVE');

    DELETE FROM xxssys_attachment2archive;
    COMMIT;

    message('insert data to XXOBJT.XXSSYS_ATTACHMENT2ARCHIVE');
    INSERT INTO xxobjt.xxssys_attachment2archive
      (document_id, file_name, file_data, arc_path, file_id, arc_file_name)
      SELECT t.document_id,
             t.file_name,
             t.file_data,
             t.arc_path,
             t.file_id,
             t.arc_file_name
        FROM xxobjt_fnd_file_documents_v    t,
             xxobjt_fnd_attachments_rules_v r
       WHERE r.entity_name = nvl(p_entity_name, r.entity_name)
         AND t.creation_date < SYSDATE - r.max_days
         AND r.entity_name = t.entity_name
         AND t.category_id = nvl(r.category_id, t.category_id)
         AND dbms_lob.getlength(t.file_data) > r.from_size_byte
         AND rownum <= p_max_rows
         AND t.dyn_condition = 1
         and 1 = (select count(*)
                    from xxobjt_fnd_file_documents_v xffd
                   where xffd.document_id = t.document_id);

    message(SQL%ROWCOUNT ||
            ' records inserted into XXOBJT.XXSSYS_ATTACHMENT2ARCHIVE');

    COMMIT;

    -----------------------------------------------
    -- create file directories
    -----------------------------------------------

    FOR arc_path_ind IN c_arc_path LOOP

      message('check directory exists: ' || arc_path_ind.arc_path);

      xxobjt_fnd_attachments.create_oracle_dir(p_name => c_directory,
                                               p_dir  => arc_path_ind.arc_path);

      COMMIT;

      is_directory_valid(p_directory  => c_directory,
                         p_valid_flag => l_directory_valid_flag,
                         p_error_code => l_error_code,
                         p_error_desc => l_error_desc);

      IF '0' != l_error_code THEN
        errbuf  := '2';
        retcode := l_error_desc;
        message('ERROR(1) :' || retcode);
        continue;
      END IF;

      -------------------------------------------------------------
      --            Create file directory
      -------------------------------------------------------------
      IF 'Y' != l_directory_valid_flag THEN

        l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                                   program     => 'XXFNDMKDIR',
                                                   description => '',
                                                   start_time  => '',
                                                   sub_request => FALSE,
                                                   argument1   => arc_path_ind.arc_path);

        COMMIT;

        message(l_request_id || ' : ' || arc_path_ind.arc_path);

        l_req_return_status := fnd_concurrent.wait_for_request(request_id => l_request_id,
                                                               INTERVAL   => 5,
                                                               max_wait   => 0,
                                                               phase      => l_phase,
                                                               status     => l_status,
                                                               dev_phase  => l_dev_phase,
                                                               dev_status => l_dev_status,
                                                               message    => l_message);

        IF upper(l_phase) = 'COMPLETED' AND upper(l_status) = 'ERROR' THEN

          errbuf  := 'ERROR(2) : Concurrent (XX Fnd Mkdir - ' ||
                     l_request_id || ') complited with ERROR';
          retcode := '2';

          message(errbuf);

          CONTINUE;

        END IF;

        xxobjt_fnd_attachments.create_oracle_dir(p_name => c_directory,
                                                 p_dir  => arc_path_ind.arc_path);

        is_directory_valid(p_directory  => c_directory,
                           p_valid_flag => l_directory_valid_flag,
                           p_error_code => l_error_code,
                           p_error_desc => l_error_desc);

        IF '0' != l_error_code THEN
          retcode := '2';
          errbuf  := 'ERROR(3) :' || l_error_desc;
          message(errbuf);
          CONTINUE;
        END IF;

        IF 'Y' != l_directory_valid_flag THEN
          retcode := '2';
          errbuf  := 'ERROR(3.1) :Invalid Directory : ' || l_directory_sql;
          message(errbuf);
          CONTINUE;
        END IF;

      END IF;

      --------------------------------------
      -- download files to folder
      ---------------------------------------
      FOR attachments_ind IN c_attachments(arc_path_ind.arc_path) LOOP

        BEGIN

          message('process file =' || attachments_ind.arc_file_name ||
                  ' document_id=' || attachments_ind.document_id);

          IF 'Y' = l_directory_valid_flag THEN

            xxssys_file_util_pkg.save_blob_to_file(p_directory_name => c_directory,
                                                   p_file_name      => attachments_ind.arc_file_name,
                                                   p_blob           => attachments_ind.file_data);

            message('check out SUCCESS :' || attachments_ind.arc_file_name || '/' ||
                    attachments_ind.document_id);
            --- delete old attachament and add link
            xxobjt_fnd_attachments.handle_file(errmsg          => l_error_desc,
                                               errcode         => l_error_code,
                                               p_file_arc_path => attachments_ind.arc_path,
                                               p_document_id   => attachments_ind.document_id);

            IF '0' != l_error_code THEN
              ROLLBACK;
              retcode := '2';
              errbuf  := 'ERROR(4) : xxobjt_fnd_attachments.handle_file(' ||
                         attachments_ind.arc_path || ' , ' ||
                         attachments_ind.document_id || ' ) - ' ||
                         l_error_desc;
              message(errbuf);
            ELSE
              COMMIT;
            END IF;

          ELSE

            message('ERROR(5) :Invalid Directory : ' || l_directory_sql);

          END IF;

        EXCEPTION
          WHEN OTHERS THEN
            retcode := 2;
            errbuf  := 'EXCEPTION_OTHERS_2 xxfnd_attachments_util_pkg.attachment2archive(' ||
                       p_entity_name || ',' || p_max_rows || ') , file : ' ||
                       arc_path_ind.arc_path || '/' ||
                       attachments_ind.file_name || ' . ' || SQLERRM;

            message(errbuf);
        END;

      END LOOP;

    END LOOP;

  EXCEPTION
    WHEN OTHERS THEN
      retcode := '2';
      errbuf  := 'EXCEPTION_OTHERS XXFND_ATTACHMENTS_UTIL_PKG.attachment2archive(' ||
                 p_entity_name || ',' || p_max_rows || ') - ' || SQLERRM;
      message(errbuf);
  END attachment2archive;

END xxfnd_attachments_util_pkg;
/
