create or replace view XXCN_TRX_AMOUNT as
select rct.customer_trx_id, 
       rctl.customer_trx_line_id,
       oed.reseller_agent reseller_no, 
       csr_reseller.salesrep_id, 
       csr_reseller.employee_number,
       nvl((select to_number(flv.DESCRIPTION) 
              from fnd_flex_values_vl flv,
                   fnd_flex_value_sets flvs
             where flvs.flex_value_set_name='XXCN_RESELLER_COMM_SPLIT_PERC' 
               and enabled_flag = 'Y'
               and flv.parent_flex_value_low = nvl(oed.reseller_agent, oed.resller_agent) 
               and flv.flex_value_set_id = flvs.flex_value_set_id
               and flv.flex_value = (select mcbk.system_type
              from mtl_system_items_b msib,
                   mtl_item_categories mic,
                   mtl_categories_b mcb,
                   mtl_categories_b_dfv mcbk
             where msib.inventory_item_id = rctl.inventory_item_id
               and msib.organization_id = xxinv_utils_pkg.get_master_organization_id
               and msib.inventory_item_id = mic.inventory_item_id
               and msib.organization_id = mic.organization_id
               and mic.category_id = mcb.category_id
               and mcb.rowid = mcbk.row_id
               and mic.category_set_id = 1100000181)),1) factor
  from ra_customer_trx_lines_all rctl, 
       ra_customer_trx rct, 
       cn_salesreps csr_reseller,
       oe_order_headers_all oeh,
       oe_order_headers_all_dfv oed
  where rctl.customer_trx_id = rct.customer_trx_id 
  and nvl(LENGTH(TRIM(TRANSLATE(rctl.sales_order, ' +-.0123456789',' '))),0) = 0 -- all numbers 
  and oeh.order_number = rctl.sales_order 
  and nvl(oed.reseller_agent, oed.resller_agent) = csr_reseller.resource_id(+)
  and oeh.rowid = oed.row_id
  --and oeh.header_id=/*1549465--*/1586708
union
select rct.customer_trx_id, 
       rctl.customer_trx_line_id,
       oed.channel_partner reseller_no, 
       csr_channel_partner.salesrep_id, 
       csr_channel_partner.employee_number,
       nvl((select 1-to_number(flv.DESCRIPTION) 
              from fnd_flex_values_vl flv,
                   fnd_flex_value_sets flvs
             where flvs.flex_value_set_name='XXCN_RESELLER_COMM_SPLIT_PERC' 
               and enabled_flag = 'Y'
               and flv.flex_value_set_id = flvs.flex_value_set_id
               and flv.parent_flex_value_low = nvl(oed.reseller_agent, oed.resller_agent) 
               and flv.flex_value = (select mcbk.system_type
              from mtl_system_items_b msib,
                   mtl_item_categories mic,
                   mtl_categories_b mcb,
                   mtl_categories_b_dfv mcbk
             where msib.inventory_item_id = rctl.inventory_item_id
               and msib.organization_id = xxinv_utils_pkg.get_master_organization_id
               and msib.inventory_item_id = mic.inventory_item_id
               and msib.organization_id = mic.organization_id
               and mic.category_id = mcb.category_id
               and mcb.rowid = mcbk.row_id
               and mic.category_set_id = 1100000181)),1) factor
  from ra_customer_trx_lines_all rctl, 
       ra_customer_trx rct, 
       cn_salesreps csr_channel_partner,
       oe_order_headers_all oeh,
       oe_order_headers_all_dfv oed
  where rctl.customer_trx_id = rct.customer_trx_id 
    and nvl(LENGTH(TRIM(TRANSLATE(rctl.sales_order, ' +-.0123456789',' '))),0) = 0 -- all numbers 
    and oeh.order_number = rctl.sales_order 
    and oed.channel_partner = csr_channel_partner.resource_id(+) 
    and oeh.rowid = oed.row_id
    --and oeh.header_id=/*1549465--*/1586708
    and oed.channel_partner is not null
    and (select mcbk.system_type
           from mtl_system_items_b msib,
                mtl_item_categories mic,
                mtl_categories_b mcb,
                mtl_categories_b_dfv mcbk
          where msib.inventory_item_id = rctl.inventory_item_id
            and msib.organization_id = xxinv_utils_pkg.get_master_organization_id
            and msib.inventory_item_id = mic.inventory_item_id
            and msib.organization_id = mic.organization_id
            and mic.category_id = mcb.category_id
            and mcb.rowid = mcbk.row_id
            and mic.category_set_id = 1100000181) in ('LE');
/
