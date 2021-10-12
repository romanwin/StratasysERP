create or replace PACKAGE BODY xxomwsh_send_mail_pkg IS
  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Package Name:    XXOMWSH_SEND_MAIL_PKG.bdy
  Author's Name:   Sandeep Akula
  Date Written:    6-AUG-2014
  Purpose:         Checks if Parent program completed sucessfully and calls Bursting Engine to send emails
                   Parent Programs:
                   1. Used in XX SSUS: Packing List Report PDF Output via Mail
                   2. XX: Send Order Acknowledgment by Mail
                   3. XX: Order Acknowledgment
  Program Style:   Stored Package BODY
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  6-AUG-2014        1.0                  Sandeep Akula    Initial Version -- CHG0032821
  15-AUG-2014       1.1                  Sandeep Akula    Added Function GET_ORDER_DFF_EMAILS -- CHG0033045
                                                          Changed Messages in EXCEPTION section of the package -- CHG0033045
  24-SEP-2014       1.2                  Sandeep Akula    Removed the wait Logic for Bursting Program -- CHG0033368
                                                          Program will not wait for Bursting Program to complete. Changes made due to Issues with Concurrent Manager Load
  03-MARCH-2015     1.3                  Sandeep Akula    Created New Functions delivery_status  and is_delivery_eligible -- CHG0034594   
  17-MAR-2015       1.4                  Sandeep Akula    Added New Functions DELIVERY_STATUS,DELIVERY_EXISTS,GET_NOTIFICATION_DETAILS 
                                                          Added New Procedures insert_mail_audit,UPDATE_STATUS,PROCESS_RECORDS
                                                          Modified Procedure MAIN with new logic  -- CHG0034594
  ---------------------------------------------------------------------------------------------------*/
  FUNCTION get_order_creator(p_delivery_id IN NUMBER DEFAULT NULL,
                             p_header_id   IN NUMBER DEFAULT NULL)
    RETURN VARCHAR2 IS
    l_creator fnd_user.user_name%TYPE;
  BEGIN

    IF p_delivery_id IS NOT NULL THEN

      l_creator := '';
      BEGIN
        SELECT DISTINCT c.user_name
        INTO   l_creator
        FROM   wsh_deliverables_v   a,
               oe_order_headers_all b,
               fnd_user             c
        WHERE  a.source_header_id = b.header_id
        AND    b.created_by = c.user_id(+)
        AND    a.delivery_id = p_delivery_id;
      EXCEPTION
        WHEN OTHERS THEN
          l_creator := '';
      END;

    ELSE

      l_creator := '';
      BEGIN
        SELECT DISTINCT b.user_name
        INTO   l_creator
        FROM   oe_order_headers_all a,
               fnd_user             b
        WHERE  a.created_by = b.user_id(+)
        AND    a.header_id = p_header_id;
      EXCEPTION
        WHEN OTHERS THEN
          l_creator := '';
      END;

    END IF;

    RETURN(nvl(l_creator, 'RACHEL.QUANCE'));

  END get_order_creator;

  FUNCTION get_order_dff_emails(p_order_number IN NUMBER DEFAULT NULL,
                                p_org_id       IN NUMBER DEFAULT NULL)
    RETURN VARCHAR2 IS
    l_emails VARCHAR2(2000) := '';

  BEGIN

    BEGIN
      SELECT attribute20
      INTO   l_emails
      FROM   oe_order_headers_all
      WHERE  order_number = p_order_number
      AND    org_id = p_org_id;
    EXCEPTION
      WHEN OTHERS THEN
        l_emails := '';
    END;

    RETURN(l_emails);

  END get_order_dff_emails;

--------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    DELIVERY_STATUS
  Author's Name:   Sandeep Akula
  Date Written:    03-MARCH-2015
  Purpose:         Checks if the Delivery is closed. Return Y if Delivery is closed else returns N.
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  03-MARCH-2015        1.0                  Sandeep Akula     Initial Version -- CHG0034594
  ---------------------------------------------------------------------------------------------------*/
FUNCTION DELIVERY_STATUS(p_delivery_id IN NUMBER,
                         p_organization_id IN NUMBER)
