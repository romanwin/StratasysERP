CREATE OR REPLACE PACKAGE BODY xxs3_otc_location_pkg AS

  ----------------------------------------------------------------------------
  --  name:            XXS3_OTC_LOCATION_PKG
  --  create by:       Mishal Kumar
  --  Revision:        1.0
  --  creation date:   26/04/2016
  ----------------------------------------------------------------------------
  --  purpose :        Package to extract the Location fields
  --                   from Legacy system
  ----------------------------------------------------------------------------
  --  ver  date        name                         desc
  --  1.0  26/04/2016  Mishal Kumar                 Initial build
  ----------------------------------------------------------------------------

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Insert in to DQ table for validation errors and update the master table
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  26/04/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  PROCEDURE insert_update_dq(p_xx_location_id     IN NUMBER,
                             p_rule_name          IN VARCHAR2,
                             p_reject_code        IN VARCHAR2,
                             p_legacy_location_id NUMBER) IS
    l_step VARCHAR2(50);

  BEGIN
    l_step := 'Set Process_Flag =Q';
    UPDATE xxobjt.xxs3_otc_location
       SET process_flag = 'Q'
     WHERE xx_location_id = p_xx_location_id;

    l_step := 'Insert into DQ table';
    INSERT INTO xxobjt.xxs3_otc_locations_dq
      (xx_dq_location_id, xx_location_id, rule_name, notes,dq_status)
    VALUES
      (xxobjt.xxs3_otc_locations_dq_seq.NEXTVAL,
       p_xx_location_id,
       p_rule_name,
       p_reject_code,
       'Q');
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log, 'Unexpected error during DQ table DML for xx_location_id = '
                          ||p_xx_location_id|| 'at step: ' ||l_step||chr(10) || SQLCODE || chr(10) || SQLERRM);
  END insert_update_dq;

   -- --------------------------------------------------------------------------------------------
  -- Purpose: Insert in to DQ table for validation errors(rejected records) and update the master table
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  26/04/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  --
  PROCEDURE insert_update_dq_r(p_xx_location_id     IN NUMBER,
                               p_rule_name          IN VARCHAR2,
                               p_reject_code        IN VARCHAR2,
                               p_legacy_location_id NUMBER) IS
     l_step VARCHAR2(50);
  BEGIN
    l_step := 'Set Process_Flag =R';
    UPDATE xxobjt.xxs3_otc_location
       SET process_flag = 'R'
     WHERE xx_location_id = p_xx_location_id;

    l_step := 'Insert Rejected record into DQ table';

    INSERT INTO xxobjt.xxs3_otc_locations_dq
      (xx_dq_location_id, xx_location_id, rule_name, notes,dq_status)
    VALUES
      (xxobjt.xxs3_otc_locations_dq_seq.NEXTVAL,
       p_xx_location_id,
       p_rule_name,
       p_reject_code,
       'R');
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log, 'Unexpected error during DQ table DML for xx_location_id = '
                          ||p_xx_location_id|| 'at step: ' ||l_step||chr(10) || SQLCODE || chr(10) || SQLERRM);
  END insert_update_dq_r;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: Extract data from staging tables for quality check of PARTY track
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  26/04/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  PROCEDURE quality_check_locations IS
    l_party_name  VARCHAR2(10);
    l_result012   BOOLEAN;
    l_result009   VARCHAR2(10);
    l_result008   VARCHAR2(10);
    l_result016   BOOLEAN;
    l_result015   BOOLEAN;
    l_result014   BOOLEAN;
    l_result004   VARCHAR2(10);
    l_result004_1 VARCHAR2(10);
    l_result004_2 VARCHAR2(10);
    l_result004_3 VARCHAR2(10);
    l_result020   BOOLEAN;
    l_result011   VARCHAR2(10);
    l_result006   VARCHAR2(10);
    l_result013   BOOLEAN;
    l_status      BOOLEAN := TRUE;
    l_country     VARCHAR2(10) := 'FALSE';
    l_check_rule  VARCHAR2(10) := 'FALSE';

   /* CURSOR c_party_type IS
    SELECT party_type */

  BEGIN
    FOR i IN (SELECT l.address4,
                     l.timezone_id,
                     l.postal_code,
                     l.xx_location_id,
                     l.legacy_location_id,
                     l.address1,
                     l.address2,
                     l.address3,
                     l.city,
                     l.country,
                     --party_type,
                     l.state,
                     l.province,
                     hp.party_type party_type
                FROM xxobjt.xxs3_otc_location l,hz_parties hp,hz_party_sites hps
               WHERE extract_rule_name IS NOT NULL
               AND l.legacy_location_id =hps.location_id
               AND hp.party_id = hps.party_id) LOOP
      l_status := TRUE;
      --
      --l_result012     := XXS3_DQ_UTIL_PKG.EQT_012(I.COUNTRY);-- ONLY FOR PARTY_TYPE = ORGANIZATION
      --l_result008     := XXS3_DQ_UTIL_PKG.EQT_008(I.COUNTRY);
      --l_result011     := XXS3_DQ_UTIL_PKG.EQT_011(I.COUNTRY);
      --l_result020     := XXS3_DQ_UTIL_PKG.EQT_020(I.ADDRESS1);
      --l_result004     := XXS3_DQ_UTIL_PKG.EQT_004(I.ADDRESS1);
      --l_result004_1   := XXS3_DQ_UTIL_PKG.EQT_004(I.ADDRESS2);
      --l_result004_2   := XXS3_DQ_UTIL_PKG.EQT_004(I.ADDRESS3);
      l_result013 := xxs3_dq_util_pkg.eqt_013(i.address4);
      --l_result014 := xxs3_dq_util_pkg.eqt_014(i.timezone_id);
      --l_result015     := XXS3_DQ_UTIL_PKG.EQT_015(I.CITY); -- ONLY FOR PARTY_TYPE = ORGANIZATION
      --l_result004_3   := XXS3_DQ_UTIL_PKG.EQT_004(I.CITY);
      l_result016 := xxs3_dq_util_pkg.eqt_016(i.postal_code); -- ONLY FOR PARTY_TYPE = ORGANIZATION
      --l_result006     := XXS3_DQ_UTIL_PKG.EQT_006(I.STATE, I.COUNTRY);
      --l_result009     := XXS3_DQ_UTIL_PKG.EQT_009(I.STATE, I.COUNTRY);
      --  x_resultEQT_028 := xxs3_dq_util_pkg.EQT_028(i.email);
      --
      /*IF l_result012 = TRUE THEN
          INSERT_UPDATE_DQ_R(I.XX_LOCATION_ID,
                           'EQT_012',
                           'EQT_012 :Missing Country Code',i.LEGACY_LOCATION_ID);
       l_status := FALSE;
       END IF;
        --
        IF l_result008 = 'FALSE' THEN
          INSERT_UPDATE_DQ_R(I.XX_LOCATION_ID,
                           'EQT_008',
                           'EQT_008 :Non-std Country Code',i.LEGACY_LOCATION_ID);
       l_status := FALSE;
       END IF;
       --
       IF l_result011 = 'TRUE' THEN
          INSERT_UPDATE_DQ(I.XX_LOCATION_ID,
                           'EQT_011',
                           'EQT_011 :Non-std Country Name',i.LEGACY_LOCATION_ID);
       l_status := FALSE;
       END IF;
       --
      IF l_result020 = TRUE THEN
          INSERT_UPDATE_DQ_R(I.XX_LOCATION_ID,
                           'EQT_020',
                           'EQT_020 :Missing Address1',i.LEGACY_LOCATION_ID);
       l_status := FALSE;
       END IF;
       --
       IF l_result004 = 'FALSE' THEN
          INSERT_UPDATE_DQ_R(I.XX_LOCATION_ID,
                           'EQT_004',
                           'EQT_004 :Non-std Address Line',i.LEGACY_LOCATION_ID);
       l_status := FALSE;
       END IF;
       --
       IF l_result004_1 = 'FALSE' THEN
          INSERT_UPDATE_DQ(I.XX_LOCATION_ID,
                           'EQT_004',
                           'EQT_004 :Non-std Address Line',i.LEGACY_LOCATION_ID);
       l_status := FALSE;
       END IF;
       --
       IF l_result004_2 = 'FALSE' THEN
          INSERT_UPDATE_DQ(I.XX_LOCATION_ID,
                           'EQT_004',
                           'EQT_004 :Non-std Address Line',i.LEGACY_LOCATION_ID);
       l_status := FALSE;
       END IF;*/
      --
     
      /*--
      IF l_result014 = TRUE THEN
        insert_update_dq(i.xx_location_id,
                           'EQT_014',
                           'EQT_014 :Missing Timezone',
                           i.legacy_location_id);
        l_status := FALSE;
      END IF;*/
      --
      /* IF l_result015 = TRUE THEN
         INSERT_UPDATE_DQ_R(I.XX_LOCATION_ID,
                          'EQT_015',
                          'EQT_015 :Missing City',i.LEGACY_LOCATION_ID);
      l_status := FALSE;
      END IF;
      --
      IF l_result004_3 = 'FALSE' THEN
         INSERT_UPDATE_DQ(I.XX_LOCATION_ID,
                          'EQT_004',
                          'EQT_004 :Non-std Address Line',i.LEGACY_LOCATION_ID);
      l_status := FALSE;
      END IF;*/
      --
      
      --
      /*IF l_result006 = 'FALSE' THEN
         INSERT_UPDATE_DQ(I.XX_LOCATION_ID,
                          'EQT_006',
                          'EQT_006 :Non-std State Code',i.LEGACY_LOCATION_ID);
      l_status := FALSE;
      END IF;*/
      --
      /* IF l_result009 = 'FALSE' THEN
         INSERT_UPDATE_DQ(I.XX_LOCATION_ID,
                          'EQT_009',
                          'EQT_009 :Standardize State Name',i.LEGACY_LOCATION_ID);
      l_status := FALSE;
      END IF;*/
      
        --END IF;
     IF i.party_type='ORGANIZATION' THEN   
      IF i.address1 IS NOT NULL THEN
        l_check_rule := xxs3_dq_util_pkg.eqt_004(i.address1);

        IF l_check_rule = 'FALSE' THEN
          insert_update_dq(i.xx_location_id,
                           'EQT_004',
                           'EQT_004 :Non-std Address Line ' || '' ||
                           'for field ' || 'ADDRESS1',
                           i.legacy_location_id);
          l_status := FALSE;
        END IF;
      END IF;
      
      IF i.city IS NOT NULL THEN
        l_check_rule := xxs3_dq_util_pkg.eqt_005(i.city);
        IF l_check_rule = 'FALSE' THEN
          insert_update_dq(i.xx_location_id,
                           'EQT_005',
                           'EQT_005 :Non-std City',
                           i.legacy_location_id);
          l_status := FALSE;
        END IF;
      END IF;
     END IF;

      IF i.address2 IS NOT NULL THEN
        l_check_rule := xxs3_dq_util_pkg.eqt_004(i.address2);
        IF l_check_rule = 'FALSE' THEN
          insert_update_dq(i.xx_location_id,
                           'EQT_004',
                           'EQT_004 :Non-std Address Line ' || '' ||
                           'for field ' || 'ADDRESS2',
                           i.legacy_location_id);
          l_status := FALSE;
        END IF;
      END IF;

      IF i.address3 IS NOT NULL THEN
        l_check_rule := xxs3_dq_util_pkg.eqt_004(i.address3);

        IF l_check_rule = 'FALSE' THEN
          insert_update_dq(i.xx_location_id,
                           'EQT_004',
                           'EQT_004 :Non-std Address Line ' || '' ||
                           'for field ' || 'ADDRESS3',
                           i.legacy_location_id);
          l_status := FALSE;
        END IF;
      END IF;
      --
     
     IF i.party_type='ORGANIZATION' THEN
      IF i.country IS NOT NULL THEN
       
        IF length(i.country) = 2 THEN
          --IF i.party_type = 'ORGANIZATION' THEN
            l_country := xxs3_dq_util_pkg.eqt_008(i.country);
            IF l_country = 'FALSE' THEN
              insert_update_dq(i.xx_location_id,
                               'EQT_008',
                               'EQT_008 :Non-std Country Code',
                               i.legacy_location_id);
              l_status := FALSE;
            END IF;
          --END IF;
        ELSIF length(i.country) > 2 THEN
          --IF i.party_type = 'ORGANIZATION' THEN
            l_country := xxs3_dq_util_pkg.eqt_011(i.country);
            IF l_country = 'FALSE' THEN
              insert_update_dq(i.xx_location_id,
                               'EQT_011',
                               'EQT_011 :Non-std Country Name',
                               i.legacy_location_id);
              l_status := FALSE;
            END IF;
          END IF;
        
       
        IF l_country = 'TRUE' THEN

          --check state if country lookup is available
          IF i.state IS NOT NULL THEN
            IF length(i.state) = 2 THEN
              l_check_rule := xxs3_dq_util_pkg.eqt_006(i.state, i.country);
              IF l_check_rule = 'FALSE' THEN
                insert_update_dq(i.xx_location_id,
                                 'EQT_006',
                                 'EQT_006 :Non-std State Code',
                                 i.legacy_location_id);
                l_status := FALSE;
              END IF;
            ELSIF length(i.state) > 2 THEN
              l_check_rule := xxs3_dq_util_pkg.eqt_009(i.state, i.country);
              IF l_check_rule = 'FALSE' THEN
                insert_update_dq(i.xx_location_id,
                                 'EQT_009',
                                 'EQT_009 :Non-std State Name',
                                 i.legacy_location_id);
                l_status := FALSE;
              END IF;
            END IF;
          END IF;
          ----check province if country lookup is available

          IF i.province IS NOT NULL THEN
            IF length(i.province) = 2 THEN
              l_check_rule := xxs3_dq_util_pkg.eqt_007(i.province,
                                                       i.country);
              IF l_check_rule = 'FALSE' THEN
                insert_update_dq(i.xx_location_id,
                                 'EQT_007',
                                 'EQT_007 :Non-std Province Code',
                                 i.legacy_location_id);
                l_status := FALSE;
              END IF;
            ELSIF length(i.province) > 2 THEN
              l_check_rule := xxs3_dq_util_pkg.eqt_010(i.province,
                                                       i.country);

              IF l_check_rule = 'FALSE' THEN
                insert_update_dq(i.xx_location_id,
                                 'EQT_010',
                                 'EQT_010 :Non-std Province Name',
                                 i.legacy_location_id);
                l_status := FALSE;
              END IF;
            END IF;
          END IF;
        END IF;
      END IF;
      
       IF l_result016 = TRUE THEN
        insert_update_dq(i.xx_location_id,
                           'EQT_016',
                           'EQT_016 :Missing Postal Code',
                           i.legacy_location_id);
        l_status := FALSE;
       END IF;
       
       IF i.city IS NULL THEN
        insert_update_dq(i.xx_location_id,
                           'EQT_015',
                           'EQT_015 :Missing City',
                           i.legacy_location_id);
        l_status := FALSE;
       END IF;
     END IF;
      --
      IF l_result013 = TRUE THEN
        insert_update_dq(i.xx_location_id,
                           'EQT_013',
                           'EQT_013 :Avalara Error',
                           i.legacy_location_id);
        l_status := FALSE;
      END IF; 
      
     IF i.party_type = 'ORGANIZATION' THEN 
      IF i.country IS NULL THEN
        --IF i.party_type = 'ORGANIZATION' THEN
          insert_update_dq_r(i.xx_location_id,
                             'EQT_012',
                             'EQT_012 :Missing Country Code',
                             i.legacy_location_id);
          l_status := FALSE;
       END IF;
       
       IF i.address1 IS NULL THEN
        insert_update_dq_r(i.xx_location_id,
                           'EQT_020',
                           'EQT_020 :Missing Address1',
                           i.legacy_location_id);
        l_status := FALSE;
       END IF;
      
     END IF;

      IF l_status = TRUE THEN

        UPDATE xxobjt.xxs3_otc_location
           SET process_flag = 'Y'
         WHERE xx_location_id = i.xx_location_id;
      END IF;
      --
    END LOOP;
    COMMIT;
  END quality_check_locations;
   -- --------------------------------------------------------------------------------------------
    -- Purpose: This procedure will generate DQ Report for locations
    -- --------------------------------------------------------------------------------------------
    -- Ver  Date        Name                          Description
    --  1.0 26/04/2016  Mishal Kumar                  Initial build
    -- --------------------------------------------------------------------------------------------
  PROCEDURE report_data_locations(p_entity IN VARCHAR2) IS
    CURSOR c_report_location IS
      SELECT nvl(ld.rule_name, ' ') rule_name,
             nvl(ld.notes, ' ') notes,
             l.legacy_location_id legacy_location_id,
             ld.xx_location_id xx_location_id,
             l.address1,
             ld.dq_status,/*
             (SELECT legacy_party_site_number FROM xxs3_otc_party_sites
             WHERE location_id = l.legacy_location_id) party_site_number,*/
             decode(l.process_flag, 'R', 'Y', 'Q', 'N') reject_record
        FROM xxobjt.xxs3_otc_location l, xxobjt.xxs3_otc_locations_dq ld
       WHERE l.xx_location_id = ld.xx_location_id
         AND l.process_flag IN ('Q', 'R');

    l_delimiter    VARCHAR2(5) := '~';
    l_err_msg      VARCHAR2(2000);
    l_count_dq     NUMBER;
    l_count_reject NUMBER;

  BEGIN
  IF p_entity = 'LOCATIONS' THEN

    SELECT COUNT(1)
      INTO l_count_dq
      FROM xxs3_otc_location
     WHERE process_flag IN ('Q', 'R');

    SELECT COUNT(1)
      INTO l_count_reject
      FROM xxs3_otc_location
     WHERE process_flag = 'R';

    fnd_file.put_line(fnd_file.output, rpad('Report name = Data Quality Error Report'|| l_delimiter, 100, ' '));
    fnd_file.put_line(fnd_file.output, rpad('========================================'|| l_delimiter, 100, ' '));
    fnd_file.put_line(fnd_file.output, rpad('Data Migration Object Name = '||p_entity || l_delimiter, 100, ' '));
    fnd_file.put_line(fnd_file.output, '');
    fnd_file.put_line(fnd_file.output, rpad('Run date and time:    ' ||
                       to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI')|| l_delimiter, 100, ' '));
    fnd_file.put_line(fnd_file.output, rpad('Total Record Count Having DQ Issues = '||l_count_dq || l_delimiter, 100, ' '));
    fnd_file.put_line(fnd_file.output, rpad('Total Record Count Rejected =  '||l_count_reject|| l_delimiter , 100, ' '));


    fnd_file.put_line(fnd_file.output, '');

    fnd_file.put_line(fnd_file.output,rpad('Track Name', 10, ' ') || l_delimiter ||
                       rpad('Entity Name', 11, ' ') || l_delimiter ||
                       rpad('XX Location ID  ', 14, ' ') || l_delimiter ||
                       rpad('Legacy Location ID', 10, ' ') || l_delimiter ||
                       rpad('Address1', 240, ' ') || l_delimiter ||/*
                       rpad('Party_Site_Number', 30, ' ') ||l_delimiter ||*/
                       rpad(nvl('Dq_Status', 'NULL'), 2, ' ') ||l_delimiter ||
                        rpad('Reject Record Flag(Y/N)', 22, ' ') || l_delimiter ||
                       rpad('Rule Name', 45, ' ') || l_delimiter ||
                       rpad('Reason Code', 50, ' ') );


    FOR r_data IN c_report_location LOOP
      fnd_file.put_line(fnd_file.output, rpad('OTC', 10, ' ') || l_delimiter ||
                         rpad('LOCATIONS', 11, ' ') || l_delimiter ||
                         rpad(r_data.xx_location_id, 14, ' ') || l_delimiter ||
                         rpad(r_data.legacy_location_id, 10, ' ') || l_delimiter ||
                         rpad(r_data.address1, 240, ' ') || l_delimiter ||/*
                         rpad(r_data.party_site_number, 30, ' ') ||l_delimiter ||*/
                         rpad(nvl(r_data.dq_status, 'NULL'), 2, ' ') ||l_delimiter ||
                         rpad(r_data.reject_record, 22, ' ') || l_delimiter ||
                         rpad(nvl(r_data.rule_name,'NULL'), 45  , ' ') || l_delimiter ||
                         rpad(nvl(r_data.notes,'NULL'), 50, ' ') );

    END LOOP;

       fnd_file.put_line(fnd_file.output,
                      rpad('=============================', 100, ' '));
    fnd_file.put_line(fnd_file.output, rpad('End Of Report', 100, ' '));
    END IF;
  END report_data_locations;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required HZ_Locations fields and insert into
  --           staging table XXS3_OTC_LOCATION
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0 26/04/2016  Mishal Kumar                  Initial build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE location_extract_data(x_errbuf  OUT VARCHAR2,
                                  x_retcode OUT NUMBER
                                  ) IS

    l_errbuf             VARCHAR2(2000);
    l_retcode            VARCHAR2(1);
    l_requestor          NUMBER;
    l_program_short_name VARCHAR2(100);
    l_status_message     VARCHAR2(4000);
    l_counter            NUMBER;
    l_count_locations NUMBER;
    --
    CURSOR cur_location_extract IS
    SELECT DISTINCT l.address_style,
                    l.address1,
                    l.address2,
                    l.address3,
                    l.address4,
                    l.city,
                    l.content_source_type,
                    l.country,
                    l.county,
                    l.created_by,
                    l.created_by_module, --new
                    l.creation_date,
                    l.date_validated,
                    l.location_id, --multiple site use
                    l.orig_system_reference,
                    l.postal_code,
                    l.province,
                    l.sales_tax_inside_city_limits,
                    l.state,
                    l.timezone_id,
                    l.time_zone   
      FROM hz_locations   l;/*,
           hz_party_sites         ps,
           hz_party_site_uses     psu,
           hz_parties             p,
           hz_cust_acct_sites_all casa,
           hz_cust_site_uses_all  csua
     WHERE l.location_id = ps.location_id
       AND ps.party_site_id = psu.party_site_id
       AND ps.party_id = p.party_id
       AND casa.party_site_id = ps.party_site_id
       AND casa.cust_acct_site_id = csua.cust_acct_site_id
       AND casa.status = 'A'
       AND casa.cust_account_id IN
           (SELECT cust_account_id FROM hz_cust_accounts WHERE status = 'A')
          --AND PSU.SITE_USE_TYPE IN ('PURCHASING', 'PAY', 'INSTALL_AT')
       AND p.party_type IN ('PARTY_RELATIONSHIP', 'PERSON', 'ORGANIZATION')
       AND (csua.site_use_code IN ('BILL_TO', 'SHIP_TO') OR
           psu.site_use_type IN ('PURCHASING', 'PAY', 'INSTALL_AT'));*/
    --
  BEGIN
    x_retcode := 0;
    x_errbuf  := 'COMPLETE';
    --

    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_otc_location';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_otc_locations_dq';

    FOR k IN cur_location_extract LOOP
      INSERT INTO xxobjt.xxs3_otc_location
        (xx_location_id,
         --location_id,
         legacy_location_id,
         --party_type,
         address1,
         address2,
         address3,
         address4,
         city,
         state,
         postal_code,
         county,
         province,
         country,
         timezone_id,
         time_zone,
         address_style,
         creation_date,
         created_by,
         orig_system_reference,
         content_source_type,
         sales_tax_inside_city_limits,
         created_by_module,
         date_validated,
         date_extracted_on,
         process_flag)
      VALUES
        (xxobjt.xxs3_otc_location_seq.NEXTVAL,
         --NULL,
         k.location_id,
         --NULL, --k.party_type,
         k.address1,
         k.address2,
         k.address3,
         k.address4,
         k.city,
         k.state,
         k.postal_code,
         k.county,
         k.province,
         k.country,
         k.timezone_id,
         k.time_zone,
         k.address_style,
         k.creation_date,
         k.created_by,
         k.orig_system_reference,
         k.content_source_type,
         k.sales_tax_inside_city_limits,
         k.created_by_module,
         k.date_validated,
         SYSDATE,
         'N');
    END LOOP;
    COMMIT;
    --
    fnd_file.put_line(fnd_file.log, 'Loading complete');
    --
    --Apply extract Rules
    
    BEGIN --Rejected party records will also mark relevant account site records to 'R'
     UPDATE xxs3_otc_location xop
        SET xop.extract_rule_name = CASE WHEN extract_rule_name = NULL THEN 'EXT-011' ELSE extract_rule_name || '|' || 'EXT-011' END
      WHERE EXISTS (SELECT location_id
               FROM xxs3_otc_party_sites a
              WHERE a.location_id = xop.legacy_location_id
                AND a.process_flag <> 'R'
                AND a.extract_rule_name IS NOT NULL
                AND nvl(a.transform_status,'PASS') <> 'FAIL');
    EXCEPTION
      WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log, 'Unexpected error during extract rules update : ' ||
                               chr(10) || SQLCODE || chr(10) ||
                               SQLERRM);                        
    END;
    
    --Apply extract Rules
    COMMIT;
    
    --DQ
    BEGIN
      quality_check_locations;
      fnd_file.put_line(fnd_file.log, 'DQ complete');
    EXCEPTION
       WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log, 'Unexpected error during DQ validation : ' ||
                     chr(10) || SQLCODE || chr(10) || SQLERRM);
    END;
    
      --update process_flag='R' and EXTRACT_DQ_ERROR column in all dependent entities  
    
   BEGIN  
    UPDATE xxs3_otc_party_sites a
       SET process_flag     = 'R',
           extract_dq_error = 'Associated Location Record: '||a.location_id||'  has DQ error or transformation error'
     WHERE EXISTS
     (SELECT legacy_location_id
              FROM xxs3_otc_location b
             WHERE b.legacy_location_id = a.location_id
               AND (nvl(b.transform_status, 'PASS') = 'FAIL' OR
                   b.process_flag = 'R')
               AND b.extract_rule_name is NOT NULL);
               
    UPDATE xxs3_otc_cust_acct_sites a
       SET process_flag     = 'R',
           extract_dq_error = 'Associated Location Record for party site id: '||a.legacy_party_site_id||'  has DQ error or transformation error'
     WHERE EXISTS
     (SELECT c.legacy_party_site_id
              FROM xxs3_otc_location b,xxs3_otc_party_sites c
             WHERE b.legacy_location_id = c.location_id
               AND c.legacy_party_site_id = a.legacy_party_site_id
               AND (nvl(b.transform_status, 'PASS') = 'FAIL' OR
                   b.process_flag = 'R')
               AND b.extract_rule_name is NOT NULL);
               
     COMMIT;          
  EXCEPTION
    WHEN OTHERS THEN 
          fnd_file.put_line(fnd_file.log, 'Unexpected error during update of EXTRACT_DQ_ERROR in dependent entities' ||
                            chr(10) || SQLCODE ||
                           chr(10) || SQLERRM);  
 END;
    --
    --Location Extract Count

	     SELECT COUNT(1)
         INTO   l_count_locations
         FROM   xxobjt.xxs3_otc_location xol;

      fnd_file.put_line(fnd_file.output, RPAD('Location Extract Records Count Report', 100, ' '));
    fnd_file.put_line(fnd_file.output, RPAD('============================================================', 200, ' '));
    fnd_file.put_line(fnd_file.output, RPAD('Run date and time:    ' ||
                       to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI'), 100, ' '));
	  fnd_file.put_line(fnd_file.output, RPAD('============================================================', 200, ' '));
	  fnd_file.put_line(fnd_file.output, '');
    fnd_file.put_line(fnd_file.output,RPAD('Track Name', 10, ' ')||chr(32)||
                       RPAD('Entity Name', 30, ' ') || chr(32) ||
					   RPAD('Total Count', 15, ' ') );
  fnd_file.put_line(fnd_file.output, RPAD('===========================================================', 200, ' '));

    fnd_file.put_line(fnd_file.output, '');

      fnd_file.put_line(fnd_file.output,RPAD('OTC', 10, ' ')||' '||
                      RPAD('LOCATION', 30, ' ') ||' ' ||
			          		   RPAD(l_count_locations, 15, ' ') );
     fnd_file.put_line(fnd_file.output, RPAD('=========END OF REPORT===============', 200, ' '));
     fnd_file.put_line(fnd_file.output, '');

  EXCEPTION
    WHEN OTHERS THEN
      x_retcode        := 2;
      x_errbuf         := 'Unexpected error: ' || SQLERRM;
      l_status_message := SQLCODE || chr(10) || SQLERRM;
      fnd_file.put_line(fnd_file.log,
                        'Unexpected error during data extraction : ' ||
                        chr(10) || l_status_message);
      fnd_file.put_line(fnd_file.log,
                        '--------------------------------------');
  END location_extract_data;

END xxs3_otc_location_pkg;
/
