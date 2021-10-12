CREATE OR REPLACE PACKAGE BODY xxconv_il_bom_pkg IS
  -- Purpose :
  -- Author  :
  -- Created :
  -- Purpose :
  ----------------------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  --------------------------------------------------
  --   1.1    23.06.2013  Vitaly        copy_bom added for CR812
  --   1.2    18.08.2013  Vitaly        CR 870 std cost - change hard-coded organization
  --   2.0   20-02-2018    R.W.         CHG0041937 to procedure copy_bom added parametre
  --                                    p_copy_subinventory 
  ----------------------------------------------------------------------------------------

  auto_spl_file utl_file.file_type;

  PROCEDURE bom_org_assignment(errbuf OUT VARCHAR2, retcode OUT VARCHAR2) IS
  
    CURSOR csr_assembly_items IS
      SELECT DISTINCT assembly_item
        FROM xxobjt_conv_bom
       WHERE trans_to_int_status = 'N';
  
    cur_item csr_assembly_items%ROWTYPE;
  
    l_group               VARCHAR2(50);
    l_family              VARCHAR2(50);
    l_oil_organization_id NUMBER;
    l_oig_organization_id NUMBER;
    l_inventory_item_id   NUMBER;
  
  BEGIN
  
    SELECT organization_id
      INTO l_oil_organization_id
      FROM mtl_parameters
     WHERE organization_code = 'IPK'; ---'WPI'
  
    SELECT organization_id
      INTO l_oig_organization_id
      FROM mtl_parameters
     WHERE organization_code = 'IRK'; ---'WRI'
  
    FOR cur_item IN csr_assembly_items LOOP
    
      l_group             := NULL;
      l_inventory_item_id := NULL;
    
      BEGIN
      
        /* BEGIN
        
                       SELECT mc.segment1, msi.inventory_item_id
                         INTO l_group, l_inventory_item_id
                         FROM mtl_system_items_b  msi,
                              mtl_item_categories mic,
                              mtl_categories_b    mc
                        WHERE mic.category_id = mc.category_id AND
                              mic.inventory_item_id = msi.inventory_item_id AND
                              mic.organization_id = msi.organization_id AND
                              mic.organization_id =
                              xxinv_utils_pkg.get_master_organization_id AND
                              mic.category_set_id =
                              xxinv_utils_pkg.get_default_category_set_id AND
                              msi.segment1 = cur_item.assembly_item;
        
                    EXCEPTION
                       WHEN OTHERS THEN
        */
        SELECT msi.inventory_item_id
          INTO l_inventory_item_id
          FROM mtl_system_items_b msi
         WHERE msi.organization_id =
               xxinv_utils_pkg.get_master_organization_id
           AND msi.segment1 = cur_item.assembly_item;
      
        -- END;
      
        UPDATE xxobjt_conv_bom
           SET assembly_item_id = l_inventory_item_id,
               organization_id  = xxinv_utils_pkg.get_organization_id_to_assign(l_inventory_item_id)
         WHERE assembly_item = cur_item.assembly_item;
      
      EXCEPTION
        WHEN OTHERS THEN
        
          UPDATE xxobjt_conv_bom xcb
             SET xcb.trans_to_int_status = 'E',
                 xcb.trans_to_int_msg    = 'Assembly not exist'
           WHERE assembly_item = cur_item.assembly_item;
        
      END;
    
    END LOOP;
  
    COMMIT;
  END bom_org_assignment;
  -----------------------------------------------------------------------
  /*PROCEDURE interface_validation(errbuf OUT VARCHAR2, retcode OUT VARCHAR2) IS
  
    CURSOR csr_bom_assembly IS
      SELECT DISTINCT assembly_item_id, assembly_item, organization_id
        FROM xxobjt_conv_bom a
       WHERE a.trans_to_int_status = 'N'
         AND NOT EXISTS
       (SELECT 'X'
                FROM xxobjt_conv_bom b
               WHERE a.organization_id = b.organization_id
                 AND a.assembly_item_id = b.assembly_item_id
                 AND b.trans_to_int_status = 'E')
       ORDER BY assembly_item_id;
  
    CURSOR csr_bom_components(p_assembly_item_id NUMBER) IS
      SELECT *
        FROM xxobjt_conv_bom a
       WHERE assembly_item_id = p_assembly_item_id
         AND a.trans_to_int_status = 'N'
         FOR UPDATE OF trans_to_int_status, trans_to_int_msg, seq_num, component_item_id;
  
    cur_assembly         csr_bom_assembly%ROWTYPE;
    cur_bom_component    csr_bom_components%ROWTYPE;
    v_component_item_id  mtl_system_items.inventory_item_id%TYPE;
    v_comp_prim_uom      mtl_system_items.primary_unit_of_measure%TYPE;
    v_uom_exist          CHAR(1);
    v_trans_to_int_flag  CHAR(1);
    v_trans_to_int_error VARCHAR2(240);
    v_comp_sequence      NUMBER(5) := 0;
    v_error              VARCHAR2(100);
  
    invalid_bom EXCEPTION;
  
  BEGIN
  
    FOR cur_assembly IN csr_bom_assembly LOOP
  
      BEGIN
  
        --check bom_action
        v_comp_sequence := 0;
  
        BEGIN
  
          SELECT 'E', 'BOM Already Exists'
            INTO v_trans_to_int_flag, v_trans_to_int_error
            FROM bom_bill_of_materials a
           WHERE a.organization_id = cur_assembly.organization_id
             AND assembly_item_id = cur_assembly.assembly_item_id;
  
          RAISE invalid_bom;
  
        EXCEPTION
          WHEN no_data_found THEN
            v_trans_to_int_flag := 'N';
          WHEN invalid_bom THEN
            RAISE invalid_bom;
          WHEN OTHERS THEN
  
            v_trans_to_int_flag  := 'E';
            v_trans_to_int_error := 'BOM Select Error: ' || SQLERRM;
            RAISE invalid_bom;
        END;
  
        FOR cur_bom_component IN csr_bom_components(cur_assembly.assembly_item_id) LOOP
  
          v_trans_to_int_flag  := 'N';
          v_trans_to_int_error := NULL;
          v_component_item_id  := NULL;
  
          -- Check the Component item existance
          BEGIN
  
            SELECT msi.inventory_item_id, primary_unit_of_measure
              INTO v_component_item_id, v_comp_prim_uom
              FROM mtl_system_items_b msi
             WHERE msi.organization_id = cur_bom_component.organization_id
               AND msi.segment1 = cur_bom_component.component_item;
  
          EXCEPTION
            WHEN no_data_found THEN
  
              v_trans_to_int_flag  := 'E';
              v_trans_to_int_error := 'Component: ' ||
                                      cur_bom_component.component_item ||
                                      ' Not Exists In The System';
              RAISE invalid_bom;
  
            WHEN OTHERS THEN
  
              v_trans_to_int_flag  := 'E';
              v_trans_to_int_error := 'Component: ' ||
                                      cur_bom_component.component_item || ' ' ||
                                      substr(SQLERRM, 1, 80);
              RAISE invalid_bom;
          END;
          --Check that qty does not have '.'
  
          v_comp_sequence := v_comp_sequence + 1;
  
          UPDATE xxobjt_conv_bom
             SET trans_to_int_status = 'N',
                 trans_to_int_msg    = NULL,
                 seq_num             = v_comp_sequence,
                 component_item_id   = v_component_item_id
           WHERE CURRENT OF csr_bom_components;
  
        END LOOP;
  
      EXCEPTION
        WHEN invalid_bom THEN
  
          UPDATE xxobjt_conv_bom
             SET trans_to_int_status = v_trans_to_int_flag,
                 trans_to_int_msg    = v_trans_to_int_error
           WHERE assembly_item_id = cur_assembly.assembly_item_id;
  
        WHEN OTHERS THEN
  
          v_error := substr(SQLERRM, 1, 70);
          UPDATE xxobjt_conv_bom
             SET trans_to_int_status = 'E', trans_to_int_msg = v_error
           WHERE assembly_item_id = cur_assembly.assembly_item_id;
  
      END;
  
      COMMIT;
  
    END LOOP;
  
    COMMIT;
  
  END interface_validation;*/
  ----------------------------------------------------------------------------
  -- This is a Good Procedure. After the table XXOBJT_CONV_BOM is full of data
  ----------------------------------------------------------------------------
  /*PROCEDURE insert_interface_bom(errbuf            OUT VARCHAR2,
                                 retcode           OUT VARCHAR2,
                                 p_organization_id IN NUMBER) IS
  
    CURSOR csr_bom_assembly IS
      SELECT DISTINCT assembly_item_id, assembly_item, organization_id
        FROM xxobjt_conv_bom a
       WHERE a.trans_to_int_status = 'N'
         AND NOT EXISTS
       (SELECT 'X'
                FROM xxobjt_conv_bom b
               WHERE a.organization_id = b.organization_id
                 AND a.assembly_item_id = b.assembly_item_id
                 AND b.trans_to_int_status = 'E')
       ORDER BY assembly_item_id;
  
    CURSOR csr_bom_components(p_assembly_item_id NUMBER) IS
      SELECT *
        FROM xxobjt_conv_bom a
       WHERE assembly_item_id = p_assembly_item_id
         AND a.trans_to_int_status = 'N';
  
    cur_assembly      csr_bom_assembly%ROWTYPE;
    cur_bom_component csr_bom_components%ROWTYPE;
    v_user_id         fnd_user.user_id%TYPE;
    v_error           VARCHAR2(100);
    v_assembly        NUMBER := -1;
    v_com_seq_num     NUMBER;
    v_comp_qty        NUMBER(10, 2);
    v_comp            NUMBER;
    v_comp_seq        NUMBER;
    v_ref_num         NUMBER := 0;
    v_counter         NUMBER := 0;
    ----- sari
    v_delimiter_des   CHAR(1) := '@';
    v_tmp_des         VARCHAR2(1000);
    v_place_des       NUMBER;
    v_ref_des         VARCHAR2(10);
    ln_quantity       NUMBER;
    ln_total_quantity NUMBER := 0;
    x                 NUMBER;
    l_supply_type     NUMBER;
    v_errbuf          VARCHAR2(100);
    v_retcode         VARCHAR2(3);
  BEGIN
  
    --bom_org_assignment(v_errbuf, v_retcode);
    interface_validation(v_errbuf, v_retcode);
  
    BEGIN
      SELECT user_id
        INTO v_user_id
        FROM fnd_user
       WHERE user_name = 'CONVERSION';
    EXCEPTION
      WHEN no_data_found THEN
        v_user_id := NULL;
    END;
  
    --Insert Into Interface
    FOR cur_assembly IN csr_bom_assembly LOOP
  
      v_counter := 0;
      BEGIN
  
        SAVEPOINT insert_bom;
  
        INSERT INTO bom_bill_of_mtls_interface
          (assembly_item_id,
           organization_id,
           assembly_type,
           transaction_type,
           process_flag,
           structure_type_name,
           created_by,
           creation_date,
           last_updated_by,
           last_update_date,
           last_update_login)
        VALUES
          (cur_assembly.assembly_item_id,
           cur_assembly.organization_id,
           1,
           'CREATE',
           1,
           'Manufacturing Structure',
           v_user_id,
           SYSDATE,
           v_user_id,
           SYSDATE,
           -1);
  
        FOR cur_bom_component IN csr_bom_components(cur_assembly.assembly_item_id) LOOP
  
          IF cur_bom_component.supply_type IS NOT NULL THEN
            SELECT lookup_code
              INTO l_supply_type
              FROM mfg_lookups
             WHERE lookup_type = 'WIP_SUPPLY'
               AND meaning = cur_bom_component.supply_type;
          ELSE
            l_supply_type := NULL;
          END IF;
          v_counter := v_counter + 10;
  
          INSERT INTO bom_inventory_comps_interface
            (assembly_item_id,
             organization_id,
             component_item_id,
             component_quantity,
             component_sequence_id,
             effectivity_date,
             disable_date,
             wip_supply_type,
             item_num,
             operation_seq_num,
             transaction_type,
             process_flag,
             created_by,
             creation_date,
             last_updated_by,
             last_update_date,
             last_update_login)
          VALUES
            (cur_bom_component.assembly_item_id,
             cur_bom_component.organization_id,
             cur_bom_component.component_item_id,
             cur_bom_component.quantity,
             cur_bom_component.seq_num,
             cur_bom_component.effective_date_from,
             cur_bom_component.effective_date_to,
             l_supply_type,
             v_counter,
             1, --operation_seq_num,
             'CREATE',
             1,
             v_user_id,
             SYSDATE,
             v_user_id,
             SYSDATE,
             -1);
  
          IF cur_bom_component.ref_designator IS NOT NULL THEN
  
            v_tmp_des := cur_bom_component.ref_designator;
            -- ln_quantity :=  i.component_quantity ;
  
            ln_total_quantity := 0;
            x                 := 0;
  
            FOR j IN 1 .. cur_bom_component.quantity LOOP
  
              v_ref_num := v_ref_num + 10;
              ---
              ln_total_quantity := ln_total_quantity + 1;
              ---
  
              v_place_des := instr(v_tmp_des, v_delimiter_des);
  
              --  Fnd_file.put_line(fnd_file.log,i.component_code ||' '||i.component_quantity || ' '||ln_total_quantity) ;
              IF v_place_des = 0 THEN
  
                v_place_des := length(v_tmp_des) + 1;
                fnd_file.put_line(fnd_file.log,
                                  ' ' || cur_bom_component.top_assembly || ' ' ||
                                  cur_bom_component.quantity || ' ' ||
                                  ln_total_quantity);
                IF ln_total_quantity <> cur_bom_component.quantity AND
                   cur_bom_component.ref_designator IS NOT NULL THEN
  
                  fnd_file.put_line(fnd_file.log,
                                    'In BOM :' ||
                                    cur_bom_component.top_assembly ||
                                    'component :' ||
                                    cur_bom_component.top_assembly ||
                                    'quantity <> total_quantity: ');
  
                END IF;
              END IF;
  
              v_ref_des := REPLACE(ltrim(rtrim(substr(v_tmp_des,
                                                      1,
                                                      v_place_des - 1))),
                                   chr(34),
                                   NULL);
  
              v_tmp_des := ltrim(substr(v_tmp_des,
                                        v_place_des + 1,
                                        length(v_tmp_des)));
  
              IF v_ref_des IS NOT NULL THEN
                x := x + 1;
              ELSE
                -- 'S1@S2@S3@' -- @ is last char in string
                fnd_file.put_line(fnd_file.log,
                                  cur_bom_component.top_assembly || ' ' ||
                                  'component : ' ||
                                  cur_bom_component.component_item ||
                                  'ref_des : ' ||
                                  cur_bom_component.ref_designator ||
                                  '  end of string is:, ');
                EXIT;
  
              END IF;
  
              INSERT INTO bom_ref_desgs_interface
                (component_reference_designator,
                 -- ref_designator_comment,
                 assembly_item_id,
                 -- component_sequence_id,--
                 component_item_id,
                 created_by,
                 creation_date,
                 last_updated_by,
                 last_update_date,
                 last_update_login,
                 process_flag,
                 transaction_type,
                 organization_id,
                 effectivity_date)
              VALUES
                (v_ref_des, -- v_ref_num,
                 --  v_ref_des ,
                 cur_bom_component.assembly_item_id,
                 -- v_com_seq_num,--
                 cur_bom_component.component_item_id,
                 v_user_id,
                 SYSDATE,
                 v_user_id,
                 SYSDATE,
                 -1,
                 1, --999, -- Ran - correct process flag
                 'CREATE',
                 cur_bom_component.organization_id,
                 trunc(SYSDATE));
            END LOOP;
  
          END IF; -- Ref
  
          --   END; -- comp
  
          UPDATE xxobjt_conv_bom
             SET trans_to_int_status = 'S', trans_to_int_msg = NULL
           WHERE assembly_item_id = cur_assembly.assembly_item_id
             AND component_item = cur_bom_component.component_item;
  
        END LOOP; -- component loop
  
      EXCEPTION
        WHEN OTHERS THEN
  
          ROLLBACK TO insert_bom;
  
          v_error := substr(SQLERRM, 1, 70);
          UPDATE xxobjt_conv_bom
             SET trans_to_int_status = 'E', trans_to_int_msg = v_error
           WHERE assembly_item_id = cur_assembly.assembly_item_id;
  
          dbms_output.put_line(cur_assembly.assembly_item || ', error:  ' ||
                               SQL%ROWCOUNT);
  
      END;
      COMMIT;
  
    END LOOP; -- assembly loop
  
    COMMIT;
    errbuf  := NULL;
    retcode := NULL;
  
  EXCEPTION
    WHEN OTHERS THEN
  
      errbuf  := 'Insert_Interface_Bom : ' || SQLERRM;
      retcode := SQLCODE;
  
  END insert_interface_bom;*/
  ---------------------------------------------------------------------------

  PROCEDURE update_supply_type IS
  
    CURSOR csr_components IS
      SELECT assembly_item,
             component_item,
             organization_id,
             supply_type,
             quantity
        FROM xxobjt_conv_bom a
       WHERE a.supply_type IS NOT NULL;
  
    cur_component csr_components%ROWTYPE;
  
    l_assembly_id      NUMBER;
    l_component_id     NUMBER;
    l_supply_type      NUMBER;
    l_bill_sequence_id NUMBER;
  
  BEGIN
  
    FOR cur_component IN csr_components LOOP
    
      SELECT assembly_item_id, bill_sequence_id
        INTO l_assembly_id, l_bill_sequence_id
        FROM mtl_system_items_b msi, bom_bill_of_materials b
       WHERE msi.segment1 = cur_component.assembly_item
         AND msi.organization_id = cur_component.organization_id
         AND msi.inventory_item_id = b.assembly_item_id
         AND msi.organization_id = b.organization_id;
    
      SELECT inventory_item_id
        INTO l_component_id
        FROM mtl_system_items_b
       WHERE segment1 = cur_component.component_item
         AND organization_id = 91; --Master
    
      SELECT lookup_code
        INTO l_supply_type
        FROM mfg_lookups
       WHERE lookup_type = 'WIP_SUPPLY'
         AND meaning = cur_component.supply_type;
    
      UPDATE bom_components_b t
         SET t.wip_supply_type = l_supply_type
       WHERE t.component_item_id = l_component_id
         AND t.bill_sequence_id = l_bill_sequence_id
         AND t.component_quantity = cur_component.quantity;
    
    END LOOP;
  
    COMMIT;
  
  EXCEPTION
    WHEN OTHERS THEN
      dbms_output.put_line(cur_component.assembly_item || ', ' ||
                           cur_component.component_item);
      ROLLBACK;
  END update_supply_type;
  -----------------------------------------------------------------------
  --  customization code: CUST695 --- Std Costing Conversions (Moving to Std Costing Project)
  --  name:               copy_bom
  --  create by:          Vitaly K.
  --  $Revision:          1.0 $
  --  creation date:      24/06/2013
  --  Purpose :   Copy BOMs to the new organizations (CR812)
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   24/06/2013    Vitaly K.       initial build
  --  2.0   20-02-2018    R.W.            CHG0041937 - added parametr "p_copy_subinventory"
  -----------------------------------------------------------------------
  PROCEDURE copy_bom(errbuf                 OUT VARCHAR2,
                     retcode                OUT VARCHAR2,
                     p_from_organization_id IN NUMBER,
                     p_assembly_item_id     IN NUMBER,
                     p_to_organization_id   IN NUMBER,
                     -- CHG0041937
                     p_copy_subinventory IN VARCHAR2) IS
    stop_processing EXCEPTION;
    l_error_message VARCHAR2(3000);
    l_step          VARCHAR2(100);
  
    l_from_organization_code VARCHAR2(3);
    l_to_organization_code   VARCHAR2(3);
    l_assembly_item_segment1 VARCHAR2(40);
  
    l_bom_success_counter NUMBER := 0;
    l_bom_errors_counter  NUMBER := 0;
  
    l_cnt          NUMBER;
    l_item_sequnce NUMBER;
    -- API input variables
    l_bom_header_rec         bom_bo_pub.bom_head_rec_type := bom_bo_pub.g_miss_bom_header_rec;
    l_bom_revision_tbl       bom_bo_pub.bom_revision_tbl_type := bom_bo_pub.g_miss_bom_revision_tbl;
    l_bom_component_tbl      bom_bo_pub.bom_comps_tbl_type := bom_bo_pub.g_miss_bom_component_tbl;
    l_bom_ref_designator_tbl bom_bo_pub.bom_ref_designator_tbl_type := bom_bo_pub.g_miss_bom_ref_designator_tbl;
    l_bom_sub_component_tbl  bom_bo_pub.bom_sub_component_tbl_type := bom_bo_pub.g_miss_bom_sub_component_tbl;
  
    -- API output variables
    x_bom_header_rec         bom_bo_pub.bom_head_rec_type := bom_bo_pub.g_miss_bom_header_rec;
    x_bom_revision_tbl       bom_bo_pub.bom_revision_tbl_type := bom_bo_pub.g_miss_bom_revision_tbl;
    x_bom_component_tbl      bom_bo_pub.bom_comps_tbl_type := bom_bo_pub.g_miss_bom_component_tbl;
    x_bom_ref_designator_tbl bom_bo_pub.bom_ref_designator_tbl_type := bom_bo_pub.g_miss_bom_ref_designator_tbl;
    x_bom_sub_component_tbl  bom_bo_pub.bom_sub_component_tbl_type := bom_bo_pub.g_miss_bom_sub_component_tbl;
    ---x_message_list           error_handler.error_tbl_type;
  
    l_error_table error_handler.error_tbl_type;
    -- l_output_dir            VARCHAR2(500) :=  '/UtlFiles/shared/DEV';
    --l_debug_filename        VARCHAR2(60) := 'bom_debug.dbg';
  
    l_return_status VARCHAR2(1) := NULL;
    l_msg_count     NUMBER := 0;
  
    -- WHO columns
    l_user_id        NUMBER := fnd_global.user_id;
    l_resp_id        NUMBER := fnd_global.resp_id;
    l_application_id NUMBER := fnd_global.resp_appl_id;
    ---user and responsibility for Apps Initialize-------
    l_user_name VARCHAR2(30) := 'CONVERSION';
    l_resp_name VARCHAR2(50) := 'Bills of Material'; -----'Manufacturing and Distribution Manager';
  
    CURSOR c_get_assemblies IS
      SELECT msi.inventory_item_id,
             msi.segment1 assembly_name,
             mp.organization_code,
             bom.assembly_type
        FROM bom_structures_b   bom,
             mtl_system_items_b msi,
             mtl_parameters     mp
       WHERE bom.assembly_item_id = msi.inventory_item_id
         AND bom.organization_id = msi.organization_id
         AND mp.organization_id = p_from_organization_id ---parameter
         AND mp.organization_id = msi.organization_id
         AND msi.inventory_item_id =
             nvl(p_assembly_item_id, msi.inventory_item_id) ---parameter
         AND NOT EXISTS
       (SELECT 1
                FROM bom_structures_b tt
               WHERE tt.assembly_item_id = bom.assembly_item_id
                 AND tt.organization_id = p_to_organization_id); ---parameter
    /*AND msi.segment1 IN ('ASY-01904',
    'OBJ-14000',
    'OBJ-13550',
    'OBJ-33070',
    'OBJ-33080')*/
    --  ORDER BY msi.segment1;
  
    CURSOR c_get_non_unique_comp_seq(p_assembly_id NUMBER) IS
      SELECT bc.item_num, COUNT(1) cntr
        FROM bom_structures_b       bom,
             mtl_system_items_b     msi,
             mtl_system_items_b     msib,
             bom_components_b       bc,
             mtl_parameters         mp,
             mtl_parameters         mp1,
             mtl_item_locations_kfv mil --new NOAM
       WHERE mil.inventory_location_id(+) = bc.supply_locator_id --new NOAM
         AND bom.organization_id = mp1.organization_id
         AND mp1.organization_id = p_from_organization_id ---parameter
         AND bc.bill_sequence_id = bom.bill_sequence_id
         AND msib.inventory_item_id = bom.assembly_item_id
         AND msib.organization_id = bom.organization_id
         AND msi.inventory_item_id = bc.component_item_id
         AND msi.organization_id = bom.organization_id
         AND bc.implementation_date IS NOT NULL
         AND msib.inventory_item_id = p_assembly_id ---cursor parameter
         AND mp.organization_id = p_to_organization_id ---parameter
       GROUP BY bc.item_num
      HAVING COUNT(1) > 1;
  
    CURSOR c_get_components(p_assembly_id NUMBER) IS
      SELECT msib.segment1 assem_name,
             msi.segment1 comp_name,
             bc.component_quantity,
             trunc(bc.effectivity_date) effectivity_date,
             trunc(bc.disable_date) disable_date,
             mp.organization_code,
             bom.assembly_item_id,
             bc.component_item_id,
             bc.operation_seq_num component_operations,
             bc.wip_supply_type,
             bom.bill_sequence_id,
             bc.supply_subinventory,
             mil.concatenated_segments locator_name,
             bc.optional,
             bc.mutually_exclusive_options,
             bc.include_on_ship_docs,
             bc.item_num, ----XXXXXXXX-------
             --   bc.supply_subinventory,
             bc.supply_locator_id
        FROM bom_structures_b       bom,
             mtl_system_items_b     msi,
             mtl_system_items_b     msib,
             bom_components_b       bc,
             mtl_parameters         mp,
             mtl_parameters         mp1,
             mtl_item_locations_kfv mil --new NOAM
       WHERE mil.inventory_location_id(+) = bc.supply_locator_id --new NOAM
         AND bom.organization_id = mp1.organization_id
         AND mp1.organization_id = p_from_organization_id ---parameter
         AND bc.bill_sequence_id = bom.bill_sequence_id
         AND msib.inventory_item_id = bom.assembly_item_id
         AND msib.organization_id = bom.organization_id
         AND msi.inventory_item_id = bc.component_item_id
         AND msi.organization_id = bom.organization_id
         AND bc.implementation_date IS NOT NULL
         AND msib.inventory_item_id = p_assembly_id ---cursor parameter
         AND mp.organization_id = p_to_organization_id; ---parameter
  
  BEGIN
    l_step  := 'Step 0';
    errbuf  := NULL;
    retcode := '0';
  
    l_step := 'Step 10';
    IF p_from_organization_id IS NULL THEN
      l_error_message := 'Error: Missing parameter p_from_organization_id';
      RAISE stop_processing;
    ELSE
      -------
      BEGIN
        SELECT mp.organization_code
          INTO l_from_organization_code
          FROM mtl_parameters mp
         WHERE mp.organization_id = p_from_organization_id; ---parameter
      EXCEPTION
        WHEN no_data_found THEN
          l_error_message := 'Error: Invalid parameter p_from_organization_id=' ||
                             p_from_organization_id;
          RAISE stop_processing;
      END;
      -------
    END IF;
  
    l_step := 'Step 20';
    IF p_to_organization_id IS NULL THEN
      l_error_message := 'Error: Missing parameter p_to_organization_id';
      RAISE stop_processing;
    ELSE
      -------
      BEGIN
        SELECT mp.organization_code
          INTO l_to_organization_code
          FROM mtl_parameters mp
         WHERE mp.organization_id = p_to_organization_id; ---parameter
      EXCEPTION
        WHEN no_data_found THEN
          l_error_message := 'Error: Invalid parameter p_to_organization_id=' ||
                             p_to_organization_id;
          RAISE stop_processing;
      END;
      -------
    END IF;
  
    l_step := 'Step 30';
    IF p_from_organization_id = p_to_organization_id THEN
      l_error_message := 'Error: parameter p_from_organization_id cannot be equel to p_to_organization_id';
      RAISE stop_processing;
    END IF;
  
    l_step := 'Step 40';
    IF p_assembly_item_id IS NOT NULL THEN
      -------
      BEGIN
        SELECT msi.segment1
          INTO l_assembly_item_segment1
          FROM mtl_system_items_b msi
         WHERE msi.organization_id = p_from_organization_id ---parameter
           AND msi.inventory_item_id = p_assembly_item_id; ---parameter
      EXCEPTION
        WHEN no_data_found THEN
          l_error_message := 'Error: Invalid parameters -- assembly item_id=' ||
                             p_assembly_item_id ||
                             ' does not exist in (from) organization ''' ||
                             l_from_organization_code ||
                             ''' (organization_id=' ||
                             p_from_organization_id || ')';
          RAISE stop_processing;
      END;
      -------
    END IF;
  
    l_step := 'Step 50';
    IF l_resp_id = -1 THEN
      -- Get the user_id----
      BEGIN
        SELECT user_id
          INTO l_user_id
          FROM fnd_user
         WHERE user_name = l_user_name;
      EXCEPTION
        WHEN no_data_found THEN
          l_error_message := 'Invalid User ''' || l_user_name || '''';
          RAISE stop_processing;
      END;
      ----------------------
    
      l_step := 'Step 60';
      -- Get the application_id and responsibility_id
    
      BEGIN
        SELECT application_id, responsibility_id
          INTO l_application_id, l_resp_id
          FROM fnd_responsibility_vl
         WHERE responsibility_name = l_resp_name;
      EXCEPTION
        WHEN no_data_found THEN
          l_error_message := 'Invalid Responsibility ''' || l_resp_name || '''';
          RAISE stop_processing;
      END;
    END IF;
    l_step := 'Step 70';
    -- intiialize applications information
    fnd_global.apps_initialize(l_user_id, l_resp_id, l_application_id);
    dbms_output.put_line('Initialized applications context: ' || l_user_id || ' ' ||
                         l_resp_id || ' ' || l_application_id);
  
    l_step := 'Step 80';
    -- Display parameters in Log ------
    fnd_file.put_line(fnd_file.log, ''); --empty line
    fnd_file.put_line(fnd_file.log, ''); --empty line
    fnd_file.put_line(fnd_file.log,
                      '================ PARAMETERS: ============================');
    fnd_file.put_line(fnd_file.log,
                      '===From Organization: ''' ||
                      l_from_organization_code || ''' (organization_id=' ||
                      p_from_organization_id || ')');
    IF p_assembly_item_id IS NOT NULL THEN
      fnd_file.put_line(fnd_file.log,
                        '===Assebly Item:     ''' || l_to_organization_code ||
                        ''' (inv_item_id=' || p_assembly_item_id || ')');
    END IF;
  
    fnd_file.put_line(fnd_file.log,
                      '===To   Organization: ''' || l_to_organization_code ||
                      ''' (organization_id=' || p_to_organization_id || ')');
    fnd_file.put_line(fnd_file.log, ''); --empty line
    fnd_file.put_line(fnd_file.log,
                      '================ APPS_INITIALIZE was completed ==========');
    fnd_file.put_line(fnd_file.log,
                      '===User:           ''' || l_user_name ||
                      ''' (user_id=' || l_user_id || ')');
    fnd_file.put_line(fnd_file.log,
                      '===Responsibility: ''' || l_resp_name ||
                      ''' (resp_id=' || l_resp_id || ')');
    fnd_file.put_line(fnd_file.log, ''); --empty line
    FOR assembly_rec IN c_get_assemblies LOOP
    
      l_step := 'Step 90';
      ----=========================== ASSEMBLIES LOOP =================================================
      l_bom_header_rec := bom_bo_pub.g_miss_bom_header_rec;
      l_bom_component_tbl.delete;
      l_cnt          := 0;
      l_item_sequnce := 0;
      -- initialize BOM header
      l_bom_header_rec.assembly_item_name := assembly_rec.assembly_name;
      l_bom_header_rec.organization_code  := l_to_organization_code;
      ---l_bom_header_rec.Organization_Code
      l_bom_header_rec.assembly_type    := assembly_rec.assembly_type;
      l_bom_header_rec.transaction_type := 'CREATE';
      l_bom_header_rec.return_status    := NULL;
    
      ------Check Item Sequence UNIQUE
      FOR component_rec IN c_get_non_unique_comp_seq(assembly_rec.inventory_item_id) LOOP
        NULL;
      END LOOP;
    
      FOR component_rec IN c_get_components(assembly_rec.inventory_item_id) LOOP
        ----========================= COMPONENTS LOOP ===================================
        -- l_bom_component_tbl(l_cnt) := bom_bo_pub.g_miss_bom_component_rec;
        -- := bom_bo_pub.g_miss_bom_component_tbl;
        l_step         := 'Step 100';
        l_cnt          := l_cnt + 1;
        l_item_sequnce := l_item_sequnce + 10;
        -- initialize BOM components
        l_bom_component_tbl(l_cnt).organization_code := component_rec.organization_code;
        l_bom_component_tbl(l_cnt).assembly_item_name := component_rec.assem_name;
        l_bom_component_tbl(l_cnt).start_effective_date := component_rec.effectivity_date;
        l_bom_component_tbl(l_cnt).component_item_name := component_rec.comp_name;
        l_bom_component_tbl(l_cnt).alternate_bom_code := NULL;
        -- Added by R.W. 20-02-2018 CHG0041937
        if p_copy_subinventory = 'Y' then
          l_bom_component_tbl(l_cnt).supply_subinventory := component_rec.supply_subinventory;
          l_bom_component_tbl(l_cnt).location_name := component_rec.locator_name; --NEW NOAM -- '6.6.6..';  -- provide concatenated segments for locator
        end if;
      
        l_bom_component_tbl(l_cnt).comments := 'Created from BOM API';
        -- l_bom_component_tbl(l_cnt).item_sequence_number := l_item_sequnce; ----XXXXXX---
        l_bom_component_tbl(l_cnt).item_sequence_number := component_rec.item_num; ----XXXXX
        --l_bom_component_tbl(l_cnt).operation_sequence_number := component_rec.component_operations;
        l_bom_component_tbl(l_cnt).transaction_type := 'CREATE';
        l_bom_component_tbl(l_cnt).quantity_per_assembly := component_rec.component_quantity;
        l_bom_component_tbl(l_cnt).return_status := NULL;
        l_bom_component_tbl(l_cnt).disable_date := component_rec.disable_date;
        /* l_bom_component_tbl(l_cnt).wip_supply_type := nvl(component_rec.wip_supply_type,
                                                            bom_bo_pub.g_miss_bom_component_rec.wip_supply_type);
        */
        l_bom_component_tbl(l_cnt).wip_supply_type := component_rec.wip_supply_type;
      
        l_bom_component_tbl(l_cnt).mutually_exclusive := component_rec.mutually_exclusive_options;
        l_bom_component_tbl(l_cnt).include_on_ship_docs := component_rec.include_on_ship_docs;
      
        l_bom_component_tbl(l_cnt).optional := component_rec.optional;
        ------------l_bom_component_tbl (l_cnt).Effective_Date=component_rec.EFFECTIVITY_DATE;
      ----=================the end of COMPONENTS LOOP ==============================
      END LOOP;
    
      l_step := 'Step 110';
      -- initialize error stack for logging errors
      error_handler.initialize;
    
      IF l_bom_component_tbl.count() > 0 THEN
        l_step := 'Step 120';
        -- call API to create / update bill
        bom_bo_pub.process_bom(p_bo_identifier          => 'BOM',
                               p_api_version_number     => 1.0,
                               p_init_msg_list          => TRUE,
                               p_bom_header_rec         => l_bom_header_rec,
                               p_bom_revision_tbl       => l_bom_revision_tbl,
                               p_bom_component_tbl      => l_bom_component_tbl,
                               p_bom_ref_designator_tbl => l_bom_ref_designator_tbl,
                               p_bom_sub_component_tbl  => l_bom_sub_component_tbl,
                               x_bom_header_rec         => x_bom_header_rec,
                               x_bom_revision_tbl       => x_bom_revision_tbl,
                               x_bom_component_tbl      => x_bom_component_tbl,
                               x_bom_ref_designator_tbl => x_bom_ref_designator_tbl,
                               x_bom_sub_component_tbl  => x_bom_sub_component_tbl,
                               x_return_status          => l_return_status,
                               x_msg_count              => l_msg_count,
                               p_debug                  => 'N'
                               --p_output_dir                  => l_output_dir,
                               --p_debug_filename              => l_debug_filename
                               );
      
        l_step := 'Step 130';
        IF (l_return_status = fnd_api.g_ret_sts_success) THEN
          --API Success
          COMMIT;
          l_bom_success_counter := l_bom_success_counter + 1;
        ELSE
          --API Error
          fnd_file.put_line(fnd_file.log,
                            '********* ERROR: Assembly Item ''' ||
                            assembly_rec.assembly_name ||
                            ''' (inv_item_id=' ||
                            assembly_rec.inventory_item_id || ')');
          ----dbms_output.put_line('x_msg_count:' || l_msg_count);
        
          error_handler.get_message_list(x_message_list => l_error_table);
          ---dbms_output.put_line('Error Message Count :' ||
          ----                     l_error_table.count);
        
          l_step := 'Step 140';
          FOR i IN 1 .. l_error_table.count LOOP
            fnd_file.put_line(fnd_file.log,
                              to_char(i) || ':' || l_error_table(i)
                              .entity_index || ':' || l_error_table(i)
                              .table_name);
            fnd_file.put_line(fnd_file.log,
                              to_char(i) || ':' || l_error_table(i)
                              .message_text);
          END LOOP;
          ROLLBACK;
          l_bom_errors_counter := l_bom_errors_counter + 1;
        END IF;
      ELSE
        fnd_file.put_line(fnd_file.log,
                          'No component found for assembly ' ||
                          assembly_rec.assembly_name);
      END IF;
      ----====================the end of ASSEMBLY LOOP =================================================
    END LOOP;
  
    l_step := 'Step 150';
    fnd_file.put_line(fnd_file.log, ''); --empty line
    fnd_file.put_line(fnd_file.log, ''); --empty line
    fnd_file.put_line(fnd_file.log,
                      '================ Concurrent program was completed =======');
    fnd_file.put_line(fnd_file.log,
                      '================ RESULTS: ===============================');
    fnd_file.put_line(fnd_file.log,
                      '=== ' || l_bom_success_counter ||
                      ' BOMs were created SUCCESSFULLY');
    IF l_bom_errors_counter = 0 THEN
      fnd_file.put_line(fnd_file.log, '=== no errors ===');
    ELSE
      retcode := '1';
      fnd_file.put_line(fnd_file.log,
                        '=== ' || l_bom_errors_counter ||
                        ' BOMs were FAILURE');
    END IF;
  
  EXCEPTION
    WHEN stop_processing THEN
      errbuf  := l_error_message;
      retcode := '2';
    WHEN OTHERS THEN
      errbuf  := 'Unexpected Error in xxconv_bom_pkg.copy_bom (' || l_step ||
                 '): ' || SQLERRM;
      retcode := '2';
  END copy_bom;
  ------------------------------------------------------------------------

END xxconv_il_bom_pkg;
/
