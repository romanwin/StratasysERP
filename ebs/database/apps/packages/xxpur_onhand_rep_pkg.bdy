CREATE OR REPLACE PACKAGE BODY XXPUR_ONHAND_REP_PKG is

  Procedure PRINT_CERTIFICATES(errbuf            out varchar2,
                               retcode           out number,
                               p_organization_id in number,
                               --p_delivery_id     in number -- CHG0041294 on 15/02/2018 for delivery id to name change
                               p_delivery_name   in varchar2 -- CHG0041294 on 15/02/2018 for delivery id to name change
                               --p_item_id         in number
                               ) is
  
    v_request_id    number := fnd_global.conc_request_id;
    v_template_name fnd_flex_values.attribute1%type;
    v_product_line  mtl_categories_b.segment3%type;
    -- v_item_id           number;
    -- v_set_layout_option varchar2(100);
    -- v_printer           varchar2(30);
    v_printer_name   varchar2(30);
    v_printer_style  varchar2(30);
    v_printer_copies number;
    -- v_serial_number     varchar2(30);
    -- v_delivery_detail_id wsh_delivery_assignments.delivery_detail_id%type;
    -- v_transaction_temp_id wsh_delivery_details.transaction_temp_id%type;
  
    Cursor template_cur is
    
      select fnvl.attribute1 template_name,
             mc.segment3 product_line,
             wdd.delivery_detail_id
      --wdd.transaction_temp_id
        from wsh_delivery_details     wdd,
             wsh_delivery_assignments wda,
             mtl_system_items_b       msi,
             mtl_categories_b         mc,
             mtl_item_categories      mic,
             mtl_parameters           mtp,
             fnd_flex_value_sets      fndvs,
             fnd_flex_values          fnvl
       where wdd.delivery_detail_id = wda.delivery_detail_id
         and wdd.inventory_item_id = msi.inventory_item_id
         and wdd.organization_id = msi.organization_id
         and wdd.source_code = 'OE'
         and mic.inventory_item_id = msi.inventory_item_id
         and mtp.organization_id = wdd.organization_id
         and wdd.organization_id = p_organization_id
         and wda.delivery_id = xxinv_trx_in_pkg.get_delivery_id(p_delivery_name) --p_delivery_id -- CHG0041294 on 15/02/2018 for delivery id to name change
            --   and mic.inventory_item_id = 10733 -- :p_item_id
         and mtp.master_organization_id = mic.organization_id
         and mic.category_id = mc.category_id
         and mic.category_set_id = 1100000041
         and fnvl.flex_value = mc.segment3
         and fnvl.flex_value_set_id = fndvs.flex_value_set_id
         and fndvs.flex_value_set_name = 'XXINV_ITEM_CATEGORY'
         and fnvl.attribute1 is not null
         and mc.segment3 is not null;
  
    Cursor serial_cur(p_delivery_detail_id number) is
    
      select delivery_detail_id,
             serial_txn_id,
             serial_number fm_serial_number,
             to_serial_number to_serial_number
        from (SELECT wdd.delivery_detail_id delivery_detail_id,
                     nvl(wdd.transaction_temp_id, -99) serial_txn_id,
                     wdd.serial_number serial_number,
                     NULL to_serial_number
                FROM wsh_delivery_details wdd
               WHERE lot_number IS NULL
                 AND serial_number is NOT NULL
                 AND transaction_temp_id IS NULL
                 AND container_flag IN ('N', 'Y') -- Added for MDC impact
              UNION ALL
              SELECT -99 delivery_detail_id,
                     transaction_temp_id serial_txn_id,
                     nvl(vendor_serial_number, fm_serial_number) serial_number,
                     to_serial_number to_serial_number
                FROM mtl_serial_numbers_temp msnt
              UNION ALL
              SELECT wdd.delivery_detail_id delivery_detail_id,
                     nvl(wdd.transaction_temp_id, -99) serial_txn_id,
                     nvl(msnt.vendor_serial_number, msnt.fm_serial_number) serial_number,
                     msnt.to_serial_number to_serial_number
                FROM mtl_serial_numbers_temp msnt, wsh_delivery_details wdd
               WHERE wdd.transaction_temp_id IS NOT NULL
                 AND wdd.lot_number IS NULL
                    --AND wdd.revision IS NULL
                 AND wdd.transaction_temp_id = msnt.transaction_temp_id
                 AND wdd.container_flag IN ('N', 'Y') -- Added for MDC impact
              UNION ALL
              SELECT wdd.delivery_detail_id delivery_detail_id,
                     nvl(wdd.transaction_temp_id, -99) serial_txn_id,
                     wsn.fm_serial_number serial_number,
                     wsn.to_serial_number to_serial_number
                FROM wsh_serial_numbers wsn, wsh_delivery_details wdd
               WHERE wdd.transaction_temp_id IS NOT NULL
                 AND wdd.lot_number IS NULL
                 AND wdd.delivery_detail_id = wsn.delivery_detail_id
                 AND wdd.container_flag IN ('N', 'Y') -- Added for MDC impact
              UNION ALL
              SELECT wdd.delivery_detail_id,
                     null,
                     ms.fm_serial_number,
                     ms.to_serial_number
                FROM mtl_material_transactions_temp m,
                     mtl_txn_request_lines          a,
                     mtl_serial_numbers_temp        ms,
                     wsh_delivery_details           wdd
               WHERE m.move_order_line_id = a.line_id
                 AND m.transaction_temp_id = ms.transaction_temp_id
                 AND wdd.move_order_line_id = a.line_id)
       WHERE delivery_detail_id = p_delivery_detail_id;
  
    serial_rec serial_cur%rowtype;
  
  Begin
  
    for template_rec in template_cur loop
    
      for serial_rec in serial_cur(template_rec.delivery_detail_id) loop
      
        dbms_output.put_line('Template Name: ' || v_template_name);
        dbms_output.put_line('Product Line:     ' || v_product_line);
        dbms_output.put_line('Delivery Name:       ' || p_delivery_name); -- CHG0041294 on 15/02/2018 for delivery id to name change
                             --to_char(p_delivery_id));                    -- CHG0041294 on 15/02/2018 for delivery id to name change
      
        fnd_file.put_line(FND_FILE.LOG,
                          'Request Submited: ' || to_char(v_Request_id));
      
        if fnd_request.add_layout('XXOBJT',
                                  template_rec.template_name,
                                  'en',
                                  'US',
                                  'PDF') then
          null;
        end if;
      
        select t.printer, t.print_style, t.number_of_copies
          into v_printer_name, v_printer_style, v_printer_copies
          from fnd_concurrent_requests t
         where t.request_id = fnd_global.CONC_REQUEST_ID;
    
         if v_printer_name is not null then
             if  fnd_request.set_print_options(v_printer_name,
                                                         v_printer_style,
                                                         v_printer_copies, -- no of copies
                                                         TRUE,
                                                         'N') then null;
             end if;
            end if;
    
        /*   begin
            
            select printer_name
                into v_printer_name
                from fnd_concurrent_programs
               where CONCURRENT_PROGRAM_NAME = 'XXWSHCERTIF';
            exception
              when others then
                null;
              
            end;
         
            if v_printer_name is not null then
             if  fnd_request.set_print_options(v_printer_name,
                                                         null,
                                                         1, -- no of copies
                                                         TRUE,
                                                         'N') then null;
             end if;
            end if;
        */
        -- Calling the child report using fnd_request
      
        v_Request_id := fnd_request.Submit_Request(application => 'XXOBJT',
                                                   program     => 'XXWSHCERCON',
                                                   argument1   => p_organization_id,
                                                   argument2   => xxinv_trx_in_pkg.get_delivery_id(p_delivery_name), --p_delivery_id,  -- CHG0041294 on 15/02/2018 for delivery id to name change
                                                   --argument3   => p_item_id,
                                                   argument3 => template_rec.product_line,
                                                   argument4 => serial_rec.fm_serial_number,
                                                   argument5 => serial_rec.to_serial_number);
        commit;
      
      end loop;
    
    end loop;
  
  End PRINT_CERTIFICATES;

End XXPUR_ONHAND_REP_PKG;
/