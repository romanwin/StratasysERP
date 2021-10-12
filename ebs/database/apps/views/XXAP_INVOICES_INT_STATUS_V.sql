CREATE OR REPLACE VIEW XXAP_INVOICES_INT_STATUS_V AS
SELECT
--------------------------------------------------------------------------
--  XXAP_INVOICES_INT_STATUS_V
--  CR681  : used by bpel to upload status to tas
---------------------------------------------------------------------------
-- Version  Date      Performer       Comments
----------  --------  --------------  -------------------------------------
--     1.0  11.2.2013  yuval tal      Initial Build
 inv.creation_date,
 inv.attribute1,
 inv.invoice_num,
 inv.invoice_date,
 inv.group_id,
 inv.invoice_id,
 inv.invoice_id_src,
 inv.invoice_id_ap,
 inv.status,
 decode(inv.status, 'SUCCESS', 0, 2) status_code,
 xxap_invoice_interface_api.get_invoice_err_string(inv.invoice_id,
                                                   inv.group_id) error_desc
  FROM xx_ap_invoices_interface inv;
