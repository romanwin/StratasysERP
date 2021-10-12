CREATE OR REPLACE PACKAGE xxap_invoice_interface_api AUTHID CURRENT_USER AS
  ---------------------------------------------------------------------------
  -- $Header: xxap_invoice_interface_api   $
  ---------------------------------------------------------------------------
  -- Package: xxap_invoice_interface_api
  -- Created:
  -- Author  : yuval tal
  --------------------------------------------------------------------------
  -- Perpose: CUST 641 CombTas Interfaces
  --          CR681: generic procerdures for invoice interface data check and import
  ---------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  11.2.2013  yuval tal            Initial Build
  --     1.1  05/31/2016  diptasurjya     CHG0038550 - Add procedure process_oic_invoices
  --                      chatterjee      to process AP invoices which are being imported from
  --                                      Oracle Incentive Compensation
  -----------------------------------------------------------------------------

  -- XX_AP_INVOICES_INTERFACE
  -- XX_AP_INVOICE_LINES_INTERFACE

  PROCEDURE process_invoices(p_err_code          OUT NUMBER,
                             p_err_message       OUT VARCHAR2,
                             p_import_request_id OUT NUMBER,
                             p_group_id          NUMBER,
                             p_ap_import_flag    VARCHAR2);

  PROCEDURE handle_header(p_invoice_id  NUMBER,
                          p_err_code    OUT NUMBER,
                          p_err_message OUT VARCHAR2);

  PROCEDURE handle_line(p_invoice_line_id NUMBER,
                        p_err_code        OUT NUMBER,
                        p_err_message     OUT VARCHAR2);

  PROCEDURE process_invoices_conc(p_err_message    OUT VARCHAR2,
                                  p_err_code       OUT NUMBER,
                                  p_table_source   VARCHAR2,
                                  p_group_id       NUMBER,
                                  p_ap_import_flag VARCHAR2);

  PROCEDURE get_import_status(p_request_id      NUMBER,
                              p_success         OUT VARCHAR2,
                              p_compeleted_code OUT VARCHAR2,
                              p_err_message     OUT VARCHAR2);

  FUNCTION get_invoice_err_string(p_invoice_id NUMBER, p_group_id NUMBER)
    RETURN VARCHAR2;

  PROCEDURE create_account(p_concat_segment      VARCHAR2,
                           p_coa_id              NUMBER,
                           p_org_id              NUMBER DEFAULT NULL,
                           x_code_combination_id OUT NUMBER,
                           x_return_code         OUT VARCHAR2,
                           x_err_msg             OUT VARCHAR2);

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0038550
  --          This is a wrapper procedure to process OIC invoices only.
  --          Input Parameter:
  --           a. p_process_rejected - Y/N. Y will re process all previously rejected invoices from OIC
  --           b. p_mail_import_summary - WIll mail the Standard AP import program output to mailing lists. Can be Y/N
  --
  --          The primary function of this procedure will be:
  --           1. Update income tax type in invoice lines interface for OIC invoices for tax reportable commission plan elements
  --              The update will also be applicable for US resellers only.
  --           2. Call standard Payables Open Interface import concurrent program after setting group ID and batch names
  --           3. In case of AP interface rejections, send notification email regarding rejected invoices
  --
  --          This procedure will be called from the concurrent program XXCN_OIC_INVOICE_IMPORT
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                                Description
  -- 1.0  05/20/2016  Diptasurjya Chatterjee               Initial Build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE process_oic_invoices(ERRBUFF OUT VARCHAR2,
                                 RETCODE OUT VARCHAR2,
                                 --p_org_id            IN number,
                                 p_process_rejected  IN varchar2,
                                 p_mail_import_summary IN varchar2);
END;
/
