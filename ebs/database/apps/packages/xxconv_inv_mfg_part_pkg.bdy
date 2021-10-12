CREATE OR REPLACE PACKAGE BODY xxconv_inv_mfg_part_pkg IS

   g_master_organization NUMBER := 91;

   PROCEDURE insert_manuf_data(errbuf OUT VARCHAR2, retcode OUT NUMBER) IS
   
      CURSOR csr_manufacturers IS
         SELECT DISTINCT xcm.manufacturer, xcm.manuf_description
           FROM xxobjt_conv_mfg xcm
          WHERE status = 'N';
   
      CURSOR csr_mfg_parts(p_manufacturer VARCHAR2) IS
         SELECT *
           FROM xxobjt_conv_mfg xcm
          WHERE xcm.manufacturer = p_manufacturer AND
                status = 'N';
   
      cur_manufacturer csr_manufacturers%ROWTYPE;
      cur_mfg_part     csr_mfg_parts%ROWTYPE;
   
      v_manuf_id          NUMBER;
      v_user_id           NUMBER;
      v_inventory_item_id NUMBER;
      v_rowid             ROWID;
   
      invalid_data EXCEPTION;
      l_error_msg VARCHAR2(500);
   
   BEGIN
   
      BEGIN
      
         SELECT user_id
           INTO v_user_id
           FROM fnd_user
          WHERE user_name = 'CONVERSION';
      
      EXCEPTION
         WHEN OTHERS THEN
         
            retcode := 2;
            errbuf  := 'Invalid conversion user';
      END;
   
      -- llop over manufacturers
      FOR cur_manufacturer IN csr_manufacturers LOOP
      
         BEGIN
         
            v_manuf_id := NULL;
         
            -- Check and create manufacturer
            BEGIN
            
               SELECT mtlm.manufacturer_id
                 INTO v_manuf_id
                 FROM mtl_manufacturers mtlm
                WHERE mtlm.description = cur_manufacturer.manufacturer;
            
            EXCEPTION
               WHEN no_data_found THEN
               
                  SELECT mtl_manufacturers_s.NEXTVAL
                    INTO v_manuf_id
                    FROM dual;
               
                  INSERT INTO mtl_manufacturers
                     (manufacturer_id,
                      manufacturer_name,
                      last_update_date,
                      last_updated_by,
                      creation_date,
                      created_by,
                      last_update_login,
                      description)
                  VALUES
                     (v_manuf_id,
                      substr(cur_manufacturer.manufacturer, 1, 30),
                      SYSDATE,
                      v_user_id, -- conversion USER id,
                      SYSDATE,
                      v_user_id, -- conversion USER id,
                      NULL,
                      cur_manufacturer.manufacturer);
               
            END;
            COMMIT;
            FOR cur_mfg_part IN csr_mfg_parts(cur_manufacturer.manufacturer) LOOP
            
               BEGIN
               
                  --check Item
                  BEGIN
                  
                     SELECT inventory_item_id
                       INTO v_inventory_item_id
                       FROM mtl_system_items_b
                      WHERE segment1 = cur_mfg_part.item AND
                            organization_id = g_master_organization;
                  
                  EXCEPTION
                     WHEN no_data_found THEN
                        l_error_msg := 'Invalid item';
                        RAISE invalid_data;
                  END;
               
                  mtl_mfg_part_numbers_pkg.insert_row(x_rowid              => v_rowid,
                                                      x_manufacturer_id    => v_manuf_id,
                                                      x_mfg_part_num       => cur_mfg_part.mfg_part_number,
                                                      x_inventory_item_id  => v_inventory_item_id,
                                                      x_last_update_date   => SYSDATE,
                                                      x_last_updated_by    => v_user_id,
                                                      x_creation_date      => SYSDATE,
                                                      x_created_by         => v_user_id,
                                                      x_last_update_login  => -1,
                                                      x_organization_id    => g_master_organization,
                                                      x_description        => cur_mfg_part.mfg_description,
                                                      x_attribute_category => NULL,
                                                      x_attribute1         => NULL,
                                                      x_attribute2         => NULL,
                                                      x_attribute3         => NULL,
                                                      x_attribute4         => NULL,
                                                      x_attribute5         => NULL,
                                                      x_attribute6         => NULL,
                                                      x_attribute7         => NULL,
                                                      x_attribute8         => NULL,
                                                      x_attribute9         => NULL,
                                                      x_attribute10        => NULL,
                                                      x_attribute11        => NULL,
                                                      x_attribute12        => NULL,
                                                      x_attribute13        => NULL,
                                                      x_attribute14        => NULL,
                                                      x_attribute15        => NULL);
               
                  UPDATE xxobjt_conv_mfg xcm
                     SET xcm.status = 'S', xcm.error_msg = NULL
                   WHERE xcm.manufacturer = cur_manufacturer.manufacturer AND
                         xcm.item = cur_mfg_part.item AND
                         xcm.mfg_part_number = cur_mfg_part.mfg_part_number;
               
               EXCEPTION
                  WHEN invalid_data THEN
                  
                     ROLLBACK;
                     UPDATE xxobjt_conv_mfg xcm
                        SET xcm.status    = 'E',
                            xcm.error_msg = 'MPN Error: ' || l_error_msg
                      WHERE xcm.manufacturer =
                            cur_manufacturer.manufacturer AND
                            xcm.item = cur_mfg_part.item AND
                            xcm.mfg_part_number =
                            cur_mfg_part.mfg_part_number;
                  
                  WHEN OTHERS THEN
                  
                     l_error_msg := SQLERRM;
                     ROLLBACK;
                     UPDATE xxobjt_conv_mfg xcm
                        SET xcm.status    = 'E',
                            xcm.error_msg = 'MPN Error: ' || l_error_msg
                      WHERE xcm.manufacturer =
                            cur_manufacturer.manufacturer AND
                            xcm.item = cur_mfg_part.item AND
                            xcm.mfg_part_number =
                            cur_mfg_part.mfg_part_number;
                  
               END;
            
               COMMIT;
            
            END LOOP;
         
         EXCEPTION
            WHEN invalid_data THEN
            
               UPDATE xxobjt_conv_mfg xcm
                  SET xcm.status    = 'E',
                      xcm.error_msg = 'Manufacturer Error: ' || l_error_msg
                WHERE xcm.manufacturer = cur_manufacturer.manufacturer;
            
            WHEN OTHERS THEN
            
               l_error_msg := SQLERRM;
               UPDATE xxobjt_conv_mfg xcm
                  SET xcm.status    = 'E',
                      xcm.error_msg = 'Manufacturer Error: ' || l_error_msg
                WHERE xcm.manufacturer = cur_manufacturer.manufacturer;
            
         END;
      
         COMMIT;
      
      END LOOP;
   
   END insert_manuf_data;

------------------------------------------------------------------------------------------------------

END xxconv_inv_mfg_part_pkg;
/

