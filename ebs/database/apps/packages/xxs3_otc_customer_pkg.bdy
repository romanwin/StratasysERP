CREATE OR REPLACE PACKAGE BODY xxs3_otc_customer_pkg AS


  ----------------------------------------------------------------------------
  --  name:            XXS3_OTC_CUSTOMER_PKG
  --  create by:       Mishal Kumar
  --  Revision:        1.0
  --  creation date:   11/05/2016
  ----------------------------------------------------------------------------
  --  purpose :        Package to extract the Customer fields
  --                   from Legacy system
  ----------------------------------------------------------------------------
  --  ver  date        name                         desc
  --  1.0  11/05/2016  Mishal Kumar                 Initial build
  ----------------------------------------------------------------------------
  g_org_id NUMBER := 737;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Insert in to DQ table for validation of errors and update the master table
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  11/05/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  PROCEDURE insert_update_dq(p_xx_cust_account_id     IN NUMBER
                            ,p_rule_name              IN VARCHAR2
                            ,p_reject_code            IN VARCHAR2
                            ,p_legacy_cust_account_id NUMBER) IS
    l_step VARCHAR2(100);                        
  BEGIN
   
    /* Update process Flag for DQ validation Records */
  l_step := 'During update operation of customer accounts DQ table (report)';
  
    UPDATE xxobjt.xxs3_otc_customer_accounts
    SET process_flag = 'Q'
    WHERE xx_cust_account_id = p_xx_cust_account_id;
  
    /* Insert DQ Rule detials in the dq table */
  l_step := 'During insert operation of customer accounts DQ table(report)';
  
    INSERT INTO xxobjt.xxs3_otc_customer_accounts_dq
      (xx_dq_cust_account_id
      ,xx_cust_account_id
      ,rule_name
      ,notes
      ,dq_status)
    VALUES
      (xxobjt.xxs3_otc_cust_accounts_dq_seq.NEXTVAL
      ,p_xx_cust_account_id
      ,p_rule_name
      ,p_reject_code
      ,'Q');
    COMMIT;
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log, 'Unexpected error during ' ||l_step||''||
                         chr(10) || SQLCODE || chr(10) ||
                         SQLERRM);
  END insert_update_dq;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Insert in to DQ table (reject records) for validation of errors and update the master table
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  11/05/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  PROCEDURE insert_update_reject_dq(p_xx_cust_account_id     IN NUMBER
                                   ,p_rule_name              IN VARCHAR2
                                   ,p_reject_code            IN VARCHAR2
                                   ,p_legacy_cust_account_id NUMBER) IS
   l_step VARCHAR2(100); 
  BEGIN
  
    /* Update process Flag for Reject Records */
  l_step := 'During update operation of customer accounts DQ table(reject)';
    UPDATE xxobjt.xxs3_otc_customer_accounts
    SET process_flag = 'R'
    WHERE xx_cust_account_id = p_xx_cust_account_id;
  
  
    /* Insert reject records details in the dq table */
  l_step := 'During insert operation of customer accounts DQ table(reject)';
    INSERT INTO xxobjt.xxs3_otc_customer_accounts_dq
      (xx_dq_cust_account_id
      ,xx_cust_account_id
      ,rule_name
      ,notes
      ,dq_status)
    VALUES
      (xxobjt.xxs3_otc_cust_accounts_dq_seq.NEXTVAL
      ,p_xx_cust_account_id
      ,p_rule_name
      ,p_reject_code
      ,'R');
    COMMIT;
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log, 'Unexpected error during DQ table insert : ' ||
                         chr(10) || SQLCODE || chr(10) ||
                         SQLERRM);
  END insert_update_reject_dq;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Insert in to DQ table for validation of errors and update the master table
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  11/05/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  PROCEDURE insert_update_uses_dq(p_xx_cust_acct_site_use_id IN NUMBER
                                 ,p_rule_name                IN VARCHAR2
                                 ,p_reject_code              IN VARCHAR2
                                 ,p_legacy_site_use_id       NUMBER) IS
  BEGIN
    /* Update process Flag for DQ validation Records */
  
    UPDATE xxobjt.xxs3_otc_cust_acct_site_uses
    SET process_flag = 'Q'
    WHERE xx_cust_acct_site_use_id = p_xx_cust_acct_site_use_id;
  
    /* Insert DQ Rule detials in the dq table */
  
    INSERT INTO xxobjt.xxs3_otc_cus_act_site_uses_dq
      (xx_dq_cust_acct_site_use_id
      ,xx_cust_acct_site_use_id
      ,rule_name
      ,notes
      ,dq_status)
    VALUES
      (xxobjt.xxs3_otc_act_site_uses_dq_seq.NEXTVAL
      ,p_xx_cust_acct_site_use_id
      ,p_rule_name
      ,p_reject_code
      ,'Q');
    COMMIT;
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log, 'Unexpected error during DQ table insert : ' ||
                         chr(10) || SQLCODE || chr(10) ||
                         SQLERRM);
  END insert_update_uses_dq;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Insert in to DQ table for validation of errors and update the master table
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  11/05/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  PROCEDURE insert_update_uses_reject_dq(p_xx_cust_acct_site_use_id IN NUMBER
                                        ,p_rule_name                IN VARCHAR2
                                        ,p_reject_code              IN VARCHAR2
                                        ,p_legacy_site_use_id       NUMBER) IS
  BEGIN
    /* Update process Flag for Reject Records */
  
    UPDATE xxobjt.xxs3_otc_cust_acct_site_uses
    SET process_flag = 'R'
    WHERE xx_cust_acct_site_use_id = p_xx_cust_acct_site_use_id;
  
    /* Insert reject records details in the dq table */
  
    INSERT INTO xxobjt.xxs3_otc_cus_act_site_uses_dq
      (xx_dq_cust_acct_site_use_id
      ,xx_cust_acct_site_use_id
      ,rule_name
      ,notes
      ,dq_status)
    VALUES
      (xxobjt.xxs3_otc_act_site_uses_dq_seq.NEXTVAL
      ,p_xx_cust_acct_site_use_id
      ,p_rule_name
      ,p_reject_code
      ,'R');
    COMMIT;
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log, 'Unexpected error during DQ table insert : ' ||
                         chr(10) || SQLCODE || chr(10) ||
                         SQLERRM);
  END insert_update_uses_reject_dq;
  
   -- --------------------------------------------------------------------------------------------
  -- Purpose: Insert in to DQ table for customer site DQ errors
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  28/12/2016  Debarati Banerjee             Initial build
  -----------------------------------------------------------------------------------------------
  PROCEDURE insert_update_dq_site(p_xx_cust_account_site_id     IN NUMBER
                            ,p_rule_name              IN VARCHAR2
                            ,p_reject_code            IN VARCHAR2) IS
    l_step VARCHAR2(100);                        
  BEGIN
   
    /* Update process Flag for DQ validation Records */
  l_step := 'During update operation of customer site DQ table (report)';
  
    UPDATE xxobjt.xxs3_otc_cust_acct_sites
    SET process_flag = 'Q'
    WHERE xx_cust_account_site_id = p_xx_cust_account_site_id;
  
    /* Insert DQ Rule detials in the dq table */
  l_step := 'During insert operation of customer site DQ table(report)';
  
    INSERT INTO xxobjt.xxs3_otc_cust_acct_site_dq
      (xx_dq_cust_acct_site_id
      ,xx_cust_account_site_id
      ,rule_name
      ,notes
      ,dq_status)
    VALUES
      (xxobjt.xxs3_otc_cust_acct_site_dq_seq.NEXTVAL
      ,p_xx_cust_account_site_id
      ,p_rule_name
      ,p_reject_code
      ,'Q');
    COMMIT;
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log, 'Unexpected error during ' ||l_step||''||
                         chr(10) || SQLCODE || chr(10) ||
                         SQLERRM);
  END insert_update_dq_site;
  
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
      AND    hcas.org_id = g_org_id
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
  -- Purpose: Extract data from staging tables for quality check of CUSTOMER track
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  11/05/2016  Mishal Kumar                  Initial build
  -- 1.1  27/12/2016  Debarati Banerjee             Added new DQ rule
  -----------------------------------------------------------------------------------------------
  PROCEDURE quality_check_cust_accounts IS
    l_result      BOOLEAN;
    l_result002   BOOLEAN;
    l_result017   BOOLEAN;
    l_result018   BOOLEAN;
    l_result029   BOOLEAN;
    l_result028   BOOLEAN;
    l_result028_1 BOOLEAN;
    l_result030   BOOLEAN;
    l_result030_1 BOOLEAN;
    l_result030_2 BOOLEAN;
    l_result030_3 BOOLEAN;
    l_result030_4 BOOLEAN;
    l_result028_2 BOOLEAN;
    l_result030_5 BOOLEAN;
    l_result031   BOOLEAN;
    l_result030_6 BOOLEAN;
    l_result030_7 BOOLEAN;
    l_result030_8 BOOLEAN;
    l_result030_9 BOOLEAN;
    l_result028_3 BOOLEAN;
    l_result025   BOOLEAN;
    l_result026   BOOLEAN;
    l_result027   BOOLEAN;
    l_result152   BOOLEAN;
    l_status      BOOLEAN := TRUE;
    l_check_rule      VARCHAR2(10) := 'TRUE';
  
    --
  BEGIN
  
    /* DQ Validations section */
  
    FOR i IN (SELECT *
              FROM xxobjt.xxs3_otc_customer_accounts
              WHERE extract_rule_name IS NOT NULL)
    LOOP
      l_status := TRUE; /* Added by santanu */
      l_result152 := xxs3_dq_util_pkg.eqt_152(i.party_id); /* Added by Santanu */
    
      --l_result029   := xxs3_dq_util_pkg.eqt_029(i.attribute2, i.attribute3); /* ONLY FOR PARTY_TYPE = ORGANIZATION */
      --l_result028   := xxs3_dq_util_pkg.eqt_028(i.sf_account_id); /*--attribute4 */
      --l_result028_1 := xxs3_dq_util_pkg.eqt_028(i.transfer_to_sf); /*--attribute5 */
      l_result028_2 := xxs3_dq_util_pkg.eqt_028(i.customer_type);
      --l_result028_3 := xxs3_dq_util_pkg.eqt_028(i.account_name);
      /*--x_result030   := xxs3_dq_util_pkg.eqt_030(i.attribute7);
      --x_result030_1 := xxs3_dq_util_pkg.eqt_030(i.customer_start_date);
      --x_result030_2 := xxs3_dq_util_pkg.eqt_030(i.inactive_reason);
      --x_result030_3 := xxs3_dq_util_pkg.eqt_030(i.customer_end_date);
      --x_result030_4 := xxs3_dq_util_pkg.eqt_030(i.attribute19); */
      --l_result030_5 := xxs3_dq_util_pkg.eqt_030(i.customer_class_code); 
      /*-- ONLY FOR PARTY_TYPE = ORGANIZATION */    
      --commented as on 26/12
      l_result030_6 := xxs3_dq_util_pkg.eqt_030(i.warehouse_id); 
      --commented as on 26/12
      l_result030_7 := xxs3_dq_util_pkg.eqt_030(i.tax_header_level_flag); /*-- ONLY FOR PARTY_TYPE = ORGANIZATION */
      l_result030_8 := xxs3_dq_util_pkg.eqt_030(i.tax_rounding_rule);
      l_result030_9 := xxs3_dq_util_pkg.eqt_030(i.account_established_date);
      l_result031   := xxs3_dq_util_pkg.eqt_031(i.sales_channel_code); --
      
      
      /*IF l_result029 = TRUE
      THEN
        insert_update_dq(i.xx_cust_account_id, 'EQT_029', 'EQT_029 :Missing value for Cstomer Attribute2 and 3', i.legacy_cust_account_id);
        l_status := FALSE;
      END IF;*/
    
      
      --
    /*  IF l_result028_3 = TRUE
      THEN
        insert_update_dq(i.xx_cust_account_id, 'EQT_028', 'EQT_028 :account_name Missing value', i.legacy_cust_account_id);
        l_status := FALSE;
      END IF;*/
    
      /*IF l_result030_5 = TRUE
      THEN
        insert_update_dq(i.xx_cust_account_id, 'EQT_030', 'EQT_030 :customer_class_code Should be NULL', i.legacy_cust_account_id);
        l_status := FALSE;
      END IF;*/
      
      IF l_result030_6 = TRUE
      THEN
        insert_update_dq(i.xx_cust_account_id, 'EQT_030', 'EQT_030 :warehouse_id Should be NULL', i.legacy_cust_account_id);
        l_status := FALSE;
      END IF;
      
      IF l_result030_7 = TRUE
      THEN
        insert_update_dq(i.xx_cust_account_id, 'EQT_030', 'EQT_030 :tax_header_level_flag Should be NULL', i.legacy_cust_account_id);
        l_status := FALSE;
      END IF;
      --
      IF l_result030_8 = TRUE
      THEN
        insert_update_dq(i.xx_cust_account_id, 'EQT_030', 'EQT_030 :tax_rounding_rule Should be NULL', i.legacy_cust_account_id);
        l_status := FALSE;
      END IF;
      --
      IF l_result030_9 = TRUE
      THEN
        insert_update_dq(i.xx_cust_account_id, 'EQT_030', 'EQT_030 :account_established_date Should be NULL', i.legacy_cust_account_id);
        l_status := FALSE;
      END IF;
      --
     
    
      /*IF xxs3_dq_util_pkg.eqt_030(i.s3_fob_point) = TRUE
      THEN
        insert_update_dq(i.xx_cust_account_id, 'EQT_030', 'EQT_030 :fob_point Should be NULL', i.legacy_cust_account_id);
        l_status := FALSE;
      END IF;*/
      
      --commented as on 26/12
    
      /*IF xxs3_dq_util_pkg.eqt_030(i.freight_term) = TRUE
      THEN
        insert_update_dq(i.xx_cust_account_id, 'EQT_030', 'EQT_030 :freight_term Should be NULL', i.legacy_cust_account_id);
        l_status := FALSE;
      END IF;*/
      
      --commented as on 26/12
      
      --new DQ rule as per FDD update 26/12
      
      IF i.s3_account_name IS NOT NULL THEN
        l_check_rule := xxs3_dq_util_pkg.eqt_001(i.s3_account_name);

        IF l_check_rule = 'FALSE' THEN
          insert_update_dq(i.xx_cust_account_id, 'EQT_001:Standardize Organization Name', 'Non-std Org Name for field account_name',i.legacy_cust_account_id);
          l_status := FALSE;
        END IF;
      END IF;          
      
       --new DQ rule as per FDD update 26/12
       
       --hz_customer_profiles DQ)
       
      /* IF i.credit_analyst_emp_no IS  NULL THEN
        l_check_rule := 'FALSE';
          insert_update_dq(i.xx_cust_account_id, 'EQT_042:PER_ALL_PEOPLE_F EMPLOYEE_NUMBER does not exist', 'Invalid employee for field credit_analyst_emp_no',i.legacy_cust_account_id);
          l_status := FALSE;        
      END IF;*/
     
     IF i.collector_id IS NOT NULL THEN
      IF i.s3_collector_emp_number IS  NULL THEN
        l_check_rule := 'FALSE';
          insert_update_dq(i.xx_cust_account_id, 'EQT_042:PER_ALL_PEOPLE_F EMPLOYEE_NUMBER does not exist', 'Invalid employee for field collector_emp_number',i.legacy_cust_account_id);
          l_status := FALSE;
      END IF;
    END IF;
      
       /*IF l_result028 = TRUE
      THEN
        insert_update_reject_dq(i.xx_cust_account_id, 'EQT_028', 'EQT_028 :sf_account_id Missing value', i.legacy_cust_account_id);
        l_status := FALSE;
      END IF;
    
      IF l_result028_1 = TRUE
      THEN
        insert_update_reject_dq(i.xx_cust_account_id, 'EQT_028', 'EQT_028 :transfer_to_sf Missing value', i.legacy_cust_account_id);
        l_status := FALSE;
      END IF;*/
    
     IF xxs3_otc_customer_pkg.get_site_count(i.legacy_cust_account_id) = 'Y' THEN 
      IF l_result028_2 = TRUE
      THEN
        insert_update_reject_dq(i.xx_cust_account_id, 'EQT_028', 'EQT_028 :customer_type Missing value', i.legacy_cust_account_id);
        l_status := FALSE;
      END IF;
     END IF;
      
       IF l_result031 = TRUE
      THEN
        insert_update_reject_dq(i.xx_cust_account_id, 'EQT_031', 'EQT_031 :Invalid Sales Channel', i.legacy_cust_account_id);
        l_status := FALSE;
      END IF;
      --
      IF l_result152 = FALSE
      THEN
        insert_update_reject_dq(i.xx_cust_account_id, 'EQT_152', 'EQT_152 :1 Party 1 Account Rule', i.legacy_cust_account_id);
        l_status := FALSE;
      END IF;
      
      --hz_customer_profiles DQ)
    
      IF l_status = TRUE
      THEN
        /* Update Process Flag if no DQ validation error*/
       BEGIN
        UPDATE xxobjt.xxs3_otc_customer_accounts
        SET process_flag = 'Y'
        WHERE xx_cust_account_id = i.xx_cust_account_id;
       EXCEPTION
          WHEN OTHERS THEN
            fnd_file.put_line(fnd_file.log, 'Unexpected error during process_flag update : ' ||
                     chr(10) || SQLCODE || chr(10) || SQLERRM);
       END;
      END IF;
    
    END LOOP;
    COMMIT;
  END quality_check_cust_accounts;
  
   -- --------------------------------------------------------------------------------------------
  -- Purpose: Extract data from staging tables for quality check of Customer Profiles
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  26/04/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE quality_check_profiles IS
    l_count       NUMBER := 0;
    x_result042   BOOLEAN;
    x_result043   BOOLEAN;
    x_result044   BOOLEAN;
    x_result044_1 BOOLEAN;
    x_result045   BOOLEAN;
    x_result046   BOOLEAN;
    x_result048   BOOLEAN;
    x_result049   BOOLEAN;
    x_result030   BOOLEAN;
    l_status      BOOLEAN := TRUE;

    --
  BEGIN
    FOR i IN (SELECT *
              FROM xxobjt.xxs3_otc_customer_accounts
              WHERE extract_rule_name IS NOT NULL) LOOP
      l_status := TRUE;
      --
      x_result030   := xxs3_dq_util_pkg.eqt_030(i.site_use_id);
      x_result042   := xxs3_dq_util_pkg.eqt_042(i.collector_id);
      x_result043   := xxs3_dq_util_pkg.eqt_043(i.legacy_cust_account_id, i.credit_checking);
      x_result044   := xxs3_dq_util_pkg.eqt_044(i.override_terms);
      x_result044_1 := xxs3_dq_util_pkg.eqt_044(i.credit_hold);
      x_result045   := xxs3_dq_util_pkg.eqt_045(i.legacy_cust_account_id, i.profile_class_id);
      x_result046   := xxs3_dq_util_pkg.eqt_046(i.legacy_cust_account_id, i.standard_terms);
      x_result048   := xxs3_dq_util_pkg.eqt_048(i.send_statements, i.statement_cycle_id);
      x_result049   := xxs3_dq_util_pkg.eqt_049(i.send_statements, i.tax_printing_option);
      --
      IF x_result030 = TRUE THEN
        insert_update_dq(i.xx_cust_account_id, 'EQT_030', 'EQT_030 :Should be Null', i.legacy_cust_account_id);
        l_status := FALSE;
      END IF;
      --
      IF x_result042 = TRUE THEN
        insert_update_reject_dq(i.xx_cust_account_id, 'EQT_042', 'EQT_042 :Invalid Person', i.legacy_cust_account_id);
        l_status := FALSE;
      END IF;
      --
      IF x_result043 = TRUE THEN
        insert_update_dq(i.xx_cust_account_id, 'EQT_043', 'EQT_043 :Incorrect Credit Check Value', i.legacy_cust_account_id);
        l_status := FALSE;
      END IF;
      --
      l_count := 0;
      SELECT COUNT(organization_id)
        INTO l_count
        FROM hr_organization_units_v
       WHERE organization_id IN
             (SELECT org_id
                FROM hz_cust_accounts
               WHERE cust_account_id = i.legacy_cust_account_id)
         AND country = 'US';
      IF l_count <> 0 THEN
        IF x_result044 = TRUE THEN
          insert_update_dq(i.xx_cust_account_id, 'EQT_044', 'EQT_044 :Override Term should be Y', i.legacy_cust_account_id);
          l_status := FALSE;
        END IF;
      END IF;
      --
      l_count := 0;
      SELECT COUNT(organization_id)
        INTO l_count
        FROM hr_organization_units_v
       WHERE organization_id IN
             (SELECT org_id
                FROM hz_cust_accounts
               WHERE cust_account_id = i.legacy_cust_account_id)
         AND country = 'US';
      IF l_count <> 0 THEN
        IF x_result044_1 = TRUE THEN
          insert_update_dq(i.xx_cust_account_id, 'EQT_044', 'EQT_044 :credit hold Should be Y', i.legacy_cust_account_id);
          l_status := FALSE;
        END IF;
      END IF;
      --
      IF x_result045 = TRUE THEN
        insert_update_dq(i.xx_cust_account_id, 'EQT_045', 'EQT_045 :Invalid US Profile Class', i.legacy_cust_account_id);
        l_status := FALSE;
      END IF;
      --
      IF x_result046 = TRUE THEN
        insert_update_dq(i.xx_cust_account_id, 'EQT_046', 'EQT_046 :Invalid US Cust Profile Terms', i.legacy_cust_account_id);
        l_status := FALSE;
      END IF;
      --
      IF x_result048 = TRUE THEN
        insert_update_dq(i.xx_cust_account_id, 'EQT_048', 'EQT_048 :Missing Cust Statement Cycle', i.legacy_cust_account_id);
        l_status := FALSE;
      END IF;
      --
      IF x_result049 = TRUE THEN
        insert_update_dq(i.xx_cust_account_id, 'EQT_049', 'EQT_049 :Invalid Cust Statement Print Option', i.legacy_cust_account_id);
        l_status := FALSE;
      END IF;
      --
      IF l_status = TRUE THEN
        BEGIN
          UPDATE xxobjt.xxs3_otc_customer_accounts
             SET process_flag = 'Y'
           WHERE xx_cust_account_id = i.xx_cust_account_id;
        EXCEPTION
          WHEN OTHERS THEN
            fnd_file.put_line(fnd_file.log, 'Unexpected error during process_flag update : ' ||
                     chr(10) || SQLCODE || chr(10) || SQLERRM);
        END;
      END IF;
      --
    END LOOP;
    COMMIT;
  END quality_check_profiles;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Generate Data Quality Report for Cusomer Accounts
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0 26/04/2016  Mishal Kumar                  Initial build
  --  1.1 28/12/2016  Debarati Banerjee             Added DQ Report for Customer Site
  -----------------------------------------------------------------------------------------------
  PROCEDURE report_data_cus_acct(p_entity VARCHAR2) IS
  
    l_delimiter    VARCHAR2(5) := '~';
    l_err_msg      VARCHAR2(2000);
    l_count_dq     NUMBER;
    l_count_reject NUMBER;
  
    /*Cursor for generate the DQ Report for the Customer */
  
    CURSOR c_report_customer IS
      SELECT nvl(cd.rule_name, ' ') rule_name
            ,nvl(cd.notes, ' ') notes
            ,c.legacy_cust_account_id legacy_cust_account_id
            ,cd.xx_cust_account_id xx_cust_account_id
            ,c.legacy_account_number
            ,c.account_name
            ,c.extract_dq_error
            ,p.legacy_party_number
            ,cd.dq_status 
            ,decode(c.process_flag, 'R', 'Y', 'Q', 'N') reject_record
      FROM xxobjt.xxs3_otc_customer_accounts    c
          ,xxobjt.xxs3_otc_customer_accounts_dq cd
          ,xxobjt.xxs3_otc_parties p
      WHERE c.xx_cust_account_id = cd.xx_cust_account_id
      AND p.legacy_party_id = c.party_id
      AND c.process_flag IN ('Q', 'R');
      
      CURSOR c_report_cust_site IS
      SELECT nvl(cd.rule_name, ' ') rule_name,
             nvl(cd.notes, ' ') notes,
             c.legacy_cust_account_site_id legacy_cust_account_site_id,
             (SELECT account_number
                FROM hz_cust_accounts
               WHERE cust_account_id = c.legacy_cust_account_id) account_number,
             cd.xx_cust_account_site_id xx_cust_account_site_id,
             c.extract_dq_error,
             (SELECT legacy_party_site_number FROM xxs3_otc_party_sites
             WHERE legacy_party_site_id = c.legacy_party_site_id) party_site_number,
             c.org_name,
             dq_status,
             decode(c.process_flag, 'R', 'Y', 'Q', 'N') reject_record
        FROM xxobjt.xxs3_otc_cust_acct_sites   c,
             xxobjt.xxs3_otc_cust_acct_site_dq cd
       WHERE c.xx_cust_account_site_id = cd.xx_cust_account_site_id
         AND c.process_flag IN ('Q', 'R');
  
  BEGIN
    IF p_entity = 'CUSTOMER'
    THEN
    
      /*count of the DQ records */
      SELECT COUNT(1)
      INTO l_count_dq
      FROM xxs3_otc_customer_accounts xca
      WHERE xca.process_flag IN ('Q', 'R');
    
      /* Count of Reject records */
      SELECT COUNT(1)
      INTO l_count_reject
      FROM xxs3_otc_customer_accounts xca
      WHERE xca.process_flag = 'R';
    
      /* Utl out put formate */
      fnd_file.put_line(fnd_file.output, rpad('Report name = Customer Accounts Data Quality Error Report' ||
                              l_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('========================================' ||
                              l_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Data Migration Object Name = ' ||
                              p_entity || l_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, '');
      fnd_file.put_line(fnd_file.output, rpad('Run date and time:    ' ||
                              to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') ||
                              l_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Total Record Count Having DQ Issues = ' ||
                              l_count_dq || l_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Total Record Count Rejected =  ' ||
                              l_count_reject || l_delimiter, 100, ' '));
    
      fnd_file.put_line(fnd_file.output, '');
    
      fnd_file.put_line(fnd_file.output, rpad('Track Name', 10, ' ') ||
                         l_delimiter ||
                         rpad('Entity Name', 17, ' ') ||
                         l_delimiter ||
                         rpad('XX Cust Account ID ', 20, ' ') ||
                         l_delimiter ||
                         rpad('Legacy Cust Account ID', 30, ' ') ||
                         l_delimiter ||
                         rpad('Legacy_Account Number', 30, ' ') ||
                         l_delimiter ||
                         rpad('Legacy Account Name', 100, ' ') ||
                         l_delimiter ||
                         rpad('Legacy Party Number', 30, ' ') ||
                         l_delimiter ||
                         rpad('DQ Status', 2, ' ') ||
                         l_delimiter ||
                         rpad('Reject Record Flag(Y/N)', 22, ' ') ||
                         l_delimiter ||
                         rpad('Rule Name', 20, ' ') ||
                         l_delimiter ||
                         rpad('Reject Reason', 50, ' ')||
                         l_delimiter ||
                         rpad('Extract DQ Error', 100, ' '));
    
      FOR r_data IN c_report_customer
      LOOP
        fnd_file.put_line(fnd_file.output, rpad('OTC', 10, ' ') ||
                           l_delimiter ||
                           rpad('Customer Accounts', 17, ' ') ||
                           l_delimiter ||
                           rpad(r_data.xx_cust_account_id, 20, ' ') ||
                           l_delimiter ||
                           rpad(r_data.legacy_cust_account_id, 30, ' ') ||
                           l_delimiter ||
                           rpad(r_data.legacy_account_number, 30, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.account_name, 'NULL'), 100, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.legacy_party_number, 'NULL'), 30, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.dq_status, 'NULL'), 2, ' ') ||
                           l_delimiter ||
                           rpad(r_data.reject_record, 22, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.rule_name, 'NULL'), 20, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.notes, 'NULL'), 50, ' ')||
                           l_delimiter ||
                           rpad(nvl(r_data.extract_dq_error, 'NULL'), 100, ' '));
      
      END LOOP;
      fnd_file.put_line(fnd_file.output, rpad('=============================', 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('End Of Report', 100, ' '));
      
   ELSIF p_entity = 'CUSTOMER_SITE' THEN
    
      /*count of the DQ records */
      SELECT COUNT(1)
      INTO l_count_dq
      FROM xxs3_otc_cust_acct_sites xca
      WHERE xca.process_flag IN ('Q', 'R');
    
      /* Count of Reject records */
      SELECT COUNT(1)
      INTO l_count_reject
      FROM xxs3_otc_cust_acct_sites xca
      WHERE xca.process_flag = 'R';
    
      /* Utl out put formate */
      fnd_file.put_line(fnd_file.output, rpad('Report name = Customer Site Data Quality Error Report' ||
                              l_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('========================================' ||
                              l_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Data Migration Object Name = ' ||
                              p_entity || l_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, '');
      fnd_file.put_line(fnd_file.output, rpad('Run date and time:    ' ||
                              to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') ||
                              l_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Total Record Count Having DQ Issues = ' ||
                              l_count_dq || l_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Total Record Count Rejected =  ' ||
                              l_count_reject || l_delimiter, 100, ' '));
    
      fnd_file.put_line(fnd_file.output, '');
    
      fnd_file.put_line(fnd_file.output, rpad('Track Name', 10, ' ') ||
                         l_delimiter ||
                         rpad('Entity Name', 17, ' ') ||
                         l_delimiter ||
                         rpad('XX Cust Account Site ID ', 20, ' ') ||
                         l_delimiter ||
                         rpad('Legacy Cust Account Site ID', 30, ' ') ||
                         l_delimiter ||
                         rpad('Legacy_Account Number', 30, ' ') ||
                         l_delimiter ||
                         rpad('Org Name', 250, ' ') ||
                         l_delimiter ||
                         rpad('Party_Site_Number', 30, ' ') ||
                         l_delimiter ||
                         rpad(nvl('Dq_Status', 'NULL'), 2, ' ') ||
                         l_delimiter ||
                         rpad('Reject Record Flag(Y/N)', 22, ' ') ||
                         l_delimiter ||
                         rpad('Rule Name', 400, ' ') ||
                         l_delimiter ||
                         rpad('Reject Reason', 400, ' ')||
                         l_delimiter ||
                         rpad('Extract DQ Error', 400, ' '));
    
      FOR r_data IN c_report_cust_site
      LOOP
        fnd_file.put_line(fnd_file.output, rpad('OTC', 10, ' ') ||
                           l_delimiter ||
                           rpad('Customer Site', 17, ' ') ||
                           l_delimiter ||
                           rpad(r_data.xx_cust_account_site_id, 20, ' ') ||
                           l_delimiter ||
                           rpad(r_data.legacy_cust_account_site_id, 30, ' ') ||
                           l_delimiter ||
                           rpad(r_data.account_number, 30, ' ') ||
                           l_delimiter ||
                           rpad(r_data.org_name, 250, ' ') ||
                           l_delimiter ||
                           rpad(r_data.party_site_number, 30, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.dq_status, 'NULL'), 2, ' ') ||
                           l_delimiter ||
                           rpad(r_data.reject_record, 22, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.rule_name, 'NULL'), 400, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.notes, 'NULL'), 400, ' ')||
                           l_delimiter ||
                           rpad(r_data.extract_dq_error, 100, ' '));
      
      END LOOP;
      fnd_file.put_line(fnd_file.output, rpad('=============================', 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('End Of Report', 100, ' '));
    
    END IF;
  END report_data_cus_acct;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Extract data from staging tables for quality check of CUSTOMER_SITE_USES track
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  11/05/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  PROCEDURE quality_check_cust_site_uses IS
    /* Variables */
    l_result029   BOOLEAN;
    l_result028   BOOLEAN;
    l_result028_1 BOOLEAN;
    l_result030   BOOLEAN;
    l_result030_1 BOOLEAN;
    l_result030_2 BOOLEAN;
    l_result030_3 BOOLEAN;
    l_result030_4 BOOLEAN;
    l_result028_2 BOOLEAN;
    l_result030_5 BOOLEAN;
    l_result031   BOOLEAN;
    l_result030_6 BOOLEAN;
    l_result030_7 BOOLEAN;
    l_result030_8 BOOLEAN;
    l_result030_9 BOOLEAN;
    l_result028_3 BOOLEAN;
    l_result028_4 BOOLEAN;
    l_result025   BOOLEAN;
    l_result026   BOOLEAN;
    l_result027   BOOLEAN;
    l_result162   BOOLEAN;
    l_result163   BOOLEAN;
    l_result164   BOOLEAN;
    l_result165   BOOLEAN;
    l_result188   BOOLEAN;
    l_result189   BOOLEAN;
    l_result193   BOOLEAN;
    l_result190   VARCHAR2(10);
    l_result191   VARCHAR2(10);
    l_result192   VARCHAR2(10);
    l_status      BOOLEAN := TRUE;
  
    --
  BEGIN
    /* DQ Validation for the Customer Site Use */
  
    FOR i IN (SELECT *
              FROM xxobjt.xxs3_otc_cust_acct_site_uses
              WHERE extract_rule_name IS NOT NULL)
    LOOP
      l_status := TRUE;
      --
      l_result025   := xxs3_dq_util_pkg.eqt_025(i.site_use_code);
      --l_result026   := xxs3_dq_util_pkg.eqt_026(i.primary_flag);
      --l_result027   := xxs3_dq_util_pkg.eqt_027(i.location); --Commented on 22/12
      l_result028   := xxs3_dq_util_pkg.eqt_028(i.gsa_indicator);
      l_result028_1 := xxs3_dq_util_pkg.eqt_028(i.org_id);
      l_result028_2 := xxs3_dq_util_pkg.eqt_028(i.ship_sets_include_lines_flag);
      l_result028_3 := xxs3_dq_util_pkg.eqt_028(i.arrivalsets_include_lines_flag);
      l_result028_4 := xxs3_dq_util_pkg.eqt_028(i.sched_date_push_flag);
      l_result162   := xxs3_dq_util_pkg.eqt_162(i.cust_account_id);
      l_result163   := xxs3_dq_util_pkg.eqt_163(i.cust_account_id);
      l_result164   := xxs3_dq_util_pkg.eqt_164(i.cust_account_id);
      l_result165   := xxs3_dq_util_pkg.eqt_165(i.cust_account_id);
     /* l_result188   := xxs3_dq_util_pkg.eqt_188(i.org_id, i.gl_id_rec_seg4, i.gl_id_rec);--Commented on 22/12
      l_result189   := xxs3_dq_util_pkg.eqt_189(i.org_id, i.gl_id_rev_seg4, i.gl_id_rev);
      l_result193   := xxs3_dq_util_pkg.eqt_193(i.org_id, i.gl_id_unearned_seg4, i.gl_id_unearned);
      l_result190   := xxs3_dq_util_pkg.eqt_190(i.gl_id_tax);
      l_result191   := xxs3_dq_util_pkg.eqt_191(i.org_id, i.gl_id_freight_seg4, i.gl_id_freight);
      l_result192   := xxs3_dq_util_pkg.eqt_192(i.gl_id_unbilled);*/ --Commented on 22/12
    
      
      --
     /* IF l_result027 = TRUE --Commented on 22/12
      THEN
        insert_update_uses_reject_dq(i.xx_cust_acct_site_use_id, 'EQT_027', 'EQT_027 :Missing Location', i.legacy_site_use_id);
        l_status := FALSE;
      END IF;*/
      --
       IF l_result162 = FALSE
      THEN
        insert_update_uses_dq(i.xx_cust_acct_site_use_id, 'EQT_162', 'EQT_162 :1 Primary Bill To', i.legacy_site_use_id);
        l_status := FALSE;
      END IF;
      IF l_result163 = FALSE
      THEN
        insert_update_uses_dq(i.xx_cust_acct_site_use_id, 'EQT_163', 'EQT_163 :1 Primary Ship To', i.legacy_site_use_id);
        l_status := FALSE;
      END IF;
      IF l_result164 = FALSE
      THEN
        insert_update_uses_dq(i.xx_cust_acct_site_use_id, 'EQT_164', 'EQT_164 :No Primary Bill To', i.legacy_site_use_id);
        l_status := FALSE;
      END IF;
      IF l_result165 = FALSE
      THEN
        insert_update_uses_dq(i.xx_cust_acct_site_use_id, 'EQT_165', 'EQT_165 :No Primary Ship To', i.legacy_site_use_id);
        l_status := FALSE;
      END IF;
      
      IF l_result028 = TRUE
      THEN
        insert_update_uses_reject_dq(i.xx_cust_acct_site_use_id, 'EQT_028', 'EQT_028 :gsa_indicator Missing value', i.legacy_site_use_id);
        l_status := FALSE;
      END IF;
      --
      IF l_result028_1 = TRUE
      THEN
        insert_update_uses_reject_dq(i.xx_cust_acct_site_use_id, 'EQT_028', 'EQT_028 :org_id Missing value', i.legacy_site_use_id);
        l_status := FALSE;
      END IF;
      --
      IF l_result028_2 = TRUE
      THEN
        insert_update_uses_reject_dq(i.xx_cust_acct_site_use_id, 'EQT_028', 'EQT_028 :ship_sets_include_lines_flag Missing value', i.legacy_site_use_id);
        l_status := FALSE;
      END IF;
      --
      IF l_result028_3 = TRUE
      THEN
        insert_update_uses_reject_dq(i.xx_cust_acct_site_use_id, 'EQT_028', 'EQT_028 :arrivalsets_include_lines_flag Missing value', i.legacy_site_use_id);
        l_status := FALSE;
      END IF;
      --
      IF l_result028_4 = TRUE
      THEN
        insert_update_uses_reject_dq(i.xx_cust_acct_site_use_id, 'EQT_028', 'EQT_028 :sched_date_push_flag Missing value', i.legacy_site_use_id);
        l_status := FALSE;
      END IF;
      --     
      
      IF l_result025 = TRUE
      THEN
        insert_update_uses_reject_dq(i.xx_cust_acct_site_use_id, 'EQT_025', 'EQT_025 :Invalid Customer Site Use Code', i.legacy_site_use_id);
        l_status := FALSE;
      END IF;
      --
     /* IF l_result026 = TRUE
      THEN
        insert_update_uses_reject_dq(i.xx_cust_acct_site_use_id, 'EQT_026', 'EQT_026 :Missing Primary Flag', i.legacy_site_use_id);
        l_status := FALSE;
      END IF;*/
     
     IF i.primary_salesrep_id IS NOT NULL THEN 
      IF i.org_id <> 737 AND i.salesrep_emp_number IS  NULL THEN
          insert_update_uses_reject_dq(i.xx_cust_acct_site_use_id, 'EQT_042:PER_ALL_PEOPLE_F EMPLOYEE_NUMBER does not exist', 'Invalid employee for field primary_salesrep_id',i.legacy_site_use_id);
          l_status := FALSE;        
      END IF;
     END IF;
     /* IF l_result188 = TRUE --Commented as on 28/12
      THEN
        insert_update_uses_dq(i.xx_cust_acct_site_use_id, 'EQT_188', 'EQT_188 :Valid Customer GL REC Segment 4', i.legacy_site_use_id);
        l_status := FALSE;
      END IF;
      IF l_result189 = TRUE
      THEN
        insert_update_uses_dq(i.xx_cust_acct_site_use_id, 'EQT_189', 'EQT_189 :Valid Customer GL REV Segment 4', i.legacy_site_use_id);
        l_status := FALSE;
      END IF;
      IF l_result193 = TRUE
      THEN
        --insert_update_uses_reject_dq(i.xx_cust_acct_site_use_id, 'EQT_193', 'EQT_193 :Valid Customer GL UNEARNED Segment 4', i.legacy_site_use_id);
        insert_update_uses_dq(i.xx_cust_acct_site_use_id, 'EQT_193', 'EQT_193 :Invalid Customer GL UNEARNED Segment 4', i.legacy_site_use_id);
        l_status := FALSE;
      END IF;
    
      IF l_result190 = 'FALSE'
      THEN
        --insert_update_uses_reject_dq(i.xx_cust_acct_site_use_id, 'EQT_193', 'EQT_193 :Valid Customer GL UNEARNED Segment 4', i.legacy_site_use_id);
        insert_update_uses_dq(i.xx_cust_acct_site_use_id, 'EQT_190', 'EQT_190 :Invalid Customer GL TAX Segment 4', i.legacy_site_use_id);
        l_status := FALSE;
      END IF;
    
      IF l_result191 = 'FALSE'
      THEN
        --insert_update_uses_reject_dq(i.xx_cust_acct_site_use_id, 'EQT_193', 'EQT_193 :Valid Customer GL UNEARNED Segment 4', i.legacy_site_use_id);
        insert_update_uses_dq(i.xx_cust_acct_site_use_id, 'EQT_191', 'EQT_191 :Invalid Customer GL FREIGHT Segment 4', i.legacy_site_use_id);
        l_status := FALSE;
      END IF;
    
      IF l_result192 = 'FALSE'
      THEN
        --insert_update_uses_reject_dq(i.xx_cust_acct_site_use_id, 'EQT_193', 'EQT_193 :Valid Customer GL UNEARNED Segment 4', i.legacy_site_use_id);
        insert_update_uses_dq(i.xx_cust_acct_site_use_id, 'EQT_192', 'EQT_192 :Invalid Customer GL UNBILLED Segment 4', i.legacy_site_use_id);
        l_status := FALSE;
      END IF;*/ --Commented as on 28/12
      
         
      IF l_status = TRUE
      THEN
        /* Update process records with Y */
      
        UPDATE xxobjt.xxs3_otc_cust_acct_site_uses
        SET process_flag = 'Y'
        WHERE xx_cust_acct_site_use_id = i.xx_cust_acct_site_use_id;
      END IF;
      --
    END LOOP;
    COMMIT;
  END quality_check_cust_site_uses;
  
   -- --------------------------------------------------------------------------------------------
  -- Purpose: Extract data from staging tables for quality check of CUSTOMER_SITES track
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0 28/12/2016  Debarati Banerjee                Initial build
  -----------------------------------------------------------------------------------------------
  PROCEDURE quality_check_cust_sites IS
  
    
  CURSOR cur_org_id IS
   SELECT COUNT(DISTINCT xocs.org_id), legacy_cust_account_id
     FROM xxs3_otc_cust_acct_sites xocs
    WHERE extract_rule_name IS NOT NULL
    GROUP BY xocs.legacy_cust_account_id
   HAVING COUNT(DISTINCT xocs.org_id) > 1;
     
       
  CURSOR cur_dq(p_cust_account_id IN NUMBER) IS
   SELECT hca.account_number,
          hcasa.bill_to_flag,
          hcasa.ship_to_flag,
          hcasa.customer_category_code,
          hp.attribute5,
          xocs.xx_cust_account_site_id
     FROM xxs3_otc_cust_acct_sites xocs,
          hz_cust_accounts         hca,
          hz_parties               hp,
          hz_cust_acct_sites_all   hcasa
    WHERE xocs.legacy_cust_account_id = hca.cust_account_id
      AND hca.party_id = hp.party_id
      AND hcasa.cust_acct_site_id = xocs.legacy_cust_account_site_id
      AND xocs.legacy_cust_account_id = p_cust_account_id;
     
 BEGIN
   FOR i IN cur_org_id LOOP
      FOR j IN cur_dq(i.legacy_cust_account_id) LOOP
       insert_update_dq_site(j.xx_cust_account_site_id
                            ,'EQT_999:Shared Accounts'
                            ,'Account Number :'||j.account_number||' '||
                             'bill_to_flag :'||nvl(j.bill_to_flag,'NULL')||' '||
                             'ship_to_flag :'||nvl(j.ship_to_flag,'NULL')||' '||
                             'customer_category_code :'||nvl(j.customer_category_code,'NULL')||''||
                             'SAM Account Flag :'||nvl(j.attribute5,'NULL'));
      END LOOP;
   END LOOP; 
 --END;
END quality_check_cust_sites;
  
     
  
  ----------------------------------------------------------------------------------------------
  -- Purpose: Update account_name is used for account name cleansing
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  27/12/2016  Debarati Banerjee             Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE update_account_name(p_id         IN NUMBER
                                ,p_account_name IN VARCHAR2) IS
  
    l_error_msg VARCHAR2(2000);
  
  BEGIN
  
    /* Update the s3 Account Name in stg table */
  
    IF regexp_like(p_account_name
                  ,'[A-Za-z]'
                  ,'i')
    THEN
      BEGIN
        UPDATE xxs3_otc_customer_accounts
        SET s3_account_name  = regexp_replace(p_account_name
                                           ,'Inc\.|INC'
                                           ,'Inc')
           ,cleanse_status = 'PASS'
        WHERE xx_cust_account_id = p_id
        AND regexp_like(p_account_name
                      ,'Inc\.|INC');
      
        UPDATE xxs3_otc_customer_accounts
        SET s3_account_name  = regexp_replace(p_account_name
                                           ,'Corp\.|CORP'
                                           ,'Corp')
           ,cleanse_status = 'PASS'
        WHERE xx_cust_account_id = p_id
        AND regexp_like(p_account_name
                      ,'Corp\.|CORP');
      
        UPDATE xxs3_otc_customer_accounts
        SET s3_account_name  = regexp_replace(p_account_name
                                           ,'LLC\.'
                                           ,'LLC')
           ,cleanse_status = 'PASS'
        WHERE xx_cust_account_id = p_id
        AND regexp_like(p_account_name
                      ,'LLC\.');
      
        UPDATE xxs3_otc_customer_accounts
        SET s3_account_name  = regexp_replace(p_account_name
                                           ,'Ltd\.|LTD\.|LTD'
                                           ,'Ltd')
           , --LTD\. is new rule
            cleanse_status = 'PASS'
        WHERE xx_cust_account_id = p_id
        AND regexp_like(p_account_name
                      ,'Ltd\.|LTD\.|LTD');
      
        UPDATE xxs3_otc_customer_accounts
        SET s3_account_name  = regexp_replace(p_account_name
                                           ,'P\.O\.'
                                           ,'PO')
           ,cleanse_status = 'PASS'
        WHERE xx_cust_account_id = p_id
        AND regexp_like(p_account_name
                      ,'P\.O\.');
      
        UPDATE xxs3_otc_customer_accounts
        SET s3_account_name  = regexp_replace(p_account_name
                                           ,'A\.P\.|A/P'
                                           ,'AP')
           ,cleanse_status = 'PASS'
        WHERE xx_cust_account_id = p_id
        AND regexp_like(p_account_name
                      ,'A\.P\.|A/P');
      
        UPDATE xxs3_otc_customer_accounts
        SET s3_account_name  = regexp_replace(p_account_name
                                           ,'CO\.|Co\.'
                                           ,'Company')
           ,cleanse_status = 'PASS'
        WHERE xx_cust_account_id = p_id
        AND regexp_like(p_account_name
                      ,'CO\.|Co\.');
      
        UPDATE xxs3_otc_customer_accounts
        SET s3_account_name  = regexp_replace(p_account_name
                                           ,'A\.R\.|A/R'
                                           ,'AR')
           ,cleanse_status = 'PASS'
        WHERE xx_cust_account_id = p_id
        AND regexp_like(p_account_name
                      ,'A\.R\.|A/R');
      
      EXCEPTION
        WHEN OTHERS THEN
          l_error_msg := 'UNEXPECTED ERROR on Account Name update : ' ||
                         SQLCODE || '-' || SQLERRM;
          BEGIN
            UPDATE xxs3_otc_customer_accounts
            SET cleanse_status = 'FAIL'
               ,cleanse_error  = cleanse_error || '' || '' || l_error_msg
            WHERE xx_cust_account_id = p_id;
          EXCEPTION
            WHEN OTHERS THEN
              fnd_file.put_line(fnd_file.log
                               ,'Unexpected error during cleansing of party name for xx_cust_account_id = ' || p_id ||
                                chr(10) || SQLCODE || chr(10) || SQLERRM);
          END;
      END;
    END IF;
  
  END update_account_name;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: Generate Data Quality Report for Customer Account Uses
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0 26/04/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  PROCEDURE report_data_cus_acct_uses(p_entity VARCHAR2) IS
  
    l_delimiter VARCHAR2(5) := '~';
    l_err_msg   VARCHAR2(2000);
  
    CURSOR c_report_customer IS
      SELECT nvl(cd.rule_name, ' ') rule_name,
             nvl(cd.notes, ' ') notes,
             c.legacy_site_use_id legacy_site_use_id,
             cd.xx_cust_acct_site_use_id xx_cust_acct_site_use_id,
             (SELECT account_number
                FROM hz_cust_accounts hca
               WHERE c.cust_account_id = hca.cust_account_id) account_number,
             c.extract_dq_error,
             cd.dq_status,
             (SELECT legacy_party_site_number
                FROM xxs3_otc_cust_acct_sites a, xxs3_otc_party_sites b
               WHERE a.legacy_cust_account_site_id =
                     c.legacy_cust_acct_site_id
                 AND a.legacy_party_site_id = b.legacy_party_site_id) party_site_number,
             c.org_name,
             decode(c.process_flag, 'R', 'Y', 'Q', 'N') reject_record
        FROM xxobjt.xxs3_otc_cust_acct_site_uses  c,
             xxobjt.xxs3_otc_cus_act_site_uses_dq cd
       WHERE c.xx_cust_acct_site_use_id = cd.xx_cust_acct_site_use_id
         AND c.process_flag IN ('Q', 'R');
  
  BEGIN
    IF p_entity = 'CUSTOMER_SITE_USE'
    THEN
      fnd_file.put_line(fnd_file.output, rpad('Customer Account Site Uses DQ status report', 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('=============================', 100, ' '));
      fnd_file.put_line(fnd_file.output, '');
      fnd_file.put_line(fnd_file.output, 'Date:    ' ||
                         to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI'));
    
      fnd_file.put_line(fnd_file.output, '');
    
      fnd_file.put_line(fnd_file.output, rpad('Track Name', 10, ' ') ||
                         l_delimiter ||
                         rpad('Entity Name', 17, ' ') ||
                         l_delimiter ||
                         rpad('XX Cust Account Site Use ID ', 27, ' ') ||
                         l_delimiter ||
                         rpad('Legacy Cust Account Site Use ID', 31, ' ') ||
                         l_delimiter ||
                         rpad('Legacy Cust Account Number', 50, ' ') ||
                         l_delimiter ||
                         rpad('Org Name', 250, ' ') ||
                         l_delimiter ||
                         rpad('Party_Site_Number', 30, ' ') ||
                         l_delimiter ||
                         rpad(nvl('Dq_Status', 'NULL'), 2, ' ') ||
                         l_delimiter ||
                         rpad('Reject Record Flag(Y/N)', 22, ' ') ||                         
                         l_delimiter ||
                         rpad('Rule Name', 70, ' ') ||
                         l_delimiter ||                         
                         rpad('Reject Reason', 70, ' ')||
                         l_delimiter ||
                         rpad('Extract DQ Error', 100, ' '));
      FOR r_data IN c_report_customer
      LOOP
        fnd_file.put_line(fnd_file.output, rpad('OTC', 10, ' ') ||
                           l_delimiter ||
                           rpad('Customer Account Site Uses', 17, ' ') ||
                           l_delimiter ||
                           rpad(r_data.xx_cust_acct_site_use_id, 27, ' ') ||
                           l_delimiter ||
                           rpad(r_data.legacy_site_use_id, 31, ' ') ||
                           l_delimiter ||
                           rpad(r_data.account_number, 50, ' ') ||
                           l_delimiter ||
                           rpad(r_data.org_name, 250, ' ') ||
                           l_delimiter ||
                           rpad(r_data.party_site_number, 30, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.dq_status, 'NULL'), 2, ' ') ||
                           l_delimiter ||
                           rpad(r_data.reject_record, 22, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.rule_name, 'NULL'), 70, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.notes, 'NULL'), 70, ' ')||
                           l_delimiter ||
                           rpad(nvl(r_data.extract_dq_error, 'NULL'), 100, ' '));
      
      END LOOP;
      fnd_file.put_line(fnd_file.output, rpad('=============================', 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('End Of Report', 100, ' '));
    END IF;
  END report_data_cus_acct_uses;
  
   -- --------------------------------------------------------------------------------------------
  -- Purpose: Data cleanse Report
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0 6/01/2017  Debarati banerjee                  Initial build
  -----------------------------------------------------------------------------------------------
  
  PROCEDURE data_cleanse_report(p_entity IN VARCHAR2) IS

    CURSOR c_report_customer_account IS
       
         SELECT xx_cust_account_id,
		        legacy_account_number,    
				customer_class_code,
				s3_customer_class_code,
				payment_term_id,
				payment_term_value,
				s3_payment_term,
				account_name,
				s3_account_name,
				collector_name,
				s3_collector_name,
				collector_emp_number,
				s3_collector_emp_number,
				credit_checking,
				s3_credit_checking,
				payment_grace_days,
				s3_payment_grace_days,
				profile_class,
				s3_profile_class,
				tax_printing_option,
				s3_tax_printing_option,
				cleanse_status,
				cleanse_error
		FROM xxs3_otc_customer_accounts
        WHERE cleanse_status IN ('PASS', 'FAIL');
		
		CURSOR c_report_customer_site_use IS              
		 SELECT xoc.xx_cust_acct_site_use_id,
				xoc.cust_account_id,
				xoca.legacy_account_number,
				xoc.fob_point,
				xoc.s3_fob_point,
				xoc.freight_term,
				xoc.s3_freight_term,
				xoc.incoterm,
				xoc.s3_incoterm,
				xoc.primary_salesrep_name,
				xoc.s3_primary_salesrep_name,
				xoc.payment_term_id,
				xoc.payment_term,
				xoc.s3_payment_term,
				xoc.price_list_id,
				xoc.price_list_value,
				xoc.s3_price_list_value,
        xoc.cleanse_status,
				xoc.cleanse_error
         FROM xxs3_otc_cust_acct_site_uses xoc,xxs3_otc_customer_accounts xoca
		 WHERE xoc.cust_account_id=xoca.legacy_cust_account_id
		 AND xoc.cleanse_status IN ('PASS', 'FAIL');
		
   p_delimiter     VARCHAR2(5) := '~';
    l_err_msg       VARCHAR2(2000);
    l_count_success NUMBER;
    l_count_fail    NUMBER;		
BEGIN
	IF p_entity = 'CUSTOMER' THEN

      SELECT COUNT(1)
      INTO   l_count_success
      FROM   xxs3_otc_customer_accounts xci
      WHERE  xci.cleanse_status = 'PASS';

      SELECT COUNT(1)
      INTO   l_count_fail
      FROM   xxs3_otc_customer_accounts xci
      WHERE  xci.cleanse_status = 'FAIL';

      fnd_file.put_line(fnd_file.output, rpad('Report name = Automated Cleanse & Standardize Report' ||
                              p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('====================================================' ||
                              p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Data Migration Object Name = ' ||
                              p_entity || p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, '');
      fnd_file.put_line(fnd_file.output, rpad('Run date and time:    ' ||
                              to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') ||
                              p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Total Record Count Success = ' ||
                              l_count_success ||
                              p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Total Record Count Failure = ' ||
                              l_count_fail || p_delimiter, 100, ' '));

      fnd_file.put_line(fnd_file.output, '');

      fnd_file.put_line(fnd_file.output, rpad('Track Name', 10, ' ') ||
                         p_delimiter ||
                         rpad('Entity Name', 11, ' ') ||
                         p_delimiter ||
                         rpad('XX Cust Account ID  ', 14, ' ') ||
                         p_delimiter ||
                         rpad('Account Number', 10, ' ') ||
                         p_delimiter ||
                         rpad('CUSTOMER CLASS CODE', 100, ' ') ||
                         p_delimiter ||
                         rpad('S3 CUSTOMER CLASS CODE', 100, ' ') ||
                         p_delimiter ||
                         rpad('PAYMENT TERM ID', 50, ' ') ||
                         p_delimiter ||
                         rpad('PAYMENT TERM VALUE', 100, ' ') ||
                         p_delimiter ||
                         rpad('S3 PAYMENT TERM', 100, ' ') ||
                         p_delimiter ||
						 rpad('ACCOUNT_NAME', 100, ' ') ||
                         p_delimiter ||
						 rpad('S3 ACCOUNT_NAME', 100, ' ') ||
                         p_delimiter ||
						 rpad('COLLECTOR NAME', 100, ' ') ||
                         p_delimiter ||
						  rpad('S3 COLLECTOR_NAME', 100, ' ') ||
                         p_delimiter ||
						 rpad('COLLECTOR EMP NUMBER', 100, ' ') ||
                         p_delimiter ||
						 rpad('S3 COLLECTOR EMP NUMBER', 100, ' ') ||
                         p_delimiter ||
						 rpad('CREDIT CHECKING', 100, ' ') ||
                         p_delimiter ||
						  rpad('S3 CREDIT CHECKING', 100, ' ') ||
                         p_delimiter ||
						 rpad('PAYMENT GRACE DAYS', 100, ' ') ||
                         p_delimiter ||
						 rpad('S3 PAYMENT GRACE DAYS', 100, ' ') ||
                         p_delimiter ||
						 rpad('PROFILE CLASS', 100, ' ') ||
                         p_delimiter ||
						 rpad('S3 PROFILE CLASS', 100, ' ') ||
                         p_delimiter ||
						 rpad('TAX PRINTING OPTION', 100, ' ') ||
                         p_delimiter ||
						 rpad('S3 TAX PRINTING OPTION', 100, ' ') ||
                         p_delimiter ||
                         rpad('Status', 10, ' ') ||
                         p_delimiter ||
                         rpad('Error Message', 200, ' '));

     
      FOR r_data IN c_report_customer_account LOOP
        fnd_file.put_line(fnd_file.output, rpad('OTC', 10, ' ') ||
                           p_delimiter ||
                           rpad('CUSTOMER ACCOUNT', 11, ' ') ||
                           p_delimiter ||
                           rpad(r_data.xx_cust_account_id, 14, ' ') ||
                           p_delimiter ||
                           rpad(r_data.legacy_account_number, 10, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.customer_class_code,'NULL'), 100, ' ') ||
                           p_delimiter ||
                          rpad(nvl(r_data.s3_customer_class_code,'NULL'), 100, ' ') ||
                           p_delimiter ||
						   rpad(nvl(r_data.payment_term_id,'NULL'), 50, ' ') ||
                           p_delimiter ||
						   rpad(nvl(r_data.payment_term_value,'NULL'), 100, ' ') ||
                           p_delimiter ||
						   rpad(nvl(r_data.s3_payment_term,'NULL'), 100, ' ') ||
                           p_delimiter ||
						   rpad(nvl(r_data.account_name,'NULL'), 100, ' ') ||
                           p_delimiter ||
						   rpad(nvl(r_data.s3_account_name,'NULL'), 100, ' ') ||
                           p_delimiter ||
						    rpad(nvl(r_data.collector_name,'NULL'), 100, ' ') ||
                           p_delimiter ||
						    rpad(nvl(r_data.s3_collector_name,'NULL'), 100, ' ') ||
                           p_delimiter ||
						    rpad(nvl(r_data.collector_emp_number,'NULL'), 100, ' ') ||
                           p_delimiter ||
						    rpad(nvl(r_data.s3_collector_emp_number,'NULL'), 100, ' ') ||
                           p_delimiter ||
						    rpad(nvl(r_data.credit_checking,'NULL'), 100, ' ') ||
                           p_delimiter ||
						    rpad(nvl(r_data.s3_credit_checking,'NULL'), 100, ' ') ||
                           p_delimiter ||
						    rpad(nvl(r_data.payment_grace_days,'NULL'), 100, ' ') ||
                           p_delimiter ||
						    rpad(nvl(r_data.s3_payment_grace_days,'NULL'), 100, ' ') ||
                           p_delimiter ||
						    rpad(nvl(r_data.profile_class,'NULL'), 100, ' ') ||
                           p_delimiter ||
						   rpad(nvl(r_data.s3_profile_class,'NULL'), 100, ' ') ||
                           p_delimiter ||
						   rpad(nvl(r_data.tax_printing_option,'NULL'), 100, ' ') ||
                           p_delimiter ||
						    rpad(nvl(r_data.s3_tax_printing_option,'NULL'), 100, ' ') ||
                           p_delimiter ||				   
                           rpad(r_data.cleanse_status, 10, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.cleanse_error, 'NULL'), 200, ' '));

          END LOOP;

      fnd_file.put_line(fnd_file.output, '');
      fnd_file.put_line(fnd_file.output, 'Stratasys Confidential' ||
                         p_delimiter);
	ELSIF p_entity = 'CUSTOMER_SITE_USE' THEN
    	SELECT COUNT(1)
      INTO   l_count_success
      FROM   xxs3_otc_cust_acct_site_uses xci
      WHERE  xci.cleanse_status = 'PASS';

      SELECT COUNT(1)
      INTO   l_count_fail
      FROM   xxs3_otc_cust_acct_site_uses xci
      WHERE  xci.cleanse_status = 'FAIL';

      fnd_file.put_line(fnd_file.output, rpad('Report name = Automated Cleanse & Standardize Report' ||
                              p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('====================================================' ||
                              p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Data Migration Object Name = ' ||
                              p_entity || p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, '');
      fnd_file.put_line(fnd_file.output, rpad('Run date and time:    ' ||
                              to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') ||
                              p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Total Record Count Success = ' ||
                              l_count_success ||
                              p_delimiter, 100, ' '));
      fnd_file.put_line(fnd_file.output, rpad('Total Record Count Failure = ' ||
                              l_count_fail || p_delimiter, 100, ' '));

      fnd_file.put_line(fnd_file.output, '');

      fnd_file.put_line(fnd_file.output, rpad('Track Name', 10, ' ') ||
                         p_delimiter ||
                         rpad('Entity Name', 11, ' ') ||
                         p_delimiter ||
                         rpad('XX Cust Site Use ID  ', 14, ' ') ||
                         p_delimiter ||
						 rpad('Customer Account ID  ', 14, ' ') ||
                         p_delimiter ||
                         rpad('Account Number', 10, ' ') ||
                         p_delimiter ||
                         rpad('FOB_POINT', 100, ' ') ||
                         p_delimiter ||
                         rpad('S3 FOB POINT', 100, ' ') ||
                         p_delimiter ||
                         rpad('FREIGHT TERM', 50, ' ') ||
                         p_delimiter ||
                         rpad('S3 FREIGHT TERM', 100, ' ') ||
                         p_delimiter ||
                         rpad('INCOTERM', 100, ' ') ||
                         p_delimiter ||
						 rpad('S3 INCOTERM', 100, ' ') ||
                         p_delimiter ||
						 rpad('PRIMARY SALESREP NAME', 100, ' ') ||
                         p_delimiter ||
						 rpad('S3 PRIMARY SALESREP NAME', 100, ' ') ||
                         p_delimiter ||
						  rpad('PAYMENT TERM ID', 100, ' ') ||
                         p_delimiter ||
						 rpad('PAYMENT TERM', 100, ' ') ||
                         p_delimiter ||
						 rpad('S3 PAYMENT TERM', 100, ' ') ||
                         p_delimiter ||
						 rpad('PRICE LIST ID', 100, ' ') ||
                         p_delimiter ||
						  rpad('PRICE LIST VALUE', 100, ' ') ||
                         p_delimiter ||
						 rpad('S3 PRICE LIST VALUE', 100, ' ') ||
                         p_delimiter ||
						 rpad('Status', 10, ' ') ||
                         p_delimiter ||
                         rpad('Error Message', 200, ' '));

     
      FOR r_data IN c_report_customer_site_use LOOP
        fnd_file.put_line(fnd_file.output, rpad('OTC', 10, ' ') ||
                           p_delimiter ||
                           rpad('CUSTOMER SITE USE', 11, ' ') ||
                           p_delimiter ||
                           rpad(r_data.xx_cust_acct_site_use_id, 14, ' ') ||
                           p_delimiter ||
						   rpad(r_data.cust_account_id, 14, ' ') ||
                           p_delimiter ||
                           rpad(r_data.legacy_account_number, 10, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.fob_point,'NULL'), 100, ' ') ||
                           p_delimiter ||
                          rpad(nvl(r_data.s3_fob_point,'NULL'), 100, ' ') ||
                           p_delimiter ||
						   rpad(nvl(r_data.freight_term,'NULL'), 50, ' ') ||
                           p_delimiter ||
						   rpad(nvl(r_data.s3_freight_term,'NULL'), 100, ' ') ||
                           p_delimiter ||
						   rpad(nvl(r_data.incoterm,'NULL'), 100, ' ') ||
                           p_delimiter ||
						   rpad(nvl(r_data.s3_incoterm,'NULL'), 100, ' ') ||
                           p_delimiter ||
						   rpad(nvl(r_data.primary_salesrep_name,'NULL'), 100, ' ') ||
                           p_delimiter ||
						    rpad(nvl(r_data.s3_primary_salesrep_name,'NULL'), 100, ' ') ||
                           p_delimiter ||
						    rpad(nvl(r_data.payment_term_id,'NULL'), 100, ' ') ||
                           p_delimiter ||
						    rpad(nvl(r_data.payment_term,'NULL'), 100, ' ') ||
                           p_delimiter ||
						    rpad(nvl(r_data.s3_payment_term,'NULL'), 100, ' ') ||
                           p_delimiter ||
						    rpad(nvl(r_data.price_list_id,'NULL'), 100, ' ') ||
                           p_delimiter ||
						    rpad(nvl(r_data.price_list_value,'NULL'), 100, ' ') ||
                           p_delimiter ||
						    rpad(nvl(r_data.s3_price_list_value,'NULL'), 100, ' ') ||
                           p_delimiter ||   
                           rpad(r_data.cleanse_status, 10, ' ') ||
                           p_delimiter ||
                           rpad(nvl(r_data.cleanse_error, 'NULL'), 200, ' '));
	
	END LOOP;

      fnd_file.put_line(fnd_file.output, '');
      fnd_file.put_line(fnd_file.output, 'Stratasys Confidential' ||
                         p_delimiter);
    END IF;
	 END data_cleanse_report;
	

  --------------------------------------------------------------------
  --  name:              data_transform_report
  --  create by:       V.V.Sateesh  
  --  Revision:          1.0
  --  creation date:     26/08/2016
  --------------------------------------------------------------------
  --  purpose :          write data transform report to output
  --
  --------------------------------------------------------------------
  --  ver  date          name                   desc
  --  1.0  26/08/2016    V.V.Sateesh       report data transform
  --------------------------------------------------------------------

  PROCEDURE data_transform_report(p_entity VARCHAR2) IS
  
    l_delimiter     VARCHAR2(5) := '~';
    l_err_msg       VARCHAR2(2000);
    l_count_success NUMBER;
    l_count_fail    NUMBER;
  
    CURSOR c_report_cust IS
      SELECT xci.legacy_cust_account_id legacy_cust_account_id
            ,xci.legacy_account_number legacy_account_number
            ,xci.xx_cust_account_id s3_xx_cust_account_id
            ,xci.price_list_value legacy_price_list_value
            ,xci.s3_price_list s3_price_list
            ,xci.payment_term_value legacy_payment_term_value
            ,xci.s3_payment_term s3_payment_term
            ,xci.warehouse_value warehouse_value 
            ,xci.s3_warehouse s3_warehouse
            ,xci.fob_point legacy_fob_point
            ,xci.s3_fob_point s3_fob_point
            ,xci.freight_term legacy_freight_term 
            ,xci.s3_freight_term s3_freight_term
            ,xci.transform_status
            ,xci.transform_error
            ,p.legacy_party_number
      FROM xxobjt.xxs3_otc_customer_accounts xci,           
           xxobjt.xxs3_otc_parties p
      WHERE xci.transform_status IN ('PASS', 'FAIL')
      AND xci.party_id = p.legacy_party_id;
  
  
    CURSOR c_report_cust_site_use IS
      SELECT xcsu.legacy_site_use_id legacy_site_use_id
            ,xcsu.legacy_cust_acct_site_id legacy_cust_acct_site_id
            ,xcsu.cust_account_id cust_account_id
            ,(SELECT account_number
              FROM hz_cust_accounts hca
              WHERE xcsu.cust_account_id = hca.cust_account_id) account_number
            ,xcsu.payment_term payment_term
            ,xcsu.s3_payment_term s3_payment_term
            ,xcsu.price_list_value price_list_value
            ,xcsu.s3_price_list_value s3_price_list_value
            ,xcsu.warehouse_code warehouse_code
            ,xcsu.s3_warehouse_code s3_warehouse_code
            ,xcsu.incoterm incoterm
            ,xcsu.s3_incoterm s3_incoterm
            ,xcsu.freight_term freight_term
            ,xcsu.s3_freight_term s3_freight_term
            ,xcsu.fob_point fob_point
            ,xcsu.s3_fob_point s3_fob_point
            ,xcsu.org_name org_name
            ,xcsu.s3_org_name s3_org_name
            ,gl_id_rec_seg1
            ,gl_id_rec_seg2
            ,gl_id_rec_seg3
            ,gl_id_rec_seg4
            ,gl_id_rec_seg5
            ,gl_id_rec_seg6
            ,gl_id_rec_seg7
            ,gl_id_rec_seg9
            ,gl_id_rec_seg10
            ,s3_gl_id_rec_seg1
            ,s3_gl_id_rec_seg2
            ,s3_gl_id_rec_seg3
            ,s3_gl_id_rec_seg4
            ,s3_gl_id_rec_seg5
            ,s3_gl_id_rec_seg6
            ,s3_gl_id_rec_seg7
            ,s3_gl_id_rec_seg8
            ,gl_id_rev_seg1
            ,gl_id_rev_seg2
            ,gl_id_rev_seg3
            ,gl_id_rev_seg4
            ,gl_id_rev_seg5
            ,gl_id_rev_seg6
            ,gl_id_rev_seg7
            ,gl_id_rev_seg9
            ,gl_id_rev_seg10
            ,s3_gl_id_rev_seg1
            ,s3_gl_id_rev_seg2
            ,s3_gl_id_rev_seg3
            ,s3_gl_id_rev_seg4
            ,s3_gl_id_rev_seg5
            ,s3_gl_id_rev_seg6
            ,s3_gl_id_rev_seg7
            ,s3_gl_id_rev_seg8
            ,gl_id_unearned_seg1
            ,gl_id_unearned_seg2
            ,gl_id_unearned_seg3
            ,gl_id_unearned_seg4
            ,gl_id_unearned_seg5
            ,gl_id_unearned_seg6
            ,gl_id_unearned_seg7
            ,gl_id_unearned_seg9
            ,gl_id_unearned_seg10
            ,s3_gl_id_unearned_seg1
            ,s3_gl_id_unearned_seg2
            ,s3_gl_id_unearned_seg3
            ,s3_gl_id_unearned_seg4
            ,s3_gl_id_unearned_seg5
            ,s3_gl_id_unearned_seg6
            ,s3_gl_id_unearned_seg7
            ,s3_gl_id_unearned_seg8
            ,gl_id_freight_seg1
            ,gl_id_freight_seg2
            ,gl_id_freight_seg3
            ,gl_id_freight_seg4
            ,gl_id_freight_seg5
            ,gl_id_freight_seg6
            ,gl_id_freight_seg7
            ,gl_id_freight_seg9
            ,gl_id_freight_seg10
            ,s3_gl_id_freight_seg1
            ,s3_gl_id_freight_seg2
            ,s3_gl_id_freight_seg3
            ,s3_gl_id_freight_seg4
            ,s3_gl_id_freight_seg5
            ,s3_gl_id_freight_seg6
            ,s3_gl_id_freight_seg7
            ,s3_gl_id_freight_seg8
            ,xcsu.transform_status
            ,xcsu.transform_error
      FROM xxobjt.xxs3_otc_cust_acct_site_uses xcsu
      WHERE xcsu.transform_status IN ('PASS', 'FAIL');
  
    CURSOR c_report_cust_site IS
      SELECT xcs.legacy_cust_account_site_id legacy_cust_account_site_id
            ,xcs.legacy_cust_account_id legacy_cust_account_id
            ,xcs.org_name org_name
            ,xcs.s3_org_name s3_org_name
            ,(SELECT account_number
              FROM hz_cust_accounts hca
              WHERE xcs.legacy_cust_account_id = hca.cust_account_id) account_number
            ,xcs.transform_status
            ,xcs.transform_error
            ,(SELECT legacy_party_site_number FROM xxs3_otc_party_sites
             WHERE legacy_party_site_id = xcs.legacy_party_site_id) party_site_number
      FROM xxobjt.xxs3_otc_cust_acct_sites xcs
      WHERE xcs.transform_status IN ('PASS', 'FAIL');
  
  BEGIN
  
    IF p_entity = 'CUSTOMER'
    THEN
    
      SELECT COUNT(1)
      INTO l_count_success
      FROM xxobjt.xxs3_otc_customer_accounts xci
      WHERE xci.transform_status = 'PASS';
    
      SELECT COUNT(1)
      INTO l_count_fail
      FROM xxobjt.xxs3_otc_customer_accounts xci
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
                         rpad('LEGACY_CUST_ACCOUNT_ID  ', 30, ' ') ||
                         l_delimiter ||
                         rpad('LEGACY_ACCOUNT_NUMBER', 30, ' ') ||
                         l_delimiter ||
                         rpad('LEGACY_PARTY_NUMBER', 30, ' ') ||
                         l_delimiter ||
                         rpad('LEGACY_PRICE_LIST_VALUE', 30, ' ') ||
                         l_delimiter ||
                         rpad('S3_PRICE_LIST', 30, ' ') ||
                         l_delimiter ||
                         rpad('LEGACY_PAYMENT_TERM_VALUE', 50, ' ') ||
                         l_delimiter ||
                         rpad('S3_PAYMENT_TERM', 50, ' ') ||
                         l_delimiter ||
                         rpad('WAREHOUSE_VALUE', 50, ' ') || 
                         l_delimiter ||
                         rpad('S3_WAREHOUSE', 50, ' ') ||
                         l_delimiter ||
                         rpad('LEGACY_FOB_POINT', 50, ' ') ||
                         l_delimiter ||
                         rpad('S3_FOB_POINT', 50, ' ') ||
                         l_delimiter ||
                         rpad('LEGACY_FREIGHT_TERM', 50, ' ') ||
                         l_delimiter ||
                         rpad('S3_FREIGHT_TERM', 50, ' ') ||
                         l_delimiter ||
                         rpad('Status', 10, ' ') ||
                         l_delimiter ||
                         rpad('Error Message', 200, ' '));
    
    
      FOR r_data IN c_report_cust
      LOOP
        fnd_file.put_line(fnd_file.output, rpad('OTC', 10, ' ') ||
                           l_delimiter ||
                           rpad('CUSTOMER', 15, ' ') ||
                           l_delimiter ||
                           rpad(r_data.legacy_cust_account_id, 30, ' ') ||
                           l_delimiter ||
                           rpad(r_data.legacy_account_number, 30, ' ') ||
                           l_delimiter ||
                           rpad(r_data.legacy_party_number, 30, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.legacy_price_list_value, 'NULL'), 30, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_price_list, 'NULL'), 30, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.legacy_payment_term_value, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_payment_term, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.warehouse_value, 'NULL'), 50, ' ') || 
                           l_delimiter ||
                           rpad(nvl(r_data.s3_warehouse, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.legacy_fob_point, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_fob_point, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.legacy_freight_term, 'NULL'), 50, ' ') || 
                           l_delimiter ||
                           rpad(nvl(r_data.s3_freight_term, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(r_data.transform_status, 10, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.transform_error, 'NULL'), 200, ' '));
      END LOOP;
    
      fnd_file.put_line(fnd_file.output, '');
      fnd_file.put_line(fnd_file.output, 'Stratasys Confidential' ||
                         l_delimiter);
    
    ELSIF p_entity = 'CUSTOMER_SITE_USE'
    THEN
    
      SELECT COUNT(1)
      INTO l_count_success
      FROM xxobjt.xxs3_otc_cust_acct_site_uses xci
      WHERE xci.transform_status = 'PASS';
    
      SELECT COUNT(1)
      INTO l_count_fail
      FROM xxobjt.xxs3_otc_cust_acct_site_uses xci
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
                         rpad('LEGACY_SITE_USE_ID  ', 14, ' ') ||
                         l_delimiter ||
                         rpad('LEGACY_CUST_ACCT_SITE_ID', 30, ' ') ||
                         l_delimiter ||
                         rpad('CUST_ACCOUNT_ID', 30, ' ') ||
                         l_delimiter ||
                         rpad('CUST ACCOUNT NUMBER', 50, ' ') ||
                         l_delimiter ||
                         rpad('ORG_NAME', 30, ' ') ||
                         l_delimiter ||
                         rpad('S3_ORG_NAME', 30, ' ') ||
                         l_delimiter ||
                         rpad('PRICE_LIST_VALUE', 30, ' ') ||
                         l_delimiter ||
                         rpad('S3_PRICE_LIST_VALUE', 30, ' ') ||
                         l_delimiter ||
                         rpad('PAYMENT_TERM', 50, ' ') ||
                         l_delimiter ||
                         rpad('S3_PAYMENT_TERM', 50, ' ') ||
                         l_delimiter ||
                         rpad('WAREHOUSE_CODE', 50, ' ') ||
                         l_delimiter ||
                         rpad('S3_WAREHOUSE_CODE', 50, ' ') ||
                         l_delimiter ||
                         rpad('FOB_POINT', 50, ' ') ||
                         l_delimiter ||
                         rpad('S3_FOB_POINT', 50, ' ') ||
                         l_delimiter ||
                         rpad('FREIGHT_TERM', 50, ' ') ||
                         l_delimiter ||
                         rpad('S3_FREIGHT_TERM', 50, ' ') ||
                         l_delimiter ||
                         rpad('INCOTERM', 50, ' ') ||
                         l_delimiter ||
                         rpad('S3_INCOTERM', 50, ' ') ||
                         l_delimiter ||
                         rpad('GL_ID_REC_SEG1', 50, ' ') ||
                         l_delimiter ||
                         rpad('GL_ID_REC_SEG2', 50, ' ') ||
                         l_delimiter ||
                         rpad('GL_ID_REC_SEG3', 50, ' ') ||
                         l_delimiter ||
                         rpad('GL_ID_REC_SEG4', 50, ' ') ||
                         l_delimiter ||
                         rpad('GL_ID_REC_SEG5', 50, ' ') ||
                         l_delimiter ||
                         rpad('GL_ID_REC_SEG6', 50, ' ') ||
                         l_delimiter ||
                         rpad('GL_ID_REC_SEG7', 50, ' ') ||
                         l_delimiter ||
                         rpad('GL_ID_REC_SEG9', 50, ' ') ||
                         l_delimiter ||
                         rpad('GL_ID_REC_SEG10', 50, ' ') ||
                         l_delimiter ||
                         rpad('S3_GL_ID_REC_SEG1', 50, ' ') ||
                         l_delimiter ||
                         rpad('S3_GL_ID_REC_SEG2', 50, ' ') ||
                         l_delimiter ||
                         rpad('S3_GL_ID_REC_SEG3', 50, ' ') ||
                         l_delimiter ||
                         rpad('S3_GL_ID_REC_SEG4', 50, ' ') ||
                         l_delimiter ||
                         rpad('S3_GL_ID_REC_SEG5', 50, ' ') ||
                         l_delimiter ||
                         rpad('S3_GL_ID_REC_SEG6', 50, ' ') ||
                         l_delimiter ||
                         rpad('S3_GL_ID_REC_SEG7', 50, ' ') ||
                         l_delimiter ||
                         rpad('S3_GL_ID_REC_SEG8', 50, ' ') ||
                         l_delimiter ||
                         rpad('GL_ID_REV_SEG1', 50, ' ') ||
                         l_delimiter ||
                         rpad('GL_ID_REV_SEG2', 50, ' ') ||
                         l_delimiter ||
                         rpad('GL_ID_REV_SEG3', 50, ' ') ||
                         l_delimiter ||
                         rpad('GL_ID_REV_SEG4', 50, ' ') ||
                         l_delimiter ||
                         rpad('GL_ID_REV_SEG5', 50, ' ') ||
                         l_delimiter ||
                         rpad('GL_ID_REV_SEG6', 50, ' ') ||
                         l_delimiter ||
                         rpad('GL_ID_REV_SEG7', 50, ' ') ||
                         l_delimiter ||
                         rpad('GL_ID_REV_SEG9', 50, ' ') ||
                         l_delimiter ||
                         rpad('GL_ID_REV_SEG10', 50, ' ') ||
                         l_delimiter ||
                         rpad('S3_GL_ID_REV_SEG1', 50, ' ') ||
                         l_delimiter ||
                         rpad('S3_GL_ID_REV_SEG2', 50, ' ') ||
                         l_delimiter ||
                         rpad('S3_GL_ID_REV_SEG3', 50, ' ') ||
                         l_delimiter ||
                         rpad('S3_GL_ID_REV_SEG4', 50, ' ') ||
                         l_delimiter ||
                         rpad('S3_GL_ID_REV_SEG5', 50, ' ') ||
                         l_delimiter ||
                         rpad('S3_GL_ID_REV_SEG6', 50, ' ') ||
                         l_delimiter ||
                         rpad('S3_GL_ID_REV_SEG7', 50, ' ') ||
                         l_delimiter ||
                         rpad('S3_GL_ID_REV_SEG8', 50, ' ') ||
                         l_delimiter ||
                         rpad('GL_ID_UNEARNED_SEG1', 50, ' ') ||
                         l_delimiter ||
                         rpad('GL_ID_UNEARNED_SEG2', 50, ' ') ||
                         l_delimiter ||
                         rpad('GL_ID_UNEARNED_SEG3', 50, ' ') ||
                         l_delimiter ||
                         rpad('GL_ID_UNEARNED_SEG4', 50, ' ') ||
                         l_delimiter ||
                         rpad('GL_ID_UNEARNED_SEG5', 50, ' ') ||
                         l_delimiter ||
                         rpad('GL_ID_UNEARNED_SEG6', 50, ' ') ||
                         l_delimiter ||
                         rpad('GL_ID_UNEARNED_SEG7', 50, ' ') ||
                         l_delimiter ||
                         rpad('GL_ID_UNEARNED_SEG9', 50, ' ') ||
                         l_delimiter ||
                         rpad('GL_ID_UNEARNED_SEG10', 50, ' ') ||
                         l_delimiter ||
                         rpad('S3_GL_ID_UNEARNED_SEG1', 50, ' ') ||
                         l_delimiter ||
                         rpad('S3_GL_ID_UNEARNED_SEG2', 50, ' ') ||
                         l_delimiter ||
                         rpad('S3_GL_ID_UNEARNED_SEG3', 50, ' ') ||
                         l_delimiter ||
                         rpad('S3_GL_ID_UNEARNED_SEG4', 50, ' ') ||
                         l_delimiter ||
                         rpad('S3_GL_ID_UNEARNED_SEG5', 50, ' ') ||
                         l_delimiter ||
                         rpad('S3_GL_ID_UNEARNED_SEG6', 50, ' ') ||
                         l_delimiter ||
                         rpad('S3_GL_ID_UNEARNED_SEG7', 50, ' ') ||
                         l_delimiter ||
                         rpad('S3_GL_ID_UNEARNED_SEG8', 50, ' ') ||
                         l_delimiter ||
                         rpad('GL_ID_FREIGHT_SEG1', 50, ' ') ||
                         l_delimiter ||
                         rpad('GL_ID_FREIGHT_SEG2', 50, ' ') ||
                         l_delimiter ||
                         rpad('GL_ID_FREIGHT_SEG3', 50, ' ') ||
                         l_delimiter ||
                         rpad('GL_ID_FREIGHT_SEG4', 50, ' ') ||
                         l_delimiter ||
                         rpad('GL_ID_FREIGHT_SEG5', 50, ' ') ||
                         l_delimiter ||
                         rpad('GL_ID_FREIGHT_SEG6', 50, ' ') ||
                         l_delimiter ||
                         rpad('GL_ID_FREIGHT_SEG7', 50, ' ') ||
                         l_delimiter ||
                         rpad('GL_ID_FREIGHT_SEG9', 50, ' ') ||
                         l_delimiter ||
                         rpad('GL_ID_FREIGHT_SEG10', 50, ' ') ||
                         l_delimiter ||
                         rpad('S3_GL_ID_FREIGHT_SEG1', 50, ' ') ||
                         l_delimiter ||
                         rpad('S3_GL_ID_FREIGHT_SEG2', 50, ' ') ||
                         l_delimiter ||
                         rpad('S3_GL_ID_FREIGHT_SEG3', 50, ' ') ||
                         l_delimiter ||
                         rpad('S3_GL_ID_FREIGHT_SEG4', 50, ' ') ||
                         l_delimiter ||
                         rpad('S3_GL_ID_FREIGHT_SEG5', 50, ' ') ||
                         l_delimiter ||
                         rpad('S3_GL_ID_FREIGHT_SEG6', 50, ' ') ||
                         l_delimiter ||
                         rpad('S3_GL_ID_FREIGHT_SEG7', 50, ' ') ||
                         l_delimiter ||
                         rpad('S3_GL_ID_FREIGHT_SEG8', 50, ' ') ||
                         l_delimiter ||
                         rpad('Status', 10, ' ') ||
                         l_delimiter ||
                         rpad('Error Message', 200, ' '));
    
    
      FOR r_data IN c_report_cust_site_use
      LOOP
        fnd_file.put_line(fnd_file.output, rpad('OTC', 10, ' ') ||
                           l_delimiter ||
                           rpad('CUSTOMER_SITE_USE', 15, ' ') ||
                           l_delimiter ||
                           rpad(r_data.legacy_site_use_id, 14, ' ') ||
                           l_delimiter ||
                           rpad(r_data.legacy_cust_acct_site_id, 30, ' ') ||
                           l_delimiter ||
                           rpad(r_data.cust_account_id, 30, ' ') ||
                           l_delimiter ||
                           rpad(r_data.account_number, 50, ' ') ||
                           l_delimiter ||
                           rpad(r_data.org_name, 30, ' ') ||
                           l_delimiter ||
                           rpad(r_data.s3_org_name, 30, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.price_list_value, 'NULL'), 30, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_price_list_value, 'NULL'), 30, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.payment_term, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_payment_term, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.warehouse_code, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_warehouse_code, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.fob_point, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_fob_point, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.freight_term, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_freight_term, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.incoterm, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_incoterm, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.gl_id_rec_seg1, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.gl_id_rec_seg2, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.gl_id_rec_seg3, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.gl_id_rec_seg4, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.gl_id_rec_seg5, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.gl_id_rec_seg6, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.gl_id_rec_seg7, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.gl_id_rec_seg9, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.gl_id_rec_seg10, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_gl_id_rec_seg1, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_gl_id_rec_seg2, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_gl_id_rec_seg3, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_gl_id_rec_seg4, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_gl_id_rec_seg5, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_gl_id_rec_seg6, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_gl_id_rec_seg7, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_gl_id_rec_seg8, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.gl_id_rev_seg1, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.gl_id_rev_seg2, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.gl_id_rev_seg3, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.gl_id_rev_seg4, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.gl_id_rev_seg5, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.gl_id_rev_seg6, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.gl_id_rev_seg7, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.gl_id_rev_seg9, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.gl_id_rev_seg10, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_gl_id_rev_seg1, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_gl_id_rev_seg2, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_gl_id_rev_seg3, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_gl_id_rev_seg4, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_gl_id_rev_seg5, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_gl_id_rev_seg6, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_gl_id_rev_seg7, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_gl_id_rev_seg8, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.gl_id_unearned_seg1, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.gl_id_unearned_seg2, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.gl_id_unearned_seg3, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.gl_id_unearned_seg4, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.gl_id_unearned_seg5, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.gl_id_unearned_seg6, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.gl_id_unearned_seg7, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.gl_id_unearned_seg9, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.gl_id_unearned_seg10, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_gl_id_unearned_seg1, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_gl_id_unearned_seg2, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_gl_id_unearned_seg3, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_gl_id_unearned_seg4, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_gl_id_unearned_seg5, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_gl_id_unearned_seg6, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_gl_id_unearned_seg7, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_gl_id_unearned_seg8, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.gl_id_freight_seg1, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.gl_id_freight_seg2, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.gl_id_freight_seg3, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.gl_id_freight_seg4, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.gl_id_freight_seg5, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.gl_id_freight_seg6, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.gl_id_freight_seg7, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.gl_id_freight_seg9, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.gl_id_freight_seg10, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_gl_id_freight_seg1, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_gl_id_freight_seg2, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_gl_id_freight_seg3, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_gl_id_freight_seg4, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_gl_id_freight_seg5, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_gl_id_freight_seg6, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_gl_id_freight_seg7, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_gl_id_freight_seg8, 'NULL'), 50, ' ') ||
                           l_delimiter ||
                           rpad(r_data.transform_status, 10, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.transform_error, 'NULL'), 200, ' '));
      END LOOP;
    
      fnd_file.put_line(fnd_file.output, '');
      fnd_file.put_line(fnd_file.output, 'Stratasys Confidential' ||
                         l_delimiter);
    
    ELSIF p_entity = 'CUSTOMER_SITE'
    THEN
    
      SELECT COUNT(1)
      INTO l_count_success
      FROM xxobjt.xxs3_otc_cust_acct_sites xci
      WHERE xci.transform_status = 'PASS';
    
      SELECT COUNT(1)
      INTO l_count_fail
      FROM xxobjt.xxs3_otc_cust_acct_sites xci
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
                         rpad('LEGACY_CUST_ACCOUNT_SITE_ID  ', 14, ' ') ||
                         l_delimiter ||
                         rpad('LEGACY_CUST_ACCOUNT_ID', 30, ' ') ||
                         l_delimiter ||
                         rpad('ORG_NAME', 240, ' ') ||
                         l_delimiter ||
                         rpad('S3_ORG_NAME', 240, ' ') ||
                         l_delimiter ||
                         rpad('Account_Number', 30, ' ') ||
                         l_delimiter ||
                         rpad('Party_Site_Number', 30, ' ') ||
                         l_delimiter ||
                         rpad('Status', 10, ' ') ||
                         l_delimiter ||
                         rpad('Error Message', 200, ' '));
    
    
      FOR r_data IN c_report_cust_site
      LOOP
        fnd_file.put_line(fnd_file.output, rpad('OTC', 10, ' ') ||
                           l_delimiter ||
                           rpad('CUSTOMER_SITE', 15, ' ') ||
                           l_delimiter ||
                           rpad(r_data.legacy_cust_account_site_id, 14, ' ') ||
                           l_delimiter ||
                           rpad(r_data.legacy_cust_account_id, 30, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.org_name, '240'), 30, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.s3_org_name, '240'), 30, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.account_number, 'NULL'), 30, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.party_site_number, 'NULL'), 30, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.transform_status, 'NULL'), 10, ' ') ||
                           l_delimiter ||
                           rpad(nvl(r_data.transform_error, 'NULL'), 200, ' '));
      END LOOP;
    
      fnd_file.put_line(fnd_file.output, '');
      fnd_file.put_line(fnd_file.output, 'Stratasys Confidential' ||
                         l_delimiter);
    
    
    END IF;
  END data_transform_report;
  
   --- --------------------------------------------------------------------------------------------
  -- Purpose: Autocleanse activity for customer site use
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  01/08/2016  Debarati Banerjee            Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE cleanse_customer_site_use IS
  
   --EQT 263
    CURSOR c_prc_list(p_cust_account_id IN NUMBER) IS
      SELECT hca.account_number,
             hca.cust_account_id,
             hca.sales_channel_code,
             ca.class_code
      FROM   hz_parties          hp,
             hz_code_assignments ca,
             hz_cust_accounts    hca
      WHERE  hp.party_id = ca.owner_table_id(+)
            --AND    ca.class_code = 'Education'
      AND    SYSDATE BETWEEN ca.start_date_active AND
             nvl(ca.end_date_active, SYSDATE)
      AND    hca.party_id = hp.party_id
      AND    hca.cust_account_id = p_cust_account_id
      AND    ca.class_category =  'Objet Business Type';
    --EQT 263
    --EQT 197

    l_error_msg VARCHAR2(4000);
    l_step VARCHAR2(200) ;
    l_count NUMBER := 0;

  BEGIN
  
  --EQT-207   
   l_step := 'cleanse fob'; 
   
    UPDATE xxs3_otc_cust_acct_site_uses
       SET s3_fob_point = NULL, cleanse_status = 'PASS'
     WHERE org_id = g_org_id
       AND extract_rule_name IS NOT NULL;       
    
   --EQT-207
   
   --EQT-208    
    l_step := 'cleanse freight';
    
    UPDATE xxs3_otc_cust_acct_site_uses
       SET s3_freight_term = NULL,cleanse_status = 'PASS'
     WHERE org_id = g_org_id
       AND extract_rule_name IS NOT NULL;
   --EQT-208    
   --EQT-209
     l_step := 'cleanse incoterm';
    
    UPDATE xxs3_otc_cust_acct_site_uses
       SET s3_incoterm = NULL,cleanse_status = 'PASS'
     WHERE org_id = g_org_id
       AND extract_rule_name IS NOT NULL;
    --EQT-209  
    
    --EQT-210     
      l_step := 'cleanse salesrep';
      
    UPDATE xxs3_otc_cust_acct_site_uses
       SET s3_primary_salesrep_name = 'No Sales Credit'
     WHERE org_id = g_org_id
       AND extract_rule_name IS NOT NULL
       AND primary_salesrep_id IS NOT NULL;
       
   UPDATE xxs3_otc_cust_acct_site_uses
       SET s3_primary_salesrep_name = primary_salesrep_name
     WHERE org_id <> g_org_id
       AND extract_rule_name IS NOT NULL
       AND primary_salesrep_id IS NOT NULL;
    --EQT-210 
    
    --
     --EQT 263
    FOR r_price_list IN (SELECT xoca.cust_account_id
                         FROM   xxs3_otc_cust_acct_site_uses xoca
                         WHERE extract_rule_name IS NOT NULL) LOOP
    
      IF xxs3_otc_customer_pkg.get_site_count(r_price_list.cust_account_id) = 'Y' THEN
      
        FOR r_prc_list IN c_prc_list(r_price_list.cust_account_id) LOOP
        
          IF r_prc_list.sales_channel_code = 'Direct' AND
             r_prc_list.class_code = 'Education' THEN
          
            /*UPDATE xxs3_otc_customer_accounts xoca
            SET    xoca.s3_price_list = 'US Direct $-EDU'
            WHERE  xoca.legacy_cust_account_id = r_prc_list.cust_account_id;*/
          
            UPDATE xxs3_otc_cust_acct_site_uses xocasu
            SET    xocasu.price_list_value = 'US Direct $-EDU'
            WHERE  xocasu.cust_account_id = r_prc_list.cust_account_id;
          
          ELSIF r_prc_list.sales_channel_code = 'Direct' AND
                r_prc_list.class_code <> 'Education' THEN
          
            /*UPDATE xxs3_otc_customer_accounts xoca
            SET    xoca.s3_price_list = 'US Direct $' || '''' || ' EDU'
            WHERE  xoca.legacy_cust_account_id = r_prc_list.cust_account_id;*/
          
            UPDATE xxs3_otc_cust_acct_site_uses xocasu
            SET    xocasu.price_list_value = 'US Direct $EDU'
            WHERE  xocasu.cust_account_id = r_prc_list.cust_account_id;
          
          END IF;
        END LOOP;
     END IF;
    END LOOP;
        --EQT 263
    --EQT 197
        UPDATE xxs3_otc_cust_acct_site_uses xocasu
           SET xocasu.payment_term = (SELECT NAME
                                           FROM ra_terms             rt,
                                                hz_customer_profiles cp,
                                                hz_cust_accounts      ca
                                          WHERE rt.term_id = cp.standard_terms
                                            AND ca.cust_account_id =
                                                cp.cust_account_id
                                            AND ca.cust_account_id =
                                                xocasu.cust_account_id
                                            AND cp.site_use_id IS NULL)
         WHERE extract_rule_name IS NOT NULL
           AND xocasu.payment_term_id IS NULL
           AND xocasu.org_id = g_org_id;
   --EQT 197
  
 /*   --
 
    l_step := 'cleanse payment_term';
    
    UPDATE xxs3_otc_cust_acct_site_uses
       SET S3_PAYMENT_TERM = 'Net 30 Days',cleanse_status = 'PASS'
     WHERE org_id = g_org_id
       AND extract_rule_name IS NOT NULL;*/

 
