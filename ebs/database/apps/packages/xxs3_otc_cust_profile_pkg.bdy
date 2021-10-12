CREATE OR REPLACE PACKAGE BODY xxs3_otc_cust_profile_pkg AS

  ----------------------------------------------------------------------------
  --  name:            XXS3_OTC_CUST_PROFILE_PKG
  --  create by:       Mishal Kumar
  --  Revision:        1.0
  --  creation date:   23/05/2016
  ----------------------------------------------------------------------------
  --  purpose :        Package to extract the Customer Profile fields
  --                   from Legacy system
  ----------------------------------------------------------------------------
  --  ver  date        name                         desc
  --  1.0  23/05/2016  Mishal Kumar                 Initial build
  ----------------------------------------------------------------------------
  report_error EXCEPTION;

  g_request_id CONSTANT NUMBER := fnd_global.conc_request_id;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Insert in to DQ table for validation of errors and update the master table
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  26/04/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  PROCEDURE insert_update_dq(p_xx_customer_profiles_id     IN NUMBER,
                             p_rule_name                   IN VARCHAR2,
                             p_reject_code                 IN VARCHAR2,
                             p_legacy_cust_acct_profile_id NUMBER) IS
  BEGIN
    UPDATE xxobjt.xxs3_otc_customer_profiles
       SET process_flag = 'Q'
     WHERE xx_customer_profiles_id = p_xx_customer_profiles_id;
    COMMIT;
    --FND_FILE.PUT_LINE(FND_FILE.LOG, 'Happening');
    INSERT INTO xxobjt.xxs3_otc_customer_profiles_dq
      (xx_dq_customer_profiles_id,
       xx_customer_profiles_id,
       rule_name,
       notes)
    VALUES
      (xxobjt.xxs3_otc_cust_profiles_dq_seq.NEXTVAL,
       p_xx_customer_profiles_id,
       p_rule_name,
       p_reject_code);
    COMMIT;
  END insert_update_dq;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: Insert in to DQ table for validation of errors and update the master table against reject
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  26/04/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  PROCEDURE insert_update_dq_r(p_xx_customer_profiles_id     IN NUMBER,
                               p_rule_name                   IN VARCHAR2,
                               p_reject_code                 IN VARCHAR2,
                               p_legacy_cust_acct_profile_id NUMBER) IS
  BEGIN
    UPDATE xxobjt.xxs3_otc_customer_profiles
       SET process_flag = 'R'
     WHERE xx_customer_profiles_id = p_xx_customer_profiles_id;
    COMMIT;
    --FND_FILE.PUT_LINE(FND_FILE.LOG, 'Happening');
    INSERT INTO xxobjt.xxs3_otc_customer_profiles_dq
      (xx_dq_customer_profiles_id,
       xx_customer_profiles_id,
       rule_name,
       notes)
    VALUES
      (xxobjt.xxs3_otc_cust_profiles_dq_seq.NEXTVAL,
       p_xx_customer_profiles_id,
       p_rule_name,
       p_reject_code);
    COMMIT;
  END insert_update_dq_r;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: Insert in to DQ table for validation of errors for Customer profile amounts
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  26/04/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  PROCEDURE insert_update_amt_dq(p_xx_cust_profile_amt_id       IN NUMBER,
                                 p_rule_name                    IN VARCHAR2,
                                 p_reject_code                  IN VARCHAR2,
                                 p_legacy_cust_acct_prof_amt_id NUMBER) IS
  BEGIN
    UPDATE xxobjt.xxs3_otc_cust_profile_amts
       SET process_flag = 'Q'
     WHERE xx_cust_profile_amt_id = p_xx_cust_profile_amt_id;
    COMMIT;
    --FND_FILE.PUT_LINE(FND_FILE.LOG, 'Happening');
    INSERT INTO xxobjt.xxs3_otc_cust_profile_amts_dq
      (xx_dq_cust_profile_amt_id,
       xx_cust_profile_amt_id,
       rule_name,
       notes,
       dq_status)
    VALUES
      (xxobjt.xxs3_otc_cust_prof_amts_dq_seq.NEXTVAL,
       p_xx_cust_profile_amt_id,
       p_rule_name,
       p_reject_code,
       'Q');
    COMMIT;
  END insert_update_amt_dq;

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
                FROM xxobjt.xxs3_otc_customer_profiles
               WHERE process_flag = 'N') LOOP
      l_status := TRUE;
      --
      x_result030   := xxs3_dq_util_pkg.eqt_030(i.site_use_id);
      x_result042   := xxs3_dq_util_pkg.eqt_042(i.collector_id);
      x_result043   := xxs3_dq_util_pkg.eqt_043(i.cust_account_id, i.credit_checking);
      x_result044   := xxs3_dq_util_pkg.eqt_044(i.override_terms);
      x_result044_1 := xxs3_dq_util_pkg.eqt_044(i.credit_hold);
      x_result045   := xxs3_dq_util_pkg.eqt_045(i.cust_account_id, i.profile_class_id);
      x_result046   := xxs3_dq_util_pkg.eqt_046(i.cust_account_id, i.standard_terms);
      x_result048   := xxs3_dq_util_pkg.eqt_048(i.send_statements, i.statement_cycle_id);
      x_result049   := xxs3_dq_util_pkg.eqt_049(i.send_statements, i.tax_printing_option);
      --
      IF x_result030 = TRUE THEN
        insert_update_dq(i.xx_customer_profiles_id, 'EQT_030', 'EQT_030 :Should be Null', i.legacy_cust_account_profile_id);
        l_status := FALSE;
      END IF;
      --
      IF x_result042 = TRUE THEN
        insert_update_dq_r(i.xx_customer_profiles_id, 'EQT_042', 'EQT_042 :Invalid Person', i.legacy_cust_account_profile_id);
        l_status := FALSE;
      END IF;
      --
      IF x_result043 = TRUE THEN
        insert_update_dq(i.xx_customer_profiles_id, 'EQT_043', 'EQT_043 :Incorrect Credit Check Value', i.legacy_cust_account_profile_id);
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
               WHERE cust_account_id = i.cust_account_id)
         AND country = 'US';
      IF l_count <> 0 THEN
        IF x_result044 = TRUE THEN
          insert_update_dq(i.xx_customer_profiles_id, 'EQT_044', 'EQT_044 :Override Term should be Y', i.legacy_cust_account_profile_id);
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
               WHERE cust_account_id = i.cust_account_id)
         AND country = 'US';
      IF l_count <> 0 THEN
        IF x_result044_1 = TRUE THEN
          insert_update_dq(i.xx_customer_profiles_id, 'EQT_044', 'EQT_044 :credit hold Should be Y', i.legacy_cust_account_profile_id);
          l_status := FALSE;
        END IF;
      END IF;
      --
      IF x_result045 = TRUE THEN
        insert_update_dq(i.xx_customer_profiles_id, 'EQT_045', 'EQT_045 :Invalid US Profile Class', i.legacy_cust_account_profile_id);
        l_status := FALSE;
      END IF;
      --
      IF x_result046 = TRUE THEN
        insert_update_dq(i.xx_customer_profiles_id, 'EQT_046', 'EQT_046 :Invalid US Cust Profile Terms', i.legacy_cust_account_profile_id);
        l_status := FALSE;
      END IF;
      --
      IF x_result048 = TRUE THEN
        insert_update_dq(i.xx_customer_profiles_id, 'EQT_048', 'EQT_048 :Missing Cust Statement Cycle', i.legacy_cust_account_profile_id);
        l_status := FALSE;
      END IF;
      --
      IF x_result049 = TRUE THEN
        insert_update_dq(i.xx_customer_profiles_id, 'EQT_049', 'EQT_049 :Invalid Cust Statement Print Option', i.legacy_cust_account_profile_id);
        l_status := FALSE;
      END IF;
      --
      IF l_status = TRUE THEN
        BEGIN
          UPDATE xxobjt.xxs3_otc_customer_profiles
             SET process_flag = 'Y'
           WHERE xx_customer_profiles_id = i.xx_customer_profiles_id;
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
  -- Purpose: Extract data from staging tables for quality check of Customer Profile Amounts
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  -- 1.0  23/05/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE quality_check_profile_amts IS
    l_count       NUMBER := 0;
    x_result030   BOOLEAN;
    x_result050   BOOLEAN;
    x_result051   BOOLEAN;
    x_result051_1 BOOLEAN;
    x_result052   BOOLEAN;
    x_result052_1 BOOLEAN;
    x_result052_2 BOOLEAN;
    x_result052_3 BOOLEAN;
    x_result052_4 BOOLEAN;
    x_result052_5 BOOLEAN;
    x_result052_6 BOOLEAN;
    l_status      BOOLEAN := TRUE;

    --
  BEGIN
    FOR i IN (SELECT *
                FROM xxobjt.xxs3_otc_cust_profile_amts
               WHERE extract_rule_name IS NOT NULL) LOOP
      l_status := TRUE;
      --
      /*x_result030   := xxs3_dq_util_pkg.eqt_030(i.site_use_id);
      x_result050   := xxs3_dq_util_pkg.eqt_050(i.currency_code);
      x_result051   := xxs3_dq_util_pkg.eqt_051(i.trx_credit_limit);
      x_result051_1 := xxs3_dq_util_pkg.eqt_051(i.overall_credit_limit);*/
      x_result052   := xxs3_dq_util_pkg.eqt_052(i.attribute1, i.attribute2);
      x_result052_1 := xxs3_dq_util_pkg.eqt_052(i.attribute1, i.attribute3);
      x_result052_2 := xxs3_dq_util_pkg.eqt_052(i.attribute1, i.attribute4);
      x_result052_3 := xxs3_dq_util_pkg.eqt_052(i.attribute1, i.attribute5);
      x_result052_4 := xxs3_dq_util_pkg.eqt_052(i.attribute1, i.attribute7);
      x_result052_5 := xxs3_dq_util_pkg.eqt_052(i.attribute1, i.attribute8);
      x_result052_6 := xxs3_dq_util_pkg.eqt_052(i.attribute1, i.attribute9);
      --
     /* IF x_result030 = TRUE THEN
        insert_update_amt_dq(i.xx_cust_profile_amt_id, 'EQT_030', 'EQT_030 :Should be Null', i.legacy_cust_acct_prof_amt_id);
      END IF;
      --
      IF x_result050 = TRUE THEN
        insert_update_amt_dq(i.xx_cust_profile_amt_id, 'EQT_050', 'EQT_050 :Currency is not USD', i.legacy_cust_acct_prof_amt_id);
      END IF;
      --
      IF x_result051 = TRUE THEN
        insert_update_amt_dq(i.xx_cust_profile_amt_id, 'EQT_051', 'EQT_051 :Non Standard Low Credit Limit', i.legacy_cust_acct_prof_amt_id);
        l_status := FALSE;
      END IF;
      --
      IF x_result051_1 = TRUE THEN
        insert_update_amt_dq(i.xx_cust_profile_amt_id, 'EQT_051', 'EQT_051 :Non Standard Low Credit Limit', i.legacy_cust_acct_prof_amt_id);
        l_status := FALSE;
      END IF;*/
      --
      IF x_result052 = TRUE THEN
        insert_update_amt_dq(i.xx_cust_profile_amt_id, 'EQT_052', 'EQT_052 :Invalid Atradius Values', i.legacy_cust_acct_prof_amt_id);
        l_status := FALSE;
      END IF;
      --
      IF x_result052_1 = TRUE THEN
        insert_update_amt_dq(i.xx_cust_profile_amt_id, 'EQT_052', 'EQT_052 :Invalid Atradius Values', i.legacy_cust_acct_prof_amt_id);
        l_status := FALSE;
      END IF;
      --
      IF x_result052_2 = TRUE THEN
        insert_update_amt_dq(i.xx_cust_profile_amt_id, 'EQT_052', 'EQT_052 :Invalid Atradius Values', i.legacy_cust_acct_prof_amt_id);
        l_status := FALSE;
      END IF;
      --
      IF x_result052_3 = TRUE THEN
        insert_update_amt_dq(i.xx_cust_profile_amt_id, 'EQT_052', 'EQT_052 :Invalid Atradius Values', i.legacy_cust_acct_prof_amt_id);
        l_status := FALSE;
      END IF;
      --
      IF x_result052_4 = TRUE THEN
        insert_update_amt_dq(i.xx_cust_profile_amt_id, 'EQT_052', 'EQT_052 :Invalid Atradius Values', i.legacy_cust_acct_prof_amt_id);
        l_status := FALSE;
      END IF;
      --
      IF x_result052_5 = TRUE THEN
        insert_update_amt_dq(i.xx_cust_profile_amt_id, 'EQT_052', 'EQT_052 :Invalid Atradius Values', i.legacy_cust_acct_prof_amt_id);
        l_status := FALSE;
      END IF;
      --
      IF x_result052_6 = TRUE THEN
        insert_update_amt_dq(i.xx_cust_profile_amt_id, 'EQT_052', 'EQT_052 :Invalid Atradius Values', i.legacy_cust_acct_prof_amt_id);
        l_status := FALSE;
      END IF;
      --
      IF l_status = TRUE THEN
       BEGIN
          UPDATE xxobjt.xxs3_otc_cust_profile_amts
             SET process_flag = 'Y'
           WHERE xx_cust_profile_amt_id = i.xx_cust_profile_amt_id;
       EXCEPTION
          WHEN OTHERS THEN
            fnd_file.put_line(fnd_file.log, 'Unexpected error during process_flag update : ' ||
                     chr(10) || SQLCODE || chr(10) || SQLERRM);
       END;
      END IF;
      --
    END LOOP;
    COMMIT;
  END quality_check_profile_amts;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: Generate Data Quality Report for Customer Profiles
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0 24/05/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  PROCEDURE report_data_cust_profiles(p_entity IN VARCHAR2) IS
    CURSOR c_profile IS
      SELECT nvl(ld.rule_name, ' ') rule_name,
             nvl(ld.notes, ' ') notes,
             l.legacy_cust_account_profile_id legacy_cust_account_profile_id,
             ld.xx_customer_profiles_id xx_customer_profiles_id
        FROM xxobjt.xxs3_otc_customer_profiles    l,
             xxobjt.xxs3_otc_customer_profiles_dq ld
       WHERE l.xx_customer_profiles_id = ld.xx_customer_profiles_id
         AND l.process_flag IN ('Q', 'R');

    p_delimiter    VARCHAR2(5) := '~';
    l_err_msg      VARCHAR2(2000);
    l_count_dq     NUMBER;
    l_count_reject NUMBER;
    --
    CURSOR c_profile_r IS
      SELECT nvl(ld.rule_name, ' ') rule_name,
             nvl(ld.notes, ' ') notes,
             l.legacy_cust_account_profile_id legacy_cust_account_profile_id,
             ld.xx_customer_profiles_id xx_customer_profiles_id
        FROM xxobjt.xxs3_otc_customer_profiles    l,
             xxobjt.xxs3_otc_customer_profiles_dq ld
       WHERE l.xx_customer_profiles_id = ld.xx_customer_profiles_id
         AND l.process_flag IN ('R');
  BEGIN
    SELECT COUNT(1)
      INTO l_count_dq
      FROM xxobjt.xxs3_otc_customer_profiles
     WHERE process_flag IN ('Q', 'R');

    SELECT COUNT(1)
      INTO l_count_reject
      FROM xxobjt.xxs3_otc_customer_profiles
     WHERE process_flag = 'R';

    fnd_file.put_line(fnd_file.output, rpad('Report name = Data Quality Error Report' ||
                            p_delimiter, 100, ' '));
    fnd_file.put_line(fnd_file.output, rpad('========================================' ||
                            p_delimiter, 100, ' '));
    fnd_file.put_line(fnd_file.output, rpad('Data Migration Object Name = Customer Profiles' ||
                            p_delimiter, 100, ' '));
    fnd_file.put_line(fnd_file.output, '');
    fnd_file.put_line(fnd_file.output, rpad('Run date and time:    ' ||
                            to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') ||
                            p_delimiter, 100, ' '));
    fnd_file.put_line(fnd_file.output, rpad('Total Record Count Having DQ Issues = ' ||
                            l_count_dq || p_delimiter, 100, ' '));
    fnd_file.put_line(fnd_file.output, rpad('Total Record Count Rejected =  ' ||
                            l_count_reject || p_delimiter, 100, ' '));
    fnd_file.put_line(fnd_file.output, '');
    fnd_file.put_line(fnd_file.output, rpad('Customer Profile DQ status report', 100, ' '));
    fnd_file.put_line(fnd_file.output, rpad('=============================', 100, ' '));
    fnd_file.put_line(fnd_file.output, '');
    fnd_file.put_line(fnd_file.output, 'Date:    ' ||
                       to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI'));

    fnd_file.put_line(fnd_file.output, '');

    fnd_file.put_line(fnd_file.output, rpad('Track Name', 10, ' ') ||
                       p_delimiter ||
                       rpad('Entity Name', 19, ' ') ||
                       p_delimiter ||
                       rpad('XX_CUSTOMER_PROFILES_ID', 23, ' ') ||
                       p_delimiter ||
                       rpad('LEGACY_CUST_ACCT_PROFILE_ID', 29, ' ') ||
                       p_delimiter ||
                       rpad('Rule Name', 20, ' ') ||
                       p_delimiter ||
                       rpad('Reason Code', 50, ' '));
    FOR r_data IN c_profile LOOP
      fnd_file.put_line(fnd_file.output, rpad('OTC', 10, ' ') ||
                         p_delimiter ||
                         rpad('CUSTOMER PROFILES', 23, ' ') ||
                         p_delimiter ||
                         rpad(r_data.xx_customer_profiles_id, 23, ' ') ||
                         p_delimiter ||
                         rpad(r_data.legacy_cust_account_profile_id, 29, ' ') ||
                         p_delimiter ||
                         rpad(r_data.rule_name, 20, ' ') ||
                         p_delimiter ||
                         rpad(r_data.notes, 50, ' '));

    END LOOP;
    fnd_file.put_line(fnd_file.output, rpad('=============================', 100, ' '));
    fnd_file.put_line(fnd_file.output, rpad('!!END OF REPORT!!', 100, ' '));
    -------------------------------------------------------------------------------------------
    -- DQ report only for rejected ones (will be shown in lof file)
    fnd_file.put_line(fnd_file.log, '"Track Name","Entity Name","XX_CUSTOMER_PROFILES_ID ", "LEGACY_CUST_ACCT_PROFILE_ID","Rule Name","Notes"');

    FOR i IN c_profile_r LOOP

      fnd_file.put_line(fnd_file.log, 'OTC' || p_delimiter ||
                         'Customer Profiles' || p_delimiter ||
                         i.xx_customer_profiles_id ||
                         p_delimiter ||
                         i.legacy_cust_account_profile_id ||
                         p_delimiter || i.rule_name ||
                         p_delimiter || i.notes);

    --fnd_file.put_line(fnd_file.log, 'CS'|| p_delimiter||'Instance'||p_delimiter||i.rule_name||p_delimiter||i.notes||p_delimiter||i.xx_instance_id);
    END LOOP;
    fnd_file.put_line(fnd_file.log, '!!END OF REPORT!!');
  END report_data_cust_profiles;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: Generate Data Quality Report for Customer Profile Amounts
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0 24/05/2016  Mishal Kumar                  Initial build
  -----------------------------------------------------------------------------------------------
  PROCEDURE report_data_cust_profile_amts(p_entity IN VARCHAR2) IS
    CURSOR c_profile_amt IS
      SELECT nvl(ld.rule_name, ' ') rule_name,
             nvl(ld.notes, ' ') notes,
             l.legacy_cust_acct_prof_amt_id legacy_cust_acct_prof_amt_id,
             ld.xx_cust_profile_amt_id xx_cust_profile_amt_id,
             ld.dq_status
        FROM xxobjt.xxs3_otc_cust_profile_amts    l,
             xxobjt.xxs3_otc_cust_profile_amts_dq ld
       WHERE l.xx_cust_profile_amt_id = ld.xx_cust_profile_amt_id
         AND l.process_flag IN ('Q', 'R');

    p_delimiter    VARCHAR2(5) := '~';
    l_err_msg      VARCHAR2(2000);
    l_count_dq     NUMBER;
    l_count_reject NUMBER;

  BEGIN
    SELECT COUNT(1)
      INTO l_count_dq
      FROM xxobjt.xxs3_otc_cust_profile_amts
     WHERE process_flag IN ('Q', 'R');

    SELECT COUNT(1)
      INTO l_count_reject
      FROM xxobjt.xxs3_otc_cust_profile_amts
     WHERE process_flag = 'R';

    fnd_file.put_line(fnd_file.output, rpad('Report name = Data Quality Error Report' ||
                            p_delimiter, 100, ' '));
    fnd_file.put_line(fnd_file.output, rpad('========================================' ||
                            p_delimiter, 100, ' '));
    fnd_file.put_line(fnd_file.output, rpad('Data Migration Object Name = Customer Profiles' ||
                            p_delimiter, 100, ' '));
    fnd_file.put_line(fnd_file.output, '');
    fnd_file.put_line(fnd_file.output, rpad('Run date and time:    ' ||
                            to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') ||
                            p_delimiter, 100, ' '));
    fnd_file.put_line(fnd_file.output, rpad('Total Record Count Having DQ Issues = ' ||
                            l_count_dq || p_delimiter, 100, ' '));
    fnd_file.put_line(fnd_file.output, rpad('Total Record Count Rejected =  ' ||
                            l_count_reject || p_delimiter, 100, ' '));
    fnd_file.put_line(fnd_file.output, '');
    fnd_file.put_line(fnd_file.output, rpad('Customer Profile Amounts DQ status report', 100, ' '));
    fnd_file.put_line(fnd_file.output, rpad('=============================', 100, ' '));
    fnd_file.put_line(fnd_file.output, '');
    fnd_file.put_line(fnd_file.output, 'Date:    ' ||
                       to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI'));

    fnd_file.put_line(fnd_file.output, '');

    fnd_file.put_line(fnd_file.output, rpad('Track Name', 10, ' ') ||
                       p_delimiter ||
                       rpad('Entity Name', 11, ' ') ||
                       p_delimiter ||
                       rpad('XX_CUST_PROFILE_AMT_ID', 23, ' ') ||
                       p_delimiter ||
                       rpad('LEGACY_CUST_ACCT_PROF_AMT_ID', 29, ' ') ||
                       p_delimiter ||
                       rpad('Rule Name', 20, ' ') ||
                       p_delimiter ||
                       rpad('Reason Code', 50, ' '));
    FOR r_data IN c_profile_amt LOOP
      fnd_file.put_line(fnd_file.output, rpad('OTC', 10, ' ') ||
                         p_delimiter ||
                         rpad('CUSTOMER PROFILES', 23, ' ') ||
                         p_delimiter ||
                         rpad(r_data.xx_cust_profile_amt_id, 23, ' ') ||
                         p_delimiter ||
                         rpad(r_data.legacy_cust_acct_prof_amt_id, 29, ' ') ||
                         p_delimiter ||
                         rpad(r_data.rule_name, 20, ' ') ||
                         p_delimiter ||
                         rpad(r_data.notes, 50, ' '));

    END LOOP;
    fnd_file.put_line(fnd_file.output, rpad('=============================', 100, ' '));
    fnd_file.put_line(fnd_file.output, rpad('End Of Report', 100, ' '));
  END report_data_cust_profile_amts;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required Customer Profiles fields and insert into
  --           staging table XXS3_OTC_CUSTOMER_PROFILES
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0 26/04/2016  Mishal Kumar                  Initial build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE profile_extract_data(x_errbuf  OUT VARCHAR2,
                                 x_retcode OUT NUMBER) IS
    l_errbuf             VARCHAR2(2000);
    l_retcode            VARCHAR2(1);
    l_requestor          NUMBER;
    l_program_short_name VARCHAR2(100);
    l_status_message     VARCHAR2(4000);
    l_counter            NUMBER;
    l_count_cust_prof  NUMBER;
    --
    /*CURSOR cur_cust_prof_extract IS
      SELECT cust_account_profile_id legacy_cust_account_profile_id,
             created_by,
             creation_date,
             cust_account_id,
             status,
             --collector_id,
             \*(SELECT DISTINCT A.NAME
                FROM ar_collectors A
               WHERE A.collector_id = collector_id) collector_name,*\
             \*(SELECT person_id FROM per_all_people_f
                                                                 WHERE employee_number = NVL(COLLECTOR_ID, -99) AND current_employee_flag = 'Y') S3_COLLECTOR_ID,*\
             --credit_analyst_id,
             \*(SELECT person_id FROM per_all_people_f
                                                                 WHERE employee_number = NVL(CREDIT_ANALYST_ID, -99)) S3_CREDIT_ANALYST_ID,*\
             credit_checking,
             tolerance,
             discount_terms,
             dunning_letters,
             send_statements,
             credit_balance_statements,
             credit_hold,
             profile_class_id,
             site_use_id,
             standard_terms,
             override_terms,
             statement_cycle_id,
             autocash_hierarchy_id,
             attribute1 parent_account_number,
             attribute2 credit_hold_reason,
             attribute4 exempt_type,
             attribute5 score_card,
             auto_rec_incl_disputed_flag,
             tax_printing_option,
             charge_on_finance_charge_flag,
             grouping_rule_id,
             cons_inv_flag,
             party_id
        FROM hz_customer_profiles
       WHERE cust_account_id IN
             (SELECT DISTINCT legacy_cust_account_id
                FROM xxs3_otc_customer_accounts
               WHERE process_flag != 'R') \*(SELECT cust_account_id
                                               FROM hz_cust_accounts
                                              WHERE status = 'A')*\
         AND site_use_id IS NULL;*/

 CURSOR cur_cust_prof_extract IS
 SELECT cust_account_profile_id legacy_cust_account_profile_id,
        hcp.created_by,
        hcp.creation_date,
        hcp.cust_account_id,
        hcp.status,
        hcp.collector_id,
        a.NAME collector_name,
        hcp.credit_analyst_id,
        (SELECT source_name
           FROM jtf_rs_resource_extns
          WHERE resource_id = credit_analyst_id) credit_analyst_name,
        credit_checking,
        tolerance,
        discount_terms,
        dunning_letters,
        send_statements,
        credit_balance_statements,
        credit_hold,
        profile_class_id,
        site_use_id,
        standard_terms,
        override_terms,
        statement_cycle_id,
        autocash_hierarchy_id,
        hcp.attribute1 parent_account_number,
        hcp.attribute2 credit_hold_reason,
        hcp.attribute4 exempt_type,
        hcp.attribute5 score_card,
        auto_rec_incl_disputed_flag,
        tax_printing_option,
        charge_on_finance_charge_flag,
        grouping_rule_id,
        cons_inv_flag,
        hcp.party_id
   FROM hz_customer_profiles hcp, hz_cust_accounts hca, ar_collectors a
  WHERE hcp.cust_account_id IN
        (SELECT DISTINCT legacy_cust_account_id
           FROM xxs3_otc_customer_accounts
          WHERE process_flag != 'R')
    AND hcp.site_use_id IS NULL
    AND hcp.cust_account_id = hca.cust_account_id
    AND hcp.collector_id = a.collector_id;
    --
  BEGIN
    x_retcode := 0;
    x_errbuf  := 'COMPLETE';
    --

    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_otc_customer_profiles';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_otc_customer_profiles_dq';

    FOR i IN cur_cust_prof_extract LOOP
      INSERT INTO xxobjt.xxs3_otc_customer_profiles
        (xx_customer_profiles_id,
         --cust_account_profile_id,
         legacy_cust_account_profile_id,
         created_by,
         creation_date,
         cust_account_id,
         s3_legacy_cust_acct_profile_id,
         status,
         collector_id,
         collector_name,
         credit_analyst_id,
         credit_analyst_name,
         credit_checking,
         tolerance,
         discount_terms,
         dunning_letters,
         send_statements,
         credit_balance_statements,
         credit_hold,
         profile_class_id,
         site_use_id,
         standard_terms,
         s3_standard_terms,
         override_terms,
         statement_cycle_id,
         autocash_hierarchy_id,
         parent_account_number,
         credit_hold_reason,
         exempt_type,
         score_card,
         auto_rec_incl_disputed_flag,
         tax_printing_option,
         charge_on_finance_charge_flag,
         grouping_rule_id,
         cons_inv_flag,
         party_id,
         date_extracted_on,
         process_flag,
         transform_status,
         transform_error)
      VALUES
        (xxobjt.xxs3_otc_customer_profiles_seq.NEXTVAL,
         -- NULL,
         i.legacy_cust_account_profile_id,
         i.created_by,
         i.creation_date,
         i.cust_account_id,
         NULL,
         i.status,
         i.collector_id,
         i.collector_name,
         i.credit_analyst_id,
         i.credit_analyst_name,
         i.credit_checking,
         i.tolerance,
         i.discount_terms,
         i.dunning_letters,
         i.send_statements,
         i.credit_balance_statements,
         i.credit_hold,
         i.profile_class_id,
         i.site_use_id,
         i.standard_terms,
         NULL,
         i.override_terms,
         i.statement_cycle_id,
         i.autocash_hierarchy_id,
         i.parent_account_number,
         i.credit_hold_reason,
         i.exempt_type,
         i.score_card,
         i.auto_rec_incl_disputed_flag,
         i.tax_printing_option,
         i.charge_on_finance_charge_flag,
         i.grouping_rule_id,
         i.cons_inv_flag,
         i.party_id,
         SYSDATE,
         'N',
         NULL,
         NULL);
    END LOOP;
    COMMIT;
    --
    fnd_file.put_line(fnd_file.log, 'Loading complete');
    --
    BEGIN
      quality_check_profiles;
      fnd_file.put_line(fnd_file.log, 'DQ complete');
    EXCEPTION
      WHEN OTHERS THEN
        x_retcode        := 2;
        x_errbuf         := 'Unexpected error: ' || SQLERRM;
        l_status_message := SQLCODE || chr(10) || SQLERRM;
        fnd_file.put_line(fnd_file.log, 'Unexpected error during data extraction : ' ||
                           chr(10) || l_status_message);
        fnd_file.put_line(fnd_file.log, '--------------------------------------');
    END;
    --

    --Customer Profile

		  SELECT COUNT(1)
         INTO   l_count_cust_prof
         FROM xxobjt.xxs3_otc_customer_profiles;

      fnd_file.put_line(fnd_file.output, RPAD('Customer Profile Extract Records Count Report', 100, ' '));
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
                      RPAD('CUSTOMER PROFILE', 30, ' ') ||' ' ||
			          		   RPAD(l_count_cust_prof, 15, ' ') );
     fnd_file.put_line(fnd_file.output, RPAD('=========END OF REPORT===============', 200, ' '));
     fnd_file.put_line(fnd_file.output, '');

  EXCEPTION
      WHEN OTHERS THEN
        x_retcode        := 2;
        x_errbuf         := 'Unexpected error: ' || SQLERRM;
        l_status_message := SQLCODE || chr(10) || SQLERRM;
        fnd_file.put_line(fnd_file.log, 'Unexpected error during data extraction : ' ||
                           chr(10) || l_status_message);
        fnd_file.put_line(fnd_file.log, '--------------------------------------');
  END profile_extract_data;
  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required Customer Profiles fields and insert into
  --           staging table XXS3_OTC_CUSTOMER_PROFILES
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0 26/04/2016  Mishal Kumar                  Initial build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE profile_amt_extract_data(x_errbuf  OUT VARCHAR2,
                                     x_retcode OUT NUMBER) IS
    l_errbuf             VARCHAR2(2000);
    l_retcode            VARCHAR2(1);
    l_requestor          NUMBER;
    l_program_short_name VARCHAR2(100);
    l_status_message     VARCHAR2(4000);
    l_counter            NUMBER;
    l_count_cust_prof_amt  NUMBER;
    --
    CURSOR cur_cust_profile_amt_extract IS
      SELECT cust_acct_profile_amt_id,
             cust_account_profile_id,
             currency_code,
             trx_credit_limit,
             overall_credit_limit,
             min_statement_amount,
             attribute1,
             attribute2,
             attribute3,
             attribute4,
             attribute5,
             attribute6,
             attribute7,
             attribute8,
             attribute9,
             cust_account_id,
             site_use_id
        FROM hz_cust_profile_amts;/*
       WHERE site_use_id IS NULL*/
      
         
  BEGIN
    x_retcode := 0;
    x_errbuf  := 'COMPLETE';
    --
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.XXS3_OTC_CUST_PROFILE_AMTS';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.XXS3_OTC_CUST_PROFILE_AMTS_DQ';
    FOR i IN cur_cust_profile_amt_extract LOOP
      INSERT INTO xxobjt.xxs3_otc_cust_profile_amts
        (xx_cust_profile_amt_id,
         --cust_acct_profile_amt_id,
         legacy_cust_acct_prof_amt_id,
         cust_account_profile_id,
         currency_code,
         trx_credit_limit,
         overall_credit_limit,
         min_statement_amount,
         attribute1,
         attribute2,
         attribute3,
         attribute4,
         attribute5,
         attribute6,
         attribute7,
         attribute8,
         attribute9,
         cust_account_id,
         site_use_id,
         date_extracted_on,
         process_flag)
      VALUES
        (xxobjt.xxs3_otc_cust_profile_amts_seq.NEXTVAL,
         --NULL,
         i.cust_acct_profile_amt_id,
         i.cust_account_profile_id,
         i.currency_code,
         i.trx_credit_limit,
         i.overall_credit_limit,
         i.min_statement_amount,
         i.attribute1,
         i.attribute2,
         i.attribute3,
         i.attribute4,
         i.attribute5,
         i.attribute6,
         i.attribute7,
         i.attribute8,
         i.attribute9,
         i.cust_account_id,
         i.site_use_id,
         SYSDATE,
         'N');
    END LOOP;
    COMMIT;
    --
    fnd_file.put_line(fnd_file.log, 'Loading complete');
    --
    --Apply extract Rules
   BEGIN 
    
    UPDATE xxs3_otc_cust_profile_amts xop
        SET xop.extract_rule_name = CASE WHEN extract_rule_name = NULL THEN 'EXT-019' ELSE extract_rule_name || '|' || 'EXT-019' END
      WHERE EXISTS (SELECT legacy_cust_account_id
               FROM xxs3_otc_customer_accounts a
              WHERE a.legacy_cust_account_id = xop.cust_account_id
                AND a.process_flag <> 'R'
                AND a.extract_rule_name IS NOT NULL
                AND nvl(a.transform_status,'PASS') <> 'FAIL')
             AND xop.site_use_id IS NULL;
    
    fnd_file.put_line(fnd_file.log,'Extract Rule Name-EXT-019: '||SQL%ROWCOUNT||' rows were updated'); 
     
    EXCEPTION
      WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log, 'Unexpected error during extract rules update : ' ||
                               chr(10) || SQLCODE || chr(10) ||
                               SQLERRM);                        
    END;
    --Apply extract Rules
    
    --Auto cleanse
    
    BEGIN
    
     UPDATE xxs3_otc_cust_profile_amts
     SET s3_currency_code = 'USD',
     cleanse_status ='PASS'
     WHERE extract_rule_name IS NOT NULL;
     
          
     UPDATE xxs3_otc_cust_profile_amts
     SET s3_overall_credit_limit = 0.99,
     cleanse_status ='PASS'
     WHERE extract_rule_name IS NOT NULL
     AND trx_credit_limit <5000;
     
     UPDATE xxs3_otc_cust_profile_amts
     SET s3_overall_credit_limit = overall_credit_limit
     WHERE extract_rule_name IS NOT NULL
     AND trx_credit_limit >= 5000;
     
   EXCEPTION
      WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log, 'Unexpected error during Autocleanse'||
                           chr(10) || SQLCODE || chr(10) ||
                           SQLERRM);
    END;
    
    COMMIT;
    
    
    BEGIN
      quality_check_profile_amts;
      fnd_file.put_line(fnd_file.log, 'DQ complete');
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;
    --

   --Customer Profile Amount

		  SELECT COUNT(1)
         INTO   l_count_cust_prof_amt
         FROM xxobjt.xxs3_otc_cust_profile_amts;

      fnd_file.put_line(fnd_file.output, RPAD('Customer Profile Amount Extract Records Count Report', 100, ' '));
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
                      RPAD('CUSTOMER PROFILE AMOUNT', 30, ' ') ||' ' ||
			          		   RPAD(l_count_cust_prof_amt, 15, ' ') );
     fnd_file.put_line(fnd_file.output, RPAD('=========END OF REPORT===============', 200, ' '));
     fnd_file.put_line(fnd_file.output, '');

  EXCEPTION
    /* WHEN REPORT_ERROR THEN
    FND_FILE.PUT_LINE(FND_FILE.LOG, 'Failed to generate report');
    X_RETCODE := 1;
    X_ERRBUF  := 'Unexpected error: report error';*/
    WHEN OTHERS THEN
      x_retcode        := 2;
      x_errbuf         := 'Unexpected error: ' || SQLERRM;
      l_status_message := SQLCODE || chr(10) || SQLERRM;
      fnd_file.put_line(fnd_file.log, 'Unexpected error during data extraction : ' ||
                         chr(10) || l_status_message);
      fnd_file.put_line(fnd_file.log, '--------------------------------------');
      /*fnd_file.put_line(fnd_file.output, 'Concurrent Request processed successfully');
      fnd_file.put_line(fnd_file.output, '--------------------------------------'); */
  END profile_amt_extract_data;
END xxs3_otc_cust_profile_pkg;
/
