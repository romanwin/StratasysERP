CREATE OR REPLACE VIEW XXAP_INVOICES_INT_ERR_V AS
SELECT
--------------------------------------------------------------------------
--  XXAP_INVOICES_INT_ERR_V
--  CR681
---------------------------------------------------------------------------
-- Version  Date      Performer       Comments
----------  --------  --------------  -------------------------------------
--     1.0  11.2.2013  yuval tal      Initial Build

 e.group_id, inv.invoice_id,0 line_number, INV.INVOICE_ID_SRC, e.description
  FROM xxobjt_interface_errors e, xx_ap_invoices_interface inv
 WHERE inv.invoice_id = e.obj_id
   AND e.group_id = inv.group_id
   AND e.table_name = 'XX_AP_INVOICES_INTERFACE'
UNION ALL
-- lines
SELECT e.group_id,inv.invoice_id,l.line_number, INV.INVOICE_ID_SRC, e.description
  FROM xxobjt_interface_errors  e,
       xx_ap_invoice_lines_interface l,
       xx_ap_invoices_interface inv
 WHERE l.invoice_line_id = e.obj_id
 and l.invoice_id=inv.invoice_id
   AND e.group_id = inv.group_id
   AND e.table_name = 'XX_AP_INVOICE_LINES_INTERFACE';
