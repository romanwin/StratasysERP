CREATE OR REPLACE PACKAGE xxhz_customer_credit_int_pkg IS
  --------------------------------------------------------------------
  --  customization code: CHG0034610
  --  name:               XXHZ_CUSTOMER_CREDIT_INT_PKG
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  creation date:      19/04/2015
  --  Description:        Upload Customer credit data from Atradius
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   19/04/2015    Michal Tzvik    initial build
  --------------------------------------------------------------------
  PROCEDURE handle_data(errbuf                   OUT VARCHAR2,
		retcode                  OUT VARCHAR2,
		p_partial_customer_match VARCHAR2);

  FUNCTION convert_name(p_party_name VARCHAR2) RETURN VARCHAR2;
  --------------------------------------------------------------------
  --  name:               main
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  customization code: CHG0034610 - Upload Customer credit data from Atradius
  --  creation date:      19/04/2015
  --  Description:        Main procedure, called by concurrent executable .
  --                      1. Upload data from csv file to xxhz_account_interface table.
  --                      2. Handle data in interface table
  --                      3. Process data to Oracle.
  --                      4. Create output- Excel report
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   19/04/2015    Michal Tzvik    initial build
  --------------------------------------------------------------------
  PROCEDURE main(errbuf                   OUT VARCHAR2,
	     retcode                  OUT VARCHAR2,
	     p_table_name             IN VARCHAR2, -- hidden parameter. default value ='XXHZ_ACCOUNT_INTERFACE' independent value set XXOBJT_LOADER_TABLES
	     p_template_name          IN VARCHAR2, -- hidden parameter. default value ='ATRADIUS'
	     p_file_name              IN VARCHAR2,
	     p_directory              IN VARCHAR2,
	     p_partial_customer_match IN VARCHAR2,
	     p_email_address          IN VARCHAR2,
	     p_arc_directory          IN VARCHAR2);

