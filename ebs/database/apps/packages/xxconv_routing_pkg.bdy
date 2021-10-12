CREATE OR REPLACE PACKAGE BODY xxconv_routing_pkg IS

  PROCEDURE insert_interface_routing(errbuf           OUT VARCHAR2,
                                     retcode          OUT VARCHAR2,
                                     p_reference_flag IN VARCHAR2) IS
  
    CURSOR cr_routing IS
      SELECT *
        FROM xxobjt_conv_routing r
       WHERE r.error_code IS NULL
      --AND r.assembly_item_number not in ('ASY-02300','ASY-02335','ASY-03300','ASY-03310')
       ORDER BY assembly_item_number, comp_subinventory, operation_seq_num;
  
    v_step     VARCHAR2(100);
    v_user_id  fnd_user.user_id%TYPE;
    v_error    VARCHAR2(1000);
    v_assembly VARCHAR2(50) := '@@';
    v_sequence NUMBER := -1;
    --v_w_resource_id      bom_resources.resource_id%TYPE;
    --v_oper_route         NUMBER;
    --v_oper_seq           NUMBER;
    v_res_seq_num NUMBER;
    --v_sch_seq_num        NUMBER;
    --v_counter            NUMBER := 0;
    --v_route_exist        VARCHAR2(1);
    --v_oper_exist         VARCHAR2(1);
    --v_res_exist          VARCHAR2(1);
    v_setup_scheduled NUMBER(1);
    v_basis_type      NUMBER;
    v_organization_id NUMBER;
    v_status          VARCHAR2(1) := 'S';
  
    v_department_id    NUMBER;
    v_subinventory     VARCHAR2(10);
    v_inv_loc_id       NUMBER;
    v_resource_id      NUMBER;
    v_assembly_item_id mtl_system_items.inventory_item_id%TYPE;
    --v_item_type          mtl_system_items.item_type%TYPE;
    --l_basis_temp         NUMBER(1);
    --v_setup_time         NUMBER;
    --v_setup_assigned     NUMBER;
    v_cst_code        NUMBER(1);
    v_file_department VARCHAR2(10);
    --v_file_Charge_type   NUMBER(1);       
    stop_processing EXCEPTION;
  
  BEGIN
    v_step  := 'Step 0';
    errbuf  := NULL;
    retcode := '0'; ---Success
  
    IF p_reference_flag IS NULL THEN
      v_error := 'Missing parameter p_reference_flag';
      RAISE stop_processing;
    END IF;
    IF p_reference_flag NOT IN ('Y', 'N') THEN
      v_error := 'Invalid value for parameter p_reference_flag=''' ||
                 p_reference_flag || ''' --- it should be ''Y'' or ''N''';
      RAISE stop_processing;
    END IF;
    v_step := 'Step 10';
    BEGIN
      SELECT user_id
        INTO v_user_id
        FROM fnd_user
       WHERE user_name = 'CONVERSION';
    EXCEPTION
      WHEN no_data_found THEN
        v_user_id := NULL;
    END;
  
    FOR i IN cr_routing LOOP
    
      IF v_status = 'S' OR
         (v_status = 'E' AND v_assembly <> i.assembly_item_number) THEN
        --in case operation/resource error
        v_step   := 'Step 20';
        v_status := 'S'; --In case v_status = 'E' And v_assembly <> i.assembly_item_number
        v_error  := NULL;
        ------------
        BEGIN
          SELECT organization_id
            INTO v_organization_id
            FROM mtl_parameters
           WHERE organization_code = i.organization;
        EXCEPTION
          WHEN OTHERS THEN
            v_error  := 'Org Id Does Not Exist';
            v_status := 'E';
        END;
        ------------
        v_step := 'Step 30';
        BEGIN
          SELECT msi.inventory_item_id
            INTO v_assembly_item_id
            FROM mtl_system_items_b msi
           WHERE msi.organization_id = v_organization_id
             AND msi.segment1 = i.assembly_item_number;
        EXCEPTION
          WHEN no_data_found THEN
            v_assembly_item_id := NULL;
            v_status           := 'E';
            IF v_error IS NULL THEN
              v_error := 'Assembly Item: ' || i.assembly_item_number ||
                         ' Not Exists In The System';
            ELSE
              v_error := v_error || chr(10) || 'Assembly Item: ' ||
                         i.assembly_item_number ||
                         ' Not Exists In The System';
            END IF;
        END;
        v_step := 'Step 40';
        -- Check the Resource existance
        BEGIN
          IF i.resource_code IS NOT NULL THEN
            --NEW Noam Segal-09/09/13
            SELECT br.resource_id, br.cost_code_type --CHECK OSP(4)
              INTO v_resource_id, v_cst_code
              FROM bom_resources br
             WHERE br.organization_id = v_organization_id
               AND br.resource_code = i.resource_code;
            /*EXCEPTION
            WHEN no_data_found THEN
              v_resource_id := NULL;
              v_status      := 'E';
              IF v_error IS NULL THEN
                v_error := 'Resource: ' || i.resource_code ||
                           ' Does Not Exist';
              ELSE
                v_error := v_error || chr(10) || 'Resource: ' ||
                           i.resource_code || ' Does Not Exist';*/
          END IF;
        END;
        ------------
        /*BEGIN
          SELECT MAX(bd.department_id)
            INTO v_department_id
            FROM bom_department_resources bd
           WHERE resource_id = v_resource_id;
        EXCEPTION
          WHEN no_data_found THEN
            v_department_id := NULL;
            v_status        := 'E';
            IF v_error IS NULL THEN
              v_error := 'Department Does Not Exist In Department Resource: ' ||
                         v_resource_id;
            ELSE
              v_error := v_error || chr(10) ||
                         'Department Does Not Exist In Department Resource: ' ||
                         v_resource_id;
            END IF;
        END;*/
        ------------  
        /*IF v_department_id IS NULL THEN
          v_status := 'E';
          IF v_error IS NULL THEN
            v_error := 'Department Does Not Exist In Department Resource: ' ||
                       v_resource_id;
          ELSE
            v_error := v_error || chr(10) ||
                       'Department Does Not Exist In Department Resource: ' ||
                       v_resource_id;
          END IF;
        END IF;*/
        ------------
        /*BEGIN
          SELECT bd.department_code
            INTO v_file_department
            FROM bom_departments bd
           WHERE department_id = v_department_id;
        EXCEPTION
          WHEN no_data_found THEN
            v_file_department := NULL;
            v_status          := 'E';
            IF v_error IS NULL THEN
              v_error := 'Department: ' || v_department_id ||
                         ' Does Not Exist';
            ELSE
              v_error := v_error || chr(10) || 'Department: ' ||
                         v_department_id || ' Does Not Exist';
            END IF;
        END;*/
        ------------
        IF i.comp_subinventory IS NOT NULL THEN
          v_step := 'Step 50';
          BEGIN
            SELECT msi.secondary_inventory_name
              INTO v_subinventory
              FROM mtl_secondary_inventories msi
             WHERE msi.organization_id = v_organization_id
               AND msi.secondary_inventory_name = i.comp_subinventory;
          EXCEPTION
            WHEN no_data_found THEN
              v_subinventory := NULL;
              v_status       := 'E';
              IF v_error IS NULL THEN
                v_error := 'Subinventory: ' || i.comp_subinventory ||
                           ' Does Not Exist';
              ELSE
                v_error := v_error || chr(10) || 'Subinventory: ' ||
                           i.comp_subinventory || ' Does Not Exist';
              END IF;
          END;
        
          IF i.comp_locator IS NOT NULL THEN
            v_step := 'Step 60';
            BEGIN
              SELECT inventory_location_id
                INTO v_inv_loc_id
                FROM mtl_item_locations mil
               WHERE mil.organization_id = v_organization_id
                 AND (mil.end_date_active IS NULL OR
                     mil.end_date_active <= SYSDATE)
                 AND mil.subinventory_code = v_subinventory
                 AND mil.segment1 || '.' || mil.segment2 || '.' ||
                     mil.segment3 || '.' || mil.segment4 = i.comp_locator
                 AND rownum < 2;
            EXCEPTION
              WHEN no_data_found THEN
                v_inv_loc_id := NULL;
                v_status     := 'E';
                IF v_error IS NULL THEN
                  v_error := 'Locator: ' || i.comp_locator ||
                             ' Does Not Exist';
                ELSE
                  v_error := v_error || chr(10) || 'Locatoe: ' ||
                             i.comp_locator || ' Does Not Exist';
                END IF;
            END;
          ELSIF v_assembly = i.assembly_item_number THEN
            v_inv_loc_id := NULL;
          ELSE
            IF v_error IS NULL THEN
              v_error := 'Locator: ' || i.comp_locator || ' Does Not Exist';
            ELSE
              v_error := v_error || chr(10) || 'Locatoe: ' ||
                         i.comp_locator || ' Does Not Exist';
            END IF;
          END IF;
        
        ELSIF v_assembly = i.assembly_item_number THEN
          v_subinventory := NULL;
        ELSE
          IF v_error IS NULL THEN
            v_error := 'Subinventory: ' || i.comp_subinventory ||
                       ' Does Not Exist';
          ELSE
            v_error := v_error || chr(10) || 'Subinventory: ' ||
                       i.comp_subinventory || ' Does Not Exist';
          END IF;
        END IF;
      
        IF v_assembly <> i.assembly_item_number THEN
          v_sequence := -1;
        END IF;
      
        IF v_status = 'S' THEN
          v_step := 'Step 100';
          --  IF v_assembly <> i.assembly_item_number THEN
          INSERT INTO bom_op_routings_interface
            (assembly_item_number,
             assembly_item_id,
             organization_id,
             routing_type,
             process_flag,
             completion_subinventory,
             completion_locator_id,
             last_update_date,
             last_updated_by,
             creation_date,
             created_by,
             transaction_type)
          VALUES
            (i.assembly_item_number,
             v_assembly_item_id,
             v_organization_id,
             i.routing_type,
             1,
             i.comp_subinventory,
             v_inv_loc_id,
             SYSDATE,
             v_user_id,
             i.creation_date,
             v_user_id,
             'CREATE');
          v_assembly := i.assembly_item_number;
        END IF; --Routing
      
        IF v_sequence <> i.operation_seq_num THEN
          v_res_seq_num := 10;
          v_step        := 'Step 200';
          INSERT INTO bom_op_sequences_interface
            (process_flag,
             last_update_date,
             last_updated_by,
             creation_date,
             created_by,
             department_id,
             department_code,
             minimum_transfer_quantity,
             count_point_type,
             effectivity_date,
             backflush_flag,
             assembly_item_number,
             assembly_item_id,
             option_dependent_flag,
             organization_id,
             operation_seq_num,
             operation_code,
             reference_flag,
             transaction_type)
          VALUES
            (1,
             SYSDATE,
             v_user_id,
             i.creation_date,
             v_user_id,
             v_department_id,
             i.department_code,
             i.min_transfer_qty,
             i.count_point_type,
             SYSDATE,
             i.backflush_flag,
             i.assembly_item_number,
             v_assembly_item_id,
             i.option_dep_flag,
             v_organization_id,
             i.operation_seq_num,
             i.operation_description,
             decode(p_reference_flag, 'Y', 1, 'N', 2), -----2, ---reference_flag --according to Noam Segal request 12/09/2013
             'CREATE');
          v_sequence := i.operation_seq_num;
        ELSE
          v_res_seq_num := v_res_seq_num + 10;
        END IF; --Operation       
      
        IF upper(i.basys_type) = 'ITEM' THEN
          v_basis_type := 1;
        ELSIF upper(i.basys_type) = 'LOT' THEN
          v_basis_type := 2;
        END IF;
      
        IF i.schedule_flag = 'Y' THEN
          v_setup_scheduled := 1;
        ELSE
          v_setup_scheduled := 2;
        END IF;
        v_step := 'Step 300';
        INSERT INTO bom_op_resources_interface
          (process_flag,
           resource_id,
           standard_rate_flag,
           assigned_units,
           usage_rate_or_amount,
           usage_rate_or_amount_inverse,
           basis_type,
           schedule_flag,
           last_update_date,
           last_updated_by,
           creation_date,
           created_by,
           -- autocharge_type,
           assembly_item_id,
           assembly_item_number,
           organization_id,
           transaction_type,
           effectivity_date,
           resource_seq_num,
           operation_seq_num,
           schedule_seq_num)
        VALUES
          (1,
           v_resource_id,
           i.standard_rate_flag,
           i.assigned_unit, --Machine assigned units=1
           i.usage_rate_or_amount,
           i.usage_rate_or_amount_in,
           v_basis_type,
           v_setup_scheduled,
           SYSDATE,
           v_user_id,
           i.creation_date,
           v_user_id,
           --  i.autocharge_type,
           v_assembly_item_id,
           i.assembly_item_number,
           v_organization_id,
           'CREATE',
           SYSDATE,
           v_res_seq_num, --v_file_resource_seq,
           i.operation_seq_num,
           i.operation_seq_num --v_file_sched_seq
           );
        v_step := 'Step 400';
        UPDATE xxobjt_conv_routing a
           SET a.error_code = 'S'
         WHERE a.assembly_item_number = i.assembly_item_number;
        v_assembly := i.assembly_item_number;
      ELSE
        v_step := 'Step 500';
        ROLLBACK;
        UPDATE xxobjt_conv_routing a
           SET a.error_code = 'E', a.error_message = v_error
         WHERE a.assembly_item_number = i.assembly_item_number;
        v_assembly := i.assembly_item_number;
        COMMIT;
      
      END IF;
    
      /* Else
      Rollback;
      Update XXOBJT_CONV_ROUTING a
         Set a.error_code = 'E', a.error_message = v_error
       Where a.assembly_item_number = i.assembly_item_number;
      v_assembly := i.assembly_item_number;*/
      COMMIT;
      --END IF;
    END LOOP;
  EXCEPTION
    WHEN stop_processing THEN
      errbuf  := '2';
      retcode := v_error;
    WHEN OTHERS THEN
      errbuf  := '2';
      retcode := 'Unexpected Error - Insert_Interface_routing ' || v_step ||
                 ' - ' || SQLERRM;
  END insert_interface_routing;

  --------------------------------------------------------------------
  --  customization code: CUST 1081
  --  name:               get_transaction_type
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0 $
  --  creation date:      18/10/2007
  --------------------------------------------------------------------
  --  input:              p_entity      - the entity i want to return
  --                                      ID will return the cust_trx_type_id
  --                                      NAME will return name (transaction_name
  --                      p_org_id      - operating unit                 
  --  return:             varchar2      - if entity = ID return cust_trx_type_id
  --                                      if entity = NAME return name (transaction_name)
  --------------------------------------------------------------------
  --  process:            cust 1081 
  --                      Contract - Defaul values.
  --                      get transaction_type name and id by operating unit                                                                               
  --------------------------------------------------------------------
  --  ver   date          name             desc
  --  1.0   18/10/2007    Dalit A. Raviv   initial build 
  --------------------------------------------------------------------  

  --------------------------------------------------------------------
  --  customization code: CUST215
  --  name:               ins_LTF_operation_resource - convertion tead time
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0 
  --  creation date:      20/12/2009
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   20/12/2009    Dalit A. Raviv  initial revision   
  --  1.1   18.08.2013    Vitaly          CR 870 std cost - change hard-coded organization
  PROCEDURE ins_ltf_operation_resource(errbuf  OUT VARCHAR2,
                                       retcode OUT VARCHAR2) IS
  
    CURSOR item_population_c IS
    
    -- get all "-S" items from organization 735 --(IPK) that have routing
      SELECT msi.segment1,
             rt.routing_sequence_id,
             rt.assembly_item_id,
             rt.organization_id
        FROM mtl_system_items_b msi, bom_operational_routings rt
       WHERE msi.segment1 LIKE '%-S'
         AND msi.organization_id = 735 --IPK  ------ 90-- WPI
         AND msi.inventory_item_id = rt.assembly_item_id
         AND msi.organization_id = rt.organization_id
      --AND    msi.segment1             IN ('1B25658-S', '1P25612-S', 'KIT-04032-S','ASY-04289-S','1P25660-S') -- for debug
       ORDER BY msi.segment1;
  
    l_user_id                NUMBER := NULL;
    l_max_seq                NUMBER := NULL;
    l_opertation_sequence_id NUMBER := NULL;
    l_count_resources        NUMBER := NULL;
    l_resource_id            NUMBER := NULL;
    l_resource_type          NUMBER := NULL;
    l_default_basis_type     NUMBER := NULL;
    l_autocharge_type        NUMBER := NULL;
  
  BEGIN
    -- get conversion user id
    BEGIN
      SELECT user_id
        INTO l_user_id
        FROM fnd_user
       WHERE user_name = 'CONVERSION';
    EXCEPTION
      WHEN no_data_found THEN
        l_user_id := NULL;
    END;
    FOR item_population_r IN item_population_c LOOP
      -- get max seq number for routing_sequence_id (assembly item)
      SELECT nvl(MAX(op.operation_seq_num), 0)
        INTO l_max_seq
        FROM bom_operation_sequences op
       WHERE op.routing_sequence_id = item_population_r.routing_sequence_id;
    
      IF l_max_seq = 0 THEN
        fnd_file.put_line(fnd_file.log,
                          '-------------------------------------------------');
        fnd_file.put_line(fnd_file.log,
                          '-- Item - ' || item_population_r.segment1 ||
                          ' Have no operation sequences' || chr(10));
      ELSE
      
        -- get last operation_sequence_id of the routing
        SELECT op.operation_sequence_id
          INTO l_opertation_sequence_id
          FROM bom_operation_sequences op
         WHERE op.routing_sequence_id =
               item_population_r.routing_sequence_id
           AND op.operation_seq_num = l_max_seq;
      
        -- check that this item have routing -> operation_sequence -> operation resource
        -- if count = 0 there is no resource for this item -> create new row
        -- if count <> 0 then just notify to log.
        SELECT COUNT(1)
          INTO l_count_resources
          FROM bom_operation_resources rs, bom_resources r
         WHERE rs.operation_sequence_id = l_opertation_sequence_id
           AND r.resource_code = 'LTF'
           AND r.organization_id = 735 --IPK  ------ 90-- WPI
           AND rs.resource_id = r.resource_id;
        --AND    rs.resource_id         = 1001;
      
        SELECT r.resource_id,
               r.resource_type,
               r.default_basis_type,
               r.autocharge_type
          INTO l_resource_id,
               l_resource_type,
               l_default_basis_type,
               l_autocharge_type
          FROM bom_resources r
         WHERE r.resource_code = 'LTF'
           AND r.organization_id = 735; --IPK  ------ 90-- WPI
      
        IF l_count_resources <> 0 THEN
          fnd_file.put_line(fnd_file.log,
                            '-------------------------------------------------');
          fnd_file.put_line(fnd_file.log,
                            '-- Item - ' || item_population_r.segment1 ||
                            ' Have LTF resource' || chr(10));
        ELSE
          BEGIN
            /* 
            The required fields to create a resource using the BOM_OP_RESOURCES_INTERFACE are:
            PROCESS_FLAG            The PROCESS_FLAG needs to be 1 for pending.
            RESOURCE_SEQ_NUM
            RESOURCE_ID
            OPERATION_SEQUENCE_ID
            TRANSACTION_TYPE        The TRANSACTION_TYPE needs to be 'insert'. 'create'.
            
            The ROUTING_SEQUENCE_ID in the BOM_OP_ROUTINGS_INTERFACE table is the same in the
            BOM_OP_RESOURCES_INTERFACE and the BOM_OP_SEQUENCES_INTERFACE tables.
            
            The OPERATION_SEQUENCE_ID in the BOM_OP_SEQUENCES_INTERFACE table is the same in the
            BOM_OP_RESOURCES_INTERFACE table.
            */
            INSERT INTO bom_op_resources_interface
              (process_flag, -- 1 The PROCESS_FLAG needs to be 1 for pending
               resource_id, -- l_resource_id
               --standard_rate_flag,  -- ??????
               assigned_units, -- 1
               usage_rate_or_amount, -- 16
               --usage_rate_or_amount_inverse,-- 16
               basis_type, -- l_default_basis_type
               schedule_flag, -- Y = 1
               last_update_date, -- sysdate
               last_updated_by, -- l_user_id
               creation_date, -- sysdate
               created_by, -- l_user_id
               assembly_item_id, -- item_population_r.assembly_item_id
               assembly_item_number, -- item_population_r.segment1
               organization_id, -- 735 --IPK  ----------- 90-- WPI
               transaction_type, -- CREATE   
               effectivity_date, -- sysdate
               resource_seq_num, -- 5
               operation_seq_num, -- l_max_seq
               schedule_seq_num, -- l_max_seq
               autocharge_type, -- l_autocharge_type
               resource_code, -- LTF
               operation_sequence_id)
            VALUES
              (1, -- Dalit process_flag
               l_resource_id, -- Dalit resource_id
               --i.standard_rate_flag,
               1, -- assigned_units
               16, -- usage_rate_or_amount
               --16,                      -- usage_rate_or_amount_in
               l_default_basis_type, -- basis_type
               1, -- Schedule Flag 1 = Y
               SYSDATE, -- 
               l_user_id, -- 
               SYSDATE, -- 
               l_user_id, -- 
               item_population_r.assembly_item_id, -- assembly_item_id
               item_population_r.segment1, -- Item Number
               735, --IPK  ------ 90-- WPI      -- organization_id 
               'CREATE', -- transaction_type
               SYSDATE, -- effectivity_date
               5, -- resource_seq_num 
               l_max_seq, -- operation_seq_num
               l_max_seq, -- schedule_seq_num
               l_autocharge_type, -- autocharge_type
               'LTF',
               l_opertation_sequence_id);
          
            COMMIT;
          EXCEPTION
            WHEN OTHERS THEN
              ROLLBACK;
              fnd_file.put_line(fnd_file.log,
                                '-------------------------------------------------');
              fnd_file.put_line(fnd_file.log,
                                '-- Item - ' || item_population_r.segment1 ||
                                ' Problem to insert row - ' || SQLERRM ||
                                chr(10));
              -- log
          END;
        END IF; -- have bom_operation_resources
      END IF; -- max bom_operation_sequences
    END LOOP; -- item_population_r
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'General exception - XXCONV_ROUTING_PKG.ins_LTF_operation_resource - ' ||
                 SQLERRM;
      retcode := 1;
  END ins_ltf_operation_resource;

END xxconv_routing_pkg;
/