RETURN VARCHAR2 IS
l_status  varchar2(100);
BEGIN

l_status := '';
select status_code
into l_status
from wsh_new_deliveries
where delivery_id = p_delivery_id and
organization_id = p_organization_id;

RETURN(l_status);

EXCEPTION
WHEN OTHERS THEN
RETURN(l_status);
END DELIVERY_STATUS;

--------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    IS_DELIVERY_ELIGIBLE
  Author's Name:   Sandeep Akula
  Date Written:    03-MARCH-2015
  Purpose:         Checks the Delivery status and Override Flag.
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  03-MARCH-2015        1.0                  Sandeep Akula     Initial Version -- CHG0034594
  ---------------------------------------------------------------------------------------------------*/
FUNCTION IS_DELIVERY_ELIGIBLE(p_delivery_id IN NUMBER,
                              p_organization_id IN NUMBER)
RETURN VARCHAR2 IS
l_override_flag  fnd_profile_option_values.profile_option_value%TYPE := fnd_profile.value('XXOM_SEND_EMAIL_FOR_CLOSED_DELIVERIES');
BEGIN

IF DELIVERY_STATUS(p_delivery_id,p_organization_id) = 'CL' and nvl(l_override_flag,'N') = 'N' THEN
RETURN('N');
ELSE
RETURN('Y');
END IF;


EXCEPTION
WHEN OTHERS THEN
RETURN('N');
END IS_DELIVERY_ELIGIBLE;

--------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    DELIVERY_EXISTS
  Author's Name:   Sandeep Akula
  Date Written:    16-MARCH-2015
  Purpose:         Checks if Delivery data exists in the Mail Audit Table 
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  16-MARCH-2015        1.0                  Sandeep Akula     Initial Version -- CHG0034594
  ---------------------------------------------------------------------------------------------------*/
FUNCTION DELIVERY_EXISTS(p_delivery_id IN VARCHAR2,
                         p_organization_id IN VARCHAR2,
                         p_source IN VARCHAR2)
RETURN VARCHAR2 IS
l_cnt NUMBER;
BEGIN

select count(*)
into l_cnt
from xxobjt_mail_audit
where pk1 = p_delivery_id and
      pk2 = p_organization_id and
      source_code = p_source;

IF l_cnt > '0' THEN
RETURN('Y');
ELSE
RETURN('N');
END IF;

EXCEPTION
WHEN OTHERS THEN
RETURN('Y');
END DELIVERY_EXISTS;

 --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    Insert_mail_audit
  Author's Name:   Sandeep Akula
  Date Written:    16-MARCH-2015
  Purpose:         Insert Mail Audit data into table xxobjt_mail_audit
  Program Style:   Procedure Definition (Pragma AUTONOMOUS Transaction)
  Called From:     Called in After Report Trigger of Report "XX SSUS: Packing List Report PDF Output via Mail"
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  13-MARCH-2014        1.0                  Sandeep Akula     Initial Version -- CHG0034594
  ---------------------------------------------------------------------------------------------------*/
  PROCEDURE insert_mail_audit(p_source      IN VARCHAR2,
                              p_email       IN VARCHAR2 DEFAULT NULL,
                              p_pk1         IN VARCHAR2,
                              p_pk2         IN VARCHAR2 DEFAULT NULL,
                              p_pk3         IN VARCHAR2 DEFAULT NULL,
                              p_ignore_flag IN VARCHAR2 DEFAULT NULL,
                              p_source_req_id IN NUMBER DEFAULT NULL,
                              p_wrapper_req_id IN NUMBER DEFAULT NULL,
                              p_bursting_req_id IN NUMBER DEFAULT NULL,
                              p_status      IN VARCHAR2 DEFAULT NULL) IS
    PRAGMA AUTONOMOUS_TRANSACTION;

BEGIN

