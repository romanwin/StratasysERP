--------------------------------------------------------------------
--  name:            XXAR_CUST_MATCH_TAB
--  create by:       Mike Mazanet
--  Revision:        1.1
--  creation date:   06/05/2015
--------------------------------------------------------------------
--  purpose : Table type used by XXHZ_API_PKG.FIND_DUPLICATE_CUSTOMERS_ONLY
--            procedure.  This procedure is wrapped in a web service
--            in the SOA layer, which is why it needs to use a table
--            object as a parameter.
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  06/05/2015  MMAZANET    Initial Creation for CHG0035118.
--------------------------------------------------------------------

CREATE TYPE xxar_cust_match_rec AS OBJECT (
  match_type            VARCHAR2(30),
  cust_account_id       NUMBER,               
  external_id           VARCHAR2(150),
  external_source_name  VARCHAR2(30),
  party_name            VARCHAR2(360),           
  duns_number_c         VARCHAR2(30),     
  atradius_id           VARCHAR2(150),
  vat_id                VARCHAR2(20) 
)
/

CREATE TYPE xxar_cust_match_tab AS TABLE OF xxar_cust_match_rec
/