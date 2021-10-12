create or replace package body XXCS_RES_UTIL is
 
 -- Author  : ADI.SAFIN
 -- Created : 27-Jun-13 14:49:13
 -- Purpose : Load new resoultion codes to the system

PROCEDURE load_res_codes (retcode out number,errbuf out VARCHAR2) IS

x_rowid               fnd_lookup_values.meaning%TYPE;
x_attribute_category  fnd_lookup_values.Attribute_Category%TYPE;
x_attribute1          fnd_lookup_values.Attribute1%TYPE;
x_attribute_NULL      fnd_lookup_values.Attribute1%TYPE := NULL;
v_min_not_used        fnd_lookup_values.meaning%TYPE;    
v_exists              NUMBER := 0; 
v_meaning             fnd_lookup_values.meaning%TYPE;
v_lookup              fnd_lookup_values.lookup_code%TYPE;                          
v_check_lookup        fnd_lookup_values.lookup_type%TYPE;
v_like_meaning        fnd_lookup_values.meaning%TYPE;

  CURSOR lookval IS 
      SELECT xll.num_val,xll.lookup_type,xll.lookup_code,INITCAP(xll.meaning) meaning,INITCAP(xll.description) description,INITCAP(xll.attribute1) attribute1
      FROM   xxcs_load_lookup xll
      WHERE  xll.lookup_type IN ('REQUEST_RESOLUTION_CODE','XXCS_FULL_SUBRESOLUTION1_NLU','XXCS_FULL_SUBRESOLUTION2_NLU')
      ORDER BY xll.num_val,xll.lookup_type,xll.lookup_code
      ;
BEGIN

