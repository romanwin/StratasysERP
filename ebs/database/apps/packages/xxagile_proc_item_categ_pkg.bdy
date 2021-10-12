CREATE OR REPLACE PACKAGE BODY xxagile_proc_item_categ_pkg IS

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
   gv_pkg_name    CONSTANT VARCHAR2(50) := 'MODU_A2O_PROCESS_ITEM_CATEG_PKG';
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
   PROCEDURE apps_initialize(p_user_id IN NUMBER) IS
   
      PRAGMA AUTONOMOUS_TRANSACTION;
   BEGIN
      fnd_global.apps_initialize(p_user_id, 0, 0);
      COMMIT;
   END;

   /*procedure apps_initialize(p_user_id in number) is
    
   pragma autonomous_transaction;
   begin
   FND_GLOBAL.apps_initialize(p_user_id,0,0);
   commit;
   end; */

   /********************************************************************************************
   AudioCodes LTd.
   Procedure Name : process_item_categ
   Description : procedure will assign inventory Item to Item Categories
   Written by : Vinay Chappidi
   Date : 05-Dec-2007
   ********************************************************************************************/
   PROCEDURE process_item_categ(p_inventory_item_id IN NUMBER,
                                p_category_set_name IN VARCHAR2,
                                p_category_name     IN VARCHAR2,
                                p_creation_date     IN DATE,
                                p_created_by        IN NUMBER,
                                p_last_update_date  IN DATE,
                                p_last_update_by    IN NUMBER,
                                x_return_status     OUT NOCOPY VARCHAR2,
                                x_error_code        OUT NOCOPY NUMBER,
                                x_msg_count         OUT NOCOPY NUMBER,
                                x_msg_data          OUT NOCOPY VARCHAR2) IS
   
      -- cursor to fetch category id for the matching category name
      CURSOR lcu_category_c(cp_category_name IN VARCHAR2, cp_structure_id IN NUMBER) IS
         SELECT category_id
           FROM mtl_categories_v
          WHERE category_concat_segs LIKE '%.' || cp_category_name || '.%' AND
                structure_id = cp_structure_id AND
                rownum = 1;
      n_category_id NUMBER;
   
      CURSOR lcu_category_m(cp_category_name IN VARCHAR2, cp_structure_id IN NUMBER) IS
         SELECT category_id
           FROM mtl_categories_v
          WHERE category_concat_segs = cp_category_name AND
                structure_id = cp_structure_id;
   
      -- cursor to fetch category id for the matching category desc and structure
      CURSOR lcu_get_sm_cat_id(cp_structure_id IN NUMBER, cp_category_desc IN VARCHAR2) IS
         SELECT category_id
           FROM mtl_categories_v
          WHERE structure_id = cp_structure_id AND
                description LIKE cp_category_desc;
   
      -- cursor to fetch the category set ID for the matching category set name
      CURSOR lcu_category_sets(cp_category_set_name IN VARCHAR2) IS
         SELECT category_set_id, control_level, structure_id
           FROM mtl_category_sets_v
          WHERE category_set_name = cp_category_set_name;
      lr_category_sets lcu_category_sets%ROWTYPE;
   
      -- cursor to get all organizations to which an item is attached
      CURSOR lcu_get_item_orgs(cp_inventory_item_id IN NUMBER, cp_control_level IN NUMBER, cp_category_set_id IN NUMBER) IS
         SELECT mic.*
           FROM mtl_item_categories mic, mtl_parameters mp
          WHERE mic.inventory_item_id = cp_inventory_item_id AND
                mic.organization_id = mp.organization_id AND
                category_set_id = cp_category_set_id AND
                ((cp_control_level = 1 AND
                mic.organization_id = mp.master_organization_id) OR
                (cp_control_level = 2));
   
      CURSOR lcu_check_rec_exists(cp_inventory_item_id IN NUMBER, cp_category_set_id IN NUMBER) IS
         SELECT 'x'
           FROM mtl_item_categories
          WHERE inventory_item_id = cp_inventory_item_id AND
                category_set_id = cp_category_set_id;
      v_temp VARCHAR2(1);
   
      n_inv_org_id NUMBER;
   
      -- get the organizations to which item is assigned to
      CURSOR lcu_get_inv_item_orgs(cp_inventory_item_id IN NUMBER, cp_control_level IN NUMBER) IS
         SELECT msi.organization_id
           FROM mtl_system_items msi, mtl_parameters mp
          WHERE msi.inventory_item_id = cp_inventory_item_id AND
                msi.organization_id = mp.organization_id AND
                ((cp_control_level = 1 AND
                msi.organization_id = mp.master_organization_id) OR
                (cp_control_level = 2));
   
      v_error_code       VARCHAR2(30);
      n_msg_count        NUMBER;
      v_msg_data         VARCHAR2(2000);
      v_return_status    VARCHAR2(30);
      n_temp_num         NUMBER;
      v_error_data       VARCHAR2(4000);
      v_error_return     VARCHAR2(32767);
      n_user_id          NUMBER := 0;
      v_transaction_type VARCHAR2(30);
      l_exception EXCEPTION;
      v_category_c VARCHAR2(50);
      v_category_m VARCHAR2(50);
      v_item       VARCHAR2(50);
   
      CURSOR cr_category_set IS
         SELECT DISTINCT c.category_set_name,
                         a.category_set_id,
                         b.default_category_id
           FROM mtl_default_category_sets a,
                mtl_category_sets_b       b,
                mtl_category_sets_tl      c
          WHERE a.category_set_id = b.category_set_id AND
                a.category_set_id = c.category_set_id AND
                c.LANGUAGE = userenv('LANG') AND
                b.default_category_id IS NOT NULL AND
                c.category_set_name = p_category_set_name;
   
   BEGIN
   
      write_to_log('PROCESS_ITEM_CATEG', 'Inside this procedure');
      --autonomous_proc.dump_temp('Inside this procedure');
      -- check if this procedure is invoked for new item creation or modification
      -- change the user accordingly
   
      BEGIN
         SELECT MAX(msi.segment1)
           INTO v_item
           FROM mtl_system_items_b msi
          WHERE msi.inventory_item_id = p_inventory_item_id;
      EXCEPTION
         WHEN OTHERS THEN
            v_item := NULL;
      END;
   
      n_user_id := nvl(p_created_by, nvl(p_last_update_by, 0));
      write_to_log('PROCESS_ITEM_CATEG', 'User ID: ' || n_user_id);
      --autonomous_proc.dump_temp('User ID: '||n_user_id);
      -- set the apps context
   
      IF fnd_global.user_id = -1 THEN
         -- Added due to 10g Upgrade Gabriel Coronel 18/05/2008          
         fnd_global.apps_initialize(n_user_id, 0, 0);
      END IF;
   
      write_to_log('PROCESS_ITEM_CATEG', 'After Setting the context');
      --autonomous_proc.dump_temp('After Setting the context');
   
      --Arik
      FOR i IN cr_category_set LOOP
         --For update - if category not exist then raise  
         n_category_id := NULL; --i.default_category_id;
         --       
         -- get the category set ID for the given category set name
         OPEN lcu_category_sets(p_category_set_name);
         FETCH lcu_category_sets
            INTO lr_category_sets;
         CLOSE lcu_category_sets;
         write_to_log('PROCESS_ITEM_CATEG',
                      'Category Set ID: ' ||
                      nvl(lr_category_sets.category_set_id, -1) ||
                      ', Controlled at 1- Master, 2 Org:' ||
                      nvl(lr_category_sets.control_level, -1));
         --autonomous_proc.dump_temp('Category Set ID: '|| nvl(lr_category_sets.category_set_id,-1)||', Controlled at 1- Master, 2 Org:'||nvl(lr_category_sets.control_level,-1));
         -- if the category set id could not be derived then raise exception and return
         IF (lr_category_sets.category_set_id IS NULL) THEN
            fnd_message.set_name('ACCST', 'AC_CST_A2O_ITM_CAT_SET_INVALID');
            fnd_message.set_token('CAT_SET_NAME',
                                  i.category_set_name /*p_category_set_name*/);
            x_msg_data  := fnd_message.get;
            x_msg_count := 1;
            RAISE l_exception;
         END IF;
      
         --Arik
         IF i.category_set_name = 'Class Category Set' THEN
            -- get the category ID for the given category name
            OPEN lcu_category_c(p_category_name,
                                lr_category_sets.structure_id);
            FETCH lcu_category_c
               INTO n_category_id;
            CLOSE lcu_category_c;
            dbms_output.put_line(n_category_id);
         ELSE
            OPEN lcu_category_m(p_category_name,
                                lr_category_sets.structure_id);
            FETCH lcu_category_m
               INTO n_category_id;
            CLOSE lcu_category_m;
         END IF;
         --
         write_to_log('PROCESS_ITEM_CATEG',
                      'Category ID: ' || nvl(n_category_id, -1));
         --autonomous_proc.dump_temp('Category ID: '|| nvl(n_category_id,-1));
         -- if the category id could not be derived then raise exception and return
         IF (n_category_id IS NULL) THEN
            fnd_message.set_name('ACCST', 'AC_CST_A2O_ITM_CAT_INVALID');
            fnd_message.set_token('CAT_NAME', p_category_name);
            x_msg_data  := fnd_message.get;
            x_msg_count := 1;
            RAISE l_exception;
         END IF;
      
         v_temp := NULL; --Arik
         -- check if the combination of inventory Item and Category Set is existing in the system
         -- if exists then it is Update else it is Create
         OPEN lcu_check_rec_exists(p_inventory_item_id,
                                   lr_category_sets.category_set_id);
         FETCH lcu_check_rec_exists
            INTO v_temp;
         CLOSE lcu_check_rec_exists;
         IF (v_temp = 'x') THEN
            v_transaction_type := 'UPDATE';
         ELSE
            v_transaction_type := 'CREATE';
         END IF;
      
         write_to_log('PROCESS_ITEM_CATEG',
                      'Transaction Type: ' || v_transaction_type);
         --autonomous_proc.dump_temp('Transaction Type: '|| v_transaction_type);
         IF (v_transaction_type = 'UPDATE') THEN
            write_to_log('PROCESS_ITEM_CATEG', 'Before Delete Loop');
            --autonomous_proc.dump_temp('Before Delete Loop');
         
            FOR lr_item_cat IN lcu_get_item_orgs(p_inventory_item_id,
                                                 lr_category_sets.control_level,
                                                 lr_category_sets.category_set_id) LOOP
               write_to_log('PROCESS_ITEM_CATEG',
                            'In Delete Loop , Org ID: ' ||
                            lr_item_cat.organization_id);
               --autonomous_proc.dump_temp('In Delete Loop , Org ID: '||lr_item_cat.organization_id);
               inv_item_category_pub.update_category_assignment(p_api_version       => '1.0',
                                                                p_init_msg_list     => ego_item_pub.g_true,
                                                                p_commit            => ego_item_pub.g_true,
                                                                p_category_id       => n_category_id,
                                                                p_old_category_id   => lr_item_cat.category_id,
                                                                p_category_set_id   => lr_item_cat.category_set_id,
                                                                p_inventory_item_id => p_inventory_item_id,
                                                                p_organization_id   => lr_item_cat.organization_id,
                                                                x_return_status     => v_return_status,
                                                                x_errorcode         => v_error_code,
                                                                x_msg_count         => n_msg_count,
                                                                x_msg_data          => v_msg_data);
            
               /*
                           -- delete the item category for all inventory organizations and then create it
                           for lr_item_cat IN lcu_get_item_orgs(p_inventory_item_id, lr_category_sets.control_level) loop
                               write_to_log('PROCESS_ITEM_CATEG','In Delete Loop , Org ID: '||lr_item_cat.organization_id);
                               --autonomous_proc.dump_temp('In Delete Loop , Org ID: '||lr_item_cat.organization_id);
                               INV_ITEM_CATEGORY_PUB.delete_category_assignment(p_api_version => '1.0',
                                                                                p_init_msg_list => EGO_ITEM_PUB.g_true,
                                                                                p_commit => EGO_ITEM_PUB.g_false,
                                                                                p_category_id => lr_item_cat.category_id,
                                                                                p_category_set_id => lr_item_cat.category_set_id,
                                                                                p_inventory_item_id => p_inventory_item_id,
                                                                                p_organization_id =>  lr_item_cat.organization_id,
                                                                                x_return_status => v_return_status,
                                                                                x_errorcode => v_error_code,
                                                                                x_msg_count => n_msg_count,
                                                                                x_msg_data => v_msg_data);
               
               */
               IF (v_return_status <> ego_item_pub.g_ret_sts_success) THEN
                  IF (n_msg_count = 1) THEN
                     fnd_message.set_encoded(v_msg_data);
                     v_error_return  := fnd_message.get;
                     x_return_status := ego_item_pub.g_ret_sts_error;
                  ELSE
                     FOR n_cnt IN 1 .. n_msg_count LOOP
                        fnd_msg_pub.get(n_cnt,
                                        'T',
                                        v_error_data,
                                        n_temp_num);
                        fnd_message.set_encoded(v_error_data);
                        v_error_return := v_error_return || fnd_message.get;
                     END LOOP;
                     x_return_status := ego_item_pub.g_ret_sts_error;
                  END IF;
                  x_msg_data   := v_error_return;
                  x_error_code := v_error_code;
                  x_msg_count  := n_msg_count;
                  RAISE l_exception;
               ELSE
                  x_return_status := 'S';
                  x_msg_data      := NULL;
                  x_msg_count     := n_msg_count;
               END IF;
            END LOOP;
            write_to_log('PROCESS_ITEM_CATEG', 'Update Completed');
            --autonomous_proc.dump_temp('Update Completed');
         ELSIF (v_transaction_type = 'CREATE') THEN
         
            write_to_log('PROCESS_ITEM_CATEG',
                         'Before entering Create Loop');
            --autonomous_proc.dump_temp('Before entering Create Loop');
         
            -- incase of update delete should be done without any errors.
            -- if errors then display that errors
            IF (nvl(x_return_status, ego_item_pub.g_ret_sts_success) <>
               ego_item_pub.g_ret_sts_error) THEN
               write_to_log('PROCESS_ITEM_CATEG', 'In the Create Loop');
               --autonomous_proc.dump_temp('In the Create Loop');
            
               FOR lr_inv_org_id IN lcu_get_inv_item_orgs(p_inventory_item_id,
                                                          lr_category_sets.control_level) LOOP
                  write_to_log('PROCESS_ITEM_CATEG',
                               'Creating For Org ID: ' ||
                               lr_inv_org_id.organization_id);
                  --autonomous_proc.dump_temp('Creating For Org ID: '|| lr_inv_org_id.organization_id);
                  inv_item_category_pub.create_category_assignment(p_api_version       => '1.0',
                                                                   p_init_msg_list     => ego_item_pub.g_true,
                                                                   p_commit            => ego_item_pub.g_true,
                                                                   p_category_id       => n_category_id,
                                                                   p_category_set_id   => lr_category_sets.category_set_id,
                                                                   p_inventory_item_id => p_inventory_item_id,
                                                                   p_organization_id   => lr_inv_org_id.organization_id,
                                                                   x_return_status     => v_return_status,
                                                                   x_errorcode         => v_error_code,
                                                                   x_msg_count         => n_msg_count,
                                                                   x_msg_data          => v_msg_data);
                  dbms_output.put_line(v_return_status);
                  IF (v_return_status <> ego_item_pub.g_ret_sts_success) THEN
                     IF (n_msg_count = 1) THEN
                        fnd_message.set_encoded(v_msg_data);
                        v_error_return := fnd_message.get;
                     ELSE
                        FOR n_cnt IN 1 .. n_msg_count LOOP
                           fnd_msg_pub.get(n_cnt,
                                           'T',
                                           v_error_data,
                                           n_temp_num);
                           fnd_message.set_encoded(v_error_data);
                           v_error_return := v_error_return ||
                                             fnd_message.get;
                        END LOOP;
                        x_return_status := ego_item_pub.g_ret_sts_error;
                     END IF;
                     x_return_status := ego_item_pub.g_ret_sts_error;
                     x_msg_data      := v_error_return;
                     x_error_code    := v_error_code;
                     x_msg_count     := n_msg_count;
                  ELSE
                     x_return_status := 'S';
                     x_msg_data      := NULL;
                     x_msg_count     := n_msg_count;
                  END IF;
               END LOOP;
            ELSE
               fnd_message.set_name('ACCST',
                                    'AC_CST_A2O_ERROR_ITEM_CREATION');
               x_msg_data   := fnd_message.get;
               x_error_code := v_error_code;
               x_msg_count  := n_msg_count;
               RAISE l_exception;
            END IF;
         END IF;
      
      /*      x_msg_data := '';
              x_error_code := '';
              x_msg_count := 0;
              x_return_status := EGO_ITEM_PUB.g_ret_sts_success;*/
      --autonomous_proc.dump_temp('Successfully Completed processing');
      END LOOP; --Cr_Category_Set
   
   EXCEPTION
      WHEN l_exception THEN
         x_return_status := ego_item_pub.g_ret_sts_error;
         x_error_code    := v_error_code;
         ego_item_msg.add_error_text(ego_item_pvt.g_item_indx, x_msg_data);
         --autonomous_proc.dump_temp(x_msg_data);
      
         --Update table for next XML file creation 
         UPDATE xxobjt.xxobjt_agile_items xx
            SET xx.attribute1 = 'E',
                xx.attribute2 = nvl(v_error_return,
                                    'Category Set/Category Does Not Exist In The System')
          WHERE xx.item_number = v_item AND
                xx.attribute1 = 'S';
         COMMIT;
      
      WHEN OTHERS THEN
         fnd_message.set_name('INV', 'INV_ITEM_UNEXPECTED_ERROR');
         fnd_message.set_token('PACKAGE_NAME',
                               'AC_A2O_PROCESS_ITEM_CATEG_PKG');
         fnd_message.set_token('PROCEDURE_NAME', 'PROCESS_ITEM_CATEG');
         fnd_message.set_token('ERROR_TEXT', SQLERRM);
         x_error_code    := SQLCODE;
         x_return_status := ego_item_pub.g_ret_sts_unexp_error;
         x_msg_count     := 1;
         x_msg_data      := fnd_message.get;
         ego_item_msg.add_error_text(ego_item_pvt.g_item_indx, x_msg_data);
         --autonomous_proc.dump_temp(x_msg_data);
      
         --Update table for next XML file creation 
         UPDATE xxobjt.xxobjt_agile_items xx
            SET xx.attribute1 = 'E', xx.attribute2 = fnd_message.get
          WHERE xx.item_number = v_item AND
                xx.attribute1 = 'S';
         COMMIT;
      
   END process_item_categ;

END xxagile_proc_item_categ_pkg;
/

