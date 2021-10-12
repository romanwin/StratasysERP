CREATE OR REPLACE VIEW XXCS_AVG_SP_CST_V AS
SELECT
--------------------------------------------------------------------
--  name:            XXCS_AVG_SP_CST_V
--  create by:       Yoram Zamir
--  Revision:        1.1
--  creation date:   04/07/2010
--------------------------------------------------------------------
--  purpose :       Discoverer Reports
--------------------------------------------------------------------
--  ver  date        name             desc
--  1.0  04/07/2010  Yoram Zamir      initial build
--  1.1  11/07/2010  Yoram Zamir      contract_type added
--------------------------------------------------------------------
      a.OPERATING_UNIT,
      a.ITEM_CATEGORY,
      a.CONTRACT_TYPE,
      sum(a.TOTAL_FACTOR_DIRECT)                    TOTAL_FACTOR_DIRECT,
      sum(a.TOTAL_FACTOR_INDIRECT)                  TOTAL_FACTOR_INDIRECT,
      sum(a.TOTAL_FACTOR_NO_CUST_TYPE)              TOTAL_FACTOR_NO_CUST_TYPE,
      sum(a.TOTAL_FACTOR)                           TOTAL_FACTOR,
      sum(a.TOTAL_COST_DIRECT)                      TOTAL_COST_DIRECT,
      sum(a.TOTAL_COST_INDIRECT)                    TOTAL_COST_INDIRECT,
      sum(a.TOTAL_COST_NO_CUST_TYPE)                TOTAL_COST_NO_CUST_TYPE,
      sum(a.TOTAL_COST)                             TOTAL_COST,
      sum(a.TOTAL_COST_HEADS_DIRECT)                TOTAL_COST_HEADS_DIRECT,
      sum(a.TOTAL_COST_MATERIAL_DIRECT)             TOTAL_COST_MATERIAL_DIRECT,
      sum(a.TOTAL_COST_HEADS_INDIRECT)              TOTAL_COST_HEADS_INDIRECT,
      sum(a.TOTAL_COST_MATERIAL_INDIRECT)           TOTAL_COST_MATERIAL_INDIRECT,
      sum(a.TOTAL_CST_HEADS_NOCUST_TYP)             TOTAL_CST_HEADS_NOCUST_TYP,
      sum(a.TOTAL_CST_MATERIAL_NOCUST_TYP)          TOTAL_CST_MATERIAL_NOCUST_TYP,
      sum(a.TOTAL_COST_HEADS)                       TOTAL_COST_HEADS,
      sum(a.TOTAL_COST_MATERIAL)                    TOTAL_COST_MATERIAL,
      sum(a.AVG_COST_DIRECT_NORMALIZED)             AVG_COST_DIRECT_NORMALIZED,
      sum(a.AVG_COST_INDIRECT_NORMALIZED)           AVG_COST_INDIRECT_NORMALIZED,
      sum(a.AVG_COST_NO_CUST_TYPE_NORMALIZ)         AVG_COST_NO_CUST_TYPE_NORMALIZ,
      sum(a.AVG_COST_NORMALIZED)                    AVG_COST_NORMALIZED,
      sum(a.AVG_COST_HEADS_DIRECT_N)                AVG_COST_HEADS_DIRECT_N,
      sum(a.AVG_COST_MATRL_DIRECT_N)                AVG_COST_MATRL_DIRECT_N,
      sum(a.AVG_COST_HEADS_INDIRECT_N)              AVG_COST_HEADS_INDIRECT_N,
      sum(a.AVG_COST_MATRL_INDIRECT_N)              AVG_COST_MATRL_INDIRECT_N,
      sum(a.AVG_CST_HEADS_NOCUST_TYP_N)             AVG_CST_HEADS_NOCUST_TYP_N,
      sum(a.AVG_CST_MATRL_NOCUST_TYP_N)             AVG_CST_MATRL_NOCUST_TYP_N,
      sum(a.AVG_COST_HEADS_N)                       AVG_COST_HEADS_N,
      sum(a.AVG_COST_MATRL_N)                       AVG_COST_MATRL_N

FROM  XXCS_AVG_SP_CST_DET_V  a
--WHERE
GROUP BY a.OPERATING_UNIT,
         a.ITEM_CATEGORY,
         a.CONTRACT_TYPE;

