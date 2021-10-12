create or replace 
package xxar_warranty_rates_debug_pkg is

  --------------------------------------------------------------------
  --  name:            XXAR_WARRANTY_RATES_DEBUG_PKG
  --  create by:       Mike Mazanet
  --  Revision:        1.1
  --  creation date:   17/11/2014 
  --------------------------------------------------------------------
  --  purpose :        Created as a copy of xxar_warranty_rates_pkg to 
  --                   troubleshoot performance issues only occurring 
  --                   in production.  Added write_log statements 
  --                   throughout.  Also added p_call_api, which allows
  --                   us to bypass calling the AR_INVOICE_API_PUB.create_single_invoice
  --                   API and p_item_id parameter in
  --                   Create_warrenty_Invoices procedure so we can run
  --                   program for one item.
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  17/11/2014  Mike Mazanet      CHG003877.  initial build
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
  procedure ins_check_line(p_user_id            in number,
                           p_warrenty_rates_tbl in t_warrenty_rates_tbl,
                           p_error_code         out varchar2,
                           p_error_desc         out varchar2);

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
  procedure validate_record(p_warrenty_rates_rec in t_warrenty_rates_rec,
                            p_err_code           out number,
                            p_err_desc           out varchar2);

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
  procedure unEarned_warrenty_revenue(errbuf  out varchar2,
                                      retcode out varchar2);

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
  procedure Earned_warrenty_revenue(errbuf  out varchar2,
                                    retcode out varchar2);
  --------------------------------------------------------------------
  --  name:            get_vsoe_ccid
  --  create by:       Ofer Suad
  --  Revision:        1.1
  --  creation date:   8/10/2013
  --------------------------------------------------------------------
  --  purpose :        CHG0032979
  --                    New Logic of Warranty Invoices
  --------------------------------------------------------------------
  procedure Create_warrenty_Invoices(errbuf  out varchar2,
                                     retcode out varchar2,
                                     p_call_api IN VARCHAR2 DEFAULT 'N', 
                                     p_item_id  IN NUMBER DEFAULT NULL);
  --------------------------------------------------------------------
  --  name:            get_vsoe_ccid
  --  create by:       Ofer Suad
  --  Revision:        1.1
  --  creation date:   8/10/2013
  --------------------------------------------------------------------
  --  purpose :        CUST500 - Automate VSOE
  --                    FIND the GL account with VSOE product line
  --------------------------------------------------------------------
  function get_vsoe_ccid(p_sys_ccid  number,
                         is_fdm_item varchar2,
                         is_unearned varchar2) return number;

end xxar_warranty_rates_debug_pkg;
/

SHOW ERRORS