CREATE OR REPLACE PACKAGE xxap_oic_util_pkg IS
  --------------------------------------------------------------------
  --  name:               xxap_oic_util_pkg
  --  create by:          yuval tal 
  --  Revision:           1.0
  --  creation date:      12/7/20
  --------------------------------------------------------------------
  --  purpose:      called from oic 
  --------------------------------------------------------------------
  --  ver     date        name            desc
  --  1.0     1.4.20     yuval tal       CHG0047624 initial build

  --------------------------------------------------------------------
  /*  TYPE t_ap_invoice_r IS RECORD(
    invoice_id    VARCHAR2(50),
    invoice_num   VARCHAR2(50),
    is_success    VARCHAR2(20),
    vendor_id     VARCHAR2(50),
    error_message VARCHAR2(200));
  TYPE t_ap_invoice_tab IS TABLE OF t_ap_invoice_r;*/

  PROCEDURE insert_ap_inv_interface(p_flow_id        NUMBER,
			p_err_code       OUT VARCHAR2,
			p_err_message    OUT VARCHAR2,
			p_ap_invoice_tab OUT xxobjt.xxap_oic_invoice_tab_type);
END xxap_oic_util_pkg;
/
