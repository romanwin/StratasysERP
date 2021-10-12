CREATE OR REPLACE PACKAGE BODY PO_CUSTOM_PRICE_PUB AS
/* $Header: POXPCPRB.pls 120.2.12010000.5 2009/06/12 13:49:35 rojain ship $ */
/* 19-May-2016  Lingaraj Sarangi  CHG0038367 - PO rescheduling should not trigger Quote based re-pricing*/
G_PKG_NAME CONSTANT varchar2(30) := 'PO_CUSTOM_PRICE_PUB';

g_log_head    CONSTANT VARCHAR2(50) := 'po.plsql.'|| G_PKG_NAME || '.';

-- Debugging
g_debug_stmt BOOLEAN := PO_DEBUG.is_debug_stmt_on;
g_debug_unexp BOOLEAN := PO_DEBUG.is_debug_unexp_on;

--------------------------------------------------------------------------------
--Start of Comments
--Name: get_custom_price_date
--Pre-reqs:
--  None.
--Modifies:
--  None.
--Locks:
--  None.
--Function:
--  This procedure returns custom price date.
--Parameters:
--IN:
--p_api_version
--  Version number of API that caller expects. It
--  should match the l_api_version defined in the
--  procedure (expected value : 1.0)
--p_source_document_header_id
--  The header id of the source document.
--p_source_document_line_id
--  The line id of the source document.
--p_order_line_id
--  The line id of the order document (PO or Requisition).
--p_quantity
--  Quantity
--p_ship_to_location_id
--  Ship to location
--p_ship_to_organization_id
--  Ship to organization
--p_need_by_date
--  Need by date
--OUT:
--x_pricing_date
--  New customized price date
--x_return_status
--  FND_API.G_RET_STS_SUCCESS if API succeeds
--  FND_API.G_RET_STS_ERROR if API fails
--  FND_API.G_RET_STS_UNEXP_ERROR if unexpected error occurs
-- Bug5598011 Added new parameter p_order_type which will indicate whether the
-- order document is REQUISITION or PO.
--Testing:
--
--End of Comments
-------------------------------------------------------------------------------
PROCEDURE GET_CUSTOM_PRICE_DATE(p_api_version			IN  NUMBER,
                                p_source_document_header_id	IN  NUMBER,   -- <FPJ Advanced Price>
                                p_source_document_line_id	IN  NUMBER,
                                p_order_line_id			IN  NUMBER, -- <Bug 3754828>
                                p_quantity			IN  NUMBER,
                                p_ship_to_location_id		IN  NUMBER,
                                p_ship_to_organization_id	IN  NUMBER,
                                p_need_by_date			IN  DATE,
                                x_pricing_date			OUT NOCOPY DATE,
                                x_return_status			OUT NOCOPY VARCHAR2,
				p_order_type                    IN VARCHAR2) --<Bug5598011>

IS
  l_api_version  NUMBER       := 1.0;
  l_api_name     VARCHAR2(60) := 'GET_CUSTOM_PRICE_DATE';
  l_log_head	 CONSTANT varchar2(100) := g_log_head || l_api_name;
  l_progress	 VARCHAR2(3) := '000';
BEGIN
  -- Check for the API version
  IF ( NOT FND_API.compatible_api_call(l_api_version,p_api_version,l_api_name,G_PKG_NAME) ) THEN
      x_return_status := FND_API.G_RET_STS_UNEXP_ERROR;
  END IF;

  /* This is where the customer will plug in their own custom logic.
     The following lines will have to be replaced with your custom code
     determining the value of the OUT parameters. */
  x_pricing_date := NULL;
  x_return_status := FND_API.G_RET_STS_SUCCESS;

END GET_CUSTOM_PRICE_DATE;

