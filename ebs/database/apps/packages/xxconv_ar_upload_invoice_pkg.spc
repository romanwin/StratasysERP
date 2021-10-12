create or replace package xxconv_ar_upload_invoice_pkg is

  procedure load_file(p_file_name     in varchar2,
                      x_error_message out varchar2);

Procedure Ascii_ARInvoiceInt (errbuf                   out varchar2, 
                              retcode                  out varchar2,
                              p_location               in varchar2,
                              p_filename               in varchar2,
                              p_processLines           in char);

end xxconv_ar_upload_invoice_pkg;
/

