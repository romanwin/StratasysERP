CREATE OR REPLACE PACKAGE BODY xxagile_process_mfg_item_pkg IS

   /********************************************************************************************
    AudioCodes LTd.
    Package Name : ac_a2o_process_item_categ_pkg
    Description : Wrapper package containing all customer item category wrapper procedure for item interface from Agile System
    Written by : Vinay Chappidi
    Date : 05-Dec-2007
   
    Change History
    ==============
    Date         Name              Ver       Change Description
    -----        ---------------   --------  ----------------------------------
    05-Dec-2007  Vinay Chappidi    DRAFT1A   Created this package, Initial Version
   ********************************************************************************************/

   -- package body level fndlog variable for getting the current runtime level
   gn_debug_level CONSTANT NUMBER := fnd_log.g_current_runtime_level;
   gv_module_name CONSTANT VARCHAR2(50) := 'Process_Item_Interface';
   gv_pkg_name    CONSTANT VARCHAR2(50) := 'XXAGILE_PROCESS_MFG_ITEM_PKG';
   gv_level       CONSTANT VARCHAR2(240) := fnd_log.level_statement;

   /********************************************************************************************
   AudioCodes LTd.
   Procedure Name : write_to_log
   Description : procedure will log messages to fnd_log_messages table when logging is enabled
   Written by : Vinay Chappidi
   Date : 05-Dec-2007
   ********************************************************************************************/
   PROCEDURE write_to_log(p_module IN VARCHAR2, p_msg IN VARCHAR2) IS
   BEGIN
      IF (gv_level >= gn_debug_level) THEN
         fnd_log.STRING(gv_level, gv_module_name || '.' || p_module, p_msg);
      END IF;
   END write_to_log;

   PROCEDURE process_mfg_item(p_mfg_name          IN VARCHAR2,
                              p_mfg_part_num      IN VARCHAR2,
                              p_inventory_item_id IN NUMBER,
                              p_transaction_type  IN VARCHAR2,
                              p_organization_id   IN NUMBER DEFAULT 23,
                              p_creation_date     IN DATE,
                              p_created_by        IN NUMBER,
                              p_last_update_date  IN DATE,
                              p_last_update_by    IN NUMBER,
                              p_attribute1        IN VARCHAR2, -- package quantity
                              p_attribute2        IN VARCHAR2, -- device marking, varchar2(15)
                              p_attribute3        IN DATE, -- obsolete date
                              p_attribute4        IN VARCHAR2, -- RoSH Compliant, varchar2(10)
                              p_attribute6        IN VARCHAR2, -- preferred, varchar2(15)
                              x_return_status     OUT NOCOPY VARCHAR2,
                              x_error_code        OUT NOCOPY NUMBER,
                              x_msg_count         OUT NOCOPY NUMBER,
                              x_msg_data          OUT NOCOPY VARCHAR2) IS
      n_user_id         NUMBER;
      l_organization_id NUMBER;
      -- cursor to fetch the manufacturer ID from the manufacturer's name
      CURSOR lcu_get_mfg_id(cp_mfg_name IN VARCHAR2) IS
         SELECT manufacturer_id
           FROM mtl_manufacturers
          WHERE nvl(description, manufacturer_name) = cp_mfg_name;
      n_mfg_id NUMBER;
   
      -- cursor to check if the same combination is getting created
      CURSOR lcu_mfg_exists(cp_mfg_id IN NUMBER, cp_inventory_item_id IN NUMBER, cp_mfg_part_num IN VARCHAR2) IS
         SELECT *
           FROM mtl_mfg_part_numbers_all_v
          WHERE manufacturer_id = cp_mfg_id AND
                inventory_item_id = cp_inventory_item_id AND
                mfg_part_num = cp_mfg_part_num;
      lr_mfg_exists lcu_mfg_exists%ROWTYPE;
   
      -- get the existing details for the manufacturer ID and mfg_number
      CURSOR lcu_get_mfg_row(cp_mfg_id IN NUMBER, cp_inventory_item_id IN NUMBER) IS
         SELECT *
           FROM mtl_mfg_part_numbers_all_v
          WHERE manufacturer_id = cp_mfg_id AND
                inventory_item_id = cp_inventory_item_id;
      lr_get_mfg_row lcu_mfg_exists%ROWTYPE; --lcu_get_mfg_row%ROWTYPE;
   
      l_exception EXCEPTION;
      v_rowid VARCHAR2(25);
   
      v_transaction_type VARCHAR2(10);
      n_attribute1       NUMBER; -- package quantity
      v_attribute2       VARCHAR2(15); -- device marking, varchar2(15)
      d_attribute3       DATE; -- obsolete date
      b_attribute3_null  BOOLEAN := FALSE;
      v_attribute4       VARCHAR2(10); -- RoSH Compliant, varchar2(10)
      v_attribute6       VARCHAR2(15); -- preferred, varchar2(15)
      v_item             VARCHAR2(50);
      l_preferred        VARCHAR2(20);
   
   BEGIN
   
      write_to_log('PROCESS_MFG_ITEM', 'Inside this procedure');
      --autonomous_proc.dump_temp('Inside this procedure');
      l_organization_id := xxinv_utils_pkg.get_master_organization_id;
      BEGIN
         SELECT msi.segment1
           INTO v_item
           FROM mtl_system_items_b msi
          WHERE msi.inventory_item_id = p_inventory_item_id AND
                organization_id = l_organization_id;
      EXCEPTION
         WHEN OTHERS THEN
            v_item := NULL;
      END;
   
      /*      BEGIN
      
               SELECT preferred
                 INTO l_preferred
                 FROM xxobjt_agile_aml xaa
                WHERE xaa.item_number = v_item AND
                      xaa.manufacturer = p_mfg_name AND
                      xaa.mpn = p_mfg_part_num AND
                      creation_date =
                      (SELECT MAX(creation_date)
                         FROM xxobjt_agile_aml xaa1
                        WHERE xaa1.item_number = xaa.item_number AND
                              xaa1.manufacturer = xaa.manufacturer AND
                              xaa1.mpn = xaa.mpn AND
                              xaa1.transaction_id = xaa.transaction_id);
      
            EXCEPTION
               WHEN OTHERS THEN
                  l_preferred := NULL;
            END;
      */
      v_transaction_type := p_transaction_type;
      -- check if this procedure is invoked for new item creation or modification
      -- change the user accordingly
      IF (upper(v_transaction_type) = 'CREATE') THEN
         n_user_id := 1650; --nvl(p_created_by,0);
      ELSIF (upper(v_transaction_type) = 'UPDATE') THEN
         n_user_id := 1650; --nvl(p_last_update_by,0);
      END IF;
   
      write_to_log('PROCESS_MFG_ITEM', 'User ID: ' || n_user_id);
      --autonomous_proc.dump_temp('User ID: '|| n_user_id);
   
      -- set the apps context
   
      --    FND_GLOBAL.apps_initialize(n_user_id,0,0);
   
      IF fnd_global.user_id = -1 THEN
         -- Added due to 10g Upgrade Gabriel Coronel 18/05/2008
         fnd_global.apps_initialize(n_user_id, 0, 0);
      END IF;
   
      -- get the manufacturer ID for the manufacturer name
      OPEN lcu_get_mfg_id(p_mfg_name);
      FETCH lcu_get_mfg_id
         INTO n_mfg_id;
      CLOSE lcu_get_mfg_id;
   
      write_to_log('PROCESS_MFG_ITEM', 'Manufacturer ID: ' || n_mfg_id);
      --autonomous_proc.dump_temp('Manufacturer ID: '|| n_mfg_id);
   
      IF (n_mfg_id IS NULL AND v_transaction_type = 'CREATE') THEN
      
         -- Manufacturer is not exiting in the system then we need to create a new manufacturer
         INSERT INTO mtl_manufacturers
            (manufacturer_id,
             manufacturer_name,
             description,
             last_update_date,
             last_updated_by,
             creation_date,
             created_by)
         VALUES
            (mtl_manufacturers_s.NEXTVAL,
             TRIM(substr(p_mfg_name, 1, 30)),
             p_mfg_name,
             p_last_update_date,
             p_last_update_by,
             p_creation_date,
             p_created_by)
         RETURNING manufacturer_id INTO n_mfg_id;
      
      END IF;
   
      IF (v_transaction_type = 'CREATE') THEN
         OPEN lcu_mfg_exists(n_mfg_id, p_inventory_item_id, p_mfg_part_num);
         FETCH lcu_mfg_exists
            INTO lr_mfg_exists;
         IF (lcu_mfg_exists%FOUND) THEN
            v_transaction_type := 'UPDATE';
            -- set a flag to update the attribute3 to NULL
            b_attribute3_null := TRUE;
         END IF;
         CLOSE lcu_mfg_exists;
      END IF;
   
      IF (v_transaction_type = 'CREATE') THEN
      
         write_to_log('PROCESS_MFG_ITEM',
                      'Before Create ROW_ID: ' || nvl(v_rowid, 'NULL'));
         --autonomous_proc.dump_temp('Before Create ROW_ID: '|| nvl(v_rowid,'NULL'));
         mtl_mfg_part_numbers_pkg.insert_row(x_rowid              => v_rowid,
                                             x_manufacturer_id    => n_mfg_id,
                                             x_mfg_part_num       => p_mfg_part_num,
                                             x_inventory_item_id  => p_inventory_item_id,
                                             x_last_update_date   => p_last_update_date,
                                             x_last_updated_by    => p_last_update_by,
                                             x_creation_date      => p_creation_date,
                                             x_created_by         => p_created_by,
                                             x_last_update_login  => NULL, -- check this value
                                             x_organization_id    => l_organization_id, -- always
                                             x_description        => NULL,
                                             x_attribute_category => NULL,
                                             x_attribute1         => NULL, --l_preferred, - Changed by Galit request 8/9/09
                                             x_attribute2         => p_attribute2,
                                             x_attribute3         => p_attribute3,
                                             x_attribute4         => p_attribute4,
                                             x_attribute5         => NULL,
                                             x_attribute6         => p_attribute6,
                                             x_attribute7         => NULL,
                                             x_attribute8         => NULL,
                                             x_attribute9         => NULL,
                                             x_attribute10        => NULL,
                                             x_attribute11        => NULL,
                                             x_attribute12        => NULL,
                                             x_attribute13        => NULL,
                                             x_attribute14        => NULL,
                                             x_attribute15        => NULL);
      
         write_to_log('PROCESS_MFG_ITEM',
                      'After Create ROW_ID: ' || nvl(v_rowid, 'NULL'));
         --autonomous_proc.dump_temp('After Create ROW_ID: '|| nvl(v_rowid,'NULL'));
         -- check if the record is created by checking the value of rowid
         IF (v_rowid IS NULL) THEN
            fnd_message.set_name('ACCST', 'ACCST_DATABASE_ERROR');
            fnd_message.set_token('SQLERRM', SQLERRM);
            x_msg_data  := fnd_message.get;
            x_msg_count := 1;
            RAISE l_exception;
         END IF;
      ELSIF (v_transaction_type = 'UPDATE') THEN
      
         NULL;
      
         -- Changed by Galit request 9/12/09
         /*         OPEN lcu_mfg_exists(n_mfg_id, p_inventory_item_id, p_mfg_part_num);
         FETCH lcu_mfg_exists
            INTO lr_get_mfg_row;
         CLOSE lcu_mfg_exists;
         
         write_to_log('PROCESS_MFG_ITEM',
                      'Row Identified,  lr_get_mfg_row.row_id: ' ||
                      lr_get_mfg_row.row_id);
         --autonomous_proc.dump_temp('Row Identified,  lr_get_mfg_row.row_id: '||lr_get_mfg_row.row_id);
         
         IF (lr_get_mfg_row.row_id IS NOT NULL) THEN
         
            write_to_log('PROCESS_MFG_ITEM',
                         'Before Updating Existing Record');
            --autonomous_proc.dump_temp('Before Updating Existing Record');
         
            mtl_mfg_part_numbers_pkg.update_row(x_rowid              => lr_get_mfg_row.row_id,
                                                x_manufacturer_id    => lr_get_mfg_row.manufacturer_id,
                                                x_mfg_part_num       => nvl(p_mfg_part_num,
                                                                            lr_get_mfg_row.mfg_part_num), -- only this is can be changed
                                                x_inventory_item_id  => lr_get_mfg_row.inventory_item_id,
                                                x_last_update_date   => nvl(p_last_update_date,
                                                                            lr_get_mfg_row.last_update_date),
                                                x_last_updated_by    => nvl(p_last_update_by,
                                                                            lr_get_mfg_row.last_updated_by),
                                                x_last_update_login  => lr_get_mfg_row.last_update_login,
                                                x_organization_id    => lr_get_mfg_row.organization_id,
                                                x_description        => lr_get_mfg_row.description,
                                                x_attribute_category => lr_get_mfg_row.attribute_category,
                                                x_attribute1         => l_preferred,
                                                x_attribute2         => v_attribute2,
                                                x_attribute3         => d_attribute3,
                                                x_attribute4         => v_attribute4,
                                                x_attribute5         => lr_get_mfg_row.attribute5,
                                                x_attribute6         => v_attribute6,
                                                x_attribute7         => lr_get_mfg_row.attribute7,
                                                x_attribute8         => lr_get_mfg_row.attribute8,
                                                x_attribute9         => lr_get_mfg_row.attribute9,
                                                x_attribute10        => lr_get_mfg_row.attribute10,
                                                x_attribute11        => lr_get_mfg_row.attribute11,
                                                x_attribute12        => lr_get_mfg_row.attribute12,
                                                x_attribute13        => lr_get_mfg_row.attribute13,
                                                x_attribute14        => lr_get_mfg_row.attribute14,
                                                x_attribute15        => lr_get_mfg_row.attribute15);
            write_to_log('PROCESS_MFG_ITEM',
                         'After Updating Existing Record');
            --autonomous_proc.dump_temp('After Updating Existing Record');
         ELSE
            fnd_message.set_name('ACCST', 'AC_CST_A2O_NO_MATCH_REC');
            fnd_message.set_token('MFG_NAME', p_mfg_name);
            fnd_message.set_token('MFG_NUM', p_mfg_part_num);
            x_msg_data  := fnd_message.get;
            x_msg_count := 1;
            RAISE l_exception;
         END IF;*/
      
      ELSIF (v_transaction_type = 'DELETE') THEN
      
         NULL;
      
         -- Changed by Galit request 9/12/09
         /*        OPEN lcu_mfg_exists(n_mfg_id, p_inventory_item_id, p_mfg_part_num);
                 FETCH lcu_mfg_exists
                    INTO lr_get_mfg_row;
                 CLOSE lcu_mfg_exists;
         
                 BEGIN
         
                    write_to_log('PROCESS_MFG_ITEM',
                                 'Row Identified,  lr_get_mfg_row.row_id: ' ||
                                 lr_get_mfg_row.row_id);
                    --autonomous_proc.dump_temp('Row Identified,  lr_get_mfg_row.row_id: '||lr_get_mfg_row.row_id);
         
                    IF (lr_get_mfg_row.row_id IS NOT NULL) THEN
         
                       write_to_log('PROCESS_MFG_ITEM',
                                    'Before Updating Existing Record');
                       --autonomous_proc.dump_temp('Before Updating Existing Record');
                       mtl_mfg_part_numbers_pkg.delete_row(x_rowid => lr_get_mfg_row.row_id);
                       --autonomous_proc.dump_temp('After Updating Existing Record');
                       -- ELSE
                       --    fnd_message.set_name('ACCST', 'AC_CST_A2O_NO_MATCH_REC');
                       --    fnd_message.set_token('MFG_NAME', p_mfg_name);
                       --    fnd_message.set_token('MFG_NUM', p_mfg_part_num);
                       ----    x_msg_data  := fnd_message.get;
                       --    x_msg_count := 1;
                       --    RAISE l_exception;
                    END IF;
         
                 EXCEPTION
                    WHEN OTHERS THEN
                       NULL;
                 END;
         */
      END IF;
   
      -- COMMIT;
      -- commit will not be done in the individual packages
      -- will be performed in the invoking BPEL process
      x_msg_data      := NULL;
      x_msg_count     := 0;
      x_error_code    := '';
      x_return_status := ego_item_pub.g_ret_sts_success;
   
      write_to_log('PROCESS_MFG_ITEM',
                   'Successfully completed processing, exiting the procedure.');
      --autonomous_proc.dump_temp('Successfully completed processing, exiting the procedure.');
   
   EXCEPTION
      WHEN l_exception THEN
         x_error_code    := '';
         x_return_status := ego_item_pub.g_ret_sts_error;
         ego_item_msg.add_error_text(ego_item_pvt.g_item_indx, x_msg_data);
         write_to_log('PROCESS_MFG_ITEM',
                      'From l_exception Exception: ' || x_msg_data);
         --autonomous_proc.dump_temp('From l_exception Exception: '||x_msg_data);
      
         --Update table for next XML file creation
         UPDATE xxobjt.xxobjt_agile_items xx
            SET xx.attribute1 = 'E', xx.attribute2 = x_msg_data
          WHERE xx.item_number = v_item AND
                xx.attribute1 = 'S';
         COMMIT;
      
      WHEN OTHERS THEN
         fnd_message.set_name('INV', 'INV_ITEM_UNEXPECTED_ERROR');
         fnd_message.set_token('PACKAGE_NAME',
                               'XXAGILE_PROCESS_MFG_ITEM_PKG');
         fnd_message.set_token('PROCEDURE_NAME', 'PROCESS_MFG_ITEM');
         fnd_message.set_token('ERROR_TEXT', SQLERRM);
         x_error_code    := SQLCODE;
         x_return_status := ego_item_pub.g_ret_sts_unexp_error;
         x_msg_count     := 1;
         x_msg_data      := fnd_message.get;
         ego_item_msg.add_error_text(ego_item_pvt.g_item_indx, x_msg_data);
         write_to_log('PROCESS_MFG_ITEM',
                      'From Others Exception: ' || x_msg_data);
         --autonomous_proc.dump_temp('From Others Exception: '||x_msg_data);
      
         --Update table for next XML file creation
         UPDATE xxobjt.xxobjt_agile_items xx
            SET xx.attribute1 = 'E', xx.attribute2 = x_msg_data
          WHERE xx.item_number = v_item AND
                xx.attribute1 = 'S';
         COMMIT;
      
   END process_mfg_item;

END xxagile_process_mfg_item_pkg;
/

