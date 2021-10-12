CREATE OR REPLACE PACKAGE "XXBI_ACTIVE_ANALYTIC_CTR_PKG"
----------------------------------------------------------------------------
-- Ver   When         Who               Description
-- ----  -----------  ---------------   ------------------------------------
-- 1.0   30/04/2019   Roman W.          CHG0045538 - Active Analytic Center
----------------------------------------------------------------------------
 IS
  g_yes         CONSTANT VARCHAR2(10) := 'Y';
  g_no          CONSTANT VARCHAR2(10) := 'N';
  g_wait        CONSTANT VARCHAR2(10) := 'WAIT';
  g_date_format CONSTANT VARCHAR2(30) := 'YYYY/MM/DD HH24:MI:DD';

  ----------------------------------------------------------------------------
  -- Ver   When         Who               Description
  -- ----  -----------  ---------------   ------------------------------------
  -- 1.0   30/04/2019   Roman W.          CHG0045538 - Active Analytic Center
  ----------------------------------------------------------------------------
  PROCEDURE write_log(p_msg IN VARCHAR2);

  ----------------------------------------------------------------------------
  -- Ver   When         Who               Description
  -- ----  -----------  ---------------   ------------------------------------
  -- 1.0   30/04/2019   Roman W.          CHG0045538 - Active Analytic Center
  ----------------------------------------------------------------------------
  PROCEDURE data_generation(errbuf             OUT VARCHAR2,
		    retcode            OUT VARCHAR2,
		    p_action_type_code IN VARCHAR2,
		    p_date_from        IN VARCHAR2,
		    p_date_to          IN VARCHAR2);

---------------------------------------------------------------------------------------------
-- Ver     When        Who         Description
-- ------  ----------  ----------  ----------------------------------------------------------
-- 1.0     19/05/2019  Roman W.    bi/bi_ActiveAnalyticCenterSetDwhData/ebsGetKey
---------------------------------------------------------------------------------------------
/*PROCEDURE get_key_data(p_entity_name OUT VARCHAR2,
                         p_entity_id   OUT VARCHAR2,
                         p_count       OUT NUMBER);*/

END xxbi_active_analytic_ctr_pkg;
/
