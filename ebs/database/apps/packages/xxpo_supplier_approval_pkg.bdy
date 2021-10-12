CREATE OR REPLACE PACKAGE BODY xxpo_supplier_approval_pkg IS
  --------------------------------------------------------------------
  --  name:       xxpo_supplier_approval_pkg     
  --  create by:    yuval tal  
  --  Revision:        
  --  creation date:   26.11.2012 
  --------------------------------------------------------------------
  --  purpose :        CUST607 - support supplier approval process
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  26.11.2012    yuval tal      initial build
  --------------------------------------------------------------------  

  --------------------------------------------------------------------
  --  name:     is_approval_process_needed      
  --  create by:       
  --  Revision:       
  --------------------------------------------------------------------
  --  purpose:    Define for each Vendor type if to include in approval process or not      
  --  In  Params:      
  --  Out Params:  YES/NO    
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  26.11.2012    yuval tal     initial build

  --------------------------------------------------------------------
  FUNCTION is_approval_process_needed(p_vendor_type VARCHAR2) RETURN VARCHAR2 IS
    CURSOR c IS
      SELECT flv.attribute1
        FROM fnd_lookup_values_vl flv
       WHERE flv.lookup_type = 'VENDOR TYPE'
         AND lookup_code = p_vendor_type;
  
    l_tmp VARCHAR2(3);
  BEGIN
    OPEN c;
    FETCH c
      INTO l_tmp;
    CLOSE c;
    RETURN nvl(l_tmp, 'NO');
  END;

  --------------------------------------------------------------------
  --  name:    get_creator_user_name    
  --  create by:       
  --  Revision:       
  --  ver  date          name              desc
  --  1.0  26.11.2012    yuval tal     initial build
  --------------------------------------------------------------------
  FUNCTION get_creator_user_name(p_user_id NUMBER) RETURN VARCHAR2 IS
    l_tmp fnd_user.user_name%TYPE;
  BEGIN
    SELECT user_name
      INTO l_tmp
      FROM fnd_user u
     WHERE u.user_id = p_user_id;
    RETURN l_tmp;
  
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
    
  END;

  --------------------------------------------------------------------
  --  name:     is_approval_process_needed      
  --  create by:       
  --  Revision:       
  --------------------------------------------------------------------
  --  purpose:    get distmail list for supplier status     
  --  In  Params:      
  --  Out Params:  YES/NO    
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  26.11.2012    yuval tal     initial build

  -----------------------------------------------------------------------
  FUNCTION get_mail_dist(p_supplier_status VARCHAR2, p_created_by NUMBER)
    RETURN VARCHAR2 IS
    CURSOR c IS
      SELECT upper(ffv.attribute1), ffv.attribute2
        FROM fnd_flex_values_vl ffv, fnd_flex_value_sets s
       WHERE s.flex_value_set_id = ffv.flex_value_set_id
         AND s.flex_value_set_name = 'XXPUR_SUPPLIER_STATUS_VS'
         AND ffv.flex_value_meaning = p_supplier_status;
  
    l_tmp               VARCHAR2(500);
    l_send_creator_flag VARCHAR2(10);
  
  BEGIN
    OPEN c;
    FETCH c
      INTO l_tmp, l_send_creator_flag;
    IF l_send_creator_flag = 'YES' THEN
      IF instr(l_tmp, get_creator_user_name(p_created_by)) > 0 THEN
        NULL;
      ELSE
        l_tmp := l_tmp || ' ' || get_creator_user_name(p_created_by);
      END IF;
    END IF;
  
    CLOSE c;
    RETURN upper(l_tmp);
  END;

  --------------------------------------------------------------------
  --  name:     attachment_exists      
  --  create by:       
  --  Revision:       
  --------------------------------------------------------------------
  --  purpose:    check exist of short text attachment in case of status is marked as need attachment   
  --  In  Params:      
  --  Out Params:  Y pass check / N failed check   
  --------------------------------------------------------------------
  --  ver  date          name              desc
  --  1.0  26.11.2012    yuval tal     initial build

  -----------------------------------------------------------------------

  FUNCTION attachment_exists(p_vendor_id            NUMBER,
                             p_approval_status_code VARCHAR2) RETURN VARCHAR2 IS
  
    CURSOR c_need_att IS
      SELECT ffv.attribute3
        FROM fnd_flex_values_vl ffv, fnd_flex_value_sets s
       WHERE s.flex_value_set_id = ffv.flex_value_set_id
         AND s.flex_value_set_name = 'XXPUR_SUPPLIER_STATUS_VS'
         AND ffv.flex_value = p_approval_status_code;
  
    CURSOR c_att IS
      SELECT 'Y'
        FROM fnd_attached_docs_form_vl ff
       WHERE ff.entity_name = 'PO_VENDORS'
         AND datatype_id = 1
         AND pk1_value = to_char(p_vendor_id)
         AND ff.created_by = fnd_global.user_id;
    --  AND ff.category_id = 34;
    l_tmp        VARCHAR2(5);
    l_att_exists VARCHAR2(1);
  BEGIN
  
    OPEN c_need_att;
    FETCH c_need_att
      INTO l_tmp;
    IF nvl(l_tmp, 'NO') = 'YES' THEN
      -- check existance
      OPEN c_att;
      FETCH c_att
        INTO l_att_exists;
      CLOSE c_att;
    
      RETURN nvl(l_att_exists, 'N');
    ELSE
      RETURN 'Y'; -- no need to check
    END IF;
  
    CLOSE c_need_att;
  
  END;

  --------------------------------------------
  -- send_mail
  --
  -- create addhoc role for mail distribution
  -- send supplier alert
  -------------------------------------------

  PROCEDURE send_mail(p_vendor_id      NUMBER,
                      p_created_by     NUMBER,
                      p_supplier_name  VARCHAR2,
                      p_old_status     VARCHAR2,
                      p_new_status     VARCHAR2,
                      p_history_ind    VARCHAR2 DEFAULT 'N',
                      p_dist_role_name VARCHAR2 DEFAULT NULL,
                      p_subject_prefix VARCHAR2 DEFAULT NULL) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  
    l_role_name       VARCHAR2(1000);
    l_role_desc       VARCHAR2(1000);
    l_body            VARCHAR2(2000);
    l_err_code        NUMBER;
    l_err_message     VARCHAR2(500);
    l_subject         VARCHAR2(500);
    l_dist_roles_list VARCHAR2(1000);
  BEGIN
    IF p_dist_role_name IS NULL THEN
      l_dist_roles_list := xxpo_supplier_approval_pkg.get_mail_dist(p_new_status,
                                                                    p_created_by);
      -- get dist list by setup
      IF l_dist_roles_list IS NOT NULL THEN
      
        IF instr(TRIM(l_dist_roles_list), ' ') > 0 THEN
        
          l_role_name := upper('XXSUPAPR_' || p_vendor_id || '_' ||
                               to_char(SYSDATE, 'HH24MISS'));
          wf_directory.createadhocrole(role_name               => l_role_name,
                                       role_display_name       => l_role_desc,
                                       LANGUAGE                => NULL,
                                       territory               => NULL,
                                       role_description        => 'Supplier_Approval',
                                       notification_preference => 'MAILHTML',
                                       role_users              => l_dist_roles_list,
                                       email_address           => NULL,
                                       fax                     => NULL,
                                       status                  => 'ACTIVE',
                                       expiration_date         => SYSDATE + 1,
                                       parent_orig_system      => -1,
                                       parent_orig_system_id   => -1,
                                       owner_tag               => NULL);
          COMMIT;
        ELSE
        
          l_role_name := l_dist_roles_list;
        
        END IF;
      END IF;
    ELSE
    
      l_role_name := p_dist_role_name;
    
    END IF;
  
    --
    fnd_message.set_name('XXOBJT', 'XXPUR_SUPPLIER_APPROVAL_TEXT');
    fnd_message.set_token('SUPP_NAME', p_supplier_name);
    fnd_message.set_token('OLD_STATUS', p_old_status);
    fnd_message.set_token('NEW_STATUS', p_new_status);
    l_body := fnd_message.get;
  
    fnd_message.set_name('XXOBJT', 'XXPUR_SUPPLIER_APPROVAL_SUB');
    fnd_message.set_token('SUPP_NAME', p_supplier_name);
  
    l_subject := fnd_message.get;
  
    xxobjt_wf_mail.send_mail_text(p_to_role     => l_role_name,
                                  p_subject     => p_subject_prefix ||
                                                   l_subject,
                                  p_body_text   => l_body,
                                  p_err_code    => l_err_code,
                                  p_err_message => l_err_message);
  
    IF p_history_ind = 'Y' THEN
    
      UPDATE xxpo_supplier_approval_his t
         SET t.last_ind = NULL
       WHERE t.vendor_id = p_vendor_id;
    
      INSERT INTO xxpo_supplier_approval_his
        (vendor_id,
         
         status,
         old_status,
         distribution_roles,
         last_update_date,
         last_updated_by,
         last_update_login,
         creation_date,
         created_by,
         last_ind)
      VALUES
        (p_vendor_id,
         
         p_new_status,
         p_old_status,
         l_dist_roles_list,
         NULL,
         NULL,
         fnd_global.login_id,
         SYSDATE,
         fnd_global.user_id,
         'Y');
    
    END IF;
    COMMIT;
  
  EXCEPTION
  
    WHEN OTHERS THEN
      /* xxobjt_debug_proc(p_message1 => 'Error in xxpo_supplier_approval_pkg.send_mail' ||
      chr(10) || 'l_dist_list=' ||
      l_dist_roles_list || chr(10) ||
      'p_old_status=' || p_old_status ||
      chr(10) || 'p_new_status=' ||
      p_new_status || chr(10) || SQLERRM ||
      
      chr(10) || chr(10) || 'Oracle Admin');*/
      xxobjt_wf_mail.send_mail_text(p_to_role     => fnd_profile.value('XX_ORACLE_OPERATION_ADMIN_USER'),
                                    p_cc_mail     => NULL,
                                    p_subject     => 'ERROR :Approval Supplier Alert :' ||
                                                     p_supplier_name,
                                    p_body_text   => 'Error in xxpo_supplier_approval_pkg.send_mail' ||
                                                     chr(10) ||
                                                     'l_dist_list=' ||
                                                     l_dist_roles_list ||
                                                     chr(10) ||
                                                     'p_old_status=' ||
                                                     p_old_status || chr(10) ||
                                                     'p_new_status=' ||
                                                     p_new_status || chr(10) ||
                                                     SQLERRM ||
                                                    
                                                     chr(10) || chr(10) ||
                                                     'Oracle Admin',
                                    p_err_code    => l_err_code,
                                    p_err_message => l_err_message);
    
      COMMIT;
  END;
  --------------------------------------------------
  -- is_hierarcy_exists
  --------------------------------------------------
  --  In  Params:  old/new supplier status    
  --  Out Params:  1 hierarch exist / 0 not exists 
  ---------------------------------------------------
  FUNCTION is_hierarchy_exists(p_old_status VARCHAR2,
                               p_new_status VARCHAR2) RETURN NUMBER IS
  
    CURSOR c(c_status VARCHAR2) IS
      SELECT ffv.hierarchy_level
        FROM fnd_flex_values_vl ffv, fnd_flex_value_sets s
       WHERE s.flex_value_set_id = ffv.flex_value_set_id
         AND s.flex_value_set_name = 'XXPUR_SUPPLIER_STATUS_VS'
         AND ffv.flex_value = c_status;
  
    l_old_level NUMBER;
    l_new_level NUMBER;
  
  BEGIN
    OPEN c(p_old_status);
    FETCH c
      INTO l_old_level;
    CLOSE c;
    OPEN c(p_new_status);
    FETCH c
      INTO l_new_level;
    CLOSE c;
  
    IF nvl(l_new_level, 0) - nvl(l_old_level, 0) IN (0, 1) THEN
      RETURN 1;
    ELSE
      RETURN 0;
    
    END IF;
  
  END;

  ------------------------------------------
  -- get_approval_status_by_seq
  -----------------------------------------

  FUNCTION get_approval_status_by_seq(p_seq NUMBER) RETURN VARCHAR2 IS
    CURSOR c IS
      SELECT ffv.flex_value
        FROM fnd_flex_values_vl ffv, fnd_flex_value_sets s
       WHERE s.flex_value_set_id = ffv.flex_value_set_id
         AND s.flex_value_set_name = 'XXPUR_SUPPLIER_STATUS_VS'
         AND ffv.hierarchy_level = p_seq;
  
    l_ret VARCHAR2(50);
  
  BEGIN
  
    OPEN c;
    FETCH c
      INTO l_ret;
    CLOSE c;
  
    RETURN l_ret;
  
  END;

  --------------------------------------------------
  --  get_last_status
  --------------------------------------------------

  FUNCTION get_last_status RETURN VARCHAR2 IS
  
    CURSOR c IS
      SELECT ffv.flex_value
        FROM fnd_flex_values_vl ffv, fnd_flex_value_sets s
       WHERE s.flex_value_set_id = ffv.flex_value_set_id
         AND s.flex_value_set_name = 'XXPUR_SUPPLIER_STATUS_VS'
         AND ffv.hierarchy_level =
             (SELECT MAX(ffv.hierarchy_level)
              
                FROM fnd_flex_values_vl ffv, fnd_flex_value_sets s
               WHERE s.flex_value_set_id = ffv.flex_value_set_id
                 AND s.flex_value_set_name = 'XXPUR_SUPPLIER_STATUS_VS');
    l_tmp VARCHAR2(100);
  BEGIN
    OPEN c;
    FETCH c
      INTO l_tmp;
    CLOSE c;
  
    RETURN l_tmp;
  END;

  ---------------------------------------------------
  -- status_escalation
  --
  -- used by cuncurrent XX PO Supplier Approval Escalation Alert/XXPOAPRALT
  --
  -- send esc mail after 2 days work
  -- send esc 30 days to po manager
  ----------------------------------------------------

  PROCEDURE status_escalation(errbuff OUT VARCHAR2, errcode OUT VARCHAR2) IS
  
    --  l_err_code    NUMBER;
    --  l_err_message VARCHAR2(500);
    -- l_subject     VARCHAR2(150);
    CURSOR c IS
      SELECT t.*, s.vendor_name
        FROM xxpo_supplier_approval_his t, ap_suppliers s
       WHERE s.vendor_id = t.vendor_id
         AND s.attribute1 = t.status
         AND t.esc_date1 IS NULL
         AND t.last_ind = 'Y'
         AND t.status != 'Rejected'
         AND t.status != xxpo_supplier_approval_pkg.get_last_status
         AND eng_bis_functions.getworkdaysbetween(90,
                                                  t.creation_date,
                                                  SYSDATE) >
             fnd_profile.value('XXPO_SUPP_APP_ESC1_DAYS');
  
    CURSOR c_mgr IS
      SELECT t.*, s.vendor_name
        FROM xxpo_supplier_approval_his t, ap_suppliers s
      
       WHERE s.vendor_id = t.vendor_id
         AND s.attribute1 = t.status
         AND t.esc_date2 IS NULL
         AND t.esc_date1 IS NOT NULL
         AND t.last_ind = 'Y'
         AND t.status != 'Rejected'
         AND t.status != xxpo_supplier_approval_pkg.get_last_status
         AND eng_bis_functions.getworkdaysbetween(90,
                                                  t.creation_date,
                                                  SYSDATE) >
             fnd_profile.value('XXPO_SUPP_APP_ESC2_DAYS');
  
  BEGIN
  
    errbuff := '';
    errcode := 0;
  
    FOR i IN c LOOP
      BEGIN
      
        send_mail(p_vendor_id      => i.vendor_id,
                  p_created_by     => i.created_by,
                  p_supplier_name  => i.vendor_name,
                  p_old_status     => i.old_status,
                  p_new_status     => i.status,
                  p_history_ind    => 'N',
                  p_subject_prefix => 'Reminder: ');
      
        -- xxobjt_debug_proc(p_message1 => l_err_message);
        UPDATE xxpo_supplier_approval_his t
           SET t.esc_date1 = SYSDATE, t.last_update_date = SYSDATE
         WHERE t.vendor_id = i.vendor_id
           AND t.last_ind = 'Y';
      
        fnd_file.put_line(fnd_file.log,
                          'User Alert for vendor:' || i.vendor_name ||
                          ' Status=' || i.status);
      
        COMMIT;
      
      EXCEPTION
        WHEN OTHERS THEN
          errbuff := SQLERRM;
          errcode := 2;
      END;
    END LOOP;
  
    FOR i IN c_mgr LOOP
      BEGIN
      
        send_mail(p_vendor_id      => i.vendor_id,
                  p_created_by     => i.created_by,
                  p_supplier_name  => i.vendor_name,
                  p_old_status     => i.old_status,
                  p_new_status     => i.status,
                  p_history_ind    => 'N',
                  p_dist_role_name => fnd_profile.value('XXPO_SUPP_APP_ESC2_ROLE'), --'POS:71063',
                  p_subject_prefix => 'Reminder: ');
      
        UPDATE xxpo_supplier_approval_his t
           SET t.esc_date2 = SYSDATE, t.last_update_date = SYSDATE
         WHERE t.vendor_id = i.vendor_id
           AND t.last_ind = 'Y';
        fnd_file.put_line(fnd_file.log,
                          'Mgr Alert for vendor:' || i.vendor_name ||
                          ' Send to ' ||
                          fnd_profile.value('XXPO_SUPP_APP_ESC2_ROLE'));
      
        COMMIT;
      EXCEPTION
        WHEN OTHERS THEN
          errbuff := SQLERRM;
          errcode := 2;
      END;
    END LOOP;
  EXCEPTION
    WHEN OTHERS THEN
      errbuff := SQLERRM;
      errcode := 2;
  END;

END xxpo_supplier_approval_pkg;
/
