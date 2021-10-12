CREATE OR REPLACE PACKAGE BODY xxinv_pronto_message_pkg AS
  ----------------------------------------------------------------------------
  --  name:            xxinv_ecomm_message_pkg
  --  create by:       Diptasurjya Chatterjee (TCS)
  --  Revision:        1.0
  --  creation date:   26/10/2015
  ----------------------------------------------------------------------------
  --  purpose :        CHG0036886 - Generic container package to handle all
  --                   inventory module related message generation where target is PRONTO,
  --                   against events recorded by API xxinv_ecomm_event_pkg
  ----------------------------------------------------------------------------
  --  ver  date        name                         desc
  --  1.0  26/10/2015  Diptasurjya Chatterjee(TCS)  CHGxxx - add pronto item message creation and
  --                                                and pronto item onhand message creation functions
  ----------------------------------------------------------------------------

  g_target_name VARCHAR2(20) := 'PRONTO';

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0036886
  --          This function generate and return product data for a given event_id
  --          for PRONTO integration
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  26/10/2015  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------

  FUNCTION generate_item_data(p_event_id  NUMBER,
		      p_entity_id NUMBER)
    RETURN xxinv_pronto_product_rec_type IS
    l_product xxinv_pronto_product_rec_type;
    l_status  VARCHAR2(1) := 'A';
  BEGIN
    SELECT decode(active_flag, 'N', 'I', 'A')
    INTO   l_status
    FROM   xxssys_events
    WHERE  event_id = p_event_id;
  
    SELECT xxinv_pronto_product_rec_type(p_event_id,
			     xopv.oa_product_id,
			     xopv.product_code,
			     xopv.product_name,
			     NULL,
			     NULL,
			     xopv.sf_product_id,
			     xopv.product_status,
			     91,
			     (SELECT organization_code
			      FROM   org_organization_definitions
			      WHERE  organization_id = 91),
			     NULL,
			     lower(xopv.service_item_flag),
			     xopv.billing_type,
			     lower(xopv.item_returnable),
			     xopv.relate_sf_item_id,
			     (SELECT cat.concatenated_segments
			      FROM   xxobjt_oa2sf_category_v cat
			      WHERE  cat.inventory_item_id =
				 p_entity_id
			      AND    cat.category_set_name =
				 'Activity Analysis'),
			     l_status,
			     'S',
			     NULL,
			     NULL,
			     NULL,
			     NULL,
			     NULL,
			     NULL,
			     NULL,
			     NULL,
			     NULL,
			     NULL,
			     NULL,
			     NULL,
			     NULL,
			     NULL,
			     NULL,
			     NULL)
    INTO   l_product
    FROM   xxobjt_oa2sf_products_v xopv
    WHERE  xopv.oa_product_id = p_entity_id;
  
    RETURN l_product;
  EXCEPTION
    WHEN OTHERS THEN
      l_product := xxinv_pronto_product_rec_type(p_event_id,
				 NULL, --   xopv.oa_product_id,
				 NULL, --   xopv.product_code,
				 NULL, --   xopv.product_name,
				 NULL,
				 NULL,
				 NULL, --   xopv.sf_product_id,
				 NULL, --   xopv.product_status,
				 NULL, --   91,
				 NULL, --   NULL, NULL, -- lower(xopv.service_item_flag),
				 NULL, -- xopv.billing_type,
				 NULL, -- lower(xopv.item_returnable),
				 NULL, -- xopv.substitute_items_id,
				 NULL,
				 NULL,
				 NULL, --,
				 NULL, -- l_status,
				 'E',
				 substr(SQLERRM, 1, 400),
				 NULL,
				 NULL,
				 NULL,
				 NULL,
				 NULL,
				 NULL,
				 NULL,
				 NULL,
				 NULL,
				 NULL,
				 NULL,
				 NULL,
				 NULL,
				 NULL,
				 NULL);
      RETURN l_product;
  END generate_item_data;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0036886
  --          This function generate and return item onhand data for a given event_id
  --          for PRONTO integration
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  27/10/2015  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------

  FUNCTION generate_onhand_data(p_event_id NUMBER)
    RETURN xxinv_item_onhand_rec_type IS
    l_onhand xxinv_item_onhand_rec_type;
  
    l_quantity            NUMBER := 0;
    l_onhand_subinventory mtl_onhand_quantities.subinventory_code%TYPE;
  BEGIN
    BEGIN
      SELECT moq.subinventory_code,
	 SUM(moq.transaction_quantity)
      INTO   l_onhand_subinventory,
	 l_quantity
      FROM   mtl_onhand_quantities moq,
	 xxssys_events         xe
      
      WHERE  xe.event_id = p_event_id
      AND    moq.inventory_item_id = xe.entity_id
      AND    moq.organization_id = xe.attribute1
      AND    moq.subinventory_code = xe.attribute2
      AND    nvl(moq.revision, '-1') = nvl(xe.attribute3, '-1')
      GROUP  BY moq.inventory_item_id,
	    moq.organization_id,
	    moq.subinventory_code,
	    moq.revision;
    
      --dbms_output.put_line(xxinv_pronto_event_pkg.is_valid_subinventory(l_onhand_subinventory));
      IF xxinv_pronto_event_pkg.is_valid_subinventory(l_onhand_subinventory) = 'N'
      
       THEN
        l_quantity := 0;
      END IF;
    EXCEPTION
      WHEN no_data_found THEN
        l_quantity := 0;
    END;
  
    SELECT xxinv_item_onhand_rec_type(p_event_id,
			  a.entity_id,
			  msib.segment1,
			  a.attribute1,
			  ood.organization_code,
			  ood.organization_name,
			  ood.organization_id || '|' ||
			  l_onhand_subinventory,
			  msin.description,
			  a.attribute3,
			  (SELECT revision_id
			   FROM   mtl_item_revisions_b mir
			   WHERE  mir.inventory_item_id =
			          to_number(a.entity_id)
			   AND    mir.organization_id =
			          to_number(a.attribute1)
			   AND    mir.revision = a.attribute3), -- reveision_id
			  l_quantity,
			  xxobjt_oa2sf_interface_pkg.get_entity_sf_id('PRODUCT',
						          a.entity_id),
			  NULL,
			  NULL,
			  'S', -- message_status_code
			  NULL, -- message_status_note
			  
			  NULL,
			  NULL,
			  NULL,
			  NULL,
			  NULL,
			  NULL,
			  NULL,
			  NULL,
			  NULL,
			  NULL,
			  NULL,
			  NULL,
			  NULL,
			  NULL,
			  NULL)
    INTO   l_onhand
    FROM   mtl_system_items_b           msib,
           org_organization_definitions ood,
           mtl_secondary_inventories    msin,
           xxssys_events                a
    
    WHERE  a.event_id = p_event_id
    AND    a.attribute1 = ood.organization_id
    AND    ood.organization_id = msin.organization_id
    AND    a.attribute2 = msin.secondary_inventory_name
    AND    msib.inventory_item_id = a.entity_id
    AND    msib.organization_id = 91;
  
    RETURN l_onhand;
  EXCEPTION
    WHEN OTHERS THEN
      NULL;
    
      l_onhand := xxinv_item_onhand_rec_type(p_event_id,
			         NULL, --  a.entity_id,
			         NULL, --  msib.segment1,
			         NULL, --  a.attribute1,
			         NULL, --  ood.organization_code,
			         NULL, --  ood.organization_name,
			         NULL, --  a.attribute1 || '|' || a.attribute2,
			         NULL, --  msin.description,
			         NULL, -- a.attribute3,
			         NULL, -- reveision_id
			         NULL, --   l_quantity,
			         NULL, --  xxobjt_oa2sf_interface_pkg.get_entity_sf_id('PRODUCT',
			         --                                   a.entity_id),
			         NULL,
			         NULL,
			         'E', -- message_status_code
			         substr(SQLERRM, 1, 250), -- message_status_note
			         
			         NULL,
			         NULL,
			         NULL,
			         NULL,
			         NULL,
			         NULL,
			         NULL,
			         NULL,
			         NULL,
			         NULL,
			         NULL,
			         NULL,
			         NULL,
			         NULL,
			         NULL);
      RETURN l_onhand;
  END generate_onhand_data;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0036886
  --          This function generate and return item onhand data for a given event_id
  --          for PRONTO integration
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  27/10/2015  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE update_item_event_active_flag(p_event_id    IN NUMBER,
			      p_item_id     IN NUMBER,
			      p_active_flag IN VARCHAR2) IS
  
  BEGIN
    --dbms_output
  
    IF xxinv_pronto_event_pkg.check_item_eligibility(NULL, NULL, p_item_id) <> 'Y' AND
       p_active_flag <> 'N' THEN
      UPDATE xxssys_events
      SET    active_flag      = 'N',
	 last_update_date = SYSDATE
      WHERE  event_id = p_event_id;
    
    END IF;
  END update_item_event_active_flag;

  -- --------------------------------------------------------------------------------------------
  -- Name:              generate_product_messages
  -- Create by:         Diptasurjya Chatterjee
  -- Revision:          1.0
  -- Creation date:     27/10/2015
  -- Calling Entity:    BPEL Process: http://srv-ire-bpeldev.2objet.com:8001/soa-infra/services/ecomm/ProcessProductDetailsCmp/productdetailsprocessbpel_client_ep?wsdl
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0036886
  --          This procedure is used to fetch product details as per NEW events recorded in event
  --          table
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  27/10/2015  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE generate_product_messages(x_errbuf           OUT VARCHAR2,
			  x_retcode          OUT NUMBER,
			  p_no_of_record     IN NUMBER,
			  p_bpel_instance_id IN NUMBER,
			  p_event_id_tab     IN xxobjt.xxssys_interface_event_tab,
			  x_products         OUT xxobjt.xxinv_pronto_product_tab_type) IS
  
    l_product_data     xxinv_pronto_product_tab_type := xxinv_pronto_product_tab_type();
    l_product_data_tmp xxinv_pronto_product_rec_type;
  
    l_event_update_status VARCHAR2(1);
  
    l_mail_body VARCHAR2(4000);
  
    l_entity_name VARCHAR2(10) := 'ITEM';
  BEGIN
    IF p_event_id_tab IS NULL OR p_event_id_tab.count = 0 THEN
      /* l_event_update_status := xxssys_event_pkg.update_bpel_instance_id(p_no_of_record,
      l_entity_name,
      g_target_name,
      p_bpel_instance_id);*/
    
      IF l_event_update_status = 'Y' THEN
        FOR entity_rec IN (SELECT event_id,
		          entity_id,
		          active_flag
		   FROM   xxssys_events
		   WHERE  bpel_instance_id = p_bpel_instance_id
		   AND    status = 'NEW') LOOP
          BEGIN
	/* Set event status to SUCCESS */
	/* Event status not updated as per Yuval's mail on: Tue 11/10/2015 9:25 AM */
	--xxssys_event_pkg.update_success(entity_rec.event_id);
          
	/* Update the active flag to correct value after validation of item,
            This is required to handle following sequence of events:
              1. New item eligible for interfacing is created where active_flag will be Y
              2. Event is not yet interfaced by SOA
              3. This item is updated, so that it becomes not eligible for interface
              4. But new event with active_flag = 'N' will not be generated, as
                 existing uprocessed event irrespective of active_flag already exists
              5. So a inactive event will be sent as active item
              6. To rectify this, before message is prepared, we check for eligibility
                 and change event active_flag accordingly */
	-- Removed as requested by Yuval 24NOV2015
	/*update_item_event_active_flag(entity_rec.event_id,
            entity_rec.entity_id,
            entity_rec.active_flag);*/
	/* END active_flag update */
          
	l_product_data_tmp := generate_item_data(entity_rec.event_id,
				     entity_rec.entity_id);
	l_product_data.extend();
	l_product_data(l_product_data.count) := l_product_data_tmp;
          
	/*  EXCEPTION
               WHEN OTHERS THEN
                 xxssys_event_pkg.process_event_error(entity_rec.event_id,
                                                      'ORACLE',
                                                      'UNEXPECTED ERROR: ' ||
                                                      SQLERRM);
            */
          END;
        END LOOP;
      END IF;
    ELSE
      /* FOR i IN 1 .. p_event_id_tab.count LOOP
        l_event_update_status := xxssys_event_pkg.update_one_bpel_instance_id(p_event_id_tab(i)
                                                                              .event_id,
                                                                              l_entity_name,
                                                                              g_target_name,
                                                                              p_bpel_instance_id);
      END LOOP;*/
    
      FOR entity_rec IN (SELECT event_id,
		        entity_id,
		        active_flag
		 FROM   xxssys_events
		 -- WHERE  bpel_instance_id = p_bpel_instance_id) 
		 WHERE  event_id IN /*bpel_instance_id =*/
		        (SELECT event_id
		         FROM   TABLE(p_event_id_tab)) /*p_bpel_instance_id*/
		 /* AND    status = 'NEW'*/
		 )
      
       LOOP
        BEGIN
          --if xxobjt_oa2sf_interface_pkg.is_relate_to_sf(entity_rec.entity_id, 'PRODUCT', '') = 'Y' then
          /* Event status not updated as per Yuval's mail on: Tue 11/10/2015 9:25 AM */
          --xxssys_event_pkg.update_success(entity_rec.event_id);
        
          /* Update the active flag to correct value after validation of item,
          This is required to handle following sequence of events:
            1. New item eligible for interfacing is created where active_flag will be Y
            2. Event is not yet interfaced by SOA
            3. This item is updated, so that it becomes not eligible for interface
            4. But new event with active_flag = 'N' will not be generated, as
               existing uprocessed event irrespective of active_flag already exists
            5. So a inactive event will be sent as active item
            6. To rectify this, before message isprepared, we check for eligibility
               and change event active_flag accordingly */
          -- Removed as requested by Yuval 24NOV2015
          /*update_item_event_active_flag(entity_rec.event_id,
          entity_rec.entity_id,
          entity_rec.active_flag);*/
          /* END active_flag update */
        
          l_product_data_tmp := generate_item_data(entity_rec.event_id,
				   entity_rec.entity_id);
          l_product_data.extend();
          l_product_data(l_product_data.count) := l_product_data_tmp;
        
        END;
      END LOOP;
    END IF;
  
    COMMIT;
    x_products := l_product_data;
  
    x_retcode := 0;
    x_errbuf  := 'COMPLETE';
  EXCEPTION
    WHEN OTHERS THEN
      x_retcode   := 2;
      x_errbuf    := 'ERROR';
      l_mail_body := 'The following unexpected exception occurred for ' ||
	         'PRONTO Products interface.' || chr(13) || chr(10) ||
	         'Failure reason : ' || chr(13) || chr(10);
    
      l_mail_body := l_mail_body || '  Error Message: ' || SQLERRM;
    
      xxinv_pronto_event_pkg.send_mail('XXINV_PRONTO_EVENT_PKG_ITEM_TO',
			   'XXINV_PRONTO_EVENT_PKG_ITEM_CC',
			   'Product',
			   l_mail_body,
			   'message preparation');
  END generate_product_messages;

  -- --------------------------------------------------------------------------------------------
  -- Name:              generate_onhand_messages
  -- Create by:         Diptasurjya Chatterjee
  -- Revision:          1.0
  -- Creation date:     27/10/2015
  -- Calling Entity:    BPEL Process: http://srv-ire-bpeldev.2objet.com:8001/soa-infra/services/ecomm/ProcessProductDetailsCmp/productdetailsprocessbpel_client_ep?wsdl
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0036886
  --          This procedure is used to fetch item onhand details as per NEW events recorded in event
  --          table
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  27/10/2015  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE generate_onhand_messages(x_errbuf           OUT VARCHAR2,
			 x_retcode          OUT NUMBER,
			 p_no_of_record     IN NUMBER,
			 p_bpel_instance_id IN NUMBER,
			 p_event_id_tab     IN xxobjt.xxssys_interface_event_tab,
			 x_onhand           OUT xxobjt.xxinv_item_onhand_tab_type) IS
    l_onhand_data     xxinv_item_onhand_tab_type := xxinv_item_onhand_tab_type();
    l_onhand_data_tmp xxinv_item_onhand_rec_type;
  
    l_event_update_status VARCHAR2(1);
    l_validation_flag     VARCHAR2(1) := 'Y';
  
    l_total_count   NUMBER;
    l_invalid_count NUMBER;
  
    l_mail_body VARCHAR2(4000);
  
    l_entity_name VARCHAR2(10) := 'ONHAND';
  BEGIN
    IF p_event_id_tab IS NULL OR p_event_id_tab.count = 0 THEN
      l_event_update_status := xxssys_event_pkg.update_bpel_instance_id(p_no_of_record,
						l_entity_name,
						g_target_name,
						p_bpel_instance_id);
    
      IF l_event_update_status = 'Y' THEN
        FOR entity_rec IN (SELECT event_id,
		          entity_id,
		          attribute1,
		          attribute2
		   FROM   xxssys_events
		   WHERE  bpel_instance_id = p_bpel_instance_id
		   AND    status = 'NEW') LOOP
          BEGIN
	l_validation_flag := 'Y';
	l_total_count     := l_total_count + 1;
          
	l_onhand_data_tmp := generate_onhand_data(entity_rec.event_id);
	l_onhand_data.extend();
	l_onhand_data(l_onhand_data.count) := l_onhand_data_tmp;
          EXCEPTION
	WHEN OTHERS THEN
	  l_invalid_count := l_invalid_count + 1;
	  xxssys_event_pkg.process_event_error(entity_rec.event_id,
				   'ORACLE',
				   'UNEXPECTED ERROR: ' ||
				   SQLERRM);
          END;
        END LOOP;
      END IF;
    ELSE
      /* FOR i IN 1 .. p_event_id_tab.count LOOP
        l_event_update_status := xxssys_event_pkg.update_one_bpel_instance_id(p_event_id_tab(i)
                                                                              .event_id,
                                                                              l_entity_name,
                                                                              g_target_name,
                                                                              p_bpel_instance_id);
      END LOOP;*/
    
      FOR entity_rec IN (SELECT event_id,
		        entity_id,
		        attribute1,
		        attribute2
		 FROM   xxssys_events
		 WHERE  event_id IN /*bpel_instance_id =*/
		        (SELECT event_id
		         FROM   TABLE(p_event_id_tab))) LOOP
      
        /* Event status not updated as per Yuval's mail on: Tue 11/10/2015 9:25 AM */
        --xxssys_event_pkg.update_success(entity_rec.event_id);
      
        l_onhand_data_tmp := generate_onhand_data(entity_rec.event_id);
        l_onhand_data.extend();
        l_onhand_data(l_onhand_data.count) := l_onhand_data_tmp;
      
      END LOOP;
    END IF;
  
    COMMIT;
    x_onhand := l_onhand_data;
  
    x_retcode := 0;
    x_errbuf  := 'COMPLETE';
  
  EXCEPTION
    WHEN OTHERS THEN
      x_retcode   := 2;
      x_errbuf    := 'ERROR';
      l_mail_body := 'The following unexpected exception occurred for ' ||
	         'Item Onhand interface.' || chr(10) ||
	         'Failure reason : ' || chr(13) || chr(10);
    
      l_mail_body := l_mail_body || '  Error Message: ' || SQLERRM;
    
      xxinv_pronto_event_pkg.send_mail('XXINV_PRONTO_EVENT_PKG_ONHAND_TO',
			   'XXINV_PRONTO_EVENT_PKG_ONHAND_CC',
			   'Item Onhand',
			   l_mail_body,
			   'message preparation');
  END generate_onhand_messages;

END xxinv_pronto_message_pkg;
/
