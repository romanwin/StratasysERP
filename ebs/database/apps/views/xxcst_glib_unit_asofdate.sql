create or replace view xxcst_glib_unit_asofdate as
select csidet.INSTANCE_ID, csidet.concatenated_segments ITEM_NUMBER,csidet.description,
       csidet.SERIAL_NUMBER,
       sum(inst_hist.qty) AS Qty,csidet.attribute9 CONV_COST,
       hropu.name Company,
       hropu.organization_id org_id,
       csidet.INVENTORY_ITEM_ID,
       csidet.UNIT_OF_MEASURE
from(
 /*Shipping Transactions that debit the TryBuy, Rebtal Or Shows GL Account from IB Interface*/
select csidet.instance_id,
       oeh.org_id, --a.instance_id
       (sum(decode(csidet.transaction_type_id,
                   53,
                   (-1 * csidet.QUANTITY),
                   (1 * csidet.QUANTITY)))) as Qty
from csi_inst_txn_details_v   csidet,
       oe_order_headers_all     oeh,
       OE_ORDER_LINES_ALL       OEL,
       oe_transaction_types_all oet,
       mtl_material_transactions mtt,
       mtl_system_items_b msi
 WHERE csidet.SOURCE_HEADER_REF_ID = oeh.header_id
   and oet.transaction_type_id = oel.line_type_id
   AND oel.header_id = oeh.header_id
   and oel.line_id = csidet.SOURCE_LINE_REF_ID
   and oet.attribute6 = 'Y'
   and csidet.transaction_type_id in (53,51)
   and mtt.transaction_id=csidet.inv_material_transaction_id
   and mtt.inventory_item_id=oel.inventory_item_id
   and msi.inventory_item_id=csidet.INVENTORY_ITEM_ID
   and msi.inventory_item_id=mtt.inventory_item_id
   and msi.organization_id=oel.ship_from_org_id
      --   and (oel.inventory_item_id = P_Item_ID or P_Item_ID is null)
   and trunc(csidet.source_transaction_date) <= XXCS_SESSION_PARAM.get_session_param_date(1)
--       to_date('30-SEP-2009 23:59:59', 'DD-MON-YYYY HH24:MI:SS')
--  and oeh.org_id = P_SubS_OrgID
 group by csidet.instance_id, oeh.org_id
UNION ALL
/*Shipping Transactions that debit the TryBuy, Rebtal Or Shows GL Account from IB Interface errors*/
 Select aa.instance_id,
       oel.org_id,
       (-1 * (decode(bb.serial_number, null, bb.shipped_quantity, 1) *
       decode(aa.transaction_type_id, 51, -1, 1))) as Qty
  From csi_txn_errors           aa,
       csi_txn_errors_v         bb,
       oe_order_lines_all       oel,
       oe_transaction_types_all oet
 Where bb.transaction_error_id = aa.transaction_error_id
   and oet.transaction_type_id = oel.line_type_id

   and oel.line_id = aa.source_line_ref_id
   and oet.attribute6 = 'Y'
   and aa.source_header_ref is not null
      --  and (aa.inventory_item_id = P_Item_ID or P_Item_ID is null)
   and aa.transaction_type_id in (53, 51)
   and trunc(aa.transaction_error_date) <= XXCS_SESSION_PARAM.get_session_param_date(1)
  --     to_date('30-SEP-2009 23:59:59', 'DD-MON-YYYY HH24:MI:SS')
--  and oel.org_id = P_SubS_OrgID
UNION ALL
/*DATA CONVERSION TryBuy, Rebtal Or Shows GL Account Units*/
Select csid.instance_id,
       hrorg.OPERATING_UNIT as org_id,
       sum(/*decode((select 1
                  from OE_ORDER_LINES_ALL       OEL,
                       oe_transaction_types_all oet
                  where oel.line_id=csid.last_oe_order_line_id
                  and NVL(oet.attribute6,1) <> 'Y'
                  and oel.line_type_id=oet.transaction_type_id)
       ,NULL,csid.quantity,0)*/1) as Qty
  From CSI_INSTANCE_DETAILS_V csid, org_organization_definitions hrorg
 where csid.attribute9 is not null
   and hrorg.ORGANIZATION_NAME = csid.organization_name
   and csid.accounting_class_code = 'CUST_PROD'
      --   and hrorg.OPERATING_UNIT = P_SubS_OrgID
   and trunc(NVL(csid.install_date, csid.active_start_date)) <= XXCS_SESSION_PARAM.get_session_param_date(1)
 --      to_date('30-SEP-2009 23:59:59', 'DD-MON-YYYY HH24:MI:SS')
 group by csid.instance_id, hrorg.OPERATING_UNIT
UNION ALL
 /*Problemtic TryBuy, Rebtal Or Shows GL Account Units that should be removed from the report*/
Select csid.instance_id,
       hrorg.OPERATING_UNIT as org_id,
       -1 as Qty
  From CSI_INSTANCE_DETAILS_V csid, org_organization_definitions hrorg
 where hrorg.ORGANIZATION_NAME = csid.organization_name
   and csid.accounting_class_code = 'CUST_PROD'
   and (csid.serial_number='5147' or csid.serial_number='7136' or csid.serial_number='7033' or csid.serial_number='7082')
UNION ALL
 /*Problemtic TryBuy, Rebtal Or Shows GL Account Units that should be removed from the report*/
Select csid.instance_id,
       hrorg.OPERATING_UNIT as org_id,
       1 as Qty
  From CSI_INSTANCE_DETAILS_V csid, org_organization_definitions hrorg
 where hrorg.ORGANIZATION_NAME = csid.organization_name
   and csid.accounting_class_code = 'CUST_PROD'
   and csid.serial_number='364' --line_id=22326, order 103358, line 17,Wrong Line_Type, SERIAL 364
  ) inst_hist,
 CSI_INSTANCE_DETAILS_V csidet,
 hr_operating_units hropu
 where inst_hist.instance_id=csidet.INSTANCE_ID
 and hropu.organization_id=inst_hist.org_id
 group by csidet.INSTANCE_ID,csidet.concatenated_segments,csidet.description,
       csidet.SERIAL_NUMBER, csidet.attribute9, hropu.name,hropu.organization_id,
       csidet.INVENTORY_ITEM_ID,
       csidet.UNIT_OF_MEASURE;
