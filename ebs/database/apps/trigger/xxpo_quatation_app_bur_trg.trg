CREATE OR REPLACE TRIGGER XXPO_QUATATION_APP_BUR_TRG

---------------------------------------------------------------------------
-- Trigger   :        XXPO_QUATATION_APPROVED_BUR_TRG
-- Created by:        Dalit A. Raviv
-- creation date:     17/12/2009
-- Revision:          1.0
---------------------------------------------------------------------------
-- Perpose:           Send mail to buyer when quatation is approved
--                    will change alert - XXPUR_QUOTATION_APPROVED_BUYERS
---------------------------------------------------------------------------
--  ver    date        name            desc
--  1.0   17/12/2009  Dalit A. Raviv  Initial Build
---------------------------------------------------------------------------
  BEFORE UPDATE ON po_headers_all  
  FOR EACH ROW
  
when (NEW.status_lookup_code = 'A' AND (NEW.status_lookup_code <> OLD.status_lookup_code)
        AND NEW.type_lookup_code = 'QUOTATION' )
DECLARE
  l_to_person   VARCHAR2(100) := NULL;
  l_sender_name VARCHAR2(240) := 'OracleApps_NoReply@objet.com';
  l_buyer_name  VARCHAR2(240) := NULL;
  l_html_str    VARCHAR2(500) := NULL;
  l_req_id      NUMBER        := NULL;
  l_result      BOOLEAN;
  l_vendor_name VARCHAR2(240) := NULL;
BEGIN
  IF nvl(fnd_profile.VALUE('XXPO_QUOTATION_APPROVAL_SEND_MAIL'), 'N') = 'Y' THEN
    BEGIN
      SELECT pba.email_address, pba.full_name
      INTO   l_to_person,       l_buyer_name
      FROM   po_buyers_all_v    pba
      WHERE  pba.employee_id    = :NEW.agent_id ;     
    EXCEPTION
      WHEN OTHERS THEN
        l_to_person := NULL;
    END;
    
    IF l_to_person IS NOT NULL THEN
     
      BEGIN
        SELECT pv.vendor_name 
        INTO   l_vendor_name
        FROM   po_vendors pv
        WHERE  vendor_id  = :NEW.vendor_id;
      EXCEPTION
        WHEN OTHERS THEN
          l_vendor_name := NULL;
      END ;
      
      --'<p>The following quotation Approved today: </p>' || :NEW.segment1 || '<p> <br> </p>' ||             
      l_html_str := '<p>Dear '||l_buyer_name||'</p>' || 
                    '<p>Quotation: ' || :NEW.segment1 ||' Was approved Today ' || 
                    '<p>Supplier:  ' || l_vendor_name || --'<p> <br> </p>' ||
                    '<p>Good day,  ' || --'<p> <br> </p>' || 
                    '<p>Oracle sys  ' ;
       
      l_result := FND_REQUEST.SET_MODE(TRUE);
      IF l_result THEN
        l_req_id := fnd_request.submit_request( application   => 'XXOBJT', 
                                                program       => 'XXOBJT_SEND_MAIL', 
                                                description   => NULL, 
                                                start_time    => NULL,
                                                sub_request   => FALSE,
                                                argument1     => l_sender_name, -- i v p_sender_name
                                                argument2     => l_to_person,   -- i v p_recipient
                                                argument3     => 'Quotations Approval Notification',-- i v p_subject
                                                argument4     => l_html_str );  -- i v p_body
          
      END IF;                                       
      /*xxfnd_smtp_utilities.conc_send_mail(p_sender_name IN VARCHAR2,
                                          p_recipient   IN VARCHAR2,
                                          p_subject     IN VARCHAR2,
                                          p_body        IN VARCHAR2)*/
    ELSE
      -- send mail to someone to notify
      -- ??????????????????????????????
      NULL;
    END IF; -- l_person_id 
  END IF; -- Profile 
  
END xxpo_quatation_app_trg;
/

