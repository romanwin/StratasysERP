CREATE OR REPLACE PACKAGE BODY xxap_shaam_pkg IS

  -------------------------------
  -- get_shaam_admin_mail_list
  ---------------------------------

  FUNCTION get_shaam_admin_mail_list RETURN VARCHAR2 IS
  BEGIN
    RETURN xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => '',
                                                       p_program_short_name => 'SHAAM');
  
  END;

  -------------------------------
  -- submit_shaam_interface_program
  --------------------------------

  PROCEDURE submit_shaam_interface_program(p_file_name   VARCHAR2,
                                           p_request_id  OUT NUMBER,
                                           p_err_code    OUT NUMBER,
                                           p_err_message OUT VARCHAR2) IS
    l_request_id  NUMBER;
    l_prog_name   VARCHAR2(50);
    l_prog_desc   VARCHAR2(500);
    l_err_code    NUMBER;
    l_err_message VARCHAR2(500);
    l_user_name   VARCHAR2(100);
  BEGIN
    p_err_code := 0;
    fnd_global.apps_initialize(fnd_profile.VALUE('XXSHAAM_USER_ID'),
                               fnd_profile.VALUE('XXSHAAM_RESP_ID'),
                               fnd_profile.VALUE('XXSHAAM_RESP_APP_ID'));
  
    SELECT user_name
      INTO l_user_name
      FROM fnd_user u
     WHERE u.user_id = fnd_profile.VALUE('XXSHAAM_USER_ID');
  
    IF NOT fnd_request.set_print_options(copies => 0) THEN
    
      NULL;
    END IF;
  
    CASE p_file_name
    
      WHEN 'SHAAM.dat' THEN
        l_prog_name  := 'CLEF077APSHIP';
        l_prog_desc  := 'CLE: Israeli Localization Shaam Interface Program';
        l_request_id := fnd_request.submit_request(application => 'CLE',
                                                   program     => l_prog_name,
                                                   argument1   => 'Site',
                                                   argument2   => fnd_profile.VALUE('XXSHAAM_USER_ID'));
      
      WHEN 'SHAAM_ERROR.dat' THEN
        l_prog_name  := 'CLEF077APSHIXP';
        l_prog_desc  := 'CLE: Israeli Localization Shaam Interface Exception Program';
        l_request_id := fnd_request.submit_request(application => 'CLE',
                                                   program     => l_prog_name,
                                                   argument1   => 'Site');
    END CASE;
  
    COMMIT;
    p_request_id := l_request_id;
    IF nvl(l_request_id, 0) = 0 THEN
    
      p_err_code    := 1;
      p_err_message := 'Failed to submit ' || l_prog_desc;
      xxobjt_wf_mail.send_mail_text(p_to_role     => l_user_name,
                                    p_cc_mail     => get_shaam_admin_mail_list,
                                    p_subject     => 'Error : SHAAM File Load Info',
                                    p_body_text   => 'Failed to submit
                                                   ' ||
                                                     l_prog_desc,
                                    p_err_code    => l_err_code,
                                    p_err_message => l_err_message);
    ELSE
      p_err_code    := 0;
      p_err_message := fnd_message.get;
      xxobjt_wf_mail.send_mail_text(p_to_role     => l_user_name,
                                    p_cc_mail     => get_shaam_admin_mail_list,
                                    p_subject     => 'SHAAM File Load Info',
                                    p_body_text   => 'Request id : ' ||
                                                     l_request_id || ' ' ||
                                                     l_prog_desc ||
                                                     ' Submited successfuly',
                                    p_err_code    => l_err_code,
                                    p_err_message => l_err_message);
    
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      p_err_code    := 2;
      p_err_message := l_err_message || ' ' || SQLERRM;
    
      xxobjt_wf_mail.send_mail_text(p_to_role     => l_user_name,
                                    p_cc_mail     => get_shaam_admin_mail_list,
                                    p_subject     => 'Error : SHAAM File Load Info',
                                    p_body_text   => 'Failed to submit
                                                   ' ||
                                                     l_prog_desc,
                                    p_err_code    => l_err_code,
                                    p_err_message => l_err_message);
    
  END;

  ---------------------------------------------
  -- send_mail
  ---------------------------------------------
  PROCEDURE send_mail(p_err_code NUMBER, p_err_msg VARCHAR2) IS
    l_err_code    NUMBER;
    l_err_message VARCHAR2(200);
    l_user_name   VARCHAR2(100);
  BEGIN
  
    fnd_global.apps_initialize(fnd_profile.VALUE('XXSHAAM_USER_ID'),
                               fnd_profile.VALUE('XXSHAAM_RESP_ID'),
                               fnd_profile.VALUE('XXSHAAM_RESP_APP_ID'));
  
    xxobjt_wf_mail.send_mail_text(p_to_role     => fnd_global.user_name,
                                  p_cc_mail     => get_shaam_admin_mail_list,
                                  p_subject     => 'Error : SHAAM File Load Info',
                                  p_body_text   => 'General failure
                                                   ' ||
                                                   p_err_msg ||
                                                   ' Bpel Instance id=' ||
                                                   p_err_code,
                                  p_err_code    => l_err_code,
                                  p_err_message => l_err_message);
  END;
  ------------------------------------
  -- COPY_file
  ------------------------------------
  PROCEDURE copy_file(p_bpel_instance NUMBER,
                      p_dir           VARCHAR2,
                      p_file_name     VARCHAR2,
                      p_err_code      OUT NUMBER) IS
  
    l_dest_dir   VARCHAR2(100);
    l_request_id NUMBER;
    --
    l_wait_result BOOLEAN;
    lv_phase      VARCHAR2(20);
    lv_status     VARCHAR2(20);
    lv_dev_phase  VARCHAR2(20);
    lv_dev_status VARCHAR2(20);
    lv_message1   VARCHAR2(20);
    lb_result     BOOLEAN;
  BEGIN
    p_err_code := 0;
    fnd_global.apps_initialize(fnd_profile.VALUE('XXSHAAM_USER_ID'),
                               fnd_profile.VALUE('XXSHAAM_RESP_ID'),
                               fnd_profile.VALUE('XXSHAAM_RESP_APP_ID'));
  
    SELECT t.path || '/cle/12.0.0/bin'
      INTO l_dest_dir
      FROM applsys.fnd_appl_tops t
     WHERE rownum = 1;
  
    l_request_id := fnd_request.submit_request(application => 'XXOBJT',
                                               program     => 'XXMVFILE',
                                               argument1   => p_dir,
                                               argument2   => p_file_name,
                                               argument3   => l_dest_dir,
                                               argument4   => p_file_name);
    COMMIT;
  
    lb_result := fnd_concurrent.wait_for_request(l_request_id,
                                                 10,
                                                 120,
                                                 lv_phase,
                                                 lv_status,
                                                 lv_dev_phase,
                                                 lv_dev_status,
                                                 lv_message1);
    COMMIT;
    IF lv_dev_phase = 'COMPLETE' THEN
      IF lv_dev_status = 'WARNING' OR lv_dev_status = 'ERROR' THEN
        p_err_code := 1;
        send_mail(p_bpel_instance,
                  'Request= ' || l_request_id || ' Unable to move ' ||
                  p_dir || '/' || p_file_name);
      ELSIF lv_dev_status = 'NORMAL' THEN
        dbms_output.put_line('Success');
      END IF;
    ELSE
      send_mail(p_bpel_instance,
                'Request id= ' || l_request_id || ' Unable to move ' ||
                p_dir || '/' || p_file_name);
    END IF;
  
  END;

END;
/

