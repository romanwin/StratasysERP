CREATE OR REPLACE TRIGGER xxqp_list_lines_biudr_trg1
--------------------------------------------------------------------------------------------------
  --  name:              xxqp_list_lines_biudr_trg1
  --  create by:         Lingaraj Sarangi
  --  Revision:          1.0
  --  creation date:     12-Dec-2017
  --------------------------------------------------------------------------------------------------
  --  purpose :          CHG0035652  : Check and insert/update data into event table for Insert and Update
  --                                   triggers on QP_LIST_LINES
  --
  --  Modification History
  --------------------------------------------------------------------------------------------------
  --  ver   date          Name                       Desc
  --  1.0   12-Dec-2017   Lingaraj Sarangi           CHG0041829 - Strataforce Real Rime Product interface
  --------------------------------------------------------------------------------------------------

  BEFORE UPDATE ON "QP"."QP_LIST_LINES"
  FOR EACH ROW

  when(1 = 1)
DECLARE
  l_trigger_name   VARCHAR2(50) := 'XXQP_LIST_LINES_BIUDR_TRG1';
  l_error_message  VARCHAR2(2000) := '';
  l_trigger_action VARCHAR2(10) := '#';
  l_list_header_id NUMBER := nvl(:new.list_header_id, :old.list_header_id);
  l_old_pl_rec     qp.qp_list_lines%ROWTYPE;
  l_new_pl_rec     qp.qp_list_lines%ROWTYPE;
BEGIN

  IF updating THEN
    IF NOT ((nvl(:old.operand, -999) <> :new.operand) OR
        (nvl(:old.end_date_active, trunc(SYSDATE + 1000)) <>
        nvl(:new.end_date_active, trunc(SYSDATE + 1000))) OR
        (nvl(:old.start_date_active, trunc(SYSDATE - 1000)) <>
        nvl(:new.start_date_active, trunc(SYSDATE - 1000)))) THEN
      -- If No Value Changed ThenDonot Create any Event
      RETURN;
    END IF;
  END IF;

  --If the Price Book Header is Inactive or Sync to Sf is No , No need to Create Event
  IF (xxssys_strataforce_events_pkg.is_pricebook_sync_to_sf(l_list_header_id) = 'N') THEN
    RETURN;
  END IF;

  IF inserting THEN
    l_trigger_action := 'INSERT';
  ELSIF updating THEN
    l_trigger_action := 'UPDATE';
  ELSIF deleting THEN
    l_trigger_action := 'DELETE';
  END IF;

  l_old_pl_rec.list_line_id        := :old.list_line_id;
  l_old_pl_rec.list_header_id      := :old.list_header_id;
  l_old_pl_rec.start_date_active   := :old.start_date_active;
  l_old_pl_rec.end_date_active     := :old.end_date_active;
  l_old_pl_rec.operand             := :old.operand;
  l_old_pl_rec.arithmetic_operator := :old.arithmetic_operator;
  l_old_pl_rec.list_line_no        := :old.list_line_no;
  l_old_pl_rec.created_by          := :old.created_by;
  l_old_pl_rec.last_updated_by     := :old.last_updated_by;

  l_new_pl_rec.list_line_id        := :new.list_line_id;
  l_new_pl_rec.list_header_id      := :new.list_header_id;
  l_new_pl_rec.start_date_active   := :new.start_date_active;
  l_new_pl_rec.end_date_active     := :new.end_date_active;
  l_new_pl_rec.operand             := :new.operand;
  l_new_pl_rec.arithmetic_operator := :new.arithmetic_operator;
  l_new_pl_rec.list_line_no        := :new.list_line_no;
  l_new_pl_rec.created_by          := :new.created_by;
  l_new_pl_rec.last_updated_by     := :new.last_updated_by;

  --Call Trigger Event Processor
  xxssys_strataforce_events_pkg.priceline_trg_processor(p_old_pl_rec     => l_old_pl_rec,
				        p_new_pl_rec     => l_new_pl_rec,
				        p_trigger_name   => l_trigger_name,
				        p_trigger_action => l_trigger_action);

EXCEPTION
  WHEN OTHERS THEN
    l_error_message := substrb(SQLERRM, 1, 500);
    raise_application_error(-20999, l_error_message);
END xxqp_list_lines_biudr_trg1;
/