UPDATE xxs3_otc_cust_acct_site_uses xocs
   SET xocs.gl_id_rec_seg3      = '112110',
       xocs.gl_id_rev_seg3      = '401110',
       xocs.gl_id_unearned_seg3 = '251300',
       xocs.gl_id_freight_seg3  = '401910',
       CLEANSE_STATUS ='PASS'
 WHERE EXISTS
 (SELECT xocsu.legacy_cust_acct_site_id
          FROM xxs3_otc_cust_acct_site_uses xocsu, hz_cust_accounts hca
         WHERE xocsu.cust_account_id = hca.cust_account_id
           AND hca.customer_type = 'I'
           AND xocsu.legacy_cust_acct_site_id =
               xocs.legacy_cust_acct_site_id)
   AND extract_rule_name IS NOT NULL;
   
   UPDATE xxs3_otc_cust_acct_site_uses xocs
   SET xocs.gl_id_rec_seg3      = NULL,
       xocs.gl_id_rev_seg3      = NULL,
       xocs.gl_id_unearned_seg3 = NULL,
       xocs.gl_id_freight_seg3  = NULL,
       CLEANSE_STATUS ='PASS'
 WHERE extract_rule_name IS NOT NULL
  AND NOT EXISTS
 (SELECT xocsu.legacy_cust_acct_site_id
          FROM xxs3_otc_cust_acct_site_uses xocsu, hz_cust_accounts hca
         WHERE xocsu.cust_account_id = hca.cust_account_id
           AND hca.customer_type = 'I'
           AND xocsu.legacy_cust_acct_site_id =
               xocs.legacy_cust_acct_site_id);
               
   
     l_step := 'cleanse GL_ID_TAX';  
               
  UPDATE xxs3_otc_cust_acct_site_uses
     SET gl_id_tax       = NULL,
         gl_id_tax_seg1  = NULL,
         gl_id_tax_seg2  = NULL,
         gl_id_tax_seg3  = NULL,
         gl_id_tax_seg4  = NULL,
         gl_id_tax_seg5  = NULL,
         gl_id_tax_seg6  = NULL,
         gl_id_tax_seg7  = NULL,
         gl_id_tax_seg10 = NULL,
         gl_id_tax_seg9  = NULL,
         cleanse_status  = 'PASS'
   WHERE extract_rule_name IS NOT NULL;   
  
   
   l_step := 'cleanse GL_ID_UNBILLED';  
               
  UPDATE xxs3_otc_cust_acct_site_uses
     SET gl_id_unbilled       = NULL,
         gl_id_unbilled_seg1  = NULL,
         gl_id_unbilled_seg2  = NULL,
         gl_id_unbilled_seg3  = NULL,
         gl_id_unbilled_seg4  = NULL,
         gl_id_unbilled_seg5  = NULL,
         gl_id_unbilled_seg6  = NULL,
         gl_id_unbilled_seg7  = NULL,
         gl_id_unbilled_seg10 = NULL,
         gl_id_unbilled_seg9  = NULL,
         cleanse_status       = 'PASS'
   WHERE extract_rule_name IS NOT NULL;
   
   COMMIT;
               
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log, 'Unexpected error during auto cleanse : ' ||
                               chr(10) || SQLCODE || chr(10) ||
                               SQLERRM);

      
  END cleanse_customer_site_use;
  
  ---------------------------------------------------------------------------------------------
   -- Purpose: This procedure will cleanse customer account extract
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0 29/12/2016  Debarati Banerjee             Initial build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE cleanse_customer_account IS
  
    l_site_count NUMBER;
  
    --EQT 185                                    
    CURSOR c_cust_code IS
      SELECT DISTINCT xoca.legacy_cust_account_id cust_account_id,
                      xoca.customer_type,
                      xoca.customer_class_code,
                      xoca.sales_channel_code
      FROM   xxs3_otc_cust_acct_sites     hcas,
             hz_cust_site_uses_all      hcsa,
             xxs3_otc_customer_accounts xoca
      WHERE  xoca.legacy_cust_account_id = hcas.legacy_cust_account_id
      AND    hcas.legacy_cust_account_site_id = hcsa.cust_acct_site_id
      AND    hcsa.org_id = g_org_id
      AND    hcsa.site_use_code = 'BILL_TO'
      AND xoca.extract_rule_name IS NOT NULL
      AND hcas.extract_rule_name IS NOT NULL;
    --EQT 185
  
  BEGIN
  
    --EQT 185
    FOR r_cust_code IN c_cust_code LOOP
    
      BEGIN
      
        SELECT COUNT(*)
        INTO   l_site_count
        FROM   hz_cust_accounts       hca,
               xxs3_otc_cust_acct_sites hcas,
               hz_cust_site_uses_all  hcsa,
               hz_party_site_uses     hpsu
        WHERE  hca.cust_account_id = r_cust_code.cust_account_id
        AND    hca.cust_account_id = hcas.legacy_cust_account_id
        AND    hcas.legacy_cust_account_site_id = hcsa.cust_acct_site_id
        AND    hcsa.org_id = g_org_id
        AND    hcsa.site_use_code = 'BILL_TO'
        AND    hcas.legacy_party_site_id = hpsu.party_site_id
        AND    hpsu.site_use_type = 'INSTALL_AT'
        AND    hcas.extract_rule_name IS NOT NULL;
        
      EXCEPTION
        WHEN OTHERS THEN
          l_site_count := -999;
        
      END;
    
      IF r_cust_code.customer_type = 'I' THEN
      
        UPDATE xxs3_otc_customer_accounts xoca
        SET    xoca.s3_customer_class_code = 'Intercompany',
        cleanse_status = 'PASS'
        WHERE  xoca.legacy_cust_account_id = r_cust_code.cust_account_id;
      
      ELSIF r_cust_code.customer_type = 'R' AND
            r_cust_code.sales_channel_code = 'INDIRECT' THEN
      
        UPDATE xxs3_otc_customer_accounts xoca
        SET    xoca.s3_customer_class_code = 'International/LATAM',
        cleanse_status = 'PASS'
        WHERE  xoca.legacy_cust_account_id = r_cust_code.cust_account_id;
      
      ELSIF r_cust_code.customer_type = 'R' AND
            r_cust_code.sales_channel_code = 'DIRECT' AND l_site_count > 0 THEN
      
        UPDATE xxs3_otc_customer_accounts xoca
        SET    xoca.s3_customer_class_code = 'Lease',
        cleanse_status = 'PASS'
        WHERE  xoca.legacy_cust_account_id = r_cust_code.cust_account_id;
      
      ELSIF r_cust_code.customer_type = 'R' AND
            r_cust_code.sales_channel_code = 'DIRECT' AND l_site_count = 0 THEN
      
        UPDATE xxs3_otc_customer_accounts xoca
        SET    xoca.s3_customer_class_code = 'Trade',
        cleanse_status = 'PASS'
        WHERE  xoca.legacy_cust_account_id = r_cust_code.cust_account_id;
        
      ELSE --copy legacy value
        UPDATE xxs3_otc_customer_accounts xoca
        SET    xoca.s3_customer_class_code = xoca.customer_class_code               
        WHERE  xoca.legacy_cust_account_id = r_cust_code.cust_account_id;
      END IF;
          
    END LOOP;
    --EQT 185
  
    FOR r_pay_term IN (SELECT xoca.legacy_cust_account_id,xoca.collector_emp_number,xoca.collector_id
                       FROM   xxs3_otc_customer_accounts xoca
                       WHERE extract_rule_name IS NOT NULL) LOOP
    
    --EQT 187 ,EQT-047
      IF xxs3_otc_customer_pkg.get_site_count(r_pay_term.legacy_cust_account_id) = 'Y' THEN      
        UPDATE xxs3_otc_customer_accounts xoca
           SET xoca.payment_term_value    = 'Net 30 Days', --EQT 187 
               --s3_payment_grace_days   = NULL, --EQT-047
               s3_collector_name       = 'Nathan Johnson', --EQT NEW
               s3_collector_emp_number = (SELECT employee_number
                                            FROM per_all_people_f a,
                                                 ar_collectors    b
                                           WHERE a.person_id = b.employee_id
                                             AND b.NAME = 'Nathan Johnson'),--EQT NEW
               s3_customer_type ='R', --EQT-267
               cleanse_status = 'PASS'
         WHERE xoca.legacy_cust_account_id =
               r_pay_term.legacy_cust_account_id;
       
     ELSE --set s3_value as legacy_value
      UPDATE xxs3_otc_customer_accounts xoca
           SET xoca.s3_customer_type    = customer_type
           WHERE xoca.legacy_cust_account_id = r_pay_term.legacy_cust_account_id; 
       
      IF r_pay_term.collector_emp_number IS NULL AND r_pay_term.collector_id IS NOT NULL THEN
        UPDATE xxs3_otc_customer_accounts xoca
        SET    /*xoca.s3_payment_grace_days = xoca.payment_grace_days,*/
               xoca.s3_collector_name =  'Stratasys, Collector' ,
               xoca.s3_collector_emp_number = (SELECT employee_number
                                            FROM per_all_people_f a,
                                                 ar_collectors    b
                                           WHERE a.person_id = b.employee_id
                                             AND b.NAME = 'Stratasys, Collector')
        WHERE  xoca.legacy_cust_account_id = r_pay_term.legacy_cust_account_id
        AND collector_emp_number IS NULL
        AND collector_id IS NOT NULL;
      ELSE
        
        UPDATE xxs3_otc_customer_accounts xoca
        SET    /*xoca.s3_payment_grace_days = xoca.payment_grace_days,*/
               xoca.s3_collector_name =  collector_name ,
               xoca.s3_collector_emp_number = collector_emp_number
        WHERE  xoca.legacy_cust_account_id = r_pay_term.legacy_cust_account_id;
      END IF;
     END IF;
    --EQT 187,EQT-047,EQT NEW
    
    END LOOP;
    
    -- EQT-043
       UPDATE xxs3_otc_customer_accounts xoca
          SET xoca.s3_credit_checking = CASE WHEN xoca.customer_type = 'I' THEN 'N' ELSE 'Y' END,
          cleanse_status = 'PASS'
        WHERE extract_rule_name IS NOT NULL;
    -- EQT-043 
    
    -- EQT-047
       UPDATE xxs3_otc_customer_accounts xoca
          SET xoca.s3_payment_grace_days = NULL,
          cleanse_status = 'PASS'
        WHERE extract_rule_name IS NOT NULL;
    -- EQT-047  
    
      -- EQT-045
       UPDATE xxs3_otc_customer_accounts xoca
          SET xoca.s3_profile_class = 'DEFAULT',
          cleanse_status = 'PASS'
        WHERE extract_rule_name IS NOT NULL;
    -- EQT-045  
    
     --EQT-049
        UPDATE xxs3_otc_customer_accounts xoca
        SET    xoca.s3_tax_printing_option = CASE WHEN xoca.SEND_STATEMENTS = 'Y' THEN 'Y' ELSE 'TOTAL ONLY' END,
               cleanse_status = 'PASS'
        WHERE  extract_rule_name IS NOT NULL;
    --EQT-049
    
      COMMIT;
  END;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Generate extract file in server using utl_file
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date          Name                          Description
  -- 1.0 17/08/2016     Debarati Banerjee             Initial build
  -----------------------------------------------------------------------------------------------
  PROCEDURE utl_file_generate(p_entity IN VARCHAR2) IS
  
    l_file      utl_file.file_type;
    l_file_path VARCHAR2(100);
    l_file_name VARCHAR2(100);
  
    /* Cursor for customer file generation using UTL */
  
    CURSOR c_customer_utl_upload IS
      SELECT * FROM xxobjt.xxs3_otc_customer_accounts;
  
    /* Cursor for the customer site use file generation using UTL */
    CURSOR c_cust_site_use_utl_upload IS
      SELECT * FROM xxobjt.xxs3_otc_cust_acct_site_uses;
  
  BEGIN
    BEGIN
      /* Get the file path from the lookup */
      SELECT TRIM(' ' FROM meaning)
      INTO l_file_path
      FROM fnd_lookup_values_vl
      WHERE lookup_type = 'XXS3_ITEM_OUT_FILE_PATH';
    
    EXCEPTION
      WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log, 'Invalid File Path' || SQLERRM);
      
    END;
  
    IF p_entity = 'CUSTOMER'
    THEN
      /* Get the file name  */
      l_file_name := 'Customer_Account_Extract' || '_' || SYSDATE || '.xls';
    
      /*Open utl file */
      l_file := utl_file.fopen(l_file_path, l_file_name, 'w', 32767);
    
      --generate csv
     /* utl_file.put(l_file, '~' || 'xx_cust_account_id');
      utl_file.put(l_file, '~' || 'cust_account_id');
      utl_file.put(l_file, '~' || 'account_number');
      utl_file.put(l_file, '~' || 'legacy_cust_account_id');
      utl_file.put(l_file, '~' || 'legacy_account_number');
      utl_file.put(l_file, '~' || 'status');
      utl_file.put(l_file, '~' || 'account_name');
      utl_file.put(l_file, '~' || 'party_id');
      utl_file.put(l_file, '~' || 'party_type');
      utl_file.put(l_file, '~' || 'orig_system_reference');
      utl_file.put(l_file, '~' || 'org_id');
      utl_file.put(l_file, '~' || 's3_org_id');
      utl_file.put(l_file, '~' || 'customer_type');
      utl_file.put(l_file, '~' || 'payment_term_id');
      utl_file.put(l_file, '~' || 'payment_term_value');
      utl_file.put(l_file, '~' || 'price_list_id');
      utl_file.put(l_file, '~' || 'price_list_value');
      utl_file.put(l_file, '~' || 'sales_channel_code');
      utl_file.put(l_file, '~' || 'date_type_reference');
      utl_file.put(l_file, '~' || 'customer_class_code');
      utl_file.put(l_file, '~' || 'warehouse_id');
      utl_file.put(l_file, '~' || 'warehouse_value');
      utl_file.put(l_file, '~' || 'tax_code');
      utl_file.put(l_file, '~' || 'tax_header_level_flag');
      utl_file.put(l_file, '~' || 'tax_rounding_rule');
      utl_file.put(l_file, '~' || 'account_established_date');
      utl_file.put(l_file, '~' || 'account_activation_date');
      utl_file.put(l_file, '~' || 'account_termination_date');
      utl_file.put(l_file, '~' || 'hold_bill_flag');
      utl_file.put(l_file, '~' || 'arrivalsets_include_lines_flag');
      utl_file.put(l_file, '~' || 'sched_date_push_flag');
      utl_file.put(l_file, '~' || 'tolerance');
      utl_file.put(l_file, '~' || 'dunning_letters');
      utl_file.put(l_file, '~' || 'send_statements');
      utl_file.put(l_file, '~' || 'credit_balance_statements');
      utl_file.put(l_file, '~' || 'standard_terms');
      utl_file.put(l_file, '~' || 'override_terms');
      utl_file.put(l_file, '~' || 'auto_rec_incl_disputed_flag');
      utl_file.put(l_file, '~' || 'tax_printing_option');
      utl_file.put(l_file, '~' || 'charge_on_finance_charge_flag');
      utl_file.put(l_file, '~' || 'cons_inv_flag');
      utl_file.put(l_file, '~' || 'currency_code');
      utl_file.put(l_file, '~' || 'trx_credit_limit');
      utl_file.put(l_file, '~' || 'min_statement_amount');
      utl_file.put(l_file, '~' || 'attribute1');
      utl_file.put(l_file, '~' || 'attribute2');
      utl_file.put(l_file, '~' || 'attribute3');
      utl_file.put(l_file, '~' || 'sf_account_id');
      utl_file.put(l_file, '~' || 'transfer_to_sf');
      utl_file.put(l_file, '~' || 'political_customer');
      utl_file.put(l_file, '~' || 'attribute7');
      utl_file.put(l_file, '~' || 'shipping_instruction');
      utl_file.put(l_file, '~' || 'collect_shipping_account');
      utl_file.put(l_file, '~' || 'customer_start_date');
      utl_file.put(l_file, '~' || 'inactive_reason');
      utl_file.put(l_file, '~' || 'customer_end_date');
      utl_file.put(l_file, '~' || 'attribute19');
      utl_file.put(l_file, '~' || 'attribute18');
      utl_file.put(l_file, '~' || 'fob_point');
      utl_file.put(l_file, '~' || 'freight_term');
      utl_file.put(l_file, '~' || 'ship_via');
      utl_file.put(l_file, '~' || 'primary_specialist_id');
      utl_file.put(l_file, '~' || 'primary_specialist_value');
      utl_file.put(l_file, '~' || 'ship_sets_include_lines_flag');
      utl_file.put(l_file, '~' || 'selling_party_id');
      utl_file.put(l_file, '~' || 'creation_date');
      utl_file.put(l_file, '~' || 'created_by_module');
      utl_file.put(l_file, '~' || 'created_by');
      utl_file.put(l_file, '~' || 'exempt_type');
      utl_file.put(l_file, '~' || 'credit_hold_reason');
      utl_file.put(l_file, '~' || 'score_card');
      utl_file.put(l_file, '~' || 'collector_id');
      utl_file.put(l_file, '~' || 'collector_name');
      utl_file.put(l_file, '~' || 'credit_checking');
      utl_file.put(l_file, '~' || 'credit_hold');
      utl_file.put(l_file, '~' || 'overall_credit_limit');
      utl_file.put(l_file, '~' || 'atradius_id');
      utl_file.put(l_file, '~' || 'ci_application_amount');
      utl_file.put(l_file, '~' || 'application_date');
      utl_file.put(l_file, '~' || 'ci_decision_amounnt');
      utl_file.put(l_file, '~' || 'decision_effective_date');
      utl_file.put(l_file, '~' || 'expiry_date');
      utl_file.put(l_file, '~' || 'buyer_name');
      utl_file.put(l_file, '~' || 'match_type');
      utl_file.put(l_file, '~' || 'credit_classification');
      utl_file.put(l_file, '~' || 'review_cycle');
      utl_file.put(l_file, '~' || 'credit_analyst');
      utl_file.put(l_file, '~' || 'customer_category_code');
      utl_file.put(l_file, '~' || 'date_extracted_on');
      utl_file.put(l_file, '~' || 'process_flag');
      utl_file.new_line(l_file);
    
      FOR c1 IN c_customer_utl_upload
      LOOP
      
        utl_file.put(l_file, '~' || to_char(c1.xx_cust_account_id));
        \*UTL_FILE.PUT(l_file,'~'||to_char(C1.cust_account_id));*\
        \*UTL_FILE.PUT(l_file,'~'||to_char(C1.account_number));*\
        utl_file.put(l_file, '~' || to_char(c1.legacy_cust_account_id));
        utl_file.put(l_file, '~' || to_char(c1.legacy_account_number));
        utl_file.put(l_file, '~' || to_char(c1.status));
        utl_file.put(l_file, '~' || to_char(c1.account_name));
        utl_file.put(l_file, '~' || to_char(c1.party_id));
        --utl_file.put(l_file, '~' || to_char(c1.party_type)); --Commented as on 26/12
        utl_file.put(l_file, '~' || to_char(c1.orig_system_reference));
        \*utl_file.pUT(l_file,'~'||to_char(C1.org_id));
        utl_file.put(l_file,'~'||to_char(C1.s3_org_id));*\
        utl_file.put(l_file, '~' || to_char(c1.customer_type));
        utl_file.put(l_file, '~' || to_char(c1.payment_term_id));
        utl_file.put(l_file, '~' || to_char(c1.payment_term_value));
        utl_file.put(l_file, '~' || to_char(c1.price_list_id));
        utl_file.put(l_file, '~' || to_char(c1.price_list_value));
        utl_file.put(l_file, '~' || to_char(c1.sales_channel_code));
        utl_file.put(l_file, '~' || to_char(c1.date_type_reference));
        utl_file.put(l_file, '~' || to_char(c1.customer_class_code));
        utl_file.put(l_file, '~' || to_char(c1.warehouse_id));
        utl_file.put(l_file, '~' || to_char(c1.warehouse_value));
        utl_file.put(l_file, '~' || to_char(c1.tax_code));
        utl_file.put(l_file, '~' || to_char(c1.tax_header_level_flag));
        utl_file.put(l_file, '~' || to_char(c1.tax_rounding_rule));
        utl_file.put(l_file, '~' || to_char(c1.account_established_date));
        utl_file.put(l_file, '~' || to_char(c1.account_activation_date));
        utl_file.put(l_file, '~' || to_char(c1.account_termination_date));
        utl_file.put(l_file, '~' || to_char(c1.hold_bill_flag));
        utl_file.put(l_file, '~' ||
                      to_char(c1.arrivalsets_include_lines_flag));
        utl_file.put(l_file, '~' || to_char(c1.sched_date_push_flag));
        utl_file.put(l_file, '~' || to_char(c1.tolerance));
        utl_file.put(l_file, '~' || to_char(c1.dunning_letters));
        utl_file.put(l_file, '~' || to_char(c1.send_statements));
        utl_file.put(l_file, '~' || to_char(c1.credit_balance_statements));
        utl_file.put(l_file, '~' || to_char(c1.standard_terms));
        utl_file.put(l_file, '~' || to_char(c1.override_terms));
        utl_file.put(l_file, '~' || to_char(c1.auto_rec_incl_disputed_flag));
        utl_file.put(l_file, '~' || to_char(c1.tax_printing_option));
        utl_file.put(l_file, '~' ||
                      to_char(c1.charge_on_finance_charge_flag));
        utl_file.put(l_file, '~' || to_char(c1.cons_inv_flag));
        utl_file.put(l_file, '~' || to_char(c1.currency_code));
        utl_file.put(l_file, '~' || to_char(c1.trx_credit_limit));
        utl_file.put(l_file, '~' || to_char(c1.min_statement_amount));
        utl_file.put(l_file, '~' || to_char(c1.attribute1));
        utl_file.put(l_file, '~' || to_char(c1.attribute2));
        utl_file.put(l_file, '~' || to_char(c1.attribute3));
        utl_file.put(l_file, '~' || to_char(c1.sf_account_id));
        utl_file.put(l_file, '~' || to_char(c1.transfer_to_sf));
        utl_file.put(l_file, '~' || to_char(c1.political_customer));
        utl_file.put(l_file, '~' || to_char(c1.attribute7));
        utl_file.put(l_file, '~' || to_char(c1.shipping_instruction));
        utl_file.put(l_file, '~' || to_char(c1.collect_shipping_account));
        utl_file.put(l_file, '~' || to_char(c1.customer_start_date));
        utl_file.put(l_file, '~' || to_char(c1.inactive_reason));
        utl_file.put(l_file, '~' || to_char(c1.customer_end_date));
        utl_file.put(l_file, '~' || to_char(c1.attribute19));
        utl_file.put(l_file, '~' || to_char(c1.attribute18));
        utl_file.put(l_file, '~' || to_char(c1.fob_point));
        --utl_file.put(l_file, '~' || to_char(c1.freight_term));--Commented as on 26/12
        utl_file.put(l_file, '~' || to_char(c1.ship_via));
        utl_file.put(l_file, '~' || to_char(c1.primary_specialist_id));
        utl_file.put(l_file, '~' || to_char(c1.primary_specialist_value));
        utl_file.put(l_file, '~' ||
                      to_char(c1.ship_sets_include_lines_flag));
        utl_file.put(l_file, '~' || to_char(c1.selling_party_id));
        utl_file.put(l_file, '~' || to_char(c1.creation_date));
        utl_file.put(l_file, '~' || to_char(c1.created_by_module));
        utl_file.put(l_file, '~' || to_char(c1.created_by));
        utl_file.put(l_file, '~' || to_char(c1.exempt_type));
        utl_file.put(l_file, '~' || to_char(c1.credit_hold_reason));
        utl_file.put(l_file, '~' || to_char(c1.score_card));
        utl_file.put(l_file, '~' || to_char(c1.collector_id));
        utl_file.put(l_file, '~' || to_char(c1.collector_name));
        utl_file.put(l_file, '~' || to_char(c1.credit_checking));
        utl_file.put(l_file, '~' || to_char(c1.credit_hold));
        utl_file.put(l_file, '~' || to_char(c1.overall_credit_limit));
        utl_file.put(l_file, '~' || to_char(c1.atradius_id));
        utl_file.put(l_file, '~' || to_char(c1.ci_application_amount));
        utl_file.put(l_file, '~' || to_char(c1.application_date));
        utl_file.put(l_file, '~' || to_char(c1.ci_decision_amounnt));
        utl_file.put(l_file, '~' || to_char(c1.decision_effective_date));
        utl_file.put(l_file, '~' || to_char(c1.expiry_date));
        utl_file.put(l_file, '~' || to_char(c1.buyer_name));
        utl_file.put(l_file, '~' || to_char(c1.match_type));
        utl_file.put(l_file, '~' || to_char(c1.credit_classification));
        utl_file.put(l_file, '~' || to_char(c1.review_cycle));
        utl_file.put(l_file, '~' || to_char(c1.credit_analyst));
        utl_file.put(l_file, '~' || to_char(c1.customer_category_code));
        utl_file.put(l_file, '~' || to_char(c1.date_extracted_on));
        utl_file.put(l_file, '~' || to_char(c1.process_flag));
        utl_file.new_line(l_file);
      
      END LOOP;
      utl_file.fclose(l_file);*/
    
    /*ELSIF p_entity = 'CUSTOMER_SITE_USE'
    THEN
    
      \* Get the file name  *\
      l_file_name := 'Customer_Site_Use_Extract' || '_' || SYSDATE ||
                     '.xls';
    
      \* Get the utl file open*\
      l_file := utl_file.fopen(l_file_path, l_file_name, 'w', 32767);
    
      \* generate csv file*\
    
      utl_file.put(l_file, '~' || 'XX_CUST_ACCT_SITE_USE_ID');
      utl_file.put(l_file, '~' || 'SITE_USE_ID');
      utl_file.put(l_file, '~' || 'LEGACY_SITE_USE_ID');
      utl_file.put(l_file, '~' || 'LEGACY_CUST_ACCT_SITE_ID');
      utl_file.put(l_file, '~' || 'CUST_ACCOUNT_ID');
      utl_file.put(l_file, '~' || 'CREATION_DATE');
      utl_file.put(l_file, '~' || 'CREATED_BY');
      utl_file.put(l_file, '~' || 'SITE_USE_CODE');
      utl_file.put(l_file, '~' || 'PRIMARY_FLAG');
      utl_file.put(l_file, '~' || 'STATUS');
      utl_file.put(l_file, '~' || 'LOCATION');
      utl_file.put(l_file, '~' || 'CONTACT_ID');
      utl_file.put(l_file, '~' || 'CONTACT_NUMBER');
      utl_file.put(l_file, '~' || 'BILL_TO_SITE_USE_ID');
      utl_file.put(l_file, '~' || 'PAYMENT_TERM_ID');
      utl_file.put(l_file, '~' || 'PAYMENT_TERM');
      utl_file.put(l_file, '~' || 'S3_PAYMENT_TERM');
      utl_file.put(l_file, '~' || 'GSA_INDICATOR');
      utl_file.put(l_file, '~' || 'SHIP_VIA');
      utl_file.put(l_file, '~' || 'INCOTERM');
      utl_file.put(l_file, '~' || 'S3_INCOTERM');
      utl_file.put(l_file, '~' || 'CUSTOMER_TYPE');
      utl_file.put(l_file, '~' || 'FOB_POINT');
      utl_file.put(l_file, '~' || 'S3_FOB_POINT');
      utl_file.put(l_file, '~' || 'ORDER_TYPE_ID');
      utl_file.put(l_file, '~' || 'ORDER_TYPE_NAME');
      utl_file.put(l_file, '~' || 'PRICE_LIST_ID');
      utl_file.put(l_file, '~' || 'S3_PRICE_LIST_ID');
      utl_file.put(l_file, '~' || 'PRICE_LIST_VALUE');
      utl_file.put(l_file, '~' || 'S3_PRICE_LIST_VALUE');
      utl_file.put(l_file, '~' || 'FREIGHT_TERM');
      utl_file.put(l_file, '~' || 'S3_FREIGHT_TERM');
      utl_file.put(l_file, '~' || 'WAREHOUSE_ID');
      utl_file.put(l_file, '~' || 'WAREHOUSE_CODE');
      utl_file.put(l_file, '~' || 'S3_WAREHOUSE_CODE');
      utl_file.put(l_file, '~' || 'TERRITORY_ID');
      utl_file.put(l_file, '~' || 'TERRITORY_NAME');
      utl_file.put(l_file, '~' || 'ATTRIBUTE_CATEGORY');
      utl_file.put(l_file, '~' || 'ATTRIBUTE10');
      utl_file.put(l_file, '~' || 'ATTRIBUTE12');
      utl_file.put(l_file, '~' || 'ORG_ID');
      utl_file.put(l_file, '~' || 'ORG_NAME');
      utl_file.put(l_file, '~' || 'S3_ORG_NAME');
      utl_file.put(l_file, '~' || 'PRIMARY_SALESREP_ID');
      utl_file.put(l_file, '~' || 'S3_PRIMARY_SALESREP_ID');
      utl_file.put(l_file, '~' || 'PRIMARY_SALESREP_NAME');
      utl_file.put(l_file, '~' || 'SHIP_SETS_INCLUDE_LINES_FLAG');
      utl_file.put(l_file, '~' || 'ARRIVALSETS_INCLUDE_LINES_FLAG');
      utl_file.put(l_file, '~' || 'SCHED_DATE_PUSH_FLAG');
      utl_file.put(l_file, '~' || 'OBJECT_VERSION_NUMBER');
      utl_file.put(l_file, '~' || 'GL_ID_REC');
      utl_file.put(l_file, '~' || 'GL_ID_REC_SEG1');
      utl_file.put(l_file, '~' || 'GL_ID_REC_SEG2');
      utl_file.put(l_file, '~' || 'GL_ID_REC_SEG3');
      utl_file.put(l_file, '~' || 'GL_ID_REC_SEG4');
      utl_file.put(l_file, '~' || 'GL_ID_REC_SEG5');
      utl_file.put(l_file, '~' || 'GL_ID_REC_SEG6');
      utl_file.put(l_file, '~' || 'GL_ID_REC_SEG7');
      utl_file.put(l_file, '~' || 'GL_ID_REC_SEG10');
      utl_file.put(l_file, '~' || 'GL_ID_REC_SEG9');
      utl_file.put(l_file, '~' || 'S3_GL_ID_REC_SEG1');
      utl_file.put(l_file, '~' || 'S3_GL_ID_REC_SEG2');
      utl_file.put(l_file, '~' || 'S3_GL_ID_REC_SEG3');
      utl_file.put(l_file, '~' || 'S3_GL_ID_REC_SEG4');
      utl_file.put(l_file, '~' || 'S3_GL_ID_REC_SEG5');
      utl_file.put(l_file, '~' || 'S3_GL_ID_REC_SEG6');
      utl_file.put(l_file, '~' || 'S3_GL_ID_REC_SEG7');
      utl_file.put(l_file, '~' || 'S3_GL_ID_REC_SEG8');
      utl_file.put(l_file, '~' || 'GL_ID_REV');
      utl_file.put(l_file, '~' || 'GL_ID_REV_SEG1');
      utl_file.put(l_file, '~' || 'GL_ID_REV_SEG2');
      utl_file.put(l_file, '~' || 'GL_ID_REV_SEG3');
      utl_file.put(l_file, '~' || 'GL_ID_REV_SEG4');
      utl_file.put(l_file, '~' || 'GL_ID_REV_SEG5');
      utl_file.put(l_file, '~' || 'GL_ID_REV_SEG6');
      utl_file.put(l_file, '~' || 'GL_ID_REV_SEG7');
      utl_file.put(l_file, '~' || 'GL_ID_REV_SEG10');
      utl_file.put(l_file, '~' || 'GL_ID_REV_SEG9');
      utl_file.put(l_file, '~' || 'S3_GL_ID_REV_SEG1');
      utl_file.put(l_file, '~' || 'S3_GL_ID_REV_SEG2');
      utl_file.put(l_file, '~' || 'S3_GL_ID_REV_SEG3');
      utl_file.put(l_file, '~' || 'S3_GL_ID_REV_SEG4');
      utl_file.put(l_file, '~' || 'S3_GL_ID_REV_SEG5');
      utl_file.put(l_file, '~' || 'S3_GL_ID_REV_SEG6');
      utl_file.put(l_file, '~' || 'S3_GL_ID_REV_SEG7');
      utl_file.put(l_file, '~' || 'S3_GL_ID_REV_SEG8');
      utl_file.put(l_file, '~' || 'GL_ID_TAX');
      utl_file.put(l_file, '~' || 'GL_ID_TAX_SEG1');
      utl_file.put(l_file, '~' || 'GL_ID_TAX_SEG2');
      utl_file.put(l_file, '~' || 'GL_ID_TAX_SEG3');
      utl_file.put(l_file, '~' || 'GL_ID_TAX_SEG4');
      utl_file.put(l_file, '~' || 'GL_ID_TAX_SEG5');
      utl_file.put(l_file, '~' || 'GL_ID_TAX_SEG6');
      utl_file.put(l_file, '~' || 'GL_ID_TAX_SEG7');
      utl_file.put(l_file, '~' || 'GL_ID_TAX_SEG10');
      utl_file.put(l_file, '~' || 'GL_ID_TAX_SEG9');
      utl_file.put(l_file, '~' || 'S3_GL_ID_TAX_SEG1');
      utl_file.put(l_file, '~' || 'S3_GL_ID_TAX_SEG2');
      utl_file.put(l_file, '~' || 'S3_GL_ID_TAX_SEG3');
      utl_file.put(l_file, '~' || 'S3_GL_ID_TAX_SEG4');
      utl_file.put(l_file, '~' || 'S3_GL_ID_TAX_SEG5');
      utl_file.put(l_file, '~' || 'S3_GL_ID_TAX_SEG6');
      utl_file.put(l_file, '~' || 'S3_GL_ID_TAX_SEG7');
      utl_file.put(l_file, '~' || 'S3_GL_ID_TAX_SEG8');
      utl_file.put(l_file, '~' || 'GL_ID_FREIGHT');
      utl_file.put(l_file, '~' || 'GL_ID_FREIGHT_SEG1');
      utl_file.put(l_file, '~' || 'GL_ID_FREIGHT_SEG2');
      utl_file.put(l_file, '~' || 'GL_ID_FREIGHT_SEG3');
      utl_file.put(l_file, '~' || 'GL_ID_FREIGHT_SEG4');
      utl_file.put(l_file, '~' || 'GL_ID_FREIGHT_SEG5');
      utl_file.put(l_file, '~' || 'GL_ID_FREIGHT_SEG6');
      utl_file.put(l_file, '~' || 'GL_ID_FREIGHT_SEG7');
      utl_file.put(l_file, '~' || 'GL_ID_FREIGHT_SEG10');
      utl_file.put(l_file, '~' || 'GL_ID_FREIGHT_SEG9');
      utl_file.put(l_file, '~' || 'S3_GL_ID_FREIGHT_SEG1');
      utl_file.put(l_file, '~' || 'S3_GL_ID_FREIGHT_SEG2');
      utl_file.put(l_file, '~' || 'S3_GL_ID_FREIGHT_SEG3');
      utl_file.put(l_file, '~' || 'S3_GL_ID_FREIGHT_SEG4');
      utl_file.put(l_file, '~' || 'S3_GL_ID_FREIGHT_SEG5');
      utl_file.put(l_file, '~' || 'S3_GL_ID_FREIGHT_SEG6');
      utl_file.put(l_file, '~' || 'S3_GL_ID_FREIGHT_SEG7');
      utl_file.put(l_file, '~' || 'S3_GL_ID_FREIGHT_SEG8');
      utl_file.put(l_file, '~' || 'GL_ID_UNBILLED');
      utl_file.put(l_file, '~' || 'GL_ID_UNBILLED_SEG1');
      utl_file.put(l_file, '~' || 'GL_ID_UNBILLED_SEG2');
      utl_file.put(l_file, '~' || 'GL_ID_UNBILLED_SEG3');
      utl_file.put(l_file, '~' || 'GL_ID_UNBILLED_SEG4');
      utl_file.put(l_file, '~' || 'GL_ID_UNBILLED_SEG5');
      utl_file.put(l_file, '~' || 'GL_ID_UNBILLED_SEG6');
      utl_file.put(l_file, '~' || 'GL_ID_UNBILLED_SEG7');
      utl_file.put(l_file, '~' || 'GL_ID_UNBILLED_SEG10');
      utl_file.put(l_file, '~' || 'GL_ID_UNBILLED_SEG9');
      utl_file.put(l_file, '~' || 'S3_GL_ID_UNBILLED_SEG1');
      utl_file.put(l_file, '~' || 'S3_GL_ID_UNBILLED_SEG2');
      utl_file.put(l_file, '~' || 'S3_GL_ID_UNBILLED_SEG3');
      utl_file.put(l_file, '~' || 'S3_GL_ID_UNBILLED_SEG4');
      utl_file.put(l_file, '~' || 'S3_GL_ID_UNBILLED_SEG5');
      utl_file.put(l_file, '~' || 'S3_GL_ID_UNBILLED_SEG6');
      utl_file.put(l_file, '~' || 'S3_GL_ID_UNBILLED_SEG7');
      utl_file.put(l_file, '~' || 'S3_GL_ID_UNBILLED_SEG8');
      utl_file.put(l_file, '~' || 'GL_ID_UNEARNED');
      utl_file.put(l_file, '~' || 'GL_ID_UNEARNED_SEG1');
      utl_file.put(l_file, '~' || 'GL_ID_UNEARNED_SEG2');
      utl_file.put(l_file, '~' || 'GL_ID_UNEARNED_SEG3');
      utl_file.put(l_file, '~' || 'GL_ID_UNEARNED_SEG4');
      utl_file.put(l_file, '~' || 'GL_ID_UNEARNED_SEG5');
      utl_file.put(l_file, '~' || 'GL_ID_UNEARNED_SEG6');
      utl_file.put(l_file, '~' || 'GL_ID_UNEARNED_SEG7');
      utl_file.put(l_file, '~' || 'GL_ID_UNEARNED_SEG10');
      utl_file.put(l_file, '~' || 'GL_ID_UNEARNED_SEG9');
      utl_file.put(l_file, '~' || 'S3_GL_ID_UNEARNED_SEG1');
      utl_file.put(l_file, '~' || 'S3_GL_ID_UNEARNED_SEG2');
      utl_file.put(l_file, '~' || 'S3_GL_ID_UNEARNED_SEG3');
      utl_file.put(l_file, '~' || 'S3_GL_ID_UNEARNED_SEG4');
      utl_file.put(l_file, '~' || 'S3_GL_ID_UNEARNED_SEG5');
      utl_file.put(l_file, '~' || 'S3_GL_ID_UNEARNED_SEG6');
      utl_file.put(l_file, '~' || 'S3_GL_ID_UNEARNED_SEG7');
      utl_file.put(l_file, '~' || 'S3_GL_ID_UNEARNED_SEG8');
      utl_file.put(l_file, '~' || 'DATE_EXTRACTED_ON');
      utl_file.put(l_file, '~' || 'PROCESS_FLAG');
      utl_file.put(l_file, '~' || 'TRANSFORM_STATUS');
      utl_file.put(l_file, '~' || 'TRANSFORM_ERROR');
      utl_file.new_line(l_file);
    
      FOR c1 IN c_cust_site_use_utl_upload
      LOOP
      
        utl_file.put(l_file, '~' || to_char(c1.xx_cust_acct_site_use_id));
        --UTL_FILE.PUT(l_file,'~'||to_char(c1.site_use_id)                );
        utl_file.put(l_file, '~' || to_char(c1.legacy_site_use_id));
        utl_file.put(l_file, '~' || to_char(c1.legacy_cust_acct_site_id));
        utl_file.put(l_file, '~' || to_char(c1.cust_account_id));
        utl_file.put(l_file, '~' || to_char(c1.creation_date));
        utl_file.put(l_file, '~' || to_char(c1.created_by));
        utl_file.put(l_file, '~' || to_char(c1.site_use_code));
        utl_file.put(l_file, '~' || to_char(c1.primary_flag));
        utl_file.put(l_file, '~' || to_char(c1.status));
        utl_file.put(l_file, '~' || to_char(c1.location));
        utl_file.put(l_file, '~' || to_char(c1.contact_id));
        utl_file.put(l_file, '~' || to_char(c1.contact_number));
        utl_file.put(l_file, '~' || to_char(c1.bill_to_site_use_id));
        utl_file.put(l_file, '~' || to_char(c1.payment_term_id));
        utl_file.put(l_file, '~' || to_char(c1.payment_term));
        utl_file.put(l_file, '~' || to_char(c1.s3_payment_term));
        utl_file.put(l_file, '~' || to_char(c1.gsa_indicator));
        utl_file.put(l_file, '~' || to_char(c1.ship_via));
        utl_file.put(l_file, '~' || to_char(c1.incoterm));
        utl_file.put(l_file, '~' || to_char(c1.s3_incoterm));
        utl_file.put(l_file, '~' || to_char(c1.customer_type));
        utl_file.put(l_file, '~' || to_char(c1.fob_point));
        utl_file.put(l_file, '~' || to_char(c1.s3_fob_point));
        utl_file.put(l_file, '~' || to_char(c1.order_type_id));
        utl_file.put(l_file, '~' || to_char(c1.order_type_name));
        utl_file.put(l_file, '~' || to_char(c1.price_list_id));
        --utl_file.pUT(l_file,'~'||to_char(c1.s3_price_list_id )          );
        utl_file.put(l_file, '~' || to_char(c1.price_list_value));
        utl_file.put(l_file, '~' || to_char(c1.s3_price_list_value));
        utl_file.put(l_file, '~' || to_char(c1.freight_term));
        utl_file.put(l_file, '~' || to_char(c1.s3_freight_term));
        utl_file.put(l_file, '~' || to_char(c1.warehouse_id));
        utl_file.put(l_file, '~' || to_char(c1.warehouse_code));
        utl_file.put(l_file, '~' || to_char(c1.s3_warehouse_code));
        utl_file.put(l_file, '~' || to_char(c1.territory_id));
        utl_file.put(l_file, '~' || to_char(c1.territory_name));
        utl_file.put(l_file, '~' || to_char(c1.attribute_category));
        utl_file.put(l_file, '~' || to_char(c1.attribute10));
        utl_file.put(l_file, '~' || to_char(c1.attribute12));
        utl_file.put(l_file, '~' || to_char(c1.org_id));
        utl_file.put(l_file, '~' || to_char(c1.org_name));
        utl_file.put(l_file, '~' || to_char(c1.s3_org_name));
        utl_file.put(l_file, '~' || to_char(c1.primary_salesrep_id));
        utl_file.put(l_file, '~' || to_char(c1.s3_primary_salesrep_id));
        utl_file.put(l_file, '~' || to_char(c1.primary_salesrep_name));
        utl_file.put(l_file, '~' ||
                      to_char(c1.ship_sets_include_lines_flag));
        utl_file.put(l_file, '~' ||
                      to_char(c1. arrivalsets_include_lines_flag));
        utl_file.put(l_file, '~' || to_char(c1.sched_date_push_flag));
        utl_file.put(l_file, '~' || to_char(c1.object_version_number));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_rec));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_rec_seg1));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_rec_seg2));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_rec_seg3));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_rec_seg4));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_rec_seg5));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_rec_seg6));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_rec_seg7));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_rec_seg10));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_rec_seg9));
        utl_file.put(l_file, '~' || to_char(c1.s3_gl_id_rec_seg1));
        utl_file.put(l_file, '~' || to_char(c1.s3_gl_id_rec_seg2));
        utl_file.put(l_file, '~' || to_char(c1.s3_gl_id_rec_seg3));
        utl_file.put(l_file, '~' || to_char(c1.s3_gl_id_rec_seg4));
        utl_file.put(l_file, '~' || to_char(c1.s3_gl_id_rec_seg5));
        utl_file.put(l_file, '~' || to_char(c1.s3_gl_id_rec_seg6));
        utl_file.put(l_file, '~' || to_char(c1.s3_gl_id_rec_seg7));
        utl_file.put(l_file, '~' || to_char(c1.s3_gl_id_rec_seg8));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_rev));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_rev_seg1));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_rev_seg2));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_rev_seg3));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_rev_seg4));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_rev_seg5));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_rev_seg6));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_rev_seg7));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_rev_seg10));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_rev_seg9));
        utl_file.put(l_file, '~' || to_char(c1.s3_gl_id_rev_seg1));
        utl_file.put(l_file, '~' || to_char(c1.s3_gl_id_rev_seg2));
        utl_file.put(l_file, '~' || to_char(c1.s3_gl_id_rev_seg3));
        utl_file.put(l_file, '~' || to_char(c1.s3_gl_id_rev_seg4));
        utl_file.put(l_file, '~' || to_char(c1.s3_gl_id_rev_seg5));
        utl_file.put(l_file, '~' || to_char(c1.s3_gl_id_rev_seg6));
        utl_file.put(l_file, '~' || to_char(c1.s3_gl_id_rev_seg7));
        utl_file.put(l_file, '~' || to_char(c1.s3_gl_id_rev_seg8));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_tax));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_tax_seg1));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_tax_seg2));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_tax_seg3));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_tax_seg4));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_tax_seg5));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_tax_seg6));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_tax_seg7));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_tax_seg10));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_tax_seg9));
        utl_file.put(l_file, '~' || to_char(c1.s3_gl_id_tax_seg1));
        utl_file.put(l_file, '~' || to_char(c1.s3_gl_id_tax_seg2));
        utl_file.put(l_file, '~' || to_char(c1.s3_gl_id_tax_seg3));
        utl_file.put(l_file, '~' || to_char(c1.s3_gl_id_tax_seg4));
        utl_file.put(l_file, '~' || to_char(c1.s3_gl_id_tax_seg5));
        utl_file.put(l_file, '~' || to_char(c1.s3_gl_id_tax_seg6));
        utl_file.put(l_file, '~' || to_char(c1.s3_gl_id_tax_seg7));
        utl_file.put(l_file, '~' || to_char(c1.s3_gl_id_tax_seg8));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_freight));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_freight_seg1));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_freight_seg2));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_freight_seg3));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_freight_seg4));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_freight_seg5));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_freight_seg6));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_freight_seg7));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_freight_seg10));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_freight_seg9));
        utl_file.put(l_file, '~' || to_char(c1.s3_gl_id_freight_seg1));
        utl_file.put(l_file, '~' || to_char(c1.s3_gl_id_freight_seg2));
        utl_file.put(l_file, '~' || to_char(c1.s3_gl_id_freight_seg3));
        utl_file.put(l_file, '~' || to_char(c1.s3_gl_id_freight_seg4));
        utl_file.put(l_file, '~' || to_char(c1.s3_gl_id_freight_seg5));
        utl_file.put(l_file, '~' || to_char(c1.s3_gl_id_freight_seg6));
        utl_file.put(l_file, '~' || to_char(c1.s3_gl_id_freight_seg7));
        utl_file.put(l_file, '~' || to_char(c1.s3_gl_id_freight_seg8));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_unbilled));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_unbilled_seg1));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_unbilled_seg2));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_unbilled_seg3));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_unbilled_seg4));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_unbilled_seg5));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_unbilled_seg6));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_unbilled_seg7));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_unbilled_seg10));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_unbilled_seg9));
        utl_file.put(l_file, '~' || to_char(c1.s3_gl_id_unbilled_seg1));
        utl_file.put(l_file, '~' || to_char(c1.s3_gl_id_unbilled_seg2));
        utl_file.put(l_file, '~' || to_char(c1.s3_gl_id_unbilled_seg3));
        utl_file.put(l_file, '~' || to_char(c1.s3_gl_id_unbilled_seg4));
        utl_file.put(l_file, '~' || to_char(c1.s3_gl_id_unbilled_seg5));
        utl_file.put(l_file, '~' || to_char(c1.s3_gl_id_unbilled_seg6));
        utl_file.put(l_file, '~' || to_char(c1.s3_gl_id_unbilled_seg7));
        utl_file.put(l_file, '~' || to_char(c1.s3_gl_id_unbilled_seg8));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_unearned));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_unearned_seg1));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_unearned_seg2));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_unearned_seg3));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_unearned_seg4));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_unearned_seg5));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_unearned_seg6));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_unearned_seg7));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_unearned_seg10));
        utl_file.put(l_file, '~' || to_char(c1.gl_id_unearned_seg9));
        utl_file.put(l_file, '~' || to_char(c1.s3_gl_id_unearned_seg1));
        utl_file.put(l_file, '~' || to_char(c1.s3_gl_id_unearned_seg2));
        utl_file.put(l_file, '~' || to_char(c1.s3_gl_id_unearned_seg3));
        utl_file.put(l_file, '~' || to_char(c1.s3_gl_id_unearned_seg4));
        utl_file.put(l_file, '~' || to_char(c1.s3_gl_id_unearned_seg5));
        utl_file.put(l_file, '~' || to_char(c1.s3_gl_id_unearned_seg6));
        utl_file.put(l_file, '~' || to_char(c1.s3_gl_id_unearned_seg7));
        utl_file.put(l_file, '~' || to_char(c1.s3_gl_id_unearned_seg8));
        utl_file.put(l_file, '~' || to_char(c1.date_extracted_on));
        utl_file.put(l_file, '~' || to_char(c1.process_flag));
        utl_file.put(l_file, '~' || to_char(c1.transform_status));
        utl_file.put(l_file, '~' || to_char(c1.transform_error));
        utl_file.new_line(l_file);
      END LOOP;
      \* Utl file Close *\
      utl_file.fclose(l_file);*/
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log, 'Unexpected error during file generation : ' ||
                         chr(10) || SQLCODE || chr(10) ||
                         SQLERRM);
      fnd_file.put_line(fnd_file.log, '--------------------------------------');
    
  END utl_file_generate;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: Extract customer accounts
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0 11/05/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required Customer Account  fields
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0 11/05/2016  Mishal Kumar                  Initial build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE customer_extract_data(x_errbuf  OUT VARCHAR2
                                 ,x_retcode OUT NUMBER) IS
    /* Variables */
    l_errbuf                 VARCHAR2(2000);
    l_retcode                VARCHAR2(1);
    l_requestor              NUMBER;
    l_program_short_name     VARCHAR2(100);
    l_status_message         VARCHAR2(4000);
    l_counter                NUMBER;
    lc_s3_fob                VARCHAR2(100);
    l_output                 VARCHAR2(100) := 'SUCCESS';
    l_count                  NUMBER := 0;
    l_err_msg                VARCHAR2(4000);
    l_err_code               VARCHAR2(100);
    l_output_coa_update      VARCHAR2(4000);
    l_output_code_coa_update VARCHAR2(100);
    l_s3_gl_string           VARCHAR2(2000);
    l_step                   VARCHAR2(50);
    l_count_cust             NUMBER;
  
    /* Cursor for the Customer Account */
  
    CURSOR cur_customer_extract 
    IS
 SELECT ca.account_established_date       account_established_date,
        ca.account_name                   account_name,
        ca.account_number                 legacy_account_number,
        ca.arrivalsets_include_lines_flag arrivalsets_include_lines_flag,
        -- cpa.attribute1 atradius_id,
        ca.attribute1  attribute1,
        ca.attribute10 collect_shipping_account,
        ca.attribute11 customer_start_date,
        ca.attribute12 inactive_reason,
        ca.attribute13 customer_end_date,
        cp.attribute2  credit_hold_reason,
        -- cpa.attribute2 ci_application_amount,
        --cp.attribute1 parent_account_number,
        -- ca.attribute2 attribute2,
        -- cpa.attribute3 application_date,
        -- ca.attribute3 attribute3,
        cp.attribute4 exempt_type,
        ca.attribute4 sf_account_id,
        -- cpa.attribute4 ci_decision_amounnt,
        cp.attribute5 score_card,
        ca.attribute5 transfer_to_sf,
        --cpa.attribute5 decision_effective_date,
        ca.attribute6 political_customer,
        --cpa.attribute6 expiry_date,
        --cpa.attribute8 buyer_name,
        ca.attribute9 shipping_instruction,
        --cpa.attribute9 match_type,
        cp.auto_rec_incl_disputed_flag auto_rec_incl_disputed_flag,
        cp.autocash_hierarchy_id,
        cp.charge_on_finance_charge_flag charge_on_finance_charge_flag,
        (SELECT class_code
           FROM (SELECT hoa.class_code, hca.cust_account_id
                   FROM hz_code_assignments hoa,
                        hz_parties          hp,
                        hz_cust_accounts    hca
                  WHERE hp.party_id = hoa.owner_table_id(+)
                       --AND    ca.class_code = 'Education'
                    AND SYSDATE BETWEEN hoa.start_date_active AND
                        nvl(hoa.end_date_active, SYSDATE)
                    AND hca.party_id = hp.party_id
                       --AND hca.cust_account_id = ca.cust_account_id
                    AND hoa.class_category = 'Objet Business Type'
                    AND hp.party_type = 'ORGANIZATION'
                  ORDER BY hoa.creation_date DESC) a
          WHERE rownum <= 1
            AND a.cust_account_id = ca.cust_account_id) industry_class_category,
        /*(SELECT hoa.class_code
                   FROM (SELECT xe.class_code,
                                xe.code_assignment_id,
                                hca.cust_account_id,
                                MAX(xe.code_assignment_id) over(PARTITION BY xe.class_code) max_id
                           FROM hz_code_assignments xe,
                                hz_parties          hp,
                                hz_cust_accounts    hca
                          WHERE hp.party_id = xe.owner_table_id(+)
                               --AND    ca.class_code = 'Education'
                            AND SYSDATE BETWEEN xe.start_date_active AND
                                nvl(xe.end_date_active, SYSDATE)
                            AND hca.party_id = hp.party_id
                            --AND hca.cust_account_id = ca.cust_account_id
                            AND xe.class_category = 'Objet Business Type') hoa
                  WHERE hoa.code_assignment_id = hoa.max_id
                    AND hoa.cust_account_id = ca.cust_account_id) industry_class_category,*/
        cp.collector_id collector_id,
        (SELECT employee_number
           FROM per_all_people_f a, ar_collectors b
          WHERE a.person_id = b.employee_id
            AND b.collector_id = cp.collector_id
            AND SYSDATE BETWEEN nvl(a.effective_start_date, SYSDATE) AND
                nvl(a.effective_end_date, SYSDATE)) collector_emp_number,
        (SELECT NAME FROM ar_collectors WHERE collector_id = cp.collector_id) collector_name,
        cp.cons_inv_flag cons_inv_flag,
        /*cp.credit_analyst_id credit_analyst_id,
                (SELECT source_name
                   FROM jtf_rs_resource_extns
                  WHERE resource_id = cp.credit_analyst_id) credit_analyst_name,
                (SELECT employee_number
                   FROM per_all_people_f ppf, jtf_rs_resource_extns jtr
                  WHERE jtr.resource_id = cp.credit_analyst_id
                    AND ppf.party_id = jtr.person_party_id
                    AND SYSDATE BETWEEN nvl(ppf.effective_start_date, SYSDATE) AND
                        nvl(ppf.effective_end_date, SYSDATE)) credit_analyst_emp_no,*/
        cp.credit_balance_statements credit_balance_statements,
        cp.credit_checking           credit_checking,
        cp.credit_hold               credit_hold,
        --cpa.currency_code currency_code,
        cp.cust_account_profile_id,
        --cpa.cust_acct_profile_amt_id,
        cp.discount_terms,
        cp.dunning_letters dunning_letters,
        cp.grouping_rule_id,
        (SELECT NAME FROM ra_grouping_rules WHERE grouping_rule_id = cp.grouping_rule_id) grouping_rule_name,
        --cpa.min_statement_amount min_statement_amount,
        --cpa.overall_credit_limit overall_credit_limit,
        cp.override_terms override_terms
        --new fields             
        --,ca.attribute7 attribute7 --commented as on 22/12
       ,
        ca.created_by created_by,
        ca.creation_date creation_date,
        ca.cust_account_id legacy_cust_account_id,
        ca.customer_class_code customer_class_code,
        ca.customer_type customer_type,
        ca.date_type_preference date_type_preference,
        ca.fob_point fob_point,
        ca.freight_term,
        ca.attribute18,
        ca.hold_bill_flag hold_bill_flag,
        (SELECT hcpc.NAME profile_class
           FROM hz_cust_profile_classes hcpc
          WHERE hcpc.profile_class_id = cp.profile_class_id) profile_class,
        ca.orig_system_reference orig_system_reference,
        ca.party_id party_id,
        ca.payment_term_id payment_term_id,
        (SELECT NAME
           FROM ra_terms rt
          WHERE rt.term_id = cp.standard_terms /*ca.payment_term_id*/
         ) payment_term_value,
        ca.price_list_id price_list_id,
        (SELECT NAME
           FROM qp_price_lists_v qp
          WHERE qp.price_list_id = ca.price_list_id) price_list_value,
        (SELECT registration_status_code
           FROM (SELECT registration_status_code, zptp.party_id
                   FROM zx_registrations zr, zx_party_tax_profile zptp
                  WHERE zr.party_tax_profile_id = zptp.party_tax_profile_id
                    AND SYSDATE BETWEEN nvl(zr.effective_from, SYSDATE) AND
                        nvl(zr.effective_to, SYSDATE)
                 --AND zptp.party_id = ca.party_id
                  ORDER BY zr.creation_date DESC) a
          WHERE rownum <= 1
            AND a.party_id = ca.party_id) registration_status_code,
        /*(SELECT zr.registration_status_code
                   FROM (SELECT xe.registration_status_code,
                                zptp.party_id,
                                xe.party_tax_profile_id,
                                MAX(xe.party_tax_profile_id) over(PARTITION BY xe.registration_status_code) max_id
                           FROM zx_registrations xe, zx_party_tax_profile zptp
                          WHERE xe.party_tax_profile_id = zptp.party_tax_profile_id
                            --AND zptp.party_id = ca.party_id
                            AND SYSDATE BETWEEN nvl(xe.effective_from, SYSDATE) AND
                                nvl(xe.effective_to, SYSDATE)) zr
                  WHERE zr.party_tax_profile_id = zr.max_id
                  AND zr.party_id = ca.party_id) registration_status_code,*/
        ca.sales_channel_code sales_channel_code,
        ca.warehouse_id warehouse_id --Commented as on 22/12
       ,
        (SELECT organization_code
           FROM mtl_parameters
          WHERE organization_id = ca.warehouse_id) warehouse_value,
        cp.profile_class_id,
        ca.sched_date_push_flag sched_date_push_flag,
        cp.send_statements send_statements,
        cp.site_use_id,
        cp.standard_terms standard_terms,
        (SELECT start_date_active
           FROM (SELECT hoa.start_date_active, hca.cust_account_id
                   FROM hz_code_assignments hoa,
                        hz_parties          hp,
                        hz_cust_accounts    hca
                  WHERE hp.party_id = hoa.owner_table_id(+)
                       --AND    ca.class_code = 'Education'
                    AND SYSDATE BETWEEN hoa.start_date_active AND
                        nvl(hoa.end_date_active, SYSDATE)
                    AND hca.party_id = hp.party_id
                       --AND hca.cust_account_id = ca.cust_account_id
                    AND hp.party_type = 'ORGANIZATION'
                    AND hoa.class_category = 'Objet Business Type'
                  ORDER BY hoa.creation_date DESC) a
          WHERE rownum <= 1
            AND a.cust_account_id = ca.cust_account_id) indus_class_category_start,
        /* (SELECT hoa.start_date_active
                   FROM (SELECT xe.class_code,
                                xe.code_assignment_id,
                                hca.cust_account_id,
                                xe.start_date_active,
                                MAX(xe.code_assignment_id) over(PARTITION BY xe.class_code) max_id
                           FROM hz_code_assignments xe,
                                hz_parties          hp,
                                hz_cust_accounts    hca
                          WHERE hp.party_id = xe.owner_table_id(+)
                               --AND    ca.class_code = 'Education'
                            AND SYSDATE BETWEEN xe.start_date_active AND
                                nvl(xe.end_date_active, SYSDATE)
                            AND hca.party_id = hp.party_id
                            --AND hca.cust_account_id = ca.cust_account_id
                            AND xe.class_category = 'Objet Business Type') hoa
                  WHERE hoa.code_assignment_id = hoa.max_id
                  AND hoa.cust_account_id = ca.cust_account_id) indus_class_category_start,*/
        cp.statement_cycle_id,
        ca.status status,
        (SELECT status
           FROM (SELECT hoa.status, hca.cust_account_id
                   FROM hz_code_assignments hoa,
                        hz_parties          hp,
                        hz_cust_accounts    hca
                  WHERE hp.party_id = hoa.owner_table_id(+)
                       --AND    ca.class_code = 'Education'
                    AND SYSDATE BETWEEN hoa.start_date_active AND
                        nvl(hoa.end_date_active, SYSDATE)
                    AND hca.party_id = hp.party_id
                       --AND hca.cust_account_id = ca.cust_account_id
                    AND hp.party_type = 'ORGANIZATION'
                    AND hoa.class_category = 'Objet Business Type'
                  ORDER BY hoa.creation_date DESC) a
          WHERE a.cust_account_id = ca.cust_account_id
            AND rownum <= 1) indus_class_category_status,
        /*(SELECT hoa.status
                   FROM (SELECT xe.class_code,
                                xe.code_assignment_id,
                                hca.cust_account_id,
                                xe.status,
                                MAX(xe.code_assignment_id) over(PARTITION BY xe.class_code) max_id
                           FROM hz_code_assignments xe,
                                hz_parties          hp,
                                hz_cust_accounts    hca
                          WHERE hp.party_id = xe.owner_table_id(+)
                               --AND    ca.class_code = 'Education'
                            AND SYSDATE BETWEEN xe.start_date_active AND
                                nvl(xe.end_date_active, SYSDATE)
                            AND hca.party_id = hp.party_id
                            --AND hca.cust_account_id = ca.cust_account_id
                            AND xe.class_category = 'Objet Business Type') hoa
                  WHERE hoa.code_assignment_id = hoa.max_id
                  AND hoa.cust_account_id = ca.cust_account_id) indus_class_category_status,*/
        cp.status profile_status,
        ca.tax_code tax_code,
        ca.tax_header_level_flag tax_header_level_flag,
        cp.tax_printing_option tax_printing_option,
        cp.payment_grace_days,
        ca.tax_rounding_rule tax_rounding_rule,
        cp.tolerance tolerance
 /* ca.ship_via ship_via,
           ca.primary_salesrep_id,
           (SELECT NAME
                 FROM apps.ra_salesreps_all salerep
                 WHERE salesrep_id = ca.primary_salesrep_id) primary_salesrep_name,
           (SELECT ppf.employee_number
                   FROM apps.per_all_people_f ppf, apps.ra_salesreps_all rs
                  WHERE ppf.person_id = rs.person_id
                    AND rs.salesrep_id = ca.primary_salesrep_id
                    AND SYSDATE BETWEEN
                            nvl(ppf.effective_start_date, SYSDATE) AND
                            nvl(ppf.effective_end_date, SYSDATE)) salesrep_emp_number,
           ca.ship_sets_include_lines_flag*/
 --cpa.trx_credit_limit trx_credit_limit
 /* ,ca.attribute18 attribute18  --Commented as on 22/12
                                            ,ca.attribute19 attribute19*/ --Commented as on 22/12
 /* ,hp.party_type party_type  ----22/12 reqd?
                                            ,hp.party_name party_name
                                            ,hp.person_first_name person_first_name
                                            ,hp.person_middle_name person_middle_name
                                            ,hp.person_last_name person_last_name*/ ----22/12 reqd?
 
 /*,ca.warehouse_id warehouse_id  --Commented as on 22/12
                                            ,(SELECT organization_code
                                              FROM mtl_parameters
                                              WHERE organization_id = ca.warehouse_id) warehouse_value
                                            ,ca.account_activation_date account_activation_date
                                            ,ca.account_termination_date account_termination_date
                                            ,ca.created_by_module created_by_module
                                            ,ca.freight_term freight_term
                                            ,ca.ship_via ship_via
                                            ,ca.primary_specialist_id primary_specialist_id
                                            ,(SELECT employee_number
                                              FROM per_all_people_f ppf
                                              WHERE ppf.person_id = ca.primary_specialist_id) primary_specialist_value
                                            ,ca.ship_sets_include_lines_flag ship_sets_include_lines_flag
                                            ,ca.org_id org_id
                                            ,ca.selling_party_id selling_party_id*/ --Commented as on 22/12
 
 /*,cp.credit_classification credit_classification --Commented as on 22/12
                                            ,cp.review_cycle review_cycle*/ --Commented as on 22/12         
   FROM hz_cust_accounts ca, hz_customer_profiles cp
  WHERE ca.cust_account_id = cp.cust_account_id
    AND cp.site_use_id IS NULL;
  
    /* Cursor for transformation */
  
    CURSOR c_transform IS
      SELECT * FROM xxobjt.xxs3_otc_customer_accounts
       WHERE process_flag <> 'R'
       AND extract_rule_name IS NOT NULL;
  
  BEGIN
  
    x_retcode := 0;
    x_errbuf  := 'COMPLETE';
  
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_otc_customer_accounts';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_otc_customer_accounts_dq';
  
    /* Insert for the Customer */
  
    FOR i IN cur_customer_extract
    LOOP
      /*INSERT INTO xxobjt.xxs3_otc_customer_accounts
        (xx_cust_account_id
        ,legacy_cust_account_id
        ,legacy_account_number
        ,status
        ,account_name
        ,party_id
        --,party_type --Commented 22/12
        ,orig_system_reference
        ,customer_type
        ,payment_term_id
        ,payment_term_value
        ,price_list_id
        ,price_list_value
        ,sales_channel_code
        ,date_type_reference
        ,customer_class_code
        ,warehouse_id
        ,warehouse_value
        ,tax_code
        ,tax_header_level_flag
        ,tax_rounding_rule
        ,account_established_date
        ,account_activation_date
        ,account_termination_date
        ,hold_bill_flag
        ,arrivalsets_include_lines_flag
        ,sched_date_push_flag
        ,tolerance
        ,dunning_letters
        ,send_statements
        ,credit_balance_statements
        ,standard_terms
        ,override_terms
        ,auto_rec_incl_disputed_flag
        ,tax_printing_option
        ,charge_on_finance_charge_flag
        ,cons_inv_flag
        ,currency_code
        ,trx_credit_limit
        ,min_statement_amount
        ,attribute1
        ,attribute2
        ,attribute3
        ,sf_account_id
        ,transfer_to_sf
        ,political_customer
        ,attribute7
        ,shipping_instruction
        ,collect_shipping_account
        ,customer_start_date
        ,inactive_reason
        ,customer_end_date
        ,attribute19
        ,attribute18
        ,fob_point
        ,freight_term
        ,ship_via
        ,primary_specialist_id
        ,primary_specialist_value
        ,ship_sets_include_lines_flag
        ,selling_party_id
        ,creation_date
        ,created_by_module
        ,created_by
        ,exempt_type
        ,credit_hold_reason
        ,score_card
        ,collector_id
        ,collector_name
        ,credit_checking
        ,credit_hold
        ,overall_credit_limit
        ,atradius_id
        ,ci_application_amount
        ,application_date
        ,ci_decision_amounnt
        ,decision_effective_date
        ,expiry_date
        ,buyer_name
        ,match_type
        ,credit_classification
        ,review_cycle
        ,credit_analyst
        ,
         --customer_category_code,
         date_extracted_on
        ,process_flag)
      VALUES
        (xxobjt.xxs3_otc_customer_accounts_seq.NEXTVAL
        ,i.legacy_cust_account_id
        ,i.legacy_account_number
        ,i.status
        ,i.account_name
        ,i.party_id
        --,i.party_type ----Commented 22/12
        ,i.orig_system_reference
        ,i.customer_type
        ,i.payment_term_id
        ,i.payment_term_value
        ,i.price_list_id
        ,i.price_list_value
        ,i.sales_channel_code
        ,i.date_type_preference
        ,i.customer_class_code
        ,i.warehouse_id
        ,i.warehouse_value
        ,i.tax_code
        ,i.tax_header_level_flag
        ,i.tax_rounding_rule
        ,i.account_established_date
        ,i.account_activation_date
        ,i.account_termination_date
        ,i.hold_bill_flag
        ,i.arrivalsets_include_lines_flag
        ,i.sched_date_push_flag
        ,i.tolerance
        ,i.dunning_letters
        ,i.send_statements
        ,i.credit_balance_statements
        ,i.standard_terms
        ,i.override_terms
        ,i.auto_rec_incl_disputed_flag
        ,i.tax_printing_option
        ,i.charge_on_finance_charge_flag
        ,i.cons_inv_flag
        ,i.currency_code
        ,i.trx_credit_limit
        ,i.min_statement_amount
        ,i.attribute1
        ,i.attribute2
        ,i.attribute3
        ,i.sf_account_id
        ,i.transfer_to_sf
        ,i.political_customer
        ,i.attribute7
        ,i.shipping_instruction
        ,i.collect_shipping_account
        ,i.customer_start_date
        ,i.inactive_reason
        ,i.customer_end_date
        ,i.attribute19
        ,i.attribute18
        ,i.fob_point
        ,i.freight_term
        ,i.ship_via
        ,i.primary_specialist_id
        ,i.primary_specialist_value
        ,i.ship_sets_include_lines_flag
        ,i.selling_party_id
        ,i.creation_date
        ,i.created_by_module
        ,i.created_by
        ,i.exempt_type
        ,i.credit_hold_reason
        ,i.score_card
        ,i.collector_id
        ,i.collector_name
        ,i.credit_checking
        ,i.credit_hold
        ,i.overall_credit_limit
        ,i.atradius_id
        ,i.ci_application_amount
        ,i.application_date
        ,i.ci_decision_amounnt
        ,i.decision_effective_date
        ,i.expiry_date
        ,i.buyer_name
        ,i.match_type
        ,i.credit_classification
        ,i.review_cycle
        ,i.credit_analyst
        ,
         --i.customer_category_code,
         SYSDATE
        ,'N');*/
        
        INSERT INTO xxobjt.xxs3_otc_customer_accounts
          (xx_cust_account_id,
           account_established_date,
           account_name,
           legacy_account_number,
           arrivalsets_include_lines_flag,
           --atradius_id,
           attribute1,
           collect_shipping_account,
           customer_start_date,
           inactive_reason,
           customer_end_date,
           credit_hold_reason,
           --ci_application_amount,
           --attribute2,
           --application_date,
           --attribute3,
           exempt_type,
           sf_account_id,
           --ci_decision_amounnt,
           score_card,
           transfer_to_sf,
           --decision_effective_date,
           political_customer,
           --expiry_date,
           --buyer_name,
           shipping_instruction,
           --match_type,
           auto_rec_incl_disputed_flag,
           autocash_hierarchy_id,
           charge_on_finance_charge_flag,
           collector_id,
           collector_emp_number,
           collector_name,
           cons_inv_flag,
           /*credit_analyst_id,
           credit_analyst_name,
           credit_analyst_emp_no,*/
           credit_balance_statements,
           credit_checking,
           credit_hold,
           --currency_code
           /*,cust_account_profile_id
                        ,cust_acct_profile_amt_id*/
           discount_terms,
           dunning_letters,
           grouping_rule_id,
           grouping_rule_name,
           --min_statement_amount,
           --overall_credit_limit,
           override_terms
           --new fields
           --,parent_account_number --commented as on 22/12
           --,attribute7 attribute7 --commented as on 22/12
          ,
           created_by,
           creation_date,
           legacy_cust_account_id,
           customer_class_code,
           customer_type,
           date_type_reference,
           fob_point,
           hold_bill_flag,
           orig_system_reference,
           party_id,
           payment_term_id,
           payment_term_value,
           price_list_id,
           price_list_value,
           sales_channel_code,
           profile_class_id,
           sched_date_push_flag,
           send_statements,
           site_use_id,
           standard_terms,
           statement_cycle_id,
           status,
           tax_code,
           tax_header_level_flag,
           tax_printing_option,
           tax_rounding_rule,
           tolerance,
           --trx_credit_limit,
           warehouse_id,
           warehouse_value,
           freight_term,
           --industry_class_category,
           attribute18,
           profile_Class,
           --registration_status_code,
           --indus_class_category_start,
           --indus_class_category_status,
           profile_status,
           payment_grace_days,
           date_extracted_on
           ,process_flag
           /*ship_via,
           primary_salesrep_name,
           salesrep_emp_number,
           ship_sets_include_lines_flag*/           
           )
        VALUES
          (xxobjt.xxs3_otc_customer_accounts_seq.NEXTVAL,
           i.account_established_date,
           i.account_name,
           i.legacy_account_number,
           i.arrivalsets_include_lines_flag,
           --i.atradius_id,
           i.attribute1,
           i.collect_shipping_account,
           i.customer_start_date,
           i.inactive_reason,
           i.customer_end_date,
           i.credit_hold_reason,
           --i.ci_application_amount,
           /*i.attribute2,
           i.application_date,
           i.attribute3,*/
           i.exempt_type,
           i.sf_account_id,
           --i.ci_decision_amounnt,
           i.score_card,
           i.transfer_to_sf,
           --i.decision_effective_date,
           i.political_customer,
           /*i.expiry_date,
           i.buyer_name,*/
           i.shipping_instruction,
           --i.match_type,
           i.auto_rec_incl_disputed_flag,
           i.autocash_hierarchy_id,
           i.charge_on_finance_charge_flag,
           i.collector_id,
           i.collector_emp_number,
           i.collector_name,
           i.cons_inv_flag,
           /*i.credit_analyst_id,
           i.credit_analyst_name,
           i.credit_analyst_emp_no,*/
           i.credit_balance_statements,
           i.credit_checking,
           i.credit_hold,
           --i.currency_code
           /*,i.cust_account_profile_id
                        ,i.cust_acct_profile_amt_id*/
           i.discount_terms,
           i.dunning_letters,
           i.grouping_rule_id,
           i.grouping_rule_name,
          -- i.min_statement_amount,
           --i.overall_credit_limit,
           i.override_terms,
           --new fields
           --i.parent_account_number ,
           --,i.attribute7 attribute7 --commented as on 22/12
           i.created_by,
           i.creation_date,
           i.legacy_cust_account_id,
           i.customer_class_code,
           i.customer_type,
           i.date_type_preference,
           i.fob_point,
           i.hold_bill_flag,
           i.orig_system_reference,
           i.party_id,
           i.payment_term_id,
           i.payment_term_value,
           i.price_list_id,
           i.price_list_value,
           i.sales_channel_code,
           i.profile_class_id,
           i.sched_date_push_flag,
           i.send_statements,
           i.site_use_id,
           i.standard_terms,
           i.statement_cycle_id,
           i.status,
           i.tax_code,
           i.tax_header_level_flag,
           i.tax_printing_option,
           i.tax_rounding_rule,
           i.tolerance,
           --i.trx_credit_limit,
           i.warehouse_id,
           i.warehouse_value,
           i.freight_term,
           --i.industry_class_category,
           i.attribute18,
           i.profile_Class,
           --i.registration_status_code,
          -- i.indus_class_category_start,
           --i.indus_class_category_status,
           i.profile_status,
           i.payment_grace_days,
           SYSDATE,
           'N'           
           /*i.ship_via,
           i.primary_salesrep_name,
           i.salesrep_emp_number,
           i.ship_sets_include_lines_flag*/ );
    END LOOP;
    COMMIT;
    --
    fnd_file.put_line(fnd_file.log, 'Loading complete');
    --
    --Apply extract Rules
    BEGIN  
      UPDATE xxs3_otc_customer_accounts xoca
         SET xoca.extract_rule_name = CASE WHEN extract_rule_name = NULL THEN 'EXT-002' ELSE extract_rule_name || '|' || 'EXT-002' END
       WHERE EXISTS (SELECT legacy_cust_account_id
                FROM xxobjt.xxs3_otc_cust_acct_sites a
               WHERE a.legacy_cust_account_id = xoca.legacy_cust_account_id --casa.cust_acct_site_id --Commented on 22/12..reqd?
                 AND a.process_flag <> 'R'
                 AND a.extract_rule_name LIKE '%EXT-007%'
                 AND nvl(a.transform_status,'PASS') <> 'FAIL');
                 
      fnd_file.put_line(fnd_file.log,'Extract Rule Name-EXT-002: '||SQL%ROWCOUNT||' rows were updated');             
                 
     UPDATE xxs3_otc_customer_accounts xoca
         SET xoca.extract_rule_name = CASE WHEN extract_rule_name = NULL THEN 'EXT-003' ELSE extract_rule_name || '|' || 'EXT-003' END
       WHERE EXISTS (SELECT legacy_cust_account_id
                FROM xxobjt.xxs3_otc_cust_acct_sites a
               WHERE a.legacy_cust_account_id = xoca.legacy_cust_account_id --casa.cust_acct_site_id --Commented on 22/12..reqd?
                 AND a.process_flag <> 'R'
                 AND a.extract_rule_name LIKE '%EXT-008%'
                 AND nvl(a.transform_status,'PASS') <> 'FAIL'); 
                 
      fnd_file.put_line(fnd_file.log,'Extract Rule Name-EXT-003: '||SQL%ROWCOUNT||' rows were updated');             
                 
      UPDATE xxs3_otc_customer_accounts xoca
         SET xoca.extract_rule_name = CASE WHEN extract_rule_name = NULL THEN 'EXT-004' ELSE extract_rule_name || '|' || 'EXT-004' END
       WHERE EXISTS (SELECT legacy_cust_account_id
                FROM xxobjt.xxs3_otc_cust_acct_sites a
               WHERE a.legacy_cust_account_id = xoca.legacy_cust_account_id --casa.cust_acct_site_id --Commented on 22/12..reqd?
                 AND a.process_flag <> 'R'
                 AND a.extract_rule_name LIKE '%EXT-009%'
                 AND nvl(a.transform_status,'PASS') <> 'FAIL');               
                            
     fnd_file.put_line(fnd_file.log,'Extract Rule Name-EXT-004: '||SQL%ROWCOUNT||' rows were updated');  
                          
    EXCEPTION
      WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log, 'Unexpected error during extract rules update : ' ||
                                 chr(10) || SQLCODE || chr(10) ||
                                 SQLERRM);  
    END; 
    --Apply extract Rules
    COMMIT;
    
    --Auto Cleanse
    BEGIN
      --eqt_003
       FOR j IN (SELECT xx_cust_account_id,
                     account_name,
                     hp.party_type,
                     legacy_cust_account_id 
               FROM xxs3_otc_customer_accounts xoca,
                    hz_parties hp
                WHERE extract_rule_name IS NOT NULL
                 AND xoca.party_id = hp.party_id
                 AND party_type= 'ORGANIZATION'
                 AND regexp_like(account_name, 'Inc\.|INC|Corp\.|CORP|LLC\.|LLC|Ltd\.|LTD\.|LTD|P\.O\.|A\.P\.|A/P|A\.R\.|A/R', 'c'))LOOP
         
          IF xxs3_otc_customer_pkg.get_site_count(j.legacy_cust_account_id) = 'Y' THEN    
           update_account_name(j.xx_cust_account_id, j.account_name);      
          END IF; 
           COMMIT;
           
           UPDATE xxs3_otc_customer_accounts
              SET s3_account_name = account_name
            WHERE s3_account_name IS NULL;
       --eqt_003
    END LOOP; 
     
       cleanse_customer_account;
   
       COMMIT;
    EXCEPTION
     WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log, 'Unexpected error during Autocleanse' ||
                           chr(10) || SQLCODE || chr(10) ||
                           SQLERRM);
    END;
    
     --Auto Cleanse
    BEGIN
      /* Quality Check procedure for Customer Account */
      l_step := 'DQ for Customer Account';
      quality_check_cust_accounts;
      l_step := 'DQ for Customer Profile';
      --quality_check_profiles;
      fnd_file.put_line(fnd_file.log, 'DQ complete');
    
    EXCEPTION
      WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log, 'Unexpected error during DQ validation at step : ' ||l_step||
                           chr(10) || SQLCODE || chr(10) ||
                           SQLERRM);
    END;
    /* Transformation of the attributes */
    BEGIN
      FOR l IN c_transform
      LOOP
        l_step := 'Update price_list_value';
        IF l.price_list_value IS NOT NULL
        THEN
          xxs3_data_transform_util_pkg.transform(p_mapping_type => 'price_list', p_stage_tab => 'xxobjt.XXS3_OTC_CUSTOMER_ACCOUNTS', --Staging Table Name
                                                 p_stage_primary_col => 'xx_cust_account_id', --Staging Table Primary Column Name
                                                 p_stage_primary_col_val => l.xx_cust_account_id, --Staging Table Primary Column Value
                                                 p_legacy_val => l.price_list_value, --Legacy Value
                                                 p_stage_col => 'S3_PRICE_LIST', --Staging Table Name
                                                 p_err_code => l_err_code, -- Output error code
                                                 p_err_msg => l_err_msg);
        END IF;
        IF l.payment_term_value IS NOT NULL 
        THEN
          l_step := 'Update payment_term_value';
          xxs3_data_transform_util_pkg.transform(p_mapping_type => 'payment_term', p_stage_tab => 'xxobjt.XXS3_OTC_CUSTOMER_ACCOUNTS', --Staging Table Name
                                                 p_stage_primary_col => 'xx_cust_account_id', --Staging Table Primary Column Name
                                                 p_stage_primary_col_val => l.xx_cust_account_id, --Staging Table Primary Column Value
                                                 p_legacy_val => l.payment_term_value, --Legacy Value
                                                 p_stage_col => 'S3_PAYMENT_TERM', --Staging Table Name
                                                 p_err_code => l_err_code, -- Output error code
                                                 p_err_msg => l_err_msg);
        END IF;
        IF l.warehouse_value IS NOT NULL 
        THEN
          l_step := 'Update warehouse_value';
          xxs3_data_transform_util_pkg.transform(p_mapping_type => 'inventory_org', p_stage_tab => 'xxobjt.XXS3_OTC_CUSTOMER_ACCOUNTS', --Staging Table Name
                                                 p_stage_primary_col => 'xx_cust_account_id', --Staging Table Primary Column Name
                                                 p_stage_primary_col_val => l.xx_cust_account_id, --Staging Table Primary Column Value
                                                 p_legacy_val => l.warehouse_value, --Legacy Value
                                                 p_stage_col => 'S3_WAREHOUSE', --Staging Table Name
                                                 p_err_code => l_err_code, -- Output error code
                                                 p_err_msg => l_err_msg);
        END IF;
        IF l.freight_term IS NOT NULL               
        THEN
          l_step := 'Update fob_point';
          xxs3_data_transform_util_pkg.transform(p_mapping_type => 'otc_fob_point', p_stage_tab => 'xxobjt.XXS3_OTC_CUSTOMER_ACCOUNTS', --Staging Table Name
                                                 p_stage_primary_col => 'xx_cust_account_id', --Staging Table Primary Column Name
                                                 p_stage_primary_col_val => l.xx_cust_account_id, --Staging Table Primary Column Value
                                                 p_legacy_val => l.freight_term, --Legacy Value
                                                 p_stage_col => 'S3_FOB_POINT', --Staging Table Name
                                                 p_err_code => l_err_code, -- Output error code
                                                 p_err_msg => l_err_msg);
        END IF; 
        IF l.freight_term IS NOT NULL 
        THEN
          l_step := 'Update freight_term';
          xxs3_data_transform_util_pkg.transform(p_mapping_type => 'otc_freight_terms', p_stage_tab => 'xxobjt.XXS3_OTC_CUSTOMER_ACCOUNTS', --Staging Table Name
                                                 p_stage_primary_col => 'xx_cust_account_id', --Staging Table Primary Column Name
                                                 p_stage_primary_col_val => l.xx_cust_account_id, --Staging Table Primary Column Value
                                                 p_legacy_val => l.freight_term, --Legacy Value
                                                 p_stage_col => 'S3_FREIGHT_TERM', --Staging Table Name
                                                 p_err_code => l_err_code, -- Output error code
                                                 p_err_msg => l_err_msg);
        END IF;
      --END LOOP;
       
      END LOOP;
      
            l_step := 'Update grouping rule name';
            
            UPDATE xxs3_otc_customer_accounts 
            SET s3_grouping_rule_name = 'SSYS OM INV GROUPING RULE',
            transform_status ='PASS'
            WHERE grouping_rule_name = 'ORDER MANAGEMENT INV';
       
      COMMIT;
    
     /* FOR m IN (SELECT *
                FROM xxobjt.xxs3_otc_customer_accounts
                WHERE process_flag != 'R')
      LOOP
        \* Transform price list value for s3 value *\
        l_step := 'Update s3_price_list';
        IF m.price_list_value IS NOT NULL
           AND m.s3_price_list IS NULL
        THEN
          UPDATE xxobjt.xxs3_otc_customer_accounts
          SET s3_price_list = m.price_list_value
          WHERE xx_cust_account_id = m.xx_cust_account_id;
        END IF;
      
        \* Transform s3payment term value *\
        IF m.payment_term_value IS NOT NULL
           AND m.s3_payment_term IS NULL
        THEN
          l_step := 'Update s3_payment_term';
          UPDATE xxobjt.xxs3_otc_customer_accounts
          SET s3_payment_term = m.payment_term_value
          WHERE xx_cust_account_id = m.xx_cust_account_id;
        END IF;
        \* Tranform warehouse_value *\
        IF m.warehouse_value IS NOT NULL
           AND m.s3_warehouse IS NULL
        THEN
          l_step := 'Update s3_warehouse';
          UPDATE xxobjt.xxs3_otc_customer_accounts
          SET s3_warehouse = m.warehouse_value
          WHERE xx_cust_account_id = m.xx_cust_account_id;
        END IF;
        \* Transform fob_poing value *\
        IF m.fob_point IS NOT NULL
           AND m.s3_fob_point IS NULL
        THEN
          l_step := 'Update s3_fob_point';
          UPDATE xxobjt.xxs3_otc_customer_accounts
          SET s3_fob_point = m.fob_point
          WHERE xx_cust_account_id = m.xx_cust_account_id;
        END IF;
        \* Transform Freight_term value *\
        IF m.freight_term IS NOT NULL
           AND m.s3_freight_term IS NULL
        THEN
          l_step := 'Update s3_freight_term';
          UPDATE xxobjt.xxs3_otc_customer_accounts
          SET s3_freight_term = m.freight_term
          WHERE xx_cust_account_id = m.xx_cust_account_id;
        END IF;
      END LOOP;*/
    
    EXCEPTION
      WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log, 'Unexpected error during transformation at step : ' ||
                           l_step || chr(10) || SQLCODE ||
                           chr(10) || SQLERRM);
    END;
  
    /* generate csv */
  
    utl_file_generate('CUSTOMER');
    
    --update process_flag='R' and EXTRACT_DQ_ERROR column in all dependent entities
  BEGIN  
    UPDATE xxs3_otc_cust_acct_sites a
       SET process_flag     = 'R',
           extract_dq_error = 'Associated Customer account: '||a.legacy_cust_account_id||'  has DQ error or transformation error'
     WHERE EXISTS
     (SELECT legacy_cust_account_id
              FROM xxs3_otc_customer_accounts b
             WHERE b.legacy_cust_account_id = a.legacy_cust_account_id
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
    /*UPDATE xxs3_otc_cust_acct_site_uses a
       SET process_flag     = 'R',
           extract_dq_error = 'Associated Customer account has DQ error or transformation error'
     WHERE EXISTS
     (SELECT legacy_cust_account_id
              FROM xxs3_otc_customer_accounts b
             WHERE b.legacy_cust_account_id = a.cust_account_id
               AND (nvl(b.transform_status, 'PASS') = 'FAIL' OR
                   b.process_flag = 'R')
               AND b.extract_rule_name is NOT NULL);*/
  
    --Customer
    SELECT COUNT(1)
    INTO l_count_cust
    FROM xxobjt.xxs3_otc_customer_accounts;
  
    fnd_file.put_line(fnd_file.output, rpad('Customer Extract Records Count Report', 100, ' '));
    fnd_file.put_line(fnd_file.output, rpad('============================================================', 200, ' '));
    fnd_file.put_line(fnd_file.output, rpad('Run date and time:    ' ||
                            to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI'), 100, ' '));
    fnd_file.put_line(fnd_file.output, rpad('============================================================', 200, ' '));
    fnd_file.put_line(fnd_file.output, '');
    fnd_file.put_line(fnd_file.output, rpad('Track Name', 10, ' ') ||
                       chr(32) ||
                       rpad('Entity Name', 30, ' ') ||
                       chr(32) ||
                       rpad('Total Count', 15, ' '));
    fnd_file.put_line(fnd_file.output, rpad('===========================================================', 200, ' '));
  
    fnd_file.put_line(fnd_file.output, '');
  
    fnd_file.put_line(fnd_file.output, rpad('OTC', 10, ' ') || ' ' ||
                       rpad('CUSTOMER', 30, ' ') || ' ' ||
                       rpad(l_count_cust, 15, ' '));
    fnd_file.put_line(fnd_file.output, rpad('=========END OF REPORT===============', 200, ' '));
    fnd_file.put_line(fnd_file.output, '');
  
  EXCEPTION
  
    WHEN OTHERS THEN
      x_retcode        := 2;
      x_errbuf         := 'Unexpected error: ' || SQLERRM;
      l_status_message := SQLCODE || chr(10) || SQLERRM;
      fnd_file.put_line(fnd_file.log, 'Unexpected error during data extraction : ' ||
                         chr(10) || l_status_message);
      fnd_file.put_line(fnd_file.log, '--------------------------------------');
    
  END customer_extract_data;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required Customer site uses fields
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0 11/05/2016  Mishal Kumar                  Initial build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE cust_site_uses_extract_data(x_errbuf  OUT VARCHAR2
                                       ,x_retcode OUT NUMBER) IS
    /* Variables */
    l_errbuf                 VARCHAR2(2000);
    l_retcode                VARCHAR2(1);
    l_requestor              NUMBER;
    l_program_short_name     VARCHAR2(100);
    l_status_message         VARCHAR2(4000);
    l_counter                NUMBER;
    lc_s3_fob                VARCHAR2(100);
    l_error_message          VARCHAR2(4000);
    l_error_code             VARCHAR2(50);
    l_count                  NUMBER := 0;
    l_output                 VARCHAR2(4000);
    l_output_code            VARCHAR2(100);
    l_output_coa_update      VARCHAR2(4000);
    l_output_code_coa_update VARCHAR2(100);
    l_s3_gl_string           VARCHAR2(2000);
    l_count1                 NUMBER;
    l_err_code               VARCHAR2(100);
    l_err_msg                VARCHAR2(4000);
    l_step                   VARCHAR2(50);
    l_count_cust_site_use    NUMBER;
    --
   
    /* Cursor for the Customer site use*/
  
   /* CURSOR cur_cust_site_use_extract 
    IS
      SELECT csua.site_use_id legacy_site_use_id
            ,csua.cust_acct_site_id legacy_cust_acct_site_id
            --,ca.cust_account_id cust_account_id --22/12 reqd?
            ,csua.creation_date creation_date
            ,csua.created_by created_by
            ,csua.site_use_code site_use_code
            ,csua.primary_flag primary_flag
            ,csua.status status
            ,csua.location location
            ,csua.contact_id contact_id --22/12 reqd?
            ,(SELECT hoc.contact_number
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
              AND hcar.cust_account_role_id = csua.contact_id) contact_number --22/12 reqd?
            ,csua.bill_to_site_use_id bill_to_site_use_id
            ,csua.payment_term_id payment_term_id
            ,(SELECT NAME
              FROM ra_terms
              WHERE term_id = nvl(to_char(csua.payment_term_id), '-99')) legacy_payment_term
            ,csua.gsa_indicator gsa_indicator
            ,csua.ship_via ship_via
            ,csua.fob_point fob_point
            --,ca.attribute18 incoterm--22/12 reqd?
            --,ca.customer_type--22/12 reqd?
            ,csua.order_type_id order_type_id
            ,(SELECT t.NAME
              FROM oe_transaction_types_tl t
              WHERE t.transaction_type_id = csua.order_type_id
              AND t.LANGUAGE = 'US') order_type_name
            ,csua.price_list_id legacy_price_list_id
            ,(SELECT NAME
              FROM qp_price_lists_v qp
              WHERE qp.price_list_id = csua.price_list_id) price_list_value
            ,csua.freight_term legacy_freight_term
            ,csua.warehouse_id warehouse_id
            ,(SELECT organization_code
              FROM mtl_parameters
              WHERE organization_id = csua.warehouse_id) warehouse_code
            ,csua.territory_id territory_id
            ,(SELECT NAME
              FROM ra_territories
              WHERE territory_id = csua.territory_id) territory_name
            ,csua.attribute_category attribute_category
            ,csua.attribute10 attribute10
            ,csua.attribute12 attribute12
            ,csua.object_version_number object_version_num
            ,csua.org_id legacy_org_id
            ,(SELECT NAME
              FROM hr_operating_units
              WHERE organization_id = csua.org_id) org_name
            ,csua.primary_salesrep_id legacy_primary_salesrep_id
            ,(SELECT NAME
              FROM apps.ra_salesreps_all salerep
              WHERE salesrep_id = csua.primary_salesrep_id
              AND org_id = csua.org_id) primary_salesrep_name
            ,csua.ship_sets_include_lines_flag ship_sets_include_lines_flag
            ,csua.arrivalsets_include_lines_flag arrivalsets_include_lines_flag
            ,csua.sched_date_push_flag sched_date_push_flag
            ,csua.object_version_number object_version_number
            ,csua.gl_id_rec
            ,gl_rec.segment1 gl_id_rec_seg1
            ,gl_rec.segment2 gl_id_rec_seg2
            ,gl_rec.segment3 gl_id_rec_seg3
            ,gl_rec.segment4 gl_id_rec_seg4
            ,gl_rec.segment5 gl_id_rec_seg5
            ,gl_rec.segment6 gl_id_rec_seg6
            ,gl_rec.segment7 gl_id_rec_seg7
            ,gl_rec.segment10 gl_id_rec_seg10
            ,gl_rec.segment9 gl_id_rec_seg9
            ,csua.gl_id_rev
            ,gl_rev.segment1 gl_id_rev_seg1
            ,gl_rev.segment2 gl_id_rev_seg2
            ,gl_rev.segment3 gl_id_rev_seg3
            ,gl_rev.segment4 gl_id_rev_seg4
            ,gl_rev.segment5 gl_id_rev_seg5
            ,gl_rev.segment6 gl_id_rev_seg6
            ,gl_rev.segment7 gl_id_rev_seg7
            ,gl_rev.segment10 gl_id_rev_seg10
            ,gl_rev.segment9 gl_id_rev_seg9
            ,csua.gl_id_tax
            ,gl_tax.segment1 gl_id_tax_seg1
            ,gl_tax.segment2 gl_id_tax_seg2
            ,gl_tax.segment3 gl_id_tax_seg3
            ,gl_tax.segment4 gl_id_tax_seg4
            ,gl_tax.segment5 gl_id_tax_seg5
            ,gl_tax.segment6 gl_id_tax_seg6
            ,gl_tax.segment7 gl_id_tax_seg7
            ,gl_tax.segment10 gl_id_tax_seg10
            ,gl_tax.segment9 gl_id_tax_seg9
            ,csua.gl_id_freight
            ,gl_freight.segment1 gl_id_freight_seg1
            ,gl_freight.segment2 gl_id_freight_seg2
            ,gl_freight.segment3 gl_id_freight_seg3
            ,gl_freight.segment4 gl_id_freight_seg4
            ,gl_freight.segment5 gl_id_freight_seg5
            ,gl_freight.segment6 gl_id_freight_seg6
            ,gl_freight.segment7 gl_id_freight_seg7
            ,gl_freight.segment10 gl_id_freight_seg10
            ,gl_freight.segment9 gl_id_freight_seg9
            ,csua.gl_id_unbilled
            ,gl_unbilled.segment1 gl_id_unbilled_seg1
            ,gl_unbilled.segment2 gl_id_unbilled_seg2
            ,gl_unbilled.segment3 gl_id_unbilled_seg3
            ,gl_unbilled.segment4 gl_id_unbilled_seg4
            ,gl_unbilled.segment5 gl_id_unbilled_seg5
            ,gl_unbilled.segment6 gl_id_unbilled_seg6
            ,gl_unbilled.segment7 gl_id_unbilled_seg7
            ,gl_unbilled.segment10 gl_id_unbilled_seg10
            ,gl_unbilled.segment9 gl_id_unbilled_seg9
            ,csua.gl_id_unearned
            ,gl_unearned.segment1 gl_id_unearned_seg1
            ,gl_unearned.segment2 gl_id_unearned_seg2
            ,gl_unearned.segment3 gl_id_unearned_seg3
            ,gl_unearned.segment4 gl_id_unearned_seg4
            ,gl_unearned.segment5 gl_id_unearned_seg5
            ,gl_unearned.segment6 gl_id_unearned_seg6
            ,gl_unearned.segment7 gl_id_unearned_seg7
            ,gl_unearned.segment10 gl_id_unearned_seg10
            ,gl_unearned.segment9 gl_id_unearned_seg9
      FROM hz_cust_site_uses_all    csua\*--Commented on 22/12..reqd?
          ,hz_cust_acct_sites_all   casa
          ,hz_cust_accounts         ca
          ,hz_parties               p*\--Commented on 22/12..reqd?
          ,gl_code_combinations_kfv gl_rec
          ,gl_code_combinations_kfv gl_rev
          ,gl_code_combinations_kfv gl_tax
          ,gl_code_combinations_kfv gl_freight
          ,gl_code_combinations_kfv gl_unbilled
          ,gl_code_combinations_kfv gl_unearned
      WHERE \*casa.cust_acct_site_id = csua.cust_acct_site_id--Commented on 22/12..reqd?
      AND casa.cust_account_id = ca.cust_account_id
      AND ca.party_id = p.party_id
      AND csua.status = 'A'
      AND casa.status = 'A'
      AND ca.status = 'A'
      AND p.status = 'A'   
      AND EXISTS
       (SELECT legacy_cust_account_site_id
             FROM xxobjt.xxs3_otc_cust_acct_sites a
             WHERE a.legacy_cust_account_site_id = csua.cust_acct_site_id--casa.cust_acct_site_id --Commented on 22/12..reqd?
             AND process_flag <> 'R')          --Commented on 22/12..reqd?    
      AND*\ csua.gl_id_rec = gl_rec.code_combination_id(+)
      AND csua.gl_id_rev = gl_rev.code_combination_id(+)
      AND csua.gl_id_tax = gl_tax.code_combination_id(+)
      AND csua.gl_id_freight = gl_freight.code_combination_id(+)
      AND csua.gl_id_unbilled = gl_unbilled.code_combination_id(+)
      AND csua.gl_id_unearned = gl_unearned.code_combination_id(+);*/
      
      CURSOR cur_cust_site_use_extract 
    IS
      SELECT csua.attribute18,
             csua.warehouse_id warehouse_id,
             (SELECT organization_code
                FROM mtl_parameters
               WHERE organization_id = csua.warehouse_id) warehouse_code,
             csua.arrivalsets_include_lines_flag arrivalsets_include_lines_flag,
             csua.bill_to_site_use_id bill_to_site_use_id,
             csua.created_by created_by,
             csua.creation_date creation_date,
             csua.cust_acct_site_id legacy_cust_acct_site_id,
             csua.freight_term legacy_freight_term,
             csua.gsa_indicator gsa_indicator,
             csua.location location,
             csua.org_id,
             (SELECT NAME
                FROM hr_operating_units
               WHERE organization_id = csua.org_id) org_name,
             csua.payment_term_id payment_term_id,
             (SELECT NAME
                FROM ra_terms
               WHERE term_id = csua.payment_term_id)/*nvl(to_char(csua.payment_term_id), '-99'))*/ payment_term,
             csua.price_list_id legacy_price_list_id,
             (SELECT NAME
                FROM qp_price_lists_v qp
               WHERE qp.price_list_id = csua.price_list_id) price_list_value,
             csua.primary_flag primary_flag,
             csua.primary_salesrep_id legacy_primary_salesrep_id,
             (SELECT NAME
              FROM apps.ra_salesreps_all salerep
              WHERE salesrep_id = csua.primary_salesrep_id
              AND org_id = csua.org_id) primary_salesrep_name,
             (SELECT ppf.employee_number
                FROM apps.per_all_people_f ppf, apps.ra_salesreps_all rs
               WHERE ppf.person_id = rs.person_id
                 AND rs.salesrep_id = csua.primary_salesrep_id
                 AND org_id = csua.org_id
                 AND SYSDATE BETWEEN
                         nvl(ppf.effective_start_date, SYSDATE) AND
                         nvl(ppf.effective_end_date, SYSDATE)) salesrep_emp_number,
             csua.sched_date_push_flag sched_date_push_flag,
             csua.ship_sets_include_lines_flag ship_sets_include_lines_flag,
             csua.site_use_code site_use_code,
             csua.site_use_id legacy_site_use_id,
             csua.status status,
             csua.fob_point,
             csua.gl_id_rec,
             gl_rec.segment1 gl_id_rec_seg1,
             gl_rec.segment2 gl_id_rec_seg2,
             gl_rec.segment3 gl_id_rec_seg3,
             gl_rec.segment4 gl_id_rec_seg4,
             gl_rec.segment5 gl_id_rec_seg5,
             gl_rec.segment6 gl_id_rec_seg6,
             gl_rec.segment7 gl_id_rec_seg7,
             gl_rec.segment10 gl_id_rec_seg10,
             gl_rec.segment9 gl_id_rec_seg9,
             csua.gl_id_rev,
             gl_rev.segment1 gl_id_rev_seg1,
             gl_rev.segment2 gl_id_rev_seg2,
             gl_rev.segment3 gl_id_rev_seg3,
             gl_rev.segment4 gl_id_rev_seg4,
             gl_rev.segment5 gl_id_rev_seg5,
             gl_rev.segment6 gl_id_rev_seg6,
             gl_rev.segment7 gl_id_rev_seg7,
             gl_rev.segment10 gl_id_rev_seg10,
             gl_rev.segment9 gl_id_rev_seg9,
             csua.gl_id_tax,
             gl_tax.segment1 gl_id_tax_seg1,
             gl_tax.segment2 gl_id_tax_seg2,
             gl_tax.segment3 gl_id_tax_seg3,
             gl_tax.segment4 gl_id_tax_seg4,
             gl_tax.segment5 gl_id_tax_seg5,
             gl_tax.segment6 gl_id_tax_seg6,
             gl_tax.segment7 gl_id_tax_seg7,
             gl_tax.segment10 gl_id_tax_seg10,
             gl_tax.segment9 gl_id_tax_seg9,
             csua.gl_id_freight,
             gl_freight.segment1 gl_id_freight_seg1,
             gl_freight.segment2 gl_id_freight_seg2,
             gl_freight.segment3 gl_id_freight_seg3,
             gl_freight.segment4 gl_id_freight_seg4,
             gl_freight.segment5 gl_id_freight_seg5,
             gl_freight.segment6 gl_id_freight_seg6,
             gl_freight.segment7 gl_id_freight_seg7,
             gl_freight.segment10 gl_id_freight_seg10,
             gl_freight.segment9 gl_id_freight_seg9,
             csua.gl_id_unbilled,
             gl_unbilled.segment1 gl_id_unbilled_seg1,
             gl_unbilled.segment2 gl_id_unbilled_seg2,
             gl_unbilled.segment3 gl_id_unbilled_seg3,
             gl_unbilled.segment4 gl_id_unbilled_seg4,
             gl_unbilled.segment5 gl_id_unbilled_seg5,
             gl_unbilled.segment6 gl_id_unbilled_seg6,
             gl_unbilled.segment7 gl_id_unbilled_seg7,
             gl_unbilled.segment10 gl_id_unbilled_seg10,
             gl_unbilled.segment9 gl_id_unbilled_seg9,
             csua.gl_id_unearned,
             gl_unearned.segment1 gl_id_unearned_seg1,
             gl_unearned.segment2 gl_id_unearned_seg2,
             gl_unearned.segment3 gl_id_unearned_seg3,
             gl_unearned.segment4 gl_id_unearned_seg4,
             gl_unearned.segment5 gl_id_unearned_seg5,
             gl_unearned.segment6 gl_id_unearned_seg6,
             gl_unearned.segment7 gl_id_unearned_seg7,
             gl_unearned.segment10 gl_id_unearned_seg10,
             gl_unearned.segment9 gl_id_unearned_seg9,
             csua.gl_id_clearing,
             gl_clearing.segment1 gl_id_clearing_seg1,
             gl_clearing.segment2 gl_id_clearing_seg2,
             gl_clearing.segment3 gl_id_clearing_seg3,
             gl_clearing.segment4 gl_id_clearing_seg4,
             gl_clearing.segment5 gl_id_clearing_seg5,
             gl_clearing.segment6 gl_id_clearing_seg6,
             gl_clearing.segment7 gl_id_clearing_seg7,
             gl_clearing.segment10 gl_id_clearing_seg10,
             gl_clearing.segment9 gl_id_clearing_seg9
             --not in FDD
            ,
             csua.attribute_category attribute_category,
             csua.attribute10        attribute10 --Shipping     
            ,csua.attribute12        attribute12 --Collect Shipping Account
            ,csua.ship_via           ship_via
            ,ca.cust_account_id
        FROM hz_cust_site_uses_all    csua 
                       ,hz_cust_acct_sites_all   casa
                       ,hz_cust_accounts         ca
                      -- ,hz_parties               p- --Commented on 22/12..reqd?
            ,
             gl_code_combinations_kfv gl_rec,
             gl_code_combinations_kfv gl_rev,
             gl_code_combinations_kfv gl_tax,
             gl_code_combinations_kfv gl_freight,
             gl_code_combinations_kfv gl_unbilled,
             gl_code_combinations_kfv gl_unearned,
             gl_code_combinations_kfv gl_clearing
       WHERE  casa.cust_acct_site_id = csua.cust_acct_site_id
            AND casa.cust_account_id = ca.cust_account_id
            /*AND ca.party_id = p.party_id --Commented on 22/12..reqd?
            AND csua.status = 'A'
            AND casa.status = 'A'
            AND ca.status = 'A'
            AND p.status = 'A'   
            AND EXISTS
             (SELECT legacy_cust_account_site_id
                   FROM xxobjt.xxs3_otc_cust_acct_sites a
                   WHERE a.legacy_cust_account_site_id = csua.cust_acct_site_id--casa.cust_acct_site_id --Commented on 22/12..reqd?
                   AND process_flag <> 'R')          --Commented on 22/12..reqd?    */
           
        AND csua.gl_id_rec = gl_rec.code_combination_id(+)
       AND csua.gl_id_rev = gl_rev.code_combination_id(+)
       AND csua.gl_id_tax = gl_tax.code_combination_id(+)
       AND csua.gl_id_freight = gl_freight.code_combination_id(+)
       AND csua.gl_id_unbilled = gl_unbilled.code_combination_id(+)
       AND csua.gl_id_unearned = gl_unearned.code_combination_id(+)
       AND csua.gl_id_clearing = gl_clearing.code_combination_id(+);
/*           
            --,ca.cust_account_id cust_account_id --22/12 reqd?
            ,csua.contact_id contact_id --22/12 reqd?
            ,(SELECT hoc.contact_number
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
              AND hcar.cust_account_role_id = csua.contact_id) contact_number --22/12 reqd?
            --,ca.attribute18 incoterm--22/12 reqd?
            --,ca.customer_type--22/12 reqd?
            ,csua.order_type_id order_type_id
            ,(SELECT t.NAME
              FROM oe_transaction_types_tl t
              WHERE t.transaction_type_id = csua.order_type_id
              AND t.LANGUAGE = 'US') order_type_name 
            ,csua.territory_id territory_id
            ,(SELECT NAME
              FROM ra_territories
              WHERE territory_id = csua.territory_id) territory_name            
            ,csua.object_version_number object_version_num
            ,(SELECT NAME
              FROM apps.ra_salesreps_all salerep
              WHERE salesrep_id = csua.primary_salesrep_id
              AND org_id = csua.org_id) primary_salesrep_name
            ,csua.object_version_number object_version_number
            ,csua.gl_id_rec
            ,gl_rec.segment1 gl_id_rec_seg1
            ,gl_rec.segment2 gl_id_rec_seg2
            ,gl_rec.segment3 gl_id_rec_seg3
            ,gl_rec.segment4 gl_id_rec_seg4
            ,gl_rec.segment5 gl_id_rec_seg5
            ,gl_rec.segment6 gl_id_rec_seg6
            ,gl_rec.segment7 gl_id_rec_seg7
            ,gl_rec.segment10 gl_id_rec_seg10
            ,gl_rec.segment9 gl_id_rec_seg9
            ,csua.gl_id_rev
            ,gl_rev.segment1 gl_id_rev_seg1
            ,gl_rev.segment2 gl_id_rev_seg2
            ,gl_rev.segment3 gl_id_rev_seg3
            ,gl_rev.segment4 gl_id_rev_seg4
            ,gl_rev.segment5 gl_id_rev_seg5
            ,gl_rev.segment6 gl_id_rev_seg6
            ,gl_rev.segment7 gl_id_rev_seg7
            ,gl_rev.segment10 gl_id_rev_seg10
            ,gl_rev.segment9 gl_id_rev_seg9
            ,csua.gl_id_tax
            ,gl_tax.segment1 gl_id_tax_seg1
            ,gl_tax.segment2 gl_id_tax_seg2
            ,gl_tax.segment3 gl_id_tax_seg3
            ,gl_tax.segment4 gl_id_tax_seg4
            ,gl_tax.segment5 gl_id_tax_seg5
            ,gl_tax.segment6 gl_id_tax_seg6
            ,gl_tax.segment7 gl_id_tax_seg7
            ,gl_tax.segment10 gl_id_tax_seg10
            ,gl_tax.segment9 gl_id_tax_seg9
            ,csua.gl_id_freight
            ,gl_freight.segment1 gl_id_freight_seg1
            ,gl_freight.segment2 gl_id_freight_seg2
            ,gl_freight.segment3 gl_id_freight_seg3
            ,gl_freight.segment4 gl_id_freight_seg4
            ,gl_freight.segment5 gl_id_freight_seg5
            ,gl_freight.segment6 gl_id_freight_seg6
            ,gl_freight.segment7 gl_id_freight_seg7
            ,gl_freight.segment10 gl_id_freight_seg10
            ,gl_freight.segment9 gl_id_freight_seg9
            ,csua.gl_id_unbilled
            ,gl_unbilled.segment1 gl_id_unbilled_seg1
            ,gl_unbilled.segment2 gl_id_unbilled_seg2
            ,gl_unbilled.segment3 gl_id_unbilled_seg3
            ,gl_unbilled.segment4 gl_id_unbilled_seg4
            ,gl_unbilled.segment5 gl_id_unbilled_seg5
            ,gl_unbilled.segment6 gl_id_unbilled_seg6
            ,gl_unbilled.segment7 gl_id_unbilled_seg7
            ,gl_unbilled.segment10 gl_id_unbilled_seg10
            ,gl_unbilled.segment9 gl_id_unbilled_seg9
            ,csua.gl_id_unearned
            ,gl_unearned.segment1 gl_id_unearned_seg1
            ,gl_unearned.segment2 gl_id_unearned_seg2
            ,gl_unearned.segment3 gl_id_unearned_seg3
            ,gl_unearned.segment4 gl_id_unearned_seg4
            ,gl_unearned.segment5 gl_id_unearned_seg5
            ,gl_unearned.segment6 gl_id_unearned_seg6
            ,gl_unearned.segment7 gl_id_unearned_seg7
            ,gl_unearned.segment10 gl_id_unearned_seg10
            ,gl_unearned.segment9 gl_id_unearned_seg9 */       -- commented out as per FDD on 27.12.2016 
  
    TYPE t_cust_site_use IS TABLE OF cur_cust_site_use_extract%ROWTYPE INDEX BY PLS_INTEGER;
    l_cust_site_use t_cust_site_use;
  
  
  BEGIN
    x_retcode := 0;
    x_errbuf  := 'COMPLETE';
  
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_otc_cust_acct_site_uses';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_otc_cus_act_site_uses_dq';
    --
    /* Insert of the Customer Site Use */
  
    /* FOR j IN cur_cust_site_use_extract 
    LOOP*/
   BEGIN 
    fnd_file.put_line(fnd_file.output,'Start extracting');
    OPEN cur_cust_site_use_extract;
    LOOP
      FETCH cur_cust_site_use_extract BULK COLLECT
        INTO l_cust_site_use;
    
      FORALL i IN 1 .. l_cust_site_use.COUNT
        /*INSERT INTO xxobjt.xxs3_otc_cust_acct_site_uses
          (xx_cust_acct_site_use_id
          ,
           --site_use_id,
           legacy_site_use_id
          ,legacy_cust_acct_site_id
          --,cust_account_id --22/12 reqd?
          ,creation_date
          ,created_by
          ,site_use_code
          ,primary_flag
          ,status
          ,location
          ,contact_id
          ,contact_number
          ,bill_to_site_use_id
          ,payment_term_id
          ,payment_term
          ,
           --s3_payment_term,
           gsa_indicator
          ,ship_via
          --,incoterm --22/12 reqd?
          --,customer_type --22/12 reqd?
          ,fob_point
          ,
           --s3_fob_point,
           order_type_id
          ,order_type_name
          ,price_list_id
          ,
           --s3_price_list_id,
           price_list_value
          ,freight_term
          ,
           --s3_freight_term,--
           warehouse_id
          ,warehouse_code
          ,territory_id
          ,territory_name
          ,attribute_category
          ,attribute10
          ,attribute12
          ,org_id
          ,org_name
          ,
           \*s3_org_id,*\primary_salesrep_id
          ,s3_primary_salesrep_id
          ,primary_salesrep_name
          ,ship_sets_include_lines_flag
          ,arrivalsets_include_lines_flag
          ,sched_date_push_flag
          ,object_version_number
          ,gl_id_rec
          ,gl_id_rec_seg1
          ,gl_id_rec_seg2
          ,gl_id_rec_seg3
          ,gl_id_rec_seg4
          ,gl_id_rec_seg5
          ,gl_id_rec_seg6
          ,gl_id_rec_seg7
          ,gl_id_rec_seg10
          ,gl_id_rec_seg9
          ,gl_id_rev
          ,gl_id_rev_seg1
          ,gl_id_rev_seg2
          ,gl_id_rev_seg3
          ,gl_id_rev_seg4
          ,gl_id_rev_seg5
          ,gl_id_rev_seg6
          ,gl_id_rev_seg7
          ,gl_id_rev_seg10
          ,gl_id_rev_seg9
          ,gl_id_tax
          ,gl_id_tax_seg1
          ,gl_id_tax_seg2
          ,gl_id_tax_seg3
          ,gl_id_tax_seg4
          ,gl_id_tax_seg5
          ,gl_id_tax_seg6
          ,gl_id_tax_seg7
          ,gl_id_tax_seg10
          ,gl_id_tax_seg9
          ,gl_id_freight
          ,gl_id_freight_seg1
          ,gl_id_freight_seg2
          ,gl_id_freight_seg3
          ,gl_id_freight_seg4
          ,gl_id_freight_seg5
          ,gl_id_freight_seg6
          ,gl_id_freight_seg7
          ,gl_id_freight_seg10
          ,gl_id_freight_seg9
          ,gl_id_unbilled
          ,gl_id_unbilled_seg1
          ,gl_id_unbilled_seg2
          ,gl_id_unbilled_seg3
          ,gl_id_unbilled_seg4
          ,gl_id_unbilled_seg5
          ,gl_id_unbilled_seg6
          ,gl_id_unbilled_seg7
          ,gl_id_unbilled_seg10
          ,gl_id_unbilled_seg9
          ,gl_id_unearned
          ,gl_id_unearned_seg1
          ,gl_id_unearned_seg2
          ,gl_id_unearned_seg3
          ,gl_id_unearned_seg4
          ,gl_id_unearned_seg5
          ,gl_id_unearned_seg6
          ,gl_id_unearned_seg7
          ,gl_id_unearned_seg10
          ,gl_id_unearned_seg9
          ,date_extracted_on
          ,process_flag)
        VALUES
          (xxobjt.xxs3_otc_cus_act_site_uses_seq.NEXTVAL
          ,
           --NULL,
           l_cust_site_use(i).legacy_site_use_id
          ,l_cust_site_use(i).legacy_cust_acct_site_id
          --,l_cust_site_use(i).cust_account_id --22/12 reqd?
          ,l_cust_site_use(i).creation_date
          ,l_cust_site_use(i).created_by
          ,l_cust_site_use(i).site_use_code
          ,l_cust_site_use(i).primary_flag
          ,l_cust_site_use(i).status
          ,l_cust_site_use(i).location
          ,l_cust_site_use(i).contact_id
          ,l_cust_site_use(i).contact_number
          ,l_cust_site_use(i).bill_to_site_use_id
          ,l_cust_site_use(i).payment_term_id
          ,l_cust_site_use(i).legacy_payment_term
          ,
           --l_cust_site_use(i).s3_payment_term,
           l_cust_site_use(i).gsa_indicator
          ,l_cust_site_use(i).ship_via
          --,l_cust_site_use(i).incoterm --22/12 reqd?
          --,l_cust_site_use(i).customer_type --22/12 reqd?
          ,l_cust_site_use(i).fob_point
          ,
           --NULL, --as instructed by Deb--s3_fob_point
           l_cust_site_use(i).order_type_id
          ,l_cust_site_use(i).order_type_name
          ,l_cust_site_use(i).legacy_price_list_id
          ,
           --'31008', --as instructed by Sandeep--s3_price_list_id
           l_cust_site_use(i).price_list_value
          ,l_cust_site_use(i).legacy_freight_term
          ,
           --NULL, --as instructed by Deb
           l_cust_site_use(i).warehouse_id
          ,l_cust_site_use(i).warehouse_code
          ,l_cust_site_use(i).territory_id
          ,l_cust_site_use(i).territory_name
          ,l_cust_site_use(i).attribute_category
          ,l_cust_site_use(i).attribute10
          ,l_cust_site_use(i).attribute12
          ,l_cust_site_use(i).legacy_org_id
          ,l_cust_site_use(i).org_name
          ,
           \*l_cust_site_use(i).s3_org_id,*\ l_cust_site_use(i)
           .legacy_primary_salesrep_id
          ,'-3'
          , ----as instructed by Sandeep
           l_cust_site_use(i).primary_salesrep_name
          ,l_cust_site_use(i).ship_sets_include_lines_flag
          ,l_cust_site_use(i).arrivalsets_include_lines_flag
          ,l_cust_site_use(i).sched_date_push_flag
          ,l_cust_site_use(i).object_version_num
          ,l_cust_site_use(i).gl_id_rec
          ,l_cust_site_use(i).gl_id_rec_seg1
          ,l_cust_site_use(i).gl_id_rec_seg2
          ,l_cust_site_use(i).gl_id_rec_seg3
          ,l_cust_site_use(i).gl_id_rec_seg4
          ,l_cust_site_use(i).gl_id_rec_seg5
          ,l_cust_site_use(i).gl_id_rec_seg6
          ,l_cust_site_use(i).gl_id_rec_seg7
          ,l_cust_site_use(i).gl_id_rec_seg10
          ,l_cust_site_use(i).gl_id_rec_seg9
          ,l_cust_site_use(i).gl_id_rev
          ,l_cust_site_use(i).gl_id_rev_seg1
          ,l_cust_site_use(i).gl_id_rev_seg2
          ,l_cust_site_use(i).gl_id_rev_seg3
          ,l_cust_site_use(i).gl_id_rev_seg4
          ,l_cust_site_use(i).gl_id_rev_seg5
          ,l_cust_site_use(i).gl_id_rev_seg6
          ,l_cust_site_use(i).gl_id_rev_seg7
          ,l_cust_site_use(i).gl_id_rev_seg10
          ,l_cust_site_use(i).gl_id_rev_seg9
          ,l_cust_site_use(i).gl_id_tax
          ,l_cust_site_use(i).gl_id_tax_seg1
          ,l_cust_site_use(i).gl_id_tax_seg2
          ,l_cust_site_use(i).gl_id_tax_seg3
          ,l_cust_site_use(i).gl_id_tax_seg4
          ,l_cust_site_use(i).gl_id_tax_seg5
          ,l_cust_site_use(i).gl_id_tax_seg6
          ,l_cust_site_use(i).gl_id_tax_seg7
          ,l_cust_site_use(i).gl_id_tax_seg10
          ,l_cust_site_use(i).gl_id_tax_seg9
          ,l_cust_site_use(i).gl_id_freight
          ,l_cust_site_use(i).gl_id_freight_seg1
          ,l_cust_site_use(i).gl_id_freight_seg2
          ,l_cust_site_use(i).gl_id_freight_seg3
          ,l_cust_site_use(i).gl_id_freight_seg4
          ,l_cust_site_use(i).gl_id_freight_seg5
          ,l_cust_site_use(i).gl_id_freight_seg6
          ,l_cust_site_use(i).gl_id_freight_seg7
          ,l_cust_site_use(i).gl_id_freight_seg10
          ,l_cust_site_use(i).gl_id_freight_seg9
          ,l_cust_site_use(i).gl_id_unbilled
          ,l_cust_site_use(i).gl_id_unbilled_seg1
          ,l_cust_site_use(i).gl_id_unbilled_seg2
          ,l_cust_site_use(i).gl_id_unbilled_seg3
          ,l_cust_site_use(i).gl_id_unbilled_seg4
          ,l_cust_site_use(i).gl_id_unbilled_seg5
          ,l_cust_site_use(i).gl_id_unbilled_seg6
          ,l_cust_site_use(i).gl_id_unbilled_seg7
          ,l_cust_site_use(i).gl_id_unbilled_seg10
          ,l_cust_site_use(i).gl_id_unbilled_seg9
          ,l_cust_site_use(i).gl_id_unearned
          ,l_cust_site_use(i).gl_id_unearned_seg1
          ,l_cust_site_use(i).gl_id_unearned_seg2
          ,l_cust_site_use(i).gl_id_unearned_seg3
          ,l_cust_site_use(i).gl_id_unearned_seg4
          ,l_cust_site_use(i).gl_id_unearned_seg5
          ,l_cust_site_use(i).gl_id_unearned_seg6
          ,l_cust_site_use(i).gl_id_unearned_seg7
          ,l_cust_site_use(i).gl_id_unearned_seg10
          ,l_cust_site_use(i).gl_id_unearned_seg9
          ,SYSDATE
          ,'N');*/
          
          INSERT INTO xxobjt.xxs3_otc_cust_acct_site_uses
          (xx_cust_acct_site_use_id
          ,incoterm
          ,warehouse_id
          ,warehouse_code
          ,arrivalsets_include_lines_flag
          ,bill_to_site_use_id
          ,created_by
          ,creation_date
          ,legacy_cust_acct_site_id          
          ,freight_term
          ,gsa_indicator
          ,location
          ,org_id
          ,org_name
          ,payment_term_id
          ,payment_term
          ,price_list_id
          ,price_list_value
          ,primary_flag
          ,primary_salesrep_id
          ,primary_salesrep_name
          ,salesrep_emp_number
          ,sched_date_push_flag
          ,ship_sets_include_lines_flag
          ,site_use_code
          ,legacy_site_use_id
          ,status
          ,fob_point          
          ,gl_id_freight
          ,gl_id_freight_seg1
          ,gl_id_freight_seg2
          ,gl_id_freight_seg3
          ,gl_id_freight_seg4
          ,gl_id_freight_seg5
          ,gl_id_freight_seg6
          ,gl_id_freight_seg7
          ,gl_id_freight_seg10
          ,gl_id_freight_seg9
          ,gl_id_rec
          ,gl_id_rec_seg1
          ,gl_id_rec_seg2
          ,gl_id_rec_seg3
          ,gl_id_rec_seg4
          ,gl_id_rec_seg5
          ,gl_id_rec_seg6
          ,gl_id_rec_seg7
          ,gl_id_rec_seg10
          ,gl_id_rec_seg9
          ,gl_id_rev
          ,gl_id_rev_seg1
          ,gl_id_rev_seg2
          ,gl_id_rev_seg3
          ,gl_id_rev_seg4
          ,gl_id_rev_seg5
          ,gl_id_rev_seg6
          ,gl_id_rev_seg7
          ,gl_id_rev_seg10
          ,gl_id_rev_seg9
          ,gl_id_tax
          ,gl_id_tax_seg1
          ,gl_id_tax_seg2
          ,gl_id_tax_seg3
          ,gl_id_tax_seg4
          ,gl_id_tax_seg5
          ,gl_id_tax_seg6
          ,gl_id_tax_seg7
          ,gl_id_tax_seg10
          ,gl_id_tax_seg9          
          ,gl_id_unbilled
          ,gl_id_unbilled_seg1
          ,gl_id_unbilled_seg2
          ,gl_id_unbilled_seg3
          ,gl_id_unbilled_seg4
          ,gl_id_unbilled_seg5
          ,gl_id_unbilled_seg6
          ,gl_id_unbilled_seg7
          ,gl_id_unbilled_seg10
          ,gl_id_unbilled_seg9
          ,gl_id_unearned
          ,gl_id_unearned_seg1
          ,gl_id_unearned_seg2
          ,gl_id_unearned_seg3
          ,gl_id_unearned_seg4
          ,gl_id_unearned_seg5
          ,gl_id_unearned_seg6
          ,gl_id_unearned_seg7
          ,gl_id_unearned_seg10
          ,gl_id_unearned_seg9
          ,gl_id_clearing
          ,gl_id_clearing_seg1
          ,gl_id_clearing_seg2
          ,gl_id_clearing_seg3
          ,gl_id_clearing_seg4
          ,gl_id_clearing_seg5
          ,gl_id_clearing_seg6
          ,gl_id_clearing_seg7
          ,gl_id_clearing_seg10
          ,gl_id_clearing_seg9
          ,attribute_category
          ,attribute10
          ,attribute12
          ,ship_via
          ,cust_account_id
          ,date_extracted_on
          ,process_flag
        /* --,cust_account_id --22/12 reqd?
          ,contact_id
          ,contact_number          
          --,incoterm --22/12 reqd?
          --,customer_type --22/12 reqd?
          
          ,
           --s3_fob_point,
           order_type_id
          ,order_type_name
          ,territory_id
          ,territory_name          
          ,primary_salesrep_name
          ,sched_date_push_flag
          ,object_version_number          
          */) 
         VALUES
          (xxobjt.xxs3_otc_cus_act_site_uses_seq.NEXTVAL
          ,l_cust_site_use(i).ATTRIBUTE18   -- newly added
          ,l_cust_site_use(i).warehouse_id
          ,l_cust_site_use(i).warehouse_code
          ,l_cust_site_use(i).arrivalsets_include_lines_flag
          ,l_cust_site_use(i).bill_to_site_use_id
          ,l_cust_site_use(i).created_by
          ,l_cust_site_use(i).creation_date
          ,l_cust_site_use(i).legacy_cust_acct_site_id
          ,l_cust_site_use(i).legacy_freight_term
          ,l_cust_site_use(i).gsa_indicator
          ,l_cust_site_use(i).location
          ,l_cust_site_use(i).org_id
          ,l_cust_site_use(i).org_name
          ,l_cust_site_use(i).payment_term_id
          ,l_cust_site_use(i).payment_term
          ,l_cust_site_use(i).legacy_price_list_id
          ,l_cust_site_use(i).price_list_value
          ,l_cust_site_use(i).primary_flag
          ,l_cust_site_use(i).legacy_primary_salesrep_id
          ,l_cust_site_use(i).primary_salesrep_name
          ,l_cust_site_use(i).salesrep_emp_number
          ,l_cust_site_use(i).sched_date_push_flag
          ,l_cust_site_use(i).ship_sets_include_lines_flag
          ,l_cust_site_use(i).site_use_code
          ,l_cust_site_use(i).legacy_site_use_id
          ,l_cust_site_use(i).status
          ,l_cust_site_use(i).fob_point
          ,l_cust_site_use(i).gl_id_freight
          ,l_cust_site_use(i).gl_id_freight_seg1
          ,l_cust_site_use(i).gl_id_freight_seg2
          ,l_cust_site_use(i).gl_id_freight_seg3
          ,l_cust_site_use(i).gl_id_freight_seg4
          ,l_cust_site_use(i).gl_id_freight_seg5
          ,l_cust_site_use(i).gl_id_freight_seg6
          ,l_cust_site_use(i).gl_id_freight_seg7
          ,l_cust_site_use(i).gl_id_freight_seg10
          ,l_cust_site_use(i).gl_id_freight_seg9
          ,l_cust_site_use(i).gl_id_rec
          ,l_cust_site_use(i).gl_id_rec_seg1
          ,l_cust_site_use(i).gl_id_rec_seg2
          ,l_cust_site_use(i).gl_id_rec_seg3
          ,l_cust_site_use(i).gl_id_rec_seg4
          ,l_cust_site_use(i).gl_id_rec_seg5
          ,l_cust_site_use(i).gl_id_rec_seg6
          ,l_cust_site_use(i).gl_id_rec_seg7
          ,l_cust_site_use(i).gl_id_rec_seg10
          ,l_cust_site_use(i).gl_id_rec_seg9
          ,l_cust_site_use(i).gl_id_rev
          ,l_cust_site_use(i).gl_id_rev_seg1
          ,l_cust_site_use(i).gl_id_rev_seg2
          ,l_cust_site_use(i).gl_id_rev_seg3
          ,l_cust_site_use(i).gl_id_rev_seg4
          ,l_cust_site_use(i).gl_id_rev_seg5
          ,l_cust_site_use(i).gl_id_rev_seg6
          ,l_cust_site_use(i).gl_id_rev_seg7
          ,l_cust_site_use(i).gl_id_rev_seg10
          ,l_cust_site_use(i).gl_id_rev_seg9
          ,l_cust_site_use(i).gl_id_tax
          ,l_cust_site_use(i).gl_id_tax_seg1
          ,l_cust_site_use(i).gl_id_tax_seg2
          ,l_cust_site_use(i).gl_id_tax_seg3
          ,l_cust_site_use(i).gl_id_tax_seg4
          ,l_cust_site_use(i).gl_id_tax_seg5
          ,l_cust_site_use(i).gl_id_tax_seg6
          ,l_cust_site_use(i).gl_id_tax_seg7
          ,l_cust_site_use(i).gl_id_tax_seg10
          ,l_cust_site_use(i).gl_id_tax_seg9          
          ,l_cust_site_use(i).gl_id_unbilled
          ,l_cust_site_use(i).gl_id_unbilled_seg1
          ,l_cust_site_use(i).gl_id_unbilled_seg2
          ,l_cust_site_use(i).gl_id_unbilled_seg3
          ,l_cust_site_use(i).gl_id_unbilled_seg4
          ,l_cust_site_use(i).gl_id_unbilled_seg5
          ,l_cust_site_use(i).gl_id_unbilled_seg6
          ,l_cust_site_use(i).gl_id_unbilled_seg7
          ,l_cust_site_use(i).gl_id_unbilled_seg10
          ,l_cust_site_use(i).gl_id_unbilled_seg9
          ,l_cust_site_use(i).gl_id_unearned
          ,l_cust_site_use(i).gl_id_unearned_seg1
          ,l_cust_site_use(i).gl_id_unearned_seg2
          ,l_cust_site_use(i).gl_id_unearned_seg3
          ,l_cust_site_use(i).gl_id_unearned_seg4
          ,l_cust_site_use(i).gl_id_unearned_seg5
          ,l_cust_site_use(i).gl_id_unearned_seg6
          ,l_cust_site_use(i).gl_id_unearned_seg7
          ,l_cust_site_use(i).gl_id_unearned_seg10
          ,l_cust_site_use(i).gl_id_unearned_seg9
          ,l_cust_site_use(i).gl_id_clearing
          ,l_cust_site_use(i).gl_id_clearing_seg1
          ,l_cust_site_use(i).gl_id_clearing_seg2
          ,l_cust_site_use(i).gl_id_clearing_seg3
          ,l_cust_site_use(i).gl_id_clearing_seg4
          ,l_cust_site_use(i).gl_id_clearing_seg5
          ,l_cust_site_use(i).gl_id_clearing_seg6
          ,l_cust_site_use(i).gl_id_clearing_seg7
          ,l_cust_site_use(i).gl_id_clearing_seg10
          ,l_cust_site_use(i).gl_id_clearing_seg9
          ,l_cust_site_use(i).attribute_category
          ,l_cust_site_use(i).attribute10
          ,l_cust_site_use(i).attribute12
          ,l_cust_site_use(i).ship_via
          ,l_cust_site_use(i).cust_account_id
          ,SYSDATE
          ,'N'
         /* ,
           --NULL,

          --,l_cust_site_use(i).cust_account_id --22/12 reqd?
          ,l_cust_site_use(i).contact_id
          ,l_cust_site_use(i).contact_number           
          --,l_cust_site_use(i).incoterm --22/12 reqd?
          --,l_cust_site_use(i).customer_type --22/12 reqd?    
           l_cust_site_use(i).order_type_id
          ,l_cust_site_use(i).order_type_name
          ,l_cust_site_use(i).territory_id
          ,l_cust_site_use(i).territory_name  
           l_cust_site_use(i).object_version_num          
          */); 
      EXIT WHEN cur_cust_site_use_extract%NOTFOUND;
    END LOOP;
    CLOSE cur_cust_site_use_extract;
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
    UPDATE xxs3_otc_cust_acct_site_uses xocsu
       SET xocsu.extract_rule_name = CASE WHEN extract_rule_name = NULL THEN 'EXT-007' ELSE extract_rule_name || '|' || 'EXT-007' END
     WHERE EXISTS
     (SELECT legacy_cust_account_site_id
              FROM xxobjt.xxs3_otc_cust_acct_sites a
             WHERE a.legacy_cust_account_site_id = xocsu.legacy_cust_acct_site_id --casa.cust_acct_site_id --Commented on 22/12..reqd?
               AND a.process_flag <> 'R'
               AND a.extract_rule_name LIKE '%EXT-007%'
               AND nvl(a.transform_status,'PASS') <> 'FAIL');
               
    fnd_file.put_line(fnd_file.log,'Extract Rule Name-EXT-007: '||SQL%ROWCOUNT||' rows were updated');          
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log, 'Unexpected error during extract rules update : ' ||
                               chr(10) || SQLCODE || chr(10) ||
                               SQLERRM);  
  END; 
    --Apply extract Rules
    COMMIT;
    --
    --Autocleanse
   BEGIN 
    cleanse_customer_site_use;
    
    COMMIT;
   EXCEPTION
      WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log, 'Unexpected error during Autocleanse : ' ||
                           chr(10) || SQLCODE || chr(10) ||
                           SQLERRM);
    END;
    
    --Autocleanse
    /* Quality check procedure call */
    BEGIN
      quality_check_cust_site_uses;
      
      COMMIT;
    EXCEPTION
      WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log, 'Unexpected error during DQ validation : ' ||
                           chr(10) || SQLCODE || chr(10) ||
                           SQLERRM);
    END;
    --Transformation
    BEGIN
      FOR k IN (SELECT *
                FROM xxobjt.xxs3_otc_cust_acct_site_uses
                WHERE process_flag <> 'R'
                AND extract_rule_name IS NOT NULL) LOOP
                
                
        /*    IF k.org_id = g_org_id AND k.site_use_code = 'BILL_TO' THEN
          IF k.customer_type = 'I' THEN
            UPDATE xxobjt.xxs3_otc_cust_acct_site_uses
               SET customer_class_code = 'INTERCOMPANY'
             WHERE xx_cust_acct_site_use_id = k.xx_cust_acct_site_use_id;
          ELSIF k.customer_type = 'R' AND k.sales_channel_code = 'INDIRECT' THEN
            UPDATE xxobjt.xxs3_otc_cust_acct_site_uses
               SET customer_class_code = 'INTERNATIONAL/LATAM'
             WHERE xx_cust_acct_site_use_id = k.xx_cust_acct_site_use_id;
          ELSIF k.customer_type = 'R' AND k.sales_channel_code = 'DIRECT' THEN
            SELECT COUNT(1)
              INTO l_count1
              FROM hz_party_site_uses hpu,
                   hz_party_sites     hpi,
                   hz_cust_accounts   hca
             WHERE hca.party_id = hpi.party_id
               AND hpi.party_site_id = hpu.party_site_id
               AND hca.party_id = k.party_id
               AND site_use_type = 'INSTALL_AT';
            IF l_count1 = 1 THEN
              UPDATE xxobjt.xxs3_otc_cust_acct_site_uses
                 SET customer_class_code = 'LEASE'
               WHERE xx_cust_acct_site_use_id = k.xx_cust_acct_site_use_id;
            ELSE
              UPDATE xxobjt.xxs3_otc_cust_acct_site_uses
                 SET customer_class_code = 'TRADE'
               WHERE xx_cust_acct_site_use_id = k.xx_cust_acct_site_use_id;
            END IF;
          
          END IF;
        END IF;*/
      
        /*IF k.gl_id_rec IS NOT NULL AND k.org_id = g_org_id THEN
          l_step := 'Update gl_id_rec';
        
          UPDATE xxobjt.xxs3_otc_cust_acct_site_uses
          SET gl_id_rec = NULL
          WHERE xx_cust_acct_site_use_id = k.xx_cust_acct_site_use_id;
        END IF;
      
        IF k.gl_id_rev IS NOT NULL AND k.org_id = g_org_id THEN
          l_step := 'Update gl_id_rev';
        
          UPDATE xxobjt.xxs3_otc_cust_acct_site_uses
          SET gl_id_rev = NULL
          WHERE xx_cust_acct_site_use_id = k.xx_cust_acct_site_use_id;
        END IF;
      
        IF k.gl_id_tax IS NOT NULL AND k.org_id = g_org_id THEN
          l_step := 'Update gl_id_tax';
        
          UPDATE xxobjt.xxs3_otc_cust_acct_site_uses
          SET gl_id_tax = NULL
          WHERE xx_cust_acct_site_use_id = k.xx_cust_acct_site_use_id;
        END IF;
      
        IF k.gl_id_freight IS NOT NULL AND k.org_id = g_org_id THEN
          l_step := 'Update gl_id_freight';
        
          UPDATE xxobjt.xxs3_otc_cust_acct_site_uses
          SET gl_id_freight = NULL
          WHERE xx_cust_acct_site_use_id = k.xx_cust_acct_site_use_id;
        END IF;
      
        IF k.gl_id_unbilled IS NOT NULL AND k.org_id = g_org_id THEN
          l_step := 'Update gl_id_unbilled';
        
          UPDATE xxobjt.xxs3_otc_cust_acct_site_uses
          SET gl_id_unbilled = NULL
          WHERE xx_cust_acct_site_use_id = k.xx_cust_acct_site_use_id;
        END IF;
      
        IF k.gl_id_unearned IS NOT NULL AND k.org_id = g_org_id THEN
          l_step := 'Update gl_id_unearned';
        
          UPDATE xxobjt.xxs3_otc_cust_acct_site_uses
          SET gl_id_unearned = NULL
          WHERE xx_cust_acct_site_use_id = k.xx_cust_acct_site_use_id;
        END IF;*/
      
        /* Transformation for s3 values */
      
        IF k.payment_term IS NOT NULL AND k.s3_payment_term IS NULL
        THEN
          l_step := 'Update payment_terms';
          xxs3_data_transform_util_pkg.transform(p_mapping_type => 'payment_term', p_stage_tab => 'xxobjt.xxs3_otc_cust_acct_site_uses', --Staging Table Name
                                                 p_stage_primary_col => 'xx_cust_acct_site_use_id', --Staging Table Primary Column Name
                                                 p_stage_primary_col_val => k.xx_cust_acct_site_use_id, --Staging Table Primary Column Value
                                                 p_legacy_val => k.payment_term, --Legacy Value
                                                 p_stage_col => 'S3_PAYMENT_TERM', --Staging Table Name
                                                 p_err_code => l_err_code, -- Output error code
                                                 p_err_msg => l_err_msg);
        END IF;
      
        IF k.price_list_value IS NOT NULL /*AND k.s3_price_list_value IS NOT NULL*/
        THEN
          l_step := 'Update price_list_value';
          xxs3_data_transform_util_pkg.transform(p_mapping_type => 'price_list', p_stage_tab => 'xxobjt.xxs3_otc_cust_acct_site_uses', --Staging Table Name
                                                 p_stage_primary_col => 'xx_cust_acct_site_use_id', --Staging Table Primary Column Name
                                                 p_stage_primary_col_val => k.xx_cust_acct_site_use_id, --Staging Table Primary Column Value
                                                 p_legacy_val => k.price_list_value, --Legacy Value
                                                 p_stage_col => 'S3_PRICE_LIST_value', --Staging Table Name
                                                 p_err_code => l_err_code, -- Output error code
                                                 p_err_msg => l_err_msg);
        END IF;
        IF k.warehouse_code IS NOT NULL
           AND k.org_id = g_org_id
        THEN
          l_step := 'Update warehouse_code';
          xxs3_data_transform_util_pkg.transform(p_mapping_type => 'inventory_org', p_stage_tab => 'xxobjt.xxs3_otc_cust_acct_site_uses', --Staging Table Name
                                                 p_stage_primary_col => 'xx_cust_acct_site_use_id', --Staging Table Primary Column Name
                                                 p_stage_primary_col_val => k.xx_cust_acct_site_use_id, --Staging Table Primary Column Value
                                                 p_legacy_val => k.warehouse_code, --Legacy Value
                                                 p_stage_col => 's3_warehouse_code', --Staging Table Name
                                                 p_err_code => l_err_code, -- Output error code
                                                 p_err_msg => l_err_msg);
        END IF;
      
        IF k.freight_term IS NOT NULL
           AND k.org_id <> g_org_id
          -- AND k.site_use_code = 'SHIP_TO'
        THEN
          l_step := 'Update incoterm';
          xxs3_data_transform_util_pkg.transform(p_mapping_type => 'otc_incoterm', p_stage_tab => 'xxobjt.xxs3_otc_cust_acct_site_uses', --Staging Table Name
                                                 p_stage_primary_col => 'xx_cust_acct_site_use_id', --Staging Table Primary Column Name
                                                 p_stage_primary_col_val => k.xx_cust_acct_site_use_id, --Staging Table Primary Column Value
                                                 p_legacy_val => k.incoterm, --Legacy Value
                                                 p_stage_col => 'S3_INCOTERM', --Staging Table Name
                                                 p_err_code => l_err_code, -- Output error code
                                                 p_err_msg => l_err_msg);
        END IF;
      
        IF k.freight_term IS NOT NULL
           AND k.org_id <> g_org_id
           --AND k.site_use_code = 'SHIP_TO'
        THEN
          l_step := 'Update freight_term';
          xxs3_data_transform_util_pkg.transform(p_mapping_type => 'otc_freight_terms', p_stage_tab => 'xxobjt.xxs3_otc_cust_acct_site_uses', --Staging Table Name
                                                 p_stage_primary_col => 'xx_cust_acct_site_use_id', --Staging Table Primary Column Name
                                                 p_stage_primary_col_val => k.xx_cust_acct_site_use_id, --Staging Table Primary Column Value
                                                 p_legacy_val => k.freight_term, --Legacy Value
                                                 p_stage_col => 'S3_FREIGHT_TERM', --Staging Table Name
                                                 p_err_code => l_err_code, -- Output error code
                                                 p_err_msg => l_err_msg);
        END IF;
      
        IF k.freight_term IS NOT NULL
           AND k.org_id <> g_org_id
           --AND k.site_use_code = 'SHIP_TO'
        THEN
          l_step := 'Update fob_point';
          xxs3_data_transform_util_pkg.transform(p_mapping_type => 'otc_fob_point', p_stage_tab => 'xxobjt.xxs3_otc_cust_acct_site_uses', --Staging Table Name
                                                 p_stage_primary_col => 'xx_cust_acct_site_use_id', --Staging Table Primary Column Name
                                                 p_stage_primary_col_val => k.xx_cust_acct_site_use_id, --Staging Table Primary Column Value
                                                 p_legacy_val => k.freight_term, --Legacy Value
                                                 p_stage_col => 'S3_FOB_POINT', --Staging Table Name
                                                 p_err_code => l_err_code, -- Output error code
                                                 p_err_msg => l_err_msg);
        END IF;
      
        IF k.org_id IS NOT NULL
        THEN
          l_step := 'Update org_name';
          xxs3_data_transform_util_pkg.transform(p_mapping_type => 'organization_name', p_stage_tab => 'xxobjt.xxs3_otc_cust_acct_site_uses', --Staging Table Name
                                                 p_stage_primary_col => 'xx_cust_acct_site_use_id', --Staging Table Primary Column Name
                                                 p_stage_primary_col_val => k.xx_cust_acct_site_use_id, --Staging Table Primary Column Value
                                                 p_legacy_val => k.org_name, --Legacy Value
                                                 p_stage_col => 'S3_ORG_NAME', --Staging Table Name
                                                 p_err_code => l_err_code, -- Output error code
                                                 p_err_msg => l_err_msg);
        END IF;
      
        IF k.gl_id_rec_seg3 IS NOT NULL AND k.gl_id_rec IS NOT NULL
           --AND k.org_id != g_org_id
        THEN
          l_step := 'Update REC_ACCOUNT';
          /*xxs3_data_transform_util_pkg.coa_transform(p_field_name => 'REC_ACCOUNT', p_legacy_company_val => k.gl_id_rec_seg1, --Legacy Company Value
                                                     p_legacy_department_val => k.gl_id_rec_seg2, --Legacy Department Value
                                                     p_legacy_account_val => k.gl_id_rec_seg3, --Legacy Account Value
                                                     p_legacy_product_val => k.gl_id_rec_seg5, --Legacy Product Value
                                                     p_legacy_location_val => k.gl_id_rec_seg6, --Legacy Location Value
                                                     p_legacy_intercompany_val => k.gl_id_rec_seg7, --Legacy Intercompany Value
                                                     p_legacy_division_val => k.gl_id_rec_seg10, --Legacy Division Value
                                                     p_item_number => NULL, p_s3_gl_string => l_s3_gl_string, p_err_code => l_output_code, p_err_msg => l_output); --Output Message   */
        
          xxs3_coa_transform_pkg.coa_transform(p_field_name => 'REC_ACCOUNT'
                                              ,p_legacy_company_val => k.gl_id_rec_seg1 --Legacy Company Value
                                              ,p_legacy_department_val => k.gl_id_rec_seg2 --Legacy Department Value
                                              ,p_legacy_account_val => k.gl_id_rec_seg3 --Legacy Account Value
                                              ,p_legacy_product_val => k.gl_id_rec_seg5 --Legacy Product Value
                                              ,p_legacy_location_val => k.gl_id_rec_seg6 --Legacy Location Value
                                              ,p_legacy_intercompany_val => k.gl_id_rec_seg7 --Legacy Intercompany Value
                                              ,p_legacy_division_val => k.gl_id_rec_seg10 --Legacy Division Value
                                              ,p_item_number => NULL
                                              ,p_s3_org => NULL
                                              ,p_trx_type => 'ALL'
                                              ,p_set_of_books_id => NULL
                                              ,p_debug_flag => 'N'
                                              ,p_s3_gl_string => l_s3_gl_string
                                              ,p_err_code => l_output_code
                                              ,p_err_msg => l_output);
                                              
          xxs3_coa_transform_pkg.coa_update(p_gl_string => l_s3_gl_string, 
                                                  p_stage_tab => 'xxs3_otc_cust_acct_site_uses', 
                                                  p_stage_primary_col => 'xx_cust_acct_site_use_id', 
                                                  p_stage_primary_col_val => k.xx_cust_acct_site_use_id, 
                                                  p_stage_company_col => 's3_gl_id_rec_seg1', 
                                                  p_stage_business_unit_col => 's3_gl_id_rec_seg2', 
                                                  p_stage_department_col => 's3_gl_id_rec_seg3', 
                                                  p_stage_account_col => 's3_gl_id_rec_seg4', 
                                                  p_stage_product_line_col => 's3_gl_id_rec_seg5',
                                                  p_stage_location_col => 's3_gl_id_rec_seg6', 
                                                  p_stage_intercompany_col => 's3_gl_id_rec_seg7', 
                                                  p_stage_future_col => 's3_gl_id_rec_seg8', 
                                                  p_coa_err_msg => l_output, 
                                                  p_err_code => l_output_code_coa_update, 
                                                  p_err_msg => l_output_coa_update);          
        
          --xxs3_data_transform_util_pkg.coa_update(p_gl_string => l_s3_gl_string, p_stage_tab => 'xxobjt.xxs3_otc_cust_acct_site_uses', p_stage_primary_col => 'xx_cust_acct_site_use_id', p_stage_primary_col_val => k.xx_cust_acct_site_use_id, p_stage_company_col => 'S3_GL_ID_REC_SEG1', p_stage_business_unit_col => 'S3_GL_ID_REC_SEG2', p_stage_department_col => 'S3_GL_ID_REC_SEG3', p_stage_account_col => 'S3_GL_ID_REC_SEG4', p_stage_product_line_col => 'S3_GL_ID_REC_SEG5', p_stage_location_col => 'S3_GL_ID_REC_SEG6', p_stage_intercompany_col => 'S3_GL_ID_REC_SEG7', p_stage_future_col => 'S3_GL_ID_REC_SEG8', p_coa_err_msg => l_output, p_err_code => l_output_code_coa_update, p_err_msg => l_output_coa_update);
        
        END IF;
        --
        IF k.gl_id_rev IS NOT NULL AND k.gl_id_rev_seg3 IS NOT NULL
           --AND k.org_id != g_org_id
        THEN
          l_step := 'Update REV_ACCOUNT';
         /* xxs3_data_transform_util_pkg.coa_transform(p_field_name => 'REV_ACCOUNT', p_legacy_company_val => k.gl_id_rev_seg1, --Legacy Company Value
                                                     p_legacy_department_val => k.gl_id_rev_seg2, --Legacy Department Value
                                                     p_legacy_account_val => k.gl_id_rev_seg3, --Legacy Account Value
                                                     p_legacy_product_val => k.gl_id_rev_seg5, --Legacy Product Value
                                                     p_legacy_location_val => k.gl_id_rev_seg6, --Legacy Location Value
                                                     p_legacy_intercompany_val => k.gl_id_rev_seg7, --Legacy Intercompany Value
                                                     p_legacy_division_val => k.gl_id_rev_seg10, --Legacy Division Value
                                                     p_item_number => NULL, p_s3_gl_string => l_s3_gl_string, p_err_code => l_output_code, p_err_msg => l_output); --Output Message   
        
          xxs3_data_transform_util_pkg.coa_update(p_gl_string => l_s3_gl_string, p_stage_tab => 'xxobjt.xxs3_otc_cust_acct_site_uses', p_stage_primary_col => 'xx_cust_acct_site_use_id', p_stage_primary_col_val => k.xx_cust_acct_site_use_id, p_stage_company_col => 'S3_GL_ID_REV_SEG1', p_stage_business_unit_col => 'S3_GL_ID_REV_SEG2', p_stage_department_col => 'S3_GL_ID_REV_SEG3', p_stage_account_col => 'S3_GL_ID_REV_SEG4', p_stage_product_line_col => 'S3_GL_ID_REV_SEG5', p_stage_location_col => 'S3_GL_ID_REV_SEG6', p_stage_intercompany_col => 'S3_GL_ID_REV_SEG7', p_stage_future_col => 'S3_GL_ID_REV_SEG8', p_coa_err_msg => l_output, p_err_code => l_output_code_coa_update, p_err_msg => l_output_coa_update);
        */
        
        xxs3_coa_transform_pkg.coa_transform(p_field_name => 'REV_ACCOUNT'
                                              ,p_legacy_company_val => k.gl_id_rev_seg1 --Legacy Company Value
                                              ,p_legacy_department_val => k.gl_id_rev_seg2 --Legacy Department Value
                                              ,p_legacy_account_val => k.gl_id_rev_seg3 --Legacy Account Value
                                              ,p_legacy_product_val => k.gl_id_rev_seg5 --Legacy Product Value
                                              ,p_legacy_location_val => k.gl_id_rev_seg6 --Legacy Location Value
                                              ,p_legacy_intercompany_val => k.gl_id_rev_seg7 --Legacy Intercompany Value
                                              ,p_legacy_division_val => k.gl_id_rev_seg10 --Legacy Division Value
                                              ,p_item_number => NULL
                                              ,p_s3_org => NULL
                                              ,p_trx_type => 'ALL'
                                              ,p_set_of_books_id => NULL
                                              ,p_debug_flag => 'N'
                                              ,p_s3_gl_string => l_s3_gl_string
                                              ,p_err_code => l_output_code
                                              ,p_err_msg => l_output);
                                              
          xxs3_coa_transform_pkg.coa_update(p_gl_string => l_s3_gl_string, 
                                                  p_stage_tab => 'xxs3_otc_cust_acct_site_uses', 
                                                  p_stage_primary_col => 'xx_cust_acct_site_use_id', 
                                                  p_stage_primary_col_val => k.xx_cust_acct_site_use_id, 
                                                  p_stage_company_col => 's3_gl_id_rev_seg1', 
                                                  p_stage_business_unit_col => 's3_gl_id_rev_seg2', 
                                                  p_stage_department_col => 's3_gl_id_rev_seg3', 
                                                  p_stage_account_col => 's3_gl_id_rev_seg4', 
                                                  p_stage_product_line_col => 's3_gl_id_rev_seg5',
                                                  p_stage_location_col => 's3_gl_id_rev_seg6', 
                                                  p_stage_intercompany_col => 's3_gl_id_rev_seg7', 
                                                  p_stage_future_col => 's3_gl_id_rev_seg8', 
                                                  p_coa_err_msg => l_output, 
                                                  p_err_code => l_output_code_coa_update, 
                                                  p_err_msg => l_output_coa_update);          
        
        END IF;
        --
        /*IF k.gl_id_tax IS NOT NULL --commented on 28/12
           AND k.org_id != g_org_id
        THEN
          l_step := 'Update TAX_ACCOUNT';
          xxs3_data_transform_util_pkg.coa_transform(p_field_name => 'TAX_ACCOUNT', p_legacy_company_val => k.gl_id_tax_seg1, --Legacy Company Value
                                                     p_legacy_department_val => k.gl_id_tax_seg2, --Legacy Department Value
                                                     p_legacy_account_val => k.gl_id_tax_seg3, --Legacy Account Value
                                                     p_legacy_product_val => k.gl_id_tax_seg5, --Legacy Product Value
                                                     p_legacy_location_val => k.gl_id_tax_seg6, --Legacy Location Value
                                                     p_legacy_intercompany_val => k.gl_id_tax_seg7, --Legacy Intercompany Value
                                                     p_legacy_division_val => k.gl_id_tax_seg10, --Legacy Division Value
                                                     p_item_number => NULL, p_s3_gl_string => l_s3_gl_string, p_err_code => l_output_code, p_err_msg => l_output); --Output Message   
        
          xxs3_data_transform_util_pkg.coa_update(p_gl_string => l_s3_gl_string, p_stage_tab => 'xxobjt.xxs3_otc_cust_acct_site_uses', p_stage_primary_col => 'xx_cust_acct_site_use_id', p_stage_primary_col_val => k.xx_cust_acct_site_use_id, p_stage_company_col => 'S3_GL_ID_tax_SEG1', p_stage_business_unit_col => 'S3_GL_ID_tax_SEG2', p_stage_department_col => 'S3_GL_ID_tax_SEG3', p_stage_account_col => 'S3_GL_ID_tax_SEG4', p_stage_product_line_col => 'S3_GL_ID_tax_SEG5', p_stage_location_col => 'S3_GL_ID_tax_SEG6', p_stage_intercompany_col => 'S3_GL_ID_tax_SEG7', p_stage_future_col => 'S3_GL_ID_tax_SEG8', p_coa_err_msg => l_output, p_err_code => l_output_code_coa_update, p_err_msg => l_output_coa_update);
        END IF;*/
        --
        IF k.gl_id_freight IS NOT NULL AND k.gl_id_freight_seg3 IS NOT NULL
           /*AND k.org_id != g_org_id*/
        THEN
          l_step := 'Update FREIGHT_ACCOUNT';
          /*xxs3_data_transform_util_pkg.coa_transform(p_field_name => 'FREIGHT_ACCOUNT', p_legacy_company_val => k.gl_id_freight_seg1, --Legacy Company Value
                                                     p_legacy_department_val => k.gl_id_freight_seg2, --Legacy Department Value
                                                     p_legacy_account_val => k.gl_id_freight_seg3, --Legacy Account Value
                                                     p_legacy_product_val => k.gl_id_freight_seg5, --Legacy Product Value
                                                     p_legacy_location_val => k.gl_id_freight_seg6, --Legacy Location Value
                                                     p_legacy_intercompany_val => k.gl_id_freight_seg7, --Legacy Intercompany Value
                                                     p_legacy_division_val => k.gl_id_freight_seg10, --Legacy Division Value
                                                     p_item_number => NULL, p_s3_gl_string => l_s3_gl_string, p_err_code => l_output_code, p_err_msg => l_output); --Output Message   
        
          xxs3_data_transform_util_pkg.coa_update(p_gl_string => l_s3_gl_string, p_stage_tab => 'xxobjt.xxs3_otc_cust_acct_site_uses', p_stage_primary_col => 'xx_cust_acct_site_use_id', p_stage_primary_col_val => k.xx_cust_acct_site_use_id, p_stage_company_col => 'S3_GL_ID_freight_SEG1', p_stage_business_unit_col => 'S3_GL_ID_freight_SEG2', p_stage_department_col => 'S3_GL_ID_freight_SEG3', p_stage_account_col => 'S3_GL_ID_freight_SEG4', p_stage_product_line_col => 'S3_GL_ID_freight_SEG5', p_stage_location_col => 'S3_GL_ID_freight_SEG6', p_stage_intercompany_col => 'S3_GL_ID_freight_SEG7', p_stage_future_col => 'S3_GL_ID_freight_SEG8', p_coa_err_msg => l_output, p_err_code => l_output_code_coa_update, p_err_msg => l_output_coa_update);*/
        
        
        xxs3_coa_transform_pkg.coa_transform(p_field_name => 'FREIGHT_ACCOUNT'
                                              ,p_legacy_company_val => k.gl_id_freight_seg1 --Legacy Company Value
                                              ,p_legacy_department_val => k.gl_id_freight_seg2 --Legacy Department Value
                                              ,p_legacy_account_val => k.gl_id_freight_seg3 --Legacy Account Value
                                              ,p_legacy_product_val => k.gl_id_freight_seg5 --Legacy Product Value
                                              ,p_legacy_location_val => k.gl_id_freight_seg6 --Legacy Location Value
                                              ,p_legacy_intercompany_val => k.gl_id_freight_seg7 --Legacy Intercompany Value
                                              ,p_legacy_division_val => k.gl_id_freight_seg10 --Legacy Division Value
                                              ,p_item_number => NULL
                                              ,p_s3_org => NULL
                                              ,p_trx_type => 'ALL'
                                              ,p_set_of_books_id => NULL
                                              ,p_debug_flag => 'N'
                                              ,p_s3_gl_string => l_s3_gl_string
                                              ,p_err_code => l_output_code
                                              ,p_err_msg => l_output);
                                              
          xxs3_coa_transform_pkg.coa_update(p_gl_string => l_s3_gl_string, 
                                                  p_stage_tab => 'xxs3_otc_cust_acct_site_uses', 
                                                  p_stage_primary_col => 'xx_cust_acct_site_use_id', 
                                                  p_stage_primary_col_val => k.xx_cust_acct_site_use_id, 
                                                  p_stage_company_col => 's3_gl_id_freight_seg1', 
                                                  p_stage_business_unit_col => 's3_gl_id_freight_seg2', 
                                                  p_stage_department_col => 's3_gl_id_freight_seg3', 
                                                  p_stage_account_col => 's3_gl_id_freight_seg4', 
                                                  p_stage_product_line_col => 's3_gl_id_freight_seg5',
                                                  p_stage_location_col => 's3_gl_id_freight_seg6', 
                                                  p_stage_intercompany_col => 's3_gl_id_freight_seg7', 
                                                  p_stage_future_col => 's3_gl_id_freight_seg8', 
                                                  p_coa_err_msg => l_output, 
                                                  p_err_code => l_output_code_coa_update, 
                                                  p_err_msg => l_output_coa_update);  
                                                  
        END IF;                                          
        --
      /*  IF k.gl_id_unbilled IS NOT NULL --commented on 28/12
           AND k.org_id != g_org_id
        THEN
          l_step := 'Update UNBILLED_ACCOUNT';
          xxs3_data_transform_util_pkg.coa_transform(p_field_name => 'UNBILLED_ACCOUNT', p_legacy_company_val => k.gl_id_unbilled_seg1, --Legacy Company Value
                                                     p_legacy_department_val => k.gl_id_unbilled_seg2, --Legacy Department Value
                                                     p_legacy_account_val => k.gl_id_unbilled_seg3, --Legacy Account Value
                                                     p_legacy_product_val => k.gl_id_unbilled_seg5, --Legacy Product Value
                                                     p_legacy_location_val => k.gl_id_unbilled_seg6, --Legacy Location Value
                                                     p_legacy_intercompany_val => k.gl_id_unbilled_seg7, --Legacy Intercompany Value
                                                     p_legacy_division_val => k.gl_id_unbilled_seg10, --Legacy Division Value
                                                     p_item_number => NULL, p_s3_gl_string => l_s3_gl_string, p_err_code => l_output_code, p_err_msg => l_output); --Output Message   
        
          xxs3_data_transform_util_pkg.coa_update(p_gl_string => l_s3_gl_string, p_stage_tab => 'xxobjt.xxs3_otc_cust_acct_site_uses', p_stage_primary_col => 'xx_cust_acct_site_use_id', p_stage_primary_col_val => k.xx_cust_acct_site_use_id, p_stage_company_col => 'S3_GL_ID_unbilled_SEG1', p_stage_business_unit_col => 'S3_GL_ID_unbilled_SEG2', p_stage_department_col => 'S3_GL_ID_unbilled_SEG3', p_stage_account_col => 'S3_GL_ID_unbilled_SEG4', p_stage_product_line_col => 'S3_GL_ID_unbilled_SEG5', p_stage_location_col => 'S3_GL_ID_unbilled_SEG6', p_stage_intercompany_col => 'S3_GL_ID_unbilled_SEG7', p_stage_future_col => 'S3_GL_ID_unbilled_SEG8', p_coa_err_msg => l_output, p_err_code => l_output_code_coa_update, p_err_msg => l_output_coa_update);
        END IF;*/ --commented on 28/12
        --
        IF k.gl_id_unearned IS NOT NULL AND k.gl_id_unearned_seg3 IS NOT NULL
          -- AND k.org_id != g_org_id
        THEN
          l_step := 'Update UNEARNED_ACCOUNT';
          /*xxs3_data_transform_util_pkg.coa_transform(p_field_name => 'UNEARNED_ACCOUNT', p_legacy_company_val => k.gl_id_unearned_seg1, --Legacy Company Value
                                                     p_legacy_department_val => k.gl_id_unearned_seg2, --Legacy Department Value
                                                     p_legacy_account_val => k.gl_id_unearned_seg3, --Legacy Account Value
                                                     p_legacy_product_val => k.gl_id_unearned_seg5, --Legacy Product Value
                                                     p_legacy_location_val => k.gl_id_unearned_seg6, --Legacy Location Value
                                                     p_legacy_intercompany_val => k.gl_id_unearned_seg7, --Legacy Intercompany Value
                                                     p_legacy_division_val => k.gl_id_unearned_seg10, --Legacy Division Value
                                                     p_item_number => NULL, p_s3_gl_string => l_s3_gl_string, p_err_code => l_output_code, p_err_msg => l_output); --Output Message   
        
          xxs3_data_transform_util_pkg.coa_update(p_gl_string => l_s3_gl_string, p_stage_tab => 'xxobjt.xxs3_otc_cust_acct_site_uses', p_stage_primary_col => 'xx_cust_acct_site_use_id', p_stage_primary_col_val => k.xx_cust_acct_site_use_id, p_stage_company_col => 'S3_GL_ID_unearned_SEG1', p_stage_business_unit_col => 'S3_GL_ID_unearned_SEG2', p_stage_department_col => 'S3_GL_ID_unearned_SEG3', p_stage_account_col => 'S3_GL_ID_unearned_SEG4', p_stage_product_line_col => 'S3_GL_ID_unearned_SEG5', p_stage_location_col => 'S3_GL_ID_unearned_SEG6', p_stage_intercompany_col => 'S3_GL_ID_unearned_SEG7', p_stage_future_col => 'S3_GL_ID_unearned_SEG8', p_coa_err_msg => l_output, p_err_code => l_output_code_coa_update, p_err_msg => l_output_coa_update);*/
          
          xxs3_coa_transform_pkg.coa_transform(p_field_name => 'UNEARNED_ACCOUNT'
                                              ,p_legacy_company_val => k.gl_id_unearned_seg1 --Legacy Company Value
                                              ,p_legacy_department_val => k.gl_id_unearned_seg2 --Legacy Department Value
                                              ,p_legacy_account_val => k.gl_id_unearned_seg3 --Legacy Account Value
                                              ,p_legacy_product_val => k.gl_id_unearned_seg5 --Legacy Product Value
                                              ,p_legacy_location_val => k.gl_id_unearned_seg6 --Legacy Location Value
                                              ,p_legacy_intercompany_val => k.gl_id_unearned_seg7 --Legacy Intercompany Value
                                              ,p_legacy_division_val => k.gl_id_unearned_seg10 --Legacy Division Value
                                              ,p_item_number => NULL
                                              ,p_s3_org => NULL
                                              ,p_trx_type => 'ALL'
                                              ,p_set_of_books_id => NULL
                                              ,p_debug_flag => 'N'
                                              ,p_s3_gl_string => l_s3_gl_string
                                              ,p_err_code => l_output_code
                                              ,p_err_msg => l_output);
                                              
          xxs3_coa_transform_pkg.coa_update(p_gl_string => l_s3_gl_string, 
                                                  p_stage_tab => 'xxs3_otc_cust_acct_site_uses', 
                                                  p_stage_primary_col => 'xx_cust_acct_site_use_id', 
                                                  p_stage_primary_col_val => k.xx_cust_acct_site_use_id, 
                                                  p_stage_company_col => 's3_gl_id_unearned_seg1', 
                                                  p_stage_business_unit_col => 's3_gl_id_unearned_seg2', 
                                                  p_stage_department_col => 's3_gl_id_unearned_seg3', 
                                                  p_stage_account_col => 's3_gl_id_unearned_seg4', 
                                                  p_stage_product_line_col => 's3_gl_id_unearned_seg5',
                                                  p_stage_location_col => 's3_gl_id_unearned_seg6', 
                                                  p_stage_intercompany_col => 's3_gl_id_unearned_seg7', 
                                                  p_stage_future_col => 's3_gl_id_unearned_seg8', 
                                                  p_coa_err_msg => l_output, 
                                                  p_err_code => l_output_code_coa_update, 
                                                  p_err_msg => l_output_coa_update);  
         
        END IF;
        
         IF k.gl_id_clearing IS NOT NULL 
          -- AND k.org_id != g_org_id
        THEN
          l_step := 'Update CLEARING_ACCOUNT';
          
          
          xxs3_coa_transform_pkg.coa_transform(p_field_name => 'CLEARING_ACCOUNT'
                                              ,p_legacy_company_val => k.gl_id_clearing_seg1 --Legacy Company Value
                                              ,p_legacy_department_val => k.gl_id_clearing_seg2 --Legacy Department Value
                                              ,p_legacy_account_val => k.gl_id_clearing_seg3 --Legacy Account Value
                                              ,p_legacy_product_val => k.gl_id_clearing_seg5 --Legacy Product Value
                                              ,p_legacy_location_val => k.gl_id_clearing_seg6 --Legacy Location Value
                                              ,p_legacy_intercompany_val => k.gl_id_clearing_seg7 --Legacy Intercompany Value
                                              ,p_legacy_division_val => k.gl_id_clearing_seg10 --Legacy Division Value
                                              ,p_item_number => NULL
                                              ,p_s3_org => NULL
                                              ,p_trx_type => 'ALL'
                                              ,p_set_of_books_id => NULL
                                              ,p_debug_flag => 'N'
                                              ,p_s3_gl_string => l_s3_gl_string
                                              ,p_err_code => l_output_code
                                              ,p_err_msg => l_output);
                                              
          xxs3_coa_transform_pkg.coa_update(p_gl_string => l_s3_gl_string, 
                                                  p_stage_tab => 'xxs3_otc_cust_acct_site_uses', 
                                                  p_stage_primary_col => 'xx_cust_acct_site_use_id', 
                                                  p_stage_primary_col_val => k.xx_cust_acct_site_use_id, 
                                                  p_stage_company_col => 's3_gl_id_clearing_seg1', 
                                                  p_stage_business_unit_col => 's3_gl_id_clearing_seg2', 
                                                  p_stage_department_col => 's3_gl_id_clearing_seg3', 
                                                  p_stage_account_col => 's3_gl_id_clearing_seg4', 
                                                  p_stage_product_line_col => 's3_gl_id_clearing_seg5',
                                                  p_stage_location_col => 's3_gl_id_clearing_seg6', 
                                                  p_stage_intercompany_col => 's3_gl_id_clearing_seg7', 
                                                  p_stage_future_col => 's3_gl_id_clearing_seg8', 
                                                  p_coa_err_msg => l_output, 
                                                  p_err_code => l_output_code_coa_update, 
                                                  p_err_msg => l_output_coa_update);  
         
        END IF;
      END LOOP;
    
    EXCEPTION
      WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log, 'Unexpected error during transformation at step : ' ||
                           l_step || chr(10) || SQLCODE ||
                           chr(10) || SQLERRM);
      
    END;
  
    -- file generate
  
    utl_file_generate('CUSTOMER_SITE_USE');
  
    --Customer Site Use
    SELECT COUNT(1)
    INTO l_count_cust_site_use
    FROM xxobjt.xxs3_otc_cust_acct_site_uses;
  
    fnd_file.put_line(fnd_file.output, rpad('Customer Site Use Extract Records Count Report', 100, ' '));
    fnd_file.put_line(fnd_file.output, rpad('============================================================', 200, ' '));
    fnd_file.put_line(fnd_file.output, rpad('Run date and time:    ' ||
                            to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI'), 100, ' '));
    fnd_file.put_line(fnd_file.output, rpad('============================================================', 200, ' '));
    fnd_file.put_line(fnd_file.output, '');
    fnd_file.put_line(fnd_file.output, rpad('Track Name', 10, ' ') ||
                       chr(32) ||
                       rpad('Entity Name', 30, ' ') ||
                       chr(32) ||
                       rpad('Total Count', 15, ' '));
    fnd_file.put_line(fnd_file.output, rpad('===========================================================', 200, ' '));
  
    fnd_file.put_line(fnd_file.output, '');
  
    fnd_file.put_line(fnd_file.output, rpad('OTC', 10, ' ') || ' ' ||
                       rpad('CUSTOMER SITE USE', 30, ' ') || ' ' ||
                       rpad(l_count_cust_site_use, 15, ' '));
    fnd_file.put_line(fnd_file.output, rpad('=========END OF REPORT===============', 200, ' '));
    fnd_file.put_line(fnd_file.output, '');
  
  EXCEPTION
  
    WHEN OTHERS THEN
      x_retcode        := 2;
      x_errbuf         := 'Unexpected error: ' || SQLERRM;
      l_status_message := SQLCODE || chr(10) || SQLERRM;
      fnd_file.put_line(fnd_file.log, 'Unexpected error during data extraction : ' ||
                         chr(10) || l_status_message);
  END cust_site_uses_extract_data;
  --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required Customer Sites  fields
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0 11/05/2016  Mishal Kumar                  Initial build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE cust_site_extract_data(x_errbuf  OUT VARCHAR2
                                  ,x_retcode OUT NUMBER) IS
    l_errbuf             VARCHAR2(2000);
    l_retcode            VARCHAR2(1);
    l_requestor          NUMBER;
    l_program_short_name VARCHAR2(100);
    l_status_message     VARCHAR2(4000);
    l_counter            NUMBER;
    l_output             VARCHAR2(100) := 'SUCCESS';
    l_count              NUMBER := 0;
    --
    l_err_code        VARCHAR2(100); -- Output error code
    l_err_msg         VARCHAR2(1000);
    l_count_cust_site NUMBER;
  
  
    CURSOR cur_cust_site_extract IS
      SELECT customer_category_code
            ,cust_account_id legacy_cust_account_id
            ,cust_acct_site_id legacy_cust_account_site_id
            ,org_id
            ,(SELECT NAME
              FROM hr_operating_units
              WHERE organization_id = hcal.org_id) org_name
            ,party_site_id legacy_party_site_id            
            ,status
            --,orig_system_reference   --commented out as per FDD on 27.12.2016
            ,attribute2 inactive_reason
            ,attribute1 sales_force_id
      FROM hz_cust_acct_sites_all hcal
      WHERE org_id <> 89; --	No customers should be migrated from OU = 89
  
  BEGIN
    x_retcode := 0;
    x_errbuf  := 'COMPLETE';
    --
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_otc_cust_acct_sites';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_otc_cust_acct_site_dq';
    --
  
    FOR k IN cur_cust_site_extract
    LOOP
      /*INSERT INTO xxobjt.xxs3_otc_cust_acct_sites
        (xx_cust_account_site_id
        ,legacy_cust_account_site_id
        ,legacy_cust_account_id
        ,legacy_party_site_id
        ,org_id
        ,org_name
        ,status
        ,orig_system_reference
        ,inactive_reason
        ,sales_force_id
        ,s3_cust_account_site_id
        ,
         --s3_cust_account_id,
         --s3_party_site_id,
         date_extracted_on
        ,process_flag)
      VALUES
        (xxobjt.xxs3_otc_cust_acct_sites_seq.NEXTVAL
        ,k.legacy_cust_account_site_id
        ,k.legacy_cust_account_id
        ,k.legacy_party_site_id
        ,k.org_id
        ,k.org_name
        ,k.status
        ,k.orig_system_reference
        ,k.inactive_reason
        ,k.sales_force_id
        ,NULL
        ,
         --NULL,
         --NULL,
         SYSDATE
        ,'N');*/
        
        INSERT INTO xxobjt.xxs3_otc_cust_acct_sites
        (xx_cust_account_site_id
        --,customer_category_code --commented out as per FDD on 28.12.2016
        ,legacy_cust_account_site_id
        ,legacy_cust_account_id
        ,org_id
        ,org_name
        ,legacy_party_site_id        
        ,status
        --,orig_system_reference  --commented out as per FDD on 28.12.2016
        ,inactive_reason
        ,sales_force_id
        ,s3_cust_account_site_id
        ,
         --s3_cust_account_id,
         --s3_party_site_id,
         date_extracted_on
        ,process_flag)
      VALUES
        (xxobjt.xxs3_otc_cust_acct_sites_seq.NEXTVAL
        --,k.customer_category_code --commented out as per FDD on 27.12.2016
        ,k.legacy_cust_account_site_id
        ,k.legacy_cust_account_id        
        ,k.org_id  
        ,k.org_name  
        ,k.legacy_party_site_id    
        ,k.status
        --,k.orig_system_reference --commented out as per FDD on 27.12.2016
        ,k.inactive_reason
        ,k.sales_force_id
        ,NULL
        ,
         --NULL,
         --NULL,
         SYSDATE
        ,'N'); 
    END LOOP;
  
    fnd_file.put_line(fnd_file.log, 'Loading complete');
    COMMIT;
    --
    BEGIN
    --Apply Extract Rules
    --EXT-007
        UPDATE xxs3_otc_cust_acct_sites xocs
           SET xocs.extract_rule_name = CASE WHEN extract_rule_name = NULL THEN 'EXT-007' ELSE extract_rule_name || '|' || 'EXT-007' END
         WHERE EXISTS
         (SELECT hca.cust_account_id
                  FROM hz_cust_accounts hca, hz_parties hp
                 WHERE hca.party_id = hp.party_id
                   AND hca.status = 'A'
                   AND hp.status = 'A'
                   AND hca.cust_account_id = xocs.legacy_cust_account_id);
        
    
        fnd_file.put_line(fnd_file.log,'Extract Rule Name-EXT-007: '||SQL%ROWCOUNT||' rows were updated');
    
        
        --EXT-008
        
UPDATE xxs3_otc_cust_acct_sites xocs
   SET xocs.extract_rule_name = CASE WHEN extract_rule_name = NULL THEN 'EXT-008' ELSE extract_rule_name || '|' || 'EXT-008' END
 WHERE EXISTS
 (SELECT chsu_bill.cust_acct_site_id,
               chsu_bill.site_use_id,
               chsu_bill.party_site_number
          FROM csi_hzca_site_uses_v chsu_bill
         WHERE chsu_bill.status = 'I'
           AND chsu_bill.site_use_id IN
               (SELECT cipv1.bill_to_address
                  FROM csi_instance_party_v cipv1
                 WHERE cipv1.instance_id IN
                       (SELECT cii.instance_id
                          FROM csi_item_instances cii
                         WHERE cii.instance_status_id NOT IN (510, 1, 10040)
                           AND instr(cii.serial_number, '-L', 1) = 0))
                           AND chsu_bill.cust_acct_site_id = xocs.legacy_cust_account_site_id
        UNION
        SELECT chsu_ship.cust_acct_site_id,
               chsu_ship.site_use_id,
               chsu_ship.party_site_number
          FROM csi_hzca_site_uses_v chsu_ship
         WHERE chsu_ship.status = 'I'
           AND chsu_ship.site_use_id IN
               (SELECT cipv1.ship_to_address
                  FROM csi_instance_party_v cipv1
                 WHERE cipv1.instance_id IN
                       (SELECT cii.instance_id
                          FROM csi_item_instances cii
                         WHERE cii.instance_status_id NOT IN (510, 1, 10040)
                           AND instr(cii.serial_number, '-L', 1) = 0))
                           AND chsu_ship.cust_acct_site_id = xocs.legacy_cust_account_site_id
        
        );
                   
        fnd_file.put_line(fnd_file.log,'Extract Rule Name-EXT-008: '||SQL%ROWCOUNT||' rows were updated');          
        
        /*UPDATE xxs3_otc_cust_acct_sites xocs
           SET xocs.extract_rule_name = CASE WHEN extract_rule_name = NULL THEN 'EXT-008' ELSE extract_rule_name || '|' || 'EXT-008' END
         WHERE EXISTS (SELECT DISTINCT hpsv.party_id, hpsv.party_site_id
                  FROM apps.hz_party_sites_v  hpsv,
                       hz_parties             hp_loc,
                       csi_item_instances     cii,
                       csi_instance_details_v cidv
                 WHERE hp_loc.party_id = hpsv.party_id
                   AND nvl(hpsv.site_use_type, 'SHIP_TO') = 'SHIP_TO'
                   AND hpsv.status = 'I'
                   AND hpsv.party_site_id = cidv.install_location_id
                   AND cidv.instance_id = cii.instance_id
                   AND cii.instance_status_id NOT IN (510, 1, 10040)
                   AND instr(cii.serial_number, '-L', 1) = 0
                   AND hpsv.party_site_id = xocs.legacy_party_site_id);
                   
        fnd_file.put_line(fnd_file.log,'Extract Rule Name-EXT-008: '||SQL%ROWCOUNT||' rows were updated'); */   
              
        --EXT-009
        UPDATE xxs3_otc_cust_acct_sites xocs
           SET xocs.extract_rule_name = CASE WHEN extract_rule_name = NULL THEN 'EXT-009' ELSE extract_rule_name || '|' || 'EXT-009' END
         WHERE EXISTS
         (SELECT DISTINCT hca.cust_account_id
                  FROM oe_order_headers_all oh,
                       hz_cust_accounts     hca,
                       oe_order_lines_all   ol
                 WHERE hca.cust_account_id = oh.sold_to_org_id
                   AND oh.header_id = ol.header_id
                   AND ol.schedule_ship_date >= SYSDATE - 1825 --should this be oh.order_date?
                   AND ol.flow_status_code <> 'Cancelled'
                   AND hca.cust_account_id = xocs.legacy_cust_account_id
                      --AND oh.ordered_date >= SYSDATE - 1825 
                   AND NOT EXISTS -- extract : For accounts where all sites are OU <> '737'
                 (SELECT cust_account_id
                          FROM hz_cust_acct_sites_all
                         WHERE cust_account_id = hca.cust_account_id
                           AND org_id = 737)); -- extract : For accounts where are all sites are OU <> '737'
                           
         /*(SELECT DISTINCT hca.cust_account_id
                  FROM oe_order_headers_all oh,
                       oe_order_lines_all   ol,
                       hz_cust_accounts     hca
                 WHERE hca.cust_account_id = oh.sold_to_org_id
                   AND oh.header_id = ol.header_id
                   AND oh.ordered_date >= SYSDATE - 1825
                   --AND ol.schedule_ship_date >= SYSDATE - 1825 --should this be oh.order_date?
                   --AND ol.flow_status_code <> 'Cancelled'
                   AND oh.org_id <> 737
                   AND hca.cust_account_id = xocs.legacy_cust_account_id);*/
        
        fnd_file.put_line(fnd_file.log,'Extract Rule Name-EXT-009: '||SQL%ROWCOUNT||' rows were updated');   
               
        EXCEPTION
          WHEN OTHERS THEN
            fnd_file.put_line(fnd_file.log, 'Unexpected error during extract rules update : ' ||
                               chr(10) || SQLCODE || chr(10) ||
                               SQLERRM);    
        END;
    
     --Apply Extract Rules
     COMMIT;
     
     --DQ
    /* BEGIN     
     quality_check_cust_sites;
     
     EXCEPTION
      WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log, 'Unexpected error during DQ : ' ||
                           chr(10) || SQLCODE || chr(10) ||
                           SQLERRM);
     END;   */        
     --DQ
     
     --Transformation
    BEGIN
      FOR l IN (SELECT * FROM xxobjt.xxs3_otc_cust_acct_sites 
                 WHERE extract_rule_name IS NOT NULL
                  AND process_flag <> 'R') LOOP
      
        IF l.org_id IS NOT NULL
        THEN
        
          xxs3_data_transform_util_pkg.transform(p_mapping_type => 'organization_name', p_stage_tab => 'xxobjt.xxs3_otc_cust_acct_sites', --Staging Table Name
                                                 p_stage_primary_col => 'xx_cust_account_site_id', --Staging Table Primary Column Name
                                                 p_stage_primary_col_val => l.xx_cust_account_site_id, --Staging Table Primary Column Value
                                                 p_legacy_val => l.org_name, --Legacy Value
                                                 p_stage_col => 'S3_ORG_NAME', --Staging Table Name
                                                 p_err_code => l_err_code, -- Output error code
                                                 p_err_msg => l_err_msg);
        END IF;
      END LOOP;
    EXCEPTION
      WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log, 'Unexpected error during transformation : ' ||
                           chr(10) || SQLCODE || chr(10) ||
                           SQLERRM);
    END;
  
  
    --Customer Site
    SELECT COUNT(1)
    INTO l_count_cust_site
    FROM xxobjt.xxs3_otc_cust_acct_sites;
  
    fnd_file.put_line(fnd_file.output, rpad('Customer Site Extract Records Count Report', 100, ' '));
    fnd_file.put_line(fnd_file.output, rpad('============================================================', 200, ' '));
    fnd_file.put_line(fnd_file.output, rpad('Run date and time:    ' ||
                            to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI'), 100, ' '));
    fnd_file.put_line(fnd_file.output, rpad('============================================================', 200, ' '));
    fnd_file.put_line(fnd_file.output, '');
    fnd_file.put_line(fnd_file.output, rpad('Track Name', 10, ' ') ||
                       chr(32) ||
                       rpad('Entity Name', 30, ' ') ||
                       chr(32) ||
                       rpad('Total Count', 15, ' '));
    fnd_file.put_line(fnd_file.output, rpad('===========================================================', 200, ' '));
  
    fnd_file.put_line(fnd_file.output, '');
  
    fnd_file.put_line(fnd_file.output, rpad('OTC', 10, ' ') || ' ' ||
                       rpad('CUSTOMER SITE', 30, ' ') || ' ' ||
                       rpad(l_count_cust_site, 15, ' '));
    fnd_file.put_line(fnd_file.output, rpad('=========END OF REPORT===============', 200, ' '));
    fnd_file.put_line(fnd_file.output, '');
  EXCEPTION
    WHEN OTHERS THEN
      x_retcode        := 2;
      x_errbuf         := 'Unexpected error: ' || SQLERRM;
      l_status_message := SQLCODE || chr(10) || SQLERRM;
      fnd_file.put_line(fnd_file.log, 'Unexpected error during data extraction : ' ||
                         chr(10) || l_status_message);
      fnd_file.put_line(fnd_file.log, '--------------------------------------');
  END cust_site_extract_data;
  --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required Customer Contact  fields
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0 11/05/2016  Mishal Kumar                  Initial build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE cust_contact_extract_data(x_errbuf  OUT VARCHAR2
                                  ,x_retcode OUT NUMBER) IS
    l_errbuf             VARCHAR2(2000);
    l_retcode            VARCHAR2(1);
    l_requestor          NUMBER;
    l_program_short_name VARCHAR2(100);
    l_status_message     VARCHAR2(4000);
    l_counter            NUMBER;
    l_output             VARCHAR2(100) := 'SUCCESS';
    l_count              NUMBER := 0;
    --
    l_err_code        VARCHAR2(100); -- Output error code
    l_err_msg         VARCHAR2(1000);
    l_count_cust_site NUMBER;
  
  
    CURSOR cur_cust_contact_extract IS
      SELECT hr.party_id          
            ,hca.cust_account_id       cust_account_id
            ,hcar.cust_account_role_id legacy_cust_account_role_id
            ,hcar.role_type
            ,hca.status
            ,hcar.attribute1 sf_contact_id
            ,hcar.attribute3 ecomm_flag
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
      --AND hr.relationship_code = 'CONTACT_OF'
           --AND hp_cust.party_id = p_party_id;
      AND EXISTS (SELECT legacy_cust_account_id
             FROM xxs3_otc_customer_accounts xop
             WHERE process_flag != 'R'
             AND xop.legacy_cust_account_id = hca.cust_account_id);
  
  BEGIN
    x_retcode := 0;
    x_errbuf  := 'COMPLETE';
    --
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_otc_cust_acct_contacts';
    --
  
    FOR k IN cur_cust_contact_extract
    LOOP
      INSERT INTO xxobjt.xxs3_otc_cust_acct_contacts
      VALUES
        (xxobjt.xxs3_otc_cust_contacts_seq.NEXTVAL
        ,k.legacy_cust_account_role_id
        ,NULL
        ,k.party_id
        ,k.cust_account_id
        ,k.role_type
        ,k.status
        ,k.sf_contact_id
        ,k.ecomm_flag  
        ,SYSDATE
        ,'N'
        ,NULL
        ,NULL
        ,NULL
        ,NULL
        ,NULL
        ,NULL
        ,NULL);
    END LOOP;
  
    fnd_file.put_line(fnd_file.log, 'Loading complete');
    /* END LOOP;*/
    COMMIT;
    --
  
    --Customer Contact
    SELECT COUNT(1)
    INTO l_count
    FROM xxobjt.xxs3_otc_cust_acct_contacts;
  
    fnd_file.put_line(fnd_file.output, rpad('Customer Contact Extract Records Count Report', 100, ' '));
    fnd_file.put_line(fnd_file.output, rpad('============================================================', 200, ' '));
    fnd_file.put_line(fnd_file.output, rpad('Run date and time:    ' ||
                            to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI'), 100, ' '));
    fnd_file.put_line(fnd_file.output, rpad('============================================================', 200, ' '));
    fnd_file.put_line(fnd_file.output, '');
    fnd_file.put_line(fnd_file.output, rpad('Track Name', 10, ' ') ||
                       chr(32) ||
                       rpad('Entity Name', 30, ' ') ||
                       chr(32) ||
                       rpad('Total Count', 15, ' '));
    fnd_file.put_line(fnd_file.output, rpad('===========================================================', 200, ' '));
  
    fnd_file.put_line(fnd_file.output, '');
  
    fnd_file.put_line(fnd_file.output, rpad('OTC', 10, ' ') || ' ' ||
                       rpad('CUSTOMER CONTACT', 30, ' ') || ' ' ||
                       rpad(l_count, 15, ' '));
    fnd_file.put_line(fnd_file.output, rpad('=========END OF REPORT===============', 200, ' '));
    fnd_file.put_line(fnd_file.output, '');
    
  EXCEPTION
    WHEN OTHERS THEN
      x_retcode        := 2;
      x_errbuf         := 'Unexpected error: ' || SQLERRM;
      l_status_message := SQLCODE || chr(10) || SQLERRM;
      fnd_file.put_line(fnd_file.log, 'Unexpected error during data extraction : ' ||
                         chr(10) || l_status_message);
      fnd_file.put_line(fnd_file.log, '--------------------------------------');
  END cust_contact_extract_data;

  --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required Customer Sites  fields
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0 11/05/2016  Mishal Kumar                  Initial build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE cust_relation_extract_data(x_errbuf  OUT VARCHAR2
                                      ,x_retcode OUT NUMBER) IS
    l_errbuf             VARCHAR2(2000);
    l_retcode            VARCHAR2(1);
    l_requestor          NUMBER;
    l_program_short_name VARCHAR2(100);
    l_status_message     VARCHAR2(4000);
    l_counter            NUMBER;
    l_output             VARCHAR2(100) := 'SUCCESS';
    l_count              NUMBER := 0;
    l_count_cust_relshp  NUMBER;
    l_err_code           VARCHAR2(100); 
    l_err_msg            VARCHAR2(1000);
    --
    --
    CURSOR cur_cust_relation_extract IS
      SELECT cust_acct_relate_id,
             cust_account_id,
             related_cust_account_id,
             relationship_type,
             customer_reciprocal_flag,
             status,
             bill_to_flag,
             ship_to_flag,
             --created_by_module,  Commented as on 22/12
             --new
             org_id,
             (SELECT NAME
                FROM hr_operating_units
               WHERE organization_id = hcar.org_id) org_name
        FROM hz_cust_acct_relate_all hcar;/*
       WHERE EXISTS (SELECT legacy_cust_account_id
                FROM xxs3_otc_customer_accounts a
               WHERE process_flag != 'R'
                 AND a.legacy_cust_account_id = hcar.cust_account_id)
         AND EXISTS
       (SELECT legacy_cust_account_id
                FROM xxs3_otc_customer_accounts a
               WHERE process_flag != 'R'
                 AND a.legacy_cust_account_id = hcar.related_cust_account_id);*/
  
  BEGIN
    x_retcode := 0;
    x_errbuf  := 'COMPLETE';
    --
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_otc_cust_relationships';
    --
    FOR l IN cur_cust_relation_extract
    LOOP
      INSERT INTO xxobjt.xxs3_otc_cust_relationships
      VALUES
        (xxobjt.xxs3_otc_cust_relations_seq.NEXTVAL
        ,SYSDATE
        ,'N'
        ,NULL
        ,NULL
        ,l.cust_acct_relate_id
        ,l.cust_account_id
        ,l.related_cust_account_id
        ,l.relationship_type
        ,l.customer_reciprocal_flag
        ,l.status
        ,l.bill_to_flag
        ,l.ship_to_flag
        --,l.created_by_module Commented as on 22/12
        --new
        ,NULL
        ,l.org_id
        ,l.org_name
        ,NULL
        ,NULL
        ,NULL
        ,NULL
        ,NULL
        ,NULL
        ,NULL);
    
    END LOOP;
    COMMIT;
    --
    fnd_file.put_line(fnd_file.log, 'Loading complete');
    
    --Apply Extract Rules
    BEGIN
     UPDATE xxs3_otc_cust_relationships xoca
        SET xoca.extract_rule_name = CASE WHEN extract_rule_name = NULL THEN 'EXT-018' ELSE extract_rule_name || '|' || 'EXT-018' END
      WHERE EXISTS (SELECT legacy_cust_account_id
               FROM xxs3_otc_customer_accounts a
              WHERE a.legacy_cust_account_id = xoca.cust_account_id
                AND a.process_flag <> 'R'
                AND a.extract_rule_name IS NOT NULL
                AND nvl(a.transform_status,'PASS') <> 'FAIL')
      AND EXISTS(SELECT legacy_cust_account_id
               FROM xxs3_otc_customer_accounts a
              WHERE a.legacy_cust_account_id = xoca.legacy_related_cust_account_id
                AND a.process_flag <> 'R'
                AND a.extract_rule_name IS NOT NULL
                AND nvl(a.transform_status,'PASS') <> 'FAIL') ;
    EXCEPTION
          WHEN OTHERS THEN
            fnd_file.put_line(fnd_file.log, 'Unexpected error during extract rules update : ' ||
                               chr(10) || SQLCODE || chr(10) ||
                               SQLERRM);                  
    END; 
     COMMIT;
    --Apply Extract Rules             
                 
    -- new change
    --Transformation
    BEGIN
      FOR l IN (SELECT xx_cust_acct_relate_id,org_id,org_name 
                 FROM xxobjt.xxs3_otc_cust_relationships
                  WHERE process_flag <> 'R'
                   AND extract_rule_name IS NOT NULL
                )
      LOOP
        IF l.org_id IS NOT NULL THEN
        
          xxs3_data_transform_util_pkg.transform(p_mapping_type => 'organization_name', p_stage_tab => 'xxobjt.xxs3_otc_cust_relationships', --Staging Table Name
                                                 p_stage_primary_col => 'XX_CUST_ACCT_RELATE_ID', --Staging Table Primary Column Name
                                                 p_stage_primary_col_val => l.xx_cust_acct_relate_id, --Staging Table Primary Column Value
                                                 p_legacy_val => l.org_name, --Legacy Value
                                                 p_stage_col => 'S3_ORG_NAME', --Staging Table Name
                                                 p_err_code => l_err_code, -- Output error code
                                                 p_err_msg => l_err_msg);
        END IF;
      END LOOP;
    EXCEPTION
      WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log, 'Unexpected error during transformation : ' ||
                           chr(10) || SQLCODE || chr(10) ||
                           SQLERRM);
    END;
    
    
    --new change
    --Customer Relationship
  
    SELECT COUNT(1)
    INTO l_count_cust_relshp
    FROM xxobjt.xxs3_otc_cust_relationships;
  
    fnd_file.put_line(fnd_file.output, rpad('Customer RelationShip Extract Records Count Report', 100, ' '));
    fnd_file.put_line(fnd_file.output, rpad('============================================================', 200, ' '));
    fnd_file.put_line(fnd_file.output, rpad('Run date and time:    ' ||
                            to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI'), 100, ' '));
    fnd_file.put_line(fnd_file.output, rpad('============================================================', 200, ' '));
    fnd_file.put_line(fnd_file.output, '');
    fnd_file.put_line(fnd_file.output, rpad('Track Name', 10, ' ') ||
                       chr(32) ||
                       rpad('Entity Name', 30, ' ') ||
                       chr(32) ||
                       rpad('Total Count', 15, ' '));
    fnd_file.put_line(fnd_file.output, rpad('===========================================================', 200, ' '));
  
    fnd_file.put_line(fnd_file.output, '');
  
    fnd_file.put_line(fnd_file.output, rpad('OTC', 10, ' ') || ' ' ||
                       rpad('CUSTOMER RELATION SHIP', 30, ' ') || ' ' ||
                       rpad(l_count_cust_relshp, 15, ' '));
    fnd_file.put_line(fnd_file.output, rpad('=========END OF REPORT===============', 200, ' '));
    fnd_file.put_line(fnd_file.output, '');
  
  EXCEPTION
  
    WHEN OTHERS THEN
      x_retcode        := 2;
      x_errbuf         := 'Unexpected error: ' || SQLERRM;
      l_status_message := SQLCODE || chr(10) || SQLERRM;
      fnd_file.put_line(fnd_file.log, 'Unexpected error during data extraction : ' ||
                         chr(10) || l_status_message);
      fnd_file.put_line(fnd_file.log, '--------------------------------------');
    
  END cust_relation_extract_data;

END xxs3_otc_customer_pkg;
/
