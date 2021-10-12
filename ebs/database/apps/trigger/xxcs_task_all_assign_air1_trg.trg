create or replace trigger XXCS_TASK_ALL_ASSIGN_AIR1_TRG
after update on jtf_task_all_assignments
for    each row
-- 11003 = Close ENG
when ((NEW.assignment_status_id = 11003) and (NEW.assignment_status_id  <> OLD.assignment_status_id ))
declare
  CURSOR get_pop_c IS
    select cdl.debrief_line_id,       cdl.quantity
    from   csf_debrief_headers        cdh,
           csf_debrief_lines          cdl,
           cs_transaction_types_b_dfv t_dfv,
           cs_transaction_types_b     trx
    where  cdh.debrief_header_id      = cdl.debrief_header_id
    and    cdl.transaction_type_id    = trx.transaction_type_id
    and    trx.rowid                  = t_dfv.row_id
    and    t_dfv.def_quantity_completion = 'YES'
    and    cdl.attribute1             is null
    and    cdl.quantity               is not null
    and    cdh.task_assignment_id     = :new.task_assignment_id;
  
  l_recipient       varchar2(250) := null;
  user_exception    exception;
begin
--------------------------------------------------------------------
--  customization code: CUST351 - CSF-Material line defective - Trg
--  name:               XXCS_TASK_ALL_ASSIGN_AIR1_TRG
--  create by:          Dalit A. Raviv
--  $Revision:          1.0
--  creation date:      29/08/2010
--  Description:        when task assignment change status to Close ENG
--                      update defective quantity
--------------------------------------------------------------------
--  ver   date          name            desc
--  1.0   29/08/2010    Dalit A. Raviv  initial build
--------------------------------------------------------------------
  if nvl(fnd_profile.VALUE('XXCS_TASK_ALL_ASSIGN_TRG_ENABLE_BI1'), 'N') = 'Y' then
    begin
      for get_pop_r in get_pop_c loop
        begin
        update csf_debrief_lines          cdl
        set    cdl.attribute1             = get_pop_r.quantity
        where  cdl.debrief_line_id        = get_pop_r.debrief_line_id;
        exception
          when others then
            begin
            l_recipient := fnd_profile.value('XXCS_RECIPIENTS_EMAIL_ADDRESS');
            xxfnd_smtp_utilities.send_mail2( p_recipient => l_recipient,
                                             p_subject   => 'Error to assign defective quantity',
                                             p_body      => 'Trigger - XXCS_TASK_ALL_ASSIGN_AIR1_TRG Failed. Task assignment id - '
                                                            ||:NEW.task_assignment_id
                                                            ||' - assignment_status_id - '
                                                            ||:NEW.assignment_status_id
                                                            ||' - '||substr(sqlerrm,1,245) );
            exception
              when others then
                null;
            end;
        end;
      end loop;
    exception     
      when others then
        raise user_exception;
    end;
  end if;

exception
  when user_exception then
    begin
      l_recipient := fnd_profile.value('XXCS_RECIPIENTS_EMAIL_ADDRESS');
      xxfnd_smtp_utilities.send_mail2( p_recipient => l_recipient,
                                       p_subject   => 'Error to assign defective quantity',
                                       p_body      => 'Trigger - XXCS_TASK_ALL_ASSIGN_AIR1_TRG Failed. Task assignment id - '
                                                      ||:NEW.task_assignment_id
                                                      ||' - assignment_status_id - '
                                                      ||:NEW.assignment_status_id
                                                      ||' - '||substr(sqlerrm,1,245) );
                       
    exception
      when others then
        null;
    end;
  when others then
    begin
      l_recipient := fnd_profile.value('XXCS_RECIPIENTS_EMAIL_ADDRESS');
      xxfnd_smtp_utilities.send_mail2( p_recipient => l_recipient,
                                       p_subject   => 'Error to assign defective quantity',
                                       p_body      => 'Trigger - XXCS_TASK_ALL_ASSIGN_AIR1_TRG Failed. Task assignment id - '
                                                      ||:NEW.task_assignment_id
                                                      ||' - assignment_status_id - '
                                                      ||:NEW.assignment_status_id
                                                      ||' - '||substr(sqlerrm,1,245) );
                       
    exception
      when others then
        null;
    end;
end XXCS_TASK_ALL_ASSIGN_AIR1_TRG;
/

