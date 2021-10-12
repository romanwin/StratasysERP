CREATE OR REPLACE PACKAGE BODY xxs3_ptm_item_master_extrt_pkg AS
  ----------------------------------------------------------------------------
  --  Name:            xxs3_ptm_item_master_extrt_pkg
  --  Create by:       V.V.SATEESH
  --  Revision:        1.0
  --  Creation date:  30/11/2016
  ----------------------------------------------------------------------------
  --  Purpose :        Package to Explode BOM and Item Revisions
  --                   from Legacy system
  --                   1.Exploding the Assembly Items and it's Components using BOM API.
  --                   2.Insert Item Revisions in the Stage table
  ----------------------------------------------------------------------------
  --  Ver  Date        Name                         Description
  --  1.0 17/08/2016  V.V.SATEESH                   Initial build
  ----------------------------------------------------------------------------

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will explode BOM and insert into stage tables
  --           staging table xxobjt.xxs3_ptm_bom_item_expl_temp , xxs3_ptm_bom_cmpnt_item_stg
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  17/08/2016   V.V.SATEESH            Initial build
  -- --------------------------------------------------------------------------------------------
   g_delimiter     VARCHAR2(5) := '~';
  PROCEDURE items_bom_explode_prc(x_errbuf  OUT VARCHAR2,
                                  x_retcode OUT NUMBER) IS
  
    l_group_id      NUMBER;
    l_error_message VARCHAR2(2000);
    l_error_code    NUMBER;
    l_sess_id       NUMBER;
    l_rec_count     NUMBER;
    l_err_count     NUMBER;
  
    --Cursor for the BOM Explosion
    CURSOR c_bom IS
      SELECT xpm.xx_inventory_item_id,
             xpm.l_inventory_item_id,
             xpm.legacy_organization_id
        FROM xxs3_ptm_master_items_ext_stg xpm
       WHERE xpm.extract_rule_name IS NOT NULL
         AND xpm.assembly_item = 'Y' ;
  
    TYPE l_cs_bom IS TABLE OF c_bom%ROWTYPE INDEX BY BINARY_INTEGER;
    l_bom_rec l_cs_bom;
  
  BEGIN
    --Deleting the records before insert
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_ptm_bom_item_expl_temp';
  
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_ptm_bom_cmpnt_item_stg';
  
    fnd_file.put_line(fnd_file.log,
                      'Inside procedure item_bom_explode_prc ' ||
                      TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
  
    OPEN c_bom;
    --FOR cur_ib_rel_rec IN cur_ib_rel
    LOOP
      FETCH c_bom BULK COLLECT
        INTO l_bom_rec LIMIT 1000;
    
      fnd_file.put_line(fnd_file.log,
                        'Inside l_bom_rec ' ||
                        TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
    
      FOR i IN l_bom_rec.first .. l_bom_rec.last LOOP
      
        SELECT bom_explosion_temp_s.NEXTVAL INTO l_group_id FROM dual;
      
        SELECT bom_explosion_temp_session_s.NEXTVAL
          INTO l_sess_id
          FROM dual;
      
        fnd_file.put_line(fnd_file.log,
                          'Before API Call:' || 'Inventory id' ||
                           l_bom_rec(i).l_inventory_item_id || 'and' ||
                           'org id' || l_bom_rec(i)
                          .legacy_organization_id ||
                           TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
        --API used for the BOM Explosion for the given item
      
        bompxinq.exploder_userexit(verify_flag       => 0,
                                   org_id            => l_bom_rec(i)
                                                       .legacy_organization_id, --p_org_id,
                                   order_by          => 1, --:B_Bill_Of_Matls.Bom_Bill_Sort_Order_Type,
                                   grp_id            => l_group_id,
                                   session_id        => 0,
                                   levels_to_explode => 20, --:B_Bill_Of_Matls.Levels_To_Explode,
                                   bom_or_eng        => 1, -- :Parameter.Bom_Or_Eng,
                                   impl_flag         => 1, --:B_Bill_Of_Matls.Impl_Only,
                                   plan_factor_flag  => 2, --:B_Bill_Of_Matls.Planning_Percent,
                                   explode_option    => 3, --:B_Bill_Of_Matls.Bom_Inquiry_Display_Type,
                                   module            => 2, --:B_Bill_Of_Matls.Costs,
                                   cst_type_id       => 0, --:B_Bill_Of_Matls.Cost_Type_Id,
                                   std_comp_flag     => 2,
                                   expl_qty          => 1, --:B_Bill_Of_Matls.Explosion_Quantity,
                                   item_id           => l_bom_rec(i)
                                                       .l_inventory_item_id, --p_item_id, --:B_Bill_Of_Matls.Assembly_Item_Id,
                                   alt_desg          => NULL, --:B_Bill_Of_Matls.Alternate_Bom_Designator,
                                   comp_code         => NULL,
                                   unit_number_from  => 0, --NVL(:B_Bill_Of_Matls.Unit_Number_From, :CONTEXT.UNIT_NUMBER_FROM),
                                   unit_number_to    => 'ZZZZZZZZZZZZZZZZZ', --NVL(:B_Bill_Of_Matls.Unit_Number_To, :CONTEXT.UNIT_NUMBER_TO),
                                   rev_date          => SYSDATE, --:B_Bill_Of_Matls.Disp_Date,
                                   show_rev          => 1, -- yes
                                   material_ctrl     => 2, --:B_Bill_Of_Matls.Material_Control,
                                   lead_time         => 2, --:B_Bill_Of_Matls.Lead_Time,
                                   err_msg           => l_error_message, --err_msg
                                   ERROR_CODE        => l_error_code);
      
        /* Insert the Records into custom table(XXS3_PTM_BOM_ITEM_EXPL_TEMP) from the Oracle Temp table (BOM_SMALL_EXPL_TEMP) */
        fnd_file.put_line(fnd_file.log,
                          'After BOM API END and before insert stage ' ||
                          TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
      
        INSERT INTO xxobjt.xxs3_ptm_bom_item_expl_temp
          SELECT bse.*, null xx_inventory_item_id
            FROM bom_small_expl_temp bse --  use BOM_explosion_temp
           WHERE top_item_id = l_bom_rec(i).l_inventory_item_id;
      
        fnd_file.put_line(fnd_file.log,
                          'After Insert into stage table ' ||
                          TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
      END LOOP;
      fnd_file.put_line(fnd_file.log,
                        'End of bom loop ' ||
                        TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
      EXIT WHEN c_bom%NOTFOUND;
    END LOOP;
    fnd_file.put_line(fnd_file.log,
                      'End of cursor loop ' ||
                      TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
    CLOSE c_bom;
    COMMIT;
    fnd_file.put_line(fnd_file.log,
                      'End of procedure item_bom_explode_prc' ||
                      TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
  
    --
    BEGIN
    
      fnd_file.put_line(fnd_file.log,
                        'Begin xxs3_ptm_master_items_ext_stg BOM Extract Rule Nam Update' ||
                        TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
    
      UPDATE xxs3_ptm_master_items_ext_stg xpmi
         SET xpmi.extract_rule_name = CASE WHEN extract_rule_name = NULL
                                      THEN 'BOM-ORG_ID:' || xpmi.legacy_organization_id 
                                      ELSE extract_rule_name || '|' || 'BOM-ORG_ID:' || xpmi.legacy_organization_id 
                                      END
       WHERE EXISTS
       (SELECT component_item_id
                FROM xxobjt.xxs3_ptm_bom_item_expl_temp xpbc
               WHERE xpbc.component_item_id = xpmi.l_inventory_item_id
                 AND xpmi.legacy_organization_id = xpbc.organization_id);
    
      COMMIT;
      fnd_file.put_line(fnd_file.log,
                        'END xxs3_ptm_master_items_ext_stg BOM Extract Rule Nam Update' ||
                        TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
    EXCEPTION
      WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log,
                          'Error in xxs3_ptm_master_items_ext_stg BOM Extract Rule Nam Update' ||
                          SQLERRM);
    END;
   /* --Calling Revisons Procedure
    BEGIN
      fnd_file.put_line(fnd_file.log,
                        'Begin item_revision_extract_prc procedure call' ||
                        TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
      items_revision_extract_prc;
      fnd_file.put_line(fnd_file.log,
                        'END item_revision_extract_prc procedure call' ||
                        TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
    END;*/
  
  EXCEPTION
    WHEN no_data_found THEN
      fnd_file.put_line(fnd_file.log,
                        'Error in "item_bom_explode_prc" Procedure' ||
                        SQLERRM);
    
  END items_bom_explode_prc;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will work for the Insert Revisions for Items
  --  insert into staging table xxs3_ptm_item_master_rev_stg
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date         Name                          Description
  -- 1.0  17/08/2016   V.V.SATEESH            Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE items_revision_extract_prc IS
    --Cursor for OMA Items
    CURSOR c_main_stg IS
      SELECT l_inventory_item_id, legacy_organization_code
        FROM xxs3_ptm_master_items_ext_stg xpm
       WHERE extract_rule_name IS NOT NULL
         AND legacy_organization_code = 'OMA';
  
    --Cursor for Item Revisions  
    CURSOR c_rev(p_inventory_item_id NUMBER, p_organization_code VARCHAR2) IS
    
      SELECT mir.inventory_item_id,
             segment1,
             mir.revision_id,
             mir.revision,
             mir.revision_label,
             mir.description revision_description,
             mir.effectivity_date,
             mir.implementation_date,
             mir.ecn_initiation_date,
             mir.change_notice,
             mir.attribute10 r_attribute10,
             mir.revised_item_sequence_id,
             mirt.revision_id tl_revision_id,
             mirt.LANGUAGE LANGUAGE,
             mirt.source_lang,
             mirt.description tl_description,
             mp.organization_code,
             mir.organization_id
        FROM mtl_item_revisions_b  mir,
             mtl_item_revisions_tl mirt,
             mtl_system_items_b    msi,
             mtl_parameters        mp
       WHERE mirt.revision_id = mir.revision_id
         AND mir.organization_id = mirt.organization_id
         AND msi.inventory_item_id = mir.inventory_item_id
         AND msi.organization_id = mir.organization_id
         AND mir.inventory_item_id = p_inventory_item_id
         AND mp.organization_code = p_organization_code
         AND mir.organization_id = mp.organization_id
         AND mirt.LANGUAGE = 'US'
         AND mirt.source_lang = 'US';
  
  BEGIN
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_ptm_item_master_rev_stg';
    --Inserting Revisions in the Revision Table
    FOR i IN c_main_stg LOOP
      FOR r_rev IN c_rev(i.l_inventory_item_id, i.legacy_organization_code) LOOP
        INSERT INTO xxobjt.xxs3_ptm_item_master_rev_stg
          (xx_inventory_item_id,
           inventory_item_id,
           item,
           legacy_revision_id,
           xxs3_revision_id,
           revision,
           revision_label,
           revision_description,
           effectivity_date,
           implementation_date,
           ecn_initiation_date,
           change_notice,
           revision_attribute10,
           revised_item_sequence_id,
           s3_revised_item_sequence_id,
           revision_language,
           source_lang,
           revision_tl_description,
           last_update_date,
           organization_id,
           organization_code,
           last_updated_by,
           orig_system_reference,
           date_extracted_on,
           process_flag,
           transaction_type,
           set_process_id)
        VALUES
          (xxs3_ptm_item_master_rev_seq.NEXTVAL,
           r_rev.inventory_item_id,
           r_rev.segment1,
           r_rev.revision_id,
           NULL,
           r_rev.revision,
           r_rev.revision_label,
           r_rev.revision_description,
           r_rev.effectivity_date,
           r_rev.implementation_date,
           r_rev.ecn_initiation_date,
           r_rev.change_notice,
           r_rev.r_attribute10,
           r_rev.revised_item_sequence_id,
           NULL,
           r_rev.LANGUAGE,
           r_rev.source_lang,
           r_rev.tl_description,
           SYSDATE,
           r_rev.organization_id,
           r_rev.organization_code,
           NULL,
           NULL,
           SYSDATE,
           'N',
           NULL,
           NULL);
      END LOOP;
    END LOOP;
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log,
                        'Error message in Revisions Insertion ' || SQLERRM);
  END items_revision_extract_prc;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This function will work for the Return ORG/MASTER control Attributes
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date         Name                          Description
  -- 1.0  17/08/2016   V.V.SATEESH            Initial build
  -- --------------------------------------------------------------------------------------------
  FUNCTION get_org_master_cntrl_fn(p_attribue_name IN VARCHAR2)
    RETURN VARCHAR2 IS
  
    l_org_mstr_value VARCHAR2(50);
  BEGIN
    SELECT meaning
      INTO l_org_mstr_value
      FROM mfg_lookups mfg2, mtl_item_attributes mia
     WHERE mfg2.lookup_type = 'ITEM_CONTROL_LEVEL_GUI'
       AND mfg2.lookup_code = mia.control_level
       AND mia.attribute_name = 'MTL_SYSTEM_ITEMS.' || p_attribue_name;
  
    RETURN l_org_mstr_value;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      l_org_mstr_value := NULL;
      fnd_file.put_line(fnd_file.log,
                        'NO DATA FOUND in get_org_master_cntrl_fn function' ||
                        SQLERRM);
    WHEN OTHERS THEN
      l_org_mstr_value := NULL;
      fnd_file.put_line(fnd_file.log,
                        'Error in get_org_master_cntrl_fn function' ||
                        SQLERRM);
  END get_org_master_cntrl_fn;
  
  -- --------------------------------------------------------------------------------------------
  -- Purpose: This function will work for the Return Cleanse Vlaue of Buyer ID Attributes
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date         Name                          Description
  -- 1.0  17/08/2016   V.V.SATEESH            Initial build
  -- --------------------------------------------------------------------------------------------
 FUNCTION cleanse_buyer_id(p_xx_inventory_item_id IN number, p_organization_code IN VARCHAR2) 
 RETURN VARCHAR2 IS

l_buyer_value VARCHAR2(50);
l_count_fdm NUMBER;
l_count_poly NUMBER;
l_count_mat NUMBER;
l_buyer_id_val VARCHAR2(100);
l_buyer_id VARCHAR2(100);
l_error_msg VARCHAR2(4000);

BEGIN

  IF p_organization_code = 'OMA' THEN

    SELECT COUNT(DISTINCT inventory_item_id)
      INTO l_count_fdm
      FROM mtl_item_categories_v mic, mtl_parameters mp
     WHERE mic.inventory_item_id = p_xx_inventory_item_id
       AND mic.organization_id = mp.organization_id
       AND mp.organization_code= p_organization_code
       AND segment6 = 'FDM';

    -- Query for get count of the PRODUCT_HIERARCHY.SEGMENT6='POLYJET' items

    SELECT COUNT(DISTINCT inventory_item_id)
      INTO l_count_poly
      FROM mtl_item_categories_v mic, mtl_parameters mp
     WHERE mic.inventory_item_id = p_xx_inventory_item_id
       AND mic.organization_id = mp.organization_id
       AND mp.organization_code= p_organization_code
       AND segment6 = 'POLYJET';

    -- Query for get count of the PRODUCT_HIERARCHY.SEGMENT1='Materials' items

    SELECT COUNT(DISTINCT inventory_item_id)
      INTO l_count_mat
      FROM mtl_item_categories_v mic, mtl_parameters mp
     WHERE mic.inventory_item_id = p_xx_inventory_item_id
       AND mic.organization_id = mp.organization_id
       AND mp.organization_code= p_organization_code
       AND segment1 = 'Materials';

    IF l_count_fdm > 0 THEN

      --Query for get Buyer id if the PRODUCT_HIERARCHY.SEGMENT6='FDM' items and org='UME'
     
      SELECT buyer_id
        INTO l_buyer_id
        FROM mtl_parameters mp, mtl_system_items_b msi
       WHERE msi.inventory_item_id = p_xx_inventory_item_id
         AND msi.organization_id = mp.organization_id
         AND mp.organization_code = 'UME';

      l_buyer_id_val := l_buyer_id;
      
      SELECT papf.employee_number
        INTO l_buyer_value
        FROM per_all_people_f papf
       WHERE papf.person_id = l_buyer_id_val
         AND TRUNC(sysdate) between
             TRUNC(nvl(papf.effective_start_date, sysdate)) AND
             TRUNC(NVL(papf.effective_end_date, sysdate));

       RETURN l_buyer_value;
       

    ELSIF l_count_poly > 0 THEN
      IF l_count_mat > 0 THEN

        SELECT buyer_id
          INTO l_buyer_id
          FROM mtl_parameters mp, mtl_system_items_b msi
         WHERE msi.inventory_item_id = p_xx_inventory_item_id
           AND msi.organization_id = mp.organization_id
           AND mp.organization_code = 'IRK';

        l_buyer_id_val := l_buyer_id;

        SELECT papf.employee_number
          INTO l_buyer_value
          FROM per_all_people_f papf
         WHERE papf.person_id = l_buyer_id_val
           AND TRUNC(sysdate) between
               TRUNC(nvl(papf.effective_start_date, sysdate)) AND
               TRUNC(NVL(papf.effective_end_date, sysdate));

         RETURN l_buyer_value;
         
        ELSE
          SELECT buyer_id
            INTO l_buyer_id
            FROM mtl_parameters mp, mtl_system_items_b msi
           WHERE msi.inventory_item_id = p_xx_inventory_item_id
             AND msi.organization_id = mp.organization_id
             AND mp.organization_code = 'IPK';
             
               l_buyer_id_val := l_buyer_id;
               
             IF  l_buyer_id_val IS NULL THEN 
             SELECT buyer_id
            INTO l_buyer_id
            FROM mtl_parameters mp, mtl_system_items_b msi
           WHERE msi.inventory_item_id = p_xx_inventory_item_id
             AND msi.organization_id = mp.organization_id
             AND mp.organization_code = 'IRK';
             
               l_buyer_id_val := l_buyer_id;
               
                SELECT papf.employee_number
          INTO l_buyer_value
          FROM per_all_people_f papf
         WHERE papf.person_id = l_buyer_id_val
           AND TRUNC(sysdate) between
               TRUNC(nvl(papf.effective_start_date, sysdate)) AND
               TRUNC(NVL(papf.effective_end_date, sysdate));
             
               RETURN l_buyer_value;
             END IF;

        SELECT papf.employee_number
          INTO l_buyer_value
          FROM per_all_people_f papf
         WHERE papf.person_id = l_buyer_id_val
           AND TRUNC(sysdate) between
               TRUNC(nvl(papf.effective_start_date, sysdate)) AND
               TRUNC(NVL(papf.effective_end_date, sysdate));
             
               RETURN l_buyer_value;
      END IF;
    ELSE
      SELECT buyer_id
        INTO l_buyer_id
        FROM mtl_parameters mp, mtl_system_items_b msi
       WHERE msi.inventory_item_id = p_xx_inventory_item_id
         AND msi.organization_id = mp.organization_id
         AND mp.organization_code ='UME' ;

      l_buyer_id_val := l_buyer_id;
        IF l_buyer_id_val IS NULL THEN
         SELECT buyer_id
        INTO l_buyer_id
        FROM mtl_parameters mp, mtl_system_items_b msi
       WHERE msi.inventory_item_id = p_xx_inventory_item_id
         AND msi.organization_id = mp.organization_id
         AND mp.organization_code = 'IPK';
         
          SELECT papf.employee_number
        INTO l_buyer_value
        FROM per_all_people_f papf
       WHERE papf.person_id = l_buyer_id_val
         AND TRUNC(sysdate) between
             TRUNC(nvl(papf.effective_start_date, sysdate)) AND
             TRUNC(NVL(papf.effective_end_date, sysdate));

      RETURN l_buyer_value;
        END IF;

      SELECT papf.employee_number
        INTO l_buyer_value
        FROM per_all_people_f papf
       WHERE papf.person_id = l_buyer_id_val
         AND TRUNC(sysdate) between
             TRUNC(nvl(papf.effective_start_date, sysdate)) AND
             TRUNC(NVL(papf.effective_end_date, sysdate));

      RETURN l_buyer_value;
    END IF;
      RETURN l_buyer_value;
  END IF;
  fnd_file.put_line(fnd_file.log,
                    'end cleanse buyer_id function' || systimestamp);

EXCEPTION
  WHEN no_data_found THEN         
                  
   l_buyer_value := NULL;
   
    RETURN l_buyer_value;

  WHEN OTHERS THEN
  l_buyer_value := NULL;
    RETURN l_buyer_value;
    l_error_msg := 'Invalid Buyer ID Found : ' || SQLERRM;
    fnd_file.put_line(fnd_file.log, l_error_msg);

    UPDATE xxobjt.xxs3_ptm_master_items_ext_stg
       SET cleanse_status = 'FAIL',
           cleanse_error  = transform_error || ',' || l_error_msg
     WHERE l_inventory_item_id = p_xx_inventory_item_id;

    
END cleanse_buyer_id;
 -- --------------------------------------------------------------------------------------------
  -- Purpose: This function will work for the Return Cleanse Vlaue of Buyer ID Attributes
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date         Name                          Description
  -- 1.0  17/08/2016   V.V.SATEESH            Initial build
  -- --------------------------------------------------------------------------------------------
FUNCTION cleanse_planner_code(p_xx_inventory_item_id IN number,
                              p_organization_code    IN VARCHAR2)
  RETURN VARCHAR2 IS

  l_planner_value VARCHAR2(50);
  l_count_fdm     NUMBER;
  l_count_poly    NUMBER;
  l_count_mat     NUMBER;
  l_planner_val   VARCHAR2(100);
  l_error_msg     VARCHAR2(4000);

BEGIN

  IF p_organization_code = 'OMA' THEN
  
    SELECT COUNT(DISTINCT inventory_item_id)
      INTO l_count_fdm
      FROM mtl_item_categories_v mic, mtl_parameters mp
     WHERE mic.inventory_item_id = p_xx_inventory_item_id
       AND mic.organization_id = mp.organization_id
       AND mp.organization_code= p_organization_code
       AND segment6 = 'FDM';
  
    -- Query for get count of the PRODUCT_HIERARCHY.SEGMENT6='POLYJET' items
  
    SELECT COUNT(DISTINCT inventory_item_id)
      INTO l_count_poly
      FROM mtl_item_categories_v mic, mtl_parameters mp
     WHERE mic.inventory_item_id = p_xx_inventory_item_id
       AND mic.organization_id = mp.organization_id
       AND mp.organization_code= p_organization_code
       AND segment6 = 'POLYJET';
  
    -- Query for get count of the PRODUCT_HIERARCHY.SEGMENT1='Materials' items
  
    SELECT COUNT(DISTINCT inventory_item_id)
      INTO l_count_mat
      FROM mtl_item_categories_v mic, mtl_parameters mp
     WHERE mic.inventory_item_id = p_xx_inventory_item_id
       AND mic.organization_id = mp.organization_id
       AND mp.organization_code= p_organization_code
       AND segment1 = 'Materials';
  
    IF l_count_fdm > 0 THEN
    
      --Query for get Buyer id if the PRODUCT_HIERARCHY.SEGMENT6='FDM' items and org='UME'
    
      SELECT planner_code
        INTO l_planner_value
        FROM mtl_parameters mp, mtl_system_items_b msi
       WHERE msi.inventory_item_id = p_xx_inventory_item_id
         AND msi.organization_id = mp.organization_id
         AND mp.organization_code = 'UME';
    
      l_planner_val := l_planner_value;
    
      RETURN l_planner_val;
    
    ELSIF l_count_poly > 0 THEN
      IF l_count_mat > 0 THEN
      
        SELECT planner_code
          INTO l_planner_value
          FROM mtl_parameters mp, mtl_system_items_b msi
         WHERE msi.inventory_item_id = p_xx_inventory_item_id
           AND msi.organization_id = mp.organization_id
           AND mp.organization_code = 'IRK';
      
        l_planner_val := l_planner_value;
      
        RETURN l_planner_val;
      
      ELSE
        SELECT planner_code
          INTO l_planner_value
          FROM mtl_parameters mp, mtl_system_items_b msi
         WHERE msi.inventory_item_id = p_xx_inventory_item_id
           AND msi.organization_id = mp.organization_id
           AND mp.organization_code = 'IPK';
      
        l_planner_val := l_planner_value;
      
        IF l_planner_val IS NULL THEN
        
          SELECT planner_code
            INTO l_planner_value
            FROM mtl_parameters mp, mtl_system_items_b msi
           WHERE msi.inventory_item_id = p_xx_inventory_item_id
             AND msi.organization_id = mp.organization_id
             AND mp.organization_code = 'IRK';
        
          l_planner_val := l_planner_value;
        
          RETURN l_planner_val;
        END IF;
      
        RETURN l_planner_val;
      END IF;
    ELSE
      SELECT planner_code
        INTO l_planner_value
        FROM mtl_parameters mp, mtl_system_items_b msi
       WHERE msi.inventory_item_id = p_xx_inventory_item_id
         AND msi.organization_id = mp.organization_id
         AND mp.organization_code = 'UME';
    
      l_planner_val := l_planner_value;
    
      IF l_planner_val IS NULL THEN
        SELECT planner_code
          INTO l_planner_value
          FROM mtl_parameters mp, mtl_system_items_b msi
         WHERE msi.inventory_item_id = p_xx_inventory_item_id
           AND msi.organization_id = mp.organization_id
           AND mp.organization_code = 'IPK';
      
        RETURN l_planner_val;
      END IF;
    
      RETURN l_planner_val;
    END IF;
    RETURN l_planner_val;
  END IF;
  fnd_file.put_line(fnd_file.log,
                    'end Cleanse Planner Code function' || systimestamp);

EXCEPTION
  WHEN no_data_found THEN
    l_planner_val := NULL;
    RETURN l_planner_val;
  
  WHEN OTHERS THEN
    l_planner_val := NULL;
    RETURN l_planner_val;
    l_error_msg := 'Invalid Planner Code Found : ' || SQLERRM;
    fnd_file.put_line(fnd_file.log, l_error_msg);
  
    UPDATE xxobjt.xxs3_ptm_master_items_ext_stg
       SET cleanse_status = 'FAIL',
           cleanse_error  = transform_error || ',' || l_error_msg
     WHERE l_inventory_item_id = p_xx_inventory_item_id;
  
    COMMIT;
END cleanse_planner_code;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Report for Cleanse details
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date         Name                          Description
  -- 1.0  12/07/2016   V.V.Sateesh                   Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE data_cleanse_report(p_entity IN VARCHAR2) IS
  
    --Variables
    l_count_success NUMBER;
    l_count_fail    NUMBER;
  
    --Cursor for generate Cleanse Report
  
    CURSOR c_report_cleanse IS
    
 SELECT
 xpm.xx_inventory_item_id        
,xpm.l_inventory_item_id              -- Inventory ID
,xpm.s3_inventory_item_id             -- S3 Inventory Item Id
,xpm.segment1                         -- Item
,xpm.legacy_organization_code         -- Legacy Organization Code
,xpm.s3_organization_code             -- S3 Organization Code
,xpm.legacy_buyer_id                  -- Buyer ID
,xpm.s3_buyer_number				  -- S3 Buyer Number
,xpm.accounting_rule_id               -- Accounting Rule Id
,xpm.legacy_accounting_rule_name      -- Legacy Accounting Rule Name 
,xpm.s3_accounting_rule_name          -- S3 Accounting Rule Name
,xpm.item_catalog_group_id			  -- Item Catalog Group Id
,xpm.s3_item_catalog_group_id		  -- S3 Item Catalog Group Id
,xpm.receipt_required_flag			  -- Receipt Required Flag	
,xpm.s3_receipt_required_flag         -- S3 Rreceipt Required Flag
,xpm.list_price_per_unit			  -- List Price Per Unit	
,xpm.s3_list_price_per_unit           -- S3 List Price Per Unit		
,xpm.receiving_routing_id			  -- Receiving Routing Id
,xpm.s3_receiving_routing_id		  -- S3 Receiving Routing Id
,xpm.s3_serial_number_control_code    -- S3 Serial Number Control Code
,xpm.source_type					  -- Source Type
,xpm.s3_source_type                   -- S3 Source Type
,xpm.source_subinventory			  -- Source Subinventory
,xpm.s3_source_subinventory           -- S3 Source Subinventory
,xpm.restrict_subinventories_code     -- Restrict Subinventories Code
,xpm.s3_restrict_subinvens_code       -- S3 Restrict Subinvens Code
,xpm.atp_flag						  -- Atp Flag
,xpm.s3_atp_flag                      -- S3 Atp Flag			
,xpm.wip_supply_subinventory          -- Wip Supply Subinventory
,xpm.s3_wip_supply_subinventory       -- S3 Wip Supply Subinventory
,xpm.secondary_uom_code				  -- Secondary Uom Code	
,xpm.s3_secondary_uom_code			  -- S3 Secondary Uom Code	
,xpm.inventory_item_status_code       -- Inventory Item Status Code
,xpm.s3_inventory_item_status_code	  -- S3 Inventory Item Status Code		
,xpm.planner_code					  -- Planner Code	 
,xpm.s3_planner_code				  -- S3 Planner Code
,xpm.fixed_lot_multiplier			  -- Fixed Lot Multiplier
,xpm.s3_fixed_lot_multiplier          -- S3 Fixed Lot Multiplier
,xpm.postprocessing_lead_time		  -- Postprocessing Lead Time	
,xpm.s3_postprocessing_lead_time      -- S3 Postprocessing Lead Time
,xpm.preprocessing_lead_time          -- Preprocessing Lead Time
,xpm.s3_preprocessing_lead_time       -- S3 Preprocessing Lead Time
,xpm.full_lead_time					  -- Full Lead Time	
,xpm.s3_full_lead_time                -- S3 Full Lead Time
,xpm.min_minmax_quantity			  -- Min Minmax Quantity
,xpm.s3_min_minmax_quantity           -- S3 Min Minmax Quantity	
,xpm.max_minmax_quantity			  -- Max Minmax Quantity
,xpm.s3_max_minmax_quantity           -- S3 Max Minmax Quantity
,xpm.minimum_order_quantity			  -- Minimum Order Quantity
,xpm.s3_minimum_order_quantity        -- S3 Minimum Order Quantity
,xpm.fixed_order_quantity			  -- Fixed Order Quantity
,xpm.s3_fixed_order_quantity          -- S3 Fixed Order Quantity
,xpm.fixed_days_supply				  -- Fixed Days Supply
,xpm.s3_fixed_days_supply             -- S3 Fixed Days Supply
,xpm.maximum_order_quantity			  -- Maximum Order Quantity	
,xpm.s3_maximum_order_quantity        -- S3 maximum Order Quantity
,xpm.atp_rule_name					  -- Atp Rule Name	
,xpm.s3_atp_rule_name				  -- S3 Atp Rule Name	
,xpm.reservable_type				  -- Reservable Type		
,xpm.s3_reservable_type               -- S3 Reservable Type		      
,xpm.cycle_count_enabled_flag		  -- Cycle Count Enabled Flag
,xpm.s3_cycle_count_enabled_flag      -- S3 Cycle Count Enabled Flag
,xpm.ship_model_complete_flag		  -- Ship Model Complete Flag
,xpm.s3_ship_model_complete_flag      -- S3 Ship Model Complete Flag
,xpm.mrp_planning_code				  -- Mrp Planning Code	
,xpm.s3_mrp_planning_code             -- S3 Mrp Planning Code			
,xpm.ato_forecast_control			  -- Ato Forecast Control		
,xpm.s3_ato_forecast_control          -- S3 Ato Forecast Control	
,xpm.release_time_fence_code          -- Release Time Fence Code
,xpm.s3_release_time_fence_code       -- S3 Release Time Fence Fode
,xpm.contract_item_type_code          -- Contract Item Type Code
,xpm.s3_contract_item_type_code       -- S3 Contract Item Type Code
,xpm.serv_req_enabled_code            -- Serv Req Enabled Code
,xpm.s3_serv_req_enabled_code         -- S3 Serv Req Enabled Code
,xpm.tracking_quantity_ind            -- Tracking Quantity Ind
,xpm.s3_tracking_quantity_ind         -- S3 Tracking Quantity Ind
,xpm.secondary_default_ind            -- Secondary Default Ind
,xpm.s3_secondary_default_ind         -- S3_secondary_default_ind
,xpm.ont_pricing_qty_source           -- Ont_pricing_qty_source
,xpm.s3_ont_pricing_qty_source        -- S3_ont_pricing_qty_source
,xpm.attribute25                      -- Attribute25
,xpm.s3_attribute25                   -- S3_attribute25
,xpm.expiration_action_code           -- Expiration_action_code
,xpm.s3_expiration_action_code        -- S3 Expiration Action Code
,xpm.expiration_action_interval       -- Expiration Action Interval
,xpm.s3_expiration_action_interval    -- S3 Expiration Action Interval
,xpm.revision_qty_control_code        -- Revision Qty Control Code
,xpm.s3_revision_qty_control_code     -- S3 Revision Qty Control Code
,xpm.attribute30                      -- Attribute30
,xpm.s3_attribute30                   -- S3 Attribute30
,xpm.date_extracted_on                -- Date Extracted On
,xpm.process_flag                     -- Process Flag
,xpm.cleanse_status                   -- Cleanse Status
,xpm.cleanse_error                    -- Cleanse Error
FROM xxs3_ptm_master_items_ext_stg xpm 
WHERE  xpm.extract_rule_name IS NOT NULL
AND   cleanse_status IN ('PASS', 'FAIL');
  
  BEGIN
    fnd_file.put_line(fnd_file.output
                     ,'Begin data_cleanse_report procedure' ||
                      systimestamp);
  
    IF p_entity = 'ITEM'
    THEN
    
      -- Count of the the Cleanse Success records
    
      SELECT COUNT(1)
      INTO l_count_success
      FROM xxobjt.xxs3_ptm_master_items_ext_stg
      WHERE cleanse_status = 'PASS';
    
      --Count of the the Cleanse Failed records
    
      SELECT COUNT(1)
      INTO l_count_fail
      FROM xxobjt.xxs3_ptm_master_items_ext_stg
      WHERE cleanse_status = 'FAIL';
    
    
      fnd_file.put_line(fnd_file.output,'Report name = Automated Cleanse & Standardize Report');
      fnd_file.put_line(fnd_file.output
                     ,'====================================================');
      fnd_file.put_line(fnd_file.output
                     ,'Data Migration Object Name = ' || 'ITEM MASTER');
      fnd_file.put_line(fnd_file.output
                     ,'Run date and time: ' ||
            to_char(SYSDATE
                   ,'dd-Mon-YYYY HH24:MI'));
      fnd_file.put_line(fnd_file.output
                     ,'Total Record Count Success = ' || l_count_success);
      fnd_file.put_line(fnd_file.output
                     ,'Total Record Count Failure = ' || l_count_fail);
      fnd_file.put_line(fnd_file.output
                     ,'');
    
    
fnd_file.put_line(fnd_file.output,
rpad('Track Name',10,' ') || g_delimiter ||
 rpad('Entity Name',11,' ') || g_delimiter ||
 rpad('XX_INVENTORY_ITEM_ID        ',20,' ')||g_delimiter||
rpad('L_INVENTORY_ITEM_ID           ',20,' ')||g_delimiter|| 
rpad('S3_INVENTORY_ITEM_ID          ',20,' ')||g_delimiter|| 
rpad('SEGMENT1                      ',20,' ')||g_delimiter|| 
rpad('LEGACY_ORGANIZATION_CODE      ',20,' ')||g_delimiter|| 
rpad('S3_ORGANIZATION_CODE          ',20,' ')||g_delimiter|| 
rpad('LEGACY_BUYER_ID               ',20,' ')||g_delimiter|| 
rpad('S3_BUYER_NUMBER				',20,' ')||g_delimiter||
rpad('ACCOUNTING_RULE_ID            ',20,' ')||g_delimiter|| 
rpad('LEGACY_ACCOUNTING_RULE_NAME   ',20,' ')||g_delimiter|| 
rpad('S3_ACCOUNTING_RULE_NAME       ',20,' ')||g_delimiter|| 
rpad('ITEM_CATALOG_GROUP_ID			',20,' ')||g_delimiter||
rpad('S3_ITEM_CATALOG_GROUP_ID		',20,' ')||g_delimiter||
rpad('RECEIPT_REQUIRED_FLAG			',20,' ')||g_delimiter||
rpad('S3_RECEIPT_REQUIRED_FLAG      ',20,' ')||g_delimiter|| 
rpad('LIST_PRICE_PER_UNIT			',20,' ')||g_delimiter||
rpad('S3_LIST_PRICE_PER_UNIT        ',20,' ')||g_delimiter|| 
rpad('RECEIVING_ROUTING_ID			',20,' ')||g_delimiter||
rpad('S3_RECEIVING_ROUTING_ID		',20,' ')||g_delimiter||
rpad('S3_SERIAL_NUMBER_CONTROL_CODE ',20,' ')||g_delimiter|| 
rpad('SOURCE_TYPE					',20,' ')||g_delimiter||
rpad('S3_SOURCE_TYPE                ',20,' ')||g_delimiter|| 
rpad('SOURCE_SUBINVENTORY			',20,' ')||g_delimiter||
rpad('S3_SOURCE_SUBINVENTORY        ',20,' ')||g_delimiter|| 
rpad('RESTRICT_SUBINVENTORIES_CODE  ',20,' ')||g_delimiter|| 
rpad('S3_RESTRICT_SUBINVENS_CODE    ',20,' ')||g_delimiter|| 
rpad('ATP_FLAG						',20,' ')||g_delimiter||
rpad('S3_ATP_FLAG                   ',20,' ')||g_delimiter|| 
rpad('WIP_SUPPLY_SUBINVENTORY       ',20,' ')||g_delimiter|| 
rpad('S3_WIP_SUPPLY_SUBINVENTORY    ',20,' ')||g_delimiter|| 
rpad('SECONDARY_UOM_CODE			',20,' ')||g_delimiter||	
rpad('S3_SECONDARY_UOM_CODE			',20,' ')||g_delimiter||
rpad('INVENTORY_ITEM_STATUS_CODE    ',20,' ')||g_delimiter|| 
rpad('S3_INVENTORY_ITEM_STATUS_CODE	',20,' ')||g_delimiter||
rpad('PLANNER_CODE					',20,' ')||g_delimiter||
rpad('S3_PLANNER_CODE				',20,' ')||g_delimiter||
rpad('FIXED_LOT_MULTIPLIER			',20,' ')||g_delimiter||
rpad('S3_FIXED_LOT_MULTIPLIER       ',20,' ')||g_delimiter|| 
rpad('POSTPROCESSING_LEAD_TIME		',20,' ')||g_delimiter||
rpad('S3_POSTPROCESSING_LEAD_TIME   ',20,' ')||g_delimiter|| 
rpad('PREPROCESSING_LEAD_TIME       ',20,' ')||g_delimiter|| 
rpad('S3_PREPROCESSING_LEAD_TIME    ',20,' ')||g_delimiter|| 
rpad('FULL_LEAD_TIME				',20,' ')||g_delimiter||	
rpad('S3_FULL_LEAD_TIME             ',20,' ')||g_delimiter|| 
rpad('MIN_MINMAX_QUANTITY			',20,' ')||g_delimiter||
rpad('S3_MIN_MINMAX_QUANTITY        ',20,' ')||g_delimiter|| 
rpad('MAX_MINMAX_QUANTITY			',20,' ')||g_delimiter||
rpad('S3_MAX_MINMAX_QUANTITY        ',20,' ')||g_delimiter|| 
rpad('MINIMUM_ORDER_QUANTITY		',20,' ')||g_delimiter||	
rpad('S3_MINIMUM_ORDER_QUANTITY     ',20,' ')||g_delimiter|| 
rpad('FIXED_ORDER_QUANTITY			',20,' ')||g_delimiter||
rpad('S3_FIXED_ORDER_QUANTITY       ',20,' ')||g_delimiter|| 
rpad('FIXED_DAYS_SUPPLY				',20,' ')||g_delimiter||
rpad('S3_FIXED_DAYS_SUPPLY          ',20,' ')||g_delimiter|| 
rpad('MAXIMUM_ORDER_QUANTITY		',20,' ')||g_delimiter||	
rpad('S3_MAXIMUM_ORDER_QUANTITY     ',20,' ')||g_delimiter|| 
rpad('ATP_RULE_NAME					',20,' ')||g_delimiter||
rpad('S3_ATP_RULE_NAME				',20,' ')||g_delimiter||
rpad('RESERVABLE_TYPE				',20,' ')||g_delimiter||
rpad('S3_RESERVABLE_TYPE            ',20,' ')||g_delimiter|| 
rpad('CYCLE_COUNT_ENABLED_FLAG		',20,' ')||g_delimiter||
rpad('S3_CYCLE_COUNT_ENABLED_FLAG   ',20,' ')||g_delimiter|| 
rpad('SHIP_MODEL_COMPLETE_FLAG		',20,' ')||g_delimiter||
rpad('S3_SHIP_MODEL_COMPLETE_FLAG   ',20,' ')||g_delimiter|| 
rpad('MRP_PLANNING_CODE				',20,' ')||g_delimiter||
rpad('S3_MRP_PLANNING_CODE          ',20,' ')||g_delimiter|| 
rpad('ATO_FORECAST_CONTROL			',20,' ')||g_delimiter||
rpad('S3_ATO_FORECAST_CONTROL       ',20,' ')||g_delimiter|| 
rpad('RELEASE_TIME_FENCE_CODE       ',20,' ')||g_delimiter|| 
rpad('S3_RELEASE_TIME_FENCE_CODE    ',20,' ')||g_delimiter|| 
rpad('CONTRACT_ITEM_TYPE_CODE       ',20,' ')||g_delimiter|| 
rpad('S3_CONTRACT_ITEM_TYPE_CODE    ',20,' ')||g_delimiter|| 
rpad('SERV_REQ_ENABLED_CODE         ',20,' ')||g_delimiter|| 
rpad('S3_SERV_REQ_ENABLED_CODE      ',20,' ')||g_delimiter|| 
rpad('TRACKING_QUANTITY_IND         ',20,' ')||g_delimiter|| 
rpad('S3_TRACKING_QUANTITY_IND      ',20,' ')||g_delimiter|| 
rpad('SECONDARY_DEFAULT_IND         ',20,' ')||g_delimiter|| 
rpad('S3_SECONDARY_DEFAULT_IND      ',20,' ')||g_delimiter|| 
rpad('ONT_PRICING_QTY_SOURCE        ',20,' ')||g_delimiter|| 
rpad('S3_ONT_PRICING_QTY_SOURCE     ',20,' ')||g_delimiter|| 
rpad('ATTRIBUTE25                   ',20,' ')||g_delimiter|| 
rpad('S3_ATTRIBUTE25                ',20,' ')||g_delimiter|| 
rpad('EXPIRATION_ACTION_CODE        ',20,' ')||g_delimiter|| 
rpad('S3_EXPIRATION_ACTION_CODE     ',20,' ')||g_delimiter|| 
rpad('EXPIRATION_ACTION_INTERVAL    ',20,' ')||g_delimiter|| 
rpad('S3_EXPIRATION_ACTION_INTERVAL ',20,' ')||g_delimiter|| 
rpad('REVISION_QTY_CONTROL_CODE     ',20,' ')||g_delimiter|| 
rpad('S3_REVISION_QTY_CONTROL_CODE  ',20,' ')||g_delimiter|| 
rpad('ATTRIBUTE30                   ',20,' ')||g_delimiter|| 
rpad('S3_ATTRIBUTE30                ',20,' ')||g_delimiter|| 
rpad('DATE_EXTRACTED_ON             ',20,' ')||g_delimiter|| 
rpad('PROCESS_FLAG                  ',20,' ')||g_delimiter|| 
rpad('STATUS            ',20,' ')||g_delimiter|| 
rpad('ERROR MESSAGE                ',200,' '));
    
    
      FOR r_data IN c_report_cleanse
      LOOP
        fnd_file.put_line(fnd_file.output,rpad('PTM',10
                  ,' ') || g_delimiter ||
              rpad('ITEMS'
                  ,11
                  ,' ') || g_delimiter ||
                 rpad(nvl(to_char(r_data.xx_inventory_item_id        ),'NULL'),20,' ')||g_delimiter||
rpad(nvl(to_char(r_data.l_inventory_item_id           ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.s3_inventory_item_id          ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.segment1                      ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.legacy_organization_code      ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.s3_organization_code          ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.legacy_buyer_id               ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.s3_buyer_number				),'NULL'),20,' ')||g_delimiter||
rpad(nvl(to_char(r_data.accounting_rule_id            ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.legacy_accounting_rule_name   ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.s3_accounting_rule_name       ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.item_catalog_group_id			),'NULL'),20,' ')||g_delimiter||
rpad(nvl(to_char(r_data.s3_item_catalog_group_id		),'NULL'),20,' ')||g_delimiter||
rpad(nvl(to_char(r_data.receipt_required_flag			),'NULL'),20,' ')||g_delimiter||
rpad(nvl(to_char(r_data.s3_receipt_required_flag      ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.list_price_per_unit			),'NULL'),20,' ')||g_delimiter||
rpad(nvl(to_char(r_data.s3_list_price_per_unit        ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.receiving_routing_id			),'NULL'),20,' ')||g_delimiter||
rpad(nvl(to_char(r_data.s3_receiving_routing_id		),'NULL'),20,' ')||g_delimiter||
rpad(nvl(to_char(r_data.s3_serial_number_control_code ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.source_type					),'NULL'),20,' ')||g_delimiter||
rpad(nvl(to_char(r_data.s3_source_type                ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.source_subinventory			),'NULL'),20,' ')||g_delimiter||
rpad(nvl(to_char(r_data.s3_source_subinventory        ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.restrict_subinventories_code  ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.s3_restrict_subinvens_code    ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.atp_flag						),'NULL'),20,' ')||g_delimiter||
rpad(nvl(to_char(r_data.s3_atp_flag                   ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.wip_supply_subinventory       ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.s3_wip_supply_subinventory    ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.secondary_uom_code				),'NULL'),20,' ')||g_delimiter||
rpad(nvl(to_char(r_data.s3_secondary_uom_code			),'NULL'),20,' ')||g_delimiter||
rpad(nvl(to_char(r_data.inventory_item_status_code    ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.s3_inventory_item_status_code),'NULL'),20,' ')||g_delimiter||	
rpad(nvl(to_char(r_data.planner_code					),'NULL'),20,' ')||g_delimiter||
rpad(nvl(to_char(r_data.s3_planner_code				),'NULL'),20,' ')||g_delimiter||
rpad(nvl(to_char(r_data.fixed_lot_multiplier			),'NULL'),20,' ')||g_delimiter||
rpad(nvl(to_char(r_data.s3_fixed_lot_multiplier       ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.postprocessing_lead_time		),'NULL'),20,' ')||g_delimiter||
rpad(nvl(to_char(r_data.s3_postprocessing_lead_time   ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.preprocessing_lead_time       ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.s3_preprocessing_lead_time    ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.full_lead_time					),'NULL'),20,' ')||g_delimiter||
rpad(nvl(to_char(r_data.s3_full_lead_time             ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.min_minmax_quantity			),'NULL'),20,' ')||g_delimiter||
rpad(nvl(to_char(r_data.s3_min_minmax_quantity        ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.max_minmax_quantity			),'NULL'),20,' ')||g_delimiter||
rpad(nvl(to_char(r_data.s3_max_minmax_quantity        ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.minimum_order_quantity			),'NULL'),20,' ')||g_delimiter||
rpad(nvl(to_char(r_data.s3_minimum_order_quantity     ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.fixed_order_quantity			),'NULL'),20,' ')||g_delimiter||
rpad(nvl(to_char(r_data.s3_fixed_order_quantity       ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.fixed_days_supply				),'NULL'),20,' ')||g_delimiter||
rpad(nvl(to_char(r_data.s3_fixed_days_supply          ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.maximum_order_quantity			),'NULL'),20,' ')||g_delimiter||
rpad(nvl(to_char(r_data.s3_maximum_order_quantity     ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.atp_rule_name					),'NULL'),20,' ')||g_delimiter||
rpad(nvl(to_char(r_data.s3_atp_rule_name				),'NULL'),20,' ')||g_delimiter||
rpad(nvl(to_char(r_data.reservable_type				),'NULL'),20,' ')||g_delimiter||
rpad(nvl(to_char(r_data.s3_reservable_type            ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.cycle_count_enabled_flag		),'NULL'),20,' ')||g_delimiter||
rpad(nvl(to_char(r_data.s3_cycle_count_enabled_flag   ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.ship_model_complete_flag		),'NULL'),20,' ')||g_delimiter||
rpad(nvl(to_char(r_data.s3_ship_model_complete_flag   ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.mrp_planning_code				),'NULL'),20,' ')||g_delimiter||
rpad(nvl(to_char(r_data.s3_mrp_planning_code          ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.ato_forecast_control			),'NULL'),20,' ')||g_delimiter||
rpad(nvl(to_char(r_data.s3_ato_forecast_control       ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.release_time_fence_code       ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.s3_release_time_fence_code    ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.contract_item_type_code       ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.s3_contract_item_type_code    ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.serv_req_enabled_code         ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.s3_serv_req_enabled_code      ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.tracking_quantity_ind         ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.s3_tracking_quantity_ind      ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.secondary_default_ind         ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.s3_secondary_default_ind      ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.ont_pricing_qty_source        ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.s3_ont_pricing_qty_source     ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.attribute25                   ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.s3_attribute25                ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.expiration_action_code        ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.s3_expiration_action_code     ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.expiration_action_interval    ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.s3_expiration_action_interval ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.revision_qty_control_code     ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.s3_revision_qty_control_code  ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.attribute30                   ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.s3_attribute30                ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.date_extracted_on             ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.process_flag                  ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.cleanse_status                ),'NULL'),20,' ')||g_delimiter|| 
rpad(nvl(to_char(r_data.cleanse_error                 ),'NULL'),200,' '));      
      END LOOP;
    
      fnd_file.put_line(fnd_file.output,'');
      fnd_file.put_line(fnd_file.output,'Stratasys Confidential' || g_delimiter);
    END IF;
    fnd_file.put_line(fnd_file.log
                     ,'end data_cleanse_report procedure' || systimestamp);
  
  EXCEPTION
    WHEN no_data_found THEN
      fnd_file.put_line(fnd_file.log,'No data found' || ' ' || SQLCODE || '-' || SQLERRM);
    
  END data_cleanse_report;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: Report for Transformatio details
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date         Name                          Description
  -- 1.0  12/07/2016   V.V.Sateesh                   Initial build
  -----------------------------------------------------------------------------------------------  
    PROCEDURE data_transform_report(p_entity IN VARCHAR2) IS
  
    --Variables
    l_count_success NUMBER;
    l_count_fail    NUMBER;
  
    -- Cursor for the Data Transform report
  
    CURSOR c_report_item IS
    
      SELECT xx_inventory_item_id
            ,l_inventory_item_id
            ,segment1
            ,xpmi.legacy_buyer_id
            ,s3_buyer_number
            ,legacy_organization_code
            ,s3_organization_code
            ,l_source_organization_code
            ,s3_source_organization_code
			,expense_account				  -- Expense Account	
            ,legacy_expense_account	
            ,legacy_expense_acct_segment1
            ,legacy_expense_acct_segment2
            ,legacy_expense_acct_segment3
            ,legacy_expense_acct_segment4
            ,legacy_expense_acct_segment5
            ,legacy_expense_acct_segment6
            ,legacy_expense_acct_segment7
            ,legacy_expense_acct_segment8
            ,legacy_expense_acct_segment9
            ,legacy_expense_acct_segment10
            ,s3_expense_acct_segment1
            ,s3_expense_acct_segment2
            ,s3_expense_acct_segment3
            ,s3_expense_acct_segment4
            ,s3_expense_acct_segment5
            ,s3_expense_acct_segment6
            ,s3_expense_acct_segment7
            ,s3_expense_acct_segment8
						,cost_of_sales_account            -- Cost Of Sales Account
            ,l_cost_of_sales_account		  -- Concatenated Segments for Cost Sales Account	
            ,l_cost_of_sales_acct_segment1
            ,l_cost_of_sales_acct_segment2
            ,l_cost_of_sales_acct_segment3
            ,l_cost_of_sales_acct_segment4
            ,l_cost_of_sales_acct_segment5
            ,l_cost_of_sales_acct_segment6
            ,l_cost_of_sales_acct_segment7
            ,l_cost_of_sales_acct_segment8
            ,l_cost_of_sales_acct_segment9
            ,l_cost_of_sales_acct_segment10
            ,s3_cost_sales_acct_segment1
            ,s3_cost_sales_acct_segment2
            ,s3_cost_sales_acct_segment3
            ,s3_cost_sales_acct_segment4
            ,s3_cost_sales_acct_segment5
            ,s3_cost_sales_acct_segment6
            ,s3_cost_sales_acct_segment7
            ,s3_cost_sales_acct_segment8
            ,s3_cost_sales_acct_segment9
            ,s3_cost_sales_acct_segment10
            ,sales_account
            ,legacy_sales_account
            ,legacy_sales_acct_segment1
            ,legacy_sales_acct_segment2
            ,legacy_sales_acct_segment3
            ,legacy_sales_acct_segment4
            ,legacy_sales_acct_segment5
            ,legacy_sales_acct_segment6
            ,legacy_sales_acct_segment7
            ,legacy_sales_acct_segment8
            ,legacy_sales_acct_segment9
            ,legacy_sales_acct_segment10
            ,s3_sales_acct_segment1
            ,s3_sales_acct_segment2
            ,s3_sales_acct_segment3
            ,s3_sales_acct_segment4
            ,s3_sales_acct_segment5
            ,s3_sales_acct_segment6
            ,s3_sales_acct_segment7
            ,s3_sales_acct_segment8
            ,s3_sales_acct_segment9
            ,s3_sales_acct_segment10
            ,inventory_item_status_code
            ,s3_inventory_item_status_code
            ,atp_rule_name
            ,s3_atp_rule_name
            ,item_type
            ,s3_item_type
            ,xpmi.transform_status
            ,xpmi.transform_error
      FROM xxobjt.xxs3_ptm_master_items_ext_stg xpmi
      WHERE xpmi.transform_status IN ('PASS', 'FAIL');
  
  BEGIN
    fnd_file.put_line(fnd_file.output
                     ,'Begin data_transform_report procedure' ||
                      systimestamp);
  
    IF p_entity = 'ITEM'
    THEN
      -- Query to get the count of the Transform status pass
    
      SELECT COUNT(1)
      INTO l_count_success
      FROM xxobjt.xxs3_ptm_master_items_ext_stg xpmi
      WHERE xpmi.transform_status = 'PASS';
    
      -- Query to get the count of the Transfor status fail
    
      SELECT COUNT(1)
      INTO l_count_fail
      FROM xxobjt.xxs3_ptm_master_items_ext_stg xpmi
      WHERE xpmi.transform_status = 'FAIL';
    
      -- Print the Transform details in the output
    
      fnd_file.put_line(fnd_file.output,rpad('Report name = Data Transformation Report' || g_delimiter
                ,100
                ,' '));
      fnd_file.put_line(fnd_file.output,rpad('========================================' || g_delimiter
                ,100
                ,' '));
      fnd_file.put_line(fnd_file.output,rpad('Data Migration Object Name = ' || 'ITEM MASTER' ||
                 g_delimiter
                ,100
                ,' '));
      fnd_file.put_line(fnd_file.output,'');
      fnd_file.put_line(fnd_file.output,rpad('Run date and time:    ' ||
                 to_char(SYSDATE
                        ,'dd-Mon-YYYY HH24:MI') || g_delimiter
                ,100
                ,' '));
      fnd_file.put_line(fnd_file.output,rpad('Total Record Count Success = ' || l_count_success ||
                 g_delimiter
                ,100
                ,' '));
      fnd_file.put_line(fnd_file.output,rpad('Total Record Count Failure = ' || l_count_fail ||
                 g_delimiter
                ,100
                ,' '));
      fnd_file.put_line(fnd_file.output,'');
      fnd_file.put_line(fnd_file.output,rpad('Track Name'
                ,10
                ,' ') || g_delimiter ||
            rpad('Entity Name'
                ,15
                ,' ') || g_delimiter ||
            rpad('XX Inventory Item ID  '
                ,20
                ,' ') || g_delimiter ||
            rpad('Inventory Item ID'
                ,20
                ,' ') || g_delimiter ||
            rpad('Item Number'
                ,30
                ,' ') || g_delimiter ||
            rpad('Legacy_Buyer_Id'
                ,17
                ,' ') || g_delimiter ||
            rpad('S3_Buyer_Number'
                ,50
                ,' ') || g_delimiter ||
            rpad('Legacy_Organization_Code'
                ,50
                ,' ') || g_delimiter ||
            rpad('S3_Organization_Code'
                ,50
                ,' ') || g_delimiter ||
            rpad('L_Source_Organization_Code'
                ,50
                ,' ') || g_delimiter ||
            rpad('S3_Source_Organization_Code'
                ,50
                ,' ') || g_delimiter ||
            rpad('Inventory_Item_Status_Code'
                ,50
                ,' ') || g_delimiter ||
            rpad('S3_Inventory_Item_Status_Code'
                ,50
                ,' ') || g_delimiter ||
            
            rpad('Atp_Rule_Name'
                ,50
                ,' ') || g_delimiter ||
            rpad('S3_Atp_Rule_Name'
                ,50
                ,' ') || g_delimiter ||
            rpad('Item_Type'
                ,50
                ,' ') || g_delimiter ||
            rpad('S3_Item_Type'
                ,50
                ,' ') || g_delimiter ||
            rpad('Legacy Expense Account'
                ,50
                ,' ') || g_delimiter ||
		    rpad('Legacy Expense Account Concat'
                ,50
                ,' ') || g_delimiter ||		
            rpad('Expense_Acct_Segment1 '
                ,25
                ,' ') || g_delimiter ||
            rpad('Expense_Acct_Segment2 '
                ,25
                ,' ') || g_delimiter ||
            rpad('Expense_Acct_Segment3 '
                ,25
                ,' ') || g_delimiter ||
            rpad('Expense_Acct_Segment4 '
                ,25
                ,' ') || g_delimiter ||
            rpad('Expense_Acct_Segment5 '
                ,25
                ,' ') || g_delimiter ||
            rpad('Expense_Acct_Segment6 '
                ,25
                ,' ') || g_delimiter ||
            rpad('Expense_Acct_Segment7 '
                ,25
                ,' ') || g_delimiter ||
            rpad('Expense_Acct_Segment8 '
                ,25
                ,' ') || g_delimiter ||
            rpad('Expense_Acct_Segment9 '
                ,25
                ,' ') || g_delimiter ||
            rpad('Expense_Acct_Segment10 '
                ,25
                ,' ') || g_delimiter ||
            rpad('S3_Expense_Acct_Segment1'
                ,25
                ,' ') || g_delimiter ||
            rpad('S3_Expense_Acct_Segment2'
                ,25
                ,' ') || g_delimiter ||
            rpad('S3_Expense_Acct_Segment3'
                ,25
                ,' ') || g_delimiter ||
            rpad('S3_Expense_Acct_Segment4'
                ,25
                ,' ') || g_delimiter ||
            rpad('S3_Expense_Acct_Segment5'
                ,25
                ,' ') || g_delimiter ||
            rpad('S3_Expense_Acct_Segment6'
                ,25
                ,' ') || g_delimiter ||
            rpad('S3_Expense_Acct_Segment7'
                ,25
                ,' ') || g_delimiter ||
            rpad('S3_Expense_Acct_Segment8'
                ,25
                ,' ')|| g_delimiter ||
		   rpad('Cost Of Sales Account'
                ,25
                ,' ') || g_delimiter ||
           rpad('Concat Cost of Sales Account'
                ,50
                ,' ') || g_delimiter ||				
            rpad('Cost_of_Sales_Acct_Segment1'
                ,30
                ,' ') || g_delimiter ||
            rpad('Cost_Of_Sales_Acct_Segment2'
                ,30
                ,' ') || g_delimiter ||
            rpad('Cost_Of_Sales_Acct_Segment3'
                ,30
                ,' ') || g_delimiter ||
            rpad('Cost_Of_Sales_Acct_Segment4'
                ,30
                ,' ') || g_delimiter ||
            rpad('Cost_Of_Sales_Acct_Segment5'
                ,30
                ,' ') || g_delimiter ||
            rpad('Cost_Of_Sales_Acct_Segment6'
                ,30
                ,' ') || g_delimiter ||
            rpad('Cost_Of_Sales_Acct_Segment7'
                ,30
                ,' ') || g_delimiter ||
            rpad('Cost_Of_Sales_Acct_Segment8'
                ,30
                ,' ') || g_delimiter ||
            rpad('Cost_Of_Sales_Acct_Segment9'
                ,30
                ,' ') || g_delimiter ||
            rpad('Cost_Of_sales_Acct_Segment10'
                ,30
                ,' ') || g_delimiter ||
            rpad('S3_Cost_Sales_Acct_Segment1'
                ,30
                ,' ') || g_delimiter ||
            rpad('S3_Cost_Sales_Acct_Segment2'
                ,30
                ,' ') || g_delimiter ||
            rpad('S3_Cost_Sales_Acct_Segment3'
                ,30
                ,' ') || g_delimiter ||
            rpad('S3_Cost_Sales_Acct_Segment4'
                ,30
                ,' ') || g_delimiter ||
            rpad('S3_Cost_Sales_Acct_Segment5'
                ,30
                ,' ') || g_delimiter ||
            rpad('S3_Cost_Sales_Acct_Segment6'
                ,30
                ,' ') || g_delimiter ||
            rpad('S3_Cost_Sales_Acct_Segment7'
                ,30
                ,' ') || g_delimiter ||
            rpad('S3_Cost_Sales_Acct_Segment8'
                ,30
                ,' ') || g_delimiter ||
		    rpad('Sales Account'
                ,25
                ,' ') || g_delimiter ||
            rpad('Concat Sales Account'
                ,50
                ,' ') || g_delimiter ||				
            rpad('Sales_Acct_Segment1 '
                ,25
                ,' ') || g_delimiter ||
            rpad('Sales_Acct_Segment2 '
                ,25
                ,' ') || g_delimiter ||
            rpad('Sales_Acct_Segment3 '
                ,25
                ,' ') || g_delimiter ||
            rpad('Sales_Acct_Segment4 '
                ,25
                ,' ') || g_delimiter ||
            rpad('Sales_Acct_Segment5 '
                ,25
                ,' ') || g_delimiter ||
            rpad('Sales_Acct_Segment6 '
                ,25
                ,' ') || g_delimiter ||
            rpad('Sales_Acct_Segment7 '
                ,25
                ,' ') || g_delimiter ||
            rpad('Sales_Acct_Segment8 '
                ,25
                ,' ') || g_delimiter ||
            rpad('Sales_Acct_Segment9 '
                ,25
                ,' ') || g_delimiter ||
            rpad('Sales_Acct_Segment10 '
                ,25
                ,' ') || g_delimiter ||
            rpad('S3_Sales_Acct_Segment1'
                ,25
                ,' ') || g_delimiter ||
            rpad('S3_Sales_Acct_Segment2'
                ,25
                ,' ') || g_delimiter ||
            rpad('S3_Sales_Acct_Segment3'
                ,25
                ,' ') || g_delimiter ||
            rpad('S3_Sales_Acct_Segment4'
                ,25
                ,' ') || g_delimiter ||
            rpad('S3_Sales_Acct_Segment5'
                ,25
                ,' ') || g_delimiter ||
            rpad('S3_Sales_Acct_Segment6'
                ,25
                ,' ') || g_delimiter ||
            rpad('S3_Sales_Acct_Segment7'
                ,25
                ,' ') || g_delimiter ||
            rpad('S3_Sales_Acct_Segment8'
                ,25
                ,' ') || g_delimiter ||
            rpad('Status'
                ,10
                ,' ') || g_delimiter ||
            rpad('Error Message'
                ,200
                ,' '));
    
      FOR r_data IN c_report_item
      LOOP
      
        fnd_file.put_line(fnd_file.output,rpad('PTM'
                  ,10
                  ,' ') || g_delimiter ||
              rpad('ITEM'
                  ,15
                  ,' ') || g_delimiter ||
              rpad(r_data.xx_inventory_item_id
                  ,30
                  ,' ') || g_delimiter ||
              rpad(r_data.l_inventory_item_id
                  ,30
                  ,' ') || g_delimiter ||
              rpad(r_data.segment1
                  ,30
                  ,' ') || g_delimiter ||
              rpad(nvl(to_char(r_data.legacy_buyer_id)
                      ,'NULL')
                  ,17
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.s3_buyer_number
                      ,'NULL')
                  ,50
                  ,' ') || g_delimiter ||
                  rpad(nvl(r_data.legacy_organization_code
                      ,'NULL')
                  ,50
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.s3_organization_code
                      ,'NULL')
                  ,50
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.l_source_organization_code
                      ,'NULL')
                  ,50
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.s3_source_organization_code
                      ,'NULL')
                  ,50
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.inventory_item_status_code
                      ,'NULL')
                  ,50
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.s3_inventory_item_status_code
                      ,'NULL')
                  ,50
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.atp_rule_name
                      ,'NULL')
                  ,50
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.s3_atp_rule_name
                      ,'NULL')
                  ,50
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.item_type
                      ,'NULL')
                  ,50
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.s3_item_type
                      ,'NULL')
                  ,50
                  ,' ') || g_delimiter ||
			   rpad(nvl(r_data.expense_account
                      ,'NULL')
                  ,25
                  ,' ') || g_delimiter ||
				  rpad(nvl(r_data.legacy_expense_account
                      ,'NULL')
                  ,25
                  ,' ') || g_delimiter ||				  
     		  rpad(nvl(r_data.legacy_expense_acct_segment1
                      ,'NULL')
                  ,25
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.legacy_expense_acct_segment2
                      ,'NULL')
                  ,25
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.legacy_expense_acct_segment3
                      ,'NULL')
                  ,25
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.legacy_expense_acct_segment4
                      ,'NULL')
                  ,25
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.legacy_expense_acct_segment5
                      ,'NULL')
                  ,25
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.legacy_expense_acct_segment6
                      ,'NULL')
                  ,25
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.legacy_expense_acct_segment7
                      ,'NULL')
                  ,25
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.legacy_expense_acct_segment8
                      ,'NULL')
                  ,25
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.s3_expense_acct_segment1
                      ,'NULL')
                  ,25
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.s3_expense_acct_segment2
                      ,'NULL')
                  ,25
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.s3_expense_acct_segment3
                      ,'NULL')
                  ,25
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.s3_expense_acct_segment4
                      ,'NULL')
                  ,25
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.s3_expense_acct_segment5
                      ,'NULL')
                  ,25
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.s3_expense_acct_segment6
                      ,'NULL')
                  ,25
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.s3_expense_acct_segment7
                      ,'NULL')
                  ,25
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.s3_expense_acct_segment8
                      ,'NULL')
                  ,25
                  ,' ') || g_delimiter ||
				  rpad(nvl(r_data.cost_of_sales_account
                      ,'NULL')
                  ,50
                  ,' ') || g_delimiter ||
				  rpad(nvl(r_data.l_cost_of_sales_account
                      ,'NULL')
                  ,50
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.l_cost_of_sales_acct_segment1
                      ,'NULL')
                  ,50
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.l_cost_of_sales_acct_segment2
                      ,'NULL')
                  ,50
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.l_cost_of_sales_acct_segment3
                      ,'NULL')
                  ,50
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.l_cost_of_sales_acct_segment4
                      ,'NULL')
                  ,50
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.l_cost_of_sales_acct_segment5
                      ,'NULL')
                  ,50
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.l_cost_of_sales_acct_segment6
                      ,'NULL')
                  ,50
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.l_cost_of_sales_acct_segment7
                      ,'NULL')
                  ,50
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.l_cost_of_sales_acct_segment8
                      ,'NULL')
                  ,50
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.l_cost_of_sales_acct_segment9
                      ,'NULL')
                  ,50
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.l_cost_of_sales_acct_segment10
                      ,'NULL')
                  ,50
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.s3_cost_sales_acct_segment1
                      ,'NULL')
                  ,50
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.s3_cost_sales_acct_segment2
                      ,'NULL')
                  ,50
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.s3_cost_sales_acct_segment3
                      ,'NULL')
                  ,50
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.s3_cost_sales_acct_segment4
                      ,'NULL')
                  ,50
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.s3_cost_sales_acct_segment5
                      ,'NULL')
                  ,50
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.s3_cost_sales_acct_segment6
                      ,'NULL')
                  ,50
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.s3_cost_sales_acct_segment7
                      ,'NULL')
                  ,50
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.s3_cost_sales_acct_segment8
                      ,'NULL')
                  ,50
                  ,' ') || g_delimiter ||
			rpad(nvl(r_data.sales_account
                      ,'NULL')
                  ,25
                  ,' ') || g_delimiter ||	
             rpad(nvl(r_data.legacy_sales_account
                      ,'NULL')
                  ,25
                  ,' ') || g_delimiter ||				  
              rpad(nvl(r_data.legacy_sales_acct_segment1
                      ,'NULL')
                  ,25
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.legacy_sales_acct_segment2
                      ,'NULL')
                  ,25
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.legacy_sales_acct_segment3
                      ,'NULL')
                  ,25
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.legacy_sales_acct_segment4
                      ,'NULL')
                  ,25
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.legacy_sales_acct_segment5
                      ,'NULL')
                  ,25
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.legacy_sales_acct_segment6
                      ,'NULL')
                  ,25
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.legacy_sales_acct_segment7
                      ,'NULL')
                  ,25
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.legacy_sales_acct_segment8
                      ,'NULL')
                  ,25
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.legacy_sales_acct_segment9
                      ,'NULL')
                  ,25
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.legacy_sales_acct_segment10
                      ,'NULL')
                  ,25
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.s3_sales_acct_segment1
                      ,'NULL')
                  ,25
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.s3_sales_acct_segment2
                      ,'NULL')
                  ,25
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.s3_sales_acct_segment3
                      ,'NULL')
                  ,25
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.s3_sales_acct_segment4
                      ,'NULL')
                  ,25
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.s3_sales_acct_segment5
                      ,'NULL')
                  ,25
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.s3_sales_acct_segment6
                      ,'NULL')
                  ,25
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.s3_sales_acct_segment7
                      ,'NULL')
                  ,25
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.s3_sales_acct_segment8
                      ,'NULL')
                  ,25
                  ,' ') || g_delimiter ||
              rpad(r_data.transform_status
                  ,10
                  ,' ') || g_delimiter ||
              rpad(nvl(r_data.transform_error
                      ,'NULL')
                  ,200
                  ,' '));
      
      END LOOP;
      fnd_file.put_line(fnd_file.output,'');
      fnd_file.put_line(fnd_file.output,'Stratasys Confidential' || g_delimiter);
    END IF;
    fnd_file.put_line(fnd_file.output
                     ,'end data_transform_report procedure' ||
                      systimestamp);
  
  EXCEPTION
    WHEN no_data_found THEN
      fnd_file.put_line(fnd_file.log,'No data found' || ' ' || SQLCODE || '-' || SQLERRM);
    
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log,'Error:data_transform_report Procudure' || ' ' || SQLCODE || '-' ||
            SQLERRM);
    
  END data_transform_report;