END xxhz_customer_credit_int_pkg;
/
CREATE OR REPLACE PACKAGE BODY xxhz_customer_credit_int_pkg IS
  --------------------------------------------------------------------
  --  customization code: CHG0034610
  --  name:               XXHZ_CUSTOMER_CREDIT_INT_PKG
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  creation date:      19/04/2015
  --  Description:        Upload Customer credit data from Atradius
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   19/04/2015    Michal Tzvik    initial build
  --  1.1  22.2.16        yuval tal       CHG0037612- Adjust the program to delete CI information and replace 0 amounts with NULL values
  --                                      modify procedure : handle_data,main
  -------------------------------------------------------------------

  report_error EXCEPTION;
  g_request_id CONSTANT NUMBER := fnd_global.conc_request_id;

  c_sts_error CONSTANT VARCHAR2(20) := 'ERROR';
  c_sts_new   CONSTANT VARCHAR2(20) := 'NEW';
  c_sts_info  CONSTANT VARCHAR2(20) := 'INFO';

  --------------------------------------------------------------------
  --  name:               report_data
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  customization code: CHG0034610 - Upload Customer credit data from Atradius
  --  creation date:      20/04/2015
  --  Description:        Create Excel report and send it by E-mail
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   20/04/2015    Michal tzvik    initial build
  --------------------------------------------------------------------
  PROCEDURE report_data(p_email_address IN VARCHAR2) IS
    l_email_body VARCHAR2(1500);
  
    CURSOR c_int IS
      SELECT xai.batch_id,
	 xai.profile_amt_attribute1 atradius_id,
	 xai.profile_amt_attribute8 organization_name,
	 hp.party_name customer_name,
	 hca.account_number customer_number,
	 (SELECT nvl(MAX(ffv.description), 'N/A')
	  FROM   xxhz_account_interface    ai,
	         fnd_flex_value_sets       ffvs,
	         fnd_flex_values_vl        ffv,
	         fnd_flex_value_children_v ffvc
	  WHERE  1 = 1
	  AND    ffvc.description = xai.profile_amt_attribute7
	  AND    ffvs.flex_value_set_name = 'XXGL_LOCATION_SEG'
	  AND    ffvs.flex_value_set_id = ffv.flex_value_set_id
	  AND    ffvc.flex_value_set_id = ffv.flex_value_set_id
	  AND    ffvc.parent_flex_value = ffv.flex_value
	  AND    ffv.description NOT LIKE 'Budget%') || ' (' ||
	 xai.profile_amt_attribute7 || ')' region_country,
	 xai.profile_amt_attribute9 match_type,
	 xai.interface_id,
	 xai.interface_status,
	 xai.log_message
      FROM   xxhz_account_interface xai,
	 hz_parties             hp,
	 hz_cust_accounts       hca
      WHERE  hca.cust_account_id(+) = xai.cust_account_id
      AND    hp.party_id(+) = hca.party_id
      AND    xai.batch_id = g_request_id;
  
    l_return_status          VARCHAR2(1);
    l_msg                    VARCHAR2(500);
    l_xxssys_generic_rpt_rec xxssys_generic_rpt%ROWTYPE;
  
  BEGIN
    -- Insert header row for reporting
    l_xxssys_generic_rpt_rec.request_id      := g_request_id;
    l_xxssys_generic_rpt_rec.header_row_flag := 'Y';
    l_xxssys_generic_rpt_rec.col1            := 'Atradius ID';
    l_xxssys_generic_rpt_rec.col2            := 'Organization name';
    l_xxssys_generic_rpt_rec.col3            := 'Customer Name';
    l_xxssys_generic_rpt_rec.col4            := 'Customer Number';
    l_xxssys_generic_rpt_rec.col5            := 'Country';
    l_xxssys_generic_rpt_rec.col6            := 'Match Type';
    l_xxssys_generic_rpt_rec.col7            := 'Interface Id';
    l_xxssys_generic_rpt_rec.col8            := 'Interface Status';
  
    xxssys_generic_rpt_pkg.ins_xxssys_generic_rpt(p_xxssys_generic_rpt_rec => l_xxssys_generic_rpt_rec,
				  
				  x_return_status => l_return_status,
				  
				  x_return_message => l_msg);
  
    IF l_return_status <> 'S' THEN
      RAISE report_error;
    END IF;
  
    FOR r_int_line IN c_int LOOP
      -- Insert details for reporting
      l_xxssys_generic_rpt_rec.request_id      := g_request_id;
      l_xxssys_generic_rpt_rec.email_to        := p_email_address;
      l_xxssys_generic_rpt_rec.header_row_flag := 'N';
      l_xxssys_generic_rpt_rec.col1            := r_int_line.atradius_id;
      l_xxssys_generic_rpt_rec.col2            := r_int_line.organization_name;
      l_xxssys_generic_rpt_rec.col3            := r_int_line.customer_name;
      l_xxssys_generic_rpt_rec.col4            := r_int_line.customer_number;
      l_xxssys_generic_rpt_rec.col5            := r_int_line.region_country;
      l_xxssys_generic_rpt_rec.col6            := r_int_line.match_type;
      l_xxssys_generic_rpt_rec.col7            := r_int_line.interface_id;
      l_xxssys_generic_rpt_rec.col8            := r_int_line.interface_status;
      l_xxssys_generic_rpt_rec.col_msg         := r_int_line.log_message;
    
      xxssys_generic_rpt_pkg.ins_xxssys_generic_rpt(p_xxssys_generic_rpt_rec => l_xxssys_generic_rpt_rec,
				    
				    x_return_status => l_return_status,
				    
				    x_return_message => l_msg);
    
      IF l_return_status <> 'S' THEN
        RAISE report_error;
      END IF;
    END LOOP;
  
    l_email_body := '''Attached Atradius Credit interface status report. Please review and take care of ERROR.''';
    -- Submit request to launch generic reporting.
    xxssys_generic_rpt_pkg.submit_request(p_burst_flag => 'Y',
			      
			      p_request_id          => g_request_id, -- This would normally be launched from a program with a request_id
			      p_l_report_title      => '''Atradius Credit interface status report''', -- We want report title to request_id
			      p_l_report_pre_text1  => '', -- If all my pre-text did not fit in p_pre_text1, I can continue in p_pre_text2 parameter
			      p_l_report_pre_text2  => '', -- Continued pre_text - when appended together will read 'Test pre text1 Test pre text2'
			      p_l_report_post_text1 => '', -- There is a post text2 parameter, which I'm not using, so need to close my quote
			      --p_l_report_post_text2       => ' Test post text2''',
			      p_l_email_subject => '''Atradius Credit interface status report''', -- Subject of bursted email.
			      p_l_email_body1   => l_email_body, -- Email body 1 (can continue to p_email_body2 if needed
			      --p_l_email_body2             => ' Test email body2''',
			      p_l_order_by  => 'col4', -- Order column by col5 (employee_number in our case)
			      p_l_file_name => '''CUSTOMER_CREDIT_UPLOAD''',
			      
			      p_l_key_column => 'col_1',
			      
			      p_l_purge_table_flag => 'Y', -- Determines wether or not to PURGE xxssys_generic_rpt table after bursting
			      
			      x_return_status => l_return_status,
			      
			      x_return_message => l_msg);
    dbms_output.put_line('l_return_status: ' || l_return_status);
    dbms_output.put_line('l_msg          : ' || l_msg);
  EXCEPTION
    WHEN report_error THEN
      fnd_file.put_line(fnd_file.log, 'Error ' || 'l_msg: ' || l_msg);
      RAISE report_error;
    WHEN OTHERS THEN
      fnd_file.put_line(fnd_file.log, 'Error ' || SQLERRM);
    
  END report_data;
  --------------------------------------------------------------------
  --  name:               upd_log
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  customization code: CHG0034610 - Upload Customer credit data from Atradius
  --  creation date:      20/04/2015
  --  Description:        update interface table with Log message and status
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   20/04/2015    Michal Tzvik    initial build
  --------------------------------------------------------------------
  PROCEDURE upd_log(p_log_msg      IN VARCHAR2,
	        p_status       IN VARCHAR2,
	        p_interface_id IN NUMBER) IS
  BEGIN
    UPDATE xxhz_account_interface a
    SET    a.log_message      = a.log_message || ' ' || p_log_msg,
           a.interface_status = p_status,
           a.last_update_date = SYSDATE
    WHERE  a.interface_id = p_interface_id
    AND    a.batch_id = g_request_id;
  END upd_log;

  --------------------------------------------------------------------
  --  name:               convert_name
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  customization code: CHG0034610 - Upload Customer credit data from Atradius
  --  creation date:      19/04/2015
  --  Description:        Remove special characters, spaces and substrings from party name
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   19/04/2015    Michal Tzvik    initial build
  --------------------------------------------------------------------
  FUNCTION convert_name(p_party_name VARCHAR2) RETURN VARCHAR2 IS
    l_converted hz_parties.party_name%TYPE;
  BEGIN
    l_converted := regexp_replace(upper(p_party_name),
		          '( *[[:punct:]])|( ){1,}|INC|LTD|LLC|CORP|CORPORATION');
  
    RETURN l_converted;
  
  END convert_name;
  --------------------------------------------------------------------
  --  name:               handle_data
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  customization code: CHG0034610 - Upload Customer credit data from Atradius
  --  creation date:      19/04/2015
  --  Description:
  --                      1. Identify the relevant customers in Oracle and populate field cust_account_id
  --                      2. Disable muliple records for the same customer
  --                      3. Populate DUNS number for US ???
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   19/04/2015    Michal Tzvik    initial build
  --  1.1  22.2.16        yuval tal       CHG0037612- check date format 'DD-Mon-YYYY'
  --                                      support NULL value  
  --------------------------------------------------------------------
  PROCEDURE handle_data(errbuf                   OUT VARCHAR2,
		retcode                  OUT VARCHAR2,
		p_partial_customer_match VARCHAR2) IS
    CURSOR c_data IS
      SELECT *
      FROM   xxhz_account_interface xai
      WHERE  xai.batch_id = g_request_id
      AND    xai.interface_status = c_sts_new;
  
    l_cust_account_id NUMBER;
    l_match_type      VARCHAR2(20);
    l_status          xxhz_account_interface.interface_status%TYPE;
    l_message         xxhz_account_interface.log_message%TYPE;
    l_party_name      VARCHAR2(250);
    l_date            DATE;
    l_number          NUMBER;
  
    no_match    EXCEPTION;
    multy_match EXCEPTION;
  BEGIN
    errbuf  := '';
    retcode := '0';
  
    fnd_file.put_line(fnd_file.log, 'Handle data...');
    /************************** 1. Identify customer *********************/
    -- Only Active Customer Accounts with �BILL_TO� address are considered
    FOR r_data IN c_data LOOP
      l_match_type := NULL;
      BEGIN
        l_status  := '';
        l_message := '';
      
        -- 1.1 Match by Atradius_id
        fnd_file.put_line(fnd_file.log, 'Match by Atradius_id...');
        BEGIN
          SELECT hcpa.cust_account_id
          INTO   l_cust_account_id
          FROM   hz_cust_profile_amts hcpa
          WHERE  hcpa.attribute1 = r_data.profile_amt_attribute1
          AND    hcpa.currency_code = 'USD'
          AND    hcpa.site_use_id IS NULL
          AND    EXISTS
           (SELECT 1
	      FROM   hz_cust_accounts       hca,
		 hz_cust_acct_sites_all hcasa,
		 hz_cust_site_uses_all  hcsua
	      WHERE  hca.cust_account_id = hcpa.cust_account_id
	      AND    hca.status = 'A'
	      AND    hcasa.cust_account_id = hca.cust_account_id
	      AND    hcsua.cust_acct_site_id = hcasa.cust_acct_site_id
	      AND    hcsua.site_use_code = 'BILL_TO');
        
          l_match_type := 'ID';
        
        EXCEPTION
          WHEN too_many_rows THEN
	RAISE multy_match;
          WHEN no_data_found THEN
          
	-- 1.2 Match by VAT Number
	fnd_file.put_line(fnd_file.log, 'Match by VAT Number...');
	BEGIN
	  SELECT hca.cust_account_id
	  INTO   l_cust_account_id
	  FROM   hz_parties       hp,
	         hz_cust_accounts hca
	  WHERE  hp.jgzz_fiscal_code = r_data.jgzz_fiscal_code
	  AND    hp.party_type = 'ORGANIZATION'
	  AND    hca.party_id = hp.party_id
	  AND    hca.status = 'A'
	  AND    EXISTS
	   (SELECT 1
	          FROM   hz_cust_acct_sites_all hcasa,
		     hz_cust_site_uses_all  hcsua
	          WHERE  hcasa.cust_account_id = hca.cust_account_id
	          AND    hcasa.cust_account_id = hca.cust_account_id
	          AND    hcsua.cust_acct_site_id =
		     hcasa.cust_acct_site_id
	          AND    hcsua.site_use_code = 'BILL_TO');
	
	  l_match_type := 'VAT';
	
	EXCEPTION
	  WHEN too_many_rows THEN
	    RAISE multy_match;
	  WHEN no_data_found THEN
	  
	    -- 1.3 Match by Exact party name after removing Special Characters
	    fnd_file.put_line(fnd_file.log,
		          'Match by Exact party name...');
	    l_party_name := convert_name(r_data.profile_amt_attribute8); -- regexp_replace(upper(r_data.profile_amt_attribute8), '( *[[:punct:]])|INC|LTD|LLC|CORP|CORPORATION');
	    fnd_file.put_line(fnd_file.log, l_party_name); -- remove !!!
	    BEGIN
	      SELECT hca.cust_account_id
	      INTO   l_cust_account_id
	      FROM   hz_parties       hp,
		 hz_cust_accounts hca
	      WHERE  xxhz_customer_credit_int_pkg.convert_name(hp.party_name) =
		 l_party_name
	      AND    hp.party_type = 'ORGANIZATION'
	      AND    hca.party_id = hp.party_id
	      AND    hca.status = 'A'
	      AND    EXISTS
	       (SELECT 1
		  FROM   hz_cust_acct_sites_all hcasa,
		         hz_cust_site_uses_all  hcsua
		  WHERE  hcasa.cust_account_id = hca.cust_account_id
		  AND    hcasa.cust_account_id = hca.cust_account_id
		  AND    hcsua.cust_acct_site_id =
		         hcasa.cust_acct_site_id
		  AND    hcsua.site_use_code = 'BILL_TO');
	    
	      l_match_type := 'EXACT';
	    
	    EXCEPTION
	      WHEN too_many_rows THEN
	        RAISE multy_match;
	      WHEN no_data_found THEN
	      
	        -- 1.4 Match by Partial Name
	        fnd_file.put_line(fnd_file.log,
			  'Match by Partial party name...');
	        IF p_partial_customer_match = 'Y' THEN
	          BEGIN
		SELECT hca.cust_account_id
		INTO   l_cust_account_id
		FROM   hz_parties       hp,
		       hz_cust_accounts hca
		WHERE  substr(xxhz_customer_credit_int_pkg.convert_name(hp.party_name),
			  1,
			  11) = substr(l_party_name, 1, 11)
		AND    hp.party_type = 'ORGANIZATION'
		AND    hca.party_id = hp.party_id
		AND    hca.status = 'A'
		AND    EXISTS
		 (SELECT 1
		        FROM   hz_cust_acct_sites_all hcasa,
			   hz_cust_site_uses_all  hcsua
		        WHERE  hcasa.cust_account_id =
			   hca.cust_account_id
		        AND    hcasa.cust_account_id =
			   hca.cust_account_id
		        AND    hcsua.cust_acct_site_id =
			   hcasa.cust_acct_site_id
		        AND    hcsua.site_use_code = 'BILL_TO');
	          
		l_match_type := 'PARTIAL';
	          
	          EXCEPTION
		WHEN too_many_rows THEN
		  RAISE multy_match;
		WHEN no_data_found THEN
		  RAISE no_match;
	          END;
	        ELSE
	          RAISE no_match;
	        END IF;
	    END;
	END;
        END;
      
        UPDATE xxhz_account_interface xai
        SET    xai.cust_account_id        = l_cust_account_id,
	   xai.profile_amt_attribute9 = l_match_type
        WHERE  xai.interface_id = r_data.interface_id;
      
        COMMIT;
      
      EXCEPTION
        WHEN multy_match THEN
          l_message := 'Multiple matching Customers';
          fnd_file.put_line(fnd_file.log, l_message);
          upd_log(l_message, c_sts_error, r_data.interface_id);
        WHEN no_match THEN
          l_message := 'No matching Customer was found';
          fnd_file.put_line(fnd_file.log, l_message);
          upd_log(l_message, c_sts_error, r_data.interface_id);
        WHEN OTHERS THEN
          l_message := 'Unexpected error in handle_data: ' || SQLERRM;
          fnd_file.put_line(fnd_file.log, l_message);
          upd_log(l_message, c_sts_error, r_data.interface_id);
      END;
    END LOOP;
  
    COMMIT;
    fnd_file.put_line(fnd_file.log, '-------------------------');
    fnd_file.put_line(fnd_file.log, 'validate DFF data types');
    fnd_file.put_line(fnd_file.log, '-------------------------');
    -- validate DFF data types
    FOR r_data IN c_data LOOP
      DECLARE
        l_date_tmp DATE;
      BEGIN
        -- CHG0037612
      
        IF r_data.profile_amt_attribute3 != 'NULL' THEN
          l_date_tmp := to_date(r_data.profile_amt_attribute3,
		        'DD-Mon-YYYY'); -- Application date
        END IF;
        IF r_data.profile_amt_attribute5 != 'NULL' THEN
          l_date_tmp := to_date(r_data.profile_amt_attribute5,
		        'DD-Mon-YYYY'); -- Decision effective date
        END IF;
      
        IF r_data.profile_amt_attribute6 != 'NULL' THEN
          l_date_tmp := to_date(r_data.profile_amt_attribute6,
		        'DD-Mon-YYYY'); -- Expiry date
        END IF;
      
      EXCEPTION
        WHEN OTHERS THEN
          upd_log('Application date, Decision effective date and Expiry date fields must be in DD-Mon-YYYY format.',
	      c_sts_error,
	      r_data.interface_id);
      END;
    
    END LOOP;
  
    fnd_file.put_line(fnd_file.log, '-------------------------');
    fnd_file.put_line(fnd_file.log,
	          'Check Disable muliple records for the same customer');
    fnd_file.put_line(fnd_file.log, '-------------------------');
  
    /*************** 2. Disable muliple records for the same customer ****************/
  
    -- 2.1 If Multiple records exist in the file for the same customer� none of them have value in decision date field-
    -- process the record with max(application_date) and put other records in status 'INFO'
    UPDATE xxhz_account_interface xai
    SET    xai.interface_status = c_sts_info,
           xai.log_message      = 'There is a newer record for this customer'
    WHERE  xai.batch_id = g_request_id
    AND    xai.interface_status = c_sts_new
    AND    xai.profile_amt_attribute5 IS NULL
    AND    upper(xai.profile_amt_attribute3) != 'NULL' --CHG0037612
    AND    NOT EXISTS ---> none of them have value in decision date field
     (SELECT 1
	FROM   xxhz_account_interface xai1
	WHERE  xai1.batch_id = xai.batch_id
	AND    xai1.interface_status = c_sts_new
	AND    xai1.cust_account_id = xai.cust_account_id
	AND    xai1.interface_id != xai.interface_id
	AND    xai1.profile_amt_attribute5 IS NOT NULL)
    AND    EXISTS ---> For the same customer, exists record with greater application date
     (SELECT 1
	FROM   xxhz_account_interface xai1
	WHERE  xai1.batch_id = xai.batch_id
	AND    xai1.interface_status = c_sts_new
	AND    xai1.cust_account_id = xai.cust_account_id
	AND    xai1.interface_id != xai.interface_id
	AND    upper(xai1.profile_amt_attribute3) != 'NULL' --CHG0037612
	      --AND    fnd_date.canonical_to_date(xai1.profile_amt_attribute3) >
	      --    fnd_date.canonical_to_date(xai.profile_amt_attribute3)
	AND    to_date(xai1.profile_amt_attribute3, 'dd-mon-yyyy') >
	       to_date(xai.profile_amt_attribute3, 'dd-mon-yyyy'));
    COMMIT;
    -- 2.1 If multiple rows exist for same cust_account_id and in one of them decision date is null- process the record with
    --  max(decision_effective_date) and put the record with null decision on status 'ERROR'
    UPDATE xxhz_account_interface xai
    SET    xai.interface_status = c_sts_error,
           xai.log_message      = 'There is no decision for this record yet. You can update the application data manually'
    WHERE  xai.batch_id = g_request_id
    AND    xai.interface_status = c_sts_new
    AND    xai.profile_amt_attribute5 IS NULL
    AND    EXISTS
     (SELECT 1
	FROM   xxhz_account_interface xai1
	WHERE  xai1.batch_id = xai.batch_id
	AND    xai1.interface_status = c_sts_new
	AND    xai1.cust_account_id = xai.cust_account_id
	AND    xai1.interface_id != xai.interface_id
	AND    xai1.profile_amt_attribute5 IS NOT NULL);
    COMMIT;
    -- 2.2   Old records are not rellevant and don't have to be processed to Oracle.
    --       So the status is changed to INFO and not to ERROR.
    UPDATE xxhz_account_interface xai
    SET    xai.interface_status = c_sts_info,
           xai.log_message      = 'There is a newer record for this customer'
    WHERE  xai.batch_id = g_request_id
    AND    xai.interface_status = c_sts_new
    AND    upper(xai.profile_amt_attribute5) != 'NULL' --CHG0037612
    AND    EXISTS
     (SELECT 1
	FROM   xxhz_account_interface xai1
	WHERE  xai1.batch_id = xai.batch_id
	AND    xai1.interface_status = c_sts_new
	AND    xai1.cust_account_id = xai.cust_account_id
	AND    xai1.interface_id != xai.interface_id
	AND    upper(xai1.profile_amt_attribute5) != 'NULL' --CHG0037612
	      --AND    fnd_date.canonical_to_date(xai1.profile_amt_attribute5) >
	      --     fnd_date.canonical_to_date(xai.profile_amt_attribute5)
	      
	AND    to_date(xai1.profile_amt_attribute5, 'dd-mon-yyyy') >
	       to_date(xai.profile_amt_attribute5, 'dd-mon-yyyy'));
    COMMIT;
    -- 2.3 If we have Multiple Atradius ID's for same cust_account_id
    --     put both in ERROR. In this case we don't check what is the record status.
    UPDATE xxhz_account_interface xai
    SET    xai.interface_status = c_sts_error,
           xai.log_message      = 'Multiple Atradius ID''s are matched to this customer. Please update the data manually.'
    WHERE  xai.batch_id = g_request_id
    AND    EXISTS
     (SELECT 1
	FROM   xxhz_account_interface xai1
	WHERE  xai1.batch_id = xai.batch_id
	AND    xai1.cust_account_id = xai.cust_account_id
	AND    xai1.profile_amt_attribute1 != xai.profile_amt_attribute1);
  
    -- 3.2  Update a customer record only if the decision date in the
    --      atradius file is later than the existing decision date in oracle
    UPDATE xxhz_account_interface xai
    SET    xai.interface_status = c_sts_info,
           xai.log_message      = 'A newer decision date exists in Oracle.'
    WHERE  xai.batch_id = g_request_id
    AND    xai.interface_status = c_sts_new
    AND    upper(xai.profile_amt_attribute5) != 'NULL' --CHG0037612
    AND    EXISTS
     (SELECT 1
	FROM   hz_cust_profile_amts hcpa
	WHERE  hcpa.cust_account_id = xai.cust_account_id
	AND    hcpa.currency_code = 'USD'
	AND    hcpa.site_use_id IS NULL
	      
	AND    fnd_date.canonical_to_date(hcpa.attribute5) >
	       to_date(xai.profile_amt_attribute5, 'dd-mon-yyyy')
	/*fnd_date.canonical_to_date(xai.profile_amt_attribute5) */
	);
    COMMIT;
    -- 3.3 If VAT Number in the file is different from existing value in Oracle
    --     Then vat number from the file should not overide existing value.
    --     The rest of the fields should be uploaded, so status will not change,
    --     Only a message will be updated.
    UPDATE xxhz_account_interface xai
    SET    /*xai.log_message       = 'Inconsistent VAT number between Atradius and Oracle. In Atradius Vat Number ' ||
           xai.jgzz_fiscal_code,*/ xai.party_attribute12 = '' /*,
                                                                                                                                                                                                                           xai.interface_status  = c_sts_error*/
    WHERE  xai.batch_id = g_request_id
    AND    xai.interface_status = c_sts_new
    AND    xai.jgzz_fiscal_code IS NOT NULL
    AND    EXISTS
     (SELECT 1
	FROM   hz_parties       hp,
	       hz_cust_accounts hca
	WHERE  hca.cust_account_id = xai.cust_account_id
	AND    hp.party_id = hca.party_id
	AND    hp.jgzz_fiscal_code IS NOT NULL
	AND    hp.jgzz_fiscal_code != xai.jgzz_fiscal_code);
  
    -- 3.4 The amounts in Atradius file are in K USD.
    --    So amounts should be multiply by 1000
  
    -- CHG0037612    Adjust the program to delete CI information and replace 0 amounts with NULL values
    UPDATE xxhz_account_interface xai
    SET    xai.profile_amt_attribute2 = decode(upper(xai.profile_amt_attribute2),
			           'NULL',
			           'NULL',
			           '0',
			           'NULL',
			           xai.profile_amt_attribute2 * 1000),
           xai.profile_amt_attribute4 = decode(upper(xai.profile_amt_attribute4),
			           'NULL',
			           'NULL',
			           '0',
			           'NULL',
			           xai.profile_amt_attribute4 * 1000)
    
    WHERE  xai.batch_id = g_request_id
    AND    xai.interface_status = c_sts_new;
  
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := SQLERRM;
      retcode := '1';
    
      UPDATE xxhz_account_interface xai
      SET    xai.interface_status = c_sts_error,
	 xai.log_message      = errbuf
      WHERE  xai.batch_id = g_request_id
      AND    xai.interface_status = c_sts_new;
  END handle_data;

  --------------------------------------------------------------------
  --  name:               process_accounts
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  customization code: CHG0034610 - Upload Customer credit data from Atradius
  --  creation date:      19/04/2015
  --  Description:        Submit request of 'XXHZ Interface Process Accounts'
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   19/04/2015    Michal Tzvik    initial build
  --------------------------------------------------------------------
  PROCEDURE process_accounts(errbuf   OUT VARCHAR2,
		     retcode  OUT VARCHAR2,
		     p_source IN VARCHAR2) IS
  
    x_request_id     NUMBER;
    l_phase          VARCHAR2(240);
    l_status         VARCHAR2(240);
    l_request_phase  VARCHAR2(240);
    l_request_status VARCHAR2(240);
    l_finished       BOOLEAN;
    l_message        VARCHAR2(240);
  BEGIN
    errbuf  := '';
    retcode := '0';
  
    x_request_id := fnd_request.submit_request('XXOBJT',
			           
			           'XXHZ_PROCESS_ACCOUNTS',
			           
			           NULL,
			           NULL,
			           FALSE,
			           
			           p_source);
  
    IF x_request_id > 0 THEN
      fnd_file.put_line(fnd_file.log,
		'Concurrent ''XXHZ Interface Process Accounts'' was submitted successfully (request_id=' ||
		x_request_id || ')');
      COMMIT;
      -- Wait for request to complete
      l_finished := fnd_concurrent.wait_for_request(request_id => x_request_id,
				    INTERVAL   => 0,
				    max_wait   => 0,
				    phase      => l_phase,
				    status     => l_status,
				    dev_phase  => l_request_phase,
				    dev_status => l_request_status,
				    message    => l_message);
    
      IF NOT l_finished THEN
        errbuf  := 'Failed to wait for Request ID ' || x_request_id;
        retcode := '1';
      END IF;
    
      IF (upper(l_request_status) <> 'NORMAL') THEN
        errbuf  := 'Request ID ' || x_request_id ||
	       ' returned with a satus of ' || l_request_status;
        retcode := '1';
      END IF;
    
    ELSE
      retcode := '1';
      errbuf  := 'Failed to submit request.';
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := SQLERRM;
      retcode := '1';
  END process_accounts;
  ----------------------------------------------------------------------
  --  customization code: CHG0034901
  --  name:               move_file
  --  create by:          Michal Tzvik
  --  creation date:      12/05/2015
  --  Purpose :           CHG0034610 - Upload Customer credit data from Atradius
  --
  --                      Submit concurrent requst "XX: Copy Concurrent Request Output"
  --                      in order to archive uploaded
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   12/05/2015    Michal Tzvik    Initial Build
  ----------------------------------------------------------------------
  PROCEDURE move_file(p_from_directory VARCHAR2,
	          p_from_file_name VARCHAR2,
	          p_to_directory   VARCHAR2,
	          p_to_file_name   VARCHAR2,
	          --x_request_id       OUT NUMBER,
	          x_err_code OUT NUMBER,
	          x_err_msg  OUT VARCHAR2) IS
  
    l_phase      VARCHAR2(20);
    l_status     VARCHAR2(20);
    l_dev_phase  VARCHAR2(20);
    l_dev_status VARCHAR2(20);
    l_message    VARCHAR2(150);
    x_request_id NUMBER;
  BEGIN
  
    x_err_msg  := '';
    x_err_code := 0;
  
    x_request_id := fnd_request.submit_request(application => 'XXOBJT', --
			           program     => 'XXMVFILE', --
			           argument1   => p_from_directory, -- to_Directory
			           argument2   => p_from_file_name, -- to_File_Name
			           argument3   => p_to_directory, -- to_Directory
			           argument4   => p_to_file_name -- to_File_Name
			           );
  
    COMMIT;
  
    IF x_request_id = 0 THEN
      x_err_msg  := 'Error submitting request of move file to directory';
      x_err_code := 1;
      RETURN;
    
    ELSE
      x_err_msg := 'Request ' || x_request_id ||
	       ' was submitted successfully';
    
    END IF;
  
    IF fnd_concurrent.wait_for_request(request_id => x_request_id, --
			   INTERVAL   => 5, --
			   phase      => l_phase, --
			   status     => l_status, --
			   dev_phase  => l_dev_phase, --
			   dev_status => l_dev_status, --
			   message    => l_message) THEN
    
      NULL;
    
    END IF;
    IF upper(l_phase) = 'COMPLETE' AND
       upper(l_status) IN ('ERROR', 'WARNING') THEN
      x_err_code := 1;
      x_err_msg  := ' move file program completed in ' || l_status ||
	        '. See log for request_id=' || x_request_id;
      RETURN;
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      x_err_msg  := 'Error when move file: ' || SQLERRM;
      x_err_code := 1;
  END move_file;

  --------------------------------------------------------------------
  --  name:               main
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  customization code: CHG0034610 - Upload Customer credit data from Atradius
  --  creation date:      19/04/2015
  --  Description:        Main procedure, called by concurrent executable .
  --                      1. Upload data from csv file to xxhz_account_interface table.
  --                      2. Handle data in interface table
  --                      3. Process data to Oracle.
  --                      4. Create output- Excel report
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   19/04/2015    Michal Tzvik    initial build
  --  1.1  22.2.16        yuval tal       CHG0037612- update  NULL records for Atradius records with no info on last upload 

  --------------------------------------------------------------------
  PROCEDURE main(errbuf                   OUT VARCHAR2,
	     retcode                  OUT VARCHAR2,
	     p_table_name             IN VARCHAR2, -- hidden parameter. default value ='XXHZ_ACCOUNT_INTERFACE' independent value set XXOBJT_LOADER_TABLES
	     p_template_name          IN VARCHAR2, -- hidden parameter. default value ='ATRADIUS'
	     p_file_name              IN VARCHAR2,
	     p_directory              IN VARCHAR2,
	     p_partial_customer_match IN VARCHAR2,
	     p_email_address          IN VARCHAR2,
	     p_arc_directory          IN VARCHAR2) IS
  
    l_errbuf        VARCHAR2(2000);
    l_retcode       VARCHAR2(1);
    l_error_message VARCHAR2(2000);
  
    stop_processing EXCEPTION;
    load_file_error EXCEPTION;
  BEGIN
    retcode := '0';
  
    -- 1. upload data from csv to interface table (XXOE_DISCOUNT_BUCKET_INTERFACE)
    fnd_file.put_line(fnd_file.log, 'Upload data from csv...');
    xxobjt_table_loader_util_pkg.load_file(errbuf                 => l_errbuf,
			       retcode                => l_retcode,
			       p_table_name           => p_table_name,
			       p_template_name        => p_template_name,
			       p_file_name            => p_file_name,
			       p_directory            => p_directory,
			       p_expected_num_of_rows => NULL);
  
    IF l_retcode <> '0' THEN
      l_error_message := l_errbuf;
      RAISE load_file_error;
    END IF;
  
    -- 1.1 Archive file
    move_file(p_from_directory => p_directory,
	  p_from_file_name => p_file_name,
	  p_to_directory   => p_arc_directory,
	  p_to_file_name   => 'Credit_' || to_char(SYSDATE, 'DDMMYY') || '_' ||
		          to_char(SYSDATE, 'hh24miss') || '.csv',
	  x_err_code       => l_retcode,
	  x_err_msg        => l_errbuf);
  
    IF l_retcode <> '0' THEN
      --l_error_message := l_errbuf;
      --RAISE stop_processing;
      fnd_file.put_line(fnd_file.log, l_errbuf);
      retcode   := '1';
      l_retcode := '0';
    END IF;
  
    -- 2. Validate
    handle_data(errbuf => l_errbuf,
	    
	    retcode => l_retcode,
	    
	    p_partial_customer_match => p_partial_customer_match);
  
    IF l_retcode <> '0' THEN
      l_error_message := l_errbuf;
      RAISE stop_processing;
    END IF;
  
    -- CHG0037612 insert NULL records for exists records not updated in last upload 
    INSERT INTO xxhz_account_interface
      (interface_id,
       batch_id,
       cust_account_id,
       profile_amt_attribute1,
       profile_amt_attribute2,
       profile_amt_attribute3,
       profile_amt_attribute4,
       profile_amt_attribute5,
       profile_amt_attribute6,
       profile_amt_attribute7,
       interface_status,
       interface_source)
    
      SELECT xxhz_account_interface_s.nextval,
	 fnd_global.conc_request_id,
	 cust_account_id,
	 attribute1,
	 'NULL',
	 'NULL',
	 'NULL',
	 'NULL',
	 'NULL',
	 'NULL',
	 'NEW',
	 'CREDIT_INS'
      FROM   (SELECT hcpa.attribute1,
	         cust_account_id
	  FROM   hz_cust_profile_amts hcpa
	  WHERE  hcpa.currency_code = 'USD'
	  AND    hcpa.site_use_id IS NULL
	  AND    hcpa.attribute1 is not null
	  AND    (hcpa.attribute2 IS NOT NULL OR
	        hcpa.attribute3 IS NOT NULL OR
	        hcpa.attribute5 IS NOT NULL OR
	        hcpa.attribute5 IS NOT NULL OR
	        hcpa.attribute6 IS NOT NULL)
	  MINUS
	  SELECT t.profile_amt_attribute1,
	         t.cust_account_id
	  FROM   xxhz_account_interface t
	  WHERE  interface_source = 'CREDIT_INS'
	  AND    t.batch_id = fnd_global.conc_request_id);
    fnd_file.put_line(fnd_file.log, SQL%ROWCOUNT || ' Null records added ');
    COMMIT;
  
    /* (SELECT MAX(batch_id)
    FROM   xxhz_account_interface tt
    WHERE  tt.interface_source = 'CREDIT_INS'));*/
  
    -- 3. Convert data and upload to target tables
    /*xxhz_interfaces_pkg.main_process_accounts(errbuf => l_error_message,
    
    retcode => l_retcode);*/
  
    process_accounts(errbuf => l_error_message,
	         
	         retcode => l_retcode,
	         
	         p_source => 'CREDIT_INS');
  
    IF l_retcode <> '0' THEN
      RAISE stop_processing;
    END IF;
  
    -- 4. Create output
    report_data(p_email_address);
  EXCEPTION
    WHEN report_error THEN
      fnd_file.put_line(fnd_file.log, 'Failed to generate report');
      retcode := 1;
      errbuf  := 'Unexpected error: report error';
    
    WHEN load_file_error THEN
      fnd_file.put_line(fnd_file.log, l_error_message);
      -- This program is supposed to be scheduled, but not always the file will exists in the folder.
      -- In such case, the program will complete normal, so no alert will be sent.
      IF l_error_message LIKE '%ORA-29400%' THEN
        fnd_file.put_line(fnd_file.log,
		  'Error: File ''' || p_file_name ||
		  ''' does not exist');
        retcode := 0;
        errbuf  := 'Invalid file name';
      ELSE
        -- file exists, but data is invalid (for example)
        retcode := 1;
        errbuf  := 'Unexpected error in uploading file';
      END IF;
    
    WHEN stop_processing THEN
      fnd_file.put_line(fnd_file.log, l_error_message);
      retcode := 1;
      errbuf  := 'Unexpected error';
    
      -- 4. Create output
      report_data(p_email_address);
    
    WHEN OTHERS THEN
      retcode := 1;
      errbuf  := 'Unexpected error: ' || SQLERRM;
    
      -- 4. Create output
      report_data(p_email_address);
    
  END main;
END xxhz_customer_credit_int_pkg;
/
