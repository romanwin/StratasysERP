create or replace trigger XXOE_ORDER_LINES_ALL_TRG2
--------------------------------------------------------------------
  -- $Header: http://sv-glo-tools01p.stratasys.dmn/svn/ERP/ebs/database/apps/trigger/XXOE_ORDER_LINES_ALL_TRG2.trg 1506 2014-08-25 21:29:39Z Gary.Altman $
  --------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.0   25.08.2014    Gary Altman     CHG0032648 - initial version
  --------------------------------------------------------------------
  
  before update of flow_status_code on OE_ORDER_LINES_ALL
  for each row
declare
  l_parent_item_id number;
  l_line_id        number;
  l_attr4          number;
  l_desc           varchar2(1000);
  l_attr12         varchar2(255);
  l_attr13         varchar2(255);
  l_check_cs       number;
  l_order_type_id  number;
  l_context        varchar2(30);
begin
      if upper(:new.flow_status_code) = 'BOOKED' then

        select xx_om_pto_so_line_attr_pkg.get_parent_item_id(:new.header_id, :new.top_model_line_id)
        into l_parent_item_id
        from dual;

        if :new.ordered_item = 'RESIN CREDIT' then

           begin

             select resin_credit_amount
             into l_attr4
             from  xx_om_pto_so_lines_attributes
             where pto_item              = l_parent_item_id
             and   price_list            = :new.price_list_id;

             :new.attribute4 := l_attr4;

           exception
             when others then
               l_attr4 := null;
           end;

           begin

             select ((select ooha.transactional_curr_code
                     from   oe_order_headers_all ooha
                     where  ooha.header_id = :new.header_id)
                    || ' ' ||
                     l_attr4
                    || ' ' ||
                    (select t.description
                     from mtl_system_items_tl t
                     where t.inventory_item_id = :new.inventory_item_id
                     and   organization_id     = :new.ship_from_org_id
                     and   t.language          = 'US'))
             into l_desc
             from dual;

             :new.user_item_description  := l_desc;

           exception
             when others then
               l_desc := null;
           end;

        end if;

        begin
          select nvl(1,0)
          into l_check_cs
          from   mtl_item_categories_v mic_sc,
                 mtl_system_items_b msi,
                 xx_om_pto_so_lines_attributes pto
          where  msi.inventory_item_id          = :new.inventory_item_id
          and    mic_sc.inventory_item_id       = msi.inventory_item_id
          and    mic_sc.organization_id         = msi.organization_id
          and    msi.organization_id            = 91
          and    mic_sc.category_set_name       = 'Activity Analysis'
          and    mic_sc.segment1                = 'Contracts'
          and    msi.inventory_item_status_code not in ('XX_DISCONT','Inactive','Obsolete')
          and    msi.coverage_schedule_id       is null
          and    msi.primary_uom_code          != 'EA'
          and    pto.pto_item                   = l_parent_item_id
          and    pto.price_list                 = :new.price_list_id
          and    pto.service_contract_item      = :new.inventory_item_id;
        exception
          when others then
            l_check_cs := 0;
        end;

        if l_check_cs = 1 then

          begin
            select to_char(add_months(trunc(sysdate), warranty_period))
            into l_attr12
            from xx_om_pto_so_lines_attributes
            where pto_item               = l_parent_item_id
            and   price_list             = :new.price_list_id
            and   service_contract_item  = :new.inventory_item_id;

          :new.attribute12 := l_attr12;

          exception
            when others then
              l_attr12 := null;
          end;

          begin

            select to_char(add_months(trunc(sysdate), warranty_period + service_contract_period))
            into l_attr13
            from xx_om_pto_so_lines_attributes
            where pto_item              = l_parent_item_id
            and   price_list            = :new.price_list_id
            and   service_contract_item = :new.inventory_item_id;

            :new.attribute13 := l_attr13;

          exception
            when others then
              l_attr13 := null;
          end;

          begin

            select xx_om_pto_so_line_attr_pkg.get_line_id(:new.header_id, :new.top_model_line_id)
            into   l_line_id
            from xx_om_pto_so_lines_attributes
            where pto_item              = l_parent_item_id
            and   price_list            = :new.price_list_id
            and   service_contract_item = :new.inventory_item_id;

            :new.attribute15 := l_line_id;

          exception
            when others then
              l_line_id := null;
          end;

          begin

            select oh.order_type_id
            into l_order_type_id
            from oe_order_headers_all oh
            where oh.header_id = :new.header_id;

            select t.name
            into l_context
            from oe_transaction_types_tl t
            where t.transaction_type_id = l_order_type_id
            and   t.language            = 'US';

            :new.context := l_context;

          exception
            when others then
              null;

          end;

       end if;
     end if;

end XXOE_ORDER_LINES_ALL_TRG1;
/