--------------------------------------------------------------------------------
--Start of Comments
--Name: get_custom_req_price
--Pre-reqs:
--  None.
--Modifies:
--  None.
--Locks:
--  None.
--Function:
--  This procedure returns custom price.
--Parameters:
--IN:
--p_api_version
--  Version number of API that caller expects. It
--  should match the l_api_version defined in the
--  procedure (expected value : 1.0)
--p_source_document_header_id
--  The header id of the source document.
--p_source_document_line_num
--  The line number of the source document.
--p_quantity
--  Quantity
--p_unit_of_measure
--  Unit of Measure
--p_deliver_to_location_id
--  Deliver to location
--p_required_currency
--  Required currency
--p_required_rate_type
--  Required rate type
--p_need_by_date
--  Need By date
--p_pricing_date
--  New custom pricing date
--p_destination_org_id
--  Destination Org
--p_currency_price
--  Caculated currency price
--OUT:
--x_new_currency_price
--  New customized currency price
--x_return_status
--  FND_API.G_RET_STS_SUCCESS if API succeeds
--  FND_API.G_RET_STS_ERROR if API fails
--  FND_API.G_RET_STS_UNEXP_ERROR if unexpected error occurs
--Testing:
--
--End of Comments
-------------------------------------------------------------------------------
PROCEDURE GET_CUSTOM_REQ_PRICE(p_api_version			IN  NUMBER,
                               p_source_document_header_id	IN  NUMBER,
                               p_source_document_line_num	IN  NUMBER,
                               p_order_line_id			IN  NUMBER, -- <Bug 3754828>
                               p_quantity			IN  NUMBER,
                               p_unit_of_measure		IN  VARCHAR2,
                               p_deliver_to_location_id		IN  NUMBER,
                               p_required_currency		IN  VARCHAR2,
                               p_required_rate_type		IN  VARCHAR2,
                               p_need_by_date			IN  DATE,
                               p_pricing_date			IN  DATE,
                               p_destination_org_id		IN  NUMBER,
                               p_currency_price			IN  NUMBER,
                               x_new_currency_price		OUT NOCOPY NUMBER,
                               x_return_status			OUT NOCOPY VARCHAR2)
IS
  l_api_version  NUMBER       := 1.0;
  l_api_name     VARCHAR2(60) := 'GET_CUSTOM_REQ_PRICE';
BEGIN
  -- Check for the API version
  IF ( NOT FND_API.compatible_api_call(l_api_version,p_api_version,l_api_name,G_PKG_NAME) ) THEN
      x_return_status := FND_API.G_RET_STS_UNEXP_ERROR;
  END IF;

  /* This is where the customer will plug in their own custom pricing logic.
     The following lines will have to be replaced with your custom code
     determining the value of the OUT parameters. */
  x_new_currency_price := NULL;
  x_return_status := FND_API.G_RET_STS_SUCCESS;

END GET_CUSTOM_REQ_PRICE;

--------------------------------------------------------------------------------
--Start of Comments
--Name: get_custom_req_price
--Pre-reqs:
--  None.
--Modifies:
--  None.
--Locks:
--  None.
--Function:
--  This procedure returns custom price.
--Parameters:
--IN:
--p_api_version
--  Version number of API that caller expects. It
--  should match the l_api_version defined in the
--  procedure (expected value : 1.0)
--p_order_quantity
--  Order Quantity
--p_ship_to_org
--  Ship to Org
--p_ship_to_loc
--  Ship to location
--p_po_line_id
--  PO Line ID
--p_cum_flag
--  Cumulated flag
--p_need_by_date
--  Need By date
--p_pricing_date
--  New custom pricing date
--p_line_location_id
--  Line location ID
--p_price
--  Caculated price
-- /* Bug 7154646 Adding the following Parameter */
--p_base_unit_price
--	Base Unit Price
--OUT:
--x_new_price
--  New customized price
--x_return_status
--  FND_API.G_RET_STS_SUCCESS if API succeeds
--  FND_API.G_RET_STS_ERROR if API fails
--  FND_API.G_RET_STS_UNEXP_ERROR if unexpected error occurs
--Testing:
--
--End of Comments
/* 19-May-2016  Lingaraj Sarangi  CHG0038367 - PO rescheduling should not trigger Quote based re-pricing*/
-------------------------------------------------------------------------------
PROCEDURE GET_CUSTOM_PO_PRICE(p_api_version		IN NUMBER,
                              p_order_quantity		IN NUMBER,
                              p_ship_to_org		IN NUMBER,
                              p_ship_to_loc		IN NUMBER,
                              p_po_line_id		IN NUMBER,
                              p_cum_flag		IN BOOLEAN,
                              p_need_by_date		IN DATE,
                              p_pricing_date		IN DATE,
                              p_line_location_id	IN NUMBER,
                              p_price			IN NUMBER,
                              x_new_price		OUT NOCOPY NUMBER,
                              x_return_status		OUT NOCOPY VARCHAR2,
                              p_req_line_price IN NUMBER)
