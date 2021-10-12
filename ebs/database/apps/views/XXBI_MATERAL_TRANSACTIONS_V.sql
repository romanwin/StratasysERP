CREATE OR REPLACE VIEW XXBI_MATERAL_TRANSACTIONS_V AS
(
SELECT 
--------------------------------------------------------------------------------------------------------------------
--  Ver  When          Who         Description
--  ---  ----------    ---------   ---------------------------------------------------------------------------------
--  2.0  20-09-2018    Ofer Suad   CHG0042478 - Automtically choose time based on location Operating unit timezone  
--                                              and do not take T&B that return to NA subinv  
--------------------------------------------------------------------------------------------------------------------
org_name,
               xaq_open.item_number,
               xaq_open.item_description,
               sum(si_qty) Qty_open_balance,
               'AS_OF_DATE BALANCE' transaction_type,
               null Amount,
               null GL_Account,
               case
                 when xxinv_utils_pkg.is_fdm_item(xaq_open.inventory_item_id) = 'N' or
                      decode(org_id, 737, mb.attribute2, 'IL') = 'IL' or
                      xxcst_ratam_pkg.is_MB_Item(xaq_open.inventory_item_id) = 'Y' then
                  'Y'
                 else
                  'N'
               end Is_UR,
               xaq_open.date_as_of,
               xaq_open.organization_code

          FROM xxobj_asofdate_qty_cst xaq_open, mtl_system_items_b mb
         where org_id != 81
         and xaq_open.asset_inventory!=2
           and mb.inventory_item_id = xaq_open.inventory_item_id
           and mb.organization_id = xxinv_utils_pkg.get_master_organization_id
           and xaq_open.subinventory_code is not null
         group by org_name,
                  xaq_open.item_number,
                  xaq_open.item_description,
                  xaq_open.inventory_item_id,
                  mb.attribute2,
                  xaq_open.date_as_of,
                  org_id,
                  xaq_open.organization_code
       union all          
        select hu.name,
       mb.segment1,
       mb.description,
       sum(qsb.quantity_total),
       'AS_OF_DATE BALANCE' transaction_type,
        null Amount,
        null GL_Account,
               case
                 when xxinv_utils_pkg.is_fdm_item(qsb.item_id) = 'N' or
                      decode(org_id, 737, mb.attribute2, 'IL') = 'IL' or
                      xxcst_ratam_pkg.is_MB_Item(qsb.item_id) = 'Y' then
                  'Y'
                 else
                  'N'
               end Is_UR,
               qsb.date_as_of,
               'Try And Buy'
  from xxobjt_ratam_qty_subs qsb,
       hr_operating_units hu,
       mtl_system_items_b           mb
 where hu.organization_id= qsb.org_id
   and mb.inventory_item_id = qsb.item_id
   and mb.organization_id = xxinv_utils_pkg.get_master_organization_id
   and qsb.organization_id='-99'||qsb.org_id
  group by 
  hu.name,
       mb.segment1,
       mb.description,
       qsb.date_as_of,
       qsb.item_id,
       mb.attribute2,
       org_id          
                
                  
        union all
        sELECT org_name,
               xaq_open.item_number,
               xaq_open.item_description,
               sum(si_qty) Qty_open_balance,
               'AS_OF_DATE BALANCE - In Transit' transaction_type,
                null Amount,
               null GL_Account,
               case
                 when xxinv_utils_pkg.is_fdm_item(xaq_open.inventory_item_id) = 'N' or
                      decode(org_id, 737, mb.attribute2, 'IL') = 'IL' or
                      xxcst_ratam_pkg.is_MB_Item(xaq_open.inventory_item_id) = 'Y' then
                  'Y'
                 else
                  'N'
               end Is_UR,
               xaq_open.date_as_of,
               xaq_open.organization_code
          FROM xxobj_asofdate_qty_cst xaq_open, mtl_system_items_b mb
         where org_id != 81
        -- and xaq_open.asset_inventory!=2
           and mb.inventory_item_id = xaq_open.inventory_item_id
           and mb.organization_id =  xxinv_utils_pkg.get_master_organization_id
           and xaq_open.subinventory_code is null
         group by org_name,
                  xaq_open.item_number,
                  xaq_open.item_description,
                  xaq_open.inventory_item_id,
                  mb.attribute2,
                  xaq_open.date_as_of,
                  org_id,
                  xaq_open.organization_code
union all
select name,
       segment1,
       description,
       sum(transaction_quantity),
       transaction_type_name,
       Amount,
       GL_Account,
       Is_UR,
       transaction_date,
        organization_code
  from (select ou.name,
               msi.segment1,
               msi.description,
               (mmt.transaction_quantity),
               mtt.transaction_type_name,
               /*case
               when mmt.primary_quantity < 0 then*/
                                 (select  ltrim(rtrim(xmlagg(xmlelement(e, Amount|| ';'))
                           .extract('//text()'),
                           ';'),
                     ';')
from 

               (select case
                         when gcc.segment3 != '132300' then
                         to_char(mta.base_transaction_value)
                         else
                          (SELECT  
                          ltrim(rtrim(xmlagg(xmlelement(e, mta.base_transaction_value|| ';'))
                           .extract('//text()'),
                           ';'),
                     ';')
                             FROM mtl_material_transactions mmt1,
                                  mtl_transaction_accounts  mta1,
                                  gl_code_combinations      gcc1
                            where mmt1.trx_source_line_id =
                                  mmt.trx_source_line_id
                              and mmt1.transaction_action_id = 36
                              and mta1.transaction_id = mmt1.transaction_id
                              and gcc1.code_combination_id =
                                  mta1.reference_account
                              and gcc1.segment3 != gcc.segment3
                              and gcc.segment3 != '132300')
                       end Amount
                  from mtl_transaction_accounts mta, gl_code_combinations gcc
                 where mta.reference_account = gcc.code_combination_id
                   and mta.transaction_id = mmt.transaction_id
                   and mta.organization_id = mmt.organization_id
                   and mta.accounting_line_type not in
                       (1,  10, 14, 15,  5)
                   and nvl(mta.cost_element_id, 1) = 1
                               )) Amount,
               
               (select  ltrim(rtrim(xmlagg(xmlelement(e, GL_Account|| ';'))
                           .extract('//text()'),
                           ';'),
                     ';')
from 

               (select case
                         when gcc.segment3 != '132300' then
                         gcc.segment3
                         else
                          (SELECT ltrim(rtrim(xmlagg(xmlelement(e, gcc.segment3|| ';'))
                           .extract('//text()'),
                           ';'),
                     ';')
                          --distinct gcc1.segment3
                             FROM mtl_material_transactions mmt1,
                                  mtl_transaction_accounts  mta1,
                                  gl_code_combinations      gcc1
                            where mmt1.trx_source_line_id =
                                  mmt.trx_source_line_id
                              and mmt1.transaction_action_id = 36
                              and mta1.transaction_id = mmt1.transaction_id
                              and gcc1.code_combination_id =
                                  mta1.reference_account
                              and gcc1.segment3 != gcc.segment3
                              and gcc.segment3 != '132300')
                       end GL_Account
                  from mtl_transaction_accounts mta, gl_code_combinations gcc
                 where mta.reference_account = gcc.code_combination_id
                   and mta.transaction_id = mmt.transaction_id
                   and mta.organization_id = mmt.organization_id
                   and mta.accounting_line_type not in
                       (1,  10, 14, 15,  5)
                   and nvl(mta.cost_element_id, 1) = 1
                               )) GL_Account,
               case
                 when xxinv_utils_pkg.is_fdm_item(msi.inventory_item_id) = 'N' or
                      decode(org.OPERATING_UNIt, 737, msi.attribute2, 'IL') = 'IL' or
                      xxcst_ratam_pkg.is_MB_Item(msi.inventory_item_id) = 'Y' then
                  'Y'
                 else
                  'N'
               end Is_UR,
               trunc(mmt.transaction_date) transaction_date,
               org.ORGANIZATION_CODE
          from mtl_material_transactions    mmt,
               mtl_system_items_b           msi,
               mtl_transaction_types        mtt,
               org_organization_definitions org,
               hr_operating_units           ou/*,
               apps.wip_discrete_jobs_v     wip*/
         where mmt.inventory_item_id = msi.inventory_item_id
           and msi.organization_id= xxinv_utils_pkg.get_master_organization_id
           and mmt.transaction_type_id = mtt.transaction_type_id
           and ou.organization_id = org.OPERATING_UNIt
           and mmt.transaction_type_id in (
                                           1,
                                           31,
                                           40,
                                           41,
                                           4,
                                           5,
                                           3,
                                           54,
                                           62,
                                           95,
                                           61,
                                           72,
                                           96,
                                           34,
                                          52,
                                            53,
                                           50,
                                           12,
                                           21,
                                           63,
                                           64,
                                           100,
                                           8,
                                           9,
                                           71,
                                           18,
                                           36,
                                           15,
                                           37,
                                           33,
                                           2,
                                           93,
                                           44,--
                                           17,--
                                           35,--
                                           38,--
                                           48,--
                                           43,--
                                           91,
                                           120
                                        )
           AND mmt.organization_id = org.organization_id
           --and mmt.transaction_source_id = wip.wip_entity_id(+)
          -- and nvl(wip.class_code, 'Standard') = 'Standard'
           and ou.organization_id != 81
           and msi.inventory_asset_flag='Y'
            /*and not exists(select 1
           from mtl_secondary_inventories msii,
                mtl_secondary_inventories msi2
           where msii.secondary_inventory_name= mmt.subinventory_code
           and msii.organization_id=mmt.organization_id
           and  (msii.ASSET_INVENTORY=2 or msii.quantity_tracked=2)
           and ( (mmt.transfer_subinventory is null) or (
             msi2.secondary_inventory_name= mmt.transfer_subinventory
           and msi2.organization_id=mmt.transfer_organization_id
           and (msi2.ASSET_INVENTORY=2 or msi2.quantity_tracked=2))))*/
           and not exists(select 1
           from mtl_secondary_inventories msii
           where msii.secondary_inventory_name= mmt.subinventory_code
           and msii.organization_id=mmt.organization_id
           and  (msii.ASSET_INVENTORY=2 or msii.quantity_tracked=2)
          /* and mmt.transaction_quantity>0*/))
 --where transaction_date between '01-apr-2017' and '30-jun-2017'
 group by name,
          segment1,
          description,
          transaction_type_name, 
          Amount,
          GL_Account,
          Is_UR,
          transaction_date,
          ORGANIZATION_CODE)
/