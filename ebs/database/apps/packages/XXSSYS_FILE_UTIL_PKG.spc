CREATE OR REPLACE  PACKAGE "APPS"."XXSSYS_FILE_UTIL_PKG" as
  -------------------------------------------------------------------------------------------
  -- Ver     When       Who         Description
  -- -----  ----------  ----------  ------------------------------------------------------------
  -- 1.0    09/01/2019              CHG0044283 - init version
  -- 1.1    02/02/2020  Roman W.    CHG0047365 - Spare Part files – change file location    
  -------------------------------------------------------------------------------------------

  g_max_pl_varchar2_def varchar2(32767);
  subtype t_max_pl_varchar2 is g_max_pl_varchar2_def%type;

  g_max_db_varchar2_def varchar2(4000);
  subtype t_max_db_varchar2 is g_max_db_varchar2_def%type;

  -- operating system types
  g_os_windows constant varchar2(1) := 'w';
  g_os_unix    constant varchar2(1) := 'u';

  g_dir_sep_win  constant varchar2(1) := '\';
  g_dir_sep_unix constant varchar2(1) := '/';

  g_file_ext_sep constant varchar2(1) := '.';

  -- file open modes
  g_file_mode_append_text constant varchar2(1) := 'a';
  g_file_mode_append_byte constant varchar2(2) := 'ab';
  g_file_mode_read_text   constant varchar2(1) := 'r';
  g_file_mode_read_byte   constant varchar2(2) := 'rb';
  g_file_mode_write_text  constant varchar2(1) := 'w';
  g_file_mode_write_byte  constant varchar2(2) := 'wb';

  g_file_name_def varchar2(2000);
  subtype t_file_name is g_file_name_def%type;

  g_file_ext_def varchar2(50);
  subtype t_file_ext is g_file_ext_def%type;

  g_dir_sep_def varchar2(1);
  subtype t_dir_sep is g_dir_sep_def%type;

  --------------------------------------------------------------------------
  -- Ver   When        Who           Description
  -- ----  ----------  ------------  ---------------------------------------
  -- 1.0   11/01/2019  Roman W.      CHG0046921 
  --------------------------------------------------------------------------
  procedure message(p_msg in varchar2);

  -- resolve filename
  -------------------------------------------------------------------------------------------
  -- Ver     When        Who         Description
  -- ------  ----------  ----------  ------------------------------------------------------------
  -- 1.0     09/01/2019               CHG0044283 -
  -------------------------------------------------------------------------------------------
  function resolve_filename(p_dir       in varchar2,
                            p_file_name in varchar2,
                            p_os        in varchar2 := g_os_windows)
    return varchar2;

  -------------------------------------------------------------------------------------------
  -- Ver     When        Who         Description
  -- ------  ----------  ----------  --------------------------------------------------------
  -- 1.0     09/01/2019               CHG0044283 - extract filename
  -------------------------------------------------------------------------------------------
  function extract_filename(p_file_name in varchar2,
                            p_os        in varchar2 := g_os_windows)
    return varchar2;

  -------------------------------------------------------------------------------------------
  -- Ver     When        Who         Description
  -- ------  ----------  ----------  --------------------------------------------------------
  -- 1.0     09/01/2019               CHG0044283 - get file extension
  -------------------------------------------------------------------------------------------
  function get_file_ext(p_file_name in varchar2) return varchar2;

  -------------------------------------------------------------------------------------------
  -- Ver     When        Who         Description
  -- ------  ----------  ----------  --------------------------------------------------------
  -- 1.0     09/01/2019               CHG0044283 - strip file extension
  -------------------------------------------------------------------------------------------
  function strip_file_ext(p_file_name in varchar2) return varchar2;

  -------------------------------------------------------------------------------------------
  -- Ver     When        Who         Description
  -- ------  ----------  ----------  --------------------------------------------------------
  -- 1.0     09/01/2019               CHG0044283 - get filename string (no whitespace)
  -------------------------------------------------------------------------------------------
  function get_filename_str(p_str       in varchar2,
                            p_extension in varchar2 := null) return varchar2;

  -------------------------------------------------------------------------------------------
  -- Ver     When        Who         Description
  -- ------  ----------  ----------  --------------------------------------------------------
  -- 1.0     09/01/2019               CHG0044283 - get blob from file
  -------------------------------------------------------------------------------------------
  function get_blob_from_file(p_directory_name in varchar2,
                              p_file_name      in varchar2) return blob;

  -------------------------------------------------------------------------------------------
  -- Ver     When        Who         Description
  -- ------  ----------  ----------  --------------------------------------------------------
  -- 1.0     09/01/2019               CHG0044283 - get clob from file
  -------------------------------------------------------------------------------------------
  function get_clob_from_file(p_directory_name in varchar2,
                              p_file_name      in varchar2) return clob;

  -------------------------------------------------------------------------------------------
  -- Ver     When        Who         Description
  -- ------  ----------  ----------  --------------------------------------------------------
  -- 1.0     09/01/2019               CHG0044283 - save blob to file
  -------------------------------------------------------------------------------------------
  procedure save_blob_to_file(p_directory_name in varchar2,
                              p_file_name      in varchar2,
                              p_blob           in blob);

  -------------------------------------------------------------------------------------------
  -- Ver     When        Who         Description
  -- ------  ----------  ----------  --------------------------------------------------------
  -- 1.0     09/01/2019               CHG0044283 - save clob to file
  -------------------------------------------------------------------------------------------
  procedure save_clob_to_file(p_directory_name in varchar2,
                              p_file_name      in varchar2,
                              p_clob           in clob);

  -------------------------------------------------------------------------------------------
  -- Ver     When        Who         Description
  -- ------  ----------  ----------  --------------------------------------------------------
  -- 1.0     09/01/2019               CHG0044283 - save clob to file (raw)
  -------------------------------------------------------------------------------------------
  procedure save_clob_to_file_raw(p_directory_name in varchar2,
                                  p_file_name      in varchar2,
                                  p_clob           in clob);

  -------------------------------------------------------------------------------------------
  -- Ver     When        Who         Description
  -- ------  ----------  ----------  --------------------------------------------------------
  -- 1.0     09/01/2019               CHG0044283 - does file exist?
  -------------------------------------------------------------------------------------------
  function file_exists(p_directory_name in varchar2,
                       p_file_name      in varchar2) return number;

  -------------------------------------------------------------------------------------------
  -- Ver     When        Who         Description
  -- ------  ----------  ----------  --------------------------------------------------------
  -- 1.0     09/01/2019               CHG0044283 - format bytes
  -------------------------------------------------------------------------------------------
  function fmt_bytes(p_bytes in number) return varchar2;

  -------------------------------------------------------------------------------------
  -- Ver   When         Who        Description
  -- ----  -----------  ---------  ----------------------------------------------------
  -- 1.1   02/02/2020   Roman W.   CHG0047365 - Spare Part files – change file location    
  -------------------------------------------------------------------------------------
  procedure wait_for_request(p_request_id in NUMBER,
                             p_error_code out varchar2,
                             p_error_desc out varchar2);

  -------------------------------------------------------------------------------------------
  -- Ver   When          Who        Descr
  -- ----  ------------  ---------  --------------------------------------------------------------
  -- 1.0   02/02/2020    Roman W.   CHG0047365 - Spare Part files – change file location
  -------------------------------------------------------------------------------------------
  PROCEDURE is_directory_valid(p_directory  IN VARCHAR2,
                               p_valid_flag OUT VARCHAR2,
                               p_error_code OUT VARCHAR2,
                               p_error_desc OUT VARCHAR2);

  --------------------------------------------------------------------------------------
  -- Ver   When         Who        Descr 
  -- ----  -----------  ---------  -----------------------------------------------------
  -- 1.1   02/02/2020   Roman W.   CHG0047365 - Spare Part files – change file location    
  --------------------------------------------------------------------------------------
  procedure create_directory(p_directory_name in varchar2,
                             p_path           in varchar2,
                             p_error_code     out varchar2,
                             p_error_desc     out varchar2);

  -----------------------------------------------------------------------------------------
  -- Ver   When        Who           Description
  -- ----  ----------  ------------  ------------------------------------------------------
  -- 1.0   29/01/2020  Roman W.      CHG0047365 - Spare Part files – change file location  
  -----------------------------------------------------------------------------------------
  procedure make_directory(p_directory_name in varchar2,
                           p_dir_path       in varchar2,
                           p_error_code     out varchar2,
                           p_error_desc     out varchar2);

end xxssys_file_util_pkg;

/