IS
  l_api_version  NUMBER       := 1.0;
  l_api_name     VARCHAR2(60) := 'GET_CUSTOM_PO_PRICE';
   l_last_archive_price NUMBER;
  l_from_header_id NUMBER;
  l_from_LINE_id   NUMBER;
  l_ReferenceDocType VARCHAR2(30);
BEGIN
  -- Check for the API version
  IF ( NOT FND_API.compatible_api_call(l_api_version,p_api_version,l_api_name,G_PKG_NAME) ) THEN
      x_return_status := FND_API.G_RET_STS_UNEXP_ERROR;
  END IF;

  /* This is where the customer will plug in their own custom pricing logic.
     The following lines will have to be replaced with your custom code
     determining the value of the OUT parameters. */
  x_new_price := NULL;
  
  /* Custom Code Starts Here - CHG0038367*/
  IF p_line_location_id IS NOT NULL THEN -- Existing record Getting Modified ?
      BEGIN
          
         Select PLLA.PRICE_OVERRIDE,
                 PLA.from_header_id,
                 PLA.from_LINE_id,
                 (Select 'QUOTATION' from PO_HEADERS_ALL PHA1
                         where PHA1.TYPE_LOOKUP_CODE ='QUOTATION'
                         AND PHA1.PO_HEADER_ID = PLA.from_header_id
                 )ReferenceDocType -- Is the Reference Doc is Quatation
             Into l_last_archive_price,
                  l_from_header_id,
                  l_from_LINE_id,
                  l_ReferenceDocType
            from PO_HEADERS_ALL PHA,
                 PO_LINES_ALL PLA,
                 PO_LINE_LOCATIONS_ARCHIVE_ALL PLLA--PO Line archive table
           WHERE PLLA.line_location_id = p_line_location_id -- Variable
             AND PHA.PO_HEADER_ID = PLA.PO_HEADER_ID
             AND PLA.PO_LINE_ID = PLLA.PO_LINE_ID
             AND PHA.PO_HEADER_ID = PLLA.PO_HEADER_ID
             AND PHA.TYPE_LOOKUP_CODE = 'STANDARD'
             AND PLLA.latest_external_flag = 'Y';
           IF l_ReferenceDocType = 'QUOTATION' and p_price != l_last_archive_price THEN
              x_new_price := l_last_archive_price;
           END IF;
      Exception
       When Others Then
          x_new_price := NULL;
      END;  

  END IF;
  /* Custom Code End Here - CHG0038367*/
  
  x_return_status := FND_API.G_RET_STS_SUCCESS;

END GET_CUSTOM_PO_PRICE;


-- <Bug 3794940 START>
-------------------------------------------------------------------------------
--Start of Comments
--Name: audit_qp_price_adjustment
--Pre-reqs:
--  None.
--Modifies:
--  None.
--Locks:
--  None.
--Function:
--  This procedure allows customer to audit advanced pricing adjustments.
--Parameters:
--IN:
--p_api_version
--  Version number of API that caller expects. It
--  should match the l_api_version defined in the
--  procedure (expected value : 1.0)
--p_order_type
--  The type of the order document (PO or Requisition).
--p_order_line_id
--  The line id of the order document (PO or Requisition).
--p_line_index
--  The index of pricing adjustments stored in temporary view QP_LDETS_V, the query to
--  fetch records from view QP_LDETS_V should have:
--    qp_ldets_v.line_index = p_line_index AND
--    qp_ldets_v.automatic_flag = 'Y'
--OUT:
--x_return_status
--  FND_API.G_RET_STS_SUCCESS if API succeeds
--  FND_API.G_RET_STS_ERROR if API fails
--  FND_API.G_RET_STS_UNEXP_ERROR if unexpected error occurs
--Testing:
--
--End of Comments
-------------------------------------------------------------------------------

PROCEDURE audit_qp_price_adjustment(p_api_version       IN  NUMBER,
                                    p_order_type        IN  VARCHAR2,
                                    p_order_line_id     IN  NUMBER,
                                    p_line_index        IN  NUMBER,
                                    x_return_status     OUT NOCOPY VARCHAR2,
                                    x_msg_count         OUT NOCOPY NUMBER,
                                    x_msg_data          OUT NOCOPY VARCHAR2)
