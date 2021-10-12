create or replace trigger XXCS_INCIDENT_BIR_TRG
  before insert on cs_incidents_all_b  
  for each row
  
when (NEW.incident_occurred_date is null and NEW.incident_date is not null )
declare
--------------------------------------------------------------------
--  customization code: CUST310
--  name:               XXCS_INCIDENT_BIR_TRG
--  create by:          Dalit A. Raviv
--  $Revision:          1.0 
--  creation date:      17/05/2010
--  Description:        if  incident_occurred_date is null then
--                      copy incident_date value.
--                      SR that create at RMA form do not have 
--                      value at incident_occurred_date.
-------------------------------------------------------------------- 
--  ver   date          name            desc
--  1.0   17/05/2010    Dalit A. Raviv  initial build
-------------------------------------------------------------------- 
begin

  if nvl(fnd_profile.VALUE('XXCS_INCIDENT_TRG_ENABLE_BI'), 'N') = 'Y' then
    if  :NEW.incident_occurred_date is null and :NEW.incident_date is not null then
      :NEW.incident_occurred_date := :NEW.incident_date;   
    end if;
  end if; 

exception
  when others then 
    null;
  
end XXCS_INCIDENT_BIR_TRG;
/