IF DELIVERY_EXISTS(p_pk1,p_pk2,p_source) = 'N' THEN

      INSERT INTO xxobjt_mail_audit
        (source_code,
         email,
         creation_date,
         created_by,
         pk1,
         pk2,
         pk3,
         ignore_flag,
         source_request_id,
         wrapper_request_id,
         bursting_request_id,
         status,
         last_updated_by,
         last_update_date)
     VALUES(p_source,
         p_email,
         SYSDATE,
         fnd_global.user_id,
         p_pk1,
         p_pk2,
         p_pk3,
         p_ignore_flag,
         p_source_req_id,
         p_wrapper_req_id,
         p_bursting_req_id,
         p_status,
         fnd_global.user_id,
         SYSDATE);
         
END IF;         
         
COMMIT;

END insert_mail_audit;

--------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    GET_NOTIFICATION_DETAILS
  Author's Name:   Sandeep Akula
  Date Written:    16-MARCH-2015
  Purpose:         Derivies the Paramters used for Packing List Report based on the request id
  Program Style:   Function Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  16-MARCH-2015        1.0                  Sandeep Akula     Initial Version -- CHG0034594
  ---------------------------------------------------------------------------------------------------*/
FUNCTION GET_NOTIFICATION_DETAILS(p_request_id IN NUMBER)
RETURN VARCHAR2 IS

    -- Error Notification Variables
    l_notf_warehouse               VARCHAR2(100) := '';
    l_notf_delivery                VARCHAR2(100) := '';
    l_notf_print_customer_item     VARCHAR2(100) := '';
    l_notf_item_display            VARCHAR2(100) := '';
    l_notf_print_mode              VARCHAR2(100) := '';
    l_notf_sort_by                 VARCHAR2(100) := '';
    l_notf_delivery_date_low       VARCHAR2(100) := '';
    l_notf_delivery_date_high      VARCHAR2(100) := '';
    l_notf_display_unshipped_items VARCHAR2(100) := '';
    l_notf_send_mail               VARCHAR2(100) := '';
    l_notf_requestor               VARCHAR2(200) := '';
    l_notf_data                    VARCHAR(32767) := '';
    l_notf_header_id               VARCHAR2(100) := '';
    l_notf_batch_mode              VARCHAR2(100) := '';
    l_notf_subject                 VARCHAR2(2000) := '';
    l_notf_order_number            NUMBER := '';
    l_notf_org_id                  NUMBER := ''; 
    l_notf_order_creator           VARCHAR2(200) := '';

BEGIN

begin
select trim(substr(argument_text,1,instr(argument_text,',',1,1)-1)) warehouse,
trim(substr(argument_text,instr(argument_text,',',1,1)+1,instr(argument_text,',',1,2)-instr(argument_text,',',1,1)-1)) delivery,
trim(substr(argument_text,instr(argument_text,',',1,2)+1,instr(argument_text,',',1,3)-instr(argument_text,',',1,2)-1)) print_customer_item,
trim(substr(argument_text,instr(argument_text,',',1,3)+1,instr(argument_text,',',1,4)-instr(argument_text,',',1,3)-1)) Item_display,
trim(substr(argument_text,instr(argument_text,',',1,4)+1,instr(argument_text,',',1,5)-instr(argument_text,',',1,4)-1)) print_mode,
trim(substr(argument_text,instr(argument_text,',',1,5)+1,instr(argument_text,',',1,6)-instr(argument_text,',',1,5)-1)) sort_by,
trim(substr(argument_text,instr(argument_text,',',1,6)+1,instr(argument_text,',',1,7)-instr(argument_text,',',1,6)-1)) Delivery_Date_low,
trim(substr(argument_text,instr(argument_text,',',1,7)+1,instr(argument_text,',',1,8)-instr(argument_text,',',1,7)-1)) Delivery_Date_high,
trim(substr(argument_text,instr(argument_text,',',1,10)+1,instr(argument_text,',',1,11)-instr(argument_text,',',1,10)-1)) Display_unshipped_items,
trim(substr(argument_text,instr(argument_text,',',1,11)+1)) send_mail,
requestor
into l_notf_warehouse,l_notf_delivery,l_notf_print_customer_item,l_notf_Item_display,l_notf_print_mode,
      l_notf_sort_by,l_notf_Delivery_Date_low,l_notf_Delivery_Date_high,l_notf_Display_unshipped_items,
      l_notf_send_mail,l_notf_requestor
