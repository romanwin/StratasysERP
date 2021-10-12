CREATE OR REPLACE PACKAGE BODY xxssys_strataforce_events2_pkg IS
  ---------------------------------------------------------------------------------------
  -- Ver  Date        Who         Description
  -- ---  ----------  ----------  -------------------------------------------------------
  -- 1.0  30/03/2020  Roman W.    CHG0047450 - Account, Contact interface - ReDo
  -- 1.1  01/09/2020  Roman W.    CHG0047450 - checking is exists site with account new OU
  -- 1.2  4.1.2021    yuval tal   CHG0048217 add populate_inactive_site_events
  -- 1.3  28/01/2020  Roman W.    CHG0047450 - is_acct_ou_valid : TOO_MANY_ROWS bug fix  
  -- 1.4  24/06/2021  Roman W.    CHG0047450 - Account, Contact interface - ReDo
  --                                Added to acct_site_updpdate_trg SITE Status = 'A'  
  ---------------------------------------------------------------------------------------

  ---------------------------------------------------------------------------------------
  -- Ver  Date        Who         Description
  -- ---  ----------  ----------  -------------------------------------------------------
  -- 1.0  30/03/2020  Roman W.    CHG0047450 - Account, Contact interface - ReDo
  ---------------------------------------------------------------------------------------
  PROCEDURE message(p_msg IN VARCHAR2) IS
    l_msg VARCHAR(4000);
  BEGIN
  
    l_msg := to_char(SYSDATE, 'DD/MM/YYYY HH24:MI:SS  ') || p_msg;
  
    IF fnd_global.conc_request_id > 0 THEN
      fnd_file.put_line(fnd_file.log, l_msg);
    ELSE
      dbms_output.put_line(l_msg);
    END IF;
  
  END message;
  ---------------------------------------------------------------------------------------
  -- Ver   When        Who           Descr
  -- ----  ----------  ------------  ----------------------------------------------------
  -- 1.0   30/03/2020  Roman W.      CHG0047450 - Account, Contact interface - ReDo
  ---------------------------------------------------------------------------------------
  PROCEDURE find_alternative_site(p_cust_account_id       IN NUMBER,
                                  p_cust_acct_site_id     IN NUMBER,
                                  p_party_site_id         IN NUMBER,
                                  p_org_id                IN NUMBER,
                                  p_site_country          IN VARCHAR2,
                                  p_out_cust_acct_site_id OUT NUMBER,
                                  p_update_account_addr   OUT VARCHAR2,
                                  p_error_code            OUT VARCHAR2,
                                  p_error_desc            OUT VARCHAR2) IS
    -----------------------------
    --     Local Definition
    -----------------------------
  
    -- ACCOUNT_ADDRESS_FLAG=Y / ACCOUNT / COUNTRY / OU /
    CURSOR site1_cur(c_cust_account_id   NUMBER,
                     c_cust_acct_site_id NUMBER,
                     c_org_id            NUMBER,
                     c_party_site_id     NUMBER,
                     c_site_country      VARCHAR2) IS
      SELECT xsd.oracle_site_id, xsd.cust_account_id, xsd.party_site_id
        FROM xxhz_site_dtl_v xsd
       WHERE 1 = 1
         AND nvl(xsd.account_address_flag, 'N') = 'Y'
         AND xsd.site_status = 'Active'
         AND xsd.cust_account_id = c_cust_account_id
         AND xsd.party_site_id != c_party_site_id
         AND xsd.oracle_site_id != c_cust_acct_site_id
         AND xsd.org_id = c_org_id
         AND xsd.site_country = c_site_country;
  
    -- ACCOUNT & COUNTRY & OU & ( PRIMARY_SHIP_TO || oracle_site_id )
    CURSOR site2_cur(c_cust_account_id   NUMBER,
                     c_cust_acct_site_id NUMBER,
                     c_org_id            NUMBER,
                     c_party_site_id     NUMBER,
                     c_site_country      VARCHAR2) IS
      SELECT xsd.oracle_site_id, xsd.cust_account_id, xsd.party_site_id
        FROM xxhz_site_dtl_v xsd
       WHERE 1 = 1
         AND xsd.site_status = 'Active'
         AND xsd.site_usage = 'Ship To'
         AND xsd.cust_account_id = c_cust_account_id
         AND xsd.party_site_id != c_party_site_id
         AND xsd.oracle_site_id != c_cust_acct_site_id
         AND xsd.org_id = c_org_id
         AND xsd.site_country = c_site_country
       ORDER BY decode(primary_ship_to, 'True', 0, 1), xsd.oracle_site_id;
  
    -- ACCOUNT & COUNTRY & OU & ( PRIMARY_BILL_TO || ORACLE_SITE_ID )
    CURSOR site3_cur(c_cust_account_id   NUMBER,
                     c_cust_acct_site_id NUMBER,
                     c_org_id            NUMBER,
                     c_party_site_id     NUMBER,
                     c_site_country      VARCHAR2) IS
      SELECT xsd.oracle_site_id, xsd.cust_account_id, xsd.party_site_id
        FROM xxhz_site_dtl_v xsd
       WHERE 1 = 1
         AND xsd.site_status = 'Active'
         AND xsd.site_usage = 'Bill To'
         AND xsd.cust_account_id = c_cust_account_id
         AND xsd.party_site_id != c_party_site_id
         AND xsd.oracle_site_id != c_cust_acct_site_id
         AND xsd.org_id = c_org_id
         AND xsd.site_country = c_site_country
       ORDER BY decode(xsd.primary_bill_to, 'True', 0, 1),
                xsd.oracle_site_id;
  
    -----------------------------
    --     Code Section
    -----------------------------
  BEGIN
    p_error_code := '0';
    p_error_desc := NULL;
  
    message('-- find_alternative_site --');
  
    --- 1 ---
    FOR site1_ind IN site1_cur(p_cust_account_id,
                               p_cust_acct_site_id,
                               p_org_id,
                               p_party_site_id,
                               p_site_country) LOOP
    
      p_out_cust_acct_site_id := site1_ind.oracle_site_id;
      --p_out_party_site_id     := site1_ind.party_site_id;
      p_update_account_addr := 'N';
    
      message('-- 1 ACCOUNT_ADDRESS_FLAG=Y / ACCOUNT / COUNTRY / OU /  -- ');
      message('cust_acct_site_id   :' || site1_ind.oracle_site_id);
      message('party_site_id       :' || site1_ind.party_site_id);
      message('update_account_addr : N');
      RETURN;
    END LOOP;
  
    --- 2 ---
    FOR site2_ind IN site2_cur(p_cust_account_id,
                               p_cust_acct_site_id,
                               p_org_id,
                               p_party_site_id,
                               p_site_country) LOOP
      p_out_cust_acct_site_id := site2_ind.oracle_site_id;
      --p_out_party_site_id     := site2_ind.party_site_id;
      p_update_account_addr := 'Y';
    
      message('-- 2 ACCOUNT & COUNTRY & OU & ( PRIMARY_SHIP_TO || oracle_site_id )  -- ');
      message('cust_acct_site_id   :' || site2_ind.oracle_site_id);
      --      message('party_site_id       :' || site2_ind.party_site_id);
      message('update_account_addr : Y');
    
      RETURN;
    END LOOP;
  
    --- 4 ---
    FOR site3_ind IN site3_cur(p_cust_account_id,
                               p_cust_acct_site_id,
                               p_org_id,
                               p_party_site_id,
                               p_site_country) LOOP
      p_out_cust_acct_site_id := site3_ind.oracle_site_id;
      --p_out_party_site_id     := site3_ind.party_site_id;
      p_update_account_addr := 'Y';
    
      message('-- 4 ACCOUNT & COUNTRY & OU & ( PRIMARY_BILL_TO || ORACLE_SITE_ID )   -- ');
      message('cust_acct_site_id   :' || p_out_cust_acct_site_id);
      --      message('party_site_id       :' || p_out_party_site_id);
      message('update_account_addr : Y');
    
      RETURN;
    
    END LOOP;
  
  EXCEPTION
    WHEN OTHERS THEN
      p_error_code := '2';
      p_error_desc := 'EXCEPTION_OTHERS XXSSYS_STRATAFORCE_EVENTS2_PKG.find_alternative_site() - ' ||
                      SQLERRM;
    
  END find_alternative_site;
  ---------------------------------------------------------------------------------------
  -- Concurrent :  XX HZ Sync Account Address / XXHZACCADDR
  ---------------------------------------------------------------------------------------
  -- Ver  Date        Who         Description
  -- ---  ----------  ----------  -------------------------------------------------------
  -- 1.0  27/03/2020  Roman W.    CHG0047450 - Account, Contact interface - ReDo
  -- 1.1  31/03/2020  Roman W.    CHG0047450 - added XXHZ_SITE_DTL_V.account_status
  ---------------------------------------------------------------------------------------
  PROCEDURE sync_account_address(errbuf OUT VARCHAR2, retcode OUT NUMBER) IS
    -----------------------------
    --    Local Definition
    -----------------------------
    CURSOR site_inactiv_cur IS
      SELECT xsd.account_number,
             xsd.cust_account_id,
             xsd.oracle_site_number,
             xsd.oracle_site_id,
             xsd.site_country,
             xsd.org_id,
             xsd.party_site_id
        FROM xxhz_site_dtl_v xsd, xxsf2_account xa
       WHERE 1 = 1
            --      AND    xsd.account_number = '13780'
         AND xsd.account_address_flag = 'Y'
         AND site_status = 'Inactive'
         AND xa.extshipsiteid__c = xsd.oracle_site_id;
  
    l_old_cust_acct_site_rec hz_cust_account_site_v2pub.cust_acct_site_rec_type;
    l_new_cust_acct_site_rec hz_cust_account_site_v2pub.cust_acct_site_rec_type;
  
    l_party_site_number VARCHAR2(300);
    l_error_code        VARCHAR2(10);
    l_error_desc        VARCHAR2(3000);
  
    l_cust_account_id       NUMBER;
    l_cust_acct_site_id     NUMBER;
    l_org_id                NUMBER;
    l_party_site_id         NUMBER;
    l_site_country          VARCHAR2(300);
    l_update_account_addr   VARCHAR2(10);
    l_new_cust_acct_site_id NUMBER;
    l_new_party_site_id     NUMBER;
    l_object_version_number NUMBER;
  
    l_mail_body CLOB;
  
    --    x_return_status         VARCHAR2(1000);
    --    x_msg_count             NUMBER(10);
    --    x_msg_data              VARCHAR2(1000);
    -----------------------------
    --    Code Section
    -----------------------------
  BEGIN
    errbuf  := NULL;
    retcode := '0';
    message('-- Start --');
    FOR site_inactiv_ind IN site_inactiv_cur LOOP
    
      l_cust_acct_site_id     := site_inactiv_ind.oracle_site_id;
      l_cust_account_id       := site_inactiv_ind.cust_account_id;
      l_org_id                := site_inactiv_ind.org_id;
      l_party_site_id         := site_inactiv_ind.party_site_id;
      l_site_country          := site_inactiv_ind.site_country;
      l_update_account_addr   := NULL;
      l_new_cust_acct_site_id := NULL;
    
      message('----------------------------------------------');
      message('ACCOUNT_NUMBER :' || site_inactiv_ind.account_number);
      message('CUST_ACCOUNT_ID :' || site_inactiv_ind.cust_account_id);
      message('ORACLE_SITE_NUMBER :' ||
              site_inactiv_ind.oracle_site_number);
      message('ORACLE_SITE_ID :' || site_inactiv_ind.oracle_site_id);
      message('SITE_COUNTRY :' || site_inactiv_ind.site_country);
      message('ORG_ID :' || site_inactiv_ind.org_id);
      message('PARTY_SITE_ID :' || site_inactiv_ind.party_site_id);
    
      -- Find alternative for
      find_alternative_site(p_cust_account_id       => l_cust_account_id,
                            p_cust_acct_site_id     => l_cust_acct_site_id,
                            p_org_id                => l_org_id,
                            p_party_site_id         => l_party_site_id,
                            p_site_country          => l_site_country,
                            p_out_cust_acct_site_id => l_new_cust_acct_site_id,
                            --p_out_party_site_id     => l_new_party_site_id,
                            p_update_account_addr => l_update_account_addr,
                            p_error_code          => l_error_code,
                            p_error_desc          => l_error_desc);
    
      IF l_error_code = 0 AND l_new_cust_acct_site_id IS NULL THEN
      
        -- prepare info for mail
      
        message('No alternative site found ');
        -- contatinate info into clob to be send later
        -- l_mail_body :=dbms_lob.append ()....
        CONTINUE;
      
      ELSIF l_error_code != '0' THEN
      
        message(l_error_desc);
        retcode := greatest(l_error_code, retcode);
        errbuf  := l_error_desc;
        CONTINUE;
      END IF;
    
      mo_global.init('AR');
      mo_global.set_policy_context('S', site_inactiv_ind.org_id);
    
      IF 'Y' = l_update_account_addr THEN
        --- Calculate object_version_number ---
        SELECT s.object_version_number
          INTO l_object_version_number
          FROM hz_cust_acct_sites_all s
         WHERE s.cust_acct_site_id = l_new_cust_acct_site_id;
      
        l_new_cust_acct_site_rec.cust_acct_site_id := l_new_cust_acct_site_id;
        l_new_cust_acct_site_rec.attribute4        := 'Y';
      
        message('update new site attribute4 = ''Y''');
        xxhz_soa_api_pkg.update_acct_site(p_cust_acct_site_rec    => l_new_cust_acct_site_rec,
                                          p_object_version_number => l_object_version_number,
                                          p_api_status            => l_error_code,
                                          p_error_msg             => l_error_desc);
        IF 'S' != l_error_code THEN
          message(l_error_desc);
          retcode := greatest(l_error_code, retcode);
          errbuf  := l_error_desc;
          -- ????? add error to mail
          CONTINUE;
        END IF;
      
      END IF;
    
      l_old_cust_acct_site_rec.cust_acct_site_id := site_inactiv_ind.oracle_site_id;
      --l_old_cust_acct_site_rec.cust_account_id   := site_inactiv_ind.cust_account_id;
      --l_old_cust_acct_site_rec.party_site_id     := site_inactiv_ind.party_site_id;
      --l_old_cust_acct_site_rec.org_id            := site_inactiv_ind.org_id;
      l_old_cust_acct_site_rec.attribute4 := 'N';
    
      SELECT s.object_version_number
        INTO l_object_version_number
        FROM hz_cust_acct_sites_all s
       WHERE s.cust_acct_site_id =
             l_old_cust_acct_site_rec.cust_acct_site_id;
    
      message('update old site attribute4 = ''N''');
      xxhz_soa_api_pkg.update_acct_site(p_cust_acct_site_rec    => l_old_cust_acct_site_rec,
                                        p_object_version_number => l_object_version_number,
                                        p_api_status            => l_error_code,
                                        p_error_msg             => l_error_desc);
      IF 'S' != l_error_code THEN
        message(l_error_desc);
        -- ????? add error to mail
        retcode := greatest(l_error_code, retcode);
        errbuf  := l_error_desc;
      
        CONTINUE;
      END IF;
    
      message('create event :  ENTITY_ID = ' ||
              l_new_cust_acct_site_rec.cust_acct_site_id);
      --- Create event --
      xxssys_strataforce_events_pkg.insert_account_addr_event(p_cust_acct_site_id => l_new_cust_acct_site_rec.cust_acct_site_id,
                                                              p_party_site_number => NULL,
                                                              p_last_updated_by   => fnd_global.user_id,
                                                              p_created_by        => fnd_global.user_id,
                                                              p_trigger_name      => 'Conc :XXHZACCADDR(' ||
                                                                                     fnd_global.conc_request_id || ')',
                                                              p_trigger_action    => 'UPDATE');
    
      COMMIT;
    
    END LOOP;
  
    -- mail alert for failures
  
    IF l_mail_body IS NOT NULL THEN
      message('Sending mail to ...');
      -- send mail
    END IF;
  
    message('-- End --');
  EXCEPTION
    WHEN OTHERS THEN
    
      errbuf  := 'EXCEPTION_OTHERS XXSSYS_STRATAFORCE_EVENTS2_PKG.sync_account_address() - ' ||
                 SQLERRM;
      retcode := '2';
    
      message(errbuf);
    
  END sync_account_address;

  ---------------------------------------------------------------------------------------
  -- Ver  Date        Who         Description
  -- ---  ----------  ----------  -------------------------------------------------------
  -- 1.0  17/06/2020  Roman W.    CHG0047450 - Account, Contact interface - ReDo
  ---------------------------------------------------------------------------------------
  PROCEDURE acct_site_delete_trg(p_cust_account_id        IN NUMBER,
                                 p_cust_acct_site_id      IN NUMBER,
                                 p_old_sf_account_address IN VARCHAR2,
                                 p_error_code             OUT VARCHAR2,
                                 p_error_desc             OUT VARCHAR2) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
    -------------------------
    --   Local Definition
    -------------------------
    l_count NUMBER;
  
    -------------------------
    --    Code Section
    -------------------------
  
  BEGIN
    p_error_code := '0';
    p_error_desc := NULL;
  
    IF 'Y' = p_old_sf_account_address THEN
      SELECT COUNT(*)
        INTO l_count
        FROM hz_cust_acct_sites hcas
       WHERE hcas.cust_account_id = p_cust_account_id
         AND hcas.cust_acct_site_id != p_cust_acct_site_id
         AND hcas.status = 'A'
         AND nvl(hcas.attribute4, 'N') = 'Y';
    
      IF 0 = l_count THEN
        p_error_code := '0';
        p_error_desc := 'You cannot delete a site marked as "SF Account Address"';
      END IF;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      p_error_code := '2';
      p_error_desc := 'EXCEPTION_OTHERS xxssys_strataforce_events2_pkg(' ||
                      p_cust_account_id || ',' || p_cust_acct_site_id || ',' ||
                      p_old_sf_account_address || ') - ' || SQLERRM;
  END acct_site_delete_trg;
  -----------------------------------------------------------------------------------
  -- Ver   When        Who        Descr
  -- ----  ----------  ---------  ---------------------------------------------------
  -- 1.0   01/09/2020  Roman W.   CHG0047450
  -- 1.1   28/01/2020  Roman W.   CHG0047450 - TOO_MANY_ROWS bug fix
  -----------------------------------------------------------------------------------
  PROCEDURE is_acct_ou_valid(p_party_id        IN NUMBER, -- 8649223
                             p_org_id          IN NUMBER,
                             p_validation_flag OUT VARCHAR2,
                             p_error_code      OUT VARCHAR2,
                             p_error_desc      OUT VARCHAR2) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
    ---------------------------
    --   Local Definition
    ---------------------------
    cursor account_cur(c_party_id NUMBER) is
      SELECT acct.cust_account_id
        FROM hz_cust_accounts acct, hz_parties party
       WHERE 1 = 1 --acct.cust_account_id = :1
         AND acct.party_id = party.party_id
         AND party.party_type = 'ORGANIZATION'
         AND party.category_code = 'CUSTOMER'
         AND acct.status = 'A'
         AND acct.party_id = c_party_id; --8649223
  
    l_cust_account_id NUMBER;
    l_count           NUMBER;
    l_final_count     NUMBER;
    ---------------------------
    --   Code section
    ---------------------------
  BEGIN
    p_error_code  := '0';
    p_error_desc  := NULL;
    l_final_count := 0;
  
    for account_ind in account_cur(p_party_id) loop
    
      SELECT COUNT(*)
        INTO l_count
        FROM hz_cust_acct_sites hzcustaccountsiteseoex,
             hz_party_sites     ps,
             hz_locations       lc,
             fnd_territories_vl terr,
             hr_operating_units ou
       WHERE hzcustaccountsiteseoex.cust_account_id = l_cust_account_id
         AND hzcustaccountsiteseoex.org_id = p_org_id
         AND ps.party_id = p_party_id
         AND hzcustaccountsiteseoex.party_site_id = ps.party_site_id
         AND ps.location_id = lc.location_id
         AND terr.territory_code = lc.country
         AND hzcustaccountsiteseoex.org_id = ou.organization_id;
    
      l_final_count := l_final_count + l_count;
    
    end loop;
  
    IF 0 = l_final_count THEN
      p_validation_flag := 'N';
    ELSE
      p_validation_flag := 'Y';
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      p_error_code := '2';
      p_error_desc := 'EXCEPTION_OTHERS xxssys_strataforce_events2_pkg.is_acct_ou_valid(' ||
                      p_party_id || ',' || p_org_id || ')-' || SQLERRM;
  END is_acct_ou_valid;

  ---------------------------------------------------------------------------------------
  -- Ver  Date        Who         Description
  -- ---  ----------  ----------  -------------------------------------------------------
  -- 1.0  17/06/2020  Roman W.    CHG0047450 - Account, Contact interface - ReDo
  -- 1.1  25/03/2021  Roman W.                 Added parameter "p_created_by_module"
  ---------------------------------------------------------------------------------------
  PROCEDURE acct_site_insert_trg(p_created_by_module      IN VARCHAR2,
                                 p_cust_account_id        IN NUMBER,
                                 p_cust_acct_site_id      IN NUMBER,
                                 p_status                 IN VARCHAR2,
                                 p_new_sf_account_address IN OUT VARCHAR2,
                                 p_error_code             OUT VARCHAR2,
                                 p_error_desc             OUT VARCHAR2) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
    -------------------------
    --    Local Definition
    -------------------------
    l_count NUMBER;
    -------------------------
    --    Code Section
    -------------------------
  
  BEGIN
  
    p_error_code := '0';
    p_error_desc := NULL;
  
    SELECT COUNT(*)
      INTO l_count
      FROM hz_cust_acct_sites hcas
     WHERE hcas.cust_account_id = p_cust_account_id
       AND hcas.cust_acct_site_id != p_cust_acct_site_id
       AND hcas.status = 'A'
       AND nvl(hcas.attribute4, 'N') = 'Y';
  
    IF 0 = l_count AND 'N' = p_new_sf_account_address AND 'A' = p_status THEN
    
      SELECT COUNT(*)
        INTO l_count
        FROM hz_cust_acct_sites hcas
       WHERE hcas.cust_account_id = p_cust_account_id
         AND hcas.cust_acct_site_id != p_cust_acct_site_id
         AND hcas.status = 'A';
    
      IF 0 = l_count THEN
        p_new_sf_account_address := 'Y';
      ELSE
        p_error_code := '2';
        p_error_desc := 'Please set "SF Account Address" to "Yes". Account must have at least one Account Address';
      END IF;
    END IF;
  
    if 'HZ_TCA_CUSTOMER_MERGE' = p_created_by_module and 0 < l_count and
       'Y' = p_new_sf_account_address THEN
      p_new_sf_account_address := 'N';
    end if;
  
  END acct_site_insert_trg;

  ---------------------------------------------------------------------------------------
  -- Ver  Date        Who         Description
  -- ---  ----------  ----------  -------------------------------------------------------
  -- 1.0  17/06/2020  Roman W.    CHG0047450 - Account, Contact interface - ReDo
  -- 1.1  24/06/2021  Roman W.    CHG0047450 - Account, Contact interface - ReDo
  --                                     Added SITE Status = 'A'
  ---------------------------------------------------------------------------------------
  PROCEDURE acct_site_updpdate_trg(p_cust_account_id        IN NUMBER,
                                   p_cust_acct_site_id      IN NUMBER,
                                   p_old_status             IN VARCHAR2,
                                   p_new_status             IN VARCHAR2,
                                   p_old_sf_account_address IN VARCHAR2,
                                   p_new_sf_account_address IN VARCHAR2,
                                   p_error_code             OUT VARCHAR2,
                                   p_error_desc             OUT VARCHAR2) IS
  
    PRAGMA AUTONOMOUS_TRANSACTION;
    ----------------------------
    --     Local Definition
    ----------------------------
    l_count           NUMBER;
    l_request_id      NUMBER;
    l_update          VARCHAR2(10);
    l_new_site_org_id NUMBER;
    l_old_site_org_id NUMBER;
    ----------------------------
    --     Code Section
    ----------------------------
  
  BEGIN
    p_error_code := '0';
    p_error_desc := NULL;
  
    SELECT hcasa1.org_id site_org_id -- 96
      INTO l_new_site_org_id
      FROM hz_cust_acct_sites_all hcasa1
     WHERE hcasa1.cust_account_id = p_cust_account_id
       AND hcasa1.cust_acct_site_id = p_cust_acct_site_id;
  
    BEGIN
    
      SELECT hcasa1.org_id site_org_id -- 96
        INTO l_old_site_org_id
        FROM hz_cust_acct_sites_all hcasa1
       WHERE 1 = 1
         AND hcasa1.attribute4 = 'Y'
         AND hcasa1.status = 'A' -- CHG0047450
         AND hcasa1.cust_account_id = p_cust_account_id
         AND hcasa1.cust_acct_site_id != p_cust_acct_site_id
         AND rownum = 1;
    
    EXCEPTION
      WHEN no_data_found THEN
        l_old_site_org_id := l_new_site_org_id;
    END;
  
    IF l_new_site_org_id != l_old_site_org_id and
       'Y' = p_old_sf_account_address THEN
      p_error_code := '2';
      p_error_desc := 'ERROR : New Site Operating Unit and Old Site Operating Unit should be the same';
      RETURN;
    END IF;
  
    SELECT COUNT(*)
      INTO l_count
      FROM hz_cust_acct_sites_all hcas
     WHERE hcas.cust_account_id = p_cust_account_id
       AND hcas.cust_acct_site_id != p_cust_acct_site_id
       AND hcas.status = 'A'
       AND nvl(hcas.attribute4, 'N') = 'Y';
  
    -- N-Y-A-A
    IF (('N' = p_old_sf_account_address AND 'Y' = p_new_sf_account_address AND
       'A' = p_old_status AND 'A' = p_new_status) OR
       -- N-Y-I-A
       ('N' = p_old_sf_account_address AND 'Y' = p_new_sf_account_address AND
       'I' = p_old_status AND 'A' = p_new_status) OR
       -- Y-Y-I-A
       ('Y' = p_old_sf_account_address AND 'Y' = p_new_sf_account_address AND
       'I' = p_old_status AND 'A' = p_new_status)) AND 0 < l_count THEN
    
      l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                                 program     => 'XXHZ_ACCOUNT_ADDR_VALIDATION', -- XXOM_AUTO_HOLD_PKG.main_conc
                                                 description => NULL,
                                                 start_time  => to_char(SYSDATE + (5 /
                                                                        86400),
                                                                        'DD-MON-YYYY HH24:MI:SS'),
                                                 sub_request => FALSE,
                                                 argument1   => p_cust_account_id,
                                                 argument2   => p_cust_acct_site_id);
    
      COMMIT;
      -- Y-N-A-A
    ELSIF ('Y' = p_old_sf_account_address AND
          'N' = p_new_sf_account_address AND 'A' = p_old_status AND
          'A' = p_new_status)
         -- Y-N-A-I
          OR ('Y' = p_old_sf_account_address AND
          'N' = p_new_sf_account_address AND 'A' = p_old_status AND
          'I' = p_new_status)
         -- Y-Y-A-I
          OR ('Y' = p_old_sf_account_address AND
          'Y' = p_new_sf_account_address AND 'A' = p_old_status AND
          'I' = p_new_status) THEN
      IF 0 = l_count THEN
        p_error_code := '2';
        p_error_desc := 'Please mark alternative Account Address site before delete/inactive exist one.';
      END IF;
      -- Y-Y-A-I
    
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
    
      p_error_code := '2';
      p_error_desc := 'EXCEPTION_OTHERS xxssys_strataforce_events2_pkg.acct_site_updpdate_trg(' ||
                      chr(10) || p_cust_account_id || ',' || chr(10) ||
                      p_cust_acct_site_id || ',' || chr(10) || p_old_status || ',' ||
                      chr(10) || p_new_status || ',' || chr(10) ||
                      p_old_sf_account_address || ',' || chr(10) ||
                      p_new_sf_account_address || ') - ' || SQLERRM;
    
  END acct_site_updpdate_trg;

  ---------------------------------------------------------------------------------------
  -- Ver  Date        Who         Description
  -- ---  ----------  ----------  -------------------------------------------------------
  -- 2.8  27/03/2020  Roman W.    CHG0047450 - Account, Contact interface - ReDo
  --                                   Concurrent : XXHZ_ACCOUNT_ADDR_VALIDATION
  ---------------------------------------------------------------------------------------
  PROCEDURE acct_site_upd_attr4_conc(errbuf              OUT VARCHAR2,
                                     retcode             OUT VARCHAR2,
                                     p_cust_account_id   IN NUMBER,
                                     p_cust_acct_site_id IN NUMBER) IS
  
    ----------------------------
    --    Local Definition
    ----------------------------
    l_count NUMBER;
    ----------------------------
    --    Code Section
    ----------------------------
    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    retcode := '0';
    errbuf  := NULL;
  
    -- update
    UPDATE hz_cust_acct_sites_all hcas
       SET hcas.attribute4 = 'N'
     WHERE hcas.cust_account_id = p_cust_account_id
       AND hcas.cust_acct_site_id != p_cust_acct_site_id
       AND hcas.attribute4 = 'Y';
  
    COMMIT;
  
  EXCEPTION
    WHEN OTHERS THEN
      retcode := '2';
      errbuf  := 'EXCEPTION_OTHERS acct_site_upd_attr4_trg.account_addr_validation(' ||
                 p_cust_account_id || ',' || p_cust_acct_site_id || ') - ' ||
                 SQLERRM;
    
  END acct_site_upd_attr4_conc;
  ---------------------------------------------------------------------------------
  -- populate_inactive_merge_site_events
  -- call by prog :XXHZ Sync Inactive Sites2SFDC (Merged)
  ---------------------------------------------------------------------------------------
  -- Ver  Date        Who         Description
  -- ---  ----------  ----------  -------------------------------------------------------
  -- 1.0   4.1.2021   Yuval Tal   CHG0048217 - push inactive sites which were merged and need to set new account to be able to
  --                                            be fetch by XXHZ_SITE_SOA_V and sync it to sfdc
  ---------------------------------------------------------------------------------------
  PROCEDURE populate_inactive_site_events(errbuf  OUT VARCHAR2,
                                          retcode OUT VARCHAR2) IS
  
    CURSOR c IS
      SELECT e.event_id,
             loc.account__c,
             s.oracle_site_number site_number,
             -- loc.id,
             loc.external_key__c oracle_site_id,
             -- loc.status__c        sf_site_status,
             -- ac.external_key__c   sf_account_number,
             -- s.account_number     oa_account_number,
             -- s.site_status        oracle_site_status,
             -- s.sf_account_id,
             loc.account__c loc_acc_id
        FROM location@source_sf2 loc,
             account@source_sf2  ac,
             xxhz_site_dtl_v     s,
             xxssys_events       e
       WHERE ac.id = loc.account__c
         AND s.oracle_site_id = loc.external_key__c
         AND ac.external_key__c != s.account_number
         AND loc.locationtype = 'Site'
         AND loc.status__c = 'Active'
         AND s.site_status = 'Inactive'
         AND s.sf_account_id IS NULL
         AND e.target_name(+) = 'STRATAFORCE'
         AND e.entity_name(+) = 'SITE'
         AND e.status(+) = 'NEW'
         AND e.entity_id(+) = s.oracle_site_id;
  
    l_xxssys_event_rec xxssys_events%ROWTYPE;
  BEGIN
  
    message('Looking for Sites....');
    FOR i IN c LOOP
      l_xxssys_event_rec := NULL;
      message('process event_id= ' || i.event_id || ' site_id=' ||
              i.oracle_site_id);
      BEGIN
        IF i.event_id IS NOT NULL THEN
          UPDATE xxssys_events
             SET attribute1       = i.loc_acc_id,
                 event_name       = 'xxssys_strataforce_events2_pkg.populate_inactive_site_events',
                 last_update_date = SYSDATE,
                 last_updated_by  = fnd_global.user_id
           WHERE event_id = i.event_id;
        
        ELSE
          -- insert event
          l_xxssys_event_rec.target_name     := 'STRATAFORCE';
          l_xxssys_event_rec.entity_name     := 'SITE';
          l_xxssys_event_rec.entity_id       := i.oracle_site_id;
          l_xxssys_event_rec.entity_code     := i.site_number; --CHG0042632
          l_xxssys_event_rec.event_name      := 'xxssys_strataforce_events2_pkg.populate_inactive_site_events';
          l_xxssys_event_rec.last_updated_by := fnd_global.user_id;
          l_xxssys_event_rec.created_by      := fnd_global.user_id;
          l_xxssys_event_rec.attribute1      := i.loc_acc_id;
          xxssys_event_pkg.insert_event(l_xxssys_event_rec, 'N');
        
        END IF;
        COMMIT;
      EXCEPTION
        WHEN OTHERS THEN
          message('Unable to resend location ' || i.oracle_site_id || ' ' ||
                  SQLERRM);
          retcode := 2;
          errbuf  := SQLERRM;
      END;
    END LOOP;
  
  END;

END xxssys_strataforce_events2_pkg;
/
