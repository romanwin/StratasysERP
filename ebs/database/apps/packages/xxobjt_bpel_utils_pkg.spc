CREATE OR REPLACE PACKAGE xxobjt_bpel_utils_pkg IS

  -- Author  : DALIT.RAVIV
  -- Created : 10/20/2010 8:37:11 AM
  -- Purpose :

  --------------------------------------------------------------------
  --  name:            get_jndi_name
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   20/10/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        procedure will get jndi-name by environment.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  20/10/2010  Dalit A. Raviv    initial build
  --  1.1  9.7.2012    yuval tal         add get_bpel_host
  --                                     get_jndi_name :change default logic
  --  1.2  10.3.14     yuval tal         CHG0031404 - add get_bpel_host2
  -- 1.3    19.4.16        yuval tal    CHG0037918 support for new SOA server  add get_bpel_host_new/get_bpel_host_current

  --------------------------------------------------------------------
  FUNCTION get_jndi_name(p_env IN VARCHAR2) RETURN VARCHAR2;
  ----------------------------------------------------------------------
  FUNCTION get_bpel_host_srv2(p_env VARCHAR2 DEFAULT NULL) RETURN VARCHAR2;
  FUNCTION get_bpel_host_srv1(p_env VARCHAR2 DEFAULT NULL) RETURN VARCHAR2;
  FUNCTION get_bpel_env RETURN VARCHAR2;
  --------------------------------------------------------------------
  --  name:            Get_sf_user_pass
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   13/10/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        procedure will get user password for Sales force
  --                   by environment.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  13/10/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE get_sf_user_pass(p_user_name OUT VARCHAR2,
		     p_password  OUT VARCHAR2,
		     p_env       IN OUT VARCHAR2,
		     p_err_code  OUT VARCHAR2,
		     p_err_msg   OUT VARCHAR2);

  --------------------------------------------------------------------
  --  name:            get_sf_endpoint_urls
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   20/10/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        procedure will get endpoint service url and endpoint login url
  --                   for Sales force by environment.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  20/10/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE get_sf_endpoint_urls(p_endpoint_service OUT VARCHAR2,
		         p_endpoint_login   OUT VARCHAR2,
		         p_env              IN OUT VARCHAR2,
		         p_err_code         OUT VARCHAR2,
		         p_err_msg          OUT VARCHAR2);

  --------------------------------------------------------------------
  --  name:            get_sf_login_params
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   20/10/2010 1:30:11 PM
  --------------------------------------------------------------------
  --  purpose :        procedure will get Sales force login params
  --                   by environment.
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  20/10/2010  Dalit A. Raviv    initial build
  --------------------------------------------------------------------
  PROCEDURE get_sf_login_params(p_user_name        OUT VARCHAR2,
		        p_password         OUT VARCHAR2,
		        p_env              OUT VARCHAR2,
		        p_jndi_name        OUT VARCHAR2,
		        p_endpoint_service OUT VARCHAR2,
		        p_endpoint_login   OUT VARCHAR2,
		        p_err_code         OUT VARCHAR2,
		        p_err_msg          OUT VARCHAR2);

  --------------------------------------
  --get_bpel_host
  ---------------------------------------
  FUNCTION get_bpel_host(p_env VARCHAR2 DEFAULT NULL) RETURN VARCHAR2;

  FUNCTION get_bpel_host2(p_env VARCHAR2 DEFAULT NULL) RETURN VARCHAR2;

  --------------------------------------
  --get_bpel_host
  ---------------------------------------
  FUNCTION get_jndi_data_source(p_env IN VARCHAR2 DEFAULT NULL)
    RETURN VARCHAR2;
END xxobjt_bpel_utils_pkg;
/
