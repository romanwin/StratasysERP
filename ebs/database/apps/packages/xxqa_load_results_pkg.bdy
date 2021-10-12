CREATE OR REPLACE PACKAGE BODY xxqa_load_results_pkg IS

  --------------------------------------------------------------------
  --  name:            XXQA_LOAD_RESULTS_PKG
  --  create by:       Eran Baram
  --  Revision:        1.0 
  --  creation date:   19/01/2011
  --------------------------------------------------------------------
  --  purpose :        CUST276 - Load QA plans from excel files
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  19/01/2011  Eran Baram    initial build
  --  1.1  13/10/2013  Vitaly        cr870 -- change hard-coded organization
  --------------------------------------------------------------------

  invalid_item EXCEPTION;
  --g_login_id   number := null;
  g_user_id NUMBER := NULL;

  --------------------------------------------------------------------
  --  name:            get_value_from_line
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0 
  --  creation date:   23/05/2010 
  --------------------------------------------------------------------
  --  purpose :        get value from excel line 
  --                   return short string each time by the deliminar 
  --------------------------------------------------------------------
  --  ver  date        name             desc
  --  1.0  23/05/2010  Dalit A. Raviv   initial build
  --------------------------------------------------------------------
  FUNCTION get_value_from_line(p_line_string IN OUT VARCHAR2,
                               p_err_msg     IN OUT VARCHAR2,
                               c_delimiter   IN VARCHAR2) RETURN VARCHAR2 IS
  
    l_pos        NUMBER;
    l_char_value VARCHAR2(250);
  
  BEGIN
    l_pos := instr(p_line_string, c_delimiter);
  
    IF nvl(l_pos, 0) < 1 THEN
      l_pos := length(p_line_string);
    END IF;
  
    l_char_value  := ltrim(rtrim(substr(p_line_string, 1, l_pos - 1)));
    p_line_string := substr(p_line_string, l_pos + 1);
  
    RETURN l_char_value;
  EXCEPTION
    WHEN OTHERS THEN
      p_err_msg := 'get_value_from_line - ' || substr(SQLERRM, 1, 250);
      fnd_file.put_line(fnd_file.log, 'p_err_msg ' || p_err_msg);
      RETURN NULL;
  END get_value_from_line;

  --------------------------------------------------------------------
  --  name:            load_sn_reporting_plan
  --  create by:       
  --  Revision:        1.0 
  --  creation date:   
  --------------------------------------------------------------------
  --  purpose :        
  --------------------------------------------------------------------
  --  ver  date        name          desc
  --  1.0  xxxxxx      xxxxxxx       initial build
  --  1.1  13/10/2013  Vitaly        cr870 -- change hard-coded organization
  --------------------------------------------------------------------
  PROCEDURE load_sn_reporting_plan(errbuf     OUT VARCHAR2,
                                   retcode    OUT VARCHAR2,
                                   p_location IN VARCHAR2,
                                   p_filename IN VARCHAR2) IS
  
    l_file_hundler utl_file.file_type;
    l_line_buffer  VARCHAR2(2500);
    l_counter      NUMBER := 0;
    l_err_msg      VARCHAR2(500);
    l_pos          NUMBER;
    c_delimiter CONSTANT VARCHAR2(1) := ',';
  
    l_job_name        wip_entities.wip_entity_name%TYPE;
    l_job_assy        mtl_system_items_b.segment1%TYPE;
    l_comp_item       mtl_system_items_b.segment1%TYPE;
    l_comp_desc       mtl_system_items_b.description%TYPE;
    l_sn              VARCHAR2(150);
    l_version         VARCHAR2(150);
    l_position        VARCHAR2(150);
    l_cpu_version     VARCHAR2(150);
    l_rom_version     VARCHAR2(150);
    l_sw_version      VARCHAR2(150);
    l_hw_version      VARCHAR2(150);
    l_hasp_sw_version VARCHAR2(150);
    l_hasp_expiration DATE;
    v_request_id      NUMBER := fnd_global.conc_request_id;
  
    g_user_name     fnd_user.user_name%TYPE;
    l_wip_entity_id NUMBER;
    l_assy_id       NUMBER;
    l_txn_seq       NUMBER;
    l_exists        NUMBER;
  
  BEGIN
    -- init globals
    --g_login_id := fnd_profile.VALUE('LOGIN_ID');
    g_user_id := fnd_profile.value('USER_ID'); --nvl(fnd_profile.VALUE('USER_ID'),2470);
  
    BEGIN
      SELECT fu.user_name
        INTO g_user_name
        FROM fnd_user fu
       WHERE fu.user_id = g_user_id;
    EXCEPTION
      WHEN OTHERS THEN
        g_user_name := 'SYSADMIN';
    END;
  
    -- handle open file to read and handle file exceptions
    BEGIN
      l_file_hundler := utl_file.fopen(location     => p_location,
                                       filename     => p_filename,
                                       open_mode    => 'r',
                                       max_linesize => 32000);
    EXCEPTION
      WHEN utl_file.invalid_path THEN
        fnd_file.put_line(fnd_file.log,
                          'Invalid Path for ' || ltrim(p_filename));
        RAISE;
      WHEN utl_file.invalid_mode THEN
        fnd_file.put_line(fnd_file.log,
                          'Invalid Mode for ' || ltrim(p_filename));
        RAISE;
      WHEN utl_file.invalid_operation THEN
        fnd_file.put_line(fnd_file.log,
                          'Invalid operation for ' || ltrim(p_filename) ||
                          SQLERRM);
        RAISE;
      WHEN OTHERS THEN
        fnd_file.put_line(fnd_file.log, 'Other for ' || ltrim(p_filename));
        RAISE;
    END; -- open file
  
    -- start read from file, do needed validation, and upload data to table
    -- Loop For All File's Lines
    LOOP
      BEGIN
        -- goto next line
        l_counter   := l_counter + 1;
        l_err_msg   := NULL;
        l_job_name  := NULL;
        l_job_assy  := NULL;
        l_comp_item := NULL;
        l_comp_desc := NULL;
        l_sn        := NULL;
        l_version   := NULL;
        l_exists    := 0;
      
        -- Get Line and handle exceptions
        BEGIN
          utl_file.get_line(file   => l_file_hundler,
                            buffer => l_line_buffer);
        EXCEPTION
          WHEN utl_file.read_error THEN
            l_err_msg := 'Read Error for line: ' || l_counter;
            RAISE invalid_item;
          WHEN no_data_found THEN
            EXIT;
          WHEN OTHERS THEN
            l_err_msg := 'Read Error for line: ' || l_counter ||
                         ', Error: ' || SQLERRM;
            RAISE invalid_item;
        END;
      
        -- Get data from line separate by deliminar
        IF l_counter > 1 THEN
        
          l_pos      := 0;
          l_job_name := get_value_from_line(l_line_buffer,
                                            l_err_msg,
                                            c_delimiter);
        
          BEGIN
            -- get job assy
            SELECT msib.segment1, we.wip_entity_id, msib.inventory_item_id
              INTO l_job_assy, l_wip_entity_id, l_assy_id
              FROM wip_entities we, mtl_system_items_b msib
             WHERE we.wip_entity_name = l_job_name
               AND we.primary_item_id = msib.inventory_item_id
               AND msib.organization_id = we.organization_id;
          
          EXCEPTION
            WHEN OTHERS THEN
              l_job_assy      := NULL;
              l_wip_entity_id := NULL;
              l_assy_id       := NULL;
          END;
        
          l_comp_item := get_value_from_line(l_line_buffer,
                                             l_err_msg,
                                             c_delimiter);
        
          -- get comp desc from OMA
          BEGIN
            SELECT msib.description
              INTO l_comp_desc
              FROM mtl_system_items_b msib
             WHERE msib.segment1 = l_comp_item
               AND msib.organization_id = 91;
          EXCEPTION
            WHEN OTHERS THEN
              l_comp_desc := NULL;
            
          END;
        
          l_sn      := get_value_from_line(l_line_buffer,
                                           l_err_msg,
                                           c_delimiter);
          l_version := get_value_from_line(l_line_buffer,
                                           l_err_msg,
                                           c_delimiter);
        
          -- validate if data exists in QA PLAN
          SELECT COUNT(*)
            INTO l_exists
            FROM q_sn_reporting_v k
           WHERE k.job = l_job_name
             AND k.item = l_job_assy
             AND k.serial_component_item = l_comp_item
             AND k.obj_serial_number = l_sn
             AND k.version = l_version;
        
          IF l_exists = 0 THEN
            -- insert in QA interface table
          
            SELECT qa_txn_interface_s.nextval INTO l_txn_seq FROM dual;
            INSERT INTO q_sn_reporting_iv
              (qa_last_updated_by_name,
               qa_created_by_name,
               process_status,
               organization_code,
               plan_name,
               job_name,
               item,
               serial_component_item,
               item_desc,
               obj_serial_number,
               version)
            VALUES
              (g_user_name,
               g_user_name,
               1,
               'IPK' /*'WPI'*/, ---Vitaly 13/10/2013
               'SN REPORTING',
               l_job_name,
               l_job_assy,
               l_comp_item,
               l_comp_desc,
               l_sn,
               l_version);
          
          END IF; -- if exists
        END IF; -- if counter > 1
      END;
    END LOOP;
  
    /*-- remove validation
    update qa_results_interface k
       set k.validate_flag = 2
     where k.plan_name = 'SN REPORTING';*/
  
    -- submit  QA proccessor to process lines
  
    /*QLTTRAMB.TRANSACTION_MANAGER(WORKER_ROWS => 200,
    ARGUMENT2   => 1,
    ARGUMENT3   => to_char(g_user_id),
    ARGUMENT4   => 'Yes');*/
  
    v_request_id := fnd_request.submit_request('QA',
                                               'QLTTRAMB',
                                               NULL,
                                               NULL,
                                               FALSE,
                                               '200',
                                               1,
                                               to_char(g_user_id),
                                               'Yes');
  
  END;

END xxqa_load_results_pkg;
/
