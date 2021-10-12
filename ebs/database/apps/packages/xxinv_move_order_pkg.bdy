CREATE OR REPLACE PACKAGE BODY xxinv_move_order_pkg IS

  --------------------------------------------------------------------
  --  name:            XXINV_MOVE_ORDER_PKG
  --  create by:       
  --  Revision:        1.0 
  --  creation date:   05.6.14 
  --------------------------------------------------------------------
  --  purpose :  change CHG0032311 Auto Populate Destination Locator in Mass Move Orders     
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  05.6.14    Yuval Tal        initial build
  --  1.1  07.07.14   yuval tal        CHG0032699 : upload_mo_setup_file add parameter p_inventory_item_id 

  --------------------------------------------------------------------
  --  name:            get_mo_dest_info
  --  create by:       
  --  Revision:        1.0 
  --  creation date:   
  --------------------------------------------------------------------
  --  purpose :  change CHG0032311 Auto Populate Destination Locator in Mass Move Orders   
  --             acivate from xxinvcustom.pll (move order form)  
  --------------------------------------------------------------------
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  05.6.14     Yuval Tal          initial build
  --  1.1  07.07.14    yuval tal          CHG0032699 : add parameter p_inventory_item_id
  --------------------------------------------------------------------   
  PROCEDURE get_mo_dest_info(p_inventory_item_id  NUMBER,
                             p_from_sub_inventory VARCHAR2,
                             p_from_locator_id    NUMBER,
                             p_to_sub_inventory   OUT VARCHAR2,
                             p_to_locator_seg     OUT VARCHAR2,
                             p_to_locator_id      OUT NUMBER) IS
  
  BEGIN
    SELECT t.dest_sub_inventory, t.dest_locator, t.dest_locator_id
      INTO p_to_sub_inventory, p_to_locator_seg, p_to_locator_id
      FROM xxinv_move_source_dest_def t
     WHERE t.source_sub_inventory = p_from_sub_inventory
       AND t.status = 'S'
       AND t.source_locator_id = nvl(p_from_locator_id, source_locator_id)
       AND t.inventory_item_id = p_inventory_item_id;
  EXCEPTION
    WHEN no_data_found THEN
      BEGIN
      
        SELECT t.dest_sub_inventory, t.dest_locator, t.dest_locator_id
          INTO p_to_sub_inventory, p_to_locator_seg, p_to_locator_id
          FROM xxinv_move_source_dest_def t
         WHERE t.source_sub_inventory = p_from_sub_inventory
           AND t.status = 'S'
           AND t.source_locator_id =
               nvl(p_from_locator_id, source_locator_id)
           AND t.inventory_item_id IS NULL;
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
    
    WHEN OTHERS THEN
      NULL;
  END;

  --------------------------------------------------------------------
  --  name:            upload_mo_setup_file
  --  create by:       
  --  Revision:        1.0 
  --  creation date:   
  --------------------------------------------------------------------
  --  purpose :  change CHG0032311 : Load setup table
  --            
  --             validate sub inventory/locator
  -- use file loader setup
  -- p_delete_records : Y/N : delete records with organization exists in file
  --------------------------------------------------------------------
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  05.6.14     Yuval Tal          initial build
  --  1.1  07.07.14    yuval tal          CHG0032699 : support  p_inventory_item_id
  --------------------------------------------------------------------   
  PROCEDURE upload_mo_setup_file(p_err_buff       OUT VARCHAR2,
                                 p_err_code       OUT NUMBER,
                                 p_table_name     VARCHAR2,
                                 p_template_name  VARCHAR2,
                                 p_directory      VARCHAR2,
                                 p_file_name      VARCHAR2,
                                 p_delete_records VARCHAR2) IS
  
    CURSOR c IS
      SELECT rownum, t.*
        FROM xxinv_move_source_dest_def t
       WHERE t.request_id = fnd_global.conc_request_id
         FOR UPDATE;
    l_tmp          NUMBER;
    l_locator_type NUMBER;
    l_err_message  xxinv_move_source_dest_def.error_message%TYPE;
    my_exception EXCEPTION;
  BEGIN
    p_err_code := 0;
  
    xxobjt_table_loader_util_pkg.load_file(errbuf                 => p_err_buff,
                                           retcode                => p_err_code,
                                           p_table_name           => p_table_name,
                                           p_template_name        => p_template_name,
                                           p_file_name            => p_file_name,
                                           p_directory            => p_directory,
                                           p_expected_num_of_rows => NULL);
  
    IF p_err_code != 0 THEN
    
      fnd_file.put_line(fnd_file.log, '========================= ');
      fnd_file.put_line(fnd_file.log, 'File not Loaded ');
      fnd_file.put_line(fnd_file.log, '========================');
    ELSE
    
      IF p_delete_records = 'Y' THEN
        DELETE FROM xxinv_move_source_dest_def tt
         WHERE tt.request_id != fnd_global.conc_request_id
           AND tt.organization_code IN
               (SELECT DISTINCT t.organization_code
                  FROM xxinv_move_source_dest_def t
                 WHERE t.request_id = fnd_global.conc_request_id);
      
        COMMIT;
      END IF;
    
      fnd_file.put_line(fnd_file.log, '========================');
      fnd_file.put_line(fnd_file.log, 'File Validation ');
      fnd_file.put_line(fnd_file.log, '========================');
      FOR i IN c LOOP
        -- validate records
        BEGIN
          l_err_message := NULL;
        
          IF i.organization_code IS NULL THEN
            l_err_message := ('Record=' || c%ROWCOUNT || ' ' ||
                             'organization_code is missing ');
          
            RAISE my_exception;
          END IF;
        
          IF i.source_sub_inventory IS NULL THEN
            l_err_message := ('Record=' || c%ROWCOUNT || ' ' ||
                             'source_sub_inventory is missing ');
          
            RAISE my_exception;
          END IF;
        
          IF i.source_sub_inventory IS NULL THEN
          
            l_err_message := ('Record=' || c%ROWCOUNT || ' ' ||
                             'source_sub_inventory is missing ');
            RAISE my_exception;
          
          END IF;
        
          IF i.dest_sub_inventory IS NULL THEN
          
            l_err_message := ('Record=' || c%ROWCOUNT || ' ' ||
                             'dest_sub_inventory is missing ');
            RAISE my_exception;
          
          END IF;
        
          -- Validate item
        
          IF i.item_code IS NOT NULL THEN
          
            i.inventory_item_id := xxinv_utils_pkg.get_item_id(i.item_code);
            IF i.inventory_item_id IS NULL THEN
            
              l_err_message := ('Record=' || c%ROWCOUNT || ' ' ||
                               'item_code is not valid ');
              RAISE my_exception;
            END IF;
          
          END IF;
        
          -- valid org 
          BEGIN
            SELECT organization_id
              INTO i.organization_id
              FROM mtl_parameters p
             WHERE p.organization_code = i.organization_code;
          EXCEPTION
            WHEN no_data_found THEN
            
              l_err_message := ('Record=' || c%ROWCOUNT || ' ' ||
                               'Organization_code=' || i.organization_code ||
                               ' is not valid');
              RAISE my_exception;
          END;
        
          -- valid source_sub_inventory
        
          BEGIN
          
            SELECT t.locator_type
              INTO l_locator_type
              FROM mtl_secondary_inventories t
             WHERE t.organization_id = i.organization_id
               AND t.secondary_inventory_name = i.source_sub_inventory;
          
          EXCEPTION
            WHEN no_data_found THEN
              l_locator_type := NULL;
            
              l_err_message := ('Record=' || c%ROWCOUNT || ' ' ||
                               'source_sub_inventory=' ||
                               i.source_sub_inventory || ' is not valid');
              RAISE my_exception;
            
          END;
        
          IF l_locator_type = 2 THEN
            -- valid source locator_id 
          
            BEGIN
            
              SELECT t.inventory_location_id
                INTO i.source_locator_id
                FROM mtl_item_locations_kfv t
               WHERE t.organization_id = i.organization_id
                 AND t.concatenated_segments = i.source_locator;
            
            EXCEPTION
              WHEN no_data_found THEN
                p_err_code    := 1;
                l_err_message := ('Record=' || c%ROWCOUNT || ' ' ||
                                 'source_locator=' || i.source_locator ||
                                 ' is not valid/missing');
                continue;
            END;
          
            -- check combination
            BEGIN
            
              SELECT 1
                INTO l_tmp
                FROM mtl_item_locations mil
               WHERE mil.organization_id = i.organization_id
                 AND mil.inventory_location_id = i.source_locator_id
                 AND mil.subinventory_code = i.source_sub_inventory;
            
            EXCEPTION
              WHEN no_data_found THEN
              
                l_err_message := ('Record=' || c%ROWCOUNT || ' ' ||
                                 'Source subInv/Locator combination is not valid ' ||
                                 i.source_sub_inventory || '/' ||
                                 i.source_locator);
                RAISE my_exception;
            END;
          
          ELSIF i.source_locator IS NOT NULL THEN
          
            l_err_message := ('Record=' || c%ROWCOUNT || ' ' ||
                             'source_locator=' || i.source_locator ||
                             ' is not required');
            RAISE my_exception;
          
          END IF;
          -- valid dest_sub_inventory
        
          BEGIN
          
            SELECT t.locator_type -- 2 locator manage
              INTO l_locator_type
              FROM mtl_secondary_inventories t
             WHERE t.organization_id = i.organization_id
               AND t.secondary_inventory_name = i.dest_sub_inventory;
          
          EXCEPTION
            WHEN no_data_found THEN
              l_locator_type := NULL;
            
              l_err_message := ('Record=' || c%ROWCOUNT || ' ' ||
                               'dest_sub_inventory=' ||
                               i.dest_sub_inventory || ' is not valid');
              RAISE my_exception;
          END;
        
          --
          -- valid dest locator_id 
        
          IF l_locator_type = 2 THEN
            BEGIN
            
              SELECT t.inventory_location_id
                INTO i.dest_locator_id
                FROM mtl_item_locations_kfv t
               WHERE t.organization_id = i.organization_id
                 AND t.concatenated_segments = i.dest_locator;
            
            EXCEPTION
              WHEN no_data_found THEN
              
                l_err_message := ('Record=' || c%ROWCOUNT || ' ' ||
                                 'dest_locator=' || i.dest_locator ||
                                 ' is not valid/missing');
                RAISE my_exception;
            END;
          
            -- check combination
            BEGIN
            
              SELECT 1
                INTO l_tmp
                FROM mtl_item_locations mil
               WHERE mil.organization_id = i.organization_id
                 AND mil.inventory_location_id = i.dest_locator_id
                 AND mil.subinventory_code = i.dest_sub_inventory;
            
            EXCEPTION
              WHEN no_data_found THEN
              
                l_err_message := ('Record=' || c%ROWCOUNT || ' ' ||
                                 'Dest subInv/Locator combination is not valid ' ||
                                 i.dest_sub_inventory || '/' ||
                                 i.dest_locator);
                RAISE my_exception;
            END;
          
            --
          
          ELSIF i.dest_locator IS NOT NULL THEN
          
            l_err_message := ('Record=' || c%ROWCOUNT || ' ' ||
                             'dest_locator=' || i.dest_locator ||
                             ' is not required');
            RAISE my_exception;
          
          END IF;
        
          -- update id's
        
          UPDATE xxinv_move_source_dest_def t
             SET t.organization_id   = i.organization_id,
                 t.source_locator_id = i.source_locator_id,
                 t.dest_locator_id   = i.dest_locator_id,
                 t.status            = 'S',
                 t.last_update_date  = SYSDATE,
                 t.error_message     = i.rownum,
                 t.inventory_item_id = i.inventory_item_id
           WHERE CURRENT OF c;
        
          --
        EXCEPTION
          WHEN my_exception THEN
            p_err_code := 1;
            --   fnd_file.put_line(fnd_file.log, l_err_message);
            UPDATE xxinv_move_source_dest_def t
               SET t.organization_id   = i.organization_id,
                   t.source_locator_id = i.source_locator_id,
                   t.dest_locator_id   = i.dest_locator_id,
                   t.status            = 'E',
                   t.error_message     = l_err_message,
                   t.last_update_date  = SYSDATE,
                   t.inventory_item_id = i.inventory_item_id
             WHERE CURRENT OF c;
          
        END;
      
      END LOOP;
    
      COMMIT;
      -- check source duplication 
      UPDATE xxinv_move_source_dest_def t
         SET t.last_update_date = SYSDATE,
             t.status           = 'E',
             t.error_message    = 'Record=' || error_message || ' ' ||
                                  'Duplicate source definition in file (' ||
                                  t.source_sub_inventory || '-' ||
                                  t.source_locator || ')'
       WHERE t.request_id = fnd_global.conc_request_id
         AND (t.organization_code, t.source_locator_id,
              t.source_sub_inventory, nvl(t.inventory_item_id, -1)) IN
             (SELECT tt.organization_code,
                     tt.source_locator_id,
                     tt.source_sub_inventory,
                     nvl(tt.inventory_item_id, -1)
                FROM xxinv_move_source_dest_def tt
               WHERE tt.request_id = fnd_global.conc_request_id
               GROUP BY tt.inventory_item_id,
                        tt.organization_code,
                        tt.source_locator_id,
                        tt.source_sub_inventory,
                        tt.inventory_item_id
              HAVING COUNT(*) > 1);
    
      COMMIT;
      -- display error 
      FOR i IN (SELECT t.error_message
                  FROM xxinv_move_source_dest_def t
                 WHERE t.status = 'E'
                   AND t.request_id = fnd_global.conc_request_id) LOOP
      
        fnd_file.put_line(fnd_file.log, i.error_message);
      
      END LOOP;
    
      --
    END IF;
  
  END;

END;
/