from fnd_conc_req_summary_v
where request_id = p_request_id;
exception
when others then
null;
end;

l_notf_data := 'Warehouse:'||l_notf_warehouse||chr(10)||
               'Delivery:'||l_notf_delivery||chr(10)||
               'Print Customer Item:'||l_notf_print_customer_item||chr(10)||
               'Item Display:'||l_notf_Item_display||chr(10)||
               'Print Mode:'||l_notf_print_mode||chr(10)||
               'Sort By:'||l_notf_sort_by||chr(10)||
               'Delivery Date Low:'||l_notf_Delivery_Date_low||chr(10)||
               'Delivery Date High:'||l_notf_Delivery_Date_high||chr(10)||
               'Display Unshipped Items:'||l_notf_Display_unshipped_items||chr(10)||
               'Send Mail:'||l_notf_send_mail||chr(10)||
               'Requestor:'||l_notf_requestor;

  RETURN(l_notf_data);
  
EXCEPTION
WHEN OTHERS THEN
RETURN(l_notf_data);
END GET_NOTIFICATION_DETAILS;

--------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    UPDATE_STATUS
  Author's Name:   Sandeep Akula
  Date Written:    16-MARCH-2015
  Purpose:         Updates Mail Audit Table with Bursting Request Status 
  Program Style:   Procedure Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  16-MARCH-2015        1.0                  Sandeep Akula     Initial Version -- CHG0034594
  ---------------------------------------------------------------------------------------------------*/
PROCEDURE UPDATE_STATUS(p_err_code OUT NUMBER,
                        p_err_msg OUT VARCHAR2) IS
  
TYPE S_DELIVERIES IS TABLE OF xxobjt_mail_audit%ROWTYPE
INDEX BY PLS_INTEGER;  
l_s_deliveries s_deliveries;  

l_error_message     VARCHAR2(32767) := '';
l_prg_exe_counter   VARCHAR2(10);
l_status_code      fnd_concurrent_requests.status_code%type;
l_phase_code      fnd_concurrent_requests.phase_code%type;
l_cnt             NUMBER;
                        
BEGIN

/* Updating Bursting Request Status */ 

l_prg_exe_counter := '22';  

l_cnt := '';
SELECT count(*)
INTO l_cnt        
FROM xxobjt_mail_audit
WHERE source_code = 'XXSSUS_WSHRDPAKSM' and
      status = 'IN_PROCESS';
 
l_prg_exe_counter := '23';   
      
IF l_cnt > '0' THEN       

l_prg_exe_counter := '24';        
-- Updating Status of Deliveries whose status is SUBMITTED 
-- Submitted Deliveries 
SELECT *
BULK COLLECT INTO l_s_deliveries        
FROM xxobjt_mail_audit
WHERE source_code = 'XXSSUS_WSHRDPAKSM' and
      status = 'IN_PROCESS';  
      
l_prg_exe_counter := '25';        
      
FOR indx IN 1 .. l_s_deliveries.COUNT 
LOOP      

l_prg_exe_counter := '26';
l_status_code := ''; 
l_phase_code := '';
begin
select status_code,phase_code
into l_status_code,l_phase_code
from fnd_conc_req_summary_v
where request_id = l_s_deliveries(indx).bursting_request_id;
exception
when others then
l_status_code := null;
end;  

l_prg_exe_counter := '27';

IF l_phase_code = 'C' THEN
l_prg_exe_counter := '28';

IF l_status_code = 'C' THEN
l_prg_exe_counter := '29';

l_error_message:= 'IF: Error Occured while Updating table xxobjt_mail_audit with Bursting status for delivery :'||l_s_deliveries(indx).pk1;
UPDATE xxobjt_mail_audit
SET status = 'MAIL SENT',
    last_updated_by = fnd_global.user_id,
    last_update_date = SYSDATE
WHERE source_code = l_s_deliveries(indx).source_code and
      pk1 = l_s_deliveries(indx).pk1;
      
l_prg_exe_counter := '30';
ELSE

