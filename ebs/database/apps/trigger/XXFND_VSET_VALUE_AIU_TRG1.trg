CREATE OR REPLACE TRIGGER XXFND_VSET_VALUE_AIU_TRG1
--------------------------------------------------------------------------------------------------
--  name:              XXFND_VSET_VALUE_AIU_TRG1
--  create by:         Diptasurjya Chatterjee
--  Revision:          1.0
--  creation date:     29-06-2015
--------------------------------------------------------------------------------------------------
--  purpose :          CHG0035700  : Check and insert/update data into event table for Insert and Update
--                                   triggers on FND_FLEX_VALUES
--
--  Modification History
--------------------------------------------------------------------------------------------------
--  ver   date          Name                       Desc
--  1.0   29/06/2015    Diptasurjya Chatterjee     CHG0035700 - eCommerce Real Time printer-flavor interface
--------------------------------------------------------------------------------------------------

AFTER INSERT OR UPDATE ON FND_FLEX_VALUES
FOR EACH ROW

DECLARE
  l_trigger_name      varchar2(30) := 'XXFND_VSET_VALUE_AIU_TRG1';
  old_printer_flavor_rec       xxinv_ecomm_event_pkg.printer_flavor_rec_type;
  new_printer_flavor_rec       xxinv_ecomm_event_pkg.printer_flavor_rec_type;
  l_error_message     varchar2(2000);
  l_flex_vset_name    varchar2(60) := null;
BEGIN
  l_error_message := '';
  
  begin
  select flex_value_set_name
    into l_flex_vset_name
    from fnd_flex_value_sets
   where flex_value_set_name in ('XXECOM_ITEM_FLAVOR','XXECOM_FLAVOR_PRINTER')
     and flex_value_set_id = :new.flex_value_set_id;
  exception
  when no_data_found then
    l_flex_vset_name := null;
  end;
  
  IF l_flex_vset_name is not null
  THEN

    -- Old Values before Update
    old_printer_flavor_rec.flex_value_set_name     := l_flex_vset_name;
    old_printer_flavor_rec.flex_value_id           := :old.flex_value_id;
    old_printer_flavor_rec.flavor_name             := :old.FLEX_VALUE;
    old_printer_flavor_rec.printer_name            := :old.PARENT_FLEX_VALUE_LOW;
    old_printer_flavor_rec.created_by              := :old.created_by;
    old_printer_flavor_rec.last_updated_by         := :old.last_updated_by;
    old_printer_flavor_rec.status                  := :old.enabled_flag;


    -- New Values after Update
    new_printer_flavor_rec.flex_value_set_name     := l_flex_vset_name;
    new_printer_flavor_rec.flex_value_id           := :new.flex_value_id;
    new_printer_flavor_rec.flavor_name             := :new.FLEX_VALUE;
    new_printer_flavor_rec.printer_name            := :new.PARENT_FLEX_VALUE_LOW;
    new_printer_flavor_rec.created_by              := :new.created_by;
    new_printer_flavor_rec.last_updated_by         := :new.last_updated_by;
    new_printer_flavor_rec.status                  := :new.enabled_flag;

    IF updating THEN

       xxinv_ecomm_event_pkg.print_flav_trigger_processor(p_old_print_flav_rec   => old_printer_flavor_rec,
                                                          p_new_print_flav_rec   => new_printer_flavor_rec,
                                                          p_trigger_name         => l_trigger_name,
                                                          p_trigger_action       => 'UPDATE');

    ELSIF inserting THEN

       xxinv_ecomm_event_pkg.print_flav_trigger_processor(p_old_print_flav_rec => null,
                                                          p_new_print_flav_rec => new_printer_flavor_rec,
                                                          p_trigger_name       => l_trigger_name,
                                                          p_trigger_action     => 'INSERT');

    END IF;

  END IF;
EXCEPTION
WHEN OTHERS THEN
  l_error_message := substrb(sqlerrm,1,500);
  RAISE_APPLICATION_ERROR(-20999,l_error_message);
END XXFND_VSET_VALUE_AIU_TRG1;
/
