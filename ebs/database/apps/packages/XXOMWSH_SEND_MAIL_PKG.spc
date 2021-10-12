create or replace PACKAGE       XXOMWSH_SEND_MAIL_PKG IS
--------------------------------------------------------------------------------------------------
/*
$Revision:   1.0  $
Package Name:    XXOMWSH_SEND_MAIL_PKG.spc
Author's Name:   Sandeep Akula
Date Written:    6-AUG-2014
Purpose:         Checks if Parent program completed sucessfully and calls Bursting Engine to send emails
                 Parent Programs:
                 1. Used in XX SSUS: Packing List Report PDF Output via Mail
                 2. XX: Send Order Acknowledgment by Mail
                 3. XX: Order Acknowledgment
Program Style:   Stored Package SPECIFICATION
Called From:
Calls To:
Maintenance History:
Date:          Version                   Name            Remarks
-----------    ----------------         -------------   ------------------
6-AUG-2014        1.0                  Sandeep Akula    Initial Version -- CHG0032821
15-AUG-2014       1.1                  Sandeep Akula    Added Function GET_ORDER_DFF_EMAILS -- CHG0033045
03-MARCH-2015     1.2                  Sandeep Akula    Created New Functions is_delivery_closed and is_delivery_eligible -- CHG0034594
17-MAR-2015       1.3                  Sandeep Akula    Added New Functions DELIVERY_STATUS,DELIVERY_EXISTS,GET_NOTIFICATION_DETAILS 
                                                        Added New Procedures insert_mail_audit,UPDATE_STATUS,PROCESS_RECORDS
                                                        Modified Procedure MAIN with new logic  -- CHG0034594
---------------------------------------------------------------------------------------------------*/
FUNCTION GET_ORDER_CREATOR(p_delivery_id IN NUMBER DEFAULT NULL,
                           p_header_id IN NUMBER DEFAULT NULL)
RETURN VARCHAR2;

FUNCTION GET_ORDER_DFF_EMAILS(p_order_number IN NUMBER DEFAULT NULL,
                              p_org_id IN NUMBER DEFAULT NULL)
RETURN VARCHAR2;

FUNCTION DELIVERY_STATUS(p_delivery_id IN NUMBER,
                         p_organization_id IN NUMBER)
RETURN VARCHAR2;   

FUNCTION IS_DELIVERY_ELIGIBLE(p_delivery_id IN NUMBER,
                              p_organization_id IN NUMBER)
RETURN VARCHAR2; 

FUNCTION DELIVERY_EXISTS(p_delivery_id IN VARCHAR2,
                         p_organization_id IN VARCHAR2,
                         p_source IN VARCHAR2)
RETURN VARCHAR2;                         

FUNCTION GET_NOTIFICATION_DETAILS(p_request_id IN NUMBER)
RETURN VARCHAR2;

PROCEDURE insert_mail_audit(p_source      IN VARCHAR2,
                              p_email       IN VARCHAR2 DEFAULT NULL,
                              p_pk1         IN VARCHAR2,
                              p_pk2         IN VARCHAR2 DEFAULT NULL,
                              p_pk3         IN VARCHAR2 DEFAULT NULL,
                              p_ignore_flag IN VARCHAR2 DEFAULT NULL,
                              p_source_req_id IN NUMBER DEFAULT NULL,
                              p_wrapper_req_id IN NUMBER DEFAULT NULL,
                              p_bursting_req_id IN NUMBER DEFAULT NULL,
                              p_status      IN VARCHAR2 DEFAULT NULL);
                              
PROCEDURE UPDATE_STATUS(p_err_code OUT NUMBER,
                        p_err_msg OUT VARCHAR2);
                        
PROCEDURE PROCESS_RECORDS(p_err_code OUT NUMBER,
                          p_err_msg OUT VARCHAR2);                        
                        
PROCEDURE MAIN(errbuf OUT VARCHAR2,
               retcode OUT NUMBER,
               p_mode  IN  VARCHAR2,
               p_delivery IN NUMBER);

END XXOMWSH_SEND_MAIL_PKG;
/
