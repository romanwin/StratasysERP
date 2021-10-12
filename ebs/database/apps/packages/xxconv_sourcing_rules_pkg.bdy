CREATE OR REPLACE PACKAGE BODY xxconv_sourcing_rules_pkg IS
  ---------------------------------------------------------------------------
  -- $Header: xxconv_sourcing_rules_pkg   $
  ---------------------------------------------------------------------------
  -- Package: xxconv_sourcing_rules_pkg
  -- Created:
  -- Author:
  --------------------------------------------------------------------------
  -- Purpose: Create Sourcing Rules for new Organizations
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  03.7.13    Vitaly      initial build
  ------------------------------------------------------------------
  g_add_to_sr_name_str VARCHAR2(100) := '.';
  -----------------------------------------------------------------------------
  PROCEDURE message(p_message VARCHAR2) IS
  
  BEGIN
    dbms_output.put_line(p_message);
    fnd_file.put_line(fnd_file.log, '========= ' || p_message);
  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END message;
  -----------------------------------------------------------------------
  -- get_lookup_code
  -----------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------------------------
  --     1.0  3.7.13    Vitaly      initial build
  -----------------------------------------------------------------------
  FUNCTION get_lookup_code(p_lookup_type VARCHAR2, p_meaning VARCHAR2)
    RETURN VARCHAR2 IS
    v_lookup_code VARCHAR2(100);
  BEGIN
    IF p_lookup_type IS NULL OR p_meaning IS NULL THEN
      RETURN NULL;
    END IF;
    SELECT lookup_code
      INTO v_lookup_code
      FROM fnd_lookup_values_vl
     WHERE lookup_type = upper(p_lookup_type) --param
       AND meaning = p_meaning; --param
    RETURN v_lookup_code;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_lookup_code;
  -----------------------------------------------------------------------
  -- get_organization_id
  -----------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ---------------------------------
  --     1.0  4.7.13    Vitaly      initial build
  -----------------------------------------------------------------------
  FUNCTION get_organization_id(p_organization_code VARCHAR2) RETURN NUMBER IS
    v_organization_id NUMBER;
  BEGIN
    IF p_organization_code IS NULL THEN
      RETURN NULL;
    END IF;
    SELECT mp.organization_id
      INTO v_organization_id
      FROM mtl_parameters mp
     WHERE mp.organization_code = p_organization_code; --param
    RETURN v_organization_id;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_organization_id;
  --------------------------------------------------------------------------
  -- upload_sourcing_rules
  --
  -- craete soursing rule from csv file cr813
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  11.6.13    Vitaly      initial build
  ---------------------------------------------------------------------------
  PROCEDURE upload_sourcing_rules(errbuf          OUT VARCHAR2,
                                  retcode         OUT VARCHAR2,
                                  p_table_name    IN VARCHAR2, --hidden parameter---- independent value set XXOBJT_LOADER_TABLES
                                  p_template_name IN VARCHAR2, -- dependent value set XXOBJT_LOADER_TEMPLATES
                                  p_file_name     IN VARCHAR2,
                                  p_directory     IN VARCHAR2) IS
  
    CURSOR c_validate_data IS
      SELECT ROWID row_id, a.*
        FROM xxmrp_sr_assignments a
       WHERE a.group_id = fnd_global.conc_request_id
         AND nvl(a.err_code, 'N') = 'N';
  
    CURSOR c_process_data(c_create_rule VARCHAR2) IS
      SELECT ROWID row_id, a.*
        FROM xxmrp_sr_assignments a
       WHERE /* a.group_id=15553115 and rownum<3 and err_code='E'*/
       a.group_id = fnd_global.conc_request_id
      ---AND nvl(a.create_rule, 'N') = nvl(c_create_rule,'N')
       AND ((a.create_rule IN ('DUPLICATE', 'NEW') AND c_create_rule = 'Y') OR
       nvl(c_create_rule, 'N') = 'N')
       AND nvl(a.err_code, 'N') = 'N'
       ORDER BY a.sourcing_rule_id;
  
    CURSOR c_get_errors IS
      SELECT a.*
        FROM xxmrp_sr_assignments a
       WHERE a.group_id = fnd_global.conc_request_id
         AND a.err_code = 'E';
  
    CURSOR c_get_sourcing_rule_data(p_sourcing_rule_name VARCHAR2,
                                    p_to_organization_id NUMBER) IS
      SELECT a.sourcing_rule_id sourcing_rule_id_new --,
      --  a.organization_id,
      --  a.sourcing_rule_name
        FROM mrp_sourcing_rules a
       WHERE a.organization_id = p_to_organization_id
         AND a.sourcing_rule_name = p_sourcing_rule_name;
  
    l_sourcing_rule_data_rec c_get_sourcing_rule_data%ROWTYPE;
    v_error_messsage         VARCHAR2(5000);
    translation_error            EXCEPTION;
    stop_processing              EXCEPTION;
    sourcing_rule_already_exists EXCEPTION;
    stop_create_sr               EXCEPTION;
    stop_sr_assignment           EXCEPTION;
    v_step VARCHAR2(100);
  
    v_retcode VARCHAR2(300);
    v_errbuf  VARCHAR2(300);
  
    v_validation_success_cntr     NUMBER := 0;
    v_validation_error_cntr       NUMBER := 0;
    v_api_error_cntr              NUMBER := 0;
    v_created_sourcing_rules_cntr NUMBER := 0;
    v_created_assignments_cntr    NUMBER := 0;
  
    ----api variables--------------
    --l_session_id            NUMBER;
    l_return_status VARCHAR2(1);
    l_msg_count     NUMBER := 0;
    l_msg_data      VARCHAR2(1000);
    ---l_msg_index_out NUMBER;
    ---l_count                 NUMBER;
    ---l_err_count             NUMBER := 0;
    l_sourcing_rule_rec     mrp_sourcing_rule_pub.sourcing_rule_rec_type;
    l_sourcing_rule_val_rec mrp_sourcing_rule_pub.sourcing_rule_val_rec_type;
    l_receiving_org_tbl     mrp_sourcing_rule_pub.receiving_org_tbl_type;
    l_receiving_org_val_tbl mrp_sourcing_rule_pub.receiving_org_val_tbl_type;
    l_shipping_org_tbl      mrp_sourcing_rule_pub.shipping_org_tbl_type;
    l_shipping_org_val_tbl  mrp_sourcing_rule_pub.shipping_org_val_tbl_type;
    o_sourcing_rule_rec     mrp_sourcing_rule_pub.sourcing_rule_rec_type;
    o_sourcing_rule_val_rec mrp_sourcing_rule_pub.sourcing_rule_val_rec_type;
    o_receiving_org_tbl     mrp_sourcing_rule_pub.receiving_org_tbl_type;
    o_receiving_org_val_tbl mrp_sourcing_rule_pub.receiving_org_val_tbl_type;
    o_shipping_org_tbl      mrp_sourcing_rule_pub.shipping_org_tbl_type;
    o_shipping_org_val_tbl  mrp_sourcing_rule_pub.shipping_org_val_tbl_type;
    ---
    l_assignment_set_rec     mrp_src_assignment_pub.assignment_set_rec_type;
    l_assignment_set_val_rec mrp_src_assignment_pub.assignment_set_val_rec_type;
    l_assignment_tbl         mrp_src_assignment_pub.assignment_tbl_type;
    l_assignment_val_tbl     mrp_src_assignment_pub.assignment_val_tbl_type;
    o_assignment_set_rec     mrp_src_assignment_pub.assignment_set_rec_type;
    o_assignment_set_val_rec mrp_src_assignment_pub.assignment_set_val_rec_type;
    o_assignment_tbl         mrp_src_assignment_pub.assignment_tbl_type;
    o_assignment_val_tbl     mrp_src_assignment_pub.assignment_val_tbl_type;
  
  BEGIN
  
    v_step  := 'Step 0';
    retcode := '0';
    errbuf  := 'Success';
  
    message('GROUP_ID=' || fnd_global.conc_request_id ||
            '============================================');
  
    v_step := 'Step 10';
    ---Load data from CSV-table into XXMRP_SR_ASSIGNMENTS table---------------------
    xxobjt_table_loader_util_pkg.load_file(errbuf                 => v_errbuf,
                                           retcode                => v_retcode,
                                           p_table_name           => p_table_name,
                                           p_template_name        => p_template_name,
                                           p_file_name            => p_file_name,
                                           p_directory            => p_directory,
                                           p_expected_num_of_rows => NULL);
    IF v_retcode <> '0' THEN
      ---WARNING or ERROR---
      v_error_messsage := v_errbuf;
      RAISE stop_processing;
    END IF;
  
    message('All records from file ' || p_file_name ||
            ' were successfully loaded into table XXMRP_SR_ASSIGNMENTS');
  
    v_step                    := 'Step 20';
    v_validation_success_cntr := 0;
    v_validation_error_cntr   := 0;
  
    FOR sourcing_rule_rec IN c_validate_data LOOP
      -------------TRANSLATIONS LOOP--------------
      BEGIN
        v_step := 'Step 30';
        -----check CREATE_RULE -----------
        IF nvl(sourcing_rule_rec.create_rule, 'NEW') NOT IN
           ('NEW', 'DUPLICATE') THEN
          v_error_messsage := 'Invalid CREATE_RULE value=' ||
                              sourcing_rule_rec.create_rule;
          RAISE translation_error;
        END IF;
        v_step := 'Step 40';
        ----translate ASSIGN_TO to ASSIGNMENT_TYPE------ for example: 'Item-Organization' to 6
        sourcing_rule_rec.assignment_type := get_lookup_code(p_lookup_type => 'MRP_ASSIGNMENT_TYPE',
                                                             p_meaning     => sourcing_rule_rec.assign_to);
        IF sourcing_rule_rec.assignment_type IS NULL THEN
          v_error_messsage := 'Invalid ASSIGN_TO value';
          RAISE translation_error;
        END IF;
        v_step := 'Step 50';
        ----translate SOURCE_TYPE to SOURCING_RULE_TYPE------ for example: 'Buy From' to 3
        sourcing_rule_rec.sourcing_rule_type := get_lookup_code(p_lookup_type => 'MRP_SOURCE_TYPE',
                                                                p_meaning     => sourcing_rule_rec.source_type);
        IF sourcing_rule_rec.sourcing_rule_type IS NULL THEN
          v_error_messsage := 'Invalid SOURCE_TYPE value';
          RAISE translation_error;
        END IF;
        v_step := 'Step 60';
        IF sourcing_rule_rec.organization_code IS NOT NULL THEN
          ----translate ORGANIZATION_CODE to ORGANIZATION_ID -- for example 'WPI' to 90
          sourcing_rule_rec.organization_id := get_organization_id(sourcing_rule_rec.organization_code);
          IF sourcing_rule_rec.organization_id IS NULL THEN
            v_error_messsage := 'Organization ' ||
                                sourcing_rule_rec.organization_code ||
                                ' does not exist';
            RAISE translation_error;
          END IF;
        END IF;
      
        v_step := 'Step 70';
        IF sourcing_rule_rec.source_organization_code IS NOT NULL THEN
          ----translate SOURCE_ORGANIZATION_CODE to SOURCE_ORGANIZATION_ID -- for example 'WPI' to 90
          sourcing_rule_rec.source_organization_id := get_organization_id(sourcing_rule_rec.source_organization_code);
          IF sourcing_rule_rec.source_organization_id IS NULL THEN
            v_error_messsage := 'Source organization ' ||
                                sourcing_rule_rec.source_organization_code ||
                                ' does not exist';
            RAISE translation_error;
          END IF;
        END IF;
        v_step := 'Step 80';
        IF sourcing_rule_rec.receipt_organization_code IS NOT NULL THEN
          ----translate RECEIPT_ORGANIZATION to RECEIPT_ORGANIZATION_ID  -- for example 'WPI' to 90
          sourcing_rule_rec.receipt_organization_id := get_organization_id(sourcing_rule_rec.receipt_organization_code);
          IF sourcing_rule_rec.receipt_organization_id IS NULL THEN
            v_error_messsage := 'Receipt organization ' ||
                                sourcing_rule_rec.receipt_organization_code ||
                                ' does not exist';
            RAISE translation_error;
          END IF;
        END IF;
        v_step := 'Step 90';
        IF sourcing_rule_rec.shipping_organization_code IS NOT NULL THEN
          ----translate SHIPPING_ORGANIZATION to SHIPPING_ORGANIZATION_ID  -- for example 'WPI' to 90
          sourcing_rule_rec.shipping_organization_id := get_organization_id(sourcing_rule_rec.shipping_organization_code);
          IF sourcing_rule_rec.shipping_organization_id IS NULL THEN
            v_error_messsage := 'Shipping organization ' ||
                                sourcing_rule_rec.shipping_organization_code ||
                                ' does not exist';
            RAISE translation_error;
          END IF;
        END IF;
      
        IF sourcing_rule_rec.assign_to = 'Item-Organization' THEN
          v_step := 'Step 100';
          IF sourcing_rule_rec.item IS NULL THEN
            v_error_messsage := 'Missing Item(segment1) for assignment_type=''Item-Organization''';
            RAISE translation_error;
          ELSE
            ----translate ITEM  to INVENTORY_ITEM_ID  ( in Source Organization)
            BEGIN
              SELECT msi.inventory_item_id
                INTO sourcing_rule_rec.inventory_item_id
                FROM mtl_system_items msi
               WHERE msi.organization_id =
                     sourcing_rule_rec.organization_id ---
                 AND msi.segment1 = sourcing_rule_rec.item; ----
            
            EXCEPTION
              WHEN no_data_found THEN
                v_error_messsage := 'Item ' || sourcing_rule_rec.item ||
                                    ' does not exist in source organization ' ||
                                    sourcing_rule_rec.source_organization_code;
                RAISE translation_error;
            END;
          END IF;
        END IF;
      
        IF sourcing_rule_rec.assign_to = 'Category-Organization' THEN
          v_step := 'Step 110';
          IF sourcing_rule_rec.category IS NULL THEN
            v_error_messsage := 'Missing Category for assignment_type=''Category-Organization''';
            RAISE translation_error;
          ELSE
            ----translate CATEGORY to CATEGORY_ID ---- for example 'Resins.R HE.Resins' to 32123
            BEGIN
              SELECT c.category_id
                INTO sourcing_rule_rec.category_id
                FROM mtl_categories_kfv c
               WHERE c.concatenated_segments = sourcing_rule_rec.category;
            EXCEPTION
              WHEN no_data_found THEN
                v_error_messsage := 'Category ' ||
                                    sourcing_rule_rec.category ||
                                    ' does not exist';
                RAISE translation_error;
            END;
          END IF;
        END IF;
      
        -- translate vendor id
      
        IF sourcing_rule_rec.vendor_name IS NOT NULL THEN
          v_step := 'Step 112';
          BEGIN
            SELECT c.vendor_id
              INTO sourcing_rule_rec.vendor_id
              FROM po_vendors c
             WHERE c.vendor_name = sourcing_rule_rec.vendor_name;
          EXCEPTION
            WHEN no_data_found THEN
              v_error_messsage := 'Vendor Id not found for vendor_name= ' ||
                                  sourcing_rule_rec.vendor_name;
              RAISE translation_error;
            WHEN OTHERS THEN
              v_error_messsage := 'Unable to find vendor site id :sourcing_rule_rec.vendor_name=' ||
                                  sourcing_rule_rec.vendor_name;
              RAISE translation_error;
          END;
        END IF;
        -- translate vendor site id
      
        IF sourcing_rule_rec.vendor_site_name IS NOT NULL THEN
          v_step := 'Step 114';
          BEGIN
            SELECT c.vendor_site_id
              INTO sourcing_rule_rec.vendor_site_id
              FROM ap_supplier_sites_all c
             WHERE c.vendor_site_code = sourcing_rule_rec.vendor_site_name
               AND c.vendor_id = sourcing_rule_rec.vendor_id;
          EXCEPTION
            WHEN no_data_found THEN
              v_error_messsage := 'Vendor site Id not found for vendor_site_name= ' ||
                                  sourcing_rule_rec.vendor_site_name;
              RAISE translation_error;
            WHEN OTHERS THEN
              v_error_messsage := 'Unable to find vendor site id :sourcing_rule_rec.vendor_id-' ||
                                  sourcing_rule_rec.vendor_id ||
                                  ' sourcing_rule_rec.vendor_site_name=' ||
                                  sourcing_rule_rec.vendor_site_name;
              RAISE translation_error;
            
          END;
        END IF;
        ---
      
        v_step := 'Step 120';
        UPDATE xxmrp_sr_assignments a
           SET a.organization_id          = sourcing_rule_rec.organization_id,
               a.source_organization_id   = sourcing_rule_rec.source_organization_id,
               a.receipt_organization_id  = sourcing_rule_rec.receipt_organization_id,
               a.shipping_organization_id = sourcing_rule_rec.shipping_organization_id,
               a.inventory_item_id        = sourcing_rule_rec.inventory_item_id,
               a.assignment_type          = sourcing_rule_rec.assignment_type,
               a.sourcing_rule_type       = sourcing_rule_rec.sourcing_rule_type,
               a.category_id              = sourcing_rule_rec.category_id,
               a.vendor_id                = sourcing_rule_rec.vendor_id,
               a.vendor_site_id           = sourcing_rule_rec.vendor_site_id
         WHERE ROWID = sourcing_rule_rec.row_id; ----
        v_validation_success_cntr := v_validation_success_cntr + 1;
      
      EXCEPTION
        WHEN translation_error THEN
          v_step := 'Step 130';
          UPDATE xxmrp_sr_assignments a
             SET err_code                   = 'E',
                 err_message                = v_error_messsage,
                 a.organization_id          = sourcing_rule_rec.organization_id,
                 a.source_organization_id   = sourcing_rule_rec.source_organization_id,
                 a.receipt_organization_id  = sourcing_rule_rec.receipt_organization_id,
                 a.shipping_organization_id = sourcing_rule_rec.shipping_organization_id,
                 a.inventory_item_id        = sourcing_rule_rec.inventory_item_id,
                 a.assignment_type          = sourcing_rule_rec.assignment_type,
                 a.sourcing_rule_type       = sourcing_rule_rec.sourcing_rule_type,
                 a.category_id              = sourcing_rule_rec.category_id,
                 a.vendor_id                = sourcing_rule_rec.vendor_id,
                 a.vendor_site_id           = sourcing_rule_rec.vendor_site_id
           WHERE ROWID = sourcing_rule_rec.row_id;
        
          v_validation_error_cntr := v_validation_error_cntr + 1;
        
      END;
      IF MOD(c_validate_data%ROWCOUNT, 500) = 0 THEN
        COMMIT;
      END IF;
      --------the end of TRANSLATIONS LOOP-------------------------
    END LOOP;
  
    COMMIT;
  
    v_step := 'Step 140';
    message('There are ' ||
            to_char(v_validation_success_cntr + v_validation_error_cntr) ||
            ' records in file ' || p_file_name || '==================');
    message('Validation status:');
    message('Successfully : ' || v_validation_success_cntr || ' records');
    message('Failed : ' || v_validation_error_cntr || ' records');
  
    ----Unexpected ERROR in xxconv_sourcing_rules_pkg.upload_sourcing_rules  
    ----  (Step 140) ORA-06502: PL/SQL: numeric or value error: character to number conversion error
  
    v_step := 'Step 150';
    IF v_validation_error_cntr > 0 THEN
      message('======================================================================================');
      message('Validation errors ====================================================================');
      message('======================================================================================');
      ---Print in LOG all validation errors
      FOR error_rec IN c_get_errors LOOP
        message('= Row ' || to_char(error_rec.row_no + 1) ||
                /* error_rec.sourcing_rule_id || '--' || error_rec.assign_to || '--' ||
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   error_rec.source_organization_code || '--' ||
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   error_rec.item || '--' || error_rec.category ||*/
                ':' || error_rec.err_message);
      END LOOP;
    END IF;
  
    v_step := 'Step 200';
    message('======================================================================================');
    message('Executing create rule  API in loop ===============================================');
    message('======================================================================================');
    FOR create_sr_rec IN c_process_data('Y') LOOP
      ---======================= CREATE SR RULE LOOP ===============================
      BEGIN
        v_step           := 'Step 200.2';
        v_error_messsage := NULL;
        ---get sourcing rule data-------
        OPEN c_get_sourcing_rule_data(CASE create_sr_rec.create_rule WHEN
                                      'DUPLICATE' THEN
                                      create_sr_rec.rule_name ||
                                      g_add_to_sr_name_str WHEN 'NEW' THEN
                                      create_sr_rec.rule_name END,
                                      create_sr_rec.source_organization_id);
      
        /* message('search for rule=' || CASE create_sr_rec.create_rule WHEN
        'DUPLICATE' THEN
        create_sr_rec.rule_name || g_add_to_sr_name_str WHEN 'NEW' THEN
        create_sr_rec.rule_name
        END || ' ' || 'org_id=' ||*/
        -- create_sr_rec.source_organization_id);
        l_sourcing_rule_data_rec := NULL;
        FETCH c_get_sourcing_rule_data
          INTO l_sourcing_rule_data_rec;
        CLOSE c_get_sourcing_rule_data;
        IF l_sourcing_rule_data_rec.sourcing_rule_id_new IS NOT NULL THEN
          -----new sourcing rule already exists------
          RAISE sourcing_rule_already_exists;
        ELSIF l_sourcing_rule_data_rec.sourcing_rule_id_new IS NULL THEN
          ---NOTFOUND----
          v_error_messsage := 'Sourcing_rule_id ' ||
                              create_sr_rec.sourcing_rule_id ||
                              ' does not exist';
          -- RAISE stop_create_sr;
        END IF;
        v_step := 'Step 200.3';
        fnd_message.clear;
        l_sourcing_rule_rec                    := mrp_sourcing_rule_pub.g_miss_sourcing_rule_rec;
        l_sourcing_rule_rec.sourcing_rule_name := CASE
                                                   create_sr_rec.create_rule
                                                    WHEN 'DUPLICATE' THEN
                                                     create_sr_rec.rule_name ||
                                                     g_add_to_sr_name_str
                                                    WHEN 'NEW' THEN
                                                     create_sr_rec.rule_name
                                                  END; --- for example: '_2'
        l_sourcing_rule_rec.organization_id    := create_sr_rec.source_organization_id;
        l_sourcing_rule_rec.planning_active    := 1; --l_sourcing_rule_data_rec.sourcing_rule_planning_active;
        l_sourcing_rule_rec.status             := 1; --l_sourcing_rule_data_rec.sourcing_rule_status;
        l_sourcing_rule_rec.sourcing_rule_type := 1; --l_sourcing_rule_data_rec.sourcing_rule_type;
        ---l_sourcing_rule_rec.sourcing_rule_id   := l_sourcing_rule_data_rec.sourcing_rule_id;
        l_sourcing_rule_rec.operation := 'CREATE';
        l_receiving_org_tbl           := mrp_sourcing_rule_pub.g_miss_receiving_org_tbl;
        l_shipping_org_tbl            := mrp_sourcing_rule_pub.g_miss_shipping_org_tbl;
        --l_receiving_org_tbl(1).Sr_Receipt_Id:=207;
        l_receiving_org_tbl(1).effective_date := trunc(SYSDATE) + 1;
        l_receiving_org_tbl(1).disable_date := NULL;
        l_receiving_org_tbl(1).receipt_organization_id := create_sr_rec.receipt_organization_id;
        l_receiving_org_tbl(1).operation := 'CREATE'; -- Create or Update
        --l_shipping_org_tbl(1).Sr_Source_Id:=228;
        l_shipping_org_tbl(1).rank := create_sr_rec.rank; --rl_sourcing_rule_data_rec.shipping_org_rank;
        l_shipping_org_tbl(1).allocation_percent := create_sr_rec.allocation_percent; --l_sourcing_rule_data_rec.ship_org_allocation_percent; ----100;
        l_shipping_org_tbl(1).source_type := create_sr_rec.sourcing_rule_type; --l_sourcing_rule_data_rec.shipping_org_source_type; ----3; -- BUY FROM
        l_shipping_org_tbl(1).vendor_id := nvl(create_sr_rec.vendor_id,
                                               fnd_api.g_miss_num);
        l_shipping_org_tbl(1).vendor_site_id := nvl(create_sr_rec.vendor_site_id,
                                                    fnd_api.g_miss_num);
        l_shipping_org_tbl(1).source_organization_id := create_sr_rec.shipping_organization_id;
        l_shipping_org_tbl(1).receiving_org_index := 1;
        l_shipping_org_tbl(1).operation := 'CREATE';
        l_shipping_org_tbl(1).ship_method := create_sr_rec.shipping_method; --- '000001_093_A_LTL';
      
        message('New sourcing_rule_name=' ||
                l_sourcing_rule_rec.sourcing_rule_name);
        ----Create SR API -----
        mrp_sourcing_rule_pub.process_sourcing_rule(p_api_version_number    => 1.0,
                                                    p_init_msg_list         => fnd_api.g_true,
                                                    p_commit                => fnd_api.g_true,
                                                    x_return_status         => l_return_status,
                                                    x_msg_count             => l_msg_count,
                                                    x_msg_data              => l_msg_data,
                                                    p_sourcing_rule_rec     => l_sourcing_rule_rec,
                                                    p_sourcing_rule_val_rec => l_sourcing_rule_val_rec,
                                                    p_receiving_org_tbl     => l_receiving_org_tbl,
                                                    p_receiving_org_val_tbl => l_receiving_org_val_tbl,
                                                    p_shipping_org_tbl      => l_shipping_org_tbl,
                                                    p_shipping_org_val_tbl  => l_shipping_org_val_tbl,
                                                    x_sourcing_rule_rec     => o_sourcing_rule_rec,
                                                    x_sourcing_rule_val_rec => o_sourcing_rule_val_rec,
                                                    x_receiving_org_tbl     => o_receiving_org_tbl,
                                                    x_receiving_org_val_tbl => o_receiving_org_val_tbl,
                                                    x_shipping_org_tbl      => o_shipping_org_tbl,
                                                    x_shipping_org_val_tbl  => o_shipping_org_val_tbl);
        IF l_return_status = fnd_api.g_ret_sts_success THEN
          ----Create SR API SUCCESS----
          UPDATE xxmrp_sr_assignments a
             SET a.sourcing_rule_id_new = o_sourcing_rule_rec.sourcing_rule_id --NEW CREATED SR RULE ID
           WHERE ROWID = create_sr_rec.row_id;
          /*message('************UPDATE xxmrp_sr_assignments SET sourcing_rule_id_new='||o_sourcing_rule_rec.sourcing_rule_id||
          ' WHERE group_id='||fnd_global.conc_request_id||
          ' AND sourcing_rule_id='||l_sourcing_rule_data_rec.sourcing_rule_id||
          ' AND .create_rule = 'Y'');*/
          v_created_sourcing_rules_cntr := v_created_sourcing_rules_cntr + 1;
        ELSE
          IF l_msg_count > 0 THEN
            v_error_messsage := NULL;
            FOR l_index IN 1 .. l_msg_count LOOP
              l_msg_data       := fnd_msg_pub.get(p_msg_index => l_index,
                                                  p_encoded   => fnd_api.g_false);
              v_error_messsage := v_error_messsage || ' ' || l_msg_data;
            END LOOP;
          END IF;
          ----Create SR API FAILURE-----
          /*   v_api_error_cntr := v_api_error_cntr + 1;
          message(create_sr_rec.sourcing_rule_id || '--' ||
                  create_sr_rec.assign_to || '--' ||
                  create_sr_rec.source_organization_code || '--' ||
                  create_sr_rec.item || '--' || create_sr_rec.category ||
                  '=======Create SR API ERROR: ' ||
                  substr(v_error_messsage, 1, 200));*/
          RAISE stop_create_sr;
        END IF;
      
      EXCEPTION
        WHEN sourcing_rule_already_exists THEN
          UPDATE xxmrp_sr_assignments a
             SET a.sourcing_rule_id_new = l_sourcing_rule_data_rec.sourcing_rule_id_new --NEW CREATED SR RULE ID
           WHERE ROWID = create_sr_rec.row_id;
        WHEN stop_create_sr THEN
          UPDATE xxmrp_sr_assignments
             SET err_code    = 'E',
                 err_message = substr(v_error_messsage, 1, 200)
           WHERE ROWID = create_sr_rec.row_id;
        
          v_api_error_cntr := v_api_error_cntr + 1;
          message('= Row ' || to_char(create_sr_rec.row_no + 1) || /*create_sr_rec.sourcing_rule_id || '--' ||
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     create_sr_rec.assign_to || '--' ||
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     create_sr_rec.source_organization_code || '--' ||
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     create_sr_rec.item || '--' || create_sr_rec.category */
                  '=======Create SR API ERROR: ' ||
                  substr(v_error_messsage, 1, 200));
      END;
      IF MOD(c_process_data%ROWCOUNT, 500) = 0 THEN
        COMMIT;
      END IF;
      ---==================the end of CREATE SR RULE LOOP ===============================
    END LOOP;
    COMMIT;
  
    v_step := 'Step 300';
    message('======================================================================================');
    message('Executing rule assignment  API in loop ===============================================');
    message('======================================================================================');
    FOR sr_assignment_rec IN c_process_data('N') LOOP
      ---===================== RULE ASSIGNMENT LOOP =====================================
      BEGIN
        v_error_messsage := NULL;
      
        fnd_message.clear;
        v_step := 'Step 300.2';
        /*  message('assignment_set_id=='||sr_assignment_rec.assignment_set_id);
        message('assignment_type=='||sr_assignment_rec.assignment_type);
        message('inventory_item_id=='||sr_assignment_rec.inventory_item_id);
        message('organization_id=='||sr_assignment_rec.organization_id);
        message('sourcing_rule_id=='||sr_assignment_rec.sourcing_rule_id);
        message('category_id=='||sr_assignment_rec.category_id);
          message('category_set_id=='||sr_assignment_rec.category_set_id);
        message('sourcing_rule_id=='||CASE nvl(sr_assignment_rec.create_rule,
                                                    'N')
                                                 WHEN 'DUPLICATE' THEN
                                                  sr_assignment_rec.sourcing_rule_id_new
                                                 WHEN 'NEW' THEN
                                                  sr_assignment_rec.sourcing_rule_id_new
                                                 ELSE
                                                  sr_assignment_rec.sourcing_rule_id
                                               END);*/
      
        l_assignment_tbl(1).assignment_set_id := sr_assignment_rec.assignment_set_id;
        l_assignment_tbl(1).assignment_type := sr_assignment_rec.assignment_type;
        l_assignment_tbl(1).operation := 'CREATE';
        l_assignment_tbl(1).organization_id := sr_assignment_rec.organization_id;
        l_assignment_tbl(1).category_id := sr_assignment_rec.category_id;
        l_assignment_tbl(1).category_set_id := 1100000041; --sr_assignment_rec.category_set_id;--1100000041
        l_assignment_tbl(1).inventory_item_id := sr_assignment_rec.inventory_item_id;
        l_assignment_tbl(1).sourcing_rule_id := CASE nvl(sr_assignment_rec.create_rule,
                                                     'N')
                                                  WHEN 'DUPLICATE' THEN
                                                   sr_assignment_rec.sourcing_rule_id_new
                                                  WHEN 'NEW' THEN
                                                   sr_assignment_rec.sourcing_rule_id_new
                                                  ELSE
                                                   sr_assignment_rec.sourcing_rule_id
                                                END;
        l_assignment_tbl(1).sourcing_rule_type := 1;
      
        v_step := 'Step 300.100';
        ---SR Assignment API --------
        mrp_src_assignment_pub.process_assignment(p_api_version_number     => 1.0,
                                                  p_init_msg_list          => fnd_api.g_true,
                                                  p_return_values          => fnd_api.g_true,
                                                  p_commit                 => fnd_api.g_false,
                                                  x_return_status          => l_return_status,
                                                  x_msg_count              => l_msg_count,
                                                  x_msg_data               => l_msg_data,
                                                  p_assignment_set_rec     => l_assignment_set_rec,
                                                  p_assignment_set_val_rec => l_assignment_set_val_rec,
                                                  p_assignment_tbl         => l_assignment_tbl,
                                                  p_assignment_val_tbl     => l_assignment_val_tbl,
                                                  x_assignment_set_rec     => o_assignment_set_rec,
                                                  x_assignment_set_val_rec => o_assignment_set_val_rec,
                                                  x_assignment_tbl         => o_assignment_tbl,
                                                  x_assignment_val_tbl     => o_assignment_val_tbl);
      
        IF l_return_status = fnd_api.g_ret_sts_success THEN
          ---SR Assignment API SUCCESS---
          v_step := 'Step 300.120';
          UPDATE xxmrp_sr_assignments
             SET err_code = 'S'
           WHERE ROWID = sr_assignment_rec.row_id;
          v_created_assignments_cntr := v_created_assignments_cntr + 1;
        ELSE
          ---SR Assignment API ERROR
          v_step := 'Step 300.130';
          IF l_msg_count > 0 THEN
            v_error_messsage := NULL;
            FOR l_index IN 1 .. l_msg_count LOOP
              l_msg_data       := fnd_msg_pub.get(p_msg_index => l_index,
                                                  p_encoded   => fnd_api.g_false);
              v_error_messsage := v_error_messsage || ' ' || l_msg_data;
            END LOOP;
          END IF;
          v_api_error_cntr := v_api_error_cntr + 1;
          message('= Row ' || to_char(sr_assignment_rec.row_no + 1) || ---sr_assignment_rec.sourcing_rule_id || '--''' ||
                  /*l_assignment_tbl(1)
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        .sourcing_rule_id || '--''' || sr_assignment_rec.assign_to ||
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         '''--''' || sr_assignment_rec.organization_code ||
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         '''--''' || sr_assignment_rec.item || '''--' ||
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         sr_assignment_rec.category ||*/
                  '== SR Assignment API ERROR: ' ||
                  substr(v_error_messsage, 1, 200));
          RAISE stop_sr_assignment;
        END IF;
      EXCEPTION
        WHEN stop_sr_assignment THEN
          v_step := 'Step 300.140';
          UPDATE xxmrp_sr_assignments
             SET err_code    = 'E',
                 err_message = substr(v_error_messsage, 1, 200)
           WHERE ROWID = sr_assignment_rec.row_id;
      END;
      IF MOD(c_process_data%ROWCOUNT, 500) = 0 THEN
        COMMIT;
      END IF;
      ---===============the end of RULE ASSIGNMENT LOOP =====================================
    END LOOP;
    COMMIT;
  
    v_step := 'Step 400';
    message('RESULTS ==============================================================================');
    message(v_created_sourcing_rules_cntr || ' sourcing rules and ' ||
            v_created_assignments_cntr ||
            ' assignments are CREATED SUCCESSFULLY.');
    IF v_validation_error_cntr > 0 OR v_api_error_cntr > 0 THEN
      message(v_validation_error_cntr || ' invalid records in your file. ' ||
              v_api_error_cntr ||
              ' API Errors. See concurrent program log ');
      retcode := '1';
      errbuf  := v_validation_error_cntr ||
                 ' invalid records in your file. ' || v_api_error_cntr ||
                 ' API Errors. See concurrent program log ';
    ELSE
      message('Concurrent program was completed successfully ========================================');
    END IF;
    message('======================================================================================');
  
    -----------------------------------------------------------
  
  EXCEPTION
    WHEN stop_processing THEN
      v_error_messsage := 'ERROR in xxconv_sourcing_rules_pkg.upload_sourcing_rules : ' ||
                          v_error_messsage;
      message(v_error_messsage);
      retcode := '2';
      errbuf  := v_error_messsage;
    WHEN OTHERS THEN
      message(v_error_messsage);
      v_error_messsage := substr('Unexpected ERROR in xxconv_sourcing_rules_pkg.upload_sourcing_rules  (' ||
                                 v_step || ') ' || SQLERRM,
                                 1,
                                 200);
      message(v_error_messsage);
      retcode := '2';
      errbuf  := v_error_messsage;
  END upload_sourcing_rules;
  ----------------------------------------------------------------------------------------- 
END xxconv_sourcing_rules_pkg;
/
