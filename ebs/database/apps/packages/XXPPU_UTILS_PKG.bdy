create or replace package body xxppu_utils_pkg IS
  ------------------------------------------------------------------------------------------
  -- Ver     When         Who             Description
  -- ------  -----------  -------------   --------------------------------------------------
  -- 1.0     2019-08-11   Roman W.        CHG0045829
  -- 1.1                                     removed %_TBL
  -- 1.2     2019-09-01   Roman W.        CHG0045829 -> added printer_part_number_id;
  -- 1.3     10.9.2019    Bellona B.      CHG0046049 - added get_so_order_type, get_so_line_type,
  --                                      is_system_item, is_material_item, check_ppu_system_item  
  ------------------------------------------------------------------------------------------  

  ------------------------------------------------------------------------------------------
  -- Ver     When         Who             Description
  -- ------  -----------  -------------   --------------------------------------------------
  -- 1.0     2019-08-11   Roman W.        CHG0045829
  ------------------------------------------------------------------------------------------  
  PROCEDURE message(p_msg IN VARCHAR2) IS
    ---------------------------------
    --      Local Definition
    ---------------------------------
    l_msg VARCHAR2(2000);
    ---------------------------------
    --      Code Section
    ---------------------------------    
  BEGIN
    l_msg := to_char(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') || ' - ' || p_msg;
  
    IF -1 = fnd_global.conc_request_id THEN
      dbms_output.put_line(l_msg);
    ELSE
      fnd_file.put_line(fnd_file.log, l_msg);
    END IF;
  
  END message;
  ------------------------------------------------------------------------------------------
  -- Ver     When         Who             Description
  -- ------  -----------  -------------   --------------------------------------------------
  -- 1.0     2019-08-11   Roman W.        CHG0045829
  ------------------------------------------------------------------------------------------  
  FUNCTION get_last_run_date RETURN DATE IS
    ---------------------------------
    --     Local Definition
    ---------------------------------    
    l_ret_val       DATE;
    l_profile_value VARCHAR2(300);
    ---------------------------------
    --     Code Section
    ---------------------------------
  BEGIN
    l_profile_value := fnd_profile.value('XXPPU_LAST_RUN_DATE');
    IF l_profile_value IS NOT NULL THEN
      l_ret_val := to_date(l_profile_value, c_last_run_date_format);
    ELSE
      l_ret_val := SYSDATE - 10;
    END IF;
  
    message('xxppu_utils_pkg.get_last_run_date => ' ||
    to_char(l_ret_val, 'YYYY-MM-DD HH24:MI:SS'));
  
    RETURN l_ret_val;
  
  END get_last_run_date;
  ------------------------------------------------------------------------------------------
  -- Ver     When         Who             Description
  -- ------  -----------  -------------   --------------------------------------------------
  -- 1.0     2019-08-11   Roman W.        CHG0045829
  ------------------------------------------------------------------------------------------  
  PROCEDURE set_last_run_date(p_last_run_date DATE,
              p_error_desc    OUT VARCHAR2,
              p_error_code    OUT VARCHAR2) IS
    l_last_run_date VARCHAR2(255);
    l_success       BOOLEAN;
  BEGIN
    p_error_desc := NULL;
    p_error_code := '0';
  
    l_last_run_date := to_char(p_last_run_date, c_last_run_date_format);
  
    l_success := fnd_profile.save(x_name               => 'XXPPU_LAST_RUN_DATE',
                  x_value              => l_last_run_date,
                  x_level_name         => 'SITE',
                  x_level_value        => NULL,
                  x_level_value_app_id => NULL);
  
    IF NOT l_success THEN
      p_error_desc := 'xxppu_utils_pkg.set_last_run_date(' ||
              p_last_run_date ||
              ') - Profile Update Failed at site Level. Error:' ||
              SQLERRM;
    
      p_error_code := '2';
    
      message(p_error_desc);
    ELSE
      COMMIT;
      message('xxppu_utils_pkg.set_last_run_date(' ||
      to_char(p_last_run_date, 'YYYY-MM-DD HH24:MI:SS') || ')');
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      p_error_desc := 'EXCEPTION OTHERS xxppu_utils_pkg.set_last_run_date(' ||
              p_last_run_date || ') - ' || SQLERRM;
      p_error_code := '2';
    
      message(p_error_desc);
    
  END;
  ------------------------------------------------------------------------------------------
  -- Ver     When         Who             Description
  -- ------  -----------  -------------   --------------------------------------------------
  -- 1.0     2019-08-11   Roman W.        CHG0045829
  ------------------------------------------------------------------------------------------  
  PROCEDURE init_for_test IS
    ---------------------------
    --     Code Section
    ---------------------------
  BEGIN
  
    fnd_global.apps_initialize(22797, 50623, 660);
    mo_global.init('ONT');
  
  END init_for_test;

  ------------------------------------------------------------------------------------------
  -- Ver     When       Who           Description
  -- ------  ---------  ------------  ------------------------------------------------------
  -- 1.0     2019-08-11   Roman W.        CHG0045829      
  ------------------------------------------------------------------------------------------
  PROCEDURE insert_header(p_header     IN OUT xxppu_headers%ROWTYPE,
          p_error_code OUT VARCHAR2,
          p_error_desc OUT VARCHAR2) IS
    ----------------------------
    --   Local Definition
    ----------------------------                          
    --  l_ppu_header_id NUMBER;
    ----------------------------
    --    Code Section
    ----------------------------                          
  BEGIN
    p_error_code := '0';
    p_error_desc := NULL;
  
    p_header.created_by        := fnd_global.user_id;
    p_header.creation_date     := SYSDATE;
    p_header.last_updated_by   := fnd_global.user_id;
    p_header.last_update_date  := SYSDATE;
    p_header.last_update_login := fnd_global.login_id;
  
    p_header.ppu_header_id := xxppu_headers_seq.nextval;
  
    message('xxppu_utils_pkg.insert_header :' || chr(10) ||
    '   ppu_header_id          :' || p_header.ppu_header_id ||
    chr(10) || '   printer_sn             :' ||
    p_header.printer_sn || chr(10) ||
    '   customer_number        :' || p_header.customer_number ||
    chr(10) || '   org_id                 :' || p_header.org_id ||
    chr(10) || '   printer_part_number_id :' ||
    p_header.printer_part_number_id || chr(10) ||
    '   contract_enable_flag   :' || p_header.contract_enable_flag ||
    chr(10) || '   header_id              :' || p_header.header_id ||
    chr(10) || '   order_number           :' ||
    p_header.order_number || chr(10) ||
    '   delivery_id            :' || p_header.delivery_id ||
    chr(10) || '   delivery_name          :' ||
    p_header.delivery_name || chr(10) ||
    '--------------------------------------------------------');
  
    INSERT INTO xxppu_headers
    VALUES p_header;
  
    COMMIT;
  
  EXCEPTION
    WHEN OTHERS THEN
      p_error_code := '2';
      p_error_desc := 'EXCEPTION_OTHERS XXPPU_UTILS_PKG.insert_header() - ' ||
              SQLERRM;
      message(p_error_desc);
  END insert_header;
  ------------------------------------------------------------------------------------------
  -- Ver     When       Who           Description
  -- ------  ---------  ------------  ------------------------------------------------------
  -- 1.0     2019-08-11   Roman W.        CHG0045829      
  ------------------------------------------------------------------------------------------
  PROCEDURE insert_line(p_line_row   IN OUT xxppu_lines%ROWTYPE,
        p_error_code OUT VARCHAR2,
        p_error_desc OUT VARCHAR2) IS
    -------------------------
    --    Code Section
    -------------------------
  BEGIN
  
    p_error_code := '0';
    p_error_desc := NULL;
  
    p_line_row.ppu_line_id       := xxppu_lines_seq.nextval;
    p_line_row.created_by        := fnd_global.user_id;
    p_line_row.creation_date     := SYSDATE;
    p_line_row.last_updated_by   := fnd_global.user_id;
    p_line_row.last_update_date  := SYSDATE;
    p_line_row.last_update_login := fnd_global.login_id;
  
    message('xxppu_utils_pkg.insert_line:' || chr(10) ||
    '    ppu_header_id        : ' || p_line_row.ppu_header_id ||
    chr(10) || '    ppu_line_id          : ' ||
    p_line_row.ppu_line_id || chr(10) ||
    '    material_part_number : ' ||
    p_line_row.material_part_number || chr(10) ||
    '---------------------------------------------------------');
  
    INSERT INTO xxppu_lines
    VALUES p_line_row;
  
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      p_error_code := '2';
      p_error_desc := 'EXCEPTION_OTHERS XXPPU_UTILS_PKG.insert_line() - ' ||
              SQLERRM;
      message(p_error_desc);
  END insert_line;
  ------------------------------------------------------------------------------------------
  -- Ver     When       Who           Description
  -- ------  ---------  ------------  ------------------------------------------------------
  -- 1.0     2019-08-11   Roman W.    CHG0045829      
  -- 1.1     2019-09-01   Roman W.    CHG0045829 - added printer_part_number_id 
  ------------------------------------------------------------------------------------------
  PROCEDURE is_line_exists(p_line          IN OUT xxppu_lines%ROWTYPE,
           p_existing_flag OUT VARCHAR2,
           p_error_code    OUT VARCHAR2,
           p_error_desc    OUT VARCHAR2) IS
    ------------------------------
    --     Local Definiiton
    ------------------------------
    l_ppu_line_id NUMBER;
    ------------------------------
    --     Code Secton
    ------------------------------
  BEGIN
    p_error_code := '0';
    p_error_desc := NULL;
  
    SELECT xlt.ppu_line_id
    INTO   l_ppu_line_id
    FROM   xxppu_lines xlt
    WHERE  xlt.ppu_header_id = p_line.ppu_header_id
    AND    xlt.material_part_id = p_line.material_part_id;
  
    p_line.ppu_line_id := l_ppu_line_id;
  
    p_existing_flag := 'Y';
    --    message('is_line_exists( ppu_header_id : ' || p_line.ppu_header_id ||
    --            ', material_part_id : ' || p_line.material_part_id || ') =' ||
    --            p_existing_flag);
  EXCEPTION
    WHEN no_data_found THEN
      p_existing_flag := 'N';
      message('is_line_exists( ppu_header_id : ' || p_line.ppu_header_id ||
      ', material_part_id : ' || p_line.material_part_id || ') =' ||
      p_existing_flag);
    WHEN OTHERS THEN
      p_error_code := '2';
      p_error_desc := 'XXPPU_UTILS_PKG.is_line_exists(' ||
              p_line.ppu_header_id || ')-' || SQLERRM;
      message(p_error_desc);
    
  END is_line_exists;

  ------------------------------------------------------------------------------------------
  -- Ver     When       Who           Description
  -- ------  ---------  ------------  ------------------------------------------------------
  -- 1.0     2019-08-11   Roman W.    CHG0045829      
  ------------------------------------------------------------------------------------------
  PROCEDURE is_header_exists(p_header        IN OUT xxppu_headers%ROWTYPE,
             p_existing_flag OUT VARCHAR2,
             p_error_code    OUT VARCHAR2,
             p_error_desc    OUT VARCHAR2) IS
    ----------------------------
    --     Local Definition
    ----------------------------
    ppu_header_id NUMBER;
    ----------------------------
    --     Code Section
    ----------------------------
  BEGIN
    p_error_code := '0';
    p_error_desc := NULL;
  
    SELECT xht.ppu_header_id
    INTO   ppu_header_id
    FROM   xxppu_headers xht
    WHERE  xht.header_id = p_header.header_id
    AND    xht.printer_part_number_id = p_header.printer_part_number_id
    AND    xht.printer_sn = p_header.printer_sn;
  
    p_existing_flag        := 'Y';
    p_header.ppu_header_id := ppu_header_id;
  
  EXCEPTION
    WHEN no_data_found THEN
      p_existing_flag := 'N';
    
    WHEN OTHERS THEN
      p_error_code := '2';
      p_error_desc := 'EXCEPTION_OTHERS XXPPU_UTILS_PKG.is_header_exist() - ' ||
              SQLERRM;
      message(p_error_desc);
  END is_header_exists;
  ------------------------------------------------------------------------------------------
  -- Ver     When         Who             Description
  -- ------  -----------  -------------   --------------------------------------------------
  -- 1.0     2019-08-28   Roman W.        CHG0045829
  ------------------------------------------------------------------------------------------    
  FUNCTION get_qubic_inch_per_unit(p_material_part_id NUMBER) RETURN NUMBER IS
    l_ret_value NUMBER;
    --------------------------------
    --      Code Section
    --------------------------------
  BEGIN
    l_ret_value := 0;
  
    SELECT to_number(nvl(mdev.element_value, 0))
    INTO   l_ret_value
    FROM   mtl_descr_element_values_v mdev
    WHERE  mdev.element_name = 'Volume Factor (CI)'
    AND    mdev.inventory_item_id = p_material_part_id;
  
    RETURN l_ret_value;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN 0;
    WHEN OTHERS THEN
      RETURN NULL;
      message('EXCEPTION_OTHERS XXPPU_UTILS_PKG.get_qubic_inch_per_unit(' ||
      p_material_part_id || ') - ' || SQLERRM);
    
  END get_qubic_inch_per_unit;
  --------------------------------------------------------------------------------------
  -- Ver     When         Who             Description
  -- ------  -----------  --------------  ----------------------------------------------
  -- 1.0     2019-09-01   Roman W.        CHG0045829
  --------------------------------------------------------------------------------------
  PROCEDURE is_contract_active(p_printer_part_number_id IN NUMBER,
               p_printer_sn             IN VARCHAR2,
               p_account_number         IN VARCHAR2,
               p_contract_flag          OUT VARCHAR2,
               p_error_desc             OUT VARCHAR2,
               p_error_code             OUT VARCHAR2) IS
    -----------------------------
    --    Code Section
    -----------------------------
  BEGIN
    p_error_desc := NULL;
    p_error_code := NULL;
  
    SELECT decode(cii.contract_status, 'Active', 'Y', 'Inactive', 'N', 'N')
    INTO   p_contract_flag
    FROM   xxsf_csi_item_instances cii
    WHERE  cii.inventory_item_id = p_printer_part_number_id
    AND    cii.serial_number = p_printer_sn
    AND    trunc(SYSDATE) BETWEEN cii.contract_start_date AND
           cii.contract_end_date
    AND    (p_account_number = cii.account_end_customer_num OR
          p_account_number = cii.owner_account_number);
  
  EXCEPTION
    WHEN no_data_found THEN
      p_contract_flag := 'N';
    WHEN OTHERS THEN
      p_error_desc := 'EXCEPTION_OTHERS xxppu_utils_pkg.is_contract_activ(' ||
              p_printer_part_number_id || ',' || chr(10) ||
              p_printer_sn || ')- ' || SQLERRM;
      p_error_code := '2';
    
      message(p_error_desc);
    
  END is_contract_active;
  ------------------------------------------------------------------------------------------
  -- Ver     When         Who             Description
  ------------------------------------------------------------------------------------------
  -- 1.0     2019-09-03   Roman W.        CHG0045829
  ------------------------------------------------------------------------------------------
  PROCEDURE set_header_line_data(p_last_run_date IN DATE,
                 p_error_desc    OUT VARCHAR2,
                 p_error_code    OUT VARCHAR2) IS
    ----------------------------
    --   Local Definition
    ----------------------------
  
    CURSOR c_ppu_header(c_last_run_date DATE) IS
      SELECT ooh.header_id,
     ooh.order_number,
     ooh.org_id,
     wsn.fm_serial_number  printer_serial_number,
     ooh.customer_number,
     ool.inventory_item_id printer_part_number_id,
     wddov.delivery_id,
     wddov.delivery_name
      FROM   oe_order_headers_v        ooh,
     oe_order_lines_all        ool,
     xxcs_items_printers_v     xip,
     wsh_delivery_details_oe_v wddov,
     wsh_delivery_details      wdd,
     wsh_serial_numbers        wsn
      WHERE  ooh.order_type LIKE ('%PPU Order%')
      AND    ool.header_id = ooh.header_id
      AND    xip.inventory_item_id = ool.inventory_item_id
      AND    xip.item_type = 'PRINTER'
      AND    wddov.source_line_id = ool.line_id
      AND    wddov.source_header_id = ooh.header_id
      AND    wdd.delivery_detail_id = wddov.delivery_detail_id
      AND    wsn.delivery_detail_id = wdd.delivery_detail_id
      AND    wdd.last_update_date >= c_last_run_date;
  
    ------------ Lines -----------
    CURSOR c_xxppu_lines(c_printer_part_number_id NUMBER) IS
      SELECT xpm.material_part_id,
     xpm.material_part_number,
     xpm.material_part_descr,
     xpm.material_type
      FROM   xxppu_printer_materials_v xpm
      WHERE  xpm.printer_part_number_id = c_printer_part_number_id;
  
    l_header_row              xxppu_headers%ROWTYPE;
    l_line_row                xxppu_lines%ROWTYPE;
    l_header_existing_flag    VARCHAR2(10);
    l_line_existing_flag      VARCHAR2(10);
    l_contract_enable_flag    VARCHAR2(10);
    l_ordered_quantity        NUMBER;
    l_mater_unit_to_replenish NUMBER;
    ----------------------------
    --    Code Section
    ----------------------------
  BEGIN
    p_error_desc := NULL;
    p_error_code := '0';
  
    message('xxppu_utils_pkg.set_header_line_data(' ||
    to_char(p_last_run_date, 'YYYY-MM-DD HH24:MI:SS') || ')');
  
    FOR header_ind IN c_ppu_header(p_last_run_date) LOOP
    
      l_header_row := NULL;
    
      is_contract_active(p_printer_part_number_id => header_ind.printer_part_number_id,
         p_printer_sn             => header_ind.printer_serial_number,
         p_contract_flag          => l_contract_enable_flag,
         p_account_number         => header_ind.customer_number,
         p_error_desc             => p_error_desc,
         p_error_code             => p_error_code);
    
      l_header_row.printer_sn             := header_ind.printer_serial_number;
      l_header_row.customer_number        := header_ind.customer_number;
      l_header_row.printer_part_number_id := header_ind.printer_part_number_id;
      l_header_row.org_id                 := header_ind.org_id;
      l_header_row.contract_enable_flag   := l_contract_enable_flag;
      l_header_row.header_id              := header_ind.header_id;
      l_header_row.order_number           := header_ind.order_number;
      l_header_row.delivery_id            := header_ind.delivery_id;
      l_header_row.delivery_name          := header_ind.delivery_name;
    
      is_header_exists(p_header        => l_header_row,
               p_existing_flag => l_header_existing_flag,
               p_error_code    => p_error_desc,
               p_error_desc    => p_error_code);
    
      IF '0' != p_error_code THEN
        RETURN;
      END IF;
    
      IF 'N' = l_header_existing_flag THEN
      
        insert_header(l_header_row, p_error_code, p_error_desc);
      
        IF '0' != p_error_code THEN
          RETURN;
        END IF;
      END IF;
    
      ----------------------------------------------------------
      --- Lines  ---
      ----------------------------------------------------------    
      FOR line_ind IN c_xxppu_lines(header_ind.printer_part_number_id) LOOP
      
        l_line_row := NULL;
      
        SELECT nvl(SUM(ool_sub.ordered_quantity), 0) ordered_quantity,
       nvl(SUM(ool_sub.shipped_quantity), 0) material_units_to_replenish
        INTO   l_ordered_quantity,
       l_mater_unit_to_replenish
        FROM   oe_order_lines ool_sub
        WHERE  ool_sub.header_id = header_ind.header_id
        AND    ool_sub.inventory_item_id = line_ind.material_part_id
        AND    nvl(ool_sub.cancelled_flag, 'N') = 'N';
      
        -- init line data --      
        l_line_row.ppu_header_id            := l_header_row.ppu_header_id;
        l_line_row.material_part_id         := line_ind.material_part_id;
        l_line_row.material_part_number     := line_ind.material_part_number;
        l_line_row.material_type            := line_ind.material_type;
        l_line_row.material_units_to_replen := l_mater_unit_to_replenish;
        l_line_row.material_enable_flag     := c_yes;
      
        is_line_exists(p_line          => l_line_row,
               p_existing_flag => l_line_existing_flag,
               p_error_code    => p_error_code,
               p_error_desc    => p_error_desc);
      
        IF '0' != p_error_code THEN
          RETURN;
        END IF;
      
        IF 'N' = l_line_existing_flag THEN
        
          insert_line(p_line_row   => l_line_row,
              p_error_code => p_error_code,
              p_error_desc => p_error_desc);
        
          IF '0' != p_error_code THEN
    RETURN;
          END IF;
        END IF;
      
      END LOOP;
    END LOOP;
  
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      p_error_code := '2';
      p_error_desc := 'EXCEPTION_OTHERS xxppu_utils_pkg.set_header_line_data(' ||
              to_char(p_last_run_date, 'YYYY-MM-DD HH24:MI:SS') ||
              ') - ' || SQLERRM;
      message(p_error_desc);
  END set_header_line_data;
  ------------------------------------------------------------------------------------------
  -- Ver     When         Who             Description
  -- ------  -----------  -------------   --------------------------------------------------
  -- 1.0     2019-08-11   Roman W.        CHG0045829
  ------------------------------------------------------------------------------------------
  PROCEDURE set_contract_flag(p_error_desc OUT VARCHAR2,
              p_error_code OUT VARCHAR2) IS
    -----------------------------
    --     Local Definition
    -----------------------------
    CURSOR c_xxppu_headers_contracts IS
      SELECT xh.ppu_header_id,
     xh.printer_part_number_id,
     xh.printer_sn,
     xh.contract_enable_flag,
     xh.customer_number
      FROM   xxppu_headers xh;
  
    l_contract_enable_flag VARCHAR2(10);
  
    -----------------------------
    --     Code Section
    -----------------------------
  BEGIN
  
    message('xxppu_utils_pkg.xxppu_utils_pkg()');
  
    FOR contract_ind IN c_xxppu_headers_contracts LOOP
    
      is_contract_active(p_printer_part_number_id => contract_ind.printer_part_number_id,
         p_printer_sn             => contract_ind.printer_sn,
         p_contract_flag          => l_contract_enable_flag,
         p_account_number         => contract_ind.customer_number,
         p_error_desc             => p_error_desc,
         p_error_code             => p_error_code);
      IF '0' != p_error_code THEN
        RETURN;
      END IF;
    
      IF contract_ind.contract_enable_flag != l_contract_enable_flag THEN
      
        UPDATE xxppu_headers xh
        SET    xh.contract_enable_flag = l_contract_enable_flag,
       xh.last_update_date     = SYSDATE,
       xh.last_updated_by      = fnd_global.user_id,
       xh.last_update_login    = fnd_global.login_id
        WHERE  xh.ppu_header_id = contract_ind.ppu_header_id
        AND    xh.printer_part_number_id =
       contract_ind.printer_part_number_id
        AND    xh.printer_sn = contract_ind.printer_sn;
      
      END IF;
    END LOOP;
  
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      p_error_desc := 'EXCEPTION_OTHERS xxppu_utils_pkg.set_contract_flag() - ' ||
              SQLERRM;
      p_error_code := '2';
      message(p_error_desc);
  END set_contract_flag;
  ------------------------------------------------------------------------------------------
  -- Ver     When         Who             Description
  -- ------  -----------  -------------   --------------------------------------------------
  -- 1.0     2019-08-11   Roman W.        CHG0045829
  -------------------------------------------------------------------------------------------  
  PROCEDURE set_material_flag_to_disable(p_error_desc OUT VARCHAR2,
                 p_error_code OUT VARCHAR2) IS
    ------------------------------
    --    Local Definition
    ------------------------------
    CURSOR c_disabled_matireal IS
      SELECT xlt.material_part_id,
     ppuh.printer_part_number_id
      FROM   xxppu_lines   xlt,
     xxppu_headers ppuh
      WHERE  ppuh.ppu_header_id = xlt.ppu_header_id
      MINUS
      SELECT xpm.material_part_id,
     xpm.printer_part_number_id
      FROM   xxppu_printer_materials_v xpm;
  
    ------------------------------
    --    Code Section
    ------------------------------
  BEGIN
    p_error_desc := NULL;
    p_error_code := '0';
  
    message('xxppu_utils_pkg.set_material_flag_to_disable()');
  
    FOR disabled_matireal_ind IN c_disabled_matireal LOOP
    
      UPDATE xxppu_lines l
      SET    l.material_enable_flag = 'N',
     l.last_update_date     = SYSDATE,
     l.last_updated_by      = fnd_global.user_id,
     l.last_update_login    = fnd_global.login_id
      WHERE  l.material_part_id = disabled_matireal_ind.material_part_id;
    
    END LOOP;
  
    COMMIT;
  
  EXCEPTION
    WHEN OTHERS THEN
      p_error_desc := 'EXCEPTION_OTHERS xxppu_utils_pkg.disable_material() - ' ||
              SQLERRM;
      p_error_code := '2';
      message(p_error_desc);
  END set_material_flag_to_disable;

  ------------------------------------------------------------------------------------------
  -- Ver     When         Who             Description
  -- ------  -----------  -------------   --------------------------------------------------
  -- 1.0     2019-08-11   Roman W.        CHG0045829
  -------------------------------------------------------------------------------------------  
  PROCEDURE add_empty_material_to_line(p_error_desc OUT VARCHAR2,
               p_error_code OUT VARCHAR2) IS
    -----------------------------
    --     Local Definition
    -----------------------------
    CURSOR c_printer_sn_list IS
      SELECT xh.ppu_header_id,
     xh.printer_part_number_id
      FROM   xxppu_headers xh
      WHERE  xh.contract_enable_flag = 'Y';
  
    ------------ Add Missing Printer Material --------------       
    CURSOR c_add_material(c_printer_part_number_id NUMBER,
          c_ppu_header_id          NUMBER) IS
      SELECT xpm.material_part_id,
     xpm.printer_part_number_id
      FROM   xxppu_printer_materials_v xpm
      WHERE  xpm.printer_part_number_id = c_printer_part_number_id
      MINUS
      SELECT xlt.material_part_id,
     ppuh.printer_part_number_id
      FROM   xxppu_lines   xlt,
     xxppu_headers ppuh
      WHERE  ppuh.ppu_header_id = xlt.ppu_header_id
      AND    xlt.ppu_header_id = c_ppu_header_id;
  
    l_line_row xxppu_lines%ROWTYPE;
    -----------------------------
    --     Code Section
    -----------------------------
  BEGIN
    p_error_desc := NULL;
    p_error_code := '0';
  
    message('xxppu_utils_pkg.add_empty_material_to_line()');
  
    FOR printer_sn_list IN c_printer_sn_list LOOP
      FOR add_matireal_ind IN c_add_material(printer_sn_list.printer_part_number_id,
                     printer_sn_list.ppu_header_id) LOOP
      
        l_line_row := NULL;
      
        SELECT printer_sn_list.ppu_header_id,
       xpm.material_part_id,
       xpm.material_part_number,
       xpm.material_type,
       0 mater_unit_to_replenish
        INTO   l_line_row.ppu_header_id,
       l_line_row.material_part_id,
       l_line_row.material_part_number,
       l_line_row.material_type,
       l_line_row.material_units_to_replen
        FROM   xxppu_printer_materials_v xpm
        WHERE  xpm.printer_part_number_id =
       add_matireal_ind.printer_part_number_id
        AND    xpm.material_part_id = add_matireal_ind.material_part_id;
      
        l_line_row.material_enable_flag := c_yes;
      
        insert_line(p_line_row   => l_line_row,
            p_error_code => p_error_code,
            p_error_desc => p_error_desc);
      
        IF '0' != p_error_code THEN
          RETURN;
        END IF;
      
      END LOOP;
    
    END LOOP;
  EXCEPTION
    WHEN OTHERS THEN
    
      p_error_desc := 'EXCEPTION_OTHERS xxppu_utils_pkg.add_empty_material_to_line() - ' ||
              SQLERRM;
      p_error_code := '0';
    
      message(p_error_desc);
    
  END add_empty_material_to_line;

  ------------------------------------------------------------------------------------------
  -- Ver     When         Who             Description
  -- ------  -----------  -------------   --------------------------------------------------
  -- 1.0     2019-08-11   Roman W.        CHG0045829
  -- 1.1     2019-08-29   Roman W.        CHG0045829 removed 
  --                                             XXPPU_LINES.material_part_descr 
  -- 1.2     2019-09-01   Roman W.        CHG0045829 -> added printer_part_number_id; 
  -- 1.3     2019-09-03   Roman W.        CHG0045829 
  ------------------------------------------------------------------------------------------  
  PROCEDURE fill_data_main(errbuf  OUT VARCHAR2,
           retcode OUT VARCHAR2) IS
    ------------------------------
    --    Local Definition
    ------------------------------
    l_sysdate       DATE;
    l_last_run_date DATE;
  
    ------------------------------
    --    Code Section
    ------------------------------  
  BEGIN
    retcode := '0';
    errbuf  := NULL;
  
    IF -1 = fnd_global.user_id THEN
      init_for_test;
    END IF;
  
    l_sysdate       := SYSDATE;
    l_last_run_date := get_last_run_date;
  
    ----------------------------------
    --     Set header line data
    ----------------------------------
    set_header_line_data(p_last_run_date => l_last_run_date,
         p_error_desc    => errbuf,
         p_error_code    => retcode);
    IF '0' != retcode THEN
      RETURN;
    END IF;
  
    ----------------------------------
    -- Set contract flag up to date 
    ----------------------------------
    set_contract_flag(p_error_desc => errbuf, p_error_code => retcode);
  
    IF '0' != retcode THEN
      RETURN;
    END IF;
  
    -----------------------------------
    -- Set material_enable_flag = 'N'
    -----------------------------------
    set_material_flag_to_disable(p_error_desc => errbuf,
                 p_error_code => retcode);
    IF '0' != retcode THEN
      RETURN;
    END IF;
  
    ------------------------------------
    --     Add missing materials 
    ------------------------------------
    add_empty_material_to_line(p_error_desc => errbuf,
               p_error_code => retcode);
  
    IF '0' != retcode THEN
      RETURN;
    END IF;
  
    ----------------------------------------
    --   Update concurrent last run date  --
    ----------------------------------------
    set_last_run_date(p_last_run_date => l_sysdate,
              p_error_desc    => errbuf,
              p_error_code    => retcode);
  
  EXCEPTION
    WHEN OTHERS THEN
      retcode := '2';
      errbuf  := 'EXCEPTION_OTHERS XXPPU_UTILS_PKG.fill_data_main() - ' ||
         SQLERRM;
    
      message(errbuf);
    
  END fill_data_main;

  --------------------------------------------------------------------
  --  purpose :     CHG0046049 - called from form personalization - add get_SO_line_type
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10.9.19  Bellona B.  CHG0046049 - initial build
  --------------------------------------------------------------------

  FUNCTION get_so_line_type(p_line_id NUMBER) RETURN VARCHAR2 IS
    l_line_type VARCHAR2(2000);
  BEGIN
  
    SELECT ottt.name -- line type
    INTO   l_line_type
    FROM   oe_order_lines_all      oola,
           oe_transaction_types_tl ottt
    WHERE  oola.line_id = p_line_id --4760082
    AND    oola.line_type_id = ottt.transaction_type_id
    AND    ottt.language = 'US';
  
    RETURN l_line_type;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;

  ------------------------------------------------------------
  -- Name: is_system_item
  -- Description: Returns Y if the supplied item is of type:
  --              [Activity Analysis category segment1
  --              : 1. Systems (net) or 2. Systems-Used ]
  --              and N if not.       
  -------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10.9.19  Bellona B.  CHG0046049 - initial build
  ------------------------------------------------------------
  FUNCTION is_system_item(p_inventory_item_id NUMBER) RETURN VARCHAR2 IS
    l_is_system_item VARCHAR2(1);
  BEGIN
  
    SELECT 'Y'
    INTO   l_is_system_item
    FROM   xxcs_items_printers_v xip
    WHERE  xip.item_type = 'PRINTER'
    AND    xip. inventory_item_id = p_inventory_item_id;
  
    RETURN l_is_system_item;
  EXCEPTION
    WHEN too_many_rows THEN
      RETURN 'Y';
    WHEN OTHERS THEN
      RETURN 'N';
  END is_system_item;
                           
  
  ------------------------------------------------------------
  -- Name: is_waterjet_item
  -- Description: Returns Y if the supplied item is of type:
  --              Water-Jet
  --              and N if not.       
  -------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10.9.19  Bellona B.  CHG0046049 - initial build
  ------------------------------------------------------------
  FUNCTION is_waterjet_item(p_inventory_item_id NUMBER) RETURN VARCHAR2 IS
    l_is_waterjet_item VARCHAR2(1);
  BEGIN
  
    SELECT 'Y'
    INTO   l_is_waterjet_item
    FROM   xxcs_items_printers_v xip
    WHERE  xip.item_type = 'WATER-JET' 
    AND    xip. inventory_item_id = p_inventory_item_id;
  
    RETURN l_is_waterjet_item;
  EXCEPTION
    WHEN too_many_rows THEN
      RETURN 'Y';
    WHEN OTHERS THEN
      RETURN 'N';
  END is_waterjet_item;  
  ------------------------------------------------------------
  -- Name: is_material_item
  -- Description: Returns Y if the supplied item is Materials item
  --              [product hierarchy category segment1 ='Materials']
  --              and N if not.       
  -------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10.9.19  Bellona B.  CHG0046049 - initial build
  ------------------------------------------------------------
  FUNCTION is_material_item(p_inventory_item_id NUMBER) RETURN VARCHAR2 IS
    l_is_material_item VARCHAR2(1);
  BEGIN
  
    SELECT 'Y'
    INTO   l_is_material_item
    FROM   mtl_item_categories_v mic_sc,
           mtl_system_items_b    msi
    WHERE  1 = 1
    AND    msi.inventory_item_id = p_inventory_item_id
    AND    msi.organization_id = 91
    AND    mic_sc.inventory_item_id = msi.inventory_item_id
    AND    mic_sc.organization_id = msi.organization_id
    AND    mic_sc.category_set_name = 'Product Hierarchy'
    AND    mic_sc.segment1 = 'Materials';
  
    RETURN l_is_material_item;
  EXCEPTION
    WHEN too_many_rows THEN
      RETURN 'Y';
    WHEN OTHERS THEN
      RETURN 'N';
  END is_material_item;

  ------------------------------------------------------------
  -- Name: show_ppu_system_item_msg
  -- Description: Returns Y if related conditions of CHG0046049 satisfies
  --              For Material items (product hierarchy category segmnet1 ='Materials') 
  --              the line DFF 'Service S/N'  (attribute1) is not null, 
  --              contract template of the S/N in this DFF is in ('Partner PPU','PPU Warranty') 
  --              and returns N if not.       
  -------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10.9.19  Bellona B.  CHG0046049 - initial build
  ------------------------------------------------------------
  FUNCTION show_ppu_system_item_msg(p_header_id  NUMBER,
            p_order_type VARCHAR2) RETURN VARCHAR2 IS
  
    CURSOR c_ppu_so_lines(c_header_id NUMBER) IS
      SELECT ool.header_id,
     ool.line_id,
     ool.inventory_item_id,
     ool.line_category_code
      FROM   oe_order_lines_all ool
      WHERE  ool.header_id = c_header_id
      AND    nvl(ool.cancelled_flag, 'N') = 'N';
  BEGIN
    IF p_order_type /*get_so_order_type(p_header_id)*/
       NOT LIKE 'PPU Order%' THEN
      RETURN 'N';
    END IF;
  
    FOR i IN c_ppu_so_lines(p_header_id) LOOP
    
      IF (is_system_item(i.inventory_item_id) = 'Y'
           OR is_waterjet_item(i.inventory_item_id) = 'Y')
          AND get_so_line_type(i.line_id) NOT LIKE '%Special Ship%' 
          AND i.line_category_code != 'RETURN' 
      THEN
        RETURN 'Y';
      END IF;
    
    END LOOP;
  
    RETURN 'N';
  
  END;        
  
  ------------------------------------------------------------
  -- Name: show_ppu_material_item_msg
  -- Description: Returns Y if related conditions of CHG0046049 satisfies
  --              For Material items (product hierarchy category segmnet1 ='Materials') 
  --              the line DFF 'Service S/N'  (attribute1) is not null, 
  --              contract template of the S/N in this DFF is in ('Partner PPU','PPU Warranty') 
  --              and returns N if not.       
  -------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10.9.19  Bellona B.  CHG0046049 - initial build
  ------------------------------------------------------------
  FUNCTION show_ppu_material_item_msg(p_header_id  NUMBER,
            p_order_type VARCHAR2) RETURN VARCHAR2 IS
  
    CURSOR c_ppu_so_lines(c_header_id NUMBER) IS
      SELECT ool.header_id,
     ool.line_id,
     ool.inventory_item_id
      FROM   oe_order_lines_all ool
      WHERE  ool.header_id = c_header_id 
      AND    nvl(xxinv_utils_pkg.is_intangible_items(ool.inventory_item_id),'Y')= 'N'
      AND    nvl(ool.cancelled_flag, 'N') = 'N';
  BEGIN
    IF p_order_type /*get_so_order_type(p_header_id)*/
       NOT LIKE 'PPU Order%' THEN
      RETURN 'N';
    END IF;
  
    FOR i IN c_ppu_so_lines(p_header_id) LOOP
    
      IF is_material_item(i.inventory_item_id) = 'Y'
          AND get_so_line_type(i.line_id) NOT LIKE '%Material Ship%' 
      THEN
        RETURN 'Y';
      END IF;
    
    END LOOP;
  
    RETURN 'N';
  
  END;  
END xxppu_utils_pkg;
/