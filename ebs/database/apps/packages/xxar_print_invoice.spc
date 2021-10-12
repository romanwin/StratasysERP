create or replace package xxar_print_invoice IS

  --------------------------------------------------------------------
  --  name:            XXAR_PRINT_INVOICE
  --  create by:       Daniel Katz
  --  Revision:        1.0
  --  creation date:   xx/xx/2010
  --------------------------------------------------------------------
  --  purpose :        This package handle ap print invoice
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  xx/xx/2010  Daniel Katz       initial build
  --  1.1  06/10/2011  Dalit A. Raviv    add the ability to send invoice output by mail
  --  1.2   3/3/2017    Sandeep Patel    CHG0037087 Update and standardize email generation logic proc send_Invoice_email()
  --                                     New Procedure Added : get_Invoice_email_info()
  --                                     New Function Added  : get_invoice_water_mark()
  --  1.3 06.06.2017   Lingaraj(TCS)     CHG0040768 - Enhance Invoice Ditribution Functionality
  --  1.4 06/05/2018   Bellona(TCS)      CHG0041929 - Added new paramter p_template in procedure get_Invoice_email_info
  --										for the logic of introducing Dynamic template for AR Invoice Print bursting process
  --------------------------------------------------------------------
  -- Public function and procedure declarations
  PROCEDURE print_invoice_special(p_org_id             IN NUMBER,
                                  p_choice             IN NUMBER,
                                  p_batch_source_id    IN NUMBER,
                                  p_cust_trx_class     IN VARCHAR2,
                                  p_cust_trx_type_id   IN ra_cust_trx_types.cust_trx_type_id%TYPE,
                                  p_customer_name_low  IN hz_parties.party_name%TYPE,
                                  p_customer_name_high IN hz_parties.party_name%TYPE,
                                  p_customer_no_low    IN hz_cust_accounts.account_number%TYPE,
                                  p_customer_no_high   IN hz_cust_accounts.account_number%TYPE,
                                  p_trx_from           IN ra_interface_lines.trx_number%TYPE,
                                  p_to_trx             IN ra_interface_lines.trx_number%TYPE,
                                  p_installment        IN NUMBER,
                                  p_from_date          IN VARCHAR2,
                                  p_to_date            IN VARCHAR2,
                                  p_open_invoices_only IN VARCHAR2,
                                  p_printing_pending   IN VARCHAR2,
                                  --added by daniel katz on 28-mar-10
                                  p_show_country_origin IN VARCHAR2);

  --------------------------------------------------------------------
  --  name:            Print_Invoice
  --  create by:       Daniel Katz
  --  Revision:        1.0
  --  creation date:   xx/xx/2010
  --------------------------------------------------------------------
  --  purpose :        Program that print AR invoices
  --                   Concurrent XX: Print Invoice
  --                   Report     XXAR_INVOICE
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  xx/xx/2010  Daniel Katz       initial build
  --  1.1  06/10/2011  Dalit A. Raviv    add the ability to send invoice output by mail
  --                                     if customer sent parameter p_send_mail the program will
  --                                     send each invoice to a different customer by mail.
  --------------------------------------------------------------------
  PROCEDURE print_invoice(errbuf               OUT VARCHAR2,
                          retcode              OUT NUMBER,
                          p_org_id             IN NUMBER,
                          p_choice             IN NUMBER,
                          p_batch_source_id    IN NUMBER,
                          p_cust_trx_class     IN VARCHAR2,
                          p_cust_trx_type_id   IN ra_cust_trx_types.cust_trx_type_id%TYPE,
                          p_customer_name_low  IN hz_parties.party_name%TYPE,
                          p_customer_name_high IN hz_parties.party_name%TYPE,
                          p_customer_no_low    IN hz_cust_accounts.account_number%TYPE,
                          p_customer_no_high   IN hz_cust_accounts.account_number%TYPE,
                          p_installment        IN NUMBER,
                          p_trx_from           IN ra_interface_lines.trx_number%TYPE,
                          p_to_trx             IN ra_interface_lines.trx_number%TYPE,
                          p_from_date          IN VARCHAR2,
                          p_to_date            IN VARCHAR2,
                          p_open_invoices_only IN VARCHAR2,
                          --added by daniel katz on 28-mar-10
                          p_show_country_origin IN VARCHAR2,
                          -- 1.1 Dalit A. Raviv
                          /*p_send_mail         IN VARCHAR2 DEFAULT 'N',--Commented on 06.06.2017 for CHG0040768*/
                          p_invoice_dist_mode   IN NUMBER,--Added on 06.06.2017 for CHG0040768, in place of p_send_mail
                          p_print_zero_amt    IN VARCHAR2 DEFAULT 'N',
                          p_printing_category IN VARCHAR2);
  --------------------------------------------------------------
  FUNCTION get_send_to_email(p_customer_trx_id IN NUMBER) RETURN VARCHAR2;
  --------------------------------------------------------------------
  --  name:            get_Invoice_email_info
  --  create by:       Sandeep Patel
  --  Revision:        1.0
  --  creation date:   03/03/2017
  ---------------------------------------------------------------------
  --  purpose :        This Procedure will be Called from XXAR_INVOICE.rdf & XXAR_SSUS_TRX_REP.rdf
  --                   common Procedure to get the Messages and Built Email Body and Subject
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  03/03/2017  Sandeep Patel     CHG0037087 Update and standardize email generation logic proc send_Invoice_email()
  --  1.1  06/05/2018  Bellona(TCS)      CHG0041929 Added new paramter p_template for the logic of introducing
  --									  Dynamic template for AR Invoice Print bursting process
  --------------------------------------------------------------------
  PROCEDURE get_Invoice_email_info(p_org_id             IN NUMBER,
                                   p_trx_number         IN VARCHAR2,
                                   p_customer_trx_id    IN NUMBER,
                                   p_bill_to_customer_name in VARCHAR2,
                                   p_inv_type           IN VARCHAR2,
                                   p_interface_header_context  IN VARCHAR2,
                                   p_rep_id             IN NUMBER,
                                   p_inv_dist_mode      IN NUMBER,
                                   p_file_name          OUT VARCHAR2,
                                   p_from_email         OUT VARCHAR2,
                                   p_to_email           OUT VARCHAR2,
                                   p_to_body            OUT VARCHAR2,
                                   p_to_title           OUT VARCHAR2,
								   p_template           OUT VARCHAR2	--CHG0041929
                                   );
  --------------------------------------------------------------------
  --  name:            get_invoice_water_mark
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   30/05/2017
  ---------------------------------------------------------------------
  --  purpose :        This Procedure will be Called from XXAR_INVOICE.rdf & XXAR_SSUS_TRX_REP.rdf
  --                   common Procedure t0 get the Invoice WaterMark
  --  Parameters :     p_invoice_choice (1 0r 2 or 3 ) Oroginal / Copy / Draft
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  30/05/2017  Lingaraj Sarangi     CHG0037087 Update and standardize email generation logic proc send_Invoice_email()
  --------------------------------------------------------------------
  FUNCTION get_invoice_water_mark(p_invoice_choice  NUMBER) RETURN VARCHAR2;
  --------------------------------------------------------------------
  --  name:            get_customer_contact_email
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   24/05/2017
  --------------------------------------------------------------------
  --  purpose :        To Get the Customer Contact Email to Send Invoice
  --------------------------------------------------------------------
  --  ver  date        name                desc
  --  1.0  24/05/2017  Lingaraj Sarangi    CHG0037087 :  Email options for sending out daily invoices
  --------------------------------------------------------------------
  FUNCTION get_customer_contact_email(p_customer_trx_id IN NUMBER)
                                  RETURN VARCHAR2;
  --------------------------------------------------------------------
  --  name:            is_cust_contact_email_exists
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   24/05/2017
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date        name                desc
  --  1.0  24/05/2017  Lingaraj Sarangi    CHG0037087 :  Email options for sending out daily invoices
  --------------------------------------------------------------------
  FUNCTION is_cust_contact_email_exists(p_customer_trx_id IN NUMBER)
                                  RETURN VARCHAR2;
  --------------------------------------------------------------------
  --  name:            get_inv_dist_where_query (Get Invoice Distribution Where Query)
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   24/05/2017
  --------------------------------------------------------------------
  --  purpose :        Prepare Invoice Distribution Query which can be
  --                   used with the  XXAR_INVOICE.rdf & XXAR_SSUS_TRX_REP.rdf
  --                   Report Parameter:-   :P_WHERE_INV_DIST_MODE
  --                   This Function Specific to use in RDF Reports Only
  --------------------------------------------------------------------
  --  ver  date        name                desc
  --  1.0  24/05/2017  Lingaraj Sarangi    CHG0040768 : initial Build
  --------------------------------------------------------------------
  FUNCTION get_inv_dist_where_query(p_inv_dist_mode NUMBER) RETURN VARCHAR2;
  --------------------------------------------------------------------
  --  name:            get_sales_admin_name
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   24/05/2017
  --------------------------------------------------------------------
  --  purpose :        Get Sales Admin Name for Non US Invoice
  --------------------------------------------------------------------
  --  ver  date        name                desc
  --  1.0  24/05/2017  Lingaraj Sarangi    CHG0037087 :  Email options for sending out daily invoices
  --------------------------------------------------------------------
  FUNCTION get_sales_admin_name(p_customer_trx_id IN NUMBER)
                                  RETURN VARCHAR2;
  --------------------------------------------------------------------
  --  name:            afterreport
  --  create by:       Lingaraj Sarangi
  --  Revision:        1.0
  --  creation date:   24/05/2017
  --------------------------------------------------------------------
  --  purpose :        After Report Trigger for XXAR_INVOICE.rdf ,XXAR_SSUS_TRX_REP.rdf
  --------------------------------------------------------------------
  --  ver  date        name                desc
  --  1.0  24/05/2017  Lingaraj Sarangi    CHG0037087 : initial Build
  --------------------------------------------------------------------
  FUNCTION afterreport(p_invoice_dist_mode IN NUMBER,
                       p_org_id IN number,
                       p_choice IN number,
                       P_Copy_Orig IN varchar2,
                       p_conc_request_id IN number,
                       p_report_rec_count IN NUMBER )
                       RETURN BOOLEAN;
END xxar_print_invoice;
/