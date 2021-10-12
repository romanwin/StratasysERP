CREATE OR REPLACE VIEW XXCONV_PO_QUOTA_STD_COST_V AS
SELECT
--------------------------------------------------------------------------
--  XXCONV_PO_QUOTA_STD_COST_V
--
---------------------------------------------------------------------------
-- Version  Date      Performer       Comments
----------  --------  --------------  -------------------------------------
--   1.0  10.10.2013  Vitaly          Initial Build
---------------------------------------------------------------------------
             ou.name                  operating_unit,
             poh.org_id,
             poh.creation_date,
             poh.segment1                quotation_number,
             'N'||poh.segment1           new_quotation_number,
             poh.type_lookup_code        document_type,
             poh.quote_type_lookup_code  quote_subtype,
             ATTACH_TAB.attachment_flag,
             poh.reply_date,
             decode(poh.currency_code,'USD',null,poh.rate_date)   rate_date,
             poh.currency_code,
             poh.quote_warning_delay,
             poh.type_lookup_code,
             poh.po_header_id,
             poh.vendor_id,
             pov.vendor_name,
             poh.vendor_site_id,
             poh.agent_id,
             poh.ship_to_location_id,
             poh.bill_to_location_id,
             poh.attribute1   po_header_attribute1,
             poh.attribute2   po_header_attribute2,
             poh.comments,
             ---PO Lines------
             pl.po_line_id,
             pl.line_num,
             pl.quantity po_line_qty,
             pl.item_description po_line_item_description,
             pl.item_revision,
             plt.line_type,
             msi.segment1 item,
             pl.vendor_product_num,
             pl.unit_meas_lookup_code,
             muom.uom_code,
             pl.unit_price,
             pl.creation_date  line_creation_date,
             ----PO Line Locations (Price Breaks) --------------
             pol.line_location_id,
             pol.shipment_num   price_breake_num,
             pol.start_date     price_breake_start_date,
             pol.end_date       price_breake_end_date,
             pol.qty_rcv_exception_code   qty_rcv_exception_code,
             pol.price_override,
             pol.price_discount,
             pol.quantity,
             pol.value_basis,
             pol.shipment_num,
             pol.ship_to_organization_id,
             pol.ship_to_location_id     price_brea_ship_to_location_id,
             orgmap.new_organization_id  new_ship_to_organization_id
        FROM po_line_locations_all pol,
             po_headers_all        poh,
             po_vendors            pov,
             po_lines_all          pl,
             po_line_types         plt,
             hr_operating_units    ou,
             mtl_system_items_b    msi,
             mtl_units_of_measure  muom,
             (select a.organization_id,
                     a.new_organization_id
              from XXINV_COST_ORG_MAP_V a
              where a.organization_id!=a.new_organization_id
                                    ) orgmap,
            (SELECT ad2.pk1_value   po_header_id,
                     'Y'    attachment_flag
              FROM fnd_attached_docs_form_vl ad2
              WHERE ad2.function_name = 'PO_POXSCERQ_Q'
              AND ad2.entity_name = 'PO_HEADERS'
                                )   ATTACH_TAB
       WHERE /*poh.po_header_id = pol.po_header_id
         AND*/ poh.closed_date IS NULL
         AND pl.po_header_id = poh.po_header_id
         AND pl.po_line_id = pol.po_line_id(+)
         AND pl.line_type_id = plt.line_type_id
         AND msi.organization_id = 91 --Master
         AND msi.inventory_item_id = pl.item_id
         ----AND nvl(pol.cancel_flag, 'N') = 'N'
         AND poh.type_lookup_code='QUOTATION'
         AND poh.status_lookup_code='A'  ------ACTIVE
         AND poh.org_id = ou.organization_id
         AND nvl(poh.vendor_id,-777)=pov.vendor_id(+)
         AND nvl(pl.unit_meas_lookup_code,'XXX')= muom.unit_of_measure(+)
         AND nvl(poh.end_date,sysdate) >= sysdate
         AND pol.ship_to_organization_id = orgmap.organization_id(+)
         AND poh.po_header_id = ATTACH_TAB.po_header_id(+)
         /*AND NOT EXISTS (select 1  ---- a.attribute1 -- NEW organization_id
                         from fnd_lookup_values_vl  a
                         where a.lookup_type = 'XXCST_INV_ORG_REPLACE'
                         and  a.attribute1=pol.ship_to_organization_id )*/
         AND EXISTS (select 1
                     from po_lines_all pl2,
                          po_line_locations_all pol2,
                          XXINV_COST_ORG_MAP_V a2
                     where pl2.po_header_id=pl.po_header_id
                     and  pl2.po_line_id=pol2.po_line_id
                     and  a2.organization_id!=a2.new_organization_id
                     and  pol2.ship_to_organization_id =a2.organization_id)
         AND NOT EXISTS (select 1  ---- NEW quotation already created
                         from  po_headers_all  poh2
                         where poh2.type_lookup_code='QUOTATION'
                         and   poh2.segment1= 'N'||poh.segment1 )
      ORDER BY poh.po_header_id, pl.line_num, pol.shipment_num;
