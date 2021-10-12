create or replace trigger xxcsf_debrief_lines_trg
  before update  of charge_upload_status  on csf_debrief_lines  
  for each row
  
when (NEW.charge_upload_status ='SUCCEEDED' and nvl(old.charge_upload_status ,'xx')!='SUCCEEDED' )
DECLARE
  --------------------------------------------------------------------
  --  customization code: CUST310
  --  name:               csf_debrief_lines_trg
  --  create by:          yuval tal
  --  $Revision:          1.0 
  --  creation date:      5.4.11
  --  Description:        
  -------------------------------------------------------------------- 
  --  ver   date          name            desc
  --  1.0   5.4.2011    yuval tal  initial build
  -------------------------------------------------------------------- 

  l_party_id     NUMBER;
  l_process_flag VARCHAR2(50);
  l_resource_id  NUMBER;

  l_counter            NUMBER;
  l_contract_header_id NUMBER;
  l_contract_line_id   NUMBER;
  l_from_date          DATE;
  l_to_date            DATE;
  l_incident_id        NUMBER;
  l_inventory_id       NUMBER;
  l_org_id             NUMBER;

  l_err_code             NUMBER;
  l_err_message          VARCHAR2(500);
  l_new_labor_start_date DATE;
  l_new_labor_end_date   DATE;
  l_external_attribute_9 VARCHAR2(240);

BEGIN
  IF nvl(fnd_profile.VALUE('XXCS_SR_CHARGE_CALCULATE'), 'N') = 'Y' THEN
    IF xxoks_cover.is_valid_foc(:OLD.business_process_id,
                                :OLD.transaction_type_id) = 'Y' THEN
    
      SELECT ciab.incident_id,
             jtas.resource_id,
             jtb.customer_id,
             --  jttb.attribute2,
             cdh.processed_flag,
             external_attribute_9
        INTO l_incident_id,
             l_resource_id,
             l_party_id,
             l_process_flag,
             l_external_attribute_9
        FROM cs_incidents_all_b       ciab, --SR Table
             jtf_tasks_b              jtb, --Tasks Table        
             csf_debrief_headers      cdh, --debreif header         
             jtf_task_all_assignments jtas --assisgnments table
       WHERE ciab.incident_id = jtb.source_object_id
         AND :OLD.debrief_header_id = cdh.debrief_header_id
         AND cdh.task_assignment_id = jtas.task_assignment_id
         AND jtas.task_id = jtb.task_id;
    
      xxoks_cover.get_contract_info4incident(p_incident_id        => l_incident_id,
                                             p_contract_header_id => l_contract_header_id,
                                             p_contract_line_id   => l_contract_line_id,
                                             p_from_date          => l_from_date,
                                             p_to_date            => l_to_date,
                                             p_inventory_id       => l_inventory_id,
                                             p_org_id             => l_org_id);
    
      l_new_labor_start_date := xxoks_cover.convert_date2incident_tz(p_server_date => :NEW.labor_start_date,
                                                                     p_incident_id => l_incident_id);
      l_new_labor_end_date   := xxoks_cover.convert_date2incident_tz(p_server_date => :NEW.labor_end_date,
                                                                     p_incident_id => l_incident_id);
      -- check contract date Vs labor_start_date
    
      IF trunc(l_new_labor_start_date) BETWEEN trunc(l_from_date) AND
         trunc(l_to_date) OR
        
         trunc(l_new_labor_end_date) BETWEEN trunc(l_from_date) AND
         trunc(l_to_date) THEN
      
        IF l_external_attribute_9 = 'Y' THEN
          l_counter := 0;
        ELSE
        
          -- check previous debriefs
          l_counter := xxoks_cover.get_visit_count(p_party_id    => l_party_id,
                                                   p_resource_id => l_resource_id,
                                                   p_from_date   => greatest(l_new_labor_start_date,
                                                                             l_from_date),
                                                   p_to_date     => least(l_new_labor_end_date,
                                                                          l_to_date));
        
        END IF;
      
        INSERT INTO xxcsf_foc_counter
          (line_id,
           debrief_line_id,
           labor_start_date,
           labor_end_date,
           party_id,
           contract_line_id,
           resource_id,
           counter,
           last_update_date,
           last_updated_by,
           creation_date,
           created_by,
           last_update_login)
        VALUES
        
          (xxcsf_foc_counter_seq.NEXTVAL,
           :OLD.debrief_line_id,
           l_new_labor_start_date,
           l_new_labor_end_date,
           l_party_id, --party_id,
           l_contract_line_id, --contract_line_id,
           l_resource_id,
           l_counter, --(trunc(:NEW.labor_end_date) - trunc(:NEW.labor_start_date)) + 1, --counter,
           SYSDATE, --last_update_date, 
           fnd_global.user_id, --last_updated_by, 
           SYSDATE, --creation_date, 
           fnd_global.user_id, --created_by, 
           fnd_global.login_id --last_update_login
           );
      
      END IF;
    END IF;
  END IF;

EXCEPTION
  WHEN OTHERS THEN
    xxobjt_wf_mail.send_mail_text(p_to_role     => 'SYSADMIN',
                                  p_subject     => 'Error in trigger xxcsf_debrief_lines_trg',
                                  p_body_text   => SQLERRM,
                                  p_err_code    => l_err_code,
                                  p_err_message => l_err_message);
  
END;
/

