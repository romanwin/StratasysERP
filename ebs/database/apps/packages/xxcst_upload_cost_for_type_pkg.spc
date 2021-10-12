CREATE OR REPLACE PACKAGE xxcst_upload_cost_for_type_pkg IS

  -- Author  : ELLA.MALCHI
  -- Created : 2009-08-11 20:00:33
  -- Purpose : 

  PROCEDURE process_cost(errbuf            OUT VARCHAR2,
                         retcode           OUT NUMBER,
                         p_cost_type_id    NUMBER,
                         p_organization_id NUMBER);

END xxcst_upload_cost_for_type_pkg;
/

