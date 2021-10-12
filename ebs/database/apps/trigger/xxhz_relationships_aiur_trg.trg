create or replace trigger xxhz_relationships_aiur_trg
  after insert or update on HZ_RELATIONSHIPS
  for each row

when (NEW.last_updated_by <> 4290 and 
      NEW.relationship_code = 'GLOBAL_ULTIMATE_OF' and 
      NEW.relationship_type = 'XX_OBJ_GLOBAL' and
      NEW.object_table_name = 'HZ_PARTIES'    and
      NEW.object_type       = 'ORGANIZATION'  and
      NEW.subject_type      = 'ORGANIZATION'
      
      )
DECLARE
  --------------------------------------------------------------------
  --  name:            XXHZ_RELATIONSHIPS_AIR_TRG
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   25/02/2015
  --------------------------------------------------------------------
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  25/02/2015  Dalit A. Raviv    initial build  CHG0033819
  --                                     check if GAM reltionship created. 
  --                                     if yes validat both acoount and sync to SFDC
  --------------------------------------------------------------------
  -- local variables here
  l_oa2sf_rec  xxobjt_oa2sf_interface_pkg.t_oa2sf_rec;
  l_err_code   VARCHAR2(10) := 0;
  l_err_desc   VARCHAR2(2500) := NULL;
  l_entity_id  NUMBER := NULL;
  l_entity_id1 number := null;
BEGIN
  -- l_entity_id = cust_account_id
  l_entity_id := xxobjt_oa2sf_interface_pkg.is_valid_to_sf('PARTY',
                                                           :new.object_id);
                                                           
  l_entity_id1 := xxobjt_oa2sf_interface_pkg.is_valid_to_sf('PARTY',
                                                           :new.subject_id);                                                           
                                                           
  IF l_entity_id IS NOT NULL THEN
    BEGIN
      -- Get cust account id
      SELECT  HCA.CUST_ACCOUNT_ID
      INTO    l_entity_id
      FROM    hz_cust_accounts hca
      WHERE   hca.party_id = :new.object_id
      AND     hca.status = 'A';
        
      l_oa2sf_rec.source_id   := l_entity_id;
      l_oa2sf_rec.source_name := 'ACCOUNT';
      xxobjt_oa2sf_interface_pkg.insert_into_interface(p_oa2sf_rec => l_oa2sf_rec, -- i t_oa2sf_rec,
                                                       p_err_code  => l_err_code, -- o v
                                                       p_err_msg   => l_err_desc); -- o v
    EXCEPTION 
      WHEN OTHERS THEN 
         NULL;
    END; 
    
  END IF;
  
  IF l_entity_id1 IS NOT NULL THEN
    BEGIN
      -- Get cust account id
      SELECT  HCA.CUST_ACCOUNT_ID
      INTO    l_entity_id1
      FROM    hz_cust_accounts hca
      WHERE   hca.party_id = :new.subject_id
      AND     hca.status = 'A';
              
      l_oa2sf_rec.source_id   := l_entity_id1;
      l_oa2sf_rec.source_name := 'ACCOUNT';
      xxobjt_oa2sf_interface_pkg.insert_into_interface(p_oa2sf_rec => l_oa2sf_rec, -- i t_oa2sf_rec,
                                                       p_err_code  => l_err_code, -- o v
                                                       p_err_msg   => l_err_desc); -- o v
    EXCEPTION 
      WHEN OTHERS THEN 
         NULL;
    END; 
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    NULL;
END xxhz_cust_accounts_air_trg1;
/