FOR lval IN lookval LOOP
  
  x_attribute_category := NULL;
  x_attribute1 := NULL;
  v_meaning := lval.meaning;
  v_lookup := lval.lookup_code;
  
 IF lval.lookup_type = 'XXCS_FULL_SUBRESOLUTION1_NLU' THEN
    -- check if att1 from  REQUEST_RESOLUTION_CODE exists
    v_exists := 0;
    
    SELECT count(1)
    INTO   v_exists
    FROM   fnd_lookup_values flv
    WHERE  FLV.LOOKUP_TYPE = 'REQUEST_RESOLUTION_CODE'
    AND    FLV.ENABLED_FLAG = 'Y'   
    AND    FLV.LANGUAGE = 'US'
    AND    UPPER(lval.attribute1) LIKE UPPER(flv.meaning||'%');
    
    IF v_exists = 0 THEN
       INSERT INTO xxcs_load_look_err(num_val,err_code,err_desc)
       VALUES (lval.num_val,11,'REQUEST_RESOLUTION_CODE - '||lval.attribute1||' Is not exists');
       COMMIT;
       EXIT;
    END IF;
    
    x_attribute1 := lval.Attribute1;
    x_attribute_category := 'XXCS_FULL_SUBRESOLUTION1_NLU';
    
    v_exists := 0;
    -- check if there is old meaning or lookup
    SELECT count(1)
    INTO   v_exists
    FROM   fnd_lookup_values flv
    WHERE  FLV.LOOKUP_TYPE = 'XXCS_FULL_SUBRESOLUTION1_NLU'
    --AND    FLV.ENABLED_FLAG = 'Y'   
    AND    FLV.LANGUAGE = 'US'
    AND    (flv.meaning = lval.meaning OR flv.lookup_code = lval.lookup_code);
    
    
    IF v_exists = 1 THEN 
        INSERT INTO xxcs_load_look_err(num_val,err_code,err_desc)
        VALUES (lval.num_val,15,'XXCS_FULL_SUBRESOLUTION1_NLU - '||lval.meaning||' Is already exists, or'||lval.lookup_code);
        COMMIT;
      /*  v_meaning := lval.meaning||'_1';
        v_lookup := lval.lookup_code||'_1';*/
    END IF; 
 ELSIF lval.lookup_type = 'XXCS_FULL_SUBRESOLUTION2_NLU' THEN
    -- check if att1 from XXCS_FULL_SUBRESOLUTION1_NLU exists
    v_exists := 0;
    
    
    SELECT count(1)
    INTO   v_exists
    FROM   fnd_lookup_values flv
    WHERE  FLV.LOOKUP_TYPE = 'XXCS_FULL_SUBRESOLUTION1_NLU'
    AND    FLV.ENABLED_FLAG = 'Y'   
    AND    FLV.LANGUAGE = 'US'
    AND    UPPER(lval.attribute1) LIKE UPPER(flv.meaning||'%');
    
    IF v_exists = 0 THEN
       INSERT INTO xxcs_load_look_err(num_val,err_code,err_desc)
       VALUES (lval.num_val,22,'XXCS_FULL_SUBRESOLUTION1_NLU - '||lval.attribute1||' Is not exists');
       COMMIT;
    ELSE
      
       
       x_attribute_category := 'XXCS_FULL_SUBRESOLUTION2_NLU';
       x_attribute1 := lval.attribute1;
    
       v_exists := 0;
        -- check if there is old meaning or lookup
        SELECT count(1)
        INTO   v_exists
        FROM   fnd_lookup_values flv
        WHERE  FLV.LOOKUP_TYPE = 'XXCS_FULL_SUBRESOLUTION2_NLU'
        --AND    FLV.ENABLED_FLAG = 'Y'   
        AND    FLV.LANGUAGE = 'US'
        AND    (initcap(flv.meaning) = lval.meaning OR flv.lookup_code = lval.lookup_code);
    
      
        IF v_exists = 1 THEN 
            INSERT INTO xxcs_load_look_err(num_val,err_code,err_desc)
            VALUES (lval.num_val,25,'XXCS_FULL_SUBRESOLUTION2_NLU - '||lval.meaning||' Is already exists, or'||lval.lookup_code);
            COMMIT;
          
           /* v_meaning := lval.meaning||'_1';
            v_lookup := lval.lookup_code||'_1';*/
        END IF; 
      
      -- get the min same lookup that not used for attribute1.
        BEGIN 
          v_min_not_used := NULL;
          SELECT MIN(initcap(FLV.Meaning))
          INTO   v_min_not_used
          FROM   fnd_lookup_values flv
          WHERE  FLV.LOOKUP_TYPE = 'XXCS_FULL_SUBRESOLUTION1_NLU'
          AND    FLV.ENABLED_FLAG = 'Y' 
          AND    FLV.LANGUAGE = 'US'
          AND    initcap(flv.meaning) = initcap(lval.attribute1)
          AND    initcap(FLV.Meaning) NOT IN ( SELECT initcap(flv_res2.attribute1)
                              FROM   fnd_lookup_values flv_res2,
                                     fnd_lookup_values flv_res1
                              WHERE  flv_res2.LOOKUP_TYPE = 'XXCS_FULL_SUBRESOLUTION2_NLU'
                              AND    flv_res1.LOOKUP_TYPE = 'XXCS_FULL_SUBRESOLUTION1_NLU'
                              AND    flv_res2.ENABLED_FLAG = 'Y' 
                              AND    flv_res2.LANGUAGE = 'US'
                              AND    flv_res1.ENABLED_FLAG = 'Y' 
                              AND    flv_res1.LANGUAGE = 'US'
                              AND    initcap(flv_res1.meaning) = initcap(flv_res2.attribute1)
                              AND    initcap(flv.description) = initcap(flv_res1.description));
          IF v_min_not_used IS NOT NULL THEN                    
             x_attribute1 := v_min_not_used;                          
          ELSE
             x_attribute1 := lval.attribute1;
          END IF;
        END;
                                
    END IF;
  ELSIF lval.lookup_type = 'XXCS_FULL_SUBRESOLUTION3_NLU' THEN
    -- check if att1 from XXCS_FULL_SUBRESOLUTION2_NLU exists
  /*  v_exists := 0;
    
    
    SELECT count(1)
    INTO   v_exists
    FROM   fnd_lookup_values flv
    WHERE  FLV.LOOKUP_TYPE = 'XXCS_FULL_SUBRESOLUTION2_NLU'
    AND    FLV.ENABLED_FLAG = 'Y'   
    AND    FLV.LANGUAGE = 'US'
    AND    UPPER(lval.attribute1) LIKE UPPER(flv.meaning||'%');
    
    IF v_exists = 0 THEN
       INSERT INTO xxcs_load_look_err(num_val,err_code,err_desc)
       VALUES (lval.num_val,33,'XXCS_FULL_SUBRESOLUTION2_NLU - '||lval.attribute1||' Is not exists');
       COMMIT;
    ELSE*/
      
       
       x_attribute_category := 'XXCS_FULL_SUBRESOLUTION3_NLU';
       x_attribute1 := lval.attribute1;
    
       v_exists := 0;
        -- check if there is old meaning or lookup
        SELECT count(1)
        INTO   v_exists
        FROM   fnd_lookup_values flv
        WHERE  FLV.LOOKUP_TYPE = 'XXCS_FULL_SUBRESOLUTION3_NLU'
        --AND    FLV.ENABLED_FLAG = 'Y'   
        AND    FLV.LANGUAGE = 'US'
        AND    (initcap(flv.meaning) = lval.meaning OR flv.lookup_code = lval.lookup_code);
          
       
        IF v_exists = 1 THEN 
            INSERT INTO xxcs_load_look_err(num_val,err_code,err_desc)
            VALUES (lval.num_val,35,'XXCS_FULL_SUBRESOLUTION3_NLU - '||lval.meaning||' Is already exists, or'||lval.lookup_code);
            COMMIT;
          /*  v_meaning := lval.meaning||'_1';
            v_lookup := lval.lookup_code||'_1';*/
        END IF; 
      
      -- get the min same lookup that not used for attribute1.
        BEGIN 
          v_min_not_used := NULL;
          SELECT MIN(initcap(FLV.Meaning))
          INTO   v_min_not_used
          FROM   fnd_lookup_values flv
          WHERE  FLV.LOOKUP_TYPE = 'XXCS_FULL_SUBRESOLUTION2_NLU'
          AND    FLV.ENABLED_FLAG = 'Y' 
          AND    FLV.LANGUAGE = 'US'
