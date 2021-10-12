CREATE OR REPLACE TRIGGER xxcsi_item_instances_bir_trg2
  before insert on CSI_ITEM_INSTANCES
  for each row


when(NEW.location_type_code = 'INVENTORY' and NEW.serial_number is not null)
DECLARE
  pragma autonomous_transaction;
  l_row_elements            qa_validation_api.ElementsArray;
  x_message_array           qa_validation_api.MessageArray;
  l_ErrorArray              qa_validation_api.ErrorArray;
  x_do_action_return        boolean;
  x_error_found             boolean;

  l_is_ato                  varchar2(1);
  i                         number := 0;
  l_cmp_item_ellement_id    number;
  l_cmp_desc_ellement_id    number;
  l_sw_version_ellement_id  number;
  l_cmp_item                mtl_system_items_b.segment1%type;
  l_cmp_desc                mtl_system_items_b.description%type;
  l_hasp_sw_version         qa_plan_char_actions.message%type;
  l_err_msg                 varchar2(2500);

  l_recipient_role          VARCHAR2(250) := NULL;
  l_att1_proc               VARCHAR2(150) := NULL;
  l_att2_proc               VARCHAR2(150) := NULL;
  l_att3_proc               VARCHAR2(150) := NULL;
  l_err_code                NUMBER := 0;
  l_err_desc                VARCHAR2(1000) := NULL;
  l_mail_list               VARCHAR2(1500) := NULL;

  cursor c_rslt(p_job  varchar2) is
    select qsr.plan_id,
           qr.spec_id,
           qsr.organization_id,
           qsr.collection_id,
           qsr.occurrence,
           qsr.obj_serial_number,
           qsr.hasp_enabled_for_sw_version
    from   q_sn_reporting_v qsr,
           qa_results qr
    where  1 = 1
    and    qr.plan_id = qsr.plan_id
    and    qr.occurrence = qsr.occurrence
    and    qsr.serial_component_item like 'CMP%'
    and    qsr.job = p_job;

    cursor c_ellement (p_name varchar2) is
      select qc.char_id
      from   qa_chars qc
      where  qc.name = p_name;
