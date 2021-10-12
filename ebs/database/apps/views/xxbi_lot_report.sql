CREATE OR REPLACE VIEW XXBI_LOT_REPORT AS
SELECT
--------------------------------------------------------------------
--  name:            XXBI_LOT_REPORT
--  create by:
--  Revision:        1.0
--  creation date:   xx/xx/2009
--------------------------------------------------------------------
--  purpose :      Discoverer Report - Lot Expiration
--------------------------------------------------------------------
--  ver  date        name            desc
--  1.0  xx/xx/2009       initial build
--------------------------------------------------------------------
       onhand.organization_code,
       onhand.subinventory,
       onhand.subinventory_desc,
       onhand.locator_segments,
       onhand.item,
       onhand.item_desc,
       onhand.primary_uom_code,
       onhand.lot_number,
       onhand.exp_date,
       onhand.ohqty,
       onhand.eu_min,
       onhand.il_min,
       onhand.us_min,
       onhand.il2_min,
       CASE
          WHEN add_months(SYSDATE, to_number(onhand.eu_min)) >
               onhand.exp_date THEN
           0
          ELSE
           onhand.ohqty
       END AS eu_avail,
       CASE
          WHEN add_months(SYSDATE, to_number(onhand.il_min)) >
               onhand.exp_date THEN
           0
          ELSE
           onhand.ohqty
       END AS il_avail,
       CASE
          WHEN add_months(SYSDATE, to_number(onhand.us_min)) >
               onhand.exp_date THEN
           0
          ELSE
           onhand.ohqty
       END AS us_avail,
       CASE
          WHEN add_months(SYSDATE, to_number(onhand.il2_min)) >
               onhand.exp_date THEN
           0
          ELSE
           onhand.ohqty
       END AS il2_avail,
       CASE
          WHEN add_months(SYSDATE,
                          to_number(decode(operating_unit,
                                           'OBJET US (OU)',
                                           onhand.us_min,
                                           'OBJET DE (OU)',
                                           onhand.eu_min,
                                           onhand.il_min))) >
               onhand.exp_date THEN
           onhand.ohqty
          ELSE
           0
       END AS qty_to_expired
  FROM (SELECT mp.organization_code,
               moqd.subinventory_code AS subinventory,
               msi.description AS subinventory_desc,
               mil.concatenated_segments AS locator_segments,
               msib.segment1 AS item,
               msib.description AS item_desc,
               msib.primary_uom_code,
               mln.lot_number,
               trunc(mln.expiration_date) AS exp_date,
               SUM(moqd.transaction_quantity) AS ohqty,
               nvl(msib.attribute5, 0) AS eu_min,
               nvl(msib.attribute4, 0) AS il_min,
               nvl(msib.attribute6, 0) AS us_min,
               nvl(msib.attribute7, 0) AS il2_min,
               hou.NAME operating_unit
          FROM mtl_lot_numbers              mln,
               mtl_onhand_quantities_detail moqd,
               mtl_system_items_b           msib,
               mtl_secondary_inventories    msi,
               mtl_item_locations_kfv       mil,
               mtl_parameters               mp,
               org_organization_definitions ood,
               hr_operating_units           hou,
               org_access                   oa
         WHERE moqd.inventory_item_id = mln.inventory_item_id AND
               moqd.organization_id = mln.organization_id AND
               mln.inventory_item_id = msib.inventory_item_id AND
               moqd.organization_id = msib.organization_id AND
               moqd.subinventory_code = msi.secondary_inventory_name AND
               moqd.locator_id = mil.inventory_location_id(+) AND
               mil.organization_id(+) = moqd.organization_id AND
               mp.organization_id = moqd.organization_id AND
               mp.organization_id = ood.organization_id AND
               ood.operating_unit = hou.organization_id AND
               oa.organization_id = mp.organization_id AND
               msi.organization_id = moqd.organization_id AND
               moqd.lot_number = mln.lot_number AND
               oa.resp_application_id =
               decode(fnd_global.resp_appl_id,
                      -1,
                      oa.resp_application_id,
                      fnd_global.resp_appl_id) AND
               oa.responsibility_id =
               decode(fnd_global.resp_id,
                      -1,
                      oa.responsibility_id,
                      fnd_global.resp_id)
         GROUP BY mp.organization_code,
                  moqd.subinventory_code,
                  msi.description,
                  mil.concatenated_segments,
                  msib.segment1,
                  msib.description,
                  msib.primary_uom_code,
                  mln.lot_number,
                  hou.NAME,
                  trunc(mln.expiration_date),
                  msib.attribute5,
                  msib.attribute4,
                  msib.attribute6,
                  msib.attribute7) onhand;

