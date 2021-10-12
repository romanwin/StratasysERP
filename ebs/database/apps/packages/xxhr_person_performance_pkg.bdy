create or replace package body XXHR_PERSON_PERFORMANCE_PKG is
--------------------------------------------------------------------
--  name:            XXHR_PERSON_PERFORMANCE_PKG
--  create by:       Dalit A. Raviv
--  Revision:        1.0
--  creation date:   29/12/2010
--------------------------------------------------------------------
--  purpose :        HR project - Handle upload of employee performance
--------------------------------------------------------------------
--  ver  date          name              desc
--  1.0  29/12/2010    Dalit A. Raviv    initial build
--------------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:            get_value_from_line
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   29/03/2011
  --------------------------------------------------------------------
  --  purpose :        get value from excel line
  --                   return short string each time by the deliminar
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  29/03/2011  Dalit A. Raviv   initial build
  --------------------------------------------------------------------
  function get_value_from_line( p_line_string in out varchar2,
                                p_err_msg     in out varchar2,
                                c_delimiter   in varchar2) return varchar2 is

    l_pos        number;
    l_char_value varchar2(50);

  begin

    l_pos := instr(p_line_string, c_delimiter);

    if nvl(l_pos, 0) < 1 then
       l_pos := length(p_line_string);
    end if;

    l_char_value := ltrim(rtrim(substr(p_line_string, 1, l_pos - 1)));

    p_line_string := substr(p_line_string, l_pos + 1);

    return l_char_value;
  exception
   when others then
     p_err_msg := 'get_value_from_line - '||substr(sqlerrm,1,250);
  end get_value_from_line;

  --------------------------------------------------------------------
  --  name:            main
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   29/12/2010
  --------------------------------------------------------------------
  --  purpose :        Main procedure that run the program
  --
  --  In Params:       p_location - /UtlFiles/HR/PERFORMANCE
  --                   p_filename - File name to run
  --                   p_token    - Security token
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  29/12/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  procedure main( errbuf      out varchar2,
                  retcode     out varchar2,
                  p_location  in  varchar2,  -- /UtlFiles/HR/PERFORMANCE
                  p_filename  in  varchar2,
                  p_token     in  varchar2) is

    l_p_performance_review_id  number  := null;
    l_ovn                      number  := null;
    l_next_review_date_warning boolean;
    --l_next_review_warning      varchar2(100) := null;
    l_err_code                 varchar2(10)  := null;
    l_err_message              varchar2(200) := null;

    l_file_hundler              utl_file.file_type;
    l_line_buffer               varchar2(2000);
    l_counter                   number               := 0;
    l_pos                       number;
    c_delimiter                 constant varchar2(1) := ',';

    l_emp_number                per_all_people_f.employee_number%type;
    l_full_name                 per_all_people_f.full_name%type;
    l_person_id                 per_all_people_f.person_id%type;
    l_rate                      varchar2(50);
    l_date_v                    varchar2(50);
    l_date                      date;
    l_flag                      varchar2(5)  := 'Y';
    l_start_date                date;

    l_err_msg                   varchar2(1500);
    --l_security                  varchar2(5) := 'N';

    invalid_rate                exception;
    general_exception           exception;

  begin
    errbuf  := null;
    retcode := 0;
    -- Dalit A. Raviv 18/07/2011
    --fnd_global.APPS_INITIALIZE(user_id => 2470,resp_id => 21538 ,resp_appl_id => 800);
    xxobjt_sec.upload_user_session_key(p_pass        => p_token, --'D1234567',
                                       p_err_code    => l_err_code ,
                                       p_err_message => l_err_message);

    if l_err_code = 1 then
      raise general_exception;
    end if;

    begin
      l_file_hundler := utl_file.fopen( location     => p_location,
                                        filename     => p_filename,
                                        open_mode    => 'r',
                                        max_linesize => 32000);
    exception
      when utl_file.invalid_path then
        retcode := 1;
        errbuf  := 'Import file was failes. 1 Invalid Path for ' || ltrim(p_filename);
        fnd_file.put_line(fnd_file.log,'Invalid Path for ' || ltrim(p_filename));
        dbms_output.put_line('Invalid Path for ' || ltrim(p_filename));
        raise;
      when utl_file.invalid_mode then
        retcode := 1;
        errbuf  := 'Import file was failes. 2 Invalid Mode for ' || ltrim(p_filename);
        fnd_file.put_line(fnd_file.log,'Invalid Mode for ' || ltrim(p_filename));
        dbms_output.put_line('Invalid Mode for ' || ltrim(p_filename));
        raise;
      when utl_file.invalid_operation then
        retcode := 1;
        errbuf  := 'Invalid operation for ' || ltrim(p_filename) ||substr(SQLERRM,1,500);
        fnd_file.put_line(fnd_file.log,'Invalid operation for ' || ltrim(p_filename) ||SQLERRM);
        dbms_output.put_line('Invalid operation for ' || ltrim(p_filename) ||SQLERRM);
        raise;
      when others then
        retcode := 1;
        errbuf  := 'Other for ' || ltrim(p_filename)||substr(SQLERRM,1,500);
        fnd_file.put_line(fnd_file.log,'Other for ' || ltrim(p_filename));
        dbms_output.put_line('Other for ' || ltrim(p_filename));
        raise;
    end;

    -- start read from file, do needed validation, and upload data to table
    -- Loop For All File's Lines
    loop
      begin
        -- goto next line
        l_counter      := l_counter + 1;
        l_err_msg      := null;
        l_emp_number   := null;
        l_flag         := 'Y';
        l_full_name    := null;
        l_rate         := null;
        l_date         := null;
        l_date_v       := null;
        l_start_date   := null;

        -- Get Line and handle exceptions
        begin
          utl_file.get_line(file   => l_file_hundler,
                            buffer => l_line_buffer);
        exception
          when utl_file.read_error then
            errbuf := 'Read Error for line: ' || l_counter;
            fnd_file.put_line(fnd_file.log,'Read Error for line: ' || l_counter);
            dbms_output.put_line('Read Error for line: ' || l_counter);
            raise invalid_rate;
          when no_data_found then
            exit;
          when others then
            errbuf := 'Read Error for line: ' || l_counter ||', Error: ' || substr(SQLERRM,1,200);
            fnd_file.put_line(fnd_file.log,'Read Error for line: ' || l_counter ||', Error: ' || substr(SQLERRM,1,200));
            dbms_output.put_line('Read Error for line: ' || l_counter ||', Error: ' || substr(SQLERRM,1,200));
            raise invalid_rate;
        end;

        -- Get data from line separate by deliminar
        if l_counter > 1 then
          l_pos := 0;

          -- Employee number    Performance_2009.csv
          l_emp_number := get_value_from_line(l_line_buffer,
                                              l_err_msg,
                                              c_delimiter);

          l_full_name  := get_value_from_line(l_line_buffer,
                                              l_err_msg,
                                              c_delimiter);

          l_rate       := get_value_from_line(l_line_buffer,
                                              l_err_msg,
                                              c_delimiter);

          l_date_v     := get_value_from_line(l_line_buffer,
                                              l_err_msg,
                                              c_delimiter);

          l_date       := to_date(l_date_v,'DD/MM/RRRR HH24:MI:SS') ;

          fnd_file.put_line(fnd_file.log,'----------- ');
          dbms_output.put_line('----------- ');

          if l_rate is null then
            fnd_file.put_line(fnd_file.log,l_counter||' - Employee '|| nvl(l_emp_number,l_full_name)||' Employee Have no rate');
            dbms_output.put_line(l_counter||' - Employee '|| nvl(l_emp_number,l_full_name)||' Employee Have no rate');
          else
            fnd_file.put_line(fnd_file.log,l_counter||' - Employee '|| nvl(l_emp_number,l_full_name)||' Start date - '||to_char(l_start_date,'dd-mon-yyyy'));
            dbms_output.put_line(l_counter||' - Employee '|| nvl(l_emp_number,l_full_name)||' Start date - '||to_char(l_start_date,'dd-mon-yyyy'));
            -- get person details
            begin
              select person_id,   paf.start_date
              into   l_person_id, l_start_date
              from   per_all_people_f paf
              where  l_emp_number     = nvl(paf.employee_number,paf.npw_number)
              and    /*trunc(sysdate)*/ l_date  between paf.effective_start_date and paf.effective_end_date;
            exception
              when others then
                select person_id,   paf.start_date
                into   l_person_id, l_start_date
                from   per_all_people_f paf
                where  l_emp_number     = nvl(paf.employee_number,paf.npw_number)
                and    /*trunc(sysdate)*/ l_date  between paf.effective_start_date and paf.effective_end_date;
                l_person_id := null;
                fnd_file.put_line(fnd_file.log,l_flag||' Employee do not exist at Orclae');
                dbms_output.put_line(l_flag||'Employee do not exist at Orclae');
                l_flag := 'N';
            end;

            -- handle performance rate value
            if l_rate = 1 then
              l_rate := 10;
            elsif l_rate = 2 then
              l_rate := 20;
            elsif l_rate = 3 then
              l_rate := 30;
            elsif l_rate = 4 then
              l_rate := 40;
            elsif l_rate = 5 then
              l_rate := 50;
            else
              l_flag := 'N';
            end if;

            if l_flag = 'Y' then
              begin
                -- Call performance API
                hr_perf_review_api.create_perf_review (p_validate                       => false,
                                                       p_performance_review_id          => l_p_performance_review_id, -- o n
                                                       p_person_id                      => l_person_id,               -- i n
                                                       p_review_date                    => l_date,                    -- i d
                                                       p_performance_rating             => l_rate,                    -- i v
                                                       p_object_version_number          => l_ovn,                     -- o n
                                                       p_next_review_date_warning       => l_next_review_date_warning -- o b
                                                      );

                fnd_file.put_line(fnd_file.log,'SUCCESS');
                dbms_output.put_line('SUCCESS');
                commit;
              exception
                when others then
                  rollback;
                  retcode := 1;
                  errbuf  := 'ERROR - ' ||substr(sqlerrm,1,240);
                  fnd_file.put_line(fnd_file.log,'ERROR - ' ||substr(sqlerrm,1,240));
                  dbms_output.put_line('ERROR - ' ||substr(sqlerrm,1,240));
              end;
            end if; -- l_flag
          end if; -- l_rate is null
        end if; -- l_counter

      exception
        when invalid_rate then
          null;
        when others then
          retcode := 1;
          errbuf  := 'Gen EXC loop Emp - ' ||l_emp_number||' - '||substr(SQLERRM,1,240);
          fnd_file.put_line(fnd_file.log,'Gen EXC loop Emp - '||l_emp_number||' - '||substr(SQLERRM,1,240));
          dbms_output.put_line('Gen EXC loop Emp - '||l_emp_number||' - '||substr(SQLERRM,1,240));
      end;
    end loop;
    utl_file.fclose(l_file_hundler);
    commit;

    -- update concurrent parameters
    update fnd_concurrent_requests t
    set    t.argument_text = null,
           t.argument3     = null,
           t.argument4     = null
    where  t.request_id    = fnd_global.CONC_REQUEST_ID;

    commit;
    -- 1) read from file
    -- 2) use aapi
    -- 3) write success / failed to log table.
  exception
    when general_exception then
      fnd_file.put_line(fnd_file.log,'You are not allowed to run this program - Please contact your sysadmin');
      errbuf  := 'You are not allowed to run this program - Please contact your sysadmin';
      retcode := 2;

      -- update concurrent parameters
      update fnd_concurrent_requests t
      set    t.argument_text = null,
             t.argument3     = null,
             t.argument4     = null
      where  t.request_id    = fnd_global.CONC_REQUEST_ID;

      commit;
    when others then
      fnd_file.put_line(fnd_file.log,'GEN EXC - '||substr(sqlerrm,1,240));
      errbuf  := 'GEN EXC - '||substr(sqlerrm,1,240);
      retcode := 2;

      -- update concurrent parameters
      update fnd_concurrent_requests t
      set    t.argument_text = null,
             t.argument3     = null,
             t.argument4     = null
      where  t.request_id    = fnd_global.CONC_REQUEST_ID;

      commit;
  end main;

  --------------------------------------------------------------------
  --  name:            upload_performance
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   06/03/2011
  --------------------------------------------------------------------
  --  purpose :        API to Upload Performance review
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  06/03/2011  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  /*
  procedure upload_performance (errbuf             out varchar2,
                                retcode            out varchar2,
                                p_location         in  varchar2, --/UtlFiles/HR/PERFORMANCE
                                p_filename         in  varchar2,
                                p_token1           in  varchar2) is

    l_p_performance_review_id  number  := null;
    l_ovn                      number  := null;
    l_next_review_date_warning boolean;
    l_next_review_warning      varchar2(100) := null;
    l_err_code                 varchar2(10)  := null;
    l_err_message              varchar2(200) := null;
  begin
    -- set apps_initialize
    fnd_global.APPS_INITIALIZE(user_id => 2470,resp_id => 21538 ,resp_appl_id => 800);
    -- set security token
    xxobjt_sec.upload_user_session_key    (p_pass        => p_token1,
                                           p_err_code    => l_err_code ,
                                           p_err_message => l_err_message);
    -- Call performance API
    hr_perf_review_api.create_perf_review (p_validate                       => false,
                                           p_performance_review_id          => l_p_performance_review_id, -- o n
                                           p_person_id                      => 861,                       -- i n
                                           p_review_date                    => sysdate,                   -- i d
                                           p_performance_rating             => '40',                      -- i v
                                           p_object_version_number          => l_ovn,                     -- o n
                                           p_next_review_date_warning       => l_next_review_date_warning -- o b
                                          );
    commit;
    dbms_output.put_line('Sucess');

  exception
    when others then
      rollback;
      dbms_output.put_line('Error - '||substr(sqlerrm,1,240));

  end;
  */
end XXHR_PERSON_PERFORMANCE_PKG;
/
