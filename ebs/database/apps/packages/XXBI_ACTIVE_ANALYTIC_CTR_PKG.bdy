CREATE OR REPLACE PACKAGE BODY "XXBI_ACTIVE_ANALYTIC_CTR_PKG"
----------------------------------------------------------------------------
-- Ver   When         Who               Description
-- ----  -----------  ---------------   ------------------------------------
-- 1.0   30/04/2019   Roman W.          CHG0045538 - Active Analytic Center
-- 1.1   26.12.2020   yuval tal         CHG0049056-  modify data generation
----------------------------------------------------------------------------
 IS

  ----------------------------------------------------------------------------
  -- Ver   When         Who               Description
  -- ----  -----------  ---------------   ------------------------------------
  -- 1.0   30/04/2019   Roman W.          CHG0045538 - Active Analytic Center

  ----------------------------------------------------------------------------
  PROCEDURE write_log(p_msg IN VARCHAR2) IS
  BEGIN
  
    IF fnd_global.conc_request_id > 0 THEN
      fnd_file.put_line(fnd_file.log, p_msg);
    ELSE
      dbms_output.put_line(p_msg);
    END IF;
  
  END write_log;

  ----------------------------------------------------------------------------
  -- Ver   When         Who               Description
  -- ----  -----------  ---------------   ------------------------------------
  -- 1.0   30/04/2019   Roman W.          CHG0045538 - Active Analytic Center
  -- 1.1   30/04/2019   Roman W.          CHG0045538 - Active Analytic Center
  --                                           XXBI_ACTIVE_ANALYTIC_CTR_TBL@SOURCE_DWH ->
  --                                           XXBI_ACTIVE_ANALYTIC_CTR_T@SOURCE_DWH
  --1.2  26.12.2020     yuval tal         CHG0049056 remove xxssys_events logic , move all logic to dwh procedure
  ----------------------------------------------------------------------------
  PROCEDURE data_generation(errbuf             OUT VARCHAR2,
		    retcode            OUT VARCHAR2,
		    p_action_type_code IN VARCHAR2,
		    p_date_from        IN VARCHAR2,
		    p_date_to          IN VARCHAR2) IS
    ---------------------------
    --   Local Definition
    ---------------------------
  
    l_batch_id  NUMBER;
    l_from_date DATE;
    l_to_date   DATE;
  
    CURSOR c_err IS
      SELECT last_run_msg,
	 --last_run_date,
	 action_type_code
      FROM   xxbi_active_analytic_ctr_t@source_dwh
      WHERE  last_run_status != 0;
  BEGIN
    errbuf  := NULL;
    retcode := '0';
  
    write_log('p_action_type_code :' || p_action_type_code);
    write_log('p_date_from :' || p_date_from);
    write_log('p_date_to :' || p_date_to);
  
    l_from_date := fnd_date.canonical_to_date(p_date_from);
  
    l_to_date := fnd_date.canonical_to_date(p_date_to);
  
    l_batch_id := fnd_global.conc_request_id;
  
    xxbi_active_analytic_data_pkg.populate_aa_events@source_dwh
    
    (errbuf             => errbuf,
     retcode            => retcode,
     p_action_type_code => p_action_type_code,
     p_from_date        => l_from_date,
     p_to_date          => l_to_date,
     p_request_id       => l_batch_id);
    FOR i IN c_err
    LOOP
      retcode := 2;
      write_log(i.action_type_code || ' - ' || i.last_run_msg);
    END LOOP;
  
  EXCEPTION
    WHEN OTHERS THEN
      errbuf  := 'XXSSYS_ACTIVE_ANALYTIC_CTR_PKG.data_generation(' ||
	     p_action_type_code || ',' || p_date_from || ') - ' ||
	     SQLERRM;
      retcode := '2';
  END data_generation;
  ---------------------------------------------------------------------------------------------
-- Ver     When        Who         Description
-- ------  ----------  ----------  ----------------------------------------------------------
-- 1.0     19/05/2019  Roman W.    bi/bi_ActiveAnalyticCenterSetDwhData/ebsGetKey
---------------------------------------------------------------------------------------------
/*PROCEDURE get_key_data(p_entity_name OUT VARCHAR2,
                         p_entity_id   OUT VARCHAR2,
                         p_count       OUT NUMBER) IS
    CURSOR data_cur IS
      SELECT xe.entity_name,
             xe.entity_id,
             COUNT(*) row_count
      FROM   xxobjt.xxssys_events xe
      WHERE  xe.target_name = 'BI_STRATAFORCE'
      AND    xe.status = 'NEW'
      AND    rownum = 1
      GROUP  BY xe.entity_name,
                xe.entity_id;

  BEGIN
    FOR data_ind IN data_cur
    LOOP
      p_entity_name := data_ind.entity_name;
      p_entity_id   := data_ind.entity_id;
      p_count       := data_ind.row_count;
    END LOOP;

  END get_key_data;*/

END xxbi_active_analytic_ctr_pkg;
/
