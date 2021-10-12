create or replace package xxhz_customer_credit_int_pkg IS
  --------------------------------------------------------------------
  --  customization code: CHG0034610
  --  name:               XXHZ_CUSTOMER_CREDIT_INT_PKG
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  creation date:      19/04/2015
  --  Description:        Upload Customer credit data from Atradius
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   19/04/2015    Michal Tzvik    initial build
  --  1.1   03/11/2019    Bellona.B       CHG0046362 - Mass Upload of customer credit limit
  --------------------------------------------------------------------
  PROCEDURE handle_data(errbuf                   OUT VARCHAR2,
		retcode                  OUT VARCHAR2,
		p_partial_customer_match VARCHAR2);

  FUNCTION convert_name(p_party_name VARCHAR2) RETURN VARCHAR2;
  --------------------------------------------------------------------
  --  name:               main
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  customization code: CHG0034610 - Upload Customer credit data from Atradius
  --  creation date:      19/04/2015
  --  Description:        Main procedure, called by concurrent executable .
  --                      1. Upload data from csv file to xxhz_account_interface table.
  --                      2. Handle data in interface table
  --                      3. Process data to Oracle.
  --                      4. Create output- Excel report
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   19/04/2015    Michal Tzvik    initial build
  --------------------------------------------------------------------
  PROCEDURE main(errbuf                   OUT VARCHAR2,
	     retcode                  OUT VARCHAR2,
	     p_table_name             IN VARCHAR2, -- hidden parameter. default value ='XXHZ_ACCOUNT_INTERFACE' independent value set XXOBJT_LOADER_TABLES
	     p_template_name          IN VARCHAR2, -- hidden parameter. default value ='ATRADIUS'
	     p_file_name              IN VARCHAR2,
	     p_directory              IN VARCHAR2,
	     p_partial_customer_match IN VARCHAR2,
	     p_email_address          IN VARCHAR2,
	     p_arc_directory          IN VARCHAR2);
         
  ------------------------------------------------------------------------------------------------------
  -- Ver    When             Who              Description
  -- -----  ---------------  ---------------  ----------------------------------------------------------
  -- 1.0    2019-11-03       Bellona.B         CHG0046362 - Mass Upload of customer credit limit
  ------------------------------------------------------------------------------------------------------
  PROCEDURE customer_credit_limit_main(errbuf            OUT VARCHAR2,
                                       retcode           OUT VARCHAR2,
                                       p_user            IN VARCHAR2,
                                       p_file_name       IN VARCHAR2,
                                       p_xxhz_credit_dir IN VARCHAR2);
END xxhz_customer_credit_int_pkg;
/