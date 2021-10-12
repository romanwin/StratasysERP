CREATE OR REPLACE PACKAGE BODY XXSSYS_DPL_PKG is
  ---------------------------------------------------------------------------------
  -- Ver   When        Who           Description
  -- ----  ----------  ------------  ----------------------------------------------
  -- 1.0   11/01/2019  Roman W.      CHG0046921
  -- 1.1   05/05/2020  Roman W.      CHG0046921 added new function "replace_clob"
  -- 1.1   11/02/2021  Roman W.      CHG0049395 bugfix in "replace_clob"  
  ---------------------------------------------------------------------------------

  --------------------------------------------------------------------------
  -- Ver   When        Who           Description
  -- ----  ----------  ------------  ---------------------------------------
  -- 1.0   11/01/2019  Roman W.      CHG0046921
  --------------------------------------------------------------------------
  procedure message(p_msg in varchar2) is
    l_msg varchar(32676);
  
  begin
  
    l_msg := to_char(sysdate, 'DD/MM/YYYY HH24:MI:SS  ') || p_msg;
  
    if fnd_global.CONC_REQUEST_ID > 0 then
      fnd_file.put_line(fnd_file.LOG, l_msg);
    else
      dbms_output.put_line(l_msg);
    end if;
  
  end message;
  -------------------------------------------------------------------------------------
  -- Ver    When        Who             Descr
  -- ----  ----------  --------------  -----------------------------------------------
  -- 1.0   15/01/2019  Roman W.        CHG0046921
  -------------------------------------------------------------------------------------
  procedure update_dpl_line_status(p_dpl_header_id in NUMBER,
                                   p_dpl_line_id   in NUMBER,
                                   p_status        in VARCHAR2,
                                   p_dpl_err_msg   in VARCHAR2,
                                   p_error_code    out VARCHAR2,
                                   p_error_desc    out VARCHAR2) is
  
    ----------------------------
    --    Code Section
    ----------------------------
  begin
    p_error_code := '0';
    p_error_desc := null;
  
    update XXSSYS_DPL_LINES xdl
       set xdl.status = p_status, xdl.error_desc = p_dpl_err_msg
     where xdl.dpl_header_id = p_dpl_header_id
       and xdl.dpl_line_id = p_dpl_line_id;
  
    update XXSSYS_DPL_HEADERS xdh
       set xdh.dpl_status = p_status
     where xdh.dpl_header_id = p_dpl_header_id;
  
    commit;
  
  exception
    when others then
      p_error_code := '2';
      p_error_desc := 'EXCEPTION_OTHERS xxssys_dpl_pkg.update_dpl_line(' ||
                      p_dpl_header_id || ',' || p_dpl_line_id || ') - ' ||
                      sqlerrm;
    
      message(p_error_desc);
    
  end update_dpl_line_status;

  -------------------------------------------------------------------------------------
  -- Ver   When          Who              Description
  -- ----  ------------  ---------------  ---------------------------------------------
  -- 1.0   30/12/2019    Roman W.         CHG0046921 - Create automatically DPL folder
  -------------------------------------------------------------------------------------
  procedure wait_for_request(p_request_id in NUMBER,
                             p_error_code out varchar2,
                             p_error_desc out varchar2) is
    -----------------------------
    --    Local Definition
    -----------------------------
    l_complete   BOOLEAN;
    l_phase      VARCHAR2(300);
    l_status     VARCHAR2(300);
    l_dev_phase  VARCHAR2(300);
    l_dev_status VARCHAR2(300);
    l_message    VARCHAR2(300);
    -----------------------------
    --    Code Section
    -----------------------------
  begin
  
    p_error_code := '0';
    p_error_desc := null;
  
    l_complete := fnd_concurrent.wait_for_request(request_id => p_request_id,
                                                  interval   => 10,
                                                  max_wait   => 0,
                                                  phase      => l_phase,
                                                  status     => l_status,
                                                  dev_phase  => l_dev_phase,
                                                  dev_status => l_dev_status,
                                                  message    => l_message);
  
    if (l_dev_phase = 'COMPLETE' and l_dev_status != 'NORMAL') then
    
      p_error_code := 2;
    
      p_error_desc := 'Request ID: ' || p_request_id || CHR(10) ||
                      'Status    : ' || l_dev_status || CHR(10) ||
                      'Message   : ' || l_message;
    
      message('STATUS : ' || p_error_code || CHR(10) || p_error_desc);
    
    END IF;
  
  end wait_for_request;

  --------------------------------------------------------------------------
  -- Ver   When        Who           Description
  -- ----  ----------  ------------  ---------------------------------------
  -- 1.0   01/11/2019  Bellona.B     CHG0046921
  --------------------------------------------------------------------------
  function get_top_path(p_top in varchar2) RETURN VARCHAR2 is
    l_path varchar(4000);
  
  begin
    select value
      into l_path
      from (select value
              from apps.Fnd_Env_Context fec
             where VARIABLE_NAME = p_top
               and xxobjt_general_utils_pkg.am_i_in_production = 'Y'
               and instr(fec.value, 'PROD') > 0
               and rownum = 1
            union all
            select value
              from apps.Fnd_Env_Context fec
             where VARIABLE_NAME = p_top
               and xxobjt_general_utils_pkg.am_i_in_production = 'N'
               and instr(fec.value, 'PROD') = 0
               and rownum = 1);
  
    RETURN l_path;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'N';
  end get_top_path;
  --------------------------------------------------------------------------
  -- Ver   When        Who           Description
  -- ----  ----------  ------------  ---------------------------------------
  -- 1.0   11/01/2019  Roman W.      CHG0046921
  --------------------------------------------------------------------------
  procedure create_directory(p_path       in varchar2,
                             p_directory  in varchar2,
                             p_error_code out varchar2,
                             p_error_desc out varchar2) is
    -----------------------------
    --    Local Definition
    -----------------------------
    l_sql varchar2(1000);
    -----------------------------
    --     Code Section
    -----------------------------
  begin
    p_error_code := '0';
    p_error_desc := null;
    l_sql        := 'CREATE OR REPLACE DIRECTORY ' || p_directory ||
                    ' AS ''' || p_path || '''';
  
    message(l_sql);
  
    EXECUTE IMMEDIATE l_sql;
  
    commit;
  
  exception
    when others then
      p_error_code := '2';
      p_error_desc := 'EXCEPTION_OTHERS xxssys_dpl_pkg.create_dpl_directory(' ||
                      p_path || ') - ' || sqlerrm;
      message(p_error_desc);
  end create_directory;

  -------------------------------------------------------------------------------------------
  -- Ver   When          Who        Descr
  -- ----  ------------  ---------  --------------------------------------------------------------
  -- 1.0   11/12/2019    Bellona.B  CHG0046921
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
    
      message(p_error_desc);
  END is_directory_valid;
  --------------------------------------------------------------------------
  -- Ver   When        Who           Description
  -- ----  ----------  ------------  ---------------------------------------
  -- 1.0   01/11/2019  Bellona.B     CHG0046921
  --------------------------------------------------------------------------
  procedure make_directory(p_dir_path   in varchar2,
                           p_directory  in varchar2,
                           p_error_code out varchar2,
                           p_error_desc out varchar2) is
    --------------------------------
    --     Local Definition
    --------------------------------
    l_request_id NUMBER;
  
    l_phase                VARCHAR2(100);
    l_status               VARCHAR2(100);
    l_dev_phase            VARCHAR2(100);
    l_dev_status           VARCHAR2(100);
    l_message              VARCHAR2(100);
    l_req_return_status    BOOLEAN;
    l_directory_valid_flag VARCHAR2(10);
    --------------------------------
    --     Code Section
    --------------------------------
  BEGIN
  
    p_error_code := '0';
    p_error_desc := NULL;
  
    create_directory(p_path       => p_dir_path,
                     p_directory  => p_directory,
                     p_error_code => p_error_code,
                     p_error_desc => p_error_desc);
  
    if '0' != p_error_code then
      return;
    end if;
  
    is_directory_valid(p_directory  => p_directory,
                       p_valid_flag => l_directory_valid_flag,
                       p_error_code => p_error_code,
                       p_error_desc => p_error_desc);
  
    IF '0' != p_error_code THEN
      message(p_error_desc);
      return;
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
                                                 argument1   => p_dir_path);
    
      COMMIT;
    
      message('REQUEST_ID :  ' || l_request_id || ' | XXFNDMKDIR( ' ||
              p_dir_path || ' ) ');
    
      if l_request_id > 0 then
        wait_for_request(p_request_id => l_request_id,
                         p_error_code => p_error_code,
                         p_error_desc => p_error_Desc);
      
        is_directory_valid(p_directory  => p_directory,
                           p_valid_flag => l_directory_valid_flag,
                           p_error_code => p_error_code,
                           p_error_desc => p_error_desc);
      
        IF '0' != p_error_code THEN
          message(p_error_desc);
          return;
        END IF;
      
        if 'Y' != l_directory_valid_flag then
          p_error_code := '2';
          p_error_desc := 'ERROR XXSSYS_DPL_PKG.make_directory(' ||
                          p_dir_path || ',' || p_directory ||
                          ') - Directory not valid';
        end if;
      else
        p_error_code := '2';
        p_error_desc := 'ERROR conccuren XXFNDMKDIR (' || p_dir_path ||
                        ') not submited ';
        message(p_error_desc);
      
      end if;
    end if;
  exception
    when others then
      p_error_code := '2';
      p_error_desc := 'ERROR : Concurrent (XX Fnd Mkdir - ' || l_request_id ||
                      ') completed with ERROR -' || SQLERRM;
    
      message(p_error_desc);
    
  end make_directory;

  --------------------------------------------------------------------------
  -- Ver   When        Who           Description
  -- ----  ----------  ------------  ---------------------------------------
  -- 1.0   30/12/2019  Roman W.      CHG0046921
  --------------------------------------------------------------------------
  procedure submit_fndwfload(p_full_path   in VARCHAR2,
                             p_file_name   in VARCHAR2,
                             p_object_name in VARCHAR2,
                             p_error_code  out varchar2,
                             p_error_desc  out varchar2) is
    -------------------------------
    --     Local Definition
    -------------------------------
    l_request_id NUMBER;
    -------------------------------
    --     Code Section
    -------------------------------
  begin
    p_error_desc := '0';
    p_error_code := null;
  
    l_request_id := fnd_request.submit_request(application => 'FND',
                                               program     => 'FNDWFLOAD',
                                               description => NULL,
                                               start_time  => NULL,
                                               sub_request => FALSE,
                                               argument1   => 'DOWNLOAD',
                                               argument2   => p_full_path || '/' ||
                                                              p_file_name,
                                               argument3   => p_object_name);
  
    commit;
  
    message('REQUEST_ID : ' || l_request_id || ' | FNDWFLOAD( DOWNLOAD , ' ||
            p_full_path || '/' || p_file_name || ' , ' || p_object_name || ')');
  
    if l_request_id > 0 then
      wait_for_request(p_request_id => l_request_id,
                       p_error_code => p_error_code,
                       p_error_desc => p_error_desc);
    else
      p_error_code := '2';
      p_error_desc := 'ERROR : conccurent FNDWFLOAD( DOWNLOAD , ' ||
                      p_full_path || '/' || p_file_name || ' , ' ||
                      p_object_name || ') not submited ';
    end if;
  
  exception
    when others then
      p_error_desc := '2';
      p_error_desc := 'EXCEPTION_OTHERS xxssys_dpl_pkg.submit_fndwfload(' ||
                      p_full_path || ' , ' || p_file_name || ' , ' ||
                      p_object_name || ') - ' || sqlerrm;
      message(p_error_desc);
  end submit_fndwfload;
  --------------------------------------------------------------------------
  -- Ver   When        Who           Description
  -- ----  ----------  ------------  ---------------------------------------
  -- 1.0   11/01/2019  Roman W.      CHG0046921
  --------------------------------------------------------------------------
  procedure submit_fndload(p_argument2  in varchar2,
                           p_argument3  in varchar2,
                           p_argument4  in varchar2,
                           p_argument5  in varchar2,
                           p_argument6  in varchar2,
                           p_error_code out varchar2,
                           p_error_desc out varchar2) is
    ---------------------------
    --    Local Definition
    ---------------------------
    l_request_id number;
    l_complete   boolean;
    l_phase      varchar2(100);
    l_status     varchar2(100);
    l_dev_phase  varchar2(100);
    l_dev_status varchar2(100);
    l_message    varchar2(100);
    ---------------------------
    --    Code Section
    ---------------------------
  begin
    p_error_code := 0;
    p_error_desc := null;
  
    l_request_id := fnd_request.submit_request(application => 'FND',
                                               program     => 'FNDLOAD',
                                               description => NULL,
                                               start_time  => NULL,
                                               sub_request => FALSE,
                                               argument1   => 'DOWNLOAD',
                                               argument2   => p_argument2,
                                               argument3   => p_argument3,
                                               argument4   => p_argument4,
                                               argument5   => p_argument5,
                                               argument6   => p_argument6);
  
    commit;
    message('REQUEST_ID : ' || l_request_id || ' | FNDLOAD(DOWNLOAD, ' ||
            p_argument2 || ',' || p_argument3 || ',' || p_argument4 || ',' ||
            p_argument5 || ',' || p_argument6 || ')');
    if l_request_id > 0 then
    
      wait_for_request(p_request_id => l_request_id,
                       p_error_code => p_error_code,
                       p_error_desc => p_error_desc);
    else
      p_error_code := '2';
      p_error_desc := 'ERROR : conccuren FNDLOAD (' || p_argument2 || ',' ||
                      p_argument3 || ',' || p_argument4 || ',' ||
                      p_argument6 || ') not submited ';
    
      message(p_error_desc);
    
    end if;
  
  end submit_fndload;
  --------------------------------------------------------------------------
  -- Ver   When        Who           Description
  -- ----  ----------  ------------  ---------------------------------------
  -- 1.0   30/10/2019  Bellon.B      CHG0046921
  -- 1.1   14/11/2019  Roman W.      CHG0046921 added "p_target_directory in varchar2,"
  --------------------------------------------------------------------------
  procedure submit_xxcpfile(p_obj_type         in varchar2,
                            p_obj_name         in varchar2,
                            p_target_directory in varchar2,
                            p_error_code       out varchar2,
                            p_error_desc       out varchar2) is
    ---------------------------
    --    Local Definition
    ---------------------------
    l_request_id number;
    l_complete   boolean;
    l_phase      varchar2(100);
    l_status     varchar2(100);
    l_dev_phase  varchar2(100);
    l_dev_status varchar2(100);
    l_message    varchar2(100);
    p_argument1  varchar2(100);
    p_argument2  varchar2(100);
    p_argument3  varchar2(100);
    p_argument4  varchar2(100);
    ---------------------------
    --    Code Section
    ---------------------------
  begin
    p_error_code := 0;
    p_error_desc := null;
    --input parameters
    message('p_obj_type: ' || p_obj_type);
    message('p_obj_name: ' || p_obj_name);
  
    p_argument2 := p_obj_name;
    p_argument4 := p_obj_name;
  
    IF p_obj_type = 'REPORT' THEN
      p_argument1 := get_top_path('XXOBJT_TOP') || '/reports/US';
      --      p_argument3 := C_DPL_ROOT_PATH || '/report';
    ELSIF p_obj_type = 'FORM' THEN
      p_argument1 := get_top_path('AU_TOP') || '/forms/US';
      --      p_argument3 := C_DPL_ROOT_PATH || '/form';
    ELSIF p_obj_type = 'HOST' THEN
      p_argument1 := get_top_path('XXOBJT_TOP') || '/bin';
    END IF;
    p_argument3 := p_target_directory;
  
    l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                               program     => 'XXCPFILE',
                                               description => NULL,
                                               start_time  => NULL,
                                               sub_request => FALSE,
                                               argument1   => p_argument1,
                                               argument2   => p_argument2,
                                               argument3   => p_argument3,
                                               argument4   => p_argument4);
  
    commit;
    message('REQUEST_ID : ' || l_request_id || ' | XXCPFILE(' ||
            p_argument1 || ', ' || p_argument2 || ', ' || p_argument3 || ', ' ||
            p_argument4 || ')');
    if l_request_id > 0 then
      wait_for_request(p_request_id => l_request_id,
                       p_error_code => p_error_code,
                       p_error_desc => p_error_desc);
    ELSE
      p_error_code := '2';
      p_error_desc := 'ERROR : conccurent XXCPFILE (' || p_argument1 || ',' ||
                      p_argument2 || ',' || p_argument3 || ',' ||
                      p_argument4 || ') not submited ';
    
      message(p_error_desc);
    end if;
  
  end submit_xxcpfile;

  --------------------------------------------------------------------------
  -- Ver    When           Who              Descr
  -- -----  -------------  ---------------  --------------------------------
  -- 1.0    10/02/2020     Roman W.         CHG0046921
  --------------------------------------------------------------------------
  procedure submit_add_dpl_zip_to_change(p_dpl_header_id IN VARCHAR2,
                                         p_change_number IN VARCHAR2,
                                         p_request_id    OUT NUMBER,
                                         p_error_code    OUT VARCHAR2,
                                         p_error_desc    OUT VARCHAR2) is
    ----------------------------
    --    Code Section
    ----------------------------
  begin
    p_error_code := '0';
    p_error_desc := null;
  
    if trim(p_dpl_header_id) is null or trim(p_change_number) is null then
      p_error_code := '2';
      p_error_desc := 'xxssys_dpl_pkg.add_zip_to_change p_dpl_header_id & p_change_number - can''t be null';
      message(p_error_desc);
      return;
    end if;
  
    p_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                               program     => 'XXSSYS_ADD_DPL_ZIP_TO_CHANGE',
                                               description => 'XX SSYS: Add DPL ZIP to change',
                                               start_time  => sysdate,
                                               sub_request => FALSE,
                                               argument1   => p_dpl_header_id,
                                               argument2   => p_change_number);
  
    if 0 = p_request_id then
      p_error_code := '2';
      p_error_desc := 'Concurrent "XX SSYS: Add DPL ZIP to change/XXSSYS_ADD_DPL_ZIP_TO_CHANGE(' ||
                      C_DPL_DIRECTORY || ',' || p_change_number ||
                      ')" - Not Submitted ';
      message(p_error_desc);
    else
      commit;
      wait_for_request(p_request_id => p_request_id,
                       p_error_code => p_error_code,
                       p_error_desc => p_error_desc);
    
    end if;
  end submit_add_dpl_zip_to_change;

  --------------------------------------------------------------------------
  -- Ver    When           Who              Descr
  -- -----  -------------  ---------------  --------------------------------
  -- 1.0    27/01/2020     Roman W.         CHG0046921
  --------------------------------------------------------------------------
  procedure submit_zip_folder(p_path          IN VARCHAR2,
                              p_change_number IN VARCHAR2,
                              p_error_code    OUT VARCHAR2,
                              p_error_desc    OUT VARCHAR2) is
    ---------------------------
    --    Code Section
    ---------------------------
    l_request_id NUMBER;
    ---------------------------
    --    Local Definition
    ---------------------------
  begin
    p_error_code := '0';
    p_error_desc := null;
  
    l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                               program     => 'XXSSYS_CREATE_ZIP_FILE',
                                               description => 'XX SSYS: Create ZIP File',
                                               start_time  => sysdate,
                                               sub_request => FALSE,
                                               argument1   => p_path,
                                               argument2   => 'DPL_' ||
                                                              p_change_number);
  
    if 0 = l_request_id then
      p_error_code := '2';
      p_error_desc := 'Concurrent "XX SSYS: Create ZIP File/XXSSYS_CREATE_ZIP_FILE(' ||
                      C_DPL_DIRECTORY || ',' || p_change_number ||
                      ')" - Not Submitted ';
      message(p_error_desc);
    else
      commit;
      message(l_request_id ||
              ' - XX SSYS: Create ZIP File/XXSSYS_CREATE_ZIP_FILE');
      wait_for_request(p_request_id => l_request_id,
                       p_error_code => p_error_code,
                       p_error_desc => p_error_desc);
    
    end if;
  exception
    when others then
      p_error_code := '2';
      p_error_desc := 'EXCEPTION_OTHERS xxssys_dpl_pkg.submit_zip_folder(' ||
                      p_path || ',' || p_change_number || ') - ' || sqlerrm;
      message(p_msg => p_error_desc);
    
  end submit_zip_folder;
  --------------------------------------------------------------------------
  -- Ver   When        Who           Description
  -- ----  ----------  ------------  ---------------------------------------
  -- 1.0   11/01/2019  Roman W.      CHG0046921
  --------------------------------------------------------------------------
  procedure download_ldt(p_path                   in varchar2,
                         p_application_short_name in varchar2,
                         p_name                   in varchar2,
                         p_attr2                  in varchar2,
                         p_attr3                  in varchar2,
                         p_attr4                  in varchar2,
                         p_attr5                  in varchar2,
                         p_attr6                  in varchar2,
                         p_error_code             out varchar2,
                         p_error_desc             out varchar2) is
  
    ----------------------------------
    --      Local Definition
    ----------------------------------
    l_full_path VARCHAR2(2000);
    l_attr3     VARCHAR2(500);
    l_attr4     VARCHAR2(500);
    l_attr5     VARCHAR2(500);
    l_attr6     VARCHAR2(500);
    ----------------------------------
    --      Code Section
    ----------------------------------
  begin
    p_error_code := 0;
    p_error_desc := null;
  
    select p_path || p_name || '_' || p_attr3 || '.ldt',
           p_attr4,
           decode(p_attr5,
                  null,
                  null,
                  p_attr5 || '=' || p_application_short_name),
           decode(p_attr6, null, null, p_attr6 || '=' || p_name)
      into l_attr3, l_attr4, l_attr5, l_attr6
      from dual;
  
    remove_file(p_directory  => C_DPL_DIRECTORY,
                p_file_name  => p_name || '_' || p_attr3 || '.ldt',
                p_error_code => p_error_code,
                p_error_desc => p_error_desc);
  
    if 0 != p_error_code then
      message(p_error_desc);
      return;
    end if;
  
    submit_fndload(p_argument2  => p_attr2,
                   p_argument3  => l_attr3,
                   p_argument4  => l_attr4,
                   p_argument5  => l_attr5,
                   p_argument6  => l_attr6,
                   p_error_code => p_error_code,
                   p_error_desc => p_error_desc);
  
  exception
    when others then
      p_error_code := '2';
      p_error_desc := 'EXCEPTION_OTHERS xxssys_dpl_pkg.download_ldt() - ' ||
                      sqlerrm;
    
      message(p_error_desc);
  end download_ldt;
  --------------------------------------------------------------------------------------
  -- Ver    When        Who         Description
  -- -----  ----------  ----------  ------------------------------------------
  -- 1.0    15/10/2019  Roman W.    CHG0046921
  --------------------------------------------------------------------------------------
  FUNCTION replace_clob(p_clob         IN CLOB,
                        p_replace_str  IN varchar2,
                        p_replace_with IN varchar2) RETURN CLOB AS
    l_buffer   VARCHAR2(32767);
    l_amount   BINARY_INTEGER := 32767;
    l_pos      INTEGER := 1;
    l_clob_len INTEGER;
    newClob    clob := EMPTY_CLOB;
  
  BEGIN
  
    --initalize the new clob
    dbms_lob.CreateTemporary(newClob, TRUE);
    l_clob_len := DBMS_LOB.getlength(p_clob);
    WHILE l_pos < l_clob_len LOOP
    
      l_buffer := DBMS_LOB.substr(lob_loc => p_clob,
                                  amount  => l_amount,
                                  offset  => l_pos);
      --READ(p_clob, l_amount, l_pos, l_buffer);
    
      IF l_buffer IS NOT NULL THEN
        -- replace the text
        l_buffer := replace(l_buffer, p_replace_str, p_replace_with);
        -- write it to the new clob
        DBMS_LOB.writeAppend(newClob, LENGTH(l_buffer), l_buffer);
      END IF;
      l_pos := l_pos + l_amount;
    
    END LOOP;
  
    RETURN newClob;
  
  EXCEPTION
    WHEN OTHERS THEN
      message('EXCEPTION_OTHERS XXSSYS_DPL_PKG.replace_clob() - ' ||
              sqlerrm);
      RAISE;
  END replace_clob;
  --------------------------------------------------------------------------
  -- Ver    When        Who         Description
  -- -----  ----------  ----------  ------------------------------------------
  -- 1.0    15/10/2019  Roman W.    CHG0046921
  -- 1.1    09/09/2020  Roman W.    CHG0046921 - replace ''    
  --------------------------------------------------------------------------
  procedure get_db_object(p_object_type IN VARCHAR2,
                          p_name        IN VARCHAR2,
                          p_schema      IN VARCHAR2,
                          p_db_object   OUT CLOB,
                          p_error_code  OUT VARCHAR2,
                          p_error_desc  OUT VARCHAR2) is
  
    --------------------------------
    --     Code Section
    --------------------------------
  begin
    p_error_code := '0';
    p_error_desc := null;
  
    p_db_object := dbms_metadata.get_ddl(object_type => upper(p_object_type),
                                         name        => upper(p_name),
                                         schema      => upper(p_schema));
  
    p_db_object := LTRIM(p_db_object, CHR(10) || CHR(13) || ' ');
    p_db_object := REPLACE(p_db_object, '', '');
  
    IF p_object_type in ('PACKAGE_BODY', 'PACKAGE_SPEC') THEN
      p_db_object := replace_clob(p_db_object, 'EDITIONABLE ', '');
    
    END IF;
  
    IF p_object_type in ('VIEW', 'SYNONYM') then
      p_db_object := replace_clob(p_db_object, 'FORCE EDITIONABLE ', '');
      dbms_lob.append(p_db_object, ';');
    END IF;
  
    IF p_object_type in ('TRIGGER') THEN
      p_db_object := replace_clob(p_db_object, 'EDITIONABLE ', '');
    
      p_db_object := REPLACE(p_db_object,
                             'ALTER TRIGGER',
                             '--ALTER TRIGGER');
    END IF;
  
    IF p_object_type in ('TRIGGER',
                         'SYNONYM',
                         'TABLE',
                         'INDEX',
                         'SEQUENCE',
                         'PACKAGE_BODY',
                         'PACKAGE_SPEC') THEN
      p_db_object := p_db_object || chr(10) || '/';
    END IF;
  
  exception
    when others then
      p_error_code := '2';
      p_error_desc := 'EXCEPTION_OTHERS xxssys_dpl_pkg.get_db_object(' ||
                      p_object_type || ',' || p_name || ',' || p_schema ||
                      ') - ' || sqlerrm;
    
      message(p_error_desc);
  end get_db_object;

  -------------------------------------------------------------------------
  -- Ver   When         Who          Descr 
  -- ----  -----------  -----------  --------------------------------------
  -- 1.0   09/09/2020   Roman W.     CHG0046921
  -------------------------------------------------------------------------
  procedure remove_file(p_directory  in varchar2,
                        p_file_name  in varchar2,
                        p_error_code out varchar2,
                        p_error_desc out varchar2) is
    l_count NUMBER;
  begin
    p_error_code := '0';
    p_error_desc := null;
  
    l_count := dbms_lob.fileexists(bfilename(p_directory, p_file_name));
  
    if 1 = l_count then
      utl_file.fremove(location => p_directory, filename => p_file_name);
    end if;
  exception
    when others then
      p_error_code := '2';
      p_error_desc := 'EXCEPTION_OTHERS xxssys_dpl_pkg.remove_file(' ||
                      p_directory || ',' || p_file_name || ') - ' ||
                      sqlerrm;
  end remove_file;
  -------------------------------------------------------------------------------
  -- Concurrent : XXSSYS_CREATE_DPL_FOLDER / XX: SSYS Create DPL folder
  -------------------------------------------------------------------------------
  -- Ver    When        Who            Descr
  -- -----  ----------  -------------  ------------------------------------------
  -- 1.0    2019-10-15  Roman W        CHG0046921
  -- 1.1    2020-05-22  Roman W        CHG0046921 - GIT
  -------------------------------------------------------------------------------
  procedure main(errbuf          OUT VARCHAR2,
                 retcode         OUT NUMBER,
                 p_change_number IN VARCHAR2) is
    -------------------------
    --   Local Definition
    -------------------------
    cursor object_entities_cur(c_change_number VARCHAR2) is
      select xdl.dpl_header_id,
             xdl.dpl_line_id,
             xdst.CATEGORY_CODE,
             xdh.CHANGE_NUMBER,
             xdl.OBJECT_TYPE,
             xdl.SCHEMA,
             xdl.OBJECT_NAME,
             xdl.OBJECT_NAME ||
             DECODE(xdst.file_suffix, null, null, '.' || xdst.file_suffix) FILE_NAME,
             xdl.APPLICATION_SHORT_NAME,
             xdst.DPL_PATH,
             xdh.DPL_LOCATION,
             xdst.ldt_attr2,
             xdst.ldt_attr3,
             xdst.ldt_attr4,
             xdst.ldt_attr5,
             xdst.ldt_attr6
        from xxssys_dpl_headers xdh,
             xxssys_dpl_lines   xdl,
             xxssys_dpl_setup   xdst
       where xdh.CHANGE_NUMBER = c_change_number
         and xdl.dpl_header_id = xdh.dpl_header_id
         and nvl(xdst.object_type, -1) = nvl(xdl.object_type, -1)
         and upper(nvl(xdst.schema, -1)) = upper(nvl(xdl.schema, -1))
       order by xdl.dpl_line_id;
  
    l_db_object  CLOB;
    l_error_code VARCHAR2(10);
    l_error_desc VARCHAR2(2000);
    l_full_path  VARCHAR2(2000);
    l_request_id number;
  
    l_complete      boolean;
    l_phase         varchar2(100);
    l_status        varchar2(100);
    l_dev_phase     varchar2(100);
    l_dev_status    varchar2(100);
    l_message       varchar2(100);
    l_dpl_header_id varchar2(100);
    l_dpl_path      varchar2(500);
    l_git_init_path varchar2(500);
    --------------------------
    --    Code Section
    --------------------------
  begin
  
    errbuf  := null;
    retcode := '0';
  
    select dpl_header_id
      into l_dpl_header_id
      from xxssys_dpl_headers xdh
     where trim(xdh.change_number) = trim(p_change_number);
  
    update xxssys_dpl_lines xdl
       set xdl.status = 'NEW'
     where xdl.dpl_header_id = l_dpl_header_id;
  
    commit;
  
    -- Update XXSSYS_DPL_HEADERS.STATUS to IN_PROCESS --
    for object_entities_ind in object_entities_cur(p_change_number) loop
    
      l_error_code := '0';
      l_error_desc := null;
    
      update_dpl_line_status(p_dpl_header_id => object_entities_ind.dpl_header_id,
                             p_dpl_line_id   => object_entities_ind.dpl_line_id,
                             p_status        => C_IN_PROCESS,
                             p_dpl_err_msg   => NULL,
                             p_error_code    => l_error_code,
                             p_error_desc    => l_error_desc);
    
      if '0' != l_error_code then
        retcode := l_error_code;
        errbuf  := l_error_desc;
        message(errbuf);
        continue;
      
      end if;
      get_change_dpl_path(p_change_number => p_change_number,
                          p_path          => l_dpl_path,
                          p_error_code    => retcode,
                          p_error_desc    => errbuf);
    
      if '0' != l_error_code then
        retcode := l_error_code;
        errbuf  := l_error_desc;
        continue;
      
      else
        l_git_init_path := nvl(object_entities_ind.dpl_location, l_dpl_path) ||
                           '/DPL_' || p_change_number; -- CHG0046921 - GIT
      
        make_directory(p_dir_path   => l_git_init_path,
                       p_directory  => C_DPL_DIRECTORY,
                       p_error_code => retcode,
                       p_error_desc => errbuf);
      
        xxssys_git_pkg.git_init(p_path       => l_git_init_path,
                                p_error_code => retcode,
                                p_error_desc => errbuf);
      
        if '0' != retcode then
          return;
        end if;
      
      end if;
    
      l_full_path := nvl(object_entities_ind.dpl_location, l_dpl_path) ||
                     '/DPL_' || p_change_number ||
                     object_entities_ind.dpl_path;
    
      make_directory(p_dir_path   => l_full_path,
                     p_directory  => C_DPL_DIRECTORY,
                     p_error_code => l_error_code,
                     p_error_desc => l_error_desc);
    
      if '0' != l_error_code then
      
        retcode := greatest(retcode, l_error_code);
        errbuf  := errbuf || ' | ' || l_error_desc;
      
        update_dpl_line_status(p_dpl_header_id => object_entities_ind.dpl_header_id,
                               p_dpl_line_id   => object_entities_ind.dpl_line_id,
                               p_status        => C_ERROR,
                               p_dpl_err_msg   => l_error_desc,
                               p_error_code    => l_error_code,
                               p_error_desc    => l_error_desc);
      
        continue;
      end if;
    
      case object_entities_ind.CATEGORY_CODE
        when 'SETUP' then
          --Download Application Setup files
          /* form function, attachment, alert, lookup, menu, message, personalization,
          profile, program, request group, request set, responsibility, valueset. */
          message('OBJECT_NAME : ' || object_entities_ind.OBJECT_NAME);
        
          download_ldt(p_path                   => l_full_path,
                       p_application_short_name => object_entities_ind.application_short_name,
                       p_name                   => object_entities_ind.object_name,
                       p_attr2                  => object_entities_ind.ldt_attr2,
                       p_attr3                  => object_entities_ind.ldt_attr3,
                       p_attr4                  => object_entities_ind.ldt_attr4,
                       p_attr5                  => object_entities_ind.ldt_attr5,
                       p_attr6                  => object_entities_ind.ldt_attr6,
                       p_error_code             => l_error_code,
                       p_error_desc             => l_error_desc);
        
          if l_error_code != '0' then
            retcode := greatest(retcode, l_error_code);
            errbuf  := errbuf || ' | ' || l_error_desc;
            continue;
          end if;
        
        when 'BINARY_FILE' then
          --Download Binary files (Reports/Forms)
          message('OBJECT_NAME : ' || object_entities_ind.OBJECT_NAME);
        
          if object_entities_ind.object_type in ('HOST', 'FORM', 'REPORT') then
            submit_xxcpfile(p_obj_type         => object_entities_ind.object_type,
                            p_obj_name         => object_entities_ind.file_name,
                            p_target_directory => l_full_path,
                            p_error_code       => l_error_code,
                            p_error_desc       => l_error_desc);
          
            if '0' != l_error_code then
              message(l_error_desc);
              retcode := greatest(retcode, l_error_code);
              errbuf  := errbuf || ' | ' || l_error_desc;
            end if;
          
          elsif object_entities_ind.object_type = 'WORKFLOW' then
          
            message('OBJECT_NAME : ' || object_entities_ind.OBJECT_NAME);
          
            submit_fndwfload(p_full_path   => l_full_path,
                             p_file_name   => object_entities_ind.FILE_NAME,
                             p_object_name => object_entities_ind.object_name,
                             p_error_code  => l_error_code,
                             p_error_desc  => l_error_desc);
          
            if '0' != l_error_code then
              retcode := greatest(retcode, l_error_code);
              errbuf  := errbuf || ' | ' || l_error_desc;
            end if;
          
          else
          
            retcode := 2;
            errbuf  := 'BINARY_FILE -> ' || object_entities_ind.object_type ||
                       ' -> No handling to OBJECT_TYPE';
            message(errbuf);
          
          end if;
        
        when 'SQL' then
          message('OBJECT_NAME : ' || object_entities_ind.OBJECT_NAME);
          get_db_object(p_object_type => object_entities_ind.object_type,
                        p_name        => object_entities_ind.object_name,
                        p_schema      => object_entities_ind.schema,
                        p_db_object   => l_db_object,
                        p_error_code  => l_error_code,
                        p_error_desc  => l_error_desc);
        
          if '0' = l_error_code then
            remove_file(p_directory  => C_DPL_DIRECTORY,
                        p_file_name  => object_entities_ind.FILE_NAME,
                        p_error_code => l_error_code,
                        p_error_desc => l_error_desc);
          
            if '0' != l_error_code then
            
              message('SQL-4)' || l_error_desc);
              retcode := greatest(retcode, l_error_code);
              errbuf  := l_error_desc;
            else
              xxssys_file_util_pkg.save_clob_to_file(p_directory_name => C_DPL_DIRECTORY,
                                                     p_file_name      => object_entities_ind.FILE_NAME,
                                                     p_clob           => l_db_object);
            end if;
          else
            message('SQL-3)' || l_error_desc);
            retcode := greatest(retcode, l_error_code);
            errbuf  := errbuf || ' | ' || l_error_desc;
          end if;
        
        else
          message('CASE not found : ' || object_entities_ind.CATEGORY_CODE);
      end case;
    
      if '0' != l_error_code then
      
        update_dpl_line_status(p_dpl_header_id => object_entities_ind.dpl_header_id,
                               p_dpl_line_id   => object_entities_ind.dpl_line_id,
                               p_status        => C_ERROR,
                               p_dpl_err_msg   => l_error_desc,
                               p_error_code    => l_error_code,
                               p_error_desc    => l_error_desc);
      else
      
        update_dpl_line_status(p_dpl_header_id => object_entities_ind.dpl_header_id,
                               p_dpl_line_id   => object_entities_ind.dpl_line_id,
                               p_status        => C_SUCCESS,
                               p_dpl_err_msg   => l_error_desc,
                               p_error_code    => l_error_code,
                               p_error_desc    => l_error_desc);
      end if;
    
    end loop;
  exception
    when others then
      errbuf  := 'EXCEPTION_OTHERS xxssys_dpl_pkg.main(' || p_change_number ||
                 ') - ' || sqlerrm;
      retcode := '2';
    
      message(errbuf);
    
  end main;
  ----------------------------------------------------------------
  -- Ver   When         Who           Description
  -- ----- -----------  ------------  ----------------------------
  -- 1.0   07/01/2019   Roman W.      CHG0046921
  ----------------------------------------------------------------
  procedure xxssys_create_dpl_folder_sbm(p_header_id     in NUMBER,
                                         p_change_number in VARCHAR2,
                                         p_request_id    out NUMBER,
                                         p_error_code    out VARCHAR2,
                                         p_error_desc    out VARCHAR2) is
    ---------------------------
    --   Local Definition
    ---------------------------
    ---------------------------
    --   Code Section
    ---------------------------
  begin
    p_request_id := 0;
    p_error_code := '0';
    p_error_desc := null;
  
    p_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                               program     => 'XXSSYS_CREATE_DPL_FOLDER',
                                               description => NULL,
                                               start_time  => NULL,
                                               sub_request => FALSE,
                                               argument1   => p_change_number);
    if 0 < p_request_id then
      commit;
    else
      p_error_code := '2';
      --      p_error_desc :=
    end if;
  
  exception
    when others then
      p_error_code := '2';
      p_error_desc := 'EXCEPTION_OTHERS xxssys_dpl_pkg.xxssys_create_dpl_folder_sbm(' ||
                      p_header_id || ',' || p_change_number || ') - ' ||
                      sqlerrm;
      message(p_error_desc);
    
  end xxssys_create_dpl_folder_sbm;

  -------------------------------------------------------------------------------
  -- Ver      When         Who              Description
  -- -------  -----------  ---------------  -------------------------------------
  -- 1.0      09/02/2020   Roman W.         CHG0046921
  -------------------------------------------------------------------------------
  procedure add_attachment(p_dpl_header_id IN NUMBER,
                           p_change_number IN varchar2,
                           p_file_name     IN varchar2,
                           p_error_code    OUT varchar2,
                           p_error_desc    OUT varchar2) is
    --------------------------
    --    Local Definition
    --------------------------
    l_rowid                ROWID;
    l_attached_document_id NUMBER;
    l_document_id          NUMBER;
    l_media_id             NUMBER;
    l_category_id          number;
    l_description          fnd_documents_tl.description%type;
    l_seq_num              NUMBER;
    l_fnd_user_id          NUMBER;
    l_short_datatype_id    NUMBER;
    x_blob                 BLOB;
    l_entity_name          varchar2(100) := 'DPL_HEADER_ID'; --'DPL_FOLDER'; --Must be defined before or use existing ones. Table: FND_DOCUMENT_ENTITIES
    l_category_name        VARCHAR2(100) := 'XXSSYS_DPL_HEADERS'; --Must be defined before or use existing ones.
    l_dpl_path             VARCHAR2(500);
  BEGIN
  
    l_description := to_char(sysdate, 'DD-MM-YYYY HH24:MI') || ' - ' ||
                     p_file_name;
  
    SELECT fnd_documents_s.NEXTVAL INTO l_document_id FROM DUAL;
  
    SELECT fnd_attached_documents_s.NEXTVAL
      INTO l_attached_document_id
      FROM DUAL;
  
    SELECT NVL(MAX(seq_num), 0) + 10
      INTO l_seq_num
      FROM fnd_attached_documents
     WHERE pk1_value = p_dpl_header_id
       AND entity_name = l_entity_name;
  
    l_fnd_user_id := fnd_global.USER_ID;
  
    -- Get Data type id for Short Text types of attachments
    SELECT datatype_id
      INTO l_short_datatype_id
      FROM apps.fnd_document_datatypes dd
     WHERE NAME = 'FILE'
       AND dd.language = 'US';
  
    -- Select Category id for Attachments
    SELECT category_id
      INTO l_category_id
      FROM apps.fnd_document_categories_vl
     WHERE USER_NAME = l_category_name;
  
    -- Select nexvalues of document id, attached document id and
    SELECT apps.fnd_documents_s.NEXTVAL,
           apps.fnd_attached_documents_s.NEXTVAL
      into l_document_id, l_attached_document_id
      FROM DUAL;
  
    get_change_dpl_path(p_change_number => p_change_number,
                        p_path          => l_dpl_path,
                        p_error_code    => p_error_code,
                        p_error_desc    => p_error_desc);
  
    SELECT fnd_lobs_s.nextval INTO l_media_id FROM dual;
  
    xxssys_file_util_pkg.make_directory(p_directory_name => C_DPL_DIRECTORY,
                                        p_dir_path       => l_dpl_path,
                                        p_error_code     => p_error_code,
                                        p_error_desc     => p_error_desc);
  
    message('p_error_code : ' || p_error_code || ', p_error_desc : ' ||
            p_error_desc);
  
    x_blob := xxssys_file_util_pkg.get_blob_from_file(p_directory_name => C_DPL_DIRECTORY,
                                                      p_file_name      => p_file_name);
  
    INSERT INTO fnd_lobs
      (file_id,
       file_name,
       file_content_type,
       upload_date,
       expiration_date,
       program_name,
       program_tag,
       file_data,
       LANGUAGE,
       oracle_charset,
       file_format)
    VALUES
      (l_media_id,
       p_file_name,
       'application/x-zip-compressed', --'text/plain',
       SYSDATE,
       NULL,
       'FNDATTCH',
       NULL,
       x_blob, -- EMPTY_BLOB(), --l_blob_data,
       'US',
       'IW8MSWIN1255',
       'binary');
  
    message('FND_LOBS File Id Created is ' || l_media_id);
  
    COMMIT;
  
    -- This package allows user to share file across multiple orgs or restrict to single org
  
    fnd_documents_pkg.insert_row(x_rowid             => l_rowid,
                                 x_document_id       => l_document_id,
                                 x_creation_date     => SYSDATE,
                                 x_created_by        => l_fnd_user_id,
                                 x_last_update_date  => SYSDATE,
                                 x_last_updated_by   => l_fnd_user_id,
                                 x_last_update_login => fnd_global.LOGIN_ID,
                                 x_datatype_id       => l_short_datatype_id,
                                 X_security_id       => null, --21, --Security ID defined in your Attchments, Usaully SOB ID/ORG_ID
                                 x_publish_flag      => 'Y', --This flag allow the file to share across multiple organization
                                 x_category_id       => l_category_id,
                                 x_security_type     => 4,
                                 x_usage_type        => 'O',
                                 x_language          => 'US',
                                 x_description       => l_description,
                                 x_file_name         => p_file_name,
                                 x_media_id          => l_media_id);
  
    commit;
  
    -- Description informations will be stored in below table based on languages.
    fnd_documents_pkg.insert_tl_row(x_document_id       => l_document_id,
                                    x_creation_date     => SYSDATE,
                                    x_created_by        => l_fnd_user_id,
                                    x_last_update_date  => SYSDATE,
                                    x_last_updated_by   => l_fnd_user_id,
                                    x_last_update_login => fnd_global.LOGIN_ID,
                                    x_language          => 'US',
                                    x_description       => l_description);
    commit;
  
    fnd_attached_documents_pkg.insert_row(x_rowid                    => l_rowid,
                                          x_attached_document_id     => l_attached_document_id,
                                          x_document_id              => l_document_id,
                                          x_creation_date            => SYSDATE,
                                          x_created_by               => l_fnd_user_id,
                                          x_last_update_date         => SYSDATE,
                                          x_last_updated_by          => l_fnd_user_id,
                                          x_last_update_login        => fnd_global.LOGIN_ID,
                                          x_seq_num                  => l_seq_num,
                                          x_entity_name              => l_entity_name,
                                          x_column1                  => NULL,
                                          x_pk1_value                => p_dpl_header_id,
                                          x_pk2_value                => NULL,
                                          x_pk3_value                => NULL,
                                          x_pk4_value                => NULL,
                                          x_pk5_value                => NULL,
                                          x_automatically_added_flag => 'N',
                                          x_datatype_id              => 6,
                                          x_category_id              => l_category_id,
                                          x_security_type            => 4,
                                          X_security_id              => null, --Security ID defined in your Attchments, Usaully SOB ID/ORG_ID
                                          x_publish_flag             => 'Y',
                                          x_language                 => 'US',
                                          x_description              => l_description,
                                          x_file_name                => p_file_name,
                                          x_media_id                 => l_media_id);
    COMMIT;
  exception
    when others then
      p_error_code := '2';
      p_error_desc := 'EXCEPTION_OTHER xxssys_dpl_pkg.add_attachment(' ||
                      p_dpl_header_id || ',' || p_change_number || ',' ||
                      p_file_name || ') - ' || sqlerrm;
    
      message(p_error_desc);
  end add_attachment;
  -------------------------------------------------------------------------------
  -- Ver   When         Who          Descr
  -- ----  -----------  -----------  --------------------------------------------
  -- 1.0   04/04/2020   Roman W.     CHG0046921
  -------------------------------------------------------------------------------
  procedure get_change_dpl_path(p_change_number IN VARCHAR2,
                                p_path          OUT VARCHAR2,
                                p_error_code    OUT VARCHAR2,
                                p_error_desc    OUT VARCHAR2) is
    ----------------------------
    --   Local Definition
    ----------------------------
  
    ----------------------------
    --     Code Section
    ----------------------------
  begin
    p_error_code := '0';
    p_error_desc := null;
  
    select xdh.dpl_location
      into p_path
      from xxssys_dpl_headers xdh
     where xdh.change_number = p_change_number;
  
  exception
    when others then
      p_path       := null;
      p_error_code := '2';
      p_error_desc := 'EXCEPTION_OTHERS xxssys_dpl_pkg.get_change_dpl_path(' ||
                      p_change_number || ') - ' || sqlerrm;
    
      message(p_error_desc);
  end get_change_dpl_path;
  -------------------------------------------------------------------------------
  -- Concurrent : XXSSYS_ADD_DPL_ZIP_TO_CHANGE/XX SSYS: Add DPL ZIP to change
  -------------------------------------------------------------------------------
  -- Ver      When         Who              Description
  -- -------  -----------  ---------------  -------------------------------------
  -- 1.0      27/01/2020   Roman W.         CHG0046921
  -------------------------------------------------------------------------------
  procedure add_zip_to_change(errbuf          OUT VARCHAR2,
                              retcode         OUT NUMBER,
                              p_dpl_header_id IN NUMBER,
                              p_change_number IN VARCHAR2) is
    -----------------------------
    --   Local Definition
    -----------------------------
    l_user_id    number;
    l_request_id number;
    l_blob       blob;
    l_file_name  varchar2(500);
    l_dpl_path   varchar2(5000);
    -----------------------------
    --   Code Section
    -----------------------------
  begin
    retcode := '0';
    errbuf  := null;
  
    l_user_id   := fnd_global.USER_ID;
    l_file_name := 'DPL_' || p_change_number || '.zip';
    --------------- Create DPL (Check out objects ) ----------------
    xxssys_dpl_pkg.main(errbuf          => errbuf,
                        retcode         => retcode,
                        p_change_number => p_change_number);
  
    if '0' <> retcode then
      return;
    end if;
  
    get_change_dpl_path(p_change_number => p_change_number,
                        p_path          => l_dpl_path,
                        p_error_code    => retcode,
                        p_error_desc    => errbuf);
    if '0' <> retcode then
      return;
    end if;
    --------------- Create ZIP -----------------
    make_directory(p_dir_path   => l_dpl_path,
                   p_directory  => C_DPL_DIRECTORY,
                   p_error_code => retcode,
                   p_error_desc => errbuf);
  
    if '0' <> retcode then
      return;
    end if;
  
    get_change_dpl_path(p_change_number => p_change_number,
                        p_path          => l_dpl_path,
                        p_error_code    => retcode,
                        p_error_desc    => errbuf);
  
    submit_zip_folder(p_path          => l_dpl_path,
                      p_change_number => p_change_number,
                      p_error_code    => retcode,
                      p_error_desc    => errbuf);
  
    if '0' <> retcode then
      return;
    end if;
  
    add_attachment(p_dpl_header_id => p_dpl_header_id,
                   p_change_number => p_change_number,
                   p_file_name     => l_file_name,
                   p_error_code    => retcode,
                   p_error_desc    => errbuf);
  exception
    when others then
      retcode := '2';
      errbuf  := 'EXCEPTION_OTHERS xxssys_dpl_pkg.send_dpl_to_email(' ||
                 p_change_number || ') - ' || sqlerrm;
      message(errbuf);
    
  end add_zip_to_change;

  ---------------------------------------------------------------------------------
  -- Ver   When        Who             Descr
  -- ----  ----------  --------------  --------------------------------------------
  -- 1.0   12/04/2020  Roman W.        CHG0046921
  ---------------------------------------------------------------------------------
  function after_dpl_exporter return boolean is
    --------------------------
    --   Local Definition
    --------------------------
  
    --------------------------
    --   Code Section
    --------------------------
  begin
    return(true);
  end after_dpl_exporter;

  ---------------------------------------------------------------------------------
  -- Ver   When        Who             Descr
  -- ----  ----------  --------------  --------------------------------------------
  -- 1.0   12/04/2020  Roman W.        CHG0046921
  ---------------------------------------------------------------------------------
  procedure xml_importer(errbuf          OUT VARCHAR2,
                         retcode         OUT NUMBER,
                         p_change_number IN VARCHAR2) is
  
    ------------------------------
    --    Local Defintion
    ------------------------------
  
    -- Change List cursor --
    cursor change_cur(c_xml XMLTYPE, c_path VARCHAR2) is
      select extractValue(value(t), 'G_CHANGE_LIST/L_CHANGE_NUMBER') L_CHANGE_NUMBER,
             extract(c_xml, c_path || '/LIST_G_DPL_HEADER') LIST_G_DPL_HEADER
        from table(XMLSequence(c_xml.extract(c_path))) t;
    -- Header Cursor --
    Cursor header_cur(c_xml           XMLTYPE,
                      c_path          VARCHAR2,
                      c_change_number varchar2) is
      select row_num,
             DPL_HEADER_ID,
             CHANGE_NUMBER,
             REQUESTED_BY,
             ASSIGNED_TO,
             CREATED_BY,
             to_date(CREATION_DATE, C_DATE_FORMAT) CREATION_DATE,
             to_date(LAST_UPDATE_DATE, C_DATE_FORMAT) LAST_UPDATE_DATE,
             LAST_UPDATED_BY,
             LAST_UPDATE_LOGIN,
             DPL_LOCATION,
             DPL_HEADER_DESCR,
             DPL_STATUS,
             DPL_ERROR_MESSAGE,
             extract(c_xml,
                     'LIST_G_DPL_HEADER[' || row_num ||
                     ']/G_DPL_HEADER/LIST_G_DPL_LINE') LIST_G_DPL_LINE
        from (select rownum row_num,
                     extractValue(value(t), 'G_DPL_LINE/L_DPL_HEADER_ID') DPL_HEADER_ID,
                     extractValue(value(t), 'G_DPL_HEADER/CHANGE_NUMBER') CHANGE_NUMBER,
                     extractValue(value(t), 'G_DPL_HEADER/REQUESTED_BY') REQUESTED_BY,
                     extractValue(value(t), 'G_DPL_HEADER/ASSIGNED_TO') ASSIGNED_TO,
                     extractValue(value(t), 'G_DPL_HEADER/CREATED_BY') CREATED_BY,
                     extractValue(value(t), 'G_DPL_HEADER/CREATION_DATE') CREATION_DATE,
                     extractValue(value(t), 'G_DPL_HEADER/LAST_UPDATE_DATE') LAST_UPDATE_DATE,
                     extractValue(value(t), 'G_DPL_HEADER/LAST_UPDATED_BY') LAST_UPDATED_BY,
                     extractValue(value(t), 'G_DPL_HEADER/LAST_UPDATE_LOGIN') LAST_UPDATE_LOGIN,
                     extractValue(value(t), 'G_DPL_HEADER/DPL_LOCATION') DPL_LOCATION,
                     extractValue(value(t), 'G_DPL_HEADER/DPL_HEADER_DESCR') DPL_HEADER_DESCR,
                     extractValue(value(t), 'G_DPL_HEADER/DPL_STATUS') DPL_STATUS,
                     extractValue(value(t), 'G_DPL_HEADER/DPL_ERROR_MESSAGE') DPL_ERROR_MESSAGE
                from table(XMLSequence(c_xml.extract(c_path))) t) sub
       where sub.CHANGE_NUMBER = c_change_number;
  
    -- Line Cursor --
    cursor line_cur(c_xml XMLTYPE, c_path VARCHAR2) is
      select sub.DPL_HEADER_ID,
             sub.DPL_LINE_ID,
             sub.OBJECT_TYPE,
             sub.SCHEMA,
             sub.OBJECT_NAME,
             sub.STATUS,
             sub.ERROR_DESC,
             sub.APPLICATION_SHORT_NAME,
             sub.CREATED_BY,
             to_date(sub.CREATION_DATE, C_DATE_FORMAT) CREATION_DATE,
             to_date(sub.LAST_UPDATE_DATE, C_DATE_FORMAT) LAST_UPDATE_DATE,
             sub.LAST_UPDATED_BY,
             sub.LAST_UPDATE_LOGIN,
             sub.CHECK_OUT
        from (select extractValue(value(t), 'G_DPL_LINE/DPL_HEADER_ID') DPL_HEADER_ID,
                     extractValue(value(t), 'G_DPL_LINE/DPL_LINE_ID') DPL_LINE_ID,
                     extractValue(value(t), 'G_DPL_LINE/OBJECT_TYPE') OBJECT_TYPE,
                     extractValue(value(t), 'G_DPL_LINE/SCHEMA') SCHEMA,
                     extractValue(value(t), 'G_DPL_LINE/OBJECT_NAME') OBJECT_NAME,
                     extractValue(value(t), 'G_DPL_LINE/STATUS') STATUS,
                     extractValue(value(t), 'G_DPL_LINE/ERROR_DESC') ERROR_DESC,
                     extractValue(value(t),
                                  'G_DPL_LINE/APPLICATION_SHORT_NAME') APPLICATION_SHORT_NAME,
                     extractValue(value(t), 'G_DPL_LINE/CREATED_BY') CREATED_BY,
                     to_date(extractValue(value(t),
                                          'G_DPL_LINE/CREATION_DATE'),
                             C_DATE_FORMAT) CREATION_DATE,
                     to_date(extractValue(value(t),
                                          'G_DPL_LINE/LAST_UPDATE_DATE'),
                             C_DATE_FORMAT) LAST_UPDATE_DATE,
                     extractValue(value(t), 'G_DPL_LINE/LAST_UPDATED_BY') LAST_UPDATED_BY,
                     extractValue(value(t), 'G_DPL_LINE/LAST_UPDATE_LOGIN') LAST_UPDATE_LOGIN,
                     extractValue(value(t), 'G_DPL_LINE/CHECK_OUT') CHECK_OUT
                from table(XMLSequence(c_xml.extract(c_path))) t) sub
       order by OBJECT_TYPE;
  
    l_xmlType        XMLTYPE;
    l_xmlTypeHeader  XMLTYPE;
    l_xmlTypeLine    XMLTYPE;
    l_clob           CLOB;
    l_clobSub        CLOB;
    l_change_path    varchar2(300);
    l_header_path    varchar2(300);
    l_line_path      varchar2(300);
    l_dpl_header_row xxssys_dpl_headers%ROWTYPE;
    l_dpl_line_row   xxssys_dpl_lines%ROWTYPE;
    ------------------------------
    --    Code Section
    ------------------------------
  begin
    errbuf  := null;
    retcode := '0';
  
    select st.long_text
      into l_clob
      from fnd_attachment_functions     fndattfn,
           fnd_doc_category_usages      fndcatusg,
           fnd_documents_vl             fnddoc,
           fnd_attached_documents       fndattdoc,
           FND_DOCUMENTS_LONG_TEXT      st,
           fnd_doc_categories_active_vl fdca,
           xxssys_dpl_headers           xdh
     where fndattfn.attachment_function_id =
           fndcatusg.attachment_function_id
       and fndcatusg.category_id = fnddoc.category_id
       and fnddoc.document_id = fndattdoc.document_id
       and fndattfn.function_name = 'XXSSYSDPLCONTROL'
       and fndattdoc.entity_name = 'DPL_HEADER_ID'
       and fdca.user_name = C_XXSSYS_DPL_IMPORT --'XXSSYS_DPL_IMPORT'
       and fdca.category_id = fndcatusg.category_id
       and fnddoc.media_id = st.media_id
       and fndattdoc.pk1_value = xdh.dpl_header_id
       and xdh.change_number = p_change_number;
  
    l_change_path := 'XXSSYS_DPL_EXPORTER/LIST_G_CHANGE_LIST/G_CHANGE_LIST';
    l_xmlType     := XMLTYPE.createXML(l_clob);
  
    for change_ind in change_cur(l_xmlType, l_change_path) loop
      begin
        message(change_ind.L_CHANGE_NUMBER);
        l_xmlTypeHeader := change_ind.LIST_G_DPL_HEADER;
        message('LIST_G_DPL_HEADER := ' ||
                dbms_lob.substr(l_xmlTypeHeader.getClobVal(), 32576, 1));
      
        for header_ind in header_cur(l_xmlTypeHeader,
                                     'LIST_G_DPL_HEADER/G_DPL_HEADER',
                                     change_ind.L_CHANGE_NUMBER) loop
        
          message('------------------- HEADER = ' ||
                  change_ind.L_CHANGE_NUMBER ||
                  ' ---------------------------------');
          message(rpad(chr(9), 10) || 'ROW_NUM : ' || header_ind.ROW_NUM);
          message(rpad(chr(9), 10) || 'DPL_HEADER_ID : ' ||
                  header_ind.DPL_HEADER_ID);
          message(rpad(chr(9), 10) || 'CHANGE_NUMBER : ' ||
                  header_ind.CHANGE_NUMBER);
          message(rpad(chr(9), 10) || 'REQUESTED_BY : ' ||
                  header_ind.REQUESTED_BY);
          message(rpad(chr(9), 10) || 'ASSIGNED_TO : ' ||
                  header_ind.ASSIGNED_TO);
          message(rpad(chr(9), 10) || 'CREATED_BY : ' ||
                  header_ind.CREATED_BY);
          message(rpad(chr(9), 10) || 'CREATION_DATE : ' ||
                  header_ind.CREATION_DATE);
          message(rpad(chr(9), 10) || 'LAST_UPDATE_DATE : ' ||
                  header_ind.LAST_UPDATE_DATE);
          message(rpad(chr(9), 10) || 'LAST_UPDATED_BY : ' ||
                  header_ind.LAST_UPDATED_BY);
          message(rpad(chr(9), 10) || 'LAST_UPDATE_LOGIN : ' ||
                  header_ind.LAST_UPDATE_LOGIN);
          message(rpad(chr(9), 10) || 'DPL_LOCATION : ' ||
                  header_ind.DPL_LOCATION);
          message(rpad(chr(9), 10) || 'DPL_HEADER_DESCR : ' ||
                  header_ind.DPL_HEADER_DESCR);
          message(rpad(chr(9), 10) || 'DPL_STATUS : ' ||
                  header_ind.DPL_STATUS);
          message(rpad(chr(9), 10) || 'DPL_ERROR_MESSAGE : ' ||
                  header_ind.DPL_ERROR_MESSAGE);
          l_dpl_header_row                   := null;
          l_dpl_header_row.DPL_HEADER_ID     := XXOBJT.xxssys_dpl_headers_s.NEXTVAL;
          l_dpl_header_row.CHANGE_NUMBER     := header_ind.CHANGE_NUMBER;
          l_dpl_header_row.REQUESTED_BY      := header_ind.REQUESTED_BY;
          l_dpl_header_row.ASSIGNED_TO       := header_ind.ASSIGNED_TO;
          l_dpl_header_row.CREATED_BY        := header_ind.CREATED_BY;
          l_dpl_header_row.CREATION_DATE     := header_ind.CREATION_DATE;
          l_dpl_header_row.LAST_UPDATE_DATE  := header_ind.LAST_UPDATE_DATE;
          l_dpl_header_row.LAST_UPDATED_BY   := header_ind.LAST_UPDATED_BY;
          l_dpl_header_row.LAST_UPDATE_LOGIN := header_ind.LAST_UPDATE_LOGIN;
          l_dpl_header_row.DPL_LOCATION      := header_ind.DPL_LOCATION;
          l_dpl_header_row.DPL_HEADER_DESCR  := 'Coppy - ' ||
                                                header_ind.DPL_HEADER_DESCR;
          l_dpl_header_row.DPL_STATUS        := header_ind.DPL_STATUS;
          l_dpl_header_row.DPL_ERROR_MESSAGE := header_ind.DPL_ERROR_MESSAGE;
        
          insert into XXOBJT.xxssys_dpl_headers values l_dpl_header_row;
        
          l_xmlTypeLine := header_ind.LIST_G_DPL_LINE;
        
          for line_ind in line_cur(l_xmlTypeLine,
                                   'LIST_G_DPL_LINE/G_DPL_LINE') loop
            message('------------------- LINE = ' || line_ind.DPL_LINE_ID);
            message(rpad(chr(9), 20) || 'DPL_HEADER_ID = ' ||
                    line_ind.DPL_HEADER_ID);
            message(rpad(chr(9), 20) || 'DPL_LINE_ID  = ' ||
                    line_ind.DPL_LINE_ID);
            message(rpad(chr(9), 20) || 'OBJECT_TYPE  = ' ||
                    line_ind.OBJECT_TYPE);
            message(rpad(chr(9), 20) || 'SCHEMA  = ' || line_ind.SCHEMA);
            message(rpad(chr(9), 20) || 'OBJECT_NAME  = ' ||
                    line_ind.OBJECT_NAME);
            message(rpad(chr(9), 20) || 'STATUS  = ' || line_ind.STATUS);
            message(rpad(chr(9), 20) || 'ERROR_DESC  = ' ||
                    line_ind.ERROR_DESC);
            message(rpad(chr(9), 20) || 'APPLICATION_SHORT_NAME  = ' ||
                    line_ind.APPLICATION_SHORT_NAME);
            message(rpad(chr(9), 20) || 'CREATED_BY  = ' ||
                    line_ind.CREATED_BY);
            message(rpad(chr(9), 20) || 'CREATION_DATE  = ' ||
                    line_ind.CREATION_DATE);
            message(rpad(chr(9), 20) || 'LAST_UPDATE_DATE  = ' ||
                    line_ind.LAST_UPDATE_DATE);
            message(rpad(chr(9), 20) || 'LAST_UPDATED_BY  = ' ||
                    line_ind.LAST_UPDATED_BY);
            message(rpad(chr(9), 20) || 'LAST_UPDATE_LOGIN  = ' ||
                    line_ind.LAST_UPDATE_LOGIN);
            message(rpad(chr(9), 20) || 'CHECK_OUT  = ' ||
                    line_ind.CHECK_OUT);
          
            l_dpl_line_row                        := null;
            l_dpl_line_row.DPL_HEADER_ID          := l_dpl_header_row.DPL_HEADER_ID;
            l_dpl_line_row.DPL_LINE_ID            := xxobjt.Xxssys_Dpl_Lines_s.nextval;
            l_dpl_line_row.OBJECT_TYPE            := line_ind.OBJECT_TYPE;
            l_dpl_line_row.SCHEMA                 := line_ind.SCHEMA;
            l_dpl_line_row.OBJECT_NAME            := line_ind.OBJECT_NAME;
            l_dpl_line_row.STATUS                 := line_ind.STATUS;
            l_dpl_line_row.ERROR_DESC             := line_ind.ERROR_DESC;
            l_dpl_line_row.APPLICATION_SHORT_NAME := line_ind.APPLICATION_SHORT_NAME;
            l_dpl_line_row.CREATED_BY             := line_ind.CREATED_BY;
            l_dpl_line_row.CREATION_DATE          := line_ind.CREATION_DATE;
            l_dpl_line_row.LAST_UPDATE_DATE       := line_ind.LAST_UPDATE_DATE;
            l_dpl_line_row.LAST_UPDATED_BY        := line_ind.LAST_UPDATED_BY;
            l_dpl_line_row.LAST_UPDATE_LOGIN      := line_ind.LAST_UPDATE_LOGIN;
            l_dpl_line_row.CHECK_OUT              := line_ind.CHECK_OUT;
          
            insert into xxobjt.xxssys_dpl_lines values l_dpl_line_row;
          
          end loop;
        end loop;
      
        commit;
      exception
        when others then
          errbuf  := 'EXCEPTION_OTHERS xxssys_dpl_pkg.xml_importer( CHANGE_NUMBER = ' ||
                     change_ind.L_CHANGE_NUMBER || ' ) ' || sqlerrm;
          retcode := '2';
          message(errbuf);
          rollback;
      end;
    end loop;
  
  exception
    when others then
      retcode := '2';
      errbuf  := 'EXCEPTION_OTHERS xxssys_dpl_pkg.xml_importer() - ' ||
                 sqlerrm;
      message(errbuf);
  end xml_importer;
  --------------------------------------------------------------------------
  -- Ver   When         Who          Descr
  -- ----  -----------  -----------  ---------------------------------------
  -- 1.0   17/05/2020   Roman W.
  --------------------------------------------------------------------------
  procedure execute_btn(p_changes_list in VARCHAR2,
                        p_action       in VARCHAR2,
                        p_error_code   out VARCHAR2,
                        p_error_desc   out VARCHAR2) is
    -----------------------------
    --    Local Definitioin
    -----------------------------
    cursor change_num_cur(C_CHANGE_LIST VARCHAR2) is
      with change_num_list as
       (select trim(CHANGE_NUMBER) CHANGE_NUMBER
          from (select regexp_substr(C_CHANGE_LIST, '[^,]+', 1, level) CHANGE_NUMBER
                  from dual
                connect by regexp_substr(C_CHANGE_LIST, '[^,]+', 1, level) is not null)
         group by trim(CHANGE_NUMBER))
      select xdh.change_number, xdh.dpl_header_id
        from change_num_list cnl, xxssys_dpl_headers xdh
       where trim(cnl.CHANGE_NUMBER) = trim(xdh.change_number);
  
    l_request_id NUMBER;
    -----------------------------
    --    Code Section
    -----------------------------
  begin
    p_error_code := '0';
    p_error_desc := null;
  
    if 'XML_EXPORTER' = p_action then
      l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                                 program     => 'XXSSYS_DPL_EXPORTER',
                                                 description => '',
                                                 start_time  => '',
                                                 sub_request => FALSE,
                                                 argument1   => p_changes_list);
    
      commit;
    
      if l_request_id <= 0 then
        p_error_code := '2';
        p_error_desc := 'ERROR : conccurent XXSSYS_DPL_EXPORTER not submited ';
      end if;
    
    else
      for change_num_ind in change_num_cur(p_changes_list) loop
        message(change_num_ind.CHANGE_NUMBER || ' - ' ||
                change_num_ind.dpl_header_id);
      
        if 'CHECK_OUT' = p_action then
          xxssys_dpl_pkg.xxssys_create_dpl_folder_sbm(p_header_id     => change_num_ind.dpl_header_id,
                                                      p_change_number => change_num_ind.CHANGE_NUMBER,
                                                      p_request_id    => l_request_id,
                                                      p_error_code    => p_error_code,
                                                      p_error_desc    => p_error_desc);
        
        elsif 'ADD_ZIP_TO_HEADER' = p_action then
          xxssys_dpl_pkg.submit_add_dpl_zip_to_change(p_dpl_header_id => change_num_ind.dpl_header_id,
                                                      p_change_number => change_num_ind.CHANGE_NUMBER,
                                                      p_request_id    => l_request_id,
                                                      p_error_code    => p_error_code,
                                                      p_error_desc    => p_error_desc);
        elsif 'XML_IMPORTER' = p_action then
          l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                                     program     => 'XXSSYS_DPL_IMPORTER',
                                                     description => '',
                                                     start_time  => '',
                                                     sub_request => FALSE,
                                                     argument1   => change_num_ind.CHANGE_NUMBER);
        
          commit;
        
          if l_request_id <= 0 then
            p_error_code := '2';
            p_error_desc := 'ERROR : conccurent XXSSYS_DPL_IMPORTER not submited ';
            message(p_error_desc);
          end if;
        
        end if;
      
      end loop;
    end if;
  
  exception
    when others then
      p_error_code := '2';
      p_error_desc := 'EXCEPTION_OTHERS xxssys_dpl_pkg.execute_btn(' ||
                      p_changes_list || ',' || p_action || ',' ||
                      p_error_code || ',' || p_error_desc || ') - ' ||
                      sqlerrm;
      message(p_error_desc);
  end execute_btn;

end xxssys_dpl_pkg;
/
