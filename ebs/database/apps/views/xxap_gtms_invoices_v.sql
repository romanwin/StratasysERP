CREATE OR REPLACE VIEW XXAP_GTMS_INVOICES_V
  AS
SELECT
--------------------------------------------------------------------
--  name:            XXAP_GTMS_INVOICES_V
--  create by:       Ofer Suad
--  Revision:        1.0
--  creation date:   01/08/2016
--------------------------------------------------------------------
--  purpose :        CHG0039020: Crate DB VIEW based on GTMS Invoices
--                               to be used by PW duplication check
--------------------------------------------------------------------
--  ver  date        name             desc
--  1.0  01/06/2016  Ofer Suad        initial build
--------------------------------------------------------------------
 Invoice_Num, Vendor_Num
From Ap_invoices_interface aii
 Where aii.source = 'XX_GTMS'
 And nvl(status, 'REJECTED') <> 'REJECTED'

Union All

Select invoice_num, pv.SEGMENT1 Vendor_Num
  FROM Ap_invoices_all aia, PO_vendors pv
Where pv.VENDOR_ID = aia.vendor_id
   And aia.source = 'XX_GTMS'
