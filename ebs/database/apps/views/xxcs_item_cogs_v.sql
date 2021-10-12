CREATE OR REPLACE VIEW XXCS_ITEM_COGS_V AS
SELECT
--------------------------------------------------------------------
--  name:            XXCS_ITEM_COGS_V
--  create by:       Vitaly.K
--  Revision:        1.3
--  creation date:   22/12/2009
--------------------------------------------------------------------
--  purpose :       Discoverer Reports
--------------------------------------------------------------------
--  ver  date        name             desc
--  1.0  22/12/2009  Vitaly           initial build
--  1.1  20/01/2010  Vitaly --        new field UOM was added
--  1.2  24/02/2010  Vitaly --        new field inventory_organization_id was added
--  1.3  07/04/2010  Vitaly --        Service_billing_type was added, sub-table was created instead of sub-select
--  1.4  06/06/2010  Vitaly           org_id was added
--  1.5  10/09/2013  Vitaly           CR870 -- Average cost_type_id=2 was replaced with fnd_profile.value('XX_COST_TYPE')
--------------------------------------------------------------------
         ITEM_COST.inventory_item_id inventory_item_id
        ,ITEM_COST.ITEM ITEM
        ,ITEM_COST.DESCRIPTION                        "DESCRIPTION"
        ,ITEM_COST.PRIMARY_UOM_CODE                   UOM
        ,ITEM_COST.SERVICE_BILLING_TYPE
        ,ITEM_COST.ORG_ID
        ,ITEM_COST.OU_NAME
        ,ITEM_COST.ORG ORG
        ,ITEM_COST.inventory_organization_id
        ,round(ITEM_COST.ITEM_COST,2)                 ITEM_COST
        ,round(ITEM_COST.MATERIAL_COST , 2)           MATERIAL_COST
        ,round(ITEM_COST.RESOURCE_COST , 2)           RESOURCE_COST
        ,round(ITEM_COST.OUTSIDE_PROCESSING_COST , 2) OUTSIDE_PROCESSING_COST
        ,round(ITEM_COST.MATERIAL_OVERHEAD_COST ,2)   MATERIAL_OVERHEAD_COST
        ,round(ITEM_COST.OVERHEAD_COST  ,2)           OVERHEAD_COST
        ,ITEM_COST.MAKE_BUY
        ,ITEM_COST.MAIN_CATEGORY
        ,ITEM_COST.currency_code
FROM
    (SELECT MSI.INVENTORY_ITEM_ID,
              ---org_dtl.organization_id    ou_code,
              org_dtl.org_id,
              org_dtl.name               ou_name,
              msi.segment1               item,
              msi.description            description,
              decode(msi.material_billable_flag,'M',          'Material',
                                                'XXOBJ_HEADS','Head',
                                                'L',          'Labour',
                                                'E',          'Expence','')   service_billing_type,
              msi.primary_uom_code,
              msi.organization_id,
              io.organization_code       ORG,
              io.organization_id         inventory_organization_id,
              decode (msi.planning_make_buy_code,1,'Make',2,'Buy')   Make_Buy,
              MAIN_CATEGORY_TAB.main_category                        Main_Category,
             c.item_cost,
             c.material_cost,
             c.resource_cost,
             c.outside_processing_cost,
             c.material_overhead_cost,
             c.overhead_cost,
             org_dtl.currency_code
      FROM   MTL_SYSTEM_ITEMS_B    msi,
             CST_ITEM_COSTS        c,
             MTL_PARAMETERS        io,
            (SELECT     ou.organization_id  org_id
                       ,ou.name
                       ,org_ou.ORGANIZATION_ID
                       ,org_ou.ORGANIZATION_CODE
                       ,org_ou.ORGANIZATION_NAME
                       ,gl.currency_code
              FROM    hr_operating_units  ou,
                      gl_ledgers          gl,
                      org_organization_definitions org_ou
              WHERE   ou.set_of_books_id  = gl.ledger_id AND
                      ou.organization_id = org_ou.OPERATING_UNIT)
                                  ORG_DTL,
            (SELECT mic.inventory_item_id,
                    mc.segment3   main_category
             FROM   MTL_ITEM_CATEGORIES   mic,
                    MTL_CATEGORIES_KFV    mc
             WHERE  mic.category_id = mc.category_id AND
                    mic.category_set_id = '1100000041' AND
                    mic.organization_id = xxinv_utils_pkg.get_master_organization_id)
                                   MAIN_CATEGORY_TAB

      WHERE      msi.inventory_item_id   = c.inventory_item_id
             and msi.organization_id     = c.organization_id
             and msi.organization_id     = io.organization_id
             -----and nvl(c.cost_type_id,2)   = 2 /*Average Cost*/
             and nvl(c.cost_type_id,fnd_profile.value('XX_COST_TYPE'))   = fnd_profile.value('XX_COST_TYPE') --Vitaly 10/09/2013
             and c.item_cost             > 0
             AND io.organization_code = org_dtl.organization_code
             AND c.inventory_item_id = MAIN_CATEGORY_TAB.inventory_item_id(+)
                         ) ITEM_COST;