l_prg_exe_counter := '31';
l_error_message:= 'ELSE: Error Occured while Updating table xxobjt_mail_audit with Bursting status for delivery :'||l_s_deliveries(indx).pk1;
UPDATE xxobjt_mail_audit
SET status = 'ERROR',
    last_updated_by = fnd_global.user_id,
    last_update_date = SYSDATE
WHERE source_code = l_s_deliveries(indx).source_code and
      pk1 = l_s_deliveries(indx).pk1;
      
l_prg_exe_counter := '32';
END IF;

l_prg_exe_counter := '33';

END IF;  

l_prg_exe_counter := '34';  
END LOOP;   
COMMIT;

l_prg_exe_counter := '35';  
p_err_code := '0';
p_err_msg := NULL;

ELSE
l_prg_exe_counter := '36';  
p_err_code := '0';
p_err_msg := NULL;
END IF;

EXCEPTION
WHEN OTHERS THEN
p_err_code := '1';
p_err_msg := 'UPDATE MODE:'||l_error_message||' - '||' Prg Cntr :'||l_prg_exe_counter||' - '||SQLERRM;
END UPDATE_STATUS;

--------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    PROCESS_RECORDS
  Author's Name:   Sandeep Akula
  Date Written:    16-MARCH-2015
  Purpose:         Checks Mail Audit Table for eligible deliveries and Calls Bursting Engine to send emails
  Program Style:   Procedure Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  16-MARCH-2015        1.0                  Sandeep Akula     Initial Version -- CHG0034594
  ---------------------------------------------------------------------------------------------------*/
PROCEDURE PROCESS_RECORDS(p_err_code OUT NUMBER,
                          p_err_msg OUT VARCHAR2) IS
                          
TYPE U_DELIVERIES IS TABLE OF xxobjt_mail_audit%ROWTYPE
  INDEX BY PLS_INTEGER;  
l_u_deliveries u_deliveries;  

l_instance_name     v$database.name%TYPE;
l_error_message     VARCHAR2(32767) := '';
l_request_id        NUMBER := fnd_global.conc_request_id;
l_burst_request_id NUMBER;
l_prg_exe_counter   VARCHAR2(10);
burst_submit_excp EXCEPTION;
l_order_number oe_order_headers_all.order_number%type;
l_order_creator fnd_user.user_name%type;
l_mail_list        VARCHAR2(1000);
l_err_code         NUMBER;
l_err_msg          VARCHAR2(200);
l_status_code      fnd_concurrent_requests.status_code%type;
l_phase_code      fnd_concurrent_requests.phase_code%type;
l_cnt   NUMBER;    

-- Variables for Print Options
l_boolean1     BOOLEAN;
l_boolean2     BOOLEAN;
l_printer_name VARCHAR2(100) := 'noprint';
                          
BEGIN

-- Processing Unprocessed Data from Mail Audit Table 

l_prg_exe_counter := '3';
l_cnt := '';
SELECT count(*)
INTO l_cnt        
FROM xxobjt_mail_audit
WHERE source_code = 'XXSSUS_WSHRDPAKSM' and
      status = 'UNPROCESSED';
      
IF l_cnt > '0' THEN

l_prg_exe_counter := '4';
-- Unprocessed Deliveries     
-- Submitting Bursting Programs for Eligible Deliveries   
-- Fetching Mail Audit data into a PL/SQL Table 
SELECT *
BULK COLLECT INTO l_u_deliveries        
FROM xxobjt_mail_audit
WHERE source_code = 'XXSSUS_WSHRDPAKSM' and
      status = 'UNPROCESSED';
      
FOR indx IN 1 .. l_u_deliveries.COUNT 
LOOP      

