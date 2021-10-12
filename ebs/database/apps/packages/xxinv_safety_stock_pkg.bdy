CREATE OR REPLACE PACKAGE BODY xxinv_safety_stock_pkg IS
  --------------------------------------------------------------------
  --  name:            XXINV_SAFETY_STOCK_PKG 
  --  Cust:            CUST241 - Have a safety stock upload program to delete
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   07/02/2010 6:43:07 PM
  --------------------------------------------------------------------
  --  purpose :        The customization will be used by the Service Planning department, at any
  --                   given time. The propose is to have a tool to update (Update existing, delete 
  --                   existing, add to the table) record of item and its safety stock.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  07/02/2009  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  invalid_item EXCEPTION;
  g_login_id NUMBER := NULL;
  g_user_id  NUMBER := NULL;

  --------------------------------------------------------------------
  --  name:            upd_mtl_safety_stocks 
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   08/02/2010 6:43:07 PM
  --------------------------------------------------------------------
  --  purpose :        update qqty to mtl_safety_stocks tbl
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  08/02/2009  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  PROCEDURE upd_mtl_safety_stocks(p_inventory_item_id IN NUMBER,
                                  p_organization_id   IN NUMBER,
                                  --p_effective_date    in  date,
                                  p_ss_qty     IN NUMBER,
                                  p_error_code OUT NUMBER,
                                  p_error_desc OUT VARCHAR2) IS
  
  BEGIN
    UPDATE mtl_safety_stocks mss
       SET mss.safety_stock_quantity = p_ss_qty,
           mss.last_update_date      = SYSDATE,
           mss.last_updated_by       = g_user_id
     WHERE mss.inventory_item_id = p_inventory_item_id
       AND mss.organization_id = p_organization_id;
    --and    trunc(mss.effectivity_date) = p_effective_date;
  
    --commit;
    p_error_code := 0;
    p_error_desc := NULL;
  
  EXCEPTION
    WHEN OTHERS THEN
      p_error_code := 1;
      p_error_desc := 'upd_mtl_safety_stocks - ' || substr(SQLERRM, 1, 250);
  END upd_mtl_safety_stocks;

  --------------------------------------------------------------------
  --  name:            upd_mtl_safety_stocks 
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   08/02/2010 6:43:07 PM
  --------------------------------------------------------------------
  --  purpose :        update qqty to mtl_safety_stocks tbl
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  08/02/2009  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  PROCEDURE ins_mtl_safty_stocks(p_org_id     IN NUMBER, -- organization_id        from excel
                                 p_item_id    IN NUMBER, -- inventory_item_id      from excel
                                 p_ss_code    IN NUMBER, -- to send 1 User-defined quantity
                                 p_forc_name  IN VARCHAR2, -- forecast_designator    should be null
                                 p_ss_percent IN NUMBER, -- safety_stock_percent   should be null
                                 p_srv_level  IN NUMBER, -- service_level          should be null
                                 p_ss_date    IN DATE, -- effectivity_date       from excel
                                 p_ss_qty     IN NUMBER, -- safety_stock_quantity  from excel
                                 p_login_id   IN NUMBER,
                                 p_user_id    IN NUMBER, -- conversion 1171
                                 p_error_code OUT NUMBER,
                                 p_error_desc OUT VARCHAR2) IS
  
  BEGIN
    INSERT INTO mtl_safety_stocks
      (effectivity_date,
       safety_stock_quantity,
       safety_stock_percent,
       last_update_date,
       service_level,
       creation_date,
       last_updated_by,
       created_by,
       last_update_login,
       organization_id,
       inventory_item_id,
       safety_stock_code,
       forecast_designator)
    VALUES
      (p_ss_date,
       p_ss_qty,
       p_ss_percent,
       SYSDATE,
       p_srv_level,
       SYSDATE,
       p_user_id,
       p_user_id,
       p_login_id,
       p_org_id,
       p_item_id,
       p_ss_code,
       p_forc_name);
    --commit;
    p_error_code := 0;
    p_error_desc := NULL;
  EXCEPTION
    WHEN OTHERS THEN
      p_error_code := 1;
      p_error_desc := 'ins_mtl_safty_stocks - general exc - ' ||
                      substr(SQLERRM, 1, 250);
    
  END ins_mtl_safty_stocks;

  --------------------------------------------------------------------
  --  name:            del_mtl_safety_stocks
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   2/7/2010 6:43:07 PM
  --------------------------------------------------------------------
  --  purpose :        Procedure that delete rows from mtl_safety_stocks
  --                   by organization_id
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  07/02/2009  Dalit A. Raviv    initial build
  -------------------------------------------------------------------- 
  PROCEDURE del_mtl_safety_stocks(p_organization_id IN NUMBER,
                                  p_error_code      OUT NUMBER,
                                  p_error_desc      OUT VARCHAR2) IS
  
    CURSOR get_items_to_dalete_c IS
      SELECT msi.segment1, mss.*
        FROM mtl_safety_stocks mss, mtl_system_items_b msi
       WHERE mss.organization_id = p_organization_id
         AND trunc(mss.last_update_date) <> trunc(SYSDATE)
         AND mss.inventory_item_id = msi.inventory_item_id
         AND mss.organization_id = msi.organization_id;
  BEGIN
    fnd_file.put_line(fnd_file.log, '--------------------');
    fnd_file.put_line(fnd_file.log, 'Start Delete items');
  
    FOR get_items_to_dalete_r IN get_items_to_dalete_c LOOP
      fnd_file.put_line(fnd_file.log,
                        'XX Item - ' || get_items_to_dalete_r.segment1 ||
                        ' Effective_date - ' ||
                        to_char(get_items_to_dalete_r.effectivity_date) ||
                        ' Qty - ' ||
                        get_items_to_dalete_r.safety_stock_quantity);
    
      DELETE mtl_safety_stocks mss
       WHERE mss.organization_id = p_organization_id
         AND mss.inventory_item_id =
             get_items_to_dalete_r.inventory_item_id
         AND trunc(mss.last_update_date) <> trunc(SYSDATE);
    END LOOP;
    fnd_file.put_line(fnd_file.log, 'End Delete items');
    fnd_file.put_line(fnd_file.log, '--------------------');
    --commit;
    p_error_code := 0;
    p_error_desc := NULL;
  EXCEPTION
    WHEN OTHERS THEN
      p_error_code := 1;
      p_error_desc := 'del_mtl_safety_stocks - Can not delete rows for organization ' ||
                      p_organization_id || ' - ' || substr(SQLERRM, 1, 250);
  END del_mtl_safety_stocks;

  --------------------------------------------------------------------
  --  name:            del_mtl_safty_stocks
  --  create by:       Ella malchi
  --  Revision:        1.0 
  --  creation date:   08/02/2010 6:43:07 PM
  --------------------------------------------------------------------
  --  purpose :        if found too_many_rows at table for the item + organization
  --                   1) find the min effective date 
  --                   2) delete all rows exept this effective date
  --                   3) update row 
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  08/02/2009  Ella malchi      initial build
  --------------------------------------------------------------------
  PROCEDURE del_mtl_safty_stocks(p_inventory_item_id IN NUMBER,
                                 p_organization_id   IN NUMBER,
                                 --p_effective_date    in  date,
                                 p_ss_qty     IN NUMBER,
                                 p_error_code OUT NUMBER,
                                 p_error_desc OUT VARCHAR2) IS
  
    l_effectivity_date DATE := NULL;
  
  BEGIN
    --  get minimum effective date  
    SELECT mss.effectivity_date
      INTO l_effectivity_date
      FROM mtl_safety_stocks mss
     WHERE mss.inventory_item_id = p_inventory_item_id
       AND mss.organization_id = p_organization_id
       AND mss.effectivity_date =
           (SELECT MIN(mss1.effectivity_date)
              FROM mtl_safety_stocks mss1
             WHERE mss1.inventory_item_id = p_inventory_item_id
               AND mss1.organization_id = p_organization_id);
    -- delete all rows but min effective date            
    DELETE mtl_safety_stocks mss
     WHERE mss.inventory_item_id = p_inventory_item_id
       AND mss.organization_id = p_organization_id
       AND mss.effectivity_date <> l_effectivity_date;
    -- update row with the new qty
    UPDATE mtl_safety_stocks mss
       SET mss.safety_stock_quantity = p_ss_qty
     WHERE mss.inventory_item_id = p_inventory_item_id
       AND mss.organization_id = p_organization_id;
  
    p_error_code := 0;
    p_error_desc := NULL;
  
  EXCEPTION
    WHEN OTHERS THEN
      p_error_code := 1;
      p_error_desc := 'del_mtl_safty_stocks many rows - ' ||
                      substr(SQLERRM, 1, 250);
  END del_mtl_safty_stocks;

  --------------------------------------------------------------------
  --  name:            get_value_from_line
  --  create by:       Ella malchi
  --  Revision:        1.0 
  --  creation date:   08/02/2010 6:43:07 PM
  --------------------------------------------------------------------
  --  purpose :        get value from excel line 
  --                   return short string each time by the deliminar 
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  08/02/2009  Ella malchi      initial build
  --------------------------------------------------------------------
  FUNCTION get_value_from_line(p_line_string IN OUT VARCHAR2,
                               p_err_msg     IN OUT VARCHAR2,
                               --p_counter     in number,
                               c_delimiter IN VARCHAR2) RETURN VARCHAR2 IS
  
    l_pos        NUMBER;
    l_char_value VARCHAR2(20);
  
  BEGIN
  
    l_pos := instr(p_line_string, c_delimiter);
  
    IF nvl(l_pos, 0) < 1 THEN
      l_pos := length(p_line_string);
    END IF;
  
    l_char_value := ltrim(rtrim(substr(p_line_string, 1, l_pos - 1)));
  
    p_line_string := substr(p_line_string, l_pos + 1);
  
    RETURN l_char_value;
  EXCEPTION
    WHEN OTHERS THEN
      p_err_msg := 'get_value_from_line - ' || substr(SQLERRM, 1, 250);
  END get_value_from_line;

  --------------------------------------------------------------------
  --  name:            load_safty_stock_data
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   2/7/2010 6:43:07 PM
  --------------------------------------------------------------------
  --  purpose :        Load safty stock data from excel file to 
  --                   mtl_safety_stocks table
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  07/02/2009  Dalit A. Raviv    initial build
  --  1.1   15/8/2011  yuval tal          CR 303: add parameter to load_safety_stock_data + logic changed
  --------------------------------------------------------------------
  PROCEDURE load_safety_stock_data(errbuf                  OUT VARCHAR2,
                                   retcode                 OUT VARCHAR2,
                                   p_location              IN VARCHAR2,
                                   p_filename              IN VARCHAR2,
                                   p_organization_id       IN NUMBER,
                                   p_delete_exists_recodrs VARCHAR2) IS
  
    l_file_hundler utl_file.file_type;
    l_line_buffer  VARCHAR2(2000);
    l_counter      NUMBER := 0;
    l_err_msg      VARCHAR2(500);
    l_pos          NUMBER;
    c_delimiter CONSTANT VARCHAR2(1) := ',';
  
    l_org_code        mtl_parameters.organization_code%TYPE;
    l_organization_id NUMBER;
    l_item_num        mtl_system_items_b.segment1%TYPE;
    l_effective_date  VARCHAR2(50) := NULL;
    l_safty_stock_qty mtl_safety_stocks.safety_stock_quantity%TYPE;
  
    l_error_code        NUMBER := 0;
    l_error_desc        VARCHAR2(2000) := NULL;
    l_exists            NUMBER := NULL;
    l_organization_code VARCHAR2(3) := NULL;
    l_item_id           NUMBER := NULL;
    l_date              DATE := NULL;
    l_date_str          VARCHAR2(50) := NULL;
  
    TYPE t_arr IS TABLE OF NUMBER INDEX BY VARCHAR2(50);
    l_org_item_arr t_arr;
    l_org_arr      t_arr;
  BEGIN
    -- init globals
    g_login_id := fnd_global.login_id;
    g_user_id  := fnd_global.user_id;
  
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
    END;
  
    -- start read from file, do needed validation, and upload data to table
    -- Loop For All File's Lines
    LOOP
      BEGIN
        -- goto next line
        l_counter           := l_counter + 1;
        l_err_msg           := NULL;
        l_item_num          := NULL;
        l_effective_date    := NULL;
        l_safty_stock_qty   := NULL;
        l_organization_code := NULL;
        l_organization_id   := NULL;
        l_item_id           := NULL;
        l_date              := NULL;
        l_date_str          := NULL;
      
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
          l_pos      := 0;
          l_org_code := get_value_from_line(l_line_buffer,
                                            l_err_msg,
                                            c_delimiter);
        
          l_item_num := get_value_from_line(l_line_buffer,
                                            l_err_msg,
                                            c_delimiter);
        
          l_effective_date := get_value_from_line(l_line_buffer,
                                                  l_err_msg,
                                                  c_delimiter);
        
          l_safty_stock_qty := to_number(get_value_from_line(l_line_buffer,
                                                             l_err_msg,
                                                             c_delimiter));
        
          -- start validation
        
          -- validate item and organization are correct at the excel file
          -- get organization code by id
          BEGIN
            SELECT mp.organization_id --mp.organization_code
              INTO l_organization_id
              FROM mtl_parameters mp
             WHERE mp.organization_code = upper(l_org_code);
          EXCEPTION
            WHEN OTHERS THEN
              -- if user enter not valid code - write msg to log
              l_err_msg           := 'Organization code is invalid - ' ||
                                     l_org_code || ' - ' || l_counter;
              l_organization_code := NULL;
              RAISE invalid_item;
          END;
          -- get inventory_item_id by item number
          BEGIN
            SELECT inventory_item_id
              INTO l_item_id
              FROM mtl_system_items_b msi
             WHERE msi.segment1 = TRIM(l_item_num)
               AND msi.organization_id = l_organization_id;
          EXCEPTION
            WHEN OTHERS THEN
              -- if user enter not valid code - write msg to log
              l_err_msg := 'Item number is invalid - ' || l_item_num ||
                           ' - ' || l_counter;
              l_item_id := NULL;
              RAISE invalid_item;
          END;
        
          -- check delete options
          IF p_delete_exists_recodrs = 'N' THEN
          
            IF NOT
                l_org_item_arr.EXISTS(l_organization_id || '-' || l_item_id) THEN
              DELETE FROM mtl_safety_stocks mss
               WHERE mss.inventory_item_id = l_item_id
                 AND mss.organization_id = l_organization_id;
              l_org_item_arr(l_organization_id || '-' || l_item_id) := 1;
              COMMIT;
            END IF;
          ELSIF p_delete_exists_recodrs = 'Y' AND
                NOT l_org_arr.EXISTS(l_org_code) THEN
            DELETE mtl_safety_stocks mss
             WHERE mss.organization_id = l_organization_id;
            l_org_arr(l_org_code) := 1;
            COMMIT;
          END IF;
        
          -- insert new row only if organization_id is valid
          l_error_code := 0;
          l_error_desc := NULL;
          --FND_DATE.canonical_to_date
          -- FND_CONC_DATE.STRING_TO_DATE('21-12-09') 
          -- 01/12/2009 not us date as 1/20/2010
          l_date     := to_date(l_effective_date, 'dd/mm/RRRR');
          l_date_str := to_char(l_date, 'DD-MON-RRRR');
          l_date     := to_date(l_date, 'DD-MON-RRRR');
          ins_mtl_safty_stocks(p_org_id     => l_organization_id, -- i n   
                               p_item_id    => l_item_id, -- i n  
                               p_ss_code    => 1, -- i n 
                               p_forc_name  => NULL,
                               p_ss_percent => NULL,
                               p_srv_level  => NULL,
                               --p_ss_date    => to_date(l_effective_date,'DD/MM/YYYY HH24:MI:SS'), -- i d
                               p_ss_date    => l_date,
                               p_ss_qty     => l_safty_stock_qty, -- i n
                               p_login_id   => g_login_id, -- i n
                               p_user_id    => g_user_id, -- i n
                               p_error_code => l_error_code, -- o n
                               p_error_desc => l_error_desc); -- o v
        
          IF l_error_code = 0 THEN
            COMMIT;
          ELSE
            retcode := 1;
            fnd_file.put_line(fnd_file.log, '--------------------');
            fnd_file.put_line(fnd_file.log,
                              'Item = ' || l_item_num ||
                              '  l_effective_date = ' || l_effective_date);
            fnd_file.put_line(fnd_file.log,
                              'Counter=' || l_counter || ' - ' ||
                              l_error_desc);
            fnd_file.put_line(fnd_file.log, '--------------------');
            ROLLBACK;
          END IF;
          -- find several rows at table   
        END IF;
      EXCEPTION
      
        WHEN invalid_item THEN
          retcode := 1;
          fnd_file.put_line(fnd_file.log, '--------------------');
          fnd_file.put_line(fnd_file.log, l_err_msg);
          fnd_file.put_line(fnd_file.log, '--------------------');
          ROLLBACK;
        WHEN OTHERS THEN
          retcode   := 1;
          l_err_msg := SQLERRM;
          fnd_file.put_line(fnd_file.log, l_err_msg);
          ROLLBACK;
      END;
    
    END LOOP;
    fnd_file.put_line(fnd_file.log, '--------------------');
    fnd_file.put_line(fnd_file.log,
                      'File Upload process ended  , check log');
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'load_safty_stock_data - General exception - ' ||
                 substr(SQLERRM, 1, 250);
      retcode := 1;
  END load_safety_stock_data;

END xxinv_safety_stock_pkg;
/
