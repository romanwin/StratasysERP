CREATE OR REPLACE VIEW XQS_VSOE_SYS_WITHOUT_RATES_V AS
(
select
--------------------------------------------------------------------
--  name:             XQS_VSOE_SYS_WITHOUT_RATES_V
--  create by:        yuval tal
--  Revision:         1.0
--  creation date:    15/05/2011
--------------------------------------------------------------------
--  purpose :         CHG0033308- BI alert VSOE System Without Rates does not pull all systems
--
--------------------------------------------------------------------
--  ver  date         name            desc
--  1.0  15/05/2011   yuval tal       initial build
--  1.1  08-Apr-2014  Ofer Suad       CHG0031891
--  1.2  15/12/2014   Ofer Suad       CHG0034054
--  1.3  26/04/2015   Ofer Suad       CHG0035120 - add warranty end date condition
--  1.4  16/10/2017   Ofer Suad       CHG0041688 Support Kit system item
--  1.5  05/05/2019   Ofer Suad       CHG0045976 - Add SDM items
--  1.6  19/07/2021   Ofer Suad       CHG0050384-  VSOE triplecheck report show missing rate fro MB items when  customer location is not in US - but rate exists 
--------------------------------------------------------------------
        hp.name                "Operating Unit",
        rta.trx_number         "Invoice Numnber",
        rta.trx_date           "Invoice Date",
        mb.segment1            "Item Code",
        mb.description         "Item Description",
        --  1.2  15/12/2014   Ofer Suad       CHG0034054
        nvl(oh.attribute7, decode(hca.sales_channel_code, 'INDIRECT', 'Indirect deal', 'DIRECT', 'Direct deal', hca.sales_channel_code)) "Cahnnel",
        -- end
        null                   "Location Code "
from    ra_customer_trx_lines_all rcl,
        ra_customer_trx_all       rta,
        oe_order_lines_all        ol,
        oe_order_headers_all      oh,
        ra_batch_sources_all      rbs,
        ra_cust_trx_types_all     rcta,
        hr_operating_units        hp,
        mtl_system_items_b        mb,
        hz_cust_site_uses_all     hcu,
        hz_cust_acct_sites_all    hcs,
        hz_cust_accounts          hca,
        mtl_material_transactions mmt
where   rcl.interface_line_attribute6 = ol.line_id
and     rcl.interface_line_context    = 'ORDER ENTRY'
and     hcu.site_use_id               = rta.bill_to_site_use_id
and     hcs.cust_acct_site_id         = hcu.cust_acct_site_id
and     hca.cust_account_id           = hcs.cust_account_id
and     oh.header_id                  = ol.header_id
and     rcl.org_id                    = hp.organization_id
--CHG0045976 - Add SDM items
--and     xxhz_party_ga_util.is_system_item(ol.inventory_item_id) = 'Y'
and xxinv_item_classification.is_system_item(mb.inventory_item_id,
                                                xxinv_utils_pkg.get_master_organization_id) = 'Y'
     and xxar_warranty_rates_pkg.get_Item_technology_rule(mb.inventory_item_id)='OPERATING_UNIT'
and     rta.cust_trx_type_id          = rcta.cust_trx_type_id
and     nvl(rcta.attribute8, 'N')     = 'Y'
and     rta.customer_trx_id           = rcl.customer_trx_id
and     rbs.name                      in ('ORDER ENTRY', 'ORDER ENTRY CM')
and     rta.trx_date                  > '30-jun-2014'
and     mb.inventory_item_id          = ol.inventory_item_id
and     mb.organization_id            = xxinv_utils_pkg.get_master_organization_id
--and     rcl.org_id                    != 683
and     xxoe_utils_pkg.is_bundle_line(rcl.interface_line_attribute6)!='Y'
and     rbs.batch_source_id           = rta.batch_source_id
--16/10/2017   Ofer Suad       CHG0041688 Support Kit system item
AND mmt.trx_source_line_id = case
               when ol.item_type_code = 'KIT' then
                (SELECT oll1.line_id
                   FROM oe_order_lines_all oll1
                  where oll1.header_id = ol.header_id
                    and oll1.top_model_line_id = ol.line_id
                    and xxhz_party_ga_util.is_system_item(ol.inventory_item_id) = 'Y'
                    and oll1.line_id != oll1.top_model_line_id and rownum=1)
               else
                ol.line_id
             end
         and mmt.transaction_type_id in (33,15)
          and not exists(       select sum(g.amount)
                    from ra_cust_trx_line_gl_dist_all g
                    where g.customer_trx_line_id=rcl.customer_trx_line_id
                    and g.account_class='REV'
                    having sum(g.amount)=0)
and     not exists (select 1
                    from   xxar_warranty_rates  wr
                    where  wr.org_id            = rcl.org_id
 --    26/04/2015   Ofer Suad       CHG0035120
                      and   rta.trx_date between wr.from_date and nvl (wr.to_date,sysdate)
                    and    ol.inventory_item_id = wr.inventory_item_id
                    and    nvl(oh.attribute7, decode(hca.sales_channel_code, 'INDIRECT', 'Indirect deal', 'DIRECT', 'Direct deal', hca.sales_channel_code)) = wr.channel)
and     not exists (select 1
                    from   xxcs_sales_ug_items_v t
                    where  ol.inventory_item_id  = t.upgrade_item_id)
union all
select  hp.name,
        rta.trx_number,
        rta.trx_date,
        mb.segment1,
        mb.description,
        --  1.2  15/12/2014   Ofer Suad       CHG0034054
        --oh.attribute7,
        nvl(oh.attribute7, decode(hca.sales_channel_code, 'INDIRECT', 'Indirect deal', 'DIRECT', 'Direct deal', hca.sales_channel_code)) attribute7,
         --    19/07/2021   Ofer Suad       CHG0050384     
        xxar_utils_pkg.get_rev_reco_cust_loc_parent(xxgl_utils_pkg.get_cust_location_segment(hl.state,
                                                                                                   xxar_warranty_rates_pkg.get_location_segemnt(hps.party_site_id))) location_code

       -- nvl(xxar_utils_pkg.get_rev_reco_cust_loc_parent(xxgl_utils_pkg.get_cust_location_segment(hl.state, nvl(gcc.segment6,'803'))),'USA') location_code
from    ra_customer_trx_lines_all rcl,
        ra_customer_trx_all       rta,
        oe_order_lines_all        ol,
        oe_order_headers_all      oh,
        ra_batch_sources_all      rbs,
        hr_operating_units        hp,
        ra_cust_trx_types_all     rcta,
        gl_code_combinations      gcc,
        hz_cust_site_uses_all     hcu,
        hz_cust_acct_sites_all    hcs,
        hz_party_sites            hps,
        hz_cust_accounts          hca,
        hz_locations              hl,
        mtl_system_items_b        mb,
        mtl_material_transactions mmt
where   hp.organization_id        = rcl.org_id
and     hcu.site_use_id           = rta.bill_to_site_use_id
and     hcs.cust_acct_site_id     = hcu.cust_acct_site_id
and     hps.party_site_id         = hcs.party_site_id
and     hl.location_id            = hps.location_id
and     rcl.interface_line_attribute6 = ol.line_id
and     oh.header_id              = ol.header_id
--CHG0045976 - Add SDM items
--and     xxinv_utils_pkg.is_fdm_system_item(ol.inventory_item_id) = 'Y'
 and xxinv_item_classification.is_system_item(mb.inventory_item_id,
                                                xxinv_utils_pkg.get_master_organization_id) = 'Y'
     and xxar_warranty_rates_pkg.get_Item_technology_rule(mb.inventory_item_id)='CUSTOMER_LOCATION'
and     rta.cust_trx_type_id      = rcta.cust_trx_type_id
and     nvl(rcta.attribute8, 'N') = 'Y'
and     hca.cust_account_id       = hcs.cust_account_id
and     rta.trx_date              > '30-jun-2014'
and     rta.customer_trx_id       = rcl.customer_trx_id
and     rbs.name                  in ('ORDER ENTRY', 'ORDER ENTRY CM')
and     rbs.batch_source_id       = rta.batch_source_id
and     gcc.code_combination_id(+) = hcu.gl_id_rev --rg.code_combination_id
and     mb.inventory_item_id      = ol.inventory_item_id
and     mb.organization_id        = xxinv_utils_pkg.get_master_organization_id
and     xxar_utils_pkg.set_rev_reco_cust_loc_parent = 1
and     xxoe_utils_pkg.is_bundle_line(rcl.interface_line_attribute6)!='Y'
--16/10/2017   Ofer Suad       CHG0041688 Support Kit system item
AND mmt.trx_source_line_id = case
               when ol.item_type_code = 'KIT' then
                (SELECT oll1.line_id
                   FROM oe_order_lines_all oll1
                  where oll1.header_id = ol.header_id
                    and oll1.top_model_line_id = ol.line_id
                    and xxinv_utils_pkg.is_fdm_system_item(oll1.inventory_item_id) = 'Y'
                    and oll1.line_id != oll1.top_model_line_id and rownum=1)
               else
                ol.line_id
             end
         and mmt.transaction_type_id in (33,15)
 and not exists(       select sum(g.amount)
                    from ra_cust_trx_line_gl_dist_all g
                    where g.customer_trx_line_id=rcl.customer_trx_line_id
                    and g.account_class='REV'
                    having sum(g.amount)=0)
and     not exists (select 1
                    from   mtl_item_categories_v mic
                    where  mic.inventory_item_id = ol.inventory_item_id
                    and    mic.organization_id   = xxinv_utils_pkg.get_master_organization_id
                    and    mic.category_set_name = 'Activity Analysis'
                    and    mic.segment1          = 'Upgrade Kits')
and     not exists (select 1
                    from   xxar_warranty_rates wr
                    where  wr.org_id = 737
 --    26/04/2015   Ofer Suad       CHG0035120
                    and   rta.trx_date between wr.from_date and nvl (wr.to_date,sysdate)
                    and    ol.inventory_item_id = wr.inventory_item_id
                    and    nvl(oh.attribute7,decode(hca.sales_channel_code,'INDIRECT','Indirect deal','DIRECT','Direct deal',hca.sales_channel_code))= wr.channel
  --    19/07/2021   Ofer Suad       CHG0050384     
  and xxar_utils_pkg.get_rev_reco_cust_loc_parent(xxgl_utils_pkg.get_cust_location_segment(hl.state,
                                                                                                   xxar_warranty_rates_pkg.get_location_segemnt(hps.party_site_id))) =
              
                  --  and    xxar_utils_pkg.get_rev_reco_cust_loc_parent(xxgl_utils_pkg.get_cust_location_segment(hl.state,nvl(gcc.segment6,'803'))) =
                           xxgl_utils_pkg.get_dff_value_description(1013892,wr.location_code)))
/                           
;
