CREATE OR REPLACE PACKAGE BODY xxs3_cs_ib_pkg AS
  ----------------------------------------------------------------------------
  --  name:            XXS3_CS_IB_PKG
  --  create by:       TCS
  --  Revision:        1.0
  --  creation date:   18/04/2016
  ----------------------------------------------------------------------------
  --  purpose :        Package to extract the Install Base template fields
  --                   from Legacy system

  ----------------------------------------------------------------------------
  --  ver  date        name                         desc
  --  1.0  18/04/2016  TCS            Initial build
  ----------------------------------------------------------------------------

  report_error EXCEPTION;
  g_request_id CONSTANT NUMBER := fnd_global.conc_request_id;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Insert in to DQ table for validation errors and update master table
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  19/04/2016  TCS            Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE insert_update_dq(p_xx_instance_id     NUMBER
                            ,p_rule_name          IN VARCHAR2
                            ,p_reject_code        IN VARCHAR2
                            ,p_legacy_instance_id NUMBER) IS
  
  BEGIN
    UPDATE xxs3_cs_instance
    SET process_flag = 'Q'
    WHERE xx_instance_id = p_xx_instance_id;
  
    UPDATE xxs3_cs_instance_attrib
    SET process_flag = 'Q'
    WHERE legacy_instance_id = p_legacy_instance_id;
  
    UPDATE xxs3_cs_instance_relation
    SET process_flag = 'Q'
    WHERE legacy_instance_id = p_legacy_instance_id;
  
    INSERT INTO xxs3_cs_instance_dq
      (xx_dq_instance_id
      ,xx_instance_id
      ,rule_name
      ,notes)
    VALUES
      (xxs3_cs_instance_dq_seq.NEXTVAL
      ,p_xx_instance_id
      ,p_rule_name
      ,p_reject_code);
  
  END insert_update_dq;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Insert in to DQ table for validation errors and update master table
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  19/04/2016  TCS            Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE insert_update_reject_dq(p_xx_instance_id     NUMBER
                                   ,p_rule_name          IN VARCHAR2
                                   ,p_reject_code        IN VARCHAR2
                                   ,p_legacy_instance_id NUMBER) IS
  
  BEGIN
    UPDATE xxs3_cs_instance
    SET process_flag = 'R'
    WHERE xx_instance_id = p_xx_instance_id;
  
    UPDATE xxs3_cs_instance_attrib
    SET process_flag = 'R'
    WHERE legacy_instance_id = p_legacy_instance_id;
  
    UPDATE xxs3_cs_instance_relation
    SET process_flag = 'R'
    WHERE legacy_instance_id = p_legacy_instance_id;
  
    INSERT INTO xxs3_cs_instance_dq
      (xx_dq_instance_id
      ,xx_instance_id
      ,rule_name
      ,notes)
    VALUES
      (xxs3_cs_instance_dq_seq.NEXTVAL
      ,p_xx_instance_id
      ,p_rule_name
      ,p_reject_code);
  
  END insert_update_reject_dq;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Update party_name
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  19/04/2016  TCS            Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE update_party_name(p_id         IN NUMBER
                             ,p_party_name IN VARCHAR2 /*,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             p_entity IN VARCHAR2*/) IS
  
    l_error_msg VARCHAR2(2000);
  
  BEGIN
  
    IF regexp_like(p_party_name, '[A-Za-z]', 'i')
    THEN
      BEGIN
        UPDATE xxs3_cs_instance
        SET s3_party_name  = regexp_replace(p_party_name, 'Inc\.|INC', 'Inc')
           ,cleanse_status = 'PASS'
        WHERE xx_instance_id = p_id
        AND regexp_like(p_party_name, 'Inc\.|INC');
      
        UPDATE xxs3_cs_instance
        SET s3_party_name  = regexp_replace(p_party_name, 'Corp\.|CORP', 'Corp')
           ,cleanse_status = 'PASS'
        WHERE xx_instance_id = p_id
        AND regexp_like(p_party_name, 'Corp\.|CORP');
      
        UPDATE xxs3_cs_instance
        SET s3_party_name  = regexp_replace(p_party_name, 'LLC\.', 'LLC')
           ,cleanse_status = 'PASS'
        WHERE xx_instance_id = p_id
        AND regexp_like(p_party_name, 'LLC\.');
      
        UPDATE xxs3_cs_instance
        SET s3_party_name  = regexp_replace(p_party_name, 'Ltd\.|LTD\.|LTD', 'Ltd')
           , --LTD\. is new rule
            cleanse_status = 'PASS'
        WHERE xx_instance_id = p_id
        AND regexp_like(p_party_name, 'Ltd\.|LTD\.|LTD');
      
        UPDATE xxs3_cs_instance
        SET s3_party_name  = regexp_replace(p_party_name, 'P\.O\.', 'PO')
           ,cleanse_status = 'PASS'
        WHERE xx_instance_id = p_id
        AND regexp_like(p_party_name, 'P\.O\.');
      
        UPDATE xxs3_cs_instance
        SET s3_party_name  = regexp_replace(p_party_name, 'A\.P\.|A/P', 'AP')
           ,cleanse_status = 'PASS'
        WHERE xx_instance_id = p_id
        AND regexp_like(p_party_name, 'A\.P\.|A/P');
      
        UPDATE xxs3_cs_instance
        SET s3_party_name  = regexp_replace(p_party_name, 'CO\.|Co\.', 'Company')
           ,cleanse_status = 'PASS'
        WHERE xx_instance_id = p_id
        AND regexp_like(p_party_name, 'CO\.|Co\.');
      
        UPDATE xxs3_cs_instance
        SET s3_party_name  = regexp_replace(p_party_name, 'A\.R\.|A/R', 'AR')
           ,cleanse_status = 'PASS'
        WHERE xx_instance_id = p_id
        AND regexp_like(p_party_name, 'A\.R\.|A/R');
      
      EXCEPTION
        WHEN OTHERS THEN
          l_error_msg := 'UNEXPECTED ERROR on Party Name update : ' ||
                         SQLERRM;
        
          UPDATE xxs3_cs_instance
          SET cleanse_status = 'FAIL'
             ,cleanse_error  = cleanse_error || '' || '' || l_error_msg
          WHERE xx_instance_id = p_id;
      END;
    END IF;
    --COMMIT;
  
  END update_party_name;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Extract data from staging tables for quality check of CS track
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0  19/04/2016  TCS            Initial build
  -----------------------------------------------------------------------------------------------

  PROCEDURE quality_check_cs IS
  
    l_uom         VARCHAR2(10);
    l_quantity    VARCHAR2(10);
    l_attribute3  VARCHAR2(10);
    l_attribute7  VARCHAR2(10);
    l_attribute6  VARCHAR2(10);
    l_attribute4  VARCHAR2(10);
    l_attribute5  VARCHAR2(10);
    l_attribute10 VARCHAR2(10);
    l_attribute8  VARCHAR2(10);
    l_attribute11 VARCHAR2(10);
    l_attribute16 VARCHAR2(10);
    l_check_rule  VARCHAR2(10) := 'TRUE';
    l_party_type  BOOLEAN;
    l_status      VARCHAR2(10) := 'SUCCESS';
    l_step        VARCHAR2(100);
  
    /*CURSOR cur_cs_ib IS
    SELECT *
    FROM   xxs3_cs_instance
    WHERE  process_flag = 'N';*/
  
    TYPE t_instance IS TABLE OF xxs3_cs_instance%ROWTYPE INDEX BY PLS_INTEGER;
    l_instance t_instance;
  
    /*CURSOR cur_cs_relationship IS
    SELECT * from XXS3_CS_RELATIONSHIP;
    
    CURSOR cur_cs_attributes IS
    SELECT * from XXS3_CS_ATTRIBUTES;*/
  
  BEGIN
    --FOR i IN cur_cs_ib LOOP
    l_step := 'During select';
    -- BEGIN
  
    SELECT * BULK COLLECT
    INTO l_instance
    FROM xxs3_cs_instance
    WHERE process_flag = 'N';
  
    FOR i IN 1 .. l_instance.COUNT
    LOOP
    
      l_status := 'SUCCESS';
    
      IF l_instance(i).unit_of_measure IS NOT NULL
      THEN
        l_uom := xxs3_dq_util_pkg.eqt_900(l_instance(i).unit_of_measure);
      
        IF l_uom = 'FALSE'
        THEN
          insert_update_dq(l_instance(i).xx_instance_id, 'EQT_900', 'EQT_900 :Value always EA in Legacy', l_instance(i)
                           .instance_id);
          l_status := 'ERR';
        END IF;
      END IF;
    
      IF l_instance(i).quantity IS NOT NULL
      THEN
        l_quantity := xxs3_dq_util_pkg.eqt_901(l_instance(i).quantity);
      
        IF l_quantity = 'FALSE'
        THEN
          insert_update_dq(l_instance(i).xx_instance_id, 'EQT_901', 'EQT_901 :Value always 1 in Legacy', l_instance(i)
                           .instance_id);
          l_status := 'ERR';
        END IF;
      END IF;
    
      IF l_instance(i).coi IS NOT NULL
      THEN
        l_attribute3 := xxs3_dq_util_pkg.eqt_902('CSI_YES_NO', l_instance(i).coi);
      
        IF l_attribute3 = 'FALSE'
        THEN
          insert_update_dq(l_instance(i).xx_instance_id, 'EQT_902', 'EQT_902 :Invalid Value Set Att3', l_instance(i)
                           .instance_id);
          l_status := 'ERR';
        END IF;
      END IF;
    
      /*IF i.coi_date IS NOT NULL THEN
      
         l_attribute7 := xxs3_dq_util_pkg.eqt_902('FND_DATE_STANDARD',
                    i.coi_date);
      
         IF l_attribute7 = 'FALSE' THEN
           insert_update_dq(i.xx_instance_id,
        'EQT_902',
        'EQT_902 :Invalid Value Set  Att7',i.instance_id);
           l_status := 'ERR';
         END IF;
      END IF;
      
      IF i.initial_ship_date IS NOT NULL THEN
         l_attribute6 := xxs3_dq_util_pkg.eqt_902('FND_DATE_STANDARD',
                    i.initial_ship_date);
      
         IF l_attribute6 = 'FALSE' THEN
           insert_update_dq(i.xx_instance_id,
        'EQT_902',
        'EQT_902 :Invalid Value Set Att6',i.instance_id);
           l_status := 'ERR';
         END IF;
      END IF;*/
    
      IF l_instance(i).embedded_sw_version IS NOT NULL
      THEN
        l_attribute4 := xxs3_dq_util_pkg.eqt_902('XXCSI_EMBEEDED_SW_VERSION', l_instance(i)
                                                 .embedded_sw_version);
      
        --fnd_file.put_line(fnd_file.output, 'Attribute4 is not null :'||l_attribute4);
      
        IF l_attribute4 = 'FALSE'
        THEN
          insert_update_dq(l_instance(i).xx_instance_id, 'EQT_902', 'EQT_902 :Invalid Value Set Att4', l_instance(i)
                           .instance_id);
          l_status := 'ERR';
        END IF;
      END IF;
    
      IF l_instance(i).objet_studio_sw_version IS NOT NULL
      THEN
        l_attribute5 := xxs3_dq_util_pkg.eqt_902('XXCSI_STUDIO_SW_VERSION', l_instance(i)
                                                 .objet_studio_sw_version);
      
        IF l_attribute5 = 'FALSE'
        THEN
          insert_update_dq(l_instance(i).xx_instance_id, 'EQT_902', 'EQT_902 :Invalid Value Set Att5', l_instance(i)
                           .instance_id);
          l_status := 'ERR';
        END IF;
      END IF;
      /*l_attribute10 := EQT_902('XXCSI_EMBEEDED_SW_VERSION',i.Objet Studio SW version);
      
      IF l_attribute10 = 'FALSE' THEN
       insert_update_dq(i.XX_INSTANCE_ID,'EQT_902','EQT_902 :Invalid Value Set Att10');
      END IF;  */
    
      IF l_instance(i).cs_region IS NOT NULL
      THEN
        l_attribute8 := xxs3_dq_util_pkg.eqt_902('XXCS_CS_REGIONS', l_instance(i)
                                                 .cs_region);
      
        IF l_attribute8 = 'FALSE'
        THEN
          insert_update_dq(l_instance(i).xx_instance_id, 'EQT_902', 'EQT_902 :Invalid Value Set Att8', l_instance(i)
                           .instance_id);
          l_status := 'ERR';
        END IF;
      END IF;
    
      /*IF i.tnm_price_list IS NOT NULL THEN
        l_attribute11 := xxs3_dq_util_pkg.eqt_903(i.tnm_price_list);
      
        IF l_attribute11 = 'FALSE' THEN
          insert_update_dq(i.xx_instance_id,
       'EQT_902',
       'EQT_902 :Invalid Value Set Att11',i.instance_id);
          l_status := 'ERR';
        END IF;
      END IF;*/
    
      IF l_instance(i).transfer_to_sfdc IS NOT NULL
      THEN
        l_attribute16 := xxs3_dq_util_pkg.eqt_902('CSI_YES_NO', l_instance(i)
                                                  .transfer_to_sfdc);
      
        IF l_attribute16 = 'FALSE'
        THEN
          insert_update_dq(l_instance(i).xx_instance_id, 'EQT_902', 'EQT_902 :Invalid Value Set Att16', l_instance(i)
                           .instance_id);
          l_status := 'ERR';
        END IF;
      END IF;
    
      IF l_instance(i).party_type = 'ORGANIZATION'
      THEN
        l_check_rule := xxs3_dq_util_pkg.eqt_001(l_instance(i)
                                                 .s3_party_name);
      
        IF l_check_rule = 'FALSE'
        THEN
          insert_update_dq(l_instance(i).xx_instance_id, 'EQT_001:Standardize Organization Name', 'Non-std Org Name', l_instance(i)
                           .instance_id);
          l_status := 'ERR';
        END IF;
      ELSIF l_instance(i).party_type = 'PERSON'
      THEN
      
        l_check_rule := xxs3_dq_util_pkg.eqt_002(l_instance(i)
                                                 .s3_party_name);
      
        IF l_check_rule = 'FALSE'
        THEN
          insert_update_dq(l_instance(i).xx_instance_id, 'EQT_002:Standardize Person Name', 'Non-std Person Name', l_instance(i)
                           .instance_id);
          l_status := 'ERR';
        END IF;
      
      ELSE
        l_party_type := xxs3_dq_util_pkg.eqt_017(l_instance(i).party_type);
      
        IF l_party_type = TRUE
        THEN
          insert_update_dq(l_instance(i).xx_instance_id, 'EQT_017:Party Type LOV', 'Invalid Party_type', l_instance(i)
                           .instance_id);
          l_status := 'ERR';
        END IF;
      END IF;
    
      IF l_status <> 'ERR'
      THEN
        UPDATE xxs3_cs_instance
        SET process_flag = 'Y'
        WHERE xx_instance_id = l_instance(i).xx_instance_id;
      
        /* UPDATE xxs3_cs_instance_attrib
        SET    process_flag = 'Y'
        WHERE  legacy_instance_id = l_instance(i).instance_id;*/
      
        /* UPDATE xxs3_cs_instance_relation
        SET    process_flag = 'Y'
        WHERE  legacy_instance_id = l_instance(i).instance_id;*/
      
      END IF;
    
    END LOOP;
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE = -24381
      THEN
        FOR indx IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
        LOOP
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
    
  END quality_check_cs;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Generate excel report
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0 19/04/2016  TCS            Initial build
  -----------------------------------------------------------------------------------------------
  PROCEDURE report_data /*(\*p_email_id IN VARCHAR2*\)*/
   IS
    CURSOR c_int IS
      SELECT 'CS'
            ,'Instance'
            ,xcid.rule_name rule_name
            ,xcid.notes notes
            ,xci.instance_id instance_id
            ,xci.xx_instance_id xx_instance_id
      FROM xxs3_cs_instance    xci
          ,xxs3_cs_instance_dq xcid
      WHERE xci.xx_instance_id = xcid.xx_instance_id
      AND xci.process_flag = 'Q';
  
    l_return_status          VARCHAR2(1);
    l_msg                    VARCHAR2(500);
    l_xxssys_generic_rpt_rec xxssys_generic_rpt%ROWTYPE;
  
  BEGIN
    -- Insert header row for reporting
    l_xxssys_generic_rpt_rec.request_id      := g_request_id;
    l_xxssys_generic_rpt_rec.header_row_flag := 'Y';
    l_xxssys_generic_rpt_rec.col1            := 'Track Name';
    l_xxssys_generic_rpt_rec.col2            := 'Entity Name';
    l_xxssys_generic_rpt_rec.col3            := 'Rule Name';
    l_xxssys_generic_rpt_rec.col4            := 'Reject Reason';
    l_xxssys_generic_rpt_rec.col5            := 'Instance ID';
    l_xxssys_generic_rpt_rec.col5            := 'Instance ID';
    l_xxssys_generic_rpt_rec.col6            := 'XX Instance ID';
  
    xxssys_generic_rpt_pkg.ins_xxssys_generic_rpt(p_xxssys_generic_rpt_rec => l_xxssys_generic_rpt_rec,
                                                  
                                                  x_return_status => l_return_status,
                                                  
                                                  x_return_message => l_msg);
  
    IF l_return_status <> 'S'
    THEN
      RAISE report_error;
    END IF;
  
    FOR r_int_line IN c_int
    LOOP
      -- Insert details for reporting
      l_xxssys_generic_rpt_rec.request_id      := g_request_id;
      l_xxssys_generic_rpt_rec.email_to        := 'yuval.tal@stratasys.com';
      l_xxssys_generic_rpt_rec.header_row_flag := 'Y';
      l_xxssys_generic_rpt_rec.col1            := 'CS';
    
      l_xxssys_generic_rpt_rec.col2 := 'Instance';
      l_xxssys_generic_rpt_rec.col3 := r_int_line.rule_name;
      l_xxssys_generic_rpt_rec.col4 := r_int_line.notes;
      l_xxssys_generic_rpt_rec.col5 := r_int_line.instance_id;
      l_xxssys_generic_rpt_rec.col6 := r_int_line.xx_instance_id;
    
      xxssys_generic_rpt_pkg.ins_xxssys_generic_rpt(p_xxssys_generic_rpt_rec => l_xxssys_generic_rpt_rec,
                                                    
                                                    x_return_status => l_return_status,
                                                    
                                                    x_return_message => l_msg);
    
      IF l_return_status <> 'S'
      THEN
        RAISE report_error;
      END IF;
    END LOOP;
  
    -- Submit request to launch generic reporting.
    xxssys_generic_rpt_pkg.submit_request(p_burst_flag => 'Y',
                                          
                                          p_request_id => g_request_id, -- This would normally be launched from a program with a request_id
                                          p_l_report_title => '''IB Extract ''' ||
                                                               '||SYSDATE', -- We want report title to request_id
                                          p_l_report_pre_text1 => '', -- If all my pre-text did not fit in p_pre_text1, I can continue in p_pre_text2 parameter
                                          p_l_report_pre_text2 => '', -- Continued pre_text - when appended together will read 'Test pre text1 Test pre text2'
                                          p_l_report_post_text1 => '', -- There is a post text2 parameter, which I'm not using, so need to close my quote
                                          --p_l_report_post_text2       => ' Test post text2''',
                                          p_l_email_subject => '''IB DQ Report''',
                                          -- Subject of bursted email.  In this case, I'm using full_name (col1) in the subject
                                          p_l_email_body1 => '', -- Email body 1 (can continue to p_email_body2 if needed
                                          --p_l_email_body2             => ' Test email body2''',
                                          p_l_order_by => '', -- Order column by col5 (employee_number in our case)
                                          p_l_file_name => '''IB_DQ_FAILURE''',
                                          
                                          p_l_key_column => 'col_6',
                                          
                                          p_l_purge_table_flag => 'Y', -- Determines wether or not to PURGE xxssys_generic_rpt table after bursting
                                          
                                          x_return_status => l_return_status,
                                          
                                          x_return_message => l_msg);
    dbms_output.put_line('l_return_status: ' || l_return_status);
    dbms_output.put_line('l_msg          : ' || l_msg);
  EXCEPTION
    WHEN report_error THEN
      dbms_output.put_line('Error ' || 'l_msg: ' || l_msg);
      RAISE report_error;
    WHEN OTHERS THEN
      dbms_output.put_line('Error ' || SQLERRM);
    
  END report_data;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: Generate DQ error report
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0 19/04/2016  TCS            Initial build
  -----------------------------------------------------------------------------------------------
  PROCEDURE dq_report_data /*(\*p_email_id IN VARCHAR2*\)*/
   IS
  
    CURSOR c_report IS
      SELECT 'CS'
            ,'Instance'
            ,xcid.rule_name rule_name
            ,xcid.notes notes
            ,xci.instance_id instance_id
            ,xci.xx_instance_id xx_instance_id
      FROM xxs3_cs_instance    xci
          ,xxs3_cs_instance_dq xcid
      WHERE xci.xx_instance_id = xcid.xx_instance_id
      AND xci.process_flag = 'Q';
  
    p_delimiter VARCHAR2(5) := ';';
  
  BEGIN
  
    fnd_file.put_line(fnd_file.log, '"Track Name","Entity Name","Rule Name","Reject Reason","Instance ID","XX Instance ID"');
  
    FOR i IN c_report
    LOOP
    
      --fnd_file.put_line(fnd_file.log, 'CS'|| p_delimiter||'Instance'||p_delimiter||i.rule_name||p_delimiter||i.notes||p_delimiter||i.xx_instance_id);
    
      fnd_file.put_line(fnd_file.log, 'CS' || p_delimiter || 'Instance' ||
                         p_delimiter || i.rule_name ||
                         p_delimiter || i.notes || p_delimiter ||
                         i.xx_instance_id);
    END LOOP;
  
  END dq_report_data;
  --------------------------------------------------------------------
  --  name:              dq_report_ib
  --  create by:         TCS
  --  Revision:          1.0
  --  creation date:     13/05/2016
  --------------------------------------------------------------------
  --  purpose :          write dq report to output
  --
  --------------------------------------------------------------------
  --  ver  date          name                   desc
  --  1.0  13/05/2016    TCS     report DQ errors
  --------------------------------------------------------------------

  PROCEDURE dq_report_ib(p_entity VARCHAR2) IS
  
    CURSOR c_report_supplier IS
      SELECT nvl(xcid.rule_name, ' ') rule_name
            ,nvl(xcid.notes, ' ') notes
            ,xci.instance_id instance_id
            ,xci.xx_instance_id xx_instance_id
            ,decode(xci.process_flag, 'R', 'Y', 'Q', 'N') reject_record
      FROM xxs3_cs_instance    xci
          ,xxs3_cs_instance_dq xcid
      WHERE xci.xx_instance_id = xcid.xx_instance_id
      AND xci.process_flag IN ('Q', 'R')
      ORDER BY instance_id DESC;
  
    p_delimiter    VARCHAR2(5) := '~';
    l_err_msg      VARCHAR2(2000);
    l_count_dq     NUMBER;
    l_count_reject NUMBER;
  
  BEGIN
    /*
    x_err_code := 0;
    x_err_msg  := '';*/
  
    SELECT COUNT(1)
    INTO l_count_dq
    FROM xxs3_cs_instance xci
    WHERE xci.process_flag IN ('Q', 'R');
  
    SELECT COUNT(1)
    INTO l_count_reject
    FROM xxs3_cs_instance xci
    WHERE xci.process_flag = 'R';
  
    fnd_file.put_line(fnd_file.output, rpad('Report name = Data Quality Error Report' ||
                            p_delimiter, 100, ' '));
    fnd_file.put_line(fnd_file.output, rpad('========================================' ||
                            p_delimiter, 100, ' '));
    fnd_file.put_line(fnd_file.output, rpad('Data Migration Object Name = ' ||
                            p_entity || p_delimiter, 100, ' '));
    fnd_file.put_line(fnd_file.output, '');
    fnd_file.put_line(fnd_file.output, rpad('Run date and time:    ' ||
                            to_char(SYSDATE, 'dd-Mon-YYYY HH24:MI') ||
                            p_delimiter, 100, ' '));
    fnd_file.put_line(fnd_file.output, rpad('Total Record Count Having DQ Issues = ' ||
                            l_count_dq || p_delimiter, 100, ' '));
    fnd_file.put_line(fnd_file.output, rpad('Total Record Count Rejected =  ' ||
                            l_count_reject || p_delimiter, 100, ' '));
  
    fnd_file.put_line(fnd_file.output, '');
  
    fnd_file.put_line(fnd_file.output, rpad('Track Name', 10, ' ') ||
                       p_delimiter ||
                       rpad('Entity Name', 11, ' ') ||
                       p_delimiter ||
                       rpad('XX Instance ID', 14, ' ') ||
                       p_delimiter ||
                       rpad('Instance ID', 10, ' ') ||
                       p_delimiter ||
                       rpad('Reject Record Flag(Y/N)', 22, ' ') ||
                       p_delimiter ||
                       rpad('Rule Name', 45, ' ') ||
                       p_delimiter ||
                       rpad('Reason Code', 50, ' '));
  
    FOR r_data IN c_report_supplier
    LOOP
      fnd_file.put_line(fnd_file.output, rpad('CS', 10, ' ') || p_delimiter ||
                         rpad('INSTANCE', 11, ' ') ||
                         p_delimiter ||
                         rpad(r_data.xx_instance_id, 14, ' ') ||
                         p_delimiter ||
                         rpad(r_data.instance_id, 10, ' ') ||
                         p_delimiter ||
                         rpad(r_data.reject_record, 22, ' ') ||
                         p_delimiter ||
                         rpad(nvl(r_data.rule_name, 'NULL'), 45, ' ') ||
                         p_delimiter ||
                         rpad(nvl(r_data.notes, 'NULL'), 50, ' '));
    
    END LOOP;
  
    fnd_file.put_line(fnd_file.output, '');
    fnd_file.put_line(fnd_file.output, 'Stratasys Confidential' ||
                       p_delimiter);
  
  END dq_report_ib;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure will extract all required install base fields and insert into
  --           staging table XXS3_CS_INSTANCE
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                          Description
  --  1.0  18/04/2016  TCS            Initial build
  -- --------------------------------------------------------------------------------------------

  PROCEDURE ib_extract_data(x_errbuf  OUT VARCHAR2
                           ,x_retcode OUT NUMBER) IS
  
    --l_request_id         NUMBER := fnd_global.conc_request_id;
    l_errbuf             VARCHAR2(2000);
    l_retcode            VARCHAR2(1);
    l_requestor          NUMBER;
    l_program_short_name VARCHAR2(100);
    l_status_message     VARCHAR2(4000);
  
    CURSOR cur_ib_extract IS
      SELECT cii.instance_id      instance_id
            ,mp.organization_code organization_name
            ,
             -- cidv.organization_name,
             msi.segment1 item_number
            ,
             -- msi.description ITEM_NAME,
             cis.NAME status
            ,
             --cii.last_vld_organization_id,
             -- cii.inventory_item_id,
             cii.unit_of_measure
            ,cii.quantity
            ,cii.serial_number
            ,cii.inventory_revision
            ,
             -- cii.owner_party_account_id,
             hcao.account_number
            ,hzpo.party_name
            ,hzpo.party_number
            ,hzpo.party_type
            ,
             --cii.system_id,
             cii.install_date
            ,cidv.shipped_date
            ,cii.creation_date
            ,
             --cii.instance_status_id,
             (SELECT chsu_bill.party_number
              FROM csi_hzca_site_uses_v chsu_bill
              WHERE chsu_bill.site_use_id =
                    (SELECT cipv1.bill_to_address
                     FROM csi_instance_party_v cipv1
                     WHERE cipv1.instance_id = cii.instance_id)) bill_to_party_number
            ,(SELECT chsu_bill.party_site_number
              FROM csi_hzca_site_uses_v chsu_bill
              WHERE chsu_bill.site_use_id =
                    (SELECT cipv1.bill_to_address
                     FROM csi_instance_party_v cipv1
                     WHERE cipv1.instance_id = cii.instance_id)) bill_to_site_number
            ,
             
             (SELECT chsu_ship.party_number
              FROM csi_hzca_site_uses_v chsu_ship
              WHERE chsu_ship.site_use_id =
                    (SELECT cipv1.ship_to_address
                     FROM csi_instance_party_v cipv1
                     WHERE cipv1.instance_id = cii.instance_id)) ship_to_party_number
            ,(SELECT chsu_ship.party_site_number
              FROM csi_hzca_site_uses_v chsu_ship
              WHERE chsu_ship.site_use_id =
                    (SELECT cipv1.ship_to_address
                     FROM csi_instance_party_v cipv1
                     WHERE cipv1.instance_id = cii.instance_id)) ship_to_site_number
            ,
             -- cii.location_id,
             -- CIDV.INSTALL_LOCATION_ID,
             (SELECT DISTINCT hp_loc.party_number
              FROM apps.hz_party_sites_v hpsv
                  ,hz_parties            hp_loc
              WHERE hp_loc.party_id = hpsv.party_id
              AND nvl(hpsv.site_use_type, 'SHIP_TO') = 'SHIP_TO'
              AND hpsv.party_site_id = cii.location_id) cur_loc_party_number
            ,
             
             (SELECT DISTINCT hpsv.party_site_number
              FROM apps.hz_party_sites_v hpsv
                  ,hz_parties            hp_loc
              WHERE hp_loc.party_id = hpsv.party_id
              AND nvl(hpsv.site_use_type, 'SHIP_TO') = 'SHIP_TO'
              AND hpsv.party_site_id = cii.location_id) cur_loc_party_site_number
            ,
             
             (SELECT DISTINCT hp_loc.party_number
              FROM apps.hz_party_sites_v hpsv
                  ,hz_parties            hp_loc
              WHERE hp_loc.party_id = hpsv.party_id
              AND nvl(hpsv.site_use_type, 'SHIP_TO') = 'SHIP_TO'
              AND hpsv.party_site_id = cidv.install_location_id) install_location_party_number
            ,
             
             (SELECT DISTINCT hpsv.party_site_number
              FROM apps.hz_party_sites_v hpsv
                  ,hz_parties            hp_loc
              WHERE hp_loc.party_id = hpsv.party_id
              AND nvl(hpsv.site_use_type, 'SHIP_TO') = 'SHIP_TO'
              AND hpsv.party_site_id = cidv.install_location_id) inst_loc_party_site_number
            ,
             
             cii.accounting_class_code
            ,nvl(counter_reading_tab.counter_reading, 0) tpt_value
            ,counter_reading_tab.counter_reading_date tpt_date
            ,cidv.last_order_number
            ,cidv.last_line_number order_line_number
            ,cii.attribute1 ib_creation_flag
            ,cii.attribute3 coi
            ,cii.attribute7 coi_date
            ,cii.attribute6 initial_ship_date
            ,cii.attribute4 embedded_sw_version
            ,cii.attribute5 objet_studio_sw_version
            ,
             --cii.attribute10,
             cii.attribute8 cs_region
            ,
             -- cii.attribute11,
             cii.attribute12 sf_asset_id
            ,cii.attribute16 transfer_to_sfdc
            ,cii.attribute9  legacy_instance_id
      FROM csi_item_instances cii
          ,csi_systems_v csv
          ,csi_instance_details_v cidv
          ,mtl_system_items_b msi
          ,hz_parties hzpo
          ,hz_cust_accounts hcao
          ,csi_instance_statuses cis
          ,csi_counter_associations_v cca
          ,mtl_parameters mp
          ,(SELECT ccr.counter_id
                  ,ccr.counter_reading
                  ,ccr.value_timestamp counter_reading_date
            FROM csi_counter_readings ccr
            WHERE ccr.counter_value_id =
                  (SELECT MAX(ccr2.counter_value_id)
                   FROM csi_counter_readings ccr2
                   WHERE ccr2.counter_id = ccr.counter_id
                   GROUP BY ccr2.counter_id)) counter_reading_tab
      WHERE msi.organization_id = 91
      AND msi.inventory_item_id = cii.inventory_item_id
      AND cii.owner_party_id = hzpo.party_id
      AND mp.organization_id = cii.last_vld_organization_id
      AND cidv.instance_id = cii.instance_id
      AND hzpo.party_id = hcao.party_id
      AND cii.system_id = csv.system_id(+)
      AND hcao.status = 'A'
      AND cii.serial_number IS NOT NULL
           --   AND    cii.instance_status_id NOT IN (510, 1, 5, 10040) -- Commented on 10-NOV-2016
      AND cii.instance_status_id NOT IN
            (SELECT instance_status_id
             FROM csi_instance_statuses
             WHERE NAME IN
                   ('EXPIRED', 'Terminated', 'CREATED', 'U/G - Not Active'))
      AND instr(cii.serial_number, '-L', 1) = 0
      AND cii.instance_status_id = cis.instance_status_id
      AND cca.counter_id = counter_reading_tab.counter_id(+)
      AND cii.instance_id = cca.source_object_id(+);
    --AND cii.instance_id IN (10816,10817);
  
    /*CURSOR cur_ib_extract IS
       SELECT
       --cii.instance_id Attribute9,
        cii.creation_date creation_date,
        (SELECT mp.organization_code FROM mtl_parameters WHERE organization_id = cii.last_vld_organization_id) organization_name,
        --cidv.organization_name organization_name,
        msi.segment1 ITEM_NUMBER,
        --msi.description ITEM_NAME,
        (SELECT NAME FROM csi_instance_statuses WHERE instance_status_id = cii.instance_status_id) status,
        --cii.last_vld_organization_id organization_id,
        --cii.inventory_item_id inventory_item_id,
        cii.unit_of_measure uom,
        cii.quantity quantity,
        cii.serial_number serial_number,
        cii.inventory_revision item_revision,
        --cii.system_id end_customer_id,
        (select party_name
         from csi_systems_b csb,
              hz_cust_accounts hca,
              hz_parties hp
         where csb.customer_id = hca.cust_account_id
         and   hca.party_id=hp.party_id
         and   csb.system_id=cii.system_id) end_customer,
        cii.owner_party_account_id customer_number,
        (SELECT hca.account_number
         FROM hz_cust_accounts hca
         WHERE hca.cust_account_id = cii.owner_party_account_id) owner_account_number,
        (SELECT party_name
         FROM hz_parties hp,
            hz_cust_accounts hca
         WHERE hca.cust_account_id = cii.owner_party_account_id
         AND   hp.party_id = hca.party_id) owner,
        cii.install_date install_date,
        cidv.shipped_date shipped_date,
        --cii.instance_status_id instance_status_id,
        --cidv.status_name instance_status,
        (SELECT chsu_bill.cust_acct_site_id
         FROM   csi_hzca_site_uses_v chsu_bill
         WHERE  chsu_bill.site_use_id =
      (SELECT cipv1.bill_to_address
       FROM   csi_instance_party_v cipv1
       WHERE  cipv1.instance_id = cii.instance_id)) bill_to,
        (SELECT chsu_ship.cust_acct_site_id
         FROM   csi_hzca_site_uses_v chsu_ship
         WHERE  chsu_ship.site_use_id =
      (SELECT cipv1.ship_to_address
       FROM   csi_instance_party_v cipv1
       WHERE  cipv1.instance_id = cii.instance_id)) ship_to,
       (SELECT chsu_bill.party_address
         FROM   csi_hzca_site_uses_v chsu_bill
         WHERE  chsu_bill.site_use_id =
      (SELECT cipv1.bill_to_address
       FROM   csi_instance_party_v cipv1
       WHERE  cipv1.instance_id = cii.instance_id)) bill_to_address,
       (SELECT chsu_ship.party_address
         FROM   csi_hzca_site_uses_v chsu_ship
         WHERE  chsu_ship.site_use_id =
      (SELECT cipv1.ship_to_address
       FROM   csi_instance_party_v cipv1
       WHERE  cipv1.instance_id = cii.instance_id)) ship_to_address,
        cii.location_id current_location,
        cidv.install_location_id installed_location,
        \*DECODE (
           cidv.location_type_code,
           'HZ_PARTY_SITES',    (SELECT DISTINCT hpsv.address1
                                   FROM apps.hz_party_sites_v hpsv
                                  WHERE hpsv.party_site_id = cidv.location_id)
                             || '--'
                             || (SELECT DISTINCT hpsv.city
                                   FROM apps.hz_party_sites_v hpsv
                                  WHERE hpsv.party_site_id = cidv.location_id)
                             || '--'
                             || (SELECT DISTINCT hpsv.state
                                   FROM apps.hz_party_sites_v hpsv
                                  WHERE hpsv.party_site_id = cidv.location_id),
           'INVENTORY',    'VAISALA -- '
                        || (SELECT ionv.organization_name
                              FROM APPS.INV_ORGANIZATION_NAME_V ionv
                             WHERE ionv.organization_id =
                                      cidv.inv_organization_id)
                        || '--'
                        || cidv.inv_subinventory_name,
           'UNKNOWN')
           "Current_Location",
        DECODE (
           cidv.install_location_type_code,
           'HZ_PARTY_SITES',    (SELECT DISTINCT hpsv.address1
                                   FROM apps.hz_party_sites_v hpsv
                                  WHERE hpsv.party_site_id =
                                           cidv.install_location_id)
                             || '--'
                             || (SELECT DISTINCT hpsv.city
                                   FROM apps.hz_party_sites_v hpsv
                                  WHERE hpsv.party_site_id =
                                           cidv.install_location_id)
                             || '--'
                             || (SELECT DISTINCT hpsv.state
                                   FROM apps.hz_party_sites_v hpsv
                                  WHERE hpsv.party_site_id =
                                           cidv.install_location_id),
           NULL, 'NULL',
           'UNKNOWN')
           "Install_Location",*\
        --cii.accounting_class_code,
        counter_reading_tab.counter_reading_date tpt_date,
        nvl(counter_reading_tab.counter_reading, 0) tpt_value,
        \*cidv.last_order_number,
        cidv.last_line_number order_line_number,*\
        cii.attribute1  attribute1,
        cii.attribute3  attribute3,
        cii.attribute7  attribute7,
        cii.attribute6  attribute6,
        cii.attribute4  attribute4,
        cii.attribute5  attribute5,
        cii.attribute10 attribute10,
        cii.attribute8  attribute8,
        cii.attribute11 attribute11,
        cii.attribute12 attribute12,
        cii.attribute16 attribute16,
        cii.instance_id instance_id
       FROM   csi_item_instances cii,
    csi_systems_v csv,
    csi_instance_details_v cidv,
    mtl_system_items_b msi,
    hz_parties hzpo,
    hz_cust_accounts hcao,
    csi_instance_statuses cis,
    csi_counter_associations_v cca,
    (SELECT ccr.counter_id,
            ccr.counter_reading,
            ccr.value_timestamp counter_reading_date
     FROM   csi_counter_readings ccr
     WHERE  ccr.counter_value_id =
            (SELECT MAX(ccr2.counter_value_id)
             FROM   csi_counter_readings ccr2
             WHERE  ccr2.counter_id = ccr.counter_id
             GROUP  BY ccr2.counter_id)) counter_reading_tab
       WHERE  msi.organization_id = 91
       AND    msi.inventory_item_id = cii.inventory_item_id
       AND    cii.owner_party_id = hzpo.party_id
       AND    cidv.instance_id = cii.instance_id
       AND    hzpo.party_id = hcao.party_id
       AND    cii.system_id = csv.system_id(+)
       AND    hcao.status = 'A'
       AND    cii.serial_number IS NOT NULL
       AND    cii.instance_status_id NOT IN (\*510,*\ 1, 10040,5)
       AND    instr(cii.serial_number, '-L', 1) = 0
       AND    cii.instance_status_id = cis.instance_status_id
       AND    cca.counter_id = counter_reading_tab.counter_id(+)
       AND    cii.instance_id = cca.source_object_id(+);*/
  
    /*CURSOR cur_ib_attrib(p_instance_id NUMBER)IS
      SELECT (SELECT new_att_id.ATTRIBUTE_ID
           FROM   CSI_I_EXTENDED_ATTRIBS new_att_id
           WHERE  new_att_id.ATTRIBUTE_CODE =  ext.ATTRIBUTE_CODE
           AND    new_att_id.item_category_id = mic_pr.CATEGORY_ID
           ) attribute_id,
           cii.instance_id instance_id,
           ext.ATTRIBUTE_CODE attribute_code,
           ext.ATTRIBUTE_name attribute_name,
           ext.ATTRIBUTE_VALUE attribute_value,
           ext.ATTRIBUTE_LEVEL
    FROM   csi_inst_extend_attrib_v ext,
           csi_item_instances cii ,
           mtl_item_categories_v mic_pr ,
           (SELECT  CASE WHEN ATTRIBUTE_LEVEL = 'GLOBAL' THEN
                'All Assets'
             WHEN ATTRIBUTE_LEVEL = 'CATEGORY' THEN
               (SELECT  mic.CATEGORY_CONCAT_SEGS
               FROM   mtl_categories_v mic
               WHERE  mic.CATEGORY_ID =  cia.item_category_id
               AND    mic.STRUCTURE_ID = 50328)
             WHEN    ATTRIBUTE_LEVEL = 'ITEM' THEN
               (SELECT msi.segment1
               FROM mtl_system_items_b msi
               WHERE msi.organization_id = 91
               AND  msi.inventory_item_id = cia.INVENTORY_ITEM_ID )
            END CATEGORY_item,
            cia.attribute_id,
            ATTRIBUTE_LEVEL
      FROM CSI_I_EXTENDED_ATTRIBS cia
    ) Mashu
    WHERE  ext.INSTANCE_ID = cii.instance_id(+)
    AND    ext.instance_id= p_instance_id
    AND   ext.ATTRIBUTE_VALue IS NOT NULL
    AND    mic_pr.INVENTORY_ITEM_ID = cii.inventory_item_id
    AND    mic_pr.ORGANIZATION_ID = 91
    AND    mic_pr.CATEGORY_SET_NAME = 'Main Category Set'
    AND   ext.ATTRIBUTE_ID = Mashu.attribute_id
    AND    Mashu.ATTRIBUTE_LEVEL = 'CATEGORY'
    AND   cii.instance_id IN  (SELECT  cii.instance_id
                               FROM csi_item_instances cii ,
                                    mtl_system_items_b msi
                               WHERE cii.serial_number IS NOT NULL
                               AND  CII.ACCOUNTING_CLASS_CODE = 'CUST_PROD'
                               AND  MSI.INVENTORY_ITEM_ID = CII.INVENTORY_ITEM_ID
                               AND  MSI.ORGANIZATION_ID = 91
                               AND  cii.instance_status_id NOT IN (5,\*510,*\1,10040) --(5)Terminated,(510)CREATED,(1)EXPIRED,(10040)/U/G - Not Active
                               AND  instr(cii.serial_number,'-L',1) = 0
                               AND xxinv_utils_pkg.is_fdm_item(cii.inventory_item_id) = 'N')
    AND  (EXT.ATTRIBUTE_CODE NOT IN ('OBJ_HASP_EXP','OBJ_HASP_SV')  AND EXT.ATTRIBUTE_VALUE != 'N/A')
    
    UNION
    SELECT (SELECT new_att_id.ATTRIBUTE_ID
            FROM   CSI_I_EXTENDED_ATTRIBS new_att_id
            WHERE  new_att_id.ATTRIBUTE_CODE =  ext.ATTRIBUTE_CODE
            AND    new_att_id.item_category_id = mic_pr.CATEGORY_ID
           ) attribute_id,
           cii.instance_id instance_id,
           ext.ATTRIBUTE_CODE attribute_code,
           ext.ATTRIBUTE_name attribute_name,
           ext.ATTRIBUTE_VALUE attribute_value,
           ext.ATTRIBUTE_LEVEL
    FROM   csi_inst_extend_attrib_v ext,
           csi_item_instances cii ,
           mtl_item_categories_v mic_pr ,
           (SELECT  CASE WHEN ATTRIBUTE_LEVEL = 'GLOBAL' THEN
                'All Assets'
             WHEN ATTRIBUTE_LEVEL = 'CATEGORY' THEN
               (SELECT  mic.CATEGORY_CONCAT_SEGS
               FROM   mtl_categories_v mic
               WHERE  mic.CATEGORY_ID =  cia.item_category_id
               AND    mic.STRUCTURE_ID = 50328)
             WHEN    ATTRIBUTE_LEVEL = 'ITEM' THEN
               (SELECT msi.segment1
               FROM mtl_system_items_b msi
               WHERE msi.organization_id = 91
               AND  msi.inventory_item_id = cia.INVENTORY_ITEM_ID )
            END CATEGORY_item,
            cia.attribute_id,
            ATTRIBUTE_LEVEL
      FROM CSI_I_EXTENDED_ATTRIBS cia
    ) Mashu
    WHERE  ext.INSTANCE_ID = cii.instance_id(+)
    AND    ext.instance_id= p_instance_id
    AND   ext.ATTRIBUTE_VALue IS NOT NULL
    AND    mic_pr.INVENTORY_ITEM_ID = cii.inventory_item_id
    AND    mic_pr.ORGANIZATION_ID = 91
    AND    mic_pr.CATEGORY_SET_NAME = 'Main Category Set'
    AND   ext.ATTRIBUTE_ID = Mashu.attribute_id
    AND    Mashu.ATTRIBUTE_LEVEL != 'CATEGORY'
    AND   cii.instance_id IN  (SELECT  cii.instance_id
                               FROM csi_item_instances cii ,
                                    mtl_system_items_b msi
                               WHERE cii.serial_number IS NOT NULL
                               AND  CII.ACCOUNTING_CLASS_CODE = 'CUST_PROD'
                               AND  MSI.INVENTORY_ITEM_ID = CII.INVENTORY_ITEM_ID
                               AND  MSI.ORGANIZATION_ID = 91
                               AND  cii.instance_status_id NOT IN (5,\*510,*\1,10040) --(5)Terminated,(510)CREATED,(1)EXPIRED,(10040)/U/G - Not Active
                               AND  instr(cii.serial_number,'-L',1) = 0
                               AND xxinv_utils_pkg.is_fdm_item(cii.inventory_item_id) = 'N')
    AND  (EXT.ATTRIBUTE_CODE NOT IN ('OBJ_HASP_EXP','OBJ_HASP_SV')  AND EXT.ATTRIBUTE_VALUE != 'N/A');*/
  
    CURSOR cur_ib_attrib IS --(p_instance_id NUMBER) IS --new
      SELECT cii.instance_id
            ,ext.attribute_code
            ,ext.attribute_name
            ,ext.attribute_value
            ,ext.attribute_level /*,
                                                                                                                                                                        (SELECT new_att_id.ATTRIBUTE_ID
                                                                                                                                                                         FROM   CSI_I_EXTENDED_ATTRIBS new_att_id
                                                                                                                                                                         WHERE  new_att_id.ATTRIBUTE_CODE =  ext.ATTRIBUTE_CODE
                                                                                                                                                                         AND    new_att_id.item_category_id = mic_pr.CATEGORY_ID
                                                                                                                                                                         ) attribute_id*/
      FROM csi_inst_extend_attrib_v ext
          ,csi_item_instances cii
          ,mtl_item_categories_v mic_pr
          ,(SELECT CASE
                     WHEN attribute_level = 'GLOBAL' THEN
                      'All Assets'
                     WHEN attribute_level = 'CATEGORY' THEN
                      (SELECT mic.category_concat_segs
                       FROM mtl_categories_v mic
                       WHERE mic.category_id = cia.item_category_id
                       AND mic.structure_id = 50328)
                     WHEN attribute_level = 'ITEM' THEN
                      (SELECT msi.segment1
                       FROM mtl_system_items_b msi
                       WHERE msi.organization_id = 91
                       AND msi.inventory_item_id = cia.inventory_item_id)
                   END category_item
                  ,cia.attribute_id
                  ,attribute_level
            FROM csi_i_extended_attribs cia) mashu
      WHERE ext.instance_id = cii.instance_id(+)
      AND ext.attribute_value IS NOT NULL
      AND mic_pr.inventory_item_id = cii.inventory_item_id
      AND mic_pr.organization_id = 91
      AND mic_pr.category_set_name = 'Main Category Set'
      AND ext.attribute_id = mashu.attribute_id
      AND mashu.attribute_level = 'CATEGORY'
           --   AND cii.instance_id = p_instance_id --Commented on 10-NOV-2016
           --    Added on 10-NOV-2016
      AND EXISTS (SELECT instance_id
             FROM xxs3_cs_instance xci
             WHERE xci.instance_id = cii.instance_id
             AND xci.process_flag != 'R')
           --    Added on 10-NOV-2016
      AND EXISTS
       (SELECT cii.instance_id
             FROM csi_item_instances ci
                 ,mtl_system_items_b msi
             WHERE ci.serial_number IS NOT NULL
             AND ci.accounting_class_code = 'CUST_PROD'
             AND msi.inventory_item_id = ci.inventory_item_id
             AND msi.organization_id = 91
                  --  AND    ci.instance_status_id NOT IN (510, 1, 5, 10040) --(5)Terminated,(510)CREATED,(1)EXPIRED,(10040)/U/G - Not Active  -- Commented on 10-NOV-2016
             AND cii.instance_status_id NOT IN
                   (SELECT instance_status_id
                    FROM csi_instance_statuses
                    WHERE NAME IN
                          ('EXPIRED', 'Terminated', 'CREATED', 'U/G - Not Active'))
             AND instr(ci.serial_number, '-L', 1) = 0
             AND xxinv_utils_pkg.is_fdm_item(ci.inventory_item_id) = 'N'
             AND ci.instance_id = cii.instance_id)
      AND (ext.attribute_code NOT IN ('OBJ_HASP_EXP', 'OBJ_HASP_SV') AND
            ext.attribute_value != 'N/A')
      
      UNION
      SELECT cii.instance_id
            ,ext.attribute_code
            ,ext.attribute_name
            ,ext.attribute_value
            ,ext.attribute_level /*,
                                                                                                                                                                         (SELECT new_att_id.ATTRIBUTE_ID
                                                                                                                                                                          FROM   CSI_I_EXTENDED_ATTRIBS new_att_id
                                                                                                                                                                          WHERE  new_att_id.ATTRIBUTE_CODE =  ext.ATTRIBUTE_CODE
                                                                                                                                                                          AND    new_att_id.item_category_id = mic_pr.CATEGORY_ID
                                                                                                                                                                         ) new_attribute_id*/
      FROM csi_inst_extend_attrib_v ext
          ,csi_item_instances cii
          ,mtl_item_categories_v mic_pr
          ,(SELECT CASE
                     WHEN attribute_level = 'GLOBAL' THEN
                      'All Assets'
                     WHEN attribute_level = 'CATEGORY' THEN
                      (SELECT mic.category_concat_segs
                       FROM mtl_categories_v mic
                       WHERE mic.category_id = cia.item_category_id
                       AND mic.structure_id = 50328)
                     WHEN attribute_level = 'ITEM' THEN
                      (SELECT msi.segment1
                       FROM mtl_system_items_b msi
                       WHERE msi.organization_id = 91
                       AND msi.inventory_item_id = cia.inventory_item_id)
                   END category_item
                  ,cia.attribute_id
                  ,attribute_level
            FROM csi_i_extended_attribs cia) mashu
      WHERE ext.instance_id = cii.instance_id(+)
      AND ext.attribute_value IS NOT NULL
      AND mic_pr.inventory_item_id = cii.inventory_item_id
      AND mic_pr.organization_id = 91
      AND mic_pr.category_set_name = 'Main Category Set'
      AND ext.attribute_id = mashu.attribute_id
      AND mashu.attribute_level != 'CATEGORY'
           -- AND cii.instance_id = p_instance_id --Commented on 10-NOV-2016
           --    Added on 10-NOV-2016
      AND EXISTS (SELECT instance_id
             FROM xxs3_cs_instance xci
             WHERE xci.instance_id = cii.instance_id
             AND xci.process_flag != 'R')
           --    Added on 10-NOV-2016
      AND EXISTS
       (SELECT cii.instance_id
             FROM csi_item_instances ci
                 ,mtl_system_items_b msi
             WHERE ci.serial_number IS NOT NULL
             AND ci.accounting_class_code = 'CUST_PROD'
             AND msi.inventory_item_id = cii.inventory_item_id
             AND msi.organization_id = 91
                  --      AND    ci.instance_status_id NOT IN (510, 1, 5, 10040) --(5)Terminated,(510)CREATED,(1)EXPIRED,(10040)/U/G - Not Active
                  -- Commented on 10-NOV-2016
             AND cii.instance_status_id NOT IN
                   (SELECT instance_status_id
                    FROM csi_instance_statuses
                    WHERE NAME IN
                          ('EXPIRED', 'Terminated', 'CREATED', 'U/G - Not Active'))
             AND instr(ci.serial_number, '-L', 1) = 0
             AND xxinv_utils_pkg.is_fdm_item(ci.inventory_item_id) = 'N'
             AND ci.instance_id = cii.instance_id)
      AND (ext.attribute_code NOT IN ('OBJ_HASP_EXP', 'OBJ_HASP_SV') AND
            ext.attribute_value != 'N/A')
      
      UNION
      SELECT cii.instance_id
            ,
             /*    (SELECT new_att_id.ATTRIBUTE_ID
                                                                                                                                                                                                                                                                                                                                                                       FROM   CSI_I_EXTENDED_ATTRIBS new_att_id
                                                                                                                                                                                                                                                                                                                                                                       WHERE  new_att_id.ATTRIBUTE_CODE =  ext.ATTRIBUTE_CODE
                                                                                                                                                                                                                                                                                                                                                                       AND    new_att_id.item_category_id = mic_pr.CATEGORY_ID
                                                                                                                                                                                                                                                                                                                                                                      ) attribute_id,*/ext.attribute_code
            ,ext.attribute_name
            ,ext.attribute_value
            ,ext.attribute_level --,
      --atts.ATTRIBUTE_ID--,
      --       cii.attribute12 IB_SF_Id
      --       mic_pr.CATEGORY_CONCAT_SEGS Main_cat_printer,
      --       Mashu.CATEGORY_item Extended_category
      --,trunc(l.transaction_date + 8) "Actual Upgrade Date"
      FROM csi_inst_extend_attrib_v ext
          ,csi_item_instances cii
          ,mtl_item_categories_v mic_pr
          ,(SELECT CASE
                     WHEN attribute_level = 'GLOBAL' THEN
                      'All Assets'
                     WHEN attribute_level = 'CATEGORY' THEN
                      (SELECT mic.category_concat_segs
                       FROM mtl_categories_v mic
                       WHERE mic.category_id = cia.item_category_id
                       AND mic.structure_id = 50328)
                     WHEN attribute_level = 'ITEM' THEN
                      (SELECT msi.segment1
                       FROM mtl_system_items_b msi
                       WHERE msi.organization_id = 91
                       AND msi.inventory_item_id = cia.inventory_item_id)
                   END category_item
                  ,cia.attribute_id
                  ,attribute_level
            FROM csi_i_extended_attribs cia) mashu
          ,csi_i_extended_attribs atts
      WHERE ext.instance_id = cii.instance_id(+)
      AND ext.attribute_value IS NOT NULL
      AND mic_pr.inventory_item_id = cii.inventory_item_id
      AND mic_pr.organization_id = 91
      AND mic_pr.category_set_name = 'Main Category Set'
      AND ext.attribute_id = atts.attribute_id
      AND atts.attribute_code = ext.attribute_code
           --AND    atts.item_category_id = mic_pr.CATEGORY_ID
           --AND   Mashu.CATEGORY_item != mic_pr.CATEGORY_CONCAT_SEGS  
      AND ext.attribute_id = mashu.attribute_id
           
      AND mashu.attribute_level = 'CATEGORY'
           --AND cii.instance_id = p_instance_id --Commented on 10-NOV-2016
           --    Added on 10-NOV-2016
      AND EXISTS (SELECT instance_id
             FROM xxs3_cs_instance xci
             WHERE xci.instance_id = cii.instance_id
             AND xci.process_flag != 'R')
           --    Added on 10-NOV-2016
           --AND   ext.INSTANCE_ID = 2877005
           --AND   ext.ATTRIBUTE_NAME = 'FCO00006'
      AND EXISTS (SELECT cii.instance_id
             FROM csi_item_instances ci
                 ,mtl_system_items_b msi
             WHERE ci.serial_number IS NOT NULL
             AND ci.accounting_class_code = 'CUST_PROD'
             AND msi.inventory_item_id = cii.inventory_item_id
             AND msi.organization_id = 91
                  --        AND    ci.instance_status_id NOT IN (510, 1, 5, 10040) --(5)Terminated,(510)CREATED,(1)EXPIRED,(10040)/U/G - Not Active-- Commented on 10-NOV-2016
             AND cii.instance_status_id NOT IN
                   (SELECT instance_status_id
                    FROM csi_instance_statuses
                    WHERE NAME IN ('EXPIRED', 'Terminated', 'CREATED',
                           'U/G - Not Active'))
             AND instr(ci.serial_number, '-L', 1) = 0
             AND xxinv_utils_pkg.is_fdm_item(ci.inventory_item_id) = 'N'
             AND ci.instance_id = cii.instance_id)
      AND (ext.attribute_code IN ('OBJ_HASP_EXP', 'OBJ_HASP_SV') OR
            ext.attribute_value = 'N/A')
      
      UNION
      SELECT cii.instance_id
            ,ext.attribute_code
            ,ext.attribute_name
            ,ext.attribute_value
            ,ext.attribute_level --,
      --atts.Attribute_Id--,
      --       cii.attribute12
      --       mic_pr.CATEGORY_CONCAT_SEGS Main_cat_printer,
      --       Mashu.CATEGORY_item Asset_category
      --,trunc(l.transaction_date + 8) "Actual Upgrade Date"
      FROM csi_inst_extend_attrib_v ext
          ,csi_item_instances cii
          ,mtl_item_categories_v mic_pr
          ,(SELECT CASE
                     WHEN attribute_level = 'GLOBAL' THEN
                      'All Assets'
                     WHEN attribute_level = 'CATEGORY' THEN
                      (SELECT mic.category_concat_segs
                       FROM mtl_categories_v mic
                       WHERE mic.category_id = cia.item_category_id
                       AND mic.structure_id = 50328)
                     WHEN attribute_level = 'ITEM' THEN
                      (SELECT msi.segment1
                       FROM mtl_system_items_b msi
                       WHERE msi.organization_id = 91
                       AND msi.inventory_item_id = cia.inventory_item_id)
                   END category_item
                  ,cia.attribute_id
                  ,attribute_level
            FROM csi_i_extended_attribs cia) mashu
          ,csi_i_extended_attribs atts
      WHERE ext.instance_id = cii.instance_id(+)
      AND ext.attribute_value IS NOT NULL
      AND mic_pr.inventory_item_id = cii.inventory_item_id
      AND mic_pr.organization_id = 91
      AND mic_pr.category_set_name = 'Main Category Set'
      AND ext.attribute_id = atts.attribute_id
      AND atts.attribute_code = ext.attribute_code
           --AND    atts.item_category_id = mic_pr.CATEGORY_ID
           --AND   Mashu.CATEGORY_item != mic_pr.CATEGORY_CONCAT_SEGS  
      AND ext.attribute_id = mashu.attribute_id
      AND mashu.attribute_level != 'CATEGORY'
           --   AND cii.instance_id = p_instance_id  --Commented on 10-NOV-2016
           --    Added on 10-NOV-2016
      AND EXISTS (SELECT instance_id
             FROM xxs3_cs_instance xci
             WHERE xci.instance_id = cii.instance_id
             AND xci.process_flag != 'R')
           --    Added on 10-NOV-2016
           --AND   ext.INSTANCE_ID = 2877005
           --AND   ext.ATTRIBUTE_NAME = 'FCO00006'
      AND EXISTS (SELECT ci.instance_id
             FROM csi_item_instances ci
                 ,mtl_system_items_b msi
             WHERE ci.serial_number IS NOT NULL
             AND ci.accounting_class_code = 'CUST_PROD'
             AND msi.inventory_item_id = ci.inventory_item_id
             AND msi.organization_id = 91
                  --      AND    ci.instance_status_id NOT IN (510, 1, 5, 10040) --(5)Terminated,(510)CREATED,(1)EXPIRED,(10040)/U/G - Not Active-- Commented on 10-NOV-2016
             AND cii.instance_status_id NOT IN
                   (SELECT instance_status_id
                    FROM csi_instance_statuses
                    WHERE NAME IN ('EXPIRED', 'Terminated', 'CREATED',
                           'U/G - Not Active'))
             AND instr(ci.serial_number, '-L', 1) = 0
             AND xxinv_utils_pkg.is_fdm_item(ci.inventory_item_id) = 'N'
             AND ci.instance_id = cii.instance_id)
      AND (ext.attribute_code IN ('OBJ_HASP_EXP', 'OBJ_HASP_SV') OR
            ext.attribute_value = 'N/A');
    /*CURSOR cur_IB_relation(p_instance_id NUMBER) IS
    SELECT relationship_id,
           relationship_type_code,
           object_id ,
           subject_id
        FROM  csi_ii_relationships cir
       WHERE NVL(CIR.ACTIVE_END_DATE,SYSDATE) > SYSDATE - 1
       AND object_id = p_instance_id;*/
  
    CURSOR cur_ib_relation IS --(p_instance_id NUMBER) IS --new
      SELECT cir.object_id
            ,cir.subject_id
            ,relationship_id
            ,relationship_type_code
      FROM csi_ii_relationships cir
      WHERE nvl(cir.active_end_date, SYSDATE) > SYSDATE - 1
           -- AND cir.object_id = p_instance_id
           --Commented on 10-NOV-2016
           --    Added on 10-NOV-2016
      AND EXISTS (SELECT instance_id
             FROM xxs3_cs_instance xci
             WHERE xci.instance_id = cir.object_id
             AND xci.process_flag != 'R');
    --    Added on 10-NOV-2016;
  
    CURSOR cur_party_name IS
      SELECT party_name
            ,xx_instance_id
      FROM xxs3_cs_instance
      WHERE regexp_like(party_name, 'Inc\.|INC|Corp\.|CORP|LLC\.|LLC|Ltd\.|LTD\.|LTD|P\.O\.|A\.P\.|A/P|A\.R\.|A/R|CO\.|Co\.', 'c');
  
    TYPE t_instance IS TABLE OF cur_ib_extract%ROWTYPE INDEX BY PLS_INTEGER;
    l_instance t_instance;
  
    TYPE t_party_name IS TABLE OF cur_party_name%ROWTYPE INDEX BY PLS_INTEGER;
    l_party_name t_party_name;
  
  
    --Added on 10-NOV-2016
    TYPE t_attribute IS TABLE OF cur_ib_attrib%ROWTYPE INDEX BY PLS_INTEGER;
    l_attribute t_attribute;
  
  
    TYPE t_relation IS TABLE OF cur_ib_relation%ROWTYPE INDEX BY PLS_INTEGER;
    l_relation t_relation;
    --Added on 10-NOV-2016
  
  
  BEGIN
  
    x_retcode := 0;
    x_errbuf  := 'COMPLETE';
  
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_cs_instance';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_cs_instance_dq';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_cs_instance_attrib';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE xxobjt.xxs3_cs_instance_relation';
  
  
    BEGIN
    
      OPEN cur_ib_extract;
      LOOP
        FETCH cur_ib_extract BULK COLLECT
          INTO l_instance LIMIT 600;
      
        EXIT WHEN l_instance.COUNT = 0;
        --bulk insert ioperation
        --IF p_only_dq = 'N' THEN
      
        --FOR i IN cur_ib_extract LOOP
        --WHERE  process_flag = 'P';
      
        --FOR i IN 1 .. l_instance.COUNT LOOP
      
        FORALL i IN 1 .. l_instance.COUNT
        
          INSERT INTO xxs3_cs_instance
          VALUES
            (xxobjt. xxs3_cs_instance_seq.NEXTVAL
            ,SYSDATE
            ,'N'
            ,NULL
            ,NULL
            ,l_instance(i).instance_id
            ,l_instance(i).organization_name
            ,'T01'
            ,l_instance(i).item_number
            ,l_instance(i).status
            ,l_instance(i).unit_of_measure
            ,l_instance(i).quantity
            ,l_instance(i).serial_number
            ,l_instance(i).inventory_revision
            ,l_instance(i).account_number
            ,l_instance(i).party_name
            ,NULL
            ,l_instance(i).party_number
            ,l_instance(i).party_type
            ,l_instance(i).install_date
            ,l_instance(i).shipped_date
            ,l_instance(i).creation_date
            ,l_instance(i).bill_to_party_number
            ,l_instance(i).bill_to_site_number
            ,l_instance(i).ship_to_party_number
            ,l_instance(i).ship_to_site_number
            ,l_instance(i).cur_loc_party_number
            ,l_instance(i).cur_loc_party_site_number
            ,l_instance(i).install_location_party_number
            ,l_instance(i).inst_loc_party_site_number
            ,l_instance(i).accounting_class_code
            ,'Printer Counter - Template'
            ,l_instance(i).tpt_value
            ,l_instance(i).tpt_date
            ,l_instance(i).last_order_number
            ,l_instance(i).order_line_number
            ,l_instance(i).ib_creation_flag
            ,l_instance(i).coi
            ,l_instance(i).coi_date
            ,l_instance(i).initial_ship_date
            ,l_instance(i).embedded_sw_version
            ,l_instance(i).objet_studio_sw_version
            ,
             --i.attribute10,
             l_instance(i).cs_region
            ,
             --i.attribute11,
             l_instance(i).sf_asset_id
            ,l_instance(i).transfer_to_sfdc
            ,l_instance(i).legacy_instance_id
            ,NULL
            ,NULL
            ,NULL
            ,NULL);
      
        /*INSERT INTO xxs3_cs_instance
        VALUES (
          xxobjt. xxs3_cs_instance_seq.nextval,
           SYSDATE,
           'N',
           NULL,
           NULL,
           i.instance_id,
           i.ORGANIZATION_NAME,
           'T01',
           i.ITEM_NUMBER,
           i.status,
           i.UNIT_OF_MEASURE,
           i.quantity,
           i.serial_number,
           i.INVENTORY_REVISION,
           i.ACCOUNT_NUMBER,
           i.PARTY_NAME,
           NULL,
           i.PARTY_NUMBER,
           i.PARTY_TYPE,
           i.install_date,
           i.shipped_date,
           i.creation_date,
           i.BILL_TO_PARTY_NUMBER,
           i.BILL_TO_SITE_NUMBER,
           i.SHIP_TO_PARTY_NUMBER,
           i.SHIP_TO_SITE_NUMBER,
           i.CUR_LOC_PARTY_NUMBER,
           i.CUR_LOC_PARTY_SITE_NUMBER,
           i.INSTALL_LOCATION_PARTY_NUMBER,
           i.INST_LOC_PARTY_SITE_NUMBER,
           i.ACCOUNTING_CLASS_CODE,           
           'Printer Counter - Template',
           i.tpt_value,
           i.tpt_date,
           i.LAST_ORDER_NUMBER,
           i.ORDER_LINE_NUMBER,           
           i.IB_CREATION_FLAG,
           i.COI,
           i.COI_DATE,
           i.INITIAL_SHIP_DATE,
           i.EMBEDDED_SW_VERSION,
           i.OBJET_STUDIO_SW_VERSION,
           --i.attribute10,
           i.CS_REGION,
           --i.attribute11,
           i.SF_ASSET_ID,
           i.TRANSFER_TO_SFDC,
           i.LEGACY_INSTANCE_ID,
           NULL,
           NULL,
           NULL,
           NULL);*/
      
        --END LOOP;
        -- EXIT WHEN cur_ib_extract%NOTFOUND;
        COMMIT;
      END LOOP;
      CLOSE cur_ib_extract;
    
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE = -24381
        THEN
          FOR indx IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
          LOOP
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
  
    --COMMIT;
  
    /* FOR i IN (SELECT instance_id FROM xxs3_cs_instance)
    LOOP
    
      FOR j IN cur_ib_attrib(i.instance_id)
      LOOP
        INSERT INTO xxs3_cs_instance_attrib
          (xx_instance_attrib_id
          ,date_extracted_on
          ,process_flag
          ,s3_instance_id
          ,notes
          ,
           --attribute_id,
           attribute_level
          ,attribute_code
          ,attribute_name
          ,attribute_value
          ,legacy_instance_id)
        VALUES
          (xxs3_cs_instance_attrib_seq.NEXTVAL
          ,SYSDATE
          ,'N'
          ,NULL
          ,NULL
          ,
           --j.attribute_id,
           j.attribute_level
          ,j.attribute_code
          ,j.attribute_name
          ,j.attribute_value
          ,j.instance_id);
      END LOOP;
    END LOOP;*/
  
    ----- Added on 10-NOV-2016 ----  
    BEGIN
    
      OPEN cur_ib_attrib;
      LOOP
        FETCH cur_ib_attrib BULK COLLECT
          INTO l_attribute LIMIT 600;
      
        EXIT WHEN l_attribute.COUNT = 0;
      
        FORALL i IN 1 .. l_attribute.COUNT
        
          INSERT INTO xxs3_cs_instance_attrib
          VALUES
            (xxobjt. xxs3_cs_instance_attrib_seq.NEXTVAL
            ,SYSDATE
            ,'N'
            ,NULL
            ,NULL
            ,l_attribute(i).attribute_level
            ,l_attribute(i).attribute_code
            ,l_attribute(i).attribute_name
            ,l_attribute(i).attribute_value
            ,l_attribute(i).instance_id);
      
        COMMIT;
      END LOOP;
      CLOSE cur_ib_attrib;
    
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE = -24381
        THEN
          FOR indx IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
          LOOP
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
  
  
    ----- Added on 10-NOV-2016 ----     
  
  
    /*  COMMIT;
    
    FOR i IN (SELECT instance_id FROM xxs3_cs_instance)
    LOOP
      FOR k IN cur_ib_relation(i.instance_id)
      LOOP
        INSERT INTO xxs3_cs_instance_relation
          (xx_instance_relation_id
          ,date_extracted_on
          ,process_flag
          ,s3_instance_id
          ,notes
          ,relationship_id
          ,relationship_type_code
          ,object_id
          ,subject_id
          ,legacy_instance_id)
        VALUES
          (xxs3_cs_instance_attrib_seq.NEXTVAL
          ,SYSDATE
          ,'N'
          ,NULL
          ,NULL
          ,k.relationship_id
          ,k.relationship_type_code
          ,k.object_id
          ,k.subject_id
          ,k.object_id);
      END LOOP;
    END LOOP;
    COMMIT;  */
    --END IF;
  
  
  
    ----- Added on 10-NOV-2016 ----
    BEGIN
    
      OPEN cur_ib_relation;
      LOOP
        FETCH cur_ib_relation BULK COLLECT
          INTO l_relation LIMIT 600;
      
        EXIT WHEN l_relation.COUNT = 0;
      
        FORALL i IN 1 .. l_relation.COUNT
        
          INSERT INTO xxs3_cs_instance_relation
          VALUES
            (xxobjt. xxs3_cs_instance_attrib_seq.NEXTVAL
            ,SYSDATE
            ,'N'
            ,NULL
            ,NULL
            ,l_relation(i).relationship_id
            ,l_relation(i).relationship_type_code
            ,l_relation(i).object_id
            ,l_relation(i).subject_id
            ,l_relation(i).object_id);
      
        COMMIT;
      END LOOP;
      CLOSE cur_ib_relation;
    
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE = -24381
        THEN
          FOR indx IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
          LOOP
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
  
    ----- Added on 10-NOV-2016 ----  
  
  
  
    fnd_file.put_line(fnd_file.log, 'Loading complete');
  
    --autocleanse
    --FOR i IN cur_party_name LOOP
    BEGIN
    
      OPEN cur_party_name;
      LOOP
        FETCH cur_party_name BULK COLLECT
          INTO l_party_name;
      
        EXIT WHEN l_party_name.COUNT = 0;
      
        FOR i IN 1 .. l_party_name.COUNT
        LOOP
          update_party_name(l_party_name(i).xx_instance_id, l_party_name(i)
                            .party_name);
          --END LOOP;
        END LOOP;
      END LOOP;
    
      CLOSE cur_party_name;
    
      COMMIT;
    
      /*FOR j IN (SELECT *
                FROM   xxs3_cs_instance
                WHERE  s3_party_name IS NULL) LOOP
      
        UPDATE xxs3_cs_instance
        SET    s3_party_name = j.party_name
        WHERE  xx_instance_id = j.xx_instance_id;
      END LOOP;*/
    
      COMMIT;
    
      quality_check_cs;
      fnd_file.put_line(fnd_file.log, 'DQ complete');
    
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE = -24381
        THEN
          FOR indx IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
          LOOP
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
  
    /*fnd_file.put_line(fnd_file.output, 'Concurrent Request processed successfully');
    fnd_file.put_line(fnd_file.output, '--------------------------------------'); */
  END ib_extract_data;


  -- --------------------------------------------------------------------------------------------
  -- Purpose: This procedure is used to insert data from EQT staging to S3 Staging table 
  -- using dblink
  -- --------------------------------------------------------------------------------------------
  -- Ver   Date        Name                          Description
  --  1.0  11/11/2016  Sumana Naha                  Initial build
  -----------------------------------------------------------------------------------------------


  /*PROCEDURE insert_staging_s3(x_errbuf  OUT VARCHAR2
                             ,x_retcode OUT NUMBER) IS
  
  
    l_step VARCHAR2(200);
  
  
  BEGIN
  
  
    -------------------------   INSTALL BASE INSTANCE ---------------------------
  
  
  
    fnd_file.put_line(fnd_file.log, 'Truncating S3 staging table for Install Base extract...');
    EXECUTE IMMEDIATE 'TRUNCATE TABLE XXX_CSI_INST_INTFS_STG_TAB@eqt_to_trngs3';
  
  
    fnd_file.put_line(fnd_file.log, 'Inserting into S3 staging table for Install Base extract...');
    l_step := 'Inserting into S3 staging table for Install Base extract...';
  
    INSERT INTO xxx_csi_inst_intfs_stg_tab@eqt_to_trngs3
      (organization_name
      ,item_number
      ,unit_of_measure
      ,uom_code
      ,quantity
      ,serial_number
      ,inventory_revision
      ,customer_name
      ,customer_account_number
      ,cust_account_id
      ,install_date
      ,shipped_on_date
      ,instance_status
      ,bill_to_party_number
      ,bill_to_party_id
      ,bill_to_site_number
      ,bill_to_site_id
      ,ship_to_party_number
      ,ship_to_party_id
      ,ship_to_site_number
      ,ship_to_site_id
      ,curr_loc_party_number
      ,curr_loc_party_id
      ,curr_loc_site_number
      ,curr_loc_site_id
      ,install_loc_party_number
      ,install_loc_party_id
      ,install_loc_site_number
      ,install_loc_site_id
      ,counter_temp_name
      ,counter_date
      ,counter_value
      ,attribute_category
      ,attribute1
      ,attribute2
      ,attribute3
      ,attribute4
      ,attribute5
      ,attribute6
      ,attribute7
      ,attribute8
      ,attribute9
      ,attribute10
      ,attribute11
      ,attribute12
      ,attribute13
      ,attribute14
      ,attribute15
      ,attribute16
      ,created_by
      ,creation_date
      ,last_updated_by
      ,last_update_date
      ,last_update_login
      ,status
      ,err_code
      ,error_message
      ,batch_id
      ,process_flag
      ,set_process_id)
      SELECT instance_id
            ,s3_organization_name
            ,item_number
            ,unit_of_measure
            ,NULL
            ,quantity
            ,serial_number
            ,item_revision
            ,s3_party_name
            ,account_number
            ,NULL
            ,install_date
            ,shipped_date
            ,status
            ,bill_to_party_number
            ,NULL
            ,bill_to_site_number
            ,NULL
            ,ship_to_party_number
            ,NULL
            ,ship_to_site_number
            ,NULL
            ,cur_loc_party_number
            ,NULL
            ,cur_loc_party_site_number
            ,NULL
            ,install_location_party_number
            ,NULL
            ,inst_loc_party_site_number
            ,NULL
            ,counter_template_name
            ,counter_date
            ,counter_value
            ,NULL
            ,ib_creation_flag
            ,NULL
            ,coi
            ,embedded_sw_version
            ,objet_studio_sw_version
            ,initial_ship_date
            ,coi_date
            ,cs_region
            ,instance_id
            ,NULL
            ,NULL
            ,sf_asset_id
            ,NULL
            ,NULL
            ,NULL
            ,transfer_to_sfdc
            ,21431
            ,SYSDATE
            ,21431
            ,SYSDATE
            ,21431
            ,NULL
            ,NULL
            ,NULL
            ,NULL
            ,'N'
            ,NULL
      FROM xxs3_cs_instance
      WHERE process_flag != 'R';
  
  
  
  
  
    -------------------------   INSTALL BASE ATTRIBUTE ---------------------------
  
  
  
    fnd_file.put_line(fnd_file.log, 'Truncating S3 staging table for Install Base Attribute extract...');
    EXECUTE IMMEDIATE 'TRUNCATE TABLE XXX_CSI_IEA_VAL_INTFS_STG_TAB@eqt_to_trngs3';
  
  
    fnd_file.put_line(fnd_file.log, 'Inserting into S3 staging table for Install Base Attribute extract...');
    l_step := 'Inserting into S3 staging table for Install Base Attribute extract...';
  
    INSERT INTO xxx_csi_iea_val_intfs_stg_tab@eqt_to_trngs3
      (old_instance_id
      ,attribute_id
      ,attribute_code
      ,attribute_name
      ,attribute_level
      ,attribute_value
      ,active_start_date
      ,active_end_date
      ,created_by
      ,creation_date
      ,last_updated_by
      ,last_update_date
      ,last_update_login
      ,status
      ,err_code
      ,error_message
      ,batch_id
      ,process_flag
      ,set_process_id)
      SELECT legacy_instance_id
            ,NULL
            ,attribute_code
            ,attribute_name
            ,attribute_level
            ,attribute_value
            ,NULL
            ,NULL
            ,21431
            ,SYSDATE
            ,21431
            ,SYSDATE
            ,21431
            ,NULL
            ,NULL
            ,NULL
            ,NULL
            ,'N'
            ,NULL
      FROM xxs3_cs_instance_attrib
      WHERE process_flag != 'R';
  
  
  
  
  
  
    -------------------------   INSTALL BASE RELATION ---------------------------
  
  
    fnd_file.put_line(fnd_file.log, 'Truncating S3 staging table for Install Base Relation extract...');
    EXECUTE IMMEDIATE 'TRUNCATE TABLE XX_CSI_II_REL_INTFS_STG_TAB@eqt_to_trngs3';
  
  
    fnd_file.put_line(fnd_file.log, 'Inserting into S3 staging table for Install Base Relation extract...');
    l_step := 'Inserting into S3 staging table for Install Base Relation extract...';
  
    INSERT INTO xx_csi_ii_rel_intfs_stg_tab@eqt_to_trngs3
      (old_object_id
      ,old_subject_id
      ,relationship_type_code
      ,relationship_start_date
      ,relationship_end_date
      ,position_reference
      ,display_order
      ,mandatory_flag
      ,CONTEXT
      ,attribute1
      ,attribute2
      ,attribute3
      ,attribute4
      ,attribute5
      ,attribute6
      ,attribute7
      ,attribute8
      ,attribute9
      ,attribute10
      ,attribute11
      ,attribute12
      ,attribute13
      ,attribute14
      ,attribute15
      ,created_by
      ,creation_date
      ,last_updated_by
      ,last_update_date
      ,last_update_login
      ,status
      ,err_code
      ,error_message
      ,batch_id
      ,process_flag
      ,set_process_id)
      SELECT object_id
            ,subject_id
            ,relationship_type_code
            ,NULL
            ,NULL
            ,NULL
            ,NULL
            ,NULL
            ,NULL
            ,NULL
            ,NULL
            ,NULL
            ,NULL
            ,NULL
            ,NULL
            ,NULL
            ,NULL
            ,NULL
            ,NULL
            ,NULL
            ,NULL
            ,NULL
            ,NULL
            ,NULL
            ,21431
            ,SYSDATE
            ,21431
            ,SYSDATE
            ,21431
            ,NULL
            ,NULL
            ,NULL
            ,NULL
            ,'N'
            ,NULL
      FROM xxs3_cs_instance_relation
      WHERE process_flag != 'R';
  
  
  EXCEPTION
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log, 'Exception while inserting data into S3 staging table :' ||
                         ' - ' || l_step || ' - ' || SQLERRM);
    
  END insert_staging_s3;*/


END xxs3_cs_ib_pkg;
/
