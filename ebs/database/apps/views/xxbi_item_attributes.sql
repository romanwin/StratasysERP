﻿create or replace view xxbi_item_attributes as
select mp.organization_code,
       msibd."ROW_ID",msibd."CONTEXT",msibd."INVOICE_UOM",msibd."COO",msibd."HS_CODE",msibd."EXP_MIN_MONTH_IL",msibd."EXP_MIN_MONTH_EU",msibd."EXP_MIN_MONTH_US",msibd."EXP_MIN_MONTH_IL_CUST",msibd."QA_CODE",msibd."XX_S_RELATED_ITEM",msibd."REPAIRABLE",msibd."RETURNABLE",msibd."ROHS",msibd."ORIGINAL_ABC_CLASS",msibd."SPEC19",msibd."TOXIC_QTY_ALLOWED",msibd."TAXWARE_CODE",msibd."FORMULATION_NUMBER",msibd."MODULE___SUPPORT",msibd."CONCATENATED_SEGMENTS",
       msib."INVENTORY_ITEM_ID",msib."ORGANIZATION_ID",msib."LAST_UPDATE_DATE",msib."LAST_UPDATED_BY",msib."CREATION_DATE",msib."CREATED_BY",msib."LAST_UPDATE_LOGIN",msib."SUMMARY_FLAG",msib."ENABLED_FLAG",msib."START_DATE_ACTIVE",msib."END_DATE_ACTIVE",msib."DESCRIPTION",msib."BUYER_ID",msib."ACCOUNTING_RULE_ID",msib."INVOICING_RULE_ID",msib."SEGMENT1",msib."SEGMENT2",msib."SEGMENT3",msib."SEGMENT4",msib."SEGMENT5",msib."SEGMENT6",msib."SEGMENT7",msib."SEGMENT8",msib."SEGMENT9",msib."SEGMENT10",msib."SEGMENT11",msib."SEGMENT12",msib."SEGMENT13",msib."SEGMENT14",msib."SEGMENT15",msib."SEGMENT16",msib."SEGMENT17",msib."SEGMENT18",msib."SEGMENT19",msib."SEGMENT20",msib."ATTRIBUTE_CATEGORY",msib."ATTRIBUTE1",msib."ATTRIBUTE2",msib."ATTRIBUTE3",msib."ATTRIBUTE4",msib."ATTRIBUTE5",msib."ATTRIBUTE6",msib."ATTRIBUTE7",msib."ATTRIBUTE8",msib."ATTRIBUTE9",msib."ATTRIBUTE10",msib."ATTRIBUTE11",msib."ATTRIBUTE12",msib."ATTRIBUTE13",msib."ATTRIBUTE14",msib."ATTRIBUTE15",msib."PURCHASING_ITEM_FLAG",msib."SHIPPABLE_ITEM_FLAG",msib."CUSTOMER_ORDER_FLAG",msib."INTERNAL_ORDER_FLAG",msib."SERVICE_ITEM_FLAG",msib."INVENTORY_ITEM_FLAG",msib."ENG_ITEM_FLAG",msib."INVENTORY_ASSET_FLAG",msib."PURCHASING_ENABLED_FLAG",msib."CUSTOMER_ORDER_ENABLED_FLAG",msib."INTERNAL_ORDER_ENABLED_FLAG",msib."SO_TRANSACTIONS_FLAG",msib."MTL_TRANSACTIONS_ENABLED_FLAG",msib."STOCK_ENABLED_FLAG",msib."BOM_ENABLED_FLAG",msib."BUILD_IN_WIP_FLAG",msib."REVISION_QTY_CONTROL_CODE",msib."ITEM_CATALOG_GROUP_ID",msib."CATALOG_STATUS_FLAG",msib."RETURNABLE_FLAG",msib."DEFAULT_SHIPPING_ORG",msib."COLLATERAL_FLAG",msib."TAXABLE_FLAG",msib."QTY_RCV_EXCEPTION_CODE",msib."ALLOW_ITEM_DESC_UPDATE_FLAG",msib."INSPECTION_REQUIRED_FLAG",msib."RECEIPT_REQUIRED_FLAG",msib."MARKET_PRICE",msib."HAZARD_CLASS_ID",msib."RFQ_REQUIRED_FLAG",msib."QTY_RCV_TOLERANCE",msib."LIST_PRICE_PER_UNIT",msib."UN_NUMBER_ID",msib."PRICE_TOLERANCE_PERCENT",msib."ASSET_CATEGORY_ID",msib."ROUNDING_FACTOR",msib."UNIT_OF_ISSUE",msib."ENFORCE_SHIP_TO_LOCATION_CODE",msib."ALLOW_SUBSTITUTE_RECEIPTS_FLAG",msib."ALLOW_UNORDERED_RECEIPTS_FLAG",msib."ALLOW_EXPRESS_DELIVERY_FLAG",msib."DAYS_EARLY_RECEIPT_ALLOWED",msib."DAYS_LATE_RECEIPT_ALLOWED",msib."RECEIPT_DAYS_EXCEPTION_CODE",msib."RECEIVING_ROUTING_ID",msib."INVOICE_CLOSE_TOLERANCE",msib."RECEIVE_CLOSE_TOLERANCE",msib."AUTO_LOT_ALPHA_PREFIX",msib."START_AUTO_LOT_NUMBER",msib."LOT_CONTROL_CODE",msib."SHELF_LIFE_CODE",msib."SHELF_LIFE_DAYS",msib."SERIAL_NUMBER_CONTROL_CODE",msib."START_AUTO_SERIAL_NUMBER",msib."AUTO_SERIAL_ALPHA_PREFIX",msib."SOURCE_TYPE",msib."SOURCE_ORGANIZATION_ID",msib."SOURCE_SUBINVENTORY",msib."EXPENSE_ACCOUNT",msib."ENCUMBRANCE_ACCOUNT",msib."RESTRICT_SUBINVENTORIES_CODE",msib."UNIT_WEIGHT",msib."WEIGHT_UOM_CODE",msib."VOLUME_UOM_CODE",msib."UNIT_VOLUME",msib."RESTRICT_LOCATORS_CODE",msib."LOCATION_CONTROL_CODE",msib."SHRINKAGE_RATE",msib."ACCEPTABLE_EARLY_DAYS",msib."PLANNING_TIME_FENCE_CODE",msib."DEMAND_TIME_FENCE_CODE",msib."LEAD_TIME_LOT_SIZE",msib."STD_LOT_SIZE",msib."CUM_MANUFACTURING_LEAD_TIME",msib."OVERRUN_PERCENTAGE",msib."MRP_CALCULATE_ATP_FLAG",msib."ACCEPTABLE_RATE_INCREASE",msib."ACCEPTABLE_RATE_DECREASE",msib."CUMULATIVE_TOTAL_LEAD_TIME",msib."PLANNING_TIME_FENCE_DAYS",msib."DEMAND_TIME_FENCE_DAYS",msib."END_ASSEMBLY_PEGGING_FLAG",msib."REPETITIVE_PLANNING_FLAG",msib."PLANNING_EXCEPTION_SET",msib."BOM_ITEM_TYPE",msib."PICK_COMPONENTS_FLAG",msib."REPLENISH_TO_ORDER_FLAG",msib."BASE_ITEM_ID",msib."ATP_COMPONENTS_FLAG",msib."ATP_FLAG",msib."FIXED_LEAD_TIME",msib."VARIABLE_LEAD_TIME",msib."WIP_SUPPLY_LOCATOR_ID",msib."WIP_SUPPLY_TYPE",msib."WIP_SUPPLY_SUBINVENTORY",msib."PRIMARY_UOM_CODE",msib."PRIMARY_UNIT_OF_MEASURE",msib."ALLOWED_UNITS_LOOKUP_CODE",msib."COST_OF_SALES_ACCOUNT",msib."SALES_ACCOUNT",msib."DEFAULT_INCLUDE_IN_ROLLUP_FLAG",msib."INVENTORY_ITEM_STATUS_CODE",msib."INVENTORY_PLANNING_CODE",msib."PLANNER_CODE",msib."PLANNING_MAKE_BUY_CODE",msib."FIXED_LOT_MULTIPLIER",msib."ROUNDING_CONTROL_TYPE",msib."CARRYING_COST",msib."POSTPROCESSING_LEAD_TIME",msib."PREPROCESSING_LEAD_TIME",msib."FULL_LEAD_TIME",msib."ORDER_COST",msib."MRP_SAFETY_STOCK_PERCENT",msib."MRP_SAFETY_STOCK_CODE",msib."MIN_MINMAX_QUANTITY",msib."MAX_MINMAX_QUANTITY",msib."MINIMUM_ORDER_QUANTITY",msib."FIXED_ORDER_QUANTITY",msib."FIXED_DAYS_SUPPLY",msib."MAXIMUM_ORDER_QUANTITY",msib."ATP_RULE_ID",msib."PICKING_RULE_ID",msib."RESERVABLE_TYPE",msib."POSITIVE_MEASUREMENT_ERROR",msib."NEGATIVE_MEASUREMENT_ERROR",msib."ENGINEERING_ECN_CODE",msib."ENGINEERING_ITEM_ID",msib."ENGINEERING_DATE",msib."SERVICE_STARTING_DELAY",msib."VENDOR_WARRANTY_FLAG",msib."SERVICEABLE_COMPONENT_FLAG",msib."SERVICEABLE_PRODUCT_FLAG",msib."BASE_WARRANTY_SERVICE_ID",msib."PAYMENT_TERMS_ID",msib."PREVENTIVE_MAINTENANCE_FLAG",msib."PRIMARY_SPECIALIST_ID",msib."SECONDARY_SPECIALIST_ID",msib."SERVICEABLE_ITEM_CLASS_ID",msib."TIME_BILLABLE_FLAG",msib."MATERIAL_BILLABLE_FLAG",msib."EXPENSE_BILLABLE_FLAG",msib."PRORATE_SERVICE_FLAG",msib."COVERAGE_SCHEDULE_ID",msib."SERVICE_DURATION_PERIOD_CODE",msib."SERVICE_DURATION",msib."WARRANTY_VENDOR_ID",msib."MAX_WARRANTY_AMOUNT",msib."RESPONSE_TIME_PERIOD_CODE",msib."RESPONSE_TIME_VALUE",msib."NEW_REVISION_CODE",msib."INVOICEABLE_ITEM_FLAG",msib."TAX_CODE",msib."INVOICE_ENABLED_FLAG",msib."MUST_USE_APPROVED_VENDOR_FLAG",msib."REQUEST_ID",msib."PROGRAM_APPLICATION_ID",msib."PROGRAM_ID",msib."PROGRAM_UPDATE_DATE",msib."OUTSIDE_OPERATION_FLAG",msib."OUTSIDE_OPERATION_UOM_TYPE",msib."SAFETY_STOCK_BUCKET_DAYS",msib."AUTO_REDUCE_MPS",msib."COSTING_ENABLED_FLAG",msib."AUTO_CREATED_CONFIG_FLAG",msib."CYCLE_COUNT_ENABLED_FLAG",msib."ITEM_TYPE",msib."MODEL_CONFIG_CLAUSE_NAME",msib."SHIP_MODEL_COMPLETE_FLAG",msib."MRP_PLANNING_CODE",msib."RETURN_INSPECTION_REQUIREMENT",msib."ATO_FORECAST_CONTROL",msib."RELEASE_TIME_FENCE_CODE",msib."RELEASE_TIME_FENCE_DAYS",msib."CONTAINER_ITEM_FLAG",msib."VEHICLE_ITEM_FLAG",msib."MAXIMUM_LOAD_WEIGHT",msib."MINIMUM_FILL_PERCENT",msib."CONTAINER_TYPE_CODE",msib."INTERNAL_VOLUME",msib."WH_UPDATE_DATE",msib."PRODUCT_FAMILY_ITEM_ID",msib."GLOBAL_ATTRIBUTE_CATEGORY",msib."GLOBAL_ATTRIBUTE1",msib."GLOBAL_ATTRIBUTE2",msib."GLOBAL_ATTRIBUTE3",msib."GLOBAL_ATTRIBUTE4",msib."GLOBAL_ATTRIBUTE5",msib."GLOBAL_ATTRIBUTE6",msib."GLOBAL_ATTRIBUTE7",msib."GLOBAL_ATTRIBUTE8",msib."GLOBAL_ATTRIBUTE9",msib."GLOBAL_ATTRIBUTE10",msib."PURCHASING_TAX_CODE",msib."OVERCOMPLETION_TOLERANCE_TYPE",msib."OVERCOMPLETION_TOLERANCE_VALUE",msib."EFFECTIVITY_CONTROL",msib."CHECK_SHORTAGES_FLAG",msib."OVER_SHIPMENT_TOLERANCE",msib."UNDER_SHIPMENT_TOLERANCE",msib."OVER_RETURN_TOLERANCE",msib."UNDER_RETURN_TOLERANCE",msib."EQUIPMENT_TYPE",msib."RECOVERED_PART_DISP_CODE",msib."DEFECT_TRACKING_ON_FLAG",msib."USAGE_ITEM_FLAG",msib."EVENT_FLAG",msib."ELECTRONIC_FLAG",msib."DOWNLOADABLE_FLAG",msib."VOL_DISCOUNT_EXEMPT_FLAG",msib."COUPON_EXEMPT_FLAG",msib."COMMS_NL_TRACKABLE_FLAG",msib."ASSET_CREATION_CODE",msib."COMMS_ACTIVATION_REQD_FLAG",msib."ORDERABLE_ON_WEB_FLAG",msib."BACK_ORDERABLE_FLAG",msib."WEB_STATUS",msib."INDIVISIBLE_FLAG",msib."DIMENSION_UOM_CODE",msib."UNIT_LENGTH",msib."UNIT_WIDTH",msib."UNIT_HEIGHT",msib."BULK_PICKED_FLAG",msib."LOT_STATUS_ENABLED",msib."DEFAULT_LOT_STATUS_ID",msib."SERIAL_STATUS_ENABLED",msib."DEFAULT_SERIAL_STATUS_ID",msib."LOT_SPLIT_ENABLED",msib."LOT_MERGE_ENABLED",msib."INVENTORY_CARRY_PENALTY",msib."OPERATION_SLACK_PENALTY",msib."FINANCING_ALLOWED_FLAG",msib."EAM_ITEM_TYPE",msib."EAM_ACTIVITY_TYPE_CODE",msib."EAM_ACTIVITY_CAUSE_CODE",msib."EAM_ACT_NOTIFICATION_FLAG",msib."EAM_ACT_SHUTDOWN_STATUS",msib."DUAL_UOM_CONTROL",msib."SECONDARY_UOM_CODE",msib."DUAL_UOM_DEVIATION_HIGH",msib."DUAL_UOM_DEVIATION_LOW",msib."CONTRACT_ITEM_TYPE_CODE",msib."SUBSCRIPTION_DEPEND_FLAG",msib."SERV_REQ_ENABLED_CODE",msib."SERV_BILLING_ENABLED_FLAG",msib."SERV_IMPORTANCE_LEVEL",msib."PLANNED_INV_POINT_FLAG",msib."LOT_TRANSLATE_ENABLED",msib."DEFAULT_SO_SOURCE_TYPE",msib."CREATE_SUPPLY_FLAG",msib."SUBSTITUTION_WINDOW_CODE",msib."SUBSTITUTION_WINDOW_DAYS",msib."IB_ITEM_INSTANCE_CLASS",msib."CONFIG_MODEL_TYPE",msib."LOT_SUBSTITUTION_ENABLED",msib."MINIMUM_LICENSE_QUANTITY",msib."EAM_ACTIVITY_SOURCE_CODE",msib."LIFECYCLE_ID",msib."CURRENT_PHASE_ID",msib."OBJECT_VERSION_NUMBER",msib."TRACKING_QUANTITY_IND",msib."ONT_PRICING_QTY_SOURCE",msib."SECONDARY_DEFAULT_IND",msib."OPTION_SPECIFIC_SOURCED",msib."APPROVAL_STATUS",msib."VMI_MINIMUM_UNITS",msib."VMI_MINIMUM_DAYS",msib."VMI_MAXIMUM_UNITS",msib."VMI_MAXIMUM_DAYS",msib."VMI_FIXED_ORDER_QUANTITY",msib."SO_AUTHORIZATION_FLAG",msib."CONSIGNED_FLAG",msib."ASN_AUTOEXPIRE_FLAG",msib."VMI_FORECAST_TYPE",msib."FORECAST_HORIZON",msib."EXCLUDE_FROM_BUDGET_FLAG",msib."DAYS_TGT_INV_SUPPLY",msib."DAYS_TGT_INV_WINDOW",msib."DAYS_MAX_INV_SUPPLY",msib."DAYS_MAX_INV_WINDOW",msib."DRP_PLANNED_FLAG",msib."CRITICAL_COMPONENT_FLAG",msib."CONTINOUS_TRANSFER",msib."CONVERGENCE",msib."DIVERGENCE",msib."CONFIG_ORGS",msib."CONFIG_MATCH",msib."ATTRIBUTE16",msib."ATTRIBUTE17",msib."ATTRIBUTE18",msib."ATTRIBUTE19",msib."ATTRIBUTE20",msib."ATTRIBUTE21",msib."ATTRIBUTE22",msib."ATTRIBUTE23",msib."ATTRIBUTE24",msib."ATTRIBUTE25",msib."ATTRIBUTE26",msib."ATTRIBUTE27",msib."ATTRIBUTE28",msib."ATTRIBUTE29",msib."ATTRIBUTE30",msib."CAS_NUMBER",msib."CHILD_LOT_FLAG",msib."CHILD_LOT_PREFIX",msib."CHILD_LOT_STARTING_NUMBER",msib."CHILD_LOT_VALIDATION_FLAG",msib."COPY_LOT_ATTRIBUTE_FLAG",msib."DEFAULT_GRADE",msib."EXPIRATION_ACTION_CODE",msib."EXPIRATION_ACTION_INTERVAL",msib."GRADE_CONTROL_FLAG",msib."HAZARDOUS_MATERIAL_FLAG",msib."HOLD_DAYS",msib."LOT_DIVISIBLE_FLAG",msib."MATURITY_DAYS",msib."PARENT_CHILD_GENERATION_FLAG",msib."PROCESS_COSTING_ENABLED_FLAG",msib."PROCESS_EXECUTION_ENABLED_FLAG",msib."PROCESS_QUALITY_ENABLED_FLAG",msib."PROCESS_SUPPLY_LOCATOR_ID",msib."PROCESS_SUPPLY_SUBINVENTORY",msib."PROCESS_YIELD_LOCATOR_ID",msib."PROCESS_YIELD_SUBINVENTORY",msib."RECIPE_ENABLED_FLAG",msib."RETEST_INTERVAL",msib."CHARGE_PERIODICITY_CODE",msib."REPAIR_LEADTIME",msib."REPAIR_YIELD",msib."PREPOSITION_POINT",msib."REPAIR_PROGRAM",msib."SUBCONTRACTING_COMPONENT",msib."OUTSOURCED_ASSEMBLY",msib."EGO_MASTER_ITEMS_DFF_CTX",
       (select 'Y'
          from BOM_OPERATIONAL_ROUTINGS r
         where r.assembly_item_id = msib.inventory_item_id
           and r.organization_id = msib.organization_id) as routing_exists_in_org,
        (select 'Y'
        from PO_ASL_SUPPLIERS_V p
        where p.item_id = msib.inventory_item_id  ) as PO_ASL_EXISTS,
        (select 'Y'
        from  qp_list_lines_v q
        where q.product_attr_value = msib.inventory_item_id
        and rownum=1) as ITEM_IN_PRICE_LISTS
  from mtl_system_items_b_dfv msibd,
       mtl_parameters         mp,
       mtl_system_items_b     msib
 where msibd.row_id = msib.rowid
   and mp.organization_id = msib.organization_id;

