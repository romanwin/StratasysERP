CREATE OR REPLACE PACKAGE BODY xxobjt_bpel_utils_pkg IS

  --------------------------------------------------------------------
  --  name:               xxobjt_bpel_utils_pkg
  --  create by:          yuval tal
  --  Revision:           1.0
  --  creation date:      XX.XX.XXXX
  --  Purpose :
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   XX.XX.XxXX    yuval tal       Initial Build
  --  1.1   10.4.13       yuval tal       add get_jndi_data_source
  --  1.2   10.3.14       yuval tal       CHG0031404 - add get_bpel_host2
  --  1.1   17/06/2015    Dalit A. Raviv  Functions: get_bpel_host2, get_jndi_name
  --                                      CHG0035388 Upgrade bpel 10G to 11G - xxGetSimplFile
  --                                      change logic to support 11g Bpel DEV/ TEST environments

  -- 1.2   19.4.16        yuval tal       CHG0037918 support for new SOA server  add get_bpel_host_new/get_bpel_host_current
  ----------------------------------------------------------------------

  --------------------------------------------------------------------
  --  name:               get_bpel_host
  --  create by:          yuval tal
  --  creation date:      9.7.2012
  --  Purpose :           procedure will get jndi-name by environment.
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   9.7.2012      yuval tal       Initial Build
  ----------------------------------------------------------------------

  FUNCTION get_bpel_host(p_env VARCHAR2 DEFAULT NULL) RETURN VARCHAR2 IS
    l_env       VARCHAR2(30) := NULL;
    l_jndi_name VARCHAR2(150) := NULL;
  BEGIN
    IF p_env IS NULL THEN
      l_env := xxagile_util_pkg.get_bpel_domain;
    ELSE
      l_env := p_env;
    END IF;
  
    CASE
      WHEN l_env = 'production' THEN
        l_jndi_name := fnd_profile.value('XXOBJT_BPEL_HOST_PROD');
      WHEN l_env = 'default' THEN
        l_jndi_name := fnd_profile.value('XXOBJT_BPEL_HOST_DEV');
    END CASE;
    RETURN l_jndi_name;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;
  --------------------------------------------------------------------
  --  name:               get_bpel_env
  --  create by:          yuval tal
  --  creation date:      10.3.14
  --  Purpose :           procedure will get bpel 11G host server
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  -- 1.1   19.4.16        yuval tal       CHG0037918 support for new SOA server 

  ----------------------------------------------------------------------

  FUNCTION get_bpel_env RETURN VARCHAR2 IS
  
    l_database VARCHAR2(20);
  
  BEGIN
  
    SELECT decode(NAME, 'PROD', 'production', 'default')
    INTO   l_database
    FROM   v$database;
  
    RETURN l_database;
  
  END;

  --------------------------------------------------------------------
  --  name:               get_bpel_host2
  --  create by:          yuval tal
  --  creation date:      10.3.14
  --  Purpose :           procedure will get bpel 11G host server
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  -- 1.1   19.4.16        yuval tal       CHG0037918 support for new SOA server 

  ----------------------------------------------------------------------
  FUNCTION get_bpel_host_srv2(p_env VARCHAR2 DEFAULT NULL) RETURN VARCHAR2 IS
    l_env       VARCHAR2(30) := NULL;
    l_jndi_name VARCHAR2(150) := NULL;
  BEGIN
  
    IF p_env IS NULL THEN
      SELECT NAME --decode(NAME, 'PROD', 'production', 'default')
      INTO   l_env
      FROM   v$database;
      --l_env := xxagile_util_pkg.get_bpel_domain;
    ELSE
      l_env := p_env;
    END IF;
    -- this will souport Bpel server for DEV and TEST
    -- if the test is done from other instances(patch etc) the default is BPel DEV
    CASE
      WHEN l_env = 'PROD' /*'production'*/
       THEN
        l_jndi_name := fnd_profile.value('XXSSYS_BPEL_HOST_PROD_SRV2');
      WHEN l_env = 'TEST' THEN
        l_jndi_name := fnd_profile.value('XXSSYS_BPEL_HOST_TEST_SRV2');
      ELSE
        l_jndi_name := fnd_profile.value('XXSSYS_BPEL_HOST_DEV_SRV2');
    END CASE;
    RETURN l_jndi_name;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;
  --------------------------------------------------------------------
  --  name:               get_bpel_host2
  --  create by:          yuval tal
  --  creation date:      10.3.14
  --  Purpose :           procedure will get bpel 11G host server
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  -- 1.1   19.4.16        yuval tal       CHG0037918 support for new SOA server 

  ----------------------------------------------------------------------
  FUNCTION get_bpel_host_srv1(p_env VARCHAR2 DEFAULT NULL) RETURN VARCHAR2 IS
    l_env       VARCHAR2(30) := NULL;
    l_jndi_name VARCHAR2(150) := NULL;
  BEGIN
  
    RETURN get_bpel_host2(p_env);
  
  END;

  --------------------------------------------------------------------
  --  name:               get_bpel_host2
  --  create by:          yuval tal
  --  creation date:      10.3.14
  --  Purpose :           procedure will get bpel 11G host server
  ----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   10.3.14       yuval tal       Initial Build
  --  1.1   17/06/2015    Dalit A. Raviv  CHG0035388 Upgrade bpel 10G to 11G - xxGetSimplFile
  --                                      change logic to support 11g Bpel DEV/ TEST environments
  ----------------------------------------------------------------------
  FUNCTION get_bpel_host2(p_env VARCHAR2 DEFAULT NULL) RETURN VARCHAR2 IS
    l_env       VARCHAR2(30) := NULL;
    l_jndi_name VARCHAR2(150) := NULL;
  BEGIN
  
    IF p_env IS NULL THEN
      SELECT NAME --decode(NAME, 'PROD', 'production', 'default')
      INTO   l_env
      FROM   v$database;
      --l_env := xxagile_util_pkg.get_bpel_domain;
    ELSE
      l_env := p_env;
    END IF;
    -- this will souport Bpel server for DEV and TEST
    -- if the test is done from other instances(patch etc) the default is BPel DEV
    CASE
      WHEN l_env = 'PROD' /*'production'*/
       THEN
        l_jndi_name := fnd_profile.value('XXOBJT_BPEL_HOST_PROD_11G');
      WHEN l_env = 'TEST' THEN
        l_jndi_name := fnd_profile.value('XXOBJT_BPEL_HOST_TEST_11G');
      ELSE
        l_jndi_name := fnd_profile.value('XXOBJT_BPEL_HOST_DEV_11G');
    END CASE;
    RETURN l_jndi_name;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;

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
  --  1.1  10.7.12     yuval tal         change default logic
  --  1.2  17/06/2015  Dalit A. Raviv    CHG0035388 Upgrade bpel 10G to 11G - xxGetSimplFile
  --                                     change logic to support 11g Bpel DEV/ TEST environments
  --                                     DEv env have different jndi name then all other env.
  --------------------------------------------------------------------
  FUNCTION get_jndi_name(p_env IN VARCHAR2) RETURN VARCHAR2 IS
  
    l_env       VARCHAR2(30) := NULL;
    l_jndi_name VARCHAR2(150) := NULL;
  BEGIN
    IF p_env IS NULL THEN
      SELECT NAME --decode(NAME, 'PROD', 'production', 'default')
      INTO   l_env
      FROM   v$database;
      --l_env := xxagile_util_pkg.get_bpel_domain;
    ELSE
      l_env := p_env;
    END IF;
  
    CASE
      WHEN l_env = 'PROD' /*'production'*/
       THEN
        l_jndi_name := fnd_profile.value('XXOBJT_SF_PRODUCTION_JNDI_NAME');
        --  WHEN l_env = 'DEV' /*'default'*/
    --  THEN
    --  l_jndi_name := 'eis/DB/oa';
      ELSE
        l_jndi_name := 'eis/DB/oa'; -- l_jndi_name := 'eis/DB/' || sys_context('USERENV', 'DB_NAME');
    END CASE;
    RETURN l_jndi_name;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END get_jndi_name;

  --------------------------------------------------------------------
  --  name:            get_jndi_data_source
  --  create by:       yuval tal
  --  Revision:        1.0
  --------------------------------------------------------------------
  --  purpose :        use for bpel xslt transform db connection
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  10.4.13     yuval tal         initial build

  --------------------------------------------------------------------
  FUNCTION get_jndi_data_source(p_env IN VARCHAR2 DEFAULT NULL)
    RETURN VARCHAR2 IS
  
    l_env     VARCHAR2(30) := NULL;
    l_jndi_ds VARCHAR2(150) := NULL;
  BEGIN
    IF p_env IS NULL THEN
      l_env := xxagile_util_pkg.get_bpel_domain;
    ELSE
      l_env := p_env;
    END IF;
  
    CASE
      WHEN l_env = 'production' THEN
        l_jndi_ds := 'jdbc/' || 'PROD_Data_Source';
      WHEN l_env = 'default' THEN
        l_jndi_ds := 'jdbc/' || sys_context('USERENV', 'DB_NAME') ||
	         '_Data_Source';
    END CASE;
    RETURN l_jndi_ds;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;
  END;

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
		     p_err_msg   OUT VARCHAR2) IS
  
    l_env      VARCHAR2(30) := NULL;
    l_user     VARCHAR2(150) := NULL;
    l_password VARCHAR2(150) := NULL;
  
  BEGIN
    IF p_env IS NULL THEN
      l_env := xxagile_util_pkg.get_bpel_domain;
    ELSE
      l_env := p_env;
    END IF;
  
    CASE
      WHEN l_env = 'production' THEN
        l_user     := fnd_profile.value('XXOBJT_SF_PRODUCTION_USER');
        l_password := fnd_profile.value('XXOBJT_SF_PRODUCTION_PASSWORD');
      WHEN l_env = 'default' THEN
        l_user     := fnd_profile.value('XXOBJT_SF_DEFAULT_USER');
        l_password := fnd_profile.value('XXOBJT_SF_DEFAULT_PASSWORD');
    END CASE;
    p_user_name := l_user;
    p_password  := l_password;
    p_env       := l_env;
    p_err_code  := 0;
    p_err_msg   := NULL;
  EXCEPTION
    WHEN OTHERS THEN
      p_user_name := NULL;
      p_password  := NULL;
      p_env       := NULL;
      p_err_code  := 1;
      p_err_msg   := 'GEN EXC - Get_sf_user_pass - ' ||
	         substr(SQLERRM, 1, 240);
    
  END get_sf_user_pass;

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
		         p_err_msg          OUT VARCHAR2) IS
  
    l_env VARCHAR2(30) := NULL;
  
  BEGIN
    IF p_env IS NULL THEN
      l_env := xxagile_util_pkg.get_bpel_domain;
      p_env := l_env;
    ELSE
      l_env := p_env;
    END IF;
    CASE
      WHEN l_env = 'production' THEN
        p_endpoint_service := fnd_profile.value('XXOBJT_SF_PRODUCTION_ENDPOINT_SERVICES_URL');
        p_endpoint_login   := fnd_profile.value('XXOBJT_SF_PRODUCTION_ENDPOINT_LOGIN_URL');
      WHEN l_env = 'default' THEN
        p_endpoint_service := fnd_profile.value('XXOBJT_SF_DEFAULT_ENDPOINT_SERVICES_URL');
        p_endpoint_login   := fnd_profile.value('XXOBJT_SF_DEFAULT_ENDPOINT_LOGIN_URL');
    END CASE;
  
    p_err_code := 0;
    p_err_msg  := NULL;
  EXCEPTION
    WHEN OTHERS THEN
      p_endpoint_service := NULL;
      p_endpoint_login   := NULL;
      p_env              := NULL;
      p_err_code         := 1;
      p_err_msg          := 'GEN EXC - get_sf_endpoint_urls - ' ||
		    substr(SQLERRM, 1, 240);
  END get_sf_endpoint_urls;

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
		        p_err_msg          OUT VARCHAR2) IS
  
    l_env              VARCHAR2(30) := NULL;
    l_user             VARCHAR2(150) := NULL;
    l_password         VARCHAR2(150) := NULL;
    l_err_code         VARCHAR2(20) := NULL;
    l_err_msg          VARCHAR2(1000) := NULL;
    l_endpoint_service VARCHAR2(150) := NULL;
    l_endpoint_login   VARCHAR2(150) := NULL;
  
  BEGIN
    l_env := xxagile_util_pkg.get_bpel_domain;
    -- get user password by env
    get_sf_user_pass(p_user_name => l_user, -- o   v
	         p_password  => l_password, -- o   v
	         p_env       => l_env, -- i/o v
	         p_err_code  => l_err_code, -- o   v
	         p_err_msg   => l_err_msg); -- o   v
    -- get jndi name by env
    p_jndi_name := get_jndi_name(l_env);
  
    -- get endpoint service/login urls by env
    get_sf_endpoint_urls(p_endpoint_service => l_endpoint_service, -- o   v
		 p_endpoint_login   => l_endpoint_login, -- o   v
		 p_env              => l_env, -- i/o v
		 p_err_code         => l_err_code, -- o   v
		 p_err_msg          => l_err_msg); -- o   v
    -- set out params
    p_user_name        := l_user;
    p_password         := l_password;
    p_endpoint_service := l_endpoint_service;
    p_endpoint_login   := l_endpoint_login;
    p_env              := l_env;
    p_err_code         := 0;
    p_err_msg          := NULL;
  
  EXCEPTION
    WHEN OTHERS THEN
      p_user_name        := NULL;
      p_password         := NULL;
      p_endpoint_service := NULL;
      p_endpoint_login   := NULL;
      p_env              := l_env;
      p_jndi_name        := NULL;
      p_err_code         := 1;
      p_err_msg          := 'GEN EXC - Get_sf_login_params - ' ||
		    substr(SQLERRM, 1, 240);
  END get_sf_login_params;

END xxobjt_bpel_utils_pkg;
/