--          AND    initcap(flv.meaning) = initcap(lval.attribute1)
          AND    UPPER(lval.attribute1) LIKE UPPER(flv.meaning||'%')
          AND    initcap(FLV.Meaning) NOT IN ( SELECT initcap(flv_res2.attribute1)
                              FROM   fnd_lookup_values flv_res2,
                                     fnd_lookup_values flv_res1
                              WHERE  flv_res2.LOOKUP_TYPE = 'XXCS_FULL_SUBRESOLUTION3_NLU'
                              AND    flv_res1.LOOKUP_TYPE = 'XXCS_FULL_SUBRESOLUTION2_NLU'
                              AND    flv_res2.ENABLED_FLAG = 'Y' 
                              AND    flv_res2.LANGUAGE = 'US'
                              AND    flv_res1.ENABLED_FLAG = 'Y' 
                              AND    flv_res1.LANGUAGE = 'US'
                              AND    initcap(flv_res1.meaning) = initcap(flv_res2.attribute1)
                              AND    initcap(flv.description) = initcap(flv_res1.description));
          IF v_min_not_used IS NOT NULL THEN                    
             x_attribute1 := v_min_not_used;                          
          ELSE
            -- the first one
             x_attribute1 := lval.attribute1;
          END IF;
        END;
                                
   -- END IF;    
 END IF;
 BEGIN
 -- check that att1 is exists in it's parent res table
    IF x_attribute_category = 'XXCS_FULL_SUBRESOLUTION1_NLU' THEN
       v_check_lookup := 'REQUEST_RESOLUTION_CODE';
    ELSIF x_attribute_category = 'XXCS_FULL_SUBRESOLUTION2_NLU' THEN
       v_check_lookup := 'XXCS_FULL_SUBRESOLUTION1_NLU';
    ELSIF x_attribute_category = 'XXCS_FULL_SUBRESOLUTION3_NLU' THEN
       v_check_lookup := 'XXCS_FULL_SUBRESOLUTION2_NLU';
    END IF;
    v_exists := '0';
    
    SELECT count(1)
    INTO   v_exists
    FROM   fnd_lookup_values flv
    WHERE  FLV.LOOKUP_TYPE = v_check_lookup
    AND    FLV.ENABLED_FLAG = 'Y' 
    AND    FLV.LANGUAGE = 'US'
    AND    flv.meaning = x_attribute1;

    -- not exists
    IF  v_exists = 0 AND lval.lookup_type != 'REQUEST_RESOLUTION_CODE'THEN   
       INSERT INTO xxcs_load_look_err(num_val,err_code,err_desc)
       VALUES (lval.num_val,44,'Att1 '||x_attribute1||' not exists at lookup '||v_check_lookup);
       COMMIT;
      /*  SELECT MIN(flv.meaning)
        INTO   x_attribute1
        FROM   fnd_lookup_values flv
        WHERE  FLV.LOOKUP_TYPE = v_check_lookup
        AND    FLV.ENABLED_FLAG = 'Y' 
        AND    FLV.LANGUAGE = 'US'
        AND    flv.description = x_attribute1;*/
        
        v_exists := 1;
   END IF;

    IF lval.lookup_type = 'REQUEST_RESOLUTION_CODE' THEN
        v_exists := 1;
    END IF;
    
    IF v_exists > 0 THEN

        fnd_lookup_values_pkg.insert_row(x_rowid => x_rowid,
                                         x_lookup_type => lval.lookup_type,
                                         x_security_group_id => 0,
                                         x_view_application_id => 170,
                                         x_lookup_code => v_lookup,
                                         x_tag => NULL,
                                         x_attribute_category => x_attribute_category,
                                         x_attribute1 => x_attribute1,
                                         x_attribute2 => x_attribute_NULL,
                                         x_attribute3 => x_attribute_NULL,
                                         x_attribute4 => x_attribute_NULL,
                                         x_enabled_flag => 'Y',
                                         x_start_date_active => SYSDATE,
                                         x_end_date_active => NULL,
                                         x_territory_code => x_attribute_NULL,
                                         x_attribute5 => x_attribute_NULL,
                                         x_attribute6 => x_attribute_NULL,
                                         x_attribute7 => x_attribute_NULL,
                                         x_attribute8 => x_attribute_NULL,
                                         x_attribute9 => x_attribute_NULL,
                                         x_attribute10 => x_attribute_NULL,
                                         x_attribute11 => x_attribute_NULL,
                                         x_attribute12 => x_attribute_NULL,
                                         x_attribute13 => x_attribute_NULL,
                                         x_attribute14 => x_attribute_NULL,
                                         x_attribute15 => x_attribute_NULL,
                                         x_meaning => v_meaning,
                                         x_description => LVAL.DESCRIPTION,
                                         x_creation_date => SYSDATE,
                                         x_created_by => 8031,
                                         x_last_update_date => SYSDATE,
                                         x_last_updated_by => 8031,
                                         x_last_update_login => NULL);

            IF x_rowid IS NULL THEN
               INSERT INTO xxcs_load_look_err(num_val,err_code,err_desc)
               VALUES (lval.num_val,99,'Not enter to lookup '||lval.lookup_type);
            END IF;   
            COMMIT;
            x_rowid := NULL;
       ELSE 
          INSERT INTO xxcs_load_look_err(num_val,err_code,err_desc)
          VALUES (lval.num_val,55,'Attribute1 is not exists '||x_attribute1||' At lookup '||v_check_lookup||' and found like '||v_like_meaning);
          COMMIT;
       END IF;
    EXCEPTION 
        WHEN OTHERS THEN 
            INSERT INTO xxcs_load_look_err(num_val,err_code,err_desc)
            VALUES (lval.num_val,100,'Not enter to lookup '||lval.lookup_type||' CODE = '||lval.Lookup_CODE||' MEANING = '||LVAL.MEANING);
            COMMIT;
      END;
                                   
