create or replace trigger xxcsi_item_instances_bir_trg1
  before insert on CSI_ITEM_INSTANCES
  for each row

 
when (NEW.location_type_code = 'INVENTORY' and NEW.serial_number is not null)
DECLARE
  l_count               NUMBER;
  l_studio_sw_version   mtl_item_categories_v.segment1%TYPE; -- varchar2(40):= null;
  l_embedded_sw_version mtl_item_categories_v.segment1%TYPE;
  l_recipient_role      VARCHAR2(250) := NULL;
  l_att1_proc           VARCHAR2(150) := NULL;
  l_att2_proc           VARCHAR2(150) := NULL;
  l_att3_proc           VARCHAR2(150) := NULL;
  l_err_code            NUMBER := 0;
  l_err_desc            VARCHAR2(1000) := NULL;
  -- 1.3 18/04/2012 Dalit A. Raviv
  l_item_number VARCHAR2(100) := NULL;
  l_mail_list   VARCHAR2(1500) := NULL;
  --
BEGIN
  --------------------------------------------------------------------
  --  name:            XXCSI_ITEM_INSTANCES_BUR_TRG1
  --  create by:       Dalit A. Raviv
  --  Revision:        1.0
  --  creation date:   22/11/2011
  --------------------------------------------------------------------
  --  purpose :        CUST470 - Printer SW Versions Traceability
  --                   Trigger that will fire each insert of item instance.
  --                   Objet would like to capture the Embedded & Studio SW Versions
  --                   as defined in BOM at the time the printer is manufactured and u
  --                   pdate the Item Instance in Install Base accordingly.
  --
  --                   Ability for customer support engineers to track the Printers
  --                   Embedded & Studio SW Versions as specified at their manufactured WIP.

  --------------------------------------------------------------------
  --  ver  date        name              desc
  --  1.0  22/11/2011  Dalit A. Raviv    initial build
  --  1.1  11/12/2011  Dalit A. Raviv    The check need to be only for PRINTERS
  --  1.2  12/12/2011  Dalit A. Raviv    change condition logic to bring only the
  --                                     row that is correct today.(considare future dates)
  --  1.3  18/04/2012  Dalit A. Raviv    change message from item_id to segment1
  --                                     add cc to Shimon Hayoun & Gal Kotigaro
  --  1.4  23/07/2012  Adi Safin         change logic - instead getting embedded and studio version from BOM,
  --                                     we got it from job.
  -- 1.5  08-APR-2014  Dovik Pollak      CHG0031885:change logic - instead getting embedded and studio version from BOM/JOB,
  --                                     Get it from Assembly Item Number
  --------------------------------------------------------------------
  IF nvl(fnd_profile.value('XXCSI_ITEM_INSTANCE_TRG_ENABLE_BI'), 'N') = 'Y' THEN
    l_count               := 0;
    l_studio_sw_version   := NULL;
    l_embedded_sw_version := NULL;
    --
    -- check that the item exist at xxcs_items_printers_v
    -- only if this is printer we cntinue.
    SELECT COUNT(1)
      INTO l_count
      FROM xxcs_items_printers_v x
     WHERE x.inventory_item_id = :new.inventory_item_id
       AND x.item_type = 'PRINTER'; --  1.1  11/12/2011  Dalit A. Raviv
  
    IF l_count > 0 THEN
      -- Get Studio SW Version for given top_level_assembly
      BEGIN
        -- 1.4  23/07/2012  Adi Safin
        /*select v.segment1
        into   l_studio_sw_version
        from   xxobjt.xxinv_bom_explode_history t,
               mtl_item_categories_v            v
        where  t.comp_item_id                   = v.inventory_item_id
        and    v.organization_id                = 91
        and    v.category_set_name              = 'Objet Studio SW Version'
        and    t.creation_date                  = (select max(creation_date)
                                                   from   xxinv_bom_explode_history h)
        and    t.top_assembly_item_id           = :NEW.inventory_item_id
        --     1.2  12/12/2011  Dalit A. Raviv
        and    trunc(sysdate)                   between t.effective_date and nvl(t.disable_date, sysdate + 1);*/
        --and    (t.disable_date                  is null or t.disable_date               > trunc(sysdate));
        --
        -- 1.4  23/07/2012  Adi Safin
      
        /*select v.segment1
        into   l_studio_sw_version
        from   xxobjt.xxinv_bom_explode_history t,
               mtl_item_categories_v            v,
               wip_discrete_jobs_v              wdj,
               wip_requirement_operations_v     wro
        where  t.comp_item_id                   = v.inventory_item_id
        and    v.organization_id                = 91
        and    v.category_set_name              = 'Objet Studio SW Version'
        and    t.creation_date                  = (select max(creation_date)
                                                   from   xxinv_bom_explode_history h)
        and    wdj.wip_entity_id                = wro.wip_entity_id
        and    wdj.organization_id              = wro.organization_id
        and    wro.inventory_item_id            = t.top_assembly_item_id
        and    wro.required_quantity            = wro.quantity_issued
        and    wdj.wip_entity_name              = :NEW.serial_number
        and    wro.concatenated_segments        like 'SET%'
        and    wro.wip_supply_meaning           != 'Phantom'
        and    trunc(sysdate)                   between t.effective_date and nvl(t.disable_date, sysdate + 1);*/
      
        -- 1.5  08-APR-2014  Dovik Pollak
        SELECT v.segment1
          INTO l_studio_sw_version
          FROM mtl_item_categories_v v
         WHERE v.organization_id = 91
           AND v.category_set_name = 'Objet Studio SW Version'
           AND v.inventory_item_id = :new.inventory_item_id;
      
      EXCEPTION
        WHEN OTHERS THEN
          l_studio_sw_version := NULL;
      END;
    
      -- Get Objet Embedded SW Version for given top_level_assembly
      BEGIN
        -- 1.4  23/07/2012  Adi Safin
        /*select v.segment1
        into   l_embedded_sw_version
        from   xxobjt.xxinv_bom_explode_history t,
              mtl_item_categories_v            v
        where  t.comp_item_id                   = v.inventory_item_id
        and    v.organization_id                = 91
        and    v.category_set_name              = 'Objet Embedded SW Version'
        and    t.creation_date                  = (select max(creation_date)
                                                  from xxinv_bom_explode_history h)
        and    t.top_assembly_item_id           = :NEW.inventory_item_id
        --     1.2  12/12/2011  Dalit A. Raviv
        and    trunc(sysdate)                   between t.effective_date and nvl(t.disable_date, sysdate + 1);*/
        --and    (t.disable_date                  is null
        --        or t.disable_date               > trunc(sysdate));
        --
        -- 1.4  23/07/2012  Adi Safin
        /*select v.segment1
        into   l_embedded_sw_version
        from   xxobjt.xxinv_bom_explode_history t,
               mtl_item_categories_v            v,
               wip_discrete_jobs_v              wdj,
               wip_requirement_operations_v     wro
        where  t.comp_item_id                   = v.inventory_item_id
        and    v.organization_id                = 91
        and    v.category_set_name              = 'Objet Embedded SW Version'
        and    t.creation_date                  = (select max(creation_date)
                                                   from xxinv_bom_explode_history h)
        and    wdj.wip_entity_id                = wro.wip_entity_id
        and    wdj.organization_id              = wro.organization_id
        and    wro.inventory_item_id            = t.top_assembly_item_id
        and    wro.required_quantity            = wro.quantity_issued
        and    wdj.wip_entity_name              = :NEW.serial_number
        and    wro.concatenated_segments        like 'SET%'
        and    wro.wip_supply_meaning           != 'Phantom'
        and    trunc(sysdate)                   between t.effective_date and nvl(t.disable_date, sysdate + 1);*/
      
        -- 1.5  08-APR-2014  Dovik Pollak
        SELECT v.segment1
          INTO l_embedded_sw_version
          FROM mtl_item_categories_v v
         WHERE v.organization_id = 91
           AND v.category_set_name = 'Objet Embedded SW Version'
           AND v.inventory_item_id = :new.inventory_item_id;
      
      EXCEPTION
        WHEN OTHERS THEN
          l_embedded_sw_version := NULL;
      END;
    
      -- ATTRIBUTE4 for Embedded version, ATTRIBUTE5 for Studio version.
      :new.attribute4 := l_embedded_sw_version;
      :new.attribute5 := l_studio_sw_version;
      -- 1.3 18/04/2012 Dalit A. Raviv
      l_item_number := xxinv_utils_pkg.get_item_segment(:new.inventory_item_id,
                                                        91);
      l_mail_list   := xxobjt_general_utils_pkg.get_alert_mail_list('XXCSI_ITEM_INSTANCES',
                                                                    ';');
      -- 1.3
      BEGIN
        IF l_embedded_sw_version IS NULL OR l_studio_sw_version IS NULL THEN
          l_recipient_role := fnd_profile.value('XXCS_ORACLE_CS_WF_ROLE_USER');
          xxobjt_wf_mail.send_mail_text(p_to_role     => l_recipient_role, -- i v
                                        p_cc_mail     => l_mail_list, -- i v
                                        p_bcc_mail    => NULL, -- i v
                                        p_subject     => 'Printer SW Versions Traceability',
                                        p_body_text   => 'Instance id: ' ||
                                                         :new.instance_id ||
                                                         ' Top assembly Item Number: ' ||
                                                         l_item_number ||
                                                         ' Studio SW: ' ||
                                                         l_studio_sw_version ||
                                                         ' Embedded SW: ' ||
                                                         l_embedded_sw_version,
                                        p_att1_proc   => l_att1_proc, -- i v
                                        p_att2_proc   => l_att2_proc, -- i v
                                        p_att3_proc   => l_att3_proc, -- i v
                                        p_err_code    => l_err_code, -- o n
                                        p_err_message => l_err_desc); -- o v
        
          /*l_recipient := fnd_profile.value('XXCS_ORACLE_CS_EMAIL_ADDRESS'); -- 'Oracle_CS@objet.com'
          l_body      := 'Instance id: '||:NEW.instance_id ||
                         ' Top assembly Item Id: '||:NEW.inventory_item_id;
          xxfnd_smtp_utilities.send_mail2(p_recipient => l_recipient,
                                          p_subject   => 'Printer SW Versions Traceability',
                                          p_body      => l_body);*/
          /*'Instance id: '||:NEW.instance_id ||
          ' Top assembly Item Id: '||:NEW.inventory_item_id||chr(10)||
          ' Studio SW: '||l_studio_sw_version||chr(10)||
          ' Embedded SW: '||l_embedded_sw_version);*/
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          NULL;
      END;
    END IF; -- l_count
  END IF; -- profile
EXCEPTION
  WHEN OTHERS THEN
    NULL;
END xxcsi_item_instances_bir_trg1;
/