l_prg_exe_counter := '5';  
  BEGIN
   
     l_prg_exe_counter := '6';
     l_order_number := '';
     BEGIN
        SELECT DISTINCT source_header_number
        INTO   l_order_number
        FROM   wsh_deliverables_v
        WHERE  delivery_id = to_number(l_u_deliveries(indx).pk1);
      EXCEPTION
        WHEN OTHERS THEN
          l_order_number := '';
      END;
     
     l_prg_exe_counter := '7';
     l_order_creator := '';
     l_error_message := 'Error Occured while deriving l_order_creator';
     l_order_creator := get_order_creator(p_delivery_id => to_number(l_u_deliveries(indx).pk1));
   
   
      l_prg_exe_counter := '8';
      -- Set printer options
      l_error_message := 'Error Occured while seeting Print Options';
      l_boolean1 := fnd_submit.set_print_options(printer => l_printer_name,
                                                 style   => 'LANDSCAPE',
                                                 copies  => '0');
                                                 
      l_prg_exe_counter := '9';
      
      --Add printer
      l_error_message := 'Error Occured while adding Print Copies';
      l_boolean2 := fnd_request.add_printer(printer => l_printer_name,
                                            copies  => '0');

      l_prg_exe_counter := '10';

      l_error_message    := 'Error Occured while Calling the Standard Bursting Engine';
      l_burst_request_id := fnd_request.submit_request(application => 'XDO',
                                                       program     => 'XDOBURSTREP',
                                                       argument1   => 'Y',
                                                       argument2   => l_u_deliveries(indx).source_request_id -- Packing List Request ID
                                                       );
      COMMIT;
      l_prg_exe_counter := '11';
      
      IF l_burst_request_id = 0 THEN
        l_prg_exe_counter := '12';
        RAISE burst_submit_excp;

      ELSE
        l_prg_exe_counter := '13';
        apps.fnd_file.put_line(apps.fnd_file.log,'Submitted the Bursting concurrent program with request_id :' ||l_burst_request_id);
         l_prg_exe_counter := '14';
         l_error_message := 'Error Occured while updating Mail Audit Table for Delivery :'||l_u_deliveries(indx).pk1;
            UPDATE xxobjt_mail_audit
            SET status = 'IN_PROCESS',
                wrapper_request_id = l_request_id,
                bursting_request_id = l_burst_request_id,
                last_updated_by = fnd_global.user_id,
                last_update_date = SYSDATE
            WHERE source_code = l_u_deliveries(indx).source_code and
                  pk1 = l_u_deliveries(indx).pk1;
         l_prg_exe_counter := '15';
      END IF; 
    
   l_prg_exe_counter := '16';  
EXCEPTION
WHEN burst_submit_excp THEN
l_error_message := l_error_message || ' - ' || ' Prg Cntr :' ||l_prg_exe_counter || ' - ' || SQLERRM;
      /* Sending Failure Email */
      l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
                                                                 p_program_short_name => l_u_deliveries(indx).source_code);
       xxobjt_wf_mail.send_mail_text(p_to_role     => l_order_creator,
                                     p_cc_mail     => l_mail_list,
                                     p_subject     => 'Ship Confirmation Email Failed.Could not send email to Customer for Order ' ||l_order_number || ' and Delivery ' ||l_u_deliveries(indx).pk1,
                                     p_body_text   => 'Bursting Program'||' Submit Exception Failure'||chr(10)||
                                                      chr(10)||
                                                      '*******  Technical Details *********'||chr(10)||  
                                                      'Packing List report Request Id :'||l_u_deliveries(indx).source_request_id||chr(10)||
                                                      'OM send mail Program Request Id :'||l_request_id||chr(10)||
                                                      'Bursting Program Request Id :'||l_burst_request_id||chr(10)||
                                                      'Exception : BURST_SUBMIT_EXCP'||chr(10)||
                                                      'Burst Emails :'||l_u_deliveries(indx).email||chr(10)||  
                                                      'Error Message :' ||'Bursting Program Could not be submitted' ||chr(10) || 'Error Message :' || l_error_message||chr(10)||
                                                      '*******  Parameters *********'||chr(10)||
                                                      get_notification_details(to_number(l_u_deliveries(indx).source_request_id)),
                                     p_err_code    => l_err_code,
                                     p_err_message => l_err_msg);
