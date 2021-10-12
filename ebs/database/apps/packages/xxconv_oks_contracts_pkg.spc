CREATE OR REPLACE PACKAGE xxconv_oks_contracts_pkg IS

   PROCEDURE load_contracts(errbuf OUT VARCHAR2, retcode OUT VARCHAR2);

   PROCEDURE fix_inv_organization;

   PROCEDURE restore_coverage;

   PROCEDURE apply_standard;

END xxconv_oks_contracts_pkg;
/

