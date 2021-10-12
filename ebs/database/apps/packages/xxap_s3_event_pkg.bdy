CREATE OR REPLACE PACKAGE BODY xxap_s3_event_pkg
-- =============================================================================
-- Copyright(c) :
-- Application  : Custom Application
-- -----------------------------------------------------------------------------
-- Program name                Creation Date    Original Ver    Created by
-- xxap_s3_event_pkg            30-JUL-2016      1.0             TCS
-- ----------------------------------------------------------------------------
-- -----------------------------------------------------------------------------
-- Description: This program will be used as business event subcription package
-- Parameter    : Written in each procedure section.
-- Return value : Written in each procedure section.
-- -----------------------------------------------------------------------------
-- Modification History:
-- Modified Date     Version      Done by       Change Description
--
-- =============================================================================
 IS

 FUNCTION event_process(p_subscription_guid IN RAW,
                         p_event             IN OUT NOCOPY wf_event_t)
    RETURN VARCHAR2
  
    -- ===========================================================================
    --  Program name          Creation Date               Created by
    --  event_process          30-JUL-2016                 TCS
    -- ---------------------------------------------------------------------------
    -- Description  : This procedure is used to insert the triggered data
    --                into business events table
    -- Return value : None
    --
    -- ===========================================================================   
  
   IS
  
    l_param_list       apps.wf_parameter_list_t; -- Event parameter list
    l_event_name       VARCHAR2(240); -- Event name
    l_param_name       VARCHAR2(240); -- Parameter name
    l_param_value      VARCHAR2(240); -- Parameter value
    l_org_id           NUMBER;
    l_cust_txn_id      NUMBER;
    l_cust_count       NUMBER;
    l_err_msg          VARCHAR2(100);
    l_event_key        VARCHAR2(2000);
    l_event_data       VARCHAR2(4000);
    l_target_name      xxssys_events.target_name%type := 'S3';
    l_entity_name      xxssys_events.entity_name%type := 'AR Invoice';
    l_active_flag      xxssys_events.active_flag%type := 'Y';
    l_xxssys_event_rec xxssys_events%ROWTYPE;
  BEGIN
              
    --l_count := l_count + 1;
   
    --//==========================================================================
    ---Getting Business event parameters in a table type
    --//==========================================================================
  
    SAVEPOINT event_start;
  
    l_param_list := p_event.getparameterlist;
    l_event_name := 'xxar.oracle.apps.ar.transaction.complete';
    l_event_key  := p_event.geteventkey();
    l_event_data := p_event.geteventdata();
    
    
  IF (l_param_list IS NOT NULL) THEN 
    
    FOR i IN l_param_list.FIRST .. l_param_list.LAST LOOP
     
      l_param_name  := l_param_list(i).getname;
      l_param_value := l_param_list(i).getvalue;
    
      IF (l_param_name = 'ORG_ID') THEN
        l_org_id := l_param_value;
      ELSIF (l_param_name = 'CUSTOMER_TRX_ID') THEN
        l_cust_txn_id := l_param_value;
      END IF;
    
    END LOOP;
  
    --//==========================================================================
    --// Checking business event fires only for interim customer
    --//==========================================================================
  
    SELECT COUNT(1)
      INTO l_cust_count
      FROM ra_customer_trx_all       rcta,
           ra_customer_trx_lines_all rctla,
           oe_order_headers_all      ooha,
           oe_order_lines_all        oola,
           oe_order_sources          oos,
           hz_cust_accounts          hca,
           fnd_lookup_values_vl      flvv,
           mtl_system_items_b        msib,
           hr_operating_units        hou,
           hz_cust_acct_sites_all    hcasa,
           hz_cust_site_uses_all     hcsua,
           hz_party_sites            hps
     WHERE rcta.customer_trx_id = rctla.customer_trx_id
       AND rcta.interface_header_attribute1 = to_char(ooha.order_number)
       AND ooha.header_id = oola.header_id
       AND rctla.interface_line_attribute6 = to_char(oola.line_id)
       AND ooha.org_id = rcta.org_id
       AND rctla.interface_line_attribute1 = to_char(ooha.order_number)
       AND rctla.sales_order = to_char(ooha.order_number)
       AND rctla.line_type = 'LINE'
       AND rctla.inventory_item_id = msib.inventory_item_id
       AND msib.organization_id =
           (SELECT DISTINCT master_organization_id FROM mtl_parameters)
       AND ooha.sold_to_org_id = hca.cust_account_id
       AND hou.organization_id = ooha.org_id
       AND ooha.invoice_to_org_id = hcsua.site_use_id
       AND hcasa.cust_acct_site_id = hcsua.cust_acct_site_id
       AND hps.party_site_id = hcasa.party_site_id
       AND ooha.order_source_id = oos.order_source_id
       AND flvv.lookup_type = 'XX_S3_INTERIM_SHIPPING_NETWORK'
       AND nvl(flvv.enabled_flag, 'N') = 'Y'
       AND sysdate between nvl(flvv.START_DATE_ACTIVE, sysdate) and
           nvl(flvv.END_DATE_ACTIVE, sysdate + 1)
       AND hca.account_name = flvv.attribute5
       AND hps.party_site_name = flvv.attribute6
       AND hou.name = flvv.attribute4
       AND oos.name = 'S3 INTERIM' 
       AND rcta.customer_trx_id = l_cust_txn_id;
  
    --//==========================================================================
    --// checking businee event fires for a particular interim customer
    --//==========================================================================
     
    IF l_cust_count != 0 THEN
    
      IF (l_param_name = 'CUSTOMER_TRX_ID') THEN
      
        l_xxssys_event_rec.target_name := l_target_name;
        l_xxssys_event_rec.entity_name := l_entity_name;
        l_xxssys_event_rec.entity_id   := l_cust_txn_id;
        l_xxssys_event_rec.event_name  := l_event_name;
        l_xxssys_event_rec.active_flag := l_active_flag;
      
        --//==========================================================================
        --// calling business event package to insert the event data
        --//==========================================================================
        
      
        xxssys_event_pkg.insert_event(p_xxssys_event_rec => l_xxssys_event_rec);
     
        COMMIT;
      
      END IF;
   END IF;
    RETURN 'SUCCESS';
     END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
    
      xxssys_event_pkg.process_event_error(p_event_id     => l_xxssys_event_rec.event_id,
                                           p_error_system => l_xxssys_event_rec.status,
                                           p_err_message  => l_xxssys_event_rec.err_message);
    
      ROLLBACK TO event_start;
      wf_core.CONTEXT('ar_inv_details',
                      p_event.geteventname(),
                      p_subscription_guid);
      wf_event.seterrorinfo(p_event, 'ERROR: ' || substr(SQLERRM, 1, 1000));
      
      RETURN 'ERROR';
  END event_process;

 END xxap_s3_event_pkg;
/
