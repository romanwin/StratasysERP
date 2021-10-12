CREATE OR REPLACE PACKAGE xxobjt_general_utils_pkg AUTHID CURRENT_USER IS
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
  --  1.4   11.10.2011    yuval tal       add get_valueset_attribute
  --  1.5   25/01/2012    Dalit A. Raviv  add function: find_string_in_long,
  --                                      get_exist_string_in_alert_sql
  --  1.6   08/07/2012    yuval tal       add get_lookup_attribute
  --  1.7   27/06/2013    Dalit A. Raviv  Handle HR packages and apps_view
  --                                      add AUTHID CURRENT_USER to spec
  --  1.8   24/0/2013     yuval tal       modify get_valueset_desc
  --  1.9   03/11/2013    YUVAL TAL       CR 1045 Add get_user_id
  --  1.10  25/12/2013    Dalit A. Raviv  add function - get_profile_value
  --  1.11  30/12/2013    yuval tal       CR 1215 Add get_lookup_meaning
  --  2.0   13/03/2014    Sandeep Akula   Added Procedure Insert_mail_audit and Function check_if_email_sent -- CHG0031424
  --  2.1   15.5.2014     yuval tal       CHG0031655 add long_to_char
  --  2.2   12/05/2014    Dalit A. Raviv  add function get_from_mail, am_i_in_production
  --  2.3   21/09/2014    Dalit A. Raviv  add function is_open_user
  --  2.4   16.11.2014    yuval tal       CHG0033847 add is_mail_valid/validate_mail_list
  --  2.5   06/AUG/2014   Sandeep Akula   Added Parameter p_request_ids to Procedure insert_mail_audit -- CHG0032821  (Reverted this change back due to Issue with CHG0033847 Migration)
  --  2.6   23/MAR/2015   Sandeep Akula   Removed p_request_ids parameter from Procedure insert_mail_audit  -- CHG0034594
  --  2.7   26/05/2015    Michal Tzvik    New function: get_invalid_mail_list
  --  2.8   22/07/2015    Michal Tzvik    CHG0035863 - New function: is_file_exist
  --  2.9   01/SEP/2015   Dalit A. RAviv  CHG0036084 - Filament Stock in Stock out
  --                                      add 2 procedures - print_log, print_out
  --  3.0   01-JAN-2016   Diptasurjya     CHG0036659 - Added functions get_ecomm_alert_to_emails and get_ecomm_alert_cc_emails
  --                      Chatterjee      to return email id for ecom event alerts
  -----------------------------------------------------------------------

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
    RETURN VARCHAR2;

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
		      p_program_short_name VARCHAR2) RETURN VARCHAR2;

  FUNCTION get_valueset_desc(p_set_code VARCHAR2,
		     p_code     VARCHAR2,
		     p_mode     VARCHAR2 DEFAULT 'ALL')
    RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  customization code:
  --  name:               get_alert_mail_list
  --  create by:          Dalit A. Raviv
  --  $Revision:          1.0
  --  creation date:      01/08/2011
  --  Description:        Value set that hold by alert name the mail list of the people
  --                      who need to get this mail.
  --                      this give flexsibility of setup.
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   01/08/2011    Dalit A. Raviv  initial build
  --------------------------------------------------------------------
  FUNCTION get_alert_mail_list(p_alert_name VARCHAR2,
		       p_separator  VARCHAR2 DEFAULT ';')
    RETURN VARCHAR2;

  FUNCTION get_valueset_attribute(p_set_code       VARCHAR2,
		          p_code           VARCHAR2,
		          p_attribute_name VARCHAR2) RETURN VARCHAR2;

  FUNCTION get_lookup_attribute(p_lookup_type        VARCHAR2,
		        p_lookup_code        VARCHAR2 DEFAULT NULL,
		        p_lookup_description VARCHAR2 DEFAULT NULL,
		        p_attribute_name     VARCHAR2)
    RETURN VARCHAR2;

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
		       p_string VARCHAR2) RETURN NUMBER;

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
    RETURN VARCHAR2;

  FUNCTION get_user_id(p_user_name VARCHAR2) RETURN NUMBER;
  FUNCTION get_lookup_meaning(p_lookup_type      VARCHAR2,
		      p_lookup_code      VARCHAR2,
		      p_description_flag VARCHAR2 DEFAULT 'N')
    RETURN VARCHAR2;

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
		     p_level_id            IN NUMBER) RETURN VARCHAR2;

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
		in_column_val  VARCHAR2) RETURN VARCHAR;

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
    RETURN VARCHAR2;

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
  06-AUG-2014          1.1                  Sandeep Akula     Added Parameter p_request_ids to Procedure insert_mail_audit -- CHG0032821
  23-MARCH-2015        1.2                  Sandeep Akula     Removed p_request_ids parameter -- CHG0034594
  ---------------------------------------------------------------------------------------------------*/
  PROCEDURE insert_mail_audit(p_source      IN VARCHAR2,
		      p_email       IN VARCHAR2 DEFAULT NULL,
		      p_pk1         IN VARCHAR2,
		      p_pk2         IN VARCHAR2 DEFAULT NULL,
		      p_pk3         IN VARCHAR2 DEFAULT NULL,
		      p_ignore_flag IN VARCHAR2 DEFAULT NULL
		      --p_request_ids IN VARCHAR2 DEFAULT NULL
		      );
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
  FUNCTION am_i_in_production RETURN VARCHAR2;

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
    RETURN VARCHAR2;

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
		p_user_id   IN NUMBER) RETURN VARCHAR2;

  --------------------------------------------------------------------
  --  customization code: CHG3200847
  --  name:    is_mail_valid
  --  create by:          yuval tal
  --  $Revision:          1.0
  --  creation date:      21/09/2014
  --  Description:        validate mail
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   16.11.2014    yuval tal       initial build
  --------------------------------------------------------------------

  FUNCTION is_mail_valid(p_mail VARCHAR2) RETURN VARCHAR2;
  --------------------------------------------------------------------
  --  customization code:CHG3200847
  --  name:     validate_mail_list
  --  create by:    yuval tal
  --  $Revision:          1.0
  --  creation date:      21/09/2014
  --  Description:        validate mail list
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   16.11.2014    yuval tal       initial build
  --------------------------------------------------------------------
  PROCEDURE validate_mail_list(p_mail_list             VARCHAR2,
		       p_seperator             VARCHAR2 DEFAULT ',',
		       p_is_list_valid         OUT VARCHAR2,
		       p_out_valid_mail_list   OUT VARCHAR2,
		       p_out_invalid_mail_list OUT VARCHAR);
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
    RETURN VARCHAR2;

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
		 p_file_name VARCHAR2) RETURN VARCHAR2;

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
  PROCEDURE print_log(p_print_msg VARCHAR2);

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
  PROCEDURE print_out(p_print_msg VARCHAR2);

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
  FUNCTION get_ecomm_alert_to_emails(p_event_id NUMBER) RETURN VARCHAR2;

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
  FUNCTION get_ecomm_alert_cc_emails(p_event_id NUMBER) RETURN VARCHAR2;
END xxobjt_general_utils_pkg;
/
