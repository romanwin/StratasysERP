CREATE OR REPLACE VIEW XXCN_PRODUCT_COMM_CATEGORY_V AS
with prod_rec as
(SELECT cqr.REVENUE_CLASS_ID,
       cqr.QUOTA_ID,
       nvl(cq.attribute3,'N') new_logo,
       crt.commission_amount * 100 rate,
       listagg(car.column_value, '.') within group(order by car.column_id) oic_concatenated_segments
  FROM CN_QUOTA_RULES_ALL     cqr,
       cn_rules_all_vl        cr,
       cn_quotas_all          cq,
       CN_ATTRIBUTE_RULES_ALL car,
       cn_rt_quota_asgns_all  crqa,
       cn_rate_tiers_all      crt,
       cn_quota_assigns_all   cqa,
       cn_comp_plans_all      ccp
 where cr.REVENUE_CLASS_ID = cqr.REVENUE_CLASS_ID
   and car.rule_id = cr.RULE_ID
   and cqr.quota_id = crqa.quota_id
   and crqa.rate_schedule_id = crt.rate_schedule_id
   and cqr.quota_id = cqa.quota_id
   and cqa.comp_plan_id = ccp.comp_plan_id
   and sysdate between nvl(ccp.start_date,sysdate-1) and nvl(ccp.end_date,sysdate+1)
   and cq.quota_id = cqr.quota_id
 group by cqr.REVENUE_CLASS_ID, cqr.QUOTA_ID, crt.commission_amount, cq.attribute3)
select msib.inventory_item_id,
       msib.segment1,
       msib.description,
       mck.concatenated_segments comm_category,
       mis.inventory_item_status_code_tl,
       (select ffv.DESCRIPTION from fnd_flex_values_vl ffv,
       fnd_flex_value_sets ffvs where ffvs.flex_value_set_name = 'XXCN_SYSTEM_TYPE'
   and ffvs.flex_value_set_id=ffv.flex_value_set_id
   and ffv.FLEX_VALUE = mck.attribute9) system_type,
       (select 'Y'
          from xxcn_consumable_items xci 
         where rtrim(xci.concatenated_string,'.') = pr.oic_concatenated_segments) PRE_COMM_CONSUMABLE_EXISTS,
       (select 'Y'
          from xxcn_system_items xsi 
         where rtrim(xsi.concatenated_string,'.') = pr.oic_concatenated_segments) PRE_COMM_SYSTEM_EXISTS,
       decode((select 'Y'
          from xxcn_system_items xsi 
         where rtrim(xsi.concatenated_string,'.') = pr.oic_concatenated_segments),'Y',(select 'MATERIALS - '||count(1) 
          from xxcn_system_items xsi, xxcn_system_to_consumable xsc 
         where rtrim(xsi.concatenated_string,'.') = pr.oic_concatenated_segments
           and xsi.system_id = xsc.system_id 
           and xsc.end_date is null),
           decode((select 'Y'
          from xxcn_consumable_items xci 
         where rtrim(xci.concatenated_string,'.') = pr.oic_concatenated_segments),'Y',
        (select 'SYSTEMS - '||count(1) 
          from xxcn_consumable_items xci1, xxcn_system_to_consumable xsc 
         where rtrim(xci1.concatenated_string,'.') = pr.oic_concatenated_segments
           and xci1.consumable_id = xsc.consumable_id 
           and xsc.end_date is null),'')) PRE_COMM_REL_COUNT,
       mcs.CATEGORY_SET_ID,
       mic.category_id,
       msib.organization_id
       ,pr.rate
       ,pr_nl.new_logo
  from mtl_system_items_b msib,
       mtl_item_categories mic,
       mtl_category_sets_vl mcs,
       MTL_CATEGORIES_KFV mck,
       mtl_item_status_tl mis,
       prod_rec pr,
       prod_rec pr_nl
 where msib.organization_id = 91
   and msib.organization_id = mic.organization_id
   and msib.inventory_item_id = mic.inventory_item_id
   and mic.category_id = mck.CATEGORY_ID
   and mcs.CATEGORY_SET_NAME = 'Commissions'
   and mck.structure_id = mcs.STRUCTURE_ID
   and mis.inventory_item_status_code = msib.inventory_item_status_code
   and mis.language = 'US'
   and pr.oic_concatenated_segments (+) = mck.concatenated_segments
   and pr.new_logo (+) = 'N'
   and pr_nl.oic_concatenated_segments (+) = mck.concatenated_segments
   and pr_nl.new_logo (+) = 'Y';
/
