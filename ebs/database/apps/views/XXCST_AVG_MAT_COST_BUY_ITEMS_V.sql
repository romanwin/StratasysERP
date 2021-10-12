CREATE OR REPLACE VIEW XXCST_AVG_MAT_COST_BUY_ITEMS_V AS
select
--------------------------------------------------------------------------
-- XXCST_AVG_MAT_COST_BUY_ITEMS_V
--
-- Purpose: Discoverer report XX: Average Material Cost for Buy Items
-- This view is designed to define items which are only buy items and that
-- have PO receipts in the material distribution.  This view will be a basis for
-- a report that displays the average material cost per item/organization in a period
-- of time.  This will help finance team define the standard cost for buy items.
---------------------------------------------------------------------------
-- Version  Date      Performer       Comments
----------  --------  --------------  -------------------------------------
--   1.0  17.11.2013  Vitaly          Initial Build
---------------------------------------------------------------------------
       unique msi.inventory_item_id,
       msi.segment1       item,
       msi.description    item_description,
       mp.organization_id,
       mp.organization_code,
       a.transaction_date,
      ROUND( sum(a.unit_cost) over (partition by a.inventory_item_id,a.organization_id)/count(a.unit_cost) over (partition by a.inventory_item_id,a.organization_id),2)AVG_MAT_COST
      ,(SELECT ROUND(CICD.ITEM_COST,2)
      FROM CST_ITEM_COST_DETAILS CICD
      WHERE CICD.INVENTORY_ITEM_ID=A.inventory_item_id
            AND CICD.COST_TYPE_ID=1
            AND CICD.ORGANIZATION_ID=A.organization_id
            AND CICD.COST_ELEMENT_ID=1)ITEM_COST,
             APPS.XXCST_GENERAL_PKG.GET_BUY_ITEM_LAST_UNIT_PRICE(A.INVENTORY_ITEM_ID)LAST_UNIT_PRICE_USD,
       xxcst_general_pkg.get_buy_item_last_need_by_date(A.INVENTORY_ITEM_ID)LAST_NEED_BY_DATE
      -- count(a.unit_cost) over (partition by a.inventory_item_id,a.organization_id)
            from cst_inv_distribution_v a,
            MTL_PARAMETERS         mp,
             MTL_SYSTEM_ITEMS_B     msi

            where a.transaction_type_id = 18 -------po receipt
            and a.line_type_name = 'Receiving Inspection'
            and a.organization_id=mp.organization_id
            and a.inventory_item_id=msi.inventory_item_id
            and mp.organization_id=msi.organization_id
            and msi.planning_make_buy_code=2
          --  and msi.segment1 in ('OBJ-01007');