END LOOP;                                   

end load_res_codes;
 
 -- Author  : ADI.SAFIN
 -- Created : 27-Jun-13 14:49:13
 -- Purpose : Map new resoultion codes to the inventory category
 --           according to machine type (WJ/EC/DSK)

PROCEDURE map_res_codes (retcode out number,errbuf out VARCHAR2) IS
  
x_null_chr VARCHAR2(30);
x_null_num NUMBER;
x_null_date DATE;
p_object_version_number  CS_SR_RES_CODE_MAPPING_DETAIL.Object_Version_Number%TYPE;
p_category_id            CS_SR_RES_CODE_MAPPING_DETAIL.Category_Id%TYPE;
p_resolution_code        CS_SR_RES_CODE_MAPPING_DETAIL.Resolution_Code%TYPE;
px_resolution_map_detail_id      CS_SR_RES_CODE_MAPPING_DETAIL.RESOLUTION_MAP_DETAIL_ID%TYPE;
l_out_message            VARCHAR2(500);
l_msg_index_out          VARCHAR2(500);
x_msg_count              NUMBER;
x_msg_data               VARCHAR2(4000);
v_exists                 NUMBER;

CURSOR new_lookup IS
    SELECT flv.lookup_code,SUBSTR(flv.lookup_code,INSTR(flv.lookup_code,'_',-1)+1) val_type
    FROM   fnd_lookup_values flv
    WHERE  FLV.LOOKUP_TYPE = 'REQUEST_RESOLUTION_CODE'-- 'XXCS_FULL_SUBRESOLUTION1_NLU'
    AND    FLV.ENABLED_FLAG = 'Y'   
    AND    flv.creation_date > SYSDATE - 1
    AND    FLV.LANGUAGE = 'US';

