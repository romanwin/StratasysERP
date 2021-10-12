CREATE OR REPLACE PACKAGE xxconv_crm_sr_api_pkg IS

  PROCEDURE insert_api_sr(errbuf            OUT VARCHAR2,
                          retcode           OUT VARCHAR2,
                          p_validation_only IN VARCHAR2);
  /*Procedure read_task_csv_file (errbuf      out varchar2,
                                   retcode     out varchar2,
                                   p_location  in  varchar2,
                                   p_filename  in  varchar2);
  Procedure Create_Task_Api(errbuf      out varchar2,
                            retcode     out varchar2);*/
-- PROCEDURE create_note;
-- PROCEDURE create_task_assignee;

END xxconv_crm_sr_api_pkg;
/

