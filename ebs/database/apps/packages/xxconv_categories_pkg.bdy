CREATE OR REPLACE PACKAGE BODY xxconv_categories_pkg IS

   PROCEDURE insert_item_category(errbuf            OUT VARCHAR2,
                                  retcode           OUT VARCHAR2,
                                  p_organization_id IN NUMBER) IS
   
      CURSOR csr_categories_structure IS
         SELECT DISTINCT a.structure_name
           FROM xxobjt_conv_item_category a
          WHERE a.err_code = 'N' AND
                a.organization_id = p_organization_id;
   
      CURSOR csr_categories_assignments(p_structure VARCHAR2) IS
         SELECT rtrim(ltrim(a.structure_name,' '),' ')   structure_name,
                rtrim(ltrim(a.item_code,' '),' ')        item_code,
                rtrim(ltrim(a.category,' '),' ')         category,
                a.organization_id
           FROM xxobjt_conv_item_category a
          WHERE a.err_code = 'N' AND
                a.organization_id = p_organization_id AND
                a.structure_name = p_structure;
   
      cur_category_structure  csr_categories_structure%ROWTYPE;
      cur_category_assignment csr_categories_assignments%ROWTYPE;
      v_error                 VARCHAR2(100);
      --v_control_level         mtl_category_sets.control_level%TYPE;
      --v_validate_flag         mtl_category_sets.validate_flag%TYPE;
      --v_to_organiz_id         NUMBER(3);
      v_categ_valid_exists    CHAR(1);
      v_counter               NUMBER(7) := 0;
      v_user_id               NUMBER;
      v_category_set_id       NUMBER;
      v_structure_id          NUMBER;
      v_id_flex_num           NUMBER;
      l_inventory_item_id     NUMBER;
      l_category_id           NUMBER;
      l_def_category_id       NUMBER;
      l_return_status         VARCHAR2(1);
      l_error_code            NUMBER;
      l_msg_count             NUMBER;
      l_msg_data              VARCHAR2(2000);
      invalid_category EXCEPTION;
   BEGIN
   
      BEGIN
         SELECT user_id
           INTO v_user_id
           FROM fnd_user
          WHERE user_name = 'CONVERSION';
      EXCEPTION
         WHEN no_data_found THEN
            errbuf  := 'Invalid User';
            retcode := 2;
            RETURN;
      END;
   
      fnd_global.apps_initialize(user_id      => v_user_id,
                                 resp_id      => 50606,
                                 resp_appl_id => 660);
   
      FOR cur_category_structure IN csr_categories_structure LOOP
      
         BEGIN
            -- get structure and value set details
            SELECT mcs.category_set_id,
                   mcs.validate_flag,
                   mcs.structure_id,
                   --  fifs.id_flex_structure_name structure_name,
                   fifs.id_flex_num
              INTO v_category_set_id,
                   v_categ_valid_exists,
                   v_structure_id,
                   v_id_flex_num
              FROM mtl_category_sets_tl      t,
                   mtl_category_sets_b       mcs,
                   fnd_id_flex_structures_vl fifs,
                   mfg_lookups               ml
             WHERE mcs.category_set_id = t.category_set_id AND
                   t.LANGUAGE = userenv('LANG') AND
                   mcs.structure_id = fifs.id_flex_num AND
                   fifs.application_id = 401 AND
                   fifs.id_flex_code = 'MCAT' AND
                   mcs.control_level = ml.lookup_code AND
                   ml.lookup_type = 'ITEM_CONTROL_LEVEL_GUI' AND
                   t.category_set_name =
                   cur_category_structure.structure_name;
            --id_flex_structure_name =
            ---cur_category_structure.structure_name AND
            --fifs.id_flex_structure_name LIKE 'Objet%';
         
            FOR cur_category_assignment IN csr_categories_assignments(cur_category_structure.structure_name) LOOP
            
               BEGIN
               
                  v_error         := NULL;
                  l_return_status := fnd_api.g_ret_sts_success;
               
                  BEGIN
                     SELECT inventory_item_id
                       INTO l_inventory_item_id
                       FROM mtl_system_items_b
                      WHERE segment1 = cur_category_assignment.item_code AND
                            organization_id =
                            cur_category_assignment.organization_id;
                  
                  EXCEPTION
                     WHEN no_data_found THEN
                        v_error := 'Item is not exist';
                        RAISE invalid_category;
                  END;
               
                  BEGIN
                  
                     SELECT category_id
                       INTO l_category_id
                       FROM mtl_categories_kfv
                      WHERE concatenated_segments = cur_category_assignment.category 
                      AND   structure_id = v_structure_id;
                  EXCEPTION
                     WHEN no_data_found THEN
                        v_error := 'Category does not exist';
                        RAISE invalid_category;
                  END;
               
                  -- IF v_categ_valid_exists = 'Y' THEN
               
                  inv_item_category_pub.create_valid_category(p_api_version        => '1.0',
                                                              p_init_msg_list      => fnd_api.g_true,
                                                              p_commit             => fnd_api.g_true,
                                                              p_category_id        => l_category_id,
                                                              p_category_set_id    => v_category_set_id,
                                                              p_parent_category_id => NULL,
                                                              x_return_status      => l_return_status,
                                                              x_errorcode          => l_error_code,
                                                              x_msg_count          => l_msg_count,
                                                              x_msg_data           => l_msg_data);
               
                  --  END IF;
               
                  BEGIN
                  
                     SELECT category_id
                       INTO l_def_category_id
                       FROM mtl_item_categories mic
                      WHERE mic.inventory_item_id = l_inventory_item_id AND
                            mic.organization_id = p_organization_id AND
                            mic.category_set_id = v_category_set_id;
                  
                     inv_item_category_pub.update_category_assignment(p_api_version       => 1.0,
                                                                      p_init_msg_list     => fnd_api.g_true,
                                                                      p_commit            => fnd_api.g_false,
                                                                      p_category_id       => l_category_id,
                                                                      p_old_category_id   => l_def_category_id,
                                                                      p_category_set_id   => v_category_set_id,
                                                                      p_inventory_item_id => l_inventory_item_id,
                                                                      p_organization_id   => p_organization_id,
                                                                      x_return_status     => l_return_status,
                                                                      x_errorcode         => l_error_code,
                                                                      x_msg_count         => l_msg_count,
                                                                      x_msg_data          => l_msg_data);
                  
                     /*    UPDATE mtl_item_categories
                       SET category_id = l_category_id
                     WHERE organization_id = p_organization_id AND
                           inventory_item_id = l_inventory_item_id AND
                           category_set_id = v_category_set_id AND
                           category_id = l_def_category_id;*/
                  
                  EXCEPTION
                     WHEN no_data_found THEN
                        NULL;
                     
                        inv_item_category_pub.create_category_assignment(p_api_version       => '1.0',
                                                                         p_init_msg_list     => fnd_api.g_true,
                                                                         p_commit            => fnd_api.g_true,
                                                                         p_category_id       => l_category_id,
                                                                         p_category_set_id   => v_category_set_id,
                                                                         p_inventory_item_id => l_inventory_item_id,
                                                                         p_organization_id   => p_organization_id,
                                                                         x_return_status     => l_return_status,
                                                                         x_errorcode         => l_error_code,
                                                                         x_msg_count         => l_msg_count,
                                                                         x_msg_data          => l_msg_data);
                        IF l_return_status != fnd_api.g_ret_sts_success THEN
                           v_error := l_msg_data;
                           RAISE invalid_category;
                        
                        END IF;
                  END;
                  UPDATE xxobjt_conv_item_category c
                     SET c.err_code = 'S'
                   WHERE structure_name =
                         cur_category_structure.structure_name AND
                         item_code = cur_category_assignment.item_code AND
                         organization_id =
                         cur_category_assignment.organization_id;
               
                  IF MOD(v_counter, 1000) = 0 THEN
                     COMMIT;
                  END IF;
               
               EXCEPTION
                  WHEN invalid_category THEN
                     UPDATE xxobjt_conv_item_category c
                        SET c.err_code = 'E', c.err_msg = v_error
                      WHERE structure_name =
                            cur_category_structure.structure_name AND
                            item_code = cur_category_assignment.item_code AND
                            organization_id =
                            cur_category_assignment.organization_id;
                  
                  WHEN OTHERS THEN
                     v_error := SQLERRM;
                     UPDATE xxobjt_conv_item_category c
                        SET c.err_code = 'E', c.err_msg = v_error
                      WHERE structure_name =
                            cur_category_structure.structure_name AND
                            item_code = cur_category_assignment.item_code AND
                            organization_id =
                            cur_category_assignment.organization_id;
                  
               END;
            
            END LOOP;
         
         EXCEPTION
            WHEN OTHERS THEN
               v_error := SQLERRM;
               UPDATE xxobjt_conv_item_category c
                  SET c.err_code = 'E',
                      c.err_msg  = 'Structure: ' || v_error
                WHERE structure_name =
                      cur_category_structure.structure_name;
            
         END;
      
      END LOOP;
   
      COMMIT;
      -- Check If Category Set Controlled At MASTER / ORG Level
      /*       BEGIN
              SELECT control_level, validate_flag
                INTO v_control_level, v_validate_flag
                FROM mtl_category_sets
               WHERE category_set_id = i.category_set_id;
           EXCEPTION
              WHEN OTHERS THEN
                 NULL;
           END;
        
           BEGIN
              -- If Set Handles Categories Validation
              IF v_validate_flag = 'Y' THEN
                 --!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                 BEGIN
                    SELECT 'Y'
                      INTO v_categ_valid_exists
                      FROM mtl_category_set_valid_cats
                     WHERE category_set_id = i.category_set_id AND
                           category_id = i.category_id;
                 
                 EXCEPTION
                    WHEN no_data_found THEN
                       v_categ_valid_exists := 'N';
                 END;
              
                 IF v_categ_valid_exists = 'N' THEN
                 
                    INSERT INTO mtl_category_set_valid_cats
                       (category_set_id,
                        category_id,
                        last_update_date,
                        last_updated_by,
                        creation_date,
                        created_by,
                        last_update_login)
                    VALUES
                       (i.category_set_id,
                        i.category_id,
                        SYSDATE,
                        i.last_updated_by,
                        SYSDATE,
                        i.created_by,
                        i.last_update_login);
                 END IF;
              END IF;
      */
   
   END insert_item_category;

   PROCEDURE handle_categories(errbuf OUT VARCHAR2, retcode OUT VARCHAR2) IS
      -- Hold The flex value set IDs
      TYPE v_categsegs_rec IS RECORD(
         flex_value_set_id NUMBER);
      TYPE v_categsegs_tab IS TABLE OF v_categsegs_rec INDEX BY BINARY_INTEGER;
      v_categsegs_arr v_categsegs_tab;
   
      -- Hold The flex value set Codes
      TYPE v_categvalues_rec IS RECORD(
         segment_code VARCHAR2(50),
         segment_desc VARCHAR2(240));
      TYPE v_categvalues_tab IS TABLE OF v_categvalues_rec INDEX BY BINARY_INTEGER;
      v_categvalues_arr v_categvalues_tab;
   
      --v_read_code NUMBER(5) := 1;
      --v_line_buf  VARCHAR2(2000);
      --v_tmp_line  VARCHAR2(2000);
      --v_delimiter CHAR(1) := ',';
      --v_place     NUMBER(3);
      v_counter   NUMBER(6) := 0;
      v_segs_cnt  NUMBER(2) := 0;
      v_user_id   fnd_user.user_id%TYPE;
   
      --v_file_item_code VARCHAR2(25);
   
      --v_flex_set_id_ace      fnd_id_flex_segments.flex_value_set_id%TYPE;
      v_id_flex_num          fnd_id_flex_structures.id_flex_num%TYPE;
      --v_insert_nextvalue     fnd_flex_values.flex_value_id%TYPE;
      --v_insert_nextvalue_ace fnd_flex_values.flex_value_id%TYPE;
      v_insert_nextcateg     mtl_categories_b.category_id%TYPE;
      --v_insert_nextcateg_ace mtl_categories_b.category_id%TYPE;
      v_conc_categ_code      mtl_categories_tl.description%TYPE;
      --v_conc_categ_code_ace  mtl_categories_tl.description%TYPE;
      v_conc_categ_desc      mtl_categories_b.description%TYPE;
      --v_max_disp_size_ace    fnd_id_flex_segments.display_size%TYPE;
   
      v_segvalue_exists     CHAR(1);
      v_categ_exists        CHAR(1);
      --v_segvalue_exists_ace CHAR(1);
      --v_categ_exists_ace    CHAR(1);
   
      v_category_set_id     mtl_category_sets.category_set_id%TYPE;
      v_structure_id        mtl_category_sets.structure_id%TYPE;
      --v_ibr_categ_id        mtl_categories_b.category_id%TYPE;
      --v_ibr_trx_type        VARCHAR2(8);
      --v_categ_seg_remise    mtl_category_sets.category_set_id%TYPE;
      --v_structure_id_remise mtl_category_sets.structure_id%TYPE;
      --v_remise_categ_id     mtl_categories_b.category_id%TYPE;
      --v_remise_trx_type     VARCHAR2(8);
      --v_categ_seg_stocks    mtl_category_sets.category_set_id%TYPE;
      --v_structure_id_stocks mtl_category_sets.structure_id%TYPE;
      --v_stocks_categ_id     mtl_categories_b.category_id%TYPE;
      --v_stocks_trx_type     VARCHAR2(8);
      --v_organization_code   VARCHAR2(3);
   
      --v_inventory_item_id  mtl_system_items.inventory_item_id%TYPE;
      --v_trans_to_int_flag  CHAR(1);
      v_trans_to_int_error VARCHAR2(240);
      l_value_set_name     VARCHAR2(240);
      l_validation_type    VARCHAR2(1);
      l_storage_value      VARCHAR2(80);
      --l_category_id        NUMBER;
      l_return_status      VARCHAR2(1);
      l_error_code         NUMBER;
      l_msg_count          NUMBER;
      l_msg_data           VARCHAR2(500);
      t_category_rec       inv_item_category_pub.category_rec_type;
      t_new_category_rec   inv_item_category_pub.category_rec_type;
   
      CURSOR csr_valid_structures IS
         SELECT mcs.category_set_id,
                mcs.structure_id,
                fifs.id_flex_num,
                mcs.validate_flag,
                id_flex_structure_name structure_code
           FROM mtl_category_sets_tl      t,
                mtl_category_sets_b       mcs,
                fnd_id_flex_structures_vl fifs,
                mfg_lookups               ml
          WHERE mcs.category_set_id = t.category_set_id AND
                t.LANGUAGE = userenv('LANG') AND
                mcs.structure_id = fifs.id_flex_num AND
                fifs.application_id = 401 AND
                fifs.id_flex_code = 'MCAT' AND
                mcs.control_level = ml.lookup_code AND
                ml.lookup_type = 'ITEM_CONTROL_LEVEL_GUI' AND
                fifs.id_flex_structure_name LIKE 'Objet%';
   
      CURSOR csr_categories(p_structure_code VARCHAR2) IS
         SELECT *
           FROM xxobjt_conv_category xcc
          WHERE xcc.trans_to_int_code = 'N' AND
                xcc.structure_code = p_structure_code;
   
      cur_category csr_categories%ROWTYPE;
   
      CURSOR cr_category_segments(pc_id_flex_num IN NUMBER) IS
         SELECT flex_value_set_id
           FROM fnd_id_flex_segments
          WHERE application_id = 401 AND
                id_flex_code = 'MCAT' AND
                id_flex_num = pc_id_flex_num AND
                enabled_flag = 'Y'
          ORDER BY segment_num;
   
     /* CURSOR cr_current_langs IS
         SELECT language_code
           FROM fnd_languages
          WHERE installed_flag IN ('B', 'I');*/
   
      /*    CURSOR cr_default_categs IS
              SELECT DISTINCT structure_id
                FROM mtl_default_category_sets a, mtl_category_sets b
               WHERE a.category_set_id = b.category_set_id AND
                     category_set_name IN ('Stocks', 'Remise');
      */
   
      cur_structure   csr_valid_structures%ROWTYPE;
      l_validate_flag VARCHAR2(1);
   
   BEGIN
   
      -- Initialize User For Updates
      BEGIN
         SELECT user_id
           INTO v_user_id
           FROM fnd_user
          WHERE user_name = 'CONVERSION';
      EXCEPTION
         WHEN no_data_found THEN
            errbuf  := 'Invalid User';
            retcode := 2;
            RETURN;
      END;
   
      fnd_global.apps_initialize(user_id      => v_user_id,
                                 resp_id      => 20420,
                                 resp_appl_id => 1);
   
      -- get structure and value set details
      FOR cur_structure IN csr_valid_structures LOOP
      
         v_category_set_id := cur_structure.category_set_id;
         v_structure_id    := cur_structure.structure_id;
         v_id_flex_num     := cur_structure.id_flex_num;
         l_validate_flag   := cur_structure.validate_flag;
         v_segs_cnt        := 0;
         v_counter         := 0;
      
         --  dbms_output.put_line(v_id_flex_num);
         FOR i IN cr_category_segments(v_id_flex_num) LOOP
            v_segs_cnt := v_segs_cnt + 1;
            v_categsegs_arr(v_segs_cnt).flex_value_set_id := i.flex_value_set_id;
         END LOOP;
      
         -- Open The File For Reading
      
         FOR cur_category IN csr_categories(cur_structure.structure_code) LOOP
         
            BEGIN
            
               v_counter            := v_counter + 1;
               v_trans_to_int_error := NULL;
               v_conc_categ_code    := NULL;
               v_conc_categ_desc    := NULL;
            
               BEGIN
               
                  v_categvalues_arr(1).segment_code := cur_category.segment1;
                  v_categvalues_arr(1).segment_desc := cur_category.description1;
                  v_categvalues_arr(2).segment_code := cur_category.segment2;
                  v_categvalues_arr(2).segment_desc := cur_category.description2;
                  v_categvalues_arr(3).segment_code := cur_category.segment3;
                  v_categvalues_arr(3).segment_desc := cur_category.description3;
                  v_categvalues_arr(4).segment_code := cur_category.segment4;
                  v_categvalues_arr(4).segment_desc := cur_category.description4;
                  v_categvalues_arr(5).segment_code := cur_category.segment5;
                  v_categvalues_arr(5).segment_desc := cur_category.description5;
                  v_categvalues_arr(6).segment_code := cur_category.segment6;
                  v_categvalues_arr(6).segment_desc := cur_category.description6;
                  v_categvalues_arr(7).segment_code := cur_category.segment7;
                  v_categvalues_arr(7).segment_desc := cur_category.description7;
                  v_categvalues_arr(8).segment_code := cur_category.segment8;
                  v_categvalues_arr(8).segment_desc := cur_category.description8;
               
               EXCEPTION
                  WHEN OTHERS THEN
                     NULL;
               END;
            
               FOR cnt IN 1 .. v_segs_cnt LOOP
               
                  -- Check If The Value Exists In Flex Values
                  IF v_categvalues_arr(cnt).segment_code IS NOT NULL THEN
                  
                     BEGIN
                        SELECT 'Y'
                          INTO v_segvalue_exists
                          FROM fnd_flex_values
                         WHERE flex_value_set_id = v_categsegs_arr(cnt)
                        .flex_value_set_id AND
                               flex_value = v_categvalues_arr(cnt)
                        .segment_code;
                     EXCEPTION
                        WHEN no_data_found THEN
                        
                           SELECT fvs.flex_value_set_name,
                                  fvs.validation_type
                             INTO l_value_set_name, l_validation_type
                             FROM fnd_flex_value_sets fvs
                            WHERE fvs.flex_value_set_id =
                                  v_categsegs_arr(cnt)
                           .flex_value_set_id;
                        
                           IF l_validation_type = 'I' THEN
                           
                              fnd_flex_val_api.create_independent_vset_value(p_flex_value_set_name => l_value_set_name,
                                                                             p_flex_value          => v_categvalues_arr(cnt)
                                                                                                     .segment_code,
                                                                             p_description         => v_categvalues_arr(cnt)
                                                                                                     .segment_desc,
                                                                             x_storage_value       => l_storage_value);
                           
                           END IF; -- validation type
                     
                     END;
                  
                     v_conc_categ_code := v_conc_categ_code || '.' ||
                                          v_categvalues_arr(cnt)
                                         .segment_code;
                     v_conc_categ_desc := v_conc_categ_desc || '.' ||
                                          v_categvalues_arr(cnt)
                                         .segment_desc;
                  
                  END IF; --segment is not null
               END LOOP; --loop over segments
            
               v_conc_categ_code := substr(v_conc_categ_code, 2);
               v_conc_categ_desc := substr(v_conc_categ_desc, 2);
            
               -- Check If The Category Exists In ITELCO_CATEGORIES (After We're Sure All Segments Are OK) 
               BEGIN
               
                  SELECT 'Y'
                    INTO v_categ_exists
                    FROM mtl_categories_kfv mc
                   WHERE structure_id = v_id_flex_num AND
                         mc.concatenated_segments = v_conc_categ_code;
               
               EXCEPTION
                  WHEN no_data_found THEN
                  
                     t_category_rec              := t_new_category_rec;
                     t_category_rec.structure_id := v_id_flex_num;
                     --   t_category_rec.last_update_date            := SYSDATE;
                     --  t_category_rec.last_updated_by             := v_user_id;
                     --  t_category_rec.creation_date               := SYSDATE;
                     --  t_category_rec.created_by                  := v_user_id;
                     --  t_category_rec.last_update_login           := -1;
                     t_category_rec.segment1     := v_categvalues_arr(1)
                                                   .segment_code;
                     t_category_rec.segment2     := v_categvalues_arr(2)
                                                   .segment_code;
                     t_category_rec.segment3     := v_categvalues_arr(3)
                                                   .segment_code;
                     t_category_rec.segment4     := v_categvalues_arr(4)
                                                   .segment_code;
                     t_category_rec.segment5     := v_categvalues_arr(5)
                                                   .segment_code;
                     t_category_rec.segment6     := v_categvalues_arr(6)
                                                   .segment_code;
                     t_category_rec.segment7     := v_categvalues_arr(7)
                                                   .segment_code;
                     t_category_rec.segment8     := v_categvalues_arr(8)
                                                   .segment_code;
                     t_category_rec.summary_flag := 'N';
                     t_category_rec.enabled_flag := 'Y';
                     t_category_rec.description  := v_conc_categ_code;
                  
                     inv_item_category_pub.create_category(p_api_version   => '1.0',
                                                           p_init_msg_list => fnd_api.g_true,
                                                           p_commit        => fnd_api.g_false,
                                                           x_return_status => l_return_status,
                                                           x_errorcode     => l_error_code,
                                                           x_msg_count     => l_msg_count,
                                                           x_msg_data      => l_msg_data,
                                                           p_category_rec  => t_category_rec,
                                                           x_category_id   => v_insert_nextcateg);
                  
                     /*               SELECT mtl_categories_b_s.NEXTVAL
                                         INTO v_insert_nextcateg
                                         FROM dual;
                                    
                                       INSERT INTO mtl_categories_b
                                          (category_id,
                                           structure_id,
                                           last_update_date,
                                           last_updated_by,
                                           creation_date,
                                           created_by,
                                           last_update_login,
                                           segment1,
                                           segment2,
                                           segment3,
                                           segment4,
                                           segment6,
                                           segment7,
                                           summary_flag,
                                           enabled_flag,
                                           description)
                                       VALUES
                                          (v_insert_nextcateg,
                                           v_id_flex_num,
                                           SYSDATE,
                                           v_user_id,
                                           SYSDATE,
                                           v_user_id,
                                           -1,
                                           v_categvalues_arr(1).segment_code,
                                           v_categvalues_arr(2).segment_code,
                                           v_categvalues_arr(3).segment_code,
                                           v_categvalues_arr(4).segment_code,
                                           v_categvalues_arr(5).segment_code,
                                           v_categvalues_arr(6).segment_code,
                                           'N',
                                           'Y',
                                           v_conc_categ_code);
                                    
                                       INSERT INTO mtl_categories_tl
                                          (category_id,
                                           LANGUAGE,
                                           source_lang,
                                           description,
                                           last_update_date,
                                           last_updated_by,
                                           creation_date,
                                           created_by,
                                           last_update_login)
                                          SELECT v_insert_nextcateg,
                                                 lang.language_code,
                                                 'US',
                                                 v_conc_categ_desc,
                                                 SYSDATE,
                                                 v_user_id,
                                                 SYSDATE,
                                                 v_user_id,
                                                 -1
                                            FROM fnd_languages lang
                                           WHERE installed_flag IN ('B', 'I');
                     */
                     --IF l_validate_flag = 'Y' THEN
                  
                     BEGIN
                     
                        inv_item_category_pub.create_valid_category(p_api_version        => '1.0',
                                                                    p_init_msg_list      => fnd_api.g_true,
                                                                    p_commit             => fnd_api.g_true,
                                                                    p_category_id        => v_insert_nextcateg,
                                                                    p_category_set_id    => v_category_set_id,
                                                                    p_parent_category_id => NULL,
                                                                    x_return_status      => l_return_status,
                                                                    x_errorcode          => l_error_code,
                                                                    x_msg_count          => l_msg_count,
                                                                    x_msg_data           => l_msg_data);
                     
                     EXCEPTION
                        WHEN OTHERS THEN
                           NULL;
                     END;
                  
                  -- IF;
               
               END;
            
               UPDATE xxobjt_conv_category xcc
                  SET xcc.trans_to_int_code  = 'S',
                      xcc.trans_to_int_error = NULL
                WHERE xcc.structure_code = cur_category.structure_code AND
                      nvl(xcc.segment1, 'null') =
                      nvl(cur_category.segment1, 'null') AND
                      nvl(xcc.segment2, 'null') =
                      nvl(cur_category.segment2, 'null') AND
                      nvl(xcc.segment3, 'null') =
                      nvl(cur_category.segment3, 'null') AND
                      nvl(xcc.segment4, 'null') =
                      nvl(cur_category.segment4, 'null') AND
                      nvl(xcc.segment5, 'null') =
                      nvl(cur_category.segment5, 'null') AND
                      nvl(xcc.segment6, 'null') =
                      nvl(cur_category.segment6, 'null') AND
                      nvl(xcc.segment7, 'null') =
                      nvl(cur_category.segment7, 'null') AND
                      nvl(xcc.segment8, 'null') =
                      nvl(cur_category.segment8, 'null');
            
               IF MOD(v_counter, 500) = 0 THEN
                  COMMIT;
               END IF;
            
            EXCEPTION
               WHEN OTHERS THEN
               
                  v_trans_to_int_error := SQLERRM;
               
                  UPDATE xxobjt_conv_category xcc
                     SET xcc.trans_to_int_code  = 'E',
                         xcc.trans_to_int_error = v_trans_to_int_error
                   WHERE xcc.structure_code = cur_category.structure_code AND
                         nvl(xcc.segment1, 'null') =
                         nvl(cur_category.segment1, 'null') AND
                         nvl(xcc.segment2, 'null') =
                         nvl(cur_category.segment2, 'null') AND
                         nvl(xcc.segment3, 'null') =
                         nvl(cur_category.segment3, 'null') AND
                         nvl(xcc.segment4, 'null') =
                         nvl(cur_category.segment4, 'null') AND
                         nvl(xcc.segment5, 'null') =
                         nvl(cur_category.segment5, 'null') AND
                         nvl(xcc.segment6, 'null') =
                         nvl(cur_category.segment6, 'null') AND
                         nvl(xcc.segment7, 'null') =
                         nvl(cur_category.segment7, 'null') AND
                         nvl(xcc.segment8, 'null') =
                         nvl(cur_category.segment8, 'null');
               
            END;
         
         END LOOP;
      
         COMMIT;
      
      END LOOP;
   
   END handle_categories;

   PROCEDURE delete_category(p_category_set_id NUMBER,
                             p_category_id     NUMBER) IS
   
      l_return_status VARCHAR2(1);
      l_error_code    NUMBER;
      l_msg_count     NUMBER;
      l_msg_data      VARCHAR2(500);
   
   BEGIN
      inv_item_category_pub.delete_valid_category(p_api_version     => '1.0',
                                                  p_init_msg_list   => fnd_api.g_true,
                                                  p_commit          => fnd_api.g_true,
                                                  x_return_status   => l_return_status,
                                                  x_errorcode       => l_error_code,
                                                  x_msg_count       => l_msg_count,
                                                  x_msg_data        => l_msg_data,
                                                  p_category_set_id => p_category_set_id,
                                                  p_category_id     => p_category_id);
   
      inv_item_category_pub.delete_category(p_api_version   => '1.0',
                                            p_init_msg_list => fnd_api.g_true,
                                            p_commit        => fnd_api.g_true,
                                            x_return_status => l_return_status,
                                            x_errorcode     => l_error_code,
                                            x_msg_count     => l_msg_count,
                                            x_msg_data      => l_msg_data,
                                            p_category_id   => p_category_id);
   
   END;
   ----------------------------------------------------------------------------
   PROCEDURE handle_ssys_categories(errbuf OUT VARCHAR2, retcode OUT VARCHAR2) IS
      -- Hold The flex value set IDs
      TYPE v_categsegs_rec IS RECORD(flex_value_set_id   NUMBER,
                                     flex_value_set_name VARCHAR2(100));
      TYPE v_categsegs_tab IS TABLE OF v_categsegs_rec INDEX BY BINARY_INTEGER;
      v_categsegs_arr v_categsegs_tab;
   
      -- Hold The flex value set Codes
      TYPE v_categvalues_rec IS RECORD(
         segment_code VARCHAR2(50),
         segment_desc VARCHAR2(240));
      TYPE v_categvalues_tab IS TABLE OF v_categvalues_rec INDEX BY BINARY_INTEGER;
      v_categvalues_arr v_categvalues_tab;
   
      l_error_tbl inv_item_grp.error_tbl_type;
      l_err_msg   VARCHAR2(300);
      v_step      VARCHAR2(100);
      --v_read_code NUMBER(5) := 1;
      --v_line_buf  VARCHAR2(2000);
      --v_tmp_line  VARCHAR2(2000);
      --v_delimiter CHAR(1) := ',';
      --v_place     NUMBER(3);
      v_counter   NUMBER(6) := 0;
      v_segs_cnt  NUMBER(2) := 0;
      v_user_id   fnd_user.user_id%TYPE;
      
      v_categories_success        number:=0;
      v_categories_failured       number:=0;
      v_categories_already_exist  number:=0;
      
      --v_file_item_code VARCHAR2(25);
   
      --v_flex_set_id_ace      fnd_id_flex_segments.flex_value_set_id%TYPE;
      v_id_flex_num          fnd_id_flex_structures.id_flex_num%TYPE;
      --v_insert_nextvalue     fnd_flex_values.flex_value_id%TYPE;
      --v_insert_nextvalue_ace fnd_flex_values.flex_value_id%TYPE;
      v_insert_nextcateg     mtl_categories_b.category_id%TYPE;
      --v_insert_nextcateg_ace mtl_categories_b.category_id%TYPE;
      v_conc_categ_code      mtl_categories_tl.description%TYPE;
      --v_conc_categ_code_ace  mtl_categories_tl.description%TYPE;
      v_conc_categ_desc      mtl_categories_b.description%TYPE;
      --v_max_disp_size_ace    fnd_id_flex_segments.display_size%TYPE;
   
      v_segvalue_exists     CHAR(1);
      v_categ_exists        CHAR(1);
      --v_segvalue_exists_ace CHAR(1);
      --v_categ_exists_ace    CHAR(1);
   
      v_category_set_id     mtl_category_sets.category_set_id%TYPE;
      v_structure_id        mtl_category_sets.structure_id%TYPE;
      --v_ibr_categ_id        mtl_categories_b.category_id%TYPE;
      --v_ibr_trx_type        VARCHAR2(8);
      --v_categ_seg_remise    mtl_category_sets.category_set_id%TYPE;
      --v_structure_id_remise mtl_category_sets.structure_id%TYPE;
      --v_remise_categ_id     mtl_categories_b.category_id%TYPE;
      --v_remise_trx_type     VARCHAR2(8);
      --v_categ_seg_stocks    mtl_category_sets.category_set_id%TYPE;
      --v_structure_id_stocks mtl_category_sets.structure_id%TYPE;
      --v_stocks_categ_id     mtl_categories_b.category_id%TYPE;
      ----v_stocks_trx_type     VARCHAR2(8);
      --v_organization_code   VARCHAR2(3);
   
      --v_inventory_item_id  mtl_system_items.inventory_item_id%TYPE;
      --v_trans_to_int_flag  CHAR(1);
      v_trans_to_int_error VARCHAR2(1000);
      l_value_set_name     VARCHAR2(240);
      l_validation_type    VARCHAR2(1);
      l_storage_value      VARCHAR2(80);
      --l_category_id        NUMBER;
      l_return_status      VARCHAR2(1);
      l_error_code         NUMBER;
      l_msg_count          NUMBER;
      l_msg_data           VARCHAR2(500);
      t_category_rec       inv_item_category_pub.category_rec_type;
      t_new_category_rec   inv_item_category_pub.category_rec_type;
   
      CURSOR csr_valid_structures IS
         SELECT mcs.category_set_id,  
                t.category_set_name,
                mcs.structure_id,
                fifs.id_flex_num,
                mcs.validate_flag,
                fifs.id_flex_structure_name structure_name,
                rtrim(ltrim(fifs.ID_FLEX_STRUCTURE_CODE,' '),' ') structure_code  ---XXINV_MAIN_ITEM_CATEGORY
           FROM mtl_category_sets_tl      t,
                mtl_category_sets_b       mcs,
                fnd_id_flex_structures_vl fifs,
                mfg_lookups               ml
          WHERE mcs.category_set_id = t.category_set_id AND
                t.LANGUAGE = 'US' AND
                mcs.structure_id = fifs.id_flex_num AND
                fifs.application_id = 401 AND
                fifs.id_flex_code = 'MCAT' AND
                mcs.control_level = ml.lookup_code AND
                ml.lookup_type = 'ITEM_CONTROL_LEVEL_GUI' AND
                fifs.ID_FLEX_STRUCTURE_CODE='XXINV_MAIN_ITEM_CATEGORY' AND
                t.category_set_name='Main Category Set'; 
   
      CURSOR csr_categories(p_structure_code VARCHAR2) IS
         SELECT xcc.structure_code,
                xcc.segment1,  xcc.description1,
                xcc.segment2,  xcc.description2,
                xcc.segment3,  xcc.description3,
                upper(xcc.finish_good_flag)   finish_good_flag
           FROM xxobjt_conv_category xcc
          WHERE xcc.trans_to_int_code = 'N' AND
                xcc.structure_code = p_structure_code;
   
      cur_category csr_categories%ROWTYPE;
   
      CURSOR cr_category_segments(pc_id_flex_num IN NUMBER) IS
         SELECT s.flex_value_set_id,     
                vs.flex_value_set_name,  ---XXINV_ITEM_GROUP, XXINV_ITEM_FAMILY, XXINV_ITEM_CATEGORY
                s.segment_num            ---10, 20, 30
           FROM fnd_id_flex_segments  s,
                fnd_flex_value_sets   vs
          WHERE s.application_id = 401 AND
                s.id_flex_code = 'MCAT' AND
                s.id_flex_num = pc_id_flex_num AND
                s.enabled_flag = 'Y' AND
                s.flex_value_set_id=vs.flex_value_set_id
          ORDER BY s.segment_num;
   
     /* CURSOR cr_current_langs IS
         SELECT language_code
           FROM fnd_languages
          WHERE installed_flag IN ('B', 'I');*/
   
      /*    CURSOR cr_default_categs IS
              SELECT DISTINCT structure_id
                FROM mtl_default_category_sets a, mtl_category_sets b
               WHERE a.category_set_id = b.category_set_id AND
                     category_set_name IN ('Stocks', 'Remise');
      */
   
      cur_structure   csr_valid_structures%ROWTYPE;
      l_validate_flag VARCHAR2(1);
   
   BEGIN
     
v_step :='Step 0';
errbuf :=null;
retcode:='0';   
   
      -- Initialize User For Updates
      BEGIN
         SELECT user_id
           INTO v_user_id
           FROM fnd_user
          WHERE user_name = 'CONVERSION';
      EXCEPTION
         WHEN no_data_found THEN
            errbuf  := 'Invalid User';
            retcode := 2;
            RETURN;
      END;
   
      fnd_global.apps_initialize(user_id      => v_user_id,
                                 resp_id      => 20420,
                                 resp_appl_id => 1);
                                 
v_step :='Step 5'; 
----Check segments1,2,3 that already exist in "other case"-------------------                                
UPDATE  XXOBJT_CONV_CATEGORY  cc
SET     cc.trans_to_int_code='E',
        cc.trans_to_int_error='Segment1 Already Exists in vs XXINV_ITEM_GROUP'
WHERE cc.trans_to_int_code='N'
AND EXISTS 
(select 1
from  fnd_flex_value_sets ffvs, 
      fnd_flex_values_vl  ffv
WHERE ffvs.flex_value_set_id = ffv.flex_value_set_id  
AND   flex_value_set_name = 'XXINV_ITEM_GROUP' ---for Seg1  
AND   ffv.enabled_flag = 'Y'
AND   upper(flex_value)=upper(ltrim(rtrim(cc.segment1,' '),' '))
and   flex_value<>ltrim(rtrim(cc.segment1,' '),' '));


UPDATE  XXOBJT_CONV_CATEGORY  cc
SET     cc.trans_to_int_code='E',
        cc.trans_to_int_error='Segment2 Already Exists in vs XXINV_ITEM_GROUP'
WHERE cc.trans_to_int_code='N'
AND EXISTS 
(select 1
from  fnd_flex_value_sets ffvs, 
      fnd_flex_values_vl  ffv
WHERE ffvs.flex_value_set_id = ffv.flex_value_set_id  
AND   flex_value_set_name = 'XXINV_ITEM_FAMILY' ---for Seg2  
AND   ffv.enabled_flag = 'Y'
AND   upper(flex_value)=upper(ltrim(rtrim(cc.segment2,' '),' '))
and   flex_value<>ltrim(rtrim(cc.segment2,' '),' '));


UPDATE  XXOBJT_CONV_CATEGORY  cc
SET     cc.trans_to_int_code='E',
        cc.trans_to_int_error='Segment3 Already Exists in vs XXINV_ITEM_GROUP'
WHERE cc.trans_to_int_code='N'
AND EXISTS 
(select 1
from  fnd_flex_value_sets ffvs, 
      fnd_flex_values_vl  ffv
WHERE ffvs.flex_value_set_id = ffv.flex_value_set_id  
AND   flex_value_set_name = 'XXINV_ITEM_CATEGORY' --for Seg3  
AND   ffv.enabled_flag = 'Y'
AND   upper(flex_value)=upper(ltrim(rtrim(cc.segment3,' '),' '))
and   flex_value<>ltrim(rtrim(cc.segment3,' '),' '));                                 
                                 
v_step :='Step 10';  
      -- get structure and value set details
      FOR cur_structure IN csr_valid_structures LOOP
         ---DBMS_OUTPUT.put_line('');
         ---DBMS_OUTPUT.put_line('*** Structure '''||cur_structure.structure_code||'''**********');
         ---DBMS_OUTPUT.put_line('');
         v_category_set_id := cur_structure.category_set_id;
         v_structure_id    := cur_structure.structure_id;
         v_id_flex_num     := cur_structure.id_flex_num;
         l_validate_flag   := cur_structure.validate_flag;
         v_segs_cnt        := 0;
         v_counter         := 0;
         v_step :='Step 20';
         --  dbms_output.put_line(v_id_flex_num);
         FOR i IN cr_category_segments(v_id_flex_num) LOOP
            v_segs_cnt := v_segs_cnt + 1;
            v_categsegs_arr(v_segs_cnt).flex_value_set_id  := i.flex_value_set_id;
            v_categsegs_arr(v_segs_cnt).flex_value_set_name:= i.flex_value_set_name;                
         END LOOP;
      
         -- Open The File For Reading
         FOR cur_category IN csr_categories(cur_structure.structure_code) LOOP
            v_step :='Step 30';
            ---DBMS_OUTPUT.put_line('');  -- empty line
            ---DBMS_OUTPUT.put_line('============== Category '''||cur_category.segment1||'.'||cur_category.segment2||'.'||cur_category.segment3||'''=======================');
            BEGIN
               l_error_tbl.DELETE;
               l_err_msg            :=null;
               v_counter            := v_counter + 1;
               v_trans_to_int_error := NULL;
               v_conc_categ_code    := NULL;
               v_conc_categ_desc    := NULL;
               v_categvalues_arr(1).segment_code := rtrim(ltrim(cur_category.segment1,' '),' ');
               v_categvalues_arr(1).segment_desc := rtrim(ltrim(cur_category.description1,' '),' ');
               v_categvalues_arr(2).segment_code := rtrim(ltrim(cur_category.segment2,' '),' ');
               v_categvalues_arr(2).segment_desc := rtrim(ltrim(cur_category.description2,' '),' ');
               v_categvalues_arr(3).segment_code := rtrim(ltrim(cur_category.segment3,' '),' ');
               v_categvalues_arr(3).segment_desc := rtrim(ltrim(cur_category.description3,' '),' ');
               ---v_categvalues_arr(4).segment_code := cur_category.segment4;
               ---v_categvalues_arr(4).segment_desc := cur_category.description4;
               ---v_categvalues_arr(5).segment_code := cur_category.segment5;
               ---v_categvalues_arr(5).segment_desc := cur_category.description5;
               ---v_categvalues_arr(6).segment_code := cur_category.segment6;
               ---v_categvalues_arr(6).segment_desc := cur_category.description6;
               ---v_categvalues_arr(7).segment_code := cur_category.segment7;
               ---v_categvalues_arr(7).segment_desc := cur_category.description7;
               ---v_categvalues_arr(8).segment_code := cur_category.segment8;
               ---v_categvalues_arr(8).segment_desc := cur_category.description8;  
               
               if cur_category.segment1 is null then
                  ---DBMS_OUTPUT.put_line('Category='''||v_conc_categ_code||''' : missing SEGMENT1');
                  v_trans_to_int_error:=v_trans_to_int_error||'; missing SEGMENT1';
               end if;
               if cur_category.segment2 is null then
                  ---DBMS_OUTPUT.put_line('Category='''||v_conc_categ_code||''' : missing SEGMENT2');
                  v_trans_to_int_error:=v_trans_to_int_error||'; missing SEGMENT2';
               end if;
               if cur_category.segment3 is null then
                  ---DBMS_OUTPUT.put_line('Category='''||v_conc_categ_code||''' : missing SEGMENT3');
                  v_trans_to_int_error:=v_trans_to_int_error||'; missing SEGMENT3';
               end if;
               if cur_category.finish_good_flag is null then
                  ---DBMS_OUTPUT.put_line('Category='''||v_conc_categ_code||''' : missing FINISH GOOG FLAG');
                  v_trans_to_int_error:=v_trans_to_int_error||'; missing FINISH GOOG FLAG';
               elsif cur_category.finish_good_flag not in ('N','Y') then
                  ---DBMS_OUTPUT.put_line('Category='''||v_conc_categ_code||''' : invalid value for FINISH GOOG FLAG (Y/N)');
                  v_trans_to_int_error:=v_trans_to_int_error||'; invalid value for FINISH GOOG FLAG (Y/N)';
               end if;
                            
               v_step :='Step 40';
               FOR cnt IN 1 .. v_segs_cnt LOOP               
                  -- Check If The Value Exists In Flex Values
                  IF v_categvalues_arr(cnt).segment_code IS NOT NULL THEN
                  
                     BEGIN
                        SELECT 'Y'
                          INTO v_segvalue_exists
                          FROM fnd_flex_values
                         WHERE flex_value_set_id = v_categsegs_arr(cnt).flex_value_set_id AND
                               flex_value = v_categvalues_arr(cnt).segment_code;
                     EXCEPTION
                        WHEN no_data_found THEN                        
                           SELECT fvs.flex_value_set_name,fvs.validation_type
                             INTO l_value_set_name, l_validation_type
                             FROM fnd_flex_value_sets fvs
                            WHERE fvs.flex_value_set_id = v_categsegs_arr(cnt).flex_value_set_id;
                           IF l_validation_type = 'I' THEN
                              ---DBMS_OUTPUT.put_line('Segment'||cnt||'='''||v_categvalues_arr(cnt).segment_code||
                              ---                     ''' does not exist in value set '''||v_categsegs_arr(cnt).flex_value_set_name||
                              ---                     ''' and will be created');
                              v_trans_to_int_error:=v_trans_to_int_error||'; Segment'||cnt||'='''||v_categvalues_arr(cnt).segment_code||
                                                   ''' does not exist in value set '''||----v_categsegs_arr(cnt).flex_value_set_name
                                                                                        l_value_set_name||
                                                   ''' (id='||v_categsegs_arr(cnt).flex_value_set_id||') and will be created';
                              fnd_flex_val_api.create_independent_vset_value(p_flex_value_set_name => l_value_set_name,
                                                                             p_flex_value          => v_categvalues_arr(cnt)
                                                                                                     .segment_code,
                                                                             p_description         => v_categvalues_arr(cnt)
                                                                                                     .segment_desc,
                                                                             x_storage_value       => l_storage_value);
                           END IF; -- validation type                     
                     END;                  
                     v_conc_categ_code := v_conc_categ_code || '.' ||v_categvalues_arr(cnt).segment_code;
                     v_conc_categ_desc := v_conc_categ_desc || '.' ||v_categvalues_arr(cnt).segment_desc;
                  
                  END IF; --segment is not null
               END LOOP; --loop over segments
            
               v_conc_categ_code := substr(v_conc_categ_code, 2);
               v_conc_categ_desc := substr(v_conc_categ_desc, 2);
            
               -- Check If The Category Exists In ITELCO_CATEGORIES (After We're Sure All Segments Are OK) 
               BEGIN
               
                  SELECT 'Y'
                    INTO v_categ_exists
                    FROM mtl_categories_kfv mc
                   WHERE structure_id = v_id_flex_num AND
                         mc.concatenated_segments = v_conc_categ_code; 
                  ---DBMS_OUTPUT.put_line('Category='''||v_conc_categ_code||''' already exists');
                  v_trans_to_int_error:=v_trans_to_int_error||'; Category='''||v_conc_categ_code||''' already exists';
                  v_categories_already_exist:=v_categories_already_exist+1;              
               EXCEPTION
                  WHEN no_data_found THEN
                     ---DBMS_OUTPUT.put_line('Category='''||v_conc_categ_code||''' does not exist and will be created');
                     v_trans_to_int_error:=v_trans_to_int_error||'; Category='''||v_conc_categ_code||''' does not exist and will be created';
                     t_category_rec              := t_new_category_rec;
                     t_category_rec.structure_id := v_id_flex_num;
                     ---t_category_rec.last_update_date            := SYSDATE;
                     ---t_category_rec.last_updated_by             := v_user_id;
                     ---t_category_rec.creation_date               := SYSDATE;
                     ---t_category_rec.created_by                  := v_user_id;
                     ---t_category_rec.last_update_login           := -1;
                     t_category_rec.segment1     := v_categvalues_arr(1).segment_code;
                     t_category_rec.segment2     := v_categvalues_arr(2).segment_code;
                     t_category_rec.segment3     := v_categvalues_arr(3).segment_code;
                     ---t_category_rec.segment4     := v_categvalues_arr(4).segment_code;
                     ---t_category_rec.segment5     := v_categvalues_arr(5).segment_code;
                     ---t_category_rec.segment6     := v_categvalues_arr(6).segment_code;
                     ---t_category_rec.segment7     := v_categvalues_arr(7).segment_code;
                     ---t_category_rec.segment8     := v_categvalues_arr(8).segment_code;
                     if v_categvalues_arr(1).segment_code in ('Systems','FG-Systems') then
                         t_category_rec.attribute4:= 'PRINTER'; 
                     end if;
                     t_category_rec.attribute7   :=upper(cur_category.finish_good_flag);
                     t_category_rec.attribute8   :='FDM';
                     t_category_rec.summary_flag := 'N';
                     t_category_rec.enabled_flag := 'Y';
                     ----t_category_rec.description  := v_conc_categ_code; 
                     
                     inv_item_category_pub.create_category(p_api_version   => '1.0',
                                                           p_init_msg_list => fnd_api.g_true,
                                                           p_commit        => fnd_api.g_false,
                                                           x_return_status => l_return_status,
                                                           x_errorcode     => l_error_code,
                                                           x_msg_count     => l_msg_count,
                                                           x_msg_data      => l_msg_data,
                                                           p_category_rec  => t_category_rec,
                                                           x_category_id   => v_insert_nextcateg);
                     IF l_return_status = 'S' THEN
                         ---DBMS_OUTPUT.put_line('Category='''||v_conc_categ_code||''' was created successfuly (category_id='||v_insert_nextcateg||')');
                         v_trans_to_int_error:=v_trans_to_int_error||'; Category='''||v_conc_categ_code||''' was created (category_id='||v_insert_nextcateg||')';
                         v_categories_success:=v_categories_success+1;
                     ELSE
                         FOR i IN 1 .. l_error_tbl.COUNT LOOP
                            l_err_msg := l_err_msg || l_error_tbl(i).message_text || chr(10);
               
                         END LOOP;
                         -----DBMS_OUTPUT.put_line('Category='''||v_conc_categ_code||''' creation ERROR: '||l_err_msg);
                         v_trans_to_int_error:=v_trans_to_int_error||'; Category='''||v_conc_categ_code||''' creation ERROR: '||l_err_msg;
                         v_categories_failured:=v_categories_failured+1;
                     END IF;
                     
                     /*inv_item_category_pub.Update_Category_Description(p_api_version   => '1.0',
                                                                       p_init_msg_list => fnd_api.g_true,
                                                                       p_commit        => fnd_api.g_false,
                                                                       x_return_status => l_return_status,
                                                                       x_errorcode     => l_error_code,
                                                                       x_msg_count     => l_msg_count,
                                                                       x_msg_data      => l_msg_data,
                                                                       p_category_id   => v_insert_nextcateg,
                                                                       p_description   => v_conc_categ_code);
                     IF l_return_status = 'S' THEN
                         ---DBMS_OUTPUT.put_line('Category Description was updated successfuly');
                         null;
                     ELSE
                         FOR i IN 1 .. l_error_tbl.COUNT LOOP
                            l_err_msg := l_err_msg || l_error_tbl(i).message_text || chr(10);
               
                         END LOOP;
                         DBMS_OUTPUT.put_line('Category Description updating ERROR: '||l_err_msg);
                     END IF;*/
                     
                     
                     /*               SELECT mtl_categories_b_s.NEXTVAL
                                         INTO v_insert_nextcateg
                                         FROM dual;
                                    
                                       INSERT INTO mtl_categories_b
                                          (category_id,
                                           structure_id,
                                           last_update_date,
                                           last_updated_by,
                                           creation_date,
                                           created_by,
                                           last_update_login,
                                           segment1,
                                           segment2,
                                           segment3,
                                           segment4,
                                           segment6,
                                           segment7,
                                           summary_flag,
                                           enabled_flag,
                                           description)
                                       VALUES
                                          (v_insert_nextcateg,
                                           v_id_flex_num,
                                           SYSDATE,
                                           v_user_id,
                                           SYSDATE,
                                           v_user_id,
                                           -1,
                                           v_categvalues_arr(1).segment_code,
                                           v_categvalues_arr(2).segment_code,
                                           v_categvalues_arr(3).segment_code,
                                           v_categvalues_arr(4).segment_code,
                                           v_categvalues_arr(5).segment_code,
                                           v_categvalues_arr(6).segment_code,
                                           'N',
                                           'Y',
                                           v_conc_categ_code);
                                    
                                       INSERT INTO mtl_categories_tl
                                          (category_id,
                                           LANGUAGE,
                                           source_lang,
                                           description,
                                           last_update_date,
                                           last_updated_by,
                                           creation_date,
                                           created_by,
                                           last_update_login)
                                          SELECT v_insert_nextcateg,
                                                 lang.language_code,
                                                 'US',
                                                 v_conc_categ_desc,
                                                 SYSDATE,
                                                 v_user_id,
                                                 SYSDATE,
                                                 v_user_id,
                                                 -1
                                            FROM fnd_languages lang
                                           WHERE installed_flag IN ('B', 'I');
                     */
                     --IF l_validate_flag = 'Y' THEN                  
                     BEGIN                     
                        inv_item_category_pub.create_valid_category(p_api_version        => '1.0',
                                                                    p_init_msg_list      => fnd_api.g_true,
                                                                    p_commit             => fnd_api.g_true,
                                                                    p_category_id        => v_insert_nextcateg,
                                                                    p_category_set_id    => v_category_set_id,
                                                                    p_parent_category_id => NULL,
                                                                    x_return_status      => l_return_status,
                                                                    x_errorcode          => l_error_code,
                                                                    x_msg_count          => l_msg_count,
                                                                    x_msg_data           => l_msg_data);
                        IF l_return_status = 'S' THEN
                          ---DBMS_OUTPUT.put_line('Valid Category was created successfuly');
                          null;
                        ELSE
                         FOR i IN 1 .. l_error_tbl.COUNT LOOP
                            l_err_msg := l_err_msg || l_error_tbl(i).message_text || chr(10);
               
                         END LOOP;
                         ---DBMS_OUTPUT.put_line('Valid Category creation ERROR: '||l_err_msg);
                         v_trans_to_int_error:=v_trans_to_int_error||'; Valid Category creation ERROR: '||l_err_msg;
                        END IF;
                     EXCEPTION
                        WHEN OTHERS THEN
                           NULL;
                     END;                  
                  -- IF;               
               END;
            
               UPDATE xxobjt_conv_category xcc
                  SET xcc.trans_to_int_code  = 'S',
                      xcc.trans_to_int_error = substr(v_trans_to_int_error,1,250)
                WHERE xcc.structure_code = cur_category.structure_code AND
                      nvl(xcc.segment1, 'null') =
                      nvl(cur_category.segment1, 'null') AND
                      nvl(xcc.segment2, 'null') =
                      nvl(cur_category.segment2, 'null') AND
                      nvl(xcc.segment3, 'null') =
                      nvl(cur_category.segment3, 'null');
                      /* AND
                      nvl(xcc.segment4, 'null') =
                      nvl(cur_category.segment4, 'null') AND
                      nvl(xcc.segment5, 'null') =
                      nvl(cur_category.segment5, 'null') AND
                      nvl(xcc.segment6, 'null') =
                      nvl(cur_category.segment6, 'null') AND
                      nvl(xcc.segment7, 'null') =
                      nvl(cur_category.segment7, 'null') AND
                      nvl(xcc.segment8, 'null') =
                      nvl(cur_category.segment8, 'null');*/
            
               IF MOD(v_counter, 100) = 0 THEN
                  COMMIT;
               END IF;
            
            EXCEPTION
               WHEN OTHERS THEN               
                  v_trans_to_int_error:=v_trans_to_int_error||'; '||SQLERRM;
                  ------DBMS_OUTPUT.put_line('Error when processing category='''||v_conc_categ_code||''': '||sqlerrm); 
                  UPDATE xxobjt_conv_category xcc
                     SET xcc.trans_to_int_code  = 'E',
                         xcc.trans_to_int_error = substr(v_trans_to_int_error,1,250)
                   WHERE xcc.structure_code = cur_category.structure_code AND
                         nvl(xcc.segment1, 'null') =
                         nvl(cur_category.segment1, 'null') AND
                         nvl(xcc.segment2, 'null') =
                         nvl(cur_category.segment2, 'null') AND
                         nvl(xcc.segment3, 'null') =
                         nvl(cur_category.segment3, 'null');
                          /*AND
                         nvl(xcc.segment4, 'null') =
                         nvl(cur_category.segment4, 'null') AND
                         nvl(xcc.segment5, 'null') =
                         nvl(cur_category.segment5, 'null') AND
                         nvl(xcc.segment6, 'null') =
                         nvl(cur_category.segment6, 'null') AND
                         nvl(xcc.segment7, 'null') =
                         nvl(cur_category.segment7, 'null') AND
                         nvl(xcc.segment8, 'null') =
                         nvl(cur_category.segment8, 'null');*/
               
            END;
         
         END LOOP;      
         COMMIT;      
      END LOOP;
      COMMIT;
      ---DBMS_OUTPUT.put_line(''); ---empty line
      ---DBMS_OUTPUT.put_line(''); ---empty line
      DBMS_OUTPUT.put_line('***** Category Conversion RESULTS **************');
      if v_categories_success>0 then
          DBMS_OUTPUT.put_line(v_categories_success||' categories are created successfuly'); 
      end if;
      if v_categories_failured>0 then
          DBMS_OUTPUT.put_line(v_categories_failured||' categories creation failure'); 
      end if;
      if v_categories_already_exist>0 then
          DBMS_OUTPUT.put_line(v_categories_already_exist||' categories already exist'); 
      end if;
      
EXCEPTION
  when others then
    DBMS_OUTPUT.put_line('=======UNEXPECTED ERROR in xxconv_categories_pkg.handle_ssys_categories procedure: '||v_step||' '||sqlerrm);   
    errbuf :='UNEXPECTED ERROR in xxconv_categories_pkg.handle_ssys_categories procedure: '||v_step||' '||sqlerrm;
    retcode:='2'; 
END handle_ssys_categories;
-------------------------------------------------------------------------------------------------
END xxconv_categories_pkg;
/
