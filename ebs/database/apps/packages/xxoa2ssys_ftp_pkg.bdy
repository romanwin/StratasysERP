create or replace package body xxoa2ssys_ftp_pkg is

--------------------------------------------------------------------
--  name:            XXOA2SSYS_FTP_PKG
--  create by:       Dalit A. Raviv
--  Revision:        1.6
--  creation date:   13/08/2012 15:59:19
--------------------------------------------------------------------
--  purpose :        Merge Day1 project - Handle transfer data from oracle to Stratasys
--                   Sales force by FTP.
--                   CUST529 - OA 2 SSYS FTP to SFDC interface
--                   CUST538 - OA2Syteline - FTP - Intercompany Inventory In Transit
--                   CUST685 - OA2Syteline - FTP - handle invoice information
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  13/08/2012  Dalit A. Raviv    initial build
--  1.1  03/10/2012  Dalit A. Raviv    cust538 OA2Syteline - FTP - Intercompany Inventory In Transit
--                                     add procedure Main_intercompany_inv, po_ftp, rcv_ftp
--                                     modify procedure get_file_name
--  1.2  20/03/2013  Dalit A. Raviv    Procedure rcv_ftp - add column 
--  1.3  14/04/2013  Dalit A. Raviv    procedure rcv_ftp - take out Received date  
--  1.4  12/05/2013  Dalit A. Raviv    CUST685 - OA2Syteline - FTP - handle invoice information
--                                     add procedure main_invoice, invoice_backlog_ftp, invoice_booked_ftp, invoice_lines_ftp 
--  1.5  19/05/2013  Dalit A. Raviv    change the select between booking and backlog
--  1.6  16/06/2013  Dalit A. Raviv    procedure invoice_booked_ftp add population of so_type like 'Trade In%'  
--------------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:            get_file_name
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   14/08/2012
  --------------------------------------------------------------------
  --  purpose :        get the file name according to subject
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  14/08/2012  Dalit A. Raviv    initial build
  --  1.1  03/10/2012  Dalit A. Raviv    add entity to handle (PO/RCV)
  --  1.2  12/05/2013  Dalit A. Raviv    add ebtity to handle invoice
  --------------------------------------------------------------------
  function get_file_name (p_entity in varchar2) return varchar2 is

    l_file_name varchar2(150) := null;
  begin
    if p_entity = 'ITEM' then
      l_file_name := fnd_profile.VALUE('XXOBJT_OA2SSYS_FTP_FILE_NAME_ITEM');
    elsif p_entity = 'ONHAND' then
      l_file_name := fnd_profile.VALUE('XXOBJT_OA2SSYS_FTP_FILE_NAME_ONHAND');
    elsif p_entity = 'ORDER' then
      l_file_name := fnd_profile.VALUE('XXOBJT_OA2SSYS_FTP_FILE_NAME_ORDER');
    elsif p_entity = 'CONTRACT' then
      l_file_name := fnd_profile.VALUE('XXOBJT_OA2SSYS_FTP_FILE_NAME_CONTRACT');
    elsif p_entity = 'BILL' then
      l_file_name := fnd_profile.VALUE('XXOBJT_OA2SSYS_FTP_FILE_NAME_BILL');
    elsif p_entity = 'SHIP' then
      l_file_name := fnd_profile.VALUE('XXOBJT_OA2SSYS_FTP_FILE_NAME_SHIP');
    elsif p_entity = 'CONTACT' then
      l_file_name := fnd_profile.VALUE('XXOBJT_OA2SSYS_FTP_FILE_NAME_CONTACT');
    elsif p_entity = 'RELATIONS' then
      l_file_name := fnd_profile.VALUE('XXOBJT_OA2SSYS_FTP_FILE_NAME_RELATIONS');
    --  1.1  03/10/2012  Dalit A. Raviv
    elsif p_entity = 'PO' then
      l_file_name := fnd_profile.VALUE('XXPO_OA2SYTELINE_FTP_FILE_NAME_PO');  -- po.csv
    elsif p_entity = 'RCV' then
      l_file_name := fnd_profile.VALUE('XXPO_OA2SYTELINE_FTP_FILE_NAME_RCV'); -- rcv.csv
    -- end  1.1  03/10/2012  Dalit A. Raviv
    -- 1.2  12/05/2013  Dalit A. Raviv
    elsif p_entity = 'INVOICELINES' then
      l_file_name := fnd_profile.VALUE('XXAR_OA2SYTELINE_FTP_FILE_NAME_INVOICELINES'); -- invoicelines.csv
    elsif p_entity = 'INVBACKLOG' then
      l_file_name := fnd_profile.VALUE('XXAR_OA2SYTELINE_FTP_FILE_NAME_INVBACKLOG');   -- backlog.csv
    elsif p_entity = 'INVBOOKED' then
      l_file_name := fnd_profile.VALUE('XXAR_OA2SYTELINE_FTP_FILE_NAME_INVBOOKED');    -- bookings.csv
    -- end 1.2  12/05/2013  Dalit A. Raviv
    else
      l_file_name := 'xx_temp.csv';
    end if;
    
    return l_file_name;
  exception
    when others then
      return 'xx_temp.csv';
  end get_file_name;

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
  procedure get_ftp_login_details (p_login_url out varchar2,
                                   p_user      out varchar2,
                                   p_password  out varchar,
                                   p_err_code  out varchar2,
                                   p_err_desc  out varchar2) is

    l_env        varchar2(20);
  begin
    p_err_code  := 0;
    p_err_desc  := null;
    l_env       := xxobjt_fnd_attachments.get_environment_name;
    if l_env = 'PROD' then
      p_login_url := fnd_profile.VALUE('XXOBJT_OA2SSYS_FTP_URL');
      p_user      := fnd_profile.VALUE('XXOBJT_OA2SSYS_FTP_USER');
      p_password  := fnd_profile.VALUE('XXOBJT_OA2SSYS_FTP_PASSWORD');
    else
      p_login_url := fnd_profile.VALUE('XXOBJT_OA2SSYS_FTP_URL_DEFAULT');
      p_user      := fnd_profile.VALUE('XXOBJT_OA2SSYS_FTP_USER_DEFAULT');
      p_password  := fnd_profile.VALUE('XXOBJT_OA2SSYS_FTP_PASSWORD_DEFAULT');
    end if;

  exception
    when others then
      p_err_code  := 1;
      p_err_desc  := 'get_ftp_login_details - '||substr(sqlerrm,1,240);
      p_login_url := null;
      p_user      := null;
      p_password  := null;
  end get_ftp_login_details;

  --------------------------------------------------------------------
  --  name:            Item_ftp
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   13/08/2012 15:59:19
  --------------------------------------------------------------------
  --  purpose :        transfer item details from oracle to stratasys Sales force
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/08/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
/*  procedure Item_ftp_old(errbuf   out varchar2,
                         retcode  out varchar2) is

    cursor item_c is
      select msi.segment1                          item,
             mp.organization_code                  whse,
             hou.name                              whse_name,
             to_char(sum(moq.primary_transaction_quantity)) qty_available
      from   mtl_onhand_quantities_detail moq,
             mtl_system_items_b           msi,
             mtl_parameters               mp,
             hr_all_organization_units    hou
      where  moq.inventory_item_id        = msi.inventory_item_id
      and    moq.organization_id          = msi.organization_id
      and    moq.organization_id          = mp.organization_id
      and    moq.organization_id          = hou.organization_id
      and    mp.organization_code         in ('POT','EOT')
      --Add condition for identify SSYS items
      group by msi.segment1,
               mp.organization_code,
               hou.name;

    l_data       clob;
    l_directory  varchar2(150);
    --l_conn       UTL_TCP.connection;
    l_user_name  varchar2(150);
    l_password   varchar2(150);
    l_login_url  varchar2(150);
    l_file_name  varchar2(150);
    l_err_code   varchar2(150);
    l_err_desc   varchar2(150);
  begin
    errbuf  := null;
    retcode := 0;

    -- get ftp login details according to environment
    get_ftp_login_details (p_login_url => l_login_url,  -- o v  'Files.stratasys.com'
                           p_user      => l_user_name,  -- o v  'OBJSSYSDATAXFER'
                           p_password  => l_password,   -- o v  'Sh0k0l@d72'
                           p_err_code  => l_err_code,   -- o v
                           p_err_desc  => l_err_desc);  -- o v

    -- set columns prompts
    l_data := 'item;whse;whse_name;qty_available';
    -- get item data to clob variable
    for item_r in item_c loop
      l_data := l_data||item_r.item||';'||item_r.whse||';'||item_r.whse_name||';'||item_r.qty_available;
    end loop;
    if dbms_lob.getlength(l_data)= 33 then
      dbms_output.put_line('Did not create clob');
      -- send mail to whoom ????
    else
      dbms_output.put_line('len - '||dbms_lob.getlength(l_data));
    end if;
    -- set pl/sql directory path according to environment
    l_directory := '/usr/tmp/TEST'; -- 'XXOA2SSYS_FTP';--'XXCS_COUPONS_FILES'
   -- xxobjt_fnd_attachments.set_shared_directory (l_directory, 'LOG/ftp');
    l_file_name := get_file_name ('ITEM');


    -- create file at directory.
    XXOBJT_FTP_PKG.put_local_ascii_data(p_data => l_data,p_dir => l_directory,p_file => l_file_name);--'Dalit.item_test.csv'

    -- transfer file to stratasys

    --l_conn := XXOBJT_FTP_PKG.login(l_login_url, '21', l_user_name, l_password); -- to call profiles
    --XXOBJT_FTP_PKG.put_remote_ascii_data(p_conn => l_conn, p_file => l_file_name, p_data => l_data);
    --XXOBJT_FTP_PKG.logout(l_conn);

  --exception
  --  when others then
  --    dbms_output.put_line('err - '||substr(sqlerrm,1,240));
      --XXOBJT_FTP_PKG.logout(l_conn);
  end Item_ftp_old;
  */

  --------------------------------------------------------------------
  --  name:            Item_ftp
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   13/08/2012 15:59:19
  --------------------------------------------------------------------
  --  purpose :        transfer item details from oracle to stratasys Sales force
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/08/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure item_ftp (errbuf     out varchar2,
                      retcode    out varchar2,
                      p_num_days in  number)is

    cursor item_c is
      select v.item_num,
             replace(v.description,'"','') description,
             v.uom, v.status, v.stock_enabled,
             to_char(v.last_update_date,'DD-MON-YYYY HH24:MI:SS') last_update_date
      from   xxoa2ssys_item_details_v v
      where  v.last_update_date       > sysdate - p_num_days;

    l_file_name      varchar2(150) := null;
    l_file_handler   utl_file.file_type;
    l_env            varchar2(150) := null;
    --l_conn           UTL_TCP.connection;
    l_user_name      varchar2(150);
    l_password       varchar2(150);
    l_login_url      varchar2(150);
    l_err_code       varchar2(150);
    l_err_desc       varchar2(150);

    --l_directory_path varchar2(500);
    l_file_location  varchar2(240) := null;
    l_request_id     number;
    l_error_flag     boolean := FALSE;
    l_count          number  := 0;
    l_phase          varchar2(20);
    l_status         varchar2(20);
    l_dev_phase      varchar2(20);
    l_dev_status     varchar2(20);
    l_message        varchar2(100);
    l_result         boolean;
    l_temp           varchar2(1) := 'N';
    l_count1         number := 0;
  begin
    errbuf  := null;
    retcode := 0;

    select count(1)
    into   l_count1
    from   xxoa2ssys_item_details_v v
    where  1 = 1
    and    v.last_update_date       > sysdate - p_num_days;

    if l_count1 = 0 then
      FND_FILE.PUT_LINE(FND_FILE.LOG,'There is no data to transfer');
      dbms_output.put_line('There is no data to transfer');
    else

      l_file_name := get_file_name ('ITEM');
      --l_file_name := 'a.csv';
      l_env       := xxobjt_fnd_attachments.get_environment_name;
      
      -- get file location
      if l_env <> 'PROD' then
        l_env := 'DEV';
      end if;
      l_file_location := '/UtlFiles/shared/'||l_env||'/LOG/ftp'; --'/UtlFiles/shared/TEST/LOG/ftp';

      -- open new file with the SR number as name
      l_file_handler := utl_file.fopen ( location  => l_file_location,--'/UtlFiles/shared/'||l_env||'/ftp', --'/usr/tmp/'||l_env, -- /usr/tmp/TEST
                                         filename  => l_file_name,
                                         open_mode => 'w');
      -- start write to the file
      utl_file.put_line (file   => l_file_handler,
                         buffer => '"ITEM_NUM","DESCRIPTION","UOM","STATUS","STOCK_ENABLED","LAST_UPDATE_DATE"');

      for item_r in item_c loop
        begin
          l_temp := 'Y';
          --l_data := l_data||item_r.item||';'||item_r.whse||';'||item_r.whse_name||';'||item_r.qty_available;
          utl_file.put_line (file   => l_file_handler,
                             buffer => '"'||item_r.item_num||'","'||item_r.description||'","'||item_r.uom||
                                       '","'||item_r.status||'","'||item_r.stock_enabled||'","'||item_r.last_update_date||'"');
         exception
          when utl_file.invalid_mode then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'The open_mode parameter in FOPEN is invalid');
            dbms_output.put_line('The open_mode parameter in FOPEN is invalid');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.invalid_path then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Specified path does not exist or is not visible to Oracle');
            dbms_output.put_line('Specified path does not exist or is not visible to Oracle');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.invalid_filehandle then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'File handle does not exist');
            dbms_output.put_line('File handle does not exist');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.internal_error then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Unhandled internal error in the UTL_FILE package');
            dbms_output.put_line('Unhandled internal error in the UTL_FILE package');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.file_open then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'File is already open');
            dbms_output.put_line('File is already open');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.invalid_maxlinesize then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'The MAX_LINESIZE value for FOPEN() is invalid; it should be within the range 1 to 32767');
            dbms_output.put_line('The MAX_LINESIZE value for FOPEN() is invalid; it should be within the range 1 to 32767');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.invalid_operation then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'File could not be opened or operated on as requested' );
            dbms_output.put_line('File could not be opened or operated on as requested' );
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.write_error then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Unable to write to file');
            dbms_output.put_line('Unable to write to file');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.access_denied then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Access to the file has been denied by the operating system');
            dbms_output.put_line('Access to the file has been denied by the operating system');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when others then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Unknown UTL_FILE Error');
            dbms_output.put_line('Unknown UTL_FILE Error - '||sqlerrm);
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
        end;
      end loop; -- write to file
      -- close the created file
      utl_file.fclose(file => l_file_handler);

      -- get ftp login details according to environment
      get_ftp_login_details (p_login_url => l_login_url,  -- o v  'Files.stratasys.com'
                             p_user      => l_user_name,  -- o v  'OBJSSYSDATAXFER'
                             p_password  => l_password,   -- o v  'Sh0k0l@d72'
                             p_err_code  => l_err_code,   -- o v
                             p_err_desc  => l_err_desc);  -- o v
   /*
      l_conn := XXOBJT_FTP_PKG.login(l_login_url, '21', l_user_name, l_password);
      --l_conn := XXOBJT_FTP_PKG.login(l_login_url, '21', l_user_name, l_password);
      XXOBJT_FTP_PKG.ascii(p_conn => l_conn);
      dbms_output.put_line('Success connect');
      --XXOBJT_FTP_PKG.put_remote_ascii_data(p_conn => l_conn, p_file => l_file_name, p_data => l_data);
      XXOBJT_FTP_PKG.put( p_conn       => l_conn,  -- i/o nocopy UTL_TCP.connection,
                          p_from_dir   => 'XXOA2SSYS_FTP', -- i v -- '/usr/tmp/'||l_env
                          p_from_file  => l_file_name,     -- i v
                          p_to_file    => l_file_name) ;   -- i v
      XXOBJT_FTP_PKG.logout(l_conn);
  */

      -- transfer file to stratasys
      fnd_file.put_line(fnd_file.log,'l_login_url - '||l_login_url);
      fnd_file.put_line(fnd_file.log,'l_user_name - '||l_user_name);
      fnd_file.put_line(fnd_file.log,'l_password - '||l_password);
      fnd_file.put_line(fnd_file.log,'l_file_location - '||l_file_location);
      fnd_file.put_line(fnd_file.log,'l_file_name - '||l_file_name);
      if l_temp = 'Y' then
        l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                                   program     => 'XXFTP',
                                                   argument1   => l_login_url,
                                                   argument2   => l_user_name,
                                                   argument3   => l_password,
                                                   argument4   => l_file_location,
                                                   argument5   => l_file_name);
        commit;
        fnd_file.put_line(fnd_file.log,'ftp request id - '||l_request_id);
        while l_error_flag = FALSE loop
          l_count := l_count + 1;
          l_result := fnd_concurrent.wait_for_request(l_request_id , 5, 86400,
                                                      l_phase,
                                                      l_status,
                                                      l_dev_phase,
                                                      l_dev_status,
                                                      l_message);

          if (l_dev_phase = 'COMPLETE' and l_dev_status = 'NORMAL') then
            l_error_flag := TRUE;
            retcode := 0;
          elsif (l_dev_phase = 'COMPLETE' and l_dev_status <> 'NORMAL') then
            l_error_flag := TRUE;
            retcode := 1;
            fnd_file.put_line(fnd_file.log,'Request finished in error or warrning, did not transfer file. - '||l_message);
          end if; -- dev_phase
        end loop; -- l_error_flag
      else
        fnd_file.put_line(fnd_file.log,'No data to transfer.');
      end if;
    end if; -- l_count
  exception
   when others then
      errbuf   := 2;
      retcode  := 'Procedure item_ftp_new failed'||substr(sqlerrm,1,240);
      fnd_file.put_line(fnd_file.log,'Procedure item_ftp_new failed - '||sqlerrm);
      dbms_output.put_line('Procedure item_ftp_new failed - '||substr(sqlerrm,1,240));
  end item_ftp;

  --------------------------------------------------------------------
  --  name:            onhand_ftp
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   16/08/2012 15:59:19
  --------------------------------------------------------------------
  --  purpose :        transfer on-hand details from oracle to stratasys Sales force
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16/08/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure onhand_ftp (errbuf     out varchar2,
                        retcode    out varchar2,
                        p_num_days in  number) is

    cursor onhand_c is
      select v.item_num, v.whse, v.whse_name, v.qty_available,
             to_char(v.last_update_date,'DD-MON-YYYY HH24:MI:SS') last_update_date
      from   xxoa2ssys_onhand_details_v v
      where  v.last_update_date         > sysdate - p_num_days;

    l_file_name      varchar2(150) := null;
    l_file_handler   utl_file.file_type;
    l_env            varchar2(150) := null;
    l_user_name      varchar2(150);
    l_password       varchar2(150);
    l_login_url      varchar2(150);
    l_err_code       varchar2(150);
    l_err_desc       varchar2(150);

    l_file_location  varchar2(240) := null;
    l_request_id     number;
    l_error_flag     boolean := FALSE;
    l_count          number  := 0;
    l_phase          varchar2(20);
    l_status         varchar2(20);
    l_dev_phase      varchar2(20);
    l_dev_status     varchar2(20);
    l_message        varchar2(100);
    l_result         boolean;
    l_temp           varchar2(1) := 'N';
    l_count1          number      := 0;
  begin
    errbuf  := null;
    retcode := 0;

    select count(1)
    into   l_count1
    from   xxoa2ssys_onhand_details_v v
    where  1 =1
    and    v.last_update_date         > sysdate - p_num_days;

    if l_count1 = 0 then
      FND_FILE.PUT_LINE(FND_FILE.LOG,'There is no data to transfer');
      dbms_output.put_line('There is no data to transfer');
    else
      l_file_name := get_file_name ('ONHAND');
      l_env       := xxobjt_fnd_attachments.get_environment_name;
      -- get file location
      if l_env <> 'PROD' then
        l_env := 'DEV';
      end if;
      l_file_location := '/UtlFiles/shared/'||l_env||'/LOG/ftp'; --'/UtlFiles/shared/TEST/LOG/ftp';

      -- open new file with the SR number as name
      l_file_handler := utl_file.fopen ( location  => l_file_location,
                                         filename  => l_file_name,
                                         open_mode => 'w');

      -- start write to the file
      utl_file.put_line (file   => l_file_handler,
                         buffer => '"ITEM_NUM","WHSE","WHSE_NAME","QTY_AVAILABLE","LAST_UPDATE_DATE"');
      for onhand_r in onhand_c loop
        begin
          l_temp := 'Y';
          utl_file.put_line (file   => l_file_handler,
                             buffer => '"'||onhand_r.item_num||'","'||onhand_r.whse||'","'||onhand_r.whse_name||
                                       '","'||onhand_r.qty_available||'","'|| onhand_r.last_update_date||'"');
         exception
          when utl_file.invalid_mode then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'The open_mode parameter in FOPEN is invalid');
            dbms_output.put_line('The open_mode parameter in FOPEN is invalid');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.invalid_path then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Specified path does not exist or is not visible to Oracle');
            dbms_output.put_line('Specified path does not exist or is not visible to Oracle');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.invalid_filehandle then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'File handle does not exist');
            dbms_output.put_line('File handle does not exist');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.internal_error then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Unhandled internal error in the UTL_FILE package');
            dbms_output.put_line('Unhandled internal error in the UTL_FILE package');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.file_open then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'File is already open');
            dbms_output.put_line('File is already open');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.invalid_maxlinesize then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'The MAX_LINESIZE value for FOPEN() is invalid; it should be within the range 1 to 32767');
            dbms_output.put_line('The MAX_LINESIZE value for FOPEN() is invalid; it should be within the range 1 to 32767');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.invalid_operation then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'File could not be opened or operated on as requested' );
            dbms_output.put_line('File could not be opened or operated on as requested' );
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.write_error then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Unable to write to file');
            dbms_output.put_line('Unable to write to file');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.access_denied then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Access to the file has been denied by the operating system');
            dbms_output.put_line('Access to the file has been denied by the operating system');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when others then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Unknown UTL_FILE Error');
            dbms_output.put_line('Unknown UTL_FILE Error - '||sqlerrm);
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
        end;
      end loop; -- write to file
      -- close the created file
      utl_file.fclose(file => l_file_handler);

      -- get ftp login details according to environment
      get_ftp_login_details (p_login_url => l_login_url,  -- o v  'Files.stratasys.com'
                             p_user      => l_user_name,  -- o v  'OBJSSYSDATAXFER'
                             p_password  => l_password,   -- o v  'Sh0k0l@d72'
                             p_err_code  => l_err_code,   -- o v
                             p_err_desc  => l_err_desc);  -- o v

      -- transfer file to stratasys
      fnd_file.put_line(fnd_file.log,'l_login_url - '||l_login_url);
      fnd_file.put_line(fnd_file.log,'l_user_name - '||l_user_name);
      fnd_file.put_line(fnd_file.log,'l_password - '||l_password);
      fnd_file.put_line(fnd_file.log,'l_file_location - '||l_file_location);
      fnd_file.put_line(fnd_file.log,'l_file_name - '||l_file_name);

      if l_temp = 'Y' then

        l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                                   program     => 'XXFTP',
                                                   argument1   => l_login_url,
                                                   argument2   => l_user_name,
                                                   argument3   => l_password,
                                                   argument4   => l_file_location,
                                                   argument5   => l_file_name);
        commit;
        fnd_file.put_line(fnd_file.log,'ftp request id - '||l_request_id);
        while l_error_flag = FALSE loop
          l_count := l_count + 1;
          l_result := fnd_concurrent.wait_for_request(l_request_id , 5, 86400,
                                                      l_phase,
                                                      l_status,
                                                      l_dev_phase,
                                                      l_dev_status,
                                                      l_message);

          if (l_dev_phase = 'COMPLETE' and l_dev_status = 'NORMAL') then
            l_error_flag := TRUE;
            retcode := 0;
          elsif (l_dev_phase = 'COMPLETE' and l_dev_status <> 'NORMAL') then
            l_error_flag := TRUE;
            retcode := 1;
            fnd_file.put_line(fnd_file.log,'Request finished in error or warrning, did not transfer file. - '||l_message);
          end if; -- dev_phase
        end loop; -- l_error_flag
      else
        fnd_file.put_line(fnd_file.log,'No data to transfer.');
      end if;
    end if; -- l_count
  exception
   when others then
      errbuf   := 2;
      retcode  := 'Procedure onhand_ftp failed'||substr(sqlerrm,1,240);
      fnd_file.put_line(fnd_file.log,'Procedure onhand_ftp failed - '||sqlerrm);
      dbms_output.put_line('Procedure onhand_ftp failed - '||substr(sqlerrm,1,240));
  end onhand_ftp;

  --------------------------------------------------------------------
  --  name:            relations_ftp
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   16/08/2012 15:59:19
  --------------------------------------------------------------------
  --  purpose :        transfer relations details from oracle to stratasys Sales force
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16/08/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure relations_ftp (errbuf     out varchar2,
                           retcode    out varchar2,
                           p_num_days in  number)is

    cursor rel_c is
      select source_account, destination_account, ship_to, bill_to, status, organization_name, to_char(last_update_date,'DD-MON-YYYY HH24:MI:SS') last_update_date
      from   xxoa2ssys_relations_details_v v
      where  v.last_update_date            > sysdate - p_num_days;

    l_file_name      varchar2(150) := null;
    l_file_handler   utl_file.file_type;
    l_env            varchar2(150) := null;
    l_user_name      varchar2(150);
    l_password       varchar2(150);
    l_login_url      varchar2(150);
    l_err_code       varchar2(150);
    l_err_desc       varchar2(150);

    l_file_location  varchar2(240) := null;
    l_request_id     number;
    l_error_flag     boolean := FALSE;
    l_count          number  := 0;
    l_phase          varchar2(20);
    l_status         varchar2(20);
    l_dev_phase      varchar2(20);
    l_dev_status     varchar2(20);
    l_message        varchar2(100);
    l_result         boolean;
    l_temp           varchar2(1) := 'N';
    l_count1         number := 0;
  begin
    errbuf  := null;
    retcode := 0;

    select count(1)
    into   l_count1
    from   xxoa2ssys_relations_details_v v
    where  1 =1
    and    v.last_update_date            > sysdate - p_num_days;

    if l_count1 = 0 then
      FND_FILE.PUT_LINE(FND_FILE.LOG,'There is no data to transfer');
      dbms_output.put_line('There is no data to transfer');
    else

      l_file_name := get_file_name ('RELATIONS');
      l_env       := xxobjt_fnd_attachments.get_environment_name;
      -- get file location
      if l_env <> 'PROD' then
        l_env := 'DEV';
      end if;
      l_file_location := '/UtlFiles/shared/'||l_env||'/LOG/ftp'; --'/UtlFiles/shared/TEST/LOG/ftp';

      -- open new file with the SR number as name
      l_file_handler := utl_file.fopen ( location  => l_file_location,
                                         filename  => l_file_name,
                                         open_mode => 'w');

      -- start write to the file
      utl_file.put_line (file   => l_file_handler,
                         buffer => '"SOURCE_ACCOUNT","DESTINATION_ACCOUNT","SHIP_TO","BILL_TO","STATUS","ORGANIZATION_NAME","LAST_UPDATE_DATE"');  -- organization_name
      for rel_r in rel_c loop
        begin
          l_temp := 'Y';
          utl_file.put_line (file   => l_file_handler,
                             buffer => '"'||rel_r.source_account||'","'||rel_r.destination_account||'","'||rel_r.ship_to||'","'||rel_r.bill_to||'","'||rel_r.status||'","'||rel_r.organization_name||'","'||rel_r.last_update_date||'"');
         exception
          when utl_file.invalid_mode then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'The open_mode parameter in FOPEN is invalid');
            dbms_output.put_line('The open_mode parameter in FOPEN is invalid');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.invalid_path then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Specified path does not exist or is not visible to Oracle');
            dbms_output.put_line('Specified path does not exist or is not visible to Oracle');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.invalid_filehandle then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'File handle does not exist');
            dbms_output.put_line('File handle does not exist');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.internal_error then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Unhandled internal error in the UTL_FILE package');
            dbms_output.put_line('Unhandled internal error in the UTL_FILE package');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.file_open then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'File is already open');
            dbms_output.put_line('File is already open');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.invalid_maxlinesize then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'The MAX_LINESIZE value for FOPEN() is invalid; it should be within the range 1 to 32767');
            dbms_output.put_line('The MAX_LINESIZE value for FOPEN() is invalid; it should be within the range 1 to 32767');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.invalid_operation then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'File could not be opened or operated on as requested' );
            dbms_output.put_line('File could not be opened or operated on as requested' );
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.write_error then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Unable to write to file');
            dbms_output.put_line('Unable to write to file');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.access_denied then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Access to the file has been denied by the operating system');
            dbms_output.put_line('Access to the file has been denied by the operating system');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when others then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Unknown UTL_FILE Error');
            dbms_output.put_line('Unknown UTL_FILE Error - '||sqlerrm);
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
        end;
      end loop; -- write to file
      -- close the created file
      utl_file.fclose(file => l_file_handler);

      -- get ftp login details according to environment
      get_ftp_login_details (p_login_url => l_login_url,  -- o v  'Files.stratasys.com'
                             p_user      => l_user_name,  -- o v  'OBJSSYSDATAXFER'
                             p_password  => l_password,   -- o v  'Sh0k0l@d72'
                             p_err_code  => l_err_code,   -- o v
                             p_err_desc  => l_err_desc);  -- o v

      -- transfer file to stratasys
      fnd_file.put_line(fnd_file.log,'l_login_url - '||l_login_url);
      fnd_file.put_line(fnd_file.log,'l_user_name - '||l_user_name);
      fnd_file.put_line(fnd_file.log,'l_password - '||l_password);
      fnd_file.put_line(fnd_file.log,'l_file_location - '||l_file_location);
      fnd_file.put_line(fnd_file.log,'l_file_name - '||l_file_name);
      if l_temp = 'Y' then
        l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                                   program     => 'XXFTP',
                                                   argument1   => l_login_url,
                                                   argument2   => l_user_name,
                                                   argument3   => l_password,
                                                   argument4   => l_file_location,
                                                   argument5   => l_file_name);
        commit;
        fnd_file.put_line(fnd_file.log,'ftp request id - '||l_request_id);
        while l_error_flag = FALSE loop
          l_count := l_count + 1;
          l_result := fnd_concurrent.wait_for_request(l_request_id , 5, 86400,
                                                      l_phase,
                                                      l_status,
                                                      l_dev_phase,
                                                      l_dev_status,
                                                      l_message);

          if (l_dev_phase = 'COMPLETE' and l_dev_status = 'NORMAL') then
            l_error_flag := TRUE;
            retcode := 0;
          elsif (l_dev_phase = 'COMPLETE' and l_dev_status <> 'NORMAL') then
            l_error_flag := TRUE;
            retcode := 1;
            fnd_file.put_line(fnd_file.log,'Request finished in error or warrning, did not transfer file. - '||l_message);
          end if; -- dev_phase
        end loop; -- l_error_flag
      else
        fnd_file.put_line(fnd_file.log,'No data to transfer.');
      end if;
    end if; -- l_count1
  exception
   when others then
      errbuf   := 2;
      retcode  := 'Procedure relations_ftp failed'||substr(sqlerrm,1,240);
      fnd_file.put_line(fnd_file.log,'Procedure relations_ftp failed - '||sqlerrm);
      dbms_output.put_line('Procedure relations_ftp failed - '||substr(sqlerrm,1,240));
  end relations_ftp;

  --------------------------------------------------------------------
  --  name:            contact_ftp
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   16/08/2012 15:59:19
  --------------------------------------------------------------------
  --  purpose :        transfer customer contacts details from oracle to stratasys Sales force
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16/08/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure contact_ftp (errbuf     out varchar2,
                         retcode    out varchar2,
                         p_num_days in  number) is

    cursor cont_c is
      select v.cust_num, v.contact_number,
             replace(v.contact_name, '"','')  contact_name, v.status,
             v.general_phone, v.mobile_phone, v.fax_phone,
             replace(v.email_address, '"','') email_address,
             to_char(last_update_date,'DD-MON-YYYY HH24:MI:SS') last_update_date
      from   xxoa2ssys_contact_details_v v
      where  v.last_update_date          > sysdate - p_num_days;

    l_file_name      varchar2(150) := null;
    l_file_handler   utl_file.file_type;
    l_env            varchar2(150) := null;
    l_user_name      varchar2(150);
    l_password       varchar2(150);
    l_login_url      varchar2(150);
    l_err_code       varchar2(150);
    l_err_desc       varchar2(150);

    l_file_location  varchar2(240) := null;
    l_request_id     number;
    l_error_flag     boolean := FALSE;
    l_count          number  := 0;
    l_phase          varchar2(20);
    l_status         varchar2(20);
    l_dev_phase      varchar2(20);
    l_dev_status     varchar2(20);
    l_message        varchar2(100);
    l_result         boolean;
    l_temp           varchar2(1) := 'N';
    l_count1         number      := 0;
  begin
    errbuf  := null;
    retcode := 0;

    select count(1)
    into   l_count1
    from   xxoa2ssys_contact_details_v v
    where  1 =1
    and    v.last_update_date          > sysdate - p_num_days;

    if l_count1 = 0 then
      FND_FILE.PUT_LINE(FND_FILE.LOG,'There is no data to transfer');
      dbms_output.put_line('There is no data to transfer');
    else
      l_file_name := get_file_name ('CONTACT');
      l_env       := xxobjt_fnd_attachments.get_environment_name;
      -- get file location
      if l_env <> 'PROD' then
        l_env := 'DEV';
      end if;
      l_file_location := '/UtlFiles/shared/'||l_env||'/LOG/ftp'; --'/UtlFiles/shared/TEST/LOG/ftp';

      -- open new file with the SR number as name
      l_file_handler := utl_file.fopen ( location  => l_file_location,
                                         filename  => l_file_name,
                                         open_mode => 'w');

      -- start write to the file
      utl_file.put_line (file   => l_file_handler,
                         buffer => '"CUST_NUM","CONTACT_NUMBER","CONTACT_NAME","STATUS","GENERAL_PHONE","MOBILE_PHONE","FAX_PHONE","EMAIL_ADDRESS","LAST_UPDATE_DATE"');

      for cont_r in cont_c loop
        begin
          l_temp := 'Y';
          utl_file.put_line (file   => l_file_handler,
                             buffer => '"'||cont_r.cust_num||'","'||cont_r.contact_number||'","'||cont_r.contact_name||'","'||cont_r.status||'","'||
                             cont_r.general_phone||'","'||cont_r.mobile_phone||'","'||cont_r.fax_phone||'","'||cont_r.email_address||'","'||cont_r.last_update_date||'"');
         exception
          when utl_file.invalid_mode then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'The open_mode parameter in FOPEN is invalid');
            dbms_output.put_line('The open_mode parameter in FOPEN is invalid');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.invalid_path then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Specified path does not exist or is not visible to Oracle');
            dbms_output.put_line('Specified path does not exist or is not visible to Oracle');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.invalid_filehandle then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'File handle does not exist');
            dbms_output.put_line('File handle does not exist');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.internal_error then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Unhandled internal error in the UTL_FILE package');
            dbms_output.put_line('Unhandled internal error in the UTL_FILE package');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.file_open then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'File is already open');
            dbms_output.put_line('File is already open');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.invalid_maxlinesize then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'The MAX_LINESIZE value for FOPEN() is invalid; it should be within the range 1 to 32767');
            dbms_output.put_line('The MAX_LINESIZE value for FOPEN() is invalid; it should be within the range 1 to 32767');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.invalid_operation then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'File could not be opened or operated on as requested' );
            dbms_output.put_line('File could not be opened or operated on as requested' );
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.write_error then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Unable to write to file');
            dbms_output.put_line('Unable to write to file');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.access_denied then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Access to the file has been denied by the operating system');
            dbms_output.put_line('Access to the file has been denied by the operating system');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when others then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Unknown UTL_FILE Error');
            dbms_output.put_line('Unknown UTL_FILE Error - '||sqlerrm);
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
        end;
      end loop; -- write to file
      -- close the created file
      utl_file.fclose(file => l_file_handler);

      -- get ftp login details according to environment
      get_ftp_login_details (p_login_url => l_login_url,  -- o v  'Files.stratasys.com'
                             p_user      => l_user_name,  -- o v  'OBJSSYSDATAXFER'
                             p_password  => l_password,   -- o v  'Sh0k0l@d72'
                             p_err_code  => l_err_code,   -- o v
                             p_err_desc  => l_err_desc);  -- o v

      -- transfer file to stratasys
      fnd_file.put_line(fnd_file.log,'l_login_url - '||l_login_url);
      fnd_file.put_line(fnd_file.log,'l_user_name - '||l_user_name);
      fnd_file.put_line(fnd_file.log,'l_password - '||l_password);
      fnd_file.put_line(fnd_file.log,'l_file_location - '||l_file_location);
      fnd_file.put_line(fnd_file.log,'l_file_name - '||l_file_name);

      l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                                 program     => 'XXFTP',
                                                 argument1   => l_login_url,
                                                 argument2   => l_user_name,
                                                 argument3   => l_password,
                                                 argument4   => l_file_location,
                                                 argument5   => l_file_name);
      commit;
      fnd_file.put_line(fnd_file.log,'ftp request id - '||l_request_id);
      if l_temp = 'Y' then
        while l_error_flag = FALSE loop
          l_count := l_count + 1;
          l_result := fnd_concurrent.wait_for_request(l_request_id , 5, 86400,
                                                      l_phase,
                                                      l_status,
                                                      l_dev_phase,
                                                      l_dev_status,
                                                      l_message);

          if (l_dev_phase = 'COMPLETE' and l_dev_status = 'NORMAL') then
            l_error_flag := TRUE;
            retcode := 0;
          elsif (l_dev_phase = 'COMPLETE' and l_dev_status <> 'NORMAL') then
            l_error_flag := TRUE;
            retcode := 1;
            fnd_file.put_line(fnd_file.log,'Request finished in error or warrning, did not transfer file. - '||l_message);
          end if; -- dev_phase
        end loop; -- l_error_flag
      else
        fnd_file.put_line(fnd_file.log,'No data to transfer.');
      end if;
    end if; -- l_count1
  exception
   when others then
      errbuf   := 2;
      retcode  := 'Procedure contact_ftp failed'||substr(sqlerrm,1,240);
      fnd_file.put_line(fnd_file.log,'Procedure contact_ftp failed - '||sqlerrm);
      dbms_output.put_line('Procedure contact_ftp failed - '||substr(sqlerrm,1,240));
  end contact_ftp;

  --------------------------------------------------------------------
  --  name:            customer_billing_ftp
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   16/08/2012 15:59:19
  --------------------------------------------------------------------
  --  purpose :        transfer customer billing details from oracle to stratasys Sales force
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16/08/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure customer_billing_ftp (errbuf     out varchar2,
                                  retcode    out varchar2,
                                  p_num_days in  number) is

    cursor bill_c is
      select v.Organization_name, v.cust_num,
             replace(v.cust_name,'"','') cust_name, v.site_number, v.status,
             replace(v.address1, '"','') address1,
             replace(v.address2, '"','') address2,
             replace(v.address3, '"','') address3,
             replace(v.address4, '"','') address4,
             v.city, v.state, v.postal_code, v.country, v.category_code, v.cust_type_desc,
             v.terms_name, v.terms_description, v.slsman, v.slsman_name, v.inco_terms, v.fob, v.currency_code,
             v.credit_limit, v.credit_hold, to_char(v.last_update_date,'DD-MON-YYYY HH24:MI:SS') last_update_date
      from   xxoa2ssys_customer_billing_v v
      where  v.last_update_date           > sysdate - p_num_days;

    l_file_name      varchar2(150) := null;
    l_file_handler   utl_file.file_type;
    l_env            varchar2(150) := null;
    l_user_name      varchar2(150);
    l_password       varchar2(150);
    l_login_url      varchar2(150);
    l_err_code       varchar2(150);
    l_err_desc       varchar2(150);

    l_file_location  varchar2(240) := null;
    l_request_id     number;
    l_error_flag     boolean := FALSE;
    l_count          number  := 0;
    l_phase          varchar2(20);
    l_status         varchar2(20);
    l_dev_phase      varchar2(20);
    l_dev_status     varchar2(20);
    l_message        varchar2(100);
    l_result         boolean;
    l_temp           varchar2(1) := 'N';
    l_count1         number      := 0;
  begin
    errbuf  := null;
    retcode := 0;

    select count(1)
    into   l_count1
    from   xxoa2ssys_customer_billing_v v
    where  1 =1
    and    v.last_update_date           > sysdate - p_num_days;

    if l_count1 = 0 then
      FND_FILE.PUT_LINE(FND_FILE.LOG,'There is no data to transfer');
      dbms_output.put_line('There is no data to transfer');
    else
      l_file_name := get_file_name ('BILL');
      l_env       := xxobjt_fnd_attachments.get_environment_name;
      -- get file location
      if l_env <> 'PROD' then
        l_env := 'DEV';
      end if;
      l_file_location := '/UtlFiles/shared/'||l_env||'/LOG/ftp'; --'/UtlFiles/shared/TEST/LOG/ftp';

      -- open new file with the SR number as name
      l_file_handler := utl_file.fopen ( location     => l_file_location,
                                         filename     => l_file_name,
                                         open_mode    => 'w',
                                         max_linesize => 32767);

      -- start write to the file
      utl_file.put_line (file   => l_file_handler,
                         buffer => '"ORGANIZATION_NAME","CUST_NUM","CUST_NAME","SITE_NUMBER","STATUS","ADDRESS1","ADDRESS2","ADDRESS3","ADDRESS4","CITY",'||
                                   '"STATE","POSTAL_CODE","COUNTRY","CATEGORY_CODE","CUST_TYPE_DESC","TERMS_NAME","TERMS_DESCRIPTION","SLSMAN",'||
                                   '"SLSMAN_NAME","INCO_TERMS","FOB","CURRENCY_CODE","CREDIT_LIMIT","CREDIT_HOLD","LAST_UPDATE_DATE"');
      for bill_r in bill_c loop
        begin
          l_temp := 'Y';
          utl_file.put_line (file   => l_file_handler,
                             buffer => '"'||bill_r.organization_name||'","'||bill_r.cust_num||'","'||bill_r.cust_name||'","'||bill_r.site_number||'","'||
                                       bill_r.status||'","'||bill_r.address1||'","'||bill_r.address2||'","'||bill_r.address3||'","'||bill_r.address4||'","'||
                                       bill_r.city||'","'||bill_r.state||'","'||bill_r.postal_code||'","'||bill_r.country||'","'||bill_r.category_code||'","'||
                                       bill_r.cust_type_desc||'","'||bill_r.terms_name||'","'||bill_r.terms_description||'","'||bill_r.slsman||'","'||
                                       bill_r.slsman_name||'","'||bill_r.inco_terms||'","'||bill_r.fob||'","'||bill_r.currency_code||'","'||
                                       bill_r.credit_limit||'","'||bill_r.credit_hold||'","'||bill_r.last_update_date||'"');

         exception
          when utl_file.invalid_mode then
            fnd_file.put_line(fnd_file.log,'The open_mode parameter in FOPEN is invalid');
            dbms_output.put_line('The open_mode parameter in FOPEN is invalid');
            errbuf   := 1;
            retcode  := 'UTL_FILE Error';
          when utl_file.invalid_path then
            fnd_file.put_line(fnd_file.log,'Specified path does not exist or is not visible to Oracle');
            dbms_output.put_line('Specified path does not exist or is not visible to Oracle');
            errbuf   := 1;
            retcode  := 'UTL_FILE Error';
          when utl_file.invalid_filehandle then
            fnd_file.put_line(fnd_file.log,'File handle does not exist');
            dbms_output.put_line('File handle does not exist');
            errbuf   := 1;
            retcode  := 'UTL_FILE Error';
          when utl_file.internal_error then
            fnd_file.put_line(fnd_file.log,'Unhandled internal error in the UTL_FILE package');
            dbms_output.put_line('Unhandled internal error in the UTL_FILE package');
            errbuf   := 1;
            retcode  := 'UTL_FILE Error';
          when utl_file.file_open then
            fnd_file.put_line(fnd_file.log,'File is already open');
            dbms_output.put_line('File is already open');
            errbuf   := 1;
            retcode  := 'UTL_FILE Error';
          when utl_file.invalid_maxlinesize then
            fnd_file.put_line(fnd_file.log,'The MAX_LINESIZE value for FOPEN() is invalid; it should be within the range 1 to 32767');
            dbms_output.put_line('The MAX_LINESIZE value for FOPEN() is invalid; it should be within the range 1 to 32767');
            errbuf   := 1;
            retcode  := 'UTL_FILE Error';
          when utl_file.invalid_operation then
            fnd_file.put_line(fnd_file.log,'File could not be opened or operated on as requested' );
            dbms_output.put_line('File could not be opened or operated on as requested' );
            errbuf   := 1;
            retcode  := 'UTL_FILE Error';
          when utl_file.write_error then
            fnd_file.put_line(fnd_file.log,'Unable to write to file');
            dbms_output.put_line('Unable to write to file');
            errbuf   := 1;
            retcode  := 'UTL_FILE Error';
          when utl_file.access_denied then
            fnd_file.put_line(fnd_file.log,'Access to the file has been denied by the operating system');
            dbms_output.put_line('Access to the file has been denied by the operating system');
            errbuf   := 1;
            retcode  := 'UTL_FILE Error';
          when others then
            fnd_file.put_line(fnd_file.log,'Unknown UTL_FILE Error');
            dbms_output.put_line('Unknown UTL_FILE Error - '||sqlerrm);
            errbuf   := 1;
            retcode  := 'UTL_FILE Error';
        end;
      end loop; -- write to file
      -- close the created file
      utl_file.fclose(file => l_file_handler);

      -- get ftp login details according to environment
      get_ftp_login_details (p_login_url => l_login_url,  -- o v  'Files.stratasys.com'
                             p_user      => l_user_name,  -- o v  'OBJSSYSDATAXFER'
                             p_password  => l_password,   -- o v  'Sh0k0l@d72'
                             p_err_code  => l_err_code,   -- o v
                             p_err_desc  => l_err_desc);  -- o v

      -- transfer file to stratasys
      fnd_file.put_line(fnd_file.log,'l_login_url - '||l_login_url);
      fnd_file.put_line(fnd_file.log,'l_user_name - '||l_user_name);
      fnd_file.put_line(fnd_file.log,'l_password - '||l_password);
      fnd_file.put_line(fnd_file.log,'l_file_location - '||l_file_location);
      fnd_file.put_line(fnd_file.log,'l_file_name - '||l_file_name);

      l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                                 program     => 'XXFTP',
                                                 argument1   => l_login_url,
                                                 argument2   => l_user_name,
                                                 argument3   => l_password,
                                                 argument4   => l_file_location,
                                                 argument5   => l_file_name);
      commit;
      fnd_file.put_line(fnd_file.log,'ftp request id - '||l_request_id);
      if l_temp = 'Y' then
        while l_error_flag = FALSE loop
          l_count := l_count + 1;
          l_result := fnd_concurrent.wait_for_request(l_request_id , 5, 86400,
                                                      l_phase,
                                                      l_status,
                                                      l_dev_phase,
                                                      l_dev_status,
                                                      l_message);

          if (l_dev_phase = 'COMPLETE' and l_dev_status = 'NORMAL') then
            l_error_flag := TRUE;
            retcode := 0;
          elsif (l_dev_phase = 'COMPLETE' and l_dev_status <> 'NORMAL') then
            l_error_flag := TRUE;
            retcode := 1;
            fnd_file.put_line(fnd_file.log,'Request finished in error or warrning, did not transfer file. - '||l_message);
          end if; -- dev_phase
        end loop; -- l_error_flag
      else
        fnd_file.put_line(fnd_file.log,'No data to transfer.');
      end if;
    end if;-- l_count
  exception
   when others then
      errbuf   := 2;
      retcode  := 'Procedure costomer_billing_ftp failed'||substr(sqlerrm,1,240);
      fnd_file.put_line(fnd_file.log,'Procedure costomer_billing_ftp failed - '||sqlerrm);
      dbms_output.put_line('Procedure costomer_billing_ftp failed - '||substr(sqlerrm,1,240));
  end customer_billing_ftp;

  --------------------------------------------------------------------
  --  name:            customer_shipping_ftp
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   16/08/2012 15:59:19
  --------------------------------------------------------------------
  --  purpose :        transfer customer shipping details from oracle to stratasys Sales force
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16/08/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure customer_shipping_ftp (errbuf     out varchar2,
                                   retcode    out varchar2,
                                   p_num_days in  number) is

  cursor ship_c is
      select v.Organization_name, v.cust_num,
             replace(v.cust_name,'"','') cust_name, v.site_number, v.status,
             replace(v.address1,'"','') address1,
             replace(v.address2,'"','') address2,
             replace(v.address3,'"','') address3,
             replace(v.address4,'"','') address4,
             v.city, v.state, v.postal_code, v.country, v.category_code, v.cust_type_desc,
             v.terms_name, v.terms_description, v.slsman, v.slsman_name, v.inco_terms, v.fob, v.currency_code,
             v.shipping_method, v.freight_terms,v.whse,
             to_char(v.last_update_date,'DD-MON-YYYY HH24:MI:SS') last_update_date
      from   xxoa2ssys_customer_shipping_v v
      where  v.last_update_date            > sysdate - p_num_days;

    l_file_name      varchar2(150) := null;
    l_file_handler   utl_file.file_type;
    l_env            varchar2(150) := null;
    l_user_name      varchar2(150);
    l_password       varchar2(150);
    l_login_url      varchar2(150);
    l_err_code       varchar2(150);
    l_err_desc       varchar2(150);

    l_file_location  varchar2(240) := null;
    l_request_id     number;
    l_error_flag     boolean := FALSE;
    l_count          number  := 0;
    l_phase          varchar2(20);
    l_status         varchar2(20);
    l_dev_phase      varchar2(20);
    l_dev_status     varchar2(20);
    l_message        varchar2(100);
    l_result         boolean;
    l_temp           varchar2(1) := 'N';
    l_count1         number      := 0;
  begin
    errbuf  := null;
    retcode := 0;

    select count(1)
    into   l_count1
    from   xxoa2ssys_customer_shipping_v v
    where  1 =1
    and    v.last_update_date           > sysdate - p_num_days;

    if l_count1 = 0 then
      FND_FILE.PUT_LINE(FND_FILE.LOG,'There is no data to transfer');
      dbms_output.put_line('There is no data to transfer');
    else
      l_file_name := get_file_name ('SHIP');
      l_env       := xxobjt_fnd_attachments.get_environment_name;
      -- get file location
      if l_env <> 'PROD' then
        l_env := 'DEV';
      end if;
      l_file_location := '/UtlFiles/shared/'||l_env||'/LOG/ftp'; --'/UtlFiles/shared/TEST/LOG/ftp';

      -- open new file with the SR number as name
      l_file_handler := utl_file.fopen ( location     => l_file_location,
                                         filename     => l_file_name,
                                         open_mode    => 'w',
                                         max_linesize => 32767);

      -- start write to the file
      utl_file.put_line (file   => l_file_handler,
                         buffer => '"ORGANIZATION_NAME","CUST_NUM","CUST_NAME","SITE_NUMBER","STATUS","ADDRESS1","ADDRESS2","ADDRESS3","ADDRESS4","CITY",'||
                                   '"STATE","POSTAL_CODE","COUNTRY","CATEGORY_CODE","CUST_TYPE_DESC","TERMS_NAME","TERMS_DESCRIPTION","SLSMAN",'||
                                   '"SLSMAN_NAME","INCO_TERMS","FOB","CURRENCY_CODE","SHIPPING_METHOD","FREIGHT_TERMS","WHSE","LAST_UPDATE_DATE"');
      for ship_r in ship_c loop
        begin
          l_temp := 'Y';
          utl_file.put_line (file   => l_file_handler,
                             buffer => '"'||ship_r.organization_name||'","'||ship_r.cust_num||'","'||ship_r.cust_name||'","'||ship_r.site_number||'","'||
                                       ship_r.status||'","'||ship_r.address1||'","'||ship_r.address2||'","'||ship_r.address3||'","'||ship_r.address4||'","'||
                                       ship_r.city||'","'||ship_r.state||'","'||ship_r.postal_code||'","'||ship_r.country||'","'||ship_r.category_code||'","'||
                                       ship_r.cust_type_desc||'","'||ship_r.terms_name||'","'||ship_r.terms_description||'","'||ship_r.slsman||'","'||
                                       ship_r.slsman_name||'","'||ship_r.inco_terms||'","'||ship_r.fob||'","'||ship_r.currency_code||'","'||
                                       ship_r.shipping_method||'","'||ship_r.freight_terms||'","'||ship_r.whse||'","'||ship_r.last_update_date||'"');

         exception
          when utl_file.invalid_mode then
            fnd_file.put_line(fnd_file.log,'The open_mode parameter in FOPEN is invalid');
            dbms_output.put_line('The open_mode parameter in FOPEN is invalid');
            errbuf   := 1;
            retcode  := 'UTL_FILE Error';
          when utl_file.invalid_path then
            fnd_file.put_line(fnd_file.log,'Specified path does not exist or is not visible to Oracle');
            dbms_output.put_line('Specified path does not exist or is not visible to Oracle');
            errbuf   := 1;
            retcode  := 'UTL_FILE Error';
          when utl_file.invalid_filehandle then
            fnd_file.put_line(fnd_file.log,'File handle does not exist');
            dbms_output.put_line('File handle does not exist');
            errbuf   := 1;
            retcode  := 'UTL_FILE Error';
          when utl_file.internal_error then
            fnd_file.put_line(fnd_file.log,'Unhandled internal error in the UTL_FILE package');
            dbms_output.put_line('Unhandled internal error in the UTL_FILE package');
            errbuf   := 1;
            retcode  := 'UTL_FILE Error';
          when utl_file.file_open then
            fnd_file.put_line(fnd_file.log,'File is already open');
            dbms_output.put_line('File is already open');
            errbuf   := 1;
            retcode  := 'UTL_FILE Error';
          when utl_file.invalid_maxlinesize then
            fnd_file.put_line(fnd_file.log,'The MAX_LINESIZE value for FOPEN() is invalid; it should be within the range 1 to 32767');
            dbms_output.put_line('The MAX_LINESIZE value for FOPEN() is invalid; it should be within the range 1 to 32767');
            errbuf   := 1;
            retcode  := 'UTL_FILE Error';
          when utl_file.invalid_operation then
            fnd_file.put_line(fnd_file.log,'File could not be opened or operated on as requested' );
            dbms_output.put_line('File could not be opened or operated on as requested' );
            errbuf   := 1;
            retcode  := 'UTL_FILE Error';
          when utl_file.write_error then
            fnd_file.put_line(fnd_file.log,'Unable to write to file');
            dbms_output.put_line('Unable to write to file');
            errbuf   := 1;
            retcode  := 'UTL_FILE Error';
          when utl_file.access_denied then
            fnd_file.put_line(fnd_file.log,'Access to the file has been denied by the operating system');
            dbms_output.put_line('Access to the file has been denied by the operating system');
            errbuf   := 1;
            retcode  := 'UTL_FILE Error';
          when others then
            fnd_file.put_line(fnd_file.log,'Unknown UTL_FILE Error');
            dbms_output.put_line('Unknown UTL_FILE Error - '||sqlerrm);
            errbuf   := 1;
            retcode  := 'UTL_FILE Error';
        end;
      end loop; -- write to file
      -- close the created file
      utl_file.fclose(file => l_file_handler);

      -- get ftp login details according to environment
      get_ftp_login_details (p_login_url => l_login_url,  -- o v  'Files.stratasys.com'
                             p_user      => l_user_name,  -- o v  'OBJSSYSDATAXFER'
                             p_password  => l_password,   -- o v  'Sh0k0l@d72'
                             p_err_code  => l_err_code,   -- o v
                             p_err_desc  => l_err_desc);  -- o v

      -- transfer file to stratasys
      fnd_file.put_line(fnd_file.log,'l_login_url - '||l_login_url);
      fnd_file.put_line(fnd_file.log,'l_user_name - '||l_user_name);
      fnd_file.put_line(fnd_file.log,'l_password - '||l_password);
      fnd_file.put_line(fnd_file.log,'l_file_location - '||l_file_location);
      fnd_file.put_line(fnd_file.log,'l_file_name - '||l_file_name);

      l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                                 program     => 'XXFTP',
                                                 argument1   => l_login_url,
                                                 argument2   => l_user_name,
                                                 argument3   => l_password,
                                                 argument4   => l_file_location,
                                                 argument5   => l_file_name);
      commit;
      fnd_file.put_line(fnd_file.log,'ftp request id - '||l_request_id);
      if l_temp = 'Y' then
        while l_error_flag = FALSE loop
          l_count := l_count + 1;
          l_result := fnd_concurrent.wait_for_request(l_request_id , 5, 86400,
                                                      l_phase,
                                                      l_status,
                                                      l_dev_phase,
                                                      l_dev_status,
                                                      l_message);

          if (l_dev_phase = 'COMPLETE' and l_dev_status = 'NORMAL') then
            l_error_flag := TRUE;
            retcode := 0;
          elsif (l_dev_phase = 'COMPLETE' and l_dev_status <> 'NORMAL') then
            l_error_flag := TRUE;
            retcode := 1;
            fnd_file.put_line(fnd_file.log,'Request finished in error or warrning, did not transfer file. - '||l_message);
          end if; -- dev_phase
        end loop; -- l_error_flag
      else
        fnd_file.put_line(fnd_file.log,'No data to transfer.');
      end if;
    end if; -- l_count1
  exception
   when others then
      errbuf   := 2;
      retcode  := 'Procedure costomer_shipping_ftp failed'||substr(sqlerrm,1,240);
      fnd_file.put_line(fnd_file.log,'Procedure costomer_shipping_ftp failed - '||sqlerrm);
      dbms_output.put_line('Procedure costomer_shipping_ftp failed - '||substr(sqlerrm,1,240));
  end customer_shipping_ftp;

  --------------------------------------------------------------------
  --  name:            order_ftp
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   16/08/2012 15:59:19
  --------------------------------------------------------------------
  --  purpose :        transfer order details from oracle to stratasys Sales force
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16/08/2012  Dalit A. Raviv    initial build
  --  1.1  17/10/2012  Idan yefet        add 2 fields
  --------------------------------------------------------------------
  procedure order_ftp (errbuf     out varchar2,
                       retcode    out varchar2,
                       p_num_days in  number) is

    cursor order_c is
      select v.organization_name, v.order_num, v.cust_num,
             v.shipping_site_num, v.billing_site_num,
             to_char(v.order_date,'DD-MON-YYYY HH24:MI:SS') order_date , v.status, v.line_num, v.item,
             --
             v.quantity, v.uom, v.currency, v.unit_selling_price,  --  1.1  17/10/2012  Idan yefet
             --
             v.line_status, v.sfdc_order_id, v.fulfillment_date, v.fulfilled_flag,
             to_char(v.last_return_date,'DD-MON-YYYY HH24:MI:SS') last_return_date, v.pick_order_status, v.delivery_number,
             --
             v.serial_number,
             --
             to_char(v.ship_date,'DD-MON-YYYY HH24:MI:SS') ship_date , v.carrier, v.primarytracking, v.waybill,
             to_char(v.last_update_date,'DD-MON-YYYY HH24:MI:SS') last_update_date
      from   xxoa2ssys_order_details_v v
      where  v.last_update_date        > sysdate - p_num_days;

    l_file_name      varchar2(150) := null;
    l_file_handler   utl_file.file_type;
    l_env            varchar2(150) := null;
    l_user_name      varchar2(150);
    l_password       varchar2(150);
    l_login_url      varchar2(150);
    l_err_code       varchar2(150);
    l_err_desc       varchar2(150);

    l_file_location  varchar2(240) := null;
    l_request_id     number;
    l_error_flag     boolean := FALSE;
    l_count          number  := 0;
    l_phase          varchar2(20);
    l_status         varchar2(20);
    l_dev_phase      varchar2(20);
    l_dev_status     varchar2(20);
    l_message        varchar2(100);
    l_result         boolean;
    l_temp           varchar2(1) := 'N';
    l_count1         number      := 0;
  begin
    errbuf  := null;
    retcode := 0;

    select count(1)
    into   l_count1
    from   xxoa2ssys_order_details_v v
    where  v.last_update_date        > sysdate - p_num_days;

    if l_count1 = 0 then
      FND_FILE.PUT_LINE(FND_FILE.LOG,'There is no data to transfer');
      dbms_output.put_line('There is no data to transfer');
    else

      l_file_name := get_file_name ('ORDER');
      l_env       := xxobjt_fnd_attachments.get_environment_name;
      -- get file location
      if l_env <> 'PROD' then
        l_env := 'DEV';
      end if;
      l_file_location := '/UtlFiles/shared/'||l_env||'/LOG/ftp'; --'/UtlFiles/shared/TEST/LOG/ftp';

      -- open new file with the SR number as name
      l_file_handler := utl_file.fopen ( location  => l_file_location,
                                         filename  => l_file_name,
                                         open_mode => 'w');

     -- start write to the file
      utl_file.put_line (file   => l_file_handler,
                         buffer => '"ORGANIZATION_NAME","ORDER_NUM","CUST_NUM","SHIPPING_SITE_NUM","BILLING_SITE_NUM","ORDER_DATE","STATUS","LINE_NUM","ITEM","QUANTITY",'||
                                   '"UOM","CURRENCY","UNIT_SELLING_PRICE","LINE_STATUS","SFDC_ORDER_ID","FULFILLMENT_DATE","FULFILLED_FLAG","LAST_RETURN_DATE",'||
                                   '"PICK_ORDER_STATUS","DELIVERY_NUMBER","SERIAL_NUMBER","SHIP_DATE","CARRIER","PRIMARYTRACKING","WAYBILL","LAST_UPDATE_DATE"');
      for order_r in order_c loop
        begin
          l_temp := 'Y';
          utl_file.put_line (file   => l_file_handler,
                             buffer => '"'||order_r.organization_name||'","'||order_r.order_num||'","'||order_r.cust_num||'","'||order_r.shipping_site_num||'","'||
                                       order_r.billing_site_num||'","'||order_r.order_date||'","'||order_r.status||'","'||order_r.line_num||'","'||order_r.item||'","'||
                                       order_r.quantity||'","'||order_r.uom||'","'||order_r.currency||'","'||order_r.unit_selling_price||'","'||order_r.line_status||'","'||
                                       order_r.sfdc_order_id||'","'||order_r.fulfillment_date||'","'||order_r.fulfilled_flag||'","'||
                                       order_r.last_return_date||'","'||order_r.pick_order_status||'","'||order_r.delivery_number||'","'||order_r.serial_number||'","'||
                                       order_r.ship_date||'","'||order_r.carrier||'","'||order_r.primarytracking||'","'||order_r.waybill||'","'||order_r.last_update_date||'"');
         exception
          when utl_file.invalid_mode then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'The open_mode parameter in FOPEN is invalid');
            dbms_output.put_line('The open_mode parameter in FOPEN is invalid');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.invalid_path then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Specified path does not exist or is not visible to Oracle');
            dbms_output.put_line('Specified path does not exist or is not visible to Oracle');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.invalid_filehandle then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'File handle does not exist');
            dbms_output.put_line('File handle does not exist');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.internal_error then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Unhandled internal error in the UTL_FILE package');
            dbms_output.put_line('Unhandled internal error in the UTL_FILE package');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.file_open then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'File is already open');
            dbms_output.put_line('File is already open');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.invalid_maxlinesize then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'The MAX_LINESIZE value for FOPEN() is invalid; it should be within the range 1 to 32767');
            dbms_output.put_line('The MAX_LINESIZE value for FOPEN() is invalid; it should be within the range 1 to 32767');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.invalid_operation then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'File could not be opened or operated on as requested' );
            dbms_output.put_line('File could not be opened or operated on as requested' );
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.write_error then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Unable to write to file');
            dbms_output.put_line('Unable to write to file');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.access_denied then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Access to the file has been denied by the operating system');
            dbms_output.put_line('Access to the file has been denied by the operating system');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when others then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Unknown UTL_FILE Error');
            dbms_output.put_line('Unknown UTL_FILE Error - '||sqlerrm);
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
        end;
      end loop; -- write to file
      -- close the created file
      utl_file.fclose(file => l_file_handler);

      -- get ftp login details according to environment
      get_ftp_login_details (p_login_url => l_login_url,  -- o v  'Files.stratasys.com'
                             p_user      => l_user_name,  -- o v  'OBJSSYSDATAXFER'
                             p_password  => l_password,   -- o v  'Sh0k0l@d72'
                             p_err_code  => l_err_code,   -- o v
                             p_err_desc  => l_err_desc);  -- o v

      -- transfer file to stratasys
      fnd_file.put_line(fnd_file.log,'l_login_url - '||l_login_url);
      fnd_file.put_line(fnd_file.log,'l_user_name - '||l_user_name);
      fnd_file.put_line(fnd_file.log,'l_password - '||l_password);
      fnd_file.put_line(fnd_file.log,'l_file_location - '||l_file_location);
      fnd_file.put_line(fnd_file.log,'l_file_name - '||l_file_name);

      l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                                 program     => 'XXFTP',
                                                 argument1   => l_login_url,
                                                 argument2   => l_user_name,
                                                 argument3   => l_password,
                                                 argument4   => l_file_location,
                                                 argument5   => l_file_name);
      commit;
      fnd_file.put_line(fnd_file.log,'ftp request id - '||l_request_id);
      if l_temp = 'Y' then
        while l_error_flag = FALSE loop
          l_count := l_count + 1;
          l_result := fnd_concurrent.wait_for_request(l_request_id , 5, 86400,
                                                      l_phase,
                                                      l_status,
                                                      l_dev_phase,
                                                      l_dev_status,
                                                      l_message);

          if (l_dev_phase = 'COMPLETE' and l_dev_status = 'NORMAL') then
            l_error_flag := TRUE;
            retcode := 0;
          elsif (l_dev_phase = 'COMPLETE' and l_dev_status <> 'NORMAL') then
            l_error_flag := TRUE;
            retcode := 1;
            fnd_file.put_line(fnd_file.log,'Request finished in error or warrning, did not transfer file. - '||l_message);
          end if; -- dev_phase
        end loop; -- l_error_flag
      else
        fnd_file.put_line(fnd_file.log,'No data to transfer.');
      end if;
    end if; -- l_count1
  exception
   when others then
      errbuf   := 2;
      retcode  := 'Procedure order_ftp failed'||substr(sqlerrm,1,240);
      fnd_file.put_line(fnd_file.log,'Procedure order_ftp failed - '||sqlerrm);
      dbms_output.put_line('Procedure order_ftp failed - '||substr(sqlerrm,1,240));
  end order_ftp;

  --------------------------------------------------------------------
  --  name:            contract_ftp
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   16/08/2012 15:59:19
  --------------------------------------------------------------------
  --  purpose :        transfer contract details from oracle to stratasys Sales force
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16/08/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure contract_ftp (errbuf     out varchar2,
                          retcode    out varchar2,
                          p_num_days in  number) is   -- xxoa2ssys_Service_Contract_v

  cursor contract_c is
      select v.organization_name, v.order_num, v.line_num, v.item, v.inv_num, v.inv_line_num,
             to_char(v.inv_date,'DD-MON-YYYY HH24:MI:SS') inv_date, v.cust_num, v.serial_number,
             v.Start_maintenance_date, v.End_maintenance_date,
             to_char(v.last_update_date,'DD-MON-YYYY HH24:MI:SS') last_update_date
      from   xxoa2ssys_Service_Contract_v v
      where  v.last_update_date           > sysdate - p_num_days;

    l_file_name      varchar2(150) := null;
    l_file_handler   utl_file.file_type;
    l_env            varchar2(150) := null;
    l_user_name      varchar2(150);
    l_password       varchar2(150);
    l_login_url      varchar2(150);
    l_err_code       varchar2(150);
    l_err_desc       varchar2(150);

    l_file_location  varchar2(240) := null;
    l_request_id     number;
    l_error_flag     boolean := FALSE;
    l_count          number  := 0;
    l_phase          varchar2(50);
    l_status         varchar2(50);
    l_dev_phase      varchar2(50);
    l_dev_status     varchar2(50);
    l_message        varchar2(500);
    l_result         boolean;
    l_temp           varchar2(1) := 'N';
    l_count1         number      := 0;
  begin
    errbuf  := null;
    retcode := 0;

    select count(1)
    into   l_count1
    from   xxoa2ssys_Service_Contract_v v
    where  v.last_update_date           > sysdate - p_num_days;

    if l_count1 = 0 then
      FND_FILE.PUT_LINE(FND_FILE.LOG,'There is no data to transfer');
      dbms_output.put_line('There is no data to transfer');
    else
      l_file_name := get_file_name ('CONTRACT');
      l_env       := xxobjt_fnd_attachments.get_environment_name;
      -- get file location
      if l_env <> 'PROD' then
        l_env := 'DEV';
      end if;
      l_file_location := '/UtlFiles/shared/'||l_env||'/LOG/ftp'; --'/UtlFiles/shared/TEST/LOG/ftp';

      -- open new file with the SR number as name
      l_file_handler := utl_file.fopen ( location  => l_file_location,
                                         filename  => l_file_name,
                                         open_mode => 'w');

      -- start write to the file
      utl_file.put_line (file   => l_file_handler,
                         buffer => '"ORGANIZATION_NAME","ORDER_NUM","LINE_NUM","ITEM","INV_NUM","INV_LINE_NUM","INV_DATE","CUST_NUM","SERIAL_NUMBER","START_MAINTENANCE_DATE","END_MAINTENANCE_DATE","LAST_UPDATE_DATE"');

      for cont_r in contract_c loop
        begin
          l_temp := 'Y';
          utl_file.put_line (file   => l_file_handler,
                             buffer => '"'||cont_r.organization_name||'","'||cont_r.order_num||'","'||cont_r.line_num||'","'||cont_r.item||'","'||
                                       cont_r.inv_num||'","'||cont_r.inv_line_num||'","'||cont_r.inv_date||'","'||cont_r.cust_num||'","'||cont_r.serial_number||'","'||
                                       cont_r.Start_maintenance_date||'","'||cont_r.End_maintenance_date||'","'||cont_r.last_update_date||'"');
         exception
          when utl_file.invalid_mode then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'The open_mode parameter in FOPEN is invalid');
            dbms_output.put_line('The open_mode parameter in FOPEN is invalid');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.invalid_path then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Specified path does not exist or is not visible to Oracle');
            dbms_output.put_line('Specified path does not exist or is not visible to Oracle');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.invalid_filehandle then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'File handle does not exist');
            dbms_output.put_line('File handle does not exist');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.internal_error then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Unhandled internal error in the UTL_FILE package');
            dbms_output.put_line('Unhandled internal error in the UTL_FILE package');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.file_open then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'File is already open');
            dbms_output.put_line('File is already open');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.invalid_maxlinesize then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'The MAX_LINESIZE value for FOPEN() is invalid; it should be within the range 1 to 32767');
            dbms_output.put_line('The MAX_LINESIZE value for FOPEN() is invalid; it should be within the range 1 to 32767');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.invalid_operation then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'File could not be opened or operated on as requested' );
            dbms_output.put_line('File could not be opened or operated on as requested' );
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.write_error then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Unable to write to file');
            dbms_output.put_line('Unable to write to file');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.access_denied then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Access to the file has been denied by the operating system');
            dbms_output.put_line('Access to the file has been denied by the operating system');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when others then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Unknown UTL_FILE Error');
            dbms_output.put_line('Unknown UTL_FILE Error - '||sqlerrm);
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
        end;
      end loop; -- write to file
      -- close the created file

      utl_file.fclose(file => l_file_handler);

      -- get ftp login details according to environment
      get_ftp_login_details (p_login_url => l_login_url,  -- o v  'Files.stratasys.com'
                             p_user      => l_user_name,  -- o v  'OBJSSYSDATAXFER'
                             p_password  => l_password,   -- o v  'Sh0k0l@d72'
                             p_err_code  => l_err_code,   -- o v
                             p_err_desc  => l_err_desc);  -- o v

      -- transfer file to stratasys
      fnd_file.put_line(fnd_file.log,'l_login_url - '||l_login_url);
      fnd_file.put_line(fnd_file.log,'l_user_name - '||l_user_name);
      fnd_file.put_line(fnd_file.log,'l_password - '||l_password);
      fnd_file.put_line(fnd_file.log,'l_file_location - '||l_file_location);
      fnd_file.put_line(fnd_file.log,'l_file_name - '||l_file_name);

      l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                                 program     => 'XXFTP',
                                                 argument1   => l_login_url,
                                                 argument2   => l_user_name,
                                                 argument3   => l_password,
                                                 argument4   => l_file_location,
                                                 argument5   => l_file_name);
      commit;
      fnd_file.put_line(fnd_file.log,'ftp request id - '||l_request_id);
      if l_temp = 'Y' then
        while l_error_flag = FALSE loop
          l_count := l_count + 1;
          l_result := fnd_concurrent.wait_for_request(l_request_id , 5, 86400,
                                                      l_phase,
                                                      l_status,
                                                      l_dev_phase,
                                                      l_dev_status,
                                                      l_message);

          if (l_dev_phase = 'COMPLETE' and l_dev_status = 'NORMAL') then
            l_error_flag := TRUE;
            retcode := 0;
          elsif (l_dev_phase = 'COMPLETE' and l_dev_status <> 'NORMAL') then
            l_error_flag := TRUE;
            retcode := 1;
            fnd_file.put_line(fnd_file.log,'Request finished in error or warrning, did not transfer file. - '||l_message);
          end if; -- dev_phase
        end loop; -- l_error_flag
      else
        fnd_file.put_line(fnd_file.log,'No data to transfer.');
      end if;
    end if; -- l_count1
  exception
   when others then
      errbuf   := 2;
      retcode  := 'Procedure contract_ftp failed'||substr(sqlerrm,1,240);
      fnd_file.put_line(fnd_file.log,'Procedure contract_ftp failed - '||sqlerrm);
      dbms_output.put_line('Procedure contract_ftp failed - '||substr(sqlerrm,1,240));
  end contract_ftp;

  --------------------------------------------------------------------
  --  name:            po_ftp
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   03/102012
  --------------------------------------------------------------------
  --  purpose :        transfer PO information with no receving to
  --                   Syteline (ssys) by FTP.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  03/102012   Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure po_ftp (errbuf     out varchar2,
                    retcode    out varchar2) is

    cursor pono_rcv_c is
      select item, vendor, to_char(po_date,'DD-MON-YYYY HH24:MI:SS') po_date,
             purchase_order, purchase_order_line,
             so_number, quantity_ordered, quantity_received,
             to_char(date_received,'DD-MON-YYYY HH24:MI:SS') date_received,
             uom, transfer_price_per_unit, total_transfer_price
      from   xxoa2syteline_po_v v;

    l_file_name      varchar2(150) := null;
    l_file_handler   utl_file.file_type;
    l_env            varchar2(150) := null;
    l_user_name      varchar2(150);
    l_password       varchar2(150);
    l_login_url      varchar2(150);
    l_err_code       varchar2(150);
    l_err_desc       varchar2(150);

    l_file_location  varchar2(240) := null;
    l_request_id     number;
    l_error_flag     boolean := FALSE;
    l_count          number  := 0;
    l_phase          varchar2(20);
    l_status         varchar2(20);
    l_dev_phase      varchar2(20);
    l_dev_status     varchar2(20);
    l_message        varchar2(100);
    l_result         boolean;
    l_temp           varchar2(1) := 'N';
    l_count1          number      := 0;
  begin
    errbuf  := null;
    retcode := 0;

    select count(1)
    into   l_count1
    from   xxoa2syteline_po_v v;

    if l_count1 = 0 then
      FND_FILE.PUT_LINE(FND_FILE.LOG,'There is no data to transfer');
      dbms_output.put_line('There is no data to transfer');
    else
      l_file_name := get_file_name ('PO');
      l_env       := xxobjt_fnd_attachments.get_environment_name;
      -- get file location
      if l_env <> 'PROD' then
        l_env := 'DEV';
      end if;
      l_file_location := '/UtlFiles/shared/'||l_env||'/LOG/ftp'; --'/UtlFiles/shared/TEST/LOG/ftp';
      
      -- open new file with the SR number as name
      l_file_handler := utl_file.fopen ( location  => l_file_location,
                                         filename  => l_file_name,
                                         open_mode => 'w');

      -- start write to the file
      utl_file.put_line (file   => l_file_handler,
                         buffer => '"ITEM","VENDOR","PO_DATE","PURCHASE_ORDER","PURCHASE_ORDER_LINE",'||
                                   '"SO_NUMBER","QUANTITY_ORDERED","QUANTITY_RECEIVED","DATE_RECEIVED","UOM","TRANSFER_PRICE_PER_UNIT","TOTAL_TRANSFER_PRICE"');

      for pono_rcv_r in pono_rcv_c loop
        begin
          l_temp := 'Y';
          utl_file.put_line (file   => l_file_handler,
                             buffer => '"'||pono_rcv_r.item||'","'||pono_rcv_r.vendor||'","'||pono_rcv_r.po_date||'","'||pono_rcv_r.purchase_order||
                                       '","'||pono_rcv_r.purchase_order_line||'","'||pono_rcv_r.so_number||'","'||pono_rcv_r.quantity_ordered||
                                       '","'||pono_rcv_r.quantity_received||'","'||pono_rcv_r.date_received||'","'||pono_rcv_r.uom||
                                       '","'||pono_rcv_r.transfer_price_per_unit||'","'||pono_rcv_r.total_transfer_price||'"');
         exception
          when utl_file.invalid_mode then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'The open_mode parameter in FOPEN is invalid');
            dbms_output.put_line('The open_mode parameter in FOPEN is invalid');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.invalid_path then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Specified path does not exist or is not visible to Oracle');
            dbms_output.put_line('Specified path does not exist or is not visible to Oracle');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.invalid_filehandle then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'File handle does not exist');
            dbms_output.put_line('File handle does not exist');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.internal_error then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Unhandled internal error in the UTL_FILE package');
            dbms_output.put_line('Unhandled internal error in the UTL_FILE package');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.file_open then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'File is already open');
            dbms_output.put_line('File is already open');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.invalid_maxlinesize then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'The MAX_LINESIZE value for FOPEN() is invalid; it should be within the range 1 to 32767');
            dbms_output.put_line('The MAX_LINESIZE value for FOPEN() is invalid; it should be within the range 1 to 32767');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.invalid_operation then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'File could not be opened or operated on as requested' );
            dbms_output.put_line('File could not be opened or operated on as requested' );
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.write_error then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Unable to write to file');
            dbms_output.put_line('Unable to write to file');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.access_denied then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Access to the file has been denied by the operating system');
            dbms_output.put_line('Access to the file has been denied by the operating system');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when others then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Unknown UTL_FILE Error');
            dbms_output.put_line('Unknown UTL_FILE Error - '||sqlerrm);
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
        end;
      end loop; -- write to file
      -- close the created file
      utl_file.fclose(file => l_file_handler);

      -- get ftp login details according to environment
      get_ftp_login_details (p_login_url => l_login_url,  -- o v  'Files.stratasys.com'
                             p_user      => l_user_name,  -- o v  'OBJSSYSDATAXFER'
                             p_password  => l_password,   -- o v  'Sh0k0l@d72'
                             p_err_code  => l_err_code,   -- o v
                             p_err_desc  => l_err_desc);  -- o v

      -- transfer file to stratasys
      fnd_file.put_line(fnd_file.log,'l_login_url - '||l_login_url);
      fnd_file.put_line(fnd_file.log,'l_user_name - '||l_user_name);
      fnd_file.put_line(fnd_file.log,'l_password - '||l_password);
      fnd_file.put_line(fnd_file.log,'l_file_location - '||l_file_location);
      fnd_file.put_line(fnd_file.log,'l_file_name - '||l_file_name);

      if l_temp = 'Y' then

        l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                                   program     => 'XXFTP',
                                                   argument1   => l_login_url,
                                                   argument2   => l_user_name,
                                                   argument3   => l_password,
                                                   argument4   => l_file_location,
                                                   argument5   => l_file_name);
        commit;
        fnd_file.put_line(fnd_file.log,'ftp request id - '||l_request_id);
        while l_error_flag = FALSE loop
          l_count := l_count + 1;
          l_result := fnd_concurrent.wait_for_request(l_request_id , 5, 86400,
                                                      l_phase,
                                                      l_status,
                                                      l_dev_phase,
                                                      l_dev_status,
                                                      l_message);

          if (l_dev_phase = 'COMPLETE' and l_dev_status = 'NORMAL') then
            l_error_flag := TRUE;
            retcode := 0;
          elsif (l_dev_phase = 'COMPLETE' and l_dev_status <> 'NORMAL') then
            l_error_flag := TRUE;
            retcode := 1;
            fnd_file.put_line(fnd_file.log,'Request finished in error or warrning, did not transfer file. - '||l_message);
          end if; -- dev_phase
        end loop; -- l_error_flag
      else
        fnd_file.put_line(fnd_file.log,'No data to transfer.');
      end if;
    end if; -- l_count
  exception
   when others then
      errbuf   := 2;
      retcode  := 'Procedure po_ftp failed'||substr(sqlerrm,1,240);
      fnd_file.put_line(fnd_file.log,'Procedure po_ftp failed - '||sqlerrm);
      dbms_output.put_line('Procedure po_ftp failed - '||substr(sqlerrm,1,240));
  end po_ftp;

  --------------------------------------------------------------------
  --  name:            rcv_ftp
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   03/102012
  --------------------------------------------------------------------
  --  purpose :        transfer PO information with receving to
  --                   Syteline (ssys) by FTP.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  03/102012   Dalit A. Raviv    initial build
  --  1.1  20/03/2013  Dalit A. Raviv    add column quantity_billed
  --  1.2  14/04/2013  Dalit A. Raviv    take out Received date  
  --------------------------------------------------------------------
  procedure rcv_ftp (errbuf     out varchar2,
                     retcode    out varchar2) is

    cursor powith_rcv_c is
      select item, vendor, to_char(po_date,'DD-MON-YYYY HH24:MI:SS') po_date,
             purchase_order, purchase_order_line,
             so_number, quantity_ordered, quantity_received,
             -- to_char(date_received,'DD-MON-YYYY HH24:MI:SS') date_received, 1.2 14/04/2013 Dalit A. Raviv 
             quantity_billed,
             uom, transfer_price_per_unit, total_transfer_price
      from   xxoa2syteline_rcv_v v;

    l_file_name      varchar2(150) := null;
    l_file_handler   utl_file.file_type;
    l_env            varchar2(150) := null;
    l_user_name      varchar2(150);
    l_password       varchar2(150);
    l_login_url      varchar2(150);
    l_err_code       varchar2(150);
    l_err_desc       varchar2(150);

    l_file_location  varchar2(240) := null;
    l_request_id     number;
    l_error_flag     boolean := FALSE;
    l_count          number  := 0;
    l_phase          varchar2(20);
    l_status         varchar2(20);
    l_dev_phase      varchar2(20);
    l_dev_status     varchar2(20);
    l_message        varchar2(100);
    l_result         boolean;
    l_temp           varchar2(1) := 'N';
    l_count1          number      := 0;
  begin
    errbuf  := null;
    retcode := 0;

    select count(1)
    into   l_count1
    from   xxoa2syteline_rcv_v v;

    if l_count1 = 0 then
      FND_FILE.PUT_LINE(FND_FILE.LOG,'There is no data to transfer');
      dbms_output.put_line('There is no data to transfer');
    else
      l_file_name := get_file_name ('RCV');
      l_env       := xxobjt_fnd_attachments.get_environment_name;
      -- get file location
      if l_env <> 'PROD' then
        l_env := 'DEV';
      end if;
      l_file_location := '/UtlFiles/shared/'||l_env||'/LOG/ftp'; --'/UtlFiles/shared/TEST/LOG/ftp';
      
      -- open new file with the SR number as name
      l_file_handler := utl_file.fopen ( location  => l_file_location,
                                         filename  => l_file_name,
                                         open_mode => 'w');

      -- start write to the file
      utl_file.put_line (file   => l_file_handler,
                         buffer => '"ITEM","VENDOR","PO_DATE","PURCHASE_ORDER","PURCHASE_ORDER_LINE",'||
                                   '"SO_NUMBER","QUANTITY_ORDERED","QUANTITY_RECEIVED","QUANTITY_BILLED","UOM","TRANSFER_PRICE_PER_UNIT","TOTAL_TRANSFER_PRICE"');
      --  1.2  14/04/2013  Dalit A. Raviv
      -- '"SO_NUMBER","QUANTITY_ORDERED","QUANTITY_RECEIVED",/*"DATE_RECEIVED",*/"QUANTITY_BILLED","UOM","TRANSFER_PRICE_PER_UNIT","TOTAL_TRANSFER_PRICE"');
      for powith_rcv_r in powith_rcv_c loop
        begin
          l_temp := 'Y';
          utl_file.put_line (file   => l_file_handler,
                             buffer => '"'||powith_rcv_r.item||'","'||powith_rcv_r.vendor||'","'||powith_rcv_r.po_date||'","'||powith_rcv_r.purchase_order||
                                       '","'||powith_rcv_r.purchase_order_line||'","'||powith_rcv_r.so_number||'","'||powith_rcv_r.quantity_ordered||
                                       '","'||powith_rcv_r.quantity_received||'","'||powith_rcv_r.quantity_billed||
                                       '","'||powith_rcv_r.uom||'","'||powith_rcv_r.transfer_price_per_unit||'","'||powith_rcv_r.total_transfer_price||'"');
          --  1.2  14/04/2013  Dalit A. Raviv
          -- '","'||powith_rcv_r.quantity_received||'","'||/*powith_rcv_r.date_received||'","'||*/powith_rcv_r.quantity_billed||  
        exception
          when utl_file.invalid_mode then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'The open_mode parameter in FOPEN is invalid');
            dbms_output.put_line('The open_mode parameter in FOPEN is invalid');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.invalid_path then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Specified path does not exist or is not visible to Oracle');
            dbms_output.put_line('Specified path does not exist or is not visible to Oracle');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.invalid_filehandle then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'File handle does not exist');
            dbms_output.put_line('File handle does not exist');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.internal_error then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Unhandled internal error in the UTL_FILE package');
            dbms_output.put_line('Unhandled internal error in the UTL_FILE package');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.file_open then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'File is already open');
            dbms_output.put_line('File is already open');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.invalid_maxlinesize then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'The MAX_LINESIZE value for FOPEN() is invalid; it should be within the range 1 to 32767');
            dbms_output.put_line('The MAX_LINESIZE value for FOPEN() is invalid; it should be within the range 1 to 32767');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.invalid_operation then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'File could not be opened or operated on as requested' );
            dbms_output.put_line('File could not be opened or operated on as requested' );
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.write_error then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Unable to write to file');
            dbms_output.put_line('Unable to write to file');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.access_denied then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Access to the file has been denied by the operating system');
            dbms_output.put_line('Access to the file has been denied by the operating system');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when others then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Unknown UTL_FILE Error');
            dbms_output.put_line('Unknown UTL_FILE Error - '||sqlerrm);
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
        end;
      end loop; -- write to file
      -- close the created file
      utl_file.fclose(file => l_file_handler);

      -- get ftp login details according to environment
      get_ftp_login_details (p_login_url => l_login_url,  -- o v  'Files.stratasys.com'
                             p_user      => l_user_name,  -- o v  'OBJSSYSDATAXFER'
                             p_password  => l_password,   -- o v  'Sh0k0l@d72'
                             p_err_code  => l_err_code,   -- o v
                             p_err_desc  => l_err_desc);  -- o v

      -- transfer file to stratasys
      fnd_file.put_line(fnd_file.log,'l_login_url - '||l_login_url);
      fnd_file.put_line(fnd_file.log,'l_user_name - '||l_user_name);
      fnd_file.put_line(fnd_file.log,'l_password - '||l_password);
      fnd_file.put_line(fnd_file.log,'l_file_location - '||l_file_location);
      fnd_file.put_line(fnd_file.log,'l_file_name - '||l_file_name);

      if l_temp = 'Y' then

        l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                                   program     => 'XXFTP',
                                                   argument1   => l_login_url,
                                                   argument2   => l_user_name,
                                                   argument3   => l_password,
                                                   argument4   => l_file_location,
                                                   argument5   => l_file_name);
        commit;
        fnd_file.put_line(fnd_file.log,'ftp request id - '||l_request_id);
        while l_error_flag = FALSE loop
          l_count := l_count + 1;
          l_result := fnd_concurrent.wait_for_request(l_request_id , 5, 86400,
                                                      l_phase,
                                                      l_status,
                                                      l_dev_phase,
                                                      l_dev_status,
                                                      l_message);

          if (l_dev_phase = 'COMPLETE' and l_dev_status = 'NORMAL') then
            l_error_flag := TRUE;
            retcode := 0;
          elsif (l_dev_phase = 'COMPLETE' and l_dev_status <> 'NORMAL') then
            l_error_flag := TRUE;
            retcode := 1;
            fnd_file.put_line(fnd_file.log,'Request finished in error or warrning, did not transfer file. - '||l_message);
          end if; -- dev_phase
        end loop; -- l_error_flag
      else
        fnd_file.put_line(fnd_file.log,'No data to transfer.');
      end if;
    end if; -- l_count
  exception
   when others then
      errbuf   := 2;
      retcode  := 'Procedure rcv_ftp failed'||substr(sqlerrm,1,240);
      fnd_file.put_line(fnd_file.log,'Procedure rcv_ftp failed - '||sqlerrm);
      dbms_output.put_line('Procedure rcv_ftp failed - '||substr(sqlerrm,1,240));
  end rcv_ftp;
  
  --------------------------------------------------------------------
  --  name:            invoice_backlog_ftp
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   13/05/2013
  --------------------------------------------------------------------
  --  purpose :        Will handle all SO in status Booked and closed and not internal
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/05/2013  Dalit A. Raviv    initial build
  --  1.1  19/05/2013  Dalit A. Raviv    change the select between booking and backlog
  --------------------------------------------------------------------
  procedure invoice_backlog_ftp (errbuf  out varchar2,
                                 retcode out varchar2) is
  
    cursor inv_c /*(p_invoice_date in date)*/ is
      select average_discount, dist_functional_amount, parent_customer_location, 
             expected_shipping_month, direct_indirect_deal, org, operating_unit, 
             so_number, so_type, so_status, to_char(so_order_date,'DD-MON-YYYY HH24:MI:SS') so_order_date,
             so_ordered_date_quarter, to_char(so_sys_recognition_date,'DD-MON-YYYY HH24:MI:SS') so_sys_recognition_date, customer_number, 
             customer_name, ship_to_address5, state, zip_code, country, 
             bill_to_customer, customer_main_business_type, customer_location_segment, 
             ship_to_customer, ship_to_country, cust_po_number, line_number, 
             line_type, order_source, ordered_item, salesrep_name, 
             main_category, item_category, item_desc, order_quantity_uom, 
             ordered_qty, shipped_qty, invoiced_qty, cancelled_qty, 
             weight_kg, item_product_line_segment, schedule_ship_date, 
             schedule_arrival_date, so_line_status, invoiced_amount, invoice_number, 
             unit_selling_price, extended_price, resin_credit_amount, unit_list_price, 
             price_list_currency, price_list, freight_charges, transactional_curr_code, 
             payment_term, confirm_date,  on_hold_flag, agent_name  
      from   apps.xxinv_om_general_report_v t
      where  t.so_type          like 'Standard%'
      and    t.so_status        = 'BOOKED'
      and    t.so_line_status   not in ('CANCELLED', 'ENTERED', 'CLOSED')
      and    (t.invoiced_qty    is null or t.ordered_qty <> t.invoiced_qty)
      and    t.bill_to_customer not like '%Stratasys%'
      and    t.bill_to_customer not like '%Objet%';

    l_file_name      varchar2(150) := null;
    l_file_handler   utl_file.file_type;
    l_env            varchar2(150) := null;
    l_user_name      varchar2(150);
    l_password       varchar2(150);
    l_login_url      varchar2(150);
    l_err_code       varchar2(150);
    l_err_desc       varchar2(150);

    l_file_location  varchar2(240) := null;
    l_request_id     number;
    l_error_flag     boolean := FALSE;
    l_count          number  := 0;
    l_phase          varchar2(20);
    l_status         varchar2(20);
    l_dev_phase      varchar2(20);
    l_dev_status     varchar2(20);
    l_message        varchar2(100);
    l_result         boolean;
    l_temp           varchar2(1)  := 'N';
    l_count1         number       := 0;
    --l_so_date        date         := null;
  begin
    errbuf  := null;
    retcode := 0;
    --  1.1  19/05/2013  Dalit A. Raviv
    -- get date from profile          
    --l_so_date := to_date(fnd_profile.value('XXAR_INVALL_DATE'),'DD/MM/YYYY HH24:MI:SS');
    --
    select count(1)
    into   l_count1
    from   apps.xxinv_om_general_report_v t
    where  t.so_type          like 'Standard%'
    and    t.so_status        = 'BOOKED'
    and    t.so_line_status   not in ('CANCELLED', 'ENTERED', 'CLOSED')
    and    (t.invoiced_qty    is null or t.ordered_qty <> t.invoiced_qty)
    and    t.bill_to_customer not like '%Stratasys%'
    and    t.bill_to_customer not like '%Objet%';
    /*where  t.so_type          like 'Standard%'
    and    t.so_status        In ('BOOKED', 'CLOSED')
    and    t.so_line_status   not in ('CANCELLED', 'ENTERED')
    and    t.so_order_date    > l_so_date -- to_date('01-JAN-2013', 'DD-MON-YYYY')
    and    t.bill_to_customer not like '%Stratasys%'
    and    t.bill_to_customer not like '%Objet%';*/
    -- end 1.1  19/05/2013
    if l_count1 = 0 then
      FND_FILE.PUT_LINE(FND_FILE.LOG,'There is no data to transfer');
      dbms_output.put_line('There is no data to transfer');
    else

      l_file_name := get_file_name ('INVBACKLOG'); -- backlog.csv
      l_env       := xxobjt_fnd_attachments.get_environment_name;
      
      -- get file location
      if l_env <> 'PROD' then
        l_env := 'DEV';
      end if;
      l_file_location := '/UtlFiles/shared/'||l_env||'/LOG/ftp'; --'/UtlFiles/shared/TEST/LOG/ftp';

      -- open new file with the SR number as name
      l_file_handler := utl_file.fopen ( location  => l_file_location,--'/UtlFiles/shared/'||l_env||'/ftp', --'/usr/tmp/'||l_env, -- /usr/tmp/TEST
                                         filename  => l_file_name,
                                         open_mode => 'w');
      -- start write to the file
      utl_file.put_line (file   => l_file_handler,
                         buffer => '"AVERAGE_DISCOUNT","DIST_FUNCTIONAL_AMOUNT","PARENT_CUSTOMER_LOCATION",'||
                                   '"EXPECTED_SHIPPING_MONTH","DIRECT_INDIRECT_DEAL","ORG","OPERATING_UNIT",'||
                                   '"SO_NUMBER","SO_TYPE","SO_STATUS","SO_ORDER_DATE",'||
                                   '"SO_ORDERED_DATE_QUARTER","SO_SYS_RECOGNITION_DATE","CUSTOMER_NUMBER",'||
                                   '"CUSTOMER_NAME","SHIP_TO_ADDRESS5","STATE","ZIP_CODE","COUNTRY",'||
                                   '"BILL_TO_CUSTOMER","CUSTOMER_MAIN_BUSINESS_TYPE","CUSTOMER_LOCATION_SEGMENT",'||
                                   '"SHIP_TO_CUSTOMER","SHIP_TO_COUNTRY","CUST_PO_NUMBER","LINE_NUMBER",'||
                                   '"LINE_TYPE","ORDER_SOURCE","ORDERED_ITEM","SALESREP_NAME",'||
                                   '"MAIN_CATEGORY","ITEM_CATEGORY","ITEM_DESC","ORDER_QUANTITY_UOM",'||
                                   '"ORDERED_QTY","SHIPPED_QTY","INVOICED_QTY","CANCELLED_QTY",'||
                                   '"WEIGHT_KG","ITEM_PRODUCT_LINE_SEGMENT","SCHEDULE_SHIP_DATE",'||
                                   '"SCHEDULE_ARRIVAL_DATE","SO_LINE_STATUS","INVOICED_AMOUNT","INVOICE_NUMBER",'||
                                   '"UNIT_SELLING_PRICE","EXTENDED_PRICE","RESIN_CREDIT_AMOUNT","UNIT_LIST_PRICE",'||
                                   '"PRICE_LIST_CURRENCY","PRICE_LIST","FREIGHT_CHARGES","TRANSACTIONAL_CURR_CODE",'||
                                   '"PAYMENT_TERM","CONFIRM_DATE","ON_HOLD_FLAG","AGENT_NAME"');
      --  1.1  19/05/2013  Dalit A. Raviv
      for inv_r in inv_c /*(l_so_date)*/ loop
        begin
          l_temp := 'Y';
          
          utl_file.put_line (file   => l_file_handler,
                             buffer => '"'||INV_R.average_discount||'","'||INV_R.dist_functional_amount||'","'||INV_R.parent_customer_location||
                                       '","'||INV_R.expected_shipping_month||'","'||INV_R.direct_indirect_deal||'","'||INV_R.org||'","'||INV_R.operating_unit||
                                       '","'||INV_R.so_number||'","'||INV_R.so_type||'","'||INV_R.so_status||'","'||INV_R.so_order_date||
                                       '","'||INV_R.so_ordered_date_quarter||'","'||INV_R.so_sys_recognition_date||'","'||INV_R.customer_number||
                                       '","'||INV_R.customer_name||'","'||INV_R.ship_to_address5||'","'||INV_R.state||'","'||INV_R.zip_code||'","'||INV_R.country||
                                       '","'||INV_R.bill_to_customer||'","'||INV_R.customer_main_business_type||'","'||INV_R.customer_location_segment||
                                       '","'||INV_R.ship_to_customer||'","'||INV_R.ship_to_country||'","'||INV_R.cust_po_number||'","'||INV_R.line_number||
                                       '","'||INV_R.line_type||'","'||INV_R.order_source||'","'||INV_R.ordered_item||'","'||INV_R.salesrep_name||
                                       '","'||INV_R.main_category||'","'||INV_R.item_category||'","'||INV_R.item_desc||'","'||INV_R.order_quantity_uom||
                                       '","'||INV_R.ordered_qty||'","'||INV_R.shipped_qty||'","'||INV_R.invoiced_qty||'","'||INV_R.cancelled_qty||
                                       '","'||INV_R.weight_kg||'","'||INV_R.item_product_line_segment||'","'||INV_R.schedule_ship_date||
                                       '","'||INV_R.schedule_arrival_date||'","'||INV_R.so_line_status||'","'||INV_R.invoiced_amount||'","'||INV_R.invoice_number||
                                       '","'||INV_R.unit_selling_price||'","'||INV_R.extended_price||'","'||INV_R.resin_credit_amount||'","'||INV_R.unit_list_price||
                                       '","'||INV_R.price_list_currency||'","'||INV_R.price_list||'","'||INV_R.freight_charges||'","'||INV_R.transactional_curr_code||
                                       '","'||INV_R.payment_term||'","'||INV_R.confirm_date||'","'||INV_R.on_hold_flag||'","'||INV_R.agent_name||'"');                                     
      
        exception
          when utl_file.invalid_mode then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'The open_mode parameter in FOPEN is invalid');
            dbms_output.put_line('The open_mode parameter in FOPEN is invalid');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.invalid_path then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Specified path does not exist or is not visible to Oracle');
            dbms_output.put_line('Specified path does not exist or is not visible to Oracle');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.invalid_filehandle then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'File handle does not exist');
            dbms_output.put_line('File handle does not exist');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.internal_error then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Unhandled internal error in the UTL_FILE package');
            dbms_output.put_line('Unhandled internal error in the UTL_FILE package');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.file_open then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'File is already open');
            dbms_output.put_line('File is already open');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.invalid_maxlinesize then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'The MAX_LINESIZE value for FOPEN() is invalid; it should be within the range 1 to 32767');
            dbms_output.put_line('The MAX_LINESIZE value for FOPEN() is invalid; it should be within the range 1 to 32767');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.invalid_operation then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'File could not be opened or operated on as requested' );
            dbms_output.put_line('File could not be opened or operated on as requested' );
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.write_error then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Unable to write to file');
            dbms_output.put_line('Unable to write to file');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.access_denied then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Access to the file has been denied by the operating system');
            dbms_output.put_line('Access to the file has been denied by the operating system');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when others then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Unknown UTL_FILE Error');
            dbms_output.put_line('Unknown UTL_FILE Error - '||sqlerrm);
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
        end;
      end loop; -- write to file
      -- close the created file
      utl_file.fclose(file => l_file_handler);

      -- get ftp login details according to environment
      get_ftp_login_details (p_login_url => l_login_url,  -- o v  'Files.stratasys.com'
                             p_user      => l_user_name,  -- o v  'OBJSSYSDATAXFER'
                             p_password  => l_password,   -- o v  'Sh0k0l@d72'
                             p_err_code  => l_err_code,   -- o v
                             p_err_desc  => l_err_desc);  -- o v
   
      -- transfer file to stratasys
      fnd_file.put_line(fnd_file.log,'l_login_url - '||l_login_url);
      fnd_file.put_line(fnd_file.log,'l_user_name - '||l_user_name);
      fnd_file.put_line(fnd_file.log,'l_password - '||l_password);
      fnd_file.put_line(fnd_file.log,'l_file_location - '||l_file_location);
      fnd_file.put_line(fnd_file.log,'l_file_name - '||l_file_name);
      if l_temp = 'Y' then
        l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                                   program     => 'XXFTP',
                                                   argument1   => l_login_url,
                                                   argument2   => l_user_name,
                                                   argument3   => l_password,
                                                   argument4   => l_file_location,
                                                   argument5   => l_file_name);
        commit;
        fnd_file.put_line(fnd_file.log,'ftp request id - '||l_request_id);
        while l_error_flag = FALSE loop
          l_count := l_count + 1;
          l_result := fnd_concurrent.wait_for_request(l_request_id , 5, 86400,
                                                      l_phase,
                                                      l_status,
                                                      l_dev_phase,
                                                      l_dev_status,
                                                      l_message);

          if (l_dev_phase = 'COMPLETE' and l_dev_status = 'NORMAL') then
            l_error_flag := TRUE;
            retcode := 0;
          elsif (l_dev_phase = 'COMPLETE' and l_dev_status <> 'NORMAL') then
            l_error_flag := TRUE;
            retcode := 1;
            fnd_file.put_line(fnd_file.log,'Request finished in error or warrning, did not transfer file. - '||l_message);
          end if; -- dev_phase
        end loop; -- l_error_flag
      else
        fnd_file.put_line(fnd_file.log,'No data to transfer.');
      end if;
    end if; -- l_count
  exception
   when others then
      errbuf   := 2;
      retcode  := 'Procedure invoice_backlog_ftp failed'||substr(sqlerrm,1,240);
      fnd_file.put_line(fnd_file.log,'Procedure invoice_backlog_ftp failed - '||sqlerrm);
      dbms_output.put_line('Procedure invoice_backlog_ftp failed - '||substr(sqlerrm,1,240));
  end invoice_backlog_ftp;
  
  --------------------------------------------------------------------
  --  name:            invoice_booked_ftp
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   13/05/2013
  --------------------------------------------------------------------
  --  purpose :        Will handle all SO in status Booked and not internal
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/05/2013  Dalit A. Raviv    initial build
  --  1.1  19/05/2013  Dalit A. Raviv    change the select between booking and backlog
  --  1.2  16/06/2013  Dalit A. Raviv    add population of so_type like 'Trade In%'  
  --------------------------------------------------------------------
  procedure invoice_booked_ftp (errbuf  out varchar2,
                                retcode out varchar2) is
                                
    --  1.1  19/05/2013  Dalit A. Raviv 
    cursor inv_c (p_invoice_date in date) is
      select average_discount, dist_functional_amount, parent_customer_location, 
             expected_shipping_month, direct_indirect_deal, org, operating_unit, 
             so_number, so_type, so_status, to_char(so_order_date,'DD-MON-YYYY HH24:MI:SS') so_order_date,
             so_ordered_date_quarter, to_char(so_sys_recognition_date,'DD-MON-YYYY HH24:MI:SS') so_sys_recognition_date, customer_number, 
             customer_name, ship_to_address5, state, zip_code, country, 
             bill_to_customer, customer_main_business_type, customer_location_segment, 
             ship_to_customer, ship_to_country, cust_po_number, line_number, 
             line_type, order_source, ordered_item, salesrep_name, 
             main_category, item_category, item_desc, order_quantity_uom, 
             ordered_qty, shipped_qty, invoiced_qty, cancelled_qty, 
             weight_kg, item_product_line_segment, schedule_ship_date, 
             schedule_arrival_date, so_line_status, invoiced_amount, invoice_number, 
             unit_selling_price, extended_price, resin_credit_amount, unit_list_price, 
             price_list_currency, price_list, freight_charges, transactional_curr_code, 
             payment_term, confirm_date,  on_hold_flag, agent_name  
      from   apps.xxinv_om_general_report_v t 
      --where  t.so_type          like 'Standard%'
      where  (t.so_type  like 'Standard%' or t.so_type  like 'Trade In%')  --------------------
      and    t.so_status        In ('BOOKED', 'CLOSED')
      and    t.so_line_status   not in ('CANCELLED', 'ENTERED')
      and    t.so_order_date    > p_invoice_date -- to_date('01-JAN-2013', 'DD-MON-YYYY')
      and    t.bill_to_customer not like '%Stratasys%'
      and    t.bill_to_customer not like '%Objet%';      

    l_file_name      varchar2(150) := null;
    l_file_handler   utl_file.file_type;
    l_env            varchar2(150) := null;
    l_user_name      varchar2(150);
    l_password       varchar2(150);
    l_login_url      varchar2(150);
    l_err_code       varchar2(150);
    l_err_desc       varchar2(150);

    l_file_location  varchar2(240) := null;
    l_request_id     number;
    l_error_flag     boolean := FALSE;
    l_count          number  := 0;
    l_phase          varchar2(20);
    l_status         varchar2(20);
    l_dev_phase      varchar2(20);
    l_dev_status     varchar2(20);
    l_message        varchar2(100);
    l_result         boolean;
    l_temp           varchar2(1)  := 'N';
    l_count1         number       := 0;
    l_so_date        date         := null;
  begin
    errbuf  := null;
    retcode := 0;
    
    --  1.1  19/05/2013  Dalit A. Raviv
    -- get date from profile          
    l_so_date := to_date(fnd_profile.value('XXAR_INVALL_DATE'),'DD/MM/YYYY HH24:MI:SS');

    select count(1)
    into   l_count1
    from   apps.xxinv_om_general_report_v t
    where  t.so_type          like 'Standard%'
    and    t.so_status        In ('BOOKED', 'CLOSED')
    and    t.so_line_status   not in ('CANCELLED', 'ENTERED')
    and    t.so_order_date    > l_so_date -- to_date('01-JAN-2013', 'DD-MON-YYYY')
    and    t.bill_to_customer not like '%Stratasys%'
    and    t.bill_to_customer not like '%Objet%';
    /*where  t.so_type          like 'Standard%'
    and    t.so_status        = 'BOOKED'
    and    t.so_line_status   not in ('CANCELLED', 'ENTERED', 'CLOSED')
    and    (t.invoiced_qty    is null or t.ordered_qty <> t.invoiced_qty)
    and    t.bill_to_customer not like '%Stratasys%'
    and    t.bill_to_customer not like '%Objet%';*/
     -- end
    if l_count1 = 0 then
      FND_FILE.PUT_LINE(FND_FILE.LOG,'There is no data to transfer');
      dbms_output.put_line('There is no data to transfer');
    else

      l_file_name := get_file_name ('INVBOOKED'); -- bookings.csv
      l_env       := xxobjt_fnd_attachments.get_environment_name;
      
      -- get file location
      if l_env <> 'PROD' then
        l_env := 'DEV';
      end if;
      l_file_location := '/UtlFiles/shared/'||l_env||'/LOG/ftp'; --'/UtlFiles/shared/TEST/LOG/ftp';

      -- open new file with the SR number as name
      l_file_handler := utl_file.fopen ( location  => l_file_location,--'/UtlFiles/shared/'||l_env||'/ftp', --'/usr/tmp/'||l_env, -- /usr/tmp/TEST
                                         filename  => l_file_name,
                                         open_mode => 'w');
      -- start write to the file
      utl_file.put_line (file   => l_file_handler,
                         buffer => '"AVERAGE_DISCOUNT","DIST_FUNCTIONAL_AMOUNT","PARENT_CUSTOMER_LOCATION",'||
                                   '"EXPECTED_SHIPPING_MONTH","DIRECT_INDIRECT_DEAL","ORG","OPERATING_UNIT",'||
                                   '"SO_NUMBER","SO_TYPE","SO_STATUS","SO_ORDER_DATE",'||
                                   '"SO_ORDERED_DATE_QUARTER","SO_SYS_RECOGNITION_DATE","CUSTOMER_NUMBER",'||
                                   '"CUSTOMER_NAME","SHIP_TO_ADDRESS5","STATE","ZIP_CODE","COUNTRY",'||
                                   '"BILL_TO_CUSTOMER","CUSTOMER_MAIN_BUSINESS_TYPE","CUSTOMER_LOCATION_SEGMENT",'||
                                   '"SHIP_TO_CUSTOMER","SHIP_TO_COUNTRY","CUST_PO_NUMBER","LINE_NUMBER",'||
                                   '"LINE_TYPE","ORDER_SOURCE","ORDERED_ITEM","SALESREP_NAME",'||
                                   '"MAIN_CATEGORY","ITEM_CATEGORY","ITEM_DESC","ORDER_QUANTITY_UOM",'||
                                   '"ORDERED_QTY","SHIPPED_QTY","INVOICED_QTY","CANCELLED_QTY",'||
                                   '"WEIGHT_KG","ITEM_PRODUCT_LINE_SEGMENT","SCHEDULE_SHIP_DATE",'||
                                   '"SCHEDULE_ARRIVAL_DATE","SO_LINE_STATUS","INVOICED_AMOUNT","INVOICE_NUMBER",'||
                                   '"UNIT_SELLING_PRICE","EXTENDED_PRICE","RESIN_CREDIT_AMOUNT","UNIT_LIST_PRICE",'||
                                   '"PRICE_LIST_CURRENCY","PRICE_LIST","FREIGHT_CHARGES","TRANSACTIONAL_CURR_CODE",'||
                                   '"PAYMENT_TERM","CONFIRM_DATE","ON_HOLD_FLAG","AGENT_NAME"');
      --  1.1  19/05/2013  Dalit A. Raviv
      for inv_r in inv_c (l_so_date ) loop
        begin
          l_temp := 'Y';
          
          utl_file.put_line (file   => l_file_handler,
                             buffer => '"'||INV_R.average_discount||'","'||INV_R.dist_functional_amount||'","'||INV_R.parent_customer_location||
                                       '","'||INV_R.expected_shipping_month||'","'||INV_R.direct_indirect_deal||'","'||INV_R.org||'","'||INV_R.operating_unit||
                                       '","'||INV_R.so_number||'","'||INV_R.so_type||'","'||INV_R.so_status||'","'||INV_R.so_order_date||
                                       '","'||INV_R.so_ordered_date_quarter||'","'||INV_R.so_sys_recognition_date||'","'||INV_R.customer_number||
                                       '","'||INV_R.customer_name||'","'||INV_R.ship_to_address5||'","'||INV_R.state||'","'||INV_R.zip_code||'","'||INV_R.country||
                                       '","'||INV_R.bill_to_customer||'","'||INV_R.customer_main_business_type||'","'||INV_R.customer_location_segment||
                                       '","'||INV_R.ship_to_customer||'","'||INV_R.ship_to_country||'","'||INV_R.cust_po_number||'","'||INV_R.line_number||
                                       '","'||INV_R.line_type||'","'||INV_R.order_source||'","'||INV_R.ordered_item||'","'||INV_R.salesrep_name||
                                       '","'||INV_R.main_category||'","'||INV_R.item_category||'","'||INV_R.item_desc||'","'||INV_R.order_quantity_uom||
                                       '","'||INV_R.ordered_qty||'","'||INV_R.shipped_qty||'","'||INV_R.invoiced_qty||'","'||INV_R.cancelled_qty||
                                       '","'||INV_R.weight_kg||'","'||INV_R.item_product_line_segment||'","'||INV_R.schedule_ship_date||
                                       '","'||INV_R.schedule_arrival_date||'","'||INV_R.so_line_status||'","'||INV_R.invoiced_amount||'","'||INV_R.invoice_number||
                                       '","'||INV_R.unit_selling_price||'","'||INV_R.extended_price||'","'||INV_R.resin_credit_amount||'","'||INV_R.unit_list_price||
                                       '","'||INV_R.price_list_currency||'","'||INV_R.price_list||'","'||INV_R.freight_charges||'","'||INV_R.transactional_curr_code||
                                       '","'||INV_R.payment_term||'","'||INV_R.confirm_date||'","'||INV_R.on_hold_flag||'","'||INV_R.agent_name||'"');                                     
      
        exception
          when utl_file.invalid_mode then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'The open_mode parameter in FOPEN is invalid');
            dbms_output.put_line('The open_mode parameter in FOPEN is invalid');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.invalid_path then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Specified path does not exist or is not visible to Oracle');
            dbms_output.put_line('Specified path does not exist or is not visible to Oracle');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.invalid_filehandle then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'File handle does not exist');
            dbms_output.put_line('File handle does not exist');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.internal_error then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Unhandled internal error in the UTL_FILE package');
            dbms_output.put_line('Unhandled internal error in the UTL_FILE package');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.file_open then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'File is already open');
            dbms_output.put_line('File is already open');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.invalid_maxlinesize then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'The MAX_LINESIZE value for FOPEN() is invalid; it should be within the range 1 to 32767');
            dbms_output.put_line('The MAX_LINESIZE value for FOPEN() is invalid; it should be within the range 1 to 32767');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.invalid_operation then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'File could not be opened or operated on as requested' );
            dbms_output.put_line('File could not be opened or operated on as requested' );
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.write_error then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Unable to write to file');
            dbms_output.put_line('Unable to write to file');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.access_denied then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Access to the file has been denied by the operating system');
            dbms_output.put_line('Access to the file has been denied by the operating system');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when others then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Unknown UTL_FILE Error');
            dbms_output.put_line('Unknown UTL_FILE Error - '||sqlerrm);
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
        end;
      end loop; -- write to file
      -- close the created file
      utl_file.fclose(file => l_file_handler);

      -- get ftp login details according to environment
      get_ftp_login_details (p_login_url => l_login_url,  -- o v  'Files.stratasys.com'
                             p_user      => l_user_name,  -- o v  'OBJSSYSDATAXFER'
                             p_password  => l_password,   -- o v  'Sh0k0l@d72'
                             p_err_code  => l_err_code,   -- o v
                             p_err_desc  => l_err_desc);  -- o v
   
      -- transfer file to stratasys
      fnd_file.put_line(fnd_file.log,'l_login_url - '||l_login_url);
      fnd_file.put_line(fnd_file.log,'l_user_name - '||l_user_name);
      fnd_file.put_line(fnd_file.log,'l_password - '||l_password);
      fnd_file.put_line(fnd_file.log,'l_file_location - '||l_file_location);
      fnd_file.put_line(fnd_file.log,'l_file_name - '||l_file_name);
    
      if l_temp = 'Y' then
        l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                                   program     => 'XXFTP',
                                                   argument1   => l_login_url,
                                                   argument2   => l_user_name,
                                                   argument3   => l_password,
                                                   argument4   => l_file_location,
                                                   argument5   => l_file_name);
        commit;
        fnd_file.put_line(fnd_file.log,'ftp request id - '||l_request_id);
        while l_error_flag = FALSE loop
          l_count := l_count + 1;
          l_result := fnd_concurrent.wait_for_request(l_request_id , 5, 86400,
                                                      l_phase,
                                                      l_status,
                                                      l_dev_phase,
                                                      l_dev_status,
                                                      l_message);

          if (l_dev_phase = 'COMPLETE' and l_dev_status = 'NORMAL') then
            l_error_flag := TRUE;
            retcode := 0;
          elsif (l_dev_phase = 'COMPLETE' and l_dev_status <> 'NORMAL') then
            l_error_flag := TRUE;
            retcode := 1;
            fnd_file.put_line(fnd_file.log,'Request finished in error or warrning, did not transfer file. - '||l_message);
          end if; -- dev_phase
        end loop; -- l_error_flag
      else
        fnd_file.put_line(fnd_file.log,'No data to transfer.');
      end if;
    end if; -- l_count
  exception
   when others then
      errbuf   := 2;
      retcode  := 'Procedure invoice_booked_ftp failed'||substr(sqlerrm,1,240);
      fnd_file.put_line(fnd_file.log,'Procedure invoice_booked_ftp failed - '||sqlerrm);
      dbms_output.put_line('Procedure invoice_booked_ftp failed - '||substr(sqlerrm,1,240));
  end invoice_booked_ftp;
  
 
  --------------------------------------------------------------------
  --  name:            invoice_lines_ftp
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   12/05/2013
  --------------------------------------------------------------------
  --  purpose :        Will handle all AR invoices from all OU and all types 
  --                   from 01-Jan-2013 (by profile)
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  12/05/2013  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure invoice_lines_ftp   (errbuf  out varchar2,
                                 retcode out varchar2) is
  
    cursor inv_c (p_invoice_date in date) is
      select operating_unit, item_prod_line_parent, cust_location_parent, trx_type, order_number, invoice_number, po_number,
             to_char(invoice_date,'DD-MON-YYYY HH24:MI:SS')    invoice_date,
             to_char(invoice_gl_date,'DD-MON-YYYY HH24:MI:SS') invoice_gl_date, 
             line_number, customer, customer_account_num, customer_main_business_type, customer_type, 
             customer_bill_to_country, customer_bill_to_state, customer_bill_to_city, ship_to_customer, cust_ship_to_main_bus_type, 
             customer_ship_to_country, customer_ship_to_state, customer_ship_to_city, customer_ship_to_county, cust_location_seg_desc, 
             item, description, item_prod_line_seg, item_prod_line_seg_desc, item_type, uom_code, quantity, kg, unit_selling_price, 
             unit_list_price, average_discount, extended_entered_amount, invoice_currency, rate_from_ent_to_func, ext_func_amount, 
             func_currency, rate_from_func_to_usd, extended_usd_amount, quarter_num
      from   xxar_invoices_all_v v
      where  invoice_date > p_invoice_date; 

    l_file_name      varchar2(150) := null;
    l_file_handler   utl_file.file_type;
    l_env            varchar2(150) := null;
    l_user_name      varchar2(150);
    l_password       varchar2(150);
    l_login_url      varchar2(150);
    l_err_code       varchar2(150);
    l_err_desc       varchar2(150);

    l_file_location  varchar2(240) := null;
    l_request_id     number;
    l_error_flag     boolean := FALSE;
    l_count          number  := 0;
    l_phase          varchar2(20);
    l_status         varchar2(20);
    l_dev_phase      varchar2(20);
    l_dev_status     varchar2(20);
    l_message        varchar2(100);
    l_result         boolean;
    l_temp           varchar2(1)  := 'N';
    l_count1         number       := 0;
    l_so_date        date         := null;
  begin
    errbuf  := null;
    retcode := 0;

    -- get date from profile          
    l_so_date := to_date(fnd_profile.value('XXAR_INVALL_DATE'),'DD/MM/YYYY HH24:MI:SS'); -- 01/01/2013 00:00:01

    select count(1)
    into   l_count1
    from   xxar_invoices_all_v v
    where  1 = 1
    and    invoice_date > l_so_date; --to_date('2013-01-01 00:00:01', 'yyyy-mm-dd hh24:mi:ss'); -- profile

    if l_count1 = 0 then
      FND_FILE.PUT_LINE(FND_FILE.LOG,'There is no data to transfer');
      dbms_output.put_line('There is no data to transfer');
    else

      l_file_name := get_file_name ('INVOICELINES');
      -- INVBACKLOG  backlog.csv
      -- INVBOOKED   bookings.csv
      --l_file_name := 'a.csv';
      l_env       := xxobjt_fnd_attachments.get_environment_name;
      
      -- get file location
      if l_env <> 'PROD' then
        l_env := 'DEV';
      end if;
      l_file_location := '/UtlFiles/shared/'||l_env||'/LOG/ftp'; --'/UtlFiles/shared/TEST/LOG/ftp';

      -- open new file with the SR number as name
      l_file_handler := utl_file.fopen ( location  => l_file_location,--'/UtlFiles/shared/'||l_env||'/ftp', --'/usr/tmp/'||l_env, -- /usr/tmp/TEST
                                         filename  => l_file_name,
                                         open_mode => 'w');
      -- start write to the file
      utl_file.put_line (file   => l_file_handler,
                         buffer => '"OPERATING_UNIT","ITEM_PROD_LINE_PARENT","CUST_LOCATION_PARENT","TRX_TYPE","ORDER_NUMBER",'||
                                   '"INVOICE_NUMBER","PO_NUMBER","INVOICE_DATE","INVOICE_GL_DATE","LINE_NUMBER",'||
                                   '"CUSTOMER","CUSTOMER_ACCOUNT_NUM","CUSTOMER_MAIN_BUSINESS_TYPE","CUSTOMER_TYPE",'||
                                   '"CUSTOMER_BILL_TO_COUNTRY","CUSTOMER_BILL_TO_STATE","CUSTOMER_BILL_TO_CITY","SHIP_TO_CUSTOMER",'||
                                   '"CUST_SHIP_TO_MAIN_BUS_TYPE","CUSTOMER_SHIP_TO_COUNTRY","CUSTOMER_SHIP_TO_STATE","CUSTOMER_SHIP_TO_CITY",'||
                                   '"CUSTOMER_SHIP_TO_COUNTY","CUST_LOCATION_SEG_DESC","ITEM","DESCRIPTION","ITEM_PROD_LINE_SEG",'||
                                   '"ITEM_PROD_LINE_SEG_DESC","ITEM_TYPE","UOM_CODE","QUANTITY","KG","UNIT_SELLING_PRICE",'||
                                   '"UNIT_LIST_PRICE","AVERAGE_DISCOUNT","EXTENDED_ENTERED_AMOUNT","INVOICE_CURRENCY",'||
                                   '"RATE_FROM_ENT_TO_FUNC","EXT_FUNC_AMOUNT","FUNC_CURRENCY","RATE_FROM_FUNC_TO_USD",'||
                                   '"EXTENDED_USD_AMOUNT","QUARTER_NUM"');

      for inv_r in inv_c (l_so_date) loop
        begin
          l_temp := 'Y';
          utl_file.put_line (file   => l_file_handler,
                             buffer => '"'||inv_r.operating_unit||'","'||inv_r.item_prod_line_parent||'","'||inv_r.cust_location_parent||'","'||inv_r.trx_type||'","'||inv_r.order_number||
                                       '","'||inv_r.invoice_number||'","'||inv_r.po_number||'","'||inv_r.invoice_date||'","'||inv_r.invoice_gl_date||'","'||inv_r.line_number||
                                       '","'||inv_r.customer||'","'||inv_r.customer_account_num||'","'||inv_r.customer_main_business_type||'","'||inv_r.customer_type||
                                       '","'||inv_r.customer_bill_to_country||'","'||inv_r.customer_bill_to_state||'","'||inv_r.customer_bill_to_city||'","'||inv_r.ship_to_customer||
                                       '","'||inv_r.cust_ship_to_main_bus_type||'","'||inv_r.customer_ship_to_country||'","'||inv_r.customer_ship_to_state||'","'||inv_r.customer_ship_to_city||
                                       '","'||inv_r.customer_ship_to_county||'","'||inv_r.cust_location_seg_desc||'","'||inv_r.item||'","'||inv_r.description||'","'||inv_r.item_prod_line_seg||
                                       '","'||inv_r.item_prod_line_seg_desc||'","'||inv_r.item_type||'","'||inv_r.uom_code||'","'||inv_r.quantity||'","'||inv_r.kg||'","'||inv_r.unit_selling_price||
                                       '","'||inv_r.unit_list_price||'","'||inv_r.average_discount||'","'||inv_r.extended_entered_amount||'","'||inv_r.invoice_currency||
                                       '","'||inv_r.rate_from_ent_to_func||'","'||inv_r.ext_func_amount||'","'||inv_r.func_currency||'","'||inv_r.rate_from_func_to_usd||
                                       '","'||inv_r.extended_usd_amount||'","'||inv_r.quarter_num||'"');                                     
         exception
          when utl_file.invalid_mode then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'The open_mode parameter in FOPEN is invalid');
            dbms_output.put_line('The open_mode parameter in FOPEN is invalid');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.invalid_path then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Specified path does not exist or is not visible to Oracle');
            dbms_output.put_line('Specified path does not exist or is not visible to Oracle');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.invalid_filehandle then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'File handle does not exist');
            dbms_output.put_line('File handle does not exist');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.internal_error then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Unhandled internal error in the UTL_FILE package');
            dbms_output.put_line('Unhandled internal error in the UTL_FILE package');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.file_open then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'File is already open');
            dbms_output.put_line('File is already open');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.invalid_maxlinesize then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'The MAX_LINESIZE value for FOPEN() is invalid; it should be within the range 1 to 32767');
            dbms_output.put_line('The MAX_LINESIZE value for FOPEN() is invalid; it should be within the range 1 to 32767');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.invalid_operation then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'File could not be opened or operated on as requested' );
            dbms_output.put_line('File could not be opened or operated on as requested' );
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.write_error then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Unable to write to file');
            dbms_output.put_line('Unable to write to file');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when utl_file.access_denied then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Access to the file has been denied by the operating system');
            dbms_output.put_line('Access to the file has been denied by the operating system');
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
          when others then
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Unknown UTL_FILE Error');
            dbms_output.put_line('Unknown UTL_FILE Error - '||sqlerrm);
            ERRBUF   := 1;
            RETCODE  := 'UTL_FILE Error';
        end;
      end loop; -- write to file
      -- close the created file
      utl_file.fclose(file => l_file_handler);

      -- get ftp login details according to environment
      get_ftp_login_details (p_login_url => l_login_url,  -- o v  'Files.stratasys.com'
                             p_user      => l_user_name,  -- o v  'OBJSSYSDATAXFER'
                             p_password  => l_password,   -- o v  'Sh0k0l@d72'
                             p_err_code  => l_err_code,   -- o v
                             p_err_desc  => l_err_desc);  -- o v
   
      -- transfer file to stratasys
      fnd_file.put_line(fnd_file.log,'l_login_url - '||l_login_url);
      fnd_file.put_line(fnd_file.log,'l_user_name - '||l_user_name);
      fnd_file.put_line(fnd_file.log,'l_password - '||l_password);
      fnd_file.put_line(fnd_file.log,'l_file_location - '||l_file_location);
      fnd_file.put_line(fnd_file.log,'l_file_name - '||l_file_name);
      if l_temp = 'Y' then
        l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                                   program     => 'XXFTP',
                                                   argument1   => l_login_url,
                                                   argument2   => l_user_name,
                                                   argument3   => l_password,
                                                   argument4   => l_file_location,
                                                   argument5   => l_file_name);
        commit;
        fnd_file.put_line(fnd_file.log,'ftp request id - '||l_request_id);
        while l_error_flag = FALSE loop
          l_count := l_count + 1;
          l_result := fnd_concurrent.wait_for_request(l_request_id , 5, 86400,
                                                      l_phase,
                                                      l_status,
                                                      l_dev_phase,
                                                      l_dev_status,
                                                      l_message);

          if (l_dev_phase = 'COMPLETE' and l_dev_status = 'NORMAL') then
            l_error_flag := TRUE;
            retcode := 0;
          elsif (l_dev_phase = 'COMPLETE' and l_dev_status <> 'NORMAL') then
            l_error_flag := TRUE;
            retcode := 1;
            fnd_file.put_line(fnd_file.log,'Request finished in error or warrning, did not transfer file. - '||l_message);
          end if; -- dev_phase
        end loop; -- l_error_flag
      else
        fnd_file.put_line(fnd_file.log,'No data to transfer.');
      end if;
    end if; -- l_count
  exception
   when others then
      errbuf   := 2;
      retcode  := 'Procedure invoice_lines_ftp failed'||substr(sqlerrm,1,240);
      fnd_file.put_line(fnd_file.log,'Procedure invoice_lines_ftp failed - '||sqlerrm);
      dbms_output.put_line('Procedure invoice_lines_ftp failed - '||substr(sqlerrm,1,240));
  end invoice_lines_ftp;

  --------------------------------------------------------------------
  --  name:            main
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   16/08/2012 15:59:19
  --------------------------------------------------------------------
  --  purpose :        Main will handle all programs - and will run each
  --                   procedure according to entity parameter.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16/08/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure main (errbuf     out varchar2,
                  retcode    out varchar2,
                  P_ENTITY   in  varchar2,
                  P_NUM_DAYS in  number) is

    l_err_desc varchar2(2500) := null;
    l_err_code varchar2(100)  := null;
  begin
    errbuf   := null;
    retcode  := 0;
    if p_entity = 'ITEM' then
      item_ftp (errbuf     => l_err_desc,
                retcode    => l_err_code,
                p_num_days => p_num_days);
    elsif p_entity = 'RELATIONS' then
      relations_ftp (errbuf     => l_err_desc,
                     retcode    => l_err_code,
                     p_num_days => p_num_days);
    elsif p_entity = 'CONTACT' then
      contact_ftp (errbuf     => l_err_desc,
                   retcode    => l_err_code,
                   p_num_days => p_num_days);
     elsif p_entity = 'BILL' then
      customer_billing_ftp (errbuf     => l_err_desc,
                            retcode    => l_err_code,
                            p_num_days => p_num_days);
    elsif p_entity = 'SHIP' then
      customer_shipping_ftp (errbuf     => l_err_desc,
                             retcode    => l_err_code,
                             p_num_days => p_num_days);
    elsif p_entity = 'ONHAND' then
      onhand_ftp (errbuf     => l_err_desc,
                  retcode    => l_err_code,
                  p_num_days => p_num_days);
    elsif p_entity = 'ORDER' then
      order_ftp (errbuf     => l_err_desc,
                 retcode    => l_err_code,
                 p_num_days => p_num_days);
    elsif p_entity = 'CONTRACT' then
      contract_ftp (errbuf     => l_err_desc,
                    retcode    => l_err_code,
                  p_num_days => p_num_days);
    end if;
    errbuf   := l_err_desc;
    retcode  := l_err_code;

  exception
    when others then
      errbuf   := 'Procedure main failed - '||substr(sqlerrm,1,240);
      retcode  := 1;
  end main;

  --------------------------------------------------------------------
  --  name:            Main_intercompany_inv
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   03/10/2012
  --------------------------------------------------------------------
  --  purpose :        Procedure will handle transfer intercompany inv - intransit
  --                   between Oracle to Sytline.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  03/10/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure main_intercompany_inv ( errbuf     out varchar2,
                                    retcode    out varchar2,
                                    p_entity   in  varchar2) is

    l_err_desc varchar2(2500) := null;
    l_err_code varchar2(100)  := null;
  begin
    errbuf   := null;
    retcode  := 0;
    if p_entity = 'PO' then
      po_ftp  (errbuf     => l_err_desc,
               retcode    => l_err_code);
    elsif p_entity = 'RCV' then
      rcv_ftp (errbuf     => l_err_desc,
               retcode    => l_err_code);
    end if;
    errbuf   := l_err_desc;
    retcode  := l_err_code;
  exception
    when others then
      errbuf   := 'Procedure main_intercompany_inv failed - '||substr(sqlerrm,1,240);
      retcode  := 1;
  end main_intercompany_inv;

  --------------------------------------------------------------------
  --  name:            main_invoice
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   12/05/2012
  --------------------------------------------------------------------
  --  purpose :        CUST685 - OA2Syteline - FTP - OM General report
  --                   Procedure will handle transfer invoice information 
  --                   between Oracle to Sytline.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  12/05/2012  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure main_invoice ( errbuf     out varchar2,
                           retcode    out varchar2,
                           p_entity   in  varchar2) is

    l_err_desc  varchar2(2500) := null;
    l_err_code  varchar2(100)  := null;
    l_proc_name varchar2(20) := null;
    gen_exp     exception;
  begin
    errbuf   := null;
    retcode  := 0;
         
    if p_entity = 'INVOICELINES' then
      l_proc_name := 'invoice_lines_ftp';
      invoice_lines_ftp    (errbuf     => l_err_desc,
                            retcode    => l_err_code);
    elsif p_entity = 'INVBOOKED' then
      l_proc_name := 'invoice_booked_ftp';
      invoice_booked_ftp   (errbuf     => l_err_desc,
                            retcode    => l_err_code);
    elsif p_entity = 'INVBACKLOG' then
      l_proc_name := 'invoice_backlog_ftp';
      invoice_backlog_ftp  (errbuf     => l_err_desc,
                            retcode    => l_err_code);
    end if;
  
    errbuf   := l_err_desc;
    retcode  := l_err_code;
    if l_err_code <> 0 then
      raise gen_exp;
    end if;
    
  exception
    when gen_exp then 
      fnd_file.put_line(fnd_file.log,'Procedure '||l_proc_name||' Failed '||l_err_desc);
    when others then
      errbuf   := 'Procedure main_invoice failed - '||substr(sqlerrm,1,240);
      retcode  := 1;
  end main_invoice;

end XXOA2SSYS_FTP_PKG;
/
