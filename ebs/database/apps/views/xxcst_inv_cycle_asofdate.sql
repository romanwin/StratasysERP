CREATE OR REPLACE VIEW XXCST_INV_CYCLE_ASOFDATE AS
select cycle_date.ITEM_NUMBER "ITEM_NUMBER",
       cycle_date.TRANSACTION_TYPE "TRANSACTION_TYPE",
       cycle_date.TRANSACTION_QUANTITY "TRANSACTION_QUANTITY",
       cycle_date.ORGANIZATION_ID "ORGANIZATION_ID",
       cycle_date.ORGANIZATION_CODE "ORGANIZATION_CODE",
       cycle_date.TRANSACTION_DATE "TRANSACTION_DATE",
       cycle_date.COMPANY_NAME "COMPANY_NAME"
from (

SELECT msi.segment1 item_number,
       CASE WHEN
       (mtt.TRANSACTION_TYPE_ID = 33 AND  mtt.TRANSACTION_ACTION_ID = 1 AND mtt.TRANSACTION_SOURCE_TYPE_ID = 2) and
       exists  (select 1
                              from  OE_ORDER_LINES_ALL       OEL,
                                    oe_transaction_types_all oet
                              where oel.line_type_id=oet.transaction_type_id
                              and (oet.attribute6 = 'Y' or oel.line_id = 22326)
                              and mtt.source_line_id=oel.line_id)
       then 'Rental, Try&Buy, Shows Shipment' WHEN
       (mtt.TRANSACTION_TYPE_ID = 33 AND  mtt.TRANSACTION_ACTION_ID = 1 AND mtt.TRANSACTION_SOURCE_TYPE_ID = 2) and
       exists (select 1
                              from  OE_ORDER_LINES_ALL       OEL,
                                    oe_order_headers_all OEH,
                                    oe_transaction_types_all oet,
                                    oe_transaction_types_tl oetl
                              where oel.line_type_id=oet.transaction_type_id
                              and oel.header_id=oeh.header_id
                              and (NVL(oet.attribute6,1) <> 'Y' AND oel.line_id <> 22326)
                              and oetl.language='US'
                              and oetl.transaction_type_id=OEH.ORDER_TYPE_ID
                              and oetl.name LIKE  '%Internal Return Shipping%'
                              and mtt.source_line_id=oel.line_id)
       then 'Intercomapny Return Order Shipment' WHEN
       (mtt.TRANSACTION_TYPE_ID = 33 AND  mtt.TRANSACTION_ACTION_ID = 1 AND mtt.TRANSACTION_SOURCE_TYPE_ID = 2) and
       exists (select 1
                              from  OE_ORDER_LINES_ALL       OEL,
                                    oe_order_headers_all OEH,
                                    oe_transaction_types_all oet,
                                    oe_transaction_types_tl oetl
                              where oel.line_type_id=oet.transaction_type_id
                              and oel.header_id=oeh.header_id
                              and (NVL(oet.attribute6,1) <> 'Y' AND oel.line_id <> 22326)
                              and oetl.language='US'
                              and oetl.transaction_type_id=OEH.ORDER_TYPE_ID
                              and oetl.name NOT LIKE '%Internal Return Shipping%'
                              and mtt.source_line_id=oel.line_id)
       then 'Std. Sales Order Shipment' WHEN
       (mtt.TRANSACTION_TYPE_ID = 62 AND mtt.TRANSACTION_ACTION_ID = 21 AND mtt.TRANSACTION_SOURCE_TYPE_ID = 8)
       then 'Intercomapny Shipment' WHEN
       (mtt.TRANSACTION_TYPE_ID in (44,17) AND mtt.TRANSACTION_ACTION_ID in (31,32) AND mtt.TRANSACTION_SOURCE_TYPE_ID =5 )
       then 'WIP Completion' WHEN
       (mtt.TRANSACTION_TYPE_ID in (15) AND mtt.TRANSACTION_ACTION_ID in (27) AND mtt.TRANSACTION_SOURCE_TYPE_ID =12
        and (mtt.subinventory_code in (select mtt.subinventory_code
                        from mtl_secondary_inventories mtlsub
                        where mtlsub.organization_id=mtt.organization_id
                        and mtlsub.secondary_inventory_name=mtt.subinventory_code
                        and mtlsub.asset_inventory=1))and
                        exists (select 1
                              from  OE_ORDER_LINES_ALL       OEL,
                                    oe_order_headers_all OEH,
                                    oe_transaction_types_all oet,
                                    oe_transaction_types_tl oetl,
                                    rcv_transactions rcvtrx
                              where oel.line_type_id=oet.transaction_type_id
                              and oel.header_id=oeh.header_id
                              and rcvtrx.transaction_id=mtt.source_line_id
                              and (NVL(oet.attribute6,1) <> 'Y' AND oel.line_id <> 22326)
                              and oetl.language='US'
                              and oetl.transaction_type_id=OEH.ORDER_TYPE_ID
                              and oetl.name LIKE '%Internal Return Receiving%'
                              and rcvtrx.oe_order_line_id=oel.line_id))
       then 'RMA Intercompany Receipt'WHEN
       (mtt.TRANSACTION_TYPE_ID in (15) AND mtt.TRANSACTION_ACTION_ID in (27) AND mtt.TRANSACTION_SOURCE_TYPE_ID =12
        and (mtt.subinventory_code in (select mtt.subinventory_code
                        from mtl_secondary_inventories mtlsub
                        where mtlsub.organization_id=mtt.organization_id
                        and mtlsub.secondary_inventory_name=mtt.subinventory_code
                        and mtlsub.asset_inventory=1))and
                        exists (select 1
                              from  OE_ORDER_LINES_ALL       OEL,
                                    oe_order_headers_all OEH,
                                    oe_transaction_types_all oet,
                                    oe_transaction_types_tl oetl,
                                    rcv_transactions rcvtrx
                              where oel.line_type_id=oet.transaction_type_id
                              and oel.header_id=oeh.header_id
                              and rcvtrx.transaction_id=mtt.source_line_id
                              and (NVL(oet.attribute6,1) <> 'Y' AND oel.line_id <> 22326)
                              and oetl.language='US'
                              and oetl.transaction_type_id=OEH.ORDER_TYPE_ID
                              and oetl.name NOT LIKE '%Internal Return Receiving%'
                              and rcvtrx.oe_order_line_id=oel.line_id))
       then 'RMA Asset Std. Order Receipt' WHEN
       (mtt.TRANSACTION_TYPE_ID in (15) AND mtt.TRANSACTION_ACTION_ID in (27) AND mtt.TRANSACTION_SOURCE_TYPE_ID =12
        and (mtt.subinventory_code in (select mtt.subinventory_code
                        from mtl_secondary_inventories mtlsub
                        where mtlsub.organization_id=mtt.organization_id
                        and mtlsub.secondary_inventory_name=mtt.subinventory_code
                        and mtlsub.asset_inventory=1))and
                        exists  (select 1
                              from  OE_ORDER_LINES_ALL       OEL,
                                    oe_transaction_types_all oet,
                                    rcv_transactions rcvtrx
                              where oel.line_type_id=oet.transaction_type_id
                              and rcvtrx.transaction_id=mtt.source_line_id
                              and (oet.attribute6 = 'Y' or oel.line_id = 22326)
                              and rcvtrx.oe_order_line_id=oel.line_id))
       then 'RMA Asset Rental, Try&Buy, Shows Receipt' WHEN
        (mtt.TRANSACTION_TYPE_ID in (15) AND mtt.TRANSACTION_ACTION_ID in (27) AND mtt.TRANSACTION_SOURCE_TYPE_ID =12
        and (mtt.subinventory_code in (select mtt.subinventory_code
                        from mtl_secondary_inventories mtlsub
                        where mtlsub.organization_id=mtt.organization_id
                        and mtlsub.secondary_inventory_name=mtt.subinventory_code
                        and mtlsub.asset_inventory=2)) and
                        exists (select 1
                              from  OE_ORDER_LINES_ALL       OEL,
                                    oe_order_headers_all OEH,
                                    oe_transaction_types_all oet,
                                    oe_transaction_types_tl oetl,
                                    rcv_transactions rcvtrx
                              where oel.line_type_id=oet.transaction_type_id
                              and oel.header_id=oeh.header_id
                              and rcvtrx.transaction_id=mtt.source_line_id
                              and (NVL(oet.attribute6,1) <> 'Y' AND oel.line_id <> 22326)
                              and oetl.language='US'
                              and oetl.transaction_type_id=OEH.ORDER_TYPE_ID
                              and oetl.name LIKE '%Internal Return Receiving%'
                              and rcvtrx.oe_order_line_id=oel.line_id))
       then 'RMA Intercompany Non-Asset Receipt'WHEN
        (mtt.TRANSACTION_TYPE_ID in (15) AND mtt.TRANSACTION_ACTION_ID in (27) AND mtt.TRANSACTION_SOURCE_TYPE_ID =12
        and (mtt.subinventory_code in (select mtt.subinventory_code
                        from mtl_secondary_inventories mtlsub
                        where mtlsub.organization_id=mtt.organization_id
                        and mtlsub.secondary_inventory_name=mtt.subinventory_code
                        and mtlsub.asset_inventory=2))and
                        exists (select 1
                              from  OE_ORDER_LINES_ALL       OEL,
                                    oe_order_headers_all OEH,
                                    oe_transaction_types_all oet,
                                    oe_transaction_types_tl oetl,
                                    rcv_transactions rcvtrx
                              where oel.line_type_id=oet.transaction_type_id
                              and oel.header_id=oeh.header_id
                              and rcvtrx.transaction_id=mtt.source_line_id
                              and (NVL(oet.attribute6,1) <> 'Y' AND oel.line_id <> 22326)
                              and oetl.language='US'
                              and oetl.transaction_type_id=OEH.ORDER_TYPE_ID
                              and oetl.name NOT LIKE '%Internal Return Receiving%'
                              and rcvtrx.oe_order_line_id=oel.line_id))
       then 'RMA Non-Asset Receipt' WHEN
       1=(select 1
                        from mtl_secondary_inventories mtlsub
                        where mtlsub.organization_id=mtt.organization_id
                        and mtlsub.secondary_inventory_name=mtt.transfer_subinventory
                        and mtlsub.asset_inventory=2)
       then 'Expense Transfer' WHEN
       (mtt.TRANSACTION_TYPE_ID = 61 AND  mtt.TRANSACTION_ACTION_ID = 12 AND mtt.TRANSACTION_SOURCE_TYPE_ID = 7)
       then 'Internal Req Intr Rcpt' WHEN
       (mtt.TRANSACTION_TYPE_ID = 12 AND  mtt.TRANSACTION_ACTION_ID = 12 AND mtt.TRANSACTION_SOURCE_TYPE_ID = 13)
       then 'Org Transfer Intr Rcpt' WHEN
       (mtt.TRANSACTION_TYPE_ID = 21 AND  mtt.TRANSACTION_ACTION_ID = 21 AND mtt.TRANSACTION_SOURCE_TYPE_ID = 13)
       then 'Org Transfer Shipment'
       else 'Other'
       End "TRANSACTION_TYPE",
       mtt.TRANSACTION_QUANTITY,
       mtt.organization_id,
       mtp.organization_code,
       trunc(mtt.transaction_date) transaction_date,
       hropu.name Company_name
  FROM MTL_MATERIAL_TRANSACTIONS mtt,
       mtl_system_items_b msi,
       mtl_parameters mtp,
       org_organization_definitions orguo,
       hr_operating_units hropu
 WHERE mtt.TRANSACTION_ACTION_ID NOT IN (24, 30)
   and mtt.organization_id=mtp.organization_id
   and mtt.organization_id=orguo.ORGANIZATION_ID
   and orguo.OPERATING_UNIT=hropu.organization_id
   and hropu.name=nvl(XXCS_SESSION_PARAM.get_session_param_char(5),hropu.name)
   and (mtp.organization_code = nvl(XXCS_SESSION_PARAM.get_session_param_char(1),mtp.organization_code))
  -- and (mtt.ORGANIZATION_ID IN (&ORGS))
   and (mtt.transaction_date between
       to_date(XXCS_SESSION_PARAM.get_session_param_char(2), 'DD-MON-YYYY HH24:MI:SS') AND
       to_date(XXCS_SESSION_PARAM.get_session_param_char(3), 'DD-MON-YYYY HH24:MI:SS'))
   and (mtt.LOGICAL_TRANSACTION = 2 OR mtt.LOGICAL_TRANSACTION IS NULL)
   and (mtt.transaction_type_id <> 2
        and not exists (select 1
                        from mtl_secondary_inventories mtlsub, mtl_secondary_inventories mtlsub1
                        where mtlsub.organization_id=mtt.organization_id
                        and mtlsub.secondary_inventory_name=mtt.transfer_subinventory
                        and mtlsub.asset_inventory=1
                        and mtlsub1.organization_id=mtt.organization_id
                        and mtlsub1.secondary_inventory_name=mtt.subinventory_code
                        and mtlsub1.asset_inventory=1))

   and msi.segment1=XXCS_SESSION_PARAM.get_session_param_char(4)
   and msi.inventory_item_id=mtt.INVENTORY_ITEM_ID
   and msi.organization_id=mtt.ORGANIZATION_ID

UNION ALL


select OHEND.item_number, 'Asset On-Hand(Period End)' "TRANSACTION_TYPE",SUM(OHEND.si_qty) "TRANSACTION_QUANTITY", OHEND.organization_id,
       mtp.organization_code, trunc(OHEND.date_as_of+1) transaction_date, OHEND.org_name
from xxcst_asofdate_onhand OHEND,
     mtl_parameters mtp
where trunc(OHEND.date_as_of)=trunc(to_date(XXCS_SESSION_PARAM.get_session_param_char(3), 'DD-MON-YYYY HH24:MI:SS'))
And OHEND.item_number=XXCS_SESSION_PARAM.get_session_param_char(4)
and OHEND.organization_ID =mtp.organization_id
and mtp.organization_code = nvl(XXCS_SESSION_PARAM.get_session_param_char(1),mtp.organization_code)
and OHEND.org_name=nvl(XXCS_SESSION_PARAM.get_session_param_char(5),OHEND.org_name)
and OHEND.asset_inventory='Yes'
GROUP BY OHEND.item_number,OHEND.organization_id, mtp.organization_code, trunc(OHEND.date_as_of+1),OHEND.org_name

UNION ALL

select OHSTART.item_number, 'Asset On-Hand(Period Start)',SUM(OHSTART.si_qty), OHSTART.organization_id,
       mtp.organization_code,trunc(OHSTART.date_as_of) transaction_date, OHSTART.org_name
from xxcst_asofdate_onhand OHSTART,
     mtl_parameters mtp
where trunc(OHSTART.date_as_of)=trunc(to_date(XXCS_SESSION_PARAM.get_session_param_char(2), 'DD-MON-YYYY HH24:MI:SS')-1/3600)
and OHSTART.item_number=XXCS_SESSION_PARAM.get_session_param_char(4)
and OHSTART.organization_ID =mtp.organization_id
and mtp.organization_code = nvl(XXCS_SESSION_PARAM.get_session_param_char(1),mtp.organization_code)
and OHSTART.org_name=nvl(XXCS_SESSION_PARAM.get_session_param_char(5),OHSTART.org_name)
and OHSTART.asset_inventory='Yes'
GROUP BY OHSTART.item_number,OHSTART.organization_id, mtp.organization_code,trunc(OHSTART.date_as_of),OHSTART.org_name

UNION ALL

select OHEND.item_number, 'Non Asset On-Hand(Period End)',SUM(OHEND.si_qty), OHEND.organization_id,
       mtp.organization_code, trunc(OHEND.date_as_of+1) transaction_date,OHEND.org_name
from xxcst_asofdate_onhand OHEND,
     mtl_parameters mtp
where trunc(OHEND.date_as_of)=trunc(to_date(XXCS_SESSION_PARAM.get_session_param_char(3), 'DD-MON-YYYY HH24:MI:SS'))
and OHEND.item_number=XXCS_SESSION_PARAM.get_session_param_char(4)
and OHEND.organization_ID =mtp.organization_id
and mtp.organization_code = nvl(XXCS_SESSION_PARAM.get_session_param_char(1),mtp.organization_code)
and OHEND.org_name=nvl(XXCS_SESSION_PARAM.get_session_param_char(5),OHEND.org_name)
and OHEND.asset_inventory='No'
GROUP BY OHEND.item_number,OHEND.organization_id, mtp.organization_code,trunc(OHEND.date_as_of+1),OHEND.org_name

UNION ALL

select OHSTART.item_number, 'Non Asset On-Hand(Period Start)',SUM(OHSTART.si_qty), OHSTART.organization_id,
       mtp.organization_code,trunc(OHSTART.date_as_of) transaction_date, OHSTART.org_name
from xxcst_asofdate_onhand OHSTART,
     mtl_parameters mtp
where trunc(OHSTART.date_as_of)=trunc(to_date(XXCS_SESSION_PARAM.get_session_param_char(2), 'DD-MON-YYYY HH24:MI:SS')-1/3600)
and OHSTART.item_number=XXCS_SESSION_PARAM.get_session_param_char(4)
and OHSTART.organization_ID =mtp.organization_id
and mtp.organization_code = nvl(XXCS_SESSION_PARAM.get_session_param_char(1),mtp.organization_code)
and OHSTART.org_name=nvl(XXCS_SESSION_PARAM.get_session_param_char(5),OHSTART.org_name)
and OHSTART.asset_inventory='No'
GROUP BY OHSTART.item_number,OHSTART.organization_id, mtp.organization_code,trunc(OHSTART.date_as_of),OHSTART.org_name

UNION ALL

select OHTRANS.item_number, 'Transit-Incomming',SUM(OHTRANS.si_qty), OHTRANS.organization_id,
       mtp.organization_code, trunc(to_date(trunc(OHTRANS.date_as_of))-1/3600) transaction_date, OHTRANS.org_name
from xxcst_asofdate_onhand OHTRANS,
     mtl_parameters mtp
where trunc(OHTRANS.date_as_of)=trunc(to_date(XXCS_SESSION_PARAM.get_session_param_char(3), 'DD-MON-YYYY HH24:MI:SS'))
and OHTRANS.item_number=XXCS_SESSION_PARAM.get_session_param_char(4)
and OHTRANS.organization_ID =mtp.organization_id
and mtp.organization_code = nvl(XXCS_SESSION_PARAM.get_session_param_char(1),mtp.organization_code)
and OHTRANS.org_name=nvl(XXCS_SESSION_PARAM.get_session_param_char(5),OHTRANS.org_name)
and OHTRANS.asset_inventory='Yes'
AND OHTRANS.subinventory_code='In-Transit'
GROUP BY OHTRANS.item_number,OHTRANS.organization_id, mtp.organization_code,trunc(to_date(trunc(OHTRANS.date_as_of))-1/3600),OHTRANS.org_name) cycle_date,
org_access oa
where  cycle_date.ORGANIZATION_ID=oa.organization_id

and oa.resp_application_id =
       decode(fnd_global.resp_appl_id,
              -1,
              oa.resp_application_id,
              fnd_global.resp_appl_id)
   and oa.responsibility_id =
       decode(fnd_global.resp_id,
              -1,
              oa.responsibility_id,
              fnd_global.resp_id)
order by ORGANIZATION_CODE, transaction_date;

