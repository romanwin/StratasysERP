CREATE OR REPLACE PACKAGE "XXSSYS_DPL_PKG" is
  --  C_DPL_ROOT_PATH CONSTANT varchar2(300) := '/UtlFiles/DPL';
  C_DPL_DIRECTORY     CONSTANT varchar2(300) := 'XXSSYS_DPL_DIR';
  C_IN_PROCESS        CONSTANT varchar2(300) := 'IN_PROCESS';
  C_NEW               CONSTANT varchar2(300) := 'NEW';
  C_SUCCESS           CONSTANT varchar2(300) := 'SUCCESS';
  C_ERROR             CONSTANT varchar2(300) := 'ERROR';
  C_DATE_FORMAT       CONSTANT varchar2(300) := 'DD/MM/YYYY HH24:MI:SS';
  C_XXSSYS_DPL_IMPORT CONSTANT varchar2(300) := 'XXSSYS_DPL_IMPORT';
  P_CHANGE_LIST VARCHAR2(240);
  ---------------------------------------------------------------------------
  -- Ver   When         Who           Description
  -- ----  -----------  ------------  ---------------------------------------
  -- 1.0                Roman W.      CHG0046921 initialization
  -- 1.1   11/02/2021   Roman W.      CHG0049395  bugfix in "replace_clob"
  ---------------------------------------------------------------------------  

  /*
  
  DECLARE
    req_id fnd_concurrent_requests.request_id%TYPE;
  
    l_user_id                 NUMBER;
    l_resp_id                 NUMBER;
    l_resp_appl_id            NUMBER;
    lv_APPLICATION_SHORT_NAME VARCHAR2(300);
    lv_RESPONSIBILITY_KEY     VARCHAR2(300);
    l_responsibility_name     VARCHAR2(300);
  
  BEGIN
    ------------------------------------------------------------
    --                  Apps initializa
    ------------------------------------------------------------
    SELECT fnd.user_id,
           fresp.responsibility_id,
           fresp.application_id,
           fresp.responsibility_name
      into l_user_id,
           l_resp_id,
           l_resp_appl_id,
           l_responsibility_name
      FROM fnd_user fnd, fnd_responsibility_tl fresp
     WHERE fnd.user_name = 'ROMAN.WINER'
       AND fresp.responsibility_name = 'Applications Operations - IT USE ONLY'
     group by fnd.user_id,
              fresp.responsibility_id,
              fresp.application_id,
              fresp.responsibility_name;
  
    select fav.APPLICATION_SHORT_NAME, frv.RESPONSIBILITY_KEY
      into lv_APPLICATION_SHORT_NAME, lv_RESPONSIBILITY_KEY
      from fnd_responsibility_vl frv, fnd_application_vl fav
     where 1 = 1
       and frv.RESPONSIBILITY_NAME = 'Applications Operations - IT USE ONLY'
       and frv.APPLICATION_ID = fav.APPLICATION_ID;
  
    fnd_global.APPS_INITIALIZE(l_user_id, l_resp_id, l_resp_appl_id);
    mo_global.init(lv_APPLICATION_SHORT_NAME);
    ------------------------------------------------------------
    --                End Apps initialize
    ------------------------------------------------------------
  --  FNDLOAD apps/sppa O Y DOWNLOAD $FND_TOP/patch/115/import/afcpprog.lct /UtlFiles/RW/XX_CONCURRENT_PROGRAM_CONC.ldt PROGRAM APPLICATION_SHORT_NAME="XXOBJT" CONCURRENT_PROGRAM_NAME="XXRW_TEST"
  
    req_id := fnd_request.submit_request(application => 'FND',
                                         program     => 'FNDLOAD',
                                         description => NULL,
                                         start_time  => NULL,
                                         sub_request => FALSE,
                                         argument1   => 'DOWNLOAD',
                                         argument2   => '@fnd:patch/115/import/afcpprog.lct',
                                         argument3   => '/UtlFiles/RW/XX_CONCURRENT_PROGRAM_CONC2.ldt',
                                         argument4   => 'PROGRAM',
                                         argument5   => 'APPLICATION_SHORT_NAME=XXOBJT',
                                         argument6   => 'CONCURRENT_PROGRAM_NAME=XXRW_TEST');
  
  
    DBMS_OUTPUT.put_line('req_id = ' || req_id);
    COMMIT;
  
  END;
  
  */

  --------------------------------------------------------------------------
  -- Ver   When        Who           Description
  -- ----  ----------  ------------  ---------------------------------------
  -- 1.0   11/01/2019  Roman W.
  --------------------------------------------------------------------------
  procedure message(p_msg in varchar2);

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
                                   p_error_desc    out VARCHAR2);

  --------------------------------------------------------------------------
  -- Ver   When        Who           Description
  -- ----  ----------  ------------  ---------------------------------------
  -- 1.0   11/01/2019  Roman W.      CHG0046921 - Create automatically DPL folder
  --------------------------------------------------------------------------
  procedure wait_for_request(p_request_id in number,
                             p_error_code out varchar2,
                             p_error_desc out varchar2);

  --------------------------------------------------------------------------
  -- Ver   When        Who           Description
  -- ----  ----------  ------------  ---------------------------------------
  -- 1.0   01/11/2019  Bellona.B     CHG0046921 - Create automatically DPL folder
  --------------------------------------------------------------------------
  function get_top_path(p_top in varchar2) RETURN VARCHAR2;

  --------------------------------------------------------------------------
  -- Ver   When        Who           Description
  -- ----  ----------  ------------  ---------------------------------------
  -- 1.0   11/01/2019  Roman W.      CHG0046921 - Create automatically DPL folder
  --------------------------------------------------------------------------
  procedure create_directory(p_path       in varchar2,
                             p_directory  in varchar2,
                             p_error_code out varchar2,
                             p_error_desc out varchar2);

  -------------------------------------------------------------------------------------------
  -- Ver   When          Who        Descr
  -- ----  ------------  ---------  --------------------------------------------------------------
  -- 1.0   11/12/2019    Bellona.B  CHG0046921 - Create automatically DPL folder
  -------------------------------------------------------------------------------------------
  PROCEDURE is_directory_valid(p_directory  in varchar2,
                               p_valid_flag out varchar2,
                               p_error_code out varchar2,
                               p_error_desc out varchar2);

  --------------------------------------------------------------------------
  -- Ver   When        Who           Description
  -- ----  ----------  ------------  ---------------------------------------
  -- 1.0   01/11/2019  Bellona.B     CHG0046921 - Create automatically DPL folder
  --------------------------------------------------------------------------
  PROCEDURE make_directory(p_dir_path   in varchar2,
                           p_directory  in varchar2,
                           p_error_code out varchar2,
                           p_error_desc out varchar2);

  --------------------------------------------------------------------------
  -- Ver   When        Who           Description
  -- ----  ----------  ------------  ---------------------------------------
  -- 1.0   30/12/2019  Roman W.      CHG0046921
  --------------------------------------------------------------------------
  procedure submit_fndwfload(p_full_path   in VARCHAR2,
                             p_file_name   in VARCHAR2,
                             p_object_name in VARCHAR2,
                             p_error_code  out varchar2,
                             p_error_desc  out varchar2);
  --------------------------------------------------------------------------
  -- Ver   When        Who           Description
  -- ----  ----------  ------------  ---------------------------------------
  -- 1.0   11/01/2019  Roman W.      CHG0046921 - Create automatically DPL folder
  --------------------------------------------------------------------------
  procedure submit_fndload(p_argument2  in varchar2,
                           p_argument3  in varchar2,
                           p_argument4  in varchar2,
                           p_argument5  in varchar2,
                           p_argument6  in varchar2,
                           p_error_code out varchar2,
                           p_error_desc out varchar2);

  --------------------------------------------------------------------------
  -- Ver   When        Who           Description
  -- ----  ----------  ------------  ---------------------------------------
  -- 1.0   30/10/2019  Bellon.B      CHG0046921 - Create automatically DPL folder
  --------------------------------------------------------------------------
  procedure submit_xxcpfile(p_obj_type         in varchar2,
                            p_obj_name         in varchar2,
                            p_target_directory in varchar2,
                            p_error_code       out varchar2,
                            p_error_desc       out varchar2);

  --------------------------------------------------------------------------
  -- Ver    When           Who              Descr
  -- -----  -------------  ---------------  --------------------------------
  -- 1.0    27/01/2020     Roman W.         CHG0046921
  --------------------------------------------------------------------------
  procedure submit_zip_folder(p_path          IN VARCHAR2,
                              p_change_number IN VARCHAR2,
                              p_error_code    OUT VARCHAR2,
                              p_error_desc    OUT VARCHAR2);

  --------------------------------------------------------------------------
  -- Ver    When           Who              Descr
  -- -----  -------------  ---------------  --------------------------------
  -- 1.0    10/02/2020     Roman W.         CHG0046921
  --------------------------------------------------------------------------
  procedure submit_add_dpl_zip_to_change(p_dpl_header_id IN VARCHAR2,
                                         p_change_number IN VARCHAR2,
                                         p_request_id    OUT NUMBER,
                                         p_error_code    OUT VARCHAR2,
                                         p_error_desc    OUT VARCHAR2);
  --------------------------------------------------------------------------
  -- Ver   When        Who           Description
  -- ----  ----------  ------------  ---------------------------------------
  -- 1.0   11/01/2019  Roman W.      CHG0046921 - Create automatically DPL folder
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
                         p_error_desc             out varchar2);
  --------------------------------------------------------------------------
  -- Ver    When        Who         Description
  -- -----  ----------  ----------  ------------------------------------------
  -- 1.0    15/10/2019  Roman W.    CHG0046921 - Create automatically DPL folder
  --------------------------------------------------------------------------
  FUNCTION replace_clob(p_clob         IN CLOB,
                        p_replace_str  IN varchar2,
                        p_replace_with IN varchar2) RETURN CLOB;
  --------------------------------------------------------------------------
  -- Ver    When        Who         Description
  -- -----  ----------  ----------  ------------------------------------------
  -- 1.0    15/10/2019  Roman W.    CHG0046921 - Create automatically DPL folder
  --------------------------------------------------------------------------
  procedure get_db_object(p_object_type in varchar2,
                          p_name        in varchar2,
                          p_schema      in varchar2,
                          p_db_object   out clob,
                          p_error_code  out varchar2,
                          p_error_desc  out varchar2);

  -------------------------------------------------------------------------
  -- Ver   When         Who          Descr 
  -- ----  -----------  -----------  --------------------------------------
  -- 1.0   09/09/2020   Roman W.     CHG0046921
  -------------------------------------------------------------------------
  procedure remove_file(p_directory  in varchar2,
                        p_file_name  in varchar2,
                        p_error_code out varchar2,
                        p_error_desc out varchar2);
  -------------------------------------------------------------------------------
  -- Ver    When        Who            Descr
  -- -----  ----------  -------------  ------------------------------------------
  -- 1.0    2019-10-15  Roman W        CHG0046921 - Create automatically DPL folder
  --                                      Executable : XX: SSYS Create DPL folder / XXSSYS_CREATE_DPL_FOLDER
  -------------------------------------------------------------------------------
  procedure main(errbuf          OUT VARCHAR2,
                 retcode         OUT NUMBER,
                 p_change_number IN VARCHAR2);

  ----------------------------------------------------------------
  -- Ver   When         Who           Description
  -- ----- -----------  ------------  ----------------------------
  -- 1.0   07/01/2019   Roman W.      CHG0046921
  --                                      submit concurrent : XX: SSYS Create DPL folder / XXSSYS_CREATE_DPL_FOLDER
  ----------------------------------------------------------------
  procedure xxssys_create_dpl_folder_sbm(p_header_id     in NUMBER,
                                         p_change_number in VARCHAR2,
                                         p_request_id    out NUMBER,
                                         p_error_code    out VARCHAR2,
                                         p_error_desc    out VARCHAR2);

  -------------------------------------------------------------------------------
  -- Ver      When         Who              Description
  -- -------  -----------  ---------------  -------------------------------------
  -- 1.0      09/02/2020   Roman W.         CHG0046921
  -------------------------------------------------------------------------------
  procedure add_attachment(p_dpl_header_id IN NUMBER,
                           p_change_number IN varchar2,
                           p_file_name     IN varchar2,
                           p_error_code    OUT varchar2,
                           p_error_desc    OUT varchar2);

  -------------------------------------------------------------------------------
  -- Ver   When         Who          Descr
  -- ----  -----------  -----------  --------------------------------------------
  -- 1.0   04/04/2020   Roman W.     CHG0046921
  -------------------------------------------------------------------------------
  procedure get_change_dpl_path(p_change_number IN VARCHAR2,
                                p_path          OUT VARCHAR2,
                                p_error_code    OUT VARCHAR2,
                                p_error_desc    OUT VARCHAR2);
  -------------------------------------------------------------------------------
  -- Ver      When         Who              Description
  -- -------  -----------  ---------------  -------------------------------------
  -- 1.0      27/01/2020   Roman W.         CHG0046921
  -------------------------------------------------------------------------------
  procedure add_zip_to_change(errbuf          OUT VARCHAR2,
                              retcode         OUT NUMBER,
                              p_dpl_header_id IN NUMBER,
                              p_change_number IN VARCHAR2);

  ---------------------------------------------------------------------------------
  -- Ver   When        Who             Descr
  -- ----  ----------  --------------  --------------------------------------------
  -- 1.0   12/04/2020  Roman W.        CHG0046921
  ---------------------------------------------------------------------------------
  function after_dpl_exporter return boolean;

  ---------------------------------------------------------------------------------
  -- Ver   When        Who             Descr
  -- ----  ----------  --------------  --------------------------------------------
  -- 1.0   12/04/2020  Roman W.        CHG0046921
  ---------------------------------------------------------------------------------
  procedure xml_importer(errbuf          OUT VARCHAR2,
                         retcode         OUT NUMBER,
                         p_change_number IN VARCHAR2);

  --------------------------------------------------------------------------
  -- Ver   When         Who          Descr
  -- ----  -----------  -----------  ---------------------------------------
  -- 1.0   17/05/2020   Roman W.
  --------------------------------------------------------------------------
  procedure execute_btn(p_changes_list in VARCHAR2,
                        p_action       in VARCHAR2,
                        p_error_code   out VARCHAR2,
                        p_error_desc   out VARCHAR2);

end xxssys_dpl_pkg;
/
