CREATE OR REPLACE PACKAGE BODY xxforecast_pkg IS

  --------------------------------------------------------------------
  --  name:            XXFORECAST_PKG
  --  create by:       Avi Hamoy
  --  Revision:        1.0
  --  creation date:   23-Jun-09 11:06:52 AM
  --------------------------------------------------------------------
  --  purpose :        CUST021 - Handle Forecast Uploads
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  23/06/2009  Avi Hamoy         initial build
  --  1.1  05/07/2012  Dalit A. Raviv    procedure ascii_forecaseinterface
  --                                     correct calculate of v_dateofforecast(Get The Period Start Date)
  --  1.2  10.7.12     yuval tal         CR444 : add get_first_day_work + modify forcast date according to bucket
  --  1.3  27/5/14     yuval tal         CHG0032149 :Update Forecast upload program to work with weeks+month simultaneity
  --                                     add function get_no_of_weeks4month
  --                                     add function is_exception_date
  --  1.4  09.07.14    yuval tal         CHG0032711 modify ascii_forecaseinterface
  --  1.5  03/02/15    Gubendran K       CHG0034269: Modified the change in ascii_forecaseinterface_resin procedure (Parameters Validations If condition from p_month_count > 12 to 24) for
  --                                     extending the limitations from 12 to 24
  --  1.6  29/12/2019  Roman W.          CHG0047066 - Forecast loading tool - need ability to load decimal numbers.
  --------------------------------------------------------------------
  /*
  --------------------------------------------------------------------------
  -- Ver   When        Who           Description
  -- ----  ----------  ------------  ---------------------------------------
  -- 1.0   11/01/2019  Roman W.      CHG0046921 
  --------------------------------------------------------------------------
  procedure message(p_msg in varchar2) is
    l_msg varchar(4000);
  
  begin
  
    l_msg := to_char(sysdate, 'DD/MM/YYYY HH24:MI:SS') || p_msg;
  
    if fnd_global.CONC_REQUEST_ID > 0 then
      fnd_file.put_line(fnd_file.LOG, l_msg);
    else
      dbms_output.put_line(l_msg);
    end if;
  
  end message;
  */
  FUNCTION get_first_day_work(p_date DATE, p_organization_id NUMBER)
    RETURN DATE IS
    l_date             DATE;
    l_calendar_code    VARCHAR2(10);
    l_exception_set_id NUMBER;
  
    CURSOR getcalendarinfo IS
      SELECT calendar_code, calendar_exception_set_id
        FROM mtl_parameters
       WHERE organization_id = p_organization_id;
  
  BEGIN
    FOR c1 IN getcalendarinfo LOOP
      l_calendar_code    := c1.calendar_code;
      l_exception_set_id := c1.calendar_exception_set_id;
    END LOOP;
  
    SELECT MIN(calendar_date)
      INTO l_date
      FROM bom_calendar_dates
     WHERE calendar_code = l_calendar_code
       AND exception_set_id = l_exception_set_id
       AND calendar_date >= p_date
       AND seq_num IS NOT NULL;
  
    RETURN l_date;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;

  --------------------------------------
  -- get_no_of_weeks4month
  --------------------------------------------------------------------
  --  ver  date        name              desc
  ------------------------------------------------------------------------
  --  1.0  27/5/14     yuval tal         chg32149 :count no of Mondays in month

  --------------------------------------
  FUNCTION get_no_of_weeks4month(p_date DATE, p_organization_id NUMBER)
    RETURN NUMBER IS
    l_weeks_no      NUMBER;
    l_calendar_code VARCHAR2(10);
    --  l_exception_set_id NUMBER;
  
    CURSOR getcalendarinfo IS
      SELECT calendar_code, calendar_exception_set_id
        FROM mtl_parameters
       WHERE organization_id = p_organization_id;
  
  BEGIN
    FOR c1 IN getcalendarinfo LOOP
      l_calendar_code := c1.calendar_code;
      -- l_exception_set_id := c1.calendar_exception_set_id;
    END LOOP;
  
    SELECT COUNT(*)
      INTO l_weeks_no
      FROM mtl_parameters mp, bom_calendar_weeks_view bcw
     WHERE mp.calendar_code = bcw.calendar_code
       AND mp.organization_id = p_organization_id
       AND bcw.calendar_code = l_calendar_code
       AND YEAR = to_char(p_date, 'YYYY')
       AND month_num = to_char(p_date, 'MM')
       AND mon IS NOT NULL;
    RETURN l_weeks_no;
    --EXCEPTION
    --  WHEN OTHERS THEN
    --    RETURN NULL;
  END;

  --------------------------------------------------------------------
  --  name:            get_designator_period
  --  create by:       Avi Hamoy
  --  Revision:        1.0
  --  creation date:   23-Jun-09 11:06:52 AM
  --------------------------------------------------------------------
  --  purpose :
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  23/06/2009  Avi Hamoy         initial build
  --------------------------------------------------------------------
  FUNCTION get_designator_period(pf_calendarname IN VARCHAR2,
                                 pf_date         IN DATE) RETURN VARCHAR2 IS
  
    v_period VARCHAR2(10);
  
  BEGIN
  
    SELECT to_char(to_date(t.period_name, 'MON'), 'MM') || ') ' ||
           t.period_name
      INTO v_period
      FROM bom.bom_period_start_dates t, bom.bom_calendars bc
     WHERE bc.calendar_code = t.calendar_code
       AND t.calendar_code = pf_calendarname
       AND pf_date >= t.period_start_date
       AND pf_date < t.next_date;
  
    RETURN(v_period);
  
  EXCEPTION
    WHEN no_data_found THEN
      RETURN(NULL);
  END get_designator_period;

  --------------------------------------------------------------------
  --  name:            is_exception_date
  --  create by:       yuval tal
  --  Revision:        1.0
  --  creation date:   23-Jun-09 11:06:52 AM
  --------------------------------------------------------------------
  --  purpose :
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc

  --  1.0  27/5/14     yuval tal         chg32149 :Update Forecast upload program to work with weeks+month simultaneity
  --                                     add parameters p_no_of_months_split2weeks NUMBER DEFAULT 0,
  --                                      p_min_qty
  --------------------------------------------------------------------
  FUNCTION is_exception_date(p_calendar_code VARCHAR2, p_date DATE)
    RETURN VARCHAR2 IS
    l_tmp VARCHAR2(1);
  BEGIN
  
    -- dbms_output.put_line('bb v_dateofforecast=' || v_dateofforecast);
    SELECT 'Y'
      INTO l_tmp
      FROM bom_calendar_exceptions t
     WHERE t.calendar_code = p_calendar_code
       AND t.exception_date = p_date;
  
    RETURN l_tmp;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'N';
  END;

  --------------------------------------------------------------------
  --  name:            ascii_forecaseinterface
  --  create by:       Avi Hamoy
  --  Revision:        1.0
  --  creation date:   23-Jun-09 11:06:52 AM
  --------------------------------------------------------------------
  --  purpose :
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  23/06/2009  Avi Hamoy         initial build
  --  1.1  05/07/2012  Dalit A. Raviv    correct calculate of v_dateofforecast(Get The Period Start Date)
  --  1.2  27/5/14     yuval tal         chg32149 :Update Forecast upload program to work with weeks+month simultaneity
  --                                     add parameters p_no_of_months_split2weeks NUMBER DEFAULT 0,
  --                                      p_min_qty
  --  1.3  09.07.14     yuval tal         CHG0032711 extend 12 month to 24
  --  1.4  29/12/2019   Roman W.          CHG0047066 - Forecast loading tool - need ability to load decimal numbers.
  --------------------------------------------------------------------
  PROCEDURE ascii_forecaseinterface(errbuf            OUT VARCHAR2,
                                    retcode           OUT VARCHAR2,
                                    p_location        IN VARCHAR2, -- /UtlFiles/Forecast
                                    p_filename        IN VARCHAR2,
                                    p_organization_id IN NUMBER, -- MFG_ORGANIZATION_ID
                                    p_month_count     IN NUMBER, -- default 12
                                    --  p_divide_type          IN VARCHAR2, -- Month
                                    p_fore_month           IN VARCHAR2,
                                    p_split2weeks_up2month NUMBER DEFAULT -1,
                                    p_min_qty              VARCHAR2) IS
    -- Select to_char(sysdate, 'YYYYMM') From dual
  
    plist_file        utl_file.file_type;
    v_user_id         fnd_user.user_id%TYPE;
    v_login_id        fnd_logins.login_id%TYPE;
    v_read_code       NUMBER(5) := 1;
    v_line_buf        VARCHAR2(2000);
    v_tmp_line        VARCHAR2(2000);
    v_delimiter       CHAR(1) := ',';
    v_place           NUMBER(3);
    v_counter         NUMBER := 0;
    v_divide_by       NUMBER(2);
    v_remain_fore     NUMBER;
    v_foremonth       DATE;
    v_month_count     NUMBER(2);
    v_read_designator mrp_forecast_designators.forecast_designator%TYPE;
    v_read_itemcode   mtl_system_items_b.segment1%TYPE;
    v_designator      mrp_forecast_designators.forecast_designator%TYPE;
    v_item_id         mtl_system_items_b.inventory_item_id%TYPE;
    v_trx             mrp_forecast_dates.transaction_id%TYPE;
    v_currentfore_qty mrp_forecast_dates.current_forecast_quantity%TYPE;
    v_qty             mrp_forecast_dates.current_forecast_quantity%TYPE;
    v_organ_calendar  bom_calendars.calendar_code%TYPE;
    v_bucket_type     mrp_forecast_designators.bucket_type%TYPE;
    v_dateofforecast  mrp_forecast_dates.forecast_date%TYPE;
    v_weekfirstwd     NUMBER(1);
    -- l_organization_id NUMBER;
    l_calendar_code VARCHAR2(50);
    TYPE v_forerecord IS RECORD(
      forecastqty NUMBER);
    TYPE v_foretable IS TABLE OF v_forerecord INDEX BY BINARY_INTEGER;
  
    v_forecastarray v_foretable;
  
    CURSOR get_trx(pc_designator IN VARCHAR2,
                   pc_itemid     NUMBER,
                   pc_foredate   DATE) IS
      SELECT mfd.transaction_id, mfd.current_forecast_quantity
        FROM mrp_forecast_dates mfd
       WHERE mfd.forecast_designator = pc_designator
         AND mfd.inventory_item_id = pc_itemid
         AND mfd.forecast_date BETWEEN pc_foredate AND pc_foredate + 5 --mfd.forecast_date between p_date 08-feb-01
         AND mfd.organization_id = p_organization_id
       ORDER BY mfd.forecast_date;
  
    -- 1.1 05/07/2012 Dalit A. Raviv
    l_flag VARCHAR2(5);
  BEGIN
    retcode    := 0;
    v_user_id  := fnd_global.user_id;
    v_login_id := fnd_global.login_id;
  
    BEGIN
      DELETE mrp_forecast_interface WHERE process_status = 5;
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;
  
    -- Get Organization Calendar + Week's 1st Working Day (Sunday or Monday)
    SELECT mp.calendar_code,
           to_number(to_char(bc.calendar_start_date, 'D'))
      INTO v_organ_calendar, v_weekfirstwd
      FROM mtl_parameters mp, bom_calendars bc
     WHERE bc.calendar_code = mp.calendar_code
       AND mp.organization_id = p_organization_id;
  
    -- Parameters Validations
    IF p_month_count > 24 OR p_month_count < 4 THEN
      --CHG0032711
      errbuf  := 'Number Of Forecast Months Must Be Between 4 And 24'; --CHG0032711
      retcode := '2';
    ELSE
      v_month_count := p_month_count;
    END IF;
  
    BEGIN
      SELECT to_date(p_fore_month, 'YYYYMM') INTO v_foremonth FROM dual;
    EXCEPTION
      WHEN OTHERS THEN
        retcode := '2';
    END;
  
    /* IF p_divide_type = 'Week' THEN
      v_divide_by := 4;
    ELSE
      v_divide_by := 1;
    END IF;*/
  
    BEGIN
      plist_file := utl_file.fopen(location  => p_location,
                                   filename  => p_filename,
                                   open_mode => 'r');
      fnd_file.put_line(fnd_file.log,
                        'File ' || ltrim(rtrim(p_location)) || '/' ||
                        ltrim(rtrim(p_filename)) || ' Opened');
    EXCEPTION
      WHEN utl_file.invalid_path THEN
        errbuf  := 'Invalid Path for ' || ltrim(rtrim(p_location)) || '/' ||
                   ltrim(rtrim(p_filename)) || chr(0);
        retcode := '2';
      WHEN utl_file.invalid_mode THEN
        errbuf  := 'Invalid Mode for ' || ltrim(rtrim(p_location)) || '/' ||
                   ltrim(rtrim(p_filename)) || chr(0);
        retcode := '2';
      WHEN utl_file.invalid_operation THEN
        errbuf  := 'Invalid operation for ' || ltrim(rtrim(p_location)) || '/' ||
                   ltrim(rtrim(p_filename)) || chr(0);
        retcode := '2';
      WHEN OTHERS THEN
        errbuf  := 'Other for ' || ltrim(rtrim(p_location)) || '/' ||
                   ltrim(rtrim(p_filename)) || chr(0);
        retcode := '2';
    END;
  
    -- Loop The File For Reading
    WHILE v_read_code <> 0 AND nvl(retcode, '0') = '0' LOOP
      BEGIN
        utl_file.get_line(file => plist_file, buffer => v_line_buf);
      EXCEPTION
        WHEN utl_file.read_error THEN
          errbuf  := 'Read Error' || chr(0);
          retcode := '2';
        WHEN no_data_found THEN
          fnd_file.put_line(fnd_file.log, 'Read Complete');
          v_read_code := 0;
        WHEN OTHERS THEN
          errbuf  := 'Other for Line Read' || chr(0);
          retcode := '2';
      END;
    
      -- Check The EOF
      IF v_read_code <> 0 THEN
        v_counter := v_counter + 1;
        v_place   := instr(v_line_buf, v_delimiter);
      
        -- Check The Delimiter
        IF nvl(v_place, 0) = 0 OR (v_place > 100) THEN
        
          errbuf  := 'No Delimiter In The File, Line' || to_char(v_counter) ||
                     chr(0);
          retcode := '2';
        ELSE
          v_read_designator := ltrim(rtrim(substr(v_line_buf,
                                                  1,
                                                  v_place - 1)));
          v_tmp_line        := ltrim(substr(v_line_buf,
                                            v_place + 1,
                                            length(v_line_buf)));
        
          v_place         := instr(v_tmp_line, v_delimiter);
          v_read_itemcode := ltrim(rtrim(substr(v_tmp_line, 1, v_place - 1)));
          v_tmp_line      := ltrim(substr(v_tmp_line,
                                          v_place + 1,
                                          length(v_tmp_line)));
        
          FOR cnt IN 1 .. v_month_count LOOP
          
            IF cnt != v_month_count THEN
              v_place := instr(v_tmp_line, v_delimiter);
            ELSE
              v_place := length(v_tmp_line);
            END IF;
          
            --                fnd_file.put_line(fnd_file.log, 'v_Read_itemCode:'||v_Read_itemCode||', cnt:'||cnt||', v_place:'||v_place||
            --                                                ', v_tmp_line:'||v_tmp_line);
            v_forecastarray(cnt).forecastqty := ltrim(rtrim(substr(v_tmp_line,
                                                                   1,
                                                                   v_place - 1)));
          
            v_forecastarray(cnt).forecastqty := round(v_forecastarray(cnt)
                                                      .forecastqty,
                                                      2); -- Added By Roman W CHG0047066                                                                 
          
            v_tmp_line := ltrim(substr(v_tmp_line,
                                       v_place + 1,
                                       length(v_tmp_line)));
          
          END LOOP;
        
          --
        
          SELECT calendar_code
            INTO l_calendar_code
            FROM mtl_parameters
           WHERE organization_id = p_organization_id;
        
          -- Get The Correct Forecast Designator From Attribute14
          BEGIN
            SELECT fdes.forecast_designator, fdes.bucket_type
            
              INTO v_designator, v_bucket_type
              FROM mrp_forecast_designators fdes
             WHERE fdes.forecast_designator = v_read_designator
               AND fdes.organization_id = p_organization_id;
          
          EXCEPTION
            WHEN no_data_found THEN
              retcode      := 1;
              v_designator := '@@@';
              fnd_file.put_line(fnd_file.log,
                                'Line ' || v_counter ||
                                ': No Such Designator');
            WHEN too_many_rows THEN
              retcode      := 1;
              v_designator := '@@@';
              fnd_file.put_line(fnd_file.log,
                                'Line ' || v_counter ||
                                ': Too Many Designators With The Same Value');
          END;
        
          -- Get The Item ID
          BEGIN
            SELECT msi.inventory_item_id
              INTO v_item_id
              FROM mtl_system_items msi
             WHERE msi.segment1 = v_read_itemcode
               AND msi.organization_id = p_organization_id;
          
          EXCEPTION
            WHEN no_data_found THEN
              v_item_id := NULL;
              fnd_file.put_line(fnd_file.log,
                                'Line ' || v_counter ||
                                ': No Such Item Code');
            WHEN OTHERS THEN
              v_item_id := NULL;
              fnd_file.put_line(fnd_file.log,
                                'Line ' || v_counter ||
                                ': Item Query General Error');
          END;
        
          -- Loop 4 Times For Monthly And 12 Times For Yearly
          IF v_designator != '@@@' AND v_item_id IS NOT NULL THEN
          
            FOR cnt IN 1 .. v_month_count LOOP
              -- 1.1 Dalit A. Raviv 05/07/2012
            
              -- chg 32149
              IF cnt <= nvl(p_split2weeks_up2month, -1) THEN
                v_divide_by := get_no_of_weeks4month(trunc(add_months(v_foremonth,
                                                                      cnt - 1),
                                                           'MM'),
                                                     p_organization_id);
              ELSE
                v_divide_by := 1;
              END IF;
              --
            
              l_flag := 'Y';
              -- Enter Data To Interface Table. Planning Manager Will Take It
              v_remain_fore := v_forecastarray(cnt).forecastqty;
            
              FOR divd IN 0 .. v_divide_by - 1 LOOP
                EXIT WHEN v_remain_fore = 0;
                IF divd = v_divide_by - 1 THEN
                  v_qty         := v_remain_fore;
                  v_remain_fore := 0;
                ELSIF v_forecastarray(cnt).forecastqty <= p_min_qty THEN
                  v_qty         := v_remain_fore;
                  v_remain_fore := 0;
                
                ELSE
                
                  -- v_qty := least(round(v_forecastarray(cnt).forecastqty / v_divide_by, 0), v_remain_fore); Rem By Roman CHG0047066 29/01/2019                             
                  v_qty := least(round(v_forecastarray(cnt)
                                       .forecastqty / v_divide_by,
                                       2),
                                 v_remain_fore); --Added By Roman CHG0047066 29/01/2019
                
                  v_remain_fore := v_remain_fore - v_qty;
                
                END IF;
              
                -- cr 444 - change logic of dateforecast accoridimd to bucket
                -- bucket 1 = first day work from 1.mm.yyy
                -- else same logic
              
                --  IF v_bucket_type != 1 THEN
              
                -- get first date work
                /*   v_dateofforecast := get_first_day_work(trunc(add_months(v_foremonth,
                                                                          cnt - 1),
                                                               'MM'),
                                                         p_organization_id) +
                                      divd * 7;
                  IF v_dateofforecast IS NULL THEN
                
                    fnd_file.put_line(fnd_file.log,
                                      'Line ' || v_counter ||
                                      ': Can not find Period start work date ');
                    l_flag := 'N';
                  END IF;
                
                ELSE*/
                --CHG0032149
              
                v_dateofforecast := next_day((add_months(v_foremonth,
                                                         cnt - 1) - 1),
                                             'MONDAY') + divd * 7;
              
                /* dbms_output.put_line('bb l_calendar_code=' ||
                l_calendar_code ||
                ' v_dateofforecast=' ||
                v_dateofforecast);*/
              
                IF v_dateofforecast IS NULL THEN
                
                  fnd_file.put_line(fnd_file.log,
                                    'Line ' || v_counter ||
                                    ': Can not find Period start work date ');
                  l_flag := 'N';
                ELSIF is_exception_date(l_calendar_code, v_dateofforecast) = 'Y' THEN
                  -- check exception date
                
                  dbms_output.put_line('bb v_dateofforecast=' ||
                                       v_dateofforecast);
                  v_dateofforecast := get_first_day_work(v_dateofforecast + 1,
                                                         p_organization_id);
                  dbms_output.put_line('v_dateofforecast=' ||
                                       v_dateofforecast);
                END IF;
                -- END IF; -- bucker logic cr 444
              
                -- Check If Exists Value In The Date To Overwrite
                BEGIN
                  v_trx := NULL;
                  OPEN get_trx(v_designator, v_item_id, v_dateofforecast);
                  FETCH get_trx
                    INTO v_trx, v_currentfore_qty;
                  CLOSE get_trx;
                  IF v_currentfore_qty = 0 THEN
                    v_currentfore_qty := 0.1;
                  END IF;
                EXCEPTION
                  WHEN OTHERS THEN
                    v_trx := NULL;
                END;
              
                IF NOT (v_currentfore_qty = 0 AND v_qty = 0) THEN
                  IF l_flag = 'Y' THEN
                  
                    INSERT INTO mrp_forecast_interface
                      (inventory_item_id,
                       forecast_designator,
                       organization_id,
                       forecast_date,
                       last_update_date,
                       last_updated_by,
                       creation_date,
                       created_by,
                       last_update_login,
                       quantity,
                       process_status,
                       confidence_percentage,
                       --     workday_control,
                       bucket_type,
                       transaction_id)
                    VALUES
                      (v_item_id,
                       v_designator,
                       p_organization_id,
                       v_dateofforecast,
                       SYSDATE,
                       v_user_id,
                       SYSDATE,
                       v_user_id,
                       v_login_id,
                       v_qty,
                       2, --waiting to be processed
                       100,
                       --  2, --Shift forward
                       1, -- v_bucket_type,
                       v_trx);
                  END IF; -- l_flag
                END IF; -- qty
              END LOOP;
            END LOOP;
          END IF; -- v_designator != '@@@' and v_item_id is not null
        END IF; -- v_place
      END IF; -- v_read_code
    END LOOP;
    COMMIT;
  END ascii_forecaseinterface;

  --------------------------------------------------------------------
  --  name:            reduce_fieldservice_usage
  --  create by:       Avi Hamoy
  --  Revision:        1.0
  --  creation date:   23-Jun-09 11:06:52 AM
  --------------------------------------------------------------------
  --  purpose :
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  23/06/2009  Avi Hamoy         initial build
  --------------------------------------------------------------------
  PROCEDURE reduce_fieldservice_usage(errbuf                OUT VARCHAR2,
                                      retcode               OUT VARCHAR2,
                                      p_organization_id     IN NUMBER,
                                      p_forecast_designator IN VARCHAR2,
                                      p_item_id             IN NUMBER) IS
  
    CURSOR cr_main IS
      SELECT mfd.inventory_item_id,
             mfd.forecast_date,
             (SELECT MIN(nxt.forecast_date)
                FROM mrp_forecast_dates nxt
               WHERE nxt.forecast_designator = mfd.forecast_designator
                 AND nxt.organization_id = mfd.organization_id
                 AND nxt.inventory_item_id = mfd.inventory_item_id
                 AND nxt.forecast_date > mfd.forecast_date + 1) end_period,
             mfd.original_forecast_quantity,
             mfd.current_forecast_quantity,
             mfd.transaction_id,
             mfd.bucket_type,
             nvl(mfd.attribute1, 0) AS already_consumed,
             ROWID
        FROM mrp_forecast_dates mfd
       WHERE mfd.forecast_designator = p_forecast_designator
         AND mfd.organization_id = p_organization_id
         AND (mfd.inventory_item_id = p_item_id OR p_item_id IS NULL)
       ORDER BY mfd.inventory_item_id, mfd.forecast_date;
  
    v_trxtypeid      mtl_transaction_types.transaction_type_id%TYPE;
    v_organ_calendar mtl_parameters.calendar_code%TYPE;
    v_trx_qty        mtl_material_transactions.transaction_quantity%TYPE;
    v_left_qty       mtl_material_transactions.transaction_quantity%TYPE;
    v_endperiod      bom_period_start_dates.period_start_date%TYPE;
    v_itemcode       mtl_system_items_b.segment1%TYPE;
    v_disabledate    mrp_forecast_designators.disable_date%TYPE;
    v_user_id        fnd_user.user_id%TYPE;
    v_login_id       fnd_logins.login_id%TYPE;
    -- API Variables
    --t_forecast_interface_tab  mrp_forecast_interface_pk.t_forecast_interface;
    --t_forecast_designator_tab mrp_forecast_interface_pk.t_forecast_designator;
    --var_bool                  BOOLEAN;
    --v_api_counter             NUMBER := 0;
  
  BEGIN
    fnd_profile.get('USER_ID', v_user_id);
    fnd_profile.get('LOGIN_ID', v_login_id);
  
    -- Get 'Field Service Usage' Trx Type ID
    SELECT tt.transaction_type_id
      INTO v_trxtypeid
      FROM mtl_transaction_types tt
     WHERE tt.transaction_type_name = 'Field Service Usage';
  
    -- Get Organization Calendar For Last Forecast Date Ranges
    SELECT mp.calendar_code
      INTO v_organ_calendar
      FROM mtl_parameters mp
     WHERE mp.organization_id = p_organization_id;
  
    -- Check If Forecast Designator Is Enabled
    BEGIN
      SELECT fd.disable_date
        INTO v_disabledate
        FROM mrp_forecast_designators fd
       WHERE fd.organization_id = p_organization_id
         AND fd.forecast_designator = p_forecast_designator;
    
      IF v_disabledate IS NOT NULL THEN
        errbuf  := 'Forecast Designator Is Disabled';
        retcode := '2';
      END IF;
    
    EXCEPTION
      WHEN no_data_found THEN
        errbuf  := 'No Such Forecast Designator';
        retcode := '2';
    END;
  
    -- Main Cursor Of Forecast Date
    FOR fdate IN cr_main LOOP
      IF fdate.end_period IS NULL THEN
      
        SELECT MIN(period_start_date)
          INTO v_endperiod
          FROM bom_period_start_dates
         WHERE calendar_code = v_organ_calendar
           AND period_start_date > fdate.forecast_date + 1;
      
      ELSE
        v_endperiod := fdate.end_period;
      END IF;
    
      -- Get The Transaction Sum
      BEGIN
      
        SELECT nvl(abs(SUM(mtt.transaction_quantity)), 0)
          INTO v_trx_qty
          FROM mtl_material_transactions mtt
         WHERE mtt.organization_id = p_organization_id
           AND mtt.transaction_type_id = v_trxtypeid
           AND mtt.transaction_date BETWEEN fdate.forecast_date AND
               v_endperiod
           AND mtt.inventory_item_id = fdate.inventory_item_id;
      
      EXCEPTION
        WHEN OTHERS THEN
          v_trx_qty := 0;
      END;
    
      v_left_qty := v_trx_qty - fdate.already_consumed;
    
      -- Only For Left Quantities, Update The Forecast
      IF v_left_qty > 0 THEN
      
        -- Get Item Code For The Log
        SELECT segment1
          INTO v_itemcode
          FROM mtl_system_items_b msi
         WHERE msi.organization_id = p_organization_id
           AND msi.inventory_item_id = fdate.inventory_item_id;
      
        -- Only If Forecast Qty Is Higher Than Reduced
        v_left_qty := least(fdate.original_forecast_quantity, v_left_qty);
      
        IF v_left_qty = fdate.original_forecast_quantity THEN
        
          INSERT INTO xxobjt_mrp_forecast_del
            (inventory_item_id,
             forecast_designator,
             organization_id,
             forecast_date,
             last_update_date,
             last_updated_by,
             creation_date,
             created_by,
             last_update_login,
             quantity,
             process_status,
             confidence_percentage,
             workday_control,
             bucket_type,
             transaction_id,
             attribute1,
             program_request_id)
          VALUES
            (fdate.inventory_item_id,
             p_forecast_designator,
             p_organization_id,
             fdate.forecast_date,
             SYSDATE,
             v_user_id,
             SYSDATE,
             v_user_id,
             v_login_id,
             fdate.original_forecast_quantity - v_left_qty,
             2, --waiting to be processed
             100,
             2, --Shift forward
             fdate.bucket_type,
             fdate.transaction_id,
             fdate.already_consumed + v_left_qty,
             fnd_global.conc_request_id);
        
        END IF;
      
        IF v_left_qty > 0 THEN
        
          INSERT INTO mrp_forecast_interface
            (inventory_item_id,
             forecast_designator,
             organization_id,
             forecast_date,
             last_update_date,
             last_updated_by,
             creation_date,
             created_by,
             last_update_login,
             quantity,
             process_status,
             confidence_percentage,
             workday_control,
             bucket_type,
             transaction_id,
             attribute1)
          VALUES
            (fdate.inventory_item_id,
             p_forecast_designator,
             p_organization_id,
             fdate.forecast_date,
             SYSDATE,
             v_user_id,
             SYSDATE,
             v_user_id,
             v_login_id,
             fdate.original_forecast_quantity - v_left_qty,
             2, --waiting to be processed
             100,
             2, --Shift forward
             fdate.bucket_type,
             fdate.transaction_id,
             fdate.already_consumed + v_left_qty);
          /*
                       v_API_Counter := v_API_Counter + 1;
                       t_forecast_interface_tab(v_API_Counter).inventory_item_id := FDate.Inventory_Item_Id;
                       t_forecast_interface_tab(v_API_Counter).forecast_designator := P_Forecast_Designator;
                       t_forecast_interface_tab(v_API_Counter).organization_id := P_Organization_ID;
                       t_forecast_interface_tab(v_API_Counter).forecast_date := FDate.Forecast_Date;
                       t_forecast_interface_tab(v_API_Counter).bucket_type := FDate.bucket_type;
                       t_forecast_interface_tab(v_API_Counter).quantity := FDate.Original_Forecast_Quantity - v_left_qty;
                       t_forecast_interface_tab(v_API_Counter).process_status := 2;
                       t_forecast_interface_tab(v_API_Counter).confidence_percentage := 100;
                       t_forecast_interface_tab(v_API_Counter).workday_control := 2;
                       t_forecast_interface_tab(v_API_Counter).transaction_id := FDate.Transaction_Id;
          
                       t_forecast_designator_tab(v_API_Counter).organization_id := P_Organization_ID;
                       t_forecast_designator_tab(v_API_Counter).forecast_designator := P_Forecast_Designator;
          */
          fnd_file.put_line(fnd_file.log,
                            'Reducing Quantity For Item ' || v_itemcode ||
                            ' , Bucket ' ||
                            to_char(fdate.forecast_date, 'DD-MON-RR') ||
                            ' By ' || v_left_qty || '. Original Was ' ||
                            fdate.original_forecast_quantity);
        
        ELSE
        
          fnd_file.put_line(fnd_file.log,
                            'Original Forcast Quantity For Item ' ||
                            v_itemcode || ' , Bucket ' ||
                            to_char(fdate.forecast_date, 'DD-MON-RR') ||
                            ' Is ' || fdate.original_forecast_quantity ||
                            ' . Cannot Reduce ' || v_left_qty);
          retcode := '1';
        END IF;
      END IF;
    END LOOP;
    -- Process The API, After Filling The Temp Table
    /*
    var_bool := MRP_FORECAST_INTERFACE_PK.MRP_FORECAST_INTERFACE (t_forecast_interface_tab, t_forecast_designator_tab);
    For i in 1..v_API_Counter loop
        dbms_output.put_line('Return Status = '||t_forecast_interface_tab(i).process_status);
        dbms_output.put_line('Error Message = '||t_forecast_interface_tab(i).error_message);
    End loop;
    */
  END reduce_fieldservice_usage;

  --------------------------------------------------------------------
  --  name:            ascii_forecaseinterface
  --  create by:       Avi Hamoy
  --  Revision:        1.0
  --  creation date:   23-Jun-09 11:06:52 AM
  --------------------------------------------------------------------
  --  purpose :
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  23/06/2009  Avi Hamoy         initial build
  --  1.1  05/07/2012  Dalit A. Raviv    correct calculate of v_dateofforecast(Get The Period Start Date)
  --  1.2  03/02/2015  Gubendran K       CHG0034269: Modified Parameters Validations If condition from p_month_count > 12 to 24
  --  1.3  29/12/2019  Roman W.          CHG0047066 - Forecast loading tool - need ability to load decimal numbers.
  --  1.4  05/12/2019  Roman W.          CHG0047066 - bug fix
  --  1.5  08/01/2019  Roman W.          CHG0047066 - bug fix added round(, 2);
  --------------------------------------------------------------------
  PROCEDURE ascii_forecaseinterface_resin(errbuf            OUT VARCHAR2,
                                          retcode           OUT VARCHAR2,
                                          p_location        IN VARCHAR2, -- /UtlFiles/Forecast
                                          p_filename        IN VARCHAR2,
                                          p_organization_id IN NUMBER, -- MFG_ORGANIZATION_ID
                                          p_month_count     IN NUMBER, -- default 12 --CHG0034269:Changed the default value from 12 to 24
                                          p_divide_type     IN VARCHAR2, -- Month
                                          p_fore_month      IN VARCHAR2) IS
    -- Select to_char(sysdate, 'YYYYMM') From dual
  
    plist_file        utl_file.file_type;
    v_user_id         fnd_user.user_id%TYPE;
    v_login_id        fnd_logins.login_id%TYPE;
    v_read_code       NUMBER(5) := 1;
    v_line_buf        VARCHAR2(2000);
    v_tmp_line        VARCHAR2(2000);
    v_delimiter       CHAR(1) := ',';
    v_place           NUMBER(3);
    v_counter         NUMBER := 0;
    v_divide_by       NUMBER(2);
    v_remain_fore     NUMBER;
    v_foremonth       DATE;
    v_month_count     NUMBER(2);
    v_read_designator mrp_forecast_designators.forecast_designator%TYPE;
    v_read_itemcode   mtl_system_items_b.segment1%TYPE;
    v_designator      mrp_forecast_designators.forecast_designator%TYPE;
    v_item_id         mtl_system_items_b.inventory_item_id%TYPE;
    v_trx             mrp_forecast_dates.transaction_id%TYPE;
    v_currentfore_qty mrp_forecast_dates.current_forecast_quantity%TYPE;
    v_qty             mrp_forecast_dates.current_forecast_quantity%TYPE;
    v_organ_calendar  bom_calendars.calendar_code%TYPE;
    v_bucket_type     mrp_forecast_designators.bucket_type%TYPE;
    v_dateofforecast  mrp_forecast_dates.forecast_date%TYPE;
    v_weekfirstwd     NUMBER(1);
    l_organization_id NUMBER;
  
    TYPE v_forerecord IS RECORD(
      forecastqty NUMBER);
    TYPE v_foretable IS TABLE OF v_forerecord INDEX BY BINARY_INTEGER;
  
    v_forecastarray v_foretable;
  
    CURSOR get_trx(pc_designator IN VARCHAR2,
                   pc_itemid     NUMBER,
                   pc_foredate   DATE) IS
      SELECT mfd.transaction_id, mfd.current_forecast_quantity
        FROM mrp_forecast_dates mfd
       WHERE mfd.forecast_designator = pc_designator
         AND mfd.inventory_item_id = pc_itemid
         AND mfd.forecast_date BETWEEN pc_foredate AND pc_foredate + 5 --mfd.forecast_date between p_date 08-feb-01
         AND mfd.organization_id = p_organization_id
       ORDER BY mfd.forecast_date;
  
    -- 1.1 05/07/2012 Dalit A. Raviv
    l_flag VARCHAR2(5);
  BEGIN
  
    errbuf  := null;
    retcode := '0';
  
    v_user_id  := fnd_global.user_id;
    v_login_id := fnd_global.login_id;
  
    BEGIN
      DELETE mrp_forecast_interface WHERE process_status = 5;
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;
  
    -- Get Organization Calendar + Week's 1st Working Day (Sunday or Monday)
    SELECT mp.calendar_code,
           to_number(to_char(bc.calendar_start_date, 'D'))
      INTO v_organ_calendar, v_weekfirstwd
      FROM mtl_parameters mp, bom_calendars bc
     WHERE bc.calendar_code = mp.calendar_code
       AND mp.organization_id = p_organization_id;
  
    -- Parameters Validations
    IF p_month_count > 24 OR p_month_count < 4 THEN
      --CHG0034269: Modified the condition value from 12 to 24
      errbuf  := 'Number Of Forecast Months Must Be Between 4 And 24';
      retcode := '2';
    ELSE
      v_month_count := p_month_count;
    END IF;
  
    BEGIN
      SELECT to_date(p_fore_month, 'YYYYMM') INTO v_foremonth FROM dual;
    EXCEPTION
      WHEN OTHERS THEN
        retcode := '2';
    END;
  
    IF p_divide_type = 'Week' THEN
      v_divide_by := 4;
    ELSE
      v_divide_by := 1;
    END IF;
  
    BEGIN
      plist_file := utl_file.fopen(location  => p_location,
                                   filename  => p_filename,
                                   open_mode => 'r');
      fnd_file.put_line(fnd_file.log,
                        'File ' || ltrim(rtrim(p_location)) || '/' ||
                        ltrim(rtrim(p_filename)) || ' Opened');
    EXCEPTION
      WHEN utl_file.invalid_path THEN
        errbuf  := 'Invalid Path for ' || ltrim(rtrim(p_location)) || '/' ||
                   ltrim(rtrim(p_filename)) || chr(0);
        retcode := '2';
      WHEN utl_file.invalid_mode THEN
        errbuf  := 'Invalid Mode for ' || ltrim(rtrim(p_location)) || '/' ||
                   ltrim(rtrim(p_filename)) || chr(0);
        retcode := '2';
      WHEN utl_file.invalid_operation THEN
        errbuf  := 'Invalid operation for ' || ltrim(rtrim(p_location)) || '/' ||
                   ltrim(rtrim(p_filename)) || chr(0);
        retcode := '2';
      WHEN OTHERS THEN
        errbuf  := 'Other for ' || ltrim(rtrim(p_location)) || '/' ||
                   ltrim(rtrim(p_filename)) || chr(0);
        retcode := '2';
    END;
  
    -- Loop The File For Reading
    WHILE v_read_code <> 0 AND nvl(retcode, '0') = '0' LOOP
      BEGIN
        utl_file.get_line(file => plist_file, buffer => v_line_buf);
      EXCEPTION
        WHEN utl_file.read_error THEN
          errbuf  := 'Read Error' || chr(0);
          retcode := '2';
        WHEN no_data_found THEN
          fnd_file.put_line(fnd_file.log, 'Read Complete');
          v_read_code := 0;
        WHEN OTHERS THEN
          errbuf  := 'Other for Line Read' || chr(0);
          retcode := '2';
      END;
    
      -- Check The EOF
      IF v_read_code <> 0 THEN
        v_counter := v_counter + 1;
        v_place   := instr(v_line_buf, v_delimiter);
      
        -- Check The Delimiter
        IF nvl(v_place, 0) = 0 OR (v_place > 100) THEN
        
          errbuf  := 'No Delimiter In The File, Line' || to_char(v_counter) ||
                     chr(0);
          retcode := '2';
        ELSE
          v_read_designator := ltrim(rtrim(substr(v_line_buf,
                                                  1,
                                                  v_place - 1)));
          v_tmp_line        := ltrim(substr(v_line_buf,
                                            v_place + 1,
                                            length(v_line_buf)));
        
          v_place         := instr(v_tmp_line, v_delimiter);
          v_read_itemcode := ltrim(rtrim(substr(v_tmp_line, 1, v_place - 1)));
          v_tmp_line      := ltrim(substr(v_tmp_line,
                                          v_place + 1,
                                          length(v_tmp_line)));
        
          FOR cnt IN 1 .. v_month_count LOOP
          
            IF cnt != v_month_count THEN
              v_place := instr(v_tmp_line, v_delimiter);
            ELSE
              v_place := length(v_tmp_line);
            END IF;
          
            --                fnd_file.put_line(fnd_file.log, 'v_Read_itemCode:'||v_Read_itemCode||', cnt:'||cnt||', v_place:'||v_place||
            --                                                ', v_tmp_line:'||v_tmp_line);
            v_forecastarray(cnt).forecastqty := round(ltrim(rtrim(substr(v_tmp_line,
                                                                         1,
                                                                         v_place - 1))),
                                                      2);
            v_tmp_line := ltrim(substr(v_tmp_line,
                                       v_place + 1,
                                       length(v_tmp_line)));
          
          END LOOP;
        
          -- Get The Correct Forecast Designator From Attribute14
          BEGIN
            SELECT fdes.forecast_designator, fdes.bucket_type
            
              INTO v_designator, v_bucket_type
              FROM mrp_forecast_designators fdes
             WHERE fdes.forecast_designator = v_read_designator
               AND fdes.organization_id = p_organization_id;
          
          EXCEPTION
            WHEN no_data_found THEN
              v_designator := '@@@';
              fnd_file.put_line(fnd_file.log,
                                'Line ' || v_counter ||
                                ': No Such Designator');
            WHEN too_many_rows THEN
              v_designator := '@@@';
              fnd_file.put_line(fnd_file.log,
                                'Line ' || v_counter ||
                                ': Too Many Designators With The Same Value');
          END;
        
          -- Get The Item ID
          BEGIN
            SELECT msi.inventory_item_id
              INTO v_item_id
              FROM mtl_system_items msi
             WHERE msi.segment1 = v_read_itemcode
               AND msi.organization_id = p_organization_id;
          
          EXCEPTION
            WHEN no_data_found THEN
              v_item_id := NULL;
              fnd_file.put_line(fnd_file.log,
                                'Line ' || v_counter ||
                                ': No Such Item Code');
            WHEN OTHERS THEN
              v_item_id := NULL;
              fnd_file.put_line(fnd_file.log,
                                'Line ' || v_counter ||
                                ': Item Query General Error');
          END;
        
          -- Loop 4 Times For Monthly And 12 Times For Yearly
          IF v_designator != '@@@' AND v_item_id IS NOT NULL THEN
          
            FOR cnt IN 1 .. v_month_count LOOP
              -- 1.1 Dalit A. Raviv 05/07/2012
              l_flag := 'Y';
              -- Enter Data To Interface Table. Planning Manager Will Take It
              v_remain_fore := v_forecastarray(cnt).forecastqty;
            
              FOR divd IN 1 .. v_divide_by LOOP
                IF divd = v_divide_by THEN
                  v_qty         := v_remain_fore;
                  v_remain_fore := 0;
                ELSE
                  -- v_qty := round(v_forecastarray(cnt).forecastqty / v_divide_by,  0); Rem by Roman W. CHG0047066 29/12/2019
                
                  v_qty := round(v_forecastarray(cnt)
                                 .forecastqty / v_divide_by,
                                 2); -- CHG0047066
                
                  IF v_remain_fore = 0 THEN
                    v_qty := 0;
                  ELSE
                    v_remain_fore := v_remain_fore - v_qty;
                  END IF;
                END IF;
              
                -- cr 444 - change logic of dateforecast accoridimd to bucket
                -- bucket 1 = first day work from 1.mm.yyy
                -- else same logic
              
                IF v_bucket_type = 1 THEN
                
                  -- get first date work
                  v_dateofforecast := get_first_day_work(trunc(add_months(v_foremonth,
                                                                          cnt - 1),
                                                               'MM'),
                                                         p_organization_id);
                  IF v_dateofforecast IS NULL THEN
                  
                    fnd_file.put_line(fnd_file.log,
                                      'Line ' || v_counter ||
                                      ': Can not find Period start work date - period name - ' ||
                                      to_char(add_months(v_foremonth,
                                                         cnt - 1),
                                              'MON') || ' Date to check - ' ||
                                      to_char(add_months(v_foremonth,
                                                         cnt - 1) + 10,
                                              'yyyy-mon-dd'));
                    l_flag := 'N';
                  END IF;
                
                ELSE
                
                  -- Get The Period Start Date
                  -- dbms_output.put_line(a => 'cnt:'||cnt||', v_foreMonth:'||v_foreMonth||', v_Organ_Calendar:'||v_Organ_Calendar);
                  -- 1.1 05/07/2012 Dalit A. Raviv
                  -- correct calculate of v_dateofforecast(Get The Period Start Date)
                  BEGIN
                    SELECT period_start_date
                      INTO v_dateofforecast
                      FROM bom_period_start_dates
                     WHERE calendar_code = v_organ_calendar
                       AND period_name =
                           to_char(add_months(v_foremonth, cnt - 1), 'MON')
                          -- and to_char(period_start_date, 'YYYY') = to_char(add_months(v_foremonth, cnt - 1), 'YYYY');
                          -- v_foremonth get it's value from the parameter p_foremonth, for example if the param
                          -- get 201207 when convert the value to date it become 01/07/2012 (allways return the first day of the month)
                          -- the period_start_date change and can be 5 days before or after period start.
                          -- when i add 10 days i'm sure the date will be between start and next.
                       AND add_months(v_foremonth, cnt - 1) + 10 BETWEEN
                           period_start_date AND next_date;
                    -- end 1.1
                  EXCEPTION
                    WHEN OTHERS THEN
                      v_dateofforecast := NULL;
                      fnd_file.put_line(fnd_file.log,
                                        'Line ' || v_counter ||
                                        ': Can not find Period start date - period name - ' ||
                                        to_char(add_months(v_foremonth,
                                                           cnt - 1),
                                                'MON') ||
                                        ' Date to check - ' ||
                                        to_char(add_months(v_foremonth,
                                                           cnt - 1) + 10,
                                                'yyyy-mon-dd'));
                      l_flag := 'N';
                    
                  END;
                
                END IF; -- bucker logic cr 444
              
                -- Check If Exists Value In The Date To Overwrite
                BEGIN
                  v_trx := NULL;
                  OPEN get_trx(v_designator, v_item_id, v_dateofforecast);
                  FETCH get_trx
                    INTO v_trx, v_currentfore_qty;
                  CLOSE get_trx;
                  IF v_currentfore_qty = 0 THEN
                    v_currentfore_qty := 0.1;
                  END IF;
                EXCEPTION
                  WHEN OTHERS THEN
                    v_trx := NULL;
                END;
              
                fnd_file.put_line(fnd_file.log,
                                  'Line1 ' || p_organization_id || '-' ||
                                  v_designator || '-' || v_dateofforecast || '-' ||
                                  v_qty || '-' || v_bucket_type || '-' ||
                                  v_trx || ': Org Id');
                IF NOT (v_currentfore_qty = 0 AND v_qty = 0) THEN
                  fnd_file.put_line(fnd_file.log,
                                    'Line2 ' || p_organization_id || '-' ||
                                    v_designator || '-' || v_dateofforecast || '-' ||
                                    v_qty || '-' || v_bucket_type || '-' ||
                                    v_trx || ': Org Id');
                  IF l_flag = 'Y' THEN
                    fnd_file.put_line(fnd_file.log,
                                      'Line3 ' || p_organization_id || '-' ||
                                      v_designator || '-' ||
                                      v_dateofforecast || '-' || v_qty || '-' ||
                                      v_bucket_type || '-' || v_trx ||
                                      ': Org Id');
                  
                    INSERT INTO mrp_forecast_interface
                      (inventory_item_id,
                       forecast_designator,
                       organization_id,
                       forecast_date,
                       last_update_date,
                       last_updated_by,
                       creation_date,
                       created_by,
                       last_update_login,
                       quantity,
                       process_status,
                       confidence_percentage,
                       workday_control,
                       bucket_type,
                       transaction_id)
                    VALUES
                      (v_item_id,
                       v_designator,
                       p_organization_id,
                       v_dateofforecast,
                       SYSDATE,
                       v_user_id,
                       SYSDATE,
                       v_user_id,
                       v_login_id,
                       v_qty,
                       2, --waiting to be processed
                       100,
                       2, --Shift forward
                       v_bucket_type,
                       v_trx);
                    fnd_file.put_line(fnd_file.log,
                                      'Line4 ' || p_organization_id || '-' ||
                                      v_designator || '-' ||
                                      v_dateofforecast || '-' || v_qty || '-' ||
                                      v_bucket_type || '-' || v_trx ||
                                      ': Org Id');
                  END IF; -- l_flag
                  fnd_file.put_line(fnd_file.log,
                                    'Line5 ' || p_organization_id || '-' ||
                                    v_designator || '-' || v_dateofforecast || '-' ||
                                    v_qty || '-' || v_bucket_type || '-' ||
                                    v_trx || ': Org Id');
                END IF; -- qty
                fnd_file.put_line(fnd_file.log,
                                  'Line6 ' || p_organization_id || '-' ||
                                  v_designator || '-' || v_dateofforecast || '-' ||
                                  v_qty || '-' || v_bucket_type || '-' ||
                                  v_trx || ': Org Id');
              END LOOP;
            END LOOP;
            fnd_file.put_line(fnd_file.log,
                              'Line7 ' || p_organization_id || '-' ||
                              v_designator || '-' || v_dateofforecast || '-' ||
                              v_qty || '-' || v_bucket_type || '-' || v_trx ||
                              ': Org Id');
          END IF; -- v_designator != '@@@' and v_item_id is not null
        END IF; -- v_place
      END IF; -- v_read_code
    END LOOP;
    fnd_file.put_line(fnd_file.log,
                      'Line8 ' || p_organization_id || '-' || v_designator || '-' ||
                      v_dateofforecast || '-' || v_qty || '-' ||
                      v_bucket_type || '-' || v_trx || ': Org Id');
  
  END ascii_forecaseinterface_resin;

END xxforecast_pkg;
/
