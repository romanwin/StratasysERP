create or replace view XXBI_ACTIVE_ANALYTIC_DATA_V
as 
select  
--------------------------------------------------------------------------------------------
-- Ver    When        Who          Description
-- -----  ----------  -----------  ---------------------------------------------------------
-- 1.0    03/12/2019  Roman W.     CHG0045538 - Active Analytic Center
-- 1.1    09/12/2019  Roman W.      CHG0045538 - Active Analytic Center
--                                     added (+)
--------------------------------------------------------------------------------------------
     xaad.record_id,
     xaad.batch_id,
     xaad.action_type_code,
     xaad.sf_target_id,
     xaad.reference_date,
     xaad.attribute1_text,
     xaad.attribute2_text,
     xaad.attribute3_text,
     xaad.attribute4_text,
     xaad.attribute5_text,
     xaad.attribute6_text,
     xaad.attribute7_text,
     xaad.attribute8_text,
     xaad.attribute9_text,
     xaad.attribute10_text,
     xaad.attribute1_number,
     xaad.attribute2_number,
     xaad.attribute3_number,
     xaad.attribute4_number,
     xaad.attribute5_number,
     xaad.attribute6_number,
     xaad.attribute7_number,
     xaad.attribute8_number,
     xaad.attribute9_number,
     xaad.attribute10_number,
     xaad.attribute1_date,
     xaad.attribute2_date,
     xaad.attribute3_date,
     xaad.attribute4_date,
     xaad.attribute5_date,
     xaad.attribute6_date,
     xaad.attribute7_date,
     xaad.attribute8_date,
     xaad.attribute9_date,
     xaad.attribute10_date,
     xaad.interface_status,
     xaad.interface_err_message,
     xaad.interface_creation_date,
     xaad.interface_last_update_date,
     xaad.sf_action_datetime,
     xaad.sf_related_object_name,
     xaad.sf_related_record_id,
     xaad.bpel_flow_id,
     aac.aa_sf_status__c,
     aac.aa_sf_err_message__c
from XXBI_ACTIVE_ANALYTIC_DATA_T@SOURCE_DWH xaad
   , ACTIVE_ANALYTICS__C@SOURCE_SF2 aac
where aac.Aa_Dwh_Record_Id__c(+) = xaad.record_id /* 1.1 */;
