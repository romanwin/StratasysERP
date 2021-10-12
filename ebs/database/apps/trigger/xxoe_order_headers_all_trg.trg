CREATE OR REPLACE TRIGGER xxoe_order_headers_all_trg
AFTER UPDATE of flow_status_code   ON OE_ORDER_HEADERS_ALL
  FOR EACH ROW


when (new.flow_status_code = 'BOOKED' and nvl(old.flow_status_code ,'-1') != 'BOOKED'
    OR ( OLD.flow_status_code!='CANCELLED' AND  new.flow_status_code='CANCELLED') )
DECLARE

  --------------------------------------------------------------------
  --  name:              XXOE_ORDER_HEADERS_ALL_TRG
  --  create by:         yuval tal
  --  Revision:          1.0
  --  creation date:     02.01.11
  --------------------------------------------------------------------
  --  purpose :
  --------------------------------------------------------------------
  --  ver  date         name           desc
  --  1.0  02.01.11     yuval tal      Initial Build - when booked check political,
  --                                   if yes send political alert
  --  1.1  6.4.11       yuval tal      add param to is political
  --  1.2  14.2.12      yuval tal      modify :  FND_PROFILE.VALUE('XXWSH_POLITICAL_USER_ADMIN')  from SYSADMIN
  --  1.3  01.4.12      yuval tal      cr 399 cust 361 send alert for cancel political order
  --  1.4  19.12.13     yuval tal      cust 316 cr 1206 exclude FDM items
  --  1.5  30/09/2014   Ginat B.       CHG0033137 change logic for PDM items
  --  1.6  12/07/2015   Michal Tzvik   CHG0035224 change logic for PDM items: use xxwsh_political.is_item_political
  --------------------------------------------------------------------
  l_subject VARCHAR2(250);
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
    FROM   oe_order_lines_all ol,
           mtl_system_items_b msib,
           hz_cust_accounts   hca,
           hz_parties         hp
    WHERE  ol.header_id = :new.header_id
    AND    msib.inventory_item_id = ol.ordered_item_id
    AND    msib.organization_id = 91
    AND    hp.party_id = hca.party_id
    AND    hca.cust_account_id = :new.sold_to_org_id
    AND    ol.cancelled_flag = 'N'
    AND    msib.shippable_item_flag = 'Y'
          --  1.5  30/09/2014   Ginat B.
          --AND xxinv_utils_pkg.is_fdm_item(ol.inventory_item_id) = 'N'          
          /*AND (xxinv_item_classification.is_item_polyjet(ol.inventory_item_id) = 'Y'
          OR xxinv_utils_pkg.get_item_category(ol.inventory_item_id,1100000221) is null)*/
    AND    xxwsh_political.is_item_political(ol.inventory_item_id) = 'Y' -- 1.6 12/07/2015 Michal Tzvik
    -- end 1.5
    ORDER  BY ol.line_number;

  CURSOR c_cancel_ord_lines IS
    SELECT hp.party_name AS customer_name,
           --oh.order_number,
           ol.line_number,
           ol.ordered_item,
           msib.segment1,
           msib.description      item_description,
           ol.order_quantity_uom,
           ol.ordered_quantity
    FROM   oe_order_lines_all ol,
           mtl_system_items_b msib,
           hz_cust_accounts   hca,
           hz_parties         hp
    WHERE  ol.header_id = :new.header_id
    AND    msib.inventory_item_id = ol.ordered_item_id
    AND    msib.organization_id = 91
    AND    hp.party_id = hca.party_id
    AND    hca.cust_account_id = :new.sold_to_org_id
    AND    (ol.cancelled_flag = 'N' OR :new.flow_status_code = 'CANCELLED')
    AND    msib.shippable_item_flag = 'Y'
          --  1.5  30/09/2014   Ginat B.
          --AND xxinv_utils_pkg.is_fdm_item(ol.inventory_item_id) = 'N'          
          /* AND (xxinv_item_classification.is_item_polyjet(ol.inventory_item_id) = 'Y'
          OR xxinv_utils_pkg.get_item_category(ol.inventory_item_id,1100000221) is null)*/
    AND    xxwsh_political.is_item_political(ol.inventory_item_id) = 'Y' -- 1.6 12/07/2015 Michal Tzvik
    -- end 1.5
    ORDER  BY ol.line_number;

  l_err_code    NUMBER;
  l_err_message VARCHAR2(2000);
