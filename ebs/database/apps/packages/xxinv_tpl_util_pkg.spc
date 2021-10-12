CREATE OR REPLACE PACKAGE xxinv_tpl_util_pkg IS
  ------------------------------------------------------------------
  -- $Header: xxinv_tpl_util_pkg   $
  ------------------------------------------------------------------
  -- Package: xxinv_tpl_util_pkg
  -- Created:
  -- Author:  Vitaly
  ------------------------------------------------------------------
  -- Purpose:
  ------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  ----------------------------
  --     1.0  29.10.13   Vitaly         initial build
  ------------------------------------------------------------------

  ---------------------------------------------------------------------------
  -- update_hr_locations
  ---------------------------------------------------------------------------
  -- Purpose: Concurrent program XX INV TPL Sync Location names/XXINVTPLLOC
  ---------------------------------------------------------------------------
  -- Version  Date        Performer       Comments
  ----------  --------    --------------  -----------------------------------
  -- 1.0      07.10.2013  Vitaly          initial build - sync background processes  cr1045
  ---------------------------------------------------------------------------
  PROCEDURE update_hr_locations(errbuf          OUT VARCHAR2,
                                retcode         OUT VARCHAR2,
                                p_days          NUMBER,
                                p_location_code VARCHAR2);

  ---------------------------------------------------------------------------
  -- onhand_compare
  ---------------------------------------------------------------------------
  -- Purpose: This procedure will be called from BPEL process after reading TPL data file
  ---------------------------------------------------------------------------
  -- Version  Date        Performer       Comments
  ----------  --------    --------------  -----------------------------------
  -- 1.0      18.02.2014  Vitaly          initial build - sync background processes  cr1045
  ---------------------------------------------------------------------------
  PROCEDURE onhand_compare(errbuf        OUT VARCHAR2,
                           retcode       OUT VARCHAR2,
                           p_source_code VARCHAR2,
                           p_bpel_id     NUMBER);
END xxinv_tpl_util_pkg;
/
