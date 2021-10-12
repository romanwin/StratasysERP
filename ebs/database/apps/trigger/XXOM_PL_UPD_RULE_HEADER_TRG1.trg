CREATE OR REPLACE TRIGGER XXOM_PL_UPD_RULE_HEADER_TRG1
  before UPDATE or DELETE on XXOM_PL_UPD_RULE_HEADER
  for each row
DECLARE
  l_err_code    NUMBER;
  l_err_message VARCHAR2(100);
  l_ord_number  VARCHAR2(20);
BEGIN

  --------------------------------------------------------------------
  --  purpose :        Create Audit row
  --------------------------------------------------------------------
  --  ver  date            name              desc
  --  1.0  07-APR-2017     Diptasurjya       initial build
  --------------------------------------------------------------------
  
  xxqp_utils_pkg.handle_audit_insert('XXOM_PL_UPD_RULE_HEADER',:old.rule_id);
  

EXCEPTION
WHEN OTHERS THEN
     raise_application_error(-20000,'ERROR! '||sqlerrm);
END XXOM_PL_UPD_RULE_HEADER_TRG1;
/