CURSOR categories IS
   SELECT DISTINCT MIC.CATEGORY_ID,MIC.SEGMENT2,DECODE(MIC.SEGMENT2,'S CONX','EC','S DeskT','DSK','S Of','EC','S Pro','EC','S Triplex','EC','WJ','WJ',MIC.SEGMENT2) lookup_val--,PR.FAMILY,PR.ITEM_TYPE,PR.ITEM,PR.ITEM_DESCRIPTION
   FROM  MTL_ITEM_CATEGORIES_V MIC,
         mtl_system_items_b msi ,
         XXCS_ITEMS_PRINTERS_V PR
   WHERE MSI.INVENTORY_ITEM_ID = MIC.INVENTORY_ITEM_ID
   AND   MSI.ORGANIZATION_ID = 91
   AND   PR.inventory_item_id = MSI.INVENTORY_ITEM_ID
   AND   MIC.CATEGORY_ID IN ( SELECT DISTINCT RES_MAP.CATEGORY_ID
                              FROM  CS_SR_RES_CODE_MAPPING_DETAIL res_map);
                              
   /*SELECT DISTINCT res_map.category_id
   FROM  CS_SR_RES_CODE_MAPPING_DETAIL res_map;*/                              
   
BEGIN
  FOR CAT IN categories LOOP
    FOR LOOK IN new_lookup LOOP
        
       -- check if resolution code already exists for that category id
       V_EXISTS := 0;
       
       SELECT COUNT(1)
       INTO   v_exists
       FROM   CS_SR_RES_CODE_MAPPING_DETAIL res_exi
       WHERE  res_exi.category_id = CAT.CATEGORY_ID
       AND    res_exi.resolution_code =  LOOK.LOOKUP_CODE
       AND    cat.lookup_val = look.val_type
       AND    res_exi.resolution_map_id = 10003;
       
       IF  v_exists = 0 AND cat.lookup_val = look.val_type THEN
         
                    px_resolution_map_detail_id := NULL;
                    p_category_id := CAT.CATEGORY_ID;
                    p_resolution_code := LOOK.LOOKUP_CODE;
                    p_object_version_number := 1;
                    
                    cs_sr_res_code_map_detail_pkg.insert_row(px_resolution_map_detail_id => px_resolution_map_detail_id,
                                                             p_resolution_map_id => 10003,--:p_resolution_map_id,
                                                             p_incident_type_id => x_null_num,
                                                             p_inventory_item_id => x_null_num,
                                                             p_organization_id => x_null_num,
                                                             p_category_id => p_category_id,
                                                             p_problem_code => x_null_chr,
                                                             p_map_start_date_active => SYSDATE,
                                                             p_map_end_date_active => x_null_date,
                                                             p_resolution_code => p_resolution_code,
                                                             p_start_date_active => SYSDATE,
                                                             p_end_date_active => x_null_date,
                                                             p_object_version_number => p_object_version_number,
                                                             p_attribute1 => x_null_chr,
                                                             p_attribute2 => x_null_chr,
                                                             p_attribute3 => x_null_chr,
                                                             p_attribute4 => x_null_chr,
                                                             p_attribute5 => x_null_chr,
                                                             p_attribute6 => x_null_chr,
                                                             p_attribute7 => x_null_chr,
                                                             p_attribute8 => x_null_chr,
                                                             p_attribute9 => x_null_chr,
                                                             p_attribute10 => x_null_chr,
                                                             p_attribute11 => x_null_chr,
                                                             p_attribute12 => x_null_chr,
                                                             p_attribute13 => x_null_chr,
                                                             p_attribute14 => x_null_chr,
                                                             p_attribute15 => x_null_chr,
                                                             p_attribute_category => x_null_chr,
                                                             p_creation_date => SYSDATE,
                                                             p_created_by => 8031,
                                                             p_last_update_date => SYSDATE,
                                                             p_last_updated_by => 8031,
                                                             p_last_update_login => NULL,
                                                             x_return_status => errbuf,
                                                             x_msg_count => x_msg_count,
                                                             x_msg_data => x_msg_data);
                                                             
                    IF px_resolution_map_detail_id IS NULL THEN
                       if x_msg_count > 0 then
                        for v_index in 1 .. x_msg_count loop
                          fnd_msg_pub.get(p_msg_index     => v_index,
                                          p_encoded       => 'F',
                                          p_data          => x_msg_data,
                                          p_msg_index_out => L_msg_index_out);
                          x_msg_data := substr(x_msg_data, 1, 200) || chr(10);
                          fnd_file.put_line(fnd_file.log, x_msg_data);
                          fnd_file.put_line(fnd_file.log,'============================================================');
                        end loop;
                      end if;
                    END IF;
                
               END IF;                                                
  END LOOP;
  END LOOP;  
  COMMIT;                                               
