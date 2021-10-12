CREATE OR REPLACE PACKAGE xxconv_ap_upload_invoice_pkg IS
   ---------------------------------------------------------------------------
   -- $Header: xxconv_ap_upload_invoice_pkg 120.0 2009/08/31  $
   ---------------------------------------------------------------------------
   -- Package: xxconv_ap_upload_invoice_pkg
   -- Created: 
   -- Author  : 
   --------------------------------------------------------------------------
   -- Perpose: Upload AP Invoices
   --------------------------------------------------------------------------
   -- Version  Date      Performer       Comments
   ----------  --------  --------------  -------------------------------------
   --     1.0  31/08/09                  Initial Build
   ---------------------------------------------------------------------------

   /*   PROCEDURE main(errbuf      OUT VARCHAR2,
                     retcode     OUT VARCHAR2,
                     p_file_name IN VARCHAR2);
   */

   PROCEDURE ascii_apinvoiceint(errbuf         OUT VARCHAR2,
                                retcode        OUT VARCHAR2,
                                p_processlines IN CHAR);
END xxconv_ap_upload_invoice_pkg;
/

