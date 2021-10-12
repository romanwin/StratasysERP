CREATE OR REPLACE PACKAGE BODY XXAR_UPDATE_INVOICE_PKG IS
--------------------------------------------------------------------
--  name:            CUST293 - AR VAT upd global dff - xxar_update_invoice_pkg
--  create by:       SARI.FRAIMAN
--  Revision:        1.0 
--  creation date:   07/04/2010 2:43:50 PM
--------------------------------------------------------------------
--  purpose :        update invoices with reshimon data - to global_attributes
--------------------------------------------------------------------
--  ver  date        name             desc
--  1.0  07/04/2010  Sari             initial build
--  1.1  19/07/2010  Dalit A. Raviv   correct date formate at laod_global_dff proc
--------------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:            get_value_from_line
  --  create by:       SARI.FRAIMAN
  --  Revision:        1.0 
  --  creation date:   07/04/2010 2:43:50 PM
  --------------------------------------------------------------------
  --  purpose :        get value from excel line
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  07/04/2010  Sari             initial build
  --------------------------------------------------------------------
  FUNCTION get_value_from_line(p_line_string IN OUT VARCHAR2,
                               p_err_msg     IN OUT VARCHAR2,
                               c_delimiter   IN     VARCHAR2) RETURN VARCHAR2 IS
   
    l_pos        NUMBER;
    l_char_value VARCHAR2(20);
       
  BEGIN
   
    l_pos := instr(p_line_string, c_delimiter);
    IF nvl(l_pos, 0) < 1 THEN
      l_pos := length(p_line_string);
    END IF;
   
    l_char_value := ltrim(rtrim(substr(p_line_string, 1, l_pos - 1)));
    p_line_string := substr(p_line_string, l_pos + 1);
   
    RETURN l_char_value;
  EXCEPTION
    WHEN OTHERS THEN
      p_err_msg := 'get_value_from_line - ' || substr(SQLERRM, 1, 250);
  END get_value_from_line;

  --------------------------------------------------------------------
  --  name:            load_global_dff
  --  create by:       SARI.FRAIMAN
  --  Revision:        1.0 
  --  creation date:   07/04/2010 2:43:50 PM
  --------------------------------------------------------------------
  --  purpose :        update invoices with reshimon data - to global_attributes
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  07/04/2010  Sari             initial build
  --  1.1  19/07/2010  Dalit A. Raviv   change date format come from the excel file.
  --                                    the value come from excel is - 01-jun-10
  --                                    this make the update to update incorect date 01-jun-0010
  --------------------------------------------------------------------
  PROCEDURE load_global_dff(errbuf     OUT VARCHAR2,
                            retcode    OUT VARCHAR2,
                            p_location IN  VARCHAR2,
                            p_filename IN  VARCHAR2) IS
   
    l_file_hundler utl_file.file_type;
       
    l_line_buffer        VARCHAR2(2000);
    l_counter            NUMBER               := 0;
    l_err_msg            VARCHAR2(500);
    c_delimiter          CONSTANT VARCHAR2(1) := ',';
       
    l_trans_number       VARCHAR2(240);
    l_trans_line_id      NUMBER;
    l_export_file_number VARCHAR2(240);
    l_export_file_date   VARCHAR2(240);
    l_error_code         NUMBER               := 0;
    l_error_desc         VARCHAR2(2000)       := NULL;
    lv_flag              CHAR(1);
    invalid_row          EXCEPTION;
  BEGIN
   
    -- handle open file to read and handle file exceptions
    BEGIN
      l_file_hundler := utl_file.fopen( location     => p_location,
                                        filename     => p_filename,
                                        open_mode    => 'r',
                                        max_linesize => 32000);
          
    EXCEPTION
      WHEN utl_file.invalid_path THEN
        fnd_file.put_line(fnd_file.log,'Invalid Path for '||ltrim(p_filename));             
        RAISE;
      WHEN utl_file.invalid_mode THEN
        fnd_file.put_line(fnd_file.log,'Invalid Mode for '||ltrim(p_filename));             
        RAISE;
      WHEN utl_file.invalid_operation THEN
        fnd_file.put_line(fnd_file.log,'Invalid operation for '||ltrim(p_filename)||SQLERRM);             
        RAISE;
      WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log, 'Other for '||ltrim(p_filename));             
        RAISE;
    END;
   
    -- start read from file, do needed validation, and upload data to table
    -- Loop For All File's Lines
    LOOP
      BEGIN
        -- goto next line
        l_counter            := l_counter + 1;
        l_err_msg            := NULL;
        l_trans_number       := NULL;
        l_trans_line_id      := NULL;
        l_export_file_number := NULL;
        l_export_file_date   := NULL;
        lv_flag              := 'N';
           
        -- Get Line and handle exceptions
        BEGIN
          utl_file.get_line(file   => l_file_hundler,
                            buffer => l_line_buffer);
        EXCEPTION
          WHEN utl_file.read_error THEN
            l_err_msg := 'Read Error for line: '||l_counter;
                         
            RAISE invalid_row;
          WHEN no_data_found THEN
            EXIT;
          WHEN OTHERS THEN
            l_err_msg := 'Read Error for line: '||l_counter||', Error: '|| SQLERRM;
                         
            RAISE invalid_row;
        END;
         
        -- Get data from line separate by deliminar
        IF l_counter > 1 THEN
            
          l_trans_number := get_value_from_line(l_line_buffer,
                                               l_err_msg,
                                               c_delimiter);
                      
          l_trans_line_id := get_value_from_line(l_line_buffer,
                                                l_err_msg,
                                                c_delimiter);
                      
          l_export_file_number := get_value_from_line(l_line_buffer,
                                                     l_err_msg,
                                                     c_delimiter);
                      
          l_export_file_date := get_value_from_line(l_line_buffer,
                                                   l_err_msg,
                                                   c_delimiter);
                      
          BEGIN
            /*
            l_export_file_date := to_char(to_date(l_export_file_date,
                                                  'DD/MM/YYYY HH24:MI:SS'), 
                                          'YYYY/MM/DD HH24:MI:SS');
            */
            -- 1.1  19/07/2010  Dalit A. Raviv       
            l_export_file_date := to_char(to_date(l_export_file_date,'DD/MM/RR HH24:MI:SS'), 'RRRR/MM/DD HH24:MI:SS');
            -- end 1.1
            --fnd_file.put_line(fnd_file.log,'l_export_file_date - '||l_export_file_date);
            --fnd_file.put_line(fnd_file.log,'l_trans_number - '|| l_trans_number||' - l_trans_line_id  - '||l_trans_line_id);
            BEGIN
                  
              SELECT 'Y'
              INTO   lv_flag
              FROM   ra_customer_trx_lines_all rctl
              WHERE  rctl.customer_trx_line_id = l_trans_line_id 
              and    rctl.line_type            = 'LINE' 
              and    rctl.org_id               = 81;
                                
              UPDATE ra_customer_trx_lines_all rctl
              SET    rctl.global_attribute1         = l_export_file_number,
                     rctl.global_attribute2         = l_export_file_date,
                     rctl.global_attribute_category = 'JE.IL.ARXTWMAI.EXPORT_INFO'
              WHERE  rctl.customer_trx_line_id      = l_trans_line_id 
              and    rctl.line_type                 = 'LINE' 
              and    rctl.org_id                    = 81; -- Only IL
                  
            EXCEPTION
               WHEN OTHERS THEN
                  retcode := 1;
                  --fnd_file.put_line(fnd_file.log,'In customer trx line id : '||l_trans_line_id||' there is a problem');
                  -- 1.1  19/07/2010  Dalit A. Raviv  
                  fnd_file.put_line(fnd_file.log,'This invoice - '|| l_trans_number||', line id - '||l_trans_line_id||
                                    'do not belong to Operating unit IL');
            END;
          EXCEPTION
            WHEN OTHERS THEN
              l_err_msg := SQLERRM;
              retcode   := 1;
              fnd_file.put_line(fnd_file.log, 'In customer trx line id : '||l_trans_line_id||
                                ' there is a problem in date. ' ||l_err_msg);
          END;
          -- do update
          l_error_code := 0;
          l_error_desc := NULL;
        END IF;
      EXCEPTION
        WHEN invalid_row THEN
          retcode := 1;
          l_err_msg := 'invalid row:' || l_err_msg;
          fnd_file.put_line(fnd_file.log, l_err_msg);
        WHEN OTHERS THEN
          retcode := 1;
          l_err_msg := SQLERRM;
          fnd_file.put_line(fnd_file.log, l_err_msg);
          ROLLBACK;
      END;
    END LOOP;
    utl_file.fclose(l_file_hundler);
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'General exception - '||substr(SQLERRM, 1, 250);
      retcode := 2;
  END load_global_dff;
  ----------------------------------------------------------  
END xxar_update_invoice_pkg;
/

