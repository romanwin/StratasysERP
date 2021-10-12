CREATE OR REPLACE PACKAGE BODY xxinv_ecomm_message_pkg

 AS
  ----------------------------------------------------------------------------
  --  name:            xxinv_ecomm_message_pkg
  --  create by:       Diptasurjya Chatterjee (TCS)
  --  Revision:        1.0
  --  creation date:   24/06/2015
  ----------------------------------------------------------------------------
  --  purpose :        CHG0035652 - Generic container package to handle all
  --                   inventory module related message generation, against
  --                   events recorded by API xxinv_ecomm_event_pkg
  ----------------------------------------------------------------------------
  --  ver  date        name                         desc
  --  1.0  24/06/2015  Diptasurjya Chatterjee(TCS)  CHG0035652 - initial build
  --  1.1  29/06/2015  Diptasurjya Chatterjee(TCS)  CHG0035700 - generate printer-flavor message
  -- 1.1  02/03/2016   Debarati Banerjee            CHG0037925 - Handle logic to generate item 
  --                                                data for new field DGRestricted 
  ----------------------------------------------------------------------------

  g_target_name    varchar2(20) := 'HYBRIS';


  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035652
  --          This function validates is an item is eligible for interfacing to eCommerce
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  24/06/2015  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------
  function is_ecomm_item (p_entity_id NUMBER) RETURN varchar2
  is
    l_validation_status varchar2(10) := 'FALSE';
    l_item_count        number :=0;
  begin
    select count(1)
      into l_item_count
      from mtl_system_items_b
     where inventory_item_id = p_entity_id
       and orderable_on_web_flag = 'Y'
       and customer_order_enabled_flag = 'Y'
       and organization_id = 91;

    if l_item_count > 0 then
      l_validation_status := 'TRUE';
    end if;

    return l_validation_status;
  end is_ecomm_item;


  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035652
  --          This function converts dimension UOM code to Inches
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  24/06/2015  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------
  function get_dimensions_uom_conv_code(p_unit_code         IN VARCHAR2,
                                        p_inventory_item_id IN NUMBER) return varchar2 is
    l_code VARCHAR2(100);
  begin
    select (CASE WHEN inv_convert.inv_um_convert(p_item_id => p_inventory_item_id,p_from_uom_code => p_unit_code,p_to_uom_code => 'IN') = '1'  OR
                      inv_convert.inv_um_convert(p_item_id => p_inventory_item_id,p_from_uom_code => p_unit_code,p_to_uom_code => 'IN') = '-99999' THEN p_unit_code
                 ELSE 'IN' END)
    into l_code
    from dual;

    return(l_code);
  exception
  when others then
    return(p_unit_code);
  end get_dimensions_uom_conv_code;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035652
  --          This function converts weight UOM code to LBS
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  24/06/2015  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------
  function get_weight_uom_conv_code(p_unit_code         IN VARCHAR2,
                                    p_inventory_item_id IN NUMBER) return varchar2 is
    l_code VARCHAR2(100);
  begin
    select (CASE WHEN inv_convert.inv_um_convert(p_item_id => p_inventory_item_id,p_from_uom_code => p_unit_code,p_to_uom_code => 'LBS') = '1' OR
                      inv_convert.inv_um_convert(p_item_id => p_inventory_item_id,p_from_uom_code => p_unit_code,p_to_uom_code => 'LBS') = '-99999' THEN p_unit_code
                 ELSE 'LBS' END)
    into l_code
    from dual;

    return(l_code);
  exception
  when others then
    return(p_unit_code);
  end get_weight_uom_conv_code;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035652
  --          This function converts item dimensions to Inches
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  24/06/2015  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------
  function get_dimensions_conv_value(p_unit_value        IN NUMBER,
                                     p_inventory_item_id IN NUMBER,
                                     p_uom_code          IN VARCHAR2) return number is
    l_rate NUMBER;
    l_conv_value NUMBER;
  begin
    l_rate := '';
    select (case when inv_convert.inv_um_convert(p_item_id => p_inventory_item_id,p_from_uom_code => p_uom_code,p_to_uom_code => 'IN') = '-99999' THEN 1
                 else inv_convert.inv_um_convert(p_item_id => p_inventory_item_id,p_from_uom_code => p_uom_code,p_to_uom_code => 'IN') end)
    into l_rate
    from dual;

    l_conv_value := ROUND(p_unit_value * l_rate,2);

    return(l_conv_value);
  exception
  when others then
    return(p_unit_value);
  end get_dimensions_conv_value;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035652
  --          This function converts item weight to LBS
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  24/06/2015  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------
  function get_weight_conv_value(p_unit_value IN NUMBER,
                                p_inventory_item_id IN NUMBER,
                                p_uom_code IN VARCHAR2) return number is
    l_rate NUMBER;
    l_conv_value NUMBER;
  begin
    l_rate := '';
    select (case when inv_convert.inv_um_convert(p_item_id => p_inventory_item_id,p_from_uom_code => p_uom_code,p_to_uom_code => 'LBS') = '-99999' THEN 1
                 else inv_convert.inv_um_convert(p_item_id => p_inventory_item_id,p_from_uom_code => p_uom_code,p_to_uom_code => 'LBS') end)
    into l_rate
    from dual;

    l_conv_value := ROUND(p_unit_value * l_rate,2);

    return(l_conv_value);
  exception
  when others then
    return(p_unit_value);
  end get_weight_conv_value;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035652
  --          This function generate and return product data for a given inventory_item_id
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  24/06/2015  Diptasurjya Chatterjee             Initial Build
  -- 1.1  02/03/2016  Debarati Banerjee                  CHG0037925 - Handle message data generated as
  --                                                     new field DGRestricted is added to xxinv_product_rec_type
  -- --------------------------------------------------------------------------------------------

  function generate_item_data(p_event_id  NUMBER,
                              p_entity_id NUMBER) return xxinv_product_rec_type IS
    l_product_tab xxinv_product_tab_type := xxinv_product_tab_type();

    l_product xxinv_product_rec_type;-- := xxinv_product_tab_type();
    l_status VARCHAR2(1) := 'A';
    l_ecom_item_flag VARCHAR2(10);
  begin
    l_ecom_item_flag := is_ecomm_item(p_entity_id);

    if l_ecom_item_flag = 'FALSE' then
      l_status :='I';
    end if;

    select xxinv_product_rec_type(p_event_id,
                                  msib.inventory_item_id,
                                  msib.segment1,
                                  msib.description,
                                  msib.primary_unit_of_measure,
                                  msib.hazardous_material_flag,
                    /*CHG0037925*/xxinv_utils_pkg.is_item_hazard_restricted(msib.inventory_item_id),
                                  get_dimensions_uom_conv_code(msib.dimension_uom_code,msib.inventory_item_id),
                                  get_dimensions_conv_value(msib.unit_length,msib.inventory_item_id,msib.dimension_uom_code),
                                  get_dimensions_conv_value(msib.unit_width,msib.inventory_item_id,msib.dimension_uom_code),
                                  get_dimensions_conv_value(msib.unit_height,msib.inventory_item_id,msib.dimension_uom_code),
                                  get_weight_uom_conv_code(msib.weight_uom_code,msib.inventory_item_id),
                                  get_weight_conv_value(msib.unit_weight,msib.inventory_item_id,msib.weight_uom_code),
                                  xxinv_utils_pkg.get_category_segment('SEGMENT5',1100000221,msib.inventory_item_id) /*family*/,
                                  xxinv_utils_pkg.get_category_segment('SEGMENT1',1100000221,msib.inventory_item_id) /*line of business*/,
                                  xxinv_utils_pkg.get_category_segment('SEGMENT6',1100000221,msib.inventory_item_id) /*technology*/,
                                  mcrb.attribute7 /*pack*/,
                                  mcrb.attribute8 /*color*/,
                                  mcrb.attribute9 /*flavor*/,
                                  null,
                                  XXINV_UTILS_PKG.get_category_segment('SEGMENT1',1100000201,msib.inventory_item_id) /*ava_tax_code*/,
                                  l_status,
                                  null,null,null,null,null,
                                  null,null,null,null,null,
                                  null,null,null,null,null
                                  )
      into l_product
      from mtl_system_items_b msib,
           mtl_cross_references_b mcrb
     where msib.inventory_item_id = p_entity_id
       and msib.organization_id = 91
       and msib.inventory_item_id = mcrb.inventory_item_id (+)
       and mcrb.cross_reference_type (+) = 'eCommerce';

    return l_product;
  end generate_item_data;

  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035700
  --          This function generates and returns printer flavor relationship data
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  29/06/2015  Diptasurjya Chatterjee             Initial Build
  -- 1.1  02/03/2016  Debarati Banerjee                  CHG0037925 - Handle message data generated as
  --                                                     new field DGRestricted is added to xxinv_product_rec_type
  -- --------------------------------------------------------------------------------------------

  function generate_prnt_flavor_data(p_event_id IN number,
                                     p_entity_id IN number,
                                     p_attribute1 IN varchar2) return xxinv_product_rec_type IS

    l_printer_flavor xxinv_product_rec_type;
    l_status         VARCHAR2(1) := 'A';
    l_ecom_item_flag VARCHAR2(10);
  begin
    select xxinv_product_rec_type(p_event_id,
                                  null,null,null,null,null,
                                  null,null,null,null,null,null,
                                  null,null,null,null,null,null, /*CHG0037925*/
                                  pfv.flex_value,
                                  cfv.flex_value,
                                  null,
                                  decode(pfv.enabled_flag,'Y', decode(cfv.enabled_flag,'Y','A','N','I'), 'N', 'I'),
                                  null,null,null,null,null,
                                  null,null,null,null,null,
                                  null,null,null,null,null
                                  )
      into l_printer_flavor
      from fnd_flex_values_vl pfv,
           fnd_flex_value_sets pfs,
           fnd_flex_values_vl cfv,
           fnd_flex_value_sets cfs
     where pfs.flex_value_set_name = 'XXECOM_ITEM_FLAVOR'
       and cfs.flex_value_set_name = 'XXECOM_FLAVOR_PRINTER'
       and pfs.flex_value_set_id = cfs.parent_flex_value_set_id
       and cfv.flex_value_set_id = cfs.flex_value_set_id
       and cfv.parent_flex_value_low = pfv.flex_value
       and pfv.flex_value_set_id = pfs.flex_value_set_id
       and pfv.flex_value_id = p_entity_id
       and cfv.flex_value_id = p_attribute1;

    return l_printer_flavor;
  end generate_prnt_flavor_data;

  -- --------------------------------------------------------------------------------------------
  -- Name:              generate_product_messages
  -- Create by:         Diptasurjya Chatterjee
  -- Revision:          1.0
  -- Creation date:     24/06/2015
  -- Calling Entity:    BPEL Process: http://srv-ire-bpeldev.2objet.com:8001/soa-infra/services/ecomm/ProcessProductDetailsCmp/productdetailsprocessbpel_client_ep?wsdl
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035652
  --          This procedure is used to fetch product details as per NEW events recorded in event
  --          table
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  24/06/2015  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE generate_product_messages(x_errbuf           OUT VARCHAR2,
                                      x_retcode          OUT NUMBER,
                                      p_no_of_record     IN NUMBER,
                                      --p_entity_name      IN VARCHAR2,
                                      p_bpel_instance_id IN NUMBER,
                                      p_event_id_tab     IN xxobjt.xxssys_interface_event_tab,
                                      x_products         OUT xxecom.xxinv_product_tab_type) IS

    l_product_data         xxinv_product_tab_type  := xxinv_product_tab_type();
    l_product_data_tmp     xxinv_product_rec_type;--  := xxinv_product_tab_type();

    l_event_proc_data      xxssys_interface_event_tab := xxssys_interface_event_tab();
    l_event_proc_data_tmp  xxssys_interface_event_tab := xxssys_interface_event_tab();

    l_event_update_status  VARCHAR2(1);


    l_mail_subject         VARCHAR2(200);
    l_mail_body            VARCHAR2(4000);
    l_mail_entity          VARCHAR2(4000):= null;
    l_mail_requestor       VARCHAR2(200);

    l_entity_name          VARCHAR2(10) := 'ITEM';
  BEGIN
    if p_event_id_tab is null or p_event_id_tab.count = 0 then
      l_event_update_status := xxssys_event_pkg.update_bpel_instance_id(p_no_of_record,
                                                                        l_entity_name,
                                                                        g_target_name,
                                                                        p_bpel_instance_id);

      if l_event_update_status = 'Y' then
        for entity_rec in (select event_id,entity_id from xxssys_events where bpel_instance_id = p_bpel_instance_id and status='NEW')
        loop
          begin
            xxssys_event_pkg.update_success(entity_rec.event_id);

            if l_entity_name = 'ITEM' then
              l_product_data_tmp := generate_item_data(entity_rec.event_id, entity_rec.entity_id);
              l_product_data.extend();
              l_product_data(l_product_data.count) := l_product_data_tmp;-- MULTISET UNION ALL l_product_data_tmp;
              --l_product_data_tmp := xxinv_product_rec_type;
            end if;
          exception
          when others then
            xxssys_event_pkg.update_error(entity_rec.event_id, 'UNEXPECTED ERROR: '||sqlerrm);
          end;
        end loop;
      end if;
    else
      for i in 1..p_event_id_tab.count
      loop
        l_event_update_status := xxssys_event_pkg.update_one_bpel_instance_id(p_event_id_tab(i).event_id,
                                                                              l_entity_name,
                                                                              g_target_name,
                                                                              p_bpel_instance_id);
      end loop;

      --if l_event_update_status = 'Y' then
        for entity_rec in (select event_id,entity_id from xxssys_events where bpel_instance_id = p_bpel_instance_id)
        loop
          begin
            xxssys_event_pkg.update_success(entity_rec.event_id);

            if l_entity_name = 'ITEM' then
              l_product_data_tmp := generate_item_data(entity_rec.event_id, entity_rec.entity_id);
              l_product_data.extend();
              l_product_data(l_product_data.count) := l_product_data_tmp;
            end if;
          exception
          when others then
            xxssys_event_pkg.update_error(entity_rec.event_id, 'UNEXPECTED ERROR: '||sqlerrm);
          end;
        end loop;
      --end if;
    end if;

    COMMIT;
    x_products := l_product_data;

    x_retcode := 0;
    x_errbuf  := 'COMPLETE';
  EXCEPTION
  WHEN OTHERS THEN
    x_retcode := 2;
    x_errbuf  := 'ERROR';
    l_mail_body := 'The following unexpected exception occurred for '||'Products interface.'||chr(13)||chr(10)||
                                     'Failure reason : '||chr(13)||chr(10);

    l_mail_body := l_mail_body||'  Error Message: '||SQLERRM;

    xxinv_ecomm_event_pkg.send_mail('XXINV_ECOMM_EVENT_PKG_ITEM_TO',
                                    'XXINV_ECOMM_EVENT_PKG_ITEM_CC',
                                    'Product',
                                    l_mail_body,
                                    'message preparation');

    --dbms_output.put_line('Error In Product Extraction: ' || SQLERRM);
  END generate_product_messages;

  -- --------------------------------------------------------------------------------------------
  -- Name:              generate_prnt_flavor_messages
  -- Create by:         Diptasurjya Chatterjee
  -- Revision:          1.0
  -- Creation date:     29/06/2015
  -- Calling Entity:    BPEL Process: http://srv-ire-bpeldev.2objet.com:8001/soa-infra/services/ecomm/ProcessPrinterDetailsCmp/processprinterflavorbpel_client_ep?wsdl
  -- --------------------------------------------------------------------------------------------
  -- Purpose: CHANGE - CHG0035700
  --          This procedure is used to fetch printer-flavor details as per NEW events recorded in event
  --          table
  -- --------------------------------------------------------------------------------------------
  -- Ver  Date        Name                               Description
  -- 1.0  29/06/2015  Diptasurjya Chatterjee             Initial Build
  -- --------------------------------------------------------------------------------------------
  PROCEDURE generate_prnt_flavor_messages(x_errbuf           OUT VARCHAR2,
                                          x_retcode          OUT NUMBER,
                                          p_no_of_record     IN NUMBER,
                                          --p_entity_name      IN VARCHAR2,
                                          p_bpel_instance_id IN NUMBER,
                                          p_event_id_tab     IN xxobjt.xxssys_interface_event_tab,
                                          x_printer_flavor   OUT xxecom.xxinv_product_tab_type) IS

    l_prnt_flavor_data         xxinv_product_tab_type  := xxinv_product_tab_type();
    l_prnt_flavor_data_tmp     xxinv_product_rec_type;--  := xxinv_product_tab_type();

    l_event_proc_data      xxssys_interface_event_tab := xxssys_interface_event_tab();
    l_event_proc_data_tmp  xxssys_interface_event_tab := xxssys_interface_event_tab();

    l_event_update_status  VARCHAR2(1);


    l_mail_subject         VARCHAR2(200);
    l_mail_body            VARCHAR2(4000);
    l_mail_entity          VARCHAR2(4000) := null;
    l_mail_requestor       VARCHAR2(200);

    l_entity_name          VARCHAR2(10) := 'PRNT-FLAV';
  BEGIN
    if p_event_id_tab is null or p_event_id_tab.count = 0 then
      l_event_update_status := xxssys_event_pkg.update_bpel_instance_id(p_no_of_record,
                                                                        l_entity_name,
                                                                        g_target_name,
                                                                        p_bpel_instance_id);

      if l_event_update_status = 'Y' then
        for entity_rec in (select event_id,entity_id,attribute1 from xxssys_events where bpel_instance_id = p_bpel_instance_id and status='NEW')
        loop
          begin
            xxssys_event_pkg.update_success(entity_rec.event_id);

            l_prnt_flavor_data_tmp := generate_prnt_flavor_data(entity_rec.event_id,
                                                                entity_rec.entity_id,
                                                                entity_rec.attribute1);
            l_prnt_flavor_data.extend();
            l_prnt_flavor_data(l_prnt_flavor_data.count) := l_prnt_flavor_data_tmp;
          exception
          when others then
            xxssys_event_pkg.update_error(entity_rec.event_id, 'UNEXPECTED ERROR: '||sqlerrm);
          end;
        end loop;
      end if;
    else
      for i in 1..p_event_id_tab.count
      loop
        l_event_update_status := xxssys_event_pkg.update_one_bpel_instance_id(p_event_id_tab(i).event_id,
                                                                              l_entity_name,
                                                                              g_target_name,
                                                                              p_bpel_instance_id);
      end loop;

      for entity_rec in (select event_id,entity_id,attribute1 from xxssys_events where bpel_instance_id = p_bpel_instance_id)
      loop
        begin
          xxssys_event_pkg.update_success(entity_rec.event_id);

          l_prnt_flavor_data_tmp := generate_prnt_flavor_data(entity_rec.event_id,
                                                              entity_rec.entity_id,
                                                              entity_rec.attribute1);
          l_prnt_flavor_data.extend();
          l_prnt_flavor_data(l_prnt_flavor_data.count) := l_prnt_flavor_data_tmp;
        exception
        when others then
          xxssys_event_pkg.update_error(entity_rec.event_id, 'UNEXPECTED ERROR: '||sqlerrm);
        end;
      end loop;
    end if;

    COMMIT;

    x_printer_flavor := l_prnt_flavor_data;

    x_retcode := 0;
    x_errbuf  := 'COMPLETE';
  EXCEPTION
  WHEN OTHERS THEN
    x_retcode := 2;
    x_errbuf  := 'ERROR';
    l_mail_body := 'The following unexpected exception occurred for '||'Printer-Flavor relationship interface.'||chr(13)||chr(10)||
                                     'Failure reason : '||chr(13)||chr(10);

    l_mail_body := l_mail_body||'  Error Message: '||SQLERRM;

    xxinv_ecomm_event_pkg.send_mail('XXINV_ECOMM_EVENT_PKG_ITEM_FLAVOR_TO',
                                    'XXINV_ECOMM_EVENT_PKG_ITEM_FLAVOR_CC',
                                    'Printer-Flavor',
                                    l_mail_body,
                                    'message preparation');
    dbms_output.put_line('Error In Printer-Flavor Extraction: ' || SQLERRM);
  END generate_prnt_flavor_messages;
END xxinv_ecomm_message_pkg;
/
