CREATE OR REPLACE PACKAGE BODY xxagile_process_cust_item_pkg IS

   /********************************************************************************************
    AudioCodes LTd.
    Package Name : XXAGILE_PROCESS_CUST_ITEM_PKG
    Description : Wrapper package containing customer item creation and modification wrapper procedure for item interface from Agile System
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
   gv_pkg_name    CONSTANT VARCHAR2(50) := 'XXAGILE_PROCESS_CUST_ITEM_PKG';
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

   -- this function will get the master organization id for a given inventory organization id
   FUNCTION get_master_organization_id(p_inventory_org_id IN NUMBER)
      RETURN NUMBER IS
      CURSOR lcu_get_mast_org_id(cp_inv_org_id IN NUMBER) IS
         SELECT mp.master_organization_id
           FROM mtl_parameters mp
          WHERE mp.organization_id = cp_inv_org_id;
   
      n_mast_org_id NUMBER;
   BEGIN
   
      IF (p_inventory_org_id IS NOT NULL) THEN
         OPEN lcu_get_mast_org_id(p_inventory_org_id);
         FETCH lcu_get_mast_org_id
            INTO n_mast_org_id;
         CLOSE lcu_get_mast_org_id;
         RETURN n_mast_org_id;
      ELSE
         RETURN NULL;
      END IF;
   EXCEPTION
      WHEN OTHERS THEN
         RETURN NULL;
   END get_master_organization_id;

   PROCEDURE process_customer_item(p_customer_name         IN VARCHAR2,
                                   p_customer_item         IN VARCHAR2,
                                   p_inventory_item_id     IN NUMBER,
                                   p_inactive_flag         IN VARCHAR2,
                                   p_preference_number     IN NUMBER,
                                   p_item_definition_level IN NUMBER DEFAULT 1,
                                   p_organization_id       IN NUMBER DEFAULT 23,
                                   p_customer_item_desc    IN VARCHAR2, -- varchar2(240)
                                   p_creation_date         IN DATE,
                                   p_created_by            IN NUMBER,
                                   p_last_update_date      IN DATE,
                                   p_last_update_by        IN NUMBER,
                                   x_return_status         OUT NOCOPY VARCHAR2,
                                   x_error_code            OUT NOCOPY NUMBER,
                                   x_msg_count             OUT NOCOPY NUMBER,
                                   x_msg_data              OUT NOCOPY VARCHAR2) IS
   
      -- cursor for fetching the customer number and customer id for a given customer name
      -- order by will ensure that the earliest active account will be used for creating
      -- customer items
      CURSOR lcu_check_cust(cp_customer_name IN VARCHAR2, cp_account_status IN VARCHAR2) IS
         SELECT cust_acct.account_number  customer_number,
                cust_acct.cust_account_id customer_id
           FROM hz_parties party, hz_cust_accounts cust_acct
          WHERE cust_acct.party_id = party.party_id AND
                party.party_name = cp_customer_name AND
                cust_acct.status = cp_account_status
          ORDER BY cust_acct.cust_account_id;
      lr_check_cust lcu_check_cust%ROWTYPE;
   
      n_customer_item_id NUMBER := -1;
   
      CURSOR lcu_get_xrefs_rec(cp_customer_item_id IN NUMBER, cp_inventory_item_id IN NUMBER) IS
         SELECT *
           FROM mtl_customer_item_xrefs_v
          WHERE customer_item_id = cp_customer_item_id AND
                inventory_item_id = cp_inventory_item_id;
   
      lr_get_x_refs_rec lcu_get_xrefs_rec%ROWTYPE;
   
      CURSOR lcu_get_rank(cp_customer_item IN VARCHAR2) IS
         SELECT MAX(rank)
           FROM mtl_customer_item_xrefs_v
          WHERE customer_item_number = cp_customer_item;
   
      -- one invetory item can be associated to only one active customer item
      -- if user tries to create a new xrefs with the same inventory item and Customer Item then abort process
      CURSOR lcu_exists_xrefs(cp_inventory_item_id IN NUMBER, cp_customer_item_number IN VARCHAR2) IS
         SELECT customer_number,
                customer_name,
                customer_item_number,
                customer_item_id
           FROM mtl_customer_item_xrefs_v
          WHERE inventory_item_id = cp_inventory_item_id AND
                customer_item_number <> cp_customer_item_number AND
                inactive_flag = 'N';
      lr_exists_xrefs lcu_exists_xrefs%ROWTYPE;
   
      CURSOR lcu_exists_cust_xrefs(cp_inventory_item_id IN NUMBER, cp_customer_item_number IN VARCHAR2, cp_customer_id IN NUMBER, cp_customer_number IN VARCHAR2) IS
         SELECT customer_number, customer_name, customer_item_number
           FROM mtl_customer_item_xrefs_v
          WHERE inventory_item_id = cp_inventory_item_id AND
                customer_item_number = cp_customer_item_number AND
                customer_id <> cp_customer_id AND
                customer_number <> cp_customer_number AND
                inactive_flag = 'N';
   
      lr_exists_cust_xrefs lcu_exists_cust_xrefs%ROWTYPE;
   
      -- this cursor will be used to check the transaction type
      -- if a record is found then it is presumed that we need to udate the customer item record
      -- otherwise we need to create a new customer item record.
      CURSOR lcu_get_cust_item_id(cp_customer_id IN NUMBER, cp_customer_item_number IN VARCHAR2, cp_item_definition_level IN NUMBER, cp_customer_category_code IN VARCHAR2, cp_address_id IN NUMBER) IS
         SELECT customer_item_id, ROWID row_id
           FROM mtl_customer_items mci
          WHERE mci.customer_id = cp_customer_id AND
                mci.customer_item_number = cp_customer_item_number AND
                mci.item_definition_level = cp_item_definition_level AND
                nvl(mci.customer_category_code, ' ') =
                nvl(cp_customer_category_code, ' ') AND
                nvl(mci.address_id, -1) = nvl(cp_address_id, -1);
      n_new_customer_item_id NUMBER;
      v_rowid                VARCHAR2(25);
   
      n_mast_org_id       NUMBER;
      n_process_mode      NUMBER;
      v_customer_name     mtl_customer_items_all_v.customer_name%TYPE;
      v_customer_number   mtl_customer_items_all_v.customer_number%TYPE;
      n_customer_id       mtl_customer_items_all_v.customer_id%TYPE;
      v_customer_item     mtl_customer_items_all_v.customer_item_number%TYPE;
      n_commodity_code_id mtl_customer_items_all_v.commodity_code_id%TYPE := 1; -- this is hardcoded
   
      n_item_definition_level mtl_customer_items_all_v.item_definition_level%TYPE;
      v_inactive_flag         mtl_customer_items_all_v.inactive_flag%TYPE;
      v_inactive_flag_xref    VARCHAR2(1);
      n_inventory_item_id     mtl_system_items.inventory_item_id%TYPE;
   
      d_creation_date      DATE;
      n_created_by         NUMBER;
      d_last_update_date   DATE;
      n_last_update_by     NUMBER;
      v_customer_item_desc VARCHAR2(240);
   
      n_inactive_flag_to_api NUMBER;
      v_inactive_flag_to_tbl VARCHAR2(1);
   
      v_null VARCHAR2(1);
      n_null NUMBER;
      d_null DATE;
   
      l_exception EXCEPTION;
      n_user_id NUMBER;
   
      n_preference_number mtl_customer_item_xrefs.preference_number%TYPE := 1;
   BEGIN
   
      write_to_log('PROCESS_CUSTOMER_ITEM', 'Inside this procedure');
      --autonomous_proc.dump_temp('Inside this procedure');
      -- set the apps context
   
      -- get the master organization id
      n_mast_org_id := get_master_organization_id(p_organization_id);
   
      write_to_log('PROCESS_CUSTOMER_ITEM',
                   'Master Organization ID: ' || n_mast_org_id ||
                   ', Input Organization ID:' || nvl(p_organization_id, -1));
      --autonomous_proc.dump_temp('Master Organization ID: '||n_mast_org_id||', Input Organization ID:'||nvl(p_organization_id,-1));
   
      write_to_log('PROCESS_CUSTOMER_ITEM',
                   'Customer Name: ' || nvl(p_customer_name, 'NULL'));
      --autonomous_proc.dump_temp('Customer Name: '|| nvl(p_customer_name,'NULL'));
   
      -- if the customer is not existing then raise error
      IF (p_customer_name IS NOT NULL) THEN
         -- get the customer information based on the input customer name
         OPEN lcu_check_cust(p_customer_name, 'A');
         FETCH lcu_check_cust
            INTO lr_check_cust;
         CLOSE lcu_check_cust;
      
         write_to_log('PROCESS_CUSTOMER_ITEM',
                      'Customer ID: ' || nvl(lr_check_cust.customer_id, -1) ||
                      ', Customer ID: ' ||
                      nvl(lr_check_cust.customer_number, 'NULL'));
         --autonomous_proc.dump_temp('Customer ID: '|| nvl(lr_check_cust.customer_id,-1)||', Customer Number: '|| nvl(lr_check_cust.customer_number,'NULL'));
      
         -- error out when the customer id could not be determined
         IF (lr_check_cust.customer_id IS NULL OR
            lr_check_cust.customer_number IS NULL) THEN
            fnd_message.set_name('ACCST', 'AC_CST_A2O_CUST_INVALID');
            fnd_message.set_token('CUST_NAME', p_customer_name);
            x_msg_data  := fnd_message.get;
            x_msg_count := 1;
            RAISE l_exception;
         END IF;
      
      ELSE
         fnd_message.set_name('ACCST', 'AC_CST_A2O_CUST_MANDATORY');
         x_msg_data  := fnd_message.get;
         x_msg_count := 1;
         RAISE l_exception;
      END IF;
   
      write_to_log('PROCESS_CUSTOMER_ITEM',
                   'Inventory Organization ID: ' ||
                   nvl(p_inventory_item_id, -1));
      --autonomous_proc.dump_temp('Inventory Organization ID: '|| nvl(p_inventory_item_id,-1));
   
      v_rowid := NULL;
      -- check if the unique combination is already existing
      -- if the record is not existing then Insert
      OPEN lcu_get_cust_item_id(lr_check_cust.customer_id,
                                p_customer_item,
                                p_item_definition_level,
                                v_null,
                                n_null);
      FETCH lcu_get_cust_item_id
         INTO n_customer_item_id, v_rowid;
      CLOSE lcu_get_cust_item_id;
   
      write_to_log('PROCESS_CUSTOMER_ITEM',
                   'Existing RowID: ' || nvl(v_rowid, 'NULL') ||
                   ', Customer Item ID:' || n_customer_item_id);
      --autonomous_proc.dump_temp('Existing RowID: '|| nvl(v_rowid,'NULL')||', Customer Item ID:'||n_customer_item_id);
   
      -- check if this procedure is invoked for new item creation or modification
      -- change the user accordingly
      IF (fnd_global.user_id = -1) THEN
         n_user_id := nvl(p_created_by, 0);
         fnd_global.apps_initialize(n_user_id, 0, 0);
      ELSE
         n_user_id := nvl(p_last_update_by, 0);
      END IF;
   
      -- set the apps context after determining the user
   
      -- inactive flag is being passed as number 1 - Y , 2 - N
      IF (p_inactive_flag = 'Y') THEN
         n_inactive_flag_to_api := 1;
         v_inactive_flag_to_tbl := 'Y';
      ELSE
         n_inactive_flag_to_api := 2;
         v_inactive_flag_to_tbl := 'N';
      END IF;
   
      -- check if the inventory item id is already assigned to different customer item which is active
      OPEN lcu_exists_xrefs(p_inventory_item_id, p_customer_item);
      FETCH lcu_exists_xrefs
         INTO lr_exists_xrefs;
      IF lcu_exists_xrefs%FOUND THEN
         --amirt 21/02/08
         OPEN lcu_get_xrefs_rec(lr_exists_xrefs.customer_item_id,
                                p_inventory_item_id);
         FETCH lcu_get_xrefs_rec
            INTO lr_get_x_refs_rec;
         CLOSE lcu_get_xrefs_rec;
      
         invicxrf.update_row(x_rowid                  => lr_get_x_refs_rec.row_id,
                             x_customer_item_id       => lr_get_x_refs_rec.customer_item_id,
                             x_inventory_item_id      => lr_get_x_refs_rec.inventory_item_id,
                             x_master_organization_id => lr_get_x_refs_rec.master_organization_id,
                             x_rank                   => lr_get_x_refs_rec.rank,
                             x_inactive_flag          => 'Y',
                             x_last_update_date       => p_last_update_date,
                             x_last_updated_by        => p_last_update_by,
                             x_creation_date          => lr_get_x_refs_rec.creation_date,
                             x_created_by             => lr_get_x_refs_rec.created_by,
                             x_last_update_login      => lr_get_x_refs_rec.last_update_login,
                             x_attribute_category     => lr_get_x_refs_rec.attribute_category,
                             x_attribute1             => lr_get_x_refs_rec.attribute1,
                             x_attribute2             => lr_get_x_refs_rec.attribute2,
                             x_attribute3             => lr_get_x_refs_rec.attribute3,
                             x_attribute4             => lr_get_x_refs_rec.attribute4,
                             x_attribute5             => lr_get_x_refs_rec.attribute5,
                             x_attribute6             => lr_get_x_refs_rec.attribute6,
                             x_attribute7             => lr_get_x_refs_rec.attribute7,
                             x_attribute8             => lr_get_x_refs_rec.attribute8,
                             x_attribute9             => lr_get_x_refs_rec.attribute9,
                             x_attribute10            => lr_get_x_refs_rec.attribute10,
                             x_attribute11            => lr_get_x_refs_rec.attribute11,
                             x_attribute12            => lr_get_x_refs_rec.attribute12,
                             x_attribute13            => lr_get_x_refs_rec.attribute13,
                             x_attribute14            => lr_get_x_refs_rec.attribute14,
                             x_attribute15            => lr_get_x_refs_rec.attribute15);
         /* fnd_message.set_name('ACCST','AC_CST_A2O_INV_CUST_EXISTS');
         fnd_message.set_token('CUST_ITEM_NUMBER',lr_exists_xrefs.customer_item_number);
         fnd_message.set_token('CUST_NAME',lr_exists_xrefs.customer_name);
         fnd_message.set_token('CUST_NUMBER',lr_exists_xrefs.customer_number);
         x_msg_data := fnd_message.get;
         x_msg_count := 1;
         close lcu_exists_xrefs;
         RAISE l_exception;*/
      END IF;
      CLOSE lcu_exists_xrefs;
   
      write_to_log('PROCESS_CUSTOMER_ITEM',
                   ' User ID: ' || nvl(n_user_id, -1));
      --autonomous_proc.dump_temp(' User ID: '|| nvl(n_user_id, -1));
   
      -- check if the record already exists then Update
      -- when the customer id is not -1 then it is presumed that the record is already existing
      IF (n_customer_item_id <> -1) THEN
         write_to_log('PROCESS_CUSTOMER_ITEM',
                      'Before Update, Customer Item ID: ' ||
                      nvl(n_customer_item_id, -1));
         --autonomous_proc.dump_temp('Before Update, Customer Item ID: '||nvl(n_customer_item_id,-1));
      
         OPEN lcu_get_xrefs_rec(n_customer_item_id, p_inventory_item_id);
         FETCH lcu_get_xrefs_rec
            INTO lr_get_x_refs_rec;
         CLOSE lcu_get_xrefs_rec;
      
         --autonomous_proc.dump_temp('Inactive Flag: '||v_inactive_flag_to_tbl);
      
         IF (lr_get_x_refs_rec.row_id IS NOT NULL) THEN
         
            -- check if the inactive flag is
            IF (v_inactive_flag_to_tbl = 'N') THEN
            
               -- check if the inventory item id is already assigned to different customer id which is active
               OPEN lcu_exists_cust_xrefs(p_inventory_item_id,
                                          p_customer_item,
                                          lr_check_cust.customer_id,
                                          lr_check_cust.customer_number);
               FETCH lcu_exists_cust_xrefs
                  INTO lr_exists_cust_xrefs;
               IF lcu_exists_cust_xrefs%FOUND THEN
                  fnd_message.set_name('ACCST',
                                       'AC_CST_A2O_INV_CUST_EXISTS');
                  fnd_message.set_token('CUST_ITEM_NUMBER',
                                        lr_exists_cust_xrefs.customer_item_number);
                  fnd_message.set_token('CUST_NAME',
                                        lr_exists_cust_xrefs.customer_name);
                  fnd_message.set_token('CUST_NUMBER',
                                        lr_exists_cust_xrefs.customer_number);
                  x_msg_data  := fnd_message.get;
                  x_msg_count := 1;
                  CLOSE lcu_exists_cust_xrefs;
                  RAISE l_exception;
               END IF;
               CLOSE lcu_exists_cust_xrefs;
            END IF;
         
            -- since only the modified columns are provided as inputs then using nvl
            -- both preference_number and inactive_flag are mandatory fields
            invicxrf.update_row(x_rowid                  => lr_get_x_refs_rec.row_id,
                                x_customer_item_id       => lr_get_x_refs_rec.customer_item_id,
                                x_inventory_item_id      => lr_get_x_refs_rec.inventory_item_id,
                                x_master_organization_id => lr_get_x_refs_rec.master_organization_id,
                                x_rank                   => nvl(p_preference_number,
                                                                lr_get_x_refs_rec.rank),
                                x_inactive_flag          => nvl(v_inactive_flag_to_tbl,
                                                                lr_get_x_refs_rec.inactive_flag),
                                x_last_update_date       => p_last_update_date,
                                x_last_updated_by        => p_last_update_by,
                                x_creation_date          => p_creation_date,
                                x_created_by             => p_created_by,
                                x_last_update_login      => lr_get_x_refs_rec.last_update_login,
                                x_attribute_category     => lr_get_x_refs_rec.attribute_category,
                                x_attribute1             => lr_get_x_refs_rec.attribute1,
                                x_attribute2             => lr_get_x_refs_rec.attribute2,
                                x_attribute3             => lr_get_x_refs_rec.attribute3,
                                x_attribute4             => lr_get_x_refs_rec.attribute4,
                                x_attribute5             => lr_get_x_refs_rec.attribute5,
                                x_attribute6             => lr_get_x_refs_rec.attribute6,
                                x_attribute7             => lr_get_x_refs_rec.attribute7,
                                x_attribute8             => lr_get_x_refs_rec.attribute8,
                                x_attribute9             => lr_get_x_refs_rec.attribute9,
                                x_attribute10            => lr_get_x_refs_rec.attribute10,
                                x_attribute11            => lr_get_x_refs_rec.attribute11,
                                x_attribute12            => lr_get_x_refs_rec.attribute12,
                                x_attribute13            => lr_get_x_refs_rec.attribute13,
                                x_attribute14            => lr_get_x_refs_rec.attribute14,
                                x_attribute15            => lr_get_x_refs_rec.attribute15);
         
            write_to_log('PROCESS_CUSTOMER_ITEM', 'After Update');
            --autonomous_proc.dump_temp('After Update');
         
         ELSE
            -- current cross reference needs to be created
            v_rowid                 := NULL;
            n_process_mode          := 1;
            v_customer_name         := p_customer_name;
            v_customer_number       := lr_check_cust.customer_number;
            n_customer_id           := lr_check_cust.customer_id;
            v_customer_item         := p_customer_item;
            n_item_definition_level := p_item_definition_level;
            n_mast_org_id           := p_organization_id;
            n_inventory_item_id     := p_inventory_item_id;
            v_inactive_flag         := n_inactive_flag_to_api;
            d_creation_date         := p_creation_date;
            n_created_by            := p_created_by;
            d_last_update_date      := p_last_update_date;
            n_last_update_by        := p_last_update_by;
         
            -- get the preference number
            OPEN lcu_get_rank(p_customer_item);
            FETCH lcu_get_rank
               INTO n_preference_number;
            IF (lcu_get_rank%FOUND) THEN
               n_preference_number := nvl(n_preference_number, 0) + 1;
            ELSE
               n_preference_number := 1;
            END IF;
         
            -- check if the inventory item id is already assigned to different customer id which is active
            OPEN lcu_exists_cust_xrefs(p_inventory_item_id,
                                       p_customer_item,
                                       n_customer_id,
                                       v_customer_number);
            FETCH lcu_exists_cust_xrefs
               INTO lr_exists_cust_xrefs;
            IF lcu_exists_cust_xrefs%FOUND THEN
               fnd_message.set_name('ACCST', 'AC_CST_A2O_INV_CUST_EXISTS');
               fnd_message.set_token('CUST_ITEM_NUMBER',
                                     lr_exists_cust_xrefs.customer_item_number);
               fnd_message.set_token('CUST_NAME',
                                     lr_exists_cust_xrefs.customer_name);
               fnd_message.set_token('CUST_NUMBER',
                                     lr_exists_cust_xrefs.customer_number);
               x_msg_data  := fnd_message.get;
               x_msg_count := 1;
               CLOSE lcu_exists_cust_xrefs;
               RAISE l_exception;
            END IF;
            CLOSE lcu_exists_cust_xrefs;
         
            invciint.validate_ci_xrefs(row_id                     => v_rowid,
                                       process_mode               => n_process_mode,
                                       customer_name              => v_customer_name,
                                       customer_number            => v_customer_number,
                                       customer_id                => n_customer_id,
                                       customer_category_code     => v_null,
                                       customer_category          => v_null,
                                       address1                   => v_null,
                                       address2                   => v_null,
                                       address3                   => v_null,
                                       address4                   => v_null,
                                       city                       => v_null,
                                       state                      => v_null,
                                       county                     => v_null,
                                       country                    => v_null,
                                       postal_code                => v_null,
                                       address_id                 => v_null,
                                       customer_item_number       => v_customer_item,
                                       item_definition_level_desc => v_null,
                                       item_definition_level      => n_item_definition_level,
                                       customer_item_id           => n_new_customer_item_id,
                                       master_organization_name   => v_null,
                                       master_organization_code   => v_null,
                                       master_organization_id     => n_mast_org_id,
                                       inventory_item_segment1    => v_null,
                                       inventory_item_segment2    => v_null,
                                       inventory_item_segment3    => v_null,
                                       inventory_item_segment4    => v_null,
                                       inventory_item_segment5    => v_null,
                                       inventory_item_segment6    => v_null,
                                       inventory_item_segment7    => v_null,
                                       inventory_item_segment8    => v_null,
                                       inventory_item_segment9    => v_null,
                                       inventory_item_segment10   => v_null,
                                       inventory_item_segment11   => v_null,
                                       inventory_item_segment12   => v_null,
                                       inventory_item_segment13   => v_null,
                                       inventory_item_segment14   => v_null,
                                       inventory_item_segment15   => v_null,
                                       inventory_item_segment16   => v_null,
                                       inventory_item_segment17   => v_null,
                                       inventory_item_segment18   => v_null,
                                       inventory_item_segment19   => v_null,
                                       inventory_item_segment20   => v_null,
                                       inventory_item             => v_null,
                                       inventory_item_id          => n_inventory_item_id,
                                       preference_number          => n_preference_number,
                                       inactive_flag              => v_inactive_flag,
                                       attribute_category         => v_null,
                                       attribute1                 => v_null,
                                       attribute2                 => v_null,
                                       attribute3                 => v_null,
                                       attribute4                 => v_null,
                                       attribute5                 => v_null,
                                       attribute6                 => v_null,
                                       attribute7                 => v_null,
                                       attribute8                 => v_null,
                                       attribute9                 => v_null,
                                       attribute10                => v_null,
                                       attribute11                => v_null,
                                       attribute12                => v_null,
                                       attribute13                => v_null,
                                       attribute14                => v_null,
                                       attribute15                => v_null,
                                       last_update_date           => d_last_update_date,
                                       last_updated_by            => n_last_update_by,
                                       creation_date              => d_creation_date,
                                       created_by                 => n_created_by,
                                       last_update_login          => n_null,
                                       request_id                 => -1,
                                       program_application_id     => -1,
                                       program_id                 => -1,
                                       program_update_date        => SYSDATE,
                                       delete_record              => 'NO DELETE');
         
         END IF;
      
         IF (nvl(p_customer_item_desc, 'ZZZZ') <> 'ZZZZ') THEN
         
            UPDATE mtl_customer_items
               SET customer_item_desc = decode(p_customer_item_desc,
                                               '!',
                                               NULL,
                                               p_customer_item_desc)
             WHERE ROWID = v_rowid;
         END IF;
      ELSE
      
         write_to_log('PROCESS_CUSTOMER_ITEM',
                      'Before Create Customer Item');
         --autonomous_proc.dump_temp('Before Create Customer Item');
      
         -- this procedure will create a new record in the MTL_CUSTOMER_ITEMS table
         v_rowid                 := NULL;
         n_process_mode          := 1; -- is 1 for 'I'
         v_customer_name         := p_customer_name;
         v_customer_number       := lr_check_cust.customer_number;
         v_customer_item_desc    := p_customer_item_desc;
         n_customer_id           := lr_check_cust.customer_id;
         v_customer_item         := p_customer_item;
         n_item_definition_level := p_item_definition_level;
         n_mast_org_id           := p_organization_id;
         v_inactive_flag         := n_inactive_flag_to_api;
         d_creation_date         := p_creation_date;
         n_created_by            := p_created_by;
         d_last_update_date      := p_last_update_date;
         n_last_update_by        := p_last_update_by;
      
         invciint.validate_customer_item(row_id                     => v_rowid,
                                         process_mode               => n_process_mode,
                                         customer_name              => v_customer_name,
                                         customer_number            => v_customer_number,
                                         customer_id                => n_customer_id,
                                         customer_category_code     => v_null,
                                         customer_category          => v_null,
                                         address1                   => v_null,
                                         address2                   => v_null,
                                         address3                   => v_null,
                                         address4                   => v_null,
                                         city                       => v_null,
                                         state                      => v_null,
                                         county                     => v_null,
                                         country                    => v_null,
                                         postal_code                => v_null,
                                         address_id                 => v_null,
                                         customer_item_number       => v_customer_item,
                                         item_definition_level_desc => v_null,
                                         item_definition_level      => n_item_definition_level,
                                         customer_item_desc         => v_customer_item_desc,
                                         model_customer_item_number => v_null,
                                         model_customer_item_id     => n_null,
                                         commodity_code             => v_null,
                                         commodity_code_id          => n_commodity_code_id, -- this is hardcoded as 1
                                         master_container_segment1  => v_null,
                                         master_container_segment2  => v_null,
                                         master_container_segment3  => v_null,
                                         master_container_segment4  => v_null,
                                         master_container_segment5  => v_null,
                                         master_container_segment6  => v_null,
                                         master_container_segment7  => v_null,
                                         master_container_segment8  => v_null,
                                         master_container_segment9  => v_null,
                                         master_container_segment10 => v_null,
                                         master_container_segment11 => v_null,
                                         master_container_segment12 => v_null,
                                         master_container_segment13 => v_null,
                                         master_container_segment14 => v_null,
                                         master_container_segment15 => v_null,
                                         master_container_segment16 => v_null,
                                         master_container_segment17 => v_null,
                                         master_container_segment18 => v_null,
                                         master_container_segment19 => v_null,
                                         master_container_segment20 => v_null,
                                         master_container           => v_null,
                                         master_container_item_id   => n_null,
                                         container_item_org_name    => v_null,
                                         container_item_org_code    => v_null,
                                         container_item_org_id      => n_mast_org_id,
                                         detail_container_segment1  => v_null,
                                         detail_container_segment2  => v_null,
                                         detail_container_segment3  => v_null,
                                         detail_container_segment4  => v_null,
                                         detail_container_segment5  => v_null,
                                         detail_container_segment6  => v_null,
                                         detail_container_segment7  => v_null,
                                         detail_container_segment8  => v_null,
                                         detail_container_segment9  => v_null,
                                         detail_container_segment10 => v_null,
                                         detail_container_segment11 => v_null,
                                         detail_container_segment12 => v_null,
                                         detail_container_segment13 => v_null,
                                         detail_container_segment14 => v_null,
                                         detail_container_segment15 => v_null,
                                         detail_container_segment16 => v_null,
                                         detail_container_segment17 => v_null,
                                         detail_container_segment18 => v_null,
                                         detail_container_segment19 => v_null,
                                         detail_container_segment20 => v_null,
                                         detail_container           => v_null,
                                         detail_container_item_id   => n_null,
                                         min_fill_percentage        => n_null,
                                         dep_plan_required_flag     => v_null,
                                         dep_plan_prior_bld_flag    => v_null,
                                         inactive_flag              => v_inactive_flag,
                                         attribute_category         => v_null,
                                         attribute1                 => v_null,
                                         attribute2                 => v_null,
                                         attribute3                 => v_null,
                                         attribute4                 => v_null,
                                         attribute5                 => v_null,
                                         attribute6                 => v_null,
                                         attribute7                 => v_null,
                                         attribute8                 => v_null,
                                         attribute9                 => v_null,
                                         attribute10                => v_null,
                                         attribute11                => v_null,
                                         attribute12                => v_null,
                                         attribute13                => v_null,
                                         attribute14                => v_null,
                                         attribute15                => v_null,
                                         demand_tolerance_positive  => n_null,
                                         demand_tolerance_negative  => n_null,
                                         last_update_date           => d_last_update_date,
                                         last_updated_by            => n_last_update_by,
                                         creation_date              => d_creation_date,
                                         created_by                 => n_created_by,
                                         last_update_login          => n_null,
                                         request_id                 => -1,
                                         program_application_id     => -1,
                                         program_id                 => -1,
                                         program_update_date        => SYSDATE,
                                         delete_record              => 'NO DELETE');
      
         write_to_log('PROCESS_CUSTOMER_ITEM',
                      'Customer Item Record Created: ' || v_rowid);
         --autonomous_proc.dump_temp('Customer Item Record Created');
      
         v_rowid                 := NULL;
         n_process_mode          := 1;
         v_customer_name         := p_customer_name;
         v_customer_number       := lr_check_cust.customer_number;
         n_customer_id           := lr_check_cust.customer_id;
         v_customer_item         := p_customer_item;
         n_item_definition_level := p_item_definition_level;
         n_mast_org_id           := p_organization_id;
         n_inventory_item_id     := p_inventory_item_id;
         v_inactive_flag         := n_inactive_flag_to_api;
         d_creation_date         := p_creation_date;
         n_created_by            := p_created_by;
         d_last_update_date      := p_last_update_date;
         n_last_update_by        := p_last_update_by;
      
         -- get the preference number
         OPEN lcu_get_rank(p_customer_item);
         FETCH lcu_get_rank
            INTO n_preference_number;
         IF (lcu_get_rank%FOUND) THEN
            n_preference_number := nvl(n_preference_number, 0) + 1;
         ELSE
            n_preference_number := 1;
         END IF;
         -- get the customer item which is created by the above procedure
         OPEN lcu_get_cust_item_id(n_customer_id,
                                   v_customer_item,
                                   n_item_definition_level,
                                   v_null,
                                   n_null);
         FETCH lcu_get_cust_item_id
            INTO n_new_customer_item_id, v_rowid;
         CLOSE lcu_get_cust_item_id;
         v_rowid := NULL; -- reusing the same variable already existing, nullify this rowid since it is different row
      
         write_to_log('PROCESS_CUSTOMER_ITEM',
                      'Customer Item Record , New Customer Item ID:' ||
                      nvl(n_new_customer_item_id, -1));
         --autonomous_proc.dump_temp('Customer Item Record , New Customer Item ID:'||nvl(n_new_customer_item_id,-1));
      
         IF (n_new_customer_item_id IS NOT NULL) THEN
         
            --autonomous_proc.dump_temp('p_inventory_item_id: '||p_inventory_item_id||' , p_customer_item: '||p_customer_item||' , n_customer_id: '||n_customer_id||', v_customer_number:'||v_customer_number  );
            -- check if the inventory item id is already assigned to different customer id which is active
            OPEN lcu_exists_cust_xrefs(p_inventory_item_id,
                                       p_customer_item,
                                       n_customer_id,
                                       v_customer_number);
            FETCH lcu_exists_cust_xrefs
               INTO lr_exists_cust_xrefs;
            IF lcu_exists_cust_xrefs%FOUND THEN
               fnd_message.set_name('ACCST', 'AC_CST_A2O_INV_CUST_EXISTS');
               fnd_message.set_token('CUST_ITEM_NUMBER',
                                     lr_exists_cust_xrefs.customer_item_number);
               fnd_message.set_token('CUST_NAME',
                                     lr_exists_cust_xrefs.customer_name);
               fnd_message.set_token('CUST_NUMBER',
                                     lr_exists_cust_xrefs.customer_number);
               x_msg_data  := fnd_message.get;
               x_msg_count := 1;
               CLOSE lcu_exists_cust_xrefs;
               RAISE l_exception;
            END IF;
            CLOSE lcu_exists_cust_xrefs;
         
            invciint.validate_ci_xrefs(row_id                     => v_rowid,
                                       process_mode               => n_process_mode,
                                       customer_name              => v_customer_name,
                                       customer_number            => v_customer_number,
                                       customer_id                => n_customer_id,
                                       customer_category_code     => v_null,
                                       customer_category          => v_null,
                                       address1                   => v_null,
                                       address2                   => v_null,
                                       address3                   => v_null,
                                       address4                   => v_null,
                                       city                       => v_null,
                                       state                      => v_null,
                                       county                     => v_null,
                                       country                    => v_null,
                                       postal_code                => v_null,
                                       address_id                 => v_null,
                                       customer_item_number       => v_customer_item,
                                       item_definition_level_desc => v_null,
                                       item_definition_level      => n_item_definition_level,
                                       customer_item_id           => n_new_customer_item_id,
                                       master_organization_name   => v_null,
                                       master_organization_code   => v_null,
                                       master_organization_id     => n_mast_org_id,
                                       inventory_item_segment1    => v_null,
                                       inventory_item_segment2    => v_null,
                                       inventory_item_segment3    => v_null,
                                       inventory_item_segment4    => v_null,
                                       inventory_item_segment5    => v_null,
                                       inventory_item_segment6    => v_null,
                                       inventory_item_segment7    => v_null,
                                       inventory_item_segment8    => v_null,
                                       inventory_item_segment9    => v_null,
                                       inventory_item_segment10   => v_null,
                                       inventory_item_segment11   => v_null,
                                       inventory_item_segment12   => v_null,
                                       inventory_item_segment13   => v_null,
                                       inventory_item_segment14   => v_null,
                                       inventory_item_segment15   => v_null,
                                       inventory_item_segment16   => v_null,
                                       inventory_item_segment17   => v_null,
                                       inventory_item_segment18   => v_null,
                                       inventory_item_segment19   => v_null,
                                       inventory_item_segment20   => v_null,
                                       inventory_item             => v_null,
                                       inventory_item_id          => n_inventory_item_id,
                                       preference_number          => n_preference_number,
                                       inactive_flag              => v_inactive_flag,
                                       attribute_category         => v_null,
                                       attribute1                 => v_null,
                                       attribute2                 => v_null,
                                       attribute3                 => v_null,
                                       attribute4                 => v_null,
                                       attribute5                 => v_null,
                                       attribute6                 => v_null,
                                       attribute7                 => v_null,
                                       attribute8                 => v_null,
                                       attribute9                 => v_null,
                                       attribute10                => v_null,
                                       attribute11                => v_null,
                                       attribute12                => v_null,
                                       attribute13                => v_null,
                                       attribute14                => v_null,
                                       attribute15                => v_null,
                                       last_update_date           => d_last_update_date,
                                       last_updated_by            => n_last_update_by,
                                       creation_date              => d_creation_date,
                                       created_by                 => n_created_by,
                                       last_update_login          => n_null,
                                       request_id                 => -1,
                                       program_application_id     => -1,
                                       program_id                 => -1,
                                       program_update_date        => SYSDATE,
                                       delete_record              => 'NO DELETE');
            write_to_log('PROCESS_CUSTOMER_ITEM',
                         'After Customer Item XREFS record creation: ');
            --autonomous_proc.dump_temp('After Customer Item XREFS record creation: ');
         ELSE
            fnd_message.set_name('ACCST', 'AC_CST_A2O_NO_CUST_ITEM_REC');
            x_msg_data := fnd_message.get;
            RAISE l_exception;
         END IF;
      END IF;
      x_error_code    := v_null;
      x_return_status := ego_item_pub.g_ret_sts_success;
      x_msg_count     := 0;
      x_msg_data      := v_null;
   
      --autonomous_proc.dump_temp('Returning from the procedure PROCESS_CUSTOMER_ITEM');
      write_to_log('PROCESS_CUSTOMER_ITEM',
                   'Returning from the procedure PROCESS_CUSTOMER_ITEM');
   EXCEPTION
      WHEN l_exception THEN
         x_error_code    := '';
         x_return_status := ego_item_pub.g_ret_sts_error;
         ego_item_msg.add_error_text(ego_item_pvt.g_item_indx, x_msg_data);
         write_to_log('PROCESS_CUSTOMER_ITEM',
                      'From l_exception Exception: ' || x_msg_data);
         --autonomous_proc.dump_temp('From l_exception Exception: '||x_msg_data);
   
      WHEN OTHERS THEN
         fnd_message.set_name('INV', 'INV_ITEM_UNEXPECTED_ERROR');
         fnd_message.set_token('PACKAGE_NAME',
                               'XXAGILE_PROCESS_CUST_ITEM_PKG');
         fnd_message.set_token('PROCEDURE_NAME', 'PROCESS_CUSTOMER_ITEM');
         fnd_message.set_token('ERROR_TEXT', SQLERRM);
         x_error_code    := SQLCODE;
         x_return_status := ego_item_pub.g_ret_sts_unexp_error;
         x_msg_count     := 1;
         x_msg_data      := fnd_message.get;
         ego_item_msg.add_error_text(ego_item_pvt.g_item_indx, x_msg_data);
         write_to_log('PROCESS_CUSTOMER_ITEM',
                      'From Others Exception: ' || x_msg_data);
         --autonomous_proc.dump_temp('From Others Exception: '||x_msg_data);
   
   END process_customer_item;

END xxagile_process_cust_item_pkg;
/

