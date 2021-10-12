CREATE OR REPLACE PACKAGE BODY xxoe_so_bucket_discnt_int_pkg IS
  --------------------------------------------------------------------
  --  name:            XXOE_SO_BUCKET_DISCNT_INT_PKG
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   14/12/2014
  --------------------------------------------------------------------
  --  purpose :        CHG0034003-Resin bucket - Apply automatic discount in SO
  --                   Upload data from csv file to setup form 
  --                   (tables XXOE_DISCOUNT_BUCKET_HEADERS, XXOE_DISCOUNT_BUCKET_LINES)
  --------------------------------------------------------------------
  --  ver    date          name             desc
  --  1.0    14.12.2014    Michal Tzvik     Initial Build
  --------------------------------------------------------------------
  g_err_msg VARCHAR2(2000);

  CURSOR c_headers IS
    SELECT DISTINCT bucket_type,
                    parent_customer_location,
                    customer_number,
                    period_name,
                    bucket_amount_usd,
                    MAX(ROWID) over(PARTITION BY bucket_type, parent_customer_location, customer_number, period_name, bucket_amount_usd) row_id,
                    -- converted data
                    NULL xx_bucket_header_id,
                    NULL xx_bucket_type_code,
                    NULL xx_customer_id
    FROM   xxoe_discount_bucket_interface xdbi
    WHERE  1 = 1
    AND    xdbi.request_id = fnd_global.conc_request_id
    AND    xdbi.status = 'NEW';

  CURSOR c_lines(p_bucket_type              VARCHAR2,
                 p_parent_customer_location VARCHAR2,
                 p_customer_number          VARCHAR2,
                 p_period_name              VARCHAR2) IS
    SELECT xdbi.order_type,
           xdbi.limit_type,
           xdbi.from_limit,
           xdbi.to_limit,
           REPLACE(REPLACE(xdbi.calc_method, chr(13), NULL), chr(10), NULL) calc_method,
           xdbi.creation_date,
           xdbi.created_by,
           xdbi.last_update_date,
           xdbi.last_updated_by,
           xdbi.last_update_login,
           REPLACE(REPLACE(xdbi.status, chr(13), NULL), chr(10), NULL) status,
           ROWID row_id,
           -- converted data
           NULL xx_order_type_id,
           NULL xx_calc_method_code,
           NULL xx_bucket_header_id,
           NULL xx_limit_type_code
    FROM   xxoe_discount_bucket_interface xdbi
    WHERE  1 = 1
    AND    xdbi.request_id = fnd_global.conc_request_id
    AND    xdbi.status = 'NEW'
    AND    xdbi.bucket_type = p_bucket_type
    AND    xdbi.parent_customer_location = p_parent_customer_location
    AND    nvl(xdbi.customer_number, -1) = nvl(p_customer_number, -1)
    AND    xdbi.period_name = p_period_name;

  --------------------------------------------------------------------
  --  name:            report_data
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   18/12/2014
  --------------------------------------------------------------------
  --  purpose :        Create output file
  --------------------------------------------------------------------
  --  ver    date        name             desc
  --  1.0    18/12/2014  Michal Tzvik     Initial Build - CHG0034003
  --------------------------------------------------------------------
  PROCEDURE report_data IS
    CURSOR c_data IS
      SELECT xdbi.request_id,
             xdbi.bucket_type,
             xdbi.parent_customer_location,
             xdbi.customer_number,
             xdbi.period_name,
             xdbi.bucket_amount_usd,
             xdbi.order_type,
             xdbi.limit_type,
             xdbi.from_limit,
             xdbi.to_limit,
             REPLACE(REPLACE(xdbi.calc_method, chr(13), NULL), chr(10), NULL) calc_method,
             REPLACE(REPLACE(xdbi.status, chr(13), NULL), chr(10), NULL) status,
             xdbi.err_msg
      FROM   xxoe_discount_bucket_interface xdbi
      WHERE  1 = 1
      AND    xdbi.request_id = fnd_global.conc_request_id;
  BEGIN
    fnd_file.put_line(fnd_file.log, 'Create output...');
  
    fnd_file.put_line(fnd_file.output, 'request id' || ' | ' ||
                       'bucket type' || ' | ' ||
                       'parent customer location' || ' | ' ||
                       'customer number' || ' | ' ||
                       'period name' || ' | ' ||
                       'bucket amount usd' || ' | ' ||
                       'order type' || ' | ' ||
                       'limit type' || ' | ' ||
                       'from limit' || ' | ' || 'to limit' ||
                       ' | ' || 'calc method' || ' | ' ||
                       'status  ' || ' | ' || 'err msg');
  
    fnd_file.put_line(fnd_file.output, '');
  
    FOR r_data IN c_data LOOP
      fnd_file.put_line(fnd_file.output, lpad(nvl(to_char(r_data.request_id), ' '), 10, ' ') ||
                         ' | ' ||
                         lpad(nvl(r_data.bucket_type, ' '), 11, ' ') ||
                         ' | ' ||
                         lpad(nvl(r_data.parent_customer_location, ' '), 24, ' ') ||
                         ' | ' ||
                         lpad(nvl(to_char(r_data.customer_number), ' '), 15, ' ') ||
                         ' | ' ||
                         lpad(nvl(r_data.period_name, ' '), 11, ' ') ||
                         ' | ' ||
                         lpad(nvl(to_char(r_data.bucket_amount_usd), ' '), 17, ' ') ||
                         ' | ' ||
                         lpad(nvl(r_data.order_type, ' '), 10, ' ') ||
                         ' | ' ||
                         lpad(nvl(r_data.limit_type, ' '), 10, ' ') ||
                         ' | ' ||
                         lpad(nvl(to_char(r_data.from_limit), ' '), 10, ' ') ||
                         ' | ' ||
                         lpad(nvl(to_char(r_data.to_limit), ' '), 8, ' ') ||
                         ' | ' ||
                         lpad(nvl(r_data.calc_method, ' '), 11, ' ') ||
                         ' | ' ||
                         lpad(nvl(r_data.status, ' '), 9, ' ') ||
                         ' | ' || r_data.err_msg);
    END LOOP;
  END report_data;
  --------------------------------------------------------------------
  --  name:            update_interface_status
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   14/12/2014
  --------------------------------------------------------------------
  --  purpose :        Update field status in interface table - xxoe_discount_bucket_interface
  --------------------------------------------------------------------
  --  ver    date        name             desc
  --  1.0    14/12/2014  Michal Tzvik     Initial Build - CHG0034003
  --------------------------------------------------------------------
  PROCEDURE update_interface_status(p_row_id  VARCHAR2,
                                    p_status  VARCHAR2,
                                    p_err_msg VARCHAR2) IS
  BEGIN
    IF p_status = 'ERROR' THEN
      fnd_file.put_line(fnd_file.log, p_err_msg);
    END IF;
  
    UPDATE xxoe_discount_bucket_interface xdbi
    SET    xdbi.status  = p_status,
           xdbi.err_msg = decode(xdbi.rowid, p_row_id, p_err_msg, xdbi.err_msg)
    WHERE  xdbi.request_id = fnd_global.conc_request_id
    AND    (xdbi.bucket_type, xdbi.parent_customer_location,
           xdbi.customer_number, xdbi.period_name) IN
           (SELECT xdbi1.bucket_type,
                    xdbi1.parent_customer_location,
                    xdbi1.customer_number,
                    xdbi1.period_name
             FROM   xxoe_discount_bucket_interface xdbi1
             WHERE  xdbi1.rowid = p_row_id);
  
  END update_interface_status;

  --------------------------------------------------------------------
  --  name:            create_bucket_line
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   14/12/2014
  --------------------------------------------------------------------
  --  purpose :        Insert new record to table xxoe_discount_bucket_lines
  --------------------------------------------------------------------
  --  ver    date        name             desc
  --  1.0    14/12/2014  Michal Tzvik     Initial Build - CHG0034003
  --------------------------------------------------------------------
  PROCEDURE create_bucket_line(p_line_rec IN c_lines%ROWTYPE,
                               x_err_code OUT VARCHAR2,
                               x_err_msg  OUT VARCHAR2) IS
    l_bucket_line_id NUMBER;
  BEGIN
  
    x_err_code := '0';
    x_err_msg  := '';
  
    SELECT xxoe_discount_bucket_lines_s.nextval
    INTO   l_bucket_line_id
    FROM   dual;
  
    dbms_output.put_line('Create bucket line. l_bucket_line_id=' ||
                         l_bucket_line_id || ', bucket_header_id=' ||
                         p_line_rec.xx_bucket_header_id ||
                         ', xx_order_type_id=' ||
                         p_line_rec.xx_order_type_id ||
                         ', xx_limit_type_code=' ||
                         p_line_rec.xx_limit_type_code ||
                         ', xx_calc_method_code=' ||
                         p_line_rec.xx_calc_method_code);
    INSERT INTO xxoe_discount_bucket_lines xdbl
      (bucket_header_id,
       bucket_line_id,
       order_type_id,
       limit_type,
       from_limit,
       to_limit,
       calc_method_code,
       creation_date,
       created_by,
       last_update_date,
       last_updated_by,
       last_update_login,
       enable_flag)
    VALUES
      (p_line_rec.xx_bucket_header_id,
       l_bucket_line_id,
       p_line_rec.xx_order_type_id,
       p_line_rec.xx_limit_type_code,
       p_line_rec.from_limit,
       p_line_rec.to_limit,
       p_line_rec.xx_calc_method_code,
       SYSDATE,
       fnd_global.user_id,
       SYSDATE,
       fnd_global.user_id,
       fnd_global.conc_login_id,
       'Y');
  
  EXCEPTION
    WHEN OTHERS THEN
      x_err_code := '1';
      x_err_msg  := 'Error in create_bucket_line: ' || SQLERRM;
  END create_bucket_line;

  --------------------------------------------------------------------
  --  name:            create_bucket_header
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   14/12/2014
  --------------------------------------------------------------------
  --  purpose :        Insert new record to table xxoe_discount_bucket_headers
  --------------------------------------------------------------------
  --  ver    date        name             desc
  --  1.0    14/12/2014  Michal Tzvik     Initial Build - CHG0034003
  --------------------------------------------------------------------
  PROCEDURE create_bucket_header(p_header_rec       IN c_headers%ROWTYPE,
                                 x_bucket_header_id OUT NUMBER,
                                 x_err_code         OUT VARCHAR2,
                                 x_err_msg          OUT VARCHAR2) IS
    l_period_year NUMBER;
    l_quarter_num NUMBER;
  
  BEGIN
  
    x_err_code := '0';
    x_err_msg  := '';
  
    SELECT xxoe_discount_bucket_headers_s.nextval
    INTO   x_bucket_header_id
    FROM   dual;
  
    fnd_file.put_line(fnd_file.log, 'Create new bucket header for bucket_type_code = ' ||
                       p_header_rec.bucket_type ||
                       ', parent_customer_location = ' ||
                       p_header_rec.parent_customer_location ||
                       ', customer = ' ||
                       p_header_rec.customer_number ||
                       ', period = ' ||
                       p_header_rec.period_name);
  
    l_period_year := substr(p_header_rec.period_name, 4);
    l_quarter_num := substr(p_header_rec.period_name, 2, 1);
  
    INSERT INTO xxoe_discount_bucket_headers xdbh
      (bucket_header_id,
       bucket_type_code,
       parent_customer_location,
       period_year,
       quarter_num,
       bucket_amount_usd,
       creation_date,
       created_by,
       last_update_date,
       last_updated_by,
       last_update_login,
       period_name,
       total_bucket_usage_amount,
       customer_id,
       enable_flag)
    VALUES
      (x_bucket_header_id,
       p_header_rec.xx_bucket_type_code,
       p_header_rec.parent_customer_location,
       l_period_year,
       l_quarter_num,
       p_header_rec.bucket_amount_usd,
       SYSDATE,
       fnd_global.user_id,
       SYSDATE,
       fnd_global.user_id,
       fnd_global.conc_login_id,
       p_header_rec.period_name,
       NULL,
       p_header_rec.xx_customer_id,
       'Y');
  
  EXCEPTION
    WHEN OTHERS THEN
      x_err_code := '1';
      x_err_msg  := 'Error in create_bucket_header: ' || SQLERRM;
  END create_bucket_header;

  --------------------------------------------------------------------
  --  name:            get_calc_method_code
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   14/12/2014
  --------------------------------------------------------------------
  --  purpose :        Get calc_method_code of given calc method name
  --------------------------------------------------------------------
  --  ver    date        name             desc
  --  1.0    14/12/2014  Michal Tzvik     Initial Build - CHG0034003
  --------------------------------------------------------------------
  FUNCTION get_calc_method_code(p_calc_method VARCHAR2,
                                x_err_code    OUT VARCHAR2,
                                x_err_msg     OUT VARCHAR2) RETURN VARCHAR2 IS
    l_calc_method_code VARCHAR2(30);
  BEGIN
    x_err_code := '0';
    x_err_msg  := '';
  
    SELECT flv.lookup_code
    INTO   l_calc_method_code
    FROM   fnd_lookup_values flv
    WHERE  1 = 1
    AND    flv.lookup_type = 'XXOE_BUCKET_LIMIT_CALC_METHOD'
    AND    flv.language = 'US'
    AND    SYSDATE BETWEEN nvl(flv.start_date_active, SYSDATE - 1) AND
           nvl(flv.end_date_active, SYSDATE + 1)
    AND    flv.enabled_flag = 'Y'
    AND    flv.meaning = p_calc_method;
  
    RETURN l_calc_method_code;
  
  EXCEPTION
    WHEN OTHERS THEN
      x_err_code := '1';
      x_err_msg  := 'Error in get_calc_method_code (' || p_calc_method ||
                    '): ' || SQLERRM;
      RETURN NULL;
  END get_calc_method_code;

  --------------------------------------------------------------------
  --  name:            get_order_type_id
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   14/12/2014
  --------------------------------------------------------------------
  --  purpose :        Get order_type_id of given order type name
  --------------------------------------------------------------------
  --  ver    date        name             desc
  --  1.0    14/12/2014  Michal Tzvik     Initial Build - CHG0034003
  --------------------------------------------------------------------
  FUNCTION get_order_type_id(p_order_type VARCHAR2,
                             x_err_code   OUT VARCHAR2,
                             x_err_msg    OUT VARCHAR2) RETURN NUMBER IS
    l_order_type_id NUMBER;
  BEGIN
    x_err_code := '0';
    x_err_msg  := '';
  
    SELECT ottt.transaction_type_id
    INTO   l_order_type_id
    FROM   oe_transaction_types_tl  ottt,
           oe_transaction_types_all otta
    WHERE  SYSDATE BETWEEN nvl(otta.start_date_active, SYSDATE - 1) AND
           nvl(otta.end_date_active, SYSDATE + 1)
    AND    otta.transaction_type_code = 'ORDER'
    AND    ottt.transaction_type_id = otta.transaction_type_id
    AND    ottt.language = userenv('LANG')
    AND    ottt.name = p_order_type;
  
    RETURN l_order_type_id;
  
  EXCEPTION
    WHEN OTHERS THEN
      x_err_code := '1';
      x_err_msg  := 'Error in get_order_type_id: ' || SQLERRM;
      RETURN NULL;
  END get_order_type_id;

  --------------------------------------------------------------------
  --  name:            get_limit_type_code
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   14/12/2014
  --------------------------------------------------------------------
  --  purpose :        Get limit type code of given limit type name
  --------------------------------------------------------------------
  --  ver    date        name             desc
  --  1.0    14/12/2014  Michal Tzvik     Initial Build - CHG0034003
  --------------------------------------------------------------------
  FUNCTION get_limit_type_code(p_limit_type VARCHAR2,
                               x_err_code   OUT VARCHAR2,
                               x_err_msg    OUT VARCHAR2) RETURN VARCHAR2 IS
    l_limit_type_code VARCHAR2(30);
  BEGIN
    x_err_code := '0';
    x_err_msg  := '';
  
    SELECT flv.lookup_code
    INTO   l_limit_type_code
    FROM   fnd_lookup_values flv
    WHERE  1 = 1
    AND    flv.lookup_type = 'XXOE_BUCKET_LIMIT_TYPE'
    AND    flv.language = 'US'
    AND    SYSDATE BETWEEN nvl(flv.start_date_active, SYSDATE - 1) AND
           nvl(flv.end_date_active, SYSDATE + 1)
    AND    flv.enabled_flag = 'Y'
    AND    flv.meaning = p_limit_type;
  
    RETURN l_limit_type_code;
  
  EXCEPTION
    WHEN OTHERS THEN
      x_err_code := '1';
      x_err_msg  := 'Error in get_limit_type_code: ' || SQLERRM;
      RETURN NULL;
  END get_limit_type_code;

  --------------------------------------------------------------------
  --  name:            get_bucket_header_id
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   14/12/2014
  --------------------------------------------------------------------
  --  purpose :        Check if bucket from csv file already exists.
  --                   if yes, fail the upload (only new buckets are allowed)
  --                   Else create new bucket and return its bucket_header_id
  --------------------------------------------------------------------
  --  ver    date        name             desc
  --  1.0    14/12/2014  Michal Tzvik     Initial Build - CHG0034003
  --------------------------------------------------------------------
  FUNCTION get_bucket_header_id(p_header_rec c_headers%ROWTYPE,
                                x_err_code   OUT VARCHAR2,
                                x_err_msg    OUT VARCHAR2) RETURN NUMBER IS
    l_bucket_header_id NUMBER;
  BEGIN
    x_err_code := '0';
    x_err_msg  := '';
  
    SELECT xdbh.bucket_header_id
    INTO   l_bucket_header_id
    FROM   xxoe_discount_bucket_headers xdbh
    WHERE  1 = 1
    AND    xdbh.bucket_type_code = p_header_rec.xx_bucket_type_code
    AND    xdbh.parent_customer_location =
           p_header_rec.parent_customer_location
    AND    nvl(xdbh.customer_id, -1) = nvl(p_header_rec.xx_customer_id, -1)
    AND    xdbh.period_name = p_header_rec.period_name;
  
    x_err_code := '1';
    x_err_msg  := 'Bucket already exists. bucket_header_id = ' ||
                  l_bucket_header_id;
    RETURN NULL;
  
  EXCEPTION
    WHEN no_data_found THEN
      create_bucket_header(p_header_rec, l_bucket_header_id, x_err_code, x_err_msg);
      RETURN l_bucket_header_id;
    
    WHEN OTHERS THEN
      x_err_code := '1';
      x_err_msg  := 'Error in get_bucket_header_id: ' || SQLERRM;
      RETURN NULL;
  END get_bucket_header_id;

  --------------------------------------------------------------------
  --  name:            get_customer_id
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   14/12/2014
  --------------------------------------------------------------------
  --  purpose :        Return customer id of given customer number.
  --                   
  --------------------------------------------------------------------
  --  ver    date        name             desc
  --  1.0    14/12/2014  Michal Tzvik     Initial Build - CHG0034003
  --------------------------------------------------------------------
  FUNCTION get_customer_id(p_customer_number IN VARCHAR2,
                           x_err_code        OUT VARCHAR2,
                           x_err_msg         OUT VARCHAR2) RETURN NUMBER IS
    l_customer_id NUMBER;
  BEGIN
    x_err_code := '0';
    x_err_msg  := '';
  
    SELECT hca.cust_account_id
    INTO   l_customer_id
    FROM   hz_cust_accounts hca
    WHERE  1 = 1
    AND    hca.status = 'A'
    AND    hca.account_number = p_customer_number;
  
    RETURN l_customer_id;
  
  EXCEPTION
    WHEN OTHERS THEN
      x_err_code := '1';
      x_err_msg  := 'Error in get_customer_id: ' || SQLERRM;
      RETURN NULL;
  END get_customer_id;

  --------------------------------------------------------------------
  --  name:            get_bucket_type_code
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   14/12/2014
  --------------------------------------------------------------------
  --  purpose :        Return bucket type code of given bucket type name.
  --                   
  --------------------------------------------------------------------
  --  ver    date        name             desc
  --  1.0    14/12/2014  Michal Tzvik     Initial Build - CHG0034003
  --------------------------------------------------------------------
  FUNCTION get_bucket_type_code(p_bucket_type_name IN VARCHAR2,
                                x_err_code         OUT VARCHAR2,
                                x_err_msg          OUT VARCHAR2)
    RETURN VARCHAR2 IS
    l_bucket_type_code VARCHAR2(30);
  BEGIN
    x_err_code := '0';
    x_err_msg  := '';
  
    SELECT flv.lookup_code bucket_type_code
    INTO   l_bucket_type_code
    FROM   fnd_lookup_values flv
    WHERE  1 = 1
    AND    flv.lookup_type = 'XXOE_BUCKET_TYPE'
    AND    flv.language = 'US'
    AND    SYSDATE BETWEEN nvl(flv.start_date_active, SYSDATE - 1) AND
           nvl(flv.end_date_active, SYSDATE + 1)
    AND    flv.enabled_flag = 'Y'
    AND    flv.meaning = p_bucket_type_name;
  
    RETURN l_bucket_type_code;
  
  EXCEPTION
    WHEN OTHERS THEN
      x_err_code := '1';
      x_err_msg  := 'Error in get_bucket_type_code: ' || SQLERRM;
      RETURN NULL;
  END get_bucket_type_code;

  --------------------------------------------------------------------
  --  name:            convert_data
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   14/12/2014
  --------------------------------------------------------------------
  --  purpose :        Convert data from interface table and insert
  --                   into target tables
  --------------------------------------------------------------------
  --  ver    date        name             desc
  --  1.0    14/12/2014  Michal Tzvik     Initial Build - CHG0034003
  --------------------------------------------------------------------
  PROCEDURE convert_data(x_err_code OUT VARCHAR2,
                         x_err_msg  OUT VARCHAR2) IS
  
    l_err_code VARCHAR2(1);
    l_err_msg  VARCHAR2(2000);
  
    line_error   EXCEPTION;
    header_error EXCEPTION;
  
  BEGIN
    x_err_code := '0';
    x_err_msg  := '';
  
    fnd_file.put_line(fnd_file.log, '');
    fnd_file.put_line(fnd_file.log, '');
    fnd_file.put_line(fnd_file.log, 'Upload data to bucket tables...');
    fnd_file.put_line(fnd_file.log, '');
  
    -------- Bucket Headers ---------
    FOR r_header IN c_headers LOOP
      BEGIN
        SAVEPOINT new_header;
        r_header.xx_bucket_type_code := get_bucket_type_code(r_header.bucket_type, l_err_code, g_err_msg);
        IF l_err_code != '0' THEN
          RAISE header_error;
        END IF;
        IF r_header.customer_number IS NOT NULL THEN
          r_header.xx_customer_id := get_customer_id(r_header.customer_number, l_err_code, g_err_msg);
          IF l_err_code != '0' THEN
            RAISE header_error;
          END IF;
        END IF;
        r_header.xx_bucket_header_id := get_bucket_header_id(r_header, l_err_code, g_err_msg);
        IF l_err_code != '0' THEN
          RAISE header_error;
        END IF;
      
        -------- Bucket Lines ---------
        FOR r_line IN c_lines(p_bucket_type => r_header.bucket_type, p_parent_customer_location => r_header.parent_customer_location, p_customer_number => r_header.customer_number, p_period_name => r_header.period_name) LOOP
          --BEGIN
          r_line.xx_bucket_header_id := r_header.xx_bucket_header_id;
          IF l_err_code != '0' THEN
            RAISE line_error;
          END IF;
          r_line.xx_order_type_id := get_order_type_id(r_line.order_type, l_err_code, g_err_msg);
          IF l_err_code != '0' THEN
            RAISE line_error;
          END IF;
          r_line.xx_calc_method_code := get_calc_method_code(r_line.calc_method, l_err_code, g_err_msg);
          IF l_err_code != '0' THEN
            RAISE line_error;
          END IF;
        
          IF r_line.limit_type IS NOT NULL THEN
            r_line.xx_limit_type_code := get_limit_type_code(r_line.limit_type, l_err_code, g_err_msg);
            IF l_err_code != '0' THEN
              RAISE line_error;
            END IF;
          END IF;
        
          create_bucket_line(r_line, l_err_code, g_err_msg);
          IF l_err_code != '0' THEN
            RAISE line_error;
          END IF;
          /* EXCEPTION
           -- if line is failed, all bucket should fail 
          WHEN OTHERS THEN
               l_err_msg :=SQLERRM;
               RAISE line_error;
           END;*/
        END LOOP; -- lines
      
        update_interface_status(r_header.row_id, 'PROCESSED', NULL);
      
      EXCEPTION
        WHEN line_error THEN
          x_err_code := '1';
          g_err_msg  := 'Error in processing line: ' || g_err_msg;
          ROLLBACK TO new_header;
          update_interface_status(r_header.row_id, 'ERROR', g_err_msg);
        
        WHEN header_error THEN
          x_err_code := '1';
          g_err_msg  := 'Error in processing header: ' || g_err_msg;
          ROLLBACK TO new_header;
          update_interface_status(r_header.row_id, 'ERROR', g_err_msg);
        
        WHEN OTHERS THEN
          x_err_code := '1';
          g_err_msg  := 'Error in processing header: ' || SQLERRM;
          ROLLBACK TO new_header;
          update_interface_status(r_header.row_id, 'ERROR', g_err_msg);
      END;
    END LOOP; -- headers
  
    COMMIT;
  
  END convert_data;

  --------------------------------------------------------------------
  --  name:            main
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   14/12/2014
  --------------------------------------------------------------------
  --  purpose :        main procedure. called by concurrent program:
  --                   1. upload data from csv to interface table (XXOE_DISCOUNT_BUCKET_INTERFACE)
  --                   2. convert and validate data
  --                   3. insert data into setup tables (XXOE_DISCOUNT_BUCKET_HEADERS, XXOE_DISCOUNT_BUCKET_LINES)
  --                   4. update status in interface table
  --------------------------------------------------------------------
  --  ver    date        name             desc
  --  1.0    14/12/2014  Michal Tzvik     Initial Build - CHG0034003
  --------------------------------------------------------------------
  PROCEDURE main(errbuf          OUT VARCHAR2,
                 retcode         OUT VARCHAR2,
                 p_table_name    IN VARCHAR2, -- hidden parameter. default value ='XXOE_DISCOUNT_BUCKET_INTERFACE' independent value set XXOBJT_LOADER_TABLES
                 p_template_name IN VARCHAR2, -- hidden parameter. default value ='DEFAULT'
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
                                           
                                           p_table_name => 'XXOE_DISCOUNT_BUCKET_INTERFACE',
                                           
                                           p_template_name => p_template_name,
                                           
                                           p_file_name => p_file_name,
                                           
                                           p_directory => p_directory,
                                           
                                           p_expected_num_of_rows => NULL);
  
    IF l_retcode <> '0' THEN
      l_error_message := l_errbuf;
      RAISE stop_processing;
    END IF;
  
    -- 2. Convert data and upload to target tables
    convert_data(l_retcode, l_error_message);
    IF l_retcode <> '0' THEN
      RAISE stop_processing;
    END IF;
  
    -- 3. Create output
    report_data;
  EXCEPTION
    WHEN stop_processing THEN
      fnd_file.put_line(fnd_file.log, l_error_message);
      retcode := 1;
      errbuf  := 'Unexpected error';
    
      -- 3. Create output
      report_data;
  END main;

END xxoe_so_bucket_discnt_int_pkg;
/
