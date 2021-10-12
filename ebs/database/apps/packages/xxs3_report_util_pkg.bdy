CREATE OR REPLACE PACKAGE BODY xxs3_report_util_pkg

-- --------------------------------------------------------------------------------------------
-- Purpose: This Package is used for single Report Utilty Concurrent Program
--
-- --------------------------------------------------------------------------------------------
-- Ver  Date        Name                          Description
-- 1.0  18/05/2016  TCS                           Initial build
-- --------------------------------------------------------------------------------------------

 AS
  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used to write in concurrent log
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE log_p(i_msg VARCHAR2) IS
  BEGIN

    fnd_file.put_line(fnd_file.log, i_msg);
    /*dbms_output.put_line(i_msg);*/

  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log, 'Error in writting Log File. ' || SQLERRM);
  END log_p;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used to write in concurrent output
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE out_p(i_msg VARCHAR2) IS
  BEGIN

    fnd_file.put_line(fnd_file.output, i_msg);
    /*dbms_output.put_line(i_msg);*/

  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log, 'Error in writting Output File. ' || SQLERRM);
  END out_p;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: This Procedure is used for single Report Utilty Concurrent Program
  --
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  18/05/2016  TCS                           Initial build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE report_util(o_errbuff     OUT VARCHAR2
                       ,o_retcode     OUT VARCHAR2
                       ,i_entity_name IN VARCHAR2
                       ,i_report_type IN VARCHAR2) IS
    i_procedure_name VARCHAR2(150);
  BEGIN
    o_retcode := 0;
    o_errbuff := 'SUCCESS';
    BEGIN
      SELECT description
        INTO i_procedure_name
        FROM fnd_lookup_values
       WHERE lookup_type = 'XXS3_DATA_REPORT_LKP'
         AND substr(TRIM(meaning), 1, instr(TRIM(meaning), '-') - 1) = i_entity_name
         AND substr(TRIM(meaning), instr(TRIM(meaning), '-') + 1) = i_report_type
         AND enabled_flag = 'Y'
         AND LANGUAGE = userenv('LANG')
         AND trunc(SYSDATE) BETWEEN nvl(start_date_active, trunc(SYSDATE)) AND
             nvl(end_date_active, trunc(SYSDATE));
    EXCEPTION
      WHEN OTHERS THEN
        o_retcode := '2';
        o_errbuff := 'SQLERRM: ' || SQLERRM;
        log_p(o_errbuff);
        RETURN;
    END;
    BEGIN
      EXECUTE IMMEDIATE 'BEGIN ' || i_procedure_name || '(''' || i_entity_name || ''') ; END;';
    EXCEPTION
      WHEN OTHERS THEN
        o_retcode := '2';
        o_errbuff := 'SQLERRM: ' || SQLERRM;
        log_p(o_errbuff);
        RETURN;
    END;
  EXCEPTION
    WHEN OTHERS THEN
      o_retcode := '2';
      o_errbuff := 'SQLERRM: ' || SQLERRM;
      log_p(o_errbuff);
  END report_util;

END xxs3_report_util_pkg;
/