-- --------------------------------------------------------------------------------------------
  -- Purpose: Generate Data Quality Report for Items
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date          Name                          Description
  --  1.0 07/12/2016   V.V.SATEESH                    Initial build
  -----------------------------------------------------------------------------------------------
  PROCEDURE report_data_items(p_entity IN VARCHAR2) IS
  
  /* Variables */
   l_count_dq	 NUMBER;
   
  /* Cursor for the Data Quality Report */
    CURSOR c_report_item IS
       SELECT c.xx_inventory_item_id xx_inventory_item_id  
        ,d.l_inventory_item_id
        ,d.segment1
		,d.legacy_organization_code
		,d.s3_organization_code
        ,nvl(c.rule_name
                ,' ') rule_name
            ,nvl(c.notes
                ,' ') notes
	  	,decode(d.process_flag, 'R', 'Y', 'Q', 'N') reject_record
            ,attribute_name
                      
      FROM xxobjt.xxs3_ptm_mtl_master_items_dq c
          ,xxobjt.xxs3_ptm_master_items_ext_stg      d
      WHERE c.xx_inventory_item_id = d.xx_inventory_item_id
      AND d.extract_rule_name is not null
      AND d.legacy_organization_code='OMA'  
      AND d.process_flag IN ('Q', 'R');

      
  BEGIN
     IF p_entity='ITEM' THEN
	SELECT count(1)
    INTO l_count_dq
    FROM xxobjt.xxs3_ptm_master_items_ext_stg d
    WHERE d.process_flag in ('Q','R');
    
    
	fnd_file.put_line(fnd_file.output, rpad('Report name = Data Quality Error Report'|| g_delimiter, 100, ' '));
    fnd_file.put_line(fnd_file.output, rpad('========================================'|| g_delimiter, 100, ' '));
    fnd_file.put_line(fnd_file.output, rpad('Data Migration Object Name = '||'Item Master' || g_delimiter, 100, ' '));
    fnd_file.put_line(fnd_file.output, '');
    fnd_file.put_line(fnd_file.output, rpad('Run date and time:    ' ||
                       to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI')|| g_delimiter, 100, ' '));
    fnd_file.put_line(fnd_file.output, rpad('Total Record Count Having DQ Issues = '||l_count_dq || g_delimiter, 100, ' '));
    /*fnd_file.put_line(fnd_file.output, rpad('Total Record Count Rejected =  '||l_count_reject|| g_delimiter , 100, ' '));*/
    fnd_file.put_line(fnd_file.output, '');

    fnd_file.put_line(fnd_file.output,rpad('Track Name', 10, ' ') || g_delimiter ||
                       rpad('Entity Name', 11, ' ') || g_delimiter ||
                       rpad('XX Inventory Item Id  ', 20, ' ') || g_delimiter ||
                       rpad('Inventory Item Id', 20, ' ') || g_delimiter ||
                       rpad('Item Number', 30, ' ') || g_delimiter ||
					   rpad('Legacy Organization Code', 30, ' ') || g_delimiter ||
					   rpad('S3 Organization Code', 30, ' ') || g_delimiter ||
                      rpad('Reject Record Flag(Y/N)', 22, ' ') || g_delimiter ||
                       rpad('Rule Name', 45, ' ') || g_delimiter ||
                       rpad('Reason Code', 50, ' ') || g_delimiter ||
					   rpad('Attribute Name', 50, ' '));


    FOR r_data IN c_report_item LOOP
      fnd_file.put_line(fnd_file.output, rpad('PTM', 10, ' ') || g_delimiter ||
                         rpad('ITEMS', 11, ' ') || g_delimiter ||
                         rpad(r_data.xx_inventory_item_id, 20, ' ') || g_delimiter ||
                         rpad(r_data.l_inventory_item_id, 20, ' ') || g_delimiter ||
                         rpad(r_data.segment1, 30, ' ') || g_delimiter ||
						 rpad(r_data.legacy_organization_code, 30, ' ') || g_delimiter ||
						 rpad(r_data.s3_organization_code, 30, ' ') || g_delimiter ||
                         rpad(r_data.reject_record, 22, ' ') || g_delimiter ||
                         rpad(NVL(r_data.rule_name,'NULL'), 45  , ' ') || g_delimiter ||
                         rpad(NVL(r_data.notes,'NULL'), 50, ' ') || g_delimiter ||
						 rpad(NVL(r_data.attribute_name,'NULL'), 50, ' '));

    END LOOP;

    fnd_file.put_line(fnd_file.output, '');
    fnd_file.put_line(fnd_file.output, 'Stratasys Confidential'|| g_delimiter);
    END IF;
	 EXCEPTION
    WHEN no_data_found THEN
      fnd_file.put_line(fnd_file.output,'No data found' || ' ' || SQLCODE || '-' || SQLERRM);
    
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.output,'Error:data_transform_report Procudure' || ' ' || SQLCODE || '-' ||
            SQLERRM);
  END report_data_items;
   -- --------------------------------------------------------------------------------------------
  -- Purpose: This function will work for the Return Transform Vlaue of Buyer ID Attributes
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date         Name                          Description
  -- 1.0  17/08/2016   V.V.SATEESH            Initial build
  -- --------------------------------------------------------------------------------------------
FUNCTION transform_buyer(p_inventory_item_id IN NUMBER,p_buyer_id IN NUMBER,p_organization_code IN VARCHAR2) 
RETURN VARCHAR2 IS
l_buyer_value varchar2(50);
BEGIN
BEGIN
SELECT papf.employee_number
        INTO l_buyer_value
        FROM per_all_people_f papf
       WHERE papf.person_id = p_buyer_id
         AND TRUNC(sysdate) between
             TRUNC(nvl(papf.effective_start_date, sysdate)) AND
             TRUNC(NVL(papf.effective_end_date, sysdate));
			 
 RETURN l_buyer_value;		
 
EXCEPTION
WHEN OTHERS THEN
l_buyer_value:= NULL;
RETURN l_buyer_value;
 UPDATE xxs3_ptm_master_items_ext_stg
              SET transform_status = 'FAIL',
             transform_error= CASE 
                                  WHEN transform_error IS NULL  
                                   THEN 'Employee Not Found '
                                   WHEN transform_error IS NOT NULL  THEN								   
						transform_error||','||'Employee Not Found '	
						                    ELSE 
                                     NULL								   
                                 END
          WHERE l_inventory_item_id = p_inventory_item_id
          AND legacy_organization_code= p_organization_code;	
		  
		  fnd_file.put_line(fnd_file.log, 'Invalid Buyer ID Found : ' || SQLERRM);
END;
EXCEPTION
WHEN OTHERS THEN
fnd_file.put_line(fnd_file.log, 'Invalid Buyer ID Found : ' || SQLERRM);
END transform_buyer;
		  
			 

END xxs3_ptm_item_master_extrt_pkg;
/