END map_res_codes;


-- Author  : ADI.SAFIN
-- Created : 15-Jul-13 14:49:13
-- Purpose : Load new resoultion codes to the Sub resolution 3

PROCEDURE load_res3 (retcode OUT NUMBER,
                     errbuf  OUT VARCHAR2) IS
                     
  CURSOR RES3 IS 
    SELECT RES3.LOOKUP_CODE,RES3.MEANING,RES3.DESCRIPTION,RES3.ATTRIBUTE1
    FROM   xxcs_load_lookup RES3
    WHERE  res3.lookup_type = 'XXCS_FULL_SUBRESOLUTION3_NLU';
    
  V_LOOKUP_TYPE         fnd_lookup_values.lookup_type%TYPE := 'XXCS_FULL_SUBRESOLUTION3_NLU';
  x_rowid               fnd_lookup_values.meaning%TYPE;
  x_attribute_category  fnd_lookup_values.Attribute_Category%TYPE;
  x_attribute1          fnd_lookup_values.Attribute1%TYPE;
  x_attribute_NULL      fnd_lookup_values.Attribute1%TYPE := NULL;

  v_meaning             fnd_lookup_values.meaning%TYPE;
  v_description         fnd_lookup_values.Description%TYPE;
  v_lookup              fnd_lookup_values.lookup_code%TYPE;                          
