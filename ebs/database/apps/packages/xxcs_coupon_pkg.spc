CREATE OR REPLACE PACKAGE xxcs_coupon_pkg IS

  --------------------------------------------------------------------
  --  name:            XXCS_COUPON_PKG
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   12/06/2012 08:45:54
  --------------------------------------------------------------------
  --  purpose :        REP501 - Training Course Coupons
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  12/06/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  TYPE t_coupon_hist_rec IS RECORD(
    counpon_number  VARCHAR2(150),
    sales_order_num VARCHAR2(150),
    system_type     VARCHAR2(240),
    serial_number   VARCHAR2(40),
    customer_name   VARCHAR2(360),
    --VALID_DATE         DATE,
    --SEND_MAIL          VARCHAR2(10),
    org_id NUMBER);

  --------------------------------------------------------------------
  --  name:            copy_file
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   13/06/2012 08:45:54
  --------------------------------------------------------------------
  --  purpose :        REP501 - Training Course Coupons
  --                   Copy coupon report output from appl/conc/out
  --                   to /UtlFiles/shared/TEST/CS/coupon
  --                   TEST  /TestApps/oracle/TEST/SharedFiles/logs/appl/conc/out
  --                   DEV   /DevApps/oracle/DEV/SharedFiles/logs/appl/conc/out
  --                   PATCH /PtchApps/oracle/PTCH/SharedFiles/logs/appl/conc/out
  --                   YES   /YesApps/oracle/YES/SharedFiles/logs/appl/conc/out
  --                   PROD  /ProdApps/oracle/PROD/SharedFiles/logs/appl/conc/out

  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/06/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE copy_file(p_dir       IN VARCHAR2,
                      p_file_name IN VARCHAR2,
                      p_err_code  OUT NUMBER);

  --------------------------------------------------------------------
  --  name:            afterreport
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   06/06/2012 15:34:52
  --------------------------------------------------------------------
  --  purpose :        REP499 - Elements Reports
  --                   send report output as mail to user that run the report.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/06/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------                        
  FUNCTION afterreport(p_request_id IN NUMBER) RETURN BOOLEAN;

  --------------------------------------------------------------------
  --  name:            main
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   12/06/2012 08:45:54
  --------------------------------------------------------------------
  --  purpose :        REP501 - Training Course Coupons
  --                   
  --                   1) get population to generate Coupon report
  --                   2) send coupon report output as mail to mail list
  --                   3) insert row to XX table to know which order line (OM)
  --                      was sent allready.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  12/06/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE main(errbuf      OUT VARCHAR2,
                 retcode     OUT VARCHAR2,
                 p_header_id IN NUMBER);

END xxcs_coupon_pkg;
/
