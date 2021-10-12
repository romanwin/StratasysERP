create or replace view xxcst_asofdate_onhand_subs as
select a.date_as_of,
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
       a.org_name/*,
       nvl(a.si_total_cost,0)/nvl(decode(a.si_qty,0,1,a.si_qty),1) avg_item_cost--,*/
from xxobj_asofdate_qty_cst a
where exists (select 1
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

