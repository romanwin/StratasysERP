create or replace PACKAGE GL_WF_CUSTOMIZATION_PKG AUTHID CURRENT_USER AS
/* $Header: glwfcuss.pls 120.2 2002/11/13 04:33:28 djogg ship $ */

  --
  -- Package
  --   GL_WF_CUSTOMIZATION_PKG
  -- Purpose
  --   Procedures for Journal Approval Process's customizable activities
  -- History
  --   08/28/97   R Goyal      Created
  --


  --
  -- Procedure
  --   Is_Je_Valid
  -- Purpose
  --   Determines if the journal batch is valid. This procedure is called from
  --   the GL Journal Approval Process activity named "Customizable: Is Journal
  --   Batch Valid" in the Journal Approval Workflow definition file. You may want
  --   to customize this activity by adding journal batch validation checks that
  --   are not encompassed by the default checks GL provides. The GL Journal
  --   Approval Process currently checks for:
  --   (1) Non-opened period
  --   (2) Control total violations
  --   (3) Untaxed journals in a batch (JE tax enabled only)
  --   (4) Unreserved funds (Budgetary control enabled only)
  --   (5) Frozen budget (Budget batches only)
  --   (6) Non-opened encumbrance year (Encumbrance batches only)
  -- History
  --   08/28/97     R Goyal     Created.
  -- Arguments
  --   itemtype   	   Workflow item type (JE Batch)
  --   itemkey    	   Unique item key
  --   actid		   ID of activity, provided by workflow engine
  --   funcmode		   Function mode (RUN or CANCEL)
  --   result		   Result of activity (COMPLETE:Y or COMPLETE:N)
  --                       COMPLETE:Y (Workflow transition branch "Yes") indicates
  --                                  that the journal batch is valid.
  --                       COMPLETE:N (Workflow transition branch "No") indicates
  --                                  that the journal batch is not valid.
  -- Notes
  --   You should only use the result codes listed above. Using unsupported
  --   result codes may cause unexpected behavior.
  --
  PROCEDURE is_je_valid  (itemtype	IN VARCHAR2,
		          itemkey	IN VARCHAR2,
                       	  actid      	IN NUMBER,
                       	  funcmode    	IN VARCHAR2,
                          result        OUT NOCOPY VARCHAR2 );


  --
  -- Procedure
  --   Does_JE_Need_Approval
  -- Purpose
  --   Determines if the journal batch needs approval. This procedure is called
  --   from the GL Journal Approval Process activity named "Customizable: Does
  --   Journal Batch Need Approval" in the Journal Approval Workflow
  --   definition file. You may want to customize this activity, for example, by
  --   adding code to allow certain users to approve their own journal batches on
  --   particular days within a period.
  -- History
  --   08/26/97      R Goyal    Created.
  -- Arguments
  --   itemtype   	   Workflow item type (JE Batch)
  --   itemkey    	   Unique item key.
  --   actid		   ID of activity, provided by workflow engine
  --   funcmode		   Function mode (RUN or CANCEL)
  --   result		   Result of activity (COMPLETE:Y or COMPLETE:N)
  --                       COMPLETE:Y (Workflow transition branch "Yes") indicates
  --                                  that the journal batch needs approval.
  --                       COMPLETE:N (Workflow transition branch "No") indicates
  --                                  that the journal batch does not need approval.
  -- Notes
  --   You should only use the result codes as listed above. Using unsupported
  --   result codes may cause unexpected behavior.
  --
  PROCEDURE does_je_need_approval( itemtype	IN VARCHAR2,
				   itemkey  	IN VARCHAR2,
				   actid	IN NUMBER,
				   funcmode	IN VARCHAR2,
				   result	OUT NOCOPY VARCHAR2 );


  --
  -- Procedure
  --   Can_Preparer_Approve
  -- Purpose
  --   Determines if the preparer can approve the journal batch. This procedure is
  --   called from the GL Journal Approval Process activity named "Customizable:
  --   Is Preparer Authorized to Approve" in the Journal Approval Workflow
  --   definition file. You may want to customize this activity, for example, to
  --   prevent a preparer from self-approving a journal batch based on the batch
  --   period, journal source, or other attributes.
  -- History
  --   08/28/97      R Goyal    Created.
  -- Arguments
  --   itemtype   	   Workflow item type (JE Batch)
  --   itemkey    	   Unique item key.
  --   actid		   ID of activity, provided by workflow engine
  --   funcmode		   Function mode (RUN or CANCEL)
  --   result		   Result of activity (COMPLETE:Y or COMPLETE:N)
  --                       COMPLETE:Y (Workflow transition branch "Yes") indicates
  --                                  that the preparer can self-approve the journal
  --                                  batch.
  --                       COMPLETE:N (Workflow transition branch "No") indicates
  --                                  that the preparer cannot self-approve the
  --                                  journal batch.
  -- Notes
  --   You should only use the result codes as listed above. Using unsupported
  --   result codes may cause unexpected behavior.
  --
  PROCEDURE can_preparer_approve( itemtype	IN VARCHAR2,
				  itemkey  	IN VARCHAR2,
				  actid	        IN NUMBER,
				  funcmode	IN VARCHAR2,
				  result	OUT NOCOPY VARCHAR2 );



  --
  -- Procedure
  --   Verify_Authority
  -- Purpose
  --   Determines if the approver has appropriate authority to approve the journal
  --   batch. This procedure is called from the GL Journal Approval Process activity
  --   named "Customizable: Verify Authority" within the "Customizable: Verify
  --   Authority Process" in the Journal Approval Workflow definition file. You may
  --   want to add your own checks to verify an approver's authority.  These customized
  --   checks will supplement the standard authorization limit check performed by
  --   the GL Journal Approval Process.
  -- History
  --   08/28/97      R Goyal    Created.
  -- Arguments
  --   itemtype   	   Workflow item type (JE Batch)
  --   itemkey    	   Unique item key.
  --   actid		   ID of activity, provided by workflow engine
  --   funcmode		   Function mode (RUN or CANCEL)
  --   result		   Result of activity (COMPLETE:PASS or COMPLETE:FAIL)
  --                       COMPLETE:PASS (Workflow transition branch "Pass") indicates
  --                                     that the approver passed the journal batch
  --                                     approval authorization check.
  --                       COMPLETE:FAIL (Workflow transition branch "Fail") indicates
  --                                     that the approver failed the journal batch
  --                                     approval authorization check.
  -- Notes
  --   You should only use the result codes as listed above. Using unsupported
  --   result codes may cause unexpected behavior.
  --
  PROCEDURE verify_authority( itemtype	IN VARCHAR2,
			      itemkey  	IN VARCHAR2,
			      actid	IN NUMBER,
			      funcmode	IN VARCHAR2,
			      result	OUT NOCOPY VARCHAR2 );


END GL_WF_CUSTOMIZATION_PKG;
/

