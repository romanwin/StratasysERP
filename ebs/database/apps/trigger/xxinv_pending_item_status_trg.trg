create or replace trigger XXINV_PENDING_ITEM_STATUS_TRG
  before insert or update on mtl_pending_item_status
  for each row
declare
  -- local variables here
  l_inventory_item_id  mtl_pending_item_status.inventory_item_id%TYPE;
  l_item_code          mtl_system_items_b.segment1%TYPE;
  l_trigger_name       VARCHAR2(50);
  l_trigger_action     VARCHAR2(50);
  l_last_updated_by    mtl_pending_item_status.last_updated_by%TYPE;
  l_organization_id    NUMBER;
  l_old_effective_date DATE;
  l_new_effective_date DATE;

begin

  --------------------------------------------------------------------------------
  -- Ver    When           Who             Descr
  -- -----  -------------  --------------  ---------------------------------------
  -- 1.0    11/03/2020     Roman W.        INC0185964-CHG0047631 update effective_date
  --------------------------------------------------------------------------------
  l_organization_id    := xxinv_utils_pkg.get_master_organization_id;
  l_old_effective_date := nvl(:old.effective_date, sysdate - 1);
  l_new_effective_date := nvl(:new.effective_date, sysdate + 1);

  if :new.organization_id = l_organization_id and
     nvl(:new.status_code, '-1') = 'XX_END_SRV' then
  
    -- call to create event 
    if l_old_effective_date != l_new_effective_date then
    
      l_inventory_item_id := :new.inventory_item_id;
      l_trigger_name      := 'XXINV_PENDING_ITEM_STATUS_TRG';
      l_trigger_action    := 'UPDATE';
      l_last_updated_by   := :new.last_updated_by;
    
      xxssys_strataforce_events_pkg.insert_product_event(p_inventory_item_id => l_inventory_item_id,
                                                         p_last_updated_by   => l_last_updated_by,
                                                         p_created_by        => l_last_updated_by,
                                                         p_trigger_name      => l_trigger_name,
                                                         p_trigger_action    => l_trigger_action);
    end if;
  end if;

end xxinv_pending_item_status_trg;
/
