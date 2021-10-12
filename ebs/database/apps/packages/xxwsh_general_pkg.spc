CREATE OR REPLACE PACKAGE xxwsh_general_pkg IS

  --------------------------------------------------------------------
  --  name:            XXWSH_GENERAL_PKG
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   19/12/2013 15:39:30
  --------------------------------------------------------------------
  --  purpose :        CUST760 - Ship Console -CR1203 -Shipping notification mail
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  19/12/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:            get_shipping_mail_list
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   19/12/2013 15:39:30
  --------------------------------------------------------------------
  --  purpose :        CUST760 - Ship Console -CR1203 -Shipping notification mail
  --                   Email the following recipients if they exist:
  --                   1) Sales Order “Ship To Contact” (XXOE_CONTACTS_V.EMAIL BY CONTACT_ID)
  --                   2) Sales Order “Bill To Contact” (XXOE_CONTACTS_V)
  --                   3) Sales Order “Sales Person” OE_ORDER_HEADERS_ALL.SALESREP_ID JTF_RS_SALESREPS
  --                   4) Sales Order Header DFF “Reseller/XXX “ (exists only for SSUS order types) OE_ORDER_HEADERS_ALL.ATTRIBUTE??
  --                   5) Sales Order Header DFF “Ship Notif Email” (OE_ORDER_HEADERS_ALL.ATTRIBUTE20 )
  --                   6) Sales Order creator  user_id -> person -> mail
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  19/12/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_shipping_mail_list(p_delivery_id IN NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  customization code: CUST 776 CR1215 Customer support SF-OA interfaces
  --  name:               get_tracking_number
  --  create by:          YUVAL TAL
  --  $Revision:          1.0
  --  creation date:      16.1.14
  --  Description:        CR1215 Customer support SF-OA interfaces
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   16.1.14       yuval tal       initial build   CR1215 Customer support SF-OA interfaces
  --------------------------------------------------------------------

  FUNCTION get_tracking_number(p_order_line_id NUMBER) RETURN VARCHAR2;

END xxwsh_general_pkg;
/