BEGIN
  FOR RS IN RES3 LOOP
     v_lookup := RS.LOOKUP_CODE;
     x_attribute1 := initcap(RS.ATTRIBUTE1);
     v_meaning := RS.MEANING;
     v_description := RS.DESCRIPTION;
        
   
  fnd_lookup_values_pkg.insert_row(x_rowid => x_rowid,
                                         x_lookup_type => V_LOOKUP_TYPE,
                                         x_security_group_id => 0,
                                         x_view_application_id => 170,
                                         x_lookup_code => v_lookup,
                                         x_tag => NULL,
                                         x_attribute_category => V_LOOKUP_TYPE,
                                         x_attribute1 => x_attribute1,
                                         x_attribute2 => x_attribute_NULL,
                                         x_attribute3 => x_attribute_NULL,
                                         x_attribute4 => x_attribute_NULL,
                                         x_enabled_flag => 'Y',
                                         x_start_date_active => SYSDATE,
                                         x_end_date_active => NULL,
                                         x_territory_code => x_attribute_NULL,
                                         x_attribute5 => x_attribute_NULL,
                                         x_attribute6 => x_attribute_NULL,
                                         x_attribute7 => x_attribute_NULL,
                                         x_attribute8 => x_attribute_NULL,
                                         x_attribute9 => x_attribute_NULL,
                                         x_attribute10 => x_attribute_NULL,
                                         x_attribute11 => x_attribute_NULL,
                                         x_attribute12 => x_attribute_NULL,
                                         x_attribute13 => x_attribute_NULL,
                                         x_attribute14 => x_attribute_NULL,
                                         x_attribute15 => x_attribute_NULL,
                                         x_meaning => v_meaning,
                                         x_description => V_DESCRIPTION,
                                         x_creation_date => SYSDATE,
                                         x_created_by => 8031,
                                         x_last_update_date => SYSDATE,
                                         x_last_updated_by => 8031,
                                         x_last_update_login => NULL);

            IF x_rowid IS NULL THEN
               INSERT INTO xxcs_load_look_err(num_val,err_code,err_desc)
               VALUES (199,199,'lookup VALUE Not enter to  '||RS.LOOKUP_CODE);
            END IF;   
            COMMIT;
            x_rowid := NULL;
       END LOOP;
END  LOAD_RES3;            

-- Author  : ADI.SAFIN
-- Created : 15-Jul-13 14:49:13
-- Purpose : prepare the lookup for loading

PROCEDURE set_lookups (retcode OUT NUMBER,
                       errbuf  OUT VARCHAR2) IS
  
  V_ACTION varchar2(5) := FND_PROFILE.VALUE('XXCS_SET_RESOLUTIONS');
    
BEGIN
  
  -- inactive old resolution codes
  IF V_ACTION = 'OLD' THEN
     UPDATE fnd_lookup_values flv
     SET    FLV.END_DATE_ACTIVE = SYSDATE - 1
     WHERE  FLV.LOOKUP_TYPE = 'REQUEST_RESOLUTION_CODE'
     AND    FLV.ENABLED_FLAG = 'Y'   
     AND    FLV.END_DATE_ACTIVE IS NULL
     AND    flv.start_date_active < SYSDATE - 2;
  END IF;        
      
  -- delete new resolution codes already created
  IF V_ACTION = 'NEW' THEN
     DELETE 
     FROM   fnd_lookup_values flv
     WHERE  FLV.LOOKUP_TYPE IN('REQUEST_RESOLUTION_CODE','XXCS_FULL_SUBRESOLUTION1_NLU','XXCS_FULL_SUBRESOLUTION2_NLU','XXCS_FULL_SUBRESOLUTION3_NLU')-- 'XXCS_FULL_SUBRESOLUTION1_NLU'
     AND    FLV.ENABLED_FLAG = 'Y'   
     AND    flv.creation_date > SYSDATE - 1;
  END IF; 
     
  -- delete category to res mapping
  IF V_ACTION = 'MAP' THEN
     DELETE CS_SR_RES_CODE_MAPPING_DETAIL kk
     WHERE  kk.creation_date > SYSDATE - 1;
  END IF;

  -- Update INCIDENT_ATTRIBUTE_10 in order to support old SR.
  IF V_ACTION = 'ATT' THEN
     UPDATE CS_INCIDENTS_ALL_B CAL 
     SET    CAL.INCIDENT_ATTRIBUTE_10 = to_char(CAL.creation_date,'DD-MON-YYYY HH24:MI:SS');
  END IF;
     
END set_lookups;
      
end XXCS_RES_UTIL;
/
