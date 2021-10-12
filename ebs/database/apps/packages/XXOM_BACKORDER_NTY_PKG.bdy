CREATE OR REPLACE PACKAGE BODY XXOM_BACKORDER_NTY_PKG is
----------------------------------------------------------
  -- Author  : PIYALI.BHOWMICK
  -- Created : 09/11/2017 12:45:36
  -- Purpose :To send notification to the order creator in case of 
  --          backorder.   
  -- ---------------------------------------------------------
  --------------------------------------------------------------------------
  -- Version  Date      Performer             Comments
  ----------  --------  --------------       -------------------------------------
  --
  --   1.1    9.11.2017     Piyali Bhowmick     CHG0041696 - Initial Build 
  ------------------------------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:            process_events
  --  create by:       Piyali Bhowmick
  --  Revision:        1.0
  --  creation date:   09/11/2017 12:45:36
  --------------------------------------------------------------------
  --  purpose : To update the staging table xxssys_events and send notification to 
  --            order creator in case of back ordered lines. 
  --------------------------------------------------------------------
  --   1.0    07.8.2017    Piyali Bhowmick      CHG0041696 -To update the staging table xxssys_events and send notification to 
  --                                           order creator in case of back ordered lines.  
  --   1.1    15.5.2018     Bellona(TCS)        CHG0043011- Backorders notification - additional requirement - In case email_id 
  --										   is absent for the order creator, For example for the user: ECCOMERCE, mail 
  --										   Notification will be sent out to SYSADMIN.
  ------------------------------------------------------------------------------------------

  PROCEDURE process_events(l_retcode OUT  VARCHAR2, 
                          l_errbuf  OUT VARCHAR2) IS
  
    -- cursor 
    CURSOR c_backorder_events IS  
        SELECT entity_id AS  header_id,
        event_id
        FROM   xxssys_events
        WHERE  status = 'NEW'
        AND    target_name = 'BACKORDER_NTY'
        AND    entity_name = 'DELIVERY';
        
 
    l_user_name VARCHAR2(100); 
   
    l_end_date  DATE ;
    l_order_number number;
	l_org_id	NUMBER;
	l_cc_mail  VARCHAR2(100);
	
	l_email    fnd_user.email_address%type;		--CHG0043011
      
  BEGIN
   
  l_retcode := 0;
  l_errbuf  := null;
    -- loop over back order  events  
    FOR i IN c_backorder_events LOOP 
      begin
      
          UPDATE xxssys_events
          SET    status  = 'IN_PROCESS'
          WHERE  event_id = i.event_id 
          AND    target_name = 'BACKORDER_NTY ';
          
          COMMIT;
  
         fnd_file.put_line(fnd_file.log,'Updating the XXSSYS_EVENT
          table to IN_PROCESS for entity_id '|| i.header_id );
		  
	  -- CHG0043011 - derive additional field email_address of the order_creator
      select fu.user_name , fu.end_date  , ooha.order_number, ooha.org_id, fu.email_address
      into  l_user_name ,l_end_date   ,l_order_number, l_org_id, l_email
      from oe_order_headers_all ooha ,fnd_user  fu 
      where fu.user_id =ooha.created_by
      and   ooha.header_id = i.header_id ;
          
      
         fnd_file.put_line(fnd_file.log,'User Name '|| l_user_name );
                  
         l_cc_mail := fnd_profile.value_specific( name   =>'XXOM_BACKORDER_NTY'
												 ,org_id => l_org_id);
    
      --Check whether the user is inactive send mail to SYS ADMIN 
      --Check whether the user has email_id, if not, send mail to SYS ADMIN	-- CHG0043011
 
        if (l_end_date is not NULL and l_end_date < sysdate) or l_email is null then  -- CHG0043011
		
         xxobjt_wf_mail.send_mail_body_proc(p_to_role     => 'SYSADMIN',
								p_cc_mail	  => l_cc_mail,
                                p_subject     =>'Backorder Notification for order'||l_order_number,
                                p_body_proc   => 'xxom_backorder_nty_pkg.backorder_details/'||i.header_id ,
                                p_err_code    => l_retcode,
                                p_err_message => l_errbuf);		
                
       else  
         xxobjt_wf_mail.send_mail_body_proc(p_to_role     => l_user_name,
								p_cc_mail	  => l_cc_mail,
                                p_subject     =>'Backorder Notification for order '||l_order_number,
                                p_body_proc   => 'xxom_backorder_nty_pkg.backorder_details/'||i.header_id ,
                                p_err_code    => l_retcode,
                                p_err_message => l_errbuf);
                               

        end if; 
             
      
      
      
          if l_retcode =0 then
            xxssys_event_pkg.update_success(i.event_id);
            
          else
            xxssys_event_pkg.update_error(i.event_id,'Unable to send mail'||l_errbuf);
            
          end if;
            COMMIT;
        exception
        when others then
           xxssys_event_pkg.update_error(i.event_id,SQLERRM); 
      end; 
    END LOOP;
    
        
  END process_events;
    --------------------------------------------------------------------
  --  name:             backorder_details
  --  create by:       Piyali Bhowmick
  --  Revision:        1.0
  --  creation date:   09/11/2017 12:45:36
  --------------------------------------------------------------------
  --  purpose :   To get the order details as well as the line details of 
  --              those lines which are backordered 
  --------------------------------------------------------------------
  --   1.0    7.8.2017    Piyali Bhowmick      CHG0041696 -   To get the order details as well as the line details of 
  --                                                  those lines which are backordered 
  ------------------------------------------------------------------------------------------

  PROCEDURE backorder_details(document_id   IN VARCHAR2,
                             display_type  IN VARCHAR2,
                             document      IN OUT CLOB,
                             document_type IN OUT VARCHAR2)IS
                                
                                

  l_doc         CLOB;

   cursor c_backorder_lines( l_header_id NUMBER) IS
 
                  SELECT 
                      ol.line_id,
                      rtrim(line_number ||
                      '.' || shipment_number ||
                      '.' || option_number ||
                      '.' || component_number ||
                      '.' || service_number,'.')                                               line_number, 
                   
                      nvl(CUST_ITEMS_TAB_Replace.Customer_Item_Number, msi.segment1)           segment1,
                      (DECODE( (xxoe_utils_pkg.is_item_resin_credit(msi.inventory_item_id)) , 
                               'Y',(xxoe_utils_pkg.get_resin_credit_description(ol.line_id)),
                               nvl(ol.user_item_description,
                                    xxinv_utils_pkg.get_item_desc_tl(msi.inventory_item_id,
                                                                     ol.ship_from_org_id,
                                                                     fnd_global.org_id)  
                                   )
                             )) description,
                      decode(line_category_code, 'RETURN', -1, 1) * ol.ordered_quantity  qty ,
                      trunc(ol.schedule_ship_date)  estimated_ship_date
                      

              from    oe_order_headers_all                       h,
                      oe_order_lines_all                         ol,
                 
                      mtl_system_items_b                         msi,
                      wsh_delivery_assignments                   wda,
                      wsh_delivery_details                        wdd,
                  

                      (select  mci.customer_id sold_to_org_id,
                               mcc.attribute1,
                               mcix.inventory_item_id,
                               mci.customer_item_number
                       from    mtl_customer_items                mci,
                               mtl_customer_item_xrefs           mcix,
                               mtl_commodity_codes               mcc,
                               mtl_system_items_b                msi
                       where   mci.customer_item_id              = mcix.customer_item_id
                       and     mcix.inactive_flag                = 'N'
                       and     msi.inventory_item_id             = mcix.inventory_item_id
                       and     msi.organization_id               = mcix.master_organization_id
                       and     mci.commodity_code_id             = mcc.commodity_code_id
                       and     mcc.attribute1                    = 'Y')                        CUST_ITEMS_TAB_Replace
              where   h.header_id                                = ol.header_id
              and     ol.inventory_item_id                       = msi.inventory_item_id
              and     ol.ship_from_org_id                        = msi.organization_id
              and     ol.cancelled_flag                          <> 'Y'
              and     msi.item_type                              <> fnd_profile.value('XXAR PREPAYMENT ITEM TYPES')
              and     ol.sold_to_org_id                          = cust_items_tab_replace.sold_to_org_id(+)
              and     ol.inventory_item_id                       = cust_items_tab_replace.inventory_item_id(+)
              and     xxoe_utils_pkg.show_dis_get_line(ol.line_id) = 'Y' 
              and     xxoe_utils_pkg.om_print_config_option(ol.line_id) = 'N'
              and    h.header_id = l_header_id --1104059
              and   wdd.SOURCE_HEADER_ID=h.HEADER_ID
              AND   wdd.source_line_id = ol.line_id
              AND wdd.delivery_detail_id = wda.delivery_detail_id
              and wdd.released_status= 'B'
              order by ol.line_number,
                       ol.shipment_number,
                       nvl(ol.option_number, -1),
                       nvl(ol.component_number, -1),
                       nvl(ol.service_number, -1);
  -- Test statements here
  cursor c_backorder_header( p_header_id NUMBER) IS
        select  
                h.order_number                              so_number,
                h.cust_po_number                          po_number,
                (select fu.user_name from fnd_user fu 
                where fu.user_id=h.created_by)            order_creator,
                to_char(h.creation_date, 'DD-MON-YYYY')   order_date ,
                sold_acct.attribute1                    vendor_no ,
                xxinv_utils_pkg.get_lookup_meaning('FREIGHT_TERMS',
                                                   h.freight_terms_code) freight_terms_code, -- ship by
                cust_acct.account_number        customer_number ,
                ot.name                          order_type   ,
          
                Xxar_utils_pkg.get_term_name_tl (term.term_id,fnd_global.org_id) terms ,
                --  ship_to,
                substr(xxHz_util.get_party_name_tl(ship_hp.party_id,fnd_global.org_id), 1, 150)  ship_to ,
                ship_loc.address1||decode(ship_loc.address2, NULL, NULL, chr(10))||
                                   ship_loc.address2  ship_to_address1    ,
                ship_loc.address1             ship_to_address1_orig  ,
                ship_loc.address2             ship_to_address2 ,
                ship_loc.city                  ship_to_city  ,
                ship_loc.postal_code           ship_to_postal_code ,
                ship_states_tab.meaning        ship_to_state ,
                ship_loc_ter.territory_short_name   ship_to_country ,
                --  Bill invoice_to,
                substr(xxHz_util.get_party_name_tl ( bill_hp.party_id,fnd_global.org_id), 1, 150) invoice_to,
                bill_loc.address1                invoice_to_address1  ,
                bill_loc.address2                invoice_to_address2  ,
                bill_loc.postal_code             invoice_to_postal_code ,
                bill_states_tab.meaning           invoice_to_state  ,
                bill_loc_ter.territory_short_name  invoice_to_country  ,
               bill_loc.city                        invoice_to_city ,
                ship_party_profiles.person_name      ship_to_contact ,
                xxhz_util.get_fax(ship_rel.party_id)  ship_to_contact_fax ,    
             --   ship_rel.party_id,   
                xxhz_util.get_phone(ship_rel.party_id)  ship_to_contact_phone,    
                invoice_party_profiles.person_name      invoice_to_contact  ,
                xxhz_util.get_fax(invoice_rel.party_id)  invoice_to_contact_fax ,   
                xxhz_util.get_phone(invoice_rel.party_id) invoice_to_contact_phone,
                decode (xxhz_util.get_ou_lang(fnd_global.org_id),'JA',salesrep_tab.alt_name ,salesrep_tab.name) salesrep_name ,
                fob_tab.meaning fob,
                fl.meaning   freight_carrier_code  
               
        FROM    mtl_parameters                           ship_from_org,
                hz_cust_site_uses_all                    ship_su,
                hz_party_sites                           ship_ps,
                hz_parties                               ship_hp,
                hz_locations                             ship_loc,
                fnd_territories_vl                       ship_loc_ter,
                hz_cust_acct_sites_all                   ship_cas,
                hz_cust_site_uses_all                    bill_su,
                hz_party_sites                           bill_ps,
                hz_parties                               bill_hp,
                hz_locations                             bill_loc,
                fnd_territories_vl                       bill_loc_ter,
                hz_cust_acct_sites_all                   bill_cas,
                hz_parties                               party,
                hz_cust_accounts                         cust_acct,
                ra_terms_tl                              term,
                oe_order_headers_all                     h,
                oe_order_sources                         os,
                hz_cust_account_roles                    sold_roles,
                hz_parties                               sold_party,
                hz_cust_accounts                         sold_acct,
                hz_relationships                         sold_rel,
                ar_lookups                               sold_arl,
                hz_cust_account_roles                    ship_roles,
                hz_parties                               ship_party,
                (SELECT pp.party_id, pp.person_name
                 FROM   hz_person_profiles pp
                 WHERE  SYSDATE BETWEEN pp.effective_start_date 
                        AND nvl(pp.effective_end_date, SYSDATE + 1)) ship_party_profiles,
                hz_relationships                         ship_rel,
                hz_cust_accounts                         ship_acct,
                ar_lookups                               ship_arl,
                hz_cust_account_roles                    invoice_roles,
                hz_parties                               invoice_party,
                (SELECT pp.party_id, pp.person_name
                 FROM   hz_person_profiles pp
                 WHERE  SYSDATE BETWEEN pp.effective_start_date 
                        AND nvl(pp.effective_end_date, SYSDATE + 1)) invoice_party_profiles,
                hz_relationships                         invoice_rel,
                hz_cust_accounts                         invoice_acct, ---bill to
                ar_lookups                               invoice_arl,
                fnd_currencies                           fndcur,
                oe_transaction_types_tl                  ot,
                qp_list_headers_tl                       pl,
                ra_rules                                 invrule,
                ra_rules                                 accrule,
                (select ppf.attribute1||' '||ppf.attribute2 alt_name, s.person_id,s.salesrep_id, r.source_name name
                  from jtf_rs_salesreps s, jtf_rs_resource_extns r,per_all_people_f ppf
                 where s.resource_id = r.resource_id
                 and   ppf.person_id(+) = s.person_id         
                 and  trunc(sysdate) between ppf.effective_start_date(+) and nvl(ppf.effective_end_date(+),sysdate+1) ) salesrep_tab,
                (select v.lookup_code, v.meaning
                 from   fnd_lookup_values v
                 where  v.lookup_type LIKE 'PN_STATE'
                 and    v.language = 'US')               ship_states_tab,
                (select v.lookup_code, v.meaning
                 from   fnd_lookup_values v
                 where  v.lookup_type LIKE 'PN_STATE'
                 and    v.LANGUAGE = 'US')               bill_states_tab,
                (select v.lookup_code, v.meaning
                 from   fnd_lookup_values v
                 where  v.lookup_type = 'FOB'
                 and    v.language = 'US')               fob_tab,
                fnd_lookup_values_vl                     fl
        where   fl.lookup_type(+)                        = 'SHIP_METHOD'
        and     fl.lookup_code(+)                        = h.shipping_method_code
        and     h.header_id                              = p_header_id--1104059
        and     h.order_type_id                          = ot.transaction_type_id
        and     ot.language                              = userenv('LANG')
        and     h.price_list_id                          = pl.list_header_id(+)
        and     pl.language(+)                           = userenv('LANG')
        and     h.invoicing_rule_id                      = invrule.rule_id(+)
        and     h.accounting_rule_id                     = accrule.rule_id(+)
        and     h.payment_term_id                        = term.term_id(+)
        and     term.language(+)                         = userenv('LANG')
        and     h.transactional_curr_code                = fndcur.currency_code
        and     h.sold_to_org_id                         = cust_acct.cust_account_id(+)
        and     cust_acct.party_id                       = party.party_id(+)
        and     h.ship_from_org_id                       = ship_from_org.organization_id(+)
        and     h.ship_to_org_id                         = ship_su.site_use_id(+)
        and     ship_su.cust_acct_site_id                = ship_cas.cust_acct_site_id(+)
        and     ship_cas.party_site_id                   = ship_ps.party_site_id(+)
        and     ship_loc.location_id(+)                  = ship_ps.location_id
        and     h.invoice_to_org_id                      = bill_su.site_use_id(+)
        and     bill_su.cust_acct_site_id                = bill_cas.cust_acct_site_id(+)
        and     bill_cas.party_site_id                   = bill_ps.party_site_id(+)
        and     bill_loc.location_id(+)                  = bill_ps.location_id
        and     h.sold_to_contact_id                     = sold_roles.cust_account_role_id(+)
        and     sold_roles.party_id                      = sold_rel.party_id(+)
        and     sold_roles.role_type(+)                  = 'CONTACT'
        and     sold_roles.cust_account_id               = sold_acct.cust_account_id(+)
        and     nvl(sold_rel.object_id, -1)              = nvl(sold_acct.party_id, -1)
        and     sold_rel.subject_id                      = sold_party.party_id(+)
        and     sold_arl.lookup_type(+)                  = 'CONTACT_TITLE'
        and     sold_arl.lookup_code(+)                  = sold_party.person_pre_name_adjunct
        and     h.ship_to_contact_id                     = ship_roles.cust_account_role_id(+)
        and     ship_roles.party_id                      = ship_rel.party_id(+)
        and     ship_roles.role_type(+)                  = 'CONTACT'
        and     ship_roles.cust_account_id               = ship_acct.cust_account_id(+)
        and     nvl(ship_rel.object_id, -1)              = nvl(ship_acct.party_id, -1)
        and     ship_rel.subject_id                      = ship_party.party_id(+)
        and     ship_arl.lookup_type(+)                  = 'CONTACT_TITLE'
        and     ship_arl.lookup_code(+)                  = ship_party.person_pre_name_adjunct
        and     h.invoice_to_contact_id                  = invoice_roles.cust_account_role_id(+)
        and     invoice_roles.party_id                   = invoice_rel.party_id(+)
        and     invoice_roles.role_type(+)               = 'CONTACT'
        and     invoice_roles.cust_account_id            = invoice_acct.cust_account_id(+)
        and     nvl(invoice_rel.object_id, -1)           = nvl(invoice_acct.party_id, -1)
        and     invoice_rel.subject_id                   = invoice_party.party_id(+)
        and     invoice_arl.lookup_type(+)               = 'CONTACT_TITLE'
        and     invoice_arl.lookup_code(+)               = invoice_party.person_pre_name_adjunct
        and     h.salesrep_id                            = salesrep_tab.salesrep_id(+)
        and     invoice_party.party_id                   = invoice_party_profiles.party_id(+)
        and     ship_ps.party_id                         = ship_hp.party_id(+)
        and     bill_ps.party_id                         = bill_hp.party_id(+)
        and     ship_party.party_id                      = ship_party_profiles.party_id(+)
        and     bill_loc.country                         = bill_loc_ter.territory_code(+)
        and     ship_loc.country                         = ship_loc_ter.territory_code(+)
        and     ship_loc.state                           = ship_states_tab.lookup_code(+)
        and     bill_loc.state                           = bill_states_tab.lookup_code(+)
        and     h.fob_point_code                         = fob_tab.lookup_code(+)
        and     h.order_source_id                        = os.order_source_id(+);


begin 
 for i in c_backorder_lines(TO_NUMBER(document_id)) loop
 
  l_doc := l_doc||
        '<tr>
            
              <td>'
                ||i.line_number||
              '</td>
              <td>'
                 ||i.segment1||
              '</td>
              <td>'
                 ||i.description||
              '</td>
              <td>'
                 ||i.qty||
              '</td>
              <td>'
                 ||i.estimated_ship_date ||
              '</td>
             
            </tr>';
  end loop;
  
 for j in c_backorder_header(TO_NUMBER(document_id)) loop
   document:= '<html>
        <body>
          <td>Order Date : '||j.order_date||'</td>
		  <br/>
		  <br/>
          <td>Order Creator : '||j.order_creator||'</td>
		  <br/>
          <br/>
         <Table>
          <tr>
          <th> <h3>To:</h3> </th>
          <th>&nbsp;&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;</th>
          <th>&nbsp;&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;</th>
          <th>&nbsp;&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;</th>
          <th>&nbsp;&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;</th>
          <th> <h3>Ship To:</h3> </th> 
          </tr> 
          <tr border = 0>
          <td>'||j.invoice_to||' </td>
          <td>&nbsp;&nbsp; &nbsp;&nbsp; &nbsp; &nbsp; &nbsp; &nbsp;</td>
          <td>&nbsp;&nbsp; &nbsp;&nbsp; &nbsp; &nbsp; &nbsp; &nbsp;</td>
          <td>&nbsp;&nbsp; &nbsp;&nbsp; &nbsp; &nbsp; &nbsp; &nbsp;</td>
          <th>&nbsp;&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;</th>
          <td>'||j.ship_to ||' </td>   
          </tr>
          <tr>
          <td> '||j.invoice_to_address1||' </td>
          <td>&nbsp;&nbsp; &nbsp;&nbsp; &nbsp; &nbsp; &nbsp; &nbsp;</td>
          <td>&nbsp;&nbsp; &nbsp;&nbsp; &nbsp; &nbsp; &nbsp; &nbsp;</td>
          <td>&nbsp;&nbsp; &nbsp;&nbsp; &nbsp; &nbsp; &nbsp; &nbsp;</td>
          <th>&nbsp;&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;</th>
          <td> '||j.ship_to_address1||' </td>   
          </tr>		  
          <tr>
          <td> '||j.invoice_to_address2||' </td>
          <td>&nbsp;&nbsp; &nbsp;&nbsp; &nbsp; &nbsp; &nbsp; &nbsp;</td>
          <td>&nbsp;&nbsp; &nbsp;&nbsp; &nbsp; &nbsp; &nbsp; &nbsp;</td>
          <td>&nbsp;&nbsp; &nbsp;&nbsp; &nbsp; &nbsp; &nbsp; &nbsp;</td>
          <th>&nbsp;&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;</th>
          <td> '||j.ship_to_address2||' </td>   
          </tr>
          <tr>
          <td> '||j.invoice_to_city||j.invoice_to_postal_code||' </td>
          <td>&nbsp;&nbsp; &nbsp;&nbsp; &nbsp; &nbsp; &nbsp; &nbsp;</td>
          <td>&nbsp;&nbsp; &nbsp;&nbsp; &nbsp; &nbsp; &nbsp; &nbsp;</td>
          <td>&nbsp;&nbsp; &nbsp;&nbsp; &nbsp; &nbsp; &nbsp; &nbsp;</td>
          <th>&nbsp;&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;</th>
          <td> '||j.ship_to_city||j.ship_to_postal_code||' </td>   
          </tr>		  
          <tr>
          <td> '||j.invoice_to_state||' </td>
          <td>&nbsp;&nbsp; &nbsp;&nbsp; &nbsp; &nbsp; &nbsp; &nbsp;</td>
          <td>&nbsp;&nbsp; &nbsp;&nbsp; &nbsp; &nbsp; &nbsp; &nbsp;</td>
          <td>&nbsp;&nbsp; &nbsp;&nbsp; &nbsp; &nbsp; &nbsp; &nbsp;</td>
          <th>&nbsp;&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;</th>
          <td> '||j.ship_to_state||' </td>   
          </tr>
          <tr>
          <td> '||j.invoice_to_country||' </td>
          <td>&nbsp;&nbsp; &nbsp;&nbsp; &nbsp; &nbsp; &nbsp; &nbsp;</td>
          <td>&nbsp;&nbsp; &nbsp;&nbsp; &nbsp; &nbsp; &nbsp; &nbsp;</td>
          <td>&nbsp;&nbsp; &nbsp;&nbsp; &nbsp; &nbsp; &nbsp; &nbsp;</td>
          <th>&nbsp;&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;</th>
          <td> '||j.ship_to_country||' </td>   
          </tr>
          <tr>
          <td> Attn:'||j.invoice_to_contact||' </td>
          <td>&nbsp;&nbsp; &nbsp;&nbsp; &nbsp; &nbsp; &nbsp; &nbsp;</td>
          <td>&nbsp;&nbsp; &nbsp;&nbsp; &nbsp; &nbsp; &nbsp; &nbsp;</td>
          <td>&nbsp;&nbsp; &nbsp;&nbsp; &nbsp; &nbsp; &nbsp; &nbsp;</td>
          <th>&nbsp;&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;</th>
          <td> Attn:'||j.ship_to_contact||' </td>   
          </tr>	          
          <tr>
          <td> Tel: '||j.invoice_to_contact_phone||' '||'Fax:'||j.invoice_to_contact_fax||' </td>
          <td>&nbsp;&nbsp; &nbsp;&nbsp; &nbsp; &nbsp; &nbsp; &nbsp;</td>
          <td>&nbsp;&nbsp; &nbsp;&nbsp; &nbsp; &nbsp; &nbsp; &nbsp;</td>
          <td>&nbsp;&nbsp; &nbsp;&nbsp; &nbsp; &nbsp; &nbsp; &nbsp;</td>
          <th>&nbsp;&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;</th>
          <td> Tel: '||j.ship_to_contact_phone||' '||'Fax:'||j.ship_to_contact_fax||' </td>   
          </tr>
         </Table> 
          <br/>
          <table border="1">
            <tr>
             
              <th>Ln</th>
              <th>Part Number</th>
              <th>Part Description</th>
              <th>Qty</th>
              <th>Estimated Ship Date</th>
              
            </tr>'||l_doc||
          
          '</table>
		  <br/>
		  <br/>
          <td> Payment Terms : '||j.terms||' </td>
		  <br/>
		  <br/>
          <td> Customer PO : '||j.po_number||' </td>
		  <br/>
		  <br/>
          <td> Sales Rep : '||j.salesrep_name||' </td>
		  <br/>
		  <br/>
          <td> Ship By : '||j.freight_carrier_code||' </td>
		  <br/>
		  <br/>
          <td>  Customer Number : '||j.customer_number||' </td>
		  <br/>
		  <br/>
          <td>  Type of Sale : '||j.order_type||' </td>  
		  <br/>
		  <br/>
          <td>  Vendor no : '||j.vendor_no||' </td>
		  <br/>
		  <br/>
		  <td> Freight Terms : '||j.freight_terms_code||' </td>
          <br/>  
          <br/>           
          <footer>
			<td>Delivery place in accordance with Incoterms&reg;2010 :'||' '||j.fob||'</td>
		   </footer>
        </body>
      </html>'; 
 END LOOP;     
 document_type := 'TEXT/HTML' || ';name=' || 'LOG.HTML';
      
  EXCEPTION
    WHEN OTHERS THEN            
      wf_core.CONTEXT('xxobjt_wf_mail',
                      'xx_notif_attach_procedure',
                      document_id,
                      display_type);
      RAISE; 
 
 END backorder_details;

end XXOM_BACKORDER_NTY_PKG;
/