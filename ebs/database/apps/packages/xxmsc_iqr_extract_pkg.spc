CREATE OR REPLACE PACKAGE xxmsc_iqr_extract_pkg AS
--------------------------------------------------------------------
--  name:            xxmsc_iqr_extract_pkg
--  create by:       Mike Mazanet
--  Revision:        1.1
--  creation date:   04/01/2015
--------------------------------------------------------------------
--  purpose : Package to handle IQR extract
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  04/01/2015  MMAZANET    Initial Creation for CHG0034833.
--------------------------------------------------------------------  

  FUNCTION get_po_qty_due(p_po_line_location_id  IN NUMBER)
  RETURN NUMBER;

  PROCEDURE main(
    errbuff           OUT VARCHAR2,
    retcode           OUT NUMBER,
    p_action          IN  VARCHAR2,
    p_batch_name      IN  VARCHAR2,
    p_file_location   IN  VARCHAR2,
    p_file_name       IN  VARCHAR2,
    p_delimiter       IN  VARCHAR2,
    p_org_id          IN  NUMBER,
    p_plan_id         IN  NUMBER
  );
  
END xxmsc_iqr_extract_pkg;

/
SHOW ERRORS