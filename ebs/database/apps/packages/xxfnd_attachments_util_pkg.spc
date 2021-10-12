CREATE OR REPLACE PACKAGE xxfnd_attachments_util_pkg IS
  -----------------------------------------------------------------------------------
  -- Ver    When          Who           Description
  -- -----  ------------  ------------  ------------------------------------------
  -- 1.0                  Roman W.      CHG0044283
  -- 1.1    27/10/2019    Roman W       CHG0046750
  --------------------------------------------------------------------------------------------

  -----------------------------------------------------------------------------------
  -- Ver    When          Who           Description
  -- -----  ------------  ------------  ------------------------------------------
  -- 1.0    09/01/2019    Roman W.      CHG0044283
  -----------------------------------------------------------------------------------
  PROCEDURE get_directory_path(p_org_id         IN VARCHAR2,
                               p_table_name     IN VARCHAR2,
                               p_directory_path OUT VARCHAR2,
                               p_error_code     OUT VARCHAR2,
                               p_error_desc     OUT VARCHAR2);

  -----------------------------------------------------------------------------------
  -- Ver    When          Who           Description
  -- -----  ------------  ------------  ------------------------------------------
  -- 1.0                  Roman W.      CHG0044283
  -----------------------------------------------------------------------------------
  PROCEDURE archive2file_system_main(errbuf                OUT VARCHAR2,
                                     retcode               OUT NUMBER,
                                     p_org_id              IN NUMBER,
                                     p_entity              IN VARCHAR2,
                                     p_date_from           IN VARCHAR2,
                                     p_date_to             IN VARCHAR2,
                                     p_creation_date_setup IN VARCHAR2);

  -------------------------------------------------------------------------------------------
  -- Ver   When          Who        Descr
  -- ----  ------------  ---------  --------------------------------------------------------------
  -- 1.0   27/10/2019    Roman W.
  -------------------------------------------------------------------------------------------
  PROCEDURE is_directory_valid(p_directory  IN VARCHAR2,
                               p_valid_flag OUT VARCHAR2,
                               p_error_code OUT VARCHAR2,
                               p_error_desc OUT VARCHAR2);

  -------------------------------------------------------------------------------------------
  -- Ver     When        Who         Description
  -- ------  ----------  ----------  --------------------------------------------------------
  -- 1.0     27/10/2019  Roman W     CHG0046750
  --------------------------------------------------------------------------------------------
  PROCEDURE attachment2archive(errbuf        OUT VARCHAR2,
                               retcode       OUT NUMBER,
                               p_entity_name IN VARCHAR2,
                               p_max_rows    IN VARCHAR2);

END xxfnd_attachments_util_pkg;
/
