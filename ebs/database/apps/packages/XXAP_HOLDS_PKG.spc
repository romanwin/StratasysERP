create or replace PACKAGE XXAP_HOLDS_PKG IS
  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Package Name:    XXAP_HOLDS_PKG.spc
  Author's Name:   Sandeep Akula
  Date Written:    13-OCT-2015
  Purpose:         AP Invoice Holds Package 
  Program Style:   Stored Package SPECIFICATION
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  13-OCT-2015        1.0                  Sandeep Akula    Initial Version (CHG0036487)
  ---------------------------------------------------------------------------------------------------*/
  g_curr_request_id NUMBER := fnd_global.conc_request_id;
 
PROCEDURE create_single_hold(p_invoice_id         IN number,
                             p_hold_lookup_code   IN varchar2,
                             p_hold_type IN varchar2 DEFAULT NULL,
                             p_hold_reason IN varchar2 DEFAULT NULL,
                             p_held_by IN number DEFAULT NULL,
                             p_calling_sequence IN varchar2 DEFAULT NULL);
                             
PROCEDURE release_single_hold(p_invoice_id         IN number,
                             p_hold_lookup_code   IN varchar2,
                             p_release_lookup_code   IN varchar2,
                             p_held_by IN number DEFAULT NULL,
                             p_calling_sequence IN varchar2 DEFAULT NULL);                             
                             
FUNCTION get_hold_action(p_invoice_id IN NUMBER)
RETURN VARCHAR2;    

FUNCTION HOLD_ELIGIBLE(p_invoice_id IN number)
RETURN VARCHAR2;
                             
PROCEDURE validate_invoice(p_invoice_id IN number,
                           p_user_id    IN number DEFAULT NULL);  
                           

END XXAP_HOLDS_PKG;
/

