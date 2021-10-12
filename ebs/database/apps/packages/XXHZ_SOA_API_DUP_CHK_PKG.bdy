CREATE OR REPLACE PACKAGE BODY xxhz_soa_api_dup_chk_pkg AS
  --------------------------------------------------------------------
  --  name:               XXHZ_SOA_API_DUP_CHK_PKG 
  --  create by:          yuval tal
  --  Revision:           1.0
  --  creation date:      1.4.20
  --------------------------------------------------------------------
  --  purpose:            general item_classifications methods
  ---------------------------------------------------------------------
  --  ver   date        name            desc
  --  ----  ----------  --------------  -------------------------------
  --  1.0   1.4.20      yuval tal       CHG0047624 initial build
  --  1.1   10/12/2020  Roman W.        CHG0047450 - added procedure : update_to_error_trx  
  ---------------------------------------------------------------------

  ---------------------------------------------------------------------------------------
  -- Ver  Date        Who         Description
  -- ---  ----------  ----------  -------------------------------------------------------
  -- 2.8  30/03/2020  Roman W.    CHG0047450 - Account, Contact interface - ReDo
  ---------------------------------------------------------------------------------------
  PROCEDURE message(p_msg IN VARCHAR2) IS
    l_msg VARCHAR(4000);
  BEGIN
  
    l_msg := to_char(SYSDATE, 'DD/MM/YYYY HH24:MI:SS') || p_msg;
  
    IF fnd_global.conc_request_id > 0 THEN
      fnd_file.put_line(fnd_file.log, l_msg);
    ELSE
      dbms_output.put_line(l_msg);
    END IF;
  
  END message;

  --------------------------------------------------------------------
  --  name:               purge 
  --  create by:          yuval tal
  --  Revision:           1.0
  --  creation date:      1.4.20
  --------------------------------------------------------------------
  --  purpose:     delete audit in xx table incase external key already 
  --               sync to salesforce       
  ---------------------------------------------------------------------
  --  ver     date        name            desc
  --  1.0     1.4.20     yuval tal       CHG0047624 initial build

  ---------------------------------------------------------------------------------------------------------------------------------------------

  PROCEDURE purge(errbuf OUT VARCHAR2, retcode OUT VARCHAR2) IS
  BEGIN
    retcode := '0';
    -- account 
  
    DELETE FROM xxhz_soa_api_dup_chk
     WHERE (source_name, source_id) IN
           (SELECT source_name, source_id
              FROM xxhz_soa_api_dup_chk c, xxsf2_account a
             WHERE source_name = 'STRATAFORCE'
               AND source_id = a.id
               AND object_name = 'ACCOUNT'
               AND external_key__c IS NOT NULL);
  
    message(' Accounts : ' || SQL%ROWCOUNT || ' deleted');
    COMMIT;
  
    -- contacts
  
    DELETE FROM xxhz_soa_api_dup_chk
     WHERE (source_name, source_id) IN
          
           (SELECT source_name, source_id
              FROM xxhz_soa_api_dup_chk c, xxsf2_contact a
             WHERE source_name = 'STRATAFORCE'
               AND source_id = a.id
               AND object_name = 'CONTACT'
               AND external_key__c IS NOT NULL);
  
    message(' Contacts : ' || SQL%ROWCOUNT || ' deleted');
    COMMIT;
    -- sites
    DELETE FROM xxhz_soa_api_dup_chk
     WHERE (source_name, source_id) IN
           (SELECT source_name, source_id
              FROM xxhz_soa_api_dup_chk c, xxsf2_locations loc
             WHERE source_name = 'STRATAFORCE'
               AND object_name = 'SITE'
               AND source_id = loc.id
               AND loc.external_key__c IS NOT NULL);
  
    message(' Sites : ' || SQL%ROWCOUNT || ' deleted');
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      retcode := '2';
      errbuf  := 'Error : xxhz_soa_api_dup_chk_pkg.purge ' || SQLERRM;
  END;
  ----------------------------------------------------------------------------
  -- Ver    When         Who        Descr 
  -- -----  -----------  ---------  ------------------------------------------
  -- 1.0    10/12/2020   Roman W.   CHG0047450
  ----------------------------------------------------------------------------
  procedure update_to_error_trx(p_rec IN xxhz_soa_api_dup_chk%ROWTYPE) is
    -------------------------
    --   Code Section
    -------------------------        
  begin
    UPDATE xxhz_soa_api_dup_chk
       SET last_update_date = SYSDATE, status = 'ERROR'
     WHERE source_id = p_rec.source_id
       AND source_name = p_rec.source_name
       AND object_name = p_rec.object_name;
  
    commit;
  
  end update_to_error_trx;

  --------------------------------------------------------------------
  --  name:               update_trx 
  --  create by:          yuval tal
  --  Revision:           1.0
  --  creation date:      1.4.20
  -------------------------------------------------------------------------------------
  --  purpose:            
  -------------------------------------------------------------------------------------
  --  ver     date        name            desc
  --  1.0     1.4.20      yuval tal       CHG0047624 initial build
  --  1.1     18/06/2020  Roman W         CHG0047450 - added reference to OBJECT_NAME   
  -------------------------------------------------------------------------------------

  PROCEDURE update_trx(p_rec IN xxhz_soa_api_dup_chk%ROWTYPE) IS
  BEGIN
  
    UPDATE xxhz_soa_api_dup_chk
       SET last_update_date        = SYSDATE,
           status                  = 'CREATED',
           last_updated_by         = fnd_global.user_id,
           last_update_login       = fnd_global.login_id,
           object_name             = p_rec.object_name,
           cust_account_id         = p_rec.cust_account_id,
           account_number          = p_rec.account_number,
           site_id                 = p_rec.site_id,
           site_number             = p_rec.site_number,
           contact_id              = p_rec.contact_id,
           location_id             = p_rec.location_id,
           ship_site_use_id        = p_rec.ship_site_use_id,
           bill_site_use_id        = p_rec.bill_site_use_id,
           email_contact_point_id  = p_rec.email_contact_point_id,
           fax_contact_point_id    = p_rec.fax_contact_point_id,
           mobile_contact_point_id = p_rec.mobile_contact_point_id,
           phone_contact_point_id  = p_rec.phone_contact_point_id,
           party_site_id           = p_rec.party_site_id,
           person_party_id         = p_rec.person_party_id,
           contact_party_id        = p_rec.contact_party_id
     WHERE source_id = p_rec.source_id
       AND source_name = p_rec.source_name
       AND object_name = p_rec.object_name; -- Added by Roman 18/06/2020 CHG0047450
  
    COMMIT;
  
  exception
    when no_data_found then
      null;
    
  END;
  --------------------------------------------------------------------
  --  name:               INSERT_TRX 
  --  create by:          yuval tal
  --  Revision:           1.0
  --  creation date:      1.4.20
  --------------------------------------------------------------------
  --  purpose:            
  ---------------------------------------------------------------------
  --  ver     date        name            desc
  --  1.0     1.4.20      yuval tal       CHG0047624 initial build
  --  1.1     18/06/2020  Roman W         CHG0047450 - added reference to OBJECT_NAME   
  --------------------------------------------------------------------------------------

  PROCEDURE insert_trx(p_rec IN OUT xxhz_soa_api_dup_chk%ROWTYPE) IS
  BEGIN
  
    INSERT INTO xxhz_soa_api_dup_chk
      (source_id,
       source_name,
       last_update_date,
       last_updated_by,
       creation_date,
       created_by,
       last_update_login,
       object_name,
       cust_account_id,
       account_number,
       site_id,
       site_number,
       contact_id,
       location_id,
       ship_site_use_id,
       bill_site_use_id,
       email_contact_point_id,
       fax_contact_point_id,
       mobile_contact_point_id,
       phone_contact_point_id,
       party_site_id,
       person_party_id,
       contact_party_id,
       status)
    VALUES
      (p_rec.source_id,
       p_rec.source_name,
       SYSDATE,
       NULL,
       SYSDATE,
       fnd_global.user_id,
       fnd_global.login_id,
       p_rec.object_name,
       p_rec.cust_account_id,
       p_rec.account_number,
       p_rec.site_id,
       p_rec.site_number,
       p_rec.contact_id,
       p_rec.location_id,
       p_rec.ship_site_use_id,
       p_rec.bill_site_use_id,
       p_rec.email_contact_point_id,
       p_rec.fax_contact_point_id,
       p_rec.mobile_contact_point_id,
       p_rec.phone_contact_point_id,
       p_rec.party_site_id,
       p_rec.person_party_id,
       p_rec.contact_party_id,
       'IN_PROCESS');
    COMMIT;
  EXCEPTION
    WHEN dup_val_on_index THEN
    
      SELECT *
        INTO p_rec
        FROM xxhz_soa_api_dup_chk
       WHERE source_id = p_rec.source_id
         AND source_name = p_rec.source_name
         AND object_name = p_rec.object_name; -- Added by Roman 18/06/2020 CHG0047450
  
  END;

END xxhz_soa_api_dup_chk_pkg;
/
