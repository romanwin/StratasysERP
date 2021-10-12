create or replace PACKAGE xxom_order_header_wf AUTHID CURRENT_USER AS
  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Package Name:    xxom_order_header_wf.spc
  Author's Name:   Sandeep Akula
  Date Written:    02-MARCH-2015
  Purpose:         Order Header Workflow Customizations 
  Program Style:   Stored Package SPECIFICATION
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  02-MARCH-2015        1.0                  Sandeep Akula    Initial Version (CHG0034606)
  ---------------------------------------------------------------------------------------------------*/

PROCEDURE get_wait_time(itemtype  IN VARCHAR2,
                        itemkey   IN VARCHAR2,
                        actid     IN NUMBER,
                        funcmode  IN VARCHAR2,
                        resultout OUT NOCOPY VARCHAR2);
                        
PROCEDURE retry_om_header_activity(errbuf OUT VARCHAR2,
                                   retcode OUT NUMBER,
                                   p_itemtype IN VARCHAR2,
                                   p_activity IN VARCHAR2,
                                   p_command IN VARCHAR2,
                                   p_start_date IN VARCHAR2,
                                   p_end_date IN VARCHAR2);                            

END xxom_order_header_wf;
/
