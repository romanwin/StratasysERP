CREATE OR REPLACE PACKAGE BODY xxfnd_profile_pkg IS
  --------------------------------------------------------------------
  --  customization code: CUST600
  --  name:               XXFND_PROFILE_PKG
  --  create by:          Vitaly
  --  $Revision:          1.0 $
  --  creation date:      17/09/2013
  --  Purpose :           Automatic user profile reset -- CR1032
  ----------------------------------------------------------------------
  --  ver   date          name       desc
  --  1.0   17/09/2013    Vitaly     initial build
  -----------------------------------------------------------------------

  ----------------------------------------------------------------------------
  -- reset_user_profiles
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --  1.3   17/09/2013    Vitaly        initial build CR1032
  PROCEDURE reset_user_profiles(errbuf         OUT VARCHAR2,
                                retcode        OUT VARCHAR2,
                                p_profile_name VARCHAR2,
                                p_user_name    VARCHAR2) IS
  
    v_error_messsage VARCHAR2(5000);
    stop_processing EXCEPTION;
    v_step           VARCHAR2(100);
    v_reset_success  BOOLEAN;
    v_num_of_success NUMBER := 0;
    v_num_of_errors  NUMBER := 0;
  
    CURSOR c_get_profile_and_user_reset IS
      SELECT p.profile_name,
             p.profile_option_name,
             p.level_meaning       user_name,
             p.level_id            user_id
        FROM xxobjt_profiles_v p
       WHERE p.level_type = 'USER'
         AND p.profile_option_name IN
             (SELECT vlp.flex_value reset_profile_name
                FROM fnd_flex_values_vl vlp, fnd_flex_value_sets vsp
               WHERE vsp.flex_value_set_name = 'XXFND_PROFILES_RESET_LIST'
                 AND vsp.flex_value_set_id = vlp.flex_value_set_id
                 AND vlp.enabled_flag = 'Y')
         AND (p.profile_option_name, p.level_meaning) NOT IN
             (SELECT a.parent_value reset_profile_name,
                     a.child_value  exclude_user_name
                FROM xxobjt_flex_dependent_v a
               WHERE a.parent_vs_name = 'XXFND_PROFILES_RESET_LIST'
                 AND a.enabled_flag = 'Y')
       ORDER BY p.profile_name, p.level_meaning;
  
  BEGIN
  
    v_step  := 'Step 0';
    retcode := '0';
    errbuf  := 'Success';
  
    fnd_msg_pub.delete_msg;
  
    fnd_file.put_line(fnd_file.log,
                      '========= Start =======================================');
  
    v_step := 'Step 20';
    FOR profile_rec IN c_get_profile_and_user_reset LOOP
      -------------------LOOP ----------------------------
      ----reset this profile on user level...-------------
      v_step          := 'Step 30';
      v_reset_success := fnd_profile.save(profile_rec.profile_option_name, --short  name
                                          NULL,
                                          'USER',
                                          profile_rec.user_id);
      IF v_reset_success THEN
        ---SUCCESS---
        fnd_file.put_line(fnd_file.log,
                          'Profile ' || profile_rec.profile_name ||
                          ' was successfully reset for user ' ||
                          profile_rec.user_name ||
                          ' **************************');
        v_num_of_success := v_num_of_success + 1;
      ELSE
        ---ERROR-----
        fnd_file.put_line(fnd_file.log,
                          'ERROR when reset profile ' ||
                          profile_rec.profile_name || ' for user ' ||
                          profile_rec.user_name ||
                          ' !!!!!!!!!!!!!!!!!!!!!!!!!!');
        v_num_of_errors := v_num_of_errors + 1;
      END IF;
      --------------the end of LOOP ----------------------
    END LOOP;
    IF v_num_of_success > 0 THEN
      fnd_file.put_line(fnd_file.log,
                        v_num_of_success ||
                        ' successfully reset profile-user ******');
    END IF;
    IF v_num_of_errors > 0 THEN
      fnd_file.put_line(fnd_file.log,
                        v_num_of_errors ||
                        ' ERRORS when update profile-user ******');
    END IF;
    IF v_num_of_success = 0 AND v_num_of_errors = 0 THEN
      fnd_file.put_line(fnd_file.log,
                        'NO PROFILES-USERS for reset. Check Value set XXFND_PROFILES_RESET_LIST ******');
    END IF;
    fnd_file.put_line(fnd_file.log,
                      '========== End ========================================');
  
    IF v_num_of_errors > 0 THEN
      retcode := '2';
      errbuf  := 'ERRORS when update profile-user';
    END IF;
  
  EXCEPTION
    WHEN stop_processing THEN
      v_error_messsage := 'ERROR in xxfnd_profile_pkg.reset_user_profiles: ' ||
                          v_error_messsage;
      fnd_file.put_line(fnd_file.log, '========= ' || v_error_messsage);
      retcode := '2';
      errbuf  := v_error_messsage;
    WHEN OTHERS THEN
      v_error_messsage := substr('Unexpected ERROR in xxfnd_profile_pkg.reset_user_profiles (' ||
                                 v_step || ') ' || SQLERRM,
                                 1,
                                 200);
      fnd_file.put_line(fnd_file.log, '========= ' || v_error_messsage);
      retcode := '2';
      errbuf  := v_error_messsage;
  END reset_user_profiles;
  ------------------------------------------------------------------------------------ 
END xxfnd_profile_pkg;
/