IS
  l_api_version  NUMBER       := 1.0;
  l_api_name     VARCHAR2(60) := 'AUDIT_QP_PRICE_ADJUSTMENT';
  l_log_head     CONSTANT varchar2(100) := g_log_head || l_api_name;
  l_progress     VARCHAR2(3) := '000';
BEGIN
  IF g_debug_stmt THEN
    PO_DEBUG.debug_begin(l_log_head);
    PO_DEBUG.debug_var(l_log_head,l_progress,'p_order_type', p_order_type);
    PO_DEBUG.debug_var(l_log_head,l_progress,'p_order_line_id',p_order_line_id);
    PO_DEBUG.debug_var(l_log_head,l_progress,'p_line_index',p_line_index);
  END IF;

  -- Check for the API version
  IF ( NOT FND_API.compatible_api_call(l_api_version,p_api_version,l_api_name,G_PKG_NAME) )
  THEN
      x_return_status := FND_API.G_RET_STS_UNEXP_ERROR;
  END IF;

  /* This is where the customer will plug in their own custom logic.
     The following lines will have to be replaced with your custom code
     determining the value of the OUT parameters. */
  x_return_status := FND_API.G_RET_STS_SUCCESS;
  x_msg_count := 0;
  x_msg_data := NULL;

  IF g_debug_stmt THEN
    PO_DEBUG.debug_end(l_log_head);
  END IF;

END audit_qp_price_adjustment;
-- <Bug 3794940 END>

-- < Bug 7430760 START>
--------------------------------------------------------------------------------
--Start of Comments
--Name: GET_CUST_INTERNAL_REQ_PRICE
--Pre-reqs:
--  None.
--Modifies:
--  None.
--Locks:
--  None.
--Function:
--  This procedure returns custom price date.
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
-- OUT PARAMETERS
-- x_return_status
-- FND_API.G_RET_STS_SUCCESS if API succeeds
-- FND_API.G_RET_STS_ERROR if API fails
-- FND_API.G_RET_STS_UNEXP_ERROR if unexpected error occurs
--
-- IN OUT PARAMETERS
-- x_unit_price
-- custom price if the custom code is in place
-- system price if the custom code is not in place
--End of Comments
-------------------------------------------------------------------------------
PROCEDURE GET_CUST_INTERNAL_REQ_PRICE(p_api_version             IN     NUMBER,
                                      p_item_id                 IN     NUMBER DEFAULT NULL,
                                      p_category_id             IN     NUMBER DEFAULT NULL,
                                      p_req_header_id           IN     NUMBER DEFAULT NULL,
                                      p_req_line_id             IN     NUMBER DEFAULT NULL,
                                      p_src_organization_id     IN     NUMBER DEFAULT NULL,
				      p_src_sub_inventory       IN     VARCHAR2 DEFAULT NULL,
                                      p_dest_organization_id    IN     NUMBER DEFAULT NULL,
				      p_dest_sub_inventory      IN     VARCHAR2 DEFAULT NULL,
				      p_deliver_to_location_id  IN     NUMBER DEFAULT NULL,
				      p_need_by_date            IN     DATE DEFAULT NULL,
				      p_unit_of_measure         IN     VARCHAR2 DEFAULT NULL,
				      p_quantity                IN     NUMBER DEFAULT NULL,
				      p_currency_code           IN     VARCHAR2 DEFAULT NULL,
				      p_rate                    IN     NUMBER DEFAULT NULL,
				      p_rate_type               IN     VARCHAR2 DEFAULT NULL,
				      p_rate_date               IN     DATE DEFAULT NULL,
				      x_return_status           OUT NOCOPY   VARCHAR2,
                                      x_unit_price              IN OUT NOCOPY NUMBER
				      )

IS
  l_api_version  NUMBER       := 1.0;
  l_api_name     VARCHAR2(60) := 'GET_CUST_INTERNAL_REQ_PRICE';
  l_log_head	 CONSTANT varchar2(100) := g_log_head || l_api_name;
  l_progress	 VARCHAR2(3) := '000';
