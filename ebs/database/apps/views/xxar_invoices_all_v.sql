create or replace view xxar_invoices_all_v as
select  
--------------------------------------------------------------------
--  name:            XXAR_INVOICES_ALL_V
--  create by:       Dalit A. Raviv
--  Revision:        1.0 
--  creation date:   12/05/2013
--------------------------------------------------------------------
--  purpose :        CUST685 - OA2Syteline - FTP - OM General report
--                   view show all AR invoices from all OU and all types 
--------------------------------------------------------------------
--  ver  date        name              desc
--  1.0  12/05/2013  Dalit A. Raviv    initial build
--------------------------------------------------------------------
        inv_view.operating_unit,
        inv_view.item_prod_line_parent,
        inv_view.cust_location_parent,
        inv_view.trx_type,
        inv_view.order_number,
        inv_view.invoice_number,
        inv_view.po_number,
        inv_view.invoice_date,
        inv_view.invoice_gl_date,
        inv_view.line_number,
        inv_view.customer,
        inv_view.customer_account_num,
        inv_view.customer_main_business_type,
        inv_view.customer_type,
        inv_view.customer_bill_to_country,
        inv_view.customer_bill_to_state,
        inv_view.customer_bill_to_city,
        inv_view.ship_to_customer,
        inv_view.cust_ship_to_main_bus_type,
        inv_view.customer_ship_to_country,
        inv_view.customer_ship_to_state,
        inv_view.customer_ship_to_city,
        inv_view.customer_ship_to_county,
        inv_view.cust_location_seg_desc,
        inv_view.item,
        inv_view.description,
        inv_view.item_prod_line_seg,
        inv_view.item_prod_line_seg_desc,
        inv_view.item_type,
        inv_view.uom_code,
        sum(inv_view.quantity)                quantity,
        sum(inv_view.kg)                      kg,
        sum(inv_view.unit_selling_price)      unit_selling_price,
        sum(inv_view.unit_list_price)         unit_list_price,
        inv_view.average_discount,
        sum(inv_view.extended_entered_amount) extended_entered_amount,
        inv_view.invoice_currency ,
        sum(inv_view.rate_from_ent_to_func)   rate_from_ent_to_func ,
        sum(inv_view.ext_func_amount)         ext_func_amount,
        inv_view.func_currency,
        sum(inv_view.rate_from_func_to_usd)   rate_from_func_to_usd,
        sum(inv_view.extended_usd_amount)     extended_usd_amount,
        inv_view.quarter_num
