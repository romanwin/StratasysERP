CREATE OR REPLACE PACKAGE xxpo_wf_notification_pkg AUTHID CURRENT_USER AS
  ---------------------------------------------------------------------------
  -- $Header: xxpo_wf_notification_pkg 120.0 2009/08/31  $
  ---------------------------------------------------------------------------
  -- Package: xxpo_wf_notification_pkg
  -- Created:
  -- Author  :
  --------------------------------------------------------------------------
  -- Perpose: Purchasing approval WF modifications
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --    1.0  31/08/09                  Initial Build
  --    1.1  26.8.10      yuval          add get_expense_type for pur distribution niotification Region
  --    1.2. 21.11.10     yuval          support release amount calc in set_startup_values
  --    1.3   10.4.11     yuval          change set_req_additional_attr
  --    1.4   14.12.11    yuval          change logic for release in set_startup_values
  --    1.5   9.1.11      yuval          fix bug :set_startup_values -  set XXPO_SENDER_ROLE for releases
  --    1.6   26.3.12     yuval          record_acceptance : support blanket and releases
  --    1.7  17.4.12         yuval tal      update_orig_dates_autonomous : support releases
  --    2.0  4.12.12      yuval tal      add is_po_approval_needed
  --    2.1  31.07.13     Vitaly         added code for CUST695 CR 932 PO remaining Shipments Conversion (for Std Cost)
  --    2.2  12.8.13      yuval tal      add is_po_approval_needed_std_cost
  --    2.3  05.06.14     sandeep akula  Added Procedures is_po_created_from_requisition, set_preparer_username_attr,
  --                                                      check_ou_in_prparernotf_lookup, check_ou_in_poapprv_ou_lookup, is_revision_greater_than_zero (CHG0031722)
  --    2.4  29.07.2014   sandeep akula  Added GROUP BY Clause to eliminate duplicates (CHG0032834)
  ---------------------------------------------------------------------------
  /* This function is the PL/SQL document function to retrieve the
  ** approval notification message header of the requisition.
  */

  FUNCTION get_req_distributions(p_set_of_books_id   NUMBER, -- l_sob_id
		         p_budget_account_id NUMBER, -- l_code_comb_id
		         p_gl_period_name    VARCHAR2) RETURN NUMBER;

  FUNCTION get_budget_amount RETURN NUMBER;

  FUNCTION get_obligation_amount RETURN NUMBER;

  FUNCTION get_actual_amount RETURN NUMBER;

  FUNCTION get_funds_avail_amount RETURN NUMBER;

  FUNCTION get_encumbrance_amount RETURN NUMBER;

  FUNCTION get_commitment_amount RETURN NUMBER;

  FUNCTION get_other_amount RETURN NUMBER;

  PROCEDURE set_startup_values(itemtype  IN VARCHAR2,
		       itemkey   IN VARCHAR2,
		       actid     IN NUMBER,
		       funcmode  IN VARCHAR2,
		       resultout OUT NOCOPY VARCHAR2);

  PROCEDURE create_njrc_requisition(itemtype  IN VARCHAR2,
			itemkey   IN VARCHAR2,
			actid     IN NUMBER,
			funcmode  IN VARCHAR2,
			resultout OUT NOCOPY VARCHAR2);

  PROCEDURE check_is_njrc_req_needed(itemtype  IN VARCHAR2,
			 itemkey   IN VARCHAR2,
			 actid     IN NUMBER,
			 funcmode  IN VARCHAR2,
			 resultout OUT NOCOPY VARCHAR2);

  PROCEDURE set_req_additional_attr(itemtype  IN VARCHAR2,
			itemkey   IN VARCHAR2,
			actid     IN NUMBER,
			funcmode  IN VARCHAR2,
			resultout OUT NOCOPY VARCHAR2);

  PROCEDURE set_dates_unchanged(itemtype  IN VARCHAR2,
		        itemkey   IN VARCHAR2,
		        actid     IN NUMBER,
		        funcmode  IN VARCHAR2,
		        resultout OUT NOCOPY VARCHAR2);

  PROCEDURE init_respond_note(itemtype  IN VARCHAR2,
		      itemkey   IN VARCHAR2,
		      actid     IN NUMBER,
		      funcmode  IN VARCHAR2,
		      resultout OUT NOCOPY VARCHAR2);

  FUNCTION get_last_mon_in_period(p_gl_period_name VARCHAR2) RETURN VARCHAR2;

  PROCEDURE record_acceptance(itemtype  IN VARCHAR2,
		      itemkey   IN VARCHAR2,
		      actid     IN NUMBER,
		      funcmode  IN VARCHAR2,
		      resultout OUT NOCOPY VARCHAR2);

  PROCEDURE update_orig_dates(itemtype  IN VARCHAR2,
		      itemkey   IN VARCHAR2,
		      actid     IN NUMBER,
		      funcmode  IN VARCHAR2,
		      resultout OUT NOCOPY VARCHAR2);

  PROCEDURE set_attr_email_doc(itemtype  IN VARCHAR2,
		       itemkey   IN VARCHAR2,
		       actid     IN NUMBER,
		       funcmode  IN VARCHAR2,
		       resultout OUT NOCOPY VARCHAR2);
  FUNCTION get_expense_type(p_code_combination_id NUMBER) RETURN VARCHAR2;

  PROCEDURE is_po_approval_needed(itemtype  IN VARCHAR2,
		          itemkey   IN VARCHAR2,
		          actid     IN NUMBER,
		          funcmode  IN VARCHAR2,
		          resultout OUT NOCOPY VARCHAR2);

  PROCEDURE is_po_approval_needed_std_cost(itemtype  IN VARCHAR2,
			       itemkey   IN VARCHAR2,
			       actid     IN NUMBER,
			       funcmode  IN VARCHAR2,
			       resultout OUT NOCOPY VARCHAR2);

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    is_po_created_from_requisition
  Author's Name:   Sandeep Akula
  Date Written:    05-JUNE-2014
  Purpose:         Checks if PO is created from Requisition
  Program Style:   Procedure Definition
  Called From:     Called in POAPPRV Workflow (Process: XX: Notify PO Approved Subprocess)
  Workflow Usage Details:
                     Item Type: PO Approval
                     Process Internal Name: XXPO_NOTIFY_PO_APPROVED
                     Process Display Name: XX: Notify PO Approved Subprocess
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  05-JUNE-2014        1.0                  Sandeep Akula     Initial Version -- CHG0031722
  ---------------------------------------------------------------------------------------------------*/
  PROCEDURE is_po_created_from_requisition(itemtype  IN VARCHAR2,
			       itemkey   IN VARCHAR2,
			       actid     IN NUMBER,
			       funcmode  IN VARCHAR2,
			       resultout OUT NOCOPY VARCHAR2);

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    set_preparer_username_attr
  Author's Name:   Sandeep Akula
  Date Written:    05-JUNE-2014
  Purpose:         Derives Preparer from the PO Requisition and sets the PREPARER_USER_NAME attribute
  Program Style:   Procedure Definition
  Called From:     Called in POAPPRV Workflow (Process: XX: Notify PO Approved Subprocess)
  Workflow Usage Details:
                     Item Type: PO Approval
                     Process Internal Name: XXPO_NOTIFY_PO_APPROVED
                     Process Display Name: XX: Notify PO Approved Subprocess
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  05-JUNE-2014        1.0                  Sandeep Akula     Initial Version -- CHG0031722
  ---------------------------------------------------------------------------------------------------*/
  PROCEDURE set_preparer_username_attr(itemtype  IN VARCHAR2,
			   itemkey   IN VARCHAR2,
			   actid     IN NUMBER,
			   funcmode  IN VARCHAR2,
			   resultout OUT NOCOPY VARCHAR2);

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    check_ou_in_prparernotf_lookup
  Author's Name:   Sandeep Akula
  Date Written:    05-JUNE-2014
  Purpose:         Checks if the Operating Unit of the PO is listed in PO Lookup "XXPO_OU_FOR_PREPARER_NOTIF"
  Program Style:   Procedure Definition
  Called From:     Called in POAPPRV Workflow (Process: XX: Notify PO Approved Subprocess)
  Workflow Usage Details:
                     Item Type: PO Approval
                     Process Internal Name: XXPO_NOTIFY_PO_APPROVED
                     Process Display Name: XX: Notify PO Approved Subprocess
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  05-JUNE-2014        1.0                  Sandeep Akula     Initial Version -- CHG0031722
  ---------------------------------------------------------------------------------------------------*/
  PROCEDURE check_ou_in_prparernotf_lookup(itemtype  IN VARCHAR2,
			       itemkey   IN VARCHAR2,
			       actid     IN NUMBER,
			       funcmode  IN VARCHAR2,
			       resultout OUT NOCOPY VARCHAR2);

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    check_ou_in_poapprv_ou_lookup
  Author's Name:   Sandeep Akula
  Date Written:    13-JUNE-2014
  Purpose:         Checks if the Operating Unit of the PO is listed in PO Lookup "XX_POAPPRV_OU"
  Program Style:   Procedure Definition
  Called From:     Called in POAPPRV Workflow (Process: XX: PO Approval Top Process)
  Workflow Usage Details:
                     Item Type: PO Approval
                     Process Internal Name: XXPO_POAPPRV_TOP
                     Process Display Name: XX: PO Approval Top Process
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  13-JUNE-2014        1.0                  Sandeep Akula     Initial Version -- CHG0031722
  ---------------------------------------------------------------------------------------------------*/
  PROCEDURE check_ou_in_poapprv_ou_lookup(itemtype  IN VARCHAR2,
			      itemkey   IN VARCHAR2,
			      actid     IN NUMBER,
			      funcmode  IN VARCHAR2,
			      resultout OUT NOCOPY VARCHAR2);

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    is_revision_greater_than_zero
  Author's Name:   Sandeep Akula
  Date Written:    13-JUNE-2014
  Purpose:         Checks if PO Revision is greater than zero
  Program Style:   Procedure Definition
  Called From:     Called in POAPPRV Workflow (Process: XX: Notify PO Approved Subprocess)
  Workflow Usage Details:
                     Item Type: PO Approval
                     Process Internal Name: XXPO_NOTIFY_PO_APPROVED
                     Process Display Name: XX: Notify PO Approved Subprocess
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  13-JUNE-2014        1.0                  Sandeep Akula     Initial Version -- CHG0031722
  ---------------------------------------------------------------------------------------------------*/
  PROCEDURE is_revision_greater_than_zero(itemtype  IN VARCHAR2,
			      itemkey   IN VARCHAR2,
			      actid     IN NUMBER,
			      funcmode  IN VARCHAR2,
			      resultout OUT NOCOPY VARCHAR2);

END xxpo_wf_notification_pkg;
/
