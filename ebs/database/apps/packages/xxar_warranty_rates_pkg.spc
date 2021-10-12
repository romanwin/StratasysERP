CREATE OR REPLACE PACKAGE xxar_warranty_rates_pkg IS

  --------------------------------------------------------------------
  --  name:            XXAR_WARRANTY_RATES_PKG
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   20/06/2012 11:26:48
  --------------------------------------------------------------------
  --  purpose :        CUST500 - Automate VSOE
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  20/06/2012  Dalit A. Raviv    initial build
  --  1.1  08/10/2013  Ofer Suad  Add get VSOE ccid
  --------------------------------------------------------------------
  TYPE t_warrenty_rates_rec IS RECORD(
    org_id            NUMBER,
    location_code     VARCHAR2(15),
    channel           VARCHAR2(15),
    inventory_item_id NUMBER,
    warranty_period   NUMBER,
    rate              NUMBER,
    from_date         DATE,
    to_date           DATE);

  TYPE t_warrenty_rates_tbl IS TABLE OF t_warrenty_rates_rec INDEX BY BINARY_INTEGER;

  --------------------------------------------------------------------
  --  name:            upd_check_line
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   20/06/2012 11:26:48
  --------------------------------------------------------------------
  --  purpose :        CUST500 - Automate VSOE
  --                   update field check line to N
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  20/06/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  /* procedure upd_check_line (p_user_id    in  number,
                             p_error_code out varchar2,
                             p_error_desc out varchar2);
  */
  --------------------------------------------------------------------
  --  name:            ins_check_line
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   20/06/2012 11:26:48
  --------------------------------------------------------------------
  --  purpose :        CUST500 - Automate VSOE
  --                   insert duplicate rows
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  20/06/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  /*  procedure ins_check_line (p_user_id    in  number,
                              p_error_code out varchar2,
                              p_error_desc out varchar2);
  */

  --------------------------------------------------------------------
  --  name:            ins_check_line
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   20/06/2012 11:26:48
  --------------------------------------------------------------------
  --  purpose :        CUST500 - Automate VSOE
  --                   insert duplicated rows
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  20/06/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE ins_check_line(p_user_id            IN NUMBER,
		   p_warrenty_rates_tbl IN t_warrenty_rates_tbl,
		   p_error_code         OUT VARCHAR2,
		   p_error_desc         OUT VARCHAR2);

  --------------------------------------------------------------------
  --  name:            validate_record
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   24/06/2012 11:26:48
  --------------------------------------------------------------------
  --  purpose :        CUST500 - Automate VSOE
  --                   validate end_date and to_date before save data to DB
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  24/06/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE validate_record(p_warrenty_rates_rec IN t_warrenty_rates_rec,
		    p_err_code           OUT NUMBER,
		    p_err_desc           OUT VARCHAR2);

  --------------------------------------------------------------------
  --  name:            unEarned_warrenty_revenue
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   18/06/2013
  --------------------------------------------------------------------
  --  purpose :        CUST500 - Automate VSOE
  --                   program that will run scheduled.
  --                   the program will locate all invoice line from account XX
  --                   and will sprade the amount into several periods
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  18/06/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE unearned_warrenty_revenue(errbuf  OUT VARCHAR2,
			  retcode OUT VARCHAR2);

  --------------------------------------------------------------------
  --  name:            Earned_warrenty_revenue
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   18/06/2013
  --------------------------------------------------------------------
  --  purpose :        CUST500 - Automate VSOE
  --                   program that will run scheduled.
  --                   the program will locate all invoice line from account XX
  --                   and will sprade the amount into several periods
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  18/06/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE earned_warrenty_revenue(errbuf  OUT VARCHAR2,
			retcode OUT VARCHAR2);
  --------------------------------------------------------------------
  --  name:            get_vsoe_ccid
  --  create by:       Ofer Suad
  --  Revision:        1.1
  --  creation date:   8/10/2013
  --------------------------------------------------------------------
  --  purpose :        CHG0032979
  --                    New Logic of Warranty Invoices
  --------------------------------------------------------------------
  PROCEDURE create_warrenty_invoices(errbuf  OUT VARCHAR2,
			 retcode OUT VARCHAR2);
  --------------------------------------------------------------------
  --  name:            get_vsoe_ccid
  --  create by:       Ofer Suad
  --  Revision:        1.1
  --  creation date:   8/10/2013
  --------------------------------------------------------------------
  --  purpose :        CUST500 - Automate VSOE
  --                    FIND the GL account with VSOE product line
  --------------------------------------------------------------------
  FUNCTION get_vsoe_ccid(p_sys_ccid  NUMBER,
		 is_fdm_item VARCHAR2,
		 is_unearned VARCHAR2) RETURN NUMBER;

END xxar_warranty_rates_pkg;
/