WHEN OTHERS THEN
      l_error_message := l_error_message||' - '||' Prg Cntr :'||l_prg_exe_counter||' - '||SQLERRM;
       /* Sending Failure Email */
        l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
                                                                   p_program_short_name => l_u_deliveries(indx).source_code);
        xxobjt_wf_mail.send_mail_text(p_to_role     => l_order_creator,
                                      p_cc_mail     => l_mail_list,
                                      p_subject     => 'Ship Confirmation Email Failed.Could not send email to Customer for Order ' ||l_order_number || ' and Delivery ' ||l_u_deliveries(indx).pk1,
                                      p_body_text   => 'XX: OMWSH Send Request Output To Mail - Failure'||chr(10)|| 
                                                       '*******  Technical Details *********'||chr(10)||   
                                                       'Packing List report Request Id :'||l_u_deliveries(indx).source_request_id||chr(10)||
                                                       'OM send mail Program Request Id :'||l_request_id||chr(10)||
                                                       'Bursting Program Request Id :'||l_burst_request_id||chr(10)||
                                                       'Exception : OTHERS'||chr(10)||
                                                       'Burst Emails :'||l_u_deliveries(indx).email||chr(10)|| 
                                                       'Error Message :' ||l_error_message||chr(10)||
                                                       '*******  Parameters *********'||chr(10)||
                                                       get_notification_details(to_number(l_u_deliveries(indx).source_request_id)),
                                      p_err_code    => l_err_code,
                                      p_err_message => l_err_msg);
END;
  
END LOOP;
COMMIT;  
l_prg_exe_counter := '17'; 
END IF;

l_prg_exe_counter := '18'; 
p_err_code := '0';
p_err_msg := NULL;

EXCEPTION
WHEN OTHERS THEN
p_err_code := '1';
p_err_msg := 'PROCESS MODE:'||l_error_message||' - '||' Prg Cntr :'||l_prg_exe_counter||' - '||SQLERRM;
END PROCESS_RECORDS;

--------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    main
  Author's Name:   Sandeep Akula
  Date Written:    16-MARCH-2015
  Purpose:         Checks Mail Audit Table for eligible deliveries and Calls Bursting Engine to send emails
  Program Style:   Procedure Definition
  Called From:
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  16-MARCH-2015        1.0                  Sandeep Akula     Initial Version -- CHG0034594
  ---------------------------------------------------------------------------------------------------*/
PROCEDURE main(errbuf           OUT VARCHAR2,
               retcode          OUT NUMBER,
               p_mode           IN  VARCHAR2,
               p_delivery       IN NUMBER) IS
               
l_instance_name     v$database.name%TYPE;
l_error_message     VARCHAR2(32767) := '';
l_request_id        NUMBER := fnd_global.conc_request_id;
l_prg_exe_counter   VARCHAR2(10);
UPDATE_EXCP   EXCEPTION;
PROCESS_EXCP  EXCEPTION;
l_cnt   NUMBER;
l_err_code         NUMBER;
l_err_msg          VARCHAR2(200);
l_err_code2         NUMBER;
l_err_msg2          VARCHAR2(200);
l_mail_list        VARCHAR2(1000);

BEGIN

fnd_file.put_line(fnd_file.log, 'Inside Program');

l_prg_exe_counter := '0';

  -- Deriving the Instance Name
 l_error_message := 'Instance Name could not be found';
  SELECT NAME
  INTO   l_instance_name
  FROM   v$database;

 l_prg_exe_counter := '1';
 
--*****************************************************************************************************************************************************  
IF p_mode = 'EXECUTE' THEN 

l_prg_exe_counter := '2';
PROCESS_RECORDS(l_err_code2,l_err_msg2);

IF l_err_code2 = '1' THEN
RAISE PROCESS_EXCP;
END IF;

l_prg_exe_counter := '21';

-- Updating Mail Audit Table with Bursting Request Status 
UPDATE_STATUS(l_err_code2,l_err_msg2);

l_prg_exe_counter := '40';

IF l_err_code2 = '1' THEN
RAISE UPDATE_EXCP;
END IF;

l_prg_exe_counter := '41';

--*****************************************************************************************************************************************************   
 
ELSIF p_mode = 'FORCE' THEN

l_prg_exe_counter := '42';

