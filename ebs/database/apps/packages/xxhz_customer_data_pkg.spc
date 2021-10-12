CREATE OR REPLACE PACKAGE xxhz_customer_data_pkg AS
  ----------------------------------------------------------------------------------
  --  name:              xxhz_customer_data_pkg
  --  create by:         Kundan Bhagat
  --  Revision:          1.0
  --  creation date:     10/04/2015
  ----------------------------------------------------------------------------------
  --  purpose :  CHANGE - CHG0034944
  --          : This package is used to fetch customer Account,sites and contacts information.
  --modification history
  ----------------------------------------------------------------------------------
  --  ver   date               name                             desc
  --  1.0   10/04/2015    Kundan Bhagat  CHANGE CHG0034944     initial build
  ------------------------------------------------------------------------------------
  PROCEDURE customer_data_proc(x_errbuf     OUT VARCHAR2,
                               x_retcode    OUT NUMBER,
                               p_account_id IN NUMBER);
END xxhz_customer_data_pkg;
/
