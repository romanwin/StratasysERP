CREATE OR REPLACE PACKAGE BODY xxinv_physical_count_pkg IS

  --------------------------------------------------------------------
  --  name:            XXINV_PHYSICAL_COUNT_PKG
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   23/05/2010 3:29:44 PM
  --------------------------------------------------------------------
  --  purpose :        CUST325 - Upload program to the physical counts from excel to the system
  --                   Get excel that will hold all neccessary fields and update 
  --                   mtl_physical_inventory_tags table with the physical count quantity
  --                   and update of mtl_physical_adjustments tbl
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  23/05/2010  Dalit A. Raviv    initial build
  --  1.1  29/06/2010  Dalit A. Raviv    add function upd_physical_adj_qty
  --                                     do update to mtl_physical_adjustments tbl
  --------------------------------------------------------------------   
  invalid_item EXCEPTION;
  --g_login_id   number := null;
  g_user_id NUMBER := NULL;

  --------------------------------------------------------------------
  --  name:            get_value_from_line
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   23/05/2010 
  --------------------------------------------------------------------
  --  purpose :        get value from excel line 
  --                   return short string each time by the deliminar 
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  23/05/2010  Dalit A. Raviv   initial build
  --------------------------------------------------------------------
  FUNCTION get_value_from_line(p_line_string IN OUT VARCHAR2,
                               p_err_msg     IN OUT VARCHAR2,
                               c_delimiter   IN VARCHAR2) RETURN VARCHAR2 IS
  
    l_pos        NUMBER;
    l_char_value VARCHAR2(250);
  
  BEGIN
    l_pos := instr(p_line_string, c_delimiter);
  
    IF nvl(l_pos, 0) < 1 THEN
      l_pos := length(p_line_string);
    END IF;
  
    l_char_value  := ltrim(rtrim(substr(p_line_string, 1, l_pos - 1)));
    p_line_string := substr(p_line_string, l_pos + 1);
  
    RETURN l_char_value;
  EXCEPTION
    WHEN OTHERS THEN
      p_err_msg := 'get_value_from_line - ' || substr(SQLERRM, 1, 250);
      fnd_file.put_line(fnd_file.log, 'p_err_msg ' || p_err_msg);
      RETURN NULL;
  END get_value_from_line;

  --------------------------------------------------------------------
  --  name:            upd_physical_count_qty
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   23/05/2010 
  --------------------------------------------------------------------
  --  purpose :        procedure that do the update
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  23/05/2010  Dalit A. Raviv   initial build
  --------------------------------------------------------------------
  PROCEDURE upd_physical_count_qty(p_qty                   IN NUMBER,
                                   p_organization_id       IN NUMBER,
                                   p_subinv                IN VARCHAR2,
                                   p_inventory_location_id IN NUMBER,
                                   p_tag_num               IN VARCHAR,
                                   p_inventory_item_id     IN NUMBER,
                                   p_physical_inventory_id IN NUMBER,
                                   
                                   p_error_code OUT NUMBER,
                                   p_error_desc OUT VARCHAR2) IS
  BEGIN
    IF p_inventory_location_id IS NOT NULL THEN
      UPDATE mtl_physical_inventory_tags mpit
         SET tag_quantity                      = p_qty,
             mpit.tag_quantity_at_standard_uom = p_qty,
             mpit.last_update_date             = SYSDATE,
             mpit.last_updated_by              = g_user_id
       WHERE organization_id = p_organization_id -- value from excel convert to id
         AND subinventory = p_subinv -- value from the excel
         AND mpit.locator_id = p_inventory_location_id -- value from excel convert to id
         AND tag_number = p_tag_num -- value from the excel
         AND inventory_item_id = p_inventory_item_id -- value from excel convert to id
         AND physical_inventory_id = p_physical_inventory_id; -- value from the excel
    ELSE
      UPDATE mtl_physical_inventory_tags mpit
         SET tag_quantity                      = p_qty,
             mpit.tag_quantity_at_standard_uom = p_qty,
             mpit.last_update_date             = SYSDATE,
             mpit.last_updated_by              = g_user_id
       WHERE organization_id = p_organization_id -- value from excel convert to id
         AND subinventory = p_subinv -- value from the excel
         AND tag_number = p_tag_num -- value from the excel
         AND inventory_item_id = p_inventory_item_id -- value from excel convert to id
         AND physical_inventory_id = p_physical_inventory_id; -- value from the excel
    END IF;
  
    p_error_code := 0;
    p_error_desc := NULL;
  
  EXCEPTION
    WHEN OTHERS THEN
      p_error_code := 1;
      p_error_desc := 'Upd_physical_count_qty Failed - ' ||
                      substr(SQLERRM, 1, 200);
  END upd_physical_count_qty;

  --------------------------------------------------------------------
  --  name:            upd_physical_adj_qty
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   29/06/2010 
  --------------------------------------------------------------------
  --  purpose :        procedure that do update to mtl_physical_adjustments tbl
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  29/06/2010  Dalit A. Raviv   initial build
  --  1.1  7.12.10     yuval tal    add p_revision 
  --------------------------------------------------------------------
  PROCEDURE upd_physical_adj_qty(p_qty                   IN NUMBER,
                                 p_organization_id       IN NUMBER,
                                 p_subinv                IN VARCHAR2,
                                 p_inventory_location_id IN NUMBER,
                                 p_lot_number            IN VARCHAR2,
                                 p_serial_number         IN VARCHAR2,
                                 p_inventory_item_id     IN NUMBER,
                                 p_physical_inventory_id IN NUMBER,
                                 p_revision              IN VARCHAR2,
                                 p_error_code            OUT NUMBER,
                                 p_error_desc            OUT VARCHAR2) IS
  BEGIN
  
    UPDATE mtl_physical_adjustments adj
       SET adj.count_quantity      = p_qty, -- value from excel
           adj.adjustment_quantity = p_qty - adj.system_quantity,
           adj.last_update_date    = SYSDATE,
           adj.last_updated_by     = g_user_id
     WHERE organization_id = p_organization_id -- value from excel convert to id
       AND subinventory_name = p_subinv -- value from the excel
       AND inventory_item_id = p_inventory_item_id -- value from excel convert to id
       AND physical_inventory_id = p_physical_inventory_id -- value from the excel
       AND nvl(adj.serial_number, '-1') = nvl(p_serial_number, '-1')
       AND nvl(adj.revision, '-1') = nvl(p_revision, '-1')
       AND nvl(adj.lot_number, '-1') = nvl(p_lot_number, '-1')
       AND nvl(adj.locator_id, -1) = nvl(p_inventory_location_id, -1);
    /* IF p_inventory_location_id IS NOT NULL THEN
      IF p_serial_number IS NOT NULL THEN
        UPDATE mtl_physical_adjustments adj
           SET adj.count_quantity      = p_qty, -- value from excel
               adj.adjustment_quantity = p_qty - adj.system_quantity,
               adj.last_update_date    = SYSDATE,
               adj.last_updated_by     = g_user_id
         WHERE organization_id = p_organization_id -- value from excel convert to id
           AND subinventory_name = p_subinv -- value from the excel
           AND adj.locator_id = p_inventory_location_id -- value from excel convert to id
           AND inventory_item_id = p_inventory_item_id -- value from excel convert to id
           AND physical_inventory_id = p_physical_inventory_id -- value from the excel
           AND adj.serial_number = p_serial_number;
      ELSIF p_lot_number IS NOT NULL THEN
        UPDATE mtl_physical_adjustments adj
           SET adj.count_quantity      = p_qty, -- value from excel
               adj.adjustment_quantity = p_qty - adj.system_quantity,
               adj.last_update_date    = SYSDATE,
               adj.last_updated_by     = g_user_id
         WHERE organization_id = p_organization_id -- value from excel convert to id
           AND subinventory_name = p_subinv -- value from the excel
           AND adj.locator_id = p_inventory_location_id -- value from excel convert to id
           AND inventory_item_id = p_inventory_item_id -- value from excel convert to id
           AND physical_inventory_id = p_physical_inventory_id -- value from the excel
           AND adj.lot_number = p_lot_number;
      ELSE
        UPDATE mtl_physical_adjustments adj
           SET adj.count_quantity      = p_qty, -- value from excel
               adj.adjustment_quantity = p_qty - adj.system_quantity,
               adj.last_update_date    = SYSDATE,
               adj.last_updated_by     = g_user_id
         WHERE organization_id = p_organization_id -- value from excel convert to id
           AND subinventory_name = p_subinv -- value from the excel
           AND adj.locator_id = p_inventory_location_id -- value from excel convert to id
           AND inventory_item_id = p_inventory_item_id -- value from excel convert to id
           AND physical_inventory_id = p_physical_inventory_id; -- value from the excel
      END IF;
    ELSE
      IF p_serial_number IS NOT NULL THEN
        UPDATE mtl_physical_adjustments adj
           SET adj.count_quantity      = p_qty, -- value from excel
               adj.adjustment_quantity = p_qty - adj.system_quantity,
               adj.last_update_date    = SYSDATE,
               adj.last_updated_by     = g_user_id
         WHERE organization_id = p_organization_id -- value from excel convert to id
           AND subinventory_name = p_subinv -- value from the excel
           AND inventory_item_id = p_inventory_item_id -- value from excel convert to id
           AND physical_inventory_id = p_physical_inventory_id -- value from the excel
           AND adj.serial_number = p_serial_number;
      ELSIF p_lot_number IS NOT NULL THEN
        UPDATE mtl_physical_adjustments adj
           SET adj.count_quantity      = p_qty, -- value from excel
               adj.adjustment_quantity = p_qty - adj.system_quantity,
               adj.last_update_date    = SYSDATE,
               adj.last_updated_by     = g_user_id
         WHERE organization_id = p_organization_id -- value from excel convert to id
           AND subinventory_name = p_subinv -- value from the excel
           AND inventory_item_id = p_inventory_item_id -- value from excel convert to id
           AND physical_inventory_id = p_physical_inventory_id -- value from the excel
           AND adj.lot_number = p_lot_number;
      ELSE
        UPDATE mtl_physical_adjustments adj
           SET adj.count_quantity      = p_qty, -- value from excel
               adj.adjustment_quantity = p_qty - adj.system_quantity,
               adj.last_update_date    = SYSDATE,
               adj.last_updated_by     = g_user_id
         WHERE organization_id = p_organization_id -- value from excel convert to id
           AND subinventory_name = p_subinv -- value from the excel
           AND inventory_item_id = p_inventory_item_id -- value from excel convert to id
           AND physical_inventory_id = p_physical_inventory_id; -- value from the excel
      END IF;
    
    END IF;*/
  
    p_error_code := 0;
    p_error_desc := NULL;
  
  EXCEPTION
    WHEN OTHERS THEN
      p_error_code := 1;
      p_error_desc := 'Upd_physical_adjt_qty Failed - ' ||
                      substr(SQLERRM, 1, 200);
  END upd_physical_adj_qty;

  --------------------------------------------------------------------
  --  name:            load_physical_count_qty
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   23/05/2010 3:29:44 PM
  --------------------------------------------------------------------
  --  purpose :        Load physical count qty data from excel file to 
  --                   mtl_physical_inventory_tags table (update qty)
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  23/05/2010  Dalit A. Raviv    initial build
  --  1.1  29/06/2010  Dalit A. Raviv    add call to upd_physical_adj_qty.
  --                                     after upd count we need to upd adj too.
  --------------------------------------------------------------------
  PROCEDURE load_physical_count_qty(errbuf           OUT VARCHAR2,
                                    retcode          OUT VARCHAR2,
                                    p_location       IN VARCHAR2,
                                    p_filename       IN VARCHAR2,
                                    p_overwrite_data IN VARCHAR2) IS
  
    l_file_hundler utl_file.file_type;
    l_line_buffer  VARCHAR2(2500);
    l_counter      NUMBER := 0;
    l_err_msg      VARCHAR2(500);
    l_pos          NUMBER;
    c_delimiter CONSTANT VARCHAR2(1) := ',';
  
    l_organization_name     VARCHAR2(250) := NULL;
    l_tag_number            VARCHAR2(40) := NULL;
    l_subinventory          VARCHAR2(50) := NULL;
    l_stock_locator         VARCHAR2(250) := NULL;
    l_item                  mtl_system_items_b.segment1%TYPE;
    l_item_desc             mtl_system_items_b.description%TYPE;
    l_lot_number            VARCHAR2(80) := NULL;
    l_serial_num            VARCHAR2(30) := NULL;
    l_counting_results      NUMBER := NULL;
    l_physical_inventory_id NUMBER := NULL;
    l_inventory_item_id     NUMBER := NULL;
    l_organization_id       NUMBER := NULL;
    l_inventory_location_id NUMBER := NULL;
    l_uom                   VARCHAR2(30);
    l_revision              VARCHAR2(30) := NULL;
    l_exists_row            VARCHAR2(5) := 'Y';
    l_exists_qty            VARCHAR2(5) := 'Y';
    l_error_code            NUMBER := 0;
    l_error_desc            VARCHAR2(500) := NULL;
  
  BEGIN
    -- init globals
    --g_login_id := fnd_profile.VALUE('LOGIN_ID');
    g_user_id := fnd_profile.VALUE('USER_ID'); --nvl(fnd_profile.VALUE('USER_ID'),2470);
  
    -- handle open file to read and handle file exceptions
    BEGIN
      l_file_hundler := utl_file.fopen(location     => p_location,
                                       filename     => p_filename,
                                       open_mode    => 'r',
                                       max_linesize => 32000);
    EXCEPTION
      WHEN utl_file.invalid_path THEN
        fnd_file.put_line(fnd_file.log,
                          'Invalid Path for ' || ltrim(p_filename));
        RAISE;
      WHEN utl_file.invalid_mode THEN
        fnd_file.put_line(fnd_file.log,
                          'Invalid Mode for ' || ltrim(p_filename));
        RAISE;
      WHEN utl_file.invalid_operation THEN
        fnd_file.put_line(fnd_file.log,
                          'Invalid operation for ' || ltrim(p_filename) ||
                          SQLERRM);
        RAISE;
      WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log, 'Other for ' || ltrim(p_filename));
        RAISE;
    END; -- open file
  
    -- start read from file, do needed validation, and upload data to table
    -- Loop For All File's Lines
    LOOP
      BEGIN
        -- goto next line
        l_counter               := l_counter + 1;
        l_err_msg               := NULL;
        l_organization_name     := NULL;
        l_tag_number            := NULL;
        l_subinventory          := NULL;
        l_stock_locator         := NULL;
        l_item                  := NULL;
        l_item_desc             := NULL;
        l_lot_number            := NULL;
        l_serial_num            := NULL;
        l_counting_results      := NULL;
        l_physical_inventory_id := NULL;
        l_inventory_item_id     := NULL;
        l_organization_id       := NULL;
        l_inventory_location_id := NULL;
        l_revision              := NULL;
        l_exists_row            := 'Y';
        l_exists_qty            := 'Y';
      
        -- Get Line and handle exceptions
        BEGIN
          utl_file.get_line(file   => l_file_hundler,
                            buffer => l_line_buffer);
        EXCEPTION
          WHEN utl_file.read_error THEN
            l_err_msg := 'Read Error for line: ' || l_counter;
            RAISE invalid_item;
          WHEN no_data_found THEN
            EXIT;
          WHEN OTHERS THEN
            l_err_msg := 'Read Error for line: ' || l_counter ||
                         ', Error: ' || SQLERRM;
            RAISE invalid_item;
        END;
      
        -- Get data from line separate by deliminar
        IF l_counter > 1 THEN
        
          l_pos               := 0;
          l_organization_name := get_value_from_line(l_line_buffer,
                                                     l_err_msg,
                                                     c_delimiter);
        
          l_tag_number    := get_value_from_line(l_line_buffer,
                                                 l_err_msg,
                                                 c_delimiter);
          l_subinventory  := get_value_from_line(l_line_buffer,
                                                 l_err_msg,
                                                 c_delimiter);
          l_stock_locator := get_value_from_line(l_line_buffer,
                                                 l_err_msg,
                                                 c_delimiter);
          l_item          := get_value_from_line(l_line_buffer,
                                                 l_err_msg,
                                                 c_delimiter);
          l_revision      := TRIM(get_value_from_line(l_line_buffer,
                                                      l_err_msg,
                                                      c_delimiter));
          l_uom           := get_value_from_line(l_line_buffer,
                                                 l_err_msg,
                                                 c_delimiter);
          /*l_item_desc              := get_value_from_line(l_line_buffer,
          l_err_msg,
          c_delimiter);*/
          l_lot_number            := get_value_from_line(l_line_buffer,
                                                         l_err_msg,
                                                         c_delimiter);
          l_serial_num            := get_value_from_line(l_line_buffer,
                                                         l_err_msg,
                                                         c_delimiter);
          l_counting_results      := get_value_from_line(l_line_buffer,
                                                         l_err_msg,
                                                         c_delimiter);
          l_physical_inventory_id := get_value_from_line(l_line_buffer,
                                                         l_err_msg,
                                                         c_delimiter);
        
          IF substr(l_tag_number, 1, 1) = '''' THEN
            l_tag_number := substr(l_tag_number, 2);
          END IF;
        
          IF substr(l_serial_num, 1, 1) = '''' THEN
            l_serial_num := substr(l_serial_num, 2);
          END IF;
        
          IF substr(l_lot_number, 1, 1) = '''' THEN
            l_lot_number := substr(l_lot_number, 2);
          END IF;
        
          -----------------------------------------
          -- start validation
          -----------------------------------------
          -- chaeck item 
          -----------------------------------------
          BEGIN
            SELECT inventory_item_id
              INTO l_inventory_item_id
              FROM mtl_system_items_b msi
             WHERE segment1 = l_item
               AND organization_id = 91;
          EXCEPTION
            WHEN OTHERS THEN
              l_err_msg           := 'Item number is invalid - ' || l_item ||
                                     ' - R' || l_counter;
              l_inventory_item_id := NULL;
              RAISE invalid_item;
          END;
          -----------------------------------------
          -- check organization
          -----------------------------------------
          BEGIN
            SELECT mp.organization_id
              INTO l_organization_id
              FROM mtl_parameters mp
             WHERE mp.organization_code = substr(l_organization_name, 1, 3);
          EXCEPTION
            WHEN OTHERS THEN
              l_err_msg         := 'Organization name is invalid - ' ||
                                   l_organization_name || ' - Qty- ' ||
                                   l_counting_results || ' - R' ||
                                   l_counter;
              l_organization_id := NULL;
              RAISE invalid_item;
          END;
          -----------------------------------------
          -- check locator
          -----------------------------------------
          IF l_stock_locator IS NOT NULL THEN
            BEGIN
              SELECT lo.inventory_location_id
                INTO l_inventory_location_id
                FROM mtl_item_locations_kfv lo
               WHERE lo.concatenated_segments = l_stock_locator
                 AND lo.organization_id = l_organization_id
                 AND lo.status_id = 1;
            EXCEPTION
              WHEN OTHERS THEN
                l_err_msg               := 'Locator name is invalid - ' ||
                                           l_stock_locator || ' - R' ||
                                           l_counter;
                l_inventory_location_id := NULL;
                RAISE invalid_item;
            END;
          END IF;
          -----------------------------------------
          -- check if there is serial number 
          -- can only update qty of 1 or 0
          -----------------------------------------
          IF l_serial_num IS NOT NULL THEN
            IF NOT l_counting_results IN (1, 0) THEN
              l_err_msg               := 'Serial number can get qty of 1 or 0 - ' ||
                                         l_serial_num || ' Qty - ' ||
                                         l_counting_results || ' - R' ||
                                         l_counter;
              l_inventory_location_id := NULL;
              RAISE invalid_item;
            END IF;
          END IF;
          -----------------------------------------
          -- check Data exists at 
          -- mtl_physical_inventory_tags tbl
          -----------------------------------------
          BEGIN
            SELECT 'Y'
              INTO l_exists_row
              FROM mtl_physical_inventory_tags mpit
             WHERE mpit.organization_id = l_organization_id
               AND mpit.tag_number = l_tag_number
               AND mpit.subinventory = l_subinventory
               AND mpit.inventory_item_id = l_inventory_item_id
               AND (mpit.lot_number = l_lot_number OR l_lot_number IS NULL)
               AND (mpit.serial_num = l_serial_num OR l_serial_num IS NULL)
               AND (mpit.locator_id = l_inventory_location_id OR
                   l_inventory_location_id IS NULL)
               AND mpit.physical_inventory_id = l_physical_inventory_id;
          EXCEPTION
            WHEN OTHERS THEN
              l_exists_row := 'N';
              l_err_msg    := 'Data do not exists at mtl_physical_inventory_tags tbl - ' ||
                              ' Physical Inventory Id - ' ||
                              l_physical_inventory_id || ' Organization - ' ||
                              l_organization_name || ' Tag number - ' ||
                              l_tag_number || ' Subinv - ' ||
                              l_subinventory || ' Item - ' || l_item ||
                              ' Lot number - ' || l_lot_number ||
                              ' Serial num - ' || l_serial_num ||
                              ' Locator - ' || l_stock_locator || ' - R' ||
                              l_counter;
              RAISE invalid_item;
          END;
          -----------------------------------------
          -- check if qty value allready entered to
          -- mtl_physical_inventory_tags tbl
          -----------------------------------------
          IF l_exists_row = 'Y' THEN
            BEGIN
              SELECT 'Y'
                INTO l_exists_qty
                FROM mtl_physical_inventory_tags mpit
               WHERE mpit.organization_id = l_organization_id
                 AND mpit.tag_number = l_tag_number
                 AND mpit.subinventory = l_subinventory
                 AND mpit.inventory_item_id = l_inventory_item_id
                 AND (mpit.lot_number = l_lot_number OR
                     l_lot_number IS NULL)
                 AND (mpit.serial_num = l_serial_num OR
                     l_serial_num IS NULL)
                 AND (mpit.locator_id = l_inventory_location_id OR
                     l_inventory_location_id IS NULL)
                 AND mpit.physical_inventory_id = l_physical_inventory_id
                 AND nvl(mpit.revision, '-1') = nvl(l_revision, '-1')
                 AND mpit.tag_quantity IS NOT NULL;
            EXCEPTION
              WHEN OTHERS THEN
                l_exists_qty := 'N';
            END;
          END IF;
          -----------------------------------------
          -- Update qty
          -----------------------------------------
        
          IF l_exists_row = 'Y' THEN
            IF (l_exists_qty = 'N' AND l_counting_results IS NOT NULL) THEN
              l_error_code := 0;
              l_error_desc := NULL;
              upd_physical_count_qty(p_qty                   => l_counting_results, -- i n
                                     p_organization_id       => l_organization_id, -- i n
                                     p_subinv                => l_subinventory, -- i v
                                     p_inventory_location_id => l_inventory_location_id, -- i n
                                     p_tag_num               => l_tag_number, -- i v
                                     p_inventory_item_id     => l_inventory_item_id, -- i n
                                     p_physical_inventory_id => l_physical_inventory_id, -- i n
                                     
                                     p_error_code => l_error_code, -- o n
                                     p_error_desc => l_error_desc); -- o v l_error_code/ p_error_desc
              IF l_error_code = 0 THEN
                -- 1.1  29/06/2010  Dalit A. Raviv 
                --commit;
                l_error_code := 0;
                l_error_desc := NULL;
                upd_physical_adj_qty(p_qty                   => l_counting_results, -- i n
                                     p_organization_id       => l_organization_id, -- i n
                                     p_subinv                => l_subinventory, -- i v
                                     p_inventory_location_id => l_inventory_location_id, -- i n
                                     p_lot_number            => l_lot_number, -- i v
                                     p_serial_number         => l_serial_num, -- i v
                                     p_inventory_item_id     => l_inventory_item_id, -- i n
                                     p_physical_inventory_id => l_physical_inventory_id, -- i n
                                     p_revision              => l_revision,
                                     p_error_code            => l_error_code, -- o n
                                     p_error_desc            => l_error_desc); -- o v l_error_code/ p_error_desc
                IF l_error_code = 0 THEN
                  COMMIT;
                ELSE
                  ROLLBACK;
                  l_err_msg := l_error_desc;
                  RAISE invalid_item;
                END IF;
                -- end 1.1  29/06/2010  Dalit A. Raviv 
              ELSE
                ROLLBACK;
                l_err_msg := l_error_desc;
                RAISE invalid_item;
              END IF; -- l_error_code
            ELSIF (l_exists_qty = 'Y' AND l_counting_results IS NOT NULL AND
                  p_overwrite_data = 'Y') THEN
              l_error_code := 0;
              l_error_desc := NULL;
              upd_physical_count_qty(p_qty                   => l_counting_results, -- i n
                                     p_organization_id       => l_organization_id, -- i n
                                     p_subinv                => l_subinventory, -- i v
                                     p_inventory_location_id => l_inventory_location_id, -- i n
                                     p_tag_num               => l_tag_number, -- i v
                                     p_inventory_item_id     => l_inventory_item_id, -- i n
                                     p_physical_inventory_id => l_physical_inventory_id, -- i n
                                     
                                     p_error_code => l_error_code, -- o n
                                     p_error_desc => l_error_desc); -- o v l_error_code/ p_error_desc
              IF l_error_code = 0 THEN
                -- 1.1 29/06/2010 Dalit A. Raviv 
                --commit;
                l_error_code := 0;
                l_error_desc := NULL;
                upd_physical_adj_qty(p_qty                   => l_counting_results, -- i n
                                     p_organization_id       => l_organization_id, -- i n
                                     p_subinv                => l_subinventory, -- i v
                                     p_inventory_location_id => l_inventory_location_id, -- i n
                                     p_lot_number            => l_lot_number, -- i v
                                     p_serial_number         => l_serial_num, -- i v
                                     p_inventory_item_id     => l_inventory_item_id, -- i n
                                     p_physical_inventory_id => l_physical_inventory_id, -- i n
                                     p_revision              => l_revision,
                                     p_error_code            => l_error_code, -- o n
                                     p_error_desc            => l_error_desc); -- o v l_error_code/ p_error_desc
              
                IF l_error_code = 0 THEN
                  COMMIT;
                ELSE
                  ROLLBACK;
                  l_err_msg := l_error_desc;
                  RAISE invalid_item;
                END IF;
                -- end 1.1 29/06/2010 Dalit A. Raviv 
              ELSE
                ROLLBACK;
                l_err_msg := l_error_desc;
                RAISE invalid_item;
              END IF; -- l_error_code
            ELSIF l_exists_qty = 'Y' AND l_counting_results IS NOT NULL AND
                  p_overwrite_data = 'N' THEN
              l_err_msg := 'Qty allready exists - ' ||
                           ' Physical Inventory Id - ' ||
                           l_physical_inventory_id || ' Organization - ' ||
                           l_organization_name || ' Tag number - ' ||
                           l_tag_number || ' Subinv - ' || l_subinventory ||
                           ' Item - ' || l_item || ' Lot number - ' ||
                           l_lot_number || ' Serial num - ' || l_serial_num ||
                           ' Locator - ' || l_stock_locator || ' - R' ||
                           l_counter;
              RAISE invalid_item;
            END IF; -- l_Counting_Results is not null
          END IF; -- l_exists
        END IF; -- l_counter
      
      EXCEPTION
        WHEN invalid_item THEN
          fnd_file.put_line(fnd_file.log, '--------------------');
          fnd_file.put_line(fnd_file.log, l_err_msg);
          fnd_file.put_line(fnd_file.log, '--------------------');
          ROLLBACK;
          retcode := 1;
          errbuf  := 'Complete warning';
        WHEN OTHERS THEN
        
          l_err_msg := ' Physical Inventory Id - ' ||
                       l_physical_inventory_id || ' Organization - ' ||
                       l_organization_name || ' Tag number - ' ||
                       l_tag_number || ' Subinv - ' || l_subinventory ||
                       ' Item - ' || l_item || ' Lot number - ' ||
                       l_lot_number || ' Serial num - ' || l_serial_num ||
                       ' Locator - ' || l_stock_locator || ' - R' ||
                       l_counter || ' - ' || SQLERRM;
          --l_err_msg := SQLERRM;
          fnd_file.put_line(fnd_file.log, l_err_msg); -- l_counter||' - '||
          ROLLBACK;
      END;
    END LOOP;
  
    utl_file.fclose(l_file_hundler);
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'load_physical_count_qty - General exception - ' ||
                 substr(SQLERRM, 1, 250);
      retcode := 1;
    
  END load_physical_count_qty;

END xxinv_physical_count_pkg;
/

