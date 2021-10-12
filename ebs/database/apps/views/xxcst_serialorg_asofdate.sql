CREATE OR REPLACE VIEW XXCST_SERIALORG_ASOFDATE AS
SELECT organization_code, serial_number, segment1,sum(case when transaction_quantity>0 then 1 else -1 end ) QTY,
       xxinv_utils_pkg.get_item_category(INVENTORY_ITEM_ID, '1100000041') main_category, DESCRIPTION, INVENTORY_ITEM_ID,
       Decode(xxinv_utils_pkg.is_fdm_item(INVENTORY_ITEM_ID,segment1),'Y','FDM','Polyjet') Technology
from (
SELECT mtlp.organization_code, a.serial_number, msi.segment1,
       (case when b.transaction_quantity>0 then 1 else -1 end ) transaction_quantity,
       A.SUBINVENTORY_CODE SUBINV, A.INVENTORY_ITEM_ID,MSI.DESCRIPTION,
      null
FROM MTL_UNIT_TRANSACTIONS a,
     MTL_MATERIAL_TRANSACTIONS b,
     mtl_transaction_types mtlt,
     mtl_system_items_b msi,
     mtl_parameters mtlp
where /*a.serial_number='7147'
and*/ a.transaction_id=b.transaction_id
and msi.inventory_item_id=a.inventory_item_id
and msi.organization_id=b.organization_id
and b.transaction_type_id=mtlt.transaction_type_id
--and b.transaction_date >= to_date('01-SEP-2009 00:00:00', 'DD-MON-YYYY HH24:MI:SS')
and b.transaction_date <= XXCS_SESSION_PARAM.get_session_param_date(1)--to_date('30-SEP-2009 23:59:59', 'DD-MON-YYYY HH24:MI:SS')
and mtlp.organization_id=b.organization_id
union all
SELECT mtlp.organization_code, a.serial_number, msi.segment1,
       1 transaction_quantity,
       'Transit' SUBINV, A.INVENTORY_ITEM_ID,MSI.DESCRIPTION,
       max(a.transaction_id)
FROM MTL_UNIT_TRANSACTIONS a,
     MTL_MATERIAL_TRANSACTIONS b,
     mtl_system_items_b msi,
     mtl_parameters mtlp,
     (select untrx.serial_number, max(untrx.transaction_date) trx_date
      from MTL_UNIT_TRANSACTIONS untrx
      where untrx.transaction_date <= XXCS_SESSION_PARAM.get_session_param_date(1)--to_date('30-SEP-2009 23:59:59', 'DD-MON-YYYY HH24:MI:SS')
      group by untrx.serial_number) lastrxdate
where /*a.serial_number='7147'
and*/ a.transaction_id=b.transaction_id
and msi.inventory_item_id=a.inventory_item_id
and msi.organization_id=b.organization_id
and b.transaction_type_id IN (62,21)
and b.transaction_date <= XXCS_SESSION_PARAM.get_session_param_date(1)--to_date('30-SEP-2009 23:59:59', 'DD-MON-YYYY HH24:MI:SS')
and lastrxdate.serial_number=a.serial_number
and lastrxdate.trx_date=a.transaction_date
and mtlp.organization_id=b.transfer_organization_id
group by mtlp.organization_code, a.serial_number, msi.segment1, A.INVENTORY_ITEM_ID, MSI.DESCRIPTION
)
where xxinv_utils_pkg.get_item_category( INVENTORY_ITEM_ID, '1100000041') like 'Systems.S%'
   or (xxinv_utils_pkg.get_item_category( INVENTORY_ITEM_ID, '1100000041') like 'Systems%'
   and xxinv_utils_pkg.is_fdm_item(INVENTORY_ITEM_ID,segment1)= 'Y')
having sum(case when transaction_quantity>0 then 1 else -1 end )<>0
group by organization_code, serial_number, segment1, INVENTORY_ITEM_ID, DESCRIPTION
order by organization_code, segment1,serial_number;
