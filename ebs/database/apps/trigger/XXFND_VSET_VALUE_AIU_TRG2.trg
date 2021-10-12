CREATE OR REPLACE TRIGGER XXFND_VSET_VALUE_AIU_TRG2
--------------------------------------------------------------------------------------------------
--  name:              XXFND_VSET_VALUE_AIU_TRG2
--  create by:         Diptasurjya Chatterjee
--  Revision:          1.0
--  creation date:     13-04-2018
--------------------------------------------------------------------------------------------------
--  purpose :          CHG0042706  : Check and insert/update data into event table for Insert and Update
--                                   triggers on FND_FLEX_VALUES
--
--  Modification History
--------------------------------------------------------------------------------------------------
--  ver   date          Name                       Desc
--  1.0   13/04/2018    Diptasurjya Chatterjee     CHG0042706 - Strataforce interface
--------------------------------------------------------------------------------------------------

AFTER INSERT OR UPDATE ON FND_FLEX_VALUES
FOR EACH ROW

DECLARE
  l_trigger_name      varchar2(30) := 'XXFND_VSET_VALUE_AIU_TRG2';
  l_old_vsetv_rec     FND_FLEX_VALUES%rowtype;
  l_new_vsetv_rec     FND_FLEX_VALUES%rowtype;
  l_error_message     varchar2(2000);
  l_flex_vset_name    varchar2(60) := null;
  l_trigger_action     VARCHAR2(10);
BEGIN
  l_error_message := '';

  begin
  select flex_value_set_name
    into l_flex_vset_name
    from fnd_flex_value_sets
   where flex_value_set_name in ('XXCS_PB_PRODUCT_FAMILY')
     and flex_value_set_id = :new.flex_value_set_id;
  exception
  when no_data_found then
    l_flex_vset_name := null;
  end;

  IF INSERTING THEN
     l_trigger_action := 'INSERT';
  ELSIF UPDATING THEN
     l_trigger_action := 'UPDATE';
  END IF;

  IF l_flex_vset_name is not null
  THEN

    -- Old Values before Update
    l_old_vsetv_rec.flex_value_set_id       := :old.flex_value_set_id ;
    l_old_vsetv_rec.flex_value_id           := :old.flex_value_id;
    l_old_vsetv_rec.flex_value              := :old.FLEX_VALUE;
    l_old_vsetv_rec.created_by              := :old.created_by;
    l_old_vsetv_rec.last_updated_by         := :old.last_updated_by;
    l_old_vsetv_rec.start_date_active       := :old.start_date_active;
    l_old_vsetv_rec.end_date_active         := :old.end_date_active;
    l_old_vsetv_rec.enabled_flag            := :old.enabled_flag;


    -- New Values after Update
    l_new_vsetv_rec.flex_value_set_id       := :new.flex_value_set_id ;
    l_new_vsetv_rec.flex_value_id           := :new.flex_value_id;
    l_new_vsetv_rec.flex_value              := :new.FLEX_VALUE;
    l_new_vsetv_rec.created_by              := :new.created_by;
    l_new_vsetv_rec.last_updated_by         := :new.last_updated_by;
    l_new_vsetv_rec.start_date_active       := :new.start_date_active;
    l_new_vsetv_rec.end_date_active         := :new.end_date_active;
    l_new_vsetv_rec.enabled_flag            := :new.enabled_flag;

    --Call Trigger Event Processor
    xxssys_strataforce_events_pkg.vset_common_trg_processor(p_old_vsetv_rec    => l_old_vsetv_rec,
                                                            p_new_vsetv_rec    => l_new_vsetv_rec,
                                                            p_trigger_name     => l_trigger_name,
                                                            p_vset_name        => l_flex_vset_name,
                                                            p_trigger_action   => l_trigger_action);

  END IF;
EXCEPTION
WHEN OTHERS THEN
  l_error_message := substrb(sqlerrm,1,500);
  RAISE_APPLICATION_ERROR(-20999,l_error_message);
END XXFND_VSET_VALUE_AIU_TRG2;
/
