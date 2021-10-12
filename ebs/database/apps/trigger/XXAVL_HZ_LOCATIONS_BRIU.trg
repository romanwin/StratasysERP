CREATE OR REPLACE TRIGGER XXAVL_HZ_LOCATIONS_BRIU
-- (c) COPYRIGHT OAC SERVICES, INC. 2014
-- (AND ALL PREVIOUS VERSIONS)
-- ====================================================================
-- = PROGRAM NAME: XXAVL_HZ_LOCATIONS_BRIU
-- = SOURCE NAME : XXAVL_HZ_LOCATIONS_BRIU.sql
-- = AUTHOR      : Michael B. Allen
-- = DATE CREATED: March 24, 2014
-- = APPLICATION : Oracle/Avalara AvaTax
-- = VERSION     : 1.0
-- = DESCRIPTION : This trigger is used to transmit address information
-- =               for US addresses to Avalara for validation.  Avalara
-- =               will return a properly formated address, if the
-- =               address was validated or an error message if it was
-- =               not.
-- =
-- ====================================================================
-- = MODIFICATION HISTORY
-- ====================================================================
--
-- DATE        NAME           DESCRIPTION
-- --------------------------------------------------------------------
-- DD MON YY   F.LAST         DESCRIPTION OF MODIFICATION
-- 12 AUG 16   L.Sarangi      INC0066076  avalara issue Need to Update a Incident number
-- ====================================================================

BEFORE INSERT OR UPDATE ON AR.HZ_LOCATIONS
  REFERENCING NEW AS New OLD AS Old
  FOR EACH ROW
  -- WHEN (New.application_id in (222,660,695))

DECLARE

  l_address_tbl   xxavl_dir_xml_pkg.g_address_validation_tab;
  l_error_message VARCHAR2(2000);
  l_status        VARCHAR2(1);
  --Is it Required to Call avalara for Address validation for Address Update Case
  --L.Sarangi 12 Aug 2016
  l_call_avalara VARCHAR2(1) := 'Y';

  FUNCTION validate_this_country(p_country_code IN VARCHAR2) RETURN BOOLEAN IS
  
    l_boolean BOOLEAN;
  
    CURSOR flv_cursor(p_lookup_code IN VARCHAR2) IS
      SELECT flv.meaning
      FROM   fnd_lookup_values flv
      WHERE  flv.lookup_type = 'XXAVL_ADDR_VALIDTN_COUNTRIES'
      AND    flv.lookup_code = p_lookup_code
      AND    flv.enabled_flag = 'Y'
      AND    SYSDATE BETWEEN flv.start_date_active AND
	 nvl(flv.end_date_active, SYSDATE + 1);
    flv_rec flv_cursor%ROWTYPE;
  
  BEGIN
  
    flv_rec.meaning := NULL;
    OPEN flv_cursor(p_country_code);
    FETCH flv_cursor
      INTO flv_rec;
    IF flv_cursor%FOUND THEN
      l_boolean := TRUE;
    ELSE
      l_boolean := FALSE;
    END IF;
    CLOSE flv_cursor;
  
    RETURN l_boolean;
  
  END validate_this_country;

