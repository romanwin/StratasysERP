CREATE OR REPLACE VIEW XXCONV_PO_STD_COST_V AS
SELECT
--------------------------------------------------------------------------
--  XXCONV_PO_STD_COST_V
--
---------------------------------------------------------------------------
-- Version  Date      Performer       Comments
----------  --------  --------------  -------------------------------------
--   1.0  28.07.2013  Vitaly          Initial Build
---------------------------------------------------------------------------
             ou.name                  operating_unit,
             poh.org_id,
             poh.closed_code,
             poh.creation_date,
             poh.segment1             po_number,
             poh.revision_num,
             poh.type_lookup_code,
             poh.authorization_status,
             poh.po_header_id,
             poh.vendor_id,
             pov.vendor_name,
             poh.vendor_site_id,
             poh.agent_id,
             poh.currency_code,
             ---PO Lines------
             pl.po_line_id,
             pl.line_num  old_line_num,
             ----DENSE_RANK() OVER (PARTITION BY poh.po_header_id ORDER BY pl.line_num NULLS LAST)  rank_row_num,
             /*(SELECT MAX(pl2.line_num)
                FROM po_lines_all pl2
               WHERE pl2.po_header_id = poh.po_header_id) + DENSE_RANK() OVER (PARTITION BY poh.po_header_id ORDER BY pl.line_num NULLS LAST)  line_num,*/
             pl.line_num + 0.1   line_num,
             pl.quantity po_line_qty,
             pl.item_description po_line_item_description,
             pl.item_revision,
             plt.line_type,
             msi.segment1 item,
             pl.unit_price,
             pl.attribute_category,
             pl.attribute1,
             pl.attribute2,
             pl.attribute3,
             pl.attribute4,
             pl.attribute5,
             pl.attribute6,
             pl.attribute7,
             pl.attribute8,
             pl.attribute9,
             pl.attribute10,
             pl.attribute11,
             pl.attribute12,
             pl.attribute13,
             pl.attribute14,
             pl.attribute15,
             ----PO Line Locations (Shipment) --------------
             pol.line_location_id,
             nvl(pol.encumbered_flag, 'N') encumbered_flag, -- Y --This PO Shipment is RESERVED --- We neew UNRESERVE this shipment

             MAX(decode(nvl(pol.encumbered_flag, 'N'),'Y',1,0)) OVER (PARTITION BY poh.po_header_id) do_reserve_flag, -- 1-we need RESERVE this PO Header at the end of process...

             pol.quantity_billed,
             pol.quantity,
             pol.unit_meas_lookup_code uom,
             pol.shipment_num  old_shipment_num,
             row_number() over(PARTITION BY pl.po_line_id ORDER BY pl.po_line_id, pol.shipment_num NULLS LAST) shipment_num,
             pol.ship_to_location_id,
             pol.ship_to_organization_id,
             orgmap.new_organization_id  new_ship_to_organization_id,
             (nvl(pol.quantity -
                  decode(pl.item_id,
                         NULL,
                         nvl(pol.quantity_billed, pol.quantity_received),
                         pol.quantity_received + pol.quantity_cancelled),
                 0)) new_shipment_qty,
             pol.promised_date shipment_promised_date,
             pol.need_by_date shipment_need_by_date,
             pol.attribute3 shipment_attribute3,
             pol.attribute4 shipment_attribute4
        FROM po_line_locations_all pol,
             po_headers_all        poh,
             po_vendors            pov,
             po_lines_all          pl,
             po_line_types         plt,
             hr_operating_units    ou,
             mtl_system_items_b    msi,
             XXINV_COST_ORG_MAP_V  orgmap
       WHERE poh.po_header_id = pol.po_header_id
         AND abs(nvl(pol.quantity -
                     decode(pl.item_id,
                            NULL,
                            nvl(pol.quantity_billed, pol.quantity_received),
                            pol.quantity_received + pol.quantity_cancelled),
                     0)) > 0.01
        ---AND poh.authorization_status IN ('APPROVED') --- this condition moved to xxconv_purchasing_entities_pkg.fill_log_table
         AND poh.closed_date IS NULL
         AND pl.po_header_id = poh.po_header_id
         AND pol.po_line_id = pl.po_line_id
         AND pl.line_type_id = plt.line_type_id
         AND msi.organization_id = 91 --Master
         AND msi.inventory_item_id = pl.item_id
         AND nvl(pol.cancel_flag, 'N') = 'N'
         AND nvl(pol.closed_code, '-1') NOT IN
             ('CLOSED',
              'FINALLY CLOSED',
              'CLOSED FOR RECEIVING',
              'CLOSED FOR INVOICE')
         AND poh.type_lookup_code='STANDARD'
         AND pol.match_option = 'R' ---Receipt
         ---AND nvl(pol.encumbered_flag, 'N') = 'Y' ---Shipment is RESERVED
         AND poh.org_id = ou.organization_id
         AND poh.vendor_id<> 4472 ---- Stratasys, Inc.
         AND nvl(pol.drop_ship_flag,'N')<>'Y'
         AND nvl(poh.vendor_id,-777)=pov.vendor_id(+)
         AND poh.org_id<>89 ----USA OU---
         AND poh.creation_date >= to_date('01-JAN-2012','DD-MON-YYYY')
         AND NOT EXISTS (SELECT 1
                         FROM po_lines_all          pl2,
                              po_line_types         plt2
                         WHERE pl2.line_type_id = plt2.line_type_id
                         AND pl2.po_header_id=poh.po_header_id
                         AND plt2.line_type='Outside processing')
         AND orgmap.organization_id!=orgmap.new_organization_id
         AND orgmap.organization_id= pol.ship_to_organization_id
         AND NOT EXISTS (select 1
                         from fnd_lookup_values_vl  a
                         where a.lookup_type = 'XXCST_INV_ORG_REPLACE'
                         and  a.attribute1=pol.ship_to_organization_id )
         --and poh.org_id=81 ----ISRAEL OU---- FOR DEBUG ONLY --- FOR DEBUG ONLY ---FOR DEBUG ONLY ---FOR DEBUG ONLY ---FOR DEBUG ONLY ---
         --and pol.ship_to_organization_id<>92 ----WRI...   ---- FOR DEBUG ONLY --- FOR DEBUG ONLY ---FOR DEBUG ONLY ---FOR DEBUG ONLY ---
      ORDER BY poh.po_header_id, pl.line_num, pol.shipment_num;
