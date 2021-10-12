CREATE OR REPLACE VIEW XXCS_MTXX_AGING_BY_PLATFORM_V AS
SELECT
--------------------------------------------------------------------
--  name:            XXCS_MTXX_AGING_BY_PLATFORM_V
--  create by:       Vitaly
--  Revision:        1.1
--  creation date:   07/07/2010
--------------------------------------------------------------------
--  purpose :        Discoverer Report
--------------------------------------------------------------------
--  ver  date        name             desc
--  1.0  07/07/2010  Vitaly           initial build
--  1.1  22/07/2010  Vitaly           Bug: Distinct was added to NUMBER_OF_PRINTERS calculation
--------------------------------------------------------------------
        t.operating_unit_party,
        t.platform,
        t.type,
        t.cs_region ,
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
FROM  XXCS_MTXX_AGING_DETAILS_V  t
------------------------------------------------------------------------
--WHERE
-------------------------------------------------------------------------
GROUP BY
      t.operating_unit_party,
      t.platform,
      t.type,
      t.cs_region;