BEGIN

  IF nvl(fnd_profile.value('AVA_VALIDATE_ADDRESSES'), 'N') = 'Y' AND
     validate_this_country(:new.country) THEN
  
    -- ====================================================================
    -- = Load address info into address table....
    -- ====================================================================
  
    l_address_tbl(1).address1 := :new.address1;
    l_address_tbl(1).address2 := :new.address2;
    l_address_tbl(1).address3 := :new.address3;
    l_address_tbl(1).address4 := :new.address4;
    l_address_tbl(1).city := :new.city;
    l_address_tbl(1).postal_code := :new.postal_code;
    l_address_tbl(1).state := :new.state;
    l_address_tbl(1).county := :new.county;
    l_address_tbl(1).country := :new.country;
    l_address_tbl(1).taxregionid := '0';
    l_address_tbl(1).textcase := 'Default';
    l_address_tbl(1).coordinates := 'false';
    l_address_tbl(1).taxability := 'false';
    l_address_tbl(1).request_date := to_char(SYSDATE, 'yyyy-mm-dd');
    l_address_tbl(1).latitude := NULL;
    l_address_tbl(1).longitude := NULL;
    l_address_tbl(1).fipscode := NULL;
    l_address_tbl(1).carrierroute := NULL;
    l_address_tbl(1).postnet := NULL;
    l_address_tbl(1).addresstype := NULL;
    l_address_tbl(1).validatestatus := NULL;
    l_address_tbl(1).geocodetype := NULL;
    l_address_tbl(1).taxable := NULL;
    l_address_tbl(1).resultcode := NULL;
    l_address_tbl(1).errormessage := NULL;
  
    -- ====================================================================
    -- = If it is Update Address,Is it required to Validate with avalara
    -- = L.Sarangi  12 Aug 2016
    -- ====================================================================
    IF updating THEN
      -- For Update Address Case
      IF upper(nvl(:old.address1, '-999')) !=
         upper(nvl(:new.address1, '-999')) OR
         upper(nvl(:old.address2, '-999')) !=
         upper(nvl(:new.address2, '-999')) OR
         upper(nvl(:old.address3, '-999')) !=
         upper(nvl(:new.address3, '-999')) OR
        --After unsuccessful validation this Code added to Address 4'** AVALARA UNABLE TO VALIDATE ADDRESS ** ' 
        --So not added Address4 for the Comparison
        --Or nvl(:old.address4,'-999') !=nvl(:new.address4,'-999')
         upper(nvl(:old.city, '-999')) != upper(nvl(:new.city, '-999')) OR
         upper(nvl(:old.postal_code, '-999')) !=
         upper(nvl(:new.postal_code, '-999')) OR
         upper(nvl(:old.state, '-999')) != upper(nvl(:new.state, '-999')) OR
         upper(nvl(:old.county, '-999')) != upper(nvl(:new.county, '-999')) OR
         upper(nvl(:old.country, '-999')) !=
         upper(nvl(:new.country, '-999')) THEN
        l_call_avalara := 'Y';
      ELSE
        l_call_avalara := 'N';
      END IF;
    END IF;
  
    -- ====================================================================
    -- = Pass the address table to the address validation procedure....
    -- ====================================================================
    IF l_call_avalara = 'Y' THEN
      --Added 12 AUG 2016 L.Sarangi
      xxavl_dir_xml_pkg.address_validation(p_address_val_tab => l_address_tbl, -- in out table def below
			       p_error_message   => l_error_message -- only for exception failure in proc
			       );
    
      IF l_error_message IS NOT NULL THEN
        RAISE fnd_api.g_exc_unexpected_error;
      END IF; -- l_error_message is not null
    
      -- ====================================================================
      -- = If we are here then the address validation procedure had no
      -- = unexpected errors (not to be confused with whether the address
      -- = is valid or not).
      -- ====================================================================
    
      :new.address1    := l_address_tbl(1).address1;
      :new.address2    := l_address_tbl(1).address2;
      :new.address3    := l_address_tbl(1).address3;
      :new.city        := l_address_tbl(1).city;
      :new.county      := l_address_tbl(1).county;
      :new.state       := l_address_tbl(1).state;
      :new.country     := nvl(l_address_tbl(1).country, :new.country);
      :new.postal_code := l_address_tbl(1).postal_code;
    
      -- ====================================================================
      -- = Set the status value based upon the ResultCode...
      -- ====================================================================
    
      IF upper(l_address_tbl(1).resultcode) = 'SUCCESS' THEN
        l_status := '0';
      ELSE
        l_status := '6';
      END IF; -- upper(l_address_tbl(1).ResultCode) = 'SUCCESS'
    
      :new.validation_status_code := l_status;
      :new.date_validated         := SYSDATE;
    
      -- ====================================================================
      -- = Set the validated_flag and the address4 value.
      -- ====================================================================
    
      IF l_status = '0' THEN
        :new.validated_flag := 'Y';
        :new.address4       := NULL;
      ELSE
        :new.validated_flag := 'N';
        -- display status to users on Address4 column
        :new.address4 := '** AVALARA UNABLE TO VALIDATE ADDRESS ** ' ||
		 substr(l_address_tbl(1).errormessage, 1, 239);
      END IF; -- l_status = '0'
    END IF; -- nvl(fnd_profile.value('AVA_DEBUG_MESSAGES'),'N')
  END IF; --  l_call_avalara = 'Y' then Call AVALARA 12 Aug 2016
EXCEPTION
  WHEN fnd_api.g_exc_error THEN
    xxavl_write_pkg_log('AVALARA.TRIGGER.XXAVL_HZ_LOCATIONS_BRIU',
		NULL,
		l_error_message);
    RAISE fnd_api.g_exc_error;
  WHEN fnd_api.g_exc_unexpected_error THEN
    xxavl_write_pkg_log('AVALARA.TRIGGER.XXAVL_HZ_LOCATIONS_BRIU',
		NULL,
		l_error_message);
    RAISE fnd_api.g_exc_unexpected_error;
  WHEN OTHERS THEN
    xxavl_write_pkg_log('AVALARA.TRIGGER.XXAVL_HZ_LOCATIONS_BRIU',
		NULL,
		'OTHERS ERROR: ' || SQLERRM);
    RAISE fnd_api.g_exc_unexpected_error;
END;
/
