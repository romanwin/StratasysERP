CREATE OR REPLACE PACKAGE BODY xxcst_upload_cost_for_type_pkg IS
  --------------------------------------------------------------------
  --  name:               xxcst_upload_cost_for_type_pkg
  --  create by:         
  --  Revision:           1.0 
  --  creation date:      
  --------------------------------------------------------------------
  --  purpose:             
  --------------------------------------------------------------------
  --  ver     date        name            desc
  --  1.0     18.08.2013  Vitaly          CR 870 std cost - change hard-coded organization; 
  --                                           Average cost_type_id=2 was replaced with fnd_profile.value('XX_COST_TYPE')
  --------------------------------------------------------------------  
  PROCEDURE process_cost(errbuf            OUT VARCHAR2,
                         retcode           OUT NUMBER,
                         p_cost_type_id    NUMBER,
                         p_organization_id NUMBER) IS
  
    CURSOR csr_items_cost(p_orig_cost_type_id NUMBER) IS
      SELECT br.resource_code,
             br.resource_id,
             cicd.inventory_item_id,
             cicd.organization_id,
             cicd.cost_type_id,
             cicd.item_cost usage_rate_or_amount,
             cce.cost_element_id,
             cic.based_on_rollup_flag,
             cicd.basis_type,
             CASE
               WHEN ((SELECT msi1.planning_make_buy_code
                        FROM mtl_system_items_b msi1
                       WHERE msi1.organization_id = 734 --IRK ------- 92--WRI
                         AND msi1.inventory_item_id = msi.inventory_item_id) = 1) THEN
                1
               ELSE
                msi.planning_make_buy_code
             END planning_make_buy_code
        FROM cst_item_cost_details cicd,
             cst_item_costs        cic,
             cst_activities        ca,
             bom_resources         br,
             cst_cost_elements     cce,
             mfg_lookups           lu1,
             mfg_lookups           lu2,
             mfg_lookups           lu3,
             mtl_system_items_b    msi
       WHERE ca.activity_id(+) = cicd.activity_id
         AND nvl(ca.organization_id(+), cicd.organization_id) =
             cicd.organization_id
         AND br.resource_id(+) = cicd.resource_id
         AND cce.cost_element_id = cicd.cost_element_id
         AND lu1.lookup_type = 'CST_BASIS'
         AND lu1.lookup_code = cicd.basis_type
         AND lu2.lookup_type = 'CST_SOURCE_TYPE'
         AND lu2.lookup_code = cicd.rollup_source_type
         AND lu3.lookup_type = 'CST_LEVEL'
         AND lu3.lookup_code = cicd.level_type
         AND cicd.organization_id = cic.organization_id
         AND cicd.inventory_item_id = cic.inventory_item_id
         AND cicd.cost_type_id = cic.cost_type_id
         AND msi.organization_id = cic.organization_id
         AND msi.inventory_item_id = cic.inventory_item_id
         AND cicd.cost_element_id = 1
         AND cic.cost_type_id = p_orig_cost_type_id
         AND cic.organization_id = p_organization_id;
  
    CURSOR c_cost_type(l_cost_type_id IN NUMBER) IS
      SELECT cost_type
        FROM cst_cost_types
       WHERE nvl(organization_id, p_organization_id) = p_organization_id
         AND nvl(disable_date, SYSDATE + 1) > SYSDATE
         AND frozen_standard_flag <> 1
         AND cost_type_id = l_cost_type_id;
  
    cur_item_cost          csr_items_cost%ROWTYPE;
    l_orig_cost_type_id    NUMBER;
    l_cost_organization_id NUMBER;
    l_group_id             NUMBER;
    l_make_value           NUMBER;
    l_counter              NUMBER := 0;
    l_cost_type            VARCHAR2(100);
    x_bool                 BOOLEAN;
    x_request_id           NUMBER := fnd_global.conc_request_id;
    x_req_id               NUMBER;
    x_phase                VARCHAR2(100);
    x_status               VARCHAR2(100);
    x_dev_phase            VARCHAR2(100);
    x_dev_status           VARCHAR2(100);
    x_return_bool          BOOLEAN;
    x_message              VARCHAR2(100);
  
  BEGIN
  
    x_bool   := fnd_request.set_print_options(NULL, NULL, 0, TRUE, 'N');
    x_req_id := fnd_request.submit_request(application => 'BOM',
                                           program     => 'CSTCSPCT',
                                           argument1   => p_organization_id, --Organization Id
                                           argument2   => p_cost_type_id, --Cost Type
                                           argument3   => '6', --Purge Option
                                           argument4   => fnd_global.user_id --Last updated by
                                           );
  
    COMMIT;
  
    IF x_req_id = 0 THEN
      -- Failure
      errbuf := fnd_message.get;
      fnd_file.put_line(fnd_file.log,
                        'ERROR submitting CSTCSPCT:' || errbuf);
      x_bool := fnd_concurrent.set_completion_status('ERROR',
                                                     substrb(errbuf, 1, 60));
    ELSE
      fnd_file.put_line(fnd_file.log,
                        'Concurrent Message# ' || to_char(x_req_id) ||
                        ' CSTCSPCT submitted.');
    
    END IF;
  
    COMMIT;
  
    x_return_bool := fnd_concurrent.wait_for_request(x_req_id,
                                                     5,
                                                     86400,
                                                     x_phase,
                                                     x_status,
                                                     x_dev_phase,
                                                     x_dev_status,
                                                     x_message);
  
    NULL;
  
    SELECT cost_organization_id
      INTO l_cost_organization_id
      FROM mtl_parameters mp
     WHERE mp.organization_id = p_organization_id;
  
    IF p_organization_id <> l_cost_organization_id THEN
      retcode := 1;
      fnd_file.put_line(fnd_file.log,
                        (fnd_message.get_string('BOM', 'CST_NOT_COSTINGORG')));
      RETURN;
    END IF;
  
    SELECT cost_type_id
      INTO l_orig_cost_type_id
      FROM cst_cost_types
     WHERE ---cost_type = 'Average';
     cost_type_id = fnd_profile.value('XX_COST_TYPE');
  
    SELECT lookup_code
      INTO l_make_value
      FROM fnd_lookup_values_vl
     WHERE lookup_type = 'MTL_PLANNING_MAKE_BUY'
       AND meaning = 'Make';
  
    SELECT cst_lists_s.nextval INTO l_group_id FROM dual;
  
    FOR cur_item_cost IN csr_items_cost(l_orig_cost_type_id) LOOP
    
      l_counter := l_counter + 1;
    
      INSERT INTO cst_item_cst_dtls_interface
        (group_id,
         inventory_item_id,
         organization_id,
         resource_id,
         cost_type_id,
         cost_element_id,
         last_update_date,
         last_updated_by,
         creation_date,
         created_by,
         last_update_login,
         process_flag,
         usage_rate_or_amount,
         based_on_rollup_flag,
         basis_type,
         group_description)
      VALUES
        (l_group_id,
         cur_item_cost.inventory_item_id,
         cur_item_cost.organization_id,
         cur_item_cost.resource_id,
         p_cost_type_id,
         cur_item_cost.cost_element_id,
         SYSDATE,
         fnd_global.user_id,
         SYSDATE,
         fnd_global.user_id,
         fnd_global.login_id,
         '1',
         decode(cur_item_cost.planning_make_buy_code,
                l_make_value,
                0,
                cur_item_cost.usage_rate_or_amount),
         cur_item_cost.based_on_rollup_flag,
         cur_item_cost.basis_type,
         'load ' || p_cost_type_id);
    
      IF MOD(l_counter, 1000) = 0 THEN
        COMMIT;
      END IF;
    
    END LOOP;
  
    COMMIT;
  
    OPEN c_cost_type(p_cost_type_id);
    FETCH c_cost_type
      INTO l_cost_type;
    CLOSE c_cost_type;
  
    x_bool   := fnd_request.set_print_options(NULL, NULL, 0, TRUE, 'N');
    x_req_id := fnd_request.submit_request(application => 'BOM',
                                           program     => 'CSTPCIMP',
                                           description => NULL,
                                           start_time  => NULL,
                                           sub_request => FALSE,
                                           argument1   => '4',
                                           argument2   => '1',
                                           argument3   => '1',
                                           argument4   => '1',
                                           argument5   => l_group_id,
                                           argument6   => l_cost_type,
                                           argument7   => '1');
  
    COMMIT;
  
    IF x_req_id = 0 THEN
      -- Failure
      errbuf := fnd_message.get;
      fnd_file.put_line(fnd_file.log,
                        'ERROR submitting CSTPCIMP1:' || errbuf);
      x_bool := fnd_concurrent.set_completion_status('ERROR',
                                                     substrb(errbuf, 1, 60));
    ELSE
      fnd_file.put_line(fnd_file.log,
                        'Concurrent Message# ' || to_char(x_req_id) ||
                        ' CSTPCIMP submitted.');
    
    END IF;
  
    COMMIT;
  
    x_return_bool := fnd_concurrent.wait_for_request(x_req_id,
                                                     5,
                                                     86400,
                                                     x_phase,
                                                     x_status,
                                                     x_dev_phase,
                                                     x_dev_status,
                                                     x_message);
  
    NULL;
  
  END process_cost;

END xxcst_upload_cost_for_type_pkg;
/
