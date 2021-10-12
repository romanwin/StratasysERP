CREATE OR REPLACE TRIGGER xxcsi_i_parties_h_bir_trg
  BEFORE INSERT ON csi_i_parties_h
  FOR EACH ROW

  WHEN (nvl (new.old_party_id, 10041) = 10041 AND new.new_party_id != 10041)
DECLARE

  CURSOR c IS
    SELECT instance_id
    FROM   csi_item_instances_h t
    WHERE  t.transaction_id = :new.transaction_id;
  l_rec xxobjt_custom_events%ROWTYPE;

  --l_sf_id csi_item_instances.attribute12%TYPE;
BEGIN
  --------------------------------------------------------------------
  --  name:            xxcsi_item_instances_h_bur_trg
  --  create by:       yuval.tal
  --  Revision:        1.0
  --  creation date:   19.3.14
  --------------------------------------------------------------------
  --  purpose :        Trigger that will fire each update of item rev
  --                   CUST776 - Customer support SF-OA interfaces CR 1215

  --                   verify that machine sold to customer and the owner is changed from
  --                   Customer "Objet internal install base" to external customer.
  --------------------------------------------------------------------
  --  ver  date        name            desc
  --  1.0  06/01/2014  YUVAL TAL       initial build
  --  1.1  18/03/2015  Dalit A. Raviv  CHG0034735 modifications for OA 2 SF asset issues
  --                                   sync when machine shipped again from stock
  -- 1.2   2.4.18      yuval tal       CHG0042619 - Install base interface from Oracle to salesforce
  --                                   move att12 check into xxobjt_oa2sf_interface_pkg.handle_asset_event 
  --------------------------------------------------------------------
  FOR i IN c LOOP
    -- 1.1 18/03/2015 Dalit A. Raviv CHG0034735
    /* l_sf_id := null;
    begin
      select attribute12
      into   l_sf_id
      from   csi_item_instances cii
      where  cii.instance_id    = i.instance_id;
    exception
      when others then
        null;
    end;*/
  
    -- if l_sf_id is null then
    -- old code
    --CHG0042619
    l_rec.source_name := 'XXCSI_I_PARTIES_H_BIR_TRG';
    l_rec.event_table := 'CSI_I_PARTIES_H';
    l_rec.event_key   := i.instance_id;
    l_rec.event_name  := 'INSTALL_BASE_SHIP';
    xxobjt_custom_events_pkg.insert_event(l_rec);
    --  else
  --   l_rec.source_name := 'XXCSI_I_PARTIES_H_BIR_TRG';
  --   l_rec.event_table := 'CSI_I_PARTIES_H';
  --   l_rec.event_key   := i.instance_id;
  --   l_rec.event_name  := 'MACHINE_RESHIP';
  --  xxobjt_custom_events_pkg.insert_event(l_rec);
  --  end if;
  -- end 1.1
  END LOOP;
EXCEPTION
  WHEN OTHERS THEN
    NULL;
END;
/
