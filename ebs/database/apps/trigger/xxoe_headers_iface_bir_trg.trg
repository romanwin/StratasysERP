CREATE OR REPLACE TRIGGER xxoe_headers_iface_bir_trg
   ---------------------------------------------------------------------------
   -- $Header: xxoe_headers_iface_bir_trg 120.0 2009/08/31  $
   ---------------------------------------------------------------------------
   -- Trigger: xxoe_headers_iface_bir_trg
   -- Created:
   -- Author  :
   --------------------------------------------------------------------------
   -- Perpose: update order price from internal requisition
   --------------------------------------------------------------------------
   -- Version  Date      Performer       Comments
   ----------  --------  --------------  -------------------------------------
   --     1.0  31/08/09                  Initial Build
   --     1.1  27/01/15   ginat B        CHG0034375  Adjust internal order creation to fix wrong currency code in internal SO
   ---------------------------------------------------------------------------
  BEFORE INSERT ON OE_HEADERS_IFACE_ALL
  FOR EACH ROW

when (NEW.order_source_id = 10)
DECLARE
  l_requisition_price NUMBER := NULL;
BEGIN

  IF nvl(fnd_profile.value('XXPO_ENABLE_INTER_REQ_PRICE'), 'N') = 'Y' THEN

    --Quering price from requisition is as follows:
    SELECT SUM(prla.unit_price)
    INTO   l_requisition_price
    FROM   po_requisition_lines_all     prla,
           org_organization_definitions odf_s, --CHG0034375
           org_organization_definitions odf_d --CHG0034375
    WHERE  prla.requisition_header_id = :new.orig_sys_document_ref
    AND    odf_s.organization_id = prla.source_organization_id
    AND    prla.destination_organization_id = odf_d.organization_id
    AND    odf_s.operating_unit != odf_d.operating_unit; --CHG0034375

    IF l_requisition_price IS NOT NULL THEN
      :new.transactional_curr_code := NULL;
    END IF;

  END IF;

EXCEPTION
  WHEN OTHERS THEN
    NULL;
END xxoe_headers_iface_bir_trg;
/
