CREATE OR REPLACE  PACKAGE BODY "APPS"."XXSSYS_FILE_UTIL_PKG" as
  -------------------------------------------------------------------------------------------
  -- Ver    When        Who         Description
  -- -----  ----------  ----------  ------------------------------------------------------------
  -- 1.0    09/01/2019              CHG0044283 - init version
  -- 1.1    02/02/2020   Roman W.   CHG0047365 - Spare Part files – change file location  
  -------------------------------------------------------------------------------------------

  --------------------------------------------------------------------------
  -- Ver   When        Who           Description
  -- ----  ----------  ------------  ---------------------------------------
  -- 1.0   11/01/2019  Roman W.      CHG0046921 
  --------------------------------------------------------------------------
  procedure message(p_msg in varchar2) is
    l_msg varchar(4000);
  
  begin
  
    l_msg := to_char(sysdate, 'DD/MM/YYYY HH24:MI:SS') || p_msg;
  
    if fnd_global.CONC_REQUEST_ID > 0 then
      fnd_file.put_line(fnd_file.LOG, l_msg);
    else
      dbms_output.put_line(l_msg);
    end if;
  
  end message;

  -------------------------------------------------------------------------------------------
  -- Ver     When        Who         Description
  -- ------  ----------  ----------  ------------------------------------------------------------
  -- 1.0     09/01/2019               CHG0044283 - copy part of string
  -------------------------------------------------------------------------------------------

  function copy_str(p_string   in varchar2,
                    p_from_pos in number := 1,
                    p_to_pos   in number := null) return varchar2 as
    l_to_pos      pls_integer;
    l_returnvalue t_max_pl_varchar2;
  begin
  
    if (p_string is null) or (p_from_pos <= 0) then
      l_returnvalue := null;
    else
    
      if p_to_pos is null then
        l_to_pos := length(p_string);
      else
        l_to_pos := p_to_pos;
      end if;
    
      if l_to_pos > length(p_string) then
        l_to_pos := length(p_string);
      end if;
    
      l_returnvalue := substr(p_string,
                              p_from_pos,
                              l_to_pos - p_from_pos + 1);
    
    end if;
  
    return l_returnvalue;
  
  end copy_str;
  -------------------------------------------------------------------------------------------
  -- Ver     When        Who         Description
  -- ------  ----------  ----------  ------------------------------------------------------------
  -- 1.0     09/01/2019               CHG0044283 - resolve filename, ie. properly concatenate dir and filename
  -------------------------------------------------------------------------------------------
  function resolve_filename(p_dir       in varchar2,
                            p_file_name in varchar2,
                            p_os        in varchar2 := g_os_windows)
    return varchar2 as
    l_returnvalue t_file_name;
  begin
  
    if lower(p_os) = g_os_windows then
    
      if substr(p_dir, -1) = g_dir_sep_win then
        l_returnvalue := p_dir || p_file_name;
      else
        if p_dir is not null then
          l_returnvalue := p_dir || g_dir_sep_win || p_file_name;
        else
          l_returnvalue := p_file_name;
        end if;
      end if;
    
    elsif lower(p_os) = g_os_unix then
    
      if substr(p_dir, -1) = g_dir_sep_unix then
        l_returnvalue := p_dir || p_file_name;
      else
        if p_dir is not null then
          l_returnvalue := p_dir || g_dir_sep_unix || p_file_name;
        else
          l_returnvalue := p_file_name;
        end if;
      end if;
    
    else
      l_returnvalue := null;
    end if;
  
    return l_returnvalue;
  
  end resolve_filename;

  -------------------------------------------------------------------------------------------
  -- Ver     When        Who         Description
  -- ------  ----------  ----------  ------------------------------------------------------------
  -- 1.0     09/01/2019               CHG0044283 - return the filename portion of the full file name
  -------------------------------------------------------------------------------------------
  function extract_filename(p_file_name in varchar2,
                            p_os        in varchar2 := g_os_windows)
    return varchar2 as
    l_returnvalue t_file_name;
    l_dir_sep     t_dir_sep;
    l_dir_sep_pos pls_integer;
  begin
  
    if lower(p_os) = g_os_windows then
      l_dir_sep := g_dir_sep_win;
    elsif lower(p_os) = g_os_unix then
      l_dir_sep := g_dir_sep_unix;
    end if;
  
    if lower(p_os) in (g_os_windows, g_os_unix) then
    
      l_dir_sep_pos := instr(p_file_name, l_dir_sep, -1);
      if l_dir_sep_pos = 0 then
        -- no directory found
        l_returnvalue := p_file_name;
      else
        -- copy filename part
        l_returnvalue := copy_str(p_file_name, l_dir_sep_pos + 1);
      end if;
    
    else
      l_returnvalue := null;
    end if;
  
    return l_returnvalue;
  
  end extract_filename;

  -------------------------------------------------------------------------------------------
  -- Ver     When        Who         Description
  -- ------  ----------  ----------  ------------------------------------------------------------
  -- 1.0     09/01/2019               CHG0044283 - get file extension
  -------------------------------------------------------------------------------------------
  function get_file_ext(p_file_name in varchar2) return varchar2 as
    l_sep_pos     pls_integer;
    l_returnvalue t_file_name;
  begin
  
    l_sep_pos := instr(p_file_name, g_file_ext_sep, -1);
  
    if l_sep_pos = 0 then
      -- no extension found
      l_returnvalue := null;
    else
      -- copy extension
      l_returnvalue := copy_str(p_file_name, l_sep_pos + 1);
    end if;
  
    return l_returnvalue;
  
  end get_file_ext;

  -------------------------------------------------------------------------------------------
  -- Ver     When        Who         Description
  -- ------  ----------  ----------  ------------------------------------------------------------
  -- 1.0     09/01/2019               CHG0044283 - strip file extension
  -------------------------------------------------------------------------------------------
  function strip_file_ext(p_file_name in varchar2) return varchar2 as
    l_sep_pos     pls_integer;
    l_file_ext    t_file_name;
    l_returnvalue t_file_name;
  begin
  
    l_file_ext := get_file_ext(p_file_name);
  
    if l_file_ext is not null then
      l_sep_pos := instr(p_file_name, g_file_ext_sep || l_file_ext, -1);
      -- copy everything except extension
      if l_sep_pos > 0 then
        l_returnvalue := copy_str(p_file_name, 1, l_sep_pos - 1);
      else
        l_returnvalue := p_file_name;
      end if;
    else
      l_returnvalue := p_file_name;
    end if;
  
    return l_returnvalue;
  
  end strip_file_ext;

  -------------------------------------------------------------------------------------------
  -- Ver     When        Who         Description
  -- ------  ----------  ----------  ------------------------------------------------------------
  -- 1.0     09/01/2019               CHG0044283 - returns string suitable for file names, ie.
  --                                                   no whitespace or special path characters
  -------------------------------------------------------------------------------------------
  function get_filename_str(p_str       in varchar2,
                            p_extension in varchar2 := null) return varchar2 as
    l_returnvalue t_file_name;
  begin
  
    l_returnvalue := replace(replace(replace(replace(trim(p_str), ' ', '_'),
                                             '\',
                                             '_'),
                                     '/',
                                     '_'),
                             ':',
                             '');
  
    if p_extension is not null then
      l_returnvalue := l_returnvalue || '.' || p_extension;
    end if;
  
    return l_returnvalue;
  
  end get_filename_str;

  -------------------------------------------------------------------------------------------
  -- Ver     When        Who         Description
  -- ------  ----------  ----------  ------------------------------------------------------------
  -- 1.0     09/01/2019               CHG0044283 - Get blob from file
  -------------------------------------------------------------------------------------------
  function get_blob_from_file(p_directory_name in varchar2,
                              p_file_name      in varchar2) return blob as
    l_bfile       bfile;
    l_returnvalue blob;
  begin
  
    dbms_lob.createtemporary(l_returnvalue, false);
    l_bfile := bfilename(p_directory_name, p_file_name);
    dbms_lob.fileopen(l_bfile, dbms_lob.file_readonly);
    dbms_lob.loadfromfile(l_returnvalue,
                          l_bfile,
                          dbms_lob.getlength(l_bfile));
    dbms_lob.fileclose(l_bfile);
  
    return l_returnvalue;
  
  exception
    when others then
      if dbms_lob.fileisopen(l_bfile) = 1 then
        dbms_lob.fileclose(l_bfile);
      end if;
      dbms_lob.freetemporary(l_returnvalue);
      raise;
    
  end get_blob_from_file;

  -------------------------------------------------------------------------------------------
  -- Ver     When        Who         Description
  -- ------  ----------  ----------  ------------------------------------------------------------
  -- 1.0     09/01/2019               CHG0044283 - Get clob from file
  -------------------------------------------------------------------------------------------
  function get_clob_from_file(p_directory_name in varchar2,
                              p_file_name      in varchar2) return clob as
    l_bfile       bfile;
    l_returnvalue clob;
  begin
  
    dbms_lob.createtemporary(l_returnvalue, false);
    l_bfile := bfilename(p_directory_name, p_file_name);
    dbms_lob.fileopen(l_bfile, dbms_lob.file_readonly);
    dbms_lob.loadfromfile(l_returnvalue,
                          l_bfile,
                          dbms_lob.getlength(l_bfile));
    dbms_lob.fileclose(l_bfile);
  
    return l_returnvalue;
  
  exception
    when others then
      if dbms_lob.fileisopen(l_bfile) = 1 then
        dbms_lob.fileclose(l_bfile);
      end if;
      dbms_lob.freetemporary(l_returnvalue);
      raise;
    
  end get_clob_from_file;

  -------------------------------------------------------------------------------------------
  -- Ver     When        Who         Description
  -- ------  ----------  ----------  ------------------------------------------------------------
  -- 1.0     09/01/2019               CHG0044283 - save blob to file
  -------------------------------------------------------------------------------------------
  procedure save_blob_to_file(p_directory_name in varchar2,
                              p_file_name      in varchar2,
                              p_blob           in blob) as
    l_file     utl_file.file_type;
    l_buffer   raw(32767);
    l_amount   binary_integer := 32767;
    l_pos      integer := 1;
    l_blob_len integer;
  begin
  
    l_blob_len := dbms_lob.getlength(p_blob);
  
    l_file := utl_file.fopen(p_directory_name,
                             p_file_name,
                             g_file_mode_write_byte,
                             32767);
  
    while l_pos < l_blob_len loop
      dbms_lob.read(p_blob, l_amount, l_pos, l_buffer);
      utl_file.put_raw(l_file, l_buffer, true);
      l_pos := l_pos + l_amount;
    end loop;
  
    utl_file.fclose(l_file);
  
  exception
    when others then
      if utl_file.is_open(l_file) then
        utl_file.fclose(l_file);
      end if;
      raise;
    
  end save_blob_to_file;

  -------------------------------------------------------------------------------------------
  -- Ver     When        Who         Description
  -- ------  ----------  ----------  ------------------------------------------------------------
  -- 1.0     09/01/2019               CHG0044283 - save clob to file
  -- 1.1     05/02/2020  Roman W.     CHG0047365 - changing clob2file save method   
  --                                      by using oracle api dbms_xslprocessor.clob2file
  -------------------------------------------------------------------------------------------
  procedure save_clob_to_file(p_directory_name in varchar2,
                              p_file_name      in varchar2,
                              p_clob           in clob) as
    l_file     utl_file.file_type;
    l_buffer   varchar2(32767);
    l_amount   binary_integer := 8000;
    l_pos      integer := 1;
    l_clob_len integer;
  begin
  
    dbms_xslprocessor.clob2file(flocation => p_directory_name,
                                fname     => p_file_name,
                                cl        => p_clob);
    /* Rem By Roman W.                            
    l_clob_len := dbms_lob.getlength(p_clob);
    
    l_file := utl_file.fopen(p_directory_name,
                             p_file_name,
                             g_file_mode_write_text,
                             32767);
    
    while l_pos < l_clob_len loop
      dbms_lob.read(p_clob, l_amount, l_pos, l_buffer);
      utl_file.put(l_file, l_buffer);
      utl_file.fflush(l_file);
      l_pos := l_pos + l_amount;
    end loop;
    
    utl_file.fclose(l_file);
    */
  
  exception
    when others then
      if utl_file.is_open(l_file) then
        utl_file.fclose(l_file);
      end if;
      raise;
    
  end save_clob_to_file;

  -------------------------------------------------------------------------------------------
  -- Ver     When        Who         Description
  -- ------  ----------  ----------  ------------------------------------------------------------
  -- 1.0     09/01/2019               CHG0044283 - save clob to file
  --                                  see http://forums.oracle.com/forums/thread.jspa?threadID=622875
  -------------------------------------------------------------------------------------------
  procedure save_clob_to_file_raw(p_directory_name in varchar2,
                                  p_file_name      in varchar2,
                                  p_clob           in clob) as
    l_file       utl_file.file_type;
    l_chunk_size pls_integer := 3000;
  begin
  
    l_file := utl_file.fopen(p_directory_name,
                             p_file_name,
                             g_file_mode_write_byte,
                             max_linesize => 32767);
  
    for i in 1 .. ceil(length(p_clob) / l_chunk_size) loop
      utl_file.put_raw(l_file,
                       utl_raw.cast_to_raw(substr(p_clob,
                                                  (i - 1) * l_chunk_size + 1,
                                                  l_chunk_size)));
      utl_file.fflush(l_file);
    end loop;
  
    utl_file.fclose(l_file);
  
  exception
    when others then
      if utl_file.is_open(l_file) then
        utl_file.fclose(l_file);
      end if;
      raise;
    
  end save_clob_to_file_raw;

  -------------------------------------------------------------------------------------------
  -- Ver     When        Who         Description
  -- ------  ----------  ----------  ------------------------------------------------------------
  -- 1.0     09/01/2019               CHG0044283 - does file exist?
  -------------------------------------------------------------------------------------------
  function file_exists(p_directory_name in varchar2,
                       p_file_name      in varchar2) return number as
    l_length      number;
    l_block_size  number;
    l_returnvalue boolean := false;
    l_ret_val     number;
  begin
  
    utl_file.fgetattr(p_directory_name,
                      p_file_name,
                      l_returnvalue,
                      l_length,
                      l_block_size);
    l_ret_val := sys.diutil.bool_to_int(l_returnvalue);
    return l_ret_val;
  
  end file_exists;

  -------------------------------------------------------------------------------------------
  -- Ver     When        Who         Description
  -- ------  ----------  ----------  ------------------------------------------------------------
  -- 1.0     09/01/2019               CHG0044283 - format bytes
  -------------------------------------------------------------------------------------------
  function fmt_bytes(p_bytes in number) return varchar2 as
    l_returnvalue xxssys_file_util_pkg.t_max_db_varchar2;
  begin
  
    l_returnvalue := case
                       when p_bytes is null then
                        null
                       when p_bytes < 1024 then
                        to_char(p_bytes) || ' bytes'
                       when p_bytes < 1048576 then
                        to_char(round(p_bytes / 1024, 1)) || ' kB'
                       when p_bytes < 1073741824 then
                        to_char(round(p_bytes / 1048576, 1)) || ' MB'
                       when p_bytes < 1099511627776 then
                        to_char(round(p_bytes / 1073741824, 1)) || ' GB'
                       else
                        to_char(round(p_bytes / 1099511627776, 1)) || ' TB'
                     end;
  
    return l_returnvalue;
  
  end fmt_bytes;

  -------------------------------------------------------------------------------------
  -- Ver   When         Who        Description
  -- ----  -----------  ---------  ---------------------------------------------
  -- 1.0   02/02/2020   Roman W.   CHG0047365 - Spare Part files – change file location
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
    
      p_error_code := '2';
    
      p_error_desc := 'Request ID: ' || p_request_id || CHR(10) ||
                      'Status    : ' || l_dev_status || CHR(10) ||
                      'Message   : ' || l_message;
    
      message('STATUS : ' || p_error_code || CHR(10) || p_error_desc);
    
    END IF;
  exception
    when others then
      p_error_code := '2';
      p_error_desc := 'EXCEPTION_OTHERS xxssys_file_util_pkg.wait_for_request(' ||
                      p_request_id || ') - ' || sqlerrm;
  end wait_for_request;

  -------------------------------------------------------------------------------------------
  -- Ver   When          Who        Descr
  -- ----  ------------  ---------  --------------------------------------------------------------
  -- 1.0   02/02/2020    Roman W.   CHG0047365 - Spare Part files – change file location
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
      p_error_desc := 'EXCEPTION_OTHERS XXSSYS_FILE_UTIL_PKG.IS_DIRECTORY_VALID(' ||
                      p_directory || ') - ' || SQLERRM;
  END is_directory_valid;

  ------------------------------------------------------------------------------------
  -- Ver   When         Who              Descr 
  -- ----  -----------  ---------------  ---------------------------------------
  -- 1.0   29/01/2020   Roman W.          CHG0047365 - Spare Part files – change file location
  ------------------------------------------------------------------------------------
  procedure create_directory(p_directory_name in varchar2,
                             p_path           in varchar2,
                             p_error_code     out varchar2,
                             p_error_desc     out varchar2) is
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
  
    l_sql := 'CREATE OR REPLACE DIRECTORY ' || p_directory_name || ' AS ''' ||
             p_path || '''';
  
    message(l_sql);
  
    EXECUTE IMMEDIATE l_sql;
  
    commit;
  
  exception
    when others then
      p_error_code := '2';
      p_error_desc := 'EXCEPTION_OTHERS xxssys_file_util_pkg.create_directory(' ||
                      p_directory_name || ',' || p_path || ') - ' ||
                      sqlerrm;
  end create_directory;
  -----------------------------------------------------------------------------------------
  -- Ver   When        Who           Description
  -- ----  ----------  ------------  ------------------------------------------------------
  -- 1.0   29/01/2020  Roman W.      CHG0047365 - Spare Part files – change file location  
  -----------------------------------------------------------------------------------------
  procedure make_directory(p_directory_name in varchar2,
                           p_dir_path       in varchar2,
                           p_error_code     out varchar2,
                           p_error_desc     out varchar2) is
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
  
    p_error_desc := '0';
    p_error_code := NULL;
  
    create_directory(p_directory_name => p_directory_name,
                     p_path           => p_dir_path,
                     p_error_code     => p_error_code,
                     p_error_desc     => p_error_desc);
  
    if '0' != p_error_code then
      return;
    end if;
  
    is_directory_valid(p_directory  => p_directory_name,
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
      else
      
        p_error_code := '2';
        p_error_desc := 'ERROR xxssys_file_util_pkg.make_directory(' ||
                        p_directory_name || ',' || p_dir_path ||
                        ') -  conccuren XXFNDMKDIR (' || p_dir_path ||
                        ') not submited ';
      
      end if;
    end if;
  exception
    when others then
      p_error_code := '2';
      p_error_desc := 'EXCEPTION_OTHERS_1 xxssys_file_util_pkg.make_directory(' ||
                      p_directory_name || ',' || p_dir_path || ') - ' ||
                      sqlerrm;
    
  end make_directory;

end xxssys_file_util_pkg;

/