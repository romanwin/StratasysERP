CREATE OR REPLACE PACKAGE BODY xxar_mass_postal_code_update IS
  --------------------------------------------------------------------
  --  customization code: CHG0033182 – Mass Upload Customer Postal codes
  --  name:               XXAR_MASS_POSTAL_CODE_UPDATE
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  creation date:      18/01/2015
  --  Description:        Mass upload of postal_code to hz_locations
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   18/01/2015    Michal Tzvik    initial build
  --------------------------------------------------------------------

  report_error EXCEPTION;
  g_request_id CONSTANT NUMBER := fnd_global.conc_request_id;

  --------------------------------------------------------------------
  --  name:               report_data
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  customization code: CHG0033182 – Mass Upload Customer Postal codes
  --  creation date:      18/01/2015
  --  Description:        Create Excel report.
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   18/01/2015    Michal tzvik    initial build
  --------------------------------------------------------------------
  PROCEDURE report_data IS
    CURSOR c_int IS
      SELECT xli.batch_id,
             cur.account_number customer_number,
             cur.party_name customer_name,
             cur.party_site_number,
             nvl(cur.location_id, xli.location_id) location_id,
             cur.postal_code current_postal_code,
             xli.postal_code new_postal_code,
             xli.interface_status,
             xli.log_message
      FROM   (SELECT hp.party_name,
                     hca.account_number account_number,
                     hca.cust_account_id,
                     hps.party_site_number,
                     hl.location_id,
                     hl.postal_code
              FROM   hz_parties       hp,
                     hz_cust_accounts hca,
                     hz_party_sites   hps,
                     hz_locations     hl
              WHERE  hp.party_id = hca.party_id
              AND    hps.party_id = hp.party_id
              AND    hps.location_id = hl.location_id) cur,
             xxhz_locations_interface xli
      WHERE  cur.location_id(+) = xli.location_id
      AND    xli.batch_id = g_request_id;
  
    l_return_status          VARCHAR2(1);
    l_msg                    VARCHAR2(500);
    l_xxssys_generic_rpt_rec xxssys_generic_rpt%ROWTYPE;
  
  BEGIN
    -- Insert header row for reporting 
    l_xxssys_generic_rpt_rec.request_id      := g_request_id;
    l_xxssys_generic_rpt_rec.header_row_flag := 'Y';
    l_xxssys_generic_rpt_rec.col1            := 'Customer Number';
    l_xxssys_generic_rpt_rec.col2            := 'Customer Name';
    l_xxssys_generic_rpt_rec.col3            := 'Site Number';
    l_xxssys_generic_rpt_rec.col4            := 'Location Id';
    l_xxssys_generic_rpt_rec.col5            := 'Current Postal Code';
    l_xxssys_generic_rpt_rec.col6            := 'New POstal Code';
    l_xxssys_generic_rpt_rec.col7            := 'Status';
  
    xxssys_generic_rpt_pkg.ins_xxssys_generic_rpt(p_xxssys_generic_rpt_rec => l_xxssys_generic_rpt_rec,
                                                  
                                                  x_return_status => l_return_status,
                                                  
                                                  x_return_message => l_msg);
  
    IF l_return_status <> 'S' THEN
      RAISE report_error;
    END IF;
  
    FOR r_int_line IN c_int LOOP
      -- Insert details for reporting 
      l_xxssys_generic_rpt_rec.request_id      := g_request_id;
      l_xxssys_generic_rpt_rec.header_row_flag := 'N';
      l_xxssys_generic_rpt_rec.col1            := r_int_line.customer_number;
      l_xxssys_generic_rpt_rec.col2            := r_int_line.customer_name;
      l_xxssys_generic_rpt_rec.col3            := r_int_line.party_site_number;
      l_xxssys_generic_rpt_rec.col4            := r_int_line.location_id;
      l_xxssys_generic_rpt_rec.col5            := r_int_line.current_postal_code;
      l_xxssys_generic_rpt_rec.col6            := r_int_line.new_postal_code;
      l_xxssys_generic_rpt_rec.col7            := r_int_line.interface_status;
      l_xxssys_generic_rpt_rec.col_msg         := r_int_line.log_message;
    
      xxssys_generic_rpt_pkg.ins_xxssys_generic_rpt(p_xxssys_generic_rpt_rec => l_xxssys_generic_rpt_rec,
                                                    
                                                    x_return_status => l_return_status,
                                                    
                                                    x_return_message => l_msg);
    
      IF l_return_status <> 'S' THEN
        RAISE report_error;
      END IF;
    END LOOP;
  
    -- Submit request to launch generic reporting.
    xxssys_generic_rpt_pkg.submit_request(p_burst_flag => 'N',
                                          
                                          p_request_id => g_request_id, -- This would normally be launched from a program with a request_id                                  
                                          p_l_report_title => '''Postal Code Mass Upload Report for ''' ||
                                                               '||SYSDATE', -- We want report title to request_id   
                                          p_l_report_pre_text1 => '', -- If all my pre-text did not fit in p_pre_text1, I can continue in p_pre_text2 parameter
                                          p_l_report_pre_text2 => '', -- Continued pre_text - when appended together will read 'Test pre text1 Test pre text2'
                                          p_l_report_post_text1 => '', -- There is a post text2 parameter, which I'm not using, so need to close my quote 
                                          --p_l_report_post_text2       => ' Test post text2''', 
                                          p_l_email_subject => '',
                                          -- Subject of bursted email.  In this case, I'm using full_name (col1) in the subject
                                          p_l_email_body1 => '', -- Email body 1 (can continue to p_email_body2 if needed   
                                          --p_l_email_body2             => ' Test email body2''',
                                          p_l_order_by => 'TO_NUMBER(col4)', -- Order column by col5 (employee_number in our case)
                                          p_l_file_name => '''POSTAL_CODE_UPLOAD''',
                                          
                                          p_l_key_column => 'col_5',
                                          
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

  --------------------------------------------------------------------
  --  name:               main
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  customization code: CHG0033182 – Mass Upload Customer Postal codes
  --  creation date:      18/01/2015
  --  Description:        Main procedure, called by concurrent executable XXAR_MASS_POSTAL_CODE_UPDATE.
  --                      1. Upload data from csv file to XXHZ_LOCATIONS_INTERFACE table.
  --                      2. Process data to Oracle.
  --                      3. Create output- Excel report
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   18/01/2015    Michal Tzvik    initial build
  --------------------------------------------------------------------
  PROCEDURE main(errbuf          OUT VARCHAR2,
                 retcode         OUT VARCHAR2,
                 p_table_name    IN VARCHAR2, -- hidden parameter. default value ='XXHZ_LOCATIONS_INTERFACE' independent value set XXOBJT_LOADER_TABLES
                 p_template_name IN VARCHAR2, -- hidden parameter. default value ='POSTAL_CODE'
                 p_file_name     IN VARCHAR2,
                 p_directory     IN VARCHAR2) IS
  
    l_errbuf        VARCHAR2(2000);
    l_retcode       VARCHAR2(1);
    l_error_message VARCHAR2(2000);
  
    stop_processing EXCEPTION;
  BEGIN
    retcode := '0';
  
    -- 1. upload data from csv to interface table (XXOE_DISCOUNT_BUCKET_INTERFACE)
    fnd_file.put_line(fnd_file.log, 'Upload data from csv...');
    xxobjt_table_loader_util_pkg.load_file(errbuf => l_errbuf,
                                           
                                           retcode => l_retcode,
                                           
                                           p_table_name => p_table_name,
                                           
                                           p_template_name => p_template_name,
                                           
                                           p_file_name => p_file_name,
                                           
                                           p_directory => p_directory,
                                           
                                           p_expected_num_of_rows => NULL);
  
    IF l_retcode <> '0' THEN
      l_error_message := l_errbuf;
      RAISE stop_processing;
    END IF;
  
    -- 2. Convert data and upload to target tables
    xxhz_interfaces_pkg.main_process_locations(errbuf => l_error_message,
                                               
                                               retcode => l_retcode,
                                               
                                               p_source => g_request_id);
    IF l_retcode <> '0' THEN
      RAISE stop_processing;
    END IF;
  
    -- 3. Create output
    report_data;
  EXCEPTION
    WHEN report_error THEN
      fnd_file.put_line(fnd_file.log, 'Failed to generate report');
      retcode := 1;
      errbuf  := 'Unexpected error: report error';
    
    WHEN stop_processing THEN
      fnd_file.put_line(fnd_file.log, l_error_message);
      retcode := 1;
      errbuf  := 'Unexpected error';
    
      -- 3. Create output
      report_data;
    WHEN OTHERS THEN
      retcode := 1;
      errbuf  := 'Unexpected error: ' || SQLERRM;
    
      -- 3. Create output
      report_data;
  END main;

END xxar_mass_postal_code_update;
/
