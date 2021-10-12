CREATE OR REPLACE PACKAGE BODY "XXINV_ECO_NOTIFICATION_PKG" is
  ------------------------------------------------------------------------------
  -- Ver   When        Who        Description
  -- ----  ----------  ---------  ----------------------------------------------
  -- 1.0   23/09/2020  Roman W.   CHG0048470 - Change notification to customers
  -- 1.2   04/02/2021  Roman W.   CHG0049362 - exclude countries from list  
  ------------------------------------------------------------------------------

  ------------------------------------------------------------------------------
  -- Ver   When        Who        Description
  -- ----  ----------  ---------  ----------------------------------------------
  -- 1.0   23/09/2020  Roman W.   CHG0048470 - Change notification to customers
  -- 1.1   13/10/2020  Roman W.                added get_implementation_date
  -- 1.2   04/02/2021  Roman W.   CHG0049362 - ECO notify customer -exclude Japan customers 
  ------------------------------------------------------------------------------

  PROCEDURE message(p_msg IN VARCHAR2) IS
  
    ----------------------------
    --       Code Section
    ----------------------------
    l_msg VARCHAR2(400);
    ----------------------------
    --       Code Section
    ----------------------------
  BEGIN
  
    l_msg := substr(to_char(SYSDATE, 'DD/MM/YYYY HH24:MI:SS') || ' - ' ||
                    p_msg,
                    1,
                    400);
  
    IF fnd_global.conc_request_id > 0 THEN
      fnd_file.put_line(fnd_file.log, l_msg);
    ELSE
      dbms_output.put_line(p_msg);
    END IF;
  END message;

  ----------------------------------------------------------------------
  -- Ver   When         Who       Descr
  -- ----  -----------  --------  --------------------------------------
  -- 1.0   15/10/2020  Roman W.   CHG0048470 - Change notification to customers
  -------------------------------------------------------------------------
  procedure remove_file(p_directory  in varchar2,
                        p_file_name  in varchar2,
                        p_error_code out varchar2,
                        p_error_desc out varchar2) is
    l_count NUMBER;
  begin
    p_error_code := '0';
    p_error_desc := null;
  
    l_count := dbms_lob.fileexists(bfilename(p_directory, p_file_name));
    message('remove_file : ' || p_file_name || ', COUNT = ' || l_count);
  
    if 1 = l_count then
      utl_file.fremove(location => p_directory, filename => p_file_name);
    end if;
  exception
    when others then
      p_error_code := '2';
      p_error_desc := 'EXCEPTION_OTHERS XXINV_ECO_NOTIFICATION_PKG.remove_file(' ||
                      p_directory || ',' || p_file_name || ') - ' ||
                      sqlerrm;
  end remove_file;

  -------------------------------------------------------------------------------------
  -- Ver   When          Who              Description
  -- ----  ------------  ---------------  ---------------------------------------------
  -- 1.0   16/11/2020    Roman W.         CHG0048470 - Change notification to customers
  -------------------------------------------------------------------------------------
  function get_email_subject(p_str VARCHAR2) return varchar2 is
    ------------------------
    --   Local Definition
    ------------------------
    l_suffix  VARCHAR2(120);
    l_prefix  VARCHAR2(120);
    l_subject VARCHAR2(300);
    ------------------------
    --   Code Section
    ------------------------
  begin
  
    if 'N' = xxobjt_general_utils_pkg.am_i_in_production then
    
      l_suffix := '[ ' || sys_context('USERENV', 'INSTANCE_NAME') || ' ]';
      begin
        select '[ ' || fcr.REQUEST_ID || ' - ' || fcr.PROGRAM || ' ]'
          into l_prefix
          from FND_CONC_REQ_SUMMARY_V fcr
         where fcr.REQUEST_ID = fnd_global.CONC_REQUEST_ID;
      exception
        when others then
          null;
      end;
    else
      l_suffix := null;
      l_prefix := null;
    end if;
  
    l_subject := 'Change notification on Stratasys products';
  
    return l_subject || l_suffix || l_prefix;
  
  end get_email_subject;

  -------------------------------------------------------------------------------------
  -- Ver   When         Who         Description
  -- ----  -----------  ----------  ---------------------------------------------------
  -- 1.0   18/11/2020   Roman W.    CHG0048470 - Change notification to customers
  -------------------------------------------------------------------------------------
  function is_header_exists(p_eco VARCHAR2) return varchar2 is
    --------------------------
    --    Local Definition
    --------------------------
    l_ret_value VARCHAR2(10);
    l_count     NUMBER;
    --------------------------
    --    Code Section
    --------------------------
  begin
  
    select count(*)
      into l_count
      from xxinv_eco_header xeh
     where xeh.eco = p_eco;
  
    if 0 = l_count then
      l_ret_value := 'N';
    else
      l_ret_value := 'Y';
    end if;
  
    return l_ret_value;
  
  end is_header_exists;

  -------------------------------------------------------------------------------------
  -- Ver   When          Who              Description
  -- ----  ------------  ---------------  ---------------------------------------------
  -- 1.0   11/11/2020    Roman W.         CHG0048470 - Change notification to customers
  -------------------------------------------------------------------------------------
  procedure update_header_mail_status(p_eco_header_id IN NUMBER,
                                      p_mail_status   IN VARCHAR2,
                                      p_note          IN VARCHAR2,
                                      p_email_sent_to IN VARCHAR2 DEFAULT NULL,
                                      p_error_code    OUT VARCHAR2,
                                      p_error_desc    OUT VARCHAR2) is
    ---------------------------------
    --     Local Definition
    ---------------------------------
  
    ---------------------------------
    --     Code Section
    ---------------------------------
  begin
    p_error_code := '0';
    p_error_desc := null;
  
    update xxinv_eco_header xeh
       set xeh.mail_status   = p_mail_status,
           xeh.note          = p_note,
           xeh.email_sent_to = p_email_sent_to
     where xeh.eco_header_id = p_eco_header_id;
  
  exception
    when others then
      p_error_code := '2';
      p_error_desc := 'EXCEPTION_OTHERS XXINV_ECO_NOTIFICATION_PKG.update_header_mail_status(' ||
                      p_eco_header_id || ',' || p_mail_status || ',' ||
                      p_note || ') - ' || sqlerrm;
    
      message(p_error_desc);
    
  end update_header_mail_status;

  -------------------------------------------------------------------------------------
  -- Ver   When          Who              Description
  -- ----  ------------  ---------------  ---------------------------------------------
  -- 1.0   11/11/2020    Roman W.         CHG0048470 - Change notification to customers
  -------------------------------------------------------------------------------------
  procedure update_line_mail_status(p_eco_line_id IN NUMBER,
                                    p_mail_status IN VARCHAR2,
                                    p_note        IN VARCHAR2,
                                    p_error_code  OUT VARCHAR2,
                                    p_error_desc  OUT VARCHAR2) is
    ------------------------
    --   Local Definition
    ------------------------
  
    ------------------------
    --   Code Section
    ------------------------
  begin
    p_error_code := '0';
    p_error_desc := null;
  
    update xxinv_eco_lines xel
       set xel.mail_status = p_mail_status, xel.note = p_note
     where xel.eco_line_id = p_eco_line_id;
  
  exception
    when others then
      p_error_code := '2';
      p_error_desc := 'EXCEPTION_OTHERS XXINV_ECO_NOTIFICATION_PKG.update_line_mail_status(' ||
                      p_eco_line_id || ',' || p_mail_status || ',' ||
                      p_note || ') - ' || sqlerrm;
      message(p_error_desc);
    
  end update_line_mail_status;

  -------------------------------------------------------------------------------------
  -- Ver   When          Who              Description
  -- ----  ------------  ---------------  ---------------------------------------------
  -- 1.0   30/12/2019    Roman W.         CHG0048470 - Change notification to customers
  -------------------------------------------------------------------------------------
  procedure wait_for_request(p_request_id in NUMBER,
                             p_error_code out varchar2,
                             p_error_desc out varchar2) is
    -----------------------------
    --    Local Definition
    -----------------------------
    l_complete   BOOLEAN;
    l_phase      VARCHAR2(300);
    l_status     VARCHAR2(300);
    l_dev_phase  VARCHAR2(300);
    l_dev_status VARCHAR2(300);
    l_message    VARCHAR2(300);
    -----------------------------
    --    Code Section
    -----------------------------
  begin
  
    p_error_code := '0';
    p_error_desc := null;
  
    l_complete := fnd_concurrent.wait_for_request(request_id => p_request_id,
                                                  interval   => 10,
                                                  max_wait   => 0,
                                                  phase      => l_phase,
                                                  status     => l_status,
                                                  dev_phase  => l_dev_phase,
                                                  dev_status => l_dev_status,
                                                  message    => l_message);
  
    if (l_dev_phase = 'COMPLETE' and l_dev_status != 'NORMAL') then
    
      p_error_code := 2;
    
      p_error_desc := 'Request ID: ' || p_request_id || CHR(10) ||
                      'Status    : ' || l_dev_status || CHR(10) ||
                      'Message   : ' || l_message;
    
      message('STATUS : ' || p_error_code || CHR(10) || p_error_desc);
    
    END IF;
  
  end wait_for_request;

  ------------------------------------------------------------------------------
  -- Ver   When        Who        Description
  -- ----  ----------  ---------  ----------------------------------------------
  -- 1.0   29/09/2020  Roman W.   CHG0048470 - Change notification to customers
  ------------------------------------------------------------------------------
  procedure set_profile_value(pv_profile_name IN VARCHAR2 DEFAULT C_SYNC_DATA_LAST_RUN_PRF,
                              pv_value        IN VARCHAR2,
                              pv_error_code   OUT VARCHAR2,
                              pv_error_desc   OUT VARCHAR2) is
    ------------------------------
    --    Local Definition
    ------------------------------
    lb_status    boolean;
    lv_old_value varchar2(240);
    ------------------------------
    --    Code Section
    ------------------------------
  BEGIN
    pv_error_code := '0';
    pv_error_desc := null;
  
    lv_old_value := fnd_profile.VALUE(pv_profile_name);
  
    lb_status := fnd_profile.SAVE(pv_profile_name, pv_value, 'SITE');
  
    IF lb_status THEN
      message('Profile : ' || pv_profile_name || 'updated ' || chr(10) ||
              rpad(chr(9), 15) || ' old value :' || lv_old_value ||
              chr(10) || rpad(chr(9), 15) || ' new value :' || pv_value);
    ELSE
    
      pv_error_code := '2';
      pv_error_desc := 'EXCEPTION_PROFILE_UPDATE_ERROR : Profile ' ||
                       pv_profile_name || 'not updated with "' || pv_value || '"';
      message(pv_error_desc);
    
    END IF;
  
    COMMIT;
  exception
    when others then
      pv_error_code := '2';
      pv_error_desc := 'EXCEPTION_OTHES XXINV_ECO_NOTIFICATION.set_profile_value(' ||
                       pv_profile_name || ',' || pv_value || ') - ' ||
                       sqlerrm;
  END set_profile_value;

  ------------------------------------------------------------------------------
  -- Ver   When        Who        Description
  -- ----  ----------  ---------  ----------------------------------------------
  -- 1.0   14/10/2020  Roman W.   CHG0048470 - Change notification to customers
  ------------------------------------------------------------------------------
  function get_notification_int_email(p_eco VARCHAR2) return varchar2 is
    ------------------------
    --   Local Definition
    ------------------------
    l_ret_value varchar2(300);
    ------------------------
    --   Code Section
    ------------------------
  begin
  
    l_ret_value := fnd_profile.value('XXINV_ECO_NOTIF_INT_MAIL_TO');
    return l_ret_value;
  end get_notification_int_email;

  /*
  ------------------------------------------------------------------------------
  -- Ver   When         Who        Descr
  -- ----  -----------  ---------  ---------------------------------------------
  -- 1.0   27/10/2020   Roman W.   CHG0048470 - Change notification to customers
  ------------------------------------------------------------------------------
  procedure get_contact_email_address(p_inventory_item_id        IN NUMBER,
                                      p_xxinv_eco_line_customers IN OUT xxinv_eco_line_customers%ROWTYPE,
                                      p_error_code               OUT VARCHAR2,
                                      p_error_desc               OUT VARCHAR2) is
    ---------------------------
    --    Local Definition
    ---------------------------
    CURSOR contact_cur(c_inventory_item_id NUMBER,
                       c_cust_account_id   NUMBER) is
      with xxadd_month as
       (select add_months(trunc(sysdate),
                          to_number(fnd_profile.VALUE('XXINV_ECO_CUSTOMER_ADD_MONTHS'))) XXINV_ECO_CUSTOMER_ADD_MONTHS
          from dual)
      select h.ship_to_customer_id,
             h.ship_to_contact_id,
             h.bill_to_customer_id,
             h.bill_to_contact_id
        from ra_customer_trx_lines_all l,
             ra_customer_trx_all       h,
             hz_cust_accounts          hca,
             --ar_contacts_v             acv,
             xxadd_month xm
       where h.customer_trx_id = l.customer_trx_id
         and h.trx_date > xm.XXINV_ECO_CUSTOMER_ADD_MONTHS
         and hca.cust_account_id = h.ship_to_customer_id
         and l.inventory_item_id is not null
         and l.inventory_item_id = c_inventory_item_id
         and hca.cust_account_id = c_cust_account_id
         and not exists
       (select 'X'
                from XXINV_ECO_LINE_CUSTOMERS xelc
               where xelc.contact_id in
                     (h.ship_to_contact_id, h.bill_to_contact_id)
                 and xelc.cust_account_id = hca.cust_account_id)
       order by h.last_update_date desc;
    --and acv.contact_id = h.ship_to_contact_id;
  
    cursor quality_contact_cur(c_cust_account_id NUMBER) is
      select ac.contact_id
        from ar_contact_roles_v acr, ar_contacts_v ac
       where acr.usage_code = 'QUALITY'
         and ac.contact_id = acr.contact_id
         and ac.email_address is not null
         and ac.customer_id = c_cust_account_id
       order by acr.last_update_date desc;
  
    l_inventory_item_id     number;
    l_cust_account_id       number;
    l_order_number          varchar2(300);
    l_invoice_to_contact_id number;
    l_email_address         varchar2(300);
    l_max_trx_date          date;
    l_quality_flag          varchar2(10);
  
    l_xxinv_eco_cust_contacts XXINV_ECO_CUST_CONTACTS%ROWTYPE;
    ---------------------------
    --    Code Section
    ---------------------------
  
  begin
  
    p_error_code := '0';
    p_error_desc := null;
  
    l_quality_flag := 'N';
    for contact_ind in contact_cur(p_inventory_item_id,
                                   p_xxinv_eco_line_customers.cust_account_id) loop
  
      if p_xxinv_eco_line_customers.contact_id is null and
         l_quality_flag = 'N' then
        ---------------- 1 -------------------------------
        -- get contact with Quality "Role" at account level
        for quality_contact_ind in quality_contact_cur(p_xxinv_eco_line_customers.cust_account_id) loop
  
          l_quality_flag := 'Y';
  
        end loop;
  
        ---------------- 2 -------------------------------
        if contact_ind.ship_to_customer_id is not null and
           contact_ind.bill_to_customer_id is not null and
           contact_ind.ship_to_customer_id =
           contact_ind.bill_to_customer_id then
  
          if contact_ind.bill_to_contact_id is not null then
            null;
          end if;
  
          if contact_ind.ship_to_contact_id is not null then
            null;
          end if;
  
          ---------------- 3 ----------------------------------
        elsif contact_ind.ship_to_customer_id is not null and
              contact_ind.bill_to_customer_id is not null and
              contact_ind.ship_to_customer_id !=
              contact_ind.bill_to_customer_id then
  
          if contact_ind.bill_to_contact_id is not null then
  
            null;
  
            set_email_to_row(p_xxinv_eco_line_customers => p_xxinv_eco_line_customers,
                             p_contact_id               => contact_ind.bill_to_contact_id,
                             p_error_code               => p_error_code,
                             p_error_desc               => p_error_desc);
  
            if '0' != p_error_code then
              return;
            end if;
  
          end if;
        end if;
      end if;
    end loop;
  
  exception
    when others then
      p_error_code := '2';
      p_error_desc := 'EXCEPTION_OTHERS XXINV_ECO_NOTIFICATION_PKG.get_contact_email_address(' ||
                      p_inventory_item_id || ',' ||
                      p_xxinv_eco_line_customers.cust_account_id || ') - ' ||
                      sqlerrm;
  
      message(p_error_desc);
  
  end get_contact_email_address;
  */
  ------------------------------------------------------------------------------
  -- Ver   When         Who        Descr
  -- ----  -----------  ---------  ---------------------------------------------
  -- 1.0   27/10/2020   Roman W.   CHG0048470 - Change notification to customers
  ------------------------------------------------------------------------------
  PROCEDURE set_account_contact(p_eco_header_id     IN NUMBER,
                                p_eco_line_id       IN NUMBER,
                                p_inventory_item_id IN NUMBER,
                                p_cust_account_id   IN NUMBER,
                                p_error_code        OUT VARCHAR2,
                                p_error_desc        OUT VARCHAR2) is
    ---------------------------
    --    Local Definition
    ---------------------------
    CURSOR contact_cur(c_inventory_item_id NUMBER,
                       c_cust_account_id   NUMBER,
                       c_date              DATE) is
      select ------------ SHIP_TO -----------------------
       ooh.ship_to_org_id     ship_to_customer_id,
       ooh.ship_to_contact_id ship_to_contact_id,
       acv_ship.email_address ship_to_email_address,
       acv_ship.first_name    ship_to_first_name,
       acv_ship.last_name     ship_to_last_name,
       ------------ BILL_TO -----------------------
       ooh.sold_to_org_id     bill_to_customer_id,
       ooh.sold_to_contact_id bill_to_contact_id,
       acv_bill.email_address bill_to_email_address,
       acv_bill.first_name    bill_to_first_name,
       acv_bill.last_name     bill_to_last_name
        from oe_order_headers_all ooh, /*oe_order_headers_all*/
             oe_order_lines_all   ool,
             hz_cust_accounts     hca,
             ar_contacts_v        acv_ship,
             ar_contacts_v        acv_bill
       where ool.HEADER_ID = ooh.header_id
         and ool.inventory_item_id = c_inventory_item_id
         and ooh.sold_to_org_id = c_cust_account_id
         and ooh.creation_date >= c_date
         and hca.cust_account_id = ooh.sold_to_org_id
         and hca.status = 'A'
         and ooh.flow_status_code = 'CLOSED'
         and ooh.ORDER_SOURCE_ID != 10
         and acv_ship.status(+) = 'A'
         and acv_bill.status(+) = 'A'
         and ooh.ship_to_contact_id = acv_ship.contact_id(+)
         and ooh.sold_to_contact_id = acv_bill.contact_id(+);
  
    /*
    select h.ship_to_customer_id,
           --h.ship_to_contact_id,                    -- Rem   09/12/2020
           acv_ship.contact_id    ship_to_contact_id, -- Added 09/12/2020
           acv_ship.email_address ship_to_email_address,
           acv_ship.first_name    ship_to_first_name,
           acv_ship.last_name     ship_to_last_name,
           h.bill_to_customer_id,
           --h.bill_to_contact_id,                    -- Rem   09/12/2020
           acv_bill.contact_id    bill_to_contact_id, -- Added 09/12/2020
           acv_bill.email_address bill_to_email_address,
           acv_bill.first_name    bill_to_first_name,
           acv_bill.last_name     bill_to_last_name
      from ra_customer_trx_lines_all l,
           ra_customer_trx_all       h,
           hz_cust_accounts          hca,
           ar_contacts_v             acv_ship,
           ar_contacts_v             acv_bill
     where h.customer_trx_id = l.customer_trx_id
       and h.trx_date > c_date
       and hca.cust_account_id = h.bill_to_customer_id --- h.ship_to_customer_id
       and l.inventory_item_id = c_inventory_item_id
       and hca.cust_account_id = c_cust_account_id
       and h.ship_to_contact_id = acv_ship.contact_id(+)
       and h.bill_to_contact_id = acv_bill.contact_id(+)
       and acv_ship.status(+) = 'A'
       and acv_bill.status(+) = 'A';
    */
  
    cursor quality_contact_cur(c_cust_account_id NUMBER) is
      select ac.contact_id, ac.email_address, ac.first_name, ac.last_name
        from ar_contact_roles_v acr, ar_contacts_v ac
       where acr.usage_code = 'QUALITY'
         and ac.contact_id = acr.contact_id
         and ac.customer_id = c_cust_account_id
         and ac.status = 'A';
  
    /*
      and not exists
    (select 'X'
             from XXINV_ECO_LINE_CUSTOMERS xelc
            where xelc.contact_id = ac.contact_id
              and xelc.cust_account_id = ac.customer_id);
      */
  
    l_inventory_item_id     number;
    l_cust_account_id       number;
    l_order_number          varchar2(300);
    l_invoice_to_contact_id number;
    l_email_address         varchar2(300);
    l_max_trx_date          date;
    l_quality_flag          varchar2(10);
  
    l_contact_id               NUMBER;
    l_contact_flag             NUMBER;
    l_error_code               VARCHAR2(300);
    l_error_desc               VARCHAR2(2000);
    l_insert_flag              VARCHAR2(10);
    l_count                    NUMBER;
    l_xxinv_eco_line_customers xxinv_eco_line_customers%ROWTYPE;
    l_date                     DATE;
    l_error_count              NUMBER;
    ---------------------------
    --    Code Section
    ---------------------------
  
  begin
  
    p_error_code := '0';
    p_error_desc := null;
  
    l_quality_flag := 'N';
    l_insert_flag  := 'N';
  
    --- Contacts with QUALITY role -----------------
    for quality_contact_ind in quality_contact_cur(p_cust_account_id) loop
    
      l_xxinv_eco_line_customers := null;
    
      l_xxinv_eco_line_customers.eco_header_id   := p_eco_header_id;
      l_xxinv_eco_line_customers.eco_line_id     := p_eco_line_id;
      l_xxinv_eco_line_customers.cust_account_id := p_cust_account_id;
    
      l_xxinv_eco_line_customers.contact_id := quality_contact_ind.contact_id;
    
      l_quality_flag := 'Y';
    
      if quality_contact_ind.email_address is null then
        l_xxinv_eco_line_customers.contact_first_name := quality_contact_ind.first_name; -- Added 09/12/2020
        l_xxinv_eco_line_customers.contact_last_name  := quality_contact_ind.last_name; -- Added 09/12/2020
        l_xxinv_eco_line_customers.mail_status        := C_ERROR;
        l_xxinv_eco_line_customers.note               := C_ERROR_NO_EMAIL;
      else
        l_xxinv_eco_line_customers.email_address      := quality_contact_ind.email_address;
        l_xxinv_eco_line_customers.contact_first_name := quality_contact_ind.first_name;
        l_xxinv_eco_line_customers.contact_last_name  := quality_contact_ind.last_name;
        l_xxinv_eco_line_customers.mail_status        := C_NEW;
        l_xxinv_eco_line_customers.note               := null;
      end if;
    
      insert_item_customer(p_row         => l_xxinv_eco_line_customers,
                           pv_error_code => l_error_code,
                           pv_error_desc => l_error_desc);
    
      l_xxinv_eco_line_customers                 := null;
      l_xxinv_eco_line_customers.eco_header_id   := p_eco_header_id;
      l_xxinv_eco_line_customers.eco_line_id     := p_eco_line_id;
      l_xxinv_eco_line_customers.cust_account_id := p_cust_account_id;
    
      if '0' != l_error_code then
      
        p_error_code := greatest(l_error_code, p_error_code);
      
        if p_error_code = l_error_code then
          p_error_desc := l_error_desc;
        end if;
      else
        l_insert_flag := 'Y';
      end if;
    
    end loop;
  
    if l_quality_flag != 'Y' then
    
      l_date := add_months(trunc(sysdate),
                           to_number(fnd_profile.VALUE('XXINV_ECO_CUSTOMER_ADD_MONTHS')));
    
      for contact_ind in contact_cur(p_inventory_item_id,
                                     p_cust_account_id,
                                     l_date) loop
      
        l_xxinv_eco_line_customers                 := null;
        l_xxinv_eco_line_customers.eco_header_id   := p_eco_header_id;
        l_xxinv_eco_line_customers.eco_line_id     := p_eco_line_id;
        l_xxinv_eco_line_customers.cust_account_id := p_cust_account_id;
      
        if contact_ind.ship_to_customer_id =
           contact_ind.bill_to_customer_id then
        
          if contact_ind.bill_to_contact_id is not null then
          
            l_xxinv_eco_line_customers.contact_id := contact_ind.bill_to_contact_id;
          
            if contact_ind.bill_to_email_address is null then
              l_xxinv_eco_line_customers.contact_first_name := contact_ind.bill_to_first_name; -- Added 09/12/2020
              l_xxinv_eco_line_customers.contact_last_name  := contact_ind.bill_to_last_name; -- Added 09/12/2020
              l_xxinv_eco_line_customers.mail_status        := C_ERROR;
              l_xxinv_eco_line_customers.note               := C_ERROR_NO_EMAIL;
            
            else
            
              l_xxinv_eco_line_customers.email_address      := contact_ind.bill_to_email_address;
              l_xxinv_eco_line_customers.contact_first_name := contact_ind.bill_to_first_name;
              l_xxinv_eco_line_customers.contact_last_name  := contact_ind.bill_to_last_name;
              l_xxinv_eco_line_customers.mail_status        := C_NEW;
              l_xxinv_eco_line_customers.note               := null;
            
            end if;
          
            insert_item_customer(p_row         => l_xxinv_eco_line_customers,
                                 pv_error_code => l_error_code,
                                 pv_error_desc => l_error_desc);
          
            l_xxinv_eco_line_customers                 := null;
            l_xxinv_eco_line_customers.eco_header_id   := p_eco_header_id;
            l_xxinv_eco_line_customers.eco_line_id     := p_eco_line_id;
            l_xxinv_eco_line_customers.cust_account_id := p_cust_account_id;
          
            if '0' != l_error_code then
              p_error_code := greatest(l_error_code, p_error_code);
              if p_error_code = l_error_code then
                p_error_desc := l_error_desc;
              end if;
            else
              l_insert_flag := 'Y';
            
            end if;
          
          end if;
        
          if contact_ind.ship_to_contact_id is not null then
          
            l_xxinv_eco_line_customers.contact_id := contact_ind.ship_to_contact_id;
          
            if contact_ind.ship_to_email_address is null then
              l_xxinv_eco_line_customers.contact_first_name := contact_ind.ship_to_first_name; -- Added 09/12/2020
              l_xxinv_eco_line_customers.contact_last_name  := contact_ind.ship_to_last_name; -- Added 09/12/2020
              l_xxinv_eco_line_customers.mail_status        := C_ERROR;
              l_xxinv_eco_line_customers.note               := C_ERROR_NO_EMAIL;
            else
              l_xxinv_eco_line_customers.email_address      := contact_ind.ship_to_email_address;
              l_xxinv_eco_line_customers.contact_first_name := contact_ind.ship_to_first_name;
              l_xxinv_eco_line_customers.contact_last_name  := contact_ind.ship_to_last_name;
              l_xxinv_eco_line_customers.mail_status        := C_NEW;
              l_xxinv_eco_line_customers.note               := null;
            end if;
          
            insert_item_customer(p_row         => l_xxinv_eco_line_customers,
                                 pv_error_code => l_error_code,
                                 pv_error_desc => l_error_desc);
          
            l_xxinv_eco_line_customers                 := null;
            l_xxinv_eco_line_customers.eco_header_id   := p_eco_header_id;
            l_xxinv_eco_line_customers.eco_line_id     := p_eco_line_id;
            l_xxinv_eco_line_customers.cust_account_id := p_cust_account_id;
          
            if '0' != l_error_code then
              p_error_code := greatest(l_error_code, p_error_code);
              if p_error_code = l_error_code then
                p_error_desc := l_error_desc;
              end if;
            else
              l_insert_flag := 'Y';
            end if;
          
          end if;
          ---------------- 3 ----------------------------------
        elsif contact_ind.bill_to_customer_id is not null and
              nvl(contact_ind.ship_to_customer_id, 0) !=
              contact_ind.bill_to_customer_id then
        
          if contact_ind.bill_to_contact_id is not null then
          
            l_xxinv_eco_line_customers.contact_id := contact_ind.bill_to_contact_id;
          
            if contact_ind.bill_to_email_address is null then
            
              l_xxinv_eco_line_customers.contact_first_name := contact_ind.bill_to_first_name; -- Added 09/12/2020
              l_xxinv_eco_line_customers.contact_last_name  := contact_ind.bill_to_last_name; -- Added 09/12/2020
              l_xxinv_eco_line_customers.mail_status        := C_ERROR;
              l_xxinv_eco_line_customers.note               := C_ERROR_NO_EMAIL;
            
            else
              l_xxinv_eco_line_customers.email_address      := contact_ind.bill_to_email_address;
              l_xxinv_eco_line_customers.contact_first_name := contact_ind.bill_to_first_name;
              l_xxinv_eco_line_customers.contact_last_name  := contact_ind.bill_to_last_name;
            
              l_xxinv_eco_line_customers.mail_status := C_NEW;
              l_xxinv_eco_line_customers.note        := null;
            end if;
          
            insert_item_customer(p_row         => l_xxinv_eco_line_customers,
                                 pv_error_code => l_error_code,
                                 pv_error_desc => l_error_desc);
          
            l_xxinv_eco_line_customers                 := null;
            l_xxinv_eco_line_customers.eco_header_id   := p_eco_header_id;
            l_xxinv_eco_line_customers.eco_line_id     := p_eco_line_id;
            l_xxinv_eco_line_customers.cust_account_id := p_cust_account_id;
          
            if '0' != l_error_code then
              p_error_code := greatest(l_error_code, p_error_code);
              if p_error_code = l_error_code then
                p_error_desc := l_error_desc;
              end if;
            else
              l_insert_flag := 'Y';
            end if;
          end if;
        end if;
      end loop;
    end if;
  
    if 'N' = l_insert_flag then
    
      if '0' = p_error_code then
        l_xxinv_eco_line_customers                 := null;
        l_xxinv_eco_line_customers.eco_header_id   := p_eco_header_id;
        l_xxinv_eco_line_customers.eco_line_id     := p_eco_line_id;
        l_xxinv_eco_line_customers.cust_account_id := p_cust_account_id;
        l_xxinv_eco_line_customers.mail_status     := C_ERROR;
        l_xxinv_eco_line_customers.note            := C_ERROR_NO_CONTACT;
      
        insert_item_customer(p_row         => l_xxinv_eco_line_customers,
                             pv_error_code => l_error_code,
                             pv_error_desc => l_error_desc);
      
        if '0' != l_error_code then
          p_error_code := greatest(l_error_code, p_error_code);
          if p_error_code = l_error_code then
            p_error_desc := l_error_desc;
          end if;
        end if;
      end if;
    end if;
  
  exception
    when others then
    
      p_error_desc := '2';
      p_error_desc := 'EXCEPTION_OTHERS XXINV_ECO_NOTIFICATION_PKG.get_contact_email_address(' ||
                      p_inventory_item_id || ',' || p_cust_account_id ||
                      ') - ' || sqlerrm;
    
      message(p_error_desc);
    
  end set_account_contact;
  ------------------------------------------------------------------------------
  -- Ver   When        Who        Description
  -- ----  ----------  ---------  ----------------------------------------------
  -- 1.0   15/10/2020  Roman W.   CHG0048470 - Change notification to customers
  ------------------------------------------------------------------------------
  procedure set_bursting_pdf_location(p_eco_pdf_location IN VARCHAR2,
                                      p_error_code       OUT VARCHAR2,
                                      p_error_desc       OUT VARCHAR2) is
    ---------------------------
    --     Code Section
    ---------------------------
  begin
    set_profile_value(pv_profile_name => 'XXINV_ECO_PDF_LOCATION',
                      pv_value        => p_eco_pdf_location,
                      pv_error_code   => p_error_code,
                      pv_error_desc   => p_error_desc);
  
  end set_bursting_pdf_location;

  ------------------------------------------------------------------------------
  -- Ver   When        Who        Description
  -- ----  ----------  ---------  ----------------------------------------------
  -- 1.0   15/10/2020  Roman W.   CHG0048470 - Change notification to customers
  ------------------------------------------------------------------------------
  function get_bursting_pdf_location return varchar2 is
    -----------------------------
    --    Local Definition
    -----------------------------
    l_ret_value VARCHAR2(300);
    -----------------------------
    --    Code section
    -----------------------------
  begin
  
    l_ret_value := fnd_profile.VALUE('XXINV_ECO_PDF_LOCATION');
  
    return l_ret_value;
  end get_bursting_pdf_location;

  -------------------------------------------------------------------------------
  -- Ver      When         Who              Description
  -- -------  -----------  ---------------  -------------------------------------
  -- 1.0      09/02/2020   Roman W.         CHG0046921
  -------------------------------------------------------------------------------
  procedure add_line_attachment(p_eco_line_id IN NUMBER,
                                p_file_name   IN VARCHAR2,
                                p_error_code  OUT VARCHAR2,
                                p_error_desc  OUT VARCHAR2) is
    --------------------------
    --    Local Definition
    --------------------------
    l_blob           BLOB := EMPTY_BLOB();
    l_status         VARCHAR2(10);
    l_status_message VARCHAR2(2000);
    l_count          NUMBER;
  
  BEGIN
    p_error_code := '0';
    p_error_desc := null;
  
    l_count := dbms_lob.fileexists(bfilename(C_XXINV_ECO_NOTIF_DIRECTORY,
                                             p_file_name));
    message(' START xxfnd_load_attachment_pkg.load_file_attachment(' ||
            p_eco_line_id || ',' || p_file_name || ') , COUNT = ' ||
            l_count);
    if 1 = l_count then
    
      message(' in if 1');
      l_blob := xxssys_file_util_pkg.get_blob_from_file(p_directory_name => C_XXINV_ECO_NOTIF_DIRECTORY,
                                                        p_file_name      => p_file_name);
    
      if dbms_lob.compare(l_blob, empty_blob()) = 0 then
      
        p_error_code := '2';
        p_error_desc := 'ERROR XXINV_ECO_NOTIFICATION_PKG.add_header_attachment(' ||
                        p_eco_line_id || ',' || p_file_name ||
                        ') - file not found';
      
        message(p_error_desc);
      
      else
        message(' in else 2');
        xxfnd_load_attachment_pkg.load_file_attachment(p_pk_id             => p_eco_line_id,
                                                       p_entity_name       => C_ENTITY_XXINV_ECO_LINES,
                                                       p_file_type         => 'PDF',
                                                       p_document_category => C_CATEGORY_XXINV_ECO_HEADER,
                                                       p_attachment_desc   => 'REQUEST_ID = ' ||
                                                                              fnd_global.CONC_REQUEST_ID,
                                                       p_filename          => p_file_name,
                                                       p_file_blob         => l_blob,
                                                       x_status            => l_status,
                                                       x_status_message    => l_status_message);
      
        if 'S' != l_status then
          p_error_code := '2';
          p_error_desc := l_status_message;
          message(p_error_desc);
        end if;
      end if;
    else
      p_error_code := '2';
      p_error_desc := 'ERROR XXINV_ECO_NOTIFICATION_PKG.add_header_attachment(' ||
                      p_eco_line_id || ',' || p_file_name ||
                      ') - file not found';
    
      message(p_error_desc);
    end if;
  
  exception
    when others then
      p_error_code := '2';
      p_error_desc := 'EXCEPTION_OTHER XXINV_ECO_NOTIFICATION_PKG.add_header_attachment(' ||
                      p_eco_line_id || ',' || p_file_name || ') - ' ||
                      sqlerrm;
    
      message(p_error_desc);
    
  end add_line_attachment;

  -------------------------------------------------------------------------------
  -- Ver      When         Who              Description
  -- -------  -----------  ---------------  -------------------------------------
  -- 1.0      09/02/2020   Roman W.         CHG0046921
  -------------------------------------------------------------------------------
  procedure add_header_attachment(p_eco_header_id IN NUMBER,
                                  p_file_name     IN varchar2,
                                  p_error_code    OUT varchar2,
                                  p_error_desc    OUT varchar2) is
    --------------------------
    --    Local Definition
    --------------------------
    l_blob           BLOB := EMPTY_BLOB();
    l_status         VARCHAR2(10);
    l_status_message VARCHAR2(2000);
  
  BEGIN
    p_error_code := '0';
    p_error_desc := null;
    message(' START xxfnd_load_attachment_pkg.load_file_attachment()');
  
    if 1 = dbms_lob.fileexists(bfilename(C_XXINV_ECO_NOTIF_DIRECTORY,
                                         p_file_name)) then
    
      l_blob := xxssys_file_util_pkg.get_blob_from_file(p_directory_name => C_XXINV_ECO_NOTIF_DIRECTORY,
                                                        p_file_name      => p_file_name);
    
      if dbms_lob.compare(l_blob, empty_blob()) = 0 then
      
        p_error_code := '2';
        p_error_desc := 'ERROR XXINV_ECO_NOTIFICATION_PKG.add_header_attachment(' ||
                        p_eco_header_id || ',' || p_file_name ||
                        ') - file not found';
      
      else
        xxfnd_load_attachment_pkg.load_file_attachment(p_pk_id             => p_eco_header_id,
                                                       p_entity_name       => C_ENTITY_XXINV_ECO_HEADER,
                                                       p_file_type         => 'PDF',
                                                       p_document_category => C_CATEGORY_XXINV_ECO_HEADER,
                                                       p_attachment_desc   => 'REQUEST_ID = ' ||
                                                                              fnd_global.CONC_REQUEST_ID,
                                                       p_filename          => p_file_name,
                                                       p_file_blob         => l_blob,
                                                       x_status            => l_status,
                                                       x_status_message    => l_status_message);
      
        if 'S' != l_status then
          p_error_code := '2';
          p_error_desc := l_status_message;
          message(p_error_desc);
        end if;
      end if;
    else
      p_error_code := '2';
      p_error_desc := 'ERROR XXINV_ECO_NOTIFICATION_PKG.add_header_attachment(' ||
                      p_eco_header_id || ',' || p_file_name ||
                      ') - file not found';
    end if;
  
  exception
    when others then
      p_error_code := '2';
      p_error_desc := 'EXCEPTION_OTHER XXINV_ECO_NOTIFICATION_PKG.add_header_attachment(' ||
                      p_eco_header_id || ',' || p_file_name || ') - ' ||
                      sqlerrm;
    
      message(p_error_desc);
  end add_header_attachment;

  --------------------------------------------------------------------------
  -- Ver   When         Who            Descr
  -- ----  -----------  -------------  -------------------------------------
  -- 1.0   13/10/2020   Roman W.       CHG0048470 - ECO notification
  --------------------------------------------------------------------------
  function get_implementation_date(p_eco VARCHAR2) return DATE is
    ---------------------------
    --    Local Definition
    ---------------------------
    l_ret_value DATE;
    ---------------------------
    --      Code Section
    ---------------------------
  begin
    select min(er.SCHEDULED_DATE)
      into l_ret_value
      from ENG_REVISED_ITEMS_V     er,
           MTL_ITEM_CATEGORIES_V   mic,
           MTL_PENDING_ITEM_STATUS mpi
     where er.organization_id =
           xxinv_utils_pkg.get_master_organization_id()
       and er.change_notice = p_eco --'ECO10906-U' -- 'ECO07102'  -- ECO
       and er.organization_id = mic.organization_id
       and er.revised_item_id = mic.inventory_item_id
       and mic.CATEGORY_SET_ID = 1100000221
       and mic.SEGMENT1 = 'Materials'
       and mic.segment7 = 'FG'
       and er.organization_id = mpi.organization_id
       and er.revised_item_id = mpi.inventory_item_id
       and mpi.status_code = 'XX_PROD';
  
    return greatest(l_ret_value, trunc(sysdate));
  
  end get_implementation_date;

  ------------------------------------------------------------------------------
  -- Ver   When        Who        Description
  -- ----  ----------  ---------  ----------------------------------------------
  -- 1.0   01/10/2020  Roman W.   CHG0048470 - Change notification to customers
  ------------------------------------------------------------------------------
  procedure insert_item_customer(p_row         IN XXINV_ECO_LINE_CUSTOMERS%ROWTYPE,
                                 pv_error_code OUT VARCHAR2,
                                 pv_error_desc OUT VARCHAR2) is
    ---------------------------
    --    Local Definition
    ---------------------------
    l_row XXINV_ECO_LINE_CUSTOMERS%ROWTYPE;
    ---------------------------
    --    Code Section
    ---------------------------
  begin
    pv_error_code := '0';
    pv_error_desc := null;
  
    l_row := p_row;
  
    /*
    if 'N' = xxobjt_general_utils_pkg.am_i_in_production and
       l_row.email_address is not null then
      l_row.email_address := 'roman.winer@stratasys.com';
    end if;
    */
  
    insert into XXINV_ECO_LINE_CUSTOMERS values l_row;
  
    commit;
  
  exception
    when DUP_VAL_ON_INDEX then
    
      update XXINV_ECO_LINE_CUSTOMERS xelc
         set xelc.email_address = l_row.email_address,
             xelc.mail_status   = l_row.mail_status,
             xelc.note          = l_row.note
       where xelc.eco_header_id = l_row.eco_header_id
         and xelc.eco_line_id = l_row.eco_line_id
         and xelc.cust_account_id = l_row.cust_account_id
         and xelc.contact_id = l_row.contact_id;
    
      commit;
    
    when others then
      pv_error_code := '2';
      pv_error_desc := 'EXCEPTION_OTHERS XXINV_ECO_NOTIFICATION_PKG.insert_item_customer() - ' ||
                       sqlerrm;
      message(pv_error_desc);
    
  end insert_item_customer;
  ------------------------------------------------------------------------------
  -- Ver   When        Who        Description
  -- ----  ----------  ---------  ----------------------------------------------
  -- 1.0   01/10/2020  Roman W.   CHG0048470 - Change notification to customers
  ------------------------------------------------------------------------------
  procedure insert_line(p_xxinv_eco_lines IN OUT XXINV_ECO_LINES%ROWTYPE,
                        pv_error_code     OUT VARCHAR2,
                        pv_error_desc     OUT VARCHAR2) is
    -----------------------------
    --     Local Definition
    -----------------------------
    -----------------------------
    --     Code Section
    -----------------------------
  begin
  
    pv_error_code := '0';
    pv_error_desc := null;
  
    insert into xxinv_eco_lines
    values p_xxinv_eco_lines
    returning eco_line_id into p_xxinv_eco_lines.eco_line_id;
  
    commit;
  
  exception
    when DUP_VAL_ON_INDEX then
    
      select xel.eco_line_id
        into p_xxinv_eco_lines.eco_line_id
        from xxinv_eco_lines xel
       where xel.eco_header_id = p_xxinv_eco_lines.eco_header_id
         and xel.inventory_item_id = p_xxinv_eco_lines.inventory_item_id;
    
    when others then
      pv_error_code := '2                                                                                                       ';
      pv_error_desc := 'EXCEPTION_OTHERS XXINV_ECO_NOTIFICATION_PKG.insert_line(' ||
                       p_xxinv_eco_lines.eco_header_id || ') - ' || sqlerrm;
    
      message(pv_error_desc);
    
  end insert_line;

  ------------------------------------------------------------------------------
  -- Ver   When        Who        Description
  -- ----  ----------  ---------  ----------------------------------------------
  -- 1.0   01/10/2020  Roman W.   CHG0048470 - Change notification to customers
  ------------------------------------------------------------------------------
  procedure insert_header(p_xxinv_eco_header_row IN OUT XXINV_ECO_HEADER%ROWTYPE,
                          pv_error_code          OUT VARCHAR2,
                          pv_error_desc          OUT VARCHAR2) is
    -------------------------
    --   Code Section
    -------------------------
  begin
    pv_error_code := '0';
    pv_error_desc := null;
  
    insert into XXINV_ECO_HEADER
    values p_xxinv_eco_header_row
    returning eco_header_id into p_xxinv_eco_header_row.eco_header_id;
  
    commit;
  exception
    when DUP_VAL_ON_INDEX then
    
      select eco_header_id
        into p_xxinv_eco_header_row.eco_header_id
        from xxinv_eco_header xeh
       where xeh.eco = p_xxinv_eco_header_row.eco;
    
    when others then
      pv_error_code := '2';
      pv_error_desc := 'EXCEPTION_OTHERS XXINV_ECO_NOTIFICATION.insert_header() - ' ||
                       sqlerrm;
    
      message(pv_error_desc);
    
  end insert_header;
  --------------------------------------------------------------------------------
  -- Ver   When         Who         Descr
  -- ----  -----------  ----------  ----------------------------------------------
  -- 1.0   14/10/2020   Roman W.    CHG0048470 - Change notification to customers
  --------------------------------------------------------------------------------
  procedure submit_bursting(p_conc_request_id IN NUMBER,
                            p_error_code      OUT VARCHAR2,
                            p_error_desc      OUT VARCHAR2) is
    -------------------------
    --   Local Definition
    -------------------------
    l_request_id NUMBER;
    -------------------------
    --     Code Section
    -------------------------
  begin
    message('SUBMIT BURSTING : ''XDO'',''XDOBURSTREP'',' ||
            p_conc_request_id);
    l_request_id := fnd_request.submit_request(application => 'XDO',
                                               program     => 'XDOBURSTREP',
                                               argument1   => 'N',
                                               argument2   => p_conc_request_id, -- Request ID of XML Publisher Report
                                               argument3   => 'Y');
    message(l_request_id);
  
    IF l_request_id > 0 THEN
      commit;
      wait_for_request(p_request_id => l_request_id,
                       p_error_code => p_error_code,
                       p_error_desc => p_error_Desc);
    
      IF '0' != p_error_code THEN
        message(p_error_desc);
      END IF;
    
    else
      p_error_code := '2';
      p_error_desc := 'ERROR conccuren : "XDOBURSTREP/XML Publisher Report Bursting Program" - not submited ';
      message(p_error_desc);
    
    END IF;
  exception
    when others then
      p_error_code := '2';
      p_error_desc := 'EXCEPTION_OTHERS XXINV_ECO_NOTIFICATION_PKG.submit_bursting(' ||
                      p_conc_request_id || ') - ' || sqlerrm;
  end submit_bursting;
  ------------------------------------------------------------------------------
  -- Concurrent : XXINV_ECO_SYNC_DATA/XXINV: Eco Sync Agile Data
  -- Tables     : XXINV_ECO_HEADER
  --              XXINV_ECO_LINES
  --              XXINV_ECO_LINE_CUSTOMERS
  --  declare
  --    errbuf           varchar2(500);
  --    retcode          varchar2(500);
  --    p_sync_from_date varchar2(20) := to_char(sysdate-100, 'DD/MM/YYYY HH24:MI:SS');
  --  begin
  --    fnd_global.apps_initialize(22797, 50623, 660);
  --   mo_global.init('ONT');
  --
  --    xxinv_eco_notification_pkg.sync_data(errbuf           => errbuf,
  --                                         retcode          => retcode,
  --                                         p_sync_from_date => p_sync_from_date);
  --  end;
  ------------------------------------------------------------------------------
  -- Ver   When        Who        Description
  -- ----  ----------  ---------  ----------------------------------------------
  -- 1.0   23/09/2020  Roman W.   CHG0048470 - Change notification to customers
  -- 1.1   24/11/2020  Roman W.       added complition_cur for update complition fields
  -- 1.2   04/02/2021  Roman W.   CHG0049362 - ECO notify customer -exclude Japan customers
  ------------------------------------------------------------------------------
  procedure sync_data(errbuf           OUT VARCHAR2,
                      retcode          OUT VARCHAR2,
                      p_sync_from_date IN VARCHAR2 -- DD-MON-RRRR HH24:MI:SS
                      ) is
    ---------------------------
    --    Local Definition
    ---------------------------
  
    ---------------------------
    --    ECO_HEADER_ID
    ---------------------------  
    cursor eco_header_cur(cd_sync_from_dte DATE) is
      select e.change_notice ECO,
             e.description,
             --'REVISION' ECO_TYPE,
             e.status_type,
             e.initiation_date,
             'Y' SEND_EXTERNAL,
             'NEW' MAIL_STATUS,
             NULL NOTE
        from ENG_ENGINEERING_CHANGES_V e, XXAGILE_CHANGES_V xgv
       where e.creation_date >= cd_sync_from_dte
         and e.organization_id = 91
         and e.change_notice = xgv.change_number
         and xgv.Notify_customers = 'Yes';
  
    ---------------------------
    --    XXINV_ECO_LINES
    ---------------------------  
    cursor eco_lines_cur(cv_eco VARCHAR2) is
      with master_organization as
       (select xxinv_utils_pkg.get_master_organization_id() master_organization_id
          from dual)
      select rownum XXROW_NUM,
             C_REVISION ECO_LINE_TYPE,
             mic.INVENTORY_ITEM_ID,
             er.REVISED_ITEM_ID,
             er.revised_item_description,
             mpi.implemented_date initiation_date,
             NULL SUBSTITUTE_ITEM_ID,
             NULL COMPLETION_DATE, -- ????
             NULL COMPETION_LOT, -- ???
             NULL NOTIFICATION_DATE, -- ??
             'NEW' MAIL_STATUS,
             NULL NOTE,
             NULL EMAIL_SENT_TO,
             er.new_item_revision BOM_REVISION,
             mo.master_organization_id organization_id
        from ENG_REVISED_ITEMS_V     er,
             MTL_ITEM_CATEGORIES_V   mic,
             MTL_PENDING_ITEM_STATUS mpi,
             master_organization     mo
       where er.change_notice = cv_eco
         and er.organization_id = mo.master_organization_id
         and er.organization_id = mic.organization_id
         and er.revised_item_id = mic.inventory_item_id
         and mic.CATEGORY_SET_ID = 1100000221
         and mic.SEGMENT1 = 'Materials'
         and mic.segment7 = 'FG'
         and mic.segment6 in ('FDM', 'POLYJET')
         and er.organization_id = mpi.organization_id
         and er.revised_item_id = mpi.inventory_item_id
         and mpi.status_code = 'XX_PROD'
         and mpi.effective_date =
             (select max(mpis.effective_date)
                from MTL_PENDING_ITEM_STATUS mpis
               where mpis.inventory_item_id = mpi.inventory_item_id
                 and mpis.organization_id = mic.organization_id
              --and mpis.status_code = mpi.status_code
              );
  
    -------------------------
    --    XXINV_ECO_LINE_CUSTOMERS
    -------------------------   
    -- Added by Roman W. 04/02/2021 CHG0049362
    cursor item_customer_cur(c_inventory_item_id NUMBER, c_date DATE) is
      with xxexclude_country as
       (select flv.LOOKUP_CODE country_code
          from fnd_lookup_values_vl flv
         where flv.LOOKUP_TYPE = 'XXSERVICE_COUNTRIES_SECURITY'
           and flv.attribute3 = 'Y'
           and trunc(sysdate) between
               nvl(flv.START_DATE_ACTIVE, trunc(sysdate)) and
               nvl(flv.END_DATE_ACTIVE, trunc(sysdate)))
      select ooh.sold_to_org_id cust_account_id
        from oe_order_headers_all ooh,
             oe_order_lines_all   ool,
             hz_cust_accounts     hca,
             xxexclude_country    xec
       where ool.HEADER_ID = ooh.header_id
         and ool.inventory_item_id = c_inventory_item_id
         and ooh.creation_date >= c_date
         and ooh.flow_status_code = 'CLOSED'
         and ooh.ORDER_SOURCE_ID != 10
         and hca.cust_account_id = ooh.sold_to_org_id
         and hca.status = 'A'
            --and xxoe_utils_pkg.get_ship_to_country_code(ool.line_id) != xec.country_code
         and xxoe_utils_pkg.get_ship_to_country_code(ool.ship_to_org_id) !=
             xec.country_code
       group by ooh.sold_to_org_id;
  
    -------------------------------------------
    --         Complition Date
    -------------------------------------------
    cursor complition_cur(c_sync_from_date DATE) is
      select xel.eco_line_id,
             m.transaction_date COMPLETION_DATE,
             m.lot_number       COMPETION_LOT
        from mtl_transaction_lot_numbers m,
             wip_discrete_jobs           w,
             xxinv_eco_lines             xel
       where m.transaction_date > c_sync_from_date
         and m.transaction_source_type_id = 5
         and m.transaction_source_id = w.wip_entity_id
         and m.inventory_item_id = xel.inventory_item_id
         and w.bom_revision = xel.bom_revision
         and xel.eco_line_type = C_REVISION;
  
    ld_sync_from_date DATE;
    lv_sync_from_date VARCHAR2(30);
    ld_sysdate        DATE;
    lv_sysdate        VARCHAR2(30);
    lv_error_code     VARCHAR2(30);
    lv_error_desc     VARCHAR2(500);
  
    l_xxinv_eco_header         XXINV_ECO_HEADER%ROWTYPE;
    l_xxinv_eco_lines          XXINV_ECO_LINES%ROWTYPE;
    l_xxinv_eco_line_customers XXINV_ECO_LINE_CUSTOMERS%ROWTYPE;
    l_valid_contacts_count     NUMBER;
    l_customer_item            NUMBER;
    l_date_from                DATE := add_months(trunc(sysdate),
                                                  to_number(fnd_profile.VALUE('XXINV_ECO_CUSTOMER_ADD_MONTHS')));
    ---------------------------
    --    Code Section
    ---------------------------
  begin
    errbuf  := null;
    retcode := '0';
  
    lv_sync_from_date := nvl(p_sync_from_date,
                             fnd_profile.VALUE('XXINV_ECO_SYNC_DATA_LAST_RUN'));
  
    ld_sysdate := sysdate;
    lv_sysdate := to_char(ld_sysdate, C_DATE_TIME_FORMAT);
  
    message('START : XXINV_ECO_NOTIFICATION.sync_data ');
    message('P_LAST_RUNNING_DATE : ' || lv_sync_from_date);
    message('-----------------------------------------------');
  
    ld_sync_from_date := fnd_conc_date.STRING_TO_DATE(lv_sync_from_date);
  
    for eco_header_ind in eco_header_cur(ld_sync_from_date) loop
      message('ECO : ' || eco_header_ind.ECO);
      l_xxinv_eco_header := null;
    
      ---- Add existing validation -----
      if 'Y' = is_header_exists(eco_header_ind.eco) then
        message(eco_header_ind.eco || ' - CONTINUED');
        continue;
      end if;
    
      ----------------------------------
      for eco_lines_ind in eco_lines_cur(eco_header_ind.ECO) loop
      
        message('INVENTORY_ITEM_ID : ' || eco_lines_ind.inventory_item_id);
        l_xxinv_eco_lines := null;
      
        l_xxinv_eco_header.eco             := eco_header_ind.eco;
        l_xxinv_eco_header.eco_description := eco_header_ind.description;
        -- l_xxinv_eco_header.eco_type              := eco_header_ind.eco_type;
        l_xxinv_eco_header.implementation_date   := get_implementation_date(eco_header_ind.eco);
        l_xxinv_eco_header.notification_ext_date := l_xxinv_eco_header.implementation_date +
                                                    to_number(fnd_profile.VALUE('XXINV_ECO_EXT_NOTIF_DAYS'));
        l_xxinv_eco_header.send_external         := eco_header_ind.send_external;
        l_xxinv_eco_header.mail_status           := eco_header_ind.mail_status;
        l_xxinv_eco_header.note                  := eco_header_ind.note;
      
        begin
        
          select m.transaction_date COMPLETION_DATE, m.lot_number
            into eco_lines_ind.COMPLETION_DATE, eco_lines_ind.COMPETION_LOT
            from mtl_transaction_lot_numbers m, wip_discrete_jobs w
           where m.transaction_date > ld_sync_from_date
             and m.transaction_source_type_id = 5
             and m.transaction_source_id = w.wip_entity_id
             and m.inventory_item_id = eco_lines_ind.inventory_item_id
             and w.bom_revision = eco_lines_ind.bom_revision;
        
        exception
          when others then
          
            message('EXCEPTION_OTHERS :SQL (' ||
                    eco_lines_ind.inventory_item_id || ',' ||
                    eco_lines_ind.bom_revision || ',' ||
                    to_date(ld_sync_from_date, 'DD/MM/YYYY') || ') - ' ||
                    sqlerrm);
            eco_lines_ind.COMPLETION_DATE := null;
            eco_lines_ind.COMPETION_LOT   := null;
        end;
      
        message('---- check is substitution ----');
        begin
          select msi_substitute.inventory_item_id
            into eco_lines_ind.SUBSTITUTE_ITEM_ID
            from XXAGILE_ITEMS_V    ag,
                 mtl_system_items_b msi,
                 mtl_system_items_b msi_substitute
           where ag.item_number = msi.segment1
             and msi.inventory_item_id = eco_lines_ind.inventory_item_id
             and msi.organization_id = 91
             and msi_substitute.segment1 = ag.substitute
             and msi_substitute.organization_id = msi.organization_id;
        
          l_xxinv_eco_lines.ECO_LINE_TYPE := C_SUBSTITUTE;
          message('ECO = ' || l_xxinv_eco_header.eco || ',' ||
                  'SUBSTITUTE_ITEM_ID - ' ||
                  eco_lines_ind.SUBSTITUTE_ITEM_ID || ', ' ||
                  'ECO_LINE_TYPE - ' || l_xxinv_eco_lines.ECO_LINE_TYPE);
        
        exception
          when OTHERS then
            message('EXCEPTION_OTHERS : SQL2 ( ' || 'ECO = ' ||
                    l_xxinv_eco_header.eco || ',' ||
                    eco_lines_ind.inventory_item_id || ',' ||
                    eco_lines_ind.organization_id || ') - ' || sqlerrm);
          
            eco_lines_ind.SUBSTITUTE_ITEM_ID := null;
            l_xxinv_eco_lines.ECO_LINE_TYPE  := C_REVISION;
        end;
      
        l_xxinv_eco_lines.eco_header_id     := l_xxinv_eco_header.eco_header_id;
        l_xxinv_eco_lines.inventory_item_id := eco_lines_ind.inventory_item_id;
        --        l_xxinv_eco_lines.ECO_LINE_TYPE            := eco_lines_ind.ECO_LINE_TYPE;
        l_xxinv_eco_lines.REVISED_ITEM_ID          := eco_lines_ind.REVISED_ITEM_ID;
        l_xxinv_eco_lines.REVISED_ITEM_DESCRIPTION := eco_lines_ind.REVISED_ITEM_DESCRIPTION;
        l_xxinv_eco_lines.INITIATION_DATE          := eco_lines_ind.INITIATION_DATE;
        l_xxinv_eco_lines.SUBSTITUTE_ITEM_ID       := eco_lines_ind.SUBSTITUTE_ITEM_ID;
        l_xxinv_eco_lines.COMPLETION_DATE          := eco_lines_ind.COMPLETION_DATE;
        l_xxinv_eco_lines.COMPETION_LOT            := eco_lines_ind.COMPETION_LOT;
        l_xxinv_eco_lines.BOM_REVISION             := eco_lines_ind.BOM_REVISION;
        l_xxinv_eco_lines.NOTIFICATION_DATE        := eco_lines_ind.NOTIFICATION_DATE;
        l_xxinv_eco_lines.MAIL_STATUS              := eco_lines_ind.MAIL_STATUS;
        l_xxinv_eco_lines.NOTE                     := eco_lines_ind.NOTE;
        l_xxinv_eco_lines.EMAIL_SENT_TO            := eco_lines_ind.EMAIL_SENT_TO;
      
        -----------------------------
        --     Insert Header
        -----------------------------
        if 1 = eco_lines_ind.XXROW_NUM then
          -------------------------------------
          -- Insert/Update to XXINV_ECO_HEADER
          -------------------------------------
          insert_header(p_xxinv_eco_header_row => l_xxinv_eco_header,
                        pv_error_code          => lv_error_code,
                        pv_error_desc          => lv_error_desc);
        
          if '0' != lv_error_code then
            retcode := greatest(lv_error_code, retcode);
            if retcode = lv_error_code then
              errbuf := lv_error_desc;
            end if;
          else
            l_xxinv_eco_lines.eco_header_id := l_xxinv_eco_header.eco_header_id;
          end if;
        
        end if;
      
        -----------------------------
        --     Insert Line
        -----------------------------
        insert_line(p_xxinv_eco_lines => l_xxinv_eco_lines,
                    pv_error_code     => lv_error_code,
                    pv_error_desc     => lv_error_desc);
      
        if '0' != lv_error_code then
          retcode := greatest(lv_error_code, retcode);
          if retcode = lv_error_code then
            errbuf := lv_error_desc;
          end if;
        end if;
      
        if C_REVISION = l_xxinv_eco_lines.eco_line_type then
          l_customer_item := l_xxinv_eco_lines.inventory_item_id;
        elsif C_SUBSTITUTE = l_xxinv_eco_lines.eco_line_type then
          l_customer_item := l_xxinv_eco_lines.substitute_item_id;
        else
          l_customer_item := null;
        end if;
      
        ----------------- Customer Item ------------------
        if l_xxinv_eco_lines.eco_header_id is not null and
           l_xxinv_eco_lines.eco_line_id is not null and
           l_customer_item is not null then
        
          l_date_from := add_months(trunc(sysdate),
                                    to_number(fnd_profile.VALUE('XXINV_ECO_CUSTOMER_ADD_MONTHS')));
        
          for item_customer_ind in item_customer_cur(l_customer_item,
                                                     l_date_from) loop
            /*
            message('CUSTOMER_ITEM = ' || l_customer_item ||
                    ', HEADER_ID = ' || l_xxinv_eco_lines.eco_header_id ||
                    ', LINE_ID = ' || l_xxinv_eco_lines.eco_line_id ||
                    ', CUSTOMER_ID = ' ||
                    item_customer_ind.cust_account_id);
            */
            set_account_contact(p_eco_header_id     => l_xxinv_eco_lines.eco_header_id,
                                p_eco_line_id       => l_xxinv_eco_lines.eco_line_id,
                                p_inventory_item_id => l_customer_item, --l_xxinv_eco_lines.inventory_item_id,
                                p_cust_account_id   => item_customer_ind.cust_account_id,
                                p_error_code        => lv_error_code,
                                p_error_desc        => lv_error_desc);
          
          end loop; -- Cust
        end if;
      
        select count(*)
          into l_valid_contacts_count
          from xxinv_eco_line_customers xelc
         where xelc.eco_line_id = l_xxinv_eco_lines.eco_line_id
           and xelc.mail_status != C_ERROR;
      
        if eco_header_ind.eco = 'ECO11134' then
          message('l_valid_contacts_count = ' || l_valid_contacts_count ||
                  ' , ECO_LINE_ID = ' || l_xxinv_eco_lines.eco_line_id);
        end if;
      
        if 0 = l_valid_contacts_count then
          update_line_mail_status(p_eco_line_id => l_xxinv_eco_lines.eco_line_id,
                                  p_mail_status => C_ERROR,
                                  p_note        => C_ERROR_HEADER,
                                  p_error_code  => lv_error_code,
                                  p_error_desc  => lv_error_desc);
        end if;
      
      end loop; -- Lines
    
      select count(*)
        into l_valid_contacts_count
        from xxinv_eco_line_customers xelc
       where xelc.eco_header_id = l_xxinv_eco_header.eco_header_id
         and xelc.mail_status != C_ERROR;
    
      if 0 = l_valid_contacts_count then
        update_header_mail_status(p_eco_header_id => l_xxinv_eco_header.eco_header_id,
                                  p_mail_status   => C_ERROR,
                                  p_note          => C_ERROR_HEADER,
                                  p_error_code    => lv_error_code,
                                  p_error_desc    => lv_error_desc);
      end if;
    end loop; -- Header
  
    set_profile_value(pv_value      => lv_sysdate,
                      pv_error_code => retcode,
                      pv_error_desc => errbuf);
  
    --- Complition Date ---
    for complition_ind in complition_cur(ld_sync_from_date) loop
    
      update xxinv_eco_lines xel
         set xel.completion_date = complition_ind.completion_date,
             xel.competion_lot   = complition_ind.competion_lot
       where xel.eco_line_id = complition_ind.eco_line_id;
    
      commit;
    
    end loop;
  
    message('END : XXINV_ECO_NOTIFICATION.sync_data ');
  
  exception
    when others then
      errbuf  := 'EXCEPTION_OTHERS XXINV_ECO_NOTIFICATION.sync_data(' ||
                 p_sync_from_date || ') - ' || sqlerrm;
      retcode := '2';
      message(errbuf);
  end sync_data;

  ------------------------------------------------------------------------------
  -- Concurrent : XXINV_ECO_NOTIF_INT / XXINV: Eco Notification Internal
  --     Tables : XXINV_ECO_HEADER
  --              XXINV_ECO_LINES
  ------------------------------------------------------------------------------
  -- Ver   When        Who        Description
  -- ----  ----------  ---------  ----------------------------------------------
  -- 1.0   23/09/2020  Roman W.   CHG0048470 - Change notification to customers
  ------------------------------------------------------------------------------
  procedure notification_int(errbuf         OUT VARCHAR2,
                             retcode        OUT VARCHAR2,
                             p_date         IN VARCHAR2, -- DD-MON-RRRR HH24:MI:SS
                             p_pdf_location IN VARCHAR2) is
    ---------------------------
    --    Local Definition
    ---------------------------
    CURSOR eco_cur(c_date DATE) is
      select XEH.ECO_HEADER_ID, XEH.ECO, XEL.ECO_LINE_TYPE ECO_TYPE
        from XXINV_ECO_HEADER XEH, XXINV_ECO_LINES XEL
       where 1 = 1
         and XEH.send_external = 'Y'
         and XEH.mail_status = C_NEW
         and trunc(XEH.implementation_date) <= trunc(c_date)
         and XEL.eco_header_id = XEH.ECO_HEADER_ID
         and exists (select 'Y'
                from xxinv_eco_line_customers xelc
               where xelc.eco_header_id = xeh.eco_header_id
                 and xelc.mail_status != C_ERROR)
       group by XEH.ECO_HEADER_ID, XEH.ECO, XEL.ECO_LINE_TYPE;
  
    l_request_id   NUMBER;
    l_error_code   VARCHAR2(30);
    l_error_desc   VARCHAR2(2000);
    l_date         DATE;
    l_pdf_location VARCHAR2(2000);
    l_sysdate      DATE;
    ---------------------------
    --    Code Section
    ---------------------------
  begin
    errbuf  := null;
    retcode := '0';
  
    l_date := fnd_conc_date.STRING_TO_DATE(nvl(p_date,
                                               to_char(sysdate,
                                                       'DD-MON-RRRR')));
  
    -------------------------------------------------------------
    ------------- Create Directory for PDF attachments ----------
    -------------------------------------------------------------
    l_pdf_location := nvl(p_pdf_location, get_bursting_pdf_location());
  
    xxssys_dpl_pkg.make_directory(p_dir_path   => l_pdf_location,
                                  p_directory  => C_XXINV_ECO_NOTIF_DIRECTORY,
                                  p_error_code => l_error_code,
                                  p_error_desc => l_error_desc);
  
    if '0' != l_error_code then
      retcode := greatest(retcode, l_error_code);
      if retcode = l_error_code then
        errbuf := l_error_desc;
      end if;
    
      return;
    end if;
  
    ---- Set Bursting PDF Location ----
    set_bursting_pdf_location(l_pdf_location, l_error_code, l_error_desc);
  
    if '0' != l_error_code then
      retcode := greatest(retcode, l_error_code);
      if retcode = l_error_code then
        errbuf := l_error_desc;
      end if;
      return;
    end if;
    ------------------ Update
    ------------------ R E V I S I O N  /  S U B S T I T U T I O N -------------------
    for eco_ind in eco_cur(l_date) loop
    
      message('LOOP : ECO - ' || eco_ind.ECO);
    
      if C_REVISION = eco_ind.ECO_TYPE then
        ------- Submit concurrent : "Eco Revision Notification Internal" --------
        l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                                   program     => 'XXINV_ECO_NOTIF_REVISION_INT', -- 'Eco Revision Notification Internal'
                                                   description => '',
                                                   start_time  => '',
                                                   sub_request => FALSE,
                                                   argument1   => eco_ind.ECO_HEADER_ID);
        message('fnd_request.submit_request(''XXOBJT'',''XXINV_ECO_NOTIF_REVISION_INT'',' ||
                eco_ind.ECO_HEADER_ID || '(' || eco_ind.ECO || ')');
      
      elsif C_SUBSTITUTE = eco_ind.ECO_TYPE then
        ------- Submit concurrent : "Eco Revision Notification Internal" --------
        l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                                   program     => 'XXINV_ECO_NOTIF_SUBSTITUTE_INT', -- 'Eco Revision Notification Internal'
                                                   description => '',
                                                   start_time  => '',
                                                   sub_request => FALSE,
                                                   argument1   => eco_ind.ECO_HEADER_ID);
      
        message('fnd_request.submit_request(''XXOBJT'',''XXINV_ECO_NOTIF_SUBSTITUTE_INT'',' ||
                eco_ind.ECO_HEADER_ID || '(' || eco_ind.ECO || ')');
      
      end if;
    
      COMMIT;
    
      if l_request_id > 0 then
      
        wait_for_request(p_request_id => l_request_id,
                         p_error_code => l_error_code,
                         p_error_desc => l_error_Desc);
      
        IF '0' != l_error_code THEN
          message(l_error_desc);
          -----------------------
          -- Add ERROR HANDLING with update header status !!!!!!!!!!!!!!!!!!!!!!
          -----------------------
          retcode := greatest(retcode, l_error_code);
          if retcode = l_error_code then
            errbuf := l_error_desc;
          end if;
        
          update_header_mail_status(p_eco_header_id => eco_ind.ECO_HEADER_ID,
                                    p_mail_status   => C_ERROR,
                                    p_note          => l_error_desc,
                                    p_error_code    => l_error_code,
                                    p_error_desc    => l_error_desc);
        END IF;
      
      else
      
        l_error_code := '2';
      
        if C_REVISION = eco_ind.ECO_TYPE then
          l_error_desc := 'ERROR conccuren : "XXINV_ECO_NOTIF_REVISION_INT/XXINV: Eco Revision Notification Internal" - not submited ';
        elsif C_SUBSTITUTE = eco_ind.ECO_TYPE then
          l_error_desc := 'ERROR conccuren : "XXINV_ECO_NOTIF_SUBSTITUTE_INT/XXINV: Eco Substitute Notification Internal" - not submited ';
        end if;
      
        message(l_error_desc);
      
        retcode := greatest(retcode, l_error_code);
        if retcode = l_error_code then
          errbuf := l_error_desc;
        end if;
      
        update_header_mail_status(p_eco_header_id => eco_ind.ECO_HEADER_ID,
                                  p_mail_status   => C_ERROR,
                                  p_note          => l_error_desc,
                                  p_error_code    => l_error_code,
                                  p_error_desc    => l_error_desc);
      
      end if;
    
      ------------ Submit Bursting ----------------
      submit_bursting(p_conc_request_id => l_request_id,
                      p_error_code      => l_error_code,
                      p_error_desc      => l_error_desc);
    
      if '0' != l_error_code then
        retcode := greatest(retcode, l_error_code);
        if retcode = l_error_code then
          errbuf := l_error_desc;
        end if;
        -----------------------
        -- Add ERROR HANDLING with update header status !!!!!!!!!!!!!!!!!!!!!!
        -----------------------
        update_header_mail_status(p_eco_header_id => eco_ind.ECO_HEADER_ID,
                                  p_mail_status   => C_ERROR,
                                  p_note          => l_error_desc,
                                  p_error_code    => l_error_code,
                                  p_error_desc    => l_error_desc);
      
        continue;
      else
      
        update_header_mail_status(p_eco_header_id => eco_ind.ECO_HEADER_ID,
                                  p_mail_status   => C_SUCCESS_INT,
                                  p_note          => null,
                                  p_email_sent_to => get_notification_int_email(eco_ind.eco),
                                  p_error_code    => l_error_code,
                                  p_error_desc    => l_error_desc);
      
      end if;
    
      ---------- Add attachment ------------------
      add_header_attachment(p_eco_header_id => eco_ind.ECO_HEADER_ID,
                            p_file_name     => eco_ind.ECO || '.pdf',
                            p_error_code    => l_error_code,
                            p_error_desc    => l_error_desc);
    
      if '0' != l_error_code then
      
        retcode := greatest(retcode, l_error_code);
        if retcode = l_error_code then
          errbuf := l_error_desc;
        end if;
      
        update_header_mail_status(p_eco_header_id => eco_ind.ECO_HEADER_ID,
                                  p_mail_status   => C_ERROR,
                                  p_note          => l_error_desc,
                                  p_error_code    => l_error_code,
                                  p_error_desc    => l_error_desc);
      
        retcode := greatest(retcode, l_error_code);
        if retcode = l_error_code then
          errbuf := l_error_desc;
        end if;
      
        remove_file(p_directory  => C_XXINV_ECO_NOTIF_DIRECTORY,
                    p_file_name  => eco_ind.ECO || '.pdf',
                    p_error_code => l_error_code,
                    p_error_desc => l_error_desc);
      
        retcode := greatest(retcode, l_error_code);
      
        if retcode = l_error_code then
          errbuf := l_error_desc;
        end if;
      
      end if;
    
    end loop;
  
  exception
    when others then
      errbuf  := 'EXCEPTION_OTHERS XXINV_ECO_NOTIFICATION_PKG.notification_int() - ' ||
                 sqlerrm;
      retcode := '2';
    
      message(errbuf);
    
  end notification_int;

  ------------------------------------------------------------------------------
  -- Concurrent : XXINV_ECO_NOTIF_EXT / XXINV: Eco Notification External
  ------------------------------------------------------------------------------
  -- Ver   When        Who        Description
  -- ----  ----------  ---------  ----------------------------------------------
  -- 1.0   23/09/2020  Roman W.   CHG0048470 - Change notification to customers
  -- 1.1   01/12/2020  Roman W.       REVISION/SUBSTITUTE ITEM bug fix
  -- 1.2   28/01/2020  Roman W.   CHG0048470 - added exclude ORG_ID
  -- 1.3   04/02/2021  Roman W.   CHG0049362 - exclude countries from list
  ------------------------------------------------------------------------------
  procedure notification_ext(errbuf  OUT VARCHAR2,
                             retcode OUT VARCHAR2,
                             P_DATE  IN VARCHAR2 -- DD-MON-RRRR HH24:MI:SS
                             ) is
    ---------------------------
    --    Local Definition
    ---------------------------
    CURSOR eco_cur(c_date DATE) is
    -------------- REVISION -------------
      select xeh.eco_header_id, xeh.eco, C_REVISION ECO_TYPE
        from XXINV_ECO_HEADER XEH
       where 1 = 1
         and XEH.Send_External = 'Y'
         and XEH.MAIL_STATUS = C_SUCCESS_INT
         and trunc(XEH.NOTIFICATION_EXT_DATE) <= trunc(c_date)
         and exists
       (select 'Y'
                from xxinv_eco_line_customers xelc, XXINV_ECO_LINES XEL
               where XEL.eco_header_id = xeh.eco_header_id
                 and xelc.eco_header_id = XEL.eco_header_id
                 and xelc.eco_line_id = XEL.eco_line_id
                 and xelc.mail_status != C_ERROR
                 and xel.eco_line_type = C_REVISION)
      union all
      -------------- SUBSTITUTE -------------
      select xeh.eco_header_id, xeh.eco, C_SUBSTITUTE ECO_TYPE
        from XXINV_ECO_HEADER XEH
       where 1 = 1
         and XEH.Send_External = 'Y'
         and XEH.MAIL_STATUS = C_SUCCESS_INT
         and XEH.NOTIFICATION_EXT_DATE <= trunc(c_date)
         and exists
       (select 'Y'
                from xxinv_eco_line_customers xelc, XXINV_ECO_LINES XEL
               where XEL.eco_header_id = xeh.eco_header_id
                 and xelc.eco_header_id = XEL.eco_header_id
                 and xelc.eco_line_id = XEL.eco_line_id
                 and xelc.mail_status != C_ERROR
                 and xel.eco_line_type = C_SUBSTITUTE);
  
    -------------------------
    --    Eco Items
    -------------------------
    cursor eco_lines_cur(p_eco_header_id NUMBER) is
      select xel.eco_line_id,
             xel.eco_line_type,
             xel.inventory_item_id,
             xel.substitute_item_id
        from xxinv_eco_lines xel
       where xel.eco_header_id = p_eco_header_id;
  
    -------------------------
    --    Customer Item
    -------------------------
    cursor item_customer_cur(c_inventory_item_id NUMBER, c_date DATE) is
    -- Added by Roman W. 28/01/2020 - EXCLUDE ORG_ID List
    /*
                                                                                                  with xx_exclude_ou as
                                                                                                   (select ffv.FLEX_VALUE org_id
                                                                                                      from FND_FLEX_VALUE_SETS ffvs,
                                                                                                           FND_FLEX_VALUES     ffv,
                                                                                                           hr_operating_units  hou
                                                                                                     where ffvs.flex_value_set_name = 'XXINV_ECO_EXCLUDE_OU'
                                                                                                       and ffv.flex_value_set_id = ffvs.flex_value_set_id
                                                                                                       and ffv.enabled_flag = 'Y'
                                                                                                       and trunc(sysdate) between
                                                                                                           nvl(ffv.start_date_active, trunc(sysdate)) and
                                                                                                           nvl(ffv.end_date_active, trunc(sysdate))
                                                                                                       and to_char(hou.organization_id) = ffv.FLEX_VALUE
                                                                                                       and trunc(sysdate) between nvl(hou.date_from, trunc(sysdate)) and
                                                                                                           nvl(hou.date_to, trunc(sysdate)))
                                                                                                  -- End Added by Roman W. 28/01/2020 - EXCLUDE ORG_ID List
                                                                                                  select ooh.sold_to_org_id cust_account_id
                                                                                                    from oe_order_headers_all ooh, 
                                                                                                         oe_order_lines_all   ool,
                                                                                                         hz_cust_accounts     hca,
                                                                                                         xx_exclude_ou        xeo
                                                                                                   where ool.inventory_item_id = c_inventory_item_id
                                                                                                     and ooh.creation_date >= c_date
                                                                                                     and ooh.flow_status_code = 'CLOSED'
                                                                                                     and ooh.ORDER_SOURCE_ID != 10
                                                                                                     and ool.HEADER_ID = ooh.header_id
                                                                                                     and hca.cust_account_id = ooh.sold_to_org_id
                                                                                                     and hca.status = 'A'
                                                                                                     and xeo.org_id != to_char(ooh.org_id)
                                                                                                   group by ooh.sold_to_org_id;
                                                                                                   */
    -- Added By Roman W. 04/02/2021 CHG0049362   
      select ooh.sold_to_org_id cust_account_id
        from oe_order_headers_all ooh,
             oe_order_lines_all   ool,
             hz_cust_accounts     hca
       where ool.inventory_item_id = c_inventory_item_id
         and ooh.creation_date >= c_date
         and ooh.flow_status_code = 'CLOSED'
         and ooh.ORDER_SOURCE_ID != 10
         and ool.HEADER_ID = ooh.header_id
         and hca.cust_account_id = ooh.sold_to_org_id
         and hca.status = 'A'
         and xxoe_utils_pkg.get_ship_to_country_code(p_line_id => ool.line_id) not in
             (select flv.LOOKUP_CODE
                from FND_LOOKUP_VALUES_VL flv
               where flv.LOOKUP_TYPE = 'XXSERVICE_COUNTRIES_SECURITY'
                 and flv.attribute3 = 'Y')
       group by ooh.sold_to_org_id;
  
    ---------------------------
    --   Local Definition
    ---------------------------
    l_request_id    NUMBER;
    l_error_code    VARCHAR2(30);
    l_error_desc    VARCHAR2(2000);
    l_date          DATE;
    l_pdf_location  VARCHAR2(2000);
    l_sysdate       DATE;
    l_customer_item NUMBER;
    l_date_from     DATE;
    ---------------------------
    --    Code Section
    ---------------------------
  begin
    errbuf  := null;
    retcode := '0';
  
    message('Start :  xxinv_eco_notification_pkg.notification_int(' ||
            p_date || ');');
  
    l_date := fnd_conc_date.STRING_TO_DATE(nvl(p_date,
                                               to_char(sysdate,
                                                       'DD-MON-RRRR')));
  
    for eco_ind in eco_cur(l_date) loop
    
      for eco_lines_int in eco_lines_cur(eco_ind.eco_header_id) loop
      
        l_date_from := add_months(trunc(sysdate),
                                  to_number(fnd_profile.VALUE('XXINV_ECO_CUSTOMER_ADD_MONTHS')));
      
        for item_customer_ind in item_customer_cur(eco_lines_int.inventory_item_id,
                                                   l_date_from) loop
        
          if C_REVISION = eco_lines_int.eco_line_type then
            l_customer_item := eco_lines_int.inventory_item_id;
          elsif C_SUBSTITUTE = eco_lines_int.eco_line_type then
            l_customer_item := eco_lines_int.substitute_item_id;
          else
            l_customer_item := null;
          end if;
        
          if l_customer_item is not null then
            set_account_contact(p_eco_header_id     => eco_ind.eco_header_id,
                                p_eco_line_id       => eco_lines_int.eco_line_id,
                                p_inventory_item_id => l_customer_item,
                                p_cust_account_id   => item_customer_ind.cust_account_id,
                                p_error_code        => l_error_code,
                                p_error_desc        => l_error_desc);
          end if;
        
        end loop;
      end loop;
    
      message('LOOP : ECO - ' || eco_ind.ECO);
    
      if C_REVISION = eco_ind.ECO_TYPE then
      
        ------- Submit concurrent : "Eco Revision Notification External" --------
        l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                                   program     => 'XXINV_ECO_NOTIF_REVISION_EXT', -- 'Eco Revision Notification External'
                                                   description => '',
                                                   start_time  => '',
                                                   sub_request => FALSE,
                                                   argument1   => eco_ind.ECO_HEADER_ID);
      
        message('fnd_request.submit_request(''XXOBJT'',''XXINV_ECO_NOTIF_REVISION_EXT'',' ||
                eco_ind.ECO_HEADER_ID || '(' || eco_ind.ECO || ')');
      
      elsif C_SUBSTITUTE = eco_ind.ECO_TYPE then
      
        null;
      
        ------- Submit concurrent : "Eco Revision Notification Internal" --------
        l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                                   program     => 'XXINV_ECO_NOTIF_SUBSTITUTE_EXT', -- 'Eco Substitution Notification Internal'
                                                   description => '',
                                                   start_time  => '',
                                                   sub_request => FALSE,
                                                   argument1   => eco_ind.ECO_HEADER_ID);
      
        message('fnd_request.submit_request(''XXOBJT'',''XXINV_ECO_NOTIF_SUBSTITUTE_INT'',' ||
                eco_ind.ECO_HEADER_ID || '(' || eco_ind.ECO || ')');
      
      end if;
    
      COMMIT;
    
      if l_request_id > 0 then
      
        wait_for_request(p_request_id => l_request_id,
                         p_error_code => l_error_code,
                         p_error_desc => l_error_desc);
      
        IF '0' != l_error_code THEN
        
          message(l_error_desc);
        
          retcode := greatest(retcode, l_error_code);
          if retcode = l_error_code then
            errbuf := l_error_desc;
          end if;
        
          update_header_mail_status(p_eco_header_id => eco_ind.ECO_HEADER_ID,
                                    p_mail_status   => C_ERROR,
                                    p_note          => l_error_desc,
                                    p_error_code    => l_error_code,
                                    p_error_desc    => l_error_desc);
        END IF;
      
        ------------ Submit Bursting ----------------
        submit_bursting(p_conc_request_id => l_request_id,
                        p_error_code      => l_error_code,
                        p_error_desc      => l_error_desc);
      
        if '0' != l_error_code then
        
          retcode := greatest(retcode, l_error_code);
          if retcode = l_error_code then
            errbuf := l_error_desc;
          end if;
        
          update_header_mail_status(p_eco_header_id => eco_ind.ECO_HEADER_ID,
                                    p_mail_status   => C_ERROR,
                                    p_note          => l_error_desc,
                                    p_error_code    => l_error_code,
                                    p_error_desc    => l_error_desc);
        
          continue;
        else
          update_header_mail_status(p_eco_header_id => eco_ind.ECO_HEADER_ID,
                                    p_mail_status   => C_SUCCESS_EXT,
                                    p_note          => NULL,
                                    p_error_code    => l_error_code,
                                    p_error_desc    => l_error_desc);
        end if;
      
      else
      
        l_error_code := '2';
      
        if C_REVISION = eco_ind.ECO_TYPE then
          l_error_desc := 'ERROR conccuren : "XXINV_ECO_NOTIF_REVISION_INT/XXINV: Eco Revision Notification Internal" - not submited ';
        elsif C_SUBSTITUTE = eco_ind.ECO_TYPE then
          l_error_desc := 'ERROR conccuren : "XXINV_ECO_NOTIF_SUBSTITUTE_INT/XXINV: Eco Substitute Notification Internal" - not submited ';
        end if;
      
        message(l_error_desc);
      
        retcode := greatest(retcode, l_error_code);
        if retcode = l_error_code then
          errbuf := l_error_desc;
        end if;
      
        update_header_mail_status(p_eco_header_id => eco_ind.ECO_HEADER_ID,
                                  p_mail_status   => C_ERROR,
                                  p_note          => l_error_desc,
                                  p_error_code    => l_error_code,
                                  p_error_desc    => l_error_desc);
      
      end if;
    
    end loop;
  
  exception
    when others then
      errbuf  := 'EXCEPTION_OTHERS XXINV_ECO_NOTIFICATION_PKG.notification_int() - ' ||
                 sqlerrm;
      retcode := '2';
    
      message(errbuf);
    
  end notification_ext;
  ------------------------------------------------------------------------------
  -- Concurrent    : XXINV_ECO_NOTIF_COMPLETION / XXINV: Eco Completion Notification
  --    XMLP Template : XXINV_ECO_NOTIF_REVISION_COM / XXINV: Eco Completion Revision Notification
  --    XMLP Data     : XXINV_ECO_NOTIF_REVISION_COM / XXINV: Eco Completion Revision Notification
  --                           Data Template :  DD_XXINV_ECO_NOTIF_REVISION_COM
  --                           Data Preview  :  PD_XXINV_ECO_NOTIF_REVISION_COM
  --                           Bursting      :  BSF_XXINV_ECO_NOTIF_REVISION_COM
  ------------------------------------------------------------------------------
  -- Ver   When        Who        Description
  -- ----  ----------  ---------  ----------------------------------------------
  -- 1.0   23/09/2020  Roman W.   CHG0048470 - Change notification to customers
  -- 1.1   22/12/2020  Roman W.   CHG0048470 - Added  "and XEL.ECO_LINE_TYPE = C_REVISION"
  ------------------------------------------------------------------------------
  procedure notification_completion(errbuf  OUT VARCHAR2,
                                    retcode OUT VARCHAR2,
                                    p_date  in varchar2 -- dd-mon-rrrr hh24:mi:ss
                                    ) is
    ------------------------------
    --     Local Definition
    ------------------------------
    CURSOR eco_cur(c_date DATE, c_organization_id NUMBER) is
      select XEH.ECO,
             XEL.ECO_HEADER_ID,
             XEL.ECO_LINE_ID,
             MSI.Segment1 ITEM_NUMBER
        from XXINV_ECO_HEADER   XEH,
             XXINV_ECO_LINES    XEL,
             MTL_SYSTEM_ITEMS_B MSI
       where 1 = 1
         and XEH.MAIL_STATUS = C_SUCCESS_EXT
         and XEL.MAIL_STATUS = C_NEW
         and XEL.ECO_LINE_TYPE = C_REVISION
         and XEH.SEND_EXTERNAL = 'Y'
         and XEH.ECO_HEADER_ID = XEL.ECO_HEADER_ID
         and msi.inventory_item_id = XEL.Revised_Item_Id
         and msi.organization_id = c_organization_id
         and trunc(XEL.COMPLETION_DATE) <= c_date
         and exists (select 'Y'
                from xxinv_eco_line_customers xelc
               where xelc.eco_header_id = XEH.ECO_HEADER_ID
                 and xelc.eco_line_id = xelc.eco_line_id
                 and xelc.mail_status != C_ERROR);
  
    CURSOR conc_child_cur(c_request_id NUMBER) is
      select R.REQUEST_ID
        from FND_CONCURRENT_REQUESTS R
       where r.parent_request_id = c_request_id;
  
    l_date            DATE;
    l_request_id      NUMBER;
    l_error_code      VARCHAR2(30);
    l_error_desc      VARCHAR2(2000);
    l_organization_id NUMBER;
    ------------------------------
    --     Code Section
    ------------------------------
  begin
    errbuf  := null;
    retcode := '0';
  
    message('Start :  xxinv_eco_notification_pkg.notification_completion(' ||
            p_date || ');');
  
    l_date := fnd_conc_date.STRING_TO_DATE(nvl(p_date,
                                               to_char(sysdate,
                                                       'DD-MON-RRRR')));
  
    l_organization_id := xxinv_utils_pkg.get_master_organization_id();
  
    ---------------------------------------------
    --        Make Directory
    ---------------------------------------------
    xxssys_dpl_pkg.make_directory(p_dir_path   => get_bursting_pdf_location,
                                  p_directory  => C_XXINV_ECO_NOTIF_DIRECTORY,
                                  p_error_code => l_error_code,
                                  p_error_desc => l_error_desc);
  
    IF '0' != l_error_code THEN
      retcode := greatest(retcode, l_error_code);
      if retcode = l_error_code then
        errbuf := l_error_desc;
      end if;
      return;
    end if;
  
    for eco_ind in eco_cur(l_date, l_organization_id) loop
      message(eco_ind.ECO || ': ECO_HEADER_ID = ' || eco_ind.ECO_HEADER_ID ||
              ', ECO_LINE_ID = ' || eco_ind.ECO_LINE_ID);
    
      ------- Submit concurrent : "Eco Revision Notification External" --------
      l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                                 program     => 'XXINV_ECO_NOTIF_REVISION_COM', -- 'XXINV: Eco Completion Revision Notification'
                                                 description => '',
                                                 start_time  => '',
                                                 sub_request => FALSE,
                                                 argument1   => eco_ind.ECO_HEADER_ID,
                                                 argument2   => eco_ind.ECO_LINE_ID);
      COMMIT;
    
      if l_request_id > 0 then
      
        wait_for_request(p_request_id => l_request_id,
                         p_error_code => l_error_code,
                         p_error_desc => l_error_Desc);
      
        if '0' != l_error_code then
        
          retcode := greatest(retcode, l_error_code);
          if retcode = l_error_code then
            errbuf := l_error_desc;
          end if;
        
          update_line_mail_status(p_eco_line_id => eco_ind.ECO_LINE_ID,
                                  p_mail_status => C_ERROR,
                                  p_note        => l_error_desc,
                                  p_error_code  => l_error_code,
                                  p_error_desc  => l_error_desc);
        
        else
          -----------------------------------------------------------------------------------------
          ------------ Submit Bursting ----------------
          submit_bursting(p_conc_request_id => l_request_id,
                          p_error_code      => l_error_code,
                          p_error_desc      => l_error_desc);
        
          if '0' != l_error_code then
            retcode := greatest(retcode, l_error_code);
            if retcode = l_error_code then
              errbuf := l_error_desc;
            end if;
          
            update_line_mail_status(p_eco_line_id => eco_ind.ECO_LINE_ID,
                                    p_mail_status => C_ERROR,
                                    p_note        => l_error_desc,
                                    p_error_code  => l_error_code,
                                    p_error_desc  => l_error_desc);
          
            continue;
          else
          
            message('Add LINE Attachment');
            add_line_attachment(p_eco_line_id => eco_ind.ECO_LINE_ID,
                                p_file_name   => eco_ind.ECO || '-' ||
                                                 eco_ind.ITEM_NUMBER ||
                                                 '.pdf',
                                p_error_code  => l_error_code,
                                p_error_desc  => l_error_desc);
          
            message('remove file');
            remove_file(p_directory  => C_XXINV_ECO_NOTIF_DIRECTORY,
                        p_file_name  => eco_ind.ECO || '-' ||
                                        eco_ind.ITEM_NUMBER || '.pdf',
                        p_error_code => l_error_code,
                        p_error_desc => l_error_desc);
          
            update_line_mail_status(p_eco_line_id => eco_ind.ECO_LINE_ID,
                                    p_mail_status => C_SUCCESS_COMP,
                                    p_note        => NULL,
                                    p_error_code  => l_error_code,
                                    p_error_desc  => l_error_desc);
          end if;
        end if;
      else
        retcode := '2';
        errbuf  := 'ERROR conccuren : "XXINV_ECO_NOTIF_REVISION_COM/XXINV: Eco Completion Revision Notification" - not submited ';
        message(errbuf);
        continue;
      end if;
    
    end loop;
  
  exception
    when others then
      errbuf  := 'EXCEPTION_OTHERS XXINV_ECO_NOTIFICATION_PKG.notification_completion(' ||
                 p_date || ') - ' || sqlerrm;
      retcode := '2';
      message(errbuf);
  end notification_completion;

end XXINV_ECO_NOTIFICATION_PKG;
/
