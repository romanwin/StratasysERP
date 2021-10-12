CREATE OR REPLACE PACKAGE xxfnd_profile_pkg IS
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
  PROCEDURE reset_user_profiles(errbuf         OUT VARCHAR2,
                                retcode        OUT VARCHAR2,
                                p_profile_name VARCHAR2,
                                p_user_name    VARCHAR2);
END xxfnd_profile_pkg;
/
