create or replace PACKAGE xxiby_pay_extract_util IS
  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Package Name:    XXIBY_PAY_EXTRACT_UTIL.spc
  Author's Name:   Sandeep Akula
  Date Written:    02-JAN-2015
  Purpose:         Payment Extract Process Utilities
  Program Style:   Stored Package SPECIFICATION
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  02-JAN-2015        1.0                  Sandeep Akula    Initial Version (CHG0032794)
  20-AUG-2015        1.1                  Sandeep Akula    Added record type payments_rec (CHG0035411)
  ---------------------------------------------------------------------------------------------------*/
  g_curr_request_id NUMBER := fnd_global.conc_request_id;
  
  -- Added Record Type 20-AUG-2015 SAkula CHG0035411 
  TYPE payments_rec IS RECORD(
   bank_account_name iby_ext_bank_accounts.bank_Account_name%type,
   vendor_name_alt   ap_suppliers.vendor_name_alt%type,
   vendor_name       ap_suppliers.vendor_name%type,
   bank_name_alt     ce_banks_v.bank_name_alt%type);

  FUNCTION is_wellsfargo_bank_account(p_payment_id IN NUMBER) RETURN VARCHAR2;

  FUNCTION is_wellsfargo_payment_type(p_payment_id IN NUMBER) RETURN VARCHAR2;

  FUNCTION get_pmt_ext_agg(p_payment_id IN NUMBER) RETURN xmltype;

  PROCEDURE get_ack_email(p_ack_level  IN NUMBER,
		                      p_orgnlmsgid IN NUMBER,
		                      p_to_email   OUT VARCHAR2);
                        --p_cc_email OUT VARCHAR2); -- TBD

  FUNCTION get_l2_ack_email(p_ack_level  IN NUMBER DEFAULT NULL,
                            p_OrgnlEndToEndId IN NUMBER)
  RETURN VARCHAR2;

END xxiby_pay_extract_util;
/
