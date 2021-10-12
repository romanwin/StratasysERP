CREATE OR REPLACE VIEW XXS3_REPORT_ENTITY_V AS
SELECT DISTINCT substr(TRIM(a.meaning), 1, instr(TRIM(a.meaning), '-') - 1) entity_name
  FROM fnd_lookup_values a
 WHERE a.lookup_type = 'XXS3_DATA_REPORT_LKP'
   AND a.enabled_flag = 'Y'
   AND a.LANGUAGE = userenv('LANG')
   and trunc(SYSDATE) BETWEEN nvl(a.start_date_active, trunc(SYSDATE)) AND
             nvl(a.end_date_active, trunc(SYSDATE))
 ORDER BY 1
/

CREATE OR REPLACE VIEW XXS3_REPORT_TYPE_V AS
SELECT DISTINCT substr(TRIM(meaning), instr(TRIM(meaning), '-') + 1) report_type
               ,substr(TRIM(meaning), 1, instr(TRIM(meaning), '-') - 1) entity_name
  FROM fnd_lookup_values
 WHERE lookup_type = 'XXS3_DATA_REPORT_LKP'
   AND enabled_flag = 'Y'
   AND LANGUAGE = userenv('LANG')
   and trunc(SYSDATE) BETWEEN nvl(start_date_active, trunc(SYSDATE)) AND
             nvl(end_date_active, trunc(SYSDATE))
/