BEGIN

  -- book
  IF (:new.flow_status_code = 'BOOKED' AND
     nvl(:old.flow_status_code, '-1') != 'BOOKED') THEN
    IF xxwsh_political.is_so_hdr_political(:new.attribute18, :new.ship_to_org_id, :new.order_type_id) = 1 THEN
    
      -- get dist list
      SELECT REPLACE(t.to_recipients, ' ', ';'),
             REPLACE(t.cc_recipients, ' ', ';'),
             REPLACE(t.bcc_recipients, ' ', ';')
      INTO   l_to,
             l_cc,
             l_bcc
      FROM   alr_distribution_lists t
      WHERE  t.name = 'XXWSH_POLITICAL_SHIPMENT';
    
      --
      fnd_message.set_name('XXOBJT', 'XXWSH_POLITICAL_ALERT_SUBJECT');
      fnd_message.set_token('ORDER_NUMBER', :new.order_number);
      l_subject := fnd_message.get;
    
      FOR i IN c_ord_lines LOOP
        IF c_ord_lines%ROWCOUNT = 1 THEN
          l_ind := 1;
        
          l_body := '<HTML><p>Hello,</p>' || --'<p> <br> </p>'
                    '<p>The following Sales order  ' || :new.order_number ||
                    ' has been booked. ' || -- '<p> <br> </p>' ||
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
        fnd_message.set_name('XXOBJT', 'XXWSH_POLITICAL_ALERT_LINK');
      
        l_body := l_body || '</table>' || fnd_message.get ||
                  '<p>Good day,</p>' || '<p>Oracle system</p></HTML>';
      
        xxobjt_wf_mail.send_mail_html(p_to_role => fnd_profile.value('XXWSH_POLITICAL_USER_ADMIN'), --'ORACLE_OPERATION',
                                      p_cc_mail => l_to, p_bcc_mail => l_cc || ';' ||
                                                     l_bcc, p_subject => l_subject, p_body_html => l_body, p_err_code => l_err_code, p_err_message => l_err_message);
      END IF;
    END IF;
  END IF;

  -- cancel order
  IF nvl(:old.flow_status_code, 'x') != 'CANCELLED' AND
     :new.flow_status_code = 'CANCELLED' AND
     xxwsh_political.is_so_hdr_political(:new.attribute18, :new.ship_to_org_id, :new.order_type_id) = 1 THEN
  
    -- get dist list
    SELECT REPLACE(t.to_recipients, ' ', ';'),
           REPLACE(t.cc_recipients, ' ', ';'),
           REPLACE(t.bcc_recipients, ' ', ';')
    INTO   l_to,
           l_cc,
           l_bcc
    FROM   alr_distribution_lists t
    WHERE  t.name = 'XXWSH_POLITICAL_SHIPMENT';
    --
    fnd_message.set_name('XXOBJT', 'XXWSH_POLITICAL_SUBJECT_CANCEL');
    fnd_message.set_token('ORDER_NUMBER', :new.order_number);
    fnd_message.set_token('P_MESSAGE', 'cancelled');
    l_subject := fnd_message.get;
  
    FOR i IN c_cancel_ord_lines LOOP
      IF c_cancel_ord_lines%ROWCOUNT = 1 THEN
        l_ind := 1;
      
        l_body := '<HTML><head><style type="text/css">h3 {color:red;}</style></head>' ||
                  '<p>Hello,</p>' ||
                  '<p><h3>The following Political Sales order  ' ||
                  :new.order_number || ' has been cancelled. </h3>' ||
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
    
      xxobjt_wf_mail.send_mail_html(p_to_role => fnd_profile.value('XXWSH_POLITICAL_USER_ADMIN'), --'ORACLE_OPERATION',
                                    p_cc_mail => l_to, p_bcc_mail => l_cc || ';' ||
                                                   l_bcc, p_subject => l_subject, p_body_html => l_body, p_err_code => l_err_code, p_err_message => l_err_message);
    END IF;
  END IF;

EXCEPTION
  WHEN OTHERS THEN
    NULL;
END;
/
