CREATE OR REPLACE PACKAGE xxqp_price_book_html_pkg IS
  --------------------------------------------------------------------
  --  customization code: CHG0033893 - Price Books Automation
  --  name:               xxqp_price_book_html_pkg
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  creation date:      15/03/2015
  --  Description:        Handle creation of HTML price book
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   15/03/2015    Michal Tzvik    initial build
  --------------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:               create_html_price_book
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  customization code: CHG0033893 - Price Books Automation
  --  creation date:      15/03/2015
  --  Description:        Create all needed files in order to get HTML price book
  --  Parametrs:          p_generation_id - unique identifier of PB generation.
  --                      A temporary directory with generation_id as its name
  --                      is been created in server under  /mnt/oracle/qp/price_book/output
  --                      The HTML PB is created in this directory.
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   15/03/2015    Michal tzvik    initial build
  --------------------------------------------------------------------
  PROCEDURE create_html_price_book(errbuf          OUT VARCHAR2,
		           retcode         OUT VARCHAR2,
		           p_generation_id NUMBER);

  --------------------------------------------------------------------
  --  name:               submit_html_pb_set
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  customization code: CHG0033893 - Price Books Automation
  --  creation date:      15/03/2015
  --  Description:        Submit request set 'XX Generate Price Book Set'
  --  Parametrs:          p_request_id - request_id of pb excel report. its XML
  --                                     will be used for generating HTML.
  --                      p_generation_id - unique identifier of PB generation.
  --                      p_email_address - the pb will be sent to this email address
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   15/03/2015    Michal tzvik    initial build
  --------------------------------------------------------------------
  PROCEDURE submit_html_pb_set(x_err_code OUT NUMBER,
		       x_err_msg  OUT VARCHAR2,
		       --  p_request_id    NUMBER,
		       p_generation_id NUMBER,
		       p_email_address VARCHAR2);

END xxqp_price_book_html_pkg;
/