from   (select
        --created by daniel katz
        ho.name Operating_Unit,
        rctl.org_id,
        'AR' currently_In,
        rba.name trx_source,
        rctt.name trx_type,
        rct.trx_number invoice_number,
        NVL(rctl.interface_line_attribute1, rct.ct_reference) order_number,
        rct.purchase_order                                    po_number,
        rct.invoice_currency_code                             invoice_currency,
        rct.trx_date                                          invoice_date,
        aps1.gl_date                                          invoice_gl_date,
        rctl.rule_start_date,
        rctl.rule_end_date,
        to_char(rctl.line_number)                             line_number,
        rctl.line_type,
        hp.party_name                                         customer,
        hca.account_number                                    customer_account_num,
        (select min(al.meaning)
         from   hz_code_assignments hcodeass, ar_lookups al
         where  hcodeass.owner_table_id    = hp.party_id
         and    hcodeass.class_category    = al.lookup_type
         and    hcodeass.class_code        = al.lookup_code
         and    hcodeass.class_category    = 'Objet Business Type'
         and    hcodeass.status            = 'A'
         and    hcodeass.start_date_active <= sysdate
         and    nvl(hcodeass.end_date_active, sysdate) >= sysdate
         and    hcodeass.owner_table_name  = 'HZ_PARTIES')    Customer_Main_Business_type,
        flv_customer_type.meaning                             customer_type,
        flv_customer_type.lookup_code                         customer_type_code,
        hl.country                                            customer_bill_to_country,
        hl.address1                                           customer_bill_to_address1,
        hl.state                                              customer_bill_to_state,
        hl.city                                               customer_bill_to_city,
        hp_ship.party_name                                    ship_to_customer,
        --business type could be one to many. Objet should use only one classification for customer.
        (select min(al.meaning)
         from   hz_code_assignments hcodeass, ar_lookups al
         where  hcodeass.owner_table_id    = hp_ship.party_id
         and    hcodeass.class_category    = al.lookup_type
         and    hcodeass.class_code        = al.lookup_code
         and    hcodeass.class_category    = 'Objet Business Type'
         and    hcodeass.status            = 'A'
         and    hcodeass.start_date_active <= sysdate
         and    nvl(hcodeass.end_date_active, sysdate) >= sysdate
         and    hcodeass.owner_table_name  = 'HZ_PARTIES')     Cust_ship_to_Main_Bus_type,
         hl_ship.country                                      customer_ship_to_country,
         hl_ship.address1                                     customer_ship_to_address1,
         hl_ship.state                                        customer_ship_to_state,
         hl_ship.city                                         customer_ship_to_city,
         hl_ship.county                                       customer_ship_to_county,
         gcc_cust_loc.segment6                                cust_location_seg,
         xxgl_utils_pkg.get_dff_value_description(1013892, gcc_cust_loc.segment6) cust_location_seg_desc,
        (select min(ffv.description)
         from   fnd_flex_value_children_v  ffvc,
                fnd_flex_values_vl         ffv,
                fnd_flex_hierarchies       ffh
         where  ffvc.flex_value_set_id     = 1013892
         and    ffvc.flex_value_set_id     = ffh.flex_value_set_id
         and    ffh.flex_value_set_id      = ffv.flex_value_set_id
         and    ffh.hierarchy_id           = ffv.structured_hierarchy_level
         and    ffvc.parent_flex_value     = ffv.flex_value
         and    ffh.hierarchy_code         = 'ACCOUNTING'
         and    ffvc.flex_value            = gcc_cust_loc.segment6)               cust_location_parent,
         gcc_item_pl.segment5                            item_prod_line_seg,
         xxgl_utils_pkg.get_dff_value_description(1013893, gcc_item_pl.segment5)  item_prod_line_seg_desc,
         decode(substr(gcc_item_pl.segment5, 1, 1), 
                '1', 'Systems','2', 'FDM-Systems','5', 'Consumables',
                '7', 'FDM-Consumables','8', 'Customer Support',
                '9', 'FDM-Maintenance and SP',  'Other')                          item_prod_line_parent,
         (select meaning
          from   fnd_lookup_values         flv
          where  flv.language              = 'US'
          and    flv.lookup_type           = 'ITEM_TYPE'
          and    flv.lookup_code           = msi.item_type)                       item_type,
         msi.segment1                                                             item,
         nvl(rctl.translated_description, rctl.description)                       description,
         replace((case when rctl.interface_line_context = 'ORDER ENTRY' 
                       and rctl.sales_order_line is not null then
                         xxinv_utils_pkg.get_serials_and_lots(rctl.interface_line_attribute6)
                       when rctl.interface_line_context = 'INTERCOMPANY' 
                       and rctl.sales_order_line is not null then
                         xxinv_utils_pkg.get_serials_and_lots(null, rctl.interface_line_attribute7)
                  end), chr(10), ' ')                                             serial_lot_exp_date,
         rctl.uom_code,
         nvl(rctl.quantity_invoiced, rctl.quantity_credited)                      quantity,
         nvl(rctl.quantity_invoiced, rctl.quantity_credited) * round(1 / mucc.conversion_rate , 3) kg,
         rctl.unit_selling_price,
         rctl.unit_standard_price                                                 unit_list_price,
         rctl.attribute10                                                         average_discount,
         rctl.extended_amount                                                     extended_entered_amount,
         nvl(rct.exchange_rate, 1)                                                rate_from_ent_to_func,
         (rctl.extended_amount) * nvl(rct.exchange_rate, 1)                       ext_func_amount,
         g_led.currency_code                                                      func_currency,
         decode(rct.invoice_currency_code,'USD', 1 / nvl(rct.exchange_rate, 1),
                gl_currency_api.get_closest_rate( g_led.currency_code, 'USD', RCT.TRX_DATE,'Corporate', 100))  rate_from_func_to_usd,
         decode(rct.invoice_currency_code,'USD', rctl.extended_amount, 
               ((rctl.extended_amount) * nvl(rct.exchange_rate, 1) *
                gl_currency_api.get_closest_rate(g_led.currency_code, 'USD', RCT.TRX_DATE, 'Corporate', 100))) extended_usd_amount,
         decode(rct.invoice_currency_code,'ILS',  rctl.extended_amount, 
               ((rctl.extended_amount) * nvl(rct.exchange_rate, 1) *
                gl_currency_api.get_closest_rate( g_led.currency_code,'ILS',RCT.TRX_DATE, 'Corporate', 100)))  extended_ILS_amount,
         gp.period_name,
         gp.quarter_num,
         rct.creation_date,
         rct.last_update_date,
         rctl.interface_line_attribute2,
         rctl.interface_line_attribute8,
         rctl.customer_trx_line_id,
         (case when rctl.interface_line_context = 'ORDER ENTRY' and rctl.sales_order_line is not null then
                 rctl.interface_line_attribute3
               when rctl.interface_line_context = 'INTERCOMPANY' and rctl.sales_order_line is not null then
                (select mmt.shipment_number
                 from   mtl_material_transactions mmt
                 where  mmt.transaction_id = rctl.interface_line_attribute7)
               else  null
         end) delivery_name
        from  ra_customer_trx_all rct,
              ra_customer_trx_lines_all rctl,
              ra_cust_trx_types_all rctt,
              mtl_system_items_b msi,
              hr_operating_units ho,
              ra_batch_sources_all rba,
              gl_ledgers g_led,
              (select aps.customer_trx_id, 
                      min(aps.gl_date)         gl_date
               from   ar_payment_schedules_all aps
               group by aps.customer_trx_id)  aps1,
              hz_parties                      hp,
              hz_party_sites                  hps,
              hz_cust_accounts                hca,
              hz_cust_acct_sites_all          hcas,
              hz_cust_site_uses_all           hcsu,
              gl_code_combinations            gcc_cust_loc,
              gl_code_combinations            gcc_item_pl,
              hz_locations                    hl,
              hz_party_sites                  hps_ship,
              hz_cust_acct_sites_all          hcas_ship,
              hz_cust_site_uses_all           hcsu_ship,
              hz_parties                      hp_ship,
              hz_locations                    hl_ship,
              gl_periods                      gp,
              mtl_uom_class_conversions       mucc,
              fnd_lookup_values               flv_customer_type
        where rctl.customer_trx_id            = rct.customer_trx_id
        and   rct.cust_trx_type_id            = rctt.cust_trx_type_id
        and   rct.org_id                      = rctt.org_id
        and   rctt.cust_trx_type_id           not between 1060 and 1067 --data conversion
        and   rctl.inventory_item_id          = msi.inventory_item_id(+)
        and   msi.organization_id(+)          =  xxinv_utils_pkg.get_master_organization_id
        and   rctl.org_id                     = ho.organization_id
        and   rct.batch_source_id             = rba.batch_source_id
        and   rct.org_id                      = rba.org_id
        and   rct.set_of_books_id             = g_led.ledger_id
        and   rct.customer_trx_id             = aps1.customer_trx_id(+)
        and   rct.bill_to_site_use_id         = hcsu.site_use_id
        and   hcsu.cust_acct_site_id          = hcas.cust_acct_site_id
        and   hcas.party_site_id              = hps.party_site_id
        and   hcas.cust_account_id            = hca.cust_account_id
        and   hp.party_id                     = hps.party_id
        and   hcsu.gl_id_rev                  = gcc_cust_loc.code_combination_id(+)
        and   msi.sales_account               = gcc_item_pl.code_combination_id(+)
        and   hps.location_id                 = hl.location_id
        and   rct.ship_to_site_use_id         = hcsu_ship.site_use_id(+)
        and   hcsu_ship.cust_acct_site_id     = hcas_ship.cust_acct_site_id(+)
        and   hcas_ship.party_site_id         = hps_ship.party_site_id(+)
        and   hps_ship.party_id               = hp_ship.party_id(+)
        and   hps_ship.location_id            = hl_ship.location_id(+)
        and   rct.complete_flag               = 'Y'
        and   rctl.inventory_item_id          = mucc.inventory_item_id(+)
        and   mucc.to_uom_code(+)             = 'KG'
        and   hca.customer_type               = flv_customer_type.lookup_code(+)
        and   flv_customer_type.language(+)   = 'US'
        and   flv_customer_type.lookup_type(+) = 'CUSTOMER_TYPE'
        and   rctt.name                       != 'Intercompany'
        and   hp.party_name                   not like '%Stratasys%'
        and   hp.party_name                   not like '%Objet%'
        and   aps1.gl_date                    between gp.start_date and gp.end_date
        Union all
        select haou_o.name                        Oper_Unit,
               rila.org_id,
               'AR Interface'                     currently_in,
               rila.batch_source_name,
               rctt.name                          trx_type,
               null                               trx_number,
               rila.sales_order,
               rila.purchase_order,
               rila.currency_code,
               trunc(nvl(nvl(rila.rule_start_date, rila.ship_date_actual),
                         rila.sales_order_date))  date1,
               trunc(nvl(nvl(rila.rule_start_date, rila.ship_date_actual),
                         rila.sales_order_date))  date2,
               rila.rule_start_date,
               rila.rule_end_date,
               rila.sales_order_line,
               rila.line_type,
               hp_bill.party_name                 Bill_customer_name,
               hca_bill.account_number            Bill_Account_num,
               --business type could be one to many. Objet should use only one classification for customer.
               (select min(al.meaning)
                  from hz_code_assignments hcodeass, 
                       ar_lookups          al
                 where hcodeass.owner_table_id    = hp_bill.party_id
                   and hcodeass.class_category    = al.lookup_type
                   and hcodeass.class_code        = al.lookup_code
                   and hcodeass.class_category    = 'Objet Business Type'
                   and hcodeass.status            = 'A'
                   and hcodeass.start_date_active <= sysdate
                   and nvl(hcodeass.end_date_active, sysdate) >= sysdate
                   and hcodeass.owner_table_name  = 'HZ_PARTIES') Customer_Main_Business_type,
               flv_customer_type.meaning                          customer_type,
               flv_customer_type.lookup_code                      customer_type_code,
               hl_bill.country                                    customer_bill_to_country,
               hl_bill.address1                                   customer_bill_to_address1,
               hl_bill.state                                      customer_bill_to_state,
               hl_bill.city                                       customer_bill_to_city,
               hp_ship.party_name                                 ship_to_customer,
               --business type could be one to many. Objet should use only one classification for customer.
               (select min(al.meaning)
                  from hz_code_assignments        hcodeass, 
                       ar_lookups                 al
                 where hcodeass.owner_table_id    = hp_ship.party_id
                   and hcodeass.class_category    = al.lookup_type
                   and hcodeass.class_code        = al.lookup_code
                   and hcodeass.class_category    = 'Objet Business Type'
                   and hcodeass.status            = 'A'
                   and hcodeass.start_date_active <= sysdate
                   and nvl(hcodeass.end_date_active, sysdate) >= sysdate
                   and hcodeass.owner_table_name  = 'HZ_PARTIES')                       Cust_ship_to_Main_Bus_type,
               hl_ship.country customer_ship_to_country,
               hl_ship.address1 customer_ship_to_address1,
               hl_ship.state customer_ship_to_state,
               hl_ship.city customer_ship_to_city,
               hl_ship.county customer_ship_to_county,
               gcc_cust_loc.segment6 cust_location_seg,
               xxgl_utils_pkg.get_dff_value_description(1013892, gcc_cust_loc.segment6) cust_location_seg_desc,
               (select min(ffv.description)
                from   fnd_flex_value_children_v ffvc,
                       fnd_flex_values_vl        ffv,
                       fnd_flex_hierarchies      ffh
                where  ffvc.flex_value_set_id    = 1013892
                and    ffvc.flex_value_set_id    = ffh.flex_value_set_id
                and    ffh.flex_value_set_id     = ffv.flex_value_set_id
                and    ffh.hierarchy_id          = ffv.structured_hierarchy_level
                and    ffvc.parent_flex_value    = ffv.flex_value
                and    ffh.hierarchy_code        = 'ACCOUNTING'
                and    ffvc.flex_value           = gcc_cust_loc.segment6)               cust_location_parent,
               gcc_item_pl.segment5                                                     item_prod_line_seg,
               xxgl_utils_pkg.get_dff_value_description(1013893, gcc_item_pl.segment5)  item_prod_line_seg_desc,
               decode(substr(gcc_item_pl.segment5, 1, 1),
                      '1', 'Systems', '2', 'FDM-Systems','5', 'Consumables',
                      '7', 'FDM-Consumables','8', 'Customer Support',
                      '9', 'FDM-Maintenance and SP', 'Other')                           item_prod_line_parent,

               (select meaning
                from   fnd_lookup_values flv
                where  flv.language      = 'US'
                and    flv.lookup_type   = 'ITEM_TYPE'
                and    flv.lookup_code   = msi.item_type)                               item_type,
               msi.segment1                                                             Item,
               nvl(rila.translated_description, rila.description)                       description,
               replace((case when rila.interface_line_context = 'ORDER ENTRY' 
                             and rila.sales_order_line is not null then
                               xxinv_utils_pkg.get_serials_and_lots(rila.interface_line_attribute6)
                             when rila.interface_line_context = 'INTERCOMPANY' 
                             and rila.sales_order_line is not null then
                               xxinv_utils_pkg.get_serials_and_lots(null, rila.interface_line_attribute7)
                        end), chr(10), ' ')                                             serial_lot_exp_date,
               rila.uom_code,
               rila.quantity,
               rila.quantity * round(1 / mucc.conversion_rate , 3)                      kg,
               rila.unit_selling_price,
               rila.unit_standard_price,
               rila.attribute10                                                         avg_discount,
               nvl((rila.quantity * rila.unit_selling_price), rila.amount)              extended_entered_amount,
               decode(rila.currency_code, gled.currency_code,1,
                      gl_currency_api.get_closest_rate(rila.currency_code,gled.currency_code,
                      nvl(nvl(rila.conversion_date, rila.ship_date_actual),  
                      rila.sales_order_date), 'Corporate',100))                         rate_from_ent_to_func,
               nvl((rila.quantity * rila.unit_selling_price), rila.amount) *
                      decode(rila.currency_code, gled.currency_code,  1,
                      gl_currency_api.get_closest_rate( rila.currency_code, gled.currency_code,
                      nvl(nvl(rila.conversion_date, rila.ship_date_actual), 
                      rila.sales_order_date),'Corporate', 100))                         ext_func_amount,
               gled.currency_code                                                       func_currency,
               gl_currency_api.get_closest_rate(gled.currency_code, 'USD',
                     nvl(nvl(rila.conversion_date, rila.ship_date_actual), 
                     rila.sales_order_date),'Corporate', 100)                           rate_from_func_to_usd,
               nvl((rila.quantity * rila.unit_selling_price), rila.amount) *
                    decode(rila.currency_code, 'USD', 1,
                    gl_currency_api.get_closest_rate(rila.currency_code,'USD',
                    nvl(nvl(rila.conversion_date, rila.ship_date_actual),
                    rila.sales_order_date), 'Corporate',100))                           extended_usd_amount,
               nvl((rila.quantity * rila.unit_selling_price), rila.amount) *
               decode(rila.currency_code, 'ILS', 1,
                      gl_currency_api.get_closest_rate(rila.currency_code, 'ILS',
                      nvl(nvl(rila.conversion_date, rila.ship_date_actual), 
                      rila.sales_order_date), 'Corporate', 100))                        extended_ils_amount,

               gp.period_name,
               gp.quarter_num,
               sysdate,
               sysdate,
               rila.interface_line_attribute2,
               rila.interface_line_attribute8,
               null invoice_line_id,
               (case when rila.interface_line_context = 'ORDER ENTRY' 
                     and rila.sales_order_line is not null then
                       rila.interface_line_attribute3
                     when rila.interface_line_context = 'INTERCOMPANY' 
                     and  rila.sales_order_line is not null then
                      (select mmt.shipment_number
                       from   mtl_material_transactions mmt
                       where  mmt.transaction_id = rila.interface_line_attribute7)
                     else null
               end)                                                                     delivery_name
        from   ra_interface_lines_ALL                rila, --for disco remove all
               gl_ledgers                        gled,
               ra_cust_trx_types_all             rctt,
               hz_cust_accounts                  hca_bill,
               hz_cust_accounts                  hca_ship,
               hz_parties                        hp_bill,
               hz_parties                        hp_ship,
               hz_party_sites                    hps_bill,
               hz_party_sites                    hps_ship,
               hz_cust_acct_sites_all            hcas_bill,
               hz_cust_acct_sites_all            hcas_ship,
               hz_cust_site_uses_all             hcsu_bill,
               hz_locations                      hl_bill,
               hz_locations                      hl_ship,
               mtl_system_items_b                msi,
               Hr_All_Organization_Units         haou_o,
               gl_code_combinations              gcc_cust_loc,
               gl_code_combinations              gcc_item_pl,
               gl_periods                        gp,
               mtl_uom_class_conversions         mucc,
               fnd_lookup_values                 flv_customer_type
        where  rila.set_of_books_id              = gled.ledger_id
        and    rila.cust_trx_type_id     	       = rctt.cust_trx_type_id
        and    rila.org_id                       = rctt.org_id
        and    rila.orig_system_bill_customer_id = hca_bill.cust_account_id
        and    hca_bill.party_id                 = hp_bill.party_id
        and    rila.orig_system_ship_customer_id =  hca_ship.cust_account_id(+)
        and    hca_ship.party_id                 = hp_ship.party_id(+)
        and    rila.orig_system_bill_address_id  =  hcas_bill.cust_acct_site_id
        and    rila.inventory_item_id            = msi.inventory_item_id(+)
        and    rila.warehouse_id                 = msi.organization_id(+)
        and    rila.org_id                       = haou_o.organization_id
        and    hcas_bill.party_site_id           = hps_bill.party_site_id
        and    rila.orig_system_ship_address_id  =  hcas_ship.cust_acct_site_id(+)
        and    hcas_ship.party_site_id           = hps_ship.party_site_id(+)
        and    hps_bill.location_id              = hl_bill.location_id
        and    hps_ship.location_id              = hl_ship.location_id(+)
        and    hcas_bill.cust_acct_site_id       = hcsu_bill.cust_acct_site_id
        and    hcsu_bill.site_use_code           = 'BILL_TO'
        and    hcsu_bill.status                  = 'A'
        and    hcsu_bill.gl_id_rev               = gcc_cust_loc.code_combination_id(+)
        and    msi.sales_account                 = gcc_item_pl.code_combination_id(+)
        and    rila.inventory_item_id            = mucc.inventory_item_id(+)
        and    mucc.to_uom_code(+)               = 'KG'
        and    hca_bill.customer_type            = flv_customer_type.lookup_code(+)
        and    flv_customer_type.language(+)     = 'US'
        and    flv_customer_type.lookup_type(+)  = 'CUSTOMER_TYPE'
        and    rctt.name                         != 'Intercompany'
        and    hp_bill.party_name                not like '%Stratasys%'
        and    hp_bill.party_name                not like '%Objet%'
        and    nvl(nvl(rila.rule_start_date, rila.ship_date_actual),
                  rila.sales_order_date) between gp.start_date and   gp.end_date
       ) inv_view               
