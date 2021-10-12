CREATE OR REPLACE VIEW xxcn_commissions_v
-- ---------------------------------------------------------------------------------
-- Name:       xxcn_commissions_v
-- Created By: MMAZANET
-- Revision:   1.0
-- ---------------------------------------------------------------------------------
-- Purpose: Shows commission percentages at item level
-- ---------------------------------------------------------------------------------
-- Ver  Date        Name        Description
-- 1.0  06/10/2014  MMAZANET    Initial Creation for CHG0031576.
-- ---------------------------------------------------------------------------------
AS
SELECT 
   comm.plan_name
,  comm.plan_element_name
,  comm.eligible_products
,  comm.business_line
,  comm.product
,  comm.family
,  msib.segment1                 item_number
,  msib.description              item_description
,  comm.commission_percent       commission_percent
,  comm.comm_ct                  commission_ct     
FROM
/* comm... */
  (SELECT 
      ccp.name                      plan_name
   ,  cq.name                       plan_element_name
   ,  crc.name                      eligible_products
   ,  item_hier.business_line       business_line
   ,  item_hier.product             product
   ,  item_hier.family              family
   ,  comm_amount.commission_amount commission_percent
   ,  COUNT(*) OVER (PARTITION BY   item_hier.business_line
                                 ,  item_hier.product
                                 ,  item_hier.family)
                                    comm_ct
   FROM 
      cn_comp_plans_all             ccp
   ,  cn_quota_assigns_all          cqa
   ,  cn_quotas_all                 cq
   ,  cn_quota_rules_all            cqr
   ,  cn_revenue_classes_all        crc
   ,  cn_rules_all                  cr
   /* item_hier... */
   , (SELECT 
         rule_id
      ,  MAX(DECODE(user_name
            ,  'Product Item Category',   low_value
            ,  NULL))                   product
      ,  MAX(DECODE(user_name
            ,  'Family Item Category',   low_value
            ,  NULL))                   family
      ,  MAX(DECODE(user_name
            ,  'Line of Business Item Category',   low_value
            ,  NULL))                   business_line      
      FROM
      /* item_dtl... */
        (SELECT 
            DECODE(car.high_value
            ,  NULL, DECODE(co.data_type
                     ,  'DATE',  TO_CHAR(TO_DATE(car.column_value,'DD/MM/RRRR'))
                     ,  car.column_value
                     )
            ,  DECODE(co.data_type
               ,  'DATE',  TO_CHAR(TO_DATE(car.low_value,'DD/MM/RRRR'))
               ,  car.low_value
               )
            )                          low_value
         ,  car.rule_id                rule_id
         ,  co.user_name               user_name
         FROM 
            cn_attribute_rules_all   car 
         ,  cn_objects_all           co
         WHERE car.dimension_hierarchy_id IS NULL
         AND   co.object_id               = car.column_id
         AND   co.table_id                IN (-11803,-16134)
         AND   car.org_id                 = co.org_id)
         /* item_dtl... */
      GROUP BY rule_id)             item_hier
   /* ...item_hier */
   , (SELECT
         crt.commission_amount
      ,  crqaa.QUOTA_ID
      FROM 
         cn_rt_quota_asgns_all   crqaa
      ,  cn_rate_schedules_all   crs
      ,  cn_lookups              cl
      ,  cn_rate_tiers_all       crt
      WHERE crs.rate_schedule_id    = crqaa.rate_schedule_id
      AND   cl.lookup_code          = crs.commission_unit_code
      AND   cl.lookup_type          = 'PERCENT_AMOUNT'
      AND   crqaa.rate_schedule_id  = crt.rate_schedule_id
      AND   SYSDATE                 BETWEEN NVL(crqaa.start_date,'01-JAN-1900')
                                       AND NVL(crqaa.end_date,'31-DEC-4712'))  
                                    comm_amount
   WHERE ccp.comp_plan_id           = cqa.comp_plan_id
   AND   cq.calc_formula_id         = 10001
   AND   cqa.quota_id               = cq.quota_id
   AND   cqr.revenue_class_id       = crc.revenue_class_id
   AND   cqr.quota_id               = cq.quota_id
   AND   cr.revenue_class_id        = crc.revenue_class_id
   AND   cr.rule_id                 = item_hier.rule_id
   AND   comm_amount.quota_id       = cq.quota_id) comm
,  mtl_system_items_b            msib
,  mtl_parameters                mp
,  mtl_item_categories_v         micv 
WHERE micv.category_set_name     = 'Commissions'
AND   micv.category_concat_segs  = comm.product||'.'||comm.family||'.'||comm.business_line
AND   micv.organization_id       = mp.organization_id
AND   mp.organization_id         = mp.master_organization_id
AND   micv.inventory_item_id     = msib.inventory_item_id
AND   micv.organization_id       = msib.organization_id
/

SHOW ERRORS