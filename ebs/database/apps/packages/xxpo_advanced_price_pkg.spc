CREATE OR REPLACE PACKAGE xxpo_advanced_price_pkg AS
  ---------------------------------------------------------------------------
  -- $Header: xxpo_advanced_price_pkg 120.0 2009/08/31  $
  ---------------------------------------------------------------------------
  -- Trigger: xxpo_advanced_price_pkg
  -- Created: 
  -- Author  : 
  --------------------------------------------------------------------------
  -- Perpose: update internal requisition price
  --------------------------------------------------------------------------
  -- Version  Date      Performer       Comments
  ----------  --------  --------------  -------------------------------------
  --     1.0  31/08/09                  Initial Build

  --  1.1     27.3.11  yuval tal change logic at get_transfer_price
  ---------------------------------------------------------------------------

  g_no_valid_period_exc EXCEPTION;
  g_submission_check_exc EXCEPTION;

  -------------------------------------------------------------------------------
  -- Package types
  -------------------------------------------------------------------------------
  -- Header record type
  TYPE header_rec_type IS RECORD(
    org_id              po_headers.org_id%TYPE,
    p_order_header_id   po_headers.po_header_id%TYPE,
    supplier_id         po_headers.vendor_id%TYPE,
    supplier_site_id    po_headers.vendor_site_id%TYPE,
    creation_date       po_headers.creation_date%TYPE,
    order_type          VARCHAR2(20) -- REQUISITION/PO
    ,
    ship_to_location_id po_headers.ship_to_location_id%TYPE,
    ship_to_org_id      po_headers.org_id%TYPE
    -- New Attributes for Receiving
    -- <FSC R12 START>
    ,
    shipment_header_id    rcv_shipment_headers.shipment_header_id%TYPE,
    hazard_class          rcv_shipment_headers.hazard_class%TYPE,
    hazard_code           rcv_shipment_headers.hazard_code%TYPE,
    shipped_date          rcv_shipment_headers.shipped_date%TYPE,
    shipment_num          rcv_shipment_headers.shipment_num%TYPE,
    carrier_method        rcv_shipment_headers.carrier_method%TYPE,
    packaging_code        rcv_shipment_headers.packaging_code%TYPE,
    freight_carrier_code  rcv_shipment_headers.freight_carrier_code%TYPE,
    freight_terms         rcv_shipment_headers.freight_terms%TYPE,
    currency_code         rcv_shipment_headers.currency_code%TYPE,
    rate                  rcv_shipment_headers.conversion_rate%TYPE,
    rate_type             rcv_shipment_headers.conversion_rate_type%TYPE,
    source_org_id         rcv_shipment_headers.organization_id%TYPE,
    expected_receipt_date rcv_shipment_headers.expected_receipt_date%TYPE
    --  <FSC R12 END>
    );

  --  Line record type
  TYPE line_rec_type IS RECORD(
    order_line_id       po_lines.po_line_id%TYPE,
    agreement_type      po_headers.type_lookup_code%TYPE,
    agreement_id        po_headers.po_header_id%TYPE,
    agreement_line_id   po_lines.po_line_id%TYPE --<R12 GBPA Adv Pricing>
    ,
    supplier_id         po_headers.vendor_id%TYPE,
    supplier_site_id    po_headers.vendor_site_id%TYPE,
    ship_to_location_id po_line_locations.ship_to_location_id%TYPE,
    ship_to_org_id      po_line_locations.ship_to_organization_id%TYPE,
    supplier_item_num   po_lines.vendor_product_num%TYPE,
    item_revision       po_lines.item_revision%TYPE,
    item_id             po_lines.item_id%TYPE,
    category_id         po_lines.category_id%TYPE,
    rate                po_headers.rate%TYPE,
    rate_type           po_headers.rate_type%TYPE,
    currency_code       po_headers.currency_code%TYPE,
    need_by_date        po_line_locations.need_by_date%TYPE
    -- <FSC R12 START>
    -- New Attributes for Receiving
    ,
    shipment_line_id        rcv_shipment_lines.shipment_line_id%TYPE,
    primary_unit_of_measure rcv_shipment_lines.primary_unit_of_measure%TYPE,
    to_organization_id      rcv_shipment_lines.to_organization_id%TYPE,
    unit_of_measure         rcv_shipment_lines.unit_of_measure%TYPE,
    source_document_code    rcv_shipment_lines.source_document_code%TYPE,
    unit_price              rcv_shipment_lines.shipment_unit_price%TYPE,
    quantity                rcv_shipment_lines.quantity_received%TYPE
    --  <FSC R12 END>
    );

  -- <FSC R12 START>
  -- QP Result Record to capture information returned by QP.
  -- Record to keep the freight charge info per line
  TYPE freight_charges_rec_type IS RECORD(
    charge_type_code    qp_preq_ldets_tmp_t.charge_type_code%TYPE,
    freight_charge      qp_preq_ldets_tmp_t.order_qty_adj_amt%TYPE,
    pricing_status_code qp_preq_ldets_tmp_t.pricing_status_code%TYPE,
    pricing_status_text qp_preq_ldets_tmp_t.pricing_status_text%TYPE);

  TYPE freight_charges_rec_tbl_type IS TABLE OF freight_charges_rec_type;

  --Record to keep the price/charge info per line.
  TYPE qp_price_result_rec_type IS RECORD(
    line_index             qp_preq_ldets_tmp_t.line_index%TYPE,
    line_id                NUMBER,
    base_unit_price        NUMBER,
    adjusted_price         NUMBER,
    freight_charge_rec_tbl freight_charges_rec_tbl_type,
    pricing_status_code    qp_preq_ldets_tmp_t.pricing_status_code%TYPE,
    pricing_status_text    qp_preq_ldets_tmp_t.pricing_status_text%TYPE);

  TYPE qp_price_result_rec_tbl_type IS TABLE OF qp_price_result_rec_type;

  TYPE line_tbl_type IS TABLE OF line_rec_type;
  -- <FSC R12 END>
  -------------------------------------------------------------------------------
  -- Global package variables
  -------------------------------------------------------------------------------

  --Global Variables for Attribute Mapping during Pricing
  g_hdr  header_rec_type;
  g_line line_rec_type;

  -------------------------------------------------------------------------------
  -- Package procedures
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
                               x_return_status       OUT NOCOPY VARCHAR2);

  FUNCTION is_valid_qp_line_type(p_line_type_id IN NUMBER) RETURN BOOLEAN;

  -- <FSC R12 START>
  PROCEDURE get_advanced_price(p_header_rec          IN header_rec_type,
                               p_line_rec_tbl        IN line_tbl_type,
                               p_request_type        IN VARCHAR2,
                               p_pricing_event       IN VARCHAR2,
                               p_has_header_pricing  IN BOOLEAN,
                               p_return_price_flag   IN BOOLEAN,
                               p_return_freight_flag IN BOOLEAN,
                               x_price_tbl           OUT NOCOPY qp_price_result_rec_tbl_type,
                               x_return_status       OUT NOCOPY VARCHAR2);
  -- <FSC R12 END>
  FUNCTION get_list_price_from_ic(p_source_organization_id NUMBER,
                                  p_dest_organization_id   NUMBER,
                                  x_list_price_curr_code   OUT VARCHAR2,
                                  x_source_curr_code       OUT VARCHAR2)
    RETURN NUMBER;

  PROCEDURE get_item_price(p_list_header_id       qp_list_headers_all.list_header_id%TYPE,
                           p_item_id              mtl_system_items_b.inventory_item_id%TYPE,
                           p_list_price_curr_code VARCHAR2,
                           p_source_curr_code     VARCHAR2,
                           x_unit_price           IN OUT NOCOPY NUMBER);

  /*** Called from Hook po_custom_price_pub.GET_CUST_INTERNAL_REQ_PRICE  ***/
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
                                        x_unit_price             IN OUT NOCOPY NUMBER);

  /*** Called from Hook MTL_INTERCOMPANY_INVOICES.GET_TRANSFER_PRICE  ***/
  FUNCTION get_transfer_price(i_transaction_id IN NUMBER,
                              i_price_list_id  IN NUMBER,
                              i_sell_ou_id     IN NUMBER,
                              i_ship_ou_id     IN NUMBER,
                              o_currency_code  OUT NOCOPY VARCHAR2,
                              x_return_status  OUT NOCOPY VARCHAR2,
                              x_msg_count      OUT NOCOPY NUMBER,
                              x_msg_data       OUT NOCOPY VARCHAR2,
                              i_order_line_id  IN NUMBER DEFAULT NULL)
    RETURN NUMBER;

END xxpo_advanced_price_pkg;
/