where  --(('Y' = 'Y' and nvl(inv_view.customer_type_code, 'XX') != 'I' OR 'N' = 'Y'))
       nvl(inv_view.customer_type_code, 'XX') != 'I'
and    (inv_view.line_type = 'LINE')
--and   invoice_date > to_date('2013-01-01 00:00:01', 'yyyy-mm-dd hh24:mi:ss') -- parameter
group by  inv_view.average_discount,
          inv_view.creation_date,
          inv_view.currently_in,
          inv_view.customer,
          inv_view.customer_account_num,
          inv_view.customer_bill_to_city,
          inv_view.customer_bill_to_country,
          inv_view.customer_bill_to_state,
          inv_view.customer_main_business_type,
          inv_view.customer_ship_to_city,
          inv_view.customer_ship_to_country,
          inv_view.customer_ship_to_county,
          inv_view.customer_ship_to_state,
          inv_view.customer_trx_line_id,
          inv_view.customer_type,
          inv_view.cust_location_parent,
          inv_view.cust_location_seg,
          inv_view.cust_location_seg_desc,
          inv_view.cust_ship_to_main_bus_type,
          inv_view.delivery_name,
          inv_view.description,
          inv_view.func_currency,
          inv_view.interface_line_attribute2,
          inv_view.invoice_currency,
          inv_view.invoice_date,
          inv_view.invoice_gl_date,
          inv_view.invoice_number,
          inv_view.item,
          inv_view.item_prod_line_parent,
          inv_view.item_prod_line_seg,
          inv_view.item_prod_line_seg_desc,
          inv_view.item_type,
          inv_view.last_update_date,
          inv_view.line_number,
          inv_view.line_type,
          inv_view.operating_unit,
          inv_view.order_number,
          inv_view.po_number,
          inv_view.quarter_num,
          inv_view.rule_end_date,
          inv_view.rule_start_date,
          inv_view.serial_lot_exp_date,
          inv_view.ship_to_customer,
          inv_view.trx_source,
          inv_view.trx_type,
          inv_view.uom_code
 order by inv_view.operating_unit asc,
          inv_view.order_number   asc,
          inv_view.invoice_number asc,
          inv_view.line_number    asc
