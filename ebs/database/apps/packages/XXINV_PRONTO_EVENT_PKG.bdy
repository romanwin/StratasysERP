CREATE OR REPLACE PACKAGE BODY xxinv_pronto_event_pkg AS
  ----------------------------------------------------------------------------
  --  name:            xxinv_pronto_event_pkg
  --  create by:       Diptasurjya Chatterjee (TCS)
  --  Revision:        1.0
  --  creation date:   27/10/2015
  ----------------------------------------------------------------------------
  --  purpose :        CHG0036886 - Generic container package to handle all
  --                   inventory module related event invocations for PRONTO target. For item
  --                   as no suitable business events were identified, triggers
  --                   has been created on base tables and processed by this API
  ----------------------------------------------------------------------------
  --  ver  date        name                         desc
  --  1.0  27/10/2015  Diptasurjya Chatterjee(TCS)  CHG0036886 - initial build
  ----------------------------------------------------------------------------

  g_target_name VARCHAR2(10) := 'PRONTO';
  g_item_entity VARCHAR2(10) := 'ITEM';

  g_event_rec xxssys_events%ROWTYPE;

  -- --------------------------------------------------------------------------------------------
  -- Name:              compare_old_new_items
  -- Create by:         Diptasurjya Chatterjee
  -- Revision:          1.0
  -- Creation date:     27/10/2015
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0036886
  --          This function will be used to compare item before update with item after update
  --          for PRONTO integration
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  27/10/2015  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------

  FUNCTION compare_old_new_items(p_old_item_rec item_rec_type,
		         p_new_item_rec item_rec_type)
    RETURN VARCHAR2 IS
  BEGIN
    IF p_old_item_rec.inventory_item_id = p_new_item_rec.inventory_item_id AND
       nvl(p_old_item_rec.segment1, '-1') =
       nvl(p_new_item_rec.segment1, '-1') AND
       nvl(p_old_item_rec.description, '-1') =
       nvl(p_new_item_rec.description, '-1') AND
       nvl(p_old_item_rec.status, '-1') = nvl(p_new_item_rec.status, '-1') AND
       nvl(p_old_item_rec.customer_order_enabled_flag, '-1') =
       nvl(p_new_item_rec.customer_order_enabled_flag, '-1') AND
       nvl(p_old_item_rec.service_item_flag, '-1') =
       nvl(p_new_item_rec.service_item_flag, '-1') AND
       nvl(p_old_item_rec.material_billable_flag, '-1') =
       nvl(p_new_item_rec.material_billable_flag, '-1') AND
       nvl(p_old_item_rec.item_returnable, '-1') =
       nvl(p_new_item_rec.item_returnable, '-1') AND
       nvl(p_old_item_rec.related_item_id, '-1') =
       nvl(p_new_item_rec.related_item_id, '-1') AND
       nvl(p_old_item_rec.relationship_type_id, '-1') =
       nvl(p_new_item_rec.relationship_type_id, '-1') AND
       nvl(p_old_item_rec.sf_id, '-1') = nvl(p_new_item_rec.sf_id, '-1') AND
       nvl(p_old_item_rec.category_set_id, '-1') =
       nvl(p_new_item_rec.category_set_id, '-1') AND
       nvl(p_old_item_rec.category_id, '-1') =
       nvl(p_new_item_rec.category_id, '-1') THEN
      RETURN 'TRUE';
    ELSE
      RETURN 'FALSE';
    END IF;
  END compare_old_new_items;

  -- --------------------------------------------------------------------------------------------
  -- Name:              send_mail
  -- Create by:         Diptasurjya Chatterjee
  -- Revision:          1.0
  -- Creation date:     27/10/2015
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0036886
  --          Send Mail for errors
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  27/10/2015  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE send_mail(p_program_name_to IN VARCHAR2,
	          p_program_name_cc IN VARCHAR2,
	          p_entity          IN VARCHAR2,
	          p_body            IN VARCHAR2,
	          p_api_phase       IN VARCHAR2 DEFAULT NULL) IS
    l_mail_to_list VARCHAR2(240);
    l_mail_cc_list VARCHAR2(240);
    l_err_code     VARCHAR2(4000);
    l_err_msg      VARCHAR2(4000);
  
    l_api_phase VARCHAR2(240) := 'event processor';
  BEGIN
    IF p_api_phase IS NOT NULL THEN
      l_api_phase := p_api_phase;
    END IF;
  
    l_mail_to_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
					      p_program_short_name => p_program_name_to);
  
    l_mail_cc_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
					      p_program_short_name => p_program_name_cc);
  
    --dbms_output.put_line('MAIL TO: '||l_mail_to_list);
  
    xxobjt_wf_mail.send_mail_text(p_to_role     => l_mail_to_list,
		          p_cc_mail     => l_mail_cc_list,
		          p_subject     => 'Stratasys Pronto interface error in Oracle, ' ||
				   l_api_phase || ' for - ' ||
				   p_entity,
		          p_body_text   => p_body,
		          p_err_code    => l_err_code,
		          p_err_message => l_err_msg);
  
  END send_mail;

  -- --------------------------------------------------------------------------------------------
  -- Name:              check_item_eligibility
  -- Create by:         Diptasurjya Chatterjee
  -- Revision:          1.0
  -- Creation date:     27/10/2015
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0036886
  --          This function will be used to check if item is eligible for interfacing
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  27/10/2015  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION check_item_eligibility(p_customer_order_enabled VARCHAR2,
		          p_item_status_code       VARCHAR2,
		          p_inventory_item_id      NUMBER)
    RETURN VARCHAR2 IS
    l_is_eligible VARCHAR2(1) := 'N';
  BEGIN
    IF p_customer_order_enabled IS NOT NULL AND
       p_item_status_code IS NOT NULL THEN
      BEGIN
        SELECT 'Y'
        INTO   l_is_eligible
        FROM   dual
        WHERE  p_customer_order_enabled = 'Y'
        AND    p_item_status_code NOT IN
	   (SELECT fv.flex_value
	     FROM   fnd_flex_values_vl  fv,
		fnd_flex_value_sets fvs
	     WHERE  fv.flex_value_set_id = fvs.flex_value_set_id
	     AND    fvs.flex_value_set_name LIKE
		'XXSSYS_SF_EXCLUDE_ITEM_STATUS'
	     AND    nvl(fv.enabled_flag, 'N') = 'Y'
	     AND    trunc(SYSDATE) BETWEEN
		nvl(fv.start_date_active, SYSDATE - 1) AND
		nvl(fv.end_date_active, SYSDATE + 1));
      EXCEPTION
        WHEN no_data_found THEN
          l_is_eligible := 'N';
      END;
    ELSE
      l_is_eligible := xxobjt_oa2sf_interface_pkg.is_relate_to_sf(p_inventory_item_id,
					      'PRODUCT',
					      '');
    END IF;
  
    RETURN l_is_eligible;
  END;

  -- --------------------------------------------------------------------------------------------
  -- Name:              check_item_relation
  -- Create by:         Diptasurjya Chatterjee
  -- Revision:          1.0
  -- Creation date:     11/11/2015
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0036886
  --          This function will be used to check if item relaion is eligible for interfacing
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  11/11/2015  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION check_item_relation(p_relationship_type_id NUMBER) RETURN VARCHAR2 IS
    l_is_eligible VARCHAR2(1) := 'N';
  BEGIN
    BEGIN
      SELECT 'Y'
      INTO   l_is_eligible
      FROM   dual
      WHERE  EXISTS (SELECT flv.lookup_code
	  FROM   fnd_lookup_values flv
	  WHERE  flv.lookup_type = 'MTL_RELATIONSHIP_TYPES'
	  AND    flv.language = userenv('LANG')
	  AND    flv.meaning = 'Substitute'
	  AND    flv.lookup_code = p_relationship_type_id);
    
    EXCEPTION
      WHEN no_data_found THEN
        l_is_eligible := 'N';
    END;
  
    RETURN l_is_eligible;
  END;

  -- --------------------------------------------------------------------------------------------
  -- Name:              check_subinv_eligibility
  -- Create by:         Diptasurjya Chatterjee
  -- Revision:          1.0
  -- Creation date:     11/11/2015
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0036886
  --          This function will be used to check if an subinventory is eligible for interface
  --          to PRONTO
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  11/11/2015  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION check_subinv_eligibility(p_subinventory_code VARCHAR2,
			p_disable_date      DATE,
			p_attribute11       VARCHAR2)
    RETURN VARCHAR2 IS
    l_is_eligible VARCHAR2(1) := 'N';
  BEGIN
    BEGIN
      SELECT 'Y'
      INTO   l_is_eligible
      FROM   dual
      WHERE  nvl(p_disable_date, SYSDATE) > SYSDATE - 1
      AND    (p_attribute11 = 'Y' OR p_subinventory_code LIKE '%CAR');
    
    EXCEPTION
      WHEN no_data_found THEN
        l_is_eligible := 'N';
    END;
  
    RETURN l_is_eligible;
  END;

  -- --------------------------------------------------------------------------------------------
  -- Name:              auto_gen_onhand_events
  -- Create by:         Diptasurjya Chatterjee
  -- Revision:          1.0
  -- Creation date:     27/10/2015
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0036886
  --          This function will auto generate events for all onhand records for provided item ID
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  27/10/2015  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION auto_gen_onhand_events(p_inventory_item_id NUMBER,
		          p_trigger_name      VARCHAR2,
		          p_trigger_action    VARCHAR2,
		          p_active_flag       VARCHAR2) RETURN NUMBER IS
    l_generated_count  NUMBER := 0;
    l_xxssys_event_rec xxssys_events%ROWTYPE;
    l_organization     NUMBER;
    l_entity_name      VARCHAR2(10) := 'ONHAND';
  BEGIN
    FOR rec IN (SELECT DISTINCT inventory_item_id,
		        organization_id,
		        subinventory_code,
		        revision
	    FROM   mtl_onhand_quantities_detail
	    WHERE  inventory_item_id = p_inventory_item_id) LOOP
      IF /*xxobjt_oa2sf_interface_pkg.is_valid_to_sf('SUBINV',
                                                         rec.subinventory_code || '|' ||
                                                         rec.organization_id) = 1*/
      
       is_valid_subinventory(rec.subinventory_code) = 'Y' THEN
        l_xxssys_event_rec.target_name     := g_target_name;
        l_xxssys_event_rec.entity_name     := l_entity_name;
        l_xxssys_event_rec.entity_id       := rec.inventory_item_id;
        l_xxssys_event_rec.attribute1      := rec.organization_id;
        l_xxssys_event_rec.attribute2      := rec.subinventory_code;
        l_xxssys_event_rec.attribute3      := rec.revision;
        l_xxssys_event_rec.last_updated_by := -1;
        l_xxssys_event_rec.created_by      := -1;
        l_xxssys_event_rec.event_name      := p_trigger_name ||
			          '(AUTO_GENERATED)';
      
        l_xxssys_event_rec.active_flag := p_active_flag;
        --if xxssys_event_pkg.is_sync(l_xxssys_event_rec) = 'TRUE' then
        xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'Y');
        l_generated_count := l_generated_count + 1;
        --end if;
      END IF;
    END LOOP;
  
    RETURN l_generated_count;
  END;

  -- --------------------------------------------------------------------------------------------
  -- Name:              item_trigger_processor
  -- Create by:         Diptasurjya Chatterjee
  -- Revision:          1.0
  -- Creation date:     27/10/2015
  -- Calling Entity:    Trigger: XXINV_ITEM_AIUR_TRG1, XXINV_ITEM_XREF_AIUR_TRG1
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0036886
  --          This function will be used for processing all activated triggers
  --          for item/cross-reference creation or update or delete for PRONTO target
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  27/10/2015  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE item_trigger_processor(p_old_item_rec   IN item_rec_type,
		           p_new_item_rec   IN item_rec_type,
		           p_trigger_name   IN VARCHAR2,
		           p_trigger_action IN VARCHAR2) IS
    l_xxssys_event_rec   xxssys_events%ROWTYPE;
    l_organization       NUMBER;
    l_item_relation_type NUMBER;
    l_entity_name        VARCHAR2(10) := 'ITEM';
  
    l_onhand_generated       NUMBER := 0;
    l_last_interface_status  VARCHAR2(1);
    l_item_relation_eligible VARCHAR2(1) := 'Y';
  BEGIN
    xxssys_event_pkg.g_api_name         := 'xxinv_pronto_event_pkg';
    xxssys_event_pkg.g_log_program_unit := 'item_trigger_processor';
  
    xxssys_event_pkg.write_log('1. Enter Item Pronto trigger processor');
  
    IF p_trigger_action = 'DELETE' THEN
      l_organization := nvl(p_old_item_rec.organization_id, 91);
    ELSE
      l_organization       := nvl(p_new_item_rec.organization_id, 91);
      l_item_relation_type := p_new_item_rec.relationship_type_id;
    END IF;
  
    IF p_trigger_action = 'DELETE' THEN
      IF p_old_item_rec.relationship_type_id IS NOT NULL THEN
        l_item_relation_eligible := check_item_relation(p_old_item_rec.relationship_type_id);
      END IF;
    ELSIF p_trigger_action = 'INSERT' THEN
      IF p_new_item_rec.relationship_type_id IS NOT NULL THEN
        l_item_relation_eligible := check_item_relation(p_new_item_rec.relationship_type_id);
      END IF;
    ELSE
      IF p_new_item_rec.relationship_type_id IS NOT NULL THEN
        l_item_relation_eligible := check_item_relation(p_new_item_rec.relationship_type_id);
      END IF;
      IF l_item_relation_eligible <> 'Y' AND
         p_old_item_rec.relationship_type_id IS NOT NULL THEN
        l_item_relation_eligible := check_item_relation(p_old_item_rec.relationship_type_id);
      END IF;
    END IF;
  
    IF l_item_relation_eligible = 'Y' THEN
      IF l_organization = 91 THEN
        l_xxssys_event_rec.target_name     := g_target_name;
        l_xxssys_event_rec.entity_name     := l_entity_name;
        l_xxssys_event_rec.entity_id       := nvl(p_new_item_rec.inventory_item_id,
				  p_old_item_rec.inventory_item_id);
        l_xxssys_event_rec.last_updated_by := nvl(p_new_item_rec.last_updated_by,
				  p_old_item_rec.last_updated_by);
        l_xxssys_event_rec.created_by      := nvl(p_new_item_rec.created_by,
				  p_old_item_rec.created_by);
        l_xxssys_event_rec.event_name      := p_trigger_name || '(' ||
			          p_trigger_action || ')';
      
        xxssys_event_pkg.write_log('2. trigger Action: ' ||
		           p_trigger_action);
        IF p_trigger_action = 'UPDATE' THEN
          /** Start Pronto Integration change */
          xxssys_event_pkg.write_log('3. Compare Result: ' ||
			 compare_old_new_items(p_old_item_rec,
				           p_new_item_rec));
          IF compare_old_new_items(p_old_item_rec, p_new_item_rec) =
	 'FALSE' THEN
	xxssys_event_pkg.write_log('4. Item Eligibility: ' ||
			   check_item_eligibility(p_new_item_rec.customer_order_enabled_flag,
					  p_new_item_rec.status,
					  p_new_item_rec.inventory_item_id));
	IF check_item_eligibility(p_new_item_rec.customer_order_enabled_flag,
			  p_new_item_rec.status,
			  p_new_item_rec.inventory_item_id) = 'Y' THEN
	  l_xxssys_event_rec.active_flag := 'Y';
	  xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'Y');
	
	  /**--- START SECTION for Auto ONHAND event generation ---**/
	  /* The following section checks what is the active_flag of last successful
              interface of this entity. if the last interface flag was:
                N = The item was deactivated last time, so this time in addition to
                    generating item event, we will generate all the onhand events
                    also for the item, org, suninventory and revision combinations
                    for this entity_id
                Y = No furthur actions required, because if last interface was active
                    it means all corresponding onhands have been interfaced already */
	  BEGIN
	    SELECT active_flag
	    INTO   l_last_interface_status
	    FROM   (SELECT nvl(active_flag, 'Y') active_flag,
		       rank() over(PARTITION BY xe1.entity_id, xe1.entity_name, xe1.target_name ORDER BY xe1.event_id DESC) rn
		FROM   xxssys_events xe1
		WHERE  status = 'SUCCESS'
		AND    entity_id = l_xxssys_event_rec.entity_id
		AND    entity_name = l_xxssys_event_rec.entity_name
		AND    target_name = l_xxssys_event_rec.target_name)
	    WHERE  rn = 1;
	  EXCEPTION
	    WHEN no_data_found THEN
	      l_last_interface_status := NULL;
	  END;
	
	  IF l_last_interface_status IS NULL OR
	     l_last_interface_status = 'N' THEN
	    l_onhand_generated := auto_gen_onhand_events(p_new_item_rec.inventory_item_id,
					 p_trigger_name,
					 p_trigger_action,
					 'Y');
	    xxssys_event_pkg.write_log('5. Number of Event Auto generated: ' ||
			       l_onhand_generated);
	  END IF;
	  /**--- END SECTION for Auto ONHAND event generation ---**/
	ELSE
	  l_xxssys_event_rec.active_flag := 'N';
	  IF xxssys_event_pkg.is_sync(l_xxssys_event_rec) = 'TRUE' THEN
	    xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'Y');
	  END IF;
	END IF;
          END IF;
          /** End Pronto Integration change */
        ELSIF p_trigger_action = 'INSERT' THEN
          /** Start Pronto Integration change */
          IF check_item_eligibility(p_new_item_rec.customer_order_enabled_flag,
			p_new_item_rec.status,
			p_new_item_rec.inventory_item_id) = 'Y' THEN
	l_xxssys_event_rec.active_flag := 'Y';
	xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'Y');
          ELSE
	l_xxssys_event_rec.active_flag := 'N';
	IF xxssys_event_pkg.is_sync(l_xxssys_event_rec) = 'TRUE' THEN
	  xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'Y');
	END IF;
          END IF;
          /** End Pronto Integration change */
        ELSIF p_trigger_action = 'DELETE' THEN
          /** Start Pronto Integration change */
          IF check_item_eligibility(NULL,
			NULL,
			p_old_item_rec.inventory_item_id) = 'Y' THEN
	l_xxssys_event_rec.active_flag := 'Y';
	xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'Y');
          ELSE
	l_xxssys_event_rec.active_flag := 'N';
	IF xxssys_event_pkg.is_sync(l_xxssys_event_rec) = 'TRUE' THEN
	  xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'Y');
	END IF;
          END IF;
          /** End Pronto Integration change */
        END IF;
      END IF;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      send_mail('XXINV_PRONTO_EVENT_PKG_ITEM_TO',
	    'XXINV_PRONTO_EVENT_PKG_ITEM_CC',
	    'Product',
	    'The following unexpected exception occurred for Product interface event processor.' ||
	    chr(13) || chr(10) || chr(10) || 'Failed record details: ' ||
	    chr(13) || chr(10) || '  Inventory Item ID: ' ||
	    l_xxssys_event_rec.entity_id || chr(13) || chr(10) ||
	    '  Inventory Org: OMA - Objet Master (IO)' || chr(13) ||
	    chr(10) || '  Error: UNEXPECTED: ' || SQLERRM);
  END item_trigger_processor;

  -- --------------------------------------------------------------------------------------------
  -- Name:              item_onhand_trigger_processor
  -- Create by:         Diptasurjya Chatterjee
  -- Revision:          1.0
  -- Creation date:     26/10/2015
  -- Calling Entity:    Trigger: XXINV_ITEM_ONHAND_AIUR_TRG1
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0036886
  --          This function will be used for processing all activated triggers
  --          for item onhand create/update/delete
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  26/10/2015  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE item_onhand_trigger_processor(p_old_item_rec   IN item_onhand_rec_type,
			      p_new_item_rec   IN item_onhand_rec_type,
			      p_trigger_name   IN VARCHAR2,
			      p_trigger_action IN VARCHAR2) IS
    l_xxssys_event_rec xxssys_events%ROWTYPE;
  
    l_organization NUMBER;
    l_entity_name  VARCHAR2(10) := 'ONHAND';
    l_exists       NUMBER := 0;
  
  BEGIN
    xxssys_event_pkg.g_api_name         := 'xxinv_pronto_event_pkg';
    xxssys_event_pkg.g_log_program_unit := 'item_onhand_trigger_processor';
  
    xxssys_event_pkg.write_log('1. Enter Item Onhand trigger processor');
  
    l_xxssys_event_rec.target_name     := g_target_name;
    l_xxssys_event_rec.entity_name     := l_entity_name;
    l_xxssys_event_rec.entity_id       := nvl(p_new_item_rec.inventory_item_id,
			          p_old_item_rec.inventory_item_id);
    l_xxssys_event_rec.attribute1      := nvl(p_new_item_rec.organization_id,
			          p_old_item_rec.organization_id);
    l_xxssys_event_rec.attribute2      := nvl(p_new_item_rec.subinventory_code,
			          p_old_item_rec.subinventory_code);
    l_xxssys_event_rec.attribute3      := nvl(p_new_item_rec.revision_name,
			          p_old_item_rec.revision_name);
    l_xxssys_event_rec.last_updated_by := nvl(p_new_item_rec.last_updated_by,
			          p_old_item_rec.last_updated_by);
    l_xxssys_event_rec.created_by      := nvl(p_new_item_rec.created_by,
			          p_old_item_rec.created_by);
    l_xxssys_event_rec.event_name      := p_trigger_name || '(' ||
			      p_trigger_action || ')';
  
    IF check_item_eligibility(NULL,
		      NULL,
		      nvl(p_new_item_rec.inventory_item_id,
		          p_old_item_rec.inventory_item_id)) = 'Y' AND
      /* xxobjt_oa2sf_interface_pkg.is_valid_to_sf('SUBINV',
                                                             l_xxssys_event_rec.attribute2 || '|' ||
                                                             l_xxssys_event_rec.attribute1) = 1*/
      
       is_valid_subinventory(l_xxssys_event_rec.attribute2) = 'Y' THEN
      l_xxssys_event_rec.active_flag := 'Y';
      xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'Y');
    END IF;
  
    xxssys_event_pkg.write_log('2. Leave Item Onhand trigger processor');
  EXCEPTION
    WHEN OTHERS THEN
      xxssys_event_pkg.write_log('3. UNEXP_ERROR Item Onhand trigger processor: ' ||
		         SQLERRM);
      send_mail('XXINV_PRONTO_EVENT_PKG_ONHAND_TO',
	    'XXINV_PRONTO_EVENT_PKG_ONHAND_CC',
	    'Item Onhand',
	    'The following unexpected exception occurred for Item Onhand interface event processor.' ||
	    chr(13) || chr(10) || chr(10) || 'Failed record details: ' ||
	    chr(13) || chr(10) || '  Item ID           : ' ||
	    l_xxssys_event_rec.entity_id || chr(10) ||
	    '  Org ID            : ' || l_xxssys_event_rec.attribute1 ||
	    chr(10) || '  Subinventory Code : ' ||
	    l_xxssys_event_rec.attribute2 || chr(10) ||
	    '  Item Revision     : ' || l_xxssys_event_rec.attribute3 ||
	    chr(10) || '  Error: UNEXPECTED : ' || SQLERRM);
  END item_onhand_trigger_processor;

  -- --------------------------------------------------------------------------------------------
  -- Name:              item_onhand_trigger_processor
  -- Create by:         Diptasurjya Chatterjee
  -- Revision:          1.0
  -- Creation date:     26/10/2015
  -- Calling Entity:    Trigger: XXINV_ITEM_ONHAND_AIUR_TRG1
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0036886
  --          This function will be used for processing all activated triggers
  --          for item onhand create/update/delete
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  26/10/2015  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE item_subinv_trigger_processor(p_old_onhand_rec IN item_onhand_rec_type,
			      p_new_onhand_rec IN item_onhand_rec_type,
			      p_trigger_name   IN VARCHAR2,
			      p_trigger_action IN VARCHAR2) IS
    l_xxssys_event_rec xxssys_events%ROWTYPE;
  
    l_organization NUMBER;
    l_entity_name  VARCHAR2(10) := 'ONHAND';
    l_exists       NUMBER := 0;
  
    l_old_subinv_valid VARCHAR2(1);
    l_new_subinv_valid VARCHAR2(1);
  BEGIN
    xxssys_event_pkg.g_api_name         := 'xxinv_pronto_event_pkg';
    xxssys_event_pkg.g_log_program_unit := 'item_subinv_trigger_processor';
  
    xxssys_event_pkg.write_log('1. Enter Item Onhand trigger processor for subinventory change');
  
    l_old_subinv_valid := check_subinv_eligibility(p_old_onhand_rec.subinventory_code,
				   p_old_onhand_rec.subinv_disable_date,
				   p_old_onhand_rec.subinv_attribute11);
  
    l_new_subinv_valid := check_subinv_eligibility(p_new_onhand_rec.subinventory_code,
				   p_new_onhand_rec.subinv_disable_date,
				   p_new_onhand_rec.subinv_attribute11);
  
    IF l_old_subinv_valid <> l_new_subinv_valid THEN
      FOR onhand_rec IN (SELECT DISTINCT inventory_item_id,
			     organization_id,
			     subinventory_code,
			     revision
		 FROM   mtl_onhand_quantities_detail
		 WHERE  subinventory_code =
		        p_new_onhand_rec.subinventory_code
		 AND    organization_id =
		        p_new_onhand_rec.organization_id
		 AND    check_item_eligibility(NULL,
				       NULL,
				       inventory_item_id) = 'Y') LOOP
        l_xxssys_event_rec.target_name     := g_target_name;
        l_xxssys_event_rec.entity_name     := l_entity_name;
        l_xxssys_event_rec.entity_id       := onhand_rec.inventory_item_id;
        l_xxssys_event_rec.attribute1      := onhand_rec.organization_id;
        l_xxssys_event_rec.attribute2      := onhand_rec.subinventory_code;
        l_xxssys_event_rec.attribute3      := onhand_rec.revision;
        l_xxssys_event_rec.last_updated_by := p_new_onhand_rec.last_updated_by;
        l_xxssys_event_rec.created_by      := p_new_onhand_rec.created_by;
        l_xxssys_event_rec.event_name      := p_trigger_name || '(' ||
			          p_trigger_action || ')';
        l_xxssys_event_rec.active_flag     := 'Y';
      
        xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'Y');
      END LOOP;
    END IF;
  
    xxssys_event_pkg.write_log('2. Leave Item Onhand trigger processor for subinventory change');
  EXCEPTION
    WHEN OTHERS THEN
      xxssys_event_pkg.write_log('3. UNEXP_ERROR Item Onhand trigger processor: ' ||
		         SQLERRM);
      send_mail('XXINV_PRONTO_EVENT_PKG_ONHAND_TO',
	    'XXINV_PRONTO_EVENT_PKG_ONHAND_CC',
	    'Item Onhand',
	    'The following unexpected exception occurred for Item Onhand interface event processor due to change in subinventory ' ||
	    chr(13) || chr(10) || chr(10) || 'Failed record details: ' ||
	    chr(13) || chr(10) || '  Org ID            : ' ||
	    l_xxssys_event_rec.attribute1 || chr(10) ||
	    '  Subinventory Code : ' || l_xxssys_event_rec.attribute2 ||
	    chr(10) || '  Error: UNEXPECTED : ' || SQLERRM);
  END item_subinv_trigger_processor;

  -- --------------------------------------------------------------------------------------------
  -- Name:              is_valid_subinventory
  -- Create by:         yuval tal
  -- Revision:          1.0
  -- Creation date:     23/11/2015
  -- Calling Entity:    
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0036886
  --          This function will be used for checking  subinventory if valid  for pronto sync  
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  23/11/2015  yuval tal                            Initial Build
  -- --------------------------------------------------------------------------------------------
  FUNCTION is_valid_subinventory(p_sub_inventory_code VARCHAR2)
    RETURN VARCHAR2 IS
  
  BEGIN
  
    IF p_sub_inventory_code LIKE '%CAR' THEN
      RETURN 'Y';
    ELSE
      RETURN 'N';
    END IF;
  
  END;

END xxinv_pronto_event_pkg;
/