BEGIN
  --------------------------------------------------------------------
  --  name:            XXCSI_ITEM_INSTANCES_BUR_TRG2
  --  create by:       Michal Tzvik
  --  Revision:        1.0
  --  creation date:   23/07/2014
  --------------------------------------------------------------------
  --  purpose :        CHG0032166 - Unified platform install Base updates for HASP
  --                   Trigger that will fire each insert of item instance.
  --                   CMP item and sw_version will be updated in SN reporting

  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  23/07/2014  Michal Tzvik      initial build
  --  1.1  16/05/2019  Bellona(TCS)      CHG0045703 - After implemented QA patch need to replace
  --       using qa_results_api.update_row with standard quality interface view Q_SN_REPORTING_IV.
  --       This is required to  make sure the correct V2C file for ATO machines will be uploaded from Safenet.
  --------------------------------------------------------------------

  select nvl(max('Y'),'N')
  into   l_is_ato
  from   wip_discrete_jobs  wdj,
         mtl_system_items_b msib
  where  wdj.wip_entity_id = :new.last_wip_job_id
  and    msib.inventory_item_id =:new.inventory_item_id
  and    msib.organization_id = :new.last_vld_organization_id
  and    msib.replenish_to_order_flag = 'Y'
  and    wdj.class_code = 'ATO'
  and    xxinv_unified_platform_utl_pkg.is_basis_hasp(msib.inventory_item_id,
                                                      msib.organization_id) = 'N';

  if l_is_ato = 'Y' then

     l_recipient_role := fnd_profile.value('XXCS_ORACLE_CS_WF_ROLE_USER');
     l_mail_list      := xxobjt_general_utils_pkg.get_alert_mail_list('XXCSI_ITEM_INSTANCES',';');

     select msib3.segment1    cmp_item,
            msib3.description cmp_desc,
            qpca.message      hasp_sw_version
     into   l_cmp_item,
            l_cmp_desc,
            l_hasp_sw_version
     from   qa_plan_char_action_triggers_v qpcat,
            qa_plan_char_actions           qpca,
            mtl_system_items_b             msib3,
            bom_components_b               bcb,
            bom_structures_b               bsb,
            wip_discrete_jobs              wdj,
            wip_requirement_operations_v   wrov
     where  qpcat.plan_char_action_trigger_id = qpca.plan_char_action_trigger_id(+)
     and    qpcat.plan_name(+) = 'SN REPORTING'
     and    qpcat.low_value_other(+) = msib3.segment1
     and    wdj.organization_id = :new.last_vld_organization_id
     and    bcb.bill_sequence_id = bsb.bill_sequence_id
     and    bsb.organization_id = 735
     and    wdj.primary_item_id = :new.inventory_item_id
     and    bcb.component_item_id = msib3.inventory_item_id
     and    msib3.organization_id = bsb.organization_id
     and    trunc(sysdate) between bcb.effectivity_date and nvl(bcb.disable_date, sysdate + 1)
     and    msib3.segment1 like 'CMP%'
     and    wdj.wip_entity_id=wrov.wip_entity_id
     and    wdj.wip_entity_id = :new.last_wip_job_id
     and    wrov.concatenated_segments like 'KIT%'
     and    wrov.inventory_item_id=bsb.assembly_item_id;

     OPEN c_ellement ('Serial Component Item');
     FETCH c_ellement INTO l_cmp_item_ellement_id;
     CLOSE c_ellement;

     OPEN c_ellement ('Item Desc');
     FETCH c_ellement INTO l_cmp_desc_ellement_id;
     CLOSE c_ellement;

     OPEN c_ellement ('HASP enabled for SW Version');
     FETCH c_ellement INTO l_sw_version_ellement_id;
     CLOSE c_ellement;
     for r_rslt in c_rslt(:new.serial_number) loop

       l_err_msg := '';

       l_row_elements(l_cmp_item_ellement_id).id    := l_cmp_item_ellement_id;
       l_row_elements(l_cmp_item_ellement_id).value := l_cmp_item;

       l_row_elements(l_cmp_desc_ellement_id).id    := l_cmp_desc_ellement_id;
       l_row_elements(l_cmp_desc_ellement_id).value := l_cmp_desc;

       if l_hasp_sw_version is null then
          l_err_msg := 'Hasp sw version is null';
       else
          l_row_elements(l_sw_version_ellement_id).id    := l_sw_version_ellement_id;
          l_row_elements(l_sw_version_ellement_id).value := l_hasp_sw_version;
       end if;
      --Commented as part of CHG0045703
      /* l_ErrorArray :=
       qa_results_api.update_row( p_plan_id                 => r_rslt.plan_id,
                                  p_spec_id                 => r_rslt.spec_id,
                                  p_org_id                  => r_rslt.organization_id,
                                  p_collection_id           => r_rslt.collection_id,
                                  p_who_last_updated_by     => fnd_global.user_id,
                                  p_who_created_by          => fnd_global.user_id,
                                  p_who_last_update_login   => fnd_global.user_id,
                                  p_enabled_flag            => null,
                                  p_error_found             => x_error_found,
                                  p_occurrence              => r_rslt.occurrence,
                                  p_do_action_return        => x_do_action_return,
                                  p_message_array           => x_message_array,
                                  p_row_elements            => l_row_elements);
       if x_error_found then
         i := x_message_array.first;
         l_err_msg := 'Failed to update q_sn_reporting_v: ';
         WHILE (i <= x_message_array.last) LOOP
           l_err_msg := l_err_msg || chr(10) || x_message_array(i).message;
           i := x_message_array.next(i);
         end loop;
       end if;

       dbms_output.put_line('l_ErrorArray: ');
       i := l_ErrorArray.first;

       WHILE (i <= l_ErrorArray.last) LOOP
         l_err_msg := l_err_msg || chr(10) || l_ErrorArray(i).error_code;
         i := l_ErrorArray.next(i);
       end loop;*/

       --Added as part of CHG0045703
         INSERT INTO Q_SN_REPORTING_IV
            (qa_last_updated_by_name,
             process_status,
             organization_code,
             plan_name,
             insert_type,
             matching_elements,
             OBJ_SERIAL_NUMBER,
             JOB_NAME,
             SERIAL_COMPONENT_ITEM,
             ITEM_DESC,
             HASP_ENABLED_FOR_SW_VERSION,
             XX_EXCEPTIONS
             )
          VALUES
            (fnd_global.USER_NAME, --qa_last_updated_by_name 'DOVIK.POLLAK'
             1, --process_status
             'IPK', --organization_code
             'SN REPORTING', --plan_name
             2, --insert_type (2: update)
             'OBJ_SERIAL_NUMBER,JOB_NAME', --matching_elements
              r_rslt.obj_serial_number, --'1695889911',
              :new.serial_number,--p_job,  --'G1001154',
              l_cmp_item,--SERIAL COMPONENT ITEM,     --'CMP-dp34233',
              l_cmp_desc,--Item Desc,                  --'new dp HASP, OBJET30 PRIME _33.2_PRIME_P',
              l_hasp_sw_version,--HASP enabled for SW Version,     --'33.2_PRIME_P',
             '0'   --EXCEPTION
             );



       --if l_err_msg is not null then
         xxobjt_wf_mail.send_mail_text(p_to_role     => l_recipient_role,
                                        p_cc_mail     => l_mail_list,
                                        p_bcc_mail    => NULL,
                                        p_subject     => 'SN Reporting Updates - Error',
                                        p_body_text   => 'JOB/Serial: ' ||
                                                         :new.serial_number || chr(10) ||
                                                         'CMP: ' ||
                                                         l_cmp_item || chr(10) ||
                                                         'HASP Version: ' ||
                                                         l_hasp_sw_version || chr(10) ||
                                                         'Error message: ' || l_err_msg ,
                                        p_att1_proc   => l_att1_proc,
                                        p_att2_proc   => l_att2_proc,
                                        p_att3_proc   => l_att3_proc,
                                        p_err_code    => l_err_code,
                                        p_err_message => l_err_desc);

       --end if;
       --commit;
     end loop;
    end if;

exception
  when others then
   --rollback;

   xxobjt_wf_mail.send_mail_text(p_to_role     => l_recipient_role,
                                  p_cc_mail     => l_mail_list,
                                  p_bcc_mail    => NULL,
                                  p_subject     => 'SN Reporting Updates - Error',
                                  p_body_text   => 'JOB/Serial: ' ||
                                                   :new.serial_number || chr(10) ||
                                                   'CMP: ' ||
                                                   l_cmp_item || chr(10) ||
                                                   'HASP Version: ' ||
                                                   l_hasp_sw_version || chr(10) ||
                                                   'Error message: Unexpected error: ' || sqlerrm ,
                                  p_att1_proc   => l_att1_proc,
                                  p_att2_proc   => l_att2_proc,
                                  p_att3_proc   => l_att3_proc,
                                  p_err_code    => l_err_code,
                                  p_err_message => l_err_desc);
end;