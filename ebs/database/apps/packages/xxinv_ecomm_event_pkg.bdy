CREATE OR REPLACE PACKAGE BODY xxinv_ecomm_event_pkg AS
  ----------------------------------------------------------------------------
  --  name:            xxinv_ecomm_event_pkg
  --  create by:       Diptasurjya Chatterjee (TCS)
  --  Revision:        1.0
  --  creation date:   22/06/2015
  ----------------------------------------------------------------------------
  --  purpose :        CHG0035652 - Generic container package to handle all
  --                   inventory module related event invocations. For item
  --                   as no suitable business events were identified, triggers
  --                   has been created on base tables and processed by this API
  ----------------------------------------------------------------------------
  --  ver  date        name                         desc
  --  1.0  22/06/2015  Diptasurjya Chatterjee(TCS)  CHG0035652 - initial build
  --  1.1  29/06/2015  Diptasurjya Chatterjee(TCS)  CHG0035700 - Add procedure print_flav_trigger_processor
  --                                                to handle printer-flavor relationship trigger. Added compare_old_new_print_flav
  --                                                to compare old and new printer flavor data records
  ----------------------------------------------------------------------------

  g_target_name         VARCHAR2(10) := 'HYBRIS';

  g_event_rec xxssys_events%ROWTYPE;

  -- Name:              compare_old_new_items
  -- Create by:         Diptasurjya Chatterjee
  -- Revision:          1.0
  -- Creation date:     22/06/2015
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035652
  --          This function will be used to compare item before update with item after update
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  22/06/2015  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------

  function compare_old_new_items (p_old_item_rec item_rec_type,
                                  p_new_item_rec item_rec_type) return varchar2
  is
    l_comparison_status varchar2(10);
  begin
    if p_old_item_rec.inventory_item_id            = p_new_item_rec.inventory_item_id AND
       p_old_item_rec.segment1                     = p_new_item_rec.segment1 AND
       p_old_item_rec.organization_id              = p_new_item_rec.organization_id AND
       nvl(p_old_item_rec.description,'-1')        = nvl(p_new_item_rec.description,'-1') AND
       p_old_item_rec.primary_unit_of_measure      = p_new_item_rec.primary_unit_of_measure AND
       p_old_item_rec.hazardous_material_flag      = p_new_item_rec.hazardous_material_flag AND
       nvl(p_old_item_rec.dimension_uom_code,'-1') = nvl(p_new_item_rec.dimension_uom_code,'-1') AND
       nvl(p_old_item_rec.unit_length,0)           = nvl(p_new_item_rec.unit_length,0) AND
       nvl(p_old_item_rec.unit_width,0)            = nvl(p_new_item_rec.unit_width,0) AND
       nvl(p_old_item_rec.unit_height,0)           = nvl(p_new_item_rec.unit_height,0) AND
       nvl(p_old_item_rec.weight_uom_code,'-1')    = nvl(p_new_item_rec.weight_uom_code,'-1') AND
       nvl(p_old_item_rec.unit_weight,0)           = nvl(p_new_item_rec.unit_weight,0) AND
       p_old_item_rec.orderable_on_web_flag        = p_new_item_rec.orderable_on_web_flag AND
       p_old_item_rec.customer_order_enabled_flag  = p_new_item_rec.customer_order_enabled_flag AND
       nvl(p_old_item_rec.category_set_id,0)       = nvl(p_new_item_rec.category_set_id,0) AND
       nvl(p_old_item_rec.category_id,0)           = nvl(p_new_item_rec.category_id,0) AND
       nvl(p_old_item_rec.pack,'-1')               = nvl(p_new_item_rec.pack,'-1') AND
       nvl(p_old_item_rec.color,'-1')              = nvl(p_new_item_rec.color,'-1') AND
       nvl(p_old_item_rec.flavor,'-1')             = nvl(p_new_item_rec.flavor,'-1')
    then
      return 'TRUE';
    else
      return 'FALSE';
    end if;
  end compare_old_new_items;

  -- Name:              compare_old_new_print_flav
  -- Create by:         Diptasurjya Chatterjee
  -- Revision:          1.0
  -- Creation date:     29/06/2015
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035700
  --          This function will be used to compare printer flavor records
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  29/06/2015  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------

  function compare_old_new_print_flav (p_old_print_flav_rec printer_flavor_rec_type,
                                       p_new_print_flav_rec printer_flavor_rec_type) return varchar2
  is
    l_comparison_status varchar2(10);
  begin
    if nvl(p_old_print_flav_rec.flavor_name, '-1')    = nvl(p_new_print_flav_rec.flavor_name, '-1') AND
       nvl(p_old_print_flav_rec.printer_name, '-1')   = nvl(p_new_print_flav_rec.printer_name, '-1') AND
       nvl(p_old_print_flav_rec.status, '-1')         = nvl(p_new_print_flav_rec.status, '-1')
    then
      return 'TRUE';
    else
      return 'FALSE';
    end if;
  end compare_old_new_print_flav;

  -- Name:              get_item_details
  -- Create by:         Diptasurjya Chatterjee
  -- Revision:          1.0
  -- Creation date:     22/06/2015
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035652
  --          This function will be used to fetch web-enabled attribute values for an item
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  22/06/2015  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------
  function get_item_details(p_inventory_item_id IN NUMBER,
                         p_organization_id IN NUMBER) return item_rec_type IS
    item_rec item_rec_type;
  begin
    select msi.inventory_item_id,
           null,
           msi.organization_id,
           null,
           null,
           null,
           null,
           null,
           null,
           null,
           null,
           null,
           null,
           null,
           null,
           null,
           null,
           null,
           msi.orderable_on_web_flag,
           msi.customer_order_enabled_flag,
           null,
           null,
           null,
           null
    into item_rec
    from mtl_system_items_b msi
    where inventory_item_id = p_inventory_item_id and
          organization_id = p_organization_id;

    return item_rec;
  exception
  when NO_DATA_FOUND then
    return item_rec;
  end get_item_details;

  -- Name:              send_mail
  -- Create by:         Diptasurjya Chatterjee
  -- Revision:          1.0
  -- Creation date:     22/06/2015
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035652
  --          Send Mail for errors
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  22/06/2015  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------

  procedure send_mail (p_program_name_to   IN varchar2,
                       p_program_name_cc   IN varchar2,
                       p_entity            IN varchar2,
                       p_body              IN varchar2,
                       p_api_phase         IN varchar2 DEFAULT NULL)
  is
    l_mail_to_list     varchar2(240);
    l_mail_cc_list     varchar2(240);
    l_err_code         varchar2(4000);
    l_err_msg          varchar2(4000);
    
    l_api_phase        varchar2(240) := 'event processor';
  begin
    if p_api_phase is not null then
      l_api_phase := p_api_phase;
    end if;
    
    l_mail_to_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
                                                                  p_program_short_name => p_program_name_to);
                                                           
    l_mail_cc_list := xxobjt_general_utils_pkg.get_dist_mail_list(p_operating_unit     => NULL,
                                                                  p_program_short_name => p_program_name_cc);
    
    --dbms_output.put_line('MAIL TO: '||l_mail_to_list);
    
    xxobjt_wf_mail.send_mail_text(p_to_role     => l_mail_to_list,
                                  p_cc_mail     => l_mail_cc_list,
                                  p_subject     => 'eStore unexpected error in Oracle '||l_api_phase||' for - '||p_entity,
                                  p_body_text   => p_body,
                                  p_err_code    => l_err_code,
                                  p_err_message => l_err_msg);

  end send_mail;

  -- Name:              item_trigger_processor
  -- Create by:         Diptasurjya Chatterjee
  -- Revision:          1.0
  -- Creation date:     22/06/2015
  -- Calling Entity:    Trigger: XXINV_ITEM_AIUR_TRG1, XXINV_ITEM_CAT_AIUR_TRG1, XXINV_ITEM_XREF_AIUR_TRG1
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035652
  --          This function will be used for processing all activated triggers
  --          for item/category/cross-reference creation or update or delete
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  22/06/2015  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------

  procedure item_trigger_processor (p_old_item_rec   IN item_rec_type,
                                    p_new_item_rec   IN item_rec_type,
                                    p_trigger_name   IN varchar2,
                                    p_trigger_action IN varchar2)
  is
    l_xxssys_event_rec xxssys_events%ROWTYPE;
    l_organization     NUMBER;
    l_entity_name      VARCHAR2(10)         := 'ITEM';

  begin
    if p_trigger_action = 'DELETE' then
      l_organization := nvl(p_old_item_rec.organization_id, 91);
    else
      l_organization := nvl(p_new_item_rec.organization_id, 91);
    end if;

    if l_organization = 91 then
      l_xxssys_event_rec.target_name      := g_target_name;
      l_xxssys_event_rec.entity_name      := l_entity_name;
      l_xxssys_event_rec.entity_id        := nvl(p_new_item_rec.inventory_item_id,p_old_item_rec.inventory_item_id);
      l_xxssys_event_rec.last_updated_by  := nvl(p_new_item_rec.last_updated_by,p_old_item_rec.last_updated_by);
      l_xxssys_event_rec.created_by       := nvl(p_new_item_rec.created_by,p_old_item_rec.created_by);
      l_xxssys_event_rec.event_name       := p_trigger_name||'('||p_trigger_action||')';

      if p_trigger_action = 'UPDATE' then
        if compare_old_new_items(p_old_item_rec, p_new_item_rec) = 'FALSE' then
          if p_new_item_rec.orderable_on_web_flag = 'Y' and p_new_item_rec.customer_order_enabled_flag = 'Y' then
            l_xxssys_event_rec.active_flag := 'Y';
            xxssys_event_pkg.insert_event(l_xxssys_event_rec,'Y');
          else
            l_xxssys_event_rec.active_flag := 'N';
            if xxssys_event_pkg.is_sync(l_xxssys_event_rec) = 'TRUE' then
              xxssys_event_pkg.insert_event(l_xxssys_event_rec,'Y');
            end if;
          end if;
        end if;
      elsif p_trigger_action = 'INSERT' then
        if p_new_item_rec.orderable_on_web_flag = 'Y' and p_new_item_rec.customer_order_enabled_flag = 'Y' then
          l_xxssys_event_rec.active_flag := 'Y';
          xxssys_event_pkg.insert_event(l_xxssys_event_rec,'Y');
        else
          l_xxssys_event_rec.active_flag := 'N';
          if xxssys_event_pkg.is_sync(l_xxssys_event_rec) = 'TRUE' then
            xxssys_event_pkg.insert_event(l_xxssys_event_rec,'Y');
          end if;
        end if;
      elsif p_trigger_action = 'DELETE' then
        if p_old_item_rec.orderable_on_web_flag = 'Y' and p_old_item_rec.customer_order_enabled_flag = 'Y' then
          l_xxssys_event_rec.active_flag := 'Y';
          xxssys_event_pkg.insert_event(l_xxssys_event_rec,'Y');
        else
          l_xxssys_event_rec.active_flag := 'N';
          if xxssys_event_pkg.is_sync(l_xxssys_event_rec) = 'TRUE' then
            xxssys_event_pkg.insert_event(l_xxssys_event_rec,'Y');
          end if;
        end if;
      end if;
    end if;
  exception
  when others then
    send_mail('XXINV_ECOMM_EVENT_PKG_ITEM_TO',
              'XXINV_ECOMM_EVENT_PKG_ITEM_CC',
              'Product',
              'The following unexpected exception occurred for Product interface event processor.'||chr(13)||chr(10)||chr(10)||
               'Failed record details: '||chr(13)||chr(10)||
               '  Inventory Item ID: '||l_xxssys_event_rec.entity_id||chr(13)||chr(10)||
               '  Inventory Org: OMA - Objet Master (IO)'||chr(13)||chr(10)||
               '  Error: UNEXPECTED: '||sqlerrm);
  end item_trigger_processor;

  -- Name:              print_flav_trigger_processor
  -- Create by:         Diptasurjya Chatterjee
  -- Revision:          1.0
  -- Creation date:     29/06/2015
  -- Calling Entity:    Trigger: XXFND_VSET_VALUE_AIU_TRG1
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035700
  --          This function will be used for processing all activated triggers
  --          for value set values creation or update
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  29/06/2015  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------

  procedure print_flav_trigger_processor (p_old_print_flav_rec   IN printer_flavor_rec_type,
                                          p_new_print_flav_rec   IN printer_flavor_rec_type,
                                          p_trigger_name         IN varchar2,
                                          p_trigger_action       IN varchar2)
  is
    PRAGMA AUTONOMOUS_TRANSACTION;
    l_xxssys_event_rec xxssys_events%ROWTYPE;
    l_organization     NUMBER;
    l_entity_name      VARCHAR2(10)         := 'PRNT-FLAV';
    l_flavor           NUMBER;
    l_entity_status    VARCHAR2(1);
    is_entity_same     VARCHAR2(10) := 'FALSE';
  begin
    if p_trigger_action = 'UPDATE' then
      is_entity_same := compare_old_new_print_flav(p_old_print_flav_rec, p_new_print_flav_rec);
    end if;

    --insert into XXINV_ITEM_EVENT values (l_entity_name, p_new_print_flav_rec.flex_value_set_name||' '||is_entity_same||' '||p_trigger_action);

    if is_entity_same = 'FALSE' then
      if p_new_print_flav_rec.flex_value_set_name = 'XXECOM_ITEM_FLAVOR' then
        if p_trigger_action = 'UPDATE' then

          for rec in (select pfv.flex_value_id flavor_id,
                             cfv.flex_value_id printer_id--,
                             --decode(p_new_print_flav_rec.status,'Y', decode(cfv.enabled_flag,'Y','A','N','I'), 'N', 'I') status
                        from fnd_flex_values pfv,
                             fnd_flex_value_sets pfs,
                             fnd_flex_values cfv,
                             fnd_flex_value_sets cfs
                       where pfs.flex_value_set_name = 'XXECOM_ITEM_FLAVOR'
                         and pfs.flex_value_set_id = cfs.parent_flex_value_set_id
                         and cfv.flex_value_set_id = cfs.flex_value_set_id
                         and cfv.parent_flex_value_low = pfv.flex_value
                         and pfv.flex_value_set_id = pfs.flex_value_set_id
                         and pfv.flex_value_id = p_new_print_flav_rec.flex_value_id)
          loop
            l_xxssys_event_rec.target_name      := g_target_name;
            l_xxssys_event_rec.entity_name      := l_entity_name;
            l_xxssys_event_rec.last_updated_by  := nvl(p_new_print_flav_rec.last_updated_by,p_old_print_flav_rec.last_updated_by);
            l_xxssys_event_rec.created_by       := nvl(p_new_print_flav_rec.created_by,p_old_print_flav_rec.created_by);
            l_xxssys_event_rec.event_name       := p_trigger_name||'('||p_trigger_action||')';
            l_xxssys_event_rec.entity_id := rec.flavor_id;
            l_xxssys_event_rec.attribute1 := rec.printer_id;
            
            --if rec.status = 'A' then
              xxssys_event_pkg.insert_event(l_xxssys_event_rec,'Y');
            --else
            --  if xxssys_event_pkg.is_sync(l_xxssys_event_rec) = 'TRUE' then
            --    xxssys_event_pkg.insert_event(l_xxssys_event_rec,'Y');
            -- end if;
            --end if;
            
          end loop;
        end if;
      elsif p_new_print_flav_rec.flex_value_set_name = 'XXECOM_FLAVOR_PRINTER' then

        if p_trigger_action = 'INSERT' then
          begin
            select flex_value_id, ffvv.enabled_flag
              into l_flavor, l_entity_status
              from fnd_flex_values ffvv,
                   fnd_flex_value_sets ffvs
             where flex_value_set_name = 'XXECOM_ITEM_FLAVOR'
               and FLEX_VALUE = p_new_print_flav_rec.printer_name
               and ffvv.flex_value_set_id = ffvs.flex_value_set_id;

            l_xxssys_event_rec.target_name      := g_target_name;
            l_xxssys_event_rec.entity_name      := l_entity_name;
            l_xxssys_event_rec.last_updated_by  := nvl(p_new_print_flav_rec.last_updated_by,p_old_print_flav_rec.last_updated_by);
            l_xxssys_event_rec.created_by       := nvl(p_new_print_flav_rec.created_by,p_old_print_flav_rec.created_by);
            l_xxssys_event_rec.event_name       := p_trigger_name||'('||p_trigger_action||')';
            l_xxssys_event_rec.entity_id        := l_flavor;
            l_xxssys_event_rec.attribute1       := p_new_print_flav_rec.flex_value_id;
            
            --if l_entity_status = 'Y' and p_new_print_flav_rec.status = 'Y' then
              xxssys_event_pkg.insert_event(l_xxssys_event_rec,'Y');
            --else
            --  if xxssys_event_pkg.is_sync(l_xxssys_event_rec) = 'TRUE' then
            --    xxssys_event_pkg.insert_event(l_xxssys_event_rec,'Y');
            --  end if;
            --end if;
          exception when no_data_found then
            null;
          end;
        else
          for rec1 in (select pfv.flex_value_id flavor_id,
                              cfv.flex_value_id printer_id--,
                              --decode(p_new_print_flav_rec.status,'Y', decode(cfv.enabled_flag,'Y','A','N','I'), 'N', 'I') status
                        from fnd_flex_values pfv,
                             fnd_flex_value_sets pfs,
                             fnd_flex_values cfv,
                             fnd_flex_value_sets cfs
                       where pfs.flex_value_set_name = 'XXECOM_ITEM_FLAVOR'
                         and cfs.flex_value_set_name = 'XXECOM_FLAVOR_PRINTER'
                         and pfs.flex_value_set_id = cfs.parent_flex_value_set_id
                         and cfv.flex_value_set_id = cfs.flex_value_set_id
                         and cfv.parent_flex_value_low = pfv.flex_value
                         and pfv.flex_value_set_id = pfs.flex_value_set_id
                         and cfv.flex_value_id = p_new_print_flav_rec.flex_value_id)
          loop

            l_xxssys_event_rec.target_name      := g_target_name;
            l_xxssys_event_rec.entity_name      := l_entity_name;
            l_xxssys_event_rec.last_updated_by  := nvl(p_new_print_flav_rec.last_updated_by,p_old_print_flav_rec.last_updated_by);
            l_xxssys_event_rec.created_by       := nvl(p_new_print_flav_rec.created_by,p_old_print_flav_rec.created_by);
            l_xxssys_event_rec.event_name       := p_trigger_name||'('||p_trigger_action||')';
            l_xxssys_event_rec.entity_id := rec1.flavor_id;
            l_xxssys_event_rec.attribute1 := rec1.printer_id;

            xxssys_event_pkg.insert_event(l_xxssys_event_rec,'Y');
          end loop;
        end if;

      end if;
    end if;
    commit;
  exception
  when others then
    send_mail('XXINV_ECOMM_EVENT_PKG_ITEM_FLAVOR_TO', 
              'XXINV_ECOMM_EVENT_PKG_ITEM_FLAVOR_CC',
              'Printer-Flavor',
              'The following unexpected exception occurred for Printer-Flavor relationship interface event processor.'||chr(13)||chr(10)||chr(10)||
               'Failed record details: '||chr(13)||chr(10)||
               '  Value Set Name: '||p_new_print_flav_rec.flex_value_set_name||chr(13)||chr(10)||
               '  Value Set value: '||p_new_print_flav_rec.flavor_name||chr(13)||chr(10)||
               '  Error: UNEXPECTED: '||sqlerrm);
  end print_flav_trigger_processor;

END XXINV_ECOMM_EVENT_PKG;
/
