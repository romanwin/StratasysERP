CREATE OR REPLACE TRIGGER xxoe_order_headers_all_2_trg
AFTER UPDATE of attribute18  ON oe_order_headers_all
  FOR EACH ROW

when  (new.attribute18 is null  and  nvl(old.attribute18 ,'-1') = 'Political')
   
DECLARE
  ---------------------------------------------------------------------------
  -- $Header: XXAP_SUPPLIERS_BIR_TRG 
  ---------------------------------------------------------------------------
  -- Trigger: oe_order_headers_all_2_trg
  -- Created: yuval tal
  -- Author  :
  --------------------------------------------------------------------------
  -- Perpose:
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  29.03.12   yuval tal       Initial Build - cr 399 cust 361 
  --                                     send alert for cancell/unmark political in dff

  ---------------------------------------------------------------------------
  l_subject VARCHAR2(300);
  l_to      VARCHAR2(500);
  l_cc      VARCHAR2(500);
  l_bcc     VARCHAR2(500);
  l_ind     NUMBER(1) := 0;
  l_body    VARCHAR2(4000);

  CURSOR c_ord_lines IS
    SELECT hp.party_name AS customer_name,
           --oh.order_number,
           ol.line_number,
           ol.ordered_item,
           msib.segment1,
           msib.description      item_description,
           ol.order_quantity_uom,
           ol.ordered_quantity
      FROM oe_order_lines_all ol,
           mtl_system_items_b msib,
           hz_cust_accounts   hca,
           hz_parties         hp
     WHERE ol.header_id = :new.header_id
       AND msib.inventory_item_id = ol.ordered_item_id
       AND msib.organization_id = 91
       AND hp.party_id = hca.party_id
       AND hca.cust_account_id = :new.sold_to_org_id
       AND ol.cancelled_flag = 'N'
       AND msib.shippable_item_flag = 'Y'
     ORDER BY ol.line_number;
  l_err_code    NUMBER;
  l_err_message VARCHAR2(2000);
  l_tmp         NUMBER;

  CURSOR c_check_line_status(c_header_id NUMBER) IS
    SELECT 1
      FROM oe_order_lines_all t, mtl_system_items_b msib
     WHERE t.header_id = c_header_id
       AND t.flow_status_code IN ('BOOKED', 'AWAITING_SHIPPING')
       AND msib.inventory_item_id = t.ordered_item_id
       AND msib.organization_id = 91
       AND msib.shippable_item_flag = 'Y';

BEGIN

  -- attribute change 
  -- check if still political

  IF :new.attribute18 IS NULL AND nvl(:old.attribute18, '-1') = 'Political' AND
     xxwsh_political.is_so_hdr_political(:new.attribute18,
                                         :new.ship_to_org_id,
                                         :new.order_type_id) = 0 THEN
    -- check line_status in case of attribute change
    -- check not all order lines are  closed
    OPEN c_check_line_status(:new.header_id);
    FETCH c_check_line_status
      INTO l_tmp;
    CLOSE c_check_line_status;
  
    IF nvl(l_tmp, 0) = 1 THEN
    
      -- get dist list
      SELECT REPLACE(t.to_recipients, ' ', ';'),
             REPLACE(t.cc_recipients, ' ', ';'),
             REPLACE(t.bcc_recipients, ' ', ';')
        INTO l_to, l_cc, l_bcc
        FROM alr_distribution_lists t
       WHERE t.name = 'XXWSH_POLITICAL_SHIPMENT';
    
      --
      fnd_message.set_name('XXOBJT', 'XXWSH_POLITICAL_SUBJECT_CANCEL');
      fnd_message.set_token('ORDER_NUMBER', :new.order_number);
      fnd_message.set_token('P_MESSAGE', 'unmark as Political');
      l_subject := fnd_message.get;
    
      FOR i IN c_ord_lines LOOP
        IF c_ord_lines%ROWCOUNT = 1 THEN
          l_ind := 1;
        
          l_body := '<HTML><head>
                   <style type="text/css">
                      h3 {color:red;}</style></head>
                         <p>Hello,</p>' ||
                    '<p><h3>The following Political Sales order  ' ||
                    :new.order_number ||
                    ' has been unmark as Political. </h3>' ||
                    '<p>Customer Name : ' || i.customer_name || ' </p>' ||
                    '<TABLE cellpadding="5"  style="color:blue" BORDER =1 > ' ||
                    '<TR><TH>Line number</TH> <TH>Item</TH><TH>Item Description</TH><TH>UOM</TH><TH>Quantity</TH></TR>';
        
        END IF;
      
        l_body := l_body || '<TR><TD>' || i.line_number || '</TD> <TD>' ||
                  i.segment1 || '</TD><TD>' || i.item_description ||
                  '</TD><TD>' || i.order_quantity_uom || '</TD><TD>' ||
                  i.ordered_quantity || '</TD></TR>';
      
      END LOOP;
    
      IF l_ind = 1 THEN
      
        l_body := l_body || '</table>
     ' || /* fnd_message.get ||*/
                  '<p>Good day,</p>' || '<p>Oracle system</p></HTML>';
      
        xxobjt_wf_mail.send_mail_html(p_to_role     => fnd_profile.value('XXWSH_POLITICAL_USER_ADMIN'), --'ORACLE_OPERATION',
                                      p_cc_mail     => l_to,
                                      p_bcc_mail    => l_cc || ';' || l_bcc,
                                      p_subject     => l_subject,
                                      p_body_html   => l_body,
                                      p_err_code    => l_err_code,
                                      p_err_message => l_err_message);
      END IF;
    END IF;
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    NULL;
END;
/
