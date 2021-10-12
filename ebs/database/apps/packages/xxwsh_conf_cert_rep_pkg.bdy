create or replace package body XXWSH_CONF_CERT_REP_PKG is
------------------------------------------------------------------
  -- $Header: http://sv-glo-tools01p.stratasys.dmn/svn/ERP/ebs/database/apps/packages/xxwsh_conf_cert_rep_pkg.bdy 1430 2014-07-20 13:15:04Z Gary.Altman $
----------------------------------------------------------------------
  --  ver   date          name            desc
  --  1.1   20.07.2014    GARY ALTMAN     CHG0032688 - change  cursor template_cur to take printer name from cross references
  --                                                   instead of categories, remove remarks                                                       
----------------------------------------------------------------------

  Procedure PRINT_CERTIFICATES(errbuf            out varchar2,
                               retcode           out number,
                               p_organization_id in number,
                               p_delivery_id     in number
                               ) is
  
    v_request_id    number := fnd_global.conc_request_id;
    v_template_name fnd_flex_values.attribute1%type;
    v_product_line  mtl_categories_b.segment3%type;

    v_printer_name   varchar2(30);
    v_printer_style  varchar2(30);
    v_printer_copies number;
    
  
    Cursor template_cur is
                  
         select  mcr.cross_reference product_line,
                 wdd.delivery_detail_id
         from    wsh_delivery_details        wdd,
                 wsh_delivery_assignments    wda,
                 mtl_system_items_b          msi,           
                 mtl_parameters              mtp,     
                 mtl_cross_references        mcr,
                 mtl_cross_reference_types   mcrt             
         where wdd.delivery_detail_id = wda.delivery_detail_id
         and wdd.inventory_item_id = msi.inventory_item_id
         and wdd.organization_id = msi.organization_id
         and wdd.source_code = 'OE'       
         and mtp.organization_id = wdd.organization_id
         and wdd.organization_id = p_organization_id
         and wda.delivery_id = p_delivery_id      
         and mcr.cross_reference_type=mcrt.cross_reference_type
         and mcr.inventory_item_id=msi.inventory_item_id
         and mcrt.cross_reference_type='COC';
  
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
      
        fnd_file.put_line(FND_FILE.LOG,
                          'Request Submited: ' || to_char(v_Request_id));
      
        if fnd_request.add_layout('XXOBJT',
                                  'XXWSHCERCON',--template_rec.template_name,
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
           
        -- Calling the child report using fnd_request
      
        v_Request_id := fnd_request.Submit_Request(application => 'XXOBJT',
                                                   program     => 'XXWSHCERCON',
                                                   argument1   => p_organization_id,
                                                   argument2   => p_delivery_id,
                                                   argument3 => template_rec.product_line,
                                                   argument4 => serial_rec.fm_serial_number,
                                                   argument5 => serial_rec.to_serial_number);
        commit;
      
      end loop;
    
    end loop;
  
  End PRINT_CERTIFICATES;

End XXWSH_CONF_CERT_REP_PKG;
/
