CREATE OR REPLACE TRIGGER xxcsi_item_instances_bur_trg1
  BEFORE UPDATE ON csi_item_instances
  FOR EACH ROW
--when ((old.attribute12 is not null) or (old.attribute12 is null and new.attribute16 = 'Y')) -- CHG0042619
DECLARE
  --l_source_id_exist VARCHAR2(5) := 'N';
  -- l_relate_to_sf    VARCHAR2(5) := 'N';
  -- l_oa2sf_rec       xxobjt_oa2sf_interface_pkg.t_oa2sf_rec;
  -- l_err_code        VARCHAR2(10) := 0;
  -- l_err_desc        VARCHAR2(2500) := NULL;
  -- l_count           NUMBER := 0;
  l_rec xxobjt_custom_events%ROWTYPE;
BEGIN
  --------------------------------------------------------------------
  --  name:            XXCSI_ITEM_INSTANCES_BUR_TRG1
  --  create by:       yuval .tal
  --  Revision:        1.0
  --  creation date:   16.7.14
  --------------------------------------------------------------------
  --  purpose :        Trigger that will audit scarp events
  --
  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  16.7.14    yuval .tal         initial build change CHG0031508
  --  1.1  12/03/2015  Dalit A. Raviv    CHG0034735 - add handle for attribute16
  --                                     sync IB that in stock to SFDC
  -- 1.2   2.4.18      yuval tal         CHG0042619 - Install base interface from Oracle to salesforce
  --                                      move att12 check into xxobjt_oa2sf_interface_pkg.handle_asset_event
  --------------------------------------------------------------------

  -- check scarp
  -- if :old.attribute12 is not null then  CHG0042619
  IF :old.instance_status_id != 5 AND :new.instance_status_id = 5 THEN
  
    l_rec.source_name := 'XXCSI_ITEM_INSTANCES_BUR_TRG1';
    l_rec.event_table := 'CSI_ITEM_INSTANCES';
    l_rec.event_key   := :old.instance_id;
    l_rec.event_name  := 'MACHINE_SCRAP';
    xxobjt_custom_events_pkg.insert_event(l_rec);
  
  END IF;
  -- end if;CHG0042619
  -- sync IB that in stock to SFDC
  IF ( /*:old.attribute12 is null and CHG0042619 */
      :new.attribute16 = 'Y' AND :new.owner_party_id = 10041) THEN
    l_rec.source_name := 'XXCSI_ITEM_INSTANCES_BUR_TRG1';
    l_rec.event_table := 'CSI_ITEM_INSTANCES';
    l_rec.event_key   := :old.instance_id;
    l_rec.event_name  := 'INSTALL_BASE_SHIP';
    xxobjt_custom_events_pkg.insert_event(l_rec);
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    NULL;
END xxcsi_item_instances_bur_trg1;
/
