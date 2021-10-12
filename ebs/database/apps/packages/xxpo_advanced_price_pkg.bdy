CREATE OR REPLACE PACKAGE BODY xxpo_advanced_price_pkg AS
  /* $Header: POXQPRVB.pls 120.8 2006/09/25 19:28:21 pxiao noship $ */

  -- Private package constants
  g_pkg_name CONSTANT VARCHAR2(30) := 'PO_ADVANCED_PRICE_PVT';
  g_log_head CONSTANT VARCHAR2(50) := 'po.plsql.' || g_pkg_name || '.';

  -- Debugging
  g_debug_stmt  BOOLEAN := po_debug.is_debug_stmt_on;
  g_debug_unexp BOOLEAN := po_debug.is_debug_unexp_on;

  --------------------------------------------------------------------------------
  -- Forward procedure declarations
  --------------------------------------------------------------------------------

  /*PROCEDURE log_pricing(p_org_id                   NUMBER,
                        p_destination_organization NUMBER,
                        p_source_organization      NUMBER,
                        p_list_header_id           NUMBER,
                        p_user_name                VARCHAR2,
                        p_unit_price               NUMBER,
                        p_item_id                  NUMBER,
                        p_source                   VARCHAR2) IS
     PRAGMA AUTONOMOUS_TRANSACTION;
  
  BEGIN
  
     INSERT INTO xxobjt_advanced_price
        (price_date,
         org_id,
         destination_organization,
         source_organization,
         list_header_id,
         user_name,
         unit_price,
         item_id,
         SOURCE,
         id)
     VALUES
        (SYSDATE,
         p_org_id,
         p_destination_organization,
         p_source_organization,
         p_list_header_id,
         p_user_name,
         p_unit_price,
         p_item_id,
         p_source,
         xxobjt_advanced_price_s.NEXTVAL);
  
     COMMIT;
  
  END log_pricing;*/

  PROCEDURE populate_header_record(p_org_id              IN NUMBER,
                                   p_order_header_id     IN NUMBER,
                                   p_supplier_id         IN NUMBER,
                                   p_supplier_site_id    IN NUMBER,
                                   p_creation_date       IN DATE,
                                   p_order_type          IN VARCHAR2,
                                   p_ship_to_location_id IN NUMBER,
                                   p_ship_to_org_id      IN NUMBER
                                   -- <FSC R12 START>
                                   -- New Attributes for R12: Receving FSC support
                                  ,
                                   p_shipment_header_id    IN NUMBER DEFAULT NULL,
                                   p_hazard_class          IN VARCHAR2 DEFAULT NULL,
                                   p_hazard_code           IN VARCHAR2 DEFAULT NULL,
                                   p_shipped_date          IN DATE DEFAULT NULL,
                                   p_shipment_num          IN VARCHAR2 DEFAULT NULL,
                                   p_carrier_method        IN VARCHAR2 DEFAULT NULL,
                                   p_packaging_code        IN VARCHAR2 DEFAULT NULL,
                                   p_freight_carrier_code  IN VARCHAR2 DEFAULT NULL,
                                   p_freight_terms         IN VARCHAR2 DEFAULT NULL,
                                   p_currency_code         IN VARCHAR2 DEFAULT NULL,
                                   p_rate                  IN NUMBER DEFAULT NULL,
                                   p_rate_type             IN VARCHAR2 DEFAULT NULL,
                                   p_source_org_id         IN NUMBER DEFAULT NULL,
                                   p_expected_receipt_date IN DATE DEFAULT NULL
                                   -- <FSC R12 END>
                                   );

  PROCEDURE populate_line_record(p_order_line_id       IN NUMBER,
                                 p_item_revision       IN VARCHAR2 -- Bug 3330884
                                ,
                                 p_item_id             IN NUMBER,
                                 p_category_id         IN NUMBER,
                                 p_supplier_item_num   IN VARCHAR2,
                                 p_agreement_type      IN VARCHAR2,
                                 p_agreement_id        IN NUMBER,
                                 p_agreement_line_id   IN NUMBER DEFAULT NULL --<R12 GBPA Adv Pricing>
                                ,
                                 p_supplier_id         IN NUMBER,
                                 p_supplier_site_id    IN NUMBER,
                                 p_ship_to_location_id IN NUMBER,
                                 p_ship_to_org_id      IN NUMBER,
                                 p_rate                IN NUMBER,
                                 p_rate_type           IN VARCHAR2,
                                 p_currency_code       IN VARCHAR2,
                                 p_need_by_date        IN DATE
                                 -- <FSC R12 START>
                                 -- New Attributes for R12: Receving FSC support
                                ,
                                 p_shipment_line_id        IN NUMBER DEFAULT NULL,
                                 p_primary_unit_of_measure IN VARCHAR2 DEFAULT NULL,
                                 p_to_organization_id      IN NUMBER DEFAULT NULL,
                                 p_unit_of_measure         IN VARCHAR2 DEFAULT NULL,
                                 p_source_document_code    IN VARCHAR2 DEFAULT NULL,
                                 p_unit_price              IN NUMBER DEFAULT NULL -- will not be mapped to any QP attribute
                                ,
                                 p_quantity                IN NUMBER DEFAULT NULL -- will not be mapped to any QP attribute
                                 -- <FSC R12 END>
                                 );
  --------------------------------------------------------------------------------
  -- Procedure definitions
  --------------------------------------------------------------------------------

  --------------------------------------------------------------------------------
  --Start of Comments
  --Name: populate_header_record
  --Pre-reqs:
  --  None.
  --Modifies:
  --  None.
  --Locks:
  --  None.
  --Function:
  --  This procedure populates global variable G_HDR.
  --Parameters:
  --IN:
  --p_org_id
  --  Org ID.
  --p_order_id
  --  Order ID: REQUISITION Header ID or PO Header ID.
  --p_supplier_id
  --  Supplier ID.
  --p_supplier_site_id
  --  Supplier Site ID.
  --p_creation_date
  --  Creation date.
  --p_order_type
  --  Order type: REQUISITION or PO.
  --p_ship_to_location_id
  --  Ship to Location ID.
  --p_ship_to_org_id
  --  Ship to Org ID.
  --p_shipment_header_id
  -- shipment header id
  --p_hazard_class
  --  hazard class
  --p_hazard_code
  --  hazard code
  --p_shipped_date
  --  shipped date for goods
  --p_shipment_num
  --  shipment number
  --p_carrier_method
  --  carrier method
  --p_packaging_code
  --  packaging code
  --p_freight_carrier_code
  --  greight carrier code
  --p_freight_terms
  --  freight terms
  --p_currency_code
  --  currency code
  --p_rate
  --  currency conversion rate
  --p_rate_type
  --  rate type
  --p_expected_receipt_date
  --  expected receipt date
  --Testing:
  --
  --End of Comments
  -------------------------------------------------------------------------------
  PROCEDURE populate_header_record(p_org_id              IN NUMBER,
                                   p_order_header_id     IN NUMBER,
                                   p_supplier_id         IN NUMBER,
                                   p_supplier_site_id    IN NUMBER,
                                   p_creation_date       IN DATE,
                                   p_order_type          IN VARCHAR2,
                                   p_ship_to_location_id IN NUMBER,
                                   p_ship_to_org_id      IN NUMBER
                                   -- <FSC R12 START>
                                   -- New Attributes for R12: Receving FSC support
                                  ,
                                   p_shipment_header_id    IN NUMBER DEFAULT NULL,
                                   p_hazard_class          IN VARCHAR2 DEFAULT NULL,
                                   p_hazard_code           IN VARCHAR2 DEFAULT NULL,
                                   p_shipped_date          IN DATE DEFAULT NULL,
                                   p_shipment_num          IN VARCHAR2 DEFAULT NULL,
                                   p_carrier_method        IN VARCHAR2 DEFAULT NULL,
                                   p_packaging_code        IN VARCHAR2 DEFAULT NULL,
                                   p_freight_carrier_code  IN VARCHAR2 DEFAULT NULL,
                                   p_freight_terms         IN VARCHAR2 DEFAULT NULL,
                                   p_currency_code         IN VARCHAR2 DEFAULT NULL,
                                   p_rate                  IN NUMBER DEFAULT NULL,
                                   p_rate_type             IN VARCHAR2 DEFAULT NULL,
                                   p_source_org_id         IN NUMBER DEFAULT NULL,
                                   p_expected_receipt_date IN DATE DEFAULT NULL
                                   -- <FSC R12 END>
                                   ) IS
  BEGIN
    g_hdr.org_id              := p_org_id;
    g_hdr.p_order_header_id   := p_order_header_id;
    g_hdr.supplier_id         := p_supplier_id;
    g_hdr.supplier_site_id    := p_supplier_site_id;
    g_hdr.creation_date       := p_creation_date;
    g_hdr.order_type          := p_order_type;
    g_hdr.ship_to_location_id := p_ship_to_location_id;
    g_hdr.ship_to_org_id      := p_ship_to_org_id;
    -- <FSC R12 START>
    g_hdr.shipment_header_id    := p_shipment_header_id;
    g_hdr.hazard_class          := p_hazard_class;
    g_hdr.hazard_code           := p_hazard_code;
    g_hdr.shipped_date          := p_shipped_date;
    g_hdr.shipment_num          := p_shipment_num;
    g_hdr.carrier_method        := p_carrier_method;
    g_hdr.packaging_code        := p_packaging_code;
    g_hdr.freight_carrier_code  := p_freight_carrier_code;
    g_hdr.freight_terms         := p_freight_terms;
    g_hdr.currency_code         := p_currency_code;
    g_hdr.rate                  := p_rate;
    g_hdr.rate_type             := p_rate_type;
    g_hdr.source_org_id         := p_source_org_id;
    g_hdr.expected_receipt_date := p_expected_receipt_date;
    -- <FSC R12 END>
  END populate_header_record;

  --------------------------------------------------------------------------------
  --Start of Comments
  --Name: populate_line_record
  --Pre-reqs:
  --  None.
  --Modifies:
  --  None.
  --Locks:
  --  None.
  --Function:
  --  This procedure populates global variable G_LINE.
  --Parameters:
  --IN:
  --p_order_line_id
  --  Order Line ID: REQUISITION Line ID or PO Line ID.
  --p_item_revision
  --  Item Revision.
  --p_item_id
  --  Inventory Item ID.
  --p_category_id
  --  Category ID.
  --p_agreement_type
  --  The type of the source agreement. In 11.5.10, should only be CONTRACT.
  --p_agreement_id
  --  The header ID of the source agreement.
  --p_supplier_id
  --  Supplier ID.
  --p_supplier_site_id
  --  Supplier Site ID.
  --p_ship_to_location_id
  --  Ship to Location ID.
  --p_ship_to_org_id
  --  Ship to Org ID.
  --p_rate
  --  Conversion rate.
  --p_rate_type
  --  Conversion rate type.
  --p_currency_code
  --  Currency code.
  --p_need_by_date
  --  Need by date.
  --p_shipment_line_id
  --  Shipment line id
  --p_primary_unit_of_measure
  --  primary unit of measure
  --p_to_organization_id
  --  destination org id
  --p_unit_of_measure
  --  unit of measure
  --p_source_document_code
  --  source doc code
  --p_unit_price
  --  unit price
  --p_quantity
  --  quantity
  --Testing:
  --
  --End of Comments
  -------------------------------------------------------------------------------
  PROCEDURE populate_line_record(p_order_line_id       IN NUMBER,
                                 p_item_revision       IN VARCHAR2 -- Bug 3330884
                                ,
                                 p_item_id             IN NUMBER,
                                 p_category_id         IN NUMBER,
                                 p_supplier_item_num   IN VARCHAR2,
                                 p_agreement_type      IN VARCHAR2,
                                 p_agreement_id        IN NUMBER,
                                 p_agreement_line_id   IN NUMBER DEFAULT NULL --<R12 GBPA Adv Pricing>
                                ,
                                 p_supplier_id         IN NUMBER,
                                 p_supplier_site_id    IN NUMBER,
                                 p_ship_to_location_id IN NUMBER,
                                 p_ship_to_org_id      IN NUMBER,
                                 p_rate                IN NUMBER,
                                 p_rate_type           IN VARCHAR2,
                                 p_currency_code       IN VARCHAR2,
                                 p_need_by_date        IN DATE
                                 --<FSC Start R12>
                                ,
                                 p_shipment_line_id        IN NUMBER DEFAULT NULL,
                                 p_primary_unit_of_measure IN VARCHAR2 DEFAULT NULL,
                                 p_to_organization_id      IN NUMBER DEFAULT NULL,
                                 p_unit_of_measure         IN VARCHAR2 DEFAULT NULL,
                                 p_source_document_code    IN VARCHAR2 DEFAULT NULL,
                                 p_unit_price              IN NUMBER DEFAULT NULL -- will not be mapped to any QP attribute
                                ,
                                 p_quantity                IN NUMBER DEFAULT NULL -- will not be mapped to any QP attribute
                                 --<FSC End R12>
                                 ) IS
  BEGIN
    g_line.order_line_id       := p_order_line_id;
    g_line.item_revision       := p_item_revision;
    g_line.item_id             := p_item_id;
    g_line.category_id         := p_category_id;
    g_line.supplier_item_num   := p_supplier_item_num;
    g_line.agreement_type      := p_agreement_type;
    g_line.agreement_id        := p_agreement_id;
    g_line.agreement_line_id   := p_agreement_line_id; --<R12 GBPA Adv Pricing>
    g_line.supplier_id         := p_supplier_id;
    g_line.supplier_site_id    := p_supplier_site_id;
    g_line.ship_to_location_id := p_ship_to_location_id;
    g_line.ship_to_org_id      := p_ship_to_org_id;
    g_line.rate                := p_rate;
    g_line.rate_type           := p_rate_type;
    g_line.currency_code       := p_currency_code;
    g_line.need_by_date        := p_need_by_date;
    -- <FSC R12 START>
    g_line.shipment_line_id        := p_shipment_line_id;
    g_line.primary_unit_of_measure := p_primary_unit_of_measure;
    g_line.to_organization_id      := p_to_organization_id;
    g_line.unit_of_measure         := p_unit_of_measure;
    g_line.source_document_code    := p_source_document_code;
    g_line.unit_price              := p_unit_price;
    g_line.quantity                := p_quantity;
    -- <FSC R12 END>
  
  END populate_line_record;

  --------------------------------------------------------------------------------
  --Start of Comments
  --Name: get_advanced_price
  --Pre-reqs:
  --  None.
  --Modifies:
  --  None.
  --Locks:
  --  None.
  --Function:
  --  This procedure calls Advanced prcing API to get list price and adjustment.
  --Parameters:
  --IN:
  --p_org_id
  --  Org ID.
  --p_supplier_id
  --  Supplier ID.
  --p_supplier_site_id
  --  Supplier Site ID.
  --p_rate
  --  Conversion rate.
  --p_rate_type
  --  Conversion rate type.
  --p_currency_code
  --  Currency code.
  --p_creation_date
  --  Creation date.
  --p_order_type
  --  Order type: REQUISITION or PO.
  --p_ship_to_location_id
  --  Ship to Location ID.
  --p_ship_to_org_id
  --  Ship to Org ID.
  --p_order_id
  --  Order ID: REQUISITION Header ID or PO Header ID.
  --p_order_line_id
  --  Order Line ID: REQUISITION Line ID or PO Line ID.
  --p_item_revision
  --  Item Revision.
  --p_item_id
  --  Inventory Item ID.
  --p_category_id
  --  Category ID.
  --p_supplier_item_num
  --  Supplier Item Number
  --p_agreement_type
  --  The type of the source agreement. In 11.5.10, should only be CONTRACT.
  --p_agreement_id
  --  The header ID of the source agreement.
  --p_price_date
  --  Price date.
  --p_quantity
  --  Quantity.
  --p_uom
  --  Unit of Measure.
  --p_unit_price
  --  Unit Price.
  --OUT:
  --x_base_unit_price
  --  Base Unit Price.
  --x_unit_price
  --  Adjusted Unit Price.
  --x_return_status
  --  FND_API.G_RET_STS_SUCCESS if API succeeds
  --  FND_API.G_RET_STS_ERROR if API fails
  --  FND_API.G_RET_STS_UNEXP_ERROR if unexpected error occurs
  --Testing:
  --
  --End of Comments
  -------------------------------------------------------------------------------
  PROCEDURE get_advanced_price(p_org_id              IN NUMBER,
                               p_supplier_id         IN NUMBER,
                               p_supplier_site_id    IN NUMBER,
                               p_creation_date       IN DATE,
                               p_order_type          IN VARCHAR2,
                               p_ship_to_location_id IN NUMBER,
                               p_ship_to_org_id      IN NUMBER,
                               p_order_header_id     IN NUMBER,
                               p_order_line_id       IN NUMBER,
                               p_item_revision       IN VARCHAR2 -- Bug 3330884
                              ,
                               p_item_id             IN NUMBER,
                               p_category_id         IN NUMBER,
                               p_supplier_item_num   IN VARCHAR2,
                               p_agreement_type      IN VARCHAR2,
                               p_agreement_id        IN NUMBER,
                               p_agreement_line_id   IN NUMBER DEFAULT NULL --<R12 GBPA Adv Pricing>
                              ,
                               p_rate                IN NUMBER,
                               p_rate_type           IN VARCHAR2,
                               p_currency_code       IN VARCHAR2,
                               p_need_by_date        IN DATE,
                               p_quantity            IN NUMBER,
                               p_uom                 IN VARCHAR2,
                               p_unit_price          IN NUMBER,
                               x_base_unit_price     OUT NOCOPY NUMBER,
                               x_unit_price          OUT NOCOPY NUMBER,
                               x_return_status       OUT NOCOPY VARCHAR2) IS
    l_api_name CONSTANT VARCHAR2(30) := 'GET_ADVANCED_PRICE';
    l_log_head CONSTANT VARCHAR2(100) := g_log_head || l_api_name;
    l_progress      VARCHAR2(3) := '000';
    l_exception_msg fnd_new_messages.message_text%TYPE;
    l_qp_license    VARCHAR2(30) := NULL;
    l_uom_code      mtl_units_of_measure.uom_code%TYPE;
  
    l_line_id            NUMBER := nvl(p_order_line_id, 1);
    l_return_status_text VARCHAR2(2000);
    l_control_rec        qp_preq_grp.control_record_type;
    l_pass_line          VARCHAR2(1);
  
    l_line_index_tbl               qp_preq_grp.pls_integer_type;
    l_line_type_code_tbl           qp_preq_grp.varchar_type;
    l_pricinl_effective_date_tbl   qp_preq_grp.date_type;
    l_active_date_first_tbl        qp_preq_grp.date_type;
    l_active_date_first_type_tbl   qp_preq_grp.varchar_type;
    l_active_date_second_tbl       qp_preq_grp.date_type;
    l_active_date_second_type_tbl  qp_preq_grp.varchar_type;
    l_line_unit_price_tbl          qp_preq_grp.number_type;
    l_line_quantity_tbl            qp_preq_grp.number_type;
    l_line_uom_code_tbl            qp_preq_grp.varchar_type;
    l_request_type_code_tbl        qp_preq_grp.varchar_type;
    l_priced_quantity_tbl          qp_preq_grp.number_type;
    l_uom_quantity_tbl             qp_preq_grp.number_type;
    l_priced_uom_code_tbl          qp_preq_grp.varchar_type;
    l_currency_code_tbl            qp_preq_grp.varchar_type;
    l_unit_price_tbl               qp_preq_grp.number_type;
    l_percent_price_tbl            qp_preq_grp.number_type;
    l_adjusted_unit_price_tbl      qp_preq_grp.number_type;
    l_upd_adjusted_unit_price_tbl  qp_preq_grp.number_type;
    l_processed_flag_tbl           qp_preq_grp.varchar_type;
    l_price_flag_tbl               qp_preq_grp.varchar_type;
    l_line_id_tbl                  qp_preq_grp.number_type;
    l_processing_order_tbl         qp_preq_grp.pls_integer_type;
    l_rounding_factor_tbl          qp_preq_grp.pls_integer_type;
    l_rounding_flag_tbl            qp_preq_grp.flag_type;
    l_qualifiers_exist_flag_tbl    qp_preq_grp.varchar_type;
    l_pricing_attrs_exist_flag_tbl qp_preq_grp.varchar_type;
    l_price_list_id_tbl            qp_preq_grp.number_type;
    l_pl_validated_flag_tbl        qp_preq_grp.varchar_type;
    l_price_request_code_tbl       qp_preq_grp.varchar_type;
    l_usage_pricing_type_tbl       qp_preq_grp.varchar_type;
    l_line_category_tbl            qp_preq_grp.varchar_type;
    l_pricing_status_code_tbl      qp_preq_grp.varchar_type;
    l_pricing_status_text_tbl      qp_preq_grp.varchar_type;
    l_list_price_overide_flag_tbl  qp_preq_grp.varchar_type;
  
    l_price_status_code qp_preq_lines_tmp.pricing_status_code%TYPE;
    l_price_status_text qp_preq_lines_tmp.pricing_status_text%TYPE;
  
    -- <Bug 3794940 START>
    l_return_status VARCHAR2(1);
    l_msg_count     NUMBER;
    l_msg_data      VARCHAR2(2000);
    -- <Bug 3794940 END>
  
  BEGIN
  
    -- Initialize OUT parameters
    x_return_status   := fnd_api.g_ret_sts_success;
    x_base_unit_price := p_unit_price;
    x_unit_price      := p_unit_price;
  
    IF g_debug_stmt THEN
      po_debug.debug_begin(l_log_head);
      po_debug.debug_var(l_log_head, l_progress, 'p_org_id', p_org_id);
      po_debug.debug_var(l_log_head,
                         l_progress,
                         'p_supplier_id',
                         p_supplier_id);
      po_debug.debug_var(l_log_head,
                         l_progress,
                         'p_supplier_site_id',
                         p_supplier_site_id);
      po_debug.debug_var(l_log_head,
                         l_progress,
                         'p_creation_date',
                         p_creation_date);
      po_debug.debug_var(l_log_head,
                         l_progress,
                         'p_order_type',
                         p_order_type);
      po_debug.debug_var(l_log_head,
                         l_progress,
                         'p_ship_to_location_id',
                         p_ship_to_location_id);
      po_debug.debug_var(l_log_head,
                         l_progress,
                         'p_ship_to_org_id',
                         p_ship_to_org_id);
      po_debug.debug_var(l_log_head,
                         l_progress,
                         'p_order_header_id',
                         p_order_header_id);
      po_debug.debug_var(l_log_head,
                         l_progress,
                         'p_order_line_id',
                         p_order_line_id);
      po_debug.debug_var(l_log_head,
                         l_progress,
                         'p_item_revision',
                         p_item_revision);
      po_debug.debug_var(l_log_head, l_progress, 'p_item_id', p_item_id);
      po_debug.debug_var(l_log_head,
                         l_progress,
                         'p_category_id',
                         p_category_id);
      po_debug.debug_var(l_log_head,
                         l_progress,
                         'p_supplier_item_num',
                         p_supplier_item_num);
      po_debug.debug_var(l_log_head,
                         l_progress,
                         'p_agreement_type',
                         p_agreement_type);
      po_debug.debug_var(l_log_head,
                         l_progress,
                         'p_agreement_id',
                         p_agreement_id);
      po_debug.debug_var(l_log_head,
                         l_progress,
                         'p_agreement_line_id',
                         p_agreement_line_id);
      po_debug.debug_var(l_log_head, l_progress, 'p_rate', p_rate);
      po_debug.debug_var(l_log_head,
                         l_progress,
                         'p_rate_type',
                         p_rate_type);
      po_debug.debug_var(l_log_head,
                         l_progress,
                         'p_currency_code',
                         p_currency_code);
      po_debug.debug_var(l_log_head,
                         l_progress,
                         'p_need_by_date',
                         p_need_by_date);
      po_debug.debug_var(l_log_head, l_progress, 'p_quantity', p_quantity);
      po_debug.debug_var(l_log_head, l_progress, 'p_uom', p_uom);
      po_debug.debug_var(l_log_head,
                         l_progress,
                         'p_unit_price',
                         p_unit_price);
      po_debug.debug_stmt(l_log_head,
                          l_progress,
                          'Check Advanced Pricing License');
    END IF;
  
    fnd_profile.get('QP_LICENSED_FOR_PRODUCT', l_qp_license);
    l_progress := '020';
    IF g_debug_stmt THEN
      po_debug.debug_var(l_log_head,
                         l_progress,
                         'l_qp_license',
                         l_qp_license);
    END IF;
  
    --Bug 5555953: Remove the logic to nullify the output unitprice if the Adv Pricing API
    --is not installed or licensed to PO;
    IF (l_qp_license IS NULL OR l_qp_license <> 'PO') THEN
      RETURN;
    END IF;
  
    l_progress := '040';
    IF g_debug_stmt THEN
      po_debug.debug_stmt(l_log_head, l_progress, 'Set Price Request ID');
    END IF;
  
    qp_price_request_context.set_request_id;
  
    l_progress := '060';
    IF g_debug_stmt THEN
      po_debug.debug_stmt(l_log_head,
                          l_progress,
                          'Populate Global Header Structure');
    END IF;
  
    populate_header_record(p_org_id              => p_org_id,
                           p_order_header_id     => p_order_header_id,
                           p_supplier_id         => p_supplier_id,
                           p_supplier_site_id    => p_supplier_site_id,
                           p_creation_date       => p_creation_date,
                           p_order_type          => p_order_type,
                           p_ship_to_location_id => p_ship_to_location_id,
                           p_ship_to_org_id      => p_ship_to_org_id);
  
    l_progress := '080';
    IF g_debug_stmt THEN
      po_debug.debug_stmt(l_log_head,
                          l_progress,
                          'Populate Global Line Structure');
    END IF;
  
    populate_line_record(p_order_line_id       => p_order_line_id,
                         p_item_revision       => p_item_revision,
                         p_item_id             => p_item_id,
                         p_category_id         => p_category_id,
                         p_supplier_item_num   => p_supplier_item_num,
                         p_agreement_type      => p_agreement_type,
                         p_agreement_id        => p_agreement_id,
                         p_agreement_line_id   => p_agreement_line_id, --<R12 GBPA Adv Pricing>
                         p_supplier_id         => p_supplier_id,
                         p_supplier_site_id    => p_supplier_site_id,
                         p_ship_to_location_id => p_ship_to_location_id,
                         p_ship_to_org_id      => p_ship_to_org_id,
                         p_rate                => p_rate,
                         p_rate_type           => p_rate_type,
                         p_currency_code       => p_currency_code,
                         p_need_by_date        => p_need_by_date);
  
    l_progress := '090';
    IF g_debug_stmt THEN
      po_debug.debug_stmt(l_log_head, l_progress, 'Set OE Debug');
      oe_debug_pub.setdebuglevel(10);
      po_debug.debug_stmt(l_log_head,
                          l_progress,
                          'Debug File Location:' ||
                          oe_debug_pub.set_debug_mode('FILE'));
      oe_debug_pub.initialize;
      oe_debug_pub.debug_on;
    END IF;
  
    l_progress := '100';
    IF g_debug_stmt THEN
      po_debug.debug_stmt(l_log_head,
                          l_progress,
                          'Build Attributes Mapping Contexts');
    END IF;
  
    qp_attr_mapping_pub.build_contexts(p_request_type_code => 'PO',
                                       p_line_index        => 1,
                                       p_pricing_type_code => 'L',
                                       p_check_line_flag   => 'N',
                                       p_pricing_event     => 'PO_BATCH',
                                       x_pass_line         => l_pass_line);
  
    l_progress := '110';
    IF g_debug_stmt THEN
      po_debug.debug_stmt(l_log_head, l_progress, 'Get UOM Code');
    END IF;
  
    BEGIN
      -- Make sure we pass uom_code instead of unit_of_measure.
      SELECT mum.uom_code
        INTO l_uom_code
        FROM mtl_units_of_measure mum
       WHERE mum.unit_of_measure = p_uom;
    EXCEPTION
      WHEN OTHERS THEN
        l_uom_code := p_uom;
    END;
  
    l_progress := '120';
    IF g_debug_stmt THEN
      po_debug.debug_var(l_log_head, l_progress, 'l_uom_code', l_uom_code);
      po_debug.debug_stmt(l_log_head,
                          l_progress,
                          'Directly Insert into Temp table');
    END IF;
  
    l_request_type_code_tbl(1) := 'PO';
    l_line_id_tbl(1) := l_line_id; -- order line id
    l_line_index_tbl(1) := 1; -- Request Line Index
    l_line_type_code_tbl(1) := 'LINE'; -- LINE or ORDER(Summary Line)
    l_pricinl_effective_date_tbl(1) := p_need_by_date; -- Pricing as of effective date
    l_active_date_first_tbl(1) := NULL; -- Can be Ordered Date or Ship Date
    l_active_date_second_tbl(1) := NULL; -- Can be Ordered Date or Ship Date
    l_active_date_first_type_tbl(1) := NULL; -- ORD/SHIP
    l_active_date_second_type_tbl(1) := NULL; -- ORD/SHIP
    l_line_unit_price_tbl(1) := p_unit_price; -- Unit Price
    -- Bug 3315550, should pass 1 instead of NULL
    l_line_quantity_tbl(1) := nvl(p_quantity, 1); -- Ordered Quantity
    -- Bug 3564136, don't pass 0, pass 1 instead
    IF (l_line_quantity_tbl(1) = 0) THEN
      l_line_quantity_tbl(1) := 1;
    END IF; /*IF (l_line_quantity_tbl(1) = 0)*/
  
    l_line_uom_code_tbl(1) := l_uom_code; -- Ordered UOM Code
    l_currency_code_tbl(1) := p_currency_code; -- Currency Code
    l_price_flag_tbl(1) := 'Y'; -- Price Flag can have 'Y',
    -- 'N'(No pricing),
    -- 'P'(Phase)
    l_usage_pricing_type_tbl(1) := qp_preq_grp.g_regular_usage_type;
    -- Bug 3564136, don't pass 0, pass 1 instead
    -- Bug 3315550, should pass 1 instead of NULL
    l_priced_quantity_tbl(1) := nvl(p_quantity, 1);
    -- Bug 3564136, don't pass 0, pass 1 instead
    IF (l_priced_quantity_tbl(1) = 0) THEN
      l_priced_quantity_tbl(1) := 1;
    END IF; /*IF (l_line_quantity_tbl(1) = 0)*/
    l_priced_uom_code_tbl(1) := l_uom_code;
    l_unit_price_tbl(1) := p_unit_price;
    l_percent_price_tbl(1) := NULL;
    l_uom_quantity_tbl(1) := NULL;
    l_adjusted_unit_price_tbl(1) := NULL;
    l_upd_adjusted_unit_price_tbl(1) := NULL;
    l_processed_flag_tbl(1) := NULL;
    l_processing_order_tbl(1) := NULL;
    l_pricing_status_code_tbl(1) := qp_preq_grp.g_status_unchanged;
    l_pricing_status_text_tbl(1) := NULL;
    l_rounding_flag_tbl(1) := NULL;
    l_rounding_factor_tbl(1) := NULL;
    l_qualifiers_exist_flag_tbl(1) := 'N';
    l_pricing_attrs_exist_flag_tbl(1) := 'N';
    l_price_list_id_tbl(1) := -9999;
    l_pl_validated_flag_tbl(1) := 'N';
    l_price_request_code_tbl(1) := NULL;
    l_line_category_tbl(1) := NULL;
    l_list_price_overide_flag_tbl(1) := 'O'; -- Override price
  
    l_progress := '140';
    IF g_debug_stmt THEN
      po_debug.debug_stmt(l_log_head, l_progress, 'Call INSERT_LINES2');
    END IF;
  
    qp_preq_grp.insert_lines2(p_line_index               => l_line_index_tbl,
                              p_line_type_code           => l_line_type_code_tbl,
                              p_pricing_effective_date   => l_pricinl_effective_date_tbl,
                              p_active_date_first        => l_active_date_first_tbl,
                              p_active_date_first_type   => l_active_date_first_type_tbl,
                              p_active_date_second       => l_active_date_second_tbl,
                              p_active_date_second_type  => l_active_date_second_type_tbl,
                              p_line_quantity            => l_line_quantity_tbl,
                              p_line_uom_code            => l_line_uom_code_tbl,
                              p_request_type_code        => l_request_type_code_tbl,
                              p_priced_quantity          => l_priced_quantity_tbl,
                              p_priced_uom_code          => l_priced_uom_code_tbl,
                              p_currency_code            => l_currency_code_tbl,
                              p_unit_price               => l_unit_price_tbl,
                              p_percent_price            => l_percent_price_tbl,
                              p_uom_quantity             => l_uom_quantity_tbl,
                              p_adjusted_unit_price      => l_adjusted_unit_price_tbl,
                              p_upd_adjusted_unit_price  => l_upd_adjusted_unit_price_tbl,
                              p_processed_flag           => l_processed_flag_tbl,
                              p_price_flag               => l_price_flag_tbl,
                              p_line_id                  => l_line_id_tbl,
                              p_processing_order         => l_processing_order_tbl,
                              p_pricing_status_code      => l_pricing_status_code_tbl,
                              p_pricing_status_text      => l_pricing_status_text_tbl,
                              p_rounding_flag            => l_rounding_flag_tbl,
                              p_rounding_factor          => l_rounding_factor_tbl,
                              p_qualifiers_exist_flag    => l_qualifiers_exist_flag_tbl,
                              p_pricing_attrs_exist_flag => l_pricing_attrs_exist_flag_tbl,
                              p_price_list_id            => l_price_list_id_tbl,
                              p_validated_flag           => l_pl_validated_flag_tbl,
                              p_price_request_code       => l_price_request_code_tbl,
                              p_usage_pricing_type       => l_usage_pricing_type_tbl,
                              p_line_category            => l_line_category_tbl,
                              p_line_unit_price          => l_line_unit_price_tbl,
                              p_list_price_override_flag => l_list_price_overide_flag_tbl,
                              x_status_code              => x_return_status,
                              x_status_text              => l_return_status_text);
  
    l_progress := '160';
    IF g_debug_stmt THEN
      po_debug.debug_stmt(l_log_head,
                          l_progress,
                          'After Calling INSERT_LINES2');
      po_debug.debug_var(l_log_head,
                         l_progress,
                         'x_return_status',
                         x_return_status);
      po_debug.debug_var(l_log_head,
                         l_progress,
                         'l_return_status_text',
                         l_return_status_text);
    END IF;
  
    IF x_return_status = fnd_api.g_ret_sts_unexp_error THEN
      fnd_message.set_name('PO', 'PO_QP_PRICE_API_ERROR');
      fnd_message.set_token('ERROR_TEXT', l_return_status_text);
      fnd_msg_pub.add;
      RAISE fnd_api.g_exc_unexpected_error;
    ELSIF x_return_status = fnd_api.g_ret_sts_error THEN
      fnd_message.set_name('PO', 'PO_QP_PRICE_API_ERROR');
      fnd_message.set_token('ERROR_TEXT', l_return_status_text);
      fnd_msg_pub.add;
      RAISE fnd_api.g_exc_error;
    END IF;
  
    -- Don't call QP_PREQ_GRP.INSERT_LINE_ATTRS2 since PO has no
    -- ASK_FOR attributes
  
    l_progress := '180';
    IF g_debug_stmt THEN
      po_debug.debug_stmt(l_log_head,
                          l_progress,
                          'Populate Control Record for Pricing Request Call');
    END IF;
  
    l_control_rec.calculate_flag         := 'Y';
    l_control_rec.simulation_flag        := 'N';
    l_control_rec.pricing_event          := 'PO_BATCH';
    l_control_rec.temp_table_insert_flag := 'N';
    l_control_rec.check_cust_view_flag   := 'N';
    l_control_rec.request_type_code      := 'PO';
    --now pricing take care of all the roundings.
    l_control_rec.rounding_flag := 'Q';
    --For multi_currency price list
    l_control_rec.use_multi_currency   := 'Y';
    l_control_rec.user_conversion_rate := po_advanced_price_pvt.g_line.rate;
    l_control_rec.user_conversion_type := po_advanced_price_pvt.g_line.rate_type;
    l_control_rec.function_currency    := po_advanced_price_pvt.g_line.currency_code;
    l_control_rec.get_freight_flag     := 'N';
  
    l_progress := '200';
    IF g_debug_stmt THEN
      po_debug.debug_stmt(l_log_head, l_progress, 'Call PRICE_REQUEST');
    END IF;
  
    qp_preq_pub.price_request(p_control_rec        => l_control_rec,
                              x_return_status      => x_return_status,
                              x_return_status_text => l_return_status_text);
  
    l_progress := '220';
    IF g_debug_stmt THEN
      po_debug.debug_var(l_log_head,
                         l_progress,
                         'x_return_status',
                         x_return_status);
      po_debug.debug_var(l_log_head,
                         l_progress,
                         'l_return_status_text',
                         l_return_status_text);
    END IF;
  
    IF x_return_status = fnd_api.g_ret_sts_unexp_error THEN
      fnd_message.set_name('PO', 'PO_QP_PRICE_API_ERROR');
      fnd_message.set_token('ERROR_TEXT', l_return_status_text);
      fnd_msg_pub.add;
      RAISE fnd_api.g_exc_unexpected_error;
    ELSIF x_return_status = fnd_api.g_ret_sts_error THEN
      fnd_message.set_name('PO', 'PO_QP_PRICE_API_ERROR');
      fnd_message.set_token('ERROR_TEXT', l_return_status_text);
      fnd_msg_pub.add;
      RAISE fnd_api.g_exc_error;
    END IF;
  
    -- <Bug 3794940 START>
    po_custom_price_pub.audit_qp_price_adjustment(p_api_version   => 1.0,
                                                  p_order_type    => p_order_type,
                                                  p_order_line_id => l_line_id,
                                                  p_line_index    => 1,
                                                  x_return_status => l_return_status,
                                                  x_msg_count     => l_msg_count,
                                                  x_msg_data      => l_msg_data);
  
    l_progress := '230';
    IF l_return_status <> fnd_api.g_ret_sts_success THEN
      po_debug.debug_var(l_log_head,
                         l_progress,
                         'l_return_status',
                         l_return_status);
      po_debug.debug_unexp(l_log_head,
                           l_progress,
                           'audit_qp_price_adjustment errors out');
      fnd_message.set_name('PO', 'PO_QP_PRICE_API_ERROR');
      fnd_message.set_token('ERROR_TEXT', l_msg_data);
      fnd_msg_pub.add;
      RAISE fnd_api.g_exc_unexpected_error;
    END IF;
    -- <Bug 3794940 END>
  
    l_progress := '240';
    IF g_debug_stmt THEN
      po_debug.debug_stmt(l_log_head, l_progress, 'Fetch QP pricing');
      po_debug.debug_var(l_log_head, l_progress, 'l_line_id', l_line_id);
      po_debug.debug_table(l_log_head,
                           l_progress,
                           'QP_PREQ_LINES_TMP_T',
                           po_debug.g_all_rows,
                           NULL,
                           'QP');
    END IF;
  
    /* Use API insted
    -- SQL What: Fetch Price from Pricing Temp table
    -- SQL Why:  Return Advanced Pricing
    SELECT line_unit_price,
           adjusted_unit_price,
           pricing_status_code,
           pricing_status_text
    INTO   x_base_unit_price,
           x_unit_price,
           l_price_status_code,
           l_price_status_text
    FROM   QP_PREQ_LINES_TMP
    WHERE  line_id = l_line_id
    AND    (processed_code IS NULL OR processed_code <> 'INVALID');
    */
  
    qp_preq_pub.get_price_for_line(p_line_index          => 1,
                                   p_line_id             => l_line_id,
                                   x_line_unit_price     => x_base_unit_price,
                                   x_adjusted_unit_price => x_unit_price,
                                   x_return_status       => x_return_status,
                                   x_pricing_status_code => l_price_status_code,
                                   x_pricing_status_text => l_price_status_text);
  
    l_progress := '260';
    IF g_debug_stmt THEN
      po_debug.debug_var(l_log_head,
                         l_progress,
                         'x_return_status',
                         x_return_status);
      po_debug.debug_var(l_log_head,
                         l_progress,
                         'x_base_unit_price',
                         x_base_unit_price);
      po_debug.debug_var(l_log_head,
                         l_progress,
                         'x_unit_price',
                         x_unit_price);
      po_debug.debug_var(l_log_head,
                         l_progress,
                         'l_price_status_code',
                         l_price_status_code);
      po_debug.debug_var(l_log_head,
                         l_progress,
                         'l_price_status_text',
                         l_price_status_text);
    END IF;
  
    x_unit_price := nvl(x_unit_price, x_base_unit_price);
  
    IF x_return_status <> fnd_api.g_ret_sts_success THEN
      fnd_message.set_name('PO', 'PO_QP_PRICE_API_ERROR');
      fnd_message.set_token('ERROR_TEXT', l_price_status_text);
      x_return_status := fnd_api.g_ret_sts_error;
    END IF;
  
    l_progress := '300';
    IF g_debug_stmt THEN
      po_debug.debug_end(l_log_head);
      po_debug.debug_var(l_log_head,
                         l_progress,
                         'x_return_status',
                         x_return_status);
      po_debug.debug_var(l_log_head,
                         l_progress,
                         'x_base_unit_price',
                         x_base_unit_price);
      po_debug.debug_var(l_log_head,
                         l_progress,
                         'x_unit_price',
                         x_unit_price);
    END IF;
  
  EXCEPTION
    WHEN fnd_api.g_exc_error THEN
      --raised expected error: assume raiser already pushed onto the stack
      l_exception_msg := fnd_msg_pub.get(p_msg_index => fnd_msg_pub.g_last,
                                         p_encoded   => 'F');
      IF g_debug_unexp THEN
        po_debug.debug_var(l_log_head,
                           l_progress,
                           'l_exception_msg',
                           l_exception_msg);
      END IF;
      x_return_status := fnd_api.g_ret_sts_error;
      -- Push the po_return_msg onto msg list and message stack
      fnd_message.set_name('PO', 'PO_QP_PRICE_API_ERROR');
      fnd_message.set_token('ERROR_TEXT', l_exception_msg);
    
    WHEN fnd_api.g_exc_unexpected_error THEN
      --raised unexpected error: assume raiser already pushed onto the stack
      l_exception_msg := fnd_msg_pub.get(p_msg_index => fnd_msg_pub.g_last,
                                         p_encoded   => 'F');
      IF g_debug_unexp THEN
        po_debug.debug_var(l_log_head,
                           l_progress,
                           'l_exception_msg',
                           l_exception_msg);
      END IF;
      x_return_status := fnd_api.g_ret_sts_unexp_error;
      -- Push the po_return_msg onto msg list and message stack
      fnd_message.set_name('PO', 'PO_QP_PRICE_API_ERROR');
      fnd_message.set_token('ERROR_TEXT', l_exception_msg);
    
    WHEN OTHERS THEN
      IF g_debug_unexp THEN
        po_debug.debug_exc(l_log_head, l_progress);
      END IF;
      --unexpected error from this procedure: get SQLERRM
      po_message_s.sql_error(g_pkg_name,
                             l_api_name,
                             l_progress,
                             SQLCODE,
                             SQLERRM);
      l_exception_msg := fnd_message.get;
      IF g_debug_unexp THEN
        po_debug.debug_var(l_log_head,
                           l_progress,
                           'l_exception_msg',
                           l_exception_msg);
      END IF;
      x_return_status := fnd_api.g_ret_sts_unexp_error;
      -- Push the po_return_msg onto msg list and message stack
      fnd_message.set_name('PO', 'PO_QP_PRICE_API_ERROR');
      fnd_message.set_token('ERROR_TEXT', l_exception_msg);
  END get_advanced_price;

  --------------------------------------------------------------------------------
  --Start of Comments
  --Name: is_valid_qp_line_type
  --Pre-reqs:
  --  None.
  --Modifies:
  --  None.
  --Locks:
  --  None.
  --Function:
  --  This procedure checks valid line type for advanced pricing call.
  --  Any Line type with combination of Value Basis (Amount/Rate/Fixed Price)
  --  and Purchase Basis (Temp Labor/Services) is invalid.
  --Parameters:
  --IN:
  --p_line_type_id
  --  Line Type ID.
  --RETURN:
  --  FALSE: Invalid Line type to call Advanced Pricing API
  --  TRUE: Valid Line type to call Advanced Pricing API
  --Testing:
  --
  --End of Comments
  -------------------------------------------------------------------------------
  FUNCTION is_valid_qp_line_type(p_line_type_id IN NUMBER) RETURN BOOLEAN IS
    l_api_name CONSTANT VARCHAR2(30) := 'IS_VALID_QP_LINE_TYPE';
    l_log_head CONSTANT VARCHAR2(100) := g_log_head || l_api_name;
    l_progress       VARCHAR2(3) := '000';
    l_purchase_basis po_line_types.purchase_basis%TYPE;
    -- Bug 3343261: should use value_basis instead of matching_basis
    -- l_matching_basis PO_LINE_TYPES.matching_basis%TYPE;
    l_value_basis po_line_types.order_type_lookup_code%TYPE;
  BEGIN
    IF g_debug_stmt THEN
      po_debug.debug_begin(l_log_head);
      po_debug.debug_var(l_log_head,
                         l_progress,
                         'p_line_type_id',
                         p_line_type_id);
    END IF;
  
    IF (p_line_type_id IS NULL) THEN
      RETURN TRUE;
    END IF;
  
    l_progress := '010';
    SELECT purchase_basis,
           -- Bug 3343261: should use value_basis instead of matching_basis
           -- matching_basis,
           order_type_lookup_code
      INTO l_purchase_basis,
           -- Bug 3343261: should use value_basis instead of matching_basis
           -- l_matching_basis,
           l_value_basis
      FROM po_line_types
     WHERE line_type_id = p_line_type_id;
  
    l_progress := '020';
    IF g_debug_stmt THEN
      po_debug.debug_stmt(l_log_head, l_progress, 'Retrieved line type');
    END IF;
  
    IF (l_purchase_basis IN ('TEMP LABOR', 'SERVICES') AND
       -- Bug 3343261: should use value_basis instead of matching_basis
       l_value_basis IN ('AMOUNT', 'RATE', 'FIXED PRICE')) THEN
      RETURN FALSE;
    END IF;
  
    l_progress := '030';
    IF g_debug_stmt THEN
      po_debug.debug_end(l_log_head);
    END IF;
  
    RETURN TRUE;
  EXCEPTION
    WHEN OTHERS THEN
      RETURN FALSE;
  END is_valid_qp_line_type;

  -- <FSC R12 START>
  --------------------------------------------------------------------------------
  --Start of Comments
  --Name: get_advanced_price
  --Pre-reqs:
  --  None.
  --Modifies:
  --  None.
  --Locks:
  --  None.
  --Procedure:
  --  This procedure calls out to QP for getting the adjusted price and
  --  freight and speacial charges. This takes in a document in the form of
  --  header record and a table of line records
  --Parameters:
  --IN:
  --  p_header_rec  Header_Rec_Type  This will keep the document header information
  --  p_line_rec_tbl Line_tbl_type   This willl keep the table of the lines for the
  --  p_request_type                 Request type to be passed to QP.
  --  p_pricing_event                pricing event set up in QP for the processing
  --  p_has_header_pricing           True, when header line is also included in pricing
  --  p_return_price_flag            True, when the caller wants the adjusted rice info
  --                                 also in the returned record
  --  p_return_freight_flag          True, when the caller wants the API to return
  --                                 freight charge related info.
  --
  --OUT:
  --  x_return_status                Return status for the QP call.
  --  x_price_tbl                    Table of resulted info from QP for each line
  --Testing:
  --
  --End of Comments
  -------------------------------------------------------------------------------
  PROCEDURE get_advanced_price(p_header_rec          header_rec_type,
                               p_line_rec_tbl        line_tbl_type,
                               p_request_type        IN VARCHAR2,
                               p_pricing_event       IN VARCHAR2,
                               p_has_header_pricing  IN BOOLEAN,
                               p_return_price_flag   IN BOOLEAN,
                               p_return_freight_flag IN BOOLEAN,
                               x_price_tbl           OUT NOCOPY qp_price_result_rec_tbl_type,
                               x_return_status       OUT NOCOPY VARCHAR2) IS
    l_api_name CONSTANT VARCHAR2(30) := 'GET_ADVANCED_PRICE';
    l_log_head CONSTANT VARCHAR2(100) := g_log_head || l_api_name;
    d_pos                          NUMBER;
    l_exception_msg                fnd_new_messages.message_text%TYPE;
    l_qp_license                   VARCHAR2(30) := NULL;
    l_uom_code                     mtl_units_of_measure.uom_code%TYPE;
    l_return_status_text           VARCHAR2(2000);
    l_control_rec                  qp_preq_grp.control_record_type;
    l_pass_line                    VARCHAR2(1);
    l_line_index_tbl               qp_preq_grp.pls_integer_type;
    l_line_type_code_tbl           qp_preq_grp.varchar_type;
    l_pricinl_effective_date_tbl   qp_preq_grp.date_type;
    l_active_date_first_tbl        qp_preq_grp.date_type;
    l_active_date_first_type_tbl   qp_preq_grp.varchar_type;
    l_active_date_second_tbl       qp_preq_grp.date_type;
    l_active_date_second_type_tbl  qp_preq_grp.varchar_type;
    l_line_unit_price_tbl          qp_preq_grp.number_type;
    l_line_quantity_tbl            qp_preq_grp.number_type;
    l_line_uom_code_tbl            qp_preq_grp.varchar_type;
    l_request_type_code_tbl        qp_preq_grp.varchar_type;
    l_priced_quantity_tbl          qp_preq_grp.number_type;
    l_uom_quantity_tbl             qp_preq_grp.number_type;
    l_priced_uom_code_tbl          qp_preq_grp.varchar_type;
    l_currency_code_tbl            qp_preq_grp.varchar_type;
    l_unit_price_tbl               qp_preq_grp.number_type;
    l_percent_price_tbl            qp_preq_grp.number_type;
    l_adjusted_unit_price_tbl      qp_preq_grp.number_type;
    l_upd_adjusted_unit_price_tbl  qp_preq_grp.number_type;
    l_processed_flag_tbl           qp_preq_grp.varchar_type;
    l_price_flag_tbl               qp_preq_grp.varchar_type;
    l_line_id_tbl                  qp_preq_grp.number_type;
    l_processing_order_tbl         qp_preq_grp.pls_integer_type;
    l_rounding_factor_tbl          qp_preq_grp.pls_integer_type;
    l_rounding_flag_tbl            qp_preq_grp.flag_type;
    l_qualifiers_exist_flag_tbl    qp_preq_grp.varchar_type;
    l_pricing_attrs_exist_flag_tbl qp_preq_grp.varchar_type;
    l_price_list_id_tbl            qp_preq_grp.number_type;
    l_pl_validated_flag_tbl        qp_preq_grp.varchar_type;
    l_price_request_code_tbl       qp_preq_grp.varchar_type;
    l_usage_pricing_type_tbl       qp_preq_grp.varchar_type;
    l_line_category_tbl            qp_preq_grp.varchar_type;
    l_pricing_status_code_tbl      qp_preq_grp.varchar_type;
    l_pricing_status_text_tbl      qp_preq_grp.varchar_type;
    l_list_price_overide_flag_tbl  qp_preq_grp.varchar_type;
    i                              PLS_INTEGER := 1;
    j                              PLS_INTEGER := 1;
    k                              PLS_INTEGER := 1;
    l_freight_charge_rec_tbl       freight_charges_rec_tbl_type;
  BEGIN
  
    -- Initialize OUT parameters
    x_return_status := fnd_api.g_ret_sts_success;
    IF g_debug_stmt THEN
      po_log.proc_begin(l_log_head);
      po_log.proc_begin(l_log_head,
                        'p_header_rec.org_id',
                        p_header_rec.org_id);
      po_log.proc_begin(l_log_head,
                        'p_header_rec.p_order_header_id',
                        p_header_rec.p_order_header_id);
      po_log.proc_begin(l_log_head,
                        'p_header_rec.supplier_id',
                        p_header_rec.supplier_id);
      po_log.proc_begin(l_log_head,
                        'p_header_rec.supplier_site_id',
                        p_header_rec.supplier_site_id);
      po_log.proc_begin(l_log_head,
                        'p_header_rec.creation_date',
                        p_header_rec.creation_date);
      po_log.proc_begin(l_log_head,
                        'p_header_rec.order_type',
                        p_header_rec.order_type);
      po_log.proc_begin(l_log_head,
                        'p_header_rec.ship_to_location_id',
                        p_header_rec.ship_to_location_id);
      po_log.proc_begin(l_log_head,
                        'p_header_rec.ship_to_org_id',
                        p_header_rec.ship_to_org_id);
      po_log.proc_begin(l_log_head,
                        'p_header_rec.shipment_header_id',
                        p_header_rec.shipment_header_id);
      po_log.proc_begin(l_log_head,
                        'p_header_rec.hazard_class',
                        p_header_rec.hazard_class);
      po_log.proc_begin(l_log_head,
                        'p_header_rec.hazard_code',
                        p_header_rec.hazard_code);
      po_log.proc_begin(l_log_head,
                        'p_header_rec.shipped_date',
                        p_header_rec.shipped_date);
      po_log.proc_begin(l_log_head,
                        'p_header_rec.shipment_num',
                        p_header_rec.shipment_num);
      po_log.proc_begin(l_log_head,
                        'p_header_rec.carrier_method',
                        p_header_rec.carrier_method);
      po_log.proc_begin(l_log_head,
                        'p_header_rec.packaging_code',
                        p_header_rec.packaging_code);
      po_log.proc_begin(l_log_head,
                        'p_header_rec.freight_carrier_code',
                        p_header_rec.freight_carrier_code);
      po_log.proc_begin(l_log_head,
                        'p_header_rec.freight_terms',
                        p_header_rec.freight_terms);
      po_log.proc_begin(l_log_head,
                        'p_header_rec.currency_code',
                        p_header_rec.currency_code);
      po_log.proc_begin(l_log_head, 'p_header_rec.rate', p_header_rec.rate);
      po_log.proc_begin(l_log_head,
                        'p_header_rec.rate_type',
                        p_header_rec.rate_type);
    
      FOR i IN 1 .. p_line_rec_tbl.COUNT LOOP
        po_log.proc_begin(l_log_head,
                          'p_line_rec_tbl(' || i || ').order_line_id',
                          p_line_rec_tbl(i).order_line_id);
        po_log.proc_begin(l_log_head,
                          'p_line_rec_tbl(' || i || ').agreement_type',
                          p_line_rec_tbl(i).agreement_type);
        po_log.proc_begin(l_log_head,
                          'p_line_rec_tbl(' || i || ').agreement_id',
                          p_line_rec_tbl(i).agreement_id);
        po_log.proc_begin(l_log_head,
                          'p_line_rec_tbl(' || i || ').agreement_line_id',
                          p_line_rec_tbl(i).agreement_line_id);
        po_log.proc_begin(l_log_head,
                          'p_line_rec_tbl(' || i || ').supplier_id',
                          p_line_rec_tbl(i).supplier_id);
        po_log.proc_begin(l_log_head,
                          'p_line_rec_tbl(' || i || ').supplier_site_id',
                          p_line_rec_tbl(i).supplier_site_id);
        po_log.proc_begin(l_log_head,
                          'p_line_rec_tbl(' || i || ').ship_to_location_id',
                          p_line_rec_tbl(i) . ship_to_location_id);
        po_log.proc_begin(l_log_head,
                          'p_line_rec_tbl(' || i || ').ship_to_org_id',
                          p_line_rec_tbl(i).ship_to_org_id);
        po_log.proc_begin(l_log_head,
                          'p_line_rec_tbl(' || i || ').supplier_item_num',
                          p_line_rec_tbl(i).supplier_item_num);
        po_log.proc_begin(l_log_head,
                          'p_line_rec_tbl(' || i || ').item_revision',
                          p_line_rec_tbl(i).item_revision);
        po_log.proc_begin(l_log_head,
                          'p_line_rec_tbl(' || i || ').item_id',
                          p_line_rec_tbl(i).item_id);
        po_log.proc_begin(l_log_head,
                          'p_line_rec_tbl(' || i || ').category_id',
                          p_line_rec_tbl(i).category_id);
        po_log.proc_begin(l_log_head,
                          'p_line_rec_tbl(' || i || ').rate',
                          p_line_rec_tbl(i).rate);
        po_log.proc_begin(l_log_head,
                          'p_line_rec_tbl(' || i || ').rate_type',
                          p_line_rec_tbl(i).rate_type);
        po_log.proc_begin(l_log_head,
                          'p_line_rec_tbl(' || i || ').currency_code',
                          p_line_rec_tbl(i).currency_code);
        po_log.proc_begin(l_log_head,
                          'p_line_rec_tbl(' || i || ').need_by_date',
                          p_line_rec_tbl(i).need_by_date);
        po_log.proc_begin(l_log_head,
                          'p_line_rec_tbl(' || i || ').shipment_line_id',
                          p_line_rec_tbl(i).shipment_line_id);
        po_log.proc_begin(l_log_head,
                          'p_line_rec_tbl(' || i ||
                          ').primary_unit_of_measure',
                          p_line_rec_tbl(i).primary_unit_of_measure);
        po_log.proc_begin(l_log_head,
                          'p_line_rec_tbl(' || i || ').to_organization_id',
                          p_line_rec_tbl(i).to_organization_id);
        po_log.proc_begin(l_log_head,
                          'p_line_rec_tbl(' || i || ').unit_of_measure',
                          p_line_rec_tbl(i).unit_of_measure);
        po_log.proc_begin(l_log_head,
                          'p_line_rec_tbl(' || i ||
                          ').source_document_code',
                          p_line_rec_tbl(i).source_document_code);
        po_log.proc_begin(l_log_head,
                          'p_line_rec_tbl(' || i || ').unit_price',
                          p_line_rec_tbl(i).unit_price);
        po_log.proc_begin(l_log_head,
                          'p_line_rec_tbl(' || i || ').quantity',
                          p_line_rec_tbl(i).quantity);
      END LOOP;
    
      po_log.proc_begin(l_log_head, 'p_request_type', p_request_type);
      po_log.proc_begin(l_log_head, 'p_pricing_event', p_pricing_event);
      po_log.proc_begin(l_log_head,
                        'p_has_header_pricing',
                        p_has_header_pricing);
      po_log.proc_begin(l_log_head,
                        'p_return_price_flag',
                        p_return_price_flag);
      po_log.proc_begin(l_log_head,
                        'p_return_freight_flag',
                        p_return_freight_flag);
    END IF;
  
    x_price_tbl := qp_price_result_rec_tbl_type();
    po_log.stmt(l_log_head, d_pos, 'Check Advanced Pricing License');
    fnd_profile.get('QP_LICENSED_FOR_PRODUCT', l_qp_license);
    d_pos := 20;
    IF g_debug_stmt THEN
      po_log.stmt(l_log_head, d_pos, 'l_qp_license', l_qp_license);
    END IF;
  
    IF (l_qp_license IS NULL OR l_qp_license <> 'PO') THEN
      RETURN;
    END IF;
  
    d_pos := 40;
    IF g_debug_stmt THEN
      po_log.stmt(l_log_head, d_pos, 'Set Price Request ID');
    END IF;
  
    qp_price_request_context.set_request_id;
  
    d_pos := 60;
    IF g_debug_stmt THEN
      po_log.stmt(l_log_head, d_pos, 'Populate Global Header Structure');
    END IF;
  
    populate_header_record(p_org_id              => p_header_rec.org_id,
                           p_order_header_id     => p_header_rec.p_order_header_id,
                           p_supplier_id         => p_header_rec.supplier_id,
                           p_supplier_site_id    => p_header_rec.supplier_site_id,
                           p_creation_date       => p_header_rec.creation_date,
                           p_order_type          => p_header_rec.order_type,
                           p_ship_to_location_id => p_header_rec.ship_to_location_id,
                           p_ship_to_org_id      => p_header_rec.ship_to_org_id,
                           -- New Attributes for R12: Receving FSC support
                           p_shipment_header_id    => p_header_rec.shipment_header_id,
                           p_hazard_class          => p_header_rec.hazard_class,
                           p_hazard_code           => p_header_rec.hazard_code,
                           p_shipped_date          => p_header_rec.shipped_date,
                           p_shipment_num          => p_header_rec.shipment_num,
                           p_carrier_method        => p_header_rec.carrier_method,
                           p_packaging_code        => p_header_rec.packaging_code,
                           p_freight_carrier_code  => p_header_rec.freight_carrier_code,
                           p_freight_terms         => p_header_rec.freight_terms,
                           p_currency_code         => p_header_rec.currency_code,
                           p_rate                  => p_header_rec.rate,
                           p_rate_type             => p_header_rec.rate_type,
                           p_source_org_id         => p_header_rec.source_org_id,
                           p_expected_receipt_date => p_header_rec.expected_receipt_date);
  
    d_pos := 80;
    IF g_debug_stmt THEN
      po_log.stmt(l_log_head, d_pos, 'Populate Global Line Structure');
    END IF;
  
    i := 1;
  
    d_pos := 90;
    IF g_debug_stmt THEN
      po_log.stmt(l_log_head, d_pos, 'Set OE Debug');
      oe_debug_pub.setdebuglevel(10);
      po_log.stmt(l_log_head,
                  d_pos,
                  'Debug File Location: ' ||
                  oe_debug_pub.set_debug_mode('FILE'));
      oe_debug_pub.initialize;
      oe_debug_pub.debug_on;
    END IF;
  
    d_pos := 100;
  
    IF (p_has_header_pricing) THEN
      d_pos := 110;
      IF g_debug_stmt THEN
        po_log.stmt(l_log_head,
                    d_pos,
                    'Build Attributes Mapping Contexts for header');
      END IF;
      qp_attr_mapping_pub.build_contexts(p_request_type_code => p_request_type,
                                         p_line_index        => i,
                                         p_pricing_type_code => 'H',
                                         p_check_line_flag   => 'N',
                                         p_pricing_event     => p_pricing_event,
                                         x_pass_line         => l_pass_line);
      d_pos := 120;
    
      l_request_type_code_tbl(i) := p_request_type;
      l_line_id_tbl(i) := nvl(p_header_rec.p_order_header_id,
                              p_header_rec.shipment_header_id); -- header id
      l_line_index_tbl(i) := i; -- Request Line Index
      l_line_type_code_tbl(i) := 'ORDER'; -- LINE or ORDER(Summary Line)
      l_pricinl_effective_date_tbl(i) := SYSDATE; -- Pricing as of effective date
      l_active_date_first_tbl(i) := NULL; -- Can be Ordered Date or Ship Date
      l_active_date_second_tbl(i) := NULL; -- Can be Ordered Date or Ship Date
      l_active_date_first_type_tbl(i) := NULL; -- ORD/SHIP
      l_active_date_second_type_tbl(i) := NULL; -- ORD/SHIP
      l_line_unit_price_tbl(i) := NULL; -- Unit Price
      l_line_quantity_tbl(i) := NULL; -- Ordered Quantity
      l_line_uom_code_tbl(i) := NULL; -- Ordered UOM Code
      l_currency_code_tbl(i) := p_header_rec.currency_code; -- Currency Code
      l_price_flag_tbl(i) := 'Y'; -- Price Flag can have 'Y',
      -- 'N'(No pricing),
      -- 'P'(Phase)
      l_usage_pricing_type_tbl(i) := qp_preq_grp.g_regular_usage_type;
      l_priced_quantity_tbl(i) := NULL;
      l_priced_uom_code_tbl(i) := NULL;
      l_unit_price_tbl(i) := NULL;
      l_percent_price_tbl(i) := NULL;
      l_uom_quantity_tbl(i) := NULL;
      l_adjusted_unit_price_tbl(i) := NULL;
      l_upd_adjusted_unit_price_tbl(i) := NULL;
      l_processed_flag_tbl(i) := NULL;
      l_processing_order_tbl(i) := NULL;
      l_pricing_status_code_tbl(i) := qp_preq_grp.g_status_unchanged;
      l_pricing_status_text_tbl(i) := NULL;
      l_rounding_flag_tbl(i) := NULL;
      l_rounding_factor_tbl(i) := NULL;
      l_qualifiers_exist_flag_tbl(i) := 'N';
      l_pricing_attrs_exist_flag_tbl(i) := 'N';
      l_price_list_id_tbl(i) := -9999;
      l_pl_validated_flag_tbl(i) := 'N';
      l_price_request_code_tbl(i) := NULL;
      l_line_category_tbl(i) := NULL;
      l_list_price_overide_flag_tbl(i) := 'O'; -- Override price
    
      i     := i + 1;
      d_pos := 130;
    END IF;
  
    FOR j IN 1 .. p_line_rec_tbl.COUNT LOOP
      populate_line_record(p_order_line_id       => p_line_rec_tbl(j)
                                                   .order_line_id,
                           p_item_revision       => p_line_rec_tbl(j)
                                                   .item_revision,
                           p_item_id             => p_line_rec_tbl(j)
                                                   .item_id,
                           p_category_id         => p_line_rec_tbl(j)
                                                   .category_id,
                           p_supplier_item_num   => p_line_rec_tbl(j)
                                                   .supplier_item_num,
                           p_agreement_type      => p_line_rec_tbl(j)
                                                   .agreement_type,
                           p_agreement_id        => p_line_rec_tbl(j)
                                                   .agreement_id,
                           p_agreement_line_id   => p_line_rec_tbl(j)
                                                   .agreement_line_id, --<R12 GBPA Adv Pricing>
                           p_supplier_id         => p_line_rec_tbl(j)
                                                   .supplier_id,
                           p_supplier_site_id    => p_line_rec_tbl(j)
                                                   .supplier_site_id,
                           p_ship_to_location_id => p_line_rec_tbl(j)
                                                   .ship_to_location_id,
                           p_ship_to_org_id      => p_line_rec_tbl(j)
                                                   .ship_to_org_id,
                           p_rate                => p_line_rec_tbl(j).rate,
                           p_rate_type           => p_line_rec_tbl(j)
                                                   .rate_type,
                           p_currency_code       => p_line_rec_tbl(j)
                                                   .currency_code,
                           p_need_by_date        => p_line_rec_tbl(j)
                                                   .need_by_date,
                           -- New Attributes for R12: Receving FSC support
                           p_shipment_line_id        => p_line_rec_tbl(j)
                                                       .shipment_line_id,
                           p_primary_unit_of_measure => p_line_rec_tbl(j)
                                                       .primary_unit_of_measure,
                           p_to_organization_id      => p_line_rec_tbl(j)
                                                       .to_organization_id,
                           p_unit_of_measure         => p_line_rec_tbl(j)
                                                       .unit_of_measure,
                           p_source_document_code    => p_line_rec_tbl(j)
                                                       .source_document_code,
                           p_quantity                => p_line_rec_tbl(j)
                                                       .quantity);
    
      d_pos := 140;
    
      IF g_debug_stmt THEN
        --make the pricing debug ON
        po_debug.debug_stmt(l_log_head, d_pos, 'Set OE Debug');
        oe_debug_pub.setdebuglevel(10);
        po_debug.debug_stmt(l_log_head,
                            d_pos,
                            'Debug File Location: ' ||
                            oe_debug_pub.set_debug_mode('FILE'));
        oe_debug_pub.initialize;
        oe_debug_pub.debug_on;
      END IF;
    
      d_pos := 150;
      IF g_debug_stmt THEN
        po_log.stmt(l_log_head,
                    d_pos,
                    'Build Attributes Mapping Contexts for Line(' || j || ')');
      END IF;
    
      qp_attr_mapping_pub.build_contexts(p_request_type_code => p_request_type,
                                         p_line_index        => i,
                                         p_pricing_type_code => 'L',
                                         p_check_line_flag   => 'N',
                                         p_pricing_event     => p_pricing_event,
                                         x_pass_line         => l_pass_line);
    
      d_pos := 160;
      IF g_debug_stmt THEN
        po_log.stmt(l_log_head, d_pos, 'Get UOM Code');
      END IF;
    
      BEGIN
        -- Make sure we pass uom_code instead of unit_of_measure.
        SELECT mum.uom_code
          INTO l_uom_code
          FROM mtl_units_of_measure mum
         WHERE mum.unit_of_measure = p_line_rec_tbl(j).unit_of_measure;
      EXCEPTION
        WHEN OTHERS THEN
          l_uom_code := p_line_rec_tbl(j).unit_of_measure;
      END;
    
      d_pos := 170;
      IF g_debug_stmt THEN
        po_log.stmt(l_log_head, d_pos, 'l_uom_code', l_uom_code);
        po_log.stmt(l_log_head, d_pos, 'Directly Insert into Temp table');
      END IF;
    
      l_request_type_code_tbl(i) := p_request_type;
      l_line_id_tbl(i) := nvl(p_line_rec_tbl(j).order_line_id,
                              p_line_rec_tbl(j).shipment_line_id); -- order line id
      l_line_index_tbl(i) := i; -- Request Line Index
      l_line_type_code_tbl(i) := 'LINE'; -- LINE or ORDER(Summary Line)
      l_pricinl_effective_date_tbl(i) := p_line_rec_tbl(j).need_by_date; -- Pricing as of effective date
      l_active_date_first_tbl(i) := NULL; -- Can be Ordered Date or Ship Date
      l_active_date_second_tbl(i) := NULL; -- Can be Ordered Date or Ship Date
      l_active_date_first_type_tbl(i) := NULL; -- ORD/SHIP
      l_active_date_second_type_tbl(i) := NULL; -- ORD/SHIP
      l_line_unit_price_tbl(i) := p_line_rec_tbl(j).unit_price; -- Unit Price
      l_line_quantity_tbl(i) := nvl(p_line_rec_tbl(j).quantity, 1); -- Ordered Quantity
    
      IF (l_line_quantity_tbl(i) = 0) THEN
        l_line_quantity_tbl(i) := 1;
      END IF;
    
      l_line_uom_code_tbl(i) := l_uom_code; -- Ordered UOM Code
      l_currency_code_tbl(i) := p_line_rec_tbl(j).currency_code; -- Currency Code
      l_price_flag_tbl(i) := 'Y'; -- Price Flag can have 'Y',
      -- 'N'(No pricing),
      -- 'P'(Phase)
      l_usage_pricing_type_tbl(i) := qp_preq_grp.g_regular_usage_type;
      l_priced_quantity_tbl(i) := nvl(p_line_rec_tbl(j).quantity, 1);
      IF (l_priced_quantity_tbl(i) = 0) THEN
        l_priced_quantity_tbl(i) := 1;
      END IF;
      l_priced_uom_code_tbl(i) := l_uom_code;
      l_unit_price_tbl(i) := p_line_rec_tbl(j).unit_price;
      l_percent_price_tbl(i) := NULL;
      l_uom_quantity_tbl(i) := NULL;
      l_adjusted_unit_price_tbl(i) := NULL;
      l_upd_adjusted_unit_price_tbl(i) := NULL;
      l_processed_flag_tbl(i) := NULL;
      l_processing_order_tbl(i) := NULL;
      l_pricing_status_code_tbl(i) := qp_preq_grp.g_status_unchanged;
      l_pricing_status_text_tbl(i) := NULL;
      l_rounding_flag_tbl(i) := NULL;
      l_rounding_factor_tbl(i) := NULL;
      l_qualifiers_exist_flag_tbl(i) := 'N';
      l_pricing_attrs_exist_flag_tbl(i) := 'N';
      l_price_list_id_tbl(i) := -9999;
      l_pl_validated_flag_tbl(i) := 'N';
      l_price_request_code_tbl(i) := NULL;
      l_line_category_tbl(i) := NULL;
      l_list_price_overide_flag_tbl(i) := 'O'; -- Override price
    
      i := i + 1;
    
    END LOOP;
  
    d_pos := 180;
    IF g_debug_stmt THEN
      po_log.stmt(l_log_head, d_pos, 'Call INSERT_LINES2');
    END IF;
  
    qp_preq_grp.insert_lines2(p_line_index               => l_line_index_tbl,
                              p_line_type_code           => l_line_type_code_tbl,
                              p_pricing_effective_date   => l_pricinl_effective_date_tbl,
                              p_active_date_first        => l_active_date_first_tbl,
                              p_active_date_first_type   => l_active_date_first_type_tbl,
                              p_active_date_second       => l_active_date_second_tbl,
                              p_active_date_second_type  => l_active_date_second_type_tbl,
                              p_line_quantity            => l_line_quantity_tbl,
                              p_line_uom_code            => l_line_uom_code_tbl,
                              p_request_type_code        => l_request_type_code_tbl,
                              p_priced_quantity          => l_priced_quantity_tbl,
                              p_priced_uom_code          => l_priced_uom_code_tbl,
                              p_currency_code            => l_currency_code_tbl,
                              p_unit_price               => l_unit_price_tbl,
                              p_percent_price            => l_percent_price_tbl,
                              p_uom_quantity             => l_uom_quantity_tbl,
                              p_adjusted_unit_price      => l_adjusted_unit_price_tbl,
                              p_upd_adjusted_unit_price  => l_upd_adjusted_unit_price_tbl,
                              p_processed_flag           => l_processed_flag_tbl,
                              p_price_flag               => l_price_flag_tbl,
                              p_line_id                  => l_line_id_tbl,
                              p_processing_order         => l_processing_order_tbl,
                              p_pricing_status_code      => l_pricing_status_code_tbl,
                              p_pricing_status_text      => l_pricing_status_text_tbl,
                              p_rounding_flag            => l_rounding_flag_tbl,
                              p_rounding_factor          => l_rounding_factor_tbl,
                              p_qualifiers_exist_flag    => l_qualifiers_exist_flag_tbl,
                              p_pricing_attrs_exist_flag => l_pricing_attrs_exist_flag_tbl,
                              p_price_list_id            => l_price_list_id_tbl,
                              p_validated_flag           => l_pl_validated_flag_tbl,
                              p_price_request_code       => l_price_request_code_tbl,
                              p_usage_pricing_type       => l_usage_pricing_type_tbl,
                              p_line_category            => l_line_category_tbl,
                              p_line_unit_price          => l_line_unit_price_tbl,
                              p_list_price_override_flag => l_list_price_overide_flag_tbl,
                              x_status_code              => x_return_status,
                              x_status_text              => l_return_status_text);
  
    d_pos := 190;
    IF g_debug_stmt THEN
      po_log.stmt(l_log_head, d_pos, 'After Calling INSERT_LINES2');
      po_log.stmt(l_log_head, d_pos, 'x_return_status', x_return_status);
      po_log.stmt(l_log_head,
                  d_pos,
                  'l_return_status_text',
                  l_return_status_text);
    END IF;
  
    IF x_return_status = fnd_api.g_ret_sts_unexp_error THEN
      fnd_message.set_name('PO', 'PO_QP_PRICE_API_ERROR');
      fnd_message.set_token('ERROR_TEXT', l_return_status_text);
      fnd_msg_pub.add;
      RAISE fnd_api.g_exc_unexpected_error;
    ELSIF x_return_status = fnd_api.g_ret_sts_error THEN
      fnd_message.set_name('PO', 'PO_QP_PRICE_API_ERROR');
      fnd_message.set_token('ERROR_TEXT', l_return_status_text);
      fnd_msg_pub.add;
      RAISE fnd_api.g_exc_error;
    END IF;
  
    -- Don't call QP_PREQ_GRP.INSERT_LINE_ATTRS2 since PO has no
    -- ASK_FOR attributes
  
    d_pos := 200;
    IF g_debug_stmt THEN
      po_log.stmt(l_log_head,
                  d_pos,
                  'Populate Control Record for Pricing Request Call');
    END IF;
  
    l_control_rec.calculate_flag         := 'Y';
    l_control_rec.simulation_flag        := 'N';
    l_control_rec.pricing_event          := p_pricing_event;
    l_control_rec.temp_table_insert_flag := 'N';
    l_control_rec.check_cust_view_flag   := 'N';
    l_control_rec.request_type_code      := p_request_type;
    --now pricing take care of all the roundings.
    l_control_rec.rounding_flag := 'Q';
    --For multi_currency price list
    l_control_rec.use_multi_currency   := 'Y';
    l_control_rec.user_conversion_rate := p_header_rec.rate;
    l_control_rec.user_conversion_type := p_header_rec.rate_type;
    l_control_rec.function_currency    := p_header_rec.currency_code;
    l_control_rec.get_freight_flag     := 'N';
  
    d_pos := 200;
    IF g_debug_stmt THEN
      po_log.stmt(l_log_head, d_pos, 'Call PRICE_REQUEST');
    END IF;
  
    qp_preq_pub.price_request(p_control_rec        => l_control_rec,
                              x_return_status      => x_return_status,
                              x_return_status_text => l_return_status_text);
  
    d_pos := 220;
    IF g_debug_stmt THEN
      po_log.stmt(l_log_head, d_pos, 'x_return_status', x_return_status);
      po_log.stmt(l_log_head,
                  d_pos,
                  'l_return_status_text',
                  l_return_status_text);
    END IF;
  
    IF x_return_status = fnd_api.g_ret_sts_unexp_error THEN
      fnd_message.set_name('PO', 'PO_QP_PRICE_API_ERROR');
      fnd_message.set_token('ERROR_TEXT', l_return_status_text);
      fnd_msg_pub.add;
      RAISE fnd_api.g_exc_unexpected_error;
    ELSIF x_return_status = fnd_api.g_ret_sts_error THEN
      fnd_message.set_name('PO', 'PO_QP_PRICE_API_ERROR');
      fnd_message.set_token('ERROR_TEXT', l_return_status_text);
      fnd_msg_pub.add;
      RAISE fnd_api.g_exc_error;
    END IF;
  
    /** No custom price hook for receiving.. need to
        incorporate it. whenever we are planning to use
        FSC for PO document
    PO_CUSTOM_PRICE_PUB.audit_qp_price_adjustment(
          p_api_version           => 1.0
    ,     p_order_type            => p_order_type
    ,     p_order_line_id         => l_line_id
    ,     p_line_index            => 1
    ,     x_return_status         => l_return_status
    ,     x_msg_count             => l_msg_count
    ,     x_msg_data          => l_msg_data
    );
    
    l_progress := '230';
    IF l_return_status <> FND_API.G_RET_STS_SUCCESS THEN
      PO_DEBUG.debug_var(l_log_head,l_progress,'l_return_status',l_return_status);
      PO_DEBUG.debug_unexp(l_log_head,l_progress,'audit_qp_price_adjustment errors out');
      FND_MESSAGE.SET_NAME('PO','PO_QP_PRICE_API_ERROR');
      FND_MESSAGE.SET_TOKEN('ERROR_TEXT',l_msg_data);
      FND_MSG_PUB.Add;
      RAISE FND_API.G_EXC_UNEXPECTED_ERROR;
    END IF;
    */
  
    d_pos := 240;
    IF g_debug_stmt THEN
      po_log.stmt(l_log_head, d_pos, 'Fetch QP pricing');
      po_log.stmt(l_log_head,
                  d_pos,
                  'p_header_rec.p_order_header_id',
                  p_header_rec.p_order_header_id);
      po_log.stmt(l_log_head,
                  d_pos,
                  'p_header_rec.shipment_header_id',
                  p_header_rec.shipment_header_id);
      po_log.stmt(l_log_head,
                  d_pos,
                  'QP_PREQ_LINES_TMP_T',
                  po_log.c_all_rows);
    END IF;
  
    IF p_return_price_flag THEN
      --Access the QP views to retrieve the values for price
      d_pos := 250;
    
      FOR j IN 1 .. i - 1 LOOP
        x_price_tbl.EXTEND();
      
        SELECT line_index,
               line_id,
               line_unit_price base_unit_price, -- base price
               order_uom_selling_price adjusted_price, -- adjusted_price
               pricing_status_code, --pricing status code
               pricing_status_text -- pricing status text
          INTO x_price_tbl(j) .line_index,
               x_price_tbl(j) .line_id,
               x_price_tbl(j) .base_unit_price,
               x_price_tbl(j) .adjusted_price,
               x_price_tbl(j) .pricing_status_code,
               x_price_tbl(j) .pricing_status_text
          FROM qp_preq_lines_tmp
         WHERE line_index = j;
      
        d_pos := 260;
      
      END LOOP;
    END IF;
  
    IF p_return_freight_flag THEN
      d_pos := 270;
    
      FOR j IN 1 .. i - 1 LOOP
        -- query to qp_ldets_v to retrieve the freight charge info.
        SELECT charge_type_code,
               order_qty_adj_amt freight_charge,
               pricing_status_code,
               pricing_status_text BULK COLLECT
          INTO l_freight_charge_rec_tbl
          FROM qp_ldets_v
         WHERE line_index = j
           AND list_line_type_code = 'FREIGHT_CHARGE'
           AND applied_flag = 'Y';
      
        IF NOT p_return_price_flag THEN
          x_price_tbl.EXTEND();
        END IF;
      
        d_pos := 280;
      
        x_price_tbl(j).line_index := l_line_index_tbl(j);
        x_price_tbl(j).base_unit_price := l_unit_price_tbl(j);
        x_price_tbl(j).freight_charge_rec_tbl := l_freight_charge_rec_tbl;
        x_price_tbl(j).line_id := l_line_id_tbl(j);
      
        SELECT pricing_status_code, pricing_status_text
          INTO x_price_tbl(j) .pricing_status_code,
               x_price_tbl(j) .pricing_status_text
          FROM qp_preq_lines_tmp
         WHERE line_index = j;
        d_pos := 290;
      END LOOP;
    END IF;
  
    d_pos := 300;
    IF g_debug_stmt THEN
      po_log.proc_end(l_log_head);
      po_log.proc_end(l_log_head, 'x_return_status', x_return_status);
      FOR j IN 1 .. x_price_tbl.COUNT LOOP
        po_log.proc_end(l_log_head,
                        'x_price_tbl(' || j || ').line_index',
                        x_price_tbl(j).line_index);
        po_log.proc_end(l_log_head,
                        'x_price_tbl(' || j || ').line_id',
                        x_price_tbl(j).line_id);
        po_log.proc_end(l_log_head,
                        'x_price_tbl(' || j || ').base_unit_price',
                        x_price_tbl(j).base_unit_price);
        po_log.proc_end(l_log_head,
                        'x_price_tbl(' || j || ').adjusted_price',
                        x_price_tbl(j).adjusted_price);
        FOR k IN 1 .. x_price_tbl(j).freight_charge_rec_tbl.COUNT LOOP
          po_log.proc_end(l_log_head,
                          'x_price_tbl(' || j ||
                          ').freight_charge_rec_tbl(' || k ||
                          ').charge_type_code',
                          x_price_tbl(j).freight_charge_rec_tbl(k)
                          .charge_type_code);
          po_log.proc_end(l_log_head,
                          'x_price_tbl(' || j ||
                          ').freight_charge_rec_tbl(' || k ||
                          ').freight_charge',
                          x_price_tbl(j).freight_charge_rec_tbl(k)
                          .freight_charge);
          po_log.proc_end(l_log_head,
                          'x_price_tbl(' || j ||
                          ').freight_charge_rec_tbl(' || k ||
                          ').pricing_status_code',
                          x_price_tbl(j).freight_charge_rec_tbl(k)
                          .pricing_status_code);
          po_log.proc_end(l_log_head,
                          'x_price_tbl(' || j ||
                          ').freight_charge_rec_tbl(' || k ||
                          ').pricing_status_text',
                          x_price_tbl(j).freight_charge_rec_tbl(k)
                          .pricing_status_text);
        END LOOP;
        po_log.proc_end(l_log_head,
                        'x_price_tbl(' || j || ').pricing_status_code',
                        x_price_tbl(j).pricing_status_code);
        po_log.proc_end(l_log_head,
                        'x_price_tbl(' || j || ').pricing_status_text',
                        x_price_tbl(j).pricing_status_text);
      END LOOP;
    END IF;
  EXCEPTION
    WHEN fnd_api.g_exc_error THEN
      --raised expected error: assume raiser already pushed onto the stack
      l_exception_msg := fnd_msg_pub.get(p_msg_index => fnd_msg_pub.g_last,
                                         p_encoded   => 'F');
      IF g_debug_unexp THEN
        po_log.exc(l_log_head, d_pos, l_exception_msg);
      END IF;
      x_return_status := fnd_api.g_ret_sts_error;
      -- Push the po_return_msg onto msg list and message stack
      fnd_message.set_name('PO', 'PO_QP_PRICE_API_ERROR');
      fnd_message.set_token('ERROR_TEXT', l_exception_msg);
    
    WHEN fnd_api.g_exc_unexpected_error THEN
      --raised unexpected error: assume raiser already pushed onto the stack
      l_exception_msg := fnd_msg_pub.get(p_msg_index => fnd_msg_pub.g_last,
                                         p_encoded   => 'F');
      IF g_debug_unexp THEN
        po_log.exc(l_log_head, d_pos, l_exception_msg);
      END IF;
      x_return_status := fnd_api.g_ret_sts_unexp_error;
      -- Push the po_return_msg onto msg list and message stack
      fnd_message.set_name('PO', 'PO_QP_PRICE_API_ERROR');
      fnd_message.set_token('ERROR_TEXT', l_exception_msg);
    
    WHEN OTHERS THEN
      IF g_debug_unexp THEN
        po_log.exc(l_log_head, d_pos);
      END IF;
      --unexpected error from this procedure: get SQLERRM
      po_message_s.sql_error(g_pkg_name,
                             l_api_name,
                             d_pos,
                             SQLCODE,
                             SQLERRM);
      l_exception_msg := fnd_message.get;
      IF g_debug_unexp THEN
        po_log.exc(l_log_head, d_pos, l_exception_msg);
      END IF;
      x_return_status := fnd_api.g_ret_sts_unexp_error;
      -- Push the po_return_msg onto msg list and message stack
      fnd_message.set_name('PO', 'PO_QP_PRICE_API_ERROR');
      fnd_message.set_token('ERROR_TEXT', l_exception_msg);
  END get_advanced_price;
  -- <FSC R12 END>

  FUNCTION get_list_price_from_ic(p_source_organization_id NUMBER,
                                  p_dest_organization_id   NUMBER,
                                  x_list_price_curr_code   OUT VARCHAR2,
                                  x_source_curr_code       OUT VARCHAR2)
    RETURN NUMBER IS
    l_list_header_id qp_list_headers_all.list_header_id%TYPE := NULL;
  
  BEGIN
  
    SELECT hzca.price_list_id, ql.currency_code, l.currency_code
      INTO l_list_header_id, x_list_price_curr_code, x_source_curr_code
      FROM hz_cust_site_uses_all        hzca,
           org_organization_definitions odest,
           org_organization_definitions osource,
           gl_ledgers                   l,
           mtl_intercompany_parameters  mtrel,
           qp_list_headers_b            ql
     WHERE odest.organization_id =
           nvl(p_dest_organization_id, odest.organization_id)
       AND mtrel.sell_organization_id = odest.operating_unit
       AND osource.organization_id =
           nvl(p_source_organization_id, osource.organization_id)
       AND mtrel.ship_organization_id = osource.operating_unit
       AND hzca.cust_acct_site_id = mtrel.address_id
       AND osource.set_of_books_id = l.ledger_id
       AND hzca.price_list_id = ql.list_header_id
       AND
          --hzca.primary_flag = 'Y' AND
           hzca.site_use_code = 'BILL_TO'
       AND rownum < 2;
  
    /*  log_pricing(fnd_global.org_id,
    p_dest_organization_id,
    p_source_organization_id,
    l_list_header_id,
    'PL: ' || x_list_price_curr_code, --fnd_global.user_name,
    NULL,
    NULL,
    'GET_LIST_PRICE_FROM_IC');*/
  
    RETURN l_list_header_id;
  
  EXCEPTION
    WHEN OTHERS THEN
      /*  log_pricing(fnd_global.org_id,
      p_dest_organization_id,
      p_source_organization_id,
      NULL,
      fnd_global.user_name,
      NULL,
      NULL,
      'GET_LIST_PRICE_FROM_IC-EX');*/
    
      RETURN NULL;
  END get_list_price_from_ic;

  PROCEDURE get_item_price(p_list_header_id       qp_list_headers_all.list_header_id%TYPE,
                           p_item_id              mtl_system_items_b.inventory_item_id%TYPE,
                           p_list_price_curr_code VARCHAR2,
                           p_source_curr_code     VARCHAR2,
                           x_unit_price           IN OUT NOCOPY NUMBER) IS
  
    l_calc_unit_price NUMBER;
    l_final_price     NUMBER(10, 4);
    l_err_msg         VARCHAR2(500);
  
  BEGIN
  
    SELECT operand
      INTO l_calc_unit_price
      FROM qp_list_lines_v qll
     WHERE qll.list_header_id = p_list_header_id
       AND SYSDATE BETWEEN nvl(qll.start_date_active, SYSDATE) AND
           nvl(qll.end_date_active, SYSDATE)
       AND product_attr_value = to_char(p_item_id);
  
    /*      log_pricing(fnd_global.org_id,
    NULL,
    NULL,
    p_list_header_id,
    'Source: ' || p_source_curr_code, --fnd_global.user_name,
    l_calc_unit_price,
    p_item_id,
    'GET_ITEM_PRICE');*/
  
    IF l_calc_unit_price IS NOT NULL THEN
    
      l_calc_unit_price := round(gl_currency_api.convert_amount(x_from_currency   => p_list_price_curr_code,
                                                                x_to_currency     => p_source_curr_code,
                                                                x_conversion_date => SYSDATE,
                                                                x_conversion_type => 'Corporate',
                                                                x_amount          => l_calc_unit_price),
                                 4);
      l_final_price     := l_calc_unit_price;
      x_unit_price      := l_final_price;
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      l_err_msg := SQLERRM;
      /*    log_pricing(fnd_global.org_id,
      NULL,
      NULL,
      p_list_header_id,
      fnd_global.user_name,
      NULL,
      p_item_id,
      'GET_ITEM_PRICE: ' || l_err_msg);*/
    
      NULL;
  END get_item_price;

  PROCEDURE get_cust_internal_req_price(p_api_version            IN NUMBER,
                                        p_item_id                IN NUMBER DEFAULT NULL,
                                        p_category_id            IN NUMBER DEFAULT NULL,
                                        p_req_header_id          IN NUMBER DEFAULT NULL,
                                        p_req_line_id            IN NUMBER DEFAULT NULL,
                                        p_src_organization_id    IN NUMBER DEFAULT NULL,
                                        p_src_sub_inventory      IN VARCHAR2 DEFAULT NULL,
                                        p_dest_organization_id   IN NUMBER DEFAULT NULL,
                                        p_dest_sub_inventory     IN VARCHAR2 DEFAULT NULL,
                                        p_deliver_to_location_id IN NUMBER DEFAULT NULL,
                                        p_need_by_date           IN DATE DEFAULT NULL,
                                        p_unit_of_measure        IN VARCHAR2 DEFAULT NULL,
                                        p_quantity               IN NUMBER DEFAULT NULL,
                                        p_currency_code          IN VARCHAR2 DEFAULT NULL,
                                        p_rate                   IN NUMBER DEFAULT NULL,
                                        p_rate_type              IN VARCHAR2 DEFAULT NULL,
                                        p_rate_date              IN DATE DEFAULT NULL,
                                        x_return_status          OUT NOCOPY VARCHAR2,
                                        x_unit_price             IN OUT NOCOPY NUMBER)
  
   IS
  
    l_list_header_id       qp_list_headers_all.list_header_id%TYPE := NULL;
    l_price_list_curr_code VARCHAR2(3);
    l_source_curr_code     VARCHAR2(3);
  BEGIN
  
    IF nvl(fnd_profile.VALUE('XXPO_ENABLE_INTER_REQ_PRICE'), 'N') = 'Y' THEN
    
      l_list_header_id := get_list_price_from_ic(p_src_organization_id,
                                                 p_dest_organization_id,
                                                 l_price_list_curr_code,
                                                 l_source_curr_code);
    
      IF l_list_header_id IS NOT NULL THEN
        get_item_price(l_list_header_id,
                       p_item_id,
                       l_price_list_curr_code,
                       l_source_curr_code,
                       x_unit_price);
      END IF;
    
    END IF;
  
  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END get_cust_internal_req_price;

  FUNCTION get_transfer_price(i_transaction_id IN NUMBER,
                              i_price_list_id  IN NUMBER,
                              i_sell_ou_id     IN NUMBER,
                              i_ship_ou_id     IN NUMBER,
                              o_currency_code  OUT NOCOPY VARCHAR2,
                              x_return_status  OUT NOCOPY VARCHAR2,
                              x_msg_count      OUT NOCOPY NUMBER,
                              x_msg_data       OUT NOCOPY VARCHAR2,
                              i_order_line_id  IN NUMBER DEFAULT NULL)
    RETURN NUMBER IS
  
    l_transfer_price      NUMBER;
    l_tmp                 NUMBER;
    l_price_list_currency VARCHAR2(10);
    l_ledger_currency     VARCHAR2(10);
    CURSOR c IS
      SELECT 1
      -- INTO l_requisition_price
        FROM hz_cust_site_uses_all        hzca,
             org_organization_definitions odest,
             org_organization_definitions osource,
             gl_ledgers                   l,
             mtl_intercompany_parameters  mtrel,
             qp_list_headers_b            ql,
             po_requisition_lines_all     req,
             oe_order_lines_all           ol
       WHERE ol.line_id = i_order_line_id
         AND req.requisition_line_id = ol.source_document_line_id
         AND odest.organization_id = req.destination_organization_id
         AND osource.organization_id = req.source_organization_id
         AND odest.organization_id = odest.organization_id
         AND mtrel.sell_organization_id = odest.operating_unit
         AND mtrel.ship_organization_id = osource.operating_unit
         AND hzca.cust_acct_site_id = mtrel.address_id
         AND osource.set_of_books_id = l.ledger_id
         AND hzca.price_list_id = ql.list_header_id
         AND --hzca.primary_flag = 'Y' AND
             hzca.site_use_code = 'BILL_TO'
         AND ol.order_source_id = 10; --AND
  
    CURSOR c2 IS
      SELECT
      -- osource.organization_id SOURCE,
      -- odest.organization_id dest,
      -- hzca.price_list_id,
       ql.currency_code price_list_currency,
       l.currency_code ledger_currency,
       ol.unit_selling_price,
       --  INTO l_list_header_id, x_list_price_curr_code, x_source_curr_code
       h.transactional_curr_code
        FROM hz_cust_site_uses_all        hzca,
             org_organization_definitions odest,
             org_organization_definitions osource,
             gl_ledgers                   l,
             mtl_intercompany_parameters  mtrel,
             qp_list_headers_b            ql,
             qp_list_headers_tl           xx,
             po_requisition_lines_all     req,
             oe_order_lines_all           ol,
             oe_order_headers_all         h
       WHERE h.header_id = ol.header_id
         AND ol.line_id = i_order_line_id
         AND req.requisition_line_id = ol.source_document_line_id --:NEW.orig_sys_line_ref
         AND odest.organization_id = req.destination_organization_id
         AND osource.organization_id = req.source_organization_id
         AND mtrel.sell_organization_id = odest.operating_unit
            
         AND mtrel.ship_organization_id = osource.operating_unit
         AND hzca.cust_acct_site_id = mtrel.address_id
         AND osource.set_of_books_id = l.ledger_id
         AND hzca.price_list_id = ql.list_header_id
            --hzca.primary_flag = 'Y' AND
         AND hzca.site_use_code = 'SHIP_TO' --AND
         AND xx.list_header_id = ql.list_header_id
         AND xx.LANGUAGE = 'US'
         AND ol.order_source_id = 10
         AND ol.source_type_code = 'INTERNAL';
  
  BEGIN
  
    IF nvl(fnd_profile.VALUE('XXPO_ENABLE_INTER_REQ_PRICE'), 'N') = 'Y' THEN
    
      x_return_status := fnd_api.g_ret_sts_success;
      x_msg_count     := 0;
      x_msg_data      := NULL;
      o_currency_code := NULL;
    
      -- 
      OPEN c;
      FETCH c
        INTO l_tmp;
      CLOSE c;
    
      IF l_tmp IS NULL THEN
      
        OPEN c2;
        FETCH c2
          INTO l_price_list_currency, l_ledger_currency, l_transfer_price, o_currency_code;
        CLOSE c2;
      
        IF l_transfer_price IS NOT NULL THEN
          RETURN l_transfer_price;
        END IF;
      END IF;
    
    END IF;
  
    o_currency_code := NULL;
    RETURN NULL;
  
  EXCEPTION
    WHEN OTHERS THEN
    
      o_currency_code := NULL;
      RETURN NULL;
    
  END get_transfer_price;

END xxpo_advanced_price_pkg;
/

