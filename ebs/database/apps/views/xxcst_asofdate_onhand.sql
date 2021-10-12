CREATE OR REPLACE VIEW XXCST_ASOFDATE_ONHAND AS
SELECT 
--------------------------------------------------------------------
--  name:            XXCST_ASOFDATE_ONHAND
--  create by:       
--  Revision:        1.1
--  creation date:   xx/xx/2009
--------------------------------------------------------------------
--  purpose :      Discoverer Report - XX: As Of Date On-hand
--------------------------------------------------------------------
--  ver  date        name            desc
--  1.0  xx/xx/2009                  initial build
--  1.1  20.01.2014  Vitaly          CUST410 - CR1262 - Add Item categories fields to set of Disco reports
--------------------------------------------------------------------
       a.date_as_of,
       a.organization_code,
       nvl(a.subinventory_code,'In-Transit') subinventory_code,
       nvl(a.subinventory_description,'In-Transit') subinventory_description,
       nvl(decode(a.asset_inventory,1,'Yes',2,'No'),'Yes') asset_inventory,
       a.item_number,
       a.item_description,
       a.si_qty,
       a.si_defaulted cost_type,
       a.si_matl_cost,
       a.si_movh_cost,
       a.si_res_cost,
       a.si_osp_cost,
       a.si_ovhd_cost,
       a.si_total_cost,
       a.creation_date,
       a.created_by,
       a.inventory_item_id,
       a.organization_id,
       a.org_id,
       a.org_name,
       nvl(a.si_total_cost,0)/nvl(decode(a.si_qty,0,1,a.si_qty),1) avg_item_cost,
       (select max(b.avg_cost_cogs)
       from xxobjt_ratam_intsales b
       where a.date_as_of=b.date_as_of
       and a.org_id=b.org_id
       and a.inventory_item_id=b.item_id) avg_cost_cogs,
       (select max(b.avg_cost_il)
       from xxobjt_ratam_intsales b
       where a.date_as_of=b.date_as_of
       and a.org_id=b.org_id
       and a.inventory_item_id=b.item_id) avg_cost_il,
      c1.category_set_name       c1_category_set_name,
      c1.concatenated_segments   c1_concatenated_segments,
      c1.segment1  c1_segment1,
      c1.segment2  c1_segment2,
      c1.segment3  c1_segment3,
      c1.segment4  c1_segment4,
      c1.segment5  c1_segment5,
      c1.segment6  c1_segment6,
      c1.segment7  c1_segment7,
      c1.segment8  c1_segment8,
      c1.segment9  c1_segment9,
      c1.segment10 c1_segment10,
      c2.category_set_name       c2_category_set_name,
      c2.concatenated_segments   c2_concatenated_segments,
      c2.segment1  c2_segment1,
      c2.segment2  c2_segment2,
      c2.segment3  c2_segment3,
      c2.segment4  c2_segment4,
      c2.segment5  c2_segment5,
      c2.segment6  c2_segment6,
      c2.segment7  c2_segment7,
      c2.segment8  c2_segment8,
      c2.segment9  c2_segment9,
      c2.segment10 c2_segment10
from xxobj_asofdate_qty_cst a,
     xxmtl_categories_v     c1, 
     xxmtl_categories_v     c2
where c1.category_set_name(+) = nvl(xxcs_session_param.get_session_param_char(1),'ZZZZZZZ') 
and   c2.category_set_name(+) = nvl(xxcs_session_param.get_session_param_char(2),'ZZZZZZZ') 
and   a.inventory_item_id = c1.inventory_item_id(+)
and   a.inventory_item_id = c2.inventory_item_id(+)
and exists (select 1
          from org_access oa
         where oa.organization_id = a.organization_id
           AND oa.resp_application_id =
               decode(fnd_global.resp_appl_id,
                      -1,
                      oa.resp_application_id,
                      fnd_global.resp_appl_id)
           AND oa.responsibility_id =
               decode(fnd_global.resp_id,
                      -1,
                      oa.responsibility_id,
                      fnd_global.resp_id));
