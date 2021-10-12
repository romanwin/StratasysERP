CREATE OR REPLACE PACKAGE xxobjt_xml_gen_pkg AUTHID CURRENT_USER IS
  ---------------------------------------------------------------------------
  -- $Header: xxobjt_xml_gen_pkg   $
  ---------------------------------------------------------------------------
  -- Package: XXOBJT_XML_GEN_PKG
  -- Created:
  -- Author:
  --------------------------------------------------------------------------
  -- Purpose: CUST-751 - Generic xml file generation (CR1047)
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  24.9.13   Vitaly         initial build
  ------------------------------------------------------------------
  FUNCTION validate_query(p_file_code           IN VARCHAR2,
                          p_error_message       OUT VARCHAR2,
                          p_num_of_rows_fetched OUT NUMBER) RETURN VARCHAR2; ---Return values: 'VALID','INVALID'
  PROCEDURE create_xml_file(errbuf             OUT VARCHAR2,
                            retcode            OUT VARCHAR2,
                            p_file_code        IN VARCHAR2,
                            p_directory        IN VARCHAR2,
                            p_file_name_prefix IN VARCHAR2,
                            p_param1           IN VARCHAR2,
                            p_param2           IN VARCHAR2,
                            p_param3           IN VARCHAR2,
                            p_param4           IN VARCHAR2,
                            p_param5           IN VARCHAR2,
                            p_param6           IN VARCHAR2);

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
                            p_param6           IN VARCHAR2 DEFAULT NULL);

  PROCEDURE update_log(p_file_id   NUMBER,
                       p_status    VARCHAR2,
                       p_row_count NUMBER DEFAULT NULL,
                       p_message   VARCHAR2 DEFAULT NULL);

  PROCEDURE update_log(p_file_name        VARCHAR2,
                       p_status           VARCHAR2,
                       p_row_count        NUMBER DEFAULT NULL,
                       p_row_count_verify NUMBER DEFAULT NULL,
                       p_message          VARCHAR2 DEFAULT NULL,
                       p_err_code         OUT NUMBER,
                       p_err_message      OUT VARCHAR2);

END xxobjt_xml_gen_pkg;
/
