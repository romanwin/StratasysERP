CREATE OR REPLACE PACKAGE BODY xxs3_otc_party_pkg AS

  ----------------------------------------------------------------------------
  --  name:            XXS3_OTC_PARTY_PKG
  --  create by:       Mishal Kumar
  --  Revision:        1.0
  --  creation date:   26/04/2016
  ----------------------------------------------------------------------------
  --  purpose :        Package to extract the Party fields
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
  PROCEDURE insert_update_dq(p_xx_party_id IN NUMBER
                            ,p_rule_name   IN VARCHAR2
                            ,p_reject_code IN VARCHAR2) IS
  
    l_step VARCHAR2(50);
  BEGIN
    /* Update Process flag for DQ records with 'Q' */
    l_step := 'Set Process_Flag =Q';
  
    UPDATE xxobjt.xxs3_otc_parties
    SET process_flag = 'Q'
    WHERE xx_party_id = p_xx_party_id;
  
    /* Insert records in the DQ table with DQ details */
    l_step := 'Insert into DQ table';
  
    INSERT INTO xxobjt.xxs3_otc_parties_dq
      (xx_dq_party_id
      ,xx_party_id
      ,rule_name
      ,notes
      ,dq_status)
    VALUES
      (xxobjt.xxs3_otc_parties_dq_seq.NEXTVAL
      ,p_xx_party_id
      ,p_rule_name
      ,p_reject_code
      ,'Q');
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log
                       ,'Unexpected error during DQ table DML for xx_party_id = ' ||
                        p_xx_party_id || 'at step: ' || l_step || chr(10) ||
                        SQLCODE || chr(10) || SQLERRM);
  END insert_update_dq;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: Insert in to DQ table for validation errors(rejects) and update the master table
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  26/04/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  PROCEDURE insert_update_r_dq(p_xx_party_id IN NUMBER
                              ,p_rule_name   IN VARCHAR2
                              ,p_reject_code IN VARCHAR2) IS
  
    l_step VARCHAR2(50);
  
  BEGIN
    /* Update Process flag for DQ reject records with 'R' */
    l_step := 'Set Process_Flag = R';
  
    UPDATE xxobjt.xxs3_otc_parties
    SET process_flag = 'R'
    WHERE xx_party_id = p_xx_party_id;
  
    /* Insert reject records in the DQ table with DQ details */
    l_step := 'Insert into DQ table for rejected records';
  
    INSERT INTO xxobjt.xxs3_otc_parties_dq
      (xx_dq_party_id
      ,xx_party_id
      ,rule_name
      ,notes
      ,dq_status)
    VALUES
      (xxobjt.xxs3_otc_parties_dq_seq.NEXTVAL
      ,p_xx_party_id
      ,p_rule_name
      ,p_reject_code
      ,'R');
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log
                       ,'Unexpected error during DQ table DML for xx_party_id = ' ||
                        p_xx_party_id || 'at step: ' || l_step || chr(10) ||
                        SQLCODE || chr(10) || SQLERRM);
  END insert_update_r_dq;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Insert into Contact Point DQ table for validation errors and update the master table
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  26/04/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  PROCEDURE insert_update_contact_dq(p_xx_cont_point_id IN NUMBER
                                    ,p_rule_name        IN VARCHAR2
                                    ,p_reject_code      IN VARCHAR2) IS
  
    l_step VARCHAR2(50);
  BEGIN
    /* Update Process flag for DQ  records with 'Q' */
    l_step := 'Set Process_Flag = Q';
  
    UPDATE xxobjt.xxs3_otc_party_contact_points
    SET process_flag = 'Q'
    WHERE xx_party_contact_point_id = p_xx_cont_point_id;
  
    /* Insert dq records in the DQ table with DQ details */
    l_step := 'Insert into DQ table';
  
    INSERT INTO xxobjt.xxs3_otc_party_cont_points_dq
      (xx_dq_party_contact_point_id
      ,xx_party_contact_point_id
      ,rule_name
      ,notes
      ,dq_status)
    VALUES
      (xxobjt.xxs3_otc_party_cont_pts_dq_seq.NEXTVAL
      ,p_xx_cont_point_id
      ,p_rule_name
      ,p_reject_code
      ,'Q');
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log
                       ,'Unexpected error during DQ table DML for xx_cont_point_id = ' ||
                        p_xx_cont_point_id || 'at step: ' || l_step ||
                        chr(10) || SQLCODE || chr(10) || SQLERRM);
  END insert_update_contact_dq;
  
   --------------------------------------------------------------------------------------------
  -- Purpose: This function will return value for customer account for which all sites have
  --          Org id as 737
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0 29/12/2016  Debarati Banerjee             Initial build
  -- --------------------------------------------------------------------------------------------
   FUNCTION get_site_count(p_cust_account_id IN NUMBER) RETURN VARCHAR2 IS
    l_status        VARCHAR2(10);
    l_site_count    NUMBER;
    l_site_us_count NUMBER;
  
  BEGIN
  
    BEGIN
     SELECT COUNT(*) --check for the sites which have qualified extracted records
      INTO   l_site_count
      FROM   hz_cust_accounts       hca,
             xxs3_otc_cust_acct_sites hcas
      WHERE  hca.cust_account_id = hcas.legacy_cust_account_id
      AND    hca.cust_account_id = p_cust_account_id
      AND    hcas.extract_rule_name IS NOT NULL;
    EXCEPTION
      WHEN OTHERS THEN
        l_site_count := -999;
    END;
  
    BEGIN
      SELECT COUNT(*)--check for the sites which have qualified extracted records
      INTO   l_site_us_count
      FROM   hz_cust_accounts       hca,
             xxs3_otc_cust_acct_sites hcas
      WHERE  hca.cust_account_id = hcas.legacy_cust_account_id
      AND    hca.cust_account_id = p_cust_account_id
      AND    hcas.org_id = 737
      AND    hcas.extract_rule_name IS NOT NULL;
    EXCEPTION
      WHEN OTHERS THEN
        l_site_us_count := -888;
    END;
  
    IF l_site_count = l_site_us_count THEN
      l_status := 'Y';
    ELSE
      l_status := 'N';
    END IF;
  
    RETURN l_status;
  
  EXCEPTION
    WHEN OTHERS THEN
      l_status := 'NA';
    
  END;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Extract data from staging tables for quality check of PARTY data
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  26/04/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  PROCEDURE quality_check_party IS
    l_party_name  VARCHAR2(10);
    l_result      VARCHAR2(10);
    l_result002   VARCHAR2(10);
    l_result002_1 VARCHAR2(10);
    l_result004   VARCHAR2(10);
    l_result004_1 VARCHAR2(10);
    l_result004_2 VARCHAR2(10);
    l_result005   VARCHAR2(10);
    l_result006   VARCHAR2(10);
    l_result007   VARCHAR2(10);
    l_result008   VARCHAR2(10);
    l_result009   VARCHAR2(10);
    l_result010   VARCHAR2(10);
    l_result011   VARCHAR2(10);
    l_result012   BOOLEAN;
    l_result013   BOOLEAN;
    l_result015   BOOLEAN;
    l_result016   BOOLEAN;
    l_result017   BOOLEAN;
    l_result018   BOOLEAN;
    l_result019   BOOLEAN;
    l_result020   BOOLEAN;
    l_result021   VARCHAR2(10);
    l_status      BOOLEAN := TRUE;
    l_country     VARCHAR2(10) := 'FALSE';
    l_check_rule  VARCHAR2(10) := 'FALSE';
    --
  BEGIN
    /* DQ rules Validation for Party begin */
    FOR i IN (SELECT xx_party_id
                    ,s3_party_name
                    ,person_last_name
                    ,address4
                    ,postal_code
                    ,party_type
                    ,person_first_name
                    ,email_address
                    ,address1
                    ,address2
                    ,address3
                    ,city
                    ,country
                    ,state
                    ,province
              FROM xxobjt.xxs3_otc_parties a
              WHERE extract_rule_name IS NOT NULL             
              )
    LOOP
    
      l_status := TRUE;
      --
     --IF xxs3_otc_customer_pkg.get_site_count(j.legacy_cust_account_id) = 'Y' THEN   
      l_result      := xxs3_dq_util_pkg.eqt_001(i.s3_party_name);
      l_result002   := xxs3_dq_util_pkg.eqt_002(i.s3_party_name);
      l_result002_1 := xxs3_dq_util_pkg.eqt_002(i.person_last_name);
      l_result017   := xxs3_dq_util_pkg.eqt_017(i.party_type);
      l_result018   := xxs3_dq_util_pkg.eqt_018(i.person_first_name
                                               ,i.party_type);
      l_result019   := xxs3_dq_util_pkg.eqt_019(i.person_last_name
                                               ,i.party_type);  
     --END IF;
      l_result013   := xxs3_dq_util_pkg.eqt_013(i.address4);
      l_result016   := xxs3_dq_util_pkg.eqt_016(i.postal_code);
      
      
      
      l_result021   := xxs3_dq_util_pkg.eqt_021(i.email_address);
    
      /* Data Quality Validations details insert into DQ table */
    
      IF i.party_type = 'ORGANIZATION'
      THEN
        IF l_result = 'FALSE'
        THEN
          insert_update_dq(i.xx_party_id
                          ,'EQT_001'
                          ,'EQT_001 :Non-std Org Name');
          l_status := FALSE;
        END IF;
      END IF;
      --
      IF i.party_type = 'PERSON'
      THEN
        IF l_result002 = 'FALSE'
        THEN
          insert_update_dq(i.xx_party_id
                          ,'EQT_002'
                          ,'EQT_002 :Non-std Person Name');
          l_status := FALSE;
        END IF;
      END IF;
    
      IF i.party_type = 'ORGANIZATION'
      THEN
        
        IF i.address1 IS NOT NULL THEN
          l_check_rule := xxs3_dq_util_pkg.eqt_004(i.address1);
          IF l_check_rule = 'FALSE'
          THEN
            insert_update_dq(i.xx_party_id
                            ,'EQT_004'
                            ,'EQT_004 :Non-std Address Line ' || '' ||
                             'for field ' || 'ADDRESS1');
            l_status := FALSE;
          END IF;
        END IF;
      END IF;
      IF i.address2 IS NOT NULL
      THEN
        l_check_rule := xxs3_dq_util_pkg.eqt_004(i.address2);
        IF l_check_rule = 'FALSE'
        THEN
          insert_update_dq(i.xx_party_id
                          ,'EQT_004'
                          ,'EQT_004 :Non-std Address Line ' || '' ||
                           'for field ' || 'ADDRESS2');
          l_status := FALSE;
        END IF;
      END IF;
      --
      IF i.address3 IS NOT NULL
      THEN
        l_check_rule := xxs3_dq_util_pkg.eqt_004(i.address3);
      
        IF l_check_rule = 'FALSE'
        THEN
          insert_update_dq(i.xx_party_id
                          ,'EQT_004'
                          ,'EQT_004 :Non-std Address Line ' || '' ||
                           'for field ' || 'ADDRESS3');
          l_status := FALSE;
        END IF;
      END IF;
      --
      IF i.party_type = 'ORGANIZATION'
      THEN
        
        IF i.city IS NOT NULL THEN
          l_check_rule := xxs3_dq_util_pkg.eqt_005(i.city);
          IF l_check_rule = 'FALSE'
          THEN
            insert_update_dq(i.xx_party_id
                            ,'EQT_005'
                            ,'EQT_005 :Non-std City');
            l_status := FALSE;
          END IF;
        END IF;
        
        IF i.city IS NULL
        THEN
          insert_update_dq(i.xx_party_id
                          ,'EQT_015'
                          ,'EQT_015 :Missing City');
          l_status := FALSE;
      END IF;
      
      IF l_result016 = TRUE
        THEN
          insert_update_dq(i.xx_party_id
                          ,'EQT_016'
                          ,'EQT_016 :Missing Postal Code');
          l_status := FALSE;
        END IF;
        --
        
        IF i.country IS NOT NULL THEN
          IF length(i.country) = 2
          THEN
            l_country := xxs3_dq_util_pkg.eqt_008(i.country);
            IF l_country = 'FALSE'
            THEN
              insert_update_dq(i.xx_party_id
                              ,'EQT_008'
                              ,'EQT_008 :Non-std Country Code');
              l_status := FALSE;
            END IF;
          ELSIF length(i.country) > 2
          THEN
            l_country := xxs3_dq_util_pkg.eqt_011(i.country);
            IF l_country = 'FALSE'
            THEN
              insert_update_dq(i.xx_party_id
                              ,'EQT_011'
                              ,'EQT_011 :Non-std Country Name');
              l_status := FALSE;
            END IF;
          END IF;
          IF l_country = 'TRUE'
          THEN
            /*--check state if country lookup is available*/
            IF i.state IS NOT NULL
            THEN
              IF length(i.state) = 2
              THEN
                l_check_rule := xxs3_dq_util_pkg.eqt_006(i.state
                                                        ,i.country);
                IF l_check_rule = 'FALSE'
                THEN
                  insert_update_dq(i.xx_party_id
                                  ,'EQT_006'
                                  ,'EQT_006 :Non-std State Code');
                  l_status := FALSE;
                END IF;
              ELSIF length(i.state) > 2
              THEN
                l_check_rule := xxs3_dq_util_pkg.eqt_009(i.state
                                                        ,i.country);
                IF l_check_rule = 'FALSE'
                THEN
                  insert_update_dq(i.xx_party_id
                                  ,'EQT_009'
                                  ,'EQT_009 :Non-std State Name');
                  l_status := FALSE;
                END IF;
              END IF;
            END IF;
            /*check province if country lookup is available*/
            IF i.province IS NOT NULL
            THEN
              IF length(i.province) = 2
              THEN
                l_check_rule := xxs3_dq_util_pkg.eqt_007(i.province
                                                        ,i.country);
                IF l_check_rule = 'FALSE'
                THEN
                  insert_update_dq(i.xx_party_id
                                  ,'EQT_007'
                                  ,'EQT_007 :Non-std Province Code');
                  l_status := FALSE;
                END IF;
              ELSIF length(i.province) > 2
              THEN
                l_check_rule := xxs3_dq_util_pkg.eqt_010(i.province
                                                        ,i.country);
                IF l_check_rule = 'FALSE'
                THEN
                  insert_update_dq(i.xx_party_id
                                  ,'EQT_010'
                                  ,'EQT_010 :Non-std Province Name');
                  l_status := FALSE;
                END IF;
              END IF;
            END IF;
          END IF;
        END IF;
      END IF;
      --    
      
      IF l_result018 = TRUE
      THEN
        insert_update_dq(i.xx_party_id
                        ,'EQT_018'
                        ,'EQT_018 : Missing first name');
        l_status := FALSE;
      END IF;
      --
      IF i.party_type = 'PERSON'
      THEN
        IF l_result019 = TRUE
        THEN
          insert_update_dq(i.xx_party_id
                          ,'EQT_019'
                          ,'EQT_019 : Missing last name');
          l_status := FALSE;
        END IF;
        IF l_result002_1 = 'FALSE'
        THEN
          insert_update_dq(i.xx_party_id
                          ,'EQT_002'
                          ,'EQT_002 :Non-std Person Name');
          l_status := FALSE;
        END IF;
      END IF;
    
      IF l_result021 = 'FALSE'
      THEN
        insert_update_dq(i.xx_party_id
                        ,'EQT_021'
                        ,'EQT_021 : Invalid email format');
        l_status := FALSE;
      END IF;
      
      IF l_result017 = TRUE
      THEN
      
        insert_update_r_dq(i.xx_party_id
                        ,'EQT_017'
                        ,'EQT_017 :Invalid Party_type');
        l_status := FALSE;
      END IF;
     
     IF i.party_type = 'ORGANIZATION' THEN
      IF i.country IS NULL
        THEN
          insert_update_r_dq(i.xx_party_id
                          ,'EQT_012'
                          ,'EQT_012 :Missing Country Code');
          l_status := FALSE;
      END IF;
      
      IF i.address1 IS NULL
        THEN
          insert_update_r_dq(i.xx_party_id
                          ,'EQT_020'
                          ,'EQT_020 :Missing Address1');
          l_status := FALSE;
      END IF;
      
      
     END IF;
     
       IF l_result013 = TRUE THEN
        insert_update_r_dq(i.xx_party_id
                        ,'EQT_013'
                        ,'EQT_013 :Avalara Error');
        l_status := FALSE;
      END IF;
    
      IF l_status = TRUE
      THEN
        UPDATE xxobjt.xxs3_otc_parties
        SET process_flag = 'Y'
        WHERE xx_party_id = i.xx_party_id;
      END IF;
      --
    END LOOP;
    /* DQ rules Validation for Party end */
  
  END quality_check_party;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: Extract data from staging tables for quality check of CONTACT POINTS 
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  26/04/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  PROCEDURE quality_check_contact_points IS
    l_party_name VARCHAR2(10);
    l_result     BOOLEAN;
    l_result022  BOOLEAN;
    l_result023  BOOLEAN;
    l_status     BOOLEAN := TRUE;
    --
  BEGIN
    /* DQ rules Validation for contact points begin */
    FOR i IN (SELECT xx_party_contact_point_id
                    ,s3_email_format
                    ,email_address
              FROM xxobjt.xxs3_otc_party_contact_points
              WHERE process_flag = 'N')
    LOOP
    
      l_status    := TRUE;
      l_result022 := xxs3_dq_util_pkg.eqt_022(i.s3_email_format
                                             ,i.email_address);
      l_result023 := xxs3_dq_util_pkg.eqt_023(i.s3_email_format
                                             ,i.email_address);
    
    
      IF l_result022 = TRUE
      THEN
        insert_update_contact_dq(i.xx_party_contact_point_id
                                ,'EQT_022'
                                ,'EQT_022 :invalid email address-email format combo');
        l_status := FALSE;
      
      END IF;
      --
      IF l_result023 = TRUE
      THEN
        insert_update_contact_dq(i.xx_party_contact_point_id
                                ,'EQT_023'
                                ,'EQT_023 :Invalid Email Address-Email Format combo');
        l_status := FALSE;
        --
      END IF;
      IF l_status = TRUE
      THEN
        UPDATE xxobjt.xxs3_otc_party_contact_points
        SET process_flag = 'Y'
        WHERE xx_party_contact_point_id = i.xx_party_contact_point_id;
      END IF;
      --
    END LOOP;
    /* DQ rules Validation for contact points end */
  END quality_check_contact_points;

  ----------------------------------------------------------------------------------------------
  -- Purpose: Update party_name is used for party name cleansing
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  19/04/2016  TCS                           Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE update_party_name(p_id         IN NUMBER
                             ,p_party_name IN VARCHAR2) IS
  
    l_error_msg VARCHAR2(2000);
  
  BEGIN
  
    /* Update the s3 Party Name in stg table */
  
    IF regexp_like(p_party_name
                  ,'[A-Za-z]'
                  ,'i')
    THEN
      BEGIN
        UPDATE xxs3_otc_parties
        SET s3_party_name  = regexp_replace(p_party_name
                                           ,'Inc\.|INC'
                                           ,'Inc')
           ,cleanse_status = 'PASS'
        WHERE xx_party_id = p_id
        AND regexp_like(p_party_name
                      ,'Inc\.|INC');
      
        UPDATE xxs3_otc_parties
        SET s3_party_name  = regexp_replace(p_party_name
                                           ,'Corp\.|CORP'
                                           ,'Corp')
           ,cleanse_status = 'PASS'
        WHERE xx_party_id = p_id
        AND regexp_like(p_party_name
                      ,'Corp\.|CORP');
      
        UPDATE xxs3_otc_parties
        SET s3_party_name  = regexp_replace(p_party_name
                                           ,'LLC\.'
                                           ,'LLC')
           ,cleanse_status = 'PASS'
        WHERE xx_party_id = p_id
        AND regexp_like(p_party_name
                      ,'LLC\.');
      
        UPDATE xxs3_otc_parties
        SET s3_party_name  = regexp_replace(p_party_name
                                           ,'Ltd\.|LTD\.|LTD'
                                           ,'Ltd')
           , --LTD\. is new rule
            cleanse_status = 'PASS'
        WHERE xx_party_id = p_id
        AND regexp_like(p_party_name
                      ,'Ltd\.|LTD\.|LTD');
      
        UPDATE xxs3_otc_parties
        SET s3_party_name  = regexp_replace(p_party_name
                                           ,'P\.O\.'
                                           ,'PO')
           ,cleanse_status = 'PASS'
        WHERE xx_party_id = p_id
        AND regexp_like(p_party_name
                      ,'P\.O\.');
      
        UPDATE xxs3_otc_parties
        SET s3_party_name  = regexp_replace(p_party_name
                                           ,'A\.P\.|A/P'
                                           ,'AP')
           ,cleanse_status = 'PASS'
        WHERE xx_party_id = p_id
        AND regexp_like(p_party_name
                      ,'A\.P\.|A/P');
      
        UPDATE xxs3_otc_parties
        SET s3_party_name  = regexp_replace(p_party_name
                                           ,'CO\.|Co\.'
                                           ,'Company')
           ,cleanse_status = 'PASS'
        WHERE xx_party_id = p_id
        AND regexp_like(p_party_name
                      ,'CO\.|Co\.');
      
        UPDATE xxs3_otc_parties
        SET s3_party_name  = regexp_replace(p_party_name
                                           ,'A\.R\.|A/R'
                                           ,'AR')
           ,cleanse_status = 'PASS'
        WHERE xx_party_id = p_id
        AND regexp_like(p_party_name
                      ,'A\.R\.|A/R');
      
      EXCEPTION
        WHEN OTHERS THEN
          l_error_msg := 'UNEXPECTED ERROR on Party Name update : ' ||
                         SQLCODE || '-' || SQLERRM;
          BEGIN
            UPDATE xxs3_otc_parties
            SET cleanse_status = 'FAIL'
               ,cleanse_error  = cleanse_error || '' || '' || l_error_msg
            WHERE xx_party_id = p_id;
          EXCEPTION
            WHEN OTHERS THEN
              fnd_file.put_line(fnd_file.log
                               ,'Unexpected error during cleansing of party name for xx_party_id = ' || p_id ||
                                chr(10) || SQLCODE || chr(10) || SQLERRM);
          END;
      END;
    END IF;
  
  END update_party_name;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: Update email format for party contact points data
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  26/04/2016  MISHAL KUMAR                  Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE cleanse_cont_pts_email(p_id    IN NUMBER
                                  ,p_email IN VARCHAR2) IS
    l_error_msg VARCHAR2(2000);
  BEGIN
    /* Update the s3 value with cleanse value */
    UPDATE xxs3_otc_party_contact_points
    SET s3_email_format = 'MAILTEXT'
       ,cleanse_status  = 'PASS'
    WHERE xx_party_contact_point_id = p_id;
  EXCEPTION
    WHEN OTHERS THEN
      l_error_msg := 'UNEXPECTED ERROR on email format update : ' ||
                     SQLCODE || '-' || SQLERRM;
      BEGIN
        UPDATE xxs3_otc_party_contact_points
        SET cleanse_status = 'FAIL'
           ,cleanse_error  = cleanse_error || '' || '' || l_error_msg
        WHERE xx_party_contact_point_id = p_id;
      EXCEPTION
        WHEN OTHERS THEN
          fnd_file.put_line(fnd_file.log
                           ,'Unexpected error during cleansing of email format for xx_party_contact_point_id = ' || p_id ||
                            chr(10) || SQLCODE || chr(10) || SQLERRM);
      END;
    
  END cleanse_cont_pts_email;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: Update WEB TYPE for party contact points data
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  26/04/2016  MISHAL KUMAR                  Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE cleanse_cont_pts_web(p_id  IN NUMBER
                                ,p_url IN VARCHAR2) IS
    l_error_msg VARCHAR2(2000);
  BEGIN
    /* Update the S3 web type value */
  
    UPDATE xxs3_otc_party_contact_points
    SET s3_web_type    = 'HTTP'
       ,cleanse_status = 'PASS'
    WHERE xx_party_contact_point_id = p_id
    AND regexp_like(p_url
                  ,'^http|^https');
  
  EXCEPTION
    WHEN OTHERS THEN
      l_error_msg := 'UNEXPECTED ERROR on Web type update : ' || SQLCODE || '-' ||
                     SQLERRM;
      BEGIN
        UPDATE xxs3_otc_party_contact_points
        SET cleanse_status = 'FAIL'
           ,cleanse_error  = cleanse_error || '' || '' || l_error_msg
        WHERE xx_party_contact_point_id = p_id;
      EXCEPTION
        WHEN OTHERS THEN
          fnd_file.put_line(fnd_file.log
                           ,'Unexpected error during cleansing of web type for xx_party_contact_point_id = ' || p_id ||
                            chr(10) || SQLCODE || chr(10) || SQLERRM);
      END;
    
  END cleanse_cont_pts_web;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required Party fields and insert into
  --           staging table XXS3_OTC_PARTIES
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0 26/04/2016  Mishal Kumar                  Initial build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE party_extract_data(x_errbuf  OUT VARCHAR2
                              ,x_retcode OUT NUMBER) IS
  
    l_errbuf             VARCHAR2(2000);
    l_retcode            VARCHAR2(1);
    l_requestor          NUMBER;
    l_program_short_name VARCHAR2(100);
    l_status_message     VARCHAR2(4000);
    l_counter            NUMBER;
    l_count_party        NUMBER;
    l_err_msg                VARCHAR2(4000);
    l_err_code               VARCHAR2(100);
  
    /* Cursor for the Party extract */  
    
  
    /*CURSOR cur_party_extract IS
      SELECT p.party_name            party_name
            , --25662
             p.person_first_name     person_first_name
            ,p.person_middle_name    person_middle_name
            ,p.person_last_name      person_last_name
            ,p.validated_flag        validated_flag
            ,p.person_title          person_title
            ,p.party_type            party_type
            ,p.status                status
            ,p.known_as              known_as
            ,p.duns_number           duns_number
            ,p.tax_reference         tax_reference
            ,p.jgzz_fiscal_code      jgzz_fiscal_code
            ,p.party_id              party_id
            ,p.party_number          party_number
            ,p.orig_system_reference orig_system_reference
            ,p.party_id              legacy_orig_system_reference
            ,p.attribute14           contract_end_date
            ,p.attribute13           contract_start_date
            ,p.attribute3            customer_support_ou
             ,(SELECT NAME
                             FROM hr_operating_units
                            WHERE organization_id = p.attribute3) customer_support_ou_name
            ,p.attribute12                 national_reg_no
            ,p.attribute5                  sam_account_flag
            ,p.attribute11                 sam_basket_level
            ,p.attribute4                  sam_benefit_start_date
            ,p.attribute9                  sam_manager
            ,p.attribute2                  security_exception
            ,p.attribute7                  vip_customer
            ,p.attribute1                  attribute1
            ,p.customer_key                customer_key
            ,p.person_pre_name_adjunct     person_pre_name_adjunct
            ,p.person_name_suffix          person_name_suffix
            ,p.group_type                  group_type
            ,p.group_type                  s3_group_type
            ,p.url                         url
            ,p.gsa_indicator_flag          gsa_indicator_flag
            ,p.category_code               category_code
            ,p.category_code               s3_category_code
            ,p.duns_number_c               duns_number_c
            ,p.created_by_module           created_by_module
            ,p.primary_phone_contact_pt_id primary_phone_contact_pt_id
            ,p.primary_phone_purpose       primary_phone_purpose
            ,p.primary_phone_line_type     primary_phone_line_type
            ,p.primary_phone_country_code  primary_phone_country_code
            ,p.primary_phone_area_code     primary_phone_area_code
            ,p.primary_phone_number        primary_phone_number
            ,p.primary_phone_extension     primary_phone_extension
            ,p.address1                    address1
            ,p.address2                    address2
            ,p.address3                    address3
            ,p.address4                    address4
            ,p.city                        city
            ,p.postal_code                 postal_code
            ,p.state                       state
            ,p.province                    province
            ,p.country                     country
            ,p.county                      county
            ,p.email_address               email_address
            ,p.creation_date               creation_date
            ,p.created_by                  created_by
            ,p.last_update_date            last_update_date
            ,p.last_updated_by             last_updated_by
      FROM hz_parties p;*/
     /* WHERE p.status = 'A'
      AND EXISTS (SELECT party_id
             FROM hz_cust_accounts hca
             WHERE status = 'A'
             AND hca.party_id = p.party_id);*/
             
   /* CURSOR cur_transform IS 
     SELECT  customer_support_ou_name,xx_party_id
     FROM  xxs3_otc_parties
     WHERE process_flag <> 'R'
     AND extract_rule_name IS NOT NULL;      */ 
     
     CURSOR cur_party_extract IS 
     SELECT p.address1 address1,
            p.address2 address2,
            p.address3 address3,
            p.address4 address4,
            p.attribute11 sam_basket_level,
            p.attribute12 national_reg_no,
            p.attribute13 contract_start_date,
            p.attribute14 contract_end_date,
            p.attribute2 security_exception,
            p.attribute3 customer_support_ou,
            (SELECT NAME
               FROM hr_operating_units
              WHERE organization_id = p.attribute3) customer_support_ou_name,
            p.attribute4 sam_benefit_start_date,
            p.attribute5 sam_account_flag,
            p.attribute7 vip_customer,
            p.attribute9 sam_manager,
            p.category_code category_code,
            p.city city,
            p.country country,
            p.county county,
            p.created_by created_by,
            p.creation_date creation_date,
            p.customer_key customer_key,
            p.duns_number duns_number,
            p.email_address email_address,
            p.gsa_indicator_flag gsa_indicator_flag,
            p.jgzz_fiscal_code jgzz_fiscal_code,
            p.known_as known_as,
            p.orig_system_reference orig_system_reference,
            p.party_id party_id,
            p.party_name party_name,
            p.party_number party_number,
            p.party_type party_type,
            p.person_first_name person_first_name,
            p.person_last_name person_last_name,
            p.person_middle_name person_middle_name,
            p.person_title person_title,
            p.postal_code postal_code,
            p.primary_phone_area_code primary_phone_area_code,
            p.primary_phone_contact_pt_id primary_phone_contact_pt_id,
            p.primary_phone_country_code primary_phone_country_code,
            p.primary_phone_extension primary_phone_extension,
            p.primary_phone_line_type primary_phone_line_type,
            p.primary_phone_number primary_phone_number,
            p.primary_phone_purpose primary_phone_purpose,
            p.province province,
            p.state state,
            p.status status,
            p.tax_reference tax_reference,
            p.validated_flag validated_flag,
            p.person_first_name || p.person_last_name default_contact_for_so
     
     /* ,p.party_id              legacy_orig_system_reference
                 
                 ,p.attribute1                  attribute1
                 ,p.person_pre_name_adjunct     person_pre_name_adjunct
                 ,p.person_name_suffix          person_name_suffix
                 ,p.group_type                  group_type
                 ,p.group_type                  s3_group_type
                 ,p.url                         url
                 ,p.category_code               s3_category_code
                 ,p.duns_number_c               duns_number_c
                 ,p.created_by_module           created_by_module
                 ,p.last_update_date            last_update_date
                 ,p.last_updated_by             last_updated_by*/
       FROM hz_parties p;
       
    TYPE t_party IS TABLE OF cur_party_extract%ROWTYPE INDEX BY PLS_INTEGER;
    l_party t_party;
  
    
  BEGIN
    x_retcode := 0;
    x_errbuf  := 'COMPLETE';
  
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_otc_parties';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_otc_parties_dq';
  
   BEGIN
    /*FOR i IN cur_party_extract
    LOOP*/
     fnd_file.put_line(fnd_file.output,'Start extracting');
    OPEN cur_party_extract;
    LOOP
      FETCH cur_party_extract BULK COLLECT
        INTO l_party;
    
      FORALL i IN 1 .. l_party.COUNT
      /*INSERT INTO xxobjt.xxs3_otc_parties
        (xx_party_id
        ,party_name
         --,s3_party_name
        ,person_first_name
        ,person_middle_name
        ,person_last_name
        ,validated_flag
        ,person_title
        ,party_type
         
         --party_id,
         --party_number,
         --orig_system_reference
        ,legacy_orig_system_reference
        ,status
        ,known_as
        ,duns_number
        ,tax_reference
        ,jgzz_fiscal_code
        ,legacy_party_id
        ,legacy_party_number
        ,attribute14
        ,attribute13
        ,attribute3
        --,customer_support_ou_name 
        ,attribute12
        ,attribute5
        ,attribute11
        ,attribute4
        ,attribute9
        ,attribute2
        ,attribute7
        ,attribute1
        ,customer_key
        ,person_pre_name_adjunct
        ,person_name_suffix
        ,group_type
        ,s3_group_type
        ,url
        ,gsa_indicator_flag
        ,category_code
        ,s3_category_code
        ,duns_number_c
        ,created_by_module
        ,primary_phone_contact_pt_id
        ,primary_phone_purpose
        ,primary_phone_line_type
        ,primary_phone_country_code
        ,primary_phone_area_code
        ,primary_phone_number
        ,primary_phone_extension
        ,address1
        ,address2
        ,address3
        ,address4
        ,city
        ,postal_code
        ,state
        ,province
        ,country
        ,county
        ,email_address
        ,creation_date
        ,created_by
        ,last_update_date
        ,last_updated_by
        ,date_extracted_on
        ,process_flag)
      VALUES
        (xxobjt.xxs3_otc_party_seq.NEXTVAL
        ,i.party_name
         --,i.party_name
        ,i.person_first_name
        ,i.person_middle_name
        ,i.person_last_name
        ,i.validated_flag
        ,i.person_title
        ,i.party_type
         
         --null,
         --null,
         -- i.       
        ,i.legacy_orig_system_reference
        ,i.status
        ,i.known_as
        ,i.duns_number
        ,i.tax_reference
        ,i.jgzz_fiscal_code
        ,i.party_id
        ,i.party_number
        ,i.contract_end_date
        ,i.contract_start_date
        ,i.customer_support_ou
        --,i.customer_support_ou_name
        ,i.national_reg_no
        ,i.sam_account_flag
        ,i.sam_basket_level
        ,i.sam_benefit_start_date
        ,i.sam_manager
        ,i.security_exception
        ,i.vip_customer
         \*,i.attribute14
                 ,i.attribute13
                 ,i.attribute3
                 ,i.attribute12
                 ,i.attribute5
                 ,i.attribute11
                 ,i.attribute4
                 ,i.attribute9
                 ,i.attribute2
                 ,i.attribute7*\
        ,i.attribute1
        ,i.customer_key
        ,i.person_pre_name_adjunct
        ,i.person_name_suffix
        ,i.group_type
        ,i.s3_group_type
        ,i.url
        ,i.gsa_indicator_flag
        ,i.category_code
        ,i.s3_category_code
        ,i.duns_number_c
        ,i.created_by_module
        ,i.primary_phone_contact_pt_id
        ,i.primary_phone_purpose
        ,i.primary_phone_line_type
        ,i.primary_phone_country_code
        ,i.primary_phone_area_code
        ,i.primary_phone_number
        ,i.primary_phone_extension
        ,i.address1
        ,i.address2
        ,i.address3
        ,i.address4
        ,i.city
        ,i.postal_code
        ,i.state
        ,i.province
        ,i.country
        ,i.county
        ,i.email_address
        ,i.creation_date
        ,i.created_by
        ,i.last_update_date
        ,i.last_updated_by
        ,SYSDATE
        ,'N');*/
        
        
