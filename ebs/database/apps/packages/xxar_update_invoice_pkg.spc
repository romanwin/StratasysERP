CREATE OR REPLACE PACKAGE xxar_update_invoice_pkg IS
--------------------------------------------------------------------
--  name:            CUST293 - AR VAT upd global dff - xxar_update_invoice_pkg
--  create by:       SARI.FRAIMAN
--  Revision:        1.0 
--  creation date:   07/04/2010 2:43:50 PM
--------------------------------------------------------------------
--  purpose :        update invoices with reshimon data - to global_attributes
--------------------------------------------------------------------
--  ver  date        name             desc
--  1.0  07/04/2010  Sari             initial build
--  1.1  19/07/2010  Dalit A. Raviv   correct date formate at laod_global_dff proc
--------------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:            load_global_dff
  --  create by:       SARI.FRAIMAN
  --  Revision:        1.0 
  --  creation date:   07/04/2010 2:43:50 PM
  --------------------------------------------------------------------
  --  purpose :        update invoices with reshimon data - to global_attributes
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  07/04/2010  Sari             initial build
  --------------------------------------------------------------------
  PROCEDURE load_global_dff(errbuf     OUT VARCHAR2,
                            retcode    OUT VARCHAR2,
                            p_location IN  VARCHAR2,
                            p_filename IN  VARCHAR2);
END xxar_update_invoice_pkg;
/

