CREATE OR REPLACE PACKAGE xxap_invoices_upload AUTHID CURRENT_USER AS
  ---------------------------------------------------------------------------
  -- $Header: xxap_invoices_upload   $
  ---------------------------------------------------------------------------
  -- Package: xxap_invoices_upload
  -- Created:
  -- Author  :
  --------------------------------------------------------------------------
  -- Perpose: upload scan invoices into fnd_lobs
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  16.08.11   yuval tal            Initial Build
  --     1.1   21.9.11   YUVAL TAL            add get_wf_inv_att - for display attachmnets in
  --                                          invoice approval notuification)
  --     1.2  2-JUL-2014 sandeep akula        CHG0031533 Changes
  --                                          Added Procedures invoice_requester_exists, get_nonmatched_inv_profile, needs_reapproval, is_ssus_op_unit
  --                                          Added Functions check_active_person and validate_approver
  --     1.3  12-AUG-2014 sandeep akula       CHG0032899 Changes
  --                                          Added Variable l_org_id
  --                                          Added Condition to send emails to Stratasys US Accounts Payable
  -- 1.4         29.11.15  yuval tal          CHG0037104 - ignore locking of file when tring to delete
  --                                          add function is_invoice_exists

  ---------------------------------------------------------------------------
  PROCEDURE get_pk(p_file_name       VARCHAR2,
	       p_out_invoive_id  OUT NUMBER,
	       p_out_voucher_num OUT VARCHAR2,
	       p_err_code        OUT NUMBER,
	       p_err_message     OUT VARCHAR2);
  PROCEDURE upload_invoices_process(errbuf          OUT VARCHAR2,
			retcode         OUT VARCHAR2,
			p_dir           VARCHAR2,
			p_unmatch_dir   VARCHAR2,
			p_category_name VARCHAR2);

  FUNCTION get_content_type(p_ext VARCHAR2) RETURN VARCHAR2;
  PROCEDURE is_objet_approval_needded(itemtype  IN VARCHAR2,
			  itemkey   IN VARCHAR2,
			  actid     IN NUMBER,
			  funcmode  IN VARCHAR2,
			  resultout OUT NOCOPY VARCHAR2);

  PROCEDURE is_invoice_exists(itemtype  IN VARCHAR2,
		      itemkey   IN VARCHAR2,
		      actid     IN NUMBER,
		      funcmode  IN VARCHAR2,
		      resultout OUT NOCOPY VARCHAR2);

  FUNCTION is_scan_invoice_exists(p_invoice_id NUMBER) RETURN VARCHAR2;

  FUNCTION is_attached_file_exists(p_invoice_id NUMBER,
		           p_file_name  VARCHAR2) RETURN VARCHAR2;
  PROCEDURE get_wf_inv_attachmnets(document_id   IN VARCHAR2,
		           display_type  IN VARCHAR2,
		           document      IN OUT BLOB,
		           document_type IN OUT VARCHAR2);

  PROCEDURE process_doc_rejection(itemtype  IN VARCHAR2,
		          itemkey   IN VARCHAR2,
		          actid     IN NUMBER,
		          funcmode  IN VARCHAR2,
		          resultout OUT NOCOPY VARCHAR2);

  PROCEDURE init_attribute_wf(itemtype  IN VARCHAR2,
		      itemkey   IN VARCHAR2,
		      actid     IN NUMBER,
		      funcmode  IN VARCHAR2,
		      resultout OUT NOCOPY VARCHAR2);

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    invoice_requester_exists
  Author's Name:   Sandeep Akula
  Date Written:    18-JUNE-2014
  Purpose:         Checks if Requestor exists for the Invoice in Invoice Workbench
  Program Style:   Procedure Definition
  Called From:     Called in APINVAPR Workflow (Process: Main Approval Process)
  Workflow Usage Details:
                     Item Type: AP Invoice Approval
                     Process Internal Name: APPROVAL_MAIN
                     Process Display Name: Main Approval Process
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  18-JUNE-2014        1.0                  Sandeep Akula     Initial Version -- CHG0031533
  ---------------------------------------------------------------------------------------------------*/
  PROCEDURE invoice_requester_exists(itemtype  IN VARCHAR2,
			 itemkey   IN VARCHAR2,
			 actid     IN NUMBER,
			 funcmode  IN VARCHAR2,
			 resultout OUT NOCOPY VARCHAR2);

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    get_nonmatched_inv_profile
  Author's Name:   Sandeep Akula
  Date Written:    18-JUNE-2014
  Purpose:         Derives the value for profile XXAP_INV_WF_EXECUTE_NONMATCHED_INV_REQUESTER_LOGIC
  Program Style:   Procedure Definition
  Called From:     Called in APINVAPR Workflow (Process: Main Approval Process)
  Workflow Usage Details:
                     Item Type: AP Invoice Approval
                     Process Internal Name: APPROVAL_MAIN
                     Process Display Name: Main Approval Process
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  18-JUNE-2014        1.0                  Sandeep Akula     Initial Version -- CHG0031533
  ---------------------------------------------------------------------------------------------------*/
  PROCEDURE get_nonmatched_inv_profile(itemtype  IN VARCHAR2,
			   itemkey   IN VARCHAR2,
			   actid     IN NUMBER,
			   funcmode  IN VARCHAR2,
			   resultout OUT NOCOPY VARCHAR2);

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    needs_reapproval
  Author's Name:   Sandeep Akula
  Date Written:    18-JUNE-2014
  Purpose:         Updates wfapproval_status column in Invoice Header and Lines tables
  Program Style:   Procedure Definition
  Called From:     Called in APINVAPR Workflow (Process: Main Approval Process)
  Workflow Usage Details:
                     Item Type: AP Invoice Approval
                     Process Internal Name: APPROVAL_MAIN
                     Process Display Name: Main Approval Process
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  18-JUNE-2014        1.0                  Sandeep Akula     Initial Version -- CHG0031533
  ---------------------------------------------------------------------------------------------------*/
  PROCEDURE needs_reapproval(itemtype  IN VARCHAR2,
		     itemkey   IN VARCHAR2,
		     actid     IN NUMBER,
		     funcmode  IN VARCHAR2,
		     resultout OUT NOCOPY VARCHAR2);

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    is_ssus_op_unit
  Author's Name:   Sandeep Akula
  Date Written:    18-JUNE-2014
  Purpose:         If the Operating Unit is SSUS this procedure will return Y else N
  Program Style:   Procedure Definition
  Called From:     Called in APINVAPR Workflow (Process: Main Approval Process)
  Workflow Usage Details:
                     Item Type: AP Invoice Approval
                     Process Internal Name: APPROVAL_INVOICE
                     Process Display Name: Invoice Approval Process
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  18-JUNE-2014        1.0                  Sandeep Akula     Initial Version -- CHG0031533
  ---------------------------------------------------------------------------------------------------*/
  PROCEDURE is_ssus_op_unit(itemtype  IN VARCHAR2,
		    itemkey   IN VARCHAR2,
		    actid     IN NUMBER,
		    funcmode  IN VARCHAR2,
		    resultout OUT NOCOPY VARCHAR2);

  /*PROCEDURE get_invoice_notif_details(document_id     IN              VARCHAR2,
  display_type    IN              VARCHAR2,
  document        IN OUT NOCOPY   CLOB,
  document_type   IN OUT NOCOPY   VARCHAR2);  */

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    check_active_person
  Author's Name:   Sandeep Akula
  Date Written:    17-JULY-2014
  Purpose:         Checks if the Person is Active in HR, has a Role record in wf_roles and has a active FND_USER record
  Program Style:   Procedure Definition
  Called From:     Called in XX_AP_INVOICE_APPROVER AME Approver Groups
  AME Usage Details:
                     Approver Group: XX_AP_INVOICE_APPROVER
                     Transaction Type: Payables Invoice Approval
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  17-JULY-2014        1.0                  Sandeep Akula     Initial Version -- CHG0031533
  ---------------------------------------------------------------------------------------------------*/

  FUNCTION check_active_person(p_person_id IN NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    validate_approver
  Author's Name:   Sandeep Akula
  Date Written:    17-JULY-2014
  Purpose:         Derives the approver from AP Invoice if Original Approver is Terminated. The Approver derived will be the requester on the Invoice
  Program Style:   Procedure Definition
  Called From:     Called in XX_AP_INVOICE_APPROVER AME Approver Groups
  AME Usage Details:
                     Approver Group: XX_AP_INVOICE_APPROVER
                     Transaction Type: Payables Invoice Approval
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  17-JULY-2014        1.0                  Sandeep Akula     Initial Version -- CHG0031533
  ---------------------------------------------------------------------------------------------------*/

  FUNCTION validate_approver(p_person_id    IN NUMBER,
		     p_invoice_id   IN NUMBER,
		     p_po_header_id IN NUMBER) RETURN NUMBER;

END xxap_invoices_upload;
/
