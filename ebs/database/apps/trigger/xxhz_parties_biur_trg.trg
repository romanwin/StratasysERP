CREATE OR REPLACE TRIGGER xxhz_parties_biur_trg
--------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  08/02/10   Ella Malchi     Initial Build
  --     1.1  28/02/10   Vitaly K        IF INSERTING OR (UPDATING AND :OLD.country<>:NEW.country) THEN..was added
  --     1.2  01/09/2020 Roman W.        CHG0047450 - before change "Customer Operating Unit/ATTRIBUTE3" required validation , that exist site in new OU
  --     1.3  28/01/2020 Roman W.        CHG0047450 - added error handling on "xxssys_strataforce_events2_pkg.is_acct_ou_valid"
  --                                                           if '0' != l_error_code then
  --                                                              l_exception := l_error_desc;
  --                                                              raise MY_EXCEPTION;
  --                                                           end if;
  --     1.4  31/01/2021 Roman W.        CHG0047450 - removed limitation Category_Code = 'CUSTOMER' 
  ---------------------------------------------------------------------------
  BEFORE INSERT OR UPDATE OF country ON hz_parties
  FOR EACH ROW
  WHEN (NEW.party_type = 'ORGANIZATION' AND NEW.country IS NOT NULL)
DECLARE
  l_org_id          NUMBER := NULL;
  l_error_code      VARCHAR2(10);
  l_error_desc      VARCHAR2(1000);
  l_validation_flag VARCHAR2(10);
  l_exception       VARCHAR2(10000);
  MY_EXCEPTION EXCEPTION;
BEGIN

  IF INSERTING OR
     (UPDATING AND nvl(:OLD.country, 'XXX') <> nvl(:NEW.country, 'XXX')) THEN
    SELECT flv.attribute1
      INTO l_org_id
      FROM fnd_lookup_values flv
     WHERE flv.lookup_type = 'XXSERVICE_COUNTRIES_SECURITY'
       AND flv.LANGUAGE = 'US'
       AND flv.enabled_flag = 'Y'
       AND lookup_code = :NEW.country;
  
    :NEW.attribute3 := l_org_id;
  END IF;

  -- Added By Roman W. CHG0047450 --
  if UPDATING and :NEW.attribute3 != :OLD.attribute3 and
     :NEW.Party_Type = 'ORGANIZATION'
  --and :NEW.Category_Code = 'CUSTOMER' 
   then
    -- check is exist site with the same OU --
  
    xxssys_strataforce_events2_pkg.is_acct_ou_valid(p_party_id        => :NEW.party_id,
                                                    p_org_id          => :NEW.attribute3,
                                                    p_validation_flag => l_validation_flag,
                                                    p_error_code      => l_error_code,
                                                    p_error_desc      => l_error_desc);
    if '0' != l_error_code then
      l_exception := l_error_desc;
      raise MY_EXCEPTION;
    end if;
  
    if 'N' = l_validation_flag then
      l_exception := 'It is not possible to change an existing "Customer Operating Unit" to new without having at least one site belong to new "Operating Unit". p_party_id = ' ||
                     :NEW.party_id || ',p_org_id = ' || :NEW.attribute3;
      raise MY_EXCEPTION;
    end if;
  
  end if;

EXCEPTION
  WHEN MY_EXCEPTION THEN
    RAISE_APPLICATION_ERROR(-20001, l_exception);
  WHEN OTHERS THEN
    RAISE_APPLICATION_ERROR(-20001,
                            'EXCEPTION_OTHERS Trigger  : XXHZ_CUST_ACCT_SITES_ALL_TRG : ' ||
                            sqlerrm);
END xxhz_parties_biur_trg;
/