UPDATE xxobjt_mail_audit
SET status = 'UNPROCESSED',
    wrapper_request_id = null,
    bursting_request_id = null,
    last_updated_by = fnd_global.user_id,
    last_update_date = SYSDATE
WHERE source_code = 'XXSSUS_WSHRDPAKSM' and
       pk1 = p_delivery;
COMMIT;
                  
l_prg_exe_counter := '43';                  
PROCESS_RECORDS(l_err_code2,l_err_msg2);

IF l_err_code2 = '1' THEN
RAISE PROCESS_EXCP;
END IF;

l_prg_exe_counter := '44';

--*****************************************************************************************************************************************************   
ELSIF p_mode = 'UPDATE' THEN

l_prg_exe_counter := '45';

-- Updating Mail Audit Table with Bursting Request Status 
UPDATE_STATUS(l_err_code2,l_err_msg2);

l_prg_exe_counter := '46';

IF l_err_code2 = '1' THEN
RAISE UPDATE_EXCP;
END IF;

l_prg_exe_counter := '47';


END IF; -- Main END IF 
--*****************************************************************************************************************************************************  
l_prg_exe_counter := '999';

EXCEPTION
WHEN PROCESS_EXCP THEN
l_error_message := l_err_msg2;
retcode := '2';
errbuf := l_error_message;
/* Sending Failure Email */
l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
                                                           p_program_short_name => 'XXSSUS_WSHRDPAKSM');
xxobjt_wf_mail.send_mail_text(p_to_role     => 'SYSADMIN',
                              p_cc_mail     => l_mail_list,
                              p_subject     => 'XX: OMWSH Send Request Output To Mail Failed for Mode : EXECUTE/PROCESS',
                              p_body_text   => 'XX: OMWSH Send Request Output To Mail - Failure'||chr(10)|| 
                                               '*******  Technical Details *********'||chr(10)|| 
                                               'OM send mail Program Request Id :'||l_request_id||chr(10)||
                                               'Exception : PROCESS_EXCP'||chr(10)||
                                               'Error Message :' ||errbuf,
                                      p_err_code    => l_err_code,
                                      p_err_message => l_err_msg);
WHEN UPDATE_EXCP THEN
l_error_message := l_err_msg2;
retcode := '2';
errbuf := l_error_message;
/* Sending Failure Email */
l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
                                                           p_program_short_name => 'XXSSUS_WSHRDPAKSM');
xxobjt_wf_mail.send_mail_text(p_to_role     => 'SYSADMIN',
                              p_cc_mail     => l_mail_list,
                              p_subject     => 'XX: OMWSH Send Request Output To Mail Failed for Mode : EXECUTE/UPDATE',
                              p_body_text   => 'XX: OMWSH Send Request Output To Mail - Failure'||chr(10)|| 
                                               '*******  Technical Details *********'||chr(10)|| 
                                               'OM send mail Program Request Id :'||l_request_id||chr(10)||
                                               'Exception : UPDATE_EXCP'||chr(10)||
                                               'Error Message :' ||errbuf,
                                      p_err_code    => l_err_code,
                                      p_err_message => l_err_msg);
WHEN OTHERS THEN
l_error_message := l_error_message||' - '||' Prg Cntr :'||l_prg_exe_counter||' - '||SQLERRM;
retcode := '2';
errbuf := l_error_message;
/* Sending Failure Email */
l_mail_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
                                                           p_program_short_name => 'XXSSUS_WSHRDPAKSM');
xxobjt_wf_mail.send_mail_text(p_to_role     => 'SYSADMIN',
                              p_cc_mail     => l_mail_list,
                              p_subject     => 'XX: OMWSH Send Request Output To Mail Failed : OTHERS',
                              p_body_text   => 'XX: OMWSH Send Request Output To Mail - Failure'||chr(10)|| 
                                               '*******  Technical Details *********'||chr(10)|| 
                                               'OM send mail Program Request Id :'||l_request_id||chr(10)||
                                               'Exception : OTHERS'||chr(10)||
                                               'Error Message :' ||errbuf,
                                      p_err_code    => l_err_code,
                                      p_err_message => l_err_msg);
    
END MAIN;
END xxomwsh_send_mail_pkg;
/

