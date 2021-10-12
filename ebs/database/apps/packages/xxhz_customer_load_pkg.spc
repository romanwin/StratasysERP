CREATE OR REPLACE PACKAGE APPS.xxhz_customer_load_pkg AS
  ----------------------------------------------------------------------------------
  --  name:              xxhz_customer_load_pkg
  --  create by:         Debarati Banerjee
  --  Revision:          1.0
  --  creation date:     24/07/2015
  ----------------------------------------------------------------------------------
  --  purpose :  CHANGE - CHG0035649
  --          : This package is used for pre populating xxssys_events table with customer
  --            account,site and contact information.
  --modification history
  ----------------------------------------------------------------------------------
  --  ver   date               name                             desc
  --  1.0   24/07/2015    Debarati Banerjee  CHANGE CHG0035649     initial build
  ------------------------------------------------------------------------------------
  PROCEDURE customer_data_load(x_errbuf     OUT VARCHAR2,
                               x_retcode    OUT NUMBER
                               --p_account_id IN NUMBER
                               );
END xxhz_customer_load_pkg;
/