INSERT INTO xxobjt.xxs3_otc_parties
  (xx_party_id,
   address1,
   address2,
   address3,
   address4,
   attribute11,
   attribute12,
   attribute13,
   attribute14,
   attribute2,
   attribute3,
   customer_support_ou,
   attribute4,
   attribute5,
   attribute7,
   attribute9,
   category_code,
   city,
   country,
   created_by,
   creation_date,
   customer_key,
   duns_number,
   email_address,
   gsa_indicator_flag,
   jgzz_fiscal_code,
   known_as,
   legacy_orig_system_reference,
   legacy_party_id,
   party_name,
   legacy_party_number,
   party_type,
   person_first_name,
   person_last_name,
   person_middle_name,
   person_title,
   postal_code,
   primary_phone_area_code,
   primary_phone_contact_pt_id,
   primary_phone_country_code,
   primary_phone_extension,
   primary_phone_line_type,
   primary_phone_number,
   primary_phone_purpose,
   province,
   state,
   status,
   tax_reference,
   validated_flag,
   default_contact_for_so,
   date_extracted_on,
   process_flag)
VALUES
  (xxobjt.xxs3_otc_party_seq.NEXTVAL,
   l_party(i).address1,
   l_party(i).address2,
   l_party(i).address3,
   l_party(i).address4,
   l_party(i).sam_basket_level,
   l_party(i).national_reg_no,
   l_party(i).contract_start_date,
   l_party(i).contract_end_date,
   l_party(i).security_exception,
   l_party(i).customer_support_ou,
   l_party(i).customer_support_ou_name,
   l_party(i).sam_benefit_start_date,
   l_party(i).sam_account_flag,
   l_party(i).vip_customer,
   l_party(i).sam_manager,
   l_party(i).category_code,
   l_party(i).city,
   l_party(i).country,
   l_party(i).created_by,
   l_party(i).creation_date,
   l_party(i).customer_key,
   l_party(i).duns_number,
   l_party(i).email_address,
   l_party(i).gsa_indicator_flag,
   l_party(i).jgzz_fiscal_code,
   l_party(i).known_as,
   l_party(i).orig_system_reference,
   l_party(i).party_id,
   l_party(i).party_name,
   l_party(i).party_number,
   l_party(i).party_type,
   l_party(i).person_first_name,
   l_party(i).person_last_name,
   l_party(i).person_middle_name,
   l_party(i).person_title,
   l_party(i).postal_code,
   l_party(i).primary_phone_area_code,
   l_party(i).primary_phone_contact_pt_id,
   l_party(i).primary_phone_country_code,
   l_party(i).primary_phone_extension,
   l_party(i).primary_phone_line_type,
   l_party(i).primary_phone_number,
   l_party(i).primary_phone_purpose,
   l_party(i).province,
   l_party(i).state,
   l_party(i).status,
   l_party(i).tax_reference,
   l_party(i).validated_flag,
   l_party(i).default_contact_for_so,
   SYSDATE,
   'N');
    /*END LOOP;
    COMMIT;*/
    
    EXIT WHEN cur_party_extract%NOTFOUND;
    END LOOP;
    CLOSE cur_party_extract;
    --END LOOP;
  
    COMMIT;
    --
   EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -24381 THEN
        FOR indx IN 1 .. SQL%BULK_EXCEPTIONS.COUNT LOOP
          fnd_file.put_line(fnd_file.log, 'Unexpected error during data extraction : ' ||
                             chr(10) ||
                             SQL%BULK_EXCEPTIONS(indx)
                            .ERROR_INDEX || ':' ||
                             SQL%BULK_EXCEPTIONS(indx)
                            .ERROR_CODE);
          fnd_file.put_line(fnd_file.log, '--------------------------------------');
        
        END LOOP;
      ELSE
        RAISE;
      END IF;
   END; 
    fnd_file.put_line(fnd_file.log, 'Loading complete');
    
    --Apply extract Rules
    
    BEGIN
     UPDATE xxs3_otc_parties xop
        SET xop.extract_rule_name = CASE WHEN extract_rule_name = NULL THEN 'EXT-006' ELSE extract_rule_name || '|' || 'EXT-006' END
      WHERE EXISTS (SELECT party_id
               FROM xxs3_otc_customer_accounts a
              WHERE a.party_id = xop.legacy_party_id
                AND a.process_flag <> 'R'
                AND a.extract_rule_name IS NOT NULL
                AND nvl(a.transform_status,'PASS') <> 'FAIL')
     AND party_type <> 'GROUP';
     
       fnd_file.put_line(fnd_file.log,'Extract Rule Name-EXT-006: '||SQL%ROWCOUNT||' rows were updated'); 
     
    EXCEPTION
      WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log, 'Unexpected error during extract rules update : ' ||
                               chr(10) || SQLCODE || chr(10) ||
                               SQLERRM);                        
    END;
    
    --Apply extract Rules
    
    COMMIT;
    
    --Autocleanse
  
    BEGIN
      FOR t IN (SELECT xx_party_id
                      ,party_name
                      ,cust_account_id
                FROM xxs3_otc_parties xop,
                     hz_cust_accounts hca
                WHERE extract_rule_name IS NOT NULL
                AND hca.party_id = xop.legacy_party_id
                )
      LOOP
      
      IF xxs3_otc_party_pkg.get_site_count(t.cust_account_id) = 'Y' THEN          
        update_party_name(t.xx_party_id
                         ,t.party_name);
      END IF;
        UPDATE xxs3_otc_parties SET s3_party_name = party_name 
        WHERE s3_party_name IS NULL ;        
      END LOOP;
     
    EXCEPTION
      WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log
                         ,'Unexpected error during party name update : ' ||
                          chr(10) || SQLCODE || chr(10) || SQLERRM);
    END;
    
     COMMIT;
     
    --Autocleanse
    
    --DQ
  
    BEGIN
      quality_check_party;
      COMMIT;
    EXCEPTION
      WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log
                         ,'Unexpected error during DQ validation : ' ||
                          chr(10) || SQLCODE || chr(10) || SQLERRM);
    END;
    
    --DQ
  
    --Transform customer_support_ou
    BEGIN
      FOR l IN (SELECT attribute3,xx_party_id,customer_support_ou FROM xxs3_otc_parties 
                  WHERE extract_rule_name IS NOT NULL
                  AND process_flag <>'R') LOOP
                  
        IF l.attribute3 IS NOT NULL THEN
                                                         
          xxs3_data_transform_util_pkg.transform(p_mapping_type => 'organization_name', 
                                                  p_stage_tab => 'xxobjt.xxs3_otc_parties', --Staging Table Name
                                                  p_stage_primary_col => 'xx_party_id', --Staging Table Primary Column Name
                                                  p_stage_primary_col_val => l.xx_party_id, --Staging Table Primary Column Value
                                                  p_legacy_val => l.customer_support_ou, --Legacy Value
                                                  p_stage_col => 's3_customer_support_ou', --Staging Table Name
                                                  p_err_code => l_err_code, -- Output error code
                                                  p_err_msg => l_err_msg);          
        END IF;
      END LOOP;
    EXCEPTION
      WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log, 'Unexpected error during transformation : ' ||
                     chr(10) || SQLCODE || chr(10) || SQLERRM);
    END;
    
    --update process_flag='R' and EXTRACT_DQ_ERROR column in all dependent entities  
    
   BEGIN  
    UPDATE xxs3_otc_customer_accounts a
       SET process_flag     = 'R',
           extract_dq_error = 'Associated Party Record: '|| a.party_id||' has DQ error or transformation error'
     WHERE EXISTS
     (SELECT legacy_party_id
              FROM xxs3_otc_parties b
             WHERE b.legacy_party_id = a.party_id
               AND (nvl(b.transform_status, 'PASS') = 'FAIL' OR
                   b.process_flag = 'R')
               AND b.extract_rule_name is NOT NULL);
               
    UPDATE xxs3_otc_cust_acct_sites a
       SET process_flag     = 'R',
           extract_dq_error = 'Associated Party Record of customer id: '|| a.legacy_cust_account_id ||' has DQ error or transformation error'
     WHERE EXISTS
     (SELECT c.legacy_cust_account_id
              FROM xxs3_otc_parties b,xxs3_otc_customer_accounts c
             WHERE b.legacy_party_id = c.party_id
               AND c.legacy_cust_account_id = a.legacy_cust_account_id
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
    SELECT COUNT(1) INTO l_count_party FROM xxobjt.xxs3_otc_parties;
  
    fnd_file.put_line(fnd_file.output
                     ,rpad('Party Extract Records Count Report'
                          ,100
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,rpad('============================================================'
                          ,200
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,rpad('Run date and time:    ' ||
                           to_char(SYSDATE
                                  ,'dd-Mon-YYYY HH24:MI')
                          ,100
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,rpad('============================================================'
                          ,200
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,'');
    fnd_file.put_line(fnd_file.output
                     ,rpad('Track Name'
                          ,10
                          ,' ') || chr(32) ||
                      rpad('Entity Name'
                          ,30
                          ,' ') || chr(32) ||
                      rpad('Total Count'
                          ,15
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,rpad('==========================================================='
                          ,200
                          ,' '));
  
    fnd_file.put_line(fnd_file.output
                     ,'');
  
    fnd_file.put_line(fnd_file.output
                     ,rpad('OTC'
                          ,10
                          ,' ') || ' ' || rpad('PARTY'
                                              ,30
                                              ,' ') || ' ' ||
                      rpad(l_count_party
                          ,15
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,rpad('=========================================================='
                          ,200
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,'');
  
  
  EXCEPTION
    WHEN OTHERS THEN
      x_retcode        := 2;
      x_errbuf         := 'Unexpected error: ' || SQLERRM;
      l_status_message := SQLCODE || chr(10) || SQLERRM;
      fnd_file.put_line(fnd_file.log
                       ,'Unexpected error during data extraction : ' ||
                        chr(10) || l_status_message);
      fnd_file.put_line(fnd_file.log
                       ,'--------------------------------------');
    
  END party_extract_data;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required Party Sites fields and insert into
  --           staging table XXS3_OTC_PARTY_SITES
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0 26/04/2016  Mishal Kumar                  Initial build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE party_sites_extract_data(x_errbuf  OUT VARCHAR2
                                    ,x_retcode OUT NUMBER) IS
  
    l_errbuf             VARCHAR2(2000);
    l_retcode            VARCHAR2(1);
    l_requestor          NUMBER;
    l_program_short_name VARCHAR2(100);
    l_status_message     VARCHAR2(4000);
    l_counter            NUMBER;
    l_count_party_sites  NUMBER;
  
    CURSOR cur_party_sites_extract IS
      SELECT DISTINCT ps.identifying_address_flag identifying_address_flag
                     , --multiple entries in hz_cust_acct_sites_all.customer site in diff orgs
                      ps.status                   status
                     ,ps.party_site_name          party_site_name
                     ,ps.attribute11              AGENT
                     ,ps.attribute1               territory_rep_1
                     ,ps.attribute2               territory_rep_2
                     ,ps.party_site_id            party_site_id
                     ,ps.party_site_number        party_site_number
                     ,ps.party_id                 party_id
                     ,ps.location_id              location_id
                     /*,p.party_number              party_number --Commented 22/12
                     ,p.party_name                party_name*/ --Commented 22/12
                     ,ps.orig_system_reference    orig_system_reference
                     ,ps.creation_date            creation_date
                     ,ps.created_by               created_by/* --Commented 22/12
                     ,ca.primary_salesrep_id      primary_salesrep_id
                      
                     ,ca.ship_sets_include_lines_flag ship_sets_include_lines_flag
                     ,ca.ship_via                     ship_via
                     ,ca.warehouse_id                 warehouse_id*/ --Commented 22/12
      FROM hz_party_sites         ps;/* --Commented 22/12
          ,hz_cust_accounts       ca
          ,hz_cust_acct_sites_all casa
          ,hz_parties             p
      --hz_cust_site_uses_all  cusa,
      WHERE p.party_id = ca.party_id
      AND ps.party_id = p.party_id
      AND ps.party_site_id = casa.party_site_id
      AND ca.cust_account_id = casa.cust_account_id
      AND p.status = 'A'
      AND ps.status = 'A'
      AND p.status = 'A'
      AND ca.status = 'A'
      AND nvl(ps.status
            ,'A') = 'A'
      AND casa.status = 'A'
           --AND p.party_id = p_party_id
      AND EXISTS (SELECT legacy_party_id
             FROM xxs3_otc_parties
             WHERE process_flag <> 'R'
             AND legacy_party_id = p.party_id)
      AND EXISTS (SELECT legacy_location_id
             FROM xxs3_otc_location xol
             WHERE xol.legacy_location_id = ps.location_id
             AND process_flag <> 'R');*/   --Commented 22/12
  
  BEGIN
    x_retcode := 0;
    x_errbuf  := 'COMPLETE';
  
    BEGIN
      EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_otc_party_sites';
    
    
      FOR j IN cur_party_sites_extract
      LOOP
        INSERT INTO xxobjt.xxs3_otc_party_sites
          (xx_party_site_id
          ,identifying_address_flag
          ,status
          ,party_site_name
          ,attribute11
          ,attribute1
          ,attribute2
          ,legacy_party_site_id
          ,legacy_party_site_number
          ,party_id
          ,location_id
          /*,party_number --commented as on 22/12
          ,party_name*/
          ,orig_system_reference
          /*,primary_salesrep_id --commented as on 22/12
          ,ship_sets_include_lines_flag
          ,ship_via
          ,warehouse_id*/ --commented as on 22/12
          ,creation_date
          ,created_by
          ,date_extracted_on
          ,process_flag)
        VALUES
          (xxobjt.xxs3_otc_party_sites_seq.NEXTVAL
          ,j.identifying_address_flag
          ,j.status
          ,j.party_site_name
          ,j.AGENT
          ,j.territory_rep_1
          ,j.territory_rep_2
          ,j.party_site_id
          ,j.party_site_number
          ,j.party_id
          ,j.location_id
         /* ,j.party_number  --commented as on 22/12
          ,j.party_name*/    --commented as on 22/12
          ,j.orig_system_reference
         /* ,j.primary_salesrep_id   --commented as on 22/12
          ,j.ship_sets_include_lines_flag
          ,j.ship_via
          ,j.warehouse_id*/  --commented as on 22/12
          ,j.creation_date
          ,j.created_by
          ,SYSDATE
          ,'N');
      END LOOP;
    
      COMMIT;
      
      --Apply extract Rules
    
    BEGIN --Rejected party records will also mark relevant account site records to 'R'
     UPDATE xxs3_otc_party_sites xop
        SET xop.extract_rule_name = CASE WHEN extract_rule_name = NULL THEN 'EXT-012' ELSE extract_rule_name || '|' || 'EXT-012' END
      WHERE EXISTS (SELECT legacy_party_site_id
               FROM xxs3_otc_cust_acct_sites a
              WHERE a.legacy_party_site_id = xop.legacy_party_site_id
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
    
      SELECT COUNT(1)
      INTO l_count_party_sites
      FROM xxobjt.xxs3_otc_party_sites;
    
      fnd_file.put_line(fnd_file.output
                       ,rpad('Party Site Extract Records Count Report'
                            ,100
                            ,' '));
      fnd_file.put_line(fnd_file.output
                       ,rpad('============================================================'
                            ,200
                            ,' '));
      fnd_file.put_line(fnd_file.output
                       ,rpad('Run date and time:    ' ||
                             to_char(SYSDATE
                                    ,'dd-Mon-YYYY HH24:MI')
                            ,100
                            ,' '));
      fnd_file.put_line(fnd_file.output
                       ,rpad('============================================================'
                            ,200
                            ,' '));
      fnd_file.put_line(fnd_file.output
                       ,'');
      fnd_file.put_line(fnd_file.output
                       ,rpad('Track Name'
                            ,10
                            ,' ') || chr(32) ||
                        rpad('Entity Name'
                            ,30
                            ,' ') || chr(32) ||
                        rpad('Total Count'
                            ,15
                            ,' '));
      fnd_file.put_line(fnd_file.output
                       ,rpad('==========================================================='
                            ,200
                            ,' '));
    
      fnd_file.put_line(fnd_file.output
                       ,'');
    
      fnd_file.put_line(fnd_file.output
                       ,rpad('OTC'
                            ,10
                            ,' ') || ' ' || rpad('PARTY SITE'
                                                ,30
                                                ,' ') || ' ' ||
                        rpad(l_count_party_sites
                            ,15
                            ,' '));
      fnd_file.put_line(fnd_file.output
                       ,rpad('=========END OF REPORT==============='
                            ,200
                            ,' '));
      fnd_file.put_line(fnd_file.output
                       ,'');
    
    EXCEPTION
      WHEN OTHERS THEN
        x_retcode        := 2;
        x_errbuf         := 'Unexpected error: ' || SQLERRM;
        l_status_message := SQLCODE || chr(10) || SQLERRM;
        fnd_file.put_line(fnd_file.log
                         ,'Unexpected error during data extraction : ' ||
                          chr(10) || l_status_message);
        fnd_file.put_line(fnd_file.log
                         ,'--------------------------------------');
    END;
  END party_sites_extract_data;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required Party Site Uses fields and insert into
  --           staging table XXS3_OTC_PARTY_SITE_USES
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0 26/04/2016  Mishal Kumar                  Initial build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE party_site_uses_extract_data(x_errbuf  OUT VARCHAR2
                                        ,x_retcode OUT NUMBER) IS
  
    l_errbuf                 VARCHAR2(2000);
    l_retcode                VARCHAR2(1);
    l_requestor              NUMBER;
    l_program_short_name     VARCHAR2(100);
    l_status_message         VARCHAR2(4000);
    l_counter                NUMBER;
    l_count_party_sites_uses NUMBER;
  
    CURSOR cur_party_sites_uses IS
      SELECT  psu.party_site_use_id party_site_use_id
                     , -- due to use of table hz_cust_site_uses_all
                      psu.party_site_id     party_site_id
                     ,psu.site_use_type     site_use_type
                     --,ps.party_site_name    party_site_name --Commented as on 22/12
                     ,psu.status            status
                     ,psu.creation_date     creation_date
                     ,psu.created_by        created_by 
                     /*,psu.attribute1
                     ,psu.attribute2
                     ,psu.attribute10
                     ,psu.attribute12*/
      FROM hz_party_site_uses     psu;
         /* ,hz_party_sites         ps  --Commented as on 22/12
          ,hz_cust_acct_sites_all casa
          ,hz_cust_site_uses_all  csua
      WHERE psu.party_site_id = ps.party_site_id
      AND ps.party_site_id = casa.party_site_id
      AND casa.cust_acct_site_id = csua.cust_acct_site_id
      AND casa.org_id = csua.org_id
      AND psu. status = 'A'
      AND ps. status = 'A'*/  --Commented as on 22/12
           --AND psu.party_site_id = p_party_site_id
      /*AND EXISTS (SELECT legacy_party_site_id
             FROM xxs3_otc_party_sites xops
             WHERE xops.legacy_party_site_id = psu.party_site_id
             AND process_flag <> 'R');*/
    --
  BEGIN
    x_retcode := 0;
    x_errbuf  := 'COMPLETE';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_otc_party_site_uses';
  
    FOR m IN cur_party_sites_uses
    LOOP
      INSERT INTO xxobjt.xxs3_otc_party_site_uses
        (xx_party_site_use_id
        ,
         --party_site_use_id,
         --party_site_id,
         site_use_type
        --,party_site_name --Commented as on 22/12
        ,status
        ,legacy_party_site_id
        ,legacy_party_site_use_id
        /*,attribute10  
        ,attribute2
        ,attribute12  */
        ,creation_date
        ,created_by
        --,attribute1   --Commented as on 22/12
        ,date_extracted_on
        ,process_flag)
      VALUES
        (xxobjt.xxs3_otc_party_site_uses_seq.NEXTVAL
        ,
         --null,
         --null,
         m.site_use_type
        --,m.party_site_name --Commented as on 22/12
        ,m.status
        ,m.party_site_id
        ,m.party_site_use_id
        /*,m.attribute10
        ,m.attribute2
        ,m.attribute12  */
        , m.creation_date
        ,m.created_by
        --,m.attribute1  
        , SYSDATE
        ,'N');
    END LOOP;
    COMMIT;
    --
    
    --Apply extract Rules
    
    BEGIN
     UPDATE xxs3_otc_party_site_uses xop
        SET xop.extract_rule_name = CASE WHEN extract_rule_name = NULL THEN 'EXT-012' ELSE extract_rule_name || '|' || 'EXT-012' END
      WHERE EXISTS (SELECT legacy_party_site_id
               FROM xxs3_otc_party_sites a
              WHERE a.legacy_party_site_id = xop.legacy_party_site_id
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
    
    SELECT COUNT(1)
    INTO l_count_party_sites_uses
    FROM xxobjt.xxs3_otc_party_site_uses;
  
    fnd_file.put_line(fnd_file.output
                     ,rpad('Party Site Use Extract Records Count Report'
                          ,100
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,rpad('============================================================'
                          ,200
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,rpad('Run date and time:    ' ||
                           to_char(SYSDATE
                                  ,'dd-Mon-YYYY HH24:MI')
                          ,100
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,rpad('============================================================'
                          ,200
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,'');
    fnd_file.put_line(fnd_file.output
                     ,rpad('Track Name'
                          ,10
                          ,' ') || chr(32) ||
                      rpad('Entity Name'
                          ,30
                          ,' ') || chr(32) ||
                      rpad('Total Count'
                          ,15
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,rpad('==========================================================='
                          ,200
                          ,' '));
  
    fnd_file.put_line(fnd_file.output
                     ,'');
  
    fnd_file.put_line(fnd_file.output
                     ,rpad('OTC'
                          ,10
                          ,' ') || ' ' || rpad('PARTY SITE USE'
                                              ,30
                                              ,' ') || ' ' ||
                      rpad(l_count_party_sites_uses
                          ,15
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,rpad('=========END OF REPORT==============='
                          ,200
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,'');
  
  EXCEPTION
    WHEN OTHERS THEN
      x_retcode        := 2;
      x_errbuf         := 'Unexpected error: ' || SQLERRM;
      l_status_message := SQLCODE || chr(10) || SQLERRM;
      fnd_file.put_line(fnd_file.log
                       ,'Unexpected error during data extraction : ' ||
                        chr(10) || l_status_message);
      fnd_file.put_line(fnd_file.log
                       ,'--------------------------------------');
  END party_site_uses_extract_data;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required Party relation fields and insert into
  --           staging table XXS3_OTC_PARTY_RELATIONSHIPS
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0 26/04/2016  Mishal Kumar                  Initial build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE party_relation_extract_data(x_errbuf  OUT VARCHAR2
                                       ,x_retcode OUT NUMBER) IS
  
    l_errbuf                    VARCHAR2(2000);
    l_retcode                   VARCHAR2(1);
    l_requestor                 NUMBER;
    l_program_short_name        VARCHAR2(100);
    l_status_message            VARCHAR2(4000);
    l_counter                   NUMBER;
    l_count_party_relationships NUMBER;
  
    CURSOR cur_party_relation_extract IS
      SELECT r.relationship_id
            ,r.subject_id
            ,r.subject_type
            ,r.object_id
            ,r.object_type
            ,r.relationship_code
            ,r.relationship_type
            ,r.start_date
            ,r.end_date --
      FROM hz_relationships r
      WHERE /*r.status = 'A'    --commented as on 22/12
      AND*/ /*r.subject_table_name = 'HZ_PARTIES'     --commented on 10/01/2017
      AND r.object_table_name = 'HZ_PARTIES'*/        --commented on 10/01/2017
      /*AND r.relationship_code NOT IN  --Commented as on 22/12
            ('CONTACT_OF', 'EMPLOYEE_OF', 'EMPLOYER_OF', 'CONTACT')
      AND r.relationship_type NOT IN ('BANK_AND_BRANCH')*/  --Commented as on 22/12
     /* AND*/ r.directional_flag = 'F';
      /*AND EXISTS (SELECT legacy_party_id
             FROM xxs3_otc_parties xop
             WHERE process_flag != 'R'
             AND xop.legacy_party_id = r.subject_id)
      AND EXISTS (SELECT legacy_party_id
             FROM xxs3_otc_parties xop
             WHERE process_flag != 'R'
             AND xop.legacy_party_id = r.object_id);*/
    --AND r.object_id = p_party_id;
  
  BEGIN
    x_retcode := 0;
    x_errbuf  := 'COMPLETE';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_otc_party_relationships';
  
    FOR n IN cur_party_relation_extract
    LOOP
      INSERT INTO xxobjt.xxs3_otc_party_relationships
        (xx_party_relationship_id
        ,
         --relationship_id,
         legacy_relationship_id
        ,subject_id
        ,subject_type
        ,object_id
        ,object_type
        ,relationship_code
        ,relationship_type
        ,start_date
        ,end_date
        ,date_extracted_on
        ,process_flag)
      VALUES
        (xxobjt.xxs3_otc_party_relation_seq.NEXTVAL
        ,
         --null,
         n.relationship_id
        ,n.subject_id
        ,n.subject_type
        ,n.object_id
        ,n.object_type
        ,n.relationship_code
        ,n.relationship_type
        ,n.start_date
        ,n.end_date
        ,SYSDATE
        ,'N');
    END LOOP;
  
    COMMIT;
    --
    --Apply extract Rules
    
    BEGIN
     UPDATE xxs3_otc_party_relationships xop
        SET xop.extract_rule_name = CASE WHEN extract_rule_name = NULL THEN 'EXT-017' ELSE extract_rule_name || '|' || 'EXT-017' END
      WHERE EXISTS (SELECT legacy_party_id
               FROM xxs3_otc_parties a
              WHERE a.legacy_party_id = xop.subject_id
                AND a.process_flag <> 'R'
                AND a.extract_rule_name IS NOT NULL
                AND nvl(a.transform_status,'PASS') <> 'FAIL')
      AND EXISTS (SELECT legacy_party_id
               FROM xxs3_otc_parties a
              WHERE a.legacy_party_id = xop.object_id
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
  
    SELECT COUNT(1)
    INTO l_count_party_relationships
    FROM xxobjt.xxs3_otc_party_relationships;
  
    fnd_file.put_line(fnd_file.output
                     ,rpad('Party Relation Ships Extract Records Count Report'
                          ,100
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,rpad('============================================================'
                          ,200
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,rpad('Run date and time:    ' ||
                           to_char(SYSDATE
                                  ,'dd-Mon-YYYY HH24:MI')
                          ,100
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,rpad('============================================================'
                          ,200
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,'');
    fnd_file.put_line(fnd_file.output
                     ,rpad('Track Name'
                          ,10
                          ,' ') || chr(32) ||
                      rpad('Entity Name'
                          ,30
                          ,' ') || chr(32) ||
                      rpad('Total Count'
                          ,15
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,rpad('==========================================================='
                          ,200
                          ,' '));
  
    fnd_file.put_line(fnd_file.output
                     ,'');
  
    fnd_file.put_line(fnd_file.output
                     ,rpad('OTC'
                          ,10
                          ,' ') || ' ' || rpad('PARTY RELATIONSHIPS'
                                              ,30
                                              ,' ') || ' ' ||
                      rpad(l_count_party_relationships
                          ,15
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,rpad('=========END OF REPORT==============='
                          ,200
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,'');
  
  EXCEPTION
    WHEN OTHERS THEN
      x_retcode        := 2;
      x_errbuf         := 'Unexpected error: ' || SQLERRM;
      l_status_message := SQLCODE || chr(10) || SQLERRM;
      fnd_file.put_line(fnd_file.log
                       ,'Unexpected error during data extraction : ' ||
                        chr(10) || l_status_message);
      fnd_file.put_line(fnd_file.log
                       ,'--------------------------------------');
  END party_relation_extract_data;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required Party Contact fields and insert into
  --           staging table XXS3_OTC_PARTY_CONTACTS
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0 17/08/2016  TCS                         Initial build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE party_contact_extract_data(x_errbuf  OUT VARCHAR2
                                      ,x_retcode OUT NUMBER) IS
  
    l_errbuf               VARCHAR2(2000);
    l_retcode              VARCHAR2(1);
    l_requestor            NUMBER;
    l_program_short_name   VARCHAR2(100);
    l_status_message       VARCHAR2(4000);
    l_counter              NUMBER;
    l_count_party_contacts NUMBER;
  
    CURSOR cur_party_contact_extract IS
      SELECT hp_cust.party_id org_party_id
            ,hp_cust.party_number org_party_number
            ,hp_cust.party_type org_party_type
            ,hp_contact.party_id contact_party_id
            ,hp_contact.party_number contact_party_number
            ,hoc.org_contact_id contact_id
            ,hoc.contact_number contact_number
            ,hp_contact.person_first_name
            ,hp_contact.person_middle_name
            ,hp_contact.person_last_name
            ,hp_contact.person_pre_name_adjunct
            ,hp_contact.known_as person_known_as
            ,hp_contact.party_type person_party_type
            ,hr.relationship_code
            ,hr.relationship_type
            ,hr.start_date
            ,hr.end_date
            ,hoc.attribute5
            ,hoc.attribute2
            ,hoc.attribute1
            ,hoc.attribute6
            ,hoc.attribute4
            ,hoc.party_site_id legacy_party_site_id
      FROM hz_relationships hr
          ,hz_parties       hp_contact
          ,hz_parties       hp_cust
          ,hz_org_contacts  hoc
      WHERE hp_cust.party_id = hr.object_id
      AND hr.subject_type = 'PERSON'
      AND hr.subject_id = hp_contact.party_id
      AND hoc.party_relationship_id = hr.relationship_id
      AND hp_contact.status = 'A'
      AND hp_cust.status = 'A'
      AND hr.relationship_code = 'CONTACT_OF'
      AND directional_flag = 'F'
      AND EXISTS (SELECT legacy_party_id
             FROM xxs3_otc_parties xop
             WHERE process_flag != 'R'
             AND xop.legacy_party_id = hp_cust.party_id);
  
    /* CURSOR cur_party_contact_extract IS
    SELECT hp_cust.party_id          org_party_id
          ,hp_cust.party_number      org_party_number
          ,hp_cust.party_type        org_party_type
          ,hca.cust_account_id       org_cust_account_id
          ,hp_contact.party_id       contact_party_id
          ,hp_contact.party_number   contact_party_number
          ,hcar.cust_account_role_id contact_id
          ,
           --hoc.org_contact_id contact_id,
           hoc.contact_number contact_number
          ,hp_contact.person_first_name
          ,hp_contact.person_middle_name
          ,hp_contact.person_last_name
          ,hp_contact.person_pre_name_adjunct
          ,hp_contact.known_as person_known_as
          ,hp_contact.party_type person_party_type
          ,hr.relationship_code
          ,hr.relationship_type
          ,hr.start_date
          ,hr.end_date
          ,hca.status
          ,
           --hca.cust_account_id,
           hoc.attribute5
          ,hoc.attribute2
          ,hoc.attribute1
          ,hoc.attribute6
          ,hoc.attribute4
          ,hcar.attribute1 sf_contact_id
    FROM hz_cust_accounts      hca
        ,hz_cust_account_roles hcar
        ,hz_relationships      hr
        ,hz_parties            hp_contact
        ,hz_parties            hp_cust
        ,hz_org_contacts       hoc
        ,hz_party_sites        hps
    WHERE hp_cust.party_id = hca.party_id
    AND hps.party_id(+) = hcar.party_id
    AND nvl(hps.identifying_address_flag, 'Y') = 'Y'
    AND hca.cust_account_id = hcar.cust_account_id
    AND hcar.role_type = 'CONTACT'
    AND hcar.cust_acct_site_id IS NULL
    AND hcar.party_id = hr.party_id
    AND hr.subject_type = 'PERSON'
    AND hr.subject_id = hp_contact.party_id
    AND hoc.party_relationship_id = hr.relationship_id
    AND hca.status = 'A'
    AND hcar.status = 'A'
    AND hp_contact.status = 'A'
    AND hp_cust.status = 'A'
    AND nvl(hps.status, 'A') = 'A'
    AND hr.relationship_code = 'CONTACT_OF'
         --AND hp_cust.party_id = p_party_id;
    AND EXISTS (SELECT legacy_party_id
           FROM xxs3_otc_parties xop
           WHERE process_flag != 'R'
           AND xop.legacy_party_id = hp_cust.party_id);*/
  
  BEGIN
    x_retcode := 0;
    x_errbuf  := 'COMPLETE';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_otc_party_contacts';
  
    FOR n IN cur_party_contact_extract
    LOOP
    
      INSERT INTO xxobjt.xxs3_otc_party_contacts
      VALUES
        (xxs3_otc_party_contacts_seq.NEXTVAL
        ,SYSDATE
        ,'N'
        ,NULL
        ,NULL
        ,n.org_party_id
        ,n.org_party_number
        ,n.org_party_type
        ,n.contact_party_id
        ,n.contact_party_number
        ,n.contact_number
        ,n.contact_id
        ,n.person_first_name
        ,n.person_middle_name
        ,n.person_last_name
        ,n.person_pre_name_adjunct
        ,n.person_known_as
        ,n.person_party_type
        ,n.relationship_code
        ,n.relationship_type
        ,n.start_date
        ,n.end_date
        ,n.attribute5
        ,n.attribute2
        ,n.attribute1
        ,n.attribute6
        ,n.attribute4
        ,n.legacy_party_site_id
        ,NULL
        ,NULL
        ,NULL
        ,NULL
        ,NULL
        ,NULL);
    
    END LOOP;
  
    COMMIT;
    --
  
    SELECT COUNT(1)
    INTO l_count_party_contacts
    FROM xxobjt.xxs3_otc_party_contacts;
  
  
    fnd_file.put_line(fnd_file.output
                     ,rpad('Party Contacts Extract Records Count Report'
                          ,100
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,rpad('============================================================'
                          ,200
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,rpad('Run date and time:    ' ||
                           to_char(SYSDATE
                                  ,'dd-Mon-YYYY HH24:MI')
                          ,100
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,rpad('============================================================'
                          ,200
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,'');
    fnd_file.put_line(fnd_file.output
                     ,rpad('Track Name'
                          ,10
                          ,' ') || chr(32) ||
                      rpad('Entity Name'
                          ,30
                          ,' ') || chr(32) ||
                      rpad('Total Count'
                          ,15
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,rpad('==========================================================='
                          ,200
                          ,' '));
  
    fnd_file.put_line(fnd_file.output
                     ,'');
  
    fnd_file.put_line(fnd_file.output
                     ,rpad('OTC'
                          ,10
                          ,' ') || ' ' || rpad('PARTY CONTACT'
                                              ,30
                                              ,' ') || ' ' ||
                      rpad(l_count_party_contacts
                          ,15
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,rpad('=========END OF REPORT==============='
                          ,200
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,'');
  
  EXCEPTION
    WHEN OTHERS THEN
      x_retcode        := 2;
      x_errbuf         := 'Unexpected error: ' || SQLERRM;
      l_status_message := SQLCODE || chr(10) || SQLERRM;
      fnd_file.put_line(fnd_file.log
                       ,'Unexpected error during data extraction : ' ||
                        chr(10) || l_status_message);
      fnd_file.put_line(fnd_file.log
                       ,'--------------------------------------');
  END party_contact_extract_data;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required Party Role fields and insert into
  --           staging table XXS3_OTC_PARTY_ROLE
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0 26/04/2016  Mishal Kumar                  Initial build
  -- --------------------------------------------------------------------------------------------
  /*PROCEDURE party_role_extract_data(x_errbuf  OUT VARCHAR2,
                                  x_retcode OUT NUMBER) IS
                                  
       l_errbuf             VARCHAR2(2000);
       l_retcode            VARCHAR2(1);
       l_requestor          NUMBER;
       l_program_short_name VARCHAR2(100);
       l_status_message     VARCHAR2(4000);
       l_counter            NUMBER;
       --
       
     CURSOR cur_valid_parties IS 
     SELECT p.party_id
         FROM hz_parties p
        WHERE p.status = 'A'
          AND EXISTS
        (SELECT party_id
                 FROM hz_cust_accounts hca
                WHERE status = 'A'
                  AND hca.party_id = p.party_id)
          AND p.created_by_module NOT IN
              ('HR API', 'API_SUPPLIERS', 'POS_SUPPLIER_MGMT', 'CE')
          AND p.created_by_module IN
              ('ONT_UI_ADD_CUSTOMER', 'TCA_V1_API', 'CSCCCCRC', 'SALESFORCE',
               'HZ_CPUI', 'HZ_TCA_CUSTOMER_MERGE');
                
                 
   CURSOR cur_party_contact_extract(p_party_id IN NUMBER) IS
   SELECT hoc.org_contact_id
     FROM hz_cust_accounts hca,
          --hz_cust_account_roles hcar,
          hz_relationships hr,
          hz_parties       hp_contact,
          hz_parties       hp_cust,
          hz_org_contacts  hoc
    WHERE hp_cust.party_id = hca.party_id
      AND hr.subject_type = 'PERSON'
      AND hr.subject_id = hp_contact.party_id
      AND hoc.party_relationship_id = hr.relationship_id
      AND hr.relationship_code = 'CONTACT_OF'
      AND hr.object_id = hp_cust.party_id
      AND hca.status = 'A'
      AND hp_contact.status = 'A'
      AND hp_cust.status = 'A'
      AND hp_cust.party_id = p_party_id;
      
       CURSOR cur_party_role_extract(p_org_contact_id IN NUMBER) IS
       SELECT org_contact_role_id,
              org_contact_id,
              role_type,
              role_level,
              primary_flag,
              orig_system_reference,
              primary_contact_per_role_type,
              status,
              object_version_number,
              created_by_module,
              application_id
         FROM hz_org_contact_roles
        WHERE status = 'A'
          AND org_contact_id = p_org_contact_id;
       BEGIN
       x_retcode := 0;
       x_errbuf  := 'COMPLETE';
       
       EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_otc_party_role';
        --
        
     FOR rec_p IN cur_valid_parties LOOP
       FOR i IN cur_party_contact_extract(rec_p.party_id) LOOP   
        FOR N IN cur_party_role_extract(i.org_contact_id) LOOP
         INSERT INTO xxobjt.xxs3_otc_party_role
           (xx_party_role_id,
            org_contact_role_id,
            legacy_org_contact_role_id,
            legacy_org_contact_id,
            role_type,
            role_level,
            orig_system_reference,
            primary_contact_per_role_type,
            status,
            object_version_number,
            created_by_module,
            application_id,
            date_extracted_on)
         VALUES
           (xxobjt.xxs3_otc_party_role_seq.NEXTVAL,
            NULL,
            n.org_contact_role_id,
            n.org_contact_id,
            n.role_type,
            n.role_level,
            n.orig_system_reference,
            n.primary_contact_per_role_type,
            n.status,
            n.object_version_number,
            n.created_by_module,
            n.application_id,
            SYSDATE);
       END LOOP;
      END LOOP;
     END LOOP;
       COMMIT;
       --
   EXCEPTION
       WHEN OTHERS THEN
             x_retcode        := 2;
             x_errbuf         := 'Unexpected error: ' || SQLERRM;
             l_status_message := SQLCODE || chr(10) || SQLERRM;
             fnd_file.put_line(fnd_file.log, 'Unexpected error during data extraction : ' ||
                                chr(10) || l_status_message);
             fnd_file.put_line(fnd_file.log, '--------------------------------------');
  END party_role_extract_data;*/
  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required Contact point fields and insert into
  --           staging table XXS3_OTC_PARTY_CONTACT_POINTS
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0 26/04/2016  Mishal Kumar                  Initial build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE party_contact_pts_extract_data(x_errbuf  OUT VARCHAR2
                                          ,x_retcode OUT NUMBER) IS
  
    l_errbuf                   VARCHAR2(2000);
    l_retcode                  VARCHAR2(1);
    l_requestor                NUMBER;
    l_program_short_name       VARCHAR2(100);
    l_status_message           VARCHAR2(4000);
    l_counter                  NUMBER;
    l_count_party_contacts_pts NUMBER;
  
    CURSOR cur_party_contact_pts_extract IS
      SELECT DISTINCT c.contact_point_id      legacy_contact_point_id
                     ,c.contact_point_type    contact_point_type
                     ,c.status                status
                     ,pa.party_id             party_id
                     ,c.primary_flag          primary_flag
                     ,c.contact_point_purpose contact_point_purpose
                     ,c.owner_table_name      owner_table_name
                     ,c.owner_table_id        owner_table_id
                     ,c.orig_system_reference orig_system_reference
                     ,c.created_by_module     created_by_module
                     ,c.timezone_id           timezone_id
                     ,c.phone_area_code       phone_area_code
                     ,c.phone_country_code    phone_country_code
                     ,c.phone_number          phone_number
                     ,c.phone_line_type       phone_line_type
                     ,c.email_address         email_address
                     ,c.email_format          email_format
                     ,c.web_type              web_type
                     ,c.url                   url
                     ,c.telex_number          telex_number
      FROM hz_contact_points     c
          ,hz_parties            pa
          ,hz_cust_accounts      hca
          ,hz_relationships      hr
          ,hz_cust_account_roles hcar
          ,hz_org_contacts       hoc --new table post CRP2
      WHERE c.owner_table_name = 'HZ_PARTIES'
      AND c.owner_table_id = hr.party_id
      AND hr.subject_type = 'ORGANIZATION'
      AND hr.subject_id = hca.party_id
      AND hca.party_id = pa.party_id
      AND hcar.role_type = 'CONTACT'
      AND hcar.party_id = hr.party_id
      AND hcar.cust_acct_site_id IS NULL
      AND c.status = 'A'
      AND pa.status = 'A'
      AND hca.status = 'A'
      AND hr.status = 'A'
      AND hcar.status = 'A'
      AND c.created_by_module NOT IN ('SR', 'HR API')
      AND hoc.party_relationship_id = hr.relationship_id --new join post CRP2
      AND EXISTS (SELECT contact_id
             FROM xxobjt.xxs3_otc_party_contacts xopc
             WHERE process_flag <> 'R'
             AND xopc.contact_id = hoc.org_contact_id /*hcar.cust_account_role_id*/
             );
  BEGIN
    x_retcode := 0;
    x_errbuf  := 'COMPLETE';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_otc_party_contact_points';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_otc_party_cont_points_dq';
  
    FOR o IN cur_party_contact_pts_extract
    LOOP
    
      INSERT INTO xxs3_otc_party_contact_points
        (xx_party_contact_point_id
        ,legacy_contact_point_id
        ,contact_point_type
        ,status
        ,legacy_party_id
        ,primary_flag
        ,contact_point_purpose
        ,owner_table_name
        ,owner_table_id
        ,orig_system_reference
        ,created_by_module
        ,timezone_id
        ,phone_area_code
        ,phone_country_code
        ,phone_number
        ,phone_line_type
        ,email_address
        ,email_format
        ,s3_email_format
        ,web_type
        ,s3_web_type
        ,url
        ,telex_number
        ,date_extracted_on
        ,process_flag)
      VALUES
        (xxobjt.xxs3_otc_party_cont_points_seq.NEXTVAL
        ,o.legacy_contact_point_id
        ,o.contact_point_type
        ,o.status
        ,o.party_id
        ,o.primary_flag
        ,o.contact_point_purpose
        ,o.owner_table_name
        ,o.owner_table_id
        ,o.orig_system_reference
        ,o.created_by_module
        ,o.timezone_id
        ,o.phone_area_code
        ,o.phone_country_code
        ,o.phone_number
        ,o.phone_line_type
        ,o.email_address
        ,o.email_format
        ,o.email_format
        ,o.web_type
        ,o.web_type
        ,o.url
        ,o.telex_number
        ,SYSDATE
        ,'N');
    END LOOP;
    COMMIT;
  
    --Autocleanse
  
    FOR t IN (SELECT xx_party_contact_point_id
                    ,contact_point_type
                    ,email_address
                    ,email_format
                    ,web_type
                    ,url
              FROM xxs3_otc_party_contact_points)
    LOOP
    
      IF (t.email_format IS NULL AND t.email_address IS NOT NULL)
      THEN
        cleanse_cont_pts_email(t.xx_party_contact_point_id
                              ,t.email_address);
      END IF;
    
      IF (t.contact_point_type = 'WEB')
      THEN
        IF t.web_type != upper(substr(t.url
                                     ,1
                                     ,4))
        THEN
          cleanse_cont_pts_web(t.xx_party_contact_point_id
                              ,t.url);
        END IF;
      END IF;
    
    END LOOP;
    COMMIT;
  
    --DQ validation
    BEGIN
      quality_check_contact_points;
      COMMIT;
    
    EXCEPTION
      WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log
                         ,'Unexpected error during DQ validation : ' ||
                          chr(10) || SQLCODE || chr(10) || SQLERRM);
    END;
  
    SELECT COUNT(1)
    INTO l_count_party_contacts_pts
    FROM xxobjt. xxs3_otc_party_contact_points;
  
  
    fnd_file.put_line(fnd_file.output
                     ,rpad('Party Contact Points Extract Records Count Report'
                          ,100
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,rpad('============================================================'
                          ,200
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,rpad('Run date and time:    ' ||
                           to_char(SYSDATE
                                  ,'dd-Mon-YYYY HH24:MI')
                          ,100
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,rpad('============================================================'
                          ,200
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,'');
    fnd_file.put_line(fnd_file.output
                     ,rpad('Track Name'
                          ,10
                          ,' ') || chr(32) ||
                      rpad('Entity Name'
                          ,30
                          ,' ') || chr(32) ||
                      rpad('Total Count'
                          ,15
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,rpad('==========================================================='
                          ,200
                          ,' '));
  
    fnd_file.put_line(fnd_file.output
                     ,'');
  
    fnd_file.put_line(fnd_file.output
                     ,rpad('OTC'
                          ,10
                          ,' ') || ' ' || rpad('PARTY CONTACT POINTS'
                                              ,30
                                              ,' ') || ' ' ||
                      rpad(l_count_party_contacts_pts
                          ,15
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,rpad('=========END OF REPORT==============='
                          ,200
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,'');
  
  
  
  EXCEPTION
    WHEN OTHERS THEN
      x_retcode        := 2;
      x_errbuf         := 'Unexpected error: ' || SQLERRM;
      l_status_message := SQLCODE || chr(10) || SQLERRM;
      fnd_file.put_line(fnd_file.log
                       ,'Unexpected error during data extraction : ' ||
                        chr(10) || l_status_message);
      fnd_file.put_line(fnd_file.log
                       ,'--------------------------------------');
    
  END party_contact_pts_extract_data;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will generate DQ Report for parties
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0 26/04/2016  Mishal Kumar                  Initial build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE dq_party_report_data_reject(p_entity IN VARCHAR2) IS
  
    l_delimiter    VARCHAR2(5) := '~';
    l_count_dq     NUMBER(15);
    l_count_reject NUMBER;
  
    CURSOR c_report IS
      SELECT xpd.xx_party_id
            ,xp.legacy_party_id
            ,xp.party_name
            ,xp.legacy_party_number
            ,xpd.rule_name
            ,xpd.notes
            ,xpd.dq_status
            ,xp.extract_dq_error
            ,decode(xp.process_flag
                   ,'R'
                   ,'Y'
                   ,'Q'
                   ,'N') reject_record
      FROM xxs3_otc_parties_dq xpd
          ,xxs3_otc_parties    xp
      WHERE xpd.xx_party_id = xp.xx_party_id
      AND xp.process_flag IN ('Q', 'R');
    --WHERE  process_flag = 'Q'
  
  BEGIN
    SELECT COUNT(1)
    INTO l_count_dq
    FROM xxs3_otc_parties
    WHERE process_flag IN ('Q', 'R');
  
    SELECT COUNT(1)
    INTO l_count_reject
    FROM xxs3_otc_parties
    WHERE process_flag = 'R';
  
    fnd_file.put_line(fnd_file.output
                     ,rpad('Report name = Data Quality Error Report' ||
                           l_delimiter
                          ,100
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,rpad('========================================' ||
                           l_delimiter
                          ,100
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,rpad('Data Migration Object Name = Party' ||
                           l_delimiter
                          ,100
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,'');
    fnd_file.put_line(fnd_file.output
                     ,rpad('Run date and time:    ' ||
                           to_char(SYSDATE
                                  ,'dd-Mon-YYYY HH24:MI') || l_delimiter
                          ,100
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,rpad('Total Record Count Having DQ Issues = ' ||
                           l_count_dq || l_delimiter
                          ,100
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,rpad('Total Record Count Rejected =  ' ||
                           l_count_reject || l_delimiter
                          ,100
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,'');
    fnd_file.put_line(fnd_file.output
                     ,rpad('Locations DQ status report'
                          ,100
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,rpad('============================='
                          ,100
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,'');
    fnd_file.put_line(fnd_file.output
                     ,'Date:    ' ||
                      to_char(SYSDATE
                             ,'dd-Mon-YYYY HH24:MI'));
  
    fnd_file.put_line(fnd_file.output
                     ,'');
  
  
  
    fnd_file.put_line(fnd_file.output
                     ,rpad('Track Name'
                          ,10
                          ,' ') || l_delimiter ||
                      rpad('Entity Name'
                          ,11
                          ,' ') || l_delimiter ||
                      rpad('XX_Party_ID  '
                          ,14
                          ,' ') || l_delimiter ||
                      rpad('Legacy_Party_ID'
                          ,20
                          ,' ') || l_delimiter ||
                      rpad('Legacy_Party_Name'
                          ,240
                          ,' ') || l_delimiter ||
                      rpad('Legacy_Party_Number'
                          ,80
                          ,' ') || l_delimiter ||
                      rpad('DQ_Status'
                            ,80
                            ,' ') || l_delimiter ||
                        rpad('Extract_DQ_Error'
                            ,80
                            ,' ') || l_delimiter ||
                      rpad('Reject Record Flag(Y/N)'
                          ,22
                          ,' ') || l_delimiter ||
                      rpad('Rule Name'
                          ,45
                          ,' ') || l_delimiter ||
                      rpad('Reason Code'
                          ,50
                          ,' '));
  
  
    FOR r_data IN c_report
    LOOP
    
      fnd_file.put_line(fnd_file.output
                       ,rpad('OTC'
                            ,10
                            ,' ') || l_delimiter ||
                        rpad('PARTY'
                            ,11
                            ,' ') || l_delimiter ||
                        rpad(r_data.xx_party_id
                            ,14
                            ,' ') || l_delimiter ||
                        rpad(r_data.legacy_party_id
                            ,20
                            ,' ') || l_delimiter ||
                        rpad(r_data.party_name
                            ,240
                            ,' ') || l_delimiter ||
                        rpad(r_data.legacy_party_number
                            ,80
                            ,' ') || l_delimiter ||
                        rpad(r_data.DQ_Status
                            ,80
                            ,' ') || l_delimiter ||
                        rpad(r_data.Extract_DQ_Error
                            ,80
                            ,' ') || l_delimiter ||
                        rpad(r_data.reject_record
                            ,22
                            ,' ') || l_delimiter ||
                        rpad(nvl(r_data.rule_name
                                ,'NULL')
                            ,45
                            ,' ') || l_delimiter ||
                        rpad(nvl(r_data.notes
                                ,'NULL')
                            ,50
                            ,' '));
    END LOOP;
    fnd_file.put_line(fnd_file.output
                     ,'!!END OF REPORT!!');
  EXCEPTION
    WHEN no_data_found THEN
      fnd_file.put_line(fnd_file.log
                       ,'No data found error' || SQLCODE || chr(10) ||
                        SQLERRM);
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log
                       ,'Unexpected error' || chr(10) || SQLCODE ||
                        chr(10) || SQLERRM);
    
  END dq_party_report_data_reject;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will generate DQ Report for party contact points
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0 26/04/2016  Mishal Kumar                  Initial build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE dq_party_cont_report_data(p_entity IN VARCHAR2) IS
  
    l_delimiter    VARCHAR2(5) := '~';
    l_count_dq     NUMBER(15);
    l_count_reject NUMBER;
  
    CURSOR c_report IS
      SELECT xpcd.xx_party_contact_point_id
            ,xpc.legacy_contact_point_id
            ,(SELECT party_name
              FROM hz_parties
              WHERE party_id = xpc.legacy_party_id) party_name
            ,xpcd.rule_name
            ,xpcd.notes
            ,decode(xpc.process_flag
                   ,'R'
                   ,'Y'
                   ,'Q'
                   ,'N') reject_record
      FROM xxs3_otc_party_cont_points_dq xpcd
          ,xxs3_otc_party_contact_points xpc
      WHERE xpcd.xx_party_contact_point_id = xpc.xx_party_contact_point_id
      AND xpc.process_flag IN ('Q', 'R'); --WHERE  process_flag = 'Q'
  
  BEGIN
    SELECT COUNT(1)
    INTO l_count_dq
    FROM xxs3_otc_party_contact_points
    WHERE process_flag IN ('Q', 'R');
  
    SELECT COUNT(1)
    INTO l_count_reject
    FROM xxs3_otc_party_contact_points
    WHERE process_flag = 'R';
  
    fnd_file.put_line(fnd_file.output
                     ,rpad('Report name = Data Quality Error Report' ||
                           l_delimiter
                          ,100
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,rpad('========================================' ||
                           l_delimiter
                          ,100
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,rpad('Data Migration Object Name = Party Contact Points' ||
                           l_delimiter
                          ,100
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,'');
    fnd_file.put_line(fnd_file.output
                     ,rpad('Run date and time:    ' ||
                           to_char(SYSDATE
                                  ,'dd-Mon-YYYY HH24:MI') || l_delimiter
                          ,100
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,rpad('Total Record Count Having DQ Issues = ' ||
                           l_count_dq || l_delimiter
                          ,100
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,rpad('Total Record Count Rejected =  ' ||
                           l_count_reject || l_delimiter
                          ,100
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,'');
    fnd_file.put_line(fnd_file.output
                     ,rpad('Locations DQ status report'
                          ,100
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,rpad('============================='
                          ,100
                          ,' '));
    fnd_file.put_line(fnd_file.output
                     ,'');
    fnd_file.put_line(fnd_file.output
                     ,'Date:    ' ||
                      to_char(SYSDATE
                             ,'dd-Mon-YYYY HH24:MI'));
  
    fnd_file.put_line(fnd_file.output
                     ,'');
  
  
    fnd_file.put_line(fnd_file.output
                     ,rpad('Track Name'
                          ,10
                          ,' ') || l_delimiter ||
                      rpad('Entity Name'
                          ,20
                          ,' ') || l_delimiter ||
                      rpad('XX_Party_Contact_Point_Id  '
                          ,14
                          ,' ') || l_delimiter ||
                      rpad('Legacy_Contact_Point_Id'
                          ,10
                          ,' ') || l_delimiter ||
                      rpad('Legacy_Party_Name'
                          ,240
                          ,' ') || l_delimiter ||
                      rpad('Reject Record Flag(Y/N)'
                          ,22
                          ,' ') || l_delimiter ||
                      rpad('Rule Name'
                          ,45
                          ,' ') || l_delimiter ||
                      rpad('Reason Code'
                          ,50
                          ,' '));
  
  
    FOR r_data IN c_report
    LOOP
    
      fnd_file.put_line(fnd_file.output
                       ,rpad('OTC'
                            ,10
                            ,' ') || l_delimiter ||
                        rpad('PARTY_CONTACT_POINT'
                            ,20
                            ,' ') || l_delimiter ||
                        rpad(r_data.xx_party_contact_point_id
                            ,14
                            ,' ') || l_delimiter ||
                        rpad(r_data.legacy_contact_point_id
                            ,10
                            ,' ') || l_delimiter ||
                        rpad(r_data.party_name
                            ,240
                            ,' ') || l_delimiter ||
                        rpad(r_data.reject_record
                            ,22
                            ,' ') || l_delimiter ||
                        rpad(nvl(r_data.rule_name
                                ,'NULL')
                            ,45
                            ,' ') || l_delimiter ||
                        rpad(nvl(r_data.notes
                                ,'NULL')
                            ,50
                            ,' '));
    
    
    END LOOP;
    fnd_file.put_line(fnd_file.output
                     ,'Stratasys Confidential' || l_delimiter);
  EXCEPTION
    WHEN no_data_found THEN
      fnd_file.put_line(fnd_file.log
                       ,'No data found error' || SQLCODE || chr(10) ||
                        SQLERRM);
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log
                       ,'Unexpected error' || chr(10) || SQLCODE ||
                        chr(10) || SQLERRM);
    
  END dq_party_cont_report_data;
   --------------------------------------------------------------------
  --  name:              data_transform_report
  --  create by:       Debarati banerjee
  --  Revision:          1.0
  --  creation date:     06/01/2016
  --------------------------------------------------------------------
  --  purpose :          write data transform report to output
  --
  --------------------------------------------------------------------
  --  ver  date          name                   desc
  --  1.0  06/01/2016   Debarati banerjee       report data transform
  --------------------------------------------------------------------

  PROCEDURE data_transform_report(p_entity IN VARCHAR2) IS
  
    l_delimiter     VARCHAR2(5) := '~';
    l_err_msg       VARCHAR2(2000);
    l_count_success NUMBER;
    l_count_fail    NUMBER;
    
    CURSOR c_report_party IS
      SELECT xcs.legacy_party_id 
            ,xcs.party_name
            ,xcs.legacy_party_number
            ,xcs.customer_support_ou 
            ,xcs.s3_customer_support_ou 
            ,xcs.transform_status
            ,xcs.transform_error
      FROM xxobjt.xxs3_otc_parties xcs
      WHERE xcs.transform_status IN ('PASS', 'FAIL');
  
  BEGIN
  
    IF p_entity = 'PARTY' THEN
    
      SELECT COUNT(1)
      INTO l_count_success
      FROM xxobjt.xxs3_otc_parties xci
      WHERE xci.transform_status = 'PASS';
    
      SELECT COUNT(1)
      INTO l_count_fail
      FROM xxobjt.xxs3_otc_parties xci
      WHERE xci.transform_status = 'FAIL';
    
    
      fnd_file.put_line(fnd_file.output, rpad('Report name = Data Transformation Report' ||
                              l_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('========================================' ||
                              l_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Data Migration Object Name = ' ||
                              p_entity || l_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, '');
      fnd_file.put_line(fnd_file.output, rpad('Run date and time:    ' ||
                              to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') ||
                              l_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Total Record Count Success = ' ||
                              l_count_success ||
                              l_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Total Record Count Failure = ' ||
                              l_count_fail || l_delimiter, 100, ' '));
    
      fnd_file.put_line(fnd_file.output, '');
      
       fnd_file.put_line(fnd_file.output, rpad('Track Name', 10, ' ') ||
                         l_delimiter ||
                         rpad('Entity Name', 15, ' ') ||
                         l_delimiter ||
                         rpad('LEGACY_PARTY_ID  ', 30, ' ') ||
                         l_delimiter ||
                         rpad('LEGACY_PARTY_NUMBER', 30, ' ') ||
                         l_delimiter ||
                         rpad('LEGACY_PARTY_NAME', 250, ' ') ||
                         l_delimiter ||
                         rpad('CUSTOMER SUPPORT OU', 250, ' ') ||
                         l_delimiter ||
                         rpad('S3 CUSTOMER SUPPORT OU', 250, ' ') ||
                         l_delimiter ||
                         rpad('Status', 10, ' ') ||
                         l_delimiter ||
                         rpad('Error Message', 200, ' '));
                         
    FOR r_data IN c_report_party
      LOOP
        fnd_file.put_line(fnd_file.output, rpad('OTC', 10, ' ') ||
                           l_delimiter ||
                           rpad('PARTY', 15, ' ') ||
                           l_delimiter ||
                           rpad(r_data.legacy_party_id, 30, ' ') ||
                           l_delimiter ||
                           rpad(r_data.legacy_party_number, 30, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.party_name, 'NULL'), 30, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.customer_support_ou, 'NULL'), 30, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_customer_support_ou, 'NULL'), 50, ' ') ||                           
                           l_delimiter ||
                           rpad(r_data.transform_status, 10, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.transform_error, 'NULL'), 200, ' '));
                           
     END LOOP;                    
   END IF;
   
   END;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will generate Data Cleanse report for parties
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0 26/04/2016  Mishal Kumar                  Initial build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE data_cleanse_report(p_entity IN VARCHAR2) IS
  
    l_delimiter     VARCHAR2(5) := '~';
    l_err_msg       VARCHAR2(2000);
    l_count_success NUMBER;
    l_count_fail    NUMBER;
  
    CURSOR c_report_parties IS
      SELECT xx_party_id
            ,legacy_party_id
            ,party_name legacy_party_name
            ,s3_party_name
            ,legacy_party_number
            ,cleanse_status
            ,cleanse_error
      FROM xxs3_otc_parties
      WHERE cleanse_status IN ('PASS', 'FAIL');
    --
  
  BEGIN
    IF p_entity = 'PARTY'
    THEN
    
      SELECT COUNT(1)
      INTO l_count_success
      FROM xxs3_otc_parties
      WHERE cleanse_status = 'PASS';
    
      SELECT COUNT(1)
      INTO l_count_fail
      FROM xxs3_otc_parties
      WHERE cleanse_status = 'FAIL';
      fnd_file.put_line(fnd_file.output
                       ,'Report name = Automated Cleanse & Standardize Report');
      fnd_file.put_line(fnd_file.output
                       ,'====================================================');
      fnd_file.put_line(fnd_file.output
                       ,'Data Migration Object Name = ' || p_entity);
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
      --
      fnd_file.put_line(fnd_file.output
                       ,'TRACK NAME' || l_delimiter || 'ENTITY NAME' ||
                        l_delimiter || 'XX PARTY ID  ' || l_delimiter ||
                        'LEGACY PARTY ID' || l_delimiter ||
                        'LEGACY PARTY NAME' || l_delimiter ||
                        'S3 PARTY NAME' || l_delimiter || 'PARTY NUMBER' ||
                        l_delimiter || 'STATUS' || l_delimiter ||
                        'ERROR MESSAGE');
      FOR r_data IN c_report_parties
      LOOP
        fnd_file.put_line(fnd_file.output
                         ,'OTC' || l_delimiter || 'PARTIES' || l_delimiter ||
                          r_data.xx_party_id || l_delimiter ||
                          r_data.legacy_party_id || l_delimiter ||
                          r_data.legacy_party_name || l_delimiter ||
                          r_data.s3_party_name || l_delimiter ||
                          r_data.legacy_party_number || l_delimiter ||
                          r_data.cleanse_status || l_delimiter ||
                          nvl(r_data.cleanse_error
                             ,'NULL'));
      END LOOP;
      fnd_file.put_line(fnd_file.output
                       ,'');
      fnd_file.put_line(fnd_file.output
                       ,'Stratasys Confidential' || l_delimiter);
    END IF;
  EXCEPTION
    WHEN no_data_found THEN
      fnd_file.put_line(fnd_file.log
                       ,'No data found error' || SQLCODE || chr(10) ||
                        SQLERRM);
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log
                       ,'Unexpected error' || chr(10) || SQLCODE ||
                        chr(10) || SQLERRM);
  END data_cleanse_report;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will generate auto cleanse Report for party contact points
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0 26/04/2016  Mishal Kumar                  Initial build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE data_cleanse_cont_report(p_entity IN VARCHAR2) IS
  
    l_delimiter     VARCHAR2(5) := '~';
    l_err_msg       VARCHAR2(2000);
    l_count_success NUMBER;
    l_count_fail    NUMBER;
  
    CURSOR c_report_parties IS
      SELECT xx_party_contact_point_id
            ,legacy_contact_point_id
            ,(SELECT party_name
              FROM hz_parties
              WHERE party_id = xpc.legacy_party_id) party_name
            ,email_format legacy_email_format
            ,s3_email_format
            ,web_type legacy_web_type
            ,s3_web_type
            ,contact_point_type
            ,cleanse_status
            ,cleanse_error
      FROM xxs3_otc_party_contact_points xpc
      WHERE cleanse_status IN ('PASS', 'FAIL');
    --
  
  BEGIN
    SELECT COUNT(1)
    INTO l_count_success
    FROM xxs3_otc_party_contact_points
    WHERE cleanse_status = 'PASS';
  
    SELECT COUNT(1)
    INTO l_count_fail
    FROM xxs3_otc_party_contact_points
    WHERE cleanse_status = 'FAIL';
    fnd_file.put_line(fnd_file.output
                     ,'Report name = Automated Cleanse & Standardize Report');
    fnd_file.put_line(fnd_file.output
                     ,'====================================================');
    fnd_file.put_line(fnd_file.output
                     ,'Data Migration Object Name = ' || p_entity);
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
    --
    fnd_file.put_line(fnd_file.output
                     ,'TRACK NAME' || l_delimiter || 'ENTITY NAME' ||
                      l_delimiter || 'XX_PARTY_CONTACT_POINT_ID' ||
                      l_delimiter || 'LEGACY_CONTACT_POINT_ID' ||
                      l_delimiter || 'LEGACY_PARTY_NAME' || l_delimiter ||
                      'LEGACY_EMAIL_FORMAT' || l_delimiter ||
                      'S3_EMAIL_FORMAT' || l_delimiter ||
                      'LEGACY_WEB_TYPE' || l_delimiter || 'S3_WEB_TYPE' ||
                      l_delimiter || 'CONTACT_POINT_TYPE' || l_delimiter ||
                      'STATUS' || l_delimiter || 'ERROR MESSAGE');
    FOR r_data IN c_report_parties
    LOOP
      fnd_file.put_line(fnd_file.output
                       ,'OTC' || l_delimiter || 'PARTY CONTACT POINTS' ||
                        l_delimiter || r_data.xx_party_contact_point_id ||
                        l_delimiter || r_data.legacy_contact_point_id ||
                        l_delimiter || r_data.party_name || l_delimiter ||
                        r_data.legacy_email_format || l_delimiter ||
                        r_data.s3_email_format || l_delimiter ||
                        r_data.legacy_web_type || l_delimiter ||
                        r_data.s3_web_type || l_delimiter ||
                        r_data.contact_point_type || l_delimiter ||
                        r_data.cleanse_status || l_delimiter ||
                        nvl(r_data.cleanse_error
                           ,'NULL'));
    END LOOP;
    fnd_file.put_line(fnd_file.output
                     ,'');
    fnd_file.put_line(fnd_file.output
                     ,'Stratasys Confidential' || l_delimiter);
  EXCEPTION
    WHEN no_data_found THEN
      fnd_file.put_line(fnd_file.log
                       ,'No data found error' || SQLCODE || chr(10) ||
                        SQLERRM);
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log
                       ,'Unexpected error' || chr(10) || SQLCODE ||
                        chr(10) || SQLERRM);
  END data_cleanse_cont_report;
END xxs3_otc_party_pkg;
/
