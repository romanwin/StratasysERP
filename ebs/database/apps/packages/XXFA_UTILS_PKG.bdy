create or replace package body XXFA_UTILS_PKG is
  -------------------------------------------------------------------------------
  --  name:              XXFA_UTILS_PKG
  --  create by:         Suad ofer
  --  Revision:          1.0
  --  creation date:      25/05/2020 11:26:48
  -------------------------------------------------------------------------------
  --  purpose :           Fix asset module utils 
  -------------------------------------------------------------------------------

  -------------------------------------------------------------------------------
  -- Ver   When        Who         Description
  -- ----  ----------  ----------  ----------------------------------------------
  -- 1.0   27/05/2020  Roman W.    CHG0047953  - Create set to run whatif program for all ledgers in one program
  -------------------------------------------------------------------------------
  procedure message(p_msg in varchar2) is
    l_msg varchar(32676);
  begin
  
    l_msg := to_char(sysdate, 'DD/MM/YYYY HH24:MI:SS  ') || p_msg;
  
    if fnd_global.CONC_REQUEST_ID > 0 then
      fnd_file.put_line(fnd_file.LOG, l_msg);
    else
      dbms_output.put_line(l_msg);
    end if;
  
  end message;

  -------------------------------------------------------------------------------
  -- Ver   When        Who          Description
  -- ----  ----------  -----------  ---------------------------------------------
  -- 1.0   27/05/2020  Roman W.     CHG0047953  - Create set to run whatif 
  --                                       program for all ledgers in one program
  -------------------------------------------------------------------------------
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
    
      message('ERROR STATUS : ' || l_dev_status || CHR(10) || 'MSG : ' ||
              p_error_desc);
    
    END IF;
  
  end wait_for_request;

  -------------------------------------------------------------------------------
  -- Ver   When         Who          Descr 
  -- ----  -----------  -----------  --------------------------------------------
  -- 1.0   25/05/2020   Ofer Suad    CHG0047953  - Create set to run whatif 
  --                                      program for all ledgers in one program
  -------------------------------------------------------------------------------
  Procedure submit_whatif_set(errbuf  IN OUT VARCHAR2,
                              retcode IN OUT VARCHAR2,
                              p_year  number) is
  
    -----------------------------
    --    Local Definition
    -----------------------------                                       
    x_req_id         NUMBER(38);
    l_num_of_periods number;
    l_error_code     varchar2(10);
    l_error_desc     varchar2(2000);
    cursor c_books is
      select g.book_type_code,
             g.set_of_books_id,
             g.attribute1,
             fdp.period_name
        from fa_book_controls g, fa_deprn_periods fdp
       where g.book_class = 'CORPORATE'
         and g.current_fiscal_year = EXTRACT(YEAR from sysdate)
         and g.last_period_counter + 1 = fdp.period_counter
         and fdp.book_type_code = g.book_type_code;
  
    -----------------------------
    --      Code Section
    -----------------------------         
  begin
    errbuf  := null;
    retcode := 0;
    message('Start XXFA_UTILS_PKG.submit_whatif_set(' || p_year || ')');
  
    for i in c_books loop
    
      message(rpad(chr(9), 5) || '-----------------');
      message(rpad(chr(9), 5) || 'book_type_code : ' || i.book_type_code);
      message(rpad(chr(9), 5) || 'set_of_books_id : ' || i.set_of_books_id);
      message(rpad(chr(9), 5) || 'attribute1 : ' || i.attribute1);
      message(rpad(chr(9), 5) || 'period_name : ' || i.period_name);
    
      select 13 - g.period_num + (p_year - EXTRACT(YEAR from sysdate)) * 12
        into l_num_of_periods
        from fa_deprn_periods g
       where g.book_type_code = i.book_type_code
         and g.period_name = i.period_name;
    
      message(rpad(chr(9), 5) || 'l_num_of_periods : ' || l_num_of_periods);
    
      x_req_id := fnd_request.submit_request('OFA',
                                             'FAWDPR',
                                             'What-If Analysis Program',
                                             sysdate,
                                             false,
                                             i.book_type_code, --'OBJ IL CORP',
                                             i.set_of_books_id, --2021,
                                             i.period_name, --'MAY-20',
                                             l_num_of_periods, --12,
                                             null,
                                             null,
                                             null,
                                             null,
                                             null,
                                             null,
                                             101,
                                             null,
                                             null,
                                             null,
                                             null,
                                             null,
                                             null,
                                             'N',
                                             'N',
                                             'NO',
                                             null,
                                             null,
                                             null);
      COMMIT;
      IF x_req_id = 0 THEN
      
        retcode := 2;
        errbuf  := 'ERROR concurrent OFA/FAWDPR Could not run program for book ' ||
                   i.book_type_code;
        message(errbuf);
      
      ELSE
        /* rem by Roman W. 2020/05/27 CHG0047953
        
        IF fnd_concurrent.wait_for_request(request_id => x_req_id,
                                           INTERVAL   => 5,
                                           phase      => rphase,
                                           status     => rstatus,
                                           dev_phase  => dphase,
                                           dev_status => dstatus,
                                           message    => message) THEN        
          
        
        END IF;
        */
        -- Added by Roman W. 2020/05/27 CHG0047953                              
        wait_for_request(p_request_id => x_req_id,
                         p_error_code => l_error_code,
                         p_error_desc => l_error_desc);
      
        if '0' != l_error_code then
          retcode := l_error_code;
          errbuf  := l_error_desc;
        end if;
      
        update fa_book_controls fb
           set fb.attribute1 = x_req_id
         where fb.book_type_code = i.book_type_code;
      
      END IF;
    
    end loop;
  
    COMMIT;
  
  exception
    when others then
      errbuf  := 'EXCEPTION_OTHERS XXFA_UTILS_PKG.submit_whatif_set(' ||
                 p_year || ') - ' || sqlerrm;
      retcode := 0;
    
      message(errbuf);
    
  end submit_whatif_set;

end XXFA_UTILS_PKG;
/
