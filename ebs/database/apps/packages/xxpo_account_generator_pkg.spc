CREATE OR REPLACE PACKAGE xxpo_account_generator_pkg IS
  --------------------------------------------------------------------
  --  customization code: CUST251 
  --  name:               Account Generator for Projects
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0 $
  --  creation date:      18/01/2010
  --------------------------------------------------------------------
  --  process:            Account Generator for Projects Related  determine the distribution 
  --                      account for Requisition  lines. In current business process the requestor
  --                      enter requisition  into the system by enter the following information:
  --                      Make sure the destination type is Expense  and RandD
  --------------------------------------------------------------------
  --  ver    date         name           desc
  --  1.0   18/01/2010   Dalit A. Raviv  initial build
  --------------------------------------------------------------------

  --------------------------------------------------------------------
  --  customization code: CUST251 
  --  name:               get_project_att1_entered
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0 $
  --  creation date:      18/01/2010
  --------------------------------------------------------------------
  --  process:            in form personalization-
  --                      check if requisition have lines from type EXPENCE
  --                      plus deliver_to_location_id is R and D 
  --                      and have value at attribute1
  --                      if do not have value msg will popup and return to header
  --------------------------------------------------------------------
  --  ver    date         name           desc
  --  1.0   18/01/2010   Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  FUNCTION get_project_att1_entered(p_requisition_header_id IN NUMBER)
    RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  customization code: CUST251 Account Generator for Projects
  --  name:               check_req_hdr_have_line
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0 $
  --  creation date:      18/01/2010
  --------------------------------------------------------------------
  --  process:            in form personalization-
  --                      i do not want user to commit before enter lines to req
  --                      if did not enter any line - msg will popup and raise
  --  return:             EXIST   - if find requisition lines
  --                      NO_LINE - if did not find any lines
  --------------------------------------------------------------------
  --  ver    date         name           desc
  --  1.0   18/01/2010   Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  FUNCTION check_req_hdr_have_line(p_requisition_header_id IN NUMBER)
    RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  customization code: CUST251 Account Generator for Projects
  --  name:               get_project_requester_acc
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0 $
  --  creation date:      18/01/2010
  --------------------------------------------------------------------
  --  process:            this procedure call from WF - PO Requisition Account Generator
  --                      Process:  XX: Build Rule-Based Expense Account
  --                      Function: XX: Get Project Requester Acc
  --  return:             COMPLETE:SUCCESS
  --                      COMPLETE:FAILURE
  --------------------------------------------------------------------
  --  ver    date         name           desc
  --  1.0   18/01/2010   Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  PROCEDURE get_project_requester_acc(itemtype IN VARCHAR2,
                                      itemkey  IN VARCHAR2,
                                      actid    IN NUMBER,
                                      funcmode IN VARCHAR2,
                                      RESULT   OUT NOCOPY VARCHAR2);

  --------------------------------------------------------------------
  --  customization code: CUST251 Account Generator for Projects
  --  name:               update_ditribution_account
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0 $
  --  creation date:      25/01/2010
  --------------------------------------------------------------------
  --  process:            
  --  return:             p_error_code - 0 success,     <> 0 failed
  --                      p_error_desc - null success , <> null failed                 
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   25/01/2010    Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  PROCEDURE update_ditribution_account(p_req_header_id IN NUMBER,
                                       p_proj_account  IN VARCHAR2,
                                       p_error_code    OUT NUMBER,
                                       p_error_desc    OUT VARCHAR2);

  --------------------------------------------------------------------
  --  customization code: CUST251 Account Generator for Projects
  --  name:               check_req_dist_have_encumb
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0 $
  --  creation date:      31/01/2010
  --------------------------------------------------------------------
  --  process:            
  --  return:             Y find encumbered_flag = Y for this req
  --                      N did not find                 
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   31/01/2010    Dalit A. Raviv  initial build
  --------------------------------------------------------------------                                      
  FUNCTION check_req_dist_have_encumb(p_req_header_id IN NUMBER)
    RETURN VARCHAR2;
  --------------------------------------------------------------------
  -------------------------------------
  -- update_po_accounts
  --  
  -- cr 483 change seg7 in accounts 
  -- called from po form ( form personaliztion) when navigating to po_approve block 
  -------------------------------------
  PROCEDURE update_po_dist_accounts(p_po_header_id NUMBER);

END xxpo_account_generator_pkg;
/
