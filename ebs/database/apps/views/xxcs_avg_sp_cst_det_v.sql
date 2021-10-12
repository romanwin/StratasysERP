CREATE OR REPLACE VIEW XXCS_AVG_SP_CST_DET_V AS
SELECT
--------------------------------------------------------------------
--  name:            XXCS_AVG_SP_CST_DET_V
--  create by:       Yoram Zamir
--  Revision:        1.0
--  creation date:   11/07/2010
--------------------------------------------------------------------
--  purpose :       Discoverer Reports this view replaces XXCS_AVG_SP_COST_V
--------------------------------------------------------------------
--  ver  date        name             desc
--  1.0  11/07/2010  Yoram Zamir      initial build
--  1.1  XX/XX/XXXX
--------------------------------------------------------------------
       avsp.operating_unit,
       avsp.item_category,
       avsp.contract_type,
       SUM(avsp.TOTAL_FACTOR_DIRECT)           TOTAL_FACTOR_DIRECT,
       SUM(avsp.TOTAL_FACTOR_INDIRECT)         TOTAL_FACTOR_INDIRECT,
       SUM(avsp.TOTAL_FACTOR_NO_CUST_TYPE)     TOTAL_FACTOR_NO_CUST_TYPE,
       SUM(avsp.TOTAL_FACTOR)                  TOTAL_FACTOR,
       ------------------------------------------------------------------
       SUM(avsp.TOTAL_COST_DIRECT)             TOTAL_COST_DIRECT,
       SUM(avsp.TOTAL_COST_INDIRECT)           TOTAL_COST_INDIRECT,
       SUM(avsp.TOTAL_COST_NO_CUST_TYPE)       TOTAL_COST_NO_CUST_TYPE,
       SUM(avsp.TOTAL_COST)                    TOTAL_COST,
       SUM(avsp.TOTAL_COST_HEADS_DIRECT)       TOTAL_COST_HEADS_DIRECT,
       SUM(avsp.TOTAL_COST_MATERIAL_DIRECT)    TOTAL_COST_MATERIAL_DIRECT,
       SUM(avsp.TOTAL_COST_HEADS_INDIRECT)     TOTAL_COST_HEADS_INDIRECT,
       SUM(avsp.TOTAL_COST_MATERIAL_INDIRECT)  TOTAL_COST_MATERIAL_INDIRECT,
       SUM(avsp.TOTAL_CST_HEADS_NOCUST_TYP)    TOTAL_CST_HEADS_NOCUST_TYP,
       SUM(avsp.TOTAL_CST_MATERIAL_NOCUST_TYP) TOTAL_CST_MATERIAL_NOCUST_TYP,
       SUM(avsp.TOTAL_COST_HEADS)              TOTAL_COST_HEADS,
       SUM(avsp.TOTAL_COST_MATERIAL)           TOTAL_COST_MATERIAL,
       ----------------------------------------------------------------------

       decode(SUM(avsp.TOTAL_FACTOR_DIRECT),0,0,SUM(avsp.TOTAL_COST_DIRECT)/SUM(avsp.TOTAL_FACTOR_DIRECT))                         AVG_COST_DIRECT_NORMALIZED,
       decode(SUM(avsp.TOTAL_FACTOR_INDIRECT),0,0,SUM(avsp.TOTAL_COST_INDIRECT)/SUM(avsp.TOTAL_FACTOR_INDIRECT))                   AVG_COST_INDIRECT_NORMALIZED,
       decode(SUM(avsp.TOTAL_FACTOR_NO_CUST_TYPE) ,0,0,SUM(avsp.TOTAL_COST_NO_CUST_TYPE)/SUM(avsp.TOTAL_FACTOR_NO_CUST_TYPE))      AVG_COST_NO_CUST_TYPE_NORMALIZ,
       decode(SUM(avsp.TOTAL_FACTOR),0,0,SUM(avsp.TOTAL_COST)/SUM(avsp.TOTAL_FACTOR))                                              AVG_COST_NORMALIZED,
       decode(SUM(avsp.TOTAL_FACTOR_DIRECT),0,0,SUM(avsp.TOTAL_COST_HEADS_DIRECT)/SUM(avsp.TOTAL_FACTOR_DIRECT))                   AVG_COST_HEADS_DIRECT_N,
       decode(SUM(avsp.TOTAL_FACTOR_DIRECT),0,0,SUM(avsp.TOTAL_COST_MATERIAL_DIRECT)/SUM(avsp.TOTAL_FACTOR_DIRECT))                AVG_COST_MATRL_DIRECT_N,
       decode(SUM(avsp.TOTAL_FACTOR_INDIRECT),0,0,SUM(avsp.TOTAL_COST_HEADS_INDIRECT)/SUM(avsp.TOTAL_FACTOR_INDIRECT))             AVG_COST_HEADS_INDIRECT_N,
       decode(SUM(avsp.TOTAL_FACTOR_INDIRECT),0,0,SUM(avsp.TOTAL_COST_MATERIAL_INDIRECT)/SUM(avsp.TOTAL_FACTOR_INDIRECT))          AVG_COST_MATRL_INDIRECT_N,
       decode(SUM(avsp.TOTAL_FACTOR_NO_CUST_TYPE),0,0,SUM(avsp.TOTAL_CST_HEADS_NOCUST_TYP)/SUM(avsp.TOTAL_FACTOR_NO_CUST_TYPE))    AVG_CST_HEADS_NOCUST_TYP_N,
       decode(SUM(avsp.TOTAL_FACTOR_NO_CUST_TYPE),0,0,SUM(avsp.TOTAL_CST_MATERIAL_NOCUST_TYP)/SUM(avsp.TOTAL_FACTOR_NO_CUST_TYPE)) AVG_CST_MATRL_NOCUST_TYP_N,
       decode(SUM(avsp.TOTAL_FACTOR),0,0,SUM(avsp.TOTAL_COST_HEADS)/SUM(avsp.TOTAL_FACTOR))                                        AVG_COST_HEADS_N,
       decode(SUM(avsp.TOTAL_FACTOR),0,0,SUM(avsp.TOTAL_COST_MATERIAL)/SUM(avsp.TOTAL_FACTOR))                                     AVG_COST_MATRL_N
FROM   XXCS_AVG_SPARE_PARTS_CST_V   avsp
GROUP BY avsp.operating_unit,
         avsp.item_category,
         avsp.contract_type;

