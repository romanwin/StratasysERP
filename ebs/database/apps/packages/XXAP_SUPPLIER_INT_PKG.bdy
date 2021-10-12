create or replace package body XXAP_SUPPLIER_INT_PKG is

  --------------------------------------------------------------------------
  -- Purpose: This Package will Help to interface and update supplier information
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  11.10.18  LINGARAJ        CHG0043027 - CTASK0038143
  --                                    Upload Attribute7 (Supplier Tier)
  ---------------------------------------------------------------------------
  g_request_id NUMBER := FND_GLOBAL.CONC_REQUEST_ID;

  --------------------------------------------------------------------------
  -- Purpose:  log messages
  --
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  11.10.18  LINGARAJ        CHG0043027 - CTASK0038143
  --                                    log messalges
  ---------------------------------------------------------------------------
  procedure message(p_msg         in varchar2,
                    p_destination in number default fnd_file.log) is
  BEGIN
    IF fnd_global.conc_request_id = -1 THEN
      dbms_output.put_line(p_msg);
    ELSE
      fnd_file.put_line(p_destination, p_msg);
    END IF;
  END message;
  --------------------------------------------------------------------------
  -- Purpose: update vendor interface with status and error message
  --
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  11.10.18  LINGARAJ        CHG0043027 - CTASK0038143
  --
  ---------------------------------------------------------------------------
  Procedure update_interface_status(p_vendor_interface_id in number,
                                    p_status              in varchar2,
                                    p_err_msg             in varchar2) is
  begin
  
    update xxap_suppliers_interface
       set status      = nvl(p_status, status),
           err_message = nvl(p_err_msg, err_message)
     where sdh_batch_id = g_request_id
       and vendor_interface_id = p_vendor_interface_id;
  
  end update_interface_status;
  --------------------------------------------------------------------------
  -- Purpose: print Interface log
  --
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  11.10.18  LINGARAJ        CHG0043027 - CTASK0038143
  --
  ---------------------------------------------------------------------------
  procedure print_interface_log is
  
    cursor cur_vendor is
      select to_char(vendor_interface_id) vendor_interface_id,
             nvl(segment1, ' ') vendor_num,
             nvl(to_char(vendor_id), ' ') vendor_id,
             nvl(vendor_name, ' ') vendor_name,
             nvl(attribute7, ' ') attribute7,
             decode(status, 'S', 'SUCCESS', 'E', 'ERROR', status) STATUS,
             err_message
        from xxap_suppliers_interface
       where sdh_batch_id = g_request_id;
       
    l_str varchar2(4000);
  begin
    message('');
    message('');
    message('');
    message('----------------------------------------------------------------------------------------------------------------------------');
    message('INTERFACE_ID   |VENDOR NUM|VENDOR_ID |ATTRIBUTE7(TIER)|VENDOR NAME |STATUS|ERROR MESSAGE');
    message('----------------------------------------------------------------------------------------------------------------------------');
  
    for rec in cur_vendor loop
      
      l_str := RPAD(rec.vendor_interface_id, 15, ' ') || '|' ||
               RPAD(rec.vendor_num, 10, ' ') || '|' ||
               RPAD(rec.vendor_id, 10, ' ') || '|' ||
               RPAD(rec.attribute7, 16, ' ') || '|' ||
               RPAD(rec.vendor_name, 47, ' ') || '|' ||
               RPAD(rec.status, 6, ' ') || '|' || rec.err_message;
    
      message(l_str);
    
    end loop;
    
    message('----------------------------------------------------------------------------------------------------------------------------');
    message('');
    message('');
  end print_interface_log;
  --------------------------------------------------------------------------
  -- Purpose:    Validate Interface data
  --
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  11.10.18  LINGARAJ        CHG0043027 - CTASK0038143
  --                                    Validate interface Data
  ---------------------------------------------------------------------------
  procedure validate_vendor_data(errbuf          out varchar2,
                                 retcode         out number,
                                 p_template_name in varchar2) is
    cursor cur_vendor is
      select asp.vendor_id,
             asp.vendor_name,
             nvl(asp.enabled_flag, 'N') enabled_flag,
             nvl(asp.end_date_active, trunc(sysdate + 10)) end_date_active,
             asp.segment1 vendor_num,
             xsi.rowid xsi_rowid,
             xsi.attribute7
        from xxobjt.xxap_suppliers_interface xsi, ap_suppliers asp
       where 1 = 1
         and xsi.segment1 = asp.segment1(+) -- vendor number
         and sdh_batch_id = g_request_id
         and status = 'L';
  
  begin
    ----------------------------------
    --General Validation
    ----------------------------------
    --(1) Vendor Number Validation
    update xxap_suppliers_interface
       set status = 'E', err_message = 'Vendor Number Cannot be null.'
     where sdh_batch_id = g_request_id
       and segment1 is null
       and status = 'L'; -- File Loaded
  
    -- Vallidation for SUPP_TIER template
    If p_template_name = 'SUPP_TIER' Then
      update xxap_suppliers_interface
         set status      = 'E',
             err_message = 'Attribute7(TIER) value cannot be null'
       where sdh_batch_id = g_request_id
         and attribute7 is null
         and status = 'L'; -- File Loaded
    
      --Validate Attribute7 value against VALUE SET
      update xxap_suppliers_interface xsi
         set status      = 'E',
             err_message = 'Attribute7(TIER) doesnot contain a valid value.Please refer Value set XX_TIER_VALUES for all Possiable Values.'
       where xsi.sdh_batch_id = g_request_id
         and xsi.status = 'L'
         and xsi.attribute7 != 'NULL'
         and not exists
       (select 1
                from fnd_flex_values ffv, fnd_flex_value_sets ffvs
               where ffv.flex_value_set_id = ffvs.flex_value_set_id
                 and nvl(ffv.enabled_flag, 'N') = 'Y'
                 and ffvs.flex_value_set_name = 'XX_TIER_VALUES'
                 and ffv.flex_value = upper(xsi.attribute7));
    End If;
  
    For rec in cur_vendor Loop
      --General Validation
      -- Vendor Validation
      update xxobjt.xxap_suppliers_interface xsi
         set vendor_id   = rec.vendor_id,
             Vendor_name = rec.vendor_name,
             status     =
             (case
               When rec.enabled_flag = 'Y' and rec.end_date_active > trunc(sysdate) Then
                'L'
               Else
                'E'
             end),
             err_message =
             (case
               When rec.enabled_flag = 'Y' and rec.end_date_active > trunc(sysdate) Then
                ''
               Else
                'Vendor number is not Active or not valid.'
             end)
       where xsi.rowid = rec.xsi_rowid;
    End Loop;
  
    update xxap_suppliers_interface
       set status = 'V' -- Validated
     where sdh_batch_id = g_request_id
       and status = 'L'; -- File Loaded
  
    retcode := 0;
    message('All Records Validated Successfully');
  Exception
    When Others Then
      retcode := 2;
      errbuf  := sqlerrm;
      message('Unexpected ERROR in XXAP_SUPPLIER_INT_PKG.validate_vendor_data, Error:' ||
              sqlerrm);
  end validate_vendor_data;
  --------------------------------------------------------------------------
  -- Purpose: Process each Validated record by Update API
  --
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  11.10.18  LINGARAJ        CHG0043027 - CTASK0038143
  --                                    Process each Validated record by Update API
  ---------------------------------------------------------------------------
  Procedure call_vendor_update_api(errbuf          OUT VARCHAR2,
                                   retcode         OUT NUMBER,
                                   p_template_name IN VARCHAR2) is
    cursor cur_vendor is
      select vendor_interface_id,
             vendor_id,
             (case
               when upper(attribute7) = 'NULL' then
                fnd_api.g_miss_char
               else
                attribute7
             end) attribute7
        from xxap_suppliers_interface
       where sdh_batch_id = g_request_id
         and status = 'V';
  
    l_return_status VARCHAR2(10);
    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(2000);
    l_vendor_rec    ap_vendor_pub_pkg.r_vendor_rec_type;
    l_msg           VARCHAR2(2000);
    l_rec           number := 0;
  begin
    retcode := 0;
    mo_global.init('SQLAP');
  
    For rec in cur_vendor Loop
      l_vendor_rec           := null;
      l_vendor_rec.vendor_id := rec.vendor_id;
      l_msg_data             := '';
      l_msg_count            := 0;
      l_return_status        := '';
      l_msg                  := '';
    
      If p_template_name = 'SUPP_TIER' Then
        l_vendor_rec.attribute7 := rec.attribute7;
      End If;
    
      ap_vendor_pub_pkg.update_vendor(p_api_version      => 1.0,
                                      p_init_msg_list    => fnd_api.g_true,
                                      p_commit           => fnd_api.g_true,
                                      p_validation_level => fnd_api.g_valid_level_full,
                                      x_return_status    => l_return_status,
                                      x_msg_count        => l_msg_count,
                                      x_msg_data         => l_msg_data,
                                      p_vendor_rec       => l_vendor_rec,
                                      p_vendor_id        => rec.vendor_id);
    
      If l_return_status <> fnd_api.g_ret_sts_success Then
        for i in 1 .. fnd_msg_pub.count_msg loop
          l_msg := fnd_msg_pub.get(p_msg_index => i,
                                   p_encoded   => fnd_api.g_false);
        
        end loop;
      
        update_interface_status(rec.vendor_interface_id,
                                'E',
                                (l_msg_data || ',' || l_msg));
      else
        update_interface_status(rec.vendor_interface_id, 'S', '');
        l_rec := l_rec + 1;
      end if;
    
    end loop;
    message(l_rec || ' no of records processed through API Successfully.');
  exception
    when others then
      retcode := 2;
      errbuf  := sqlerrm;
      message('Unexpected Error in call_vendor_update_api , ' || errbuf);
  end call_vendor_update_api;
  --------------------------------------------------------------------------
  -- Purpose: This procedure is the main program which will called by concurrent program
  --
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  11.10.18  LINGARAJ        CHG0043027 - CTASK0038143
  --                                    Upload file & Call Validation and other required processing Logic
  ---------------------------------------------------------------------------
  procedure upload_supplier_data(errbuf          out varchar2,
                                 retcode         out varchar2,
                                 p_table_name    in varchar2,
                                 p_template_name in varchar2,
                                 p_file_name     in varchar2,
                                 p_directory     in varchar2) is
    stop_processing exception;
    l_errbuf         varchar2(1000);
    l_retcode        varchar2(50);
    l_error_messsage varchar2(4000);
    l_step           varchar2(50);
  begin
    retcode := '0';
    message(l_step);
    ---load data from csv-table into xxap_suppliers_interface table---------------------
    xxobjt_table_loader_util_pkg.load_file(errbuf                 => l_errbuf,
                                           retcode                => l_retcode,
                                           p_table_name           => p_table_name,
                                           p_template_name        => p_template_name,
                                           p_file_name            => p_file_name,
                                           p_directory            => p_directory,
                                           p_expected_num_of_rows => null);
  
    --update request id to the uploaded records
    update xxap_suppliers_interface
       set sdh_batch_id = g_request_id,
           status       = decode(l_retcode, '0', 'L', 'E') -- file loaded
     where sdh_batch_id = -1;
  
    if l_retcode <> '0' then
    
      ---warning or error---
      l_error_messsage := l_errbuf;
      message('=================================================');
      message('File Not Loaded');
      message('Error :' || l_error_messsage);
      message('=================================================');
    
      raise stop_processing;
    
    else
      message('=================================================');
      message('File Loaded Successfully to Interface Table : XXAP_SUPPLIERS_INTERFACE, SDH_BATCH_ID:' ||
              g_request_id);
      message('=================================================');
    end if;
  
    l_step := 'Step-2. Interface Data Validation Start.';
  
    --validate data
    validate_vendor_data(errbuf          => l_errbuf,
                         retcode         => l_retcode,
                         p_template_name => p_template_name);
  
    if l_retcode = 0 then
      l_step := 'Step-3. Call API for Supplier Data update.';
      call_vendor_update_api(errbuf          => l_errbuf,
                             retcode         => l_retcode,
                             p_template_name => p_template_name);
      if l_retcode = 2 then
        --mark remaining records error
        update xxap_suppliers_interface
           set status      = 'E',
               err_message = err_message ||
                             ', UNEXPECTED ERROR, During API data Update.'
         where sdh_batch_id = g_request_id
           and status != 'E';
      end if;
    
    else
      --mark all records error
      update xxap_suppliers_interface
         set status      = 'E',
             err_message = err_message ||
                           ', UNEXPECTED ERROR, During data validation.'
       where sdh_batch_id = g_request_id
         and status != 'E';
    end if;
  
    --print interface log
    print_interface_log;
  
  exception
    when stop_processing then
      message(l_error_messsage);
      retcode := '2';
      errbuf  := l_error_messsage;
    when others then
      l_error_messsage := substr('Unexpected ERROR in XXAP_SUPPLIER_INT_PKG.upload_supplier_data (' ||
                                 l_step || ') ' || sqlerrm,
                                 1,
                                 200);
      message(l_error_messsage);
    
      retcode := '2';
      errbuf  := l_error_messsage;
  end upload_supplier_data;

end xxap_supplier_int_pkg;
/
