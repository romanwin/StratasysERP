CREATE OR REPLACE PACKAGE BODY xxobjt_general_utils_pkg IS

  --------------------------------------------------------------------
  --  customization code: CUSTxxx
  --  name:               XXOBJT_GENERAL_UTILS_PKG
  --  create by:          Vitaly K.
  --  $Revision:          1.0
  --  creation date:      06/06/2010
  --  Purpose :           General procedures and functions
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   06/06/2010    Vitaly K.       initial build
  --  1.1   11/08/2010    Yuval tal       Add function get_dist_mail_list
  --  1.2   17/04/2011    yuval tal       add get_valueset_desc
  --  1.3   01/08/2011    Dalit A. Raviv  add function get_alert_mail_list
  --  1.4   11/10/2011    yuval tal       add get_valueset_attribute
  --  1.5   17/01/2012    Dalit A. Raviv  procedure get_alert_mail_list add condition
  --  1.6   25/01/2012    Dalit A. Raviv  add function: find_string_in_long,
  --                                                    get_exist_string_in_alert_sql
  --  1.7   24/0/2013     yuval tal       modify get_valueset_desc
  --  1.8   03/11/2013    yuval tal       Add get_user_id
  --  1.9   25/12/2013    Dalit A. Raviv  add function - get_profile_value

  --  1.10  30/12/2013    yuval tal       CR 1215 : add get_lookup_meaning
  --  2.0   13/03/2014    Sandeep Akula   Added Procedure Insert_mail_audit and Function check_if_email_sent -- CHG0031424
  --  2.1   15.5.2014     yuval tal       CHG0031655 add long_to_char
  --  2.2   12/05/2014    Dalit A. Raviv  add function get_from_mail, am_i_in_production
  --  2.3   21/09/2014    Dalit A. Raviv  add function is_open_user
  --  2.4   16.11.2014    yuval tal       CHG0033847 :add is_mail_valid/validate_mail_list
  --  2.5   06/AUG/2014   Sandeep Akula   Added Parameter p_request_ids to Procedure insert_mail_audit -- CHG0032821  (Reverted this change back due to Issue with CHG0033847 Migration)
  --  2.6   23/MAR/2015   Sandeep Akula   Removed p_request_ids parameter from Procedure insert_mail_audit  -- CHG0034594
  --  2.7   26/05/2015    Michal Tzvik    New function: get_invalid_mail_list
  --  2.8   22/07/2015    Michal Tzvik    CHG0035863 - New function: is_file_exist
  --  2.9   01/SEP/2015   Dalit A. RAviv  CHG0036084 - Filament Stock in Stock out
  --                                                      add 2 procedures - print_log, print_out
  --  3.0   01-JAN-2016   Diptasurjya     CHG0036659 - Added functions get_ecomm_alert_to_emails and get_ecomm_alert_cc_emails
  --                      Chatterjee      to return email id for ecom event alerts
  -- 3.1   11.7.16        yuval tal      INC0072108 - modify is_mail_valid , get_invalid_mail_list add trim
  -- 3.1   10.10.16        yuval tal      INC0078059 - modify is_mail_valid  allow suffix of 2-4 chars
  -- 3.2   20-OCT-2020    Diptasurjya     INC0209747 - modify is_mail_valid  allow suffix of 2-5 chars
  -----------------------------------------------------------------------

  --------------------------------------------------------------------
  --  customization code:
  --  name:               get_user_id
  --  create by:          yuval tal
  --  $Revision:          1.0
  --  creation date:      3.11.13
  --  Purpose :  get user id for user name
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   06/06/2010    Vitaly K.       initial build
  -----------------------------------------------------------------------

  FUNCTION get_user_id(p_user_name VARCHAR2) RETURN NUMBER IS
    l_tmp NUMBER;
  BEGIN
    SELECT user_id
    INTO   l_tmp
    FROM   fnd_user
    WHERE  user_name = p_user_name;
    RETURN l_tmp;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;

  END;

  --------------------------------------------------------------------
  --  customization code: CUSTxxx
  --  name:               get_profile_specific_value
  --  create by:          Vitaly K.
  --  $Revision:          1.0
  --  creation date:      06/06/2010
  --  Purpose :           function that get profile short name and profile level
  --                      and return profile value at this level
  --                      p_profile_level = 10001  ---Application level
  --                      p_profile_level = 10002  ---Site level
  --                      p_profile_level = 10003  ---Responsibility level
  --                      p_profile_level = 10004  ---User level
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   06/06/2010    Vitaly K.       initial build
  -----------------------------------------------------------------------
  FUNCTION get_profile_specific_value(p_profile_short_name IN VARCHAR2,
			  p_profile_level      IN NUMBER)
    RETURN VARCHAR2 IS
    ----p_profile_level = 10001  ---Application level
    ----p_profile_level = 10002  ---Site level
    ----p_profile_level = 10003  ---Responsibility level
    ----p_profile_level = 10004  ---User level
    v_level_value   NUMBER;
    v_profile_value VARCHAR2(300);
  BEGIN

    IF p_profile_short_name IS NULL OR p_profile_level IS NULL OR
       p_profile_level NOT IN (10001, 10002, 10003, 10004) THEN
      RETURN NULL;
    END IF;
    IF p_profile_level = 10001 /*Application level*/
     THEN
      v_level_value := fnd_profile.value('APPLICATION_ID');
    ELSIF p_profile_level = 10002 /*Site level*/
     THEN
      v_level_value := fnd_global.org_id;
    ELSIF p_profile_level = 10003 /*Responsibility level*/
     THEN
      v_level_value := fnd_global.resp_id;
    ELSIF p_profile_level = 10004 /*User level*/
     THEN
      v_level_value := fnd_global.user_id;
    END IF;

    SELECT fpov.profile_option_value
    INTO   v_profile_value
    FROM   fnd_profile_option_values fpov,
           fnd_profile_options_tl    fpot,
           fnd_profile_options       fpo
    WHERE  fpov.level_id = p_profile_level ---parameter
    AND    fpov.level_value = v_level_value
          ---------AND   FPOT.user_profile_option_name ='XX: VPD Security Enabled'
          ---------AND   FPO.profile_option_name='XXCS_VPD_SECURITY_ENABLED'
    AND    fpo.profile_option_name = p_profile_short_name ---parameter
    AND    fpo.profile_option_id = fpov.profile_option_id
    AND    fpo.profile_option_name = fpot.profile_option_name
    AND    fpov.application_id = fpo.application_id
    AND    fpot.language = 'US';

    RETURN v_profile_value;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_profile_specific_value;

  --------------------------------------------------------------------
  --  customization code:
  --  name:               get_dist_mail_list
  --  create by:          Yuval Tal
  --  $Revision:          1.0
  --  creation date:      11/08/2010
  --  Description:
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   11/08/2010    Yuval Tal       initial build
  --------------------------------------------------------------------
  FUNCTION get_dist_mail_list(p_operating_unit     NUMBER,
		      p_program_short_name VARCHAR2) RETURN VARCHAR2 IS

    CURSOR c_list IS
      SELECT *
      FROM   xxobjt_mail_list_v t
      WHERE  nvl(t.operating_unit, '-1') = nvl(p_operating_unit, '-1')
      AND    t.program_short_name = p_program_short_name;

    l_mail_list VARCHAR2(500) := NULL;

  BEGIN
    FOR i IN c_list LOOP

      l_mail_list := l_mail_list || i.email || ';';

    END LOOP;
    RETURN rtrim(l_mail_list, ';');

  END get_dist_mail_list;

  ------------------------------------
  -- get_valueset_desc
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   11/08/2010    Yuval Tal       ADD p_mode : ALL = ignore enable flag /ACTIVE  only enable
  --------------------------------------------------------------------

  FUNCTION get_valueset_desc(p_set_code VARCHAR2,
		     p_code     VARCHAR2,
		     p_mode     VARCHAR2 DEFAULT 'ALL')

   RETURN VARCHAR2 IS

    CURSOR c IS
      SELECT p.description
      FROM   fnd_flex_values_vl  p,
	 fnd_flex_value_sets vs
      WHERE  flex_value = p_code
      AND    p.flex_value_set_id = vs.flex_value_set_id
      AND    vs.flex_value_set_name = p_set_code
      AND    ((nvl(p.enabled_flag, 'N') = 'Y' AND p_mode = 'ACTIVE') OR
	p_mode = 'ALL');
    l_tmp VARCHAR2(200);

  BEGIN

    OPEN c;
    FETCH c
      INTO l_tmp;
    CLOSE c;

    RETURN l_tmp;
  END;

  --------------------------------------------------------------------
  --  customization code:
  --  name:               get_alert_mail_list
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      01/08/2011
  --  Description:        Value set that hold by alert name the mail list of the people
  --                      who need to get this mail.
  --                      this give flexsibility of setup.
  --                      for test p_alert_name XXHR_EMP_TERMINATION_NOTIF
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   01/08/2011    Dalit A. Raviv  initial build
  --  1.1   17/01/2012    Dalit A. Raviv  correct position list select not to
  --                                      retrieve Ex-Employee Ex-Continget worker  get_alert_mail_list
  --------------------------------------------------------------------
  FUNCTION get_alert_mail_list(p_alert_name VARCHAR2,
		       p_separator  VARCHAR2 DEFAULT ';')
    RETURN VARCHAR2 IS
    -- Get alert mail list from value set
    CURSOR list_c IS
      SELECT ffv.flex_value_set_name,
	 ffv.flex_value_set_id,
	 t.flex_value_id,
	 t.flex_value,
	 t.description           email, -- position or Email address
	 t.attribute3            alert_name,
	 t.attribute4            list_type
      FROM   fnd_flex_values_vl  t,
	 fnd_flex_value_sets ffv
      WHERE  ffv.flex_value_set_id = t.flex_value_set_id
      AND    ffv.flex_value_set_name = 'XX_SEND_MAIL'
      AND    t.enabled_flag = 'Y'
      AND    trunc(SYSDATE) BETWEEN nvl(t.start_date_active, SYSDATE - 1) AND
	 nvl(t.end_date_active, SYSDATE + 1)
      AND    t.attribute3 = p_alert_name;
    -- get all people email that hold the same position
    CURSOR position_list_c(p_position_name VARCHAR2) IS
      SELECT papf.email_address
      FROM   per_all_people_f      papf,
	 per_all_assignments_f paa
      WHERE  papf.person_id = paa.person_id
      AND    trunc(SYSDATE) BETWEEN papf.effective_start_date AND
	 papf.effective_end_date
      AND    trunc(SYSDATE) BETWEEN paa.effective_start_date AND
	 paa.effective_end_date
      AND    hr_person_type_usage_info.get_user_person_type(trunc(SYSDATE),
					papf.person_id) NOT LIKE
	 'Ex%'
      AND    decode(paa.position_id,
	        NULL,
	        NULL,
	        xxhr_util_pkg.get_position_name(paa.person_id)) =
	 p_position_name;
    l_mail_list VARCHAR2(1500) := NULL;
    --l_mail      varchar2(240)  := null;

  BEGIN
    FOR list_r IN list_c LOOP
      IF list_r.list_type = 'Email' THEN
        l_mail_list := l_mail_list || list_r.email || p_separator;
      ELSIF list_r.list_type = 'Position' THEN
        FOR position_list_r IN position_list_c(list_r.email) LOOP
          l_mail_list := l_mail_list || position_list_r.email_address ||
		 p_separator;
        END LOOP;
      END IF;
    END LOOP;
    RETURN rtrim(l_mail_list, p_separator);

  END get_alert_mail_list;

  -------------------------------------
  -- get_valueset_attribute
  -------------------------------------
  FUNCTION get_valueset_attribute(p_set_code       VARCHAR2,
		          p_code           VARCHAR2,
		          p_attribute_name VARCHAR2) RETURN VARCHAR2 IS
    CURSOR c IS
      SELECT CASE upper(p_attribute_name)
	   WHEN 'ATTRIBUTE1' THEN
	    p.attribute1
	   WHEN 'ATTRIBUTE2' THEN
	    p.attribute2
	   WHEN 'ATTRIBUTE3' THEN
	    p.attribute3
	   WHEN 'ATTRIBUTE4' THEN
	    p.attribute4
	   WHEN 'ATTRIBUTE5' THEN
	    p.attribute5
	   WHEN 'ATTRIBUTE6' THEN
	    p.attribute6
	   WHEN 'ATTRIBUTE7' THEN
	    p.attribute7
	   WHEN 'ATTRIBUTE8' THEN
	    p.attribute8
	   WHEN 'ATTRIBUTE9' THEN
	    p.attribute9
	   WHEN 'ATTRIBUTE10' THEN
	    p.attribute10
	   WHEN 'ATTRIBUTE11' THEN
	    p.attribute11
	   WHEN 'ATTRIBUTE12' THEN
	    p.attribute12
	   WHEN 'ATTRIBUTE13' THEN
	    p.attribute13
	   WHEN 'ATTRIBUTE14' THEN
	    p.attribute14
	   WHEN 'ATTRIBUTE15' THEN
	    p.attribute15
	 END CASE
      FROM   fnd_flex_values_vl  p,
	 fnd_flex_value_sets vs
      WHERE  flex_value = p_code
      AND    p.flex_value_set_id = vs.flex_value_set_id
      AND    vs.flex_value_set_name = p_set_code;
    l_tmp VARCHAR2(240);

  BEGIN

    OPEN c;
    FETCH c
      INTO l_tmp;
    CLOSE c;

    RETURN l_tmp;
  END;

  ---------------------------------------------------------------------
  -- get_lookup_attribute
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   30.12.13      yuval tal       initial build
  ---------------------------------------------------------------------
  FUNCTION get_lookup_meaning(p_lookup_type      VARCHAR2,
		      p_lookup_code      VARCHAR2,
		      p_description_flag VARCHAR2 DEFAULT 'N')
    RETURN VARCHAR2 IS

    l_tmp VARCHAR2(200);

    CURSOR c IS
      SELECT decode(p_description_flag, 'Y', p.description, p.meaning)
      FROM   fnd_lookup_values_vl p
      WHERE  p.lookup_type = p_lookup_type
      AND    p.lookup_code = p_lookup_code;

  BEGIN

    OPEN c;
    FETCH c
      INTO l_tmp;
    CLOSE c;

    RETURN l_tmp;
  END;

  -------------------------------------
  -- GET_LOOKUP_ATTRIBUTE
  -------------------------------------
  FUNCTION get_lookup_attribute(p_lookup_type        VARCHAR2,
		        p_lookup_code        VARCHAR2 DEFAULT NULL,
		        p_lookup_description VARCHAR2 DEFAULT NULL,
		        p_attribute_name     VARCHAR2)
    RETURN VARCHAR2 IS
    CURSOR c IS
      SELECT CASE upper(p_attribute_name)
	   WHEN 'ATTRIBUTE1' THEN
	    p.attribute1
	   WHEN 'ATTRIBUTE2' THEN
	    p.attribute2
	   WHEN 'ATTRIBUTE3' THEN
	    p.attribute3
	   WHEN 'ATTRIBUTE4' THEN
	    p.attribute4
	   WHEN 'ATTRIBUTE5' THEN
	    p.attribute5
	   WHEN 'ATTRIBUTE6' THEN
	    p.attribute6
	   WHEN 'ATTRIBUTE7' THEN
	    p.attribute7
	   WHEN 'ATTRIBUTE8' THEN
	    p.attribute8
	   WHEN 'ATTRIBUTE9' THEN
	    p.attribute9
	   WHEN 'ATTRIBUTE10' THEN
	    p.attribute10
	   WHEN 'ATTRIBUTE11' THEN
	    p.attribute11
	   WHEN 'ATTRIBUTE12' THEN
	    p.attribute12
	   WHEN 'ATTRIBUTE13' THEN
	    p.attribute13
	   WHEN 'ATTRIBUTE14' THEN
	    p.attribute14
	   WHEN 'ATTRIBUTE15' THEN
	    p.attribute15
	 END CASE
      FROM   fnd_lookup_values_vl p
      WHERE  p.lookup_type = p_lookup_type
      AND    (p.lookup_code = p_lookup_code OR
	p.description = p_lookup_description);
    l_tmp VARCHAR2(200);

  BEGIN

    OPEN c;
    FETCH c
      INTO l_tmp;
    CLOSE c;

    RETURN l_tmp;
  END;

  --------------------------------------------------------------------
  --  customization code:
  --  name:               find_string_in_long
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      25/01/2012
  --  Description:        Look for string in Long Variable
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   25/01/2012    Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  FUNCTION find_string_in_long(p_long   LONG,
		       p_string VARCHAR2) RETURN NUMBER IS

  BEGIN
    -- If p_string is not found in p_long, then the instr function will return 0.
    -- If found the return number of the first occurrence of the search string.
    RETURN instr(upper(p_long), upper(p_string));
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 0;
  END find_string_in_long;

  --------------------------------------------------------------------
  --  customization code:
  --  name:               get_exist_string_in_long
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      25/01/2012
  --  Description:        Look for string in Long Variable
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   25/01/2012    Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  FUNCTION get_exist_string_in_alert_sql(p_alert_name IN VARCHAR2,
			     p_string     IN VARCHAR2)
    RETURN VARCHAR2 IS
    l_result NUMBER;

    CURSOR alert_c IS
      SELECT aa.alert_id,
	 aa.alert_name,
	 aa.description,
	 aa.sql_statement_text
      FROM   alr_alerts aa
      WHERE  aa.alert_name = p_alert_name;

  BEGIN
    FOR alert_r IN alert_c LOOP
      -- Call the function
      l_result := find_string_in_long(p_long   => upper(alert_r.sql_statement_text),
			  p_string => upper(p_string));
      IF l_result <> 0 THEN
        --dbms_output.put_line('Alert    '||alert_r.alert_name||' - '||alert_r.description);
        --dbms_output.put_line('l_result '||l_result);
        RETURN 'Y';
      ELSE
        RETURN 'N';
      END IF;
    END LOOP;
  END get_exist_string_in_alert_sql;

  --------------------------------------------------------------------
  --  customization code:
  --  name:               get_profile_value
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      25/12/2013
  --  Description:        Get profile value by level
  --                      p_profile_option_name -> profile name (system)
  --                      p_level_type          -> Site, Application,Responsibility, Server, Organization , USER
  --                      p_level_id            -> Site= -1, application_id, responsibility_id, server_id, organization_id, user_id
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   25/12/2013    Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  FUNCTION get_profile_value(p_profile_option_name IN VARCHAR2,
		     p_level_type          IN VARCHAR2,
		     p_level_id            IN NUMBER) RETURN VARCHAR2 IS

    l_profile_value VARCHAR2(240) := NULL;

  BEGIN
    IF upper(p_level_type) = 'SITE' THEN
      SELECT profile_value
      INTO   l_profile_value
      FROM   xxobjt_profiles_v p
      WHERE  p.profile_option_name = p_profile_option_name
      AND    upper(p.level_type) = 'SITE';
    ELSE
      SELECT profile_value
      INTO   l_profile_value
      FROM   xxobjt_profiles_v p
      WHERE  p.profile_option_name = p_profile_option_name
      AND    upper(p.level_type) = upper(p_level_type)
      AND    p.level_id = p_level_id;
    END IF;

    RETURN l_profile_value;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_profile_value;

  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Function Name:    check_if_email_sent
  Author's Name:   Sandeep Akula
  Date Written:    13-MARCH-2014
  Purpose:         Checks if mail was sent previously for a particular source by checking data loaded in table xxobjt_mail_audit
  Program Style:   Function Definition
  Called From:     Called in After Report Trigger of Report "XX SSUS: Packing List Report PDF Output via Mail"
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  13-MARCH-2014        1.0                  Sandeep Akula     Initial Version -- CHG0031424
  ---------------------------------------------------------------------------------------------------*/
  FUNCTION check_if_email_sent(p_source      IN VARCHAR2,
		       p_email       IN VARCHAR2 DEFAULT NULL,
		       p_pk1         IN VARCHAR2,
		       p_pk2         IN VARCHAR2 DEFAULT NULL,
		       p_pk3         IN VARCHAR2 DEFAULT NULL,
		       p_ignore_flag IN VARCHAR2 DEFAULT NULL)
    RETURN VARCHAR2 IS

    l_cnt NUMBER := '';

  BEGIN

    BEGIN
      SELECT COUNT(*)
      INTO   l_cnt
      FROM   xxobjt_mail_audit
      WHERE  source_code = p_source
      AND    pk1 = p_pk1
      AND    nvl(pk2, '1') = nvl(p_pk2, '1')
      AND    nvl(pk3, '2') = nvl(p_pk3, '2')
      AND    nvl(ignore_flag, '3') = nvl(p_ignore_flag, '3');
    EXCEPTION
      WHEN OTHERS THEN
        l_cnt := '99';
    END;

    IF l_cnt = '0' THEN
      RETURN('N');
    ELSE
      RETURN('Y');
    END IF;

  END check_if_email_sent;
  --------------------------------------------------------------------------------------------------
  /*
  $Revision:   1.0  $
  Procedure Name:    Insert_mail_audit
  Author's Name:   Sandeep Akula
  Date Written:    13-MARCH-2014
  Purpose:         Insert Mail Audit data into table xxobjt_mail_audit
  Program Style:   Procedure Definition (Pragma AUTONOMOUS Transaction)
  Called From:     Called in After Report Trigger of Report "XX SSUS: Packing List Report PDF Output via Mail"
  Calls To:
  Maintenance History:
  Date:          Version                   Name            Remarks
  -----------    ----------------         -------------   ------------------
  13-MARCH-2014        1.0                  Sandeep Akula     Initial Version -- CHG0031424
  06-AUG-2014          1.1                  Sandeep Akula     Added Parameter p_request_ids to Procedure insert_mail_audit -- CHG0032821 (Reverted this change back due to Issue with CHG0033847 Migration)
  23-MARCH-2015        1.2                  Sandeep Akula     Removed p_request_ids parameter -- CHG0034594
  ---------------------------------------------------------------------------------------------------*/
  PROCEDURE insert_mail_audit(p_source      IN VARCHAR2,
		      p_email       IN VARCHAR2 DEFAULT NULL,
		      p_pk1         IN VARCHAR2,
		      p_pk2         IN VARCHAR2 DEFAULT NULL,
		      p_pk3         IN VARCHAR2 DEFAULT NULL,
		      p_ignore_flag IN VARCHAR2 DEFAULT NULL
		      --p_request_ids IN VARCHAR2 DEFAULT NULL
		      ) IS
    PRAGMA AUTONOMOUS_TRANSACTION;

  BEGIN

    BEGIN

      INSERT INTO xxobjt_mail_audit
        (source_code,
         email,
         creation_date,
         created_by,
         pk1,
         pk2,
         pk3,
         ignore_flag
         --request_ids
         )
      VALUES
        (p_source,
         p_email,
         SYSDATE,
         fnd_global.user_id,
         p_pk1,
         p_pk2,
         p_pk3,
         p_ignore_flag
         --p_request_ids
         );
    EXCEPTION
      WHEN OTHERS THEN
        NULL;
    END;
    COMMIT;
  END insert_mail_audit;

  --------------------------------------------------------------------
  --  customization code:
  --  name:               long_to_char
  --  create by:          yuval tal
  --  $Revision:          1.0
  --  creation date:      7.5.14
  --  Description:        convert long to char

  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   7.5.14        yuval tal       initial build - change CHG0031655
  --------------------------------------------------------------------
  FUNCTION long_to_char(in_table_name  VARCHAR,
		in_column      VARCHAR2,
		in_column_name VARCHAR2,
		in_column_val  VARCHAR2) RETURN VARCHAR AS
    text_c1 VARCHAR2(32767);
    sql_cur VARCHAR2(2000);
  BEGIN
    IF in_column_val IS NULL THEN
      RETURN NULL;
    END IF;
    sql_cur := 'select ' || in_column || ' from ' || in_table_name ||
	   ' where ' || in_column_name || '=' || in_column_val;
    -- dbms_output.put_line(sql_cur);
    EXECUTE IMMEDIATE sql_cur
      INTO text_c1;
    text_c1 := substr(text_c1, 1, 4000);
    RETURN text_c1;
  END;

  --------------------------------------------------------------------
  --  customization code:
  --  name:               am_i_in_production
  --  create by:          Dalit a. Raviv
  --  $Revision:          1.0
  --  creation date:      26/05/2014
  --  Description:        function that check if the environment is production
  --                      Return Y if Production, else N
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   26/05/2014    Dalit a. Raviv  initial build
  --------------------------------------------------------------------
  FUNCTION am_i_in_production RETURN VARCHAR2 IS
    l_db VARCHAR2(10) := NULL;
  BEGIN

    SELECT sys_context('userenv', 'db_name')
    INTO   l_db
    FROM   dual;

    IF l_db = 'PROD' THEN
      RETURN 'Y';
    ELSE
      RETURN 'N';
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'N';
  END am_i_in_production;

  --------------------------------------------------------------------
  --  customization code:
  --  name:               get_from_mail
  --  create by:          Dalit a. Raviv
  --  $Revision:          1.0
  --  creation date:      12/05/2014
  --  Description:
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   12/05/2014    Dalit a. Raviv  initial build
  --------------------------------------------------------------------
  FUNCTION get_from_mail(p_from_mailbox VARCHAR2 DEFAULT NULL)
    RETURN VARCHAR2 IS
    l_db        VARCHAR2(50) := NULL;
    l_from_mail VARCHAR2(150) := NULL;
    l_prod      VARCHAR2(10) := 'N';
  BEGIN

    SELECT sys_context('userenv', 'db_name')
    INTO   l_db
    FROM   dual;
    l_prod := am_i_in_production;

    --IF l_db = 'PROD' THEN
    IF l_prod = 'Y' THEN
      l_from_mail := nvl(p_from_mailbox,
		 fnd_profile.value('XXSSYS_FROM_MAIL_PROD')); --'Stratasys_DoNotReply@stratasys.com';
    ELSE
      l_from_mail := l_db || '_' ||
	         fnd_profile.value('XXSSYS_FROM_MAIL_DEV'); -- -
    END IF;
    RETURN l_from_mail;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN 'oradev@objet.com';
  END get_from_mail;

  --------------------------------------------------------------------
  --  customization code:
  --  name:               is_open_user
  --  create by:          Dalit a. Raviv
  --  $Revision:          1.0
  --  creation date:      21/09/2014
  --  Description:        check if user is open - use for WF
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   21/09/2014    Dalit a. Raviv  initial build
  --------------------------------------------------------------------
  FUNCTION is_open_user(p_user_name IN VARCHAR2,
		p_user_id   IN NUMBER) RETURN VARCHAR2 IS
    l_open VARCHAR2(10) := 'N';
  BEGIN
    IF p_user_name IS NOT NULL THEN
      SELECT 'Y'
      INTO   l_open
      FROM   fnd_user fu
      WHERE  fu.user_name = p_user_name
      AND    (fu.end_date IS NULL OR fu.end_date > trunc(SYSDATE));
    ELSIF p_user_id IS NOT NULL THEN
      SELECT 'Y'
      INTO   l_open
      FROM   fnd_user fu
      WHERE  fu.user_id = p_user_id
      AND    (fu.end_date IS NULL OR fu.end_date > trunc(SYSDATE));
    END IF;

    RETURN l_open;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN 'N';
    WHEN OTHERS THEN
      RETURN 'N';
  END is_open_user;

  --------------------------------------------------------------------
  --  customization code: CHG0033847
  --  name:    is_mail_valid
  --  create by:          yuval tal
  --  $Revision:          1.0
  --  creation date:      21/09/2014
  --  Description:        validate mail
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   16.11.2014    yuval tal       initial build
  -- 1.1    11.7.16       yuval tal       INC0072108 - add trim , Validate email address in Ack emailShip email DFF's at the SO header
  --  1.2   10.10.16      yuval tal        INC0078059 - allow suffix of 2-4 chars
  --  1.3   20-OCT-2020   Diptasurjya     INC0209747 - Allow suffix of 2-5 characters
  --------------------------------------------------------------------

  FUNCTION is_mail_valid(p_mail VARCHAR2) RETURN VARCHAR2 IS

  BEGIN
    --INC0072108
    --INC0078059
    IF regexp_like(TRIM(p_mail),
	       '^[a-z0-9._-]+@[a-z0-9.-]+\.[a-z]{2,5}$',  -- INC0209747 change from 2-4 to 2-5
	       'i') THEN
      RETURN 'Y';
    ELSE
      RETURN 'N';
    END IF;
  END;

  --------------------------------------------------------------------
  --  customization code:CHG0033847
  --  name:     validate_mail_list
  --  create by:    yuval tal
  --  $Revision:          1.0
  --  creation date:      21/09/2014
  --  Description:        validate mail list
  -- in :
  -- p_mail_list       : concatinated mail list
  -- p_seperator       : mail list seperator
  -- out :
  -- p_is_list_valid     : Y - valid / N - not valid
  -- p_out_valid_mail_list   valid concatinated mail list
  -- p_out_invalid_mail_list invalid concatinated mail list
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   16.11.2014    yuval tal       initial build
  -- 1.1    11.7.16       yuval tal       INC0072108 - add trim
  --------------------------------------------------------------------
  PROCEDURE validate_mail_list(p_mail_list             VARCHAR2,
		       p_seperator             VARCHAR2 DEFAULT ',',
		       p_is_list_valid         OUT VARCHAR2,
		       p_out_valid_mail_list   OUT VARCHAR2,
		       p_out_invalid_mail_list OUT VARCHAR) IS

    CURSOR c_mails IS

      SELECT mail_acc
      FROM   (SELECT regexp_substr(p_mail_list,
		           '[^' || p_seperator || ']+',
		           1,
		           rownum) mail_acc
	  FROM   dual
	  CONNECT BY LEVEL <=
		 length(regexp_replace(p_mail_list,
			           '[^' || p_seperator || ']+')) + 1)
      WHERE  TRIM(mail_acc) IS NOT NULL; --INC0072108

  BEGIN
    p_is_list_valid := 'Y';
    FOR i IN c_mails LOOP

      IF is_mail_valid(i.mail_acc) = 'Y' THEN
        p_out_valid_mail_list := p_out_valid_mail_list || p_seperator ||
		         i.mail_acc;
      ELSE
        p_is_list_valid         := 'N';
        p_out_invalid_mail_list := p_out_invalid_mail_list || p_seperator ||
		           i.mail_acc;
      END IF;
    END LOOP;

    p_out_invalid_mail_list := ltrim(p_out_invalid_mail_list, p_seperator);
    p_out_valid_mail_list   := ltrim(p_out_valid_mail_list, p_seperator);

  END validate_mail_list;

  --------------------------------------------------------------------
  --  customization code:
  --  name:               get_invalid_mail_list
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  creation date:      26.05.2015
  --  Description:        get invalid mail list. if all mail list is valid, return null
  -- in :
  -- p_mail_list       : concatinated mail list
  -- p_seperator       : mail list seperator
  -- return :
  --  invalid concatinated mail list
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   26.05.2015    Michal Tzvik       initial build
  --------------------------------------------------------------------
  FUNCTION get_invalid_mail_list(p_mail_list VARCHAR2,
		         p_seperator VARCHAR2 DEFAULT ',')
    RETURN VARCHAR2

   IS
    l_is_list_valid     VARCHAR2(1);
    l_valid_mail_list   VARCHAR2(1000);
    l_invalid_mail_list VARCHAR2(1000);
  BEGIN

    validate_mail_list(p_mail_list             => p_mail_list, --
	           p_seperator             => p_seperator, --
	           p_is_list_valid         => l_is_list_valid, --
	           p_out_valid_mail_list   => l_valid_mail_list, --
	           p_out_invalid_mail_list => l_invalid_mail_list);

    IF l_is_list_valid = 'Y' THEN
      RETURN NULL;
    ELSE
      RETURN l_invalid_mail_list;
    END IF;

  END get_invalid_mail_list;

  --------------------------------------------------------------------
  --  customization code:
  --  name:               is_file_exist
  --  create by:          Michal Tzvik
  --  $Revision:          1.0
  --  creation date:      22.07.2015
  --  Description:        Check if file exists in the directory
  -- in :
  -- p_directory
  -- p_file_name
  -- return :
  --  Y / N
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   26.05.2015    Michal Tzvik       initial build
  --------------------------------------------------------------------
  FUNCTION is_file_exist(p_directory VARCHAR2,
		 p_file_name VARCHAR2) RETURN VARCHAR2 IS
    v_file_exists BOOLEAN;
    v_file_length NUMBER;
    v_block_size  NUMBER;

  BEGIN

    utl_file.fgetattr(p_directory,
	          p_file_name,
	          v_file_exists,
	          v_file_length,
	          v_block_size);
    IF v_file_exists THEN
      RETURN 'Y';
    ELSE
      RETURN 'N';
      NULL;
    END IF;

  END is_file_exist;

  --------------------------------------------------------------------
  --  name:             print_log
  --  create by:        Dalit A. RAviv
  --  Revision:         1.0
  --  creation date:    24/AUG/2015
  --------------------------------------------------------------------
  --  purpose :         Print message to log - CHG0036084 - Filament Stock in Stock out
  --------------------------------------------------------------------
  --  ver  date         name            desc
  --  1.0  24/AUG/2015  Dalit A. RAviv  initial build
  --------------------------------------------------------------------
  PROCEDURE print_log(p_print_msg VARCHAR2) IS
  BEGIN
    IF fnd_global.conc_request_id = -1 THEN
      dbms_output.put_line(p_print_msg);
    ELSE
      fnd_file.put_line(fnd_file.log, p_print_msg);
    END IF;
  END print_log;

  --------------------------------------------------------------------
  --  name:             print_log
  --  create by:        Dalit A. RAviv
  --  Revision:         1.0
  --  creation date:    24/AUG/2015
  --------------------------------------------------------------------
  --  purpose :         Print message to output - CHG0036084 - Filament Stock in Stock out
  --------------------------------------------------------------------
  --  ver  date         name            desc
  --  1.0  24/AUG/2015  Dalit A. RAviv  initial build
  --------------------------------------------------------------------
  PROCEDURE print_out(p_print_msg VARCHAR2) IS
  BEGIN
    IF fnd_global.conc_request_id = -1 THEN
      dbms_output.put_line(p_print_msg);
    ELSE
      fnd_file.put_line(fnd_file.output, p_print_msg);
    END IF;
  END print_out;

  --------------------------------------------------------------------
  --  name:             get_ecomm_alert_to_emails
  --  create by:        Diptasurjya Chatterjee
  --  Revision:         1.0
  --  creation date:    01/13/2016
  --------------------------------------------------------------------
  --  purpose :         CHG0036659 - Fetch list of to email ids for ecommerce event alert email
  --------------------------------------------------------------------
  --  ver  date         name            desc
  --  1.0  01/13/2016   Diptasurjya     CHG0036659 - initial build
  --------------------------------------------------------------------
  FUNCTION get_ecomm_alert_to_emails(p_event_id NUMBER) RETURN VARCHAR2 IS
    l_email_ids VARCHAR2(2000);
  BEGIN
    SELECT ffvt.description
    INTO   l_email_ids
    FROM   fnd_flex_value_sets ffvs,
           fnd_flex_values     ffv,
           fnd_flex_values_tl  ffvt,
           xxssys_events       a
    WHERE  flex_value_set_name = 'XX_SEND_MAIL' -- Value Set Name
    AND    ffv.flex_value_set_id = ffvs.flex_value_set_id
    AND    ffvt.flex_value_id = ffv.flex_value_id
    AND    ffvs.flex_value_set_id = ffv.flex_value_set_id
    AND    ffvt.language = userenv('LANG')
    AND    ffv.enabled_flag = 'Y'
    AND    ffv.summary_flag = 'N'
    AND    nvl(ffv.attribute1, '-1') =
           nvl(decode(a.entity_name,
	           'ACCOUNT',
	           a.attribute1,
	           'SITE',
	           (SELECT aa.attribute1
		FROM   xxssys_events aa
		WHERE  aa.entity_id = a.attribute1
		AND    aa.entity_name = 'ACCOUNT'
		AND    rownum = 1),
	           'CONTACT',
	           (SELECT aa.attribute1
		FROM   xxssys_events aa
		WHERE  aa.entity_id = a.attribute1
		AND    aa.entity_name = 'ACCOUNT'
		AND    rownum = 1),
	           'CUST_PRINT',
	           (SELECT aa.attribute1
		FROM   xxssys_events aa
		WHERE  aa.entity_id = a.entity_id
		AND    aa.entity_name = 'ACCOUNT'
		AND    rownum = 1),
	           '-1'),
	    '-1')
    AND    ffv.attribute2 = a.target_name
    AND    ffv.attribute3 = decode(a.entity_name,
		           'ACCOUNT',
		           'CUSTOMER',
		           'SITE',
		           'CUSTOMER',
		           'CONTACT',
		           'CUSTOMER',
		           'CUST_PRINT',
		           'CUSTOMER',
		           a.entity_name) || 'TO'
    AND    a.event_id = p_event_id;
    RETURN l_email_ids;
  END;

  --------------------------------------------------------------------
  --  name:             get_ecomm_alert_cc_emails
  --  create by:        Diptasurjya Chatterjee
  --  Revision:         1.0
  --  creation date:    01/13/2016
  --------------------------------------------------------------------
  --  purpose :         CHG0036659 - Fetch list of cc email ids for ecommerce event alert email
  --------------------------------------------------------------------
  --  ver  date         name            desc
  --  1.0  01/13/2016   Diptasurjya     CHG0036659 - initial build
  --------------------------------------------------------------------
  FUNCTION get_ecomm_alert_cc_emails(p_event_id NUMBER) RETURN VARCHAR2 IS
    l_email_ids VARCHAR2(2000);
  BEGIN
    SELECT ffvt.description
    INTO   l_email_ids
    FROM   fnd_flex_value_sets ffvs,
           fnd_flex_values     ffv,
           fnd_flex_values_tl  ffvt,
           xxssys_events       a
    WHERE  flex_value_set_name = 'XX_SEND_MAIL' -- Value Set Name
    AND    ffv.flex_value_set_id = ffvs.flex_value_set_id
    AND    ffvt.flex_value_id = ffv.flex_value_id
    AND    ffvs.flex_value_set_id = ffv.flex_value_set_id
    AND    ffvt.language = userenv('LANG')
    AND    ffv.enabled_flag = 'Y'
    AND    ffv.summary_flag = 'N'
    AND    nvl(ffv.attribute1, '-1') =
           nvl(decode(a.entity_name,
	           'ACCOUNT',
	           a.attribute1,
	           'SITE',
	           (SELECT aa.attribute1
		FROM   xxssys_events aa
		WHERE  aa.entity_id = a.attribute1
		AND    aa.entity_name = 'ACCOUNT'
		AND    rownum = 1),
	           'CONTACT',
	           (SELECT aa.attribute1
		FROM   xxssys_events aa
		WHERE  aa.entity_id = a.attribute1
		AND    aa.entity_name = 'ACCOUNT'
		AND    rownum = 1),
	           'CUST_PRINT',
	           (SELECT aa.attribute1
		FROM   xxssys_events aa
		WHERE  aa.entity_id = a.entity_id
		AND    aa.entity_name = 'ACCOUNT'
		AND    rownum = 1),
	           '-1'),
	    '-1')
    AND    ffv.attribute2 = 'HYBRIS'
    AND    ffv.attribute3 = decode(a.entity_name,
		           'ACCOUNT',
		           'CUSTOMER',
		           'SITE',
		           'CUSTOMER',
		           'CONTACT',
		           'CUSTOMER',
		           'CUST_PRINT',
		           'CUSTOMER',
		           a.entity_name) || 'CC'
    AND    a.event_id = p_event_id;
    RETURN l_email_ids;
  END;

END xxobjt_general_utils_pkg;
/
