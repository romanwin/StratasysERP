CREATE OR REPLACE VIEW xxcs_mtxx_by_distribut_rpt1_v AS
SELECT
--------------------------------------------------------------------
--  name:            XXCS_MTXX_BY_DISTRIBUT_RPT1_V
--  create by:       Dalit A. Raviv
--  Revision:        1.2
--  creation date:   08/11/2011
--------------------------------------------------------------------
--  purpose :        Discoverer Report
--                   Data group by CS_Region_group instead of cs_region
--------------------------------------------------------------------
--  ver  date        name             desc
--  1.0  08/11/2011  Dalit A. Raviv   initial build
--------------------------------------------------------------------
        t.operating_unit_party,
        t.type,
        region_gr.CS_Region_group,    --
        t.customer_name,
        SUM(nvl(t.mtbc,0))            NUMBER_OF_CALLS_MTBC,
        SUM(nvl(t.mtbd,0))            NUMBER_OF_CALLS_MTBD,
        SUM(nvl(t.mtbv,0))            NUMBER_OF_CALLS_MTBV,
        SUM(nvl(t.mttr,0))            NUMBER_OF_CALLS_MTTR,
        COUNT(DISTINCT t.instance_id) NUMBER_OF_PRINTERS,
        SUM(nvl(t.labor_hours,0))     LABOR_HOURS,
        SUM(t.effective_ib)           EFF_IB,
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
from    xxcs_mtxx_report_details_v t,
        (select fv.FLEX_VALUE cs_region,
                df.xxcs_cs_region_type_reports cs_region_type
         from   fnd_flex_values_vl   fv,
                fnd_flex_values_dfv  df
         where  fv.flex_value_set_id = 1014107 --XXCS_CS_REGIONS
         and    fv.row_id            = df.row_id
         and    fv.enabled_flag      = 'Y'
         and    sysdate              between nvl(fv.start_date_active,sysdate) and nvl(fv.end_date_active,sysdate) ) CS_REGION,
        xxcs_regions_v               region_gr     --
where   t.cs_region                  = cs_region.cs_region
and     cs_region.cs_region_type     = 'Indirect'
and     region_gr.CS_Region          = t.cs_region --
GROUP BY  t.operating_unit_party,
          t.type,
          region_gr.CS_Region_group,               --
          t.customer_name;
