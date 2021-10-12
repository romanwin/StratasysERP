CREATE OR REPLACE PACKAGE xxom_order_hist_pkg AS
  ----------------------------------------------------------------------------------
  --  name:              xxom_order_hist_pkg
  --  create by:         Kundan Bhagat
  --  Revision:          1.0
  --  creation date:     10/04/2015
  ----------------------------------------------------------------------------------
  --  purpose : CHANGE - CHG0034800
  --           This package is used to fetch Order history information (Header,Line and shipment).
  --modification history
  ----------------------------------------------------------------------------------
  --  ver   date               name                             desc
  --  1.0   10/04/2015    Kundan Bhagat  CHANGE CHG0034944  initial build
  ------------------------------------------------------------------------------------
  PROCEDURE order_history_proc(x_retcode OUT NUMBER,
                               x_errbuf  OUT VARCHAR2);

END xxom_order_hist_pkg;
/
