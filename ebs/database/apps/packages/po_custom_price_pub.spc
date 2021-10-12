CREATE OR REPLACE PACKAGE po_custom_price_pub AUTHID CURRENT_USER AS
  /* $Header: POXPCPRS.pls 120.3.12010000.7 2009/06/12 13:48:57 rojain ship $ */
  /*#
  * Provide the ability to perform custom pricing on Oracle Purchasing
  * documents directly through an API.
  *
  * @rep:scope public
  * @rep:product PO
  * @rep:displayname Purchase Order Custom Pricing APIs
  */

  /*#
  * Provides the ability to customize the pricing date through an API.
  *
  * The API is called by the Oracle Requisition Pricing API and
  * PO/Release Pricing API that would use the pricing date to fetch the
  * price.  Prices of products in catalogs may not be static and can
  * vary with time due to various factors: supply/demand variations,
  * buying volume, and component price variations.
  *
  * The variation of price of a product with time is actually captured
  * in terms of price and effective periods in the form of price breaks
  * on blanket purchase agreements and catalog quotations. Price list
  * lines in Oracle Advanced Pricing can also have effective periods
  * defined.
  *
  * Based on the supplier agreement, the price of the product being
  * ordered or requested from the catalog may be determined based on the
  * price that is effective on the pricing date. The pricing date can be
  * the date that the order is placed, the date that the order is
  * shipped, or the date that the material is expected to arrive. Rules
  * around determining the pricing date widely vary from one business to
  * another and even within a business from one commodity to another.
  *
  * Businesses can add PL/SQL code to the custom API that can
  * accommodate their own special rules to determine the pricing date.
  * The subsequent pricing call will return the unit price from the
  * source blanket or quotation that is effective on the pricing date.
  *
  * @param p_api_version Null not allowed.  Value should match the
  * current version of the API (currently 1.0). Used by the API to
  * determine compatibility of API and calling program.
  * @rep:paraminfo  {@rep:required}
  *
  * @param p_source_document_header_id Internal ID for source document
  * header. (i.e. PO_LINES_ALL.po_header_id)
  * @rep:paraminfo  {@rep:required}
  *
  * @param p_source_document_line_id Internal ID for source document
  * line. (i.e. PO_LINES_ALL.po_line_id)
  * @rep:paraminfo  {@rep:required}
  *
  * @param p_order_line_id Internal ID for an order line. (i.e.
  * PO_HEADERS_ALL.po_header_id)
  * @rep:paraminfo  {@rep:required}
  *
  * @param p_quantity Quantity
  * @rep:paraminfo  {@rep:required}
  *
  * @param p_ship_to_location_id Ship to location ID
  * @rep:paraminfo  {@rep:required}
  *
  * @param p_ship_to_organization_id Ship to organization ID
  * @rep:paraminfo  {@rep:required}
  *
  * @param p_need_by_date Need by date
  * @rep:paraminfo  {@rep:required}
  *
  * @param x_pricing_date New custom pricing date
  * @rep:paraminfo  {@rep:required}
  *
  * @param x_return_status Possible Values are:
  * S = Success - Completed without errors.
  * E = Error - Parameters are in error.
  * U = Unexpected error.
  * Bug5598011 @param p_order_type Adding new parameter p_order_type which will
  * indicate if the order document is PO or REQUISITION
  
  * @rep:displayname Get custom price date
  *
  * @rep:category BUSINESS_ENTITY PO_STANDARD_PURCHASE_ORDER
  * @rep:category BUSINESS_ENTITY PO_BLANKET_RELEASE
  * @rep:category BUSINESS_ENTITY PO_PURCHASE_REQUISITION
  * @rep:category BUSINESS_ENTITY PO_INTERNAL_REQUISITION
  */
  PROCEDURE get_custom_price_date(p_api_version               IN NUMBER,
                                  p_source_document_header_id IN NUMBER, -- <FPJ Advanced Price>
                                  p_source_document_line_id   IN NUMBER,
                                  p_order_line_id             IN NUMBER, -- <Bug 3754828>
                                  p_quantity                  IN NUMBER,
                                  p_ship_to_location_id       IN NUMBER,
                                  p_ship_to_organization_id   IN NUMBER,
                                  p_need_by_date              IN DATE,
                                  x_pricing_date              OUT NOCOPY DATE,
                                  x_return_status             OUT NOCOPY VARCHAR2,
                                  p_order_type                IN VARCHAR2 DEFAULT NULL); -- <Bug5598011>

  /*#
  * Provides the ability to customize the requisition price through an
  * API.
  *
  * This API is called by the Oracle Requisition Pricing API that could
  * return a different price than what the Oracle Requisition Pricing
  * API has returned.
  *
  * Often times the price maintained on supplier catalogs are purely
  * list prices and does not factor in adjustments such as discounts or
  * surcharges as negotiated between a specific buyer and supplier.
  *
  * The Custom Requisition Pricing API enables you to add PL/SQL code to
  * a new custom price adjustment hook in the standard requisition
  * pricing API to adjust the price as determined from a source document
  * (blanket agreement or quotation). This provides a mechanism to
  * factor in negotiated discounts, surcharges, or other adjustments on
  * top of the catalog prices.
  *
  * @param p_api_version Null not allowed. Value should match the
  * current version of the API (currently 1.0). Used by the API to
  * determine compatibility of API and calling program.
  * @rep:paraminfo  {@rep:required}
  *
  * @param p_source_document_header_id Internal ID for source document
  * header. (i.e. PO_LINES_ALL.po_header_id)
  * @rep:paraminfo  {@rep:required}
  *
  * @param p_source_document_line_num Line number for source document
  * line. (i.e. PO_LINES_ALL.po_line_id)
  * @rep:paraminfo  {@rep:required}
  *
  * @param p_order_line_id Internal ID for an order line. (i.e.
  * PO_HEADERS_ALL.po_header_id)
  * @rep:paraminfo  {@rep:required}
  *
  * @param p_quantity Quantity
  * @rep:paraminfo  {@rep:required}
  *
  * @param p_unit_of_measure Unit of Measure
  * @rep:paraminfo  {@rep:required}
  *
  * @param p_deliver_to_location_id Deliver to location ID
  * @rep:paraminfo  {@rep:required}
  *
  * @param p_required_currency Required currency
  * @rep:paraminfo  {@rep:required}
  *
  * @param p_required_rate_type Required rate type
  * @rep:paraminfo  {@rep:required}
  *
  * @param p_need_by_date Need by date
  * @rep:paraminfo  {@rep:required}
  *
  * @param p_pricing_date Pricing date
  * @rep:paraminfo  {@rep:required}
  *
  * @param p_destination_org_id Destination organization ID
  * @rep:paraminfo  {@rep:required}
  *
  * @param p_currency_price Currency price
  * @rep:paraminfo  {@rep:required}
  *
  * @param x_new_currency_price New customized price
  * @rep:paraminfo  {@rep:required}
  *
  * @param x_return_status Possible Values are:
  * S = Success - Completed without errors.
  * E = Error - Parameters are in error.
  * U = Unexpected error.
  * @rep:paraminfo  {@rep:required}
  *
  * @rep:displayname Get custom requisition price
  *
  * @rep:category BUSINESS_ENTITY PO_PURCHASE_REQUISITION
  * @rep:category BUSINESS_ENTITY PO_INTERNAL_REQUISITION
  */
  PROCEDURE get_custom_req_price(p_api_version               IN NUMBER,
                                 p_source_document_header_id IN NUMBER,
                                 p_source_document_line_num  IN NUMBER,
                                 p_order_line_id             IN NUMBER, -- <Bug 3754828>
                                 p_quantity                  IN NUMBER,
                                 p_unit_of_measure           IN VARCHAR2,
                                 p_deliver_to_location_id    IN NUMBER,
                                 p_required_currency         IN VARCHAR2,
                                 p_required_rate_type        IN VARCHAR2,
                                 p_need_by_date              IN DATE,
                                 p_pricing_date              IN DATE,
                                 p_destination_org_id        IN NUMBER,
                                 p_currency_price            IN NUMBER,
                                 x_new_currency_price        OUT NOCOPY NUMBER,
                                 x_return_status             OUT NOCOPY VARCHAR2);

  /*#
  * Provides the ability to customize PO/Release price through an API.
  *
  * The API is called by the Oracle PO/Release Pricing API that could
  * return a different price than what the Oracle PO/Release Pricing API
  * has returned.
  *
  * The Custom PO/Release Pricing API enables you to add PL/SQL code to
  * a custom price adjustment hook in the standard PO/Release Pricing
  * API that can adjust the unit price as determined from a source
  * document (blanket agreement or quotation). This provides a mechanism
  * to factor in negotiated discounts, surcharges, or other adjustments
  * on top of the catalog prices.
  *
  * @param p_api_version Null not allowed. Value should match the
  * current version of the API (currently 1.0). Used by the API to
  * determine compatibility of API and calling program.
  * @rep:paraminfo  {@rep:required}
  *
  * @param p_order_quantity Order quantity
  * @rep:paraminfo  {@rep:required}
  *
  * @param p_ship_to_org Ship to organization
  * @rep:paraminfo  {@rep:required}
  *
  * @param p_ship_to_loc Ship to location
  * @rep:paraminfo  {@rep:required}
  *
  * @param p_po_line_id Internal ID for PO Line. (i.e.
  * PO_LINES_ALL.po_line_id)
  * @rep:paraminfo  {@rep:required}
  *
  * @param p_cum_flag Cumulative flag
  * @rep:paraminfo  {@rep:required}
  *
  * @param p_need_by_date Need by date
  * @rep:paraminfo  {@rep:required}
  *
  * @param p_pricing_date Pricing date
  * @rep:paraminfo  {@rep:required}
  *
  * @param p_line_location_id Internal ID for PO Shipment. (i.e.
  * PO_LINE_LOCATIONS_ALL.line_location_id)
  * @rep:paraminfo  {@rep:required}
  *
  * @param p_price Calculated price
  * @rep:paraminfo  {@rep:required}
  *
  * @param x_new_price New customized price
  * @rep:paraminfo  {@rep:required}
  *
  * @param x_return_status Possible Values are:
  * S = Success - Completed without errors.
  * E = Error - Parameters are in error.
  * U = Unexpected error.
  * @rep:paraminfo  {@rep:required}
  *
  * @rep:displayname Get custom purchase order price
  *
  * @rep:category BUSINESS_ENTITY PO_STANDARD_PURCHASE_ORDER
  * @rep:category BUSINESS_ENTITY PO_BLANKET_RELEASE
  */
  PROCEDURE get_custom_po_price(p_api_version      IN NUMBER,
                                p_order_quantity   IN NUMBER,
                                p_ship_to_org      IN NUMBER,
                                p_ship_to_loc      IN NUMBER,
                                p_po_line_id       IN NUMBER,
                                p_cum_flag         IN BOOLEAN,
                                p_need_by_date     IN DATE,
                                p_pricing_date     IN DATE,
                                p_line_location_id IN NUMBER,
                                p_price            IN NUMBER,
                                x_new_price        OUT NOCOPY NUMBER,
                                x_return_status    OUT NOCOPY VARCHAR2,
                                p_req_line_price   IN NUMBER DEFAULT NULL); --< Bug 7154646 >

  -- <Bug 3794940 START>
  /* Bug 7154646 Adding the parameter p_req_line_price to retain the Req Line Price, if Required. */
  /*#
  * Provides the ability to audit advanced pricing adjustments during pricing
  * API call
  *
  * The API is called by the Oracle PO/Release Pricing API after invoking
  * advanced pricing engine.
  *
  * The information about pricing adjustments is stored in temporary view
  * QP_LDETS_V. To get the records, user should query this view for the records
  * that satisfy the following:
  *  qp_ldets_v.line_index = p_line_index AND
  *  qp_ldets_v.automatic_flag = 'Y'
  *
  * @param p_api_version Null not allowed. Value should match the
  * current version of the API (currently 1.0). Used by the API to
  * determine compatibility of API and calling program.
  * @rep:paraminfo  {@rep:required}
  *
  * @param p_order_type Type of the document ('PO' or 'REQUISITION')
  * @rep:paraminfo  {@rep:required}
  *
  * @param p_order_line_id Line ID of the document (po line or requisition line)
  * @rep:paraminfo  {@rep:required}
  *
  * @param p_line_index The index of pricing adjustments stored in
  * temporary view QP_LDETS_V.
  * @rep:paraminfo  {@rep:required}
  *
  * @param x_return_status Return status of the API. Possible Values are:
  * S = Success - Completed without errors.
  * E = Error - Parameters are in error.
  * U = Unexpected error.
  * @rep:paraminfo  {@rep:required}
  *
  * @param x_msg_count Number of messages added to FND_MSG_PUB message stack, if
  * used
  * @rep:paraminfo  {@rep:required}
  *
  * @param x_msg_data If x_msg_count = 1, this output parameter should return
  * the text of the message
  * @rep:paraminfo  {@rep:required}
  *
  * @rep:displayname Audit advanced pricing adjustments
  *
  * @rep:category BUSINESS_ENTITY PO_PURCHASE_REQUISITION
  * @rep:category BUSINESS_ENTITY PO_STANDARD_PURCHASE_ORDER
  */
  PROCEDURE audit_qp_price_adjustment(p_api_version   IN NUMBER,
                                      p_order_type    IN VARCHAR2,
                                      p_order_line_id IN NUMBER,
                                      p_line_index    IN NUMBER,
                                      x_return_status OUT NOCOPY VARCHAR2,
                                      x_msg_count     OUT NOCOPY NUMBER,
                                      x_msg_data      OUT NOCOPY VARCHAR2);
  -- <Bug 3794940 END>
  -- < Bug 7430760 START>
  /*#
  * This procedure provides for fetching custom unit price for an inventory item
  * on an internal requisition based on the item, source and destination inventories
  * and unit of measure. The parameters are
  
  * IN PARAMETERS
  *
  * @param p_api_version p_api_version : Null not allowed. Value should match the
  * current version of the API (currently 1.0). Used by the API to
  * determine compatibility of API and calling program.
  * @rep:paraminfo  {@rep:required}
  *
  * @param p_item_id : inventory item id of the item for which custom price is fetched
  * @rep:paraminfo  {@rep:required}
  *
  * @param p_category_id : category id of the item for which custom price is fetched
  * @rep:paraminfo  {@rep:required}
  *
  * @param p_req_header_id : Header id of the requisition
  * @rep:paraminfo  {@rep:required}
  *
  * @param p_req_line_id : Line of the requisition line
  * @rep:paraminfo  {@rep:required}
  *
  * @param p_src_organization_id : source inventory organization of the requisition line
  * @rep:paraminfo  {@rep:required}
  *
  * @param p_src_sub_inventory : Source sub inventory
  * @rep:paraminfo  {@rep:required}
  *
  * @param p_dest_organization_id : destination inventory organization of the requisition line
  * @rep:paraminfo  {@rep:required}
  *
  * @param p_dest_sub_inventory : destination sub inventory
  * @rep:paraminfo  {@rep:required}
  *
  * @param p_deliver_to_location_id : deliver to location in the destination organization
  * @rep:paraminfo  {@rep:required}
  *
  * @param p_need_by_date : need by date
  * @rep:paraminfo  {@rep:required}
  *
  * @param p_unit_of_measure : unit of measure of the requisition line
  * @rep:paraminfo  {@rep:required}
  *
  * @param p_quantity : quantity
  * @rep:paraminfo  {@rep:required}
  *
  * @param p_currency_code : currency code of the source organization
  * @rep:paraminfo  {@rep:required}
  *
  * @param p_rate : Rate of conversion of p_currency_code to fsp currency code
  * @rep:paraminfo  {@rep:required}
  *
  * @param p_rate_type : type of conversion
  * @rep:paraminfo  {@rep:required}
  *
  * @param p_rate_date : date of conversion
  * @rep:paraminfo  {@rep:required}
  *
  * OUT PARAMETERS
  *
  * @param x_return_status
  * FND_API.G_RET_STS_SUCCESS if API succeeds
  * FND_API.G_RET_STS_ERROR if API fails
  * FND_API.G_RET_STS_UNEXP_ERROR if unexpected error occurs
  * @rep:paraminfo  {@rep:required}
  *
  * IN OUT PARAMETERS
  *
  * @param x_unit_price
  * custom price if the custom code is in place
  * system price if the custom code is not in place
  * @rep:paraminfo  {@rep:required}
  *
  * @rep:displayname Get custom Internal Requisition Price
  *
  * @rep:category BUSINESS_ENTITY PO_INTERNAL_REQUISITION
  *
  */

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

  -- < Bug 7430760 END>
  --------------------------------------------------------------------------------
  --Start of Comments
  --Name: GET_CUSTOM_INTERNAL_REQ_PRICE
  --Pre-reqs:
  --  None.
  --Modifies:
  --  None.
  --Locks:
  --  None.
  --Function:
  --  This function call the procedure GET_CUST_INTERNAL_REQ_PRICE to and returns
  --  the unit price.This function is called from req import to fetch the unit price.
  --  This function is used only for internal coding purpose.
  --  DO NOT CUSTOMIZE THIS FUNCTION.
  --  CUSTOMIZE THE PROCEDURE GET_CUST_INTERNAL_REQ_PRICE
  --Parameters:
  -- IN PARAMETERS
  --
  -- p_item_id : inventory item id of the item for which custom price is fetched
  --
  -- p_category_id : category id of the category for which custom price is fetched
  --
  -- p_req_header_id : Header id of the requisition
  --
  -- p_req_line_id : Line of the requisition line
  --
  -- p_src_organization_id : source inventory organization of the requisition line
  --
  -- p_src_sub_inventory : Source sub inventory
  --
  -- p_dest_organization_id : destination inventory organization of the requisition line
  --
  -- p_dest_sub_inventory : destination sub inventory
  --
  -- p_deliver_to_location_id : deliver to location in the destination organization
  --
  -- p_need_by_date : need by date
  --
  -- p_unit_of_measure : unit of measure of the requisition line
  --
  -- p_quantity : quantity
  --
  -- p_currency_code : currency code of the source organization
  --
  -- p_rate : Rate of conversion of p_currency_code to fsp currency code
  --
  -- p_rate_type : type of conversion
  --
  -- p_rate_date : date of conversion
  --
  -- p_unit_price : unit price fetched from inventory. This price is returned
  -- if there is no custom code.
  --
  -- OUT PARAMETERS

  -- x_unit_price
  -- custom price if the custom code is in place
  -- system price if the custom code is not in place
  --End of Comments
  -------------------------------------------------------------------------------

  FUNCTION get_custom_internal_req_price(p_api_version            IN NUMBER,
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
                                         p_unit_price             IN NUMBER DEFAULT NULL)
    RETURN NUMBER;

END po_custom_price_pub; -- Package spec
/
