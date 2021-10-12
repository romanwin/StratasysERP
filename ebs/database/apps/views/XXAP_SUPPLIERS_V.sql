------------------------------------------------------------------------------
--  Program             :  AP Suppliers View
--  Filename            :  xxapsuppliersv.sql
--
--  Description         :  Corresponding information on the form can be found
--                      :  under the AP Vendors menu selection.
--                      :  Includes a ZERO row to avoid Outer joins in Discoverer
--                      :  and OBIEE reporting
--
--  Created By          :  John Hendrickson
--  Creation Date       :  July 7, 2014
--
--  Change History      : V1.0
--  .......................................................................
--   ver  date               name                             desc
--   1.0  7/07/2014    John Hendrickson           CHG0032283 initial build 
------------------------------------------------------------------------------
CREATE OR REPLACE VIEW xxbi.xxap_suppliers_v
(supplier_id,
    supplier_num,
    supplier_name,
    start_date_active,
    end_date_active,
    sup_creation_date,
    sup_created_by,
    sub_last_update_date,
    sub_last_updated_by,
    PARTY_ID,
    SOURCE_SUPPLIER_ID,
    SOURCE_SUPPLIER_NUM,
    ENABLED_FLAG,
    VENDOR_TYPE_LOOKUP_CODE,
    PAY_GROUP_LOOKUP_CODE,
    PAYMENT_CURRENCY_CODE,
    NUM_1099,
    TYPE_1099,
    TAX_REPORTING_NAME,
    FEDERAL_REPORTABLE_FLAG,
    EXCLUSIVE_PAYMENT_FLAG,
    HOLD_ALL_PAYMENT_FLAG,
    VENDOR_NAME_ALT,
    MINORITY_GROUP_LOOKUP_CODE,
    ATTRIBUTE1,
    ATTRIBUTE2,
    ATTRIBUTE3,
    ATTRIBUTE4,
    ATTRIBUTE5,
    ATTRIBUTE6,
    ATTRIBUTE7,
    ATTRIBUTE8,
    ATTRIBUTE9,
    ATTRIBUTE10
    )
AS
  SELECT aps.vendor_id supplier_id,
    aps.segment1 supplier_num,
    aps.vendor_name supplier_name,
    aps.start_date_active start_date_active,
    aps.end_date_active end_date_active,
    aps.creation_date sup_creation_date,
    NVL (papf.full_name, fu.user_name) sup_created_by,
    aps.last_update_date sub_last_update_date,
    NVL (papf2.full_name, fu2.user_name) sub_last_updated_by,
    aps.party_id PARTY_ID,
    aps.attribute5 SOURCE_SUPPLIER_ID,
    aps.attribute6 SOURCE_SUPPLIER_NUM,
    aps.enabled_flag ENABLED_FLAG,
    aps.vendor_type_lookup_code VENDOR_TYPE_LOOKUP_CODE,
    aps.pay_group_lookup_code PAY_GROUP_LOOKUP_CODE,
    aps.payment_currency_code PAYMENT_CURRENCY_CODE,
    aps.num_1099 NUM_1099,
    aps.type_1099 TYPE_1099,
    aps.tax_reporting_name TAX_REPORTING_NAME,
    aps.federal_reportable_flag FEDERAL_REPORTABLE_FLAG,
    aps.exclusive_payment_flag EXCLUSIVE_PAYMENT_FLAG,
    aps.hold_all_payments_flag HOLD_ALL_PAYMENT_FLAG,
    aps.vendor_name_alt VENDOR_NAME_ALT,
    aps.minority_group_lookup_code MINORITY_GROUP_LOOKUP_CODE,
    aps.attribute1 ATTRIBUTE1,
    aps.attribute2 ATTRIBUTE2,
    aps.attribute3 ATTRIBUTE3,
    aps.attribute4 ATTRIBUTE4,
    aps.attribute5 ATTRIBUTE5,
    aps.attribute6 ATTRIBUTE6,
    aps.attribute7 ATTRIBUTE7,
    aps.attribute8 ATTRIBUTE8,
    aps.attribute9 ATTRIBUTE9,
    aps.attribute10 ATTRIBUTE10
  FROM apps.ap_suppliers APS,
    apps.fnd_user fu,
    apps.per_all_people_f papf,
    apps.fnd_user fu2,
    apps.per_all_people_f papf2
  WHERE aps.created_by = fu.user_id
  AND fu.employee_id = papf.person_id(+)
  AND TRUNC (SYSDATE) BETWEEN papf.EFFECTIVE_START_DATE(+) AND papf.EFFECTIVE_END_DATE(+)
  AND aps.last_updated_by = fu2.user_id
  AND fu2.employee_id     = papf2.person_id(+)
  AND TRUNC (SYSDATE) BETWEEN papf2.EFFECTIVE_START_DATE(+) AND papf2.EFFECTIVE_END_DATE(+)
UNION ALL
SELECT 
    0
    ,'null'
    ,'null'
    ,sysdate
    ,sysdate
    ,sysdate
    ,'null'
    ,sysdate
    ,'null'
    ,0
    ,'null'
    ,'null'
    ,'null'
    ,'null'
    ,'null'
    ,'null'
    ,'null'
    ,'null'
    ,'null'
    ,'null'
    ,'null'
    ,'null'
    ,'null'
    ,'null'
    ,'null'
    ,'null'
    ,'null'
    ,'null'
    ,'null'
    ,'null'
    ,'null'
    ,'null'
    ,'null'
    ,'null'
FROM dual;
