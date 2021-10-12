create or replace PACKAGE XXOE_AR_INTF_UPDATE_WF AS
  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Package Name:    xxoe_ar_intf_update_wf.spc
  Author's Name:   Sandeep Akula
  Date Written:    21-JULY-2015
  Purpose:         Order Line Workflow Customizations 
  Program Style:   Stored Package SPECIFICATION
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  21-JULY-2015        1.0                  Sandeep Akula    Initial Version (CHG0036062)
  ---------------------------------------------------------------------------------------------------*/

PROCEDURE initialize_attributes(itemtype  IN VARCHAR2,
                                itemkey   IN VARCHAR2,
                                actid     IN NUMBER,
                                funcmode  IN VARCHAR2,
                                resultout OUT NOCOPY VARCHAR2);
                           
PROCEDURE is_line_eligible(itemtype  IN VARCHAR2,
                           itemkey   IN VARCHAR2,
                           actid     IN NUMBER,
                           funcmode  IN VARCHAR2,
                           resultout OUT NOCOPY VARCHAR2);
 
PROCEDURE update_ar_interface(itemtype  IN VARCHAR2,
                              itemkey   IN VARCHAR2,
                              actid     IN NUMBER,
                              funcmode  IN VARCHAR2,
                              resultout OUT NOCOPY VARCHAR2);
END XXOE_AR_INTF_UPDATE_WF;
/

