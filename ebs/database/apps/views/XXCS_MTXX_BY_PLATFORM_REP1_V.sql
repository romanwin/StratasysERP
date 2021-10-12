CREATE OR REPLACE VIEW XXCS_MTXX_BY_PLATFORM_REP1_V AS
SELECT
--------------------------------------------------------------------
--  name:            XXCS_MTXX_BY_PLATFORM_REP1_V
--  create by:       Roman Vaintraub
--  Revision:        1.0
--  creation date:   17/10/2011
--------------------------------------------------------------------
--  purpose :        Discoverer Report
--------------------------------------------------------------------
--  ver  date        name             desc
--  1.0  17/10/2011  Roman V.         initial build
--------------------------------------------------------------------
        t.operating_unit_party,
        t.platform,
        t.type,
        r.CS_Region_group,
        SUM(nvl(t.mtbc,0)) NUMBER_OF_CALLS_MTBC,
        SUM(nvl(t.mtbd,0)) NUMBER_OF_CALLS_MTBD,
        SUM(nvl(t.mtbv,0)) NUMBER_OF_CALLS_MTBV,
        SUM(nvl(t.mttr,0)) NUMBER_OF_CALLS_MTTR,
        COUNT(DISTINCT t.instance_id) NUMBER_OF_PRINTERS,
        SUM(nvl(t.labor_hours,0)) LABOR_HOURS,
        SUM(t.effective_ib) EFF_IB,
----------------MTBC------------------------------------------------------------------------
        decode(SUM(t.effective_ib),0,0,
               SUM(nvl(t.mtbc,0))/SUM(t.effective_ib))*AVG(t.factor_year) AVG_PER_SYS_PER_YEAR_MTBC,
        decode (decode(SUM(t.effective_ib),0,0,
               SUM(nvl(t.mtbc,0))/SUM(t.effective_ib))*AVG(t.factor_year),0,0,365/(decode(SUM(t.effective_ib),0,0,
               SUM(nvl(t.mtbc,0))/SUM(t.effective_ib))*AVG(t.factor_year))) MTBC,
---------------MTBD------------------------------------------------------------------------
        decode(SUM(t.effective_ib),0,0,
               SUM(nvl(t.mtbd,0))/SUM(t.effective_ib))*AVG(t.factor_year) AVG_PER_SYS_PER_YEAR_MTBD,
        decode (decode(SUM(t.effective_ib),0,0,
               SUM(nvl(t.mtbd,0))/SUM(t.effective_ib))*AVG(t.factor_year),0,0,365/(decode(SUM(t.effective_ib),0,0,
               SUM(nvl(t.mtbd,0))/SUM(t.effective_ib))*AVG(t.factor_year))) MTBD,
----------------MTBV------------------------------------------------------------------------
        decode(SUM(t.effective_ib),0,0,
               SUM(nvl(t.mtbv,0))/SUM(t.effective_ib))*AVG(t.factor_year) AVG_PER_SYS_PER_YEAR_MTBV,
        decode (decode(SUM(t.effective_ib),0,0,
               SUM(nvl(t.mtbv,0))/SUM(t.effective_ib))*AVG(t.factor_year),0,0,365/(decode(SUM(t.effective_ib),0,0,
               SUM(nvl(t.mtbv,0))/SUM(t.effective_ib))*AVG(t.factor_year))) MTBV,
---------------MTTR-------------------------------------------------------------------------
        decode(SUM(t.effective_ib),0,0,
               SUM(nvl(t.mttr,0))/SUM(t.effective_ib))*AVG(t.factor_year) AVG_PER_SYS_PER_YEAR_MTTR,
        decode (SUM(nvl(t.mttr,0)),0,0,
                SUM(nvl(t.labor_hours,0))/SUM(nvl(t.mttr,0))) MTTR
--------------------------------------------------------------------------------------------
FROM  XXCS_MTXX_REPORT_DETAILS_V t, xxcs_regions_v r
------------------------------------------------------------------------
WHERE t.cs_region = r.CS_Region
-------------------------------------------------------------------------
GROUP BY
      t.operating_unit_party,
      t.platform,
      t.type,
      r.CS_Region_group;
