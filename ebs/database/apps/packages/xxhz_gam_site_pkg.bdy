CREATE OR REPLACE PACKAGE BODY xxhz_gam_site_pkg IS

  --------------------------------------------------------------------
  --  name:            XXHZ_GAM_SITE_PKG
  --  create by:       Dalit A. Raviv
  --  Revision:        1.4
  --  creation date:   14/01/2013 15:59:19
  --------------------------------------------------------------------
  --  purpose :        CUST630 - GAM dashboard interface
  --                   There will be an interface between Oracle and GAM site.
  --                   1.  A program will run every night and provide data about the GAM/KAM customers.
  --                   2.  It will create XML files of the required data.
  --                   3.  The files will be put on a specific directory.
  --                   4.  The GAM site developers will connect to that directory and pull the data.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  14/01/2013  Dalit A. Raviv    initial build
  --  1.1  25/02/2013  Dalit A. Raviv    function get_file_location - file_location will take from profile
  --  1.2  28/02/2013  Dalit A. Raviv    procedure rebate_ftp - correct handle of session param
  --                                     procedure contact_ftp - correct population select
  --  1.3  17/03/2013  Adi Safin         procedure rebate_ftp - Estimate need to run over today date instead of cur_year_last_day
  --  1.4  09/05/2013  Dalit A. Raviv    procedure rebate_ftp - GAM dashboard - modify the estimate rebate date for the end of the year
  --  1.5  25/07/2013  yuval tal         CR 797 : add default values to xml fields : account_ftp,machine_ftp,period_ftp,product_ftp,rebate_ftp,contact_ftp
  --------------------------------------------------------------------
  g_default_number  NUMBER := 9999999;
  g_default_varchar VARCHAR2(2) := 'NA';
  g_default_date    VARCHAR2(10) := '1900-01-01';
  g_default_boolean VARCHAR2(5) := 'false';
  --------------------------------------------------------------------
  --  name:            get_file_name
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   15/01/2013
  --------------------------------------------------------------------
  --  purpose :        get the file name according to subject
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  15/01/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_file_name(p_entity IN VARCHAR2) RETURN VARCHAR2 IS
  
    l_file_name VARCHAR2(150) := NULL;
  BEGIN
  
    IF p_entity = 'ACCOUNT' THEN
      l_file_name := fnd_profile.value('XXHZ_GAM_SITE_FTP_FILE_NAME_ACCOUNT');
    ELSIF p_entity = 'PERIOD' THEN
      l_file_name := fnd_profile.value('XXHZ_GAM_SITE_FTP_FILE_NAME_PERIOD');
    ELSIF p_entity = 'PRODUCT' THEN
      l_file_name := fnd_profile.value('XXHZ_GAM_SITE_FTP_FILE_NAME_PRODUCT');
    ELSIF p_entity = 'SN' THEN
      l_file_name := fnd_profile.value('XXHZ_GAM_SITE_FTP_FILE_NAME_SN');
    ELSIF p_entity = 'REBATE' THEN
      l_file_name := fnd_profile.value('XXHZ_GAM_SITE_FTP_FILE_NAME_REBATE');
    ELSIF p_entity = 'CONTACT' THEN
      l_file_name := fnd_profile.value('XXHZ_GAM_SITE_FTP_FILE_NAME_CONTACT');
    ELSE
      l_file_name := 'xx_temp.csv';
    END IF;
  
    RETURN l_file_name;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'xx_temp.csv';
  END get_file_name;

  --------------------------------------------------------------------
  --  name:            get_ftp_login_details
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   14/08/2012
  --------------------------------------------------------------------
  --  purpose :        get stratasys login details for ftp
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  14/08/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE get_ftp_login_details(p_login_url OUT VARCHAR2,
                                  p_user      OUT VARCHAR2,
                                  p_password  OUT VARCHAR,
                                  p_err_code  OUT VARCHAR2,
                                  p_err_desc  OUT VARCHAR2) IS
  BEGIN
    p_err_code := 0;
    p_err_desc := NULL;
  
    p_login_url := fnd_profile.value('XXHZ_GAM_SITE_FTP_URL'); -- ftp.2objet.com
    p_user      := fnd_profile.value('XXHZ_GAM_SITE_FTP_USER'); -- gamsitewrite
    p_password  := fnd_profile.value('XXHZ_GAM_SITE_FTP_PASSWORD'); -- Ssyswrite123
  
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code  := 1;
      p_err_desc  := 'get_ftp_login_details - ' || substr(SQLERRM, 1, 240);
      p_login_url := NULL;
      p_user      := NULL;
      p_password  := NULL;
  END get_ftp_login_details;

  --------------------------------------------------------------------
  --  name:            get_file_location
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   14/01/2013 15:59:19
  --------------------------------------------------------------------
  --  purpose :        get the location to put the file in
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  14/01/2013  Dalit A. Raviv    initial build
  --  1.1  25/02/2013  Dalit A. Raviv    file_location will take from profile
  --------------------------------------------------------------------
  FUNCTION get_file_location RETURN VARCHAR2 IS
    l_env           VARCHAR2(150) := NULL;
    l_file_location VARCHAR2(240) := NULL;
  BEGIN
    l_env := xxobjt_fnd_attachments.get_environment_name;
    -- get file location
    IF l_env = 'PROD' THEN
      l_file_location := fnd_profile.value('XXHZ_GAM_SITE_FTP_FILE_LOCATION'); --'/UtlFiles/shared/'||l_env||'/CS/ftp';
    ELSE
      l_file_location := fnd_profile.value('XXHZ_GAM_SITE_FTP_FILE_LOCATION_DEV'); --'/UtlFiles/shared/DEV';
    END IF;
  
    RETURN l_file_location;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_file_location;

  --------------------------------------------------------------------
  --  name:            get_service_agreement
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   14/01/2013 15:59:19
  --------------------------------------------------------------------
  --  purpose :        If the result will be 0 then send true else send false
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  14/01/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  FUNCTION get_service_agreement(p_parent_party_id IN NUMBER,
                                 p_cust_account_id IN NUMBER) RETURN VARCHAR2 IS
    l_count_machins_parent NUMBER;
    l_count_active_sa      NUMBER;
  BEGIN
    SELECT xxhz_party_ga_util.get_system_ga_ib4acc(p_cust_account_id) -- count machines for global parent
      INTO l_count_machins_parent
      FROM dual;
  
    SELECT COUNT(DISTINCT cii.instance_id) num -- count active service agreement for global parent
      INTO l_count_active_sa
      FROM okc_k_headers_all_b h,
           okc_k_lines_b       l1,
           okc_k_lines_b       l2,
           okc_k_items         oki1, --ib
           okc_k_items         oki2, --contract
           csi_item_instances  cii,
           hz_cust_accounts    hca,
           mtl_system_items_b  msib,
           mtl_item_categories mic,
           mtl_categories_b    mcb,
           xxhz_party_ga_v     rel
     WHERE h.id = l1.dnz_chr_id
       AND oki1.object1_id1 = cii.instance_id
       AND oki1.cle_id = l1.id
       AND oki1.object1_id1 = cii.instance_id
       AND oki2.cle_id = l2.id
       AND l2.chr_id = h.id
       AND l1.sts_code IN ('ACTIVE', 'SIGNED')
       AND cii.owner_party_id = hca.party_id
       AND mcb.category_id = mic.category_id
       AND mcb.attribute4 = 'PRINTER'
       AND msib.inventory_item_id = mic.inventory_item_id
       AND cii.inventory_item_id = msib.inventory_item_id
       AND msib.organization_id = 91
       AND mic.organization_id = msib.organization_id
       AND h.scs_code = 'SERVICE'
       AND xxhz_party_ga_util.is_system_item(cii.inventory_item_id) = 'Y'
       AND cii.owner_party_id = rel.party_id
       AND rel.cust_account_id IN
           (SELECT par_acc.cust_account_id
              FROM xxhz_party_ga_v par_acc
             WHERE par_acc.parent_party_id = p_parent_party_id);
  
    IF (l_count_machins_parent - l_count_active_sa) = 0 THEN
      RETURN 'true'; -- all machins that under GA has service aggreement (contracts)
    ELSE
      RETURN 'false'; -- not all machins under SA
    END IF;
  
  END get_service_agreement;

  --------------------------------------------------------------------
  --  name:            account_ftp
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   15/01/2013
  --------------------------------------------------------------------
  --  purpose :        transfer account information of GAM
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  15/01/2013  Dalit A. Raviv    initial build
  --  1.1  25/07/2013  yuval tal         CR 797 : add default values to xml fields
  --------------------------------------------------------------------
  PROCEDURE account_ftp(errbuf OUT VARCHAR2, retcode OUT VARCHAR2) IS
  
    CURSOR account_c IS
      SELECT acc.cust_account_id,
             acc.party_id,
             htf.escape_sc(rtrim(ltrim(acc.party_name))) party_name,
             acc.parent_party_id,
             htf.escape_sc(rtrim(ltrim(acc.parent_party))) parent_party,
             to_char(acc.ga_start_date, 'YYYY-MM-DD') ga_start_date,
             acc.global_basket,
             acc.service_agreement,
             acc.country,
             acc.city city
        FROM xxhz_gam_site_accounts_v acc;
  
    l_file_name    VARCHAR2(150) := NULL;
    l_file_handler utl_file.file_type;
    l_user_name    VARCHAR2(150);
    l_password     VARCHAR2(150);
    l_login_url    VARCHAR2(150);
    l_err_code     VARCHAR2(150);
    l_err_desc     VARCHAR2(150);
  
    l_file_location VARCHAR2(240) := NULL;
    l_request_id    NUMBER;
    l_error_flag    BOOLEAN := FALSE;
    l_count         NUMBER := 0;
    l_phase         VARCHAR2(20);
    l_status        VARCHAR2(20);
    l_dev_phase     VARCHAR2(20);
    l_dev_status    VARCHAR2(20);
    l_message       VARCHAR2(100);
    l_result        BOOLEAN;
    l_count1        NUMBER := 0;
  BEGIN
    errbuf  := NULL;
    retcode := 0;
    -- check that there is data to transfer
    SELECT COUNT(1) INTO l_count1 FROM xxhz_gam_site_accounts_v v;
  
    IF l_count1 = 0 THEN
      fnd_file.put_line(fnd_file.log, 'There is no data to transfer');
      dbms_output.put_line('There is no data to transfer');
    ELSE
      l_file_name     := get_file_name('ACCOUNT');
      l_file_location := get_file_location;
      -- open new file with the for account data
      l_file_handler := utl_file.fopen(location  => l_file_location,
                                       filename  => l_file_name,
                                       open_mode => 'w');
    
      -- start write to the file
      utl_file.put_line(file   => l_file_handler,
                        buffer => '<?xml version="1.0" encoding="utf-8" ?>');
    
      utl_file.put_line(file   => l_file_handler,
                        buffer => '<Accounts xmlns="http://tempuri.org/GAMMinisite">');
    
      -- by loop add the tags and information
      FOR account_r IN account_c LOOP
        BEGIN
          utl_file.put_line(file => l_file_handler, buffer => '<Party>');
          utl_file.put_line(file   => l_file_handler,
                            buffer => '<PartyID>' ||
                                      nvl(account_r.party_id,
                                          g_default_number) || '</PartyID>');
          utl_file.put_line(file   => l_file_handler,
                            buffer => '<PartyName>' ||
                                      nvl(account_r.party_name,
                                          g_default_varchar) ||
                                      '</PartyName>');
          utl_file.put_line(file   => l_file_handler,
                            buffer => '<ParentPartyID>' ||
                                      nvl(account_r.parent_party_id,
                                          g_default_number) ||
                                      '</ParentPartyID>');
          utl_file.put_line(file   => l_file_handler,
                            buffer => '<ParentPartyName>' ||
                                      nvl(account_r.parent_party,
                                          g_default_varchar) ||
                                      '</ParentPartyName>');
          utl_file.put_line(file   => l_file_handler,
                            buffer => '<JoinedDate>' ||
                                      nvl(account_r.ga_start_date,
                                          g_default_date) || '</JoinedDate>');
          utl_file.put_line(file   => l_file_handler,
                            buffer => '<GlobalBasketLevel>' ||
                                      nvl(account_r.global_basket,
                                          g_default_varchar) ||
                                      '</GlobalBasketLevel>');
          utl_file.put_line(file   => l_file_handler,
                            buffer => '<GlobalServiceAgreement>' ||
                                      nvl(account_r.service_agreement,
                                          g_default_boolean) ||
                                      '</GlobalServiceAgreement>');
          utl_file.put_line(file   => l_file_handler,
                            buffer => '<Country>' ||
                                      nvl(account_r.country,
                                          g_default_varchar) || '</Country>');
          utl_file.put_line(file   => l_file_handler,
                            buffer => '<City>' ||
                                      nvl(account_r.city, g_default_varchar) ||
                                      '</City>');
          utl_file.put_line(file => l_file_handler, buffer => '</Party>');
        EXCEPTION
          WHEN utl_file.invalid_mode THEN
            fnd_file.put_line(fnd_file.log,
                              'The open_mode parameter in FOPEN is invalid');
            dbms_output.put_line('The open_mode parameter in FOPEN is invalid');
            errbuf  := 1;
            retcode := 'UTL_FILE Error';
          WHEN utl_file.invalid_path THEN
            fnd_file.put_line(fnd_file.log,
                              'Specified path does not exist or is not visible to Oracle');
            dbms_output.put_line('Specified path does not exist or is not visible to Oracle');
            errbuf  := 1;
            retcode := 'UTL_FILE Error';
          WHEN utl_file.invalid_filehandle THEN
            fnd_file.put_line(fnd_file.log, 'File handle does not exist');
            dbms_output.put_line('File handle does not exist');
            errbuf  := 1;
            retcode := 'UTL_FILE Error';
          WHEN utl_file.internal_error THEN
            fnd_file.put_line(fnd_file.log,
                              'Unhandled internal error in the UTL_FILE package');
            dbms_output.put_line('Unhandled internal error in the UTL_FILE package');
            errbuf  := 1;
            retcode := 'UTL_FILE Error';
          WHEN utl_file.file_open THEN
            fnd_file.put_line(fnd_file.log, 'File is already open');
            dbms_output.put_line('File is already open');
            errbuf  := 1;
            retcode := 'UTL_FILE Error';
          WHEN utl_file.invalid_maxlinesize THEN
            fnd_file.put_line(fnd_file.log,
                              'The MAX_LINESIZE value for FOPEN() is invalid; it should be within the range 1 to 32767');
            dbms_output.put_line('The MAX_LINESIZE value for FOPEN() is invalid; it should be within the range 1 to 32767');
            errbuf  := 1;
            retcode := 'UTL_FILE Error';
          WHEN utl_file.invalid_operation THEN
            fnd_file.put_line(fnd_file.log,
                              'File could not be opened or operated on as requested');
            dbms_output.put_line('File could not be opened or operated on as requested');
            errbuf  := 1;
            retcode := 'UTL_FILE Error';
          WHEN utl_file.write_error THEN
            fnd_file.put_line(fnd_file.log, 'Unable to write to file');
            dbms_output.put_line('Unable to write to file');
            errbuf  := 1;
            retcode := 'UTL_FILE Error';
          WHEN utl_file.access_denied THEN
            fnd_file.put_line(fnd_file.log,
                              'Access to the file has been denied by the operating system');
            dbms_output.put_line('Access to the file has been denied by the operating system');
            errbuf  := 1;
            retcode := 'UTL_FILE Error';
          WHEN OTHERS THEN
            fnd_file.put_line(fnd_file.log, 'Unknown UTL_FILE Error');
            dbms_output.put_line('Unknown UTL_FILE Error - ' || SQLERRM);
            errbuf  := 1;
            retcode := 'UTL_FILE Error';
        END;
      END LOOP; -- write to file
      -- add closing tag
      utl_file.put_line(file => l_file_handler, buffer => '</Accounts>');
      -- close the created file
      utl_file.fclose(file => l_file_handler);
    
      -- get ftp login details
      get_ftp_login_details(p_login_url => l_login_url, -- o v  -- ftp.2objet.com
                            p_user      => l_user_name, -- o v  -- gamsitewrite
                            p_password  => l_password, -- o v  -- Ssyswrite123
                            p_err_code  => l_err_code, -- o v
                            p_err_desc  => l_err_desc); -- o v
    
      fnd_file.put_line(fnd_file.log, 'l_login_url - ' || l_login_url);
      fnd_file.put_line(fnd_file.log, 'l_user_name - ' || l_user_name);
      fnd_file.put_line(fnd_file.log, 'l_password - ' || l_password);
      fnd_file.put_line(fnd_file.log,
                        'l_file_location - ' || l_file_location);
      fnd_file.put_line(fnd_file.log, 'l_file_name - ' || l_file_name);
    
      -- send the file created by FTP to the url decided
      l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                                 program     => 'XXFTP',
                                                 argument1   => l_login_url,
                                                 argument2   => l_user_name,
                                                 argument3   => l_password,
                                                 argument4   => l_file_location,
                                                 argument5   => l_file_name);
      COMMIT;
      fnd_file.put_line(fnd_file.log, 'ftp request id - ' || l_request_id);
      WHILE l_error_flag = FALSE LOOP
        l_count  := l_count + 1;
        l_result := fnd_concurrent.wait_for_request(l_request_id,
                                                    5,
                                                    86400,
                                                    l_phase,
                                                    l_status,
                                                    l_dev_phase,
                                                    l_dev_status,
                                                    l_message);
      
        IF (l_dev_phase = 'COMPLETE' AND l_dev_status = 'NORMAL') THEN
          l_error_flag := TRUE;
          retcode      := 0;
        ELSIF (l_dev_phase = 'COMPLETE' AND l_dev_status <> 'NORMAL') THEN
          l_error_flag := TRUE;
          retcode      := 1;
          fnd_file.put_line(fnd_file.log,
                            'Request finished in error or warrning, did not transfer file. - ' ||
                            l_message);
        END IF; -- dev_phase
      END LOOP; -- l_error_flag
    
    END IF; -- l_count1
  
  EXCEPTION
    WHEN OTHERS THEN
      retcode := 2;
      errbuf  := 'Procedure account_ftp failed' || substr(SQLERRM, 1, 240);
      fnd_file.put_line(fnd_file.log,
                        'Procedure account_ftp failed - ' || SQLERRM);
      dbms_output.put_line('Procedure account_ftp failed - ' ||
                           substr(SQLERRM, 1, 240));
  END account_ftp;

  --------------------------------------------------------------------
  --  name:            sn_ftp
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   15/01/2013
  --------------------------------------------------------------------
  --  purpose :        transfer sn information of GAM
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  15/01/2013  Dalit A. Raviv    initial build
  --  1.1  25/07/2013  yuval tal         CR 797 : add default values to xml fields
  --------------------------------------------------------------------
  PROCEDURE machine_ftp(errbuf OUT VARCHAR2, retcode OUT VARCHAR2) IS
  
    CURSOR sn_c IS
      SELECT party_id,
             htf.escape_sc(printer_description) printer_description,
             serial_number,
             htf.escape_sc(sn.address) address
        FROM xxhz_gam_site_sn_parties_v sn;
  
    l_file_name    VARCHAR2(150) := NULL;
    l_file_handler utl_file.file_type;
    l_user_name    VARCHAR2(150);
    l_password     VARCHAR2(150);
    l_login_url    VARCHAR2(150);
    l_err_code     VARCHAR2(150);
    l_err_desc     VARCHAR2(150);
  
    l_file_location VARCHAR2(240) := NULL;
    l_request_id    NUMBER;
    l_error_flag    BOOLEAN := FALSE;
    l_count         NUMBER := 0;
    l_phase         VARCHAR2(20);
    l_status        VARCHAR2(20);
    l_dev_phase     VARCHAR2(20);
    l_dev_status    VARCHAR2(20);
    l_message       VARCHAR2(100);
    l_result        BOOLEAN;
    l_count1        NUMBER := 0;
  BEGIN
    errbuf  := NULL;
    retcode := 0;
    -- check that there is data to transfer
    SELECT COUNT(1) INTO l_count1 FROM xxhz_gam_site_sn_parties_v;
  
    IF l_count1 = 0 THEN
      fnd_file.put_line(fnd_file.log, 'There is no data to transfer');
      dbms_output.put_line('There is no data to transfer');
    ELSE
      l_file_name     := get_file_name('SN');
      l_file_location := get_file_location;
      -- open new file with the for account data
      l_file_handler := utl_file.fopen(location  => l_file_location,
                                       filename  => l_file_name,
                                       open_mode => 'w');
    
      -- start write to the file
      utl_file.put_line(file   => l_file_handler,
                        buffer => '<?xml version="1.0" encoding="utf-8" ?>');
    
      utl_file.put_line(file   => l_file_handler,
                        buffer => '<Machines xmlns="http://tempuri.org/GAMMinisite">');
    
      -- by loop add the tags and information
      FOR sn_r IN sn_c LOOP
        BEGIN
          utl_file.put_line(file => l_file_handler, buffer => '<Machine>');
          utl_file.put_line(file   => l_file_handler,
                            buffer => '<PartyID>' ||
                                      nvl(sn_r.party_id, g_default_number) ||
                                      '</PartyID>');
          utl_file.put_line(file   => l_file_handler,
                            buffer => '<MachineDescription>' ||
                                      nvl(sn_r.printer_description,
                                          g_default_varchar) ||
                                      '</MachineDescription>');
          utl_file.put_line(file   => l_file_handler,
                            buffer => '<SerialNumber>' ||
                                      nvl(sn_r.serial_number,
                                          g_default_varchar) ||
                                      '</SerialNumber>');
          utl_file.put_line(file   => l_file_handler,
                            buffer => '<Address>' ||
                                      nvl(sn_r.address, g_default_varchar) ||
                                      '</Address>');
          utl_file.put_line(file => l_file_handler, buffer => '</Machine>');
        EXCEPTION
          WHEN utl_file.invalid_mode THEN
            fnd_file.put_line(fnd_file.log,
                              'The open_mode parameter in FOPEN is invalid');
            dbms_output.put_line('The open_mode parameter in FOPEN is invalid');
            errbuf  := 1;
            retcode := 'UTL_FILE Error';
          WHEN utl_file.invalid_path THEN
            fnd_file.put_line(fnd_file.log,
                              'Specified path does not exist or is not visible to Oracle');
            dbms_output.put_line('Specified path does not exist or is not visible to Oracle');
            errbuf  := 1;
            retcode := 'UTL_FILE Error';
          WHEN utl_file.invalid_filehandle THEN
            fnd_file.put_line(fnd_file.log, 'File handle does not exist');
            dbms_output.put_line('File handle does not exist');
            errbuf  := 1;
            retcode := 'UTL_FILE Error';
          WHEN utl_file.internal_error THEN
            fnd_file.put_line(fnd_file.log,
                              'Unhandled internal error in the UTL_FILE package');
            dbms_output.put_line('Unhandled internal error in the UTL_FILE package');
            errbuf  := 1;
            retcode := 'UTL_FILE Error';
          WHEN utl_file.file_open THEN
            fnd_file.put_line(fnd_file.log, 'File is already open');
            dbms_output.put_line('File is already open');
            errbuf  := 1;
            retcode := 'UTL_FILE Error';
          WHEN utl_file.invalid_maxlinesize THEN
            fnd_file.put_line(fnd_file.log,
                              'The MAX_LINESIZE value for FOPEN() is invalid; it should be within the range 1 to 32767');
            dbms_output.put_line('The MAX_LINESIZE value for FOPEN() is invalid; it should be within the range 1 to 32767');
            errbuf  := 1;
            retcode := 'UTL_FILE Error';
          WHEN utl_file.invalid_operation THEN
            fnd_file.put_line(fnd_file.log,
                              'File could not be opened or operated on as requested');
            dbms_output.put_line('File could not be opened or operated on as requested');
            errbuf  := 1;
            retcode := 'UTL_FILE Error';
          WHEN utl_file.write_error THEN
            fnd_file.put_line(fnd_file.log, 'Unable to write to file');
            dbms_output.put_line('Unable to write to file');
            errbuf  := 1;
            retcode := 'UTL_FILE Error';
          WHEN utl_file.access_denied THEN
            fnd_file.put_line(fnd_file.log,
                              'Access to the file has been denied by the operating system');
            dbms_output.put_line('Access to the file has been denied by the operating system');
            errbuf  := 1;
            retcode := 'UTL_FILE Error';
          WHEN OTHERS THEN
            fnd_file.put_line(fnd_file.log, 'Unknown UTL_FILE Error');
            dbms_output.put_line('Unknown UTL_FILE Error - ' || SQLERRM);
            errbuf  := 1;
            retcode := 'UTL_FILE Error';
        END;
      END LOOP; -- write to file
      -- add closing tag
      utl_file.put_line(file => l_file_handler, buffer => '</Machines>');
      -- close the created file
      utl_file.fclose(file => l_file_handler);
    
      -- get ftp login details
      get_ftp_login_details(p_login_url => l_login_url, -- o v  -- ftp.2objet.com
                            p_user      => l_user_name, -- o v  -- gamsitewrite
                            p_password  => l_password, -- o v  -- Ssyswrite123
                            p_err_code  => l_err_code, -- o v
                            p_err_desc  => l_err_desc); -- o v
    
      fnd_file.put_line(fnd_file.log, 'l_login_url - ' || l_login_url);
      fnd_file.put_line(fnd_file.log, 'l_user_name - ' || l_user_name);
      fnd_file.put_line(fnd_file.log, 'l_password - ' || l_password);
      fnd_file.put_line(fnd_file.log,
                        'l_file_location - ' || l_file_location);
      fnd_file.put_line(fnd_file.log, 'l_file_name - ' || l_file_name);
    
      -- send the file created by FTP to the url decided
      l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                                 program     => 'XXFTP',
                                                 argument1   => l_login_url,
                                                 argument2   => l_user_name,
                                                 argument3   => l_password,
                                                 argument4   => l_file_location,
                                                 argument5   => l_file_name);
      COMMIT;
      fnd_file.put_line(fnd_file.log, 'ftp request id - ' || l_request_id);
      WHILE l_error_flag = FALSE LOOP
        l_count  := l_count + 1;
        l_result := fnd_concurrent.wait_for_request(l_request_id,
                                                    5,
                                                    86400,
                                                    l_phase,
                                                    l_status,
                                                    l_dev_phase,
                                                    l_dev_status,
                                                    l_message);
      
        IF (l_dev_phase = 'COMPLETE' AND l_dev_status = 'NORMAL') THEN
          l_error_flag := TRUE;
          retcode      := 0;
        ELSIF (l_dev_phase = 'COMPLETE' AND l_dev_status <> 'NORMAL') THEN
          l_error_flag := TRUE;
          retcode      := 1;
          fnd_file.put_line(fnd_file.log,
                            'Request finished in error or warrning, did not transfer file. - ' ||
                            l_message);
        END IF; -- dev_phase
      END LOOP; -- l_error_flag
    
    END IF; -- l_count1
  EXCEPTION
    WHEN OTHERS THEN
      retcode := 2;
      errbuf  := 'Procedure sn_ftp failed' || substr(SQLERRM, 1, 240);
      fnd_file.put_line(fnd_file.log,
                        'Procedure sn_ftp failed - ' || SQLERRM);
      dbms_output.put_line('Procedure sn_ftp failed - ' ||
                           substr(SQLERRM, 1, 240));
  END machine_ftp;

  --------------------------------------------------------------------
  --  name:            period_ftp
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   15/01/2013
  --------------------------------------------------------------------
  --  purpose :        transfer resin period information of GAM
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  15/01/2013  Dalit A. Raviv    initial build
  --  1.1  25/07/2013  yuval tal         CR 797 : add default values to xml fields
  --------------------------------------------------------------------
  PROCEDURE period_ftp(errbuf OUT VARCHAR2, retcode OUT VARCHAR2) IS
  
    CURSOR period_c IS
      SELECT p.parent_party_id,
             p.party_id,
             p.year,
             p.q_period,
             p.kg_per_period,
             p.amount_per_period,
             rtrim(ltrim(p.party_name)) party_name
        FROM apps.xxhz_gam_site_resin_period_v p;
  
    l_file_name    VARCHAR2(150) := NULL;
    l_file_handler utl_file.file_type;
    l_user_name    VARCHAR2(150);
    l_password     VARCHAR2(150);
    l_login_url    VARCHAR2(150);
    l_err_code     VARCHAR2(150);
    l_err_desc     VARCHAR2(150);
  
    l_file_location VARCHAR2(240) := NULL;
    l_request_id    NUMBER;
    l_error_flag    BOOLEAN := FALSE;
    l_count         NUMBER := 0;
    l_phase         VARCHAR2(20);
    l_status        VARCHAR2(20);
    l_dev_phase     VARCHAR2(20);
    l_dev_status    VARCHAR2(20);
    l_message       VARCHAR2(100);
    l_result        BOOLEAN;
    l_temp          NUMBER := 0;
    l_date          DATE := NULL;
    l_year          NUMBER := NULL;
    l_today_year    NUMBER := NULL;
  BEGIN
    errbuf  := NULL;
    retcode := 0;
  
    l_year       := fnd_profile.value('XXHZ_GAM_SITE_RESIN_START_YEAR');
    l_today_year := to_number(to_char(SYSDATE, 'YYYY'));
  
    l_file_name     := get_file_name('PERIOD');
    l_file_location := get_file_location;
    -- open new file with the for account data
    l_file_handler := utl_file.fopen(location  => l_file_location,
                                     filename  => l_file_name,
                                     open_mode => 'w');
  
    -- start write to the file
    utl_file.put_line(file   => l_file_handler,
                      buffer => '<?xml version="1.0" encoding="utf-8" ?>');
  
    utl_file.put_line(file   => l_file_handler,
                      buffer => '<Resins xmlns="http://tempuri.org/GAMMinisite">');
  
    FOR i IN l_year .. l_today_year LOOP
    
      l_date := to_date('31-DEC-' || l_year, 'DD-MON-YYYY');
      SELECT xxcs_session_param.set_session_param_date(l_date, 1)
        INTO l_temp
        FROM dual;
    
      l_year := l_year + 1;
    
      -- by loop add the tags and information
      FOR period_r IN period_c LOOP
        BEGIN
          utl_file.put_line(file => l_file_handler, buffer => '<Value>');
          utl_file.put_line(file   => l_file_handler,
                            buffer => '<PartyID>' ||
                                      nvl(period_r.party_id,
                                          g_default_number) || '</PartyID>');
          utl_file.put_line(file   => l_file_handler,
                            buffer => '<Year>' || nvl(period_r.year, '1900') ||
                                      '</Year>');
          utl_file.put_line(file   => l_file_handler,
                            buffer => '<Quater>' ||
                                      nvl(period_r.q_period, 0) ||
                                      '</Quater>');
          utl_file.put_line(file   => l_file_handler,
                            buffer => '<Quantity>' ||
                                      nvl(period_r.kg_per_period, 0) ||
                                      '</Quantity>');
          utl_file.put_line(file   => l_file_handler,
                            buffer => '<Amount>' ||
                                      nvl(period_r.amount_per_period, 0) ||
                                      '</Amount>');
          utl_file.put_line(file => l_file_handler, buffer => '</Value>');
        EXCEPTION
          WHEN utl_file.invalid_mode THEN
            fnd_file.put_line(fnd_file.log,
                              'The open_mode parameter in FOPEN is invalid');
            dbms_output.put_line('The open_mode parameter in FOPEN is invalid');
            errbuf  := 1;
            retcode := 'UTL_FILE Error';
          WHEN utl_file.invalid_path THEN
            fnd_file.put_line(fnd_file.log,
                              'Specified path does not exist or is not visible to Oracle');
            dbms_output.put_line('Specified path does not exist or is not visible to Oracle');
            errbuf  := 1;
            retcode := 'UTL_FILE Error';
          WHEN utl_file.invalid_filehandle THEN
            fnd_file.put_line(fnd_file.log, 'File handle does not exist');
            dbms_output.put_line('File handle does not exist');
            errbuf  := 1;
            retcode := 'UTL_FILE Error';
          WHEN utl_file.internal_error THEN
            fnd_file.put_line(fnd_file.log,
                              'Unhandled internal error in the UTL_FILE package');
            dbms_output.put_line('Unhandled internal error in the UTL_FILE package');
            errbuf  := 1;
            retcode := 'UTL_FILE Error';
          WHEN utl_file.file_open THEN
            fnd_file.put_line(fnd_file.log, 'File is already open');
            dbms_output.put_line('File is already open');
            errbuf  := 1;
            retcode := 'UTL_FILE Error';
          WHEN utl_file.invalid_maxlinesize THEN
            fnd_file.put_line(fnd_file.log,
                              'The MAX_LINESIZE value for FOPEN() is invalid; it should be within the range 1 to 32767');
            dbms_output.put_line('The MAX_LINESIZE value for FOPEN() is invalid; it should be within the range 1 to 32767');
            errbuf  := 1;
            retcode := 'UTL_FILE Error';
          WHEN utl_file.invalid_operation THEN
            fnd_file.put_line(fnd_file.log,
                              'File could not be opened or operated on as requested');
            dbms_output.put_line('File could not be opened or operated on as requested');
            errbuf  := 1;
            retcode := 'UTL_FILE Error';
          WHEN utl_file.write_error THEN
            fnd_file.put_line(fnd_file.log, 'Unable to write to file');
            dbms_output.put_line('Unable to write to file');
            errbuf  := 1;
            retcode := 'UTL_FILE Error';
          WHEN utl_file.access_denied THEN
            fnd_file.put_line(fnd_file.log,
                              'Access to the file has been denied by the operating system');
            dbms_output.put_line('Access to the file has been denied by the operating system');
            errbuf  := 1;
            retcode := 'UTL_FILE Error';
          WHEN OTHERS THEN
            fnd_file.put_line(fnd_file.log, 'Unknown UTL_FILE Error');
            dbms_output.put_line('Unknown UTL_FILE Error - ' || SQLERRM);
            errbuf  := 1;
            retcode := 'UTL_FILE Error';
        END;
      END LOOP; -- write to file
    END LOOP; -- count years
    -- add closing tag
    utl_file.put_line(file => l_file_handler, buffer => '</Resins>');
    -- close the created file
    utl_file.fclose(file => l_file_handler);
  
    -- get ftp login details
    get_ftp_login_details(p_login_url => l_login_url, -- o v  -- ftp.2objet.com
                          p_user      => l_user_name, -- o v  -- gamsitewrite
                          p_password  => l_password, -- o v  -- Ssyswrite123
                          p_err_code  => l_err_code, -- o v
                          p_err_desc  => l_err_desc); -- o v
  
    fnd_file.put_line(fnd_file.log, 'l_login_url - ' || l_login_url);
    fnd_file.put_line(fnd_file.log, 'l_user_name - ' || l_user_name);
    fnd_file.put_line(fnd_file.log, 'l_password - ' || l_password);
    fnd_file.put_line(fnd_file.log,
                      'l_file_location - ' || l_file_location);
    fnd_file.put_line(fnd_file.log, 'l_file_name - ' || l_file_name);
  
    -- send the file created by FTP to the url decided
    l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                               program     => 'XXFTP',
                                               argument1   => l_login_url,
                                               argument2   => l_user_name,
                                               argument3   => l_password,
                                               argument4   => l_file_location,
                                               argument5   => l_file_name);
    COMMIT;
    fnd_file.put_line(fnd_file.log, 'ftp request id - ' || l_request_id);
    WHILE l_error_flag = FALSE LOOP
      l_count  := l_count + 1;
      l_result := fnd_concurrent.wait_for_request(l_request_id,
                                                  5,
                                                  86400,
                                                  l_phase,
                                                  l_status,
                                                  l_dev_phase,
                                                  l_dev_status,
                                                  l_message);
    
      IF (l_dev_phase = 'COMPLETE' AND l_dev_status = 'NORMAL') THEN
        l_error_flag := TRUE;
        retcode      := 0;
      ELSIF (l_dev_phase = 'COMPLETE' AND l_dev_status <> 'NORMAL') THEN
        l_error_flag := TRUE;
        retcode      := 1;
        fnd_file.put_line(fnd_file.log,
                          'Request finished in error or warrning, did not transfer file. - ' ||
                          l_message);
      END IF; -- dev_phase
    END LOOP; -- l_error_flag
  
  EXCEPTION
    WHEN OTHERS THEN
      retcode := 2;
      errbuf  := 'Procedure period_ftp failed' || substr(SQLERRM, 1, 240);
      fnd_file.put_line(fnd_file.log,
                        'Procedure period_ftp failed - ' || SQLERRM);
      dbms_output.put_line('Procedure period_ftp failed - ' ||
                           substr(SQLERRM, 1, 240));
  END period_ftp;

  --------------------------------------------------------------------
  --  name:            product_ftp
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   15/01/2013
  --------------------------------------------------------------------
  --  purpose :        transfer resin product information of GAM
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  15/01/2013  Dalit A. Raviv    initial build
  --  1.1  25/07/2013  yuval tal         CR 797 : add default values to xml fields
  --------------------------------------------------------------------
  PROCEDURE product_ftp(errbuf OUT VARCHAR2, retcode OUT VARCHAR2) IS
  
    CURSOR product_c IS
      SELECT p.segment1,
             htf.escape_sc(p.description) description,
             p.party_id
        FROM apps.xxhz_gam_site_resin_product_v p;
  
    l_file_name    VARCHAR2(150) := NULL;
    l_file_handler utl_file.file_type;
    l_user_name    VARCHAR2(150);
    l_password     VARCHAR2(150);
    l_login_url    VARCHAR2(150);
    l_err_code     VARCHAR2(150);
    l_err_desc     VARCHAR2(150);
  
    l_file_location VARCHAR2(240) := NULL;
    l_request_id    NUMBER;
    l_error_flag    BOOLEAN := FALSE;
    l_count         NUMBER := 0;
    l_phase         VARCHAR2(20);
    l_status        VARCHAR2(20);
    l_dev_phase     VARCHAR2(20);
    l_dev_status    VARCHAR2(20);
    l_message       VARCHAR2(100);
    l_result        BOOLEAN;
    l_temp          NUMBER := 0;
    l_date          DATE := NULL;
    l_year          NUMBER := NULL;
    l_today_year    NUMBER := NULL;
  BEGIN
    errbuf  := NULL;
    retcode := 0;
  
    --l_year       := fnd_profile.VALUE('XXHZ_GAM_SITE_RESIN_START_YEAR');
    l_today_year := to_number(to_char(SYSDATE, 'YYYY'));
    l_year       := l_today_year - 2;
  
    l_file_name     := get_file_name('PRODUCT');
    l_file_location := get_file_location;
    -- open new file with the for account data
    l_file_handler := utl_file.fopen(location  => l_file_location,
                                     filename  => l_file_name,
                                     open_mode => 'w');
  
    -- start write to the file
    utl_file.put_line(file   => l_file_handler,
                      buffer => '<?xml version="1.0" encoding="utf-8" ?>');
  
    utl_file.put_line(file   => l_file_handler,
                      buffer => '<Products xmlns="http://tempuri.org/GAMMinisite">');
  
    FOR i IN l_year .. l_today_year LOOP
    
      l_date := to_date('31-DEC-' || l_year, 'DD-MON-YYYY');
      SELECT xxcs_session_param.set_session_param_date(l_date, 1)
        INTO l_temp
        FROM dual;
    
      l_year := l_year + 1;
    
      -- by loop add the tags and information
      FOR product_r IN product_c LOOP
        BEGIN
          utl_file.put_line(file => l_file_handler, buffer => '<Product>');
          utl_file.put_line(file   => l_file_handler,
                            buffer => '<PartyID>' ||
                                      nvl(product_r.party_id,
                                          g_default_number) || '</PartyID>');
          utl_file.put_line(file   => l_file_handler,
                            buffer => '<ProductID>' || product_r.segment1 ||
                                      '</ProductID>');
          utl_file.put_line(file   => l_file_handler,
                            buffer => '<ProductName>' ||
                                      nvl(product_r.description,
                                          g_default_varchar) ||
                                      '</ProductName>');
          utl_file.put_line(file => l_file_handler, buffer => '</Product>');
        EXCEPTION
          WHEN utl_file.invalid_mode THEN
            fnd_file.put_line(fnd_file.log,
                              'The open_mode parameter in FOPEN is invalid');
            dbms_output.put_line('The open_mode parameter in FOPEN is invalid');
            errbuf  := 1;
            retcode := 'UTL_FILE Error';
          WHEN utl_file.invalid_path THEN
            fnd_file.put_line(fnd_file.log,
                              'Specified path does not exist or is not visible to Oracle');
            dbms_output.put_line('Specified path does not exist or is not visible to Oracle');
            errbuf  := 1;
            retcode := 'UTL_FILE Error';
          WHEN utl_file.invalid_filehandle THEN
            fnd_file.put_line(fnd_file.log, 'File handle does not exist');
            dbms_output.put_line('File handle does not exist');
            errbuf  := 1;
            retcode := 'UTL_FILE Error';
          WHEN utl_file.internal_error THEN
            fnd_file.put_line(fnd_file.log,
                              'Unhandled internal error in the UTL_FILE package');
            dbms_output.put_line('Unhandled internal error in the UTL_FILE package');
            errbuf  := 1;
            retcode := 'UTL_FILE Error';
          WHEN utl_file.file_open THEN
            fnd_file.put_line(fnd_file.log, 'File is already open');
            dbms_output.put_line('File is already open');
            errbuf  := 1;
            retcode := 'UTL_FILE Error';
          WHEN utl_file.invalid_maxlinesize THEN
            fnd_file.put_line(fnd_file.log,
                              'The MAX_LINESIZE value for FOPEN() is invalid; it should be within the range 1 to 32767');
            dbms_output.put_line('The MAX_LINESIZE value for FOPEN() is invalid; it should be within the range 1 to 32767');
            errbuf  := 1;
            retcode := 'UTL_FILE Error';
          WHEN utl_file.invalid_operation THEN
            fnd_file.put_line(fnd_file.log,
                              'File could not be opened or operated on as requested');
            dbms_output.put_line('File could not be opened or operated on as requested');
            errbuf  := 1;
            retcode := 'UTL_FILE Error';
          WHEN utl_file.write_error THEN
            fnd_file.put_line(fnd_file.log, 'Unable to write to file');
            dbms_output.put_line('Unable to write to file');
            errbuf  := 1;
            retcode := 'UTL_FILE Error';
          WHEN utl_file.access_denied THEN
            fnd_file.put_line(fnd_file.log,
                              'Access to the file has been denied by the operating system');
            dbms_output.put_line('Access to the file has been denied by the operating system');
            errbuf  := 1;
            retcode := 'UTL_FILE Error';
          WHEN OTHERS THEN
            fnd_file.put_line(fnd_file.log, 'Unknown UTL_FILE Error');
            dbms_output.put_line('Unknown UTL_FILE Error - ' || SQLERRM);
            errbuf  := 1;
            retcode := 'UTL_FILE Error';
        END;
      END LOOP; -- write to file
    END LOOP; -- count years
    -- add closing tag
    utl_file.put_line(file => l_file_handler, buffer => '</Products>');
    -- close the created file
    utl_file.fclose(file => l_file_handler);
  
    -- get ftp login details
    get_ftp_login_details(p_login_url => l_login_url, -- o v  -- ftp.2objet.com
                          p_user      => l_user_name, -- o v  -- gamsitewrite
                          p_password  => l_password, -- o v  -- Ssyswrite123
                          p_err_code  => l_err_code, -- o v
                          p_err_desc  => l_err_desc); -- o v
  
    fnd_file.put_line(fnd_file.log, 'l_login_url - ' || l_login_url);
    fnd_file.put_line(fnd_file.log, 'l_user_name - ' || l_user_name);
    fnd_file.put_line(fnd_file.log, 'l_password - ' || l_password);
    fnd_file.put_line(fnd_file.log,
                      'l_file_location - ' || l_file_location);
    fnd_file.put_line(fnd_file.log, 'l_file_name - ' || l_file_name);
  
    -- send the file created by FTP to the url decided
    l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                               program     => 'XXFTP',
                                               argument1   => l_login_url,
                                               argument2   => l_user_name,
                                               argument3   => l_password,
                                               argument4   => l_file_location,
                                               argument5   => l_file_name);
    COMMIT;
    fnd_file.put_line(fnd_file.log, 'ftp request id - ' || l_request_id);
    WHILE l_error_flag = FALSE LOOP
      l_count  := l_count + 1;
      l_result := fnd_concurrent.wait_for_request(l_request_id,
                                                  5,
                                                  86400,
                                                  l_phase,
                                                  l_status,
                                                  l_dev_phase,
                                                  l_dev_status,
                                                  l_message);
    
      IF (l_dev_phase = 'COMPLETE' AND l_dev_status = 'NORMAL') THEN
        l_error_flag := TRUE;
        retcode      := 0;
      ELSIF (l_dev_phase = 'COMPLETE' AND l_dev_status <> 'NORMAL') THEN
        l_error_flag := TRUE;
        retcode      := 1;
        fnd_file.put_line(fnd_file.log,
                          'Request finished in error or warrning, did not transfer file. - ' ||
                          l_message);
      END IF; -- dev_phase
    END LOOP; -- l_error_flag
  
  EXCEPTION
    WHEN OTHERS THEN
      retcode := 2;
      errbuf  := 'Procedure product_ftp failed' || substr(SQLERRM, 1, 240);
      fnd_file.put_line(fnd_file.log,
                        'Procedure product_ftp failed - ' || SQLERRM);
      dbms_output.put_line('Procedure product_ftp failed - ' ||
                           substr(SQLERRM, 1, 240));
  END product_ftp;

  --------------------------------------------------------------------
  --  name:            rebate_ftp
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   16/01/2013
  --------------------------------------------------------------------
  --  purpose :        transfer reabate information of GAM
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16/01/2013  Dalit A. Raviv    initial build
  --  1.1  28/02/2013  Dalit A. Raviv    correct the use of session param.
  --  1.2  17/03/2013  Adi Safin         Estimate need to run over today date instead of cur_year_last_day
  --  1.3  09/05/2013  Dalit A. Raviv    GAM dashboard - modify the estimate rebate date for the end of the year
  --  1.4  25/07/2013  yuval tal         CR 797 : add default values to xml fields
  --------------------------------------------------------------------
  PROCEDURE rebate_ftp(errbuf OUT VARCHAR2, retcode OUT VARCHAR2) IS
  
    CURSOR parent_c IS
      SELECT DISTINCT v.parent_party_id,
                      rtrim(ltrim(xxhz_party_ga_util.get_party_name(v.parent_party_id))) parent_party_name
        FROM xxhz_party_ga_v v;
  
    CURSOR today_c(p_parent_party_id IN NUMBER) IS
      SELECT reb.parent_party_id,
             round(reb.total_ga_kg) currentconsumption,
             --reb.parent_party_name,
             round(SUM(reb.rebate)) rebate_usd,
             to_char(xxcs_session_param.get_session_param_date(1),
                     'YYYY-MM-DD') current_rebate_date /*'DD-MON-YYYY'*/
        FROM xxhz_party_ga_rebate_v reb
       WHERE reb.parent_party_id = p_parent_party_id
       GROUP BY reb.parent_party_id, --reb.parent_party_name,
                round(reb.total_ga_kg),
                to_char(xxcs_session_param.get_session_param_date(1),
                        'YYYY-MM-DD');
  
    CURSOR prev_year_c(p_parent_party_id IN NUMBER) IS
      SELECT reb.parent_party_id,
             --reb.parent_party_name,
             round(SUM(reb.rebate)) rebate_usd,
             to_char(xxcs_session_param.get_session_param_date(1),
                     'YYYY-MM-DD') current_rebate_date
        FROM xxhz_party_ga_rebate_v reb
       WHERE reb.parent_party_id = p_parent_party_id
       GROUP BY reb.parent_party_id, --reb.parent_party_name,
                to_char(xxcs_session_param.get_session_param_date(1),
                        'YYYY-MM-DD');
  
    CURSOR cur_year_c(p_parent_party_id IN NUMBER) IS
      SELECT reb.parent_party_id,
             --reb.parent_party_name,
             round(SUM(reb.year_rebate)) estmate_rebate_usd,
             to_char(xxcs_session_param.get_session_param_date(1),
                     'YYYY-MM-DD') current_rebate_date
        FROM xxhz_party_ga_rebate_v reb
       WHERE reb.parent_party_id = p_parent_party_id
       GROUP BY reb.parent_party_id,
                --reb.parent_party_name,
                to_char(xxcs_session_param.get_session_param_date(1),
                        'YYYY-MM-DD');
  
    l_file_name    VARCHAR2(150) := NULL;
    l_file_handler utl_file.file_type;
    l_user_name    VARCHAR2(150);
    l_password     VARCHAR2(150);
    l_login_url    VARCHAR2(150);
    l_err_code     VARCHAR2(150);
    l_err_desc     VARCHAR2(150);
  
    l_file_location VARCHAR2(240) := NULL;
    l_request_id    NUMBER;
    l_error_flag    BOOLEAN := FALSE;
    l_count         NUMBER := 0;
    l_phase         VARCHAR2(20);
    l_status        VARCHAR2(20);
    l_dev_phase     VARCHAR2(20);
    l_dev_status    VARCHAR2(20);
    l_message       VARCHAR2(100);
    l_result        BOOLEAN;
    l_count1        NUMBER;
  
    l_temp1 NUMBER := NULL;
    --l_temp2          number        := null;
    --l_temp3          number        := null;
    l_today              DATE := NULL;
    l_prev_year_last_day DATE := NULL;
    l_cur_year_last_day  DATE := NULL;
  BEGIN
    errbuf  := NULL;
    retcode := 0;
  
    -- Set session param
    l_today              := trunc(SYSDATE);
    l_prev_year_last_day := (trunc(SYSDATE, 'YYYY') - 1);
    l_cur_year_last_day  := (add_months(trunc(SYSDATE, 'YYYY'), 12) - 1);
    /* 1.1  28/02/2013  Dalit A. Raviv
    select XXCS_SESSION_PARAM.set_session_param_date(l_today,1),
           XXCS_SESSION_PARAM.set_session_param_date(l_prev_year_last_day,2),
           XXCS_SESSION_PARAM.set_session_param_date(l_cur_year_last_day,3)
    into   l_temp1, l_temp2, l_temp3
    from   dual;
    */
    l_file_name     := get_file_name('REBATE');
    l_file_location := get_file_location;
    -- open new file with the for account data
    l_file_handler := utl_file.fopen(location  => l_file_location,
                                     filename  => l_file_name,
                                     open_mode => 'w');
  
    -- start write to the file
    utl_file.put_line(file   => l_file_handler,
                      buffer => '<?xml version="1.0" encoding="utf-8" ?>');
  
    utl_file.put_line(file   => l_file_handler,
                      buffer => '<Rebates xmlns="http://tempuri.org/GAMMinisite">');
  
    FOR parent_r IN parent_c LOOP
      -- by loop add the tags and information
      BEGIN
        utl_file.put_line(file => l_file_handler, buffer => '<Rebate>');
        utl_file.put_line(file   => l_file_handler,
                          buffer => '<ParentPartyID>' ||
                                    nvl(parent_r.parent_party_id,
                                        g_default_number) ||
                                    '</ParentPartyID>');
        --utl_file.put_line (file   => l_file_handler,
        --                   buffer => '<PARENT_PARTY_NAME>'||parent_r.parent_party_name||'</PARENT_PARTY_NAME>');
        -- Today information
        l_count1 := 0;
        -- 1.1 28/02/2013 Dalit A. Raviv
        -- Set session param for today
        SELECT xxcs_session_param.set_session_param_date(l_today, 1)
          INTO l_temp1
          FROM dual;
      
        FOR today_r IN today_c(parent_r.parent_party_id) LOOP
          l_count1 := l_count1 + 1;
          utl_file.put_line(file   => l_file_handler,
                            buffer => '<CurrentConsumption>' ||
                                      nvl(today_r.currentconsumption, 0) ||
                                      '</CurrentConsumption>');
          utl_file.put_line(file   => l_file_handler,
                            buffer => '<CurrentValue>' ||
                                      nvl(today_r.rebate_usd, 0) ||
                                      '</CurrentValue>');
          utl_file.put_line(file   => l_file_handler,
                            buffer => '<CurrentDate>' ||
                                      nvl(today_r.current_rebate_date,
                                          g_default_date) ||
                                      '</CurrentDate>');
        END LOOP; -- today information
        IF l_count1 = 0 THEN
          utl_file.put_line(file   => l_file_handler,
                            buffer => '<CurrentConsumption>' || 0 ||
                                      '</CurrentConsumption>');
          utl_file.put_line(file   => l_file_handler,
                            buffer => '<CurrentValue>' || '0' ||
                                      '</CurrentValue>');
          utl_file.put_line(file   => l_file_handler,
                            buffer => '<CurrentDate>' ||
                                      to_char(l_today, 'YYYY-MM-DD') ||
                                      '</CurrentDate>');
        ELSE
          l_count1 := 0;
        END IF;
      
        -- 1.1 28/02/2013 Dalit A. Raviv
        -- Set session param for pervious year
        SELECT xxcs_session_param.set_session_param_date(l_prev_year_last_day,
                                                         1)
          INTO l_temp1
          FROM dual;
      
        -- Prev year information
        FOR prev_year_r IN prev_year_c(parent_r.parent_party_id) LOOP
          l_count1 := l_count1 + 1;
          utl_file.put_line(file   => l_file_handler,
                            buffer => '<LastYearValue>' ||
                                      nvl(prev_year_r.rebate_usd, 0) ||
                                      '</LastYearValue>');
          utl_file.put_line(file   => l_file_handler,
                            buffer => '<LastYearDate>' ||
                                      nvl(prev_year_r.current_rebate_date,
                                          g_default_date) ||
                                      '</LastYearDate>');
        END LOOP;
        IF l_count1 = 0 THEN
          utl_file.put_line(file   => l_file_handler,
                            buffer => '<LastYearValue>' || '0' ||
                                      '</LastYearValue>');
          utl_file.put_line(file   => l_file_handler,
                            buffer => '<LastYearDate>' ||
                                      nvl(to_char(l_prev_year_last_day,
                                                  'YYYY-MM-DD'),
                                          g_default_date) ||
                                      '</LastYearDate>');
        ELSE
          l_count1 := 0;
        END IF;
        -- 1.1 28/02/2013 Dalit A. Raviv
        -- Set session param for current year last day.
        -- 1.2 17/03/2013 Adi Safin
        -- estimate need to run over today date instead of "cur year last day"
        SELECT xxcs_session_param.set_session_param_date(l_today, 1)
          INTO l_temp1
          FROM dual;
      
        -- Curr year information
        --  1.3  09/05/2013  Dalit A. Raviv
        FOR cur_year_r IN cur_year_c(parent_r.parent_party_id) LOOP
          l_count1 := l_count1 + 1;
          utl_file.put_line(file   => l_file_handler,
                            buffer => '<EstimatedValue>' ||
                                      nvl(cur_year_r.estmate_rebate_usd, 0) ||
                                      '</EstimatedValue>');
          utl_file.put_line(file   => l_file_handler,
                            buffer => '<EstimatedDate>' || /*cur_year_r.current_rebate_date*/
                                      nvl(to_char(l_cur_year_last_day,
                                                  'YYYY-MM-DD'),
                                          g_default_date) ||
                                      '</EstimatedDate>'); ----------
        END LOOP;
        IF l_count1 = 0 THEN
          utl_file.put_line(file   => l_file_handler,
                            buffer => '<EstimatedValue>' || '0' ||
                                      '</EstimatedValue>');
          utl_file.put_line(file   => l_file_handler,
                            buffer => '<EstimatedDate>' ||
                                      nvl(to_char(l_cur_year_last_day,
                                                  'YYYY-MM-DD'),
                                          g_default_date) ||
                                      '</EstimatedDate>');
        ELSE
          l_count1 := 0;
        END IF;
      
        utl_file.put_line(file => l_file_handler, buffer => '</Rebate>');
      EXCEPTION
        WHEN utl_file.invalid_mode THEN
          fnd_file.put_line(fnd_file.log,
                            'The open_mode parameter in FOPEN is invalid');
          dbms_output.put_line('The open_mode parameter in FOPEN is invalid');
          errbuf  := 1;
          retcode := 'UTL_FILE Error';
        WHEN utl_file.invalid_path THEN
          fnd_file.put_line(fnd_file.log,
                            'Specified path does not exist or is not visible to Oracle');
          dbms_output.put_line('Specified path does not exist or is not visible to Oracle');
          errbuf  := 1;
          retcode := 'UTL_FILE Error';
        WHEN utl_file.invalid_filehandle THEN
          fnd_file.put_line(fnd_file.log, 'File handle does not exist');
          dbms_output.put_line('File handle does not exist');
          errbuf  := 1;
          retcode := 'UTL_FILE Error';
        WHEN utl_file.internal_error THEN
          fnd_file.put_line(fnd_file.log,
                            'Unhandled internal error in the UTL_FILE package');
          dbms_output.put_line('Unhandled internal error in the UTL_FILE package');
          errbuf  := 1;
          retcode := 'UTL_FILE Error';
        WHEN utl_file.file_open THEN
          fnd_file.put_line(fnd_file.log, 'File is already open');
          dbms_output.put_line('File is already open');
          errbuf  := 1;
          retcode := 'UTL_FILE Error';
        WHEN utl_file.invalid_maxlinesize THEN
          fnd_file.put_line(fnd_file.log,
                            'The MAX_LINESIZE value for FOPEN() is invalid; it should be within the range 1 to 32767');
          dbms_output.put_line('The MAX_LINESIZE value for FOPEN() is invalid; it should be within the range 1 to 32767');
          errbuf  := 1;
          retcode := 'UTL_FILE Error';
        WHEN utl_file.invalid_operation THEN
          fnd_file.put_line(fnd_file.log,
                            'File could not be opened or operated on as requested');
          dbms_output.put_line('File could not be opened or operated on as requested');
          errbuf  := 1;
          retcode := 'UTL_FILE Error';
        WHEN utl_file.write_error THEN
          fnd_file.put_line(fnd_file.log, 'Unable to write to file');
          dbms_output.put_line('Unable to write to file');
          errbuf  := 1;
          retcode := 'UTL_FILE Error';
        WHEN utl_file.access_denied THEN
          fnd_file.put_line(fnd_file.log,
                            'Access to the file has been denied by the operating system');
          dbms_output.put_line('Access to the file has been denied by the operating system');
          errbuf  := 1;
          retcode := 'UTL_FILE Error';
        WHEN OTHERS THEN
          fnd_file.put_line(fnd_file.log, 'Unknown UTL_FILE Error');
          dbms_output.put_line('Unknown UTL_FILE Error - ' || SQLERRM);
          errbuf  := 1;
          retcode := 'UTL_FILE Error';
      END;
    END LOOP; -- parent
    -- add closing tag
    utl_file.put_line(file => l_file_handler, buffer => '</Rebates>');
    -- close the created file
    utl_file.fclose(file => l_file_handler);
  
    -- get ftp login details
    get_ftp_login_details(p_login_url => l_login_url, -- o v  -- ftp.2objet.com
                          p_user      => l_user_name, -- o v  -- gamsitewrite
                          p_password  => l_password, -- o v  -- Ssyswrite123
                          p_err_code  => l_err_code, -- o v
                          p_err_desc  => l_err_desc); -- o v
  
    fnd_file.put_line(fnd_file.log, 'l_login_url - ' || l_login_url);
    fnd_file.put_line(fnd_file.log, 'l_user_name - ' || l_user_name);
    fnd_file.put_line(fnd_file.log, 'l_password - ' || l_password);
    fnd_file.put_line(fnd_file.log,
                      'l_file_location - ' || l_file_location);
    fnd_file.put_line(fnd_file.log, 'l_file_name - ' || l_file_name);
  
    -- send the file created by FTP to the url decided
    l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                               program     => 'XXFTP',
                                               argument1   => l_login_url,
                                               argument2   => l_user_name,
                                               argument3   => l_password,
                                               argument4   => l_file_location,
                                               argument5   => l_file_name);
    COMMIT;
    fnd_file.put_line(fnd_file.log, 'ftp request id - ' || l_request_id);
    WHILE l_error_flag = FALSE LOOP
      l_count  := l_count + 1;
      l_result := fnd_concurrent.wait_for_request(l_request_id,
                                                  5,
                                                  86400,
                                                  l_phase,
                                                  l_status,
                                                  l_dev_phase,
                                                  l_dev_status,
                                                  l_message);
    
      IF (l_dev_phase = 'COMPLETE' AND l_dev_status = 'NORMAL') THEN
        l_error_flag := TRUE;
        retcode      := 0;
      ELSIF (l_dev_phase = 'COMPLETE' AND l_dev_status <> 'NORMAL') THEN
        l_error_flag := TRUE;
        retcode      := 1;
        fnd_file.put_line(fnd_file.log,
                          'Request finished in error or warrning, did not transfer file. - ' ||
                          l_message);
      END IF; -- dev_phase
    END LOOP; -- l_error_flag
  
  EXCEPTION
    WHEN OTHERS THEN
      retcode := 2;
      errbuf  := 'Procedure product_ftp failed' || substr(SQLERRM, 1, 240);
      fnd_file.put_line(fnd_file.log,
                        'Procedure product_ftp failed - ' || SQLERRM);
      dbms_output.put_line('Procedure product_ftp failed - ' ||
                           substr(SQLERRM, 1, 240));
  END rebate_ftp;

  --------------------------------------------------------------------
  --  name:            contact_ftp
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   16/01/2013
  --------------------------------------------------------------------
  --  purpose :        transfer reabate information of GAM
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16/01/2013  Dalit A. Raviv    initial build
  --  1.1  28/02/2013  Dalit A. Raviv    population will show only the contct that are primary
  --                                     if none of the contact (phone fax and mobile) is primary
  --                                     bring what you have.
  -- 1.2   09/07/2013  Adi Safin         BUGFIX - Replace value N with Null in order to get contact that is marked as not primary
  -- 1.3  25/07/2013  yuval tal         CR 797 : add default values to xml fields
  --------------------------------------------------------------------
  PROCEDURE contact_ftp(errbuf OUT VARCHAR2, retcode OUT VARCHAR2) IS
    CURSOR con_c IS
      SELECT con.party_id,
             htf.escape_sc(con.contact_address) contact_address,
             con.person_first_name person_first_name,
             con.person_last_name person_last_name,
             htf.escape_sc(con.job_title) job_title,
             con.phone phone,
             con.fax fax,
             con.email_address email_address,
             decode(con.ww_global_main_contact, 'Y', 'true', 'false') ww_global_main_contact,
             decode(con.site_main_contact, 'Y', 'true', 'false') site_main_contact,
             decode(con.gam_contact, 'Y', 'true', 'false') gam_contact
        FROM xxhz_gam_site_cotacts_v con
       WHERE nvl(coalesce(REPLACE(con.phone_primary_flag, 'N', NULL),
                          REPLACE(con.mobile_primary_flag, 'N', NULL),
                          REPLACE(con.fax_primary_flag, 'N', NULL)),
                 'Y') = 'Y'; -- 1.2 Adi Safin
  
    l_file_name    VARCHAR2(150) := NULL;
    l_file_handler utl_file.file_type;
    l_user_name    VARCHAR2(150);
    l_password     VARCHAR2(150);
    l_login_url    VARCHAR2(150);
    l_err_code     VARCHAR2(150);
    l_err_desc     VARCHAR2(150);
  
    l_file_location VARCHAR2(240) := NULL;
    l_request_id    NUMBER;
    l_error_flag    BOOLEAN := FALSE;
    l_count         NUMBER := 0;
    l_phase         VARCHAR2(20);
    l_status        VARCHAR2(20);
    l_dev_phase     VARCHAR2(20);
    l_dev_status    VARCHAR2(20);
    l_message       VARCHAR2(100);
    l_result        BOOLEAN;
    l_count1        NUMBER := 0;
  BEGIN
    errbuf  := NULL;
    retcode := 0;
    -- check that there is data to transfer
    SELECT COUNT(1) INTO l_count1 FROM xxhz_gam_site_cotacts_v;
  
    IF l_count1 = 0 THEN
      fnd_file.put_line(fnd_file.log, 'There is no data to transfer');
      dbms_output.put_line('There is no data to transfer');
    ELSE
      l_file_name     := get_file_name('CONTACT');
      l_file_location := get_file_location;
      -- open new file with the for account data
      l_file_handler := utl_file.fopen(location  => l_file_location,
                                       filename  => l_file_name,
                                       open_mode => 'w');
    
      -- start write to the file
      utl_file.put_line(file   => l_file_handler,
                        buffer => '<?xml version="1.0" encoding="utf-8" ?>');
    
      utl_file.put_line(file   => l_file_handler,
                        buffer => '<UserContacts xmlns="http://tempuri.org/GAMMinisite">');
    
      -- by loop add the tags and information
      FOR con_r IN con_c LOOP
        BEGIN
          utl_file.put_line(file => l_file_handler, buffer => '<Contact>');
          utl_file.put_line(file   => l_file_handler,
                            buffer => '<PartyID>' ||
                                      nvl(con_r.party_id, g_default_number) ||
                                      '</PartyID>');
          utl_file.put_line(file   => l_file_handler,
                            buffer => '<Email>' ||
                                      nvl(con_r.email_address,
                                          g_default_varchar) || '</Email>');
          utl_file.put_line(file   => l_file_handler,
                            buffer => '<Address>' ||
                                      nvl(con_r.contact_address,
                                          g_default_varchar) || '</Address>');
          utl_file.put_line(file   => l_file_handler,
                            buffer => '<FirstName>' ||
                                      nvl(con_r.person_first_name,
                                          g_default_varchar) ||
                                      '</FirstName>');
          utl_file.put_line(file   => l_file_handler,
                            buffer => '<LastName>' ||
                                      nvl(con_r.person_last_name,
                                          g_default_varchar) ||
                                      '</LastName>');
          utl_file.put_line(file   => l_file_handler,
                            buffer => '<JobTitle>' ||
                                      nvl(con_r.job_title, g_default_varchar) ||
                                      '</JobTitle>');
          utl_file.put_line(file   => l_file_handler,
                            buffer => '<Phone>' || con_r.phone || '</Phone>');
          utl_file.put_line(file   => l_file_handler,
                            buffer => '<Fax>' || con_r.fax || '</Fax>');
          utl_file.put_line(file   => l_file_handler,
                            buffer => '<GlobalContact>' ||
                                      nvl(con_r.ww_global_main_contact,
                                          g_default_boolean) ||
                                      '</GlobalContact>');
          utl_file.put_line(file   => l_file_handler,
                            buffer => '<SiteContact>' ||
                                      nvl(con_r.site_main_contact,
                                          g_default_boolean) ||
                                      '</SiteContact>');
          utl_file.put_line(file   => l_file_handler,
                            buffer => '<Contact>' ||
                                      nvl(con_r.gam_contact,
                                          g_default_boolean) || '</Contact>');
          utl_file.put_line(file => l_file_handler, buffer => '</Contact>');
        EXCEPTION
          WHEN utl_file.invalid_mode THEN
            fnd_file.put_line(fnd_file.log,
                              'The open_mode parameter in FOPEN is invalid');
            dbms_output.put_line('The open_mode parameter in FOPEN is invalid');
            errbuf  := 1;
            retcode := 'UTL_FILE Error';
          WHEN utl_file.invalid_path THEN
            fnd_file.put_line(fnd_file.log,
                              'Specified path does not exist or is not visible to Oracle');
            dbms_output.put_line('Specified path does not exist or is not visible to Oracle');
            errbuf  := 1;
            retcode := 'UTL_FILE Error';
          WHEN utl_file.invalid_filehandle THEN
            fnd_file.put_line(fnd_file.log, 'File handle does not exist');
            dbms_output.put_line('File handle does not exist');
            errbuf  := 1;
            retcode := 'UTL_FILE Error';
          WHEN utl_file.internal_error THEN
            fnd_file.put_line(fnd_file.log,
                              'Unhandled internal error in the UTL_FILE package');
            dbms_output.put_line('Unhandled internal error in the UTL_FILE package');
            errbuf  := 1;
            retcode := 'UTL_FILE Error';
          WHEN utl_file.file_open THEN
            fnd_file.put_line(fnd_file.log, 'File is already open');
            dbms_output.put_line('File is already open');
            errbuf  := 1;
            retcode := 'UTL_FILE Error';
          WHEN utl_file.invalid_maxlinesize THEN
            fnd_file.put_line(fnd_file.log,
                              'The MAX_LINESIZE value for FOPEN() is invalid; it should be within the range 1 to 32767');
            dbms_output.put_line('The MAX_LINESIZE value for FOPEN() is invalid; it should be within the range 1 to 32767');
            errbuf  := 1;
            retcode := 'UTL_FILE Error';
          WHEN utl_file.invalid_operation THEN
            fnd_file.put_line(fnd_file.log,
                              'File could not be opened or operated on as requested');
            dbms_output.put_line('File could not be opened or operated on as requested');
            errbuf  := 1;
            retcode := 'UTL_FILE Error';
          WHEN utl_file.write_error THEN
            fnd_file.put_line(fnd_file.log, 'Unable to write to file');
            dbms_output.put_line('Unable to write to file');
            errbuf  := 1;
            retcode := 'UTL_FILE Error';
          WHEN utl_file.access_denied THEN
            fnd_file.put_line(fnd_file.log,
                              'Access to the file has been denied by the operating system');
            dbms_output.put_line('Access to the file has been denied by the operating system');
            errbuf  := 1;
            retcode := 'UTL_FILE Error';
          WHEN OTHERS THEN
            fnd_file.put_line(fnd_file.log, 'Unknown UTL_FILE Error');
            dbms_output.put_line('Unknown UTL_FILE Error - ' || SQLERRM);
            errbuf  := 1;
            retcode := 'UTL_FILE Error';
        END;
      END LOOP; -- write to file
      -- add closing tag
      utl_file.put_line(file   => l_file_handler,
                        buffer => '</UserContacts>');
      -- close the created file
      utl_file.fclose(file => l_file_handler);
    
      -- get ftp login details
      get_ftp_login_details(p_login_url => l_login_url, -- o v  -- ftp.2objet.com
                            p_user      => l_user_name, -- o v  -- gamsitewrite
                            p_password  => l_password, -- o v  -- Ssyswrite123
                            p_err_code  => l_err_code, -- o v
                            p_err_desc  => l_err_desc); -- o v
    
      fnd_file.put_line(fnd_file.log, 'l_login_url - ' || l_login_url);
      fnd_file.put_line(fnd_file.log, 'l_user_name - ' || l_user_name);
      fnd_file.put_line(fnd_file.log, 'l_password - ' || l_password);
      fnd_file.put_line(fnd_file.log,
                        'l_file_location - ' || l_file_location);
      fnd_file.put_line(fnd_file.log, 'l_file_name - ' || l_file_name);
    
      -- send the file created by FTP to the url decided
      l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                                 program     => 'XXFTP',
                                                 argument1   => l_login_url,
                                                 argument2   => l_user_name,
                                                 argument3   => l_password,
                                                 argument4   => l_file_location,
                                                 argument5   => l_file_name);
      COMMIT;
      fnd_file.put_line(fnd_file.log, 'ftp request id - ' || l_request_id);
      WHILE l_error_flag = FALSE LOOP
        l_count  := l_count + 1;
        l_result := fnd_concurrent.wait_for_request(l_request_id,
                                                    5,
                                                    86400,
                                                    l_phase,
                                                    l_status,
                                                    l_dev_phase,
                                                    l_dev_status,
                                                    l_message);
      
        IF (l_dev_phase = 'COMPLETE' AND l_dev_status = 'NORMAL') THEN
          l_error_flag := TRUE;
          retcode      := 0;
        ELSIF (l_dev_phase = 'COMPLETE' AND l_dev_status <> 'NORMAL') THEN
          l_error_flag := TRUE;
          retcode      := 1;
          fnd_file.put_line(fnd_file.log,
                            'Request finished in error or warrning, did not transfer file. - ' ||
                            l_message);
        END IF; -- dev_phase
      END LOOP; -- l_error_flag
    
    END IF; -- l_count1
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'Procedure contact_ftp failed' || substr(SQLERRM, 1, 200);
      retcode := 2;
      fnd_file.put_line(fnd_file.log,
                        'Procedure contact_ftp failed - ' || SQLERRM);
      dbms_output.put_line('Procedure contact_ftp failed - ' ||
                           substr(SQLERRM, 1, 200));
  END contact_ftp;

  --------------------------------------------------------------------
  --  name:            main
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   14/01/2013 15:59:19
  --------------------------------------------------------------------
  --  purpose :        Handle the main program
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  14/01/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE main(errbuf   OUT VARCHAR2,
                 retcode  OUT VARCHAR2,
                 p_entity IN VARCHAR2) IS
  
    l_err_desc VARCHAR2(2500) := NULL;
    l_err_code VARCHAR2(100) := NULL;
  BEGIN
    errbuf  := NULL;
    retcode := 0;
    IF p_entity = 'ACCOUNT' THEN
      account_ftp(errbuf => l_err_desc, retcode => l_err_code);
    ELSIF p_entity = 'PERIOD' THEN
      period_ftp(errbuf => l_err_desc, retcode => l_err_code);
    ELSIF p_entity = 'PRODUCT' THEN
      product_ftp(errbuf => l_err_desc, retcode => l_err_code);
    ELSIF p_entity = 'SN' THEN
      machine_ftp(errbuf => l_err_desc, retcode => l_err_code);
    ELSIF p_entity = 'REBATE' THEN
      rebate_ftp(errbuf => l_err_desc, retcode => l_err_code);
    ELSIF p_entity = 'CONTACT' THEN
      contact_ftp(errbuf => l_err_desc, retcode => l_err_code);
    END IF;
    errbuf  := l_err_desc;
    retcode := l_err_code;
  
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'Procedure main failed - ' || substr(SQLERRM, 1, 240);
      retcode := 1;
  END main;

END xxhz_gam_site_pkg;
/
