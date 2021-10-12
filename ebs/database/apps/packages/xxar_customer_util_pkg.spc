CREATE OR REPLACE PACKAGE xxar_customer_util_pkg AS
--------------------------------------------------------------------
--  name:            xxar_customer_util_pkg
--  create by:       Mike Mazanet
--  Revision:        1.1
--  creation date:   03/23/2015
--------------------------------------------------------------------
--  purpose : Package to hold utility functions for manipulating 
--            customers and associated customer entities.
--------------------------------------------------------------------
--  ver  date        name              desc
-- 1.0  03/23/2015  MMAZANET    Initial Creation for CHG0034748.
--------------------------------------------------------------------

  PROCEDURE inactivate_customers(
    errbuff         OUT VARCHAR2,
    retcode         OUT NUMBER,
    p_batch_name    IN  VARCHAR2,
    p_file_location IN  VARCHAR2,
    p_file_name     IN  VARCHAR2
  );

END xxar_customer_util_pkg;
/

SHOW ERRORS