BEGIN
  -- Check for the API version
  IF ( NOT FND_API.compatible_api_call(l_api_version,p_api_version,l_api_name,G_PKG_NAME) ) THEN
      x_return_status := FND_API.G_RET_STS_UNEXP_ERROR;
  END IF;

  /* This is where the customer will plug in their own custom logic.
     The following lines will have to be replaced with your custom code
     determining the value of the OUT parameters. Assign the value of
     the custom price to the IN OUT parameter x_unit_price*/
   x_return_status := FND_API.G_RET_STS_SUCCESS;

 END GET_CUST_INTERNAL_REQ_PRICE;

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

FUNCTION GET_CUSTOM_INTERNAL_REQ_PRICE(p_api_version             IN     NUMBER,
                                       p_item_id                 IN     NUMBER DEFAULT NULL,
                                       p_category_id             IN     NUMBER DEFAULT NULL,
                                       p_req_header_id           IN     NUMBER DEFAULT NULL,
                                       p_req_line_id             IN     NUMBER DEFAULT NULL,
                                       p_src_organization_id     IN     NUMBER DEFAULT NULL,
				       p_src_sub_inventory       IN     VARCHAR2 DEFAULT NULL,
                                       p_dest_organization_id    IN     NUMBER DEFAULT NULL,
				       p_dest_sub_inventory      IN     VARCHAR2 DEFAULT NULL,
				       p_deliver_to_location_id  IN     NUMBER DEFAULT NULL,
				       p_need_by_date            IN     DATE DEFAULT NULL,
				       p_unit_of_measure         IN     VARCHAR2 DEFAULT NULL,
				       p_quantity                IN     NUMBER DEFAULT NULL,
				       p_currency_code           IN     VARCHAR2 DEFAULT NULL,
				       p_rate                    IN     NUMBER DEFAULT NULL,
				       p_rate_type               IN     VARCHAR2 DEFAULT NULL,
				       p_rate_date               IN     DATE DEFAULT NULL,
				       p_unit_price              IN     NUMBER DEFAULT NULL
				       ) RETURN NUMBER IS

l_api_version  NUMBER       := 1.0;
l_api_name     VARCHAR2(60) := 'GET_CUSTOM_INTERNAL_REQ_PRICE';
l_log_head	 CONSTANT varchar2(100) := g_log_head || l_api_name;
l_progress	 VARCHAR2(3) := '000';
x_unit_price NUMBER;
x_return_status varchar2(1);

BEGIN

IF g_debug_stmt THEN
   FND_LOG.string(FND_LOG.LEVEL_STATEMENT,g_log_head || '.'||l_api_name||'.'
          || l_progress,'Before calling procedure GET_CUST_INTERNAL_REQ_PRICE ');
END IF;

x_unit_price := p_unit_price;

GET_CUST_INTERNAL_REQ_PRICE(p_api_version  => 1.0,
                            p_item_id      => p_item_id,
                            p_category_id  => p_category_id,
                            p_req_header_id  => p_req_header_id,
                            p_req_line_id  => p_req_line_id,
                            p_src_organization_id => p_src_organization_id,
			    p_src_sub_inventory => p_src_sub_inventory,
                            p_dest_organization_id => p_dest_organization_id,
			    p_dest_sub_inventory => p_dest_sub_inventory,
			    p_deliver_to_location_id => p_deliver_to_location_id,
		            p_need_by_date => p_need_by_date,
			    p_unit_of_measure => p_unit_of_measure,
			    p_quantity => p_quantity,
			    p_currency_code => p_currency_code,
			    p_rate => p_rate,
			    p_rate_type => p_rate_type,
			    p_rate_date => p_rate_date,
			    x_return_status => x_return_status,
                            x_unit_price => x_unit_price
				      );

IF (x_return_status <> 'S') THEN
 FND_LOG.string(FND_LOG.LEVEL_STATEMENT,g_log_head || '.'||l_api_name||'.'
          || l_progress,'After calling procedure GET_CUST_INTERNAL_REQ_PRICE. Return status is : '|| x_return_status );
 app_exception.raise_exception;
END IF;

return(x_unit_price);

END GET_CUSTOM_INTERNAL_REQ_PRICE;

END PO_CUSTOM_PRICE_PUB;
/
