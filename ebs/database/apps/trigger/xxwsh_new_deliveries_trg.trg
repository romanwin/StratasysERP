CREATE OR REPLACE TRIGGER xxwsh_new_deliveries_trg
   ---------------------------------------------------------------------------
   -- $Header: XXAP_SUPPLIERS_BIR_TRG 120.0 2009/08/31  $
   ---------------------------------------------------------------------------
   -- Trigger: xxwsh_new_deliveries_trg
   -- Created:
   -- Author  :
   --------------------------------------------------------------------------
   -- Perpose:
   --------------------------------------------------------------------------
   -- Version  Date      Performer       Comments
   ----------  --------  --------------  -------------------------------------
   --     1.0  10.8.10   yuval tal           Initial Build
   ---------------------------------------------------------------------------
BEFORE UPDATE of status_code ON wsh_new_deliveries
  FOR EACH ROW

when (new.status_code='CL' and nvl(old.status_code,'-1')!='CL' )
DECLARE
  CURSOR c_check IS
    SELECT hp.party_name,
           xx.org_information5,
           wdd.shipped_quantity,
           wdd.item_description,
           msi.segment1,
           oha.order_number
      FROM oe_order_lines_all            ola,
           oe_order_headers_all          oha,
           wsh_delivery_assignments      wda,
           wsh_delivery_details          wdd,
           xxobjt_org_organization_def_v xx,
           mtl_system_items_b            msi,
           hz_parties                    hp,
           hz_cust_accounts              cacc
     WHERE cacc.cust_account_id = oha.sold_to_org_id
       AND cacc.party_id = hp.party_id
       AND ola.header_id = oha.header_id
       AND :OLD.delivery_id = wda.delivery_id
       AND wda.delivery_detail_id = wdd.delivery_detail_id
       AND wdd.source_line_id = ola.line_id
       AND msi.inventory_item_id = ola.inventory_item_id
       AND msi.organization_id = ola.ship_from_org_id
       AND oha.org_id = 103
       AND xx.organization_id = ola.ship_from_org_id
       AND xx.operating_unit != 103
       AND wdd.container_flag = 'N';

  l_body    VARCHAR2(32000);
  l_subject VARCHAR2(150);
  l_ind     NUMBER(1) := 0;
BEGIN
  IF fnd_profile.VALUE('XXOM_STOCK_ALERT_ENABLE') = 'Y' THEN
    FOR i IN c_check LOOP
      IF c_check%ROWCOUNT = 1 THEN
        l_ind     := 1;
        l_subject := 'The following stock was sent directly from ' ||
                     i.org_information5 || ' to Customer : ' ||
                     i.party_name;
        l_body    := '<p>Hello,</p>' || --'<p> <br> </p>'
                     '<p>The following stock was sent directly from ' ||
                     i.org_information5 || ' to Customer : ' ||
                     i.party_name || -- '<p> <br> </p>' ||
                     '<p>Delivery : ' || :OLD.NAME || ' </p>' ||
                     '<TABLE cellpadding="5"  style="color:blue" BORDER =1 > ' ||
                     '<TR><TH>Item</TH> <TH>Item Description</TH><TH>Quantity</TH><TH>Initial Pick up date</TH><TH>Order no</TH></TR>';
      
      END IF;
    
      l_body := l_body || '<TR><TD>' || i.segment1 || '</TD> <TD>' ||
                i.item_description || '</TD><TD>' || i.shipped_quantity ||
                '</TD><TD>' || :OLD.initial_pickup_date || '</TD><TD>' ||
                i.order_number || '</TD></TR>';
    
    END LOOP;
  
    IF l_ind = 1 THEN
      l_body := l_body || '</table><p>Good day,</p>' || '<p>Oracle sys</p>';
    
      xxfnd_smtp_utilities.send_mail(p_recipient => fnd_profile.VALUE('XXOM_STOCK_ALERT_MAIL'),
                                     p_subject   => l_subject,
                                     p_body      => l_body,
                                     p_from_name => NULL);
    
    END IF;
  
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    NULL;
  
END xxwsh_delivery_details_trg;
/

